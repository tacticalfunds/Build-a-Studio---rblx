--[[
	Entitlements: future unlock hook for collections. Everything is free today.

	* `kind = "free"` (or no entitlement metadata) is always unlocked.
	* Any other kind needs a resolver injected via `resolvers[kind]`. Unknown
	  kinds fail closed, so tagging a collection with a paid kind before a real
	  ownership check exists can never unlock it by accident. No game-pass or
	  developer-product checks are implemented here, and no purchase prompts.
	* An item is usable when ANY of its collection tags is unlocked, so a future
	  paid-only item must be tagged with paid collections only.
]]

local Entitlements = {}
Entitlements.__index = Entitlements

-- options.resolvers: { [kind] = function(userId, entitlement) -> boolean } (optional)
function Entitlements.new(options)
	local resolvers = {}
	if type(options) == "table" and type(options.resolvers) == "table" then
		for kind, resolver in pairs(options.resolvers) do
			if type(kind) == "string" and type(resolver) == "function" then
				resolvers[kind] = resolver
			end
		end
	end
	-- "free" cannot be overridden.
	resolvers.free = function()
		return true
	end
	return setmetatable({ resolvers = resolvers }, Entitlements)
end

function Entitlements:isCollectionUnlocked(userId, collection)
	if type(collection) ~= "table" then
		return false
	end
	local entitlement = collection.entitlement
	local kind
	if entitlement == nil then
		kind = "free"
	elseif type(entitlement) == "table" then
		kind = entitlement.kind
	end
	local resolver = type(kind) == "string" and self.resolvers[kind] or nil
	if resolver == nil then
		return false
	end
	local ok, unlocked = pcall(resolver, userId, entitlement)
	return ok and unlocked == true
end

-- catalog must provide getCollection(id).
function Entitlements:isItemUnlocked(userId, item, catalog)
	if type(item) ~= "table" or type(item.collections) ~= "table" then
		return false
	end
	for _, tag in ipairs(item.collections) do
		if self:isCollectionUnlocked(userId, catalog.getCollection(tag)) then
			return true
		end
	end
	return false
end

return Entitlements
