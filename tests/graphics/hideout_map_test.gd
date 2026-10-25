extends Node
## The hideout is a room you walk around, not a screen. Three stations stand on
## its floor — the weapon rack, the counter and the gate — and each answers to
## the interact key when the player is standing at it. The weapon's graph is not
## one of them: TAB opens it from wherever the player stands.
##
## What this holds to: a station only answers from close enough, opening one
## puts its panel up and holds the player still, the panel is the old screen's
## own column (so the lists and their buttons are all still there), the gate
## refuses to open until there is a kit to carry through it, and buying a part
## at the counter costs scrap and puts the part in the stash.
##
## And that the names on the signs are legible, which is a question about how
## they are drawn: world text goes into the pixel buffer at the buffer's own
## resolution (`PixelCamera.draw_text`), never at world size to be shrunk into
## it. Shrunk, it arrives blended — soft grey edges where a pixel face has none
## — and Hangul, whose face stands twice as tall, arrived unreadable.
##
## Needs a real renderer: that check reads the frame back.

const GameScript := preload("res://app/game.gd")

var game: Node
var world: HideoutWorld
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

## A key down and up. Both codes are filled in: the bindings are read off the
## physical key, and the editor closes itself off the labelled one.
func tap_key(code: int) -> void:
	var d := InputEventKey.new()
	d.physical_keycode = code
	d.keycode = code
	d.pressed = true
	Input.parse_input_event(d)
	await frames(4)
	var u := InputEventKey.new()
	u.physical_keycode = code
	u.keycode = code
	u.pressed = false
	Input.parse_input_event(u)
	await frames(4)

## Every Control under `root`, scrollbars included.
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

## The shades lying on the view's layer — one under an open panel, none
## otherwise, and never two.
func shades(view: HideoutWorldView) -> Array:
	return view.layer.get_children().filter(func(c: Node) -> bool:
		return c is ColorRect and (c as ColorRect).color == UiKit.SHADE \
			and not c.is_queued_for_deletion())

func buttons_under(root: Node) -> Array:
	return controls_under(root).filter(func(c: Control) -> bool: return c is Button)

## Puts the player at a station's feet and lets a frame go by, so the station
## has recomputed whether anybody is standing at it.
func stand_at(id: String) -> void:
	world.player.global_position = (world.stations[id] as Station).global_position
	await frames(3)

## Holds a direction down for a fifth of a second and says how far across the
## floor the player got.
func walk(dir: String) -> float:
	var from := world.player.global_position.x
	Input.action_press(dir)
	for i in 12:
		await get_tree().physics_frame
	Input.action_release(dir)
	await get_tree().physics_frame
	return absf(world.player.global_position.x - from)

## How the ink on the plates meets their ground. A glyph drawn at the buffer's
## own resolution puts down the ink colour and nothing else; one shrunk into the
## buffer leaves a fringe of everything in between. So this counts both, inside
## each plate — and only there: the wall the plates hang on has colours of its
## own, and some of them lie between a plate's ground and its ink.
func sign_ink() -> void:
	# A frame drawn from here on. A covered window on macOS draws nothing, and
	# a frame waited for there never comes, so it is made to draw.
	var drawn := [false]
	RenderingServer.frame_post_draw.connect(func() -> void: drawn[0] = true, CONNECT_ONE_SHOT)
	var waited := 0.0
	while not drawn[0] and waited < 2.0:
		await get_tree().process_frame
		if not DisplayServer.window_can_draw():
			RenderingServer.force_draw(false)
		waited += get_process_delta_time()
	var im := get_viewport().get_texture().get_image()
	var view := Views.of(world) as HideoutWorldView
	var onto := get_viewport().get_final_transform() * get_viewport().get_canvas_transform() \
		* view.global_transform
	var ground := Style.HIDEOUT_PLATE
	var inked := 0
	var blended := 0
	var grounded := 0
	for id in world.stations:
		# In from the frame, which is drawn in the ink's own colour.
		var plate: Rect2 = (onto * view._plate(world.stations[id] as Station)).grow(-6.0)
		for y in range(int(plate.position.y), int(plate.end.y)):
			for x in range(int(plate.position.x), int(plate.end.x)):
				var c := im.get_pixel(x, y)
				# Near, not equal: the frame comes back as 8-bit colour, and a
				# ground of 0.06 is 15/255 by the time it is read.
				if _near(c, ground):
					grounded += 1
					continue
				for ink in [Style.HIDEOUT_SIGN, Style.HIDEOUT_SIGN_LIT]:
					var t := mix_of(c, ground, ink)
					if t > 0.9:
						inked += 1
					elif t > 0.15:
						blended += 1
	check(grounded > 2000, "the plates are where the view says they are (%d pixels of their ground)" % grounded)
	check(inked > 200, "the plates carry names at all (%d pixels of ink)" % inked)
	check(blended * 20 < inked,
		"and every one of them is ink or ground, never the wash in between (%d blended of %d)"
			% [blended, inked])

## Two colours the same to the eye, and to 8-bit colour.
func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01

## How far along `ground` → `ink` the colour `c` sits, or 0 if it is not on that
## line at all. What a pixel of a glyph drawn straight into the buffer answers is
## 1; what the filter leaves behind on the way down answers somewhere in between.
func mix_of(c: Color, ground: Color, ink: Color) -> float:
	var d := Vector3(ink.r - ground.r, ink.g - ground.g, ink.b - ground.b)
	var v := Vector3(c.r - ground.r, c.g - ground.g, c.b - ground.b)
	var t := v.dot(d) / d.dot(d)
	if t < 0.0 or t > 1.05:
		return 0.0
	return 0.0 if (v - d * t).length() > 0.03 else t

func _ready() -> void:
	GameState.reset_profile()
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(6)
	game.goto_hideout()
	await frames(24)
	world = game.current
	check(world != null and game.state == GameScript.State.HIDEOUT,
		"the hideout is a world, not a screen (%s)" % ("null" if world == null else world.get_class()))
	check(world.room != null and world.player != null, "with a room and somebody standing in it")
	check(world.stations.size() == 4, "and four stations on its floor (%d)" % world.stations.size())
	check(not world.stations.has("bench"), "with no workbench among them: TAB is the way onto the board")

	# --- a station only answers from close enough ----------------------------
	var rack: Station = world.stations["weapons"]
	world.player.global_position = rack.global_position + Vector2(600.0, 0.0)
	await frames(3)
	check(not rack.near, "a station across the room is out of reach")
	rack.interact()
	await frames(2)
	check(world.open_panel == "", "and pressing it from there does nothing")
	await stand_at("weapons")
	check(rack.near, "walking up to it puts it in reach")

	# --- opening one ---------------------------------------------------------
	rack.interact()
	await frames(8)
	check(world.open_panel == "weapons", "and a press opens its panel")
	check(world.player.controls_locked(),
		"which holds the player still while they read it")
	var walked := await walk("move_right")
	check(walked < 1.0, "and the movement keys do not walk them off (%.0f px)" % walked)
	# The pointer is the system's while a panel is up, so it is the real one
	# that is moved here, from one side of the screen to the other.
	var aim_was: Vector2 = world.player.aim
	for x in [8.0, 1270.0]:
		get_viewport().warp_mouse(Vector2(x, 360.0))
		await frames(3)
	check(Pointer.point.x > 1000.0 and world.player.aim.is_equal_approx(aim_was),
		"nor does the pointer, crossing the panel, turn their weapon (%s, was %s)"
			% [str(world.player.aim), str(aim_was)])
	var view = Views.of(world)
	check(view != null and view.panel != null, "the panel is on screen")
	# The room goes dark behind it, the way the game does behind the pause menu.
	var shade: Array = shades(view)
	var screen := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	check(shade.size() == 1 and (shade[0] as ColorRect).get_global_rect().encloses(screen),
		"the room goes dark behind it, all of the screen (%d shades)" % shade.size())
	check(shade.size() == 1 and view.hud.get_index() < shade[0].get_index()
			and shade[0].get_index() < view.panel.get_index(),
		"over the readout and under the panel")
	var picked := ""
	for b: Button in buttons_under(view.panel):
		if b.text.findn(Weapons.name_for("GUN")) >= 0 and not b.disabled:
			picked = "GUN"
			b.emit_signal("pressed")
			break
	check(picked == "GUN", "the rack lists the weapons the vault holds")
	await frames(6)
	check(world.weapon_id == "GUN",
		"picking one is what the room carries to the gate (%s)" % world.weapon_id)

	# The way out is in the corner, where the pause menu's pages keep theirs.
	# Pressing it is walking away from the station: the same close the key does.
	var arrow: Button = null
	for b: Button in buttons_under(view.panel):
		if b.text == Loc.t("hideout.station.arrow"):
			arrow = b
			break
	check(arrow != null, "a back arrow stands in the panel's top-left corner")
	if arrow != null:
		arrow.emit_signal("pressed")
	else:
		world.close_panel()
	await frames(6)
	check(world.open_panel == "" and not world.player.controls_locked(),
		"and pressing it gives the room and the keys back")
	check(shades(view).is_empty(), "and the dark goes with the panel")
	walked = await walk("move_right")
	check(walked > 5.0, "so the same keys walk again (%.0f px)" % walked)
	# And the game has the pointer back, so moving it turns the weapon again.
	Pointer.point = Vector2(8.0, 360.0)
	await frames(2)
	var aimed_left := world.player.aim.x
	Pointer.point = Vector2(1270.0, 360.0)
	await frames(2)
	check(aimed_left < 0.0 and world.player.aim.x > 0.0,
		"and the pointer turns the weapon again (%.2f, then %.2f)" % [aimed_left, world.player.aim.x])

	# --- the counter sells parts --------------------------------------------
	await stand_at("shop")
	(world.stations["shop"] as Station).interact()
	await frames(8)
	check(world.open_panel == "shop", "the counter opens the same way")
	walked = await walk("move_left")
	check(walked < 1.0, "and holds the player the same way (%.0f px)" % walked)
	var scrap_was: int = GameState.scrap
	var held_was: int = GameState.component_count("PIERCE", GameState.stash)
	GameState.scrap = 500
	world.refresh_panel()
	await frames(8)
	check(shades(Views.of(world)).size() == 1, "a panel built again lies on one shade, not two")
	var bought := false
	for b: Button in buttons_under(Views.of(world).panel):
		if b.text == Loc.t("hideout.shop.price", [GameState.shop_price("PIERCE")]) and not b.disabled:
			# Several parts share a price; the one wanted is the one whose row
			# is PIERCE's, so this walks back up to the row to be sure.
			var row := b.get_parent()
			var named := false
			for c in row.get_children():
				if c is Label and (c as Label).text.findn(Components.name_for("PIERCE")) >= 0:
					named = true
			if not named:
				continue
			b.emit_signal("pressed")
			bought = true
			break
	await frames(6)
	check(bought, "the counter offers a part for scrap")
	check(GameState.component_count("PIERCE", GameState.stash) == held_was + 1,
		"buying one puts it in the stash (%d)" % GameState.component_count("PIERCE", GameState.stash))
	check(GameState.scrap == 500 - GameState.shop_price("PIERCE"),
		"and takes the scrap for it (%d)" % GameState.scrap)
	check(GameState.shop_price("PIERCE") > 5 * int(GameState.FACILITY_INFO["scrapper"]["max"]),
		"a part costs more than breaking one down ever pays back")
	GameState.scrap = scrap_was
	world.close_panel()
	await frames(6)

	# --- the words on the signs ----------------------------------------------
	# In Korean, where it shows: Silkscreen at twice its size shrinks back to
	# exactly itself, so English survived being drawn the wrong way and 둥근모꼴
	# did not.
	var was_language := Loc.language
	Loc.set_language("kor")
	await frames(10)
	await sign_ink()
	Loc.set_language(was_language)
	await frames(6)

	# --- the gate ------------------------------------------------------------
	# A weapon always has its graph, so the gate is open for any weapon the
	# vault still has, and shut — saying why — for one it has lost.
	var gate: Station = world.stations["gate"]
	await stand_at("gate")
	world.set_weapon("SWORD")
	await frames(4)
	check(gate.open, "the gate is open: a weapon on the rack always has its graph to carry")
	# Appended, not assigned: a GDScript lambda captures a local by value, so
	# `deployed = [...]` inside one is a write nobody out here would ever see.
	var deployed: Array = []
	world.deploy_requested.connect(func(w: String) -> void: deployed.append(w))
	GameState.owned_weapons.erase("SWORD")
	world.set_weapon("SWORD")
	await frames(4)
	check(not gate.open and gate.closed_reason == Loc.t("hideout.gate.no_weapon"),
		"a weapon the vault has lost shuts it, and it says why")
	gate.interact()
	await frames(4)
	check(deployed.is_empty(), "a shut gate does not answer")
	GameState.owned_weapons.append("SWORD")
	world.set_weapon("GUN")
	await frames(4)
	check(gate.open, "a weapon the vault has opens it")

	# --- the kit, on the player and on the key -------------------------------
	# The readout over the room reads the player rather than the profile, so what
	# the gate would carry has to be on them before it can be shown: the graph
	# on the weapon the rack is on, put back by whatever changed it.
	var hud: Hud = Views.of(world).hud
	check(world.player.runner != null and world.player.runner.board == world.armed_board()
			and world.player.weapon_id == "GUN",
		"the player standing in the room carries the graph the gate would carry")
	check(hud != null and hud.player == world.player,
		"and the readout over the room is reading them")

	# The key that opens assembly in a raid opens it here, over that same graph.
	# The second press is the editor closing itself, and this must not see it
	# and open the editor straight back up.
	await tap_key(KEY_TAB)
	check(game.editor != null and is_instance_valid(game.editor),
		"TAB opens assembly over the room")
	if game.editor != null and is_instance_valid(game.editor):
		check(game.editor.current_board() == world.armed_board(),
			"on the weapon's own graph")
	check(world.player.controls_locked(), "and holds the player still under it, as a panel does")
	walked = await walk("move_right")
	check(walked < 1.0, "so the movement keys do nothing while it is up (%.0f px)" % walked)
	await tap_key(KEY_TAB)
	check(game.editor == null, "and a second press puts it away")
	walked = await walk("move_right")
	check(not world.player.controls_locked() and walked > 5.0,
		"giving the keys back (%.0f px)" % walked)

	# Opened by key from the far end of the room, by the gate, with no panel
	# between; ESC shuts it as well as TAB, and hands back to the room.
	await stand_at("gate")
	await tap_key(KEY_TAB)
	check(game.editor != null and is_instance_valid(game.editor) and world.open_panel == "",
		"TAB opens the weapon's graph by the gate too, with no panel between")
	walked = await walk("move_right")
	check(walked < 1.0, "and holds the player under it (%.0f px)" % walked)
	await tap_key(KEY_ESCAPE)
	check(game.editor == null, "shutting the board goes back to the room")
	walked = await walk("move_right")
	check(not world.player.controls_locked() and walked > 5.0,
		"where the player walks again (%.0f px)" % walked)

	await stand_at("gate")
	gate.interact()
	await frames(4)
	check(deployed.size() == 1 and String(deployed[0]) == "GUN",
		"and walking through deploys the weapon and what is on it (%s)" % str(deployed))

	print("[HIDE] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
