-- Panel door runtime: DoorController with the real DoorAutoOpen core and
-- injected fake sensing, driver, clock and heartbeat. No Roblox physics,
-- tweens or walk-through are exercised.
return function(T, H)
	local DoorController = H.load("src/server/Runtime/DoorController")
	local DoorAutoOpen = H.load("src/server/Core/DoorAutoOpen")

	local META = { hinge = { x = 2.4998779297, z = 0 }, leaf = { center = { 0.0998414308, 4.3001308441, 0 }, size = { 5.2000732422, 8.2000856400, 0.9500000477 } }, swing = "-z", openDegrees = 90 }
	local CLEAR = { nearby = false, occupied = false, blocked = false }
	local NEAR = { nearby = true, occupied = false, blocked = false }
	local BLOCKED_NEAR = { nearby = true, occupied = false, blocked = true }

	local function record(itemId, z)
		return { itemId = itemId or "test_door", x = 0, y = 0, z = z or 8, yaw = 0 }
	end

	-- env.input(reg) decides each door's sensing input (nil = unknown).
	local function setup(opts)
		opts = opts or {}
		local env = { now = 0, calls = {}, connections = 0, failDriver = {} }
		env.input = function() return CLEAR end
		env.sensing = { inputs = function(_, regs)
			env.scans = (env.scans or 0) + 1
			if env.scanError then error("scan failed") end
			local out = {}
			for _, r in ipairs(regs) do out[r.coreId] = env.input(r) end
			return out
		end }
		env.driver = {}
		for _, method in ipairs({ "attach", "detach", "pose", "setCollision" }) do
			env.driver[method] = function(_, r, value)
				if env.failDriver[method] then error(method .. " failed") end
				env.calls[#env.calls + 1] = { method = method, id = r.id, coreId = r.coreId, value = value }
			end
		end
		env.heartbeat = { Connect = function(_, fn)
			env.connections = env.connections + 1
			env.fire = fn
			return { Disconnect = function() env.connections = env.connections - 1 env.fire = nil end }
		end }
		env.core = DoorAutoOpen.new(opts.core)
		env.controller = DoorController.new({
			core = env.core, sensing = env.sensing, driver = env.driver, heartbeat = env.heartbeat,
			clock = function() return env.now end,
			specFor = opts.specFor or function(itemId) if itemId == "test_door" then return META end end,
			scanInterval = 0.25, maxInputAge = 1,
		})
		function env.tick(t) env.now = t env.controller:tick() end
		function env.last(method, id)
			for i = #env.calls, 1, -1 do
				local c = env.calls[i]
				if c.method == method and (id == nil or c.id == id) then return c end
			end
		end
		function env.count(method, id)
			local n = 0
			for _, c in ipairs(env.calls) do if c.method == method and (id == nil or c.id == id) then n = n + 1 end end
			return n
		end
		return env
	end
	local function near(a, b) return math.abs(a - b) < 1e-6 end

	T.test("non-doors and invalid specs are left completely alone", function()
		local env = setup({ specFor = function(itemId)
			if itemId == "bad_door" then return { hinge = { x = 0, z = 0 } } end
			if itemId == "boom" then error("spec lookup failed") end
		end })
		T.eq(env.controller:attach({}, "i1", record("cozy_plant_01"), true), nil)
		T.eq(env.controller:attach({}, "i2", record("bad_door"), true), nil)
		T.eq(env.controller:attach({}, "i3", record("boom"), true), nil)
		for _, m in ipairs({ "beginEdit", "thaw", "cancelEdit", "detach" }) do
			T.eq(env.controller[m](env.controller, {}), false, m .. " on an unknown model")
		end
		T.eq(env.controller:moved({}, record()), false)
		env.tick(1)
		T.eq(#env.calls, 0, "no driver calls")
		T.eq(env.core:count(), 0)
	end)

	T.test("open cycle: linear poses from the core's progress, collision off while moving and restored only closed and clear", function()
		local env = setup()
		local model = {}
		local reg = env.controller:attach(model, "i1", record(), false)
		T.ok(reg ~= nil and env.count("attach") == 1)
		env.input = function() return NEAR end
		env.tick(0)
		T.eq(env.last("setCollision").value, false, "collision off as it starts moving")
		env.tick(0.15)
		T.ok(near(env.last("pose").value, 22.5), "a quarter of the way: 22.5 degrees")
		env.tick(0.3)
		T.ok(near(env.last("pose").value, 45), "half-way: 45 degrees")
		env.tick(0.6)
		T.ok(near(env.last("pose").value, 90), "fully open")
		local poses = env.count("pose")
		env.tick(0.7)
		T.eq(env.count("pose"), poses, "no redundant pose calls at rest")
		T.eq(env.last("setCollision").value, false, "open: collision still off")
		env.input = function() return CLEAR end
		env.tick(1); env.tick(2.9)
		T.ok(near(env.last("pose").value, 90), "still open during the exit delay")
		T.eq(env.last("setCollision").value, false, "open and clear but not closed: collision still off")
		for _, c in ipairs(env.calls) do
			T.ok(not (c.method == "setCollision" and c.value == true), "no collision restore while open")
		end
		env.tick(3.0) -- closing starts
		env.tick(3.3)
		T.ok(near(env.last("pose").value, 45), "closing linearly")
		local collisionsBefore = env.count("setCollision")
		env.tick(3.6)
		T.ok(near(env.last("pose").value, 0))
		T.eq(env.count("setCollision"), collisionsBefore + 1)
		T.eq(env.last("setCollision").value, true, "closed and clear: original collision restored")
	end)

	T.test("blockage mid-motion holds the leaf; malformed or failed scans hold it too", function()
		local env = setup()
		env.controller:attach({}, "i1", record(), false)
		env.input = function() return NEAR end
		env.tick(0); env.tick(0.25)
		env.input = function() return BLOCKED_NEAR end
		env.tick(0.5) -- held at progress 0.5/0.6
		local held = env.last("pose").value
		for t = 1, 5 do env.tick(t) end
		T.ok(near(env.last("pose").value, held), "held where it stopped")
		T.eq(env.last("setCollision").value, false, "collision stays off while held")
		for _, bad in ipairs({ { nearby = true }, "near", { nearby = true, occupied = false, blocked = "no" } }) do
			env.input = function() return bad end
			env.tick(env.now + 0.5)
			T.ok(near(env.last("pose").value, held), "malformed input: still held")
		end
		env.scanError = true
		env.tick(env.now + 0.5)
		T.ok(near(env.last("pose").value, held), "a failed scan: still held")
		env.scanError = false
		env.input = function() return NEAR end
		env.tick(env.now + 0.5)
		env.tick(env.now + 0.6)
		T.ok(near(env.last("pose").value, 90), "resumes once the sweep is known clear")
	end)

	T.test("stale sensing results expire: an old 'clear' can't close or open a door", function()
		local env = setup()
		local reg = env.controller:attach({}, "i1", record(), false)
		env.input = function() return NEAR end
		env.tick(0); env.tick(0.6)
		env.input = function() return CLEAR end
		env.tick(0.9) -- one fresh 'clear' scan
		env.controller.scanInterval = 100 -- no new scans from here on
		env.tick(5)
		T.eq(env.core:state(reg.coreId).phase, "open", "the 'clear' is 4.1 s old (> maxInputAge 1 s): unknown, so it doesn't close")
		env.controller.scanInterval = 0.25
		env.tick(5.1); env.tick(7.1)
		T.eq(env.core:state(reg.coreId).phase, "closing", "fresh 'clear' scans close it after the exit delay")
	end)

	T.test("edits: a frozen (reset) door can't reopen until thaw; cancelEdit restores the record; nested edits keep the original", function()
		local env = setup()
		local model = {}
		local reg = env.controller:attach(model, "i1", record(nil, 8), false)
		env.input = function() return NEAR end
		env.tick(0); env.tick(0.6)
		T.eq(env.controller:beginEdit(model), true)
		T.eq(env.last("pose").value, 0, "snapped closed")
		T.eq(env.last("setCollision").value, false)
		T.eq(env.core:state(reg.coreId).phase, "closed")
		env.controller:moved(model, record(nil, 24))
		T.eq(reg.record.z, 24)
		env.controller:beginEdit(model) -- nested
		for t = 1, 10 do env.tick(t) end
		T.eq(env.core:state(reg.coreId).phase, "closed", "near the whole time, but frozen")
		T.eq(env.last("pose").value, 0)
		env.controller:cancelEdit(model)
		T.eq(reg.record.z, 8, "rollback restores the record from before the first edit")
		T.ok(reg.roomBox.maxZ < 9, "room box follows the restored record")
		env.tick(11); env.tick(11.6)
		T.ok(near(env.last("pose").value, 90), "opens again after thaw")
	end)

	T.test("reused ids: a replacement model with the same id gets a fresh registration; the old model can't touch it", function()
		local env = setup()
		local old, new = {}, {}
		local a = env.controller:attach(old, "i1", record(), false)
		env.input = function() return NEAR end
		env.tick(0)
		local b = env.controller:attach(new, "i1", record(), true)
		T.ok(b ~= a and b.coreId ~= a.coreId and b.generation > a.generation)
		T.eq(env.controller:detach(old), true)
		T.eq(env.controller:registration(new), b, "detaching the old model leaves the new one")
		T.eq(env.controller:thaw(old), false)
		T.eq(env.controller:beginEdit(old), false)
		env.controller:thaw(new)
		env.tick(1); env.tick(1.6)
		T.ok(env.core:state(b.coreId).phase == "open")
		T.eq(env.core:state(a.coreId), nil, "the old core entry is gone")
		-- Detach and attach the same model object again: new generation, new core id.
		env.controller:detach(new)
		local c = env.controller:attach(new, "i1", record(), false)
		T.ok(c.coreId ~= b.coreId and c.coreId ~= a.coreId)
		T.eq(env.controller:attach(new, "i1", record(), false), c, "attaching an attached model is idempotent")
	end)

	T.test("invalid clocks make a tick a no-op; driver failures are isolated; the door cap leaves extras static", function()
		local env = setup()
		env.controller:attach({}, "i1", record(), false)
		env.input = function() return NEAR end
		for _, bad in ipairs({ 0 / 0, math.huge, -math.huge }) do
			env.tick(bad)
		end
		T.eq(env.count("pose"), 0)
		T.eq(env.count("setCollision"), 0)
		env.failDriver.pose = true
		env.tick(0); env.tick(0.3)
		env.failDriver.pose = false
		env.tick(0.6)
		T.ok(near(env.last("pose").value, 90), "a failing pose call doesn't break later ticks")
		local small = setup({ core = { maxDoors = 1 } })
		T.ok(small.controller:attach({}, "a", record(), false) ~= nil)
		T.eq(small.controller:attach({}, "b", record(), false), nil, "over the cap: left static")
		T.eq(small.count("attach"), 1, "no driver state for the extra door")
		small.failDriver.attach = true
		local m3 = setup()
		m3.failDriver.attach = true
		T.eq(m3.controller:attach({}, "c", record(), false), nil, "a failing driver attach leaves it static")
		T.eq(m3.core:count(), 0, "and releases its core entry")
	end)

	T.test("start, stop and destroy: one heartbeat connection at most; nothing left running; doors restored", function()
		local env = setup()
		local model = {}
		env.controller:attach(model, "i1", record(), false)
		T.eq(env.controller:start(), true)
		T.eq(env.controller:start(), false, "no second connection")
		T.eq(env.connections, 1)
		env.input = function() return NEAR end
		env.now = 0; env.fire()
		env.now = 0.3; env.fire()
		T.ok(near(env.last("pose").value, 45), "ticks through the heartbeat")
		env.controller:stop()
		T.eq(env.connections, 0)
		env.controller:stop()
		T.eq(env.connections, 0, "stop is idempotent")
		env.controller:start()
		env.controller:destroy()
		T.eq(env.connections, 0, "destroy disconnects")
		T.eq(env.last("pose").value, 0, "destroy returns doors to closed")
		T.eq(env.last("setCollision").value, true, "with their original collision")
		T.eq(env.count("detach"), 1)
		T.eq(env.controller:count(), 0)
		T.eq(env.core:count(), 0, "core entries released")
		local calls = #env.calls
		env.tick(5)
		T.eq(#env.calls, calls, "tick after destroy is a no-op")
		T.eq(env.controller:start(), false)
		T.eq(env.controller:attach({}, "i2", record(), false), nil, "no attach after destroy")
	end)

	T.test("scans are bounded to active doors at the scan interval; frozen doors are never scanned", function()
		local env = setup()
		local seen
		env.sensing.inputs = function(_, regs) seen = regs return {} end
		local a, b = {}, {}
		env.controller:attach(a, "i1", record(), false)
		env.controller:attach(b, "i2", record(nil, -8), true)
		env.tick(0)
		T.eq(#seen, 1, "only the unfrozen door")
		seen = nil
		env.tick(0.1)
		T.eq(seen, nil, "no rescan inside the interval")
		env.tick(0.3)
		T.ok(seen ~= nil)
	end)
end
