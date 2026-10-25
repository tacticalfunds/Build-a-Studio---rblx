-- Task 7 foundation: the pure seat-assignment model (SeatAssignments) and
-- seat profiles (SeatProfiles), plus contract checks against the attached
-- bb3efa6 live source snapshot (docs/studio-reference/).
--
-- The seat profiles used here are TEST FIXTURES ONLY. Real anchor metadata
-- comes from Codex; SeatProfiles.Profiles ships empty.
return function(T, H)
	local SeatAssignments = H.load("src/server/Core/SeatAssignments")
	local SeatProfiles = H.load("src/shared/SeatProfiles")
	local PlacementCore = H.load("src/server/Core/PlacementCore")
	local BuildPersistence = H.load("src/server/Core/BuildPersistence")
	local Catalog = H.load("src/shared/Catalog")
	local Config = H.load("src/shared/Config")
	local Codes = SeatAssignments.Codes

	local A, B = 1001, 2002

	local FIXTURE_PROFILES = {
		cozy_armchair_01 = { Version = 1, PoseProfile = "Chair", Anchors = { Seat = { X = 0, Y = 1.5, Z = 0.2, Yaw = 0 } } },
		cozy_coffee_table_01 = { Version = 1, PoseProfile = "Couch", Anchors = { Left = { X = -1, Y = 1, Z = 0, Yaw = 0 }, Right = { X = 1, Y = 1, Z = 0, Yaw = 0 } } },
	}

	-- Reference snapshot ---------------------------------------------------------
	local REFERENCE = "docs/studio-reference/Studio_Persistence_bb3efa6_Source_Backup.json"
	local referenceText
	local function referenceSource(path)
		referenceText = referenceText or H.readFile(H.ROOT .. "/" .. REFERENCE)
		local at = referenceText:find('"Path": "' .. path .. '"', 1, true)
		assert(at, "reference script missing: " .. path)
		local s = select(2, referenceText:find('"Source": "', at, true))
		local out, i = {}, s + 1
		while true do
			local c = referenceText:sub(i, i)
			if c == '"' then break end
			if c == "\\" then
				local n = referenceText:sub(i + 1, i + 1)
				local map = { n = "\n", r = "\r", t = "\t", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
				if n == "u" then
					out[#out + 1] = "?"
					i = i + 6
				else
					out[#out + 1] = map[n] or n
					i = i + 2
				end
			else
				out[#out + 1] = c
				i = i + 1
			end
		end
		return (table.concat(out):gsub("\r", ""))
	end

	-- Model on a fake live build ---------------------------------------------------
	local function setup(options)
		options = options or {}
		local env = { host = A, epoch = 0, occupied = {}, items = {} }
		env.items.i1 = { itemId = "cozy_armchair_01" }
		env.items.i2 = { itemId = "cozy_armchair_01" }
		env.items.i3 = { itemId = "cozy_plant_01" } -- decorative
		env.items.i4 = { itemId = "cozy_coffee_table_01" } -- Couch profile (fixture)
		env.seats = SeatAssignments.new({
			profiles = options.profiles or FIXTURE_PROFILES,
			catalog = Catalog,
			getItem = function(id) return env.items[id] end,
			isHost = function(userId) return userId == env.host end,
			hostEpoch = function() return env.epoch end,
			isSlotOccupied = function(slot)
				if env.occupiedError then error("seat read failed") end
				return env.occupied[slot] == true
			end,
			couchPosesEnabled = options.couch,
		})
		function env.ctx(userId) return { userId = userId or env.host, epoch = env.epoch } end
		function env.assign(slot, id, anchor, rev) return env.seats:assign(env.ctx(), slot, id, anchor, rev) end
		return env
	end

	local function unchangedBy(env, fn)
		local before = env.seats:status()
		local result = fn()
		T.deepEq(env.seats:status(), before, "a refusal must not change state or revision")
		return result
	end

	-- Contract checks against the live source ---------------------------------------

	T.test("live contracts from the bb3efa6 snapshot: four seats, slot range, pose modes, Lounge-only couch poses", function()
		local poses = referenceSource("ServerScriptService.PodcastPoses")
		local modes = poses:match("local modes=(%b{})")
		T.ok(modes, "PodcastPoses modes table")
		local live = {}
		for name in modes:gmatch("(%w+)=true") do live[name] = true end
		T.deepEq(live, SeatProfiles.LivePoseModes, "LivePoseModes mirrors the live server's modes")
		T.ok(poses:find('(mode=="CouchSide" or mode=="CouchRecline") and RS.PodcastSettings:GetAttribute("SceneSet")~="Lounge"', 1, true), "couch modes are Lounge-only in the live server")
		for name, profile in pairs(SeatProfiles.PoseProfiles) do
			for _, mode in ipairs(profile.modes) do
				T.ok(live[mode], name .. " uses only live modes: " .. mode)
			end
		end
		T.eq(SeatProfiles.PoseProfiles.Couch.needsLivePosePatch, true)
		local seating = referenceSource("ServerScriptService.PodcastSeating")
		T.ok(seating:find("index<1 or index>4", 1, true), "PodcastSeating accepts seat indexes 1..4")
		local layout = referenceSource("ServerScriptService.StudioLayout")
		T.ok(layout:find('for i=1,4 do poses[i]=seats["Seat"..i]:GetAttribute("CustomSeatCFrame") end', 1, true), "StudioLayout drives Seat1..Seat4")
		T.ok(layout:find('root.CameraShots["Seat"..i].Value=', 1, true) and layout:find('root.CameraShots["POV"..i].Value=', 1, true), "camera shots follow the seat CFrames")
		T.eq(Config.SeatSlotCount, 4)
		T.eq(#SeatProfiles.SlotNames, 4)
		local director = referenceSource("ServerScriptService.PodcastDirector")
		T.ok(director:find('SeatLabel1="HOST",SeatLabel2="GUEST 01",SeatLabel3="GUEST 02",SeatLabel4="GUEST 03"', 1, true), "slot 1 is the host seat")
	end)

	T.test("StudioCustomization only walks the selected room root, never the builder folder (actual isolation, no tag guard)", function()
		local source = referenceSource("ReplicatedStorage.StudioCustomization")
		T.ok(source:find('if scene=="Custom" then return workspace.PodcastStudio end', 1, true))
		T.ok(source:find('return workspace:FindFirstChild(c:GetAttribute("ModelName"),true)', 1, true))
		T.ok(source:find('if scene=="Custom" then return result end', 1, true), "Custom room returns no editable items")
		T.eq(source:find("BuildItemId", 1, true), nil, "no BuildItemId guard exists today")
		T.eq(source:find("StudioBuilderPlacedItems", 1, true), nil)
		T.eq(Config.PlacedItemsFolderName, "StudioBuilderPlacedItems")
	end)

	-- Profiles ------------------------------------------------------------------------

	T.test("profiles ship empty: every catalog item is decorative by default", function()
		T.eq(next(SeatProfiles.Profiles), nil)
		local env = setup({ profiles = SeatProfiles.Profiles })
		T.eq(env.seats:profileFor("cozy_armchair_01"), nil)
		T.eq(unchangedBy(env, function() return env.assign(1, "i1", "Seat") end).code, Codes.NotSeatCapable)
	end)

	T.test("profile validation refuses malformed or unknown entries; invalid profiles stay decorative", function()
		local bad = {
			cozy_armchair_01 = { Version = 2, PoseProfile = "Chair", Anchors = { Seat = { X = 0, Y = 0, Z = 0, Yaw = 0 } } },
			cozy_bookshelf_01 = { Version = 1, PoseProfile = "Bench", Anchors = { Seat = { X = 0, Y = 0, Z = 0, Yaw = 0 } } },
			cozy_plant_01 = { Version = 1, PoseProfile = "Chair", Anchors = { ["9bad"] = { X = 0, Y = 0, Z = 0, Yaw = 0 } } },
			cozy_floor_lamp_01 = { Version = 1, PoseProfile = "Chair", Anchors = { Seat = { X = 0 / 0, Y = 0, Z = 0, Yaw = 0 } } },
			retro_tv_cart_01 = { Version = 1, PoseProfile = "Chair", Anchors = {} },
			retro_cassette_01 = { Version = 1, PoseProfile = "Chair", Anchors = { Seat = { X = 0, Y = 0, Z = 0, Yaw = 0, Scale = 2 } } },
			not_in_catalog = { Version = 1, PoseProfile = "Chair", Anchors = { Seat = { X = 0, Y = 0, Z = 0, Yaw = 0 } } },
			cozy_coffee_table_01 = { Version = 1, PoseProfile = "Chair", Anchors = { A = { X = 0, Y = 0, Z = 0, Yaw = 0 }, B = { X = 0, Y = 0, Z = 0, Yaw = 0 }, C = { X = 0, Y = 0, Z = 0, Yaw = 0 }, D = { X = 0, Y = 0, Z = 0, Yaw = 0 }, E = { X = 0, Y = 0, Z = 0, Yaw = 0 } } },
		}
		local problems = SeatProfiles.validate(bad, Catalog)
		T.deepEq(problems, {
			cozy_armchair_01 = "BadVersion",
			cozy_bookshelf_01 = "UnknownPoseProfile",
			cozy_plant_01 = "BadAnchor",
			cozy_floor_lamp_01 = "BadAnchor",
			retro_tv_cart_01 = "BadAnchors",
			retro_cassette_01 = "BadAnchor",
			not_in_catalog = "UnknownCatalogItem",
			cozy_coffee_table_01 = "BadAnchors",
		})
		T.deepEq(SeatProfiles.validate(FIXTURE_PROFILES, Catalog), {})
		local env = setup({ profiles = bad })
		T.eq(env.seats:profileFor("cozy_armchair_01"), nil)
		T.eq(env.seats:profileProblems().cozy_armchair_01, "BadVersion")
		T.eq(env.assign(1, "i1", "Seat").code, Codes.NotSeatCapable)
	end)

	T.test("profiles with unknown top-level keys are refused (strict schema) and stay decorative", function()
		local anchors = { Seat = { X = 0, Y = 1.5, Z = 0.2, Yaw = 0 } }
		local profiles = {
			cozy_armchair_01 = { Version = 1, PoseProfile = "Chair", Anchors = anchors, Scale = 99 },
			cozy_bookshelf_01 = { Version = 1, PoseProfile = "Chair", Anchors = anchors, AvatarOffset = { Y = 2 } },
		}
		T.deepEq(SeatProfiles.validate(profiles, Catalog), { cozy_armchair_01 = "UnknownKey", cozy_bookshelf_01 = "UnknownKey" })
		local env = setup({ profiles = profiles })
		T.eq(env.seats:profileFor("cozy_armchair_01"), nil)
		T.eq(env.seats:profileProblems().cozy_armchair_01, "UnknownKey")
		T.eq(env.assign(1, "i1", "Seat").code, Codes.NotSeatCapable)
		-- The same profile without the extra key is accepted.
		T.deepEq(SeatProfiles.validate({ cozy_armchair_01 = { Version = 1, PoseProfile = "Chair", Anchors = anchors } }, Catalog), {})
	end)

	T.test("a section with an unknown top-level key is refused before load, so nothing is silently dropped on re-save", function()
		local env = setup()
		T.eq(env.assign(1, "i1", "Seat").ok, true)
		local before = env.seats:status()
		local staged, code = env.seats:prepareLoad({ Version = 1, Assignments = {}, FutureMetadata = { important = true } }, function() return nil end)
		T.eq(staged, nil)
		T.eq(code, Codes.Corrupt)
		T.deepEq(env.seats:status(), before, "refused load changes nothing")
		for key in pairs(env.seats:encode()) do
			T.ok(key == "Version" or key == "Assignments", "encode writes only the schema keys: " .. tostring(key))
		end
	end)

	-- Assign / unassign -------------------------------------------------------------------

	T.test("assign validates host, session, slot, item, profile, anchor and pose; refusals change nothing", function()
		local env = setup()
		T.eq(unchangedBy(env, function() return env.seats:assign(env.ctx(B), 1, "i1", "Seat") end).code, Codes.NotHost)
		T.eq(unchangedBy(env, function() return env.seats:assign({ userId = A, epoch = env.epoch - 1 }, 1, "i1", "Seat") end).code, Codes.AuthorityLost)
		T.eq(unchangedBy(env, function() return env.seats:assign({ userId = A }, 1, "i1", "Seat") end).code, Codes.BadRequest)
		T.eq(unchangedBy(env, function() return env.seats:assign(nil, 1, "i1", "Seat") end).code, Codes.BadRequest)
		for _, slot in ipairs({ 0, 5, 1.5, "1", -1, 0 / 0 }) do
			T.eq(unchangedBy(env, function() return env.assign(slot, "i1", "Seat") end).code, Codes.BadSlot, "slot " .. tostring(slot))
		end
		T.eq(unchangedBy(env, function() return env.assign(1, "x1", "Seat") end).code, Codes.BadRequest)
		T.eq(unchangedBy(env, function() return env.assign(1, "i1", "../Seat") end).code, Codes.BadRequest)
		T.eq(unchangedBy(env, function() return env.assign(1, { "i1" }, "Seat") end).code, Codes.BadRequest)
		T.eq(unchangedBy(env, function() return env.assign(1, "i99", "Seat") end).code, Codes.NotFound)
		T.eq(unchangedBy(env, function() return env.assign(1, "i3", "Seat") end).code, Codes.NotSeatCapable, "decorative plant")
		T.eq(unchangedBy(env, function() return env.assign(1, "i1", "Left") end).code, Codes.UnknownAnchor)
		T.eq(unchangedBy(env, function() return env.assign(1, "i4", "Left") end).code, Codes.UnsupportedPose, "Couch needs the live pose patch")
		local ok = env.assign(1, "i1", "Seat")
		T.eq(ok.ok, true)
		T.eq(ok.revision, 1)
		T.deepEq(env.seats:status().active, { [1] = { itemId = "i1", anchor = "Seat" } })
		local couch = setup({ couch = true })
		T.eq(couch.assign(2, "i4", "Left").ok, true, "allowed once couch poses are enabled")
	end)

	T.test("assignments are unique per anchor; re-assigning the same target is a no-op; stale revisions are refused", function()
		local env = setup({ couch = true })
		T.eq(env.assign(1, "i1", "Seat").ok, true)
		T.eq(unchangedBy(env, function() return env.assign(2, "i1", "Seat") end).code, Codes.AnchorTaken)
		local same = env.assign(1, "i1", "Seat")
		T.eq(same.ok, true)
		T.eq(same.unchanged, true)
		T.eq(env.seats:status().revision, 1)
		T.eq(env.assign(2, "i4", "Left").ok, true)
		T.eq(env.assign(3, "i4", "Right").ok, true, "two anchors on one item are separate seats")
		T.eq(unchangedBy(env, function() return env.assign(4, "i2", "Seat", 1) end).code, Codes.StaleRevision)
		T.eq(env.assign(4, "i2", "Seat", 3).ok, true)
		-- Re-pointing slot 1 at another item frees the old anchor.
		env.items.i5 = { itemId = "cozy_armchair_01" }
		T.eq(env.assign(1, "i5", "Seat").ok, true)
		T.eq(env.assign(1, "i1", "Seat").ok, true)
	end)

	T.test("occupied seats are protected: no reassign or unassign; an unreadable occupancy counts as occupied", function()
		local env = setup()
		T.eq(env.assign(1, "i1", "Seat").ok, true)
		env.occupied[1] = true
		T.eq(unchangedBy(env, function() return env.assign(1, "i2", "Seat") end).code, Codes.SeatOccupied)
		T.eq(unchangedBy(env, function() return env.seats:unassign(env.ctx(), 1) end).code, Codes.SeatOccupied)
		env.occupied[2] = true
		T.eq(unchangedBy(env, function() return env.assign(2, "i2", "Seat") end).code, Codes.SeatOccupied, "an occupied room seat can't jump to a builder anchor")
		env.occupied = {}
		env.occupiedError = true
		T.eq(unchangedBy(env, function() return env.assign(2, "i2", "Seat") end).code, Codes.SeatOccupied)
		env.occupiedError = nil
		T.eq(env.seats:unassign(env.ctx(), 1).ok, true)
		T.eq(env.seats:unassign(env.ctx(), 1).code, Codes.NothingAssigned)
	end)

	T.test("host transfer: assignments are shared studio state; the old session's request is refused; the new host edits", function()
		local env = setup()
		local oldCtx = env.ctx()
		T.eq(env.assign(1, "i1", "Seat").ok, true)
		env.host, env.epoch = B, env.epoch + 1 -- PlacementCore:onHostChanged bumps the epoch
		T.eq(env.seats:assign(oldCtx, 2, "i2", "Seat").code, Codes.NotHost)
		env.host = A
		T.eq(env.seats:assign(oldCtx, 2, "i2", "Seat").code, Codes.AuthorityLost, "A -> B -> A: the old session is stale")
		env.host = B
		T.deepEq(env.seats:status().active[1], { itemId = "i1", anchor = "Seat" }, "kept across transfer")
		T.eq(env.seats:assign(env.ctx(B), 2, "i2", "Seat").ok, true)
	end)

	-- Placement effects (real PlacementCore effect shapes) ------------------------------

	local function coreSetup()
		local env = setup()
		local effects = {}
		local world = { live = {} }
		function world:apply(effect)
			effects[#effects + 1] = effect
			return { kind = effect.kind }
		end
		function world:rollback() end
		function world:commit() end
		function world:publishRevision() end
		env.effects = effects
		env.now = 0
		env.core = PlacementCore.new({
			config = Config, catalog = Catalog,
			templates = { isInstalled = function() return true end, getSize = function() return { 2, 2, 2 } end },
			entitlements = { isItemUnlocked = function() return true end },
			authority = { check = function(_, userId) return userId == env.host end, currentHostUserId = function() return env.host end },
			bounds = { halfX = 20, halfZ = 15, height = 16 },
			world = world,
			clock = function() return env.now end,
		})
		-- The model reads the real core's build and epoch.
		env.items = setmetatable({}, { __index = function(_, id) return env.core.model:get(id) end })
		env.seats = SeatAssignments.new({
			profiles = FIXTURE_PROFILES, catalog = Catalog,
			getItem = function(id) return env.core.model:get(id) end,
			isHost = function(userId) return userId == env.host end,
			hostEpoch = function() return env.core.hostEpoch end,
			isSlotOccupied = function(slot) return env.occupied[slot] == true end,
		})
		function env.ctx() return { userId = env.host, epoch = env.core.hostEpoch } end
		function env.req(payload)
			env.now = env.now + 1
			local before = #effects
			local response = env.core:handle(env.host, payload)
			return response, effects[before + 1]
		end
		return env
	end

	T.test("PlacementCore effects: Move/Rotate/Undo/Redo moves re-anchor or refuse when occupied; Delete and Undo-of-Place refuse while assigned; Duplicate spawns freely", function()
		local env = coreSetup()
		local placed = env.req({ op = "Place", itemId = "cozy_armchair_01", transform = { x = 0, y = 0, z = 0, yaw = 0 } })
		T.eq(placed.id, "i1")
		T.eq(env.seats:assign(env.ctx(), 1, "i1", "Seat").ok, true)

		local _, move = env.req({ op = "Move", id = "i1", transform = { x = 2, y = 0, z = 0, yaw = 0 } })
		local ok, code, slots = env.seats:checkEffect(move)
		T.eq(move.kind, "move")
		T.eq(ok, true)
		T.deepEq(slots, { 1 }, "slot 1 must be re-anchored after the move")
		local _, rotate = env.req({ op = "Rotate", id = "i1" })
		T.eq(rotate.kind, "move")
		env.occupied[1] = true
		ok, code = env.seats:checkEffect(rotate)
		T.eq(ok, false)
		T.eq(code, Codes.SeatOccupied)
		local _, undoMove = env.req({ op = "Undo" })
		T.eq(undoMove.kind, "move")
		T.eq(select(2, env.seats:checkEffect(undoMove)), Codes.SeatOccupied)
		local _, redoMove = env.req({ op = "Redo" })
		T.eq(redoMove.kind, "move")
		T.eq(select(2, env.seats:checkEffect(redoMove)), Codes.SeatOccupied)
		env.occupied[1] = nil

		local dup, spawn = env.req({ op = "Duplicate", id = "i1" })
		T.eq(spawn.kind, "spawn")
		T.eq((env.seats:checkEffect(spawn)), true)
		T.eq(env.seats:slotsForItem(dup.id)[1], nil, "a duplicate is never assigned")

		local _, remove = env.req({ op = "Delete", id = "i1" })
		T.eq(remove.kind, "remove")
		ok, code = env.seats:checkEffect(remove)
		T.eq(ok, false)
		T.eq(code, Codes.SeatAssigned)
		env.occupied[1] = true
		T.eq(select(2, env.seats:checkEffect(remove)), Codes.SeatOccupied)
		env.occupied[1] = nil
		-- Undo of a Place is a remove too.
		local other = env.req({ op = "Place", itemId = "cozy_armchair_01", transform = { x = -4, y = 0, z = 0, yaw = 0 } })
		T.eq(env.seats:assign(env.ctx(), 2, other.id, "Seat").ok, true)
		local _, undoPlace = env.req({ op = "Undo" })
		T.eq(undoPlace.kind, "remove")
		T.eq(undoPlace.id, other.id)
		T.eq(select(2, env.seats:checkEffect(undoPlace)), Codes.SeatAssigned)
		-- Unassigned items stay freely editable.
		T.eq((env.seats:checkEffect({ kind = "remove", id = dup.id })), true)
		T.eq(env.seats:checkEffect({ kind = "explode", id = "i1" }), false)
	end)

	T.test("a build load (replace effect) is refused while an assigned seat is occupied", function()
		local env = coreSetup()
		env.req({ op = "Place", itemId = "cozy_armchair_01", transform = { x = 0, y = 0, z = 0, yaw = 0 } })
		T.eq(env.seats:assign(env.ctx(), 1, "i1", "Seat").ok, true)
		local persistence = BuildPersistence.new(function() return env.core end)
		local data = persistence:attachBuild({ Version = 1, Settings = {} })
		local staged = persistence:prepareLoad(A, data)
		local txn = persistence:begin(A, staged)
		local before = #env.effects
		txn:applyBuild()
		local effect = env.effects[before + 1]
		T.eq(effect.kind, "replace", "the real load path applies a replace effect")
		T.eq((env.seats:checkEffect(effect)), true)
		env.occupied[1] = true
		local ok, code, slots = env.seats:checkEffect(effect)
		T.eq(ok, false)
		T.eq(code, Codes.SeatOccupied)
		T.deepEq(slots, { 1 })
		txn:rollback()
	end)

	-- Reconcile, room switching, save compatibility ---------------------------------------

	T.test("reconcile keeps invalid assignments as preserved (never dropped) and promotes them when valid again", function()
		local env = setup()
		T.eq(env.assign(1, "i1", "Seat").ok, true)
		T.eq(env.assign(2, "i2", "Seat").ok, true)
		local rev = env.seats:status().revision
		env.items.i1 = nil -- e.g. a load rollback rebuilt the world without it
		local r = env.seats:reconcile()
		T.deepEq(r.demoted, { 1 })
		T.eq(env.seats:status().revision, rev + 1)
		T.deepEq(env.seats:status().preserved, { { slot = 1, itemId = "i1", anchor = "Seat", reason = "UnknownItem" } })
		T.deepEq(env.seats:encode().Assignments, { { Slot = 2, ItemId = "i2", Anchor = "Seat" }, { Slot = 1, ItemId = "i1", Anchor = "Seat" } }, "preserved entries are written back")
		T.deepEq(env.seats:resolve(true)[1], { slot = 1, source = "room" }, "a preserved slot uses the room seat")
		env.items.i1 = { itemId = "cozy_armchair_01" }
		env.occupied[1] = true
		T.deepEq(env.seats:reconcile().promoted, {}, "not promoted onto an occupied seat")
		env.occupied[1] = nil
		T.deepEq(env.seats:reconcile().promoted, { 1 })
		T.deepEq(env.seats:status().preserved, {})
		T.deepEq(env.seats:status().active[1], { itemId = "i1", anchor = "Seat" })
		T.deepEq(env.seats:reconcile(), { demoted = {}, promoted = {} })
	end)

	T.test("room switching: assignments resolve to builder anchors only while the builder stage is active, and are kept", function()
		local env = setup()
		T.eq(env.assign(1, "i1", "Seat").ok, true)
		local onStage = env.seats:resolve(true)
		T.deepEq(onStage[1], { slot = 1, source = "builder", itemId = "i1", anchor = "Seat", catalogId = "cozy_armchair_01", poseProfile = "Chair", offset = { X = 0, Y = 1.5, Z = 0.2, Yaw = 0 } })
		for slot = 2, 4 do T.deepEq(onStage[slot], { slot = slot, source = "room" }) end
		onStage[1].offset.X = 99
		T.eq(env.seats:resolve(true)[1].offset.X, 0, "resolve returns copies")
		local away = env.seats:resolve(false)
		for slot = 1, 4 do T.eq(away[slot].source, "room") end
		T.deepEq(env.seats:status().active[1], { itemId = "i1", anchor = "Seat" }, "switching away keeps the assignment")
		T.eq(env.seats:resolve(true)[1].source, "builder")
	end)

	T.test("save section: legacy (missing) loads empty; newer versions and malformed sections are refused", function()
		local legacy = SeatAssignments.decode(nil)
		T.deepEq(legacy, { entries = {}, legacy = true })
		T.eq(select(2, SeatAssignments.decode({ Version = 2, Assignments = {} })), Codes.UnsupportedVersion)
		local corrupt = {
			"x", {}, { Version = 0, Assignments = {} }, { Version = 1 }, { Version = 1, Assignments = { "a" } },
			{ Version = 1, Assignments = { { Slot = 5, ItemId = "i1", Anchor = "Seat" } } },
			{ Version = 1, Assignments = { { Slot = 1, ItemId = "1", Anchor = "Seat" } } },
			{ Version = 1, Assignments = { { Slot = 1, ItemId = "i1", Anchor = "" } } },
			{ Version = 1, Assignments = { { Slot = 1, ItemId = "i1", Anchor = "Seat", Offset = 3 } } },
			{ Version = 1, Assignments = { [2] = { Slot = 1, ItemId = "i1", Anchor = "Seat" } } },
			{ Version = 1, Assignments = {}, FutureMetadata = { important = true } }, -- would be dropped on re-save
			{ Version = 1, Assignments = { { Slot = 1, ItemId = "i1", Anchor = "Seat" } }, Note = "x" },
		}
		for i, section in ipairs(corrupt) do
			T.eq(select(2, SeatAssignments.decode(section)), Codes.Corrupt, "corrupt case " .. i)
		end
		local many = { Version = 1, Assignments = {} }
		for i = 1, Config.MaxSeatEntries + 1 do many.Assignments[i] = { Slot = 1, ItemId = "i" .. i, Anchor = "Seat" } end
		T.eq(select(2, SeatAssignments.decode(many)), Codes.Corrupt)
		local env = setup()
		T.eq(env.assign(1, "i1", "Seat").ok, true)
		T.eq(select(2, env.seats:prepareLoad({ Version = 2, Assignments = {} }, function() return nil end)), Codes.UnsupportedVersion)
		T.deepEq(env.seats:status().active[1], { itemId = "i1", anchor = "Seat" }, "a refused load changes nothing")
		T.deepEq(SeatAssignments.new({ getItem = function() end, isHost = function() end, hostEpoch = function() end, isSlotOccupied = function() end }):encode(), { Version = 1, Assignments = {} }, "an empty section is still written, so absence means an older writer")
	end)

	T.test("load staging classifies against the loaded build; unknown profiles, missing items and conflicts are preserved, written back and revived later", function()
		local env = setup()
		local section = { Version = 1, Assignments = {
			{ Slot = 1, ItemId = "i7", Anchor = "Seat" },
			{ Slot = 2, ItemId = "i8", Anchor = "Seat" }, -- profile not configured here
			{ Slot = 3, ItemId = "i9", Anchor = "Seat" }, -- not in the loaded build
			{ Slot = 1, ItemId = "i10", Anchor = "Seat" }, -- second entry for slot 1
			{ Slot = 4, ItemId = "i7", Anchor = "Seat" }, -- anchor already taken
			{ Slot = 4, ItemId = "i7", Anchor = "Back" }, -- anchor not in the profile
		} }
		local loaded = { i7 = "cozy_armchair_01", i8 = "cozy_bookshelf_01", i10 = "cozy_armchair_01" }
		local staged = env.seats:prepareLoad(section, function(id) return loaded[id] end)
		T.deepEq(staged.active, { [1] = { itemId = "i7", anchor = "Seat" } })
		T.deepEq(staged.preserved, {
			{ slot = 2, itemId = "i8", anchor = "Seat", reason = "UnknownProfile" },
			{ slot = 3, itemId = "i9", anchor = "Seat", reason = "UnknownItem" },
			{ slot = 1, itemId = "i10", anchor = "Seat", reason = "Conflict" },
			{ slot = 4, itemId = "i7", anchor = "Seat", reason = "Conflict" },
			{ slot = 4, itemId = "i7", anchor = "Back", reason = "UnknownAnchor" },
		})
		T.eq(env.seats:status().revision, 0, "staging changes nothing")
		T.eq(env.seats:commitLoad(staged).ok, true)
		local written = env.seats:encode()
		T.eq(#written.Assignments, #section.Assignments, "nothing dropped on re-save")
		local again = env.seats:prepareLoad(written, function(id) return loaded[id] end)
		T.deepEq(again.active, staged.active)
		T.deepEq(again.preserved, staged.preserved)
		-- Later, real metadata for the bookshelf arrives (new server, new profiles).
		local profiles = { cozy_armchair_01 = FIXTURE_PROFILES.cozy_armchair_01, cozy_bookshelf_01 = { Version = 1, PoseProfile = "Chair", Anchors = { Seat = { X = 0, Y = 1, Z = 0, Yaw = 0 } } } }
		local later = setup({ profiles = profiles })
		later.items = {}
		for id, catalogId in pairs(loaded) do later.items[id] = { itemId = catalogId } end
		T.eq(later.seats:commitLoad(later.seats:prepareLoad(written, function(id) return loaded[id] end)).ok, true)
		T.deepEq(later.seats:status().active, { [1] = { itemId = "i7", anchor = "Seat" }, [2] = { itemId = "i8", anchor = "Seat" } })
	end)

	T.test("commitLoad refuses when a seat that would move is occupied; an occupied unchanged seat is fine", function()
		local env = setup()
		T.eq(env.assign(1, "i1", "Seat").ok, true)
		local keep = env.seats:prepareLoad({ Version = 1, Assignments = { { Slot = 1, ItemId = "i1", Anchor = "Seat" }, { Slot = 2, ItemId = "i2", Anchor = "Seat" } } }, function(id) return env.items[id] and env.items[id].itemId end)
		env.occupied[2] = true
		local refused = unchangedBy(env, function() return env.seats:commitLoad(keep) end)
		T.eq(refused.code, Codes.SeatOccupied)
		T.deepEq(refused.slots, { 2 })
		env.occupied = { [1] = true }
		local done = env.seats:commitLoad(keep)
		T.eq(done.ok, true)
		T.deepEq(done.changed, { 2 })
		-- Legacy load (no section) clears assignments: refused while slot 1 is occupied.
		local legacy = env.seats:prepareLoad(nil, function() return nil end)
		T.eq(legacy.legacy, true)
		T.eq(env.seats:commitLoad(legacy).code, Codes.SeatOccupied)
		env.occupied = {}
		T.eq(env.seats:commitLoad(legacy).ok, true)
		T.deepEq(env.seats:status().active, {})
	end)

	T.test("unassign discards preserved entries for a slot explicitly; the section stays bounded", function()
		local env = setup()
		local entries = {}
		for i = 1, Config.MaxSeatEntries do entries[i] = { Slot = (i % 3) + 2, ItemId = "i" .. (100 + i), Anchor = "Seat" } end
		T.eq(env.seats:commitLoad(env.seats:prepareLoad({ Version = 1, Assignments = entries }, function() return nil end)).ok, true)
		T.eq(#env.seats:status().preserved, Config.MaxSeatEntries)
		T.eq(unchangedBy(env, function() return env.assign(1, "i1", "Seat") end).code, Codes.SectionFull)
		local cleared = env.seats:unassign(env.ctx(), 2)
		T.eq(cleared.ok, true)
		T.ok(cleared.discarded > 0)
		T.eq(env.assign(1, "i1", "Seat").ok, true)
		T.ok(#env.seats:encode().Assignments <= Config.MaxSeatEntries)
		-- Assigning a slot supersedes its preserved entries (reported, not silent).
		local result = env.assign(3, "i2", "Seat")
		T.eq(result.ok, true)
		T.ok(result.superseded > 0)
	end)
end
