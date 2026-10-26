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
	local ACOUSTIC_WALL = "structure_acoustic_wall_01"
	local CABINET = "future_drawer_cabinet_01"
	local DISPENSER = "studio_water_dispenser_01"
	local PLANT = "studio_tall_floor_plant_01"
	local CONFERENCE_TABLE = "studio_conference_table_01"
	local FLOWER_POT = "studio_flower_pot_01"
	local OFFICE_CHAIR = "studio_office_chair_01"
	local MUG = "studio_coffee_mug_01"
	local BOARD = "studio_presentation_board_01"
	local SOFTBOX = "studio_softbox_01"

	T.test("catalog holds 7 original, 24 expansion, 5 structure, 4 later furniture, 9 structure variant, 2 futuristic furniture, 1 sofa, 2 batch 03 structure, 1 industrial wall, 1 acoustic wall, 1 drawer cabinet, 1 water dispenser, 1 tall floor plant, 1 conference table, 1 flower pot, 1 office chair, 1 coffee mug, 1 presentation board and 1 softbox ID, earlier entries unchanged in order", function()
		T.eq(#Catalog.Items, 65, "item count")
		T.eq(Catalog.Items[65].id, SOFTBOX, "the softbox is appended last")
		T.eq(Catalog.Items[63].id, MUG, "the coffee mug follows the office chair")
		T.eq(Catalog.Items[64].id, BOARD, "the presentation board follows the coffee mug")
		T.eq(Catalog.Items[61].id, FLOWER_POT, "the flower pot follows the conference table")
		T.eq(Catalog.Items[62].id, OFFICE_CHAIR, "the office chair follows the flower pot")
		T.eq(Catalog.Items[59].id, PLANT, "the tall floor plant follows the water dispenser")
		T.eq(Catalog.Items[60].id, CONFERENCE_TABLE, "the conference table follows the tall floor plant")
		T.eq(Catalog.Items[57].id, CABINET, "the drawer cabinet follows the acoustic wall")
		T.eq(Catalog.Items[58].id, DISPENSER, "the water dispenser follows the drawer cabinet")
		T.eq(Catalog.Items[55].id, INDUSTRIAL_WALL, "the industrial wall follows the batch 03 structure")
		T.eq(Catalog.Items[56].id, ACOUSTIC_WALL, "the acoustic wall follows the industrial wall")
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
		-- The acoustic wall: retro, 1980s and futuristic.
		local structureTags = { cozy = 16, retro = 17, ["1980s"] = 18, winter = 16, futuristic = 18 }
		-- Drawer cabinet: futuristic only.
		-- Water dispenser: cozy and 1980s.
		-- Tall floor plant: cozy, retro and 1980s.
		-- Conference table: cozy, 1980s and futuristic.
		-- Red flower pot: cozy, retro, 1980s and winter.
		-- Black office chair: cozy, 1980s and futuristic.
		-- Steaming coffee mug: all five collections.
		-- Presentation board: cozy, 1980s and futuristic.
		-- Studio softbox: cozy, 1980s and futuristic.
		local expected = { cozy = 35, retro = 24, ["1980s"] = 25, winter = 15, futuristic = 17 }
		for _, c in ipairs(Catalog.Collections) do
			T.eq(#Catalog.getFurnitureTagged(c.id), expected[c.id], c.id .. " furniture count")
			T.eq(#Catalog.getItemsTagged(c.id), expected[c.id] + structureTags[c.id], c.id .. " raw tag count (structure pieces included)")
			for _, item in ipairs(Catalog.getFurnitureTagged(c.id)) do
				T.eq(item.structure, nil, item.id)
			end
		end
		local perKind = { floor = 5, wall = 5, doorway = 2, ceiling = 3, window_wall = 3 }
		local structureTotal = 0
		for _, f in ipairs(Catalog.StructureFilters) do
			local items = Catalog.getStructureItems(f.id)
			T.eq(#items, perKind[f.id], f.id)
			for _, item in ipairs(items) do
				T.eq(STRUCTURE[item.id] or STRUCTURE_VARIANTS[item.id] or BATCH03_STRUCTURE[item.id] or ((item.id == INDUSTRIAL_WALL or item.id == ACOUSTIC_WALL) and "wall"), f.id, item.id)
			end
			structureTotal = structureTotal + #items
		end
		T.eq(structureTotal, 18)
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
		T.eq(#Catalog.Items, base + #APPROVED_TRACKED + #VARIANT_ORDER + #FUTURISTIC_FURNITURE + 1 + #BATCH03_ORDER + 11, "only the structure variants, futuristic furniture, the sofa, the batch 03 structure, the two prepared walls, the drawer cabinet and the eight room extractions follow the approved tracked items")
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
				-- The drawer cabinet (a later registration, its own manifest) shares the prefix.
				T.ok(expectedType[item.id] ~= nil or item.id == CABINET, "only reviewed futuristic pieces use their prepared copies: " .. item.id)
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
		T.deepEq(prepared, { "future_speaker_01", "future_layered_coffee_table_01", SOFA, BATCH03_ORDER[1], BATCH03_ORDER[2], INDUSTRIAL_WALL, ACOUSTIC_WALL, CABINET, DISPENSER, PLANT, CONFERENCE_TABLE, FLOWER_POT, OFFICE_CHAIR, MUG, BOARD, SOFTBOX })
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
		T.eq(walls[#walls - 1], INDUSTRIAL_WALL, "listed after the earlier walls")
	end)

	T.test("acoustic wall: registered exactly from its manifest as a 16 x 15 x 1 wall on the grid; adapted tiles plus added backing recorded; no acoustic behaviour claimed", function()
		local StructureGrid = H.load("src/shared/StructureGrid")
		local manifest = H.readFile(H.ROOT .. "/docs/assets/Acoustic_Wall_Registration_2026-10-26.json")
		local count = 0
		for _ in manifest:gmatch('"preparedPath"') do count = count + 1 end
		T.eq(count, 1, "manifest items")
		local item = Catalog.getItem(ACOUSTIC_WALL)
		T.ok(item ~= nil, ACOUSTIC_WALL)
		T.eq(item.displayName, "Acoustic Foam Wall")
		T.deepEq(item.structure, { kind = "wall" })
		T.eq(item.type, nil, "no furniture type")
		T.deepEq(item.collections, { "retro", "1980s", "futuristic" })
		T.eq(item.sourceRef, "ServerStorage.StudioBuilderPreparedAssets." .. ACOUSTIC_WALL, "prepared name matches its id")
		local at = manifest:find('"id": "' .. ACOUSTIC_WALL .. '"', 1, true)
		T.ok(at, "id in manifest")
		local entry = manifest:sub(at, manifest:find('"visualReview"', at, true))
		T.ok(entry:find('"displayName": "' .. item.displayName .. '"', 1, true), "displayName")
		T.ok(entry:find('"structure": { "kind": "wall" }', 1, true), "kind in manifest")
		T.ok(entry:find('"collections": ["retro", "1980s", "futuristic"]', 1, true), "collections in manifest")
		T.ok(entry:find('"sourceRef": "' .. item.sourceRef .. '"', 1, true), "sourceRef")
		T.ok(entry:find('"preparedPath": "' .. item.sourceRef .. '"', 1, true), "install source")
		for _, fact in ipairs({ '"baseParts": 57,', '"scripts": 0,', '"lights": 0,', '"anchored": true,', '"rotation": "Identity",', '"size": [16, 15, 1],', '"count": 56,', '"size": [16, 15, 0.8],' }) do
			T.ok(entry:find(fact, 1, true), fact)
		end
		-- 56 tiles + 1 backing = 57 parts; the 8 x 7 layout fills the tile count.
		local cols, rows = entry:match('"layout": "(%d+) columns x (%d+) rows')
		T.eq(tonumber(cols) * tonumber(rows), 56, "8 x 7 tiles")
		T.ok(entry:find("was ADDED; it is not from the source model", 1, true), "the added backing is disclosed")
		T.ok(entry:find("no sound-absorption behaviour is claimed", 1, true), "appearance only")
		T.ok(entry:find("The backing supplies the wall's collision", 1, true), "collision comes from the backing")
		T.ok(manifest:find('"creator": "DesolatedWorld"', 1, true) and manifest:find("H02_10", 1, true), "source recorded")
		T.ok(manifest:find("NOT included in the latest full-place backup", 1, true), "backup status recorded")
		for key in pairs(item) do
			T.ok(key ~= "sourceAssetId" and key ~= "preparedPath" and key ~= "adaptation" and key ~= "tiles" and key ~= "backing", ACOUSTIC_WALL .. " carries " .. key)
		end
		-- The 16 x 15 x 1 module validates on wall edges inside the live 48 marker, in both orientations, and refuses off-grid or raised spots.
		local size = { 16, 15, 1 }
		local live = { halfX = 24, halfZ = 24, height = 24 }
		T.deepEq(StructureGrid.validate("wall", { x = 0, y = 0, z = -8, yaw = 180 }, size, live), { x = 0, y = 0, z = -8, yaw = 180 })
		T.deepEq(StructureGrid.validate("wall", { x = -8, y = 0, z = 0, yaw = 270 }, size, live), { x = -8, y = 0, z = 0, yaw = 270 })
		T.eq((StructureGrid.validate("wall", { x = 0, y = 0, z = 0, yaw = 0 }, size, live)), nil, "a cell centre is not a wall edge")
		T.eq((StructureGrid.validate("wall", { x = 0, y = 1, z = 8, yaw = 0 }, size, live)), nil, "wall level is 0")
		-- Structure > Walls lists it last; furniture style lists never include it, even for its own tags.
		local walls = {}
		for _, w in ipairs(Catalog.getStructureItems("wall")) do walls[#walls + 1] = w.id end
		T.deepEq(walls, { "structure_wall_01", "structure_wall_wood_01", "structure_wall_brick_01", INDUSTRIAL_WALL, ACOUSTIC_WALL })
		for _, tag in ipairs(item.collections) do
			for _, f in ipairs(Catalog.getFurnitureTagged(tag)) do
				T.ok(f.id ~= ACOUSTIC_WALL, tag .. " furniture excludes the acoustic wall")
			end
		end
	end)

	T.test("drawer cabinet: registered exactly from its manifest as futuristic storage furniture; floor placement fits its measured bounds; decorative only", function()
		local Transform = H.load("src/shared/Transform")
		local Config = H.load("src/shared/Config")
		local manifest = H.readFile(H.ROOT .. "/docs/assets/Drawer_Cabinet_Registration_2026-10-26.json")
		local count = 0
		for _ in manifest:gmatch('"preparedPath"') do count = count + 1 end
		T.eq(count, 1, "manifest items")
		local item = Catalog.getItem(CABINET)
		T.ok(item ~= nil, CABINET)
		T.eq(item.displayName, "Three-Drawer Cabinet")
		T.eq(item.type, "storage")
		T.eq(item.structure, nil, "furniture, not structure")
		T.deepEq(item.collections, { "futuristic" })
		T.eq(item.sourceRef, "ServerStorage.StudioBuilderPreparedAssets." .. CABINET, "prepared name matches its id")
		local at = manifest:find('"id": "' .. CABINET .. '"', 1, true)
		T.ok(at, "id in manifest")
		local entry = manifest:sub(at, manifest:find('"visualReview"', at, true))
		T.ok(entry:find('"displayName": "' .. item.displayName .. '"', 1, true), "displayName")
		T.ok(entry:find('"type": "storage"', 1, true), "type in manifest")
		T.ok(entry:find('"collections": ["futuristic"]', 1, true), "collections in manifest")
		T.ok(entry:find('"sourceRef": "' .. item.sourceRef .. '"', 1, true), "sourceRef")
		T.ok(entry:find('"preparedPath": "' .. item.sourceRef .. '"', 1, true), "install source")
		for _, fact in ipairs({ '"placement": "floor",', '"baseParts": 6,', '"scripts": 0,', '"lights": 0,', '"seats": 0,', '"anchored": true,', '"front": "-Z",' }) do
			T.ok(entry:find(fact, 1, true), fact)
		end
		T.ok(entry:find("no geometry added", 1, true), "no added geometry")
		T.ok(entry:find("the drawers do not open and there is no storage behaviour", 1, true), "decorative only")
		T.ok(manifest:find('"creator": "SebbyTheGODKid"', 1, true) and manifest:find("H02_18", 1, true), "source recorded")
		T.ok(manifest:find("NOT included in the latest full-place backup", 1, true), "backup status recorded")
		for key in pairs(item) do
			T.ok(key ~= "sourceAssetId" and key ~= "preparedPath" and key ~= "placement" and key ~= "adaptation", CABINET .. " carries " .. key)
		end
		-- Floor placement with the measured bounds (half X 3.2155, half Z 1.6399) inside the live 48 marker.
		local sx, sy, sz = entry:match('"size": %[([%d%.]+), ([%d%.]+), ([%d%.]+)%]')
		local size = { tonumber(sx), tonumber(sy), tonumber(sz) }
		T.eq(size[1], 6.430999755859375)
		local live = { halfX = 24, halfZ = 24, height = 24 }
		local function place(x, y, z, yaw) return Transform.sanitize({ x = x, y = y, z = z, yaw = yaw }, size, live, Config) end
		T.deepEq(place(0, 0, 0, 0), { x = 0, y = 0, z = 0, yaw = 0 }, "on the floor at the centre")
		T.ok(place(20.7, 0, 0, 0) ~= nil, "front-facing against the X edge")
		T.eq(select(2, place(21, 0, 0, 0)), "OutOfBounds", "its 6.43 width overhangs the X edge")
		T.ok(place(21, 0, 0, 90) ~= nil, "turned 90 degrees, its 3.28 depth fits at x = 21")
		T.eq(select(2, place(0, 0, 21, 90)), "OutOfBounds", "turned 90 degrees, its width overhangs the Z edge")
		T.eq(select(2, place(0, -0.5, 0, 0)), "OutOfBounds", "not below the floor")
		-- Furniture filters: it appears under Futuristic > Storage, never in Structure mode or other styles.
		local storage = {}
		for _, f in ipairs(Catalog.getFurnitureByType("futuristic", "storage")) do storage[#storage + 1] = f.id end
		T.deepEq(storage, { "future_shelf_01", CABINET }, "futuristic storage")
		for _, f in ipairs(Catalog.StructureFilters) do
			for _, s in ipairs(Catalog.getStructureItems(f.id)) do T.ok(s.id ~= CABINET, f.id .. " excludes the cabinet") end
		end
		for _, f in ipairs(Catalog.getFurnitureByType("cozy", "storage")) do T.ok(f.id ~= CABINET, "cozy storage excludes it") end
	end)

	T.test("water dispenser: registered exactly from its manifest as cozy/1980s decor; room provenance without an invented creator or asset ID; floor placement fits its bounds", function()
		local Transform = H.load("src/shared/Transform")
		local Config = H.load("src/shared/Config")
		local manifest = H.readFile(H.ROOT .. "/docs/assets/Water_Dispenser_Registration_2026-10-26.json")
		local count = 0
		for _ in manifest:gmatch('"preparedPath"') do count = count + 1 end
		T.eq(count, 1, "manifest items")
		local item = Catalog.getItem(DISPENSER)
		T.ok(item ~= nil, DISPENSER)
		T.eq(item.displayName, "Water Dispenser")
		T.eq(item.type, "decor")
		T.eq(item.structure, nil, "furniture, not structure")
		T.deepEq(item.collections, { "cozy", "1980s" })
		T.eq(item.credit, nil, "no credit: the creator is not verified")
		T.eq(item.sourceRef, "ServerStorage.StudioBuilderPreparedAssets." .. DISPENSER, "prepared name matches its id")
		local at = manifest:find('"id": "' .. DISPENSER .. '"', 1, true)
		T.ok(at, "id in manifest")
		local entry = manifest:sub(at, manifest:find('"visualReview"', at, true))
		T.ok(entry:find('"displayName": "' .. item.displayName .. '"', 1, true), "displayName")
		T.ok(entry:find('"type": "decor"', 1, true), "type in manifest")
		T.ok(entry:find('"collections": ["cozy", "1980s"]', 1, true), "collections in manifest")
		T.ok(entry:find('"sourceRef": "' .. item.sourceRef .. '"', 1, true), "sourceRef")
		T.ok(entry:find('"preparedPath": "' .. item.sourceRef .. '"', 1, true), "install source")
		for _, fact in ipairs({ '"placement": "floor",', '"baseParts": 20,', '"specialMeshes": 14,', '"scripts": 0,', '"lights": 0,', '"seats": 0,', '"joints": 0,', '"anchored": true,', '"canTouch": false,' }) do
			T.ok(entry:find(fact, 1, true), fact)
		end
		T.ok(entry:find("Removed 16 redundant ManualWelds", 1, true) and entry:find("no geometry added", 1, true), "preparation recorded")
		T.ok(entry:find("no dispensing and no tap animation", 1, true), "decorative only")
		-- Provenance: the parent room model only, matching the committed asset guide; no invented creator or dispenser asset ID.
		T.ok(manifest:find('"extractedFrom": "Workspace.RoomCollection.ConferenceRoom.Water Machine"', 1, true), "extraction path")
		T.ok(manifest:find('"creator": "Not independently verified; not recorded"', 1, true), "creator not invented")
		T.ok(manifest:find("the dispenser has no individual asset ID", 1, true), "no individual asset ID implied")
		T.ok(manifest:find("not a batch 02 or batch 03 candidate", 1, true), "room extraction, not batch 02")
		local guide = H.readFile(H.ROOT .. "/docs/assets/Studio_Asset_Guide_2026-10-25.json")
		local room = guide:find('"name": "ConferenceRoom"', 1, true)
		T.ok(room, "the guide has the ConferenceRoom record")
		T.ok(guide:sub(room, room + 800):find("Source4993294691", 1, true), "the guide records the parent model source")
		T.ok(manifest:find('"parentFreeModelAssetId": "4993294691"', 1, true), "the manifest matches the guide")
		for key in pairs(item) do
			T.ok(key ~= "sourceAssetId" and key ~= "preparedPath" and key ~= "placement" and key ~= "adaptation" and key ~= "credit", DISPENSER .. " carries " .. key)
		end
		-- Floor placement with the measured bounds (half X 0.975, half Z 1.125) inside the live 48 marker.
		local sx, sy, sz = entry:match('"size": %[([%d%.]+), ([%d%.]+), ([%d%.]+)%]')
		local size = { tonumber(sx), tonumber(sy), tonumber(sz) }
		T.eq(size[3], 2.25)
		local live = { halfX = 24, halfZ = 24, height = 24 }
		local function place(x, y, z, yaw) return Transform.sanitize({ x = x, y = y, z = z, yaw = yaw }, size, live, Config) end
		T.deepEq(place(0, 0, 0, 0), { x = 0, y = 0, z = 0, yaw = 0 }, "on the floor at the centre")
		T.ok(place(23, 0, 22.8, 0) ~= nil, "fits in a corner facing forward")
		T.eq(select(2, place(23, 0, 23, 0)), "OutOfBounds", "its 2.25 depth overhangs the Z edge at z = 23")
		T.ok(place(22.8, 0, 23, 90) ~= nil, "turned 90 degrees, its 1.95 width fits at z = 23")
		T.eq(select(2, place(0, 19, 0, 0)), "OutOfBounds", "its 5.1 height must stay under the 24 ceiling")
		-- Filters: Cozy > Decor and 1980s > Decor, not other styles or Structure mode.
		local function ids(list) local out = {} for _, f in ipairs(list) do out[#out + 1] = f.id end return out end
		local cozyDecor, eightiesDecor = ids(Catalog.getFurnitureByType("cozy", "decor")), ids(Catalog.getFurnitureByType("1980s", "decor"))
		-- The coffee mug (a later registration) follows it.
		T.eq(cozyDecor[#cozyDecor - 1], DISPENSER, "last before later registrations in Cozy > Decor")
		T.eq(eightiesDecor[#eightiesDecor - 1], DISPENSER, "last before later registrations in 1980s > Decor")
		T.eq(cozyDecor[#cozyDecor], MUG)
		for _, tag in ipairs({ "retro", "winter", "futuristic" }) do
			for _, f in ipairs(Catalog.getFurnitureTagged(tag)) do T.ok(f.id ~= DISPENSER, tag .. " excludes the dispenser") end
		end
		for _, f in ipairs(Catalog.StructureFilters) do
			for _, s in ipairs(Catalog.getStructureItems(f.id)) do T.ok(s.id ~= DISPENSER, f.id .. " excludes the dispenser") end
		end
	end)

	T.test("tall floor plant: registered exactly from its manifest as cozy/retro/1980s plants; matches its gap-audit entry; no invented creator or plant asset ID; floor placement fits its bounds", function()
		local Transform = H.load("src/shared/Transform")
		local Config = H.load("src/shared/Config")
		local manifest = H.readFile(H.ROOT .. "/docs/assets/Tall_Floor_Plant_Registration_2026-10-26.json")
		local count = 0
		for _ in manifest:gmatch('"preparedPath"') do count = count + 1 end
		T.eq(count, 1, "manifest items")
		local item = Catalog.getItem(PLANT)
		T.ok(item ~= nil, PLANT)
		T.eq(item.displayName, "Tall Floor Plant")
		T.eq(item.type, "plants")
		T.eq(item.structure, nil, "furniture, not structure")
		T.deepEq(item.collections, { "cozy", "retro", "1980s" })
		T.eq(item.credit, nil, "no credit: the creator is not verified")
		T.eq(item.sourceRef, "ServerStorage.StudioBuilderPreparedAssets." .. PLANT, "prepared name matches its id")
		local at = manifest:find('"id": "' .. PLANT .. '"', 1, true)
		T.ok(at, "id in manifest")
		local entry = manifest:sub(at, manifest:find('"visualReview"', at, true))
		T.ok(entry:find('"displayName": "' .. item.displayName .. '"', 1, true), "displayName")
		T.ok(entry:find('"type": "plants"', 1, true), "type in manifest")
		T.ok(entry:find('"collections": ["cozy", "retro", "1980s"]', 1, true), "collections in manifest")
		T.ok(entry:find('"sourceRef": "' .. item.sourceRef .. '"', 1, true), "sourceRef")
		T.ok(entry:find('"preparedPath": "' .. item.sourceRef .. '"', 1, true), "install source")
		for _, fact in ipairs({ '"placement": "floor",', '"baseParts": 1,', '"partClass": "MeshPart",', '"scripts": 0,', '"lights": 0,', '"seats": 0,', '"joints": 0,', '"anchored": true,', '"canTouch": false,' }) do
			T.ok(entry:find(fact, 1, true), fact)
		end
		T.ok(entry:find("no geometry added", 1, true), "no added geometry")
		T.ok(entry:find("no sway or animation", 1, true), "decorative only")
		-- Provenance: the parent room model only; no invented creator or plant model ID; the mesh content stays in the manifest.
		T.ok(manifest:find('"creator": "Not independently verified; not recorded"', 1, true), "creator not invented")
		T.ok(manifest:find("not an individual plant model", 1, true), "no individual plant model ID claimed")
		T.ok(manifest:find('"parentFreeModelAssetId": "4993294691"', 1, true), "parent model recorded")
		local guide = H.readFile(H.ROOT .. "/docs/assets/Studio_Asset_Guide_2026-10-25.json")
		local room = guide:find('"name": "ConferenceRoom"', 1, true)
		T.ok(room and guide:sub(room, room + 800):find("Source4993294691", 1, true), "the asset guide records the parent model")
		T.ok(manifest:find('"meshId": "rbxassetid://430369152"', 1, true) and manifest:find('"textureId": "rbxassetid://430369173"', 1, true), "mesh content recorded")
		for key, value in pairs(item) do
			T.ok(key ~= "sourceAssetId" and key ~= "preparedPath" and key ~= "placement" and key ~= "meshContent" and key ~= "credit", PLANT .. " carries " .. key)
			T.ok(type(value) ~= "string" or not value:find("430369", 1, true), PLANT .. "." .. key .. " carries no mesh ID")
		end
		-- The committed gap audit lists the same source path, type and size.
		local audit = H.readFile(H.ROOT .. "/docs/assets/Existing_Room_Catalog_Gap_Audit_2026-10-26.json")
		local auditAt = audit:find('"displayName":"Tall potted plant"', 1, true) or audit:find('"displayName": "Tall potted plant"', 1, true)
		T.ok(auditAt, "gap audit entry exists")
		local auditEntry = audit:sub(auditAt, (audit:find("}", auditAt, true)))
		T.ok(auditEntry:find("Workspace.RoomCollection.ConferenceRoom.Potted Plant", 1, true), "same source path as the gap audit")
		T.ok(auditEntry:find('"plants"', 1, true), "the gap audit proposed type plants")
		local sx, sy, sz = entry:match('"size": %[([%d%.]+), ([%d%.]+), ([%d%.]+)%]')
		local size = { tonumber(sx), tonumber(sy), tonumber(sz) }
		local ax, ay, az = auditEntry:match('"size":%s*%[%s*([%d%.]+),%s*([%d%.]+),%s*([%d%.]+)%s*%]')
		T.ok(math.abs(size[1] - tonumber(ax)) < 1e-6 and math.abs(size[2] - tonumber(ay)) < 1e-6 and math.abs(size[3] - tonumber(az)) < 1e-6, "same bounds as the gap audit")
		-- Floor placement with the measured bounds (half X 2.607, half Z 1.856) inside the live 48 marker.
		local live = { halfX = 24, halfZ = 24, height = 24 }
		local function place(x, y, z, yaw) return Transform.sanitize({ x = x, y = y, z = z, yaw = yaw }, size, live, Config) end
		T.deepEq(place(0, 0, 0, 0), { x = 0, y = 0, z = 0, yaw = 0 }, "on the floor at the centre")
		T.ok(place(21.3, 0, 22.1, 0) ~= nil, "fits in a corner facing forward")
		T.eq(select(2, place(21.5, 0, 0, 0)), "OutOfBounds", "its 5.21 width overhangs the X edge at x = 21.5")
		T.ok(place(21.5, 0, 0, 90) ~= nil, "turned 90 degrees, its 3.71 depth fits at x = 21.5")
		T.eq(select(2, place(0, 17, 0, 0)), "OutOfBounds", "its 7.14 height must stay under the 24 ceiling")
		-- Filters: Cozy/Retro/1980s > Plants; never Winter, Futuristic or Structure mode.
		for _, tag in ipairs(item.collections) do
			local plants = Catalog.getFurnitureByType(tag, "plants")
			-- Later plants (the red flower pot) follow it in registration order.
			local position
			for i, f in ipairs(plants) do if f.id == PLANT then position = i end end
			T.ok(position ~= nil, "listed in " .. tag .. " > Plants")
			T.ok(position == #plants or plants[position + 1].id == FLOWER_POT, PLANT .. " precedes only later registrations in " .. tag)
		end
		for _, tag in ipairs({ "winter", "futuristic" }) do
			for _, f in ipairs(Catalog.getFurnitureTagged(tag)) do T.ok(f.id ~= PLANT, tag .. " excludes the plant") end
		end
		for _, f in ipairs(Catalog.StructureFilters) do
			for _, s in ipairs(Catalog.getStructureItems(f.id)) do T.ok(s.id ~= PLANT, f.id .. " excludes the plant") end
		end
	end)

	T.test("conference table: registered exactly from its manifest as cozy/1980s/futuristic tables; matches its gap-audit entry; large footprint validated at the edges and when rotated", function()
		local Transform = H.load("src/shared/Transform")
		local Config = H.load("src/shared/Config")
		local manifest = H.readFile(H.ROOT .. "/docs/assets/Conference_Table_Registration_2026-10-26.json")
		local count = 0
		for _ in manifest:gmatch('"preparedPath"') do count = count + 1 end
		T.eq(count, 1, "manifest items")
		local item = Catalog.getItem(CONFERENCE_TABLE)
		T.ok(item ~= nil, CONFERENCE_TABLE)
		T.eq(item.displayName, "White Conference Table")
		T.eq(item.type, "tables")
		T.eq(item.structure, nil, "furniture, not structure")
		T.deepEq(item.collections, { "cozy", "1980s", "futuristic" })
		T.eq(item.credit, nil, "no credit: the creator is not verified")
		T.eq(item.sourceRef, "ServerStorage.StudioBuilderPreparedAssets." .. CONFERENCE_TABLE, "prepared name matches its id")
		local at = manifest:find('"id": "' .. CONFERENCE_TABLE .. '"', 1, true)
		T.ok(at, "id in manifest")
		local entry = manifest:sub(at, manifest:find('"visualReview"', at, true))
		T.ok(entry:find('"displayName": "' .. item.displayName .. '"', 1, true), "displayName")
		T.ok(entry:find('"type": "tables"', 1, true), "type in manifest")
		T.ok(entry:find('"collections": ["cozy", "1980s", "futuristic"]', 1, true), "collections in manifest")
		T.ok(entry:find('"sourceRef": "' .. item.sourceRef .. '"', 1, true), "sourceRef")
		T.ok(entry:find('"preparedPath": "' .. item.sourceRef .. '"', 1, true), "install source")
		for _, fact in ipairs({ '"placement": "floor",', '"baseParts": 3,', '"scripts": 0,', '"lights": 0,', '"seats": 0,', '"joints": 0,', '"anchored": true,', '"canTouch": false,' }) do
			T.ok(entry:find(fact, 1, true), fact)
		end
		T.ok(entry:find("no geometry added", 1, true), "no added geometry")
		T.ok(entry:find("no automatic chairs, no seat adapters and no new interactions", 1, true), "decorative only")
		T.ok(manifest:find('"creator": "Not independently verified; not recorded (no credit)"', 1, true), "creator not invented")
		T.ok(manifest:find("not an individual table model", 1, true), "no individual table model ID claimed")
		local guide = H.readFile(H.ROOT .. "/docs/assets/Studio_Asset_Guide_2026-10-25.json")
		local room = guide:find('"name": "ConferenceRoom"', 1, true)
		T.ok(room and guide:sub(room, room + 800):find("Source4993294691", 1, true), "the asset guide records the parent model")
		for key in pairs(item) do
			T.ok(key ~= "sourceAssetId" and key ~= "preparedPath" and key ~= "placement" and key ~= "reviewCopy" and key ~= "credit", CONFERENCE_TABLE .. " carries " .. key)
		end
		-- The committed gap audit lists the same source path, type and size (Y within normalization rounding).
		local audit = H.readFile(H.ROOT .. "/docs/assets/Existing_Room_Catalog_Gap_Audit_2026-10-26.json")
		local auditAt = audit:find('"displayName": "Conference table"', 1, true)
		T.ok(auditAt, "gap audit entry exists")
		local auditEntry = audit:sub(auditAt, (audit:find("}", auditAt, true)))
		T.ok(auditEntry:find("Workspace.RoomCollection.ConferenceRoom.Table", 1, true), "same source path as the gap audit")
		T.ok(auditEntry:find('"tables"', 1, true), "the gap audit proposed type tables")
		local sx, sy, sz = entry:match('"size": %[([%d%.]+), ([%d%.]+), ([%d%.]+)%]')
		local size = { tonumber(sx), tonumber(sy), tonumber(sz) }
		local ax, ay, az = auditEntry:match('"size":%s*%[%s*([%d%.]+),%s*([%d%.]+),%s*([%d%.]+)%s*%]')
		T.ok(math.abs(size[1] - tonumber(ax)) < 1e-6 and math.abs(size[3] - tonumber(az)) < 1e-6, "same footprint as the gap audit")
		T.ok(math.abs(size[2] - tonumber(ay)) < 1e-6 and size[2] ~= tonumber(ay), "Y differs only by normalization rounding")
		-- Large footprint (half extents 12.1125 x 5.8125 at yaw 0) inside the live 48 marker.
		local live = { halfX = 24, halfZ = 24, height = 24 }
		local function place(x, y, z, yaw) return Transform.sanitize({ x = x, y = y, z = z, yaw = yaw }, size, live, Config) end
		T.deepEq(place(0, 0, 0, 0), { x = 0, y = 0, z = 0, yaw = 0 }, "on the floor at the centre")
		T.ok(place(11.8, 0, 18, 0) ~= nil, "lengthwise: fits with 11.8 along X and 18 along Z")
		T.eq(select(2, place(12, 0, 0, 0)), "OutOfBounds", "its 24.2 length overhangs the X edge at x = 12")
		T.eq(select(2, place(0, 0, 18.3, 0)), "OutOfBounds", "its 11.6 depth overhangs the Z edge at z = 18.3")
		T.ok(place(18, 0, 11.8, 90) ~= nil, "turned 90 degrees, the long side runs along Z")
		T.eq(select(2, place(0, 0, 12, 90)), "OutOfBounds", "turned 90 degrees, its length overhangs the Z edge at z = 12")
		T.ok(place(12, 0, 0, 270) ~= nil, "turned 270 degrees, x = 12 fits")
		-- At 45 degrees its diagonal extent (12.675 per side) is wider than either axis.
		T.ok(place(11, 0, 11, 45) ~= nil, "45 degrees fits at (11, 11)")
		T.eq(select(2, place(11.5, 0, 0, 45)), "OutOfBounds", "45 degrees overhangs at x = 11.5")
		T.eq(select(2, place(0, 0, 0, 10)), "BadTransform", "yaw stays on the 15 degree step")
		-- Filters: Cozy, 1980s and Futuristic > Tables; never Retro, Winter or Structure mode.
		for _, tag in ipairs(item.collections) do
			local tables = Catalog.getFurnitureByType(tag, "tables")
			T.eq(tables[#tables].id, CONFERENCE_TABLE, "last in " .. tag .. " > Tables")
		end
		for _, tag in ipairs({ "retro", "winter" }) do
			for _, f in ipairs(Catalog.getFurnitureTagged(tag)) do T.ok(f.id ~= CONFERENCE_TABLE, tag .. " excludes the conference table") end
		end
		for _, f in ipairs(Catalog.StructureFilters) do
			for _, s in ipairs(Catalog.getStructureItems(f.id)) do T.ok(s.id ~= CONFERENCE_TABLE, f.id .. " excludes the conference table") end
		end
	end)

	T.test("red flower pot: registered exactly from its manifest as cozy/retro/1980s/winter plants; matches its gap-audit entry; floor and elevated placement limits", function()
		local Transform = H.load("src/shared/Transform")
		local Config = H.load("src/shared/Config")
		local manifest = H.readFile(H.ROOT .. "/docs/assets/Flower_Pot_Registration_2026-10-26.json")
		local count = 0
		for _ in manifest:gmatch('"preparedPath"') do count = count + 1 end
		T.eq(count, 1, "manifest items")
		local item = Catalog.getItem(FLOWER_POT)
		T.ok(item ~= nil, FLOWER_POT)
		T.eq(item.displayName, "Red Flower Pot")
		T.eq(item.type, "plants")
		T.eq(item.structure, nil, "furniture, not structure")
		T.deepEq(item.collections, { "cozy", "retro", "1980s", "winter" })
		T.eq(item.credit, nil, "no credit: the creator is not verified")
		T.eq(item.sourceRef, "ServerStorage.StudioBuilderPreparedAssets." .. FLOWER_POT, "prepared name matches its id")
		local at = manifest:find('"id": "' .. FLOWER_POT .. '"', 1, true)
		T.ok(at, "id in manifest")
		local entry = manifest:sub(at, manifest:find('"visualReview"', at, true))
		T.ok(entry:find('"displayName": "' .. item.displayName .. '"', 1, true), "displayName")
		T.ok(entry:find('"type": "plants"', 1, true), "type in manifest")
		T.ok(entry:find('"collections": ["cozy", "retro", "1980s", "winter"]', 1, true), "collections in manifest")
		T.ok(entry:find('"sourceRef": "' .. item.sourceRef .. '"', 1, true), "sourceRef")
		T.ok(entry:find('"preparedPath": "' .. item.sourceRef .. '"', 1, true), "install source")
		for _, fact in ipairs({ '"baseParts": 38,', '"partBreakdown": "37 Parts + 1 UnionOperation",', '"SpecialMesh": 19', '"CylinderMesh": 4', '"BlockMesh": 10', '"scripts": 0,', '"lights": 0,', '"seats": 0,', '"joints": 0,', '"anchored": true,', '"canTouch": false,' }) do
			T.ok(entry:find(fact, 1, true), fact)
		end
		T.ok(entry:find("no new placement metadata", 1, true), "existing furniture placement")
		T.ok(entry:find("no geometry added", 1, true), "no added geometry")
		T.ok(entry:find("no sway and no interactions", 1, true), "decorative only")
		T.ok(manifest:find('"creator": "Not independently verified; not recorded (no credit)"', 1, true), "creator not invented")
		T.ok(manifest:find("not an individual flower pot model", 1, true), "no individual model ID claimed")
		local guide = H.readFile(H.ROOT .. "/docs/assets/Studio_Asset_Guide_2026-10-25.json")
		local room = guide:find('"name": "ConferenceRoom"', 1, true)
		T.ok(room and guide:sub(room, room + 800):find("Source4993294691", 1, true), "the asset guide records the parent model")
		for key in pairs(item) do
			T.ok(key ~= "sourceAssetId" and key ~= "preparedPath" and key ~= "placement" and key ~= "reviewCopy" and key ~= "meshes" and key ~= "credit", FLOWER_POT .. " carries " .. key)
		end
		-- The committed gap audit lists the same source path, type and size (within 1e-6).
		local audit = H.readFile(H.ROOT .. "/docs/assets/Existing_Room_Catalog_Gap_Audit_2026-10-26.json")
		local auditAt = audit:find('"displayName": "Flower pot"', 1, true)
		T.ok(auditAt, "gap audit entry exists")
		local auditEntry = audit:sub(auditAt, (audit:find("}", auditAt, true)))
		T.ok(auditEntry:find("Workspace.RoomCollection.ConferenceRoom.Flower Pot", 1, true), "same source path as the gap audit")
		T.ok(auditEntry:find('"plants"', 1, true), "the gap audit proposed type plants")
		local sx, sy, sz = entry:match('"size": %[([%d%.]+), ([%d%.]+), ([%d%.]+)%]')
		local size = { tonumber(sx), tonumber(sy), tonumber(sz) }
		local audited = { auditEntry:match('"size":%s*%[%s*([%d%.]+),%s*([%d%.]+),%s*([%d%.]+)%s*%]') }
		for i = 1, 3 do
			T.ok(math.abs(size[i] - tonumber(audited[i])) < 1e-6, "axis " .. i .. " within 1e-6 of the gap audit")
		end
		-- Floor placement (half extents 0.9768 x 0.9676) inside the live 48 marker.
		local live = { halfX = 24, halfZ = 24, height = 24 }
		local function place(x, y, z, yaw) return Transform.sanitize({ x = x, y = y, z = z, yaw = yaw }, size, live, Config) end
		T.deepEq(place(0, 0, 0, 0), { x = 0, y = 0, z = 0, yaw = 0 }, "on the floor at the centre")
		T.ok(place(23, 0, -23, 0) ~= nil, "fits in a corner")
		T.eq(select(2, place(23.1, 0, 0, 0)), "OutOfBounds", "its 1.95 width overhangs the X edge at x = 23.1")
		T.ok(place(23.02, 0, 0, 90) ~= nil, "turned 90 degrees, its 1.94 depth fits at x = 23.02")
		T.eq(select(2, place(0, -0.1, 0, 0)), "OutOfBounds", "not below the floor")
		-- Elevated placement uses the same furniture rules: on top of the 3.3-stud conference table, and up to the 24-stud ceiling.
		T.ok(place(0, 3.3, 0, 0) ~= nil, "raised onto a tabletop")
		T.ok(place(0, 21, 0, 0) ~= nil, "raised to 21: its 2.92 height still clears the ceiling")
		T.eq(select(2, place(0, 21.1, 0, 0)), "OutOfBounds", "raised to 21.1 it would poke through the ceiling")
		-- Filters: Cozy, Retro, 1980s and Winter > Plants; never Futuristic or Structure mode.
		for _, tag in ipairs(item.collections) do
			local plants = Catalog.getFurnitureByType(tag, "plants")
			T.eq(plants[#plants].id, FLOWER_POT, "last in " .. tag .. " > Plants")
		end
		for _, f in ipairs(Catalog.getFurnitureTagged("futuristic")) do T.ok(f.id ~= FLOWER_POT, "futuristic excludes the flower pot") end
		for _, f in ipairs(Catalog.StructureFilters) do
			for _, s in ipairs(Catalog.getStructureItems(f.id)) do T.ok(s.id ~= FLOWER_POT, f.id .. " excludes the flower pot") end
		end
	end)

	T.test("black office chair: one chair registered exactly from its manifest as cozy/1980s/futuristic seating; decorative (no Seat); floor placement fits its bounds", function()
		local Transform = H.load("src/shared/Transform")
		local Config = H.load("src/shared/Config")
		local manifest = H.readFile(H.ROOT .. "/docs/assets/Office_Chair_Registration_2026-10-26.json")
		local count = 0
		for _ in manifest:gmatch('"preparedPath"') do count = count + 1 end
		T.eq(count, 1, "manifest items")
		local item = Catalog.getItem(OFFICE_CHAIR)
		T.ok(item ~= nil, OFFICE_CHAIR)
		T.eq(item.displayName, "Black Office Chair")
		-- Chairs use the existing seating type; there is no separate chairs type in the chooser.
		T.eq(item.type, "seating")
		T.eq(Catalog.getFurnitureType("chairs"), nil, "no new furniture type was added")
		T.eq(#Catalog.FurnitureTypes, 9, "the type list is unchanged")
		T.eq(item.structure, nil, "furniture, not structure")
		T.deepEq(item.collections, { "cozy", "1980s", "futuristic" })
		T.eq(item.credit, nil, "no credit: the creator is not verified")
		T.eq(item.sourceRef, "ServerStorage.StudioBuilderPreparedAssets." .. OFFICE_CHAIR, "prepared name matches its id")
		local at = manifest:find('"id": "' .. OFFICE_CHAIR .. '"', 1, true)
		T.ok(at, "id in manifest")
		local entry = manifest:sub(at, manifest:find('"visualReview"', at, true))
		T.ok(entry:find('"displayName": "' .. item.displayName .. '"', 1, true), "displayName")
		T.ok(entry:find('"type": "seating"', 1, true) and entry:find("Requested as 'chairs'", 1, true), "type mapping recorded")
		T.ok(entry:find('"collections": ["cozy", "1980s", "futuristic"]', 1, true), "collections in manifest")
		T.ok(entry:find('"sourceRef": "' .. item.sourceRef .. '"', 1, true), "sourceRef")
		T.ok(entry:find('"preparedPath": "' .. item.sourceRef .. '"', 1, true), "install source")
		for _, fact in ipairs({ '"baseParts": 1,', '"partClass": "MeshPart",', '"scripts": 0,', '"lights": 0,', '"seats": 0,', '"joints": 0,', '"anchored": true,', '"canTouch": false,', '"collisionFidelity": "Hull",', '"front": "-Z",' }) do
			T.ok(entry:find(fact, 1, true), fact)
		end
		T.ok(entry:find("original scale of 1.125", 1, true), "conversion at the original scale")
		T.ok(entry:find("the Seat and three ManualWelds", 1, true), "excluded Seat and welds recorded")
		T.ok(entry:find("no sitting, rolling or swivel behaviour", 1, true), "decorative only")
		T.ok(manifest:find("NOT the 12-chair group", 1, true), "a single chair, not the group")
		T.ok(manifest:find('"creator": "Not independently verified; not recorded (no credit)"', 1, true), "creator not invented")
		T.ok(manifest:find("not an individual chair model", 1, true), "no individual chair model ID claimed")
		T.ok(manifest:find('"meshId": "rbxassetid://96065544"', 1, true) and manifest:find('"textureId": "rbxassetid://96065600"', 1, true), "mesh content recorded")
		local guide = H.readFile(H.ROOT .. "/docs/assets/Studio_Asset_Guide_2026-10-25.json")
		local room = guide:find('"name": "ConferenceRoom"', 1, true)
		T.ok(room and guide:sub(room, room + 800):find("Source4993294691", 1, true), "the asset guide records the parent model")
		for key, value in pairs(item) do
			T.ok(key ~= "sourceAssetId" and key ~= "preparedPath" and key ~= "placement" and key ~= "reviewCopy" and key ~= "meshContent" and key ~= "credit" and key ~= "seat", OFFICE_CHAIR .. " carries " .. key)
			T.ok(type(value) ~= "string" or not value:find("9606", 1, true), OFFICE_CHAIR .. "." .. key .. " carries no mesh ID")
		end
		-- The gap audit lists the 12-seat group at this path; the registered item is one chair, much smaller than the group.
		local audit = H.readFile(H.ROOT .. "/docs/assets/Existing_Room_Catalog_Gap_Audit_2026-10-26.json")
		local auditAt = audit:find('"displayName": "Office chairs"', 1, true)
		T.ok(auditAt, "gap audit entry exists")
		local auditEntry = audit:sub(audit:sub(1, auditAt):match(".*(){") or 1, (audit:find("}", auditAt, true)))
		T.ok(auditEntry:find("Workspace.RoomCollection.ConferenceRoom.Chairs", 1, true), "same source group as the gap audit")
		T.ok(auditEntry:find('"seats": 12', 1, true), "the audited group holds 12 seats")
		T.ok(auditEntry:find('"seating"', 1, true), "the gap audit proposed type seating")
		local sx, sy, sz = entry:match('"size": %[([%d%.]+), ([%d%.]+), ([%d%.]+)%]')
		local size = { tonumber(sx), tonumber(sy), tonumber(sz) }
		local gx, _, gz = auditEntry:match('"size":%s*%[%s*([%d%.]+),%s*([%d%.]+),%s*([%d%.]+)%s*%]')
		T.ok(size[1] < tonumber(gx) / 5 and size[3] < tonumber(gz) / 5, "one chair, not the group footprint")
		-- Floor placement (half extents 1.1417 x 1.1733) inside the live 48 marker.
		local live = { halfX = 24, halfZ = 24, height = 24 }
		local function place(x, y, z, yaw) return Transform.sanitize({ x = x, y = y, z = z, yaw = yaw }, size, live, Config) end
		T.deepEq(place(0, 0, 0, 0), { x = 0, y = 0, z = 0, yaw = 0 }, "on the floor at the centre")
		T.ok(place(22.8, 0, -22.8, 0) ~= nil, "fits in a corner")
		T.ok(place(22.85, 0, 0, 0) ~= nil, "its 2.28 width fits at x = 22.85")
		T.eq(select(2, place(22.85, 0, 0, 90)), "OutOfBounds", "turned 90 degrees, its 2.35 depth overhangs at x = 22.85")
		T.eq(select(2, place(0, 0, 22.9, 0)), "OutOfBounds", "its 2.35 depth overhangs the Z edge at z = 22.9")
		T.eq(select(2, place(0, 19.9, 0, 0)), "OutOfBounds", "its 4.15 height must stay under the 24 ceiling")
		-- Filters: Cozy, 1980s and Futuristic > Seating, after the earlier chairs; never Retro, Winter or Structure mode.
		for _, tag in ipairs(item.collections) do
			local seating = Catalog.getFurnitureByType(tag, "seating")
			T.eq(seating[#seating].id, OFFICE_CHAIR, "last in " .. tag .. " > Seating")
		end
		for _, tag in ipairs({ "retro", "winter" }) do
			for _, f in ipairs(Catalog.getFurnitureTagged(tag)) do T.ok(f.id ~= OFFICE_CHAIR, tag .. " excludes the office chair") end
		end
		for _, f in ipairs(Catalog.StructureFilters) do
			for _, s in ipairs(Catalog.getStructureItems(f.id)) do T.ok(s.id ~= OFFICE_CHAIR, f.id .. " excludes the office chair") end
		end
	end)

	T.test("steaming coffee mug: decor in every collection, registered from its manifest; modified room version recorded; floor and tabletop placement fit its bounds", function()
		local Transform = H.load("src/shared/Transform")
		local Config = H.load("src/shared/Config")
		local manifest = H.readFile(H.ROOT .. "/docs/assets/Coffee_Mug_Registration_2026-10-26.json")
		local item = Catalog.getItem(MUG)
		T.ok(item ~= nil, MUG)
		T.eq(item.displayName, "Steaming Coffee Mug")
		T.eq(item.type, "decor")
		T.eq(item.structure, nil)
		T.deepEq(item.collections, { "cozy", "retro", "1980s", "winter", "futuristic" })
		T.eq(item.sourceRef, "ServerStorage.StudioBuilderPreparedAssets." .. MUG, "prepared name matches its id")
		local keys = {}
		for key in pairs(item) do keys[#keys + 1] = key end
		table.sort(keys)
		T.eq(table.concat(keys, ","), "collections,displayName,id,sourceRef,type", "only catalog fields; provenance and steam settings stay in the manifest")
		-- The manifest entry agrees with the catalog and records what makes this item different.
		local at = manifest:find('"id": "' .. MUG .. '"', 1, true)
		local entry = manifest:sub(at, manifest:find('"visualReview"', at, true))
		for _, fact in ipairs({ '"displayName": "Steaming Coffee Mug"', '"type": "decor"', '"sourceRef": "' .. item.sourceRef .. '"', '"preparedPath": "' .. item.sourceRef .. '"', '"scripts": 0,', '"seats": 0,', '"particleEmitters": 1,', '"surfaceGuis": 2,' }) do
			T.ok(entry:find(fact, 1, true), fact)
		end
		T.ok(manifest:find("NOT an unchanged free model", 1, true), "the modified room version is not passed off as the free model")
		T.ok(manifest:find('"creator": "Not independently verified; not recorded (no credit)"', 1, true), "creator not invented")
		T.ok(entry:find("forPreview removes the emitter", 1, true), "preview sanitizing recorded")
		-- Same source and size as the gap audit's "Roblox coffee mug" (within 1e-6).
		local audit = H.readFile(H.ROOT .. "/docs/assets/Existing_Room_Catalog_Gap_Audit_2026-10-26.json")
		local auditAt = audit:find('"displayName": "Roblox coffee mug"', 1, true)
		local auditEntry = audit:sub(auditAt, (audit:find("}", auditAt, true)))
		T.ok(auditEntry:find("Workspace.RoomCollection.ConferenceRoom.Coffee cup", 1, true), "same source as the gap audit")
		local size = { entry:match('"size": %[([%d%.]+), ([%d%.]+), ([%d%.]+)%]') }
		local audited = { auditEntry:match('"size":%s*%[%s*([%d%.]+),%s*([%d%.]+),%s*([%d%.]+)%s*%]') }
		for i = 1, 3 do
			size[i] = tonumber(size[i])
			T.ok(math.abs(size[i] - tonumber(audited[i])) < 1e-6, "axis " .. i)
		end
		-- Placement under the existing furniture rules: floor, on the 3.3-stud conference table, and right up to the edge.
		local live = { halfX = 24, halfZ = 24, height = 24 }
		local function place(x, y, z, yaw) return Transform.sanitize({ x = x, y = y, z = z, yaw = yaw }, size, live, Config) end
		T.deepEq(place(0, 0, 0, 0), { x = 0, y = 0, z = 0, yaw = 0 })
		T.ok(place(5, 3.3, -2, 45) ~= nil, "on a tabletop, turned 45 degrees")
		T.ok(place(23.6, 0, 23.69, 0) ~= nil, "fits right against a corner")
		T.eq(select(2, place(23.7, 0, 0, 0)), "OutOfBounds", "its 0.77 width overhangs at x = 23.7")
		T.eq(select(2, place(0, 23.3, 0, 0)), "OutOfBounds", "its 0.74 height must stay under the ceiling")
		-- Listed last under Decor in every collection; never in Structure mode.
		for _, c in ipairs(Catalog.Collections) do
			local decor = Catalog.getFurnitureByType(c.id, "decor")
			T.eq(decor[#decor].id, MUG, "last in " .. c.id .. " > Decor")
		end
		for _, f in ipairs(Catalog.StructureFilters) do
			for _, s in ipairs(Catalog.getStructureItems(f.id)) do T.ok(s.id ~= MUG, f.id) end
		end
	end)

	T.test("presentation board: a static screen in cozy/1980s/futuristic, registered from its manifest; thin footprint fits on the floor, against an edge and raised", function()
		local Transform = H.load("src/shared/Transform")
		local Config = H.load("src/shared/Config")
		local manifest = H.readFile(H.ROOT .. "/docs/assets/Presentation_Board_Registration_2026-10-26.json")
		local item = Catalog.getItem(BOARD)
		T.ok(item ~= nil, BOARD)
		T.eq(item.displayName, "Studio Presentation Board")
		T.eq(item.type, "screens")
		T.eq(item.structure, nil, "furniture placement, not a structure wall piece")
		T.deepEq(item.collections, { "cozy", "1980s", "futuristic" })
		T.eq(item.sourceRef, "ServerStorage.StudioBuilderPreparedAssets." .. BOARD, "prepared name matches its id")
		local keys = {}
		for key in pairs(item) do keys[#keys + 1] = key end
		table.sort(keys)
		T.eq(table.concat(keys, ","), "collections,displayName,id,sourceRef,type", "only catalog fields; provenance and branding stay in the manifest")
		local at = manifest:find('"id": "' .. BOARD .. '"', 1, true)
		local entry = manifest:sub(at, manifest:find('"visualReview"', at, true))
		for _, fact in ipairs({ '"type": "screens"', '"preparedPath": "' .. item.sourceRef .. '"', '"scripts": 0,', '"surfaceGuis": 1,', '"canTouch": false,' }) do
			T.ok(entry:find(fact, 1, true), fact)
		end
		T.ok(entry:find("Removed the StudioTextRole attributes", 1, true), "copies are cut off from global title updates")
		T.ok(manifest:find("NOT an unchanged free model", 1, true), "the branded version is not passed off as the free model")
		-- Same source and size as the gap audit's "Presentation board" (within 1e-5).
		local audit = H.readFile(H.ROOT .. "/docs/assets/Existing_Room_Catalog_Gap_Audit_2026-10-26.json")
		local auditAt = audit:find('"displayName": "Presentation board"', 1, true)
		local auditEntry = audit:sub(auditAt, (audit:find("}", auditAt, true)))
		T.ok(auditEntry:find("Workspace.RoomCollection.ConferenceRoom.WhiteBoard", 1, true), "same source as the gap audit")
		local size = { entry:match('"size": %[([%d%.]+), ([%d%.]+), ([%d%.]+)%]') }
		local audited = { auditEntry:match('"size":%s*%[%s*([%d%.]+),%s*([%d%.]+),%s*([%d%.]+)%s*%]') }
		for i = 1, 3 do
			size[i] = tonumber(size[i])
			T.ok(math.abs(size[i] - tonumber(audited[i])) < 1e-5, "axis " .. i)
		end
		-- Thin 9.5 x 0.24 footprint: it stands right against an edge facing in, but its width overhangs once turned side-on.
		local live = { halfX = 24, halfZ = 24, height = 24 }
		local function place(x, y, z, yaw) return Transform.sanitize({ x = x, y = y, z = z, yaw = yaw }, size, live, Config) end
		T.deepEq(place(0, 0, 0, 0), { x = 0, y = 0, z = 0, yaw = 0 })
		T.ok(place(0, 0, 23.87, 180) ~= nil, "flat against the +Z edge")
		T.ok(place(23.87, 0, 0, 90) ~= nil, "flat against the +X edge, turned 90 degrees")
		T.eq(select(2, place(19.3, 0, 0, 0)), "OutOfBounds", "its 9.5 width overhangs the X edge at x = 19.3")
		-- Raised (for example onto the 3.3-stud conference table) under the same rules, but not through the ceiling.
		T.ok(place(0, 3.3, 0, 0) ~= nil, "raised onto a tabletop")
		T.ok(place(0, 17.3, 0, 0) ~= nil, "raised to 17.3: its 6.67 height still clears the ceiling")
		T.eq(select(2, place(0, 17.4, 0, 0)), "OutOfBounds", "raised to 17.4 it would poke through the ceiling")
		-- Screens: joins the CRT TV in 1980s, and is the only screen in Cozy and Futuristic.
		local function ids(c) local out = {} for _, f in ipairs(Catalog.getFurnitureByType(c, "screens")) do out[#out + 1] = f.id end return out end
		T.deepEq(ids("1980s"), { "retro_crt_tv_01", BOARD })
		T.deepEq(ids("cozy"), { BOARD })
		T.deepEq(ids("futuristic"), { BOARD })
		T.deepEq(ids("retro"), { "retro_crt_tv_01" }, "not in Retro")
		T.deepEq(ids("winter"), {}, "not in Winter")
	end)

	T.test("studio softbox: decorative lighting in cozy/1980s/futuristic with its light recorded as disabled; upright normalized size fits on the floor", function()
		local Transform = H.load("src/shared/Transform")
		local Config = H.load("src/shared/Config")
		local manifest = H.readFile(H.ROOT .. "/docs/assets/Studio_Softbox_Registration_2026-10-26.json")
		local item = Catalog.getItem(SOFTBOX)
		T.ok(item ~= nil, SOFTBOX)
		T.eq(item.displayName, "Studio Softbox")
		T.eq(item.type, "lighting")
		T.eq(item.structure, nil)
		T.deepEq(item.collections, { "cozy", "1980s", "futuristic" })
		T.eq(item.sourceRef, "ServerStorage.StudioBuilderPreparedAssets." .. SOFTBOX, "prepared name matches its id")
		local keys = {}
		for key in pairs(item) do keys[#keys + 1] = key end
		table.sort(keys)
		T.eq(table.concat(keys, ","), "collections,displayName,id,sourceRef,type", "only catalog fields; no light settings or adapter hooks in the catalog")
		local at = manifest:find('"id": "' .. SOFTBOX .. '"', 1, true)
		local entry = manifest:sub(at, manifest:find('"visualReview"', at, true))
		for _, fact in ipairs({ '"type": "lighting"', '"preparedPath": "' .. item.sourceRef .. '"', '"scripts": 0,', '"lights": 1,', '"enabled": false,', '"front": "-Z",' }) do
			T.ok(entry:find(fact, 1, true), fact)
		end
		T.ok(entry:find("must not be enabled", 1, true), "the light stays off; no adjustable lighting promised")
		T.ok(entry:find("27 Studio*/Podcast* descendant attributes", 1, true), "cut off from the old room's fixture controls")
		T.ok(manifest:find("NOT an unchanged free model", 1, true), "the modified version is not passed off as the free model")
		local guide = H.readFile(H.ROOT .. "/docs/assets/Studio_Asset_Guide_2026-10-25.json")
		local room = guide:find('"name": "BroadcastSet"', 1, true)
		T.ok(room and guide:sub(room, room + 800):find("Source136839605425322", 1, true), "parent room asset per the asset guide")
		-- Upright size (height along Y). The gap audit's source had its height in Z; the manifest documents that normalization.
		local size = { entry:match('"size": %[([%d%.]+), ([%d%.]+), ([%d%.]+)%]') }
		for i = 1, 3 do size[i] = tonumber(size[i]) end
		T.ok(size[2] > size[1] and size[2] > size[3], "tallest along Y once normalized")
		local audit = H.readFile(H.ROOT .. "/docs/assets/Existing_Room_Catalog_Gap_Audit_2026-10-26.json")
		local auditAt = audit:find('"displayName": "Studio softbox"', 1, true)
		T.ok(audit:sub(auditAt, (audit:find("}", auditAt, true))):find("Workspace.RoomCollection.BroadcastSet.Softbox1", 1, true), "same source as the gap audit")
		T.ok(entry:find("HEIGHT IN Z", 1, true), "the sideways source axes are documented")
		-- Floor placement with the 2.60 x 3.66 footprint and 7.91 height.
		local live = { halfX = 24, halfZ = 24, height = 24 }
		local function place(x, y, z, yaw) return Transform.sanitize({ x = x, y = y, z = z, yaw = yaw }, size, live, Config) end
		T.deepEq(place(0, 0, 0, 0), { x = 0, y = 0, z = 0, yaw = 0 })
		T.ok(place(22.6, 0, 22.1, 0) ~= nil, "fits in a corner")
		T.eq(select(2, place(0, 0, 22.3, 0)), "OutOfBounds", "its 3.66 depth overhangs the Z edge at z = 22.3")
		T.ok(place(0, 0, 22.3, 90) ~= nil, "turned 90 degrees, its 2.60 width fits at z = 22.3")
		T.eq(select(2, place(0, 16.1, 0, 0)), "OutOfBounds", "its 7.91 height must stay under the 24 ceiling")
		-- Lighting lists: last in Cozy, 1980s and Futuristic; never in Retro or Winter.
		for _, tag in ipairs(item.collections) do
			local lights = Catalog.getFurnitureByType(tag, "lighting")
			T.eq(lights[#lights].id, SOFTBOX, "last in " .. tag .. " > Lighting")
		end
		for _, tag in ipairs({ "retro", "winter" }) do
			for _, f in ipairs(Catalog.getFurnitureByType(tag, "lighting")) do T.ok(f.id ~= SOFTBOX, tag) end
		end
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
		local manifest = H.readFile(H.ROOT .. "/docs/assets/Catalog_Expansion_2026-10-25.json") .. H.readFile(H.ROOT .. "/docs/assets/Structure_and_Decor_Candidates_2026-10-25.json") .. H.readFile(H.ROOT .. "/docs/assets/Decor_Candidate_retro_patterned_rug_01_2026-10-26.json") .. H.readFile(H.ROOT .. "/docs/assets/Decor_Candidate_retro_classic_floor_lamp_01_2026-10-26.json") .. H.readFile(H.ROOT .. "/docs/assets/Structure_Expansion_2026-10-26.json") .. H.readFile(H.ROOT .. "/docs/assets/Futuristic_Furniture_Registration_2026-10-26.json") .. H.readFile(H.ROOT .. "/docs/assets/Tufted_Leather_Sofa_Registration_2026-10-26.json") .. H.readFile(H.ROOT .. "/docs/assets/Batch03_Structure_Registration_2026-10-26.json") .. H.readFile(H.ROOT .. "/docs/assets/Industrial_Wall_Registration_2026-10-26.json") .. H.readFile(H.ROOT .. "/docs/assets/Acoustic_Wall_Registration_2026-10-26.json") .. H.readFile(H.ROOT .. "/docs/assets/Drawer_Cabinet_Registration_2026-10-26.json") .. H.readFile(H.ROOT .. "/docs/assets/Water_Dispenser_Registration_2026-10-26.json") .. H.readFile(H.ROOT .. "/docs/assets/Tall_Floor_Plant_Registration_2026-10-26.json") .. H.readFile(H.ROOT .. "/docs/assets/Conference_Table_Registration_2026-10-26.json") .. H.readFile(H.ROOT .. "/docs/assets/Flower_Pot_Registration_2026-10-26.json") .. H.readFile(H.ROOT .. "/docs/assets/Office_Chair_Registration_2026-10-26.json") .. H.readFile(H.ROOT .. "/docs/assets/Coffee_Mug_Registration_2026-10-26.json") .. H.readFile(H.ROOT .. "/docs/assets/Presentation_Board_Registration_2026-10-26.json") .. H.readFile(H.ROOT .. "/docs/assets/Studio_Softbox_Registration_2026-10-26.json")
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
