extends Node
## Holding the cast button charges; letting go is what casts, with whatever the
## hold paid for. A tap is a charge of nothing, so a quick press still casts.

const GameScript := preload("res://app/game.gd")

var game: Node
var sb: Sandbox
var shots: int = 0
var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[CHG] PASS ", what)
	else:
		fails += 1
		push_error("CHG FAIL: " + what)

## Shots one cast would produce at a given charge, off the preview.
func shots_at(r: SkillRunner, bonus: int) -> int:
	var saved := r.ttl_bonus
	r.ttl_bonus = bonus
	var n: int = (r.simulate()["outputs"] as Array).size()
	r.ttl_bonus = saved
	return n

## How many follow-ups a cast at `bonus` hangs off its ON HIT: one a lap of
## the branch round its ring.
func follow_ups_at(r: SkillRunner, bonus: int) -> int:
	var saved := r.ttl_bonus
	r.ttl_bonus = bonus
	var n := 0
	var link = (r.simulate()["triggers"] as Dictionary).get("ON_HIT", null)
	while link != null:
		n += 1
		link = link.on_hit
	r.ttl_bonus = saved
	return n

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func wait(secs: float) -> void:
	var t := 0.0
	while t < secs:
		await get_tree().process_frame
		t += get_process_delta_time()

## Waits for the graph to come free, so one cast cannot bleed into the next.
func settle(p: Player) -> void:
	var guard := 0
	while not p.runner.is_ready() and guard < 900:
		await get_tree().process_frame
		guard += 1
	await frames(4)

## Holds for `secs`, releases, and reports what that one cast fired.
func hold_and_count(p: Player, secs: float) -> int:
	await settle(p)
	p.mana = Player.MAX_MANA
	p.charge = 0.0
	await frames(4)
	shots = 0
	await hold(secs)
	await settle(p)
	return shots

func press(down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_RIGHT
	e.pressed = down
	Input.parse_input_event(e)

func hold(secs: float) -> void:
	var d := InputEventMouseButton.new()
	d.button_index = MOUSE_BUTTON_RIGHT
	d.pressed = true
	Input.parse_input_event(d)
	var t := 0.0
	while t < secs:
		await get_tree().process_frame
		t += get_process_delta_time()
	var u := InputEventMouseButton.new()
	u.button_index = MOUSE_BUTTON_RIGHT
	u.pressed = false
	Input.parse_input_event(u)
	await frames(3)

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
	p.runner.fired.connect(func(_x: Payload) -> void: shots += 1)
	await frames(4)

	check(is_equal_approx(p.mana, Player.MAX_MANA), "mana starts full")
	check(is_equal_approx(p.charge, 0.0), "and nothing is charged")
	var base := p.runner.cycle_ttl()
	check(base == p.runner.pass_cost,
		"an uncharged cast is worth exactly one pass of the board (%d)" % base)

	# Holding fires nothing; the release is what casts.
	shots = 0
	var d := InputEventMouseButton.new()
	d.button_index = MOUSE_BUTTON_RIGHT
	d.pressed = true
	Input.parse_input_event(d)
	await wait(0.8)
	check(shots == 0, "holding the button casts nothing while it is down (%d)" % shots)
	check(p.charge > 0.0, "it charges instead (%.0f)" % p.charge)
	var paid := p.charge
	var u := InputEventMouseButton.new()
	u.button_index = MOUSE_BUTTON_RIGHT
	u.pressed = false
	Input.parse_input_event(u)
	await frames(3)
	check(shots > 0, "and letting go casts it (%d shot(s))" % shots)
	check(absf(p.cast_charge - paid) < 1.5,
		"with everything the hold paid for, not a bled-down remnant (%.1f of %.1f)"
			% [p.cast_charge, paid])
	await settle(p)

	# On a board with no cycle the charge has nowhere to go, and must not turn
	# one cast into several.
	check(await hold_and_count(p, 0.15) == 1, "a tap on a cycle-free board casts once")
	check(await hold_and_count(p, 1.5) == 1, "and so does a full charge on it")

	# Charging engages on every skill, cycle in the graph or not — the mana goes
	# either way. What the life is worth is then up to what the player built.
	p.mana = Player.MAX_MANA
	p.charge = 0.0
	await frames(6)
	await hold(1.2)
	check(p.mana < Player.MAX_MANA - 5.0,
		"holding a board with no cycle spends mana (%.0f left)" % p.mana)
	check(p.charge_cap() > 0.0,
		"every board has room for some charge (%.0f)" % p.charge_cap())
	# Read from what the release banked: `charge` is emptied into it on the way.
	check(p.cast_charge > 0.0, "and the release banks real charge (%.0f)" % p.cast_charge)
	check(shots_at(p.runner, int(p.cast_charge)) == shots_at(p.runner, 0),
		"but on this board it buys no extra casts (%d)" % shots_at(p.runner, 0))
	await frames(2)

	# A looping board is what has somewhere to spend it: an ON HIT whose branch
	# goes round a ring, a follow-up a lap.
	var loop := SkillBoard.new(7, 5, "Winding Blade")
	loop.set_root("BRIDGE", Vector2i(3, 2))
	loop.place("DAMAGE", Vector2i(4, 2), 0)
	loop.place("ON_HIT", Vector2i(5, 2), 0)     # on through the SLASH and out, and its branch round
	loop.place("SLASH", Vector2i(6, 2), 0)
	loop.place("DAMAGE", Vector2i(5, 3), 2)
	loop.place("BRIDGE", Vector2i(4, 3), 3)     # back into the first DAMAGE
	sb.graphs[sb.current_weapon()] = loop
	sb._apply_weapon()
	p.runner.fired.connect(func(_x: Payload) -> void: shots += 1)
	await frames(6)
	check(follow_ups_at(p.runner, SkillRunner.MAX_TTL_BONUS) > follow_ups_at(p.runner, 0),
		"charging a loop does buy more (%d -> %d follow-ups)"
			% [follow_ups_at(p.runner, 0), follow_ups_at(p.runner, SkillRunner.MAX_TTL_BONUS)])
	p.mana = Player.MAX_MANA
	p.charge = 0.0
	await frames(6)
	await hold(1.2)
	check(p.mana < Player.MAX_MANA - 5.0, "holding it spends mana (%.0f left)" % p.mana)
	await frames(2)

	# A skill still recovering cannot be charged. The wait is the board's own
	# cadence; a hold running alongside it would buy the next cast's life out of
	# time already being spent. Held across the boundary, nothing is bought
	# while it recovers and the same hold starts paying the moment it is free.
	p.mana = Player.MAX_MANA
	p.charge = 0.0
	await frames(4)
	check(not p.runner.is_ready(), "the cast that hold bought is still running")
	press(true)
	# Sampled only for as long as it really is recovering, and read before each
	# frame rather than after it. Both halves of the rule are true at once — the
	# wait buys nothing, and the same hold starts paying the instant the slot
	# comes free — so a fixed wait that outlasts the recovery measures the second
	# half and calls it a failure of the first.
	var bought := 0.0
	var spent := 0.0
	var held := 0.0
	while held < 0.4 and not p.runner.is_ready():
		bought = maxf(bought, p.charge)
		spent = maxf(spent, Player.MAX_MANA - p.mana)
		await get_tree().process_frame
		held += get_process_delta_time()
	check(bought <= 0.01, "holding a recovering skill buys no life (%.1f)" % bought)
	check(spent <= 0.01, "and spends no mana on it (%.1f)" % spent)
	var guard := 0
	while not p.runner.is_ready() and guard < 900:
		await get_tree().process_frame
		guard += 1
	await wait(0.4)
	check(p.charge > 0.0,
		"the same hold charges the moment the slot comes free (%.0f)" % p.charge)
	press(false)
	await frames(3)

	# With mana gone there is nothing left to buy life with.
	p.mana = 0.0
	p.charge = 0.0
	await frames(4)
	var before_ttl := p.runner.cycle_ttl()
	await hold(1.0)
	check(p.runner.cycle_ttl() <= before_ttl + 1,
		"with no mana, holding buys no life (%d)" % p.runner.cycle_ttl())

	# It comes back on its own.
	var t := 0.0
	while p.mana < Player.MAX_MANA and t < 12.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	check(p.mana >= Player.MAX_MANA - 0.01, "mana refills on its own (%.2fs)" % t)

	# Charge never outlives the hold that bought it.
	p.charge = Player.MAX_CHARGE_TTL
	# Waited on the clock, not on a frame count: this runs uncapped.
	var decay := 0.0
	while p.charge > 0.01 and decay < 3.0:
		await get_tree().process_frame
		decay += get_process_delta_time()
	check(p.charge <= 0.01, "charge bleeds off once released (%.2fs)" % decay)
	await frames(2)
	check(p.runner.ttl_bonus == 0, "and the board drops back to base life")

	print("[CHG] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
