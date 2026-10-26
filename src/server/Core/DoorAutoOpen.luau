--[[
	DoorAutoOpen: pure auto-open state machine for hinged doors (panel door
	plan, docs/panel-door-plan.md). No Roblox types, no clock of its own:
	callers pass `now` (seconds). NOT referenced by any live entry point yet.

	Per door, a phase and a leaf progress (0 = closed, 1 = open):
		closed   at rest closed; `collidable` says whether closed collision is on
		opening  moving toward 1 (collision off)
		open     at rest open (collision off)
		closing  moving toward 0 (collision off)
		held     stopped part-way by a solid obstruction (collision off)

	update(now, inputs) reads one input per door, inputs[id] = {
		nearby   = true when a living player is close enough to want it open,
		occupied = true when an avatar is in the doorway or the leaf's sweep,
		blocked  = true when a solid obstruction (not the door's own parts or
		           the floor) is in the leaf's sweep,
	}. A missing or malformed input is treated as blocked (hold still):
	nothing moves on data the adapter did not supply.

	Rules:
	* closed: blocked -> stay closed; else nearby -> open. Closed collision
	  comes back only when neither occupied nor blocked.
	* opening: a fresh opening (from closed or held-closing) holds where it
	  is when blocked; a reopen that reverses a closing retraces space the
	  leaf has just swept, so it keeps going. Either finishes at full travel.
	* open: nearby, occupied or blocked -> stay open; else close after
	  exitDelay seconds of being clear.
	* closing: nearby, occupied or blocked -> reopen from where it is; else
	  finish closed (with collision, since it is clear).
	* held: blocked -> stay; else reopen if nearby or occupied, otherwise close.
	Motions finish by the clock at t0 + duration (within TOLERANCE), so float
	rounding never leaves a leaf a hair short of its end.

	Each motion has a token. complete(id, token, now) lets a runtime tween
	report it finished; stale tokens (after a reversal, hold, reset or remove)
	are ignored, so an old callback can never move a door. update() also
	finishes motions by the clock. Every call returns at most one event per
	door, in insertion order: { kind, id, token, ... } with kind one of
	"opening", "opened", "closing", "closed", "held", "collision", "snapClosed".
]]

local DoorAutoOpen = {}
DoorAutoOpen.__index = DoorAutoOpen

DoorAutoOpen.TOLERANCE = 1e-9

DoorAutoOpen.Defaults = {
	openSeconds = 0.6, -- full closed -> open travel
	closeSeconds = 0.6, -- full open -> closed travel
	exitDelay = 2, -- seconds clear before closing
	maxDoors = 150,
}

DoorAutoOpen.Codes = {
	BadId = "BadId",
	Duplicate = "Duplicate",
	TooMany = "TooMany",
	Unknown = "Unknown",
}
local Codes = DoorAutoOpen.Codes

local function isFinite(v)
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

function DoorAutoOpen.new(config)
	config = config or {}
	local self = setmetatable({}, DoorAutoOpen)
	for key, default in pairs(DoorAutoOpen.Defaults) do
		local v = config[key]
		if v == nil then
			v = default
		end
		assert(isFinite(v) and v > 0, "DoorAutoOpen: bad " .. key)
		self[key] = v
	end
	self.doors = {}
	self.order = {}
	self.now = -math.huge
	return self
end

-- Clock: finite and never moving backwards.
function DoorAutoOpen:_clock(now)
	if isFinite(now) and now > self.now then
		self.now = now
	end
	return self.now
end

function DoorAutoOpen:add(id)
	if type(id) ~= "string" or #id == 0 or #id > 64 then
		return nil, Codes.BadId
	end
	if self.doors[id] then
		return nil, Codes.Duplicate
	end
	if #self.order >= self.maxDoors then
		return nil, Codes.TooMany
	end
	self.doors[id] = { phase = "closed", progress = 0, token = 0, collidable = true }
	self.order[#self.order + 1] = id
	return true
end

function DoorAutoOpen:remove(id)
	if not self.doors[id] then
		return false
	end
	self.doors[id] = nil
	for i, other in ipairs(self.order) do
		if other == id then
			table.remove(self.order, i)
			break
		end
	end
	return true
end

function DoorAutoOpen:_progress(door, now)
	local m = door.motion
	if m == nil then
		return door.progress
	end
	local seconds = (m.to > m.from) and self.openSeconds or self.closeSeconds
	local moved = (now - m.t0) / seconds
	if m.to > m.from then
		return math.min(m.to, m.from + moved)
	end
	return math.max(m.to, m.from - moved)
end

function DoorAutoOpen:_start(id, door, to, now, retreat)
	local from = self:_progress(door, now)
	local seconds = (to == 1) and self.openSeconds or self.closeSeconds
	local duration = math.abs(to - from) * seconds
	door.token = door.token + 1
	door.motion = { from = from, to = to, t0 = now, duration = duration, retreat = retreat == true }
	door.progress = from
	door.phase = (to == 1) and "opening" or "closing"
	door.collidable = false
	door.clearSince = nil
	return { kind = door.phase, id = id, token = door.token, from = from, to = to, duration = duration }
end

function DoorAutoOpen:_finish(id, door, collide)
	door.progress = door.motion.to
	door.motion = nil
	if door.progress == 1 then
		door.phase = "open"
		door.clearSince = nil
		return { kind = "opened", id = id, token = door.token }
	end
	door.phase = "closed"
	door.collidable = collide
	return { kind = "closed", id = id, token = door.token, collide = collide }
end

function DoorAutoOpen:_done(door, now)
	return now >= door.motion.t0 + door.motion.duration - DoorAutoOpen.TOLERANCE
end

function DoorAutoOpen:_hold(id, door, now)
	door.progress = self:_progress(door, now)
	door.motion = nil
	door.token = door.token + 1
	door.phase = "held"
	return { kind = "held", id = id, token = door.token, progress = door.progress }
end

local function readInput(input)
	if type(input) ~= "table" then
		return false, false, true
	end
	local nearby = input.nearby == true
	local occupied = input.occupied == true
	local blocked = input.blocked ~= false
	return nearby, occupied, blocked
end

function DoorAutoOpen:_step(id, door, now, input)
	local nearby, occupied, blocked = readInput(input)
	local phase = door.phase
	if phase == "closed" then
		if blocked then
			return nil
		end
		if nearby then
			return self:_start(id, door, 1, now)
		end
		if not door.collidable and not occupied then
			door.collidable = true
			return { kind = "collision", id = id, token = door.token, collide = true }
		end
		return nil
	elseif phase == "opening" then
		if blocked and not door.motion.retreat then
			return self:_hold(id, door, now)
		end
		if self:_done(door, now) then
			return self:_finish(id, door, false)
		end
		return nil
	elseif phase == "open" then
		if nearby or occupied or blocked then
			door.clearSince = nil
			return nil
		end
		door.clearSince = door.clearSince or now
		if now - door.clearSince >= self.exitDelay - DoorAutoOpen.TOLERANCE then
			return self:_start(id, door, 0, now)
		end
		return nil
	elseif phase == "closing" then
		if nearby or occupied or blocked then
			return self:_start(id, door, 1, now, true)
		end
		if self:_done(door, now) then
			return self:_finish(id, door, true)
		end
		return nil
	elseif phase == "held" then
		if blocked then
			return nil
		end
		return self:_start(id, door, (nearby or occupied) and 1 or 0, now)
	end
	return nil
end

-- Advances every door. inputs: { [id] = { nearby, occupied, blocked } }.
-- Returns a list with at most one event per door.
function DoorAutoOpen:update(now, inputs)
	now = self:_clock(now)
	if type(inputs) ~= "table" then
		inputs = {}
	end
	local events = {}
	for _, id in ipairs(self.order) do
		local event = self:_step(id, self.doors[id], now, inputs[id])
		if event then
			events[#events + 1] = event
		end
	end
	return events
end

-- A runtime tween finished. Only the current motion's token is accepted.
-- Collision is not restored here (no inputs); the next update does that.
function DoorAutoOpen:complete(id, token, now)
	local door = self.doors[id]
	if door == nil or door.motion == nil or token ~= door.token then
		return nil
	end
	self:_clock(now)
	return self:_finish(id, door, false)
end

-- Snap closed now (before any edit to the door: move, rotate, delete,
-- rollback, reload). Invalidates in-flight motions. Collision returns only
-- once a later update sees the doorway clear.
function DoorAutoOpen:reset(id, now)
	local door = self.doors[id]
	if door == nil then
		return nil, Codes.Unknown
	end
	self:_clock(now)
	door.token = door.token + 1
	door.motion = nil
	door.progress = 0
	door.phase = "closed"
	door.collidable = false
	door.clearSince = nil
	return { kind = "snapClosed", id = id, token = door.token }
end

-- Read-only snapshot for tests and diagnostics.
function DoorAutoOpen:state(id, now)
	local door = self.doors[id]
	if door == nil then
		return nil
	end
	local t = isFinite(now) and math.max(now, self.now) or self.now
	return {
		phase = door.phase,
		progress = self:_progress(door, t),
		collidable = door.collidable,
		token = door.token,
	}
end

function DoorAutoOpen:count()
	return #self.order
end

return DoorAutoOpen
