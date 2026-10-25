--[[
	DirectorPersistence (STUDIO BUILDER, task 5 corrections) — a ModuleScript
	installed next to PodcastDirector. It replaces the Director's snapshot(),
	restoreSnapshot() and persistentAction() with the same logic, moved here
	so it can be tested, plus these fixes:

	1. Compound load is one transaction. After validation, staging and the
	   (yielding) text filter, the builder's edit lock is held for the whole
	   room + build restore (builder edits and saves get Busy). The trusted
	   previous room state is captured before any mutation. Any failure, or
	   lost authority after the final yield, rolls back the room (without
	   re-filtering text: the captured values are the live ones) and the
	   build. If a rollback fails, saving is latched and the builder stays in
	   recovery (edits and saves refused).
	2. The staged load is bound to the host session and build revision at
	   preparation; A -> B -> A during text filtering is refused before any
	   mutation (legacy room-only loads included).
	3. Save-block latch: after any failed Load/LoadCode (corrupt, newer,
	   backend read failure, rollback failure), Save and Share are refused
	   for that host until a successful load or the explicit
	   "DiscardLoadBlock" action.
	4. Save feedback: the write and the slot-list refresh are separate; a
	   refresh failure no longer reports a successful save as failed.

	Room code below is the live Director code (2026-10-25) with `for k in t`
	written as `for k in pairs(t)` and math.clamp as a local clamp; no other
	behaviour change. rememberLighting is NOT called during rollback (its
	semantics weren't provided; see docs/integration-task5.md).

	deps (all existing Director locals, passed in): settings, defaults,
	groupKeys, textLengths, bounds, layoutBounds, atmosphereBounds,
	atmosphereKeys, fixtureAttributes, itemAttributes, itemBounds, finite,
	lighting, customization, rememberLighting, applyAll, applyDecor,
	getState, studio, RS, TextService, presets, remote, feedback,
	setLayoutBusy(bool) (closure over the Director's layoutBusy),
	builderPersistence (BuilderService.getPersistence()), clock (os.clock),
	warn.
]]

local DirectorPersistence = {}

local LATCH_MESSAGE = "Your last load didn't complete, so saving is paused to protect your saved studios. Load a studio again, or discard to save the current room anyway."

local function clamp(v, lo, hi)
	return math.min(math.max(v, lo), hi)
end

function DirectorPersistence.new(d)
	local M = {}
	local settings = d.settings
	local latched = {} -- [userId] = reason

	local function currentScene()
		return settings:GetAttribute("SceneSet") or "Custom"
	end

	-- Live snapshot() body (room part).
	local function roomSnapshot()
		local data = { Version = 1, Settings = {}, Fixtures = {}, Items = {} }
		local scene = currentScene()
		for key in pairs(d.defaults) do
			if key ~= "Phase" and (not d.groupKeys[key] or key:sub(1, #scene + 1) == scene .. "_") then
				data.Settings[key] = settings:GetAttribute(key)
			end
		end
		data.Settings.CustomLighting = settings:GetAttribute("CustomLighting") == true
		for _, record in pairs(d.lighting.GetFixtures(scene)) do
			local values = {}
			for key, attribute in pairs(d.fixtureAttributes) do
				values[key] = record.Light:GetAttribute(attribute)
			end
			data.Fixtures[record.Id] = values
		end
		for _, record in pairs(d.customization.GetItems(scene)) do
			local values = {}
			for key, attribute in pairs(d.itemAttributes) do
				values[key] = record.Object:GetAttribute(attribute)
			end
			data.Items[record.Id] = values
		end
		return data
	end

	function M.snapshot()
		-- BUILDER: additive Build section; errors (visible failed save) if the builder can't capture now.
		return d.builderPersistence:attachBuild(roomSnapshot())
	end

	-- Trusted pre-load state: every setting key (all scene groups), and the
	-- fixture/item overrides of both the current and the target scene.
	local function captureRoom(targetScene)
		local settingsValues = {}
		for key in pairs(d.defaults) do
			if key ~= "Phase" then
				settingsValues[key] = settings:GetAttribute(key)
			end
		end
		settingsValues.CustomLighting = settings:GetAttribute("CustomLighting") == true
		local scenes = {}
		for _, scene in ipairs({ currentScene(), targetScene }) do
			if scenes[scene] == nil then
				local fixtures, items = {}, {}
				for _, record in pairs(d.lighting.GetFixtures(scene)) do
					local values = {}
					for key, attribute in pairs(d.fixtureAttributes) do
						values[key] = record.Light:GetAttribute(attribute)
					end
					fixtures[record.Id] = values
				end
				for _, record in pairs(d.customization.GetItems(scene)) do
					local values = {}
					for key, attribute in pairs(d.itemAttributes) do
						values[key] = record.Object:GetAttribute(attribute)
					end
					items[record.Id] = values
				end
				scenes[scene] = { Fixtures = fixtures, Items = items }
			end
		end
		return { scene = currentScene(), Settings = settingsValues, scenes = scenes }
	end

	-- Live restore body: settings, applyAll, fixture and item overrides.
	-- textValues: filtered strings for a load, or the captured live strings for
	-- a rollback (never re-filtered). remember=false skips rememberLighting.
	local function applyRoom(values, textValues, fixturesBy, itemsBy, scene, remember)
		if remember then
			d.rememberLighting(currentScene())
		end
		for key, default in pairs(d.defaults) do
			local value = values[key]
			if key ~= "Phase" and type(value) == type(default) and (type(value) ~= "number" or d.finite(value)) then
				if d.textLengths[key] then
					value = textValues[key]
				elseif d.bounds[key] then
					value = clamp(value, d.bounds[key][1], d.bounds[key][2])
				elseif d.layoutBounds[key] then
					value = clamp(value, d.layoutBounds[key][1], d.layoutBounds[key][2])
				elseif d.atmosphereBounds[key] then
					value = clamp(value, d.atmosphereBounds[key][1], d.atmosphereBounds[key][2])
				elseif key == "Ambience" and value ~= "Off" and value ~= "Rain" and value ~= "Air" then
					value = "Off"
				end
				if value ~= nil then
					settings:SetAttribute(key, value)
				end
			end
		end
		for _, key in pairs(d.atmosphereKeys) do
			if values[key] == nil then
				settings:SetAttribute(key, d.defaults[key])
			end
		end
		settings:SetAttribute("CustomLighting", values.CustomLighting == true)
		d.applyAll()
		for _, record in pairs(d.lighting.GetFixtures(scene)) do
			d.lighting.ResetFixtureOverrides(record.Light)
			local patch = type(fixturesBy) == "table" and fixturesBy[record.Id]
			if type(patch) == "table" then
				for key, attribute in pairs(d.fixtureAttributes) do
					local value = patch[key]
					if (key == "Enabled" and type(value) == "boolean") or ((key == "Intensity" or key == "Range") and d.finite(value)) or (key == "Color" and type(value) == "string" and #value == 6 and value:match("^%x+$")) then
						record.Light:SetAttribute(attribute, value)
					end
				end
			end
		end
		for _, record in pairs(d.customization.GetItems(scene)) do
			d.customization.Reset(record.Object)
			local patch = type(itemsBy) == "table" and itemsBy[record.Id]
			if type(patch) == "table" then
				for key, limit in pairs(d.itemBounds) do
					if d.finite(patch[key]) then
						record.Object:SetAttribute(d.itemAttributes[key], clamp(patch[key], limit[1], limit[2]))
					end
				end
				if type(patch.Visible) == "boolean" then
					record.Object:SetAttribute(d.itemAttributes.Visible, patch.Visible)
				end
			end
		end
		d.customization.Apply(scene)
		d.lighting.Apply(d.studio, d.getState())
		d.applyDecor(d.getState())
	end

	-- Restores the captured pre-load state, raw attribute values included.
	local function rollbackRoom(captured)
		local current = captured.scenes[captured.scene]
		applyRoom(captured.Settings, captured.Settings, current.Fixtures, current.Items, captured.scene, false)
		-- The load's target scene (if different) also had its overrides reset.
		for scene, state in pairs(captured.scenes) do
			if scene ~= captured.scene then
				for _, record in pairs(d.lighting.GetFixtures(scene)) do
					d.lighting.ResetFixtureOverrides(record.Light)
					for key, attribute in pairs(d.fixtureAttributes) do
						local value = state.Fixtures[record.Id] and state.Fixtures[record.Id][key]
						if value ~= nil then
							record.Light:SetAttribute(attribute, value)
						end
					end
				end
				for _, record in pairs(d.customization.GetItems(scene)) do
					d.customization.Reset(record.Object)
					for key, attribute in pairs(d.itemAttributes) do
						local value = state.Items[record.Id] and state.Items[record.Id][key]
						if value ~= nil then
							record.Object:SetAttribute(attribute, value)
						end
					end
				end
			end
		end
	end

	local function isHost(p)
		return p.Parent ~= nil and p.UserId == settings:GetAttribute("HostUserId")
	end

	function M.restoreSnapshot(p, data)
		assert(type(data) == "table" and data.Version == 1 and type(data.Settings) == "table", "Unsupported studio preset.")
		local values = data.Settings
		local scene = values.SceneSet
		assert(type(scene) == "string" and (scene == "Custom" or d.RS.PodcastRooms:FindFirstChild(scene)), "This room is unavailable.")
		-- BUILDER: validate + stage + bind (host epoch, build revision) before any yield or mutation.
		local staged = d.builderPersistence:prepareLoad(p.UserId, data)
		local filtered = {}
		for key in pairs(d.textLengths) do
			if type(values[key]) == "string" then
				filtered[key] = d.TextService:FilterStringAsync(values[key], p.UserId, Enum.TextFilterContext.PublicChat):GetNonChatStringForBroadcastAsync()
			end
		end
		assert(isHost(p), "Host controls changed while loading.")
		-- BUILDER: one transaction for room + build. begin() re-checks the binding
		-- and holds the builder lock until commit/rollback.
		local captured = captureRoom(scene)
		local txn = d.builderPersistence:begin(p.UserId, staged)
		local ok, err = pcall(function()
			txn:applyBuild()
			applyRoom(values, filtered, data.Fixtures, data.Items, scene, true)
			-- Final authority after every yield (applyAll, world swap).
			assert(isHost(p) and txn:stillAuthorized(), "Host controls changed while loading.")
		end)
		if ok then
			local result = txn:commit()
			if result.recoveryNeeded then
				latched[p.UserId] = "BuildRecovery"
			end
			return
		end
		local roomRestored = pcall(rollbackRoom, captured)
		local buildRestored = txn:rollback()
		if not (roomRestored and buildRestored) then
			latched[p.UserId] = "RollbackFailed"
			error("The studio couldn't be fully restored after a failed load. Saving is paused until a studio loads successfully.")
		end
		error(err, 0)
	end

	-- Live persistentAction with the latch and the separated list refresh.
	local persistenceBusy, persistenceLast = {}, {}
	function M.persistentAction(p, action, args)
		if type(action) ~= "string" or type(args) ~= "table" then
			return
		end
		if persistenceBusy[p] or d.clock() - (persistenceLast[p] or -100) < 2 then
			d.feedback(p, false, "Please wait a moment before another save request.")
			return
		end
		if not ({ List = true, Save = true, Load = true, Share = true, LoadCode = true, DiscardLoadBlock = true })[action] then
			return
		end
		-- BUILDER: explicit discard of the save block.
		if action == "DiscardLoadBlock" then
			latched[p.UserId] = nil
			d.remote:FireClient(p, true, "Saving is available again.")
			return
		end
		-- BUILDER: no Save/Share of unrelated or empty state after a failed load.
		if (action == "Save" or action == "Share") and latched[p.UserId] then
			d.feedback(p, false, LATCH_MESSAGE)
			return
		end
		persistenceBusy[p] = true
		persistenceLast[p] = d.clock()
		local loading = action == "Load" or action == "LoadCode"
		if loading then
			d.setLayoutBusy(true)
		end
		local ok, message, payload = pcall(function()
			if action == "List" then
				return "Saved studios refreshed.", { Slots = d.presets.List(p.UserId) }
			end
			if action == "Save" then
				local name = d.presets.Save(p.UserId, args.Slot, args.Name, M.snapshot())
				return "Saved “" .. name .. "” for future sessions."
			end
			if action == "Share" then
				return "Share this code with another host.", { Code = d.presets.Share(p.UserId, args.Slot) }
			end
			local entry = action == "Load" and d.presets.Load(p.UserId, args.Slot) or d.presets.LoadCode(args.Code)
			M.restoreSnapshot(p, entry.Data)
			return "Loaded “" .. entry.Name .. "”."
		end)
		if loading then
			d.setLayoutBusy(false)
			if ok then
				latched[p.UserId] = nil
			elseif latched[p.UserId] == nil then
				latched[p.UserId] = "LoadFailed" -- includes backend read failures
			end
		end
		-- BUILDER: refresh the slot list separately; a refresh failure must not turn a successful save into a failure.
		if ok and action == "Save" then
			local listed, slots = pcall(d.presets.List, p.UserId)
			if listed then
				payload = { Slots = slots }
			else
				message = message .. " (The slot list couldn't refresh; reopen saved studios to see it.)"
			end
		end
		persistenceBusy[p] = nil
		if ok then
			d.remote:FireClient(p, true, message, payload)
		else
			d.warn("Studio preset:", message)
			local detail = tostring(message)
			if detail:lower():find("publish") or detail:lower():find("api") or detail:lower():find("403") or detail:lower():find("datastore") then
				d.feedback(p, false, "Persistent saves are unavailable here. Use a published experience with data-store access; your current room is still active.")
			else
				d.feedback(p, false, detail:match(":%d+: (.+)$") or "The preset could not be processed. Please try again.")
			end
		end
	end

	-- Read-only view for the panel/tests.
	function M.saveBlocked(userId)
		return latched[userId]
	end

	return M
end

return DirectorPersistence
