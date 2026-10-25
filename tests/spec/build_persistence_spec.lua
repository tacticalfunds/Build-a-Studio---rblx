-- Task 5: Build save/load through the core and BuildPersistence (the API the
-- patched Director calls). Fake world supports the two-phase "replace" effect.
return function(T, H)
	local PlacementCore = H.load("src/server/Core/PlacementCore")
	local BuildPersistence = H.load("src/server/Core/BuildPersistence")
	local SaveSnapshot = H.load("src/server/Adapters/SaveSnapshot")
	local Catalog = H.load("src/shared/Catalog")
	local Config = H.load("src/shared/Config")

	local A, B = 1001, 2002
	local SIZES = { cozy_plant_01 = { 2.93, 5.72, 2.93 }, cozy_armchair_01 = { 5.0, 4.73, 4.25 }, retro_tv_cart_01 = { 3.29, 4.68, 3.97 } }

	local function fakeWorld(env)
		local w = { live = {}, calls = {}, failApply = nil, failRollback = 0, yieldOn = {} }
		local function copy(r)
			return { itemId = r.itemId, x = r.x, y = r.y, z = r.z, yaw = r.yaw }
		end
		function w:apply(effect)
			self.calls[#self.calls + 1] = "apply:" .. effect.kind
			if self.yieldOn[effect.kind] then
				self.yieldOn[effect.kind] = nil
				coroutine.yield("world")
			end
			if self.failApply == effect.kind then
				error("world failure")
			end
			if effect.kind == "replace" then
				local old = self.live
				local new = {}
				for _, e in ipairs(effect.entries) do
					new[e.id] = copy(e.record)
				end
				self.live = new
				return { kind = "replace", old = old }
			end
			local previous = self.live[effect.id]
			if effect.kind == "spawn" then
				self.live[effect.id] = copy(effect.record)
			elseif effect.kind == "move" then
				self.live[effect.id] = copy(effect.to)
			else
				self.live[effect.id] = nil
			end
			return { kind = effect.kind, id = effect.id, previous = previous }
		end
		function w:rollback(token)
			self.calls[#self.calls + 1] = "rollback:" .. token.kind
			if self.failRollback > 0 then
				self.failRollback = self.failRollback - 1
				error("rollback failed")
			end
			if token.kind == "replace" then
				self.live = token.old
			else
				self.live[token.id] = token.previous
			end
		end
		function w:commit() end
		function w:reconcile(entries)
			self.calls[#self.calls + 1] = "reconcile"
			self.live = {}
			for _, e in ipairs(entries) do
				self.live[e.id] = copy(e.record)
			end
		end
		function w:publishRevision() end
		return w
	end

	local function setup(options)
		options = options or {}
		local env = { host = A, now = 0, installed = {}, locked = {} }
		for id in pairs(SIZES) do
			env.installed[id] = true
		end
		env.world = fakeWorld(env)
		env.core = PlacementCore.new({
			config = setmetatable({ MaxItems = options.maxItems or Config.MaxItems }, { __index = Config }),
			catalog = Catalog,
			templates = {
				isInstalled = function(id) return env.installed[id] == true end,
				getSize = function(id)
					local s = env.installed[id] and SIZES[id]
					return s and { s[1], s[2], s[3] } or nil
				end,
			},
			entitlements = { isItemUnlocked = function(_, _, item) return not env.locked[item.id] end },
			authority = {
				check = function(_, userId) return userId == env.host end,
				currentHostUserId = function() return env.host end,
			},
			bounds = { halfX = 20, halfZ = 15, height = 16 },
			world = env.world,
			clock = function() return env.now end,
		})
		env.persistence = BuildPersistence.new(function() return env.core end)
		function env.req(payload, userId)
			env.now = env.now + 1
			return env.core:handle(userId or A, payload)
		end
		function env.place(itemId, x, z, yaw)
			return env.req({ op = "Place", itemId = itemId or "cozy_plant_01", transform = { x = x or 0, y = 0, z = z or 0, yaw = yaw or 0 } })
		end
		function env.transfer(userId)
			env.host = userId
			env.core:onHostChanged()
		end
		return env
	end

	local function state(env)
		local parts = { "rev=" .. env.core:getRevision(), "preserved=" .. #env.core.preserved }
		for _, e in ipairs(env.core:list()) do
			local r = e.record
			parts[#parts + 1] = string.format("%s:%s:%.2f,%.2f,%g", e.id, r.itemId, r.x, r.z, r.yaw)
		end
		local live = {}
		for id, r in pairs(env.world.live) do
			live[#live + 1] = string.format("%s:%.2f,%.2f", id, r.x, r.z)
		end
		table.sort(live)
		parts[#parts + 1] = "world=" .. table.concat(live, ";")
		return table.concat(parts, "|")
	end

	local function preset(build)
		local data = { Version = 1, Settings = { SceneSet = "Custom", Title = "My show" }, Fixtures = { L1 = { Enabled = true } }, Items = { P1 = { X = 1 } } }
		data.Build = build
		return data
	end

	local function errorMessage(fn)
		local ok, err = pcall(fn)
		T.eq(ok, false, "expected an error")
		return tostring(err)
	end

	local function stored(id, catalogId, x)
		return { Id = id, CatalogId = catalogId, Transform = { X = x or 0, Y = 0, Z = 0, Yaw = 0 } }
	end

	-- Build-only load through the held transaction (what DirectorPersistence does
	-- around the room restore): begin, apply, final check, commit; rollback on error.
	local function commitLoad(env, staged)
		local txn = env.persistence:begin(A, staged)
		local ok, err = pcall(function()
			txn:applyBuild()
			assert(txn:stillAuthorized(), "Host controls changed while loading. Nothing was changed.")
		end)
		if not ok then
			local rolledBack = txn:rollback()
			error(rolledBack and err or "The builder is resynchronizing. Try again in a moment; nothing was changed.", 0)
		end
		return txn:commit()
	end

	-- Save -----------------------------------------------------------------------

	T.test("save attaches an additive Build section; preset Version and sections untouched", function()
		local env = setup()
		env.place("cozy_plant_01", 2, 0)
		env.place("cozy_armchair_01", -6, 0, 90)
		local snapshot = preset(nil)
		local saved = env.persistence:attachBuild(snapshot)
		T.eq(saved.Version, 1)
		T.eq(saved.Settings, snapshot.Settings)
		T.eq(saved.Fixtures, snapshot.Fixtures)
		T.eq(saved.Items, snapshot.Items)
		T.eq(snapshot.Build, nil, "input snapshot not mutated")
		T.eq(saved.Build.Version, 1)
		T.eq(#saved.Build.Items, 2)
		T.eq(saved.Build.Items[2].CatalogId, "cozy_armchair_01")
		T.eq(saved.Build.Items[2].Transform.Yaw, 90)
		for key in pairs(saved.Build.Items[1]) do
			T.ok(key == "Id" or key == "CatalogId" or key == "Transform", "unexpected stored key " .. key)
		end
	end)

	T.test("save fails visibly while an edit is in flight or the world is recovering", function()
		local env = setup()
		env.world.yieldOn.spawn = true
		local co = coroutine.create(function() env.place("cozy_plant_01", 0, 0) end)
		assert(coroutine.resume(co))
		T.ok(errorMessage(function() env.persistence:attachBuild(preset(nil)) end):find("still applying"), "Busy message")
		assert(coroutine.resume(co))
		-- Put the core into recovery: host lost mid-edit and the rollback fails.
		env.world.failRollback = 1
		env.world.yieldOn.spawn = true
		local co2 = coroutine.create(function() env.place("cozy_plant_01", 5, 0) end)
		assert(coroutine.resume(co2))
		env.transfer(B)
		assert(coroutine.resume(co2))
		env.transfer(A)
		T.eq(env.core:getState(), "recovery")
		T.ok(errorMessage(function() env.persistence:attachBuild(preset(nil)) end):find("resynchronizing"), "RecoveryNeeded message")
	end)

	T.test("an oversized build fails the save visibly", function()
		local env = setup()
		env.place("cozy_plant_01", 0, 0)
		local original = Config.MaxBuildSectionBytes
		Config.MaxBuildSectionBytes = 10
		local ok, err = pcall(function() env.persistence:attachBuild(preset(nil)) end)
		Config.MaxBuildSectionBytes = original
		T.eq(ok, false)
		T.ok(tostring(err):find("too large"))
	end)

	T.test("there is no implicit save path: the builder never writes a DataStore", function()
		for _, rel in ipairs(H.sourceList) do
			local src = H.readFile(H.ROOT .. "/" .. rel):gsub("%-%-%[(=*)%[.-%]%1%]", "")
			for _, word in ipairs({ "UpdateAsync", "SetAsync", "GetDataStore", "RemoveAsync" }) do
				-- Comments may mention them; code may not.
				for line in src:gmatch("[^\n]+") do
					local code = line:gsub("%-%-.*$", "")
					T.ok(not code:find(word), rel .. " calls " .. word)
				end
			end
		end
	end)

	-- Load -----------------------------------------------------------------------

	T.test("load round trip: same logical IDs and transforms; history cleared", function()
		local source = setup()
		source.place("cozy_plant_01", 2, 0)
		source.place("cozy_armchair_01", -6, 3, 90)
		local saved = source.persistence:attachBuild(preset(nil))

		local env = setup()
		env.place("retro_tv_cart_01", 9, 9) -- current build, about to be replaced
		local staged = env.persistence:prepareLoad(A, saved)
		T.eq(commitLoad(env, staged).ok, true)
		local list = env.core:list()
		T.eq(#list, 2)
		T.eq(list[1].id, "i1")
		T.eq(list[2].id, "i2")
		T.eq(list[2].record.yaw, 90)
		T.eq(env.world.live.i2.z, 3, "world matches")
		T.eq(env.req({ op = "Undo" }).code, "NothingToUndo", "history cleared by the load")
		T.eq(env.place("cozy_plant_01", 0, -8).id, "i3", "IDs continue after the higher of both nextIds")
	end)

	T.test("IDs are never reused after loading a save with a lower NextId", function()
		local env = setup()
		for i = 1, 5 do
			env.place("cozy_plant_01", -12 + i * 4, 0) -- i1..i5 handed out in this server
		end
		local staged = env.persistence:prepareLoad(A, preset({ Version = 1, NextId = 2, Items = { stored("i1", "cozy_armchair_01", 5) } }))
		commitLoad(env, staged)
		T.eq(env.place("cozy_plant_01", -8, -8).id, "i6", "not i2")
	end)

	T.test("corrupt or newer Build sections fail before anything changes", function()
		local env = setup()
		env.place("cozy_plant_01", 1, 1)
		local before, calls = state(env), #env.world.calls
		local corrupt = errorMessage(function() env.persistence:prepareLoad(A, preset({ Version = 1, NextId = 1, Items = "nope" })) end)
		T.ok(corrupt:find("can't be read"), corrupt)
		T.ok(corrupt:find(":%d+: "), "position prefix for the Director's message extraction")
		local newer = errorMessage(function() env.persistence:prepareLoad(A, preset({ Version = 99, NextId = 1, Items = {} })) end)
		T.ok(newer:find("newer version"), newer)
		T.ok(errorMessage(function() env.persistence:prepareLoad(A, preset({ Version = 1, NextId = 2, Items = { stored("i1", "cozy_plant_01", 0 / 0) } })) end):find("can't be read"))
		T.eq(state(env), before, "build unchanged")
		T.eq(#env.world.calls, calls, "world untouched")
	end)

	T.test("legacy presets (no Build) leave the build untouched", function()
		local env = setup()
		env.place("cozy_plant_01", 1, 1)
		local before = state(env)
		local staged = env.persistence:prepareLoad(A, preset(nil))
		T.eq(staged.legacy, true)
		T.eq(commitLoad(env, staged).ok, true)
		T.eq(state(env), before)
	end)

	T.test("unplaceable entries are preserved, counted against the cap, and written back", function()
		local env = setup({ maxItems = 5 })
		env.installed.retro_tv_cart_01 = nil
		env.locked.cozy_armchair_01 = true
		local section = {
			Version = 1, NextId = 9,
			Items = {
				stored("i1", "cozy_plant_01", 0),
				stored("i2", "retired_sofa_01", 0), -- unknown catalog ID
				stored("i3", "retro_tv_cart_01", 2), -- template not installed
				stored("i4", "cozy_armchair_01", 4), -- collection locked
				stored("i5", "cozy_plant_01", 500), -- outside current bounds
			},
		}
		commitLoad(env, env.persistence:prepareLoad(A, preset(section)))
		T.eq(#env.core:list(), 1, "only the placeable entry is spawned")
		T.eq(#env.core.preserved, 4)
		T.eq(env.world.live.i2, nil)
		T.eq(env.place("cozy_plant_01", 6, 0).code, "ItemCap", "preserved entries hold capacity (5 total)")
		local resaved = env.persistence:attachBuild(preset(nil))
		T.eq(#resaved.Build.Items, 5, "all entries written back")
		T.eq(resaved.Build.Items[2].CatalogId, "retired_sofa_01")
		T.eq(resaved.Build.NextId, 9)
	end)

	T.test("host change during the world replace rolls back; build unchanged", function()
		local env = setup()
		env.place("cozy_plant_01", 1, 1)
		local before = state(env)
		local staged = env.persistence:prepareLoad(A, preset({ Version = 1, NextId = 3, Items = { stored("i7", "cozy_armchair_01", 5) } }))
		env.world.yieldOn.replace = true
		local result
		local co = coroutine.create(function()
			result = { pcall(function() return commitLoad(env, staged) end) }
		end)
		assert(coroutine.resume(co))
		env.transfer(B)
		env.transfer(A) -- A -> B -> A: same host, new host session
		assert(coroutine.resume(co))
		T.eq(result[1], false)
		T.ok(tostring(result[2]):find("Host controls changed"))
		T.eq(state(env), before)
	end)

	T.test("edits and saves are serialized with a pending load", function()
		local env = setup()
		env.place("cozy_plant_01", 1, 1)
		local staged = env.persistence:prepareLoad(A, preset({ Version = 1, NextId = 2, Items = { stored("i1", "cozy_armchair_01", 5) } }))
		env.world.yieldOn.replace = true
		local co = coroutine.create(function() commitLoad(env, staged) end)
		assert(coroutine.resume(co))
		T.eq(env.place("cozy_plant_01", 3, 3).code, "Busy")
		T.ok(errorMessage(function() env.persistence:attachBuild(preset(nil)) end):find("still applying"))
		local second = pcall(function() commitLoad(env, staged) end)
		T.eq(second, false, "a second load is refused while the first is applying")
		assert(coroutine.resume(co))
		T.eq(env.core:list()[1].record.itemId, "cozy_armchair_01")
	end)

	T.test("world replace failure leaves the build unchanged", function()
		local env = setup()
		env.place("cozy_plant_01", 1, 1)
		local before = state(env)
		env.world.failApply = "replace"
		local staged = env.persistence:prepareLoad(A, preset({ Version = 1, NextId = 2, Items = { stored("i1", "cozy_armchair_01", 5) } }))
		T.ok(errorMessage(function() commitLoad(env, staged) end):find("couldn't be applied"))
		T.eq(state(env), before)
	end)

	T.test("a failed rollback after a load fails closed; recovery restores the old build", function()
		local env = setup()
		env.place("cozy_plant_01", 1, 1)
		local before = state(env)
		local staged = env.persistence:prepareLoad(A, preset({ Version = 1, NextId = 2, Items = { stored("i1", "cozy_armchair_01", 5) } }))
		env.world.yieldOn.replace = true
		env.world.failRollback = 1
		local result
		local co = coroutine.create(function()
			result = { pcall(function() return commitLoad(env, staged) end) }
		end)
		assert(coroutine.resume(co))
		env.transfer(B)
		assert(coroutine.resume(co))
		T.ok(tostring(result[2]):find("resynchronizing"), "recovery reported")
		T.eq(env.core:getState(), "recovery")
		env.transfer(A)
		T.eq(env.core:recover(), true)
		T.eq(env.world.calls[#env.world.calls], "rollback:replace", "retried rollback restored the old set")
		T.eq(state(env), before)
	end)

	T.test("builder unavailable: saves carry no Build, loads skip it", function()
		local persistence = BuildPersistence.new(function() return nil end)
		local snapshot = preset(nil)
		T.eq(persistence:attachBuild(snapshot), snapshot)
		local staged = persistence:prepareLoad(A, preset({ Version = 1, NextId = 1, Items = {} }))
		T.eq(staged.skipped, true)
		local txn = persistence:begin(A, staged)
		txn:applyBuild()
		T.eq(txn:stillAuthorized(), true)
		T.eq(txn:commit().ok, true)
	end)

	T.test("preparation is bound to the host session: A -> B -> A before begin is refused", function()
		local env = setup()
		env.place("cozy_plant_01", 1, 1)
		local before = state(env)
		local staged = env.persistence:prepareLoad(A, preset({ Version = 1, NextId = 2, Items = { stored("i1", "cozy_armchair_01", 5) } }))
		local legacy = env.persistence:prepareLoad(A, preset(nil))
		env.transfer(B) -- e.g. during the Director's yielding text filtering
		env.transfer(A)
		T.ok(errorMessage(function() env.persistence:begin(A, staged) end):find("Host controls changed"))
		T.ok(errorMessage(function() env.persistence:begin(A, legacy) end):find("Host controls changed"), "legacy room-only loads too")
		T.eq(state(env), before)
		T.eq(env.core:getState(), "ready", "nothing left locked")
	end)

	T.test("preparation is bound to the build revision", function()
		local env = setup()
		local staged = env.persistence:prepareLoad(A, preset({ Version = 1, NextId = 2, Items = { stored("i1", "cozy_armchair_01", 5) } }))
		local legacy = env.persistence:prepareLoad(A, preset(nil))
		env.place("cozy_plant_01", 1, 1) -- the build changed after staging
		T.ok(errorMessage(function() env.persistence:begin(A, staged) end):find("build changed"))
		local txn = env.persistence:begin(A, legacy) -- room-only loads don't depend on the build revision
		T.eq(txn:commit().ok, true)
	end)

	T.test("the transaction holds the edit lock until it ends", function()
		local env = setup()
		local txn = env.persistence:begin(A, env.persistence:prepareLoad(A, preset(nil)))
		T.eq(env.place("cozy_plant_01", 1, 1).code, "Busy")
		T.ok(errorMessage(function() env.persistence:attachBuild(preset(nil)) end):find("still applying"))
		txn:rollback()
		T.eq(env.place("cozy_plant_01", 1, 1).ok, true)
	end)

	T.test("prepareLoad refuses a non-host before anything else", function()
		local env = setup()
		T.ok(errorMessage(function() env.persistence:prepareLoad(B, preset(nil)) end):find("Host controls changed"))
	end)

	T.test("prepareLoad only validates: nothing is staged into the core", function()
		local env = setup()
		env.place("cozy_plant_01", 1, 1)
		local before = state(env)
		env.persistence:prepareLoad(A, preset({ Version = 1, NextId = 2, Items = { stored("i1", "cozy_armchair_01", 5) } }))
		T.eq(state(env), before)
		T.eq(SaveSnapshot.VERSION, 1)
	end)
end
