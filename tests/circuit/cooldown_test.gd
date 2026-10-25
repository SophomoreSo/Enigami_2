extends Node
## The numbers behind the graph's cooldown wipe: one continuous 0 → 1 fill
## across the whole wait, measured against how long a cycle really takes, and a
## flash at the moment it lands.

## Finer than a frame, because this measures a cycle rather than plays one: at
## the base clock a plain board's whole cadence is a couple of frames long, and
## sampling it every sixtieth of a second cannot tell 0.04s from 0.05s — the
## readings this asserts on were quantisation, not the runner.
const DT := 1.0 / 240.0
## Steps to a second, so a wait can be written as the time it means.
const SECOND := int(1.0 / DT)

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[CD] PASS ", what)
	else:
		fails += 1
		push_error("CD FAIL: " + what)

func make(weapon: String) -> SkillRunner:
	var r := SkillRunner.new(Weapons.make_board(weapon))
	r.base_payload_provider = func() -> Payload: return Weapons.base_payload(weapon)
	return r

## Cycles a held skill gets through in `secs`.
func cycles_in(r: SkillRunner, secs: float) -> int:
	var n := [0]
	r.cycle_started.connect(func() -> void: n[0] += 1)
	r.set_active(true)
	var t := 0.0
	while t < secs:
		r.update(DT)
		t += DT
	return n[0]

## Runs one whole cast at `bonus` charge, and reports how long it took and what
## the wipe read on the last frame before the slot came free.
func cast_at(r: SkillRunner, bonus: int) -> Dictionary:
	r.ttl_bonus = bonus
	r.set_active(true)
	var ran := false
	var wipe := 0.0
	var secs := 0.0
	for i in 20 * SECOND:
		r.update(DT)
		if not r.is_ready():
			ran = true
			wipe = r.ready_ratio()
			secs += DT
			r.set_active(false)   # one cast, not a held repeat
		elif ran:
			break
	return {"wipe": wipe, "seconds": secs}

## A straight board: a BRIDGE on the root and the listed parts in a row after
## it, on a board exactly as long, so the last of them is against the way out.
## Returns how many ticks one whole cycle of it takes.
func ticks_of(ids: Array) -> int:
	var long := 1
	for id in ids:
		long += int(Components.get_def(id)["cells"])
	var b := SkillBoard.new(long, 5, "chain")
	b.set_root("BRIDGE")
	var x := 1
	for id in ids:
		b.place(String(id), Vector2i(x, 2), 0)
		x += int(Components.get_def(id)["cells"])
	var r := SkillRunner.new(b)
	r.base_payload_provider = func() -> Payload: return Weapons.base_payload("SWORD")
	return int(r.simulate()["ticks"])

func _ready() -> void:
	# Held: the fill runs the whole wait and restarts, and each landing flashes.
	var r := make("SWORD")
	var predicted := float(r.simulate()["cycle_seconds"])
	r.set_active(true)
	var samples: Array = []
	var flashes := 0
	var was_flash := 0.0
	var backwards := 0
	var last := 0.0
	for i in 3 * SECOND:
		r.update(DT)
		var p := r.ready_ratio()
		if r.ready_flash > was_flash:
			flashes += 1
		was_flash = r.ready_flash
		if p < last - 0.001 and p > 0.02:
			backwards += 1
		last = p
		samples.append(p)
	check(samples.max() > 0.85, "the fill reaches the bottom of the card (%.2f)" % samples.max())
	check(backwards == 0, "and only ever runs downward, never jumping back (%d reversals)" % backwards)
	check(flashes >= 2, "a held skill flashes on every landing (%d in %.1fs)" % [flashes, 3 * SECOND * DT])
	check(absf(r.cycle_seconds - predicted) < predicted * 0.2,
		"the fill is measured against the real cycle (%.3fs vs %.3fs preview)"
			% [r.cycle_seconds, predicted])

	# Released: it comes back, flashes, and then sits ready.
	var q := make("SWORD")
	q.set_active(true)
	for i in 4:
		q.update(DT)
	q.set_active(false)
	var peak := 0.0
	for i in SECOND:
		q.update(DT)
		peak = maxf(peak, q.ready_flash)
	check(q.is_ready(), "a released skill settles as ready")
	check(is_equal_approx(q.ready_ratio(), 1.0), "with the card fully clear (%.2f)" % q.ready_ratio())
	check(peak > 0.9, "and it flashed when it got there (%.2f)" % peak)
	for i in SECOND:
		q.update(DT)
	check(q.ready_flash <= 0.0, "the flash fades out rather than sticking on")

	# A slower board must take proportionally longer to fill. Counted over a run
	# of cycles rather than read off one of them: two bare graphs are only a
	# tick of heat apart, a step of this loop, so a single reading of either is
	# mostly quantisation.
	var rock_cycle := float(make("ROCK").simulate()["cycle_seconds"])
	check(not is_equal_approx(rock_cycle, predicted),
		"the ROCK's and the SWORD's bare graphs take different times (%.4fs vs %.4fs)" % [rock_cycle, predicted])
	var slow := "ROCK" if rock_cycle > predicted else "SWORD"
	var fast := "SWORD" if slow == "ROCK" else "ROCK"
	var slow_n := cycles_in(make(slow), 3.0)
	var fast_n := cycles_in(make(fast), 3.0)
	check(slow_n < fast_n,
		"and the slower one's square fills more slowly to match (%d %s cycles in 3s against %d %s)"
			% [slow_n, slow, fast_n, fast])

	# Charging changes how long a cast takes, so one cycle stopped predicting the
	# next one the moment holding the button bought laps. The wipe has to fill
	# against the cast actually running: a charged cast followed by an uncharged
	# one had the slot reading four tenths full at the instant it was castable.
	var ring := SkillBoard.new(7, 5, "ring")
	ring.set_root("BRIDGE", Vector2i(3, 2))
	ring.place("BRIDGE", Vector2i(4, 2), 0)
	ring.place("ON_HIT", Vector2i(5, 2), 0)     # on through the SLASH and out, and its branch round
	ring.place("SLASH", Vector2i(6, 2), 0)
	ring.place("BRIDGE", Vector2i(5, 3), 2)
	ring.place("BRIDGE", Vector2i(4, 3), 3)     # back into the first BRIDGE
	var lr := SkillRunner.new(ring)
	lr.base_payload_provider = func() -> Payload: return Weapons.base_payload("SWORD")
	var charged := cast_at(lr, SkillRunner.MAX_TTL_BONUS)
	var plain := cast_at(lr, 0)
	check(charged["seconds"] > plain["seconds"] * 1.5,
		"a charged cast really is the longer one (%.2fs vs %.2fs)"
			% [charged["seconds"], plain["seconds"]])
	# Alternating is what catches it: each cast is measured against the last.
	var worst := 1.0
	for bonus in [SkillRunner.MAX_TTL_BONUS, 0, SkillRunner.MAX_TTL_BONUS, 0]:
		worst = minf(worst, float(cast_at(lr, bonus)["wipe"]))
	check(worst > 0.9,
		"the wipe is full when the slot comes free, charged or not (worst %.2f)" % worst)

	# One tick per cell. What a part costs is the room it takes up, so a cycle can
	# be counted off the grid instead of looked up part by part.
	var drift: Array = []
	for id in Components.ids():
		if Components.tick_cost(id) != int(Components.get_def(id)["cells"]):
			drift.append(id)
	check(drift.is_empty(), "every part costs one tick per cell (%s)" % str(drift))
	var wide: Array = []
	for id in Components.ids():
		if int(Components.get_def(id)["cells"]) != 1:
			wide.append(id)
	check(wide.is_empty(), "and every part is one cell, so one tick (%s)" % str(wide))
	# And the board agrees: every cell added to the path is one more tick,
	# whichever part it belongs to.
	var one := ticks_of(["BRIDGE"])
	check(ticks_of(["BRIDGE", "BRIDGE"]) - one == 1,
		"a second BRIDGE costs one tick (%d)" % (ticks_of(["BRIDGE", "BRIDGE"]) - one))
	# And a board is its parts and the wait every cast has: going out of it
	# costs nothing.
	check(one == 2 + SkillRunner.BASE_COOLDOWN_TICKS,
		"a board of two BRIDGEs is two ticks and the wait (%d)" % one)
	# DELAY, which used to hold a flow for twelve ticks of its own, is a cell
	# like any other: what it adds is its heat, to the wait after the walk.
	var held := ticks_of(["DELAY"]) - one
	var heat_ticks := int(round(float(Components.get_def("DELAY")["heat"]) * SkillRunner.HEAT_TO_TICKS))
	check(heat_ticks > 0 and held == heat_ticks,
		"a DELAY where a BRIDGE was adds its heat to the wait, %d ticks of it (%d)" % [heat_ticks, held])

	print("[CD] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
