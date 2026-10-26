extends Node2D
## Crates: little boxes laid in a room's map (`MadeRoom.CRATE`), each with a
## few coins in it. Anything that strikes one breaks it — the player's blow,
## a monster's — and its gold spills out onto the floor to be picked up. It is
## struck by what reaches it and sought by nothing: no homing bolt, aimed blow
## or pet turns for it, and breaking it is no kill. Broken, it stays broken.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[CRATE] PASS ", what)
	else:
		fails += 1
		push_error("CRATE FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func start_raid() -> Raid:
	var r := Raid.new()
	r.finished.connect(func(_result: String, _payload: Dictionary) -> void: r.queue_free())
	add_child(r)
	await frames(4)
	return r

func _ready() -> void:
	GameState.reset_profile()
	for n in range(1, GameState.SAVE_SLOTS + 1):
		GameState.delete_slot(n)
	seed(20261026)

	_laid()
	await _broken()

	print("[CRATE] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## A map lays them, a mark a cell, on open floor; the creator offers the mark.
func _laid() -> void:
	check(MadeRoom.things().has(MadeRoom.CRATE), "the map creator offers a crate under THINGS")
	var made := Maps.load_room("raid_0_4")
	check(made != null, "the raid's way in is a map")
	if made == null:
		return
	var rec := made.record()
	var crates: Array = rec.get("crates", [])
	check(crates.size() == made.cells_marked(MadeRoom.CRATE).size() and crates.size() > 0,
		"one crate a mark (%d)" % crates.size())
	var gold_ok := crates.all(func(c: Dictionary) -> bool:
		return int(c["gold"]) >= MadeRoom.CRATE_GOLD.x and int(c["gold"]) <= MadeRoom.CRATE_GOLD.y \
			and not bool(c["broken"]))
	check(gold_ok, "each holds a little gold, and none is broken yet")
	check(str(made.record()["crates"]) == str(crates), "the same map always hides the same gold")
	made.free()

func _clear_monsters(raid: Raid) -> void:
	for c in raid.room.get_children():
		if c is Enemy:
			c.queue_free()
	await frames(2)

## A blow of `form`: a swing, or a bolt.
func blow(form: String = "SLASH") -> Payload:
	var p := Payload.new()
	p.damage = 10.0
	p.form = form
	return p

func _broken() -> void:
	GameState.deploy("SWORD")
	var raid := await start_raid()
	await _clear_monsters(raid)
	var room := raid.room
	var standing := room.crates.size()
	check(standing == room.data.get("crates", []).size() and standing >= 2,
		"the way in stands its crates (%d)" % standing)
	if standing < 2:
		return
	var crate: Crate = room.crates[0]

	# Struck by either side, sought by neither.
	check(Attacks.targets(0).has(crate) and Attacks.targets(1).has(crate),
		"the player's side and the monsters' can both strike it")
	check(not Attacks.quarries(0).has(crate) and Attacks.nearest_target(crate.global_position, 0, 200.0) != crate,
		"but nothing goes after it: no homing, no aimed blow, no pull of the aim")
	check((crate.collision_layer & 1) != 0, "it stands in the way, on the walls' layer")

	# The player's blow breaks it, and its gold spills out where it stood.
	var gold := crate.gold()
	var at := crate.position
	var kills := int(GameState.records.get("kills", 0))
	var player := raid.player
	player.global_position = crate.global_position + Vector2(-30, 0)
	await frames(2)
	Attacks.spawn(blow(), {"attacker": player, "room": room, "team": 0,
		"aim": Vector2.RIGHT, "origin": player.global_position})
	await frames(3)
	check(not is_instance_valid(crate) or crate.dead, "one blow breaks it")
	check(room.crates.size() == standing - 1, "and it is gone from the room")
	var spilled: Pickup = null
	for c in room.get_children():
		if c is Pickup and (c as Pickup).scrap_amount > 0:
			spilled = c
	check(spilled != null and spilled.scrap_amount == gold and spilled.position.distance_to(at) < 40.0,
		"its %d gold spills out where it stood" % gold)
	check(int(GameState.records.get("kills", 0)) == kills, "and breaking a crate is no kill")

	# Walked over, the gold is the run's.
	var scrap_before := GameState.raid_scrap
	if spilled != null:
		for i in 90:
			if not is_instance_valid(spilled):
				break
			player.global_position = spilled.global_position
			await get_tree().process_frame
	check(GameState.raid_scrap == scrap_before + GameState.gold_found(gold),
		"picked up, the gold is the run's (%d)" % (GameState.raid_scrap - scrap_before))

	# A monster's bolt breaks one as well.
	var other: Crate = room.crates[0]
	Attacks.spawn(blow("PROJECTILE"), {"attacker": null, "room": room, "team": 1,
		"aim": Vector2.RIGHT, "origin": other.global_position + Vector2(-30, 0)})
	for i in 60:
		if room.crates.size() < standing - 1:
			break
		await get_tree().process_frame
	check(room.crates.size() == standing - 2, "a monster's bolt breaks one too")

	# Out and back in: what was broken stays broken.
	var home := room.coord
	var far := home
	for key in raid.map.rooms:
		var c: Vector2i = key
		if absi(c.x - home.x) + absi(c.y - home.y) > 1:
			far = c
			break
	raid.go_to(far)
	await frames(3)
	raid.go_to(home)
	await frames(3)
	check(raid.room.crates.size() == standing - 2, "walking back in finds the broken ones still broken")
	var broken := (raid.room.data["crates"] as Array).filter(func(c: Dictionary) -> bool: return bool(c["broken"]))
	check(broken.size() == 2, "and the room's record says which")
