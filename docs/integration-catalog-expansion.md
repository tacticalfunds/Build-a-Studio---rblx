# Integration report: catalog expansion (6a8e490)

**Status:** the 31-item catalog is **installed and checked in Studio Play** (Codex, 2026-10-25).
Seat runtime, real-service QA (DataStore save/load with expansion items, multiplayer) and a bulk performance benchmark are **not** done.

The original provenance stays in [`docs/assets/Catalog_Expansion_2026-10-25.json`](assets/Catalog_Expansion_2026-10-25.json).
That manifest is unchanged. Its `status` line and `templatePath` values (`ServerStorage.StudioBuilderExpansion.*`) describe the templates **as prepared, before install**.

## What was installed

| Item | State in the working place |
|---|---|
| Catalog source | The reviewed `src/shared/Catalog.luau` at 6a8e490 (31 items) was installed. **Only the Catalog changed.** The rest of the runtime stays at bb3efa6 plus the existing local integration patches (see the README, "Live patch points"). |
| Templates | All 24 additions are in `ServerStorage.StudioBuilderTemplates` under their item IDs, for **31** in total. The prepared originals are kept in `ServerStorage.StudioBuilderExpansion`. |
| Template preparation | The 24 new templates are scriptless and anchored, with Seats, lights and effects disabled. Their ThumbnailCameras were removed. |
| Asset yard | 24 manual-use copies are in `Workspace.StudioAssetYard`, folder `07 Builder Catalog Expansion`. Like the rest of the yard, `AssetYardGuard` removes them at play start. They're never a template source. |
| Seat profiles | None. `SeatProfiles.Profiles` is still empty, and every item is decorative. |

## Observed evidence (Codex, real Studio)

| Check | Result |
|---|---|
| `Catalog.validate()` in real Studio Luau | Passed |
| Play: client `Place` then `Delete` for every catalog ID | **31 of 31 succeeded**, zero failures |
| Play: `future_curved_sofa_01` placed at x = 23 | Correctly answered `OutOfBounds` (the footprint check at the sandbox edge) |
| Play: Host Panel > Studio > OPEN BUILDER | The drawer opened. The five filters show **Cozy 22, Retro 16, 1980s 12, Winter 11, Futuristic 9**, matching `catalog_spec`. |
| Play: card click then floor click | Clicking the Curved Lounge Sofa card, then the floor, placed it |
| `ReplicatedStorage.StudioBuilder.PreviewTemplates` | Holds 31 models |
| Startup and clean-up | Play stopped, and no QA scripts were kept in the place |

## Observation to keep in mind

- **The legacy floor lamp still lights.** The original `cozy_floor_lamp_01` template **still contains its light** and emits light when placed.
  That's the template as it was, not a lighting adapter: the builder doesn't control it, save it or link it to PodcastLighting.
  The 24 new templates have their lights disabled. Whether the old lamp's light should be disabled for consistency is a template decision for Codex. No code change was made.
- **Stale comments in `Catalog.luau`.** The header comments still describe the pre-install state: templates in `StudioBuilderExpansion`, and Studio verification pending.
  This checkpoint is documentation-only, so the source is unchanged. Those comments get corrected with the next code checkpoint.

## Not verified (do not claim)

- Real DataStore save and load of builds that use expansion items. Earlier save/load checks used memory stand-ins.
- Multiplayer: replication of expansion items to a second client, late joiners, streaming for other players.
- A bulk performance benchmark: join time and memory with 31 preview templates (some over 100 parts), and drawer ViewportFrame cost.
- Move, Rotate, Duplicate, Undo and Redo per expansion item: only Place and Delete ran for all 31.
- Card-click placement through the drawer for items other than the Curved Lounge Sofa.
- Any seat behaviour: task 7 is still a pure model, and no seat profile is approved.

## Backups

- **Full place:** the full-place backup is still the **62f2f87 baseline**. A new full-place backup of this state is **pending**.
  Codex didn't take one because the user stopped native Computer Use, and that isn't to be bypassed.
- **Scripts:** the 45-script JSON in `docs/studio-reference/` backs up the bb3efa6 scripts only. It doesn't include the expansion templates or the updated Catalog module.
