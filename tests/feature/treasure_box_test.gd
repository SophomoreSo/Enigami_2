extends Node2D
## A room's loot is kept in one treasure box rather than left on the floor.
## Pressing interact beside it puts everything in it into the run at once; the
## box stays, open and empty, for as long as the raid does. What a kill knocks
## loose is not loot the room was found with, and still leaps out on its own.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[BOX] PASS ", what)
	else:
		fails += 1
		push_error("BOX FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func press() -> void:
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	await frames(1)

func bag_count() -> int:
	var n := 0
	for k in GameState.raid_bag:
		n += int(GameState.raid_bag[k])
	return n

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
	seed(20261003)

	_retired()
	await _box()

	print("[BOX] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## A part taken out of the game stays on the record and never comes out.
func _retired() -> void:
	var gone := ""
	for id in ["SPLIT", "TEE", "REVERSE", "DASH"]:
		if Components.is_retired(id):
			gone = id
			break
	check(gone != "", "there is a retired part to try (%s)" % gone)
	var loot := [{"id": gone, "pos": [0.0, 0.0]}, {"scrap": 7, "pos": [0.0, 0.0]}]
	var out := TreasureBox.takeable(loot)
	check(out.size() == 1 and out[0].has("scrap"), "a retired part never comes out of a box")

func _clear_monsters(raid: Raid) -> void:
	for c in raid.room.get_children():
		if c is Enemy:
			c.queue_free()
	await frames(2)

func _box() -> void:
	GameState.deploy("SWORD")
	var raid := await start_raid()

	check(raid.room.box == null, "the way in is found with nothing in it, so it has no box")

	var where := Vector2i(-999, -999)
	for c in raid.map.rooms.keys():
		if String(raid.map.rooms[c].get("kind", "")) == "treasure":
			where = c
	check(where.x != -999, "the floor has a treasure room")
	if where.x == -999:
		return
	raid.go_to(where)
	await frames(3)
	await _clear_monsters(raid)

	var floor_loot := 0
	for c in raid.room.get_children():
		if c is Pickup:
			floor_loot += 1
	check(floor_loot == 0, "nothing the room was found with is lying on the floor (%d)" % floor_loot)
	var box: TreasureBox = raid.room.box
	check(box != null and not box.is_open, "it is all in one shut box")
	if box == null:
		return
	var inside := TreasureBox.takeable(box.contents)
	check(inside.size() >= 2, "a treasure room's box holds its 2 to 4 things (%d)" % inside.size())
	var want_scrap := 0
	var want_parts := 0
	for l in inside:
		if l.has("scrap"):
			want_scrap += int(l["scrap"])
		else:
			want_parts += 1

	# Out of reach, a press does nothing.
	raid.player.global_position = box.global_position + Vector2(300, 0)
	await frames(2)
	check(not box.offered() and not raid.use_nearby(), "from across the room it is not offered")
	await press()
	check(not box.is_open, "and a press there leaves it shut")

	var bag_before := bag_count()
	var scrap_before := GameState.raid_scrap
	for i in 30:
		raid.player.global_position = box.global_position
		await get_tree().process_frame
		if box.offered():
			break
	check(box.offered() and raid.use_nearby(), "beside it, it is offered, and the console's USE says so")
	await press()
	check(box.is_open, "a press beside it opens it")
	check(bag_count() == bag_before + want_parts and GameState.raid_scrap == scrap_before + want_scrap,
		"everything in it goes into the run at once (%d parts, %d gold)" % [want_parts, want_scrap])
	check(TreasureBox.takeable(raid.room.data["loot"]).is_empty(), "and off the room's record")
	check(not box.offered() and not raid.use_nearby(), "an open box is not offered again")

	# Out and back in: the same box in the same place, still open, still empty.
	var at := box.global_position
	var away: Vector2i = raid.map.entry
	raid.go_to(away)
	await frames(2)
	raid.go_to(where)
	await frames(3)
	await _clear_monsters(raid)
	var again: TreasureBox = raid.room.box
	check(again != null and again.is_open, "walking back in finds the box standing open")
	if again == null:
		return
	check(again.global_position.distance_to(at) < 1.0, "where it stood")
	bag_before = bag_count()
	scrap_before = GameState.raid_scrap
	for i in 10:
		raid.player.global_position = again.global_position
		await get_tree().process_frame
	await press()
	check(bag_count() == bag_before and GameState.raid_scrap == scrap_before, "and it has nothing more to give")

	# A kill is not the room's loot: what it knocks loose still leaps out. The
	# box's room is kept hold of: the player is stood clear of the drop, and
	# 400 px from the box is across the seam into the room beside, which the
	# raid then calls the room the player is in.
	var home := raid.room
	var e := Enemy.new()
	e.setup(Monsters.pick(home.rng, 1), 1, "")
	e.room = home
	home.add_child(e)
	# In the world: the room stands where the floor puts it, not at its corner.
	e.global_position = again.global_position + Vector2(120, -40)
	await frames(2)
	raid.player.global_position = again.global_position + Vector2(-400, 0)
	e.apply_damage(999999.0, [], null)
	await frames(3)
	var loose := 0
	for c in home.get_children():
		if c is Pickup:
			loose += 1
	check(loose >= 1, "a kill still drops its gold where it fell (%d)" % loose)
