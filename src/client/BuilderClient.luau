--[[
	BuilderClient: Roblox binding for build mode. All behaviour lives in
	Build/BuildController (tested with fakes); this module only supplies the
	Roblox env and forwards signals. Studio/Play pending.

	API (for the host panel's Studio page; no live function is guessed):
		BuilderClient.configure({
			hooks = { camera = ..., hostControls = ..., hostDrawer = ..., worldClickHandlers = ... },
			panel = {
				getPosition = function() -> x, y end,               -- optional: open where the panel is
				onClosed = function({ x, y, reason, cancelled, cleanupFailed }) end, -- optional
			},
			roomSwitchSignal = RBXScriptSignal?,                    -- optional live room-switch gate
		})
		BuilderClient.open()  -> ok, reason   -- reasons: Unavailable, HandoffUnbound,
		                                     -- HandoffFailed, Cancelled, CleanupPending, Opening
		BuilderClient.close()                 -- Back / Done
		BuilderClient.isOpen()

	Signals (host change, room switch, respawn, input, viewport, focus) are
	connected once when this module loads, before any open can yield.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("StudioBuilder")
local Config = require(Shared:WaitForChild("Config"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Protocol = require(Shared:WaitForChild("Protocol"))

local Build = script.Parent:WaitForChild("Build")
local BuildController = require(Build:WaitForChild("BuildController"))
local BuildInput = require(Build:WaitForChild("BuildInput"))
local BuildDrawer = require(Build:WaitForChild("BuildDrawer"))
local BuildModeHandoff = require(script.Parent:WaitForChild("Adapters"):WaitForChild("BuildModeHandoff"))

local player = Players.LocalPlayer
local GHOST_VALID = Color3.fromRGB(91, 224, 198) -- panel teal
local GHOST_INVALID = Color3.fromRGB(235, 87, 87) -- world-space ghost only

local BuilderClient = {}
local handoff = BuildModeHandoff.new()
local panelCallbacks = {}
local selectionHighlight = nil
local controller -- created below

local function placedFolder()
	return Workspace:FindFirstChild(Config.PlacedItemsFolderName)
end

local function previewTemplate(itemId)
	local folder = Shared:FindFirstChild(Config.PreviewTemplatesFolderName)
	return folder and folder:FindFirstChild(itemId) or nil
end

local function sandboxFrame()
	local folder = placedFolder()
	local origin = folder and folder:GetAttribute("SandboxOrigin")
	local size = folder and folder:GetAttribute("SandboxSize")
	if typeof(origin) ~= "CFrame" or typeof(size) ~= "Vector3" then
		return nil
	end
	return { origin = origin, bounds = { halfX = size.X / 2, halfZ = size.Z / 2, height = size.Y } }
end

local function ray(pointer)
	local camera = Workspace.CurrentCamera
	if pointer.space == "screen" then
		return camera:ScreenPointToRay(pointer.position.X, pointer.position.Y)
	end
	return camera:ViewportPointToRay(pointer.position.X, pointer.position.Y)
end

local function placedModel(id)
	local folder = placedFolder()
	return id and folder and folder:FindFirstChild(id) or nil
end

local env = {
	config = Config,
	catalog = Catalog,
	handoff = handoff,
	messageFor = Protocol.message,
	readSandbox = sandboxFrame,
	previewTemplate = previewTemplate,
	spawn = function(fn)
		task.spawn(fn)
	end,
	wait = function(seconds)
		task.wait(seconds)
	end,
	clock = os.clock,
	textFocused = function()
		return UserInputService:GetFocusedTextBox() ~= nil
	end,
}

function env.request(payload)
	local remotes = Shared:FindFirstChild(Config.RemotesFolderName)
	local remote = remotes and remotes:FindFirstChild(Config.RequestRemoteName)
	if remote == nil then
		return { ok = false, code = Protocol.Codes.Unavailable }
	end
	local ok, response = pcall(remote.InvokeServer, remote, payload)
	if not ok or type(response) ~= "table" then
		return { ok = false, code = Protocol.Codes.Internal }
	end
	return response
end

function env.isHost()
	local settings = ReplicatedStorage:FindFirstChild("PodcastSettings")
	return settings ~= nil and settings:GetAttribute("HostUserId") == player.UserId
end

function env.createDrawer(callbacks)
	return BuildDrawer.new(player:WaitForChild("PlayerGui"), Catalog.getCollectionsSorted(), callbacks, Catalog.StructureFilters)
end

function env.itemSize(itemId)
	local template = previewTemplate(itemId)
	if template == nil then
		return nil
	end
	local _, size = template:GetBoundingBox()
	return { size.X, size.Y, size.Z }
end

function env.createGhost(itemId)
	local template = previewTemplate(itemId)
	local frame = sandboxFrame()
	if template == nil or frame == nil then
		return nil
	end
	local model = template:Clone() -- already inert (sanitized server-side)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Transparency = math.max(part.Transparency, 0.45)
		end
	end
	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 0.7
	highlight.Parent = model
	model.Parent = Workspace.CurrentCamera
	return {
		catalogId = itemId,
		model = model,
		show = function(t, valid)
			model:PivotTo(frame.origin * CFrame.new(t.x, t.y, t.z) * CFrame.Angles(0, math.rad(t.yaw), 0))
			highlight.FillColor = valid and GHOST_VALID or GHOST_INVALID
			highlight.OutlineColor = highlight.FillColor
		end,
		destroy = function()
			model:Destroy()
		end,
	}
end

function env.raycast(pointer, excludeId)
	local frame = sandboxFrame()
	if frame == nil then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = {}
	if controller.ghost and controller.ghost.model then
		exclude[#exclude + 1] = controller.ghost.model
	end
	if player.Character then
		exclude[#exclude + 1] = player.Character
	end
	local moving = placedModel(excludeId)
	if moving then
		exclude[#exclude + 1] = moving
	end
	params.FilterDescendantsInstances = exclude
	local r = ray(pointer)
	local result = Workspace:Raycast(r.Origin, r.Direction * 2000, params)
	if result == nil then
		return nil
	end
	local p = frame.origin:PointToObjectSpace(result.Position)
	return { x = p.X, y = p.Y, z = p.Z, upDot = frame.origin.UpVector:Dot(result.Normal) }
end

function env.pickPlaced(pointer)
	local folder = placedFolder()
	if folder == nil then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { folder }
	local r = ray(pointer)
	local result = Workspace:Raycast(r.Origin, r.Direction * 2000, params)
	local node = result and result.Instance
	while node and node.Parent ~= folder do
		node = node.Parent
	end
	return node and node:GetAttribute(Config.BuildItemIdAttribute) or nil
end

function env.selectedInfo(id)
	local model = placedModel(id)
	local frame = sandboxFrame()
	if model == nil or frame == nil then
		return nil
	end
	local _, yaw = frame.origin:ToObjectSpace(model:GetPivot()):ToOrientation()
	local step = Config.RotationStep
	return { catalogId = model:GetAttribute("BuildCatalogId"), yaw = (math.floor(math.deg(yaw) / step + 0.5) * step) % 360 }
end

function env.mouseLocation()
	return { position = UserInputService:GetMouseLocation(), space = "viewport" }
end

function env.setSelectionHighlight(id)
	local model = placedModel(id)
	if model == nil then
		if selectionHighlight then
			selectionHighlight:Destroy()
			selectionHighlight = nil
		end
		return
	end
	if selectionHighlight == nil then
		selectionHighlight = Instance.new("Highlight")
		selectionHighlight.FillTransparency = 1
		selectionHighlight.OutlineColor = GHOST_VALID
		selectionHighlight.Parent = Workspace.CurrentCamera
	end
	selectionHighlight.Adornee = model
end

env.panel = {
	getPosition = function()
		if panelCallbacks.getPosition then
			return panelCallbacks.getPosition()
		end
		return nil
	end,
	onClosed = function(info)
		if panelCallbacks.onClosed then
			panelCallbacks.onClosed(info)
		end
	end,
}

controller = BuildController.new(env)

-- Signals: bound once, so cancellation works even while open() is yielding.
local function method(input)
	return input.UserInputType == Enum.UserInputType.Touch and "touch" or "mouse"
end

local function keyDown(a, b)
	return UserInputService:IsKeyDown(a) or UserInputService:IsKeyDown(b)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	local keyboard = input.UserInputType == Enum.UserInputType.Keyboard
	local action = BuildInput.classify({
		keyCode = input.KeyCode.Name,
		inputType = input.UserInputType.Name,
		gameProcessed = gameProcessed,
		textFocused = UserInputService:GetFocusedTextBox() ~= nil,
		ctrl = keyboard and keyDown(Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl),
		shift = keyboard and keyDown(Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift),
		alt = keyboard and keyDown(Enum.KeyCode.LeftAlt, Enum.KeyCode.RightAlt),
	})
	if action == "cancel" then
		controller:cancel()
	elseif action == "rotate" or action == "undo" or action == "redo" or action == "delete" then
		controller:onKeyPressed(action, input.KeyCode.Name)
	elseif action == "pointer" then
		local m = method(input)
		local pointer = m == "touch" and { position = Vector2.new(input.Position.X, input.Position.Y), space = "screen" } or env.mouseLocation()
		controller:onPointerPressed(pointer, m, input.Position.X, input.Position.Y)
	end
end)

-- Every key release counts (processed or not), so a hold always ends.
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		controller:onKeyReleased(input.KeyCode.Name)
	end
end)

UserInputService.TextBoxFocused:Connect(function()
	controller:onTextFocused()
end)

UserInputService.InputChanged:Connect(function(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		controller:onPointerMoved(env.mouseLocation(), "mouse")
	elseif input.UserInputType == Enum.UserInputType.Touch and not gameProcessed then
		controller:onPointerMoved({ position = Vector2.new(input.Position.X, input.Position.Y), space = "screen" }, "touch")
	end
end)

UserInputService.WindowFocusReleased:Connect(function()
	controller:onFocusLost()
end)

RunService.RenderStepped:Connect(function()
	controller:tick()
end)

player.CharacterAdded:Connect(function()
	controller:onRespawned()
end)

local function watchCamera(camera)
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			controller:onViewportChanged(camera.ViewportSize.X, camera.ViewportSize.Y)
		end)
	end
end
watchCamera(Workspace.CurrentCamera)
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	watchCamera(Workspace.CurrentCamera)
end)

local function watchSettings(settings)
	settings:GetAttributeChangedSignal("HostUserId"):Connect(function()
		controller:onHostChanged()
	end)
	settings:GetAttributeChangedSignal("SceneSet"):Connect(function()
		controller:onRoomSwitched()
	end)
end
local existingSettings = ReplicatedStorage:FindFirstChild("PodcastSettings")
if existingSettings then
	watchSettings(existingSettings)
else
	ReplicatedStorage.ChildAdded:Connect(function(child)
		if child.Name == "PodcastSettings" then
			watchSettings(child)
		end
	end)
end

local function watchRevision(folder)
	folder:GetAttributeChangedSignal(Config.BuildRevisionAttribute):Connect(function()
		controller:onRevisionChanged(folder:GetAttribute(Config.BuildRevisionAttribute))
	end)
end
if placedFolder() then
	watchRevision(placedFolder())
else
	Workspace.ChildAdded:Connect(function(child)
		if child.Name == Config.PlacedItemsFolderName then
			watchRevision(child)
		end
	end)
end

function BuilderClient.configure(options)
	assert(not controller:isOpen() and not controller:isOpening(), "configure before opening build mode")
	options = options or {}
	for slot, hook in pairs(options.hooks or {}) do
		handoff:bind(slot, hook)
	end
	panelCallbacks = options.panel or {}
	if options.roomSwitchSignal then
		options.roomSwitchSignal:Connect(function()
			controller:onRoomSwitched()
		end)
	end
end

function BuilderClient.open()
	return controller:open()
end

function BuilderClient.close()
	controller:close()
end

function BuilderClient.isOpen()
	return controller:isOpen()
end

return BuilderClient
