extends Node
## The menus in mobile mode, which are laid out for a thumb (`UiKit.mobile`):
## every page the kit builds — the title's settings and its save slots, the
## pause menu, a station's panel in the hideout — is a page most of the width
## of the screen, on it, with nothing to press under THUMB tall, its words at
## THUMB_TEXT, and no two things to press on one another. On a 16:9 screen and
## on one the shape of a long phone.
##
## What is on a page is a thumb's too: the controls page has the switch, SET
## BUTTON POSITIONS and the aim's help, and no pointer speed and no bindings,
## which a phone has nothing to set with. And a page that scrolls can be dragged
## by whatever the thumb lands on: nothing between a button and the scroll keeps
## the press for itself.
##
## The mode is thrown on a page of these menus, so each is built again for the
## other mode with the same page up — and with the keyboard on the switch that
## took the old one's place. At a desk every one of them is as it was.

const GameScript := preload("res://app/game.gd")

var fails := 0
var game: Node

func check(ok: bool, what: String) -> void:
	if ok:
		print("[THUMB] PASS ", what)
	else:
		fails += 1
		push_error("THUMB FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func screen() -> Vector2:
	return get_viewport().get_visible_rect().size

func on_glass(at: Vector2) -> Vector2:
	return get_window().get_final_transform() * at

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

func action(name: String) -> void:
	for down in [true, false]:
		var e := InputEventAction.new()
		e.action = name
		e.pressed = down
		Input.parse_input_event(e)
		await frames(2)
	await frames(2)

## Every Control under `root` that is on the screen.
func shown_under(root: Node) -> Array:
	var out: Array = []
	for c in root.find_children("*", "Control", true, false):
		if (c as Control).is_visible_in_tree():
			out.append(c)
	return out

## What a thumb presses on a page: its buttons, switches and sliders.
func pressables(root: Node) -> Array:
	var out: Array = []
	for c in shown_under(root):
		if (c is BaseButton or c is Slider) and not c is ScrollBar:
			out.append(c)
	return out

func find_under(root: Node, pick: Callable) -> Node:
	for c in root.find_children("*", "", true, false):
		if pick.call(c):
			return c
	return null

func switch_on(page: Node) -> UiKit.Switch:
	return find_under(page, func(n: Node) -> bool: return n is UiKit.Switch) as UiKit.Switch

func focus_owner() -> Control:
	return get_viewport().gui_get_focus_owner()

## Where `c` can be pressed: all of it, or for a row of the page's list as much
## of it as the scroll is showing — the rest is under the page's head or foot,
## out of a thumb's reach until the list is dragged.
func on_page(f: UiKit.ScreenFrame, c: Control) -> Rect2:
	var r := c.get_global_rect()
	return r.intersection(f.body.get_global_rect()) if f.body.is_ancestor_of(c) else r

## A page laid out for a thumb: where it stands, and everything on it.
func audit(name: String, f: UiKit.ScreenFrame) -> void:
	var vp := screen()
	check(f.thumb, "%s: the page is built for a thumb" % name)
	var want := minf(UiKit.THUMB_PAGE, vp.x - UiKit.THUMB_EDGE * 2.0)
	check(is_equal_approx(f.size.x, want), "%s: most of the width of the screen (%.0f of %.0f)" % [name, f.size.x, vp.x])
	check(Rect2(Vector2.ZERO, vp).encloses(f.get_global_rect()),
		"%s: all of it on the screen (%s)" % [name, str(f.get_global_rect())])
	var short: Array = []
	var small: Array = []
	var out: Array = []
	var held: Array = []
	var page := f.get_global_rect()
	var things := pressables(f)
	check(things.size() > 0, "%s: with something on it to press (%d)" % [name, things.size()])
	for c: Control in things:
		var r := c.get_global_rect()
		var what := (c as Button).text if c is Button else c.get_class()
		if r.size.y < UiKit.THUMB - 0.5:
			short.append("%s %.0f" % [what, r.size.y])
		if r.position.x < page.position.x - 0.5 or r.end.x > page.end.x + 0.5:
			out.append(what)
		# A page is dragged by whatever the thumb is on: the press goes on up to
		# the scroll, past everything between. A slider is the one thing that
		# keeps its own — a thumb on it is moving the knob.
		if f.body.is_ancestor_of(c) and not c is Slider:
			var at: Node = c
			while at != f.body:
				if at is Control and (at as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
					held.append("%s at %s" % [what, at.get_class()])
					break
				at = at.get_parent()
	for c: Control in shown_under(f):
		var size := 0
		if c is Label and (c as Label).text != "":
			size = (c as Label).get_theme_font_size("font_size")
		elif c is Button and (c as Button).text != "":
			size = (c as Button).get_theme_font_size("font_size")
		if size > 0 and size < UiKit.THUMB_TEXT:
			small.append("%s at %d" % [c.get("text"), size])
	check(short.is_empty(), "%s: nothing to press stands under %.0f (%s)" % [name, UiKit.THUMB, str(short)])
	check(small.is_empty(), "%s: every word is written at a thumb's size (%s)" % [name, str(small)])
	check(out.is_empty(), "%s: and nothing to press hangs off the page (%s)" % [name, str(out)])
	check(held.is_empty(), "%s: a press on any of it reaches the page, to drag it by (%s)" % [name, str(held)])
	var over: Array = []
	for i in things.size():
		for j in range(i + 1, things.size()):
			var a: Control = things[i]
			var b: Control = things[j]
			if a.is_ancestor_of(b) or b.is_ancestor_of(a):
				continue
			if on_page(f, a).grow(-1.0).intersects(on_page(f, b).grow(-1.0)):
				over.append("%s/%s" % [a.get_class(), b.get_class()])
	check(over.is_empty(), "%s: no two of them on one another (%s)" % [name, str(over)])
	check(f.body.scroll_deadzone >= int(UiKit.TOUCH_SLOP),
		"%s: and a thumb's tremor on a button is not a drag (%d)" % [name, f.body.scroll_deadzone])

func _ready() -> void:
	var was_mode := Touch.mode
	var was_size := DisplayServer.window_get_size()
	# Not 1:1, where a design position and a window position are the same number.
	DisplayServer.window_set_size(Vector2i(1440, 810))
	Touch.set_mode(Touch.OFF)
	TouchPad.set_layout({}, false)
	GameState.reset_profile()
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(10)
	await _at_a_desk()
	await _the_title()
	await _thrown_from_a_page()
	await _the_pause_menu()
	await _the_hideout()
	await _a_long_phone()
	Touch.set_mode(was_mode)
	DisplayServer.window_set_size(was_size)
	print("[THUMB] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## --- at a desk ------------------------------------------------------------------

## With mobile mode off nothing here has moved: the pages are a desk's width,
## their buttons a word tall, and the controls page has all of its rows.
func _at_a_desk() -> void:
	var t := game.current as TitleScreen
	t._toggle_settings()
	t._toggle_controls()
	await frames(4)
	check(not UiKit.mobile() and UiKit.thumb() == 0.0 and UiKit.text(16) == 16,
		"at a desk the kit builds a desk's rows")
	check(not t._controls.thumb and is_equal_approx(t._controls.size.x, 608.0),
		"and a page is a desk's width (%.0f)" % t._controls.size.x)
	var panel := find_under(t._controls, func(n: Node) -> bool: return n is ControlsPanel) as ControlsPanel
	check(panel != null and not panel.thumb() and panel._rows.size() == Controls.ACTIONS.size(),
		"its controls page lists a binding an action (%d)" % (panel._rows.size() if panel else -1))
	var sliders := shown_under(t._controls).filter(func(c: Node) -> bool: return c is Slider)
	check(sliders.size() == 2, "under the pointer's speed and the aim's help (%d sliders)" % sliders.size())
	var tall := 0.0
	for c: Control in pressables(t._controls):
		tall = maxf(tall, c.size.y)
	check(tall < UiKit.THUMB, "with nothing on it a thumb's height (%.0f at most)" % tall)
	check(t._save_slot_root is VBoxContainer, "and the save slots are the column under the seal")
	t._toggle_controls()
	t._toggle_settings()
	await frames(2)

## --- the title's pages ------------------------------------------------------------

func _the_title() -> void:
	Touch.set_mode(Touch.ON)
	await frames(4)
	var t := game.current as TitleScreen
	check(UiKit.mobile() and UiKit.thumb() == UiKit.THUMB and UiKit.text(16) == UiKit.THUMB_TEXT,
		"in mobile mode the kit builds a thumb's")
	t._toggle_settings()
	await frames(4)
	audit("settings", t._settings)
	t._toggle_general()
	await frames(4)
	audit("general", t._general)
	check(shown_under(t._general).filter(func(c: Node) -> bool: return c is Slider).size() == 2,
		"general: the two volumes are sliders a thumb can run along")
	t._toggle_general()
	t._toggle_controls()
	await frames(4)
	audit("controls", t._controls)
	var panel := find_under(t._controls, func(n: Node) -> bool: return n is ControlsPanel) as ControlsPanel
	check(panel != null and panel.thumb(), "controls: its panel is a thumb's")
	if panel != null:
		check(panel._rows.is_empty(), "controls: with no bindings on it — there is no key on the glass to bind (%d)" % panel._rows.size())
		var sliders := shown_under(panel).filter(func(c: Node) -> bool: return c is Slider)
		check(sliders.size() == 1, "controls: nor the pointer's speed, only the aim's help (%d sliders)" % sliders.size())
		check(switch_on(panel) != null and switch_on(panel).button_pressed,
			"controls: the switch is there, and on")
		check(panel._arrange != null and panel._arrange.is_visible_in_tree(),
			"controls: and SET BUTTON POSITIONS under it")
	t._toggle_controls()
	t._toggle_settings()
	await frames(2)

	# The save slots: a page of plates rather than a column of lines.
	t._show_save_slots()
	await frames(4)
	check(t._save_slot_root is UiKit.ScreenFrame, "the save slots are a page of their own")
	if t._save_slot_root is UiKit.ScreenFrame:
		audit("save slots", t._save_slot_root)
	check(t._slot_rows.size() == TitleScreen.SAVE_SLOTS, "save slots: a row a slot (%d)" % t._slot_rows.size())
	var bin: Button = t._slot_rows[1]["bin"]
	check(bin.size.x >= UiKit.THUMB and bin.size.y >= UiKit.THUMB,
		"save slots: a can is a plate of its own, a thumb across (%s)" % str(bin.size))
	await click(bin.get_global_rect().get_center())
	check(t._armed_slot == 2 and (t._slot_rows[1]["stamp"] as Label).text == Loc.t("menu.save_slots.slot_delete"),
		"save slots: a press on it arms it, and the row says so")
	await action("ui_cancel")
	check(t._armed_slot == -1 and t._save_slot_root.visible, "save slots: backing out calls it off first")
	await action("ui_cancel")
	check(t._menu_root.visible and not is_instance_valid(t._save_slot_root) or not t._save_slot_root.visible,
		"save slots: and then leaves the page")

## --- thrown from a page ---------------------------------------------------------------

## The switch is on the controls page, so throwing it lays out the very page it
## is on. The page stays up, and the keyboard stays on the switch.
func _thrown_from_a_page() -> void:
	var t := game.current as TitleScreen
	t._toggle_settings()
	t._toggle_controls()
	await frames(4)
	var before := switch_on(t._controls)
	before.grab_focus()
	await action("ui_accept")
	await frames(3)
	check(not Touch.wanted(), "thrown from the keyboard, mobile mode goes off")
	check(t._controls.visible and not t._controls.thumb and not t._settings.visible,
		"and the controls page is up still, laid out for a desk")
	var after := switch_on(t._controls)
	check(after != null and after != before and focus_owner() == after,
		"with the keyboard on the switch that took the old one's place")
	check(t._menu_root is VBoxContainer, "the menu under it is a column again")
	await action("ui_accept")
	await frames(3)
	check(Touch.wanted() and t._controls.visible and t._controls.thumb and focus_owner() == switch_on(t._controls),
		"and thrown back, it is a thumb's again, the keyboard still on the switch")
	t._toggle_controls()
	t._toggle_settings()
	await frames(2)

## --- the pause menu -------------------------------------------------------------------

## Built once at boot, at a desk's size as it happened, and kept. It is built
## again when it comes up in a mode it was not built for — and on its own
## controls page, where the mode is thrown from inside it.
func _the_pause_menu() -> void:
	game.goto_sandbox()
	await frames(12)
	check(not game.pause_thumb, "the pause menu was built at boot, for a desk")
	game._pause()
	await frames(4)
	check(game.pause_thumb, "paused in mobile mode, it is built again for a thumb")
	audit("paused", game.pause_main)
	game._pause_general(true)
	await frames(4)
	audit("paused, general", game.pause_general)
	game._pause_general(false)
	game._pause_controls(true)
	await frames(4)
	audit("paused, controls", game.pause_controls)
	var arrow := find_under(game.pause_controls, func(n: Node) -> bool:
		return n is Button and (n as Button).text == Loc.t("menu.pause.arrow")) as Button
	check(arrow != null and arrow.size.x >= UiKit.THUMB,
		"paused, controls: the way back in its corner is a thumb across")
	await click(switch_on(game.pause_controls).get_global_rect().get_center())
	await frames(4)
	check(not Touch.wanted() and not game.pause_thumb, "the switch thrown on it lays the menu out for a desk")
	check(game.pause_menu.visible and game.pause_controls.visible and not game.pause_main.visible,
		"with the controls page up still")
	check(get_tree().paused, "and the game still stopped behind it")
	await click(switch_on(game.pause_controls).get_global_rect().get_center())
	await frames(4)
	check(Touch.wanted() and game.pause_thumb and game.pause_controls.visible,
		"and thrown back, for a thumb again")
	game._unpause()
	await frames(4)

## --- a station's panel -------------------------------------------------------------------

func _the_hideout() -> void:
	game.goto_hideout()
	await frames(12)
	var world := game.current as HideoutWorld
	var view: HideoutWorldView = Views.of(world)
	var pad: TouchPad = game.touch_pad
	world.open_station("weapons")
	await frames(6)
	check(view.panel is UiKit.ScreenFrame, "the rack opens its panel")
	audit("the rack", view.panel)
	check(pad.face == TouchPad.Face.CLEAR,
		"the rack: the console's keys are cleared from under the page (face %d)" % pad.face)
	var frame := view.panel as UiKit.ScreenFrame
	var rack: Array = []
	for c: Control in pressables(frame.rows):
		if c is Button and Weapons.ids().any(func(id: String) -> bool:
				return (c as Button).text.contains(Weapons.name_for(id))):
			rack.append(c)
	# Rows of Hideout.RACK_COLUMNS, every plate as wide as the first.
	var level := rack.size() == Weapons.ids().size()
	for i in rack.size():
		var b: Control = rack[i]
		var first: Control = rack[i - i % Hideout.RACK_COLUMNS]
		# To a pixel: a row's width shared three ways need not come out whole.
		level = level and is_equal_approx(b.global_position.y, first.global_position.y) \
			and absf(b.size.x - (rack[0] as Control).size.x) <= 1.0
	check(level, "the rack: its weapons stand in rows of %d, as wide as each other (%d of them)"
		% [Hideout.RACK_COLUMNS, rack.size()])
	check(frame.rows.get_combined_minimum_size().y <= frame.body.size.y + 1.0,
		"the rack: so the whole of it is on the page, BUILD included, with nothing to scroll (%.0f in %.0f)"
			% [frame.rows.get_combined_minimum_size().y, frame.body.size.y])
	world.close_panel()
	await frames(4)
	check(pad.face == TouchPad.Face.PLAY, "and closed, the console has its keys again")

	world.open_station("shop")
	await frames(6)
	audit("the counter", view.panel)
	frame = view.panel as UiKit.ScreenFrame
	check(frame.rows.get_combined_minimum_size().y > frame.body.size.y,
		"the counter: its list is longer than the page, which scrolls it")
	# The mode thrown under a panel — from the pause menu, which comes up over
	# one — builds the panel again.
	Touch.set_mode(Touch.OFF)
	await frames(4)
	check(view.panel is UiKit.ScreenFrame and not (view.panel as UiKit.ScreenFrame).thumb,
		"the counter: thrown to a desk under it, the panel is a desk's")
	Touch.set_mode(Touch.ON)
	await frames(4)
	check((view.panel as UiKit.ScreenFrame).thumb, "the counter: and a thumb's again")
	world.close_panel()
	await frames(4)

## --- another shape of screen ---------------------------------------------------------

## A phone longer than 16:9: the pages are as wide as a page runs, in the middle
## of it.
func _a_long_phone() -> void:
	DisplayServer.window_set_size(Vector2i(1560, 720))
	await frames(6)
	game.goto_title()
	await frames(8)
	var t := game.current as TitleScreen
	t._toggle_settings()
	t._toggle_general()
	await frames(4)
	audit("general, on a long phone", t._general)
	check(is_equal_approx(t._general.size.x, UiKit.THUMB_PAGE)
			and absf(t._general.get_global_rect().get_center().x - screen().x * 0.5) <= 1.0,
		"general, on a long phone: as wide as a page runs, in the middle (%.0f wide on %.0f)"
			% [t._general.size.x, screen().x])
	t._toggle_general()
	t._toggle_settings()
	await frames(2)
