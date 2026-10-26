-- Task 10: StructureGrid integrated into server placement (PlacementCore).
-- The structure catalog items and template sizes below are TEST FIXTURES
-- ONLY (ids prefixed "fixture_"); the live 31-item catalog has no structure
-- entries. Candidate registration is a later checkpoint.
return function(T, H)
	local PlacementCore = H.load("src/server/Core/PlacementCore")
	local Catalog = H.load("src/shared/Catalog")
	local Config = H.load("src/shared/Config")
	local TemplateCatalog = H.load("src/server/Adapters/TemplateCatalog")
	local Transform = H.load("src/shared/Transform")

	local HOST, GUEST = 1001, 2002
	local LIVE = { halfX = 24, halfZ = 24, height = 24 } -- current 48 x 24 x 48 marker
	local FUTURE = { halfX = 24.5, halfZ = 24.5, height = 24 } -- proposed 49 x 24 x 49

	local FIXTURES = {
		{ id = "fixture_floor", displayName = "Fixture Floor", collections = { "cozy" }, structure = { kind = "floor" } },
		{ id = "fixture_ceiling", displayName = "Fixture Ceiling", collections = { "cozy" }, structure = { kind = "ceiling" } },
		{ id = "fixture_wall", displayName = "Fixture Wall", collections = { "cozy" }, structure = { kind = "wall" } },
		{ id = "fixture_window_wall", displayName = "Fixture Window Wall", collections = { "cozy" }, structure = { kind = "window_wall" } },
		{ id = "fixture_doorway", displayName = "Fixture Doorway", collections = { "cozy" }, structure = { kind = "doorway" } },
		-- Malformed on purpose: corners are not an approved kind.
		{ id = "fixture_corner", displayName = "Fixture Corner", collections = { "cozy" }, structure = { kind = "corner" } },
	}
	local SIZES = {
		fixture_floor = { 16, 1, 16 }, fixture_ceiling = { 16, 1, 16 },
		fixture_wall = { 16, 15, 1 }, fixture_window_wall = { 16, 15, 1 }, fixture_doorway = { 16, 15, 1 },
		fixture_corner = { 16, 15, 16 },
		cozy_plant_01 = { 2.93, 5.72, 2.93 }, cozy_armchair_01 = { 5.0, 4.73, 4.25 },
	}
	local fixtureById = {}
	for _, item in ipairs(FIXTURES) do fixtureById[item.id] = item end
	local testCatalog = {
		getItem = function(id)
			if type(id) ~= "string" then return nil end
			return fixtureById[id] or Catalog.getItem(id)
		end,
	}

	local function fakeWorld()
		local w = { live = {}, calls = {}, failApply = nil }
		local function copy(r) return { itemId = r.itemId, x = r.x, y = r.y, z = r.z, yaw = r.yaw } end
		function w:apply(effect)
			self.calls[#self.calls + 1] = "apply:" .. effect.kind
			if self.failApply == effect.kind then error("world failure") end
			if effect.kind == "replace" then
				local old = self.live
				self.live = {}
				for _, e in ipairs(effect.entries) do self.live[e.id] = copy(e.record) end
				return { kind = "replace", old = old }
			end
			local previous = self.live[effect.id]
			if effect.kind == "spawn" then self.live[effect.id] = copy(effect.record)
			elseif effect.kind == "move" then self.live[effect.id] = copy(effect.to)
			elseif effect.kind == "remove" then self.live[effect.id] = nil end
			return { kind = effect.kind, id = effect.id, previous = previous }
		end
		function w:rollback(token)
			if token.kind == "replace" then self.live = token.old else self.live[token.id] = token.previous end
		end
		function w:commit() end
		function w:publishRevision() end
		return w
	end

	local function setup(bounds)
		local env = { host = HOST, now = 0 }
		env.world = fakeWorld()
		env.core = PlacementCore.new({
			config = Config,
			catalog = testCatalog,
			templates = {
				isInstalled = function(id) return SIZES[id] ~= nil end,
				getSize = function(id) local s = SIZES[id]; return s and { s[1], s[2], s[3] } or nil end,
			},
			entitlements = { isItemUnlocked = function() return true end },
			authority = { check = function(_, userId) return userId == env.host end },
			bounds = bounds or LIVE,
			world = env.world,
			clock = function() return env.now end,
		})
		function env.req(payload, userId)
			env.now = env.now + 1
			return env.core:handle(userId or HOST, payload)
		end
		function env.place(itemId, x, y, z, yaw)
			return env.req({ op = "Place", itemId = itemId, transform = { x = x, y = y, z = z, yaw = yaw } })
		end
		function env.get(id) return env.core.model:get(id) end
		return env
	end

	-- Model + revision + world + history availability, to prove refusals change nothing.
	local function snapshot(env)
		local parts = { "rev=" .. env.core:getRevision(), "calls=" .. #env.world.calls }
		for _, e in ipairs(env.core:list()) do
			local r = e.record
			parts[#parts + 1] = string.format("%s:%s:%g,%g,%g,%g", e.id, r.itemId, r.x, r.y, r.z, r.yaw)
		end
		local st = env.core:status(HOST)
		parts[#parts + 1] = "undo=" .. tostring(st.canUndo) .. ",redo=" .. tostring(st.canRedo)
		return table.concat(parts, "|")
	end
	local function refused(env, payload, code, reason, userId)
		local before = snapshot(env)
		local r = env.req(payload, userId)
		T.eq(r.ok, false, "refused: " .. tostring(payload.op))
		T.eq(r.code, code, tostring(payload.op) .. " code")
		if reason ~= nil then T.eq(r.reason, reason, tostring(payload.op) .. " reason") end
		T.eq(snapshot(env), before, "refusal changed nothing")
		return r
	end
	local function pose(env, id)
		local r = env.get(id)
		return { x = r.x, y = r.y, z = r.z, yaw = r.yaw }
	end

	-- Catalog / listing interfaces --------------------------------------------------------

	T.test("catalog: only the 18 registered structure pieces carry structure; metadata is optional and strictly validated", function()
		local kinds = {}
		for _, item in ipairs(Catalog.Items) do
			if item.structure ~= nil then
				kinds[item.id] = item.structure.kind
			end
		end
		T.eq(#Catalog.Items, 58)
		for i = 1, 31 do
			T.eq(Catalog.Items[i].structure, nil, Catalog.Items[i].id .. " (furniture)")
		end
		T.eq(Catalog.Items[37].structure, nil, "record player is furniture")
		T.eq(Catalog.Items[38].structure, nil, "radio is furniture")
		T.eq(Catalog.Items[39].structure, nil, "patterned rug is furniture")
		T.eq(Catalog.Items[40].structure, nil, "classic floor lamp is furniture")
		T.deepEq(kinds, {
			structure_wall_01 = "wall", structure_window_wall_01 = "window_wall", structure_doorway_01 = "doorway", structure_floor_01 = "floor", structure_ceiling_01 = "ceiling",
			structure_floor_oak_01 = "floor", structure_floor_walnut_01 = "floor", structure_floor_concrete_01 = "floor", structure_floor_slate_01 = "floor",
			structure_wall_wood_01 = "wall", structure_wall_brick_01 = "wall", structure_ceiling_dark_01 = "ceiling",
			structure_window_black_01 = "window_wall", structure_doorway_wide_01 = "doorway",
			structure_glass_partition_01 = "window_wall", structure_ceiling_acoustic_01 = "ceiling",
			structure_industrial_wall_01 = "wall", structure_acoustic_wall_01 = "wall",
		})
		local collections = { { id = "cozy", displayName = "Cozy" } }
		local function check(structure)
			return Catalog.validateData(collections, { { id = "x_item", displayName = "X", collections = { "cozy" }, structure = structure } })
		end
		for _, kind in ipairs({ "floor", "ceiling", "wall", "window_wall", "doorway" }) do
			T.eq((check({ kind = kind })), true, kind)
		end
		for _, bad in ipairs({ { kind = "corner" }, { kind = "window" }, { kind = "Wall" }, { kind = "wall", offset = 7.5 }, {}, "wall", 5 }) do
			local ok, errors = check(bad)
			T.eq(ok, false)
			T.ok(errors[1]:find("invalid structure metadata", 1, true), tostring(errors[1]))
		end
		-- Template listing passes the kind through as a copy.
		local tc = TemplateCatalog.build({ Items = FIXTURES }, function(id) return SIZES[id] and { size = SIZES[id] } or nil end)
		local listing = tc:clientListing()
		T.deepEq(listing[3].structure, { kind = "wall" })
		listing[3].structure.kind = "floor"
		T.eq(FIXTURES[3].structure.kind, "wall", "listing does not alias the catalog")
		T.eq(TemplateCatalog.build(Catalog, function() return nil end):clientListing()[1].structure, nil)
	end)

	-- Furniture unchanged ---------------------------------------------------------------

	T.test("furniture placement is unchanged: free positions, 15-degree yaw and rotation, size-based duplicate", function()
		local env = setup(LIVE)
		local r = env.place("cozy_plant_01", 3.37, 0, -2.25, 15)
		T.eq(r.ok, true)
		T.deepEq(pose(env, r.id), { x = 3.37, y = 0, z = -2.25, yaw = 15 })
		T.eq(env.req({ op = "Rotate", id = r.id }).ok, true)
		T.eq(env.get(r.id).yaw, 30)
		local dup = env.req({ op = "Duplicate", id = r.id })
		T.eq(dup.ok, true)
		local hx = Transform.halfExtents(SIZES.cozy_plant_01, 30)
		local dx = math.ceil(hx * 2 / Config.GridSize) * Config.GridSize -- the pre-existing formula
		T.eq(dx, 5)
		T.deepEq(pose(env, dup.id), { x = 3.37 + dx, y = 0, z = -2.25, yaw = 30 }, "offset by the rounded-up yawed footprint, as before")
		T.eq(env.place("cozy_armchair_01", 0, 2.5, 0, 45).ok, true, "furniture may float and use any 15-degree yaw")
	end)

	-- Place -----------------------------------------------------------------------------------

	T.test("structure Place: on-grid pieces of every kind at their levels; off-grid, level and yaw refusals are OffGrid with reasons", function()
		local env = setup(LIVE)
		T.eq(env.place("fixture_floor", -16, 0, 16, 90).ok, true)
		T.eq(env.place("fixture_ceiling", 0, 15, 0, 0).ok, true)
		T.eq(env.place("fixture_wall", 0, 0, 8, 0).ok, true)
		T.eq(env.place("fixture_window_wall", 8, 0, -16, 270).ok, true)
		T.eq(env.place("fixture_doorway", -8, 0, 0, 90).ok, true)
		local w = env.place("fixture_wall", 0.004, 0, -7.996, 180)
		T.deepEq(pose(env, w.id), { x = 0, y = 0, z = -8, yaw = 180 }, "within 0.01 snaps exactly")
		local t = function(x, y, z, yaw) return { op = "Place", itemId = "fixture_wall", transform = { x = x, y = y, z = z, yaw = yaw } } end
		refused(env, t(0, 0, 0, 0), "OffGrid", "OffGrid")
		refused(env, t(8, 0, 0, 0), "OffGrid", "OffGrid")
		refused(env, t(0, 0, 8.5, 0), "OffGrid", "OffGrid")
		refused(env, t(0, 1, 8, 0), "OffGrid", "BadLevel")
		refused(env, t(0, 0, 8, 15), "OffGrid", "BadYaw")
		refused(env, t(0, 0, 8, 45), "OffGrid", "BadYaw")
		refused(env, { op = "Place", itemId = "fixture_ceiling", transform = { x = 0, y = 0, z = 0, yaw = 0 } }, "OffGrid", "BadLevel")
		refused(env, { op = "Place", itemId = "fixture_floor", transform = { x = 8, y = 0, z = 0, yaw = 0 } }, "OffGrid", "OffGrid")
		refused(env, { op = "Place", itemId = "fixture_corner", transform = { x = 0, y = 0, z = 0, yaw = 0 } }, "UnknownItem")
	end)

	T.test("outer bounds with no overhang: outer walls at +/-24 refused on the live 48 marker, accepted on the proposed 49 marker", function()
		local live, future = setup(LIVE), setup(FUTURE)
		local outer = { { 0, 24, 0 }, { -16, -24, 180 }, { 24, 16, 90 }, { -24, 0, 270 } }
		for _, o in ipairs(outer) do
			refused(live, { op = "Place", itemId = "fixture_wall", transform = { x = o[1], y = 0, z = o[2], yaw = o[3] } }, "OutOfBounds")
			T.eq(future.place("fixture_wall", o[1], 0, o[2], o[3]).ok, true, "future accepts " .. o[1] .. "," .. o[2])
		end
		-- 3 x 3 floors and ceilings fit both; a fourth ring fits neither.
		for _, env in ipairs({ live, future }) do
			for _, x in ipairs({ -16, 0, 16 }) do
				T.eq(env.place("fixture_floor", x, 0, -16, 0).ok, true)
				T.eq(env.place("fixture_ceiling", x, 15, 16, 0).ok, true, "ceiling top 16 fits height 24")
			end
			refused(env, { op = "Place", itemId = "fixture_floor", transform = { x = 32, y = 0, z = 0, yaw = 0 } }, "OutOfBounds")
			refused(env, { op = "Place", itemId = "fixture_wall", transform = { x = 32, y = 0, z = 24, yaw = 0 } }, "OutOfBounds")
		end
	end)

	T.test("hostile and malformed structure requests are refused before any change", function()
		local env = setup(FUTURE)
		local place = function(transform, itemId) return { op = "Place", itemId = itemId or "fixture_wall", transform = transform } end
		refused(env, place({ y = 0, z = 8, yaw = 0 }), "BadTransform")
		refused(env, place({ x = 0, z = 8, yaw = 0 }), "BadTransform")
		refused(env, place({ x = 0, y = 0, yaw = 0 }), "BadTransform")
		refused(env, place({ x = 0, y = 0, z = 0 / 0, yaw = 0 }), "BadTransform")
		refused(env, place({ x = 0, y = 0, z = math.huge, yaw = 0 }), "BadTransform")
		refused(env, place({ x = "0", y = 0, z = 8, yaw = 0 }), "BadTransform")
		refused(env, place({ x = 0, y = 0, z = 8, yaw = 0, kind = "floor" }), "BadTransform")
		refused(env, place({ x = 0, y = 0, z = 8, yaw = 0 }, "fixture_missing"), "UnknownItem")
		refused(env, { op = "Place", itemId = "fixture_wall", transform = { x = 0, y = 0, z = 8, yaw = 0 }, structure = { kind = "floor" } }, "BadRequest")
		refused(env, place({ x = 0, y = 0, z = 8, yaw = 0 }), "NotHost", nil, GUEST)
		local w = env.place("fixture_wall", 0, 0, 8, 0)
		refused(env, { op = "Move", id = w.id, transform = { x = 0, z = 8, yaw = 0 } }, "BadTransform")
		refused(env, { op = "Rotate", id = w.id, direction = 2 }, "BadRequest")
		refused(env, { op = "Rotate", id = w.id }, "NotHost", nil, GUEST)
		refused(env, { op = "Duplicate", id = w.id }, "NotHost", nil, GUEST)
	end)

	-- Move / Rotate / Duplicate -----------------------------------------------------------------

	T.test("structure Move uses the same grid rules; an edge piece must match its yaw axis", function()
		local env = setup(LIVE)
		local w = env.place("fixture_wall", 0, 0, 8, 0)
		T.eq(env.req({ op = "Move", id = w.id, transform = { x = 16, y = 0, z = -8, yaw = 180 } }).ok, true)
		T.deepEq(pose(env, w.id), { x = 16, y = 0, z = -8, yaw = 180 })
		T.eq(env.req({ op = "Move", id = w.id, transform = { x = 8, y = 0, z = 0, yaw = 90 } }).ok, true, "to a Z-axis edge with a Z yaw")
		refused(env, { op = "Move", id = w.id, transform = { x = 8, y = 0, z = 0, yaw = 0 } }, "OffGrid", "OffGrid")
		refused(env, { op = "Move", id = w.id, transform = { x = 8, y = 0, z = 0, yaw = 30 } }, "OffGrid", "BadYaw")
		refused(env, { op = "Move", id = w.id, transform = { x = 24, y = 0, z = 0, yaw = 90 } }, "OutOfBounds")
		local f = env.place("fixture_floor", 0, 0, 0, 0)
		refused(env, { op = "Move", id = f.id, transform = { x = 4, y = 0, z = 0, yaw = 0 } }, "OffGrid", "OffGrid")
	end)

	T.test("structure Rotate: 90-degree steps; floors turn in place; edge pieces hinge at an end point (provisional) and respect bounds", function()
		local env = setup(FUTURE)
		local f = env.place("fixture_floor", 16, 0, -16, 0)
		T.eq(env.req({ op = "Rotate", id = f.id }).ok, true)
		T.deepEq(pose(env, f.id), { x = 16, y = 0, z = -16, yaw = 90 })
		T.eq(env.req({ op = "Rotate", id = f.id, direction = -1 }).ok, true)
		T.eq(env.get(f.id).yaw, 0)
		local w = env.place("fixture_wall", 0, 0, 8, 0)
		T.eq(env.req({ op = "Rotate", id = w.id }).ok, true)
		T.deepEq(pose(env, w.id), { x = 8, y = 0, z = 16, yaw = 90 }, "hinged at (8, 8)")
		T.eq(env.req({ op = "Rotate", id = w.id, direction = -1 }).ok, true)
		T.deepEq(pose(env, w.id), { x = 0, y = 0, z = 8, yaw = 0 }, "-1 from (8, 16, 90) hinges at (8, 8) back to (0, 8)")
		-- At the outer edge the first candidate is outside; the fixed order picks the next.
		local outer = env.place("fixture_doorway", 16, 0, 24, 0)
		T.eq(env.req({ op = "Rotate", id = outer.id }).ok, true)
		T.deepEq(pose(env, outer.id), { x = 24, y = 0, z = 16, yaw = 90 })
		-- Every candidate out of bounds: refused, nothing changed.
		local tight = setup({ halfX = 8, halfZ = 8.5, height = 24 })
		local only = tight.place("fixture_wall", 0, 0, 8, 0)
		T.eq(only.ok, true)
		refused(tight, { op = "Rotate", id = only.id }, "OutOfBounds")
		-- On the live marker, a wall hinging toward an outer edge falls back inside.
		local live = setup(LIVE)
		local lw = live.place("fixture_wall", 16, 0, 8, 0)
		T.eq(live.req({ op = "Rotate", id = lw.id }).ok, true)
		local p = pose(live, lw.id)
		T.eq(p.yaw, 90)
		T.ok(math.abs(p.x) + 0.5 <= 24 and math.abs(p.z) + 8 <= 24, "inside the live bounds")
	end)

	T.test("structure Duplicate steps one 16-stud cell or edge, stays on the grid and respects the supplied bounds", function()
		local env = setup(LIVE)
		local f = env.place("fixture_floor", 0, 0, 0, 0)
		local d1 = env.req({ op = "Duplicate", id = f.id })
		T.deepEq(pose(env, d1.id), { x = 16, y = 0, z = 0, yaw = 0 })
		local d2 = env.req({ op = "Duplicate", id = d1.id })
		T.deepEq(pose(env, d2.id), { x = 0, y = 0, z = 0, yaw = 0 }, "+x would leave the 48 marker, so -x")
		local wx = env.place("fixture_wall", 0, 0, 8, 0)
		T.deepEq(pose(env, env.req({ op = "Duplicate", id = wx.id }).id), { x = 16, y = 0, z = 8, yaw = 0 }, "continues along X")
		local wz = env.place("fixture_doorway", -8, 0, 0, 270)
		T.deepEq(pose(env, env.req({ op = "Duplicate", id = wz.id }).id), { x = -8, y = 0, z = 16, yaw = 270 }, "continues along Z")
		local c = env.place("fixture_ceiling", -16, 15, 16, 0)
		T.deepEq(pose(env, env.req({ op = "Duplicate", id = c.id }).id), { x = 0, y = 15, z = 16, yaw = 0 })
		-- No on-grid spot inside the bounds: refused, nothing changed.
		local tiny = setup({ halfX = 8, halfZ = 8, height = 24 })
		local lone = tiny.place("fixture_floor", 0, 0, 0, 0)
		refused(tiny, { op = "Duplicate", id = lone.id }, "OutOfBounds")
	end)

	-- Atomicity, undo/redo, save/load ------------------------------------------------------------

	T.test("a failed world apply leaves model, history and revision unchanged for structure ops", function()
		local env = setup(FUTURE)
		local w = env.place("fixture_wall", 0, 0, 8, 0)
		for _, case in ipairs({
			{ kind = "spawn", payload = { op = "Place", itemId = "fixture_floor", transform = { x = 0, y = 0, z = 0, yaw = 0 } } },
			{ kind = "move", payload = { op = "Rotate", id = w.id } },
			{ kind = "spawn", payload = { op = "Duplicate", id = w.id } },
			{ kind = "remove", payload = { op = "Delete", id = w.id } },
		}) do
			env.world.failApply = case.kind
			local before = snapshot(env)
			local r = env.req(case.payload)
			T.eq(r.code, "ApplyFailed", case.payload.op)
			-- calls grows by the attempted apply only
			T.eq(snapshot(env):gsub("calls=%d+", ""), before:gsub("calls=%d+", ""), case.payload.op .. " left state unchanged")
		end
		env.world.failApply = nil
		T.deepEq(pose(env, w.id), { x = 0, y = 0, z = 8, yaw = 0 })
	end)

	T.test("mixed furniture and structure Undo/Redo restore exact IDs and transforms through every step", function()
		local env = setup(FUTURE)
		local states = {}
		local function state()
			local out = {}
			for _, e in ipairs(env.core:list()) do
				out[#out + 1] = string.format("%s=%s@%g,%g,%g,%g", e.id, e.record.itemId, e.record.x, e.record.y, e.record.z, e.record.yaw)
			end
			return table.concat(out, ";")
		end
		local function step(payload)
			states[#states + 1] = state()
			local r = env.req(payload)
			T.eq(r.ok, true, payload.op)
			return r
		end
		local plant = step({ op = "Place", itemId = "cozy_plant_01", transform = { x = 3.5, y = 0, z = -2, yaw = 15 } })
		local wall = step({ op = "Place", itemId = "fixture_wall", transform = { x = 0, y = 0, z = 8, yaw = 0 } })
		step({ op = "Rotate", id = wall.id })
		step({ op = "Move", id = plant.id, transform = { x = -4, y = 1, z = 6, yaw = 45 } })
		local floor = step({ op = "Place", itemId = "fixture_floor", transform = { x = -16, y = 0, z = -16, yaw = 0 } })
		step({ op = "Duplicate", id = floor.id })
		step({ op = "Delete", id = wall.id })
		local final = state()
		for i = #states, 1, -1 do
			T.eq(env.req({ op = "Undo" }).ok, true, "undo " .. i)
			T.eq(state(), states[i], "after undo " .. i)
		end
		T.eq(env.req({ op = "Undo" }).code, "NothingToUndo")
		for i = 2, #states do
			T.eq(env.req({ op = "Redo" }).ok, true, "redo " .. i)
			T.eq(state(), states[i], "after redo " .. i)
		end
		T.eq(env.req({ op = "Redo" }).ok, true)
		T.eq(state(), final)
	end)

	T.test("save/load: structure pieces round-trip with no schema change; pieces invalid for the current bounds or grid are preserved and written back", function()
		local src = setup(FUTURE)
		src.place("fixture_floor", 0, 0, 0, 0)
		src.place("fixture_wall", 0, 0, 24, 0) -- outer wall: valid only on the 49 marker
		src.place("cozy_plant_01", 3.5, 0, -2, 15)
		local section = src.core:captureBuild()
		for _, item in ipairs(section.Items) do
			local keys = {}
			for k in pairs(item) do keys[#keys + 1] = k end
			table.sort(keys)
			T.eq(table.concat(keys, ","), "CatalogId,Id,Transform", "no new fields per item")
		end
		-- A hand-edited off-grid wall in the saved section.
		section.Items[#section.Items + 1] = { Id = "i9", CatalogId = "fixture_wall", Transform = { X = 3, Y = 0, Z = 8, Yaw = 0 } }
		section.NextId = 10

		-- Loading into the live 48 marker: the outer wall and the off-grid wall are preserved, not dropped.
		local live = setup(LIVE)
		local plan = live.core:prepareLoad(HOST, section)
		T.ok(plan ~= nil)
		local placed, preserved = {}, {}
		for _, e in ipairs(plan.entries) do placed[#placed + 1] = e.id end
		for _, e in ipairs(plan.preserved) do preserved[#preserved + 1] = e.id end
		T.deepEq(placed, { "i1", "i3" })
		T.deepEq(preserved, { "i2", "i9" })
		T.eq(live.core:loadBuild(HOST, plan).ok, true)
		local resaved = live.core:captureBuild()
		local ids = {}
		for _, item in ipairs(resaved.Items) do ids[#ids + 1] = item.Id end
		T.deepEq(ids, { "i1", "i2", "i3", "i9" }, "preserved entries written back")
		T.eq(resaved.NextId, 10)
		-- History is cleared by the load; a new structure edit doesn't reuse a preserved ID.
		local n = live.place("fixture_floor", 16, 0, 0, 0)
		T.eq(n.id, "i10")

		-- Loading into the proposed 49 marker places the outer wall.
		local future = setup(FUTURE)
		local plan2 = future.core:prepareLoad(HOST, section)
		local placed2 = {}
		for _, e in ipairs(plan2.entries) do placed2[#placed2 + 1] = e.id end
		T.deepEq(placed2, { "i1", "i2", "i3" })
		T.eq(#plan2.preserved, 1, "the off-grid wall stays preserved")
	end)
end
