-- Furniture organized by type inside each collection: explicit catalog types,
-- the type chooser (counts, no empty groups, All items), type filtering, and
-- navigation that cancels previews and never lets a stale response or click
-- act on an old choice.
return function(T, H)
	local Catalog = H.load("src/shared/Catalog")
	local Config = H.load("src/shared/Config")
	local BuildSession = H.load("src/client/Build/BuildSession")
	local BuildController = H.load("src/client/Build/BuildController")
	local BuildModeHandoff = H.load("src/client/Adapters/BuildModeHandoff")

	-- The reviewed assignment: one primary type per furniture item, by function.
	local EXPECTED = {
		cozy_armchair_01 = "seating", cozy_upholstered_chair_01 = "seating", future_curved_sofa_01 = "seating",
		modern_lounge_chair_01 = "seating", studio_chair_01 = "seating", winter_furry_chair_01 = "seating",
		cozy_tufted_leather_sofa_01 = "seating",
		cozy_coffee_table_01 = "tables", future_glass_table_01 = "tables", retro_meeting_table_01 = "tables",
		cozy_bookshelf_01 = "storage", retro_tv_cart_01 = "storage", future_shelf_01 = "storage",
		winter_firewood_shelf_01 = "storage", winter_log_basket_01 = "storage", future_drawer_cabinet_01 = "storage",
		studio_boom_mic_01 = "microphones", studio_desk_mic_01 = "microphones",
		retro_cassette_01 = "audio", studio_headphones_01 = "audio", studio_mixer_01 = "audio",
		retro_record_player_01 = "audio", retro_radio_01 = "audio", future_speaker_01 = "audio",
		future_layered_coffee_table_01 = "tables",
		cozy_floor_lamp_01 = "lighting", future_modern_lamp_01 = "lighting", studio_desk_lamp_01 = "lighting", winter_lantern_01 = "lighting",
		retro_classic_floor_lamp_01 = "lighting",
		retro_crt_tv_01 = "screens",
		cozy_plant_01 = "plants", cozy_monstera_01 = "plants", studio_tall_floor_plant_01 = "plants",
		cozy_book_set_01 = "decor", retro_book_01 = "decor", winter_folded_throw_01 = "decor",
		winter_snow_globe_01 = "decor", winter_white_rug_01 = "decor", retro_patterned_rug_01 = "decor",
		studio_water_dispenser_01 = "decor",
	}

	-- Catalog -------------------------------------------------------------------------------

	T.test("every furniture item has exactly the reviewed type; structure pieces have none; type list is fixed", function()
		local ids = {}
		for i, t in ipairs(Catalog.FurnitureTypes) do ids[i] = t.id end
		T.eq(table.concat(ids, ","), "seating,tables,storage,microphones,audio,lighting,screens,plants,decor")
		local furniture, seen = 0, {}
		for _, item in ipairs(Catalog.Items) do
			if item.structure then
				T.eq(item.type, nil, item.id .. " (structure)")
			else
				furniture = furniture + 1
				T.eq(item.type, EXPECTED[item.id], item.id)
				seen[item.id] = true
			end
		end
		T.eq(furniture, 41)
		for id in pairs(EXPECTED) do T.ok(seen[id], "assigned item exists: " .. id) end
		T.eq(Catalog.getFurnitureType("doors"), nil, "no empty Doors type in furniture")
		T.eq(Catalog.getFurnitureType("seating").displayName, "Seating")
		T.eq(Catalog.getFurnitureType(nil), nil)
		-- Types are explicit data, not derived from names: some names would mislead.
		T.eq(Catalog.getItem("retro_tv_cart_01").type, "storage", "the AV cart is not a screen")
		T.eq(Catalog.getItem("winter_white_rug_01").type, "decor")
	end)

	T.test("the validator requires one known type on furniture and forbids it on structure pieces", function()
		local collections = { { id = "cozy", displayName = "Cozy" } }
		local function check(item)
			item.id = item.id or "x_item"
			item.displayName = "X"
			item.collections = { "cozy" }
			return Catalog.validateData(collections, { item })
		end
		T.eq((check({ type = "tables" })), true)
		for _, bad in ipairs({ {}, { type = "doors" }, { type = "Tables" }, { type = 3 } }) do
			local ok, errors = check(bad)
			T.eq(ok, false)
			T.ok(errors[1]:find("needs a furniture type", 1, true), tostring(errors[1]))
		end
		local ok, errors = check({ structure = { kind = "wall" }, type = "decor" })
		T.eq(ok, false)
		T.ok(errors[1]:find("must not have a furniture type", 1, true))
		T.eq((check({ structure = { kind = "wall" } })), true)
	end)

	T.test("type counts per collection: correct, in type order, no empty groups; type filtering is the intersection", function()
		local typeOrder = {}
		for i, t in ipairs(Catalog.FurnitureTypes) do typeOrder[t.id] = i end
		for _, c in ipairs(Catalog.getCollectionsSorted()) do
			local furniture = Catalog.getFurnitureTagged(c.id)
			local expected = {}
			for _, item in ipairs(furniture) do expected[item.type] = (expected[item.type] or 0) + 1 end
			local counts = Catalog.getFurnitureTypeCounts(c.id)
			local total, last = 0, 0
			for _, entry in ipairs(counts) do
				T.ok(entry.count > 0, c.id .. " has no empty group")
				T.eq(entry.count, expected[entry.id], c.id .. " " .. entry.id)
				T.ok(typeOrder[entry.id] > last, "type order")
				last = typeOrder[entry.id]
				total = total + entry.count
				local list = Catalog.getFurnitureByType(c.id, entry.id)
				T.eq(#list, entry.count)
				for _, item in ipairs(list) do
					T.eq(item.type, entry.id)
					T.eq(item.structure, nil)
					local tagged = false
					for _, tag in ipairs(item.collections) do if tag == c.id then tagged = true end end
					T.ok(tagged, item.id .. " is in " .. c.id)
				end
			end
			T.eq(total, #furniture, c.id .. " counts add up")
			for typeId in pairs(expected) do
				local present = false
				for _, entry in ipairs(counts) do if entry.id == typeId then present = true end end
				T.ok(present, c.id .. " lists " .. typeId)
			end
		end
		-- Concrete snapshot for two collections.
		local function summary(id)
			local out = {}
			for _, e in ipairs(Catalog.getFurnitureTypeCounts(id)) do out[#out + 1] = e.id .. "=" .. e.count end
			return table.concat(out, ",")
		end
		T.eq(summary("futuristic"), "seating=2,tables=2,storage=2,microphones=1,audio=3,lighting=2")
		T.eq(summary("winter"), "seating=2,tables=1,storage=3,lighting=2,plants=1,decor=4")
		T.eq(#Catalog.getFurnitureByType("winter", "screens"), 0)
	end)

	-- Session ---------------------------------------------------------------------------------

	T.test("session: collection and type changes return to or set the chooser and cancel previews", function()
		local s = BuildSession.new(Config)
		s:opened(true)
		T.eq(s.furnitureType, nil, "starts on the chooser")
		T.eq(s:setFurnitureType("doors"), false)
		T.eq(s:setFurnitureType("seating"), true)
		s:choose("cozy_armchair_01", true, nil)
		T.eq(s:setFurnitureType("tables"), true)
		T.eq(s.mode, "idle", "type change cancels placing")
		s:choose("cozy_coffee_table_01", true, nil)
		T.eq(s:setFilter("cozy"), true)
		T.eq(s.furnitureType, nil, "re-picking the collection returns to the chooser")
		T.eq(s.mode, "idle")
		s:setFurnitureType("all")
		s:select("i3")
		s:beginMove("cozy_plant_01", 0, nil)
		T.eq(s:setFilter("winter"), true)
		T.eq(s.mode, "selected", "move cancelled back to the selection")
		T.eq(s.furnitureType, nil)
		s:setFurnitureType("decor")
		s:setCategory("structure")
		T.eq(s.furnitureType, nil, "category change returns to the chooser")
		s:choose("structure_wall_01", true, "wall")
		T.eq(s:setStructureFilter("floor"), true)
		T.eq(s.mode, "placing", "re-picking the current structure filter is a no-op")
		T.eq(s:setStructureFilter("doorway"), true)
		T.eq(s.mode, "idle", "structure filter change cancels too")
	end)

	-- Controller -------------------------------------------------------------------------------

	local function setup()
		local env = { config = Config, catalog = Catalog, requests = {}, ghosts = {}, spawned = {}, revision = 0, hold = {}, closed = 0 }
		env.handoff = BuildModeHandoff.new({ hooks = { camera = { enter = function() end, exit = function() end }, hostControls = { enter = function() end, exit = function() end } } })
		function env.request(payload)
			env.requests[#env.requests + 1] = payload
			if env.hold[payload.op] then
				env.hold[payload.op] = nil
				coroutine.yield("request")
			end
			if payload.op == "Status" then
				return { ok = true, status = { state = "ready", canUndo = false, canRedo = false, revision = env.revision } }
			end
			env.revision = env.revision + 1
			return { ok = true, id = "i" .. env.revision, status = { state = "ready", canUndo = true, canRedo = false, revision = env.revision } }
		end
		function env.readSandbox() return { origin = "O", bounds = { halfX = 24.5, halfZ = 24.5, height = 24 } } end
		function env.isHost() return true end
		function env.createDrawer(callbacks)
			local d = { callbacks = callbacks, x = 18, y = 178, log = {} }
			function d:setPosition() end
			function d:getPosition() return self.x, self.y end
			function d:setInputMode() end
			function d:refit() end
			function d:cancelDrag() end
			function d:containsPoint() return false end
			function d:setFilter(id) self.filter = id end
			function d:setCategory(category) self.category = category end
			function d:showTypes(types) self.types, self.typeView = types, "chooser" end
			function d:showTypeItems(name) self.typeName, self.typeView = name, "items" end
			function d:hideTypes() self.typeView = "none" end
			function d:setItems(items) self.items = items end
			function d:setStatus() end
			function d:setFooter() end
			function d:refresh() end
			function d:destroy() self.destroyed = true end
			env.drawer = d
			return d
		end
		function env.previewTemplate(id) return { name = id } end
		function env.itemSize() return { 2, 2, 2 } end
		function env.createGhost(id)
			local g = { catalogId = id, destroyed = false }
			g.show = function() end
			g.destroy = function() g.destroyed = true end
			env.ghosts[#env.ghosts + 1] = g
			return g
		end
		function env.raycast(pointer) return pointer.hit end
		function env.pickPlaced(pointer) return pointer.pick end
		function env.selectedInfo() return { catalogId = "cozy_armchair_01", yaw = 0 } end
		function env.mouseLocation() return env.mouse end
		function env.setSelectionHighlight() end
		env.panel = { onClosed = function() env.closed = env.closed + 1 end }
		function env.spawn(fn) local co = coroutine.create(fn); env.spawned[#env.spawned + 1] = co; assert(coroutine.resume(co)) end
		function env.wait() coroutine.yield("wait") end
		env.c = BuildController.new(env)
		return env
	end
	local function at(x, z, pick) return { hit = { x = x, y = 0, z = z, upDot = 1 }, pick = pick } end
	local function ids(list)
		local out = {}
		for _, e in ipairs(list) do out[#out + 1] = e.id end
		return table.concat(out, ",")
	end

	T.test("controller: a collection opens its type chooser with counts and All items; a type lists only its furniture; Types returns", function()
		local env = setup()
		T.eq(env.c:open(), true)
		T.eq(env.drawer.typeView, "chooser")
		T.eq(env.drawer.filter, "cozy")
		local expected = Catalog.getFurnitureTypeCounts("cozy")
		T.eq(#env.drawer.types, #expected + 1)
		for i, e in ipairs(expected) do
			T.deepEq(env.drawer.types[i], e)
		end
		T.deepEq(env.drawer.types[#env.drawer.types], { id = "all", displayName = "All items", count = 29 })
		T.eq(#env.drawer.items, 0, "no cards while choosing a type")
		env.drawer.callbacks.onType("microphones")
		T.eq(env.drawer.typeView, "items")
		T.eq(env.drawer.typeName, "Microphones")
		T.eq(ids(env.drawer.items), ids(Catalog.getFurnitureByType("cozy", "microphones")))
		env.drawer.callbacks.onTypes()
		T.eq(env.drawer.typeView, "chooser")
		T.eq(env.c:isOpen(), true, "Types does not leave build mode")
		env.drawer.callbacks.onType("all")
		T.eq(#env.drawer.items, 29)
		T.eq(env.drawer.typeName, "All items")
		env.drawer.callbacks.onFilter("futuristic")
		T.eq(env.drawer.typeView, "chooser", "changing collection returns to the chooser")
		T.eq(ids(env.drawer.types), "seating,tables,storage,microphones,audio,lighting,all")
		env.drawer.callbacks.onType("doors")
		T.eq(env.drawer.typeView, "chooser", "an unknown type is ignored")
		env.drawer.callbacks.onBack()
		T.eq(env.c:isOpen(), false, "Exit leaves build mode")
		T.eq(env.closed, 1)
	end)

	T.test("controller: changing type or collection cancels placement and moves; nothing stale is sent", function()
		local env = setup()
		env.c:open()
		env.drawer.callbacks.onType("seating")
		env.c:chooseItem("cozy_armchair_01")
		env.c:onPointerMoved(at(2, 2), "touch")
		T.eq(env.c.session.mode, "placing")
		local ghost = env.ghosts[#env.ghosts]
		local sent = #env.requests
		env.drawer.callbacks.onType("tables")
		T.eq(env.c.session.mode, "idle")
		T.eq(ghost.destroyed, true)
		env.drawer.callbacks.onPlaceHere()
		env.c:onPointerPressed(at(2, 2), "mouse")
		T.eq(#env.requests, sent, "no Place after a type change")
		-- Collection change while placing.
		env.c:chooseItem("cozy_coffee_table_01")
		env.c:onPointerMoved(at(1, 1), "touch")
		env.drawer.callbacks.onFilter("retro")
		T.eq(env.c.session.mode, "idle")
		env.drawer.callbacks.onPlaceHere()
		T.eq(#env.requests, sent, "no Place after a collection change")
		-- Moving a selected item, then changing type: back to the selection, no Move sent.
		env.c:onPointerPressed(at(0, 0, "i9"), "mouse")
		env.c:beginMove()
		env.c:onPointerMoved(at(3, 3), "touch")
		T.eq(env.c.session.mode, "moving")
		env.drawer.callbacks.onType("audio")
		T.eq(env.c.session.mode, "selected")
		T.eq(env.c.session.selectedId, "i9")
		env.drawer.callbacks.onPlaceHere()
		T.eq(#env.requests, sent, "no Move after a type change")
		-- Structure filter change while placing a structure piece.
		env.drawer.callbacks.onCategory("structure")
		T.eq(env.drawer.typeView, "none", "Structure mode hides the type chooser")
		env.c:chooseItem("structure_wall_01")
		env.c:onPointerMoved(at(3, 7), "touch")
		env.drawer.callbacks.onFilter("doorway")
		T.eq(env.c.session.mode, "idle")
		env.drawer.callbacks.onPlaceHere()
		T.eq(#env.requests, sent)
		env.drawer.callbacks.onCategory("furniture")
		T.eq(env.drawer.typeView, "chooser")
	end)

	T.test("controller: a Place in flight when the type changes updates status only; it can't revive the old choice", function()
		local env = setup()
		env.c:open()
		env.drawer.callbacks.onType("seating")
		env.c:chooseItem("cozy_armchair_01")
		env.c:onPointerMoved(at(2, 2), "touch")
		env.hold.Place = true
		local co = coroutine.create(function() env.drawer.callbacks.onPlaceHere() end)
		assert(coroutine.resume(co))
		T.eq(coroutine.status(co), "suspended")
		env.drawer.callbacks.onType("plants")
		assert(coroutine.resume(co))
		T.eq(env.c.session.mode, "idle", "the late success does not select the old placement")
		T.eq(env.c.session.selectedId, nil)
		T.eq(env.c.session.canUndo, true, "status from the response is still applied")
		T.eq(env.drawer.typeName, "Plants")
	end)
end
