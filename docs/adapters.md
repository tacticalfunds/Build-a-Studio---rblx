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
| Build-mode handoff | `src/client/Adapters/BuildModeHandoff.luau` | `BuildModeHandoff.new({hooks}) :enter(context)`, `:exit()` | slots `camera`, `hostControls`, `hostDrawer`, `worldClickHandlers`, each `{enter(context), exit()}` | `camera` and `hostControls` are required, so build mode won't start without them |
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
