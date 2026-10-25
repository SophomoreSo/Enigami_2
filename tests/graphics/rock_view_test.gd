extends Node
## The rock, drawn (`Weapons.is_thrown`): a stone and not the pack's morning
## star. The tile is drawn in code (`Style.DRAWN_TILES`) and handed out like an
## atlas tile; it is held the right way up whichever way it is aimed, and the
## hand is empty once it is thrown; in the air it is the rock that flies,
## turning over a quarter at a time; on the floor it lies under a mark that
## says where it is; and the HUD says it is out.
##
## Needs a real renderer: what shows is read off the frame.

const GameScript := preload("res://app/game.gd")

var game: Node
var world: HideoutWorld
var player: Player
var view: PlayerView
var bot: ComputerHands
var fails := 0
var _drawn := false

func check(ok: bool, what: String) -> void:
	if ok:
		print("[ROCKVIEW] PASS ", what)
	else:
		fails += 1
		push_error("ROCKVIEW FAIL: " + what)

## A frame, with the window kept drawing: a covered one on macOS draws nothing.
func tick() -> void:
	await get_tree().process_frame
	if not DisplayServer.window_can_draw():
		RenderingServer.force_draw(false)

func wait(secs: float) -> void:
	var t := 0.0
	while t < secs:
		await tick()
		t += get_process_delta_time()

func until(cond: Callable, most: float) -> bool:
	var t := 0.0
	while t < most:
		if cond.call():
			return true
		await tick()
		t += get_process_delta_time()
	return bool(cond.call())

## The frame on screen, once one has been drawn.
func frame() -> Image:
	_drawn = false
	var t := 0.0
	while not _drawn and t < 2.0:
		await tick()
		t += get_process_delta_time()
	return get_viewport().get_texture().get_image()

## The frame on screen with every light in the world put out for it: the
## colours as they are drawn, before the lamps and shining things add theirs
## (`Lighting`). What is checked against it is a palette, or what is drawn
## where, and not how any of it is lit.
func unlit_frame() -> Image:
	var out: Array = []
	for group: StringName in [Shine.GROUP, Lamp.GROUP]:
		for n in get_tree().get_nodes_in_group(group):
			n.remove_from_group(group)
			out.append([n, group])
	await frame()
	var im := await frame()
	for o: Array in out:
		if is_instance_valid(o[0]):
			(o[0] as Node).add_to_group(o[1])
	return im

## Where a point of the world lands on the screen.
func on_screen(at: Vector2) -> Vector2i:
	return Vector2i((get_viewport().get_final_transform() * get_viewport().get_canvas_transform() * at).round())

## How many pixels within `reach` screen pixels of `at` are one of the rock's
## own colours — its lit top, which nothing else in the room is painted in.
func rock_pixels(im: Image, at: Vector2i, reach: int) -> int:
	var inks: Dictionary = Style.DRAWN_TILES["rock"]["inks"]
	var want: Array = [inks["h"], inks["l"]]
	var n := 0
	for y in range(at.y - reach, at.y + reach + 1):
		for x in range(at.x - reach, at.x + reach + 1):
			if x < 0 or y < 0 or x >= im.get_width() or y >= im.get_height():
				continue
			var c := im.get_pixel(x, y)
			for w: Color in want:
				if absf(c.r - w.r) < 0.02 and absf(c.g - w.g) < 0.02 and absf(c.b - w.b) < 0.02:
					n += 1
					break
	return n

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	RenderingServer.frame_post_draw.connect(func() -> void: _drawn = true)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	GameState.reset_profile()

	_the_tile()
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await wait(0.2)
	game.goto_hideout()
	world = game.current
	await until(func() -> bool: return Views.of(world.player) != null, 2.0)
	player = world.player
	view = Views.of(player) as PlayerView
	bot = ComputerHands.new()
	player.input.add(bot)
	player.global_position.x = 300.0
	await wait(0.4)

	await _held()
	await _thrown()
	await _lying()

	print("[ROCKVIEW] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

func _the_tile() -> void:
	check(Style.weapon_art("ROCK") == "rock" and not Sprites.has_tile("rock"),
		"the rock is drawn with a tile of the game's own, not one of the pack's (%s)" % Style.weapon_art("ROCK"))
	var t := Sprites.texture("rock")
	check(t != null and t.get_size() == Vector2(10, 8), "a stone ten pixels by eight (%s)" % str(t.get_size() if t != null else Vector2.ZERO))
	if t == null:
		return
	var im := t.get_image()
	check(im.get_pixel(0, 0).a == 0.0 and im.get_pixel(9, 7).a == 0.0 and im.get_pixel(4, 4).a == 1.0,
		"rounded off at its corners, solid in the middle")
	check(Sprites.texture("rock") == t, "made once, and handed out again after")

func _held() -> void:
	var tilts: Array = []
	for aim: Vector2 in [Vector2(260, -120), Vector2(-260, 40), Vector2(0, -300)]:
		bot.point_at(player.global_position + aim)
		await wait(0.15)
		tilts.append(view.weapon_sprite.rotation)
	check(view.weapon_sprite.texture == Sprites.texture("rock") and view.weapon_sprite.self_modulate.a > 0.5,
		"the rock is in the hand")
	check(tilts.all(func(r: float) -> bool: return is_zero_approx(r)),
		"held the right way up however it is aimed (%s)" % str(tilts))
	var im := await unlit_frame()
	var hand := on_screen(view.weapon_sprite.global_position)
	check(rock_pixels(im, hand, 14) >= 6, "and drawn there (%d of its pixels)" % rock_pixels(im, hand, 14))

func _thrown() -> void:
	bot.point_at(player.global_position + Vector2(300, -200))
	await wait(0.1)
	# The rock flies as fast and as flat as a shuriken, and on a slow screen
	# (CI's) it was on the floor before its picture was read. The clock run at a
	# quarter for the throw keeps it in the air for as many frames again, however
	# few a second there are: this is about how it is drawn, not how fast it goes.
	# Held there by hand, with TimeCtl, which would ease it back, stood down:
	# its own slowing would draw the room dilated as well.
	TimeCtl.set_process(false)
	Engine.time_scale = 0.25
	bot.attack = true
	await wait(0.06)
	bot.attack = false
	await until(func() -> bool: return _rock_away() != null, 2.0)
	var flying := _rock_away()
	check(flying != null, "(a rock in the air)")
	if flying == null:
		_clock_back()
		return
	# How far it has turned over, a quarter at a time, every frame from here
	# while it flies — through the frames the picture below is read in, too.
	# A slow screen has the rock on the floor a few frames after it is thrown,
	# and started only after that read, CI's saw it at one quarter twice.
	var turns: Array = []
	var pv: ProjectileView = Views.of(flying)
	var watch := func() -> void:
		if pv != null and is_instance_valid(pv):
			var q := fmod(absf(roundf(pv._spin / (PI * 0.5))), 4.0)
			if turns.is_empty() or turns.back() != q:
				turns.append(q)
	watch.call()
	get_tree().process_frame.connect(watch)
	var im := await unlit_frame()
	check(view.weapon_sprite.self_modulate.a == 0.0, "the hand is empty once it is thrown")
	var seen := rock_pixels(im, on_screen(flying.global_position), 14) if is_instance_valid(flying) else 0
	check(seen >= 6, "and it is the rock that flies (%d of its pixels)" % seen)
	await until(func() -> bool: return turns.size() >= 2 or pv == null or not is_instance_valid(pv), 0.25)
	get_tree().process_frame.disconnect(watch)
	_clock_back()
	# Two quarters seen is a rock turning over.
	check(turns.size() >= 2, "turning over as it goes, a quarter at a time (%s)" % str(turns))

## The clock as the game keeps it again, after the throw held it at a quarter.
func _clock_back() -> void:
	Engine.time_scale = 1.0
	TimeCtl.set_process(true)

## The rock in the air, once it is well out of the hand; or null.
func _rock_away() -> Projectile:
	for c in world.get_children():
		if c is Projectile and (c as Projectile).is_rock() \
				and (c as Projectile).global_position.distance_to(player.global_position) > 70.0:
			return c
	return null

## The rock lying still on the floor; or null.
func _rock_down() -> LooseRock:
	for r in get_tree().get_nodes_in_group("loose_rocks"):
		if (r as LooseRock).resting:
			return r
	return null

func _lying() -> void:
	await until(func() -> bool: return _rock_down() != null, 4.0)
	var r := _rock_down()
	check(r != null, "(a rock on the floor)")
	if r == null:
		return
	var im := await unlit_frame()
	var at := on_screen(r.global_position)
	check(rock_pixels(im, at, 14) >= 6, "lying on the floor, it is the rock (%d of its pixels)" % rock_pixels(im, at, 14))
	var mark := Style.weapon_color("ROCK")
	var lit := 0
	var over := on_screen(r.global_position + Vector2(0, -LooseRock.RADIUS - LooseRockView.MARK_LIFT))
	for y in range(over.y - 14, over.y + 14):
		for x in range(over.x - 12, over.x + 12):
			var c := im.get_pixel(x, y)
			if c.r > 0.5 and absf(c.r - c.b) > 0.15 and absf(c.r - mark.r) < 0.25 and absf(c.g - mark.g) < 0.25:
				lit += 1
	check(lit >= 4, "with a mark over it, in its colour, to find it by (%d pixels)" % lit)
	check(not player.holds("ROCK"), "(still out of the hand)")
