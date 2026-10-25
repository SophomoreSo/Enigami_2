extends Node2D
## Where a lunge lands. SWIFT STRIKE goes to what the player is pointing at, up
## to the skill's reach; with AUTO-AIM it picks its own target and stops as
## soon as the cut has carried past it, and looks for one as far as it lunges.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[DASH] PASS ", what)
	else:
		fails += 1
		push_error("DASH FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func fire(atk: Actor, form: String, size: float, auto_aim: int = 0, lunge: float = 1.0) -> Vector2:
	var from := atk.global_position
	var p := Payload.new()
	p.form = form
	p.damage = 3.0
	p.size = size
	p.auto_aim = auto_aim
	p.lunge = lunge
	Attacks.spawn(p, {"attacker": atk, "room": null, "team": atk.team,
		"aim": atk.aim if atk is Player else Vector2.RIGHT, "origin": from})
	await frames(2)
	return atk.global_position - from

func _ready() -> void:
	Arena.register(self)
	var p := Player.new()
	p.collision_layer = 2
	p.collision_mask = 1
	p.position = Vector2(400, 300)
	add_child(p)
	await frames(3)
	p.input_locked = true   # nothing to move it between shots

	var reach := Attacks.DASH_SLASH_REACH

	# Inside the skill's reach, the lunge lands on the cursor.
	for d: float in [30.0, 60.0, reach]:
		p.global_position = Vector2(400, 300)
		p.aim = Vector2.RIGHT
		p.aim_point = p.global_position + Vector2(d, 0)
		var moved := await fire(p, "DASHSLASH", 1.0)
		check(absf(moved.x - d) < 1.0,
			"a cursor %.0f px out lands the lunge there (%.1f px)" % [d, moved.x])

	# Beyond it, the reach is the cap — and SIZE is what buys more of it.
	p.global_position = Vector2(400, 300)
	p.aim = Vector2.RIGHT
	p.aim_point = p.global_position + Vector2(900, 0)
	var far := await fire(p, "DASHSLASH", 1.0)
	check(absf(far.x - reach) < 1.0,
		"a cursor past the reach stops at the reach (%.1f of %.0f px)" % [far.x, reach])
	p.global_position = Vector2(400, 300)
	p.aim_point = p.global_position + Vector2(900, 0)
	var big := await fire(p, "DASHSLASH", 1.5)
	check(absf(big.x - reach * 1.5) < 1.0,
		"and SIZE scales that cap (%.1f of %.0f px)" % [big.x, reach * 1.5])

	# SWIFT STRIKE with AUTO-AIM ends just clear of its target, however far away
	# it started.
	for gap: float in [80.0, 160.0, 300.0]:
		p.global_position = Vector2(400, 300)
		p.aim = Vector2.RIGHT
		p.aim_point = p.global_position + Vector2(900, 0)
		var e := Enemy.new()
		e.setup("CRAWLER", 1, "")
		add_child(e)
		e.global_position = p.global_position + Vector2(gap, 0)
		await frames(2)
		var enemy_x := e.global_position.x
		var hp := e.health
		await fire(p, "DASHSLASH", 1.0, 1)
		var clearance := e.hurt_radius + p.hurt_radius
		var past := p.global_position.x - enemy_x
		check(absf(past - clearance) < 1.0,
			"an enemy %.0f px away is cleared by exactly %.1f px, no more" % [gap, past])
		check(e.health < hp, "and the cut still lands on it on the way through")
		e.queue_free()
		await frames(2)

	# AUTO-AIM looks as far as the lunge goes, where that is further than it
	# looks on its own: an enemy past its sight is no target for a short lunge,
	# and is for one that RANGE carries out to it.
	var beyond := Attacks.AUTO_AIM_SIGHT + 200.0
	var carried := (beyond + 100.0) / reach
	for lunge: float in [1.0, carried]:
		p.global_position = Vector2(400, 300)
		p.aim = Vector2.RIGHT
		p.aim_point = p.global_position + Vector2(40, 0)
		var e := Enemy.new()
		e.setup("CRAWLER", 1, "")
		add_child(e)
		e.global_position = p.global_position + Vector2(beyond, 0)
		await frames(2)
		var enemy_x := e.global_position.x
		var moved := await fire(p, "DASHSLASH", 1.0, 1, lunge)
		if lunge == 1.0:
			check(absf(moved.x - reach) < 1.0,
				"an enemy %.0f px off is past a %.0f px lunge's sight: it lunges its reach (%.1f px)"
					% [beyond, reach, moved.x])
		else:
			check(absf(p.global_position.x - enemy_x - (e.hurt_radius + p.hurt_radius)) < 1.0,
				"and a lunge that reaches %.0f px goes at it and through (%.1f px)"
					% [reach * lunge, moved.x])
		e.queue_free()
		await frames(2)

	# A monster has nothing to point at, so it keeps lunging down its aim.
	var m := Enemy.new()
	m.setup("CRAWLER", 1, "")
	add_child(m)
	m.global_position = Vector2(700, 300)
	await frames(2)
	var mfrom := m.global_position
	var mp := Payload.new()
	mp.form = "DASHSLASH"
	mp.damage = 3.0
	mp.size = 1.0
	Attacks.spawn(mp, {"attacker": m, "room": null, "team": m.team,
		"aim": Vector2.RIGHT, "origin": mfrom})
	await frames(2)
	check(absf((m.global_position.x - mfrom.x) - reach) < 1.0,
		"an attacker with no cursor lunges its full reach (%.1f px)"
			% (m.global_position.x - mfrom.x))

	print("[DASH] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
