--[[
	SaveSnapshot: the versioned Build snapshot payload.

	Separate from StudioPresets (its 5 slots / 250 KB cap are untouched) and
	never written through LayoutRevision. A record looks like:

		{
			schema = "StudioBuilder.Build",
			version = 1,
			nextId = 4,
			items = {
				{ id = "i1", itemId = "cozy_armchair_01", x = 0, y = 0, z = -4, yaw = 90 },
				...
			},
		}

	Coordinates are local to the sandbox origin (studs), yaw in degrees.

	decode() is strict about structure: a non-table record, wrong schema, bad
	types, non-finite numbers, duplicate IDs or too many items all fail, so the
	caller can refuse to save over data it could not read. Records newer than
	VERSION fail with UnsupportedVersion (never downgraded). Older records run
	through Migrations in order.

	Entries that are structurally fine but not placeable right now (retired item,
	out of the current bounds, locked collection) are returned in `preserved`
	and written back by encode(), so they are never silently dropped.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("StudioBuilder")
local Config = require(Shared:WaitForChild("Config"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Validate = require(Shared:WaitForChild("Validate"))

local SaveSnapshot = {}

SaveSnapshot.SCHEMA = Config.SnapshotSchema
SaveSnapshot.VERSION = Config.SnapshotVersion

SaveSnapshot.Codes = {
	Corrupt = "Corrupt",
	WrongSchema = "WrongSchema",
	UnsupportedVersion = "UnsupportedVersion",
	TooLarge = "TooLarge",
}

-- Migrations[n](record) returns a NEW version n+1 record. Empty while only v1 exists.
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

-- Structural check of one stored entry. Returns a clean copy and its id number, or nil.
local function checkEntry(e)
	if type(e) ~= "table" then
		return nil
	end
	local idNumber = SaveSnapshot.parseBuildId(e.id)
	if idNumber == nil then
		return nil
	end
	if not Validate.isBoundedString(e.itemId, Config.MaxCatalogIdLength, Catalog.ITEM_ID_PATTERN) then
		return nil
	end
	local limit = Config.MaxCoordinate
	for _, key in ipairs({ "x", "y", "z" }) do
		local v = e[key]
		if not Validate.isFiniteNumber(v) or math.abs(v) > limit then
			return nil
		end
	end
	if not Validate.isFiniteNumber(e.yaw) or math.abs(e.yaw) > MAX_YAW then
		return nil
	end
	return copyEntry(e), idNumber
end

local function byIdNumber(a, b)
	return SaveSnapshot.parseBuildId(a.id) < SaveSnapshot.parseBuildId(b.id)
end

-- build: { nextId = integer, items = { entry }, preserved = { entry }? }
function SaveSnapshot.encode(build)
	local items = {}
	for _, e in ipairs(build.items) do
		items[#items + 1] = copyEntry(e)
	end
	for _, e in ipairs(build.preserved or {}) do
		items[#items + 1] = copyEntry(e)
	end
	table.sort(items, byIdNumber)
	return {
		schema = SaveSnapshot.SCHEMA,
		version = SaveSnapshot.VERSION,
		nextId = build.nextId,
		items = items,
	}
end

local function migrate(record)
	local current = record
	while current.version < SaveSnapshot.VERSION do
		local step = SaveSnapshot.Migrations[current.version]
		if step == nil then
			return nil, SaveSnapshot.Codes.UnsupportedVersion
		end
		local ok, upgraded = pcall(step, current)
		if not ok or type(upgraded) ~= "table" or upgraded.version ~= current.version + 1 then
			return nil, SaveSnapshot.Codes.Corrupt
		end
		current = upgraded
	end
	return current
end

-- options.classify(entry) -> true when placeable now (optional; default true)
-- options.maxItems (optional; default Config.MaxItems)
-- Returns { nextId, items, preserved } or nil, code.
function SaveSnapshot.decode(raw, options)
	local Codes = SaveSnapshot.Codes
	options = options or {}
	if type(raw) ~= "table" then
		return nil, Codes.Corrupt
	end
	if raw.schema ~= SaveSnapshot.SCHEMA then
		return nil, Codes.WrongSchema
	end
	if not Validate.isPositiveInteger(raw.version) then
		return nil, Codes.Corrupt
	end
	if raw.version > SaveSnapshot.VERSION then
		return nil, Codes.UnsupportedVersion
	end
	local record, migrateCode = migrate(raw)
	if record == nil then
		return nil, migrateCode
	end

	local n = Validate.sequenceLength(record.items, options.maxItems or Config.MaxItems)
	if n == nil then
		return nil, Codes.Corrupt
	end
	local nextId = record.nextId
	if not Validate.isPositiveInteger(nextId) or nextId > MAX_ID_NUMBER + 1 then
		return nil, Codes.Corrupt
	end

	local result = { nextId = nextId, items = {}, preserved = {} }
	local seen = {}
	local highest = 0
	for i = 1, n do
		local entry, idNumber = checkEntry(record.items[i])
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
	-- Never hand out an ID that already exists in the record.
	if result.nextId <= highest then
		result.nextId = highest + 1
	end
	return result
end

-- Conservative upper bound of the serialized size in bytes (JSON-like), so the
-- cap can be checked without HttpService.
function SaveSnapshot.estimateBytes(record)
	local bytes = 96 + #tostring(record.schema)
	for _, e in ipairs(record.items or {}) do
		bytes = bytes + 64 + #tostring(e.id) + #tostring(e.itemId) + 4 * 24
	end
	return bytes
end

function SaveSnapshot.checkSize(record, maxBytes)
	if SaveSnapshot.estimateBytes(record) > (maxBytes or Config.MaxSnapshotBytes) then
		return false, SaveSnapshot.Codes.TooLarge
	end
	return true
end

return SaveSnapshot
