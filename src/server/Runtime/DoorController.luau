--[[
	DoorController: runtime orchestration for auto-opening doors (panel door
	plan, docs/panel-door-plan.md). DORMANT: the production bootstrap does not
	create one and BuilderService does not pass one to PlacedItemsWorld, so
	no door behaviour is live.

	Injected:
		core      DoorAutoOpen instance (the single timing authority)
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
	that is never reused; DoorAutoOpen tokens are global too, so nothing from
	an old registration can move a new one.

	Poses: every tick, each door's leaf angle is openDegrees * the core's
	linear progress at `now`, sent to the driver. There are no tweens and no
	completion callbacks, so there is no easing disagreement and nothing can
	complete twice; the core finishes motions by the clock.

	Collision: the driver turns leaf collision off on every motion, hold or
	reset event and restores the template's original states only on
	"collision" or "closed" with collide = true, i.e. closed and clear.

	Edits (PlacedItemsWorld lifecycle, all no-ops for non-door models):
		attach(model, id, record, frozen)   spawn apply / replace new / reconcile respawn
		beginEdit(model)   before a move, remove or replace-out applies: snap
		                   closed, freeze, remember the record
		moved(model, record)   after the model's pivot changed
		cancelEdit(model)  rollback: restore the remembered record, thaw
		thaw(model)        commit (spawn / move), or after reconcile
		detach(model)      the model is going away (rollback of a spawn,
		                   commit of a remove or replace-out, reconcile)
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
	scanInterval = 0.25, -- seconds between sensing passes
	maxInputAge = 1, -- older sensing results count as unknown
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
	return self
end

function DoorController:_call(reg, method, ...)
	local ok, err = pcall(self.driver[method], self.driver, reg, ...)
	if not ok then
		self.log("door driver " .. method .. " failed for " .. tostring(reg.id) .. ": " .. tostring(err))
	end
	return ok
end

-- Sets reg.record and the derived room-space sweep box and doorway centre.
function DoorController:_place(reg, record)
	reg.record = record
	reg.roomBox = DoorGeometry.toRoom(reg.sweptLocal, record)
	local c = reg.spec.leaf.center
	local x, y, z = DoorGeometry.pointToRoom(c[1], c[2], c[3], record)
	reg.center = x and { x = x, y = y, z = z } or nil
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
	self.generation = self.generation + 1
	local coreId = "door#" .. self.generation
	if not self.core:add(coreId) then
		self.log("door limit reached; " .. tostring(id) .. " left static")
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
		frozen = frozen ~= false,
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
	return reg
end

function DoorController:detach(model)
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
	self.core:remove(reg.coreId)
	reg.detached = true
	self:_call(reg, "detach")
	return true
end

-- Snap closed and freeze before an edit. Idempotent: a second beginEdit
-- keeps the record from before the first.
function DoorController:beginEdit(model)
	local reg = model and self.byModel[model]
	if reg == nil then
		return false
	end
	if reg.recordBeforeEdit == nil then
		reg.recordBeforeEdit = reg.record
	end
	reg.frozen = true
	self.core:reset(reg.coreId, self.clock())
	self:_call(reg, "setCollision", false)
	self:_call(reg, "pose", 0)
	reg.angle = 0
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
	reg.recordBeforeEdit = nil
	reg.frozen = false
	return true
end

function DoorController:_apply(event)
	local reg = self.byCore[event.id]
	if reg == nil then
		return
	end
	local kind = event.kind
	if kind == "collision" or (kind == "closed" and event.collide == true) then
		self:_call(reg, "setCollision", true)
	elseif kind == "opening" or kind == "closing" or kind == "held" or kind == "snapClosed" then
		self:_call(reg, "setCollision", false)
	end
end

function DoorController:tick()
	if self.destroyed then
		return
	end
	local okClock, now = pcall(self.clock)
	if not okClock or not isFinite(now) then
		return
	end
	local active = {}
	for _, reg in ipairs(self.order) do
		if not reg.frozen then
			active[#active + 1] = reg
		end
	end
	if self.lastScan == nil or now - self.lastScan >= self.scanInterval or now < self.lastScan then
		self.lastScan = now
		local okScan, inputs = pcall(self.sensing.inputs, self.sensing, active)
		self.inputs = (okScan and type(inputs) == "table") and inputs or {}
		self.inputsAt = now
	end
	local fresh = self.inputsAt ~= nil and now - self.inputsAt <= self.maxInputAge and now >= self.inputsAt
	local coreInputs = {}
	if fresh then
		for _, reg in ipairs(active) do
			coreInputs[reg.coreId] = self.inputs[reg.coreId]
		end
	end
	for _, event in ipairs(self.core:update(now, coreInputs)) do
		self:_apply(event)
	end
	for _, reg in ipairs(self.order) do
		local state = self.core:state(reg.coreId, now)
		if state then
			local angle = reg.spec.openDegrees * state.progress
			if angle ~= reg.angle then
				reg.angle = angle
				self:_call(reg, "pose", angle)
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

-- Stops ticking, returns every door to closed with its original collision,
-- and releases all registrations. Later calls are no-ops.
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
	self.destroyed = true
end

function DoorController:count()
	return #self.order
end

function DoorController:registration(model)
	return self.byModel[model]
end

return DoorController
