extends Node2D
## A pit in the floor (`Room.pits`, `MadeRoom.PIT`): the player who walks into
## one falls — loses a little health, is held a moment, and stands again where
## they last stood on floor — and a dash carries them over it; a monster that
## walks is stopped at its edge, since to it a pit is a wall, and one that
## flies is not. A bolt flies over.
##
## Headless: nothing here is looked at.

var fails := 0
var cues: Array = []

func check(ok: bool, what: String) -> void:
	if ok:
		print("[PIT] PASS ", what)
	else:
		fails += 1
		push_error("PIT FAIL: " + what)

func phys(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func until(cond: Callable, limit: int = 240) -> bool:
	for i in limit:
		if cond.call():
			return true
		await get_tree().physics_frame
	return bool(cond.call())

func heard(cue: StringName) -> int:
	var n := 0
	for c in cues:
		if c == cue:
			n += 1
	return n

func _ready() -> void:
	Arena.register(self)
	Cues.fired.connect(func(cue: StringName, _d: Dictionary) -> void: cues.append(cue))
	# A room with a pit across its middle, floor either side: two cells across,
	# the most a room rolls (`Room`), which a dash from its edge carries over.
	var room := MadeRoom.new()
	room.plan = PackedStringArray([
		"################",
		"#..............#",
		"#..............#",
		"#.....OO.......#",
		"#.....OO.......#",
		"#.....OO.......#",
		"#..............#",
		"#..............#",
		"################",
	])
	add_child(room)
	room.stand()
	check(room.is_pit(6, 4) and not room.is_solid(6, 4) and not room.is_pit(2, 4) and not room.is_pit(0, 4),
		"a pit is open, and not floor; the floor and the walls are not pits")
	check(room.is_pit_at(room.cell_center(7, 3)) and room.is_floor_at(room.cell_center(2, 2))
			and not room.is_floor_at(room.cell_center(7, 3)) and not room.is_floor_at(room.cell_center(0, 0)),
		"and a point over one is over one")
	check(room.pit_body != null and room.pit_body.collision_layer == Room.PIT_BIT and room.pit_body.get_child_count() > 0,
		"the pits stand on their own collision layer")
	check(MadeRoom.things().has(MadeRoom.PIT), "a pit is a thing the map creator lays")

	var p := Player.new()
	p.collision_layer = 2
	p.collision_mask = 1
	add_child(p)
	p.room = room
	p.global_position = room.cell_center(3, 4)
	await phys(2)
	var hands := ComputerHands.new()
	p.input.add(hands)
	var hp := p.health
	var stood := p.global_position

	# Walked into: the fall.
	hands.move = Vector2.RIGHT
	check(await until(func() -> bool: return p.falling(), 120), "walking into the pit, the player falls")
	hands.move = Vector2.ZERO
	check(heard(&"fell") == 1, "and it is heard (%d)" % heard(&"fell"))
	check(is_equal_approx(p.health, hp - Player.PIT_DAMAGE), "it costs %.0f health (%.0f lost)" % [Player.PIT_DAMAGE, hp - p.health])
	check(room.is_pit_at(p.fell_at) and not room.is_pit_at(p.global_position) and p.global_position.x < room.cell_center(6, 4).x,
		"the body is back on the floor it left, short of the pit's edge (%s)" % str(p.global_position))
	check(p.controls_locked(), "and held while it falls")
	var at := p.global_position
	hands.move = Vector2.RIGHT
	await phys(6)
	check(p.global_position.is_equal_approx(at), "a push does nothing while it is held")
	check(await until(func() -> bool: return not p.falling(), 120), "it stands again")
	check(not p.controls_locked() and p.invuln > 0.0, "with the hands back on it and a moment's grace")
	hands.move = Vector2.ZERO
	await until(func() -> bool: return p.velocity.length() < 1.0)
	check(p.global_position.x < room.cell_center(6, 4).x - 8.0,
		"and stands clear of the edge, where it last stood on floor (%.0f)" % p.global_position.x)

	# Dashed across from its edge: no fall. A dash is DASH_SPEED for DASH_TIME,
	# a little more than the pit is wide.
	p.global_position = Vector2(float(6 * Room.CELL) - 6.0, room.cell_center(4, 4).y)
	p.invuln = 0.0
	await phys(2)
	await until(func() -> bool: return p.can_dash())
	hp = p.health
	cues.clear()
	hands.move = Vector2.RIGHT
	hands.dash()
	await phys(2)
	check(p.is_dashing(), "(a dash starts)")
	await until(func() -> bool: return not p.is_dashing())
	hands.move = Vector2.ZERO
	await phys(4)
	check(heard(&"fell") == 0 and is_equal_approx(p.health, hp) and p.global_position.x > float(8 * Room.CELL),
		"a dash carries the player over the pit to the floor beyond (%.0f)" % p.global_position.x)

	# A monster that walks is stopped at the edge; one that flies crosses.
	var crawler := Enemy.new()
	crawler.setup("CRAWLER", 1, "")
	crawler.room = room
	crawler.collision_layer = 4
	crawler.collision_mask = 1 | Room.PIT_BIT
	add_child(crawler)
	crawler.global_position = room.cell_center(3, 4)
	crawler.hunt(p)
	await phys(90)
	check(not room.is_pit_at(crawler.global_position) and crawler.global_position.x < room.cell_center(6, 4).x,
		"a crawler after the player is stopped at the pit's edge (%.0f)" % crawler.global_position.x)
	var drifter := Enemy.new()
	drifter.setup("DRIFTER", 1, "")
	drifter.room = room
	drifter.collision_layer = 4
	drifter.collision_mask = 1
	add_child(drifter)
	drifter.global_position = room.cell_center(3, 3)
	drifter.hunt(p)
	await until(func() -> bool: return drifter.global_position.x > float(6 * Room.CELL) + 8.0, 300)
	check(drifter.global_position.x > float(6 * Room.CELL) + 8.0,
		"a drifter is not stopped at the edge: it flies out over the pit (%.0f)" % drifter.global_position.x)

	# A bolt flies over.
	var bolt := Payload.new()
	bolt.form = "PROJECTILE"
	bolt.damage = 1.0
	bolt.range_px = 600.0
	var hp2 := p.health
	p.invuln = 0.0
	p.global_position = room.cell_center(12, 4)
	await phys(2)
	Attacks.spawn(bolt, {"attacker": crawler, "room": room, "team": 1, "aim": Vector2.RIGHT,
		"origin": room.cell_center(3, 4)})
	check(await until(func() -> bool: return p.health < hp2, 120), "a bolt flies over the pit and strikes what is beyond")

	print("[PIT] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
