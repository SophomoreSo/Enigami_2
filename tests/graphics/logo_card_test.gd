extends Node
## The logo the game opens on (`LogoCard`): picked at random from the pool,
## every logo in it white to its edges once it is drawn, held over the title it
## goes into and gone by itself — or at once on a press, which never reaches the
## title under it.
##
## And the white in front of it, which is not the card's: the boot, in the
## project settings, and the iOS launch screen, in the export preset. From the
## moment the game is opened to the logo is one sheet of white, with no Godot on
## it.
##
## Last, the game as launched: the main scene opens on the card over its title.
## A game built inside a test, as this one and every other test builds it, does
## not — it goes straight to work.

const GameScript := preload("res://app/game.gd")

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[LOGO] PASS ", what)
	else:
		fails += 1
		push_error("LOGO FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func seconds(t: float) -> void:
	await get_tree().create_timer(t).timeout

## The card's logo and paper, once `cond` holds: on the first frame it does — or
## [-1, -1] if the card went first, or it never came to. Waited for rather than
## timed: the whole card is gone in about a second, and on a slow machine a
## frame is a good part of one of its steps.
func once(card: LogoCard, cond: Callable) -> Array:
	var left := LogoCard.HOLD + LogoCard.LOGO_OUT + LogoCard.FADE + 1.0
	while left > 0.0 and is_instance_valid(card) and not cond.call():
		await get_tree().process_frame
		left -= get_process_delta_time()
	return [card.logo_alpha(), card.paper_alpha()] if is_instance_valid(card) else [-1.0, -1.0]

func on_glass(at: Vector2) -> Vector2:
	return get_window().get_final_transform() * at

func key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		Input.parse_input_event(e)
		await frames(2)
	await frames(2)

func click(at: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = on_glass(at)
	m.global_position = m.position
	Input.parse_input_event(m)
	await frames(2)
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = on_glass(at)
		e.global_position = e.position
		Input.parse_input_event(e)
		await frames(2)
	await frames(2)

## Whether `c` is the white of the card.
func white(c: Color) -> bool:
	return c.r >= 254.5 / 255.0 and c.g >= 254.5 / 255.0 and c.b >= 254.5 / 255.0

## A picture read from its file, or null.
func picture(path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	return img if img != null and not img.is_empty() else null

func _ready() -> void:
	var was_size := DisplayServer.window_get_size()
	# Not 1:1, where a design position and a window position are the same
	# number and a click sent to the wrong one lands anyway.
	DisplayServer.window_set_size(Vector2i(1440, 810))
	GameState.reset_profile()
	_the_pool()
	_the_white()
	await _the_card()
	await _built_inside_a_test()
	# The main scene takes the place of this one, and this one goes with it: what
	# is left to ask is asked by a node standing at the root on its own.
	var launched := Launched.new()
	launched.fails = fails
	launched.was_size = was_size
	get_tree().root.add_child(launched)

## --- the pool -----------------------------------------------------------------

## Every logo in it, drawn as the card draws it (LIFT), comes out white along
## every edge — or clear, which the card's white shows through — so none of
## them stands in a box of its own.
func _the_pool() -> void:
	var pool := LogoCard.pool()
	check(pool.size() >= 2, "the pool holds the studio's logos (%s)" % str(pool))
	var boxed: Array = []
	for path in pool:
		check(load(path) is Texture2D, "%s is a picture the game can draw" % path.get_file())
		var img := picture(path)
		if img == null:
			boxed.append(path.get_file() + " unreadable")
			continue
		var w := img.get_width()
		var h := img.get_height()
		var off := 0
		for y in h:
			for x in w:
				if x >= 4 and y >= 4 and x < w - 4 and y < h - 4:
					continue
				var c := img.get_pixel(x, y)
				var drawn := Color(c.r * LogoCard.LIFT, c.g * LogoCard.LIFT, c.b * LogoCard.LIFT)
				if c.a > 0.05 and not white(drawn):
					off += 1
		if off > 0:
			boxed.append("%s: %d edge pixels" % [path.get_file(), off])
	check(boxed.is_empty(), "and every logo is white to its edges as the card draws it (%s)" % str(boxed))

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var seen := {}
	for i in 60:
		seen[LogoCard.pick(rng)] = true
	check(seen.keys().all(func(p: String) -> bool: return pool.has(p)), "a pick is always one of the pool")
	check(seen.size() == pool.size(),
		"and over sixty starts every one of them comes up (%d of %d)" % [seen.size(), pool.size()])

## --- the white ------------------------------------------------------------------

## What the engine boots onto and what iOS shows before the game runs: the
## card's white, with nothing on it — not a logo, which a launch screen could not
## change, and not Godot's.
func _the_white() -> void:
	check(LogoCard.PAPER == Color.WHITE, "the card is white")
	check(white(ProjectSettings.get_setting("application/boot_splash/bg_color")),
		"the game boots onto white (%s)" % str(ProjectSettings.get_setting("application/boot_splash/bg_color")))
	check(not bool(ProjectSettings.get_setting("application/boot_splash/show_image")),
		"with Godot's own picture off")
	var presets := ConfigFile.new()
	check(presets.load("res://export_presets.cfg") == OK, "the export presets read")
	var ios := ""
	for s in presets.get_sections():
		if not s.ends_with(".options") and String(presets.get_value(s, "platform", "")) == "iOS":
			ios = s + ".options"
	check(ios != "", "there is an iOS preset")
	if ios == "":
		return
	var two := String(presets.get_value(ios, "storyboard/custom_image@2x", ""))
	var three := String(presets.get_value(ios, "storyboard/custom_image@3x", ""))
	check(two != "" and two == three,
		"its launch screen is a picture of the game's own, the same at both sizes (%s)" % two)
	var img := picture(two) if two != "" else null
	var all_white := img != null
	if img != null:
		for y in img.get_height():
			for x in img.get_width():
				all_white = all_white and white(img.get_pixel(x, y))
	check(all_white, "and that picture is white and nothing else")
	check(bool(presets.get_value(ios, "storyboard/use_custom_bg_color", false))
			and white(presets.get_value(ios, "storyboard/custom_bg_color", Color.BLACK)),
		"laid on white, edge to edge")

## --- the card -------------------------------------------------------------------

func _the_card() -> void:
	# A button under it, the way the title's START is under it at boot: focused,
	# and on a lower layer.
	var under := CanvasLayer.new()
	under.layer = 5
	add_child(under)
	var b := Button.new()
	b.text = "START"
	b.position = Vector2(560, 340)
	b.size = Vector2(160, 40)
	under.add_child(b)
	b.grab_focus()
	var presses := [0]
	b.pressed.connect(func() -> void: presses[0] += 1)
	var over := CanvasLayer.new()
	over.layer = 20
	add_child(over)

	var card := LogoCard.new()
	over.add_child(card)
	await frames(2)
	check(card.logo != null and LogoCard.pool().has(card.logo.resource_path),
		"the card comes up with a logo from the pool (%s)" % (card.logo.resource_path if card.logo else "none"))
	check(card.size == get_viewport().get_visible_rect().size and card.holding(),
		"over the whole screen, holding it")
	await key(KEY_ENTER)
	await click(b.get_global_rect().get_center())
	check(presses[0] == 0, "nothing pressed while it is up reaches what is under it")
	check(is_instance_valid(card) and not card.holding(), "and a press goes straight to the fade")
	await seconds(LogoCard.LOGO_OUT + LogoCard.FADE + 0.2)
	check(not is_instance_valid(card), "which ends with the card gone")
	await key(KEY_ENTER)
	await click(b.get_global_rect().get_center())
	check(presses[0] == 2, "after which what is under it answers a key and a click again (%d)" % presses[0])

	# Left alone it holds; then the logo goes into its white, which stays whole,
	# and only then the white into what is under it — one layer at a time.
	var again := LogoCard.new()
	over.add_child(again)
	await seconds(LogoCard.HOLD * 0.5)
	check(is_instance_valid(again) and again.holding() and again.logo_alpha() == 1.0
			and again.paper_alpha() == 1.0, "left alone it holds the logo")
	var going: Array = await once(again, func() -> bool: return again.logo_alpha() < 1.0)
	check(going[0] > 0.0 and going[0] < 1.0 and going[1] == 1.0,
		"then the logo goes into the white, which stays whole (%.2f, %.2f)" % going)
	going = await once(again, func() -> bool: return again.paper_alpha() < 1.0)
	check(going[0] == 0.0 and going[1] > 0.0 and going[1] < 1.0,
		"and then the white goes into what is under it, by itself (%.2f, %.2f)" % going)
	await seconds(LogoCard.FADE + 0.3)
	check(not is_instance_valid(again), "and the card is gone")
	under.queue_free()
	over.queue_free()
	await frames(2)

## --- a game built inside a test --------------------------------------------------

func _built_inside_a_test() -> void:
	var game := Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(4)
	check(not LogoCard.wanted(game) and _cards(game) == 0 and game.state == game.State.TITLE,
		"a game built inside a test opens straight on its title, with no card")
	game.queue_free()
	await frames(2)

static func _cards(root: Node) -> int:
	var n := 0
	var stack: Array = [root]
	while not stack.is_empty():
		var at: Node = stack.pop_back()
		if at is LogoCard:
			n += 1
		stack.append_array(at.get_children())
	return n

## --- the game as launched ---------------------------------------------------------

## Asked from the root, once the main scene has taken the test's place.
class Launched extends Node:
	var fails := 0
	var was_size := Vector2i.ZERO

	func check(ok: bool, what: String) -> void:
		if ok:
			print("[LOGO] PASS ", what)
		else:
			fails += 1
			push_error("LOGO FAIL: " + what)

	func _ready() -> void:
		get_tree().change_scene_to_file("res://app/main.tscn")
		var game: Node = null
		for i in 120:
			await get_tree().process_frame
			var now := get_tree().current_scene
			if now != null and now.get("overlay_layer") != null:
				game = now
				break
		check(game != null, "the main scene comes up")
		if game != null:
			var cards: Array = (game.overlay_layer as Node).get_children().filter(
				func(n: Node) -> bool: return n is LogoCard)
			var card: LogoCard = cards[0] if cards.size() == 1 else null
			check(LogoCard.wanted(game) and card != null and card.logo != null
					and LogoCard.pool().has(card.logo.resource_path),
				"the game as launched opens on a logo from the pool (%s)"
					% (card.logo.resource_path.get_file() if card != null and card.logo != null else "none"))
			check(game.state == game.State.TITLE and game.current is TitleScreen,
				"over its title, built under it")
			await get_tree().create_timer(LogoCard.HOLD + LogoCard.LOGO_OUT + LogoCard.FADE + 0.3).timeout
			check(not is_instance_valid(card) and game.current is TitleScreen,
				"which it goes into by itself, leaving the title")
		DisplayServer.window_set_size(was_size)
		print("[LOGO] ---- %d failures ----" % fails)
		get_tree().quit(1 if fails > 0 else 0)
