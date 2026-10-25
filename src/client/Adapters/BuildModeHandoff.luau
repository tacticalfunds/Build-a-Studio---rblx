--[[
	BuildModeHandoff: enters and leaves build mode through injected hooks.

	The live owners (PodcastCamera, the host drawer, host hotkeys, world click
	handlers) are reached only through hooks, one per slot:

		hook = { enter = function(context) ... end, exit = function() ... end }

	Slots, entered in this order and exited in reverse:
		camera              PodcastCamera hands the camera to build mode and takes
		                    it back (see PodcastCameraHook). The builder never sets
		                    the camera itself.
		hostControls        suppress 1-5, V, F, auto-shot and seat controls. Must
		                    leave E/Q (free-camera vertical), Escape and
		                    right-mouse cursor release working.
		hostDrawer          hide the host drawer, show it again on exit.
		worldClickHandlers  disable existing world item/light click handlers.

	Required slots (default: camera, hostControls) must be bound, otherwise
	enter() refuses, so the builder never fights PodcastCamera for the camera.

	State machine: inactive -> entering -> active -> exiting -> inactive.
	Hooks may yield. Rules:
	* A hook is recorded as a cleanup handle BEFORE its enter runs, so a hook
	  that applied part of its change and then errored is still exited. Exit
	  hooks must therefore be safe after a partial or failed enter.
	* enter() refuses (reason "Busy") while entering or exiting; it is
	  idempotent while active.
	* exit() during a yielded enter cancels it: it returns ok=true with
	  pending=true, and the entering thread rolls back every attempted hook as
	  soon as the yielded hook returns. Cancellation is checked after every hook.
	* exit() during exiting is a no-op (pending=true).
	* If an exit hook fails, its handle is kept: hasPendingCleanup() is true,
	  enter() refuses ("CleanupPending"), and the next exit() retries only the
	  failed hooks (the hook objects that were entered, even if rebound since).

	`context` is an opaque table supplied by the builder controller and passed
	through untouched. options.onStateChanged(state) is called on every change.
]]

local BuildModeHandoff = {}
BuildModeHandoff.__index = BuildModeHandoff

BuildModeHandoff.SLOTS = { "camera", "hostControls", "hostDrawer", "worldClickHandlers" }
BuildModeHandoff.DEFAULT_REQUIRED = { "camera", "hostControls" }

local INACTIVE, ENTERING, ACTIVE, EXITING = "inactive", "entering", "active", "exiting"
BuildModeHandoff.States = { Inactive = INACTIVE, Entering = ENTERING, Active = ACTIVE, Exiting = EXITING }

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
-- options.onStateChanged: function(state) (optional)
function BuildModeHandoff.new(options)
	options = options or {}
	local self = setmetatable({
		hooks = {},
		required = options.required or BuildModeHandoff.DEFAULT_REQUIRED,
		onStateChanged = options.onStateChanged,
		state = INACTIVE,
		generation = 0,
		handles = {}, -- { slot, hook } entered or attempted and not yet cleaned up, in entry order
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

function BuildModeHandoff:_setState(state)
	self.state = state
	if self.onStateChanged then
		pcall(self.onStateChanged, state)
	end
end

-- Bind or replace a hook; only allowed while inactive. Pending cleanup handles
-- keep the hook they entered with.
function BuildModeHandoff:bind(slot, hook)
	assert(self.state == INACTIVE, "cannot rebind hooks while build mode is " .. self.state)
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

function BuildModeHandoff:getState()
	return self.state
end

function BuildModeHandoff:isActive()
	return self.state == ACTIVE
end

function BuildModeHandoff:hasPendingCleanup()
	return #self.handles > 0
end

-- Runs exit for every handle in reverse order (may yield). Keeps the handles
-- whose exit failed, in entry order. Returns the failures.
function BuildModeHandoff:_cleanup()
	local handles = self.handles
	self.handles = {}
	local failures, kept = {}, {}
	for i = #handles, 1, -1 do
		local handle = handles[i]
		local ok, err = pcall(handle.hook.exit)
		if not ok then
			failures[#failures + 1] = { slot = handle.slot, reason = "ExitFailed", detail = tostring(err) }
			table.insert(kept, 1, handle)
		end
	end
	-- Handles recorded while this cleanup yielded cannot exist (enter refuses
	-- while exiting), so replacing the list is safe.
	self.handles = kept
	return failures
end

local function append(list, items)
	for _, item in ipairs(items) do
		list[#list + 1] = item
	end
	return list
end

-- Returns ok, failures ({ slot?, reason, detail? } list).
function BuildModeHandoff:enter(context)
	if self.state == ACTIVE then
		return true, {}
	end
	if self.state ~= INACTIVE then
		return false, { { reason = "Busy", state = self.state } }
	end
	if #self.handles > 0 then
		return false, { { reason = "CleanupPending" } }
	end
	for _, slot in ipairs(self.required) do
		if self.hooks[slot] == nil then
			return false, { { slot = slot, reason = "Unbound" } }
		end
	end

	self.generation = self.generation + 1
	local generation = self.generation
	self:_setState(ENTERING)

	for _, slot in ipairs(BuildModeHandoff.SLOTS) do
		local hook = self.hooks[slot]
		if hook then
			self.handles[#self.handles + 1] = { slot = slot, hook = hook }
			local ok, err = pcall(hook.enter, context)
			if self.generation ~= generation then
				-- exit() was requested while this hook yielded: roll back everything.
				local failures = append({ { slot = slot, reason = "Cancelled" } }, self:_cleanup())
				self:_setState(INACTIVE)
				return false, failures
			end
			if not ok then
				self:_setState(EXITING)
				local failures = append({ { slot = slot, reason = "EnterFailed", detail = tostring(err) } }, self:_cleanup())
				self:_setState(INACTIVE)
				return false, failures
			end
		end
	end

	self:_setState(ACTIVE)
	return true, {}
end

-- Returns ok, failures, pending. pending=true means cleanup is still running in
-- another thread (a yielded enter being cancelled, or an exit in progress).
-- Also retries pending cleanup when inactive.
function BuildModeHandoff:exit()
	if self.state == ENTERING then
		self.generation = self.generation + 1
		self:_setState(EXITING)
		return true, {}, true
	end
	if self.state == EXITING then
		return true, {}, true
	end
	if self.state == INACTIVE and #self.handles == 0 then
		return true, {}, false
	end
	self.generation = self.generation + 1
	self:_setState(EXITING)
	local failures = self:_cleanup()
	self:_setState(INACTIVE)
	return #failures == 0, failures, false
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
