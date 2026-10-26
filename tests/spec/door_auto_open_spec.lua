-- Panel door foundation: the pure auto-open state machine (DoorAutoOpen),
-- driven by a fake clock and hand-built adapter inputs. Nothing here is
-- wired live; the runtime adapters are a later checkpoint.
return function(T, H)
	local DoorAutoOpen = H.load("src/server/Core/DoorAutoOpen")
	local Codes = DoorAutoOpen.Codes

	local function input(nearby, occupied, blocked)
		return { nearby = nearby, occupied = occupied, blocked = blocked }
	end
	local CLEAR = input(false, false, false)
	local NEAR = input(true, false, false)
	local OCCUPIED = input(false, true, false)
	local BLOCKED = input(false, false, true)
	local NEAR_BLOCKED = input(true, false, true)
	-- Malformed inputs: every one must be treated as UNKNOWN (hold, never move).
	local MALFORMED = {
		{ name = "missing", value = nil },
		{ name = "string", value = "near" },
		{ name = "empty table", value = {} },
		{ name = "only blocked=false", value = { blocked = false } },
		{ name = "nearby only", value = { nearby = true } },
		{ name = "string boolean", value = { nearby = "true", occupied = false, blocked = false } },
		{ name = "number for blocked", value = { nearby = false, occupied = false, blocked = 0 } },
		{ name = "occupied missing", value = { nearby = false, blocked = false } },
		{ name = "extra key", value = { nearby = false, occupied = false, blocked = false, open = true } },
	}

	local function oneDoor(config)
		local m = DoorAutoOpen.new(config)
		T.eq(m:add("d1"), true)
		return m
	end
	local function step(m, now, value)
		local events = m:update(now, { d1 = value })
		T.ok(#events <= 1, "at most one event per door")
		return events[1]
	end
	local function near(a, b) return math.abs(a - b) < 1e-9 end
	-- Drive a fresh door to a phase at a known time.
	local function at(phase)
		local m = oneDoor()
		if phase == "closed" then
			step(m, 0, CLEAR)
			return m, 0
		end
		step(m, 0, NEAR)
		if phase == "opening" then
			return m, 0.3
		end
		step(m, 0.6, NEAR)
		if phase == "open" then
			return m, 1
		end
		step(m, 1, CLEAR)
		T.eq(step(m, 3, CLEAR).kind, "closing")
		if phase == "closing" then
			return m, 3.3
		end
		step(m, 3.3, BLOCKED) -- held half-way while closing
		return m, 4
	end

	T.test("config and registry: validated settings, ids, duplicates, cap, remove", function()
		local m = DoorAutoOpen.new()
		T.eq(m.openSeconds, 0.6)
		T.eq(m.exitDelay, 2)
		for _, bad in ipairs({ { openSeconds = 0 }, { exitDelay = -1 }, { closeSeconds = 0 / 0 }, { maxDoors = math.huge } }) do
			T.eq(pcall(DoorAutoOpen.new, bad), false)
		end
		T.eq(select(2, m:add("")), Codes.BadId)
		T.eq(select(2, m:add(7)), Codes.BadId)
		T.eq(select(2, m:add(("x"):rep(65))), Codes.BadId)
		T.eq(m:add("a"), true)
		T.eq(select(2, m:add("a")), Codes.Duplicate)
		local small = DoorAutoOpen.new({ maxDoors = 2 })
		small:add("a"); small:add("b")
		T.eq(select(2, small:add("c")), Codes.TooMany)
		T.eq(small:remove("a"), true)
		T.eq(small:remove("a"), false)
		T.eq(small:add("c"), true, "a removed slot can be reused")
		local s = m:state("a")
		T.eq(s.phase, "closed"); T.eq(s.progress, 0); T.eq(s.collidable, true)
	end)

	T.test("proximity: opens with collision off, progresses by the clock, finishes open", function()
		local m = oneDoor()
		T.eq(step(m, 0, CLEAR), nil, "nothing to do while clear")
		local e = step(m, 1, NEAR)
		T.eq(e.kind, "opening"); T.eq(e.from, 0); T.eq(e.to, 1); T.eq(e.duration, 0.6)
		T.eq(m:state("d1").collidable, false, "collision off while moving")
		T.ok(near(m:state("d1", 1.3).progress, 0.5))
		T.eq(step(m, 1.3, NEAR), nil)
		T.deepEq(step(m, 1.6, NEAR), { kind = "opened", id = "d1", token = e.token })
		T.eq(m:state("d1").phase, "open")
	end)

	T.test("exit delay: closes only after being clear for exitDelay; any presence restarts the wait", function()
		local m = at("open")
		T.eq(step(m, 1, CLEAR), nil, "clear timer starts")
		T.eq(step(m, 2.9, CLEAR), nil, "not yet")
		T.eq(step(m, 3.5, NEAR), nil, "someone came back")
		T.eq(step(m, 4, CLEAR), nil, "timer restarts")
		T.eq(step(m, 5.9, CLEAR), nil)
		local e = step(m, 6, CLEAR)
		T.eq(e.kind, "closing")
		T.ok(near(e.duration, 0.6))
		T.deepEq(step(m, 6.6, CLEAR), { kind = "closed", id = "d1", token = e.token, collide = true }, "closes clear, so collision returns")
		T.eq(m:state("d1").collidable, true)
	end)

	T.test("hold open: occupied or blocked keeps an open door open indefinitely", function()
		for _, value in ipairs({ OCCUPIED, BLOCKED }) do
			local m = at("open")
			for t = 1, 60 do
				T.eq(step(m, t, value), nil, "held at " .. t)
			end
			T.eq(m:state("d1").phase, "open")
			T.eq(step(m, 61, CLEAR), nil)
			T.eq(step(m, 63, CLEAR).kind, "closing", "closes once clear for the delay")
		end
	end)

	T.test("closing + avatar or returning player: reopens from where it is, because the sweep is known clear", function()
		for _, value in ipairs({ OCCUPIED, NEAR }) do
			local m = at("closing")
			local e = step(m, 3.3, value)
			T.eq(e.kind, "opening")
			T.ok(near(e.from, 0.5) and near(e.duration, 0.3), "reverses from 0.5 for the remaining 0.3 s")
			T.eq(m:state("d1").collidable, false, "never collides mid-swing")
			T.eq(step(m, 3.6, value).kind, "opened")
		end
	end)

	T.test("closing + solid obstruction: holds part-way (no reopen bypass); stays held while blocked; resumes the safe direction once clear", function()
		local m = at("closing")
		local held = step(m, 3.3, BLOCKED)
		T.eq(held.kind, "held")
		T.ok(near(held.progress, 0.5))
		for t = 4, 30 do
			T.eq(step(m, t, BLOCKED), nil, "persistent blocked never opens or closes it")
			T.eq(step(m, t + 0.5, NEAR_BLOCKED), nil, "nor does a player nearby while blocked")
		end
		local s = m:state("d1", 31)
		T.eq(s.phase, "held"); T.ok(near(s.progress, 0.5)); T.eq(s.collidable, false)
		-- Clear and nobody wants it open: finish closing from where it stopped.
		local resume = step(m, 31, CLEAR)
		T.eq(resume.kind, "closing")
		T.ok(near(resume.from, 0.5) and near(resume.duration, 0.3))
		T.eq(step(m, 31.3, CLEAR).kind, "closed")
		-- Clear and someone near: open from where it stopped instead.
		local m2 = at("closing")
		step(m2, 3.3, BLOCKED)
		local reopen = step(m2, 5, NEAR)
		T.eq(reopen.kind, "opening")
		T.ok(near(reopen.from, 0.5))
	end)

	T.test("opening + solid obstruction: holds part-way; resumes toward open or closed once clear", function()
		local m = oneDoor()
		step(m, 0, NEAR)
		local held = step(m, 0.3, NEAR_BLOCKED)
		T.eq(held.kind, "held")
		T.ok(near(held.progress, 0.5))
		T.ok(near(m:state("d1", 5).progress, 0.5), "stays put while held")
		T.eq(step(m, 6, NEAR).kind, "opening")
		local m2 = oneDoor()
		step(m2, 0, NEAR); step(m2, 0.3, NEAR_BLOCKED)
		local back = step(m2, 1, CLEAR)
		T.eq(back.kind, "closing", "nobody wants it open: close from where it stopped")
		T.ok(near(back.from, 0.5) and near(back.duration, 0.3))
	end)

	T.test("closed doors: a solid obstruction holds them shut even if someone is near; collision returns only when clear", function()
		local m = oneDoor()
		T.eq(step(m, 0, NEAR_BLOCKED), nil, "furniture in the sweep: stay shut, don't slice through it")
		T.eq(m:state("d1").phase, "closed")
		T.eq(step(m, 1, NEAR).kind, "opening", "opens once the sweep is free")
		local snap = m:reset("d1", 2)
		T.eq(snap.kind, "snapClosed")
		T.eq(m:state("d1").collidable, false)
		T.eq(step(m, 2.1, OCCUPIED), nil, "an avatar is in the doorway: no collision yet")
		T.eq(step(m, 2.2, BLOCKED), nil)
		T.deepEq(step(m, 2.3, CLEAR), { kind = "collision", id = "d1", token = snap.token, collide = true })
		T.eq(step(m, 2.4, CLEAR), nil, "only once")
	end)

	T.test("malformed or missing input holds in every phase: never opens, closes, reverses or restores collision", function()
		for _, phase in ipairs({ "closed", "opening", "open", "closing", "held" }) do
			for _, bad in ipairs(MALFORMED) do
				local m, t = at(phase)
				if phase == "closed" then
					m:reset("d1", t) -- closed collision off, waiting for a clear doorway
				end
				local before = m:state("d1", t)
				local e = step(m, t, bad.value)
				local label = phase .. " / " .. bad.name
				if phase == "opening" or phase == "closing" then
					T.eq(e and e.kind, "held", label .. ": a moving leaf stops")
				else
					T.eq(e, nil, label .. ": nothing happens")
				end
				local after = m:state("d1", t + 10)
				T.ok(near(after.progress, before.progress), label .. ": no movement")
				T.eq(after.collidable, false, label .. ": no collision restored")
				-- Still unknown much later: still no motion, and an open door never starts closing.
				for k = 1, 5 do
					local later = step(m, t + 3 * k, bad.value)
					T.eq(later, nil, label .. " later")
				end
				T.ok(near(m:state("d1").progress, before.progress), label .. ": still put")
			end
		end
	end)

	T.test("tokens are never reused, even when an id is removed and added again (undo / reconcile)", function()
		local m = oneDoor()
		local first = step(m, 0, NEAR)
		T.eq(m:remove("d1"), true)
		T.eq(m:add("d1"), true)
		local second = step(m, 0.1, NEAR)
		T.ok(second.token ~= first.token, "a new registration gets new tokens")
		T.eq(m:complete("d1", first.token, 0.2), nil, "the old registration's callback is ignored")
		T.eq(m:state("d1", 0.2).phase, "opening", "the replacement is not marked open")
		T.ok(near(m:state("d1", 0.2).progress, 1 / 6))
		-- Reset, remove and re-add in a reconcile-like sequence: every old token stays dead.
		local tokens = { first.token, second.token }
		tokens[#tokens + 1] = m:reset("d1", 0.3).token
		local third = step(m, 0.4, NEAR)
		tokens[#tokens + 1] = third.token
		m:remove("d1"); m:add("d1")
		tokens[#tokens + 1] = m:reset("d1", 0.5).token
		local fourth = step(m, 0.6, NEAR)
		local seen = {}
		for _, tk in ipairs(tokens) do
			T.eq(seen[tk], nil, "token " .. tk .. " reused")
			seen[tk] = true
			T.ok(tk ~= fourth.token)
			T.eq(m:complete("d1", tk, 0.7), nil, "old token " .. tk .. " ignored")
		end
		T.eq(m:state("d1").phase, "opening")
		T.eq(m:complete("d1", fourth.token, 0.7).kind, "opened", "only the live motion completes")
		-- Tokens are unique across doors too.
		local many = DoorAutoOpen.new()
		many:add("a"); many:add("b")
		local ev = many:update(0, { a = NEAR, b = NEAR })
		T.ok(ev[1].token ~= ev[2].token)
		T.eq(many:complete("b", ev[1].token, 0.1), nil, "a's token can't complete b")
	end)

	T.test("stale completions within one registration: reversal, hold and reset invalidate callbacks", function()
		local m = oneDoor()
		local opening = step(m, 0, NEAR)
		step(m, 0.6, NEAR); step(m, 1, CLEAR)
		local closing = step(m, 3, CLEAR)
		T.eq(m:complete("d1", opening.token, 3.1), nil, "an old opening callback is ignored")
		T.eq(m:state("d1").phase, "closing")
		local reopen = step(m, 3.3, OCCUPIED)
		T.eq(m:complete("d1", closing.token, 3.4), nil, "the reversed closing callback is ignored")
		T.deepEq(m:complete("d1", reopen.token, 3.4), { kind = "opened", id = "d1", token = reopen.token })
		T.eq(m:complete("d1", reopen.token, 3.5), nil, "a finished motion can't complete twice")
		step(m, 3.6, CLEAR)
		local c2 = step(m, 5.6, CLEAR)
		local held = step(m, 5.7, BLOCKED)
		T.eq(m:complete("d1", c2.token, 5.8), nil, "a held motion's callback is ignored")
		T.eq(m:complete("d1", held.token, 5.8), nil, "held has no motion to complete")
		local resumed = step(m, 6, CLEAR)
		m:reset("d1", 6.1)
		T.eq(m:complete("d1", resumed.token, 6.2), nil, "reset kills the in-flight callback")
		local s = m:state("d1")
		T.eq(s.phase, "closed"); T.eq(s.progress, 0); T.eq(s.collidable, false)
		-- A tween completion closing the door does not restore collision by itself.
		local o = step(m, 7, NEAR); m:complete("d1", o.token, 7.6)
		step(m, 8, CLEAR); local c3 = step(m, 10, CLEAR)
		T.eq(m:complete("d1", c3.token, 10.6).collide, false)
		T.eq(step(m, 10.7, CLEAR).kind, "collision")
		local o2 = step(m, 11, NEAR)
		T.eq(m:remove("d1"), true)
		T.eq(m:complete("d1", o2.token, 11.1), nil)
		T.deepEq(m:update(12, { d1 = NEAR }), {})
		T.eq(m:state("d1"), nil)
		T.eq(select(2, m:reset("d1", 13)), Codes.Unknown)
	end)

	T.test("clock: no transition or stored motion before the first valid time; invalid times never move a door", function()
		for _, bad in ipairs({ 0 / 0, math.huge, -math.huge, "1" }) do
			local m = oneDoor()
			T.deepEq(m:update(bad, { d1 = NEAR }), {}, "no event on an invalid first clock")
			T.deepEq(m:update(nil, { d1 = NEAR }), {}, "nor on nil")
			local s = m:state("d1")
			T.eq(s.phase, "closed"); T.eq(s.progress, 0)
			T.eq(m.now, nil, "no clock stored")
			-- reset is allowed (no motion is stored) and complete has nothing to finish.
			T.eq(m:reset("d1", bad).kind, "snapClosed")
			T.eq(m:complete("d1", s.token, bad), nil)
			T.eq(m.now, nil)
			-- Recovery on the first valid time.
			local e = step(m, 5, NEAR)
			T.eq(e.kind, "opening")
			T.ok(near(m:state("d1", 5.3).progress, 0.5), "motion timed from the valid clock")
			T.deepEq(m:update(bad, { d1 = NEAR }), {}, "an invalid time later is a no-op")
			T.eq(step(m, 5.6, NEAR).kind, "opened")
		end
		local m = oneDoor()
		step(m, 10, NEAR)
		T.eq(step(m, 5, NEAR), nil, "an earlier time is clamped to the last one")
		T.ok(near(m:state("d1").progress, 0), "no progress from a backwards clock")
		T.eq(step(m, 10.6, NEAR).kind, "opened")
	end)

	T.test("bounded events: one per door per update, in insertion order; unknown ids ignored", function()
		local m = DoorAutoOpen.new()
		local inputs = { ghost = NEAR }
		for i = 1, 150 do
			local id = "i" .. i
			T.eq(m:add(id), true)
			inputs[id] = NEAR
		end
		T.eq(select(2, m:add("i151")), Codes.TooMany)
		local events = m:update(0, inputs)
		T.eq(#events, 150)
		for i, e in ipairs(events) do
			T.eq(e.id, "i" .. i, "insertion order")
			T.eq(e.kind, "opening")
		end
		T.eq(#m:update(0.1, inputs), 0, "nothing new mid-swing")
		T.eq(#m:update(0.6, inputs), 150, "all finish together")
		T.deepEq(m:update(1, "inputs"), {}, "non-table inputs: every door unknown, nothing moves")
	end)

	T.test("holdAt: rebases onto an applied progress, held with collision off; invalidates tokens; needs no clock; rejects bad input", function()
		local m = oneDoor()
		local opening = step(m, 0, NEAR)
		local held = m:holdAt("d1", 0.25, 0.3)
		T.eq(held.kind, "held"); T.eq(held.progress, 0.25)
		local s = m:state("d1", 5)
		T.eq(s.phase, "held"); T.eq(s.progress, 0.25); T.eq(s.collidable, false)
		T.eq(m:complete("d1", opening.token, 0.4), nil, "the old motion can't complete")
		T.eq(step(m, 1, BLOCKED), nil, "held while blocked")
		local resume = step(m, 2, NEAR)
		T.eq(resume.kind, "opening"); T.ok(near(resume.from, 0.25), "resumes from the applied position")
		T.eq(m:holdAt("d1", 2, 3).progress, 1, "clamped")
		T.eq(m:holdAt("d1", -1, 3).progress, 0)
		T.eq(m:holdAt("d1", 0 / 0, 3), nil)
		T.eq(m:holdAt("ghost", 0.5, 3), nil)
		local fresh = oneDoor()
		T.eq(fresh:holdAt("d1", 0.5, nil).kind, "held", "works before any valid clock")
		T.eq(fresh.now, nil, "and stores none")
	end)
end
