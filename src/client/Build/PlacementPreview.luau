--[[
	PlacementPreview: turns a pointer raycast hit into a candidate transform.
	Pure; the client controller does the raycast and passes the hit in sandbox
	local space. The server re-validates everything.

	* Surface snapping (default): the item sits on whatever it hit, as long as
	  the surface faces up: floor, tabletop or another placed item. Overlaps
	  and floating are allowed by the server, so this only picks a sensible
	  height. Walls and undersides (upDot < MinUpDot) are rejected.
	* Grid snapping (default on): x and z round to Config.GridSize.
	* Tiny negative heights from the floor surface clamp to 0.
	* Bounds and yaw rules come from the shared Transform module, so the preview
	  turns invalid exactly where the server would reject.
	* Structure pieces (ctx.structureKind, task 10) use the shared StructureGrid
	  instead, the same module and code mapping the server uses: the hit's x/z
	  picks the nearest cell centre or cell edge, the level is fixed by kind
	  (floor 0, wall 0, ceiling 15: a floor hit places a ceiling at y 15), yaw
	  is cardinal, and bounds are the supplied sandbox bounds with no overhang.
	  Any hit counts (floor, a wall face, a ceiling top): only x/z are used.
	  Invalid results carry the server's code (OffGrid with a reason, or
	  OutOfBounds) and the projected transform, drawn as an invalid ghost.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("StudioBuilder")
local Transform = require(Shared:WaitForChild("Transform"))
local StructureGrid = require(Shared:WaitForChild("StructureGrid"))

local PlacementPreview = {}

PlacementPreview.MinUpDot = 0.7
PlacementPreview.FloorTolerance = 0.5

local function finite(v)
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function computeStructure(hit, ctx)
	if type(hit) ~= "table" or not finite(hit.x) or not finite(hit.z) then
		return { valid = false, code = "NoSurface" }
	end
	local raw, projectCode = StructureGrid.project(ctx.structureKind, { x = hit.x, z = hit.z }, ctx.yaw)
	if raw == nil then
		local code, reason = StructureGrid.toProtocol(projectCode)
		return { valid = false, code = code, reason = reason }
	end
	local clean, gridCode = StructureGrid.validate(ctx.structureKind, raw, ctx.size, ctx.bounds, {
		maxCoordinate = ctx.config.MaxCoordinate,
		boundsEpsilon = ctx.config.BoundsEpsilon,
	})
	if clean then
		return { valid = true, transform = clean }
	end
	local code, reason = StructureGrid.toProtocol(gridCode)
	return { valid = false, code = code, reason = reason, transform = raw }
end

-- hit: { x, y, z, upDot } in sandbox local space, or nil when nothing was hit.
-- ctx: { size, yaw, bounds, snap, config, structureKind? }
-- Returns { valid, code, reason?, transform }; transform is the best guess for
-- drawing the ghost even when invalid (nil when there is no surface).
function PlacementPreview.compute(hit, ctx)
	if ctx.structureKind ~= nil then
		return computeStructure(hit, ctx)
	end
	if hit == nil or type(hit.upDot) ~= "number" or hit.upDot < PlacementPreview.MinUpDot then
		return { valid = false, code = "NoSurface" }
	end
	local x, y, z = hit.x, hit.y, hit.z
	if ctx.snap then
		local grid = ctx.config.GridSize
		x = Transform.round(x, grid)
		z = Transform.round(z, grid)
	end
	if y < 0 and y > -PlacementPreview.FloorTolerance then
		y = 0
	end
	local raw = { x = x, y = y, z = z, yaw = ctx.yaw }
	local clean, code = Transform.sanitize(raw, ctx.size, ctx.bounds, ctx.config)
	if clean then
		return { valid = true, transform = clean }
	end
	return { valid = false, code = code, transform = raw }
end

return PlacementPreview
