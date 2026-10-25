--[[
	PlacementCore: server-authoritative place / move / rotate / duplicate /
	delete for the single editable sandbox. Pure: every Roblox touch point is
	injected, and any injected call may yield.

	deps = {
		config, catalog,
		templates     = { isInstalled(itemId), getSize(itemId) },   -- TemplateCatalog
		entitlements  = { isItemUnlocked(userId, item, catalog) },  -- Entitlements
		authority     = { check(userId) -> allowed, reason,          -- HostAuthority
		                  currentHostUserId() -> id? (optional) },
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
	  it (placedByUserId is metadata only).
	* Undo/Redo are planners like any other op: same lock, host checks,
	  validation (catalog, template, entitlement, bounds, cap), world
	  apply/rollback and recovery. They restore exact logical IDs. A step that
	  no longer applies (item changed, template removed, collection locked) is
	  dropped with HistoryConflict and never touches the world. History is
	  cleared on host transfer, on any revision change it did not make, and on
	  entering recovery. Undo/Redo may carry expectedRevision (StaleRevision).
	* Host sessions: onHostChanged() (wired to PodcastSettings.HostUserId)
	  bumps a host epoch and clears history at once, so A -> B -> A ends A's
	  old history even with no edit in between. Every request also compares
	  authority.currentHostUserId() with the last seen host, in case a signal
	  was missed. The epoch is captured with the lock and re-checked with the
	  host after every possibly-yielding step; a change aborts (rollback) with
	  AuthorityLost. Status offers undo/redo only to the current host.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("StudioBuilder")
local Protocol = require(Shared:WaitForChild("Protocol"))
local Transform = require(Shared:WaitForChild("Transform"))
local Validate = require(Shared:WaitForChild("Validate"))

local SaveSnapshot = require(script.Parent.Parent:WaitForChild("Adapters"):WaitForChild("SaveSnapshot"))
local BuildHistory = require(script.Parent.BuildHistory)
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
	self.preserved = {} -- saved entries that can't be placed right now; written back on save
	self.history = BuildHistory.new(deps.config.HistoryLimit or 50)
	self.limiter = RateLimiter.new(deps.config.RateLimits, deps.clock)
	self.revision = 0
	self.state = READY
	self.pending = nil -- { token, effect } between world.apply and the model commit
	self.recovery = nil -- { kind = "rollback" | "finalize", token, effect }
	self.recovering = false
	self.hostEpoch = 0
	self.lastSeenHost = self:_currentHost()
	return self
end

function PlacementCore:_currentHost()
	if self.authority.currentHostUserId == nil then
		return nil
	end
	local ok, hostUserId = pcall(self.authority.currentHostUserId, self.authority)
	return ok and hostUserId or nil
end

-- Runtime notification that PodcastSettings.HostUserId changed.
function PlacementCore:onHostChanged()
	self.hostEpoch = self.hostEpoch + 1
	self.lastSeenHost = self:_currentHost()
	self.history:clear(self.revision)
end

-- Fallback for a missed notification: compare with the last seen host.
function PlacementCore:_observeHost()
	if self.authority.currentHostUserId == nil then
		return
	end
	if self:_currentHost() ~= self.lastSeenHost then
		self:onHostChanged()
	end
end

-- Host check bound to the host session captured when the lock was taken.
-- Authority reads may yield, so the epoch is compared LAST, after every
-- possibly-yielding read; a transfer during those reads (A -> B -> A) bumps
-- the epoch and is caught.
function PlacementCore:_stillAuthorized(userId, epoch)
	local allowed = self:_isHost(userId)
	self:_observeHost()
	return allowed and self.hostEpoch == epoch
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

-- Status for userId; attached to every response.
function PlacementCore:status(userId)
	local authorized = self:_isHost(userId)
	return {
		state = self.state,
		canUndo = authorized and self.history:canUndo(userId, self.revision, self.hostEpoch),
		canRedo = authorized and self.history:canRedo(userId, self.revision, self.hostEpoch),
		revision = self.revision,
	}
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

local function sameRecord(a, b)
	return a.itemId == b.itemId and sameTransform(a, b)
end

-- History entry describing a committed effect (exact logical ID).
local function entryFromEffect(effect)
	if effect.kind == "move" then
		return { kind = "move", id = effect.id, before = BuildModel.copyRecord(effect.from), after = BuildModel.copyRecord(effect.to) }
	end
	return { kind = effect.kind, id = effect.id, record = BuildModel.copyRecord(effect.record) }
end

-- id is optional: a new ID is allocated unless an exact one is restored (redo/undo).
function PlacementCore:_spawnPlan(record, id)
	if not self.model:hasCapacity() then
		return nil, Codes.ItemCap
	end
	id = id or self.model:peekNextId()
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

-- Plans one undo or redo step. A step that no longer applies comes back as
-- { conflict = code } so the caller drops it without touching the world.
function PlacementCore:_historyPlan(userId, direction)
	local entry = self.history:peek(direction)
	if entry == nil then
		return nil, direction == "undo" and Codes.NothingToUndo or Codes.NothingToRedo
	end
	local current = self.model:get(entry.id)
	local removing = (entry.kind == "spawn" and direction == "undo") or (entry.kind == "remove" and direction == "redo")
	local creating = (entry.kind == "remove" and direction == "undo") or (entry.kind == "spawn" and direction == "redo")
	local plan, code
	if removing then
		if current == nil or not sameRecord(current, entry.record) then
			return { conflict = Codes.NotFound }
		end
		plan = planners.Delete(self, userId, { id = entry.id })
	elseif creating then
		if current ~= nil then
			return { conflict = Codes.HistoryConflict }
		end
		local _, itemCode = self:_checkCreatable(userId, entry.record.itemId)
		if itemCode then
			return { conflict = itemCode }
		end
		local t, tCode = self:_clean(entry.record.itemId, entry.record)
		if t == nil then
			return { conflict = tCode }
		end
		plan, code = self:_spawnPlan(withTransform(entry.record, t), entry.id)
	else
		local expected = direction == "undo" and entry.after or entry.before
		local target = direction == "undo" and entry.before or entry.after
		if current == nil or not sameRecord(current, expected) then
			return { conflict = Codes.NotFound }
		end
		plan, code = self:_movePlan(entry.id, current, target)
	end
	if plan == nil then
		return { conflict = code }
	end
	local history = self.history
	plan.afterCommit = function(revision)
		history:commitStep(direction, revision)
	end
	return plan
end

function planners.Undo(self, userId)
	return self:_historyPlan(userId, "undo")
end

function planners.Redo(self, userId)
	return self:_historyPlan(userId, "redo")
end

function PlacementCore:_enterRecovery(kind, token, effect)
	self.recovery = { kind = kind, token = token, effect = effect }
	-- The world may differ from what history describes.
	self.history:clear(self.revision)
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
	local epoch = self.hostEpoch
	if op == "Undo" or op == "Redo" then
		local valid, expected = RequestValidator.optionalRevision(rawget(payload, "expectedRevision"))
		if not valid then
			return self:_reject(Codes.BadRequest)
		end
		if expected ~= nil and expected ~= self.revision then
			return self:_reject(Codes.StaleRevision)
		end
	end
	-- History belongs to one host at one revision (host transfer, recovery or
	-- a future load invalidate it).
	self.history:sync(userId, self.revision, epoch)
	local plan, planCode = planners[op](self, userId, payload)
	if plan == nil then
		return self:_reject(planCode)
	end
	if plan.conflict then
		self.history:drop(op == "Undo" and "undo" or "redo")
		local response = self:_reject(Codes.HistoryConflict)
		response.reason = plan.conflict
		return response
	end
	if plan.noop then
		return { ok = true, id = plan.id, buildRevision = self.revision }
	end
	return self:_executePlan(userId, epoch, plan)
end

-- Shared tail for every mutation (edits, undo/redo, build loads): host + epoch
-- re-check, world apply, re-check, model commit, revision, finalize. Runs with
-- the edit lock held.
function PlacementCore:_executePlan(userId, epoch, plan)
	-- Planning dependencies may have yielded.
	if not self:_stillAuthorized(userId, epoch) then
		return self:_reject(Codes.AuthorityLost)
	end

	local applied, token = pcall(self.world.apply, self.world, plan.effect)
	if not applied then
		self:_log("world apply failed: " .. tostring(token))
		return self:_reject(Codes.ApplyFailed)
	end
	self.pending = { token = token, effect = plan.effect }

	-- world.apply may yield.
	if not self:_stillAuthorized(userId, epoch) then
		return self:_undoPending(Codes.AuthorityLost)
	end
	local committed, commitErr = pcall(plan.commit)
	if not committed then
		self:_log("model commit failed: " .. tostring(commitErr))
		return self:_undoPending(Codes.Internal)
	end
	self.pending = nil
	self.revision = self.revision + 1
	if plan.afterCommit then
		plan.afterCommit(self.revision)
	else
		self.history:record(entryFromEffect(plan.effect), self.revision)
	end

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
	self:_observeHost()
	local op, code = RequestValidator.op(payload)
	local category = op == "Status" and "status" or "edit"
	if not self.limiter:allow(userId, category) then
		return self:_respond(userId, self:_reject(Codes.RateLimited))
	end
	if op == nil then
		return self:_respond(userId, self:_reject(code))
	end
	if op == "Status" then
		return self:_respond(userId, { ok = true, buildRevision = self.revision })
	end
	return self:_respond(userId, self:_handleEdit(userId, op, payload))
end

function PlacementCore:_respond(userId, response)
	response.status = self:status(userId)
	return response
end

function PlacementCore:_handleEdit(userId, op, payload)
	return self:_exclusive(function()
		return self:_locked(userId, op, payload)
	end)
end

-- Runs body with the edit lock held; every mutation goes through here.
function PlacementCore:_exclusive(body)
	if self.state == RECOVERY and not self:recover() then
		return self:_reject(Codes.RecoveryNeeded)
	end
	if self.state ~= READY then
		return self:_reject(Codes.Busy)
	end

	self.state = BUSY
	local ok, response = pcall(body)
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

-- Persistence (task 5) -------------------------------------------------------

local function entryOf(id, r)
	return { id = id, itemId = r.itemId, x = r.x, y = r.y, z = r.z, yaw = r.yaw }
end

-- The current build as a Build section (SaveSnapshot shape), preserved
-- entries included. Synchronous; refuses while an edit or load is in flight
-- (Busy) or the world is unreconciled (RecoveryNeeded), so a save never
-- captures a half-applied build.
function PlacementCore:captureBuild()
	if self.state == RECOVERY then
		return nil, Codes.RecoveryNeeded
	end
	if self.state ~= READY then
		return nil, Codes.Busy
	end
	local items = {}
	for _, e in ipairs(self.model:list()) do
		items[#items + 1] = entryOf(e.id, e.record)
	end
	local section = SaveSnapshot.encode({ nextId = self.model.nextId, items = items, preserved = self.preserved })
	local fits, code = SaveSnapshot.checkSize(section)
	if not fits then
		return nil, code
	end
	return section
end

-- Validates and stages a Build section without mutating anything. Entries
-- that can't be placed now (unknown/retired/uninstalled/locked item, outside
-- the current bounds) are preserved, never dropped. Returns a plan or nil, code
-- (Corrupt, UnsupportedVersion).
function PlacementCore:prepareLoad(userId, section)
	local decoded, code = SaveSnapshot.decode(section, {
		maxItems = self.config.MaxItems,
		classify = function(entry)
			local _, itemCode = self:_checkCreatable(userId, entry.itemId)
			if itemCode then
				return false
			end
			return self:_clean(entry.itemId, entry) ~= nil
		end,
	})
	if decoded == nil then
		return nil, code
	end
	local entries = {}
	for _, e in ipairs(decoded.items) do
		local t = self:_clean(e.itemId, e)
		if t == nil then
			return nil, Codes.OutOfBounds -- classify accepted it; defensive
		end
		entries[#entries + 1] = { id = e.id, record = { itemId = e.itemId, x = t.x, y = t.y, z = t.z, yaw = t.yaw } }
	end
	return { entries = entries, preserved = decoded.preserved, nextId = decoded.nextId }
end

-- Replaces the whole build with a staged plan through the same exclusive path
-- as edits: lock, host + epoch re-checks after every yield, two-phase world
-- "replace" with rollback, recovery on failed rollback/finalize. History is
-- cleared on success. expectedRevision (optional) is checked under the lock.
-- Returns { ok, code?, buildRevision }. Single-shot build-only load; compound
-- room + build loads use beginTransaction instead.
function PlacementCore:loadBuild(userId, plan, expectedRevision)
	if not Validate.isPositiveInteger(userId) or type(plan) ~= "table" then
		return self:_reject(Codes.BadRequest)
	end
	self:_observeHost()
	return self:_exclusive(function()
		if not self:_isHost(userId) then
			return self:_reject(Codes.NotHost)
		end
		if expectedRevision ~= nil and expectedRevision ~= self.revision then
			return self:_reject(Codes.StaleRevision)
		end
		local epoch = self.hostEpoch
		local previous = { entries = self.model:list() }
		local model = BuildModel.new(self.config.MaxItems)
		model:setReserved(#plan.preserved)
		for _, e in ipairs(plan.entries) do
			local r = e.record
			model:add(e.id, { itemId = r.itemId, placedByUserId = r.placedByUserId or userId, x = r.x, y = r.y, z = r.z, yaw = r.yaw })
		end
		-- IDs are never reused within a server, even across loads.
		model:reserveIdsThrough(math.max(plan.nextId, self.model.nextId) - 1)
		local core = self
		local response = self:_executePlan(userId, epoch, {
			effect = { kind = "replace", id = "*", entries = model:list(), previous = previous.entries },
			commit = function()
				core.model = model
				core.preserved = plan.preserved
			end,
			afterCommit = function(revision)
				core.history:clear(revision)
			end,
		})
		return response
	end)
end

-- Binding captured when a load is prepared: the host session and build
-- revision it was validated against.
function PlacementCore:binding()
	return { epoch = self.hostEpoch, revision = self.revision }
end

-- Compound loads (room + build) hold the edit lock for their whole duration.
-- beginTransaction refuses unless the host, host epoch and (when given) build
-- revision still match the preparation binding. The returned transaction must
-- end with exactly one commit() or rollback(); until then edits and saves get
-- Busy. Returns txn or nil, code.
local Transaction = {}
Transaction.__index = Transaction

function PlacementCore:beginTransaction(userId, binding)
	self:_observeHost()
	if self.state == RECOVERY and not self:recover() then
		return nil, Codes.RecoveryNeeded
	end
	if self.state ~= READY then
		return nil, Codes.Busy
	end
	if not self:_isHost(userId) then
		return nil, Codes.NotHost
	end
	if type(binding) ~= "table" or binding.epoch ~= self.hostEpoch then
		return nil, Codes.AuthorityLost
	end
	if binding.revision ~= nil and binding.revision ~= self.revision then
		return nil, Codes.StaleRevision
	end
	self.state = BUSY
	return setmetatable({ core = self, userId = userId, epoch = self.hostEpoch, done = false }, Transaction)
end

-- Final authority check after any yield: same host and same host session.
function Transaction:stillAuthorized()
	return self.core:_stillAuthorized(self.userId, self.epoch)
end

-- Swaps the world to the staged build (two-phase; may yield). The model is
-- committed only by commit(). Returns ok, code.
function Transaction:applyBuild(plan)
	assert(not self.done and self.token == nil, "transaction already applied or ended")
	local core = self.core
	local model = BuildModel.new(core.config.MaxItems)
	model:setReserved(#plan.preserved)
	for _, e in ipairs(plan.entries) do
		local r = e.record
		model:add(e.id, { itemId = r.itemId, placedByUserId = r.placedByUserId or self.userId, x = r.x, y = r.y, z = r.z, yaw = r.yaw })
	end
	model:reserveIdsThrough(math.max(plan.nextId, core.model.nextId) - 1)
	local effect = { kind = "replace", id = "*", entries = model:list(), previous = core.model:list() }
	local ok, token = pcall(core.world.apply, core.world, effect)
	if not ok then
		core:_log("world replace failed: " .. tostring(token))
		return false, Codes.ApplyFailed
	end
	self.token, self.effect, self.model, self.preserved = token, effect, model, plan.preserved
	return true
end

function Transaction:_release()
	self.done = true
	local core = self.core
	core.state = core.recovery ~= nil and RECOVERY or READY
end

-- Commits the applied build (if any) and releases the lock. Never throws.
-- Returns { ok = true, buildRevision, recoveryNeeded? }.
function Transaction:commit()
	assert(not self.done, "transaction already ended")
	local core = self.core
	local response = { ok = true, buildRevision = core.revision }
	if self.token ~= nil then
		core.model = self.model
		core.preserved = self.preserved
		core.revision = core.revision + 1
		core.history:clear(core.revision)
		response.buildRevision = core.revision
		local finalized, err = pcall(core.world.commit, core.world, self.token)
		if not finalized then
			core:_log("world finalize failed: " .. tostring(err))
			core:_enterRecovery("finalize", self.token, self.effect)
			response.recoveryNeeded = true
		end
		pcall(core.world.publishRevision, core.world, core.revision)
	end
	self:_release()
	return response
end

-- Restores the world to the previous build (the model was never changed) and
-- releases the lock. A failed world rollback fails closed: recovery state,
-- edits and saves refused until reconciled. Returns ok.
function Transaction:rollback()
	assert(not self.done, "transaction already ended")
	local core = self.core
	local ok = true
	if self.token ~= nil then
		local rolledBack, err = pcall(core.world.rollback, core.world, self.token)
		if not rolledBack then
			core:_log("world rollback failed: " .. tostring(err))
			core:_enterRecovery("rollback", self.token, self.effect)
			ok = false
		end
	end
	self:_release()
	return ok
end

return PlacementCore
