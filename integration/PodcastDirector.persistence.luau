--[[
	STUDIO BUILDER PATCH (task 5, corrected) for PodcastDirector — NOT a
	standalone script. Install integration/DirectorPersistence.luau as a
	ModuleScript named "DirectorPersistence" next to PodcastDirector, then
	make these edits in the Director:

	(1) DELETE the existing local functions snapshot(), restoreSnapshot() and
	    persistentAction() (their logic now lives in DirectorPersistence,
	    unchanged except the documented fixes).
	(2) INSERT the block below at the place where persistentAction() was
	    defined (after every local it references exists: settings, defaults,
	    groupKeys, textLengths, bounds, layoutBounds, atmosphereBounds,
	    atmosphereKeys, fixtureAttributes, itemAttributes, itemBounds,
	    finite, roomLooks, lighting, customization, rememberLighting, applyAll,
	    applyDecor, getState, studio, presets, remote, feedback, layoutBusy).
	    The names snapshot / restoreSnapshot / persistentAction stay bound, so
	    the existing remote handler ("Persist" -> persistentAction) and any
	    other callers keep working.
	(3) Optional UI: a "Discard" control that sends
	    PodcastStudioControl:FireServer("Persist", "DiscardLoadBlock", {}) to
	    lift the save block after a failed load (Codex wires the panel).
]]

local directorPersistence = require(script.Parent:WaitForChild("DirectorPersistence")).new({
	settings = settings,
	defaults = defaults,
	groupKeys = groupKeys,
	textLengths = textLengths,
	bounds = bounds,
	layoutBounds = layoutBounds,
	atmosphereBounds = atmosphereBounds,
	atmosphereKeys = atmosphereKeys,
	fixtureAttributes = fixtureAttributes,
	itemAttributes = itemAttributes,
	itemBounds = itemBounds,
	finite = finite,
	lighting = lighting,
	customization = customization,
	rememberLighting = rememberLighting,
	applyAll = applyAll,
	applyDecor = applyDecor,
	getState = getState,
	studio = studio,
	RS = RS,
	TextService = TextService,
	presets = presets,
	remote = remote,
	feedback = feedback,
	setLayoutBusy = function(value)
		layoutBusy = value
	end,
	builderPersistence = require(game:GetService("ServerScriptService"):WaitForChild("StudioBuilder"):WaitForChild("Runtime"):WaitForChild("BuilderService")).getPersistence(),
	clock = os.clock,
	warn = warn,
	-- rememberLighting's cache (live: local roomLooks = {}), so a failed load restores it exactly.
	getRoomLook = function(scene)
		return roomLooks[scene]
	end,
	setRoomLook = function(scene, look)
		roomLooks[scene] = look
	end,
})
local snapshot = directorPersistence.snapshot
local restoreSnapshot = directorPersistence.restoreSnapshot
local persistentAction = directorPersistence.persistentAction
