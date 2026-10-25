--[[
	SeatProfiles: which catalog items may act as participant seats (task 7
	foundation). Pure data plus a validator; no Roblox APIs.

	Decorative by default: a catalog item is seat-capable only when it has an
	entry in SeatProfiles.Profiles. The table ships EMPTY. Real anchor
	metadata comes from Codex's inspection of the furniture; nothing here
	guesses avatar offsets.

	Profile shape (one per catalog ID):
		[catalogId] = {
			Version = 1,
			PoseProfile = "Chair" | "Couch",
			Anchors = {
				-- Seat attachment point in the template's local space (studs from
				-- its bottom-centre pivot, yaw in degrees), approved per anchor.
				[anchorId] = { X = 0, Y = 0, Z = 0, Yaw = 0 },
			},
		}

	Slots: 1 = Host, 2..4 = Guest 1..3. These are the live Seat1..Seat4
	(StudioLayout, PodcastSeating) and camera shots Seat1..4 / POV1..4.

	Pose profiles map to the live PodcastPoses modes (server script
	ServerScriptService.PodcastPoses, bb3efa6 snapshot). The live server only
	allows CouchSide/CouchRecline while SceneSet == "Lounge", so the Couch
	profile needs a live PodcastPoses change before it can be offered.
]]

local Shared = script.Parent
local Config = require(Shared:WaitForChild("Config"))
local Validate = require(Shared:WaitForChild("Validate"))

local SeatProfiles = {}

SeatProfiles.VERSION = 1

SeatProfiles.SlotNames = { "Host", "Guest1", "Guest2", "Guest3" }

-- Exactly the modes accepted by the live PodcastPoses server script.
SeatProfiles.LivePoseModes = {
	Natural = true,
	Relaxed = true,
	Lean = true,
	Thinking = true,
	Talking = true,
	CouchSide = true,
	CouchRecline = true,
}

SeatProfiles.PoseProfiles = {
	Chair = { modes = { "Natural", "Relaxed", "Lean", "Thinking", "Talking" } },
	-- Live PodcastPoses refuses the couch modes outside Lounge: gated until patched.
	Couch = { modes = { "Natural", "Relaxed", "Lean", "Thinking", "Talking", "CouchSide", "CouchRecline" }, needsLivePosePatch = true },
}

SeatProfiles.MaxAnchorsPerProfile = 4
SeatProfiles.ANCHOR_PATTERN = "^[%a][%w_]*$"
local MAX_OFFSET = 64

-- Explicitly approved seat-capable catalog items. Empty until real metadata is supplied.
SeatProfiles.Profiles = {}

function SeatProfiles.isAnchorId(v)
	return Validate.isBoundedString(v, Config.MaxSeatAnchorIdLength, SeatProfiles.ANCHOR_PATTERN)
end

local function checkAnchor(anchor)
	if type(anchor) ~= "table" then
		return false
	end
	for key in pairs(anchor) do
		if key ~= "X" and key ~= "Y" and key ~= "Z" and key ~= "Yaw" then
			return false
		end
	end
	for _, key in ipairs({ "X", "Y", "Z" }) do
		local v = anchor[key]
		if not Validate.isFiniteNumber(v) or math.abs(v) > MAX_OFFSET then
			return false
		end
	end
	return Validate.isFiniteNumber(anchor.Yaw) and math.abs(anchor.Yaw) <= 360
end

-- Checks one profile. Returns true or false, reason.
function SeatProfiles.checkProfile(catalogId, profile, catalog)
	if catalog ~= nil and catalog.getItem(catalogId) == nil then
		return false, "UnknownCatalogItem"
	end
	if type(profile) ~= "table" or profile.Version ~= SeatProfiles.VERSION then
		return false, "BadVersion"
	end
	for key in pairs(profile) do
		if key ~= "Version" and key ~= "PoseProfile" and key ~= "Anchors" then
			return false, "UnknownKey"
		end
	end
	if SeatProfiles.PoseProfiles[profile.PoseProfile] == nil then
		return false, "UnknownPoseProfile"
	end
	if type(profile.Anchors) ~= "table" then
		return false, "BadAnchors"
	end
	local n = 0
	for anchorId, anchor in pairs(profile.Anchors) do
		n = n + 1
		if not SeatProfiles.isAnchorId(anchorId) or not checkAnchor(anchor) then
			return false, "BadAnchor"
		end
	end
	if n < 1 or n > SeatProfiles.MaxAnchorsPerProfile then
		return false, "BadAnchors"
	end
	return true
end

-- Validates a whole profile table. Returns { [catalogId] = reason } for every
-- invalid entry (empty table when all are valid).
function SeatProfiles.validate(profiles, catalog)
	local problems = {}
	for catalogId, profile in pairs(profiles) do
		local ok, reason = SeatProfiles.checkProfile(catalogId, profile, catalog)
		if not ok then
			problems[catalogId] = reason
		end
	end
	return problems
end

return SeatProfiles
