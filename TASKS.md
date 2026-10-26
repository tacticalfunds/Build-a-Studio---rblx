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
| 4 | Simple drawer UI, item editing and Undo/Redo | 3 | Done (Studio pending) |
| 5 | Save/load with failure protection | 3 | Done (installed; real DataStore/text filter pending) |
| 6 | Integration README and Codex Studio playtest handoff | 4, 5 | Done (playtest pending) |
| 7 | Seat-anchor and camera-assignment adapter | 6 | In progress (foundation for review; wiring pending) |
| 8 | More collection themes | 6 | **49 installed**; all 10 new items passed remote Place→Rotate→Delete in Play (physical UI/visual checks unverified); 10 candidates tracked, not registered; batch 02/03 candidates; Executive/Broadcast pending |
| 9 | Studio > Branding: image IDs on room or individual surfaces | 3, 5 (+ live panel/director/preset source) | Pending |
| 10 | Structure pieces: walls, floors, ceilings, doorways, windows | 3, 4, 8 (+ Codex measurements) | In progress (14 pieces and R rotation installed; remote-tested in Play; physical R-key/UI, visual QA and doorway clearance pending) |
| 11 | Existing room assets in Build (user request) | 8 (+ inspected manifest from Codex) | Pending: awaiting an inspected manifest |

**User priority (2026-10-25): keep expanding the model catalog.** Codex prepares and inspects candidates. Each set is registered in its own bounded checkpoint (manifest, catalog entries, tests), then installed and Play-checked by Codex. The queue order above is otherwise unchanged.

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
- Studio evidence from Codex after 4616648: 26 placement and recovery tests (16 placement, 10 recovery) passed in real Studio Luau. Fuzz there: 3000 requests, 1183 commits. Real unparented Instance reconciliation passed for all 7 prepared models: detached rebuild, stray removal, pivot correction, empty reconciliation and placement attribution. There's no installation or full Play UI test yet.
- Decisions (2026-10-25): separate builder rate limit; overlaps and floating placement allowed in the sandbox prototype, with UI surface snapping by default; shared studio editable by the current host. Codex supplies the sandbox marker and live room-switch gate during integration. Details in docs/adapters.md.

## 4. Simple drawer UI, item editing and Undo/Redo: Done (Studio and Play pending)
- **Visual contract:** follow [`docs/ui-contract.md`](docs/ui-contract.md) exactly. That means the live panel tokens (`C.bg`, `card`, `teal`, `white`, `muted`, GothamMedium, 8 px buttons, selected = teal on `C.bg`), its layout and responsive fit, and its drag and touch behaviour. Add a Build entry inside the existing Studio tab; no fifth tab and no second host panel. The catalog drawer uses the same conventions, with Back/Done returning to the panel at its kept position. Theme filters Retro, 1980s, Futuristic, Cozy and Winter all share one button style. Add a shared theme/helper module for new builder UI only; don't rewrite the existing panel source.
- **Integration:** explicit callbacks and adapters only. The live `toggleOpen` is local (it updates `Drawer.Visible`, `launch.Text` and `PanelOpen`), so the `hostDrawer` hook waits for Codex to expose a callable open/close. Codex does the panel wiring and visual comparison.
Cozy and 1980s filters, ViewportFrame cards, and placement on a surface. A selected item can be moved, rotated, duplicated or deleted. Undo/Redo and Done. Grid snapping is on by default, R rotates 15°, and Escape cancels placement without swallowing UI controls. Undo/redo runs on the server, restores logical item IDs and handles rejected edits.
- Also: invalidate undo/redo history on host transfer (shared studio, current host edits everything). Snap placement to surfaces by default; the server allows overlap and floating. Handle `RecoveryNeeded` and `recoveryNeeded` responses by pausing edits with a visible message.
- Also: cancel previews and drags, and exit build mode, on host loss, room switch, respawn or disconnect. Bind the handoff slots once Codex adds the panel and camera gates.
- Acceptance: tests run for undo/redo ID restoration and history conflicts. UI behavior is Studio-pending.
- Delivered:
  - Server: `Undo`/`Redo`/`Status` ops and `BuildHistory`. Undo and redo plan through the same lock, host checks, validation, world apply/rollback and recovery, and restore exact logical IDs. Conflicts are dropped with `HistoryConflict` and the world untouched. History is invalidated on host transfer, unexpected revisions and recovery. `expectedRevision` gives `StaleRevision`. Sandbox origin and size are published as attributes for the client preview.
  - Client: `UI/PanelTheme` (contract tokens and layout), `Build/BuildSession`, `Build/PlacementPreview`, `Build/BuildInput`, `Build/BuildDrawer`, `BuilderClient`. Details and Codex wiring steps: [`docs/adapters.md`](docs/adapters.md#build-drawer-and-undoredo-task-4). Contract interpretations to check: [`docs/ui-contract.md`](docs/ui-contract.md#implementation-notes-task-4-to-check-during-the-visual-comparison).
- Evidence (executed 2026-10-25): `lua5.4 tests/run.lua` gives **156 passed, 0 failed** across 18 specs.
  - `placement_history_spec` (17 tests):
    - undo/redo of place, delete, move, rotate and duplicate with exact IDs;
    - redo cleared by a new edit; rejected and no-op edits not recorded; nothing-to-undo/redo leaves state unchanged;
    - conflicts (locked collection, removed template, diverged item) dropped with world and state untouched, and the chain continuing;
    - host transfer clearing history for both hosts; stale `expectedRevision` refused without consuming history;
    - authority lost or world failure during undo keeps the step; undo rollback failure enters recovery and clears history;
    - redo serialized by the lock; depth limit; Status read-only for anyone, and every response carries status.
  - `client_ui_spec` (21 tests):
    - contract tokens and layout numbers, responsive fit and drag clamp;
    - floor and tabletop snapping, grid on/off, walls rejected, preview invalid exactly where the server rejects;
    - text-entry safety, Escape listen-only, E/Q/RMB/1–5/V/F never handled;
    - session flows, the RecoveryNeeded pause and resume, and cancel on host loss, room switch, respawn or unexpected revision.
  - The placement fuzz now includes undo/redo: 3000 requests, 1337 committed, model and world consistent.
  - Mutation checks each made tests fail: redo with a new ID, conflict not dropped, history kept across host transfer, no stale-revision check, history kept through recovery, re-create skipping the entitlement check, Escape ignored when processed, walls accepted as surfaces.
- Not executed: BuildDrawer and BuilderClient (Instances, raycasts, input, ViewportFrames), the Studio-page entry and live hook binding (Codex), full Play UI. Lua 5.4 compile check only.
- Codex wiring needed: the Build button in the Studio tab calls `BuilderClient.open()`; `configure({ hooks = { camera, hostControls, hostDrawer, worldClickHandlers }, panel = { getPosition, onClosed } })`; visual comparison against the live panel.
- Review findings (3d6519f), fixed:
  - **Server P2:** history only re-synced on the next host edit, so A → B (Status only) → A let A undo, and A's status said canUndo while B was host (reproduced in Studio Luau). Fix: a host-session epoch. `onHostChanged()` is wired to `PodcastSettings.HostUserId` and clears history at the change. A `currentHostUserId()` readback on every request catches missed signals. The epoch is re-checked with the host after every yielding step (rollback with `AuthorityLost`). History is keyed by user, revision and epoch, and status offers undo/redo only to the current host.
  - **Client P1-1 / P2-6:** client logic moved to `Build/BuildController` (injected env). A generation guard on every yielding request (edits, the initial Status, recovery polls) discards results after close or reopen. BuildSession ignores responses once closed, and ignores status older than the newest known revision.
  - **P1-2:** the ghost tracks its catalog ID and is replaced on a mismatch. Placement uses only a preview computed for the current item.
  - **P1-3:** opening is tracked separately, and cancel listeners are bound once at load (before any yield). Close, host loss, room switch or respawn during `handoff:enter` cancels the open, exits the handoff and creates no UI.
  - **P2-4 / P2-5:** the active input method is tracked per input. Taps preview and Place here confirms, mouse polling never overwrites a touched point, and the preview row now has Rotate.
  - **P2-7:** a failed handoff exit is reported (`cleanupFailed`), retried in the background and on `close`/`open`, and `open` refuses with `CleanupPending` until it succeeds.
  - **UI:** viewport resize and orientation refit plus re-clamp; explicit blocking of presses over the whole drawer; drag cancelled on focus loss and on release anywhere.
- Evidence (executed 2026-10-25): `lua5.4 tests/run.lua` gives **179 passed, 0 failed** across 20 specs.
  - `host_epoch_spec` (7 tests): the exact A → B (Status only) → A no-intervening-edit case, status without authority, a missed signal caught by readback, an epoch change during a yielding undo and during a yielding place (both rolled back), and the same host keeping history. The first five failed on 3d6519f for the reported reason: the undo succeeded and status said canUndo.
  - `build_controller_spec` (16 tests) drives the real BuildController and a real BuildModeHandoff with coroutine fakes: a late Place after close and after close + reopen, ghost A → B, cancellation during a yielding enter by close, host loss, room switch and respawn, touchscreen with a mouse, the Rotate button, an old-session Status poll, a stale-revision status, the initial Status after close, cleanup failure and retry, the drawer press block, refit/drag cancel, and panel position.
  - "Fails without the fix" for the client: the old BuilderClient wasn't injectable, so each original bug was put back into the extracted controller. Every one made its tests fail (late responses applied 4, ghost reuse 1, close during opening ignored 2, mouse overwriting touch 1, stale status applied 1, cleanup failure discarded 2, drawer press not blocked 1, no refit/drag cancel 1).
  - Server mutations caught: no epoch recheck (2), no missed-signal readback (1), status ignoring authority (1, after adding a no-readback case). An `onHostChanged` that doesn't clear history isn't caught on its own, because history is also epoch-keyed (redundant layers).
  - Test-quality fix: the old-session Status poll test first resumed the held request before close (passing vacuously). It now asserts the poll is suspended inside that request.
- Studio evidence from Codex (before these fixes): all 43 server placement, recovery and history tests passed in real Studio Luau, and a 3000-request fuzz made 1263 commits. The UI findings came from static review; nothing has been Play-tested yet.
- Not executed: BuilderClient bindings, BuildDrawer Instances (Rotate button, refit, hit test, drag), real raycasts and input, and full Play. The P2-5 Rotate button and the drawer-side refit/hit test are static UI changes; only the controller's use of them is tested.
- Final follow-up (review of f6facd3; 50 existing server regressions passed in real Studio Luau):
  1. **P1 stale cleanup worker:** a background retry from a failed close could wake after a successful reopen and exit the NEW active handoff, because `hasPendingCleanup()` is also true for active handles. Fix: failed cleanup now means an inactive handoff that still holds handles. Workers are scoped to a cleanup generation, which a successful cleanup, a newer worker or a new open invalidates. Every wake re-checks generation, opening/open state and failed-cleanup state, and the shared `cleanupRetrying` flag is gone, so a stale worker can't reset it. Regression: failed close, worker waits, successful reopen, old worker wakes. The new handoff stays active, no exit hooks run, and edits still go through. That test failed on f6facd3 (2 extra exit hooks). A second test shows a newer worker completing after an older one goes stale. The three worker guards are deliberately redundant: removing any single one is covered by the others, and removing all three makes both tests fail.
  2. **P2 epoch compared before a yielding authority read:** `_stillAuthorized` now reads authority first (it may yield), then observes the host, and compares the epoch last. Regression: the post-apply authority check yields, the host goes A → B → A, then it resumes. The result is `AuthorityLost`, the world is rolled back and the revision stays 0. On f6facd3 it committed with `ok=true`. Putting the old ordering back makes it fail.
  - Suite: **182 passed, 0 failed**. UI and style unchanged.
- Controller regressions (audit of f6facd3; 37 client/controller tests were green in Studio Luau before 49541db, and these two failed there):
  1. **P2 pending Place overwrote a newer choice:** choose A, Place A pauses, choose B, A succeeds. B's preview was discarded and `itemId` became nil. Fix: an interaction (intent) counter, bumped by choose, move, cancel, preview rotate and select. A response arriving after the intent changed still updates status, undo/redo, revision and pause, but never mode, selection or the chosen item. Nothing is blocked and the UI is unchanged. Regression: the exact sequence. B is still placing, its ghost is kept, status is applied, and B is placed next. A second test confirms that without a newer choice the placed item is still selected. Ignoring the intent makes the regression fail.
  2. **P2 close during a yielding `createDrawer` leaked UI:** open now stays "opening" through handoff enter, `createDrawer` (`WaitForChild` on PlayerGui) and `panel.getPosition`. The drawer stays local until the generation checks pass, a cancelled open destroys only its own drawer, never calls the panel and never touches a newer session. Regressions: close during `createDrawer` (UI destroyed, `Cancelled`, handoff exited, `getPosition` never called); close and reopen while the first creation is pending (stale drawer destroyed, new drawer and handoff untouched); close during `getPosition`. Mutations each caught: no check after `createDrawer`, no check after `getPosition`, and clearing "opening" before drawer creation (the old order).
  - Suite: **187 passed, 0 failed**. UI and style unchanged.


## 5. Save/load with failure protection: Done (Studio install and DataStore pending)
Versioned records, validated on load. A failed load keeps the current build and blocks saving. A failed save is shown to the player. Empty or failed loads never autosave over real data. Records newer than the current version are never downgraded. There are no LayoutRevision writes.
- Also: route the `Build` section through StudioPresets (`Persist` Save/Load, 5 slots, 250000-byte cap, entry Version 1). The Director must rebuild Build items before applying fixture and item overrides, and a missing Build keeps legacy loading.
- Acceptance: tests run for backend errors, corrupt records, newer versions, the empty-autosave guard and interleaved saves. Persistence through DataStore is marked untested.
- Delivered: the Build section inside the existing StudioPresets (5 slots, 250000 bytes, entry Version 1); no new profile, no autosave, and Done just leaves the builder.
  - `PlacementCore`: `captureBuild`, `prepareLoad` (stages without mutating; preserves unplaceable entries), `loadBuild` (the same exclusive path as edits, via the new two-phase world `replace`) and `revertLoad`. The tail of `_locked` became the shared `_executePlan`.
  - `BuildPersistence`: the Director API. `PresetSlotGuard`: overwrite rules and a retry-safe transform. `PlacedItemsWorld`: the `replace` effect. `BuilderService.getPersistence()`.
  - Integration: `integration/StudioPresets.luau` (only `Save` changed, diff-checked against the live source) and `integration/PodcastDirector.persistence.luau` (one require, plus `snapshot()` and `restoreSnapshot()`, whitespace-diff-checked; `persistentAction` unchanged). Install order and checklist: [`docs/integration-task5.md`](docs/integration-task5.md).
- Evidence (executed 2026-10-25): `lua5.4 tests/run.lua` gives **217 passed, 0 failed** across 22 specs.
  - `build_persistence_spec` (17 tests):
    - additive save shape; visible save failure while busy, in recovery and when oversized; no DataStore writes anywhere in the builder source;
    - load round trip with exact IDs and history cleared; no ID reuse;
    - corrupt, NaN and newer Builds fail before any change; legacy presets untouched;
    - unplaceable entries preserved, counted against the cap and written back;
    - A → B → A during the world replace rolls back; edits, saves and a second load are serialized; replace failure leaves the build unchanged;
    - a failed rollback enters recovery, which restores the old build; revertLoad is exact and refused after an edit;
    - Director-order contract (a room failure reverts the build; a build failure never touches the room or the text filter); builder unavailable.
  - `preset_slot_guard_spec` (12 tests):
    - guard rules (legacy, same-version, corrupt profile, newer or invalid Build, Build would be lost); the transform never mutates and resets its refusal on every call;
    - the **actual patched StudioPresets executed** against a fake DataStore: Save/Load/List, a newer-Build refusal that is visible (with position prefix) and writes nothing, a corrupt profile kept, legacy slots overwritten with other slots preserved, UpdateAsync retries in both directions, and the 250000-byte cap.
  - Mutations caught: a non-reset refusal, overwritable newer Builds, a mutating `withSlot` (original behaviour), corrupt profile replaced (original behaviour), unplaceables not preserved, capture ignoring busy/recovery, revert ignoring edits, ID reuse, preserved entries not counted, patched Save ignoring the refusal.
- Not executed: real DataStore calls, the Director patch in a live server (only its ordering contract is tested), text filtering, a Studio install, Play.
- Deliberate behaviour change for review: the patched Save refuses a non-table profile or Slots table (the old code replaced the whole profile, losing all five slots).
- Live integration (Codex, 2026-10-25): Host Panel > Studio > OPEN BUILDER works in Play and the drawer matches the existing UI. Under `StreamingEnabled=true` the build floor and objects streamed out (avatar in the Boardroom, build camera at (2024, 23, 29)). Runtime fix in this checkpoint: `PlacedItemsWorld` sets `ModelStreamingMode = Persistent` on every placed model after sanitizing and before parenting (spawn, build-load replace, reconcile respawn), and reconcile re-applies it to kept models. Codex makes the sandbox Model and the 7 templates persistent in Studio, and room assets stream normally. This is a deliberate bounded-prototype choice, documented in docs/adapters.md. Tested with fake Instances in `placed_items_world_spec` (3 tests; property-write order shows Persistent is set before Parent; removing it from the build path or the reconcile path makes tests fail). The isolated MCP `require` reporting `HandoffUnbound` is a separate module instance (expected fail-closed), not a live wiring fault. Suite: **220 passed, 0 failed**.
- Review corrections (review of 339180e; live task 4 now verified in Play: Place/Move/Rotate/Duplicate/Delete/Undo/Redo, plus Done restoring shot 0 and the host drawer; streaming fix verified for replication and floor raycasts):
  1. **P1 compound load wasn't atomic:** the Director logic moved into `integration/DirectorPersistence.luau` (live code, dependency-injected), and the Director edit now just constructs it. A load is one transaction: the trusted pre-load room state is captured (all settings plus current and target scene overrides), and `PlacementCore:beginTransaction` holds the edit lock across the build swap and the room restore. A final host and epoch check runs after the yields. Any failure restores the room without re-filtering text and rolls the build back; a failed rollback latches saving and leaves the builder in recovery. `commitLoad` and `revertLoad` were removed.
  2. **P2 preparation unbound:** `prepareLoad` binds the host epoch and build revision, and `begin` re-checks them. A → B → A during text filtering is refused before any mutation, legacy room-only loads included.
  3. **P1 slot guard:** it now also refuses newer or invalid record Version, snapshot Version and types (all four reproduced cases plus more), on every UpdateAsync retry.
  4. **Save-block latch:** after any failed load (corrupt, newer, backend read failure, rollback failure), Save and Share are refused until a successful load or the `DiscardLoadBlock` action.
  5. **Save feedback:** the slot-list refresh is separated from the write, so a successful save is never reported as failed.
- Evidence (executed 2026-10-25): `lua5.4 tests/run.lua` gives **234 passed, 0 failed** across 24 specs.
  - `director_persistence_spec` (10 tests) drives the **actual DirectorPersistence callbacks** with the real patched StudioPresets on a fake DataStore, the real BuildPersistence, PlacementCore and transaction on a fake world, a fake room (settings, two scenes of fixtures and items, an `applyAll` that can yield or fail) and a yielding text filter. It covers: round trip; room failure with exact room, fixture and build rollback, no re-filtering, Save and Share latched, and discard; builder edits and capture blocked during a yielding `applyAll`; A → B → A during filtering for build and legacy presets; authority lost during `applyAll`; a failed build rollback latching and keeping recovery; corrupt and newer builds stopping before filtering; a backend read failure latching and a successful load clearing it; a list-refresh failure not misreporting the save; unchanged cooldown.
  - `build_persistence_spec`: ported to the transaction API, plus binding (A → B → A, revision), lock-holding and non-host tests. `preset_slot_guard_spec`: the four reproduced records (plus three more) and a patched-Save retry case.
  - "Fails without the fix": the previous guard fails both new guard tests. Putting back no room rollback, lock release before the room restore, no final authority check, no binding check, no latch, the original List-in-the-same-pcall, and Share unlatched each makes tests fail. The Share check first passed vacuously (it read stale feedback); the assertion was strengthened and now catches it.
- Not executed: real DataStore, the Director edit in the live script, real text filtering, Studio, Play.
- Recovery checkpoint (review of e30e8be; the 10 Director tests and 6 slot-guard checks passed in real Studio Luau; three new real-Luau regressions blocked installation):
  1. **A room rollback failure didn't hold recovery:** with `applyAll` throwing during both load and rollback, the core returned to ready, Place worked, and Discard then Save wrote a slot. Now `Transaction:rollback(external)` puts a failed room restore into a shared `compound` recovery (captured room + build). Edits, saves, loads and Discard are refused for every host, across host transfer, and only a successful `recover()` (room restore, then world rollback or reconcile) clears it.
  2. **A finalize failure was reported as a successful load:** `restoreSnapshot` now raises "the build is still being restored", the latch stays `BuildRecovery`, and saving stays paused until reconciliation really succeeds.
  3. **`beginTransaction` raced:** it checked READY, then yielded in authority validation before setting BUSY. It now takes the lock first and releases it on every refusal or error.
  - `rememberLighting` (source provided): the `roomLooks` entry for the current scene is captured and restored exactly, including absence, via `getRoomLook` / `setRoomLook` closures in the Director construction block.
- Evidence (executed 2026-10-25): `lua5.4 tests/run.lua` gives **239 passed, 0 failed**.
  - New in `director_persistence_spec`: compound recovery (double `applyAll` failure; edits and saves blocked for A and, after transfer, for B; Discard refused; recovery restores the captured room and lifts the block); finalize failure reported as incomplete and blocked until reconciled; two concurrent `begin`s with a yielding authority check (the second is refused, rollback releases only the first); a refused `begin` after a yield releases the lock; the `roomLooks` entry restored exactly. The first four failed on e30e8be as reported.
  - Putting the original bugs back: ignoring the owed room restore, reporting a finalize failure as success, the old lock ordering, and allowing Discard/Save during recovery each make tests fail. Clearing the latch without recovery isn't caught on its own, because the recovery check runs first and already refuses (a redundant layer).
- Room-mutation gate (review of ce59b1d): during a yielding room restore inside compound recovery, `layoutBusy` was false, so a normal room command survived and `recover()` returned true with mixed state.
  - `DirectorPersistence.roomMutationBlocked()` is true while any `restoreSnapshot` is in flight (counted, released on error) or the builder's recovery is unresolved. It reads the core's recovery state, which holds through every attempt (background, Persist-triggered or direct), including yields, until room and build are both restored. It isn't a toggled flag.
  - Director wiring (step 4 of the patch file): refuse every non-Persist action on the gate, right after the existing `layoutBusy` line; re-check the gate and `layoutBusy` in the Text branch after the filter returns. Persist (List, retries) and builder Status stay open. Core behaviour unchanged. The handler's parameter names and the Text branch's exact shape weren't provided, so the edits are written against placeholders.
- Evidence (executed 2026-10-25): `lua5.4 tests/run.lua` gives **243 passed, 0 failed**.
  - 4 new `director_persistence_spec` tests drive a simulated live handler (the existing `layoutBusy` gate, plus the documented edits) against the real DirectorPersistence, core and StudioPresets:
    - Set, Fixture, Item, Look, Text and another player's command are all refused during a background `core:recover()` yielded in `applyAll`, with `layoutBusy` false; List, Status and the Save refusal still work; the room afterwards deep-equals the captured state, and the gate then lifts;
    - an attempt that yields and fails keeps the gate closed, and a Persist-triggered retry yielding in `applyAll` holds it;
    - a Text filter in flight when a load fails into recovery is refused on return, and the text never lands;
    - a Text filter returning during a direct `restoreSnapshot` (no `layoutBusy`) is refused, and the count is released after success and after an error.
  - Mutations caught: gate always open (the old handler; all 4 fail), loads not counted, recovery state ignored, the Text re-check limited to player/host (the current live branch), the count not released on error, and a retry wrapped in a toggled flag (3 fail).
- Not executed: the handler edits in the live Director, real text filtering, Studio, Play.
- Studio state noted: the working Studio stays at 62f2f87 plus host-panel, camera and streaming patches, with a full-place and 42-script checkpoint saved. The CRT asset `retro_crt_tv_01` is prepared; catalog registration comes later.
- Not executed: real DataStore, the Director edit in the live script, Studio, Play.


## 6. Integration README and Codex Studio playtest handoff: Done (playtest pending)
Document the Rojo mapping, adapter wiring, protocol and security model, and list what is implemented versus Studio-pending. Write a playtest checklist for Codex.
- Acceptance: Codex can wire the adapters without reading the core code. Pending items are listed explicitly.
- Delivered: [`README.md`](README.md), covering:
  - status at a glance, the Rojo mapping and the install order;
  - the live patch points in the working Studio:
    - both Director gates (installed at bb3efa6);
    - StudioPresets;
    - the host panel (OPEN BUILDER, hooks, no Discard button yet, so a successful Load is the only way to lift the save block);
    - the camera (camera and hostControls slots);
    - streaming;
  - protocol and security model, and a save/load summary;
  - verification split into executed here, real Studio Luau, Play (with the memory-stand-in and no-text caveats) and **not verified** (real DataStore, text filtering, multiplayer, forced live failures, touch, StudioCustomization exclusion, room-switch gate);
  - the remaining Codex playtest checklist, and catalog status.
  `docs/integration-task5.md` status updated to point at it.
- Codex evidence recorded (bb3efa6):
  - **Install:** installed in Studio Edit; the 19 Director tests and five independent regressions pass in real Luau; nine files compile.
  - **Play:** the server starts ready; Place, Undo, Redo and Delete work over the RemoteFunction; the Director Save/Load round trip worked (`i2` at (4, 0, -4), yaw 15, Theme Teal) and cleared history; a failed Load then Save was refused, with no second write.
  - **Caveats:** StudioPresets was replaced by memory stand-ins (no real DataStore), the fake Load had no text fields, and UI mouse automation stalled.
- Not documented from source: the exact panel, camera and streaming patch code lives only in the Studio checkpoint. The README describes each patch's contract and what was reported, and lists unreported items (StudioCustomization exclusion, room-switch gate, per-key hostControls suppression) as checks.
- No code changed in this task. `lua5.4 tests/run.lua`: 243 passed, 0 failed.

## 7. Seat-anchor and camera-assignment adapter: In progress (foundation for review; wiring pending)
Turn chosen decorative chairs into seat anchors that work with StudioLayout and Seat1–Seat4. `StudioLayout.Apply` resets all four seat CFrames and the camera shots, so this needs an explicit anchor-to-seat assignment or coordinated Layout changes, occupant-safe moves, and pose-profile validation (e.g. couch poses) on both server and panel.
- Acceptance: none until the contracts are inspected. Until this task is Done, don't claim seating integration works. (Cassie offered help. This task is unclaimed.)
- Foundation checkpoint (2026-10-25), grounded in the installed bb3efa6 source (45 scripts) Codex attached:
  - **Reference:** stored verbatim at `docs/studio-reference/Studio_Persistence_bb3efa6_Source_Backup.json`, with an index (`docs/studio-reference/README.md`: paths, classes, hashes, commit, PlaceId). It's a reference, not a sync source.
    All 34 comparable installed scripts (32 StudioBuilder modules, plus DirectorPersistence and StudioPresets) are identical to the repository at bb3efa6.
    The full-place RBXL is still the 62f2f87 baseline; the JSON backs up bb3efa6 scripts only.
  - **`src/shared/SeatProfiles.luau`:**
    - an explicit seat-profile table, **shipped empty** (decorative by default), with strict validation;
    - Chair and Couch pose profiles mapped to the live PodcastPoses modes. Couch is gated, because live PodcastPoses is Lounge-only.
  - **`src/server/Core/SeatAssignments.luau`** (pure, not wired): four slots (Host, Guest 1–3 = Seat1..4) map to (placed item ID, approved anchor ID).
    - Validates host and host-session epoch, slot range, an existing item, a configured profile, the anchor, pose support, unique anchors, occupied-seat protection (an unreadable occupancy counts as occupied) and stale revisions.
    - `checkEffect` gates the real PlacementCore effect kinds:
      - Move, Rotate and Undo/Redo moves re-anchor, or are refused when occupied;
      - Delete and Undo-of-Place are refused while assigned;
      - a load replace is refused while occupied.
    - `reconcile` preserves and later promotes. `resolve(stageActive)` covers room switching.
    - Additive versioned `BuildSeats` section: legacy-compatible; newer and corrupt versions refused; unknown profiles, missing items and conflicts preserved and written back, never silently dropped. Load is staged, then committed with an occupancy re-check.
  - **`Config`:** `SeatSectionKey`, `SeatSectionVersion`, `SeatSlotCount`, `MaxSeatEntries`, `MaxSeatAnchorIdLength`.
  - **Plan:** `docs/task7-seat-plan.md` covers:
    - the live contracts;
    - decisions needed: the builder stage as a SceneSet, the 120-stud check against Seat1, the couch pose gate, camera shot offsets, the reservation race;
    - runtime hooks H1–H8, all **not implemented**. The key constraint: re-anchoring must not call `Layout.Apply`, because `LayoutRevision` forces Wide and closes the builder.
  - **README:** the hooks are now verified from source.
    - The panel wraps PodcastCameraHook and adds a `BuildCamera` action.
    - hostControls is the `StudioBuilderActive` attribute; hostDrawer and worldClicks share `BuildModeActive`; roomSwitchSignal is `LayoutRevision`. No Discard button.
    - StudioCustomization's isolation comes from root traversal only, with no tag guard; a defensive guard is flagged.
- Evidence (executed 2026-10-25): `lua5.4 tests/run.lua` gives **259 passed, 0 failed** (25 specs).
  - New in `seat_assignments_spec` (16 tests):
    - contract checks parsed from the attached live source;
    - profiles and validation; assign/unassign rules, host transfer and A → B → A;
    - real PlacementCore effects for Move, Rotate, Undo, Redo, Duplicate, Delete and Undo-of-Place, plus a real build-load replace through BuildPersistence;
    - reconcile and promotion, room-switch resolve;
    - save decode refusals; load classification, round trip and revival with later profiles; commitLoad occupancy; the section bound.
  - 18 mutations caught, among them: occupancy ignored or failing open, remove allowed, move ignoring occupancy, reconcile or load dropping entries, epoch not checked, uniqueness off, couch ungated, commitLoad ignoring occupancy, resolve ignoring the stage, a newer version accepted, no bound, promotion onto an occupied seat, preserved entries never superseded, unknown keys accepted, offset aliasing, load conflicts undetected.
- Not executed: any Roblox Instance, seat movement, occupied avatars, poses or camera shots; live wiring; real anchor metadata (Codex supplies it).
- Schema corrections (review of 9c64fd0; 14 pure tests passed in real Studio Luau, and the 2 snapshot-file contract tests were skipped there):
  1. `SeatAssignments.decode` now refuses any section key other than `Version` and `Assignments` (`Corrupt`). `FutureMetadata` was accepted, then dropped on re-save.
  2. `SeatProfiles.checkProfile` now refuses any profile key other than `Version`, `PoseProfile` and `Anchors` (`UnknownKey`, and the profile stays decorative). `Scale = 99` was accepted.
  - The synchronous-dependency contract is documented in the module header and the plan: no yields under the lock, or a final epoch and revision re-check before committing. A yielding `getItem` reproducing a stale-host assignment is outside that contract.
  - The wiring decisions are recorded in `docs/task7-seat-plan.md` §3, not implemented: Builder scene entry, sit distance from the requested seat, server-owned reservations with cleanup, Couch disabled, chair profile first, free-room camera formula as a candidate, unassigned Builder slots inactive.
  - Evidence: `lua5.4 tests/run.lua` gives **261 passed, 0 failed**. 2 new regressions, plus 2 new corrupt-section cases. Removing either check makes tests fail (2 and 1 respectively).

## 8. More collection themes: 49 installed; all 10 new items passed remote Place→Rotate→Delete in Play (physical UI/visual checks unverified); 10 candidates tracked, not registered; batch 02/03 candidates; Executive/Broadcast pending
Starter, Retro, Winter, Futuristic, Executive and Broadcast, drawing on the asset index once Codex promotes templates.
- Acceptance: catalog entries only for templates Codex has prepared. Still free.
- Catalog expansion (user priority, 2026-10-25; task 7 wiring is paused, not started):
  - **Delivered:** 24 templates prepared and visually reviewed by Codex.
    - The manifest is committed as `docs/assets/Catalog_Expansion_2026-10-25.json`, and the asset index is updated.
    - The 24 items are appended to `Catalog.luau` with the exact IDs, display names, tags and sourceRefs. The 7 originals keep their IDs and order. Total: 31.
    - All decorative, free and without seat profiles. `sourceAssetId` stays in the manifest only.
  - **Install note:** the templates sit in `ServerStorage.StudioBuilderExpansion`, but the probe reads `StudioBuilderTemplates`. Codex places them there under their IDs, or they show as not installed. There are no code changes beyond `Catalog.luau`, and no persistence, UI or seat changes.
  - **Tests:** `catalog_spec` now checks:
    - exactly the 7 + 24 IDs in order;
    - unique IDs and display names;
    - exact per-collection counts (Cozy 22, Retro 16, 1980s 12, Winter 11, Futuristic 9);
    - each expansion entry against the manifest (name, tags, sourceRef, template path, zero scripts, decorative), with no asset-ID fields in the catalog;
    - every sourceRef present in the asset guide or the manifest.

    The old hard-coded 7-item and "futuristic is empty" assertions were replaced.
  - **Evidence (executed 2026-10-25):** `lua5.4 tests/run.lua` gives **263 passed, 0 failed**. These mutations were each caught: a wrong tag, sourceRef or display name; a duplicate display name; a dropped item; a renamed original.
  - **Pending (Codex, Studio):** install the 24 templates in `StudioBuilderTemplates`, probe acceptance, filters, placing each collection, large footprints against the sandbox bounds, the replication and drawer cost of 31 preview templates, save and load with expansion items.
- Integration evidence (Codex, 2026-10-25, for 6a8e490). Full report: [`docs/integration-catalog-expansion.md`](docs/integration-catalog-expansion.md).
  - **Installed:** all 24 templates in `ServerStorage.StudioBuilderTemplates` (31 total); the prepared originals kept; 24 manual-use copies in `StudioAssetYard/07 Builder Catalog Expansion`.
    Only the reviewed `Catalog` source was installed; the runtime is still bb3efa6 plus the local integration patches.
    The new templates are scriptless and anchored, with Seats, lights and effects disabled and ThumbnailCameras removed.
  - **Verified:**
    - real Studio Luau `Catalog.validate` passed;
    - in Play, client Place then Delete succeeded for all 31 IDs with zero failures, and the curved sofa at x = 23 correctly returned `OutOfBounds`;
    - the OPEN BUILDER drawer filters show Cozy 22, Retro 16, 1980s 12, Winter 11, Futuristic 9;
    - a Curved Lounge Sofa card plus floor click placed it;
    - `PreviewTemplates` has 31 models;
    - Play stopped with no QA scripts kept.
  - **Observation:** the legacy `cozy_floor_lamp_01` template still has its light (a template decision, not an adapter).
  - **Not done, not claimed:**
    - real DataStore save/load with expansion items, multiplayer, a bulk performance benchmark;
    - Move, Rotate, Duplicate, Undo and Redo per expansion item;
    - any seat runtime (task 7 is still a pure model with no approved profiles).
  - **Backup:** a full-place backup of this state is pending. The user stopped native Computer Use, and it isn't bypassed. The 62f2f87 RBXL remains the full-place baseline.
  - This checkpoint is documentation only, with no code, runtime or UI changes. The header comments in `Catalog.luau` still describe the pre-install state; they get fixed in the next code checkpoint.

- Decor registration (after review of 24e8047):
  - **Registered:** `retro_record_player_01` (Vintage Record Player) and `retro_radio_01` (Vintage Radio), from `docs/assets/Structure_and_Decor_Candidates_2026-10-25.json`, with the exact name, tags (retro, 1980s, cozy) and sourceRef. Positions 37 and 38; the first 36 IDs and their order are unchanged.
  - **Credit:** the record player keeps the creator's requested credit verbatim (`credit = "RushioLCO (credit requested)"`). The radio's creator (zzz_1551) is noted in the source and the index.
  - Both are decorative furniture with no structure metadata and no audio. Their templates are in `ServerStorage.StudioStructureCandidates`, so they're **not installed** in the game until Codex places them in `StudioBuilderTemplates`.
  - **Style filter counts:** Cozy 24, Retro 18, 1980s 14, Winter 11, Futuristic 9.
  - **Still deferred:** the shoji divider (272 parts), the corner and the standalone window frame.
  - **Evidence (executed 2026-10-25):** `lua5.4 tests/run.lua` gives **297 passed, 0 failed**. The catalog tests check: 38 entries in order; the decor matches the manifest exactly (name, tags, sourceRef); the credit is kept verbatim; there's no structure tag; the deferred 3 and the rejected asset IDs are still absent.
    Mutations caught: the credit dropped, a wrong tag, a changed name, the radio marked as structure.

- Integration evidence for 46d55cb (Codex):
  - Both decor props are installed. Real Play Place, Rotate and Delete passed.
  - Independent full suite: 297 passed, 0 failed.
  - Studio returned to Edit, and a source catalog backup was saved.
  - World captures are still white, so there's no fresh visual approval. No full-place backup is claimed.
- Asset index refresh (2026-10-25; documentation only, no runtime change). Archived in [`docs/assets/refresh-2026-10-25/`](docs/assets/refresh-2026-10-25/README.md): the original ZIP, the standalone handoff TXT and the extracted JSON and TXT files, with a README summarising installed vs pending and the verification.
  - **Checksums:** all four checksums in the ZIP's checksum file match, and the standalone TXT is byte-identical to the zipped one.
  - **Counts verified:**
    - 38 installed, all with zero scripts; their IDs, order, names and tags are identical to `Catalog.luau`;
    - 13 tracked candidates: 3 prepared + 2 walls + 8 imports;
    - 6 rooms; 5,758 Model records (**not** unique assets); 500 distinct content references; 59 script containers.
  - `docs/assets/README.md` now points to the refresh as the current state; the earlier snapshots stay as history.
  - **Pending, not registered:**
    - corner, standalone window frame and shoji divider;
    - Concrete Sci-Fi Wall and White Brick Wall (grid adaptation needed);
    - 8 new imports: two fireplaces, two pillows, executive sci-fi desk, realistic rug, old floor lamp, wood truss beam. Zero embedded scripts, but scaling, effects and visual QA remain, and they're **not approved**.
  - **Observation from the refresh:** four installed templates (cork floor lamp, modern lamp, desk lamp, lantern) each contain one light object. Whether those are enabled isn't stated. The builder doesn't control them.

- Furniture organized by type (user priority, 2026-10-26). Delivered at 4c7087d; **installed and Play-checked since** (evidence below):
  - **Catalog:** `Catalog.FurnitureTypes`: Seating, Tables, Storage, Microphones, Audio, Lighting, Screens, Plants, Decor.
    - Each of the 33 furniture items has exactly one explicit primary `type` by function, set in data and never derived from names. The AV cart is Storage, not Screens.
    - Totals: Seating 6, Tables 3, Storage 5, Microphones 2, Audio 5, Lighting 4, Screens 1, Plants 2, Decor 5.
    - Structure pieces have no type.
    - The validator requires a known type on furniture and forbids one on structure pieces.
    - New helpers: `getFurnitureType`, `getFurnitureByType(collection, type)` and `getFurnitureTypeCounts(collection)` (ordered, empty types hidden).
    - IDs, order, tags, placement authorization and persistence are unchanged.
  - **Client:**
    - `BuildSession.furnitureType` (nil = chooser, "all", or a type). Changing collection (even re-picking it) or category returns to the chooser.
    - Changing collection, type or structure filter cancels any placement or move preview.
    - `BuildController` adds `chooseType` and `backToTypes`; every navigation bumps intent, so an in-flight response only updates status.
    - `BuildDrawer` gets a two-column type chooser with counts and All items, and a "< Types" row. The action row's Back is relabelled **Exit** (it leaves build mode; behaviour unchanged).
    - Structure mode is unchanged and has no chooser. No new theme tokens; `docs/ui-contract.md` has a "Furniture by type" section for the visual comparison.
  - **Evidence (executed 2026-10-26):** `lua5.4 tests/run.lua` gives **304 passed, 0 failed** (29 specs). New `furniture_types_spec` (7 tests):
    - the complete reviewed type assignment, and no Doors type in furniture;
    - validator rules;
    - per-collection counts correct, in type order, no empty groups, adding up, with type filtering equal to the collection-type intersection (plus Futuristic and Winter snapshots);
    - session navigation and cancellation;
    - the controller chooser (counts, All items, no cards while choosing), type lists, Types vs Exit;
    - type, collection and structure-filter changes cancelling placement and move with nothing sent;
    - a Place in flight during a type change applying status only.

    Updated fakes and one structure test (style filters now open the chooser). 10 mutations caught.
  - **Not executed:** the real drawer Instances (BuildDrawer isn't run outside Roblox), Studio and Play.
- Integration evidence for 4c7087d (Codex, 2026-10-26):
  - **Install:** all 304 tests rerun independently, 0 failures. All four changed modules matched the prior installed sources, were backed up, and were then installed in place 132242140555698.
  - **Verified in Play:**
    - the Cozy type counts;
    - Tables lists two tables, and Microphones lists two microphones;
    - "< Types" returns to the chooser without exiting build mode;
    - switching to Futuristic updates to nine items;
    - Structure → Doors shows the doorway;
    - a coffee table placed through the category UI was confirmed on the server, then deleted, and no test objects remain;
    - the screenshot confirms the matching dark/teal panel and grid;
    - no console errors.
  - **Still pending:**
    - builder-specific visual QA of structure pieces, and doorway clearance (task 10);
    - seating wiring (task 7 is a pure model, with no approved anchor metadata);
    - the 13 tracked model candidates (not registered);
    - real persistence checks (real DataStore save/load, text filtering, multiplayer);
    - a full-place backup (source backups only).

- Status corrections (Codex, 2026-10-26):
  - The blank (white) world captures have recovered, and the user sees models normally. **Builder-specific visual QA is still pending.**
  - The four-light check: the cork floor lamp is enabled (brightness 1, range 10; original). The sculptural modern lamp, desk lamp and lantern are disabled, as intended.
  - The 89121f0 asset-log archive and ZIP were independently verified byte-for-byte.
  - The earlier "white captures" notes above are kept as history.

- Patterned rug registration (after review of 3e7a45e; repository only, Studio install and Play check pending):
  - **Registered:** `retro_patterned_rug_01`, "Patterned Vintage Rug": collections cozy, retro and 1980s; type decor; sourceRef `ServerStorage.NextCatalogInspection.Review_11829259774`. It's appended as entry 39; the earlier IDs and order are unchanged. **Installed count stays 38** until Codex installs it.
  - **Source:** one of the 13 tracked candidates (import 11829259774, "Realistic Rug", free Creator Store asset by caductis), not a new 14th.
  - **Normalized by Codex:** one MeshPart; zero scripts, sounds, lights and particles; anchored; CanTouch false; scale 0.65; bottom-centre pivot; 9.043 × 0.304 × 10.029 studs; neutral-lit screenshot reviewed.
    The prepared template is in `ServerStorage.PreparedDecorCandidates.retro_patterned_rug_01`.
  - **Provenance:** `docs/assets/Decor_Candidate_retro_patterned_rug_01_2026-10-26.json`. The asset ID, URL and template path stay there, not in the catalog.
  - **Not registered:** the two normalized pillow derivatives (not approved) and every other candidate. 12 of the 13 remain tracked.
  - **Test change, for review:** "no catalog field carries an asset ID" now exempts `sourceRef`, which must be a `ServerStorage.` path, not a URL and without `rbxassetid`, and is cross-checked against a committed manifest. The required sourceRef contains the inspection folder name `Review_11829259774`. Every other field keeps the strict digit check.
  - **Evidence (executed 2026-10-26):** `lua5.4 tests/run.lua` gives **305 passed, 0 failed**.
    - New: rug-versus-manifest exactness (name, tags, type, sourceRef, creator, zero scripts); no other catalog entry pointing at an inspection copy; no pillow registered.
    - Updated: 39 entries in order; furniture counts Cozy 25, Retro 19, 1980s 15, Winter 11, Futuristic 9; the type assignments (34 furniture, Decor 6); the Cozy "All items (25)"; structure placement (item 39 is furniture).
    - 6 mutations caught: a wrong type, tag or name; an asset ID in another field; sourceRef as a URL; a pillow sneaked in.

- Integration evidence for a9bf5ba (Codex):
  - **Install:** independent full suite 305 passed, 0 failed. The catalog was backed up, then installed along with the prepared rug template.
  - **Play:**
    - Cozy → Decor lists Patterned Vintage Rug as "Ready to place", and the Cozy count is 25;
    - real remote Place at the sandbox-relative origin, Rotate and Delete all succeeded;
    - the screenshot shows the rug correctly on the floor;
    - no console errors.
  - Studio was returned to Edit. **Installed total: 39.** The full-place backup refresh is still pending; a source backup was saved.
- Classic floor lamp registration (after review of a9bf5ba; repository only, Studio install and Play check pending):
  - **Registered:** `retro_classic_floor_lamp_01`, "Classic Shaded Floor Lamp": type lighting; collections cozy, retro, 1980s and winter; sourceRef `ServerStorage.NextCatalogInspection.Review_4128475322`. It's appended as entry 40; the earlier entries are unchanged. **Installed stays 39** until Codex installs it.
  - **Source:** tracked import 4128475322 ("Old Floor Lamp (Mesh)", free Creator Store asset by bearduckmonkey), one of the remaining 12. **11 remain unregistered.**
  - **Codex's neutral-lit review:** a tall, slender dark bronze stand, a round ornamental base and an aged cream fabric shade. This corrects the earlier thumbnail-based "cage-like" description, which is noted in the refresh README.
  - **Normalized:** one MeshPart, upright, bottom-centre pivot at zero, 2 × 6.5 × 2 studs, anchored, CanTouch false; zero scripts, sounds, particles and Light objects.
  - **Decorative only:** no illumination and no on/off behaviour. No runtime light adapter was added.
  - **Provenance:** `docs/assets/Decor_Candidate_retro_classic_floor_lamp_01_2026-10-26.json`. The prepared template is in `ServerStorage.PreparedDecorCandidates.retro_classic_floor_lamp_01`.
  - **Not approved:** the pillows and every other candidate.
  - **Evidence (executed 2026-10-26):** `lua5.4 tests/run.lua` gives **305 passed, 0 failed**.
    - The rug-only provenance test became one table of approved tracked registrations: the rug and the lamp, each checked against its own manifest (name, tags, type, sourceRef, creator, zero scripts) and appended in approval order, with nothing after them. Only these two point at inspection copies, there are no pillows, and the lamp manifest records no Light.
    - Updated: 40 entries; furniture counts Cozy 26, Retro 20, 1980s 16, Winter 12, Futuristic 9; types (35 furniture, Lighting 5); the Winter type snapshot (lighting = 2); Cozy "All items (26)"; structure placement (item 40 is furniture).
    - 5 mutations caught: lamp as decor, a missing Winter tag, a wrong name, a wrong sourceRef, a fireplace sneaked in.

- Catalog hunt batch 02 (2026-10-26; **inventory only**: documentation, nothing registered, no runtime change):
  - **Archived:** `docs/assets/Catalog_Hunt_Batch02_2026-10-26.json`, verbatim, and indexed in `docs/assets/README.md`.
  - **Contents:** 8 inspected free sources gave 22 candidate pieces: 7 walls/trims, 4 seating, 3 storage, 2 tables, 2 audio, 2 decor, 1 door, 1 window. The Modular Wall Pack and the Modular Wall Trim Pack, previously deferred, are now inspected.
  - **Copies:** the prepared copies in `ServerStorage.CatalogHuntPrepared02` are reported anchored and script-free.
    **Correction:** their persistence is **UNVERIFIED**. An Edit execute returned 22 prepared models, but the current Play server has no `CatalogHuntPrepared02` folder (`CatalogHuntBatch02` is present). This stays pending until Studio is back in Edit. Codex keeps a recreation script locally (`work/prepare-hunt-batch02.luau`, not in this repository).
    All 22 remain candidates only. Nothing is ready or installed, and no runtime work is assigned. The originals are preserved in `ServerStorage.CatalogHuntBatch02` with their scripts disabled. The Futuristic Furniture pack's welding, vehicle-movement, text-banner and unpacker scripts never ran.
  - **Pending:** geometry, orientation, visual and placement review (sideways acoustic panels, unusually oriented industrial walls, walls and trims not on the 16-stud module). **No review gallery yet:** Studio entered Play before staging.
  - Not registered, not Build-ready. This entry doesn't start any other implementation, and the queue order is unchanged.
  - **Still pending Studio integration:** the 9 structure variants (caf7115) and the rotation change (14933b6).

- Catalog hunt batch 03 (2026-10-26; **inventory only**: documentation, nothing imported or registered, no runtime change):
  - **Archived:** `docs/assets/Catalog_Hunt_Batch03_2026-10-26.json`, verbatim, and indexed in `docs/assets/README.md`.
  - **Review:** 48 search results, 16 previews visually reviewed, 12 shortlisted, 4 rejected.
  - **Shortlist by proposed type:** 3 walls (2 glass partitions, a wood-slat feature wall), 3 decor (curtains, 2 radiators), 2 storage (sideboards), 1 audio (road cases), 1 seating (wingback armchair), 1 ceiling (tiles), 1 door.
  - **Status:** thumbnail review only. Not imported, not script-audited, not placement-tested, not registered, not Build-ready.
  - **Checked on archive:** the JSON parses; the IDs are unique; the links match the IDs; none of the 16 IDs appears elsewhere in the repository docs, source or status files.
  - **Batch 02** keeps its status at the time: candidates only, with prepared-copy persistence unverified (resolved later in Edit; see the batch 02 recreation checkpoint).
  - **Install pending:** the runtime changes through 5fcf60b (311 tests passed, independently reviewed) are still not installed. Studio stays in Play and wasn't interrupted. The queue order is unchanged.

- Existing-room gap audit (2026-10-26; **documentation only**; feeds task 11, which still waits on an inspected manifest):
  - **Archived:** `docs/assets/Existing_Room_Catalog_Gap_Audit_2026-10-26.json`, verbatim, and indexed in `docs/assets/README.md`.
  - **Scope:** a read-only Play audit of **13 existing room objects or groups**. These aren't 13 imported or Build-ready assets.
    - Conference Room: table, office chairs, coffee mug, guest laptop, water cooler, presentation board, flower pot, tall plant, panel door.
    - Broadcast Set: softbox, lighting umbrella, On Air sign, metal door.
  - **Flags:**
    - **Guest laptop: 611 parts**. Optimize it or replace it with a lower-part equivalent before builder duplication.
    - **Office chairs:** a 12-seat group. Extract a single chair; don't register the group.
    - **Doors (2):** grid and clearance adaptation needed; functional opening not verified.
    - **Lighting props** (softbox, umbrella, On Air sign; one light each): orientation and light-control integration review needed.
    - **Presentation board:** carries live studio text labels (AFTER HOURS etc.), to review before reuse.
  - No scripts were found in these 13 objects; that isn't a whole-place security audit.
  - Template extraction and registration remain pending Edit mode. Studio is still in Play, so no integration is claimed.
  - Batch 02 and batch 03 keep their pending and unverified status. No runtime, catalog or queue change.

- Integration checkpoint (Codex, 2026-10-26, Studio back in Edit):
  - **Installed:** **only `Catalog.luau`** from the reviewed 5fcf60b, plus ten approved templates: the 9 `StructureExpansionCandidates` variants and `retro_classic_floor_lamp_01`. **The live catalog and templates are now 49.**
  - **Checks:**
    - a fresh require and the TemplateCatalog `serverStorageProbe` passed for all 49;
    - structure counts: Floors 5, Walls 3, Doors 2, Ceilings 2, Windows 2;
    - all ten additions are anchored, with zero scripts and upright bottom-centre pivots.
  - **Backup:** the previous Catalog source was backed up locally and in `ServerStorage.BuilderIntegrationBackups.Catalog_Before49_20261025_2233`.
  - **Not verified in this checkpoint:** Play/UI placement of the ten new items.
  - **Not installed:** the five-module **R rotation change (14933b6)**.
  - **Still candidates only:** batch 02 and batch 03. The full-place backup is still pending.
  - Codex independently verified that the 718e39e gap-audit JSON matches the supplied file exactly.
  - Earlier "install pending" notes for the lamp and the structure variants are kept as history; this entry supersedes them.

- Batch 02 recreation checkpoint (Codex, 2026-10-26, Edit mode; documentation only):
  - **Recreated:** Codex confirmed `ServerStorage.CatalogHuntPrepared02` was absent, recreated all 22 sanitized candidates from the 8 originals, and independently re-read the folder: **22 models, 353 BaseParts, zero LuaSourceContainers, zero unanchored parts**. This resolves the earlier missing prepared-copy issue for the current Edit DataModel.
  - **Review gallery:** 22 labelled display copies at `Workspace.StudioAssetYard.09 New Asset Review`, by type on a 6-column grid (about x 3500–3720, z 3370–3502).
    - Each is marked CANDIDATE / NOT IN BUILD and keeps its source, type and collection metadata.
    - A `CandidateIndexJSON` is stored in that folder, and the display copies have zero scripts.
  - Build templates stay **49**.
  - **Still pending:** fit, orientation, visual and placement approval of all 22, so none is registered; and the full-place disk backup.
  - The historical batch 02 manifest and the earlier "unverified" notes are unchanged.
  - Housekeeping: the rotation install entry was moved from the end of task 11 to task 10, where it belongs. Its wording is unchanged and the queue order is unchanged.
- Batch 03 structure import checkpoint (Codex, 2026-10-26, Edit mode; documentation only):
  - **Imported to quarantine:** 3 of 12 shortlisted sources in `ServerStorage.CatalogHuntBatch03`, zero scripts: Glass Partition, Scaleable Ceiling Tiles and Modern wood block. The other 9 are still thumbnail-only. Archived as `docs/assets/Batch03_Structure_Import_Checkpoint_2026-10-26.json`.
  - **None is Build-ready:**
    - the glass partition needs 16-stud grid sizing;
    - the ceiling's texture is on its top face only, so it needs an underside treatment;
    - the wood block is a decal-covered four-stud cube, not a modular slatted wall, with two overlapping Top decals.
  - Gallery capture stalled and was cancelled, so there is no visual approval. Build templates stay **49**.
  - The historical batch 03 manifest is unchanged.

## 9. Studio > Branding: Pending
Requested 2026-10-25. Not started: it waits on the current panel, director and preset source from Codex, and builds on the host checks from task 3 and the saving from task 5.
- UX: a Branding section on the Studio page. The host enters a Roblox image asset ID and sees a preview. They then apply it either to the whole active room's branding, or by clicking or selecting eligible individual surfaces (wall signs, screens, mugs, laptop lids). Apply and Reset per room and per surface.
- Rules: host-authoritative, checked on the server for every apply or reset. Targets come from an allowlist of stable surface IDs, never arbitrary Instances or paths. Only image/decal content is set: never model or script loaders, `LoadAsset`, `require(id)` or arbitrary URLs. The asset ID must be a positive integer, turned into image content server-side. If an image is invalid or unavailable, the prior branding stays. Per-surface overrides are saved with the studio as an additive, versioned preset section, so older presets load unchanged.
- **Visual contract:** Branding sits inside the existing Studio tab, in the same row, heading and input style as the live panel ([`docs/ui-contract.md`](docs/ui-contract.md)). No new visual style.
- Context: laptop Apple logos were already replaced with existing geometric Roblox marks on 11 live and stored instances (Codex).
- Acceptance (draft): tests that actually run cover the asset-ID validation, target allowlist, host check, keeping prior branding on failure, and save/load of overrides including legacy presets. Studio-pending for preview and rendering.

## 10. Structure pieces: walls, floors, ceilings, doorways, windows: In progress (14 pieces and R rotation installed; remote-tested in Play; physical R-key/UI, visual QA and doorway clearance pending)
Let hosts build room shells in the sandbox from modular 16-stud pieces, as a **structure** category separate from the style collections.
- Candidates (Codex, 2026-10-25): 10 prepared and visually inspected in `ServerStorage.StudioStructureCandidates`. The manifest is [`docs/assets/Structure_and_Decor_Candidates_2026-10-25.json`](docs/assets/Structure_and_Decor_Candidates_2026-10-25.json), indexed in `docs/assets/README.md` with creator credits, the 2 rejected unsafe imports (IDs kept) and 3 deferred ones.
  - **Structure pieces:** wall, window wall, doorway, corner, floor, ceiling, industrial window frame.
  - **Ordinary decor:** record player (RushioLCO credit kept), radio, shoji divider (272 parts).
  - The ceiling is a recolour of the kit floor geometry, not a separate marketplace model.
  - **None are registered in `Catalog.luau` or the Build UI.**
- Plan: [`docs/structure-placement-plan.md`](docs/structure-placement-plan.md), based on the current Transform, PlacementPreview, RoomProvider and PlacementCore code. It covers:
  - the 16-stud structure grid: wall edges and corners, floor and ceiling heights;
  - 90° yaw and Rotate; door clearance; window wall-face attachment;
  - support deletion (keep "floating allowed" for now);
  - outer-wall vs. bounds arithmetic, and a shared pure grid rule enforced by the server;
  - undo and save compatibility (no format change; off-grid pieces preserved);
  - a Structure mode reusing the drawer's filter row and theme.
- Decisions D1–D7 are open. Codex measurements are needed: opening boxes, wall centreline, corner legs, window mounting, the live sandbox marker size.
- Acceptance (draft): the tests listed in section 7 of the plan. Runtime placement, avatar clearance and window fitting are Play-tested by Codex.
- **Not done:** any structure runtime, catalog entry or UI. Structural snapping isn't implemented.
- Evidence for this docs checkpoint: `lua5.4 tests/run.lua` runs the catalog and static checks, including a new guard that none of the 10 candidate IDs is in `Catalog.luau` and that no rejected asset ID appears in source.
- Pure foundation (review of b14edfd; decisions D1–D7 resolved from Codex's Studio measurements):
  - **Delivered:** `src/shared/StructureGrid.luau`:
    - cell centres at 16i and edges at 8 + 16i from the sandbox origin (a cell centre), with ties toward +infinity;
    - levels: floor 0, wall 0, ceiling 15;
    - cardinal yaw; edge pieces along X at 0/180 and along Z at 90/270;
    - `validate` with distinct codes (BadKind, BadTransform, BadSize, BadYaw, BadLevel, OffGrid, then OutOfBounds from the shared bounds check, with no overhang) and a 0.01 tolerance that snaps exactly;
    - `project` from a floor hit;
    - a deterministic `rotate` re-snap proposal: hinge at an end point, fixed candidate order.
  - Covers floor, ceiling, wall, window_wall and doorway. Corner (leg centrelines at 7.5, not 8) and the standalone window frame (axes need normalizing) are deferred and give BadKind.
  - **Measured, recorded, not yet used:** the doorway opening (x ±2.5, y 1 to 8.5, z ±0.5; threshold y 0 to 1; corridor recommendation z ±2.5). No avatar Play claim.
  - **Bounds:** a 49 × 24 × 49 marker is proposed for 3 × 3 cells with outer walls at ±24. The live 48 × 24 × 48 marker at (2000, 12, 0) is untouched; there, outer walls are refused and inner walls and 3 × 3 floors fit.
  - **Plan:** `docs/structure-placement-plan.md` §4 is updated with the decisions and the Rotate proposal, and labelled pure foundations, pending Studio review.
  - **Not integrated:** no planners, preview, drawer, catalog, persistence, seat or theme changes. All 31 live catalog entries are unchanged.
  - **Evidence (executed 2026-10-25):** `lua5.4 tests/run.lua` gives **273 passed, 0 failed** (26 specs). `structure_grid_spec` adds 9 tests: snapping (negative cells, ties), floor and ceiling (ceiling top 16, height 15.9 vs 16), edge axes for the three edge kinds, the full outer-wall footprint (24 refused, 24.5 accepted), tolerance, yaw, bad input, projection (including a sweep), and Rotate.
    12 mutations caught: edge origin, tie direction, swapped axes, overhang allowed, no level check, ceiling at 16, OffGrid reported as bounds, 15° yaw, rotate in place, no fallback candidates, tie edge choice, corner accepted.
- Validation repair (review of 8f3f404; the 9 grid tests passed in real Studio Luau, and 3 reproduced throws blocked):
  - **Bug:** `StructureGrid.validate` and `Transform.sanitize` checked coordinates with `ipairs({ x, y, z })`, which stops at the first nil, so a missing x, y or z skipped validation and then threw on arithmetic.
  - **Fix:** both now check each field explicitly (`isCoordinate`). Valid transforms, the 0.01 quantization and bounds behaviour are unchanged.
  - **Regressions:** missing x, missing y, missing z, plus combinations where a later coordinate is also NaN, a string or infinite. They're asserted as `BadTransform` and never a throw, through `validate`, `rotate` and `Transform.sanitize`. Ordinary valid and outer-wall cases are re-checked.
  - **Mutation check:** putting the original `ipairs` loop back fails the new test, in each module independently.
  - **Evidence:** `lua5.4 tests/run.lua` gives **275 passed, 0 failed**.
  - Still unintegrated. The hinge Rotate stays an isolated proposal and isn't UX-approved; it waits for a practical preview review.
- Server placement integration (after review of 8b5d37a; the 10 grid tests and 6 missing-coordinate regressions passed in real Studio Luau):
  - **Catalog and listing:** optional `structure = { kind }` metadata, validated in `Catalog.validateData` (only floor, ceiling, wall, window_wall and doorway; nothing but `kind`). Corner and window are refused. `TemplateCatalog:clientListing()` passes the kind through as a copy.
    The live 31 entries are unchanged and carry no structure.
  - **`PlacementCore._clean`:** for structure items, it applies `StructureGrid.validate` with the core's supplied bounds (no overhang), `MaxCoordinate` and `BoundsEpsilon`. So Place, Move, Undo/Redo (history re-validation) and load classification all share the grid, level and cardinal-yaw rules.
    Malformed or unsupported structure metadata gives `UnknownItem`.
  - **Codes:** new Protocol code `OffGrid`, with `reason` OffGrid, BadLevel or BadYaw, propagated by the planners. Bounds stay `OutOfBounds`.
  - **Rotate:** structure items step 90° through `StructureGrid.rotate`. Floors and ceilings turn in place; edge pieces hinge at an end point, with a fixed candidate order. The hinge is **provisional, awaiting visual UX validation**.
  - **Duplicate:** structure items take one 16-stud step: along their own axis first for edge pieces, then sideways. The first on-grid in-bounds candidate wins.
    Honest note: because `_clean` refuses off-grid candidates, the old size-based offsets would converge on the same results for these sizes. The explicit 16-stud offsets make the intent clear rather than change outcomes.
  - **Furniture:** unchanged (free positions, 15° rotation, size-based duplicate).
  - **Unchanged:** no save schema change, no support graph, no cascade delete, no new remote, no persistence or seat change.
  - **Doorway clearance corridor:** still pending, not implemented. No avatar clearance is claimed.
  - **Evidence (executed 2026-10-25):** `lua5.4 tests/run.lua` gives **286 passed, 0 failed** (27 specs). `structure_placement_spec` adds 11 tests with labelled `fixture_*` structure items and sizes, on both the live 48 marker and the proposed 49 marker. They cover:
    - catalog and listing metadata;
    - furniture unchanged;
    - Place for every kind, with OffGrid, BadLevel and BadYaw reasons;
    - outer bounds (walls at ±24 refused on 48, accepted on 49; 3 × 3 floors and ceilings fit both);
    - hostile and malformed requests (missing, non-finite and string coordinates, extra keys, unknown items, non-host);
    - Move axis rules; Rotate (in place, hinge, boundary fallback, impossible cases refused unchanged, live-bounds fallback);
    - Duplicate (cells, both edge axes, a bounds fallback, refusal);
    - failed world apply leaving state and history unchanged;
    - a mixed furniture and structure undo/redo walk with exact IDs and transforms;
    - save/load (no new fields; outer and off-grid walls preserved on 48 and written back; the outer wall placed on 49; no ID reuse).

    Every refusal is checked against a snapshot of the model, revision, world calls and undo/redo availability.
    10 mutations were caught: `_clean` ignoring structure, malformed kinds treated as furniture, 15° Rotate, in-place 90° Rotate, OffGrid reported as bounds, reason dropped, overhang allowed, duplicate axis order, catalog validation off, listing dropping the kind.
  - **Not executed:** anything in Studio. No candidate is registered; there's no client preview or UI.
- Client UI and registration (after review of 12068ca; 286 tests rerun independently on Windows with Lua 5.4):
  - **Catalog:** the 5 approved candidates are registered with the exact manifest name, tags and sourceRef, and the structure kinds wall, window_wall, doorway, floor and ceiling. Total 36; the first 31 IDs and their order are unchanged.
    The ceiling's floor-derived provenance is noted in the source.
    The templates are still in `ServerStorage.StudioStructureCandidates`, not `StudioBuilderTemplates`, so they're not installed in the game.
    New helpers: `Catalog.StructureFilters`, `getFurnitureTagged` (the style filters now show furniture only) and `getStructureItems`.
  - **Shared code mapping:** `StructureGrid.toProtocol`, used by both `PlacementCore` and `PlacementPreview`.
  - **Client:**
    - `BuildSession` gets a category (furniture or structure), a structure filter and the item kind. Switching category cancels previews.
      The preview rotation step is 90° for floors and ceilings, and 180° for edge pieces (R flips facing; the pointer picks the edge).
    - `PlacementPreview` gets a structure path through `StructureGrid` (project, then validate, with the supplied bounds; any hit, using x/z only; ceiling at y = 15; server codes and reasons).
    - `BuildController`: `setCategory`, structure filters, kind-aware choose and move.
      `lastPreview` is tied to item and yaw and cleared when it can't be recomputed, so a stale or rotated-without-recompute preview is never sent.
    - `BuildDrawer`: a Furniture | Structure choice row (existing styles) and the existing tab row relabelled per category.
    - `BuilderClient` passes the structure filters.
    - Keyboard, mouse and focus protections are unchanged.
  - **Docs:** the plan has a plain-language explanation of the provisional hinge Rotate, and the UI contract notes the Structure mode for the visual comparison.
  - **Still pending:** the doorway clearance / obstruction policy (not implemented, not tested).
  - **Evidence (executed 2026-10-25):** `lua5.4 tests/run.lua` gives **297 passed, 0 failed** (28 specs).
    - New `structure_client_spec` (10 tests):
      - preview snapping and levels, any-hit behaviour, bad input, and furniture unchanged;
      - live 48 vs proposed 49 marker outer walls;
      - **preview/server parity**: 12,960 placements over both markers, all 5 kinds and 4 yaws; valid exactly when the real server accepts, with the same code and the same stored transform;
      - session categories and rotation steps;
      - controller: mixed filtering (furniture filters never show structure pieces; each structure filter lists its kind), a category switch cancelling a stale placement with nothing sent, a missing template not installable, grid ghost to exact Place transform (ceiling at y = 15), outer edge invalid on 48 with no request and a footer message, Rotate re-validation and stale-preview refusal, structure Move with its kind, OffGrid and BadYaw reasons and a server refusal message in the footer.
    - Updated: the catalog tests (36 entries, furniture vs raw tag counts, the 5 registered from the manifest, the 5 deferred still blocked, rejected asset IDs still absent from source), the listing safe fields (`structure` with only `kind`), and the structure placement spec (registered kinds).
    - 11 client mutations caught: preview ignoring the kind or skipping bounds, the controller omitting the kind, a category switch keeping the preview, no yaw check on confirm, a stale preview kept, structure leaking into style filters, a 90° edge step, choose or move dropping the kind, the OffGrid message lost.
  - **Not executed:** Studio install, Play, the real drawer Instances (BuildDrawer isn't run outside Roblox), and avatar clearance. **Players can't use structures yet.**
- Integration evidence (Codex, for 24e8047):
  - **Suite:** 297 passed, run independently.
  - **Installed:** after backing up all 45 existing scripts, the 11 changed modules and the 5 inspected structure templates in place 132242140555698. The marker is now 49 × 24 × 49, and the live catalog and templates hold 36.
  - **Play:**
    - Build → Structure opens with the matching dark/teal UI and five filters;
    - the real client/server remote placed all five pieces; a floor move, a wall rotate, a duplicate, undo, redo and every deletion passed;
    - BadYaw, OffGrid and OutOfBounds refusals were seen;
    - no console errors.
  - **Visual QA pending:** all world captures render white, including the original room in Edit mode. Rendering is Automatic, ViewMode None, with sane lighting; there's no confirmed cause. The GUI works and raycasts hit the correct geometry. **Visual placement, the hinge Rotate feel and doorway clearance are not approved.**
  - **Backups and place state:** Studio was returned to Edit, with no publish or merge. The full-place backup is still pending; there's a source-only backup.
- Rotation usability (user priority, 2026-10-26). Delivered at 14933b6; **installed since** (see the rotation install entry below). Physical R-key/UI checks unverified:
  - **What changed:**
    - R and the Rotate button now turn **every** structure preview 90° (floors, ceilings, walls, window walls, doorways), and the chosen angle holds while the pointer moves. Furniture keeps 15°.
    - `StructureGrid.project` gets a backward-compatible `options.lockYaw`: the yaw picks the edge axis (0/180 X-axis, 90/270 Z-axis, same grid origin) and is kept exactly. The default nearest-edge behaviour and all server validation are unchanged.
    - `PlacementPreview` passes `lockYaw` for structure.
    - `BuildSession.rotationStep` returns 90 for every structure kind.
    - The status line shows the angle ("Angle 90° [R]"), and the Rotate buttons are labelled "Rotate [R]".
    - A selected placed piece keeps the authoritative server Rotate.
    - Text-box focus, processed-input and free-camera key rules, host checks, bounds and stale-preview protection are unchanged.
  - **Before:** edge previews flipped 180° and the pointer chose the edge, so symmetric walls looked unchanged.
  - **Evidence (executed 2026-10-26):** `lua5.4 tests/run.lua` gives **310 passed, 0 failed** (30 specs). New `structure_rotation_spec` (5 tests):
    - `lockYaw` semantics against the default, with every locked projection on the grid;
    - four R turns of all 5 kinds: 90° steps, angle shown, each ghost's server acceptance matching its validity, edge-line axis per yaw, every turn a distinct preview, and the final click sending the exact ghost;
    - the angle holding across a pointer sweep, with parity;
    - furniture 15° steps unchanged, and a selected piece's R sending Rotate;
    - R ignored while typing or when processed, free-camera keys untouched, and a stale preview not sent after a turn.

    `structure_client_spec` was updated to the locked semantics. 6 mutations caught.
  - **Live status note (Codex, 2026-10-26):** the latest live Play snapshot reports **39 templates** and a user layout of 12 pieces. The classic floor lamp (e5d524d) is registered in the repository only and **not claimed installed**. User builds were not touched.
- Structure variants registration (after review of 14933b6; repository only, Studio install and Play check pending):
  - **Registered:** 9 entries from the manifest, appended after the classic floor lamp. The earlier IDs and order are unchanged.
    - Floors: `structure_floor_oak_01`, `structure_floor_walnut_01`, `structure_floor_concrete_01`, `structure_floor_slate_01`.
    - Walls: `structure_wall_wood_01`, `structure_wall_brick_01`.
    - Ceiling: `structure_ceiling_dark_01`. Window wall: `structure_window_black_01`. Doorway: `structure_doorway_wide_01`.
  - All are tagged with the five collections and carry `structure = { kind }`; no furniture type.
  - **Counts:** the repo catalog is **49**, including the not-yet-installed lamp, with **14 structure items**. The **live catalog stays 39**.
  - **Provenance:** `docs/assets/Structure_Expansion_2026-10-26.json` reproduces the items array verbatim, with notes. These are adapted free assets and material variants: 8 from the modular kit (12219944662) and the tracked White Brick Wall (12782716872) resized to the grid. They aren't independent marketplace models.
    The install source is `preparedPath` (`ServerStorage.StructureExpansionCandidates.<id>`). sourceRef and sourceAssetId are kept as provenance, and the catalog carries no asset ID or prepared path.
  - **Wide doorway:** the opening is 8 wide and 9 high above a 1-stud threshold (Codex measurement). **Avatar walkthrough not tested**; the doorway clearance policy is still pending.
  - **Tracked candidates:** the White Brick Wall was one of the 13, so **10 remain unregistered**.
  - No UI or grid contract change. Structure filters (once installed): Floors 5, Walls 3, Doors 2, Ceilings 2, Windows 2.
  - **Evidence (executed 2026-10-26):** `lua5.4 tests/run.lua` gives **311 passed, 0 failed**.
    - New catalog test: the variants match the manifest exactly (name, tags, kind, sourceRef, install path, zero scripts); there's no provenance field in the catalog; and each manifest size validates on the grid at its kind's level.
    - Updated: 49 entries in order; raw tag counts +14; per-kind structure counts; the approved-tracked list includes the brick wall; the structure filter lists in the controller test; the structure placement kinds.
    - 5 mutations caught: the wide doorway as a wall, a wrong name, a missing tag, a dropped variant, a changed sourceRef.
  - **Rotation (14933b6):** still not installed. The live key test is pending.
- Rotation install and remote Play check (Codex, 2026-10-26):
  - **Installed:** the five reviewed R-rotation files from 5fcf60b (change 14933b6): `StructureGrid`, `BuildSession`, `BuildController`, `BuildDrawer`, `PlacementPreview`.
    - Before installing, each live source was checked against the a9bf5ba baseline, and all matched.
    - Backups: `outputs/Rotation Backup` (local) and `ServerStorage.BuilderIntegrationBackups.Rotation_20261025_2243`.
    - After returning to Edit, all five installed sources were verified to match staging.
  - **Brief Play check:**
    - the installed `BuildSession` turned a structure preview 90°, then 180°; furniture turned 15°;
    - **all ten newly installed assets** (the classic floor lamp and the nine structure variants) passed Place → Rotate → Delete through the real client/server `BuilderRequest` remote, with every operation ok;
    - the test copies were deleted, and Studio was returned to Edit.
  - **Limitation:** the camera ViewportSize was 1 × 1, and automated mouse input stalled and was cancelled. So the **physical R key, the drawer UI and visual checks remain unverified**, as does **doorway avatar clearance**. No UI success is claimed.
  - **Code:** no changes beyond the reviewed sources. The previous independent pure suite was 311/0.
  - **Still pending:** batch 02 and batch 03 candidates, and the full-place backup.

## 11. Existing room assets in Build (user request): Pending
Make the assets already used in the six existing rooms available in the Build drawer, as decorative catalog entries in the right furniture types (or structure kinds).
- **Waiting on:** an inspected manifest from Codex, covering the prepared templates (zero scripts, anchored, bottom-centre pivots, normalized scale), stable IDs, names, collections, types, sourceRefs and credits. Nothing is registered until then, and nothing guesses which room models qualify.
- The live rooms themselves stay untouched; the builder only gets prepared copies.
- The user is browsing in Edit, so there are no Play or camera changes.
- Acceptance (draft): the same per-manifest catalog tests as earlier registrations, with type and count updates and provenance kept out of the catalog. Studio install and Play check by Codex.
