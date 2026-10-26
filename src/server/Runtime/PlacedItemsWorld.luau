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

	Streaming: every model built here (spawn, build-load replace, reconcile
	respawn) gets ModelStreamingMode = Persistent after sanitizing and before
	parenting, and reconcile re-applies it to models it keeps. This is a
	deliberate choice for the bounded 150-item sandbox prototype under
	StreamingEnabled (the build camera can be far from the avatar); the
	sandbox Model and the 7 ServerStorage templates are made persistent in
	Studio by Codex. Existing room assets keep normal streaming.

	Templates have bottom-centre pivots (verified by TemplateCatalog's probe),
	so the world pivot is origin * (x, y, z) * yaw. Each model is tagged with
	BuildItemId / BuildCatalogId / BuildPlacedByUserId. StudioCustomization must
	skip BuildItemId-tagged models (pending a live-script change, see docs/adapters.md).

	Optional door lifecycle hook (panel door plan; DORMANT, BuilderService
	passes none): `doors` is an injected door lifecycle object. Without it every
	call below is skipped, so existing behaviour is unchanged. With it:
	* spawn:   apply -> attach(frozen); commit -> thaw; rollback -> detach.
	* move:    apply -> beginEdit BEFORE PivotTo, then moved(to);
	           commit -> thaw; rollback -> PivotTo previous, then cancelEdit.
	* remove:  apply -> beginEdit before unparenting; commit -> detach;
	           rollback -> cancelEdit.
	* replace: only after every new model built (a failed build calls
	           nothing): old -> beginEdit (if one fails, the freezes made so
	           far are cancelled, the new models destroyed and the apply
	           fails with the world untouched), new -> attach(frozen);
	           commit -> detach old, thaw new; rollback -> detach new, cancelEdit old.
	* reconcile: dropped models -> detach; kept -> beginEdit, PivotTo,
	           moved, thaw; respawned -> attach then thaw.
	Doors stay frozen (snapped closed, no sensing) from apply until commit or
	rollback, so a reset door cannot reopen mid-edit. beginEdit raises when a
	door can't be snapped closed; for move and remove that happens before the
	model changes, so the apply simply fails. The controller keys
	doors by model, so old and new models with the same id never share state.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("StudioBuilder"):WaitForChild("Config"))
local TemplateSanitizer = require(script.Parent.TemplateSanitizer)

local PlacedItemsWorld = {}
PlacedItemsWorld.__index = PlacedItemsWorld

-- folder: the dedicated placed-items Folder
-- origin: sandbox origin CFrame (floor centre)
-- getTemplate(itemId) -> curated template Model or nil
-- doors: optional door lifecycle hook (see above); nil keeps the world door-free.
function PlacedItemsWorld.new(folder, origin, getTemplate, doors)
	return setmetatable({ folder = folder, origin = origin, getTemplate = getTemplate, models = {}, doors = doors }, PlacedItemsWorld)
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
		-- Bounded prototype (<= 150 items): placed models stay streamed in
		-- regardless of avatar distance (StreamingEnabled; the build camera can
		-- be far from the avatar). Set before parenting. Existing rooms keep
		-- their normal streaming.
		model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
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
		if self.doors then
			self.doors:attach(model, effect.id, effect.record, true)
		end
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
		if self.doors then
			-- Freezing an old door can fail (driver fault); then undo the
			-- freezes already made, discard the new models and fail the apply
			-- with the world untouched.
			local frozen = {}
			local okFreeze, freezeErr = pcall(function()
				for _, model in pairs(old) do
					self.doors:beginEdit(model)
					frozen[#frozen + 1] = model
				end
			end)
			if not okFreeze then
				for _, model in ipairs(frozen) do
					self.doors:cancelEdit(model)
				end
				for _, model in pairs(created) do
					model:Destroy()
				end
				error(freezeErr, 0)
			end
		end
		for _, model in pairs(old) do
			model.Parent = nil
		end
		for _, model in pairs(created) do
			model.Parent = self.folder
		end
		self.models = created
		if self.doors then
			for _, entry in ipairs(effect.entries) do
				self.doors:attach(created[entry.id], entry.id, entry.record, true)
			end
		end
		return { kind = "replace", id = "*", old = old, new = created }
	elseif effect.kind == "move" then
		local model = self.models[effect.id]
		if model == nil then
			error("no placed model for " .. effect.id)
		end
		if self.doors then
			self.doors:beginEdit(model)
		end
		local previous = model:GetPivot()
		model:PivotTo(self:_cframe(effect.to))
		if self.doors then
			self.doors:moved(model, effect.to)
		end
		return { kind = "move", id = effect.id, model = model, previous = previous }
	elseif effect.kind == "remove" then
		local model = self.models[effect.id]
		if model == nil then
			error("no placed model for " .. effect.id)
		end
		if self.doors then
			self.doors:beginEdit(model)
		end
		model.Parent = nil
		return { kind = "remove", id = effect.id, model = model }
	end
	error("unknown effect kind " .. tostring(effect.kind))
end

function PlacedItemsWorld:rollback(token)
	local doors = self.doors
	if token.kind == "replace" then
		for _, model in pairs(token.new) do
			if doors then
				doors:detach(model)
			end
			model:Destroy()
		end
		for _, model in pairs(token.old) do
			model.Parent = self.folder
			if doors then
				doors:cancelEdit(model)
			end
		end
		self.models = token.old
	elseif token.kind == "spawn" then
		self.models[token.id] = nil
		if doors then
			doors:detach(token.model)
		end
		token.model:Destroy()
	elseif token.kind == "move" then
		token.model:PivotTo(token.previous)
		if doors then
			doors:cancelEdit(token.model)
		end
	elseif token.kind == "remove" then
		token.model.Parent = self.folder
		if doors then
			doors:cancelEdit(token.model)
		end
	end
end

function PlacedItemsWorld:commit(token)
	local doors = self.doors
	if token.kind == "replace" then
		for _, model in pairs(token.old) do
			if doors then
				doors:detach(model)
			end
			model:Destroy()
		end
		if doors then
			for _, model in pairs(token.new) do
				doors:thaw(model)
			end
		end
	elseif token.kind == "remove" then
		self.models[token.id] = nil
		if doors then
			doors:detach(token.model)
		end
		token.model:Destroy()
	elseif doors and (token.kind == "spawn" or token.kind == "move") then
		doors:thaw(token.model)
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
	local doors = self.doors
	for id, model in pairs(self.models) do
		if wanted[id] == nil or model.Parent ~= self.folder then
			self.models[id] = nil
			if doors then
				doors:detach(model)
			end
			model:Destroy()
		end
	end
	for _, child in ipairs(self.folder:GetChildren()) do
		local id = child:GetAttribute(Config.BuildItemIdAttribute)
		if id == nil or self.models[id] ~= child then
			if doors then
				doors:detach(child)
			end
			child:Destroy()
		end
	end
	for _, entry in ipairs(entries) do
		local model = self.models[entry.id]
		if model then
			if doors then
				doors:beginEdit(model)
			end
			model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
			model:PivotTo(self:_cframe(entry.record))
			if doors then
				doors:moved(model, entry.record)
				doors:thaw(model)
			end
		else
			local token = self:apply({ kind = "spawn", id = entry.id, record = entry.record })
			if doors then
				doors:thaw(token.model)
			end
		end
	end
end

function PlacedItemsWorld:publishRevision(revision)
	self.folder:SetAttribute(Config.BuildRevisionAttribute, revision)
end

return PlacedItemsWorld
