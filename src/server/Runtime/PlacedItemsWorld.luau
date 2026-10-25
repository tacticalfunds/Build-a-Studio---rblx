--[[
	PlacedItemsWorld: applies PlacementCore effects to Instances in the
	dedicated Workspace.StudioBuilderPlacedItems folder. Studio integration pending.

	Two-phase, so PlacementCore can undo a change if the host is lost while
	it ran:
		apply(effect) -> token     visible change, reversible
		rollback(token)            undo it
		commit(token)              finalize (only removal does work here)
	* spawn:  clone the curated template, sanitize, tag, pivot, parent LAST.
	          rollback destroys the clone.
	* move:   PivotTo the new transform; rollback restores the previous pivot.
	* remove: unparent; rollback re-parents; commit destroys.

	Templates have bottom-centre pivots (verified by TemplateCatalog's probe),
	so the world pivot is origin * (x, y, z) * yaw. Each model is tagged with
	BuildItemId / BuildCatalogId / BuildOwnerUserId. StudioCustomization must
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

function PlacedItemsWorld:apply(effect)
	if effect.kind == "spawn" then
		local template = self.getTemplate(effect.record.itemId)
		if template == nil then
			error("template missing for " .. effect.record.itemId)
		end
		local model = template:Clone()
		if model == nil then
			error("template is not Archivable: " .. effect.record.itemId)
		end
		local ok, err = pcall(function()
			TemplateSanitizer.forPlacement(model)
			model.Name = effect.id
			model:SetAttribute(Config.BuildItemIdAttribute, effect.id)
			model:SetAttribute("BuildCatalogId", effect.record.itemId)
			model:SetAttribute("BuildOwnerUserId", effect.record.ownerUserId)
			model:PivotTo(self:_cframe(effect.record))
			model.Parent = self.folder
		end)
		if not ok then
			model:Destroy()
			error(err, 0)
		end
		self.models[effect.id] = model
		return { kind = "spawn", id = effect.id, model = model }
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
	if token.kind == "spawn" then
		self.models[token.id] = nil
		token.model:Destroy()
	elseif token.kind == "move" then
		token.model:PivotTo(token.previous)
	elseif token.kind == "remove" then
		token.model.Parent = self.folder
	end
end

function PlacedItemsWorld:commit(token)
	if token.kind == "remove" then
		self.models[token.id] = nil
		token.model:Destroy()
	end
end

function PlacedItemsWorld:publishRevision(revision)
	self.folder:SetAttribute(Config.BuildRevisionAttribute, revision)
end

return PlacedItemsWorld
