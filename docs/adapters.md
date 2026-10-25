# Builder adapters (task 2)

These are the narrow seams between the builder and live Studio systems. Each one is
dependency-injected where the live API hasn't been inspected yet. **Studio
integration is pending for all of them.** Only the pure logic has been exercised,
by `lua5.4 tests/run.lua`.

Rojo mapping (`default.project.json`): `src/shared` → `ReplicatedStorage.StudioBuilder`,
`src/server` → `ServerScriptService.StudioBuilder`, `src/client` →
`StarterPlayerScripts.StudioBuilder`. All three are new folders. Nothing in Workspace
or in the existing rooms is described or replaced.

| Adapter | File | Entry point | Injected | Live default |
|---|---|---|---|---|
| Catalog | `src/shared/Catalog.luau` | `Catalog.getItem(id)`, `getItemsTagged(tag)`, `validate()` | n/a (data) | 7 stable IDs; tags Cozy, 1980s, Retro, Winter, Futuristic |
| Entitlements | `src/server/Adapters/Entitlements.luau` | `Entitlements.new({resolvers}) :isItemUnlocked(userId, item, Catalog)` | `resolvers[kind](userId, entitlement) -> boolean` | Only `free`, so everything is unlocked. Unknown kinds fail closed. |
| Host authority | `src/server/Adapters/HostAuthority.luau` | `HostAuthority.new({getHostUserId}) :check(userId) -> allowed, reason` | `getHostUserId() -> number?` | `podcastSettingsSource()` reads `ReplicatedStorage.PodcastSettings:GetAttribute("HostUserId")`. No caching, so call it on every edit. |
| Template catalog | `src/server/Adapters/TemplateCatalog.luau` | `TemplateCatalog.build(Catalog, probe)`, then `:isInstalled(id)`, `:getSize(id)`, `:clientListing()` | `probe(itemId) -> {size={x,y,z}}?` (an error marks the entry invalid) | `serverStorageProbe()` looks for a Model named `<itemId>` in `ServerStorage.StudioBuilderTemplates` and rejects templates that contain scripts. Test fixtures load only when `Config.Dev.UseTestFixtures` is set, in Studio. |
| Room / sandbox | `src/server/Adapters/RoomProvider.luau` | `RoomProvider.new({resolve}) :resolve(player) -> {id, origin, bounds}?` | `resolve(player)` | `markerSource()` uses the Workspace part `StudioBuilderSandbox`. Sandbox only. |
| Save payload | `src/server/Adapters/SaveSnapshot.luau` | `encode(build)`, `decode(raw, {classify, maxItems})`, `checkSize(record)` | `classify(entry) -> boolean` | Schema `StudioBuilder.Build` v1, migrations table, 64 KB cap. Separate from StudioPresets. |
| Save backend | `src/server/Adapters/SaveBackends.luau` | `backend:load(userId)`, `backend:save(userId, record)`; `SaveBackends.check(b)` | any backend meeting the contract | `memory()` only, which is **not persistence**. DataStore is planned for task 5. |
| Build-mode handoff (camera mode) | `src/client/Adapters/BuildModeHandoff.luau` | `BuildModeHandoff.new({hooks}) :enter(context)`, `:exit()` | slots `camera`, `hostControls`, `hostDrawer`, `worldClickHandlers`, each `{enter(context), exit()}` | None. `camera` and `hostControls` are required, so build mode won't start until PodcastCamera and host-control hooks are bound. |

## Contracts from the 2026-10-25 inspection (not yet bound)

- **Camera:** PodcastCamera keeps sole ownership. The `camera` hook should go through
  `PodcastCameraUI.StudioCameraControl`. Its signature hasn't been inspected, so no call is written yet.
- **hostControls hook:** suppresses 1–5, V, F, auto-shot and seat controls. E/Q
  (free-camera vertical), Escape and right-mouse cursor release keep working. The builder
  binds only `R` and listens to `Escape` without sinking it. The tests enforce this.
- **hostDrawer / worldClickHandlers hooks:** hide the host drawer and disable existing world
  item and light click handlers while building.
- **Placed items** go in their own folder (`Config.PlacedItemsFolderName`), so
  StudioCustomization's pivot reset never touches them.
- **Seats:** catalog chairs are decorative. `Workspace.PodcastStudio.Seats.Seat1`–`Seat4`
  stay the only participant seats until the seat-anchor adapter (task 7) exists.
- **Saves** never write LayoutRevision (a static test rejects it in code) and never use StudioPresets slots.
- **Templates:** client visuals for curated ServerStorage templates (cards, ghost preview)
  still need a server-published copy. That's to be designed in task 3 or 4.
