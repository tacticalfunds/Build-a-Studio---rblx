return function(T, H)
	local HostAuthority = H.load("src/server/Adapters/HostAuthority")
	local R = HostAuthority.Reasons

	local function withHost(value)
		return HostAuthority.new({ getHostUserId = function() return value end })
	end

	T.test("the host is allowed; anyone else is denied", function()
		local a = withHost(1001)
		T.eq(a:check(1001), true)
		local allowed, reason = a:check(1002)
		T.eq(allowed, false)
		T.eq(reason, R.NotHost)
	end)

	T.test("missing host fails closed", function()
		local allowed, reason = withHost(nil):check(1001)
		T.eq(allowed, false)
		T.eq(reason, R.NoHost)
	end)

	T.test("an erroring source fails closed", function()
		local a = HostAuthority.new({ getHostUserId = function() error("boom") end })
		local allowed, reason = a:check(1001)
		T.eq(allowed, false)
		T.eq(reason, R.HostUnavailable)
	end)

	T.test("non-integer or non-number host IDs are rejected, not coerced", function()
		for _, bad in ipairs({ "1001", 1001.5, 0, -1001, 0 / 0, math.huge, true, {} }) do
			local allowed, reason = withHost(bad):check(1001)
			T.eq(allowed, false, "host " .. tostring(bad))
			T.eq(reason, R.HostIdInvalid, "host " .. tostring(bad))
		end
	end)

	T.test("malformed user IDs are rejected", function()
		local a = withHost(1001)
		for _, bad in ipairs({ "1001", 1001.5, 0, -1, 0 / 0, -math.huge, {}, io.stdout }) do
			local allowed, reason = a:check(bad)
			T.eq(allowed, false, "user " .. tostring(bad))
			T.eq(reason, R.BadUserId)
		end
		T.eq((a:check(nil)), false)
	end)

	T.test("no caching: a host change applies to the next check", function()
		local host = 1
		local a = HostAuthority.new({ getHostUserId = function() return host end })
		T.eq(a:check(1), true)
		host = 2
		T.eq((a:check(1)), false)
		T.eq(a:check(2), true)
	end)

	T.test("default source reads ReplicatedStorage.PodcastSettings HostUserId", function()
		local a = HostAuthority.new({ getHostUserId = HostAuthority.podcastSettingsSource() })
		local allowed, reason = a:check(42)
		T.eq(allowed, false)
		T.eq(reason, R.NoHost, "no PodcastSettings")
		H.setServiceChild("ReplicatedStorage", "PodcastSettings", {
			GetAttribute = function(_, name)
				if name == "HostUserId" then
					return 42
				end
				return nil
			end,
		})
		T.eq(a:check(42), true)
		T.eq((a:check(43)), false)
		H.setServiceChild("ReplicatedStorage", "PodcastSettings", nil)
	end)

	T.test("constructor requires a source", function()
		T.throws(function() HostAuthority.new({}) end)
		T.throws(function() HostAuthority.new() end)
	end)
end
