return function(T, H)
	local Catalog = H.load("src/shared/Catalog")
	local Entitlements = H.load("src/server/Adapters/Entitlements")

	T.test("every shipped item is unlocked by default (everything free)", function()
		local e = Entitlements.new()
		for _, item in ipairs(Catalog.Items) do
			T.ok(e:isItemUnlocked(12345, item, Catalog), item.id)
		end
		for _, c in ipairs(Catalog.Collections) do
			T.ok(e:isCollectionUnlocked(12345, c), c.id)
		end
	end)

	T.test("missing entitlement metadata counts as free", function()
		T.ok(Entitlements.new():isCollectionUnlocked(1, { id = "x" }))
	end)

	T.test("unknown or malformed kinds fail closed", function()
		local e = Entitlements.new()
		T.eq(e:isCollectionUnlocked(1, { id = "x", entitlement = { kind = "gamepass" } }), false, "unknown kind")
		T.eq(e:isCollectionUnlocked(1, { id = "x", entitlement = "free" }), false, "string metadata")
		T.eq(e:isCollectionUnlocked(1, { id = "x", entitlement = { kind = 5 } }), false, "non-string kind")
		T.eq(e:isCollectionUnlocked(1, nil), false, "nil collection")
		T.eq(e:isCollectionUnlocked(1, io.stdout), false, "userdata collection")
	end)

	T.test("future resolvers decide their own kind; errors and non-true results lock", function()
		local calls = {}
		local e = Entitlements.new({
			resolvers = {
				owned = function(userId, entitlement)
					calls[#calls + 1] = { userId, entitlement.tier }
					return userId == 7
				end,
				broken = function()
					error("service down")
				end,
				truthy = function()
					return "yes"
				end,
			},
		})
		local owned = { id = "x", entitlement = { kind = "owned", tier = "gold" } }
		T.eq(e:isCollectionUnlocked(7, owned), true)
		T.eq(e:isCollectionUnlocked(8, owned), false)
		T.eq(calls[1][1], 7)
		T.eq(calls[1][2], "gold", "resolver receives the entitlement metadata")
		T.eq(e:isCollectionUnlocked(7, { id = "y", entitlement = { kind = "broken" } }), false)
		T.eq(e:isCollectionUnlocked(7, { id = "z", entitlement = { kind = "truthy" } }), false)
	end)

	T.test("free cannot be overridden into a paywall", function()
		local e = Entitlements.new({ resolvers = { free = function() return false end } })
		T.ok(e:isCollectionUnlocked(1, { id = "x", entitlement = { kind = "free" } }))
	end)

	T.test("an item is unlocked when any tag is unlocked", function()
		local catalog = {
			getCollection = function(id)
				local map = {
					open = { id = "open", entitlement = { kind = "free" } },
					locked = { id = "locked", entitlement = { kind = "future" } },
				}
				return map[id]
			end,
		}
		local e = Entitlements.new()
		T.ok(e:isItemUnlocked(1, { id = "a", collections = { "locked", "open" } }, catalog), "mixed tags")
		T.eq(e:isItemUnlocked(1, { id = "b", collections = { "locked" } }, catalog), false, "locked only")
		T.eq(e:isItemUnlocked(1, { id = "c", collections = { "missing" } }, catalog), false, "unknown tag")
		T.eq(e:isItemUnlocked(1, nil, catalog), false, "nil item")
		T.eq(e:isItemUnlocked(1, { id = "d" }, catalog), false, "untagged item")
	end)
end
