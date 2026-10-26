# Studio asset index

Metadata snapshot of the live Roblox place. **This is an index, not the models.**
No binary models or place files are stored in this repository.

| | |
|---|---|
| Place | Studio Experience, place ID `132242140555698` |
| Snapshot date | 2026-10-25 (inventory generated `2026-10-25T17:42:27Z`) |
| Produced by | Codex (asset discovery / Studio integration), from a local Studio scan |

## Current state: refresh of 2026-10-25 (installed commit 46d55cb)

**Start here for what's installed and pending now:** [`refresh-2026-10-25/README.md`](refresh-2026-10-25/README.md).
It's a full asset list with descriptions, appearance evidence, function versus proposed use, collection tags, source paths, IDs, creators and credits, dimensions, counts of parts, scripts and effects, the model hierarchy, dependencies, script metadata, limitations and SHA-256 checksums. Checksums and counts were verified on archive.

| Group | Count |
|---|---|
| Installed catalog templates | 38 (zero embedded scripts) |
| Tracked unregistered candidates | 13 (3 earlier prepared + 2 new walls + 8 new imports) |
| Live rooms | 6 |
| Nested/copy Model records | 5,758 (**not** unique marketplace assets) |
| Distinct content references | 500 |
| Script containers | 59 |

The refresh's installed and pending sections are current. The files below are earlier snapshots, kept unchanged as history; where their status claims differ, the refresh wins.

## Files (historical snapshots)

Read them in this order:

| File | What it holds | Size |
|---|---|---|
| [`Studio_Asset_Handoff_2026-10-25.txt`](Studio_Asset_Handoff_2026-10-25.txt) | Plain-text summary: read-first rules, builder contract, a summary of each stored asset, and the six rooms. **Start here.** | 24 KB |
| [`Studio_Asset_Guide_2026-10-25.json`](Studio_Asset_Guide_2026-10-25.json) | Human-oriented guide. `assets` (39 stored top-level entries: 34 previous + 5 `BuilderAssetReview` candidates), `rooms` (6), `commonPreparation`. Each entry has appearance, function, evidence, proposed collections and known provenance. | 53 KB |
| [`Studio_Asset_Inventory_2026-10-25.json`](Studio_Asset_Inventory_2026-10-25.json) | Exhaustive index. `ModelRecords` (2594 **nested** models, not distinct products), `LooseParts` (4), `ContentReferences` (448 distinct content URLs/IDs with use paths), `ScriptRecords` (13), `Services`. | 2.3 MB |
| [`Catalog_Expansion_2026-10-25.json`](Catalog_Expansion_2026-10-25.json) | The catalog expansion manifest: 24 templates prepared in `ServerStorage.StudioBuilderExpansion`, each with id, displayName, collections, sourceRef, an optional `sourceAssetId` (provenance only, never loaded), scripts (0), parts, size and functionality (decorative only). Original provenance, kept unchanged: its `status` and `templatePath` describe the pre-install state. The items were later installed into `StudioBuilderTemplates` and checked in Play (see [`../integration-catalog-expansion.md`](../integration-catalog-expansion.md)). | 16 KB |
| [`Existing_Room_Catalog_Gap_Audit_2026-10-26.json`](Existing_Room_Catalog_Gap_Audit_2026-10-26.json) | Read-only Play audit of **13 existing room objects or groups** (Conference Room and Broadcast Set) as possible Build additions. **These aren't imported, extracted, registered or Build-ready assets.** Flags: the **Guest laptop has 611 parts** and needs optimizing or a lower-part replacement; the **Office chairs** entry is a 12-seat group, so a single chair must be extracted; the **two doors** need grid and clearance adaptation (opening not verified); the **softbox, umbrella and On Air sign** each contain a light and need orientation and light-control review. No scripts were found in these 13 (not a whole-place audit). Template extraction is pending Edit mode. | 7 KB |
| [`Catalog_Hunt_Batch03_2026-10-26.json`](Catalog_Hunt_Batch03_2026-10-26.json) | Catalog hunt batch 03: 48 search results, 16 previews reviewed, 12 shortlisted, 4 rejected. **Thumbnail review only: not imported, not script-audited, not tested, not registered.** | 9 KB |
| [`Catalog_Hunt_Batch02_2026-10-26.json`](Catalog_Hunt_Batch02_2026-10-26.json) | Catalog hunt batch 02: 8 inspected free sources and 22 candidate pieces. Prepared copies are reported in `ServerStorage.CatalogHuntPrepared02`, but their **persistence is unverified**: the folder is absent on the current Play server. The originals, with scripts disabled, are in `ServerStorage.CatalogHuntBatch02`. **Candidates only: not registered, not Build-ready.** Fit, orientation, visual and placement review are pending, and there's no review gallery yet. | 16 KB |
| [`Structure_Expansion_2026-10-26.json`](Structure_Expansion_2026-10-26.json) | 9 structure variants prepared and visually reviewed by Codex in Edit (anchored, bottom-centre pivots, zero scripts): 4 floors, 2 walls, a ceiling, a window wall and a wide doorway. They're adapted free assets and material variants of the modular kit (source 12219944662), plus the tracked White Brick Wall (12782716872) resized to the grid, not independent models. Install source: `preparedPath`. **Registered in `Catalog.luau`; Studio install pending.** The wide doorway's opening is 8 × 9 above a 1-stud threshold; avatar walkthrough not tested. | 5 KB |
| [`Decor_Candidate_retro_classic_floor_lamp_01_2026-10-26.json`](Decor_Candidate_retro_classic_floor_lamp_01_2026-10-26.json) | Provenance for `retro_classic_floor_lamp_01` (Classic Shaded Floor Lamp), recorded from Codex's inspection report. It's one of the tracked candidates (import 4128475322 by bearduckmonkey), normalized and approved: one MeshPart, zero scripts and Light objects (decorative, no illumination), 2 × 6.5 × 2 studs. **Registered in `Catalog.luau`; Studio install pending.** | 2 KB |
| [`Decor_Candidate_retro_patterned_rug_01_2026-10-26.json`](Decor_Candidate_retro_patterned_rug_01_2026-10-26.json) | Provenance for `retro_patterned_rug_01` (Patterned Vintage Rug), recorded from Codex's inspection report. It's one of the 13 tracked candidates (import 11829259774 by caductis), normalized and approved: one MeshPart, zero scripts, scale 0.65, 9.04 × 0.30 × 10.03 studs. **Registered, installed and Play-checked (after a9bf5ba).** It also records that the two pillow derivatives are not approved. | 2 KB |
| [`Structure_and_Decor_Candidates_2026-10-25.json`](Structure_and_Decor_Candidates_2026-10-25.json) | 10 **candidates**, prepared and visually inspected in Edit mode in `ServerStorage.StudioStructureCandidates`, with labelled manual-use copies in `StudioAssetYard/08 Structure and Decor Review/Prepared Pieces`. **Not registered in `Catalog.luau` and not in the Build UI.** Also: inspection notes, 2 rejected imports and 3 deferred ones (below). | 12 KB |
| [`Studio_Components_2026-10-25.json`](Studio_Components_2026-10-25.json) | Functional components, including inactive storage duplicates: `Fixtures` (161 lights), `Seats` (95 Seat/VehicleSeat), `Effects` (55 emitters), `Sounds` (2), `Displays` (83 text displays), `RoomConfig` (26). | 90 KB |

## Catalog hunt batch 03 (2026-10-26): thumbnail-reviewed ONLY, NOT imported, NOT registered

Inventory: [`Catalog_Hunt_Batch03_2026-10-26.json`](Catalog_Hunt_Batch03_2026-10-26.json), archived exactly as provided.
- **Review so far:** 48 search results; 16 previews visually reviewed; 12 shortlisted; 4 rejected.
- **Status:** thumbnail review only. **Not imported, not script-audited, not placement-tested, not registered and not Build-ready.**
- **Checked on archive:**
  - the JSON parses;
  - the 12 IDs are unique, and every store link and thumbnail link matches its asset ID;
  - none of the 16 IDs (shortlisted or rejected) appears elsewhere in this repository's asset docs, source or status files.
- **Next step (from the inventory):** import to an isolated ServerStorage folder in Edit mode, inspect scripts and geometry, then adapt and test placement before any Build registration.
- The proposed types and collections are proposals, not approved catalog data.

**Shortlisted (12)**

| Source asset | Name | Creator | Proposed type | Proposed collections | Look (thumbnail) |
|---|---|---|---|---|---|
| 71809634278314 | Road Cases (Rack Standard) | Taz Tech Industries / Technology A-Z! | Audio | 1980s, futuristic | Three black equipment road cases with silver edging; useful rack/production-room dressing. |
| 1845221071 | Curtains & Curtain Rod | visionpsyche7 | Decor | cozy, retro, winter | Cream draped curtains on brass rod; can soften windows and room backgrounds. |
| 76638260331408 | Vintage Wingback Armchair | Bobas5525pro | Seating | cozy, retro, winter | Deep green tufted wingback armchair with blanket, cushion and books; decorative objects may obstruct seated avatars. |
| 551197444 | Scaleable Ceiling Tiles! | VCVCFans | Ceilings | 1980s, futuristic | Grid of white speckled ceiling tiles; needs fitting to the existing 16-stud structure module. |
| 8446424278 | Radiator | josxphh | Decor | cozy, winter | White modern panel radiator with visible valve and pipe. |
| 2248688016 | Radiator (Mesh) | 980246 | Decor | retro, 1980s, winter | Metal fin radiator; orientation must be corrected and confirmed. |
| 120679877080216 | sideboard | dasha_fat | Storage | cozy, retro, winter | Dark wooden hutch with upper/lower cupboards, open shelf and plate decor. |
| 365063567 | sideboard | Kiaraomgg | Storage | 1980s, futuristic | Simple dark sideboard with white vase, red flowers and a lamp; components may be separable. |
| 109536795681280 | 🚪 Realistic Door Mesh - Detailed Interior Exterio | EchoXE2Scyth3O1327 | Doors | retro, 1980s | Weathered light painted panel door in frame; static prop until inspected and adapted, no opening behaviour promised. |
| 4494060927 | Glass Partition | v7k_1 | Walls | retro, 1980s, futuristic | Black grid-frame glass partition with rectangular panes. |
| 16526376998 | Glass partition Updated! | ValuMart PLC | Walls | futuristic | Tall frameless dark glass partition on slim base. |
| 112665732912463 | Modern wood block | ITZREAL_SZ4 | Walls | cozy, retro, futuristic | Pale vertical wood slats over a dark backing, useful feature-wall finish. |

**Rejected (4)**

| ID | Reason |
|---|---|
| 28682 | Very basic lamp; not a quality improvement over existing lamps. |
| 105749 | Primitive rounded wooden arch; does not fit desired detailed room structure. |
| 13121115362 | Preview shows material sphere rather than ready ceiling geometry. |
| 96888576123141 | Branded floor wedge speaker; not intended neutral studio monitor. |

## Catalog hunt batch 02 (2026-10-26): candidates only, NOT registered, NOT Build-ready

Inventory: [`Catalog_Hunt_Batch02_2026-10-26.json`](Catalog_Hunt_Batch02_2026-10-26.json), archived exactly as provided.
- **What it is:** 22 candidate pieces from 8 inspected free Creator Store sources. The Modular Wall Pack and the Modular Wall Trim Pack were listed earlier as deferred; they're now inspected.
- **Where the copies are:**
  - Prepared copies: `ServerStorage.CatalogHuntPrepared02.H02_xx`, reported anchored and script-free.
    **Persistence UNVERIFIED (correction, 2026-10-26):** an Edit-mode execute returned the 22 prepared models, but the current Play server has **no** `CatalogHuntPrepared02` folder. Whether the prepared copies persist can only be confirmed after returning to Edit.
    Codex saved a recreation script locally at `work/prepare-hunt-batch02.luau`; that's on Codex's machine, not in this repository.
  - Imported originals: `ServerStorage.CatalogHuntBatch02`, with their scripts disabled. It's present on the current Play server. All 8 originals are preserved.
- **Scripts:** the Futuristic Furniture pack contained welding, vehicle-movement, text-banner and unpacker scripts. None of them ran, and none is in the prepared copies.
- **Still to review:** geometry, orientation, visuals and placement, including the acoustic panels (currently sideways) and the unusually oriented industrial walls.
  - The industrial walls and trims don't match the 16 × 15 × 1 structure module, so grid adaptation is needed before any structure use.
  - **No review gallery exists yet for this batch:** Studio entered Play before gallery staging.
- **Not done:** none of these are in `Catalog.luau` or the Build UI. The "type" column is the proposed category from the inventory, not an approved catalog type.

| Candidate | Name | Proposed type | Proposed collections | Size (studs) | Parts | Creator (source asset) |
|---|---|---|---|---|---|---|
| H02_01 | Industrial Corner Wall 1 | Walls | futuristic, 1980s | 36.64 × 36.64 × 12.72 | 64 | WilliamBosso (120565443892509) |
| H02_02 | Industrial Corner Wall 2 | Walls | futuristic, 1980s | 33.70 × 33.70 × 12.72 | 64 | WilliamBosso (120565443892509) |
| H02_03 | Industrial Straight Wall | Walls | futuristic, 1980s | 33.44 × 2.76 × 12.72 | 26 | WilliamBosso (120565443892509) |
| H02_04 | Wall Trim A | Walls | cozy, retro, 1980s, winter, futuristic | 4.00 × 4.00 × 4.00 | 1 | KoBoIce (87617727134882) |
| H02_05 | Wall Trim B | Walls | cozy, retro, 1980s, winter, futuristic | 8.00 × 4.00 × 8.00 | 1 | KoBoIce (87617727134882) |
| H02_06 | Wall Trim C | Walls | cozy, retro, 1980s, winter, futuristic | 8.00 × 4.00 × 8.00 | 1 | KoBoIce (87617727134882) |
| H02_07 | Wall Trim C+ | Walls | cozy, retro, 1980s, winter, futuristic | 12.00 × 4.00 × 12.00 | 1 | KoBoIce (87617727134882) |
| H02_08 | Metal Frame Glass Door | Doors | futuristic, 1980s | 7.99 × 7.33 × 0.39 | 8 | HAmonbeat999 (11450448430) |
| H02_09 | Arched Window | Windows | cozy, retro, winter | 6.01 × 12.04 × 1.00 | 6 | ClearlyRach (492934961) |
| H02_10 | Acoustic Panel Set | Decor | retro, 1980s, futuristic | 6.00 × 0.20 × 16.00 | 15 | DesolatedWorld (9069165816) |
| H02_11 | Leather Sofa | Seating | cozy, retro, 1980s, winter | 10.97 × 4.00 × 6.02 | 1 | leutxiz (10026927662) |
| H02_12 | Record Console Shelf | Audio | retro, 1980s, cozy | 14.00 × 6.40 × 4.00 | 57 | Savageboy (126677556) |
| H02_13 | Future Speaker | Audio | futuristic | 2.20 × 3.20 × 1.10 | 5 | SebbyTheGODKid (1375085945) |
| H02_14 | Future Shell Chair | Seating | futuristic | 3.49 × 3.57 × 3.72 | 17 | SebbyTheGODKid (1375085945) |
| H02_15 | Future Couch | Seating | futuristic | 4.30 × 4.30 × 7.50 | 26 | SebbyTheGODKid (1375085945) |
| H02_16 | Future TV Stand | Storage | futuristic | 3.26 × 4.56 × 14.67 | 2 | SebbyTheGODKid (1375085945) |
| H02_17 | Future Chaise | Seating | futuristic | 4.20 × 4.15 × 10.49 | 9 | SebbyTheGODKid (1375085945) |
| H02_18 | Future Dresser | Storage | futuristic | 6.43 × 4.20 × 3.28 | 6 | SebbyTheGODKid (1375085945) |
| H02_19 | Future Desk | Tables | futuristic | 8.00 × 7.60 × 7.20 | 20 | SebbyTheGODKid (1375085945) |
| H02_20 | Future Coffee Table | Tables | futuristic | 9.00 × 2.20 × 5.00 | 10 | SebbyTheGODKid (1375085945) |
| H02_21 | Future Counter | Storage | futuristic | 4.10 × 3.20 × 10.00 | 8 | SebbyTheGODKid (1375085945) |
| H02_22 | Future Refrigerator | Decor | futuristic | 4.00 × 8.00 × 4.21 | 5 | SebbyTheGODKid (1375085945) |

The creator links and thumbnails are in the JSON. They're provenance only and never loaded.

## Structure and decor candidates (2026-10-25)

**Registered, structure pieces (installed in Studio at 24e8047; visual QA pending):** `structure_wall_01`, `structure_window_wall_01`, `structure_doorway_01`, `structure_floor_01`, `structure_ceiling_01`, with structure kinds wall, window_wall, doorway, floor and ceiling.
**Registered, decor (catalog only; Studio install pending):** `retro_record_player_01` (with the creator's requested credit "RushioLCO (credit requested)" kept verbatim in the catalog's `credit` field) and `retro_radio_01` (creator zzz_1551). Both are decorative, with no audio.
**Deferred, not registered:** `structure_corner_01`, `structure_industrial_window_01`, `cozy_shoji_divider_01`.
The structure plan is [`../structure-placement-plan.md`](../structure-placement-plan.md).
The 10 templates have zero scripts and zero unanchored parts, and 319 parts in total.

| ID | Name | Category | Size (studs) | Parts | Source asset | Creator / credit |
|---|---|---|---|---|---|---|
| `structure_wall_01` | Plaster Wall | wall | 16 × 15 × 1 | 1 | 12219944662 | plexaruszx |
| `structure_window_wall_01` | Window Wall | wall | 16 × 15 × 1 | 7 | 12219944662 | plexaruszx |
| `structure_doorway_01` | Open Doorway Wall | doorway | 16 × 15 × 1 | 5 | 12219944662 | plexaruszx |
| `structure_corner_01` | Plaster Corner | wall | 16 × 15 × 16 | 2 | 12219944662 | plexaruszx |
| `structure_floor_01` | Wood Floor Tile | floor | 16 × 1 × 16 | 2 | 12219944662 | plexaruszx |
| `structure_ceiling_01` | Plain Ceiling Tile | ceiling | 16 × 1 × 16 | 2 | 12219944662 (the floor geometry) | plexaruszx |
| `structure_industrial_window_01` | Industrial Window Frame | window | 5.2 × 7.13 × 1.39 | 1 | 13304797063 | 2BeeSupreme |
| `retro_record_player_01` | Vintage Record Player | decor | 2.1 × 2.35 × 1.94 | 26 | 12769863525 | **RushioLCO (credit requested; keep it)** |
| `retro_radio_01` | Vintage Radio | decor | 1.55 × 1.28 × 1.04 | 1 | 14003553892 | zzz_1551 |
| `cozy_shoji_divider_01` | Shoji Room Divider | divider | 1.71 × 6.17 × 4.46 | **272** | 10862992379 | Sjenchi |

- **The ceiling is not a separate marketplace model.** `structure_ceiling_01` is a neutral recolour of the kit's floor geometry, from the same source (`Modular Room.Model.Floor`, asset 12219944662, plexaruszx).
- **Modifications by Codex:**
  - removed kit floor sections from the standalone walls, and removed helper parts, imported interactions and the door leaf;
  - aligned the straight walls to local X, with centred bottom pivots;
  - scaled the divider uniformly to 42%.
- **Inspection:** zero seam gap at a 16-stud wall pitch; the doorway is clear 4 studs at its centre. Runtime placement isn't tested.
- **Source asset IDs and creator URLs are provenance only.** They're never loaded, and they never go into `Catalog.luau`.

**Rejected entirely.** These imports were removed for unsafe embedded code. Keep the IDs here so they aren't re-imported:

| Asset ID | Name | Scripts | Reason |
|---|---|---|---|
| 107809369531099 | Rooms Kit Walls Floors Doors Interior | 43 | Unrelated or obfuscated embedded code; the entire imported candidate was removed |
| 72345259689081 | Acoustic Foam Tile Wall Studio Concrete Panel Back | 2 | A hidden, unrelated runtime and UI controller, despite a no-script description; the entire imported candidate was removed |

**Deferred (not prepared):**

| Asset ID | Name | Creator | Reason |
|---|---|---|---|
| 120565443892509 | Modular Wall Pack | WilliamBosso | Needs orientation and fit review before preparation |
| 87617727134882 | Modular Wall Trim Pack (FIXED) | KoBoIce | Needs orientation and fit review before preparation |
| 15777685204 | Old Wood Flooring | FroztedFrozty | A MaterialVariant, not a standalone floor model |

## Reading rules

- **Collections are proposed.** Starter, Cozy, Retro, 1980s, Winter, Futuristic, Executive and Broadcast are suggestions. Everything is free, and no entitlement or purchase logic exists.
- **Unknown sources stay unknown.** Don't invent model IDs. Mesh or content IDs aren't model IDs.
- **Archived originals differ from the fixed live versions** (for example the cups, the lounge blanket and the creator desk microphone). Check the live room before treating a staged template as current.
- **Counts include nested descendants.** Don't add up part or instance counts across records. They aren't triangle, GPU or performance measurements.
- **Appearance doesn't mean function.** Microphones, speakers, laptops and mixers don't implement audio. Decorative chairs aren't podcast seats. The functional seats are `Workspace.PodcastStudio.Seats.Seat1`–`Seat4`.
- The six existing rooms are listed for reference only and must stay untouched by the builder.

## Querying the large JSON

Query it locally instead of opening the whole file. For example:

```sh
# Top-level keys and counts
python3 -c "import json;d=json.load(open('docs/assets/Studio_Asset_Inventory_2026-10-25.json'));print({k:(len(v) if isinstance(v,list) else v) for k,v in d.items()})"

# Names, paths and proposed collections of the guide entries
python3 -c "import json;[print(a.get('name'),'|',a.get('path'),'|',a.get('proposedCollections')) for a in json.load(open('docs/assets/Studio_Asset_Guide_2026-10-25.json'))['assets']]"
```

Field names inside records can change between snapshots. Inspect one record (`d['ModelRecords'][0]`) before you write a query.

## Refreshing the snapshot

1. Codex re-runs the Studio scan on place `132242140555698` and exports the same four files with a new date suffix.
2. Add the new files beside the old ones under `docs/assets/`. Don't overwrite earlier snapshots, so diffs stay possible.
3. Update this README: the snapshot table, the file table (names and counts) and any changed reading rules.
4. Check the counts locally with the commands above against the counts the handoff text claims, before you commit.
5. Commit on a working branch. Never commit place files or binary models, and never merge to `main` as part of a refresh.
