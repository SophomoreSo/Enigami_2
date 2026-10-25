extends Node
## A raid can be put down and picked back up. MAIN MENU inside one writes the
## run into the save slot instead of ending it, and opening that slot again
## walks back into the same raid rather than into the hideout.
##
## The map is not in the save — it is laid again from the same rows — so what this checks
## is that the run written over it comes back: the room the player was standing
## in, where they were standing, what was left of them, the raid clock, and the
## rooms as the run had left them. It goes through disk, not memory: the save is
## written, the slot is read back, and the raid is rebuilt from what came out.

const GameScript := preload("res://app/game.gd")
const SLOT := 3

var game: Node
var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[PARK] PASS ", what)
	else:
		fails += 1
		push_error("PARK FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## A room next door to this one, or the same one when the map has boxed it in.
func neighbour(raid: Raid) -> Vector2i:
	for dir in raid.map.doors_for(raid.room.coord):
		var target: Vector2i = raid.room.coord + RaidMap.dir_delta(int(dir))
		if raid.map.has_room(target):
			return target
	return raid.room.coord

func _ready() -> void:
	GameState.slot = SLOT
	GameState.reset_profile()
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(6)

	game._deploy("SWORD")
	await frames(20)
	var raid: Raid = game.current
	check(raid != null and game.state == GameScript.State.RAID, "deployed into a raid")
	var seed_was: int = raid.map.seed_base
	# Read off the first raid while it is still alive: parking frees it.
	var entry_was: Vector2i = raid.map.entry

	# Make the run worth saving: walk next door, take a wound, and put a few
	# seconds on the clock. A raid resumed at its entry with full health would
	# pass this test by doing nothing at all.
	var moved := neighbour(raid)
	raid.go_to(moved)
	await frames(10)
	raid.player.health = 42.0
	raid.player.global_position += Vector2(64.0, 0.0)
	raid.map.elapsed = 37.5
	var where := raid.player.global_position
	var enemies_left: int = int((raid.map.get_record(moved).get("enemies", []) as Array).size())
	check(moved != entry_was, "walked into another room (%s)" % moved)

	# --- putting it down -----------------------------------------------------
	game._pause()
	await frames(6)
	check(game.pause_park != null and game.pause_park.visible,
		"a raid's pause menu offers '%s'" % Loc.t("menu.pause.park"))
	check(not game.pause_title.visible, "and not the one that does not save")
	# Both ways out of a raid ask first, and the question is what says what the
	# answer costs. CANCEL is back to PAUSED with nothing done.
	game.pause_abandon.emit_signal("pressed")
	await frames(6)
	check(game.pause_asking() == "abandon" and game.get_tree().paused
			and game.state == GameScript.State.RAID,
		"ABANDON RAID asks before it forfeits anything ('%s')" % Menus.note_for("abandon"))
	ask_answer("abandon", "back")
	await frames(6)
	check(game.pause_asking() == "" and game.pause_main.visible and game.state == GameScript.State.RAID,
		"and CANCEL is back to PAUSED, the raid as it was")
	game.pause_park.emit_signal("pressed")
	await frames(6)
	check(game.pause_asking() == "park" and game.state == GameScript.State.RAID
			and not GameState.has_parked_raid(),
		"MAIN MENU asks too, before anything is written ('%s')" % Menus.note_for("park"))
	ask_answer("park", "confirm")
	await frames(10)
	check(game.state == GameScript.State.TITLE, "answering it hands back to the title")
	check(GameState.has_parked_raid(), "with the raid parked in the slot")
	check(GameState.in_raid and GameState.raid_weapon == "SWORD",
		"the kit is still checked out to it")

	# --- picking it back up --------------------------------------------------
	# Through disk: the slot is read back the way opening it on the title reads
	# it, so nothing left in memory can pass for a save that was written.
	GameState.raid_progress = {}
	GameState.in_raid = false
	check(GameState.load_slot(SLOT), "the slot reads back off disk")
	check(GameState.has_parked_raid(), "and the raid is in what came out of it")
	game._start_game()
	# What was restored is read before the raid is allowed to run. `_ready` has
	# already put the room and the player back by the time `_start_game`
	# returns, and what comes next is a live room with monsters standing in it:
	# a couple of frames of them is enough to move the player and take a bite
	# out of the health that was just restored, which is the raid working, not
	# the save failing.
	var back: Raid = game.current
	var health_back: float = back.player.health if back != null else 0.0
	var pos_back: Vector2 = back.player.global_position if back != null else Vector2.ZERO
	await frames(20)
	check(game.state == GameScript.State.RAID, "starting that slot walks into the raid")
	check(back != null and back.map.seed_base == seed_was,
		"the same floor, under the same run number (%d)" % back.map.seed_base)
	check(back.room != null and back.room.coord == moved,
		"in the room it was left in (%s, wanted %s)"
			% [Vector2i.ZERO if back.room == null else back.room.coord, moved])
	check(absf(health_back - 42.0) < 0.5,
		"with the wound it was left with (%.1f)" % health_back)
	check(pos_back.distance_to(where) < 2.0,
		"standing where it was left (%s, wanted %s)" % [pos_back, where])
	check(absf(back.map.elapsed - 37.5) < 0.5,
		"and the clock where it was left (%.1f)" % back.map.elapsed)
	var back_enemies: int = int((back.map.get_record(moved).get("enemies", []) as Array).size())
	check(back_enemies == enemies_left,
		"the room holds what it held (%d of %d)" % [back_enemies, enemies_left])
	check(bool(back.map.get_record(entry_was).get("visited", false)),
		"and the rooms already opened are still open")

	# --- and it is not left behind -------------------------------------------
	# Extracting ends the raid, and a raid that has ended is not parked in the
	# slot any more: opening it again has to land in the hideout.
	GameState.extract()
	check(not GameState.has_parked_raid(), "extracting clears the parked raid")
	check(not GameState.in_raid, "and the slot is out of the raid")

	print("[PARK] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## Presses the answer `item` on the question `menu` that PAUSED has up.
func ask_answer(menu: String, item: String) -> void:
	var text := Menus.text_for(menu, item)
	for b in (game.pause_asks[menu] as Control).find_children("*", "Button", true, false):
		if (b as Button).text == text:
			(b as Button).emit_signal("pressed")
			return
	check(false, "the %s question has a '%s' to press" % [menu, text])
