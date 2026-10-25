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
| `integration/PodcastDirector.persistence.luau` | Three edits for `PodcastDirector`: one `require`, a replacement `snapshot()` and a replacement `restoreSnapshot()`. Not a standalone script. `persistentAction()` is **unchanged**. |
| `src/server/Core/PresetSlotGuard.luau` | Overwrite rules used inside the Save transform |
| `src/server/Core/BuildPersistence.luau` | The API the Director calls: `attachBuild`, `prepareLoad`, `commitLoad`, `revertLoad` |
| `src/server/Core/PlacementCore.luau` | `captureBuild`, `prepareLoad`, `loadBuild`, `revertLoad`, all through the same lock, host and epoch checks, rollback and recovery as edits |

## Exact install order

1. **Builder first:** sync the StudioBuilder tree (Rojo `default.project.json`) so
   `ServerScriptService.StudioBuilder.Core.PresetSlotGuard` and
   `ServerScriptService.StudioBuilder.Runtime.BuilderService` exist. Both patched live scripts require them.
2. **StudioPresets:** replace `ServerScriptService.StudioPresets` with `integration/StudioPresets.luau`.
3. **Director:**
   1. Next to `local presets = require(...)`, add the `builderPersistence` line from the patch file.
   2. Replace `snapshot()` with the patch version. Only its last line changes: `return builderPersistence:attachBuild(data)`.
   3. Replace `restoreSnapshot(p, data)` with the patch version.
   4. Leave `persistentAction()` exactly as it is.
4. Run the Studio checklist below. Codex reviews before anything is published.

## Behaviour

### Save (Director "Persist" Save → `snapshot()` → `presets.Save`)

- `attachBuild` adds `Build = { Version = 1, NextId, Items = { { Id, CatalogId, Transform = { X, Y, Z, Yaw } } } }`
  (room-relative). Preserved, unplaceable entries are written back unchanged.
- **Visible failure:** while a builder edit or load is in flight (Busy), while the world is being
  reconciled (RecoveryNeeded), or if the section exceeds 64 KB. The error reaches the existing
  `feedback` path, and the message carries a position prefix, so the Director's `:%d+: (.+)$` extraction shows it.
- **Slot guard (inside UpdateAsync):** a save writes nothing and fails visibly when:
  - the stored profile or its Slots table is corrupt (the old code replaced the whole profile, losing all five slots);
  - the slot's Build is newer or unreadable;
  - the new snapshot has no Build but the slot's Build has entries (builder unavailable in this server).
  The transform is pure and retry-safe: it never mutates `old`, and the last invocation decides the outcome.
- **No autosave:** the builder never writes a DataStore itself (a test enforces this). An explicit save of an empty build is allowed.

### Load (Director "Persist" Load/LoadCode → `restoreSnapshot`)

1. Existing preset and room checks (unchanged).
2. **`prepareLoad` (before any yield or mutation):** validates and stages the Build.
   - A corrupt or newer section raises, so the room and the build are unchanged and the error is visible.
   - Unplaceable entries (unknown or retired item, template not installed, collection locked, outside the current bounds)
     are **preserved**: not spawned, counted against the 150 cap, and written back on the next save.
   - No `Build` (legacy preset): the builder is untouched.
3. Existing text filtering (yields) and the existing host re-check (unchanged).
4. **`commitLoad` (before the room is touched):** replaces the build through PlacementCore's exclusive path.
   - It takes the edit lock, so concurrent builder edits, saves and loads get Busy.
   - It re-checks host and host epoch after every yield.
   - It applies a two-phase world "replace": all models are built unparented first, then swapped, and rolled back on failure.
   - A failed rollback enters recovery.
   - Any failure raises with the build unchanged (or in recovery, which refuses edits and saves until reconciled).
   - On success, history is cleared, logical IDs come from the save, and new IDs are never reused within the server.
5. **Room restore:** the existing code, unchanged, runs inside a pcall. If it errors, `revertLoad` restores the previous
   build (only when nothing changed since the load) and the error is re-raised.
   The room's own partial-mutation behaviour is unchanged from today.
6. `applyAll()` switches the room. Clients in build mode leave on the SceneSet change.

### Builder unavailable in a server (no sandbox marker)

Saves carry no Build, and the slot guard refuses to drop an existing non-empty Build. Loads apply the room and leave
the Build section untouched in the preset.

## Studio checklist (pending, for Codex)

- [ ] Save into an empty slot, a legacy slot and a slot with a Build. Load each back: same items, IDs and transforms.
- [ ] Load a legacy preset: the builder is untouched and the room loads as before.
- [ ] Hand-edit a slot to `Build.Version = 2`: Save into that slot is refused, and Load is refused with the room unchanged.
- [ ] Save while a builder edit is in flight: a visible "still applying" message.
- [ ] Host transfer during Load: "Host controls changed", with build and room unchanged.
- [ ] Share code of a preset with a Build: LoadCode restores the build.
- [ ] Remove a template from `StudioBuilderTemplates`, then load: that item is preserved (not spawned) and survives a re-save.
- [ ] Confirm that `SaveBackends.memory` (task 2) is unused. Persistence goes only through StudioPresets.
