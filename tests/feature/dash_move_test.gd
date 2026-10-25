extends Node2D
## The dash on the dash key: which way it goes, how far it carries, and what it
## is worth as a dodge. `dash_test` is about the lunges an attack can make; this
## is the move the player presses for themselves.
##
## The three rules it holds to: a dash goes the way the stick is held, any of
## the eight ways and every way between, or the way the body faces with nothing
## held; its reach is a step rather than a flight across the room; and it opens
## a window of i-frames counted from the press and no longer.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[MOVE] PASS ", what)
	else:
		fails += 1
		push_error("MOVE FAIL: " + what)

func spawn(at: Vector2) -> Player:
	var p := Player.new()
	p.collision_layer = 2
	p.collision_mask = 1
	p.position = at
	add_child(p)
	return p

## Presses dash and waits the move out. Reports the direction it took, the
## i-frames the press armed, and how far it carried — measured over the dash's
## own frames only, so the walking that follows is not counted in the reach.
func dash(p: Player) -> Dictionary:
	await begin(p)
	var d := {"went": p.is_dashing(), "dir": p._dash_dir, "invuln": p.invuln}
	var from: Vector2 = p.global_position
	var guard := 0
	while p.is_dashing() and guard < 60:
		await get_tree().physics_frame
		guard += 1
	d["travel"] = p.global_position - from
	return d

## Presses dash and returns on the frame the dash exists but has not moved
## anything yet: the press is seen in the state's own action, and the dash only
## takes the body over from the frame after it.
func begin(p: Player) -> void:
	Input.action_press("dash")
	var guard := 0
	while not p.is_dashing() and guard < 30:
		await get_tree().physics_frame
		guard += 1
	Input.action_release("dash")

## Waits until another dash is there to be had: the cooldown, the stamina it
## costs, and any i-frames still running from the last one — and the body
## still again.
func rest(p: Player) -> void:
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)
	var guard := 0
	while (p.is_dashing() or p.invuln > 0.0 or not p.can_dash() or p.velocity.length() > 1.0) and guard < 900:
		await get_tree().physics_frame
		guard += 1

func _ready() -> void:
	Arena.register(self)
	var p := spawn(Vector2(400, 320))
	await get_tree().physics_frame
	await get_tree().physics_frame

	# Walking right: the dash goes right.
	Input.action_press("move_right")
	var right := await dash(p)
	Input.action_release("move_right")
	check(right["went"], "the key starts a dash")
	check((right["dir"] as Vector2).is_equal_approx(Vector2.RIGHT), "held right, it goes right (%s)" % str(right["dir"]))
	check(absf(right["travel"].y) < 1.0,
		"and carries the player up or down the floor by nothing (%.2f px)" % right["travel"].y)

	# The reach: what the speed and the window say it should be, to within the
	# frame the window is quantised to, and short enough to stay a step.
	var reach: float = right["travel"].x
	var nominal := Player.DASH_SPEED * Player.DASH_TIME
	var frame := Player.DASH_SPEED * get_physics_process_delta_time()
	check(reach >= nominal - 1.0 and reach <= nominal + frame + 1.0,
		"it carries its speed for its window and no further (%.1f px, %.1f asked)"
			% [reach, nominal])
	check(reach > Room.CELL * 1.5 and reach < Room.CELL * 3.5,
		"which is a step of about two and a half cells, not a flight (%.1f cells)"
			% (reach / float(Room.CELL)))

	# Held up and right together: the dash goes the diagonal between them, the
	# same step long.
	await rest(p)
	Input.action_press("move_right")
	Input.action_press("move_up")
	var slant := await dash(p)
	Input.action_release("move_right")
	Input.action_release("move_up")
	check((slant["dir"] as Vector2).is_equal_approx(Vector2(1, -1).normalized()),
		"held up and right, it goes up and right (%s)" % str(slant["dir"]))
	check(absf((slant["travel"] as Vector2).length() - reach) < 1.0,
		"the same step long on the diagonal (%.1f px)" % (slant["travel"] as Vector2).length())

	# Held down alone: down the floor it goes.
	await rest(p)
	Input.action_press("move_down")
	var down := await dash(p)
	Input.action_release("move_down")
	check((down["dir"] as Vector2).is_equal_approx(Vector2.DOWN) and absf(down["travel"].x) < 1.0,
		"held down, it goes down the floor and no way across it (%s)" % str(down["dir"]))

	# Turning around and letting go: the dash follows the face.
	await rest(p)
	Input.action_press("move_left")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("move_left")
	await rest(p)
	var back := await dash(p)
	check((back["dir"] as Vector2).is_equal_approx(Vector2.LEFT) and absf(back["travel"].y) < 1.0,
		"facing left with nothing held, it dashes left (%s)" % str(back["dir"]))

	# What it is worth as a dodge: a window opened at the press, the length it
	# promises, running down on its own from there.
	await rest(p)
	var before := p.health
	await begin(p)
	var armed := p.invuln
	var blocked := p.apply_damage(9.0)
	check(armed <= Player.DASH_INVULN + 0.001 and armed > Player.DASH_INVULN - 0.05,
		"the press arms the %.2fs of i-frames it promises (%.3fs)" % [Player.DASH_INVULN, armed])
	check(blocked == 0.0 and is_equal_approx(p.health, before),
		"a hit inside the window is waved through")
	var t := 0.0
	var guard := 0
	while p.invuln > 0.0 and guard < 200:
		await get_tree().process_frame
		t += get_process_delta_time()
		guard += 1
	check(t <= armed + 0.03,
		"it runs down from there rather than being topped up frame by frame (%.3fs)" % t)
	check(p._dash_cd > 0.0,
		"and closes well before the dash comes back (%.2fs of recovery left)" % p._dash_cd)
	var landed := p.apply_damage(9.0)
	check(landed > 0.0 and p.health < before, "after it, a hit lands (%.0f)" % landed)

	print("[MOVE] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
