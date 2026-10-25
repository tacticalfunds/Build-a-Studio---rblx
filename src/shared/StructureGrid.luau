--[[
	StructureGrid: pure placement maths for modular 16-stud structure pieces
	(task 10 foundation). No Roblox types; nothing calls this yet. It is NOT
	wired into PlacementCore, the preview, the drawer or the catalog.

	Decisions (review of b14edfd, measured in Studio by Codex):
	* D1 The sandbox origin is a cell CENTRE. Cell centres sit at x, z = 16*i;
	  cell edges at x, z = 8 + 16*i (i any integer, negative included).
	* D2 Bounds are whatever the caller supplies; there is no overhang
	  allowance. A 16 x 15 x 1 wall on the outer edge at +/-24 needs
	  halfX/halfZ >= 24.5 (a future 49 x 24 x 49 marker); the live 48 x 24 x 48
	  marker refuses it with OutOfBounds.
	* D3 Levels (y of the bottom-centre pivot): floor 0 (top 1), wall 0
	  (top 15), ceiling 15 (top 16).
	* Kinds covered: floor, ceiling (cell kinds) and wall, window_wall,
	  doorway (edge kinds). Corner and the standalone window frame are
	  deferred until their geometry is validated (D6, D7).

	Edge pieces have their length along local X: yaw 0/180 means the piece
	lies along X on an edge line z = 8 + 16k with x at a cell centre;
	yaw 90/270 means it lies along Z on an edge line x = 8 + 16k with z at a
	cell centre. Yaw is cardinal only (0, 90, 180, 270).

	Ties (a point exactly halfway) always round toward +infinity, matching
	Transform.round, so the result never depends on the sign of the input.

	Error codes are distinct from bounds: BadKind, BadTransform, BadSize,
	BadYaw, BadLevel, OffGrid, then OutOfBounds from the shared bounds check.
]]

local Transform = require(script.Parent.Transform)
local Validate = require(script.Parent.Validate)

local StructureGrid = {}

StructureGrid.PITCH = 16
StructureGrid.HALF = 8
StructureGrid.YAW_STEP = 90
-- Accepted distance from the exact grid value (server positions are 0.01-quantized).
StructureGrid.TOLERANCE = 0.01

StructureGrid.Kinds = {
	floor = { placement = "cell", level = 0 },
	ceiling = { placement = "cell", level = 15 },
	wall = { placement = "edge", level = 0 },
	window_wall = { placement = "edge", level = 0 },
	doorway = { placement = "edge", level = 0 },
}

StructureGrid.Codes = {
	BadKind = "BadKind",
	BadTransform = "BadTransform",
	BadSize = "BadSize",
	BadYaw = "BadYaw",
	BadLevel = "BadLevel",
	OffGrid = "OffGrid",
	OutOfBounds = "OutOfBounds",
}
local Codes = StructureGrid.Codes

local PITCH, HALF = StructureGrid.PITCH, StructureGrid.HALF

local function isCoordinate(v, limit)
	return Validate.isFiniteNumber(v) and math.abs(v) <= limit
end

-- Nearest cell centre (16*i); ties toward +infinity.
function StructureGrid.snapCentre(v)
	return math.floor(v / PITCH + 0.5) * PITCH
end

-- Nearest edge line (8 + 16*k); ties toward +infinity.
function StructureGrid.snapEdge(v)
	return math.floor((v - HALF) / PITCH + 0.5) * PITCH + HALF
end

local function near(a, b)
	return math.abs(a - b) <= StructureGrid.TOLERANCE
end

-- "x" when the edge piece lies along X (yaw 0/180), "z" for 90/270.
function StructureGrid.edgeAxis(yaw)
	if yaw == 0 or yaw == 180 then
		return "x"
	end
	return "z"
end

function StructureGrid.cardinalYaw(yaw)
	if not Validate.isFiniteNumber(yaw) then
		return nil
	end
	return Transform.normalizeYaw(yaw, StructureGrid.YAW_STEP)
end

local function checkSize(size)
	if type(size) ~= "table" then
		return false
	end
	for i = 1, 3 do
		if not Validate.isFiniteNumber(size[i]) or size[i] <= 0 then
			return false
		end
	end
	return true
end

local function checkBounds(bounds)
	return type(bounds) == "table" and Validate.isFiniteNumber(bounds.halfX) and Validate.isFiniteNumber(bounds.halfZ)
		and Validate.isFiniteNumber(bounds.height) and bounds.halfX > 0 and bounds.halfZ > 0 and bounds.height > 0
end

--[[
	Validates a structure transform. kind: a StructureGrid.Kinds key.
	t: { x, y, z, yaw } (untrusted). size: template { sx, sy, sz }.
	bounds: { halfX, halfZ, height }. options.maxCoordinate and
	options.boundsEpsilon are optional (defaults 1024 and 0.001).
	Returns a fresh transform snapped exactly onto the grid, or nil, code.
]]
function StructureGrid.validate(kind, t, size, bounds, options)
	options = options or {}
	local spec = type(kind) == "string" and StructureGrid.Kinds[kind] or nil
	if spec == nil then
		return nil, Codes.BadKind
	end
	if type(t) ~= "table" then
		return nil, Codes.BadTransform
	end
	local limit = options.maxCoordinate or 1024
	local x, y, z, yaw = rawget(t, "x"), rawget(t, "y"), rawget(t, "z"), rawget(t, "yaw")
	-- Explicit per-field checks (ipairs over { x, y, z } stops at the first nil).
	if not (isCoordinate(x, limit) and isCoordinate(y, limit) and isCoordinate(z, limit)) then
		return nil, Codes.BadTransform
	end
	if not Validate.isFiniteNumber(yaw) or math.abs(yaw) > 3600 then
		return nil, Codes.BadTransform
	end
	if not checkSize(size) or not checkBounds(bounds) then
		return nil, Codes.BadSize
	end
	local cleanYaw = StructureGrid.cardinalYaw(yaw)
	if cleanYaw == nil then
		return nil, Codes.BadYaw
	end
	if not near(y, spec.level) then
		return nil, Codes.BadLevel
	end
	local gx, gz
	if spec.placement == "cell" then
		gx, gz = StructureGrid.snapCentre(x), StructureGrid.snapCentre(z)
	elseif StructureGrid.edgeAxis(cleanYaw) == "x" then
		gx, gz = StructureGrid.snapCentre(x), StructureGrid.snapEdge(z)
	else
		gx, gz = StructureGrid.snapEdge(x), StructureGrid.snapCentre(z)
	end
	if not near(x, gx) or not near(z, gz) then
		return nil, Codes.OffGrid
	end
	local clean = { x = gx, y = spec.level, z = gz, yaw = cleanYaw }
	if not Transform.fits(clean, size, bounds, options.boundsEpsilon or 0.001) then
		return nil, Codes.OutOfBounds
	end
	return clean
end

--[[
	Projects a floor hit { x, z } (sandbox local) onto the grid for kind.
	preferredYaw (optional, cardinal) keeps the caller's facing: for cell
	kinds it is used as is; for edge kinds the nearest edge decides the axis,
	and a preferred yaw of 180 or 270 keeps the flipped facing on that axis.
	Edge choice: the nearer of the nearest X-axis edge (z on an edge line) and
	the nearest Z-axis edge (x on an edge line); a tie picks the X-axis edge.
	Returns an unvalidated { x, y, z, yaw } (run validate for bounds), or
	nil, code for bad input.
]]
function StructureGrid.project(kind, hit, preferredYaw)
	local spec = type(kind) == "string" and StructureGrid.Kinds[kind] or nil
	if spec == nil then
		return nil, Codes.BadKind
	end
	if type(hit) ~= "table" or not Validate.isFiniteNumber(hit.x) or not Validate.isFiniteNumber(hit.z) then
		return nil, Codes.BadTransform
	end
	local yaw = 0
	if preferredYaw ~= nil then
		yaw = StructureGrid.cardinalYaw(preferredYaw)
		if yaw == nil then
			return nil, Codes.BadYaw
		end
	end
	if spec.placement == "cell" then
		return { x = StructureGrid.snapCentre(hit.x), y = spec.level, z = StructureGrid.snapCentre(hit.z), yaw = yaw }
	end
	local flipped = yaw == 180 or yaw == 270
	local edgeZ = StructureGrid.snapEdge(hit.z)
	local edgeX = StructureGrid.snapEdge(hit.x)
	if math.abs(hit.z - edgeZ) <= math.abs(hit.x - edgeX) then
		return { x = StructureGrid.snapCentre(hit.x), y = spec.level, z = edgeZ, yaw = flipped and 180 or 0 }
	end
	return { x = edgeX, y = spec.level, z = StructureGrid.snapCentre(hit.z), yaw = flipped and 270 or 90 }
end

--[[
	Rotate proposal (NOT wired into PlacementCore planners).
	Turning an edge piece 90 degrees in place would put a perpendicular piece
	at the old edge centre, which is off-grid. Instead the piece hinges at
	one of its end points (always a grid corner, (8+16a, 8+16b)) and extends
	along the new axis, so the result is on-grid by construction.
	Candidates are tried in a fixed order and the first that validates wins:
		direction +1: hinge at the end with the larger coordinate along the
		              old axis, extend toward +new axis; then toward -; then
		              the other end, + then -.
		direction -1: the smaller end first, extend toward -, then +; then
		              the larger end, - then +.
	Cell pieces keep their position and only turn. Returns a clean transform
	or nil, code (OutOfBounds only when every candidate is out of bounds).
]]
function StructureGrid.rotate(kind, t, direction, size, bounds, options)
	if direction ~= 1 and direction ~= -1 then
		return nil, Codes.BadTransform
	end
	local current, code = StructureGrid.validate(kind, t, size, bounds, options)
	if current == nil then
		return nil, code
	end
	local newYaw = (current.yaw + direction * StructureGrid.YAW_STEP) % 360
	local spec = StructureGrid.Kinds[kind]
	if spec.placement == "cell" then
		return StructureGrid.validate(kind, { x = current.x, y = current.y, z = current.z, yaw = newYaw }, size, bounds, options)
	end
	local ends
	if StructureGrid.edgeAxis(current.yaw) == "x" then
		ends = { { current.x - HALF, current.z }, { current.x + HALF, current.z } }
	else
		ends = { { current.x, current.z - HALF }, { current.x, current.z + HALF } }
	end
	local hinges = direction == 1 and { ends[2], ends[1] } or { ends[1], ends[2] }
	local signs = direction == 1 and { 1, -1 } or { -1, 1 }
	local newAxis = StructureGrid.edgeAxis(newYaw)
	local lastCode = Codes.OutOfBounds
	for _, hinge in ipairs(hinges) do
		for _, sign in ipairs(signs) do
			local candidate
			if newAxis == "x" then
				candidate = { x = hinge[1] + sign * HALF, y = current.y, z = hinge[2], yaw = newYaw }
			else
				candidate = { x = hinge[1], y = current.y, z = hinge[2] + sign * HALF, yaw = newYaw }
			end
			local clean, candidateCode = StructureGrid.validate(kind, candidate, size, bounds, options)
			if clean then
				return clean
			end
			lastCode = candidateCode
		end
	end
	return nil, lastCode
end

return StructureGrid
