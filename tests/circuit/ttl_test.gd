extends Node
## Every pulse carries a time to live — how many more parts it may enter — which
## is what stops a cycle in the board looping forever. Charging buys more of it.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[TTL] PASS ", what)
	else:
		fails += 1
		push_error("TTL FAIL: " + what)

func runner(b: SkillBoard, bonus: int = 0) -> SkillRunner:
	var r := SkillRunner.new(b)
	r.base_payload_provider = func() -> Payload: return Weapons.base_payload("SWORD")
	r.ttl_bonus = bonus
	return r

## A straight run of `n` BRIDGEs into an attack, off a BRIDGE on the root, on a
## board exactly as long, so the SLASH is against the way out: no cycle, just
## length.
func chain(n: int) -> SkillBoard:
	var b := SkillBoard.new(n + 2, 5, "chain")
	b.set_root("BRIDGE")
	for i in n:
		b.place("BRIDGE", Vector2i(1 + i, 2), 0)
	b.place("SLASH", Vector2i(1 + n, 2), 0)
	return b

func shots(r: SkillRunner) -> int:
	return (r.simulate()["outputs"] as Array).size()

## SWIFT STRIKE on the root, an ON HIT whose branch walks two OVERCLOCKs back
## round into it, and AUTO-AIM on the way out — the dragon test's board — so
## every lap the life pays for is one more follow-up. The root takes flow like
## any other part, which is what closes the ring.
func trigger_ring() -> SkillBoard:
	var b := SkillBoard.new(7, 5, "trigger ring")
	b.set_root("DASHSLASH", Vector2i(4, 2))
	b.place("ON_HIT", Vector2i(5, 2), 0)
	b.place("AUTO_AIM", Vector2i(6, 2), 0)
	b.place("OVERCLOCK", Vector2i(5, 3), 2)
	b.place("OVERCLOCK", Vector2i(4, 3), 3)
	return b

## Attacks in a chain: the one fired, and every follow-up hung off it.
func links(p) -> int:
	var n := 0
	while p != null:
		n += 1
		p = p.on_hit
	return n

## One live cast at `bonus`, run to the end: how many attacks its chain holds.
func live_links(r: SkillRunner, bonus: int) -> int:
	r.ttl_bonus = bonus
	var got := [0]
	var count := func(p: Payload) -> void: got[0] = links(p)
	r.fired.connect(count)
	r.set_active(true)
	r.update(1.0 / 60.0)
	r.set_active(false)
	for i in 6000:
		if r.is_ready():
			break
		r.update(1.0 / 60.0)
	r.fired.disconnect(count)
	return got[0]

func _ready() -> void:
	# A cycle has to end in the live runner, not just on paper — and still end
	# when it has been charged as far as charge goes.
	var live := runner(trigger_ring(), SkillRunner.MAX_TTL_BONUS)
	live.set_active(true)
	var ran := false
	var ended := false
	for i in 6000:
		live.update(1.0 / 60.0)
		if not live.pulses.is_empty():
			ran = true
		elif ran and live.cooldown > 0:
			ended = true
			break
	check(ran, "a fully charged ring runs")
	check(ended, "and comes to a stop rather than circling forever")

	# More life, more laps, monotonically: each lap of the branch is one more
	# follow-up on the one attack the cast fires.
	var last := -1
	var rising := true
	for bonus in [0, 12, 24, 48]:
		var n := links(runner(trigger_ring(), bonus).simulate()["triggers"].get("ON_HIT", null))
		if n <= last:
			rising = false
		last = n
	check(rising, "more life buys strictly more laps (up to %d follow-ups)" % last)
	check(shots(runner(trigger_ring(), 48)) == 1, "and the cast is still one attack, carrying them")

	# Length alone must never cost a board its shot: a cast's life starts at
	# exactly one pass of whatever board it is, short or long. A pass is the
	# parts on it — the root, the BRIDGEs and the SLASH — and nothing for going
	# out.
	for n in [2, 12, 40]:
		var r := runner(chain(n))
		check(r.pass_cost == n + 2,
			"a %d-BRIDGE chain costs %d to walk once (%d)" % [n, n + 2, r.pass_cost])
		check(shots(r) == 1, "and one pass is exactly what an uncharged cast takes")
		check(not bool(r.simulate()["expired"]), "with nothing cut short for want of life")

	# Charge buys life, and life is only ever spent going round. A board with no
	# cycle in it walks to its way out and stops there however much it is given,
	# so charging must never turn one cast into several.
	for bonus in [0, 12, 24, SkillRunner.MAX_TTL_BONUS]:
		check(shots(runner(chain(3), bonus)) == 1,
			"a cycle-free board fires once at +%d charge" % bonus)
	check(shots(runner(Weapons.make_board("SWORD"), SkillRunner.MAX_TTL_BONUS)) == 1,
		"and so does a fully charged bare graph")

	# What a charge buys has to ride on the cast that paid for it. A trigger
	# branch walks behind the attack that carries it, and each cast used to carry
	# the chain the cast before it had built: a charged cast after a tap went out
	# with no follow-ups, and every tap after a charged cast kept its whole chain.
	var tr := runner(trigger_ring())
	var want := {}
	for bonus in [0, 16, SkillRunner.MAX_TTL_BONUS]:
		tr.ttl_bonus = bonus
		want[bonus] = links(tr.simulate()["triggers"].get("ON_HIT", null)) + 1
	check(want[SkillRunner.MAX_TTL_BONUS] > want[16] and want[16] > want[0],
		"charging a looping trigger buys follow-ups (%s)" % str(want))
	var got: Array = []
	var expected: Array = []
	for bonus in [0, SkillRunner.MAX_TTL_BONUS, SkillRunner.MAX_TTL_BONUS, 16, 0]:
		got.append(live_links(tr, bonus))
		expected.append(want[bonus])
	check(got == expected,
		"each live cast carries the chain its own charge built (%s, want %s)" % [str(got), str(expected)])

	print("[TTL] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
