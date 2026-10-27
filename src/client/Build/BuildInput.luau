--[[
	BuildInput: decides what a raw input means in build mode. Pure.

	The builder only LISTENS (UserInputService); it never binds or sinks
	input, so the host panel, chat and PodcastCamera keep their keys:
	* Anything while a TextBox has focus is ignored (text-entry safe).
	* Escape cancels placement/selection even if the game processed it, but
	  is never sunk, so the cursor-release safeguard still runs.
	* R rotates, left click / tap is a pointer action, only when the game did
	  not process the input (clicks on UI never place items).
	* Undo / redo shortcuts, also only for unprocessed input: Ctrl+Shift+Z
	  and Ctrl+Y redo; plain Z and Ctrl+Z undo. Redo is checked first, so
	  Ctrl+Shift+Z never undoes. Shift+Z, Alt+Z and plain Y do nothing.
	  Backspace deletes the selected item (not with Alt). The controller
	  acts once per press and only while build mode is open.
	* E/Q (free-camera vertical), right mouse (look / cursor release), 1-5, V
	  and F are never handled here. Suppressing host shortcuts is the
	  hostControls hook's job, not this module's.
]]

local BuildInput = {}

BuildInput.NeverHandled = { E = true, Q = true, One = true, Two = true, Three = true, Four = true, Five = true, V = true, F = true, MouseButton2 = true }

-- ctx: { keyCode = "R" | "Escape" | ..., inputType = "Keyboard" | "MouseButton1" | "Touch" | ...,
--        gameProcessed = boolean, textFocused = boolean,
--        ctrl = boolean?, shift = boolean?, alt = boolean? }
-- Returns "rotate" | "cancel" | "pointer" | "undo" | "redo" | "delete" | nil.
function BuildInput.classify(ctx)
	if ctx.textFocused then
		return nil
	end
	if BuildInput.NeverHandled[ctx.keyCode] or BuildInput.NeverHandled[ctx.inputType] then
		return nil
	end
	if ctx.keyCode == "Escape" then
		return "cancel"
	end
	if ctx.gameProcessed then
		return nil
	end
	if ctx.keyCode == "R" then
		return "rotate"
	end
	if ctx.keyCode == "Backspace" then
		return ctx.alt ~= true and "delete" or nil
	end
	if ctx.keyCode == "Z" or ctx.keyCode == "Y" then
		local ctrl, shift = ctx.ctrl == true, ctx.shift == true
		if ctx.alt == true then
			return nil
		end
		-- Redo first: Ctrl+Shift+Z would otherwise match the Z undo branch.
		if ctrl and ((ctx.keyCode == "Z" and shift) or (ctx.keyCode == "Y" and not shift)) then
			return "redo"
		end
		if ctx.keyCode == "Z" and not shift then
			return "undo"
		end
		return nil
	end
	if ctx.inputType == "MouseButton1" or ctx.inputType == "Touch" then
		return "pointer"
	end
	return nil
end

return BuildInput
