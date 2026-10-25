--[[
	SaveSnapshot: the versioned Build save payload.

	Verified contract (2026-10-25): StudioPresets entries hold a Director
	snapshot {Version=1, Settings, Fixtures, Items}. The builder adds one
	section beside them, leaving the preset entry and top-level Version at 1:

		Build = {
			Version = 1,
			NextId = 4,
			Items = {
				{ Id = "i1", CatalogId = "cozy_armchair_01",
				  Transform = { X = 0, Y = 0, Z = -4, Yaw = 90 } },
				...
			},
		}

	Transforms are room-relative (studs from the sandbox origin, yaw in
	degrees). Only catalog IDs and bounded numbers are stored: no Instances,
	asset IDs or attribute bags. A preset without a Build section is a legacy
	preset; readFromPreset() reports NoBuild so callers keep legacy behaviour.

	decode() is strict about structure: bad types, non-finite numbers,
	duplicate IDs or too many items fail the whole section, so the caller can
	refuse to save over data it could not read. Sections newer than VERSION
	fail with UnsupportedVersion (never downgraded); older ones run through
	Migrations in order. Entries that are structurally fine but not placeable
	right now (retired item, out of bounds, locked collection) come back in
	`preserved` and are written back by encode(), never silently dropped.

	Internally the builder uses plain entries { id, itemId, x, y, z, yaw }.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("StudioBuilder")
local Config = require(Shared:WaitForChild("Config"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Validate = require(Shared:WaitForChild("Validate"))

local SaveSnapshot = {}

SaveSnapshot.SECTION_KEY = Config.BuildSectionKey
SaveSnapshot.VERSION = Config.BuildSectionVersion

SaveSnapshot.Codes = {
	Corrupt = "Corrupt",
	UnsupportedVersion = "UnsupportedVersion",
	TooLarge = "TooLarge",
	NoBuild = "NoBuild",
}

-- Migrations[n](section) returns a NEW version n+1 section. Empty while only v1 exists.
SaveSnapshot.Migrations = {}

local MAX_ID_NUMBER = 1000000000
local MAX_YAW = 3600

function SaveSnapshot.parseBuildId(id)
	if type(id) ~= "string" or #id < 2 or #id > Config.MaxBuildIdLength then
		return nil
	end
	local digits = string.match(id, "^i([1-9]%d*)$")
	local n = digits and tonumber(digits) or nil
	if n == nil or n > MAX_ID_NUMBER then
		return nil
	end
	return n
end

function SaveSnapshot.formatBuildId(n)
	return string.format("i%d", n)
end

local function copyEntry(e)
	return { id = e.id, itemId = e.itemId, x = e.x, y = e.y, z = e.z, yaw = e.yaw }
end

local function toStored(e)
	return { Id = e.id, CatalogId = e.itemId, Transform = { X = e.x, Y = e.y, Z = e.z, Yaw = e.yaw } }
end

-- Structural check of one stored item. Returns an internal entry and its id number, or nil.
local function checkStored(s)
	if type(s) ~= "table" then
		return nil
	end
	local idNumber = SaveSnapshot.parseBuildId(s.Id)
	if idNumber == nil then
		return nil
	end
	if not Validate.isBoundedString(s.CatalogId, Config.MaxCatalogIdLength, Catalog.ITEM_ID_PATTERN) then
		return nil
	end
	local t = s.Transform
	if type(t) ~= "table" then
		return nil
	end
	local limit = Config.MaxCoordinate
	for _, key in ipairs({ "X", "Y", "Z" }) do
		local v = t[key]
		if not Validate.isFiniteNumber(v) or math.abs(v) > limit then
			return nil
		end
	end
	if not Validate.isFiniteNumber(t.Yaw) or math.abs(t.Yaw) > MAX_YAW then
		return nil
	end
	return { id = s.Id, itemId = s.CatalogId, x = t.X, y = t.Y, z = t.Z, yaw = t.Yaw }, idNumber
end

local function byIdNumber(a, b)
	return SaveSnapshot.parseBuildId(a.Id) < SaveSnapshot.parseBuildId(b.Id)
end

-- build: { nextId = integer, items = { entry }, preserved = { entry }? }
-- Returns the Build section.
function SaveSnapshot.encode(build)
	local items = {}
	for _, e in ipairs(build.items) do
		items[#items + 1] = toStored(e)
	end
	for _, e in ipairs(build.preserved or {}) do
		items[#items + 1] = toStored(e)
	end
	table.sort(items, byIdNumber)
	return { Version = SaveSnapshot.VERSION, NextId = build.nextId, Items = items }
end

local function migrate(section)
	local current = section
	while current.Version < SaveSnapshot.VERSION do
		local step = SaveSnapshot.Migrations[current.Version]
		if step == nil then
			return nil, SaveSnapshot.Codes.UnsupportedVersion
		end
		local ok, upgraded = pcall(step, current)
		if not ok or type(upgraded) ~= "table" or upgraded.Version ~= current.Version + 1 then
			return nil, SaveSnapshot.Codes.Corrupt
		end
		current = upgraded
	end
	return current
end

-- options.classify(entry) -> true when placeable now (optional; default true)
-- options.maxItems (optional; default Config.MaxItems)
-- Returns { nextId, items, preserved } or nil, code.
function SaveSnapshot.decode(section, options)
	local Codes = SaveSnapshot.Codes
	options = options or {}
	if type(section) ~= "table" or not Validate.isPositiveInteger(section.Version) then
		return nil, Codes.Corrupt
	end
	if section.Version > SaveSnapshot.VERSION then
		return nil, Codes.UnsupportedVersion
	end
	local migrated, migrateCode = migrate(section)
	if migrated == nil then
		return nil, migrateCode
	end

	local n = Validate.sequenceLength(migrated.Items, options.maxItems or Config.MaxItems)
	if n == nil then
		return nil, Codes.Corrupt
	end
	local nextId = migrated.NextId
	if not Validate.isPositiveInteger(nextId) or nextId > MAX_ID_NUMBER + 1 then
		return nil, Codes.Corrupt
	end

	local result = { nextId = nextId, items = {}, preserved = {} }
	local seen = {}
	local highest = 0
	for i = 1, n do
		local entry, idNumber = checkStored(migrated.Items[i])
		if entry == nil or seen[entry.id] then
			return nil, Codes.Corrupt
		end
		seen[entry.id] = true
		if idNumber > highest then
			highest = idNumber
		end
		local placeable = true
		if options.classify then
			local ok, verdict = pcall(options.classify, copyEntry(entry))
			placeable = ok and verdict == true
		end
		if placeable then
			result.items[#result.items + 1] = entry
		else
			result.preserved[#result.preserved + 1] = entry
		end
	end
	-- Never hand out an ID that already exists in the section.
	if result.nextId <= highest then
		result.nextId = highest + 1
	end
	return result
end

-- Returns a shallow copy of a Director preset snapshot with the Build section
-- attached. Version, Settings, Fixtures and Items are passed through untouched.
function SaveSnapshot.attachToPreset(presetData, section)
	assert(type(presetData) == "table", "preset snapshot must be a table")
	local copy = {}
	for k, v in pairs(presetData) do
		copy[k] = v
	end
	copy[SaveSnapshot.SECTION_KEY] = section
	return copy
end

-- Reads the Build section out of a preset snapshot. A missing section returns
-- nil, NoBuild (legacy preset); everything else goes through decode().
function SaveSnapshot.readFromPreset(presetData, options)
	if type(presetData) ~= "table" then
		return nil, SaveSnapshot.Codes.Corrupt
	end
	local section = presetData[SaveSnapshot.SECTION_KEY]
	if section == nil then
		return nil, SaveSnapshot.Codes.NoBuild
	end
	return SaveSnapshot.decode(section, options)
end

-- Conservative upper bound of the JSON size in bytes, so the cap can be
-- checked without HttpService.
function SaveSnapshot.estimateBytes(section)
	local bytes = 64
	for _, s in ipairs(section.Items or {}) do
		bytes = bytes + 96 + #tostring(s.Id) + #tostring(s.CatalogId) + 4 * 24
	end
	return bytes
end

function SaveSnapshot.checkSize(section, maxBytes)
	if SaveSnapshot.estimateBytes(section) > (maxBytes or Config.MaxBuildSectionBytes) then
		return false, SaveSnapshot.Codes.TooLarge
	end
	return true
end

return SaveSnapshot
