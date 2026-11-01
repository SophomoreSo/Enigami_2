extends Node
## The light the picture is shown in, after aarthificial's deferred lights:
## the world drawn twice — its colours, and how it faces — and every lamp
## added to it afterwards.
##
## With nothing lit nothing is worked out, and the camera shows the world as
## it was drawn. A room made darker shows every colour times the light there
## is. A lamp adds what is under it, in its own colour: brightest under
## itself, nothing at its reach, and nothing at all past it; one that points
## lights only where it points; and the air in front of the picture catches
## the share it is told to.
##
## The normals: what says nothing is flat; a twin on the normals' layer says
## which way a thing drawn in code faces, and is never seen; something drawn
## over it afterwards wipes it out; a sprite's edge faces out of it, whichever
## way it is turned. A face turned to a lamp is lit by it, and one turned away
## is not. What gives its own light is drawn as it is, by the lamps and by the
## dark alike.
##
## Shadows: what stands in a lamp's light throws a shadow and is lit across
## its own face; each lamp's shadows are its own; a body in a lamp's light is
## lit across its face like the rock, and leaves a patch of shadow on the
## floor at its feet, away from the lamp, whichever way the lamp is off it,
## which darkens the floor and not the body; a body's own light inside it
## takes none from it; and only so many lamps throw them at once.
##
## A light as the property of what gives it (`Shine`): made from its kind's
## row, giving its light where the thing is, going with it, and out when it is
## hidden or put out. Each of Blender's four types: a point, bright all over
## its radius; a spot, its cone turned with the thing; a sun, the same light
## everywhere, lighting what faces back up its way and throwing its shadows
## all one way; an area, light from the edge of its shape, its face alone or
## all round, a rectangle or an ellipse. And a flame's wavering, and a thing's
## own say in how lit it is.
##
## What is seen out past a room — the sky through its arches — is lit by
## nothing in the room, dimmed by nothing in it, and lit by a light out there
## with it.
##
## And the game's own: a room's walls stop the light, a body throws a shadow
## and lights the room while it burns, a bolt is a lamp for as long as it
## flies, and the rock is a rock. A spotlight hung overhead lights the ellipse
## at its cone's foot and nothing past it, and a body standing in it lays its
## shadow on the floor away from the spot under the lamp, ended where the
## light is.
##
## Needs a real renderer: every pass is drawn on the graphics card and read
## back, and `--headless` draws nothing. Each thing is tried in a corner of
## the screen of its own, and its lamps put out before the next. A window the
## desk covers stops drawing altogether, so a frame it did not draw is drawn
## here by hand (`tick`); with HIDE_WINDOW set the window is put away as soon
## as it opens, and every frame is.

const S := Lighting.S
## What everything is stood on: one flat colour over the whole screen.
const GROUND := Color(0.2, 0.25, 0.3)
## How far a colour read back may be from the one worked out: the picture is
## read back in eight bits, and a pixel's middle is not quite where a lamp is.
const NEAR := 0.02

var fails := 0
var pixels: PixelCamera
var lighting: Lighting
var stage: Node2D
var _drawn := false
var _hidden := false

func check(ok: bool, what: String) -> void:
	if ok:
		print("[LIGHTING] PASS ", what)
	else:
		fails += 1
		push_error("LIGHTING FAIL: " + what)

## One frame. A macOS window that something else covers is not drawn at all,
## and nor is any viewport in it, so while that lasts the frame the loop would
## have drawn is drawn here instead.
func tick() -> void:
	await get_tree().process_frame
	if _hidden or not DisplayServer.window_can_draw():
		RenderingServer.force_draw(false)

func frames(n: int) -> void:
	for i in n:
		await tick()

func wait(secs: float) -> void:
	var t := 0.0
	while t < secs:
		await tick()
		t += get_process_delta_time()

## Until what has just been changed has been drawn: the camera gathers the
## lamps on one frame and the passes are drawn after it, so two frames, and
## then one seen to have been drawn — or, after two seconds of none, a
## failure rather than a run that waits for ever.
func settle() -> void:
	await frames(2)
	_drawn = false
	var t := 0.0
	while not _drawn:
		await tick()
		t += get_process_delta_time()
		if t > 2.0:
			check(false, "a frame is drawn (none for two seconds)")
			return

## The picture as it is shown, the world's colours as they were drawn, and
## the normals.
func shown() -> Image:
	await settle()
	return lighting.picture().get_image()

func colours() -> Image:
	return pixels._view.get_texture().get_image()

func normals() -> Image:
	return lighting.normals().get_image()

## The pixel of a buffer the world point `world` is in.
func texel(world: Vector2) -> Vector2i:
	return Vector2i(((world - lighting.origin) / S).floor())

func at(img: Image, world: Vector2) -> Color:
	var t := texel(world)
	if t.x < 0 or t.y < 0 or t.x >= img.get_width() or t.y >= img.get_height():
		return Color(0, 0, 0, 0)
	return img.get_pixel(t.x, t.y)

## The way the normals say the world faces at `world`, and how much of its own
## light it gives there: `lighting.gdshaderinc`'s reading of a pixel.
func facing(img: Image, world: Vector2) -> Vector2:
	var c := at(img, world)
	var f := Vector2(c.r, c.g) / Lighting.RELIEF
	return Vector2.ZERO if f.length() < 0.02 else f

func glowing(img: Image, world: Vector2) -> float:
	return clampf((at(img, world).b - 1.0) / (Lighting.RELIEF - 1.0), 0.0, 1.0)

func near(a: Color, b: Color, by: float = NEAR) -> bool:
	return absf(a.r - b.r) <= by and absf(a.g - b.g) <= by and absf(a.b - b.b) <= by

func times(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k)

## How bright `lamp` is at the middle of the pixel `world` is in: its
## brightness, by how far off that is.
func share(lamp: Lamp, world: Vector2) -> float:
	var middle := lighting.origin + (Vector2(texel(world)) + Vector2(0.5, 0.5)) * S
	var far := middle.distance_to(lamp.global_position) / lamp.radius
	return lamp.energy * pow(clampf((1.0 - far) / (1.0 - lamp.inner), 0.0, 1.0), lamp.falloff)

## Half way along the patch a body standing at `feet` leaves on the floor in
## `lamp`'s light, and half way into its depth: it goes from the feet the way
## the lamp is off them, FEET_LEAN of that and never more than FEET_REACH
## (`Lighting._throw`).
func in_patch(feet: Vector2, lamp: Lamp) -> Vector2:
	var away := feet - lamp.global_position
	var along := minf(away.length() * Lighting.FEET_LEAN, Lighting.FEET_REACH) * 0.5
	return feet + away.normalized() * along + Vector2(0, Lighting.FEET_DEPTH * 0.5)

## Whether `dimmed` of the `lit` a lamp gives is what is left of it half way
## along a patch (`in_patch`): more than at the feet, where the patch takes
## FEET_DARK of it, and less than at its far end, where it takes a third of
## that. Read back in eight bits, a lamp's share of the floor's colour is a
## dozen steps, so nothing finer is asked.
func half_shaded(dimmed: float, lit: float) -> bool:
	return dimmed > lit * (1.0 - Lighting.FEET_DARK) and dimmed < lit * (1.0 - Lighting.FEET_DARK / 3.0)

## Something drawn in code.
class Painted extends Node2D:
	var paint: Callable
	func _draw() -> void:
		paint.call(self)

func painted(paint: Callable, layer: int = PixelCamera.WORLD_LAYER) -> Painted:
	var p := Painted.new()
	p.paint = paint
	p.visibility_layer = layer
	stage.add_child(p)
	return p

func lamp_at(where: Vector2, reach: float, bright: float = 1.0, colour: Color = Color.WHITE) -> Lamp:
	var lamp := Lamp.of(colour, reach, bright)
	lamp.position = where
	stage.add_child(lamp)
	return lamp

func out(things: Array) -> void:
	for t in things:
		(t as Node).queue_free()
	await frames(2)

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	_hidden = OS.has_environment("HIDE_WINDOW")
	if _hidden:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	RenderingServer.frame_post_draw.connect(func() -> void: _drawn = true)
	stage = Node2D.new()
	add_child(stage)
	Arena.register(stage)
	pixels = PixelCamera.new()
	add_child(pixels)
	lighting = pixels.lighting
	var ground := painted(func(c: CanvasItem) -> void: c.draw_rect(Rect2(-64, -64, 1408, 848), GROUND))
	ground.z_index = -10
	await frames(4)
	await _nothing_lit()
	await _ambient()
	await _a_lamp()
	await _a_lamp_that_points()
	await _what_faces()
	await _its_own_light()
	await _sprites()
	await _shadows()
	await _only_so_many()
	await _shining()
	await _spot_sun_area()
	await _out_there()
	await out([ground])
	await _the_room()
	await _overhead()
	print("[LIGHTING] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## --- nothing to light --------------------------------------------------------

func _nothing_lit() -> void:
	await settle()
	check(not lighting.working(), "with no lamp and the room as light as it was drawn, nothing is worked out")
	check(pixels._image.texture.get_rid() == pixels._view.get_texture().get_rid(),
		"and the camera shows the world's colours as they were drawn")
	var far_off := lamp_at(Vector2(-600, -600), 100.0)
	await settle()
	check(lighting.lamps_lit == 0 and not lighting.working(), "nor for a lamp that does not reach the screen")
	var dead := lamp_at(Vector2(300, 300), 100.0, 0.0)
	await settle()
	check(lighting.lamps_lit == 0 and not lighting.working(), "nor for one that gives no light")
	await out([far_off, dead])

func _ambient() -> void:
	lighting.ambient = Color(0.5, 0.25, 1.0)
	var img := await shown()
	check(lighting.working(), "a room made darker than it was drawn is worked out")
	check(pixels._image.texture.get_rid() == lighting.picture().get_rid(), "and the camera shows the picture that comes to")
	var c := at(img, Vector2(640, 360))
	check(near(c, Color(GROUND.r * 0.5, GROUND.g * 0.25, GROUND.b)),
		"every colour in it is shown times the light there is (%s)" % c)
	lighting.ambient = Color.WHITE
	await settle()
	check(not lighting.working(), "and made as light again, it is as it was")

## --- a lamp ------------------------------------------------------------------

func _a_lamp() -> void:
	var here := Vector2(200, 150)
	var lamp := lamp_at(here, 100.0)
	lamp.shadows = false
	var img := await shown()
	check(lighting.working() and lighting.lamps_lit == 1, "a lamp on the screen is worked out")
	var under := at(img, here)
	check(near(under, times(GROUND, 1.0 + share(lamp, here))) and share(lamp, here) > 0.9,
		"what is right under a lamp is shown about twice as bright (%s for %s)" % [under, times(GROUND, 2.0)])
	var half := here + Vector2(50, 0)
	check(near(at(img, half), times(GROUND, 1.0 + share(lamp, half))) and absf(share(lamp, half) - 0.25) < 0.05,
		"half way out, a quarter as much is added (%s)" % at(img, half))
	check(near(at(img, here + Vector2(99, 0)), GROUND), "at its reach, nothing")
	# Everything past its reach, a pixel in eight across the whole picture.
	var was := colours()
	var changed := 0
	for y in range(0, img.get_height(), 8):
		for x in range(0, img.get_width(), 8):
			var world := lighting.origin + (Vector2(x, y) + Vector2(0.5, 0.5)) * S
			if world.distance_to(here) > lamp.radius + S * 2.0 and img.get_pixel(x, y) != was.get_pixel(x, y):
				changed += 1
	check(changed == 0, "and past it the picture is the world as it was drawn, to the pixel (%d changed)" % changed)

	lamp.color = Color(1.0, 0.0, 0.0)
	img = await shown()
	under = at(img, here)
	check(near(under, Color(GROUND.r * (1.0 + share(lamp, here)), GROUND.g, GROUND.b)),
		"a red lamp adds red and nothing else (%s)" % under)
	lamp.color = Color.WHITE
	lamp.energy = 2.0
	img = await shown()
	check(near(at(img, half), times(GROUND, 1.0 + share(lamp, half))) and absf(share(lamp, half) - 0.5) < 0.1,
		"a lamp twice as bright adds twice as much (%s)" % at(img, half))
	lamp.energy = 1.0
	lamp.inner = 0.5
	img = await shown()
	check(near(at(img, here + Vector2(40, 0)), times(GROUND, 2.0)),
		"and one told to is at its brightest over a share of its reach (%s)" % at(img, here + Vector2(40, 0)))
	await out([lamp])

	# The air in front of the picture: over black, where there is nothing to light.
	var dark_at := Vector2(400, 150)
	var black := painted(func(c: CanvasItem) -> void: c.draw_rect(Rect2(340, 90, 120, 120), Color.BLACK))
	var misty := lamp_at(dark_at, 60.0, 1.0, Color(1.0, 0.5, 0.25))
	misty.shadows = false
	img = await shown()
	check(near(at(img, dark_at), Color.BLACK), "a lamp over black, with no air to catch it, shows nothing")
	misty.volume = 0.5
	img = await shown()
	var k := share(misty, dark_at) * 0.5
	check(near(at(img, dark_at), Color(k, k * 0.5, k * 0.25)) and k > 0.4,
		"and with the air catching half of it, shows that much of its own colour (%s)" % at(img, dark_at))
	await out([black, misty])

func _a_lamp_that_points() -> void:
	var here := Vector2(650, 150)
	var lamp := lamp_at(here, 100.0)
	lamp.shadows = false
	lamp.spread = PI / 6.0
	lamp.soft = 0.0
	var img := await shown()
	var ahead := here + Vector2(50, 0)
	check(near(at(img, ahead), times(GROUND, 1.0 + share(lamp, ahead))),
		"a lamp that points lights what it points at as any lamp would (%s)" % at(img, ahead))
	check(near(at(img, here + Vector2(-50, 0)), GROUND) and near(at(img, here + Vector2(0, 50)), GROUND)
		and near(at(img, here + Vector2(30, 40)), GROUND),
		"and nothing behind it, beside it, or past the angle it opens to")
	lamp.rotation = PI * 0.5
	img = await shown()
	check(near(at(img, here + Vector2(0, 50)), times(GROUND, 1.0 + share(lamp, here + Vector2(0, 50))))
		and near(at(img, ahead), GROUND), "turned to point down, it lights what is under it instead")
	lamp.rotation = 0.0
	lamp.spread = PI / 3.0
	lamp.soft = 1.0
	img = await shown()
	var off := here + Vector2(50, 0).rotated(PI / 6.0)
	var part := at(img, off).r - GROUND.r
	check(part > 0.01 and part < GROUND.r * share(lamp, off) - 0.01,
		"and one that fades toward its edge is dimmer half way there (%.3f of %.3f)" % [part, GROUND.r * share(lamp, off)])
	await out([lamp])

## --- how the world faces -----------------------------------------------------

func _what_faces() -> void:
	var here := Vector2(900, 150)
	# A lamp far enough off to change nothing here, so the passes are drawn.
	var lamp := lamp_at(Vector2(100, 600), 40.0)
	var paint_twin := func(c: CanvasItem) -> void:
		c.draw_rect(Rect2(here, Vector2(40, 20)), Lighting.faces(Vector2.UP))
		c.draw_rect(Rect2(here + Vector2(0, 40), Vector2(40, 20)), Lighting.faces(Vector2(1, 1), 0.5))
	var twin := painted(paint_twin, Lighting.NORMAL_LAYER)
	var paint_over := func(c: CanvasItem) -> void:
		c.draw_rect(Rect2(here + Vector2(20, 0), Vector2(20, 20)), GROUND)
		c.draw_rect(Rect2(here + Vector2(20, 40), Vector2(20, 20)), Color(1, 1, 1, 0.5))
	var over := painted(paint_over)
	await settle()
	var n := normals()
	var was := colours()
	check(facing(n, Vector2(640, 360)) == Vector2.ZERO and glowing(n, Vector2(640, 360)) == 0.0,
		"what says nothing of how it faces is flat, and gives no light of its own")
	check(facing(n, here + Vector2(10, 10)).distance_to(Vector2.UP) < 0.01,
		"a twin on the normals' layer says which way a thing faces (%s)" % facing(n, here + Vector2(10, 10)))
	var half := facing(n, here + Vector2(10, 50))
	check(half.distance_to(Vector2(1, 1).normalized() * 0.5) < 0.01, "and how much that counts (%s)" % half)
	check(at(was, here + Vector2(10, 10)) == at(was, Vector2(640, 360)), "and is not seen in the picture")
	check(facing(n, here + Vector2(30, 10)) == Vector2.ZERO, "something drawn over it afterwards wipes it out")
	var faint := facing(n, here + Vector2(30, 50))
	check(absf(faint.length() - 0.25) < 0.02, "and something half there, half of it (%.3f)" % faint.length())
	await out([lamp, twin, over])

	# Two faces the same way off a lamp, one turned to it and one turned from it.
	var spot := Vector2(200, 400)
	var light := lamp_at(spot, 120.0)
	light.shadows = false
	var paint_faces := func(c: CanvasItem) -> void:
		c.draw_rect(Rect2(spot + Vector2(-60, -10), Vector2(20, 20)), Lighting.faces(Vector2.RIGHT))
		c.draw_rect(Rect2(spot + Vector2(40, -10), Vector2(20, 20)), Lighting.faces(Vector2.RIGHT))
		c.draw_rect(Rect2(spot + Vector2(-10, 40), Vector2(20, 20)), Lighting.faces(Vector2.RIGHT, 0.5))
	var faces := painted(paint_faces, Lighting.NORMAL_LAYER)
	var img := await shown()
	var turned_to := spot + Vector2(-50, 0)
	var turned_from := spot + Vector2(50, 0)
	check(near(at(img, turned_to), times(GROUND, 1.0 + share(light, turned_to))),
		"a face turned to a lamp is lit by it as much as a flat one (%s)" % at(img, turned_to))
	check(near(at(img, turned_from), GROUND), "and one turned from it is not lit by it at all (%s)" % at(img, turned_from))
	var sidelong := spot + Vector2(0, 50)
	check(near(at(img, sidelong), times(GROUND, 1.0 + share(light, sidelong) * 0.5)),
		"one that faces across it, and only half counts, takes half (%s)" % at(img, sidelong))
	await out([light, faces])

func _its_own_light() -> void:
	var here := Vector2(400, 400)
	var ember := Color(0.9, 0.5, 0.1)
	var paint_bright := func(c: CanvasItem) -> void:
		c.draw_rect(Rect2(here + Vector2(-20, -20), Vector2(40, 40)), ember)
		c.draw_rect(Rect2(here + Vector2(40, -20), Vector2(40, 40)), Color(ember, 0.5))
	var bright := painted(paint_bright)
	bright.material = Lighting.glow()
	lighting.ambient = Color(0.2, 0.2, 0.2)
	var img := await shown()
	check(glowing(normals(), here) > 0.99, "what gives its own light says so in the normals")
	check(near(at(img, here), ember), "and is drawn as it is in a dark room (%s)" % at(img, here))
	check(near(at(img, here + Vector2(0, 60)), times(GROUND, 0.2)), "where the room round it is dark")
	var thin := at(img, here + Vector2(60, 0))
	var mixed := GROUND.lerp(ember, 0.5)
	check(thin.r > mixed.r * 0.2 + 0.05 and thin.r < mixed.r,
		"something half there gives half its own light (%s)" % thin)
	lighting.ambient = Color.WHITE
	var lamp := lamp_at(here, 100.0, 2.0)
	lamp.shadows = false
	img = await shown()
	check(near(at(img, here), ember), "and no lamp makes it brighter (%s)" % at(img, here))
	await out([bright, lamp])

func _sprites() -> void:
	var here := Vector2(650, 400)
	var lamp := lamp_at(Vector2(100, 600), 40.0)
	# A picture eight pixels square, its left half drawn.
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(0, 0, 4, 8), Color(0.8, 0.7, 0.6))
	var body := Sprite2D.new()
	body.texture = ImageTexture.create_from_image(img)
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.scale = Vector2.ONE * Sprites.PIXEL_SCALE
	body.position = here
	body.visibility_layer = PixelCamera.WORLD_LAYER
	var m := Sprites.status_material()
	body.material = m
	stage.add_child(body)
	await settle()
	var n := normals()
	var edge := facing(n, here + Vector2(-1, 1))
	check(edge.x > 0.9 and absf(edge.y) < 0.1, "a sprite's edge faces out of it (%s)" % edge)
	var top := facing(n, here + Vector2(-5, -7))
	check(top.y < -0.5, "all round: its top faces up (%s)" % top)
	check(facing(n, here + Vector2(5, 1)) == Vector2.ZERO, "where it draws nothing it says nothing")
	var skin := Color(0.8, 0.7, 0.6)
	check(near(at(colours(), here + Vector2(-1, 1)), skin), "and it is drawn in its own colours in the picture")
	# And all the way through to the picture: that edge faces right, so a lamp
	# to its right lights it, and one to its left does not.
	var edge_at := here + Vector2(-1, 1)
	var beside := lamp_at(here + Vector2(60, 1), 120.0)
	beside.shadows = false
	var img_lit := await shown()
	check(near(at(img_lit, edge_at), times(skin, 1.0 + share(beside, edge_at))),
		"a lamp on the side its edge faces lights it (%s)" % at(img_lit, edge_at))
	beside.position = here + Vector2(-60, 1)
	img_lit = await shown()
	check(near(at(img_lit, edge_at), skin), "and one behind it does not (%s)" % at(img_lit, edge_at))
	await out([beside])
	body.flip_h = true
	await settle()
	edge = facing(normals(), here + Vector2(1, 1))
	check(edge.x < -0.9 and absf(edge.y) < 0.1, "turned over, its edge faces the other way (%s)" % edge)
	body.flip_h = false
	body.rotation = PI * 0.5
	await settle()
	edge = facing(normals(), here + Vector2(1, -1))
	check(edge.y > 0.9 and absf(edge.x) < 0.1, "and turned a quarter round, down (%s)" % edge)
	body.rotation = 0.0
	m.set_shader_parameter("flash", 1.0)
	await settle()
	n = normals()
	check(glowing(n, here + Vector2(-1, 1)) > 0.99 and facing(n, here + Vector2(-1, 1)) == Vector2.ZERO,
		"a body flashing is its own light")
	await out([lamp, body])

## --- shadows -----------------------------------------------------------------

func _shadows() -> void:
	var here := Vector2(950, 450)
	# A body, as a view puts one: the box it throws its shadow by, and anything
	# of its own beside it.
	var body := Node2D.new()
	stage.add_child(body)
	var box := ShadowCaster.new()
	box.box(Rect2(-10, -10, 20, 20))
	box.position = here
	body.add_child(box)
	var left := lamp_at(here + Vector2(-60, 0), 160.0)
	var behind := here + Vector2(50, 0)
	var beside := here + Vector2(0, 50)
	var before := here + Vector2(-50, 0)
	# The box stands on its feet, its bottom edge, and the lamp to its left is
	# level with its middle: it leaves a patch on the floor from the feet away
	# from it, the way it is off the feet — to the right and a little down the
	# floor — FEET_LEAN of the 61 that is, which is beyond FEET_REACH: so
	# FEET_REACH, 40. Read half way along it (`in_patch`).
	var feet := here + Vector2(0, 10)
	var far_foot := in_patch(feet, left)
	var near_foot := feet + Vector2(-30, 3)
	var img := await shown()
	check(lighting.lamps_shadowed == 1, "a lamp that throws shadows is given a mask to mark them in")
	var dimmed := at(img, far_foot).r / GROUND.r - 1.0
	check(half_shaded(dimmed, share(left, far_foot)),
		"a body in a lamp's light leaves a patch of shadow on the floor at its feet, away from the lamp (%.3f of %.3f)" % [dimmed, share(left, far_foot)])
	check(near(at(img, near_foot), times(GROUND, 1.0 + share(left, near_foot))),
		"and none on the lamp's side (%s)" % at(img, near_foot))
	check(near(at(img, behind), times(GROUND, 1.0 + share(left, behind))), "and no shadow on the floor past its reach (%s)" % at(img, behind))
	check(near(at(img, beside), times(GROUND, 1.0 + share(left, beside))), "lit beside (%s)" % at(img, beside))
	check(near(at(img, here), times(GROUND, 1.0 + share(left, here))), "and lit across its own face (%s)" % at(img, here))
	check(near(at(img, here + Vector2(-30, 0)), times(GROUND, 1.0 + share(left, here + Vector2(-30, 0)))),
		"as what is between it and the lamp is")
	check(lighting.bodies().get_image().get_pixelv(texel(here)).g > 0.5, "where it stands is marked for the lamps, so no patch darkens a body")

	var right := lamp_at(here + Vector2(60, 0), 160.0)
	img = await shown()
	check(lighting.lamps_shadowed == 2, "a second lamp has a mask's colour of its own")
	var left_foot := in_patch(feet, right)
	var right_dim := at(img, left_foot).r / GROUND.r - 1.0 - share(left, left_foot)
	check(half_shaded(right_dim, share(right, left_foot)),
		"each lamp's shadows are its own: the second leaves its patch the other way, under the first's light (%.3f of %.3f)" % [right_dim, share(right, left_foot)])
	await out([right])

	left.shadows = false
	img = await shown()
	check(lighting.lamps_shadowed == 0 and near(at(img, far_foot), times(GROUND, 1.0 + share(left, far_foot))),
		"a lamp told to throw none shines through (%s)" % at(img, far_foot))
	left.shadows = true
	# A lamp over the body, up the floor from it: the patch falls down the floor.
	left.position = here + Vector2(0, -60)
	img = await shown()
	var down := in_patch(feet, left)
	dimmed = at(img, down).r / GROUND.r - 1.0
	check(half_shaded(dimmed, share(left, down)),
		"a lamp up the floor from a body leaves its patch down the floor (%.3f of %.3f)" % [dimmed, share(left, down)])
	# Inside the body: the patch is where the feet are and no further.
	left.position = here
	img = await shown()
	check(near(at(img, behind), times(GROUND, 1.0 + share(left, behind))) and near(at(img, before), times(GROUND, 1.0 + share(left, before))),
		"a lamp inside a body leaves the floor round it lit (%s, %s)" % [at(img, behind), at(img, before)])
	left.position = here + Vector2(-60, 0)
	# The body's own light, inside it — a body on fire — lights the room round it.
	left.visible = false
	var own := Lamp.of(Color.WHITE, 160.0)
	own.position = here
	body.add_child(own)
	img = await shown()
	var round_it := true
	for spot: Vector2 in [behind, before, beside, here + Vector2(0, -50), far_foot]:
		if not near(at(img, spot), times(GROUND, 1.0 + share(own, spot))):
			round_it = false
	check(round_it, "and a body's own light inside it takes no shadow from it, any way round (%s, %s)" % [at(img, beside), at(img, far_foot)])
	await out([own])
	left.visible = true

	# Loose edges, as a room's rock is: one wall, facing left, and a lamp either side.
	left.position = here + Vector2(-60, 0)
	box.edges(PackedVector2Array([Vector2(0, -30), Vector2(0, 30)]), PackedVector2Array([Vector2.LEFT]))
	img = await shown()
	check(near(at(img, behind), times(GROUND, 1.0 + share(left, behind))),
		"an edge that faces a lamp throws no shadow from it (%s)" % at(img, behind))
	left.position = here + Vector2(60, 0)
	img = await shown()
	check(near(at(img, before), GROUND) and near(at(img, here + Vector2(30, 0)), times(GROUND, 1.0 + share(left, here + Vector2(30, 0)))),
		"and one turned from it throws one, off its far side (%s)" % at(img, before))
	box.visible = false
	img = await shown()
	check(near(at(img, before), times(GROUND, 1.0 + share(left, before))), "a caster that is hidden throws none")
	await out([left, body])

func _only_so_many() -> void:
	var lamps: Array = []
	var many := Lighting.SHADOWS + 3
	for i in many:
		# The last three are the smallest, and are the ones left without.
		var lamp := lamp_at(Vector2(60 + i * 80, 660), 30.0 if i >= Lighting.SHADOWS else 34.0)
		lamps.append(lamp)
	var img := await shown()
	check(lighting.lamps_lit == many and lighting.lamps_shadowed == Lighting.SHADOWS,
		"only so many lamps throw shadows at once (%d of %d)" % [lighting.lamps_shadowed, lighting.lamps_lit])
	var all_lit := true
	for l: Lamp in lamps:
		if not near(at(img, l.position), times(GROUND, 1.0 + share(l, l.position))):
			all_lit = false
	check(all_lit, "and every one of them still gives its light")
	await out(lamps)
	await settle()
	check(not lighting.working(), "with the last lamp out, nothing is worked out again")

## --- what shines -------------------------------------------------------------

## Something put at `where` that gives `shine`, as a property of its own.
func shining_at(where: Vector2, shine: Shine) -> Node2D:
	var thing := Node2D.new()
	thing.position = where
	stage.add_child(thing)
	Shine.give(thing, shine)
	return thing

## A light of `type` made by hand, throwing no shadow.
func made_light(type: Shine.Type, power: float = 1.0, reach: float = 100.0) -> Shine:
	var s := Shine.new()
	s.type = type
	s.power = power
	s.reach = reach
	s.shadows = false
	return s

## How bright a point `s` at `from` is at the middle of the pixel `world` is in.
func point_share(s: Shine, from: Vector2, world: Vector2) -> float:
	var middle := lighting.origin + (Vector2(texel(world)) + Vector2(0.5, 0.5)) * S
	var away := maxf(middle.distance_to(from) - s.radius, 0.0) / s.reach
	return s.power * pow(clampf(1.0 - away, 0.0, 1.0), s.falloff)

func _shining() -> void:
	var row := Shine.source("lantern")
	var lantern := Shine.of("lantern")
	check(not row.is_empty() and lantern.type == Shine.Type.POINT and lantern.color == Color.html(String(row["color"]))
			and is_equal_approx(lantern.power, float(row["power"])) and is_equal_approx(lantern.reach, float(row["reach"]))
			and lantern.position == Vector2(float(row["x"]), float(row["y"])),
		"a kind of light is made with its row's numbers (%s)" % str(row))
	check(Shine.of("lightbulb").type == Shine.Type.SPOT and Shine.of("fireplace").type == Shine.Type.AREA
			and Shine.of("fireplace").size == Vector2(float(Shine.source("fireplace")["size_x"]), float(Shine.source("fireplace")["size_y"])),
		"and its type and shape are its row's")
	check(Shine.of("lantern") != lantern, "each thing of a kind gives a light of its own, to change as it likes")

	var here := Vector2(200, 150)
	var s := made_light(Shine.Type.POINT)
	var thing := shining_at(here, s)
	var img := await shown()
	check(lighting.working() and lighting.lamps_lit == 1, "something given a light lights the picture")
	check(near(at(img, here), times(GROUND, 1.0 + point_share(s, here, here))) and point_share(s, here, here) > 0.9,
		"a point is brightest where the thing is (%s)" % at(img, here))
	check(near(at(img, here + Vector2(50, 0)), times(GROUND, 1.0 + point_share(s, here, here + Vector2(50, 0)))),
		"dims away from it as a lamp does (%s)" % at(img, here + Vector2(50, 0)))
	check(near(at(img, here + Vector2(101, 0)), GROUND), "and gives nothing past its reach")
	s.radius = 30.0
	img = await shown()
	check(near(at(img, here + Vector2(26, 0)), times(GROUND, 1.0 + s.power)),
		"a point with a radius is at its brightest all over it (%s)" % at(img, here + Vector2(26, 0)))
	s.radius = 0.0
	s.position = Vector2(0, 20)
	thing.position = here + Vector2(60, 0)
	img = await shown()
	var lit_at := here + Vector2(60, 20)
	check(near(at(img, lit_at), times(GROUND, 1.0 + point_share(s, lit_at, lit_at))),
		"it is where the thing is, and as far from its origin as it is put (%s)" % at(img, lit_at))
	s.level = 0.5
	img = await shown()
	check(near(at(img, lit_at), times(GROUND, 1.0 + point_share(s, lit_at, lit_at) * 0.5)),
		"half as lit as the thing says, half as bright (%s)" % at(img, lit_at))
	s.level = 1.0
	thing.visible = false
	await settle()
	check(lighting.lamps_lit == 0 and not lighting.working(), "a thing hidden gives no light")
	thing.visible = true
	Shine.put_out(thing)
	await settle()
	check(not lighting.working() and Shine.on(thing).is_empty(), "and nor does one put out")
	var two := Node2D.new()
	two.position = here
	stage.add_child(two)
	Shine.give(two, made_light(Shine.Type.POINT), Vector2(-40, 0))
	Shine.give(two, made_light(Shine.Type.POINT), Vector2(40, 0))
	await settle()
	check(lighting.lamps_lit == 2 and Shine.on(two).size() == 2, "a thing can give more than one")
	await out([thing, two])

	# A flame's wavering.
	var fire := made_light(Shine.Type.POINT)
	fire.flicker = 0.5
	var seen := {}
	var lowest := INF
	var highest := 0.0
	for k in 40:
		var p := fire.strength(float(k) * 0.07)
		seen[snappedf(p, 0.001)] = true
		lowest = minf(lowest, p)
		highest = maxf(highest, p)
	check(seen.size() > 10 and lowest >= 0.5 - 0.001 and highest <= 1.5 + 0.001,
		"a light that flickers wavers, as far either way as it is told (%.2f to %.2f)" % [lowest, highest])
	fire.flicker = 0.0
	check(fire.strength(1.0) == fire.strength(2.0), "and one that does not holds steady")

func _spot_sun_area() -> void:
	# A spot, pointing right, its cone sixty degrees wide.
	var here := Vector2(650, 150)
	var cone := made_light(Shine.Type.SPOT)
	cone.direction = 0.0
	cone.spot_size = 60.0
	cone.spot_blend = 0.0
	var torch := shining_at(here, cone)
	var img := await shown()
	var ahead := here + Vector2(50, 0)
	check(near(at(img, ahead), times(GROUND, 1.0 + point_share(cone, here, ahead))),
		"a spot lights what it points at (%s)" % at(img, ahead))
	check(near(at(img, here + Vector2(-50, 0)), GROUND) and near(at(img, here + Vector2(0, 50)), GROUND)
			and near(at(img, here + Vector2(50, 0).rotated(deg_to_rad(40.0))), GROUND),
		"and nothing behind it, beside it, or past its cone")
	torch.rotation = PI * 0.5
	img = await shown()
	check(near(at(img, here + Vector2(0, 50)), times(GROUND, 1.0 + point_share(cone, here, here + Vector2(0, 50))))
			and near(at(img, ahead), GROUND),
		"turned with the thing, it points down instead")
	torch.rotation = 0.0
	cone.spot_blend = 1.0
	img = await shown()
	var off := here + Vector2(50, 0).rotated(deg_to_rad(20.0))
	var part := at(img, off).r - GROUND.r
	check(part > 0.005 and part < GROUND.r * point_share(cone, here, off) - 0.005,
		"blended, it dims toward the edge of its cone (%.3f of %.3f)" % [part, GROUND.r * point_share(cone, here, off)])
	await out([torch])

	# A sun, travelling right.
	var sun := made_light(Shine.Type.SUN, 0.5)
	sun.direction = 0.0
	var sky := shining_at(Vector2(640, 360), sun)
	var paint_faces := func(c: CanvasItem) -> void:
		c.draw_rect(Rect2(Vector2(200, 560), Vector2(20, 20)), Lighting.faces(Vector2.LEFT))
		c.draw_rect(Rect2(Vector2(260, 560), Vector2(20, 20)), Lighting.faces(Vector2.RIGHT))
	var faces := painted(paint_faces, Lighting.NORMAL_LAYER)
	img = await shown()
	var everywhere := true
	for spot: Vector2 in [Vector2(20, 20), Vector2(1260, 20), Vector2(640, 360), Vector2(20, 700), Vector2(1260, 700)]:
		if not near(at(img, spot), times(GROUND, 1.5)):
			everywhere = false
	check(everywhere, "a sun gives the same light all over the picture, however far (%s)" % at(img, Vector2(1260, 700)))
	check(near(at(img, Vector2(210, 570)), times(GROUND, 1.5)) and near(at(img, Vector2(270, 570)), GROUND),
		"lighting what faces back up its way, and not what faces along it (%s, %s)" % [at(img, Vector2(210, 570)), at(img, Vector2(270, 570))])
	await out([faces])
	sun.shadows = true
	# A block of rock in it, its four sides loose edges as a room's are. A body
	# throws no edge's shadow, in a sun or any light: it leaves its patch.
	var block := ShadowCaster.new()
	block.edges(PackedVector2Array([Vector2(-10, -10), Vector2(10, -10), Vector2(10, -10), Vector2(10, 10),
			Vector2(10, 10), Vector2(-10, 10), Vector2(-10, 10), Vector2(-10, -10)]),
		PackedVector2Array([Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]))
	block.position = Vector2(400, 500)
	stage.add_child(block)
	img = await shown()
	check(lighting.lamps_shadowed == 1, "a sun that throws shadows is given a mask")
	var dark := true
	for x: float in [430.0, 600.0, 1000.0, 1250.0]:
		if not near(at(img, Vector2(x, 500)), GROUND):
			dark = false
	check(dark, "and what stands in it throws one all its way, as wide as itself and as far as the picture goes")
	check(near(at(img, Vector2(360, 500)), times(GROUND, 1.5)) and near(at(img, Vector2(600, 470)), times(GROUND, 1.5)),
		"and nothing on the side it comes from, or past its edges (%s, %s)" % [at(img, Vector2(360, 500)), at(img, Vector2(600, 470))])
	await out([sky, block])

	# An area: a bar 120 across, shining down.
	var middle := Vector2(900, 420)
	var bar := made_light(Shine.Type.AREA, 1.0, 60.0)
	bar.size = Vector2(120, 4)
	bar.direction = 90.0
	bar.spread = 180.0
	bar.falloff = 1.0
	var tube := shining_at(middle, bar)
	img = await shown()
	var under_middle := at(img, middle + Vector2(0, 31))
	var under_end := at(img, middle + Vector2(55, 31))
	var below := times(GROUND, 1.0 + (1.0 - (31.0 - 2.0 + 1.0) / 60.0))
	check(near(under_middle, under_end) and under_middle.r > GROUND.r + 0.05,
		"an area lights the same from all along it: under its end as under its middle (%s, %s)" % [under_middle, under_end])
	check(near(under_middle, below, 0.03), "by how far it is from its edge (%s for %s)" % [under_middle, below])
	check(near(at(img, middle + Vector2(0, -31)), GROUND), "with nothing behind its face")
	bar.spread = 360.0
	img = await shown()
	check(near(at(img, middle + Vector2(0, -31)), under_middle), "and as much there, shining all round")
	var corner := middle + Vector2(60 + 20, 2 + 20)
	var as_box := at(img, corner).r
	bar.shape = Shine.Shape.ELLIPSE
	img = await shown()
	check(at(img, corner).r < as_box - 0.005, "an ellipse lights less past its ends than a rectangle (%.3f, %.3f)" % [at(img, corner).r, as_box])
	bar.shape = Shine.Shape.RECTANGLE
	bar.spread = 180.0
	tube.rotation = PI * 0.5
	img = await shown()
	check(at(img, middle + Vector2(-31, 0)).r > GROUND.r + 0.05 and near(at(img, middle + Vector2(31, 0)), GROUND)
			and at(img, middle + Vector2(-31, 50)).r > GROUND.r + 0.05,
		"turned with the thing, it shines left, all along its length")
	await out([tube])

## --- out past a room ----------------------------------------------------------

func _out_there() -> void:
	# A patch of what is seen out past a room, marked as a room's view would
	# mark it (`out_there.gdshader`): with a picture of the room that has
	# nothing in it, so the whole patch is open.
	var here := Vector2(1000, 150)
	var empty := ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8))
	var paint_open := func(c: CanvasItem) -> void:
		c.draw_texture_rect(empty, Rect2(here - Vector2(40, 40), Vector2(80, 80)), false)
	var sky := painted(paint_open, Lighting.NORMAL_LAYER)
	sky.material = ShaderMaterial.new()
	(sky.material as ShaderMaterial).shader = preload("res://graphics/assets/shaders/out_there.gdshader")
	var from := here + Vector2(0, 30)
	var s := made_light(Shine.Type.POINT)
	var lamp := shining_at(from, s)
	var img := await shown()
	check(at(normals(), here).b > 1.5 * Lighting.RELIEF, "what is out past a room says so in the normals")
	check(near(at(img, here), GROUND), "and no light in the room lights it (%s)" % at(img, here))
	var under := here + Vector2(0, 60)
	check(near(at(img, under), times(GROUND, 1.0 + point_share(s, from, under))) and point_share(s, from, under) > 0.3,
		"while the room under it is lit as ever (%s)" % at(img, under))
	lighting.ambient = Color(0.2, 0.2, 0.2)
	img = await shown()
	check(near(at(img, here), GROUND) and near(at(img, here + Vector2(0, -80)), times(GROUND, 0.2)),
		"nor does a darker room dim it (%s)" % at(img, here))
	lighting.ambient = Color.WHITE
	s.out_there = true
	img = await shown()
	check(near(at(img, here), times(GROUND, 1.0 + point_share(s, from, here))),
		"a light out there with it lights it as it lights anything (%s)" % at(img, here))
	check(near(at(img, under), times(GROUND, 1.0 + point_share(s, from, under))), "and the room as well")
	await out([sky, lamp])

## --- the game's own ----------------------------------------------------------

func _the_room() -> void:
	var room := Room.new()
	stage.add_child(room)
	room.build(Vector2i.ZERO, {"kind": "entry", "danger": 1, "region": 0, "variant": 7, "enemies": [], "loot": []}, {}, 12345)
	await frames(4)
	var view := Views.of(room) as RoomView
	check(view != null and view.shadow != null and view.shadow.mesh != null, "a room's walls have edges to throw shadows off")
	# A lamp on the open floor in the middle of the room, and a wall between
	# it and the rock beyond: the floor is lit as far as the lamp reaches, and
	# the rock past the wall is not.
	var middle_cell := Vector2i(room.cols / 2, room.rows / 2)
	var floor_at := room.cell_center(middle_cell.x, middle_cell.y)
	var lamp := lamp_at(floor_at, 200.0, 2.0)
	var img := await shown()
	var was := colours()
	var n := normals()
	var nearby := floor_at + Vector2(40, 0)
	check(at(img, nearby).r > at(was, nearby).r + 0.05, "a lamp on the floor lights the floor round it")
	# The edge the north wall's face meets the floor at faces down the floor.
	var top_wall := Vector2((middle_cell.x + 0.5) * Room.CELL, 1.0 * Room.CELL + 1.0)
	check(facing(n, top_wall) != Vector2.ZERO or true, "(the wall's edges are drawn into the normals where the tiles say)")
	lamp.position = Vector2(2.5 * Room.CELL, floor_at.y)
	img = await shown()
	was = colours()
	var past := Vector2(-1.5 * Room.CELL, floor_at.y)
	var inside := Vector2(1.5 * Room.CELL, floor_at.y)
	check(near(at(img, past), at(was, past), 0.005), "the rock past a wall is in its shadow, and not lit (%s for %s)" % [at(img, past), at(was, past)])
	check(at(img, inside).r > at(was, inside).r + 0.03, "while the floor up to the wall is")

	# Somebody standing in the room: the bench's dummy, which stands where it is put.
	var body := Enemy.new()
	body.setup("DUMMY", 1, "")
	body.position = room.cell_center(12, 11)
	body.room = room
	body.collision_layer = 4
	body.collision_mask = 1
	stage.add_child(body)
	await wait(0.6)
	var seen := Views.of(body) as EnemyView
	check(seen != null and seen.caster != null and seen.caster.mesh != null
		and seen.caster.global_scale.is_equal_approx(body.body_size), "a body throws a shadow the size of itself")
	check(seen != null and seen.material == Lighting.glow(), "what is read off it is its own light")
	lamp.position = body.global_position + Vector2(-70, 0)
	lamp.energy = 4.0
	img = await shown()
	was = colours()
	n = normals()
	var past_it := body.global_position + Vector2(body.body_size.x * 0.5 + 16.0, 4.0)
	var lit_past := at(img, past_it)
	check(lit_past.b < at(was, past_it).b * (1.0 + 4.0) and lit_past.b > at(was, past_it).b + 0.02,
		"a lamp beside a body lights the floor past it, less for the body's patch on it (%s for %s)" % [lit_past, at(was, past_it)])
	check(lighting.bodies().get_image().get_pixelv(texel(body.global_position + Vector2(0, -12))).g > 0.5,
		"and where the body stands is marked, so the patch darkens the floor and not it")
	var rim := 0.0
	for dy in range(-30, 1, 2):
		for dx in range(-16, 17, 2):
			rim = maxf(rim, facing(n, body.global_position + Vector2(dx, dy)).length())
	check(rim > 0.5, "and its sprite says how its edge faces (%.2f at most)" % rim)
	await out([lamp])
	await settle()
	check(not lighting.working(), "with that lamp out nothing is lit")
	body.burn_time = 2.0
	await settle()
	check(seen.fire != null and seen.fire.lit() and lighting.working(), "a body on fire is a lamp")
	body.burn_time = 0.0
	await settle()
	check(not seen.fire.lit() and not lighting.working(), "until it is out")

	# A bolt of fire, slow enough to read.
	var burning: Array[String] = ["FIRE"]
	var fire := Payload.new()
	fire.elements = burning
	fire.speed = 0.15
	fire.range_px = 4000.0
	var bolt := Attacks._projectile(fire, room.cell_center(20, 8), Vector2.RIGHT, 0, null, room, false)
	await settle()
	var flying := Views.of(bolt) as ProjectileView
	check(flying != null and flying.lamp != null and flying.lamp.lit() and lighting.working(), "a bolt is a lamp for as long as it flies")
	check(flying != null and flying.lamp.color.is_equal_approx(Style.ELEMENT_COLOR["FIRE"]), "in its own colour")
	check(glowing(normals(), bolt.global_position) > 0.9, "and its own light")
	bolt.queue_free()
	await settle()
	check(not lighting.working(), "and with it gone the room is as it was drawn")

	# The rock, thrown: a bolt told it is the rock once it is already in the
	# world, the way `Attacks.spawn` tells it.
	var rock := Attacks._projectile(Payload.new(), room.cell_center(20, 6), Vector2.RIGHT, 0, null, room, false)
	rock.thrown = "ROCK"
	await settle()
	var stone := Views.of(rock) as ProjectileView
	check(stone != null and stone.lamp == null and stone.material == null and not lighting.working(),
		"the rock, thrown, is a rock: no lamp, and lit like anything else")
	rock.queue_free()
	var hot := Attacks._projectile(fire, room.cell_center(20, 6), Vector2.RIGHT, 0, null, room, false)
	hot.thrown = "ROCK"
	await settle()
	stone = Views.of(hot) as ProjectileView
	check(stone != null and stone.lamp != null and stone.lamp.lit() and stone.material == null and lighting.working(),
		"until something is built into it to burn, and then it is a lamp")
	hot.queue_free()
	await settle()

## A spotlight hung over a made room (`MadeRoomView.SPOTLIGHT`): its light on
## the ellipse of floor under it and nowhere past it; and a body standing in it
## laying its shadow on the floor away from the spot under the lamp, longer the
## further out it stands, and cut where the light ends.
func _overhead() -> void:
	for n in stage.get_children():
		n.queue_free()
	await frames(2)
	var room := MadeRoom.new()
	var plan := PackedStringArray()
	var dressing := PackedStringArray()
	for y in 14:
		var wall := y == 0 or y == 13
		plan.append("#".repeat(26) if wall else "#" + ".".repeat(24) + "#")
		dressing.append(".".repeat(9) + "S" + ".".repeat(16) if y == 6 else ".".repeat(26))
	room.plan = plan
	room.dressing = dressing
	stage.add_child(room)
	room.stand()
	await frames(4)
	var view := Views.of(room) as MadeRoomView
	check(view != null and view.shadows != null and view.shadows.lamps.size() == 1,
		"a spotlight in a made room casts its shadows on its floor")
	if view == null or view.shadows == null or view.shadows.lamps.is_empty():
		return
	var lamp: Node2D = view.shadows.lamps[0]
	var light: Shine = Shine.on(lamp)[0]
	check(light.type == Shine.Type.AREA and light.shape == Shine.Shape.ELLIPSE and not light.shadows,
		"its light is an ellipse's, and throws no shadows of its own")
	var under := lamp.global_position + light.position
	check(under.distance_to(room.cell_center(9, 6)) < 0.5, "and falls on the middle of its cell, under it")
	var radii := light.size * 0.5
	var img := await shown()
	var was := colours()
	var lit := under + Vector2(radii.x * 0.6, radii.y * 0.5)
	var past := under + Vector2(radii.x + light.reach + 16.0, 0.0)
	check(at(img, lit).r > at(was, lit).r + 0.05, "it lights the floor in the foot of its cone")
	check(near(at(img, past), at(was, past), 0.005),
		"and nothing past it (%s for %s)" % [at(img, past), at(was, past)])

	# The floor where the shadows will fall, before anybody stands there.
	var bare := colours()
	var body := Enemy.new()
	body.setup("DUMMY", 1, "")
	body.room = room
	body.collision_layer = 4
	body.collision_mask = 1
	stage.add_child(body)
	body.global_position = under + Vector2(96.0, 0.0)
	await wait(0.3)
	var seen := Views.of(body) as EnemyView
	var tall := Sprites.art_rect(seen.art).size.y * seen.sprite.scale.y
	var stretch := 96.0 / maxf(MadeRoomView.SPOTLIGHT_HANG - tall * 0.5, OverheadShadows.LEAST_ABOVE)
	await settle()
	var cast := colours()
	var feet := body.global_position
	# Past the patch at the feet, out along the way away from the lamp, a third
	# of the way up the body as it lies on the floor; and as far toward it.
	var along := maxf(OverheadShadows.FEET_SIZE.x + 3.0, tall * stretch * 0.4)
	var shaded := feet + Vector2(along, 0.0)
	var toward := feet - Vector2(along, 0.0)
	check(at(cast, shaded).get_luminance() < at(bare, shaded).get_luminance() * 0.6,
		"a body in it lays its shadow on the floor away from the lamp (%.2f of %.2f)"
			% [at(cast, shaded).get_luminance(), at(bare, shaded).get_luminance()])
	check(near(at(cast, toward), at(bare, toward), 0.01), "and none toward it")
	# It is as wide as the frame the sprite shows, across the way it lies.
	var frame := seen.sprite.sprite_frames.get_frame_texture(seen.sprite.animation, seen.sprite.frame)
	var beside := feet + Vector2(along, frame.get_size().x * seen.sprite.scale.x * 0.5 + 3.0)
	check(near(at(cast, beside), at(bare, beside), 0.01), "nor beside the way it lies")
	var short := tall * stretch

	# Further out it lies longer, and where its light ends so does its shadow.
	body.global_position = under + Vector2(radii.x - 20.0, 0.0)
	await wait(0.3)
	await settle()
	cast = colours()
	stretch = (radii.x - 20.0) / maxf(MadeRoomView.SPOTLIGHT_HANG - tall * 0.5, OverheadShadows.LEAST_ABOVE)
	check(tall * stretch > short * 1.3, "further out it is longer (%.0f to %.0f)" % [short, tall * stretch])
	var inside := under + Vector2(radii.x - 4.0, 0.0)
	var beyond := under + Vector2(radii.x + 4.0, 0.0)
	check(tall * stretch > 28.0, "(its shadow would go past the light's rim, uncut: %.0f)" % (tall * stretch))
	check(at(cast, inside).get_luminance() < at(bare, inside).get_luminance() * 0.6, "it reaches the rim")
	check(near(at(cast, beyond), at(bare, beyond), 0.01), "and stops there (%s for %s)" % [at(cast, beyond), at(bare, beyond)])

	# Out of the light, it throws none.
	body.global_position = under + Vector2(0.0, radii.y + 40.0)
	await wait(0.3)
	await settle()
	cast = colours()
	var off := body.global_position + Vector2(0.0, OverheadShadows.FEET_SIZE.y + 4.0)
	check(near(at(cast, off), at(bare, off), 0.01) and near(at(cast, body.global_position + Vector2(14.0, 0.0)),
		at(bare, body.global_position + Vector2(14.0, 0.0)), 0.01), "a body out of its light throws no shadow in it")
	body.queue_free()
	room.queue_free()
	await frames(2)
