extends Node2D
## The player is drawn the map way (`SkinnedCharacter`, `PixelMap`): frames
## painted in map colours, resolved through the skin by `skin_sprite.gdshader`.
##
## On the CPU: the character loads with every pose the body can take, every
## painted pixel of every frame names an opaque skin pixel, and the resolved
## frames are in the skin's colours. On screen: what the sprite puts there is
## the skin's colours and nothing else — no raw coordinates, no blending across
## a texel — and swapping the skin swaps every frame at once.
##
## Needs a real renderer: the screen part reads the frame back.

var fails := 0
var player: Player
var view: PlayerView
## Where the frame went, for looking at.
var dir: String = "user://shots"

func check(ok: bool, what: String) -> void:
	if ok:
		print("[SKIN] PASS ", what)
	else:
		fails += 1
		push_error("SKIN FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func solid(centre: Vector2, size: Vector2) -> void:
	var b := StaticBody2D.new()
	b.collision_layer = 1
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	cs.position = centre
	b.add_child(cs)
	add_child(b)

func spawn(at: Vector2) -> Player:
	var p := Player.new()
	p.collision_layer = 2
	p.collision_mask = 1
	p.position = at
	add_child(p)
	return p

## The skin's colours, as `Color.to_rgba32()` keys.
static func palette_of(img: Image) -> Dictionary:
	var out := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a8 == 255:
				out[c.to_rgba32()] = true
	return out

## Within a couple of steps of one of `palette`'s colours, per channel.
static func in_palette(c: Color, palette: Dictionary) -> bool:
	for key: int in palette:
		var p := Color.hex(key)
		if absi(p.r8 - c.r8) <= 2 and absi(p.g8 - c.g8) <= 2 and absi(p.b8 - c.b8) <= 2:
			return true
	return false

## Reads the frame back and sorts every screen pixel under the player's sprite
## into the clear colour, a colour of `palette`, or something else.
func sample(palette: Dictionary, shot: String) -> Dictionary:
	await RenderingServer.frame_post_draw
	var im := get_viewport().get_texture().get_image()
	im.save_png(dir.path_join(shot + ".png"))
	var xf := get_window().get_final_transform() * view.sprite.get_global_transform_with_canvas()
	var size := Sprites.frame_size(Style.PLAYER_ART)
	var rect := Rect2i(xf * Rect2(-size * 0.5, size))
	rect = rect.intersection(Rect2i(Vector2i.ZERO, im.get_size()))
	var clear := RenderingServer.get_default_clear_color()
	var out := {"bg": 0, "skin": 0, "other": 0, "examples": []}
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := im.get_pixel(x, y)
			if absi(c.r8 - clear.r8) <= 2 and absi(c.g8 - clear.g8) <= 2 and absi(c.b8 - clear.b8) <= 2:
				out["bg"] += 1
			elif in_palette(c, palette):
				out["skin"] += 1
			else:
				out["other"] += 1
				if out["examples"].size() < 4:
					out["examples"].append("%s at %d,%d" % [c.to_html(false), x, y])
	out["rect"] = rect
	return out

func _ready() -> void:
	if OS.has_environment("SHOTS_DIR"):
		dir = OS.get_environment("SHOTS_DIR")
	DirAccess.make_dir_recursive_absolute(dir)
	# Not 1:1 with the design size, so a screen-for-canvas mix-up would show.
	get_window().size = Vector2i(1440, 810)
	await frames(3)

	# --- the character, on the CPU -----------------------------------------------
	var art := Style.PLAYER_ART
	check(Sprites.has_character(art), "the player's art '%s' is a character" % art)
	var sk := Sprites.skinned(art)
	check(sk != null, "and one drawn the map way")
	if sk == null:
		_finish()
		return
	for anim in ["idle", "run", "hit", "dash", "sit"]:
		check(sk.frames.has_animation(anim) and sk.frames.get_frame_count(anim) > 0,
			"it has a '%s' pose" % anim)
	check(sk.frames.get_frame_count("run") >= 6, "the run is a cycle, not a shuffle (%d frames)" % sk.frames.get_frame_count("run"))
	check(Sprites.frame_size(art) == Vector2(sk.frame_size) and sk.frame_size == sk.skin_image.get_size(),
		"the frames are the skin's size (%s)" % sk.frame_size)
	check(is_equal_approx(Sprites.art_rect(art).end.y, float(sk.frame_size.y)),
		"the feet stand on the frame's bottom row (art ends at %s)" % Sprites.art_rect(art).end.y)
	var strays := 0
	for anim in sk.strays:
		strays += int(sk.strays[anim])
	check(strays == 0, "every painted pixel is a map colour (%d were not)" % strays)
	var drawn := 0
	var off := 0
	for anim in sk.frames.get_animation_names():
		for look: Image in sk.lookup_frames(anim):
			for y in look.get_height():
				for x in look.get_width():
					var at := look.get_pixel(x, y)
					if at.a8 == 0:
						continue
					drawn += 1
					if sk.skin_image.get_pixel(at.r8, at.g8).a8 < 255:
						off += 1
	check(drawn > 0 and off == 0,
		"every painted pixel names an opaque skin pixel (%d pixels, %d off the skin)" % [drawn, off])
	var palette := palette_of(sk.skin_image)
	var resolved := Sprites.resolved_frames(art)
	var img := resolved.get_frame_texture("idle", 0).get_image()
	var res_off := 0
	var res_drawn := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a8 == 0:
				continue
			res_drawn += 1
			if not palette.has(c.to_rgba32()):
				res_off += 1
	check(res_drawn > 0 and res_off == 0,
		"the resolved idle frame is in the skin's colours (%d pixels, %d not)" % [res_drawn, res_off])

	# --- the character, on screen --------------------------------------------------
	player = spawn(Vector2(640, 360))
	await frames(4)
	view = Views.of(player) as PlayerView
	check(view != null and view.sprite != null, "the player was given its view")
	if view == null or view.sprite == null:
		_finish()
		return
	# The weapon is cut from the atlas; only the body is under test.
	view.weapon_sprite.visible = false
	await frames(6)
	check(view.sprite.animation == "idle", "standing still, the player idles (%s)" % view.sprite.animation)
	check(view.sprite.material is ShaderMaterial
			and (view.sprite.material as ShaderMaterial).get_shader_parameter("skin") == sk.skin,
		"the sprite wears the skin shader, sampling the skin")
	var seen: Dictionary = await sample(palette, "player_skin")
	print("[SKIN] on screen in %s: %d skin, %d background, %d other %s"
		% [seen["rect"], seen["skin"], seen["bg"], seen["other"], seen["examples"]])
	check(seen["skin"] >= 300, "the body is on screen in the skin's colours (%d pixels)" % seen["skin"])
	check(seen["other"] == 0, "and in nothing else: no raw coordinates, no blending (%d pixels: %s)"
		% [seen["other"], ", ".join(seen["examples"])])

	# The art stands on the body's feet: the frame's bottom row, where the feet
	# are drawn, sits on the node, whatever the body's size says.
	var scale := Sprites.PIXEL_SCALE
	var under_art := (Sprites.frame_size(art).y * 0.5 - (Sprites.frame_size(art).y - Sprites.art_rect(art).end.y)) * scale
	check(is_equal_approx(view.sprite.position.y + under_art, 0.0),
		"the art's feet stand on the body's feet (%.1f off)" % (view.sprite.position.y + under_art))
	# The player's own art is drawn side on, so it shows for every facing,
	# mirrored the way the body is turned: walking down the screen is the side
	# strip, and walking left is the same strip turned round.
	Input.action_press("move_down")
	for i in 6:
		await get_tree().physics_frame
	await frames(4)
	check(view.showing() == "run" and not view.sprite.flip_h,
		"walking down, side-on art shows its run, unmirrored (%s)" % view.sprite.animation)
	Input.action_release("move_down")
	Input.action_press("move_left")
	for i in 6:
		await get_tree().physics_frame
	await frames(4)
	check(view.showing() == "run" and view.sprite.flip_h,
		"walking left, the same run turned round (%s)" % view.sprite.animation)
	Input.action_release("move_left")
	for i in 12:
		await get_tree().physics_frame
	await frames(4)
	check(view.showing() == "idle" and view.sprite.flip_h,
		"and standing, the idle, still turned the way it last went (%s)" % view.sprite.animation)
	Input.action_press("move_right")
	for i in 6:
		await get_tree().physics_frame
	Input.action_release("move_right")
	for i in 12:
		await get_tree().physics_frame
	await frames(4)

	# A second skin, the channels rotated so no colour survives, under the same frames.
	var original: Image = sk.skin_image.duplicate()
	var swapped := Image.create(original.get_width(), original.get_height(), false, Image.FORMAT_RGBA8)
	for y in original.get_height():
		for x in original.get_width():
			var c := original.get_pixel(x, y)
			swapped.set_pixel(x, y, Color(c.g, c.b, c.r, c.a))
	check(Sprites.reskin(art, swapped), "the skin can be swapped in place")
	await frames(4)
	var reseen: Dictionary = await sample(palette_of(swapped), "player_reskinned")
	print("[SKIN] reskinned: %d new-skin, %d background, %d other %s"
		% [reseen["skin"], reseen["bg"], reseen["other"], reseen["examples"]])
	check(reseen["skin"] >= 300 and reseen["other"] == 0,
		"and every frame on screen changes with it (%d pixels in the new skin, %d in neither)"
		% [reseen["skin"], reseen["other"]])
	var res2 := Sprites.resolved_frames(art).get_frame_texture("idle", 0).get_image()
	check(palette_of(swapped).has(res2.get_pixel(int(Sprites.art_rect(art).get_center().x),
			int(Sprites.art_rect(art).get_center().y)).to_rgba32()),
		"the resolved frames follow the new skin too")
	check(not Sprites.reskin(art, Image.create(3, 3, false, Image.FORMAT_RGBA8)),
		"a skin of another size is refused")
	Sprites.reskin(art, original)
	check(not Sprites.reskin("imp", original), "an atlas character has no skin to swap")
	_finish()

func _finish() -> void:
	print("[SKIN] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
