-- Panel door runtime: PlacedItemsWorld's optional door hook, with fake
-- Instances. First with a recording hook (exact call order per effect),
-- then with the real DoorController + DoorAutoOpen and a fake driver. The
-- production BuilderService passes no hook (checked in door_geometry_spec).
return function(T, H)
	local PlacedItemsWorld = H.load("src/server/Runtime/PlacedItemsWorld")
	local DoorController = H.load("src/server/Runtime/DoorController")
	local DoorAutoOpen = H.load("src/server/Core/DoorAutoOpen")

	local META = { hinge = { x = 2.4998779297, z = 0 }, leaf = { center = { 0.0998414308, 4.3001308441, 0 }, size = { 5.2000732422, 8.2000856400, 0.9500000477 } }, swing = "-z", openDegrees = 90 }
	local NEAR = { nearby = true, occupied = false, blocked = false }

	local function cf(desc)
		return setmetatable({ desc = desc }, { __mul = function(a, b) return cf(a.desc .. "*" .. b.desc) end })
	end
	local fakeCFrame = {
		new = function(x, y, z) return cf(string.format("T(%g,%g,%g)", x, y, z)) end,
		Angles = function(_, y) return cf(string.format("R(%g)", y)) end,
	}

	local function setup(withDoors, missingTemplates, opts)
		opts = opts or {}
		H.setGlobal("CFrame", fakeCFrame)
		H.setGlobal("Enum", { ModelStreamingMode = { Persistent = "Persistent" } })
		local env = { log = {}, built = {}, revisions = 0, activeCap = opts.activeCap, failDriver = {} }
		local function note(s) env.log[#env.log + 1] = s end
		env.folder = { Name = "Folder" }
		function env.folder:GetChildren()
			local out = {}
			for _, m in ipairs(env.built) do
				if m.Parent == env.folder and not m.destroyed then out[#out + 1] = m end
			end
			return out
		end
		function env.folder:SetAttribute() env.revisions = env.revisions + 1 end
		local function fakeModel()
			local props, attrs = {}, {}
			local model = {}
			local methods = {
				GetDescendants = function() return {} end,
				SetAttribute = function(_, k, v) attrs[k] = v end,
				GetAttribute = function(_, k) return attrs[k] end,
				PivotTo = function(_, c)
					if env.failPivot and attrs.BuildItemId == env.failPivot then error("pivot failed") end
					props.pivot = c.desc note("PivotTo " .. tostring(attrs.BuildItemId) .. " " .. c.desc)
				end,
				GetPivot = function() return cf(props.pivot or "none") end,
				Destroy = function() props.destroyed = true props.Parent = nil note("Destroy " .. tostring(attrs.BuildItemId)) end,
			}
			return setmetatable(model, {
				__index = function(_, k) return methods[k] or props[k] end,
				__newindex = function(_, k, v)
					props[k] = v
					if k == "Parent" then note("Parent " .. tostring(attrs.BuildItemId) .. "=" .. (v == nil and "nil" or "folder")) end
				end,
			})
		end
		local template = { Clone = function() local m = fakeModel() env.built[#env.built + 1] = m return m end }
		local getTemplate = function(itemId)
			if missingTemplates and missingTemplates[itemId] then return nil end
			return template
		end
		if withDoors == "record" then
			env.doors = {}
			for _, method in ipairs({ "attach", "beginEdit", "moved", "cancelEdit", "thaw", "detach" }) do
				env.doors[method] = function(_, model, a, b, c)
					local id = model and model:GetAttribute("BuildItemId")
					note(method .. " " .. tostring(id) .. (method == "attach" and (" frozen=" .. tostring(c)) or ""))
				end
			end
		elseif withDoors == "real" then
			env.now = 0
			env.input = NEAR
			env.calls = {}
			local driver = {}
			for _, method in ipairs({ "attach", "detach", "pose", "setCollision" }) do
				driver[method] = function(_, reg, value)
					local f = env.failDriver[method]
					if f and (f == true or f == reg.id or (type(f) == "function" and f(reg))) then
						error(method .. " failed")
					end
					env.calls[#env.calls + 1] = { method = method, id = reg.id, value = value }
					if method == "pose" then note("pose " .. reg.id .. " " .. tostring(value)) end
				end
			end
			env.core = DoorAutoOpen.new({ maxDoors = 2 * (env.activeCap or 150) })
			env.doors = DoorController.new({
				core = env.core, driver = driver, clock = function() return env.now end,
				sensing = { inputs = function(_, regs) local out = {} for _, r in ipairs(regs) do out[r.coreId] = env.input end return out end },
				specFor = function(itemId) if itemId == "test_door" then return META end end,
				activeCap = env.activeCap,
			})
			function env.tick(t) env.now = t env.doors:tick() end
		end
		env.world = PlacedItemsWorld.new(env.folder, cf("O"), getTemplate, env.doors)
		function env.since(mark)
			local out = {}
			for i = mark + 1, #env.log do out[#out + 1] = env.log[i] end
			return out
		end
		return env
	end
	local function teardown()
		H.setGlobal("CFrame", nil)
		H.setGlobal("Enum", nil)
	end
	local function run(fn)
		local ok, err = pcall(fn)
		teardown()
		assert(ok, err)
	end
	local function rec(x, itemId)
		return { itemId = itemId or "test_door", placedByUserId = 1, x = x or 0, y = 0, z = 8, yaw = 0 }
	end
	local function index(list, value)
		for i, v in ipairs(list) do if v == value then return i end end
	end

	T.test("no hook: every effect kind works exactly as before and nothing door-related is called", function()
		run(function()
			local env = setup(nil)
			T.eq(env.world.doors, nil)
			local s = env.world:apply({ kind = "spawn", id = "i1", record = rec(0) }); env.world:commit(s)
			local m = env.world:apply({ kind = "move", id = "i1", to = rec(4) }); env.world:rollback(m)
			local r = env.world:apply({ kind = "remove", id = "i1" }); env.world:rollback(r)
			local p = env.world:apply({ kind = "replace", entries = { { id = "i2", record = rec(1) } } }); env.world:commit(p)
			env.world:reconcile({ { id = "i2", record = rec(2) }, { id = "i3", record = rec(3) } })
			for _, line in ipairs(env.log) do
				T.ok(not line:find("^attach") and not line:find("^beginEdit") and not line:find("^thaw") and not line:find("^detach"), line)
			end
			T.eq(#env.folder:GetChildren(), 2)
		end)
	end)

	T.test("spawn (place, duplicate, redo): attach frozen after parenting; commit thaws; rollback detaches before destroying", function()
		run(function()
			local env = setup("record")
			local mark = #env.log
			local token = env.world:apply({ kind = "spawn", id = "i1", record = rec() })
			local seq = env.since(mark)
			T.ok(index(seq, "Parent i1=folder") < index(seq, "attach i1 frozen=true"), table.concat(seq, ", "))
			mark = #env.log
			env.world:commit(token)
			T.deepEq(env.since(mark), { "thaw i1" })
			local t2 = env.world:apply({ kind = "spawn", id = "i2", record = rec(2) })
			mark = #env.log
			env.world:rollback(t2)
			T.deepEq(env.since(mark), { "detach i2", "Destroy i2" })
		end)
	end)

	T.test("move (move, rotate, undo/redo of a move): beginEdit before the pivot changes, moved after; rollback re-pivots then cancels", function()
		run(function()
			local env = setup("record")
			env.world:commit(env.world:apply({ kind = "spawn", id = "i1", record = rec(0) }))
			local mark = #env.log
			local token = env.world:apply({ kind = "move", id = "i1", to = rec(4) })
			local seq = env.since(mark)
			T.eq(seq[1], "beginEdit i1")
			T.ok(seq[2]:find("^PivotTo i1"), seq[2])
			T.eq(seq[3], "moved i1")
			mark = #env.log
			env.world:rollback(token)
			seq = env.since(mark)
			T.ok(seq[1]:find("^PivotTo i1"), "pivot restored first")
			T.eq(seq[2], "cancelEdit i1")
			local t2 = env.world:apply({ kind = "move", id = "i1", to = rec(5) })
			mark = #env.log
			env.world:commit(t2)
			T.deepEq(env.since(mark), { "thaw i1" })
		end)
	end)

	T.test("remove (delete, undo of a place): beginEdit before unparenting; commit detaches before destroying; rollback cancels after reparenting", function()
		run(function()
			local env = setup("record")
			env.world:commit(env.world:apply({ kind = "spawn", id = "i1", record = rec() }))
			local mark = #env.log
			local token = env.world:apply({ kind = "remove", id = "i1" })
			T.deepEq(env.since(mark), { "beginEdit i1", "Parent i1=nil" })
			mark = #env.log
			env.world:rollback(token)
			T.deepEq(env.since(mark), { "Parent i1=folder", "cancelEdit i1" })
			local t2 = env.world:apply({ kind = "remove", id = "i1" })
			mark = #env.log
			env.world:commit(t2)
			T.deepEq(env.since(mark), { "detach i1", "Destroy i1" })
		end)
	end)

	T.test("replace (build load): old frozen and new attached frozen; commit and rollback release the right set; a failed build calls nothing", function()
		run(function()
			local env = setup("record", { missing_door = true })
			env.world:commit(env.world:apply({ kind = "spawn", id = "i1", record = rec() }))
			local mark = #env.log
			local token = env.world:apply({ kind = "replace", entries = { { id = "i1", record = rec(3) }, { id = "i2", record = rec(6) } } })
			local seq = env.since(mark)
			T.ok(index(seq, "beginEdit i1") < index(seq, "Parent i1=nil"), "the old model is frozen before it is detached: " .. table.concat(seq, ", "))
			T.ok(index(seq, "attach i1 frozen=true") and index(seq, "attach i2 frozen=true"), table.concat(seq, ", "))
			mark = #env.log
			env.world:rollback(token)
			seq = env.since(mark)
			T.eq(#seq, 6, table.concat(seq, ", "))
			T.ok(index(seq, "detach i1") < index(seq, "cancelEdit i1"), "new detached, old thawed")
			local t2 = env.world:apply({ kind = "replace", entries = { { id = "i1", record = rec(3) } } })
			mark = #env.log
			env.world:commit(t2)
			T.deepEq(env.since(mark), { "detach i1", "Destroy i1", "thaw i1" })
			mark = #env.log
			T.throws(function()
				env.world:apply({ kind = "replace", entries = { { id = "i7", record = rec(1) }, { id = "i8", record = rec(2, "missing_door") } } })
			end)
			for _, line in ipairs(env.since(mark)) do
				T.ok(not line:find("^attach") and not line:find("^beginEdit") and not line:find("^detach"), "failed build: " .. line)
			end
		end)
	end)

	T.test("reconcile: dropped and stray models detached; kept models frozen, re-pivoted and thawed; respawns attached then thawed; repeatable", function()
		run(function()
			local env = setup("record")
			env.world:commit(env.world:apply({ kind = "spawn", id = "i1", record = rec(0) }))
			env.world:commit(env.world:apply({ kind = "spawn", id = "i2", record = rec(1) }))
			local mark = #env.log
			env.world:reconcile({ { id = "i1", record = rec(5) }, { id = "i3", record = rec(9) } })
			local seq = env.since(mark)
			T.ok(index(seq, "detach i2") < index(seq, "Destroy i2"), table.concat(seq, ", "))
			local b = index(seq, "beginEdit i1")
			T.ok(b and seq[b + 1]:find("^PivotTo i1") and seq[b + 2] == "moved i1" and seq[b + 3] == "thaw i1", "kept: freeze, pivot, moved, thaw")
			T.ok(index(seq, "attach i3 frozen=true") < index(seq, "thaw i3"))
			mark = #env.log
			env.world:reconcile({ { id = "i1", record = rec(5) }, { id = "i3", record = rec(9) } })
			seq = env.since(mark)
			T.eq(index(seq, "attach i1"), nil, "no duplicate attach on a repeat")
			T.eq(index(seq, "attach i3 frozen=true"), nil)
			T.ok(index(seq, "thaw i1") and index(seq, "thaw i3"))
		end)
	end)

	T.test("real controller: a door placed but not committed can't open; after commit it opens; edits snap it closed before the pivot moves", function()
		run(function()
			local env = setup("real")
			local token = env.world:apply({ kind = "spawn", id = "i1", record = rec(0) })
			env.tick(0); env.tick(1)
			T.eq(env.core:count(), 1)
			local reg = env.doors:registration(token.model)
			T.eq(env.core:state(reg.coreId).phase, "closed", "frozen until commit")
			env.world:commit(token)
			env.tick(2); env.tick(2.6)
			T.eq(env.core:state(reg.coreId).phase, "open")
			-- Move while open: snapped closed BEFORE the model's pivot changes.
			local mark = #env.log
			local move = env.world:apply({ kind = "move", id = "i1", to = rec(4) })
			local seq = env.since(mark)
			T.ok(index(seq, "pose i1 0") < (function() for i, l in ipairs(seq) do if l:find("^PivotTo") then return i end end end)(), table.concat(seq, ", "))
			for t = 3, 8 do env.tick(t) end
			T.eq(env.core:state(reg.coreId).phase, "closed", "a reset door can't reopen between apply and commit/rollback")
			T.eq(reg.record.x, 4)
			env.world:rollback(move)
			T.eq(reg.record.x, 0, "rollback restores the stored record (the stable pivot source)")
			env.tick(9); env.tick(9.6)
			T.eq(env.core:state(reg.coreId).phase, "open", "usable again after rollback")
			T.eq(env.revisions, 0, "door activity never publishes a build revision")
		end)
	end)

	T.test("real controller: remove, replace with a reused id, failed replace and repeated reconcile leave exactly one registration per live door", function()
		run(function()
			local env = setup("real", { missing_door = true })
			local function regs() return env.doors:count() end
			env.world:commit(env.world:apply({ kind = "spawn", id = "i1", record = rec(0) }))
			env.world:commit(env.world:apply({ kind = "spawn", id = "p1", record = rec(0, "cozy_plant_01") }))
			T.eq(regs(), 1, "non-door items are never registered")
			-- Remove + rollback keeps it; remove + commit releases it.
			env.world:rollback(env.world:apply({ kind = "remove", id = "i1" }))
			T.eq(regs(), 1)
			local oldModel = env.world.models.i1
			local oldReg = env.doors:registration(oldModel)
			-- Build load reusing id i1: rollback restores the old registration untouched.
			env.world:rollback(env.world:apply({ kind = "replace", entries = { { id = "i1", record = rec(7) } } }))
			T.eq(regs(), 1)
			T.eq(env.doors:registration(oldModel), oldReg)
			T.eq(oldReg.frozen, false)
			T.eq(oldReg.record.x, 0)
			-- Commit: the old model's registration is released, the new one has a fresh core id.
			env.world:commit(env.world:apply({ kind = "replace", entries = { { id = "i1", record = rec(7) } } }))
			T.eq(regs(), 1)
			T.eq(env.doors:registration(oldModel), nil)
			local newReg = env.doors:registration(env.world.models.i1)
			T.ok(newReg.coreId ~= oldReg.coreId)
			T.eq(env.core:state(oldReg.coreId), nil)
			-- A failed build load changes nothing.
			T.throws(function() env.world:apply({ kind = "replace", entries = { { id = "i9", record = rec(1, "missing_door") } } }) end)
			T.eq(regs(), 1)
			T.eq(env.doors:registration(env.world.models.i1), newReg)
			-- Repeated reconcile: kept door re-registered in place, extras added once.
			env.tick(0); env.tick(0.6)
			env.world:reconcile({ { id = "i1", record = rec(2) }, { id = "i4", record = rec(5) } })
			env.world:reconcile({ { id = "i1", record = rec(2) }, { id = "i4", record = rec(5) } })
			T.eq(regs(), 2)
			T.eq(newReg.record.x, 2)
			T.eq(newReg.frozen, false)
			-- Delete commit releases everything for that door.
			env.world:commit(env.world:apply({ kind = "remove", id = "i4" }))
			T.eq(regs(), 1)
			T.eq(env.core:count(), 1, "core entries match live doors")
		end)
	end)

	T.test("real controller: a reconcile that fails mid-door leaves that door frozen and closed; the next successful reconcile thaws it", function()
		run(function()
			local env = setup("real", { missing_door = true })
			env.world:commit(env.world:apply({ kind = "spawn", id = "i1", record = rec(0) }))
			local reg = env.doors:registration(env.world.models.i1)
			env.tick(0); env.tick(0.6)
			T.eq(env.core:state(reg.coreId).phase, "open")
			-- A failing respawn before the door is reached leaves the door untouched and usable.
			T.throws(function()
				env.world:reconcile({ { id = "i2", record = rec(2, "missing_door") }, { id = "i1", record = rec(1) } })
			end)
			T.eq(reg.frozen, false)
			-- A failure while re-pivoting the kept door itself leaves it frozen and snapped closed.
			env.failPivot = "i1"
			T.throws(function()
				env.world:reconcile({ { id = "i1", record = rec(1) } })
			end)
			env.failPivot = nil
			T.eq(reg.frozen, true, "left frozen: safe")
			env.tick(0); env.tick(1)
			T.eq(env.core:state(reg.coreId).phase, "closed")
			env.world:reconcile({ { id = "i1", record = rec(1) } })
			T.eq(reg.frozen, false)
			env.tick(2); env.tick(2.6)
			T.eq(env.core:state(reg.coreId).phase, "open")
		end)
	end)

	T.test("build load at capacity: a full replacement set is staged beside the frozen old set; commit keeps every new door, rollback keeps every old one", function()
		run(function()
			local env = setup("real", nil, { activeCap = 3 })
			local function load(entries) return env.world:apply({ kind = "replace", entries = entries }) end
			-- 3 doors (the cap) plus 2 non-doors.
			env.world:commit(load({
				{ id = "d1", record = rec(0) }, { id = "p1", record = rec(1, "cozy_plant_01") },
				{ id = "d2", record = rec(2) }, { id = "d3", record = rec(3) }, { id = "p2", record = rec(4, "cozy_plant_01") },
			}))
			T.eq(env.doors:committedCount(), 3)
			local oldRegs = {}
			for _, id in ipairs({ "d1", "d2", "d3" }) do oldRegs[id] = env.doors:registration(env.world.models[id]) end
			-- Replace with 3 doors (two reusing ids) and a non-door: rollback restores the old set intact.
			local entries = { { id = "d1", record = rec(5) }, { id = "d2", record = rec(6) }, { id = "d9", record = rec(7) }, { id = "p3", record = rec(8, "cozy_plant_01") } }
			local token = load(entries)
			T.eq(env.doors:count(), 6, "3 old (frozen) + 3 staged")
			T.eq(env.doors:committedCount(), 3, "staged doors don't count against the cap")
			env.world:rollback(token)
			T.eq(env.doors:count(), 3)
			T.eq(env.doors:committedCount(), 3)
			for id, reg in pairs(oldRegs) do
				T.eq(env.doors:registration(env.world.models[id]), reg, id .. " kept")
				T.eq(reg.frozen, false, id .. " thawed")
			end
			-- Commit: every new door is registered and active; none dropped.
			env.world:commit(load(entries))
			T.eq(env.doors:count(), 3)
			T.eq(env.doors:committedCount(), 3)
			T.eq(next(env.doors.overflow), nil, "nothing over capacity")
			for _, id in ipairs({ "d1", "d2", "d9" }) do
				local reg = env.doors:registration(env.world.models[id])
				T.ok(reg ~= nil and reg.frozen == false and reg.staged == false, id .. " active")
			end
			T.eq(env.core:count(), 3, "core slots match live doors")
			env.tick(0); env.tick(0.3); env.tick(0.9)
			for _, id in ipairs({ "d1", "d2", "d9" }) do
				T.eq(env.core:state(env.doors:registration(env.world.models[id]).coreId).phase, "open", id .. " works")
			end
		end)
	end)

	T.test("build load over capacity is explicit: extra new doors are recorded in overflow, not silently dropped", function()
		run(function()
			local env = setup("real", nil, { activeCap = 2 })
			env.world:commit(env.world:apply({ kind = "replace", entries = { { id = "a", record = rec(0) }, { id = "b", record = rec(1) }, { id = "c", record = rec(2) } } }))
			T.eq(env.doors:committedCount(), 2)
			local overflowCount = 0
			for _ in pairs(env.doors.overflow) do overflowCount = overflowCount + 1 end
			T.eq(overflowCount, 1, "the third door is recorded")
			T.eq(env.core:count(), 2)
		end)
	end)

	T.test("driver faults during edits: move and remove applies fail before touching the model; a failing build load unwinds; reconcile stays in recovery", function()
		run(function()
			local env = setup("real")
			env.world:commit(env.world:apply({ kind = "spawn", id = "i1", record = rec(0) }))
			env.world:commit(env.world:apply({ kind = "spawn", id = "i2", record = rec(2) }))
			local m1 = env.world.models.i1
			local r1 = env.doors:registration(m1)
			env.tick(0); env.tick(0.6)
			T.eq(env.core:state(r1.coreId).phase, "open")
			env.failDriver.pose = "i1"
			local mark = #env.log
			T.throws(function() env.world:apply({ kind = "move", id = "i1", to = rec(9) }) end)
			for _, line in ipairs(env.since(mark)) do
				T.ok(not line:find("^PivotTo i1"), "the model never moved half-open: " .. line)
			end
			T.eq(r1.record.x, 0)
			T.eq(r1.frozen, false)
			T.eq(r1.faulted, true)
			T.throws(function() env.world:apply({ kind = "remove", id = "i1" }) end)
			T.eq(m1.Parent, env.folder, "remove failed before unparenting")
			-- Build load: whichever old door freezes first succeeds, the second fails:
			-- the first freeze is cancelled and the new models destroyed.
			env.failDriver.pose = nil
			env.tick(1); env.tick(1.3) -- recover i1 first
			local poses, firstFrozen = 0, nil
			env.failDriver.pose = function(reg)
				poses = poses + 1
				if poses == 1 then firstFrozen = reg.id end
				return poses == 2
			end
			local before = #env.built
			T.throws(function() env.world:apply({ kind = "replace", entries = { { id = "i5", record = rec(5) } } }) end)
			env.failDriver.pose = nil
			T.ok(firstFrozen ~= nil, "one old door was frozen before the failure")
			T.eq(env.world.models.i1, m1, "the old set is still current")
			T.eq(env.doors:registration(env.world.models[firstFrozen]).frozen, false, "the first freeze was cancelled")
			T.eq(env.doors:registration(env.world.models[firstFrozen]).recordBeforeEdit, nil)
			T.eq(env.built[before + 1].destroyed, true, "the new model was destroyed")
			T.eq(env.doors:count(), 2, "no staged registrations left behind")
			-- Reconcile: the failing door aborts it (the core stays in recovery); fix the driver and it completes.
			env.tick(2); env.tick(2.3) -- resync whichever door faulted above
			env.failDriver.pose = "i1"
			T.throws(function() env.world:reconcile({ { id = "i1", record = rec(0) }, { id = "i2", record = rec(2) } }) end)
			env.failDriver.pose = nil
			env.tick(3); env.tick(3.3)
			T.eq(r1.faulted, false, "resynced")
			env.world:reconcile({ { id = "i1", record = rec(0) }, { id = "i2", record = rec(2) } })
			T.eq(r1.frozen, false)
			T.eq(env.core:state(r1.coreId).phase, "closed", "reconciled closed at its stored pose")
			T.eq(env.revisions, 0)
		end)
	end)
end
