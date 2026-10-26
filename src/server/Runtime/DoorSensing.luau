--[[
	DoorSensing: turns raw server observations into DoorAutoOpen inputs
	{ nearby, occupied, blocked } for each registered door (panel door plan,
	docs/panel-door-plan.md). Pure logic over two injected queries, so it is
	fully testable with fakes; the Roblox versions live in DoorRuntimeAdapters.
	DORMANT: nothing in the production bootstrap creates it yet.

	Injected:
		getCharacters() -> list of { alive = bool, position = { x, y, z } (room
		    space), model = <character model> }. Raising, returning a non-table
		    or more than maxCharacters entries makes the whole scan UNKNOWN.
		queryBox(roomBox, reg) -> hits, truncated. hits is a list of
		    { model = <top-level model or nil>, solid = bool (the part
		      collides), supportingFloor = bool, maxY = number (room-space
		      top of the part's oriented box) }. Raising, a non-table,
		    truncated = true or more than maxHits hits makes that door UNKNOWN.

	Characters: only entries with alive == true and a finite position inside
	the sandbox bounds plus `margin` count; anything else is skipped (one bad
	entry never makes the scan unknown, a failed or truncated scan does).

	Per door (reg needs coreId, model, roomBox = the conservative whole-sweep
	room box from DoorGeometry, and center = { x, y, z } of the doorway):
	* nearby: a counted character within nearbyRadius (horizontal) of the
	  centre, and within the sweep's height range plus `margin`.
	* each overlap hit is classified, in this order:
		- the owning door model itself (surround, Frame, Leaf): ignored;
		- a living counted character's model: occupied, whether or not that
		  part collides (character parts are often non-collidable);
		- a non-solid part (solid = false: decoration, helper, invisible
		  non-colliding part): ignored, since it can't obstruct the leaf;
		- a solid part flagged supportingFloor that only touches the sweep's
		  bottom (maxY <= roomBox.minY + contactTolerance): ignored;
		- any other solid part, including adjacent walls, other structure,
		  furniture, dead characters and a floor piece that rises into the
		  sweep: blocked.
	  A malformed hit (non-table, `solid` not a boolean, a floor without a
	  finite maxY) makes the door UNKNOWN. Nothing is ignored just because it
	  is structure.
	UNKNOWN doors are simply left out of the returned map; DoorAutoOpen then
	holds them still.
]]

local DoorSensing = {}
DoorSensing.__index = DoorSensing

DoorSensing.Defaults = {
	nearbyRadius = 6,
	margin = 2,
	contactTolerance = 0.05,
	maxCharacters = 64,
	maxHits = 64,
}

local function isFinite(v)
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

-- bounds: { halfX, halfZ, height } of the sandbox.
function DoorSensing.new(deps)
	assert(type(deps) == "table", "DoorSensing.new needs deps")
	assert(type(deps.getCharacters) == "function", "DoorSensing needs getCharacters")
	assert(type(deps.queryBox) == "function", "DoorSensing needs queryBox")
	local b = deps.bounds
	assert(type(b) == "table" and isFinite(b.halfX) and isFinite(b.halfZ) and isFinite(b.height), "DoorSensing needs bounds")
	local self = setmetatable({ getCharacters = deps.getCharacters, queryBox = deps.queryBox, bounds = b }, DoorSensing)
	for key, default in pairs(DoorSensing.Defaults) do
		local v = deps[key]
		if v == nil then
			v = default
		end
		assert(isFinite(v) and v >= 0, "DoorSensing: bad " .. key)
		self[key] = v
	end
	return self
end

local function position3(p)
	return type(p) == "table" and isFinite(p.x) and isFinite(p.y) and isFinite(p.z)
end

-- Returns the counted characters and a set of their models, or nil (unknown).
function DoorSensing:characters()
	local ok, list = pcall(self.getCharacters)
	if not ok or type(list) ~= "table" or #list > self.maxCharacters then
		return nil
	end
	local b, m = self.bounds, self.margin
	local out, models = {}, {}
	for _, c in ipairs(list) do
		if type(c) == "table" and c.alive == true and position3(c.position) then
			local p = c.position
			if math.abs(p.x) <= b.halfX + m and math.abs(p.z) <= b.halfZ + m and p.y >= -m and p.y <= b.height + m then
				out[#out + 1] = c
				if c.model ~= nil then
					models[c.model] = true
				end
			end
		end
	end
	return out, models
end

-- "ignore", "occupied", "blocked", or nil when the hit is malformed.
function DoorSensing:classify(hit, reg, characterModels)
	if type(hit) ~= "table" then
		return nil
	end
	if hit.model ~= nil and hit.model == reg.model then
		return "ignore"
	end
	if hit.model ~= nil and characterModels[hit.model] then
		return "occupied"
	end
	if type(hit.solid) ~= "boolean" then
		return nil
	end
	if not hit.solid then
		return "ignore"
	end
	if hit.supportingFloor == true then
		if not isFinite(hit.maxY) then
			return nil
		end
		if hit.maxY <= reg.roomBox.minY + self.contactTolerance then
			return "ignore"
		end
	end
	return "blocked"
end

-- One door's input, or nil when it can't be determined.
function DoorSensing:inputFor(reg, chars, characterModels)
	local box, c = reg.roomBox, reg.center
	if type(box) ~= "table" or not position3(c) then
		return nil
	end
	local nearby = false
	local r2 = self.nearbyRadius * self.nearbyRadius
	for _, ch in ipairs(chars) do
		local p = ch.position
		local dx, dz = p.x - c.x, p.z - c.z
		if dx * dx + dz * dz <= r2 and p.y >= box.minY - self.margin and p.y <= box.maxY + self.margin then
			nearby = true
			break
		end
	end
	local ok, hits, truncated = pcall(self.queryBox, box, reg)
	if not ok or type(hits) ~= "table" or truncated == true or #hits > self.maxHits then
		return nil
	end
	local occupied, blocked = false, false
	for _, hit in ipairs(hits) do
		local kind = self:classify(hit, reg, characterModels)
		if kind == nil then
			return nil
		end
		occupied = occupied or kind == "occupied"
		blocked = blocked or kind == "blocked"
	end
	return { nearby = nearby, occupied = occupied, blocked = blocked }
end

-- regs: list of active registrations. Returns { [coreId] = input } holding
-- only doors whose input is known.
function DoorSensing:inputs(regs)
	local out = {}
	local chars, models = self:characters()
	if chars == nil then
		return out
	end
	for _, reg in ipairs(regs) do
		local input = self:inputFor(reg, chars, models)
		if input then
			out[reg.coreId] = input
		end
	end
	return out
end

return DoorSensing
