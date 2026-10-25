extends Node2D
## Two rules the hideout used to keep to itself: what the forge costs, and that
## a weapon is its graph — the weapon's own part on the root, the player's build
## after it, one graph per weapon and none without one. Both are the profile's
## now, so they hold for every caller and not only for a panel's buttons — and
## this is what says so, with no renderer.
##
## And one the profile had not been keeping: a profile started over starts from
## nothing. What the last one made of the hideout — a workbench grown, a vault
## deepened — is not handed on to the next.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[FORGE] PASS ", what)
	else:
		fails += 1
		push_error("FORGE FAIL: " + what)

func _ready() -> void:
	GameState.reset_profile()

	# --- the forge ------------------------------------------------------------
	# Three of one part on the shelves and nothing else, so what the forge takes
	# and what it gives back can be counted whatever it happens to make.
	GameState.stash.clear()
	GameState.stash["DAMAGE"] = GameState.FORGE_INPUTS
	GameState.scrap = GameState.FORGE_COST - 1
	check(not GameState.can_forge(), "a scrap short of the price, the forge is shut")
	GameState.scrap = GameState.FORGE_COST
	check(GameState.can_forge(), "at the price, with parts to melt, it is open")
	GameState.stash["DAMAGE"] = GameState.FORGE_INPUTS - 1
	check(not GameState.can_forge(), "a part short of the inputs, it is shut")
	GameState.stash["DAMAGE"] = GameState.FORGE_INPUTS

	var pick: Array[String] = []
	for i in GameState.FORGE_INPUTS:
		pick.append("DAMAGE")
	var made := GameState.forge_component(pick)
	check(made != "" and Components.exists(made), "the forge gives a part back (%s)" % made)
	check(GameState.scrap == 0, "and takes exactly the price (%d left)" % GameState.scrap)
	check(GameState.stash_total() == 1 and int(GameState.stash.get(made, 0)) == 1,
		"melts the inputs, and shelves the one part made (%s)" % str(GameState.stash))
	check(not GameState.can_forge(), "with the scrap gone it is shut again")
	check(GameState.forge_component(pick) == "" and GameState.stash_total() == 1,
		"and shut, it takes nothing")

	# --- a weapon is its graph -------------------------------------------------
	GameState.reset_profile()
	var graphs: Array = []
	for w in GameState.owned_weapons:
		if GameState.weapon_boards.has(w):
			graphs.append(w)
	check(graphs.size() == GameState.owned_weapons.size(),
		"a new profile has a graph on every weapon it owns (%s)" % str(graphs))
	var sword := GameState.weapon_board("SWORD")
	check(String(sword.root_entry().get("id", "")) == Weapons.root_part("SWORD"),
		"the sword's graph starts with the sword's own part (%s)" % sword.root_entry().get("id", "nothing"))
	check(GameState.graph_is_bare("SWORD"), "and nothing is built on it yet")
	check(sword == GameState.weapon_board("SWORD"), "asking again is the same graph, not a copy")
	check(sword.width == GameState.board_size().x and sword.height == GameState.board_size().y,
		"on the workbench's own grid (%dx%d)" % [sword.width, sword.height])
	# Building on it is building on the profile: what the gate carries is a copy.
	check(sword.erase_at(sword.root) == "" and sword.has_root(), "the weapon's own part cannot be taken off")
	check(sword.place("FIRE", Vector2i(2, 2), 0), "the build goes on after it")
	check(not GameState.graph_is_bare("SWORD") and sword.used_components() == {"FIRE": 1},
		"and the graph counts what was built and not the root (%s)" % str(sword.used_components()))
	GameState.deploy("SWORD")
	check(GameState.raid_board != null and GameState.raid_board != sword
			and GameState.raid_board.used_components() == {"FIRE": 1},
		"deploying carries a copy of the graph, FIRE and all")
	GameState.raid_board.place("DAMAGE", Vector2i(2, 1), 0)
	GameState.extract()
	check(GameState.weapon_board("SWORD").used_components() == {"FIRE": 1, "DAMAGE": 1},
		"and an edit made in the field comes home with it (%s)" % str(GameState.weapon_board("SWORD").used_components()))
	# A weapon that turns up with no graph — a profile from before weapons had
	# them — is handed its bare one, so it always fires something.
	GameState.weapon_boards.erase("GUN")
	var gun := GameState.weapon_board("GUN")
	check(gun != null and String(gun.root_entry().get("id", "")) == Weapons.root_part("GUN") and gun.used_components().is_empty(),
		"a weapon with no graph is handed its bare one")

	# --- the rock's graph falls with the kit, the rock does not -----------------
	GameState.deploy("ROCK")
	GameState.raid_board.place("PIERCE", Vector2i(1, 2), 0)
	var lost := GameState.die({"room": [1, 1], "pos": [100.0, 100.0]})
	check(GameState.owned_weapons.has("ROCK"), "there is always another rock")
	check(GameState.graph_is_bare("ROCK"), "with nothing on it: what was built went with the kit")
	check(int((lost.get("parts", {}) as Dictionary).get("PIERCE", 0)) == 1,
		"and the results are told what was built into it (%s)" % str(lost.get("parts", {})))
	check((GameState.lost_kit.get("boards", {}) as Dictionary).has("ROCK")
			and not (GameState.lost_kit.get("weapons", []) as Array).has("ROCK"),
		"the drop holds the rock's graph and not the rock (%s)" % str(GameState.lost_kit.get("weapons", [])))

	_started_over()

	print("[FORGE] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## --- a profile started over starts from nothing --------------------------------

## Every facility at its highest level, as a profile that has built everything.
func built_up() -> void:
	for key in GameState.facilities:
		GameState.facilities[key] = int(GameState.FACILITY_INFO[key]["max"])

## The facilities that are not at the level a new profile has them at.
func built() -> Array:
	var out: Array = []
	for key in GameState.facilities:
		if int(GameState.facilities[key]) != GameState.FACILITY_START:
			out.append(String(key))
	return out

## However a profile is started — wiped, its slot emptied, an empty slot opened
## after another — the hideout is as a new game finds it, and a save brings back
## its own. The facilities used to be left as whatever profile was open before
## had them, so a new game began with that one's workbench.
func _started_over() -> void:
	GameState.reset_profile()
	var kept := GameState.slot
	var other := kept % GameState.SAVE_SLOTS + 1
	GameState.delete_slot(other)
	check(built().is_empty() and GameState.board_size() == Vector2i(GameState.weapon_board("SWORD").width,
			GameState.weapon_board("SWORD").height),
		"(a new profile's facilities are at their first level, and its boards on that workbench's grid)")

	built_up()
	GameState.reset_profile()
	check(built().is_empty(), "wiping a profile puts every facility back to its first level (still built: %s)" % str(built()))

	# A built-up profile in one slot, and an empty slot opened after it.
	built_up()
	GameState.save_game()
	GameState.load_slot(other)
	check(built().is_empty(), "an empty slot opened after a built-up profile starts from nothing (still built: %s)" % str(built()))
	check(GameState.board_size() == Vector2i(GameState.weapon_board("SWORD").width, GameState.weapon_board("SWORD").height),
		"with its boards on the grid its own workbench has (%s)" % str(GameState.board_size()))
	GameState.load_slot(kept)
	check(built().size() == GameState.facilities.size(),
		"and the built-up profile's save brings its own levels back (%s)" % str(GameState.facilities))

	# A save that says nothing of a facility — one written before the facility
	# was — has it at its first level, not at the last profile's.
	var path := GameState.slot_path(kept)
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	(saved["facilities"] as Dictionary).erase("medbay")
	(saved["records"] as Dictionary).erase("kills")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(saved))
	f.close()
	GameState.records["kills"] = 99
	GameState.load_slot(kept)
	check(int(GameState.facilities["medbay"]) == GameState.FACILITY_START
			and int(GameState.facilities["workbench"]) == int(GameState.FACILITY_INFO["workbench"]["max"]),
		"a facility a save does not mention is at its first level, and the ones it does are as saved (%s)" % str(GameState.facilities))
	check(int(GameState.records["kills"]) == 0, "nor is a record it does not mention the last profile's (%d)" % int(GameState.records["kills"]))

	# Emptying the slot being played leaves a new profile in its place.
	GameState.delete_slot(kept)
	check(built().is_empty(), "emptying the slot being played leaves a profile that has built nothing (still built: %s)" % str(built()))
	GameState.delete_slot(other)
