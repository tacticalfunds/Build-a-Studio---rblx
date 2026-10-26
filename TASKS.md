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

## 8. More collection themes: 67 installed in total (49 furniture, 18 structure; see task 11 for the room extractions; see task 10 for the structure pieces; the batch 02 pieces passed remote Place→Rotate→Delete); batch 02: 6 installed, 16 pending; all 10 new items passed remote Place→Rotate→Delete in Play (physical UI/visual checks unverified); 10 candidates tracked, not registered; batch 02/03 candidates; Executive/Broadcast pending
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
- Full-place backup checkpoint (Codex, 2026-10-26, Edit mode; documentation only):
  - **Saved:** a full local place backup via File > Download a Copy: `StudioBuilder-FullBackup-2026-10-25-2313.rbxl`, 4,132,460 bytes, SHA256 `06018C0FF8ABC8392F3AECA2078F27B9EAF6D95C0F30C1C21E1B8307D343494C`. The RBXL is kept locally and not uploaded to this repository.
  - **Verified:** the file exists and has a binary Roblox header. **Not reopened for restoration testing.**
  - **Includes:** the current 49-item catalog, the 22 prepared and staged batch 02 candidates, and the 3 quarantined batch 03 sources. It supersedes the earlier "full-place backup pending" notes, which are left as written.
  - Inclusion in the backup approves nothing: batch 02 and batch 03 candidates stay pending, and Build templates stay **49**.
  - **Capture note:** the native Studio window renders normally; the earlier capture limitation is specific to automated capture. No new visual check is claimed.
- Futuristic furniture registration (repository; Codex install pending):
  - **Registered (2):** `future_speaker_01` (Neon Studio Speaker; audio; futuristic) and `future_layered_coffee_table_01` (Layered Neon Coffee Table; tables; futuristic), appended after the structure variants. Repository count **51**; installed Build count stays **49**.
  - **Checks reported by Codex:** native Studio viewport inspection, and an Edit re-read of the prepared copies: zero LuaSourceContainers, all parts anchored, identity bottom-centre pivot (minY within 0.00003 studs of zero), zero Light objects. The speaker is decorative only, with no playback. The source is the free Creator Store pack Futuristic Furniture by SebbyTheGODKid, sanitized earlier.
  - **Provenance:** `docs/assets/Futuristic_Furniture_Registration_2026-10-26.json`. The historical batch 02 manifest is unchanged.
  - **Pending (Codex):** install the two prepared copies from `ServerStorage.StudioBuilderPreparedAssets` into `StudioBuilderTemplates`, run the TemplateCatalog probe, and do real placement tests. Also refresh the RBXL backup: the new prepared names aren't in it yet.
  - **Not approved:** the other 20 batch 02 candidates. The Leather Sofa (H02_11) is held for a local yaw correction (about −101°) and a front and seating-clearance review.
  - Tests: the catalog, type-count and drawer-count specs are updated for 51 items (futuristic furniture 11). There's a new manifest cross-check, and a guard that no other batch 02 candidate is registered. No UI or runtime code changed.
- 51-item install checkpoint (Codex, 2026-10-26; supersedes the "install pending" notes in the registration entry above, which are left as written):
  - **Review:** Codex reviewed 48b055c and ran its test suite independently: 312 passed, 0 failed.
  - **Mapping confirmed:** H02_13 = `future_speaker_01`; H02_20 = `future_layered_coffee_table_01`.
  - **Installed:** both are in `StudioBuilderTemplates` and Catalog in Edit. **Installed total: 51** (37 furniture, 14 structure).
  - **Checks:**
    - all 51 catalog entries passed the TemplateCatalog live probe;
    - there were 51 client previews in Play;
    - both new items passed real client BuilderRequest Place → Rotate → Delete (all six operations ok), and the test items were removed;
    - back in Edit, both templates persist.
  - **Not done:** a physical UI-click or R-key test.
  - **Backup:** a fresh full local place backup via Download a Copy, which includes the new prepared and template names. `StudioBuilder-FullBackup-51Items-2026-10-25-2333.rbxl`, 4,133,184 bytes, SHA256 `DB17E6BF29BD16C285A8A1B4C18705EEC928CD4F6964B495B3486C5ECEFA1CCC`. The header and existence are verified; restoration is not tested. It is local only and not uploaded.
  - **Still pending:** the other 20 batch 02 candidates, including the held Leather Sofa (H02_11). The registration manifest and the batch 02 manifest are unchanged.
- Tufted leather sofa registration (repository; Codex install pending):
  - **Registered (1):** `cozy_tufted_leather_sofa_01` (Tufted Leather Sofa; seating; cozy, retro, 1980s, winter), appended after the futuristic pieces. **Repository count: 52; installed count stays 51.**
  - **Source:** batch 02 H02_11, the free Creator Store model Leather Sofa by leutxiz. Install source: `ServerStorage.StudioBuilderPreparedAssets.cozy_tufted_leather_sofa_01` (the prepared copy's name matches the id).
  - **Codex checks:**
    - native Studio front and rear inspection: a dark charcoal tufted two-cushion leather sofa with rolled arms;
    - the about −101° local mesh yaw was corrected to identity, with the canonical front facing −Z and an identity bottom-centre pivot;
    - bounds 10.9743766785 × 3.9982066154 × 6.0234160423 studs;
    - one anchored MeshPart, with zero scripts, zero Lights and zero Seats.
  - **Decorative only:** there's no participant-seat adapter, and no sitting or seating-clearance claim.
  - **Provenance:** `docs/assets/Tufted_Leather_Sofa_Registration_2026-10-26.json`. The historical manifests are unchanged.
  - **Pending (Codex):** install into `StudioBuilderTemplates`, the TemplateCatalog probe, Play placement tests, and a backup refresh (it isn't in the 51-item RBXL).
  - **Batch 02 tally:** 2 installed, this 1 prepared and registered, 19 pending.
  - **Tests:**
    - counts updated for 52 items: 38 furniture; cozy 27, retro 21, 1980s 17, winter 13; winter seating 2;
    - a new consistency test covering the manifest fields, the decorative facts, and that the prepared name matches the id for the three batch 02 pieces.
    - No UI or runtime code changed.
- 52-item install checkpoint (Codex, 2026-10-26; supersedes the "install pending" notes in the sofa registration entry above, which are left as written):
  - **Review:** Codex reviewed 06adb12 and ran its tests independently: 313 passed, 0 failed.
  - **Installed:** the reviewed `Catalog` and `cozy_tufted_leather_sofa_01` in `StudioBuilderTemplates`. **Installed total: 52** (38 furniture, 14 structure).
  - **Checks:**
    - all 52 template probes are valid, none invalid;
    - real client BuilderRequest Place → Rotate → Delete all succeeded in Play, and the test copy was removed;
    - back in Edit, the 52 templates and the sofa persist.
  - **Not done:** a physical UI-click or R-key test. The sofa is decorative only, with no Seat adapter.
  - **Backup:** a new full local place backup via Download a Copy, `StudioBuilder-FullBackup-52Items-2026-10-25-2353.rbxl`, 4,136,547 bytes, SHA256 `50119431B1DEACB33F8514F251D8390B3503CF4FF8DC84B82DBF3BF0EF262148`.
    - The file exists and its binary Roblox header is verified; restore is not tested.
    - It contains the sofa's prepared copy, its template and its axis-review copies.
    - The previous backups are kept. It is local only and not uploaded.
  - **Batch 02:** 3 installed (speaker, layered coffee table, sofa), 19 pending. The historical manifests are unchanged.
- Drawer cabinet registration (repository; Codex integration pending):
  - **Registered (1):** `future_drawer_cabinet_01` (Three-Drawer Cabinet; furniture type storage; futuristic; floor placement), appended last.
    - **Counts:** repository 57 (39 furniture, 18 structure). Installed stays **56** (38 furniture, 18 structure).
  - **Source:** free Creator Store asset 1375085945, Futuristic Furniture by SebbyTheGODKid; batch 02 H02_18 Future Dresser (the original is retained).
  - **Prepared copy (Codex, Edit):** `ServerStorage.StudioBuilderPreparedAssets.future_drawer_cabinet_01`.
    - Bounds X 6.430999755859375, Y 4.2000017166137695, Z 3.27987003326416, with an identity bottom-centre pivot and the front facing −Z.
    - 6 anchored BaseParts, zero LuaSourceContainers, zero Lights, zero Seats.
    - The near-identity rotations and the pivot were normalized; no geometry was added.
    - The noisy, overscaled woodgrain was replaced with a neutral gray SmoothPlastic body, lighter drawer faces, a dark top and dark Metal round knobs.
    - It was inspected in native Studio.
  - **Decorative only:** the drawers don't open, and there's no storage behaviour.
  - **Provenance:** `docs/assets/Drawer_Cabinet_Registration_2026-10-26.json`. The historical manifests are unchanged.
  - **Not done yet:** it isn't installed or runtime tested, and it isn't backed up (the latest 56-item backup predates it).
  - **Pending (Codex):** install, the probe, Play Place → Rotate → Delete, then a backup.
  - **Batch 02 tally:** 5 installed, 17 pending (H02_18 among them until integration).
  - **Tests:**
    - counts updated: 57 items, 39 furniture; futuristic furniture 12 (storage 2); futuristic drawer count 12;
    - a new test checks the manifest fields and facts, that the prepared name matches the id, and that no provenance-only keys end up in the catalog;
    - floor placement with the measured bounds: at the centre, against the X edge, overhanging at x = 21 unless turned 90°, the Z overhang when turned, and not below the floor;
    - it's listed under Futuristic > Storage after the shelf, and never in Structure mode or cozy storage.
    - No UI or runtime code changed.
- 57-item install checkpoint (Codex, 2026-10-26; supersedes the "integration pending" notes in the drawer cabinet entry above, which are left as written):
  - **Review:** Codex reviewed ae798e4 and ran the full suite independently: 317 passed, 0 failed.
  - **Installed:** live Edit now has 57 catalog entries and 57 templates (39 furniture, 18 structure); `future_drawer_cabinet_01` is installed.
  - **Checks:**
    - all 57 probes are valid, 0 invalid;
    - real client BuilderRequest Place at (0, 0, 0, yaw 0), Rotate direction 1, and Delete were all ok (revisions 1, 2 and 3), and the test copy was removed;
    - Edit persistence was verified.
  - **Not done:** a physical UI-click or R-key test. The cabinet is decorative only.
  - **Batch 02:** 6 installed (H02_18 among them), 16 pending. No registered item is pending from this checkpoint.
  - **Backup:** a new full-place backup, `StudioBuilder-FullBackup-57Items-2026-10-26-0116.rbxl`, 4,141,758 bytes, SHA256 `383785EC6115EC04623A659974D6AE4AC644CCE4634DEEB6DFBAD510D9D8F73F`.
    - The file and its `<roblox!` header are verified; restore is untested.
    - It includes the cabinet's prepared, template and review copies.
    - Earlier backups are kept. It is local only and not uploaded.
  - The historical manifests are unchanged.

## 9. Studio > Branding: Pending
Requested 2026-10-25. Not started: it waits on the current panel, director and preset source from Codex, and builds on the host checks from task 3 and the saving from task 5.
- UX: a Branding section on the Studio page. The host enters a Roblox image asset ID and sees a preview. They then apply it either to the whole active room's branding, or by clicking or selecting eligible individual surfaces (wall signs, screens, mugs, laptop lids). Apply and Reset per room and per surface.
- Rules: host-authoritative, checked on the server for every apply or reset. Targets come from an allowlist of stable surface IDs, never arbitrary Instances or paths. Only image/decal content is set: never model or script loaders, `LoadAsset`, `require(id)` or arbitrary URLs. The asset ID must be a positive integer, turned into image content server-side. If an image is invalid or unavailable, the prior branding stays. Per-surface overrides are saved with the studio as an additive, versioned preset section, so older presets load unchanged.
- **Visual contract:** Branding sits inside the existing Studio tab, in the same row, heading and input style as the live panel ([`docs/ui-contract.md`](docs/ui-contract.md)). No new visual style.
- Context: laptop Apple logos were already replaced with existing geometric Roblox marks on 11 live and stored instances (Codex).
- Acceptance (draft): tests that actually run cover the asset-ID validation, target allowlist, host check, keeping prior branding on failure, and save/load of overrides including legacy presets. Studio-pending for preview and rendering.

## 10. Structure pieces: walls, floors, ceilings, doorways, windows: In progress (18 pieces and R rotation installed; remote-tested in Play; physical R-key/UI, visual QA and doorway clearance pending)
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
- Batch 03 structure registration (repository; Codex install pending):
  - **Registered (2):** both carry all five collection tags, are appended after the sofa, and use the existing structure conventions.
    - `structure_glass_partition_01` (Grid Glass Partition; `window_wall`, in Windows).
    - `structure_ceiling_acoustic_01` (Acoustic Tile Ceiling; `ceiling`).
  - **Counts:** repository 54 (38 furniture, 16 structure); installed stays **52**.
  - **Glass partition:** from 4494060927 Glass Partition by v7k_1.
    - Measured 15.9999895 × 14.9998140 × 1 (normalized and resized per axis to 16 × 15 × 1, length along local X).
    - Upright identity bottom-centre pivot (error 0.000000954).
    - 2 anchored BaseParts (Part glazing and a UnionOperation black grid frame); 0 Lua, 0 Textures; the redundant weld was removed.
    - Native viewport review: a black grid frame with transparent glazing. It is a fixed glass wall, with no opening or door behaviour.
  - **Acoustic ceiling:** from 551197444 Scaleable Ceiling Tiles by VCVCFans.
    - 1 anchored Part, 16 × 1 × 16 (from the 9 × 0.2 × 9 source), with a bottom-centre identity pivot (error 0).
    - 0 Lua, 2 Textures: texture 342118609 kept at 4 × 4 studs, and the Top texture copied to the Bottom face.
    - The underside was reviewed natively on a flipped gallery copy; the prepared copy stays upright.
  - **Provenance:** `docs/assets/Batch03_Structure_Registration_2026-10-26.json`. Install source: `ServerStorage.StudioBuilderPreparedAssets.<id>`. The historical batch 03 manifests are unchanged.
  - **Approval scope:** visual and static only. Not installed, with no live placement, and not in the 52-item backup.
  - **Pending (Codex):** install, the probe, Play placement, and a backup refresh.
  - **Tallies:**
    - batch 03: 2 prepared and registered, 1 other source quarantined (Modern wood block), 9 thumbnail-only;
    - batch 02 unchanged: 3 installed, 19 pending.
  - **Tests:**
    - counts updated: 54 items; Windows 3, Ceilings 3; 16 structure pieces;
    - a new test checks each piece against its manifest (kind, tags, sourceRef, install source, facts), that its measured size validates on the grid, and that the wood block stays out.
    - No UI or runtime code changed.
- 54-item install checkpoint (Codex, 2026-10-26; supersedes the "install pending" notes in the batch 03 registration entry above, which are left as written):
  - **Review:** Codex reviewed d034a34 and ran its tests independently: 314 passed, 0 failed.
  - **Installed:** the matching `Catalog`, `structure_glass_partition_01` and `structure_ceiling_acoustic_01`. **Installed total: 54** (38 furniture, 16 structure).
  - **Checks:**
    - all 54 live template probes are valid, 0 invalid;
    - filters: Floors 5, Walls 3, Doors 2, Ceilings 3, Windows 3;
    - real client BuilderRequest Place → Rotate → Delete passed for **each** new piece (all six operations ok), using the partition at (0, 0, 8, 0) and the ceiling at (0, 15, 0, 0); the test copies were removed;
    - back in Edit, the 54 templates persist.
  - **Not done:** a physical UI-click or R-key check.
  - **Backup:** a local full-place backup, `StudioBuilder-FullBackup-54Items-2026-10-26-0013.rbxl`, 4,137,806 bytes, SHA256 `48D0C5D40EAA99B0801949284198F70D01B19A83CF4BC7FE963B09538AAFBFC6`.
    - The file exists and its binary Roblox header is verified; restoration is not tested.
    - It contains the prepared, template and review copies of the two pieces.
    - The prior backups are kept. It is local only and not uploaded.
  - **Tallies:**
    - batch 03: 2 installed, 1 quarantined (Modern wood block), 9 thumbnail-only;
    - batch 02 unchanged: 3 installed, 19 pending.
  - The historical manifests are unchanged.
- Industrial wall registration (repository; Codex integration pending):
  - **Registered (1):** `structure_industrial_wall_01` (Industrial Concrete Wall; `wall`, in Walls; futuristic and 1980s), appended last.
    - It's the first structure piece without all five tags. Structure mode ignores style filters, so it still lists under Walls.
    - **Counts:** repository 55 (38 furniture, 17 structure; Walls 4). Installed stays **54**.
  - **Source:** free Creator Store asset 120565443892509, Modular Wall Pack by WilliamBosso; the extracted Straight Wall, batch 02 H02_03 (the original candidate is retained).
  - **Preparation (Codex):**
    - the imported geometry was rotated and normalized, with a minimum trim thickness of 0.05 and depth constrained to one stud;
    - bounds are exactly 16 × 15 × 1, with identity rotation and a bottom-centre pivot at the origin;
    - 26 anchored BaseParts, zero LuaSourceContainers;
    - both faces were inspected in native Studio, and the bounds and pivot assertions passed.
    - Look: gray concrete with dark metal horizontal trim and conduit, a brown lower band and a small pale indicator; the reverse is plain.
  - **Light:** one imported PointLight is present but **disabled**. No lighting adapter behaviour is claimed.
  - **Provenance:** `docs/assets/Industrial_Wall_Registration_2026-10-26.json`. Install source: `ServerStorage.StudioBuilderPreparedAssets.structure_industrial_wall_01`. The batch 02 manifest is unchanged.
  - **Pending (Codex):**
    - install into `StudioBuilderTemplates`, the probe, and Play Place → Rotate → Delete;
    - a refreshed backup after integration (the 54-item backup predates this candidate).
  - **Batch 02 tally:** 3 installed, 19 pending (this candidate among them until integration).
  - **Tests:**
    - counts updated: 55 items, Walls 4, 17 structure; raw tag counts per collection now account for the narrower tags;
    - a new test checks the manifest fields and facts and that the prepared name matches the id;
    - it also checks that the 16 × 15 × 1 module validates on both wall orientations within the live 48 marker, refuses off-grid and wrong-level positions, validates a projected hit, stays out of furniture style lists, and lists last under Walls.
    - No UI or runtime code changed.
- 55-item install checkpoint (Codex, 2026-10-26; supersedes the "integration pending" notes in the industrial wall entry above, which are left as written):
  - **Review:** Codex reviewed 249db85 and ran its suite independently: 315 passed, 0 failed.
  - **Installed:** live Studio now has 55 catalog entries and 55 templates (38 furniture, 17 structure).
  - **Checks:**
    - all 55 probes are valid, 0 invalid;
    - structure filters: Floors 5, Walls 4, Doors 2, Ceilings 3, Windows 3;
    - Industrial Concrete Wall is installed, with its 26 parts anchored and its PointLight disabled (no lighting behaviour claimed);
    - real client BuilderRequest Place at local (0, 0, 8, yaw 0), Rotate direction 1, and Delete all succeeded (revisions 1, 2 and 3), and the test copy was removed;
    - back in Edit, catalog and template persistence was verified.
  - **Not done:** a physical UI-click or R-key test.
  - **Batch 02:** 4 installed, 18 pending. There's no pending industrial registration.
  - **Backup:** a new full-place backup, `StudioBuilder-FullBackup-55Items-2026-10-26-0035.rbxl`, 4,139,781 bytes, SHA256 `5C606E2F9D121958C89C2573FD367F430B2D8DC23735CCC547F8C5D2E22A7097`.
    - The file and its header (`<roblox!`) are verified; restore is not tested.
    - It includes the prepared and installed industrial wall.
    - Earlier backups are kept. It is local only and not uploaded.
  - The historical manifests are unchanged.
- Acoustic wall registration (repository; Codex integration pending):
  - **Registered (1):** `structure_acoustic_wall_01` (Acoustic Foam Wall; `wall`, in Walls; retro, 1980s, futuristic), appended last.
    - **Counts:** repository 56 (38 furniture, 18 structure; Walls 5). Installed stays **55** (38 furniture, 17 structure).
  - **Source:** free Creator Store asset 9069165816, Acoustic Panel Set by DesolatedWorld; batch 02 H02_10 (the original candidate is retained).
  - **Preparation (Codex):**
    - **Adapted from the source:** one grooved UnionOperation, made into an 8-column × 7-row checkerboard with alternating groove directions (56 tiles).
      - Each tile is 1.96 × 0.2 × 1.96, charcoal Fabric RGB 48, 48, 51, with UsePartColor on.
      - Collision and touch are disabled on the tiles.
    - **Added (not from the source):** one plain structural backing Part, 16 × 15 × 0.8, which supplies the collision.
    - **Totals:** 57 anchored BaseParts; measured bounds exactly 16 × 15 × 1; identity rotation; bottom-centre pivot at the origin; zero LuaSourceContainers and zero lights.
    - The front and the plain reverse were inspected in native Studio, and the bounds and pivot assertions passed.
  - **Appearance only:** no sound-absorption behaviour is claimed.
  - **Provenance:** `docs/assets/Acoustic_Wall_Registration_2026-10-26.json`. Install source: `ServerStorage.StudioBuilderPreparedAssets.structure_acoustic_wall_01`. The batch 02 manifest is unchanged.
  - **Pending (Codex):** install, the probe, Play Place → Rotate → Delete, then a refreshed backup (the 55-item backup predates this candidate).
  - **Batch 02 tally:** 4 installed, 18 pending (H02_10 among them until integration).
  - **Tests:**
    - counts updated: 56 items, Walls 5, 18 structure; per-collection structure tags retro 17, 1980s 18, futuristic 18;
    - a new test checks the manifest fields and facts (57 = 56 tiles + 1 backing, the 8 × 7 layout, the backing disclosure, no acoustic claim) and that the prepared name matches the id;
    - it also checks grid validation on both wall orientations, refusals for a cell centre and a raised spot, the exact Walls order, and that it stays out of furniture style lists.
    - No UI or runtime code changed.
- 56-item install checkpoint (Codex, 2026-10-26; supersedes the "integration pending" notes in the acoustic wall entry above, which are left as written):
  - **Review:** Codex reviewed 71c9a2d and ran its suite independently: 316 passed, 0 failed.
  - **Installed:** live Studio now has 56 catalog entries and 56 templates (38 furniture, 18 structure).
  - **Checks:**
    - all 56 template probes are valid, 0 invalid;
    - filters: Floors 5, Walls 5, Doors 2, Ceilings 3, Windows 3;
    - Acoustic Foam Wall is installed: 57 anchored parts, 0 scripts and 0 lights; decorative acoustic appearance only;
    - real client BuilderRequest Place at local (0, 0, −8, yaw 180), Rotate direction 1, and Delete all passed (revisions 1, 2 and 3), and the test copy was removed;
    - back in Edit, catalog and template persistence was verified.
  - **Not done:** a physical UI-click or R-key test.
  - **Batch 02:** 5 installed (H02_10 among them), 17 pending.
  - **Backup:** a new full-place backup, `StudioBuilder-FullBackup-56Items-2026-10-26-0055.rbxl`, 4,141,091 bytes, SHA256 `E290100DCCE4015401016F107D37FCFBF7D7C9DD0C24E7626DDCED5C15EC53DF`.
    - The file and its `<roblox!` header are verified; restore is untested.
    - It includes the acoustic wall's prepared, template and review copies.
    - Earlier backups are kept. It is local only and not uploaded.
  - The historical manifests are unchanged.

## 11. Existing room assets in Build (user request): In progress (10 installed: the water dispenser, the tall floor plant, the conference table, the flower pot, the office chair, the coffee mug, the presentation board, the studio softbox, the umbrella light and the broadcast indicator lamp; 3 remaining: the laptop, the panel door and the metal door; the panel door is a prepared candidate, not registered or installed, with a plan for review)
Make the assets already used in the six existing rooms available in the Build drawer, as decorative catalog entries in the right furniture types (or structure kinds).
- **Waiting on:** an inspected manifest from Codex, covering the prepared templates (zero scripts, anchored, bottom-centre pivots, normalized scale), stable IDs, names, collections, types, sourceRefs and credits. Nothing is registered until then, and nothing guesses which room models qualify.
- The live rooms themselves stay untouched; the builder only gets prepared copies.
- The user is browsing in Edit, so there are no Play or camera changes.
- Acceptance (draft): the same per-manifest catalog tests as earlier registrations, with type and count updates and provenance kept out of the catalog. Studio install and Play check by Codex.
- Water dispenser registration (repository; Codex integration pending). This is the first existing-room extraction; Codex supplied an inspected, per-item preparation report rather than a whole-room manifest:
  - **Registered (1):** `studio_water_dispenser_01` (Water Dispenser; furniture type decor; cozy and 1980s; normal floor placement), appended last.
    - **Counts:** repository 58 (40 furniture, 18 structure). Installed stays **57** (39 furniture, 18 structure).
  - **Source:** extracted from `Workspace.RoomCollection.ConferenceRoom.Water Machine`. The original room is unchanged.
    - The parent free model is 4993294691, per the ConferenceRoom record in `docs/assets/Studio_Asset_Guide_2026-10-25.json` (preparation "Source4993294691").
    - The creator is not independently verified and isn't recorded, and the dispenser has no individual asset ID.
  - **Prepared copy (Codex):** `ServerStorage.StudioBuilderPreparedAssets.studio_water_dispenser_01`.
    - Bounds 1.949987769126892 × 5.100000381469727 × 2.25, with an identity bottom-centre pivot.
    - 20 anchored BaseParts, 14 SpecialMeshes; 0 LuaSourceContainers, 0 Lights, 0 Seats, 0 joints.
    - 16 redundant ManualWelds were removed, the parts anchored, touch disabled and the pivot normalized. The original geometry, colours and meshes were kept, and no geometry was added.
    - Native visual review passed: a white upright dispenser with a translucent blue bottle and water, red and blue labels, and two gray taps.
  - **Decorative only:** no dispensing and no tap animation.
  - **Provenance:** `docs/assets/Water_Dispenser_Registration_2026-10-26.json`. The asset guide and the gap audit are unchanged.
  - **Backup:** the prepared and review copies are newer than the 57-item backup; the original room source is in it.
  - **Pending (Codex):** install, the probe, Play Place → Rotate → Delete, then a backup.
  - **Not affected:** batch 02 stays at 6 installed, 16 pending, because this is a room extraction, not batch 02.
  - **Tests:**
    - counts updated: 58 items, 40 furniture; cozy 28, 1980s 18; cozy All items 28;
    - a new test checks the manifest fields and facts, the room provenance cross-checked against the asset guide's ConferenceRoom record, that no creator, credit or individual asset ID is invented, and that the prepared name matches the id;
    - floor placement with the measured bounds: in a corner, the Z overhang unless turned 90°, and the 24-stud height limit;
    - it's listed last in Cozy > Decor and 1980s > Decor, and never in other styles or Structure mode.
    - No UI or runtime code changed.
- 58-item install checkpoint (Codex, 2026-10-26; supersedes the "integration pending" notes in the water dispenser entry above, which are left as written):
  - **Review:** Codex reviewed cfe56ad and ran the suite independently: 318 tests, all passing.
  - **Installed:** live Edit now has 58 catalog entries and 58 templates (40 furniture, 18 structure); `studio_water_dispenser_01` is installed.
  - **Checks:**
    - all 58 probes are valid, 0 invalid;
    - real client BuilderRequest Place at (0, 0, 0, yaw 0), Rotate direction 1, and Delete were all ok (revisions 1, 2 and 3), and the test copy was removed;
    - Edit persistence was verified.
  - **Not done:** a physical UI-click or R-key test. It is decorative only.
  - **Task 11 status:** 1 installed (the water dispenser). The other 12 entries from the original gap audit are still pending, and there's no claim that all rooms are covered.
  - **Not affected:** batch 02 stays at 6 installed, 16 pending.
  - **Backup:** a new full-place backup, `StudioBuilder-FullBackup-58Items-2026-10-26-0136.rbxl`, 4,142,820 bytes, SHA256 `7005A6253149CD60D2926153EEA787EF0989A592AD6C731F3D09E786A688D8A3`.
    - The file and its `<roblox!` header are verified; restore is untested.
    - It includes the dispenser's prepared, template and review copies.
    - Earlier backups are kept. It is local only and not uploaded.
  - The historical manifests are unchanged.
- Tall floor plant registration (repository; Codex integration pending):
  - **Registered (1):** `studio_tall_floor_plant_01` (Tall Floor Plant; furniture type plants; cozy, retro and 1980s; normal floor placement), appended last.
    - **Counts:** repository 59 (41 furniture, 18 structure). Installed stays **58** (40 furniture, 18 structure).
  - **Source:** extracted from `Workspace.RoomCollection.ConferenceRoom.Potted Plant` (one of the equivalent room copies); this is the gap audit's "Tall potted plant". The original room is unchanged.
    - The parent free model is 4993294691, per the ConferenceRoom record in the asset guide.
    - The creator is not independently verified and isn't recorded, and no individual plant model ID is claimed.
    - The mesh content is recorded in the manifest only: MeshId `rbxassetid://430369152`, texture `rbxassetid://430369173`. Codex found no matching MeshId among the 58 installed templates.
  - **Prepared copy (Codex):** `ServerStorage.StudioBuilderPreparedAssets.studio_tall_floor_plant_01`.
    - Bounds 5.213370323181152 × 7.141579627990723 × 3.7111449241638185, with an identity bottom-centre pivot.
    - One anchored MeshPart; 0 scripts, Lights, Seats and joints; CanTouch false.
    - The original mesh, texture, scale and colours were kept, and no geometry was added.
    - Native visual review: tall textured green leaves on a woody stem in a tapered dark-red pot.
  - **Decorative only:** no sway.
  - **Provenance:** `docs/assets/Tall_Floor_Plant_Registration_2026-10-26.json`. The asset guide and the gap audit are unchanged.
  - **Backup:** the prepared and review copies postdate the 58-item backup; the original room source is in it.
  - **Pending (Codex):** install, the probe, Play Place → Rotate → Delete, then a backup.
  - **Tallies:**
    - task 11: 1 installed, 12 gap-audit entries pending (the plant among them until integration);
    - batch 02 unchanged: 6 installed, 16 pending.
  - **Tests:**
    - counts updated: 59 items, 41 furniture; cozy 29, retro 22, 1980s 19; cozy All items 29;
    - a new test checks the manifest fields and facts, that the prepared name matches the id, that no creator, credit or plant model ID is invented, and that no mesh ID ends up in the catalog;
    - it cross-checks the parent model against the asset guide, and the source path, type and bounds against the gap audit's "Tall potted plant";
    - floor placement with the measured bounds: in a corner, the X overhang unless turned 90°, and the 24-stud height limit;
    - it's listed last in Cozy, Retro and 1980s > Plants, and never in Winter, Futuristic or Structure mode.
    - No UI or runtime code changed.
- 59-item verified installation checkpoint (Codex, 2026-10-26; supersedes the "integration pending" notes in the tall floor plant entry above, which are left as written as history):
  - **Review:** Codex reran the archive of 30e58c1 independently: 319 tests passed, 0 failed.
  - **Installed:** `studio_tall_floor_plant_01` is in `StudioBuilderTemplates` and the live Catalog. **Installed total: 59** (41 furniture, 18 structure).
  - **Checks:**
    - a fresh Catalog/TemplateCatalog probe: 59 entries, 59 templates, 59 valid, 0 invalid;
    - real Play client BuilderRequest Place, Rotate and Delete all succeeded; the test copy was removed, and Studio returned to Edit.
  - **Not done:** physical UI clicks and the R key. The original room is unchanged.
  - **No registered-but-uninstalled items:** the repository and the live install both hold 59.
  - **Tallies:**
    - task 11: 2 installed (the water dispenser and the plant), 11 gap-audit entries remaining;
    - batch 02 unchanged: 6 installed, 16 pending.
  - **Backup:** `StudioBuilder-FullBackup-59Items-2026-10-26-0156.rbxl`, 4,143,330 bytes, SHA256 `96D1A865DD301CA79F0C1F7C8BC92621EA1E0529BBA21EA8DD9123469D6EA605`.
    - The `<roblox!` header is valid; restore is not tested.
    - It includes the plant's new prepared, template and review copies.
    - Earlier backups are kept. It is local only and not uploaded.
  - The historical registration manifest is unchanged.
- Conference table registration (repository; Codex integration pending):
  - **Registered (1):** `studio_conference_table_01` (White Conference Table; furniture type tables; cozy, 1980s and futuristic; ordinary floor placement), appended last.
    - **Counts:** repository 60 (42 furniture, 18 structure). Installed stays **59** (41 furniture, 18 structure).
  - **Source:** extracted from `Workspace.RoomCollection.ConferenceRoom.Table`; this is the gap audit's "Conference table". The original room is untouched.
    - The parent free model is 4993294691, per the ConferenceRoom record in the asset guide.
    - The creator is not independently verified, so no credit is recorded, and no individual table model ID is claimed.
  - **Prepared copy (Codex, Edit):** `ServerStorage.StudioBuilderPreparedAssets.studio_conference_table_01`.
    - Exact bounds X 24.224998474121095, Y 3.299999952316284, Z 11.625, with an identity bottom-centre pivot. The tiny Y difference from the gap audit is normalization rounding.
    - 3 anchored Parts; zero scripts, Lights, Seats and joints; CanTouch false.
    - The original geometry, scale, materials and colours were kept, and no geometry was added.
    - Native viewport review: a large rectangular white Metal tabletop over a narrow dark WoodPlanks underlayer, on a broad dark wood pedestal. It differs in shape and size from all four existing table templates.
    - Review copy: `Workspace.StudioAssetYard.Conference Table Review` at (4028, 1, 3538).
  - **Decorative only:** no automatic chairs, seat adapters or new interactions.
  - **Provenance:** `docs/assets/Conference_Table_Registration_2026-10-26.json`. The asset guide and the gap audit are unchanged.
  - **Backup:** the prepared and review copies postdate the 59-item backup; the original room source is in it.
  - **Pending (Codex):** install, the probe, Play Place → Rotate → Delete, then a backup.
  - **Tallies:**
    - task 11: 2 installed, 11 pending (the table registered among them, awaiting integration);
    - batch 02 unchanged: 6 installed, 16 pending.
  - **Tests:**
    - counts updated: 60 items, 42 furniture; cozy 30, 1980s 20, futuristic 13; futuristic tables 3; cozy All items 30; futuristic drawer 13;
    - a new test checks the manifest fields and facts, that the prepared name matches the id, and that no creator, credit or table model ID is invented;
    - it cross-checks the parent model against the asset guide, and the source path, type and footprint against the gap audit (with the Y rounding difference asserted);
    - large-footprint placement inside the live 48 marker:
      - lengthwise X and Z edge limits;
      - turned 90° and 270°;
      - the wider 45° diagonal extent;
      - a refused off-step yaw;
    - it's listed last in Cozy, 1980s and Futuristic > Tables, and never in Retro, Winter or Structure mode.
    - No UI or runtime code changed.
- 60-item verified installation checkpoint (Codex, 2026-10-26; supersedes the "integration pending" notes in the conference table entry above, which are left as written as history):
  - **Review:** Codex reviewed dbb5ef2 and ran its archive independently: 320 passed, 0 failed.
  - **Installed:** `studio_conference_table_01` is in the live Catalog and `StudioBuilderTemplates`. **Installed total: 60** (42 furniture, 18 structure).
  - **Checks:**
    - a fresh probe: 60 entries, 60 templates, 60 valid, 0 invalid;
    - real Play client BuilderRequest Place at local (0, 0, 0, yaw 0), Rotate direction 1, and Delete succeeded (revisions 1, 2 and 3), and the test copy was removed;
    - back in Edit, persistence was verified.
  - **Not done:** a physical UI-click or R-key test. The original room is untouched, and the table is decorative, with no seats included.
  - **No registered-but-uninstalled items:** the repository and the live install both hold 60.
  - **Tallies:**
    - task 11: 3 installed (the water dispenser, the tall floor plant and the conference table), 10 gap-audit entries remaining;
    - batch 02 unchanged: 6 installed, 16 pending.
  - **Backup:** `StudioBuilder-FullBackup-60Items-2026-10-26-0216.rbxl`, 4,143,957 bytes, SHA256 `4325F4E1C910E27715BFA054ACE452959BAAC4AB5EA382548D617B0EEC2DC234`.
    - The `<roblox!` header is valid; restore is untested.
    - It includes the table's new prepared, template and review copies.
    - Older backups are kept. It is local only and not uploaded.
  - The historical registration manifest is unchanged.
- Red flower pot registration (repository; Codex integration pending):
  - **Registered (1):** `studio_flower_pot_01` (Red Flower Pot; furniture type plants; cozy, retro, 1980s and winter; existing furniture placement, no new placement metadata), appended last.
    - **Counts:** repository 61 (43 furniture, 18 structure). Installed stays **60** (42 furniture, 18 structure).
  - **Source:** extracted from `Workspace.RoomCollection.ConferenceRoom.Flower Pot`; this is the gap audit's "Flower pot". The original room is unchanged.
    - The parent free model is 4993294691, per the ConferenceRoom record in the asset guide.
    - The creator is not independently verified, so no credit is recorded, and no individual model ID is claimed.
  - **Prepared copy (Codex, Edit):** `ServerStorage.StudioBuilderPreparedAssets.studio_flower_pot_01`.
    - Exact bounds 1.9535508155822755 × 2.915562868118286 × 1.935222864151001, within 1e-6 of the gap audit.
    - Identity bottom-centre pivot, with a negligible bounding-centre X offset of 0.000029712915420532228 from float rounding.
    - 38 anchored BaseParts (37 Parts and 1 UnionOperation); 19 SpecialMeshes, 4 CylinderMeshes and 10 BlockMeshes; zero scripts, Lights, Seats and joints; CanTouch false.
    - The original geometry, scale, materials, colours and textures were kept, and no geometry was added.
    - Native visual review: stylized red blossoms and green leaves on dark textured stems in an orange terracotta-style pot with textured soil. It's distinct from the installed green-only plants.
    - Review copy: `Workspace.StudioAssetYard.Flower Pot Review` at (4072, 1, 3538).
  - **Decorative only:** no sway and no interactions.
  - **Provenance:** `docs/assets/Flower_Pot_Registration_2026-10-26.json`. The asset guide and the gap audit are unchanged.
  - **Backup:** the prepared and review copies postdate the 60-item backup; the original room source is in it.
  - **Pending (Codex):** install, the probe, Play Place → Rotate → Delete, then a backup.
  - **Tallies:**
    - task 11: 3 installed, 10 pending (the pot registered among them, awaiting integration);
    - batch 02 unchanged: 6 installed, 16 pending.
  - **Tests:**
    - counts updated: 61 items, 43 furniture; cozy 31, retro 23, 1980s 21, winter 14; winter plants 2; cozy All items 31;
    - a new test checks the manifest fields and facts (parts, meshes, decorative, no new placement metadata), that the prepared name matches the id, and that no creator, credit or model ID is invented;
    - it cross-checks the parent model against the asset guide, and the source path, type and every axis (within 1e-6) against the gap audit;
    - floor placement: corner, X edge, turned 90°, and not below the floor;
    - elevated placement under the same furniture rules: on a 3.3-stud tabletop, at y = 21 (fits), and at y = 21.1 (through the 24-stud ceiling);
    - it's listed last in Cozy, Retro, 1980s and Winter > Plants, and never in Futuristic or Structure mode.
    - Existing test: the tall floor plant's "last in Plants" check now allows later registrations after it.
    - No UI or runtime code changed.
- 61-item verified installation checkpoint (Codex, 2026-10-26; supersedes the "integration pending" notes in the red flower pot entry above, which are left as written as history):
  - **Review:** Codex reviewed e0c91b7 and ran its archive independently: 321 passed, 0 failed.
  - **Installed:** `studio_flower_pot_01` is in the live Catalog and `StudioBuilderTemplates`. **Installed total: 61** (43 furniture, 18 structure).
  - **Checks:**
    - a fresh probe: 61 entries, 61 templates, 61 valid, 0 invalid;
    - real Play client BuilderRequest checks all succeeded:
      1. flower pot floor Place at (0, 0, 0, yaw 0), revision 1;
      2. Rotate direction 1, revision 2;
      3. Delete, revision 3;
      4. conference table Place, revision 4;
      5. flower pot elevated Place at (0, 3.3, 0, yaw 0), revision 5;
      6. Delete the flower pot, revision 6;
      7. Delete the table, revision 7.
    - all test copies were removed, and persistence was verified back in Edit.
  - **Scope:** these are server request tests. They are not physical UI or R-key tests, and not a visual check that the pot sits correctly on the tabletop. The original room is unchanged.
  - **No registered-but-uninstalled items:** the repository and the live install both hold 61.
  - **Tallies:**
    - task 11: 4 installed (the water dispenser, the tall floor plant, the conference table and the flower pot), 9 gap-audit entries remaining;
    - batch 02 unchanged: 6 installed, 16 pending.
  - **Backup:** `StudioBuilder-FullBackup-61Items-2026-10-26-0236.rbxl`, 4,145,249 bytes, SHA256 `0E3241A2FFE94E68ED4595EA30DE25A6CAC231C037141690C10B32065790F750`.
    - The `<roblox!` header is valid; restore is untested.
    - It includes the pot's prepared, template and review copies.
    - Previous backups are kept. It is local only and not uploaded.
  - The historical registration manifest is unchanged.
- Black office chair registration (repository; prepared and registered, integration pending, **not installed**):
  - **Registered (1):** `studio_office_chair_01` (Black Office Chair; cozy, 1980s and futuristic), appended last.
    - **Type:** it was requested as "chairs". The catalog has no `chairs` furniture type, so it uses the existing `seating` type, as `studio_chair_01` and the gap audit's proposal do. Adding a type would change the type chooser UI, which this checkpoint must not do.
    - **Counts:** repository 62 (44 furniture, 18 structure). Installed stays **61** (43 furniture, 18 structure).
  - **Source:** one Office Chair extracted from `Workspace.RoomCollection.ConferenceRoom.Chairs`. It is **not** the 12-chair group, which the gap audit flagged as needing a single-chair extraction. The original room is unchanged.
    - The parent free model is 4993294691, per the asset guide's ConferenceRoom record.
    - The creator is not independently verified, so no credit is recorded, and no individual chair model ID is claimed.
    - Mesh 96065544 and texture 96065600 are recorded in the manifest only.
  - **Prepared copy (Codex):** `ServerStorage.StudioBuilderPreparedAssets.studio_office_chair_01`; review copy `Workspace.StudioAssetYard.Office Chair Review`.
    - **Conversion:** the same SpecialMesh was converted to a MeshPart with AssetService.CreateMeshPartAsync at its original 1.125 scale, keeping the original texture, colour, Concrete material and reflectance.
    - **Pivot:** the intrinsic mesh extents offset was corrected to an identity bottom-centre pivot (minimum Y 0), with the front facing −Z.
    - **Measured bounds** (GetBoundingBox): 2.283479928970337 × 4.147194385528565 × 2.346519231796265.
    - **Contents:** 1 MeshPart; 0 LuaSourceContainers, Lights, Seats and joints; anchored, CanTouch false, Hull collision.
    - **Excluded:** the original invisible collision proxy, the Seat and three ManualWelds.
    - **Look:** a black high-back padded office chair with armrests, a pedestal and five caster spokes, with a subtle fabric texture. Distinct from `studio_chair_01`. Visual review performed.
  - **Decorative placement only:** no sitting, rolling or swivel behaviour yet.
  - **Not yet tested:** live Place, Rotate and Delete, and the UI.
  - **Provenance:** `docs/assets/Office_Chair_Registration_2026-10-26.json`. The asset guide and the gap audit are unchanged.
  - **Backup:** the latest full-place backup is still `StudioBuilder-FullBackup-61Items-2026-10-26-0236.rbxl`. The prepared and review copies postdate it; the original source is in it.
  - **Pending (Codex):** install, the probe, Play Place → Rotate → Delete, then a backup.
  - **Tallies:**
    - task 11: 4 installed, 9 remaining until Studio install verification (the office chair prepared and registered among them);
    - batch 02 unchanged: 6 installed, 16 pending.
  - **Tests:**
    - counts updated: 62 items, 44 furniture; cozy 32, 1980s 22, futuristic 14; futuristic seating 3; cozy All items 32; futuristic drawer 14;
    - a new test checks the manifest fields and facts, the seating-for-"chairs" mapping, that no new furniture type was added, that the prepared name matches the id, and that no creator, credit, model ID or mesh ID is invented or carried;
    - it cross-checks the parent model against the asset guide, and the 12-seat group in the gap audit, confirming this is one chair, not the group footprint;
    - floor placement with the measured bounds: corner, the X edge facing forward versus turned 90°, the Z edge, and the 24-stud height limit;
    - it's listed last in Cozy, 1980s and Futuristic > Seating, and never in Retro, Winter or Structure mode.
    - No UI or runtime code changed.
- 62-item verified installation checkpoint (Codex, Studio Experience, 2026-10-26; supersedes the "integration pending, not installed" notes in the office chair entry above, which are left as written as history):
  - **Review:** Codex reviewed 7bbd018 (the existing seating type confirmed as correct) and ran the archived commit independently: 322 passed, 0 failed.
  - **Installed:** 62 Catalog entries and 62 templates (44 furniture, 18 structure). The live `studio_office_chair_01` template is installed.
  - **Prior Catalog source:** verified against the last-reviewed version and backed up as `ServerStorage.BuilderIntegrationBackups.Catalog_Before62_20261026_0254`.
  - **Checks:**
    - a fresh probe: 62 valid, 0 invalid, 0 not installed;
    - real BuilderRequest calls in Play all succeeded:
      1. Status, revision 0;
      2. Place `studio_office_chair_01` at (0, 0, 0, yaw 0) → `i1`, revision 1, with a server-measured pivot of (2000, 0, 0) and a bounding minimum Y of 0;
      3. Rotate direction 1, revision 2;
      4. Delete, revision 3.
    - back in Edit, the 62-entry catalog and the template persisted, and the test layout was absent.
  - **Scope:** these are server request checks, not physical mouse, R-key or visual UI checks. The chair is decorative only (no sitting, rolling or swivel), and the original room is untouched.
  - **No registered-but-uninstalled items:** repository 62, live 62.
  - **Tallies:**
    - task 11: 5 installed (the water dispenser, the tall floor plant, the conference table, the flower pot and the office chair), 8 original gap-audit entries remaining;
    - batch 02 unchanged: 6 installed, 16 pending.
  - **Backup (new latest):** `StudioBuilder-FullBackup-62Items-2026-10-26-0256.rbxl`, 4,147,271 bytes, SHA256 `C5217F564C31D98F89197137C2210A21860FD200B4EC24614831B70B50AA2220`.
    - The `<roblox!` header is valid; restore is not tested.
    - It includes the chair's prepared, template and review copies.
    - Previous backups are kept. It is local only and not uploaded.
  - The historical registration manifest is unchanged.
- Steaming coffee mug registration (repository; prepared and registered, integration pending):
  - **Registered (1):** `studio_coffee_mug_01` (Steaming Coffee Mug; existing decor type; all five collections), appended last.
    - **Counts:** repository 63 (45 furniture, 18 structure). Installed stays **62** (44 furniture, 18 structure).
  - **Source:** one `Workspace.RoomCollection.ConferenceRoom.Coffee cup`; this is the gap audit's "Roblox coffee mug".
    - It is the **current modified room version**, with project-specific porcelain, recessed coffee, Roblox mark and steam edits, **not** an unchanged free model.
    - The parent room model is 4993294691, per the asset guide. The creator isn't verified, so there's no individual model ID and no credit.
    - The original room is untouched this checkpoint.
  - **Prepared copy (Codex):** `ServerStorage.StudioBuilderPreparedAssets.studio_coffee_mug_01`; review copy `Workspace.StudioAssetYard.Coffee Mug Review`.
    - **Measurements:** GetBoundingBox size 0.7700138092041016 × 0.7425129413604736 × 0.6092129349708557, with an identity bottom-centre pivot (error about 0.00000162 studs).
    - **Contents:** 5 anchored BaseParts (3 Parts and 2 UnionOperations), CanTouch false; 0 scripts, Lights, Seats and joints; 2 SurfaceGuis for the Roblox marks; 1 ParticleEmitter under an Attachment. It was cloned and normalized, with no new geometry.
    - **Look:** a cream hollow porcelain mug with an exterior handle, recessed dark coffee, and black Roblox marks on opposite sides.
    - **Steam:** enabled, rate 4, lifetime 1.8–2.5, speed 0.18–0.27, upward acceleration 0.32, spread 9 × 9, using the built-in `rbxasset://textures/particles/smoke_main.dds`. The Attachment was checked to sit above the liquid and point world-up.
    - **Visual review:** static only; it shows the hollow rim, handle and mark.
  - **Sanitizer:** the existing TemplateSanitizer was checked on disposable clones in Edit. `forPlacement` keeps 1 emitter, 2 SurfaceGuis and 0 scripts; `forPreview` removes the emitter and keeps 2 SurfaceGuis and 0 scripts. No sanitizer code change was needed.
  - **Decorative only:** no pickup or drinking.
  - **Not yet verified:** live Place, Rotate and Delete, steam motion in Play, and elevated tabletop placement.
  - **Provenance:** `docs/assets/Coffee_Mug_Registration_2026-10-26.json`. The asset guide and the gap audit are unchanged.
  - **Backup:** the latest is still the 62-item backup. The prepared and review copies postdate it; the original source is in it.
  - **Tallies:**
    - task 11: 5 installed, 8 remaining (the mug prepared and registered among them, pending integration);
    - batch 02 unchanged: 6 installed, 16 pending.
  - **Tests (kept compact):**
    - counts updated: 63 items, 45 furniture, every collection +1; Futuristic now has a Decor group (decor=1), and winter decor is 5;
    - one focused test covers: the catalog fields only (no provenance or steam keys); the manifest agreeing with the catalog; the modified-version and no-creator records; source and size against the gap audit; floor, tabletop (y = 3.3) and edge placement; and last under Decor in every collection;
    - the water dispenser's "last in Decor" check now allows the mug after it.
    - No UI or runtime code changed.
- 63-item verified installation checkpoint (Codex, Studio Experience `132242140555698`, 2026-10-26; supersedes the "integration pending" and "not yet verified" notes in the coffee mug entry above, which are left as written as history):
  - **Review:** Codex reviewed 552a454 and ran the 323 tests independently: 0 failures.
  - **Installed:** `studio_coffee_mug_01` is in Studio Experience. **Installed total: 63** (45 furniture, 18 structure). The Catalog module was backed up first as `ServerStorage.BuilderIntegrationBackups.Catalog_Before63_20261026_0314`.
  - **Checks:**
    - a fresh Edit probe after Play: 63 catalog entries, 63 templates, 63 valid, 0 invalid, 0 not installed;
    - real BuilderRequest checks passed:
      1. floor Place, revision 1;
      2. Rotate, revision 2;
      3. Delete, revision 3;
      4. conference table Place, revision 4;
      5. tabletop mug Place, revision 5, with the mug's minimum Y at 3.299999833 against the table's maximum Y of 3.299999952;
      6. and 7. only the test mug and table deleted.
    - **Steam:** the emitter was retained, enabled, rate 4, pointing world-up; faint rising steam was visible in native Play screenshots. The temporary camera override was removed.
    - back in Edit, persistence was verified, and no test items remain.
  - **Not done:** physical mouse or R-key UI verification. There's no pickup or drinking behaviour.
  - **No registered-but-uninstalled items:** repository 63, live 63. The wider queue isn't finished.
  - **Tallies:**
    - task 11: 6 installed (the water dispenser, the tall floor plant, the conference table, the flower pot, the office chair and the coffee mug), 7 original gap-audit entries remaining;
    - batch 02 unchanged: 6 installed, 16 pending.
  - **Backup (new latest):** `StudioBuilder-FullBackup-63Items-2026-10-26-0320.rbxl`, 4,148,374 bytes, SHA256 `CF9D24ADA36D3CBCC7D26B9D56029CF99DA24E77BB38E3634E09661C5E474F49`.
    - The Roblox header is verified; restore is untested.
    - Previous backups are kept. It is local only and not uploaded.
  - The historical registration manifest is unchanged.
- Studio presentation board registration (repository; prepared and registered, integration pending):
  - **Registered (1):** `studio_presentation_board_01` (Studio Presentation Board; existing screens type; cozy, 1980s and futuristic), appended last.
    - **Counts:** repository 64 (46 furniture, 18 structure). Installed stays **63** (45 furniture, 18 structure).
  - **Source:** cloned from `Workspace.RoomCollection.ConferenceRoom.WhiteBoard` (the original is untouched); this is the gap audit's "Presentation board".
    - It is the **current project-modified version** with StudioDisplay branding, **not** an unchanged free model.
    - The parent room model is 4993294691, per the asset guide. The creator is unverified, so there's no individual board ID and no credit.
  - **Prepared copy (Codex):** `ServerStorage.StudioBuilderPreparedAssets.studio_presentation_board_01`; review copy `Workspace.StudioAssetYard.Presentation Board Review` at (4204, 1, 3538), yaw 180.
    - **Changes:** 1 ManualWeld removed. The StudioTextRole attributes were removed from the two copied TextLabels, so placed copies can't receive unintended global title updates.
    - **Orientation:** the source was rotated 180° so the front faces −Z (visible face world normal about [0, 0, −1]), and bottom-centred with an identity pivot (error 0.000000533).
    - **Measured bounds** (GetBoundingBox): 9.502521514892579 × 6.674383163452148 × 0.2432195395231247.
    - **Contents:** 9 anchored Parts and 4 CylinderMeshes, CanTouch false; 0 scripts, Lights, Seats and joints; 1 SurfaceGui.
    - **Look:** a thin dark rounded panel with white AFTER HOURS, turquoise PODCAST STUDIO / 01, a white Roblox mark and a CONVERSATIONS / IDEAS / COMMUNITY footer. Native visual review passed.
  - **Sanitizer:** the existing TemplateSanitizer was checked on disposable Edit clones. `forPlacement` and `forPreview` both keep 9 parts and 1 SurfaceGui, with 0 removals; no code change.
  - **Static decorative screen only:** no drawing, video, clickable UI, per-item branding adapter or new wall snapping. It uses existing furniture placement.
  - **Pending:** live Place, Rotate and Delete, and elevated placement.
  - **Provenance:** `docs/assets/Presentation_Board_Registration_2026-10-26.json`. The asset guide and the gap audit are unchanged.
  - **Backup:** the latest is still the 63-item backup. The prepared and review copies postdate it; the original source is in it.
  - **Tallies:**
    - task 11: 6 installed, 7 remaining (the board prepared and registered among them);
    - batch 02 unchanged: 6 installed, 16 pending.
  - **Index corrections (same commit):**
    - The candidate line no longer says all 13 gap-audit objects are unextracted.
    - The "no visual check has been done since" statement now records that later per-item native reviews happened. Physical mouse and R-key checks remain unverified.
  - **Tests:**
    - counts updated: 64 items, 46 furniture; cozy 34, 1980s 24, futuristic 16; Futuristic now lists a Screens group; cozy All items 34; futuristic drawer 16;
    - one compact test covers: the catalog fields only; the key manifest facts (including the StudioTextRole removal and the modified version); source and size against the gap audit; the thin footprint flat against the Z and X edges versus overhanging side-on; raised onto a tabletop and up to the ceiling limit; and the exact Screens lists per collection.
    - No UI or runtime code changed.
- 64-item verified installation checkpoint (Codex, Studio Experience `132242140555698`, 2026-10-26). This is installation evidence. It supersedes the "integration pending" and "pending" notes in the presentation board registration entry above, which stay as written as history:
  - **Review:** Codex reviewed 9a139cc and ran the archived suite independently: 324 passed, 0 failed.
  - **Installed:** `studio_presentation_board_01` is in Studio Experience. **Installed total: 64** (46 furniture, 18 structure).
  - **Catalog source:** guarded against the previously reviewed 63-item version before replacement, and backed up as `ServerStorage.BuilderIntegrationBackups.Catalog_Before64_20261026_0334`.
  - **Checks:**
    - a fresh probe: 64 entries and 64 templates; 64 valid, 0 invalid, 0 not installed;
    - real BuilderRequest checks passed:
      1. floor Place, revision 1;
      2. Rotate, revision 2;
      3. Delete, revision 3;
      4. elevated Place at y = 3.3, revision 4, with a server-measured board minimum Y of 3.299999237. The one SurfaceGui was kept, the visible face is −Z, and there are zero StudioTextRole attributes;
      5. only the test board deleted, revision 5.
    - back in Edit: 64 catalog entries and 64 templates verified, the board persisted, and no test items remain.
  - **Scope:** these are remote/server checks, not physical mouse or R-key UI tests. The static decorative limits remain: no new wall snapping, drawing, video or per-item branding.
  - **No registered-but-uninstalled items:** repository 64, live 64. The wider queue isn't finished.
  - **Tallies:**
    - task 11: 7 installed (the water dispenser, the tall floor plant, the conference table, the flower pot, the office chair, the coffee mug and the presentation board), 6 original gap-audit entries remaining;
    - batch 02 unchanged: 6 installed, 16 pending.
  - **Backup (new latest):** `StudioBuilder-FullBackup-64Items-2026-10-26-0337.rbxl`, 4,149,746 bytes, SHA256 `BDCFA33460196A8B8CEF4E24628803EE5887D0B5DABBD0C8A8B85ED03EAC1366`.
    - The `<roblox!` header is verified; restore is untested.
    - Earlier backups are kept. It is local only and not uploaded.
  - The historical registration manifest is unchanged.
- Studio softbox registration (repository; prepared and registered, installation pending):
  - **Registered (1):** `studio_softbox_01` (Studio Softbox; existing lighting type; cozy, 1980s and futuristic; floor placement), appended last.
    - **Counts:** repository 65 (47 furniture, 18 structure). Live stays **64** (46 furniture, 18 structure).
    - **Size:** the catalog has no size fields. The footprint and height come from the template at install, and the manifest records the measured size.
  - **Source:** `Workspace.RoomCollection.BroadcastSet.Softbox1`; this is the gap audit's "Studio softbox". The original is untouched.
    - It is the project-modified room version, further adapted for Build, **not** an unchanged free model.
    - The parent room asset is 136839605425322, per the asset guide's BroadcastSet record. The creator is unverified, so there's no separate softbox ID and no credit.
  - **Prepared copy (Codex):** `ServerStorage.StudioBuilderPreparedAssets.studio_softbox_01`; review copy `Workspace.StudioAssetYard.Studio Softbox Review` at (4248, 1, 3538), yaw 180.
    - **Orientation normalization:** the source pivot axes were sideways although the geometry stood upright; the gap audit size [2.6022839546, 3.6576573849, 7.9109272957] has the height in Z. The new bottom-centred identity pivot gives [2.602280378341675, 7.910927295684815, 3.657658576965332]: upright along +Y, with the diffuser and light facing −Z, and a measured bottom-centre error of zero.
    - **Contents:** 25 BaseParts (23 Parts and 2 UnionOperations), all anchored, CanTouch false; 0 scripts, Seats and joints; no tags.
    - **Removed:** 2 ManualWelds and 27 Studio*/Podcast* descendant attributes, which isolates it from the old room's fixture IDs and groups.
    - **Diffuser:** changed from dark SmoothPlastic to matte off-white Fabric RGB 225, 223, 214. No geometry was added.
    - **Look:** a tall rectangular off-white fabric diffuser in a dark gray housing, on a vertical pole with four spread support legs. Native visual review complete.
  - **Light:** 1 SpotLight, intentionally **disabled**.
    - Settings: Enabled = false, Brightness 0.4472135901451111, Range 14, Angle 90, Color [1, 0.9194186925888062, 0.8544370532035828], Face Bottom, world direction [0, 0, −1].
    - It's a decorative prop only, pending a separate builder lighting adapter. The original room's controls must not operate it. It isn't to be enabled, and no adjustable lighting is promised.
  - **Sanitizer:** the existing TemplateSanitizer was checked on disposable Edit clones. `forPlacement` keeps the 25 parts and the 1 disabled light; `forPreview` keeps the 25 parts and removes the light. No sanitizer change.
  - **Local evidence:** Codex's `outputs/Studio Softbox Preparation.json` and `outputs/Review Studio Softbox.png` are local and not in this repository.
  - **Provenance:** `docs/assets/Studio_Softbox_Registration_2026-10-26.json`. The asset guide and the gap audit are unchanged.
  - **Pending after review:** live installation, real Place, Rotate and Delete checks, verifying the placed light stays disabled, and a fresh full-place backup. The prepared and review copies postdate the 64-item backup; the original source is in it.
  - **Tallies:**
    - task 11: 7 installed, 6 remaining (the softbox prepared and registered among them, installation pending);
    - batch 02 unchanged: 6 installed, 16 pending.
    - The wider queue isn't finished.
  - **Tests:**
    - counts updated: 65 items, 47 furniture; cozy 35, 1980s 25, futuristic 17; futuristic lighting 3; cozy All items 35; futuristic drawer 17;
    - one compact test covers: the catalog fields only (no light settings or adapter hooks); the key manifest facts (light disabled, room attributes removed, modified version, parent asset per the guide); the size tallest along Y, with the sideways-source normalization documented rather than the old and new axes compared; floor placement in a corner, the Z overhang unless turned, and the height limit; and last in Cozy, 1980s and Futuristic > Lighting.
    - No UI or runtime code changed.
- 65-item verified installation checkpoint (Codex, Studio Experience `132242140555698`, 2026-10-26). This is installation evidence. It supersedes the "installation pending" and "pending after review" notes in the softbox registration entry above, which stay as written as history:
  - **Review:** Codex reviewed a64eb15 and ran all tests independently: 325 passed, 0 failed.
  - **Installed:** `studio_softbox_01` was installed in Edit, with the Catalog guarded against the previous 64-item source. **Installed total: 65** (47 furniture, 18 structure).
  - **Catalog backup:** `ServerStorage.BuilderIntegrationBackups.Catalog_Before65_20261026_0355`.
  - **Checks:**
    - fresh probes before and after Play: 65 catalog entries, 65 templates, 65 valid, 0 invalid, 0 not installed;
    - real BuilderRequest Play checks all succeeded: Status (revision 0), Place `i1` (revision 1), Rotate `i1` (revision 2), Delete `i1` (revision 3);
    - server measurements: 25 parts, 1 disabled light, 0 Studio/Podcast descendant attributes, minimum Y 0, size [2.6021881103515627, 7.910927295684815, 3.657658576965332];
    - **the light was still disabled after rotation;**
    - back in Edit, persistence was verified and zero test items remain.
  - **Scope:** these are remote/server checks, not physical mouse or R-key UI tests. The softbox is decorative only; a builder lighting adapter is still pending.
  - **No registered-but-uninstalled items:** repository 65 = live 65. The wider queue isn't finished.
  - **Tallies:**
    - task 11: 8 installed (the water dispenser, the tall floor plant, the conference table, the flower pot, the office chair, the coffee mug, the presentation board and the studio softbox), 5 original gap-audit entries remaining;
    - batch 02 unchanged: 6 installed, 16 pending.
  - **Backup (new latest):** `StudioBuilder-FullBackup-65Items-2026-10-26-0357.rbxl`, 4,152,323 bytes, SHA256 `DCD1A49520B4529154F1ECCA4FBAA17BCD9F5FBBAA7D07DF33B32EA7D64CFA0C`.
    - The `<roblox!` header is verified; restore is untested.
    - It includes the softbox's prepared, review and installed copies.
    - Earlier backups are kept. It is local only.
  - **Index correction:** the gap-audit file row no longer makes the blanket "not extracted" claim about all 13 objects. It now points to the current tally of 8 installed and 5 unextracted, and the audit JSON is unchanged.
  - The historical registration manifest is unchanged.
- Studio umbrella light registration (repository; prepared and registered, installation pending):
  - **Registered (1):** `studio_umbrella_light_01` (Studio Umbrella Light; existing lighting type; cozy, 1980s and futuristic; floor placement), appended last.
    - **Counts:** repository 66 (48 furniture, 18 structure). Live stays **65** (47 furniture, 18 structure).
  - **Source:** the gap audit's "Lighting umbrella", from `Workspace.RoomCollection.BroadcastSet['Lighting Ubrella']`.
    - The audit measured only the 10-part **head**. The registered item is the **complete fixture**, combining copies of that head, the sibling Medium boom, the Stand tripod and 3 sibling support Parts. The supports sit at source positions [488.041748046875, 3.66770601272583, −1.0360262393951416], [488.02581787109375, 4.199891090393066, −1.4861855506896973] and [488.041748046875, 4.20881462097168, −1.144085168838501].
    - Its counts and dimensions must **not** be equated with the head-only audit figures.
    - The parent room asset is 136839605425322, per the asset guide. The creator is unverified, so there's no separate fixture asset ID and no credit.
    - It is the current project-modified room version, further adapted; the original is untouched.
  - **Prepared copy (Codex):** `ServerStorage.StudioBuilderPreparedAssets.studio_umbrella_light_01`; review copy `Workspace.StudioAssetYard.Studio Umbrella Review` at (4292, 1, 3538), yaw 180.
    - **Removed:** the initial 46-part assembly included two disconnected red/white control-face parts, which were removed. 25 Studio*/Podcast* attributes were also removed. No scripts or joints were found.
    - **Orientation:** rotated yaw 90 and bottom-centred with an identity pivot. The copied head was shifted [0, −0.10, −0.054] in the prepared frame to close a small boom-fitting gap, then the fixture was re-centred. There's no fabricated geometry and no material change.
    - **Final contents:** 44 BaseParts (32 Parts and 12 Unions) and 29 DataModelMeshes, all anchored, CanTouch false; 0 LuaSourceContainers, Seats, joints, remaining attributes and tags.
    - **Final size:** [2.1505026817321779, 6.569082260131836, 2.8773441314697267], identity bottom-centre (measured error 0), upright along +Y. The reflector opening direction is [0.0001253413, −0.4999973178, −0.8660269976]: horizontal along −Z with a 30° downward tilt.
    - **Look:** a white scalloped reflector with a dark outer shell, an angled shaft on an articulated boom, a slim dark pole, a three-legged braced tripod and a side-mounted dark power box. Native visual review is complete: the entire fixture is visible and the shaft joins the boom.
  - **Light:** 1 PointLight, intentionally **disabled** (Enabled = false, Brightness 0.670820415019989, Range 10, Color [1, 0.9194186925888062, 0.8544370532035828]).
    - It's decorative only, pending a builder lighting adapter. There are no adjustable or articulated controls, and the original room's fixture controls must not operate it.
  - **Sanitizer:** the existing TemplateSanitizer on disposable clones. Placement keeps 44 parts and 1 disabled light (removes 0); preview keeps 44 parts and 0 lights (removes 1). No sanitizer changes.
  - **Local evidence:** `outputs/Studio Umbrella Preparation.json` and `outputs/Review Studio Umbrella.png` are local and not in this repository.
  - **Provenance:** `docs/assets/Studio_Umbrella_Light_Registration_2026-10-26.json`. The asset guide and the gap audit are unchanged.
  - **Pending:** live installation, Place, Rotate and Delete, the disabled-light check, and a new full-place backup. The prepared and review copies postdate the 65-item backup; the original source is in it.
  - **Tallies:**
    - task 11: 8 installed, 5 remaining (the umbrella prepared and registered among them, installation pending);
    - batch 02 unchanged: 6 installed, 16 pending.
    - The wider queue is unfinished.
  - **Tests:**
    - counts updated: 66 items, 48 furniture; cozy 36, 1980s 26, futuristic 18; futuristic lighting 4; cozy All items 36; futuristic drawer 18;
    - one compact test covers: the catalog fields only; the key manifest facts (44 parts, disabled light, no attributes, no fabricated geometry, the head-only audit warning); the parent asset per the guide; that it is the complete fixture (more parts and over twice the height of the audited head) and stands upright; floor placement (corner, the Z overhang unless turned, the height limit); and last in Cozy, 1980s and Futuristic > Lighting;
    - the softbox's "last in Lighting" check now allows the umbrella after it.
    - No UI, adapter or runtime code changed.
- 66-item verified installation checkpoint (Codex, Studio Experience `132242140555698`, 2026-10-26). This is installation evidence. It supersedes the "installation pending" and "pending" notes in the umbrella registration entry above, which stay as written as history:
  - **Review:** Codex ran the suite of 499ce49 independently: 326 passed, 0 failed.
  - **Installed:** the reviewed Catalog and the `studio_umbrella_light_01` template. **Installed total: 66** (48 furniture, 18 structure).
  - **Catalog backup:** `ServerStorage.BuilderIntegrationBackups.Catalog_Before66_20261026_0415`.
  - **Checks:**
    - fresh probes before and after Play: 66 catalog entries, 66 templates, 66 valid, 0 invalid or not installed;
    - real BuilderRequest calls all succeeded: Status (revision 0), Place `i1` (revision 1), Rotate `i1` (revision 2), Delete `i1` (revision 3);
    - server measurements: 44 parts, one disabled PointLight, zero Studio/Podcast descendant attributes, minimum Y 0, size [2.1505026817321779, 6.569082260131836, 2.8773441314697267];
    - **the light stayed disabled after rotation;**
    - back in Edit, zero test items remain.
  - **Evidence:** Codex's local `Catalog 66 Installation Checkpoint.json` is not in this repository.
  - **Scope:** these are remote/server checks, not physical mouse or R-key UI tests. The umbrella is decorative only; a lighting adapter is still pending.
  - **No registered-but-uninstalled items:** repository 66 = live 66. The wider queue isn't finished.
  - **Tallies:**
    - task 11: 9 installed, 4 remaining (the guest laptop, the panel door, the On Air sign and the metal door);
    - batch 02 unchanged: 6 installed, 16 pending.
  - **Backup (new latest):** `StudioBuilder-FullBackup-66Items-2026-10-26-0417.rbxl`, 4,156,676 bytes, SHA256 `7DCAC30F3BBA42629687528EC9ED4CE70ABCCDDB33ABBA08A28B92EE1874F740`.
    - The `<roblox!` header is verified; restore is not tested.
    - Earlier backups are kept. It is local only.
  - The historical registration manifest and the gap audit are unchanged.
- Broadcast indicator lamp registration (repository; prepared and registered, installation pending):
  - **Registered (1):** `studio_broadcast_indicator_01` (Broadcast Indicator Lamp; existing lighting type; retro, 1980s and futuristic), appended last.
    - **Counts:** repository 67 (49 furniture, 18 structure). Live stays **66** (48 furniture, 18 structure).
  - **Source:** `Workspace.RoomCollection.BroadcastSet["On Air ausen"]`, corresponding to the gap audit's "On air sign". The original is unchanged.
    - **Native review finding:** it is a **round indicator fixture, not a text sign**: a square gray diamond-plate backing with a green-tinted transparent glass sphere over a dark core, and no lettering, decals, screens or imported meshes.
    - **Type:** the audit proposed decor; it's registered as the existing lighting type, as specified.
    - The parent room asset is 136839605425322, per the asset guide. The creator is unverified, so there's no separate fixture ID and no credit.
    - It is the current project-modified version, further adapted.
  - **Prepared copy (Codex):** `ServerStorage.StudioBuilderPreparedAssets.studio_broadcast_indicator_01`; review copy `Workspace.StudioAssetYard.Broadcast Indicator Review` at (4336, 1, 3538), yaw 180.
    - **Changes:** 3 Parts cloned (one Block, two Balls) and 27 room attributes removed; 0 scripts and joints were found.
    - **Orientation:** a tiny source yaw was normalized and it was rotated Y −90°, so the globe faces −Z with the plate behind at +Z. Identity bottom-centre pivot, error 0; all anchored, CanTouch false.
    - No fabricated geometry and no material, colour or transparency changes.
    - **Final size:** [1.7549996376037598, 1.7549996376037598, 1.3650007247924805]; 0 Lua, Seats, joints, attributes, tags and unanchored parts. The −90° turn swaps the audited X and Z extents.
  - **Light:** one PointLight, intentionally **disabled** (brightness 0.0872066542506218, range 14, color [0.9137254953384399, 0.9372549057006836, 0.9176470637321472]).
  - **Sanitizer:** placement keeps 3 parts and 1 disabled light (removes 0); preview keeps 3 parts and 0 lights (removes 1).
  - **Decorative only:** no recording-status reaction, switch, active lighting, wall snapping, functional wall mount or lighting adapter. It uses existing generic furniture placement only.
  - **Local evidence:** `Broadcast Indicator Preparation.json` and `Review Broadcast Indicator.png` are local and not in this repository.
  - **Provenance:** `docs/assets/Broadcast_Indicator_Registration_2026-10-26.json`. The asset guide and the gap audit are unchanged.
  - **Pending (Codex review and integration):** live installation, real Place, Rotate and Delete, and a new full-place backup. The prepared and review copies postdate the 66-item backup; the original source is in it.
  - **Tallies:**
    - task 11: 9 installed, 4 remaining (the On Air sign among them, now prepared and registered);
    - batch 02 unchanged: 6 installed, 16 pending.
    - The wider queue isn't finished.
  - **Tests:**
    - counts updated: 67 items, 49 furniture; retro 25, 1980s 27, futuristic 19; futuristic lighting 5; futuristic drawer 19;
    - one compact test covers: the catalog fields only (no light, recording or wall-mount hooks); the key manifest facts (3 parts, disabled light, no attributes, "not a text sign", no recording reaction); the parent asset per the guide; the same 3-part source as the gap audit, with the audited X and Z swapped by the turn; placement against an edge versus side-on, on a tabletop, and the height limit; and last in Retro, 1980s and Futuristic > Lighting, never in Cozy or Winter;
    - the softbox and umbrella ordering checks now allow later registrations after them.
    - No UI, adapter or runtime code changed.
- 67-item verified installation checkpoint (Codex, Studio Experience `132242140555698`, 2026-10-26). This is installation evidence. It supersedes the "installation pending" and "pending" notes in the broadcast indicator registration entry above, which stay as written as history:
  - **Review:** Codex ran the 327 tests of 19c2a2e independently: zero failures.
  - **Installed:** the reviewed Catalog and `studio_broadcast_indicator_01`. **Installed total: 67** (49 furniture, 18 structure).
  - **Catalog backup:** `ServerStorage.BuilderIntegrationBackups.Catalog_Before67_20261026_0435`.
  - **Checks:**
    - fresh probes before and after Play: 67 entries, 67 templates, 67 valid, zero invalid or missing;
    - real BuilderRequest checks all succeeded:
      1. Status, revision 0;
      2. floor Place `i1`, revision 1;
      3. Rotate `i1`, revision 2;
      4. Delete `i1`, revision 3;
      5. raised Place `i2` at y = 3.3, revision 4;
      6. Delete `i2`, revision 5.
    - server measurements: 3 parts, one disabled PointLight, zero Studio/Podcast descendant attributes, size [1.7549996376037598, 1.7549996376037598, 1.3650007247924805]; floor minimum Y 0, raised minimum Y 3.299999952316284;
    - **the light stayed disabled after rotation and after raised placement;**
    - back in Edit, no test items remain.
  - **Evidence:** Codex's local `Catalog 67 Installation Checkpoint.json` is not in this repository.
  - **Scope:** these are remote/server checks, not physical mouse or R-key UI tests. It is decorative only: no recording-status reaction, wall snapping or lighting adapter.
  - **No registered-but-uninstalled items:** repository 67 = live 67. The wider queue isn't finished.
  - **Tallies:**
    - task 11: 10 installed, 3 remaining (the guest laptop, the panel door and the metal door);
    - batch 02 unchanged: 6 installed, 16 pending.
  - **Backup (new latest):** `StudioBuilder-FullBackup-67Items-2026-10-26-0437.rbxl`, 4,157,515 bytes, SHA256 `FC83E5A57219C28E79C695E6D0D143F7420E05A031C3F554C9F5E5F78CCBC70A`.
    - The `<roblox!` header is verified; restore is untested.
    - Earlier backups are kept. It is local only.
  - **Nonblocking review finding, for a later cleanup (test code not changed now):** in the broadcast indicator test in `tests/spec/catalog_spec.lua`, the yaw 180 placement near the +Z edge is a valid bounds check. But its label, "backing plate against the +Z edge", is inaccurate: at yaw 180 the backing faces −Z.
  - The historical manifests and the gap audit are unchanged.
- Panel door candidate (Codex, 2026-10-26): **prepared only, not registered and not installed.** This checkpoint is docs and design only.
  - **Candidate:** `ServerStorage.StudioBuilderPreparedAssets.studio_panel_door_candidate_01`, from `Workspace.RoomCollection.ConferenceRoom.Door` (the original is unchanged); this is the gap audit's "Panel door".
  - **Review copy:** `Workspace.StudioAssetYard.Panel Door Candidate Review` at (4380, 1, 3538), yaw 180.
  - **Preparation:**
    - removed 29 Welds, 2 Rotate joints, 1 BodyGyro and 3 invisible helper Parts; no scripts were present;
    - 35 visible anchored Parts remain, CanTouch false, with no joints, forces or scripts;
    - children are Frame and Leaf;
    - uniform 4/3 scale (matching the audited size × 4/3), with an identity bottom-centre pivot;
    - bounds 6.2 × 9 × 1, clear opening about 5 × 8.2 (y 0.2 to 8.4), hinges at local x 2.5, z 0;
    - native screenshot inspected.
  - **Blockers:**
    - the closed anchored leaf blocks passage;
    - it is not a 16 × 15 × 1 module;
    - it doesn't fit the existing doorway's opening of about 5 wide at y 1 to 8.5;
    - its opening starts 0.8 below the floor-module top.
  - **Plan:** [`docs/panel-door-plan.md`](docs/panel-door-plan.md). It covers:
    - a dedicated 16 × 15 × 1 doorway module authored **closed**, as the probe's bottom-centre pivot rule requires, with the frame raised to sill y = 1;
    - open state transient and server-only: never saved, closed on spawn and before any edit;
    - recommended first version: server-side auto-open by proximity, with no prompt, remote or UI change;
    - a pure swing-volume bounds check (`SwingOutOfBounds`);
    - strict catalog door metadata;
    - the tests for the first code checkpoint;
    - decisions D1 to D6 for review.
  - **Provenance:** `docs/assets/Panel_Door_Candidate_Preparation_2026-10-26.json`. Codex's local evidence (`outputs/Panel Door Candidate Preparation.json`, `outputs/Review Panel Door Candidate.png`) is not in this repository.
  - **Backup:** the original source is in the 67-item backup. The prepared and review copies postdate it and need a later backup at installation.
  - **Counts unchanged:** live 67 (49 furniture, 18 structure); task 11 at 10 installed, 3 remaining; batch 02 at 6 installed, 16 pending. The wider queue isn't finished.
- Panel door pure foundation (repository code; **not wired, not registered, not installed**):
  - **Decisions accepted in the review of 85025c9:**
    - a dedicated 16 × 15 × 1 module surround;
    - the frame raised +0.8;
    - automatic opening for any living nearby player;
    - a fixed local −Z swing;
    - no prompts, no new remote, and the current UI kept.
  - **`src/shared/DoorGeometry.luau`:**
    - strict validation of finite, well-shaped door metadata (hinge, closed leaf box including hardware, swing "-z", open angle);
    - the **exact swept box** of the closed leaf box over the whole arc, built from its four corners' circular arcs, which replaces the non-conservative rectangle in the design note;
    - the y bounds, a cardinal-yaw room transform matching `PlacedItemsWorld`, and a bounds check (`SwingOutOfBounds`).
  - **Finding:** the measured hinge-side corner swings about 0.515 past the wall line, beyond the 0.5 half-depth. An inward-swinging outer-edge door therefore exceeds a 49 marker by about 0.015 unless the module recesses the leaf.
  - **`src/server/Core/DoorAutoOpen.luau`:** a pure state machine driven by a fake clock:
    - proximity opening, and closing after an exit delay;
    - separate `occupied` and `blocked` inputs, with missing input held still;
    - holding open while occupied or blocked;
    - reopening from the current progress if obstructed while closing;
    - a fresh opening holds against a solid obstruction;
    - collision off while moving, and closed collision restored only when clear;
    - at most one event per door per update;
    - explicit `reset` and `remove`, and token-protected `complete` that ignores stale callbacks.
  - **StructureGrid is unchanged.** No live source references either module; a test enforces that.
  - **Plan updated** ([`docs/panel-door-plan.md`](docs/panel-door-plan.md)): the swing-volume correction, the fixed module pivot contract, the obstruction and occupancy rules, the adapter contracts (validated live-character scans, the overlap adapter, the leaf driver, and lifecycle hooks covering apply, rollback, commit, reconcile and stale tweens), the first runtime follow-up, and what isn't exercised.
  - **Tests:**
    - 18 new: `door_geometry_spec` (7) and `door_auto_open_spec` (11);
    - **345 passed, 0 failed** in total;
    - mutations that drop the arc extremes, ignore leaf thickness, or let closing ignore an avatar each fail tests.
  - **Not exercised:** anything in Studio (tweens, pivots, physics, collision), the character and overlap adapters, the module itself, catalog registration, the placement integration, the PlacedItemsWorld hook, and avatar walk-through.
  - **Asset index fix:** the remaining-objects lines now say the panel door is extracted and prepared but not registered, rather than "unextracted".
  - **Counts unchanged:** live and repository 67; task 11 at 10 installed, 3 remaining; batch 02 at 6 installed, 16 pending.
