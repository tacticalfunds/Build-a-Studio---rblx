# Task 5 integration: Build save/load through StudioPresets

The builder stores its build as an **additive `Build` section** inside the existing StudioPresets
snapshot: same DataStore (`PodcastStudioPresets_v1`), same 5 slots, same 250000-byte cap, entry and
top-level `Version = 1`. There's **no separate save profile and no autosave**. Done just leaves the
builder; saving and loading stay in the existing Studio → saved studios UI.

**Status:** pure logic and the patched StudioPresets module were executed against fakes
(`lua5.4 tests/run.lua`). **No real DataStore call, Studio install or Play test has been run.**

## Files

| File | What it is |
|---|---|
| `integration/StudioPresets.luau` | Full replacement for `ServerScriptService.StudioPresets`, built from the live source. Only `M.Save` changed (guarded, retry-safe UpdateAsync transform). |
| `integration/DirectorPersistence.luau` | New ModuleScript, installed next to PodcastDirector. It holds the Director's `snapshot` / `restoreSnapshot` / `persistentAction` logic (live code, dependency-injected) with the fixes below. |
| `integration/PodcastDirector.persistence.luau` | The Director edit: delete the three old functions and insert the construction block that passes the Director's existing locals. Not a standalone script. |
| `src/server/Core/PresetSlotGuard.luau` | Overwrite rules used inside the Save transform |
| `src/server/Core/BuildPersistence.luau` | Builder side: `attachBuild`, `prepareLoad` (stages and binds), and `begin` returning a load transaction |
| `src/server/Core/PlacementCore.luau` | `captureBuild`, `prepareLoad`, `binding`, and `beginTransaction` (holds the edit lock: `applyBuild` / `stillAuthorized` / `commit` / `rollback`) |

## Exact install order

1. **Builder first:** sync the StudioBuilder tree so `ServerScriptService.StudioBuilder.Core.PresetSlotGuard` and
   `ServerScriptService.StudioBuilder.Runtime.BuilderService` exist.
2. **StudioPresets:** replace `ServerScriptService.StudioPresets` with `integration/StudioPresets.luau`.
3. **DirectorPersistence:** add `integration/DirectorPersistence.luau` as a ModuleScript named `DirectorPersistence`, sibling of PodcastDirector.
4. **Director:**
   1. Delete the local functions `snapshot()`, `restoreSnapshot()` and `persistentAction()`.
   2. Insert the block from `integration/PodcastDirector.persistence.luau` where `persistentAction` was, after every local it passes exists.
   3. The names `snapshot`, `restoreSnapshot` and `persistentAction` stay bound, so the existing `Persist` remote handler keeps calling `persistentAction`.
5. **Optional panel control:** "Discard" sends `PodcastStudioControl:FireServer("Persist", "DiscardLoadBlock", {})` to lift the save block.
6. Run the Studio checklist below.

## Behaviour

### Save

- `snapshot()` is the live room snapshot plus an additive `Build = { Version = 1, NextId, Items = { { Id, CatalogId, Transform } } }`.
  Unplaceable preserved entries are written back.
- **Visible failure:** while a builder edit or load is in flight, while the builder is in recovery, or if the build is over 64 KB.
- **Save-block latch:** after any failed Load/LoadCode, **Save and Share are refused** for that host until a successful load or `DiscardLoadBlock`.
  That includes a corrupt or newer build, a backend read failure, and a failed rollback.
- **Write vs refresh:** the write and the slot-list refresh are separate. A refresh failure still reports the save as successful, with a note.
- **Slot guard (inside UpdateAsync; the last retry decides):** the save writes nothing when:
  - the profile or Slots table is corrupt;
  - the slot entry isn't a readable v1 record: non-table, non-number or newer `Version`, non-table or newer `Data` (snapshot) Version, or non-table `Settings`;
  - the slot's Build is newer or unreadable;
  - a snapshot without Build would drop a non-empty Build.
- **No autosave:** the builder never writes a DataStore.

### Load: one transaction for room and build

1. Existing preset and room checks.
2. **`prepareLoad`:** validates and stages the Build, and binds the load to the current **host epoch and build revision**.
   A corrupt or newer Build fails here, before the text filter and before any mutation.
3. Existing text filtering (yields) and host check.
4. **Capture** the trusted pre-load room state: every setting key, plus the fixture and item overrides of the current and target scenes.
5. **`begin`:** re-checks the binding. A → B → A during filtering is refused here with nothing changed, legacy room-only loads included.
   It then **holds the builder's edit lock** until the end, so builder edits and saves get Busy.
6. Inside a pcall: `applyBuild` (two-phase world swap; the model isn't committed yet), the live room restore (`applyAll` etc.),
   then a **final authority check** (same host and same host epoch) after all yields.
7. **On success:** `commit` (model, revision and history clear; finalize), and the latch is cleared.
8. **On any failure:**
   - the room is restored from the captured state **without re-filtering text** (the captured strings are the live ones), and `rememberLighting` is not called;
   - the build world swap is rolled back;
   - if either rollback fails, saving is latched (`RollbackFailed`) and the builder stays in recovery, refusing edits and saves.

### Recovery (review of e30e8be)

- **Room rollback fails:** the failed restore joins the builder's **compound recovery**, which holds the captured room and the build.
  - Builder edits, saves, loads and Discard are refused **for every host**, across host transfer, until recovery restores both parts.
  - Recovery runs every 2 s in BuilderService, and each Persist action also attempts it first. Nothing else clears it.
- **Build finalize fails after the room loaded:** the Load is reported as **incomplete**, not successful. Saving stays paused until the finalize is reconciled.
- **`rememberLighting`:** the current scene's `roomLooks` entry is captured before the load and restored exactly on rollback, including absence.
  The Director passes `getRoomLook` / `setRoomLook` closures over its existing `roomLooks` table (see the patch file).
- **Locking:** `beginTransaction` takes the edit lock before any possibly-yielding authority read and releases it on every refusal or error.

### Builder unavailable in a server

Saves carry no Build, and the guard refuses to drop an existing non-empty Build. Loads run the room part through the same capture and rollback.
There's no builder epoch then; the Director's own host checks apply.

## Live integration notes (Codex, 2026-10-25)

- Host Panel > Studio > OPEN BUILDER works in Play, and the drawer matches the existing UI.
- StreamingEnabled: placed models are `ModelStreamingMode = Persistent` (see docs/adapters.md, "Streaming"). The sandbox Model and templates are made persistent in Studio.
- An isolated MCP `require` reported `HandoffUnbound` while the real button worked. MCP runs `require` in a separate environment, so it gets a separate, unconfigured module instance. Its `HandoffUnbound` is the expected fail-closed answer for that instance, not a fault in the live wiring.

## Studio checklist (pending, for Codex)

- [ ] Save into an empty slot, a legacy slot and a slot with a Build. Load each back: same items, IDs and transforms.
- [ ] Load a legacy preset: the builder is untouched and the room loads as before.
- [ ] Hand-edit a slot to `Build.Version = 2`: Save into that slot is refused, and Load is refused with the room unchanged.
- [ ] Save while a builder edit is in flight: a visible "still applying" message.
- [ ] Force a room failure during Load (for example, a temporary error in applyAll): room settings, fixtures, items and the build are restored; then Save is refused until Load or Discard.
- [ ] Load while editing in the builder: builder edits get "Still applying" until the load finishes.
- [ ] Host transfer during Load: "Host controls changed", with build and room unchanged.
- [ ] Share code of a preset with a Build: LoadCode restores the build.
- [ ] Remove a template from `StudioBuilderTemplates`, then load: that item is preserved (not spawned) and survives a re-save.
- [ ] Confirm that `SaveBackends.memory` (task 2) is unused. Persistence goes only through StudioPresets.
