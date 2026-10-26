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

	T.test("catalog holds the 7 original, 24 expansion, 5 structure and 4 later furniture IDs, earlier entries unchanged in order", function()
		T.eq(#Catalog.Items, 40, "item count")
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
		local expected = { cozy = 26, retro = 20, ["1980s"] = 16, winter = 12, futuristic = 9 }
		for _, c in ipairs(Catalog.Collections) do
			T.eq(#Catalog.getFurnitureTagged(c.id), expected[c.id], c.id .. " furniture count")
			T.eq(#Catalog.getItemsTagged(c.id), expected[c.id] + 5, c.id .. " raw tag count")
			for _, item in ipairs(Catalog.getFurnitureTagged(c.id)) do
				T.eq(item.structure, nil, item.id)
			end
		end
		for _, f in ipairs(Catalog.StructureFilters) do
			local items = Catalog.getStructureItems(f.id)
			T.eq(#items, 1, f.id)
			T.eq(STRUCTURE[items[1].id], f.id)
		end
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
		T.eq(#Catalog.Items, base + #APPROVED_TRACKED, "nothing after the approved tracked items")
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
		local manifest = H.readFile(H.ROOT .. "/docs/assets/Catalog_Expansion_2026-10-25.json") .. H.readFile(H.ROOT .. "/docs/assets/Structure_and_Decor_Candidates_2026-10-25.json") .. H.readFile(H.ROOT .. "/docs/assets/Decor_Candidate_retro_patterned_rug_01_2026-10-26.json") .. H.readFile(H.ROOT .. "/docs/assets/Decor_Candidate_retro_classic_floor_lamp_01_2026-10-26.json")
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
