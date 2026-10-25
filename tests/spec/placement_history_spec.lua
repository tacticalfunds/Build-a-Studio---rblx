-- Server-authoritative undo/redo: exact logical IDs, same validation/lock/
-- recovery path as normal edits, conflicts dropped without touching the world,
-- history invalidated on host transfer, stale revisions and recovery.
return function(T, H)
	local PlacementCore = H.load("src/server/Core/PlacementCore")
	local Catalog = H.load("src/shared/Catalog")
	local Config = H.load("src/shared/Config")

	local HOST, OTHER = 1001, 2002
	local SIZES = {
		cozy_plant_01 = { 2.93, 5.72, 2.93 },
		cozy_bookshelf_01 = { 6.22, 12.14, 1.59 },
		cozy_armchair_01 = { 5.0, 4.73, 4.25 },
	}

	local function fakeWorld()
		local w = { live = {}, calls = {}, failApply = nil, failRollback = 0, yieldOn = {}, onApply = nil }
		local function copy(r)
			return { itemId = r.itemId, x = r.x, y = r.y, z = r.z, yaw = r.yaw }
		end
		function w:apply(effect)
			self.calls[#self.calls + 1] = "apply:" .. effect.kind .. ":" .. effect.id
			if self.onApply then
				self.onApply(effect)
			end
			if self.yieldOn[effect.kind] then
				self.yieldOn[effect.kind] = nil
				coroutine.yield()
			end
			if self.failApply == effect.kind then
				error("world failure")
			end
			local previous = self.live[effect.id]
			if effect.kind == "spawn" then
				assert(previous == nil, "spawn over an existing model " .. effect.id)
				self.live[effect.id] = copy(effect.record)
			elseif effect.kind == "move" then
				self.live[effect.id] = copy(effect.to)
			else
				self.live[effect.id] = nil
			end
			return { id = effect.id, previous = previous }
		end
		function w:rollback(token)
			self.calls[#self.calls + 1] = "rollback:" .. token.id
			if self.failRollback > 0 then
				self.failRollback = self.failRollback - 1
				error("rollback failed")
			end
			self.live[token.id] = token.previous
		end
		function w:commit() end
		function w:reconcile(entries)
			self.live = {}
			for _, e in ipairs(entries) do
				self.live[e.id] = copy(e.record)
			end
		end
		function w:publishRevision() end
		return w
	end

	local function setup(options)
		options = options or {}
		local env = { host = HOST, now = 0, installed = {}, locked = {} }
		for id in pairs(SIZES) do
			env.installed[id] = true
		end
		local config = setmetatable({ HistoryLimit = options.historyLimit or Config.HistoryLimit }, { __index = Config })
		env.world = fakeWorld()
		env.core = PlacementCore.new({
			config = config,
			catalog = Catalog,
			templates = {
				isInstalled = function(id) return env.installed[id] == true end,
				getSize = function(id)
					local s = env.installed[id] and SIZES[id]
					return s and { s[1], s[2], s[3] } or nil
				end,
			},
			-- Called as entitlements:isItemUnlocked(userId, item, catalog).
			entitlements = { isItemUnlocked = function(_, _, item) return not env.locked[item.id] end },
			authority = { check = function(_, userId) return userId == env.host end },
			bounds = { halfX = 20, halfZ = 15, height = 16 },
			world = env.world,
			clock = function() return env.now end,
		})
		function env.req(payload, userId)
			env.now = env.now + 1
			return env.core:handle(userId or HOST, payload)
		end
		function env.place(itemId, x, z, yaw)
			return env.req({ op = "Place", itemId = itemId or "cozy_plant_01", transform = { x = x or 0, y = 0, z = z or 0, yaw = yaw or 0 } })
		end
		function env.undo(extra, userId)
			local p = { op = "Undo" }
			for k, v in pairs(extra or {}) do p[k] = v end
			return env.req(p, userId)
		end
		function env.redo(extra, userId)
			local p = { op = "Redo" }
			for k, v in pairs(extra or {}) do p[k] = v end
			return env.req(p, userId)
		end
		return env
	end

	local function state(env)
		local parts = { "rev=" .. env.core:getRevision() }
		for _, e in ipairs(env.core:list()) do
			local r = e.record
			parts[#parts + 1] = string.format("%s:%s:%.2f,%.2f,%.2f,%g", e.id, r.itemId, r.x, r.y, r.z, r.yaw)
		end
		local live = {}
		for id, r in pairs(env.world.live) do
			live[#live + 1] = string.format("%s:%.2f,%.2f,%g", id, r.x, r.z, r.yaw)
		end
		table.sort(live)
		parts[#parts + 1] = "world=" .. table.concat(live, ";")
		return table.concat(parts, "|")
	end

	local function consistent(env)
		local n = 0
		for _, e in ipairs(env.core:list()) do
			local live = env.world.live[e.id]
			T.ok(live ~= nil, e.id .. " missing from world")
			T.eq(live.x, e.record.x)
			T.eq(live.z, e.record.z)
			T.eq(live.yaw, e.record.yaw)
			n = n + 1
		end
		for id in pairs(env.world.live) do
			T.ok(env.core.model:get(id) ~= nil, id .. " in world but not in model")
		end
	end

	T.test("undo/redo of a place restores the exact logical ID and transform", function()
		local env = setup()
		env.place("cozy_armchair_01", 3, -2, 45)
		local placed = state(env)
		local u = env.undo()
		T.eq(u.ok, true)
		T.eq(u.id, "i1")
		T.eq(#env.core:list(), 0)
		T.eq(u.status.canRedo, true)
		T.eq(u.status.canUndo, false)
		local r = env.redo()
		T.eq(r.ok, true)
		T.eq(r.id, "i1", "redo brings back i1, not a new ID")
		T.eq(state(env):gsub("^rev=%d+", ""), placed:gsub("^rev=%d+", ""), "same item, same transform")
		T.eq(env.core:getRevision(), 3, "each step is a committed revision")
		consistent(env)
	end)

	T.test("undo of a delete restores the same ID; later places never reuse IDs", function()
		local env = setup()
		env.place("cozy_plant_01", 0, 0)
		env.place("cozy_plant_01", 5, 0)
		env.req({ op = "Delete", id = "i1" })
		T.eq(env.undo().id, "i1")
		T.ok(env.core.model:get("i1") ~= nil)
		T.eq(env.place("cozy_plant_01", -5, 0).id, "i3")
		consistent(env)
	end)

	T.test("move, rotate and duplicate undo/redo", function()
		local env = setup()
		env.place("cozy_plant_01", 0, 0)
		env.req({ op = "Move", id = "i1", transform = { x = 4, y = 0, z = 2, yaw = 0 } })
		env.req({ op = "Rotate", id = "i1" })
		env.req({ op = "Duplicate", id = "i1" })
		T.eq(#env.core:list(), 2)
		env.undo() -- duplicate
		T.eq(#env.core:list(), 1)
		env.undo() -- rotate
		T.eq(env.core.model:get("i1").yaw, 0)
		env.undo() -- move
		T.eq(env.core.model:get("i1").x, 0)
		env.redo()
		env.redo()
		local r = env.core.model:get("i1")
		T.eq(r.x, 4)
		T.eq(r.yaw, 15)
		env.redo()
		T.ok(env.core.model:get("i2") ~= nil, "duplicate restored with its original ID")
		consistent(env)
	end)

	T.test("a new edit after undo clears redo", function()
		local env = setup()
		env.place("cozy_plant_01", 0, 0)
		env.undo()
		env.place("cozy_plant_01", 5, 0)
		local before = state(env)
		local r = env.redo()
		T.eq(r.code, "NothingToRedo")
		T.eq(state(env), before)
	end)

	T.test("rejected edits are not recorded; undo skips to the last valid edit", function()
		local env = setup()
		env.place("cozy_plant_01", 0, 0)
		env.req({ op = "Move", id = "i1", transform = { x = 3, y = 0, z = 0, yaw = 0 } })
		local before = state(env)
		T.eq(env.req({ op = "Move", id = "i1", transform = { x = 99, y = 0, z = 0, yaw = 0 } }).code, "OutOfBounds")
		T.eq(env.req({ op = "Move", id = "i1", transform = { x = 0 / 0, y = 0, z = 0, yaw = 0 } }).code, "BadTransform")
		T.eq(env.req({ op = "Move", id = "i1", transform = { x = 3.001, y = 0, z = 0, yaw = 0 } }).ok, true, "no-op move")
		T.eq(state(env), before, "rejected and no-op edits changed nothing")
		env.undo()
		T.eq(env.core.model:get("i1").x, 0, "undo reverted the last committed move")
		env.undo()
		T.eq(#env.core:list(), 0)
		T.eq(env.undo().code, "NothingToUndo")
	end)

	T.test("nothing to undo/redo leaves state unchanged and never touches the world", function()
		local env = setup()
		local calls = #env.world.calls
		T.eq(env.undo().code, "NothingToUndo")
		T.eq(env.redo().code, "NothingToRedo")
		T.eq(#env.world.calls, calls)
		T.eq(env.core:getRevision(), 0)
	end)

	T.test("history conflict: re-creating a locked or uninstalled item is dropped, world untouched", function()
		local env = setup()
		env.place("cozy_plant_01", 0, 0)
		env.place("cozy_armchair_01", 6, 0)
		env.req({ op = "Delete", id = "i2" })
		env.locked.cozy_armchair_01 = true -- e.g. a future entitlement lapsed
		local before, calls = state(env), #env.world.calls
		local r = env.undo()
		T.eq(r.code, "HistoryConflict")
		T.eq(r.reason, "NotEntitled")
		T.eq(state(env), before, "state unchanged")
		T.eq(#env.world.calls, calls, "world untouched")
		T.eq(r.status.canUndo, true, "the conflicting step was dropped; older steps remain")
		-- Next step is "undo place i2", but i2 no longer exists: also a conflict, also dropped.
		local second = env.undo()
		T.eq(second.code, "HistoryConflict")
		T.eq(second.reason, "NotFound")
		T.eq(state(env), before)
		-- Then "undo place i1" applies normally.
		local third = env.undo()
		T.eq(third.ok, true)
		T.eq(third.id, "i1")
		T.eq(#env.core:list(), 0)
		consistent(env)
	end)

	T.test("history conflict: re-creating an item whose template was removed", function()
		local env = setup()
		env.place("cozy_plant_01", 0, 0)
		env.req({ op = "Delete", id = "i1" })
		env.installed.cozy_plant_01 = nil
		local before = state(env)
		local r = env.undo()
		T.eq(r.code, "HistoryConflict")
		T.eq(r.reason, "NotInstalled")
		T.eq(state(env), before)
	end)

	T.test("history conflict when the item changed underneath the entry", function()
		local env = setup()
		env.place("cozy_plant_01", 0, 0)
		env.req({ op = "Move", id = "i1", transform = { x = 5, y = 0, z = 0, yaw = 0 } })
		-- Simulate divergence the history did not record (e.g. a reconcile repaired the item).
		env.core.model:set("i1", { itemId = "cozy_plant_01", placedByUserId = HOST, x = 7, y = 0, z = 0, yaw = 0 })
		env.world.live.i1.x = 7
		local before = state(env)
		local r = env.undo()
		T.eq(r.code, "HistoryConflict")
		T.eq(state(env), before)
	end)

	T.test("host transfer invalidates history for both hosts", function()
		local env = setup()
		env.place("cozy_plant_01", 0, 0)
		env.place("cozy_plant_01", 5, 0)
		env.host = OTHER
		T.eq(env.undo(nil, HOST).code, "NotHost", "former host cannot undo")
		local before = state(env)
		local r = env.undo(nil, OTHER)
		T.eq(r.code, "NothingToUndo", "new host starts with empty history")
		T.eq(state(env), before)
		env.req({ op = "Delete", id = "i1" }, OTHER)
		T.eq(env.undo(nil, OTHER).id, "i1", "new host's own edits are undoable")
		env.host = HOST
		T.eq(env.undo().code, "NothingToUndo", "returning host's old history is gone")
	end)

	T.test("stale expectedRevision is refused without consuming history", function()
		local env = setup()
		env.place("cozy_plant_01", 0, 0)
		env.place("cozy_plant_01", 5, 0)
		local before = state(env)
		T.eq(env.undo({ expectedRevision = 1 }).code, "StaleRevision")
		T.eq(env.undo({ expectedRevision = "2" }).code, "BadRequest")
		T.eq(env.undo({ expectedRevision = -1 }).code, "BadRequest")
		T.eq(state(env), before)
		local r = env.undo({ expectedRevision = 2 })
		T.eq(r.ok, true)
		T.eq(r.id, "i2")
		T.eq(env.undo({ expectedRevision = 2 }).code, "StaleRevision", "a double-click cannot undo twice")
	end)

	T.test("undo uses the same host re-check and rollback: authority lost keeps the step", function()
		local env = setup()
		env.place("cozy_plant_01", 0, 0)
		local before = state(env)
		env.world.onApply = function(effect)
			if effect.kind == "remove" then
				env.host = OTHER
			end
		end
		local r = env.undo()
		T.eq(r.code, "AuthorityLost")
		T.eq(state(env), before)
		env.world.onApply = nil
		env.host = HOST
		T.eq(env.undo().ok, true, "the step was kept and applies once authority is back")
		T.eq(#env.core:list(), 0)
	end)

	T.test("undo world failure is transactional and keeps the step", function()
		local env = setup()
		env.place("cozy_plant_01", 0, 0)
		env.req({ op = "Delete", id = "i1" })
		env.world.failApply = "spawn"
		local before = state(env)
		T.eq(env.undo().code, "ApplyFailed")
		T.eq(state(env), before)
		env.world.failApply = nil
		T.eq(env.undo().id, "i1")
		consistent(env)
	end)

	T.test("undo rollback failure enters recovery and clears history", function()
		local env = setup()
		env.place("cozy_plant_01", 0, 0)
		env.world.failRollback = 1
		env.world.onApply = function()
			env.host = OTHER
		end
		local r = env.undo()
		T.eq(r.code, "AuthorityLost")
		T.eq(r.recoveryNeeded, true)
		T.eq(r.status.state, "recovery")
		env.world.onApply = nil
		env.host = HOST
		T.eq(env.core:recover(), true)
		T.eq(env.undo().code, "NothingToUndo", "history cleared by recovery")
		consistent(env)
	end)

	T.test("redo is serialized by the edit lock", function()
		local env = setup()
		env.place("cozy_plant_01", 0, 0)
		env.undo()
		env.world.yieldOn.spawn = true
		local response
		local co = coroutine.create(function()
			response = env.core:handle(HOST, { op = "Redo" })
		end)
		env.now = env.now + 1
		assert(coroutine.resume(co))
		T.eq(env.req({ op = "Place", itemId = "cozy_plant_01", transform = { x = 5, y = 0, z = 0, yaw = 0 } }).code, "Busy")
		T.eq(env.undo().code, "Busy")
		assert(coroutine.resume(co))
		T.eq(response.id, "i1")
		consistent(env)
	end)

	T.test("history depth is bounded", function()
		local env = setup({ historyLimit = 3 })
		for i = 1, 5 do
			env.place("cozy_plant_01", -12 + i * 4, 0)
		end
		for _ = 1, 3 do
			T.eq(env.undo().ok, true)
		end
		T.eq(env.undo().code, "NothingToUndo")
		T.eq(#env.core:list(), 2)
	end)

	T.test("Status is read-only, allowed for anyone, and every response carries status", function()
		local env = setup()
		env.place("cozy_plant_01", 0, 0)
		local before = state(env)
		local s = env.req({ op = "Status" }, OTHER)
		T.eq(s.ok, true)
		T.eq(s.status.canUndo, false, "status is per user")
		T.eq(s.status.state, "ready")
		local mine = env.req({ op = "Status" })
		T.eq(mine.status.canUndo, true)
		T.eq(mine.status.revision, 1)
		T.eq(env.req({ op = "Status", extra = 1 }).code, "BadRequest")
		T.eq(state(env), before)
		T.ok(env.req({ op = "Bogus" }).status ~= nil, "rejections carry status too")
	end)
end
