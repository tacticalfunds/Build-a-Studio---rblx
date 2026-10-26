-- Panel door foundation: the pure auto-open state machine (DoorAutoOpen),
-- driven by a fake clock and hand-built adapter inputs. Nothing here is
-- wired live; the runtime adapters are a later checkpoint.
return function(T, H)
	local DoorAutoOpen = H.load("src/server/Core/DoorAutoOpen")
	local Codes = DoorAutoOpen.Codes

	local CLEAR = { nearby = false, occupied = false, blocked = false }
	local NEAR = { nearby = true, occupied = false, blocked = false }
	local OCCUPIED = { nearby = false, occupied = true, blocked = false }
	local BLOCKED = { nearby = false, occupied = false, blocked = true }
	local NEAR_BLOCKED = { nearby = true, occupied = false, blocked = true }

	local function oneDoor()
		local m = DoorAutoOpen.new()
		T.eq(m:add("d1"), true)
		return m
	end
	local function step(m, now, input)
		local events = m:update(now, { d1 = input })
		T.ok(#events <= 1, "at most one event per door")
		return events[1]
	end
	local function near(a, b) return math.abs(a - b) < 1e-9 end

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
		T.deepEq(m:state("a"), { phase = "closed", progress = 0, collidable = true, token = 0 })
	end)

	T.test("proximity: opens with collision off, progresses by the clock, finishes open", function()
		local m = oneDoor()
		T.eq(step(m, 0, CLEAR), nil, "nothing to do while clear")
		local e = step(m, 1, NEAR)
		T.deepEq(e, { kind = "opening", id = "d1", token = 1, from = 0, to = 1, duration = 0.6 })
		T.eq(m:state("d1").collidable, false, "collision off while moving")
		T.ok(near(m:state("d1", 1.3).progress, 0.5))
		T.eq(step(m, 1.3, NEAR), nil)
		T.deepEq(step(m, 1.6, NEAR), { kind = "opened", id = "d1", token = 1 })
		T.eq(m:state("d1").phase, "open")
		T.eq(m:state("d1").collidable, false)
	end)

	T.test("exit delay: closes only after being clear for exitDelay; any presence restarts the wait", function()
		local m = oneDoor()
		step(m, 0, NEAR); step(m, 0.6, NEAR)
		T.eq(step(m, 1, CLEAR), nil, "clear timer starts")
		T.eq(step(m, 2.9, CLEAR), nil, "not yet")
		T.eq(step(m, 3.5, NEAR), nil, "someone came back")
		T.eq(step(m, 4, CLEAR), nil, "timer restarts")
		T.eq(step(m, 5.9, CLEAR), nil)
		local e = step(m, 6, CLEAR)
		T.eq(e.kind, "closing")
		T.eq(e.token, 2)
		T.ok(near(e.duration, 0.6))
		T.deepEq(step(m, 6.6, CLEAR), { kind = "closed", id = "d1", token = 2, collide = true }, "closes clear, so collision returns")
		T.eq(m:state("d1").collidable, true)
	end)

	T.test("hold open: occupied or blocked keeps an open door open indefinitely", function()
		for _, input in ipairs({ OCCUPIED, BLOCKED }) do
			local m = oneDoor()
			step(m, 0, NEAR); step(m, 0.6, NEAR)
			for t = 1, 60 do
				T.eq(step(m, t, input), nil, "held at " .. t)
			end
			T.eq(m:state("d1").phase, "open")
			T.eq(step(m, 61, CLEAR), nil)
			T.eq(step(m, 63, CLEAR).kind, "closing", "closes once clear for the delay")
		end
	end)

	T.test("obstruction during closing: an avatar, a solid obstruction or a returning player reopens from where it is", function()
		for _, input in ipairs({ OCCUPIED, BLOCKED, NEAR }) do
			local m = oneDoor()
			step(m, 0, NEAR); step(m, 0.6, NEAR); step(m, 1, CLEAR)
			T.eq(step(m, 3, CLEAR).kind, "closing")
			local e = step(m, 3.3, input) -- half-way closed
			T.eq(e.kind, "opening")
			T.ok(near(e.from, 0.5) and near(e.duration, 0.3), "reverses from 0.5 for the remaining 0.3 s")
			T.eq(m:state("d1").collidable, false, "never collides mid-swing")
			T.eq(step(m, 3.6, input).kind, "opened")
		end
	end)

	T.test("closed doors: a solid obstruction holds them shut even if someone is near; collision returns only when clear", function()
		local m = oneDoor()
		T.eq(step(m, 0, NEAR_BLOCKED), nil, "furniture in the sweep: stay shut, don't slice through it")
		T.eq(m:state("d1").phase, "closed")
		T.eq(step(m, 1, NEAR).kind, "opening", "opens once the sweep is free")
		-- After a snap reset the closed collision waits for a clear doorway.
		local snap = m:reset("d1", 2)
		T.deepEq(snap, { kind = "snapClosed", id = "d1", token = 2 })
		T.eq(m:state("d1").collidable, false)
		T.eq(step(m, 2.1, OCCUPIED), nil, "an avatar is in the doorway: no collision yet")
		T.eq(step(m, 2.2, BLOCKED), nil)
		T.deepEq(step(m, 2.3, CLEAR), { kind = "collision", id = "d1", token = 2, collide = true })
		T.eq(step(m, 2.4, CLEAR), nil, "only once")
	end)

	T.test("held: a solid obstruction stops an opening leaf part-way; it resumes toward open or closed once free", function()
		local m = oneDoor()
		step(m, 0, NEAR)
		local held = step(m, 0.3, NEAR_BLOCKED)
		T.eq(held.kind, "held")
		T.ok(near(held.progress, 0.5))
		T.eq(held.token, 2, "a hold invalidates the running motion")
		T.ok(near(m:state("d1", 5).progress, 0.5), "stays put while held")
		T.eq(step(m, 5, BLOCKED), nil)
		local resume = step(m, 6, NEAR)
		T.eq(resume.kind, "opening")
		T.ok(near(resume.from, 0.5))
		local m2 = oneDoor()
		step(m2, 0, NEAR); step(m2, 0.3, NEAR_BLOCKED)
		local back = step(m2, 1, CLEAR)
		T.eq(back.kind, "closing", "nobody wants it open: close from where it stopped")
		T.ok(near(back.from, 0.5) and near(back.duration, 0.3))
	end)

	T.test("missing or malformed inputs hold still: no motion on data the adapter did not supply", function()
		local m = oneDoor()
		T.eq(step(m, 0, nil), nil, "closed stays closed")
		T.eq(step(m, 1, "near"), nil)
		step(m, 2, NEAR); step(m, 2.6, NEAR)
		for t = 3, 20 do
			T.eq(step(m, t, nil), nil, "open stays open")
		end
		T.eq(step(m, 21, { nearby = true }), nil, "blocked omitted counts as blocked")
		T.deepEq(m:update(22, "inputs"), {}, "non-table inputs")
	end)

	T.test("stale completions: only the current motion's token can finish it; reset and remove invalidate", function()
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
		-- Reset mid-motion: the in-flight callback is dead.
		step(m, 3.6, CLEAR)
		local c2 = step(m, 5.6, CLEAR)
		T.eq(c2.kind, "closing")
		m:reset("d1", 5.7)
		T.eq(m:complete("d1", c2.token, 5.8), nil)
		T.deepEq(m:state("d1"), { phase = "closed", progress = 0, collidable = false, token = c2.token + 1 })
		-- A tween completion closing the door does not restore collision by itself.
		local o = step(m, 6, NEAR); m:complete("d1", o.token, 6.6)
		step(m, 7, CLEAR); local c3 = step(m, 9, CLEAR)
		T.deepEq(m:complete("d1", c3.token, 9.6), { kind = "closed", id = "d1", token = c3.token, collide = false })
		T.eq(step(m, 9.7, CLEAR).kind, "collision")
		-- Remove: callbacks and updates no longer see it.
		local o2 = step(m, 10, NEAR)
		T.eq(m:remove("d1"), true)
		T.eq(m:complete("d1", o2.token, 10.1), nil)
		T.deepEq(m:update(11, { d1 = NEAR }), {})
		T.eq(m:state("d1"), nil)
		T.eq(select(2, m:reset("d1", 12)), Codes.Unknown)
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
	end)

	T.test("clock: non-finite or backwards time never moves a door backwards", function()
		local m = oneDoor()
		step(m, 10, NEAR)
		T.ok(near(m:state("d1", 10.3).progress, 0.5))
		T.eq(step(m, 5, NEAR), nil, "earlier time is clamped to the last one")
		T.ok(near(m:state("d1").progress, 0), "no progress from a backwards clock")
		T.eq(step(m, 0 / 0, NEAR), nil)
		T.eq(step(m, math.huge, NEAR), nil)
		T.eq(step(m, 10.6, NEAR).kind, "opened")
	end)
end
