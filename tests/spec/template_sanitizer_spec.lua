return function(T, H)
	local TemplateSanitizer = H.load("src/server/Runtime/TemplateSanitizer")

	-- Minimal fake instance tree. `classes` lists the class and its ancestors for IsA.
	local HIERARCHY = {
		Model = { "Model" },
		Part = { "Part", "BasePart" },
		MeshPart = { "MeshPart", "BasePart" },
		Seat = { "Seat", "Part", "BasePart" },
		VehicleSeat = { "VehicleSeat", "BasePart" },
		Script = { "Script", "BaseScript", "LuaSourceContainer" },
		LocalScript = { "LocalScript", "Script", "BaseScript", "LuaSourceContainer" },
		ModuleScript = { "ModuleScript", "LuaSourceContainer" },
		ClickDetector = { "ClickDetector" },
		ProximityPrompt = { "ProximityPrompt" },
		RemoteEvent = { "RemoteEvent" },
		BindableEvent = { "BindableEvent" },
		PointLight = { "PointLight", "Light" },
		Sound = { "Sound" },
		ParticleEmitter = { "ParticleEmitter" },
		Decal = { "Decal" },
	}

	local function node(className, children)
		local n = { ClassName = className, children = children or {}, destroyed = false }
		function n:IsA(name)
			for _, c in ipairs(HIERARCHY[className]) do
				if c == name then
					return true
				end
			end
			return false
		end
		function n:Destroy()
			self.destroyed = true
		end
		function n:GetDescendants()
			local out = {}
			local function walk(x)
				for _, child in ipairs(x.children) do
					out[#out + 1] = child
					walk(child)
				end
			end
			walk(self)
			return out
		end
		return n
	end

	local function sampleTemplate()
		local refs = {}
		refs.body = node("Part")
		refs.mesh = node("MeshPart", { node("Decal") })
		refs.seat = node("Seat")
		refs.vseat = node("VehicleSeat")
		refs.script = node("Script")
		refs.legacy = node("Part", { node("ClickDetector"), node("ProximityPrompt"), node("RemoteEvent"), node("BindableEvent"), node("ModuleScript") })
		refs.light = node("PointLight")
		refs.sound = node("Sound")
		refs.fx = node("ParticleEmitter")
		refs.body.children = { refs.light, refs.sound, refs.fx, node("LocalScript") }
		local model = node("Model", { refs.body, refs.mesh, refs.seat, refs.vseat, refs.script, refs.legacy })
		return model, refs
	end

	T.test("placement copies lose all code and legacy interaction objects", function()
		local model, refs = sampleTemplate()
		local counts = TemplateSanitizer.forPlacement(model)
		T.eq(refs.script.destroyed, true)
		for _, child in ipairs(refs.legacy.children) do
			T.eq(child.destroyed, true, child.ClassName)
		end
		T.eq(refs.body.children[4].destroyed, true, "nested LocalScript")
		T.eq(counts.removed, 7)
		T.eq(refs.light.destroyed, false, "placed lamps keep their light")
		T.eq(refs.mesh.children[1].destroyed, false, "decals stay")
	end)

	T.test("all parts anchored; seats disabled and untouchable", function()
		local model, refs = sampleTemplate()
		local counts = TemplateSanitizer.forPlacement(model)
		for _, part in ipairs({ refs.body, refs.mesh, refs.seat, refs.vseat, refs.legacy }) do
			T.eq(part.Anchored, true, part.ClassName)
		end
		T.eq(refs.seat.Disabled, true)
		T.eq(refs.seat.CanTouch, false)
		T.eq(refs.vseat.Disabled, true)
		T.eq(counts.seatsDisabled, 2)
		T.eq(refs.body.CanCollide, nil, "placement keeps collision as authored")
	end)

	T.test("preview copies are inert: no collision, query, touch, shadows, audio, lights or effects", function()
		local model, refs = sampleTemplate()
		TemplateSanitizer.forPreview(model)
		for _, part in ipairs({ refs.body, refs.mesh, refs.seat, refs.vseat }) do
			T.eq(part.CanCollide, false, part.ClassName)
			T.eq(part.CanQuery, false)
			T.eq(part.CanTouch, false)
			T.eq(part.CastShadow, false)
		end
		T.eq(refs.light.destroyed, true)
		T.eq(refs.sound.destroyed, true)
		T.eq(refs.fx.destroyed, true)
		T.eq(refs.script.destroyed, true)
	end)
end
