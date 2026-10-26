# Studio asset index

Metadata snapshot of the live Roblox place. **This is an index, not the models.**
No binary models or place files are stored in this repository.

| | |
|---|---|
| Place | Studio Experience, place ID `132242140555698` |
| Snapshot date | 2026-10-25 (inventory generated `2026-10-25T17:42:27Z`) |
| Produced by | Codex (asset discovery / Studio integration), from a local Studio scan |

## Current install status (2026-10-26)

- **Live catalog and templates: 54** (Codex, Edit mode, 2026-10-26): 38 furniture and 16 structure. That's the earlier 52 plus the two batch 03 structure pieces registered in d034a34. Manifest: [`Batch03_Structure_Registration_2026-10-26.json`](Batch03_Structure_Registration_2026-10-26.json).
  - The two pieces:
    - `structure_glass_partition_01` (Grid Glass Partition; Windows; a fixed glass wall with no opening or door behaviour);
    - `structure_ceiling_acoustic_01` (Acoustic Tile Ceiling; Ceilings).
  - Codex reviewed d034a34 and ran its tests independently: 314 passed, 0 failed.
  - Installed the matching `Catalog` and both templates. All 54 live template probes are valid, 0 invalid.
  - Structure filters: Floors 5, Walls 3, Doors 2, Ceilings 3, Windows 3.
  - Real client BuilderRequest Place → Rotate → Delete passed for **each** new piece (all six operations ok), using the partition at (0, 0, 8, yaw 0) and the ceiling at (0, 15, 0, yaw 0). The test copies were removed.
  - Back in Edit, the 54 templates persist. No physical UI-click or R-key check was done.
- **52-item checkpoint** (superseded by the 54 above): 38 furniture and 14 structure. That's the earlier 51 plus `cozy_tufted_leather_sofa_01` (Tufted Leather Sofa, batch 02 H02_11, registered in 06adb12). Manifest: [`Tufted_Leather_Sofa_Registration_2026-10-26.json`](Tufted_Leather_Sofa_Registration_2026-10-26.json).
  - Codex reviewed 06adb12 and ran its tests independently: 313 passed, 0 failed.
  - Installed its `Catalog` and the sofa template into `StudioBuilderTemplates`. All 52 template probes are valid, with none invalid.
  - Real client BuilderRequest Place → Rotate → Delete all succeeded in Play, and the test copy was removed.
  - Back in Edit, Codex verified that the 52 templates and the sofa persist.
  - The sofa is decorative only, with no Seat adapter. No physical UI-click or R-key test was done.
- **51-item checkpoint** (superseded): 37 furniture and 14 structure. That's the earlier 49 plus the two futuristic pieces registered in 48b055c: `future_speaker_01` (Neon Studio Speaker) and `future_layered_coffee_table_01` (Layered Neon Coffee Table). Manifest: [`Futuristic_Furniture_Registration_2026-10-26.json`](Futuristic_Furniture_Registration_2026-10-26.json).
  - Installed from `ServerStorage.StudioBuilderPreparedAssets` into `StudioBuilderTemplates`, with the matching `Catalog`.
  - The TemplateCatalog live probe passed for all 51 entries, and there were 51 client previews in Play.
  - Both new items passed real client BuilderRequest Place → Rotate → Delete in Play (all six operations ok), and the test items were removed.
  - Back in Edit, both templates were verified to persist.
  - No physical UI-click or R-key test was done at this checkpoint.
- **Earlier 49-item checkpoint** (superseded; the earlier 39 plus the classic floor lamp and the 9 structure variants, `Structure_Expansion_2026-10-26.json`):
  - Only `Catalog.luau` from the reviewed 5fcf60b was installed, along with those ten templates.
  - A fresh require and the TemplateCatalog probe passed for all 49.
  - Structure filters: Floors 5, Walls 3, Doors 2, Ceilings 2, Windows 2.
  - **Remote check passed:** all ten new items passed Place → Rotate → Delete through the real BuilderRequest remote in Play, and the test copies were deleted.
- **Rotation installed:** the R-rotation change (14933b6, five modules) is now installed (see TASKS).
- **Not verified yet:** physical mouse/R-key UI, visual checks and doorway avatar clearance. The Play camera viewport was 1 × 1 and automated mouse input stalled. Codex reports the native Studio window renders normally; the capture limitation is specific to automated capture, and no visual check has been done since.
- **Candidates only:** batch 02 (the other 19 of 22; 3 are installed: the speaker, the layered coffee table and the sofa; prepared copies recreated and re-read in Edit; review gallery staged; fit, orientation, visual and placement approval pending), batch 03 (2 installed, listed above; 1 other source, the Modern wood block, still quarantined and not Build-ready; 9 thumbnail-only), the existing-room gap audit (13 room objects, not extracted), and 10 tracked candidates from the refresh.
- **Full-place backup (latest):** saved locally by Codex after the 54-item install (Edit mode, File > Download a Copy). It is not stored in this repository.
  - File: `StudioBuilder-FullBackup-54Items-2026-10-26-0013.rbxl`, 4,137,806 bytes, SHA256 `48D0C5D40EAA99B0801949284198F70D01B19A83CF4BC7FE963B09538AAFBFC6`.
  - Verified: the file exists and has a binary Roblox header. **Restoration not tested.**
  - Contents: the 54-item catalog and templates, including the prepared, template and review copies of the two batch 03 structure pieces. Earlier backups are kept. Being in the backup does not approve any candidate.
- **Previous full-place backup (52 items)** (superseded; local only):
  - File: `StudioBuilder-FullBackup-52Items-2026-10-25-2353.rbxl`, 4,136,547 bytes, SHA256 `50119431B1DEACB33F8514F251D8390B3503CF4FF8DC84B82DBF3BF0EF262148`.
  - Verified: the file exists and has a binary Roblox header. **Restore not tested.**
  - Contents: the 52-item catalog and templates, including the sofa's prepared copy, its template and its axis-review copies. Earlier backups are kept. Being in the backup does not approve any candidate.
- **Older full-place backup (51 items)** (superseded; local only):
  - File: `StudioBuilder-FullBackup-51Items-2026-10-25-2333.rbxl`, 4,133,184 bytes, SHA256 `DB17E6BF29BD16C285A8A1B4C18705EEC928CD4F6964B495B3486C5ECEFA1CCC`.
  - Verified: the file exists and has a binary Roblox header. **Not reopened for restoration testing.**
  - Contents: the 51-item catalog and templates, including the new prepared and template names. Being in the backup does not approve any candidate.
- **Older full-place backup (49 items)** (superseded; local only):
  - File: `StudioBuilder-FullBackup-2026-10-25-2313.rbxl`, 4,132,460 bytes, SHA256 `06018C0FF8ABC8392F3AECA2078F27B9EAF6D95C0F30C1C21E1B8307D343494C`.
  - Verified: the file exists and has a binary Roblox header. **Not reopened for restoration testing.**
  - Contents: the 49-item catalog, the 22 prepared and staged batch 02 candidates, and the 3 quarantined batch 03 sources. Being in the backup does not approve any candidate.

The manifests and refresh files below are historical records and are left unchanged.

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
| [`Tufted_Leather_Sofa_Registration_2026-10-26.json`](Tufted_Leather_Sofa_Registration_2026-10-26.json) | Provenance for batch 02 H02_11 Leather Sofa (free, leutxiz), prepared as `cozy_tufted_leather_sofa_01`. Codex inspected the front and rear in the native viewport. The about −101° mesh yaw was corrected to identity, with the front facing −Z and a bottom-centre pivot. It is one anchored MeshPart, 10.97 × 4.00 × 6.02 studs, with zero scripts, Lights and Seats; decorative only. **Registered (repository 52); not installed** (installed 51), and not in the 51-item backup. The manifest is left as written at registration. **Since installed** (52 live; probe and remote Place/Rotate/Delete passed; in the 52-item RBXL backup): see the status block. | 2 KB |
| [`Futuristic_Furniture_Registration_2026-10-26.json`](Futuristic_Furniture_Registration_2026-10-26.json) | Provenance for 2 batch 02 pieces from the free Futuristic Furniture pack (SebbyTheGODKid), visually reviewed in the native Studio viewport and re-read in Edit by Codex: zero scripts, all parts anchored, bottom-centre pivots, zero Light objects. **Registered in `Catalog.luau` (repository count 51); not yet installed in `StudioBuilderTemplates`** (installed Build count 49). Also records the held Leather Sofa and that the new prepared names are not yet in a refreshed RBXL backup. The manifest is left as written at registration. **Since installed** (51 live, probe and remote Place/Rotate/Delete passed; new names in the 51-item RBXL backup): see the status block. | 3 KB |
| [`Batch03_Structure_Registration_2026-10-26.json`](Batch03_Structure_Registration_2026-10-26.json) | Provenance for 2 batch 03 structure pieces prepared and visually reviewed by Codex. The Glass Partition (4494060927, v7k_1) was resized to a 16 × 15 × 1 `structure_glass_partition_01` window wall: 2 anchored parts, redundant weld removed, a fixed wall with no opening. The Scaleable Ceiling Tiles (551197444, VCVCFans) were resized to a 16 × 1 × 16 `structure_ceiling_acoustic_01` ceiling: 1 anchored Part, with the top texture copied to the bottom. Both have zero scripts and bottom-centre pivots. **Registered (repository 54); not installed** (installed 52), and not in the 52-item backup. The manifest is left as written at registration. **Since installed** (54 live; probes and remote Place/Rotate/Delete passed for each; in the 54-item RBXL backup): see the status block. | 3 KB |
| [`Batch03_Structure_Import_Checkpoint_2026-10-26.json`](Batch03_Structure_Import_Checkpoint_2026-10-26.json) | Batch 03 structure import checkpoint: 3 of the 12 shortlisted sources (Glass Partition, Scaleable Ceiling Tiles, Modern wood block) imported into `ServerStorage.CatalogHuntBatch03` quarantine, zero scripts, zero meshes. **Not prepared, approved, registered or installed in Build.** Gallery capture stalled; no visual approval. | 2 KB |
| [`Catalog_Hunt_Batch03_2026-10-26.json`](Catalog_Hunt_Batch03_2026-10-26.json) | Catalog hunt batch 03: 48 search results, 16 previews reviewed, 12 shortlisted, 4 rejected. **Thumbnail review only: not imported, not script-audited, not tested, not registered.** | 9 KB |
| [`Catalog_Hunt_Batch02_2026-10-26.json`](Catalog_Hunt_Batch02_2026-10-26.json) | Catalog hunt batch 02: 8 inspected free sources and 22 candidate pieces. Prepared copies in `ServerStorage.CatalogHuntPrepared02` were **recreated in Edit and independently re-read**: 22 models, 353 BaseParts, zero scripts, zero unanchored parts. A labelled review gallery is at `Workspace.StudioAssetYard.09 New Asset Review`. The originals, with scripts disabled, are in `ServerStorage.CatalogHuntBatch02`. **Candidates only: not registered, not Build-ready.** (Two have since been registered and installed from new prepared copies: see `Futuristic_Furniture_Registration_2026-10-26.json` and the status block.) Fit, orientation, visual and placement approval are pending, and the full-place disk backup has since been saved (see the status block above). | 16 KB |
| [`Structure_Expansion_2026-10-26.json`](Structure_Expansion_2026-10-26.json) | 9 structure variants prepared and visually reviewed by Codex in Edit (anchored, bottom-centre pivots, zero scripts): 4 floors, 2 walls, a ceiling, a window wall and a wide doorway. They're adapted free assets and material variants of the modular kit (source 12219944662), plus the tracked White Brick Wall (12782716872) resized to the grid, not independent models. Install source: `preparedPath`. **Installed after 5fcf60b** (Codex: Catalog plus templates; probe passed; remote Place/Rotate/Delete passed in Play). **Physical UI and visual checks not yet verified.** The wide doorway's opening is 8 × 9 above a 1-stud threshold; avatar walkthrough not tested. | 5 KB |
| [`Decor_Candidate_retro_classic_floor_lamp_01_2026-10-26.json`](Decor_Candidate_retro_classic_floor_lamp_01_2026-10-26.json) | Provenance for `retro_classic_floor_lamp_01` (Classic Shaded Floor Lamp), recorded from Codex's inspection report. It's one of the tracked candidates (import 4128475322 by bearduckmonkey), normalized and approved: one MeshPart, zero scripts and Light objects (decorative, no illumination), 2 × 6.5 × 2 studs. **Installed after 5fcf60b** (Codex; probe passed; remote Place/Rotate/Delete passed in Play). **Physical UI and visual checks not yet verified.** | 2 KB |
| [`Decor_Candidate_retro_patterned_rug_01_2026-10-26.json`](Decor_Candidate_retro_patterned_rug_01_2026-10-26.json) | Provenance for `retro_patterned_rug_01` (Patterned Vintage Rug), recorded from Codex's inspection report. It's one of the 13 tracked candidates (import 11829259774 by caductis), normalized and approved: one MeshPart, zero scripts, scale 0.65, 9.04 × 0.30 × 10.03 studs. **Registered, installed and Play-checked (after a9bf5ba).** It also records that the two pillow derivatives are not approved. | 2 KB |
| [`Structure_and_Decor_Candidates_2026-10-25.json`](Structure_and_Decor_Candidates_2026-10-25.json) | 10 **candidates**, prepared and visually inspected in Edit mode in `ServerStorage.StudioStructureCandidates`, with labelled manual-use copies in `StudioAssetYard/08 Structure and Decor Review/Prepared Pieces`. **Not registered in `Catalog.luau` and not in the Build UI.** Also: inspection notes, 2 rejected imports and 3 deferred ones (below). | 12 KB |
| [`Studio_Components_2026-10-25.json`](Studio_Components_2026-10-25.json) | Functional components, including inactive storage duplicates: `Fixtures` (161 lights), `Seats` (95 Seat/VehicleSeat), `Effects` (55 emitters), `Sounds` (2), `Displays` (83 text displays), `RoomConfig` (26). | 90 KB |

## Catalog hunt batch 03 (2026-10-26): 2 of 12 installed, 1 quarantined, 9 thumbnail-only

Inventory: [`Catalog_Hunt_Batch03_2026-10-26.json`](Catalog_Hunt_Batch03_2026-10-26.json), archived exactly as provided. It is the historical thumbnail-review record and is left unchanged; the import checkpoint below supersedes its "not imported" status for three sources only.

**Structure import checkpoint (Codex, 2026-10-26):** [`Batch03_Structure_Import_Checkpoint_2026-10-26.json`](Batch03_Structure_Import_Checkpoint_2026-10-26.json), archived exactly as provided.
- **Imported:** 3 of the 12 shortlisted sources, into `ServerStorage.CatalogHuntBatch03` quarantine. Zero LuaSourceContainers and zero meshes in all three.
- **Not imported:** the other 9 are still thumbnail-only.
- **None of the three is Build-ready:** not prepared, approved, registered or installed. Build templates stay **49**.
- **Findings per source:**
  - **Glass Partition** (4494060927): a Model with a Part, a Weld and a Union, about 11.92 × 9.43 × 0.24 studs. It needs resizing to the 16-stud structure grid.
  - **Scaleable Ceiling Tiles** (551197444): one Granite Part, 9 × 0.2 × 9 studs, with its tile Texture on the **Top** face only. It needs an underside treatment, as well as fitting to the 16-stud grid.
  - **Modern wood block** (112665732912463): one Plastic Part, about 4.43 × 4.22 × 4 studs, covered in Decals. It is a roughly four-stud decal-covered cube, **not a modular slatted wall**, so the thumbnail's "feature wall" reading does not hold. It also has **two overlapping Top decals** (two different images on the same face).
- **Visual review:** gallery capture stalled and was cancelled, so no visual approval is claimed.
- **Next step:** grid adaptation and visual review, before any Build registration.

**Registration update (2026-10-26):** two of the three quarantined sources were adapted and approved for their visual and static preparation, and are registered in the repository (see [`Batch03_Structure_Registration_2026-10-26.json`](Batch03_Structure_Registration_2026-10-26.json)):
- **Glass Partition → `structure_glass_partition_01` (Grid Glass Partition, `window_wall`):**
  - the redundant Weld was removed, and the original yaw normalized;
  - it was resized per axis to 16 × 15 × 1, with its length along local X and an upright identity bottom-centre pivot;
  - it has 2 anchored BaseParts (Part glazing and a UnionOperation black grid frame), with zero scripts and zero Textures;
  - it is a fixed glass wall, with no opening or door behaviour.
- **Scaleable Ceiling Tiles → `structure_ceiling_acoustic_01` (Acoustic Tile Ceiling, `ceiling`):**
  - it was resized to 16 × 1 × 16, keeping the source texture at 4 × 4 studs;
  - the Top texture was copied to the Bottom face, which fixes the underside finding above;
  - it is 1 anchored Part with 2 Textures and zero scripts;
  - the underside was reviewed on a flipped gallery copy; the prepared copy stays upright.
- **Installed (superseding checkpoint):** both are now in `StudioBuilderTemplates`. They passed the live probes and real BuilderRequest Place → Rotate → Delete in Play (partition at (0, 0, 8, 0), ceiling at (0, 15, 0, 0)), and they persist in Edit. They're in the 54-item backup. No physical UI-click or R-key check was done.
- **Modern wood block:** still quarantined and not Build-ready. The other 9 sources are still thumbnail-only.
- The import checkpoint and the inventory JSON above are left as written.

**Thumbnail review (historical, from the inventory):**
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

## Catalog hunt batch 02 (2026-10-26): 3 of 22 installed; 19 candidates only

Inventory: [`Catalog_Hunt_Batch02_2026-10-26.json`](Catalog_Hunt_Batch02_2026-10-26.json), archived exactly as provided and left unchanged.

**Registration update (2026-10-26):** two pieces from the Futuristic Furniture pack passed Codex's visual and static checks and are registered in the repository (see [`Futuristic_Furniture_Registration_2026-10-26.json`](Futuristic_Furniture_Registration_2026-10-26.json)):
- `future_speaker_01` (Neon Studio Speaker) = H02_13 Future Speaker (**confirmed by Codex**).
- `future_layered_coffee_table_01` (Layered Neon Coffee Table) = H02_20 Future Coffee Table (**confirmed by Codex**).
- **Installed (superseding checkpoint):** both are now in `StudioBuilderTemplates`. They passed the live probe and real BuilderRequest Place → Rotate → Delete in Play, and they persist in Edit. Physical UI-click and R-key tests weren't done.
- **Leather Sofa (H02_11), later checkpoint:** after being held from a rear three-quarter inspection, the sofa was inspected from the front and rear in the native viewport. Its mesh yaw (about −101°) was corrected to identity, with the front facing −Z.
  - It is registered in the repository as `cozy_tufted_leather_sofa_01` (Tufted Leather Sofa) from `ServerStorage.StudioBuilderPreparedAssets.cozy_tufted_leather_sofa_01`, per [`Tufted_Leather_Sofa_Registration_2026-10-26.json`](Tufted_Leather_Sofa_Registration_2026-10-26.json).
  - **Installed (superseding checkpoint):** it is now in `StudioBuilderTemplates`. It passed the probe and real BuilderRequest Place → Rotate → Delete in Play, and it persists in Edit. No physical UI-click or R-key test was done.
  - It is decorative only, with zero Seats, so there is no sitting or clearance claim.
- **The other 19 remain pending.**
- The original H02 copies are in the earlier RBXL backup, and the new prepared and template names are in the 51-item backup (`StudioBuilder-FullBackup-51Items-2026-10-25-2333.rbxl`). The sofa's prepared copy is not in that backup, but it is in the 52-item backup (`StudioBuilder-FullBackup-52Items-2026-10-25-2353.rbxl`).

The notes below describe the batch as first inventoried.

- **What it is:** 22 candidate pieces from 8 inspected free Creator Store sources. The Modular Wall Pack and the Modular Wall Trim Pack were listed earlier as deferred; they're now inspected.
- **Where the copies are:**
  - Prepared copies: `ServerStorage.CatalogHuntPrepared02.H02_xx`, reported anchored and script-free.
    **Persistence UNVERIFIED (correction, 2026-10-26):** an Edit-mode execute returned the 22 prepared models, but the current Play server has **no** `CatalogHuntPrepared02` folder. Whether the prepared copies persist can only be confirmed after returning to Edit.
    Codex saved a recreation script locally at `work/prepare-hunt-batch02.luau`; that's on Codex's machine, not in this repository.
  - Imported originals: `ServerStorage.CatalogHuntBatch02`, with their scripts disabled. It's present on the current Play server. All 8 originals are preserved.
- **Scripts:** the Futuristic Furniture pack contained welding, vehicle-movement, text-banner and unpacker scripts. None of them ran, and none is in the prepared copies.
- **Current status (Codex, 2026-10-26, Edit mode):** this resolves the missing prepared-copy issue noted above, for the current Edit DataModel.
  - Codex confirmed `CatalogHuntPrepared02` was absent, recreated all 22 sanitized candidates from the 8 originals, and independently re-read the folder: **22 models, 353 BaseParts, zero LuaSourceContainers, zero unanchored parts**.
  - **Review gallery:** 22 labelled display copies are at `Workspace.StudioAssetYard.09 New Asset Review`, organized by type on a 6-column grid (about x 3500–3720, z 3370–3502).
    - Each is marked **CANDIDATE / NOT IN BUILD** and keeps its source, type and collection metadata.
    - A `CandidateIndexJSON` is stored in that folder.
    - The display copies have zero scripts too. Like the rest of the yard, they're removed at play start.
  - Build templates are still **49**.
  - **The full-place disk backup was pending at this checkpoint.** It has since been saved and includes these 22 copies (see the status block above).
  - The historical notes above (the earlier unverified persistence and the missing gallery) are kept as the record.
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
**Registered, decor (installed at 46d55cb; Play Place/Rotate/Delete passed):** `retro_record_player_01` (with the creator's requested credit "RushioLCO (credit requested)" kept verbatim in the catalog's `credit` field) and `retro_radio_01` (creator zzz_1551). Both are decorative, with no audio.
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
