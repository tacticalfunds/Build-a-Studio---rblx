-- Static checks over every file in src/ (including Roblox-only modules that the
-- other specs cannot execute).
return function(T, H)
	-- Splits source into code with comments removed. When stripStrings is true,
	-- string literal contents are removed as well.
	local function strip(src, stripStrings)
		local out = {}
		local i, n = 1, #src
		while i <= n do
			local c = src:sub(i, i)
			local two = src:sub(i, i + 1)
			if two == "--" then
				local level = src:match("^%-%-%[(=*)%[", i)
				if level then
					local close = "]" .. level .. "]"
					local e = src:find(close, i, true)
					i = (e or n) + #close
				else
					local e = src:find("\n", i, true)
					i = e or (n + 1)
				end
			elseif c == "[" and src:match("^%[=*%[", i) then
				local level = src:match("^%[(=*)%[", i)
				local close = "]" .. level .. "]"
				local e = src:find(close, i, true) or n
				if not stripStrings then
					out[#out + 1] = src:sub(i, e + #close - 1)
				else
					out[#out + 1] = '""'
				end
				i = e + #close
			elseif c == '"' or c == "'" then
				local j = i + 1
				while j <= n do
					local d = src:sub(j, j)
					if d == "\\" then
						j = j + 2
					elseif d == c then
						break
					else
						j = j + 1
					end
				end
				out[#out + 1] = stripStrings and '""' or src:sub(i, j)
				i = j + 1
			else
				out[#out + 1] = c
				i = i + 1
			end
		end
		return table.concat(out)
	end

	local sources = {}
	for _, rel in ipairs(H.sourceList) do
		sources[rel] = H.readFile(H.ROOT .. "/" .. rel)
	end

	T.test("every source file compiles (Lua 5.1-compatible Luau subset)", function()
		T.ok(#H.sourceList > 0, "no sources found")
		for rel, src in pairs(sources) do
			local chunk, err = load(src, rel, "t", {})
			T.ok(chunk ~= nil, tostring(err))
		end
	end)

	T.test("no Lua 5.4-only syntax that Luau would reject", function()
		local patterns = {
			{ "%f[%w_]goto%f[^%w_]", "goto" },
			{ "::[%a_][%w_]*::", "label" },
			{ "<const>", "<const>" },
			{ "<close>", "<close>" },
			{ "[^~=<>]~[^=]", "bitwise ~" },
			{ "<<", "<<" },
			{ ">>", ">>" },
			{ "[^&]&[^&]", "&" },
			{ "|", "|" },
		}
		for rel, src in pairs(sources) do
			local code = strip(src, true)
			for _, p in ipairs(patterns) do
				T.ok(not code:find(p[1]), rel .. " uses " .. p[2])
			end
		end
	end)

	T.test("no dynamic asset loading, HTTP, payments or LayoutRevision writes in code", function()
		local forbidden = {
			{ "LoadAsset", "LoadAsset" },
			{ "InsertService", "InsertService" },
			{ "GetObjects", "GetObjects" },
			{ "loadstring", "loadstring" },
			{ "HttpService", "HttpService" },
			{ "MarketplaceService", "MarketplaceService" },
			{ "rbxassetid", "asset URL" },
			{ "require%s*%(%s*%d", "require(assetId)" },
			{ "getfenv", "getfenv" },
			{ "setfenv", "setfenv" },
			{ "LayoutRevision", "LayoutRevision" },
		}
		for rel, src in pairs(sources) do
			local code = strip(src, false)
			for _, p in ipairs(forbidden) do
				T.ok(not code:find(p[1]), rel .. " uses " .. p[2])
			end
		end
	end)

	T.test("comment stripper sanity", function()
		T.eq(strip("a --[[ LoadAsset ]] b -- HttpService\nc", false), "a  b \nc")
		T.eq(strip("x = 'goto'", true), 'x = ""')
	end)
end
