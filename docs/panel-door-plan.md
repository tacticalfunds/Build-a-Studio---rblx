# Panel door: implementation plan

**Status:**
- The design checkpoint (85025c9) was accepted with corrections.
- The foundation (8275097) wasn't accepted; its corrections (a65d89c) were accepted.
- **The runtime layer is now implemented, tested and DORMANT:**
  - `src/server/Runtime/DoorSensing.luau`;
  - `src/server/Runtime/DoorController.luau`;
  - `src/server/Runtime/DoorRuntimeAdapters.luau`;
  - an optional lifecycle hook in `PlacedItemsWorld`.
- **Nothing activates doors:**
  - the production bootstrap and BuilderService don't create a controller;
  - BuilderService builds the world with no hook (exactly three arguments);
  - no source outside the door modules names a door module.
  - A test enforces all three.
- **Also unchanged:** there's no catalog entry and no installed template, and no UI, remote or save-schema change.
- Nothing here is claimed to work in Studio.
- The prepared candidate is recorded in [`assets/Panel_Door_Candidate_Preparation_2026-10-26.json`](assets/Panel_Door_Candidate_Preparation_2026-10-26.json).

## Decisions (made in the review of 85025c9)

- **D1:** a dedicated 16 × 15 × 1 module surround.
- **D2:** automatic opening for any **living** nearby player.
- **D4:** a fixed local **−Z** swing side.
- **D5:** the frame raised **+0.8**, so the clear opening sits at y 1.0 to 9.2.
- **UI and remotes:** the current UI is kept, with no prompts and no new remote.
- **Furniture in the swing holds the door**, rather than the leaf visually slicing through it. There's no general furniture-placement rewrite.

## What the code does today (inspected)

- **StructureGrid:** `doorway` is a 16 × 15 × 1 edge kind at level 0, with cardinal yaw and length along local X. It knows nothing of moving parts, and it is **unchanged** by this work.
- **Existing doorway** opening: x −2.5 to 2.5, y 1 to 8.5. Floor modules occupy y 0 to 1.
- **TemplateCatalog probe:** requires an upright pivot at the **bounding-box bottom centre**. So the template must be authored with the leaf **closed**.
- **TemplateSanitizer:** strips code, prompts, detectors and remotes, and anchors every part. The door template stays script-free.
- **PlacedItemsWorld:** a two-phase `apply`, then `commit` or `rollback`, plus `reconcile`. It's the one place to hook door resets.
- **PlacementCore:** host-only edits under one lock, with revisions and history.
- **SaveSnapshot:** saves only `{ Id, CatalogId, Transform }` (Build Version 1).

## Template and pivot contract

- Codex builds `structure_doorway_panel_01`: a 16 × 15 × 1 panel with a cut-out holding the prepared `Frame` and `Leaf`, with the frame raised so its sill is at y = 1. The surround is project-built geometry.
- **The module pivot is fixed:** identity, at the bottom centre of the 16 × 15 × 1 box with the leaf closed. The runtime must **store this pivot when it spawns the door and always use it**, for edits, resets and tweens. It must never recompute it from `GetBoundingBox` or `GetPivot` while a leaf is open, because an open leaf shifts the box.
- **Hinge and leaf metadata** come from the installed module (the candidate's values move by the +0.8 raise). They are validated by `DoorGeometry.validate`.

## Swing volume (correction 1)

- The earlier rectangle, x [−2.75, 2.5] by z [−5.25, 0], was **not conservative**. The closed leaf, with its hardware, already reaches x about 2.70 (past the hinge at 2.50) and z ±0.475.
- **`DoorGeometry.sweptBox` replaces it with an exact construction.** At any angle, the box of a rotating rectangle is set by its four corners. So the union over the whole 0..open arc is the box of the four corners' circular arcs: each arc's end points, plus any ±x or ±z extreme the arc passes. It is padded by 1e-6.
- **Measured candidate** (hinge x 2.49988, z 0; leaf centre x 0.09984; size 5.20007 × 8.20009 × 0.95):
  - x **−2.5228 to 3.0153**; z **−5.0226 to 0.5154**; y **0.2 to 8.4**.
  - The hinge-side corner swings out about 0.515 past the wall line, beyond the wall's 0.5 half-depth.
  - So even an inward-swinging door on an outer edge needs bounds about 0.015 larger than a 49 marker. That's recorded as a finding for the module build: recessing the leaf or the frame would remove it.
- **Tests:** the corners are sampled every 0.25° across 0..90° and checked inside the box, which is also tight to within 1e-3. The 45°, 120° and 180° arcs and a mirrored hinge are sampled too. All four cardinal yaws are checked against an independent CFrame-convention transform. A mutation that drops the arc extremes fails 5 tests, and one that ignores thickness fails 3.

## Auto-open state machine (corrections 2 and 3, revised after the review of 8275097)

`DoorAutoOpen` is pure, with a fake clock. Per door it tracks a phase (`closed`, `opening`, `open`, `closing`, `held`), a progress value (0 = closed, 1 = open), whether it's collidable, and a motion token.

**Inputs per door, supplied by the runtime adapters:** a table with **exactly** these three booleans:
- `nearby`: a living player is close enough to want it open.
- `occupied`: an avatar is in the doorway or the leaf's sweep.
- `blocked`: a solid obstruction is anywhere in the sweep, other than the door's own parts and its supporting floor.

Anything else is **unknown**: a missing input, wrong types, missing keys or extra keys.

**Safety rule:** the leaf only moves when the whole sweep is known clear, which means a valid input with `blocked = false`.
- **Unknown or blocked input never starts, continues or reverses a motion.** A moving leaf stops where it is (`held`, collision off). A closed, open or held leaf stays put, and an open leaf's exit timer restarts. Closed collision is never restored on unknown input.
- The whole-sweep `blocked` flag can't tell the opening path from the closing path, so a blocked door holds rather than guessing. The earlier "reverse retraces space it just swept" bypass was **removed**: "clear earlier" doesn't prove the return path is clear now.

**With valid, unblocked input:**
- **Closed:** nearby → open. Otherwise closed collision is restored once the doorway isn't occupied.
- **Opening:** finish at full travel. Avatar occupancy doesn't stop an opening, and an avatar can make a closing reopen, while no solid obstruction is present. The leaf's collision is off during any motion. **That is the door's visual behaviour, not a claim that avatars have no collision**: the leaf may pass visually through an avatar while it swings.
- **Open:** nearby or occupied → stay open. Otherwise close after `exitDelay` seconds of being clear (2 s by default).
- **Closing:** nearby or occupied → reopen from the current progress (the return path is known clear). Otherwise finish closed, with collision on.
- **Held:** nearby or occupied → open. Otherwise close. Either way it resumes from where it stopped.

**Guarantees:**
- **Tokens** come from one counter shared by every door and are **never reused, even across remove and re-add of the same id**. So an old tween callback can't complete a replacement registration (undo, reconcile).
- `complete(id, token)` accepts only the current motion's token. Reversal, hold, reset and remove all invalidate earlier tokens.
- **Clock:** nothing happens before the first finite `now`. A nil, NaN or infinite `now` makes `update` a no-op and stores no motion; an earlier finite time is clamped.
- At most one event per door per update, in insertion order, with at most 150 doors.
- Motions finish by the clock (with a 1e-9 tolerance) or via `complete`.
- `reset(id)` snaps it closed with collision waiting for a clear update. `remove(id)` drops its state.

**This is not a security lock.** Auto doors open for any living player nearby.

## Runtime layer (implemented, dormant)

| Piece | What it does |
|---|---|
| **DoorSensing** (`src/server/Runtime/DoorSensing.luau`) | Pure logic over two injected queries; it produces each door's `{ nearby, occupied, blocked }`. More detail below. |
| **DoorController** (`src/server/Runtime/DoorController.luau`) | Registrations, edits, ticking and poses; more detail below. |
| **DoorRuntimeAdapters** (`src/server/Runtime/DoorRuntimeAdapters.luau`) | The Roblox pieces, with types injected so tests use fakes. `characters()` returns Players' characters (`alive` = Humanoid Health > 0, position from `origin:PointToObjectSpace`). `queryBox()` calls `GetPartBoundsInBox` over the room box with `MaxParts`, reports `truncated` when the limit is reached, names each hit's top-level model (a placed item or a character), and takes `supportingFloor` from an injected predicate. `driver` pivots the Leaf to `module * hinge * Angles(0, -swingSign * angle, 0) * hinge:Inverse() * closedOffset`, where `module` always comes from the stored record. It records each leaf part's original `CanCollide` at attach. |
| **PlacedItemsWorld hook** | An optional 4th argument; with none, nothing changes. More detail below. |

**DoorSensing:**
- **Characters:** only entries that are `alive`, with finite positions inside the sandbox plus a margin, count. One bad entry is skipped. A failed scan, a non-table result or more than `maxCharacters` entries makes every door **unknown**.
- **Overlap hits:** each is classified. The owning door model is ignored; a counted character's model means occupied; a part flagged supporting floor that only touches the sweep's bottom is ignored. **Everything else blocks**, including adjacent walls, other structure, furniture, dead characters and a floor piece that rises into the sweep.
- **Unknown door:** a failed or truncated query, more than `maxHits` hits, or a malformed hit makes that door unknown, and unknown doors are left out of the result.
- **Query box:** always the conservative whole-sweep room box from `DoorGeometry`.

**DoorController:**
- **Keyed by model:** registrations are keyed by model, not placement id. Each gets a never-reused core id (`door#<generation>`).
- **Specs:** a door's spec comes from an injected, validated `specFor(itemId)`. Nil or invalid means it isn't a door and is left alone. Nothing is hardcoded or registered.
- **Poses:** each tick, the pose is `openDegrees` × the core's linear progress at `now`. There are no tweens and no completion callbacks, so there's no easing disagreement and nothing completes twice.
- **Scans:** sensing runs at `scanInterval` over unfrozen doors only. Results older than `maxInputAge` count as unknown.
- **Collision:** off on every motion, hold or reset event. The template's original states come back only on `collision` or `closed` with `collide = true`, i.e. closed and clear.
- **Edits:**
  - `attach` (frozen), `beginEdit` (snap closed, collision off, freeze, remember the record), `moved`, `cancelEdit` (restore the record, thaw), `thaw` and `detach`.
  - A frozen door gets no input, so it can't reopen between an edit's apply and its commit or rollback.
- **Lifecycle:** at most one heartbeat connection. `stop` disconnects it. `destroy` disconnects, returns doors to closed with their original collision, releases every registration and core entry, and makes later calls no-ops. The controller holds no other connections or tasks.

**PlacedItemsWorld hook**, with every call guarded:
- **spawn:** attach frozen, then thaw on commit or detach on rollback.
- **move:** `beginEdit` **before** the pivot changes, then `moved`. Rollback re-pivots, then `cancelEdit`.
- **remove:** `beginEdit` before unparenting. Commit detaches; rollback cancels.
- **replace:** only after every new model has built (a failed build calls nothing). The old set gets `beginEdit` and the new set is attached frozen. Commit detaches old and thaws new; rollback does the reverse.
- **reconcile:** detach dropped and stray models; kept models get `beginEdit`, pivot, `moved`, then `thaw`; respawns are attached, then thawed. A failure mid-door leaves that door frozen and closed.
- Duplicate, load, undo and redo all reach the world as these same effects.

**Transient state only:** door state never changes build revisions or saves. No door module mentions SaveSnapshot, BuildModel, BuildPersistence, revisions, attributes or DataStores (checked statically), and the integration test sees zero revision publishes.

## Before activation (next checkpoints, not started)

1. Codex builds the 16 × 15 × 1 module (frame raised +0.8; recess the leaf if the 0.515 hinge-side overhang matters on outer edges), measures its hinge and leaf, and installs it.
2. Register `structure_doorway_panel_01` with its door metadata (validated by `DoorGeometry`). Add `DoorGeometry.check` to placement for door items, giving `SwingOutOfBounds`. Probe for `Frame` and `Leaf`.
3. Wire it up: the bootstrap creates a DoorController with the real adapters (supplying the origin, the folder, a supporting-floor predicate and `RunService.Heartbeat`) and passes it to PlacedItemsWorld. That changes the dormant guard deliberately.
4. Studio Play checks:
   - probe;
   - Place, Rotate, Move, Duplicate, Delete, Undo and Redo;
   - Save/load (it loads closed);
   - walk-through and auto-open;
   - an avatar in the doorway holding it open;
   - furniture in the sweep holding it;
   - **real overlap false positives** (for example adjacent walls touching the sweep box);
   - collision states;
   - a fresh backup.

## What is NOT exercised (still unverified)

- **Studio:** nothing runs there, including real CFrame maths, actual leaf poses, physics, collision and replication.
- **Real overlap queries:** `GetPartBoundsInBox` behaviour is unverified: false positives from parts merely touching the box, rotated part extents (the adapter's `maxY` is an axis-aligned estimate), and characters' accessories.
- **Real Players and Humanoids:** the adapters are tested only against fakes.
- **The door module and activation:** the module isn't built and its final metadata is unknown. There's no catalog registration, placement integration or bootstrap wiring, and no avatar walk-through.
