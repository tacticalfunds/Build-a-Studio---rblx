--[[
	SeatAssignments: the server-authoritative seat-assignment model (task 7
	foundation). Pure and synchronous: no Roblox APIs, no yields. It is NOT
	wired into PlacementCore, the Director, StudioLayout or the panel yet;
	docs/task7-seat-plan.md lists those runtime hooks.

	Four participant slots (1 = Host, 2..4 = Guest 1..3, the live
	Seat1..Seat4) each map to at most one (placed item ID, anchor ID). Only
	catalog items with a valid entry in SeatProfiles.Profiles can be
	assigned; everything else stays decorative.

	deps:
		profiles            SeatProfiles.Profiles-shaped table (invalid entries
		                    are excluded and listed in :profileProblems())
		catalog             optional, for profile validation
		getItem(id)         -> { itemId = catalogId, ... } or nil (the live build)
		isHost(userId)      -> boolean
		hostEpoch()         -> number (PlacementCore's host-session epoch)
		isSlotOccupied(slot)-> boolean; an error or non-boolean counts as occupied
		couchPosesEnabled   optional boolean; Couch profiles are refused until the
		                    live PodcastPoses Lounge-only gate is changed

	Edits take ctx = { userId, epoch } captured by the caller under its lock.
	Every refusal leaves state and revision unchanged.

	Save section (additive, top-level beside Build; Config.SeatSectionKey):
		BuildSeats = { Version = 1, Assignments = {
			{ Slot = 1, ItemId = "i3", Anchor = "Seat" }, ... } }
	Entries that are well formed but can't be active right now (unknown or
	unconfigured profile, missing item, unknown anchor, unsupported pose,
	slot or anchor conflict) are kept as `preserved` with a reason, written
	back by encode(), and promoted by reconcile() once they become valid.
	They are never dropped silently; only an explicit unassign of that slot,
	or a new assignment to it, discards them.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("StudioBuilder")
local Config = require(Shared:WaitForChild("Config"))
local Validate = require(Shared:WaitForChild("Validate"))
local SeatProfiles = require(Shared:WaitForChild("SeatProfiles"))

local SeatAssignments = {}
SeatAssignments.__index = SeatAssignments

SeatAssignments.SECTION_KEY = Config.SeatSectionKey
SeatAssignments.VERSION = Config.SeatSectionVersion

SeatAssignments.Codes = {
	BadRequest = "BadRequest",
	BadSlot = "BadSlot",
	NotHost = "NotHost",
	AuthorityLost = "AuthorityLost",
	StaleRevision = "StaleRevision",
	NotFound = "NotFound",
	NotSeatCapable = "NotSeatCapable",
	UnknownAnchor = "UnknownAnchor",
	UnsupportedPose = "UnsupportedPose",
	AnchorTaken = "AnchorTaken",
	SeatOccupied = "SeatOccupied",
	SeatAssigned = "SeatAssigned",
	NothingAssigned = "NothingAssigned",
	SectionFull = "SectionFull",
	Corrupt = "Corrupt",
	UnsupportedVersion = "UnsupportedVersion",
}
local Codes = SeatAssignments.Codes

-- Why a preserved entry is not active.
SeatAssignments.Reasons = {
	UnknownItem = "UnknownItem",
	UnknownProfile = "UnknownProfile",
	UnknownAnchor = "UnknownAnchor",
	UnsupportedPose = "UnsupportedPose",
	Conflict = "Conflict",
}
local Reasons = SeatAssignments.Reasons

local BUILD_ID_PATTERN = "^i%d+$"

local function isSlot(v)
	return Validate.isInteger(v) and v >= 1 and v <= Config.SeatSlotCount
end

local function isBuildId(v)
	return Validate.isBoundedString(v, Config.MaxBuildIdLength, BUILD_ID_PATTERN)
end

function SeatAssignments.new(deps)
	assert(type(deps) == "table", "SeatAssignments.new requires deps")
	for _, name in ipairs({ "getItem", "isHost", "hostEpoch", "isSlotOccupied" }) do
		assert(type(deps[name]) == "function", "SeatAssignments deps." .. name .. " must be a function")
	end
	local profiles = deps.profiles or SeatProfiles.Profiles
	local problems = SeatProfiles.validate(profiles, deps.catalog)
	local valid = {}
	for catalogId, profile in pairs(profiles) do
		if problems[catalogId] == nil then
			valid[catalogId] = profile
		end
	end
	return setmetatable({
		deps = deps,
		profiles = valid,
		problems = problems,
		active = {}, -- [slot] = { itemId, anchor }
		preserved = {}, -- { { slot, itemId, anchor, reason } }
		revision = 0,
	}, SeatAssignments)
end

function SeatAssignments:profileProblems()
	local out = {}
	for k, v in pairs(self.problems) do
		out[k] = v
	end
	return out
end

-- Seat profile for a catalog item, or nil when it is decorative.
function SeatAssignments:profileFor(catalogId)
	return self.profiles[catalogId]
end

function SeatAssignments:_occupied(slot)
	local ok, value = pcall(self.deps.isSlotOccupied, slot)
	return not (ok and value == false)
end

function SeatAssignments:_authorize(ctx)
	if type(ctx) ~= "table" or not Validate.isPositiveInteger(ctx.userId) or not Validate.isInteger(ctx.epoch) then
		return Codes.BadRequest
	end
	local ok, isHost = pcall(self.deps.isHost, ctx.userId)
	if not ok or isHost ~= true then
		return Codes.NotHost
	end
	local okEpoch, epoch = pcall(self.deps.hostEpoch)
	if not okEpoch or epoch ~= ctx.epoch then
		return Codes.AuthorityLost
	end
	return nil
end

-- Checks that (itemId, anchor) can be a seat now. lookup(id) -> catalogId?
-- Returns nil, or code and the matching preserved reason.
function SeatAssignments:_checkTarget(itemId, anchor, lookup)
	local catalogId = lookup(itemId)
	if catalogId == nil then
		return Codes.NotFound, Reasons.UnknownItem
	end
	local profile = self.profiles[catalogId]
	if profile == nil then
		return Codes.NotSeatCapable, Reasons.UnknownProfile
	end
	if profile.Anchors[anchor] == nil then
		return Codes.UnknownAnchor, Reasons.UnknownAnchor
	end
	local pose = SeatProfiles.PoseProfiles[profile.PoseProfile]
	if pose == nil or (pose.needsLivePosePatch and self.deps.couchPosesEnabled ~= true) then
		return Codes.UnsupportedPose, Reasons.UnsupportedPose
	end
	return nil
end

function SeatAssignments:_liveLookup()
	local getItem = self.deps.getItem
	return function(id)
		local ok, record = pcall(getItem, id)
		if ok and type(record) == "table" and type(record.itemId) == "string" then
			return record.itemId
		end
		return nil
	end
end

local function slotTaking(active, itemId, anchor)
	for slot, a in pairs(active) do
		if a.itemId == itemId and a.anchor == anchor then
			return slot
		end
	end
	return nil
end

local function refuse(code)
	return { ok = false, code = code }
end

function SeatAssignments:_entryCount()
	local n = #self.preserved
	for _ in pairs(self.active) do
		n = n + 1
	end
	return n
end

function SeatAssignments:_dropPreservedFor(slot)
	local kept, dropped = {}, 0
	for _, p in ipairs(self.preserved) do
		if p.slot == slot then
			dropped = dropped + 1
		else
			kept[#kept + 1] = p
		end
	end
	self.preserved = kept
	return dropped
end

-- Assigns slot to (itemId, anchor). expectedRevision is optional.
function SeatAssignments:assign(ctx, slot, itemId, anchor, expectedRevision)
	local authCode = self:_authorize(ctx)
	if authCode then
		return refuse(authCode)
	end
	if not isSlot(slot) then
		return refuse(Codes.BadSlot)
	end
	if expectedRevision ~= nil and expectedRevision ~= self.revision then
		return refuse(Codes.StaleRevision)
	end
	if not isBuildId(itemId) or not SeatProfiles.isAnchorId(anchor) then
		return refuse(Codes.BadRequest)
	end
	local code = self:_checkTarget(itemId, anchor, self:_liveLookup())
	if code then
		return refuse(code)
	end
	local current = self.active[slot]
	if current and current.itemId == itemId and current.anchor == anchor then
		return { ok = true, slot = slot, revision = self.revision, unchanged = true }
	end
	if slotTaking(self.active, itemId, anchor) then
		return refuse(Codes.AnchorTaken)
	end
	-- Moving an occupied seat would carry or strand the seated avatar.
	if self:_occupied(slot) then
		return refuse(Codes.SeatOccupied)
	end
	local preservedForSlot = 0
	for _, p in ipairs(self.preserved) do
		if p.slot == slot then
			preservedForSlot = preservedForSlot + 1
		end
	end
	if current == nil and self:_entryCount() - preservedForSlot + 1 > Config.MaxSeatEntries then
		return refuse(Codes.SectionFull)
	end
	self.active[slot] = { itemId = itemId, anchor = anchor }
	local superseded = self:_dropPreservedFor(slot)
	self.revision = self.revision + 1
	return { ok = true, slot = slot, revision = self.revision, superseded = superseded }
end

-- Clears slot (its active assignment and any preserved entries for it).
function SeatAssignments:unassign(ctx, slot, expectedRevision)
	local authCode = self:_authorize(ctx)
	if authCode then
		return refuse(authCode)
	end
	if not isSlot(slot) then
		return refuse(Codes.BadSlot)
	end
	if expectedRevision ~= nil and expectedRevision ~= self.revision then
		return refuse(Codes.StaleRevision)
	end
	local hasPreserved = false
	for _, p in ipairs(self.preserved) do
		if p.slot == slot then
			hasPreserved = true
		end
	end
	if self.active[slot] == nil and not hasPreserved then
		return refuse(Codes.NothingAssigned)
	end
	if self.active[slot] ~= nil and self:_occupied(slot) then
		return refuse(Codes.SeatOccupied)
	end
	self.active[slot] = nil
	local discarded = self:_dropPreservedFor(slot)
	self.revision = self.revision + 1
	return { ok = true, slot = slot, revision = self.revision, discarded = discarded }
end

function SeatAssignments:slotsForItem(itemId)
	local slots = {}
	for slot = 1, Config.SeatSlotCount do
		local a = self.active[slot]
		if a and a.itemId == itemId then
			slots[#slots + 1] = slot
		end
	end
	return slots
end

local function activeSlots(active)
	local slots = {}
	for slot = 1, Config.SeatSlotCount do
		if active[slot] then
			slots[#slots + 1] = slot
		end
	end
	return slots
end

--[[
	Placement gate for one planned PlacementCore effect (the same shapes the
	world receives: spawn, move, remove, replace). Undo/Redo produce these
	same kinds. Returns ok, code?, slots:
	* spawn: allowed (a new or restored item is never assigned).
	* move (Move, Rotate, Undo/Redo of either): refused with SeatOccupied when
	  an assigned slot on that item is occupied; otherwise allowed, and
	  `slots` lists the seats the runtime must re-anchor after commit.
	* remove (Delete, Undo of Place, Redo of Delete): refused while the item
	  holds any slot (SeatOccupied if occupied, else SeatAssigned); the host
	  unassigns first.
	* replace (build load, load rollback): refused with SeatOccupied when any
	  assigned slot is occupied; otherwise allowed, and the caller commits
	  the loaded seat section (commitLoad) or reconciles.
]]
function SeatAssignments:checkEffect(effect)
	if type(effect) ~= "table" then
		return false, Codes.BadRequest, {}
	end
	local kind = effect.kind
	if kind == "spawn" then
		return true, nil, {}
	end
	local slots
	if kind == "move" or kind == "remove" then
		slots = self:slotsForItem(effect.id)
	elseif kind == "replace" then
		slots = activeSlots(self.active)
	else
		return false, Codes.BadRequest, {}
	end
	for _, slot in ipairs(slots) do
		if self:_occupied(slot) then
			return false, Codes.SeatOccupied, slots
		end
	end
	if kind == "remove" and #slots > 0 then
		return false, Codes.SeatAssigned, slots
	end
	return true, nil, slots
end

-- Re-checks every active assignment against the live build and profiles.
-- Invalid ones become preserved (with a reason); preserved ones that are
-- valid again are promoted when their slot is free, unoccupied and the
-- anchor is untaken. Returns { demoted = {slots}, promoted = {slots} }.
function SeatAssignments:reconcile()
	local lookup = self:_liveLookup()
	local demoted, promoted = {}, {}
	for slot = 1, Config.SeatSlotCount do
		local a = self.active[slot]
		if a then
			local _, reason = self:_checkTarget(a.itemId, a.anchor, lookup)
			if reason then
				self.active[slot] = nil
				self.preserved[#self.preserved + 1] = { slot = slot, itemId = a.itemId, anchor = a.anchor, reason = reason }
				demoted[#demoted + 1] = slot
			end
		end
	end
	local kept = {}
	for _, p in ipairs(self.preserved) do
		local _, reason = self:_checkTarget(p.itemId, p.anchor, lookup)
		if reason == nil and self.active[p.slot] == nil and not slotTaking(self.active, p.itemId, p.anchor) and not self:_occupied(p.slot) then
			self.active[p.slot] = { itemId = p.itemId, anchor = p.anchor }
			promoted[#promoted + 1] = p.slot
		else
			if reason ~= nil then
				p.reason = reason
			elseif self.active[p.slot] ~= nil or slotTaking(self.active, p.itemId, p.anchor) then
				p.reason = Reasons.Conflict
			end
			kept[#kept + 1] = p
		end
	end
	self.preserved = kept
	if #demoted > 0 or #promoted > 0 then
		self.revision = self.revision + 1
	end
	return { demoted = demoted, promoted = promoted }
end

--[[
	Which seat source each slot uses. stageActive is true only while the
	builder studio is the active stage (an integration decision; see the
	plan). Otherwise every slot keeps the live room seat, and assignments are
	kept for later. Builder entries include the approved local anchor offset
	for the runtime adapter to place Seat<slot>.
]]
function SeatAssignments:resolve(stageActive)
	local lookup = self:_liveLookup()
	local out = {}
	for slot = 1, Config.SeatSlotCount do
		local a = self.active[slot]
		local entry = { slot = slot, source = "room" }
		if stageActive and a then
			local catalogId = lookup(a.itemId)
			local profile = catalogId and self.profiles[catalogId]
			local offset = profile and profile.Anchors[a.anchor]
			if offset then
				entry = {
					slot = slot,
					source = "builder",
					itemId = a.itemId,
					anchor = a.anchor,
					catalogId = catalogId,
					poseProfile = profile.PoseProfile,
					offset = { X = offset.X, Y = offset.Y, Z = offset.Z, Yaw = offset.Yaw },
				}
			end
		end
		out[slot] = entry
	end
	return out
end

function SeatAssignments:status()
	local active = {}
	for slot = 1, Config.SeatSlotCount do
		local a = self.active[slot]
		if a then
			active[slot] = { itemId = a.itemId, anchor = a.anchor }
		end
	end
	local preserved = {}
	for i, p in ipairs(self.preserved) do
		preserved[i] = { slot = p.slot, itemId = p.itemId, anchor = p.anchor, reason = p.reason }
	end
	return { revision = self.revision, active = active, preserved = preserved }
end

-- Save section: active entries by slot, then preserved ones in order.
function SeatAssignments:encode()
	local list = {}
	for slot = 1, Config.SeatSlotCount do
		local a = self.active[slot]
		if a then
			list[#list + 1] = { Slot = slot, ItemId = a.itemId, Anchor = a.anchor }
		end
	end
	for _, p in ipairs(self.preserved) do
		list[#list + 1] = { Slot = p.slot, ItemId = p.itemId, Anchor = p.anchor }
	end
	return { Version = SeatAssignments.VERSION, Assignments = list }
end

-- Structural decode. nil (no section) is a legacy build: no assignments.
-- Returns { entries = { {slot, itemId, anchor} }, legacy } or nil, code.
function SeatAssignments.decode(section)
	if section == nil then
		return { entries = {}, legacy = true }
	end
	if type(section) ~= "table" or not Validate.isPositiveInteger(section.Version) then
		return nil, Codes.Corrupt
	end
	if section.Version > SeatAssignments.VERSION then
		return nil, Codes.UnsupportedVersion
	end
	local n = Validate.sequenceLength(section.Assignments, Config.MaxSeatEntries)
	if n == nil then
		return nil, Codes.Corrupt
	end
	local entries = {}
	for i = 1, n do
		local e = section.Assignments[i]
		if type(e) ~= "table" or not isSlot(e.Slot) or not isBuildId(e.ItemId) or not SeatProfiles.isAnchorId(e.Anchor) then
			return nil, Codes.Corrupt
		end
		for key in pairs(e) do
			if key ~= "Slot" and key ~= "ItemId" and key ~= "Anchor" then
				return nil, Codes.Corrupt
			end
		end
		entries[i] = { slot = e.Slot, itemId = e.ItemId, anchor = e.Anchor }
	end
	return { entries = entries, legacy = false }
end

--[[
	Stages a load: decode, then classify every entry against the LOADED build.
	catalogIdFor(id) -> catalogId? answers for the staged build's placeable
	items (preserved build entries are not spawned, so they count as
	missing). The first valid entry for a slot wins; later ones are kept as
	Conflict. Returns staged or nil, code. Nothing changes until commitLoad.
]]
function SeatAssignments:prepareLoad(section, catalogIdFor)
	local decoded, code = SeatAssignments.decode(section)
	if decoded == nil then
		return nil, code
	end
	local lookup = function(id)
		local ok, catalogId = pcall(catalogIdFor, id)
		return ok and type(catalogId) == "string" and catalogId or nil
	end
	local staged = { active = {}, preserved = {}, legacy = decoded.legacy }
	for _, e in ipairs(decoded.entries) do
		local _, reason = self:_checkTarget(e.itemId, e.anchor, lookup)
		if reason == nil and (staged.active[e.slot] ~= nil or slotTaking(staged.active, e.itemId, e.anchor)) then
			reason = Reasons.Conflict
		end
		if reason == nil then
			staged.active[e.slot] = { itemId = e.itemId, anchor = e.anchor }
		else
			staged.preserved[#staged.preserved + 1] = { slot = e.slot, itemId = e.itemId, anchor = e.anchor, reason = reason }
		end
	end
	return staged
end

local function sameTarget(a, b)
	if a == nil or b == nil then
		return a == b
	end
	return a.itemId == b.itemId and a.anchor == b.anchor
end

-- Slots whose seat would move (assignment added, removed or changed) if the
-- staged state were committed, and which of them are occupied now.
function SeatAssignments:changedSlots(staged)
	local changed, occupied = {}, {}
	for slot = 1, Config.SeatSlotCount do
		if not sameTarget(self.active[slot], staged.active[slot]) then
			changed[#changed + 1] = slot
			if self:_occupied(slot) then
				occupied[#occupied + 1] = slot
			end
		end
	end
	return changed, occupied
end

-- Commits a staged load. Refused (state unchanged) when any seat that would
-- move is occupied at commit time.
function SeatAssignments:commitLoad(staged)
	local changed, occupied = self:changedSlots(staged)
	if #occupied > 0 then
		return { ok = false, code = Codes.SeatOccupied, slots = occupied }
	end
	self.active = {}
	for slot, a in pairs(staged.active) do
		self.active[slot] = { itemId = a.itemId, anchor = a.anchor }
	end
	self.preserved = {}
	for i, p in ipairs(staged.preserved) do
		self.preserved[i] = { slot = p.slot, itemId = p.itemId, anchor = p.anchor, reason = p.reason }
	end
	self.revision = self.revision + 1
	return { ok = true, revision = self.revision, changed = changed }
end

return SeatAssignments
