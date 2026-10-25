--[[
	BuildSession: client-side state of the Build drawer. Pure; the controller
	feeds it events and reads the result. The server stays authoritative: the
	session only decides what the UI shows and which request to send.

	Modes: "closed" | "idle" | "placing" | "moving" | "selected".
	* placing/moving show a preview; R turns the preview by RotationStep.
	* Escape: placing -> idle, moving -> selected, selected -> idle.
	* Edits are blocked while read-only (not host) or paused (server in
	  recovery). The pause lifts only when a status says "ready".
	* Host loss, room switch and respawn cancel any preview or move and ask
	  the controller to exit build mode.
	* A BuildRevision the session didn't cause cancels an in-progress move
	  (the item may have changed); undo/redo send expectedRevision so the
	  server refuses stale steps.
]]

local BuildSession = {}
BuildSession.__index = BuildSession

local FILTERS = { cozy = true, ["1980s"] = true, retro = true, winter = true, futuristic = true }

function BuildSession.new(config)
	return setmetatable({
		config = config,
		mode = "closed",
		filter = "cozy",
		itemId = nil,
		selectedId = nil,
		previewYaw = 0,
		readOnly = false,
		paused = false,
		canUndo = false,
		canRedo = false,
		revision = nil,
		message = nil,
	}, BuildSession)
end

function BuildSession:isOpen()
	return self.mode ~= "closed"
end

function BuildSession:canEdit()
	return self:isOpen() and not self.readOnly and not self.paused
end

function BuildSession:isPreviewing()
	return self.mode == "placing" or self.mode == "moving"
end

function BuildSession:opened(isHost)
	self.mode = "idle"
	self.readOnly = not isHost
	self.itemId, self.selectedId, self.message = nil, nil, nil
	if self.readOnly then
		self.message = "Only the host can build."
	end
end

function BuildSession:closed()
	self.mode = "closed"
	self.itemId, self.selectedId = nil, nil
end

function BuildSession:setFilter(collectionId)
	if FILTERS[collectionId] then
		self.filter = collectionId
		return true
	end
	return false
end

-- Starts placing a catalog item (installed = has a prepared template).
function BuildSession:choose(itemId, installed)
	if not self:canEdit() then
		return false
	end
	if not installed then
		self.message = "That item isn't installed yet."
		return false
	end
	self.mode = "placing"
	self.itemId = itemId
	self.selectedId = nil
	self.previewYaw = 0
	return true
end

function BuildSession:select(id)
	if not self:isOpen() or self:isPreviewing() then
		return false
	end
	self.selectedId = id
	self.mode = id and "selected" or "idle"
	return true
end

function BuildSession:beginMove(itemId, currentYaw)
	if self.mode ~= "selected" or not self:canEdit() then
		return false
	end
	self.mode = "moving"
	self.itemId = itemId
	self.previewYaw = currentYaw or 0
	return true
end

-- R / Rotate button. Returns "preview" (local turn) or "request" (send Rotate).
function BuildSession:rotate()
	if self:isPreviewing() then
		self.previewYaw = (self.previewYaw + self.config.RotationStep) % 360
		return "preview"
	end
	if self.mode == "selected" and self:canEdit() then
		return "request"
	end
	return nil
end

function BuildSession:cancel()
	if self.mode == "placing" then
		self.mode = "idle"
		self.itemId = nil
	elseif self.mode == "moving" then
		self.mode = "selected"
		self.itemId = nil
	elseif self.mode == "selected" then
		self.mode = "idle"
		self.selectedId = nil
	end
end

-- Applies a server response to op. Failed placements keep the preview so the
-- user can try another spot.
function BuildSession:applyResponse(op, response)
	local status = type(response) == "table" and response.status or nil
	if type(status) == "table" then
		self.canUndo = status.canUndo == true
		self.canRedo = status.canRedo == true
		if type(status.revision) == "number" then
			self.revision = status.revision
		end
		if status.state == "recovery" then
			self.paused = true
		elseif status.state == "ready" and self.paused then
			self.paused = false
			self.message = nil
		end
	end
	if type(response) ~= "table" then
		return
	end
	if response.code == "RecoveryNeeded" or response.recoveryNeeded then
		self.paused = true
	end
	if self.paused then
		self.message = "The build area is resynchronizing; edits are paused."
	end
	if response.code == "NotHost" then
		self.readOnly = true
		self:cancelPreview()
	end
	if not response.ok then
		return
	end
	if op == "Place" or op == "Duplicate" then
		self.mode = "selected"
		self.selectedId = response.id
		self.itemId = nil
	elseif op == "Move" then
		self.mode = "selected"
		self.itemId = nil
	elseif op == "Delete" then
		self.mode = "idle"
		self.selectedId = nil
	elseif op == "Undo" or op == "Redo" then
		-- The affected item may have disappeared; start from a clean selection.
		self.mode = "idle"
		self.selectedId = nil
		self.itemId = nil
	end
end

function BuildSession:cancelPreview()
	if self.mode == "placing" then
		self.mode = "idle"
	elseif self.mode == "moving" then
		self.mode = "selected"
	end
	self.itemId = nil
end

-- Returns true when the controller must exit build mode.
function BuildSession:hostChanged(isHost)
	if isHost then
		-- Became (or stayed) host: editing is allowed; the server starts a fresh history.
		if self.readOnly then
			self.readOnly = false
			self.message = nil
		end
		return false
	end
	self:cancelPreview()
	self.readOnly = true
	self.message = "Host changed; build mode closed."
	return true
end

function BuildSession:roomSwitched()
	self:cancelPreview()
	self.message = "Room changed; build mode closed."
	return true
end

function BuildSession:respawned()
	self:cancelPreview()
	self.message = "Respawned; build mode closed."
	return true
end

-- A BuildRevision change that our own responses didn't explain.
function BuildSession:revisionChanged(revision)
	if revision == self.revision then
		return
	end
	self.revision = revision
	if self.mode == "moving" then
		self:cancelPreview()
		self.message = "The studio changed; move cancelled."
	end
end

return BuildSession
