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
	(4) ROOM-MUTATION GATE (review of ce59b1d). layoutBusy alone is not
	    enough: it is false while a failed load's recovery is unresolved and
	    while a background recovery attempt yields inside applyAll. Two
	    edits in the existing PodcastStudioControl remote handler.
	    I don't have that handler's source, so <player> and <action> below
	    stand for its own parameter names (the player and the first string
	    argument: "Fixture", "Item", "Set", "Preset", "Text", "Look",
	    "Transfer", "Persist").

	    (4a) Directly AFTER the existing line
	             if layoutBusy then feedback(...); return end
	         (keep that line unchanged) insert:

	             if <action> ~= "Persist" and directorPersistence.roomMutationBlocked() then
	                 feedback(<player>, false, directorPersistence.ROOM_MUTATION_MESSAGE)
	                 return
	             end

	         Every non-Persist action (Fixture, Item, Set, Preset, Text, Look,
	         Transfer) is refused while a load is in flight or recovery is
	         unresolved. Persist is left open on purpose: List still works,
	         and every Persist action retries recovery first and reports
	         RECOVERY_MESSAGE. The builder's Status op stays open too.

	    (4b) In the Text branch, the existing re-check after
	         TextService:FilterStringAsync(...):GetNonChatStringForBroadcastAsync()
	         returns (today it re-checks only the player/host) gets the gate
	         added, so a filter that was already in flight when a load or
	         recovery began can't write afterwards:

	             -- existing player/host re-check condition, then:
	             if layoutBusy or directorPersistence.roomMutationBlocked() then
	                 feedback(<player>, false, directorPersistence.ROOM_MUTATION_MESSAGE)
	                 return
	             end

	         It goes immediately before the first SetAttribute of the filtered
	         text, with no yield in between. If the Text branch has any other
	         yield before it writes, put the same check after that yield too.
	         Send me the Text branch if its shape makes the placement unclear.

	    directorPersistence is the local created by the block below. If the
	    handler function is defined above this block, forward-declare
	    `local directorPersistence` above the handler and change the block's
	    first line to an assignment (drop its `local`).
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
