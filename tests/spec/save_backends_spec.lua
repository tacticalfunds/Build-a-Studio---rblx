return function(T, H)
	local SaveBackends = H.load("src/server/Adapters/SaveBackends")

	T.test("memory backend returns nil for unsaved users", function()
		T.eq(SaveBackends.memory():load(1), nil)
	end)

	T.test("memory backend copies on save and on load", function()
		local b = SaveBackends.memory()
		local record = { schema = "StudioBuilder.Build", items = { { id = "i1", x = 1 } } }
		b:save(1, record)
		record.items[1].x = 99
		local loaded = b:load(1)
		T.eq(loaded.items[1].x, 1, "save copied")
		loaded.items[1].x = 42
		T.eq(b:load(1).items[1].x, 1, "load copied")
		T.eq(b:load(2), nil, "users are separate")
	end)

	T.test("backend contract check", function()
		T.ok(SaveBackends.check(SaveBackends.memory()))
		T.eq((SaveBackends.check(nil)), false)
		T.eq((SaveBackends.check({ kind = "", load = print, save = print })), false)
		T.eq((SaveBackends.check({ kind = "x", load = print })), false)
	end)
end
