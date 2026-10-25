-- Asynchronous client controller behaviour (review of 3d6519f). Drives the
-- real BuildController and a real BuildModeHandoff with coroutine-based fakes
-- for the remote, drawer, ghosts and scheduler.
return function(T, H)
	local BuildController = H.load("src/client/Build/BuildController")
	local BuildModeHandoff = H.load("src/client/Adapters/BuildModeHandoff")
	local Catalog = H.load("src/shared/Catalog")
	local Config = H.load("src/shared/Config")

	local function fakeDrawer(env, callbacks)
		local d = { callbacks = callbacks, refits = {}, cancelDrags = 0, inputModes = {}, destroyed = false, x = 18, y = 178 }
		function d:setPosition(x, y) self.x, self.y = x, y end
		function d:getPosition() return self.x, self.y end
		function d:setInputMode(m) self.inputModes[#self.inputModes + 1] = m end
		function d:refit(w, h) self.refits[#self.refits + 1] = w .. "x" .. h end
		function d:cancelDrag() self.cancelDrags = self.cancelDrags + 1 end
		function d:containsPoint() return env.overDrawer end
		function d:setFilter() end
		function d:setItems(items) self.items = items end
		function d:setStatus() end
		function d:setFooter(text) self.footer = text end
		function d:refresh() end
		function d:destroy() self.destroyed = true end
		return d
	end

	local function setup()
		local env = {
			config = Config, catalog = Catalog,
			requests = {}, hold = {}, drawers = {}, ghosts = {}, spawned = {}, closed = {},
			host = true, overDrawer = false, hookLog = {}, failExit = 0, revision = 0,
		}
		local function hook(slot)
			return {
				enter = function()
					env.hookLog[#env.hookLog + 1] = slot .. ":enter"
					if env.yieldEnter == slot then
						env.yieldEnter = nil
						coroutine.yield("enter")
					end
				end,
				exit = function()
					env.hookLog[#env.hookLog + 1] = slot .. ":exit"
					if slot == "hostControls" and env.failExit > 0 then
						env.failExit = env.failExit - 1
						error("exit failed")
					end
				end,
			}
		end
		env.handoff = BuildModeHandoff.new({ hooks = { camera = hook("camera"), hostControls = hook("hostControls") } })
		-- Minimal server: revisions advance on edits; status can be forced.
		function env.respond(payload)
			if payload.op == "Status" then
				return { ok = true, status = env.forcedStatus or { state = "ready", canUndo = false, canRedo = false, revision = env.revision } }
			end
			env.revision = env.revision + 1
			local id = payload.id or ("i" .. env.revision)
			return { ok = true, id = id, status = { state = "ready", canUndo = true, canRedo = false, revision = env.revision } }
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
		function env.isHost() return env.host end
		function env.createDrawer(callbacks)
			local d = fakeDrawer(env, callbacks)
			env.drawers[#env.drawers + 1] = d
			if env.yieldCreateDrawer then
				env.yieldCreateDrawer = nil
				coroutine.yield("createDrawer") -- e.g. WaitForChild("PlayerGui")
			end
			return d
		end
		function env.previewTemplate(id) return { name = id } end
		function env.itemSize() return { 2, 2, 2 } end
		function env.createGhost(id)
			local g = { catalogId = id, shown = {}, destroyed = false }
			g.show = function(t) g.shown[#g.shown + 1] = t end
			g.destroy = function() g.destroyed = true end
			env.ghosts[#env.ghosts + 1] = g
			return g
		end
		function env.raycast(pointer) return pointer.hit end
		function env.pickPlaced(pointer) return pointer.pick end
		function env.selectedInfo() return { catalogId = "cozy_plant_01", yaw = 0 } end
		function env.mouseLocation() return env.mouse end
		function env.setSelectionHighlight(id) env.highlight = id end
		env.panel = {
			getPosition = function()
				env.getPositionCalls = (env.getPositionCalls or 0) + 1
				if env.yieldGetPosition then
					env.yieldGetPosition = nil
					coroutine.yield("getPosition")
				end
				return 50, 60
			end,
			onClosed = function(info) env.closed[#env.closed + 1] = info end,
		}
		function env.spawn(fn)
			local co = coroutine.create(fn)
			env.spawned[#env.spawned + 1] = co
			assert(coroutine.resume(co))
		end
		function env.wait() coroutine.yield("wait") end
		-- Resume every suspended background task once.
		function env.step()
			for _, co in ipairs(env.spawned) do
				if coroutine.status(co) == "suspended" then
					assert(coroutine.resume(co))
				end
			end
		end
		env.c = BuildController.new(env)
		return env
	end

	-- Runs fn in a coroutine; returns the coroutine and a getter for its results.
	local function run(fn)
		local results
		local co = coroutine.create(function()
			results = { fn() }
		end)
		assert(coroutine.resume(co))
		return co, function() return results end
	end

	local function at(x, z, pick)
		return { hit = { x = x, y = 0, z = z, upDot = 1 }, pick = pick }
	end

	local function lastRequest(env)
		return env.requests[#env.requests]
	end

	-- P1-1: late responses ------------------------------------------------------

	T.test("a Place response arriving after close does not revive the session; reopen is clean", function()
		local env = setup()
		T.eq(env.c:open(), true)
		env.c:chooseItem("cozy_plant_01")
		env.hold.Place = true
		local co = run(function() env.c:onPointerPressed(at(1, 1), "mouse", 999, 999) end)
		T.eq(lastRequest(env).op, "Place")
		env.c:close()
		assert(coroutine.resume(co)) -- success arrives late
		T.eq(env.c:isOpen(), false, "late success must not reopen the session")
		T.eq(env.c.session.mode, "closed")
		T.eq(env.c:open(), true, "next open works")
		T.eq(#env.drawers, 2, "a fresh drawer was created")
		T.eq(env.handoff:isActive(), true, "handoff entered again")
	end)

	T.test("an old response after close+reopen cannot overwrite the new selection", function()
		local env = setup()
		env.c:open()
		env.c:chooseItem("cozy_plant_01")
		env.hold.Place = true
		local co = run(function() env.c:onPointerPressed(at(1, 1), "mouse", 999, 999) end)
		env.c:close()
		env.c:open()
		env.c:onPointerPressed(at(0, 0, "i9"), "mouse", 999, 999)
		T.eq(env.c.session.selectedId, "i9")
		assert(coroutine.resume(co))
		T.eq(env.c.session.selectedId, "i9", "old Place result ignored")
		T.eq(env.c.session.mode, "selected")
		T.eq(env.c.sending, false, "new session can still send")
	end)

	-- P1-2: ghost follows the chosen item --------------------------------------

	T.test("choosing item A then B renders B's ghost and places B", function()
		local env = setup()
		env.c:open()
		env.mouse = at(2, 2)
		env.c:chooseItem("cozy_plant_01")
		env.c:tick()
		T.eq(env.ghosts[1].catalogId, "cozy_plant_01")
		env.c:chooseItem("cozy_armchair_01")
		env.c:tick()
		T.eq(env.ghosts[1].destroyed, true, "A's ghost removed")
		T.eq(env.ghosts[#env.ghosts].catalogId, "cozy_armchair_01", "B's ghost rendered")
		env.c:onPointerPressed(at(2, 2), "mouse", 999, 999)
		T.eq(lastRequest(env).itemId, "cozy_armchair_01")
	end)

	-- P1-3: cancel while opening -------------------------------------------------

	local function cancelDuringOpen(trigger)
		local env = setup()
		env.yieldEnter = "camera"
		local co, results = run(function() return env.c:open() end)
		T.eq(env.c:isOpening(), true)
		trigger(env)
		assert(coroutine.resume(co))
		T.eq(results()[1], false)
		T.eq(results()[2], "Cancelled")
		T.eq(#env.drawers, 0, "no UI created")
		T.eq(env.c:isOpen(), false)
		T.eq(env.c:isOpening(), false)
		T.eq(env.handoff:getState(), "inactive")
		T.eq(env.hookLog[#env.hookLog], "camera:exit", "camera handed back")
		T.eq(env.closed[#env.closed].cancelled, true)
		T.eq(env.c:open(), true, "a later open works")
		return env
	end

	T.test("close during a yielding handoff enter cancels the open", function()
		cancelDuringOpen(function(env) env.c:close() end)
	end)

	T.test("host loss during opening cancels it", function()
		cancelDuringOpen(function(env)
			env.host = false
			env.c:onHostChanged()
			env.host = true
		end)
	end)

	T.test("room switch and respawn during opening cancel it", function()
		cancelDuringOpen(function(env) env.c:onRoomSwitched() end)
		cancelDuringOpen(function(env) env.c:onRespawned() end)
	end)

	-- P2-4/5: input method ---------------------------------------------------------

	T.test("touchscreen with a mouse attached: taps preview, Place here confirms, mouse polling doesn't overwrite", function()
		local env = setup()
		env.c:open()
		env.c:chooseItem("cozy_plant_01")
		env.c:onPointerPressed(at(3, 4), "touch", 999, 999)
		T.eq(#env.requests, 1, "only the initial Status; a tap does not place")
		T.eq(env.drawers[1].inputModes[#env.drawers[1].inputModes], "touch", "Place here shown")
		env.mouse = at(-5, -5)
		env.c:tick()
		local ghost = env.ghosts[#env.ghosts]
		T.eq(ghost.shown[#ghost.shown].x, 3, "mouse polling did not move the touched preview")
		env.drawers[1].callbacks.onPlaceHere()
		T.eq(lastRequest(env).op, "Place")
		T.eq(lastRequest(env).transform.x, 3)
		-- Then the mouse is used: clicks place directly again.
		env.c:chooseItem("cozy_plant_01")
		env.c:onPointerMoved(at(6, 6), "mouse")
		T.eq(env.drawers[1].inputModes[#env.drawers[1].inputModes], "mouse")
		env.c:onPointerPressed(at(6, 6), "mouse", 999, 999)
		T.eq(lastRequest(env).transform.x, 6)
	end)

	T.test("Rotate button turns the preview while placing (touch has no R key)", function()
		local env = setup()
		env.c:open()
		env.c:chooseItem("cozy_plant_01")
		local before = #env.requests
		env.drawers[1].callbacks.onRotate()
		T.eq(env.c.session.previewYaw, 15)
		T.eq(#env.requests, before, "preview rotation is local")
	end)

	-- P2-6: recovery polling and stale status -------------------------------------

	T.test("a Status poll from a previous session cannot overwrite the new one", function()
		local env = setup()
		env.forcedStatus = { state = "recovery", revision = 0 }
		env.c:open()
		T.eq(env.c.session.paused, true)
		env.hold.Status = true
		local before = #env.requests
		env.step() -- the poll wakes, sends Status and stays suspended inside the request
		T.eq(#env.requests, before + 1)
		T.eq(lastRequest(env).op, "Status")
		T.eq(env.hold.Status, nil, "the poll's Status is the one being held")
		env.c:close()
		env.forcedStatus = nil
		env.c:open()
		T.eq(env.c.session.paused, false)
		env.forcedStatus = { state = "recovery", revision = 0 }
		env.step() -- the old poll's Status returns "recovery"
		env.forcedStatus = nil
		T.eq(env.c.session.paused, false, "old session's result ignored")
	end)

	T.test("status older than the newest known revision is ignored", function()
		local env = setup()
		env.c:open()
		env.c:chooseItem("cozy_plant_01")
		env.c:onPointerPressed(at(1, 1), "mouse", 999, 999) -- revision 1
		T.eq(env.c.session.revision, 1)
		env.c.session:applyResponse("Status", { ok = true, status = { state = "recovery", canUndo = false, revision = 0 } })
		T.eq(env.c.session.paused, false)
		T.eq(env.c.session.canUndo, true)
	end)

	T.test("the initial Status during open is discarded if the session closes first", function()
		local env = setup()
		env.hold.Status = true
		local co, results = run(function() return env.c:open() end)
		env.c:close()
		env.forcedStatus = { state = "recovery", revision = 0 }
		assert(coroutine.resume(co))
		T.eq(env.c:isOpen(), false)
		T.eq(env.c.session.paused, false)
		T.ok(results() ~= nil)
	end)

	-- P2-7: handoff cleanup failures ------------------------------------------------

	T.test("a failed handoff exit is reported, retried, and blocks open until it succeeds", function()
		local env = setup()
		env.c:open()
		env.failExit = 2
		env.c:close()
		T.eq(env.closed[#env.closed].cleanupFailed, true, "reported to the panel")
		T.eq(env.handoff:hasPendingCleanup(), true)
		local ok, reason = env.c:open()
		T.eq(ok, false)
		T.eq(reason, "CleanupPending", "retry on open failed once more")
		env.step() -- background retry succeeds
		T.eq(env.handoff:hasPendingCleanup(), false)
		T.eq(env.c:open(), true)
	end)

	T.test("a stale cleanup worker never exits a newer active handoff", function()
		local env = setup()
		env.c:open()
		env.failExit = 1 -- the close's exit fails once
		env.c:close()
		T.eq(env.handoff:hasPendingCleanup(), true)
		-- The background worker is now waiting. The user reopens: open() retries
		-- cleanup successfully and enters a NEW handoff.
		T.eq(env.c:open(), true)
		T.eq(env.handoff:isActive(), true)
		local exitsBefore = 0
		for _, entry in ipairs(env.hookLog) do
			if entry:find(":exit") then exitsBefore = exitsBefore + 1 end
		end
		env.step() -- the old worker wakes
		env.step()
		local exitsAfter = 0
		for _, entry in ipairs(env.hookLog) do
			if entry:find(":exit") then exitsAfter = exitsAfter + 1 end
		end
		T.eq(exitsAfter, exitsBefore, "the stale worker must not run exit hooks")
		T.eq(env.handoff:isActive(), true, "new handoff remains active")
		T.eq(env.c:isOpen(), true)
		T.eq(env.drawers[#env.drawers].destroyed, false, "drawer still usable")
		env.c:chooseItem("cozy_plant_01")
		env.c:onPointerPressed(at(1, 1), "mouse", 999, 999)
		T.eq(lastRequest(env).op, "Place", "edits still go through")
	end)

	T.test("a newer cleanup worker is not cancelled by an older one finishing", function()
		local env = setup()
		env.c:open()
		env.failExit = 3
		env.c:close() -- fails (1), worker A scheduled
		env.c:close() -- retry while closed fails (2), worker B scheduled
		env.step() -- both wake: the stale one must just stop; the current one retries (3) and fails
		T.eq(env.handoff:hasPendingCleanup(), true)
		env.step() -- the current worker retries again and succeeds
		T.eq(env.handoff:hasPendingCleanup(), false, "cleanup eventually completes")
		T.eq(env.c:open(), true)
	end)

	T.test("close() while closed retries pending cleanup", function()
		local env = setup()
		env.c:open()
		env.failExit = 1
		env.c:close()
		T.eq(env.handoff:hasPendingCleanup(), true)
		env.c:close()
		T.eq(env.handoff:hasPendingCleanup(), false)
	end)

	-- Follow-up regressions (review of f6facd3) -----------------------------------------

	T.test("a pending Place for item A does not overwrite a newer choice of item B", function()
		local env = setup()
		env.c:open()
		env.mouse = at(1, 1)
		env.c:chooseItem("cozy_plant_01")
		env.c:tick()
		env.hold.Place = true
		local co = run(function() env.c:onPointerPressed(at(1, 1), "mouse", 999, 999) end)
		T.eq(lastRequest(env).itemId, "cozy_plant_01")
		env.c:chooseItem("cozy_armchair_01") -- user picks B while A's Place is in flight
		assert(coroutine.resume(co)) -- A succeeds
		local session = env.c.session
		T.eq(session.itemId, "cozy_armchair_01", "B is still being placed")
		T.eq(session.mode, "placing")
		T.eq(session.canUndo, true, "status from A's response still applied")
		T.eq(session.revision, 1)
		env.c:tick()
		T.eq(env.ghosts[#env.ghosts].catalogId, "cozy_armchair_01", "B's preview kept")
		T.eq(env.ghosts[#env.ghosts].destroyed, false)
		env.c:onPointerPressed(at(4, 4), "mouse", 999, 999)
		T.eq(lastRequest(env).itemId, "cozy_armchair_01", "B can be placed next")
	end)

	T.test("without a newer choice, a Place response still selects the placed item", function()
		local env = setup()
		env.c:open()
		env.c:chooseItem("cozy_plant_01")
		env.c:onPointerPressed(at(1, 1), "mouse", 999, 999)
		T.eq(env.c.session.mode, "selected")
		T.eq(env.c.session.selectedId, "i1")
	end)

	T.test("close during a yielding createDrawer destroys the returned drawer", function()
		local env = setup()
		env.yieldCreateDrawer = true
		local co, results = run(function() return env.c:open() end)
		T.eq(#env.drawers, 1, "creation started")
		env.c:close()
		T.eq(env.handoff:getState(), "inactive", "handoff exited by close")
		assert(coroutine.resume(co))
		T.eq(results()[1], false)
		T.eq(results()[2], "Cancelled")
		T.eq(env.drawers[1].destroyed, true, "returned UI destroyed")
		T.eq(env.getPositionCalls, nil, "a cancelled open never calls into the panel")
		T.eq(env.c:isOpen(), false)
		T.eq(env.c.drawer, nil)
		T.eq(env.handoff:getState(), "inactive", "stale open did not re-enter anything")
	end)

	T.test("close + reopen while the first drawer creation is pending", function()
		local env = setup()
		env.yieldCreateDrawer = true
		local co, results = run(function() return env.c:open() end)
		env.c:close()
		T.eq(env.c:open(), true, "second open completes")
		local second = env.drawers[2]
		assert(coroutine.resume(co)) -- the first creation finishes late
		T.eq(results()[2], "Cancelled")
		T.eq(env.drawers[1].destroyed, true, "stale drawer destroyed")
		T.eq(second.destroyed, false, "new session's drawer untouched")
		T.eq(env.c.drawer, second)
		T.eq(env.c:isOpen(), true)
		T.eq(env.handoff:isActive(), true, "new handoff still active")
	end)

	T.test("close during a yielding panel.getPosition destroys the drawer", function()
		local env = setup()
		env.yieldGetPosition = true
		local co, results = run(function() return env.c:open() end)
		env.c:close()
		assert(coroutine.resume(co))
		T.eq(results()[2], "Cancelled")
		T.eq(env.drawers[1].destroyed, true)
		T.eq(env.c:isOpen(), false)
		T.eq(env.handoff:getState(), "inactive")
	end)

	-- UI findings --------------------------------------------------------------------

	T.test("presses on the drawer never reach the world, whatever gameProcessed says", function()
		local env = setup()
		env.c:open()
		env.overDrawer = true
		env.c:onPointerPressed(at(0, 0, "i1"), "mouse", 30, 300)
		T.eq(env.c.session.selectedId, nil)
		env.c:chooseItem("cozy_plant_01")
		local before = #env.requests
		env.c:onPointerPressed(at(0, 0), "mouse", 30, 300)
		T.eq(#env.requests, before, "no placement through the drawer")
	end)

	T.test("viewport changes refit the drawer; focus loss cancels drag", function()
		local env = setup()
		env.c:open()
		env.c:onViewportChanged(844, 390)
		T.eq(env.drawers[1].refits[1], "844x390")
		env.c:onFocusLost()
		T.eq(env.drawers[1].cancelDrags, 1)
	end)

	T.test("the drawer opens at the panel position and reports its position on close", function()
		local env = setup()
		env.c:open()
		T.eq(env.drawers[1].x, 50)
		T.eq(env.drawers[1].y, 60)
		env.c:close()
		T.eq(env.closed[1].x, 50)
		T.eq(env.closed[1].y, 60)
	end)
end
