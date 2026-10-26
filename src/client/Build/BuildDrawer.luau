--[[
	BuildDrawer: the Build catalog drawer, built only from PanelTheme so it
	matches the live host panel (docs/ui-contract.md). Studio-pending: not run
	outside Roblox.

	Layout (contract positions):
	* title "Build" at (18, 13), shared status line at (18, 39);
	* DRAG TO MOVE handle top right, 30x30 close (= Back) at (right - 48, 12);
	* the five collection filters in the tab row (x 14, y 72, h 34, gap 6),
	  standard/selected button styles;
	* the same tab row is relabelled in Structure mode: Floors / Walls /
	  Doors / Ceilings / Windows (task 10). No extra tab row or panel;
	* scroll body (x 14, y 119, w - 28, h - 177), rows with 9 px padding:
	  a Furniture | Structure choice row (same button styles, selected =
	  teal), actions (Undo / Redo / Exit / Done; Exit leaves build mode),
	  selection (Move / Rotate /
	  Duplicate / Delete), placement row (Place here when the active input is
	  touch / Rotate / Cancel), the collection heading, then either the
	  furniture type chooser (two-column grid of "Seating (4)"-style buttons,
	  empty types hidden, plus All items) or a "< Types" row and the chosen
	  type's catalog cards with ViewportFrames from PreviewTemplates;
	* footer status at (18, bottom - 49), 11 px muted.
	The drawer is draggable by its handle and clamped on-screen; refit() follows
	viewport resizes/orientation; containsPoint() lets the controller keep every
	press on the drawer (background and labels included) out of the world.
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

-- callbacks: onFilter(id), onCategory(category), onType(typeId), onTypes,
--            onItem(itemId), onUndo, onRedo, onBack (Exit), onDone, onMove,
--            onRotate, onDuplicate, onDelete, onPlaceHere, onCancel
-- collections: sorted { id, displayName }; structureFilters: { id, displayName }
-- (optional). The tab row starts with the collections; setCategory relabels it.
function BuildDrawer.new(playerGui, collections, callbacks, structureFilters)
	local self = setmetatable({ callbacks = callbacks, cards = {}, tabButtons = {}, tabIds = {} }, BuildDrawer)

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
	drawer.Active = true
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
	local n = math.max(#collections, structureFilters and #structureFilters or 0)
	for i = 1, n do
		local b = PanelTheme.button("", false)
		b.LayoutOrder = i
		b.Parent = tabs
		b.Activated:Connect(function()
			local id = self.tabIds[i]
			if id then
				callbacks.onFilter(id)
			end
		end)
		self.tabButtons[i] = b
	end
	self:_labelTabs(collections)

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

	local onCategory = callbacks.onCategory or function() end
	local _, categories = buttonRow(body, 0, { "Furniture", "Structure" }, {
		function() onCategory("furniture") end,
		function() onCategory("structure") end,
	})
	self.categoryButtons = categories

	-- "Exit" leaves build mode; "< Types" (below) only returns to the type chooser.
	local _, actions = buttonRow(body, 1, { "Undo", "Redo", "Exit", "Done" }, { callbacks.onUndo, callbacks.onRedo, callbacks.onBack, callbacks.onDone })
	self.actions = actions

	local selection
	self.selectionRow, selection = buttonRow(body, 2, { "Move", "Rotate [R]", "Duplicate", "Delete" }, { callbacks.onMove, callbacks.onRotate, callbacks.onDuplicate, callbacks.onDelete })
	self.selectionButtons = selection

	local hint = row(body, 3, 54)
	self.hintText = place(PanelTheme.label("description", ""), hint, UDim2.new(), UDim2.new(1, 0, 0, 16))
	local hintButtons = row(hint, 1, L.tabsHeight)
	hintButtons.Position = UDim2.fromOffset(0, 20)
	local hintLayout = Instance.new("UIListLayout")
	hintLayout.FillDirection = Enum.FillDirection.Horizontal
	hintLayout.Padding = UDim.new(0, L.tabsGap)
	hintLayout.SortOrder = Enum.SortOrder.LayoutOrder
	hintLayout.Parent = hintButtons
	local function hintButton(text, selected, order, callback)
		local b = PanelTheme.button(text, selected)
		b.Size = UDim2.new(1 / 3, -L.tabsGap * 2 / 3, 1, 0)
		b.LayoutOrder = order
		b.Parent = hintButtons
		b.Activated:Connect(callback)
		return b
	end
	self.placeHere = hintButton("Place here", true, 1, callbacks.onPlaceHere)
	hintButton("Rotate [R]", false, 2, callbacks.onRotate) -- touch users have no R key
	hintButton("Cancel", false, 3, callbacks.onCancel)
	self.hintRow = hint
	self:setInputMode("mouse")

	local heading = row(body, 4, 34)
	self.collectionHeading = place(PanelTheme.label("heading", ""), heading, UDim2.new(), UDim2.new(1, 0, 0, 16))
	self.headingDescription = place(PanelTheme.label("description", "Choose an item, then a floor or tabletop."), heading, UDim2.fromOffset(0, 18), UDim2.new(1, 0, 0, 14))

	-- "< Types" row: back to the chooser (not out of build mode).
	local typeBack = row(body, 5, L.tabsHeight)
	local backButton = PanelTheme.button("< Types", false)
	place(backButton, typeBack, UDim2.new(), UDim2.new(1 / 3, -L.tabsGap * 2 / 3, 1, 0))
	backButton.Activated:Connect(function()
		if callbacks.onTypes then
			callbacks.onTypes()
		end
	end)
	self.typeName = place(PanelTheme.label("heading", ""), typeBack, UDim2.new(1 / 3, L.tabsGap, 0, 9), UDim2.new(2 / 3, -L.tabsGap, 0, 16))
	typeBack.Visible = false
	self.typeBackRow = typeBack

	-- Type chooser: a compact two-column grid in the scroll body.
	local chooser = Instance.new("Frame")
	chooser.BackgroundTransparency = 1
	chooser.Size = UDim2.new(1, 0, 0, 0)
	chooser.AutomaticSize = Enum.AutomaticSize.Y
	chooser.LayoutOrder = 6
	chooser.Visible = false
	chooser.Parent = body
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.5, -L.tabsGap / 2, 0, L.tabsHeight)
	grid.CellPadding = UDim2.fromOffset(L.tabsGap, L.tabsGap)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = chooser
	self.typeChooser = chooser
	self.typeButtons = {}
	self:setCategory("furniture", collections)

	self.footer = place(PanelTheme.label("status", ""), drawer, UDim2.new(0, L.footerX, 1, -L.footerBottomInset), UDim2.new(1, -L.footerX * 2, 0, L.footerHeight))

	gui.Parent = playerGui
	return self
end

local function isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

function BuildDrawer:_makeDraggable(handle)
	local startInput, startPosition = nil, nil
	self.dragging = false
	handle.InputBegan:Connect(function(input)
		if isPress(input) then
			self.dragging, startInput, startPosition = true, input.Position, self.drawer.AbsolutePosition
		end
	end)
	-- Release anywhere ends the drag (the handle may not see the release).
	self.dragEndConnection = UserInputService.InputEnded:Connect(function(input)
		if isPress(input) then
			self.dragging = false
		end
	end)
	self.dragConnection = UserInputService.InputChanged:Connect(function(input)
		if self.dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - startInput
			self:setPosition(startPosition.X + delta.X, startPosition.Y + delta.Y)
		end
	end)
end

-- Focus loss: stop dragging so the panel doesn't follow a later mouse move.
function BuildDrawer:cancelDrag()
	self.dragging = false
end

-- Viewport resize/orientation: refit size with the live formula, keep the
-- current position but clamp it on-screen.
function BuildDrawer:refit(viewportX, viewportY)
	local fit = PanelTheme.fit(viewportX, viewportY)
	self.drawer.Size = UDim2.fromOffset(fit.width, fit.height)
	local p = self.drawer.AbsolutePosition
	local x, y = PanelTheme.clamp(p.X, p.Y, fit.width, fit.height, viewportX, viewportY)
	self.drawer.Position = UDim2.fromOffset(x, y)
end

-- True when (x, y) in GUI space (same space as InputObject.Position) is on the drawer.
function BuildDrawer:containsPoint(x, y)
	if type(x) ~= "number" or type(y) ~= "number" then
		return false
	end
	local p, size = self.drawer.AbsolutePosition, self.drawer.AbsoluteSize
	return x >= p.X and x <= p.X + size.X and y >= p.Y and y <= p.Y + size.Y
end

-- "touch" shows Place here (taps only preview); "mouse" clicks place directly.
function BuildDrawer:setInputMode(method)
	local touch = method == "touch"
	self.placeHere.Visible = touch
	self.hintText.Text = touch and "Tap a surface to preview, then Place here." or "Click a surface to place. R rotates, Esc cancels."
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

-- Relabels the tab row with filters ({ id, displayName }); extra buttons hide.
function BuildDrawer:_labelTabs(filters)
	local n = #filters
	for i, b in ipairs(self.tabButtons) do
		local f = filters[i]
		self.tabIds[i] = f and f.id or nil
		b.Visible = f ~= nil
		b.Text = f and f.displayName or ""
		b.Size = UDim2.new(1 / math.max(n, 1), -L.tabsGap * (n - 1) / math.max(n, 1), 1, 0)
		PanelTheme.setSelected(b, false)
	end
end

-- "furniture" | "structure": relabels the tab row and marks the choice row.
function BuildDrawer:setCategory(category, filters)
	self:_labelTabs(filters)
	if self.categoryButtons then
		PanelTheme.setSelected(self.categoryButtons.Furniture, category == "furniture")
		PanelTheme.setSelected(self.categoryButtons.Structure, category == "structure")
	end
	if self.headingDescription then
		self.headingDescription.Text = category == "structure" and "Choose a piece, then point at the floor; it snaps to the room grid." or "Choose an item, then a floor or tabletop."
	end
end

-- Furniture type chooser: types = { { id, displayName, count } } (empty
-- types already left out by the controller). Hides the cards' back row.
function BuildDrawer:showTypes(types)
	for _, b in ipairs(self.typeButtons) do
		b:Destroy()
	end
	self.typeButtons = {}
	for i, t in ipairs(types) do
		local b = PanelTheme.button(string.format("%s (%d)", t.displayName, t.count), false)
		b.LayoutOrder = i
		b.Parent = self.typeChooser
		b.Activated:Connect(function()
			if self.callbacks.onType then
				self.callbacks.onType(t.id)
			end
		end)
		self.typeButtons[i] = b
	end
	self.typeChooser.Visible = true
	self.typeBackRow.Visible = false
end

-- The chosen type's cards: shows "< Types" and the type name.
function BuildDrawer:showTypeItems(displayName)
	self.typeChooser.Visible = false
	self.typeBackRow.Visible = true
	self.typeName.Text = displayName or ""
end

-- Structure mode: no type chooser and no back row.
function BuildDrawer:hideTypes()
	self.typeChooser.Visible = false
	self.typeBackRow.Visible = false
end

function BuildDrawer:setFilter(filterId, displayName)
	for i, b in ipairs(self.tabButtons) do
		PanelTheme.setSelected(b, self.tabIds[i] ~= nil and self.tabIds[i] == filterId)
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
	if self.dragEndConnection then
		self.dragEndConnection:Disconnect()
	end
	self.gui:Destroy()
end

return BuildDrawer
