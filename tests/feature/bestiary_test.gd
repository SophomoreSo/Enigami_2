extends Node2D
## The monster dictionary's rules (`GameState.bestiary`): a new game has met
## nothing; walking into a room in a raid meets every monster in it, and a
## monster's attack going off is its skill seen — the Arbiter's second form's
## once it has turned; what was met and seen is in the save and comes back with
## it; and a new game starts from nothing again.
##
## What the page draws of it is `tests/graphics/editor_close_test`'s.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[DEX] PASS ", what)
	else:
		fails += 1
		push_error("DEX FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _ready() -> void:
	GameState.reset_profile()
	for n in range(1, GameState.SAVE_SLOTS + 1):
		GameState.delete_slot(n)
	seed(20261009)
	await _met_and_seen()
	_kept()
	print("[DEX] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

func _met_and_seen() -> void:
	check(GameState.bestiary["monsters"].is_empty() and GameState.bestiary["skills"].is_empty(),
		"a new game has met nothing")
	check(Monsters.DEX.has("ARBITER") and not Monsters.DEX.has("DUMMY") and not Monsters.DEX.has("GUNMAN"),
		"the dictionary is the monsters a raid has in it")
	check(Monsters.skills_of("CRAWLER") == ["board"] and Monsters.skills_of("ARBITER") == ["board", "board_phase2"]
			and Monsters.skills_of("DUMMY").is_empty(),
		"a monster's skills are its boards")
	GameState.deploy("SWORD")
	var raid := Raid.new()
	raid.finished.connect(func(_result: String, _payload: Dictionary) -> void: raid.queue_free())
	add_child(raid)
	await frames(4)
	var with := Vector2i(-1, -1)
	for c in raid.map.rooms:
		if c != raid.room.coord and not (raid.map.rooms[c].get("enemies", []) as Array).is_empty():
			with = c
			break
	raid.go_to(with)
	await frames(2)
	var met: Array = []
	var one: Enemy = null
	for n in raid.room.get_children():
		if n is Enemy and Monsters.DEX.has(n.kind):
			met.append(n.kind)
			if one == null:
				one = n
	check(not met.is_empty() and met.all(func(k: String) -> bool: return GameState.knows_monster(k)),
		"walking into a room meets every monster in it (%s)" % str(met))
	check(one != null and not GameState.knows_skill(one.kind, "board"), "and sees none of their skills yet")
	if one != null:
		one.target = raid.player
		one._on_fired(one.runner.base_payload_provider.call())
		check(GameState.knows_skill(one.kind, "board"), "a monster's attack going off is its skill seen")
	# The Arbiter, turned: what it casts then is its second form.
	var boss := Enemy.new()
	boss.setup("ARBITER")
	raid.room.add_child(boss)
	await frames(1)
	boss.phase = 2
	check(boss.skill == "board_phase2", "the Arbiter turned casts its second form")
	raid._meet(boss)
	boss.target = raid.player
	boss._on_fired(boss.runner.base_payload_provider.call())
	check(GameState.knows_skill("ARBITER", "board_phase2") and not GameState.knows_skill("ARBITER", "board"),
		"and that is the skill seen, the first form's still not")
	raid.queue_free()
	await frames(2)

func _kept() -> void:
	var met: Array = GameState.bestiary["monsters"].duplicate()
	var seen: Array = GameState.bestiary["skills"].duplicate()
	GameState.save_game()
	GameState.bestiary = {"monsters": [], "skills": []}
	check(GameState.load_game() and GameState.bestiary["monsters"] == met and GameState.bestiary["skills"] == seen,
		"what was met and seen comes back with the save (%d, %d)" % [met.size(), seen.size()])
	GameState.reset_profile()
	check(GameState.bestiary["monsters"].is_empty() and GameState.bestiary["skills"].is_empty(),
		"and a new game knows none of it")
