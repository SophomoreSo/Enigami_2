extends Node2D
## The shovel, and the ground it digs. Every profile is handed the shovel once —
## a new one starts with it, an old save is given it when it loads, and one lost
## since is not given back. Raid rooms hide lit ground worth digging, rolled with
## the room: holding the use key on it with the shovel in hand digs it up and
## puts what was buried into the run; letting go starts it over, and the digging
## is loud enough to turn the monsters near it round.

## GameState's script, for its static slot path: the autoload has no class name.
const GameStateScript := preload("res://feature/core/game_state.gd")

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[DIG] PASS ", what)
	else:
		fails += 1
		push_error("DIG FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func wait(secs: float) -> void:
	var t := 0.0
	while t < secs:
		await get_tree().process_frame
		t += get_process_delta_time()

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
	seed(20261004)

	_the_shovel()
	_handed_out()
	await _digging()

	print("[DIG] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## --- the weapon --------------------------------------------------------------
func _the_shovel() -> void:
	check(Weapons.ids().has("SHOVEL") and Weapons.root_part("SHOVEL") == "SLASH",
		"the shovel is a weapon whose graph is a SLASH")
	check(Weapons.digs("SHOVEL") and not Weapons.digs("SWORD") and not Weapons.digs("ROCK"),
		"and the one weapon that digs")
	check(Weapons.make_board("SHOVEL").root_entry().get("id", "") == "SLASH"
			and Weapons.make_board("SHOVEL").used_components().is_empty(),
		"its graph as a profile gets it is its SLASH and nothing on it")

## --- every profile is handed it, once ----------------------------------------------
func _handed_out() -> void:
	GameState.reset_profile()
	check(GameState.owned_weapons.has("SHOVEL") and GameState.handed_out.has("SHOVEL"),
		"a new profile starts with the shovel")
	# A save from before the shovel: no record of it ever handed out.
	GameState.owned_weapons.erase("SHOVEL")
	GameState.handed_out.clear()
	GameState.save_game()
	var raw := FileAccess.get_file_as_string(GameStateScript.slot_path(GameState.slot))
	var parsed: Dictionary = JSON.parse_string(raw)
	parsed.erase("handed_out")
	var f := FileAccess.open(GameStateScript.slot_path(GameState.slot), FileAccess.WRITE)
	f.store_string(JSON.stringify(parsed))
	f.close()
	GameState.load_slot(GameState.slot)
	check(GameState.owned_weapons.has("SHOVEL"), "a save from before it is given it when it loads")
	# Lost since: handed out already, and not handed out again.
	GameState.owned_weapons.erase("SHOVEL")
	GameState.save_game()
	GameState.load_slot(GameState.slot)
	check(not GameState.owned_weapons.has("SHOVEL"), "and a shovel lost since is not given back")
	GameState.reset_profile()

## --- the ground --------------------------------------------------------------------
func _digging() -> void:
	GameState.deploy("SHOVEL")
	var raid := await start_raid()
	var where := Vector2i(-999, -999)
	var kinds := {}
	for c in raid.map.rooms.keys():
		var kind := String(raid.map.rooms[c].get("kind", ""))
		kinds[kind] = true
		if kind == "normal" and where.x == -999:
			where = c
	check(where.x != -999, "the floor has an ordinary room")
	if where.x == -999:
		return
	raid.go_to(where)
	await frames(3)
	for c in raid.room.get_children():
		if c is Enemy:
			c.queue_free()
	await frames(2)

	var room := raid.room
	var recs: Array = room.data.get("digs", [])
	check(recs.size() >= 1 and recs.size() <= 2 and room.digs.size() == recs.size(),
		"an ordinary room hides one or two spots of ground to dig (%d)" % recs.size())
	var apart := true
	for i in room.digs.size():
		for j in range(i + 1, room.digs.size()):
			apart = apart and room.digs[i].global_position.distance_to(room.digs[j].global_position) >= Room.DIG_APART
	check(apart, "kept apart from each other")
	var spot: DigSpot = room.digs[0] if not room.digs.is_empty() else null
	if spot == null:
		return
	var buried := TreasureBox.takeable(spot.record.get("loot", []))
	var parts := buried.filter(func(l: Dictionary) -> bool: return l.has("id")).size()
	var scrap := buried.filter(func(l: Dictionary) -> bool: return l.has("scrap")).size()
	check(scrap == 1 and parts >= 1 and parts <= 2, "with gold and a part or two buried under it (%s)" % str(buried))

	var p := raid.player
	p.global_position = spot.global_position
	p.velocity = Vector2.ZERO
	await frames(3)
	check(spot.offered() and raid.use_nearby(), "standing on it with the shovel in hand, it is offered")

	# A monster within earshot, its back to the digging.
	var e := Enemy.new()
	e.setup("CRAWLER", 1, "")
	e.room = room
	e.collision_layer = 4
	e.collision_mask = 1
	room.add_child(e)
	e.global_position = spot.global_position + Vector2(160.0, -2.0)
	await frames(2)
	e.face(1)
	e._glance = 30.0

	# Held a moment and let go: it starts over.
	Input.action_press("interact")
	await wait(DigSpot.HOLD * 0.4)
	check(spot.digging and spot.progress > 0.0 and not spot.is_dug(), "holding the key digs it, a little at a time")
	check(e.side() == -1, "and the noise turns the monster near it round to look")
	Input.action_release("interact")
	await frames(2)
	check(not spot.digging and spot.progress == 0.0, "letting go starts it over")
	e.queue_free()
	await frames(2)

	# Held through: it comes up, and into the run.
	var bag_before := 0
	for k in GameState.raid_bag:
		bag_before += int(GameState.raid_bag[k])
	var scrap_before := GameState.raid_scrap
	Input.action_press("interact")
	await wait(DigSpot.HOLD + 0.3)
	Input.action_release("interact")
	await frames(2)
	var bag_after := 0
	for k in GameState.raid_bag:
		bag_after += int(GameState.raid_bag[k])
	check(spot.is_dug() and bool(spot.record.get("dug", false)), "held through, it is dug up, and the room remembers it")
	check(bag_after - bag_before == parts and GameState.raid_scrap > scrap_before,
		"what was buried is in the run (%d parts, %d gold)" % [bag_after - bag_before, GameState.raid_scrap - scrap_before])
	check(not spot.offered(), "and a hole is not dug twice")

	# Without the shovel in hand, the ground is only ground.
	var other: DigSpot = null
	for d in room.digs:
		if not d.is_dug():
			other = d
	if other != null:
		p.setup("SWORD", GameState.weapon_board("SWORD"))
		p.global_position = other.global_position
		await frames(3)
		check(not other.offered(), "with another weapon in hand, the ground is not offered")
		Input.action_press("interact")
		await wait(DigSpot.HOLD + 0.3)
		Input.action_release("interact")
		check(not other.is_dug(), "and holding the key there digs nothing")
	raid.queue_free()
	await frames(2)
