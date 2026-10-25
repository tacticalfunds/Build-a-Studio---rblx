--[[
	Test runner for the pure (Roblox-free) parts of the Studio Builder.

	Run from the repository root:   lua5.4 tests/run.lua

	It emulates just enough of Roblox to load modules: `script`, `script.Parent`,
	`:WaitForChild`, `:FindFirstChild`, `require(<module node>)` and
	`game:GetService(...)`, using the same tree as default.project.json:
		ReplicatedStorage.StudioBuilder                     -> src/shared
		ServerScriptService.StudioBuilder                   -> src/server
		StarterPlayer.StarterPlayerScripts.StudioBuilder    -> src/client
	Anything that needs real Instances (CFrame, Workspace parts, DataStores, UI)
	is NOT exercised here and stays "Studio integration pending".
]]

local ROOT = (arg and arg[0] or ""):match("^(.*)/tests/run%.lua$") or "."

local function readFile(path)
	local f = assert(io.open(path, "rb"))
	local s = f:read("a")
	f:close()
	return s
end

-- File index -------------------------------------------------------------

local files = {} -- "src/shared/Config" -> "src/shared/Config.luau"
local dirs = {}
local sourceList = {}
do
	local p = assert(io.popen('cd "' .. ROOT .. '" && find src -name "*.luau" | sort'))
	for line in p:lines() do
		local rel = line:gsub("^%./", "")
		local base = rel:gsub("%.luau$", ""):gsub("%.server$", ""):gsub("%.client$", "")
		files[base] = rel
		sourceList[#sourceList + 1] = rel
		local d = base:match("^(.*)/[^/]+$")
		while d do
			dirs[d] = true
			d = d:match("^(.*)/[^/]+$")
		end
	end
	p:close()
end

-- Fake instance tree -----------------------------------------------------

local MOUNTS = {
	ReplicatedStorage = { StudioBuilder = "src/shared" },
	ServerScriptService = { StudioBuilder = "src/server" },
	StarterPlayerScripts = { StudioBuilder = "src/client" },
}
local mountParent = { ["src/shared"] = "ReplicatedStorage", ["src/server"] = "ServerScriptService", ["src/client"] = "StarterPlayerScripts" }
local extraChildren = {} -- service name -> { [name] = value } injected by tests

local NodeMT = {}
local nodeCache = {}
local serviceCache = {}

local function pathNode(path)
	if not files[path] and not dirs[path] then
		return nil
	end
	local n = nodeCache[path]
	if not n then
		n = setmetatable({ __path = path }, NodeMT)
		nodeCache[path] = n
	end
	return n
end

local function serviceNode(name)
	local n = serviceCache[name]
	if not n then
		n = setmetatable({ __service = name }, NodeMT)
		serviceCache[name] = n
	end
	return n
end

local function childOf(self, name)
	local service = rawget(self, "__service")
	if service then
		if service == "StarterPlayer" and name == "StarterPlayerScripts" then
			return serviceNode("StarterPlayerScripts")
		end
		local extra = extraChildren[service]
		if extra and extra[name] ~= nil then
			return extra[name]
		end
		local mount = MOUNTS[service] and MOUNTS[service][name]
		return mount and pathNode(mount) or nil
	end
	return pathNode(rawget(self, "__path") .. "/" .. name)
end

local function displayName(self)
	return rawget(self, "__service") or rawget(self, "__path")
end

NodeMT.__index = function(self, key)
	if key == "Name" then
		return rawget(self, "__service") or rawget(self, "__path"):match("([^/]+)$")
	elseif key == "Parent" then
		local path = rawget(self, "__path")
		if not path then
			return nil
		end
		if mountParent[path] then
			return serviceNode(mountParent[path])
		end
		return pathNode(path:match("^(.*)/[^/]+$"))
	elseif key == "FindFirstChild" then
		return function(node, name)
			return childOf(node, name)
		end
	elseif key == "WaitForChild" then
		return function(node, name)
			return childOf(node, name) or error("WaitForChild would hang: " .. name .. " in " .. displayName(node), 2)
		end
	end
	local child = childOf(self, key)
	if child == nil then
		error(tostring(key) .. " is not a valid member of " .. displayName(self), 2)
	end
	return child
end

local fakeGame = {
	GetService = function(_, name)
		return serviceNode(name)
	end,
}

-- Module loading ---------------------------------------------------------

local moduleCache = {}
local G

local function robloxRequire(target)
	local path = type(target) == "table" and rawget(target, "__path")
	if not path or not files[path] then
		error("require target is not a module: " .. tostring(path or target), 2)
	end
	local cached = moduleCache[path]
	if cached ~= nil then
		return cached
	end
	local env = setmetatable({ script = target }, { __index = G })
	local chunk = assert(loadfile(ROOT .. "/" .. files[path], "t", env))
	local result = chunk()
	moduleCache[path] = result
	return result
end

G = setmetatable({ require = robloxRequire, game = fakeGame, warn = function() end }, { __index = _G })

local H = {}
H.ROOT = ROOT
H.sourceList = sourceList
H.readFile = readFile

-- H.load("src/server/Adapters/HostAuthority")
function H.load(path)
	return robloxRequire(pathNode(path) or error("no module " .. path))
end

-- Inject a fake child under a service, e.g. ReplicatedStorage.PodcastSettings.
function H.setServiceChild(service, name, value)
	extraChildren[service] = extraChildren[service] or {}
	extraChildren[service][name] = value
end

-- Assertions ---------------------------------------------------------------

local T = { passed = 0, failed = 0, failures = {}, current = "" }

local function fmt(v)
	if type(v) == "string" then
		return string.format("%q", v)
	end
	return tostring(v)
end

function T.test(name, fn)
	local ok, err = xpcall(fn, debug.traceback)
	if ok then
		T.passed = T.passed + 1
	else
		T.failed = T.failed + 1
		T.failures[#T.failures + 1] = T.current .. " :: " .. name .. "\n    " .. tostring(err)
	end
end

function T.eq(actual, expected, message)
	if actual ~= expected then
		error((message or "values differ") .. ": expected " .. fmt(expected) .. ", got " .. fmt(actual), 2)
	end
end

function T.ok(value, message)
	if not value then
		error(message or "expected a truthy value", 2)
	end
end

function T.deepEq(a, b, message, path)
	path = path or "value"
	if type(a) ~= "table" or type(b) ~= "table" then
		if a ~= b then
			error((message or "tables differ") .. " at " .. path .. ": expected " .. fmt(b) .. ", got " .. fmt(a), 2)
		end
		return
	end
	for k, v in pairs(a) do
		T.deepEq(v, b[k], message, path .. "." .. tostring(k))
	end
	for k in pairs(b) do
		if a[k] == nil then
			error((message or "tables differ") .. " at " .. path .. "." .. tostring(k) .. ": missing", 2)
		end
	end
end

function T.throws(fn, message)
	local ok = pcall(fn)
	if ok then
		error(message or "expected an error", 2)
	end
end

-- Run --------------------------------------------------------------------

local specs = {}
do
	local p = assert(io.popen('cd "' .. ROOT .. '" && ls tests/spec/*.lua | sort'))
	for line in p:lines() do
		specs[#specs + 1] = line
	end
	p:close()
end

for _, spec in ipairs(specs) do
	T.current = spec:match("([^/]+)%.lua$")
	local chunk = assert(loadfile(ROOT .. "/" .. spec))
	local ok, err = xpcall(function()
		chunk()(T, H)
	end, debug.traceback)
	if not ok then
		T.failed = T.failed + 1
		T.failures[#T.failures + 1] = T.current .. " :: (spec crashed)\n    " .. tostring(err)
	end
	print(string.format("%-28s done", T.current))
end

for _, f in ipairs(T.failures) do
	print("FAIL " .. f)
end
print(string.format("\n%d passed, %d failed", T.passed, T.failed))
os.exit(T.failed == 0 and 0 or 1)
