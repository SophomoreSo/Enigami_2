extends Node
## POSSESS: a hit that puts the player's hands into the monster it strikes.
##
## Played on the bench, which has a floor, monsters to put down and somebody to
## talk to: the monster taken and on the player's side, the body left standing
## where it was and still hunted, the monster walking under the player's keys,
## passing for one of them until it hurts one of them, hurt by
## the rest once it has, taking the weapon out of the body's hands, talking to
## the Sage — and every way out: the time, the key, the monster dying, a hop to
## the next one, and the body dying.

var fails := 0
var bench: Sandbox
var player: Player
var hands: ComputerHands

func check(ok: bool, what: String) -> void:
	if ok:
		print("[POSSESS] PASS ", what)
	else:
		fails += 1
		push_error("POSSESS FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## Frames until `cond` holds, or `secs` of game time: whether it did.
func until(cond: Callable, secs: float) -> bool:
	var t := 0.0
	while t < secs:
		if cond.call():
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return bool(cond.call())

## Game time, waited out by the clock rather than by counting frames.
func wait(secs: float) -> void:
	var t := 0.0
	while t < secs:
		await get_tree().process_frame
		t += get_process_delta_time()

## A monster of `kind` put down on the bench's floor in column `x`, facing
## `dir`, 1 for right and -1 for left.
func monster(kind: String, x: int, dir: int = 1) -> Enemy:
	bench._spawn(kind, 1, floor_point(x))
	var e: Enemy = null
	for c in bench.get_children():
		if c is Enemy and (c as Enemy).kind == kind and not (c as Enemy).dead and (c as Enemy).pilot == null:
			e = c
	e.max_health = 99999.0
	e.health = 99999.0
	e.face(Vector2(float(dir), 0.0))
	e._glance = 999.0
	return e

## A hit carrying POSSESS for `secs`, landed on `e` by `by`.
func possess_hit(e: Enemy, secs: float, by: Actor, damage: float = 1.0) -> void:
	var p := Payload.new()
	p.damage = damage
	p.possess = secs
	Attacks.resolve_hit(p, e, e.global_position, Vector2.RIGHT, by, bench.room, by.team)

## The middle of the bench's floor, in column `x`.
func floor_point(x: int) -> Vector2:
	return bench.room.cell_center(x, 11)

func clear() -> void:
	for c in bench.get_children():
		if c is Enemy:
			c.queue_free()
	Attacks.clear_in_flight(bench)
	await frames(2)

func _ready() -> void:
	GameState.reset_profile()
	_the_part()
	bench = Sandbox.new()
	add_child(bench)
	await frames(6)
	player = bench.player
	player.global_position = floor_point(8)
	hands = ComputerHands.new()
	player.input.add(hands)
	await clear()
	await _taking_one()
	await _under_the_keys()
	await _passing_for_one_of_them()
	await _the_weapon()
	await _ways_out()
	await _talking()
	bench.queue_free()
	await frames(3)
	await _the_body_dies()
	print("[POSSESS] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## --- the part ---------------------------------------------------------------
func _the_part() -> void:
	check(Components.exists("POSSESS") and Components.get_def("POSSESS")["cat"] == Components.CAT_STATES,
		"POSSESS is a STATES part")
	check(Components.code_of("POSSESS") >= 0, "with a number in a shared code (%d)" % Components.code_of("POSSESS"))
	var b := SkillBoard.new(3, 5, "test")
	b.set_root("PROJECTILE")
	b.place("POSSESS", Vector2i(1, 2), 0)
	b.place("POSSESS", Vector2i(2, 2), 0)
	var r := SkillRunner.new(b)
	r.base_payload_provider = func() -> Payload: return Weapons.base_payload("GUN")
	var outs: Array = r.simulate()["outputs"]
	var p: Payload = outs[0] if outs.size() > 0 else null
	check(p != null and is_equal_approx(p.possess, 10.0), "each one stacked holds it 5 seconds longer (%.0fs)" % (p.possess if p else -1.0))
	check(p != null and Attacks.summary(p).contains(Loc.t("editor.payload.possess", [10.0])),
		"and the graph's line says for how long (%s)" % (Attacks.summary(p) if p else ""))
	var boss := Enemy.new()
	boss.setup("ARBITER")
	var crawler := Enemy.new()
	crawler.setup("CRAWLER")
	check(not Player.can_possess(boss) and Player.can_possess(crawler), "a boss cannot be taken; anything else can")
	boss.free()
	crawler.free()

## --- a hit takes it -----------------------------------------------------------
var vessel: Enemy

func _taking_one() -> void:
	vessel = monster("CRAWLER", 14, -1)
	await frames(4)
	var body_at := player.global_position
	var hurt := [0.0]
	vessel.damaged.connect(func(_a: Actor, n: float) -> void: hurt[0] += n)
	possess_hit(vessel, 30.0, player, 20.0)
	await frames(2)
	check(player.possessing == vessel and vessel.pilot == player and player.vessel() == vessel,
		"a POSSESS hit puts the player's hands into the monster struck")
	check(hurt[0] == 0.0 and is_equal_approx(vessel.health, vessel.max_health),
		"and does it no harm, whatever the hit carried (%.0f taken)" % hurt[0])
	check(vessel.team == player.team, "which is on the player's side now")
	check(player.input.body == vessel, "and their input line drives it")
	check(not Attacks.targets(player.team).has(vessel) and Attacks.targets(1).has(vessel),
		"so their attacks pass it by, and the monsters' can hurt it")
	check(player.global_position.distance_to(body_at) < 2.0, "the body stays where it was")

## --- under the player's keys ---------------------------------------------------
func _under_the_keys() -> void:
	var body_x := player.global_position.x
	var x0 := vessel.global_position.x
	hands.move = Vector2.RIGHT
	await wait(0.4)
	hands.move = Vector2.ZERO
	check(vessel.global_position.x > x0 + 20.0, "the keys walk the monster (%.0fpx)" % (vessel.global_position.x - x0))
	check(absf(player.global_position.x - body_x) < 1.0, "and the body does not move with them")
	check(vessel.facing.x > 0.0, "facing the way it walks")
	var y0 := vessel.global_position.y
	hands.move = Vector2.DOWN
	await wait(0.3)
	hands.move = Vector2.ZERO
	check(vessel.global_position.y > y0 + 15.0 and vessel.facing.y > 0.0,
		"and down the floor as well, facing that way (%.0fpx)" % (vessel.global_position.y - y0))

## --- passing for one of them, until it hurts one of them -----------------------
func _passing_for_one_of_them() -> void:
	# A monster beside the vessel, facing it, the body further off behind it.
	var watcher := monster("CRAWLER", int(vessel.global_position.x / Room.CELL) + 3, -1)
	await frames(6)
	check(not watcher._hunts(vessel) and watcher._nearest_quarry() == player,
		"another monster takes the possessed one for one of them, and hunts the body instead")
	check(watcher.target != vessel, "(it is not after the monster beside it)")
	# The monster's own attack: either button.
	var fired := [false]
	vessel.runner.fired.connect(func(_p: Payload) -> void: fired[0] = true)
	hands.attack = true
	check(await until(func() -> bool: return fired[0], 2.0), "a button attacks with the monster's own attack")
	hands.attack = false
	await frames(4)
	check(not vessel.revealed and not watcher._hunts(vessel) and watcher.target != vessel,
		"and an attack that hurts none of them gives nothing away")
	# A hit of its that hurts one of them does.
	var cut := Payload.new()
	cut.damage = 5.0
	Attacks.resolve_hit(cut, watcher, watcher.global_position, Vector2.RIGHT, vessel, bench.room, vessel.team)
	check(vessel.revealed, "hurting one of them gives it away")
	check(watcher._hunts(vessel), "so the monsters hunt it after")
	check(await until(func() -> bool: return watcher.target == vessel, 1.0),
		"and the one beside it, nearer to it than to the body, goes after it")
	# Hurt by the monsters' attacks.
	var hp := vessel.health
	var bite := Payload.new()
	bite.damage = 10.0
	Attacks.resolve_hit(bite, vessel, vessel.global_position, Vector2.LEFT, watcher, bench.room, watcher.team)
	check(vessel.health < hp, "and their attacks hurt it (%.0f lost)" % (hp - vessel.health))
	watcher.queue_free()
	await frames(2)

## --- the weapon ----------------------------------------------------------------
func _the_weapon() -> void:
	hands.use()
	await frames(3)
	check(not player.vessel_armed, "away from the body, interact takes nothing")
	vessel.global_position = player.global_position + Vector2(30, 0)
	vessel.velocity = Vector2.ZERO
	await frames(2)
	check(player.can_take_weapon(), "beside the body, the weapon is there to take")
	hands.use()
	await frames(3)
	check(player.vessel_armed, "and interact takes it out of the body's hands")
	# Now the buttons cast the weapon's graph — the sword's lunge — from the
	# monster.
	vessel.global_position = floor_point(20)
	await frames(2)
	var own := [false]
	vessel.runner.fired.connect(func(_p: Payload) -> void: own[0] = true)
	var from := [null]
	player.cast_fired.connect(func() -> void: from[0] = player.vessel())
	hands.point_at(vessel.global_position + Vector2(200, 0))
	hands.attack = true
	check(await until(func() -> bool: return from[0] != null, 2.0), "a button casts the weapon's graph")
	hands.attack = false
	check(from[0] == vessel, "from the monster")
	var lunge: DashSlash = null
	for c in bench.get_children():
		if c is DashSlash:
			lunge = c
	check(lunge != null and lunge.attacker == vessel, "so the sword's lunge carries the monster")
	check(not own[0], "and not the monster's own attack")
	await wait(0.3)

## --- every way out ---------------------------------------------------------------
func _ways_out() -> void:
	# The key.
	hands.step_out()
	await frames(3)
	check(player.possessing == null and player.vessel() == player and player.input.body == player,
		"the step-out key puts the hands back in the body")
	check(vessel.pilot == null and vessel.team == 1 and vessel.stunned(),
		"and leaves the monster one of them again, stunned (%.1fs)" % vessel.stun_time)
	check(not player.vessel_armed, "with the weapon back in the body's hands")
	var bx := player.global_position.x
	hands.move = Vector2.RIGHT
	await wait(0.3)
	hands.move = Vector2.ZERO
	check(player.global_position.x > bx + 20.0, "and the keys walk the body again")

	# The time.
	vessel.stun_time = 0.0
	possess_hit(vessel, 0.4, player)
	check(player.possessing == vessel, "(taken again, for 0.4s)")
	check(await until(func() -> bool: return player.possessing == null, 1.5), "when the time runs out the hands come back")

	# The monster dying.
	vessel.stun_time = 0.0
	possess_hit(vessel, 30.0, player)
	vessel.health = 1.0
	vessel.apply_damage(50.0)
	check(await until(func() -> bool: return player.possessing == null, 0.5), "a monster killed with the player in it puts them back")
	await clear()

	# A hop: from inside one monster, a POSSESS hit on another.
	var a := monster("CRAWLER", 18)
	var b := monster("HOPPER", 24)
	await frames(4)
	possess_hit(a, 30.0, player)
	possess_hit(b, 30.0, a)
	await frames(2)
	check(player.possessing == b and player.input.body == b, "from inside one monster, a POSSESS hit hops to the next")
	check(a.pilot == null and a.team == 1 and a.stunned(), "and the first is let go of, stunned")
	player.release()
	await clear()

## --- talking ----------------------------------------------------------------------
func _talking() -> void:
	var sage := bench.npc
	var e := monster("CRAWLER", 16)
	await frames(4)
	player.global_position = floor_point(6)
	await frames(2)
	possess_hit(e, 30.0, player)
	# Next to the Sage, with the body out of reach of them.
	e.global_position = sage.global_position + Vector2(-50, 0)
	e.velocity = Vector2.ZERO
	await frames(4)
	check(sage.in_range and player.global_position.distance_to(sage.global_position) > Npc.TALK_RANGE,
		"the Sage is in reach of the monster, and not of the body")
	for down in [true, false]:
		var press := InputEventAction.new()
		press.action = "interact"
		press.pressed = down
		Input.parse_input_event(press)
		await frames(2)
	check(await until(func() -> bool: return sage.is_talking(), 3.0),
		"interact there talks to them, from inside the monster")
	check(e.global_position.distance_to(sage.global_position) <= Npc.TALK_RANGE
			and player.global_position.distance_to(sage.global_position) > Npc.TALK_RANGE,
		"the monster was walked over to talk, and the body stayed where it was")
	sage.end_conversation()
	await frames(3)
	player.release()
	await clear()

## --- the body dies -------------------------------------------------------------------
## In a raid, where it matters: the body is hunted while the hands are away,
## and dying is the raid lost.
func _the_body_dies() -> void:
	GameState.deploy("SWORD")
	var raid := Raid.new()
	var ended := [""]
	raid.finished.connect(func(result: String, _payload: Dictionary) -> void:
		ended[0] = result
		raid.queue_free())
	add_child(raid)
	await frames(4)
	var body := raid.player
	var e := Enemy.new()
	e.setup("CRAWLER", 1, "")
	e.room = raid.room
	e.collision_layer = 4
	e.collision_mask = 1
	raid.room.add_child(e)
	e.global_position = body.global_position + Vector2(120, 0)
	e.max_health = 99999.0
	e.health = 99999.0
	await frames(2)
	var exit_at := raid.room.to_global(raid.room.extraction_rect().get_center())
	body.global_position = exit_at
	await frames(3)
	check(raid.room.extract_offered, "(the body stands in an exit that would take it)")
	check(body.possess(e, 30.0), "(in a raid, the hands go into a monster)")
	await frames(3)
	check(not raid.room.extract_offered, "with the hands in a monster, the exit does not offer to take the body")
	check(not raid._can_wander(e), "a possessed monster does not wander off through a door")
	var released := [false]
	body.released.connect(func(_m) -> void: released[0] = true)
	body.invuln = 0.0
	body.health = 1.0
	body.apply_damage(50.0)
	# At once: the raid that is lost frees the room, and the monster in it.
	check(released[0] and e.pilot == null and e.team == 1, "the body dying with the hands elsewhere brings them back to it")
	check(ended[0] == "died", "and the raid is lost (%s)" % ended[0])
	await frames(2)
	await frames(2)
	GameState.reset_profile()
