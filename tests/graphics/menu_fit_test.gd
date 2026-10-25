extends Node
## Menus must not run off the bottom of the screen. Both the pause menu and the
## title's settings are a fixed-position column that grows with its contents,
## and two new rebindable actions were enough to push the ABANDON RAID button
## clean out of the viewport with nothing on screen to say it was there.
##
## Each is pages now — itself, and what sits behind its buttons: the title's
## settings keep the volumes and language behind GENERAL SETTINGS and the
## rebinding list behind CONTROL SETTINGS, the pause menu the list alone. The
## pages behind the buttons are the long ones, so every page of both is checked.
##
## Fitting the screen is not enough on its own: a page that scrolled whole kept
## its heading and its way out inside the scroll, and the rebinding list is long
## enough to carry both of them off the screen. So each page is also scrolled to
## its end, and what is pinned around the rows is looked for on the screen
## afterwards.

const GameScript := preload("res://app/game.gd")

var game: Node
var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[MENU] PASS ", what)
	else:
		fails += 1
		push_error("MENU FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## Every menu here is a `UiKit.ScreenFrame` so it can outgrow the screen safely:
## it fits the screen, its rows scroll, and its head and foot do not move.
func audit(name: String, f: UiKit.ScreenFrame) -> void:
	var vp := get_viewport().get_visible_rect().size
	check(f.position.y >= 0.0 and f.position.y + f.size.y <= vp.y + 0.5,
		"%s stays inside the viewport (%.0f..%.0f of %.0f)"
			% [name, f.position.y, f.position.y + f.size.y, vp.y])
	check(f.position.x >= 0.0 and f.position.x + f.size.x <= vp.x + 0.5,
		"%s stays inside it sideways too" % name)
	var wanted := f.rows.get_combined_minimum_size().y
	# Whatever will not fit has to be reachable by scrolling, not lost.
	f.body.scroll_vertical = 100000
	await frames(3)
	var reach := float(f.body.scroll_vertical) + f.body.size.y
	check(reach >= wanted - 1.0,
		"%s can scroll to its last row (reaches %.0f of %.0f)" % [name, reach, wanted])
	# And with the rows at their end, what is pinned around them is still there:
	# the heading over the page and the way out from under it.
	var screen := Rect2(Vector2.ZERO, vp)
	for named in [["head", f.head], ["foot", f.foot]]:
		var box: Control = named[1]
		check(box.get_child_count() > 0 and screen.encloses(box.get_global_rect()),
			"%s keeps its %s on the screen with the rows scrolled to the end (%s)"
				% [name, named[0], box.get_global_rect()])
	f.body.scroll_vertical = 0
	await frames(2)

## The settings pages and the pause menu sit in the middle of the screen, so the
## gap above one is the gap below it. Only a page that fits is centred — a
## longer one fills the room it has and scrolls — so this is for the short ones.
func centred(name: String, f: UiKit.ScreenFrame) -> void:
	var vp := get_viewport().get_visible_rect().size
	check(absf(f.position.x - (vp.x - f.size.x) * 0.5) <= 1.0,
		"%s is centred across the screen (%.0f..%.0f of %.0f)"
			% [name, f.position.x, f.position.x + f.size.x, vp.x])
	check(absf(f.position.y - (vp.y - f.size.y) * 0.5) <= 1.0,
		"%s is centred down it too (%.0f above, %.0f below)"
			% [name, f.position.y, vp.y - f.position.y - f.size.y])

func _ready() -> void:
	GameState.reset_profile()
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(10)

	var title = game.current
	title._toggle_settings()
	await frames(8)
	check(title._settings is UiKit.ScreenFrame, "the title's settings panel is a frame")
	await audit("title settings", title._settings)
	centred("title settings", title._settings)
	title._toggle_general()
	await frames(8)
	check(title._general is UiKit.ScreenFrame, "the title's general page is one too")
	await audit("title general", title._general)
	centred("title general", title._general)
	title._toggle_general()
	await frames(4)
	title._toggle_controls()
	await frames(8)
	check(title._controls is UiKit.ScreenFrame, "and so is the rebinding page")
	await audit("title controls", title._controls)
	title._toggle_controls()
	await frames(4)
	title._toggle_settings()
	await frames(4)

	game._deploy("SWORD")
	await frames(24)
	game._pause()
	await frames(8)
	var sc: UiKit.ScreenFrame = game.pause_main as UiKit.ScreenFrame
	check(sc != null, "the pause menu is a frame")
	if sc != null:
		await audit("pause menu", sc)
		centred("pause menu", sc)
	game._pause_general(true)
	await frames(8)
	var gc: UiKit.ScreenFrame = game.pause_general as UiKit.ScreenFrame
	check(gc != null, "the pause menu's general page is one")
	if gc != null:
		await audit("pause general", gc)
		centred("pause general", gc)
	game._pause_general(false)
	await frames(4)
	game._pause_controls(true)
	await frames(8)
	var cc: UiKit.ScreenFrame = game.pause_controls as UiKit.ScreenFrame
	check(cc != null, "and so is the controls page behind it")
	if cc != null:
		await audit("pause controls", cc)
	game._pause_controls(false)
	await frames(4)
	# The dimmer behind it still has to cover the whole screen.
	var vp := get_viewport().get_visible_rect().size
	for c in game.pause_menu.get_children():
		if c is ColorRect:
			check((c as ColorRect).size == vp,
				"and the dimmer behind it still covers the screen (%s)" % (c as ColorRect).size)
	game._unpause()

	print("[MENU] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
