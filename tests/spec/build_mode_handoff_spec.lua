return function(T, H)
	local BuildModeHandoff = H.load("src/client/Adapters/BuildModeHandoff")
	local Config = H.load("src/shared/Config")

	-- Records every hook call into log as "slot:enter" / "slot:exit".
	local function recorder(log, failOn)
		local hooks = {}
		for _, slot in ipairs(BuildModeHandoff.SLOTS) do
			hooks[slot] = {
				enter = function(context)
					log[#log + 1] = slot .. ":enter"
					log.context = context
					if failOn == slot .. ":enter" then
						error("enter failed")
					end
				end,
				exit = function()
					log[#log + 1] = slot .. ":exit"
					if failOn == slot .. ":exit" then
						error("exit failed")
					end
				end,
			}
		end
		return hooks
	end

	T.test("refuses to enter while required hooks are unbound", function()
		local h = BuildModeHandoff.new()
		local ok, failures = h:enter({})
		T.eq(ok, false)
		T.eq(failures[1].slot, "camera")
		T.eq(failures[1].reason, "Unbound")
		T.eq(h:isActive(), false)
		local d = h:describe()
		T.eq(d.camera, "unbound")
		T.eq(d.worldClickHandlers, "unbound")
	end)

	T.test("enters in slot order and exits in reverse, passing context through", function()
		local log = {}
		local h = BuildModeHandoff.new({ hooks = recorder(log) })
		local context = { sandboxId = "sandbox_main" }
		T.ok(h:enter(context))
		T.eq(log.context, context)
		T.ok(h:isActive())
		T.ok(h:exit())
		T.eq(table.concat(log, ","), "camera:enter,hostControls:enter,hostDrawer:enter,worldClickHandlers:enter,"
			.. "worldClickHandlers:exit,hostDrawer:exit,hostControls:exit,camera:exit")
		T.eq(h:isActive(), false)
	end)

	T.test("enter and exit are idempotent", function()
		local log = {}
		local h = BuildModeHandoff.new({ hooks = recorder(log) })
		h:enter({})
		h:enter({})
		h:exit()
		h:exit()
		T.eq(#log, 8, "each hook ran exactly once per direction")
	end)

	T.test("a failing enter hook is exited too, then the hooks already entered", function()
		local log = {}
		local h = BuildModeHandoff.new({ hooks = recorder(log, "hostDrawer:enter") })
		local ok, failures = h:enter({})
		T.eq(ok, false)
		T.eq(h:isActive(), false)
		T.eq(failures[1].slot, "hostDrawer")
		T.eq(failures[1].reason, "EnterFailed")
		T.eq(table.concat(log, ","), "camera:enter,hostControls:enter,hostDrawer:enter,hostDrawer:exit,hostControls:exit,camera:exit")
	end)

	T.test("exit runs every hook even when one fails, and reports it", function()
		local log = {}
		local h = BuildModeHandoff.new({ hooks = recorder(log, "hostDrawer:exit") })
		h:enter({})
		local ok, failures = h:exit()
		T.eq(ok, false)
		T.eq(#failures, 1)
		T.eq(failures[1].slot, "hostDrawer")
		T.eq(h:isActive(), false, "build mode is left even after a failed exit hook")
		T.eq(log[#log], "camera:exit", "camera restored last")
	end)

	T.test("optional slots may stay unbound", function()
		local log = {}
		local all = recorder(log)
		local h = BuildModeHandoff.new({ hooks = { camera = all.camera, hostControls = all.hostControls } })
		T.ok(h:enter({}))
		T.ok(h:exit())
		T.eq(table.concat(log, ","), "camera:enter,hostControls:enter,hostControls:exit,camera:exit")
	end)

	T.test("binding is validated and locked while active", function()
		local log = {}
		local h = BuildModeHandoff.new({ hooks = recorder(log) })
		T.throws(function() h:bind("lighting", { enter = print, exit = print }) end, "unknown slot")
		T.throws(function() h:bind("camera", { enter = print }) end, "missing exit")
		T.throws(function() BuildModeHandoff.new({ required = { "nope" } }) end, "unknown required slot")
		h:enter({})
		T.throws(function() h:bind("camera", { enter = print, exit = print }) end, "rebind while active")
		h:exit()
	end)

	T.test("builder keys never collide with suppressed or preserved host inputs", function()
		T.eq(#BuildModeHandoff.conflictingKeys(Config.BuilderKeys), 0)
		local conflicts = BuildModeHandoff.conflictingKeys({ "E", "V", "R", "Escape", "MouseButton2" })
		T.eq(table.concat(conflicts, ","), "E,V,MouseButton2")
	end)
end
