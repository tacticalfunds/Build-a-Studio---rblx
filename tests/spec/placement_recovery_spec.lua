-- Regression tests for the two task-3 review blockers (reproduced by Codex in
-- Studio Luau with an isolated fake world):
--  1. the edit lock was taken only after planning, so a request yielding in a
--     planning dependency could interleave with another request mid-apply and
--     both allocated i1 (model/world diverged);
--  2. a failed rollback after losing authority only logged and unlocked,
--     leaving world and model diverged with edits still accepted.
-- Yields are simulated with coroutines.
return function(T, H)
	local PlacementCore = H.load("src/server/Core/PlacementCore")
	local Catalog = H.load("src/shared/Catalog")
	local Config = H.load("src/shared/Config")

	local HOST, OTHER = 1001, 2002
	local SIZE = { 2.93, 5.72, 2.93 }

	-- Fake world with switchable yields and failures.
	-- yieldOn[kind] = true      apply(kind) yields once
	-- failRollback = n          the next n rollbacks raise
	-- failCommit = n            the next n commits raise
	-- reconcileFails = bool     reconcile raises
	local function fakeWorld()
		local w = { live = {}, calls = {}, revisions = {}, yieldOn = {}, failRollback = 0, failCommit = 0, pendingRemoval = {} }
		local function copy(r)
			return { itemId = r.itemId, x = r.x, y = r.y, z = r.z, yaw = r.yaw }
		end
		function w:apply(effect)
			self.calls[#self.calls + 1] = "apply:" .. effect.kind .. ":" .. effect.id
			if self.yieldOn[effect.kind] then
				self.yieldOn[effect.kind] = nil
				coroutine.yield("world")
			end
			local previous = self.live[effect.id]
			if effect.kind == "spawn" then
				self.live[effect.id] = copy(effect.record)
			elseif effect.kind == "move" then
				self.live[effect.id] = copy(effect.to)
			elseif effect.kind == "remove" then
				self.live[effect.id] = nil
				self.pendingRemoval[effect.id] = true
			end
			return { kind = effect.kind, id = effect.id, previous = previous }
		end
		function w:rollback(token)
			self.calls[#self.calls + 1] = "rollback:" .. token.id
			if self.failRollback > 0 then
				self.failRollback = self.failRollback - 1
				error("rollback failed")
			end
			self.live[token.id] = token.previous
			self.pendingRemoval[token.id] = nil
		end
		function w:commit(token)
			self.calls[#self.calls + 1] = "commit:" .. token.id
			if self.failCommit > 0 then
				self.failCommit = self.failCommit - 1
				error("finalize failed")
			end
			self.pendingRemoval[token.id] = nil
		end
		function w:reconcile(entries)
			self.calls[#self.calls + 1] = "reconcile"
			if self.reconcileFails then
				error("reconcile failed")
			end
			self.live = {}
			self.pendingRemoval = {}
			for _, e in ipairs(entries) do
				self.live[e.id] = copy(e.record)
			end
		end
		function w:publishRevision(n)
			self.revisions[#self.revisions + 1] = n
		end
		return w
	end

	local function setup()
		local env = { host = HOST, now = 0, yieldEntitlement = false }
		env.world = fakeWorld()
		env.core = PlacementCore.new({
			config = Config,
			catalog = Catalog,
			templates = {
				isInstalled = function() return true end,
				getSize = function() return { SIZE[1], SIZE[2], SIZE[3] } end,
			},
			entitlements = {
				isItemUnlocked = function()
					if env.yieldEntitlement then
						env.yieldEntitlement = false
						coroutine.yield("entitlement")
					end
					return true
				end,
			},
			authority = { check = function(_, userId) return userId == env.host end },
			bounds = { halfX = 20, halfZ = 15, height = 16 },
			world = env.world,
			clock = function() return env.now end,
		})
		function env.placePayload(x)
			return { op = "Place", itemId = "cozy_plant_01", transform = { x = x or 0, y = 0, z = 0, yaw = 0 } }
		end
		-- Starts a request in its own coroutine; returns a function giving its response.
		function env.start(payload, userId)
			env.now = env.now + 1
			local response
			local co = coroutine.create(function()
				response = env.core:handle(userId or HOST, payload)
			end)
			assert(coroutine.resume(co))
			return co, function() return response end
		end
		function env.req(payload, userId)
			env.now = env.now + 1
			return env.core:handle(userId or HOST, payload)
		end
		return env
	end

	local function modelIds(env)
		local ids = {}
		for _, e in ipairs(env.core:list()) do
			ids[#ids + 1] = e.id
		end
		return table.concat(ids, ",")
	end

	local function worldIds(env)
		local ids = {}
		for id in pairs(env.world.live) do
			ids[#ids + 1] = id
		end
		table.sort(ids)
		return table.concat(ids, ",")
	end

	-- Blocker 1 -----------------------------------------------------------

	T.test("blocker 1: exact interleaving (A yields in entitlement, B yields in world.apply) stays consistent", function()
		local env = setup()
		env.yieldEntitlement = true
		local coA, resultA = env.start(env.placePayload(0))
		T.eq(resultA(), nil, "A is suspended inside the entitlement check")

		env.world.yieldOn.spawn = true
		local coB, resultB = env.start(env.placePayload(5))
		-- With the lock taken before planning, B must not reach world.apply.
		if resultB() == nil then
			-- Old behaviour: B suspended inside world.apply. Drive the reported sequence.
			assert(coroutine.resume(coA))
			assert(coroutine.resume(coB))
		end
		T.eq(resultB().code, "Busy", "B is refused while A holds the edit lock")
		T.eq(env.world.yieldOn.spawn, true, "B never reached world.apply")
		T.eq(#env.world.calls, 0)
		env.world.yieldOn.spawn = nil
		assert(coroutine.resume(coA))
		T.eq(resultA().ok, true)
		T.eq(resultA().id, "i1")
		T.eq(modelIds(env), "i1")
		T.eq(worldIds(env), "i1", "world and model agree")
		T.eq(env.core:getState(), "ready")
		T.eq(env.req(env.placePayload(5)).id, "i2", "next edit proceeds normally")
	end)

	T.test("host change while planning yields: rejected before any world change", function()
		local env = setup()
		env.yieldEntitlement = true
		local co, result = env.start(env.placePayload(0))
		env.host = OTHER
		assert(coroutine.resume(co))
		T.eq(result().code, "AuthorityLost")
		T.eq(#env.world.calls, 0, "world never touched")
		T.eq(modelIds(env), "")
		T.eq(env.core:getState(), "ready", "lock released")
	end)

	T.test("the lock is released after every rejection and after internal errors", function()
		local env = setup()
		for _, payload in ipairs({
			{ op = "Place", itemId = "nope_01", transform = { x = 0, y = 0, z = 0, yaw = 0 } },
			{ op = "Place", itemId = "cozy_plant_01", transform = { x = 99, y = 0, z = 0, yaw = 0 } },
			{ op = "Delete", id = "i7" },
		}) do
			env.req(payload)
			T.eq(env.core:getState(), "ready", payload.op)
		end
		env.req(env.placePayload(0), OTHER)
		T.eq(env.core:getState(), "ready", "after NotHost")
		env.core.entitlements = { isItemUnlocked = function() error("entitlement service bug") end }
		T.eq(env.req(env.placePayload(0)).code, "Internal")
		T.eq(env.core:getState(), "ready", "after a throwing dependency")
	end)

	-- Blocker 2 -----------------------------------------------------------

	-- Host transfers while world.apply is suspended, then the original host
	-- returns: edits must still be refused until the world is reconciled.
	local function loseHostDuringApply(env)
		env.world.yieldOn.spawn = true
		local co, result = env.start(env.placePayload(0))
		env.host = OTHER
		assert(coroutine.resume(co))
		env.host = HOST
		return result()
	end

	T.test("blocker 2: failed rollback fails closed with recovery-needed state", function()
		local env = setup()
		env.world.failRollback = 1
		local r = loseHostDuringApply(env)
		T.eq(r.ok, false)
		T.eq(r.code, "AuthorityLost")
		T.eq(r.recoveryNeeded, true, "response must not claim the world is unchanged")
		T.eq(env.core:getState(), "recovery")
		T.eq(worldIds(env), "i1", "world really did diverge (rollback failed)")
		T.eq(modelIds(env), "", "model was never committed")
		T.ok(env.core:getRecovery() ~= nil, "operation and token retained")
		T.eq(env.core:getRecovery().kind, "rollback")
	end)

	T.test("edits are refused while recovery keeps failing; revision does not move", function()
		local env = setup()
		env.world.failRollback = 3
		env.world.reconcileFails = true
		T.eq(loseHostDuringApply(env).recoveryNeeded, true)
		for _ = 1, 2 do
			local r = env.req(env.placePayload(5))
			T.eq(r.code, "RecoveryNeeded")
		end
		T.eq(env.core:getRevision(), 0)
		T.eq(env.core:getState(), "recovery")
		T.eq(modelIds(env), "")
	end)

	T.test("retried rollback reconciles, then edits resume consistently", function()
		local env = setup()
		env.world.failRollback = 2 -- the original rollback and the first retry fail
		env.world.reconcileFails = true
		T.eq(loseHostDuringApply(env).recoveryNeeded, true)
		T.eq(env.req(env.placePayload(5)).code, "RecoveryNeeded", "retry 1 fails")
		local r = env.req(env.placePayload(5))
		T.eq(r.ok, true, "retry 2 succeeds and the edit proceeds")
		T.eq(env.core:getState(), "ready")
		T.eq(modelIds(env), r.id)
		T.eq(worldIds(env), r.id, "stray i1 removed by the retried rollback")
	end)

	T.test("reconcile is the fallback when rollback keeps failing", function()
		local env = setup()
		env.world.failRollback = 100
		T.eq(loseHostDuringApply(env).recoveryNeeded, true)
		T.eq(env.core:recover(), true)
		T.eq(env.world.calls[#env.world.calls], "reconcile")
		T.eq(worldIds(env), "", "world rebuilt from the model")
		T.eq(env.core:getState(), "ready")
	end)

	T.test("model commit failure rolls the world back, or fails closed if that rollback fails", function()
		local env = setup()
		env.req(env.placePayload(0))
		local realAdd = env.core.model.add
		env.core.model.add = function() error("model bug") end
		T.eq(env.req(env.placePayload(5)).code, "Internal")
		T.eq(worldIds(env), "i1", "spawned model rolled back")
		T.eq(env.core:getState(), "ready")

		env.world.failRollback = 1
		env.world.reconcileFails = true
		local r = env.req(env.placePayload(5))
		T.eq(r.code, "Internal")
		T.eq(r.recoveryNeeded, true)
		T.eq(env.core:getState(), "recovery")
		env.core.model.add = realAdd
		env.world.reconcileFails = false
		T.eq(env.core:recover(), true)
		T.eq(worldIds(env), "i1")
	end)

	T.test("finalization failure: edit is committed, recovery retries finalize before more edits", function()
		local env = setup()
		env.req(env.placePayload(0))
		env.world.failCommit = 1
		env.world.reconcileFails = true
		local r = env.req({ op = "Delete", id = "i1" })
		T.eq(r.ok, true, "the delete itself is committed")
		T.eq(r.recoveryNeeded, true)
		T.eq(env.core:getState(), "recovery")
		T.eq(env.core:getRecovery().kind, "finalize")
		T.eq(env.world.pendingRemoval.i1, true, "detached model not yet destroyed")
		local next = env.req(env.placePayload(3))
		T.eq(next.ok, true, "finalize retried, then the new edit runs")
		T.eq(env.world.pendingRemoval.i1, nil)
		T.eq(modelIds(env), "i2")
		T.eq(worldIds(env), "i2")
	end)

	T.test("concurrent requests during a yielding recovery are refused", function()
		local env = setup()
		env.world.failRollback = 1
		T.eq(loseHostDuringApply(env).recoveryNeeded, true)
		local realRollback = env.world.rollback
		env.world.rollback = function(self, token)
			coroutine.yield("recovering")
			return realRollback(self, token)
		end
		local co, first = env.start(env.placePayload(5))
		T.eq(first(), nil, "first request is driving recovery")
		T.eq(env.req(env.placePayload(6)).code, "RecoveryNeeded")
		assert(coroutine.resume(co))
		T.eq(first().ok, true)
		T.eq(env.core:getState(), "ready")
	end)
end
