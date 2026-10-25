--[[
	PlacementCore: server-authoritative place / move / rotate / duplicate /
	delete for the single editable sandbox. Pure: every Roblox touch point is
	injected, and any injected call may yield.

	deps = {
		config, catalog,
		templates     = { isInstalled(itemId), getSize(itemId) },   -- TemplateCatalog
		entitlements  = { isItemUnlocked(userId, item, catalog) },  -- Entitlements
		authority     = { check(userId) -> allowed, reason },       -- HostAuthority
		bounds        = { halfX, halfZ, height },                   -- RoomProvider sandbox
		world         = { apply(effect) -> token, rollback(token), commit(token),
		                  reconcile(entries)?, publishRevision(n) }, -- PlacedItemsWorld
		clock         = function() -> seconds,
		log           = function(message) (optional),
	}
	world.apply must leave no change behind when it raises.

	States: "ready" | "busy" | "recovery".
	Per request: rate limit -> strict payload (pure) -> recovery check ->
	take the edit lock (Busy if held) -> host check -> plan (catalog,
	template, entitlement, bounds, cap; no mutation) -> host re-check ->
	world.apply -> host re-check -> commit model + BuildRevision ->
	world.commit (finalize) -> release the lock.
	* The lock is taken before any injected (possibly yielding) dependency and
	  released in exactly one place, for every outcome.
	* Rejections before world.apply leave state, world and revision untouched.
	* After world.apply, a lost host or a model commit error rolls the world
	  back. If that rollback fails, or finalize fails, the core fails closed:
	  it keeps the operation and token, enters "recovery", answers
	  recoveryNeeded=true, and refuses edits until recover() succeeds (retry
	  the operation, then world.reconcile from the model as a fallback).
	* Shared studio: the current host may edit any placed item, whoever placed
	  it (placedByUserId is metadata only). Undo history from a previous host
	  must be invalidated by the undo layer (task 4).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("StudioBuilder")
local Protocol = require(Shared:WaitForChild("Protocol"))
local Transform = require(Shared:WaitForChild("Transform"))
local Validate = require(Shared:WaitForChild("Validate"))

local BuildModel = require(script.Parent.BuildModel)
local RateLimiter = require(script.Parent.RateLimiter)
local RequestValidator = require(script.Parent.RequestValidator)

local Codes = Protocol.Codes

local PlacementCore = {}
PlacementCore.__index = PlacementCore

local READY, BUSY, RECOVERY = "ready", "busy", "recovery"

local REQUIRED = { "config", "catalog", "templates", "entitlements", "authority", "bounds", "world", "clock" }

function PlacementCore.new(deps)
	assert(type(deps) == "table", "PlacementCore.new requires deps")
	for _, name in ipairs(REQUIRED) do
		assert(deps[name] ~= nil, "PlacementCore missing dependency: " .. name)
	end
	local self = setmetatable({}, PlacementCore)
	for k, v in pairs(deps) do
		self[k] = v
	end
	self.model = BuildModel.new(deps.config.MaxItems)
	self.limiter = RateLimiter.new(deps.config.RateLimits, deps.clock)
	self.revision = 0
	self.state = READY
	self.pending = nil -- { token, effect } between world.apply and the model commit
	self.recovery = nil -- { kind = "rollback" | "finalize", token, effect }
	self.recovering = false
	return self
end

function PlacementCore:_log(message)
	if self.log then
		pcall(self.log, message)
	end
end

function PlacementCore:_reject(code)
	return { ok = false, code = code, buildRevision = self.revision }
end

function PlacementCore:_isHost(userId)
	local ok, allowed = pcall(self.authority.check, self.authority, userId)
	return ok and allowed == true
end

function PlacementCore:getRevision()
	return self.revision
end

function PlacementCore:getState()
	return self.state
end

function PlacementCore:getRecovery()
	return self.recovery
end

function PlacementCore:list()
	return self.model:list()
end

-- Catalog, install and entitlement checks for creating an instance of itemId.
function PlacementCore:_checkCreatable(userId, itemId)
	local item = self.catalog.getItem(itemId)
	if item == nil then
		return nil, Codes.UnknownItem
	end
	if not self.templates.isInstalled(itemId) then
		return nil, Codes.NotInstalled
	end
	if not self.entitlements:isItemUnlocked(userId, item, self.catalog) then
		return nil, Codes.NotEntitled
	end
	return item
end

function PlacementCore:_clean(itemId, raw)
	local size = self.templates.getSize(itemId)
	if size == nil then
		return nil, Codes.NotInstalled
	end
	return Transform.sanitize(raw, size, self.bounds, self.config)
end

-- Resolves an existing item. Returns id, record or nil, code.
function PlacementCore:_existing(rawId)
	local id, code = RequestValidator.buildId(rawId)
	if id == nil then
		return nil, code
	end
	local record = self.model:get(id)
	if record == nil then
		return nil, Codes.NotFound
	end
	return id, record
end

local function withTransform(record, t)
	return { itemId = record.itemId, placedByUserId = record.placedByUserId, x = t.x, y = t.y, z = t.z, yaw = t.yaw }
end

local function sameTransform(a, b)
	return a.x == b.x and a.y == b.y and a.z == b.z and a.yaw == b.yaw
end

function PlacementCore:_spawnPlan(record)
	if not self.model:hasCapacity() then
		return nil, Codes.ItemCap
	end
	local id = self.model:peekNextId()
	local model = self.model
	return {
		id = id,
		effect = { kind = "spawn", id = id, record = BuildModel.copyRecord(record) },
		commit = function()
			model:add(id, record)
		end,
	}
end

function PlacementCore:_movePlan(id, before, raw)
	local t, code = self:_clean(before.itemId, raw)
	if t == nil then
		return nil, code
	end
	local after = withTransform(before, t)
	if sameTransform(before, after) then
		return { id = id, noop = true }
	end
	local model = self.model
	return {
		id = id,
		effect = { kind = "move", id = id, from = before, to = BuildModel.copyRecord(after) },
		commit = function()
			model:set(id, after)
		end,
	}
end

local planners = {}

function planners.Place(self, userId, payload)
	local itemId, code = RequestValidator.catalogId(rawget(payload, "itemId"))
	if itemId == nil then
		return nil, code
	end
	local _, itemCode = self:_checkCreatable(userId, itemId)
	if itemCode then
		return nil, itemCode
	end
	local shape, shapeCode = RequestValidator.transformShape(rawget(payload, "transform"))
	if shape == nil then
		return nil, shapeCode
	end
	local t, tCode = self:_clean(itemId, shape)
	if t == nil then
		return nil, tCode
	end
	return self:_spawnPlan({ itemId = itemId, placedByUserId = userId, x = t.x, y = t.y, z = t.z, yaw = t.yaw })
end

function planners.Move(self, _, payload)
	local id, record = self:_existing(rawget(payload, "id"))
	if id == nil then
		return nil, record
	end
	local shape, code = RequestValidator.transformShape(rawget(payload, "transform"))
	if shape == nil then
		return nil, code
	end
	return self:_movePlan(id, record, shape)
end

function planners.Rotate(self, _, payload)
	local id, record = self:_existing(rawget(payload, "id"))
	if id == nil then
		return nil, record
	end
	local direction, code = RequestValidator.direction(rawget(payload, "direction"))
	if direction == nil then
		return nil, code
	end
	local raw = { x = record.x, y = record.y, z = record.z, yaw = record.yaw + direction * self.config.RotationStep }
	return self:_movePlan(id, record, raw)
end

function planners.Duplicate(self, userId, payload)
	local id, source = self:_existing(rawget(payload, "id"))
	if id == nil then
		return nil, source
	end
	local _, itemCode = self:_checkCreatable(userId, source.itemId)
	if itemCode then
		return nil, itemCode
	end
	local size = self.templates.getSize(source.itemId)
	if size == nil then
		return nil, Codes.NotInstalled
	end
	-- Server picks the spot: next to the source on a free side, grid-aligned.
	local hx, hz = Transform.halfExtents(size, source.yaw)
	local grid = self.config.GridSize
	local dx = math.ceil(hx * 2 / grid) * grid
	local dz = math.ceil(hz * 2 / grid) * grid
	for _, offset in ipairs({ { dx, 0 }, { -dx, 0 }, { 0, dz }, { 0, -dz } }) do
		local t = self:_clean(source.itemId, { x = source.x + offset[1], y = source.y, z = source.z + offset[2], yaw = source.yaw })
		if t then
			return self:_spawnPlan({ itemId = source.itemId, placedByUserId = userId, x = t.x, y = t.y, z = t.z, yaw = t.yaw })
		end
	end
	return nil, Codes.OutOfBounds
end

function planners.Delete(self, _, payload)
	local id, record = self:_existing(rawget(payload, "id"))
	if id == nil then
		return nil, record
	end
	local model = self.model
	return {
		id = id,
		effect = { kind = "remove", id = id, record = record },
		commit = function()
			model:remove(id)
		end,
	}
end

function PlacementCore:_enterRecovery(kind, token, effect)
	self.recovery = { kind = kind, token = token, effect = effect }
	self:_log("entering recovery after failed " .. kind .. " of " .. tostring(effect and effect.kind) .. " " .. tostring(effect and effect.id))
end

-- Rolls back the pending world change. Returns a response for `code`.
function PlacementCore:_undoPending(code)
	local pending = self.pending
	self.pending = nil
	local ok, err = pcall(self.world.rollback, self.world, pending.token)
	if ok then
		return self:_reject(code)
	end
	self:_log("world rollback failed: " .. tostring(err))
	self:_enterRecovery("rollback", pending.token, pending.effect)
	local response = self:_reject(code)
	response.recoveryNeeded = true
	return response
end

-- Runs with the edit lock held. Every exit returns a response.
function PlacementCore:_locked(userId, op, payload)
	if not self:_isHost(userId) then
		return self:_reject(Codes.NotHost)
	end
	local plan, planCode = planners[op](self, userId, payload)
	if plan == nil then
		return self:_reject(planCode)
	end
	if plan.noop then
		return { ok = true, id = plan.id, buildRevision = self.revision }
	end
	-- Planning dependencies may have yielded.
	if not self:_isHost(userId) then
		return self:_reject(Codes.AuthorityLost)
	end

	local applied, token = pcall(self.world.apply, self.world, plan.effect)
	if not applied then
		self:_log("world apply failed: " .. tostring(token))
		return self:_reject(Codes.ApplyFailed)
	end
	self.pending = { token = token, effect = plan.effect }

	-- world.apply may yield.
	if not self:_isHost(userId) then
		return self:_undoPending(Codes.AuthorityLost)
	end
	local committed, commitErr = pcall(plan.commit)
	if not committed then
		self:_log("model commit failed: " .. tostring(commitErr))
		return self:_undoPending(Codes.Internal)
	end
	self.pending = nil
	self.revision = self.revision + 1

	local response = { ok = true, id = plan.id, buildRevision = self.revision }
	local finalized, finalizeErr = pcall(self.world.commit, self.world, token)
	if not finalized then
		self:_log("world finalize failed: " .. tostring(finalizeErr))
		self:_enterRecovery("finalize", token, plan.effect)
		response.recoveryNeeded = true
	end
	pcall(self.world.publishRevision, self.world, self.revision)
	return response
end

-- Deterministic reconciliation: retry the retained operation, then fall back
-- to rebuilding the world from the model. Returns true when back to ready.
function PlacementCore:recover()
	if self.state ~= RECOVERY then
		return true
	end
	if self.recovering then
		return false
	end
	self.recovering = true
	local r = self.recovery
	local method = r.kind == "finalize" and self.world.commit or self.world.rollback
	local ok = pcall(method, self.world, r.token)
	if not ok and self.world.reconcile then
		local reconciled, err = pcall(self.world.reconcile, self.world, self.model:list())
		ok = reconciled
		if not reconciled then
			self:_log("world reconcile failed: " .. tostring(err))
		end
	end
	self.recovering = false
	if not ok then
		return false
	end
	self.recovery = nil
	self.state = READY
	pcall(self.world.publishRevision, self.world, self.revision)
	self:_log("recovered")
	return true
end

-- Entry point for one BuilderRequest. Never throws for any payload.
function PlacementCore:handle(userId, payload)
	if not Validate.isPositiveInteger(userId) then
		return self:_reject(Codes.BadRequest)
	end
	if not self.limiter:allow(userId, "edit") then
		return self:_reject(Codes.RateLimited)
	end
	local op, code = RequestValidator.op(payload)
	if op == nil then
		return self:_reject(code)
	end
	if self.state == RECOVERY and not self:recover() then
		return self:_reject(Codes.RecoveryNeeded)
	end
	if self.state ~= READY then
		return self:_reject(Codes.Busy)
	end

	self.state = BUSY
	local ok, response = pcall(self._locked, self, userId, op, payload)
	if not ok then
		self:_log("edit failed: " .. tostring(response))
		if self.pending ~= nil then
			-- Unexpected error after a world change: the world state is unknown.
			self:_enterRecovery("rollback", self.pending.token, self.pending.effect)
			self.pending = nil
		end
		response = self:_reject(Codes.Internal)
		if self.recovery ~= nil then
			response.recoveryNeeded = true
		end
	end
	self.state = self.recovery ~= nil and RECOVERY or READY
	return response
end

return PlacementCore
