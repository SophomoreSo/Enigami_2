extends Node
## The assembly board and the console on the glass: what a press on the board
## lands on, and what is drawn over what.
##
## The hideout's workbench used to sit on the pause menu's own layer, over the
## console. It covered the console without stopping it answering — the console
## reads fingers in `_input`, ahead of every Control — so a click on the
## workbench's CLOSE pressed the MENU key hidden under it, and the pause menu
## opened underneath a workbench that was still on the screen. The raid's board
## sat under the console instead, and had the same keys standing on its CLOSE
## and CODE where they could at least be seen.
##
## A desk first, where the mouse is the finger, since that is where it was
## found; a gamepad, whose START is the pause action and which no board closes
## on; then a thumb, which the system hands over as a click as well as a touch;
## then the raid's board, and the map, which is the other page of the same
## screen and leaves the glass as clear.

const GameScript := preload("res://app/game.gd")

var fails := 0
var game: Node
var pad: TouchPad
var hideout: HideoutWorld

func check(ok: bool, what: String) -> void:
	if ok:
		print("[WORKBENCH] PASS ", what)
	else:
		fails += 1
		push_error("WORKBENCH FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## A point in the 1280x720 the game is drawn at, where it lands on the window.
## Every press here goes through `Input` the way the system sends one, so it
## meets the console's `_input` before it meets any Control.
func on_glass(at: Vector2) -> Vector2:
	return get_window().get_final_transform() * at

func press(at: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = on_glass(at)
	e.global_position = e.position
	Input.parse_input_event(e)

func point(at: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = on_glass(at)
	m.global_position = m.position
	Input.parse_input_event(m)
	await frames(2)

func click(at: Vector2) -> void:
	await point(at)
	press(at, true)
	await frames(2)
	press(at, false)
	await frames(3)

func tap(at: Vector2) -> void:
	for down in [true, false]:
		var e := InputEventScreenTouch.new()
		e.index = 0
		e.position = on_glass(at)
		e.pressed = down
		Input.parse_input_event(e)
		await frames(2)
	await frames(3)

func key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		Input.parse_input_event(e)
		await frames(2)
	await frames(2)

func workbench_up() -> bool:
	return game.editor != null and is_instance_valid(game.editor)

func paused() -> bool:
	return get_tree().paused or game.pause_menu.visible

## Whatever a failing check left behind, so the next one starts from a room
## and not from a menu or a board the last one could not close.
func tidy() -> void:
	if get_tree().paused:
		game._unpause()
	if workbench_up():
		game._close_editor()
	await frames(3)

func shown() -> Array:
	var out: Array = []
	for c in TouchPad.CONTROLS:
		if pad.shown(c):
			out.append(String(c.get("action", "move")))
	return out

func layer_of(c: CanvasItem) -> int:
	return c.get_canvas_layer_node().layer

func _ready() -> void:
	var was_mode := Touch.mode
	var was_size := DisplayServer.window_get_size()
	# Not 1:1. A press sent at a design position proves nothing on the one
	# window where a design position and a window position are the same number.
	DisplayServer.window_set_size(Vector2i(1440, 810))
	Touch.set_mode(Touch.ON)
	# The plates where the design puts them, whatever this machine's player has
	# moved them to — in force here only, and nothing kept.
	TouchPad.set_layout({}, false)
	GameState.reset_profile()
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(6)
	pad = game.touch_pad
	game.goto_hideout()
	await frames(12)
	hideout = game.current as HideoutWorld
	await _on_a_desk()
	await _from_the_floor()
	await _from_a_gamepad()
	await _with_a_thumb()
	await _the_raids_board()
	Touch.set_mode(was_mode)
	DisplayServer.window_set_size(was_size)
	print("[WORKBENCH] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## --- a desk, the mouse for a finger -----------------------------------------

func _on_a_desk() -> void:
	game._edit_weapon_graph()
	await frames(4)
	check(workbench_up(), "the weapon's graph raises the workbench over the room")
	if not workbench_up():
		return
	check(pad.face == TouchPad.Face.CLEAR, "and the workbench leaves the console CLEAR")
	check(shown().is_empty(), "with nothing on it (%s)" % str(shown()))
	check(pad.visible and Controls.mouse_aside(),
		"but still up, so the board goes on naming the keys on the glass")
	check(layer_of(game.editor) < layer_of(pad) and layer_of(pad) < layer_of(game.pause_menu),
		"the workbench is under the console and the console under the pause menu (%d, %d, %d)"
			% [layer_of(game.editor), layer_of(pad), layer_of(game.pause_menu)])

	await click(game.editor._close_rect().get_center())
	check(not paused(), "a click on the workbench's back arrow does not open the pause menu")
	check(not workbench_up(), "it closes the workbench")
	check(pad.face == TouchPad.Face.PLAY, "and the floor is back with its keys")
	await tidy()

	# COPY stands under the board, over nothing on the console, and a click on
	# it copies and does nothing else. The clipboard is put back as it was.
	game._edit_weapon_graph()
	await frames(4)
	var clipboard := DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD)
	var was := DisplayServer.clipboard_get() if clipboard else ""
	await click(game.editor._copy_rect().get_center())
	check(workbench_up() and not paused(),
		"a click on the workbench's COPY leaves it up and presses nothing under it")
	if clipboard:
		DisplayServer.clipboard_set(was)
	await tidy()

## --- opened by key, from the floor ------------------------------------------

## Nothing holds the player still here, so under the workbench the console was
## not even on its screen face: all of it answered, and a press on the grid
## grew the movement stick instead of reaching the board.
func _from_the_floor() -> void:
	hideout.set_weapon(hideout.weapon_id)
	await frames(4)
	check(pad.face == TouchPad.Face.PLAY, "on the floor the console is all there")
	await click(TouchPad.area(control_of("open_editor")).get_center())
	check(workbench_up(), "and its KIT opens the workbench over the weapon's graph")
	if not workbench_up():
		return
	check(pad.face == TouchPad.Face.CLEAR, "which leaves it CLEAR (face %d)" % pad.face)
	var ed: SkillEditor = game.editor
	var reached: Array = []
	ed.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			reached.append(e))
	# Wherever mobile mode's layout has stood the board: an empty cell of it.
	var cell := ed._cell_center(Vector2i(2, 0))
	await point(cell)
	press(cell, true)
	await frames(2)
	# Dragged a little, since the stick only comes out for a thumb that moves.
	await point(cell + Vector2(20, 0))
	check(not pad.stick_showing(), "a press dragged on the grid grows no stick under it")
	press(cell + Vector2(20, 0), false)
	await frames(3)
	check(reached.size() == 1, "it reaches the board instead (%d)" % reached.size())
	await tidy()

## --- a gamepad's START -------------------------------------------------------

## START is the pause action, and the board closes on the ESC key and not on
## that, so the press goes by it to the shell. The menu has to come up over the
## workbench, and the workbench has to stop under it: ESC is the menu's then,
## and a workbench still answering keys closed itself behind the menu.
func _from_a_gamepad() -> void:
	game._edit_weapon_graph()
	await frames(4)
	var start := InputEventJoypadButton.new()
	start.button_index = JOY_BUTTON_START
	start.pressed = true
	Input.parse_input_event(start)
	await frames(2)
	start = start.duplicate()
	start.pressed = false
	Input.parse_input_event(start)
	await frames(3)
	check(paused(), "START over the workbench pauses the hideout")
	check(workbench_up(), "with the workbench still there")
	await key(KEY_ESCAPE)
	check(not paused(), "ESC puts the menu away")
	check(workbench_up(), "and does not close the workbench behind it")
	await tidy()

## --- a thumb -----------------------------------------------------------------

## The system hands a touch over as a click first and then as itself, so a thumb
## on CLOSE used to do both: the click closed the board and the touch pressed
## MENU. This is also the first finger this pad has seen, which it takes as the
## mouse first — see `TouchPad._saw_a_finger`.
func _with_a_thumb() -> void:
	game._edit_weapon_graph()
	await frames(4)
	await tap(game.editor._close_rect().get_center())
	check(not workbench_up(), "a thumb on the workbench's back arrow closes it")
	check(not paused(), "and presses nothing else on the way")
	await tidy()

	# The hideout has no map, and the MAP tab is on the workbench's top all the
	# same: a thumb on it puts the map's page up, which says so, the glass as
	# clear as under the board; and the MAP key on the floor puts the screen up
	# on that page.
	game._edit_weapon_graph()
	await frames(4)
	await tap(tab_of(game.editor.pages, ScreenTabs.MAP))
	check(workbench_up() and game.editor_pages.map.visible and not game.editor.visible
			and game.editor_pages.map.map == null,
		"a thumb on the workbench's MAP tab puts the map's page up, with no map on it")
	check(pad.face == TouchPad.Face.CLEAR, "and the glass is clear under it")
	await tap(ScreenTabs.back_rect(true).get_center())
	check(not workbench_up() and not paused(), "a thumb on its back arrow puts the screen away, and presses nothing else")
	await tidy()
	await tap(TouchPad.area(control_of("open_map")).get_center())
	check(workbench_up() and game.editor_pages.map.visible, "the MAP key on the floor puts it up on the map's page")
	await tidy()

## --- the raid's board, and the map ------------------------------------------

func _the_raids_board() -> void:
	game._deploy("SWORD")
	await frames(16)
	var raid := game.current as Raid
	raid.set_editing(true)
	await frames(3)
	check(pad.face == TouchPad.Face.CLEAR, "the raid's board leaves the console CLEAR too")
	await tap(Views.of(raid).editor._close_rect().get_center())
	check(not raid.editing, "a thumb on its back arrow closes it")
	check(not paused(), "rather than pressing the MENU key that stood on it")
	await tidy()

	# The map is the board's screen with its other tab up, and the same top: the
	# back arrow that puts it away, and the tabs that go between the two. So the
	# glass is as clear under it as under the board.
	raid.set_reading_map(true)
	await frames(3)
	check(pad.face == TouchPad.Face.CLEAR, "the map leaves the console CLEAR as the board does (%s)"
		% str(shown()))
	await tap(tab_of(Views.of(raid).map_panel.pages, ScreenTabs.GRAPH))
	check(raid.editing and not raid.reading_map, "a thumb on the GRAPH tab puts the board up in the map's place")
	await tap(tab_of(Views.of(raid).editor.pages, ScreenTabs.MAP))
	check(raid.reading_map and not raid.editing, "and one on MAP the map in the board's")
	await tap(ScreenTabs.back_rect(true).get_center())
	check(not raid.reading_map and not raid.editing, "a thumb on the map's back arrow puts it away")
	check(not paused(), "and presses nothing else on the way")
	await tidy()

## The middle of `id`'s tab along the top of a thumb's screen with `pages` on it.
func tab_of(pages: Array, id: String) -> Vector2:
	return (ScreenTabs.tab_rects(pages, true)[pages.find(id)] as Rect2).get_center()

func control_of(action: String) -> Dictionary:
	for c in TouchPad.CONTROLS:
		if String(c.get("action", "")) == action:
			return c
	return {}
