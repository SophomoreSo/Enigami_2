extends Node
## Drives every screen and every attack form once, with rendering on, so that
## draw-time and runtime errors surface in CI-style runs.

const GameScript := preload("res://app/game.gd")
var game: Node
var log_lines: Array[String] = []
var fails := 0

func say(s: String) -> void:
	log_lines.append(s)
	print("[SMOKE] ", s)

## Counted as well as shouted: the count is what the exit code is made of.
func fail(what: String) -> void:
	fails += 1
	push_error("SMOKE FAIL: " + what)

func _ready() -> void:
	# Start from a clean profile so runs are repeatable.
	GameState.reset_profile()
	for n in range(1, GameState.SAVE_SLOTS + 1):
		GameState.delete_slot(n)
	seed(20260911)  # deterministic map and loot for repeatable runs
	await _run()
	print("[SMOKE] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## The cast button as an event rather than `Input.action_press`, which stamps the
## action with the current frame and so can have its release land in a frame the
## player has already processed — leaving `is_action_just_released` false and the
## cast never bought.
func _cast_button(down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_RIGHT
	e.pressed = down
	Input.parse_input_event(e)

func _run() -> void:
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(5)
	say("title ok, state=%d" % game.state)

	# The opening scene, which a wiped profile has not seen. Read a couple of
	# beats the way a player does, then skip out of it.
	game.goto_intro()
	await frames(5)
	var intro: Cutscene = game.current
	var beats := 0
	for i in 400:
		if intro.done or beats >= 3:
			break
		if intro.waiting_for_press() and intro.line_finished():
			intro.press()
			beats += 1
		await get_tree().process_frame
	say("intro ok, read %d beats, cast=%s" % [beats, str(intro.cast.keys())])
	intro.skip()
	await frames(6)
	say("intro handed over, state=%d (1 = hideout), seen=%s"
		% [game.state, str(GameState.intro_seen)])

	game.goto_hideout()
	await frames(5)
	say("hideout ok, weapons=%s" % str(GameState.owned_weapons))

	# Workbench editor over the hideout: the weapon's graph.
	game._edit_weapon_graph()
	await frames(3)
	var ed: SkillEditor = game.editor
	ed.selected = "DAMAGE"
	ed._hover_cell = Vector2i(2, 1)
	ed._click_left()
	ed._hover_pal = 3
	ed._update_hover(Vector2(720, 120))
	await frames(3)
	game._close_editor()
	await frames(3)
	say("workbench editor ok")

	# Deploy with the sword and the graph on it.
	game._deploy("SWORD")
	await frames(6)
	var raid: Raid = game.current
	say("raid ok, rooms=%d entry=%s" % [raid.map.rooms.size(), str(raid.map.entry)])

	# Fire the graph for a while, with both buttons: the cast button held and
	# let go, and the attack button held.
	var fire_count := [0]
	raid.player.runner.fired.connect(func(_p: Payload) -> void: fire_count[0] += 1)
	if Controls.short_label_for("attack") != "LMB":
		fail("attack is on %s, not LMB" % Controls.short_label_for("attack"))
	if Controls.short_label_for("cast_skill") != "RMB":
		fail("cast_skill is on %s, not RMB" % Controls.short_label_for("cast_skill"))
	say("LMB attacks, RMB charges and casts")
	Input.action_press("cast_skill")
	await frames(40)
	Input.action_release("cast_skill")
	await frames(4)
	Input.action_press("attack")
	await frames(40)
	Input.action_release("attack")
	say("the graph fired %d times" % fire_count[0])
	if fire_count[0] <= 0:
		fail("casting produced no output")

	# Every attack form, straight through the spawner, reaching round what it
	# hits with a NEAR — and none, where the NEAR is the attack: a touch on
	# everything round it, as a trigger's follow-up is here.
	for form in ["PROJECTILE", "SLASH", "DASHSLASH", "HEADBUTT", ""]:
		var p := Payload.new()
		p.form = form
		p.near = 1
		p.spread = Payload.new()
		p.spread.damage = 2.0
		p.spread.elements = ["FIRE"] as Array[String]
		p.damage = 5.0
		p.duplicates = 3
		p.elements = ["FIRE", "ICE"] as Array[String]
		p.pierce = 2
		p.homing = 1
		var trig := Payload.new()
		trig.near = 1
		trig.spread = Payload.new()
		trig.spread.damage = 3.0
		p.on_hit = trig
		p.on_kill = trig
		Attacks.spawn(p, {"attacker": raid.player, "room": raid.room, "team": 0,
			"aim": Vector2.RIGHT, "origin": raid.player.global_position})
		await frames(6)
	say("all attack forms ok")


	# Editor mid-raid, then a component placement from the bag.
	GameState.add_component("HOMING", 3, GameState.raid_bag)
	raid.set_editing(true)
	await frames(4)
	var red: SkillEditor = Views.of(raid).editor
	red.selected = "HOMING"
	red._hover_cell = Vector2i(1, 1)
	red._click_left()
	red._update_hover(Vector2(300, 200))
	if not GameState.raid_board.comp_at(Vector2i(1, 1)).has("id"):
		fail("mid-raid placement did not land on the board")
	await frames(6)
	raid.set_editing(false)
	await frames(3)
	say("raid editor ok, bag=%s" % str(GameState.raid_bag))

	# Walk every way out of the entry room — its doorways — and back.
	var visited := 0
	for dir in raid.map.doors_for(raid.room.coord).keys():
		var before: Vector2i = raid.room.coord
		raid.go_through(int(dir))
		await frames(8)
		if raid.room.coord != before:
			visited += 1
	say("door travel ok, moved %d times, now at %s" % [visited, str(raid.room.coord)])

	# Sweep to a few more rooms so more generation paths run.
	for c in raid.map.rooms.keys():
		raid.go_to(c)
		await frames(3)
	say("visited all %d rooms" % raid.map.rooms.size())

	# Kill everything in the current room to exercise drops.
	raid.go_to(raid.map.entry)
	await frames(3)
	for c in raid.room.get_children():
		if c is Enemy:
			c.apply_damage(999999.0, [], null)
	await frames(10)
	say("kills ok")

	# Loot must land in the raid bag, not the safe stash. Find a room with loot.
	for c in raid.map.rooms.keys():
		if String(raid.map.rooms[c].get("kind", "")) == "treasure":
			raid.go_to(c)
			break
	await frames(4)
	var stash_before := GameState.stash.duplicate()
	var loot_here := 0
	for c in raid.room.get_children():
		if c is Pickup:
			fail("a room's loot was left on the floor instead of in its box")
	var box: TreasureBox = raid.room.box
	if box != null:
		loot_here = TreasureBox.takeable(box.contents).size()
		var bag_before := 0
		for k in GameState.raid_bag:
			bag_before += int(GameState.raid_bag[k])
		var scrap_before := GameState.raid_scrap
		for i in 30:
			raid.player.global_position = box.global_position
			await get_tree().process_frame
			if box.offered():
				break
		Input.action_press("interact")
		await frames(2)
		Input.action_release("interact")
		var bag_after := 0
		for k in GameState.raid_bag:
			bag_after += int(GameState.raid_bag[k])
		if not box.is_open or (bag_after == bag_before and GameState.raid_scrap == scrap_before):
			fail("the treasure box could not be opened")
	say("loot in box %d -> bag=%s scrap=%d  stash untouched=%s" % [loot_here, str(GameState.raid_bag), GameState.raid_scrap, str(GameState.stash == stash_before)])
	if GameState.stash != stash_before:
		fail("raid loot leaked into the stash")

	# Extraction at the entry gate.
	raid.go_to(raid.map.entry)
	await frames(4)
	for c in raid.room.get_children():
		if c is Enemy:
			c.queue_free()
	Input.action_press("interact")
	for i in 700:
		raid.player.global_position = raid.room.to_global(raid.room.extraction_rect().get_center())
		await get_tree().process_frame
		if game.state != 2:
			break
	Input.action_release("interact")
	say("state after extraction=%d (4 = results)" % game.state)
	if game.state != 4:
		fail("holding interact at a free exit did not extract")

	await frames(5)
	if game.current is ResultsScreen:
		(game.current as ResultsScreen).continued.emit()
	await frames(6)
	say("results ok, stash=%s scrap=%d" % [str(GameState.stash), GameState.scrap])
	if not GameState.weapon_board("SWORD").comp_at(Vector2i(1, 1)).has("id"):
		fail("a board edited mid-raid did not come home")
	else:
		say("mid-raid edit survived extraction")

	# Sandbox.
	game.goto_sandbox()
	await frames(10)
	var sb: Sandbox = game.current
	sb.spawn_monster("CRAWLER")
	sb.spawn_monster("ARBITER")
	sb.cycle_weapon()
	sb.set_editing(true)
	await frames(20)
	sb.set_editing(false)
	Input.action_press("cast_skill")
	await frames(60)
	Input.action_release("cast_skill")
	say("sandbox ok, dps=%.1f weapon=%s" % [sb.dps(), sb.current_weapon()])

	# Damage has to actually land: stand on a dummy and hold the trigger.
	var dummy: Enemy = null
	for c in sb.get_children():
		if c is Enemy and c.kind == "DUMMY":
			dummy = c
	sb.weapon_index = 0
	sb._apply_weapon()
	sb.player.global_position = dummy.global_position + Vector2(-30, 0)
	sb.player.aim = Vector2.RIGHT
	Input.action_press("cast_skill")
	for i in 120:
		sb.player.global_position = dummy.global_position + Vector2(-30, 0)
		sb.player.aim = Vector2.RIGHT
		await get_tree().process_frame
	Input.action_release("cast_skill")
	var hp_lost := dummy.max_health - dummy.health
	say("melee damage landed: %.1f (dps %.1f)" % [hp_lost, sb.dps()])
	if hp_lost <= 0.0:
		fail("no damage was dealt")

	# Death path: the weapon and the graph on it go down together.
	game._deploy("GUN")
	await frames(6)
	var raid2: Raid = game.current
	raid2.player.apply_damage(99999.0, [], null)
	await frames(10)
	say("death path ok, state=%d weapons=%s" % [game.state, str(GameState.owned_weapons)])
	if GameState.owned_weapons.has("GUN") or GameState.weapon_boards.has("GUN"):
		fail("the weapon carried into a lost raid survived, or its graph did")
	else:
		say("death took the gun and its graph with it")
	game.goto_title()
	await frames(5)
