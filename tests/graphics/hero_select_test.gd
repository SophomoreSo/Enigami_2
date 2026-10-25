extends Node
## Sitting down on a bench brings up who to play as (`HeroSelect`): the heroes
## of the roster in a row with the cursor on the one played as, the player held
## sat and still under it; left and right move the cursor, round the row;
## interact takes the hero the cursor is on, which the profile keeps and a
## slot read back off disk still has; ESC puts the screen away with nothing
## changed; and standing up puts it away too. On the sandbox's bench, and in
## the hideout.

const GameScript := preload("res://app/game.gd")
const SLOT := 3

var game: Node
var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[HEROES] PASS ", what)
	else:
		fails += 1
		push_error("HEROES FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## Until `cond` holds, or `seconds` have gone by on the wall.
func until(cond: Callable, seconds: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > int(seconds * 1000.0):
			return false
		await get_tree().physics_frame
	return true

func key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	get_viewport().push_input(e)
	await get_tree().process_frame
	var up := InputEventKey.new()
	up.keycode = code
	up.physical_keycode = code
	up.pressed = false
	get_viewport().push_input(up)
	await frames(3)

## Walks the player to the bench `b` and sits them down on it with interact.
func sit_on(p: Player, b: Bench) -> bool:
	p.global_position = b.global_position + Vector2(-Bench.RANGE + 6.0, 0.0)
	p.velocity = Vector2.ZERO
	await frames(2)
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	return await until(func() -> bool: return p.seated(), 4.0)

## The middle of a cell on the sandbox's floor — open, and no pit — as far
## across the room as it allows from everyone standing in it, the people to
## talk to and the dummy.
func _clear_floor(sb: Sandbox) -> Vector2:
	var others: Array = get_tree().get_nodes_in_group("npcs") + get_tree().get_nodes_in_group("enemies")
	var best := Vector2.ZERO
	var widest := -1.0
	for x in range(2, sb.room.cols - 2):
		for y in range(2, sb.room.rows - 2):
			if sb.room.is_solid(x, y) or sb.room.is_pit(x, y):
				continue
			var at := sb.room.cell_center(x, y)
			var nearest := INF
			for o: Node2D in others:
				nearest = minf(nearest, at.distance_to(o.global_position))
			if nearest > widest:
				widest = nearest
				best = at
	return best

func screen() -> HeroSelect:
	return game.heroes

func _ready() -> void:
	GameState.slot = SLOT
	GameState.reset_profile()
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(6)
	var roster := Heroes.ids()
	check(roster.size() == 4 and GameState.hero == roster[0],
		"the roster has four heroes, and a new profile plays as the first (%s)" % GameState.hero)
	var wrong: Array = []
	for id in roster:
		if not Sprites.has_character(id) and (Style.hero_play_art(id) != Style.PLAYER_ART
				or not Sprites.has_character(Style.hero_portrait_art(id))):
			wrong.append(id)
	check(wrong.is_empty(), "a hero with no sprites of their own is played as the player's art, with an atlas face standing in (%s)" % str(wrong))

	# --- the sandbox's bench ---------------------------------------------------
	game.goto_sandbox()
	await frames(12)
	var sb: Sandbox = game.current
	# The sandbox's room has no bench of its own, so one is put down on its
	# floor, as a laid map's would be: as far as it can be from anyone standing
	# there to talk to, and from the dummy. Interact answers whatever it is in
	# reach of, and beside the one who talks it is the walk over to talk.
	var bench: Bench = sb.room.add_bench(_clear_floor(sb))
	# The sandbox does not tell its room who plays it, as the hideout and a raid
	# do, so the bench is told.
	bench.player = sb.player
	check(sb.room.benches.has(bench), "a bench put down in the sandbox's room")
	check(await sit_on(sb.player, bench), "interact beside it sits the player down")
	await frames(3)
	check(game._choosing() and screen().visible and screen().ids == roster,
		"and sat, who to play as comes up: the heroes in a row (%d)" % screen().ids.size())
	check(screen().cursor == 0 and sb.player.input_locked and sb.tools_open,
		"the cursor on the one played as, the player held sat and still")
	var first := screen().card_rect(0)
	var last := screen().card_rect(roster.size() - 1)
	check(first.position.x > 0.0 and last.end.x < screen().size.x and first.position.y == last.position.y,
		"the cards in one row on the screen (%s to %s)" % [str(first), str(last)])
	await key(KEY_D)
	check(screen().cursor == 1, "right moves the cursor along (%d)" % screen().cursor)
	await key(KEY_A)
	await key(KEY_A)
	check(screen().cursor == roster.size() - 1, "left moves it back, and round the row (%d)" % screen().cursor)
	await key(KEY_D)
	check(screen().cursor == 0, "and round again")
	await key(KEY_D)
	await key(KEY_F)
	check(GameState.hero == roster[1] and not game._choosing(), "interact takes the hero the cursor is on, and the screen goes (%s)" % GameState.hero)
	check(sb.player.seated() and not sb.player.input_locked and not sb.tools_open,
		"the player still sat, and free to stand")
	# Kept with the profile, through disk.
	var was := GameState.hero
	GameState.hero = ""
	check(GameState.load_slot(SLOT) and GameState.hero == was, "the slot read back off disk plays as them")
	# Up off the bench, and sat again: the cursor is on them, and ESC changes nothing.
	# A dash the way the hands read one: an action, which `key` is not.
	await until(func() -> bool: return sb.player.can_dash(), 3.0)
	Input.action_press("dash")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("dash")
	await until(func() -> bool: return not sb.player.seated(), 2.0)
	check(not sb.player.seated() and not game._choosing(), "a dash stands the player up, and nothing comes up")
	await until(func() -> bool: return not sb.player.is_dashing(), 2.0)
	check(await sit_on(sb.player, bench), "sat down again")
	await frames(3)
	check(game._choosing() and screen().cursor == 1, "the screen is back, the cursor on the one played as")
	await key(KEY_D)
	await key(KEY_ESCAPE)
	check(not game._choosing() and GameState.hero == was and not game.get_tree().paused,
		"ESC puts it away with nothing changed, pausing nothing")
	check(sb.player.seated(), "and the player still sat")
	# Standing up while it is up puts it away. It came up as the player sat, so
	# to have it back they stand and sit again: interact at the bench they are
	# sat on would only stand them up.
	sb.player.stand_up()
	await frames(3)
	check(await sit_on(sb.player, bench) and game._choosing(), "sat again, it is back up")
	sb.player.stand_up()
	await frames(3)
	check(not game._choosing() and not sb.tools_open, "standing up puts the screen away")

	# --- the hideout ------------------------------------------------------------
	game.goto_hideout()
	await frames(10)
	var h: HideoutWorld = game.hideout_ref
	check(not h.room.benches.is_empty(), "the hideout has its bench")
	check(await sit_on(h.player, h.room.benches[0]), "sat down on it")
	await frames(3)
	check(game._choosing() and h.editing and not Views.of(h).hud.visible,
		"the screen comes up over the hideout, the player held and the HUD away")
	await key(KEY_ESCAPE)
	check(not game._choosing() and not h.editing, "and ESC puts it away, the hold let go")

	GameState.hero = roster[0]
	GameState.save_game()
	print("[HEROES] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
