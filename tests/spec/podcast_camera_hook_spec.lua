return function(T, H)
	local PodcastCameraHook = H.load("src/client/Adapters/PodcastCameraHook")
	local BuildModeHandoff = H.load("src/client/Adapters/BuildModeHandoff")

	-- Fake StudioCameraControl: records Fire calls as "Action=value".
	local function fake(state, readError)
		local fired = {}
		local hook = PodcastCameraHook.new({
			fire = function(action, value)
				fired[#fired + 1] = action .. "=" .. tostring(value)
			end,
			readState = function()
				if readError then
					error("gui missing")
				end
				return state
			end,
		})
		return hook, fired
	end

	local function cycle(state, readError)
		local hook, fired = fake(state, readError)
		hook.enter({})
		hook.exit()
		return table.concat(fired, ",")
	end

	T.test("enter selects PodcastCamera's free camera (no second camera writer)", function()
		local hook, fired = fake({ SelectedShot = 0, FreeCamera = false, POV = false })
		hook.enter({})
		T.eq(table.concat(fired, ","), "FreeCamera=true")
	end)

	T.test("exit from Wide returns to Wide", function()
		T.eq(cycle({ SelectedShot = 0, FreeCamera = false, POV = false }), "FreeCamera=true,FreeCamera=false")
	end)

	T.test("exit reselects the previous seat shot", function()
		T.eq(cycle({ SelectedShot = 3, FreeCamera = false, POV = false }), "FreeCamera=true,FreeCamera=false,Shot=3")
	end)

	T.test("exit restores POV on the previous seat", function()
		T.eq(cycle({ SelectedShot = 1, FreeCamera = false, POV = true }), "FreeCamera=true,FreeCamera=false,Shot=1,POV=true")
	end)

	T.test("a user already in free camera stays in free camera", function()
		T.eq(cycle({ SelectedShot = -2, FreeCamera = true, POV = false }), "FreeCamera=true")
	end)

	T.test("Walk is not re-entered (it would fire a seat Leave); returns to Wide", function()
		T.eq(cycle({ SelectedShot = -1, FreeCamera = false, POV = false }), "FreeCamera=true,FreeCamera=false")
	end)

	T.test("malformed or unreadable state falls back to Wide", function()
		for _, shot in ipairs({ 7, 2.5, "2", 0 / 0 }) do
			T.eq(cycle({ SelectedShot = shot, FreeCamera = "yes", POV = true }), "FreeCamera=true,FreeCamera=false", tostring(shot))
		end
		T.eq(cycle(nil), "FreeCamera=true,FreeCamera=false", "nil state")
		T.eq(cycle({}, true), "FreeCamera=true,FreeCamera=false", "readState error")
	end)

	T.test("exit without enter does nothing; exit is one-shot", function()
		local hook, fired = fake({ SelectedShot = 2, FreeCamera = false })
		hook.exit()
		T.eq(#fired, 0)
		hook.enter({})
		hook.exit()
		hook.exit()
		T.eq(table.concat(fired, ","), "FreeCamera=true,FreeCamera=false,Shot=2")
	end)

	T.test("works as the camera slot and is rolled back if a later hook fails", function()
		local hook, fired = fake({ SelectedShot = 4, FreeCamera = false })
		local controls = {
			enter = function() error("panel gate missing") end,
			exit = function() end,
		}
		local handoff = BuildModeHandoff.new({ hooks = { camera = hook, hostControls = controls } })
		local ok = handoff:enter({})
		T.eq(ok, false)
		T.eq(table.concat(fired, ","), "FreeCamera=true,FreeCamera=false,Shot=4", "camera restored by rollback")
	end)

	T.test("constructor validates its dependencies", function()
		T.throws(function() PodcastCameraHook.new({ fire = print }) end)
	end)
end
