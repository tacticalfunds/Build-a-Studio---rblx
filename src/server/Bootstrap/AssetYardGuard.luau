--[[
	AssetYardGuard: removes the editor-only asset yard when a server starts.

	Workspace.StudioAssetYard holds display copies Codex uses while curating
	assets in Edit mode. It is not a build template source (those live in
	ServerStorage.StudioBuilderTemplates) and must not exist during play.
	Only the exact top-level child is removed; nothing else in Workspace (the
	six rooms included) is searched or touched.
]]

local AssetYardGuard = {}

-- workspace: anything with FindFirstChild (injected for tests).
-- Returns true when a yard was found and destroyed.
function AssetYardGuard.run(workspace, yardName)
	local yard = workspace:FindFirstChild(yardName)
	if yard == nil then
		return false
	end
	yard:Destroy()
	return true
end

return AssetYardGuard
