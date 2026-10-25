extends Node
## Frames of the light, for looking at: the bench as it is drawn with nothing
## lit; as it ships, with a bolt of fire flying through it and a blast of ice
## going off; with a lamp on its floor — the picture, the normals the lamp
## reads, and the shadows it throws — and then the same room gone dark,
## with two lamps in it and a bolt through the dark. And a raid: the room it
## starts in, lit by its way out, and a room with monsters in it and a bolt
## among them.
##
## The normals are drawn the way a normal map is: grey for a face turned to
## the eye, redder the more it faces right and greener the more it faces
## down, and blue where something gives its own light. The shadows are the
## masks as they are: a colour to a lamp.
##
## Needs a real renderer — `--headless` draws into a dummy and saves black.
## Writes to `user://shots` unless SHOTS_DIR names somewhere else. With
## HIDE_WINDOW set the window is put away as soon as it opens, and every
## frame is drawn by hand.

const GameScript := preload("res://app/game.gd")
var dir: String = "user://shots"
var pixels: PixelCamera

## One frame. A window that is put away, or that something covers, is not
## drawn at all, so while that lasts the frame is drawn here instead.
func tick() -> void:
	await get_tree().process_frame
	if not DisplayServer.window_can_draw() or OS.has_environment("HIDE_WINDOW"):
		RenderingServer.force_draw(false)

func frames(n: int) -> void:
	for i in n:
		await tick()

func wait(secs: float) -> void:
	var t := 0.0
	while t < secs:
		await tick()
		t += get_process_delta_time()

func save(img: Image, shot_name: String, times: int = 1) -> void:
	if times > 1:
		img.resize(img.get_width() * times, img.get_height() * times, Image.INTERPOLATE_NEAREST)
	var err := img.save_png(dir.path_join(shot_name + ".png"))
	print("[SHOT] ", shot_name, " -> ", dir, "" if err == OK else " FAILED (%d)" % err)

## The screen, or `crop` of it three times the size.
func shot(shot_name: String, crop: Rect2i = Rect2i()) -> void:
	await tick()
	var img := get_viewport().get_texture().get_image()
	if crop.size != Vector2i.ZERO:
		img = img.get_region(crop)
		save(img, shot_name, 3)
	else:
		save(img, shot_name)

## The normals, as a normal map is drawn, twice the size.
func normals_shot(shot_name: String) -> void:
	await tick()
	var buf := pixels.lighting.normals().get_image()
	var out := Image.create_empty(buf.get_width(), buf.get_height(), false, Image.FORMAT_RGBA8)
	for y in buf.get_height():
		for x in buf.get_width():
			var c := buf.get_pixel(x, y)
			var facing := Vector2(c.r, c.g) / Lighting.RELIEF
			if facing.length() < 0.02:
				facing = Vector2.ZERO
			var glow := clampf((c.b - 1.0) / (Lighting.RELIEF - 1.0), 0.0, 1.0)
			out.set_pixel(x, y, Color(0.5 + facing.x * 0.5, 0.5 + facing.y * 0.5, 0.5 + glow * 0.5))
	save(out, shot_name, 2)

## The shadows' first mask, as it is, twice the size.
func shadows_shot(shot_name: String) -> void:
	await tick()
	var img := pixels.lighting.shadows(0).get_image()
	img.convert(Image.FORMAT_RGB8)
	save(img, shot_name, 2)

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	if OS.has_environment("HIDE_WINDOW"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	if OS.has_environment("SHOTS_DIR"):
		dir = OS.get_environment("SHOTS_DIR")
	DirAccess.make_dir_recursive_absolute(dir)
	GameState.reset_profile()
	seed(7)
	var game := Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(6)
	game.goto_sandbox()
	await frames(20)
	var sb: Sandbox = game.current
	pixels = (Views.of(sb) as SandboxView).pixels
	var lighting := pixels.lighting
	await shot("60_unlit")
	print("[SHOT] with nothing lit the passes are %s" % ("running" if lighting.working() else "not run"))
	var middle := Vector2(Room.W, Room.H) * Room.CELL * 0.5
	sb.player.global_position = middle + Vector2(-70.0, 40.0)

	# The room as it ships: as light as it ever was, and lit further only by
	# what is thrown through it. A bolt of fire going right over the floor,
	# and then a blast of ice beside the player.
	var burning: Array[String] = ["FIRE"]
	var fire := Payload.new()
	fire.elements = burning
	fire.speed = 0.45
	fire.range_px = 4000.0
	Attacks._projectile(fire, middle + Vector2(-260.0, 0.0), Vector2.RIGHT, 0, null, sb.room, false)
	await wait(0.55)
	await shot("61_bolt")
	await shadows_shot("61_bolt_shadows")
	Attacks.clear_in_flight()
	await frames(2)
	var freezing: Array[String] = ["ICE"]
	var ice := Payload.new()
	ice.elements = freezing
	Attacks._go_off(ice, middle + Vector2(40.0, 30.0), 60.0, 0, null, sb.room)
	await frames(5)
	await shot("62_blast")
	await wait(1.0)

	# A lamp hung low over the floor, between the player and a monster big
	# enough to see the light on.
	sb.spawn_monster("WARDEN")
	for c in sb.get_children():
		if c is Enemy and (c as Enemy).kind == "WARDEN":
			(c as Enemy).global_position = middle + Vector2(96.0, 0.0)
	var lamp := Lamp.of(Color(1.0, 0.8, 0.5), 240.0, 2.2)
	lamp.volume = 0.05
	lamp.position = middle + Vector2(0.0, -40.0)
	sb.room.add_child(lamp)
	await wait(0.6)
	await shot("63_lamp")
	await normals_shot("64_normals")
	await shadows_shot("65_shadows")
	print("[SHOT] lamps on the screen %d, throwing shadows %d" % [lighting.lamps_lit, lighting.lamps_shadowed])

	# The same room with the light taken out of it, and a second lamp, low and
	# cold, off to the right — and a bolt through the dark.
	lighting.ambient = Color(0.28, 0.3, 0.42)
	var cold := Lamp.of(Color(0.4, 0.7, 1.0), 220.0, 2.4)
	cold.volume = 0.06
	cold.position = middle + Vector2(330.0, 20.0)
	sb.room.add_child(cold)
	await wait(0.2)
	await shot("66_dark")
	await shot("66_dark_close", Rect2i(Vector2i(int(middle.x) - 150, int(middle.y) - 100), Vector2i(420, 200)))
	Attacks._projectile(fire, middle + Vector2(-420.0, 0.0), Vector2.RIGHT, 0, null, sb.room, false)
	await wait(0.5)
	await shot("67_dark_bolt")

	# A raid, as it ships. The room it starts in has a way out, which is a
	# lamp; and then a room with monsters in it, and a bolt among them.
	game._deploy("SWORD")
	await frames(20)
	var raid: Raid = game.current
	raid.player.invuln = 999.0
	pixels = (Views.of(raid) as RaidView).pixels
	await wait(0.5)
	await shot("68_way_out")
	await normals_shot("68_way_out_normals")
	for c in raid.map.rooms.keys():
		if String(raid.map.rooms[c].get("kind", "")) == "normal":
			raid.go_to(c)
			break
	await wait(0.6)
	var from := raid.player.global_position + Vector2(40.0, -30.0)
	Attacks._projectile(fire, from, Vector2.RIGHT, 0, raid.player, raid.room, false)
	await wait(0.45)
	await shot("69_raid_bolt")
	await shadows_shot("69_raid_bolt_shadows")
	get_tree().quit()
