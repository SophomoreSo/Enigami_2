extends Node2D
## How far an attack goes when the aim says how far: the right stick, pushed
## part of the way past its dead zone, asks for part of an attack's distance
## (`Player.aim_reach`), and a spawn handed that `reach` covers that share of
## its own — a bolt's range, a thrown shot's arc, a lunge. Nothing asks
## a burst or a swing to move: they happen where the caster stands.
##
## Driven through `Attacks.spawn`, the door the player's casts go through, and
## the player's own stick reading, so what is checked is the rule and not a
## copy of it. Without a `reach` nothing changes — a monster's attack, a mouse.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[REACH] PASS ", what)
	else:
		fails += 1
		push_error("REACH FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## Whatever a spawn just put in the arena of `kind`, taken out again.
func spawned(kind: Variant) -> Array:
	var out: Array = []
	for c in get_children():
		if is_instance_of(c, kind) and not c.is_queued_for_deletion():
			out.append(c)
			remove_child(c)
			c.queue_free()
	return out

func bolt(form: String = "PROJECTILE") -> Payload:
	var p := Payload.new()
	p.form = form
	p.range_px = 400.0
	return p

func push(at: Vector2) -> void:
	for i in 2:
		var m := InputEventJoypadMotion.new()
		m.device = 0
		m.axis = JOY_AXIS_RIGHT_X if i == 0 else JOY_AXIS_RIGHT_Y
		m.axis_value = at.x if i == 0 else at.y
		Input.parse_input_event(m)

func _ready() -> void:
	Arena.register(self)

	# --- the stick ----------------------------------------------------------
	check(is_zero_approx(Player.reach_of(Player.STICK_DEAD * 0.5)) and is_zero_approx(Player.reach_of(Player.STICK_DEAD)),
		"inside the dead zone the stick asks for nothing")
	check(is_equal_approx(Player.reach_of(1.0), 1.0), "at the rim it asks for all of it")
	var drift: Array = []
	for want: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
		var back := Player.reach_of(Player.push_for(want))
		if absf(back - want) > 0.02:
			drift.append("%.2f -> %.2f" % [want, back])
	check(drift.is_empty(), "a push made for a reach reads back as that reach (%s)" % str(drift))
	check(Player.push_for(0.0) > Player.STICK_DEAD, "and even the shortest one aims")

	# --- the share of the distance ---------------------------------------------
	check(is_equal_approx(Attacks.distance_for(0.0), Attacks.REACH_MIN)
			and is_equal_approx(Attacks.distance_for(1.0), 1.0)
			and Attacks.distance_for(0.5) > Attacks.REACH_MIN and Attacks.distance_for(0.5) < 1.0,
		"nothing asked for is REACH_MIN of the way, all of it is all of it (%.2f at half)" % Attacks.distance_for(0.5))

	# --- a bolt -------------------------------------------------------------------
	var ranges: Dictionary = {}
	for r: float in [0.0, 0.5, 1.0]:
		Attacks.spawn(bolt(), {"aim": Vector2.RIGHT, "origin": Vector2.ZERO, "reach": r})
		var shots := spawned(Projectile)
		ranges[r] = (shots[0] as Projectile).range_px if shots.size() == 1 else -1.0
	check(is_equal_approx(float(ranges[1.0]), 400.0) and is_equal_approx(float(ranges[0.0]), 400.0 * Attacks.REACH_MIN)
			and is_equal_approx(float(ranges[0.5]), 400.0 * Attacks.distance_for(0.5)),
		"a bolt flies the share of its range the aim asks for (%s)" % str(ranges))
	Attacks.spawn(bolt(), {"aim": Vector2.RIGHT, "origin": Vector2.ZERO})
	var plain := spawned(Projectile)
	check(plain.size() == 1 and is_equal_approx((plain[0] as Projectile).range_px, 400.0),
		"and one nobody said how far of flies all of it, as a monster's does")

	# --- a throw --------------------------------------------------------------------
	# A lobbed shot flies an arc over the floor and comes down where the aim
	# asks: as far as it carries at the rim, REACH_MIN of that at the dead
	# zone. The arc is what ends it, not its range, which stays whole.
	var lands: Dictionary = {}
	var short_range := 0.0
	for r: float in [1.0, 0.0]:
		Attacks.spawn(bolt(), {"aim": Vector2.RIGHT, "origin": Vector2.ZERO, "reach": r, "lobbed": true})
		var thrown := spawned(Projectile)
		if thrown.size() == 1:
			var b: Projectile = thrown[0]
			# Where h + v t - g t² / 2 comes back to the floor, and how far it
			# flies in that time.
			var g := b.gravity
			var t := (b.vertical + sqrt(b.vertical * b.vertical + 2.0 * g * b.height)) / g
			lands[r] = b.velocity.length() * t
			if r == 0.0:
				short_range = b.range_px
	check(lands.has(1.0) and lands.has(0.0) and absf(float(lands[1.0]) - 400.0) < 2.0
			and absf(float(lands[0.0]) - 400.0 * Attacks.REACH_MIN) < 2.0,
		"a lobbed shot comes down all the way out at the rim, REACH_MIN of the way at the dead zone (%s)" % str(lands))
	check(is_equal_approx(short_range, 400.0), "rather than being cut off in the air")

	# --- a lunge ------------------------------------------------------------------------
	var caster := Player.new()
	add_child(caster)
	await frames(2)
	caster.global_position = Vector2(0, 0)
	caster.aim_point = caster.global_position + Vector2.RIGHT * Player.STICK_AIM_REACH
	var lunges: Dictionary = {}
	for r: float in [0.0, 1.0]:
		Attacks.spawn(bolt("DASHSLASH"), {"attacker": caster, "aim": Vector2.RIGHT,
			"origin": caster.global_position, "reach": r})
		var cut := spawned(DashSlash)
		lunges[r] = (cut[0] as DashSlash).to.distance_to((cut[0] as DashSlash).from) if cut.size() == 1 else -1.0
	check(is_equal_approx(float(lunges[1.0]), Attacks.DASH_SLASH_REACH)
			and is_equal_approx(float(lunges[0.0]), Attacks.DASH_SLASH_REACH * Attacks.REACH_MIN),
		"a lunge aimed with the stick goes the share of its reach asked for (%s)" % str(lunges))
	caster.velocity = Vector2.ZERO

	# --- the player reads it off the stick ---------------------------------------------
	push(Vector2.RIGHT * Player.push_for(0.5))
	await frames(2)
	caster._update_aim()
	check(absf(caster.aim_reach - 0.5) < 0.02 and caster.aim.is_equal_approx(Vector2.RIGHT),
		"the player aiming with the stick half way asks for half (%.2f)" % caster.aim_reach)
	push(Vector2.ZERO)
	await frames(2)
	caster._update_aim()
	check(is_equal_approx(caster.aim_reach, 1.0), "and aiming with the pointer asks for all of it")

	print("[REACH] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
