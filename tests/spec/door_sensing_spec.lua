-- Panel door runtime: DoorSensing with fake character and overlap queries.
-- Real Roblox overlap behaviour (false positives, part shapes) is NOT
-- exercised here and stays unverified until Studio.
return function(T, H)
	local DoorSensing = H.load("src/server/Runtime/DoorSensing")
	local G = H.load("src/shared/DoorGeometry")

	local META = { hinge = { x = 2.4998779297, z = 0 }, leaf = { center = { 0.0998414308, 4.3001308441, 0 }, size = { 5.2000732422, 8.2000856400, 0.9500000477 } }, swing = "-z", openDegrees = 90 }
	local BOUNDS = { halfX = 24, halfZ = 24, height = 24 }
	local DOOR_MODEL, WALL, CHAIR, FLOOR, ALICE, BOB = {}, {}, {}, {}, {}, {}

	local function reg(record)
		local clean = G.validate(META)
		local r = { coreId = "door#1", model = DOOR_MODEL, spec = clean }
		r.roomBox = G.toRoom(G.sweptBox(clean), record)
		local x, y, z = G.pointToRoom(clean.leaf.center[1], clean.leaf.center[2], clean.leaf.center[3], record)
		r.center = { x = x, y = y, z = z }
		return r
	end
	local REC = { x = 0, y = 0, z = 8, yaw = 0 }

	local function sensing(chars, hits, truncated, extra)
		local deps = {
			bounds = BOUNDS,
			getCharacters = function() return chars end,
			queryBox = function(box, r)
				if type(hits) == "function" then return hits(box, r) end
				return hits, truncated
			end,
		}
		for k, v in pairs(extra or {}) do deps[k] = v end
		return DoorSensing.new(deps)
	end
	local function char(x, z, model, alive, y)
		return { alive = alive ~= false, position = { x = x, y = y or 3, z = z }, model = model }
	end
	local function only(s, r)
		return s:inputs({ r })[r.coreId]
	end

	T.test("queryBox receives the conservative whole-sweep room box from DoorGeometry", function()
		local r = reg(REC)
		local seen
		local s = sensing({}, function(box) seen = box return {}, false end)
		T.deepEq(only(s, r), { nearby = false, occupied = false, blocked = false })
		T.deepEq(seen, G.toRoom(G.sweptBox(G.validate(META)), REC))
		T.ok(seen.maxX > 3.0 and seen.minZ < 8 - 5.02, "includes the hinge-side protrusion and the full far-corner radius")
	end)

	T.test("nearby: living, finite, in-sandbox characters within the radius and height window only", function()
		local r = reg(REC) -- doorway centre about (0.1, 4.3, 8)
		local s = sensing({ char(0, 13, ALICE) }, {})
		T.eq(only(s, r).nearby, true, "5 studs away")
		T.eq(only(sensing({ char(0, 14.5, ALICE) }, {}), r).nearby, false, "6.5 studs away")
		T.eq(only(sensing({ char(0, 9, ALICE, false) }, {}), r).nearby, false, "dead characters don't count")
		T.eq(only(sensing({ char(0, 9, ALICE, true, 14) }, {}), r).nearby, false, "above the sweep's height window")
		for _, bad in ipairs({
			{ alive = true, position = { x = 0 / 0, y = 3, z = 9 } },
			{ alive = true, position = { x = 0, y = math.huge, z = 9 } },
			{ alive = true, position = { x = 0, y = 3 } },
			{ alive = "yes", position = { x = 0, y = 3, z = 9 } },
			{ alive = true, position = { x = 0, y = 3, z = 99 } }, -- outside the sandbox
			"player",
		}) do
			T.eq(only(sensing({ bad }, {}), r).nearby, false, "skipped: " .. tostring(bad))
		end
		T.eq(only(sensing({ char(0, 99, ALICE), char(0, 10, BOB) }, {}), r).nearby, true, "one bad entry doesn't spoil the scan")
	end)

	T.test("failed, malformed or truncated character scans make every door unknown", function()
		local r = reg(REC)
		local many = {}
		for i = 1, 65 do many[i] = char(20, 20, {}) end
		for _, s in ipairs({
			sensing(nil, {}),
			sensing("chars", {}),
			sensing(many, {}),
			DoorSensing.new({ bounds = BOUNDS, getCharacters = function() error("scan failed") end, queryBox = function() return {}, false end }),
		}) do
			T.deepEq(s:inputs({ r }), {}, "no input: the door holds")
		end
	end)

	T.test("overlap classification: own door ignored, avatars occupied even when non-colliding, non-solid parts ignored, solid parts block; structure never ignored wholesale", function()
		local r = reg(REC)
		local function classify(hits, chars)
			return only(sensing(chars or { char(20, 20, ALICE) }, hits), r)
		end
		T.deepEq(classify({ { model = DOOR_MODEL, solid = true, maxY = 9 } }), { nearby = false, occupied = false, blocked = false }, "the owning door model is ignored")
		T.eq(classify({ { model = ALICE, solid = true, maxY = 5 } }).occupied, true, "a living character's model")
		local ghost = classify({ { model = ALICE, solid = false, maxY = 5 } })
		T.ok(ghost.occupied == true and ghost.blocked == false, "an avatar counts as occupying even with non-collidable parts")
		T.eq(classify({ { model = ALICE, solid = true, maxY = 5 } }).blocked, false)
		T.eq(classify({ { model = BOB, solid = true, maxY = 5 } }).blocked, true, "an unknown or dead character's solid part blocks")
		T.eq(classify({ { model = WALL, solid = true, maxY = 15 } }).blocked, true, "a solid adjacent wall blocks: never globally ignored")
		local decor = classify({ { model = WALL, solid = false, maxY = 15 } })
		T.deepEq(decor, { nearby = false, occupied = false, blocked = false }, "a non-solid decoration or helper part doesn't pin the door")
		T.eq(classify({ { model = CHAIR, solid = true, maxY = 2 } }).blocked, true, "solid furniture")
		T.eq(classify({ { model = nil, solid = true, maxY = 1 } }).blocked, true, "an unowned solid part")
		local sill = r.roomBox.minY
		T.eq(classify({ { model = FLOOR, solid = true, supportingFloor = true, maxY = sill } }).blocked, false, "the supporting floor touching the sill is ignored")
		T.eq(classify({ { model = FLOOR, solid = true, supportingFloor = true, maxY = sill + 0.04 } }).blocked, false, "within contact tolerance")
		T.eq(classify({ { model = FLOOR, solid = true, supportingFloor = true, maxY = sill + 0.5 } }).blocked, true, "a floor piece rising into the sweep (e.g. rotated) blocks")
		T.eq(classify({ { model = WALL, solid = true, supportingFloor = false, maxY = sill } }).blocked, true, "only flagged floor gets the contact exemption")
		local both = classify({ { model = DOOR_MODEL, solid = true, maxY = 9 }, { model = ALICE, solid = false, maxY = 5 }, { model = CHAIR, solid = true, maxY = 2 } })
		T.deepEq(both, { nearby = false, occupied = true, blocked = true })
		T.eq(classify({ { model = WALL, maxY = 15 } }), nil, "a hit without a solid flag is malformed: unknown")
		T.eq(classify({ { model = WALL, solid = "yes", maxY = 15 } }), nil)
	end)

	T.test("failed, truncated or malformed overlap queries make that door unknown", function()
		local r = reg(REC)
		local tooMany = {}
		for i = 1, 65 do tooMany[i] = { model = DOOR_MODEL, maxY = 1 } end
		for name, s in pairs({
			truncated = sensing({}, { { model = DOOR_MODEL, maxY = 1 } }, true),
			tooMany = sensing({}, tooMany, false),
			notTable = sensing({}, "hits"),
			badHit = sensing({}, { "part" }),
			badFloorTop = sensing({}, { { model = FLOOR, solid = true, supportingFloor = true, maxY = 0 / 0 } }),
			raises = sensing({}, function() error("query failed") end),
		}) do
			T.eq(only(s, r), nil, name)
		end
		local noBox = reg(REC); noBox.roomBox = nil
		T.eq(only(sensing({}, {}), noBox), nil, "no room box: unknown")
	end)

	T.test("config validated; several doors scanned independently", function()
		T.eq(pcall(DoorSensing.new, { getCharacters = function() end, queryBox = function() end }), false, "bounds required")
		T.eq(pcall(DoorSensing.new, { bounds = BOUNDS, getCharacters = function() end, queryBox = function() end, nearbyRadius = -1 }), false)
		local a, b = reg(REC), reg({ x = 8, y = 0, z = 0, yaw = 90 })
		b.coreId = "door#2"; b.model = {}
		local s = sensing({ char(0, 12, ALICE) }, function(_, r) if r == b then error("boom") end return {}, false end)
		local out = s:inputs({ a, b })
		T.eq(out["door#1"].nearby, true)
		T.eq(out["door#2"], nil, "one failing door doesn't affect another")
	end)
end
