# Structure placement plan: walls, floors, ceilings, doorways, windows

**Status:** this is a plan only. **Nothing here is implemented.**
- No structure catalog entries, snapping, server rules or UI exist yet.
- The 10 candidates in [`docs/assets/Structure_and_Decor_Candidates_2026-10-25.json`](assets/Structure_and_Decor_Candidates_2026-10-25.json) are prepared in Studio (`ServerStorage.StudioStructureCandidates`), but they're **not** registered in `Catalog.luau` and **not** in the Build UI.
- **Structural snapping is not done.**

Everything below refers to the placement code as it is now. The decisions marked **D1–D7** need review before implementation.

## 1. What the current code does (and what that means for structures)

| Current behaviour | File | Consequence for structures |
|---|---|---|
| A transform is `{ x, y, z, yaw }`: the bottom-centre pivot, in studs from the sandbox origin (floor centre). | `Transform.luau` | Walls, floors and ceilings fit the existing format, so **no save format change** is needed (section 6). |
| Yaw must be a multiple of `RotationStep` (15°). `Rotate` adds ±15°. | `Transform.normalizeYaw`, `PlacementCore planners.Rotate` | Structure pieces need yaw in {0, 90, 180, 270}, and `Rotate` must step 90° for them. |
| Positions are quantized to 0.01 studs. The client grid snap is `GridSize` = 1. | `Config`, `PlacementPreview` | Structures need a separate **16-stud structure grid** (the module size). |
| Bounds: the yawed AABB must fit within `halfX`/`halfZ`, with `y >= 0` and `y + sy <= height`. The sandbox is the `StudioBuilderSandbox` marker part: `halfX = Size.X/2`, `halfZ = Size.Z/2`, `height = Size.Y`. | `Transform.fits`, `RoomProvider.markerSource` | A wall centred on the outer edge of the sandbox pokes 0.5 studs out and is refused, so the grid must be inset (D2). A ceiling needs `height` at or above its top (D3). |
| Overlaps and floating are **allowed**; the server checks bounds only (Codex decision, task 3). | `PlacementCore`, `docs/adapters.md` | Without a new rule, a window can float and a wall can be deleted from under one. The first slice keeps this policy (D5). |
| The preview raycasts the pointer and accepts only upward faces (`upDot >= 0.7`), then snaps x/z to the 1-stud grid. | `PlacementPreview`, `BuilderClient env.raycast` | Floors and walls can use the floor hit. A ceiling can't be reached by an upward-facing hit at its height. A window needs a **vertical** face. These need structure-specific preview modes. |
| Duplicate offsets by the yawed size, rounded up to `GridSize`, trying +x, -x, +z, -z. | `planners.Duplicate` | For 16 × 1 walls this gives a 16-stud step along the length. Good, but on a structure piece it must also keep the 16-stud grid. |
| Item cap 150; saved entries are validated on load and **preserved, not dropped**, when not placeable. | `Config.MaxItems`, `PlacementCore:prepareLoad` | A 3 × 3-cell room is 9 floors + 9 ceilings + 12 walls = 30 items. A structure rule that a saved piece no longer meets keeps it preserved. |

## 2. Catalog: a structure category, separate from style collections

- **New per-item field:** `structure = { kind = "floor" | "wall" | "corner" | "doorway" | "ceiling" | "window" }`.
  Items without it are ordinary furniture and decor.
- **Collections stay style tags.** The manifest tags the kit walls with all five styles; the tags are kept for future themed variants.
  The drawer shows structure pieces **only in Structure mode**, never mixed into the Cozy/Retro/… furniture lists.
- **Ordinary items:** `retro_record_player_01`, `retro_radio_01` and `cozy_shoji_divider_01` (categories `decor` and `divider`) are normal catalog items. They can be registered through the usual catalog path (as for the 24-item expansion) in their own checkpoint.
  The divider's **272 parts** need a performance review before high-density use.
- **Structure metadata comes from Codex's measurements, never from guesses:**
  - opening box of each doorway and window wall (local min/max);
  - wall centreline offset (where the 1-stud wall sits relative to the pivot);
  - the corner's leg geometry;
  - the window frame's mounting depth.

  The manifest records `doorwayCenterAt4StudsClear` and a zero seam gap at a 16-stud pitch. Everything else must be measured.
- **Ceiling provenance:** `structure_ceiling_01` is a **neutral recolour of the kit floor geometry**, not a distinct marketplace model. It shares the floor's source (`sourceRef` …`Modular Room.Model.Floor`, asset 12219944662, creator plexaruszx).
  The catalog entry must say so.

## 3. Structure grid and placement rules

Cells are 16 × 16 studs (the straight wall is 16 × 15 × 1; the floor tile is 16 × 1 × 16).

| Kind | Position | Yaw | Height (y of pivot) |
|---|---|---|---|
| floor | cell centre | 0 / 90 / 180 / 270 | 0 (base level only; no multi-storey in this slice) |
| ceiling | cell centre | 0 / 90 / 180 / 270 | wall top (D3) |
| wall, doorway, window wall | centre of a cell **edge**; length along the edge (the walls are aligned to local X, so yaw 0 means an edge parallel to X, yaw 90 an edge parallel to Z) | multiples of 90 | 0 (D3) |
| corner | cell centre; yaw picks the corner (the quadrant of the pointer) | multiples of 90 | 0 |
| window (frame) | on the face of a wall piece, flush to the wall plane, with x/z along the wall snapped to 1 stud and y to 1 stud | the wall's yaw (+180 for the other face) | between the wall's bottom and top, minus the frame height |

**Server rule (new), applied in `_clean` for items with `structure`:**
- yaw in {0, 90, 180, 270};
- the position must match the kind's grid rule, using the same maths as the client;
- the existing bounds check.

The rule is pure and shared, like `Transform` (for example, a `StructureGrid` module in `src/shared`), so the preview turns invalid exactly where the server refuses.
Windows aren't required to touch a wall on the server (D5), but must use a 90° yaw.

`Rotate` on a structure piece steps 90°. On a wall it swaps the edge orientation about the same edge centre; the result has to stay on the grid, or it's refused as `OutOfBounds`.

## 4. Decisions needed (D1–D7)

1. **D1 Grid origin.** I recommend anchoring the cell grid to the sandbox origin, with cell edges at multiples of 16 from it (x = 16i), so the centre of the sandbox is a cell corner.
   The alternative is the sandbox centre as a cell centre.
2. **D2 Outer walls vs. bounds.** A wall centred on an edge at `x = ±halfX` extends 0.5 studs past the bounds, and today's `Transform.fits` refuses it.
   - Option a: size the marker so the outermost usable edge plus 0.5 fits (with D1, `halfX = 16n + 0.5`, e.g. 32.5).
   - Option b: allow structure pieces exactly `thickness/2` of overhang.

   I recommend option a: no special case in the server.
3. **D3 Heights.** I recommend floor tiles at y = 0 (top at 1), walls at y = 0 (the bottom stud hidden by the tiles; about 14 studs visible), and ceilings at y = 15 (top at 16).
   That fits a sandbox at least 16 high (the tests use 16; the live marker height must be confirmed by Codex).
   The alternative is walls at y = 1 on top of the tiles and ceilings at 16, which needs a sandbox at least 17 high and leaves walls without tiles floating 1 stud.
4. **D4 Door clearance.** The doorway is about 4 studs clear at its centre (manifest). Opening height and exact width must be measured.
   I recommend that the server refuse a **structure** piece whose AABB intersects a doorway's opening box, extended 2 studs to each side of the wall. The structure kinds here are wall, corner, window frame and another doorway.
   Furniture in a doorway stays allowed, consistent with the overlap policy, but the preview shows a warning colour.
   Avatar clearance (R15 width and height) is a Play test, not a calculation.
5. **D5 Supports and attachments.** This keeps the current "floating allowed" policy for the first slice:
   - deleting a wall under a window or a floor tile under furniture is allowed;
   - the dependants stay where they are, and the drawer can warn ("This wall has a window on it").

   No support graph, no cascade delete, no attachment field in the save.
   The alternative is support links with cascade or refusal. That needs a new save field and compound undo entries (a delete that removes several items must undo as one step). I suggest a later checkpoint for that.
6. **D6 Window type.** `structure_industrial_window_01` (5.2 × 7.1 × 1.4) mounts as a frame on the **face of a plain wall**, a decorative overlay. It doesn't cut an opening.
   `structure_window_wall_01` is the wall with a real opening. Codex should confirm this reading of the two assets.
7. **D7 Corner fit.** The corner's 16 × 15 × 16 box has to be measured against the straight-wall centreline. If its legs are flush with the cell edge rather than centred on it, it sits 0.5 studs off the straight walls.
   No offset is guessed. The rule waits for Codex's measurement.

## 5. Client preview and Build UI (no redesign)

- **Structure mode:** a `STRUCTURE` toggle button in the existing action row of the Build drawer, built with `PanelTheme` like Undo/Redo/Back/Done.
  It switches the existing filter row (same position, size, 6 px gaps, same chip style) between the five style collections and five structure kinds: **Floors, Walls, Doors, Ceilings, Windows**.
  There is no new tab, panel, colour or font; selected chips use teal with dark text, as now.
- **Preview modes**, all pure and testable like `PlacementPreview`:
  - floor and ceiling: the cell from the floor hit (ceiling at the D3 height, ghost drawn there);
  - wall, doorway, window wall: the nearest cell edge to the floor hit, with the orientation from that edge;
  - corner: the cell, with the yaw from the quadrant;
  - window: needs a raycast that accepts **vertical** faces of placed wall items (`upDot` near 0), then snaps onto that face.
- **R** rotates 90° in Structure mode (15° otherwise). Escape and the existing input rules are unchanged.
- Ghost colours as now: teal when valid, the existing red tint when invalid, plus the doorway-warning case (D4).

## 6. Undo, history and save compatibility

- **No new effects:** structure pieces use Place/Move/Rotate/Duplicate/Delete and their existing effects, so Undo/Redo and the history work unchanged.
  Exact logical IDs are restored, and the host epoch and recovery rules apply.
- **No save format change:** they're ordinary `Build.Items` entries (`Id`, `CatalogId`, `Transform`).
  A preset with structure pieces loads on any builder that knows the catalog IDs.
  On a builder whose grid rule refuses a saved piece (for example, after D1 or D2 change), the piece is **preserved, not dropped**, by the existing `prepareLoad` classification, and written back on save.
- **Seat assignment (task 7):** unaffected. Structure pieces have no seat profiles.
- **If D5 later moves to support links:** a new versioned field and compound history entries are needed. That's out of scope here.

## 7. Tests to add with the implementation

- `StructureGrid` maths on edges and centres for every yaw; on-grid and off-grid refusals; outer-edge bounds per D2.
- Server: structure yaw and position rules in Place, Move, Rotate (90° steps), Duplicate (stays on the grid), Undo/Redo, and load classification (preserved when off-grid).
- Doorway clearance (D4), with measured boxes from fixtures labelled as fixtures.
- Preview: floor, edge, corner and ceiling modes, and wall-face attachment for windows.
- Drawer: Structure mode reuses the filter row and theme tokens (`client_ui_spec` style).

## 8. Not executed / still needed from Codex

- Runtime placement of any structure piece (manifest: "runtime placement not tested").
- Measurements for D3, D4, D6 and D7, and the live sandbox marker size for D2.
- A Play test of avatar clearance through doorways, floor/wall collision, and window fitting.
- A new full-place backup. It's still pending; the previous native backup interaction was stopped by the user, and isn't bypassed.
