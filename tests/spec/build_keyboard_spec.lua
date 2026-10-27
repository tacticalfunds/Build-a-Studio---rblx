-- Build keyboard controls: undo/redo shortcuts (modifier precedence), Backspace
-- delete, hold-to-rotate timing and every stop condition, and text-entry
-- suppression. Drives the real BuildInput and BuildController with fakes for
-- the remote, drawer, ghosts, clock and scheduler.
return function(T, H)
	local BuildInput = H.load("src/client/Build/BuildInput")
	local BuildController = H.load("src/client/Build/BuildController")
	local BuildModeHandoff = H.load("src/client/Adapters/BuildModeHandoff")
	local Catalog = H.load("src/shared/Catalog")
	local Config = H.load("src/shared/Config")

	local function key(keyCode, mods, gameProcessed, textFocused)
		mods = mods or {}
		return BuildInput.classify({
			keyCode = keyCode, inputType = "Keyboard", gameProcessed = gameProcessed == true, textFocused = textFocused == true,
			ctrl = mods.ctrl, shift = mods.shift, alt = mods.alt,
		})
	end

	local function setup()
		local env = { config = Config, catalog = Catalog, requests = {}, hold = {}, spawned = {}, now = 0, typing = false, revision = 0 }
		local function hook() return { enter = function() end, exit = function() end } end
		env.handoff = BuildModeHandoff.new({ hooks = { camera = hook(), hostControls = hook() } })
		function env.respond(payload)
			if payload.op == "Status" then
				return { ok = true, status = { state = "ready", canUndo = false, canRedo = false, revision = env.revision } }
			end
			if env.fail and env.fail[payload.op] then
				return { ok = false, code = env.fail[payload.op], status = { state = "ready", canUndo = true, canRedo = false, revision = env.revision } }
			end
			env.revision = env.revision + 1
			local redo = payload.op == "Undo"
			return { ok = true, id = payload.id or ("i" .. env.revision), status = { state = "ready", canUndo = true, canRedo = redo, revision = env.revision } }
		end
		function env.request(payload)
			env.requests[#env.requests + 1] = payload
			if env.hold[payload.op] then
				env.hold[payload.op] = nil
				coroutine.yield("request")
			end
			return env.respond(payload)
		end
		function env.readSandbox() return { origin = "O", bounds = { halfX = 20, halfZ = 15, height = 16 } } end
		function env.isHost() return true end
		function env.createDrawer(callbacks)
			local d = { callbacks = callbacks }
			for _, m in ipairs({ "setInputMode", "refit", "cancelDrag", "setFilter", "setCategory", "showTypes", "showTypeItems", "hideTypes", "setItems", "setStatus", "setFooter", "refresh", "destroy", "setPosition" }) do
				d[m] = function() end
			end
			function d:getPosition() return 18, 178 end
			function d:containsPoint() return false end
			env.drawer = d
			return d
		end
		function env.previewTemplate(id) return { name = id } end
		function env.itemSize() return { 2, 2, 2 } end
		function env.createGhost(id) return { catalogId = id, show = function() end, destroy = function() end } end
		function env.raycast(pointer) return pointer.hit end
		function env.pickPlaced(pointer) return pointer.pick end
		function env.selectedInfo() return { catalogId = "cozy_plant_01", yaw = 0 } end
		function env.mouseLocation() return { hit = { x = 0, y = 0, z = 0, upDot = 1 } } end
		function env.setSelectionHighlight() end
		function env.spawn(fn)
			local co = coroutine.create(fn)
			env.spawned[#env.spawned + 1] = co
			assert(coroutine.resume(co))
		end
		function env.wait() coroutine.yield("wait") end
		function env.clock() return env.now end
		function env.textFocused() return env.typing end
		function env.resumeAll()
			for _, co in ipairs(env.spawned) do
				if coroutine.status(co) == "suspended" then assert(coroutine.resume(co)) end
			end
		end
		env.c = BuildController.new(env)
		function env.at(t) env.now = t; env.c:tick() end
		function env.count(op)
			local n = 0
			for _, r in ipairs(env.requests) do if r.op == op then n = n + 1 end end
			return n
		end
		return env
	end
	local function selectItem(env, id)
		env.c:onPointerPressed({ pick = id }, "mouse", 900, 500)
		T.eq(env.c.session.mode, "selected")
		T.eq(env.c.session.selectedId, id)
	end
	local function placed(env)
		-- One real edit so the server status allows Undo.
		env.c:chooseItem("cozy_plant_01")
		env.c:onPointerPressed({ hit = { x = 0, y = 0, z = 0, upDot = 1 } }, "mouse", 900, 500)
		T.eq(env.c.session.canUndo, true)
	end

	-- Classification -------------------------------------------------------------------------

	T.test("shortcut mapping: redo modifiers are checked before the Z undo branch", function()
		T.eq(key("Z"), "undo", "plain Z")
		T.eq(key("Z", { ctrl = true }), "undo", "Ctrl+Z")
		T.eq(key("Z", { ctrl = true, shift = true }), "redo", "Ctrl+Shift+Z is redo, never undo")
		T.eq(key("Y", { ctrl = true }), "redo", "Ctrl+Y")
		T.eq(key("Y"), nil, "plain Y does nothing")
		T.eq(key("Y", { ctrl = true, shift = true }), nil, "Ctrl+Shift+Y does nothing")
		T.eq(key("Z", { shift = true }), nil, "Shift+Z does nothing")
		T.eq(key("Z", { alt = true }), nil, "Alt+Z does nothing")
		T.eq(key("Z", { ctrl = true, alt = true }), nil)
		T.eq(key("Backspace"), "delete")
		T.eq(key("Backspace", { alt = true }), nil)
		T.eq(key("R"), "rotate", "R unchanged")
	end)

	T.test("text entry and processed input never trigger build shortcuts", function()
		for _, case in ipairs({ { "Z" }, { "Z", { ctrl = true } }, { "Z", { ctrl = true, shift = true } }, { "Y", { ctrl = true } }, { "Backspace" }, { "R" } }) do
			T.eq(key(case[1], case[2], false, true), nil, case[1] .. " while typing")
			T.eq(key(case[1], case[2], true, false), nil, case[1] .. " processed by the game (chat, UI)")
		end
		T.eq(key("Escape", nil, true, false), "cancel", "Escape still cancels when processed (unchanged)")
	end)

	-- Undo / redo ---------------------------------------------------------------------------

	T.test("undo/redo keys: only while open, only when allowed, once per press, through the button command", function()
		local env = setup()
		T.eq(env.c:onKeyPressed("undo", "Z"), nil, "closed: nothing")
		env.c:onKeyReleased("Z")
		T.eq(#env.requests, 0)
		env.c:open()
		local before = #env.requests
		env.c:onKeyPressed("undo", "Z")
		env.c:onKeyReleased("Z")
		T.eq(#env.requests, before, "nothing to undo: no request")
		placed(env)
		env.c:onKeyPressed("undo", "Z")
		T.deepEq(env.requests[#env.requests], { op = "Undo", expectedRevision = env.c.session.revision - 1 }, "same payload as the Undo button")
		env.c:onKeyPressed("undo", "Z")
		env.c:onKeyPressed("undo", "Z")
		T.eq(env.count("Undo"), 1, "a held Z acts once")
		env.c:onKeyReleased("Z")
		T.eq(env.c.session.canRedo, true)
		env.c:onKeyPressed("redo", "Y")
		T.eq(env.requests[#env.requests].op, "Redo")
		env.c:onKeyPressed("redo", "Y")
		T.eq(env.count("Redo"), 1, "a held Ctrl+Y acts once")
		env.c:onKeyReleased("Y")
		-- The drawer buttons run the same commands.
		env.c:onKeyPressed("undo", "Z")
		env.c:onKeyReleased("Z")
		env.drawer.callbacks.onRedo()
		T.eq(env.count("Redo"), 2)
	end)

	T.test("undo/redo keys respect the busy state: nothing is queued while an edit is in flight", function()
		local env = setup()
		env.c:open()
		placed(env)
		env.hold.Undo = true
		local co = coroutine.create(function() env.c:onKeyPressed("undo", "Z") end)
		assert(coroutine.resume(co))
		T.eq(env.c.sending, true)
		env.c:onKeyReleased("Z")
		env.c:onKeyPressed("undo", "Z")
		env.c:onKeyPressed("redo", "Y")
		T.eq(env.count("Undo"), 1)
		T.eq(env.count("Redo"), 0)
		assert(coroutine.resume(co))
		T.eq(env.c.sending, false)
	end)

	-- Backspace delete ------------------------------------------------------------------------

	T.test("Backspace deletes only the selected item, once per press, and the delete can be undone", function()
		local env = setup()
		env.c:onKeyPressed("delete", "Backspace")
		env.c:onKeyReleased("Backspace")
		T.eq(env.count("Delete"), 0, "closed: nothing")
		env.c:open()
		env.c:onKeyPressed("delete", "Backspace")
		env.c:onKeyReleased("Backspace")
		T.eq(env.count("Delete"), 0, "no selection: nothing")
		selectItem(env, "i7")
		env.c:onKeyPressed("delete", "Backspace")
		T.deepEq(env.requests[#env.requests], { op = "Delete", id = "i7" }, "same payload as the Delete button")
		T.eq(env.c.session.selectedId, nil, "the selection is cleared by the delete")
		env.c:onKeyPressed("delete", "Backspace")
		T.eq(env.count("Delete"), 1, "holding Backspace never cascades")
		env.c:onKeyReleased("Backspace")
		env.c:onKeyPressed("delete", "Backspace")
		T.eq(env.count("Delete"), 1, "nothing left selected: nothing")
		env.c:onKeyReleased("Backspace")
		T.eq(env.c.session.canUndo, true)
		env.c:onKeyPressed("undo", "Z")
		T.eq(env.requests[#env.requests].op, "Undo", "the delete is undoable with Z")
	end)

	T.test("Backspace does nothing while placing, moving, read-only or busy", function()
		local env = setup()
		env.c:open()
		env.c:chooseItem("cozy_plant_01")
		env.c:onKeyPressed("delete", "Backspace")
		env.c:onKeyReleased("Backspace")
		env.c:cancel()
		selectItem(env, "i3")
		env.c:beginMove()
		T.eq(env.c.session.mode, "moving")
		env.c:onKeyPressed("delete", "Backspace")
		env.c:onKeyReleased("Backspace")
		env.c:cancel()
		T.eq(env.c.session.mode, "selected")
		env.c.session.readOnly = true
		env.c:onKeyPressed("delete", "Backspace")
		env.c:onKeyReleased("Backspace")
		env.c.session.readOnly = false
		env.hold.Duplicate = true
		local co = coroutine.create(function() env.drawer.callbacks.onDuplicate() end)
		assert(coroutine.resume(co))
		env.c:onKeyPressed("delete", "Backspace")
		T.eq(env.count("Delete"), 0)
		assert(coroutine.resume(co))
	end)

	-- Hold to rotate -------------------------------------------------------------------------

	T.test("R: a tap turns once; a hold repeats after the initial delay at the repeat interval; release stops it", function()
		local env = setup()
		env.c:open()
		env.c:chooseItem("cozy_plant_01")
		local s = env.c.session
		env.c:onKeyPressed("rotate", "R")
		T.eq(s.previewYaw, 15, "one turn on press")
		env.c:onKeyPressed("rotate", "R")
		T.eq(s.previewYaw, 15, "a repeated key-down without release is ignored")
		env.at(0.2)
		T.eq(s.previewYaw, 15, "nothing before the initial delay")
		env.at(0.35)
		T.eq(s.previewYaw, 30, "first repeat at the delay")
		env.at(0.5)
		T.eq(s.previewYaw, 30)
		env.at(0.55)
		T.eq(s.previewYaw, 45, "then at the repeat interval")
		env.c:onKeyReleased("R")
		env.at(2)
		T.eq(s.previewYaw, 45, "release stops it immediately")
		-- A quick tap: down and up before the delay is exactly one turn.
		env.c:onKeyPressed("rotate", "R")
		env.c:onKeyReleased("R")
		env.at(3)
		T.eq(s.previewYaw, 60)
		T.eq(BuildController.RotateHold.delay, 0.35)
		T.eq(BuildController.RotateHold.interval, 0.2)
		T.ok(1 / BuildController.RotateHold.interval <= Config.RateLimits.edit.refillPerSecond, "held Rotate requests stay under the edit refill rate")
	end)

	T.test("R hold after a lag spike turns once, not a catch-up burst; structure pieces keep their 90-degree step", function()
		local env = setup()
		env.c:open()
		env.c:chooseItem("cozy_plant_01")
		local s = env.c.session
		env.c:onKeyPressed("rotate", "R")
		env.at(5)
		T.eq(s.previewYaw, 30, "one turn after a 5 s stall")
		env.at(5.1)
		T.eq(s.previewYaw, 30)
		env.at(5.2)
		T.eq(s.previewYaw, 45)
		env.c:onKeyReleased("R")
		env.c:setCategory("structure")
		env.c:chooseItem("structure_wall_01")
		env.now = 10
		env.c:onKeyPressed("rotate", "R")
		T.eq(s.previewYaw, 90)
		env.at(10.35)
		T.eq(s.previewYaw, 180, "the repeat uses the same snap step as a tap")
		env.c:onKeyReleased("R")
	end)

	T.test("R hold stops on focus loss, text focus, cancel, close, target change and loss of edit rights", function()
		local function holding()
			local env = setup()
			env.c:open()
			env.c:chooseItem("cozy_plant_01")
			env.c:onKeyPressed("rotate", "R")
			T.ok(env.c.rotateHold ~= nil)
			return env, env.c.session
		end
		local env, s = holding()
		env.c:onFocusLost()
		env.at(1)
		T.eq(s.previewYaw, 15, "focus loss")
		env.c:onKeyPressed("rotate", "R")
		T.eq(s.previewYaw, 30, "after focus loss the key-down state is reset, so a new press works")
		env, s = holding()
		env.c:onTextFocused()
		env.at(1)
		T.eq(s.previewYaw, 15, "a TextBox took focus")
		env, s = holding()
		env.typing = true
		env.at(1)
		T.eq(s.previewYaw, 15, "text focus seen by tick")
		T.eq(env.c.rotateHold, nil)
		env, s = holding()
		env.c:cancel()
		env.c:chooseItem("cozy_plant_01")
		env.at(1)
		T.eq(env.c.rotateHold, nil, "cancel")
		env, s = holding()
		env.c:close()
		T.eq(env.c.rotateHold, nil, "close")
		env.c:open()
		env.c:chooseItem("cozy_plant_01")
		env.at(1)
		T.eq(env.c.session.previewYaw, 0, "nothing turns after reopening")
		env, s = holding()
		env.c:chooseItem("cozy_armchair_01")
		env.at(1)
		T.eq(s.previewYaw, 0, "a new target is not turned by the old hold")
		T.eq(env.c.rotateHold, nil)
		env, s = holding()
		s.readOnly = true
		env.at(1)
		T.eq(env.c.rotateHold, nil, "host permission lost")
		env, s = holding()
		s.paused = true
		env.at(1)
		T.eq(env.c.rotateHold, nil, "recovery pause")
	end)

	T.test("R hold on a selected item: Rotate requests never queue up; a failure, a delete or a deselect stops the hold", function()
		local env = setup()
		env.c:open()
		selectItem(env, "i4")
		env.c:onKeyPressed("rotate", "R")
		T.deepEq(env.requests[#env.requests], { op = "Rotate", id = "i4" })
		env.hold.Rotate = true
		env.at(0.35)
		T.eq(env.count("Rotate"), 2, "first repeat sent")
		T.eq(env.c.sending, true, "and still in flight")
		env.at(0.6)
		env.at(0.9)
		env.at(1.5)
		T.eq(env.count("Rotate"), 2, "nothing more while the request is in flight")
		env.resumeAll()
		env.at(1.5)
		T.eq(env.count("Rotate"), 3, "one more once it returns, not a burst")
		env.at(1.6)
		T.eq(env.count("Rotate"), 3)
		-- A failed Rotate (e.g. out of bounds) stops the hold.
		env.fail = { Rotate = "OutOfBounds" }
		env.at(1.7)
		T.eq(env.count("Rotate"), 4)
		T.eq(env.c.rotateHold, nil)
		env.at(3)
		T.eq(env.count("Rotate"), 4)
		env.fail = nil
		env.c:onKeyReleased("R")
		-- Backspace while holding R deletes once and ends the hold.
		env.c:onKeyPressed("rotate", "R")
		env.c:onKeyPressed("delete", "Backspace")
		T.eq(env.count("Delete"), 1)
		T.eq(env.c.rotateHold, nil)
		env.at(5)
		T.eq(env.count("Rotate"), 5, "no Rotate after the delete")
		env.c:onKeyReleased("R")
		env.c:onKeyReleased("Backspace")
		-- Clearing the selection (a click on empty floor) ends the hold.
		selectItem(env, "i9")
		env.c:onKeyPressed("rotate", "R")
		env.c:onPointerPressed({ pick = nil }, "mouse", 900, 500)
		env.at(7)
		T.eq(env.count("Rotate"), 6)
		T.eq(env.c.rotateHold, nil)
	end)
end
