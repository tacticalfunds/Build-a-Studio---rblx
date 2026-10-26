--[[
	DoorRuntimeAdapters: the Roblox-facing pieces behind DoorSensing and
	DoorController (panel door plan). Built only by DoorRuntime, which
	BuilderService calls only when Config.Doors.Enabled is true (false by
	default). Roblox types are injected (deps.CFrame, deps.Vector3,
	deps.OverlapParams, deps.workspace, deps.Players, deps.Enum), so tests
	can drive them with fakes; defaults use the real globals when present.

	characters(): every Player's Character with a Humanoid of Health > 0 and
	a HumanoidRootPart, as { alive, position (room space), model }. Positions
	are converted with origin:PointToObjectSpace; DoorSensing validates them.

	queryBox(roomBox, reg): GetPartBoundsInBox over the room-space box (as an
	axis-aligned box in the sandbox frame) with MaxParts = maxHits. Returns
	hits and truncated = (#parts >= maxHits). Each hit names its top-level
	model: a placed item (direct child of the placed-items folder) or a
	character model, so DoorSensing can ignore the owning door and count
	avatars. deps.exclude (optional list of Instances, e.g. the sandbox
	marker part, which is a build volume and never an obstruction) is left
	out of the query with an Exclude filter. solid = part.CanCollide. supportingFloor comes from
	deps.isSupportingFloor(part, model). maxY is the top of the part's
	ORIENTED box in room space: centre y + the half-extents projected onto the
	room's up axis (|R10| sx + |R11| sy + |R12| sz) / 2 from the part's
	room-relative CFrame, so a rotated part's top is never underestimated.

	driver: records the leaf's closed offset from the module pivot and each
	leaf part's original CanCollide at attach (the template is closed then).
	pose(reg, degrees) pivots the Leaf to
		module * hinge * Angles(0, -sign * angle, 0) * hinge:Inverse() * closedOffset
	where module is ALWAYS origin * (x, y, z) * Angles(0, yaw) from the stored
	record, never the model's current pivot or bounding box. setCollision
	restores the original states (on) or turns every leaf part off.
]]

local DoorGeometry = require(game:GetService("ReplicatedStorage"):WaitForChild("StudioBuilder"):WaitForChild("DoorGeometry"))

local DoorRuntimeAdapters = {}

local function defaults(deps)
	return {
		CFrame = deps.CFrame or CFrame,
		Vector3 = deps.Vector3 or Vector3,
		OverlapParams = deps.OverlapParams or OverlapParams,
		workspace = deps.workspace or workspace,
		Players = deps.Players or game:GetService("Players"),
		Enum = deps.Enum or Enum,
	}
end

local function moduleCFrame(lib, origin, record)
	return origin * lib.CFrame.new(record.x, record.y, record.z) * lib.CFrame.Angles(0, math.rad(record.yaw), 0)
end

function DoorRuntimeAdapters.characters(deps)
	local lib = defaults(deps)
	local origin = deps.origin
	return function()
		local out = {}
		for _, player in ipairs(lib.Players:GetPlayers()) do
			local character = player.Character
			if character then
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				local root = character:FindFirstChild("HumanoidRootPart")
				if humanoid and root then
					local p = origin:PointToObjectSpace(root.Position)
					out[#out + 1] = { alive = humanoid.Health > 0, position = { x = p.X, y = p.Y, z = p.Z }, model = character }
				end
			end
		end
		return out
	end
end

-- Top-level model for a hit part: the placed item under `folder`, else the
-- outermost ancestor Model (a character, a room model), else nil.
local function topModel(part, folder)
	local node, outer = part.Parent, nil
	while node ~= nil and node ~= folder do
		if node.Parent == folder then
			return node
		end
		if node:IsA("Model") then
			outer = node
		end
		node = node.Parent
	end
	return outer
end

function DoorRuntimeAdapters.queryBox(deps)
	local lib = defaults(deps)
	local origin, folder, maxHits = deps.origin, deps.folder, deps.maxHits or 64
	local isSupportingFloor = deps.isSupportingFloor or function()
		return false
	end
	return function(box)
		local cx, cy, cz = (box.minX + box.maxX) / 2, (box.minY + box.maxY) / 2, (box.minZ + box.maxZ) / 2
		local size = lib.Vector3.new(box.maxX - box.minX, box.maxY - box.minY, box.maxZ - box.minZ)
		local params = lib.OverlapParams.new()
		params.MaxParts = maxHits
		if deps.exclude ~= nil then
			params.FilterType = lib.Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = deps.exclude
		end
		local parts = lib.workspace:GetPartBoundsInBox(origin * lib.CFrame.new(cx, cy, cz), size, params)
		local hits = {}
		for _, part in ipairs(parts) do
			local model = topModel(part, folder)
			local _, cy, _, _, _, _, r10, r11, r12 = origin:ToObjectSpace(part.CFrame):GetComponents()
			local s = part.Size
			local top = cy + (math.abs(r10) * s.X + math.abs(r11) * s.Y + math.abs(r12) * s.Z) / 2
			hits[#hits + 1] = {
				model = model,
				solid = part.CanCollide == true,
				supportingFloor = isSupportingFloor(part, model) == true,
				maxY = top,
			}
		end
		return hits, #parts >= maxHits
	end
end

function DoorRuntimeAdapters.driver(deps)
	local lib = defaults(deps)
	local origin = deps.origin
	local driver = {}

	local function leafOf(reg)
		local leaf = reg.model:FindFirstChild("Leaf")
		if leaf == nil then
			error("door model has no Leaf")
		end
		return leaf
	end

	function driver:attach(reg)
		local leaf = leafOf(reg)
		local module = moduleCFrame(lib, origin, reg.record)
		reg.leafOffset = module:ToObjectSpace(leaf:GetPivot())
		reg.collision = {}
		for _, d in ipairs(leaf:GetDescendants()) do
			if d:IsA("BasePart") then
				reg.collision[#reg.collision + 1] = { part = d, canCollide = d.CanCollide }
			end
		end
	end

	function driver:detach(reg)
		reg.collision = nil
		reg.leafOffset = nil
	end

	function driver:pose(reg, degrees)
		local leaf = leafOf(reg)
		local hinge = lib.CFrame.new(reg.spec.hinge.x, 0, reg.spec.hinge.z)
		local turn = lib.CFrame.Angles(0, -DoorGeometry.swingSign(reg.spec) * math.rad(degrees), 0)
		local module = moduleCFrame(lib, origin, reg.record)
		leaf:PivotTo(module * hinge * turn * hinge:Inverse() * reg.leafOffset)
	end

	function driver:setCollision(reg, on)
		for _, entry in ipairs(reg.collision or {}) do
			entry.part.CanCollide = on and entry.canCollide or false
		end
	end

	return driver
end

return DoorRuntimeAdapters
