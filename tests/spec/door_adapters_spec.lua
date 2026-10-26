-- Panel door runtime: the Roblox-facing adapters with injected fake types.
-- These check the formulas and mappings only; real CFrame maths, overlap
-- queries, physics and replication are NOT exercised and stay unverified.
return function(T, H)
	local Adapters = H.load("src/server/Runtime/DoorRuntimeAdapters")
	local G = H.load("src/shared/DoorGeometry")

	local META = { hinge = { x = 2.5, z = 0 }, leaf = { center = { 0.1, 4.3, 0 }, size = { 5.2, 8.2, 0.95 } }, swing = "-z", openDegrees = 90 }

	-- Fake CFrame: descriptive strings composed in order.
	local function cf(desc)
		local c = { desc = desc }
		function c:Inverse() return cf("inv(" .. desc .. ")") end
		function c:ToObjectSpace(other) return cf("inv(" .. desc .. ")*" .. other.desc) end
		-- origin "O" sits at world y = 1: room = world - (0, 1, 0)
		function c:PointToObjectSpace(v) return { X = v.X, Y = v.Y - 1, Z = v.Z } end
		return setmetatable(c, { __mul = function(a, b) return cf(a.desc .. "*" .. b.desc) end })
	end
	local CF = {
		new = function(x, y, z) return cf(string.format("T(%g,%g,%g)", x, y, z)) end,
		Angles = function(_, y) return cf(string.format("R(%.4f)", y)) end,
	}
	local V3 = { new = function(x, y, z) return { X = x, Y = y, Z = z } end }

	local function part(canCollide)
		return { CanCollide = canCollide, IsA = function(_, c) return c == "BasePart" end }
	end

	T.test("driver: the leaf pose is built from the stored record and hinge, never the model's current pivot; collision originals restored", function()
		local p1, p2, p3 = part(true), part(false), part(true)
		local pivots = {}
		local leaf = {
			GetPivot = function() return cf("LEAFCLOSED") end,
			GetDescendants = function() return { p1, p2, p3, { IsA = function() return false end } } end,
			PivotTo = function(_, c) pivots[#pivots + 1] = c.desc end,
		}
		local model = {
			FindFirstChild = function(_, n) if n == "Leaf" then return leaf end end,
			GetPivot = function() error("the module pivot must never be read from the model") end,
		}
		local driver = Adapters.driver({ origin = cf("O"), CFrame = CF })
		local reg = { id = "i1", model = model, spec = G.validate(META), record = { x = 0, y = 0, z = 8, yaw = 90 } }
		driver:attach(reg)
		T.eq(reg.leafOffset.desc, "inv(O*T(0,0,8)*R(1.5708))*LEAFCLOSED", "closed offset from the record's module pivot")
		driver:pose(reg, 90)
		-- swingSign = +1 (leaf centre on -x of the hinge), so the Roblox turn is -90 degrees.
		T.eq(pivots[1], "O*T(0,0,8)*R(1.5708)*T(2.5,0,0)*R(-1.5708)*inv(T(2.5,0,0))*inv(O*T(0,0,8)*R(1.5708))*LEAFCLOSED")
		reg.record = { x = 16, y = 0, z = 8, yaw = 90 } -- moved: poses follow the stored record
		driver:pose(reg, 0)
		T.ok(pivots[2]:find("^O%*T%(16,0,8%)%*R%(1%.5708%)%*T%(2%.5,0,0%)%*R%(%-?0%.0000%)"), pivots[2])
		driver:setCollision(reg, false)
		T.ok(not p1.CanCollide and not p2.CanCollide and not p3.CanCollide, "all off")
		driver:setCollision(reg, true)
		T.ok(p1.CanCollide == true and p2.CanCollide == false and p3.CanCollide == true, "originals restored, not forced on")
		driver:detach(reg)
		T.eq(reg.collision, nil)
		local noLeaf = { model = { FindFirstChild = function() end }, spec = reg.spec, record = reg.record }
		T.eq(pcall(driver.attach, driver, noLeaf), false, "a door model without a Leaf can't be attached")
	end)

	T.test("characters: alive flag from Humanoid health, room-space root positions, characters without parts skipped", function()
		local function character(health, x, y, z, noRoot)
			local humanoid = { Health = health }
			local root = { Position = { X = x, Y = y, Z = z } }
			return {
				FindFirstChildOfClass = function(_, c) if c == "Humanoid" then return humanoid end end,
				FindFirstChild = function(_, n) if n == "HumanoidRootPart" and not noRoot then return root end end,
			}
		end
		local alive, dead = character(100, 1, 4, 9), character(0, 2, 4, 9)
		local players = { GetPlayers = function()
			return { { Character = alive }, { Character = dead }, { Character = nil }, { Character = character(100, 0, 0, 0, true) } }
		end }
		local list = Adapters.characters({ origin = cf("O"), Players = players })()
		T.eq(#list, 2)
		T.deepEq(list[1], { alive = true, position = { x = 1, y = 3, z = 9 }, model = alive })
		T.eq(list[2].alive, false, "reported, then filtered by DoorSensing")
	end)

	T.test("queryBox: room box to a sandbox-frame query; hits name their top-level model; truncation reported", function()
		local folder = { name = "folder" }
		local door = { Parent = folder, IsA = function(_, c) return c == "Model" end }
		local leafModel = { Parent = door, IsA = function(_, c) return c == "Model" end }
		local charModel = { Parent = { Parent = nil, IsA = function() return false end }, IsA = function(_, c) return c == "Model" end }
		local floorPiece = { Parent = folder, IsA = function(_, c) return c == "Model" end }
		local parts = {
			{ Parent = leafModel, Position = { X = 0, Y = 5, Z = 8 }, Size = { Y = 2 } },
			{ Parent = charModel, Position = { X = 0, Y = 4, Z = 8 }, Size = { Y = 2 } },
			{ Parent = floorPiece, Position = { X = 0, Y = 1.5, Z = 8 }, Size = { Y = 1 } },
		}
		local query
		local ws = { GetPartBoundsInBox = function(_, c, size, params) query = { c = c.desc, size = size, max = params.MaxParts } return parts end }
		local q = Adapters.queryBox({
			origin = cf("O"), folder = folder, maxHits = 3, workspace = ws, CFrame = CF, Vector3 = V3,
			OverlapParams = { new = function() return {} end },
			isSupportingFloor = function(_, model) return model == floorPiece end,
		})
		local hits, truncated = q({ minX = -2, maxX = 4, minY = 0, maxY = 9, minZ = 3, maxZ = 9 })
		T.eq(query.c, "O*T(1,4.5,6)")
		T.deepEq(query.size, { X = 6, Y = 9, Z = 6 })
		T.eq(query.max, 3)
		T.eq(hits[1].model, door, "a leaf part maps to its placed door model")
		T.eq(hits[2].model, charModel, "a character part maps to the character model")
		T.eq(hits[3].model, floorPiece)
		T.eq(hits[3].supportingFloor, true)
		T.eq(hits[3].maxY, 1, "top of the floor part in room space")
		T.eq(truncated, true, "MaxParts reached: reported as truncated")
		parts[3] = nil
		local _, t2 = q({ minX = -2, maxX = 4, minY = 0, maxY = 9, minZ = 3, maxZ = 9 })
		T.eq(t2, false)
	end)
end
