extends Node
## The title's settings and the pause menu are built in UiKit's pixel look all
## the way down, including the controls list they share. The title's settings
## are three pages now — the two buttons themselves, the volumes and language
## behind GENERAL SETTINGS, and the rebinding list behind CONTROL SETTINGS —
## and the pause menu is two, so all five are checked: every piece of text is
## the pixel face at a multiple of its native 8px, every box is square,
## unsmoothed and evenly bordered, the sliders and scrollbars are replaced, the
## bindings still line up and fit, and the panel fits the width it is given. The
## pause menu is checked for one thing more — that its rows sit on something
## solid, since the raid behind it goes on being drawn and showed through them.
##
## Each button and its page are checked too: one page at a time is on screen,
## the button leads to it and BACK leads out of it.
##
## And the three settings that are about the machine rather than the game —
## the screen mode, whether an impact may move the camera and whether the
## parts' icons move — which both screens carry and which have to agree with
## `Video` about what is set. Camera shake is
## pressed and followed all the way down to `Fx`; the screen mode is not, since
## a test that took the whole display twice a run is a test that gets switched
## off. See the note where it is checked.

const GameScript := preload("res://app/game.gd")
const BOXES := ["panel", "normal", "hover", "pressed", "focus", "disabled", "slider",
	"grabber_area", "grabber_area_highlight", "scroll", "scroll_focus", "grabber",
	"grabber_highlight", "grabber_pressed"]

var game: Node
var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[PIXUI] PASS ", what)
	else:
		fails += 1
		push_error("PIXUI FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## Every Control under `root`, scrollbars included: they are internal children.
func controls_under(root: Node) -> Array:
	var out: Array = []
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Control:
			out.append(n)
		for c in n.get_children(true):
			stack.append(c)
	return out

## The first Control under `root` that `pick` says yes to, or null.
func find_under(root: Node, pick: Callable) -> Node:
	for c in controls_under(root):
		if pick.call(c):
			return c
	return null

func button_named(root: Node, text: String) -> Button:
	return find_under(root, func(c: Node) -> bool: return c is Button and (c as Button).text == text) as Button

## The row a setting named `name` stands in: the one its name is written in.
func row_named(page: Node, name: String) -> Node:
	var label := find_under(page, func(c: Node) -> bool:
		return c is Label and (c as Label).text == name)
	return label.get_parent() if label != null else null

## The rows that answer to `Video`, checked wherever settings are shown.
## Both screens build them from `VideoRows`, so a page missing one is a page
## that forgot to ask rather than a row that was written differently.
##
## The answer in force is the button that cannot be pressed, which is the whole
## of how these rows say what is set: `Video` is read for what it should be and
## the page for what it is showing. Two of the rows answer OFF and ON, so each
## row's answers are looked for in the row its name is in.
func video_rows(page: Node, where: String) -> void:
	for named in [
			[Loc.t("menu.video.screen"), Loc.t("menu.video.windowed"),
				Loc.t("menu.video.fullscreen"), Video.fullscreen],
			[Loc.t("menu.video.shake"), Loc.t("menu.video.off"),
				Loc.t("menu.video.on"), Video.screen_shake],
			[Loc.t("menu.video.icons"), Loc.t("menu.video.off"),
				Loc.t("menu.video.on"), Video.icon_motion]]:
		var name := String(named[0])
		var row := row_named(page, name)
		check(row != null, "%s carries '%s'" % [where, name])
		if row == null:
			continue
		var off := button_named(row, String(named[1]))
		var on := button_named(row, String(named[2]))
		var set_on: bool = bool(named[3])
		check(off != null and on != null, "%s: with both answers on it" % where)
		if off == null or on == null:
			continue
		check(on.disabled == set_on and off.disabled != set_on,
			"%s: and the one in force is the one that cannot be pressed (%s)"
				% [where, "on" if set_on else "off"])

## Every check that says a built menu is in the pixel look, run over whatever is
## under `frame`: the settings, the pause menu and the rebinding page each
## screen keeps behind its CONTROL SETTINGS button are all the same kit, and all
## the same frame — a pinned head, the rows in a scroll, a pinned foot.
##
## `sliders` and `min_texts` are what that page is expected to hold — the title
## keeps nothing on its front page but the buttons onto the other two, while the
## pause menu still carries its volume rows itself.
func audit(frame: UiKit.ScreenFrame, what: String, sliders_want: int, min_texts: int) -> void:
	var all := controls_under(frame)
	var texts := 0
	var plain: Array = []
	var boxes := 0
	var soft: Array = []
	var sliders := 0
	var knobs := 0
	for c in all:
		if c is Label or c is Button:
			texts += 1
			var size: int = c.get_theme_font_size("font_size")
			if c.get_theme_font("font") != UiKit.PIXEL_FONT or size < 16 or size % 8 != 0:
				plain.append("%s '%s' @%d" % [c.get_class(), c.text, size])
		if c is HSlider:
			sliders += 1
			if c.has_theme_icon_override("grabber"):
				knobs += 1
		for name in BOXES:
			if not c.has_theme_stylebox_override(name):
				continue
			var sb := c.get_theme_stylebox(name) as StyleBoxFlat
			if sb == null:
				continue
			boxes += 1
			var bad := sb.anti_aliasing
			for i in 4:
				if sb.get_border_width(i) % UiKit.PIXEL != 0 or sb.get_corner_radius(i) != 0:
					bad = true
			if bad:
				soft.append("%s.%s at %s (aa=%s radius=%d border=%d)" % [c.get_class(), name,
					frame.get_path_to(c), sb.anti_aliasing, sb.get_corner_radius(CORNER_TOP_LEFT),
					sb.get_border_width(SIDE_LEFT)])
	check(texts >= min_texts and plain.is_empty(),
		"%s: every text is the pixel face at a multiple of 8px (%d checked, off: %s)" % [what, texts, str(plain)])
	check(boxes > 20 and soft.is_empty(),
		"%s: every box is square, unsmoothed and evenly bordered (%d checked, off: %s)" % [what, boxes, str(soft)])
	check(sliders == sliders_want and knobs == sliders_want,
		"%s: every slider has the square knob (%d knobs on %d of %d sliders)" % [what, knobs, sliders, sliders_want])
	check(frame.body.get_v_scroll_bar().has_theme_stylebox_override("grabber"),
		"%s: the scrollbar is the pixel one" % what)

	var bar := frame.body.get_v_scroll_bar()
	var room := frame.body.size.x - (bar.size.x if bar.visible else 0.0)
	var wanted := frame.rows.get_combined_minimum_size().x
	check(wanted <= room + 0.5, "%s: the rows fit the width they are given (%.0f of %.0f)" % [what, wanted, room])
	# The head and the foot are outside the scroll and have the panel to
	# themselves, bar and all.
	for box: Control in [frame.head, frame.foot]:
		check(box.get_combined_minimum_size().x <= box.size.x + 0.5,
			"%s: what is pinned fits the panel too (%.0f of %.0f)"
				% [what, box.get_combined_minimum_size().x, box.size.x])


func _ready() -> void:
	GameState.reset_profile()
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(10)

	var title: TitleScreen = game.current
	title._toggle_settings()
	await frames(8)
	audit(title._settings, "the settings", 0, 4)

	# --- the general page ----------------------------------------------------
	# The volumes and the language are not on the settings any more either: the
	# settings are two buttons and the way back, and nothing else.
	check(find_under(title._settings, func(c: Node) -> bool: return c is HSlider) == null,
		"the settings no longer carry the volume rows themselves")
	var open_general := button_named(title._settings, Menus.name_for("general"))
	check(open_general != null, "the settings offer '%s'" % Menus.name_for("general"))
	check(title._general != null and not title._general.visible,
		"and the page behind it starts closed")
	if open_general != null:
		open_general.emit_signal("pressed")
		await frames(8)
	check(title._general.visible and not title._settings.visible,
		"pressing it swaps the settings for the general page")
	audit(title._general, "the general page", 2, 7)

	# --- the language switch ------------------------------------------------
	# It lives on the general page, and pressing it has to rebuild the page it
	# was pressed on, the settings and menu behind it and the pause menu that
	# outlives all of them — none of which redraw themselves, since every word
	# on them is written once.
	var was_language := Loc.language
	var other := ""
	for lang in Loc.languages():
		if lang != Loc.language:
			other = lang
	check(other != "", "there is a second language to switch to")
	if other != "":
		var pick: Button = null
		for c in controls_under(title._general):
			if c is Button and (c as Button).text == Loc.language_name(other):
				pick = c
		check(pick != null, "the general page offers %s, written in itself ('%s')"
			% [other, Loc.language_name(other)])
		if pick != null:
			pick.emit_signal("pressed")
			await frames(8)
			check(Loc.language == other, "pressing it switches the game to %s" % other)
			check(title._general != null and title._general.visible,
				"and leaves the general page open, where the button was")
			var heading := ""
			for c in controls_under(title._general):
				if c is Label and (c as Label).text == Menus.name_for("general"):
					heading = (c as Label).text
			check(heading != "", "the page is rebuilt in %s ('%s')" % [other, heading])
			check(title._start_button != null
					and title._start_button.text == Loc.t("menu.title.start"),
				"and so is the menu behind it ('%s')"
					% ("" if title._start_button == null else title._start_button.text))
			var paused_in := 0
			for c in controls_under(game.pause_menu):
				if c is Button and (c as Button).text == Loc.t("menu.pause.resume"):
					paused_in += 1
			check(paused_in == 1, "and the pause menu, which no screen owns (%d)" % paused_in)
			Loc.set_language(was_language)
			await frames(8)
			check(Loc.language == was_language, "switching back puts %s on again" % was_language)

	# --- the settings that are about the machine -----------------------------
	# Screen mode and camera shake, on the same page as the volumes and the
	# language, and the same two rows in the pause menu below.
	video_rows(title._general, "the general page")

	# Shake off is the answer the game ships with, and off has to mean off all
	# the way down: `Fx` is the one place that reads the setting, so nothing that
	# asks for a shake has to know whether one is wanted.
	var shake_was: bool = Video.screen_shake
	Video.set_screen_shake(false)
	Fx._shake = 0.0
	Fx.shake(6.0)
	check(is_equal_approx(Fx._shake, 0.0),
		"with camera shake off, a hit that asks for one does not get it (%.1f)" % Fx._shake)
	var shake_row := row_named(title._general, Loc.t("menu.video.shake"))
	var shake_on := button_named(shake_row, Loc.t("menu.video.on")) if shake_row != null else null
	check(shake_on != null and not shake_on.disabled,
		"the page offers '%s' while it is off" % Loc.t("menu.video.on"))
	if shake_on != null:
		shake_on.emit_signal("pressed")
		await frames(6)
	check(Video.screen_shake, "pressing it turns camera shake on")
	video_rows(title._general, "the general page, with shake on")
	Fx._shake = 0.0
	Fx.shake(6.0)
	check(is_equal_approx(Fx._shake, 6.0), "and the same hit now gets one (%.1f)" % Fx._shake)
	Fx._shake = 0.0

	# The screen row is not pressed here. It would take the whole display and
	# give it back, twice, in every run of this file — a test nobody would leave
	# switched on. What can be checked without a window changing under the run is
	# that the setting is kept where the language and the bindings are kept.
	var full_was: bool = Video.fullscreen
	Video.fullscreen = not full_was
	Video._save()
	Video.fullscreen = full_was
	Video.screen_shake = not Video.screen_shake
	Video._load()
	check(Video.fullscreen == (not full_was),
		"the screen setting is written to %s and read back" % Video.PATH.get_file())
	Video.fullscreen = full_was
	Video.set_screen_shake(shake_was)
	Video._save()
	await frames(4)

	var general_back := button_named(title._general, Menus.text_for("general", "back"))
	check(general_back != null, "the general page offers '%s'" % Menus.text_for("general", "back"))
	if general_back != null:
		general_back.emit_signal("pressed")
		await frames(8)
	check(title._settings.visible and not title._general.visible,
		"and it leads back to the settings")

	# --- the controls page ---------------------------------------------------
	# The rebinding list is not on the settings any more: it is a page of its
	# own, and CONTROL SETTINGS is the only way onto it.
	check(find_under(title._settings, func(c: Node) -> bool: return c is ControlsPanel) == null,
		"the settings no longer carry the rebinding list themselves")
	var open_controls := button_named(title._settings, Menus.name_for("controls"))
	check(open_controls != null, "the settings offer '%s'" % Menus.name_for("controls"))
	check(title._controls != null and not title._controls.visible,
		"and the page behind it starts closed")
	if open_controls != null:
		open_controls.emit_signal("pressed")
		await frames(8)
	check(title._controls.visible and not title._settings.visible,
		"pressing it swaps the settings for the controls page")
	# Two sliders: how fast the pointer moves, and how much a stick is helped.
	audit(title._controls, "the controls page", 2, 25)

	var cp: ControlsPanel = find_under(title._controls, func(c: Node) -> bool: return c is ControlsPanel) as ControlsPanel
	check(cp != null and cp.pixel, "the controls page builds its list in the pixel look")
	if cp != null:
		var columns := {}
		var tight: Array = []
		for b: Button in cp._rows.values():
			columns[int(round(b.global_position.x))] = true
			if b.get_minimum_size().x > b.size.x + 0.5:
				tight.append(b.text)
		check(columns.size() == 1, "the bindings line up in one column (%d x positions)" % columns.size())
		check(tight.is_empty(), "every binding fits its button (too tight: %s)" % str(tight))

	var back := button_named(title._controls, Menus.text_for("controls", "back"))
	check(back != null, "the controls page offers '%s'" % Menus.text_for("controls", "back"))
	if back != null:
		back.emit_signal("pressed")
		await frames(8)
	check(title._settings.visible and not title._controls.visible,
		"and it leads back to the settings")

	# --- the pause menu -------------------------------------------------------
	# The same kit again, from inside a raid, and the same three pages. It is
	# checked with each page shown, since a scroll that has never been on screen
	# has not laid itself out.
	game.pause_menu.visible = true
	game._pause_controls(false)
	await frames(6)
	var pause_frame: UiKit.ScreenFrame = game.pause_main as UiKit.ScreenFrame
	var resume := button_named(game.pause_main, Loc.t("menu.pause.resume"))
	check(pause_frame != null, "the pause menu is a frame that fits the screen")
	if pause_frame != null:
		audit(pause_frame, "the pause menu", 0, 5)
	check(find_under(game.pause_main, func(c: Node) -> bool: return c is ControlsPanel) == null,
		"PAUSED no longer carries the rebinding list itself")
	check(find_under(game.pause_main, func(c: Node) -> bool: return c is HSlider) == null,
		"nor the volume rows, which are behind GENERAL SETTINGS now")

	var pause_general := button_named(game.pause_main, Menus.name_for("general"))
	check(pause_general != null, "the pause menu offers '%s'" % Menus.name_for("general"))
	if pause_general != null:
		pause_general.emit_signal("pressed")
		await frames(6)
	check(game.pause_general.visible and not game.pause_main.visible,
		"pressing it swaps PAUSED for the general page")
	audit(game.pause_general as UiKit.ScreenFrame, "the pause general page", 2, 4)
	# --- the language switch, from inside a game -----------------------------
	# It is on this page as well as the title's, and pressing it rebuilds the
	# menu it was pressed in — so the page that comes back has to be this one,
	# not PAUSED. Everything else on screen either draws its words every frame
	# or rebuilds itself on the same signal.
	var pause_was := Loc.language
	var pause_other := ""
	for lang in Loc.languages():
		if lang != Loc.language:
			pause_other = lang
	var pause_pick: Button = button_named(game.pause_general, Loc.language_name(pause_other))
	check(pause_pick != null, "the pause menu's general page offers %s" % pause_other)
	if pause_pick != null:
		pause_pick.emit_signal("pressed")
		await frames(8)
		check(Loc.language == pause_other, "pressing it switches the game to %s" % pause_other)
		check(game.pause_general != null and game.pause_general.visible
				and not game.pause_main.visible,
			"and leaves the general page open, where the button was")
		check(button_named(game.pause_general, Loc.t("menu.settings.language")) == null
				and find_under(game.pause_general, func(c: Node) -> bool:
					return c is Label and (c as Label).text == Loc.t("menu.settings.language")) != null,
			"the page is rebuilt in %s" % pause_other)
		Loc.set_language(pause_was)
		await frames(8)
		check(Loc.language == pause_was, "switching back puts %s on again" % pause_was)

	video_rows(game.pause_general, "the pause menu's general page")

	var pause_general_back := button_named(game.pause_general, Menus.text_for("general", "back"))
	if pause_general_back != null:
		pause_general_back.emit_signal("pressed")
		await frames(6)
	check(pause_general_back != null and game.pause_main.visible and not game.pause_general.visible,
		"and BACK leads to PAUSED again")

	# --- the way out, and the arrow ------------------------------------------
	# BACK TO GAME heads PAUSED, over the two doors, with the way to the menu
	# left at the foot; and every page carries an arrow in its top-left corner
	# that means one level up.
	var back_to_game := button_named(game.pause_main, Loc.t("menu.pause.resume"))
	# By which one the shell shows rather than by what it says: in a raid and out
	# of one, the way to the menu is MAIN MENU alike.
	var to_menu: Button = game.pause_park if game.state == GameScript.State.RAID else game.pause_title
	check(back_to_game != null and to_menu != null,
		"PAUSED offers '%s' and the way to the menu" % Loc.t("menu.pause.resume"))
	if back_to_game != null and to_menu != null:
		var rows := (game.pause_main as UiKit.ScreenFrame).rows
		var first_door := button_named(game.pause_main, Menus.name_for("general"))
		check(back_to_game.get_parent() == rows and back_to_game.get_index() == 0
				and first_door != null and first_door.get_parent() == rows
				and first_door.get_index() > back_to_game.get_index(),
			"at the top, over the two doors (%d)" % back_to_game.get_index())
		check(to_menu.get_parent() == (game.pause_main as UiKit.ScreenFrame).foot,
			"and the way to the menu stays at the foot")
	for page in [game.pause_main, game.pause_general, game.pause_controls]:
		check(button_named(page, Loc.t("menu.pause.arrow")) != null,
			"every pause page carries the arrow in its corner")
	var arrow := button_named(game.pause_main, Loc.t("menu.pause.arrow"))
	if arrow != null:
		arrow.emit_signal("pressed")
		await frames(6)
		check(not game.get_tree().paused and not game.pause_menu.visible,
			"and on PAUSED it is the way back into the game")
		game.pause_menu.visible = true
		game._pause_controls(false)
		await frames(6)

	var pause_open := button_named(game.pause_main, Menus.name_for("controls"))
	check(pause_open != null, "the pause menu offers '%s'" % Menus.name_for("controls"))
	if pause_open != null:
		pause_open.emit_signal("pressed")
		await frames(6)
	check(game.pause_controls.visible and not game.pause_main.visible,
		"pressing it swaps PAUSED for the controls page")
	audit(game.pause_controls as UiKit.ScreenFrame, "the pause controls page", 2, 25)
	var pause_cp: ControlsPanel = find_under(game.pause_controls, func(c: Node) -> bool: return c is ControlsPanel) as ControlsPanel
	check(pause_cp != null and pause_cp.pixel, "the pause menu's controls list is the pixel one too")
	var pause_back := button_named(game.pause_controls, Menus.text_for("controls", "back"))
	if pause_back != null:
		pause_back.emit_signal("pressed")
		await frames(6)
	check(pause_back != null and game.pause_main.visible and not game.pause_controls.visible,
		"and BACK leads to PAUSED again")
	# The raid goes on being drawn behind it, and a stopped tree leaves whatever
	# the HUD was saying where it was: the rows have to sit on something solid,
	# or those words come through a button lit under the cursor.
	#
	# Looked up again rather than kept from earlier: the language switch above
	# rebuilt this menu, and every button on it is a different object now.
	var backing := ""
	resume = button_named(game.pause_main, Loc.t("menu.pause.resume"))
	var at: Node = resume
	while at != null and at != game.pause_menu:
		if at is PanelContainer:
			var sb := (at as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
			if sb != null and sb.bg_color.a >= 1.0:
				backing = at.get_class()
		at = at.get_parent()
	check(resume != null and backing != "",
		"and RESUME sits on a panel nothing shows through ('%s')" % backing)
	game.pause_menu.visible = false

	print("[PIXUI] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
