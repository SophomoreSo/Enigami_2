extends Node
## Up to three weapons are carried, and one of them is in hand.
##
## At home the kit is what the rack was left carrying: picked weapon by weapon,
## three at most, never none. A raid is walked into with all of it — every
## weapon and the graph on each — and a key apart: a slot's own key, or a step
## along with the wheel, puts another in hand, and each keeps its own graph and
## its own wait between casts. Walking out takes the whole kit home; dying drops
## the whole kit where the player fell.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[KIT3] PASS ", what)
	else:
		fails += 1
		push_error("KIT3 FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## Frames until `cond` holds, or `secs` of game time: whether it did.
func until(cond: Callable, secs: float) -> bool:
	var t := 0.0
	while t < secs:
		if cond.call():
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return bool(cond.call())

func fresh() -> void:
	GameState.reset_profile()
	for n in range(1, GameState.SAVE_SLOTS + 1):
		GameState.delete_slot(n)

func start_raid() -> Raid:
	var r := Raid.new()
	r.finished.connect(func(_result: String, _payload: Dictionary) -> void: r.queue_free())
	add_child(r)
	await frames(4)
	return r

## A key, pressed and let go of, the way a hand does it.
func tap_key(code: int) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.keycode = code
		e.pressed = down
		Input.parse_input_event(e)
	await frames(2)

## One notch of the wheel: a button down and up again inside a frame.
func wheel(button: int) -> void:
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = button
		e.pressed = down
		Input.parse_input_event(e)
	await frames(2)

func _ready() -> void:
	fresh()
	seed(20261003)
	_at_home()
	_old_saves()
	await _in_the_room()
	await _in_a_raid()
	await _put_down_and_picked_up()
	await _at_the_bench()
	_walking_out()
	_dying()
	print("[KIT3] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## --- the kit the rack is left carrying -------------------------------------------
func _at_home() -> void:
	fresh()
	var first: String = GameState.owned_weapons[0]
	check(GameState.carried() == [first],
		"with nothing picked the kit is the first weapon on the rack (%s)" % str(GameState.carried()))
	check(GameState.carry("SWORD") and GameState.carry("GUN"), "a weapon the vault has can be carried")
	check(GameState.carried().size() == 3 and GameState.carried().size() == GameState.MAX_CARRIED,
		"three is a full kit (%s)" % str(GameState.carried()))
	var slots := GameState.carried()
	check(slots[0] == first and slots[1] == "SWORD" and slots[2] == "GUN", "slotted in the order they were picked")
	check(GameState.carry("GUN") and GameState.carried() == slots, "picking one already carried changes nothing")

	# A fourth has no slot of its own: it takes the place of the weapon the rack
	# was on. No weapon of the game's is spare, so one stands in.
	GameState.owned_weapons.append("SPARE")
	check(GameState.carry("SPARE", "SWORD") and GameState.carried() == [first, "SPARE", "GUN"],
		"with the kit full, a weapon picked takes the slot of the one that was in hand (%s)" % str(GameState.carried()))
	check(not GameState.carry("NOSUCH"), "a weapon the vault does not have is not carried")
	GameState.owned_weapons.erase("SPARE")
	check(GameState.carried() == [first, "GUN"], "a weapon the vault no longer has is not in the kit (%s)" % str(GameState.carried()))

	check(GameState.leave_behind("GUN") and GameState.carried() == [first], "a weapon can be put back")
	check(not GameState.leave_behind(first) and GameState.carried() == [first], "but not the last one: nobody goes in empty-handed")

	# The rack is left as it was, through a save.
	GameState.carry("GUN")
	GameState.carry("SWORD")
	var was := GameState.carried()
	GameState.save_game()
	GameState.loadout = []
	GameState.load_slot(GameState.slot)
	check(GameState.carried() == was, "the kit is kept with the profile (%s)" % str(GameState.carried()))

## --- a profile from before there was a kit ------------------------------------------
func _old_saves() -> void:
	fresh()
	GameState.deploy("SWORD")
	GameState.raid_board.place("FIRE", Vector2i(2, 2), 0)
	var board: Dictionary = GameState.raid_board.serialize()
	GameState.park_raid({"room": [0, 0], "pos": [100.0, 100.0], "health": 50.0})
	# As it was written when a raid carried one weapon: the weapon, and its graph.
	var path := GameState.slot_path(GameState.slot)
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	saved.erase("raid_weapons")
	saved.erase("raid_graphs")
	saved.erase("raid_hand")
	saved.erase("loadout")
	saved["raid_weapon"] = "SWORD"
	saved["raid_board"] = board
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(saved))
	f.close()
	GameState.load_slot(GameState.slot)
	check(GameState.in_raid and GameState.raid_weapons == ["SWORD"] and GameState.raid_weapon == "SWORD",
		"a raid parked with one weapon reads back as a kit of one (%s)" % str(GameState.raid_weapons))
	check(GameState.raid_board != null and GameState.raid_board.used_components() == {"FIRE": 1},
		"with the graph that was on it")
	check(GameState.loadout.is_empty(), "and a profile with no kit picked has the rack where it always was")
	GameState.die()

## --- the room between raids ---------------------------------------------------------
func _in_the_room() -> void:
	fresh()
	var world := HideoutWorld.new()
	add_child(world)
	await frames(4)
	var first: String = GameState.owned_weapons[0]
	check(world.weapon_id == first and world.player.weapons == [first],
		"the room opens with the rack on its first weapon, and the player holding it")
	world.set_weapon("GUN")
	check(world.weapon_id == "GUN" and GameState.carried() == [first, "GUN"],
		"picking a weapon takes it in hand and into the kit (%s)" % str(GameState.carried()))
	check(world.player.weapons == [first, "GUN"] and world.player.weapon_id == "GUN"
			and world.player.runner.board == world.armed_board(),
		"the player in the room is holding the kit, with the graph the gate would carry in hand")
	await tap_key(KEY_3)
	check(world.player.empty_handed() and world.player.hand == 2 and world.player.runner == world.player.hand_runner
			and world.player.hand_board == GameState.weapon_board(Weapons.HAND) and world.weapon_id == "GUN",
		"a slot no weapon is in is an empty hand on its key, and the rack stays where it was (%s)" % world.weapon_id)
	world.set_weapon("SWORD")
	check(world.player.weapons.size() == 3 and world.player.hand == 2, "a third joins it")

	# The keys that change weapon in a raid change it here.
	await tap_key(KEY_1)
	check(world.player.hand == 0 and world.weapon_id == first,
		"a slot's key on the floor puts that weapon in hand, and the rack is on it (%s)" % world.weapon_id)
	check(world.armed_board() == GameState.weapon_board(first), "so its graph is the one assembly would open")

	# Put back, and the hand moves on.
	world.set_weapon("GUN")
	check(world.leave_weapon("GUN") and not GameState.is_carried("GUN") and world.weapon_id != "GUN"
			and world.player.weapons == GameState.carried(),
		"a weapon put back leaves the kit, and the hand goes to one still carried (%s)" % world.weapon_id)

	# The gate walks out holding the weapon in hand, with the rest beside it.
	world.set_weapon("GUN")
	var asked: Array = []
	world.deploy_requested.connect(func(w: String) -> void: asked.append(w))
	(world.stations["gate"] as Station).used.emit(world.stations["gate"])
	check(asked == ["GUN"], "the gate asks to go with the weapon in hand (%s)" % str(asked))
	world.queue_free()
	await frames(2)

## --- three weapons, a key apart -----------------------------------------------------
func _in_a_raid() -> void:
	fresh()
	var sword_built := GameState.weapon_board("SWORD")
	sword_built.place("FIRE", Vector2i(2, 2), 0)
	GameState.deploy(["SWORD", "GUN", "ROCK"], "GUN")
	check(GameState.raid_weapons == ["SWORD", "GUN", "ROCK"] and GameState.raid_hand == 1
			and GameState.raid_weapon == "GUN",
		"deploying carries the kit, and walks in holding the one asked for")
	check(GameState.raid_graphs.size() == 4 and GameState.raid_graphs["SWORD"] != sword_built
			and (GameState.raid_graphs["SWORD"] as SkillBoard).used_components() == {"FIRE": 1}
			and GameState.raid_graphs.has(Weapons.HAND)
			and GameState.raid_graphs[Weapons.HAND] != GameState.weapon_board(Weapons.HAND),
		"with a copy of the graph on each, and of the empty hand's")
	check(not GameState.owned_weapons.has("SWORD") and not GameState.owned_weapons.has("GUN")
			and GameState.owned_weapons.has(GameState.FREE_WEAPON),
		"every weapon carried is out of the vault, but the free one")

	var raid := await start_raid()
	var p := raid.player
	check(p.weapons == ["SWORD", "GUN", "ROCK"] and p.hand == 1 and p.weapon_id == "GUN"
			and p.runners.size() == 3 and p.runner == p.runners[1],
		"the player has all three, each with its own runner, and the one asked for in hand")
	var own := true
	for i in 3:
		own = own and (p.runners[i] as SkillRunner).board == GameState.raid_graphs[p.weapons[i]]
	check(own, "each runner walks the raid's copy of its own weapon's graph")

	# The keys, and the wheel.
	await tap_key(KEY_1)
	check(p.hand == 0 and p.weapon_id == "SWORD" and p.runner == p.runners[0], "1 draws the first weapon")
	check(GameState.raid_hand == 0 and GameState.raid_weapon == "SWORD" and GameState.raid_board == p.runner.board,
		"and the profile knows which is in hand: its graph is the one assembly opens")
	await tap_key(KEY_3)
	check(p.weapon_id == "ROCK", "3 draws the third")
	await tap_key(KEY_2)
	check(p.weapon_id == "GUN", "2 the second")
	await tap_key(KEY_4)
	check(p.empty_handed() and p.hand == Player.EMPTY_HAND and p.weapon_id == "" and p.weapon_hands() == null
			and p.runner == p.hand_runner and p.hand_board == GameState.raid_graphs[Weapons.HAND]
			and String(p.runner.board.root_entry().get("id", "")) == "HEADBUTT" and p.can_cast(),
		"4 draws the empty hand: nothing in it, and the raid's copy of its own graph to cast, a PUNCH")
	check(GameState.raid_hand == 1 and GameState.raid_weapon == "GUN",
		"and the profile stays on the weapon last in hand, whose graph assembly opens")
	await tap_key(KEY_2)
	await wheel(MOUSE_BUTTON_WHEEL_DOWN)
	check(p.weapon_id == "ROCK", "a notch of the wheel down is the next weapon")
	await wheel(MOUSE_BUTTON_WHEEL_DOWN)
	check(p.empty_handed(), "on from the last weapon to the empty hand")
	await wheel(MOUSE_BUTTON_WHEEL_DOWN)
	check(p.weapon_id == "SWORD", "and round from it to the first")
	await wheel(MOUSE_BUTTON_WHEEL_UP)
	check(p.empty_handed(), "and a notch up is the one before")
	await wheel(MOUSE_BUTTON_WHEEL_UP)
	check(p.weapon_id == "ROCK", "(and the one before that, the last weapon)")

	# Not while a screen has the keys.
	raid.set_editing(true)
	await tap_key(KEY_1)
	await wheel(MOUSE_BUTTON_WHEEL_DOWN)
	check(p.weapon_id == "ROCK", "with assembly open over the raid, neither changes the weapon")
	raid.set_editing(false)
	await frames(2)

	# The computer's hands from here, so nobody at the desk is steering.
	var hands := ComputerHands.new()
	p.input.add(hands)
	hands.point_at(p.global_position + Vector2(300, 0))
	hands.take_weapon(0)
	await frames(2)
	check(p.weapon_id == "SWORD", "(the computer draws by slot too)")
	hands.take_weapon(7)
	await frames(2)
	check(p.weapon_id == "SWORD", "a slot nothing is carried in draws nothing")

	# Each weapon is its own skill: what is cast is the graph of the one in hand.
	var forms: Array = []
	for i in 3:
		(p.runners[i] as SkillRunner).fired.connect(func(pl: Payload) -> void: forms.append([i, pl.form]))
	hands.attack = true
	check(await until(func() -> bool: return not forms.is_empty(), 2.0), "(the sword is cast)")
	hands.attack = false
	# A weapon's own form is the part on its root, by the same name.
	check(not forms.is_empty() and forms[0] == [0, Weapons.root_part("SWORD")],
		"attacking casts the graph of the weapon in hand (%s)" % str(forms))
	var sword_runner: SkillRunner = p.runner
	check(not sword_runner.is_ready(), "(and the sword is waiting to be cast again)")

	# Drawn straight after, the gun is ready: its wait is its own.
	forms.clear()
	hands.take_weapon(1)
	await frames(2)
	check(p.weapon_id == "GUN" and p.runner.is_ready(), "the weapon drawn has its own wait, and is ready at once")
	hands.attack = true
	check(await until(func() -> bool: return not forms.is_empty(), 2.0), "(the gun is cast)")
	hands.attack = false
	var only_gun := true
	for f in forms:
		only_gun = only_gun and int(f[0]) == 1
	check(only_gun and String(forms[0][1]) == "PROJECTILE", "and it is the gun's own graph that goes off (%s)" % str(forms))
	# And the sword, put away, has gone on waiting its wait out.
	check(await until(func() -> bool: return sword_runner.is_ready(), 5.0), "a weapon put away recovers in its slot")

	# A cast still out when its weapon is put away lands as that weapon's.
	Attacks.clear_in_flight(raid)
	var bolt := Payload.new()
	bolt.form = "PROJECTILE"
	bolt.damage = 10.0
	(p.runners[0] as SkillRunner).fired.emit(bolt)
	var landed: Projectile = null
	for c in raid.get_children():
		if c is Projectile:
			landed = c
	check(landed != null and is_equal_approx(landed.payload.damage,
			10.0 * float(Weapons.get_def("SWORD")["ranged_mul"])),
		"a flow leaving the sword's graph with the gun in hand is still the sword's")

	# A hold being charged does not follow the hand to the next weapon.
	await until(func() -> bool: return p.runner.is_ready(), 5.0)
	hands.cast = true
	check(await until(func() -> bool: return p.charge > 2.0, 3.0), "(a hold charges the gun)")
	hands.take_weapon(2)
	await frames(2)
	check(p.weapon_id == "ROCK" and is_zero_approx(p.cast_charge),
		"changing weapon lets go of what was being charged")
	hands.cast = false
	await frames(3)
	raid.queue_free()
	await frames(2)
	GameState.die()

## --- a raid put down holding one weapon is picked up holding it --------------------
func _put_down_and_picked_up() -> void:
	fresh()
	GameState.deploy(["SWORD", "GUN", "ROCK"])
	var raid := await start_raid()
	raid.player.switch_to(2)
	check(GameState.raid_hand == 2, "(the third weapon is in hand)")
	GameState.park_raid(raid.park())
	raid.queue_free()
	await frames(2)
	GameState.raid_hand = 0
	GameState.load_slot(GameState.slot)
	check(GameState.has_parked_raid() and GameState.raid_weapons == ["SWORD", "GUN", "ROCK"]
			and GameState.raid_hand == 2 and GameState.raid_graphs.size() == 4,
		"a parked raid keeps its kit, and which weapon was in hand")
	var back := await start_raid()
	check(back.player.weapons == ["SWORD", "GUN", "ROCK"] and back.player.weapon_id == "ROCK",
		"and is walked back into holding it")
	back.queue_free()
	await frames(2)
	GameState.die()

## --- the bench carries a kit's worth -----------------------------------------------
## There are more weapons than a kit holds, so the bench carries three: the one
## it is on and the next ones round.
func _at_the_bench() -> void:
	fresh()
	var bench := Sandbox.new()
	add_child(bench)
	await frames(4)
	var all: Array = Weapons.ids()
	check(Array(bench.player.weapons) == all.slice(0, Player.MAX_WEAPONS)
			and bench.player.weapon_id == bench.current_weapon()
			and bench.player.runner.board == bench.board(),
		"the bench puts a kit's worth on the player, the one it is on in hand, with its bench graph (%s)" % str(bench.player.weapons))
	await tap_key(KEY_2)
	check(bench.current_weapon() == String(all[1]) and bench.player.runner.board == bench.board(),
		"a slot's key changes weapon at the bench, and the bench is on that weapon (%s)" % bench.current_weapon())
	bench.cycle_weapon()
	check(bench.current_weapon() == String(all[2]) and bench.player.weapon_id == String(all[2])
			and bench.player.runner.board == bench.board(),
		"and the bench's own swap is the next one round (%s)" % bench.current_weapon())
	bench.cycle_weapon()
	check(bench.current_weapon() == String(all[3]) and bench.player.weapons.has(String(all[3])),
		"and on past the kit to a weapon it did not have in it (%s)" % bench.current_weapon())
	# On round whatever weapons there are after that one, to the last of them.
	for i in range(4, all.size()):
		bench.cycle_weapon()
	check(bench.current_weapon() == String(all[all.size() - 1]),
		"and on to the last weapon there is (%s)" % bench.current_weapon())
	bench.cycle_weapon()
	check(bench.current_weapon() == String(all[0]) and bench.player.hand == 0, "from the last back to the first")
	bench.queue_free()
	await frames(2)

## --- walking out takes the whole kit home ------------------------------------------
func _walking_out() -> void:
	fresh()
	GameState.carry("SWORD")
	GameState.carry("GUN")
	var kit := GameState.carried()
	GameState.deploy(kit)
	GameState.add_component("DAMAGE", 2, GameState.raid_bag)
	(GameState.raid_graphs["SWORD"] as SkillBoard).place("DAMAGE", Vector2i(2, 2), 0)
	(GameState.raid_graphs["GUN"] as SkillBoard).place("PIERCE", Vector2i(2, 2), 0)
	var result := GameState.extract()
	check(GameState.weapon_board("SWORD").used_components() == {"DAMAGE": 1}
			and GameState.weapon_board("GUN").used_components() == {"PIERCE": 1},
		"what was built in the field comes home on each weapon it was built on")
	var home := true
	for w in kit:
		home = home and GameState.owned_weapons.has(w)
	check(home and GameState.carried() == kit, "every weapon is back in the vault, and the rack is as it was left")
	check((result.get("weapons", []) as Array) == Array(kit), "and the results are told what was carried (%s)" % str(result.get("weapons", [])))

## --- dying drops the whole kit ----------------------------------------------------
func _dying() -> void:
	fresh()
	GameState.weapon_board("SWORD").place("FIRE", Vector2i(2, 2), 0)
	GameState.weapon_board("GUN").place("PIERCE", Vector2i(1, 2), 0)
	GameState.weapon_board("ROCK").place("DAMAGE", Vector2i(1, 2), 0)
	GameState.carry("ROCK")
	GameState.carry("SWORD")
	GameState.carry("GUN")
	var kit := GameState.carried()
	GameState.deploy(kit, "GUN")
	var lost := GameState.die({"room": [1, 1], "pos": [300.0, 300.0]})
	check((lost.get("weapons", []) as Array).size() == 3 and String(lost.get("weapon", "")) == "GUN",
		"a death is told every weapon that fell, and which was in hand")
	var parts: Dictionary = lost.get("parts", {})
	check(int(parts.get("FIRE", 0)) == 1 and int(parts.get("PIERCE", 0)) == 1 and int(parts.get("DAMAGE", 0)) == 1,
		"and everything built onto them (%s)" % str(parts))
	var drop: Dictionary = GameState.lost_kit
	var dropped: Array = drop.get("weapons", [])
	check(dropped.has("SWORD") and dropped.has("GUN") and not dropped.has(GameState.FREE_WEAPON),
		"the drop holds every weapon that can be lost (%s)" % str(dropped))
	check((drop.get("boards", {}) as Dictionary).size() == 3, "and the graph of all three, the free one's included")
	check(not GameState.owned_weapons.has("SWORD") and not GameState.owned_weapons.has("GUN")
			and GameState.owned_weapons == [GameState.FREE_WEAPON, "SHOVEL", "SHURIKEN", "RUNE"],
		"the vault is left with the free weapon, and what was not carried (%s)" % str(GameState.owned_weapons))
	check(GameState.graph_is_bare("ROCK") and GameState.graph_is_bare("SWORD"), "and every graph that went in is gone from it")
	check(GameState.carried() == [GameState.FREE_WEAPON], "the kit is what is left to carry (%s)" % str(GameState.carried()))

	# Going back for it, and walking it out.
	GameState.deploy()
	check(GameState.raid_weapons == [GameState.FREE_WEAPON], "going back is with what is left")
	GameState.recover_lost_kit()
	check(int(GameState.raid_bag.get("FIRE", 0)) == 1 and int(GameState.raid_bag.get("PIERCE", 0)) == 1
			and int(GameState.raid_bag.get("DAMAGE", 0)) == 1,
		"picked up, what was built onto all three is in the bag (%s)" % str(GameState.raid_bag))
	var shelved := {"FIRE": int(GameState.stash.get("FIRE", 0)), "PIERCE": int(GameState.stash.get("PIERCE", 0))}
	GameState.extract()
	check(GameState.owned_weapons.has("SWORD") and GameState.owned_weapons.has("GUN"), "walked out, the weapons are back on the rack")
	check(GameState.graph_is_bare("SWORD") and GameState.graph_is_bare("GUN")
			and int(GameState.stash.get("FIRE", 0)) == shelved["FIRE"] + 1
			and int(GameState.stash.get("PIERCE", 0)) == shelved["PIERCE"] + 1,
		"bare, with what was on them on the shelves")
	check(GameState.carried() == kit, "and carried again, as the rack was left (%s)" % str(GameState.carried()))
