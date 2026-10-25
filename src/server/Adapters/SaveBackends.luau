--[[
	SaveBackends: storage for Build snapshots.

	Contract every backend implements:
		backend.kind               string, e.g. "memory"
		backend:load(userId)       -> record or nil (nil = nothing saved yet);
		                              raises an error on failure
		backend:save(userId, record)  raises an error on failure

	Only the in-memory backend exists so far. It is process-local and lost
	when the server shuts down: NOT persistence. A DataStore backend is planned
	for task 5 and will be documented as untested until Codex verifies it.
]]

local SaveBackends = {}

local function deepCopy(value, depth)
	if type(value) ~= "table" then
		return value
	end
	assert(depth < 8, "record nested too deeply")
	local copy = {}
	for k, v in pairs(value) do
		copy[k] = deepCopy(v, depth + 1)
	end
	return copy
end

function SaveBackends.memory()
	local store = {}
	local backend = { kind = "memory" }
	function backend:load(userId)
		return deepCopy(store[userId], 0)
	end
	function backend:save(userId, record)
		store[userId] = deepCopy(record, 0)
	end
	return backend
end

-- Returns ok, reason. Used at startup to reject a misconfigured backend.
function SaveBackends.check(backend)
	if type(backend) ~= "table" then
		return false, "backend must be a table"
	end
	if type(backend.kind) ~= "string" or #backend.kind == 0 then
		return false, "backend.kind must be a non-empty string"
	end
	if type(backend.load) ~= "function" or type(backend.save) ~= "function" then
		return false, "backend needs load and save functions"
	end
	return true
end

return SaveBackends
