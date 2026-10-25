extends Node2D
## Dying drops the kit rather than destroying it, and the next deployment can go
## back for it: the same map, the same room, the spot the player fell on.
##
## Both halves are here because they are one rule seen from two sides — what
## `GameState` writes down when a run ends, and what the next `Raid` puts back
## on the floor because of it.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[KIT] PASS ", what)
	else:
		fails += 1
		push_error("KIT FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _ready() -> void:
	# A profile of its own, like the smoke test: deploying and dying are written
	# to disk, so a run has to start from something known.
	GameState.reset_profile()
	for n in range(1, GameState.SAVE_SLOTS + 1):
		GameState.delete_slot(n)
	seed(20260920)

	_same_floor()
	await _rules()
	await _floor()

	print("[KIT] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## --- the promise the whole thing rests on -----------------------------------
## One floor. A drop is an address on a map that has not been laid yet, so a
## floor that came out different the second time would leave every kit
## stranded. It is laid by hand now, the same rows every time: whatever the
## run's number, and whatever the global generator is doing.
func _same_floor() -> void:
	seed(1)
	var a := RaidMap.new()
	a.lay(9876543)
	var first: Array = a.rooms.keys()
	var kinds := first.map(func(c: Vector2i) -> String: return String(a.rooms[c]["kind"]))
	# A different global seed, and another run's number: neither may matter.
	seed(2)
	randomize()
	var b := RaidMap.new()
	b.lay(1234)
	check(not first.is_empty() and b.rooms.size() == a.rooms.size()
			and first.all(func(c: Vector2i) -> bool: return b.rooms.has(c)),
		"the floor is the same rooms, whatever the run's number or the global generator (%d)"
			% a.rooms.size())
	check(kinds == first.map(func(c: Vector2i) -> String: return String(b.rooms[c]["kind"])),
		"and puts the entry, the boss and the treasure in the same places")
	check(a.entry == b.entry, "and the way in is the same way in")

## --- what a death writes down -----------------------------------------------
func _rules() -> void:
	# Something built onto the sword, so the drop has a graph worth having.
	var sword := GameState.weapon_board("SWORD")
	sword.place("FIRE", Vector2i(2, 2), 0)
	GameState.deploy("SWORD")
	GameState.add_component("FIRE", 2, GameState.raid_bag)
	GameState.raid_scrap = 17
	var seed_used := GameState.raid_seed

	var lost := GameState.die({"room": [2, 3], "pos": [640.0, 320.0]})
	check(bool(lost.get("dropped", false)), "a death with somewhere to fall leaves the kit there")
	check(GameState.has_lost_kit(), "and the drop outlives the raid that made it")
	check(not GameState.weapon_boards.has("SWORD"), "the sword's graph went with it")
	check(not GameState.owned_weapons.has("SWORD"), "and the weapon is off the rack")
	check(int((lost.get("parts", {}) as Dictionary).get("FIRE", 0)) == 1,
		"the results are told what was built onto it (%s)" % str(lost.get("parts", {})))

	var kit: Dictionary = GameState.lost_kit
	check(int(kit.get("seed", 0)) == seed_used, "the drop remembers which map it is in")
	check((kit.get("room", []) as Array) == [2, 3] and (kit.get("pos", []) as Array).size() == 2,
		"and the room and the spot in it (%s)" % str(kit.get("room", [])))
	check((kit.get("boards", {}) as Dictionary).has("SWORD")
			and (kit.get("weapons", []) as Array) == ["SWORD"],
		"it holds the weapon and the graph on it")
	check(int((kit.get("bag", {}) as Dictionary).get("FIRE", 0)) == 2
			and int(kit.get("scrap", 0)) == 17,
		"the bag and the scrap that were being carried")
	check(GameState.lost_kit_size() == 1 + 1 + 2,
		"and counts as the weapon, the part built on it and the bag (%d)" % GameState.lost_kit_size())

	# Through disk, the way the next session will find it. A drop is the one
	# thing a run leaves for a later one, so it has to survive the app closing.
	GameState.save_game()
	GameState.load_slot(GameState.slot)
	check(GameState.has_lost_kit(), "the drop is written out and read back")
	check(int(GameState.lost_kit.get("seed", 0)) == seed_used
			and (GameState.lost_kit.get("room", []) as Array).size() == 2,
		"with the map and the room it belongs to intact")
	check((GameState.lost_kit.get("boards", {}) as Dictionary).has("SWORD"),
		"and the graph still in it")

	# The map a kit is lying in is the map the next deployment walks into.
	GameState.deploy("ROCK")
	check(GameState.raid_seed == seed_used,
		"deploying again goes back to the same floor (%d)" % GameState.raid_seed)

	# Picking it up puts it back into the run, not into the vault — and every
	# part into the bag, the one built onto the sword as much as the loose two,
	# so the bench can build with them before the way out.
	var got := GameState.recover_lost_kit()
	check(not got.is_empty() and not GameState.has_lost_kit(), "recovering it clears the drop")
	check(int(GameState.raid_bag.get("FIRE", 0)) == 3 and GameState.raid_scrap == 17,
		"the bag, the part off the sword's graph and the scrap are being carried again (%s)"
			% str(GameState.raid_bag))
	check(GameState.raid_carried_weapons == ["SWORD"], "the weapon rides along as cargo")
	check(not GameState.weapon_boards.has("SWORD") and not GameState.owned_weapons.has("SWORD"),
		"and is not home yet — the rack is untouched")

	# Built onto the weapon in hand out there, a part from the drop is spent
	# from the bag like any other.
	check(GameState.raid_board.place("FIRE", Vector2i(2, 2), 0)
			and GameState.take_component("FIRE", GameState.raid_bag),
		"a recovered part can go onto the graph in hand")

	var stash_before := int(GameState.stash.get("FIRE", 0))
	var result := GameState.extract()
	check(GameState.owned_weapons.has("SWORD"), "walking out puts the weapon back on the rack")
	check(GameState.graph_is_bare("SWORD"),
		"bare: what was built on it came home in the bag (%s)" % str(GameState.weapon_board("SWORD").used_components()))
	check(int(GameState.stash.get("FIRE", 0)) == stash_before + 2, "what was left in the bag goes to the stash")
	check(int(GameState.weapon_board("ROCK").used_components().get("FIRE", 0)) == 1,
		"and the part built on in the field comes home on the rock's graph")
	check((result.get("recovered", []) as Array).size() == 1,
		"and the results sheet is told what came back out")

	# The rock is never lost, but its graph is: what was built onto it comes
	# back in the bag too, and leaves alone whatever was built onto the rock
	# meanwhile.
	GameState.deploy("ROCK")
	GameState.raid_board.place("PIERCE", Vector2i(1, 2), 0)
	GameState.die({"room": [2, 3], "pos": [640.0, 320.0]})
	var rock := GameState.weapon_board("ROCK")
	rock.place("DAMAGE", Vector2i(1, 2), 0)
	GameState.deploy("SWORD")
	GameState.recover_lost_kit()
	check(int(GameState.raid_bag.get("PIERCE", 0)) == 1 and int(GameState.raid_bag.get("FIRE", 0)) == 1,
		"the rock's lost graph comes back as parts in the bag (%s)" % str(GameState.raid_bag))
	var pierce_before := int(GameState.stash.get("PIERCE", 0))
	GameState.extract()
	check(GameState.weapon_board("ROCK").used_components() == {"DAMAGE": 1}
			and int(GameState.stash.get("PIERCE", 0)) == pierce_before + 1,
		"and walked out, they go to the shelves, not over the rock's new graph")

	# A raid parked back when a recovered weapon rode with the graph it fell
	# with: opened now, what was built on that graph is in the bag instead.
	var old_cargo := Weapons.make_board("SWORD")
	old_cargo.place("FIRE", Vector2i(2, 2), 0)
	GameState._read_raid({"in_raid": true, "raid_weapons": ["ROCK"],
		"raid_carried_boards": {"SWORD": old_cargo.serialize()}, "raid_carried_weapons": ["SWORD"]})
	check(int(GameState.raid_bag.get("FIRE", 0)) == 1 and GameState.raid_carried_weapons == ["SWORD"],
		"a raid parked with a graph as cargo opens with its parts in the bag (%s)" % str(GameState.raid_bag))
	GameState._forget_raid()

## --- what the next raid puts back on the floor ------------------------------
## Somewhere in this room a body could be standing: open floor, clear of
## `away_from` — the door the next run walks in
## through. A drop left underfoot would be picked up before it was ever seen.
func standing_spot(r: Room, away_from: Vector2) -> Vector2:
	for x in range(3, Room.W - 4):
		for y in range(3, Room.H - 3):
			if r.is_solid(x, y):
				continue
			var p := r.cell_center(x, y)
			if p.distance_to(away_from) > 260.0:
				return p
	return away_from

## A raid that tidies itself up the way the game does: the screen that owns one
## frees it the moment it finishes, and without that the view keeps reading a
## player who is no longer there.
func start_raid() -> Raid:
	var r := Raid.new()
	r.finished.connect(func(_result: String, _payload: Dictionary) -> void: r.queue_free())
	add_child(r)
	await frames(4)
	return r

func _floor() -> void:
	# A part on the sword, so there is something on its graph to come back.
	GameState.weapon_board("SWORD").place("PIERCE", Vector2i(2, 2), 0)
	GameState.deploy("SWORD")
	var raid := await start_raid()
	var died_in: Vector2i = raid.room.coord
	# The room's own spot; the player is put there in the world.
	var died_at := standing_spot(raid.room, raid.room.spawn_point())
	raid.player.global_position = raid.room.to_global(died_at)
	await frames(2)
	raid.player.apply_damage(99999.0)
	await frames(4)
	check(GameState.has_lost_kit(), "dying in a real room leaves a drop")
	check((GameState.lost_kit.get("room", []) as Array) == [died_in.x, died_in.y],
		"in the room it happened in (%s)" % str(died_in))
	await frames(2)

	# Back in. The map is the same map, so the room is where it was.
	GameState.deploy("ROCK")
	var back := await start_raid()
	check(back.map.has_room(died_in), "the floor is the one that was died on")
	check((back.map.get_record(died_in) as Dictionary).has("lost_kit"),
		"and the room's own record is holding the kit for it")

	back.go_to(died_in)
	await frames(2)
	var on_floor: LostKit = null
	for c in back.room.get_children():
		if c is LostKit:
			on_floor = c
	check(on_floor != null, "walking in finds it lying there")
	if on_floor == null:
		return
	check(absf(on_floor.position.x - died_at.x) < 24.0,
		"on the spot it fell on (%.0f px across from it)"
			% absf(on_floor.position.x - died_at.x))
	check(on_floor.size() >= 1, "with what was in it (%d things)" % on_floor.size())
	check(GameState.has_lost_kit(), "and still waiting to be picked up")

	# And walking onto it is all it takes.
	back.player.global_position = on_floor.global_position
	await frames(3)
	check(not GameState.has_lost_kit(), "touching it picks it up")
	check(GameState.raid_carried_weapons.has("SWORD"), "the weapon is being carried again")
	check(int(GameState.raid_bag.get("PIERCE", 0)) == 1,
		"and the part off its graph is in the bag the bench builds from (%s)" % str(GameState.raid_bag))
	check(not (back.map.get_record(died_in) as Dictionary).has("lost_kit"),
		"and the room is not holding it any more")
	back.queue_free()
	await frames(2)
