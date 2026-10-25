# Builder adapters (task 2)

These are the narrow seams between the builder and live Studio systems. Each one is
dependency-injected where the live API isn't known, or is wired to the **verified
contracts** from Codex's read-only inspection on 2026-10-25. **Studio integration is
pending for all of them.** Only the pure logic has been exercised, by `lua5.4 tests/run.lua`.

Rojo mapping (`default.project.json`): `src/shared` → `ReplicatedStorage.StudioBuilder`,
`src/server` → `ServerScriptService.StudioBuilder`, `src/client` →
`StarterPlayerScripts.StudioBuilder`. All three are new folders. Nothing in Workspace
or the existing rooms is described or replaced.

| Adapter | File | Entry point | Injected | Live default |
|---|---|---|---|---|
| Catalog | `src/shared/Catalog.luau` | `Catalog.getItem(id)`, `getItemsTagged(tag)`, `validate()` | n/a (data) | 7 stable IDs; tags Cozy, 1980s, Retro, Winter, Futuristic |
| Entitlements | `src/server/Adapters/Entitlements.luau` | `Entitlements.new({resolvers}) :isItemUnlocked(userId, item, Catalog)` | `resolvers[kind](userId, entitlement) -> boolean` | Only `free`, so everything is unlocked. Unknown kinds fail closed. |
| Host authority | `src/server/Adapters/HostAuthority.luau` | `HostAuthority.new({getHostUserId}) :check(userId) -> allowed, reason` | `getHostUserId() -> number?` | `podcastSettingsSource()` reads the `HostUserId` attribute on the `ReplicatedStorage.PodcastSettings` Folder, with no caching |
| Template catalog | `src/server/Adapters/TemplateCatalog.luau` | `TemplateCatalog.build(Catalog, probe)`, then `:isInstalled(id)`, `:getSize(id)`, `:clientListing()` | `probe(itemId) -> {size={x,y,z}}?` (an error marks the entry invalid) | `serverStorageProbe()` looks for a Model named `<itemId>` in `ServerStorage.StudioBuilderTemplates` and rejects templates that contain scripts. Fixtures load only when `Config.Dev.UseTestFixtures` is set, in Studio. |
| Room / sandbox | `src/server/Adapters/RoomProvider.luau` | `RoomProvider.new({resolve}) :resolve(player) -> {id, origin, bounds}?` | `resolve(player)` | `markerSource()` uses the Workspace part `StudioBuilderSandbox`. Sandbox only. |
| Save payload | `src/server/Adapters/SaveSnapshot.luau` | `encode(build)`, `decode(section)`, `attachToPreset(preset, section)`, `readFromPreset(preset)`, `checkSize(section)` | `classify(entry) -> boolean` | Additive `Build = {Version=1, NextId, Items={ {Id, CatalogId, Transform={X,Y,Z,Yaw}} }}` section. The preset's top-level and entry `Version` stay 1. A missing `Build` returns `NoBuild` (legacy). 64 KB section cap, under the 250000-byte preset cap. |
| Save backend | `src/server/Adapters/SaveBackends.luau` | `backend:load(userId)`, `backend:save(userId, section)`; `SaveBackends.check(b)` | any backend meeting the contract | `memory()` only, which is **not persistence**. Routing through StudioPresets is task 5. |
| Build-mode handoff | `src/client/Adapters/BuildModeHandoff.luau` | `BuildModeHandoff.new({hooks}) :enter(context)`, `:exit()` | slots `camera`, `hostControls`, `hostDrawer`, `worldClickHandlers`, each `{enter(context), exit()}` | `camera` and `hostControls` are required, so build mode won't start without them. State machine inactive → entering → active → exiting. Hooks may yield. Each attempted hook is recorded before it runs, so a partial failure is still exited. `exit()` during a yielded `enter()` cancels it (`pending=true`). A failed exit keeps its handle for retry, and `enter()` refuses until cleanup succeeds. |
| Camera hook | `src/client/Adapters/PodcastCameraHook.luau` | `PodcastCameraHook.fromLocalPlayer()` returns a `camera` slot hook | `fire(action, value)`, `readState()` | `PlayerGui.PodcastCameraUI.StudioCameraControl:Fire("FreeCamera", true)` on enter. On exit, restores the previous view (details below). |
| Asset yard guard | `src/server/Bootstrap/AssetYardGuard.luau`, run by `src/server/StudioBuilderBootstrap.server.luau` | `AssetYardGuard.run(Workspace, "StudioAssetYard")` | workspace object | Destroys only the top-level `Workspace.StudioAssetYard` when a play or live server starts. Scripts don't run in Edit mode, so the yard stays while you edit. |

The camera hook's exit restore: a free camera stays free; seat shots 1–4 (and POV) are
reselected; Wide, Walk and unknown views go to Wide. Walk is never re-entered, because
entering Walk fires a seat Leave.

## What the verified contracts still need from live scripts (not done here)

These need edits to existing scripts that this repo doesn't contain. The builder
won't guess them, and the matching handoff slots stay unbound until they exist.

1. **hostControls gate (required slot).** PodcastCamera has no BuildMode or ownership API.
   It needs an explicit gate that ignores 1–5, V, F, D-pad/Y shot controls and AutoShot while
   building, keeping WASD, Q/E, Shift/Ctrl, right-drag look, and the Escape / right-mouse
   release / focus-loss cursor safeguards. PodcastSpeakerFollow already pauses while
   `SelectedShot < 0`. An explicit gate there is still preferable.
2. **hostDrawer slot.** PodcastStudioPanel must expose its shared open/close function (the one
   that keeps the `PanelOpen` attribute and launch text in sync). Toggling `Drawer.Visible`
   directly leaves them stale.
3. **worldClickHandlers slot.** The panel's world picker (mouse clicks while the drawer is visible on
   the Studio or Lighting tab) and its highlight must be gated off during building.
4. **StudioCustomization exclusion.** It must skip anything tagged with the `BuildItemId` attribute
   (`Config.BuildItemIdAttribute`) or anything inside `StudioBuilderPlacedItems`. Otherwise its
   pivot reset from `StudioBasePivot` could overwrite builder items.
5. **Director restore order.** `restoreSnapshot()` must rebuild `Build` items before applying
   fixture and item overrides. A missing `Build` must keep today's behaviour.

## Rules carried into later tasks

- **Host authority is rechecked at commit time** after any yield (host can transfer mid-operation),
  in the same way as PodcastDirector, which checks `HostUserId` on every request. Builder previews and drags are
  cancelled, and build mode exits, on host loss, room switch, respawn or disconnect (tasks 3–4).
- **No LayoutRevision writes** from the builder (a static test rejects it in code). LayoutRevision
  forces the Wide shot. The builder keeps its own build revision.
- **Seats:** `Workspace.PodcastStudio.Seats.Seat1`–`Seat4` serve all rooms and are moved by
  `StudioLayout.Apply`. Catalog chairs are decorative and carry no functional Seat. A chair
  becomes a participant seat only through the task 7 anchor-assignment adapter, which must be
  occupant-safe. Pose profiles (e.g. couch poses) need explicit server validation there too.
- **Templates:** curated templates live in ServerStorage. Client cards and ghost previews need a
  server-published copy, to be designed in task 3 or 4. `Workspace.StudioAssetYard` is never a template source.

## Placement (task 3)

Server-authoritative placement in the single sandbox. Studio integration is pending.

| Piece | File | Role |
|---|---|---|
| Protocol | `src/shared/Protocol.luau` | Ops `Place`, `Move`, `Rotate`, `Duplicate`, `Delete`, their exact field sets, and error codes and messages |
| Transform | `src/shared/Transform.luau` | Strict transform check: finite numbers, yaw on the 15° grid, 0.01-stud position quantizing, and a full **yawed** footprint against room bounds. Shared with the client preview. |
| PlacementCore | `src/server/Core/PlacementCore.luau` | States `ready`, `busy` and `recovery`. Order per request: rate limit, strict payload, take the edit lock (`Busy` if held), host check, plan (catalog, installed template, entitlement, yawed bounds, cap 150), host re-check, `world.apply`, host re-check, commit model, `BuildRevision`, `world.commit`, release. The lock is taken before any injected (possibly yielding) dependency and released in exactly one place. Rejections before apply never touch state, world or revision. A failed rollback or finalize fails closed: the operation and token are kept, the response says `recoveryNeeded`, and edits return `RecoveryNeeded` until `recover()` succeeds (retry the operation, then `world.reconcile` from the model). The current host may edit every item; `placedByUserId` is metadata only. |
| RequestValidator / BuildModel / RateLimiter | `src/server/Core/*.luau` | Exact key sets (no Instances, colours, scales or paths), `i<n>` IDs never reused, token buckets |
| PlacedItemsWorld | `src/server/Runtime/PlacedItemsWorld.luau` | Two-phase apply, rollback and commit, plus `reconcile(entries)`, on `Workspace.StudioBuilderPlacedItems`. Clones curated templates, tags `BuildItemId`, `BuildCatalogId` and `BuildPlacedByUserId`, and publishes the `BuildRevision` attribute. |
| TemplateSanitizer | `src/server/Runtime/TemplateSanitizer.luau` | Strips code, ClickDetectors, prompts, drag detectors, remotes and bindables. Disables Seats, anchors parts. Previews also lose collision, query, touch, shadows, sounds, lights and effects. |
| BuilderService | `src/server/Runtime/BuilderService.luau` | Creates `Remotes.BuilderRequest`, the placed-items folder and `ReplicatedStorage.StudioBuilder.PreviewTemplates`. Retries recovery every 2 s while in `recovery`. Stays disabled (`Unavailable`) until a `StudioBuilderSandbox` marker exists. |

The template probe also rejects templates whose pivot isn't upright or isn't at the bottom centre of their bounding box.

### Decisions (Codex, 2026-10-25)

1. **Shared studio:** the current host can edit every placed item after a transfer. The former host is refused (`NotHost`). Undo history from a previous host must be invalidated (task 4).
2. **Rate limits:** the builder keeps its own bucket, separate from the Director's.
3. **Surface/collision policy:** overlaps and floating placement are allowed in the sandbox prototype. The UI snaps to surfaces by default (task 4). The server checks bounds only.
4. **Sandbox marker and room-switch gate:** Codex supplies the `StudioBuilderSandbox` marker and the live room-switch gate during integration. Until the marker exists, the builder answers `Unavailable`.
5. **StudioCustomization** still needs its live-script exclusion for `BuildItemId` and `StudioBuilderPlacedItems`.

## Build drawer and undo/redo (task 4)

Studio-pending: there's no installation or full Play UI test yet. The pure decision modules are tested.

| Piece | File | Role |
|---|---|---|
| Host sessions | `PlacementCore:onHostChanged()`, wired by BuilderService to `PodcastSettings.HostUserId` | Each host change bumps a host epoch and clears history immediately (A → B → A included, with no edit needed). Every request also compares `HostAuthority:currentHostUserId()` with the last host it saw, in case a signal is missed. The epoch is captured with the lock and re-checked with the host after every possibly-yielding step, so a change aborts with rollback (`AuthorityLost`). History is keyed by user, revision and epoch. Status offers undo/redo only to the current host. |
| Undo/Redo | `src/server/Core/PlacementCore.luau`, `BuildHistory.luau` | `Undo`/`Redo` ops plan like any edit: same lock, host checks, validation, world apply/rollback and recovery. Exact logical IDs are restored. A step that no longer applies is dropped with `HistoryConflict` (`reason` gives why) and never touches the world. History is cleared on host transfer, on any revision change it didn't make, and on entering recovery. `expectedRevision` makes stale or double clicks fail with `StaleRevision`. Depth: 50. |
| Status | `PlacementCore` | `{ op = "Status" }`, read-only and allowed for anyone. Every response carries `status = { state, canUndo, canRedo, revision }`. |
| PanelTheme | `src/client/UI/PanelTheme.luau` | The `docs/ui-contract.md` tokens, layout constants, `fit()`/`clamp()` and constructors for new builder UI only |
| BuildSession | `src/client/Build/BuildSession.luau` | Drawer state machine: placing/moving/selected, read-only, paused (RecoveryNeeded), and cancel on host loss, room switch, respawn or unexpected revision |
| PlacementPreview | `src/client/Build/PlacementPreview.luau` | Surface snapping (upward-facing floor, tabletop or placed item), grid snapping, and the same bounds rules as the server |
| BuildInput | `src/client/Build/BuildInput.luau` | Listen-only input. Text entry is always ignored. Escape cancels without being sunk. R and clicks fire only when unprocessed. E/Q, right mouse, 1–5, V and F are never handled. |
| BuildDrawer | `src/client/Build/BuildDrawer.luau` | The drawer, built only from PanelTheme in the contract layout: filters in the tab row, then rows for actions (Undo/Redo/Back/Done), selection (Move/Rotate/Duplicate/Delete), a placement hint (Place here on touch / Cancel) and ViewportFrame cards from `PreviewTemplates`. Not-installed cards are disabled. Draggable and clamped. |
| BuildController | `src/client/Build/BuildController.luau` | All client build-mode behaviour behind an injected `env`, so it can be tested with fakes:
- A **generation** guard on every yielding request: late results after close or reopen are discarded.
- **Opening** is tracked separately; close, host loss, room switch or respawn during `handoff:enter` cancels the open and exits the handoff.
- A failed handoff exit is kept, retried in the background and on `close`/`open`, and `open` refuses with `CleanupPending`.
- The ghost tracks its catalog ID.
- The **active input method** (mouse or touch) is tracked per input, so touchscreens with a mouse attached work.
- Presses inside the drawer are blocked explicitly.
- Viewport refit and drag cancel on focus loss. |
| BuilderClient | `src/client/BuilderClient.luau` | A thin Roblox binding: builds `env` and connects signals (host, room, respawn, input, viewport, focus, revision) once at load. API: `configure({ hooks, panel = { getPosition, onClosed }, roomSwitchSignal })`, `open() -> ok, reason` (`Unavailable`, `HandoffUnbound`, `HandoffFailed`, `Cancelled`, `CleanupPending`, `Opening`), `close()`, `isOpen()`. `onClosed` receives `{ x, y, reason, cancelled, cleanupFailed }`. |

### What Codex wires (nothing is guessed or auto-bound)

1. **Studio-page Build entry:** a button in the existing Studio tab calls `BuilderClient.open()`. If it returns
   `false, "HandoffUnbound" | "HandoffFailed" | "Unavailable"`, show that in the panel's status line.
2. **Hooks** via `BuilderClient.configure({ hooks = ... })`:
   - `camera`: e.g. `PodcastCameraHook.fromLocalPlayer()`, the verified `StudioCameraControl`;
   - `hostControls`: the PodcastCamera shortcut gate;
   - `hostDrawer`: the panel's exposed open/close;
   - `worldClickHandlers`: the panel world-picker gate.
   `camera` and `hostControls` are required, so open() fails closed without them.
3. **Panel position:** `panel.getPosition()` opens the drawer where the panel is. `panel.onClosed({ x, y, reason })`
   lets the panel keep or restore its position and show the exit reason.
4. **Room-switch gate:** optional `roomSwitchSignal`. `PodcastSettings.SceneSet` changes are also handled.

Done currently closes like Back. Task 5 adds the save, and a failed save will be visible and keep the drawer open.

## Save/load (task 5)

The build is saved as an additive `Build` section in the existing StudioPresets slots: no separate profile and no autosave. Exact install order, behaviour and the Studio checklist: [`docs/integration-task5.md`](integration-task5.md). `SaveBackends.memory()` from task 2 is no longer on any path.
