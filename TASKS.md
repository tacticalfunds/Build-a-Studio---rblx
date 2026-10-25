# Task queue: Build-a-Studio builder prototype

Ordered queue. **Only one implementation task is In progress at a time.** Update this file
before starting a task and after finishing it.
Statuses: `Pending` · `In progress` · `Blocked` · `Done`.

Standing constraints for every task:
- Don't merge to `main`, publish or deploy the Roblox game, or enable payments.
- Leave the six existing rooms and the live Podcast* systems untouched. The builder is a separate sandbox.
- Use only stable catalog IDs mapped to prepared templates. No `LoadAsset`, no `require(assetId)`, no HTTP loaders, no arbitrary asset IDs.
- "Studio-tested" status needs evidence from Codex. Until then, mark Studio behavior **pending**.
- Keep the code small enough to review. No framework.

Known contracts (from Codex, 2026-10-25):
- Host check: `ReplicatedStorage.PodcastSettings:GetAttribute("HostUserId")`, checked server-side on every edit.
- PodcastCamera owns the camera and exposes `PodcastCameraUI.StudioCameraControl`. Reach it only through an adapter hook. Its signature hasn't been inspected yet.
- Build mode suppresses 1–5, V, F, auto-shot and seat controls. E and Q stay as free-camera vertical controls. Escape and right-mouse cursor release keep working. Hide the host drawer and disable world item and light click handlers while building.
- StudioCustomization resets pivots from StudioBasePivot, so builder items go in their own folder and are excluded from it.
- The functional seats are `Workspace.PodcastStudio.Seats.Seat1`–`Seat4`, moved by StudioLayout. Catalog chairs are decorative until a seat-anchor adapter exists.
- StudioPresets has 5 slots and a 250 KB cap. Build snapshots get their own versioned adapter that preserves older data. Never write LayoutRevision per drag, because it resets the camera.

| # | Task | Depends on | Status |
|---|---|---|---|
| 1 | Index the current Studio assets | none | Done |
| 2 | Define narrow adapters (catalog, host, room, camera, save) | 1 | Done (Studio pending) |
| 3 | Server-authoritative placement and validation | 2 | Pending |
| 4 | Simple drawer UI, item editing and Undo/Redo | 3 | Pending |
| 5 | Save/load with failure protection | 3 | Pending |
| 6 | Integration README and Codex Studio playtest handoff | 4, 5 | Pending |
| 7 | Seat-anchor and camera-assignment adapter | 6 | Pending |
| 8 | More collection themes | 6 | Pending |

## 1. Index the current Studio assets: Done
Commit Codex's four snapshot files under `docs/assets/` with an index README.
- Acceptance: all four files committed byte-for-byte. README gives the place ID, snapshot date, what each file holds, reading rules and refresh steps. Counts checked locally: 39 guide entries, 6 rooms, 2594 model records, 448 content refs, 161 lights, 95 seats, 55 emitters, 2 sounds, 83 displays.
- Evidence: counts confirmed by a local JSON parse on 2026-10-25.

## 2. Define narrow adapters: Done (Studio integration pending)
Create `src/shared`, `src/server` and `src/client` with a Rojo project. Write adapter modules, each with a documented contract and a safe default. Contract table and the live-script follow-ups: [`docs/adapters.md`](docs/adapters.md).
- `Catalog`: the 7 stable IDs. Collections are tags (Cozy, 1980s, Retro, Winter, Futuristic), all `entitlement={kind="free"}`. Each `sourceRef` is checked against the asset guide.
- `Entitlements`: injected resolvers. `free` always unlocks, unknown kinds fail closed, no paywall.
- `HostAuthority`: `PodcastSettings.HostUserId`, no caching, fails closed.
- `TemplateCatalog`: curated `ServerStorage.StudioBuilderTemplates`. Each item is installed, not_installed or invalid. Fixtures are opt-in and Studio-only.
- `RoomProvider`: sandbox only, validated bounds.
- `SaveSnapshot`: an additive preset `Build={Version=1,NextId,Items={ {Id,CatalogId,Transform={X,Y,Z,Yaw}} }}` section. Preset Version stays 1, a missing Build means `NoBuild` (legacy), strict decode, migrations, unplaceable items preserved, 64 KB cap. `SaveBackends.memory()` only.
- `BuildModeHandoff` + `PodcastCameraHook` (verified contract): `StudioCameraControl:Fire("FreeCamera", true)` on enter, restores the previous shot and POV on exit, never re-enters Walk, adds no second camera writer.
- `AssetYardGuard` + `StudioBuilderBootstrap.server.luau`: removes only `Workspace.StudioAssetYard` at play or server start.
- Acceptance: each adapter has a single documented entry point. No Podcast* API is guessed beyond the verified contracts. Every file passes a compile check.
- Evidence (executed 2026-10-25): `lua5.4 tests/run.lua` gives **75 passed, 0 failed** across 11 specs. Mutation checks (host check, Build-section legacy path, camera restore, hook rollback) each made the targeted tests fail, then went back to green.
- Not executed: anything that needs real Instances (live PodcastSettings, PodcastCameraUI, ServerStorage templates, the sandbox marker, the yard removal in a real Play session). The Luau compiler wasn't available, so files are compile-checked as Lua 5.4 only.
- Needs live-script patches (Codex): a hostControls gate in PodcastCamera, the panel's shared open/close and world-picker gate, StudioCustomization skipping `BuildItemId`, and the Director restoring `Build` before overrides. Until the first two exist, build mode refuses to enter (required slots).

## 3. Server-authoritative placement and validation: Pending
A pure core handles the catalog whitelist, finite and bounded transforms, room bounds, the item cap, per-player rate limits, an edit check against HostUserId on every request, and edits limited to the player's own build items. A thin Roblox layer applies the results inside a dedicated builder folder.
- Also: recheck host authority after every yield before committing. Use a separate build revision (never LayoutRevision). Tag placed models with `BuildItemId` inside `StudioBuilderPlacedItems`. Publish client-visible copies of curated templates.
- Acceptance: tests that actually run cover authorization, malformed payloads (Instances, NaN/inf, extra keys like color or scale, paths, oversized strings), cap and rate limits. Studio behavior is marked pending.

## 4. Simple drawer UI, item editing and Undo/Redo: Pending
Cozy and 1980s filters, ViewportFrame cards, and placement on a surface. A selected item can be moved, rotated, duplicated or deleted. Undo/Redo and Done. Grid snapping is on by default, R rotates 15°, and Escape cancels placement without swallowing UI controls. Undo/redo runs on the server, restores logical item IDs and handles rejected edits.
- Also: cancel previews and drags, and exit build mode, on host loss, room switch, respawn or disconnect. Bind the handoff slots once Codex adds the panel and camera gates.
- Acceptance: tests run for undo/redo ID restoration and history conflicts. UI behavior is Studio-pending.

## 5. Save/load with failure protection: Pending
Versioned records, validated on load. A failed load keeps the current build and blocks saving. A failed save is shown to the player. Empty or failed loads never autosave over real data. Records newer than the current version are never downgraded. There are no LayoutRevision writes.
- Also: route the `Build` section through StudioPresets (`Persist` Save/Load, 5 slots, 250000-byte cap, entry Version 1). The Director must rebuild Build items before applying fixture and item overrides, and a missing Build keeps legacy loading.
- Acceptance: tests run for backend errors, corrupt records, newer versions, the empty-autosave guard and interleaved saves. Persistence through DataStore is marked untested.

## 6. Integration README and Codex Studio playtest handoff: Pending
Document the Rojo mapping, adapter wiring, protocol and security model, and list what is implemented versus Studio-pending. Write a playtest checklist for Codex.
- Acceptance: Codex can wire the adapters without reading the core code. Pending items are listed explicitly.

## 7. Seat-anchor and camera-assignment adapter: Pending
Turn chosen decorative chairs into seat anchors that work with StudioLayout and Seat1–Seat4. `StudioLayout.Apply` resets all four seat CFrames and the camera shots, so this needs an explicit anchor-to-seat assignment or coordinated Layout changes, occupant-safe moves, and pose-profile validation (e.g. couch poses) on both server and panel.
- Acceptance: none until the contracts are inspected. Until this task is Done, don't claim seating integration works. (Cassie offered help. This task is unclaimed.)

## 8. More collection themes: Pending
Starter, Retro, Winter, Futuristic, Executive and Broadcast, drawing on the asset index once Codex promotes templates.
- Acceptance: catalog entries only for templates Codex has prepared. Still free.
