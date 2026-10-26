# Panel door: implementation plan (design only)

Status: **plan for review.** No code, catalog entry or template exists for this yet, and nothing here is claimed to work. The prepared candidate is recorded in [`assets/Panel_Door_Candidate_Preparation_2026-10-26.json`](assets/Panel_Door_Candidate_Preparation_2026-10-26.json).

## What the code does today (inspected)

- **StructureGrid** (`src/shared/StructureGrid.luau`): `doorway` is an edge kind at level 0 on the 16-stud grid, with cardinal yaw. Its length runs along local X, and the module is 16 × 15 × 1. Validation checks the grid, the level, the yaw, and that the template's size box fits the bounds. Nothing knows about a moving part.
- **The existing doorway** (`structure_doorway_01` and `_wide_01`): a static open frame. Its measured opening (D4 in [`structure-placement-plan.md`](structure-placement-plan.md)) is x −2.5 to 2.5 and y 1 to 8.5, with a threshold at y 0 to 1. **Floor modules occupy y 0 to 1**, so a walkable opening starts at y 1.
- **TemplateCatalog probe**: requires an upright pivot at the **bounding-box bottom centre**. A template authored with its leaf open would shift the box and fail the probe.
- **TemplateSanitizer**: strips code, prompts, click and drag detectors, and remotes from every clone, and anchors every part. The preview also drops collision. A door template stays script-free and survives this unchanged.
- **PlacedItemsWorld**: clones, sanitizes, tags (`BuildItemId`) and `PivotTo`s whole models. Move, rotate, remove and load all go through it. That's the one place to hook a door reset.
- **PlacementCore / Protocol**: Place, Move, Rotate, Duplicate, Delete, Undo, Redo and Status. All of these are host-only edits under one lock, with revisions and history. Rate limit: edit 12 burst at 6/s.
- **SaveSnapshot**: saves `{ Id, CatalogId, Transform }` only, with Build Version 1. There's no per-item state field.
- **Build UI**: Furniture/Structure categories, the type chooser, and Structure filters Floors, Walls, Doors, Ceilings and Windows. A door module lists under **Doors** with no UI change.

## Recommendation

### 1. Template: a dedicated 16 × 15 × 1 doorway module, authored closed

- Codex builds `structure_doorway_panel_01` in Studio: a 16 × 15 × 1 wall panel with a cut-out sized to the 6.2 × 9 frame, holding the prepared **Frame** and **Leaf** at local x = 0.
- **Raise the frame 0.8** so its clear opening sits at y **1.0 to 9.2**, level with the floor-module top and the existing threshold. Otherwise the bottom 0.8 of the opening is below the floor surface. The frame top is then at 9.8, well inside 15.
- The surround is project-built geometry (from the existing wall kit's material). It is recorded as such and not attributed to the free model.
- Children: `Frame` (static) and `Leaf` (a Model whose parts are all anchored).
- **Pivot contract:** identity, at the bottom centre of the 16 × 15 × 1 box (the wall-line centre), with the **leaf closed**. The probe then passes, and StructureGrid needs no size change.
- **Why not standalone furniture:** it wouldn't join walls, would leave gaps around a 6.2-wide frame, and has no grid rule for an opening.

### 2. Door state: saved pose closed, open state transient

- **Saved:** only the module transform, as today. **No new save fields; Build Version stays 1.**
- **Open or closed:** server memory only. It is never saved, never in history and never a revision.
- Every spawn starts closed: Place, Duplicate, load, recovery reconcile and Undo/Redo respawn.
- Any edit effect on a door snaps it closed first, then the edit applies to a closed model. That covers Move, Rotate, Delete, replace and reconcile. A moving leaf can't be carried into a new pose or saved half-open.

### 3. Behaviour: trusted server code, with auto-open by proximity in the first version

- A new server module, **DoorController** (`src/server/Runtime/`), owns every leaf. Templates stay script-free.
- **First version:** a leaf opens when any player's character root is within about 6 studs of the opening centre, measured server-side. It closes after the doorway has been clear for about 2 seconds.
  - No client request, no new remote, no prompt and no UI change.
  - Authorization, range and rate concerns are avoided because clients never ask: the server reads its own character positions.
  - A bounded tick (4 Hz, over at most 150 items, doors only) keeps the cost small.
- **Swing:** the leaf rotates 90° about its vertical hinge axis, at local x = 2.5, z = 0 (both hinge centres measured there). It always swings toward local **−Z**, tweened server-side with `PivotTo` on the anchored Leaf. The leaf's CanCollide is off while it's moving. Closed it blocks; open it sits beside the opening.
- **Swing volume (local):** a quarter disc of radius about 5.25 about the hinge: x −2.75 to 2.5, z −5.25 to 0. That's inside the module's half-cell (8), so it never reaches the next edge line.
- **Alternative for review (D2):** an explicit toggle (click or tap) over a dedicated DoorRequest remote. It would need its own rate bucket (for example 4 burst at 2/s), a server-side range check of about 10 studs from the hinge, and a decision on who may toggle. It's more code and touches the client input, so it isn't recommended first.

### 4. Placement and clearance rules

- **Grid:** the door module uses the existing `doorway` kind, so R-rotate, snapping and bounds work unchanged.
- **Room bounds:** add a pure `StructureGrid.doorSwing(transform, door)` that returns the room-space swing box. Validation also refuses a door whose swing box leaves the bounds, with a new code `SwingOutOfBounds`.
  - On the live 48 marker, outer edges are already refused, as walls are (D2).
  - On a future 49 marker, only an inward-swinging yaw is accepted on an outer edge.
- **Furniture in the swing:** not blocked in the first version. Anchored parts don't collide physically; the leaf may pass through furniture visually. This is documented as a known limit, not hidden.

### 5. Catalog metadata

- A new optional top-level `door = { hingeX = 2.5, swing = "-z", radius = 5.25 }`, strictly validated: only on `structure.kind == "doorway"`, with no other keys and finite numbers.
- The probe also checks that the template has `Frame` and `Leaf` children.
- No asset IDs. The provenance stays in the manifest.

## Lifecycle summary

| Event | Door behaviour |
|---|---|
| Place / Duplicate / load / reconcile | Spawns closed |
| Move / Rotate | Snaps closed, then moves; it can reopen afterwards |
| Delete / Undo removal | Snaps closed, then removes; its state is dropped |
| Host change, save, preset load | No door state involved |
| Preview ghost | Closed (sanitized preview clone, no collision) |

## Tests for the first code checkpoint (pure, run in `tests/run.lua`)

1. **Catalog:** the door metadata's strict validation (wrong kind, extra keys, non-finite values all rejected), plus registration counts (Doors filter 2 → 3).
2. **StructureGrid.doorSwing:** for each yaw 0/90/180/270, the swing box is on the expected side, with the right extents from the hinge and radius.
   - On the 49 marker, an outer edge with an outward swing gives `SwingOutOfBounds` and an inward swing is accepted.
   - Interior edges are accepted.
3. **DoorController core** (no Roblox, with a fake clock and fake characters):
   - it opens within range and stays closed out of range;
   - it closes after the clear delay;
   - the reset hook snaps it closed;
   - delete drops its state;
   - duplicate and load start closed;
   - the tick cost is bounded by the number of doors.
4. **Persistence:** `SaveSnapshot.encode` output is identical whether a door is open or closed (no door state is ever saved).
5. **Hinge maths:** rotating the leaf 90° keeps its hinge-side edge fixed, and its far edge lands at radius distance on −Z.
6. **Static guards:** the door template and runtime add no ProximityPrompt, ClickDetector or new RemoteEvent in the auto-open version.

## What the first usable checkpoint would deliver

- **Repository:** the catalog entry `structure_doorway_panel_01` (kind doorway, with door metadata), `StructureGrid.doorSwing` and its validation, DoorController (a pure core plus a thin runtime) wired through a PlacedItemsWorld reset hook, and the tests above. No UI changes.
- **Codex in Studio:** build the 16 × 15 × 1 surround with the frame raised to sill y = 1, install it, then check in Play:
  - probe;
  - Place, Rotate, Move, Duplicate, Delete;
  - Save/load (it loads closed);
  - an avatar walking through as it auto-opens;
  - the leaf closing after the clear delay;
  - a fresh backup.
- **Until then:** none of this is claimed working. The candidate is prepared only, not registered, not installed and untested.

## Decisions for review

- **D1:** a module surround (recommended) or a standalone door.
- **D2:** auto-open by proximity (recommended for the first version) or an explicit toggle remote.
- **D3:** who opens it: everyone nearby (auto) or only the host.
- **D4:** a fixed −Z swing side (recommended), or a mirrored variant later.
- **D5:** raise the frame so its sill is at y = 1 (recommended).
- **D6:** whether furniture in the swing is ignored in the first version (recommended) or blocks placement.
