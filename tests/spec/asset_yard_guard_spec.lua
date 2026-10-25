return function(T, H)
	local AssetYardGuard = H.load("src/server/Bootstrap/AssetYardGuard")
	local Config = H.load("src/shared/Config")

	local function fakeWorkspace(childNames)
		local destroyed = {}
		local children = {}
		for _, name in ipairs(childNames) do
			children[name] = { Destroy = function() destroyed[#destroyed + 1] = name end }
		end
		local ws = {
			FindFirstChild = function(_, name, recursive)
				T.eq(recursive, nil, "must not search recursively")
				return children[name]
			end,
		}
		return ws, destroyed
	end

	T.test("removes only the top-level asset yard", function()
		local ws, destroyed = fakeWorkspace({ "StudioAssetYard", "PodcastStudio", "FreeModelStudio", "RoomCollection" })
		T.eq(AssetYardGuard.run(ws, Config.AssetYardName), true)
		T.eq(table.concat(destroyed, ","), "StudioAssetYard")
	end)

	T.test("no yard means nothing is touched", function()
		local ws, destroyed = fakeWorkspace({ "PodcastStudio", "RoomCollection" })
		T.eq(AssetYardGuard.run(ws, Config.AssetYardName), false)
		T.eq(#destroyed, 0)
	end)

	T.test("configured name matches the editor yard", function()
		T.eq(Config.AssetYardName, "StudioAssetYard")
	end)
end
