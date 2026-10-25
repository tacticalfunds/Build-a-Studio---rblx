-- Review finding (3d6519f, reproduced in Studio Luau): history was only
-- re-synced on the next host edit, so A -> B (Status only) -> A let A undo
-- again, and A's status said canUndo=true while B was host. History must be
-- invalidated when HostUserId changes, and every yielding history operation
-- must re-check the host-session epoch.
return function(T, H)
	local PlacementCore = H.load("src/server/Core/PlacementCore")
	local Catalog = H.load("src/shared/Catalog")
	local Config = H.load("src/shared/Config")

	local A, B = 1001, 2002

	local function setup(options)
		options = options or {}
		local env = { host = A, now = 0, yieldOn = {} }
		local world = { live = {}, calls = {} }
		function world:apply(effect)
			self.calls[#self.calls + 1] = "apply:" .. effect.kind
			if env.yieldOn[effect.kind] then
				env.yieldOn[effect.kind] = nil
				coroutine.yield()
			end
			local previous = self.live[effect.id]
			if effect.kind == "spawn" then
				self.live[effect.id] = effect.record
			elseif effect.kind == "move" then
				self.live[effect.id] = effect.to
			else
				self.live[effect.id] = nil
			end
			return { id = effect.id, previous = previous }
		end
		function world:rollback(token)
			self.calls[#self.calls + 1] = "rollback"
			self.live[token.id] = token.previous
		end
		function world:commit() end
		function world:publishRevision() end
		env.world = world
		env.core = PlacementCore.new({
			config = Config,
			catalog = Catalog,
			templates = { isInstalled = function() return true end, getSize = function() return { 2.93, 5.72, 2.93 } end },
			entitlements = { isItemUnlocked = function() return true end },
			authority = {
				check = function(_, userId)
					env.checks = (env.checks or 0) + 1
					if env.yieldOnCheck == env.checks then
						coroutine.yield("check")
					end
					return userId == env.host
				end,
				currentHostUserId = (not options.noHostReadback) and function() return env.host end or nil,
			},
			bounds = { halfX = 20, halfZ = 15, height = 16 },
			world = world,
			clock = function() return env.now end,
		})
		function env.req(payload, userId)
			env.now = env.now + 1
			return env.core:handle(userId, payload)
		end
		-- HostUserId attribute changes; the runtime forwards it to the core.
		function env.transfer(userId)
			env.host = userId
			if env.core.onHostChanged then
				env.core:onHostChanged()
			end
		end
		return env
	end

	local function place(env, userId, x)
		return env.req({ op = "Place", itemId = "cozy_plant_01", transform = { x = x or 0, y = 0, z = 0, yaw = 0 } }, userId)
	end

	T.test("A -> B (status only) -> A: A's old history is gone, with no intervening edit", function()
		local env = setup()
		T.eq(place(env, A).id, "i1")
		env.transfer(B)
		T.eq(env.req({ op = "Status" }, B).ok, true, "B only reads status")
		env.transfer(A)
		local r = env.req({ op = "Undo" }, A)
		T.eq(r.code, "NothingToUndo", "A must not undo across a host session boundary")
		T.eq(#env.core:list(), 1, "i1 still placed")
	end)

	T.test("status never offers undo/redo to a user without current authority", function()
		local env = setup()
		place(env, A)
		env.transfer(B)
		local s = env.req({ op = "Status" }, A).status
		T.eq(s.canUndo, false, "former host A sees canUndo=false while B is host")
		T.eq(s.canRedo, false)
		T.eq(env.req({ op = "Status" }, B).status.canUndo, false, "B has no history yet")
	end)

	T.test("host change is observed even if the runtime notification is missed", function()
		local env = setup()
		place(env, A)
		env.host = B -- attribute changed; no onHostChanged call (missed signal)
		env.req({ op = "Status" }, B)
		env.host = A
		T.eq(env.req({ op = "Undo" }, A).code, "NothingToUndo", "observed via currentHostUserId on B's request")
	end)

	T.test("epoch change during a yielding undo (A -> B -> A) rolls back and clears history", function()
		local env = setup()
		place(env, A)
		env.yieldOn.remove = true
		local response
		local co = coroutine.create(function()
			response = env.core:handle(A, { op = "Undo" })
		end)
		env.now = env.now + 1
		assert(coroutine.resume(co))
		env.transfer(B)
		env.transfer(A) -- A is host again, but in a new host session
		assert(coroutine.resume(co))
		T.eq(response.code, "AuthorityLost")
		T.eq(env.world.calls[#env.world.calls], "rollback")
		T.eq(#env.core:list(), 1, "undo did not commit")
		T.ok(env.world.live.i1 ~= nil, "world rolled back")
		T.eq(env.req({ op = "Undo" }, A).code, "NothingToUndo", "history invalidated")
	end)

	T.test("epoch change during a yielding normal edit also aborts it", function()
		local env = setup()
		env.yieldOn.spawn = true
		local response
		local co = coroutine.create(function()
			response = env.core:handle(A, { op = "Place", itemId = "cozy_plant_01", transform = { x = 0, y = 0, z = 0, yaw = 0 } })
		end)
		env.now = env.now + 1
		assert(coroutine.resume(co))
		env.transfer(B)
		env.transfer(A)
		assert(coroutine.resume(co))
		T.eq(response.code, "AuthorityLost")
		T.eq(#env.core:list(), 0)
	end)

	T.test("status requires current authority even when no host change was observable", function()
		local env = setup({ noHostReadback = true })
		place(env, A)
		env.host = B -- no notification and no readback: epoch cannot change
		local s = env.req({ op = "Status" }, A).status
		T.eq(s.canUndo, false, "former host is not offered undo")
		T.eq(env.req({ op = "Undo" }, A).code, "NotHost")
	end)

	T.test("A -> B -> A during a yielding post-apply authority check does not commit", function()
		local env = setup()
		env.checks = 0
		-- Checks in a Place: 1 = initial, 2 = after planning, 3 = after world.apply.
		env.yieldOnCheck = 3
		local response
		local co = coroutine.create(function()
			response = env.core:handle(A, { op = "Place", itemId = "cozy_plant_01", transform = { x = 0, y = 0, z = 0, yaw = 0 } })
		end)
		env.now = env.now + 1
		assert(coroutine.resume(co))
		T.eq(response, nil, "suspended inside the post-apply authority check")
		env.transfer(B)
		env.transfer(A)
		assert(coroutine.resume(co))
		T.eq(response.ok, false, "must not commit in a new host session")
		T.eq(response.code, "AuthorityLost")
		T.eq(#env.core:list(), 0)
		T.eq(env.world.live.i1, nil, "world rolled back")
		T.eq(env.core:getRevision(), 0)
	end)

	T.test("same host keeps history across status reads and its own edits", function()
		local env = setup()
		place(env, A)
		env.req({ op = "Status" }, A)
		env.req({ op = "Status" }, B)
		T.eq(env.req({ op = "Undo" }, A).ok, true)
	end)
end
