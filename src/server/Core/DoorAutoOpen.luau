--[[
	DoorAutoOpen: pure auto-open state machine for hinged doors (panel door
	plan, docs/panel-door-plan.md). No Roblox types, no clock of its own:
	callers pass `now` (seconds). NOT referenced by any live entry point yet.

	Per door, a phase and a leaf progress (0 = closed, 1 = open):
		closed   at rest closed; `collidable` says whether closed collision is on
		opening  moving toward 1 (collision off)
		open     at rest open (collision off)
		closing  moving toward 0 (collision off)
		held     stopped part-way because motion could not be proven safe (collision off)

	update(now, inputs) reads one input per door, inputs[id] = {
		nearby   = boolean: a living player is close enough to want it open,
		occupied = boolean: an avatar is in the doorway or the leaf's sweep,
		blocked  = boolean: a solid obstruction (not the door's own parts or its
		           supporting floor) is anywhere in the leaf's sweep,
	}. The input is VALID only when it is a table holding exactly these three
	booleans. Anything else (missing, wrong types, extra keys) is UNKNOWN.

	Safety rule: the leaf only moves when the whole sweep is known clear of
	solid obstructions, i.e. a valid input with blocked = false. Unknown or
	blocked input never starts, continues or reverses a motion:
	* a moving leaf stops where it is (held, collision off);
	* a closed, open or held leaf stays put; an open leaf's exit timer restarts;
	* closed collision is never restored on unknown input.
	The whole-sweep `blocked` flag cannot tell the opening path from the
	closing path, so a blocked door holds rather than guessing which way is
	clear.

	With valid, unblocked input:
	* closed: nearby -> open; otherwise restore closed collision once the
	  doorway is not occupied.
	* opening: finish at full travel (avatars are not solid; collision is off).
	* open: nearby or occupied -> stay open; otherwise close after exitDelay
	  seconds of being clear.
	* closing: nearby or occupied -> reopen from where it is (the return path
	  is known clear); otherwise finish closed, with collision.
	* held: nearby or occupied -> open; otherwise close.
	Motions finish by the clock at t0 + duration (within TOLERANCE), so float
	rounding never leaves a leaf a hair short of its end.

	Clock: nothing happens until the first finite `now`. A non-finite `now`
	makes update() a no-op; an earlier finite `now` is clamped to the last one.

	Tokens are drawn from one counter shared by every door and never reused,
	not even when an id is removed and added again. complete(id, token, now)
	accepts only the current motion's token, so an old callback can never move
	a door or its replacement. Every update returns at most one event per
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

local INPUT_KEYS = { nearby = true, occupied = true, blocked = true }

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
	self.now = nil -- no valid clock yet
	self.lastToken = 0
	return self
end

-- A fresh token, unique across every door and registration.
function DoorAutoOpen:_token()
	self.lastToken = self.lastToken + 1
	return self.lastToken
end

-- Returns the clock to use, or nil when no valid time is known.
function DoorAutoOpen:_clock(now)
	if not isFinite(now) then
		return nil
	end
	if self.now == nil or now > self.now then
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
	self.doors[id] = { phase = "closed", progress = 0, token = self:_token(), collidable = true }
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
	if m == nil or now == nil then
		return door.progress
	end
	local seconds = (m.to > m.from) and self.openSeconds or self.closeSeconds
	local moved = math.max(0, now - m.t0) / seconds
	if m.to > m.from then
		return math.min(m.to, m.from + moved)
	end
	return math.max(m.to, m.from - moved)
end

function DoorAutoOpen:_done(door, now)
	return now >= door.motion.t0 + door.motion.duration - DoorAutoOpen.TOLERANCE
end

function DoorAutoOpen:_start(id, door, to, now)
	local from = self:_progress(door, now)
	local seconds = (to == 1) and self.openSeconds or self.closeSeconds
	local duration = math.abs(to - from) * seconds
	door.token = self:_token()
	door.motion = { from = from, to = to, t0 = now, duration = duration }
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

function DoorAutoOpen:_hold(id, door, now)
	door.progress = self:_progress(door, now)
	door.motion = nil
	door.token = self:_token()
	door.phase = "held"
	door.collidable = false
	return { kind = "held", id = id, token = door.token, progress = door.progress }
end

-- Returns valid, nearby, occupied, blocked.
local function readInput(input)
	if type(input) ~= "table" then
		return false
	end
	for key in pairs(input) do
		if not INPUT_KEYS[key] then
			return false
		end
	end
	if type(input.nearby) ~= "boolean" or type(input.occupied) ~= "boolean" or type(input.blocked) ~= "boolean" then
		return false
	end
	return true, input.nearby, input.occupied, input.blocked
end

function DoorAutoOpen:_step(id, door, now, input)
	local valid, nearby, occupied, blocked = readInput(input)
	local phase = door.phase
	-- Unknown or blocked: no motion may start, continue or reverse.
	if not valid or blocked then
		if phase == "opening" or phase == "closing" then
			return self:_hold(id, door, now)
		end
		if phase == "open" then
			door.clearSince = nil
		end
		return nil
	end
	if phase == "closed" then
		if nearby then
			return self:_start(id, door, 1, now)
		end
		if not door.collidable and not occupied then
			door.collidable = true
			return { kind = "collision", id = id, token = door.token, collide = true }
		end
		return nil
	elseif phase == "opening" then
		if self:_done(door, now) then
			return self:_finish(id, door, false)
		end
		return nil
	elseif phase == "open" then
		if nearby or occupied then
			door.clearSince = nil
			return nil
		end
		door.clearSince = door.clearSince or now
		if now - door.clearSince >= self.exitDelay - DoorAutoOpen.TOLERANCE then
			return self:_start(id, door, 0, now)
		end
		return nil
	elseif phase == "closing" then
		if nearby or occupied then
			return self:_start(id, door, 1, now)
		end
		if self:_done(door, now) then
			return self:_finish(id, door, true)
		end
		return nil
	elseif phase == "held" then
		return self:_start(id, door, (nearby or occupied) and 1 or 0, now)
	end
	return nil
end

-- Advances every door. inputs: { [id] = { nearby, occupied, blocked } }.
-- Returns a list with at most one event per door; empty until a valid clock.
function DoorAutoOpen:update(now, inputs)
	now = self:_clock(now)
	if now == nil then
		return {}
	end
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
-- Collision is not restored here (no inputs); the next valid update does that.
function DoorAutoOpen:complete(id, token, now)
	local door = self.doors[id]
	if door == nil or door.motion == nil or token ~= door.token then
		return nil
	end
	self:_clock(now)
	return self:_finish(id, door, false)
end

-- Stop a moving leaf where it is (for example when the runtime could not
-- apply a prerequisite such as disabling collision). Returns the "held"
-- event, or nil when nothing was moving or the clock is unknown.
function DoorAutoOpen:hold(id, now)
	local door = self.doors[id]
	if door == nil or door.motion == nil then
		return nil
	end
	now = self:_clock(now) or self.now
	if now == nil then
		return nil
	end
	return self:_hold(id, door, now)
end

-- Snap closed now (before any edit to the door: move, rotate, delete,
-- rollback, reconcile, reload). Invalidates in-flight motions. Collision
-- returns only once a later valid update sees the doorway clear.
function DoorAutoOpen:reset(id, now)
	local door = self.doors[id]
	if door == nil then
		return nil, Codes.Unknown
	end
	self:_clock(now)
	door.token = self:_token()
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
	local t = self.now
	if isFinite(now) and (t == nil or now > t) then
		t = now
	end
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
