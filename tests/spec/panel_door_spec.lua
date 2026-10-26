-- Panel door wall (structure_doorway_panel_01): catalog registration with
-- validated door metadata, the TemplateCatalog Frame/Leaf probe, and the
-- server swept-box placement check (SwingOutOfBounds). Prepared-only: the
-- template is not installed and the auto-open runtime stays dormant, so the
-- template sizes below are the manifest's measured closed bounds.
return function(T, H)
	local Catalog = H.load("src/shared/Catalog")
	local Config = H.load("src/shared/Config")
	local DoorGeometry = H.load("src/shared/DoorGeometry")
	local PlacementCore = H.load("src/server/Core/PlacementCore")
	local TemplateCatalog = H.load("src/server/Adapters/TemplateCatalog")

	local DOOR = "structure_doorway_panel_01"
	local HOST = 1001
	local LIVE = { halfX = 24, halfZ = 24, height = 24 } -- current 48 x 24 x 48 marker
	local FUTURE = { halfX = 24.5, halfZ = 24.5, height = 24 } -- proposed 49 x 24 x 49

	-- Fixture door: a 15-wide leaf hinged at the wall's +x end. Swung open,
	-- its thickness reaches x = 8.5, past the 16 x 15 x 1 wall, so the swing
	-- (not the wall) decides whether a spot by a side edge fits.
	local WIDE = {
		hinge = { x = 8, z = 0 },
		leaf = { center = { 0.5, 4.5, 0 }, size = { 15, 8, 1 } },
		swing = "-z",
		openDegrees = 90,
	}
	-- Fixture door: an 18-wide leaf hinged just past the wall's +x end (about
	-- 17.5 deep when open). Its swept box is wider along z than along x, so
	-- bounds can hold it facing -z but no rotate candidate can hold it turned.
	local DEEP = {
		hinge = { x = 9, z = 0 },
		leaf = { center = { 0.5, 4.5, 0 }, size = { 18, 8, 1 } },
		swing = "-z",
		openDegrees = 90,
	}
	local FIXTURES = {
		fixture_deep_door = { id = "fixture_deep_door", displayName = "Fixture Deep Door", collections = { "cozy" }, structure = { kind = "doorway" }, door = DEEP },
		fixture_wide_door = { id = "fixture_wide_door", displayName = "Fixture Wide Door", collections = { "cozy" }, structure = { kind = "doorway" }, door = WIDE },
		-- Bypasses the Catalog validator on purpose: placement must fail closed.
		fixture_bad_door = { id = "fixture_bad_door", displayName = "Fixture Bad Door", collections = { "cozy" }, structure = { kind = "doorway" }, door = { swing = "+z" } },
	}
	local SIZES = {
		[DOOR] = { 16, 15, 1 }, structure_doorway_01 = { 16, 15, 1 },
		fixture_wide_door = { 16, 15, 1 }, fixture_deep_door = { 16, 15, 1 }, fixture_bad_door = { 16, 15, 1 },
	}
	local testCatalog = {
		getItem = function(id)
			if type(id) ~= "string" then return nil end
			return FIXTURES[id] or Catalog.getItem(id)
		end,
	}

	local function setup(bounds)
		local env = { now = 0, live = {} }
		local world = {}
		function world:apply(effect)
			local previous = env.live[effect.id]
			if effect.kind == "replace" then
				local old = env.live
				env.live = {}
				for _, e in ipairs(effect.entries) do env.live[e.id] = e.record end
				return { kind = "replace", old = old }
			end
			if effect.kind == "spawn" then env.live[effect.id] = effect.record
			elseif effect.kind == "move" then env.live[effect.id] = effect.to
			elseif effect.kind == "remove" then env.live[effect.id] = nil end
			return { kind = effect.kind, id = effect.id, previous = previous }
		end
		function world:rollback(token)
			if token.kind == "replace" then env.live = token.old else env.live[token.id] = token.previous end
		end
		function world:commit() end
		function world:publishRevision() end
		env.core = PlacementCore.new({
			config = Config, catalog = testCatalog,
			templates = {
				isInstalled = function(id) return SIZES[id] ~= nil end,
				getSize = function(id) local s = SIZES[id]; return s and { s[1], s[2], s[3] } or nil end,
			},
			entitlements = { isItemUnlocked = function() return true end },
			authority = { check = function(_, userId) return userId == HOST end },
			bounds = bounds, world = world, clock = function() return env.now end,
		})
		function env.req(payload)
			env.now = env.now + 1
			return env.core:handle(HOST, payload)
		end
		function env.place(itemId, x, z, yaw)
			return env.req({ op = "Place", itemId = itemId, transform = { x = x, y = 0, z = z, yaw = yaw } })
		end
		function env.pose(id)
			local r = env.core.model:get(id)
			return r and { x = r.x, y = r.y, z = r.z, yaw = r.yaw } or nil
		end
		function env.state()
			local parts = { "rev=" .. env.core:getRevision() }
			for _, e in ipairs(env.core:list()) do
				parts[#parts + 1] = string.format("%s:%g,%g,%g", e.id, e.record.x, e.record.z, e.record.yaw)
			end
			return table.concat(parts, "|")
		end
		return env
	end
	local function refused(env, payload, code)
		local before = env.state()
		local r = env.req(payload)
		T.eq(r.ok, false, payload.op .. " refused")
		T.eq(r.code, code, payload.op .. " code")
		T.eq(env.state(), before, payload.op .. " refusal changed nothing")
	end

	-- Outer edges of the 49 marker, with the yaw whose -z swing faces the room.
	local OUTER = {
		{ x = 0, z = 24, inward = 0, outward = 180 },
		{ x = 0, z = -24, inward = 180, outward = 0 },
		{ x = 24, z = 0, inward = 90, outward = 270 },
		{ x = -24, z = 0, inward = 270, outward = 90 },
	}

	-- Catalog ---------------------------------------------------------------------------------------

	T.test("catalog: the panel door wall is a prepared doorway with exactly the measured door metadata from its manifest", function()
		local item = Catalog.getItem(DOOR)
		T.ok(item ~= nil, DOOR)
		T.eq(item.displayName, "Wood Panel Door Wall")
		T.deepEq(item.structure, { kind = "doorway" })
		T.deepEq(item.collections, { "cozy", "retro", "1980s", "winter" })
		T.eq(item.sourceRef, "ServerStorage.StudioBuilderPreparedAssets." .. DOOR)
		T.eq(item.credit, nil, "no creator is recorded")
		T.deepEq(item.door, {
			hinge = { x = 2.4998779296875, z = -0.02 },
			leaf = {
				center = { 0.09984123706817627, 5.100130558013916, -0.02000001072883606 },
				size = { 5.2000732421875, 8.200085639953614, 0.8740000128746033 },
			},
			swing = "-z",
			openDegrees = 90,
		})
		local manifest = H.readFile(H.ROOT .. "/docs/assets/Panel_Door_Wall_Module_Preparation_2026-10-26.json")
		for _, fact in ipairs({
			'"x": 2.4998779296875, "z": -0.02',
			'"center": [0.09984123706817627, 5.100130558013916, -0.02000001072883606]',
			'"size": [5.2000732421875, 8.200085639953614, 0.8740000128746033]',
			'"swing": "-z"', '"openDegrees": 90', '"baseParts": 39,',
			'"sourceRef": "' .. item.sourceRef .. '"', '"children": ["Frame", "Leaf", "WallSurround"]',
			'"inStudioBuilderTemplates": false', '"restoreTested": false',
		}) do
			T.ok(manifest:find(fact, 1, true), fact)
		end
		-- The accepted swept box (module space, 0..90 degrees toward -z).
		local box = DoorGeometry.sweptBox(DoorGeometry.validate(item.door))
		local x0, x1 = manifest:match('"x": %[([%-%d%.]+), ([%-%d%.]+)%]')
		local y0, y1 = manifest:match('"y": %[([%-%d%.]+), ([%-%d%.]+)%]')
		local z0, z1 = manifest:match('"z": %[([%-%d%.]+), ([%-%d%.]+)%]')
		for _, pair in ipairs({ { box.minX, x0 }, { box.maxX, x1 }, { box.minY, y0 }, { box.maxY, y1 }, { box.minZ, z0 }, { box.maxZ, z1 } }) do
			T.ok(math.abs(pair[1] - tonumber(pair[2])) < 1e-6, "swept box " .. pair[2])
		end
		-- The swing stays inside the 16 x 15 module along the wall and under its top.
		T.ok(box.minX > -8 and box.maxX < 8 and box.maxY < 15 and box.maxZ < 0.5, "swing inside the wall's length, height and +z face")
	end)

	T.test("catalog: door metadata is optional and fails closed (doorways only, strictly validated)", function()
		local collections = { { id = "cozy", displayName = "Cozy" } }
		local function check(fields)
			local item = { id = "x_item", displayName = "X", collections = { "cozy" } }
			for k, v in pairs(fields) do item[k] = v end
			return Catalog.validateData(collections, { item })
		end
		T.eq((check({ structure = { kind = "doorway" }, door = WIDE })), true, "valid door on a doorway")
		T.eq((check({ structure = { kind = "doorway" } })), true, "a doorway without a door is unchanged")
		for _, fields in ipairs({
			{ structure = { kind = "wall" }, door = WIDE },
			{ structure = { kind = "window_wall" }, door = WIDE },
			{ type = "decor", door = WIDE },
			{ door = WIDE },
		}) do
			T.eq((check(fields)), false, "door metadata on a non-doorway")
		end
		local function with(patch)
			local d = { hinge = { x = 8, z = 0 }, leaf = { center = { 0, 4.5, 0 }, size = { 16, 8, 1 } }, swing = "-z", openDegrees = 90 }
			patch(d)
			return d
		end
		for name, door in pairs({
			string = "door",
			empty = {},
			plusZ = with(function(d) d.swing = "+z" end),
			zeroOpen = with(function(d) d.openDegrees = 0 end),
			wideOpen = with(function(d) d.openDegrees = 181 end),
			nanHinge = with(function(d) d.hinge.x = 0 / 0 end),
			hingeOff = with(function(d) d.hinge.x = 9 end),
			centredHinge = with(function(d) d.hinge.x = 0 end),
			flatLeaf = with(function(d) d.leaf.size[3] = 0 end),
			belowFloor = with(function(d) d.leaf.center[2] = 3 end),
			extraKey = with(function(d) d.speed = 2 end),
		}) do
			T.eq((check({ structure = { kind = "doorway" }, door = door })), false, "malformed door: " .. name)
		end
		-- Only the panel door carries door metadata.
		for _, item in ipairs(Catalog.Items) do
			T.eq(item.door ~= nil, item.id == DOOR, item.id)
		end
	end)

	-- TemplateCatalog --------------------------------------------------------------------------------

	T.test("template probe: the door is installed only with Frame and Leaf Model children; other items are unaffected", function()
		local function build(models)
			return TemplateCatalog.build(Catalog, function(id)
				if id == DOOR or id == "structure_doorway_01" then
					return { size = { 16, 15, 1 }, models = models }
				end
				return nil
			end)
		end
		local S = TemplateCatalog.Status
		local ok = build({ Frame = true, Leaf = true, WallSurround = true })
		T.eq(ok:status(DOOR), S.Installed)
		T.deepEq(ok:getSize(DOOR), { 16, 15, 1 })
		for name, models in pairs({ none = nil, empty = {}, noLeaf = { Frame = true, WallSurround = true }, noFrame = { Leaf = true }, truthy = { Frame = 1, Leaf = "yes" } }) do
			local tc = build(models)
			T.eq(tc:status(DOOR), S.Invalid, name)
			T.eq(tc.entries[DOOR].reason, "door template needs Frame and Leaf models", name)
			T.eq(tc:status("structure_doorway_01"), S.Installed, "a plain doorway needs no Frame/Leaf: " .. name)
		end
		-- The prepared-only state: no template, so it is not installed and the listing adds no door fields.
		local none = TemplateCatalog.build(Catalog, function() return nil end)
		T.eq(none:status(DOOR), S.NotInstalled)
		for _, entry in ipairs(ok:clientListing()) do
			T.eq(entry.door, nil, entry.id .. " listing unchanged")
		end
	end)

	-- Server placement ------------------------------------------------------------------------------

	T.test("place: every interior edge at every cardinal yaw fits on the live marker; outer edges stay OutOfBounds", function()
		local env = setup(LIVE)
		local placed = 0
		for _, edge in ipairs({ -8, 8 }) do
			for _, cell in ipairs({ -16, 0, 16 }) do
				for _, yaw in ipairs({ 0, 180 }) do
					T.eq(env.place(DOOR, cell, edge, yaw).ok, true, "z edge " .. edge .. " x " .. cell .. " yaw " .. yaw)
					T.eq(env.place(DOOR, edge, cell, yaw + 90).ok, true, "x edge " .. edge .. " z " .. cell .. " yaw " .. (yaw + 90))
					placed = placed + 2
				end
			end
		end
		T.eq(#env.core:list(), placed)
		for _, o in ipairs(OUTER) do
			for _, yaw in ipairs({ o.inward, o.outward }) do
				refused(env, { op = "Place", itemId = DOOR, transform = { x = o.x, y = 0, z = o.z, yaw = yaw } }, "OutOfBounds")
			end
		end
	end)

	T.test("place: on the 49 marker an outer door must swing into the room; facing out is SwingOutOfBounds", function()
		local env = setup(FUTURE)
		for _, o in ipairs(OUTER) do
			refused(env, { op = "Place", itemId = DOOR, transform = { x = o.x, y = 0, z = o.z, yaw = o.outward } }, "SwingOutOfBounds")
			local r = env.place(DOOR, o.x, o.z, o.inward)
			T.eq(r.ok, true, "inward at " .. o.x .. "," .. o.z)
			T.deepEq(env.pose(r.id), { x = o.x, y = 0, z = o.z, yaw = o.inward })
			-- The plain doorway has no swing, so both facings fit.
			T.eq(env.place("structure_doorway_01", o.x, o.z, o.outward).ok, true, "plain doorway facing out")
		end
		-- Yaws equivalent mod 360 are checked after the grid normalizes them.
		refused(env, { op = "Place", itemId = DOOR, transform = { x = 16, y = 0, z = 24, yaw = -180 } }, "SwingOutOfBounds")
		T.eq(env.place(DOOR, 16, 24, 360).ok, true, "yaw 360 = 0, inward")
		-- Malformed metadata that slipped past the catalog fails closed.
		refused(env, { op = "Place", itemId = "fixture_bad_door", transform = { x = 0, y = 0, z = 8, yaw = 0 } }, "UnknownItem")
	end)

	T.test("place: the wide fixture's swing (not its wall) decides a side-edge spot", function()
		local env = setup(LIVE)
		refused(env, { op = "Place", itemId = "fixture_wide_door", transform = { x = 16, y = 0, z = 8, yaw = 0 } }, "SwingOutOfBounds")
		T.eq(env.place("structure_doorway_01", 16, 8, 0).ok, true, "the same wall without a door fits")
		T.eq(env.place("fixture_wide_door", -16, 8, 0).ok, true, "hinge side away from the edge")
		T.eq(env.place("fixture_wide_door", 16, 8, 180).ok, true, "turned, the hinge faces the room")
	end)

	T.test("move: outer spots follow the swing rule; a refused move keeps the door where it was", function()
		local env = setup(FUTURE)
		local d = env.place(DOOR, 0, 8, 0)
		T.eq(d.ok, true)
		for _, o in ipairs(OUTER) do
			refused(env, { op = "Move", id = d.id, transform = { x = o.x, y = 0, z = o.z, yaw = o.outward } }, "SwingOutOfBounds")
			T.eq(env.req({ op = "Move", id = d.id, transform = { x = o.x, y = 0, z = o.z, yaw = o.inward } }).ok, true)
			T.deepEq(env.pose(d.id), { x = o.x, y = 0, z = o.z, yaw = o.inward })
		end
	end)

	T.test("rotate: hinge candidates that swing out are skipped; when none fits the door's refusal is reported", function()
		local env = setup(FUTURE)
		-- From (0, 24, yaw 0): the first +1 candidate (24, 16, 90) swings out
		-- of the +x edge; the next, (8, 16, 90), swings into the room.
		local d = env.place(DOOR, 0, 24, 0)
		T.eq(env.req({ op = "Rotate", id = d.id }).ok, true)
		T.deepEq(env.pose(d.id), { x = 8, y = 0, z = 16, yaw = 90 })
		-- The plain doorway takes the first candidate from the same spot.
		local w = env.place("structure_doorway_01", 16, 24, 0)
		T.eq(env.req({ op = "Rotate", id = w.id }).ok, true)
		T.deepEq(env.pose(w.id), { x = 24, y = 0, z = 16, yaw = 90 })
		-- Every rotated pose stays inside the bounds through a full turn.
		local spin = setup(FUTURE)
		local s = spin.place(DOOR, 0, 24, 0)
		for step = 1, 8 do
			local direction = step <= 4 and 1 or -1
			T.eq(spin.req({ op = "Rotate", id = s.id, direction = direction }).ok, true, "step " .. step)
			local p = spin.pose(s.id)
			T.ok(DoorGeometry.check(Catalog.getItem(DOOR).door, p, FUTURE, Config.BoundsEpsilon) ~= nil, "swing fits after step " .. step)
		end
		-- One edge, one cell wide: only facing in fits, so turning is refused for the swing.
		local tight = setup({ halfX = 8, halfZ = 8.5, height = 24 })
		local only = tight.place(DOOR, 0, 8, 0)
		T.eq(only.ok, true)
		refused(tight, { op = "Rotate", id = only.id }, "OutOfBounds")
		-- A one-cell square: from (0, 8, 0) the +1 candidates are (8, 0, 90) and
		-- (-8, 0, 90); yaw 90 swings toward -x, so only x = 8 fits.
		local square = setup({ halfX = 8.5, halfZ = 8.5, height = 24 })
		local c = square.place(DOOR, 0, 8, 0)
		T.eq(c.ok, true)
		T.eq(square.req({ op = "Rotate", id = c.id }).ok, true)
		T.deepEq(square.pose(c.id), { x = 8, y = 0, z = 0, yaw = 90 })
		-- From (0, -8, 180) the +1 candidates are (8, 0, 270) and (-8, 0, 270);
		-- yaw 270 swings toward +x, so the fixed order's first pick is skipped.
		local s2 = setup({ halfX = 8.5, halfZ = 8.5, height = 24 })
		local st = s2.place(DOOR, 0, -8, 180)
		T.eq(st.ok, true)
		T.eq(s2.req({ op = "Rotate", id = st.id }).ok, true)
		T.deepEq(s2.pose(st.id), { x = -8, y = 0, z = 0, yaw = 270 })
	end)

	T.test("rotate: when every in-bounds candidate swings out, SwingOutOfBounds is reported and nothing changes", function()
		-- 19.6 x 19.2: the deep door's swing spans x -8.51..9.71 and z -9.51..8.71
		-- at (0, 8, 0). Turned onto either x edge line (both directions), the
		-- spans swap and its swing crosses a z limit (by 0.11) or the far x limit.
		local bounds = { halfX = 9.8, halfZ = 9.6, height = 24 }
		local env = setup(bounds)
		local d = env.place("fixture_deep_door", 0, 8, 0)
		T.eq(d.ok, true)
		refused(env, { op = "Rotate", id = d.id }, "SwingOutOfBounds")
		refused(env, { op = "Rotate", id = d.id, direction = -1 }, "SwingOutOfBounds")
		-- The plain doorway in the same bounds turns freely.
		local plain = setup(bounds)
		local w = plain.place("structure_doorway_01", 0, 8, 0)
		T.eq(plain.req({ op = "Rotate", id = w.id }).ok, true)
	end)

	T.test("duplicate: skips a spot whose swing leaves the bounds; reports SwingOutOfBounds when no spot fits", function()
		local env = setup(LIVE)
		local src = env.place("fixture_wide_door", 0, 8, 0)
		T.eq(src.ok, true)
		local dup = env.req({ op = "Duplicate", id = src.id })
		T.eq(dup.ok, true)
		T.deepEq(env.pose(dup.id), { x = -16, y = 0, z = 8, yaw = 0 }, "+x would swing past the edge, so -x")
		local panel = env.place(DOOR, 0, -8, 0)
		local pd = env.req({ op = "Duplicate", id = panel.id })
		T.deepEq(env.pose(pd.id), { x = 16, y = 0, z = -8, yaw = 0 }, "the panel door duplicates along its edge")
		local tight = setup({ halfX = 16, halfZ = 8.5, height = 24 })
		local only = tight.place("fixture_wide_door", 0, 8, 0)
		T.eq(only.ok, true)
		-- +/-x (x = +/-16) and +z (z = 24) put the wall outside; -z (z = -8)
		-- would swing about 15 studs out of the -z edge.
		refused(tight, { op = "Duplicate", id = only.id }, "SwingOutOfBounds")
	end)

	T.test("undo/redo and save/load: door spots go through the same swing check", function()
		local env = setup(FUTURE)
		local d = env.place(DOOR, 0, 24, 0)
		T.eq(env.req({ op = "Move", id = d.id, transform = { x = -24, y = 0, z = 0, yaw = 270 } }).ok, true)
		T.eq(env.req({ op = "Undo" }).ok, true)
		T.deepEq(env.pose(d.id), { x = 0, y = 0, z = 24, yaw = 0 })
		T.eq(env.req({ op = "Redo" }).ok, true)
		T.deepEq(env.pose(d.id), { x = -24, y = 0, z = 0, yaw = 270 })
		-- A saved build with an inward and an outward outer door.
		local section = {
			Version = 1, NextId = 4,
			Items = {
				{ Id = "i1", CatalogId = DOOR, Transform = { X = 0, Y = 0, Z = 24, Yaw = 0 } },
				{ Id = "i2", CatalogId = DOOR, Transform = { X = 24, Y = 0, Z = 0, Yaw = 270 } },
				{ Id = "i3", CatalogId = DOOR, Transform = { X = 0, Y = 0, Z = 8, Yaw = 180 } },
			},
		}
		local function classify(bounds)
			local plan = setup(bounds).core:prepareLoad(HOST, section)
			T.ok(plan ~= nil)
			local placed, preserved = {}, {}
			for _, e in ipairs(plan.entries) do placed[#placed + 1] = e.id end
			for _, e in ipairs(plan.preserved) do preserved[#preserved + 1] = e.id end
			return placed, preserved
		end
		local placed, preserved = classify(FUTURE)
		T.deepEq(placed, { "i1", "i3" })
		T.deepEq(preserved, { "i2" }, "the outward door is preserved, not dropped")
		placed, preserved = classify(LIVE)
		T.deepEq(placed, { "i3" })
		T.deepEq(preserved, { "i1", "i2" }, "outer edges stay out of the live marker")
	end)
end
