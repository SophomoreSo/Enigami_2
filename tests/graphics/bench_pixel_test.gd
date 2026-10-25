extends Node
## The bench's drawer is drawn in UiKit's pixel look: every PIXEL×PIXEL block of
## what it draws is one colour, its buttons are the pixel face, and what it
## draws fits — the damage readout under the HUD's corner, the drawer under
## that and clear of the lines along the bottom, every button inside it, and
## nothing but the tab left on the screen once it is in.
##
## The block check covers the drawn part and not the buttons, which are Controls
## and cannot meet it: Godot centres a Button's label inside its box, the pixel
## face is 21px tall, and no box height makes both the border and the baseline
## land on an even row. A Control-built screen is held to the other standard —
## the pixel face at a multiple of 8px, square unsmoothed boxes, as
## `settings_pixel_test` and `hideout_pixel_test` check — and a one-pixel offset
## between a letter and the box around it is not visible. What is drawn by hand
## has no such excuse, so it is held to the block.
##
## Needs a real renderer: the block check reads the frame back.

const GameScript := preload("res://app/game.gd")

var game: Node
var panel: SandboxPanel
var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[BENCH] PASS ", what)
	else:
		fails += 1
		push_error("BENCH FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

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

## Leaves only what the panel draws itself. The world behind it goes through the
## pixel camera, slid by whatever the real camera had left over — a pixel off
## this grid on purpose — and the buttons are Controls, which the block check
## does not cover (see the note at the top).
func isolate() -> Array:
	var hidden: Array = []
	var own := panel.get_parent()
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var layer := n as CanvasLayer
		if layer != own and layer.visible:
			layer.visible = false
			hidden.append(layer)
	for c in own.get_children():
		if c != panel and c is CanvasItem and (c as CanvasItem).visible:
			(c as CanvasItem).visible = false
			hidden.append(c)
	for c in panel.get_children():
		if c is CanvasItem and (c as CanvasItem).visible:
			(c as CanvasItem).visible = false
			hidden.append(c)
	return hidden

## Every PIXEL×PIXEL block of the frame is one colour: shrunk to a pixel a block
## and blown back up, it only comes back unchanged if no block held two.
func blocks(name: String) -> void:
	await frames(4)
	await RenderingServer.frame_post_draw
	var im := get_viewport().get_texture().get_image()
	var dir := OS.get_environment("SHOTS_DIR") if OS.has_environment("SHOTS_DIR") else "user://shots"
	DirAccess.make_dir_recursive_absolute(dir)
	im.save_png(dir.path_join("pixel_bench.png"))
	# The grid is Silkscreen's. A language written in a finer face is still
	# whole pixels, just smaller ones — 둥근모꼴's Hangul is a 16px body where
	# Silkscreen's Latin is an 8px body drawn at twice the size — so the shot is
	# still saved and looked at, and this grid is not claimed of it.
	# `tests/shared/loc_test` is what holds those languages to whole pixels.
	if UiKit.pixel_grid() < UiKit.PIXEL:
		print("[BENCH] skip the block check: %s is written on a %d-pixel grid, not %d"
			% [Loc.language, UiKit.pixel_grid(), UiKit.PIXEL])
		return
	var screen := Vector2i(get_viewport().get_visible_rect().size)
	if im.get_size() != screen:
		print("[BENCH] skip the block check: the frame is %s, not %s" % [im.get_size(), screen])
		return
	var s := UiKit.PIXEL
	var round_trip := im.duplicate() as Image
	round_trip.resize(screen.x / s, screen.y / s, Image.INTERPOLATE_NEAREST)
	round_trip.resize(screen.x, screen.y, Image.INTERPOLATE_NEAREST)
	var same := round_trip.get_data() == im.get_data()
	var first := Vector2i(-1, -1)
	if not same:
		for y in range(0, screen.y - s + 1, s):
			for x in range(0, screen.x - s + 1, s):
				var c := im.get_pixel(x, y)
				for dy in s:
					for dx in s:
						if im.get_pixel(x + dx, y + dy) != c and first.x < 0:
							first = Vector2i(x, y)
	check(same, "%s: every %d×%d block on screen is one colour (the first split at %s)"
		% [name, s, s, first])

func _ready() -> void:
	GameState.reset_profile()
	seed(9)
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(6)
	game.goto_sandbox()
	await frames(14)
	var sb: Sandbox = game.current
	panel = Views.of(sb).panel
	check(panel != null, "the bench builds its drawer")

	# A monster on the floor and the drawer all the way out, so the whole of it
	# is in the frame.
	sb.spawn_monster("CRAWLER")
	panel.set_out(true)
	await get_tree().create_timer(SandboxPanel.SLIDE + 0.15).timeout

	var hidden := isolate()
	await blocks("bench")
	restore(hidden)

	# --- the pixel look on the buttons --------------------------------------
	var plain: Array = []
	var soft: Array = []
	var texts := 0
	var boxes := 0
	for c in controls_under(panel):
		if c is Button or c is Label:
			texts += 1
			var size: int = c.get_theme_font_size("font_size")
			if c.get_theme_font("font") != UiKit.PIXEL_FONT or size < UiKit.PIXEL_TEXT or size % 8 != 0:
				plain.append("%s '%s' @%d" % [c.get_class(), c.text, size])
		for name in ["normal", "hover", "pressed", "focus", "disabled"]:
			if not c.has_theme_stylebox_override(name):
				continue
			var sb_box := c.get_theme_stylebox(name) as StyleBoxFlat
			if sb_box == null:
				continue
			boxes += 1
			var bad := sb_box.anti_aliasing
			for i in 4:
				if sb_box.get_border_width(i) % UiKit.PIXEL != 0 or sb_box.get_corner_radius(i) != 0:
					bad = true
			if bad:
				soft.append("%s.%s" % [c.get_class(), name])
	check(texts >= 12 and plain.is_empty(),
		"every button is the pixel face at a multiple of 8px (%d checked, off: %s)" % [texts, str(plain)])
	check(boxes > 20 and soft.is_empty(),
		"every box is square, unsmoothed and evenly bordered (%d checked, off: %s)" % [boxes, str(soft)])

	# --- the layout ---------------------------------------------------------
	var vp := get_viewport().get_visible_rect().size
	check(sb.player.runner != null and sb.player.runner.board == sb.board(),
		"the bench carries the weapon's graph")

	# Capitals stand 10 above their baseline and nothing descends.
	var hud_last := Hud.WEAPON_LINE
	var dps_top := SandboxPanel.DPS_AT.y - 10.0
	check(dps_top > hud_last,
		"the damage readout sits under the HUD's corner, reason line and all (%.0f under %.0f)"
			% [dps_top, hud_last])
	check(SandboxPanel.DPS_AT.y < SandboxPanel.TOP,
		"and over the drawer (%.0f over %.0f)" % [SandboxPanel.DPS_AT.y, SandboxPanel.TOP])
	var dps_wide := SandboxPanel.DPS_AT.x + PixelDraw.text_width("damage/sec (3s avg): 1234.5")
	check(dps_wide < vp.x * 0.5, "with room for four digits of damage (%.0f)" % dps_wide)

	var drawer := panel.drawer_rect()
	check(drawer.position == Vector2(0.0, SandboxPanel.TOP),
		"out, the drawer stands against the left edge (%s)" % str(drawer))
	check(drawer.end.y <= vp.y, "and ends on the screen (%.0f of %.0f)" % [drawer.end.y, vp.y])
	var grid := panel._grid.get_global_rect()
	check(drawer.encloses(grid), "every button is inside it (%s in %s)" % [str(grid), str(drawer)])
	var tab := panel.tab_rect()
	check(tab.position.x < drawer.end.x and tab.end.x <= vp.x,
		"the tab rides on its edge (%s)" % str(tab))

	panel.set_out(false)
	await get_tree().create_timer(SandboxPanel.SLIDE + 0.15).timeout
	drawer = panel.drawer_rect()
	tab = panel.tab_rect()
	check(drawer.end.x <= 0.0, "in, the drawer is off the left edge (%s)" % str(drawer))
	check(tab.position.x <= 0.0 and tab.end.x >= SandboxPanel.TAB.x - PixelDraw.PX,
		"and its tab is what is left on the screen (%s)" % str(tab))

	print("[BENCH] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

func restore(hidden: Array) -> void:
	for n in hidden:
		if is_instance_valid(n):
			n.visible = true
