--[[
	BuildHistory: server-side undo/redo stacks for the shared sandbox.

	Entries describe committed world effects with exact logical IDs:
		{ kind = "spawn",  id, record }          undo = remove id, redo = spawn id again
		{ kind = "remove", id, record }          undo = spawn id again, redo = remove id
		{ kind = "move",   id, before, after }   undo = move to before, redo = move to after

	History is valid only for the user who made it and only at the build
	revision it last recorded. sync() clears it when either differs: a host
	transfer, or a revision change that history did not make (recovery,
	reconcile or a future load). Pure.
]]

local BuildHistory = {}
BuildHistory.__index = BuildHistory

function BuildHistory.new(limit)
	return setmetatable({ limit = limit, undoStack = {}, redoStack = {}, ownerUserId = nil, revision = 0 }, BuildHistory)
end

function BuildHistory:clear(revision)
	self.undoStack = {}
	self.redoStack = {}
	self.ownerUserId = nil
	self.revision = revision
end

-- Clears the stacks unless they belong to userId at revision. Returns true if cleared.
function BuildHistory:sync(userId, revision)
	if self.ownerUserId == userId and self.revision == revision then
		return false
	end
	self:clear(revision)
	self.ownerUserId = userId
	return true
end

function BuildHistory:_valid(userId, revision)
	return self.ownerUserId == userId and self.revision == revision
end

function BuildHistory:canUndo(userId, revision)
	return self:_valid(userId, revision) and #self.undoStack > 0
end

function BuildHistory:canRedo(userId, revision)
	return self:_valid(userId, revision) and #self.redoStack > 0
end

-- A new edit: push it and drop the redo stack.
function BuildHistory:record(entry, revision)
	local stack = self.undoStack
	stack[#stack + 1] = entry
	while #stack > self.limit do
		table.remove(stack, 1)
	end
	self.redoStack = {}
	self.revision = revision
end

function BuildHistory:peek(direction)
	local stack = direction == "undo" and self.undoStack or self.redoStack
	return stack[#stack]
end

-- Moves the applied entry to the opposite stack.
function BuildHistory:commitStep(direction, revision)
	local from = direction == "undo" and self.undoStack or self.redoStack
	local to = direction == "undo" and self.redoStack or self.undoStack
	to[#to + 1] = table.remove(from)
	self.revision = revision
end

-- Discards an entry that can no longer be applied.
function BuildHistory:drop(direction)
	local stack = direction == "undo" and self.undoStack or self.redoStack
	table.remove(stack)
end

return BuildHistory
