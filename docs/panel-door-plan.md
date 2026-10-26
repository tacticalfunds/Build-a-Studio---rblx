# Panel door: implementation plan

**Status:**
- The design checkpoint (85025c9) was accepted with corrections.
- The foundation (8275097) was reviewed and **not accepted for integration**. Four state-machine defects were found (token reuse, invalid first clock, lenient input, the reopen bypass); they are fixed in the following commit.
- The **pure foundation** is now implemented and tested: `src/shared/DoorGeometry.luau` and `src/server/Core/DoorAutoOpen.luau`.
- **No live entry point, catalog entry, template, runtime, UI or save-schema change references them yet**, and a test enforces that.
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
- **Opening:** finish at full travel. Avatars aren't solid, and collision is off.
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

## Adapter contracts for the first runtime

| Adapter | Contract |
|---|---|
| **Nearby scan** (server) | Each tick, scan only **live characters in the current sandbox**: a Humanoid with Health > 0, a root part present, and its position **finite** and inside the sandbox bounds plus a small margin. Measure room-space distance to each door's opening centre; `nearby` means within about 6 studs. Bound the scan: players × doors, at most 150 doors, at 4 Hz. No client input is involved, but positions are still validated. |
| **Occupancy and obstruction** (server, later) | Query the room-space `sweptBox` (plus the doorway opening box) for overlapping parts. Exclude **only** the owning door model (its own surround, `Frame` and `Leaf`) and the floor piece directly supporting it, where it merely touches at the sill. **Adjacent walls and any other structure are not globally ignored:** anything that actually intrudes into the sweep counts. Parts of a living character's model count as `occupied`; every other solid part (placed furniture, other structure) counts as `blocked`. If the scan can't run or returns bad data, the runtime must pass an **unknown** input (for example, omit it), which holds the door still. |
| **Leaf driver** (server) | Handles each event. **opening / closing / held:** tween the Leaf's pivot about the hinge from the event's progress, with collision off. **opened / closed:** final pose. **collision** and **closed with collide = true:** restore the leaf's closed collision. **snapClosed:** cancel the tween, then pivot to closed. Report tween completion with `complete(id, token)`. Always compute poses from the stored module pivot and hinge. |
| **Lifecycle hook** (PlacedItemsWorld) | Before a door-affecting `apply` (move, remove, replace) and on `rollback` and `reconcile`, cancel its tween and call `reset(id)`, so the edit works on a closed leaf at the stored pivot. On a spawn `commit`, `add(id)` (it starts closed); on a remove `commit`, `remove(id)`. A rolled-back spawn never `add`s; a rolled-back remove keeps the door, already reset. Duplicate and load spawn closed. |
| **Persistence** | Nothing. Door state never enters SaveSnapshot, BuildModel, history or revisions. |

## First runtime follow-up (next code checkpoint, not started)

1. Catalog: `structure_doorway_panel_01` (kind `doorway`), plus a strictly validated optional `door` field. It's validated by `DoorGeometry.validate`, and the catalog never carries asset IDs. The probe also checks for `Frame` and `Leaf` children.
2. Placement: use `DoorGeometry.check` alongside StructureGrid for door items, so an out-of-bounds swing is `SwingOutOfBounds`. StructureGrid's existing behaviour stays as it is.
3. Runtime: a DoorController wiring the adapters above to `DoorAutoOpen`, plus a PlacedItemsWorld hook that's optional and a no-op for non-doors.
4. Tests for the lifecycle hook with fake worlds: apply, rollback, commit, reconcile, duplicate and load. Also a SaveSnapshot encode that's identical with doors open or closed, and a check that no prompts or remotes are added.
5. Codex in Studio: build and install the module, then check in Play:
   - probe;
   - Place, Rotate, Move, Duplicate, Delete and Undo;
   - Save/load (it loads closed);
   - auto-open and walk-through;
   - holding with an avatar in the doorway;
   - holding against furniture in the sweep;
   - a fresh backup.

## What this checkpoint does NOT exercise

- **Studio, Play, physics and collision:** nothing real, including real tweens, CFrame pivots and actual leaf poses.
- **Adapters:** character scans and overlap queries don't exist yet.
- **The module itself:** not built, and its final hinge and leaf metadata aren't known.
- **The wider build path:** catalog registration, the placement integration and the PlacedItemsWorld hook aren't wired.
- **Avatar walk-through and clearance:** untested.
