--[[
	DoorController: runtime orchestration for auto-opening doors (panel door
	plan, docs/panel-door-plan.md). DORMANT: the production bootstrap does not
	create one and BuilderService does not pass one to PlacedItemsWorld, so
	no door behaviour is live.

	Injected:
		core      DoorAutoOpen instance (the single timing authority). Its
		          maxDoors must be at least 2 * activeCap (staging room).
		sensing   { inputs(regs) -> { [coreId] = input } } (DoorSensing)
		driver    { attach(reg), detach(reg), pose(reg, degrees), setCollision(reg, on) }
		clock()   -> seconds (non-finite values make a tick a no-op)
		specFor(itemId) -> door metadata or nil (validated with DoorGeometry;
		          nil or invalid = not a door, left completely alone)
		heartbeat optional signal with :Connect(fn) -> connection:Disconnect()
		log       optional function(message)

	Registrations are keyed by MODEL, not by placement id, so an old model
	and its replacement with the same id (build load, undo, reconcile) never
	share state. Each registration gets a fresh core id "door#<generation>"
	that is never reused; DoorAutoOpen tokens are global too.

	Capacity: at most activeCap (150) COMMITTED doors. A door attached frozen
	by an edit's apply is STAGED and does not count until thaw (commit), so a
	build load can stage a full replacement set beside the frozen old set
	(the core holds up to 2 * activeCap). The world's commit detaches the old
	set before thawing the new one, so a 150-for-150 load fits. If a thaw
	would still exceed activeCap, that door is released and recorded in
	`overflow` (never silently dropped).

	Sensing: a door's cached input is discarded on beginEdit, moved,
	cancelEdit and thaw, so after any edit it waits (holding still) for a
	fresh scan taken at its new pose; a stale result can never start motion
	or restore collision. Frozen and faulted doors are never scanned.

	Poses: every tick, each door's leaf angle is openDegrees * the core's
	linear progress at `now`. There are no tweens and no completion
	callbacks, so there is no easing disagreement and nothing can complete
	twice. `reg.angle` is the last angle the driver ACCEPTED; a failed pose
	leaves it unchanged so the next attempt retries.

	Collision: turned off on every motion, hold or reset event and restored
	to the template's original states only on "collision" or "closed" with
	collide = true (closed and clear).

	Tick order: (1) core events, applying collision disables (prerequisites
	for motion); (2) poses; (3) collision restores, carried out only when the
	leaf's closed pose (angle 0) is CONFIRMED by a successful pose and the
	core is closed and clear. A failed final pose therefore leaves collision
	off.

	Faults: if the driver fails to disable collision, pose the leaf or restore
	collision, the registration is FAULTED. The core is rebased onto the last
	ACCEPTED angle (DoorAutoOpen:holdAt) and held there with collision off, so
	no pose is sent for a motion whose collision could not be disabled and the
	core never believes the leaf is somewhere it isn't. A faulted door gets
	no sensing input. Every scanInterval the controller tries to resync it
	WITHOUT moving it: collision off, then re-apply the last accepted angle.
	Only a fully successful resync clears the fault; the door then stays held
	at that angle until a fresh scan of its sweep allows motion, so recovery
	never jumps along an unscanned or blocked path. beginEdit is edit-critical: if the
	snap closed fails, the door is faulted, its previous edit state is kept
	and the error is raised, so the world's apply fails before it touches the
	model and the existing transaction / reconcile handling takes over.

	Edits (PlacedItemsWorld lifecycle, all no-ops for non-door models):
		attach(model, id, record, frozen)   spawn apply / replace new / reconcile respawn
		beginEdit(model)   before a move, remove or replace-out applies (raises on failure)
		moved(model, record)   after the model's pivot changed
		cancelEdit(model)  rollback: restore the remembered record, thaw
		thaw(model)        commit (spawn / move), or after reconcile
		detach(model)      the model is going away
	A frozen door gets no sensing input, so DoorAutoOpen holds it closed: a
	door reset by an edit cannot reopen before that edit commits or rolls back.

	The module pivot is always computed from the stored placement record by
	the driver, never from the model's current pivot or bounding box.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DoorGeometry = require(ReplicatedStorage:WaitForChild("StudioBuilder"):WaitForChild("DoorGeometry"))

local DoorController = {}
DoorController.__index = DoorController

DoorController.Defaults = {
	scanInterval = 0.25, -- seconds between sensing passes (and fault resync attempts)
	maxInputAge = 1, -- older sensing results count as unknown
	activeCap = 150, -- committed doors
}

local function isFinite(v)
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

function DoorController.new(deps)
	assert(type(deps) == "table", "DoorController.new needs deps")
	for _, key in ipairs({ "core", "sensing", "driver" }) do
		assert(deps[key] ~= nil, "DoorController needs " .. key)
	end
	assert(type(deps.clock) == "function", "DoorController needs clock")
	assert(type(deps.specFor) == "function", "DoorController needs specFor")
	local self = setmetatable({
		core = deps.core,
		sensing = deps.sensing,
		driver = deps.driver,
		clock = deps.clock,
		specFor = deps.specFor,
		heartbeat = deps.heartbeat,
		log = deps.log or function() end,
		byModel = {},
		byCore = {},
		order = {},
		generation = 0,
		committed = 0,
		overflow = {},
		inputs = {},
		inputsAt = nil,
		lastScan = nil,
		destroyed = false,
	}, DoorController)
	for key, default in pairs(DoorController.Defaults) do
		local v = deps[key]
		if v == nil then
			v = default
		end
		assert(isFinite(v) and v > 0, "DoorController: bad " .. key)
		self[key] = v
	end
	assert(type(self.core.maxDoors) == "number" and self.core.maxDoors >= 2 * self.activeCap,
		"DoorController: core.maxDoors must be at least 2 * activeCap for staged replacements")
	return self
end

function DoorController:_now()
	local ok, now = pcall(self.clock)
	if ok and isFinite(now) then
		return now
	end
	return nil
end

-- Calls the driver; returns true on success, false (logged) on failure.
function DoorController:_call(reg, method, ...)
	local ok, err = pcall(self.driver[method], self.driver, reg, ...)
	if not ok then
		self.log("door driver " .. method .. " failed for " .. tostring(reg.id) .. ": " .. tostring(err))
	end
	return ok
end

function DoorController:_forgetInput(reg)
	self.inputs[reg.coreId] = nil
end

-- Marks a registration faulted and rebases the core onto the leaf angle the
-- driver last ACCEPTED (not the core's theoretical progress), held there
-- with collision off. Any later motion starts from that real position and
-- needs a fresh scan.
function DoorController:_fault(reg, reason)
	if not reg.faulted then
		self.log("door " .. tostring(reg.id) .. " faulted: " .. reason)
	end
	reg.faulted = true
	reg.nextResync = nil
	reg.pendingRestore = false
	self:_forgetInput(reg)
	self.core:holdAt(reg.coreId, reg.angle / reg.spec.openDegrees, self:_now())
end

-- Sets reg.record and the derived room-space sweep box and doorway centre.
function DoorController:_place(reg, record)
	reg.record = record
	reg.roomBox = DoorGeometry.toRoom(reg.sweptLocal, record)
	local c = reg.spec.leaf.center
	local x, y, z = DoorGeometry.pointToRoom(c[1], c[2], c[3], record)
	reg.center = x and { x = x, y = y, z = z } or nil
	self:_forgetInput(reg)
end

function DoorController:attach(model, id, record, frozen)
	if self.destroyed or model == nil or self.byModel[model] then
		return self.byModel[model]
	end
	local okSpec, meta = pcall(self.specFor, record and record.itemId)
	if not okSpec or meta == nil then
		return nil
	end
	local spec = DoorGeometry.validate(meta)
	if spec == nil then
		self.log("door spec invalid for " .. tostring(record.itemId) .. "; left static")
		return nil
	end
	local staged = frozen ~= false
	if not staged and self.committed >= self.activeCap then
		self.overflow[model] = id
		self.log("door limit reached; " .. tostring(id) .. " left static")
		return nil
	end
	self.generation = self.generation + 1
	local coreId = "door#" .. self.generation
	if not self.core:add(coreId) then
		self.overflow[model] = id
		self.log("door staging limit reached; " .. tostring(id) .. " left static")
		return nil
	end
	local reg = {
		model = model,
		id = id,
		itemId = record.itemId,
		spec = spec,
		sweptLocal = DoorGeometry.sweptBox(spec),
		coreId = coreId,
		generation = self.generation,
		frozen = staged,
		staged = staged,
		angle = 0,
	}
	self:_place(reg, record)
	if not self:_call(reg, "attach") then
		self.core:remove(coreId)
		return nil
	end
	self.byModel[model] = reg
	self.byCore[coreId] = reg
	self.order[#self.order + 1] = reg
	if not staged then
		self.committed = self.committed + 1
	end
	return reg
end

function DoorController:detach(model)
	if model ~= nil then
		self.overflow[model] = nil
	end
	local reg = model and self.byModel[model]
	if reg == nil then
		return false
	end
	self.byModel[model] = nil
	self.byCore[reg.coreId] = nil
	for i, other in ipairs(self.order) do
		if other == reg then
			table.remove(self.order, i)
			break
		end
	end
	if not reg.staged then
		self.committed = self.committed - 1
	end
	self.inputs[reg.coreId] = nil
	self.core:remove(reg.coreId)
	reg.detached = true
	self:_call(reg, "detach")
	return true
end

-- Snap closed and freeze before an edit. Raises (leaving the previous edit
-- state, faulted) if the driver can't disable collision or close the leaf,
-- so the caller's apply fails before it changes the model.
function DoorController:beginEdit(model)
	local reg = model and self.byModel[model]
	if reg == nil then
		return false
	end
	self:_forgetInput(reg)
	if not self:_call(reg, "setCollision", false) or not self:_call(reg, "pose", 0) then
		self:_fault(reg, "could not snap closed for an edit")
		error("door " .. tostring(reg.id) .. " could not be snapped closed for an edit", 0)
	end
	reg.angle = 0
	if reg.recordBeforeEdit == nil then
		reg.recordBeforeEdit = reg.record
	end
	reg.frozen = true
	self.core:reset(reg.coreId, self:_now())
	return true
end

function DoorController:moved(model, record)
	local reg = model and self.byModel[model]
	if reg == nil then
		return false
	end
	self:_place(reg, record)
	return true
end

function DoorController:cancelEdit(model)
	local reg = model and self.byModel[model]
	if reg == nil then
		return false
	end
	if reg.recordBeforeEdit then
		self:_place(reg, reg.recordBeforeEdit)
	end
	return self:thaw(model)
end

function DoorController:thaw(model)
	local reg = model and self.byModel[model]
	if reg == nil then
		return false
	end
	if reg.staged then
		if self.committed >= self.activeCap then
			self.log("door limit reached at commit; " .. tostring(reg.id) .. " left static")
			local id = reg.id
			self:detach(model)
			self.overflow[model] = id
			return false
		end
		reg.staged = false
		self.committed = self.committed + 1
	end
	reg.recordBeforeEdit = nil
	reg.frozen = false
	self:_forgetInput(reg)
	return true
end

-- Applies one core event BEFORE poses. Collision disables happen now (a
-- failure faults the door, so no pose follows); collision restores are only
-- recorded and carried out after the closed pose is confirmed (see tick).
function DoorController:_apply(event)
	local reg = self.byCore[event.id]
	if reg == nil then
		return
	end
	local kind = event.kind
	if kind == "collision" or (kind == "closed" and event.collide == true) then
		reg.pendingRestore = true
	elseif kind == "opening" or kind == "closing" or kind == "held" or kind == "snapClosed" then
		reg.pendingRestore = false
		if not self:_call(reg, "setCollision", false) then
			self:_fault(reg, "could not disable collision")
		end
	end
end

-- Faulted doors: re-establish a safe, known state WITHOUT moving the leaf:
-- collision off, then re-apply the last accepted angle (the core is already
-- rebased there). Never poses toward the core's theoretical target, so
-- recovery can't sweep an unscanned or blocked path. A failed attempt leaves
-- it faulted until the next attempt (one per scanInterval).
function DoorController:_resync(reg, now)
	if reg.nextResync ~= nil and now < reg.nextResync then
		return
	end
	reg.nextResync = now + self.scanInterval
	if self:_call(reg, "setCollision", false) and self:_call(reg, "pose", reg.angle) then
		reg.faulted = false
		reg.nextResync = nil
		self.log("door " .. tostring(reg.id) .. " recovered at " .. tostring(reg.angle) .. " degrees")
	end
end

function DoorController:tick()
	if self.destroyed then
		return
	end
	local now = self:_now()
	if now == nil then
		return
	end
	local active = {}
	for _, reg in ipairs(self.order) do
		if not reg.frozen and not reg.faulted then
			active[#active + 1] = reg
		end
	end
	if self.lastScan == nil or now - self.lastScan >= self.scanInterval or now < self.lastScan then
		self.lastScan = now
		local okScan, inputs = pcall(self.sensing.inputs, self.sensing, active)
		local scanned = {}
		if okScan and type(inputs) == "table" then
			-- Keep only entries for doors that were scanned (never frozen or faulted ones).
			for _, reg in ipairs(active) do
				scanned[reg.coreId] = inputs[reg.coreId]
			end
		end
		self.inputs = scanned
		self.inputsAt = now
	end
	local fresh = self.inputsAt ~= nil and now - self.inputsAt <= self.maxInputAge and now >= self.inputsAt
	local coreInputs = {}
	if fresh then
		for _, reg in ipairs(active) do
			coreInputs[reg.coreId] = self.inputs[reg.coreId]
		end
	end
	-- 1. Events: collision disables (prerequisites for motion).
	for _, event in ipairs(self.core:update(now, coreInputs)) do
		self:_apply(event)
	end
	-- 2. Poses, then 3. collision restores only once closed is confirmed.
	for _, reg in ipairs(self.order) do
		if reg.faulted then
			self:_resync(reg, now)
		else
			local state = self.core:state(reg.coreId, now)
			if state then
				local angle = reg.spec.openDegrees * state.progress
				if angle ~= reg.angle then
					if self:_call(reg, "pose", angle) then
						reg.angle = angle
					else
						self:_fault(reg, "could not pose the leaf")
					end
				end
			end
			if reg.pendingRestore and not reg.faulted then
				if reg.angle == 0 and state and state.phase == "closed" then
					if self:_call(reg, "setCollision", true) then
						reg.pendingRestore = false
					else
						self:_fault(reg, "could not restore collision")
					end
				else
					reg.pendingRestore = false
					self:_fault(reg, "collision restore requested while the leaf is not confirmed closed")
				end
			end
		end
	end
end

function DoorController:start()
	if self.destroyed or self.connection or self.heartbeat == nil then
		return false
	end
	self.connection = self.heartbeat:Connect(function()
		self:tick()
	end)
	return true
end

function DoorController:stop()
	if self.connection then
		self.connection:Disconnect()
		self.connection = nil
	end
end

-- Stops ticking, returns every door to closed with its original collision
-- (best effort), and releases all registrations. Later calls are no-ops.
function DoorController:destroy()
	self:stop()
	local regs = self.order
	for _, reg in ipairs(regs) do
		self:_call(reg, "pose", 0)
		self:_call(reg, "setCollision", true)
	end
	for i = #regs, 1, -1 do
		self:detach(regs[i].model)
	end
	self.inputs = {}
	self.overflow = {}
	self.destroyed = true
end

function DoorController:count()
	return #self.order
end

function DoorController:committedCount()
	return self.committed
end

function DoorController:registration(model)
	return self.byModel[model]
end

return DoorController
