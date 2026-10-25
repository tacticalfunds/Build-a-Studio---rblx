return function(T, H)
	local Catalog = H.load("src/shared/Catalog")
	local TemplateCatalog = H.load("src/server/Adapters/TemplateCatalog")
	local S = TemplateCatalog.Status

	T.test("missing templates are reported as not installed", function()
		local tc = TemplateCatalog.build(Catalog, function() return nil end)
		for _, item in ipairs(Catalog.Items) do
			T.eq(tc:status(item.id), S.NotInstalled, item.id)
			T.eq(tc:isInstalled(item.id), false)
			T.eq(tc:getSize(item.id), nil)
		end
	end)

	T.test("probe is asked only for catalog IDs", function()
		local asked = {}
		TemplateCatalog.build(Catalog, function(id)
			asked[#asked + 1] = id
			return nil
		end)
		T.eq(#asked, #Catalog.Items)
		for i, item in ipairs(Catalog.Items) do
			T.eq(asked[i], item.id)
		end
	end)

	T.test("installed templates expose a copied size", function()
		local tc = TemplateCatalog.build(Catalog, function(id)
			if id == "cozy_plant_01" then
				return { size = { 2.9, 5.7, 2.9 } }
			end
			return nil
		end)
		T.eq(tc:status("cozy_plant_01"), S.Installed)
		local size = tc:getSize("cozy_plant_01")
		T.deepEq(size, { 2.9, 5.7, 2.9 })
		size[1] = 999
		T.eq(tc:getSize("cozy_plant_01")[1], 2.9, "getSize returns a copy")
		T.eq(tc:status("cozy_armchair_01"), S.NotInstalled)
	end)

	T.test("probe errors and bad sizes mark entries invalid", function()
		local bad = {
			cozy_armchair_01 = "error",
			cozy_coffee_table_01 = { size = { 0, 1, 1 } },
			cozy_bookshelf_01 = { size = { 0 / 0, 1, 1 } },
			cozy_plant_01 = { size = { 1, 2 } },
			cozy_floor_lamp_01 = { size = { 1, 2, 3, 4 } },
			retro_tv_cart_01 = { size = { 1, 1, 1e9 } },
			retro_cassette_01 = "big",
		}
		local tc = TemplateCatalog.build(Catalog, function(id)
			if bad[id] == "error" then
				error("template contains scripts")
			end
			return bad[id]
		end)
		for id in pairs(bad) do
			T.eq(tc:status(id), S.Invalid, id)
			T.eq(tc:isInstalled(id), false, id)
		end
	end)

	T.test("unknown and non-string IDs are never installed", function()
		local tc = TemplateCatalog.build(Catalog, function() return { size = { 1, 1, 1 } } end)
		T.eq(tc:status("not_a_real_item"), nil)
		T.eq(tc:isInstalled(io.stdout), false)
		T.eq(tc:isInstalled({}), false)
		T.eq(tc:getSize(42), nil)
	end)

	T.test("client listing exposes only safe fields", function()
		local tc = TemplateCatalog.build(Catalog, function(id)
			if id == "retro_tv_cart_01" then
				return { size = { 3.3, 4.7, 4 } }
			end
			return nil
		end)
		local allowed = { id = true, displayName = true, collections = true, status = true, size = true, structure = true }
		local listing = tc:clientListing()
		T.eq(#listing, #Catalog.Items)
		for _, entry in ipairs(listing) do
			for key in pairs(entry) do
				T.ok(allowed[key], "unexpected key " .. key)
			end
			if entry.structure ~= nil then
				local keys = {}
				for k in pairs(entry.structure) do keys[#keys + 1] = k end
				T.eq(table.concat(keys, ","), "kind", "structure exposes only its kind")
			end
			if entry.id == "retro_tv_cart_01" then
				T.eq(entry.status, S.Installed)
			else
				T.eq(entry.status, S.NotInstalled)
				T.eq(entry.size, nil)
			end
		end
		listing[1].collections[1] = "hacked"
		T.ok(Catalog.Items[1].collections[1] ~= "hacked", "listing does not alias the catalog")
	end)
end
