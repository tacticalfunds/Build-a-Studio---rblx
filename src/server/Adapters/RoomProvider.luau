--[[
	RoomProvider: resolves the editable sandbox for a player.

	The prototype builds only in a separate sandbox; the six existing rooms are
	never offered. The resolver is injected:

		resolve(player) -> {
			id = "sandbox_main",          -- stable string ID
			origin = CFrame,              -- floor centre, +Y up (opaque to pure code)
			bounds = { halfX = 20, halfZ = 20, height = 16 },  -- studs
		} or nil

	Results are validated before use; anything malformed means "no sandbox".
	Default live source: RoomProvider.markerSource() reads an anchored marker
	part named Config.SandboxMarkerName at the top level of Workspace (its
	volume is the build volume). Studio integration pending.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("StudioBuilder")
local Config = require(Shared:WaitForChild("Config"))
local Validate = require(Shared:WaitForChild("Validate"))

local RoomProvider = {}
RoomProvider.__index = RoomProvider

local function defaultIsOrigin(value)
	return typeof ~= nil and typeof(value) == "CFrame"
end

-- options.resolve: function(player) -> descriptor|nil
-- options.isOrigin: function(value) -> boolean (optional; defaults to a CFrame check)
function RoomProvider.new(options)
	assert(type(options) == "table" and type(options.resolve) == "function", "RoomProvider.new requires resolve")
	return setmetatable({
		resolver = options.resolve,
		isOrigin = options.isOrigin or defaultIsOrigin,
	}, RoomProvider)
end

local function validBounds(b)
	if type(b) ~= "table" then
		return false
	end
	for _, key in ipairs({ "halfX", "halfZ", "height" }) do
		local v = b[key]
		if not Validate.isFiniteNumber(v) or v <= 0 or v > Config.MaxCoordinate then
			return false
		end
	end
	return true
end

-- Returns a clean descriptor or nil, reason.
function RoomProvider:resolve(player)
	local ok, d = pcall(self.resolver, player)
	if not ok then
		return nil, "ResolverError"
	end
	if d == nil then
		return nil, "NoSandbox"
	end
	if type(d) ~= "table" or not Validate.isBoundedString(d.id, 64) or not validBounds(d.bounds) or not self.isOrigin(d.origin) then
		return nil, "InvalidSandbox"
	end
	return {
		id = d.id,
		origin = d.origin,
		bounds = { halfX = d.bounds.halfX, halfZ = d.bounds.halfZ, height = d.bounds.height },
	}
end

-- Default live source (Roblox only; Studio integration pending).
function RoomProvider.markerSource()
	local Workspace = game:GetService("Workspace")
	return function()
		local marker = Workspace:FindFirstChild(Config.SandboxMarkerName)
		if marker == nil or not marker:IsA("BasePart") then
			return nil
		end
		local size = marker.Size
		return {
			id = "marker:" .. marker.Name,
			origin = marker.CFrame * CFrame.new(0, -size.Y / 2, 0),
			bounds = { halfX = size.X / 2, halfZ = size.Z / 2, height = size.Y },
		}
	end
end

return RoomProvider
