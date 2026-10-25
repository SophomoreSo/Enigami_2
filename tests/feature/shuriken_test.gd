extends Node
## The shuriken (`Weapons.is_stacked`): a stack of throwing stars, spent one a
## bolt and picked back up where they struck.
##
## Every profile is handed it, and a kit carries the whole stack. A press throws
## one, lobbed — straight only with ANTI-GRAVITY on its graph — and it sticks where it strikes: in the wall,
## at the face of it, pointing the way it flew. The hands that threw it take it
## back by walking over it, but not into a stack that is already whole. Out of
## throw with nothing struck it drops, and sticks in the floor.
##
## In a monster it rides with the monster, out of reach, until the monster dies
## and lets go of it. A volley spends one a bolt, and with fewer left throws only
## what is left; a flow that is not a bolt spends nothing. With none left the
## weapon throws nothing, and says so. A kit handed out again keeps what the
## stack had left, and one fresh off the rack is whole. One left in a room
## belongs to the room, and nothing of it is written down when the room is
## left; a raid put down keeps what was in hand.
##
## Headless: nothing here is looked at, only where things are.

var fails := 0
var cues: Array = []
var bot: ComputerHands
var room: Room
var p: Player

func check(ok: bool, what: String) -> void:
	if ok:
		print("[SHURIKEN] PASS ", what)
	else:
		fails += 1
		push_error("SHURIKEN FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## By the clock: a headless run goes as fast as it likes.
func wait(secs: float) -> void:
	var t := 0.0
	while t < secs:
		await get_tree().process_frame
		t += get_process_delta_time()

## Frames until `cond` holds, or `secs` of game time: whether it did.
func until(cond: Callable, secs: float) -> bool:
	var t := 0.0
	while t < secs:
		if cond.call():
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return bool(cond.call())

func fresh() -> void:
	GameState.reset_profile()
	for n in range(1, GameState.SAVE_SLOTS + 1):
		GameState.delete_slot(n)

func heard(cue: StringName, kind: String = "") -> int:
	var n := 0
	for c in cues:
		if c[0] == cue and (kind == "" or String((c[1] as Dictionary).get("kind", "")) == kind):
			n += 1
	return n

func stars() -> Array:
	return get_tree().get_nodes_in_group("stuck_shurikens").filter(
		func(s: Node) -> bool: return not s.is_queued_for_deletion())

func bolts() -> Array:
	return get_children().filter(
		func(c: Node) -> bool: return c is Projectile and not c.is_queued_for_deletion())

func clear_stars() -> void:
	for s in stars():
		s.queue_free()
	await frames(2)

## A flat room, its floor along the foot, with a wall standing up out of it a
## cell wide from the eighth row down: the twentieth column.
const WALL_X := 20
func flat_room() -> Room:
	var r := Room.new()
	add_child(r)
	r.build(Vector2i.ZERO, {"kind": "entry", "danger": 1, "region": 0, "variant": 3,
		"flat": true, "enemies": [], "loot": []}, {}, 20261004)
	for y in range(8, Room.H - 1):
		r._set_cell(WALL_X, y, 1)
	return r

## Where the open floor is: the far side of the wall, further from it and from
## the room's own end than a shuriken flies.
func open_floor() -> Vector2:
	return floor_at(float(WALL_X + 1) * Room.CELL + 360.0)

## Where the player stands on the floor, `x` along: the middle row of it.
func floor_at(x: float) -> Vector2:
	return Vector2(x, (float(Room.H) * 0.5 + 0.5) * Room.CELL)

func stand(at: Vector2) -> void:
	p.global_position = at
	p.velocity = Vector2.ZERO
	await frames(3)

## A press of attack, as a hand does it, aimed level `dir` of the player — once
## the last throw's wait has run down, or the press would throw nothing.
func throw(dir: Vector2) -> void:
	await until(func() -> bool: return p.runner.is_ready(), 3.0)
	bot.point_at(p.global_position + dir * 300.0)
	await frames(2)
	bot.attack = true
	await frames(3)
	bot.attack = false
	await frames(2)

func _ready() -> void:
	fresh()
	seed(20261004)
	Arena.register(self)
	Cues.fired.connect(func(cue: StringName, d: Dictionary) -> void: cues.append([cue, d]))
	_the_weapon()
	room = flat_room()
	p = Player.new()
	p.collision_layer = 2
	p.collision_mask = 1
	add_child(p)
	p.room = room
	p.max_health = 99999.0
	p.health = p.max_health
	p.setup_kit(["SHURIKEN"], [Weapons.make_board("SHURIKEN")])
	bot = ComputerHands.new()
	p.input.add(bot)
	await frames(3)
	await _lobbed()
	await _straight_into_the_wall()
	await _taken_back()
	await _out_of_throw()
	await _in_a_monster()
	await _volleys()
	await _none_left()
	await _a_new_kit()
	_left_in_the_room()
	p.queue_free()
	room.queue_free()
	await frames(2)
	await _put_down_and_picked_up()
	print("[SHURIKEN] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## --- the weapon --------------------------------------------------------------------
func _the_weapon() -> void:
	check(Weapons.is_stacked("SHURIKEN") and Weapons.stack_of("SHURIKEN") > 1
			and not Weapons.is_thrown("SHURIKEN") and not Weapons.is_stacked("ROCK"),
		"the shuriken is a stack of %d, and not the rock's one thrown weapon" % Weapons.stack_of("SHURIKEN"))
	check(Weapons.root_part("SHURIKEN") == "PROJECTILE" and Weapons.uses_lobbed_shots("SHURIKEN"),
		"its graph throws a bolt, lobbed, as every thrown thing is")
	check(GameState.owned_weapons.has("SHURIKEN") and GameState.HANDED_OUT.has("SHURIKEN"),
		"every profile is handed it")

## --- thrown, it is lobbed: it arcs, and comes down on the way ------------------------
## A plain throw at the wall from close by meets it: a wall stops a throw
## whatever its arc. The star is taken back off the wall and the
## stack made whole again, so what follows finds the kit as it was handed out.
func _lobbed() -> void:
	check(p.stock_of("SHURIKEN") == Weapons.stack_of("SHURIKEN") and p.can_cast() and p.weapon_hands() == p,
		"a kit carries the whole stack (%d)" % p.stock_of("SHURIKEN"))
	var face := float(WALL_X) * Room.CELL
	await stand(floor_at(face - 120.0))
	await throw(Vector2.RIGHT)
	var flying := bolts()
	check(flying.size() == 1 and (flying[0] as Projectile).sticks == "SHURIKEN"
			and (flying[0] as Projectile).gravity > 0.0,
		"a press throws one, lobbed (%d bolts)" % flying.size())
	await until(func() -> bool: return not stars().is_empty(), 2.0)
	var all := stars()
	var hit: StuckShuriken = all[0] if all.size() == 1 else null
	check(hit != null and hit.stuck() and not room.is_solid_at(hit.global_position)
			and room.is_solid_at(hit.global_position + hit.heading * 3.0)
			and absf(hit.global_position.x - face) < StuckShuriken.RADIUS,
		"the wall stops it on the way, whatever its arc: stuck in the face, point in (%.0f from it)"
			% (absf(hit.global_position.x - face) if hit != null else -1.0))
	for s in all:
		s.queue_free()
	p.stock["SHURIKEN"] = Weapons.stack_of("SHURIKEN")
	await frames(2)
	# ANTI-GRAVITY on its graph, for the rest: the throws fly straight.
	var straight := Weapons.make_board("SHURIKEN")
	straight.move_root(Vector2i(5, 2), 0)
	straight.place("ANTI_GRAVITY", Vector2i(6, 2), 0)
	p.setup_kit(["SHURIKEN"], [straight])
	await frames(2)

## --- weightless, it flies flat and sticks at the face of the wall --------------------
func _straight_into_the_wall() -> void:
	check(p.stock_of("SHURIKEN") == Weapons.stack_of("SHURIKEN") and p.can_cast() and p.weapon_hands() == p,
		"the kit handed out again carries the whole stack (%d)" % p.stock_of("SHURIKEN"))
	var face := float(WALL_X) * Room.CELL
	await stand(floor_at(face - 120.0))
	cues.clear()
	var from := p.global_position
	await throw(Vector2.RIGHT)
	var flying := bolts()
	check(flying.size() == 1 and (flying[0] as Projectile).sticks == "SHURIKEN"
			and is_zero_approx((flying[0] as Projectile).gravity),
		"with ANTI-GRAVITY on its graph a press throws one with no arc (%d bolts)" % flying.size())
	check(p.stock_of("SHURIKEN") == Weapons.stack_of("SHURIKEN") - 1, "and the stack is one short (%d)" % p.stock_of("SHURIKEN"))
	check(heard(&"attack") == 1 and String((cues[0][1] as Dictionary).get("thrown", "")) == "SHURIKEN",
		"it is heard as a throw, not a shot")
	# Off level from where it set off, which is the hand rather than wherever
	# the body had settled when the press began.
	var level := (flying[0] as Projectile).global_position.y if not flying.is_empty() else from.y
	var drift := 0.0
	await until(func() -> bool:
		for b: Projectile in bolts():
			drift = maxf(drift, absf(b.global_position.y - level))
		return not stars().is_empty(), 2.0)
	check(drift < 0.5, "it flies in a straight line (%.2f px off level)" % drift)
	var all := stars()
	check(all.size() == 1 and (all[0] as StuckShuriken).stuck(), "and sticks (%d)" % all.size())
	if all.is_empty():
		return
	var s: StuckShuriken = all[0]
	check(not room.is_solid_at(s.global_position) and room.is_solid_at(s.global_position + Vector2(2.0, 0.0))
			and absf(s.global_position.x - face) < 2.0,
		"at the face of the wall it struck (%.1f, the face at %.0f)" % [s.global_position.x, face])
	check(absf(s.global_position.y - level) < 0.5 and s.heading.dot(Vector2.RIGHT) > 0.999,
		"at the height it flew at, pointing the way it went")
	await wait(0.5)
	check(stars().size() == 1 and s.global_position.x > face - 2.0, "and stays there")

## --- walked over, it is back in the stack ---------------------------------------------
func _taken_back() -> void:
	var all := stars()
	if all.is_empty():
		return
	var s: StuckShuriken = all[0]
	var had := p.stock_of("SHURIKEN")
	cues.clear()
	await stand(Vector2(s.global_position.x - 14.0, p.global_position.y))
	check(await until(func() -> bool: return p.stock_of("SHURIKEN") == had + 1, 1.0),
		"walked over, it is one more in the stack (%d)" % p.stock_of("SHURIKEN"))
	await frames(2)
	check(stars().is_empty() and heard(&"shuriken_back") == 1, "and out of the wall")
	# Not into a stack that is already whole: then it stays where it is.
	p.stock["SHURIKEN"] = Weapons.stack_of("SHURIKEN")
	var spare := StuckShuriken.lodge("SHURIKEN", p.global_position, Vector2.RIGHT, room, p)
	await wait(0.6)
	check(is_instance_valid(spare) and not spare.is_queued_for_deletion()
			and p.stock_of("SHURIKEN") == Weapons.stack_of("SHURIKEN"),
		"with the stack whole, one walked over stays where it is")
	p.stock["SHURIKEN"] = Weapons.stack_of("SHURIKEN") - 1
	check(await until(func() -> bool: return stars().is_empty(), 1.0),
		"and is taken the moment there is room for it")
	await clear_stars()

## --- out of throw, it drops into the floor ---------------------------------------------
func _out_of_throw() -> void:
	await stand(open_floor())
	var from := p.global_position
	await throw(Vector2.LEFT)
	check(await until(func() -> bool:
		var all := stars()
		return all.size() == 1 and (all[0] as StuckShuriken).stuck(), 3.0), "thrown at nothing, it comes down and sticks")
	var all := stars()
	if all.is_empty():
		return
	var s: StuckShuriken = all[0]
	check(s.global_position.x < from.x - 100.0 and not room.is_solid_at(s.global_position)
			and is_zero_approx(s.height),
		"out at the end of its throw, down in the floor (%.0f px out, %.1f up)" % [from.x - s.global_position.x, s.height])
	await clear_stars()

## --- in a monster it rides with it, until it dies --------------------------------------
func _in_a_monster() -> void:
	await stand(open_floor())
	var e := Enemy.new()
	e.setup("CRAWLER", 1, "")
	e.max_health = 100000.0
	e.room = room
	room.add_child(e)
	e.health = e.max_health
	# Held where it is put: a monster walking itself about between frames would
	# leave a frame's step between it and what rides in it.
	e.set_process(false)
	e.set_physics_process(false)
	e.global_position = p.global_position + Vector2(90.0, 0.0)
	await frames(2)
	await throw(Vector2.RIGHT)
	check(await until(func() -> bool: return not stars().is_empty(), 1.0), "thrown at a monster, it sticks in it")
	var all := stars()
	if all.is_empty():
		e.queue_free()
		return
	var s: StuckShuriken = all[0]
	check(s.host == e and not s.stuck(), "in the monster, not in the floor behind it")
	var off := s.global_position - e.global_position
	e.global_position += Vector2(60.0, -30.0)
	await frames(2)
	check((s.global_position - e.global_position).is_equal_approx(off), "and rides with it where it goes")
	var had := p.stock_of("SHURIKEN")
	await stand(Vector2(s.global_position.x, p.global_position.y))
	await wait(0.5)
	check(p.stock_of("SHURIKEN") == had and is_instance_valid(s) and s.host == e, "out of reach while it is in it")
	e.apply_damage(1e9)
	check(await until(func() -> bool: return is_instance_valid(s) and s.stuck(), 3.0),
		"the monster dead, it lets go of it, and it comes down and sticks")
	if is_instance_valid(s):
		check(s.height == 0.0 and not room.is_solid_at(s.global_position), "on the floor at its feet")
		await stand(s.global_position)
		check(await until(func() -> bool: return p.stock_of("SHURIKEN") == had + 1, 1.0),
			"and is taken back from there (%d)" % p.stock_of("SHURIKEN"))
	if is_instance_valid(e):
		e.queue_free()
	await clear_stars()

## --- a volley spends one a bolt ------------------------------------------------------
func _volleys() -> void:
	await stand(open_floor())
	p.stock["SHURIKEN"] = Weapons.stack_of("SHURIKEN")
	var three := Weapons.base_payload("SHURIKEN")
	three.form = "PROJECTILE"
	three.duplicates = 3
	p._on_fired(three, "SHURIKEN")
	check(bolts().size() == 3 and p.stock_of("SHURIKEN") == Weapons.stack_of("SHURIKEN") - 3,
		"a volley of three throws three, and spends three (%d bolts, %d left)" % [bolts().size(), p.stock_of("SHURIKEN")])
	await wait(1.5)
	check(stars().size() == 3, "and all three stick (%d)" % stars().size())
	await clear_stars()
	p.stock["SHURIKEN"] = 2
	var again := Weapons.base_payload("SHURIKEN")
	again.form = "PROJECTILE"
	again.duplicates = 3
	p._on_fired(again, "SHURIKEN")
	check(bolts().size() == 2 and p.stock_of("SHURIKEN") == 0,
		"with two left it throws the two (%d bolts)" % bolts().size())
	await wait(1.5)
	await clear_stars()
	p.stock["SHURIKEN"] = 5
	var cut := Weapons.base_payload("SHURIKEN")
	cut.form = "SLASH"
	p._on_fired(cut, "SHURIKEN")
	check(p.stock_of("SHURIKEN") == 5, "and a flow that is not a bolt spends none")
	await wait(0.3)

## --- with none left, nothing goes -----------------------------------------------------
func _none_left() -> void:
	p.stock["SHURIKEN"] = 0
	check(not p.can_cast() and p.weapon_hands() == null, "with none left it cannot be thrown, and the hand is empty")
	cues.clear()
	bot.point_at(p.global_position + Vector2(300.0, 0.0))
	bot.attack = true
	await wait(0.6)
	bot.attack = false
	await frames(2)
	check(heard(&"attack") == 0 and bolts().is_empty(), "held down, the button throws nothing")
	check(heard(&"refused", "thrown") == 1, "and says so once for the press (%d)" % heard(&"refused", "thrown"))
	var empty := Weapons.base_payload("SHURIKEN")
	empty.form = "PROJECTILE"
	p._on_fired(empty, "SHURIKEN")
	check(bolts().is_empty(), "nor does a lap that comes round after the last has gone")

## --- a kit handed out again ------------------------------------------------------------
func _a_new_kit() -> void:
	p.stock["SHURIKEN"] = 4
	p.setup_kit(["SHURIKEN"], [Weapons.make_board("SHURIKEN")])
	check(p.stock_of("SHURIKEN") == 4, "a kit handed out again keeps what the stack had left")
	p.setup_kit(["SWORD"], [Weapons.make_board("SWORD")])
	check(p.stock_of("SHURIKEN") == 0 and not p.stock.has("SHURIKEN"), "one without it carries none")
	p.setup_kit(["SWORD", "SHURIKEN"], [Weapons.make_board("SWORD"), Weapons.make_board("SHURIKEN")], 1)
	check(p.stock_of("SHURIKEN") == Weapons.stack_of("SHURIKEN"), "and one with it again, fresh off the rack, is whole")

## --- left in a room -------------------------------------------------------------------
func _left_in_the_room() -> void:
	var s := StuckShuriken.lodge("SHURIKEN", p.global_position + Vector2(40.0, 0.0), Vector2.RIGHT, room, p)
	check(s.get_parent() == room, "a shuriken where it struck belongs to the room, and goes with it")
	room.save_state()
	check(not room.data.has("rocks") and not str(room.data).contains("SHURIKEN"),
		"and the room writes nothing of it down, so one left behind is gone")

## --- a raid put down keeps what was in hand -------------------------------------------
func _put_down_and_picked_up() -> void:
	fresh()
	GameState.deploy(["SHURIKEN", "SWORD"])
	var raid := Raid.new()
	add_child(raid)
	await frames(4)
	check(raid.player.stock_of("SHURIKEN") == Weapons.stack_of("SHURIKEN"), "a raid walks in with the whole stack")
	raid.player.stock["SHURIKEN"] = 3
	GameState.park_raid(raid.park())
	raid.queue_free()
	await frames(2)
	GameState.load_slot(GameState.slot)
	var back := Raid.new()
	add_child(back)
	await frames(4)
	check(back.player.stock_of("SHURIKEN") == 3, "and put down with three in hand, is walked back into with three")
	back.queue_free()
	await frames(2)
	GameState.die()
