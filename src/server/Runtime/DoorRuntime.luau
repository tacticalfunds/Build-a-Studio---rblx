--[[
	DoorRuntime: builds the auto-open door runtime from its real parts
	(panel door plan, docs/panel-door-plan.md). DISABLED BY DEFAULT:
	BuilderService calls start() only when Config.Doors.Enabled is true, and
	start() itself returns nil when the flag is off. With no runtime,
	PlacedItemsWorld gets no door hook and behaves exactly as before.

	start(deps) -> DoorController (started) or nil when disabled. deps:
		config     shared Config (Doors.Enabled, Doors.ScanInterval, MaxItems)
		catalog    shared Catalog (door metadata and floor kinds come only
		           from here; nothing a client sends is read)
		origin     sandbox origin CFrame (floor centre)
		folder     the placed-items Folder
		bounds     sandbox { halfX, halfZ, height }
		heartbeat  signal with :Connect (RunService.Heartbeat)
		clock      function() -> seconds
		log        optional function(message)
		exclude    optional list of Instances left out of overlap queries
		           (the sandbox marker part)
		roblox     optional injected types for DoorRuntimeAdapters (tests)

	Capacity: the controller allows Config.MaxItems (150) committed doors,
	and the DoorAutoOpen core holds twice that, so a full build load can
	stage a replacement set beside the frozen old one.

	One runtime at a time: start() first destroys any runtime it started
	earlier (stopping its Heartbeat connection and releasing its doors), so
	a rebind never leaves two controllers ticking. stop() does the same and
	is safe to call repeatedly.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("StudioBuilder")
local Config = require(Shared:WaitForChild("Config"))

local Server = script.Parent.Parent
local DoorAutoOpen = require(Server:WaitForChild("Core"):WaitForChild("DoorAutoOpen"))
local DoorController = require(script.Parent:WaitForChild("DoorController"))
local DoorSensing = require(script.Parent:WaitForChild("DoorSensing"))
local DoorRuntimeAdapters = require(script.Parent:WaitForChild("DoorRuntimeAdapters"))

local DoorRuntime = {}

local active = nil

function DoorRuntime.isEnabled(config)
	config = config or Config
	return type(config.Doors) == "table" and config.Doors.Enabled == true
end

-- Door metadata for a catalog id, read from the server's catalog only.
local function specSource(catalog)
	return function(itemId)
		local item = type(itemId) == "string" and catalog.getItem(itemId) or nil
		return type(item) == "table" and item.door or nil
	end
end

-- A part supports a door when it belongs to a placed floor piece: a direct
-- child of the placed-items folder whose catalog id is a floor structure
-- item. DoorSensing still blocks a floor that rises into the sweep.
local function supportingFloor(catalog, folder)
	local floors = {}
	for _, item in ipairs(catalog.Items) do
		if type(item.structure) == "table" and item.structure.kind == "floor" then
			floors[item.id] = true
		end
	end
	return function(_, model)
		if model == nil or model.Parent ~= folder then
			return false
		end
		local id = model:GetAttribute("BuildCatalogId")
		return type(id) == "string" and floors[id] == true
	end
end

-- Builds the controller without starting it.
function DoorRuntime.build(deps)
	assert(type(deps) == "table", "DoorRuntime needs deps")
	local config = deps.config or Config
	local activeCap = config.MaxItems
	local adapterDeps = {
		origin = deps.origin,
		folder = deps.folder,
		exclude = deps.exclude,
		maxHits = DoorSensing.Defaults.maxHits,
		isSupportingFloor = supportingFloor(deps.catalog, deps.folder),
	}
	for key, value in pairs(deps.roblox or {}) do
		adapterDeps[key] = value
	end
	local sensing = DoorSensing.new({
		getCharacters = DoorRuntimeAdapters.characters(adapterDeps),
		queryBox = DoorRuntimeAdapters.queryBox(adapterDeps),
		bounds = deps.bounds,
	})
	return DoorController.new({
		core = DoorAutoOpen.new({ maxDoors = 2 * activeCap }),
		sensing = sensing,
		driver = DoorRuntimeAdapters.driver(adapterDeps),
		clock = deps.clock,
		specFor = specSource(deps.catalog),
		heartbeat = deps.heartbeat,
		log = deps.log,
		activeCap = activeCap,
		scanInterval = config.Doors.ScanInterval,
	})
end

function DoorRuntime.start(deps)
	DoorRuntime.stop()
	if not DoorRuntime.isEnabled(deps and deps.config) then
		return nil
	end
	local controller = DoorRuntime.build(deps)
	if not controller:start() then
		controller:destroy()
		error("door runtime could not connect to its heartbeat")
	end
	active = controller
	return controller
end

function DoorRuntime.stop()
	local controller = active
	active = nil
	if controller then
		controller:destroy()
	end
end

-- The running controller, or nil.
function DoorRuntime.active()
	return active
end

return DoorRuntime
