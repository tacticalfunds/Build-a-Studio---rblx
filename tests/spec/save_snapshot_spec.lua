return function(T, H)
	local SaveSnapshot = H.load("src/server/Adapters/SaveSnapshot")
	local Config = H.load("src/shared/Config")
	local C = SaveSnapshot.Codes

	local function entry(id, itemId, x)
		return { id = id, itemId = itemId or "cozy_plant_01", x = x or 0, y = 0, z = 0, yaw = 0 }
	end

	local function stored(id, catalogId, transform)
		return { Id = id, CatalogId = catalogId or "cozy_plant_01", Transform = transform or { X = 0, Y = 0, Z = 0, Yaw = 0 } }
	end

	local function section(items, extra)
		local s = { Version = SaveSnapshot.VERSION, NextId = 10, Items = items }
		for k, v in pairs(extra or {}) do
			s[k] = v
		end
		return s
	end

	local function decodeCode(raw, options)
		local result, code = SaveSnapshot.decode(raw, options)
		T.eq(result, nil, "expected decode failure")
		return code
	end

	T.test("encode produces the Build section shape, sorted by ID", function()
		local s = SaveSnapshot.encode({
			nextId = 4,
			items = { entry("i3", "retro_tv_cart_01", 2.5), entry("i1", "cozy_armchair_01", -3) },
			preserved = { entry("i2", "retired_item_01", 1) },
		})
		T.eq(s.Version, 1)
		T.eq(s.NextId, 4)
		T.eq(s.Items[1].Id, "i1")
		T.eq(s.Items[1].CatalogId, "cozy_armchair_01")
		T.eq(s.Items[1].Transform.X, -3)
		T.eq(s.Items[2].Id, "i2")
		T.eq(s.Items[3].Id, "i3")
		local allowed = { Id = true, CatalogId = true, Transform = true }
		for key in pairs(s.Items[1]) do
			T.ok(allowed[key], "unexpected stored key " .. key)
		end
	end)

	T.test("decode(encode(x)) round-trips", function()
		local decoded = assert(SaveSnapshot.decode(SaveSnapshot.encode({ nextId = 4, items = { entry("i1", nil, 2.5), entry("i3") } })))
		T.eq(#decoded.items, 2)
		T.eq(decoded.nextId, 4)
		T.deepEq(decoded.items[1], entry("i1", nil, 2.5))
	end)

	T.test("attaching to a preset leaves Version and legacy sections untouched", function()
		local settings, fixtures, items = { SceneSet = "Lounge" }, { L1 = {} }, { P1 = { StudioMoveX = 1 } }
		local preset = { Version = 1, Settings = settings, Fixtures = fixtures, Items = items }
		local withBuild = SaveSnapshot.attachToPreset(preset, SaveSnapshot.encode({ nextId = 2, items = { entry("i1") } }))
		T.eq(withBuild.Version, 1)
		T.eq(withBuild.Settings, settings)
		T.eq(withBuild.Fixtures, fixtures)
		T.eq(withBuild.Items, items)
		T.eq(preset.Build, nil, "input preset not mutated")
		local decoded = assert(SaveSnapshot.readFromPreset(withBuild))
		T.eq(#decoded.items, 1)
	end)

	T.test("legacy presets without a Build section report NoBuild", function()
		local result, code = SaveSnapshot.readFromPreset({ Version = 1, Settings = {}, Fixtures = {}, Items = {} })
		T.eq(result, nil)
		T.eq(code, C.NoBuild)
		result, code = SaveSnapshot.readFromPreset("not a preset")
		T.eq(result, nil)
		T.eq(code, C.Corrupt)
	end)

	T.test("newer section versions are refused, never downgraded", function()
		T.eq(decodeCode(section({}, { Version = SaveSnapshot.VERSION + 1 })), C.UnsupportedVersion)
	end)

	T.test("structurally corrupt sections fail as a whole", function()
		local cases = {
			["string section"] = "hello",
			["nil section"] = nil,
			["version 0"] = section({}, { Version = 0 }),
			["version string"] = section({}, { Version = "1" }),
			["version float"] = section({}, { Version = 1.5 }),
			["lowercase keys"] = { version = 1, nextId = 1, items = {} },
			["items missing"] = section(nil),
			["items string"] = section("x"),
			["items with hole"] = section({ [1] = stored("i1"), [3] = stored("i3") }),
			["items with hash key"] = section({ stored("i1"), foo = stored("i2") }),
			["duplicate id"] = section({ stored("i1"), stored("i1") }),
			["id i0"] = section({ stored("i0") }),
			["id leading zero"] = section({ stored("i01") }),
			["id without prefix"] = section({ stored("1") }),
			["id fractional"] = section({ stored("i1.5") }),
			["id too long"] = section({ stored("i99999999999") }),
			["id table"] = section({ stored({}) }),
			["catalog path"] = section({ stored("i1", "Workspace.Part") }),
			["catalog uppercase"] = section({ stored("i1", "Cozy_Plant") }),
			["catalog asset url"] = section({ stored("i1", "rbxassetid://1") }),
			["catalog userdata"] = section({ stored("i1", io.stdout) }),
			["transform missing"] = section({ { Id = "i1", CatalogId = "cozy_plant_01" } }),
			["transform userdata (CFrame stand-in)"] = section({ stored("i1", nil, io.stdout) }),
			["X NaN"] = section({ stored("i1", nil, { X = 0 / 0, Y = 0, Z = 0, Yaw = 0 }) }),
			["X inf"] = section({ stored("i1", nil, { X = math.huge, Y = 0, Z = 0, Yaw = 0 }) }),
			["X beyond limit"] = section({ stored("i1", nil, { X = Config.MaxCoordinate + 1, Y = 0, Z = 0, Yaw = 0 }) }),
			["Yaw huge"] = section({ stored("i1", nil, { X = 0, Y = 0, Z = 0, Yaw = 1e9 }) }),
			["Z missing"] = section({ stored("i1", nil, { X = 0, Y = 0, Yaw = 0 }) }),
			["Y string"] = section({ stored("i1", nil, { X = 0, Y = "0", Z = 0, Yaw = 0 }) }),
			["entry not table"] = section({ "i1" }),
			["NextId 0"] = section({}, { NextId = 0 }),
			["NextId float"] = section({}, { NextId = 2.5 }),
			["NextId string"] = section({}, { NextId = "3" }),
		}
		for name, raw in pairs(cases) do
			local result, code = SaveSnapshot.decode(raw)
			T.eq(result, nil, name)
			T.eq(code, C.Corrupt, name)
		end
	end)

	T.test("item cap is enforced on load", function()
		T.eq(decodeCode(section({ stored("i1"), stored("i2"), stored("i3"), stored("i4") }), { maxItems = 3 }), C.Corrupt)
		T.ok(SaveSnapshot.decode(section({ stored("i1"), stored("i2"), stored("i3") }), { maxItems = 3 }))
	end)

	T.test("NextId is raised above the highest stored ID", function()
		local decoded = assert(SaveSnapshot.decode(section({ stored("i7"), stored("i2") }, { NextId = 3 })))
		T.eq(decoded.nextId, 8)
	end)

	T.test("unknown extra fields are not carried into the build", function()
		local s = section({ { Id = "i1", CatalogId = "cozy_plant_01", Transform = { X = 1, Y = 0, Z = 0, Yaw = 0, Scale = 50 }, Color = "red" } })
		local decoded = assert(SaveSnapshot.decode(s))
		T.deepEq(decoded.items[1], { id = "i1", itemId = "cozy_plant_01", x = 1, y = 0, z = 0, yaw = 0 })
	end)

	T.test("unplaceable entries are preserved and written back, not dropped", function()
		local raw = section({ stored("i1", "cozy_plant_01"), stored("i2", "retired_item_01"), stored("i3", "cozy_armchair_01") })
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
		T.eq(#SaveSnapshot.encode(decoded).Items, 3, "preserved entries survive the next save")
	end)

	T.test("decode does not alias or mutate the raw section", function()
		local raw = section({ stored("i1") })
		local decoded = assert(SaveSnapshot.decode(raw))
		decoded.items[1].x = 50
		T.eq(raw.Items[1].Transform.X, 0)
	end)

	T.test("older versions run through ordered migrations", function()
		local originalVersion = SaveSnapshot.VERSION
		SaveSnapshot.VERSION = 2
		SaveSnapshot.Migrations[1] = function(v1)
			return { Version = 2, NextId = v1.NextId, Items = v1.Items }
		end
		local raw = section({ stored("i1") }, { Version = 1 })
		local ok, err = pcall(function()
			local decoded = assert(SaveSnapshot.decode(raw))
			T.eq(#decoded.items, 1)
			T.eq(raw.Version, 1, "input section untouched")
			SaveSnapshot.Migrations[1] = function()
				return { Version = 7, NextId = 1, Items = {} }
			end
			T.eq(decodeCode(raw), C.Corrupt, "bad migration result")
			SaveSnapshot.Migrations[1] = nil
			T.eq(decodeCode(raw), C.UnsupportedVersion, "missing migration step")
		end)
		SaveSnapshot.VERSION = originalVersion
		SaveSnapshot.Migrations[1] = nil
		assert(ok, err)
	end)

	T.test("a full build fits the section cap and the 250000-byte preset cap", function()
		local items = {}
		for i = 1, Config.MaxItems do
			items[i] = { id = "i" .. (1000000 + i), itemId = string.rep("a", Config.MaxCatalogIdLength), x = -1023.25, y = 15.5, z = 1023.75, yaw = 345 }
		end
		local s = SaveSnapshot.encode({ nextId = 2000000, items = items })
		T.ok(SaveSnapshot.checkSize(s), "max build within section cap")
		T.ok(Config.MaxBuildSectionBytes < 250000, "section cap below the preset cap")
		local ok, code = SaveSnapshot.checkSize(s, 1000)
		T.eq(ok, false)
		T.eq(code, C.TooLarge)
	end)

	T.test("decode never throws on random garbage", function()
		local seed = 12345
		local function rand(n)
			seed = (seed * 1103515245 + 12345) % 2147483648
			return seed % n
		end
		local keys = { "Version", "NextId", "Items", "Id", "CatalogId", "Transform", "X", "Y", "Z", "Yaw", 1, 2, 3 }
		local function garbage(depth)
			local kind = rand(9)
			if kind == 0 then return nil
			elseif kind == 1 then return rand(2) == 0
			elseif kind == 2 then return rand(1000) - 500
			elseif kind == 3 then return ({ 0 / 0, math.huge, -math.huge, 1e308, 0.5 })[rand(5) + 1]
			elseif kind == 4 then return ({ "i1", "cozy_plant_01", "Build", "", string.rep("x", 300) })[rand(5) + 1]
			elseif kind == 5 then return io.stdout
			end
			local t = {}
			if depth < 3 then
				for _ = 1, rand(5) do
					t[keys[rand(#keys) + 1]] = garbage(depth + 1)
				end
			end
			return t
		end
		for i = 1, 3000 do
			local raw = garbage(0)
			if i % 3 == 0 and type(raw) == "table" then
				raw.Version = 1
			end
			local ok, err = pcall(SaveSnapshot.decode, raw)
			T.ok(ok, "decode threw on case " .. i .. ": " .. tostring(err))
			ok, err = pcall(SaveSnapshot.readFromPreset, { Version = 1, Build = raw })
			T.ok(ok, "readFromPreset threw on case " .. i .. ": " .. tostring(err))
		end
	end)
end
