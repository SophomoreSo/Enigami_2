extends Node
## Where mobile mode's buttons stand, as the player puts them: SET BUTTON
## POSITIONS on the control settings, and the screen behind it.
##
## Checked the way a player does it. The row is on the controls page only in
## mobile mode. A button is taken by a thumb and dragged: let go where it fits
## it stays, let go on another button or over the HUD it goes back. SAVE keeps
## it, and in a raid a thumb on the new place presses it and a thumb on the old
## one presses nothing — on a screen of another shape too, where the moved
## button keeps its distance from the corner it was put nearest and the rest
## keep theirs from the right. RESET, from the pause menu this time, puts the
## design back, and the way out keeps nothing.
##
## On a window that is not 1:1, so every press has to be carried from the glass
## to the screen and a wrong carry cannot land by luck. The machine's own
## arrangement is put back at the end: that file is the player's.

const GameScript := preload("res://app/game.gd")

var fails := 0
var game: Node
var _had_file := false
var _file_text := ""

func check(ok: bool, what: String) -> void:
	if ok:
		print("[LAYOUT] PASS ", what)
	else:
		fails += 1
		push_error("LAYOUT FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func screen() -> Vector2:
	return get_viewport().get_visible_rect().size

func on_glass(at: Vector2) -> Vector2:
	return get_window().get_final_transform() * at

## A finger landing or lifting, and moving, sent the way the system sends them.
func touch(index: int, at: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = on_glass(at)
	e.pressed = pressed
	Input.parse_input_event(e)

func drag(index: int, at: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = on_glass(at)
	Input.parse_input_event(e)

## A thumb that takes whatever is at `from` and carries it to `to` in a few
## steps, the way a thumb moves, before lifting there.
func carry(from: Vector2, to: Vector2) -> void:
	touch(0, from, true)
	await frames(2)
	for k in range(1, 7):
		drag(0, from.lerp(to, float(k) / 6.0))
		await frames(1)
	await frames(2)

func lift(at: Vector2) -> void:
	touch(0, at, false)
	await frames(3)

## A click, pressed and let go, for the buttons that are Controls.
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
		e.position = m.position
		e.global_position = e.position
		Input.parse_input_event(e)
		await frames(2)

func find_under(root: Node, want: Callable) -> Node:
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if want.call(n):
			return n
		for c in n.get_children(true):
			stack.append(c)
	return null

func editor() -> TouchLayoutEditor:
	return find_under(get_tree().root, func(n: Node) -> bool: return n is TouchLayoutEditor) \
		as TouchLayoutEditor

func control_of(key: String) -> Dictionary:
	for c in TouchPad.CONTROLS:
		if TouchPad.key_of(c) == key:
			return c
	return {}

func index_of(key: String) -> int:
	return TouchPad.CONTROLS.find(control_of(key))

## Where a button stands now, in the arrangement `l`.
func middle_of(key: String, l: Dictionary) -> Vector2:
	return TouchPad.middle(TouchPad.placed(control_of(key), l), screen())

func _ready() -> void:
	var was_mode := Touch.mode
	var was_size := DisplayServer.window_get_size()
	_had_file = FileAccess.file_exists(TouchPad.LAYOUT_PATH)
	if _had_file:
		_file_text = FileAccess.get_file_as_string(TouchPad.LAYOUT_PATH)
	TouchPad.set_layout({}, false)
	DisplayServer.window_set_size(Vector2i(1440, 810))
	Touch.set_mode(Touch.OFF)
	GameState.reset_profile()
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(10)
	var panel := await _the_row()
	if panel != null:
		await _arranging(panel)
		await _in_a_raid()
		await _another_shape()
		await _reset_from_the_pause_menu()
		await _the_way_out()
	# The machine's own arrangement, and its own mode, back as they were.
	if _had_file:
		var f := FileAccess.open(TouchPad.LAYOUT_PATH, FileAccess.WRITE)
		f.store_string(_file_text)
		f.close()
	elif FileAccess.file_exists(TouchPad.LAYOUT_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TouchPad.LAYOUT_PATH))
	Touch.set_mode(was_mode)
	DisplayServer.window_set_size(was_size)
	print("[LAYOUT] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## --- the row ------------------------------------------------------------------

func _the_row() -> ControlsPanel:
	var title := game.current as TitleScreen
	title._toggle_settings()
	await frames(3)
	title._toggle_controls()
	await frames(6)
	var panel := find_under(title._controls, func(n: Node) -> bool: return n is ControlsPanel) \
		as ControlsPanel
	check(panel != null, "the controls page is up")
	if panel == null:
		return null
	check(not panel._arrange.is_visible_in_tree(),
		"with mobile mode off there is no SET BUTTON POSITIONS: nothing on the glass to move")
	await click(panel._mobile.get_global_rect().get_center())
	await frames(3)
	check(Touch.wanted(), "throwing mobile mode on")
	# The page is built again for a thumb, and its panel with it.
	panel = find_under(title._controls, func(n: Node) -> bool: return n is ControlsPanel) \
		as ControlsPanel
	check(panel != null and panel.thumb(), "lays the page out again for a thumb")
	if panel == null:
		return null
	check(panel._arrange.is_visible_in_tree(), "brings SET BUTTON POSITIONS up under the switch")
	check(panel._arrange.text == Loc.t("controls.arrange.open"),
		"which says what it does ('%s')" % panel._arrange.text)
	return panel

## --- moving them ----------------------------------------------------------------

func _arranging(panel: ControlsPanel) -> void:
	await click(panel._arrange.get_global_rect().get_center())
	await frames(4)
	var ed := editor()
	check(ed != null and ed.is_visible_in_tree(), "pressing it puts up the screen that moves them")
	if ed == null:
		return
	check(ed.get_global_rect().size.is_equal_approx(screen()), "over the whole screen")
	check(ed._working.is_empty(), "with every button where the design has it")

	# HIT, carried to the middle of the screen and let go where it fits. Left
	# of the middle and low, so it keeps to the bottom-left corner from now on.
	var hit_was := middle_of("attack", {})
	var hit_to := Vector2(600, 460)
	await carry(hit_was, hit_to)
	check(ed._dragging == index_of("attack"), "a thumb on HIT takes it")
	check(ed._fits(ed._dragging, ed._entry(control_of("attack"), ed._now)),
		"and it is somewhere it can stay, so it is not drawn red")
	await lift(hit_to)
	var entry: Dictionary = ed._working.get("attack", {})
	check(not entry.is_empty() and Vector2(entry["at"]).is_equal_approx(hit_to)
			and Vector2(entry["pin"]).is_equal_approx(Vector2(0, 1)),
		"let go, it stays there, kept to the bottom-left corner it is nearest (%s)" % str(entry))
	check(TouchPad.layout().is_empty(), "and nothing is kept yet")

	# DASH, let go on HIT: it would cover it, so it goes back.
	var dash_was := middle_of("dash", ed._working)
	var hit_at := middle_of("attack", ed._working)
	await carry(dash_was, hit_at)
	check(ed._dragging == index_of("dash")
			and not ed._fits(ed._dragging, ed._entry(control_of("dash"), ed._now)),
		"DASH carried onto HIT is somewhere it cannot stay, drawn red")
	await lift(hit_at)
	check(not ed._working.has("dash") and middle_of("dash", ed._working).is_equal_approx(dash_was),
		"and let go there it goes back where it was")

	# USE, let go over the HUD's corner: the same.
	var use_was := middle_of("dash", ed._working)
	await carry(use_was, TouchLayoutEditor.HUD_CORNER.get_center())
	await lift(TouchLayoutEditor.HUD_CORNER.get_center())
	check(not ed._working.has("dash"), "nor may a button cover the HUD's corner")

	# A plate is carried by where it was taken, not jumped to by its corner —
	# here to the top of the screen, between the HUD's corner and the skills.
	var map_rect := TouchPad.area(TouchPad.placed(control_of("open_map"), ed._working), screen())
	var took := map_rect.get_center()
	var map_to := Vector2(560, 80)
	await carry(took, map_to)
	await lift(map_to)
	var map_entry: Dictionary = ed._working.get("open_map", {})
	check(not map_entry.is_empty()
			and TouchPad.area(TouchPad.placed(control_of("open_map"), ed._working), screen()) \
				.get_center().is_equal_approx(map_to),
		"MAP moves with the thumb that took it, from wherever it was taken (%s)" % str(map_entry))

	# SAVE keeps it, and the screen goes.
	await click(ed._save.get_global_rect().get_center())
	await frames(4)
	check(editor() == null, "SAVE puts the screen away")
	var kept := TouchPad.layout()
	check(kept.has("attack") and kept.has("open_map") and not kept.has("dash"),
		"and keeps what was moved and nothing that was not (%s)" % str(kept.keys()))
	check(FileAccess.file_exists(TouchPad.LAYOUT_PATH), "in a file of its own")
	TouchPad._layout_read = false
	check(TouchPad.layout().get("attack", {}).get("at", Vector2.ZERO).is_equal_approx(hit_to),
		"which reads back the same")
	check(get_viewport().gui_get_focus_owner() == panel._arrange,
		"and the keyboard is back on the button that opened it")

## --- in a fight ------------------------------------------------------------------

func _in_a_raid() -> void:
	game._deploy("SWORD")
	await frames(24)
	var pad: TouchPad = game.touch_pad
	check(pad != null and pad.visible, "a raid, with the console on the glass")
	# Out of the exit the raid starts the player in, where HIT is USE: out in
	# the open, where it is HIT.
	var raid := game.current as Raid
	raid.player.global_position = raid.room.to_global(raid.room.standing_near(raid.room.cell_center(20, 11)))
	raid.player.velocity = Vector2.ZERO
	await frames(3)
	check(not pad.use_near, "stood out in the open, with nothing to use, so HIT is HIT")
	touch(0, Vector2(600, 460), true)
	await frames(3)
	check(Input.is_action_pressed("attack"), "a thumb where HIT was put presses HIT")
	touch(0, Vector2(600, 460), false)
	await frames(3)
	var old_hit := TouchPad.middle(control_of("attack"), screen())
	touch(0, old_hit, true)
	await frames(3)
	check(not Input.is_action_pressed("attack"), "and one where it used to be does not")
	touch(0, old_hit, false)
	await frames(3)

func _another_shape() -> void:
	var was := DisplayServer.window_get_size()
	# A long phone: HIT keeps to the left, DASH, never moved, to the right.
	DisplayServer.window_set_size(Vector2i(1480, 640))
	await frames(8)
	var hit_at := middle_of("attack", TouchPad.layout())
	check(hit_at.is_equal_approx(Vector2(600, 460)),
		"on a long phone HIT stays that far from the bottom-left corner (%s)" % str(hit_at))
	touch(0, hit_at, true)
	await frames(3)
	check(Input.is_action_pressed("attack"), "and a thumb there still presses it")
	touch(0, hit_at, false)
	await frames(3)
	var dash_at := middle_of("dash", TouchPad.layout())
	check(screen().x - dash_at.x < 100.0, "while DASH stays by the right edge (%s)" % str(dash_at))
	touch(0, dash_at, true)
	await frames(3)
	check(Input.is_action_pressed("dash"), "where a thumb still finds it")
	touch(0, dash_at, false)
	await frames(3)
	# A tablet: the bottom has gone down, and HIT with it.
	DisplayServer.window_set_size(Vector2i(1152, 864))
	await frames(8)
	hit_at = middle_of("attack", TouchPad.layout())
	check(is_equal_approx(screen().y - hit_at.y, 720.0 - 460.0),
		"on a tablet HIT keeps its distance from the bottom (%s on %s)" % [str(hit_at), str(screen())])
	touch(0, hit_at, true)
	await frames(3)
	check(Input.is_action_pressed("attack"), "and presses there")
	touch(0, hit_at, false)
	await frames(3)
	DisplayServer.window_set_size(was)
	await frames(8)

## --- putting it back ----------------------------------------------------------------

func _reset_from_the_pause_menu() -> void:
	game._pause()
	await frames(3)
	game._pause_controls(true)
	await frames(6)
	var panel := find_under(game.pause_controls, func(n: Node) -> bool: return n is ControlsPanel) \
		as ControlsPanel
	check(panel != null and panel._arrange.is_visible_in_tree(),
		"the pause menu's controls page has SET BUTTON POSITIONS too")
	if panel == null:
		return
	await click(panel._arrange.get_global_rect().get_center())
	await frames(4)
	var ed := editor()
	check(ed != null and get_tree().paused, "and it opens over the paused raid")
	if ed == null:
		return
	check(ed._working.has("attack"), "showing the buttons where they were put")
	var reset := find_under(ed, func(n: Node) -> bool:
		return n is Button and (n as Button).text == Loc.t("controls.arrange.reset")) as Button
	await click(reset.get_global_rect().get_center())
	await frames(2)
	check(ed._working.is_empty() and not TouchPad.layout().is_empty(),
		"RESET puts every button back where the design has it, keeping nothing yet")
	await click(ed._save.get_global_rect().get_center())
	await frames(4)
	check(TouchPad.layout().is_empty(), "and SAVE keeps that")
	game._pause_controls(false)
	game._unpause()
	await frames(6)
	var hit_at := TouchPad.middle(control_of("attack"), screen())
	touch(0, hit_at, true)
	await frames(3)
	check(Input.is_action_pressed("attack"), "so HIT is back where it started")
	touch(0, hit_at, false)
	await frames(3)

func _the_way_out() -> void:
	game.goto_title()
	await frames(10)
	var panel := await _the_row_again()
	if panel == null:
		return
	await click(panel._arrange.get_global_rect().get_center())
	await frames(4)
	var ed := editor()
	check(ed != null, "the screen, once more")
	if ed == null:
		return
	var dash_was := middle_of("dash", {})
	await carry(dash_was, Vector2(600, 460))
	await lift(Vector2(600, 460))
	check(ed._working.has("dash"), "with DASH moved")
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	Input.parse_input_event(esc)
	await frames(4)
	check(editor() == null, "the way back out puts it away")
	check(TouchPad.layout().is_empty(), "and keeps nothing of what was done there")
	check((game.current as TitleScreen)._controls.visible,
		"leaving the controls page where it was, rather than backing out of that too")

func _the_row_again() -> ControlsPanel:
	var title := game.current as TitleScreen
	title._toggle_settings()
	await frames(3)
	title._toggle_controls()
	await frames(6)
	return find_under(title._controls, func(n: Node) -> bool: return n is ControlsPanel) \
		as ControlsPanel
