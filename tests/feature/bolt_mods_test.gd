extends Node
## Three parts that change how a bolt flies (`Projectile`): BOUNCE, which has
## it come back off the walls and floors it meets before one ends it;
## BOOMERANG — RETURN — which turns it back toward whoever cast it at the end
## of its range, or off a wall, striking afresh on the way, and brings a thrown
## stone back into the hand; and CHAIN, which sends a fresh bolt out of each
## enemy struck at the nearest other one, a jump fewer on it.
##
## Headless: nothing here is looked at, only where things are and what they
## took.

var fails := 0
var cues: Array = []
var bot: ComputerHands
var room: Room
var p: Player

func check(ok: bool, what: String) -> void:
	if ok:
		print("[BOLT_MODS] PASS ", what)
	else:
		fails += 1
		push_error("BOLT_MODS FAIL: " + what)

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

func bolts() -> Array:
	return get_children().filter(
		func(c: Node) -> bool: return c is Projectile and not c.is_queued_for_deletion())

func rocks() -> Array:
	return get_tree().get_nodes_in_group("loose_rocks").filter(
		func(r: Node) -> bool: return not r.is_queued_for_deletion())

## Whether bolt `b` is gone. By its id rather than itself: a lambda holding a
## node that has been freed is an error every time it is called.
func gone(b: Node) -> Callable:
	if b == null:
		return func() -> bool: return true
	var id := b.get_instance_id()
	return func() -> bool:
		var n := instance_from_id(id)
		return n == null or (n as Node).is_queued_for_deletion()

## A flat room, its floor along the foot, with a wall standing up out of it a
## cell wide from the eighth row down: the twentieth column.
const WALL_X := 20
func flat_room() -> Room:
	var r := Room.new()
	add_child(r)
	r.build(Vector2i.ZERO, {"kind": "entry", "danger": 1, "region": 0, "variant": 3,
		"flat": true, "enemies": [], "loot": []}, {}, 20261021)
	for y in range(8, Room.H - 1):
		r._set_cell(WALL_X, y, 1)
	return r

## Where the open floor is: the far side of the wall, well clear of it and of
## the room's own end.
func open_floor() -> Vector2:
	return floor_at(float(WALL_X + 1) * Room.CELL + 300.0)

## Where the player stands on the floor, `x` along: the middle row of it.
func floor_at(x: float) -> Vector2:
	return Vector2(x, (float(Room.H) * 0.5 + 0.5) * Room.CELL)

func stand(at: Vector2) -> void:
	p.global_position = at
	p.velocity = Vector2.ZERO
	await frames(3)

## A monster stood at `at` and held there, out of its own mind, to be struck.
func monster(at: Vector2) -> Enemy:
	var e := Enemy.new()
	e.setup("CRAWLER", 1, "")
	e.max_health = 100000.0
	e.room = room
	room.add_child(e)
	e.health = e.max_health
	e.set_process(false)
	e.set_physics_process(false)
	e.global_position = at
	await frames(2)
	return e

## A bolt's payload: flat, `range_px` far, and nothing else on it.
func bolt(range_px: float = 600.0) -> Payload:
	var pl := Payload.new()
	pl.form = "PROJECTILE"
	pl.range_px = range_px
	return pl

## Fires `pl` from `from` along `dir` as the player's, and hands back the one
## bolt it made.
func fire(pl: Payload, from: Vector2, dir: Vector2) -> Projectile:
	Attacks.spawn(pl, {"attacker": p, "room": room, "team": p.team, "aim": dir, "origin": from,
		"lobbed": false})
	await frames(1)
	var b := bolts()
	return b[0] if b.size() == 1 else null

## A press of attack, as a hand does it, aimed `dir` of the player — once the
## last throw's wait has run down, or the press would throw nothing.
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
	seed(20261021)
	Arena.register(self)
	Cues.fired.connect(func(cue: StringName, d: Dictionary) -> void: cues.append([cue, d]))
	_the_parts()
	room = flat_room()
	p = Player.new()
	p.collision_layer = 2
	p.collision_mask = 1
	add_child(p)
	p.room = room
	p.max_health = 99999.0
	p.health = p.max_health
	p.setup_kit(["ROCK"], [Weapons.make_board("ROCK")])
	bot = ComputerHands.new()
	p.input.add(bot)
	await frames(3)
	await _bounces()
	await _comes_back()
	await _rock_comes_home()
	await _chains()
	print("[BOLT_MODS] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## --- the parts -----------------------------------------------------------------
func _the_parts() -> void:
	for row: Array in [["BOUNCE", 50, &"bounce"], ["RETURN", 51, &"returns"], ["CHAIN", 52, &"chain"]]:
		var id: String = row[0]
		check(Components.exists(id)
				and String(Components.get_def(id).get("cat", "")) == Components.CAT_PROJECTILE_BEHAVIOR
				and Components.code_of(id) == int(row[1]),
			"%s is a projectile behaviour, number %d in a code" % [id, row[1]])
		var pl := Payload.new()
		for e in Components.effects_of(id):
			if e["field"] == row[2]:
				pl.set(row[2], int(pl.get(row[2])) + int(e["value"]))
		check(int(pl.get(row[2])) == 1, "and one of it is one %s on the flow" % row[2])
	check(Attacks.WORDS.any(func(r: Array) -> bool: return r[0] == &"chain")
			and Loc.t("editor.payload.bounce", [2]) != "editor.payload.bounce",
		"the preview has words for them")

## --- BOUNCE: back off the wall, and on --------------------------------------------
func _bounces() -> void:
	var face := float(WALL_X) * Room.CELL
	await stand(floor_at(face - 120.0))
	cues.clear()
	var pl := bolt(600.0)
	pl.bounce = 1
	var b := await fire(pl, p.global_position, Vector2.RIGHT)
	check(b != null and b.bounces_left == 1, "a bolt with one BOUNCE has one to spend")
	if b == null:
		return
	check(await until(func() -> bool:
		return is_instance_valid(b) and not b.is_queued_for_deletion() and b.velocity.x < 0.0, 1.0),
		"flown into the wall, it comes back off it")
	check(is_instance_valid(b) and not room.is_solid_at(b.global_position) and b.global_position.x < face
			and heard(&"impact", "bounce") == 1 and heard(&"impact", "wall") == 0,
		"from the open side of the face, heard as a bounce and not as the wall ending it")
	check(await until(gone(b), 3.0), "and ends later, as a bolt does")
	check(heard(&"impact", "bounce") == 1, "having bounced the once (%d)" % heard(&"impact", "bounce"))
	# Without it, the wall is the end.
	cues.clear()
	var c := await fire(bolt(600.0), p.global_position, Vector2.RIGHT)
	await until(gone(c), 2.0)
	check(heard(&"impact", "wall") == 1 and heard(&"impact", "bounce") == 0, "without it the wall ends the bolt")
	# Two of them, into the floor first and then the wall: two bounces.
	cues.clear()
	var twice := bolt(600.0)
	twice.bounce = 2
	var d := await fire(twice, p.global_position, Vector2(1.0, 0.35))
	await until(gone(d), 3.0)
	check(heard(&"impact", "bounce") == 2,
		"two stacked are two bounces, off the floor and the wall (%d)" % heard(&"impact", "bounce"))

## --- BOOMERANG: back the way it came, striking again -----------------------------------
func _comes_back() -> void:
	await stand(open_floor())
	var from := p.global_position
	var e := await monster(from + Vector2(100.0, 0.0))
	# What one blow of a plain bolt takes, to count the returning one's by.
	var was := e.health
	var plain := bolt(300.0)
	plain.pierce = 1
	var c := await fire(plain, from, Vector2.RIGHT)
	await until(gone(c), 2.0)
	var one := was - e.health
	check(one > 0.0, "a plain bolt lands once on the monster in its way (%.1f)" % one)
	var pl := bolt(200.0)
	pl.returns = 1
	pl.pierce = 1
	was = e.health
	cues.clear()
	var b := await fire(pl, from, Vector2.RIGHT)
	check(b != null, "a bolt with BOOMERANG goes out")
	if b == null:
		e.queue_free()
		return
	# A box, since a lambda cannot write a captured number back.
	var far := [0.0]
	check(await until(func() -> bool:
		if is_instance_valid(b) and not b.is_queued_for_deletion():
			far[0] = maxf(far[0], b.global_position.x - from.x)
			return b.velocity.x < 0.0
		return false, 1.5), "at the end of its range it turns back")
	check(far[0] > 150.0 and far[0] < 230.0, "two hundred pixels out (%.0f)" % far[0])
	check(await until(gone(b), 2.0), "and comes home")
	check(heard(&"impact", "fade") == 0 and heard(&"impact", "wall") == 0 and heard(&"impact", "turn") == 1,
		"caught, not faded: it was heard turning and nothing else")
	check(absf((was - e.health) - 2.0 * one) < 0.5,
		"striking the monster on the way out and again on the way back (%.1f of %.1f)" % [was - e.health, 2.0 * one])
	check(is_equal_approx(p.health, p.max_health), "and not whoever it comes back to")
	e.queue_free()
	await frames(2)

## --- the rock flies back into the hand ---------------------------------------------------
func _rock_comes_home() -> void:
	var board := Weapons.make_board("ROCK")
	board.move_root(Vector2i(5, 2), 0)
	board.place("RETURN", Vector2i(6, 2), 0)
	p.setup_kit(["ROCK"], [board])
	await frames(2)
	await stand(open_floor())
	check(p.holds("ROCK"), "the rock is in hand")
	cues.clear()
	await throw(Vector2.LEFT)
	var flying := bolts()
	check(flying.size() == 1 and (flying[0] as Projectile).thrown == "ROCK" and not p.holds("ROCK"),
		"thrown, it is out of hand (%d bolts)" % flying.size())
	check(await until(func() -> bool: return p.holds("ROCK"), 3.0), "and flies back into it")
	await frames(2)
	check(bolts().is_empty() and rocks().is_empty(), "with nothing left in the air or on the floor")
	check(heard(&"rock_back") == 1 and heard(&"stone_cast") == 0,
		"heard coming back, its throw uncast (%d back, %d cast)" % [heard(&"rock_back"), heard(&"stone_cast")])
	check(is_equal_approx(p.health, p.max_health), "and the hand it comes back to unhurt")
	p.setup_kit(["ROCK"], [Weapons.make_board("ROCK")])
	await frames(2)

## --- CHAIN: out of the one struck, at the next -------------------------------------------
func _chains() -> void:
	await stand(open_floor())
	var from := p.global_position
	var a := await monster(from + Vector2(100.0, 0.0))
	var b := await monster(a.global_position + Vector2(80.0, -70.0))
	var c := await monster(b.global_position + Vector2(90.0, 60.0))
	var pl := bolt(300.0)
	pl.chain = 1
	cues.clear()
	var first := await fire(pl, from, Vector2.RIGHT)
	check(first != null, "a bolt with one CHAIN goes out")
	check(await until(func() -> bool: return b.health < b.max_health, 1.5),
		"struck, the first monster sends a bolt on at the nearest other, which is struck too")
	await until(func() -> bool: return bolts().is_empty(), 2.0)
	check(a.health < a.max_health and b.health < b.max_health and is_equal_approx(c.health, c.max_health),
		"and the chain ends there: the third is not touched")
	check(heard(&"chain") == 1, "one jump heard (%d)" % heard(&"chain"))
	for e in [a, b, c]:
		e.health = e.max_health
	var two := bolt(300.0)
	two.chain = 2
	cues.clear()
	await fire(two, from, Vector2.RIGHT)
	check(await until(func() -> bool: return c.health < c.max_health, 2.0),
		"two stacked jump twice, and the third is struck")
	await until(func() -> bool: return bolts().is_empty(), 2.0)
	check(heard(&"chain") == 2, "two jumps heard (%d)" % heard(&"chain"))
	# Nobody else in sight: no link.
	b.queue_free()
	c.queue_free()
	await frames(2)
	a.health = a.max_health
	cues.clear()
	await fire(two, from, Vector2.RIGHT)
	await until(func() -> bool: return bolts().is_empty(), 2.0)
	check(a.health < a.max_health and heard(&"chain") == 0, "with no other monster in sight the chain ends on the first")
	a.queue_free()
	await frames(2)
