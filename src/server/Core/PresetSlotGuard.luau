--[[
	PresetSlotGuard: overwrite rules for StudioPresets slot saves. Pure; used
	inside the UpdateAsync transform of the patched StudioPresets.Save
	(integration/StudioPresets.luau).

	A save into a slot is refused (nothing written) when:
	* CorruptProfile   the stored profile or its Slots table isn't a table
	                   (the unpatched code would replace the whole profile,
	                   losing all five slots);
	* NewerRecord      the slot's entry Version or snapshot (Data) Version is
	                   newer than 1;
	* InvalidRecord    the slot holds something that isn't a readable v1 entry
	                   (non-table entry, non-number Version, non-table Data or
	                   Settings);
	* NewerBuild       the slot holds a Build section from a newer version;
	* InvalidBuild     the slot holds a Build section that doesn't decode;
	* BuildWouldBeLost the new snapshot has no Build section (builder
	                   unavailable in this server) but the slot's Build has
	                   entries.
	Legacy slots (no Build) and readable same-version Builds may be replaced.

	transform() is retry-safe: UpdateAsync may call it several times with
	different `old` values. Each call recomputes the outcome from `old` alone,
	never mutates `old` or the entry, and getRefusal() reports the last call.
]]

local SaveSnapshot = require(script.Parent.Parent:WaitForChild("Adapters"):WaitForChild("SaveSnapshot"))

local PresetSlotGuard = {}

PresetSlotGuard.Messages = {
	CorruptProfile = "Your saved studios couldn't be read, so nothing was overwritten.",
	NewerBuild = "That slot was saved by a newer version of the builder. Choose another slot.",
	NewerRecord = "That slot was saved by a newer version of the game. Choose another slot.",
	InvalidRecord = "That slot's saved data can't be read, so it wasn't overwritten. Choose another slot.",
	InvalidBuild = "That slot's build data can't be read, so it wasn't overwritten. Choose another slot.",
	BuildWouldBeLost = "The builder isn't available here, so saving would remove that slot's build. Choose another slot.",
}

-- Returns ok, reason.
function PresetSlotGuard.checkOverwrite(old, slot, entry)
	if old == nil then
		return true
	end
	if type(old) ~= "table" then
		return false, "CorruptProfile"
	end
	local slots = rawget(old, "Slots")
	if slots == nil then
		return true
	end
	if type(slots) ~= "table" then
		return false, "CorruptProfile"
	end
	local existing = slots[tostring(slot)]
	if existing == nil then
		return true -- empty slot
	end
	if type(existing) ~= "table" or type(existing.Version) ~= "number" then
		return false, "InvalidRecord"
	end
	if existing.Version > 1 then
		return false, "NewerRecord"
	end
	if existing.Version ~= 1 then
		return false, "InvalidRecord"
	end
	local data = existing.Data
	if type(data) ~= "table" or type(data.Version) ~= "number" then
		return false, "InvalidRecord"
	end
	if data.Version > 1 then
		return false, "NewerRecord"
	end
	if data.Version ~= 1 or type(data.Settings) ~= "table" then
		return false, "InvalidRecord"
	end
	local build = data[SaveSnapshot.SECTION_KEY]
	if build == nil then
		return true -- legacy slot
	end
	local decoded, code = SaveSnapshot.decode(build)
	if decoded == nil then
		return false, code == SaveSnapshot.Codes.UnsupportedVersion and "NewerBuild" or "InvalidBuild"
	end
	local newData = type(entry) == "table" and entry.Data or nil
	local newBuild = type(newData) == "table" and newData[SaveSnapshot.SECTION_KEY] or nil
	if newBuild == nil and #decoded.items + #decoded.preserved > 0 then
		return false, "BuildWouldBeLost"
	end
	return true
end

-- A new profile with slot set to entry; `old` is never mutated.
function PresetSlotGuard.withSlot(old, slot, entry)
	local profile = {}
	if type(old) == "table" then
		for k, v in pairs(old) do
			profile[k] = v
		end
	end
	local slots = {}
	if type(profile.Slots) == "table" then
		for k, v in pairs(profile.Slots) do
			slots[k] = v
		end
	end
	slots[tostring(slot)] = entry
	profile.Slots = slots
	return profile
end

-- Returns transform(old) for UpdateAsync and getRefusal() -> reason | nil.
-- transform returns nil (cancel the write) when refused.
function PresetSlotGuard.transform(slot, entry)
	local refusal = nil
	local function transform(old)
		refusal = nil
		local ok, reason = PresetSlotGuard.checkOverwrite(old, slot, entry)
		if not ok then
			refusal = reason
			return nil
		end
		return PresetSlotGuard.withSlot(old, slot, entry)
	end
	return transform, function()
		return refusal
	end
end

function PresetSlotGuard.message(reason)
	return PresetSlotGuard.Messages[reason] or "That slot couldn't be saved."
end

return PresetSlotGuard
