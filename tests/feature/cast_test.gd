extends Node
## Two buttons, one graph. The attack button runs the weapon's graph as it is,
## again and again for as long as it is held, and spends nothing; the cast
## button charges it and casts on release, with whatever the hold paid for.
## Nothing else fires it: there are no slots to arm, and the number keys do
## nothing at all.

const GameScript := preload("res://app/game.gd")
var game: Node
var sb: Sandbox
var fired: int = 0
var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[CAST] PASS ", what)
	else:
		fails += 1
		push_error("CAST FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func tap_key(code: int) -> void:
	var d := InputEventKey.new()
	d.physical_keycode = code
	d.keycode = code
	d.pressed = true
	Input.parse_input_event(d)
	await frames(4)
	var u := InputEventKey.new()
	u.physical_keycode = code
	u.keycode = code
	u.pressed = false
	Input.parse_input_event(u)
	await frames(2)

func hold_mouse(btn: int, n: int) -> void:
	var d := InputEventMouseButton.new()
	d.button_index = btn
	d.pressed = true
	Input.parse_input_event(d)
	await frames(n)
	var u := InputEventMouseButton.new()
	u.button_index = btn
	u.pressed = false
	Input.parse_input_event(u)
	await frames(3)

## Waits for the graph to come free, so one cast cannot bleed into the next.
func settle(p: Player) -> void:
	var guard := 0
	while not p.runner.is_ready() and guard < 900:
		await get_tree().process_frame
		guard += 1
	await frames(4)

func _ready() -> void:
	GameState.reset_profile()
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(6)
	game.goto_sandbox()
	await frames(20)
	sb = game.current
	var p := sb.player
	check(p.runner != null and p.runner.board == sb.board(),
		"the player carries one runner, on the weapon's graph")
	check(String(p.runner.board.root_entry().get("id", "")) == Weapons.root_part(p.weapon_id),
		"which starts with the weapon's own part (%s)" % p.runner.board.root_entry().get("id", "nothing"))
	p.runner.fired.connect(func(_x: Payload) -> void: fired += 1)
	await settle(p)

	# The attack button: the graph, as it is, for free, for as long as it is held.
	fired = 0
	p.mana = Player.MAX_MANA
	await hold_mouse(MOUSE_BUTTON_LEFT, 70)
	check(fired >= 2, "holding the attack button casts the graph again and again (%d casts)" % fired)
	check(is_equal_approx(p.mana, Player.MAX_MANA), "and spends no mana doing it (%.0f)" % p.mana)
	check(is_equal_approx(p.charge, 0.0), "nor charges anything")
	await settle(p)
	fired = 0
	await hold_mouse(MOUSE_BUTTON_LEFT, 3)
	check(fired == 1, "a tap on it is one cast (%d)" % fired)
	await settle(p)

	# The cast button: hold to charge, let go to cast.
	fired = 0
	p.mana = Player.MAX_MANA
	var d := InputEventMouseButton.new()
	d.button_index = MOUSE_BUTTON_RIGHT
	d.pressed = true
	Input.parse_input_event(d)
	await frames(40)
	check(fired == 0, "holding the cast button casts nothing while it is down (%d)" % fired)
	check(p.charge > 0.0 and p.mana < Player.MAX_MANA, "it charges, and the charge costs mana (%.0f, %.0f left)" % [p.charge, p.mana])
	# The attack button is quiet while a charge is building: it would spend the
	# cast the hold is paying for.
	var mid := InputEventMouseButton.new()
	mid.button_index = MOUSE_BUTTON_LEFT
	mid.pressed = true
	Input.parse_input_event(mid)
	await frames(6)
	var mid_up := InputEventMouseButton.new()
	mid_up.button_index = MOUSE_BUTTON_LEFT
	mid_up.pressed = false
	Input.parse_input_event(mid_up)
	await frames(2)
	check(fired == 0, "the attack button fires nothing while the cast button is held (%d)" % fired)
	var paid := p.charge
	var u := InputEventMouseButton.new()
	u.button_index = MOUSE_BUTTON_RIGHT
	u.pressed = false
	Input.parse_input_event(u)
	await frames(4)
	check(fired == 1, "and letting go casts it, once (%d)" % fired)
	check(p.cast_charge >= paid - 0.5, "with what the hold paid for (%.1f of %.1f)" % [p.cast_charge, paid])
	await settle(p)
	# And the attack button, after it, casts bare: the charge went with the cast
	# it bought.
	fired = 0
	var life_before := p.runner.cycle_ttl()
	await hold_mouse(MOUSE_BUTTON_LEFT, 3)
	check(fired == 1 and p.runner.ttl_bonus == 0 and life_before == p.runner.pass_cost,
		"an attack after a charged cast starts with the graph's own life, not the charge's (%d)" % p.runner.ttl_bonus)
	await settle(p)

	# Nothing else fires it.
	fired = 0
	for code in [KEY_1, KEY_2, KEY_3, KEY_4]:
		await tap_key(code)
	check(fired == 0, "the number keys fire nothing (%d)" % fired)
	check(not InputMap.has_action("skill_1") and not InputMap.has_action("skill_4"),
		"there are no slots to arm, so nothing is bound to arm one")

	print("[CAST] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
