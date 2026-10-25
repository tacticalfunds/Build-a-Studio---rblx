# Build-a-Studio: studio builder prototype

A small builder for the podcast/meeting game. From **Host Panel > Studio > OPEN BUILDER**, the host places
curated items in one separate sandbox. Each placed item can be moved, rotated, duplicated or deleted, with
Undo and Redo. The build is saved inside the existing StudioPresets slots.

- **Untouched:** the six existing rooms and the live Podcast* systems, apart from the documented patch points below.
- **Not done:** nothing is published, merged to `main` or monetized. Every catalog item is free.

This README is the integration and playtest handoff (task 6). Deeper references:

| Topic | Document |
|---|---|
| Adapter contracts, placement, drawer, streaming | [`docs/adapters.md`](docs/adapters.md) |
| Host-panel visual contract (exact tokens and layout) | [`docs/ui-contract.md`](docs/ui-contract.md) |
| Save/load install details, behaviour, recovery | [`docs/integration-task5.md`](docs/integration-task5.md) |
| Catalog expansion install and Play evidence | [`docs/integration-catalog-expansion.md`](docs/integration-catalog-expansion.md) |
| Structure placement plan (walls, floors, ceilings; not implemented) | [`docs/structure-placement-plan.md`](docs/structure-placement-plan.md) |
| Asset inventory from Studio | [`docs/assets/`](docs/assets/README.md) |
| Installed live source reference (bb3efa6, 45 scripts) | [`docs/studio-reference/`](docs/studio-reference/README.md) |
| Seat assignment model and wiring plan (task 7) | [`docs/task7-seat-plan.md`](docs/task7-seat-plan.md) |
| Task queue and per-checkpoint evidence | [`TASKS.md`](TASKS.md) |

## Status at a glance (2026-10-25)

| Area | Status |
|---|---|
| Catalog | **31 items installed** in the working place. Place→Delete passed in Play for all 31, and the drawer filters were checked ([`docs/integration-catalog-expansion.md`](docs/integration-catalog-expansion.md)). Real DataStore save/load with expansion items, multiplayer and a performance benchmark are not done. |
| Placement, undo/redo, host authority, recovery (server) | Tested locally and in real Studio Luau; Place/Undo/Redo/Delete checked in Play |
| Build drawer UI | Full UI flow passed in Play at 62f2f87 (latest Play run: UI mouse automation stalled, so not re-checked) |
| Save/load through StudioPresets | Director logic tested locally and in real Studio Luau; Play round trip done **against a memory stand-in for StudioPresets** |
| Real DataStore, real text filtering, multiplayer | **Not verified** |
| Seat assignment (task 7) | Pure model and integration plan only ([`docs/task7-seat-plan.md`](docs/task7-seat-plan.md)); no runtime wiring, no real anchor metadata |
| Executive/Broadcast collections (task 8), Branding (task 9) | Not started |

## Repository layout and Rojo mapping

`default.project.json` maps three new folders. Nothing in Workspace or the existing rooms is replaced.

| Source | Studio location | Contents |
|---|---|---|
| `src/shared` | `ReplicatedStorage.StudioBuilder` | `Config`, `Catalog`, `Protocol`, `Transform`, `Validate` |
| `src/server` | `ServerScriptService.StudioBuilder` | `StudioBuilderBootstrap.server` plus `Adapters/`, `Core/`, `Runtime/`, `Bootstrap/` |
| `src/client` | `StarterPlayer.StarterPlayerScripts.StudioBuilder` | `BuilderClient` (ModuleScript) plus `Build/`, `UI/`, `Adapters/` |
| `integration/` | not synced by Rojo | Files installed by hand into live scripts (see below) |
| `tests/` | not synced | `lua5.4 tests/run.lua` harness and 27 specs |
| `docs/studio-reference/` | not synced | Installed bb3efa6 source snapshot (reference only, read by one spec) |

`BuilderClient` is a ModuleScript and doesn't start itself. The host panel requires it and calls `configure` and `open`.

## Install order

1. **Builder tree.** Sync the three folders.
   The server bootstrap removes `Workspace.StudioAssetYard` (editor-only display copies) at play start, then starts `BuilderService`.
   `BuilderService` creates:
   - `ReplicatedStorage.StudioBuilder.Remotes.BuilderRequest` (RemoteFunction);
   - `ReplicatedStorage.StudioBuilder.PreviewTemplates` (sanitized copies for cards and the ghost);
   - `Workspace.StudioBuilderPlacedItems`, carrying the `BuildRevision`, `SandboxOrigin` and `SandboxSize` attributes.
2. **Studio prerequisites (Codex, done in the working place):**
   - `ServerStorage.StudioBuilderTemplates`: one Model per catalog ID. Each is anchored, has its pivot upright at the bottom centre, has no scripts, and has any Seats disabled.
     The probe rejects anything else and the card shows as not installed.
   - `Workspace.StudioBuilderSandbox`: the marker part whose volume is the build volume. Without it, the builder answers `Unavailable`.
   - **Streaming:** make the sandbox Model and the templates persistent. Placed models are set `ModelStreamingMode = Persistent` by the runtime.
3. **StudioPresets:** replace `ServerScriptService.StudioPresets` with `integration/StudioPresets.luau`. Only `Save` changes: it becomes a guarded, retry-safe UpdateAsync.
4. **DirectorPersistence:** add `integration/DirectorPersistence.luau` as a ModuleScript named `DirectorPersistence`, next to PodcastDirector.
5. **PodcastDirector:** follow `integration/PodcastDirector.persistence.luau`:
   1. delete `snapshot`, `restoreSnapshot` and `persistentAction`;
   2. insert the construction block, including the `roomLooks` getter/setter and the `setLayoutBusy` closure;
   3. add the two room-mutation gates (next section).
6. **Host panel and camera wiring** (next section).

## Live patch points in the working Studio

The installed source of 45 scripts at bb3efa6 is now in the repository as a **reference**:
[`docs/studio-reference/`](docs/studio-reference/README.md), with an index of paths, hashes and the commit.
Each hook below was checked against that source.
- Every installed StudioBuilder module, `DirectorPersistence` and `StudioPresets` is identical to this repository at bb3efa6, apart from line endings.
- **Backups:** the full-place RBXL backup is still the **62f2f87 baseline**. The JSON snapshot backs up the bb3efa6 scripts only, not the place.

### PodcastDirector (installed, verified in source)

- `directorPersistence` is built once from the Director's own locals, and `snapshot`, `restoreSnapshot` and `persistentAction` are bound to it.
  `getRoomLook` / `setRoomLook` are closures over the Director's `roomLooks`.
- **Entry gate:** in `PodcastStudioControl.OnServerEvent`, right after `if layoutBusy then feedback(p,false,"Please wait for the room transition."); return end`:
  `if action~="Persist" and directorPersistence.roomMutationBlocked() then feedback(p,false,directorPersistence.ROOM_MUTATION_MESSAGE); return end`.
  Fixture, Item, Set, Preset, Text, Timer, Look and Transfer are refused while a load is running or a failed load's recovery is unresolved.
  Persist stays open, so List works and every Persist action retries recovery first.
- **Post-filter gate:** in the Text branch, after the player/host re-check that follows the filter, and before `SetAttribute`:
  `if layoutBusy or directorPersistence.roomMutationBlocked() then` refuse.

### StudioPresets (installed)

- `Save` uses `PresetSlotGuard.transform`. It refuses to write over a corrupt profile, a newer or invalid record,
  snapshot or Build, or a slot whose existing non-empty Build would be lost.

### Host panel: PodcastStudioPanel (verified in source)

- **OPEN BUILDER:** the Studio tab gets a "BUILD YOUR STUDIO" heading and an OPEN BUILDER action row at the top of the page (`LayoutOrder` -20 / -19), built with the panel's own `heading` and `actionRow`.
  It refuses non-hosts, calls `builderClient.open()`, and shows a failure as `Builder: <reason>`. There is no fifth tab and no second panel.
- **Loading:** `BuilderClient` is required from `PlayerScripts.StudioBuilder` inside a `pcall`. If it's missing, the panel warns and keeps working without the builder.
- **`builderClient.configure`** binds all four hook slots:
  - `camera`: `PodcastCameraHook.fromLocalPlayer()`, wrapped (see the camera section);
  - `hostControls`: sets `PodcastCameraUI.StudioBuilderActive` to true on enter and false on exit;
  - `hostDrawer`:
    - enter: `cancelSharedEdits()`, `BuildModeActive = true`, `setPanelOpen(false)` (keeping `Drawer.Visible`, the launcher text and `PanelOpen` in sync), launcher text `BACK TO STUDIO  [P]`;
    - exit: `BuildModeActive = false`;
  - `worldClickHandlers`: sets the same `BuildModeActive` attribute. The panel's world picker returns early while it's set.
    Because both slots share one attribute, whichever exits first clears it.
  - `panel.getPosition` / `panel.onClosed`: open the drawer at the panel position. On close, the panel re-clamps the returned position, reopens, and shows the exit reason. "Restoring camera controls…" appears when cleanup failed.
  - `roomSwitchSignal = Workspace.PodcastStudio:GetAttributeChangedSignal("LayoutRevision")`.
    **Every** `StudioLayout.Apply` closes the builder: a room switch, a table/layout change, Look Recall/Reset, and a preset Load (through `applyAll`).
- **Launcher and P key:** while the builder is open, they close the builder instead of toggling the panel.
- **No Discard control.** No panel code sends `Persist` / `DiscardLoadBlock`.
  After a failed load, the save-block message mentions discarding. Until a control is added, **a successful Load is the only way to lift the save block**.

### Camera: PodcastCamera (verified in source)

- **New `BuildCamera` action** on `StudioCameraControl` (value: a CFrame). It switches to free camera (`selectShot(-2)`), places the free camera at that CFrame and sets Focus.
  It's handled before the build-mode gate, so it works while building.
- **Camera hook as wrapped by the panel:**
  - **Enter:** remembers whether the free camera was on and the current camera CFrame. Then the original hook (`FreeCamera = true`), then `BuildCamera` at `sandboxOrigin * (24, 23, 29)`, looking at `sandboxOrigin * (0, 1, 0)`.
  - **Exit:** the original hook restores the previous view (free stays free; seat shots 1–4 and POV reselected; Wide, Walk and unknown views go to Wide; Walk never re-entered). If the camera was free before, `BuildCamera` returns it to its old CFrame.
- **While `StudioBuilderActive` is set,** this is ignored:
  - `selectShot` (except free camera), and the forced Wide on `LayoutRevision`;
  - V / gamepad Y view toggle, F walk, the Sit button;
  - the `AutoShot`, `Shot`, `POV`, `Walk` and `Reset` actions;
  - keys 1–5, V, F and D-pad.

  The camera bar and header are hidden.
- **Still working while building:**
  - **Escape:** its handler runs first and always releases the cursor.
  - **Right-mouse free look:** works while the camera is free; free look is released when build mode toggles.
  - **WASD / Q / E flight:** the code is unchanged; it's on the checklist rather than re-verified here.
- `PodcastSpeakerFollow` has no builder check of its own. Its `AutoShot` requests are ignored by the camera while building.
- Isolated MCP `require` calls report `HandoffUnbound`, because they get a separate, unconfigured module instance. This is expected and not a wiring fault.

### Streaming (Studio settings, per Codex)

- `StreamingEnabled = true`. The build camera can be far from the avatar, for example avatar in the Boardroom and camera at (2024, 23, 29).
- The sandbox Model and the 7 templates are persistent in Studio, and `PlacedItemsWorld` makes every placed model persistent before parenting.
- Room assets keep normal streaming.
- Verified by Codex: client replication and floor raycasts. These are Instance properties, so they aren't in the script snapshot.

### StudioCustomization: isolation without a guard (verified in source)

- `StudioCustomization.GetItems(scene)` walks only the selected room root:
  - `Workspace.PodcastStudio` for Custom, which returns no items;
  - otherwise the model named by that room's `PodcastRooms` config.
- Builder items live separately in `Workspace.StudioBuilderPlacedItems`, so the `StudioBasePivot` reset never reaches them.
- There is **no explicit `BuildItemId` or folder guard**. Isolation comes only from that traversal.
- A defensive guard is needed before builder items are ever placed inside a room root. The seat-assignment spec asserts both the isolation and the absent guard.

## Protocol and security model

- **One RemoteFunction:** `Remotes.BuilderRequest`, one table per call. The ops and their exact fields are listed in `src/shared/Protocol.luau`:
  `Place {itemId, transform}`, `Move {id, transform}`, `Rotate {id, direction?}`, `Duplicate {id}`, `Delete {id}`, `Undo {expectedRevision?}`,
  `Redo {expectedRevision?}`, `Status {}`. Structure items (catalog `structure` metadata) additionally get `OffGrid` with a `reason` (OffGrid, BadLevel or BadYaw) when off the 16-stud grid.
  Any other key is rejected. Instances, paths, colours and scales are never accepted.
- **Transforms:** local to the sandbox origin; finite; yaw on the 15° grid; positions quantized to 0.01 studs. The full yawed footprint must fit the sandbox bounds.
- **Catalog whitelist:** stable IDs (`src/shared/Catalog.luau`) map to curated ServerStorage templates. Clones are sanitized of code, prompts, detectors, remotes and bindables.
  There are no `LoadAsset`, `InsertService`, `require(assetId)` or HTTP loaders; a static test enforces this.
- **Authority:** only the current host (`ReplicatedStorage.PodcastSettings.HostUserId`) edits.
  The host is re-checked after every yield, and a host-session epoch aborts work across A → B → A. History is cleared on host change.
- **Limits:**
  - 150 items;
  - builder-only rate limits: edits 12 burst at 6/s, Status 6 burst at 2/s;
  - undo depth 50;
  - `expectedRevision` refuses stale Undo/Redo.
- **Fail closed:** the edit lock is taken before any yielding dependency. A failed world rollback or finalize puts the server in `recovery`.
  Edits and saves are then refused until recovery succeeds; it is retried every 2 s.
- **Never `LayoutRevision`:** the builder publishes its own `BuildRevision`.

## Save and load (summary)

- **Storage:** an additive `Build = { Version = 1, NextId, Items = { { Id, CatalogId, Transform = { X, Y, Z, Yaw } } } }` section inside the existing StudioPresets snapshot.
  Same 5 slots, same 250000-byte cap, no autosave. Done just leaves the builder.
- **Load:** one transaction for room and build. A corrupt or newer Build fails before any change.
  Any failure rolls the room back without re-filtering text, and rolls the build back.
- **Recovery:** if a rollback fails, a shared recovery blocks:
  - builder edits, saves, loads and Discard, for every host;
  - normal room changes, through the Director gates.
  It stays until the room and the build are both restored.
- **Save block:** after any failed Load or LoadCode, Save and Share are refused for that host until a successful load (or `DiscardLoadBlock`, which has no UI yet).

## Verification

### Executed in this repository

- `lua5.4 tests/run.lua`: **286 passed, 0 failed**, across 27 specs.
- `seat_assignments_spec` also checks the seat model's contracts against the attached bb3efa6 source: seat count, seat index range, pose modes, Lounge-only couch poses, seat labels and StudioCustomization isolation.
- The tests run the real modules (and the real `integration/` files) against fakes. Yields are driven by coroutines.
- Key behaviours were also checked by mutation: each original bug, put back, makes a test fail.
- All source is compile-checked as Lua 5.4. The Luau CLI couldn't run in this environment.

### Executed by Codex in real Studio Luau

- 50 server, 47 client, and Director tests: all **19** Director tests at bb3efa6, plus five independent regressions.
- Slot-guard checks, and template probe and reconcile checks on the 7 real templates.
- All nine installed or patched files compile.

### Executed by Codex in Play (working place)

- **Builder UI (at 62f2f87):** OPEN BUILDER opens the drawer, which matches the live panel.
  Place, Move, Rotate, Duplicate, Delete, Undo and Redo work; Done restores shot 0 and the host drawer.
- **Streaming:** the persistence fix works for client replication and floor raycasts.
- **At bb3efa6:**
  - the server starts in `ready`;
  - Place, Undo, Redo and Delete work through the client RemoteFunction;
  - the Director Save/Load round trip worked: table `i2` came back at local (4, 0, -4), yaw 15, and Theme Teal came back after deleting it and setting Theme Sand;
  - history was cleared on load;
  - a failed Load (a missing slot) followed by Save was refused, with no second backend write;
  - no startup errors.
- **Caveat on those Play checks:**
  - The StudioPresets API was replaced by **Play-only memory stand-ins**, so there were no real DataStore reads or writes.
  - The fake Load had **no text fields**, so live text filtering didn't run.
  - UI mouse automation stalled in that run, so the bb3efa6 checks went through the RemoteFunction, not the drawer.

### Not verified yet

- Real DataStore: Save, Load, List, Share and LoadCode, UpdateAsync retries, backend errors, the size cap.
- Real TextService filtering inside Load, including a filter that yields long enough to race a host change.
- Multiplayer: host transfer during building and during Load, a non-host trying to edit, two clients watching the build, late joiners and streaming for other players.
- A real forced room failure during Load (rollback and recovery in a live server), and the Director gates refusing real panel actions during it.
- Touch input, and the drawer flow at bb3efa6.
- Anything about seats with the builder: task 7 is a pure model so far.

## Playtest checklist for Codex (remaining)

Use a test place or a private server with DataStore access. Never publish.

**DataStore and text (real services):**
- [ ] Save into an empty slot, a legacy slot (no Build) and a slot with a Build. Load each back: same item IDs, catalog IDs and transforms.
- [ ] Load a legacy preset: the builder is left as it is and the room loads as before.
- [ ] Hand-edit a slot to `Build.Version = 2`: Save into it is refused, and Load is refused with room and build unchanged.
- [ ] Save, Load and Share with a real title (text filtering runs): the filtered title is applied, and Save/Load feedback is correct.
- [ ] Share a preset with a Build, then LoadCode it: the build comes back.
- [ ] A slot-list refresh failure after a good save still reports the save as successful (only if a failure can be forced safely).

**Failure paths:**
- [ ] Force a room failure during Load (a temporary error in `applyAll`): room settings, fixtures, items, `roomLooks` and the build are restored.
  Save is then refused until a successful Load (there's no Discard button).
- [ ] Force `applyAll` to fail during both Load and rollback:
  - every non-Persist panel action is refused with the room-changes message;
  - Persist List still works;
  - builder edits get RecoveryNeeded.
  Remove the failure and wait about 2 s: the room is exactly the pre-load state, and everything works again.
- [ ] Type a Text change, then start a failing Load before the filter returns: the text isn't applied.

**Multiplayer (two clients):**
- [ ] Transfer host during building: the old host's builder closes or turns read-only, and the new host can edit every item. Undo history doesn't carry over.
- [ ] Transfer host during Load: "Host controls changed", with room and build unchanged.
- [ ] A non-host sending BuilderRequest edits gets `NotHost`. Status still answers.
- [ ] The second client sees placed items (streaming) and doesn't see the ghost.

**Catalog expansion (24 items).** Done in Play (Codex): templates installed, Place then Delete for all 31 IDs, `OutOfBounds` at the sandbox edge, filter counts, a card-click placement, 31 preview models. Remaining:
- [ ] Move, Rotate, Duplicate, Undo and Redo on expansion items (only Place and Delete ran for all 31).
- [ ] Card-click placement for more items than the Curved Lounge Sofa.
- [ ] Preview cost: join time and drawer ViewportFrame performance with 31 preview templates, some over 100 parts (`future_shelf_01`, `studio_mixer_01`, `winter_white_rug_01`).
- [ ] Real DataStore Save and Load of a build that uses expansion items; a second client sees them.
- [ ] Decide whether the legacy `cozy_floor_lamp_01` template should keep its light. It still emits light; the 24 new templates have lights disabled.

**UI and place:**
- [ ] While building, 1–5, V, F, D-pad/Y and AutoShot do nothing; WASD, Q/E, right-drag look and Escape cursor release still work. After Done, the shortcuts work again.
- [ ] Re-run the drawer flow at bb3efa6 (Place/Move/Rotate/Duplicate/Delete/Undo/Redo/Done, R, Escape) with mouse and with touch.
- [ ] Changing room customization (Studio tab item edits in a free-model room) doesn't move builder items. Isolation comes from the root traversal; there's no tag guard.
- [ ] Remove one template from `StudioBuilderTemplates`, then load a build that uses it: the item is kept (not spawned) and survives a re-save.

## Catalog and content status

`Catalog.luau` lists **31 items**, all free and all **decorative**. No seat, light or audio adapter exists:
- chairs aren't seats;
- microphones, mixers and headphones have no audio;
- the legacy `cozy_floor_lamp_01` template still contains and emits its own light. That isn't an adapter.

**Installed (2026-10-25):** all 31 templates are in `ServerStorage.StudioBuilderTemplates` in the working place, and the installed Catalog source is 6a8e490. Evidence: [`docs/integration-catalog-expansion.md`](docs/integration-catalog-expansion.md).
- **The original 7:**
  - `cozy_armchair_01`, `cozy_coffee_table_01`, `cozy_bookshelf_01`, `cozy_plant_01`, `cozy_floor_lamp_01`;
  - `retro_tv_cart_01`, `retro_cassette_01`.
- **The expansion (24):**
  - Prepared and visually reviewed by Codex; scriptless and anchored, with Seats, lights and effects disabled. No seat profiles.
  - The original manifest, kept as provenance, is [`docs/assets/Catalog_Expansion_2026-10-25.json`](docs/assets/Catalog_Expansion_2026-10-25.json). The catalog's IDs, names, tags and sourceRefs match it exactly; a test checks this.
  - The `sourceAssetId` fields stay in the manifest only.
  - The prepared originals remain in `ServerStorage.StudioBuilderExpansion`, and 24 manual-use copies are in the asset yard (`07 Builder Catalog Expansion`).
- **Collection counts (items can carry several tags):** Cozy 22, Retro 16, 1980s 12, Winter 11, Futuristic 9. Every filter now has items.
  Executive and Broadcast (task 8) don't exist yet.
- **Candidates, not installed (10):** 7 structure pieces (walls, doorway, corner, floor, ceiling, window frame) and 3 decor items. They're prepared in Studio and indexed in [`docs/assets/README.md`](docs/assets/README.md), but they aren't in `Catalog.luau` or the Build UI.
  Structure placement is integrated on the **server** in the repository (task 10, [`docs/structure-placement-plan.md`](docs/structure-placement-plan.md)): grid, level and cardinal-yaw validation for catalog items with `structure` metadata, 90° Rotate and on-grid Duplicate. It's tested only with fake fixtures, and isn't installed in Studio. No live item has structure metadata, and there's no client preview or UI yet, so structural snapping isn't available in the game.

## Next tasks

- **Task 7, seat assignment:** the foundation (pure model, tests, plan) is in [`docs/task7-seat-plan.md`](docs/task7-seat-plan.md).
  Wiring waits on review, on the decisions listed there, and on real anchor and profile metadata from Codex. Until then, catalog chairs are decorative only.
- **Task 8:** more collection themes, for templates Codex has prepared.
- **Task 9:** Studio > Branding.
- **Discard control (small, panel side):** a button that sends `PodcastStudioControl:FireServer("Persist", "DiscardLoadBlock", {})`.
