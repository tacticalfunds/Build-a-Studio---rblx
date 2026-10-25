--[[
	RequestValidator: strict shape checks for untrusted BuilderRequest payloads.

	Only plain tables with string keys from Protocol.OpFields are accepted.
	Instances, CFrames, colours, scales, paths or any extra field are rejected
	before any lookup happens. Pure; reads with rawget/pairs only.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("StudioBuilder")
local Config = require(Shared:WaitForChild("Config"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Protocol = require(Shared:WaitForChild("Protocol"))
local Validate = require(Shared:WaitForChild("Validate"))

local SaveSnapshot = require(script.Parent.Parent:WaitForChild("Adapters"):WaitForChild("SaveSnapshot"))

local Codes = Protocol.Codes
local RequestValidator = {}

local MAX_FIELDS = 4
local TRANSFORM_KEYS = { x = true, y = true, z = true, yaw = true }

-- Returns op, or nil and a code. Checks the op and the exact key set.
function RequestValidator.op(payload)
	if type(payload) ~= "table" then
		return nil, Codes.BadRequest
	end
	local op = rawget(payload, "op")
	if type(op) ~= "string" or #op > 16 then
		return nil, Codes.BadRequest
	end
	local fields = rawget(Protocol.OpFields, op)
	if fields == nil then
		return nil, Codes.UnknownOp
	end
	local n = 0
	for key in pairs(payload) do
		n = n + 1
		if n > MAX_FIELDS then
			return nil, Codes.BadRequest
		end
		if key ~= "op" and (type(key) ~= "string" or rawget(fields, key) == nil) then
			return nil, Codes.BadRequest
		end
	end
	for key, required in pairs(fields) do
		if required and rawget(payload, key) == nil then
			return nil, Codes.BadRequest
		end
	end
	return op
end

function RequestValidator.catalogId(v)
	if not Validate.isBoundedString(v, Config.MaxCatalogIdLength, Catalog.ITEM_ID_PATTERN) then
		return nil, Codes.BadRequest
	end
	return v
end

function RequestValidator.buildId(v)
	if SaveSnapshot.parseBuildId(v) == nil then
		return nil, Codes.BadRequest
	end
	return v
end

-- Exactly the keys x, y, z, yaw; values are checked by Transform.sanitize.
function RequestValidator.transformShape(v)
	if type(v) ~= "table" then
		return nil, Codes.BadTransform
	end
	local n = 0
	for key in pairs(v) do
		n = n + 1
		if n > 4 or rawget(TRANSFORM_KEYS, key) == nil then
			return nil, Codes.BadTransform
		end
	end
	if n ~= 4 then
		return nil, Codes.BadTransform
	end
	return v
end

-- Optional revision the client last saw: nil, or a non-negative integer.
-- Returns ok, value.
function RequestValidator.optionalRevision(v)
	if v == nil then
		return true, nil
	end
	if not Validate.isInteger(v) or v < 0 or v > 1000000000 then
		return false
	end
	return true, v
end

-- Optional rotation direction: nil -> 1; otherwise exactly 1 or -1.
function RequestValidator.direction(v)
	if v == nil then
		return 1
	end
	if v == 1 or v == -1 then
		return v
	end
	return nil, Codes.BadRequest
end

return RequestValidator
