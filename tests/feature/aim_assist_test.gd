extends Node2D
## Aim assist: the curve from where the stick points to where the weapon does
## (`AimCurve`), and the player's line bending a stick's aim with it
## (`AimAssist`). The curve keeps a target's middle exact, gives every target at
## least the floor's width of stick, runs slower across it and faster beside it
## but never backwards, is the identity away from everything, goes all the way
## round, and moves smoothly as targets close on each other. In the world, only
## a stick's aim bends — never the pointer's — toward what is alive, in reach
## and in sight, and a change in what can be aimed at fades in rather than
## jumping the weapon.

var fails := 0
## How near two angles have to be to be the same one. A target comes in as a
## Vector2, whose numbers are 32-bit, so its middle is a hair off the 64-bit
## angle it was made from: millionths of a degree.
const CLOSE := 1e-6

func check(ok: bool, what: String) -> void:
	if ok:
		print("[AIM] PASS ", what)
	else:
		fails += 1
		push_error("AIM FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func wait(secs: float) -> void:
	var t := 0.0
	while t < secs:
		await get_tree().process_frame
		t += get_process_delta_time()

func deg(v: float) -> float:
	return deg_to_rad(v)

## The curve all the way round: its least and greatest slope, its greatest
## correction, and how far off it comes back round to where it started.
func sweep(c: AimCurve, steps: int = 7200) -> Dictionary:
	var lo := INF
	var hi := -INF
	var most := 0.0
	var step := TAU / float(steps)
	var prev := c.at(-PI)
	for i in range(1, steps + 1):
		var x := -PI + step * float(i)
		var y := c.at(x)
		lo = minf(lo, (y - prev) / step)
		hi = maxf(hi, (y - prev) / step)
		most = maxf(most, absf(y - x))
		prev = y
	var round_trip := 0.0
	for x in [-3.0, -1.0, 0.3, 2.5]:
		round_trip = maxf(round_trip, absf(c.at(x + TAU) - (c.at(x) + TAU)))
	return {"lo": lo, "hi": hi, "most": most, "round": round_trip}

func _ready() -> void:
	_the_curve()
	await _in_the_world()
	print("[AIM] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## --- the curve ----------------------------------------------------------------
func _the_curve() -> void:
	var steepest := 1.5 * AimCurve.SECANT_MAX
	var bound := AimCurve.FLOOR + deg(1.0)

	var none := sweep(AimCurve.around([]))
	check(is_equal_approx(float(none["lo"]), 1.0) and is_equal_approx(float(none["hi"]), 1.0)
		and float(none["most"]) < 1e-12, "with nothing to aim at, the stick is the aim")

	# One small target, 2 degrees either side of its middle at 30.
	var mid := deg(30.0)
	var half := deg(2.0)
	var one := AimCurve.around([Vector2(mid, half)])
	check(absf(one.at(mid) - mid) < CLOSE, "aimed dead at a target's middle, nothing is corrected")
	check(absf(one.at(mid + AimCurve.FLOOR) - (mid + half)) < CLOSE
			and absf(one.at(mid - AimCurve.FLOOR) - (mid - half)) < CLOSE,
		"the stick FLOOR either side of it lands on its edges: its virtual size is the floor")
	var d := deg(0.01)
	var across := (one.at(mid + d) - one.at(mid - d)) / (2.0 * d)
	check(absf(across - half / AimCurve.FLOOR) < 1e-6,
		"across it the stick runs at its size over its virtual size (%.3f)" % across)
	var away := AimCurve.FLOOR + AimCurve.MARGIN + deg(1.0)
	check(absf(one.at(mid + away) - (mid + away)) < CLOSE and absf(one.at(mid - away) - (mid - away)) < CLOSE
			and absf(one.at(mid + PI) - (mid + PI)) < CLOSE,
		"MARGIN past its virtual size the curve is the identity again")
	var s := sweep(one)
	check(float(s["lo"]) >= AimCurve.SENSITIVITY_MIN - 1e-6,
		"it never runs backwards, nor slower than SENSITIVITY_MIN (%.3f)" % float(s["lo"]))
	check(float(s["hi"]) <= steepest, "nor steeper than it may (%.3f)" % float(s["hi"]))
	check(float(s["most"]) <= bound, "and corrects no more than about the floor (%.2f deg)" % rad_to_deg(float(s["most"])))
	check(float(s["round"]) < 1e-9, "all the way round, it comes back to where it started")

	var big := sweep(AimCurve.around([Vector2(deg(-50.0), AimCurve.FLOOR + deg(1.0))]))
	check(float(big["most"]) < 1e-9, "a target already as wide as the floor is left alone")
	var tiny := AimCurve.around([Vector2(0.0, deg(0.5))])
	var crawl := (tiny.at(d) - tiny.at(-d)) / (2.0 * d)
	check(absf(crawl - AimCurve.SENSITIVITY_MIN) < 1e-6,
		"a tiny one is held to SENSITIVITY_MIN rather than flattened (%.3f)" % crawl)

	# Two, far enough apart to leave each other be, and both middles exact.
	var pair := AimCurve.around([Vector2(deg(10.0), half), Vector2(deg(70.0), half)])
	check(absf(pair.at(deg(10.0)) - deg(10.0)) < CLOSE and absf(pair.at(deg(70.0)) - deg(70.0)) < CLOSE,
		"two targets: each middle is still exact")
	check(absf(pair.at(deg(10.0) + AimCurve.FLOOR) - deg(12.0)) < CLOSE,
		"and far enough apart, each keeps its whole virtual size")

	# Brought together until one stands in front of the other: the curve moves,
	# but it never jumps — not as they crowd each other, and not as they meet.
	var worst := 0.0
	var worst_at := 0.0
	var before := PackedFloat64Array()
	var sep := 60.0
	var ok := true
	while sep >= 0.0:
		var c := AimCurve.around([Vector2(0.0, half), Vector2(deg(sep), half)])
		var sw := sweep(c, 1800)
		ok = ok and float(sw["lo"]) > 0.0 and float(sw["hi"]) <= steepest
		var now := PackedFloat64Array()
		for i in 400:
			now.append(c.at(deg(-60.0 + 0.3 * float(i))))
		if not before.is_empty():
			for i in now.size():
				if absf(now[i] - before[i]) > worst:
					worst = absf(now[i] - before[i])
					worst_at = sep
		before = now
		sep -= 0.05
	check(ok, "two targets closing on each other: it climbs, and never too steeply, all the way")
	check(worst < deg(0.5), "and it moves smoothly as they close and meet (at most %.2f deg a step, at %.2f apart)"
		% [rad_to_deg(worst), worst_at])

	var seam := sweep(AimCurve.around([Vector2(deg(179.0), deg(3.0)), Vector2(deg(-179.0), deg(3.0))]))
	check(float(seam["lo"]) > 0.0 and float(seam["round"]) < 1e-9, "two meeting across the half-turn are one, all the same")

	var full := AimCurve.around([Vector2(mid, half)], 1.0)
	var some := AimCurve.around([Vector2(mid, half)], 0.5)
	var off := AimCurve.around([Vector2(mid, half)], 0.0)
	var x := mid + deg(8.0)
	check(absf(off.at(x) - x) < 1e-12 and absf(some.at(x) - (x + full.at(x)) * 0.5) < 1e-9,
		"strength blends it with the identity: none of it is the stick, half is half way")

	# Anything at all: any number of targets, any size, anywhere.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261001
	var lo := INF
	var hi := -INF
	var most := 0.0
	var turned := 0.0
	for trial in 300:
		var ts: Array = []
		for i in rng.randi_range(1, 9):
			ts.append(Vector2(rng.randf_range(-PI, PI), deg(rng.randf_range(0.3, 30.0))))
		var sw := sweep(AimCurve.around(ts), 1800)
		lo = minf(lo, float(sw["lo"]))
		hi = maxf(hi, float(sw["hi"]))
		most = maxf(most, float(sw["most"]))
		turned = maxf(turned, float(sw["round"]))
	check(lo >= AimCurve.SENSITIVITY_MIN - 1e-6 and hi <= steepest,
		"300 rooms of targets: always climbing, slope %.3f to %.3f" % [lo, hi])
	check(most <= bound and turned < 1e-9,
		"never correcting much past the floor (%.2f deg), and always all the way round" % rad_to_deg(most))

## --- in the world -------------------------------------------------------------

## A room that cannot see across itself.
class Blind extends RefCounted:
	func has_line_of_sight(_a: Vector2, _b: Vector2) -> bool:
		return false

func solid(centre: Vector2, size: Vector2) -> void:
	var b := StaticBody2D.new()
	b.collision_layer = 1
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	cs.position = centre
	b.add_child(cs)
	add_child(b)

## Something to aim at: a body on the monsters' side with nothing to do.
func target(at: Vector2, radius: float) -> Actor:
	var t := Actor.new()
	t.team = 1
	t.hurt_radius = radius
	t.position = at
	add_child(t)
	return t

## Pushes the right stick all the way over at `angle`, or lets go of it.
func stick(angle: float, push: float = 1.0) -> void:
	for i in 2:
		var m := InputEventJoypadMotion.new()
		m.device = 0
		m.axis = JOY_AXIS_RIGHT_X if i == 0 else JOY_AXIS_RIGHT_Y
		m.axis_value = cos(angle) * push if i == 0 else sin(angle) * push
		Input.parse_input_event(m)
	await frames(3)

## Watches the aim while something about the targets changes: how far it moved
## in the worst single frame, and how long until it settled within a hair of
## where it was going.
func watch_fade(p: Player, going_to: float) -> Dictionary:
	var biggest := 0.0
	var last := p.aim.angle()
	var t := 0.0
	var settled := -1.0
	while t < 1.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		var now := p.aim.angle()
		biggest = maxf(biggest, absf(now - last))
		last = now
		if settled < 0.0 and absf(now - going_to) < deg(0.05):
			settled = t
	return {"step": biggest, "took": settled}

func _in_the_world() -> void:
	AimAssist.strength = 1.0
	var p := Player.new()
	p.collision_layer = 2
	p.collision_mask = 1
	p.position = Vector2(300, 360)
	add_child(p)
	await frames(30)
	var t := target(p.global_position + Vector2(300, 0), 14.0)
	var half := asin(14.0 / 300.0)
	# The room was empty when the player came in, so the monster is a change in
	# what can be aimed at, and fades in like one.
	await wait(AimAssist.FADE * 2.0)

	await stick(0.0)
	check(absf(p.aim.angle()) < 1e-4, "a stick dead on a monster is where the weapon points")
	await stick(deg(8.0))
	var bent := p.aim.angle()
	check(absf(bent) <= half,
		"8 degrees off a monster 300px out, the weapon is on it (%.2f deg, it fills %.2f)" % [rad_to_deg(bent), rad_to_deg(half)])
	var curve_says := AimCurve.around([Vector2(0.0, half)]).at(deg(8.0))
	check(absf(bent - curve_says) < deg(0.05), "exactly where the curve puts it (%.3f)" % rad_to_deg(curve_says))
	check(p.aim_point.is_equal_approx(p.global_position + p.aim * Player.STICK_AIM_REACH),
		"and where it lands follows the bent aim, not the stick")
	await stick(deg(60.0))
	check(absf(p.aim.angle() - deg(60.0)) < 1e-4, "60 degrees off, the stick is left alone")

	# Things change, and the weapon is walked over rather than jumped.
	await stick(deg(8.0))
	p.room = Blind.new()
	var gone := await watch_fade(p, deg(8.0))
	check(float(gone["took"]) >= AimAssist.FADE * 0.5 and float(gone["took"]) <= AimAssist.FADE * 2.0,
		"out of sight, it lets go — over FADE (%.2fs)" % float(gone["took"]))
	check(float(gone["step"]) < deg(2.0), "never by more than %.2f deg a frame" % rad_to_deg(float(gone["step"])))
	check(absf(p.aim.angle() - deg(8.0)) < 1e-4, "and then the stick is the aim")
	p.room = null
	var back := await watch_fade(p, curve_says)
	check(float(back["took"]) > 0.0 and float(back["step"]) < deg(2.0),
		"back in sight, it comes back the same way (%.2fs, %.2f deg a frame at most)"
			% [float(back["took"]), rad_to_deg(float(back["step"]))])
	t.global_position = p.global_position + Vector2(AimAssist.REACH + 100.0, 0)
	await wait(AimAssist.FADE * 2.0)
	check(absf(p.aim.angle() - deg(8.0)) < 1e-4, "out of reach, nothing pulls")
	t.global_position = p.global_position + Vector2(300, 0)
	await wait(AimAssist.FADE * 2.0)
	check(absf(p.aim.angle() - curve_says) < deg(0.05), "in reach again, it does")
	t.dead = true
	var died := await watch_fade(p, deg(8.0))
	check(float(died["took"]) > 0.0 and float(died["step"]) < deg(2.0),
		"a monster that dies lets go of the aim the same way (%.2fs)" % float(died["took"]))
	t.dead = false

	# The player's own say.
	await wait(AimAssist.FADE * 2.0)
	AimAssist.strength = 0.0
	await frames(3)
	check(absf(p.aim.angle() - deg(8.0)) < 1e-4, "with the setting at nothing, the stick is the aim")
	AimAssist.strength = 1.0
	await frames(3)

	# The pointer points at a place, and is never bent: a target right beside
	# where it points does not move the weapon off it.
	await stick(0.0, 0.0)
	var pointed := Pointer.world_point(p) - p.global_position
	t.global_position = p.global_position + pointed.normalized().rotated(deg(6.0)) * 300.0
	await wait(AimAssist.FADE * 2.0)
	check(pointed.length() > 4.0 and absf(p.aim.angle_to(pointed)) < 1e-4,
		"the pointer's aim is never bent, though a monster stands 6 degrees off it")
