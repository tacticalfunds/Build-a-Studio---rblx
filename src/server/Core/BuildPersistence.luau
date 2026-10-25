--[[
	BuildPersistence: the Director-facing API for saving and loading the
	builder's Build section inside existing StudioPresets snapshots (5 slots,
	250000-byte cap, entry Version 1). No separate save profile, no autosave.

	getCore() -> PlacementCore | nil (nil when the builder is disabled here).

	Save:  data = persistence:attachBuild(snapshot())
	       Errors (visible failed save) when the builder can't capture now:
	       Busy, RecoveryNeeded, TooLarge. With the builder disabled the
	       snapshot is returned unchanged and PresetSlotGuard refuses to
	       overwrite a slot whose Build has entries.
	Load:  staged = persistence:prepareLoad(userId, data)   -- before any yield/mutation
	       ... Director's existing text filtering and host check ...
	       token = persistence:commitLoad(userId, staged)  -- before mutating the room
	       ... Director's existing room restore; on error:
	       persistence:revertLoad(userId, token)
	* prepareLoad validates and stages without mutating: Corrupt or newer
	  (UnsupportedVersion) Build sections error, so nothing changes.
	  Unplaceable entries are preserved and written back on the next save.
	  A preset without Build (legacy) leaves the build untouched.
	* commitLoad replaces the build through PlacementCore's exclusive path
	  (lock, host + epoch re-checks after yields, world rollback/recovery). Any
	  failure leaves the build unchanged and errors.
	* revertLoad restores the replaced build if nothing changed since.
	Error messages are player-facing; errors are raised with a position
	prefix so the Director's existing ":%d+: (.+)$" extraction shows them.
]]

local SaveSnapshot = require(script.Parent.Parent:WaitForChild("Adapters"):WaitForChild("SaveSnapshot"))

local BuildPersistence = {}
BuildPersistence.__index = BuildPersistence

BuildPersistence.Messages = {
	Busy = "The builder is still applying a change. Try again in a moment.",
	RecoveryNeeded = "The builder is resynchronizing. Try again in a moment; nothing was changed.",
	TooLarge = "This studio's build is too large to save.",
	Corrupt = "This saved studio's build data can't be read. Nothing was changed.",
	UnsupportedVersion = "This saved studio was made by a newer version and can't be loaded here. Nothing was changed.",
	NotHost = "Host controls changed while loading. Nothing was changed.",
	AuthorityLost = "Host controls changed while loading. Nothing was changed.",
	StaleRevision = "The build changed while loading. Nothing was changed.",
	ApplyFailed = "The build couldn't be applied. Nothing was changed.",
	Unavailable = "The builder isn't available here.",
	Internal = "The build couldn't be processed. Nothing was changed.",
}

function BuildPersistence.new(getCore)
	assert(type(getCore) == "function", "BuildPersistence.new requires getCore")
	return setmetatable({ getCore = getCore }, BuildPersistence)
end

local function fail(code)
	error(BuildPersistence.Messages[code] or BuildPersistence.Messages.Internal, 2)
end

function BuildPersistence:attachBuild(snapshot)
	local core = self.getCore()
	if core == nil then
		return snapshot
	end
	local section, code = core:captureBuild()
	if section == nil then
		fail(code)
	end
	return SaveSnapshot.attachToPreset(snapshot, section)
end

function BuildPersistence:prepareLoad(userId, data)
	if type(data) ~= "table" or data[SaveSnapshot.SECTION_KEY] == nil then
		return { legacy = true }
	end
	local core = self.getCore()
	if core == nil then
		-- Builder disabled in this server: the room loads, the Build section
		-- stays in the preset untouched (and the slot guard protects it).
		return { legacy = true, skipped = true }
	end
	local plan, code = core:prepareLoad(userId, data[SaveSnapshot.SECTION_KEY])
	if plan == nil then
		fail(code)
	end
	return { plan = plan }
end

function BuildPersistence:commitLoad(userId, staged)
	if staged == nil or staged.legacy then
		return nil
	end
	local core = self.getCore()
	if core == nil then
		fail("Unavailable")
	end
	local response = core:loadBuild(userId, staged.plan)
	if not response.ok then
		fail(response.recoveryNeeded and "RecoveryNeeded" or response.code)
	end
	return response.revert
end

-- Returns ok, code. A nil token (legacy load) is a no-op.
function BuildPersistence:revertLoad(userId, token)
	if token == nil then
		return true
	end
	local core = self.getCore()
	if core == nil then
		return false, "Unavailable"
	end
	local response = core:revertLoad(userId, token)
	return response.ok == true, response.code
end

return BuildPersistence
