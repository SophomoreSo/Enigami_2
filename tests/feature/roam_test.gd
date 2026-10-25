extends Node2D
## Monsters are rolled once a raid and never topped up again: a room left and
## come back to holds the monsters that were left in it, still carrying the
## wounds they were left with. A room beside the player's stands up with it
## (`Raid.rooms`), and a doorway is walked through without a cut: the room
## left stays up, so does everything in the air, and a monster that crosses
## the seam is the other room's from then on. One after the player keeps
## after them out of sight: once its room is taken down it travels the floor
## as a record (`Raid.hunters`) and is stood up again, after them, in the
## room they are in.
##
## Only the rooms stood up are simulated, so a monster elsewhere is a record
## on the map rather than a node: `listed` below reads it there, which is the
## only way to see a monster in a room nobody is near.

var fails := 0
var cuts := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[ROAM] PASS ", what)
	else:
		fails += 1
		push_error("ROAM FAIL: " + what)

## Idle frames, which is when the raid stands rooms up and hands monsters
## over (`_process`): a physics frame can come round several times inside
## one of them while a room is being built, and prove nothing.
func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## Every monster the map says is in `c`. A room that has been stood up keeps
## them under "enemies"; one that has not keeps anything that has come to it
## under "arrivals" until it is.
func listed(raid: Raid, c: Vector2i) -> Array:
	var rec: Dictionary = raid.map.get_record(c)
	var out: Array = []
	out.append_array(rec.get("enemies", []))
	out.append_array(rec.get("arrivals", []))
	return out

## How many of the test's own monsters the map says are in `c`.
##
## A monster is followed by the tag written into its record rather than by its
## kind, because the rooms hold their own and a room next door is perfectly
## entitled to hold another Hopper. The record is what travels between rooms,
## so a mark on it is the one thing that identifies a particular monster.
func count_in(raid: Raid, c: Vector2i, tag: String) -> int:
	var n := 0
	for e in listed(raid, c):
		if String((e as Dictionary).get("tag", "")) == tag:
			n += 1
	return n

## Everything `team` has in the world that an attack put there: bolts, arcs,
## lunges, bursts, and the follow-ups waiting to become one.
func in_air(raid: Raid, team: int) -> int:
	var n := 0
	for c in raid.get_children():
		if c.is_queued_for_deletion():
			continue
		if c is Projectile or c is MeleeArc or c is DashSlash or c is AreaBurst \
				or c is Attacks.Deferred:
			if int(c.get("team")) == team:
				n += 1
	return n

## The live monster carrying `tag`, in any room stood up, or null.
func find(raid: Raid, tag: String) -> Enemy:
	for key in raid.rooms:
		var r: Room = raid.rooms[key]
		if not is_instance_valid(r):
			continue
		for n in r.get_children():
			if n is Enemy and not (n as Enemy).dead and n.has_meta("record") \
					and String((n.get_meta("record") as Dictionary).get("tag", "")) == tag:
				return n
	return null

## Puts a monster in the player's room the way the room itself does, record
## and all, so the test's own subjects are indistinguishable from rolled ones.
## Held where it is put, out of its own mind, until the test says otherwise:
## one that noticed the player and went after them would not stay to be
## counted.
func plant(raid: Raid, kind: String, cell: Vector2i, tag: String) -> Enemy:
	var at := raid.room.cell_center(cell.x, cell.y)
	var rec := {"kind": kind, "mod": "", "pos": [at.x, at.y], "tag": tag}
	var e: Enemy = raid.room.arrive(rec)
	e.set_process(false)
	return e

## A doorway out of the player's room with a room on the other side.
func way_out(raid: Raid) -> int:
	for dir in raid.room.doors:
		if raid.map.has_room(raid.room.coord + RaidMap.dir_delta(int(dir))):
			return int(dir)
	return -1

## A room of the floor that is not `home` and not beside it through a doorway:
## one the player can be cut to and have `home` taken down behind them, since a
## room beside the player's is kept standing (`Raid.UNLOAD_FAR`).
func far_from(raid: Raid, home: Vector2i) -> Vector2i:
	for key in raid.map.rooms:
		var c: Vector2i = key
		if c != home and not (c.y == home.y and absi(c.x - home.x) == 1):
			return c
	return home

## The world point two cells in from the doorway on `side` of room `c`.
func inside(raid: Raid, c: Vector2i, side: int) -> Vector2:
	var r: Room = raid.rooms[c]
	return r.to_global(r.arrival_at(side))

func _ready() -> void:
	GameState.reset_profile()
	GameState.raid_seed = 20260919
	GameState.deploy("GUN")
	var raid := Raid.new()
	raid.cut.connect(func() -> void: cuts += 1)
	add_child(raid)
	await frames(2)

	var home := raid.room.coord
	var dir := way_out(raid)
	check(dir >= 0, "the entry room %s has a way out of it" % [home])
	var away: Vector2i = home + RaidMap.dir_delta(dir)
	var far := far_from(raid, home)
	check(far != home and far != away, "and the floor has a room that is not beside it (%s)" % [far])

	var wounded := plant(raid, "SENTRY", Vector2i(int(Room.W / 2.0), Room.DOOR_ROWS[1]), "wounded")
	var rover := plant(raid, "HOPPER", Vector2i(int(Room.W / 2.0) + 3, Room.DOOR_ROWS[1]), "rover")
	var max_hp := wounded.max_health
	wounded.apply_damage(max_hp * 0.5, [], null, false)
	var left := wounded.health
	var before := listed(raid, home).size()
	check(before >= 2 and count_in(raid, home, "wounded") == 1 and count_in(raid, home, "rover") == 1,
		"the two are among the room's monsters (%d)" % before)

	# --- a room left for good is taken down, and nothing is topped up --------
	raid.go_to(far)
	await frames(2)
	check(not raid.rooms.has(home) and raid.room.coord == far,
		"cut to a room not beside it, the room is taken down behind the player")
	check(count_in(raid, home, "wounded") == 1 and count_in(raid, home, "rover") == 1,
		"and the map keeps its monsters as records")
	raid.go_to(home)
	await frames(4)
	check(raid.room.coord == home and listed(raid, home).size() == before,
		"walked back into, it holds the monsters it held, no more (%d, was %d)"
		% [listed(raid, home).size(), before])
	var back := find(raid, "wounded")
	check(back != null and absf(back.health - left) < 0.5,
		"and the one that was hurt is still hurt (%.0f of %.0f)"
		% [back.health if back != null else -1.0, max_hp])
	rover = find(raid, "rover")
	if rover != null:
		rover.set_process(false)

	# --- the room beside stands up as the player nears the seam --------------
	var mouth: Vector2 = raid.room.to_global(raid.room.door_rect(dir).get_center())
	raid.player.global_position = mouth
	raid.player.velocity = Vector2.ZERO
	await frames(2)
	check(raid.rooms.has(away) and raid.room.coord == home,
		"standing in the doorway, the room beyond is stood up and the player is still here")
	if not raid.rooms.has(away):
		print("[ROAM] ---- %d failures ----" % fails)
		get_tree().quit(1 if fails > 0 else 0)
		return
	var there: Room = raid.rooms[away]
	check(there.position == Room.origin_of(away) and raid.room.neighbours.get(dir) == there
			and there.neighbours.get(RaidMap.opposite(dir)) == raid.room,
		"where the floor puts it, and the two know each other")
	var over := mouth + Vector2(RaidMap.dir_delta(dir)) * Room.CELL * 2.0
	check(raid.room.is_solid_at(over) == there.is_solid_at(over) and not raid.room.out_of_bounds(over),
		"a point past the seam is answered by the room beside, and is not out of bounds")

	# --- walked through, there is no cut, and the air stays ------------------
	var shot := Payload.new()
	shot.form = "PROJECTILE"
	var ctx := {"attacker": raid.player, "room": raid.room, "team": 0,
		"aim": Vector2.UP, "origin": raid.player.global_position}
	for i in 3:
		Attacks.spawn(shot, ctx)
	check(in_air(raid, 0) == 3, "three bolts of the player's own in the air (%d)" % in_air(raid, 0))
	var was_cuts := cuts
	raid.player.global_position = inside(raid, away, RaidMap.opposite(dir))
	raid.player.velocity = Vector2.ZERO
	await frames(2)
	check(raid.room.coord == away, "a step past the seam, the player is in the room beside")
	check(raid.rooms.has(home), "the room left stays up behind them")
	check(cuts == was_cuts, "and the picture did not cut")
	check(in_air(raid, 0) == 3, "and the bolts are still in the air (%d)" % in_air(raid, 0))

	# --- a monster that crosses the seam is the room beside's ----------------
	var home_room: Room = raid.rooms[home]
	rover = find(raid, "rover")
	check(rover != null and rover.get_parent() == home_room, "(the rover is still the first room's)")
	if rover == null:
		print("[ROAM] ---- %d failures ----" % fails)
		get_tree().quit(1 if fails > 0 else 0)
		return
	rover.global_position = inside(raid, away, RaidMap.opposite(dir)) + Vector2(RaidMap.dir_delta(dir)) * 40.0
	await frames(2)
	check(rover.get_parent() == there and rover.room == there,
		"moved over the seam, it is the other room's child, and asks that room about the rock")
	check(count_in(raid, home, "rover") == 0 and count_in(raid, away, "rover") == 1,
		"with its record moved with it (%d here, %d there)" % [count_in(raid, home, "rover"), count_in(raid, away, "rover")])

	# --- after the player, it keeps after them out of sight ------------------
	rover.set_process(true)
	rover.hunt(raid.player)
	check(rover.hunting(), "set after the player, it is hunting")
	raid.go_to(far)
	await frames(2)
	check(not raid.rooms.has(away), "(the room it was in is taken down)")
	check(raid.hunters.size() == 1 and find(raid, "rover") == null and count_in(raid, away, "rover") == 0,
		"and it is on the road rather than left there (%d on the road)" % raid.hunters.size())
	# Its hops run on the clock; the clock is run down by hand, a hop a frame.
	var hops := 0
	while not raid.hunters.is_empty() and hops < 12:
		for h in raid.hunters:
			h["left"] = 0.0
		await frames(2)
		hops += 1
	var arrived := find(raid, "rover")
	check(arrived != null and raid.hunters.is_empty(),
		"a room at a time, it comes to the room the player is in (%d hops)" % hops)
	# The first room up that its road comes to: the player's, or one beside it
	# that is standing, which it walks on into after them.
	var landed: Room = arrived.get_parent() as Room if arrived != null else null
	check(landed != null and raid.rooms.values().has(landed)
			and count_in(raid, landed.coord, "rover") == 1 and count_in(raid, away, "rover") == 0,
		"stood up in the first room up on its road, among that room's monsters, once (%s, player in %s)"
		% [str(landed.coord) if landed != null else "none", str(raid.room.coord)])
	check(arrived != null and arrived.hunting(), "and still after them")

	print("[ROAM] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
