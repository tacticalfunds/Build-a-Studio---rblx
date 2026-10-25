-- PlacedItemsWorld with fake Instances: placed models are ModelStreamingMode
-- Persistent before they are parented (spawn, build-load replace, reconcile),
-- and the two-phase effects keep the folder consistent.
return function(T, H)
	local PlacedItemsWorld = H.load("src/server/Runtime/PlacedItemsWorld")

	-- Fake CFrame: opaque values that multiply into a description string.
	local function cf(desc)
		return setmetatable({ desc = desc }, {
			__mul = function(a, b) return cf(a.desc .. "*" .. b.desc) end,
		})
	end
	local fakeCFrame = {
		new = function(x, y, z) return cf(string.format("T(%g,%g,%g)", x, y, z)) end,
		Angles = function(_, y) return cf(string.format("R(%g)", y)) end,
	}
	local fakeEnum = { ModelStreamingMode = { Persistent = "Persistent", Default = "Default" } }

	-- Fake model: records every property write in order.
	local function fakeModel(folderLog)
		local props, attrs, writes = { Parent = nil }, {}, {}
		local model = {}
		local methods = {
			GetDescendants = function() return {} end,
			SetAttribute = function(_, k, v) attrs[k] = v end,
			GetAttribute = function(_, k) return attrs[k] end,
			PivotTo = function(_, c) props.pivot = c.desc writes[#writes + 1] = "PivotTo" end,
			GetPivot = function() return cf(props.pivot or "none") end,
			Destroy = function() props.destroyed = true props.Parent = nil end,
		}
		setmetatable(model, {
			__index = function(_, k)
				if methods[k] then return methods[k] end
				if k == "writes" then return writes end
				return props[k]
			end,
			__newindex = function(_, k, v)
				writes[#writes + 1] = k .. "=" .. tostring(v)
				props[k] = v
				if k == "Parent" and folderLog then
					folderLog[#folderLog + 1] = v
				end
			end,
		})
		return model
	end

	local function setup()
		H.setGlobal("CFrame", fakeCFrame)
		H.setGlobal("Enum", fakeEnum)
		local env = { built = {} }
		env.folder = { Name = "StudioBuilderPlacedItems", children = {} }
		function env.folder:GetChildren()
			local out = {}
			for _, m in ipairs(env.built) do
				if m.Parent == env.folder and not m.destroyed then out[#out + 1] = m end
			end
			return out
		end
		function env.folder:SetAttribute() end
		local template = { Clone = function()
			local m = fakeModel()
			env.built[#env.built + 1] = m
			return m
		end }
		env.world = PlacedItemsWorld.new(env.folder, cf("O"), function() return template end)
		return env
	end

	local function teardown()
		H.setGlobal("CFrame", nil)
		H.setGlobal("Enum", nil)
	end

	local function record(x)
		return { itemId = "cozy_plant_01", placedByUserId = 1001, x = x or 0, y = 0, z = 0, yaw = 0 }
	end

	local function persistentBeforeParent(model)
		local streaming, parent = nil, nil
		for i, w in ipairs(model.writes) do
			if w == "ModelStreamingMode=Persistent" and not streaming then streaming = i end
			if w:find("^Parent=") and not parent and w ~= "Parent=nil" then parent = i end
		end
		return streaming ~= nil and parent ~= nil and streaming < parent
	end

	T.test("spawned models are Persistent before they are parented", function()
		local env = setup()
		local ok, err = pcall(function()
			local token = env.world:apply({ kind = "spawn", id = "i1", record = record(2) })
			T.eq(token.model.ModelStreamingMode, "Persistent")
			T.ok(persistentBeforeParent(token.model), table.concat(token.model.writes, ","))
			T.eq(token.model.Parent, env.folder)
			T.eq(token.model:GetAttribute("BuildItemId"), "i1")
		end)
		teardown()
		assert(ok, err)
	end)

	T.test("build-load replace builds every model Persistent before swapping it in", function()
		local env = setup()
		local ok, err = pcall(function()
			env.world:apply({ kind = "spawn", id = "i1", record = record(0) })
			local old = env.built[1]
			local token = env.world:apply({ kind = "replace", id = "*", entries = {
				{ id = "i5", record = record(3) },
				{ id = "i6", record = record(6) },
			} })
			for id, model in pairs(token.new) do
				T.eq(model.ModelStreamingMode, "Persistent", id)
				T.ok(persistentBeforeParent(model), id .. ": " .. table.concat(model.writes, ","))
				T.eq(model.Parent, env.folder)
			end
			T.eq(old.Parent, nil, "old set detached")
			env.world:rollback(token)
			T.eq(old.Parent, env.folder, "rollback restores the old set")
			T.eq(token.new.i5.destroyed, true)
		end)
		teardown()
		assert(ok, err)
	end)

	T.test("reconcile respawns Persistent models and re-applies Persistent to kept ones", function()
		local env = setup()
		local ok, err = pcall(function()
			local t1 = env.world:apply({ kind = "spawn", id = "i1", record = record(0) })
			local kept = t1.model
			kept.ModelStreamingMode = "Default" -- e.g. changed externally
			env.world:reconcile({
				{ id = "i1", record = record(1) },
				{ id = "i2", record = record(4) }, -- missing from the world: respawned
			})
			T.eq(kept.ModelStreamingMode, "Persistent", "kept model corrected")
			local respawned = env.world.models.i2
			T.ok(respawned ~= nil)
			T.eq(respawned.ModelStreamingMode, "Persistent")
			T.ok(persistentBeforeParent(respawned), table.concat(respawned.writes, ","))
		end)
		teardown()
		assert(ok, err)
	end)
end
