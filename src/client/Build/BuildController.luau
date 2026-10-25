--[[
	BuildController: client build-mode behaviour, independent of Roblox so its
	asynchronous paths can be tested. BuilderClient supplies `env` (Roblox
	bindings) and forwards signals; every env call may yield.

	env = {
		config, catalog,
		request(payload) -> response,               -- RemoteFunction invoke (yields)
		handoff,                                    -- BuildModeHandoff instance
		readSandbox() -> { origin, bounds } | nil,
		isHost() -> boolean,
		createDrawer(callbacks) -> drawer,          -- BuildDrawer
		previewTemplate(itemId) -> template | nil,  -- prepared PreviewTemplates
		itemSize(itemId) -> { x, y, z } | nil,
		createGhost(itemId) -> { catalogId, show(transform, valid), destroy() } | nil,
		raycast(pointer, excludeId) -> { x, y, z, upDot } | nil,  -- sandbox local
		pickPlaced(pointer) -> id | nil,
		selectedInfo(id) -> { catalogId, yaw } | nil,
		mouseLocation() -> pointer,
		setSelectionHighlight(id | nil),
		panel = { getPosition() -> x, y, onClosed(info) },  -- optional
		spawn(fn), wait(seconds),
	}

	Async rules (review of 3d6519f):
	* generation: bumped on every open and close. Every yielding request
	  captures it and discards its result if it changed, so a response that
	  arrives after close (or after close + reopen) can never revive or
	  overwrite a session. Stale status revisions are ignored by BuildSession.
	* opening is tracked separately from open. close(), host change, room
	  switch and respawn during a yielding handoff:enter cancel the open: the
	  handoff is exited, no drawer is created, open() returns "Cancelled".
	* A failed handoff exit keeps its cleanup handle; it is reported to the
	  panel, retried in the background and on every close()/open(), and open()
	  refuses with "CleanupPending" until it succeeds.
	* The ghost tracks its catalog ID and is replaced when the chosen item
	  changes; a placement only uses a preview computed for the current item.
	* The active input method (mouse or touch) is tracked per input, not by
	  device capability: touch taps preview and confirm with Place here, mouse
	  clicks confirm, and mouse polling never overwrites a touched point.
	* Pointer presses inside the drawer never reach the world, whatever
	  gameProcessed says.
]]

local BuildSession = require(script.Parent.BuildSession)
local PlacementPreview = require(script.Parent.PlacementPreview)

local BuildController = {}
BuildController.__index = BuildController

local RETRY_SECONDS = 2

function BuildController.new(env)
	local self = setmetatable({
		env = env,
		session = BuildSession.new(env.config),
		generation = 0,
		opening = false,
		sending = false,
		drawer = nil,
		ghost = nil,
		sandbox = nil,
		pointer = nil,
		inputMethod = "mouse",
		lastPreview = nil,
		cleanupRetrying = false,
		lastCloseInfo = nil,
	}, BuildController)
	return self
end

function BuildController:isOpen()
	return self.session:isOpen()
end

function BuildController:isOpening()
	return self.opening
end

-- Requests ------------------------------------------------------------------

-- One yielding request bound to the current generation. Returns the response,
-- or nil when it was discarded because the session closed/reopened meanwhile.
function BuildController:_request(payload)
	local generation = self.generation
	local response = self.env.request(payload)
	if generation ~= self.generation then
		return nil
	end
	if type(response) ~= "table" then
		response = { ok = false, code = "Internal" }
	end
	self.session:applyResponse(payload.op, response)
	return response
end

-- Sends one edit; ignores input while an edit of this session is in flight.
function BuildController:_send(payload)
	if self.sending or not self.session:canEdit() then
		return nil
	end
	self.sending = true
	local generation = self.generation
	local response = self:_request(payload)
	if generation ~= self.generation then
		return nil -- a newer session owns `sending` now
	end
	self.sending = false
	if response and not response.ok and response.code then
		self.session.message = self.env.messageFor and self.env.messageFor(response.code) or response.code
	end
	self:_refresh()
	return response
end

function BuildController:_refreshStatus()
	self:_request({ op = "Status" })
	self:_refresh()
end

-- Handoff cleanup -------------------------------------------------------------

function BuildController:_retryCleanup()
	local handoff = self.env.handoff
	if not handoff:hasPendingCleanup() then
		return true
	end
	local ok = handoff:exit()
	return ok and not handoff:hasPendingCleanup()
end

function BuildController:_scheduleCleanupRetry()
	if self.cleanupRetrying then
		return
	end
	self.cleanupRetrying = true
	self.env.spawn(function()
		while self.env.handoff:hasPendingCleanup() do
			self.env.wait(RETRY_SECONDS)
			self:_retryCleanup()
		end
		self.cleanupRetrying = false
	end)
end

function BuildController:_exitHandoff()
	local ok, failures = self.env.handoff:exit()
	if not ok and self.env.handoff:hasPendingCleanup() then
		self:_scheduleCleanupRetry()
		return false, failures
	end
	return true
end

function BuildController:_notifyClosed(info)
	self.lastCloseInfo = info
	local panel = self.env.panel
	if panel and panel.onClosed then
		pcall(panel.onClosed, info)
	end
end

-- Open / close ----------------------------------------------------------------

function BuildController:open()
	if self.session:isOpen() then
		return true
	end
	if self.opening then
		return false, "Opening"
	end
	if not self:_retryCleanup() then
		self:_scheduleCleanupRetry()
		return false, "CleanupPending"
	end
	local sandbox = self.env.readSandbox()
	if sandbox == nil then
		return false, "Unavailable"
	end

	self.generation = self.generation + 1
	local generation = self.generation
	self.opening = true
	local entered, failures = self.env.handoff:enter({ sandboxOrigin = sandbox.origin, bounds = sandbox.bounds })
	if generation ~= self.generation then
		-- Cancelled while entering; _cancelOpening already asked the handoff to exit.
		if entered then
			self:_exitHandoff()
		end
		return false, "Cancelled"
	end
	self.opening = false
	if not entered then
		local reason = failures and failures[1] and failures[1].reason == "Unbound" and "HandoffUnbound" or "HandoffFailed"
		return false, reason
	end

	self.sandbox = sandbox
	self.sending = false
	self.session:opened(self.env.isHost())
	self.drawer = self.env.createDrawer(self:_drawerCallbacks())
	local panel = self.env.panel
	if panel and panel.getPosition then
		local ok, x, y = pcall(panel.getPosition)
		if ok and type(x) == "number" and type(y) == "number" then
			self.drawer:setPosition(x, y)
		end
	end
	self.drawer:setInputMode(self.inputMethod)
	self:showFilter(self.session.filter)
	self:_startRecoveryPolling(generation)
	self:_refreshStatus()
	return true
end

function BuildController:_cancelOpening(reason)
	self.generation = self.generation + 1
	self.opening = false
	local ok = self:_exitHandoff() -- cancels a yielded enter (pending) or cleans up
	self:_notifyClosed({ reason = reason, cancelled = true, cleanupFailed = not ok or nil })
end

-- reason: optional message for the panel (host change, room switch, respawn).
function BuildController:close(reason)
	if self.opening then
		self:_cancelOpening(reason)
		return
	end
	if not self.session:isOpen() then
		-- Nothing open, but a previous exit may still need cleaning up.
		if not self:_retryCleanup() then
			self:_scheduleCleanupRetry()
		end
		return
	end
	self.generation = self.generation + 1
	local x, y = nil, nil
	if self.drawer then
		x, y = self.drawer:getPosition()
	end
	self.session:closed()
	self.sending = false
	self:_clearGhost()
	self.env.setSelectionHighlight(nil)
	if self.drawer then
		self.drawer:destroy()
		self.drawer = nil
	end
	local ok = self:_exitHandoff()
	self:_notifyClosed({ x = x, y = y, reason = reason, cleanupFailed = not ok or nil })
end

function BuildController:_startRecoveryPolling(generation)
	self.env.spawn(function()
		while generation == self.generation do
			self.env.wait(RETRY_SECONDS)
			if generation ~= self.generation then
				break
			end
			if self.session.paused then
				self:_refreshStatus() -- _request discards results from older sessions
			end
		end
	end)
end

-- Preview ---------------------------------------------------------------------

function BuildController:_clearGhost()
	if self.ghost then
		self.ghost:destroy()
	end
	self.ghost = nil
	self.lastPreview = nil
end

function BuildController:_ensureGhost()
	local itemId = self.session.itemId
	if self.ghost and self.ghost.catalogId ~= itemId then
		self:_clearGhost()
	end
	if self.ghost == nil and itemId then
		self.ghost = self.env.createGhost(itemId)
	end
end

function BuildController:_updatePreview()
	local session = self.session
	if not session:isPreviewing() or self.sandbox == nil then
		self:_clearGhost()
		return
	end
	self:_ensureGhost()
	if self.ghost == nil or self.pointer == nil then
		return
	end
	local size = self.env.itemSize(session.itemId)
	if size == nil then
		return
	end
	local exclude = session.mode == "moving" and session.selectedId or nil
	local hit = self.env.raycast(self.pointer, exclude)
	local preview = PlacementPreview.compute(hit, { size = size, yaw = session.previewYaw, bounds = self.sandbox.bounds, snap = true, config = self.env.config })
	preview.itemId = session.itemId
	self.lastPreview = preview
	if preview.transform then
		self.ghost.show(preview.transform, preview.valid)
	end
end

function BuildController:confirmPlacement()
	local session = self.session
	if not session:isPreviewing() or not session:canEdit() then
		return nil
	end
	local preview = self.lastPreview
	if preview == nil or preview.itemId ~= session.itemId or not preview.valid then
		session.message = self.env.messageFor and self.env.messageFor(preview and preview.code == "OutOfBounds" and "OutOfBounds" or "BadTransform") or "Can't place there."
		self:_refresh()
		return nil
	end
	local t = preview.transform
	local transform = { x = t.x, y = t.y, z = t.z, yaw = t.yaw }
	if session.mode == "placing" then
		return self:_send({ op = "Place", itemId = session.itemId, transform = transform })
	end
	return self:_send({ op = "Move", id = session.selectedId, transform = transform })
end

-- UI ----------------------------------------------------------------------------

function BuildController:_refresh()
	local session = self.session
	if self.drawer == nil then
		return
	end
	if not session:isPreviewing() then
		self:_clearGhost()
	end
	local highlighted = (session.mode == "selected" or session.mode == "moving") and session.selectedId or nil
	self.env.setSelectionHighlight(highlighted)
	local status
	if session.readOnly then
		status = "Only the host can build."
	elseif session:isPreviewing() then
		status = "Placing: snaps to floors and tabletops."
	else
		status = "Build your studio."
	end
	self.drawer:setStatus(status)
	self.drawer:setFooter(session.message or "")
	self.drawer:refresh(session)
end

function BuildController:showFilter(collectionId)
	local session = self.session
	session:setFilter(collectionId)
	if self.drawer == nil then
		return
	end
	local catalog = self.env.catalog
	local collection = catalog.getCollection(session.filter)
	self.drawer:setFilter(session.filter, collection and collection.displayName)
	local items = {}
	for _, item in ipairs(catalog.getItemsTagged(session.filter)) do
		local template = self.env.previewTemplate(item.id)
		items[#items + 1] = { id = item.id, displayName = item.displayName, installed = template ~= nil, preview = template }
	end
	self.drawer:setItems(items)
	self:_refresh()
end

function BuildController:chooseItem(itemId)
	self.session:choose(itemId, self.env.previewTemplate(itemId) ~= nil)
	self:_updatePreview()
	self:_refresh()
end

function BuildController:rotate()
	local action = self.session:rotate()
	if action == "request" then
		return self:_send({ op = "Rotate", id = self.session.selectedId })
	end
	self:_updatePreview()
	self:_refresh()
	return nil
end

function BuildController:cancel()
	self.session:cancel()
	self:_refresh()
end

function BuildController:beginMove()
	local session = self.session
	local info = session.selectedId and self.env.selectedInfo(session.selectedId) or nil
	if info then
		session:beginMove(info.catalogId, info.yaw)
		self:_updatePreview()
		self:_refresh()
	end
end

function BuildController:_drawerCallbacks()
	return {
		onFilter = function(id)
			self:showFilter(id)
		end,
		onItem = function(itemId)
			self:chooseItem(itemId)
		end,
		onUndo = function()
			self:_send({ op = "Undo", expectedRevision = self.session.revision })
		end,
		onRedo = function()
			self:_send({ op = "Redo", expectedRevision = self.session.revision })
		end,
		onBack = function()
			self:close()
		end,
		onDone = function()
			self:close() -- task 5: save first; stay open with a visible error if it fails
		end,
		onMove = function()
			self:beginMove()
		end,
		onRotate = function()
			self:rotate()
		end,
		onDuplicate = function()
			if self.session.selectedId then
				self:_send({ op = "Duplicate", id = self.session.selectedId })
			end
		end,
		onDelete = function()
			if self.session.selectedId then
				self:_send({ op = "Delete", id = self.session.selectedId })
			end
		end,
		onPlaceHere = function()
			self:confirmPlacement()
		end,
		onCancel = function()
			self:cancel()
		end,
	}
end

-- Signals from BuilderClient ------------------------------------------------------

function BuildController:_setInputMethod(method)
	if method ~= self.inputMethod then
		self.inputMethod = method
		if self.drawer then
			self.drawer:setInputMode(method)
		end
	end
end

-- Mouse movement or touch drag over the world.
function BuildController:onPointerMoved(pointer, method)
	self:_setInputMethod(method)
	if method == "touch" then
		self.pointer = pointer
		self:_updatePreview()
	end
end

-- Left click or tap. screenX/screenY are in GUI space for the drawer hit test.
function BuildController:onPointerPressed(pointer, method, screenX, screenY)
	if not self.session:isOpen() then
		return
	end
	if self.drawer and self.drawer:containsPoint(screenX, screenY) then
		return -- presses on the drawer (even its background) never reach the world
	end
	self:_setInputMethod(method)
	self.pointer = pointer
	if self.session:isPreviewing() then
		self:_updatePreview()
		if method == "mouse" then
			self:confirmPlacement() -- touch confirms with Place here
		end
		return
	end
	self.session:select(self.env.pickPlaced(pointer))
	self:_refresh()
end

-- Per frame.
function BuildController:tick()
	if not self.session:isPreviewing() then
		return
	end
	if self.inputMethod == "mouse" then
		self.pointer = self.env.mouseLocation()
	end
	self:_updatePreview()
end

function BuildController:onHostChanged()
	if self.opening then
		if not self.env.isHost() then
			self:_cancelOpening("Host changed; build mode closed.")
		end
		return
	end
	if self.session:isOpen() and self.session:hostChanged(self.env.isHost()) then
		self:close(self.session.message)
	elseif self.session:isOpen() then
		self:_refresh()
	end
end

function BuildController:onRoomSwitched()
	if self.opening then
		self:_cancelOpening("Room changed; build mode closed.")
	elseif self.session:isOpen() then
		self.session:roomSwitched()
		self:close(self.session.message)
	end
end

function BuildController:onRespawned()
	if self.opening then
		self:_cancelOpening("Respawned; build mode closed.")
	elseif self.session:isOpen() then
		self.session:respawned()
		self:close(self.session.message)
	end
end

function BuildController:onRevisionChanged(revision)
	if self.session:isOpen() then
		self.session:revisionChanged(revision)
		self:_refresh()
	end
end

function BuildController:onViewportChanged(width, height)
	if self.drawer then
		self.drawer:refit(width, height)
	end
end

function BuildController:onFocusLost()
	if self.drawer then
		self.drawer:cancelDrag()
	end
end

return BuildController
