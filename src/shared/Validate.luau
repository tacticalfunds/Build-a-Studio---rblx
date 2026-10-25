--[[
	Validate: small type guards for untrusted values (remote payloads, stored
	records, adapter return values). Pure; no Roblox APIs.
]]

local Validate = {}

local HUGE = math.huge

function Validate.isFiniteNumber(v)
	return type(v) == "number" and v == v and v ~= HUGE and v ~= -HUGE
end

function Validate.isInteger(v)
	return Validate.isFiniteNumber(v) and v == math.floor(v)
end

function Validate.isPositiveInteger(v)
	return Validate.isInteger(v) and v >= 1
end

-- Non-empty string no longer than maxLength that fully matches pattern (optional).
function Validate.isBoundedString(v, maxLength, pattern)
	if type(v) ~= "string" or #v == 0 or #v > maxLength then
		return false
	end
	if pattern ~= nil and string.match(v, pattern) == nil then
		return false
	end
	return true
end

-- Returns the length of t if it is a proper sequence (1..n, no other keys) of at
-- most maxLength entries, otherwise nil. Stops counting early on oversized tables.
function Validate.sequenceLength(t, maxLength)
	if type(t) ~= "table" then
		return nil
	end
	local n = 0
	for _ in pairs(t) do
		n = n + 1
		if n > maxLength then
			return nil
		end
	end
	for i = 1, n do
		if t[i] == nil then
			return nil
		end
	end
	return n
end

return Validate
