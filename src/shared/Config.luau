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

-- Build snapshot (separate from StudioPresets, which keeps its own 5 slots / 250 KB cap)
Config.SnapshotSchema = "StudioBuilder.Build"
Config.SnapshotVersion = 1
Config.MaxSnapshotBytes = 64 * 1024

-- Instance names (builder-owned; never shared with existing Podcast* systems)
Config.TemplateFolderName = "StudioBuilderTemplates" -- curated by Codex in ServerStorage
Config.PlacedItemsFolderName = "StudioBuilderPlacedItems" -- excluded from StudioCustomization
Config.SandboxMarkerName = "StudioBuilderSandbox" -- Workspace part whose volume is the build volume

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
