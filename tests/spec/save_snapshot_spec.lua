return function(T, H)
	local SaveSnapshot = H.load("src/server/Adapters/SaveSnapshot")
	local Config = H.load("src/shared/Config")
	local C = SaveSnapshot.Codes

	local function entry(id, itemId, x)
		return { id = id, itemId = itemId or "cozy_plant_01", x = x or 0, y = 0, z = 0, yaw = 0 }
	end

	local function record(items, extra)
		local r = { schema = SaveSnapshot.SCHEMA, version = SaveSnapshot.VERSION, nextId = 10, items = items }
		for k, v in pairs(extra or {}) do
			r[k] = v
		end
		return r
	end

	local function decodeCode(raw, options)
		local result, code = SaveSnapshot.decode(raw, options)
		T.eq(result, nil, "expected decode failure")
		return code
	end

	T.test("encode then decode round-trips, sorted by ID", function()
		local build = {
			nextId = 4,
			items = { entry("i3", "retro_tv_cart_01", 2.5), entry("i1", "cozy_armchair_01", -3) },
			preserved = { entry("i2", "retired_item_01", 1) },
		}
		local r = SaveSnapshot.encode(build)
		T.eq(r.schema, "StudioBuilder.Build")
		T.eq(r.version, 1)
		T.eq(r.items[1].id, "i1")
		T.eq(r.items[2].id, "i2")
		T.eq(r.items[3].id, "i3")
		local decoded = assert(SaveSnapshot.decode(r))
		T.eq(#decoded.items, 3)
		T.eq(decoded.nextId, 4)
		T.eq(decoded.items[3].x, 2.5)
	end)

	T.test("records without our schema (e.g. StudioPresets data) are refused", function()
		T.eq(decodeCode({ version = 1, nextId = 1, items = {} }), C.WrongSchema)
		T.eq(decodeCode(record({}, { schema = "StudioPresets" })), C.WrongSchema)
	end)

	T.test("newer versions are refused, never downgraded", function()
		T.eq(decodeCode(record({}, { version = SaveSnapshot.VERSION + 1 })), C.UnsupportedVersion)
	end)

	T.test("structurally corrupt records fail as a whole", function()
		local cases = {
			["string record"] = "hello",
			["nil record"] = nil,
			["version 0"] = record({}, { version = 0 }),
			["version string"] = record({}, { version = "1" }),
			["version float"] = record({}, { version = 1.5 }),
			["items missing"] = record(nil),
			["items string"] = record("x"),
			["items with hole"] = record({ [1] = entry("i1"), [3] = entry("i3") }),
			["items with hash key"] = record({ entry("i1"), foo = entry("i2") }),
			["duplicate id"] = record({ entry("i1"), entry("i1") }),
			["id i0"] = record({ entry("i0") }),
			["id leading zero"] = record({ entry("i01") }),
			["id without prefix"] = record({ entry("1") }),
			["id fractional"] = record({ entry("i1.5") }),
			["id too long"] = record({ entry("i99999999999") }),
			["id table"] = record({ entry({}) }),
			["itemId path"] = record({ entry("i1", "Workspace.Part") }),
			["itemId uppercase"] = record({ entry("i1", "Cozy_Plant") }),
			["itemId asset url"] = record({ entry("i1", "rbxassetid://1") }),
			["itemId userdata"] = record({ entry("i1", io.stdout) }),
			["x NaN"] = record({ entry("i1", nil, 0 / 0) }),
			["x inf"] = record({ entry("i1", nil, math.huge) }),
			["x beyond limit"] = record({ entry("i1", nil, Config.MaxCoordinate + 1) }),
			["yaw huge"] = record({ { id = "i1", itemId = "cozy_plant_01", x = 0, y = 0, z = 0, yaw = 1e9 } }),
			["missing z"] = record({ { id = "i1", itemId = "cozy_plant_01", x = 0, y = 0, yaw = 0 } }),
			["entry not table"] = record({ "i1" }),
			["nextId 0"] = record({}, { nextId = 0 }),
			["nextId float"] = record({}, { nextId = 2.5 }),
			["nextId string"] = record({}, { nextId = "3" }),
		}
		for name, raw in pairs(cases) do
			local result, code = SaveSnapshot.decode(raw)
			T.eq(result, nil, name)
			T.eq(code, C.Corrupt, name)
		end
	end)

	T.test("item cap is enforced on load", function()
		T.eq(decodeCode(record({ entry("i1"), entry("i2"), entry("i3"), entry("i4") }), { maxItems = 3 }), C.Corrupt)
		T.ok(SaveSnapshot.decode(record({ entry("i1"), entry("i2"), entry("i3") }), { maxItems = 3 }))
	end)

	T.test("nextId is raised above the highest stored ID", function()
		local decoded = assert(SaveSnapshot.decode(record({ entry("i7"), entry("i2") }, { nextId = 3 })))
		T.eq(decoded.nextId, 8)
	end)

	T.test("unplaceable entries are preserved and written back, not dropped", function()
		local raw = record({ entry("i1", "cozy_plant_01"), entry("i2", "retired_item_01"), entry("i3", "cozy_armchair_01") })
		local decoded = assert(SaveSnapshot.decode(raw, {
			classify = function(e)
				if e.itemId == "cozy_armchair_01" then
					error("classifier bug")
				end
				return e.itemId == "cozy_plant_01"
			end,
		}))
		T.eq(#decoded.items, 1)
		T.eq(#decoded.preserved, 2, "unknown item and classifier error are both preserved")
		local again = SaveSnapshot.encode(decoded)
		T.eq(#again.items, 3, "preserved entries survive the next save")
	end)

	T.test("decode does not alias or mutate the raw record", function()
		local raw = record({ entry("i1") })
		local decoded = assert(SaveSnapshot.decode(raw))
		decoded.items[1].x = 50
		T.eq(raw.items[1].x, 0)
	end)

	T.test("older versions run through ordered migrations", function()
		local originalVersion = SaveSnapshot.VERSION
		SaveSnapshot.VERSION = 2
		SaveSnapshot.Migrations[1] = function(v1)
			local items = {}
			for i, e in ipairs(v1.items) do
				items[i] = { id = e.id, itemId = e.itemId, x = e.x, y = e.y, z = e.z, yaw = e.yaw }
			end
			return { schema = v1.schema, version = 2, nextId = v1.nextId, items = items }
		end
		local raw = record({ entry("i1") }, { version = 1 })
		local ok, err = pcall(function()
			local decoded = assert(SaveSnapshot.decode(raw))
			T.eq(#decoded.items, 1)
			T.eq(raw.version, 1, "input record untouched")
			SaveSnapshot.Migrations[1] = function(v1)
				return { schema = v1.schema, version = 7, nextId = 1, items = {} }
			end
			T.eq(decodeCode(raw), C.Corrupt, "bad migration result")
			SaveSnapshot.Migrations[1] = nil
			T.eq(decodeCode(raw), C.UnsupportedVersion, "missing migration step")
		end)
		SaveSnapshot.VERSION = originalVersion
		SaveSnapshot.Migrations[1] = nil
		assert(ok, err)
	end)

	T.test("a full build fits the snapshot size cap; small caps report TooLarge", function()
		local items = {}
		for i = 1, Config.MaxItems do
			items[i] = { id = "i" .. (1000000 + i), itemId = string.rep("a", Config.MaxCatalogIdLength), x = -1023.25, y = 15.5, z = 1023.75, yaw = 345 }
		end
		local r = SaveSnapshot.encode({ nextId = 2000000, items = items })
		T.ok(SaveSnapshot.checkSize(r), "max build within cap")
		local ok, code = SaveSnapshot.checkSize(r, 1000)
		T.eq(ok, false)
		T.eq(code, C.TooLarge)
	end)

	T.test("decode never throws on random garbage", function()
		local seed = 12345
		local function rand(n)
			seed = (seed * 1103515245 + 12345) % 2147483648
			return seed % n
		end
		local function garbage(depth)
			local kind = rand(9)
			if kind == 0 then return nil
			elseif kind == 1 then return rand(2) == 0
			elseif kind == 2 then return rand(1000) - 500
			elseif kind == 3 then return ({ 0 / 0, math.huge, -math.huge, 1e308, 0.5 })[rand(5) + 1]
			elseif kind == 4 then return ({ "i1", "cozy_plant_01", "StudioBuilder.Build", "", string.rep("x", 300) })[rand(5) + 1]
			elseif kind == 5 then return io.stdout
			end
			local t = {}
			if depth < 3 then
				for _ = 1, rand(5) do
					local keys = { "schema", "version", "nextId", "items", "id", "itemId", "x", "y", "z", "yaw", 1, 2, 3 }
					t[keys[rand(#keys) + 1]] = garbage(depth + 1)
				end
			end
			return t
		end
		for i = 1, 3000 do
			local raw = garbage(0)
			if i % 3 == 0 and type(raw) == "table" then
				raw.schema = SaveSnapshot.SCHEMA
				raw.version = 1
			end
			local ok, err = pcall(SaveSnapshot.decode, raw)
			T.ok(ok, "decode threw on case " .. i .. ": " .. tostring(err))
		end
	end)
end
