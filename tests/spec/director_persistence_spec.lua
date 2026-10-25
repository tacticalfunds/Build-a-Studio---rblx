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
		local env = { now = 0, fired = {}, feedbacks = {}, busy = {}, filterCalls = 0, applyAllCalls = 0, remembered = 0, roomLooks = {} }

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
			-- Live semantics: roomLooks[scene] = current light keys.
			rememberLighting = function(scene)
				env.remembered = env.remembered + 1
				env.roomLooks[scene] = { CustomLighting = env.settings:GetAttribute("CustomLighting"), Fog = env.settings:GetAttribute("Fog") }
			end,
			getRoomLook = function(scene) return env.roomLooks[scene] end,
			setRoomLook = function(scene, look) env.roomLooks[scene] = look end,
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
			setLayoutBusy = function(v)
				env.busy[#env.busy + 1] = v
				env.layoutBusy = v
			end,
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
		function world:commit()
			if (self.failCommit or 0) > 0 then self.failCommit = self.failCommit - 1 error("finalize failed") end
		end
		function world:publishRevision() end
		env.world = world
		env.core = PlacementCore.new({
			config = Config, catalog = Catalog,
			templates = { isInstalled = function() return true end, getSize = function() return { 2, 2, 2 } end },
			entitlements = { isItemUnlocked = function() return true end },
			authority = {
				check = function(_, userId)
					if env.yieldCheck then env.yieldCheck = nil coroutine.yield("check") end
					return userId == env.settings:GetAttribute("HostUserId")
				end,
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
		-- The live PodcastStudioControl handler with the documented wiring
		-- (integration/PodcastDirector.persistence.luau, edit 4): the existing
		-- layoutBusy gate, then the room-mutation gate for every non-Persist
		-- action, and the Text branch's re-check after its filter yields.
		env.layoutBusy = false
		local function refused(p, message)
			deps.feedback(p, false, message)
			return false
		end
		function env.command(p, action, key, value)
			if env.layoutBusy then
				return refused(p, "The studio layout is changing.")
			end
			if action ~= "Persist" and env.dp.roomMutationBlocked() then
				return refused(p, env.dp.ROOM_MUTATION_MESSAGE)
			end
			local scene = env.settings:GetAttribute("SceneSet") or "Custom"
			if action == "Set" then
				env.settings:SetAttribute(key, value)
			elseif action == "Fixture" then
				fixtures[scene][1].Light:SetAttribute(key, value)
			elseif action == "Item" then
				items[scene][1].Object:SetAttribute(key, value)
			elseif action == "Look" then
				env.roomLooks[scene] = { Fog = value }
			elseif action == "Text" then
				local filtered = value
				if env.onCommandFilter then env.onCommandFilter() end -- TextService yields
				if not (p.Parent ~= nil and p.UserId == env.settings:GetAttribute("HostUserId")) then
					return refused(p, "Host controls changed.")
				end
				if env.layoutBusy or env.dp.roomMutationBlocked() then
					return refused(p, env.dp.ROOM_MUTATION_MESSAGE)
				end
				env.settings:SetAttribute(key, filtered)
			elseif action == "Persist" then
				env.now = env.now + 3
				env.dp.persistentAction(p, key, value or {})
			end
			return true
		end
		function env.roomState()
			return deepCopy({ settings = env.settings.attrs, looks = env.roomLooks,
				C1 = fixtures.Custom[1].Light.attrs, L1 = fixtures.Lounge[1].Light.attrs,
				CI = items.Custom[1].Object.attrs, LI = items.Lounge[1].Object.attrs })
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
		T.ok(env.lastFeedback():find("still being restored"), env.lastFeedback())
		T.eq(env.store.data["user:1001"].Slots["2"], nil)
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

	-- Recovery checkpoint (review of e30e8be) --------------------------------------

	T.test("room rollback failure keeps shared compound recovery: edits/saves blocked across host transfer, Discard refused, only recovery clears", function()
		local env = setup()
		saveLoungePreset(env)
		local roomBefore = deepCopy(env.settings.attrs)
		env.onApplyAll = function() error("applyAll broken") end -- fails during load AND rollback
		env.action("Load", { Slot = 1 })
		T.eq(env.dp.saveBlocked(A), "RollbackFailed")
		T.eq(env.core:getState(), "recovery", "builder must stay in recovery while the room is unrestored")
		T.eq(env.place(0).code, "RecoveryNeeded", "builder edits refused")
		env.action("DiscardLoadBlock")
		env.action("Save", { Slot = 2, Name = "x" })
		T.eq(env.store.data["user:1001"].Slots["2"], nil, "Discard does not bypass compound recovery")
		-- Host transfer: the new host is blocked too.
		env.transfer(B)
		local bp = { UserId = B, Parent = {} }
		env.now = env.now + 1
		T.eq(env.core:handle(B, { op = "Place", itemId = "cozy_plant_01", transform = { x = 1, y = 0, z = 0, yaw = 0 } }).code, "RecoveryNeeded")
		local storedBefore = deepCopy(env.store.data)
		env.action("Save", { Slot = 1, Name = "B's" }, bp)
		T.deepEq(env.store.data, storedBefore, "new host cannot save during recovery")
		-- applyAll works again: recovery restores the captured room and lifts the block.
		env.onApplyAll = nil
		T.eq(env.core:recover(), true)
		T.deepEq(env.settings.attrs.Title, roomBefore.Title, "captured room restored by recovery")
		T.eq(env.settings:GetAttribute("SceneSet"), roomBefore.SceneSet)
		env.transfer(A)
		T.eq(env.place(0).ok, true)
		env.action("Save", { Slot = 2, Name = "After recovery" })
		T.eq(env.lastFired().ok, true)
	end)

	T.test("finalize failure after a load reports incomplete loading and keeps saving paused until reconciled", function()
		local env = setup()
		saveLoungePreset(env)
		env.world.failCommit = 2 -- the load's finalize and the retry during Save both fail
		local fired = #env.fired
		env.action("Load", { Slot = 1 })
		T.eq(#env.fired, fired, "not reported as a successful load")
		T.ok(env.lastFeedback():find("still being restored"), tostring(env.lastFeedback()))
		T.eq(env.core:getState(), "recovery")
		T.eq(env.dp.saveBlocked(A), "BuildRecovery")
		env.action("Save", { Slot = 2, Name = "x" })
		T.eq(env.store.data["user:1001"].Slots["2"], nil)
		T.eq(env.core:recover(), true) -- finalize retried
		env.action("Save", { Slot = 2, Name = "Now" })
		T.eq(env.lastFired().ok, true)
	end)

	T.test("beginTransaction takes the lock before yielding authority checks", function()
		local env = setup()
		local persistence = BuildPersistence.new(function() return env.core end)
		local staged = persistence:prepareLoad(A, { Version = 1, Settings = {} })
		env.yieldCheck = true
		local first, firstErr
		local co = coroutine.create(function()
			local ok, txn = pcall(function() return persistence:begin(A, staged) end)
			first, firstErr = ok and txn or nil, not ok and txn or nil
		end)
		assert(coroutine.resume(co)) -- paused inside authority.check
		local secondOk = pcall(function() return persistence:begin(A, staged) end)
		T.eq(secondOk, false, "second transaction refused while the first holds the lock")
		assert(coroutine.resume(co))
		T.ok(first ~= nil, tostring(firstErr))
		T.eq(env.core:getState(), "busy")
		first:rollback()
		T.eq(env.core:getState(), "ready")
	end)

	T.test("a refused begin after a yielding check releases the lock", function()
		local env = setup()
		local persistence = BuildPersistence.new(function() return env.core end)
		local staged = persistence:prepareLoad(A, { Version = 1, Settings = {} })
		env.yieldCheck = true
		local ok
		local co = coroutine.create(function() ok = pcall(function() return persistence:begin(A, staged) end) end)
		assert(coroutine.resume(co))
		env.transfer(B)
		assert(coroutine.resume(co))
		T.eq(ok, false)
		T.eq(env.core:getState(), "ready")
	end)

	T.test("a failed load restores the previous roomLooks entry exactly, including absence", function()
		local env = setup()
		saveLoungePreset(env)
		env.roomLooks.Custom = nil
		env.onApplyAll = function() env.onApplyAll = nil error("boom") end
		env.action("Load", { Slot = 1 })
		T.eq(env.remembered > 0, true, "the load did call rememberLighting")
		T.eq(env.roomLooks.Custom, nil, "absent entry restored as absent")
		env.action("DiscardLoadBlock")
		env.roomLooks.Custom = { CustomLighting = true, Fog = 0.9 }
		env.onApplyAll = function() env.onApplyAll = nil error("boom") end
		env.action("Load", { Slot = 1 })
		T.deepEq(env.roomLooks.Custom, { CustomLighting = true, Fog = 0.9 }, "previous entry restored exactly")
	end)

	-- Room-mutation gate (review of ce59b1d) ----------------------------------------

	-- A failed load whose room rollback also fails: compound recovery, with
	-- the Director's layoutBusy already back to false.
	local function enterCompoundRecovery(env)
		saveLoungePreset(env)
		local captured = env.roomState()
		env.onApplyAll = function() error("applyAll broken") end
		env.action("Load", { Slot = 1 })
		T.eq(env.core:getState(), "recovery")
		T.eq(env.layoutBusy, false, "precondition: layoutBusy is false while recovery is unresolved")
		return captured
	end

	T.test("room commands are refused while recovery is unresolved and during a yielded background recovery attempt", function()
		local env = setup()
		local captured = enterCompoundRecovery(env)
		local bp = { UserId = B, Parent = {} }
		-- Unresolved, between attempts.
		T.eq(env.command(env.p, "Set", "Title", "Between attempts"), false)
		T.eq(env.dp.roomMutationBlocked(), true)
		-- The background retry (BuilderService calls core:recover()); the room
		-- restore yields inside applyAll after writing the captured settings.
		env.onApplyAll = function()
			env.onApplyAll = nil
			coroutine.yield("applyAll")
		end
		local co = coroutine.create(function() return env.core:recover() end)
		local resumed, where = coroutine.resume(co)
		T.ok(resumed and where == "applyAll", "recovery attempt yielded in applyAll")
		T.eq(env.layoutBusy, false)
		T.eq(env.command(env.p, "Set", "Title", "Hijack"), false, "Set refused mid-recovery")
		T.eq(env.command(env.p, "Set", "Brightness", 0.1), false)
		T.eq(env.command(env.p, "Fixture", "LightIntensity", 9), false)
		T.eq(env.command(env.p, "Item", "StudioMoveX", 7), false)
		T.eq(env.command(env.p, "Look", nil, 0.9), false)
		T.eq(env.command(env.p, "Text", "Title", "Typed"), false)
		T.eq(env.command(bp, "Set", "Title", "Other player"), false)
		T.eq(env.lastFeedback(), env.dp.ROOM_MUTATION_MESSAGE)
		-- Builder edits and capture stay refused (core behaviour unchanged).
		T.eq(env.place(0).code, "RecoveryNeeded")
		T.eq(pcall(function() env.dp.snapshot() end), false)
		-- The recovery route stays open: status, List, and Persist retries.
		env.now = env.now + 1
		local status = env.core:handle(A, { op = "Status" })
		T.eq(status.ok, true)
		T.eq(status.status.state, "recovery")
		env.command(env.p, "Persist", "List")
		T.eq(env.lastFired().ok, true, "List works during recovery")
		local storedBefore = deepCopy(env.store.data)
		env.command(env.p, "Persist", "Save", { Slot = 2, Name = "mid" })
		T.eq(env.lastFeedback(), "The studio is still being restored after a failed load. Saving and loading are paused until that finishes.")
		T.deepEq(env.store.data, storedBefore)
		-- The attempt finishes: exactly the captured state, nothing mixed in.
		local finished, recovered = coroutine.resume(co)
		T.ok(finished, tostring(recovered))
		T.eq(recovered, true)
		T.eq(coroutine.status(co), "dead")
		T.deepEq(env.roomState(), captured, "recovery restored exactly the captured room")
		-- Resolved: the gate lifts.
		T.eq(env.dp.roomMutationBlocked(), false)
		T.eq(env.command(env.p, "Set", "Title", "After recovery"), true)
		T.eq(env.settings:GetAttribute("Title"), "After recovery")
	end)

	T.test("a failed recovery attempt keeps the gate closed; a Persist-triggered retry holds it too", function()
		local env = setup()
		local captured = enterCompoundRecovery(env)
		-- An attempt that yields, then fails again: still unresolved, still gated.
		env.onApplyAll = function()
			coroutine.yield("applyAll")
			error("still broken")
		end
		local co = coroutine.create(function() return env.core:recover() end)
		assert(coroutine.resume(co))
		T.eq(env.command(env.p, "Set", "Title", "Hijack"), false)
		local _, recovered = coroutine.resume(co)
		T.eq(recovered, false)
		T.eq(env.dp.roomMutationBlocked(), true, "gate never drops while recovery is unresolved")
		T.eq(env.command(env.p, "Set", "Title", "Hijack"), false)
		-- Recovery driven from a Persist action (it retries first); its room
		-- restore yields, and room commands are refused meanwhile.
		env.onApplyAll = function()
			env.onApplyAll = nil
			coroutine.yield("applyAll")
		end
		local persist = coroutine.create(function() env.command(env.p, "Persist", "List") end)
		assert(coroutine.resume(persist))
		T.eq(coroutine.status(persist), "suspended")
		T.eq(env.command(env.p, "Fixture", "LightIntensity", 9), false)
		T.eq(env.command(env.p, "Set", "Title", "Hijack"), false)
		assert(coroutine.resume(persist))
		T.eq(env.lastFired().ok, true)
		T.eq(env.core:getState(), "ready")
		T.deepEq(env.roomState(), captured)
		T.eq(env.command(env.p, "Set", "Title", "Free"), true)
	end)

	T.test("a Text command whose filter was in flight is refused when it returns after a failed load entered recovery", function()
		local env = setup()
		saveLoungePreset(env)
		local captured = env.roomState()
		env.onCommandFilter = function()
			env.onCommandFilter = nil
			coroutine.yield("filter")
		end
		local text = coroutine.create(function() return env.command(env.p, "Text", "Title", "Typed earlier") end)
		assert(coroutine.resume(text))
		T.eq(coroutine.status(text), "suspended", "text filter in flight")
		-- Meanwhile a load fails and its room rollback fails: compound recovery.
		env.onApplyAll = function() error("applyAll broken") end
		env.action("Load", { Slot = 1 })
		T.eq(env.core:getState(), "recovery")
		T.eq(env.layoutBusy, false)
		local _, applied = coroutine.resume(text)
		T.eq(applied, false, "the in-flight Text write is refused by the re-check")
		T.eq(env.lastFeedback(), env.dp.ROOM_MUTATION_MESSAGE)
		T.ok(env.settings:GetAttribute("Title") ~= "Typed earlier")
		env.onApplyAll = nil
		T.eq(env.core:recover(), true)
		T.deepEq(env.roomState(), captured, "recovery restores the captured room; the text never landed")
	end)

	T.test("a Text command whose filter returns while a load is in flight is refused, even if layoutBusy is not set by the caller", function()
		local env = setup()
		saveLoungePreset(env)
		local data = env.dp.snapshot() -- a valid preset to load directly
		env.onCommandFilter = function()
			env.onCommandFilter = nil
			coroutine.yield("filter")
		end
		local text = coroutine.create(function() return env.command(env.p, "Text", "Title", "Typed earlier") end)
		assert(coroutine.resume(text))
		-- A direct restoreSnapshot (no persistentAction, so no layoutBusy) yielding in applyAll.
		env.onApplyAll = function()
			env.onApplyAll = nil
			coroutine.yield("applyAll")
		end
		local load = coroutine.create(function() env.dp.restoreSnapshot(env.p, data) end)
		assert(coroutine.resume(load))
		T.eq(coroutine.status(load), "suspended")
		T.eq(env.layoutBusy, false)
		T.eq(env.dp.roomMutationBlocked(), true, "a load in flight holds the gate")
		local _, applied = coroutine.resume(text)
		T.eq(applied, false)
		T.eq(env.command(env.p, "Set", "Title", "Hijack"), false)
		local ok, err = coroutine.resume(load)
		T.ok(ok, tostring(err))
		T.eq(coroutine.status(load), "dead")
		T.eq(env.dp.roomMutationBlocked(), false, "released when the load finishes")
		T.eq(env.settings:GetAttribute("Title"), data.Settings.Title)
		-- A failing direct load also releases its count (and errors as before).
		T.eq(pcall(env.dp.restoreSnapshot, env.p, { Version = 2 }), false)
		T.eq(env.dp.roomMutationBlocked(), false)
	end)

	T.test("cooldown and busy handling are unchanged", function()
		local env = setup()
		env.dp.persistentAction(env.p, "List", {})
		env.dp.persistentAction(env.p, "List", {}) -- same clock: within 2 s
		T.eq(env.lastFeedback(), "Please wait a moment before another save request.")
	end)
end
