# Studio asset index

Metadata snapshot of the live Roblox place. **This is an index, not the models.**
No binary models or place files are stored in this repository.

| | |
|---|---|
| Place | Studio Experience, place ID `132242140555698` |
| Snapshot date | 2026-10-25 (inventory generated `2026-10-25T17:42:27Z`) |
| Produced by | Codex (asset discovery / Studio integration), from a local Studio scan |

## Files

Read them in this order:

| File | What it holds | Size |
|---|---|---|
| [`Studio_Asset_Handoff_2026-10-25.txt`](Studio_Asset_Handoff_2026-10-25.txt) | Plain-text summary: read-first rules, builder contract, a summary of each stored asset, and the six rooms. **Start here.** | 24 KB |
| [`Studio_Asset_Guide_2026-10-25.json`](Studio_Asset_Guide_2026-10-25.json) | Human-oriented guide. `assets` (39 stored top-level entries: 34 previous + 5 `BuilderAssetReview` candidates), `rooms` (6), `commonPreparation`. Each entry has appearance, function, evidence, proposed collections and known provenance. | 53 KB |
| [`Studio_Asset_Inventory_2026-10-25.json`](Studio_Asset_Inventory_2026-10-25.json) | Exhaustive index. `ModelRecords` (2594 **nested** models, not distinct products), `LooseParts` (4), `ContentReferences` (448 distinct content URLs/IDs with use paths), `ScriptRecords` (13), `Services`. | 2.3 MB |
| [`Catalog_Expansion_2026-10-25.json`](Catalog_Expansion_2026-10-25.json) | The catalog expansion manifest: 24 templates prepared in `ServerStorage.StudioBuilderExpansion`, each with id, displayName, collections, sourceRef, an optional `sourceAssetId` (provenance only, never loaded), scripts (0), parts, size and functionality (decorative only). These 24 items are registered in `src/shared/Catalog.luau`; Studio verification of the registered catalog is pending. | 14 KB |
| [`Studio_Components_2026-10-25.json`](Studio_Components_2026-10-25.json) | Functional components, including inactive storage duplicates: `Fixtures` (161 lights), `Seats` (95 Seat/VehicleSeat), `Effects` (55 emitters), `Sounds` (2), `Displays` (83 text displays), `RoomConfig` (26). | 90 KB |

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
