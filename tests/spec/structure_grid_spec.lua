-- Task 10 foundation: pure StructureGrid maths (D1 cell-centre origin, D2
-- caller bounds with no overhang, D3 levels). Not wired into any runtime.
return function(T, H)
	local G = H.load("src/shared/StructureGrid")
	local Codes = G.Codes

	local WALL = { 16, 15, 1 }
	local FLOOR = { 16, 1, 16 }
	local LIVE = { halfX = 24, halfZ = 24, height = 24 } -- current 48 x 24 x 48 marker
	local FUTURE = { halfX = 24.5, halfZ = 24.5, height = 24 } -- proposed 49 x 24 x 49

	local function t(x, y, z, yaw) return { x = x, y = y, z = z, yaw = yaw } end

	T.test("snapping: cell centres at 16i, edges at 8+16i, negative cells, ties toward +infinity", function()
		T.eq(G.snapCentre(0), 0)
		T.eq(G.snapCentre(7.9), 0)
		T.eq(G.snapCentre(8.1), 16)
		T.eq(G.snapCentre(-8.1), -16)
		T.eq(G.snapCentre(-23.9), -16)
		T.eq(G.snapCentre(-40), -32)
		T.eq(G.snapCentre(8), 16, "tie at an edge line goes up")
		T.eq(G.snapCentre(-8), 0, "negative tie also goes up")
		T.eq(G.snapEdge(0), 8, "tie at a cell centre goes up")
		T.eq(G.snapEdge(-16), -8, "negative tie also goes up")
		T.eq(G.snapEdge(3), 8)
		T.eq(G.snapEdge(-3), -8)
		T.eq(G.snapEdge(-20), -24)
		T.eq(G.snapEdge(30), 24)
	end)

	T.test("floors and ceilings: cell centres, D3 levels, cardinal yaw; the ceiling top is 16", function()
		local f = G.validate("floor", t(-16, 0, 16, 270), FLOOR, LIVE)
		T.deepEq(f, t(-16, 0, 16, 270))
		local c = G.validate("ceiling", t(0, 15, -16, 90), FLOOR, LIVE)
		T.deepEq(c, t(0, 15, -16, 90))
		T.eq(c.y + FLOOR[2], 16, "ceiling top")
		T.eq(select(2, G.validate("ceiling", t(0, 15, 0, 0), FLOOR, { halfX = 24, halfZ = 24, height = 15.9 })), Codes.OutOfBounds, "a ceiling needs height >= 16")
		T.ok(G.validate("ceiling", t(0, 15, 0, 0), FLOOR, { halfX = 24, halfZ = 24, height = 16 }) ~= nil, "exactly 16 fits")
		T.eq(select(2, G.validate("floor", t(8, 0, 0, 0), FLOOR, LIVE)), Codes.OffGrid, "a floor on an edge line")
		T.eq(select(2, G.validate("floor", t(0, 1, 0, 0), FLOOR, LIVE)), Codes.BadLevel)
		T.eq(select(2, G.validate("ceiling", t(0, 0, 0, 0), FLOOR, LIVE)), Codes.BadLevel)
		-- 3 x 3 cells fit the live 48-stud marker (centres -16, 0, 16); a fourth ring does not.
		for _, x in ipairs({ -16, 0, 16 }) do
			for _, z in ipairs({ -16, 0, 16 }) do
				T.ok(G.validate("floor", t(x, 0, z, 0), FLOOR, LIVE) ~= nil, x .. "," .. z)
			end
		end
		T.eq(select(2, G.validate("floor", t(32, 0, 0, 0), FLOOR, LIVE)), Codes.OutOfBounds)
	end)

	T.test("edge pieces: along X at yaw 0/180, along Z at 90/270, for wall, window wall and doorway", function()
		for _, kind in ipairs({ "wall", "window_wall", "doorway" }) do
			T.deepEq(G.validate(kind, t(0, 0, 8, 0), WALL, LIVE), t(0, 0, 8, 0), kind .. " along X")
			T.deepEq(G.validate(kind, t(-16, 0, -8, 180), WALL, LIVE), t(-16, 0, -8, 180), kind .. " along X flipped")
			T.deepEq(G.validate(kind, t(8, 0, 0, 90), WALL, LIVE), t(8, 0, 0, 90), kind .. " along Z")
			T.deepEq(G.validate(kind, t(-8, 0, 16, 270), WALL, LIVE), t(-8, 0, 16, 270), kind .. " along Z flipped")
			-- Wrong axis for the yaw: an X-edge position with a Z yaw is off-grid.
			T.eq(select(2, G.validate(kind, t(0, 0, 8, 90), WALL, LIVE)), Codes.OffGrid, kind)
			T.eq(select(2, G.validate(kind, t(8, 0, 0, 0), WALL, LIVE)), Codes.OffGrid, kind)
			T.eq(select(2, G.validate(kind, t(8, 0, 8, 0), WALL, LIVE)), Codes.OffGrid, kind .. " centred on a corner")
			T.eq(select(2, G.validate(kind, t(0, 0, 0, 0), WALL, LIVE)), Codes.OffGrid, kind .. " at a cell centre")
			T.eq(select(2, G.validate(kind, t(0, 1, 8, 0), WALL, LIVE)), Codes.BadLevel, kind)
		end
	end)

	T.test("full outer-wall footprint: +/-24 needs half 24.5 (future marker); the live 48 marker refuses with no overhang", function()
		for _, w in ipairs({ t(0, 0, 24, 0), t(-16, 0, -24, 180), t(24, 0, 16, 90), t(-24, 0, 0, 270) }) do
			T.ok(G.validate("wall", w, WALL, FUTURE) ~= nil, "fits 24.5: " .. w.x .. "," .. w.z)
			T.eq(select(2, G.validate("wall", w, WALL, LIVE)), Codes.OutOfBounds, "live 24 refuses: " .. w.x .. "," .. w.z)
		end
		-- Along an outer edge, only the three cell centres fit: x = +/-32 pokes out lengthwise.
		T.eq(select(2, G.validate("wall", t(32, 0, 24, 0), WALL, FUTURE)), Codes.OutOfBounds)
		-- Wall height 15 at level 0 needs height >= 15.
		T.eq(select(2, G.validate("wall", t(0, 0, 8, 0), WALL, { halfX = 24, halfZ = 24, height = 14.5 })), Codes.OutOfBounds)
		-- Inner walls fit the live marker.
		T.ok(G.validate("wall", t(0, 0, 8, 0), WALL, LIVE) ~= nil)
	end)

	T.test("tolerance: within 0.01 snaps exactly onto the grid; beyond is OffGrid (not OutOfBounds)", function()
		T.deepEq(G.validate("wall", t(0.004, -0.006, 7.995, 360), WALL, LIVE), t(0, 0, 8, 0))
		T.deepEq(G.validate("floor", t(-15.991, 0.01, 16.009, -90), FLOOR, LIVE), t(-16, 0, 16, 270))
		T.eq(select(2, G.validate("wall", t(0, 0, 8.02, 0), WALL, LIVE)), Codes.OffGrid)
		T.eq(select(2, G.validate("floor", t(0.5, 0, 0, 0), FLOOR, LIVE)), Codes.OffGrid)
		T.eq(select(2, G.validate("floor", t(0, 0.02, 0, 0), FLOOR, LIVE)), Codes.BadLevel)
	end)

	T.test("yaw: only cardinal values; 15-degree steps and non-finite yaw are refused distinctly", function()
		T.eq(select(2, G.validate("floor", t(0, 0, 0, 45), FLOOR, LIVE)), Codes.BadYaw)
		T.eq(select(2, G.validate("wall", t(0, 0, 8, 15), WALL, LIVE)), Codes.BadYaw)
		T.eq(G.validate("wall", t(0, 0, 8, 540), WALL, LIVE).yaw, 180)
		T.eq(G.validate("wall", t(8, 0, 0, -270), WALL, LIVE).yaw, 90)
		T.eq(select(2, G.validate("wall", t(0, 0, 8, 0 / 0), WALL, LIVE)), Codes.BadTransform)
		T.eq(select(2, G.validate("wall", t(0, 0, 8, math.huge), WALL, LIVE)), Codes.BadTransform)
	end)

	T.test("bad input: unknown or deferred kinds, malformed transforms, sizes and bounds", function()
		for _, kind in ipairs({ "corner", "window", "decor", "", 5 }) do
			T.eq(select(2, G.validate(kind, t(0, 0, 0, 0), FLOOR, LIVE)), Codes.BadKind, tostring(kind))
		end
		T.eq(select(2, G.validate(nil, t(0, 0, 0, 0), FLOOR, LIVE)), Codes.BadKind)
		for _, bad in ipairs({ "x", t(0 / 0, 0, 0, 0), t(0, math.huge, 0, 0), t(0, 0, -math.huge, 0), t(2000, 0, 0, 0), { x = 0, y = 0, z = 0 }, t("0", 0, 0, 0) }) do
			T.eq(select(2, G.validate("floor", bad, FLOOR, LIVE)), Codes.BadTransform)
		end
		T.eq(select(2, G.validate("floor", t(0, 0, 0, 0), { 16, 1 }, LIVE)), Codes.BadSize)
		T.eq(select(2, G.validate("floor", t(0, 0, 0, 0), { 16, 0, 16 }, LIVE)), Codes.BadSize)
		T.eq(select(2, G.validate("floor", t(0, 0, 0, 0), FLOOR, { halfX = 24, halfZ = 0 / 0, height = 24 })), Codes.BadSize)
		T.eq(select(2, G.validate("floor", t(0, 0, 0, 0), FLOOR, nil)), Codes.BadSize)
		-- validate never returns the caller's table.
		local raw = t(0, 0, 0, 0)
		T.ok(G.validate("floor", raw, FLOOR, LIVE) ~= raw)
	end)

	T.test("project: floor hits snap to cells or the nearest edge; ties pick the X-axis edge; preferred facing kept", function()
		T.deepEq(G.project("floor", { x = 9, z = -7 }), t(16, 0, 0, 0))
		T.deepEq(G.project("ceiling", { x = -9, z = 30 }, 90), t(-16, 15, 32, 90))
		T.deepEq(G.project("wall", { x = 3, z = 7 }), t(0, 0, 8, 0), "near the z = 8 edge")
		T.deepEq(G.project("wall", { x = 7, z = 3 }), t(8, 0, 0, 90), "near the x = 8 edge")
		T.deepEq(G.project("wall", { x = -7, z = -9 }), t(0, 0, -8, 0))
		T.deepEq(G.project("doorway", { x = 4, z = 4 }), t(0, 0, 8, 0), "equidistant: X-axis edge")
		T.deepEq(G.project("wall", { x = 3, z = 7 }, 180), t(0, 0, 8, 180), "flipped facing kept")
		T.deepEq(G.project("wall", { x = 7, z = 3 }, 180), t(8, 0, 0, 270), "flipped facing kept on the Z axis")
		T.deepEq(G.project("window_wall", { x = 7, z = 3 }, 0), t(8, 0, 0, 90))
		T.eq(select(2, G.project("corner", { x = 0, z = 0 })), Codes.BadKind)
		T.eq(select(2, G.project("wall", { x = 0 / 0, z = 0 })), Codes.BadTransform)
		T.eq(select(2, G.project("wall", { x = 0, z = 0 }, 45)), Codes.BadYaw)
		-- Every projection validates (inside the live marker).
		for x = -20, 20, 2.5 do
			for z = -20, 20, 2.5 do
				for _, kind in ipairs({ "floor", "wall" }) do
					local p = G.project(kind, { x = x, z = z })
					local size = kind == "floor" and FLOOR or WALL
					local clean, code = G.validate(kind, p, size, FUTURE)
					T.ok(clean ~= nil or code == Codes.OutOfBounds, kind .. " projection on grid at " .. x .. "," .. z .. ": " .. tostring(code))
				end
			end
		end
	end)

	T.test("rotate proposal: an edge piece hinges at an end point and stays on-grid (never in place at the old centre)", function()
		-- Along X at z = 8, x = 0 (ends at (-8, 8) and (8, 8)).
		T.deepEq(G.rotate("wall", t(0, 0, 8, 0), 1, WALL, FUTURE), t(8, 0, 16, 90), "+1: larger end, toward +z")
		T.deepEq(G.rotate("wall", t(0, 0, 8, 0), -1, WALL, FUTURE), t(-8, 0, 0, 270), "-1: smaller end, toward -z")
		-- Along Z at x = 8, z = 0 (ends at (8, -8) and (8, 8)).
		T.deepEq(G.rotate("wall", t(8, 0, 0, 90), 1, WALL, FUTURE), t(16, 0, 8, 180))
		-- Results always validate, and four turns return to an on-grid piece.
		local cur = t(-16, 0, -8, 180)
		for _ = 1, 4 do
			cur = G.rotate("doorway", cur, 1, WALL, FUTURE)
			T.ok(cur ~= nil)
			T.deepEq(G.validate("doorway", cur, WALL, FUTURE), cur)
		end
		-- At the boundary the first candidate falls outside; the next one in the fixed order is used.
		T.deepEq(G.rotate("wall", t(16, 0, 24, 0), 1, WALL, FUTURE), t(24, 0, 16, 90), "+z is outside, so -z")
		-- Cell pieces turn in place.
		T.deepEq(G.rotate("floor", t(16, 0, -16, 0), -1, FLOOR, LIVE), t(16, 0, -16, 270))
		-- Bad input and impossible turns.
		T.eq(select(2, G.rotate("wall", t(0, 0, 8, 0), 2, WALL, FUTURE)), Codes.BadTransform)
		T.eq(select(2, G.rotate("wall", t(0, 0, 0, 0), 1, WALL, FUTURE)), Codes.OffGrid, "the current transform must be valid first")
		local tight = { halfX = 8, halfZ = 8.5, height = 24 } -- room for one X-axis wall at z = 8 only
		T.eq(select(2, G.rotate("wall", t(0, 0, 8, 0), 1, WALL, tight)), Codes.OutOfBounds, "every candidate out of bounds")
	end)
end
