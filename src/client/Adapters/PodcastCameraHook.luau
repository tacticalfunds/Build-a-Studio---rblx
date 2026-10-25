--[[
	PodcastCameraHook: the `camera` slot for BuildModeHandoff, built on the
	verified PodcastCamera contract (read-only inspection, 2026-10-25):

		PlayerGui.PodcastCameraUI.StudioCameraControl  (BindableEvent, local only)
			control:Fire("FreeCamera", true)   selects free camera (SelectedShot -2)
			control:Fire("FreeCamera", false)  selects Wide (0)
			control:Fire("Shot", 0..4)         0 Wide, 1 Host, 2..4 Guests
			control:Fire("POV", true)          POV on the current positive seat
		Readback attributes on PodcastCameraUI: SelectedShot, FreeCamera, POV.

	Build mode reuses PodcastCamera's own free camera (WASD, Q/E, right-drag
	look), so the builder never adds a second camera CFrame writer. SelectedShot
	< 0 already pauses PodcastSpeakerFollow's automatic cuts. There is no
	BuildMode/ownership API in PodcastCamera yet: shot keys 1-5/V/F still work
	until the hostControls gate exists (see docs/adapters.md).

	On exit the previous view is restored: free camera stays free, a seat shot
	(1..4) is reselected, POV is re-enabled if it was on, and anything else
	(Wide, Walk, unknown) returns to Wide. Walk is deliberately not re-entered,
	because entering Walk fires PodcastSeatRequest("Leave").
]]

local PodcastCameraHook = {}

local function isShot(v)
	return type(v) == "number" and v == math.floor(v) and v >= 1 and v <= 4
end

-- options.fire(action, value)  sends one StudioCameraControl action
-- options.readState() -> { SelectedShot, FreeCamera, POV } (may error; treated as unknown)
-- Returns a hook { enter(context), exit() }.
function PodcastCameraHook.new(options)
	assert(type(options) == "table" and type(options.fire) == "function" and type(options.readState) == "function", "PodcastCameraHook.new requires fire and readState")
	local fire, readState = options.fire, options.readState
	local saved = nil

	local hook = {}

	function hook.enter()
		local ok, state = pcall(readState)
		if not ok or type(state) ~= "table" then
			state = {}
		end
		saved = { selectedShot = state.SelectedShot, freeCamera = state.FreeCamera == true, pov = state.POV == true }
		fire("FreeCamera", true)
	end

	function hook.exit()
		local s = saved
		saved = nil
		if s == nil or s.freeCamera then
			return
		end
		fire("FreeCamera", false) -- back to Wide
		if isShot(s.selectedShot) then
			fire("Shot", s.selectedShot)
			if s.pov then
				fire("POV", true)
			end
		end
	end

	return hook
end

-- Live default (Studio integration pending). Returns nil if the control is
-- missing or not a BindableEvent, so BuildModeHandoff refuses to enter.
function PodcastCameraHook.fromLocalPlayer(timeoutSeconds)
	local Players = game:GetService("Players")
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = playerGui:WaitForChild("PodcastCameraUI", timeoutSeconds or 10)
	local control = gui and gui:FindFirstChild("StudioCameraControl")
	if control == nil or not control:IsA("BindableEvent") then
		return nil
	end
	return PodcastCameraHook.new({
		fire = function(action, value)
			control:Fire(action, value)
		end,
		readState = function()
			return {
				SelectedShot = gui:GetAttribute("SelectedShot"),
				FreeCamera = gui:GetAttribute("FreeCamera"),
				POV = gui:GetAttribute("POV"),
			}
		end,
	})
end

return PodcastCameraHook
