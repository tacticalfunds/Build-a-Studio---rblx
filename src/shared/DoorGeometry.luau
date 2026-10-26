--[[
	DoorGeometry: pure swing-volume maths for a hinged door leaf (panel door
	plan, docs/panel-door-plan.md). No Roblox types. NOT referenced by any
	live entry point, the catalog, StructureGrid or the placement path yet.

	Metadata (template-local studs, module pivot at the bottom centre of the
	CLOSED module; the leaf is described closed):
		{
			hinge = { x = n, z = n },                        -- vertical hinge axis
			leaf = { center = { x, y, z }, size = { x, y, z } }, -- closed leaf box, incl. hardware
			swing = "-z",                                    -- side the leaf opens into
			openDegrees = n,                                 -- 0 < n <= 180
		}

	The swept box is EXACT for the closed leaf box rotating about the hinge
	over the whole 0..openDegrees arc, then padded outward by EPSILON. The
	box of a rotating rectangle at any angle is set by its corners, so the
	union over the arc is the box of the four corners' circular arcs: each
	arc contributes its end points plus any axis extreme (+x, +z, -x, -z) it
	passes. Thickness, handles and the hinge-side protrusion are all inside
	the leaf box, so they are covered; nothing assumes a zero-thickness leaf.

	Rotation in the x-z plane: positive angles turn +x toward +z, i.e.
	(x, z) -> (x cos a - z sin a, x sin a + z cos a). The sign is chosen so
	the leaf centre moves toward -z when swing = "-z".

	Room transform follows PlacedItemsWorld: origin * (x, y, z) * Angles(0, yaw, 0),
	so a local (x, z) maps to (x cos yaw + z sin yaw, -x sin yaw + z cos yaw).
	Only cardinal yaws (0, 90, 180, 270) are accepted.
]]

local Validate = require(script.Parent.Validate)

local DoorGeometry = {}

DoorGeometry.EPSILON = 1e-6
DoorGeometry.MAX_EXTENT = 64
DoorGeometry.MIN_HINGE_OFFSET = 0.01

DoorGeometry.Codes = {
	BadDoor = "BadDoor",
	BadTransform = "BadTransform",
	BadYaw = "BadYaw",
	BadBounds = "BadBounds",
	SwingOutOfBounds = "SwingOutOfBounds",
}
local Codes = DoorGeometry.Codes

local function finite(v, limit)
	return Validate.isFiniteNumber(v) and math.abs(v) <= limit
end

local function onlyKeys(t, allowed)
	for key in pairs(t) do
		if not allowed[key] then
			return false
		end
	end
	return true
end

local function vector3(t, positive)
	if type(t) ~= "table" or #t ~= 3 or not onlyKeys(t, { [1] = true, [2] = true, [3] = true }) then
		return nil
	end
	for i = 1, 3 do
		if not finite(t[i], DoorGeometry.MAX_EXTENT) or (positive and t[i] <= 0) then
			return nil
		end
	end
	return { t[1], t[2], t[3] }
end

-- Returns a clean copy of the metadata, or nil and BadDoor.
function DoorGeometry.validate(meta)
	if type(meta) ~= "table" or not onlyKeys(meta, { hinge = true, leaf = true, swing = true, openDegrees = true }) then
		return nil, Codes.BadDoor
	end
	local hinge, leaf = meta.hinge, meta.leaf
	if type(hinge) ~= "table" or not onlyKeys(hinge, { x = true, z = true }) then
		return nil, Codes.BadDoor
	end
	if not finite(hinge.x, DoorGeometry.MAX_EXTENT) or not finite(hinge.z, DoorGeometry.MAX_EXTENT) then
		return nil, Codes.BadDoor
	end
	if type(leaf) ~= "table" or not onlyKeys(leaf, { center = true, size = true }) then
		return nil, Codes.BadDoor
	end
	local center, size = vector3(leaf.center, false), vector3(leaf.size, true)
	if center == nil or size == nil then
		return nil, Codes.BadDoor
	end
	if meta.swing ~= "-z" then
		return nil, Codes.BadDoor
	end
	local open = meta.openDegrees
	if not Validate.isFiniteNumber(open) or open <= 0 or open > 180 then
		return nil, Codes.BadDoor
	end
	local minX, maxX = center[1] - size[1] / 2, center[1] + size[1] / 2
	local minZ, maxZ = center[3] - size[3] / 2, center[3] + size[3] / 2
	-- The hinge axis must pass through the leaf's footprint, away from its centre.
	if hinge.x < minX or hinge.x > maxX or hinge.z < minZ or hinge.z > maxZ then
		return nil, Codes.BadDoor
	end
	if math.abs(center[1] - hinge.x) < DoorGeometry.MIN_HINGE_OFFSET then
		return nil, Codes.BadDoor
	end
	if center[2] - size[2] / 2 < 0 then
		return nil, Codes.BadDoor
	end
	return {
		hinge = { x = hinge.x, z = hinge.z },
		leaf = { center = center, size = size },
		swing = "-z",
		openDegrees = open,
	}
end

-- +1 or -1: the rotation sign (in this module's x -> +z convention) that
-- moves the leaf centre toward -z. A Roblox driver turning the leaf with
-- CFrame.Angles(0, a, 0) must use a = -sign * angle, because Roblox's
-- positive yaw turns +x toward -z.
local function swingSign(clean)
	return (clean.leaf.center[1] < clean.hinge.x) and 1 or -1
end
DoorGeometry.swingSign = swingSign

local function leafCorners(clean)
	local c, s = clean.leaf.center, clean.leaf.size
	local hx, hz = s[1] / 2, s[3] / 2
	return {
		{ c[1] - hx, c[3] - hz },
		{ c[1] + hx, c[3] - hz },
		{ c[1] + hx, c[3] + hz },
		{ c[1] - hx, c[3] + hz },
	}
end

local function rotateAbout(px, pz, ox, oz, radians)
	local dx, dz = px - ox, pz - oz
	local co, si = math.cos(radians), math.sin(radians)
	return ox + dx * co - dz * si, oz + dx * si + dz * co
end

-- Leaf footprint corners (template-local x, z) at a given opening angle in
-- degrees. Exposed for tests and the later runtime tween; clamps nothing.
function DoorGeometry.leafCornersAt(clean, degrees)
	local radians = swingSign(clean) * math.rad(degrees)
	local out = {}
	for i, p in ipairs(leafCorners(clean)) do
		local x, z = rotateAbout(p[1], p[2], clean.hinge.x, clean.hinge.z, radians)
		out[i] = { x, z }
	end
	return out
end

-- Counter-clockwise (+angle) turn in [0, 2pi) from vector u to direction d.
local function ccwAngle(ux, uz, dx, dz)
	local r = math.sqrt(ux * ux + uz * uz)
	local cosine = math.max(-1, math.min(1, (ux * dx + uz * dz) / r))
	local a = math.acos(cosine)
	if ux * dz - uz * dx < 0 then
		a = 2 * math.pi - a
	end
	return a
end

local AXES = { { 1, 0 }, { 0, 1 }, { -1, 0 }, { 0, -1 } }

-- Exact box (padded by EPSILON) of the leaf over the whole arc, template-local:
-- { minX, maxX, minY, maxY, minZ, maxZ }.
function DoorGeometry.sweptBox(clean)
	local sign = swingSign(clean)
	local sweep = math.rad(clean.openDegrees)
	local ox, oz = clean.hinge.x, clean.hinge.z
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	local function include(x, z)
		minX, maxX = math.min(minX, x), math.max(maxX, x)
		minZ, maxZ = math.min(minZ, z), math.max(maxZ, z)
	end
	for _, p in ipairs(leafCorners(clean)) do
		include(p[1], p[2])
		include(rotateAbout(p[1], p[2], ox, oz, sign * sweep))
		local ux, uz = p[1] - ox, p[2] - oz
		local r = math.sqrt(ux * ux + uz * uz)
		if r > 0 then
			for _, d in ipairs(AXES) do
				local a = ccwAngle(ux, uz, d[1], d[2])
				local along = (sign > 0) and a or ((2 * math.pi - a) % (2 * math.pi))
				if along <= sweep then
					include(ox + d[1] * r, oz + d[2] * r)
				end
			end
		end
	end
	local e = DoorGeometry.EPSILON
	local c, s = clean.leaf.center, clean.leaf.size
	return {
		minX = minX - e,
		maxX = maxX + e,
		minY = c[2] - s[2] / 2 - e,
		maxY = c[2] + s[2] / 2 + e,
		minZ = minZ - e,
		maxZ = maxZ + e,
	}
end

local CARDINAL = { [0] = { 1, 0 }, [90] = { 0, 1 }, [180] = { -1, 0 }, [270] = { 0, -1 } }

local function cardinal(yaw)
	if not Validate.isFiniteNumber(yaw) then
		return nil
	end
	local y = yaw % 360
	if y == 0 or y == 90 or y == 180 or y == 270 then
		return y
	end
	return nil
end

-- Room-space box of a template-local box under a placement transform
-- { x, y, z, yaw } (cardinal yaw only). Returns box or nil, code.
function DoorGeometry.toRoom(box, t)
	if type(t) ~= "table" then
		return nil, Codes.BadTransform
	end
	local x, y, z = t.x, t.y, t.z
	if not (Validate.isFiniteNumber(x) and Validate.isFiniteNumber(y) and Validate.isFiniteNumber(z)) then
		return nil, Codes.BadTransform
	end
	local yaw = cardinal(t.yaw)
	if yaw == nil then
		return nil, Codes.BadYaw
	end
	-- Exact cosines and sines for cardinal yaws, so boxes stay exact.
	local co, si = CARDINAL[yaw][1], CARDINAL[yaw][2]
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, lx in ipairs({ box.minX, box.maxX }) do
		for _, lz in ipairs({ box.minZ, box.maxZ }) do
			local wx = x + lx * co + lz * si
			local wz = z - lx * si + lz * co
			minX, maxX = math.min(minX, wx), math.max(maxX, wx)
			minZ, maxZ = math.min(minZ, wz), math.max(maxZ, wz)
		end
	end
	return { minX = minX, maxX = maxX, minY = y + box.minY, maxY = y + box.maxY, minZ = minZ, maxZ = maxZ }
end

-- Room-space position of a template-local point (x, y, z) under a placement
-- transform (cardinal yaw only). Returns x, y, z or nil, code.
function DoorGeometry.pointToRoom(px, py, pz, t)
	local room, code = DoorGeometry.toRoom({ minX = px, maxX = px, minY = py, maxY = py, minZ = pz, maxZ = pz }, t)
	if room == nil then
		return nil, code
	end
	return room.minX, room.minY, room.minZ
end

-- True when a room-space box lies inside bounds { halfX, halfZ, height }
-- (centred on the sandbox origin, floor at y = 0), within epsilon.
function DoorGeometry.fits(roomBox, bounds, epsilon)
	epsilon = epsilon or 0
	return roomBox.minX >= -bounds.halfX - epsilon
		and roomBox.maxX <= bounds.halfX + epsilon
		and roomBox.minZ >= -bounds.halfZ - epsilon
		and roomBox.maxZ <= bounds.halfZ + epsilon
		and roomBox.minY >= -epsilon
		and roomBox.maxY <= bounds.height + epsilon
end

-- Full check: metadata, transform and bounds. Returns the room-space swept
-- box, or nil and a code (BadDoor, BadTransform, BadYaw, BadBounds, SwingOutOfBounds).
function DoorGeometry.check(meta, t, bounds, epsilon)
	local clean, code = DoorGeometry.validate(meta)
	if clean == nil then
		return nil, code
	end
	if type(bounds) ~= "table" then
		return nil, Codes.BadBounds
	end
	for _, key in ipairs({ "halfX", "halfZ", "height" }) do
		if not Validate.isFiniteNumber(bounds[key]) or bounds[key] <= 0 then
			return nil, Codes.BadBounds
		end
	end
	local room, roomCode = DoorGeometry.toRoom(DoorGeometry.sweptBox(clean), t)
	if room == nil then
		return nil, roomCode
	end
	if not DoorGeometry.fits(room, bounds, epsilon or 0.001) then
		return nil, Codes.SwingOutOfBounds
	end
	return room
end

return DoorGeometry
