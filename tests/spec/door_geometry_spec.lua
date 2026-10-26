-- Panel door foundation: pure swing-volume geometry (DoorGeometry). The
-- measured values are the prepared candidate's (docs/assets/
-- Panel_Door_Candidate_Preparation_2026-10-26.json); the later module with
-- the raised frame will have its own metadata. Nothing here is wired live.
return function(T, H)
	local G = H.load("src/shared/DoorGeometry")
	local Codes = G.Codes

	local HINGE_X = 2.4998779297
	local LEAF_C = { 0.0998414308, 4.3001308441, 0 }
	local LEAF_S = { 5.2000732422, 8.2000856400, 0.9500000477 }
	local function measured(overrides)
		local m = { hinge = { x = HINGE_X, z = 0 }, leaf = { center = { LEAF_C[1], LEAF_C[2], LEAF_C[3] }, size = { LEAF_S[1], LEAF_S[2], LEAF_S[3] } }, swing = "-z", openDegrees = 90 }
		for k, v in pairs(overrides or {}) do m[k] = v end
		return m
	end

	-- Independent reference: Roblox CFrame.Angles(0, yaw, 0) applied to local (x, z), then translated.
	local function roomPoint(x, z, t)
		local r = math.rad(t.yaw)
		return t.x + x * math.cos(r) + z * math.sin(r), t.z - x * math.sin(r) + z * math.cos(r)
	end
	local function inside(box, x, z, tol)
		tol = tol or 1e-9
		return x >= box.minX - tol and x <= box.maxX + tol and z >= box.minZ - tol and z <= box.maxZ + tol
	end

	T.test("validate: accepts the measured leaf as a clean copy; rejects malformed, non-finite or ill-shaped metadata", function()
		local clean = G.validate(measured())
		T.ok(clean ~= nil)
		local source = measured()
		local copy = G.validate(source)
		source.leaf.size[1] = 99
		T.eq(copy.leaf.size[1], LEAF_S[1], "no aliasing")
		local bad = {
			"door", 7, {},
			measured({ extra = true }),
			measured({ swing = "+z" }),
			(function() local m = measured(); m.swing = nil; return m end)(),
			measured({ openDegrees = 0 }),
			measured({ openDegrees = 181 }),
			measured({ openDegrees = 0 / 0 }),
			measured({ hinge = { x = HINGE_X } }),
			measured({ hinge = { x = HINGE_X, z = 0, y = 1 } }),
			measured({ hinge = { x = math.huge, z = 0 } }),
			measured({ hinge = { x = 3.5, z = 0 } }), -- outside the leaf footprint
			measured({ hinge = { x = HINGE_X, z = 0.6 } }), -- outside the leaf thickness
			measured({ hinge = { x = LEAF_C[1], z = 0 } }), -- through the leaf centre: no swing side
			measured({ leaf = { center = LEAF_C, size = { 5.2, 8.2, 0 } } }),
			measured({ leaf = { center = LEAF_C, size = { 5.2, -8.2, 0.95 } } }),
			measured({ leaf = { center = LEAF_C, size = { 5.2, 8.2 } } }),
			measured({ leaf = { center = LEAF_C, size = { 5.2, 8.2, 0.95, 1 } } }),
			measured({ leaf = { center = { 0.1, 4.3, 0 / 0 }, size = LEAF_S } }),
			measured({ leaf = { center = { 0.1, 2, 0 }, size = LEAF_S } }), -- dips below the module floor
			measured({ leaf = { center = { 0.1, 4.3, 0 }, size = { 65, 8.2, 0.95 } } }),
			measured({ leaf = { center = LEAF_C } }),
		}
		for i, m in ipairs(bad) do
			local ok, code = G.validate(m)
			T.eq(ok, nil, "bad #" .. i)
			T.eq(code, Codes.BadDoor, "bad #" .. i)
		end
	end)

	T.test("sweptBox: exact corner-arc extents for the measured leaf, including thickness, hardware and the hinge-side protrusion", function()
		local box = G.sweptBox(G.validate(measured()))
		-- Leaf corners relative to the hinge: far side dx = -5.00007, hinge side dx = +0.20020, dz = +-0.475.
		local halfT = LEAF_S[3] / 2
		local farDx = (LEAF_C[1] - LEAF_S[1] / 2) - HINGE_X
		local nearDx = (LEAF_C[1] + LEAF_S[1] / 2) - HINGE_X
		local rFar = math.sqrt(farDx * farDx + halfT * halfT)
		local rNear = math.sqrt(nearDx * nearDx + halfT * halfT)
		local e = G.EPSILON
		-- The far corners pass -x (180 deg) and -z (270 deg); the hinge-side corners pass +x (0 deg) and +z (90 deg).
		T.ok(math.abs(box.minX - (HINGE_X - rFar - e)) < 1e-9, "minX")
		T.ok(math.abs(box.maxX - (HINGE_X + rNear + e)) < 1e-9, "maxX")
		T.ok(math.abs(box.minZ - (-rFar - e)) < 1e-9, "minZ")
		T.ok(math.abs(box.maxZ - (rNear + e)) < 1e-9, "maxZ")
		T.ok(math.abs(box.minY - (LEAF_C[2] - LEAF_S[2] / 2 - e)) < 1e-9 and math.abs(box.maxY - (LEAF_C[2] + LEAF_S[2] / 2 + e)) < 1e-9, "y bounds are the leaf's")
		-- The review's point: a zero-thickness radial rectangle x[-2.75, 2.5], z[-5.25, 0] does not contain the leaf.
		T.ok(box.maxX > 2.6999, "covers the closed leaf past the hinge (x about 2.7)")
		T.ok(box.maxX > 3.0 and box.maxZ > 0.5, "covers the hinge-side corner swinging out past +x and +z")
		T.ok(box.minZ < -5.02, "covers the far corner's full radius, not just the leaf width")
	end)

	T.test("sweptBox: every leaf corner at every sampled angle (0..90 by 0.25 deg) is inside, and the box is tight", function()
		local clean = G.validate(measured())
		local box = G.sweptBox(clean)
		local seen = { minX = math.huge, maxX = -math.huge, minZ = math.huge, maxZ = -math.huge }
		for step = 0, 360 do
			local deg = step * 0.25
			for _, p in ipairs(G.leafCornersAt(clean, deg)) do
				T.ok(inside(box, p[1], p[2]), ("corner outside at %.2f deg"):format(deg))
				seen.minX, seen.maxX = math.min(seen.minX, p[1]), math.max(seen.maxX, p[1])
				seen.minZ, seen.maxZ = math.min(seen.minZ, p[2]), math.max(seen.maxZ, p[2])
			end
		end
		for key, v in pairs(seen) do
			T.ok(math.abs(box[key] - v) < 1e-3, key .. " is tight to the sampled sweep")
		end
		-- Direction: at 90 deg the far edge is about 5 studs into -z, and the leaf's former -z face now faces +x.
		local far = G.leafCornersAt(clean, 90)[1]
		T.ok(far[2] < -4.9 and math.abs(far[1] - (HINGE_X + LEAF_S[3] / 2)) < 1e-6, "opens into -z")
	end)

	T.test("sweptBox: other arcs and a mirrored hinge stay conservative and still open into -z", function()
		local cases = {
			measured({ openDegrees = 45 }),
			measured({ openDegrees = 120 }),
			measured({ openDegrees = 180 }),
			-- Hinge on the -x side, leaf toward +x.
			{ hinge = { x = -2.4998779297, z = 0 }, leaf = { center = { -0.0998414308, 4.3, 0 }, size = LEAF_S }, swing = "-z", openDegrees = 90 },
		}
		for i, m in ipairs(cases) do
			local clean = G.validate(m)
			local box = G.sweptBox(clean)
			for step = 0, 200 do
				local deg = clean.openDegrees * step / 200
				for _, p in ipairs(G.leafCornersAt(clean, deg)) do
					T.ok(inside(box, p[1], p[2]), "case " .. i .. " at " .. deg)
				end
			end
			local c = G.leafCornersAt(clean, math.min(90, clean.openDegrees))
			local cz = (c[1][2] + c[2][2] + c[3][2] + c[4][2]) / 4
			T.ok(cz < 0, "case " .. i .. " opens into -z")
		end
	end)

	T.test("toRoom: all four cardinal yaws contain the transformed sweep; swing side follows the yaw; non-cardinal or bad transforms refused", function()
		local clean = G.validate(measured())
		local box = G.sweptBox(clean)
		local expectSide = { [0] = "minZ", [90] = "minX", [180] = "maxZ", [270] = "maxX" }
		for _, yaw in ipairs({ 0, 90, 180, 270 }) do
			local t = { x = 8, y = 0.5, z = -16, yaw = yaw }
			local room = G.toRoom(box, t)
			T.ok(room ~= nil, "yaw " .. yaw)
			T.ok(math.abs(room.minY - (0.5 + box.minY)) < 1e-12 and math.abs(room.maxY - (0.5 + box.maxY)) < 1e-12, "y offset")
			for step = 0, 180 do
				for _, p in ipairs(G.leafCornersAt(clean, step * 0.5)) do
					local wx, wz = roomPoint(p[1], p[2], t)
					T.ok(inside(room, wx, wz, 1e-9), ("yaw %d at %.1f deg"):format(yaw, step * 0.5))
				end
			end
			-- The deep side of the swing (about 5.02 from the wall line) lies on the expected room side.
			local side = expectSide[yaw]
			local centre = (side == "minZ" or side == "maxZ") and t.z or t.x
			T.ok(math.abs(room[side] - centre) > 5, "yaw " .. yaw .. " swings toward " .. side)
		end
		T.deepEq(G.toRoom(box, { x = 0, y = 0, z = 0, yaw = -90 }), G.toRoom(box, { x = 0, y = 0, z = 0, yaw = 270 }), "yaw normalized")
		for _, t in ipairs({ { x = 0, y = 0, z = 0, yaw = 45 }, { x = 0, y = 0, z = 0, yaw = 15 } }) do
			T.eq(select(2, G.toRoom(box, t)), Codes.BadYaw)
		end
		for _, t in ipairs({ "t", { x = 0 / 0, y = 0, z = 0, yaw = 0 }, { x = 0, y = math.huge, z = 0, yaw = 0 }, { x = 0, y = 0, z = 0 } }) do
			local _, code = G.toRoom(box, t)
			T.ok(code == Codes.BadTransform or code == Codes.BadYaw, tostring(code))
		end
	end)

	T.test("check: interior edges fit; an outward swing on an outer edge is SwingOutOfBounds; bounds validated", function()
		local m = measured()
		local live = { halfX = 24, halfZ = 24, height = 24 }
		T.ok(G.check(m, { x = 0, y = 0, z = 8, yaw = 0 }, live) ~= nil, "interior edge, swings toward z = 3")
		T.ok(G.check(m, { x = 8, y = 0, z = 0, yaw = 90 }, live) ~= nil, "interior edge along Z")
		T.eq(select(2, G.check(m, { x = 0, y = 0, z = -24, yaw = 0 }, live)), Codes.SwingOutOfBounds, "outer edge, swinging outward")
		-- Inward on the same outer edge: the swing itself is inside; only the hinge-side corner reaches
		-- about 0.515 beyond the wall line, so a marker must allow that much.
		local roomy = { halfX = 25, halfZ = 25, height = 24 }
		T.ok(G.check(m, { x = 0, y = 0, z = -24, yaw = 180 }, roomy) ~= nil, "outer edge, swinging inward")
		T.eq(select(2, G.check(m, { x = 0, y = 0, z = -24, yaw = 180 }, { halfX = 24.5, halfZ = 24.5, height = 24 })), Codes.SwingOutOfBounds,
			"the measured hinge-side protrusion (about 0.515) exceeds the 0.5 wall half-depth of a 49 marker")
		T.eq(select(2, G.check(m, { x = 0, y = 16, z = 8, yaw = 0 }, live)), Codes.SwingOutOfBounds, "too high for the ceiling")
		T.eq(select(2, G.check({}, { x = 0, y = 0, z = 8, yaw = 0 }, live)), Codes.BadDoor)
		for _, b in ipairs({ "b", { halfX = 24, halfZ = 24 }, { halfX = 0, halfZ = 24, height = 24 }, { halfX = 24, halfZ = 0 / 0, height = 24 } }) do
			T.eq(select(2, G.check(m, { x = 0, y = 0, z = 8, yaw = 0 }, b)), Codes.BadBounds)
		end
	end)

	T.test("gated: only door modules reference the runtime door modules; placement uses only the pure geometry; BuilderService reaches the runtime only through DoorRuntime", function()
		local DOOR_MODULES = { "DoorGeometry", "DoorAutoOpen", "DoorSensing", "DoorController", "DoorRuntimeAdapters", "DoorRuntime" }
		-- Catalog validation, server placement and the client preview may use the
		-- pure swept-box geometry; nothing outside the door modules may name the
		-- state machine or the runtime layer.
		local GEOMETRY_USERS = {
			["src/shared/Catalog.luau"] = true,
			["src/server/Core/PlacementCore.luau"] = true,
			["src/client/Build/PlacementPreview.luau"] = true,
		}
		-- BuilderService may name DoorRuntime (the disabled-by-default factory) only.
		local RUNTIME_USERS = { ["src/server/Runtime/BuilderService.luau"] = true }
		local geometryUsers = {}
		for _, rel in ipairs(H.sourceList) do
			local isDoorModule = false
			for _, name in ipairs(DOOR_MODULES) do
				if rel:find("/" .. name .. ".luau", 1, true) then isDoorModule = true end
			end
			if not isDoorModule then
				local src = H.readFile(H.ROOT .. "/" .. rel)
				for _, name in ipairs(DOOR_MODULES) do
					if name == "DoorGeometry" and GEOMETRY_USERS[rel] then
						T.ok(src:find(name, 1, true), rel .. " uses DoorGeometry")
						geometryUsers[#geometryUsers + 1] = rel
					elseif name == "DoorRuntime" and RUNTIME_USERS[rel] then
						T.ok(src:find("require(script.Parent:WaitForChild(\"DoorRuntime\"))", 1, true), rel .. " requires DoorRuntime")
					else
						T.eq(src:find(name, 1, true), nil, rel .. " references " .. name)
					end
				end
			end
		end
		T.eq(#geometryUsers, 3, "every allowed geometry user is in the source list")
		-- The world's door hook is the flag-gated runtime (nil by default); see door_runtime_spec.
		local service = H.readFile(H.ROOT .. "/src/server/Runtime/BuilderService.luau")
		T.eq(service:match("PlacedItemsWorld%.new(%b())"), "(placedFolder, sandbox.origin, curatedTemplate, doors)")
		local config = H.load("src/shared/Config")
		T.eq(config.Doors.Enabled, false, "shipped disabled")
		-- Door state is transient: no door module touches saves, revisions or the build model.
		for _, name in ipairs(DOOR_MODULES) do
			for _, rel in ipairs(H.sourceList) do
				if rel:find("/" .. name .. ".luau", 1, true) then
					local src = H.readFile(H.ROOT .. "/" .. rel)
					for _, word in ipairs({ "SaveSnapshot", "BuildModel", "BuildPersistence", "publishRevision", "BuildRevision", "SetAttribute", "DataStore" }) do
						T.eq(src:find(word, 1, true), nil, rel .. " mentions " .. word)
					end
				end
			end
		end
	end)
end
