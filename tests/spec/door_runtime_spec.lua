-- Door runtime wiring (DoorRuntime + BuilderService), disabled by default.
-- Everything Roblox-facing is a fake: string CFrames, a fake Heartbeat,
-- fake Players / workspace / models. This checks the wiring, the default-off
-- gate, capacity and lifecycle only. Real CFrame maths, overlap queries,
-- physics, hinge/frame contact, players and replication are NOT exercised.
return function(T, H)
	local DoorRuntime = H.load("src/server/Runtime/DoorRuntime")
	local DoorAutoOpen = H.load("src/server/Core/DoorAutoOpen")
	local DoorSensing = H.load("src/server/Runtime/DoorSensing")
	local PlacedItemsWorld = H.load("src/server/Runtime/PlacedItemsWorld")
	local Catalog = H.load("src/shared/Catalog")
	local Config = H.load("src/shared/Config")

	local DOOR = "structure_doorway_panel_01"
	local BOUNDS = { halfX = 24, halfZ = 24, height = 24 }
	local ON = { MaxItems = Config.MaxItems, Doors = { Enabled = true, ScanInterval = 0.25 } }

	-- Fake CFrame: descriptive strings composed in order.
	local function cf(desc)
		local c = { desc = desc }
		function c:Inverse() return cf("inv(" .. desc .. ")") end
		function c:ToObjectSpace(other) return cf("inv(" .. desc .. ")*" .. other.desc) end
		-- The sandbox origin sits at world y = 1: room = world - (0, 1, 0).
		function c:PointToObjectSpace(v) return { X = v.X, Y = v.Y - 1, Z = v.Z } end
		return setmetatable(c, { __mul = function(a, b) return cf(a.desc .. "*" .. b.desc) end })
	end
	local CF = {
		new = function(x, y, z) return cf(string.format("T(%g,%g,%g)", x, y, z)) end,
		Angles = function(_, y) return cf(string.format("R(%.4f)", y)) end,
	}

	-- A fake Heartbeat that counts live connections.
	local function signal()
		local s = { handlers = {}, connects = 0 }
		function s:Connect(fn)
			self.connects = self.connects + 1
			local conn = { live = true }
			function conn.Disconnect() conn.live = false end
			self.handlers[#self.handlers + 1] = { fn = fn, conn = conn }
			return conn
		end
		function s:live()
			local n = 0
			for _, h in ipairs(self.handlers) do if h.conn.live then n = n + 1 end end
			return n
		end
		function s:fire()
			for _, h in ipairs(self.handlers) do if h.conn.live then h.fn() end end
		end
		return s
	end

	local function env(config, opts)
		opts = opts or {}
		local e = { now = 0, players = {}, parts = {}, queries = {} }
		e.heartbeat = signal()
		e.folder = { Name = "StudioBuilderPlacedItems" }
		e.marker = { Name = "StudioBuilderSandbox" }
		e.roblox = {
			CFrame = CF,
			Vector3 = { new = function(x, y, z) return { X = x, Y = y, Z = z } end },
			OverlapParams = { new = function() return {} end },
			Enum = { RaycastFilterType = { Exclude = "Exclude" } },
			Players = { GetPlayers = function() return e.players end },
			workspace = { GetPartBoundsInBox = function(_, c, size, params)
				e.queries[#e.queries + 1] = { c = c, size = size, params = params }
				return e.parts
			end },
		}
		e.deps = {
			config = config, catalog = Catalog, origin = cf("O"), folder = e.folder, bounds = BOUNDS,
			heartbeat = e.heartbeat, clock = function() return e.now end,
			log = function() end, exclude = { e.marker }, roblox = e.roblox,
		}
		if opts.noHeartbeat then e.deps.heartbeat = nil end
		return e
	end

	local function teardown()
		DoorRuntime.stop()
		H.setGlobal("CFrame", nil)
		H.setGlobal("Enum", nil)
	end
	local function run(fn)
		local ok, err = pcall(fn)
		teardown()
		assert(ok, err)
	end

	-- Default off ---------------------------------------------------------------------------------

	T.test("default off: Config.Doors.Enabled is false; start builds nothing, connects nothing and leaves no runtime", function()
		run(function()
			T.eq(Config.Doors.Enabled, false, "shipped disabled")
			T.eq(Config.Doors.ScanInterval, 0.25)
			T.eq(DoorRuntime.isEnabled(Config), false)
			T.eq(DoorRuntime.isEnabled(nil), false, "nil means the shared Config")
			for _, flag in ipairs({ "true", 1, {}, false }) do
				T.eq(DoorRuntime.isEnabled({ Doors = { Enabled = flag } }), false, "only the boolean true enables: " .. tostring(flag))
			end
			T.eq(DoorRuntime.isEnabled({}), false, "no Doors table")
			local e = env(Config)
			T.eq(DoorRuntime.start(e.deps), nil)
			T.eq(e.heartbeat.connects, 0, "no Heartbeat connection")
			T.eq(DoorRuntime.active(), nil)
			T.eq(#e.queries, 0)
			-- Turning the flag off on a rebind stops a runtime started earlier.
			local onEnv = env(ON)
			T.ok(DoorRuntime.start(onEnv.deps) ~= nil)
			T.eq(onEnv.heartbeat:live(), 1)
			T.eq(DoorRuntime.start(env(Config).deps), nil)
			T.eq(onEnv.heartbeat:live(), 0, "the earlier runtime was stopped")
			T.eq(DoorRuntime.active(), nil)
		end)
	end)

	T.test("BuilderService: doors start only behind the flag, and the world's fourth argument is that runtime or nil", function()
		-- Line endings normalized so a CRLF checkout (Windows archive) matches too.
		local src = H.readFile(H.ROOT .. "/src/server/Runtime/BuilderService.luau"):gsub("\r\n", "\n")
		local args = src:match("PlacedItemsWorld%.new(%b())")
		T.eq(args, "(placedFolder, sandbox.origin, curatedTemplate, doors)")
		-- `doors` starts nil and is only set from DoorRuntime.start inside the flag check.
		T.ok(src:find("local doors = nil\n\tif DoorRuntime.isEnabled(Config) then", 1, true), "gated on the flag")
		local assigned = 0
		for _ in src:gmatch("doors = ") do assigned = assigned + 1 end
		T.eq(assigned, 2, "declared nil, then set once from the started runtime")
		T.ok(src:find("pcall(DoorRuntime.start, {", 1, true), "a failed start can't take the builder down")
		T.ok(src:find("heartbeat = RunService.Heartbeat", 1, true))
		T.ok(src:find("folder = placedFolder", 1, true) and src:find("origin = sandbox.origin", 1, true) and src:find("bounds = sandbox.bounds", 1, true))
		T.ok(src:find("catalog = Catalog", 1, true), "door metadata from the server's catalog")
		T.ok(src:find("exclude = { Workspace:FindFirstChild(Config.SandboxMarkerName) }", 1, true), "the sandbox marker never blocks a door")
		-- BuilderService names only DoorRuntime, never the parts it builds.
		for _, name in ipairs({ "DoorAutoOpen", "DoorController", "DoorSensing", "DoorRuntimeAdapters" }) do
			T.eq(src:find(name, 1, true), nil, name)
		end
		-- No client code reads the flag or the door runtime.
		for _, rel in ipairs(H.sourceList) do
			if rel:find("^src/client/") then
				local client = H.readFile(H.ROOT .. "/" .. rel)
				T.eq(client:find("Config.Doors", 1, true), nil, rel)
				T.eq(client:find("DoorRuntime", 1, true), nil, rel)
			end
		end
	end)

	-- Enabled wiring ------------------------------------------------------------------------------

	T.test("enabled: real DoorAutoOpen, DoorSensing and adapters; one Heartbeat connection; staging capacity 2 x 150", function()
		run(function()
			local e = env(ON)
			local controller = DoorRuntime.start(e.deps)
			T.ok(controller ~= nil)
			T.eq(DoorRuntime.active(), controller)
			T.eq(e.heartbeat.connects, 1)
			T.eq(e.heartbeat:live(), 1)
			T.eq(Config.MaxItems, 150)
			T.eq(controller.activeCap, 150, "committed doors capped at the 150-item limit")
			T.eq(getmetatable(controller.core), DoorAutoOpen)
			T.eq(controller.core.maxDoors, 300, "room to stage a full replacement set")
			T.eq(getmetatable(controller.sensing), DoorSensing)
			T.eq(controller.sensing.bounds, BOUNDS, "sensing uses the sandbox bounds")
			T.eq(controller.scanInterval, 0.25, "scan interval from Config.Doors")
			T.eq(controller.heartbeat, e.heartbeat)
			-- A second start on the same controller can't add a tick.
			T.eq(controller:start(), false)
			T.eq(e.heartbeat:live(), 1)
		end)
	end)

	T.test("enabled: door metadata comes only from the server catalog by id; a record can't smuggle its own", function()
		run(function()
			local e = env(ON)
			local controller = DoorRuntime.start(e.deps)
			T.deepEq(controller.specFor(DOOR), Catalog.getItem(DOOR).door)
			for _, id in ipairs({ "structure_doorway_01", "cozy_plant_01", "nope", "rbxassetid://123", 42, false }) do
				T.eq(controller.specFor(id), nil, tostring(id))
			end
			T.eq(controller.specFor(nil), nil)
			local meta = { hinge = { x = 2.5, z = 0 }, leaf = { center = { 0.1, 4.3, 0 }, size = { 5.2, 8.2, 0.9 } }, swing = "-z", openDegrees = 90 }
			local model = { FindFirstChild = function() error("a non-door is never touched") end }
			T.eq(controller:attach(model, "i1", { itemId = "structure_doorway_01", x = 0, y = 0, z = 8, yaw = 0, door = meta }, true), nil,
				"door fields on a record are ignored; only the catalog decides")
			T.eq(controller:count(), 0)
		end)
	end)

	T.test("enabled: overlap queries run in the sandbox frame, exclude the marker, and only placed floor pieces count as supporting floor", function()
		run(function()
			local e = env(ON)
			local controller = DoorRuntime.start(e.deps)
			local function placed(catalogId, parent)
				return { Parent = parent, IsA = function(_, c) return c == "Model" end, GetAttribute = function(_, k) if k == "BuildCatalogId" then return catalogId end end }
			end
			local floor = placed("structure_floor_oak_01", e.folder)
			local wall = placed("structure_wall_01", e.folder)
			local outside = placed("structure_floor_01", { Parent = nil, IsA = function() return false end })
			local function partOf(model)
				return { Parent = model, CanCollide = true, Size = { X = 16, Y = 1, Z = 16 }, CFrame = { rel = { 0, 0.5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } } }
			end
			e.parts = { partOf(floor), partOf(wall), partOf(outside) }
			function e.deps.origin:ToObjectSpace(c) return { GetComponents = function() return table.unpack(c.rel) end } end
			local hits, truncated = controller.sensing.queryBox({ minX = -2, maxX = 3, minY = 1, maxY = 9, minZ = 3, maxZ = 9 })
			T.eq(truncated, false)
			T.eq(hits[1].supportingFloor, true, "a placed floor piece")
			T.eq(hits[2].supportingFloor, false, "a placed wall")
			T.eq(hits[3].supportingFloor, false, "a floor-tagged model outside the placed-items folder")
			local q = e.queries[1]
			T.eq(q.c.desc, "O*T(0.5,5,6)", "the box is placed relative to the sandbox origin")
			T.eq(q.params.MaxParts, DoorSensing.Defaults.maxHits)
			T.eq(q.params.FilterType, "Exclude")
			T.deepEq(q.params.FilterDescendantsInstances, { e.marker })
		end)
	end)

	-- Lifecycle -----------------------------------------------------------------------------------

	T.test("lifecycle: a rebind destroys the old controller first; stop is idempotent; nothing keeps ticking", function()
		run(function()
			local first, second = env(ON), env(ON)
			local ticks = { first = 0, second = 0 }
			first.deps.clock = function() ticks.first = ticks.first + 1 return 0 end
			second.deps.clock = function() ticks.second = ticks.second + 1 return 0 end
			local a = DoorRuntime.start(first.deps)
			local b = DoorRuntime.start(second.deps)
			T.ok(a ~= b)
			T.eq(a.destroyed, true, "the old controller is destroyed")
			T.eq(first.heartbeat:live(), 0, "its connection is gone")
			T.eq(second.heartbeat:live(), 1)
			T.eq(DoorRuntime.active(), b)
			first.heartbeat:fire()
			second.heartbeat:fire()
			T.eq(ticks.first, 0, "the old controller never ticks again")
			T.ok(ticks.second > 0)
			-- Two starts on the same Heartbeat still leave exactly one live tick.
			local shared = env(ON)
			DoorRuntime.start(shared.deps)
			DoorRuntime.start(shared.deps)
			T.eq(shared.heartbeat.connects, 2)
			T.eq(shared.heartbeat:live(), 1)
			DoorRuntime.stop()
			T.eq(shared.heartbeat:live(), 0)
			T.eq(DoorRuntime.active(), nil)
			DoorRuntime.stop()
			T.eq(DoorRuntime.active(), nil, "stop twice is a no-op")
			-- A start that can't connect raises and leaves nothing behind.
			local broken = env(ON, { noHeartbeat = true })
			T.eq(pcall(DoorRuntime.start, broken.deps), false)
			T.eq(DoorRuntime.active(), nil)
		end)
	end)

	-- A started runtime, a world with its door hook, one placed panel door
	-- (and one plain doorway), and a fake player that can stand near it.
	local function rig()
		H.setGlobal("CFrame", CF)
		H.setGlobal("Enum", { ModelStreamingMode = { Persistent = "Persistent" } })
		local e = env(ON)
		e.logs = {}
		e.deps.log = function(message) e.logs[#e.logs + 1] = message end
		e.controller = DoorRuntime.start(e.deps)
		function e.folder:GetChildren() return {} end
		function e.folder:SetAttribute() end
		e.leaves = {}
		local function part(canCollide)
			local state = { CanCollide = canCollide, IsA = function(_, c) return c == "BasePart" end }
			return setmetatable({}, {
				__index = state,
				__newindex = function(_, k, v)
					if e.failCollision and e.failCollision(state, v) then error("collision write failed") end
					state[k] = v
				end,
			})
		end
		local function fakeModel()
			local props, attrs = {}, {}
			local parts = { part(true), part(false) }
			local leaf = { pivots = {}, parts = parts, GetPivot = function() return cf("LEAF") end, GetDescendants = function() return parts end }
			function leaf.PivotTo(_, c)
				if e.failPivot then error("pivot failed") end
				leaf.pivots[#leaf.pivots + 1] = c.desc
			end
			local methods = {
				GetDescendants = function() return {} end,
				SetAttribute = function(_, k, v) attrs[k] = v end,
				GetAttribute = function(_, k) return attrs[k] end,
				PivotTo = function(_, c) props.pivot = c.desc end,
				Destroy = function() props.Parent = nil end,
				FindFirstChild = function(_, n) if n == "Leaf" then return leaf end end,
			}
			local model = setmetatable({}, { __index = function(_, k) return methods[k] or props[k] end, __newindex = function(_, k, v) props[k] = v end })
			e.leaves[model] = leaf
			return model
		end
		local template = { Clone = function() return fakeModel() end }
		e.world = PlacedItemsWorld.new(e.folder, cf("O"), function() return template end, e.controller)
		e.door = e.world:apply({ kind = "spawn", id = "i1", record = { itemId = DOOR, placedByUserId = 1, x = 0, y = 0, z = 8, yaw = 0 } })
		e.world:commit(e.door)
		e.plain = e.world:apply({ kind = "spawn", id = "i2", record = { itemId = "structure_doorway_01", placedByUserId = 1, x = 16, y = 0, z = 8, yaw = 0 } })
		e.world:commit(e.plain)
		e.reg = e.controller:registration(e.door.model)
		e.leaf = e.leaves[e.door.model]
		e.leafParts = e.leaf.parts
		-- A living player one stud in front of the doorway (world y 5 = room y 4).
		local humanoid, root = { Health = 100 }, { Position = { X = 1, Y = 5, Z = 6 } }
		local character = {
			FindFirstChildOfClass = function(_, c) if c == "Humanoid" then return humanoid end end,
			FindFirstChild = function(_, n) if n == "HumanoidRootPart" then return root end end,
		}
		function e.approach() e.players = { { Character = character } } end
		function e.leave() e.players = {} end
		function e.run(from, to) for t = from, to, 0.25 do e.now = t; e.heartbeat:fire() end end
		function e.logged(text)
			for _, line in ipairs(e.logs) do if line:find(text, 1, true) then return true end end
			return false
		end
		return e
	end
	local function closedPose(desc) return desc:find("R(-0.0000)", 1, true) or desc:find("R(0.0000)", 1, true) end

	T.test("end to end with the world hook: a placed panel door opens for a nearby player, closes after they leave, and stop() restores it", function()
		run(function()
			local e = rig()
			T.eq(e.controller:count(), 1, "only the door is registered")
			T.eq(e.controller:committedCount(), 1)
			T.ok(e.reg ~= nil and e.controller:registration(e.plain.model) == nil)
			e.approach()
			e.run(0, 1)
			T.eq(e.reg.angle, 90, "fully open after the 0.6 s travel")
			T.ok(e.leaf.pivots[#e.leaf.pivots]:find("R(-1.5708)", 1, true), "posed through the hinge from the stored record: " .. e.leaf.pivots[#e.leaf.pivots])
			T.ok(not e.leafParts[1].CanCollide and not e.leafParts[2].CanCollide, "leaf collision off while open")
			T.ok(#e.queries > 0, "the sweep was scanned")
			-- The player leaves the sandbox: closes after the exit delay, collision back to its originals.
			e.leave()
			e.run(1.25, 5)
			T.eq(e.reg.angle, 0)
			T.eq(e.leafParts[1].CanCollide, true, "original collision restored")
			T.eq(e.leafParts[2].CanCollide, false, "a non-colliding part stays non-colliding")
			-- Open it again, then stop: the door is returned closed and released.
			e.approach()
			e.run(5.25, 6.5)
			T.eq(e.reg.angle, 90)
			DoorRuntime.stop()
			T.ok(closedPose(e.leaf.pivots[#e.leaf.pivots]), "closed on stop")
			T.eq(e.leafParts[1].CanCollide, true)
			T.eq(e.controller:count(), 0, "registrations released")
			T.eq(e.heartbeat:live(), 0)
			T.eq(#e.logs, 0, "a clean stop logs nothing")
		end)
	end)

	T.test("stop and rebind with a closed door: no pose is needed, original collision comes back", function()
		run(function()
			local e = rig()
			e.leave()
			e.run(0, 1)
			T.eq(e.reg.angle, 0)
			e.failPivot = true -- a closed leaf must not need a pose to be released
			local before = #e.leaf.pivots
			DoorRuntime.start(env(ON).deps) -- rebind
			T.eq(#e.leaf.pivots, before)
			T.eq(e.leafParts[1].CanCollide, true)
			T.eq(e.controller:count(), 0)
			T.eq(e.heartbeat:live(), 0)
		end)
	end)

	T.test("stop fault: the closing pose fails, so the open leaf stays non-colliding, is logged, released and never ticks again", function()
		run(function()
			local e = rig()
			e.approach()
			e.run(0, 1)
			T.eq(e.reg.angle, 90)
			local openPose = e.leaf.pivots[#e.leaf.pivots]
			e.failPivot = true
			DoorRuntime.stop()
			T.eq(e.leaf.pivots[#e.leaf.pivots], openPose, "the leaf physically stays open")
			T.eq(e.leafParts[1].CanCollide, false, "an unconfirmed close never restores collision")
			T.eq(e.leafParts[2].CanCollide, false)
			T.ok(e.logged("i1 could not be closed on shutdown; its leaf is left open at 90 degrees and non-colliding. Re-place the item or reload the build to reset it."), "actionable log")
			T.eq(e.controller:count(), 0, "registrations released anyway")
			T.eq(e.controller.core:count(), 0)
			T.eq(e.heartbeat.connects, 1)
			T.eq(e.heartbeat:live(), 0, "disconnected exactly once")
			T.eq(DoorRuntime.active(), nil)
			e.failPivot = false
			local logs, pivots = #e.logs, #e.leaf.pivots
			e.run(1.25, 3)
			DoorRuntime.stop()
			T.eq(#e.leaf.pivots, pivots, "no tick or second cleanup touches the leaf")
			T.eq(#e.logs, logs)
			T.eq(e.leafParts[1].CanCollide, false)
		end)
	end)

	T.test("rebind fault: the same rule holds when a new start replaces the runtime", function()
		run(function()
			local e = rig()
			e.approach()
			e.run(0, 1)
			e.failPivot = true
			local nextEnv = env(ON)
			local replacement = DoorRuntime.start(nextEnv.deps)
			T.ok(replacement ~= nil and replacement ~= e.controller)
			T.eq(e.leafParts[1].CanCollide, false, "left non-colliding")
			T.ok(e.logged("could not be closed on shutdown"))
			T.eq(e.controller.destroyed, true)
			T.eq(e.heartbeat:live(), 0)
			T.eq(nextEnv.heartbeat:live(), 1, "exactly one controller ticking")
			e.heartbeat:fire()
			T.eq(e.controller:count(), 0)
		end)
	end)

	T.test("stop faults in collision: no pose without collision off; a part-way restore is turned back off", function()
		run(function()
			-- Collision can't be turned off: the leaf is not moved at all.
			local e = rig()
			e.approach()
			e.run(0, 1)
			local openPose = e.leaf.pivots[#e.leaf.pivots]
			e.failCollision = function() return true end
			DoorRuntime.stop()
			T.eq(e.leaf.pivots[#e.leaf.pivots], openPose, "no pose without collision off")
			T.eq(e.leafParts[1].CanCollide, false, "still off from opening")
			T.ok(e.logged("could not turn its leaf collision off on shutdown"))
			T.ok(e.logged("could not be closed on shutdown"))
			T.eq(e.controller:count(), 0)
			T.eq(e.heartbeat:live(), 0)
			teardown()
			-- The leaf closes, but restoring fails on the second part after the first
			-- was turned solid: the first is turned back off.
			local f = rig()
			f.approach()
			f.run(0, 1)
			local first, secondState = f.leafParts[1], getmetatable(f.leafParts[2]).__index
			-- Restoring writes part 1 (true) then part 2 (false); fail part 2 while part 1 is solid.
			f.failCollision = function(state, value)
				return state == secondState and value == false and first.CanCollide == true
			end
			DoorRuntime.stop()
			T.ok(closedPose(f.leaf.pivots[#f.leaf.pivots]), "the leaf did close")
			T.eq(first.CanCollide, false, "the half-restored part is turned back off")
			T.ok(f.logged("i1 closed on shutdown but its collision could not be restored; it is left non-colliding."))
			T.eq(f.controller:count(), 0)
			T.eq(f.heartbeat:live(), 0)
		end)
	end)
end
