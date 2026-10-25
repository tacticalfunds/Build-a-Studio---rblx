return function(T, H)
	local Transform = H.load("src/shared/Transform")
	local Config = H.load("src/shared/Config")
	local BOUNDS = { halfX = 20, halfZ = 10, height = 16 }
	local SHELF = { 6.22, 12.14, 1.59 } -- FilledBookshelf bounds from the asset guide

	local function clean(x, y, z, yaw, size)
		return Transform.sanitize({ x = x, y = y, z = z, yaw = yaw }, size or SHELF, BOUNDS, Config)
	end

	T.test("yaw must sit on the 15 degree grid and is normalized to [0, 360)", function()
		T.eq(Transform.normalizeYaw(0, 15), 0)
		T.eq(Transform.normalizeYaw(-15, 15), 345)
		T.eq(Transform.normalizeYaw(375, 15), 15)
		T.eq(Transform.normalizeYaw(720, 15), 0)
		T.eq(Transform.normalizeYaw(-360, 15), 0)
		T.eq(Transform.normalizeYaw(7, 15), nil)
		T.eq(Transform.normalizeYaw(14.9, 15), nil)
	end)

	T.test("rotated footprint swaps extents at 90 degrees and grows at 45", function()
		local hx, hz = Transform.halfExtents(SHELF, 0)
		T.ok(math.abs(hx - 3.11) < 1e-9 and math.abs(hz - 0.795) < 1e-9)
		hx, hz = Transform.halfExtents(SHELF, 90)
		T.ok(math.abs(hx - 0.795) < 1e-9 and math.abs(hz - 3.11) < 1e-9)
		local chair = { 5.0, 4.73, 4.25 }
		hx, hz = Transform.halfExtents(chair, 45)
		T.ok(hx > 2.5 and hz > 2.125, "45 degree footprint of a near-square chair exceeds both axis extents")
	end)

	T.test("full item bounds including yaw decide fit", function()
		T.ok(clean(16.8, 0, 0, 0), "fits along X at yaw 0")
		local t, code = clean(17, 0, 0, 0)
		T.eq(t, nil)
		T.eq(code, "OutOfBounds", "half width 3.11 pokes past halfX 20")
		T.ok(clean(19, 0, 0, 90), "turned 90 degrees it fits at x=19")
		T.eq(select(2, clean(0, 0, 8, 90)), "OutOfBounds", "but then sticks past halfZ 10")
		T.ok(clean(0, 0, 9.2, 0), "z fits at yaw 0")
	end)

	T.test("height and floor are enforced", function()
		T.ok(clean(0, 3.86, 0, 0), "top exactly at the ceiling (with epsilon)")
		T.eq(select(2, clean(0, 4, 0, 0)), "OutOfBounds")
		T.eq(select(2, clean(0, -0.1, 0, 0)), "OutOfBounds")
	end)

	T.test("malformed values are BadTransform, not OutOfBounds", function()
		local bad = {
			{ 0 / 0, 0, 0, 0 }, { math.huge, 0, 0, 0 }, { 0, -math.huge, 0, 0 }, { 0, 0, 0, 0 / 0 },
			{ Config.MaxCoordinate + 1, 0, 0, 0 }, { 0, 0, 0, 1e9 }, { "1", 0, 0, 0 }, { 0, 0, 0, 7 },
		}
		for i, v in ipairs(bad) do
			local t, code = clean(v[1], v[2], v[3], v[4])
			T.eq(t, nil, "case " .. i)
			T.eq(code, "BadTransform", "case " .. i)
		end
		T.eq(select(2, Transform.sanitize(io.stdout, SHELF, BOUNDS, Config)), "BadTransform", "userdata")
		T.eq(select(2, Transform.sanitize({ x = 0, y = 0, z = 0 }, SHELF, BOUNDS, Config)), "BadTransform", "missing yaw")
	end)

	T.test("positions are quantized to the server precision", function()
		local t = clean(1.23456, 0.004, -2.0049, -15)
		T.ok(math.abs(t.x - 1.23) < 1e-9)
		T.ok(math.abs(t.y - 0) < 1e-9)
		T.ok(math.abs(t.z + 2.0) < 1e-9)
		T.eq(t.yaw, 345)
	end)

	-- Review of 8f3f404: ipairs({ x, y, z }) stops at the first nil, so a missing
	-- coordinate skipped validation and the later arithmetic threw.
	T.test("a missing x, y or z is BadTransform, never a throw, even when a later field is bad too", function()
		local cases = {
			{ name = "missing x", raw = { y = 0, z = 0, yaw = 0 } },
			{ name = "missing y", raw = { x = 0, z = 0, yaw = 0 } },
			{ name = "missing z", raw = { x = 0, y = 0, yaw = 0 } },
			{ name = "missing x, NaN z", raw = { y = 0, z = 0 / 0, yaw = 0 } },
			{ name = "missing x, string y", raw = { y = "0", z = 0, yaw = 0 } },
			{ name = "missing y, huge z", raw = { x = 0, z = math.huge, yaw = 0 } },
			{ name = "missing x and y", raw = { z = 0, yaw = 0 } },
			{ name = "all missing", raw = { yaw = 0 } },
		}
		for _, c in ipairs(cases) do
			local ok, result, code = pcall(Transform.sanitize, c.raw, SHELF, BOUNDS, Config)
			T.ok(ok, c.name .. " threw: " .. tostring(result))
			T.eq(result, nil, c.name)
			T.eq(code, "BadTransform", c.name)
		end
		-- Valid transforms are unchanged.
		T.deepEq(clean(1.004, 0, -1.996, 375), { x = 1, y = 0, z = -2, yaw = 15 })
		T.eq(select(2, clean(19, 0, 0, 0)), "OutOfBounds")
	end)
end
