--[[
	BuildModeHandoff: enters and leaves build mode through injected hooks.

	The live owners (PodcastCamera, the host drawer, host hotkeys, world click
	handlers) expose APIs that have not been inspected yet, so this module never
	calls them directly. Integrations bind one hook per slot:

		hook = { enter = function(context) ... end, exit = function() ... end }

	Slots, entered in this order and exited in reverse:
		camera              PodcastCamera hands the camera to build mode and takes
		                    it back on exit (e.g. via PodcastCameraUI.StudioCameraControl;
		                    signature not yet inspected). The builder never sets
		                    the camera itself.
		hostControls        suppress 1-5, V, F, auto-shot and seat controls. Must
		                    leave E/Q (free-camera vertical), Escape and
		                    right-mouse cursor release working.
		hostDrawer          hide the host drawer, show it again on exit.
		worldClickHandlers  disable existing world item/light click handlers.

	Required slots (default: camera, hostControls) must be bound, otherwise
	enter() refuses, so the builder never fights PodcastCamera for the camera.
	If any enter hook fails, hooks already entered are rolled back. exit() runs
	every exit hook even if some fail, and reports the failures.

	`context` is an opaque table supplied by the builder controller (for
	example the sandbox origin and bounds) and is passed through untouched.
]]

local BuildModeHandoff = {}
BuildModeHandoff.__index = BuildModeHandoff

BuildModeHandoff.SLOTS = { "camera", "hostControls", "hostDrawer", "worldClickHandlers" }
BuildModeHandoff.DEFAULT_REQUIRED = { "camera", "hostControls" }

-- Inputs the hostControls hook suppresses while building (contract, 2026-10-25).
BuildModeHandoff.SUPPRESSED_HOST_INPUTS = { "One", "Two", "Three", "Four", "Five", "V", "F", "AutoShot", "SeatControls" }
-- Inputs that must keep working; the builder must not bind them. Escape is the
-- one the builder may listen to (never sink) to cancel placement.
BuildModeHandoff.PRESERVED_HOST_INPUTS = { "E", "Q", "Escape", "MouseButton2" }
BuildModeHandoff.LISTEN_ONLY_INPUTS = { Escape = true }

local VALID_SLOTS = {}
for _, slot in ipairs(BuildModeHandoff.SLOTS) do
	VALID_SLOTS[slot] = true
end

local function checkHook(slot, hook)
	assert(VALID_SLOTS[slot], "unknown build-mode slot: " .. tostring(slot))
	assert(type(hook) == "table" and type(hook.enter) == "function" and type(hook.exit) == "function", "hook for " .. slot .. " needs enter and exit functions")
end

-- options.hooks: { [slot] = hook } (optional)
-- options.required: list of slots that must be bound (optional)
function BuildModeHandoff.new(options)
	options = options or {}
	local self = setmetatable({
		hooks = {},
		required = options.required or BuildModeHandoff.DEFAULT_REQUIRED,
		entered = {},
		active = false,
	}, BuildModeHandoff)
	for _, slot in ipairs(self.required) do
		assert(VALID_SLOTS[slot], "unknown required slot: " .. tostring(slot))
	end
	if options.hooks then
		for slot, hook in pairs(options.hooks) do
			self:bind(slot, hook)
		end
	end
	return self
end

-- Bind or replace a hook; only allowed while build mode is inactive.
function BuildModeHandoff:bind(slot, hook)
	assert(not self.active, "cannot rebind hooks while build mode is active")
	checkHook(slot, hook)
	self.hooks[slot] = hook
end

-- { [slot] = "bound" | "unbound" }
function BuildModeHandoff:describe()
	local out = {}
	for _, slot in ipairs(BuildModeHandoff.SLOTS) do
		out[slot] = self.hooks[slot] and "bound" or "unbound"
	end
	return out
end

function BuildModeHandoff:isActive()
	return self.active
end

local function runExits(self, slots)
	local failures = {}
	for i = #slots, 1, -1 do
		local slot = slots[i]
		local ok, err = pcall(self.hooks[slot].exit)
		if not ok then
			failures[#failures + 1] = { slot = slot, reason = "ExitFailed", detail = tostring(err) }
		end
	end
	return failures
end

-- Returns ok, failures ({ slot, reason, detail? } list). Idempotent.
function BuildModeHandoff:enter(context)
	if self.active then
		return true, {}
	end
	for _, slot in ipairs(self.required) do
		if self.hooks[slot] == nil then
			return false, { { slot = slot, reason = "Unbound" } }
		end
	end
	local entered = {}
	for _, slot in ipairs(BuildModeHandoff.SLOTS) do
		local hook = self.hooks[slot]
		if hook then
			local ok, err = pcall(hook.enter, context)
			if not ok then
				local failures = { { slot = slot, reason = "EnterFailed", detail = tostring(err) } }
				for _, f in ipairs(runExits(self, entered)) do
					failures[#failures + 1] = f
				end
				return false, failures
			end
			entered[#entered + 1] = slot
		end
	end
	self.entered = entered
	self.active = true
	return true, {}
end

-- Returns ok, failures. Always leaves build mode inactive. Idempotent.
function BuildModeHandoff:exit()
	if not self.active then
		return true, {}
	end
	local entered = self.entered
	self.entered = {}
	self.active = false
	local failures = runExits(self, entered)
	return #failures == 0, failures
end

-- Builder keys that collide with host inputs it must suppress or preserve.
function BuildModeHandoff.conflictingKeys(builderKeys)
	local reserved = {}
	for _, key in ipairs(BuildModeHandoff.SUPPRESSED_HOST_INPUTS) do
		reserved[key] = true
	end
	for _, key in ipairs(BuildModeHandoff.PRESERVED_HOST_INPUTS) do
		if not BuildModeHandoff.LISTEN_ONLY_INPUTS[key] then
			reserved[key] = true
		end
	end
	local conflicts = {}
	for _, key in ipairs(builderKeys) do
		if reserved[key] then
			conflicts[#conflicts + 1] = key
		end
	end
	return conflicts
end

return BuildModeHandoff
