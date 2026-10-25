extends Node
## Every OVERCLOCK takes the same share of a board's cycle off, the tenth as much
## as the first, down to a floor past which one more does nothing. That holds
## only because a flow crosses one without spending a tick: when each cost the
## tick every part costs, and a settling delay on top, the curve bottomed out at
## one and a row of them made a board slower.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[OC] PASS ", what)
	else:
		fails += 1
		push_error("OC FAIL: " + what)

## A row of `n` overclocks feeding a SLASH, off a BRIDGE on the root, on a
## board exactly as long and one row high — so the row is the middle one, and
## the SLASH stands against the way out.
func build(n: int) -> SkillBoard:
	var b := SkillBoard.new(n + 2, 1, "oc")
	b.set_root("BRIDGE", Vector2i(0, 0), 0)
	for i in n:
		b.place("OVERCLOCK", Vector2i(1 + i, 0), 0)
	b.place("SLASH", Vector2i(n + 1, 0), 0)
	return b

func cycle(n: int, mul: float = 1.0) -> float:
	var b := build(n)
	if int(b.analyze()["overclock"]) != n:
		push_error("OC FAIL: only %d of %d overclocks fitted" % [b.analyze()["overclock"], n])
	var r := SkillRunner.new(b)
	r.base_payload_provider = func() -> Payload: return Weapons.base_payload("SWORD")
	r.cooldown_mul = mul
	return float(r.simulate()["cycle_seconds"])

## What `n` overclocks should leave of a cycle of `base`.
func expected(base: float, n: int) -> float:
	return base * maxf(1.0 - SkillBoard.OVERCLOCK_STEP * n, SkillBoard.OVERCLOCK_FLOOR)

func _ready() -> void:
	var c: Dictionary = {}
	for n in [0, 1, 2, 3, 4, 5, 6, 8, 12, 20, 29]:
		c[n] = cycle(n)
	print("[OC] curve: ", c)

	var cut: float = float(c[0]) * SkillBoard.OVERCLOCK_STEP
	check(c[1] < c[0] and absf((c[0] - c[1]) - cut) < 1e-6,
		"one overclock takes a step off the cycle (%.4f -> %.4f)" % [c[0], c[1]])
	check(absf((c[1] - c[2]) - cut) < 1e-6 and absf((c[4] - c[5]) - cut) < 1e-6,
		"and every one after takes the same step again")
	var on_line := true
	for n in c:
		if absf(c[n] - expected(c[0], n)) > 1e-6:
			on_line = false
			push_error("OC FAIL: %d overclocks give %.4f, the line says %.4f" % [n, c[n], expected(c[0], n)])
	check(on_line, "the whole curve is the line, floor included")

	# More is never worse, and past the floor it is nothing at all.
	var falling := true
	var keys := c.keys()
	keys.sort()
	for i in range(1, keys.size()):
		if c[keys[i]] > c[keys[i - 1]] + 1e-9:
			falling = false
	check(falling, "more overclocks are never slower")
	check(absf(c[12] - c[0] * SkillBoard.OVERCLOCK_FLOOR) < 1e-6,
		"twelve reach the floor (%.4f of %.4f)" % [c[12], c[0]])
	check(absf(c[29] - c[12]) < 1e-6, "and a wall of them past it is worth what twelve are")

	# A weapon's wait is the graph's stretched ten times over, and the line holds
	# on it just the same: the multiplier scales the whole cycle, not the cut.
	var w0 := cycle(0, Player.CAST_COOLDOWN_MUL)
	var w6 := cycle(6, Player.CAST_COOLDOWN_MUL)
	check(absf(w6 - expected(w0, 6)) < 1e-6,
		"on a weapon six take 30%% off too (%.3f -> %.3f)" % [w0, w6])

	# The live runner must actually deliver the cycle the preview promises.
	for n in [0, 2, 8, 12]:
		var b := build(n)
		var r := SkillRunner.new(b)
		r.base_payload_provider = func() -> Payload: return Weapons.base_payload("SWORD")
		var predicted := float(r.simulate()["cycle_seconds"])
		var count := [0]
		r.cycle_started.connect(func() -> void: count[0] += 1)
		r.set_active(true)
		var step := 1.0 / 240.0
		var elapsed := 0.0
		var budget: float = maxf(predicted * 6.0, 2.0)
		while elapsed < budget:
			r.update(step)
			elapsed += step
		var measured := elapsed / float(maxi(count[0], 1))
		check(absf(measured - predicted) < predicted * 0.25,
			"live cycle matches the preview at %d overclocks (%.3f vs %.3f)" % [n, measured, predicted])

	print("[OC] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
