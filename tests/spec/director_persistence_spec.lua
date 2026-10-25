-- Task 5 corrections: the actual integration callbacks (DirectorPersistence:
-- snapshot / restoreSnapshot / persistentAction) with the real patched
-- StudioPresets on a fake DataStore, the real BuildPersistence + PlacementCore
-- on a fake world, a fake room (settings, fixtures, items, applyAll) and a
-- yielding text filter.
return function(T, H)
	local PlacementCore = H.load("src/server/Core/PlacementCore")
	local BuildPersistence = H.load("src/server/Core/BuildPersistence")
	local Catalog = H.load("src/shared/Catalog")
	local Config = H.load("src/shared/Config")

	local A, B = 1001, 2002

	local function deepCopy(v)
		if type(v) ~= "table" then return v end
		local out = {}
		for k, x in pairs(v) do out[k] = deepCopy(x) end
		return out
	end

	local function attrObject(initial)
		local o = { attrs = deepCopy(initial or {}) }
		function o:GetAttribute(k) return self.attrs[k] end
		function o:SetAttribute(k, v) self.attrs[k] = v end
		return o
	end

	local function setup()
		local env = { now = 0, fired = {}, feedbacks = {}, busy = {}, filterCalls = 0, applyAllCalls = 0, remembered = 0 }

		-- Room ------------------------------------------------------------------
		env.settings = attrObject({ HostUserId = A, SceneSet = "Custom", Title = "Live show", Brightness = 1, Fog = 0.2, Ambience = "Off", Custom_Warmth = 0.5, Lounge_Warmth = 0.5, CustomLighting = false })
		local defaults = { SceneSet = "Custom", Title = "", Brightness = 1, Fog = 0, Ambience = "Off", Phase = "", Custom_Warmth = 0.5, Lounge_Warmth = 0.5 }
		local fixtures = {
			Custom = { { Id = "C1", Light = attrObject({ LightEnabled = true, LightIntensity = 2 }) } },
			Lounge = { { Id = "L1", Light = attrObject({ LightEnabled = false, LightIntensity = 0.5 }) } },
		}
		local items = {
			Custom = { { Id = "CI", Object = attrObject({ StudioMoveX = 3 }) } },
			Lounge = { { Id = "LI", Object = attrObject({ StudioMoveX = -2 }) } },
		}
		env.fixtures, env.items = fixtures, items
		local deps = {
			settings = env.settings,
			defaults = defaults,
			groupKeys = { Custom_Warmth = true, Lounge_Warmth = true },
			textLengths = { Title = 40 },
			bounds = { Brightness = { 0, 2 } },
			layoutBounds = {},
			atmosphereBounds = { Fog = { 0, 1 } },
			atmosphereKeys = { "Fog" },
			fixtureAttributes = { Enabled = "LightEnabled", Intensity = "LightIntensity" },
			itemAttributes = { X = "StudioMoveX", Visible = "StudioItemVisible" },
			itemBounds = { X = { -10, 10 } },
			finite = function(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end,
			lighting = {
				GetFixtures = function(scene) return fixtures[scene] or {} end,
				ResetFixtureOverrides = function(light) light.attrs = {} end,
				Apply = function() end,
			},
			customization = {
				GetItems = function(scene) return items[scene] or {} end,
				Reset = function(object) object.attrs = {} end,
				Apply = function() end,
			},
			rememberLighting = function() env.remembered = env.remembered + 1 end,
			applyAll = function()
				env.applyAllCalls = env.applyAllCalls + 1
				if env.onApplyAll then env.onApplyAll() end
			end,
			applyDecor = function() end,
			getState = function() return {} end,
			studio = {},
			RS = { PodcastRooms = { FindFirstChild = function(_, name) return name == "Lounge" or nil end } },
			TextService = {
				FilterStringAsync = function(_, text)
					env.filterCalls = env.filterCalls + 1
					if env.onFilter then env.onFilter() end
					return { GetNonChatStringForBroadcastAsync = function() return text end }
				end,
			},
			remote = { FireClient = function(_, p, ok, message, payload) env.fired[#env.fired + 1] = { ok = ok, message = message, payload = payload } end },
			feedback = function(p, ok, message) env.feedbacks[#env.feedbacks + 1] = message end,
			setLayoutBusy = function(v) env.busy[#env.busy + 1] = v end,
			clock = function() return env.now end,
			warn = function() end,
		}

		-- Builder ---------------------------------------------------------------
		local world = { live = {}, failApply = nil, failRollback = 0, yieldOn = {} }
		function world:apply(effect)
			if self.yieldOn[effect.kind] then self.yieldOn[effect.kind] = nil coroutine.yield("world") end
			if self.failApply == effect.kind then error("world failure") end
			if effect.kind == "replace" then
				local old = self.live
				self.live = {}
				for _, e in ipairs(effect.entries) do self.live[e.id] = e.record.itemId end
				return { kind = "replace", old = old }
			end
			local previous = self.live[effect.id]
			if effect.kind == "spawn" then self.live[effect.id] = effect.record.itemId
			elseif effect.kind == "remove" then self.live[effect.id] = nil end
			return { kind = effect.kind, id = effect.id, previous = previous }
		end
		function world:rollback(token)
			if self.failRollback > 0 then self.failRollback = self.failRollback - 1 error("rollback failed") end
			if token.kind == "replace" then self.live = token.old else self.live[token.id] = token.previous end
		end
		function world:commit() end
		function world:publishRevision() end
		env.world = world
		env.core = PlacementCore.new({
			config = Config, catalog = Catalog,
			templates = { isInstalled = function() return true end, getSize = function() return { 2, 2, 2 } end },
			entitlements = { isItemUnlocked = function() return true end },
			authority = {
				check = function(_, userId) return userId == env.settings:GetAttribute("HostUserId") end,
				currentHostUserId = function() return env.settings:GetAttribute("HostUserId") end,
			},
			bounds = { halfX = 20, halfZ = 15, height = 16 },
			world = world,
			clock = function() return env.now end,
		})
		deps.builderPersistence = BuildPersistence.new(function() return env.core end)

		-- Real patched StudioPresets on a fake DataStore -------------------------
		local store = { data = {}, failGet = false }
		function store:GetAsync(key)
			if self.failGet then error("DataStore request was rejected (502)") end
			return deepCopy(self.data[key])
		end
		function store:UpdateAsync(key, fn)
			local result = fn(deepCopy(self.data[key]))
			if result ~= nil then self.data[key] = deepCopy(result) end
			return result
		end
		env.store = store
		deps.presets = H.loadIntegration("integration/StudioPresets.luau", {
			DataStoreService = { GetDataStore = function() return store end },
			HttpService = { JSONEncode = function() return "{}" end, GenerateGUID = function() return "0123456789abcdef0123456789abcdef" end },
			TextService = { FilterStringAsync = function(_, text) return { GetNonChatStringForBroadcastAsync = function() return text end } end },
		})

		local DirectorPersistence = H.loadIntegration("integration/DirectorPersistence.luau", {})
		env.dp = DirectorPersistence.new(deps)
		env.p = { UserId = A, Parent = {} }

		function env.action(action, args, player)
			env.now = env.now + 3 -- past the 2 s cooldown
			env.dp.persistentAction(player or env.p, action, args or {})
		end
		function env.place(x)
			env.now = env.now + 1
			return env.core:handle(A, { op = "Place", itemId = "cozy_plant_01", transform = { x = x, y = 0, z = 0, yaw = 0 } })
		end
		function env.transfer(userId)
			env.settings:SetAttribute("HostUserId", userId)
			env.core:onHostChanged()
		end
		function env.lastFired() return env.fired[#env.fired] end
		function env.lastFeedback() return env.feedbacks[#env.feedbacks] end
		return env
	end

	-- A saved Lounge preset with a build, written through the real Save path.
	local function saveLoungePreset(env, slot)
		local before = deepCopy(env.settings.attrs)
		env.settings:SetAttribute("SceneSet", "Lounge")
		env.settings:SetAttribute("Title", "Saved show")
		env.place(4)
		env.place(8)
		env.action("Save", { Slot = slot or 1, Name = "Lounge night" })
		T.eq(env.lastFired().ok, true, "save succeeded")
		-- Back to a different live state.
		env.settings.attrs = before
		env.now = env.now + 1
		env.core:handle(A, { op = "Delete", id = "i1" })
		env.now = env.now + 1
		env.core:handle(A, { op = "Delete", id = "i2" })
		env.place(-6) -- live build: i3 only
	end

	local function liveBuild(env)
		local ids = {}
		for _, e in ipairs(env.core:list()) do ids[#ids + 1] = e.id end
		return table.concat(ids, ",")
	end

	T.test("save then load restores room and build through the real callbacks", function()
		local env = setup()
		saveLoungePreset(env)
		env.action("Load", { Slot = 1 })
		T.eq(env.lastFired().ok, true, tostring(env.lastFeedback()))
		T.eq(env.settings:GetAttribute("SceneSet"), "Lounge")
		T.eq(env.settings:GetAttribute("Title"), "Saved show")
		T.eq(liveBuild(env), "i1,i2", "saved build restored with its IDs")
		T.eq(env.busy[1], true)
		T.eq(env.busy[2], false, "layoutBusy released")
		T.eq(env.dp.saveBlocked(A), nil)
	end)

	T.test("room failure rolls back room (no re-filtering) and build; save is latched until discard", function()
		local env = setup()
		saveLoungePreset(env)
		local roomBefore = deepCopy(env.settings.attrs)
		local fixtureBefore = deepCopy(env.fixtures.Lounge[1].Light.attrs)
		local customBefore = deepCopy(env.fixtures.Custom[1].Light.attrs)
		env.onApplyAll = function()
			env.onApplyAll = nil
			error("applyAll failed mid-switch")
		end
		local filtersBefore = env.filterCalls
		env.action("Load", { Slot = 1 })
		T.ok(env.lastFeedback() ~= nil, "failure reported")
		T.deepEq(env.settings.attrs, roomBefore, "room settings restored exactly")
		T.deepEq(env.fixtures.Custom[1].Light.attrs, customBefore, "current scene fixtures restored")
		T.deepEq(env.fixtures.Lounge[1].Light.attrs, fixtureBefore, "target scene fixture overrides restored")
		T.eq(env.filterCalls, filtersBefore + 1, "only the load's own text was filtered; rollback did not re-filter")
		T.eq(liveBuild(env), "i3", "build unchanged")
		T.eq(env.world.live.i3, "cozy_plant_01")
		T.eq(env.dp.saveBlocked(A), "LoadFailed")

		local stored = deepCopy(env.store.data)
		env.action("Save", { Slot = 2, Name = "Oops" })
		T.ok(env.lastFeedback():find("saving is paused"), env.lastFeedback())
		T.deepEq(env.store.data, stored, "nothing written while latched")
		local feedbacks, fired = #env.feedbacks, #env.fired
		env.action("Share", { Slot = 1 })
		T.eq(#env.feedbacks, feedbacks + 1, "Share answered with a refusal")
		T.eq(#env.fired, fired, "no share code issued")
		T.ok(env.lastFeedback():find("saving is paused"), "Share blocked too")

		env.action("DiscardLoadBlock")
		env.action("Save", { Slot = 2, Name = "Current" })
		T.eq(env.lastFired().ok, true)
		T.eq(env.store.data["user:1001"].Slots["2"].Name, "Current")
	end)

	T.test("builder edits and saves are blocked while the room restore yields", function()
		local env = setup()
		saveLoungePreset(env)
		env.onApplyAll = function()
			env.onApplyAll = nil
			coroutine.yield("applyAll")
		end
		local co = coroutine.create(function() env.action("Load", { Slot = 1 }) end)
		assert(coroutine.resume(co))
		T.eq(env.place(0).code, "Busy", "builder edit refused mid-load")
		T.eq(pcall(function() env.dp.snapshot() end), false, "builder capture refused mid-load")
		assert(coroutine.resume(co))
		T.eq(env.lastFired().ok, true)
		T.eq(liveBuild(env), "i1,i2")
	end)

	T.test("A -> B -> A during text filtering is refused before any mutation (build and legacy presets)", function()
		local env = setup()
		saveLoungePreset(env)
		local roomBefore = deepCopy(env.settings.attrs)
		env.onFilter = function()
			env.onFilter = nil
			env.transfer(B)
			env.transfer(A)
		end
		env.action("Load", { Slot = 1 })
		T.ok(env.lastFeedback():find("Host controls changed"), tostring(env.lastFeedback()))
		T.deepEq(env.settings.attrs, roomBefore, "room untouched")
		T.eq(env.applyAllCalls, 0)
		T.eq(liveBuild(env), "i3")

		-- Legacy (room-only) preset in slot 3.
		env.action("DiscardLoadBlock")
		env.store.data["user:1001"].Slots["3"] = { Name = "Old", Version = 1, Data = { Version = 1, Settings = { SceneSet = "Lounge", Title = "Legacy" }, Fixtures = {}, Items = {} } }
		env.onFilter = function()
			env.onFilter = nil
			env.transfer(B)
			env.transfer(A)
		end
		env.action("Load", { Slot = 3 })
		T.ok(env.lastFeedback():find("Host controls changed"))
		T.eq(env.settings:GetAttribute("Title"), roomBefore.Title)
		T.eq(env.applyAllCalls, 0)
	end)

	T.test("authority lost during the yielding room restore rolls back room and build", function()
		local env = setup()
		saveLoungePreset(env)
		local roomBefore = deepCopy(env.settings.attrs)
		env.onApplyAll = function()
			env.onApplyAll = nil
			coroutine.yield("applyAll")
		end
		local co = coroutine.create(function() env.action("Load", { Slot = 1 }) end)
		assert(coroutine.resume(co))
		env.transfer(B)
		env.transfer(A) -- same host, new host session: still lost
		assert(coroutine.resume(co))
		T.ok(env.lastFeedback():find("Host controls changed"))
		local after = deepCopy(env.settings.attrs)
		T.deepEq(after, roomBefore, "room rolled back")
		T.eq(liveBuild(env), "i3", "build rolled back")
		T.eq(env.world.live.i3, "cozy_plant_01")
	end)

	T.test("a failed build rollback latches saving and keeps the builder in recovery", function()
		local env = setup()
		saveLoungePreset(env)
		env.world.failRollback = 5
		env.onApplyAll = function()
			env.onApplyAll = nil
			error("applyAll failed")
		end
		env.action("Load", { Slot = 1 })
		T.ok(env.lastFeedback():find("couldn't be fully restored"), env.lastFeedback())
		T.eq(env.dp.saveBlocked(A), "RollbackFailed")
		T.eq(env.core:getState(), "recovery")
		T.eq(env.place(0).code, "RecoveryNeeded", "builder edits refused")
		env.action("Save", { Slot = 2, Name = "x" })
		T.ok(env.lastFeedback():find("saving is paused"))
	end)

	T.test("corrupt and newer stored builds fail before filtering, room and build untouched, and latch", function()
		local env = setup()
		saveLoungePreset(env)
		env.store.data["user:1001"].Slots["1"].Data.Build = { Version = 1, NextId = 1, Items = "broken" }
		local roomBefore = deepCopy(env.settings.attrs)
		env.action("Load", { Slot = 1 })
		T.ok(env.lastFeedback():find("can't be read"), env.lastFeedback())
		T.eq(env.filterCalls, 0, "stopped before the yielding filter")
		T.deepEq(env.settings.attrs, roomBefore)
		T.eq(liveBuild(env), "i3")
		T.eq(env.dp.saveBlocked(A), "LoadFailed")
		env.action("DiscardLoadBlock")
		env.store.data["user:1001"].Slots["1"].Data.Build = { Version = 2, NextId = 1, Items = {} }
		env.action("Load", { Slot = 1 })
		T.ok(env.lastFeedback():find("newer version"))
		T.eq(env.dp.saveBlocked(A), "LoadFailed")
	end)

	T.test("backend read failure during load enters the save block", function()
		local env = setup()
		saveLoungePreset(env)
		env.store.failGet = true
		env.action("Load", { Slot = 1 })
		T.ok(env.lastFeedback():find("unavailable"), env.lastFeedback())
		T.eq(env.dp.saveBlocked(A), "LoadFailed")
		env.store.failGet = false
		env.action("Save", { Slot = 2, Name = "x" })
		T.ok(env.lastFeedback():find("saving is paused"))
		env.action("Load", { Slot = 1 }) -- a successful load lifts the block
		T.eq(env.lastFired().ok, true)
		T.eq(env.dp.saveBlocked(A), nil)
	end)

	T.test("a slot-list refresh failure does not misreport a successful save", function()
		local env = setup()
		env.place(1)
		local realGet = env.store.GetAsync
		env.store.GetAsync = function() error("DataStore throttled") end -- List fails, UpdateAsync works
		env.action("Save", { Slot = 4, Name = "Saved anyway" })
		env.store.GetAsync = realGet
		local fired = env.lastFired()
		T.eq(fired.ok, true, "save reported as successful")
		T.ok(fired.message:find("couldn't refresh"), fired.message)
		T.eq(env.store.data["user:1001"].Slots["4"].Name, "Saved anyway")
		T.eq(env.store.data["user:1001"].Slots["4"].Data.Build.Items[1].Id, "i1")
	end)

	T.test("cooldown and busy handling are unchanged", function()
		local env = setup()
		env.dp.persistentAction(env.p, "List", {})
		env.dp.persistentAction(env.p, "List", {}) -- same clock: within 2 s
		T.eq(env.lastFeedback(), "Please wait a moment before another save request.")
	end)
end
