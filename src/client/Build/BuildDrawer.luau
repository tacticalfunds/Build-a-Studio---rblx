--[[
	BuildDrawer: the Build catalog drawer, built only from PanelTheme so it
	matches the live host panel (docs/ui-contract.md). Studio-pending: not run
	outside Roblox.

	Layout (contract positions):
	* title "Build" at (18, 13), shared status line at (18, 39);
	* DRAG TO MOVE handle top right, 30x30 close (= Back) at (right - 48, 12);
	* the five collection filters in the tab row (x 14, y 72, h 34, gap 6),
	  standard/selected button styles;
	* scroll body (x 14, y 119, w - 28, h - 177), rows with 9 px padding:
	  actions (Undo / Redo / Back / Done), selection (Move / Rotate /
	  Duplicate / Delete), placement hint (Place here on touch / Cancel),
	  then catalog cards with ViewportFrames from PreviewTemplates;
	* footer status at (18, bottom - 49), 11 px muted.
	The drawer is draggable by its handle and clamped on-screen.
]]

local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local PanelTheme = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("PanelTheme"))

local BuildDrawer = {}
BuildDrawer.__index = BuildDrawer

local L = PanelTheme.Layout

local function place(instance, parent, position, size)
	instance.Position = position
	instance.Size = size
	instance.Parent = parent
	return instance
end

local function row(parent, order, height)
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(1, 0, 0, height)
	f.LayoutOrder = order
	f.Parent = parent
	return f
end

-- Lays buttons out across a row with the tab gap.
local function buttonRow(parent, order, labels, callbacks)
	local r = row(parent, order, L.tabsHeight)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, L.tabsGap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = r
	local buttons = {}
	local n = #labels
	for i, label in ipairs(labels) do
		local b = PanelTheme.button(label, false)
		b.Size = UDim2.new(1 / n, -L.tabsGap * (n - 1) / n, 1, 0)
		b.LayoutOrder = i
		b.Parent = r
		b.Activated:Connect(callbacks[i])
		buttons[label] = b
	end
	return r, buttons
end

-- callbacks: onFilter(id), onItem(itemId), onUndo, onRedo, onBack, onDone,
--            onMove, onRotate, onDuplicate, onDelete, onPlaceHere, onCancel
-- collections: sorted { id, displayName }
function BuildDrawer.new(playerGui, collections, callbacks, touchOnly)
	local self = setmetatable({ callbacks = callbacks, cards = {}, filterButtons = {} }, BuildDrawer)

	local gui = Instance.new("ScreenGui")
	gui.Name = "StudioBuilderDrawer"
	gui.ResetOnSpawn = PanelTheme.ScreenGui.ResetOnSpawn
	gui.IgnoreGuiInset = PanelTheme.ScreenGui.IgnoreGuiInset
	gui.DisplayOrder = PanelTheme.ScreenGui.DisplayOrder
	self.gui = gui

	local viewport = Workspace.CurrentCamera.ViewportSize
	local fit = PanelTheme.fit(viewport.X, viewport.Y)
	local drawer = PanelTheme.drawer("Drawer")
	drawer.Size = UDim2.fromOffset(fit.width, fit.height)
	drawer.Position = UDim2.fromOffset(fit.x, fit.y)
	drawer.Parent = gui
	self.drawer = drawer

	local title = PanelTheme.label("title", "Build")
	place(title, drawer, UDim2.fromOffset(L.headerX, L.headerY), UDim2.new(1, -170, 0, L.titleHeight))
	self.status = place(PanelTheme.label("status", ""), drawer, UDim2.fromOffset(L.statusX, L.statusY), UDim2.new(1, -36, 0, 16))

	local handle = PanelTheme.label("handle", L.handleText)
	handle.TextXAlignment = Enum.TextXAlignment.Right
	handle.Active = true
	place(handle, drawer, UDim2.new(1, -150, 0, L.closeTop), UDim2.fromOffset(96, L.closeSize))
	self:_makeDraggable(handle)

	-- Close label: confirm against the live panel's close glyph during visual comparison.
	local close = PanelTheme.button("X", false)
	place(close, drawer, UDim2.new(1, -L.closeRightInset, 0, L.closeTop), UDim2.fromOffset(L.closeSize, L.closeSize))
	close.Activated:Connect(callbacks.onBack)

	-- Filter row in the tab position.
	local tabs = Instance.new("Frame")
	tabs.BackgroundTransparency = 1
	place(tabs, drawer, UDim2.fromOffset(L.tabsX, L.tabsY), UDim2.new(1, -L.tabsX * 2, 0, L.tabsHeight))
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, L.tabsGap)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabs
	local n = #collections
	for i, c in ipairs(collections) do
		local b = PanelTheme.button(c.displayName, false)
		b.Size = UDim2.new(1 / n, -L.tabsGap * (n - 1) / n, 1, 0)
		b.LayoutOrder = i
		b.Parent = tabs
		b.Activated:Connect(function()
			callbacks.onFilter(c.id)
		end)
		self.filterButtons[c.id] = b
	end

	local body = Instance.new("ScrollingFrame")
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = L.scrollBarThickness
	body.ScrollBarImageColor3 = PanelTheme.color("teal")
	body.CanvasSize = UDim2.new()
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	place(body, drawer, UDim2.fromOffset(L.bodyX, L.bodyY), UDim2.new(1, -L.bodyWidthInset, 1, -L.bodyHeightInset))
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, L.rowPadding)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = body
	local padding = Instance.new("UIPadding")
	padding.PaddingRight = UDim.new(0, L.rowPaddingRight)
	padding.PaddingBottom = UDim.new(0, L.rowPaddingBottom)
	padding.Parent = body
	self.body = body

	local _, actions = buttonRow(body, 1, { "Undo", "Redo", "Back", "Done" }, { callbacks.onUndo, callbacks.onRedo, callbacks.onBack, callbacks.onDone })
	self.actions = actions

	local selection
	self.selectionRow, selection = buttonRow(body, 2, { "Move", "Rotate", "Duplicate", "Delete" }, { callbacks.onMove, callbacks.onRotate, callbacks.onDuplicate, callbacks.onDelete })
	self.selectionButtons = selection

	local hint = row(body, 3, 54)
	place(PanelTheme.label("description", touchOnly and "Tap a surface to preview, then Place here." or "Click a surface to place. R rotates, Esc cancels."), hint, UDim2.new(), UDim2.new(1, 0, 0, 16))
	local hintButtons = row(hint, 1, L.tabsHeight)
	hintButtons.Position = UDim2.fromOffset(0, 20)
	local hintLayout = Instance.new("UIListLayout")
	hintLayout.FillDirection = Enum.FillDirection.Horizontal
	hintLayout.Padding = UDim.new(0, L.tabsGap)
	hintLayout.Parent = hintButtons
	if touchOnly then
		local placeHere = PanelTheme.button("Place here", true)
		placeHere.Size = UDim2.new(0.5, -L.tabsGap / 2, 1, 0)
		placeHere.Parent = hintButtons
		placeHere.Activated:Connect(callbacks.onPlaceHere)
	end
	local cancel = PanelTheme.button("Cancel", false)
	cancel.Size = UDim2.new(0.5, -L.tabsGap / 2, 1, 0)
	cancel.Parent = hintButtons
	cancel.Activated:Connect(callbacks.onCancel)
	self.hintRow = hint

	local heading = row(body, 4, 34)
	self.collectionHeading = place(PanelTheme.label("heading", ""), heading, UDim2.new(), UDim2.new(1, 0, 0, 16))
	place(PanelTheme.label("description", "Choose an item, then a floor or tabletop."), heading, UDim2.fromOffset(0, 18), UDim2.new(1, 0, 0, 14))

	self.footer = place(PanelTheme.label("status", ""), drawer, UDim2.new(0, L.footerX, 1, -L.footerBottomInset), UDim2.new(1, -L.footerX * 2, 0, L.footerHeight))

	gui.Parent = playerGui
	return self
end

function BuildDrawer:_makeDraggable(handle)
	local dragging, startInput, startPosition = false, nil, nil
	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, startInput, startPosition = true, input.Position, self.drawer.AbsolutePosition
		end
	end)
	handle.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	self.dragConnection = UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - startInput
			self:setPosition(startPosition.X + delta.X, startPosition.Y + delta.Y)
		end
	end)
end

function BuildDrawer:setPosition(x, y)
	local viewport = Workspace.CurrentCamera.ViewportSize
	local size = self.drawer.AbsoluteSize
	local cx, cy = PanelTheme.clamp(x, y, size.X, size.Y, viewport.X, viewport.Y)
	self.drawer.Position = UDim2.fromOffset(cx, cy)
end

function BuildDrawer:getPosition()
	local p = self.drawer.AbsolutePosition
	return p.X, p.Y
end

function BuildDrawer:setStatus(text)
	self.status.Text = text or ""
end

function BuildDrawer:setFooter(text)
	self.footer.Text = text or ""
end

function BuildDrawer:setFilter(collectionId, displayName)
	for id, b in pairs(self.filterButtons) do
		PanelTheme.setSelected(b, id == collectionId)
	end
	self.collectionHeading.Text = displayName or ""
end

local function setEnabled(button, enabled)
	button.AutoButtonColor = enabled
	button.Active = enabled
	button.TextColor3 = PanelTheme.color(enabled and "white" or "muted")
end

-- Reflects BuildSession state: which rows show and which buttons are live.
function BuildDrawer:refresh(session)
	local editable = session:canEdit()
	setEnabled(self.actions.Undo, editable and session.canUndo)
	setEnabled(self.actions.Redo, editable and session.canRedo)
	self.selectionRow.Visible = session.mode == "selected"
	for _, b in pairs(self.selectionButtons) do
		setEnabled(b, editable)
	end
	self.hintRow.Visible = session:isPreviewing()
	for _, card in pairs(self.cards) do
		setEnabled(card.button, editable and card.installed)
	end
end

local function frameViewport(viewport, model)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 35
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local cf, size = model:GetBoundingBox()
	local radius = math.max(size.Magnitude / 2, 0.5)
	local distance = radius / math.tan(math.rad(camera.FieldOfView / 2)) * 1.05
	local direction = (cf.LookVector + cf.RightVector * 0.6 + cf.UpVector * 0.5).Unit
	camera.CFrame = CFrame.lookAt(cf.Position + direction * distance, cf.Position)
end

-- items: { { id, displayName, installed, preview = Model? } } for the current filter.
function BuildDrawer:setItems(items)
	for _, card in pairs(self.cards) do
		card.button:Destroy()
	end
	self.cards = {}
	for i, item in ipairs(items) do
		local b = PanelTheme.button("", false)
		b.Size = UDim2.new(1, 0, 0, 64)
		b.LayoutOrder = 10 + i
		local viewport = Instance.new("ViewportFrame")
		viewport.BackgroundTransparency = 1
		viewport.Size = UDim2.fromOffset(56, 56)
		viewport.Position = UDim2.fromOffset(4, 4)
		viewport.Parent = b
		if item.preview then
			local model = item.preview:Clone()
			model.Parent = viewport
			frameViewport(viewport, model)
		end
		place(PanelTheme.label("body", item.displayName), b, UDim2.fromOffset(70, 14), UDim2.new(1, -78, 0, 18))
		place(PanelTheme.label("description", item.installed and "Ready to place" or "Not installed"), b, UDim2.fromOffset(70, 34), UDim2.new(1, -78, 0, 14))
		b.Parent = self.body
		b.Activated:Connect(function()
			if item.installed then
				self.callbacks.onItem(item.id)
			end
		end)
		self.cards[item.id] = { button = b, installed = item.installed }
	end
end

function BuildDrawer:destroy()
	if self.dragConnection then
		self.dragConnection:Disconnect()
	end
	self.gui:Destroy()
end

return BuildDrawer
