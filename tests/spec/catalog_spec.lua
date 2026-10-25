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

	T.test("catalog contains exactly the agreed stable item IDs", function()
		local expected = {
			"cozy_armchair_01", "cozy_coffee_table_01", "cozy_bookshelf_01", "cozy_plant_01",
			"cozy_floor_lamp_01", "retro_tv_cart_01", "retro_cassette_01",
		}
		T.eq(#Catalog.Items, #expected, "item count")
		for _, id in ipairs(expected) do
			T.ok(Catalog.getItem(id) ~= nil, "missing " .. id)
		end
	end)

	T.test("collection tags filter items; futuristic has no items yet", function()
		local cozy = Catalog.getItemsTagged("cozy")
		T.eq(#cozy, 5, "cozy count")
		local eighties = Catalog.getItemsTagged("1980s")
		local ids = {}
		for _, item in ipairs(eighties) do
			ids[item.id] = true
		end
		T.ok(ids.retro_tv_cart_01 and ids.retro_cassette_01 and ids.cozy_armchair_01, "1980s tags")
		T.eq(#Catalog.getItemsTagged("futuristic"), 0, "futuristic")
		T.eq(#Catalog.getItemsTagged("nope"), 0, "unknown tag")
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

	T.test("every sourceRef exists in the committed asset guide (no invented sources)", function()
		local guide = H.readFile(H.ROOT .. "/docs/assets/Studio_Asset_Guide_2026-10-25.json")
		for _, item in ipairs(Catalog.Items) do
			T.ok(string.find(guide, '"path": "' .. item.sourceRef .. '"', 1, true) or string.find(guide, '"path":"' .. item.sourceRef .. '"', 1, true),
				item.id .. " sourceRef not in asset guide: " .. item.sourceRef)
		end
	end)

	T.test("no catalog field carries an asset ID", function()
		for _, item in ipairs(Catalog.Items) do
			for key, value in pairs(item) do
				if type(value) == "string" then
					T.ok(not string.find(value, "%d%d%d%d%d"), item.id .. "." .. key .. " looks like an asset ID")
				end
			end
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
