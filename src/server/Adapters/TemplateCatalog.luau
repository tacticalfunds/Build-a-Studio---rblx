--[[
	TemplateCatalog: maps stable catalog IDs to curated templates.

	Pure core: TemplateCatalog.build(catalog, probe) where
		probe(itemId) -> nil                      template not installed
		              -> { size = { x, y, z } }   installed (measured bounds, studs)
		              (raising an error marks the entry invalid)
	Each item ends up "installed", "not_installed" or "invalid". Only installed
	items may be placed; the UI shows the others as disabled "not installed" cards.

	Default live probe: TemplateCatalog.serverStorageProbe() looks for a Model
	named exactly like the item ID in ServerStorage.StudioBuilderTemplates.
	Templates are curated by Codex; nothing is ever loaded from an asset ID, and
	client input only ever selects among these catalog IDs. Test fixtures are
	read only in Studio and only when Config.Dev.UseTestFixtures is true.
	Studio integration pending.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("StudioBuilder")
local Config = require(Shared:WaitForChild("Config"))
local Validate = require(Shared:WaitForChild("Validate"))

local TemplateCatalog = {}
TemplateCatalog.__index = TemplateCatalog

TemplateCatalog.Status = {
	Installed = "installed",
	NotInstalled = "not_installed",
	Invalid = "invalid",
}

local MAX_TEMPLATE_EXTENT = 256

local function cleanSize(size)
	if Validate.sequenceLength(size, 3) ~= 3 then
		return nil
	end
	for i = 1, 3 do
		local v = size[i]
		if not Validate.isFiniteNumber(v) or v <= 0 or v > MAX_TEMPLATE_EXTENT then
			return nil
		end
	end
	return { size[1], size[2], size[3] }
end

function TemplateCatalog.build(catalog, probe)
	assert(type(probe) == "function", "TemplateCatalog.build requires a probe function")
	local Status = TemplateCatalog.Status
	local entries = {}
	for _, item in ipairs(catalog.Items) do
		local ok, result = pcall(probe, item.id)
		local entry
		if not ok then
			entry = { status = Status.Invalid, reason = tostring(result) }
		elseif result == nil then
			entry = { status = Status.NotInstalled }
		else
			local size = type(result) == "table" and cleanSize(result.size) or nil
			if size then
				entry = { status = Status.Installed, size = size }
			else
				entry = { status = Status.Invalid, reason = "bad size" }
			end
		end
		entries[item.id] = entry
	end
	return setmetatable({ catalog = catalog, entries = entries }, TemplateCatalog)
end

function TemplateCatalog:status(itemId)
	local entry = type(itemId) == "string" and self.entries[itemId] or nil
	return entry and entry.status or nil
end

function TemplateCatalog:isInstalled(itemId)
	return self:status(itemId) == TemplateCatalog.Status.Installed
end

-- Copy of the measured size, or nil when not installed.
function TemplateCatalog:getSize(itemId)
	if not self:isInstalled(itemId) then
		return nil
	end
	local s = self.entries[itemId].size
	return { s[1], s[2], s[3] }
end

-- Client-safe drawer listing: IDs, names, tags, status and size only. No
-- Instances, paths, source refs or asset IDs are exposed.
function TemplateCatalog:clientListing()
	local list = {}
	for _, item in ipairs(self.catalog.Items) do
		local tags = {}
		for i, tag in ipairs(item.collections) do
			tags[i] = tag
		end
		list[#list + 1] = {
			id = item.id,
			displayName = item.displayName,
			collections = tags,
			status = self:status(item.id),
			size = self:getSize(item.id),
		}
	end
	return list
end

-- Default live probe (Roblox only; Studio integration pending).
function TemplateCatalog.serverStorageProbe()
	local ServerStorage = game:GetService("ServerStorage")
	local RunService = game:GetService("RunService")
	return function(itemId)
		local folder = ServerStorage:FindFirstChild(Config.TemplateFolderName)
		local template = folder and folder:FindFirstChild(itemId) or nil
		if template == nil and Config.Dev.UseTestFixtures == true and RunService:IsStudio() then
			local fixtures = ServerStorage:FindFirstChild(Config.Dev.TestFixtureFolderName)
			template = fixtures and fixtures:FindFirstChild(itemId) or nil
		end
		if template == nil then
			return nil
		end
		if not template:IsA("Model") then
			error("template is not a Model")
		end
		for _, descendant in ipairs(template:GetDescendants()) do
			if descendant:IsA("LuaSourceContainer") then
				error("template contains scripts")
			end
		end
		local _, size = template:GetBoundingBox()
		return { size = { size.X, size.Y, size.Z } }
	end
end

return TemplateCatalog
