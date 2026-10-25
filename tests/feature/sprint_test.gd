extends Node2D
## The sprint: the same walk, half as fast again, for as long as it is asked
## for.
##
## Held with a direction the body goes that way faster, and let go it is a
## walk again. It is a pace and nothing else — no state of its own, no cost —
## so it turns and stops as a walk does, goes every way a walk goes, and does
## nothing by itself. A hold still holds it, a walk the game is walking is
## still a walk, and a chill slows it as it slows a walk. The key says it; on
## the console it is the stick dragged far out of its ring, which is
## touch_pad_test's.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[SPRINT] PASS ", what)
	else:
		fails += 1
		push_error("SPRINT FAIL: " + what)

func phys(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func until(cond: Callable, limit: int = 240) -> bool:
	for i in limit:
		if cond.call():
			return true
		await get_tree().physics_frame
	return bool(cond.call())

func settle(p: Player) -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "dash", "sprint"]:
		Input.action_release(a)
	await until(func() -> bool: return p.velocity.length() < 1.0)
	await phys(2)

## The speed the body settles at, held as it is for a while.
func top_speed(p: Player) -> float:
	await phys(40)
	return p.velocity.length()

func _ready() -> void:
	var p := Player.new()
	p.collision_layer = 2
	p.collision_mask = 1
	p.position = Vector2(0, 360)
	add_child(p)
	await settle(p)

	check(Player.SPRINT_SPEED > Player.RUN_SPEED * 1.2,
		"a sprint is a good deal faster than a walk (%.0f against %.0f)" % [Player.SPRINT_SPEED, Player.RUN_SPEED])

	# --- held with a direction --------------------------------------------------------
	Input.action_press("move_right")
	var walk := await top_speed(p)
	check(is_equal_approx(walk, Player.RUN_SPEED), "holding right alone is a walk (%.0f)" % walk)
	Input.action_press("sprint")
	var sprint := await top_speed(p)
	check(is_equal_approx(sprint, Player.SPRINT_SPEED) and p.velocity.x > 0.0,
		"with sprint held it is a sprint, the same way (%.0f)" % sprint)
	check(p.state_name() == "Walk", "which is a pace, not a state of its own (%s)" % p.state_name())
	Input.action_release("sprint")
	var again := await top_speed(p)
	check(is_equal_approx(again, Player.RUN_SPEED), "let go of, it is a walk again (%.0f)" % again)
	Input.action_press("sprint")
	await phys(30)
	Input.action_release("move_right")
	Input.action_press("move_left")
	var back := await top_speed(p)
	check(is_equal_approx(back, Player.SPRINT_SPEED) and p.velocity.x < 0.0 and p.side() == -1,
		"it turns as a walk does, and sprints the other way (%.0f)" % p.velocity.x)
	await settle(p)

	# --- by itself, and on a diagonal ------------------------------------------------
	var from := p.global_position
	Input.action_press("sprint")
	await phys(20)
	check(p.state_name() == "Idle" and p.global_position.distance_to(from) < 1.0,
		"sprint held with no direction goes nowhere (%s)" % p.state_name())
	Input.action_press("move_right")
	Input.action_press("move_up")
	sprint = await top_speed(p)
	check(is_equal_approx(sprint, Player.SPRINT_SPEED) and p.velocity.x > 0.0 and p.velocity.y < 0.0,
		"two ways held together sprint the diagonal between them, no faster (%.0f)" % sprint)
	await settle(p)

	# --- what holds or walks the body ------------------------------------------------------
	Input.action_press("move_right")
	Input.action_press("sprint")
	await phys(30)
	p.talk_locked = true
	check(await until(func() -> bool: return p.velocity.length() < 1.0, 60), "a hold stops a sprint dead, like anything else the hands were doing")
	p.talk_locked = false
	await settle(p)
	Input.action_press("sprint")
	var w := WalkTo.new(p.global_position + Vector2(400.0, 0.0))
	p.input.add(w)
	var fastest := 0.0
	for i in 40:
		await get_tree().physics_frame
		fastest = maxf(fastest, p.velocity.length())
	check(fastest > 100.0 and fastest <= Player.RUN_SPEED + 1.0,
		"a walk the game is walking is a walk, sprint held or not (%.0f at most)" % fastest)
	w.cancel()
	await settle(p)

	# --- a chill ----------------------------------------------------------------------------
	p.chill_time = 10.0
	Input.action_press("move_right")
	Input.action_press("sprint")
	var chilled := await top_speed(p)
	check(is_equal_approx(chilled, Player.SPRINT_SPEED * p.speed_scale()) and chilled < Player.RUN_SPEED,
		"a chill slows a sprint by as much as it slows a walk (%.0f)" % chilled)
	p.chill_time = 0.0
	await settle(p)

	# --- the other hands -----------------------------------------------------------------------
	var bot := ComputerHands.new()
	p.input.add(bot)
	bot.move = Vector2.RIGHT
	bot.sprint = true
	sprint = await top_speed(p)
	check(is_equal_approx(sprint, Player.SPRINT_SPEED), "the computer's hands sprint it by saying so (%.0f)" % sprint)
	bot.sprint = false
	walk = await top_speed(p)
	check(is_equal_approx(walk, Player.RUN_SPEED), "and walk it by not (%.0f)" % walk)
	p.input.remove(bot)
	await settle(p)

	# A gamepad: the left stick clicked in, held, with the stick over.
	var click := InputEventJoypadButton.new()
	click.device = 0
	click.button_index = JOY_BUTTON_LEFT_STICK
	click.pressed = true
	Input.parse_input_event(click)
	var lean := InputEventJoypadMotion.new()
	lean.device = 0
	lean.axis = JOY_AXIS_LEFT_X
	lean.axis_value = 1.0
	Input.parse_input_event(lean)
	sprint = await top_speed(p)
	check(is_equal_approx(sprint, Player.SPRINT_SPEED), "a gamepad sprints with its left stick clicked in (%.0f)" % sprint)
	click = click.duplicate()
	click.pressed = false
	Input.parse_input_event(click)
	lean = lean.duplicate()
	lean.axis_value = 0.0
	Input.parse_input_event(lean)
	await settle(p)

	print("[SPRINT] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
