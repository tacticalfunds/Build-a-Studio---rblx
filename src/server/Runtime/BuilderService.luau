--[[
	BuilderService: wires PlacementCore to Roblox. Studio integration pending.

	start():
	1. validates the catalog and probes ServerStorage.StudioBuilderTemplates;
	2. resolves the sandbox from the StudioBuilderSandbox marker part. With no
	   marker the builder stays disabled and every request returns Unavailable.
	   Nothing is created in, or searched for inside, the six rooms;
	3. creates Workspace.StudioBuilderPlacedItems (dedicated; BuildRevision,
	   SandboxOrigin and SandboxSize attributes for the client preview);
	4. publishes sanitized preview copies of installed templates to
	   ReplicatedStorage.StudioBuilder.PreviewTemplates for the client ghost and cards;
	5. creates Remotes.BuilderRequest (RemoteFunction) -> PlacementCore:handle.

	Host authority comes from PodcastSettings.HostUserId, checked on every edit
	and again after the world change. Never touches LayoutRevision.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("StudioBuilder")
local Config = require(Shared:WaitForChild("Config"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Protocol = require(Shared:WaitForChild("Protocol"))

local Server = script.Parent.Parent
local PlacementCore = require(Server:WaitForChild("Core"):WaitForChild("PlacementCore"))
local Adapters = Server:WaitForChild("Adapters")
local HostAuthority = require(Adapters:WaitForChild("HostAuthority"))
local Entitlements = require(Adapters:WaitForChild("Entitlements"))
local TemplateCatalog = require(Adapters:WaitForChild("TemplateCatalog"))
local RoomProvider = require(Adapters:WaitForChild("RoomProvider"))
local PlacedItemsWorld = require(script.Parent:WaitForChild("PlacedItemsWorld"))
local TemplateSanitizer = require(script.Parent:WaitForChild("TemplateSanitizer"))

local BuilderService = {}
local started = false
local core = nil

local function log(message)
	warn("[StudioBuilder] " .. message)
end

local function getOrCreate(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA(className) then
		return existing
	end
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

local function curatedTemplate(itemId)
	local folder = ServerStorage:FindFirstChild(Config.TemplateFolderName)
	local template = folder and folder:FindFirstChild(itemId) or nil
	if template and template:IsA("Model") then
		return template
	end
	return nil
end

local function publishPreviews(templates)
	local folder = getOrCreate(Shared, "Folder", Config.PreviewTemplatesFolderName)
	folder:ClearAllChildren()
	for _, item in ipairs(Catalog.Items) do
		local template = templates:isInstalled(item.id) and curatedTemplate(item.id) or nil
		local clone = template and template:Clone() or nil
		if clone then
			TemplateSanitizer.forPreview(clone)
			clone.Name = item.id
			clone:SetAttribute("BuildCatalogId", item.id)
			clone.Parent = folder
		end
	end
end

function BuilderService.start()
	if started then
		return
	end
	started = true

	local remotes = getOrCreate(Shared, "Folder", Config.RemotesFolderName)
	local request = getOrCreate(remotes, "RemoteFunction", Config.RequestRemoteName)
	request.OnServerInvoke = function()
		return { ok = false, code = Protocol.Codes.Unavailable }
	end

	local catalogOk, errors = Catalog.validate()
	if not catalogOk then
		log("catalog invalid, builder disabled: " .. table.concat(errors, "; "))
		return
	end

	local templates = TemplateCatalog.build(Catalog, TemplateCatalog.serverStorageProbe())
	for _, item in ipairs(Catalog.Items) do
		if not templates:isInstalled(item.id) then
			log(item.id .. " template " .. tostring(templates:status(item.id)) .. "; card shows as not installed")
		end
	end

	local sandbox, reason = RoomProvider.new({ resolve = RoomProvider.markerSource() }):resolve(nil)
	if sandbox == nil then
		log("no sandbox (" .. tostring(reason) .. "): place a " .. Config.SandboxMarkerName .. " part in Workspace; builder disabled")
		return
	end

	local placedFolder = getOrCreate(Workspace, "Folder", Config.PlacedItemsFolderName)
	placedFolder:SetAttribute(Config.BuildRevisionAttribute, 0)
	-- Read by the client preview (advisory only; the server re-validates).
	placedFolder:SetAttribute("SandboxOrigin", sandbox.origin)
	placedFolder:SetAttribute("SandboxSize", Vector3.new(sandbox.bounds.halfX * 2, sandbox.bounds.height, sandbox.bounds.halfZ * 2))
	publishPreviews(templates)

	core = PlacementCore.new({
		config = Config,
		catalog = Catalog,
		templates = {
			isInstalled = function(id)
				return templates:isInstalled(id)
			end,
			getSize = function(id)
				return templates:getSize(id)
			end,
		},
		entitlements = Entitlements.new(),
		authority = HostAuthority.new({ getHostUserId = HostAuthority.podcastSettingsSource() }),
		bounds = sandbox.bounds,
		world = PlacedItemsWorld.new(placedFolder, sandbox.origin, curatedTemplate),
		clock = os.clock,
		log = log,
	})

	request.OnServerInvoke = function(player, payload)
		local ok, response = pcall(core.handle, core, player.UserId, payload)
		if not ok then
			log("request error: " .. tostring(response))
			return { ok = false, code = Protocol.Codes.Internal }
		end
		return response
	end

	Players.PlayerRemoving:Connect(function(player)
		core.limiter:forget(player.UserId)
	end)

	-- If a rollback or finalize failed, edits stay refused (RecoveryNeeded)
	-- until reconciliation succeeds; keep retrying in the background too.
	task.spawn(function()
		while true do
			task.wait(2)
			if core:getState() == "recovery" then
				core:recover()
			end
		end
	end)
end

-- For later tasks (save/load, UI): read-only access to the core, nil when disabled.
function BuilderService.getCore()
	return core
end

return BuilderService
