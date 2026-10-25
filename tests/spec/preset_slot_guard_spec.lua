-- Task 5: StudioPresets slot overwrite rules, and the actual patched
-- integration/StudioPresets.luau executed against a fake DataStore whose
-- UpdateAsync replays the transform after concurrent writes (retries).
return function(T, H)
	local Guard = H.load("src/server/Core/PresetSlotGuard")

	local function deepCopy(v)
		if type(v) ~= "table" then
			return v
		end
		local out = {}
		for k, x in pairs(v) do
			out[k] = deepCopy(x)
		end
		return out
	end

	local function build(items, version)
		return { Version = version or 1, NextId = (#items) + 1, Items = items }
	end

	local function item(id)
		return { Id = id, CatalogId = "cozy_plant_01", Transform = { X = 0, Y = 0, Z = 0, Yaw = 0 } }
	end

	local function entry(buildSection)
		return { Name = "Show", Version = 1, Data = { Version = 1, Settings = { SceneSet = "Custom" }, Fixtures = {}, Items = {}, Build = buildSection } }
	end

	local function profileWith(slotEntries)
		local slots = {}
		for slot, e in pairs(slotEntries) do
			slots[tostring(slot)] = e
		end
		return { Slots = slots }
	end

	-- Guard rules ------------------------------------------------------------------

	T.test("new, empty, legacy and same-version slots may be replaced", function()
		T.ok(Guard.checkOverwrite(nil, 1, entry(build({}))))
		T.ok(Guard.checkOverwrite({}, 1, entry(build({}))))
		T.ok(Guard.checkOverwrite(profileWith({ [2] = entry(build({ item("i1") })) }), 1, entry(build({}))), "other slot irrelevant")
		T.ok(Guard.checkOverwrite(profileWith({ [1] = entry(nil) }), 1, entry(build({}))), "legacy slot")
		T.ok(Guard.checkOverwrite(profileWith({ [1] = entry(build({ item("i1") })) }), 1, entry(build({}))), "same version, explicit save of an empty build")
	end)

	T.test("corrupt profiles are never overwritten", function()
		for _, bad in ipairs({ "junk", 42, true, { Slots = "x" }, { Slots = 5 } }) do
			local ok, reason = Guard.checkOverwrite(bad, 1, entry(build({})))
			T.eq(ok, false)
			T.eq(reason, "CorruptProfile")
		end
	end)

	T.test("newer or unreadable Build sections are never overwritten", function()
		local ok, reason = Guard.checkOverwrite(profileWith({ [1] = entry(build({}, 2)) }), 1, entry(build({})))
		T.eq(ok, false)
		T.eq(reason, "NewerBuild")
		for _, bad in ipairs({ { Version = 1, NextId = 1, Items = "x" }, { NextId = 1, Items = {} }, "build", build({ item("i1"), item("i1") }) }) do
			local ok2, reason2 = Guard.checkOverwrite(profileWith({ [1] = entry(bad) }), 1, entry(build({})))
			T.eq(ok2, false)
			T.eq(reason2, "InvalidBuild")
		end
	end)

	T.test("a snapshot without Build may not drop a slot's non-empty Build", function()
		local ok, reason = Guard.checkOverwrite(profileWith({ [1] = entry(build({ item("i1") })) }), 1, entry(nil))
		T.eq(ok, false)
		T.eq(reason, "BuildWouldBeLost")
		T.ok(Guard.checkOverwrite(profileWith({ [1] = entry(build({})) }), 1, entry(nil)), "an empty Build loses nothing")
	end)

	T.test("transform never mutates old or the entry; refusal reflects the last call", function()
		local new = entry(build({ item("i1") }))
		local transform, refusal = Guard.transform(3, new)
		local old = profileWith({ [1] = entry(nil), [2] = entry(build({})) })
		local before = deepCopy(old)
		local result = transform(old)
		T.deepEq(old, before, "old untouched")
		T.eq(result.Slots["3"], new)
		T.eq(result.Slots["1"], old.Slots["1"], "other slots kept")
		T.eq(refusal(), nil)
		T.eq(transform(profileWith({ [3] = entry(build({}, 9)) })), nil)
		T.eq(refusal(), "NewerBuild")
		T.ok(transform(nil) ~= nil, "a retry with a fresh value succeeds")
		T.eq(refusal(), nil, "refusal reset on every call")
	end)

	-- The patched StudioPresets, executed --------------------------------------------

	local function jsonLength(v)
		local t = type(v)
		if t == "string" then
			return #v + 2
		elseif t == "number" or t == "boolean" then
			return #tostring(v)
		elseif t == "table" then
			local n = 2
			for k, x in pairs(v) do
				n = n + #tostring(k) + 4 + jsonLength(x)
			end
			return n
		end
		return 4
	end

	local function services()
		local store = { data = {}, interleave = nil, transformCalls = 0 }
		function store:GetAsync(key)
			return deepCopy(self.data[key])
		end
		function store:UpdateAsync(key, fn)
			self.transformCalls = 0
			local writes = self.interleave or {}
			self.interleave = nil
			for _, other in ipairs(writes) do
				self.transformCalls = self.transformCalls + 1
				fn(deepCopy(self.data[key])) -- discarded: another server wrote first
				self.data[key] = deepCopy(other)
			end
			self.transformCalls = self.transformCalls + 1
			local result = fn(deepCopy(self.data[key]))
			if result ~= nil then
				self.data[key] = deepCopy(result)
			end
			return result
		end
		local fakes = {
			DataStoreService = { GetDataStore = function(_, name) store.name = name return store end },
			HttpService = {
				JSONEncode = function(_, v) return string.rep("x", jsonLength(v)) end,
				GenerateGUID = function() return "0123456789abcdef0123456789abcdef" end,
			},
			TextService = {
				FilterStringAsync = function(_, text)
					return { GetNonChatStringForBroadcastAsync = function() return text end }
				end,
			},
		}
		return fakes, store
	end

	local function presets()
		local fakes, store = services()
		local M = H.loadIntegration("integration/StudioPresets.luau", fakes)
		return M, store
	end

	local function snapshot(buildSection)
		return entry(buildSection).Data
	end

	T.test("patched Save writes the additive Build section; Load returns it; store name unchanged", function()
		local M, store = presets()
		T.eq(M.Save(1001, 2, "Night show", snapshot(build({ item("i1") }))), "Night show")
		T.eq(store.name, "PodcastStudioPresets_v1")
		local loaded = M.Load(1001, 2)
		T.eq(loaded.Version, 1)
		T.eq(loaded.Data.Version, 1)
		T.eq(loaded.Data.Build.Items[1].Id, "i1")
		T.eq(M.List(1001)[2].Name, "Night show")
	end)

	T.test("patched Save over a newer Build fails visibly and writes nothing", function()
		local M, store = presets()
		store.data["user:1001"] = profileWith({ [1] = { Name = "Future", Version = 1, Data = snapshot(build({}, 2)) } })
		local before = deepCopy(store.data)
		local ok, err = pcall(M.Save, 1001, 1, "Overwrite", snapshot(build({})))
		T.eq(ok, false)
		T.ok(tostring(err):find("newer version"), tostring(err))
		T.ok(tostring(err):find(":%d+: "), "position prefix for the Director's message extraction")
		T.deepEq(store.data, before, "store unchanged")
	end)

	T.test("patched Save refuses a corrupt profile instead of replacing all slots", function()
		local M, store = presets()
		store.data["user:1001"] = "corrupted"
		local ok, err = pcall(M.Save, 1001, 1, "Show", snapshot(build({})))
		T.eq(ok, false)
		T.ok(tostring(err):find("couldn't be read"))
		T.eq(store.data["user:1001"], "corrupted")
	end)

	T.test("patched Save keeps legacy behaviour: legacy slots overwritten, other slots preserved", function()
		local M, store = presets()
		store.data["user:1001"] = profileWith({ [1] = entry(nil), [4] = entry(build({ item("i9") })) })
		M.Save(1001, 1, "Fresh", snapshot(build({ item("i1") })))
		local profile = store.data["user:1001"]
		T.eq(profile.Slots["1"].Name, "Fresh")
		T.eq(profile.Slots["4"].Data.Build.Items[1].Id, "i9", "slot 4 untouched")
	end)

	T.test("UpdateAsync retry: a concurrent newer write is detected on the retry", function()
		local M, store = presets()
		store.data["user:1001"] = profileWith({ [1] = entry(nil) })
		-- After the first attempt, another server saves a newer Build into slot 1.
		store.interleave = { profileWith({ [1] = entry(build({}, 3)) }) }
		local ok, err = pcall(M.Save, 1001, 1, "Mine", snapshot(build({})))
		T.eq(store.transformCalls, 2, "transform ran twice")
		T.eq(ok, false, "refusal from the last attempt wins")
		T.ok(tostring(err):find("newer version"))
		T.eq(store.data["user:1001"].Slots["1"].Data.Build.Version, 3, "the other server's newer write survives")
	end)

	T.test("UpdateAsync retry: a refusal on the first attempt doesn't stick when the retry is fine", function()
		local M, store = presets()
		store.data["user:1001"] = profileWith({ [1] = entry(build({}, 3)) })
		store.interleave = { profileWith({ [1] = entry(nil) }) } -- another server replaced it with a legacy entry
		local ok = pcall(M.Save, 1001, 1, "Mine", snapshot(build({ item("i1") })))
		T.eq(store.transformCalls, 2)
		T.eq(ok, true)
		T.eq(store.data["user:1001"].Slots["1"].Name, "Mine")
	end)

	T.test("patched Save still enforces the 250000-byte preset cap", function()
		local M = presets()
		local data = snapshot(build({}))
		data.Settings.Huge = string.rep("y", 260000)
		local ok, err = pcall(M.Save, 1001, 1, "Big", data)
		T.eq(ok, false)
		T.ok(tostring(err):find("too large"))
	end)
end
