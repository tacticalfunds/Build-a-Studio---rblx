# Studio reference: installed bb3efa6 script snapshot

`Studio_Persistence_bb3efa6_Source_Backup.json` is a read-only copy of the **actual installed source** of 45 scripts in the working place.
Codex exported it from Studio after installing builder commit bb3efa6.

**It is a reference, not a sync source.** Nothing reads it at runtime, and Rojo doesn't map it.
`tests/spec/seat_assignments_spec.lua` reads it, to check that the seat model's contracts match the live StudioLayout, PodcastSeating, PodcastPoses, Director and StudioCustomization.
When the live scripts change, a new snapshot replaces this one, and this index is updated with it.

| Field | Value |
|---|---|
| Commit | `bb3efa6` |
| PlaceId | `132242140555698` |
| Verified (as recorded) | Memory-only actual Director Play Save/Load round trip and failed-load latch; no real DataStore/text-filter validation |
| Scripts | 45 |
| File SHA-256 | `8ca817b5af2bce678183ffe1f92bab0c170c258a3687495d15f8b61b5b7455d0` |

## Backups: which file covers what

- **Full place (RBXL):** the full-place backup is still the **62f2f87 baseline**. It wasn't updated for bb3efa6.
- **This JSON:** backs up the bb3efa6 **scripts only**: no Instances, templates, attributes or place settings.

## Installed builder sources vs. this repository

All 34 comparable scripts (32 StudioBuilder modules, plus `DirectorPersistence` and `StudioPresets`) were compared with this repository at commit bb3efa6.
The comparison ignores `\r` and trailing newlines. They are identical.
Later commits (for example, task 7's seat constants in `Config`) are newer than this snapshot.
The working place has since installed the 6a8e490 `Catalog` (31 items) and 24 more templates. Neither is in this JSON (see `docs/integration-catalog-expansion.md`).

## Index

The source hash is the first 12 hex characters of SHA-256 over the `Source` string as stored.

| Path | Class | Bytes | Source hash | Status |
|---|---|---|---|---|
| `ReplicatedStorage.PodcastLighting` | ModuleScript | 39612 | `ab7c5fb7df99` | Live script; not in this repository |
| `ReplicatedStorage.StudioBuilder.Catalog` | ModuleScript | 6485 | `486c19def460` | Same as `src/shared/Catalog.luau` at bb3efa6 |
| `ReplicatedStorage.StudioBuilder.Config` | ModuleScript | 2931 | `b02aa28dc27b` | Same as `src/shared/Config.luau` at bb3efa6 |
| `ReplicatedStorage.StudioBuilder.Protocol` | ModuleScript | 3930 | `029fc4193476` | Same as `src/shared/Protocol.luau` at bb3efa6 |
| `ReplicatedStorage.StudioBuilder.Transform` | ModuleScript | 2991 | `5f518ca7af85` | Same as `src/shared/Transform.luau` at bb3efa6 |
| `ReplicatedStorage.StudioBuilder.Validate` | ModuleScript | 1294 | `7a7479ea5641` | Same as `src/shared/Validate.luau` at bb3efa6 |
| `ReplicatedStorage.StudioCustomization` | ModuleScript | 2770 | `477dd525e43c` | Live script; not in this repository |
| `ServerScriptService.DirectorPersistence` | ModuleScript | 17852 | `0b36a171e97f` | Same as `integration/DirectorPersistence.luau` at bb3efa6 |
| `ServerScriptService.PodcastDirector` | Script | 21448 | `03f48a5fe24d` | Live script with the task 5 patch installed (construction block + both room-mutation gates) |
| `ServerScriptService.PodcastPoses` | Script | 1847 | `7305c38c8c09` | Live script; not in this repository |
| `ServerScriptService.PodcastSeating` | Script | 3356 | `435c79677768` | Live script; not in this repository |
| `ServerScriptService.StudioBuilder.Adapters.Entitlements` | ModuleScript | 2133 | `d1b998a052c0` | Same as `src/server/Adapters/Entitlements.luau` at bb3efa6 |
| `ServerScriptService.StudioBuilder.Adapters.HostAuthority` | ModuleScript | 2781 | `06c040818cbd` | Same as `src/server/Adapters/HostAuthority.luau` at bb3efa6 |
| `ServerScriptService.StudioBuilder.Adapters.RoomProvider` | ModuleScript | 2959 | `e3fbce373fdd` | Same as `src/server/Adapters/RoomProvider.luau` at bb3efa6 |
| `ServerScriptService.StudioBuilder.Adapters.SaveBackends` | ModuleScript | 1630 | `324df50282a0` | Same as `src/server/Adapters/SaveBackends.luau` at bb3efa6 |
| `ServerScriptService.StudioBuilder.Adapters.SaveSnapshot` | ModuleScript | 7868 | `16b186bd040e` | Same as `src/server/Adapters/SaveSnapshot.luau` at bb3efa6 |
| `ServerScriptService.StudioBuilder.Adapters.TemplateCatalog` | ModuleScript | 5035 | `b28207cdb0ae` | Same as `src/server/Adapters/TemplateCatalog.luau` at bb3efa6 |
| `ServerScriptService.StudioBuilder.Bootstrap.AssetYardGuard` | ModuleScript | 784 | `f0b9cd1c17e9` | Same as `src/server/Bootstrap/AssetYardGuard.luau` at bb3efa6 |
| `ServerScriptService.StudioBuilder.Core.BuildHistory` | ModuleScript | 2828 | `a7e27159b26d` | Same as `src/server/Core/BuildHistory.luau` at bb3efa6 |
| `ServerScriptService.StudioBuilder.Core.BuildModel` | ModuleScript | 2471 | `b777b7edc81d` | Same as `src/server/Core/BuildModel.luau` at bb3efa6 |
| `ServerScriptService.StudioBuilder.Core.BuildPersistence` | ModuleScript | 7077 | `bdd5cfc1ff18` | Same as `src/server/Core/BuildPersistence.luau` at bb3efa6 |
| `ServerScriptService.StudioBuilder.Core.PlacementCore` | ModuleScript | 30276 | `685dc5959caf` | Same as `src/server/Core/PlacementCore.luau` at bb3efa6 |
| `ServerScriptService.StudioBuilder.Core.PresetSlotGuard` | ModuleScript | 4679 | `9c00703921af` | Same as `src/server/Core/PresetSlotGuard.luau` at bb3efa6 |
| `ServerScriptService.StudioBuilder.Core.RateLimiter` | ModuleScript | 1297 | `ceb4211b3c12` | Same as `src/server/Core/RateLimiter.luau` at bb3efa6 |
| `ServerScriptService.StudioBuilder.Core.RequestValidator` | ModuleScript | 3053 | `e5c7cbf27529` | Same as `src/server/Core/RequestValidator.luau` at bb3efa6 |
| `ServerScriptService.StudioBuilder.Runtime.BuilderService` | ModuleScript | 6875 | `c76bcc7e6d66` | Same as `src/server/Runtime/BuilderService.luau` at bb3efa6 |
| `ServerScriptService.StudioBuilder.Runtime.PlacedItemsWorld` | ModuleScript | 7030 | `9cc0c786903a` | Same as `src/server/Runtime/PlacedItemsWorld.luau` at bb3efa6 |
| `ServerScriptService.StudioBuilder.Runtime.TemplateSanitizer` | ModuleScript | 2242 | `126d3f63551b` | Same as `src/server/Runtime/TemplateSanitizer.luau` at bb3efa6 |
| `ServerScriptService.StudioBuilder.StudioBuilderBootstrap` | Script | 645 | `2849c931221f` | Same as `src/server/StudioBuilderBootstrap.server.luau` at bb3efa6 |
| `ServerScriptService.StudioLayout` | ModuleScript | 4618 | `1b9462aaeee7` | Live script; not in this repository |
| `ServerScriptService.StudioPresets` | ModuleScript | 3537 | `c445b780f6a6` | Same as `integration/StudioPresets.luau` at bb3efa6 |
| `StarterPlayer.StarterPlayerScripts.PodcastAtmosphere` | LocalScript | 5923 | `b4b32770ed65` | Live script; not in this repository |
| `StarterPlayer.StarterPlayerScripts.PodcastCamera` | LocalScript | 16413 | `d5a9f5846a74` | Live script; not in this repository |
| `StarterPlayer.StarterPlayerScripts.PodcastPoses` | LocalScript | 5160 | `9b1d5d9f5641` | Live script; not in this repository |
| `StarterPlayer.StarterPlayerScripts.PodcastSpeakerFollow` | LocalScript | 4127 | `25d4c92c3418` | Live script; not in this repository |
| `StarterPlayer.StarterPlayerScripts.PodcastStudioPanel` | LocalScript | 43305 | `222f680f099e` | Live script; not in this repository |
| `StarterPlayer.StarterPlayerScripts.StudioBuilder.Adapters.BuildModeHandoff` | ModuleScript | 8661 | `ab1696da6b1b` | Same as `src/client/Adapters/BuildModeHandoff.luau` at bb3efa6 |
| `StarterPlayer.StarterPlayerScripts.StudioBuilder.Adapters.PodcastCameraHook` | ModuleScript | 3367 | `2147260ac771` | Same as `src/client/Adapters/PodcastCameraHook.luau` at bb3efa6 |
| `StarterPlayer.StarterPlayerScripts.StudioBuilder.Build.BuildController` | ModuleScript | 19159 | `f50edbb47e5a` | Same as `src/client/Build/BuildController.luau` at bb3efa6 |
| `StarterPlayer.StarterPlayerScripts.StudioBuilder.Build.BuildDrawer` | ModuleScript | 13395 | `b68b25cb4ec3` | Same as `src/client/Build/BuildDrawer.luau` at bb3efa6 |
| `StarterPlayer.StarterPlayerScripts.StudioBuilder.Build.BuildInput` | ModuleScript | 1632 | `dfa07b9d02e3` | Same as `src/client/Build/BuildInput.luau` at bb3efa6 |
| `StarterPlayer.StarterPlayerScripts.StudioBuilder.Build.BuildSession` | ModuleScript | 6979 | `d71ab53371f4` | Same as `src/client/Build/BuildSession.luau` at bb3efa6 |
| `StarterPlayer.StarterPlayerScripts.StudioBuilder.Build.PlacementPreview` | ModuleScript | 2056 | `de41753666e4` | Same as `src/client/Build/PlacementPreview.luau` at bb3efa6 |
| `StarterPlayer.StarterPlayerScripts.StudioBuilder.BuilderClient` | ModuleScript | 11816 | `348dbd8b2f28` | Same as `src/client/BuilderClient.luau` at bb3efa6 |
| `StarterPlayer.StarterPlayerScripts.StudioBuilder.UI.PanelTheme` | ModuleScript | 4520 | `6f15d3356f24` | Same as `src/client/UI/PanelTheme.luau` at bb3efa6 |
