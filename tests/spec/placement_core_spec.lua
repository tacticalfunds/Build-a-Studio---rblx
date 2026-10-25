return function(T, H)
	local PlacementCore = H.load("src/server/Core/PlacementCore")
	local Catalog = H.load("src/shared/Catalog")
	local Config = H.load("src/shared/Config")
	local Entitlements = H.load("src/server/Adapters/Entitlements")

	-- Template bounds from docs/assets (boundsStuds of each source model).
	local SIZES = {
		cozy_armchair_01 = { 5.0, 4.73, 4.25 },
		cozy_coffee_table_01 = { 3.0, 1.75, 6.4 },
		cozy_bookshelf_01 = { 6.22, 12.14, 1.59 },
		cozy_plant_01 = { 2.93, 5.72, 2.93 },
		cozy_floor_lamp_01 = { 1.9, 6.32, 1.9 },
		retro_tv_cart_01 = { 3.29, 4.68, 3.97 },
		retro_cassette_01 = { 1.47, 0.25, 0.85 },
	}
	local HOST, GUEST = 1001, 2002

	-- Fake world mirroring PlacedItemsWorld's two-phase contract.
	local function fakeWorld()
		local w = { live = {}, calls = {}, revisions = {} }
		local function copy(r)
			return { itemId = r.itemId, placedByUserId = r.placedByUserId, x = r.x, y = r.y, z = r.z, yaw = r.yaw }
		end
		function w:apply(effect)
			self.calls[#self.calls + 1] = "apply:" .. effect.kind .. ":" .. effect.id
			if self.onApply then
				self.onApply(effect)
			end
			if self.failApply == effect.kind then
				error("world failure")
			end
			local previous = self.live[effect.id]
			if effect.kind == "spawn" then
				assert(previous == nil, "spawn over existing model")
				self.live[effect.id] = copy(effect.record)
			elseif effect.kind == "move" then
				self.live[effect.id] = copy(effect.to)
			elseif effect.kind == "remove" then
				self.live[effect.id] = nil
			end
			return { kind = effect.kind, id = effect.id, previous = previous }
		end
		function w:rollback(token)
			self.calls[#self.calls + 1] = "rollback:" .. token.kind .. ":" .. token.id
			self.live[token.id] = token.previous
		end
		function w:commit(token)
			self.calls[#self.calls + 1] = "commit:" .. token.kind .. ":" .. token.id
		end
		function w:publishRevision(n)
			self.revisions[#self.revisions + 1] = n
		end
		return w
	end

	local function setup(options)
		options = options or {}
		local env = { host = HOST, now = 0, installed = {} }
		for id in pairs(SIZES) do
			env.installed[id] = true
		end
		for _, id in ipairs(options.notInstalled or {}) do
			env.installed[id] = nil
		end
		local config = setmetatable({ MaxItems = options.maxItems or Config.MaxItems }, { __index = Config })
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
			entitlements = options.entitlements or Entitlements.new(),
			authority = { check = function(_, userId) return userId == env.host end },
			bounds = { halfX = 20, halfZ = 15, height = 16 },
			world = env.world,
			clock = function() return env.now end,
		})
		-- Each request advances the clock 1 s unless told otherwise, so rate limits stay out of the way.
		function env.req(payload, userId, noAdvance)
			if not noAdvance then
				env.now = env.now + 1
			end
			return env.core:handle(userId or HOST, payload)
		end
		function env.place(itemId, x, z, yaw)
			return env.req({ op = "Place", itemId = itemId, transform = { x = x or 0, y = 0, z = z or 0, yaw = yaw or 0 } })
		end
		return env
	end

	-- Snapshot of model + revision + world to prove rejected edits change nothing.
	local function snapshot(env)
		local parts = { "rev=" .. env.core:getRevision(), "worldRevs=" .. #env.world.revisions }
		for _, entry in ipairs(env.core:list()) do
			local r = entry.record
			parts[#parts + 1] = string.format("%s:%s:%d:%.3f,%.3f,%.3f,%g", entry.id, r.itemId, r.placedByUserId, r.x, r.y, r.z, r.yaw)
		end
		local live = {}
		for id, r in pairs(env.world.live) do
			live[#live + 1] = string.format("%s:%.3f,%.3f,%g", id, r.x, r.z, r.yaw)
		end
		table.sort(live)
		parts[#parts + 1] = "live=" .. table.concat(live, ";")
		return table.concat(parts, "|")
	end

	local function expectRejected(env, payload, code, userId, label)
		local before = snapshot(env)
		local callsBefore = #env.world.calls
		local r = env.req(payload, userId)
		T.eq(r.ok, false, label)
		T.eq(r.code, code, label)
		T.eq(snapshot(env), before, (label or code) .. ": state changed after rejection")
		T.eq(#env.world.calls, callsBefore, (label or code) .. ": world touched after rejection")
	end

	-- Model and world agree after every request.
	local function consistent(env)
		local seen = 0
		for _, entry in ipairs(env.core:list()) do
			local live = env.world.live[entry.id]
			T.ok(live ~= nil, entry.id .. " missing from world")
			T.eq(live.x, entry.record.x)
			T.eq(live.yaw, entry.record.yaw)
			seen = seen + 1
		end
		local liveCount = 0
		for _ in pairs(env.world.live) do
			liveCount = liveCount + 1
		end
		T.eq(liveCount, seen, "world has models the core doesn't")
	end

	T.test("host places a curated item; BuildRevision advances", function()
		local env = setup()
		local r = env.place("cozy_armchair_01", 2, -3, 90)
		T.eq(r.ok, true)
		T.eq(r.id, "i1")
		T.eq(r.buildRevision, 1)
		T.eq(env.world.revisions[1], 1)
		local item = env.core:list()[1]
		T.eq(item.record.placedByUserId, HOST)
		T.eq(item.record.yaw, 90)
		T.eq(table.concat(env.world.calls, ","), "apply:spawn:i1,commit:spawn:i1")
		consistent(env)
	end)

	T.test("non-hosts are rejected for every op, before any lookup", function()
		local env = setup()
		env.place("cozy_plant_01")
		for _, payload in ipairs({
			{ op = "Place", itemId = "cozy_plant_01", transform = { x = 0, y = 0, z = 0, yaw = 0 } },
			{ op = "Move", id = "i1", transform = { x = 1, y = 0, z = 0, yaw = 0 } },
			{ op = "Rotate", id = "i1" },
			{ op = "Duplicate", id = "i1" },
			{ op = "Delete", id = "i1" },
		}) do
			expectRejected(env, payload, "NotHost", GUEST, payload.op)
		end
	end)

	T.test("host change during the world apply rolls back and changes nothing", function()
		for _, case in ipairs({ { "spawn" }, { "move" }, { "remove" } }) do
			local env = setup()
			env.place("cozy_plant_01", 0, 0)
			local before = snapshot(env)
			env.world.onApply = function(effect)
				if effect.kind == case[1] then
					env.host = GUEST -- host transfers while the edit is mid-flight
				end
			end
			local payload
			if case[1] == "spawn" then
				payload = { op = "Place", itemId = "cozy_plant_01", transform = { x = 5, y = 0, z = 0, yaw = 0 } }
			elseif case[1] == "move" then
				payload = { op = "Move", id = "i1", transform = { x = 5, y = 0, z = 0, yaw = 0 } }
			else
				payload = { op = "Delete", id = "i1" }
			end
			local r = env.req(payload)
			T.eq(r.ok, false, case[1])
			T.eq(r.code, "AuthorityLost", case[1])
			T.eq(snapshot(env), before, case[1] .. ": state changed after lost authority")
			T.eq(env.world.calls[#env.world.calls]:match("^rollback"), "rollback", case[1] .. ": world rolled back")
			consistent(env)
		end
	end)

	T.test("world apply failures are transactional", function()
		for _, kind in ipairs({ "spawn", "move", "remove" }) do
			local env = setup()
			env.place("cozy_plant_01", 0, 0)
			env.world.failApply = kind
			local payload = ({
				spawn = { op = "Place", itemId = "cozy_plant_01", transform = { x = 5, y = 0, z = 0, yaw = 0 } },
				move = { op = "Move", id = "i1", transform = { x = 5, y = 0, z = 0, yaw = 0 } },
				remove = { op = "Delete", id = "i1" },
			})[kind]
			local before = snapshot(env)
			local r = env.req(payload)
			T.eq(r.code, "ApplyFailed", kind)
			T.eq(snapshot(env), before, kind)
			env.world.failApply = nil
			if kind == "spawn" then
				T.eq(env.place("cozy_plant_01", 5, 0).id, "i2", "failed spawn did not consume an ID")
			end
		end
	end)

	T.test("malformed payloads are rejected with state unchanged", function()
		local env = setup()
		env.place("cozy_plant_01")
		local okTransform = { x = 1, y = 0, z = 0, yaw = 0 }
		local cases = {
			{ nil, "BadRequest" }, { "Place", "BadRequest" }, { 42, "BadRequest" }, { io.stdout, "BadRequest" },
			{ {}, "BadRequest" }, { { op = 5 }, "BadRequest" }, { { op = "Teleport" }, "UnknownOp" },
			{ { op = "__index" }, "UnknownOp" }, { { op = string.rep("P", 100) }, "BadRequest" },
			{ { op = "Place", itemId = "cozy_plant_01" }, "BadRequest" },
			{ { op = "Place", itemId = "cozy_plant_01", transform = okTransform, scale = 3 }, "BadRequest" },
			{ { op = "Place", itemId = "cozy_plant_01", transform = okTransform, color = "red" }, "BadRequest" },
			{ { op = "Place", itemId = "cozy_plant_01", transform = okTransform, [1] = true }, "BadRequest" },
			{ { op = "Place", itemId = io.stdout, transform = okTransform }, "BadRequest" },
			{ { op = "Place", itemId = "ServerStorage.StudioBuilderTemplates.cozy_plant_01", transform = okTransform }, "BadRequest" },
			{ { op = "Place", itemId = "rbxassetid://964030990", transform = okTransform }, "BadRequest" },
			{ { op = "Place", itemId = string.rep("a", 5000), transform = okTransform }, "BadRequest" },
			{ { op = "Place", itemId = "cozy_plant_01", transform = io.stdout }, "BadTransform" },
			{ { op = "Place", itemId = "cozy_plant_01", transform = { x = 1, y = 0, z = 0 } }, "BadTransform" },
			{ { op = "Place", itemId = "cozy_plant_01", transform = { x = 1, y = 0, z = 0, yaw = 0, scale = 2 } }, "BadTransform" },
			{ { op = "Place", itemId = "cozy_plant_01", transform = { x = 0 / 0, y = 0, z = 0, yaw = 0 } }, "BadTransform" },
			{ { op = "Place", itemId = "cozy_plant_01", transform = { x = math.huge, y = 0, z = 0, yaw = 0 } }, "BadTransform" },
			{ { op = "Place", itemId = "cozy_plant_01", transform = { x = 1, y = 0, z = 0, yaw = 7 } }, "BadTransform" },
			{ { op = "Place", itemId = "cozy_plant_01", transform = { x = "1", y = 0, z = 0, yaw = 0 } }, "BadTransform" },
			{ { op = "Move", id = "i0", transform = okTransform }, "BadRequest" },
			{ { op = "Move", id = "../i1", transform = okTransform }, "BadRequest" },
			{ { op = "Move", id = io.stdout, transform = okTransform }, "BadRequest" },
			{ { op = "Move", id = "i1", transform = { x = 1, y = 0, z = 0, yaw = 0, cframe = {} } }, "BadTransform" },
			{ { op = "Rotate", id = "i1", direction = 2 }, "BadRequest" },
			{ { op = "Rotate", id = "i1", direction = "1" }, "BadRequest" },
			{ { op = "Delete", id = "i1", path = "Workspace" }, "BadRequest" },
			{ { op = "Delete" }, "BadRequest" },
		}
		for i, case in ipairs(cases) do
			expectRejected(env, case[1], case[2], HOST, "case " .. i)
		end
	end)

	T.test("catalog allowlist, installed templates and entitlements are enforced", function()
		local env = setup({ notInstalled = { "retro_tv_cart_01" } })
		local t = { x = 0, y = 0, z = 0, yaw = 0 }
		expectRejected(env, { op = "Place", itemId = "cozy_sofa_99", transform = t }, "UnknownItem")
		expectRejected(env, { op = "Place", itemId = "retro_tv_cart_01", transform = t }, "NotInstalled")
		local locked = setup({ entitlements = { isItemUnlocked = function() return false end } })
		expectRejected(locked, { op = "Place", itemId = "cozy_plant_01", transform = t }, "NotEntitled")
	end)

	T.test("room bounds use the full yawed footprint", function()
		local env = setup()
		expectRejected(env, { op = "Place", itemId = "cozy_bookshelf_01", transform = { x = 17, y = 0, z = 0, yaw = 0 } }, "OutOfBounds")
		T.eq(env.place("cozy_bookshelf_01", 19, 0, 90).ok, true, "fits after turning 90 degrees")
		expectRejected(env, { op = "Place", itemId = "cozy_bookshelf_01", transform = { x = 0, y = 4, z = 0, yaw = 0 } }, "OutOfBounds", HOST, "too tall at y=4")
		expectRejected(env, { op = "Place", itemId = "cozy_plant_01", transform = { x = 0, y = -1, z = 0, yaw = 0 } }, "OutOfBounds", HOST, "below floor")
	end)

	T.test("item cap applies to Place and Duplicate", function()
		local env = setup({ maxItems = 3 })
		for i = 1, 3 do
			T.eq(env.place("cozy_plant_01", -10 + i * 4, 0).ok, true)
		end
		expectRejected(env, { op = "Place", itemId = "cozy_plant_01", transform = { x = 0, y = 0, z = 5, yaw = 0 } }, "ItemCap")
		expectRejected(env, { op = "Duplicate", id = "i1" }, "ItemCap")
	end)

	T.test("shared studio: after a transfer the current host edits every item; the former host cannot", function()
		local env = setup()
		env.place("cozy_plant_01")
		env.host = GUEST
		expectRejected(env, { op = "Delete", id = "i1" }, "NotHost", HOST, "former host")
		T.eq(env.req({ op = "Move", id = "i1", transform = { x = 3, y = 0, z = 0, yaw = 0 } }, GUEST).ok, true)
		T.eq(env.req({ op = "Rotate", id = "i1" }, GUEST).ok, true)
		local dup = env.req({ op = "Duplicate", id = "i1" }, GUEST)
		T.eq(dup.ok, true)
		local list = env.core:list()
		T.eq(list[1].record.placedByUserId, HOST, "placedBy metadata is preserved on edit")
		T.eq(list[2].record.placedByUserId, GUEST, "the duplicate records who placed it")
		T.eq(env.req({ op = "Delete", id = "i1" }, GUEST).ok, true)
		expectRejected(env, { op = "Delete", id = "i42" }, "NotFound", GUEST)
	end)

	T.test("move and rotate validate bounds; rejected moves keep the old transform", function()
		local env = setup()
		env.place("cozy_bookshelf_01", 19, 0, 90)
		expectRejected(env, { op = "Rotate", id = "i1" }, "OutOfBounds", HOST, "turning against the wall")
		expectRejected(env, { op = "Move", id = "i1", transform = { x = 25, y = 0, z = 0, yaw = 90 } }, "OutOfBounds")
		local r = env.req({ op = "Move", id = "i1", transform = { x = 0, y = 0, z = 0, yaw = 90 } })
		T.eq(r.ok, true)
		T.eq(env.req({ op = "Rotate", id = "i1" }).ok, true)
		T.eq(env.core:list()[1].record.yaw, 105)
		T.eq(env.req({ op = "Rotate", id = "i1", direction = -1 }).ok, true)
		T.eq(env.req({ op = "Rotate", id = "i1", direction = -1 }).ok, true)
		T.eq(env.core:list()[1].record.yaw, 75)
		consistent(env)
	end)

	T.test("a no-op move succeeds without touching the world or revision", function()
		local env = setup()
		env.place("cozy_plant_01", 1, 1)
		local before = snapshot(env)
		local calls = #env.world.calls
		local r = env.req({ op = "Move", id = "i1", transform = { x = 1.001, y = 0, z = 1, yaw = 360 } })
		T.eq(r.ok, true)
		T.eq(snapshot(env), before)
		T.eq(#env.world.calls, calls)
	end)

	T.test("duplicate picks a free in-bounds side and keeps yaw", function()
		local env = setup()
		env.place("cozy_armchair_01", 17, 0, 0) -- right side is out of bounds
		local r = env.req({ op = "Duplicate", id = "i1" })
		T.eq(r.ok, true)
		T.eq(r.id, "i2")
		local copy = env.core:list()[2].record
		T.eq(copy.x, 12, "placed on the left (17 - 5)")
		T.eq(copy.yaw, 0)
		T.eq(copy.placedByUserId, HOST)
		consistent(env)
	end)

	T.test("delete removes the item; IDs are never reused", function()
		local env = setup()
		env.place("cozy_plant_01", 0, 0)
		env.place("cozy_plant_01", 5, 0)
		T.eq(env.req({ op = "Delete", id = "i2" }).ok, true)
		T.eq(env.world.calls[#env.world.calls], "commit:remove:i2")
		expectRejected(env, { op = "Delete", id = "i2" }, "NotFound")
		T.eq(env.place("cozy_plant_01", 5, 0).id, "i3")
		consistent(env)
	end)

	T.test("rate limit: burst then refill, per player, malformed spam included", function()
		local env = setup()
		local accepted = 0
		for _ = 1, 20 do
			local r = env.req({ op = "Place", itemId = "cozy_cassette_x" }, HOST, true)
			if r.code ~= "RateLimited" then
				accepted = accepted + 1
			end
		end
		T.eq(accepted, Config.RateLimits.edit.capacity, "burst capacity")
		T.eq(env.req({ op = "Delete", id = "i1" }, GUEST, true).code, "NotHost", "other players have their own bucket")
		env.now = env.now + 1
		T.eq(env.req({ op = "Delete", id = "i9" }, HOST, true).code, "NotFound", "refilled after a second")
	end)

	T.test("one edit at a time: a request during a yielding apply gets Busy", function()
		local env = setup()
		local inner
		env.world.onApply = function()
			inner = env.core:handle(HOST, { op = "Place", itemId = "cozy_plant_01", transform = { x = 5, y = 0, z = 0, yaw = 0 } })
		end
		T.eq(env.place("cozy_plant_01", 0, 0).ok, true)
		T.eq(inner.code, "Busy")
		T.eq(#env.core:list(), 1)
	end)

	T.test("random payloads never throw and invariants hold", function()
		local env = setup({ maxItems = 40 })
		local seed = 4242
		local function rand(n)
			seed = (seed * 1103515245 + 12345) % 2147483648
			return math.floor(seed / 65536) % n -- high bits; low LCG bits alternate
		end
		local ids = {}
		for _, item in ipairs(Catalog.Items) do
			ids[#ids + 1] = item.id
		end
		-- Mostly in-range numbers, with NaN/inf/out-of-room values mixed in.
		local function num()
			local pick = rand(20)
			if pick == 0 then return 0 / 0 elseif pick == 1 then return math.huge elseif pick == 2 then return (rand(4400) - 2200) / 100 end
			return (rand(3000) - 1500) / 100
		end
		local function maybe(percent)
			return rand(100) < percent
		end
		local FIELDS = { Place = { "itemId", "transform" }, Move = { "id", "transform" }, Rotate = { "id" }, Duplicate = { "id" }, Delete = { "id" } }
		local successes = 0
		local codes = {}
		for i = 1, 3000 do
			local ops = { "Place", "Place", "Move", "Move", "Rotate", "Duplicate", "Delete", "Delete", "Bogus" }
			local op = ops[rand(#ops) + 1]
			local payload = { op = op }
			-- ~90% of requests carry exactly the fields their op needs; the rest are malformed.
			local wanted = {}
			for _, field in ipairs(FIELDS[op] or {}) do
				wanted[field] = maybe(95)
			end
			if wanted.itemId or maybe(5) then payload.itemId = ids[rand(#ids) + 1] end
			if wanted.id or maybe(5) then
				local existing = env.core:list()
				if #existing > 0 and maybe(80) then
					payload.id = existing[rand(#existing) + 1].id
				else
					payload.id = "i" .. rand(200) -- usually stale or never allocated
				end
			end
			if wanted.transform or maybe(5) then
				payload.transform = { x = num(), y = maybe(80) and 0 or num(), z = num(), yaw = maybe(5) and 7 or rand(48) * 15 - 360 }
			end
			if op == "Rotate" and maybe(30) then payload.direction = rand(3) - 1 end
			if maybe(3) then payload.extra = true end
			local user = rand(10) == 0 and GUEST or HOST
			local ok, r = pcall(env.core.handle, env.core, user, payload)
			T.ok(ok, "handle threw on case " .. i .. ": " .. tostring(r))
			codes[tostring(r.code)] = (codes[tostring(r.code)] or 0) + 1
			if r.ok and r.buildRevision > successes then
				successes = r.buildRevision
			end
			env.now = env.now + 0.2
		end
		T.eq(env.core:getRevision(), successes)
		T.ok(successes >= 300, "fuzz committed too few edits to be meaningful: " .. successes)
		local summary = {}
		for code, n in pairs(codes) do
			summary[#summary + 1] = code .. "=" .. n
		end
		table.sort(summary)
		H.note("placement fuzz: 3000 requests, " .. successes .. " committed, " .. env.core.model.count .. " items at end; " .. table.concat(summary, " "))
		T.ok(env.core.model.count <= 40, "cap held")
		for _, entry in ipairs(env.core:list()) do
			local r = entry.record
			local size = SIZES[r.itemId]
			local Transform = H.load("src/shared/Transform")
			T.ok(Transform.fits(r, size, { halfX = 20, halfZ = 15, height = 16 }, Config.BoundsEpsilon), entry.id .. " out of bounds")
			T.eq(r.placedByUserId, HOST)
		end
		consistent(env)
	end)
end
