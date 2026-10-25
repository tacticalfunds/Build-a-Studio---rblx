--[[
	TemplateSanitizer: makes clones of curated templates safe to place or preview.

	The curated templates are audited (no code, Seats disabled), but clones
	are sanitized again so legacy behaviour can never ride along:
	* removes all code (LuaSourceContainer) and legacy interaction objects
	  (ClickDetector, ProximityPrompt, DragDetector, remotes, bindables);
	* disables Seat / VehicleSeat (decorative furniture is not a participant
	  seat until the seat-anchor adapter exists) and turns off their touch;
	* anchors every BasePart.
	Previews additionally lose collision, query, touch, shadows, sounds,
	lights and particle effects.

	Uses only GetDescendants / IsA / Destroy and property writes, so tests can
	drive it with fake instances. Returns counts of what was changed.
]]

local TemplateSanitizer = {}

local REMOVE_ALWAYS = {
	"LuaSourceContainer",
	"ClickDetector",
	"ProximityPrompt",
	"DragDetector",
	"RemoteEvent",
	"UnreliableRemoteEvent",
	"RemoteFunction",
	"BindableEvent",
	"BindableFunction",
}

local REMOVE_FOR_PREVIEW = { "Sound", "Light", "ParticleEmitter", "Fire", "Smoke", "Sparkles", "Beam", "Trail" }

local function isAny(instance, classNames)
	for _, className in ipairs(classNames) do
		if instance:IsA(className) then
			return true
		end
	end
	return false
end

local function sanitize(model, preview)
	local counts = { removed = 0, seatsDisabled = 0, parts = 0 }
	for _, d in ipairs(model:GetDescendants()) do
		if isAny(d, REMOVE_ALWAYS) or (preview and isAny(d, REMOVE_FOR_PREVIEW)) then
			d:Destroy()
			counts.removed = counts.removed + 1
		elseif d:IsA("BasePart") then
			counts.parts = counts.parts + 1
			d.Anchored = true
			if d:IsA("Seat") or d:IsA("VehicleSeat") then
				d.Disabled = true
				d.CanTouch = false
				counts.seatsDisabled = counts.seatsDisabled + 1
			end
			if preview then
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.CastShadow = false
			end
		end
	end
	return counts
end

function TemplateSanitizer.forPlacement(model)
	return sanitize(model, false)
end

function TemplateSanitizer.forPreview(model)
	return sanitize(model, true)
end

return TemplateSanitizer
