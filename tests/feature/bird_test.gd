extends Node2D
## Birds: laid in a room's map (`MadeRoom.BIRD`), pecking about on the floor
## until the player comes near — their body, or a monster their hands are in —
## or something goes off close by, when they fly up and away from it and are
## gone. One taking off startles the birds round it into following; a bird
## further off stays. Flown, a bird stays flown.

var fails := 0
var room: MadeRoom
var player: Player

func check(ok: bool, what: String) -> void:
	if ok:
		print("[BIRD] PASS ", what)
	else:
		fails += 1
		push_error("BIRD FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func wait(secs: float) -> void:
	var t := 0.0
	while t < secs:
		await get_tree().process_frame
		t += get_process_delta_time()

## Waits until `cond` holds, for at most `secs`. Whether it did.
func until(cond: Callable, secs: float) -> bool:
	var t := 0.0
	while t < secs:
		if cond.call():
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return cond.call()

## The bird standing in cell (x, y) of the room, or null.
func bird_at(x: int, y: int) -> Bird:
	for b in room.birds:
		if is_instance_valid(b) and b.record["pos"] == [room.stand_point(Vector2i(x, y)).x,
				room.stand_point(Vector2i(x, y)).y]:
			return b
	return null

func _ready() -> void:
	Arena.register(self)
	GameState.reset_profile()
	seed(20261027)
	_laid()
	await _stand()
	await _scared()
	await _noise()
	await _in_a_monster()
	await _stays_flown()
	print("[BIRD] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## A map lays them, a mark a cell, on open floor; the creator offers the mark,
## and the Moonlit Grove has some.
func _laid() -> void:
	check(MadeRoom.things().has(MadeRoom.BIRD), "the map creator offers a bird under THINGS")
	var grove := Maps.load_room("moonlit_grove")
	check(grove != null, "the Moonlit Grove is a map")
	if grove == null:
		return
	var rec: Array = grove.record().get("birds", [])
	check(rec.size() == grove.cells_marked(MadeRoom.BIRD).size() and rec.size() >= 3,
		"one bird a mark in the Grove (%d)" % rec.size())
	check(rec.all(func(b: Dictionary) -> bool: return not bool(b["flown"])), "and none has flown yet")
	grove.free()
	# And where a player meets them: every room of a raid's floor, and the hall
	# of the hideout.
	var bare: Array = []
	for row in Db.rows("SELECT map_id FROM raid_rooms"):
		var made := Maps.load_room(String(row["map_id"]))
		if made == null or (made.record().get("birds", []) as Array).size() < 2:
			bare.append(String(row["map_id"]))
		if made != null:
			made.free()
	check(bare.is_empty(), "every room of a raid has a few (%s have none)" % str(bare))
	var hall := MadeRoom.new()
	hall.plan = HideoutWorld.PLAN
	check(hall.cells_marked(MadeRoom.BIRD).size() >= 3, "and the hideout's hall has some")
	hall.free()

## A room with a flock of three close together, two near each other further
## off, and one on its own across the floor; the player at the far end.
func _stand() -> void:
	room = MadeRoom.new()
	room.plan = PackedStringArray([
		"########################################",
		"#......................................#",
		"#......................................#",
		"#....v.v...............................#",
		"#.....v.......................v........#",
		"#......................................#",
		"#..................v.v.................#",
		"#......................................#",
		"#.................................P....#",
		"#......................................#",
		"########################################",
	])
	player = Player.new()
	player.collision_layer = 2
	player.collision_mask = 1
	room.player = player
	add_child(room)
	room.stand()
	add_child(player)
	player.room = room
	player.global_position = room.spawn_point()
	await frames(4)
	check(room.birds.size() == 6, "every bird laid stands on the floor (%d)" % room.birds.size())
	var at := room.birds.map(func(b: Bird) -> Vector2: return b.global_position)
	await wait(5.0)
	var still := 0
	for i in room.birds.size():
		var b: Bird = room.birds[i]
		if not b.flying and b.global_position.distance_to(at[i]) <= Bird.HOP * 4.0:
			still += 1
	check(still == 6, "with nobody near, they stay, hopping a little about where they were (%d of 6)" % still)

## The player walks up to the flock: the nearest goes up, away from them, and
## the two beside it after; the birds further off stay where they are.
func _scared() -> void:
	var first := bird_at(7, 3)
	var flock := [bird_at(5, 3), bird_at(6, 4)]
	var off := bird_at(19, 6)
	var lone := bird_at(30, 4)
	check(first != null and flock.all(func(b) -> bool: return b != null) and off != null and lone != null,
		"(the birds where they were laid)")
	if first == null or off == null or lone == null:
		return
	var from := first.global_position + Vector2(Bird.SCARE + 40.0, 0.0)
	player.global_position = from
	await wait(0.5)
	check(not first.flying, "a little way off, it goes on pecking")
	var took := [null]
	first.took_off.connect(func(_b: Bird, away: Vector2) -> void: took[0] = away)
	player.global_position = first.global_position + Vector2(Bird.SCARE - 20.0, 0.0)
	check(await until(func() -> bool: return first.flying, 0.5), "come near, it flies")
	check(took[0] != null and (took[0] as Vector2).x < 0.0, "away from the player (%s)" % str(took[0]))
	var was := first.global_position
	await wait(0.3)
	check(is_instance_valid(first) and first.height > 0.0
			and first.global_position.distance_to(player.global_position) > was.distance_to(player.global_position),
		"up off the floor, and further from the player as it goes")
	check(flock.all(func(b: Bird) -> bool: return is_instance_valid(b) and b.flying),
		"the birds beside it follow it up")
	check(is_instance_valid(off) and not off.flying and is_instance_valid(lone) and not lone.flying,
		"and the ones further off stay")
	check(await until(func() -> bool: return not is_instance_valid(first), Bird.FLIGHT + 0.5),
		"in a moment it is gone")
	await wait(0.5)
	check(room.birds.size() == 3 and room.birds.has(off) and room.birds.has(lone),
		"and so are the two that followed it (%d left)" % room.birds.size())
	player.global_position = room.spawn_point()

## A blow or a shot going off near a bird sends it up, with nobody near.
func _noise() -> void:
	var off := bird_at(19, 6)
	if off == null:
		check(false, "(the bird further off)")
		return
	check(player.global_position.distance_to(off.global_position) > Bird.SCARE, "(the player is not near it)")
	# Off to the side away from the other birds: one going off near them would
	# send them up instead.
	Cues.at(&"impact", off.global_position - Vector2(Bird.NOISE + 60.0, 0.0), {"kind": "wall"})
	await frames(2)
	check(not off.flying, "something going off a long way from it, it pecks on")
	Cues.at(&"impact", off.global_position + Vector2(0.0, Bird.NOISE - 20.0), {"kind": "wall"})
	await frames(2)
	check(off.flying, "something going off close by, it flies")
	await wait(Bird.FLIGHT + 0.5)

## A monster the player's hands are in scares a bird as their body would.
func _in_a_monster() -> void:
	var lone := bird_at(30, 4)
	if lone == null:
		check(false, "(the lone bird)")
		return
	var e := Enemy.new()
	e.setup("CRAWLER", 1, "")
	e.room = room
	e.collision_layer = 4
	e.collision_mask = 1
	room.add_child(e)
	e.global_position = room.stand_point(Vector2i(30, 8))
	await frames(2)
	check(player.possess(e, 5.0), "(the player's hands in a Crawler)")
	player.global_position = room.spawn_point()
	await wait(0.3)
	check(not lone.flying, "the Crawler a way off, the bird pecks on")
	e.global_position = lone.global_position + Vector2(0.0, Bird.SCARE - 20.0)
	check(await until(func() -> bool: return lone.flying, 0.5), "walked up to it, the bird flies from the monster")
	player.release()
	await wait(Bird.FLIGHT + 0.5)

## Every bird flown is flown in the room's record: stood up again from it, the
## room has none of them.
func _stays_flown() -> void:
	var rec: Dictionary = room.data
	check((rec["birds"] as Array).all(func(b: Dictionary) -> bool: return bool(b["flown"])),
		"every bird that flew has flown in the room's record")
	var again := MadeRoom.new()
	again.plan = room.plan
	add_child(again)
	again.build(Vector2i.ZERO, rec, {}, 0)
	await frames(2)
	check(again.birds.is_empty(), "and the room stood up again from it has none (%d)" % again.birds.size())
