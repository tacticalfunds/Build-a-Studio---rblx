# Studio asset index

Metadata snapshot of the live Roblox place. **This is an index, not the models.**
No binary models or place files are stored in this repository.

| | |
|---|---|
| Place | Studio Experience, place ID `132242140555698` |
| Snapshot date | 2026-10-25 (inventory generated `2026-10-25T17:42:27Z`) |
| Produced by | Codex (asset discovery / Studio integration), from a local Studio scan |

## Current install status (2026-10-26)

- **Live catalog and templates: 72** (Codex, Studio Experience place `132242140555698`, Edit mode, 2026-10-26): 72 catalog entries and 72 templates, 52 furniture and 20 structure, with 4 Windows pieces. That's the earlier 71 plus `future_console_desk_01` (Console Desk, tables; futuristic; batch 02 H02_19 desk only, registered in ea6c501). Manifest: [`Console_Desk_Registration_2026-10-26.json`](Console_Desk_Registration_2026-10-26.json). **The repository and the live install both hold 72.**
  - Codex reviewed all 8 changed files of ea6c501 and ran the archived revision independently: 421 passed, 0 failed.
  - **Installed:** ONLY the reviewed Catalog and the `future_console_desk_01` template. Studio had reconnected with a new connector ID; a read-only check confirmed the same place ID. Before the write, the live Catalog matched 20f13ea with 71 templates, and the five-part prepared desk's safety and bounds were rechecked. Rollback copy: `ServerStorage.BuilderIntegrationBackups.Desk72_Beforeea6c501_20261026_1441.Catalog`.
  - **Audit (fresh):** 72 catalog entries, 72 valid templates, 52 furniture and 20 structure, 4 Windows pieces; `Config.Doors.Enabled` is false.
  - **Static Edit checks:** the real PlacementCore and PlacedItemsWorld, isolated, with an injected authority and clock:
    - Place, Rotate and Delete pass at yaw 0, 90, 180 and 270;
    - outer-edge placement is rejected with OutOfBounds;
    - logs empty; fixtures cleaned up.
  - **Not checked:** Play, the UI, remote requests, avatars, physics, tabletop interaction and save/load.
  - **⚠ No 72-item full-place backup yet (pending).** Codex could not create it: the native Windows capture showed the wallpaper instead of Studio, and binding and activating a fresh window failed ("failed to activate captured window"), so the UI automation was stopped. The latest verified full backup is still the **71-item** file below, which **predates the desk's extraction and install**. The rollback Catalog copy, Codex's local reconstruction scripts and the repository Catalog are kept, but they are **not equivalent to a full-place backup**. A 72-item backup is pending until the Studio window is available.
- **Previous 71-item checkpoint** (superseded by the 72 above).
- **Repository 72, live 71** (superseded by the 72-item install above): `future_console_desk_01` (Console Desk, tables; futuristic) is registered in the repository but **not installed**: prepared by Codex from batch 02 H02_19 (the free "Futuristic Furniture" pack by SebbyTheGODKid, asset 1375085945). Only the five-part desk of the 20-part composite is used; the nine-part computer and the six-part chair (with its Seat) are deliberately excluded. Static Edit inspection only (safety counts, bounds, four cardinal world-corner AABBs, front and rear native visual checks). No placement runtime, Play, UI, remote, avatar, physics, tabletop interaction or save/load test. Manifest: [`Console_Desk_Registration_2026-10-26.json`](Console_Desk_Registration_2026-10-26.json). Repository counts: 52 furniture, 20 structure (live: 51 furniture, 20 structure, 4 Windows, doors disabled). The prepared desk isn't in a backup yet; the original H02_19 is in the 71-item backup.
- **Live catalog and templates: 71** (Codex, Studio Experience place `132242140555698`, Edit mode, 2026-10-26): 71 catalog entries and 71 templates, 51 furniture and 20 structure, with 4 Windows pieces. That's the earlier 70 plus `future_capsule_tv_stand_01` (Capsule TV Stand, storage; futuristic; batch 02 H02_16, registered in 20f13ea). Manifest: [`Capsule_TV_Stand_Registration_2026-10-26.json`](Capsule_TV_Stand_Registration_2026-10-26.json). **The repository and the live install both hold 71.**
  - Codex reviewed all 8 changed files of 20f13ea and ran the archived revision independently: 420 passed, 0 failed.
  - **Installed:** ONLY the Catalog and the inspected `future_capsule_tv_stand_01` template. Before the write, the live Catalog matched fab302c; the rollback copy is `ServerStorage.BuilderIntegrationBackups.Capsule71_Before20f13ea_20261026_1304.Catalog`.
  - **Audit (fresh):** 71 catalog entries, 71 valid templates, 51 furniture and 20 structure, 4 Windows pieces; `Config.Doors.Enabled` is false.
  - **Static Edit checks:** the real PlacementCore and PlacedItemsWorld, isolated, with an injected authority and clock:
    - Place, Rotate and Delete pass at yaw 0, 90, 180 and 270;
    - outer-edge placement is rejected with OutOfBounds;
    - no logs; temporary fixtures cleaned up.
  - **Not checked:** Play, the UI, remote requests, avatars, physics and save/load. The stand stays static decorative storage with no TV.
- **Previous 70-item checkpoint** (superseded by the 71 above).
- **Repository 71, live 70** (superseded by the 71-item install above): `future_capsule_tv_stand_01` (Capsule TV Stand, storage; futuristic) is registered in the repository but **not installed**: prepared by Codex from batch 02 H02_16, the TV stand in the free "Futuristic Furniture" pack by SebbyTheGODKid (asset 1375085945), with static Edit inspection only (safety counts, bounds, four cardinal AABBs, front and rear native visual checks). No Build UI, placement runtime, Play, avatar, remote or save/load test. It is static decorative storage with no TV included. Manifest: [`Capsule_TV_Stand_Registration_2026-10-26.json`](Capsule_TV_Stand_Registration_2026-10-26.json). Repository counts: 51 furniture, 20 structure (live: 50 furniture, 20 structure, 4 Windows, doors disabled). It isn't in the 70-item backup.
- **Live catalog and templates: 70** (Codex, Studio Experience place `132242140555698`, Edit mode, 2026-10-26): 70 catalog entries and 70 templates, 50 furniture and 20 structure, with 4 Windows pieces. That's the earlier 69 plus `record_console_01` (Retro Record Console, audio; retro, 1980s, cozy; batch 02 H02_12, registered in fab302c). Manifest: [`Record_Console_Registration_2026-10-26.json`](Record_Console_Registration_2026-10-26.json). **The repository and the live install both hold 70.**
  - Codex reviewed all 7 changed files of fab302c and ran the suite independently from a pristine archive (Lua 5.4 via Lupa): 419 passed, 0 failed.
  - **Installed:** ONLY the reviewed Catalog and the `record_console_01` template. Before the write, the live Catalog matched c6bbd41 exactly; the rollback copy is `ServerStorage.BuilderIntegrationBackups.RecordConsole70_Beforefab302c_20261026_1244.Catalog`.
  - **Audit (fresh, isolated):** 70 catalog entries, 70 of 70 templates valid, 50 furniture and 20 structure, 4 Windows pieces; `Config.Doors.Enabled` is still false.
  - **Static Edit checks:** the real PlacementCore and PlacedItemsWorld, in an isolated Edit probe with an injected authority and clock:
    - Place, Rotate and Delete pass at yaw 0, 90, 180 and 270;
    - outer-edge placement is rejected with OutOfBounds;
    - logs were empty and the temporary models were cleaned up.
  - **Not checked:** Play, the UI, remote requests, avatars, physics and save/load. The console stays static decoration (no playback or drawer behaviour).
- **Previous 69-item checkpoint** (superseded by the 70 above).
- **Repository 70, live 69** (superseded by the 70-item install above): `record_console_01` (Retro Record Console, audio; retro, 1980s, cozy) is registered in the repository but **not installed**: prepared by Codex from batch 02 H02_12, the free "Record Player & Shelf" by Savageboy (asset 126677556), with static Edit inspection only (part and safety counts, the four cardinal bounds, floor contact, a native visual review). No Build UI, placement runtime, Play, avatar or save/load test. It is static decoration: no playback, spinning or drawer behaviour. Manifest: [`Record_Console_Registration_2026-10-26.json`](Record_Console_Registration_2026-10-26.json). Repository counts: 50 furniture, 20 structure. It isn't in the 69-item backup.
- **Live catalog and templates: 69** (Codex, Studio Experience place `132242140555698`, Edit mode, 2026-10-26): 69 catalog entries and 69 templates, 49 furniture and 20 structure, with 4 Windows pieces. That's the earlier 68 plus `structure_window_arch_01` (Arched Window Wall, window_wall; cozy, retro, winter; batch 02 H02_09, registered in c6bbd41). Manifest: [`Arched_Window_Wall_Registration_2026-10-26.json`](Arched_Window_Wall_Registration_2026-10-26.json). **The repository and the live install both hold 69.**
  - Codex ran the suite on a clean Windows archive independently: 418 passed, 0 failed.
  - **Installed:** ONLY the reviewed `Catalog.luau` and the prepared `structure_window_arch_01` template. Before the write, the live Catalog matched its parent exactly; it was backed up as `ServerStorage.BuilderIntegrationBackups.ArchedWindow69_Beforec6bbd41_20261026_1204`. The original source, the prepared copies and the review model are retained.
  - **Audit:** a fresh isolated Luau audit found 69 of 69 templates installed and valid; catalog 69 (49 furniture, 20 structure), 4 Windows pieces; the arched window measures 16 × 15 × 1; `Config.Doors.Enabled` is still false.
  - **Static Edit checks:** the real PlacementCore and PlacedItemsWorld, in an isolated Edit probe with an injected authority and clock:
    - Place, Rotate and Delete pass at four yaws;
    - outer-edge Place is refused with OutOfBounds;
    - no logs and no temporary models were left behind.
  - **Not checked:** Play, the UI, remote requests, avatars, physics and save/load.
  - Codex's local evidence file `outputs/Catalog 69 Installation Checkpoint.json` is not in this repository.
- **Previous 68-item checkpoint** (superseded by the 69 above). **Live catalog and templates: 68** (Codex, Studio Experience place `132242140555698`, Edit mode, 2026-10-26): 68 catalog entries and 68 templates, 49 furniture and 19 structure. That's the earlier 67 plus `structure_doorway_panel_01` (Wood Panel Door Wall, doorway; cozy, retro, 1980s, winter), registered in 0aa23de. Manifest: [`Panel_Door_Wall_Module_Preparation_2026-10-26.json`](Panel_Door_Wall_Module_Preparation_2026-10-26.json). **The repository and the live install both hold 68.**
  - Codex accepted 72d56f3 after running the 417-test suite independently (417 passed) and re-running its original injected stop-failure probe (passing).
  - **Installed:** the reviewed door and catalog delta (16 modules) and the `structure_doorway_panel_01` template. The live Config lacked the unrelated BuildSeats constants; that was preserved as it was, and only the `Doors` settings were added. **`Config.Doors.Enabled` remains false.**
  - **Backups first:** the previous three builder roots are in `ServerStorage.BuilderIntegrationBackups.Door68_Before72d56f3_20261026_1124`. The original room door, the prepared copy and the yard copies are preserved.
  - **Probe:** a fresh Studio catalog/probe validation passes for all 68 templates. The door template has 39 anchored parts, no scripts, joints or constraints, Frame and Leaf children, and a measured size of 16 × 15 × 1.
  - **Static Edit checks:** in isolated Edit test trees, the real PlacementCore and PlacedItemsWorld were run with an injected authority and clock:
    - Place, Rotate and Delete pass at yaw 0, 90, 180 and 270;
    - outer-edge placement is rejected with OutOfBounds;
    - no temporary models were left behind, and the live placed count is 0.
  - **Not checked:** Play, remote requests, the UI, physics, avatars and automatic-door behaviour. The door runtime is not enabled, so placed doors stay static and closed.
- **Repository 69, live 68** (superseded by the 69-item install above): `structure_window_arch_01` (Arched Window Wall, window_wall; cozy, retro, winter) is registered in the repository but **not installed**: prepared by Codex from batch 02 H02_09, the free "Arch Window" by ClearlyRach (asset 492934961), with static Edit asset checks only (visual review, bounds at four yaws, aperture rays). No Build UI, placement runtime, Play, avatar or save/load test. Manifest: [`Arched_Window_Wall_Registration_2026-10-26.json`](Arched_Window_Wall_Registration_2026-10-26.json). Repository counts: 49 furniture, 20 structure. It isn't in the 68-item backup.
- **Previous 67-item checkpoint** (superseded by the 68 above). **Live catalog and templates: 67** (Codex, Studio Experience `132242140555698`, 2026-10-26): 67 catalog entries and 67 templates, 49 furniture and 18 structure. That's the earlier 66 plus `studio_broadcast_indicator_01` (Broadcast Indicator Lamp, lighting, the round Broadcast Set "On Air" indicator, registered in 19c2a2e). Manifest: [`Broadcast_Indicator_Registration_2026-10-26.json`](Broadcast_Indicator_Registration_2026-10-26.json).
  - Codex ran the 327 tests independently: zero failures. The reviewed Catalog and the indicator template are installed, and the Catalog was backed up first as `ServerStorage.BuilderIntegrationBackups.Catalog_Before67_20261026_0435`.
  - Fresh probes before and after Play: 67 entries, 67 templates, 67 valid, zero invalid or missing.
  - Real BuilderRequest checks all succeeded:
    1. Status, revision 0;
    2. floor Place `i1`, revision 1;
    3. Rotate `i1`, revision 2;
    4. Delete `i1`, revision 3;
    5. raised Place `i2` at y = 3.3, revision 4;
    6. Delete `i2`, revision 5.
  - **Server measurements:** 3 parts, one disabled PointLight, zero Studio/Podcast descendant attributes, size 1.7549996376037598 × 1.7549996376037598 × 1.3650007247924805. The floor minimum Y was 0 and the raised minimum Y was 3.299999952316284. **The light stayed disabled after rotation and after raised placement.**
  - Back in Edit, no test items remain. Codex's local evidence file `Catalog 67 Installation Checkpoint.json` is not in this repository.
  - **Scope:** these are remote/server checks, not physical mouse or R-key UI tests. It is decorative only: no recording-status reaction, wall snapping or lighting adapter.
- **Repository 68, live 67** (superseded by the 68-item install above): `structure_doorway_panel_01` was registered **prepared-only** with validated door metadata and the swept-swing placement check, before it was installed. Manifest: [`Panel_Door_Wall_Module_Preparation_2026-10-26.json`](Panel_Door_Wall_Module_Preparation_2026-10-26.json). Repository counts: 49 furniture, 19 structure. The wider queue isn't finished (see the task 11, batch 02 and candidate lines below).
- **Panel door prepared backup (local; superseded by the 68-item backup):** `StudioBuilder-FullBackup-PanelDoorPrepared-2026-10-26.rbxl`, 4,160,221 bytes, SHA256 `23B17B0618ABE86498115C93C86C3CB0594F1179D6CD315CEB03E6E687877C98`. Restore not tested; not uploaded.
- **66-item checkpoint** (superseded by the 67 above): 66 catalog entries and 66 templates, 48 furniture and 18 structure. That's the earlier 65 plus `studio_umbrella_light_01` (Studio Umbrella Light, lighting, the complete Broadcast Set umbrella fixture, registered in 499ce49). Manifest: [`Studio_Umbrella_Light_Registration_2026-10-26.json`](Studio_Umbrella_Light_Registration_2026-10-26.json).
  - Codex ran the suite independently: 326 passed, 0 failed. The reviewed Catalog and the umbrella template are installed, and the Catalog was backed up first as `ServerStorage.BuilderIntegrationBackups.Catalog_Before66_20261026_0415`.
  - Fresh probes before and after Play: 66 catalog entries, 66 templates, 66 valid, 0 invalid or not installed.
  - Real BuilderRequest calls all succeeded: Status (revision 0), Place `i1` (revision 1), Rotate `i1` (revision 2), Delete `i1` (revision 3).
  - **Server measurements:** 44 parts, one disabled PointLight, zero Studio/Podcast descendant attributes, minimum Y 0, size 2.1505026817321779 × 6.569082260131836 × 2.8773441314697267. **The light stayed disabled after rotation.**
  - Back in Edit, zero test items remain. Codex's local evidence file `Catalog 66 Installation Checkpoint.json` is not in this repository.
  - **Scope:** these are remote/server checks, not physical mouse or R-key UI tests. The umbrella is decorative only; a lighting adapter is still pending.
- **65-item checkpoint** (superseded): 65 catalog entries and 65 templates, 47 furniture and 18 structure. That's the earlier 64 plus `studio_softbox_01` (Studio Softbox, lighting, from the project-modified Broadcast Set, registered in a64eb15). Manifest: [`Studio_Softbox_Registration_2026-10-26.json`](Studio_Softbox_Registration_2026-10-26.json).
  - Codex reviewed a64eb15 and ran all tests independently: 325 passed, 0 failed.
  - Installed in Edit, with the Catalog guarded against the previous 64-item source and backed up as `ServerStorage.BuilderIntegrationBackups.Catalog_Before65_20261026_0355`.
  - Fresh probes before and after Play: 65 catalog entries, 65 templates, 65 valid, 0 invalid, 0 not installed.
  - Real BuilderRequest Play checks all succeeded: Status (revision 0), Place `i1` (revision 1), Rotate `i1` (revision 2), Delete `i1` (revision 3).
  - **Server measurements:** 25 parts, 1 disabled light, 0 Studio/Podcast descendant attributes, minimum Y 0, size 2.6021881103515627 × 7.910927295684815 × 3.657658576965332. **The light was still disabled after rotation.**
  - Back in Edit, persistence was verified and zero test items remain.
  - **Scope:** these are remote/server checks, not physical mouse or R-key UI tests. The softbox is decorative only; a builder lighting adapter is still pending.
- **64-item checkpoint** (superseded): 64 catalog entries and 64 templates, 46 furniture and 18 structure. That's the earlier 63 plus `studio_presentation_board_01` (Studio Presentation Board, screens, the current project-branded Conference Room board, registered in 9a139cc). Manifest: [`Presentation_Board_Registration_2026-10-26.json`](Presentation_Board_Registration_2026-10-26.json).
  - Codex reviewed 9a139cc and ran the archived suite independently: 324 passed, 0 failed.
  - The Catalog source was guarded against the previously reviewed 63-item version before replacement, and backed up as `ServerStorage.BuilderIntegrationBackups.Catalog_Before64_20261026_0334`.
  - A fresh probe found 64 entries and 64 templates: 64 valid, 0 invalid, 0 not installed.
  - Real BuilderRequest checks passed:
    1. floor Place, revision 1;
    2. Rotate, revision 2;
    3. Delete, revision 3;
    4. elevated Place at y = 3.3, revision 4, with a server-measured board minimum Y of 3.299999237. The one SurfaceGui was kept, the visible face is −Z, and there are zero StudioTextRole attributes;
    5. only the test board deleted, revision 5.
  - Back in Edit, Codex verified 64 catalog entries, 64 templates, the board persisting, and no test items left.
  - **Scope:** these are remote/server checks, not physical mouse or R-key UI tests. The static decorative limits remain: no wall snapping, drawing, video or per-item branding.
- **63-item checkpoint** (superseded): 63 catalog entries and 63 templates, 45 furniture and 18 structure. That's the earlier 62 plus `studio_coffee_mug_01` (Steaming Coffee Mug, decor, the current project-modified Conference Room mug, registered in 552a454). Manifest: [`Coffee_Mug_Registration_2026-10-26.json`](Coffee_Mug_Registration_2026-10-26.json).
  - Codex reviewed 552a454 and ran the 323 tests independently: 0 failures.
  - A fresh Edit probe after Play found 63 valid, 0 invalid, 0 not installed. The Catalog module was backed up first as `ServerStorage.BuilderIntegrationBackups.Catalog_Before63_20261026_0314`.
  - Real BuilderRequest checks passed:
    1. floor Place, revision 1;
    2. Rotate, revision 2;
    3. Delete, revision 3;
    4. conference table Place, revision 4;
    5. tabletop mug Place, revision 5, with the mug's minimum Y at 3.299999833 against the table's maximum Y of 3.299999952;
    6. and 7. only the test mug and table deleted.
  - **Steam:** the emitter was retained, enabled, rate 4, pointing world-up, and faint rising steam was visible in native Play screenshots. The temporary camera override was removed.
  - Back in Edit, persistence was verified, and no test items remain.
  - **Not done:** no physical mouse or R-key UI verification. There's no pickup or drinking behaviour.
- **62-item checkpoint** (superseded): 62 catalog entries and 62 templates, 44 furniture and 18 structure. That's the earlier 61 plus `studio_office_chair_01` (Black Office Chair, seating, one chair extracted from the Conference Room, registered in 7bbd018). Manifest: [`Office_Chair_Registration_2026-10-26.json`](Office_Chair_Registration_2026-10-26.json).
  - Codex reviewed 7bbd018 (the existing seating type confirmed as correct) and ran the archived commit independently: 322 passed, 0 failed.
  - A fresh probe found 62 valid, 0 invalid, 0 not installed. The live chair template is installed.
  - The prior Catalog source was verified against the last-reviewed version and backed up as `ServerStorage.BuilderIntegrationBackups.Catalog_Before62_20261026_0254`.
  - Real BuilderRequest calls in Play all succeeded:
    1. Status, revision 0;
    2. Place `studio_office_chair_01` at (0, 0, 0, yaw 0) → `i1`, revision 1, with a server-measured pivot of (2000, 0, 0) and a bounding minimum Y of 0;
    3. Rotate direction 1, revision 2;
    4. Delete, revision 3.
  - Back in Edit, the 62-entry catalog and the template persisted, and the test layout was absent.
  - **Scope:** these are server request checks, not physical mouse, R-key or visual UI checks. The chair is decorative only (no sitting, rolling or swivel), and the original room is untouched.
- **61-item checkpoint** (superseded): 61 catalog entries and 61 templates, 43 furniture and 18 structure. That's the earlier 60 plus `studio_flower_pot_01` (Red Flower Pot, an existing-room extraction from the Conference Room, registered in e0c91b7). Manifest: [`Flower_Pot_Registration_2026-10-26.json`](Flower_Pot_Registration_2026-10-26.json).
  - Codex reviewed e0c91b7 and ran its archive independently: 321 passed, 0 failed.
  - It's installed in the live Catalog and `StudioBuilderTemplates`. A fresh probe found 61 entries and 61 templates: 61 valid, 0 invalid.
  - Real Play client BuilderRequest checks all succeeded:
    1. flower pot floor Place at (0, 0, 0, yaw 0), revision 1;
    2. Rotate direction 1, revision 2;
    3. Delete, revision 3;
    4. conference table Place, revision 4;
    5. flower pot elevated Place at (0, 3.3, 0, yaw 0), revision 5;
    6. Delete the flower pot, revision 6;
    7. Delete the table, revision 7.
  - All test copies were removed. Back in Edit, persistence was verified.
  - **Scope:** these are server request tests. They are not physical UI or R-key tests, and not a visual check that the pot sits correctly on the tabletop. The original room is unchanged.
- **60-item checkpoint** (superseded): 60 catalog entries and 60 templates, 42 furniture and 18 structure. That's the earlier 59 plus `studio_conference_table_01` (White Conference Table, an existing-room extraction from the Conference Room, registered in dbb5ef2). Manifest: [`Conference_Table_Registration_2026-10-26.json`](Conference_Table_Registration_2026-10-26.json).
  - Codex reviewed dbb5ef2 and ran its archive independently: 320 passed, 0 failed.
  - It's installed in the live Catalog and `StudioBuilderTemplates`. A fresh probe found 60 entries and 60 templates: 60 valid, 0 invalid.
  - Real Play client BuilderRequest calls succeeded: Place at local (0, 0, 0, yaw 0), Rotate direction 1, then Delete (revisions 1, 2 and 3). The test copy was removed.
  - Back in Edit, persistence was verified. No physical UI-click or R-key test was done.
  - The original room is untouched. The table is decorative, with no seats included.
- **59-item checkpoint** (superseded): 59 catalog entries and 59 templates, 41 furniture and 18 structure. That's the earlier 58 plus `studio_tall_floor_plant_01` (Tall Floor Plant, an existing-room extraction from the Conference Room, registered in 30e58c1). Manifest: [`Tall_Floor_Plant_Registration_2026-10-26.json`](Tall_Floor_Plant_Registration_2026-10-26.json).
  - Codex reran the archive independently: 319 tests passed, 0 failed.
  - It's installed in `StudioBuilderTemplates` and the live Catalog. A fresh Catalog/TemplateCatalog probe found 59 entries and 59 templates: 59 valid, 0 invalid.
  - Real Play client BuilderRequest Place, Rotate and Delete all succeeded. The test copy was removed, and Studio returned to Edit.
  - No physical UI-click or R-key test was done. The original room is unchanged.
- **58-item checkpoint** (superseded): 58 catalog entries and 58 templates, 40 furniture and 18 structure. That's the earlier 57 plus `studio_water_dispenser_01` (Water Dispenser, an existing-room extraction from the Conference Room, registered in cfe56ad). Manifest: [`Water_Dispenser_Registration_2026-10-26.json`](Water_Dispenser_Registration_2026-10-26.json).
  - Codex reviewed cfe56ad and ran the suite independently: 318 tests, all passing.
  - All 58 probes are valid, 0 invalid.
  - Real client BuilderRequest calls were all ok: Place at (0, 0, 0, yaw 0), Rotate direction 1, then Delete (revisions 1, 2 and 3). The test copy was removed.
  - Edit persistence was verified. No physical UI-click or R-key test was done. It is decorative only.
- **57-item checkpoint** (superseded): 57 catalog entries and 57 templates, 39 furniture and 18 structure. That's the earlier 56 plus `future_drawer_cabinet_01` (Three-Drawer Cabinet, batch 02 H02_18, registered in ae798e4). Manifest: [`Drawer_Cabinet_Registration_2026-10-26.json`](Drawer_Cabinet_Registration_2026-10-26.json).
  - Codex reviewed ae798e4 and ran the full suite independently: 317 passed, 0 failed.
  - All 57 probes are valid, 0 invalid.
  - Real client BuilderRequest calls were all ok: Place at (0, 0, 0, yaw 0), Rotate direction 1, then Delete (revisions 1, 2 and 3). The test copy was removed.
  - Edit persistence was verified. No physical UI-click or R-key test was done. The cabinet is decorative only.
- **56-item checkpoint** (superseded): 56 catalog entries and 56 templates, 38 furniture and 18 structure. That's the earlier 55 plus `structure_acoustic_wall_01` (Acoustic Foam Wall, batch 02 H02_10, registered in 71c9a2d). Manifest: [`Acoustic_Wall_Registration_2026-10-26.json`](Acoustic_Wall_Registration_2026-10-26.json).
  - Codex reviewed 71c9a2d and ran its suite independently: 316 passed, 0 failed.
  - All 56 template probes are valid, 0 invalid. Filters: Floors 5, Walls 5, Doors 2, Ceilings 3, Windows 3.
  - The wall is installed: 57 anchored parts, 0 scripts and 0 lights. It looks like acoustic foam only, with no sound behaviour.
  - Real client BuilderRequest calls all passed: Place at local (0, 0, −8, yaw 180), Rotate direction 1, then Delete (revisions 1, 2 and 3). The test copy was removed.
  - Back in Edit, catalog and template persistence was verified. No physical UI-click or R-key test was done.
- **55-item checkpoint** (superseded): 55 catalog entries and 55 templates, 38 furniture and 17 structure. That's the earlier 54 plus `structure_industrial_wall_01` (Industrial Concrete Wall, batch 02 H02_03, registered in 249db85). Manifest: [`Industrial_Wall_Registration_2026-10-26.json`](Industrial_Wall_Registration_2026-10-26.json).
  - Codex reviewed 249db85 and ran its tests independently: 315 passed, 0 failed.
  - All 55 probes are valid, 0 invalid. Structure filters: Floors 5, Walls 4, Doors 2, Ceilings 3, Windows 3.
  - The wall is installed with its 26 parts anchored and its PointLight disabled; no lighting behaviour is claimed.
  - Real client BuilderRequest calls all succeeded: Place at local (0, 0, 8, yaw 0), Rotate direction 1, then Delete (revisions 1, 2 and 3). The test copy was removed.
  - Back in Edit, catalog and template persistence was verified. No physical UI-click or R-key test was done.
- **54-item checkpoint** (superseded): 38 furniture and 16 structure. That's the earlier 52 plus the two batch 03 structure pieces registered in d034a34. Manifest: [`Batch03_Structure_Registration_2026-10-26.json`](Batch03_Structure_Registration_2026-10-26.json).
  - The two pieces:
    - `structure_glass_partition_01` (Grid Glass Partition; Windows; a fixed glass wall with no opening or door behaviour);
    - `structure_ceiling_acoustic_01` (Acoustic Tile Ceiling; Ceilings).
  - Codex reviewed d034a34 and ran its tests independently: 314 passed, 0 failed.
  - Installed the matching `Catalog` and both templates. All 54 live template probes are valid, 0 invalid.
  - Structure filters: Floors 5, Walls 3, Doors 2, Ceilings 3, Windows 3.
  - Real client BuilderRequest Place → Rotate → Delete passed for **each** new piece (all six operations ok), using the partition at (0, 0, 8, yaw 0) and the ceiling at (0, 15, 0, yaw 0). The test copies were removed.
  - Back in Edit, the 54 templates persist. No physical UI-click or R-key check was done.
- **52-item checkpoint** (superseded): 38 furniture and 14 structure. That's the earlier 51 plus `cozy_tufted_leather_sofa_01` (Tufted Leather Sofa, batch 02 H02_11, registered in 06adb12). Manifest: [`Tufted_Leather_Sofa_Registration_2026-10-26.json`](Tufted_Leather_Sofa_Registration_2026-10-26.json).
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
- **Not verified yet:** physical mouse/R-key UI, visual checks and doorway avatar clearance. The Play camera viewport was 1 × 1 and automated mouse input stalled. Codex reports the native Studio window renders normally; the capture limitation is specific to automated capture. **Correction:** later per-item native visual reviews *have* been done, as recorded in each registration since then. Physical mouse and R-key UI checks, a full visual QA pass and doorway avatar clearance remain unverified.
- **Existing-room extractions (task 11):** 11 installed (the water dispenser, the tall floor plant, the conference table, the flower pot, the office chair, the coffee mug, the presentation board, the studio softbox, the umbrella light, the broadcast indicator lamp, which is the audit's "On Air sign", and the panel door wall). The panel door wall is installed with static Edit checks only; its auto-open runtime is disabled and untested in Play (see the panel door plan). The 2 remaining gap-audit candidates are the guest laptop and the metal door, which aren't extracted. This is not a claim that all rooms are covered.
- **Candidates only:** batch 02 (the other 12 of 22; 10 are installed: the speaker, the layered coffee table, the sofa, the industrial wall, the acoustic wall, the drawer cabinet, the arched window wall (H02_09), the record console (H02_12), the capsule TV stand (H02_16) and the console desk (H02_19, the desk only, not the rest of the composite); the last four have static Edit checks only; prepared copies recreated and re-read in Edit; review gallery staged; fit, orientation, visual and placement approval pending), batch 03 (2 installed, listed above; 1 other source, the Modern wood block, still quarantined and not Build-ready; 9 thumbnail-only), the existing-room gap audit (13 room objects: 11 since extracted and installed, per the task 11 line above, including the panel door as a wall module; the other 2 are the laptop and metal door, not extracted yet), and 10 tracked candidates from the refresh.
- **Full-place backup (latest verified):** saved locally by Codex after the 71-item install, using Download a Copy. It is local only and not uploaded. **It does not contain the console desk** (the 72-item backup is pending; see the status block).
  - File: `StudioBuilder-FullBackup-71Items-2026-10-26.rbxl`, 4,192,968 bytes, SHA256 `2215DA91CCEA816CDE191562165B26895A5A81EA0F4690F80944F53BBD065F9B`.
  - File and hash verified by Codex. **Restore not tested.**
  - Contents: the 71-item catalog and templates, with `Config.Doors.Enabled = false`. Older backups are preserved.
- **Previous full-place backup (70 items)** (superseded; local only):
  - File: `StudioBuilder-FullBackup-70Items-2026-10-26.rbxl`, 4,191,919 bytes, SHA256 `570BEE62BCE474573B4C0D745964F1E4B776A8BD9C62BE1075DBE658A46C9E52`.
  - **Restore not tested.**
  - Contents: the 70-item catalog and templates, with `Config.Doors.Enabled = false`. Earlier backups are kept.
- **Previous full-place backup (69 items)** (superseded; local only):
  - File: `StudioBuilder-FullBackup-69Items-2026-10-26.rbxl`, 4,190,746 bytes, SHA256 `5FD3A92904C917146C6CFDC4B10E2B57F0A6C54327FE4D6B06A4F64AF8F48140`.
  - **Restore not tested.**
  - Contents: the 69-item catalog and templates, with `Config.Doors.Enabled = false`. Earlier backups are kept.
- **Previous full-place backup (68 items)** (superseded; local only):
  - File: `StudioBuilder-FullBackup-68Items-2026-10-26.rbxl`, 4,181,422 bytes, SHA256 `2F3EAFC938EEBE59835244E368C03E9BC074986B1264119357F98D2E0A712664`.
  - **Restore not tested.**
  - Contents: the 68-item catalog and templates, with `Config.Doors.Enabled = false`. Earlier backups are kept.
- **Previous full-place backup (67 items)** (superseded; local only):
  - File: `StudioBuilder-FullBackup-67Items-2026-10-26-0437.rbxl`, 4,157,515 bytes, SHA256 `FC83E5A57219C28E79C695E6D0D143F7420E05A031C3F554C9F5E5F78CCBC70A`.
  - Verified: the `<roblox!` header. **Restore untested.**
  - Contents: the 67-item catalog and templates. Earlier backups are kept. Being in the backup does not approve any candidate.
- **Previous full-place backup (66 items)** (superseded; local only):
  - File: `StudioBuilder-FullBackup-66Items-2026-10-26-0417.rbxl`, 4,156,676 bytes, SHA256 `7DCAC30F3BBA42629687528EC9ED4CE70ABCCDDB33ABBA08A28B92EE1874F740`.
  - Verified: the `<roblox!` header. **Restore not tested.**
  - Contents: the 66-item catalog and templates. Earlier backups are kept. Being in the backup does not approve any candidate.
- **Older full-place backup (65 items)** (superseded; local only):
  - File: `StudioBuilder-FullBackup-65Items-2026-10-26-0357.rbxl`, 4,152,323 bytes, SHA256 `DCD1A49520B4529154F1ECCA4FBAA17BCD9F5FBBAA7D07DF33B32EA7D64CFA0C`.
  - Verified: the `<roblox!` header. **Restore untested.**
  - Contents: the 65-item catalog and templates, including the softbox's prepared, review and installed copies. Earlier backups are kept. Being in the backup does not approve any candidate.
- **Older full-place backup (64 items)** (superseded; local only):
  - File: `StudioBuilder-FullBackup-64Items-2026-10-26-0337.rbxl`, 4,149,746 bytes, SHA256 `BDCFA33460196A8B8CEF4E24628803EE5887D0B5DABBD0C8A8B85ED03EAC1366`.
  - Verified: the `<roblox!` header. **Restore untested.**
  - Contents: the 64-item catalog and templates. Earlier backups are kept. Being in the backup does not approve any candidate.
- **Older full-place backup (63 items)** (superseded; local only):
  - File: `StudioBuilder-FullBackup-63Items-2026-10-26-0320.rbxl`, 4,148,374 bytes, SHA256 `CF9D24ADA36D3CBCC7D26B9D56029CF99DA24E77BB38E3634E09661C5E474F49`.
  - Verified: the Roblox header. **Restore untested.**
  - Contents: the 63-item catalog and templates. Previous backups are kept. Being in the backup does not approve any candidate.
- **Older full-place backup (62 items)** (superseded; local only):
  - File: `StudioBuilder-FullBackup-62Items-2026-10-26-0256.rbxl`, 4,147,271 bytes, SHA256 `C5217F564C31D98F89197137C2210A21860FD200B4EC24614831B70B50AA2220`.
  - Verified: a valid `<roblox!` header. **Restore not tested.**
  - Contents: the 62-item catalog and templates, including the chair's prepared, template and review copies. Previous backups are kept. Being in the backup does not approve any candidate.
- **Older full-place backup (61 items)** (superseded; local only):
  - File: `StudioBuilder-FullBackup-61Items-2026-10-26-0236.rbxl`, 4,145,249 bytes, SHA256 `0E3241A2FFE94E68ED4595EA30DE25A6CAC231C037141690C10B32065790F750`.
  - Verified: a valid `<roblox!` header. **Restore untested.**
  - Contents: the 61-item catalog and templates, including the pot's prepared, template and review copies. Previous backups are kept. Being in the backup does not approve any candidate.
- **Older full-place backup (60 items)** (superseded; local only):
  - File: `StudioBuilder-FullBackup-60Items-2026-10-26-0216.rbxl`, 4,143,957 bytes, SHA256 `4325F4E1C910E27715BFA054ACE452959BAAC4AB5EA382548D617B0EEC2DC234`.
  - Verified: a valid `<roblox!` header. **Restore untested.**
  - Contents: the 60-item catalog and templates, including the table's new prepared, template and review copies. Older backups are kept. Being in the backup does not approve any candidate.
- **Older full-place backup (59 items)** (superseded; local only):
  - File: `StudioBuilder-FullBackup-59Items-2026-10-26-0156.rbxl`, 4,143,330 bytes, SHA256 `96D1A865DD301CA79F0C1F7C8BC92621EA1E0529BBA21EA8DD9123469D6EA605`.
  - Verified: a valid `<roblox!` header. **Restore not tested.**
  - Contents: the 59-item catalog and templates, including the plant's new prepared, template and review copies. Earlier backups are kept. Being in the backup does not approve any candidate.
- **Older full-place backup (58 items)** (superseded; local only):
  - File: `StudioBuilder-FullBackup-58Items-2026-10-26-0136.rbxl`, 4,142,820 bytes, SHA256 `7005A6253149CD60D2926153EEA787EF0989A592AD6C731F3D09E786A688D8A3`.
  - Verified: the file and its `<roblox!` header. **Restore untested.**
  - Contents: the 58-item catalog and templates, including the dispenser's prepared, template and review copies. Earlier backups are kept. Being in the backup does not approve any candidate.
- **Older full-place backup (57 items)** (superseded; local only):
  - File: `StudioBuilder-FullBackup-57Items-2026-10-26-0116.rbxl`, 4,141,758 bytes, SHA256 `383785EC6115EC04623A659974D6AE4AC644CCE4634DEEB6DFBAD510D9D8F73F`.
  - Verified: the file and its `<roblox!` header. **Restore untested.**
  - Contents: the 57-item catalog and templates, including the cabinet's prepared, template and review copies. Earlier backups are kept. Being in the backup does not approve any candidate.
- **Older full-place backup (56 items)** (superseded; local only):
  - File: `StudioBuilder-FullBackup-56Items-2026-10-26-0055.rbxl`, 4,141,091 bytes, SHA256 `E290100DCCE4015401016F107D37FCFBF7D7C9DD0C24E7626DDCED5C15EC53DF`.
  - Verified: the file and its `<roblox!` header. **Restore untested.**
  - Contents: the 56-item catalog and templates, including the acoustic wall's prepared, template and review copies. Earlier backups are kept. Being in the backup does not approve any candidate.
- **Older full-place backup (55 items)** (superseded; local only):
  - File: `StudioBuilder-FullBackup-55Items-2026-10-26-0035.rbxl`, 4,139,781 bytes, SHA256 `5C606E2F9D121958C89C2573FD367F430B2D8DC23735CCC547F8C5D2E22A7097`.
  - Verified: the file exists and its binary Roblox header (`<roblox!`) checks out. **Restore not tested.**
  - Contents: the 55-item catalog and templates, including the prepared and installed industrial wall. Earlier backups are kept. Being in the backup does not approve any candidate.
- **Older full-place backup (54 items)** (superseded; local only; saved in Edit mode via File > Download a Copy):
  - File: `StudioBuilder-FullBackup-54Items-2026-10-26-0013.rbxl`, 4,137,806 bytes, SHA256 `48D0C5D40EAA99B0801949284198F70D01B19A83CF4BC7FE963B09538AAFBFC6`.
  - Verified: the file exists and has a binary Roblox header. **Restoration not tested.**
  - Contents: the 54-item catalog and templates, including the prepared, template and review copies of the two batch 03 structure pieces. Earlier backups are kept. Being in the backup does not approve any candidate.
- **Older full-place backup (52 items)** (superseded; local only):
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
| [`Existing_Room_Catalog_Gap_Audit_2026-10-26.json`](Existing_Room_Catalog_Gap_Audit_2026-10-26.json) | Read-only Play audit of **13 existing room objects or groups** (Conference Room and Broadcast Set) as possible Build additions. **As audited, these weren't imported, extracted, registered or Build-ready assets.** (Current tally: 11 of the 13 have since been extracted and installed through per-item registrations, including the On Air sign as the broadcast indicator lamp and the panel door as a 16 × 15 × 1 wall module (live 68); the other 2 are the laptop and metal door, still unextracted. See the task 11 line in the status block. The audit JSON itself is unchanged.) Flags: the **Guest laptop has 611 parts** and needs optimizing or a lower-part replacement; the **Office chairs** entry is a 12-seat group, so a single chair must be extracted; the **two doors** need grid and clearance adaptation (opening not verified); the **softbox, umbrella and On Air sign** each contain a light and need orientation and light-control review. No scripts were found in these 13 (not a whole-place audit). Template extraction is pending Edit mode. | 7 KB |
| [`Tufted_Leather_Sofa_Registration_2026-10-26.json`](Tufted_Leather_Sofa_Registration_2026-10-26.json) | Provenance for batch 02 H02_11 Leather Sofa (free, leutxiz), prepared as `cozy_tufted_leather_sofa_01`. Codex inspected the front and rear in the native viewport. The about −101° mesh yaw was corrected to identity, with the front facing −Z and a bottom-centre pivot. It is one anchored MeshPart, 10.97 × 4.00 × 6.02 studs, with zero scripts, Lights and Seats; decorative only. **Registered (repository 52); not installed** (installed 51), and not in the 51-item backup. The manifest is left as written at registration. **Since installed** (52 live; probe and remote Place/Rotate/Delete passed; in the 52-item RBXL backup): see the status block. | 2 KB |
| [`Futuristic_Furniture_Registration_2026-10-26.json`](Futuristic_Furniture_Registration_2026-10-26.json) | Provenance for 2 batch 02 pieces from the free Futuristic Furniture pack (SebbyTheGODKid), visually reviewed in the native Studio viewport and re-read in Edit by Codex: zero scripts, all parts anchored, bottom-centre pivots, zero Light objects. **Registered in `Catalog.luau` (repository count 51); not yet installed in `StudioBuilderTemplates`** (installed Build count 49). Also records the held Leather Sofa and that the new prepared names are not yet in a refreshed RBXL backup. The manifest is left as written at registration. **Since installed** (51 live, probe and remote Place/Rotate/Delete passed; new names in the 51-item RBXL backup): see the status block. | 3 KB |
| [`Console_Desk_Registration_2026-10-26.json`](Console_Desk_Registration_2026-10-26.json) | Provenance and preparation for batch 02 H02_19 from the free "Futuristic Furniture" pack by SebbyTheGODKid (asset 1375085945), prepared as `future_console_desk_01` (Console Desk; tables; futuristic). The original 20-part composite stays at `ServerStorage.CatalogHuntPrepared02.H02_19`. ONLY its five-part Desk model was extracted; the nine-part computer and the six-part chair (with its Seat) are excluded. Rotation normalized (width on X, the old chair side facing −Z), no scaling, identity bottom-centre pivot; size 8.000004 × 3.400012 × 5.000015. 5 anchored Parts, CanTouch false, zero nested models, scripts, seats, lights, joints, constraints and decals. Muted finish (gray and dark Metal; the Neon inlay changed to teal SmoothPlastic). No geometry added. Static Edit checks only. Static decorative desk: no computer, chair, lights or seating. **Registered (repository 72); not installed** (live 71); the prepared desk is not in a backup yet. The manifest is kept as history and left as written; its status is **superseded by installation evidence** (72 live; 72/72 templates valid; static Edit Place/Rotate/Delete at four yaws; outer edge OutOfBounds; no Play, UI, remote, avatar, physics, tabletop or save/load test). **No 72-item full-place backup exists yet**: see the status block. | 3 KB |
| [`Capsule_TV_Stand_Registration_2026-10-26.json`](Capsule_TV_Stand_Registration_2026-10-26.json) | Provenance and preparation for batch 02 H02_16, "Fururistic TV Stand by SebbyTheGODKid" from the free "Futuristic Furniture" pack (asset 1375085945), prepared as `future_capsule_tv_stand_01` (Capsule TV Stand; storage; futuristic). The original stays at `ServerStorage.CatalogHuntPrepared02.H02_16`. The clone was turned +90° (width on X) and scaled uniformly by 0.8, with an identity bottom-centre pivot; size 11.736886 × 3.647831 × 2.608202. 2 UnionOperations and 1 nested Model, all anchored, CanTouch false, with zero scripts, joints, constraints, Lights, Seats and decals. The finish was deliberately toned down: white Neon to muted teal SmoothPlastic and translucent Glass to opaque dark Metal. No geometry added. Static Edit checks only. Static decorative storage: no TV, playback, drawers, light or seating. **Registered (repository 71); not installed** (live 70); not in the 70-item backup. The manifest is kept as history and left as written; its status is **superseded by installation evidence** (71 live; 71/71 templates valid; static Edit Place/Rotate/Delete at four yaws; outer edge OutOfBounds; in the 71-item RBXL backup; no Play, UI, remote, avatar, physics or save/load test): see the status block. | 3 KB |
| [`Record_Console_Registration_2026-10-26.json`](Record_Console_Registration_2026-10-26.json) | Provenance and preparation for batch 02 H02_12, the free "Record Player & Shelf" by Savageboy (asset 126677556), prepared as `record_console_01` (Retro Record Console; audio; retro, 1980s, cozy). Imported yaw corrected by -70.91357436° and scaled uniformly by 0.625, with an identity bottom-centre pivot; about 8.75 × 4.0 × 2.5, front facing −Z. 57 anchored Parts, 2 nested Models and 1 top-facing Decal (texture recorded in the manifest, part of the imported model); zero scripts, joints, constraints, unanchored or touch-enabled parts. The four cardinal bounds and floor contact were checked and the look was reviewed in native Studio (static Edit only). Static decoration: no playback, spinning, drawers, seating or lights. **Registered (repository 70); not installed** (live 69); not in the 69-item backup. The manifest is kept as history and left as written; its status is **superseded by installation evidence** (70 live; 70/70 templates valid; static Edit Place/Rotate/Delete at four yaws; outer edge OutOfBounds; in the 70-item RBXL backup; no Play, UI, remote, avatar, physics or save/load test): see the status block. | 3 KB |
| [`Arched_Window_Wall_Registration_2026-10-26.json`](Arched_Window_Wall_Registration_2026-10-26.json) | Provenance and preparation for batch 02 H02_09, the free "Arch Window" by ClearlyRach (asset 492934961), prepared as `structure_window_arch_01` (Arched Window Wall; window_wall; cozy, retro, winter). The imported window was copied (the source is preserved), its yaw corrected by 19.088297°, scaled to 98% and raised 1.6, and set in a CSG plaster surround cut with clones of the original frame and glazing so the opening stays clear. 7 anchored parts, CanTouch false, no scripts, constraints, joints or body movers; 16 × 15 × 1 with an identity bottom-centre pivot. Static Edit checks only: native visual review, bounds at four yaws, 3 clear aperture rays and 3 surround hits. Codex's local manifest and screenshot are not in this repository. **Registered (repository 69); not installed** (live 68); not in the 68-item backup. The manifest is kept as history and left as written; its status is **superseded by installation evidence** (69 live; 69/69 templates valid; static Edit Place/Rotate/Delete at four yaws; outer edge OutOfBounds; in the 69-item RBXL backup; no Play, UI, remote, avatar, physics or save/load test): see the status block. | 3 KB |
| [`Panel_Door_Wall_Module_Preparation_2026-10-26.json`](Panel_Door_Wall_Module_Preparation_2026-10-26.json) | The final panel door wall module `structure_doorway_panel_01` (Wood Panel Door Wall; doorway; cozy, retro, 1980s, winter), prepared by Codex in Studio Edit at `ServerStorage.StudioBuilderPreparedAssets.structure_doorway_panel_01`: Frame, Leaf and WallSurround; 39 anchored parts, CanTouch false, no scripts, joints, constraints or body movers; closed bounds 16 × 15 × 1 with an identity bottom-centre pivot. Records the exact door metadata, the swept box, Codex's Edit-pose checks (396 passed; no runtime, physics, replication or avatar test) and the local backup (restore not tested). Parent room asset 4993294691; no creator, credit or door asset ID. **Registered (repository 68) prepared-only** (live 67) at the time and kept as written; **superseded by installation evidence**: installed in Edit (live 68; 68/68 probes valid; static Place/Rotate/Delete at four yaws; outer edge OutOfBounds; in the 68-item RBXL backup), with `Config.Doors.Enabled` false and no Play, avatar or auto-open check: see the status block. | 5 KB |
| [`Panel_Door_Candidate_Preparation_2026-10-26.json`](Panel_Door_Candidate_Preparation_2026-10-26.json) | **Candidate only: not registered, not installed, untested.** Codex's preparation of the gap audit's "Panel door" from `…ConferenceRoom.Door`: 35 anchored Parts (Frame and Leaf), with welds, Rotate joints, a BodyGyro and helper parts removed. Uniform 4/3 scale, 6.2 × 9 × 1, hinges at local x 2.5. The closed leaf blocks passage and it isn't a 16 × 15 × 1 module; see the plan [`../panel-door-plan.md`](../panel-door-plan.md). | 3 KB |
| [`Broadcast_Indicator_Registration_2026-10-26.json`](Broadcast_Indicator_Registration_2026-10-26.json) | Provenance and preparation for `studio_broadcast_indicator_01` (Broadcast Indicator Lamp; lighting; retro, 1980s, futuristic), from `BroadcastSet["On Air ausen"]`, the gap audit's "On air sign". The native review found a round glass indicator on a diamond-plate backing, **not a text sign**. It's project-modified and further adapted; parent room asset 136839605425322; no creator, credit or fixture ID. It has 3 Parts, rotated −90° to face −Z; size 1.75 × 1.75 × 1.37; zero scripts, joints and attributes; and 1 PointLight recorded as **disabled**. Decorative only: no recording reaction, switch or wall mount. **Registered (repository 67); not installed** (live 66). The manifest is kept as history and left as written; its registration status is **superseded by installation evidence** (67 live; probes 67/67 valid; floor, rotate, delete and raised request checks succeeded; light stayed disabled; in the 67-item RBXL backup): see the status block. | 3 KB |
| [`Studio_Umbrella_Light_Registration_2026-10-26.json`](Studio_Umbrella_Light_Registration_2026-10-26.json) | Provenance and preparation for `studio_umbrella_light_01` (Studio Umbrella Light; lighting; cozy, 1980s, futuristic). It is the **complete** Broadcast Set umbrella fixture: copies of the head (the gap audit's 10-part "Lighting umbrella"), the boom, the tripod and 3 supports, project-modified and further adapted. Parent room asset 136839605425322; no creator, credit or fixture ID. It has 44 anchored parts and 29 meshes, size 2.15 × 6.57 × 2.88, with zero scripts, Seats, joints, attributes and tags, and 1 PointLight recorded as **disabled** (decorative only). Two stray control-face pieces were removed, and no geometry was fabricated. **Registered (repository 66); not installed** (live 65). The manifest is kept as history and left as written; its registration status is **superseded by installation evidence** (66 live; probes 66/66 valid; Status, Place, Rotate and Delete succeeded; light stayed disabled after rotation; in the 66-item RBXL backup): see the status block. | 4 KB |
| [`Studio_Softbox_Registration_2026-10-26.json`](Studio_Softbox_Registration_2026-10-26.json) | Provenance and preparation for the eighth existing-room extraction: `studio_softbox_01` (Studio Softbox; lighting; cozy, 1980s, futuristic), from `Workspace.RoomCollection.BroadcastSet.Softbox1`, project-modified and further adapted (not an unchanged free model). Parent room asset 136839605425322; no creator, credit or separate softbox ID. The sideways source axes (height in Z) were normalized upright to 2.60 × 7.91 × 3.66, facing −Z. It has 25 anchored parts, zero scripts, Seats and joints, and 1 SpotLight recorded as **disabled** (decorative only, no lighting adapter). The welds and 27 room attributes were removed, and the diffuser re-coloured. **Registered (repository 65); not installed** (live 64). The manifest is kept as history and left as written; its registration status is **superseded by installation evidence** (65 live; probes 65/65 valid; Status, Place, Rotate and Delete succeeded; light still disabled after rotation; in the 65-item RBXL backup): see the status block. | 3 KB |
| [`Presentation_Board_Registration_2026-10-26.json`](Presentation_Board_Registration_2026-10-26.json) | Provenance and preparation for the seventh existing-room extraction: `studio_presentation_board_01` (Studio Presentation Board; screens; cozy, 1980s, futuristic), cloned from `…ConferenceRoom.WhiteBoard` in its current project-modified, StudioDisplay-branded version (not an unchanged free model). Parent model 4993294691; no creator, credit or individual board ID. The weld and the StudioTextRole attributes were removed, and it was rotated 180° to face −Z. Size 9.50 × 6.67 × 0.24; 9 anchored Parts, 4 CylinderMeshes, 1 SurfaceGui; zero scripts, Lights, Seats and joints. A static decorative screen only. **Registered (repository 64); not installed** (installed 63). The manifest is kept as history and left as written; its "pending" registration status is **superseded** by the verified installation (64 live; probe 64/64 valid; floor, rotate, delete and elevated request checks passed; in the 64-item RBXL backup): see the status block. | 3 KB |
| [`Coffee_Mug_Registration_2026-10-26.json`](Coffee_Mug_Registration_2026-10-26.json) | Provenance and preparation for the sixth existing-room extraction: `studio_coffee_mug_01` (Steaming Coffee Mug; decor; all five collections), from one `…ConferenceRoom.Coffee cup` in its current project-modified version (not an unchanged free model). Parent model 4993294691; no creator, credit or individual model ID. It has 5 anchored parts, 2 SurfaceGuis and 1 steam ParticleEmitter (settings recorded), with zero scripts, Lights, Seats and joints. Also records the TemplateSanitizer check (the emitter kept for placement, stripped from the preview) and what's still to verify. **Registered (repository 63); not installed** (installed 62). The manifest is kept as history and left as written; that registration status is **superseded** by the verified installation (63 live; probe 63/63 valid; floor, rotate, delete and tabletop request checks passed; steam seen in Play; in the 63-item RBXL backup): see the status block. | 3 KB |
| [`Office_Chair_Registration_2026-10-26.json`](Office_Chair_Registration_2026-10-26.json) | Provenance and preparation for the fifth existing-room extraction: `studio_office_chair_01` (Black Office Chair; seating, requested as "chairs"; cozy, 1980s, futuristic). It is one chair from `Workspace.RoomCollection.ConferenceRoom.Chairs`, not the 12-chair group. The parent free model 4993294691 is per the asset guide; the creator isn't verified, so there's no credit and no individual model ID. Mesh 96065544 and texture 96065600 are recorded here only. The SpecialMesh became one MeshPart at its original 1.125 scale, 2.28 × 4.15 × 2.35, front −Z; zero scripts, Lights, Seats and joints; the Seat and welds were excluded. Decorative only. **Registered (repository 62); not installed or runtime tested** (installed 61). The manifest is kept as history and left as written; that registration status is **superseded** by the verified installation (62 live; probe 62/62 valid; Play Status/Place/Rotate/Delete succeeded; in the 62-item RBXL backup): see the status block. | 3 KB |
| [`Flower_Pot_Registration_2026-10-26.json`](Flower_Pot_Registration_2026-10-26.json) | Provenance and preparation for the fourth existing-room extraction: `studio_flower_pot_01` (Red Flower Pot; plants; cozy, retro, 1980s, winter), from `Workspace.RoomCollection.ConferenceRoom.Flower Pot` (the gap audit's "Flower pot"). The parent free model 4993294691 is per the asset guide; the creator isn't verified, so there's no credit and no individual model ID. Size 1.95 × 2.92 × 1.94, identity bottom-centre pivot, 38 anchored parts (37 Parts and 1 Union) with 33 mesh objects, and zero scripts, Lights, Seats and joints. The original is kept, with no geometry added. Decorative only. **Registered (repository 61); not installed or runtime tested** (installed 60). The manifest is kept as history and left as written; that registration status is **superseded** by the verified installation (61 live; probe 61/61 valid; floor and elevated Play request checks succeeded; in the 61-item RBXL backup): see the status block. | 2 KB |
| [`Conference_Table_Registration_2026-10-26.json`](Conference_Table_Registration_2026-10-26.json) | Provenance and preparation for the third existing-room extraction: `studio_conference_table_01` (White Conference Table; tables; cozy, 1980s, futuristic), from `Workspace.RoomCollection.ConferenceRoom.Table` (the gap audit's "Conference table"). The parent free model 4993294691 is per the asset guide; the creator isn't verified, so there's no credit and no individual table model ID. Size 24.22 × 3.30 × 11.63, identity bottom-centre pivot, 3 anchored Parts, zero scripts, Lights, Seats and joints; the original is kept, with no geometry added. Decorative only, with no chairs or seats. **Registered (repository 60); not installed or runtime tested** (installed 59). The manifest is kept as history and left as written; that registration status is **superseded** by the verified installation (60 live; probe 60/60 valid; Play Place/Rotate/Delete succeeded; in the 60-item RBXL backup): see the status block. | 2 KB |
| [`Tall_Floor_Plant_Registration_2026-10-26.json`](Tall_Floor_Plant_Registration_2026-10-26.json) | Provenance and preparation for the second existing-room extraction: `studio_tall_floor_plant_01` (Tall Floor Plant; plants; cozy, retro, 1980s), from `Workspace.RoomCollection.ConferenceRoom.Potted Plant` (the gap audit's "Tall potted plant"). The parent free model 4993294691 is per the asset guide; the creator isn't verified and no individual plant model ID is claimed. Mesh 430369152 and texture 430369173 are recorded here only. Size 5.21 × 7.14 × 3.71, identity bottom-centre pivot, one anchored MeshPart, zero scripts, Lights, Seats and joints; the original mesh is kept, with no geometry added. Decorative only. **Registered (repository 59); not installed or runtime tested** (installed 58). The manifest is kept as history and left as written; that registration status is **superseded** by the verified installation (59 live; probe 59/59 valid; Play Place/Rotate/Delete succeeded; in the 59-item RBXL backup): see the status block. | 2 KB |
| [`Water_Dispenser_Registration_2026-10-26.json`](Water_Dispenser_Registration_2026-10-26.json) | Provenance and preparation for the first existing-room extraction: `studio_water_dispenser_01` (Water Dispenser; decor; cozy, 1980s), from `Workspace.RoomCollection.ConferenceRoom.Water Machine`. The parent free model 4993294691 is per the asset guide's ConferenceRoom record; the creator isn't verified and the dispenser has no individual asset ID. Size 1.95 × 5.1 × 2.25, identity bottom-centre pivot, 20 anchored parts and 14 SpecialMeshes, zero scripts, Lights, Seats and joints; 16 redundant welds removed and no geometry added. Decorative only. **Registered (repository 58); not installed or runtime tested** (installed 57). The manifest is left as written at registration; that registration status is **superseded**: since installed (58 live; probes and remote Place/Rotate/Delete passed; in the 58-item RBXL backup), see the status block. | 2 KB |
| [`Drawer_Cabinet_Registration_2026-10-26.json`](Drawer_Cabinet_Registration_2026-10-26.json) | Provenance and preparation for batch 02 H02_18 Future Dresser (Futuristic Furniture, 1375085945, SebbyTheGODKid), prepared as `future_drawer_cabinet_01`, a futuristic storage piece placed on the floor. Size 6.430999755859375 × 4.2000017166137695 × 3.27987003326416, identity bottom-centre pivot, front −Z. It has 6 anchored parts and zero scripts, Lights and Seats. Rotations were normalized with no geometry added; the woodgrain was replaced with gray SmoothPlastic, lighter drawer faces, a dark top and dark Metal knobs. Decorative only: the drawers don't open. **Registered (repository 57); not installed, runtime tested or backed up** (installed 56). The manifest is left as written at registration; that registration status is **superseded**: since installed (57 live; probes and remote Place/Rotate/Delete passed; in the 57-item RBXL backup), see the status block. | 2 KB |
| [`Acoustic_Wall_Registration_2026-10-26.json`](Acoustic_Wall_Registration_2026-10-26.json) | Provenance and preparation for batch 02 H02_10: the Acoustic Panel Set (9069165816, DesolatedWorld), prepared as `structure_acoustic_wall_01`. One grooved UnionOperation from the free model was adapted into an 8 × 7 checkerboard of 1.96 × 0.2 × 1.96 charcoal Fabric tiles (collision and touch off), plus an **added** 16 × 15 × 0.8 backing Part that supplies the collision. Total 16 × 15 × 1, 57 anchored parts, zero scripts and lights. Appearance only, with no sound behaviour. **Registered (repository 56); not installed or runtime tested** (installed 55), and not in the 55-item backup. The manifest is left as written at registration. **Since installed** (56 live; probes and remote Place/Rotate/Delete passed; in the 56-item RBXL backup): see the status block. | 2 KB |
| [`Industrial_Wall_Registration_2026-10-26.json`](Industrial_Wall_Registration_2026-10-26.json) | Provenance and preparation for batch 02 H02_03: the Straight Wall from the Modular Wall Pack (120565443892509, WilliamBosso), prepared as `structure_industrial_wall_01`. The geometry was rotated and normalized to 16 × 15 × 1, with a minimum trim thickness of 0.05 and depth constrained to one stud. It has 26 anchored BaseParts, zero scripts, and one disabled PointLight (no lighting behaviour claimed). **Registered (repository 55); not installed or runtime tested** (installed 54), and not in the 54-item backup. The manifest is left as written at registration. **Since installed** (55 live; probes and remote Place/Rotate/Delete passed; in the 55-item RBXL backup): see the status block. | 2 KB |
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

## Catalog hunt batch 02 (2026-10-26): 6 of 22 installed; 16 candidates only

Inventory: [`Catalog_Hunt_Batch02_2026-10-26.json`](Catalog_Hunt_Batch02_2026-10-26.json), archived exactly as provided and left unchanged.

**Registration update (2026-10-26):** two pieces from the Futuristic Furniture pack passed Codex's visual and static checks and are registered in the repository (see [`Futuristic_Furniture_Registration_2026-10-26.json`](Futuristic_Furniture_Registration_2026-10-26.json)):
- `future_speaker_01` (Neon Studio Speaker) = H02_13 Future Speaker (**confirmed by Codex**).
- `future_layered_coffee_table_01` (Layered Neon Coffee Table) = H02_20 Future Coffee Table (**confirmed by Codex**).
- **Installed (superseding checkpoint):** both are now in `StudioBuilderTemplates`. They passed the live probe and real BuilderRequest Place → Rotate → Delete in Play, and they persist in Edit. Physical UI-click and R-key tests weren't done.
- **Leather Sofa (H02_11), later checkpoint:** after being held from a rear three-quarter inspection, the sofa was inspected from the front and rear in the native viewport. Its mesh yaw (about −101°) was corrected to identity, with the front facing −Z.
  - It is registered in the repository as `cozy_tufted_leather_sofa_01` (Tufted Leather Sofa) from `ServerStorage.StudioBuilderPreparedAssets.cozy_tufted_leather_sofa_01`, per [`Tufted_Leather_Sofa_Registration_2026-10-26.json`](Tufted_Leather_Sofa_Registration_2026-10-26.json).
  - **Installed (superseding checkpoint):** it is now in `StudioBuilderTemplates`. It passed the probe and real BuilderRequest Place → Rotate → Delete in Play, and it persists in Edit. No physical UI-click or R-key test was done.
  - It is decorative only, with zero Seats, so there is no sitting or clearance claim.
- **H02_03 (Industrial Straight Wall):** prepared and registered as `structure_industrial_wall_01` (see [`Industrial_Wall_Registration_2026-10-26.json`](Industrial_Wall_Registration_2026-10-26.json)), and now **installed** (superseding checkpoint). It passed the probes and real BuilderRequest Place → Rotate → Delete in Play, and it persists in Edit; no physical UI-click or R-key test was done. The original candidate is retained.
- **H02_10 (Acoustic Panel Set):** adapted, registered as `structure_acoustic_wall_01` (see [`Acoustic_Wall_Registration_2026-10-26.json`](Acoustic_Wall_Registration_2026-10-26.json)), and now **installed** (superseding checkpoint). It passed the probes and real BuilderRequest Place → Rotate → Delete in Play, and it persists in Edit; no physical UI-click or R-key test was done. The original candidate is retained.
- **H02_18 (Future Dresser):** prepared, registered as `future_drawer_cabinet_01` (see [`Drawer_Cabinet_Registration_2026-10-26.json`](Drawer_Cabinet_Registration_2026-10-26.json)), and now **installed** (superseding checkpoint). It passed the probes and real BuilderRequest Place → Rotate → Delete in Play, and it persists in Edit; no physical UI-click or R-key test was done. The original candidate is retained.
- **The other 16 remain pending.**
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
