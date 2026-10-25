--[[
	BuildModel: the authoritative list of placed items in the sandbox.

	Records: { itemId, ownerUserId, x, y, z, yaw }. IDs are "i<n>" (see
	SaveSnapshot.formatBuildId), allocated monotonically and never reused.
	Getters return copies, so callers can never mutate state by accident.
]]

local SaveSnapshot = require(script.Parent.Parent:WaitForChild("Adapters"):WaitForChild("SaveSnapshot"))

local BuildModel = {}
BuildModel.__index = BuildModel

local function copyRecord(r)
	return { itemId = r.itemId, ownerUserId = r.ownerUserId, x = r.x, y = r.y, z = r.z, yaw = r.yaw }
end
BuildModel.copyRecord = copyRecord

function BuildModel.new(maxItems)
	return setmetatable({ items = {}, count = 0, nextId = 1, maxItems = maxItems }, BuildModel)
end

function BuildModel:hasCapacity()
	return self.count < self.maxItems
end

function BuildModel:peekNextId()
	return SaveSnapshot.formatBuildId(self.nextId)
end

function BuildModel:get(id)
	local r = self.items[id]
	return r and copyRecord(r) or nil
end

-- add/set/remove are only called by PlacementCore after validation and a
-- successful world apply, so they assert instead of returning error codes.
function BuildModel:add(id, record)
	assert(self.items[id] == nil, "duplicate build id " .. tostring(id))
	assert(self:hasCapacity(), "item cap exceeded")
	self.items[id] = copyRecord(record)
	self.count = self.count + 1
	local n = SaveSnapshot.parseBuildId(id)
	if n and n >= self.nextId then
		self.nextId = n + 1
	end
end

function BuildModel:set(id, record)
	assert(self.items[id] ~= nil, "unknown build id " .. tostring(id))
	self.items[id] = copyRecord(record)
end

function BuildModel:remove(id)
	assert(self.items[id] ~= nil, "unknown build id " .. tostring(id))
	self.items[id] = nil
	self.count = self.count - 1
end

-- Sorted copies: { { id, record } }
function BuildModel:list()
	local out = {}
	for id, r in pairs(self.items) do
		out[#out + 1] = { id = id, record = copyRecord(r) }
	end
	table.sort(out, function(a, b)
		return SaveSnapshot.parseBuildId(a.id) < SaveSnapshot.parseBuildId(b.id)
	end)
	return out
end

return BuildModel
