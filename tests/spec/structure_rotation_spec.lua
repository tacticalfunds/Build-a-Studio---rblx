-- Rotation usability: R / Rotate [R] turns every structure preview 90
-- degrees, the turn holds while the pointer moves (orientation lock), the
-- ghost stays valid exactly where the real server accepts it, and furniture
-- keeps its 15-degree steps. Fakes for drawer, ghosts and remote; the real
-- PlacementCore checks parity.
return function(T, H)
	local StructureGrid = H.load("src/shared/StructureGrid")
	local BuildController = H.load("src/client/Build/BuildController")
	local BuildInput = H.load("src/client/Build/BuildInput")
	local BuildModeHandoff = H.load("src/client/Adapters/BuildModeHandoff")
	local PlacementCore = H.load("src/server/Core/PlacementCore")
	local Catalog = H.load("src/shared/Catalog")
	local Config = H.load("src/shared/Config")

	local FUTURE = { halfX = 24.5, halfZ = 24.5, height = 24 }
	local SIZES = {
		structure_wall_01 = { 16, 15, 1 },
		structure_window_wall_01 = { 16.00006103515625, 14.999996185302734, 1 },
		structure_doorway_01 = { 16, 15.000016212463379, 1 },
		structure_floor_01 = { 16, 1, 16 },
		structure_ceiling_01 = { 16, 1, 16 },
		cozy_plant_01 = { 2.93, 5.72, 2.93 },
	}
	local KINDS = {
		{ id = "structure_wall_01", kind = "wall" },
		{ id = "structure_window_wall_01", kind = "window_wall" },
		{ id = "structure_doorway_01", kind = "doorway" },
		{ id = "structure_floor_01", kind = "floor" },
		{ id = "structure_ceiling_01", kind = "ceiling" },
	}

	-- StructureGrid.project with the orientation lock --------------------------------------

	T.test("project lockYaw: the yaw picks the edge axis and is kept exactly; the default nearest-edge behaviour is unchanged", function()
		for _, kind in ipairs({ "wall", "window_wall", "doorway" }) do
			T.deepEq(StructureGrid.project(kind, { x = 7, z = 3 }, 0, { lockYaw = true }), { x = 0, y = 0, z = 8, yaw = 0 })
			T.deepEq(StructureGrid.project(kind, { x = 7, z = 3 }, 90, { lockYaw = true }), { x = 8, y = 0, z = 0, yaw = 90 })
			T.deepEq(StructureGrid.project(kind, { x = 7, z = 3 }, 180, { lockYaw = true }), { x = 0, y = 0, z = 8, yaw = 180 })
			T.deepEq(StructureGrid.project(kind, { x = 7, z = 3 }, 270, { lockYaw = true }), { x = 8, y = 0, z = 0, yaw = 270 })
			-- Default: nearest edge decides the axis (unchanged).
			T.deepEq(StructureGrid.project(kind, { x = 7, z = 3 }, 0), { x = 8, y = 0, z = 0, yaw = 90 })
			T.deepEq(StructureGrid.project(kind, { x = 7, z = 3 }, 0, { lockYaw = false }), { x = 8, y = 0, z = 0, yaw = 90 })
			T.deepEq(StructureGrid.project(kind, { x = 7, z = 3 }, 0, "lock"), { x = 8, y = 0, z = 0, yaw = 90 }, "non-table options ignored")
		end
		T.deepEq(StructureGrid.project("floor", { x = 9, z = -7 }, 270, { lockYaw = true }), { x = 16, y = 0, z = 0, yaw = 270 })
		T.deepEq(StructureGrid.project("ceiling", { x = 9, z = -7 }, 90, { lockYaw = true }), { x = 16, y = 15, z = 0, yaw = 90 })
		T.eq(select(2, StructureGrid.project("wall", { x = 0, z = 0 }, 45, { lockYaw = true })), "BadYaw")
		-- Every locked projection is on the grid (server validation never says OffGrid).
		for _, k in ipairs(KINDS) do
			for _, yaw in ipairs({ 0, 90, 180, 270 }) do
				for x = -22, 22, 2.75 do
					for z = -22, 22, 2.75 do
						local p = StructureGrid.project(k.kind, { x = x, z = z }, yaw, { lockYaw = true })
						T.eq(p.yaw, yaw)
						local clean, code = StructureGrid.validate(k.kind, p, SIZES[k.id], FUTURE)
						T.ok(clean ~= nil or code == "OutOfBounds", k.kind .. " yaw " .. yaw .. " at " .. x .. "," .. z .. ": " .. tostring(code))
					end
				end
			end
		end
	end)

	-- Controller ------------------------------------------------------------------------------

	local function serverPlace(itemId, t)
		local world = {}
		function world:apply(effect) return { kind = effect.kind } end
		function world:rollback() end
		function world:commit() end
		function world:publishRevision() end
		local core = PlacementCore.new({
			config = Config, catalog = Catalog,
			templates = {
				isInstalled = function(id) return SIZES[id] ~= nil end,
				getSize = function(id) local s = SIZES[id]; return s and { s[1], s[2], s[3] } or nil end,
			},
			entitlements = { isItemUnlocked = function() return true end },
			authority = { check = function(_, userId) return userId == 1001 end },
			bounds = FUTURE, world = world, clock = function() return 1 end,
		})
		return core:handle(1001, { op = "Place", itemId = itemId, transform = { x = t.x, y = t.y, z = t.z, yaw = t.yaw } })
	end

	local function setup()
		local env = { config = Config, catalog = Catalog, requests = {}, ghosts = {}, revision = 0 }
		env.handoff = BuildModeHandoff.new({ hooks = { camera = { enter = function() end, exit = function() end }, hostControls = { enter = function() end, exit = function() end } } })
		function env.request(payload)
			env.requests[#env.requests + 1] = payload
			if payload.op ~= "Status" then env.revision = env.revision + 1 end
			return { ok = true, id = "i" .. env.revision, status = { state = "ready", canUndo = false, canRedo = false, revision = env.revision } }
		end
		function env.readSandbox() return { origin = "O", bounds = FUTURE } end
		function env.isHost() return true end
		function env.createDrawer(callbacks)
			local d = { callbacks = callbacks }
			for _, name in ipairs({ "setPosition", "setInputMode", "refit", "cancelDrag", "setFilter", "setCategory", "showTypes", "showTypeItems", "hideTypes", "setItems", "setFooter", "refresh", "destroy" }) do
				d[name] = function() end
			end
			function d:getPosition() return 18, 178 end
			function d:containsPoint() return false end
			function d:setStatus(text) self.status = text end
			env.drawer = d
			return d
		end
		function env.previewTemplate(id) return { name = id } end
		function env.itemSize(id) local s = SIZES[id] or { 2, 2, 2 }; return { s[1], s[2], s[3] } end
		function env.createGhost(id)
			local g = { catalogId = id, shown = {} }
			g.show = function(t, valid) g.shown[#g.shown + 1] = { t = t, valid = valid } end
			g.destroy = function() end
			env.ghosts[#env.ghosts + 1] = g
			return g
		end
		function env.raycast(pointer) return pointer.hit end
		function env.pickPlaced(pointer) return pointer.pick end
		function env.selectedInfo() return env.selected end
		function env.mouseLocation() return env.mouse end
		function env.setSelectionHighlight() end
		function env.spawn() end
		function env.wait() end
		env.c = BuildController.new(env)
		env.c:open()
		return env
	end
	local function at(x, z) return { hit = { x = x, y = 0, z = z, upDot = 1 } } end
	local function ghost(env)
		local g = env.ghosts[#env.ghosts]
		return g.shown[#g.shown]
	end

	T.test("four R turns of every structure kind: 90-degree steps with visible angle, each ghost valid exactly where the server accepts it", function()
		for _, k in ipairs(KINDS) do
			local env = setup()
			env.drawer.callbacks.onCategory("structure")
			env.c:chooseItem(k.id)
			env.c:onPointerMoved(at(5, 6.5), "touch")
			T.eq(ghost(env).t.yaw, 0)
			local seen = {}
			for turn = 1, 4 do
				env.c:rotate()
				local g = ghost(env)
				local expectedYaw = (turn * 90) % 360
				T.eq(g.t.yaw, expectedYaw, k.kind .. " turn " .. turn)
				T.eq(env.c.lastPreview.yaw, expectedYaw)
				T.eq(env.drawer.status, string.format("Placing: snaps to the 16-stud room grid. Angle %d° [R]", expectedYaw))
				local r = serverPlace(k.id, g.t)
				T.eq(r.ok, g.valid, k.kind .. " parity at turn " .. turn)
				if StructureGrid.Kinds[k.kind].placement == "edge" then
					local axis = StructureGrid.edgeAxis(expectedYaw)
					if axis == "x" then
						T.eq((g.t.z - 8) % 16, 0, "on an X-axis edge line")
					else
						T.eq((g.t.x - 8) % 16, 0, "on a Z-axis edge line")
					end
				end
				seen[g.t.x .. "," .. g.t.z .. "," .. g.t.yaw] = true
			end
			local distinct = 0
			for _ in pairs(seen) do distinct = distinct + 1 end
			T.eq(distinct, 4, k.kind .. ": each turn changes the preview (yaw always differs)")
			-- A click sends exactly the ghost after four turns (back to 0).
			env.drawer.callbacks.onPlaceHere()
			local last = env.requests[#env.requests]
			T.eq(last.op, "Place")
			T.deepEq(last.transform, ghost(env).t)
		end
	end)

	T.test("the chosen angle holds while the pointer crosses edges and cells", function()
		local env = setup()
		env.drawer.callbacks.onCategory("structure")
		env.c:chooseItem("structure_wall_01")
		env.c:rotate() -- 90: along Z
		for step = 0, 40 do
			local x, z = -20 + step, -15 + step * 0.75 -- a diagonal sweep near every kind of edge
			env.c:onPointerMoved(at(x, z), "touch")
			local g = ghost(env)
			T.eq(g.t.yaw, 90, "yaw stays 90 at " .. x .. "," .. z)
			T.eq((g.t.x - 8) % 16, 0, "x on an edge line")
			T.eq(g.t.z % 16, 0, "z at a cell centre")
			T.eq(serverPlace("structure_wall_01", g.t).ok, g.valid, "parity at " .. x .. "," .. z)
		end
		env.c:chooseItem("structure_floor_01")
		env.c:rotate()
		env.c:rotate()
		for step = 0, 20 do
			env.c:onPointerMoved(at(-18 + step * 1.8, 17 - step * 1.7), "touch")
			T.eq(ghost(env).t.yaw, 180, "floor angle stays 180")
		end
	end)

	T.test("furniture keeps 15-degree turns and shows its angle; a selected piece's R uses the server Rotate", function()
		local env = setup()
		env.drawer.callbacks.onType("all")
		env.c:chooseItem("cozy_plant_01")
		env.c:onPointerMoved(at(2.4, -3.6), "touch")
		for turn = 1, 3 do
			env.c:rotate()
			T.eq(ghost(env).t.yaw, turn * 15)
			T.eq(env.drawer.status, string.format("Placing: snaps to floors and tabletops. Angle %d° [R]", turn * 15))
		end
		T.deepEq({ ghost(env).t.x, ghost(env).t.z }, { 2, -4 }, "furniture grid snap unchanged")
		-- A placed, selected structure piece: R sends the authoritative Rotate, no preview.
		env.c:cancel()
		env.selected = { catalogId = "structure_wall_01", yaw = 0 }
		env.c:onPointerPressed({ hit = at(0, 0).hit, pick = "i5" }, "mouse")
		local before = #env.requests
		env.c:rotate()
		T.deepEq(env.requests[before + 1], { op = "Rotate", id = "i5" })
		T.eq(env.c.session.mode, "selected")
	end)

	T.test("R stays protected: ignored while typing or when the game processed it; free-camera keys are never taken", function()
		local function classify(ctx)
			return BuildInput.classify({ keyCode = ctx.key, inputType = "Keyboard", gameProcessed = ctx.processed == true, textFocused = ctx.text == true })
		end
		T.eq(classify({ key = "R" }), "rotate")
		T.eq(classify({ key = "R", text = true }), nil)
		T.eq(classify({ key = "R", processed = true }), nil)
		for _, key in ipairs({ "E", "Q", "V", "F", "One" }) do
			T.eq(classify({ key = key }), nil, key)
		end
		-- A stale preview is never sent after a turn that couldn't be recomputed.
		local env = setup()
		env.drawer.callbacks.onCategory("structure")
		env.c:chooseItem("structure_floor_01")
		env.c:onPointerMoved(at(0, 0), "touch")
		local sizes = env.itemSize
		env.itemSize = function() return nil end
		env.c:rotate()
		T.eq(env.c.lastPreview, nil)
		local before = #env.requests
		env.drawer.callbacks.onPlaceHere()
		T.eq(#env.requests, before)
		env.itemSize = sizes
	end)
end
