--[[
	HostAuthority: decides whether a user may edit the build sandbox.

	Contract (Codex, 2026-10-25): the authoritative host is
	ReplicatedStorage.PodcastSettings:GetAttribute("HostUserId"), checked
	server-side on every edit. The source is injected so tests and future
	integrations can supply it; the authority itself never caches, so a host
	change applies to the very next request.

	Fails closed: a missing PodcastSettings, missing/non-integer attribute or an
	erroring source all deny. A string-typed attribute is denied rather than
	coerced (attribute type not yet confirmed in Studio).

	Usage:
		local authority = HostAuthority.new({ getHostUserId = HostAuthority.podcastSettingsSource() })
		local allowed, reason = authority:check(player.UserId)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("StudioBuilder")
local Validate = require(Shared:WaitForChild("Validate"))

local HostAuthority = {}
HostAuthority.__index = HostAuthority

HostAuthority.Reasons = {
	BadUserId = "BadUserId",
	HostUnavailable = "HostUnavailable",
	NoHost = "NoHost",
	HostIdInvalid = "HostIdInvalid",
	NotHost = "NotHost",
}

-- options.getHostUserId: function() -> number|nil
function HostAuthority.new(options)
	assert(type(options) == "table" and type(options.getHostUserId) == "function", "HostAuthority.new requires getHostUserId")
	return setmetatable({ getHostUserId = options.getHostUserId }, HostAuthority)
end

-- Returns allowed (boolean), reason (string, only when denied).
function HostAuthority:check(userId)
	local Reasons = HostAuthority.Reasons
	if not Validate.isPositiveInteger(userId) then
		return false, Reasons.BadUserId
	end
	local ok, hostUserId = pcall(self.getHostUserId)
	if not ok then
		return false, Reasons.HostUnavailable
	end
	if hostUserId == nil then
		return false, Reasons.NoHost
	end
	if not Validate.isPositiveInteger(hostUserId) then
		return false, Reasons.HostIdInvalid
	end
	if hostUserId ~= userId then
		return false, Reasons.NotHost
	end
	return true
end

-- Default live source. Studio integration pending: verifies nothing beyond the
-- documented attribute name.
function HostAuthority.podcastSettingsSource()
	return function()
		local settings = ReplicatedStorage:FindFirstChild("PodcastSettings")
		if settings == nil then
			return nil
		end
		return settings:GetAttribute("HostUserId")
	end
end

return HostAuthority
