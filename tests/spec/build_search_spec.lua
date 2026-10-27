-- Build drawer search: literal case-insensitive matching (BuildSearch), and the
-- controller narrowing the current view's cards within the active mode and
-- filters, the empty state, previews/status kept, and build shortcuts ignored
-- while the search box has focus. Expected lists are computed from the live
-- catalog, never hardcoded counts.
return function(T, H)
	local BuildSearch = H.load("src/client/Build/BuildSearch")
	local BuildInput = H.load("src/client/Build/BuildInput")
	local BuildController = H.load("src/client/Build/BuildController")
	local BuildModeHandoff = H.load("src/client/Adapters/BuildModeHandoff")
	local Catalog = H.load("src/shared/Catalog")
	local Config = H.load("src/shared/Config")

	local function ids(list)
		local out = {}
		for _, item in ipairs(list) do out[#out + 1] = item.id end
		return out
	end
	-- Independent reference: plain substring match on lowercased names.
	local function expected(list, query)
		local out = {}
		for _, item in ipairs(list) do
			if string.find(string.lower(item.displayName), string.lower(query), 1, true) then out[#out + 1] = item.id end
		end
		return out
	end

	local function setup()
		local env = { config = Config, catalog = Catalog, requests = {}, missing = {}, now = 0, typing = false }
		local function hook() return { enter = function() end, exit = function() end } end
		env.handoff = BuildModeHandoff.new({ hooks = { camera = hook(), hostControls = hook() } })
		function env.request(payload)
			env.requests[#env.requests + 1] = payload
			if payload.op == "Status" then return { ok = true, status = { state = "ready", canUndo = true, canRedo = false, revision = 0 } } end
			return { ok = true, id = payload.id or "i1", status = { state = "ready", canUndo = true, canRedo = false, revision = #env.requests } }
		end
		function env.readSandbox() return { origin = "O", bounds = { halfX = 20, halfZ = 15, height = 16 } } end
		function env.isHost() return true end
		function env.createDrawer(callbacks)
			local d = { callbacks = callbacks, items = {}, typeView = "none", emptyHint = nil }
			for _, m in ipairs({ "setInputMode", "refit", "cancelDrag", "setStatus", "setFooter", "refresh", "destroy", "setPosition" }) do
				d[m] = function() end
			end
			function d:getPosition() return 18, 178 end
			function d:containsPoint() return false end
			function d:setFilter(id, name) self.filter, self.filterName = id, name end
			function d:setCategory(category) self.category = category end
			function d:showTypes(types) self.types, self.typeView = types, "chooser" end
			function d:showTypeItems(name) self.typeName, self.typeView = name, "items" end
			function d:hideTypes() self.typeView = "none" end
			function d:setItems(items) self.items = items end
			function d:setEmptyState(hint) self.emptyHint = hint end
			env.drawer = d
			return d
		end
		function env.previewTemplate(id) if env.missing[id] then return nil end return { name = id } end
		function env.itemSize() return { 2, 2, 2 } end
		function env.createGhost(id) return { catalogId = id, show = function() end, destroy = function() end } end
		function env.raycast(pointer) return pointer.hit end
		function env.pickPlaced(pointer) return pointer.pick end
		function env.selectedInfo() return { catalogId = "cozy_plant_01", yaw = 0 } end
		function env.mouseLocation() return { hit = { x = 0, y = 0, z = 0, upDot = 1 } } end
		function env.setSelectionHighlight() end
		function env.spawn(fn) assert(coroutine.resume(coroutine.create(fn))) end
		function env.wait() coroutine.yield("wait") end
		function env.clock() return env.now end
		function env.textFocused() return env.typing end
		env.c = BuildController.new(env)
		return env
	end

	-- A query word that appears in some, but not all, names of a list.
	local function partialWord(list)
		for _, item in ipairs(list) do
			for word in string.gmatch(item.displayName, "%a%a%a+") do
				local n = #expected(list, word)
				if n > 0 and n < #list then return word end
			end
		end
	end

	-- BuildSearch --------------------------------------------------------------------------

	T.test("search matching: trimmed, case-insensitive, literal (no patterns), empty keeps everything", function()
		T.eq(BuildSearch.normalize("  LaMp \t"), "lamp")
		T.eq(BuildSearch.normalize(nil), "")
		T.eq(BuildSearch.normalize(42), "")
		T.eq(#BuildSearch.normalize(string.rep("a", 500)), BuildSearch.MaxLength, "length capped")
		local items = { { displayName = "A.B Lamp" }, { displayName = "AxB lamp" }, { displayName = "50% (Off)" }, { displayName = nil } }
		T.eq(#BuildSearch.filter(items, ""), #items, "empty query keeps every item")
		T.eq(#BuildSearch.filter(items, BuildSearch.normalize("LAMP")), 2)
		T.eq(BuildSearch.filter(items, "a.b")[1].displayName, "A.B Lamp")
		T.eq(#BuildSearch.filter(items, "a.b"), 1, "'.' is a literal dot, not any character")
		T.eq(#BuildSearch.filter(items, "% ("), 1, "'%' and '(' are literal")
		T.eq(#BuildSearch.filter(items, "[a-z]"), 0, "brackets are literal")
		T.eq(#BuildSearch.filter(items, "zzz"), 0)
		T.ok(BuildSearch.emptyHint("Floors"):find("Floors", 1, true))
	end)

	-- Controller -----------------------------------------------------------------------------

	T.test("furniture: a search over the type chooser lists the collection's matching cards; clearing restores the chooser", function()
		local env = setup()
		env.c:open()
		local collection = env.c.session.filter
		local all = Catalog.getFurnitureTagged(collection)
		T.eq(env.drawer.typeView, "chooser")
		local word = partialWord(all)
		T.ok(word ~= nil, "the live catalog has a partial match to search for")
		env.drawer.callbacks.onSearch("  " .. string.upper(word) .. " ")
		T.eq(env.drawer.typeView, "none", "the chooser gives way to results")
		T.deepEq(ids(env.drawer.items), expected(all, word), "matches within the active collection only")
		T.eq(env.drawer.emptyHint, nil)
		for _, card in ipairs(env.drawer.items) do
			T.ok(card.preview ~= nil and card.installed == true, card.id .. " keeps its preview and status")
			T.ok(Catalog.getItem(card.id).structure == nil, "furniture mode never shows structure")
		end
		env.drawer.callbacks.onSearch("")
		T.eq(env.drawer.typeView, "chooser", "empty search restores the normal listing")
		T.eq(#env.drawer.items, 0)
		T.eq(env.drawer.emptyHint, nil)
	end)

	T.test("furniture: search narrows a chosen type; status of not-installed cards is kept; the query survives a collection change", function()
		local env = setup()
		env.c:open()
		local collection = env.c.session.filter
		local typeId
		for _, t in ipairs(Catalog.getFurnitureTypeCounts(collection)) do
			if t.count > 1 then typeId = t.id break end
		end
		T.ok(typeId ~= nil)
		local list = Catalog.getFurnitureByType(collection, typeId)
		env.missing[list[1].id] = true
		env.c:chooseType(typeId)
		local first = string.lower(list[1].displayName)
		env.drawer.callbacks.onSearch(first)
		T.eq(env.drawer.typeView, "items", "the chosen type stays chosen")
		T.deepEq(ids(env.drawer.items), expected(list, first))
		T.eq(env.drawer.items[1].installed, false, "a not-installed card still shows as not installed")
		-- Another collection: same query, new scope.
		local other
		for _, c in ipairs(Catalog.getCollectionsSorted()) do
			if c.id ~= collection then other = c.id break end
		end
		env.c:showFilter(other)
		T.deepEq(ids(env.drawer.items), expected(Catalog.getFurnitureTagged(other), first), "searched within the new collection")
	end)

	T.test("no match: an empty state naming the scope; structure mode searches only the active structure filter", function()
		local env = setup()
		env.c:open()
		env.drawer.callbacks.onSearch("no such item zzqx")
		T.eq(#env.drawer.items, 0)
		local collection = Catalog.getCollection(env.c.session.filter)
		T.ok(env.drawer.emptyHint and env.drawer.emptyHint:find(collection.displayName, 1, true), "hint names the collection")
		env.drawer.callbacks.onSearch("")
		env.c:setCategory("structure")
		local filters = Catalog.StructureFilters
		local first, second = filters[1], filters[2]
		env.c:showStructureFilter(first.id)
		local mine = Catalog.getStructureItems(first.id)
		local theirs = Catalog.getStructureItems(second.id)
		-- A word from the second filter that none of the first filter's names contain.
		local word
		for _, item in ipairs(theirs) do
			for w in string.gmatch(item.displayName, "%a%a%a+") do
				if #expected(mine, w) == 0 then word = w break end
			end
			if word then break end
		end
		T.ok(word ~= nil)
		env.drawer.callbacks.onSearch(word)
		T.eq(#env.drawer.items, 0, "another structure kind's piece is not shown")
		T.ok(env.drawer.emptyHint:find(first.displayName, 1, true), "hint names the structure filter")
		env.c:showStructureFilter(second.id)
		T.deepEq(ids(env.drawer.items), expected(theirs, word), "found in its own filter")
		T.eq(env.drawer.emptyHint, nil)
		for _, card in ipairs(env.drawer.items) do
			T.eq(Catalog.getItem(card.id).structure.kind, second.id)
		end
	end)

	T.test("typing a search never cancels a preview or a selection, sends nothing, and resets with the drawer", function()
		local env = setup()
		env.c:open()
		env.c:chooseItem("cozy_plant_01")
		local intent, sent = env.c.intent, #env.requests
		env.drawer.callbacks.onSearch("lamp")
		T.eq(env.c.session.mode, "placing")
		T.eq(env.c.session.itemId, "cozy_plant_01")
		T.eq(env.c.intent, intent, "no intent bump: a pending Place still applies")
		T.eq(#env.requests, sent)
		env.c:cancel()
		env.c:onPointerPressed({ pick = "i5" }, "mouse", 900, 500)
		env.drawer.callbacks.onSearch("chair")
		T.eq(env.c.session.selectedId, "i5", "selection kept")
		env.c:close()
		T.eq(env.c.search, "")
		env.c:setSearch("stale query from before opening")
		env.c:open()
		T.eq(env.c.search, "", "a new drawer starts unfiltered")
		T.eq(env.drawer.typeView, "chooser")
	end)

	T.test("while the search box has focus, typed Z, Ctrl+Z, Ctrl+Y, Ctrl+Shift+Z, Backspace and R never edit; a held R stops", function()
		for _, case in ipairs({ { "Z" }, { "Z", true }, { "Y", true }, { "Z", true, true }, { "Backspace" }, { "R" } }) do
			T.eq(BuildInput.classify({ keyCode = case[1], inputType = "Keyboard", gameProcessed = true, textFocused = true, ctrl = case[2], shift = case[3] }), nil, case[1])
			T.eq(BuildInput.classify({ keyCode = case[1], inputType = "Keyboard", gameProcessed = false, textFocused = true, ctrl = case[2], shift = case[3] }), nil, case[1] .. " (even if unprocessed)")
		end
		local env = setup()
		env.c:open()
		env.c:chooseItem("cozy_plant_01")
		env.c:onKeyPressed("rotate", "R")
		T.eq(env.c.session.previewYaw, 15)
		env.c:onTextFocused() -- the search box took focus while R was held
		env.typing = true
		env.now = 2
		env.c:tick()
		T.eq(env.c.session.previewYaw, 15)
		T.eq(env.c.rotateHold, nil)
	end)
end
