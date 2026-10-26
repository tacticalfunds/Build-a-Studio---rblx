return function(T, H)
	local Catalog = H.load("src/shared/Catalog")

	local function copyData()
		local collections, items = {}, {}
		for i, c in ipairs(Catalog.Collections) do
			collections[i] = { id = c.id, displayName = c.displayName, order = c.order, entitlement = c.entitlement }
		end
		for i, item in ipairs(Catalog.Items) do
			local tags = {}
			for j, tag in ipairs(item.collections) do
				tags[j] = tag
			end
			items[i] = { id = item.id, displayName = item.displayName, collections = tags, sourceRef = item.sourceRef }
		end
		return collections, items
	end

	local function hasError(errors, needle)
		for _, e in ipairs(errors) do
			if string.find(e, needle, 1, true) then
				return true
			end
		end
		return false
	end

	T.test("shipped catalog validates", function()
		local ok, errors = Catalog.validate()
		T.ok(ok, table.concat(errors, "; "))
	end)

	T.test("collections are Cozy, 1980s, Retro, Winter, Futuristic and all free", function()
		local expected = { cozy = "Cozy", ["1980s"] = "1980s", retro = "Retro", winter = "Winter", futuristic = "Futuristic" }
		local count = 0
		for _, c in ipairs(Catalog.Collections) do
			count = count + 1
			T.eq(c.displayName, expected[c.id], "collection " .. c.id)
			T.eq(c.entitlement.kind, "free", "entitlement for " .. c.id)
		end
		T.eq(count, 5, "collection count")
	end)

	local ORIGINAL = {
		"cozy_armchair_01", "cozy_coffee_table_01", "cozy_bookshelf_01", "cozy_plant_01",
		"cozy_floor_lamp_01", "retro_tv_cart_01", "retro_cassette_01",
	}
	local EXPANSION = {
		"cozy_book_set_01", "cozy_monstera_01", "cozy_upholstered_chair_01", "future_curved_sofa_01",
		"future_glass_table_01", "future_modern_lamp_01", "future_shelf_01", "modern_lounge_chair_01",
		"retro_book_01", "retro_crt_tv_01", "retro_meeting_table_01", "studio_boom_mic_01",
		"studio_chair_01", "studio_desk_lamp_01", "studio_desk_mic_01", "studio_headphones_01",
		"studio_mixer_01", "winter_firewood_shelf_01", "winter_folded_throw_01", "winter_furry_chair_01",
		"winter_lantern_01", "winter_log_basket_01", "winter_snow_globe_01", "winter_white_rug_01",
	}

	local STRUCTURE = {
		structure_wall_01 = "wall", structure_window_wall_01 = "window_wall", structure_doorway_01 = "doorway",
		structure_floor_01 = "floor", structure_ceiling_01 = "ceiling",
	}
	local STRUCTURE_ORDER = { "structure_wall_01", "structure_window_wall_01", "structure_doorway_01", "structure_floor_01", "structure_ceiling_01" }

	local DECOR = { "retro_record_player_01", "retro_radio_01", "retro_patterned_rug_01", "retro_classic_floor_lamp_01" }

	local STRUCTURE_VARIANTS = {
		structure_floor_oak_01 = "floor", structure_floor_walnut_01 = "floor", structure_floor_concrete_01 = "floor",
		structure_floor_slate_01 = "floor", structure_wall_wood_01 = "wall", structure_wall_brick_01 = "wall",
		structure_ceiling_dark_01 = "ceiling", structure_window_black_01 = "window_wall", structure_doorway_wide_01 = "doorway",
	}
	local VARIANT_ORDER = {
		"structure_floor_oak_01", "structure_floor_walnut_01", "structure_floor_concrete_01", "structure_floor_slate_01",
		"structure_wall_wood_01", "structure_wall_brick_01", "structure_ceiling_dark_01", "structure_window_black_01",
		"structure_doorway_wide_01",
	}
	local FUTURISTIC_FURNITURE = { "future_speaker_01", "future_layered_coffee_table_01" }
	local SOFA = "cozy_tufted_leather_sofa_01"
	local BATCH03_STRUCTURE = { structure_glass_partition_01 = "window_wall", structure_ceiling_acoustic_01 = "ceiling" }
	local BATCH03_ORDER = { "structure_glass_partition_01", "structure_ceiling_acoustic_01" }
	local INDUSTRIAL_WALL = "structure_industrial_wall_01"

	T.test("catalog holds 7 original, 24 expansion, 5 structure, 4 later furniture, 9 structure variant, 2 futuristic furniture, 1 sofa, 2 batch 03 structure and 1 industrial wall ID, earlier entries unchanged in order", function()
		T.eq(#Catalog.Items, 55, "item count")
		T.eq(Catalog.Items[55].id, INDUSTRIAL_WALL, "the industrial wall is appended last")
		T.eq(Catalog.Items[52].id, SOFA, "the sofa follows the futuristic furniture")
		T.eq(Catalog.Items[53].id, BATCH03_ORDER[1], "batch 03 structure #1")
		T.eq(Catalog.Items[54].id, BATCH03_ORDER[2], "batch 03 structure #2")
		for i, id in ipairs(FUTURISTIC_FURNITURE) do
			T.eq(Catalog.Items[#ORIGINAL + #EXPANSION + #STRUCTURE_ORDER + #DECOR + #VARIANT_ORDER + i].id, id, "futuristic furniture #" .. i)
		end
		for i, id in ipairs(VARIANT_ORDER) do
			T.eq(Catalog.Items[#ORIGINAL + #EXPANSION + #STRUCTURE_ORDER + #DECOR + i].id, id, "variant #" .. i)
		end
		for i, id in ipairs(STRUCTURE_ORDER) do
			T.eq(Catalog.Items[#ORIGINAL + #EXPANSION + i].id, id, "structure #" .. i)
		end
		for i, id in ipairs(DECOR) do
			T.eq(Catalog.Items[#ORIGINAL + #EXPANSION + #STRUCTURE_ORDER + i].id, id, "decor #" .. i)
		end
		for i, id in ipairs(ORIGINAL) do
			T.eq(Catalog.Items[i].id, id, "original #" .. i)
		end
		for i, id in ipairs(EXPANSION) do
			T.eq(Catalog.Items[#ORIGINAL + i].id, id, "expansion #" .. i)
		end
	end)

	T.test("item IDs and display names are unique", function()
		local ids, names = {}, {}
		for _, item in ipairs(Catalog.Items) do
			T.eq(ids[item.id], nil, "duplicate id " .. item.id)
			T.eq(names[item.displayName], nil, "duplicate displayName " .. item.displayName)
			ids[item.id], names[item.displayName] = true, true
		end
	end)

	T.test("collection tag counts match the data, and every collection has items", function()
		-- Style filters show furniture only; the 5 structure pieces carry all five tags but live in Structure mode.
		-- Later furniture: record player, radio and rug (cozy, retro, 1980s) and the lamp (also winter).
		-- Futuristic furniture: the speaker and the layered coffee table (futuristic only).
		-- Tufted leather sofa: cozy, retro, 1980s and winter.
		-- Batch 03 structure: the glass partition and the acoustic ceiling carry all five tags (16 structure pieces).
		-- The industrial wall is the first structure piece with narrower tags: futuristic and 1980s only.
		local structureTags = { cozy = 16, retro = 16, ["1980s"] = 17, winter = 16, futuristic = 17 }
		local expected = { cozy = 27, retro = 21, ["1980s"] = 17, winter = 13, futuristic = 11 }
		for _, c in ipairs(Catalog.Collections) do
			T.eq(#Catalog.getFurnitureTagged(c.id), expected[c.id], c.id .. " furniture count")
			T.eq(#Catalog.getItemsTagged(c.id), expected[c.id] + structureTags[c.id], c.id .. " raw tag count (structure pieces included)")
			for _, item in ipairs(Catalog.getFurnitureTagged(c.id)) do
				T.eq(item.structure, nil, item.id)
			end
		end
		local perKind = { floor = 5, wall = 4, doorway = 2, ceiling = 3, window_wall = 3 }
		local structureTotal = 0
		for _, f in ipairs(Catalog.StructureFilters) do
			local items = Catalog.getStructureItems(f.id)
			T.eq(#items, perKind[f.id], f.id)
			for _, item in ipairs(items) do
				T.eq(STRUCTURE[item.id] or STRUCTURE_VARIANTS[item.id] or BATCH03_STRUCTURE[item.id] or (item.id == INDUSTRIAL_WALL and "wall"), f.id, item.id)
			end
			structureTotal = structureTotal + #items
		end
		T.eq(structureTotal, 17)
		local labels = {}
		for i, f in ipairs(Catalog.StructureFilters) do labels[i] = f.displayName end
		T.eq(table.concat(labels, ","), "Floors,Walls,Doors,Ceilings,Windows")
		local eighties = {}
		for _, item in ipairs(Catalog.getItemsTagged("1980s")) do
			eighties[item.id] = true
		end
		T.ok(eighties.retro_tv_cart_01 and eighties.retro_cassette_01 and eighties.cozy_armchair_01 and eighties.retro_crt_tv_01, "1980s tags")
		local future = {}
		for _, item in ipairs(Catalog.getItemsTagged("futuristic")) do
			future[item.id] = true
		end
		T.ok(future.future_curved_sofa_01 and future.studio_mixer_01 and not future.cozy_plant_01, "futuristic tags")
		T.eq(#Catalog.getItemsTagged("nope"), 0, "unknown tag")
	end)

	T.test("expansion entries match the committed manifest exactly (id, name, tags, sourceRef; zero scripts; decorative)", function()
		local manifest = H.readFile(H.ROOT .. "/docs/assets/Catalog_Expansion_2026-10-25.json")
		local count = 0
		for _ in manifest:gmatch('"templatePath"') do count = count + 1 end
		T.eq(count, #EXPANSION, "manifest item count")
		for _, id in ipairs(EXPANSION) do
			local item = Catalog.getItem(id)
			T.ok(item ~= nil, "missing " .. id)
			-- The manifest entry for this id: from its "collections" (which precede "id") to its "size".
			local idAt = manifest:find('"id": "' .. id .. '"', 1, true)
			T.ok(idAt, "manifest has " .. id)
			local entryStart = 1
			for pos in manifest:gmatch('()"collections"') do
				if pos < idAt then entryStart = pos end
			end
			local entry = manifest:sub(entryStart, (manifest:find('"size"', idAt, true)))
			T.ok(entry:find('"displayName": "' .. item.displayName .. '"', 1, true), id .. " displayName")
			T.ok(entry:find('"sourceRef": "' .. item.sourceRef .. '"', 1, true), id .. " sourceRef")
			T.ok(entry:find('"templatePath": "ServerStorage.StudioBuilderExpansion.' .. id .. '"', 1, true), id .. " templatePath")
			T.ok(entry:find('"scripts": 0,', 1, true), id .. " has zero scripts")
			T.ok(entry:find("Decorative only", 1, true), id .. " is decorative")
			local tags = {}
			for tag in entry:match('"collections": (%b[])'):gmatch('"([^"]+)"') do tags[tag] = true end
			local mine = {}
			for _, tag in ipairs(item.collections) do mine[tag] = true end
			T.deepEq(mine, tags, id .. " collections")
			-- Source asset IDs stay in the manifest only.
			for key in pairs(item) do
				T.ok(key ~= "sourceAssetId" and key ~= "templatePath", id .. " carries " .. key)
			end
		end
	end)

	T.test("candidates: exactly the 5 structure pieces and 2 decor items are registered from the manifest; deferred ones and rejected asset IDs stay out", function()
		local manifest = H.readFile(H.ROOT .. "/docs/assets/Structure_and_Decor_Candidates_2026-10-25.json")
		local ids = {}
		for entry in manifest:gmatch('"templatePath": "ServerStorage%.StudioStructureCandidates%.([%w_]+)"') do
			ids[#ids + 1] = entry
		end
		T.eq(#ids, 10, "candidate count")
		local index = H.readFile(H.ROOT .. "/docs/assets/README.md")
		local deferred = { structure_corner_01 = true, structure_industrial_window_01 = true, cozy_shoji_divider_01 = true }
		local decor = { retro_record_player_01 = true, retro_radio_01 = true }
		for _, id in ipairs(ids) do
			T.ok(index:find("`" .. id .. "`", 1, true), id .. " is indexed in docs/assets/README.md")
			local item = Catalog.getItem(id)
			if deferred[id] then
				T.eq(item, nil, id .. " is deferred and must not be registered")
			else
				T.ok(item ~= nil, id .. " is registered")
				if decor[id] then
					T.eq(item.structure, nil, id .. " is decorative furniture, not a structure piece")
				else
					T.eq(item.structure.kind, STRUCTURE[id], id .. " kind")
				end
				-- Exact name, tags and sourceRef from this candidate's manifest entry.
				local at = manifest:find('"id": "' .. id .. '"', 1, true)
				local stop = manifest:find('"collections"', at, true)
				local entry = manifest:sub(at, stop and select(2, manifest:find("%b[]", stop)) or #manifest)
				T.ok(entry:find('"displayName": "' .. item.displayName .. '"', 1, true), id .. " displayName")
				T.ok(entry:find('"sourceRef": "' .. item.sourceRef .. '"', 1, true), id .. " sourceRef")
				local tags = {}
				for tag in entry:match('"collections": (%b[])'):gmatch('"([^"]+)"') do tags[tag] = true end
				local mine = {}
				for _, tag in ipairs(item.collections) do mine[tag] = true end
				T.deepEq(mine, tags, id .. " collections")
				for key in pairs(item) do
					T.ok(key ~= "sourceAssetId" and key ~= "templatePath" and key ~= "sourceUrl", id .. " carries " .. key)
				end
			end
		end
		local rejected = manifest:match('"rejected": (%b[])')
		local rejectedIds = {}
		for assetId in rejected:gmatch('"assetId": "(%d+)"') do
			rejectedIds[#rejectedIds + 1] = assetId
		end
		T.eq(#rejectedIds, 2, "rejected imports")
		for _, assetId in ipairs(rejectedIds) do
			T.ok(index:find(assetId, 1, true), assetId .. " rejection kept in the index")
			for _, path in ipairs(H.sourceList) do
				T.eq(H.readFile(H.ROOT .. "/" .. path):find(assetId, 1, true), nil, assetId .. " appears in " .. path)
			end
		end
		T.ok(index:find("RushioLCO (credit requested; keep it)", 1, true), "record player credit kept in the index")
		T.ok(manifest:find('"credits": "RushioLCO (credit requested)"', 1, true))
		T.eq(Catalog.getItem("retro_record_player_01").credit, "RushioLCO (credit requested)", "record player credit kept verbatim in the catalog")
		T.eq(Catalog.getItem("retro_radio_01").credit, nil, "no credit text in the manifest for the radio")
		local ceiling = H.readFile(H.ROOT .. "/src/shared/Catalog.luau")
		T.ok(ceiling:find("Neutral recolour of the kit floor geometry", 1, true), "ceiling provenance noted in the catalog")
	end)

	-- Tracked candidates approved one at a time, each with its own provenance manifest.
	local APPROVED_TRACKED = {
		{ id = "retro_patterned_rug_01", manifest = "Decor_Candidate_retro_patterned_rug_01_2026-10-26.json", creator = "caductis", type = "decor" },
		{ id = "retro_classic_floor_lamp_01", manifest = "Decor_Candidate_retro_classic_floor_lamp_01_2026-10-26.json", creator = "bearduckmonkey", type = "lighting" },
	}

	T.test("approved tracked candidates: each registered exactly from its manifest, appended in order; no other tracked import is registered", function()
		local base = #ORIGINAL + #EXPANSION + #STRUCTURE_ORDER + 2 -- + record player, radio
		local expectedInspected = {}
		for i, a in ipairs(APPROVED_TRACKED) do
			local manifest = H.readFile(H.ROOT .. "/docs/assets/" .. a.manifest)
			local item = Catalog.getItem(a.id)
			T.ok(item ~= nil, a.id)
			T.eq(Catalog.Items[base + i].id, a.id, a.id .. " appended in approval order")
			T.ok(manifest:find('"id": "' .. a.id .. '"', 1, true), a.id .. " manifest id")
			T.ok(manifest:find('"displayName": "' .. item.displayName .. '"', 1, true), a.id .. " displayName")
			T.ok(manifest:find('"sourceRef": "' .. item.sourceRef .. '"', 1, true), a.id .. " sourceRef")
			T.ok(manifest:find('"type": "' .. item.type .. '"', 1, true), a.id .. " type")
			T.eq(item.type, a.type)
			T.eq(item.structure, nil)
			local tags = {}
			for tag in manifest:match('"collections": (%b[])'):gmatch('"([^"]+)"') do tags[tag] = true end
			local mine = {}
			for _, tag in ipairs(item.collections) do mine[tag] = true end
			T.deepEq(mine, tags, a.id .. " collections")
			T.ok(manifest:find('"sourceCreator": "' .. a.creator .. '"', 1, true), a.id .. " creator recorded")
			T.ok(manifest:find('"scripts": 0,', 1, true), a.id .. " zero scripts recorded")
			T.ok(manifest:find("NOT approved", 1, true), a.id .. " manifest records the unapproved pillows")
			for key in pairs(item) do
				T.ok(key ~= "sourceAssetId" and key ~= "templatePath" and key ~= "sourceUrl", a.id .. " carries " .. key)
			end
			expectedInspected[#expectedInspected + 1] = a.id
		end
		T.eq(#Catalog.Items, base + #APPROVED_TRACKED + #VARIANT_ORDER + #FUTURISTIC_FURNITURE + 1 + #BATCH03_ORDER + 1, "only the structure variants, futuristic furniture, the sofa, the batch 03 structure and the industrial wall follow the approved tracked items")
		expectedInspected[#expectedInspected + 1] = "structure_wall_brick_01" -- the tracked White Brick Wall, resized (structure manifest)
		local inspected = {}
		for _, item in ipairs(Catalog.Items) do
			if item.sourceRef:find("NextCatalogInspection", 1, true) then
				inspected[#inspected + 1] = item.id
			end
		end
		T.deepEq(inspected, expectedInspected, "only approved tracked imports point at inspection copies")
		for _, item in ipairs(Catalog.Items) do
			T.eq(item.displayName:lower():find("pillow", 1, true), nil, "no pillow registered: " .. item.id)
		end
		-- The lamp is honestly decorative: the manifest records no Light object.
		local lamp = H.readFile(H.ROOT .. "/docs/assets/Decor_Candidate_retro_classic_floor_lamp_01_2026-10-26.json")
		T.ok(lamp:find('"lights": 0,', 1, true))
		T.ok(lamp:find("no illumination", 1, true))
	end)

	T.test("structure variants: registered exactly from their manifest, on the grid module, provenance kept out of the catalog", function()
		local StructureGrid = H.load("src/shared/StructureGrid")
		local manifest = H.readFile(H.ROOT .. "/docs/assets/Structure_Expansion_2026-10-26.json")
		local count = 0
		for _ in manifest:gmatch('"preparedPath"') do count = count + 1 end
		T.eq(count, 9, "manifest items")
		local bounds = { halfX = 24.5, halfZ = 24.5, height = 24 }
		local spot = { floor = { 0, 0, 0, 0 }, ceiling = { 0, 15, 0, 90 }, wall = { 0, 0, 8, 0 }, window_wall = { 8, 0, 0, 90 }, doorway = { 0, 0, -8, 180 } }
		for _, id in ipairs(VARIANT_ORDER) do
			local item = Catalog.getItem(id)
			T.ok(item ~= nil, id)
			T.eq(item.structure.kind, STRUCTURE_VARIANTS[id], id .. " kind")
			T.eq(item.type, nil, id .. " has no furniture type")
			local at = manifest:find('"id": "' .. id .. '"', 1, true)
			T.ok(at, id .. " in manifest")
			-- The manifest entry for this id: from the preceding "collections" to its "size".
			local start = 1
			for pos in manifest:gmatch('()"collections"') do if pos < at then start = pos end end
			local entry = manifest:sub(start, manifest:find('"size"', at, true))
			T.ok(entry:find('"displayName": "' .. item.displayName .. '"', 1, true), id .. " displayName")
			T.ok(entry:find('"sourceRef": "' .. item.sourceRef .. '"', 1, true), id .. " sourceRef")
			T.ok(entry:find('"kind": "' .. item.structure.kind .. '"', 1, true), id .. " kind in manifest")
			T.ok(entry:find('"preparedPath": "ServerStorage.StructureExpansionCandidates.' .. id .. '"', 1, true), id .. " install source")
			T.ok(entry:find('"scripts": 0', 1, true), id .. " zero scripts")
			local tags = {}
			for tag in entry:match('"collections": (%b[])'):gmatch('"([^"]+)"') do tags[tag] = true end
			local mine = {}
			for _, tag in ipairs(item.collections) do mine[tag] = true end
			T.deepEq(mine, tags, id .. " collections")
			for key in pairs(item) do
				T.ok(key ~= "sourceAssetId" and key ~= "preparedPath" and key ~= "adaptation", id .. " carries " .. key)
			end
			-- The manifest size fits the grid module for its kind.
			local sx, sy, sz = manifest:sub(at):match('"size": %[%s*([%d%.]+),%s*([%d%.]+),%s*([%d%.]+)')
			local size = { tonumber(sx), tonumber(sy), tonumber(sz) }
			local p = spot[item.structure.kind]
			T.ok(StructureGrid.validate(item.structure.kind, { x = p[1], y = p[2], z = p[3], yaw = p[4] }, size, bounds) ~= nil, id .. " validates on the grid")
		end
		T.ok(manifest:find("8 studs wide and 9 studs high above a 1-stud threshold", 1, true), "wide doorway opening recorded")
		T.ok(manifest:find("Avatar walkthrough not tested", 1, true))
		T.ok(manifest:find("not nine independent marketplace models", 1, true))
	end)

	T.test("futuristic furniture: exactly two batch 02 pieces registered from their manifest; the other batch 02 candidates stay out", function()
		local manifest = H.readFile(H.ROOT .. "/docs/assets/Futuristic_Furniture_Registration_2026-10-26.json")
		local count = 0
		for _ in manifest:gmatch('"preparedPath"') do count = count + 1 end
		T.eq(count, #FUTURISTIC_FURNITURE, "manifest items")
		local expectedType = { future_speaker_01 = "audio", future_layered_coffee_table_01 = "tables" }
		for _, id in ipairs(FUTURISTIC_FURNITURE) do
			local item = Catalog.getItem(id)
			T.ok(item ~= nil, id)
			T.eq(item.type, expectedType[id], id .. " type")
			T.eq(item.structure, nil, id .. " is furniture")
			T.deepEq(item.collections, { "futuristic" }, id .. " collections")
			local at = manifest:find('"id": "' .. id .. '"', 1, true)
			T.ok(at, id .. " in manifest")
			local entry = manifest:sub(at, manifest:find('"visualReview"', at, true))
			T.ok(entry:find('"displayName": "' .. item.displayName .. '"', 1, true), id .. " displayName")
			T.ok(entry:find('"type": "' .. item.type .. '"', 1, true), id .. " type in manifest")
			T.ok(entry:find('"collections": ["futuristic"]', 1, true), id .. " collections in manifest")
			T.ok(entry:find('"sourceRef": "' .. item.sourceRef .. '"', 1, true), id .. " sourceRef")
			T.ok(entry:find('"preparedPath": "ServerStorage.StudioBuilderPreparedAssets.' .. id .. '"', 1, true), id .. " install source")
			T.ok(entry:find('"scripts": 0,', 1, true), id .. " zero scripts")
			T.ok(entry:find('"lights": 0,', 1, true), id .. " zero lights")
			T.ok(entry:find('"anchored": true,', 1, true), id .. " anchored")
			for key in pairs(item) do
				T.ok(key ~= "sourceAssetId" and key ~= "preparedPath" and key ~= "batch02Candidate", id .. " carries " .. key)
			end
		end
		T.ok(manifest:find("NO audio playback", 1, true), "the speaker is decorative")
		T.ok(manifest:find('"creator": "SebbyTheGODKid"', 1, true), "creator recorded")
		T.ok(manifest:find("HELD for a local yaw correction", 1, true), "the leather sofa is held")
		-- No other batch 02 candidate (by name or prepared path) is registered.
		local batch02 = H.readFile(H.ROOT .. "/docs/assets/Catalog_Hunt_Batch02_2026-10-26.json")
		local names = {}
		for name in batch02:gmatch('"name":"([^"]+)","size"') do names[name] = true end
		T.ok(names["Leather Sofa"] and names["Future Couch"], "batch 02 names parsed")
		for _, item in ipairs(Catalog.Items) do
			T.eq(names[item.displayName], nil, "batch 02 candidate registered under its candidate name: " .. item.id)
			T.eq(item.sourceRef:find("CatalogHunt", 1, true), nil, item.id .. " does not point at a batch 02/03 copy")
			if item.sourceRef:find("StudioBuilderPreparedAssets.future_", 1, true) then
				T.ok(expectedType[item.id] ~= nil, "only the two reviewed futuristic pieces use their prepared copies: " .. item.id)
			end
		end
	end)

	T.test("tufted leather sofa: registered exactly from its manifest; decorative (no Seat); install source matches its id", function()
		local manifest = H.readFile(H.ROOT .. "/docs/assets/Tufted_Leather_Sofa_Registration_2026-10-26.json")
		local count = 0
		for _ in manifest:gmatch('"preparedPath"') do count = count + 1 end
		T.eq(count, 1, "manifest items")
		local item = Catalog.getItem(SOFA)
		T.ok(item ~= nil, SOFA)
		T.eq(item.displayName, "Tufted Leather Sofa")
		T.eq(item.type, "seating")
		T.eq(item.structure, nil, "furniture, not structure")
		T.deepEq(item.collections, { "cozy", "retro", "1980s", "winter" })
		-- The prepared copy's name matches the catalog id (install source = sourceRef).
		T.eq(item.sourceRef, "ServerStorage.StudioBuilderPreparedAssets." .. SOFA)
		local at = manifest:find('"id": "' .. SOFA .. '"', 1, true)
		T.ok(at, "id in manifest")
		local entry = manifest:sub(at, manifest:find('"visualReview"', at, true))
		T.ok(entry:find('"displayName": "' .. item.displayName .. '"', 1, true), "displayName")
		T.ok(entry:find('"type": "seating"', 1, true), "type")
		T.ok(entry:find('"collections": ["cozy", "retro", "1980s", "winter"]', 1, true), "collections")
		T.ok(entry:find('"sourceRef": "' .. item.sourceRef .. '"', 1, true), "sourceRef")
		T.ok(entry:find('"preparedPath": "' .. item.sourceRef .. '"', 1, true), "install source")
		for _, fact in ipairs({ '"baseParts": 1,', '"partClass": "MeshPart",', '"scripts": 0,', '"lights": 0,', '"seats": 0,', '"anchored": true,' }) do
			T.ok(entry:find(fact, 1, true), fact)
		end
		T.ok(entry:find("canonical front faces -Z", 1, true), "yaw corrected, front recorded")
		T.ok(entry:find("No sitting or seating-clearance claim", 1, true), "decorative only")
		T.ok(manifest:find('"creator": "leutxiz"', 1, true), "creator recorded")
		T.ok(manifest:find("H02_11", 1, true), "batch 02 candidate recorded")
		T.ok(manifest:find("NOT included in the latest full-place backup", 1, true), "backup status recorded")
		for key in pairs(item) do
			T.ok(key ~= "sourceAssetId" and key ~= "preparedPath" and key ~= "seat" and key ~= "seats", SOFA .. " carries " .. key)
		end
		-- The three batch 02 pieces and the two batch 03 structure pieces are each registered from their own prepared copy.
		local prepared = {}
		for _, it in ipairs(Catalog.Items) do
			local name = it.sourceRef:match("^ServerStorage%.StudioBuilderPreparedAssets%.(.+)$")
			if name and name ~= "retro_crt_tv_01" then
				T.eq(name, it.id, it.id .. " prepared name matches its id")
				prepared[#prepared + 1] = it.id
			end
		end
		T.deepEq(prepared, { "future_speaker_01", "future_layered_coffee_table_01", SOFA, BATCH03_ORDER[1], BATCH03_ORDER[2], INDUSTRIAL_WALL })
	end)

	T.test("batch 03 structure: registered exactly from its manifest, on the grid module, provenance kept out of the catalog", function()
		local StructureGrid = H.load("src/shared/StructureGrid")
		local manifest = H.readFile(H.ROOT .. "/docs/assets/Batch03_Structure_Registration_2026-10-26.json")
		local count = 0
		for _ in manifest:gmatch('"preparedPath"') do count = count + 1 end
		T.eq(count, #BATCH03_ORDER, "manifest items")
		local bounds = { halfX = 24.5, halfZ = 24.5, height = 24 }
		local spot = { ceiling = { 0, 15, 0, 90 }, window_wall = { 8, 0, 0, 90 } }
		for _, id in ipairs(BATCH03_ORDER) do
			local item = Catalog.getItem(id)
			T.ok(item ~= nil, id)
			T.eq(item.structure.kind, BATCH03_STRUCTURE[id], id .. " kind")
			T.eq(item.type, nil, id .. " has no furniture type")
			T.deepEq(item.collections, { "cozy", "retro", "1980s", "winter", "futuristic" }, id .. " all five tags")
			T.eq(item.sourceRef, "ServerStorage.StudioBuilderPreparedAssets." .. id, id .. " prepared name matches its id")
			local at = manifest:find('"id": "' .. id .. '"', 1, true)
			T.ok(at, id .. " in manifest")
			local entry = manifest:sub(at, manifest:find('"visualReview"', at, true))
			T.ok(entry:find('"displayName": "' .. item.displayName .. '"', 1, true), id .. " displayName")
			T.ok(entry:find('"structure": { "kind": "' .. item.structure.kind .. '" }', 1, true), id .. " kind in manifest")
			T.ok(entry:find('"collections": ["cozy", "retro", "1980s", "winter", "futuristic"]', 1, true), id .. " collections in manifest")
			T.ok(entry:find('"sourceRef": "' .. item.sourceRef .. '"', 1, true), id .. " sourceRef")
			T.ok(entry:find('"preparedPath": "' .. item.sourceRef .. '"', 1, true), id .. " install source")
			T.ok(entry:find('"scripts": 0,', 1, true), id .. " zero scripts")
			T.ok(entry:find('"anchored": true,', 1, true), id .. " anchored")
			for key in pairs(item) do
				T.ok(key ~= "sourceAssetId" and key ~= "preparedPath" and key ~= "adaptation" and key ~= "source", id .. " carries " .. key)
			end
			-- The measured size fits the grid module for its kind.
			local sx, sy, sz = entry:match('"size": %[([%d%.]+), ([%d%.]+), ([%d%.]+)%]')
			local size = { tonumber(sx), tonumber(sy), tonumber(sz) }
			local p = spot[item.structure.kind]
			T.ok(StructureGrid.validate(item.structure.kind, { x = p[1], y = p[2], z = p[3], yaw = p[4] }, size, bounds) ~= nil, id .. " validates on the grid")
		end
		local glass = manifest:sub(manifest:find('"id": "structure_glass_partition_01"', 1, true), manifest:find('"id": "structure_ceiling_acoustic_01"', 1, true))
		T.ok(glass:find('"baseParts": 2,', 1, true) and glass:find('"textures": 0,', 1, true), "partition: 2 parts, no textures")
		T.ok(glass:find("no opening and no door behaviour", 1, true), "partition is a fixed wall")
		T.ok(glass:find("Redundant Weld removed", 1, true), "weld removal recorded")
		local ceiling = manifest:sub((manifest:find('"id": "structure_ceiling_acoustic_01"', 1, true)))
		T.ok(ceiling:find('"baseParts": 1,', 1, true) and ceiling:find('"textures": 2,', 1, true), "ceiling: 1 part, 2 textures")
		T.ok(ceiling:find("copied to the Bottom face", 1, true), "underside treatment recorded")
		T.ok(manifest:find('"creator": "v7k_1"', 1, true) and manifest:find('"creator": "VCVCFans"', 1, true), "creators recorded")
		T.ok(manifest:find("NOT included in the latest full-place backup", 1, true), "backup status recorded")
		-- The quarantined wood block stays out of the catalog.
		for _, item in ipairs(Catalog.Items) do
			T.eq(item.displayName:lower():find("wood block", 1, true), nil, item.id)
		end
	end)

	T.test("industrial wall: registered exactly from its manifest as a 16 x 15 x 1 wall on the grid; Structure-mode only; light disabled, not claimed", function()
		local StructureGrid = H.load("src/shared/StructureGrid")
		local manifest = H.readFile(H.ROOT .. "/docs/assets/Industrial_Wall_Registration_2026-10-26.json")
		local count = 0
		for _ in manifest:gmatch('"preparedPath"') do count = count + 1 end
		T.eq(count, 1, "manifest items")
		local item = Catalog.getItem(INDUSTRIAL_WALL)
		T.ok(item ~= nil, INDUSTRIAL_WALL)
		T.eq(item.displayName, "Industrial Concrete Wall")
		T.deepEq(item.structure, { kind = "wall" })
		T.eq(item.type, nil, "no furniture type")
		T.deepEq(item.collections, { "futuristic", "1980s" })
		T.eq(item.sourceRef, "ServerStorage.StudioBuilderPreparedAssets." .. INDUSTRIAL_WALL, "prepared name matches its id")
		local at = manifest:find('"id": "' .. INDUSTRIAL_WALL .. '"', 1, true)
		T.ok(at, "id in manifest")
		local entry = manifest:sub(at, manifest:find('"visualReview"', at, true))
		T.ok(entry:find('"displayName": "' .. item.displayName .. '"', 1, true), "displayName")
		T.ok(entry:find('"structure": { "kind": "wall" }', 1, true), "kind in manifest")
		T.ok(entry:find('"collections": ["futuristic", "1980s"]', 1, true), "collections in manifest")
		T.ok(entry:find('"sourceRef": "' .. item.sourceRef .. '"', 1, true), "sourceRef")
		T.ok(entry:find('"preparedPath": "' .. item.sourceRef .. '"', 1, true), "install source")
		for _, fact in ipairs({ '"baseParts": 26,', '"scripts": 0,', '"lights": 1,', '"anchored": true,', '"rotation": "Identity",', '"size": [16, 15, 1],' }) do
			T.ok(entry:find(fact, 1, true), fact)
		end
		T.ok(entry:find("DISABLED", 1, true) and entry:find("No lighting adapter behaviour is claimed", 1, true), "the light is disabled and not claimed")
		T.ok(manifest:find('"creator": "WilliamBosso"', 1, true) and manifest:find("H02_03", 1, true), "source recorded")
		T.ok(manifest:find("NOT included in the latest full-place backup", 1, true), "backup status recorded")
		for key in pairs(item) do
			T.ok(key ~= "sourceAssetId" and key ~= "preparedPath" and key ~= "adaptation" and key ~= "lights", INDUSTRIAL_WALL .. " carries " .. key)
		end
		-- The 16 x 15 x 1 module validates on every wall edge inside the live 48 marker, in both orientations, and snaps from off-grid.
		local size = { 16, 15, 1 }
		local live = { halfX = 24, halfZ = 24, height = 24 }
		T.deepEq(StructureGrid.validate("wall", { x = 0, y = 0, z = 8, yaw = 0 }, size, live), { x = 0, y = 0, z = 8, yaw = 0 })
		T.deepEq(StructureGrid.validate("wall", { x = 8, y = 0, z = 16, yaw = 90 }, size, live), { x = 8, y = 0, z = 16, yaw = 90 })
		T.eq((StructureGrid.validate("wall", { x = 3, y = 0, z = 8, yaw = 0 }, size, live)), nil, "off-grid refused")
		T.eq((StructureGrid.validate("wall", { x = 0, y = 15, z = 8, yaw = 0 }, size, live)), nil, "wall level is 0")
		local projected = StructureGrid.project("wall", { x = 1.2, y = 0, z = 6.7 }, 0)
		T.ok(projected ~= nil and StructureGrid.validate("wall", projected, size, live) ~= nil, "a projected hit validates")
		-- Furniture style lists never include it; Structure > Walls does.
		for _, c in ipairs(Catalog.Collections) do
			for _, f in ipairs(Catalog.getFurnitureTagged(c.id)) do
				T.ok(f.id ~= INDUSTRIAL_WALL, c.id .. " furniture excludes the wall")
			end
		end
		local walls = {}
		for _, w in ipairs(Catalog.getStructureItems("wall")) do walls[#walls + 1] = w.id end
		T.eq(walls[#walls], INDUSTRIAL_WALL, "listed last under Walls")
	end)

	T.test("sorted collections follow declared order", function()
		local sorted = Catalog.getCollectionsSorted()
		for i = 2, #sorted do
			T.ok(sorted[i - 1].order < sorted[i].order, "order")
		end
	end)

	T.test("lookups reject non-string and unknown IDs", function()
		T.eq(Catalog.getItem(nil), nil)
		T.eq(Catalog.getItem(42), nil)
		T.eq(Catalog.getItem({}), nil)
		T.eq(Catalog.getItem(io.stdout), nil, "userdata (Instance stand-in)")
		T.eq(Catalog.getItem("ServerStorage.PodcastAssetStaging.Green Armchair"), nil, "path")
		T.eq(Catalog.getItem("rbxassetid://964030990"), nil, "asset id")
		T.eq(Catalog.getCollection(io.stdout), nil)
	end)

	T.test("every sourceRef exists in the committed asset guide or expansion manifest (no invented sources)", function()
		local guide = H.readFile(H.ROOT .. "/docs/assets/Studio_Asset_Guide_2026-10-25.json")
		local manifest = H.readFile(H.ROOT .. "/docs/assets/Catalog_Expansion_2026-10-25.json") .. H.readFile(H.ROOT .. "/docs/assets/Structure_and_Decor_Candidates_2026-10-25.json") .. H.readFile(H.ROOT .. "/docs/assets/Decor_Candidate_retro_patterned_rug_01_2026-10-26.json") .. H.readFile(H.ROOT .. "/docs/assets/Decor_Candidate_retro_classic_floor_lamp_01_2026-10-26.json") .. H.readFile(H.ROOT .. "/docs/assets/Structure_Expansion_2026-10-26.json") .. H.readFile(H.ROOT .. "/docs/assets/Futuristic_Furniture_Registration_2026-10-26.json") .. H.readFile(H.ROOT .. "/docs/assets/Tufted_Leather_Sofa_Registration_2026-10-26.json") .. H.readFile(H.ROOT .. "/docs/assets/Batch03_Structure_Registration_2026-10-26.json") .. H.readFile(H.ROOT .. "/docs/assets/Industrial_Wall_Registration_2026-10-26.json")
		for _, item in ipairs(Catalog.Items) do
			local inGuide = string.find(guide, '"path": "' .. item.sourceRef .. '"', 1, true) or string.find(guide, '"path":"' .. item.sourceRef .. '"', 1, true)
			local inManifest = string.find(manifest, '"sourceRef": "' .. item.sourceRef .. '"', 1, true)
			T.ok(inGuide or inManifest, item.id .. " sourceRef not in asset guide or manifest: " .. item.sourceRef)
		end
	end)

	T.test("no catalog field carries an asset ID (sourceRef is a documentation-only ServerStorage path)", function()
		for _, item in ipairs(Catalog.Items) do
			for key, value in pairs(item) do
				if type(value) == "string" and key ~= "sourceRef" then
					T.ok(not string.find(value, "%d%d%d%d%d"), item.id .. "." .. key .. " looks like an asset ID")
				end
			end
			-- sourceRef names a Studio staging path (it may contain the import's
			-- folder name, e.g. Review_<n>); it is never loaded, must stay a
			-- ServerStorage path and is cross-checked against a committed
			-- manifest by the provenance test below.
			T.ok(item.sourceRef:find("^ServerStorage%.") ~= nil, item.id .. " sourceRef is a ServerStorage path")
			T.eq(item.sourceRef:find("rbxassetid", 1, true), nil, item.id)
			T.eq(item.sourceRef:find("://", 1, true), nil, item.id .. " sourceRef is not a URL")
		end
	end)

	T.test("validator rejects duplicate, malformed and mistagged entries", function()
		local collections, items = copyData()
		items[#items + 1] = { id = "cozy_plant_01", displayName = "Dup", collections = { "cozy" } }
		items[#items + 1] = { id = "Cozy Armchair", displayName = "Bad id", collections = { "cozy" } }
		items[#items + 1] = { id = "rbxassetid://123", displayName = "Asset", collections = { "cozy" } }
		items[#items + 1] = { id = "x_untagged", displayName = "Untagged", collections = {} }
		items[#items + 1] = { id = "x_unknown_tag", displayName = "Unknown", collections = { "vaporwave" } }
		items[#items + 1] = { id = "x_repeat_tag", displayName = "Repeat", collections = { "cozy", "cozy" } }
		items[#items + 1] = { id = "x_no_name", collections = { "cozy" } }
		collections[#collections + 1] = { id = "cozy", displayName = "Again" }
		collections[#collections + 1] = { id = "paid", displayName = "Paid", entitlement = "gamepass" }
		local ok, errors = Catalog.validateData(collections, items)
		T.eq(ok, false)
		T.ok(hasError(errors, "duplicate item id cozy_plant_01"), "dup item")
		T.ok(hasError(errors, "has an invalid id"), "bad id")
		T.ok(hasError(errors, "needs at least one collection tag"), "untagged")
		T.ok(hasError(errors, "unknown collection tag vaporwave"), "unknown tag")
		T.ok(hasError(errors, "repeats collection tag cozy"), "repeat tag")
		T.ok(hasError(errors, "x_no_name needs a displayName"), "no name")
		T.ok(hasError(errors, "duplicate collection id cozy"), "dup collection")
		T.ok(hasError(errors, "paid has malformed entitlement"), "entitlement")
	end)

	T.test("validator rejects non-sequence inputs without crashing", function()
		local ok, errors = Catalog.validateData("nope", { foo = 1 })
		T.eq(ok, false)
		T.ok(#errors >= 2)
	end)
end
