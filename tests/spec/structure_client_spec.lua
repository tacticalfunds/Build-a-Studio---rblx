-- Task 10 client checkpoint: Structure mode in the Build drawer controller,
-- structure ghost preview through the shared StructureGrid, and parity with
-- the server's placement rules. Uses the 5 registered structure catalog
-- entries; template sizes are the manifest's measured sizes (Studio install
-- pending). Drawer, ghosts, remote and scheduler are fakes.
return function(T, H)
	local BuildController = H.load("src/client/Build/BuildController")
	local BuildSession = H.load("src/client/Build/BuildSession")
	local PlacementPreview = H.load("src/client/Build/PlacementPreview")
	local BuildModeHandoff = H.load("src/client/Adapters/BuildModeHandoff")
	local PlacementCore = H.load("src/server/Core/PlacementCore")
	local Catalog = H.load("src/shared/Catalog")
	local Config = H.load("src/shared/Config")
	local Protocol = H.load("src/shared/Protocol")

	local LIVE = { halfX = 24, halfZ = 24, height = 24 } -- current 48 x 24 x 48 marker
	local FUTURE = { halfX = 24.5, halfZ = 24.5, height = 24 } -- proposed 49 x 24 x 49
	-- Manifest sizes (docs/assets/Structure_and_Decor_Candidates_2026-10-25.json).
	local SIZES = {
		structure_wall_01 = { 16, 15, 1 },
		structure_window_wall_01 = { 16.00006103515625, 14.999996185302734, 1 },
		structure_doorway_01 = { 16, 15.000016212463379, 1 },
		structure_floor_01 = { 16, 1, 16 },
		structure_ceiling_01 = { 16, 1, 16 },
		-- Prepared panel door wall: closed module bounds from its manifest.
		structure_doorway_panel_01 = { 16, 15, 1 },
		cozy_plant_01 = { 2.93, 5.72, 2.93 },
	}
	local KIND = {
		structure_wall_01 = "wall", structure_window_wall_01 = "window_wall", structure_doorway_01 = "doorway",
		structure_floor_01 = "floor", structure_ceiling_01 = "ceiling",
	}

	local function hit(x, z, upDot, y)
		return { x = x, y = y or 0, z = z, upDot = upDot or 1 }
	end
	local function preview(itemId, h, bounds, yaw)
		return PlacementPreview.compute(h, { size = SIZES[itemId], yaw = yaw or 0, bounds = bounds or LIVE, snap = true, config = Config, structureKind = KIND[itemId] })
	end

	-- PlacementPreview --------------------------------------------------------------------

	T.test("preview: structure hits snap to cells and edges at the kind's level; a floor hit places a ceiling at y 15", function()
		local f = preview("structure_floor_01", hit(9, -7))
		T.eq(f.valid, true)
		T.deepEq(f.transform, { x = 16, y = 0, z = 0, yaw = 0 })
		local c = preview("structure_ceiling_01", hit(-9, 3))
		T.deepEq(c.transform, { x = -16, y = 15, z = 0, yaw = 0 }, "ceiling from a floor hit")
		T.deepEq(preview("structure_wall_01", hit(3, 7)).transform, { x = 0, y = 0, z = 8, yaw = 0 })
		T.deepEq(preview("structure_doorway_01", hit(7, 3), LIVE, 90).transform, { x = 8, y = 0, z = 0, yaw = 90 }, "yaw 90 locks the Z-axis edge")
		T.deepEq(preview("structure_doorway_01", hit(7, 3)).transform, { x = 0, y = 0, z = 8, yaw = 0 }, "yaw 0 locks the X-axis edge even nearer an x edge")
		T.deepEq(preview("structure_window_wall_01", hit(7, 3), LIVE, 270).transform, { x = 8, y = 0, z = 0, yaw = 270 }, "facing kept")
		T.deepEq(preview("structure_window_wall_01", hit(7, 3), LIVE, 180).transform, { x = 0, y = 0, z = 8, yaw = 180 }, "facing kept")
		-- Any hit counts: a wall face, a ceiling underside or a raised top still uses only x/z.
		T.deepEq(preview("structure_floor_01", hit(9, -7, 0, 6)).transform, { x = 16, y = 0, z = 0, yaw = 0 })
		T.deepEq(preview("structure_floor_01", hit(9, -7, -1, 16)).transform, { x = 16, y = 0, z = 0, yaw = 0 })
		T.eq(preview("structure_floor_01", nil).code, "NoSurface")
		T.eq(preview("structure_floor_01", hit(0 / 0, 0)).code, "NoSurface")
		T.eq(preview("structure_floor_01", { x = 1, y = 0, upDot = 1 }).code, "NoSurface", "missing z")
		local bad = preview("structure_floor_01", hit(0, 0), LIVE, 45)
		T.eq(bad.valid, false)
		T.eq(bad.code, "OffGrid")
		T.eq(bad.reason, "BadYaw")
		-- Furniture keeps its behaviour: wall faces are not surfaces.
		T.eq(PlacementPreview.compute(hit(0, 0, 0.2), { size = SIZES.cozy_plant_01, yaw = 0, bounds = LIVE, snap = true, config = Config }).code, "NoSurface")
	end)

	T.test("preview: outer walls are invalid on the live 48 marker (drawn as invalid ghosts) and valid on the proposed 49", function()
		local live = preview("structure_wall_01", hit(3, 23.6), LIVE)
		T.eq(live.valid, false)
		T.eq(live.code, "OutOfBounds")
		T.deepEq(live.transform, { x = 0, y = 0, z = 24, yaw = 0 }, "still drawable")
		T.eq(preview("structure_wall_01", hit(3, 23.6), FUTURE).valid, true)
		T.eq(preview("structure_floor_01", hit(30, 0), FUTURE).code, "OutOfBounds", "a fourth ring fits neither")
		T.eq(preview("structure_ceiling_01", hit(0, 0), { halfX = 24, halfZ = 24, height = 15.9 }).code, "OutOfBounds", "ceiling top 16")
	end)

	-- Parity with the server ----------------------------------------------------------------

	local function serverFor(bounds)
		local env = { now = 0 }
		local world = { live = {} }
		function world:apply(effect) return { kind = effect.kind, id = effect.id } end
		function world:rollback() end
		function world:commit() end
		function world:publishRevision() end
		env.core = PlacementCore.new({
			config = Config, catalog = Catalog,
			templates = {
				isInstalled = function(id) return SIZES[id] ~= nil end,
				getSize = function(id) local s = SIZES[id]; return s and { s[1], s[2], s[3] } or nil end,
			},
			entitlements = { isItemUnlocked = function() return true end },
			authority = { check = function(_, userId) return userId == 1001 end },
			bounds = bounds, world = world, clock = function() return env.now end,
		})
		function env.place(itemId, t)
			env.now = env.now + 1
			return env.core:handle(1001, { op = "Place", itemId = itemId, transform = { x = t.x, y = t.y, z = t.z, yaw = t.yaw } })
		end
		return env
	end

	T.test("parity: the ghost is valid exactly where the real server accepts the same transform (48 and 49 markers, every kind)", function()
		local checked = 0
		for _, bounds in ipairs({ LIVE, FUTURE }) do
			for itemId in pairs(KIND) do
				for x = -30, 30, 3.5 do
					for z = -30, 30, 3.5 do
						for _, yaw in ipairs({ 0, 90, 180, 270 }) do
							local p = preview(itemId, hit(x, z), bounds, yaw)
							local server = serverFor(bounds)
							local r = server.place(itemId, p.transform)
							checked = checked + 1
							T.eq(r.ok, p.valid, itemId .. " at " .. x .. "," .. z .. " yaw " .. yaw)
							if not p.valid then
								T.eq(r.code, p.code, "same code for " .. itemId .. " at " .. x .. "," .. z)
							else
								T.deepEq(server.core.model:get(r.id), { itemId = itemId, placedByUserId = 1001, x = p.transform.x, y = p.transform.y, z = p.transform.z, yaw = p.transform.yaw })
							end
						end
					end
				end
			end
		end
		H.note("structure preview/server parity: " .. checked .. " placements compared")
	end)

	T.test("parity: the panel door ghost applies the server's swept-box check (SwingOutOfBounds) at every yaw on both markers", function()
		local DOOR = "structure_doorway_panel_01"
		local door = Catalog.getItem(DOOR).door
		local checked, swing = 0, 0
		for _, bounds in ipairs({ LIVE, FUTURE }) do
			for x = -30, 30, 3.5 do
				for z = -30, 30, 3.5 do
					for _, yaw in ipairs({ 0, 90, 180, 270 }) do
						local ctx = { size = SIZES[DOOR], yaw = yaw, bounds = bounds, snap = true, config = Config, structureKind = "doorway", door = door }
						local p = PlacementPreview.compute(hit(x, z), ctx)
						local r = serverFor(bounds).place(DOOR, p.transform)
						checked = checked + 1
						T.eq(r.ok, p.valid, DOOR .. " at " .. x .. "," .. z .. " yaw " .. yaw)
						if not p.valid then
							T.eq(r.code, p.code, "same code at " .. x .. "," .. z .. " yaw " .. yaw)
							if p.code == "SwingOutOfBounds" then swing = swing + 1 end
						end
						-- Without door metadata the same spot is judged by the grid alone.
						ctx.door = nil
						local plain = PlacementPreview.compute(hit(x, z), ctx)
						T.ok(plain.valid or not p.valid, "the swing check only ever removes spots")
					end
				end
			end
		end
		T.ok(swing > 0, "outward-facing outer edges on the 49 marker are SwingOutOfBounds")
		-- Malformed metadata fails closed in the preview too.
		local bad = PlacementPreview.compute(hit(0, 7), { size = SIZES[DOOR], yaw = 0, bounds = LIVE, snap = true, config = Config, structureKind = "doorway", door = { swing = "+z" } })
		T.eq(bad.valid, false)
		T.eq(bad.code, "UnknownItem")
		H.note("panel door preview/server parity: " .. checked .. " placements compared, " .. swing .. " swing refusals")
	end)

	-- BuildSession -------------------------------------------------------------------------------

	T.test("session: categories, structure filters and rotation steps; switching category cancels a stale preview", function()
		local s = BuildSession.new(Config)
		s:opened(true)
		T.eq(s.category, "furniture")
		T.eq(s:setCategory("decor"), false)
		T.eq(s:setStructureFilter("corner"), false, "corners are deferred")
		T.eq(s:setStructureFilter("window_wall"), true)
		s:choose("cozy_plant_01", true, nil)
		T.eq(s:rotationStep(), 15)
		T.eq(s:setCategory("structure"), true)
		T.eq(s.mode, "idle", "placing cancelled")
		T.eq(s.itemId, nil)
		s:choose("structure_floor_01", true, "floor")
		T.eq(s:rotationStep(), 90)
		s:choose("structure_wall_01", true, "wall")
		T.eq(s:rotationStep(), 90, "every structure preview turns 90 degrees")
		T.eq(s:rotate(), "preview")
		T.eq(s.previewYaw, 90)
		s:cancel()
		s:select("i4")
		s:beginMove("structure_floor_01", 90, "floor")
		T.eq(s.mode, "moving")
		T.eq(s:setCategory("furniture"), true)
		T.eq(s.mode, "selected", "move cancelled back to the selection")
		T.eq(s.itemKind, nil)
		T.eq(s:setCategory("furniture"), true, "same category: no change")
	end)

	-- BuildController ------------------------------------------------------------------------------

	local function setup(bounds)
		local env = {
			config = Config, catalog = Catalog, messageFor = Protocol.message,
			requests = {}, ghosts = {}, spawned = {}, missing = {}, revision = 0,
		}
		local function hook()
			return { enter = function() end, exit = function() end }
		end
		env.handoff = BuildModeHandoff.new({ hooks = { camera = hook(), hostControls = hook() } })
		function env.request(payload)
			env.requests[#env.requests + 1] = payload
			if payload.op == "Status" then
				return { ok = true, status = { state = "ready", canUndo = false, canRedo = false, revision = env.revision } }
			end
			if env.reply then
				return env.reply(payload)
			end
			env.revision = env.revision + 1
			return { ok = true, id = "i" .. env.revision, status = { state = "ready", canUndo = true, canRedo = false, revision = env.revision } }
		end
		function env.readSandbox() return { origin = "O", bounds = bounds or LIVE } end
		function env.isHost() return true end
		function env.createDrawer(callbacks)
			local d = { callbacks = callbacks, x = 18, y = 178 }
			function d:setPosition() end
			function d:getPosition() return self.x, self.y end
			function d:setInputMode() end
			function d:refit() end
			function d:cancelDrag() end
			function d:containsPoint() return false end
			function d:setFilter(id, name) self.filter, self.filterName = id, name end
			function d:setCategory(category, filters) self.category, self.filters = category, filters end
			function d:showTypes(types) self.types, self.typeView = types, "chooser" end
			function d:showTypeItems(name) self.typeName, self.typeView = name, "items" end
			function d:hideTypes() self.typeView = "none" end
			function d:setItems(items) self.items = items end
			function d:setStatus(text) self.status = text end
			function d:setFooter(text) self.footer = text end
			function d:refresh() end
			function d:destroy() end
			env.drawer = d
			return d
		end
		function env.previewTemplate(id)
			if env.missing[id] then return nil end
			return { name = id }
		end
		function env.itemSize(id)
			if env.noSize then return nil end
			local s = SIZES[id] or { 2, 2, 2 }
			return { s[1], s[2], s[3] }
		end
		function env.createGhost(id)
			local g = { catalogId = id, shown = {}, destroyed = false }
			g.show = function(t, valid) g.shown[#g.shown + 1] = { t = t, valid = valid } end
			g.destroy = function() g.destroyed = true end
			env.ghosts[#env.ghosts + 1] = g
			return g
		end
		function env.raycast(pointer) return pointer.hit end
		function env.pickPlaced(pointer) return pointer.pick end
		function env.selectedInfo() return env.selected end
		function env.mouseLocation() return env.mouse end
		function env.setSelectionHighlight() end
		function env.spawn(fn) local co = coroutine.create(fn); env.spawned[#env.spawned + 1] = co; assert(coroutine.resume(co)) end
		function env.wait() coroutine.yield("wait") end
		env.c = BuildController.new(env)
		return env
	end
	local function at(x, z) return { hit = hit(x, z) } end
	local function ids(items)
		local out = {}
		for _, item in ipairs(items) do out[#out + 1] = item.id end
		return out
	end
	local function lastOp(env)
		return env.requests[#env.requests]
	end
	local function lastGhost(env)
		local g = env.ghosts[#env.ghosts]
		return g and g.shown[#g.shown]
	end

	T.test("controller: furniture filters never show structure pieces; Structure mode relabels the row and lists each kind", function()
		local env = setup()
		T.eq(env.c:open(), true)
		T.eq(env.drawer.category, "furniture")
		T.eq(#env.drawer.filters, 5)
		for _, c in ipairs(Catalog.getCollectionsSorted()) do
			env.drawer.callbacks.onFilter(c.id)
			env.drawer.callbacks.onType("all")
			for _, item in ipairs(env.drawer.items) do
				T.eq(Catalog.getItem(item.id).structure, nil, c.id .. " shows furniture only: " .. item.id)
			end
		end
		T.eq(#env.drawer.items, 21, "futuristic furniture")
		env.drawer.callbacks.onCategory("structure")
		T.eq(env.drawer.category, "structure")
		local labels = {}
		for i, f in ipairs(env.drawer.filters) do labels[i] = f.displayName end
		T.eq(table.concat(labels, ","), "Floors,Walls,Doors,Ceilings,Windows")
		T.eq(env.drawer.filter, "floor")
		T.deepEq(ids(env.drawer.items), { "structure_floor_01", "structure_floor_oak_01", "structure_floor_walnut_01", "structure_floor_concrete_01", "structure_floor_slate_01" })
		local expected = {
			{ "wall", { "structure_wall_01", "structure_wall_wood_01", "structure_wall_brick_01", "structure_industrial_wall_01", "structure_acoustic_wall_01" } },
			{ "doorway", { "structure_doorway_01", "structure_doorway_wide_01", "structure_doorway_panel_01" } },
			{ "ceiling", { "structure_ceiling_01", "structure_ceiling_dark_01", "structure_ceiling_acoustic_01" } },
			{ "window_wall", { "structure_window_wall_01", "structure_window_black_01", "structure_glass_partition_01", "structure_window_arch_01" } },
		}
		for _, pair in ipairs(expected) do
			local kind, list = pair[1], pair[2]
			env.drawer.callbacks.onFilter(kind)
			T.deepEq(ids(env.drawer.items), list, kind)
			T.eq(env.drawer.filter, kind)
		end
		env.drawer.callbacks.onFilter("cozy")
		T.deepEq(ids(env.drawer.items), { "structure_window_wall_01", "structure_window_black_01", "structure_glass_partition_01", "structure_window_arch_01" }, "a style id in Structure mode is ignored")
		env.drawer.callbacks.onCategory("furniture")
		T.eq(env.drawer.filter, "futuristic", "furniture filter remembered")
		T.eq(env.drawer.typeView, "chooser", "back in furniture: the type chooser")
		env.drawer.callbacks.onType("all")
		T.eq(#env.drawer.items, 21)
	end)

	T.test("controller: switching category while placing cancels the stale placement; nothing is sent", function()
		local env = setup()
		env.c:open()
		env.c:chooseItem("cozy_plant_01")
		env.c:onPointerMoved(at(2, 2), "touch")
		T.eq(env.c.session.mode, "placing")
		local ghost = env.ghosts[#env.ghosts]
		local sent = #env.requests
		env.drawer.callbacks.onCategory("structure")
		T.eq(env.c.session.mode, "idle")
		T.eq(ghost.destroyed, true)
		T.eq(env.c.lastPreview, nil)
		env.c:confirmPlacement()
		env.c:onPointerPressed(at(2, 2), "mouse")
		T.eq(#env.requests, sent, "no Place for the cancelled furniture item")
	end)

	T.test("controller: missing structure templates show as not installed and cannot start placing", function()
		local env = setup()
		env.missing.structure_wall_01 = true
		env.c:open()
		env.drawer.callbacks.onCategory("structure")
		env.drawer.callbacks.onFilter("wall")
		T.eq(env.drawer.items[1].installed, false)
		env.c:chooseItem("structure_wall_01")
		T.eq(env.c.session.mode, "idle")
		T.eq(env.c.session.message, "That item isn't installed yet.")
	end)

	T.test("controller: structure ghost uses the grid; a click sends exactly the previewed transform; a ceiling goes to y 15", function()
		local env = setup(FUTURE)
		env.c:open()
		env.drawer.callbacks.onCategory("structure")
		env.c:chooseItem("structure_ceiling_01")
		env.c:onPointerPressed(at(9, -7), "mouse")
		T.deepEq(lastOp(env), { op = "Place", itemId = "structure_ceiling_01", transform = { x = 16, y = 15, z = 0, yaw = 0 } })
		T.eq(lastGhost(env).valid, true)
		T.eq(env.drawer.status, "Build your studio.")
		env.c:chooseItem("structure_wall_01")
		T.eq(env.c.session.itemKind, "wall")
		env.c:onPointerMoved(at(3, 23.6), "touch")
		T.eq(env.drawer.status, "Placing: snaps to the 16-stud room grid. Angle 0° [R]")
		T.deepEq(lastGhost(env).t, { x = 0, y = 0, z = 24, yaw = 0 })
		T.eq(lastGhost(env).valid, true, "the outer edge fits the 49 marker")
		env.drawer.callbacks.onPlaceHere()
		T.deepEq(lastOp(env).transform, { x = 0, y = 0, z = 24, yaw = 0 })
	end)

	T.test("controller: on the live 48 marker an outer-edge ghost is invalid and nothing is sent; the footer explains", function()
		local env = setup(LIVE)
		env.c:open()
		env.drawer.callbacks.onCategory("structure")
		env.c:chooseItem("structure_doorway_01")
		env.c:rotate() -- 90: along Z, so the pointer picks an x edge line
		local sent = #env.requests
		env.c:onPointerPressed(at(23.6, 3), "mouse")
		T.deepEq(lastGhost(env).t, { x = 24, y = 0, z = 0, yaw = 90 })
		T.eq(lastGhost(env).valid, false)
		T.eq(#env.requests, sent)
		T.eq(env.c.session.message, Protocol.message("OutOfBounds"))
		env.c:onPointerPressed(at(8.3, 3), "mouse")
		T.deepEq(lastOp(env).transform, { x = 8, y = 0, z = 0, yaw = 90 }, "an inner edge is sent")
	end)

	T.test("controller: Rotate re-validates the preview; a rotate without a fresh preview never sends the old spot", function()
		local env = setup(FUTURE)
		env.c:open()
		env.drawer.callbacks.onCategory("structure")
		env.c:chooseItem("structure_wall_01")
		env.c:onPointerMoved(at(3, 7), "touch")
		T.deepEq(lastGhost(env).t, { x = 0, y = 0, z = 8, yaw = 0 })
		env.c:rotate()
		T.deepEq(lastGhost(env).t, { x = 8, y = 0, z = 0, yaw = 90 }, "R turns the wall 90 degrees and re-validates")
		T.eq(env.c.lastPreview.yaw, 90)
		-- The preview can't be recomputed (size unknown): the stale one is dropped, not sent.
		env.noSize = true
		env.c:rotate()
		T.eq(env.c.lastPreview, nil)
		local sent = #env.requests
		env.drawer.callbacks.onPlaceHere()
		T.eq(#env.requests, sent, "no Place without a current preview")
		env.noSize = nil
		env.c:onPointerMoved(at(3, 7), "touch")
		env.drawer.callbacks.onPlaceHere()
		T.deepEq(lastOp(env).transform, { x = 0, y = 0, z = 8, yaw = 180 }, "the locked yaw (180 after two turns) is sent")
		-- A preview computed for an older yaw is refused even if still cached.
		env.c:chooseItem("structure_floor_01")
		env.c:onPointerMoved(at(0, 0), "touch")
		env.c.session.previewYaw = 90 -- yaw changed without a recompute
		local before = #env.requests
		env.drawer.callbacks.onPlaceHere()
		T.eq(#env.requests, before)
	end)

	T.test("controller: moving a structure item previews with its kind; validation reasons reach the footer", function()
		local env = setup(FUTURE)
		env.c:open()
		env.selected = { catalogId = "structure_window_wall_01", yaw = 90 }
		env.c:onPointerPressed({ hit = hit(0, 0), pick = "i7" }, "mouse")
		T.eq(env.c.session.mode, "selected")
		env.c:beginMove()
		T.eq(env.c.session.itemKind, "window_wall")
		env.c:onPointerMoved(at(-7, 3), "touch")
		T.deepEq(lastGhost(env).t, { x = -8, y = 0, z = 0, yaw = 90 })
		env.drawer.callbacks.onPlaceHere()
		T.deepEq(lastOp(env), { op = "Move", id = "i7", transform = { x = -8, y = 0, z = 0, yaw = 90 } })
		-- A non-cardinal yaw (impossible for stored structure items) previews invalid with a reason.
		env.selected = { catalogId = "structure_floor_01", yaw = 45 }
		env.c:onPointerPressed({ hit = hit(0, 0), pick = "i8" }, "mouse")
		env.c:beginMove()
		env.c:onPointerMoved(at(1, 1), "touch")
		T.eq(env.c.lastPreview.code, "OffGrid")
		T.eq(env.c.lastPreview.reason, "BadYaw")
		env.drawer.callbacks.onPlaceHere()
		T.eq(env.c.session.message, Protocol.message("OffGrid"))
		-- A server refusal shows its message too.
		env.c:cancel()
		env.reply = function() return { ok = false, code = "OffGrid", reason = "BadLevel", status = { state = "ready", revision = env.revision } } end
		env.drawer.callbacks.onRotate()
		T.eq(env.drawer.footer, Protocol.message("OffGrid"))
	end)
	T.test("controller: the panel door ghost is invalid where its swing leaves the build area; nothing is sent and the footer explains", function()
		local env = setup(FUTURE)
		env.c:open()
		env.drawer.callbacks.onCategory("structure")
		env.c:chooseItem("structure_doorway_panel_01")
		T.eq(env.c.session.itemKind, "doorway")
		env.c:onPointerMoved(at(3, 23.6), "touch")
		T.deepEq(lastGhost(env).t, { x = 0, y = 0, z = 24, yaw = 0 })
		T.eq(lastGhost(env).valid, true, "facing into the room on the 49 marker")
		env.c:rotate()
		env.c:rotate()
		T.deepEq(lastGhost(env).t, { x = 0, y = 0, z = 24, yaw = 180 })
		T.eq(lastGhost(env).valid, false, "facing out of the room")
		local sent = #env.requests
		env.c:onPointerPressed(at(3, 23.6), "mouse")
		T.eq(lastGhost(env).valid, false)
		T.eq(#env.requests, sent, "nothing is sent")
		T.eq(env.c.session.message, Protocol.message("SwingOutOfBounds"))
		env.c:onPointerMoved(at(3, -23.6), "touch")
		T.deepEq(lastGhost(env).t, { x = 0, y = 0, z = -24, yaw = 180 })
		env.drawer.callbacks.onPlaceHere()
		T.deepEq(lastOp(env), { op = "Place", itemId = "structure_doorway_panel_01", transform = { x = 0, y = 0, z = -24, yaw = 180 } })
		-- The plain doorway on the same outward spot is valid (it has no swing).
		env.c:chooseItem("structure_doorway_01")
		env.c:onPointerMoved(at(3, 23.6), "touch")
		T.eq(lastGhost(env).valid, true)
	end)
end
