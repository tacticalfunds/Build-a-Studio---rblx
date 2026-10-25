--[[
	RateLimiter: per-key token buckets. Pure; the clock is injected.
	rules = { [category] = { capacity = n, refillPerSecond = r } }
]]

local RateLimiter = {}
RateLimiter.__index = RateLimiter

function RateLimiter.new(rules, clock)
	assert(type(rules) == "table" and type(clock) == "function", "RateLimiter.new requires rules and clock")
	return setmetatable({ rules = rules, clock = clock, buckets = {} }, RateLimiter)
end

-- Spends one token; returns false when the bucket is empty or the category unknown.
function RateLimiter:allow(key, category)
	local rule = self.rules[category]
	if rule == nil then
		return false
	end
	local now = self.clock()
	local perKey = self.buckets[key]
	if perKey == nil then
		perKey = {}
		self.buckets[key] = perKey
	end
	local bucket = perKey[category]
	if bucket == nil then
		bucket = { tokens = rule.capacity, at = now }
		perKey[category] = bucket
	end
	local elapsed = now - bucket.at
	if elapsed > 0 then
		bucket.tokens = math.min(rule.capacity, bucket.tokens + elapsed * rule.refillPerSecond)
	end
	bucket.at = now
	if bucket.tokens >= 1 then
		bucket.tokens = bucket.tokens - 1
		return true
	end
	return false
end

function RateLimiter:forget(key)
	self.buckets[key] = nil
end

return RateLimiter
