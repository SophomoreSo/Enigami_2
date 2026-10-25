extends Node2D
## What a blow that gets through buys the player: a second in which nothing else
## can land, whatever they do with it — and the one thing that still reaches
## them inside it, which is the burn a hit has already paid for.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[HURT] PASS ", what)
	else:
		fails += 1
		push_error("HURT FAIL: " + what)

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

func spawn(at: Vector2) -> Player:
	var p := Player.new()
	p.collision_layer = 2
	p.collision_mask = 1
	p.position = at
	add_child(p)
	await get_tree().physics_frame
	await get_tree().physics_frame
	return p

## Waits out whatever grace is running, so the next blow is measured on its own.
func clear(p: Player) -> void:
	var guard := 0
	while p.invuln > 0.0 and guard < 300:
		await get_tree().process_frame
		guard += 1

func wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()

func _ready() -> void:
	Arena.register(self)
	var p := await spawn(Vector2(400, 320))

	# The blow lands, and closes the door behind it.
	var full := p.health
	var first := p.apply_damage(9.0)
	check(first > 0.0 and is_equal_approx(p.health, full - 9.0),
		"the first blow lands in full (%.0f of %.0f left)" % [p.health, full])
	check(p.invuln > Player.HURT_INVULN - 0.05 and p.invuln <= Player.HURT_INVULN + 0.001,
		"and buys the %.1fs of grace it promises (%.3fs)" % [Player.HURT_INVULN, p.invuln])

	var hurt := p.health
	check(p.apply_damage(9.0) == 0.0, "a second blow on the same frame is refused")
	await wait(0.5)
	check(p.apply_damage(9.0) == 0.0, "and one half a second later is still refused")
	check(is_equal_approx(p.health, hurt), "none of them took anything (%.0f)" % p.health)

	# A dash inside the window is the shorter grace of the two, and `maxf` is
	# what stops it trading a second of safety for a tenth.
	Input.action_press("dash")
	var guard := 0
	while not p.is_dashing() and guard < 30:
		await get_tree().physics_frame
		guard += 1
	Input.action_release("dash")
	check(p.invuln > Player.DASH_INVULN + 0.1,
		"dashing inside it does not trade it for the dash's own (%.3fs left)" % p.invuln)

	# How long it actually runs, timed from the blow that opened it.
	await clear(p)
	p.apply_damage(9.0)
	var t := 0.0
	guard = 0
	while p.invuln > 0.0 and guard < 300:
		await get_tree().process_frame
		t += get_process_delta_time()
		guard += 1
	check(absf(t - Player.HURT_INVULN) < 0.05,
		"the grace runs for the second it says and then stops (%.3fs)" % t)
	var next := p.apply_damage(9.0)
	check(next > 0.0, "the blow after it lands (%.0f)" % next)

	# Being on fire is not a way to sit out the fight: the burn the hit lit is
	# already paid for, so it goes on ticking through the grace that same hit
	# bought — while anything swinging at the player still misses.
	await clear(p)
	var lit := p.health
	p.apply_damage(10.0, ["FIRE"])
	check(p.burn_time > 0.0, "a fire hit leaves the player burning (%.1fs)" % p.burn_time)
	var after_hit := p.health
	await wait(0.4)
	check(p.health < after_hit,
		"the burn keeps eating through the grace (%.1f -> %.1f)" % [after_hit, p.health])
	check(p.invuln > 0.0 and p.apply_damage(9.0) == 0.0,
		"and a swing inside that same window still misses")
	check(p.health < lit - 10.0, "so being on fire costs more than the hit that lit it")

	print("[HURT] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
