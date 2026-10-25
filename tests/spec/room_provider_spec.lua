return function(T, H)
	local RoomProvider = H.load("src/server/Adapters/RoomProvider")
	local ORIGIN = { fakeCFrame = true }

	local function provider(descriptor, opts)
		return RoomProvider.new({
			resolve = function()
				if opts == "error" then
					error("no rooms")
				end
				return descriptor
			end,
			isOrigin = function(v) return v == ORIGIN end,
		})
	end

	local function sandbox(bounds, id, origin)
		return { id = id or "sandbox_main", origin = origin or ORIGIN, bounds = bounds or { halfX = 20, halfZ = 15, height = 16 } }
	end

	T.test("valid sandbox is returned as a clean copy", function()
		local raw = sandbox()
		local d = assert(provider(raw):resolve({}))
		T.eq(d.id, "sandbox_main")
		T.eq(d.bounds.halfZ, 15)
		raw.bounds.halfZ = 999
		T.eq(d.bounds.halfZ, 15, "copied")
	end)

	T.test("nil and errors mean no sandbox", function()
		local d, reason = provider(nil):resolve({})
		T.eq(d, nil)
		T.eq(reason, "NoSandbox")
		d, reason = provider(nil, "error"):resolve({})
		T.eq(d, nil)
		T.eq(reason, "ResolverError")
	end)

	T.test("malformed descriptors are rejected", function()
		local cases = {
			sandbox({ halfX = 0, halfZ = 1, height = 1 }),
			sandbox({ halfX = -5, halfZ = 1, height = 1 }),
			sandbox({ halfX = 0 / 0, halfZ = 1, height = 1 }),
			sandbox({ halfX = math.huge, halfZ = 1, height = 1 }),
			sandbox({ halfX = 5, halfZ = 1 }),
			sandbox({ halfX = 5, halfZ = 1, height = 1e9 }),
			sandbox(nil, ""),
			sandbox(nil, 42),
			sandbox(nil, nil, { notACFrame = true }),
			"sandbox",
		}
		for i, raw in ipairs(cases) do
			local d, reason = provider(raw):resolve({})
			T.eq(d, nil, "case " .. i)
			T.eq(reason, "InvalidSandbox", "case " .. i)
		end
	end)
end
