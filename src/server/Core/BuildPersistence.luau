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
	       ... text filtering (yields) and host check ...
	       txn = persistence:begin(userId, staged)          -- holds the builder lock
	       txn:applyBuild(); <room restore>; txn:stillAuthorized()
	       txn:commit()   or, on any failure: <room rollback>; txn:rollback()
	       (integration/DirectorPersistence.luau drives this.)
	* prepareLoad validates and stages without mutating: Corrupt or newer
	  (UnsupportedVersion) Build sections error, so nothing changes.
	  Unplaceable entries are preserved and written back on the next save.
	  A preset without Build (legacy) leaves the build untouched.
	* prepareLoad binds the staged load to the host epoch and build revision;
	  begin() refuses if either moved (A -> B -> A during text filtering).
	* The transaction holds PlacementCore's edit lock across the whole room +
	  build load, so builder edits and saves get Busy until it ends. A failed
	  world rollback leaves the builder in recovery (edits and saves refused).
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

-- Validates and stages a preset's Build section before any yield or
-- mutation, and binds it to the current host session and build revision.
-- Corrupt or newer sections error. Returns staged = { legacy?, plan?, binding? }.
function BuildPersistence:prepareLoad(userId, data)
	local core = self.getCore()
	if core == nil then
		-- Builder disabled here: the room loads; any Build section stays in the preset.
		return { legacy = true, skipped = true }
	end
	if not core:_isHost(userId) then
		fail("NotHost")
	end
	local binding = core:binding()
	if type(data) ~= "table" or data[SaveSnapshot.SECTION_KEY] == nil then
		-- Legacy (room-only): still bound to the host session.
		return { legacy = true, binding = { epoch = binding.epoch } }
	end
	local plan, code = core:prepareLoad(userId, data[SaveSnapshot.SECTION_KEY])
	if plan == nil then
		fail(code)
	end
	return { plan = plan, binding = binding }
end

local LoadTransaction = {}
LoadTransaction.__index = LoadTransaction

-- Starts the compound load: holds the builder's edit lock until commit() or
-- rollback(). Errors (nothing changed) if the host session or build revision
-- moved since prepareLoad. With the builder disabled, returns an inert
-- transaction so the Director code has one shape.
function BuildPersistence:begin(userId, staged)
	local core = self.getCore()
	if core == nil or staged.skipped then
		return setmetatable({ inert = true }, LoadTransaction)
	end
	local txn, code = core:beginTransaction(userId, staged.binding)
	if txn == nil then
		fail(code)
	end
	return setmetatable({ txn = txn, staged = staged }, LoadTransaction)
end

-- Applies the staged build to the world (legacy loads: no-op). Errors on failure;
-- the caller must then call rollback().
function LoadTransaction:applyBuild()
	if self.inert or self.staged.legacy then
		return
	end
	local ok, code = self.txn:applyBuild(self.staged.plan)
	if not ok then
		fail(code)
	end
end

-- Final authority check after yields (host and host session).
function LoadTransaction:stillAuthorized()
	if self.inert then
		return true
	end
	return self.txn:stillAuthorized()
end

-- Returns { ok, buildRevision?, recoveryNeeded? }.
function LoadTransaction:commit()
	if self.inert then
		return { ok = true }
	end
	return self.txn:commit()
end

-- Returns ok (false = the builder is now in recovery and refuses edits/saves).
function LoadTransaction:rollback()
	if self.inert then
		return true
	end
	return self.txn:rollback()
end

return BuildPersistence
