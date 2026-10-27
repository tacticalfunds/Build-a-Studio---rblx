--[[
	BuildSearch: the Build drawer's catalog search. Pure.

	normalize(text) trims surrounding whitespace, lowercases and caps the
	length (MaxLength), so "  Lamp " and "lamp" are the same query. filter
	keeps the items whose displayName contains the query as LITERAL text,
	case-insensitively: string.find with plain = true, so characters such as
	"%" or "(" are matched as typed, never as a pattern. An empty query keeps
	every item. The list is whatever the current view shows (collection,
	type or structure filter), so search never widens the scope.
]]

local BuildSearch = {}

BuildSearch.MaxLength = 60

function BuildSearch.normalize(text)
	if type(text) ~= "string" then
		return ""
	end
	local trimmed = string.sub(text, 1, BuildSearch.MaxLength)
	trimmed = string.gsub(trimmed, "^%s+", "")
	trimmed = string.gsub(trimmed, "%s+$", "")
	return string.lower(trimmed)
end

-- items: { { displayName, ... } }; query: a normalized query.
function BuildSearch.filter(items, query)
	if query == nil or query == "" then
		return items
	end
	local out = {}
	for _, item in ipairs(items) do
		local name = type(item.displayName) == "string" and string.lower(item.displayName) or nil
		if name and string.find(name, query, 1, true) then
			out[#out + 1] = item
		end
	end
	return out
end

-- The empty state's hint, naming the scope the search looked in.
function BuildSearch.emptyHint(scopeName)
	if type(scopeName) == "string" and scopeName ~= "" then
		return "Search looks in " .. scopeName .. " only. Try another filter or clear the search."
	end
	return "Try another filter or clear the search."
end

return BuildSearch
