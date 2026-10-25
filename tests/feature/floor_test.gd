extends Node2D
## The raid's floor, laid by hand (`RaidMap`, `raid_rooms`): every room it names
## is a map that is there; one way in, with a start and an exit; the Arbiter's
## room with the Arbiter posted in it and its exit; every doorway a room
## marks matched by the room it leads to, the way back; every room reached
## from the way in; and each room holding exactly what its map lays in it,
## nothing rolled. The database cannot see a map's marks, so this is where a
## floor that would strand a player fails.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[FLOOR] PASS ", what)
	else:
		fails += 1
		push_error("FLOOR FAIL: " + what)

func _ready() -> void:
	var laid := RaidMap.new()
	laid.lay(1)
	var rows := Db.rows("SELECT * FROM raid_rooms")
	check(not rows.is_empty() and laid.rooms.size() == rows.size(),
		"every room the floor names is laid (%d of %d)" % [laid.rooms.size(), rows.size()])
	var entries: Array = laid.rooms.keys().filter(func(c: Vector2i) -> bool: return laid.rooms[c]["kind"] == "entry")
	check(entries.size() == 1 and entries[0] == laid.entry, "one way in")
	var made := {}
	for c: Vector2i in laid.rooms:
		made[c] = Maps.load_room(String(laid.rooms[c]["map"]))
	var start: MadeRoom = made.get(laid.entry)
	check(start != null and not start.cells_marked(MadeRoom.START).is_empty()
			and (laid.rooms[laid.entry] as Dictionary).has("extraction"),
		"where a run starts and a way out of it there")
	var bosses: Array = laid.rooms.keys().filter(func(c: Vector2i) -> bool: return laid.rooms[c]["kind"] == "boss")
	check(bosses.size() == 1 and not (made[bosses[0]] as MadeRoom).cells_marked("a").is_empty()
			and String((laid.rooms[bosses[0]] as Dictionary).get("extraction", {}).get("id", "")) == "arbiter",
		"one Arbiter's room, with the Arbiter posted in it and its exit")
	var exits_marked: Array = []
	var one_way: Array = []
	var holds: Array = []
	for c: Vector2i in laid.rooms:
		var room: MadeRoom = made[c]
		var rec: Dictionary = laid.rooms[c]
		if rec.has("extraction") and room.exit_cell().x < 0:
			exits_marked.append(str(c))
		for side in laid.doors_for(c):
			var there: Vector2i = c + RaidMap.dir_delta(int(side))
			if not laid.doors_for(there).has(RaidMap.opposite(int(side))):
				one_way.append("%s->%s" % [str(c), str(there)])
		if (rec["enemies"] as Array).size() != room.monster_records().size():
			holds.append(str(c))
	check(exits_marked.is_empty(), "every way out stands on its room's E (%s)" % str(exits_marked))
	check(one_way.is_empty(), "every doorway leads somewhere with one back (%s)" % str(one_way))
	check(holds.is_empty(), "every room holds the monsters its map posts, and no more (%s)" % str(holds))
	# Every room reached from the way in.
	var seen := {laid.entry: true}
	var todo: Array = [laid.entry]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for side in laid.doors_for(c):
			var there: Vector2i = c + RaidMap.dir_delta(int(side))
			if not seen.has(there):
				seen[there] = true
				todo.append(there)
	check(seen.size() == laid.rooms.size(), "every room is reached from the way in (%d of %d)" % [seen.size(), laid.rooms.size()])
	for room in made.values():
		if room != null:
			room.free()
	print("[FLOOR] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
