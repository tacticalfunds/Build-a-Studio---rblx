-- Regression tests for the two BuildModeHandoff bugs found in review of f279ac3:
--  1. a hook that partly applied its change and then errored was never exited;
--  2. exit() during a yielded enter() returned "done", then the resumed enter()
--     set active=true and kept the camera.
-- Yielding hooks are simulated with coroutines (yield across pcall works in
-- both Lua 5.4 and Luau).
return function(T, H)
	local BuildModeHandoff = H.load("src/client/Adapters/BuildModeHandoff")

	-- Hooks that log calls; `behaviour[slot .. ":enter"]` may be "error",
	-- "yield" or "applyThenError"; `behaviour[slot .. ":exit"]` may be
	-- "error", "errorOnce" or "yield".
	local function makeHooks(log, behaviour, world)
		local hooks = {}
		for _, slot in ipairs(BuildModeHandoff.SLOTS) do
			hooks[slot] = {
				enter = function()
					log[#log + 1] = slot .. ":enter"
					local b = behaviour[slot .. ":enter"]
					if b == "yield" then
						coroutine.yield(slot)
					end
					world[slot] = true -- e.g. drawer hidden, camera taken
					if b == "error" or b == "applyThenError" then
						error(slot .. " enter failed")
					end
				end,
				exit = function()
					log[#log + 1] = slot .. ":exit"
					local b = behaviour[slot .. ":exit"]
					if b == "yield" then
						coroutine.yield(slot)
					end
					if b == "error" then
						error(slot .. " exit failed")
					elseif b == "errorOnce" then
						behaviour[slot .. ":exit"] = nil
						error(slot .. " exit failed once")
					end
					world[slot] = nil
				end,
			}
		end
		return hooks
	end

	local function setup(behaviour)
		local log, world = {}, {}
		local h = BuildModeHandoff.new({ hooks = makeHooks(log, behaviour or {}, world) })
		return h, log, world
	end

	local function startEnter(h)
		local results
		local co = coroutine.create(function()
			results = { h:enter({}) }
		end)
		assert(coroutine.resume(co))
		return co, function()
			return results
		end
	end

	local function noneApplied(world)
		for slot in pairs(world) do
			return false, slot
		end
		return true
	end

	T.test("bug 1: a hook that applies its change and then errors is exited", function()
		local h, log, world = setup({ ["hostDrawer:enter"] = "applyThenError" })
		local ok, failures = h:enter({})
		T.eq(ok, false)
		T.eq(failures[1].slot, "hostDrawer")
		T.eq(failures[1].reason, "EnterFailed")
		local clean, leftover = noneApplied(world)
		T.ok(clean, "still applied after failed enter: " .. tostring(leftover))
		T.eq(table.concat(log, ","), "camera:enter,hostControls:enter,hostDrawer:enter,hostDrawer:exit,hostControls:exit,camera:exit")
		T.eq(h:getState(), "inactive")
	end)

	T.test("bug 2: exit during a yielded enter cancels it; camera is not retained", function()
		local h, log, world = setup({ ["camera:enter"] = "yield" })
		local co, results = startEnter(h)
		T.eq(h:getState(), "entering")
		T.eq(h:isActive(), false)

		local ok, failures, pending = h:exit()
		T.eq(ok, true)
		T.eq(#failures, 0)
		T.eq(pending, true, "exit reports that cleanup is deferred to the yielded enter")
		T.eq(h:getState(), "exiting")

		assert(coroutine.resume(co))
		local r = results()
		T.eq(r[1], false, "resumed enter must not succeed")
		T.eq(r[2][1].reason, "Cancelled")
		T.eq(h:isActive(), false)
		T.eq(h:getState(), "inactive")
		T.ok(noneApplied(world), "camera retained after cancelled enter")
		T.eq(table.concat(log, ","), "camera:enter,camera:exit", "later hooks never entered")
	end)

	T.test("cancellation after a yield in a middle hook rolls back everything attempted", function()
		local h, log, world = setup({ ["hostDrawer:enter"] = "yield" })
		local co, results = startEnter(h)
		local _, _, pending = h:exit()
		T.eq(pending, true)
		assert(coroutine.resume(co))
		T.eq(results()[1], false)
		T.ok(noneApplied(world))
		T.eq(table.concat(log, ","), "camera:enter,hostControls:enter,hostDrawer:enter,hostDrawer:exit,hostControls:exit,camera:exit")
	end)

	T.test("enter is serialized: a second enter during a yielded enter or exit is refused", function()
		local h, log = setup({ ["camera:enter"] = "yield" })
		local co, results = startEnter(h)
		local ok, failures = h:enter({})
		T.eq(ok, false)
		T.eq(failures[1].reason, "Busy")
		assert(coroutine.resume(co))
		T.eq(results()[1], true)
		T.eq(h:isActive(), true)
		T.eq(#log, 4, "each hook entered exactly once")

		-- now a yielding exit
		local h2, log2 = setup({ ["camera:exit"] = "yield" })
		h2:enter({})
		local exitCo = coroutine.create(function()
			h2:exit()
		end)
		assert(coroutine.resume(exitCo))
		T.eq(h2:getState(), "exiting")
		local ok2, failures2 = h2:enter({})
		T.eq(ok2, false)
		T.eq(failures2[1].reason, "Busy")
		local _, _, pending = h2:exit()
		T.eq(pending, true, "second exit during a yielded exit is a no-op")
		assert(coroutine.resume(exitCo))
		T.eq(h2:getState(), "inactive")
		local exits = 0
		for _, entry in ipairs(log2) do
			if entry:find(":exit") then
				exits = exits + 1
			end
		end
		T.eq(exits, 4, "each exit hook ran exactly once")
	end)

	T.test("a failed exit keeps its cleanup handle; enter waits until cleanup succeeds", function()
		local h, log, world = setup({ ["hostDrawer:exit"] = "errorOnce" })
		T.ok(h:enter({}))
		local ok, failures = h:exit()
		T.eq(ok, false)
		T.eq(failures[1].slot, "hostDrawer")
		T.eq(h:isActive(), false)
		T.eq(h:hasPendingCleanup(), true)
		T.eq(world.hostDrawer, true, "drawer still hidden")
		T.eq(world.camera, nil, "other hooks still exited")

		local entered, enterFailures = h:enter({})
		T.eq(entered, false)
		T.eq(enterFailures[1].reason, "CleanupPending")

		T.ok(h:exit(), "retry cleans up")
		T.eq(h:hasPendingCleanup(), false)
		T.ok(noneApplied(world))
		T.eq(log[#log], "hostDrawer:exit", "only the failed hook is retried")
		T.ok(h:enter({}), "can enter again after cleanup")
	end)

	T.test("cleanup handles survive rebinding the slot", function()
		local log, world = {}, {}
		local hooks = makeHooks(log, { ["hostDrawer:exit"] = "errorOnce" }, world)
		local h = BuildModeHandoff.new({ hooks = hooks })
		h:enter({})
		h:exit()
		local replacementCalled = false
		h:bind("hostDrawer", {
			enter = function() end,
			exit = function() replacementCalled = true end,
		})
		h:exit()
		T.eq(replacementCalled, false, "retry uses the hook that was entered")
		T.eq(world.hostDrawer, nil)
	end)

	T.test("rollback that yields keeps the handoff busy until it finishes", function()
		local h, _, world = setup({ ["worldClickHandlers:enter"] = "error", ["camera:exit"] = "yield" })
		local co, results = startEnter(h)
		T.eq(h:getState(), "exiting", "rolling back")
		T.eq(h:enter({}), false)
		assert(coroutine.resume(co))
		T.eq(results()[1], false)
		T.eq(h:getState(), "inactive")
		T.ok(noneApplied(world))
	end)

	T.test("state changes are reported in order", function()
		local states = {}
		local log, world = {}, {}
		local h = BuildModeHandoff.new({
			hooks = makeHooks(log, {}, world),
			onStateChanged = function(state) states[#states + 1] = state end,
		})
		h:enter({})
		h:exit()
		T.eq(table.concat(states, ","), "entering,active,exiting,inactive")
	end)
end
