--[[
	BuilderClient: client entry point for build mode. Studio-pending: wiring,
	raycasts and UI are not run outside Roblox; the decisions they rely on live
	in the tested pure modules (BuildSession, PlacementPreview, BuildInput,
	PanelTheme, BuildModeHandoff).

	API (for the host panel's Studio page; no live function is guessed):
		BuilderClient.configure({
			hooks = { camera = ..., hostControls = ..., hostDrawer = ..., worldClickHandlers = ... },
			panel = {
				getPosition = function() -> x, y end,   -- optional: open where the panel is
				onClosed = function({ x, y, reason }) end, -- optional: panel restores/keeps position
			},
			roomSwitchSignal = RBXScriptSignal?,      -- optional live room-switch gate
		})
		BuilderClient.open()  -> ok, reason   -- the Studio page's Build callback
		BuilderClient.close()                 -- Back / Done
		BuilderClient.isOpen()

	Fails closed: open() refuses (reason "HandoffUnbound" / "HandoffFailed")
	unless the required camera and hostControls hooks are bound and enter
	cleanly, and refuses ("Unavailable") until the server has a sandbox.
	Cancel triggers: host change (PodcastSettings.HostUserId), room switch
	(PodcastSettings.SceneSet or the injected signal), respawn. Undo/Redo send
	expectedRevision. RecoveryNeeded pauses edits and polls Status.
	Done currently closes like Back; saving is task 5.
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
local BuildSession = require(Build:WaitForChild("BuildSession"))
local BuildInput = require(Build:WaitForChild("BuildInput"))
local PlacementPreview = require(Build:WaitForChild("PlacementPreview"))
local BuildDrawer = require(Build:WaitForChild("BuildDrawer"))
local BuildModeHandoff = require(script.Parent:WaitForChild("Adapters"):WaitForChild("BuildModeHandoff"))

local player = Players.LocalPlayer
local GHOST_VALID = Color3.fromRGB(91, 224, 198) -- panel teal
local GHOST_INVALID = Color3.fromRGB(235, 87, 87) -- world-space ghost only

local BuilderClient = {}

local handoff = BuildModeHandoff.new()
local panelCallbacks = {}
local roomSwitchSignal = nil
local session = BuildSession.new(Config)
local drawer, ghost, ghostHighlight, selectionHighlight = nil, nil, nil, nil
local connections = {}
local sandbox = nil -- { origin, bounds }
local pointer = nil -- { position = Vector2, space = "viewport" | "screen" }
local lastPreview = nil
local sending = false
local openGeneration = 0

local function connect(signal, fn)
	connections[#connections + 1] = signal:Connect(fn)
end

local function placedFolder()
	return Workspace:FindFirstChild(Config.PlacedItemsFolderName)
end

local function previewTemplate(itemId)
	local folder = Shared:FindFirstChild(Config.PreviewTemplatesFolderName)
	return folder and folder:FindFirstChild(itemId) or nil
end

local function isHost()
	local settings = ReplicatedStorage:FindFirstChild("PodcastSettings")
	return settings ~= nil and settings:GetAttribute("HostUserId") == player.UserId
end

local function readSandbox()
	local folder = placedFolder()
	local origin = folder and folder:GetAttribute("SandboxOrigin")
	local size = folder and folder:GetAttribute("SandboxSize")
	if typeof(origin) ~= "CFrame" or typeof(size) ~= "Vector3" then
		return nil
	end
	return { origin = origin, bounds = { halfX = size.X / 2, halfZ = size.Z / 2, height = size.Y } }
end

local function request(payload)
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

local refresh -- forward declaration

-- Sends one edit; ignores clicks while a request is in flight.
local function send(payload)
	if sending then
		return nil
	end
	sending = true
	local response = request(payload)
	sending = false
	session:applyResponse(payload.op, response)
	if not response.ok and response.code then
		session.message = Protocol.message(response.code)
	end
	refresh()
	return response
end

local function clearGhost()
	if ghost then
		ghost:Destroy()
	end
	ghost, ghostHighlight, lastPreview = nil, nil, nil
end

local function itemSize(itemId)
	local template = previewTemplate(itemId)
	if template == nil then
		return nil
	end
	local _, size = template:GetBoundingBox()
	return { size.X, size.Y, size.Z }
end

local function ensureGhost()
	if ghost or not session.itemId then
		return
	end
	local template = previewTemplate(session.itemId)
	if template == nil then
		return
	end
	ghost = template:Clone() -- already inert (sanitized server-side)
	for _, part in ipairs(ghost:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Transparency = math.max(part.Transparency, 0.45)
		end
	end
	ghostHighlight = Instance.new("Highlight")
	ghostHighlight.FillTransparency = 0.7
	ghostHighlight.Parent = ghost
	ghost.Parent = Workspace.CurrentCamera
end

local function selectedModel()
	local folder = placedFolder()
	return session.selectedId and folder and folder:FindFirstChild(session.selectedId) or nil
end

local function ray(p)
	local camera = Workspace.CurrentCamera
	if p.space == "screen" then
		return camera:ScreenPointToRay(p.position.X, p.position.Y)
	end
	return camera:ViewportPointToRay(p.position.X, p.position.Y)
end

local function updatePreview()
	if not session:isPreviewing() or sandbox == nil then
		clearGhost()
		return
	end
	ensureGhost()
	if ghost == nil or pointer == nil then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { ghost }
	if player.Character then
		exclude[#exclude + 1] = player.Character
	end
	if session.mode == "moving" and selectedModel() then
		exclude[#exclude + 1] = selectedModel()
	end
	params.FilterDescendantsInstances = exclude
	local r = ray(pointer)
	local result = Workspace:Raycast(r.Origin, r.Direction * 2000, params)
	local hit = nil
	if result then
		local p = sandbox.origin:PointToObjectSpace(result.Position)
		hit = { x = p.X, y = p.Y, z = p.Z, upDot = sandbox.origin.UpVector:Dot(result.Normal) }
	end
	local size = itemSize(session.itemId)
	if size == nil then
		return
	end
	lastPreview = PlacementPreview.compute(hit, { size = size, yaw = session.previewYaw, bounds = sandbox.bounds, snap = true, config = Config })
	local t = lastPreview.transform
	if t then
		ghost:PivotTo(sandbox.origin * CFrame.new(t.x, t.y, t.z) * CFrame.Angles(0, math.rad(t.yaw), 0))
	end
	ghostHighlight.FillColor = lastPreview.valid and GHOST_VALID or GHOST_INVALID
	ghostHighlight.OutlineColor = ghostHighlight.FillColor
end

local function confirmPlacement()
	if not session:isPreviewing() or not session:canEdit() then
		return
	end
	if lastPreview == nil or not lastPreview.valid then
		session.message = Protocol.message(lastPreview and lastPreview.code == "OutOfBounds" and "OutOfBounds" or "BadTransform")
		refresh()
		return
	end
	local t = lastPreview.transform
	local transform = { x = t.x, y = t.y, z = t.z, yaw = t.yaw }
	if session.mode == "placing" then
		send({ op = "Place", itemId = session.itemId, transform = transform })
	else
		send({ op = "Move", id = session.selectedId, transform = transform })
	end
end

local function pickPlaced(p)
	local folder = placedFolder()
	if folder == nil then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { folder }
	local r = ray(p)
	local result = Workspace:Raycast(r.Origin, r.Direction * 2000, params)
	local node = result and result.Instance
	while node and node.Parent ~= folder do
		node = node.Parent
	end
	return node and node:GetAttribute(Config.BuildItemIdAttribute) or nil
end

local function currentYaw(model)
	local relative = sandbox.origin:ToObjectSpace(model:GetPivot())
	local _, yaw = relative:ToOrientation()
	local step = Config.RotationStep
	return (math.floor(math.deg(yaw) / step + 0.5) * step) % 360
end

refresh = function()
	if drawer == nil then
		return
	end
	if session.mode ~= "moving" and session.mode ~= "placing" then
		clearGhost()
	end
	local model = selectedModel()
	if selectionHighlight then
		selectionHighlight.Adornee = (session.mode == "selected" or session.mode == "moving") and model or nil
	end
	drawer:setStatus(session.readOnly and "Only the host can build." or (session:isPreviewing() and "Placing: snaps to floors and tabletops." or "Build your studio."))
	drawer:setFooter(session.message or "")
	drawer:refresh(session)
end

local function showFilter(collectionId)
	session:setFilter(collectionId)
	local collection = Catalog.getCollection(session.filter)
	drawer:setFilter(session.filter, collection and collection.displayName)
	local items = {}
	for _, item in ipairs(Catalog.getItemsTagged(session.filter)) do
		local template = previewTemplate(item.id)
		items[#items + 1] = { id = item.id, displayName = item.displayName, installed = template ~= nil, preview = template }
	end
	drawer:setItems(items)
	refresh()
end

local function onInput(input, gameProcessed)
	local action = BuildInput.classify({
		keyCode = input.KeyCode.Name,
		inputType = input.UserInputType.Name,
		gameProcessed = gameProcessed,
		textFocused = UserInputService:GetFocusedTextBox() ~= nil,
	})
	if action == "cancel" then
		session:cancel()
		refresh()
	elseif action == "rotate" then
		if session:rotate() == "request" then
			send({ op = "Rotate", id = session.selectedId })
		end
		refresh()
	elseif action == "pointer" then
		local touch = input.UserInputType == Enum.UserInputType.Touch
		pointer = touch and { position = Vector2.new(input.Position.X, input.Position.Y), space = "screen" } or { position = UserInputService:GetMouseLocation(), space = "viewport" }
		if session:isPreviewing() then
			updatePreview()
			if not touch then
				confirmPlacement() -- touch confirms with "Place here"
			end
		else
			session:select(pickPlaced(pointer))
			refresh()
		end
	end
end

function BuilderClient.configure(options)
	assert(not session:isOpen(), "configure before opening build mode")
	options = options or {}
	for slot, hook in pairs(options.hooks or {}) do
		handoff:bind(slot, hook)
	end
	panelCallbacks = options.panel or {}
	roomSwitchSignal = options.roomSwitchSignal
end

function BuilderClient.isOpen()
	return session:isOpen()
end

-- reason: optional message for the panel (host change, room switch, respawn).
function BuilderClient.close(reason)
	if not session:isOpen() then
		return
	end
	openGeneration = openGeneration + 1
	local x, y = nil, nil
	if drawer then
		x, y = drawer:getPosition()
	end
	session:closed()
	for _, c in ipairs(connections) do
		c:Disconnect()
	end
	connections = {}
	clearGhost()
	if selectionHighlight then
		selectionHighlight:Destroy()
		selectionHighlight = nil
	end
	if drawer then
		drawer:destroy()
		drawer = nil
	end
	handoff:exit()
	if panelCallbacks.onClosed then
		pcall(panelCallbacks.onClosed, { x = x, y = y, reason = type(reason) == "string" and reason or nil })
	end
end

local function exitWith(message)
	BuilderClient.close(message)
end

function BuilderClient.open()
	if session:isOpen() then
		return true
	end
	sandbox = readSandbox()
	if sandbox == nil then
		return false, "Unavailable"
	end
	local entered, failures = handoff:enter({ sandboxOrigin = sandbox.origin, bounds = sandbox.bounds })
	if not entered then
		local reason = failures[1] and failures[1].reason == "Unbound" and "HandoffUnbound" or "HandoffFailed"
		return false, reason
	end

	session:opened(isHost())
	local touchOnly = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	drawer = BuildDrawer.new(player:WaitForChild("PlayerGui"), Catalog.getCollectionsSorted(), {
		onFilter = showFilter,
		onItem = function(itemId)
			session:choose(itemId, previewTemplate(itemId) ~= nil)
			refresh()
		end,
		onUndo = function()
			if session:canEdit() then
				send({ op = "Undo", expectedRevision = session.revision })
			end
		end,
		onRedo = function()
			if session:canEdit() then
				send({ op = "Redo", expectedRevision = session.revision })
			end
		end,
		onBack = function()
			BuilderClient.close()
		end,
		onDone = function()
			BuilderClient.close() -- task 5: save first, stay open with a visible error if it fails
		end,
		onMove = function()
			local model = selectedModel()
			if model then
				session:beginMove(model:GetAttribute("BuildCatalogId"), currentYaw(model))
				refresh()
			end
		end,
		onRotate = function()
			if session:rotate() == "request" then
				send({ op = "Rotate", id = session.selectedId })
			end
		end,
		onDuplicate = function()
			if session:canEdit() and session.selectedId then
				send({ op = "Duplicate", id = session.selectedId })
			end
		end,
		onDelete = function()
			if session:canEdit() and session.selectedId then
				send({ op = "Delete", id = session.selectedId })
			end
		end,
		onPlaceHere = confirmPlacement,
		onCancel = function()
			session:cancel()
			refresh()
		end,
	}, touchOnly)
	if panelCallbacks.getPosition then
		local ok, x, y = pcall(panelCallbacks.getPosition)
		if ok and type(x) == "number" and type(y) == "number" then
			drawer:setPosition(x, y)
		end
	end
	selectionHighlight = Instance.new("Highlight")
	selectionHighlight.FillTransparency = 1
	selectionHighlight.OutlineColor = GHOST_VALID
	selectionHighlight.Parent = Workspace.CurrentCamera

	connect(UserInputService.InputBegan, onInput)
	connect(UserInputService.InputChanged, function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.Touch and not gameProcessed and session:isPreviewing() then
			pointer = { position = Vector2.new(input.Position.X, input.Position.Y), space = "screen" }
		end
	end)
	connect(RunService.RenderStepped, function()
		if session:isPreviewing() and not (UserInputService.TouchEnabled and not UserInputService.MouseEnabled) then
			pointer = { position = UserInputService:GetMouseLocation(), space = "viewport" }
		end
		updatePreview()
	end)
	local settings = ReplicatedStorage:FindFirstChild("PodcastSettings")
	if settings then
		connect(settings:GetAttributeChangedSignal("HostUserId"), function()
			if session:hostChanged(isHost()) then
				exitWith(session.message)
			end
		end)
		connect(settings:GetAttributeChangedSignal("SceneSet"), function()
			session:roomSwitched()
			exitWith(session.message)
		end)
	end
	if roomSwitchSignal then
		connect(roomSwitchSignal, function()
			session:roomSwitched()
			exitWith(session.message)
		end)
	end
	connect(player.CharacterAdded, function()
		session:respawned()
		exitWith(session.message)
	end)
	local folder = placedFolder()
	connect(folder:GetAttributeChangedSignal(Config.BuildRevisionAttribute), function()
		session:revisionChanged(folder:GetAttribute(Config.BuildRevisionAttribute))
		refresh()
	end)
	-- While the server is recovering, poll Status until it reports ready.
	local generation = openGeneration
	task.spawn(function()
		while generation == openGeneration do
			task.wait(2)
			if generation == openGeneration and session.paused then
				session:applyResponse("Status", request({ op = "Status" }))
				refresh()
			end
		end
	end)

	showFilter(session.filter)
	session:applyResponse("Status", request({ op = "Status" }))
	refresh()
	return true
end

return BuilderClient
