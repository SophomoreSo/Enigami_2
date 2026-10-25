extends Node2D
## The rooms a raid keeps stood up (`Raid.rooms`): the one the player is in,
## and the one beside it through a doorway once they are near the seam, kept
## while they are anywhere near — never more than three, each where the floor
## puts it. A room left for good is taken down. What the picture may show is
## the rooms stood up (`Raid.live_rect`). A parked raid keeps the monsters on
## the road between rooms.
##
## Headless: nothing here is looked at, only what is stood up and where.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[WINDOW] PASS ", what)
	else:
		fails += 1
		push_error("WINDOW FAIL: " + what)

## Idle frames, which is when the raid stands rooms up and hands monsters
## over (`_process`): a physics frame can come round several times inside
## one of them while a room is being built, and prove nothing.
func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func way_out(raid: Raid) -> int:
	for dir in raid.room.doors:
		if raid.map.has_room(raid.room.coord + RaidMap.dir_delta(int(dir))):
			return int(dir)
	return -1

func far_from(raid: Raid, home: Vector2i) -> Vector2i:
	for key in raid.map.rooms:
		var c: Vector2i = key
		if c != home and not (c.y == home.y and absi(c.x - home.x) == 1):
			return c
	return home

## The union of the rooms stood up, worked out here, to hold the raid's to.
func union(raid: Raid) -> Rect2:
	var out := Rect2()
	for key in raid.rooms:
		var r: Room = raid.rooms[key]
		out = r.bounds() if out.size == Vector2.ZERO else out.merge(r.bounds())
	return out

func _ready() -> void:
	GameState.reset_profile()
	GameState.raid_seed = 20260919
	GameState.deploy("GUN")
	var raid := Raid.new()
	add_child(raid)
	await frames(2)

	# --- where the floor puts them ---------------------------------------------
	var home := raid.room.coord
	check(raid.room.position == Room.origin_of(home) and Raid.coord_at(raid.player.global_position) == home,
		"the first room stands where the floor puts it, with the player in it")
	check(Room.origin_of(Vector2i(2, 3)) == Vector2(2 * Room.W * Room.CELL, 3 * Room.H * Room.CELL)
			and Raid.coord_at(Room.origin_of(Vector2i(4, 1)) + Vector2(5.0, 5.0)) == Vector2i(4, 1),
		"a room's place and the room at a point are each other's inverse")
	check(raid.live_rect() == union(raid), "what the picture may show is the rooms stood up")
	check(raid.rooms.size() <= 2, "at the start, the room and at most the one beside (%d)" % raid.rooms.size())

	var dir := way_out(raid)
	var away: Vector2i = home + RaidMap.dir_delta(dir)
	var far := far_from(raid, home)
	check(dir >= 0 and far != home, "the entry has a room beside it and one further off")
	var seam_x := Room.origin_of(home).x + (0.0 if dir == Components.W else float(Room.W * Room.CELL))
	var y := raid.player.global_position.y

	# --- the room beside, stood up near the seam and kept while near -----------
	# From a stand further than LOAD_NEAR from the seam, with the room beside
	# not up: the start may have stood it up, if the entry starts a player near
	# the seam, and one up is kept.
	var toward := signf(float(RaidMap.dir_delta(dir).x))
	raid.player.global_position = Vector2(seam_x - toward * (Raid.LOAD_NEAR + 200.0), y)
	raid.player.velocity = Vector2.ZERO
	if raid.rooms.has(away):
		raid._unload_room(away)
	await frames(2)
	check(not raid.rooms.has(away), "further than LOAD_NEAR from the seam, the room beside is not stood up")
	raid.player.global_position = Vector2(seam_x - toward * (Raid.LOAD_NEAR - 100.0), y)
	await frames(2)
	check(raid.rooms.has(away), "within it, it is")
	check(raid.live_rect() == union(raid) and raid.live_rect().size.x == 2.0 * Room.W * Room.CELL,
		"and the picture may show the two of them")
	raid.player.global_position = Vector2(seam_x - toward * (Room.W * Room.CELL * 0.5), y)
	await frames(2)
	check(raid.rooms.has(away), "back in the middle of the room, it is kept standing")
	check(raid.rooms.size() <= 3, "never more than three (%d)" % raid.rooms.size())

	# --- a room left for good is taken down ------------------------------------
	raid.go_to(far)
	await frames(2)
	check(raid.room.coord == far and not raid.rooms.has(home) and not raid.rooms.has(away),
		"cut to a room further off, the two are taken down (%s left)" % str(raid.rooms.keys()))
	check(bool(raid.map.get_record(home).get("visited", false)) and not bool(raid.map.get_record(away).get("visited", false)),
		"the room stood in was visited, for the map; the one only stood up beside it was not")

	# --- a parked raid keeps the hunters on the road -----------------------------
	raid.hunters.append({"rec": {"kind": "CRAWLER", "mod": "", "pos": [1.0, 2.0], "tag": "x"},
		"at": away, "to": home, "dir": Components.W, "left": 3.5, "hops": 2})
	var saved := raid.park()
	check((saved.get("hunters", []) as Array).size() == 1, "a parked raid writes the hunters down")
	raid.hunters.clear()
	raid._restore_hunters(saved["hunters"])
	var h: Dictionary = raid.hunters[0] if not raid.hunters.is_empty() else {}
	check(not h.is_empty() and h["at"] == away and h["to"] == home and int(h["dir"]) == Components.W
			and is_equal_approx(float(h["left"]), 3.5) and int(h["hops"]) == 2
			and String((h["rec"] as Dictionary).get("tag", "")) == "x",
		"and reads them back as they were")

	raid.queue_free()
	await frames(2)
	print("[WINDOW] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
