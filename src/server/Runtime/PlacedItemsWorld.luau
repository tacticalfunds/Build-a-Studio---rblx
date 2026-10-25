--[[
	PlacedItemsWorld: applies PlacementCore effects to Instances in the
	dedicated Workspace.StudioBuilderPlacedItems folder. Studio integration pending.

	Two-phase, so PlacementCore can undo a change if the host is lost while
	it ran:
		apply(effect) -> token     visible change, reversible
		rollback(token)            undo it
		commit(token)              finalize (only removal does work here)
		reconcile(entries)         recovery fallback: rebuild the folder from the model
	* spawn:  clone the curated template, sanitize, tag, pivot, parent LAST.
	          rollback destroys the clone.
	* move:   PivotTo the new transform; rollback restores the previous pivot.
	* remove: unparent; rollback re-parents; commit destroys.
	* replace (build load): build all new models unparented first (failure
	  leaves the world untouched), then swap; rollback restores the old set;
	  commit destroys the old set.

	Templates have bottom-centre pivots (verified by TemplateCatalog's probe),
	so the world pivot is origin * (x, y, z) * yaw. Each model is tagged with
	BuildItemId / BuildCatalogId / BuildPlacedByUserId. StudioCustomization must
	skip BuildItemId-tagged models (pending a live-script change, see docs/adapters.md).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("StudioBuilder"):WaitForChild("Config"))
local TemplateSanitizer = require(script.Parent.TemplateSanitizer)

local PlacedItemsWorld = {}
PlacedItemsWorld.__index = PlacedItemsWorld

-- folder: the dedicated placed-items Folder
-- origin: sandbox origin CFrame (floor centre)
-- getTemplate(itemId) -> curated template Model or nil
function PlacedItemsWorld.new(folder, origin, getTemplate)
	return setmetatable({ folder = folder, origin = origin, getTemplate = getTemplate, models = {} }, PlacedItemsWorld)
end

function PlacedItemsWorld:_cframe(record)
	return self.origin * CFrame.new(record.x, record.y, record.z) * CFrame.Angles(0, math.rad(record.yaw), 0)
end

-- Clones, sanitizes, tags and pivots a model for id/record; returns it UNPARENTED.
function PlacedItemsWorld:_build(id, record)
	local template = self.getTemplate(record.itemId)
	if template == nil then
		error("template missing for " .. record.itemId)
	end
	local model = template:Clone()
	if model == nil then
		error("template is not Archivable: " .. record.itemId)
	end
	local ok, err = pcall(function()
		TemplateSanitizer.forPlacement(model)
		model.Name = id
		model:SetAttribute(Config.BuildItemIdAttribute, id)
		model:SetAttribute("BuildCatalogId", record.itemId)
		model:SetAttribute("BuildPlacedByUserId", record.placedByUserId)
		model:PivotTo(self:_cframe(record))
	end)
	if not ok then
		model:Destroy()
		error(err, 0)
	end
	return model
end

function PlacedItemsWorld:apply(effect)
	if effect.kind == "spawn" then
		local model = self:_build(effect.id, effect.record)
		model.Parent = self.folder
		self.models[effect.id] = model
		return { kind = "spawn", id = effect.id, model = model }
	elseif effect.kind == "replace" then
		-- Build loads: build every new model first; any failure leaves the world untouched.
		local created = {}
		local ok, err = pcall(function()
			for _, entry in ipairs(effect.entries) do
				created[entry.id] = self:_build(entry.id, entry.record)
			end
		end)
		if not ok then
			for _, model in pairs(created) do
				model:Destroy()
			end
			error(err, 0)
		end
		local old = self.models
		for _, model in pairs(old) do
			model.Parent = nil
		end
		for _, model in pairs(created) do
			model.Parent = self.folder
		end
		self.models = created
		return { kind = "replace", id = "*", old = old, new = created }
	elseif effect.kind == "move" then
		local model = self.models[effect.id]
		if model == nil then
			error("no placed model for " .. effect.id)
		end
		local previous = model:GetPivot()
		model:PivotTo(self:_cframe(effect.to))
		return { kind = "move", id = effect.id, model = model, previous = previous }
	elseif effect.kind == "remove" then
		local model = self.models[effect.id]
		if model == nil then
			error("no placed model for " .. effect.id)
		end
		model.Parent = nil
		return { kind = "remove", id = effect.id, model = model }
	end
	error("unknown effect kind " .. tostring(effect.kind))
end

function PlacedItemsWorld:rollback(token)
	if token.kind == "replace" then
		for _, model in pairs(token.new) do
			model:Destroy()
		end
		for _, model in pairs(token.old) do
			model.Parent = self.folder
		end
		self.models = token.old
	elseif token.kind == "spawn" then
		self.models[token.id] = nil
		token.model:Destroy()
	elseif token.kind == "move" then
		token.model:PivotTo(token.previous)
	elseif token.kind == "remove" then
		token.model.Parent = self.folder
	end
end

function PlacedItemsWorld:commit(token)
	if token.kind == "replace" then
		for _, model in pairs(token.old) do
			model:Destroy()
		end
	elseif token.kind == "remove" then
		self.models[token.id] = nil
		token.model:Destroy()
	end
end

-- Recovery fallback: make the folder match the model exactly. entries is
-- PlacementCore's model:list() ({ { id, record } }). Destroys anything not in
-- the model (including stray or detached models), respawns missing ones and
-- re-pivots the rest. Raises if any step fails, so the core stays in recovery.
function PlacedItemsWorld:reconcile(entries)
	local wanted = {}
	for _, entry in ipairs(entries) do
		wanted[entry.id] = entry.record
	end
	for id, model in pairs(self.models) do
		if wanted[id] == nil or model.Parent ~= self.folder then
			self.models[id] = nil
			model:Destroy()
		end
	end
	for _, child in ipairs(self.folder:GetChildren()) do
		local id = child:GetAttribute(Config.BuildItemIdAttribute)
		if id == nil or self.models[id] ~= child then
			child:Destroy()
		end
	end
	for _, entry in ipairs(entries) do
		local model = self.models[entry.id]
		if model then
			model:PivotTo(self:_cframe(entry.record))
		else
			self:apply({ kind = "spawn", id = entry.id, record = entry.record })
		end
	end
end

function PlacedItemsWorld:publishRevision(revision)
	self.folder:SetAttribute(Config.BuildRevisionAttribute, revision)
end

return PlacedItemsWorld
