extends Node
## The editor must be able to say exactly where a board breaks: what the flow
## reaches, where it gets out of the board, and where it is lost.
##
## A flow goes from a part into the part beside it and no further, and the one
## place it becomes an attack is the way out: the middle of the board's right
## edge. There is no OUTPUT part — see `SkillBoard.follow`. And the root, where
## the flow starts, is moved and turned like any part, but never taken off.
var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[TRACE] PASS ", what)
	else:
		fails += 1
		push_error("TRACE FAIL: " + what)

func _ready() -> void:
	# A flow entering a part from the side it does not point at is fine now:
	# the arrow says where flow leaves, nothing says where it may come from.
	var b := SkillBoard.new(7, 5, "sideways")
	b.set_root("BRIDGE", Vector2i(3, 2), 1)      # south
	b.place("OVERCLOCK", Vector2i(3, 3), 0)      # entered from the north, leaves east
	b.place("OVERCLOCK", Vector2i(4, 3), 3)      # entered from the west, leaves north
	b.place("OVERCLOCK", Vector2i(4, 2), 0)      # entered from the south, leaves east
	b.place("SLASH", Vector2i(5, 2), 0)
	b.place("BRIDGE", Vector2i(6, 2), 0)         # against the way out
	var t := b.trace()
	check((t["breaks"] as Array).is_empty(), "turning a corner through any part is a valid join")
	check(t["reachable"].size() == 6, "the whole snaking chain is live (%d)" % t["reachable"].size())
	check((t["leaks"] as Array).is_empty(), "and none of it runs out anywhere")
	check(bool(t["gets_out"]) and (t["outs"] as Array).size() == 1,
		"it gets out, by the one way there is")
	var sim := SkillRunner.new(b)
	sim.base_payload_provider = func() -> Payload: return Weapons.base_payload("SWORD")
	check((sim.simulate()["outputs"] as Array).size() == 1, "it produces an attack")

	# --- the way out ----------------------------------------------------------
	# The middle of the right edge, on every grid a Workbench grows — of an even
	# number of rows, the upper of the two in the middle.
	var outs_at := {}
	for size in [Vector2i(7, 5), Vector2i(8, 6), Vector2i(9, 7), Vector2i(10, 8), Vector2i(11, 9)]:
		outs_at[size] = SkillBoard.new(size.x, size.y).way_out()
	check(outs_at[Vector2i(7, 5)] == Vector2i(6, 2) and outs_at[Vector2i(8, 6)] == Vector2i(7, 2)
			and outs_at[Vector2i(9, 7)] == Vector2i(8, 3) and outs_at[Vector2i(10, 8)] == Vector2i(9, 3)
			and outs_at[Vector2i(11, 9)] == Vector2i(10, 4),
		"the way out is the middle of the right edge (%s)" % str(outs_at))
	# A root standing against it fires on its own, which is how a weapon nobody
	# has built on fires.
	var bare := SkillBoard.new(7, 5, "bare")
	bare.set_root("SLASH", Vector2i(6, 2))
	var tb0 := bare.trace()
	check(bool(tb0["gets_out"]) and (tb0["leaks"] as Array).is_empty() and (tb0["breaks"] as Array).is_empty(),
		"a root against the way out gets out")
	var bare_run := SkillRunner.new(bare)
	bare_run.base_payload_provider = func() -> Payload: return Weapons.base_payload("SWORD")
	var bare_sim := bare_run.simulate()
	check((bare_sim["outputs"] as Array).size() == 1 and not bool(bare_sim["expired"]),
		"and is an attack: going out costs no life, so the root's one pass is enough")
	# Anywhere else, an empty cell carries nothing: the flow goes into the cell
	# beside it and stops there.
	var far := SkillBoard.new(7, 5, "far")
	far.set_root("SLASH")
	var tf := far.trace()
	var lk0: Dictionary = (tf["leaks"] as Array)[0] if not (tf["leaks"] as Array).is_empty() else {}
	check(not bool(tf["gets_out"]) and (tf["leaks"] as Array).size() == 1
			and lk0.get("from") == SkillBoard.ROOT and int(lk0.get("dir", -1)) == Components.E
			and String(lk0.get("why", "")) == "empty",
		"a root across the board from it leaks into the empty cell beside it (%s)" % str(lk0))
	var far_run := SkillRunner.new(far)
	far_run.base_payload_provider = func() -> Payload: return Weapons.base_payload("SWORD")
	check((far_run.simulate()["outputs"] as Array).is_empty(), "and fires nothing")
	# A chain one cell short is a leak at its end; the last part makes it whole.
	for x in range(1, 6):
		far.place("BRIDGE", Vector2i(x, 2), 0)
	var short_of := far.trace()
	check(not bool(short_of["gets_out"]) and (short_of["leaks"] as Array).size() == 1
			and (short_of["leaks"] as Array)[0].get("from") == Vector2i(5, 2),
		"a chain that stops a cell short leaks there")
	far.place("BRIDGE", Vector2i(6, 2), 0)
	check(bool(far.trace()["gets_out"]) and (far.trace()["leaks"] as Array).is_empty(),
		"and reaches the way out once the cell is filled")
	# Any other edge is not a way out — another row's end of the right edge
	# included — and a flow off one is a leak.
	var above := SkillBoard.new(7, 5, "above")
	above.set_root("SLASH", Vector2i(6, 1))
	var ta := above.trace()
	var lk1: Dictionary = (ta["leaks"] as Array)[0] if not (ta["leaks"] as Array).is_empty() else {}
	check(not bool(ta["gets_out"]) and String(lk1.get("why", "")) == "edge",
		"a flow off the right edge a row from the middle runs off the board (%s)" % str(lk1))
	var down := SkillBoard.new(7, 5, "down")
	down.set_root("SLASH", Vector2i(6, 2), 1)    # against the way out, but turned south
	check(not bool(down.trace()["gets_out"]), "and one turned away from the way out does not get out by it")

	# Two outputs pointed at each other is the one join that cannot carry flow.
	var h := SkillBoard.new(7, 5, "headon")
	h.set_root("BRIDGE")
	h.place("BRIDGE", Vector2i(1, 2), 2)         # points back west at the root
	var th := h.trace()
	check((th["breaks"] as Array).size() == 1, "outputs meeting head-on is a break")
	var hb: Dictionary = (th["breaks"] as Array)[0] if not (th["breaks"] as Array).is_empty() else {}
	# The break is named at the part that would not take the flow — the BRIDGE
	# turned back on the root — not at the one that sent it.
	check(String(hb.get("id", "")) == "BRIDGE" and hb.get("to") == Vector2i(1, 2)
			and String(hb.get("why", "")) == "facing",
		"and it is reported at the part that turned the flow back (%s)" % str(hb))

	# The root is a part like any other, so a flow may run back into it — and a
	# ring through it with no way out is dead code like any other ring.
	var fb := SkillBoard.new(7, 5, "feedback")
	fb.set_root("BRIDGE", Vector2i(1, 2), 0)
	fb.place("BRIDGE", Vector2i(2, 2), 1)
	fb.place("BRIDGE", Vector2i(2, 3), 2)
	fb.place("BRIDGE", Vector2i(1, 3), 3)        # points north, back into the root
	var ti := fb.trace()
	check((ti["breaks"] as Array).is_empty() and ti["reachable"].size() == 4,
		"a flow aimed back at the root is taken: the root feeds on any side but its own output")
	check((ti["dead"] as Dictionary).size() == 4,
		"and a ring closed on it with no way out is dead code, root included")

	# A ring must not run forever: a pulse gets a hop budget.
	var r := SkillBoard.new(7, 5, "ring")
	r.set_root("BRIDGE", Vector2i(0, 0), 0)     # feeds east into the ring
	r.place("BRIDGE", Vector2i(1, 0), 0)         # east
	r.place("BRIDGE", Vector2i(2, 0), 1)         # south
	r.place("BRIDGE", Vector2i(2, 1), 2)         # west
	r.place("BRIDGE", Vector2i(1, 1), 3)         # north, closing the ring
	var tr := r.trace()
	check((tr["breaks"] as Array).is_empty(), "a ring is a legal board")
	check(tr["reachable"].size() == 5, "the whole ring is reachable")
	var runner := SkillRunner.new(r)
	runner.base_payload_provider = func() -> Payload: return Weapons.base_payload("SWORD")
	# Charged, so the ring is given real life to burn through rather than the
	# single pass an uncharged cast is worth.
	runner.ttl_bonus = 40
	runner.set_active(true)
	runner._tick()                               # starts the cycle
	check(not runner.is_idle(), "the ring pulse is in flight")
	var ticks := 1
	while ticks < 4000 and not runner.is_idle():
		runner._tick()
		ticks += 1
	check(runner.is_idle(), "the circulating pulse burns out (%d ticks)" % ticks)
	check(ticks > 4, "but not immediately — it really did circulate")
	# And the board recovers: the next cycle starts normally afterwards.
	var restarted := false
	for i in 200:
		runner._tick()
		if not runner.is_idle():
			restarted = true
			break
	check(restarted, "the board starts a fresh cycle after a ring burns out")

	# The budget counts re-entries into a part, and it is the same budget the
	# workbench previews with. A looping board therefore has to run at the cycle
	# time and follow-ups the preview promised: when the runner counted total
	# distance travelled instead, a ring held the cycle open for dozens of ticks
	# with the root stuck behind it, and the board fired once where the preview
	# said four.
	var lp := SkillBoard.new(7, 5, "loop")
	lp.set_root("BRIDGE", Vector2i(3, 2))
	lp.place("BRIDGE", Vector2i(4, 2), 0)
	lp.place("ON_HIT", Vector2i(5, 2), 0)   # on to the attack, and its branch round the ring
	lp.place("SLASH", Vector2i(6, 2), 0)    # east, and out
	lp.place("BRIDGE", Vector2i(5, 3), 2)
	lp.place("BRIDGE", Vector2i(4, 3), 3)   # north, back into the first BRIDGE
	var lr := SkillRunner.new(lp)
	lr.base_payload_provider = func() -> Payload: return Weapons.base_payload("SWORD")
	# An uncharged cast is worth one pass, so the laps this is checking are
	# bought the way a player buys them: by holding the cast button.
	lr.ttl_bonus = 32
	var pred := lr.simulate()
	var predicted := float(pred["cycle_seconds"])
	var want_shots: int = (pred["outputs"] as Array).size()
	var want_after := 0
	var promised = (pred["triggers"] as Dictionary).get("ON_HIT", null)
	while promised != null:
		want_after += 1
		promised = promised.on_hit
	check(want_shots == 1 and want_after > 1,
		"the ring previews one attack a cycle with a follow-up a lap (%d, %d)" % [want_shots, want_after])
	var cycles := [0]
	var shots := [0]
	var whole := [0]   # shots banked at the last cycle boundary, so no partial cycle
	var carried: Array = []
	lr.cycle_started.connect(func() -> void:
		cycles[0] += 1
		whole[0] = shots[0])
	lr.fired.connect(func(fp: Payload) -> void:
		shots[0] += 1
		var n := 0
		var q = fp.on_hit
		while q != null:
			n += 1
			q = q.on_hit
		carried.append(n))
	lr.set_active(true)
	var step := 1.0 / 240.0
	var elapsed := 0.0
	while elapsed < predicted * 5.0:
		lr.update(step)
		elapsed += step
	var measured := elapsed / float(maxi(cycles[0], 1))
	check(absf(measured - predicted) < predicted * 0.2,
		"a looping board runs at the cycle the preview promised (%.2fs vs %.2fs)" % [measured, predicted])
	var per_cycle := float(whole[0]) / float(maxi(cycles[0] - 1, 1))
	check(absf(per_cycle - float(want_shots)) < 0.5,
		"and fires as many shots as it promised (%.1f vs %d)" % [per_cycle, want_shots])
	check(not carried.is_empty() and carried.all(func(n: int) -> bool: return n == want_after),
		"each carrying the follow-ups it promised (%s, want %d)" % [str(carried), want_after])

	# --- loops the flow can never leave ----------------------------------------
	# The board from the report: a trigger feeding a four-part ring that never
	# hands the flow back. Every part of the ring is dead code; nothing outside
	# it is — the root is doing its job, and the SLASH stranded past it is
	# unreached rather than caught.
	var dl := SkillBoard.new(7, 5, "deadloop")
	dl.set_root("BRIDGE")
	dl.place("DUPLICATE", Vector2i(1, 2), 3)     # in from the west, out north
	dl.place("FIRE", Vector2i(1, 1), 0)          # east
	dl.place("DAMAGE", Vector2i(2, 1), 1)        # south
	dl.place("FIRE", Vector2i(2, 2), 2)          # west, closing the ring
	dl.place("SLASH", Vector2i(3, 2), 0)
	var td := dl.trace()
	var caught: Dictionary = td["dead"]
	check(caught.size() == 4, "every part of a ring with no way out is dead code (%d)"
		% caught.size())
	check(not caught.has(Vector2i(0, 2)) and not caught.has(Vector2i(3, 2)),
		"and neither the root feeding it nor the part it never reaches is")
	check((td["dead_links"] as Array).size() == 4,
		"the ring's own seams come back with it, so one silhouette can go round it")
	var trapped := false
	for origin in td["reachable"]:
		if caught.has(origin):
			trapped = true
	check(trapped and not bool(td["gets_out"]),
		"and the flow runs into the trap, so nothing comes out")

	# The same ring with nothing feeding it: a trap is a trap before anything
	# falls into it, so this is marked too.
	var orphan := SkillBoard.new(7, 5, "orphan")
	orphan.place("BRIDGE", Vector2i(1, 0), 0)
	orphan.place("BRIDGE", Vector2i(2, 0), 1)
	orphan.place("BRIDGE", Vector2i(2, 1), 2)
	orphan.place("BRIDGE", Vector2i(1, 1), 3)
	check((orphan.trace()["dead"] as Dictionary).size() == 4,
		"a ring with nothing feeding it is dead code all the same")
	check((tr["dead"] as Dictionary).size() == 4, "and so is the one the root feeds")

	# The ring that pays for itself is left alone. A trigger's branch lapping the
	# stat parts, a follow-up a lap, is the pattern charging a skill exists to
	# buy, and calling it dead code would be calling the game dead code.
	check((lp.trace()["dead"] as Dictionary).is_empty(),
		"a ring with a way out of it is not dead code")
	check((b.trace()["dead"] as Dictionary).is_empty(), "and neither is a plain chain")
	# Nor is a ring one of whose own parts sends its flow out of the board, with
	# no part between: every part of it leads to every other, and it is still the
	# way out. The dragon test's board is this shape.
	var lo := SkillBoard.new(7, 5, "leaves")
	lo.set_root("SLASH", Vector2i(5, 2))
	lo.place("ON_HIT", Vector2i(6, 2), 0)        # east and out, and its branch south round the ring
	lo.place("BRIDGE", Vector2i(6, 3), 2)
	lo.place("BRIDGE", Vector2i(5, 3), 3)        # north, back into the root
	var tlo := lo.trace()
	check((tlo["dead"] as Dictionary).is_empty() and bool(tlo["gets_out"]),
		"a ring that lets its flow out of the board itself is not dead code either")
	# The same ring a cell further in, its ON HIT sending into a part that will
	# not take it, is.
	var shut := SkillBoard.new(7, 5, "shut")
	shut.set_root("SLASH", Vector2i(4, 2))
	shut.place("ON_HIT", Vector2i(5, 2), 0)
	shut.place("BRIDGE", Vector2i(5, 3), 2)
	shut.place("BRIDGE", Vector2i(4, 3), 3)
	shut.place("BRIDGE", Vector2i(6, 2), 2)      # facing back at the ON HIT
	check((shut.trace()["dead"] as Dictionary).size() == 4,
		"but one with its way out shut is")

	# Nor is a ring whose work is done on the way in rather than by sending a
	# flow out: trapped or not, it dilates time once a lap for as long as the
	# life lasts.
	var spin := SkillBoard.new(7, 5, "dilate")
	spin.set_root("BRIDGE", Vector2i(0, 0), 0)
	spin.place("BRIDGE", Vector2i(1, 0), 0)
	spin.place("TIME_DILATION", Vector2i(2, 0), 1)
	spin.place("BRIDGE", Vector2i(2, 1), 2)
	spin.place("BRIDGE", Vector2i(1, 1), 3)
	check((spin.trace()["dead"] as Dictionary).is_empty(),
		"a ring with TIME DILATION in it is doing something every lap, not nothing")

	# A loop through a trigger's branch queues one follow-up per lap. It used to
	# overwrite a single stored payload instead, so four laps through four
	# DAMAGE parts collapsed into one enormous strike rather than the four
	# separate attacks the board draws.
	var tb := SkillBoard.new(7, 5, "trigger loop")
	tb.set_root("BRIDGE", Vector2i(3, 2))
	tb.place("DASHSLASH", Vector2i(4, 2), 0)
	tb.place("BRIDGE", Vector2i(5, 2), 0)
	tb.place("ON_HIT", Vector2i(6, 2), 0)      # onward E and out, branch S
	tb.place("DAMAGE", Vector2i(6, 3), 1)
	tb.place("DAMAGE", Vector2i(6, 4), 2)
	tb.place("BRIDGE", Vector2i(5, 4), 2)
	tb.place("DAMAGE", Vector2i(4, 4), 3)
	tb.place("DAMAGE", Vector2i(4, 3), 3)      # back into the DASHSLASH
	var tr2 := SkillRunner.new(tb)
	tr2.base_payload_provider = func() -> Payload: return Weapons.base_payload("SWORD")
	tr2.ttl_bonus = 48   # charged, so the branch goes round more than once
	var tsim := tr2.simulate()
	var chain: Array = []
	var link = (tsim["triggers"] as Dictionary).get("ON_HIT", null)
	while link != null:
		chain.append(link)
		link = link.on_hit
	check(chain.size() > 1, "each lap queues its own follow-up (%d)" % chain.size())
	# And the life the pulse carries is the only thing that bounds the chain:
	# the same board charged less queues fewer follow-ups.
	var chain_at := func(bonus: int) -> int:
		var rr := SkillRunner.new(tb)
		rr.base_payload_provider = func() -> Payload: return Weapons.base_payload("SWORD")
		rr.ttl_bonus = bonus
		var n := 0
		var l = (rr.simulate()["triggers"] as Dictionary).get("ON_HIT", null)
		while l != null:
			n += 1
			l = l.on_hit
		return n
	var short_chain: int = chain_at.call(12)
	check(short_chain < chain.size(),
		"and life is what bounds it: +12 queues %d, +48 queues %d"
			% [short_chain, chain.size()])
	var rising := true
	for i in range(1, chain.size()):
		if chain[i].damage <= chain[i - 1].damage:
			rising = false
	check(rising, "and each carries only its own lap's damage, not every lap's")
	check(not chain.is_empty() and String(chain[0].form) == "DASHSLASH",
		"the follow-up is the attack the loop runs through")

	# The live runner has to hand out the same chain the preview showed, on the
	# very first attack — the branch that defines it is still walking the board
	# behind that attack, so it has to come from the board, not from history.
	var live: Array = []
	tr2.fired.connect(func(pp: Payload) -> void:
		if live.is_empty():
			var n := 0
			var q = pp.on_hit
			while q != null:
				n += 1
				q = q.on_hit
			live.append(n))
	tr2.set_active(true)
	for i in 400:
		tr2.update(1.0 / 120.0)
	check(not live.is_empty() and int(live[0]) == chain.size(),
		"the first attack already carries the whole chain (%s vs %d)"
			% [str(live), chain.size()])

	# A part two cells off is not reached at all: the flow leaks into the empty
	# cell between, and nothing carries it on.
	var d2 := SkillBoard.new(7, 5, "gap")
	d2.set_root("BRIDGE", Vector2i(1, 0), 1)    # south, down the column
	d2.place("NEAR", Vector2i(1, 2), 0)          # two cells down
	var td2 := d2.trace()
	check((td2["breaks"] as Array).is_empty() and (td2["leaks"] as Array).size() == 1
			and td2["reachable"].size() == 1,
		"a part across an empty cell is not reached: the flow leaks into the gap")

	# Nothing on the root at all.
	var f := SkillBoard.new(7, 5, "unrooted")
	f.place("SLASH", Vector2i(2, 2), 0)
	check(not bool(f.trace()["has_root"]),
		"a board with nothing on its root says so")

	# A wired board with no attack form reports that, not a wiring fault.
	var g := SkillBoard.new(7, 5, "noform")
	g.set_root("BRIDGE", Vector2i(5, 2))
	g.place("BRIDGE", Vector2i(6, 2), 0)
	var tg := g.trace()
	check(bool(tg["has_root"]) and bool(tg["gets_out"]) and (tg["breaks"] as Array).is_empty()
			and (tg["leaks"] as Array).is_empty() and g.compute_tags().is_empty(),
		"a formless chain is wired clean, and carries no attack form")
	var formless := SkillRunner.new(g)
	check((formless.simulate()["outputs"] as Array).is_empty(),
		"so what it lets out of the board is no attack")

	# --- the root ---------------------------------------------------------------
	# The one part the hand cannot take off the board, or drop something on.
	var w := SkillBoard.new(7, 5, "weapon")
	w.set_root("DASHSLASH")
	w.place("FIRE", Vector2i(1, 2), 0)
	check(w.erase_at(SkillBoard.ROOT) == "" and w.has_root(),
		"erasing the root leaves it standing")
	check(not w.can_place("FIRE", SkillBoard.ROOT, 0), "and nothing may be dropped on it")
	check(w.erase_at(Vector2i(1, 2)) == "FIRE", "while everything else comes off as it always did")
	check(w.used_components().is_empty(),
		"the root is the weapon's, so it is not among the parts the build is made of")
	# But it moves, and turns, like any part — never over another, and never off
	# the grid. Where it goes the flow starts.
	w.place("FIRE", Vector2i(2, 2), 0)
	check(not w.can_move_root(Vector2i(2, 2), 0) and not w.move_root(Vector2i(2, 2), 0)
			and w.root == SkillBoard.ROOT,
		"the root is not moved where it would cover another part")
	check(not w.move_root(Vector2i(7, 2), 0) and w.root == SkillBoard.ROOT,
		"nor off the grid")
	check(w.move_root(Vector2i(1, 2), 0) and w.root == Vector2i(1, 2)
			and w.comp_at(SkillBoard.ROOT).is_empty() and w.is_root(Vector2i(1, 2)),
		"it moves onto a free cell, and leaves the one it stood on empty")
	w.erase_at(Vector2i(2, 2))
	check(w.move_root(Vector2i(6, 2), 0) and bool(w.trace()["gets_out"]),
		"and against the way out its flow leaves the board")
	check(w.move_root(w.root, 1) and int(w.root_entry()["rot"]) == 1 and w.root == Vector2i(6, 2)
			and not bool(w.trace()["gets_out"]),
		"turned where it stands, its flow goes the way it faces now")

	# --- a board grown ----------------------------------------------------------
	# A Workbench grows the board round what is on it, so a build against the way
	# out stays against it: new columns come in on the left, new rows above or
	# below as the middle moves.
	var grown := SkillBoard.new(7, 5, "grown")
	grown.set_root("SLASH", Vector2i(5, 2))
	grown.place("DAMAGE", Vector2i(6, 2), 0)
	var still := true
	for level in range(2, 6):
		grown.resize_grid(6 + level, 4 + level)
		still = still and bool(grown.trace()["gets_out"]) \
			and grown.comp_at(grown.way_out()).get("id", "") == "DAMAGE" and grown.is_root(grown.root)
	check(still and grown.width == 11 and grown.height == 9 and grown.root == Vector2i(9, 4),
		"a build against the way out stays against it through every upgrade (%s, root at %s)"
			% [str(Vector2i(grown.width, grown.height)), str(grown.root)])

	print("[TRACE] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
