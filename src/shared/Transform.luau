--[[
	Transform: placement maths shared by the server (authoritative) and the
	client preview (advisory). Pure; no Roblox types.

	A transform is { x, y, z, yaw }: studs from the sandbox origin (floor
	centre, +Y up) to the item's bottom-centre pivot, and yaw in degrees.
	Bounds are { halfX, halfZ, height }. Item size is the template's measured
	bounding box { sx, sy, sz } in its own axes. The footprint used for the
	bounds check is the axis-aligned box of the yawed item, so a long item
	that fits along one wall may not fit after a 90 degree turn.
]]

local Validate = require(script.Parent.Validate)

local Transform = {}

local YAW_TOLERANCE = 1e-6
local MAX_ABS_YAW = 3600

local function round(v, step)
	return math.floor(v / step + 0.5) * step
end
Transform.round = round

-- Returns the yaw normalized to [0, 360) on the rotation grid, or nil when it
-- is not (within tolerance) a multiple of step.
function Transform.normalizeYaw(yaw, step)
	local steps = (yaw % 360) / step
	local nearest = math.floor(steps + 0.5)
	if math.abs(steps - nearest) > YAW_TOLERANCE then
		return nil
	end
	local normalized = (nearest * step) % 360
	if normalized >= 360 - YAW_TOLERANCE then
		normalized = 0
	end
	return normalized
end

-- Half extents on the room X and Z axes of a size rotated by yaw degrees.
function Transform.halfExtents(size, yaw)
	local r = math.rad(yaw)
	local c, s = math.abs(math.cos(r)), math.abs(math.sin(r))
	return (c * size[1] + s * size[3]) / 2, (s * size[1] + c * size[3]) / 2
end

function Transform.fits(t, size, bounds, epsilon)
	local hx, hz = Transform.halfExtents(size, t.yaw)
	return math.abs(t.x) + hx <= bounds.halfX + epsilon
		and math.abs(t.z) + hz <= bounds.halfZ + epsilon
		and t.y >= -epsilon
		and t.y + size[2] <= bounds.height + epsilon
end

-- Validates an untrusted transform table. Returns a fresh clean transform, or
-- nil and "BadTransform" (malformed) / "OutOfBounds" (well-formed but outside).
-- Only the four fields are read; key-set strictness is the request validator's job.
function Transform.sanitize(raw, size, bounds, config)
	if type(raw) ~= "table" then
		return nil, "BadTransform"
	end
	local x, y, z, yaw = rawget(raw, "x"), rawget(raw, "y"), rawget(raw, "z"), rawget(raw, "yaw")
	local limit = config.MaxCoordinate
	for _, v in ipairs({ x, y, z }) do
		if not Validate.isFiniteNumber(v) or math.abs(v) > limit then
			return nil, "BadTransform"
		end
	end
	if not Validate.isFiniteNumber(yaw) or math.abs(yaw) > MAX_ABS_YAW then
		return nil, "BadTransform"
	end
	local cleanYaw = Transform.normalizeYaw(yaw, config.RotationStep)
	if cleanYaw == nil then
		return nil, "BadTransform"
	end
	local p = config.PositionPrecision
	local t = { x = round(x, p), y = round(y, p), z = round(z, p), yaw = cleanYaw }
	if not Transform.fits(t, size, bounds, config.BoundsEpsilon) then
		return nil, "OutOfBounds"
	end
	return t
end

return Transform
