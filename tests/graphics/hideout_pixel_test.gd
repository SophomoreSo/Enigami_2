extends Node
## The hideout's panels are built in UiKit's pixel look and everything on them
## fits, with the profile at its widest: every facility maxed (the longest
## numbers), a full stash, a skill with a name too long for its row, and each
## weapon selected in turn. Checked on the built tree — every piece of text is
## the pixel face at a multiple of its native 8px, every box is square,
## unsmoothed and evenly bordered, the panel stays on the screen, and no text is
## wider than what holds it unless it is allowed to wrap or be cut short.
##
## The hideout is a room now, so these are the panels its stations open — the
## rack and the counter, one column each. They are columns the old screen
## showed side by side, which is why one test still covers all of them.
##
## And where each of those sits: a panel is a pinned title, the rows and the way
## out, and only the rows scroll. Scrolled whole, as it was, the counter's list
## carried its own title and the way back to the room clean off the screen — so
## every panel here is scrolled to its end and both pinned pieces are looked for
## on the screen afterwards.

const GameScript := preload("res://app/game.gd")
const BOXES := ["panel", "normal", "hover", "pressed", "focus", "disabled",
	"scroll", "scroll_focus", "grabber", "grabber_highlight", "grabber_pressed"]

var game: Node
var world: HideoutWorld
## The column on screen: whichever station was opened last.
var hideout: Hideout
## What the title of the panel around it says, which is the station's name.
var heading := ""
var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[HIDE] PASS ", what)
	else:
		fails += 1
		push_error("HIDE FAIL: " + what)

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

## Opens a station and hands back the column inside its panel. That column is a
## `Hideout` built with `section` set — the same object the old screen was, with
## two of its three columns left out — so everything below reads it the same way
## it always did.
func open_section(id: String) -> Hideout:
	world.close_panel()
	await frames(2)
	heading = Loc.t("hideout.station.%s" % id)
	world.open_station(id)
	await frames(6)
	var view = Views.of(world)
	for c in controls_under(view.panel):
		if c is Hideout:
			return c
	return null

func label_with(prefix: String) -> Label:
	for c in controls_under(hideout):
		if c is Label and (c as Label).text.begins_with(prefix):
			return c
	return null

func button_with(prefix: String) -> Button:
	for c in controls_under(hideout):
		if c is Button and (c as Button).text.begins_with(prefix):
			return c
	return null

## The one thing on the panel — column, frame or either end of it — whose text
## is exactly `text`.
func text_in(root: Node, text: String) -> Control:
	for c in controls_under(root):
		if (c is Label and (c as Label).text == text) or (c is Button and (c as Button).text == text):
			return c
	return null

## The pixel look, and the fit, over the panel on screen right now: the column
## and the frame around it both, since the title, the status line and the way
## out are the frame's and are as much a part of the panel as the rows are.
## `least` and `boxes_least` are how much text and how many styled boxes that
## panel is expected to carry — the rack is a handful of weapons and the line
## that says what one is, the counter is two long lists — so a panel that
## quietly came up empty is still a failure.
func audit(what: String, least: int, boxes_least: int) -> void:
	await frames(4)
	var all := controls_under(Views.of(world).panel)
	var plain: Array = []
	var soft: Array = []
	var wide: Array = []
	var texts := 0
	var boxes := 0
	for c in all:
		if c is Label or c is Button:
			texts += 1
			var size: int = c.get_theme_font_size("font_size")
			if c.get_theme_font("font") != UiKit.PIXEL_FONT or size < UiKit.PIXEL_TEXT or size % 8 != 0:
				plain.append("%s '%s' @%d" % [c.get_class(), c.text, size])
			# A label that wraps, or a control that cuts its text short, is meant
			# to be narrower than its text. Everything else has to fit.
			var may_shrink: bool = (c is Label and ((c as Label).autowrap_mode != TextServer.AUTOWRAP_OFF
				or (c as Label).clip_text)) or (c is Button and (c as Button).clip_text)
			if not may_shrink and c.get_combined_minimum_size().x > c.size.x + 0.5:
				wide.append("%s '%s' (%.0f of %.0f)" % [c.get_class(), c.text,
					c.get_combined_minimum_size().x, c.size.x])
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
				soft.append("%s.%s (aa=%s radius=%d border=%d)" % [c.get_class(), name,
					sb.anti_aliasing, sb.get_corner_radius(CORNER_TOP_LEFT), sb.get_border_width(SIDE_LEFT)])
	check(texts > least and plain.is_empty(),
		"%s: every text is the pixel face at a multiple of 8px (%d checked, off: %s)" % [what, texts, str(plain)])
	check(boxes > boxes_least and soft.is_empty(),
		"%s: every box is square, unsmoothed and evenly bordered (%d checked, off: %s)" % [what, boxes, str(soft)])
	check(wide.is_empty(), "%s: every text fits what holds it (too wide: %s)" % [what, str(wide)])

	# The column has to fit the frame it was given, and the frame has to fit the
	# screen. A column longer than the frame is not a failure by itself — the
	# frame scrolls — but one wider than it is, since nothing scrolls sideways.
	var vp := get_viewport().get_visible_rect().size
	check(hideout.get_combined_minimum_size().x <= hideout.size.x + 0.5,
		"%s: the column fits the width of its panel (%.0f of %.0f)"
			% [what, hideout.get_combined_minimum_size().x, hideout.size.x])
	var panel := Views.of(world).panel as UiKit.ScreenFrame
	var frame := panel.get_global_rect()
	check(frame.position.x >= -0.5 and frame.position.y >= -0.5
		and frame.end.x <= vp.x + 0.5 and frame.end.y <= vp.y + 0.5,
		"%s: the panel stays on the screen (%s in %s)" % [what, frame, vp])

	# The rows are the one part of the panel that scrolls, and the title, the
	# status line and the way out are pinned around them. Scrolled to the end is
	# where a panel that scrolled whole lost the first and the last of those:
	# both were off the screen, with nothing on it to say where they had gone.
	var body := panel.body
	check(body != null and body.is_ancestor_of(hideout),
		"%s: the rows inside the panel are what scrolls" % what)
	if body == null:
		return
	body.scroll_vertical = 1000000
	await frames(3)
	var screen := Rect2(Vector2.ZERO, vp)
	for named in [["the title", text_in(panel, heading)],
			["the way out", text_in(panel, Loc.t("hideout.station.back"))]]:
		var c: Control = named[1]
		check(c != null and screen.encloses(c.get_global_rect()),
			"%s: %s stays on the screen with the list scrolled to the end (%s)"
				% [what, named[0], "missing" if c == null else str(c.get_global_rect())])
	# And what scrolled out of the top is all still reachable at the bottom.
	var reach := float(body.scroll_vertical) + body.size.y
	var wanted := hideout.get_combined_minimum_size().y
	check(reach >= wanted - 1.0,
		"%s: the list scrolls to its last row (reaches %.0f of %.0f)" % [what, reach, wanted])
	body.scroll_vertical = 0
	await frames(2)

func _ready() -> void:
	GameState.reset_profile()
	# A new profile keeps whatever facility levels the last one had — resetting
	# does not touch them — so this puts back what it raises, or every run after
	# it starts on a maxed hideout.
	var facilities_before: Dictionary = GameState.facilities.duplicate()
	# The widest profile there is: every facility maxed, so the numbers are the
	# longest they go, and a stash with every part in it at a two-digit count.
	for key in GameState.FACILITY_INFO:
		GameState.facilities[key] = int(GameState.FACILITY_INFO[key]["max"])
	for id in Components.loot_pool():
		GameState.stash[id] = 19
	GameState.scrap = 99999
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(6)
	game.goto_hideout()
	await frames(14)
	world = game.current

	# --- the rack, on every weapon in turn -----------------------------------
	hideout = await open_section("weapons")
	check(hideout != null, "the rack opens a column of its own")
	for id in Weapons.ids():
		hideout.weapon_id = id
		hideout.rebuild()
		await audit(Weapons.name_for(id), 6, 12)

	# --- the counter, which carries the longest lists ------------------------
	world.set_weapon("SWORD")
	hideout = await open_section("shop")
	await audit("the counter", 40, 40)

	# --- the forge, and the rebuild it triggers ------------------------------
	# The forge is the counter's, like everything else that costs scrap. The
	# panel is rebuilt under it, so this is also the check that a rebuild in the
	# middle of a press leaves a panel standing.
	hideout = await open_section("shop")
	var before := int(GameState.stash.get("SLASH", 0))
	hideout._forge()
	await frames(4)
	check(int(GameState.stash.get("SLASH", 0)) != before or GameState.scrap < 99999,
		"the forge really spends the parts")
	await audit("the counter after the forge", 40, 40)

	var dir := OS.get_environment("SHOTS_DIR") if OS.has_environment("SHOTS_DIR") else "user://shots"
	DirAccess.make_dir_recursive_absolute(dir)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("pixel_hideout.png"))

	GameState.facilities = facilities_before
	GameState.save_game()
	print("[HIDE] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
