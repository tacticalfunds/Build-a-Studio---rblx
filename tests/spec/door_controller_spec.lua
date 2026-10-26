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
		env.core = DoorAutoOpen.new(opts.core or { maxDoors = 300 })
		env.controller = DoorController.new({
			core = env.core, sensing = env.sensing, driver = env.driver, heartbeat = env.heartbeat,
			clock = function() return env.now end,
			specFor = opts.specFor or function(itemId) if itemId == "test_door" then return META end end,
			scanInterval = 0.25, maxInputAge = 1, activeCap = opts.activeCap,
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

	T.test("invalid clocks make a tick a no-op; capacity: committed doors capped, staged doors don't count until thaw, overflow recorded", function()
		local env = setup()
		env.controller:attach({}, "i1", record(), false)
		env.input = function() return NEAR end
		for _, bad in ipairs({ 0 / 0, math.huge, -math.huge }) do
			env.tick(bad)
		end
		T.eq(env.count("pose"), 0)
		T.eq(env.count("setCollision"), 0)
		T.eq(pcall(DoorController.new, { core = DoorAutoOpen.new({ maxDoors = 150 }), sensing = env.sensing, driver = env.driver,
			clock = function() return 0 end, specFor = function() end }), false, "the core must have staging room for 2 x activeCap")
		local small = setup({ core = { maxDoors = 2 }, activeCap = 1 })
		local a = {}
		T.ok(small.controller:attach(a, "a", record(), false) ~= nil)
		local b = {}
		T.eq(small.controller:attach(b, "b", record(), false), nil, "a second committed door is over the cap")
		T.eq(small.controller.overflow[b], "b", "recorded, not silently dropped")
		T.eq(small.count("attach"), 1, "no driver state for it")
		local staged = {}
		T.ok(small.controller:attach(staged, "c", record(), true) ~= nil, "a staged door fits beside the committed one")
		T.eq(small.controller:committedCount(), 1)
		T.eq(small.controller:thaw(staged), false, "thawing it while the cap is full releases it")
		T.eq(small.controller.overflow[staged], "c")
		T.eq(small.controller:count(), 1)
		T.eq(small.core:count(), 1, "its core slot is released")
		-- The review's reproduction at the smallest cap: old door frozen by a replace, replacement staged beside it.
		local r = setup({ core = { maxDoors = 2 }, activeCap = 1 })
		local old, new = {}, {}
		r.controller:attach(old, "i1", record(), false)
		r.controller:beginEdit(old)
		local staged2 = r.controller:attach(new, "i1", record(), true)
		T.ok(staged2 ~= nil, "the replacement is staged, not refused")
		r.controller:detach(old)
		T.eq(r.controller:thaw(new), true, "commit: old released first, then the new door becomes active")
		T.eq(staged2.staged, false); T.eq(staged2.frozen, false)
		r.input = function() return NEAR end
		r.tick(0); r.tick(0.6)
		T.eq(r.core:state(staged2.coreId).phase, "open", "the replacement door works")
		local m3 = setup()
		m3.failDriver.attach = true
		T.eq(m3.controller:attach({}, "c", record(), false), nil, "a failing driver attach leaves it static")
		T.eq(m3.core:count(), 0, "and releases its core entry")
	end)

	T.test("faults: collision that can't be disabled stops the motion before any pose; recovery resyncs, then motion needs fresh input", function()
		local env = setup()
		local reg = env.controller:attach({}, "i1", record(), false)
		env.input = function() return NEAR end
		env.failDriver.setCollision = true
		env.tick(0)
		T.eq(reg.faulted, true)
		T.eq(env.core:state(reg.coreId).phase, "held", "the core motion is held at once")
		env.tick(0.15)
		T.eq(env.count("pose"), 0, "no pose for a motion whose collision couldn't be disabled")
		T.ok(near(env.core:state(reg.coreId, 0.15).progress, 0))
		env.tick(0.2) -- resync attempts are rate-limited to the scan interval
		env.failDriver.setCollision = false
		env.tick(0.3)
		T.eq(reg.faulted, false, "resynced: collision off and pose matched")
		T.eq(env.last("setCollision").value, false)
		T.eq(env.last("pose").value, 0)
		T.eq(env.core:state(reg.coreId).phase, "held", "still held until fresh input")
		env.tick(0.6); env.tick(1.3)
		T.ok(near(env.last("pose").value, 90), "opens on fresh input after recovery")
	end)

	T.test("faults: a failed pose isn't recorded as applied; the leaf is held and re-posed on recovery", function()
		local env = setup()
		local reg = env.controller:attach({}, "i1", record(), false)
		env.input = function() return NEAR end
		env.tick(0)
		env.tick(0.15)
		T.ok(near(reg.angle, 22.5))
		env.failDriver.pose = true
		env.tick(0.3)
		T.ok(near(reg.angle, 22.5), "the angle stays at the last accepted pose")
		T.eq(reg.faulted, true)
		T.eq(env.core:state(reg.coreId).phase, "held")
		local held = env.core:state(reg.coreId).progress * 90
		env.tick(0.4) -- a resync attempt that also fails: next attempt not before 0.65
		env.failDriver.pose = false
		env.tick(0.6)
		T.eq(reg.faulted, true, "resync attempts are rate-limited")
		env.tick(0.7)
		T.eq(reg.faulted, false)
		T.ok(near(env.last("pose").value, held), "re-posed to where the core holds it")
		T.ok(near(reg.angle, held))
	end)

	T.test("faults: collision restore failure keeps it faulted and retries; beginEdit raises without touching edit state", function()
		local env = setup()
		local model = {}
		local reg = env.controller:attach(model, "i1", record(), false)
		env.input = function() return NEAR end
		env.tick(0); env.tick(0.6)
		env.input = function() return CLEAR end
		env.tick(1); env.tick(3); env.tick(3.3)
		env.failDriver.setCollision = true
		env.tick(3.6) -- closed and clear: restore fails
		T.eq(reg.faulted, true)
		T.eq(env.core:state(reg.coreId).collidable, false, "the core no longer believes collision is on")
		env.failDriver.setCollision = false
		env.tick(3.9)
		T.eq(reg.faulted, false)
		T.eq(env.last("setCollision").value, false, "resync never restores collision: it re-establishes the safe state")
		env.tick(4.0)
		T.eq(env.last("setCollision").value, false, "no fresh scan yet (the 3.9 scan ran while it was faulted)")
		env.tick(4.15) -- fresh clear scan: held at 0 -> closing (0 s) ...
		env.tick(4.2) -- ... closed, closed pose already confirmed: restore
		T.eq(env.last("setCollision").value, true, "restored through the normal path once closed and clear")
		-- beginEdit: a failed snap raises; the door is not frozen and keeps its record.
		env.input = function() return NEAR end
		env.tick(4.45); env.tick(4.7)
		T.ok(reg.angle > 0, "opening before the failed edit")
		env.failDriver.pose = true
		T.eq(pcall(env.controller.beginEdit, env.controller, model), false, "edit-critical failure raises")
		T.eq(reg.frozen, false)
		T.eq(reg.recordBeforeEdit, nil)
		T.eq(reg.faulted, true)
		T.ok(env.core:state(reg.coreId).phase ~= "closed", "the core is not reset to closed while the leaf is still open")
		env.failDriver.pose = false
		T.eq(env.controller:beginEdit(model), true, "succeeds once the driver works")
		T.eq(env.core:state(reg.coreId).phase, "closed")
	end)

	T.test("edits discard cached scans: a move or rollback within the scan interval waits for a fresh scan at the new pose", function()
		local env = setup()
		local model = {}
		local reg = env.controller:attach(model, "i1", record(nil, 8), false)
		env.input = function() return NEAR end
		env.tick(0) -- opening from a NEAR scan at the old place
		env.controller:beginEdit(model)
		env.controller:moved(model, record(nil, -8))
		env.input = function() return BLOCKED_NEAR end
		env.controller:thaw(model)
		env.tick(0.1) -- inside the scan interval: no fresh scan yet
		T.eq(env.core:state(reg.coreId).phase, "closed", "the old cached NEAR is not reused at the new place")
		env.tick(0.25) -- fresh scan: blocked
		T.eq(env.core:state(reg.coreId).phase, "closed", "blocked at the new place")
		-- Rollback within the interval: also waits.
		env.input = function() return NEAR end
		env.tick(0.5); T.eq(env.core:state(reg.coreId).phase, "opening")
		env.controller:beginEdit(model)
		env.controller:moved(model, record(nil, 24))
		env.controller:cancelEdit(model)
		T.eq(reg.record.z, -8)
		env.tick(0.6)
		T.eq(env.core:state(reg.coreId).phase, "closed", "no reuse of the pre-edit scan after rollback")
		env.tick(0.75)
		T.eq(env.core:state(reg.coreId).phase, "opening", "fresh scan after rollback")
	end)

	T.test("scans never record entries for frozen or faulted doors", function()
		local env = setup()
		local a, b = {}, {}
		local ra = env.controller:attach(a, "i1", record(), false)
		local rb = env.controller:attach(b, "i2", record(nil, -8), true)
		env.sensing.inputs = function()
			return { [ra.coreId] = NEAR, [rb.coreId] = NEAR, ["door#999"] = NEAR }
		end
		env.tick(0)
		T.eq(env.controller.inputs[rb.coreId], nil, "a frozen door's entry is discarded even if sensing returns one")
		T.eq(env.controller.inputs["door#999"], nil)
		T.ok(env.controller.inputs[ra.coreId] ~= nil)
		env.controller:thaw(b)
		env.tick(0.1)
		T.eq(env.core:state(rb.coreId).phase, "closed", "a just-thawed door waits for its own scan")
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

	-- Review of 4e61869, probe 1: the final close must not enable collision before the closed pose succeeds.
	T.test("final close: a failed closed pose keeps collision off; the core is rebased to the real angle; repeated failures stay conservative", function()
		local env = setup()
		local reg = env.controller:attach({}, "i1", record(), false)
		env.input = function() return NEAR end
		env.tick(0); env.tick(0.6)
		env.input = function() return CLEAR end
		env.tick(1); env.tick(3); env.tick(3.3)
		T.ok(near(reg.angle, 45))
		env.failDriver.pose = true
		env.tick(3.6) -- the core finishes closed, but the leaf can't be posed to 0
		T.ok(near(reg.angle, 45), "physical angle unchanged")
		T.eq(env.last("setCollision").value, false, "collision is NOT restored while the leaf is still at 45 degrees")
		T.eq(reg.faulted, true)
		local st = env.core:state(reg.coreId)
		T.eq(st.phase, "held"); T.ok(near(st.progress, 0.5), "core rebased to the applied 45 degrees"); T.eq(st.collidable, false)
		-- Retry fails again: still faulted, still no collision, still at 45.
		env.tick(3.9)
		T.eq(reg.faulted, true)
		local restores = 0
		for _, c in ipairs(env.calls) do
			if c.method == "setCollision" and c.value == true then restores = restores + 1 end
		end
		T.eq(restores, 0, "collision has never been restored while the leaf is open")
		env.failDriver.pose = false
		env.tick(4.2) -- resync: collision off, re-pose to the applied 45 (no motion)
		T.eq(reg.faulted, false)
		T.ok(near(env.last("pose").value, 45), "recovery re-applies the real angle, not the core's earlier target of 0")
		-- A fresh clear scan closes it from 45, and only then is collision restored.
		env.tick(4.5)
		T.eq(env.core:state(reg.coreId).phase, "closing")
		env.tick(4.6); env.tick(4.9)
		T.ok(near(env.last("pose").value, 0))
		T.eq(env.last("setCollision").value, true, "restored after the confirmed closed pose")
	end)

	-- Review of 4e61869, probe 2: recovery must not advance the leaf along an unscanned or blocked path.
	T.test("recovery never advances: a pose fault at 22.5 recovers at 22.5 even though the core had targeted 45; a blocked path keeps it there", function()
		local env = setup()
		local reg = env.controller:attach({}, "i1", record(), false)
		env.input = function() return NEAR end
		env.tick(0); env.tick(0.15)
		T.ok(near(reg.angle, 22.5))
		env.failDriver.pose = true
		env.tick(0.3) -- intended 45, applied 22.5
		T.ok(near(reg.angle, 22.5))
		T.ok(near(env.core:state(reg.coreId).progress, 0.25), "core rebased to 22.5, not the theoretical 45")
		env.input = function() return BLOCKED_NEAR end
		env.failDriver.pose = false
		env.tick(0.4) -- recovery tick
		T.ok(near(env.last("pose").value, 22.5), "no advance from 22.5 on recovery")
		T.eq(reg.faulted, false)
		for t = 1, 6 do env.tick(0.4 + t * 0.25) end
		T.ok(near(env.last("pose").value, 22.5), "blocked at its new scan: stays at 22.5")
		T.eq(env.core:state(reg.coreId).phase, "held")
		env.input = function() return NEAR end
		env.tick(2.25); env.tick(2.75)
		T.ok(near(env.last("pose").value, 90), "opens from 22.5 once a fresh scan shows the path clear")
	end)

	T.test("ordering within a tick: collision off before the first pose of a motion; restore after the confirmed closed pose", function()
		local env = setup()
		local reg = env.controller:attach({}, "i1", record(), false)
		env.input = function() return NEAR end
		env.tick(0)
		env.tick(0.15)
		local firstOff, firstPose
		for i, c in ipairs(env.calls) do
			if c.method == "setCollision" and c.value == false and not firstOff then firstOff = i end
			if c.method == "pose" and not firstPose then firstPose = i end
		end
		T.ok(firstOff and firstPose and firstOff < firstPose, "collision disabled before the leaf moves")
		env.tick(0.6)
		env.input = function() return CLEAR end
		env.tick(1); env.tick(3)
		local mark = #env.calls
		env.tick(3.6) -- closing finishes: pose 0, then restore, in that order
		local seq = {}
		for i = mark + 1, #env.calls do seq[#seq + 1] = env.calls[i].method .. "=" .. tostring(env.calls[i].value) end
		T.deepEq(seq, { "pose=0", "setCollision=true" })
		T.eq(reg.faulted, nil)
	end)

	T.test("collision restore retries fail repeatedly: collision never reported on, door stays faulted and closed until a full recovery", function()
		local env = setup()
		local reg = env.controller:attach({}, "i1", record(), false)
		env.input = function() return NEAR end
		env.tick(0); env.tick(0.6)
		env.input = function() return CLEAR end
		env.tick(1); env.tick(3)
		local failTrue = true
		env.driver.setCollision = function(_, r, on)
			if on and failTrue then error("restore failed") end
			env.calls[#env.calls + 1] = { method = "setCollision", id = r.id, coreId = r.coreId, value = on }
		end
		env.tick(3.6)
		T.eq(reg.faulted, true)
		T.eq(env.core:state(reg.coreId).collidable, false)
		for t = 1, 8 do env.tick(3.6 + t * 0.25) end -- resyncs succeed (collision off), restores keep failing
		T.eq(env.last("setCollision").value, false, "never reported on")
		T.ok(near(reg.angle, 0))
		failTrue = false
		for t = 9, 12 do env.tick(3.6 + t * 0.25) end
		T.eq(env.last("setCollision").value, true, "restored once the driver works")
		T.eq(reg.faulted, false)
	end)

	-- Review of a02d970: a newly blocked or unknown scan must not advance the physical leaf before holding.
	local STOPPERS = {
		{ name = "blocked", set = function(env) env.input = function() return BLOCKED_NEAR end end },
		{ name = "scan raises", set = function(env) env.input = function() error("scan unavailable") end end },
		{ name = "sensing call fails", set = function(env) env.scanError = true end },
		{ name = "missing entry", set = function(env) env.input = function() return nil end end },
		{ name = "malformed entry", set = function(env) env.input = function() return { nearby = true } end end },
		{ name = "extra key", set = function(env) env.input = function() return { nearby = true, occupied = false, blocked = false, x = 1 } end end },
	}
	local function clearAll(env, value)
		env.scanError = false
		env.input = function() return value end
	end

	T.test("opening: a blocked or unknown scan stops the leaf at its last APPLIED angle (no advance), then clear resumes from there", function()
		for _, stopper in ipairs(STOPPERS) do
			local env = setup()
			local reg = env.controller:attach({}, "i1", record(), false)
			env.input = function() return NEAR end
			env.tick(0); env.tick(0.15)
			T.ok(near(reg.angle, 22.5), stopper.name)
			local poses = env.count("pose")
			stopper.set(env)
			env.tick(0.3) -- fresh scan: blocked / unknown
			T.ok(near(reg.angle, 22.5), stopper.name .. ": applied angle stays 22.5, not 45")
			T.eq(env.count("pose"), poses, stopper.name .. ": no pose sent")
			local st = env.core:state(reg.coreId, 0.3)
			T.eq(st.phase, "held", stopper.name)
			T.ok(near(st.progress, 0.25), stopper.name .. ": core rebased to the applied angle")
			for t = 1, 4 do env.tick(0.3 + t * 0.25) end
			T.ok(near(reg.angle, 22.5), stopper.name .. ": stays put while blocked/unknown")
			clearAll(env, NEAR)
			env.tick(1.55)
			local resume = env.core:state(reg.coreId, 1.55)
			T.eq(resume.phase, "opening", stopper.name)
			env.tick(1.7) -- 0.15 s of travel from 0.25 progress
			T.ok(near(reg.angle, 45), stopper.name .. ": resumes from 22.5 (22.5 + 22.5), not from a phantom 45")
			env.tick(2.3)
			T.ok(near(reg.angle, 90), stopper.name .. ": then completes")
		end
	end)

	T.test("closing: a blocked or unknown scan stops the leaf at its last applied angle; clear resumes closing from there", function()
		for _, stopper in ipairs(STOPPERS) do
			local env = setup()
			local reg = env.controller:attach({}, "i1", record(), false)
			env.input = function() return NEAR end
			env.tick(0); env.tick(0.6)
			env.input = function() return CLEAR end
			env.tick(1); env.tick(3) -- closing starts
			env.tick(3.15)
			T.ok(near(reg.angle, 67.5), stopper.name)
			stopper.set(env)
			env.tick(3.3)
			T.ok(near(reg.angle, 67.5), stopper.name .. ": applied angle stays 67.5, not 45")
			T.ok(near(env.core:state(reg.coreId, 3.3).progress, 0.75), stopper.name .. ": core rebased")
			T.eq(env.last("setCollision").value, false, stopper.name .. ": collision stays off")
			clearAll(env, CLEAR)
			env.tick(3.55)
			T.eq(env.core:state(reg.coreId, 3.55).phase, "closing", stopper.name)
			env.tick(3.7)
			T.ok(near(reg.angle, 45), stopper.name .. ": resumes from 67.5")
			env.tick(4.1)
			T.ok(near(reg.angle, 0), stopper.name .. ": closes")
			T.eq(env.last("setCollision").value, true, stopper.name .. ": collision restored after the confirmed close")
		end
	end)

	T.test("long frame gap: a stopper seen after a long gap still leaves the leaf at its last applied angle", function()
		for _, phase in ipairs({ "opening", "closing" }) do
			for _, stopper in ipairs(STOPPERS) do
				local env = setup({ core = { maxDoors = 300, openSeconds = 4, closeSeconds = 4 } })
				local reg = env.controller:attach({}, "i1", record(), false)
				env.input = function() return NEAR end
				env.tick(0)
				local base = 0
				if phase == "closing" then
					env.tick(4)
					env.input = function() return CLEAR end
					env.tick(5); env.tick(7)
					base = 7
				end
				env.tick(base + 0.5)
				local applied = reg.angle
				T.ok(applied > 0 and applied < 90, phase .. "/" .. stopper.name)
				stopper.set(env)
				env.tick(base + 3) -- a 2.5 s frame gap: theoretical progress moved a lot
				T.ok(near(reg.angle, applied), phase .. "/" .. stopper.name .. ": no jump across the gap")
				T.ok(near(env.core:state(reg.coreId).progress * 90, applied), phase .. "/" .. stopper.name .. ": core agrees with the applied angle")
			end
		end
	end)

	T.test("clear paths still move normally, including across a frame gap", function()
		local env = setup()
		local reg = env.controller:attach({}, "i1", record(), false)
		env.input = function() return NEAR end
		env.tick(0)
		env.tick(0.45) -- one long gap with clear input: motion was authorised
		T.ok(near(reg.angle, 67.5))
		env.tick(0.6)
		T.ok(near(reg.angle, 90))
	end)
end
