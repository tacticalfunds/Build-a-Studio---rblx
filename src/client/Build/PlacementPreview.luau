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
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("StudioBuilder")
local Transform = require(Shared:WaitForChild("Transform"))

local PlacementPreview = {}

PlacementPreview.MinUpDot = 0.7
PlacementPreview.FloorTolerance = 0.5

-- hit: { x, y, z, upDot } in sandbox local space, or nil when nothing was hit.
-- ctx: { size, yaw, bounds, snap, config }
-- Returns { valid, code, transform }; transform is the best guess for drawing
-- the ghost even when invalid (nil when there is no surface).
function PlacementPreview.compute(hit, ctx)
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
