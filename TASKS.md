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
- **UI must match the current in-game host panel** (user requirement, 2026-10-25): no redesign and no different visual style. Exact tokens, layout and UX rules are in [`docs/ui-contract.md`](docs/ui-contract.md).

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
| 3 | Server-authoritative placement and validation | 2 | Done (Studio pending) |
| 4 | Simple drawer UI, item editing and Undo/Redo | 3 | Pending |
| 5 | Save/load with failure protection | 3 | Pending |
| 6 | Integration README and Codex Studio playtest handoff | 4, 5 | Pending |
| 7 | Seat-anchor and camera-assignment adapter | 6 | Pending |
| 8 | More collection themes | 6 | Pending |
| 9 | Studio > Branding: image IDs on room or individual surfaces | 3, 5 (+ live panel/director/preset source) | Pending |

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
- Review fixes (code review of f279ac3, reproduced by Codex in Studio with real Luau):
  1. A hook that applied part of its change and then errored was never exited. Each attempted hook is now recorded as a cleanup handle before its `enter` runs.
  2. `exit()` during a yielded `enter()` returned done, and the resumed enter then went active and kept the camera. There is now an explicit state machine (inactive, entering, active, exiting) with a generation counter. Cancellation is checked after every hook, and `exit()` during entering returns `pending=true` while the entering thread rolls back. A second enter or exit while busy is refused or a no-op. A failed exit keeps its handle (`hasPendingCleanup()`), enter refuses until a retried `exit()` succeeds, and the retry uses the hook objects that were entered.
  Regression tests: `tests/spec/build_mode_handoff_regression_spec.lua` (8 tests; they failed on the old code and pass now). Putting each bug back makes its regression tests fail. Suite: **83 passed, 0 failed**.
- Needs live-script patches (Codex): a hostControls gate in PodcastCamera, the panel's shared open/close and world-picker gate, StudioCustomization skipping `BuildItemId`, and the Director restoring `Build` before overrides. Until the first two exist, build mode refuses to enter (required slots).

## 3. Server-authoritative placement and validation: Done (Studio integration pending)
A pure core handles the catalog whitelist, finite and bounded transforms, room bounds, the item cap, per-player rate limits, an edit check against HostUserId on every request, and edits limited to the player's own build items. A thin Roblox layer applies the results inside a dedicated builder folder.
- Status from Codex (2026-10-25): all seven catalog templates now exist in `ServerStorage.StudioBuilderTemplates` under the catalog IDs. They're anchored, have bottom-center pivots and no code, and any embedded Seats are disabled. `Workspace.StudioAssetYard` holds 49 labeled `EditorOnly=true` display copies (no scripts, Seats disabled). It's never a template source and is removed at play start by the bootstrap guard.
- Also: recheck host authority after every yield before committing. Use a separate build revision (never LayoutRevision). Tag placed models with `BuildItemId` inside `StudioBuilderPlacedItems`. Publish client-visible copies of curated templates.
- Acceptance: tests that actually run cover authorization, malformed payloads (Instances, NaN/inf, extra keys like color or scale, paths, oversized strings), cap and rate limits. Studio behavior is marked pending.
- Delivered: `src/shared/Protocol.luau`, `src/shared/Transform.luau`, `src/server/Core/{PlacementCore,RequestValidator,BuildModel,RateLimiter}.luau`, `src/server/Runtime/{PlacedItemsWorld,TemplateSanitizer,BuilderService}.luau`, and the bootstrap now starts BuilderService. The template probe checks for upright, bottom-centre pivots. Details: [`docs/adapters.md`](docs/adapters.md#placement-task-3).
- Evidence (executed 2026-10-25): `lua5.4 tests/run.lua` gives **108 passed, 0 failed** across 14 specs. New specs: `transform_spec` (yawed bounds, yaw grid, quantizing), `placement_core_spec` (17 tests), `template_sanitizer_spec` (fake instances).
  - Every rejection is checked to leave model, world, revision and world calls unchanged: non-host, malformed payloads (~33 kinds), unknown, uninstalled or locked items, out of bounds, cap, not found (ownership rejections were later replaced by the shared-studio decision).
  - Host change during apply rolls back spawn, move and remove. World apply failures are transactional. A concurrent request during apply gets Busy. Rate-limit burst and refill, per player.
  - Fuzz: 3000 mixed requests, 1229 committed, none threw. Bounds, cap, ownership and model-world agreement hold at the end.
  - Mutation checks: removing the host recheck, ignoring yaw in the footprint, mutating the model before apply, and dropping the ownership check each made tests fail (that check was later removed by the shared-studio decision). Dropping the installed check did not, because a missing template has no size and is still rejected as `NotInstalled`.
  - Test-quality fix: the fuzz initially committed 0 edits (low LCG bits alternate), so its invariants were vacuous. It now uses high bits, biases toward well-formed requests and asserts at least 300 commits. The SaveSnapshot fuzz got the same RNG fix.
- Not executed: everything touching Instances (PlacedItemsWorld cloning and pivots, BuilderService remotes and folders, preview publishing, the probe's pivot check, the bootstrap in Play). Lua 5.4 compile check only.
- Review blockers (code review of 9a2bb6a, reproduced by Codex in Studio Luau with an isolated fake world), fixed:
  1. The edit lock was taken only after planning, so A (yielding in the entitlement check) and B (yielding in world.apply) both allocated i1, and B's failed commit rolled back the world's i1. The lock is now taken before any injected dependency (the host check included) and released in one place for every outcome. The host is rechecked after planning, before any world change.
  2. A failed rollback after losing authority only logged and unlocked. The core now fails closed: the operation and token are kept, the state is `recovery`, the response carries `recoveryNeeded=true`, and edits get `RecoveryNeeded` until `recover()` succeeds (retry the operation, then `world.reconcile` from the model). A failed finalize (`world.commit`) and a model commit error whose rollback also fails take the same path. BuilderService retries every 2 s. `PlacedItemsWorld:reconcile` rebuilds the folder from the model.
  Regression tests: `tests/spec/placement_recovery_spec.lua` (10 tests). All failed on 9a2bb6a: blocker 1 reproduced as B getting `Internal` from its duplicate-ID commit. Mutations (lock after planning, failed rollback only logging, no reconcile fallback, edits allowed during recovery, no host recheck after planning) each make them fail. Suite: **118 passed, 0 failed**. Fuzz: 3000 requests, 1229 committed.
- Decision applied: the current host edits every item after a transfer, and the former host gets `NotHost`. `ownerUserId` became `placedByUserId` (metadata only); the `NotOwner` code was removed and `RecoveryNeeded` added.
- Studio evidence from Codex (2026-10-25): f54454d passed five real-Luau handoff regressions. The template probe recognizes all seven real templates. Real unparented Model clones of all seven passed spawn, move, pivot rollback, remove rollback, delete and sanitized previews in Studio. Nothing installed into the runtime yet. The recovery and reconcile paths added here haven't been run in Studio yet.
- Decisions (2026-10-25): separate builder rate limit; overlaps and floating placement allowed in the sandbox prototype, with UI surface snapping by default; shared studio editable by the current host. Codex supplies the sandbox marker and live room-switch gate during integration. Details in docs/adapters.md.

## 4. Simple drawer UI, item editing and Undo/Redo: Pending
- **Visual contract:** follow [`docs/ui-contract.md`](docs/ui-contract.md) exactly. That means the live panel tokens (`C.bg`, `card`, `teal`, `white`, `muted`, GothamMedium, 8 px buttons, selected = teal on `C.bg`), its layout and responsive fit, and its drag and touch behaviour. Add a Build entry inside the existing Studio tab; no fifth tab and no second host panel. The catalog drawer uses the same conventions, with Back/Done returning to the panel at its kept position. Theme filters Retro, 1980s, Futuristic, Cozy and Winter all share one button style. Add a shared theme/helper module for new builder UI only; don't rewrite the existing panel source.
- **Integration:** explicit callbacks and adapters only. The live `toggleOpen` is local (it updates `Drawer.Visible`, `launch.Text` and `PanelOpen`), so the `hostDrawer` hook waits for Codex to expose a callable open/close. Codex does the panel wiring and visual comparison.
Cozy and 1980s filters, ViewportFrame cards, and placement on a surface. A selected item can be moved, rotated, duplicated or deleted. Undo/Redo and Done. Grid snapping is on by default, R rotates 15°, and Escape cancels placement without swallowing UI controls. Undo/redo runs on the server, restores logical item IDs and handles rejected edits.
- Also: invalidate undo/redo history on host transfer (shared studio, current host edits everything). Snap placement to surfaces by default; the server allows overlap and floating. Handle `RecoveryNeeded` and `recoveryNeeded` responses by pausing edits with a visible message.
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

## 9. Studio > Branding: Pending
Requested 2026-10-25. Not started: it waits on the current panel, director and preset source from Codex, and builds on the host checks from task 3 and the saving from task 5.
- UX: a Branding section on the Studio page. The host enters a Roblox image asset ID and sees a preview. They then apply it either to the whole active room's branding, or by clicking or selecting eligible individual surfaces (wall signs, screens, mugs, laptop lids). Apply and Reset per room and per surface.
- Rules: host-authoritative, checked on the server for every apply or reset. Targets come from an allowlist of stable surface IDs, never arbitrary Instances or paths. Only image/decal content is set: never model or script loaders, `LoadAsset`, `require(id)` or arbitrary URLs. The asset ID must be a positive integer, turned into image content server-side. If an image is invalid or unavailable, the prior branding stays. Per-surface overrides are saved with the studio as an additive, versioned preset section, so older presets load unchanged.
- **Visual contract:** Branding sits inside the existing Studio tab, in the same row, heading and input style as the live panel ([`docs/ui-contract.md`](docs/ui-contract.md)). No new visual style.
- Context: laptop Apple logos were already replaced with existing geometric Roblox marks on 11 live and stored instances (Codex).
- Acceptance (draft): tests that actually run cover the asset-ID validation, target allowlist, host check, keeping prior branding on failure, and save/load of overrides including legacy presets. Studio-pending for preview and rendering.
