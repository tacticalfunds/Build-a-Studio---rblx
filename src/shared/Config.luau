--[[
	Config: shared constants for the Studio Builder sandbox.

	The server enforces these values itself; the client only reads them to
	pre-validate. Written in the Lua 5.1-compatible subset of Luau so the pure
	modules can be exercised by tests/run.lua outside Roblox.
]]

local Config = {}

-- Identifiers
Config.MaxCatalogIdLength = 48
Config.MaxBuildIdLength = 11 -- "i" + up to 10 digits

-- Build limits
Config.MaxItems = 150
Config.MaxCoordinate = 1024 -- absolute sanity bound on any stored local coordinate

-- Placement (server enforces; client preview mirrors via shared Transform)
Config.GridSize = 1 -- studs; client snapping step, also the duplicate offset step
Config.RotationStep = 15 -- degrees; yaw must be a multiple of this
Config.PositionPrecision = 0.01 -- server quantizes positions to this step
Config.BoundsEpsilon = 0.001

-- Per-player token buckets
Config.RateLimits = {
	edit = { capacity = 12, refillPerSecond = 6 },
}

-- Build save payload: an additive `Build` section inside a StudioPresets snapshot
-- ({Version=1, Settings, Fixtures, Items, Build}). The preset entry/top-level
-- Version stays 1; StudioPresets keeps its 5 slots and 250000-byte JSON cap.
Config.BuildSectionKey = "Build"
Config.BuildSectionVersion = 1
Config.MaxBuildSectionBytes = 64 * 1024 -- leaves room for the rest of the preset

-- Instance names (builder-owned; never shared with existing Podcast* systems)
Config.TemplateFolderName = "StudioBuilderTemplates" -- curated by Codex in ServerStorage
Config.PlacedItemsFolderName = "StudioBuilderPlacedItems" -- excluded from StudioCustomization
Config.BuildItemIdAttribute = "BuildItemId" -- tag on every placed model; StudioCustomization must skip it
Config.AssetYardName = "StudioAssetYard" -- editor-only display copies in Workspace, removed at play start
Config.SandboxMarkerName = "StudioBuilderSandbox" -- Workspace part whose volume is the build volume
Config.BuildRevisionAttribute = "BuildRevision" -- on the placed-items folder; never LayoutRevision
Config.PreviewTemplatesFolderName = "PreviewTemplates" -- sanitized copies under ReplicatedStorage.StudioBuilder
Config.RemotesFolderName = "Remotes"
Config.RequestRemoteName = "BuilderRequest"

-- Keys the builder itself binds while open. Host keys that build mode suppresses
-- or must leave working live in client/Adapters/BuildModeHandoff.
Config.BuilderKeys = { "R", "Escape" }

-- Studio-only conveniences. Off by default: production-looking placeholders are
-- not allowed, so missing templates show as "not installed" unless a test fixture
-- folder is explicitly opted into.
Config.Dev = {
	UseTestFixtures = false,
	TestFixtureFolderName = "StudioBuilderTestFixtures",
}

return Config
