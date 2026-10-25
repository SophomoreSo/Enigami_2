extends Node2D
## Stamina is the budget a dash spends. The dash keeps its own short cooldown —
## that is what makes chaining responsive — and stamina is the separate limit on
## how long the chaining may go on.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[STAM] PASS ", what)
	else:
		fails += 1
		push_error("STAM FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func spawn() -> Player:
	var p := Player.new()
	p.collision_layer = 2
	p.collision_mask = 1
	p.position = Vector2(200, 320)
	add_child(p)
	await get_tree().physics_frame
	await get_tree().physics_frame
	return p

## Presses dash once and reports whether a dash actually started. Waits out the
## cooldown afterwards but never the stamina, so a chain is limited only by the
## thing under test.
func dash(p: Player) -> bool:
	Input.action_press("dash")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("dash")
	var went := p._dash_time > 0.0
	var guard := 0
	while (p._dash_time > 0.0 or p._dash_cd > 0.0) and guard < 200:
		await get_tree().physics_frame
		guard += 1
	return went

func _ready() -> void:
	Arena.register(self)
	var p := await spawn()
	Input.action_press("move_right")

	var budget := int(Player.MAX_STAMINA / Player.DASH_STAMINA)
	check(budget >= 2, "a full bar is worth more than one dash (%d)" % budget)
	check(is_equal_approx(p.stamina, Player.MAX_STAMINA), "it starts full")

	var went := 0
	for i in budget:
		if await dash(p):
			went += 1
	check(went == budget, "a full bar spends exactly %d dashes (%d went)" % [budget, went])
	check(p.stamina < Player.DASH_STAMINA, "and leaves too little for another (%.1f)" % p.stamina)

	var extra := await dash(p)
	check(not extra, "the next press is refused")
	check(not p.can_dash(), "and can_dash() agrees")
	check(p.stamina >= 0.0, "stamina never goes negative (%.1f)" % p.stamina)

	# It comes back, but not instantly, and not past full.
	var before := p.stamina
	await frames(2)
	check(p.stamina >= before, "it only ever refills, never drains on its own")
	var t := 0.0
	var guard := 0
	while p.stamina < Player.MAX_STAMINA and guard < 900:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		guard += 1
	check(p.stamina <= Player.MAX_STAMINA + 0.01, "it stops at full (%.1f)" % p.stamina)
	check(t > 0.5 and t < 8.0, "refilling takes a real but bounded pause (%.2fs)" % t)
	check(await dash(p), "and dashing works again once it has")

	# A dash goes the way the body is held — any of the eight ways — and the
	# way it faces when nothing is held.
	Input.action_release("move_right")
	Input.action_press("move_up")
	Input.action_press("move_left")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_press("dash")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("dash")
	check(p.is_dashing() and p._dash_dir.is_equal_approx(Vector2(-1, -1).normalized()),
		"held up and left, a dash goes up and left (%s)" % str(p._dash_dir))
	Input.action_release("move_up")
	Input.action_release("move_left")
	guard = 0
	while (p._dash_time > 0.0 or p._dash_cd > 0.0 or p.velocity.length() > 1.0) and guard < 200:
		await get_tree().physics_frame
		guard += 1
	while not p.can_dash() and guard < 900:
		await get_tree().physics_frame
		guard += 1
	var faced := p.facing
	Input.action_press("dash")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("dash")
	check(p.is_dashing() and p._dash_dir.is_equal_approx(faced),
		"with nothing held, it goes the way the body faces (%s)" % str(p._dash_dir))

	print("[STAM] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
