--[[
	PlacementCore: server-authoritative place / move / rotate / duplicate /
	delete for the single editable sandbox. Pure: every Roblox touch point is
	injected.

	deps = {
		config, catalog,
		templates     = { isInstalled(itemId), getSize(itemId) },   -- TemplateCatalog
		entitlements  = { isItemUnlocked(userId, item, catalog) },  -- Entitlements
		authority     = { check(userId) -> allowed, reason },       -- HostAuthority
		bounds        = { halfX, halfZ, height },                   -- RoomProvider sandbox
		world         = { apply(effect) -> token, commit(token), rollback(token),
		                  publishRevision(n) },                     -- PlacedItemsWorld
		clock         = function() -> seconds,
		log           = function(message) (optional),
	}

	Order for every request: rate limit -> strict payload -> host check ->
	busy lock -> plan (all validation, no mutation) -> world.apply -> host
	re-check -> commit model + BuildRevision -> world.commit.
	* Any rejection before apply leaves state, world and revision untouched.
	* If world.apply fails, or the host changed while it ran (it may yield),
	  the world change is rolled back and the model is never touched.
	* One edit at a time: a request arriving while another is mid-apply gets Busy.
	* Items may only be edited by their owner, who must also be the current host.
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
local Ops = Protocol.Ops

local PlacementCore = {}
PlacementCore.__index = PlacementCore

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
	self.busy = false
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

-- Resolves an existing item the user may edit. Returns id, record or nil, code.
function PlacementCore:_owned(userId, rawId)
	local id, code = RequestValidator.buildId(rawId)
	if id == nil then
		return nil, code
	end
	local record = self.model:get(id)
	if record == nil then
		return nil, Codes.NotFound
	end
	if record.ownerUserId ~= userId then
		return nil, Codes.NotOwner
	end
	return id, record
end

local function withTransform(record, t)
	return { itemId = record.itemId, ownerUserId = record.ownerUserId, x = t.x, y = t.y, z = t.z, yaw = t.yaw }
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
	return self:_spawnPlan({ itemId = itemId, ownerUserId = userId, x = t.x, y = t.y, z = t.z, yaw = t.yaw })
end

function planners.Move(self, userId, payload)
	local id, record = self:_owned(userId, rawget(payload, "id"))
	if id == nil then
		return nil, record
	end
	local shape, code = RequestValidator.transformShape(rawget(payload, "transform"))
	if shape == nil then
		return nil, code
	end
	return self:_movePlan(id, record, shape)
end

function planners.Rotate(self, userId, payload)
	local id, record = self:_owned(userId, rawget(payload, "id"))
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
	local id, source = self:_owned(userId, rawget(payload, "id"))
	if id == nil then
		return nil, source
	end
	local _, itemCode = self:_checkCreatable(userId, source.itemId)
	if itemCode then
		return nil, itemCode
	end
	-- Server picks the spot: next to the source on a free side, grid-aligned.
	local hx, hz = Transform.halfExtents(self.templates.getSize(source.itemId), source.yaw)
	local grid = self.config.GridSize
	local dx = math.ceil(hx * 2 / grid) * grid
	local dz = math.ceil(hz * 2 / grid) * grid
	for _, offset in ipairs({ { dx, 0 }, { -dx, 0 }, { 0, dz }, { 0, -dz } }) do
		local t = self:_clean(source.itemId, { x = source.x + offset[1], y = source.y, z = source.z + offset[2], yaw = source.yaw })
		if t then
			return self:_spawnPlan({ itemId = source.itemId, ownerUserId = userId, x = t.x, y = t.y, z = t.z, yaw = t.yaw })
		end
	end
	return nil, Codes.OutOfBounds
end

function planners.Delete(self, userId, payload)
	local id, record = self:_owned(userId, rawget(payload, "id"))
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

function PlacementCore:_execute(userId, plan)
	if plan.noop then
		return { ok = true, id = plan.id, buildRevision = self.revision }
	end
	self.busy = true
	local applied, token = pcall(self.world.apply, self.world, plan.effect)
	if not applied then
		self.busy = false
		self:_log("world apply failed: " .. tostring(token))
		return self:_reject(Codes.ApplyFailed)
	end
	-- world.apply may yield; the host may have changed meanwhile.
	if not self:_isHost(userId) then
		local rolledBack, err = pcall(self.world.rollback, self.world, token)
		if not rolledBack then
			self:_log("world rollback failed: " .. tostring(err))
		end
		self.busy = false
		return self:_reject(Codes.AuthorityLost)
	end
	local ok, commitErr = pcall(plan.commit)
	if not ok then
		-- Should be unreachable (plans are validated); keep world and model consistent.
		self:_log("model commit failed: " .. tostring(commitErr))
		pcall(self.world.rollback, self.world, token)
		self.busy = false
		return self:_reject(Codes.Internal)
	end
	self.revision = self.revision + 1
	local committed, err = pcall(self.world.commit, self.world, token)
	if not committed then
		self:_log("world commit failed: " .. tostring(err))
	end
	pcall(self.world.publishRevision, self.world, self.revision)
	self.busy = false
	return { ok = true, id = plan.id, buildRevision = self.revision }
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
	if not self:_isHost(userId) then
		return self:_reject(Codes.NotHost)
	end
	if self.busy then
		return self:_reject(Codes.Busy)
	end
	local planned, plan, planCode = pcall(planners[op], self, userId, payload)
	if not planned then
		self:_log("planning failed: " .. tostring(plan))
		return self:_reject(Codes.Internal)
	end
	if plan == nil then
		return self:_reject(planCode)
	end
	return self:_execute(userId, plan)
end

PlacementCore.Ops = Ops

return PlacementCore
