extends Node
## The velocity buffer from aarthificial's interactive foliage, and the
## foliage reading it: what moving things write into the air, how the air
## springs back, and how a patch's pixels move for it.
##
## Still air stays still, and a body standing in it, or barely moving, writes
## nothing. A body running through it leaves a push behind it its own way, and
## none where it has not been; the push swings back past rest and dies away. A
## blast pushes outward all round. When the camera moves, what was pushed stays
## where it was in the world. And every shader is told where the buffer is and
## what time the world thinks it is.
##
## And the shader: a patch with nothing pushing it and no wind is drawn pixel
## for pixel as it was grown; pushed one way its plants lean that way, by
## whole pixels of their own colours, and their roots stay put; a bush pushed
## up rises.
##
## Needs a real renderer: the buffer is stepped on the graphics card and read
## back, and `--headless` draws nothing. Each thing is tried in a corner of the
## buffer of its own, so nothing waits for the air to settle after another,
## and everything waits by the clock rather than by frames: a desk's display
## may run at 120 a second and a CI box's at whatever it likes. A window the
## desk covers stops drawing altogether, viewports and all, so a frame it did
## not draw is drawn here by hand (`tick`).

const S := VelocityBuffer.S
## Where the buffer stands in the world, and how many pixels it covers: the
## world from (-64, -64) to (576, 256).
const ORIGIN := Vector2(-64, -64)
const SIZE := Vector2i(320, 160)
## The corners things are tried in, on floors of their own along the bottom,
## each picture and its margin clear of the next: a patch of grass pushed
## right, one pushed left, and a bush.
const GRASS_RIGHT := Vector2(40, 240)
const GRASS_LEFT := Vector2(260, 240)
const BUSH_AT := Vector2(460, 240)
## How wide the patches of grass are, in pixels of the picture.
const GRASS_SPAN := 48
## A runner's wake along the top left, a blast in the top right, and the wake
## the camera moves over in the very top left.
const WAKE_Y := 60.0
const BLAST_AT := Vector2(340, 20)
const CAMERA_Y := 0.0

var fails := 0
var buffer: VelocityBuffer
var _drawn := false

func check(ok: bool, what: String) -> void:
	if ok:
		print("[VELOCITY] PASS ", what)
	else:
		fails += 1
		push_error("VELOCITY FAIL: " + what)

## One frame. A macOS window that something else covers is not drawn at all,
## and nor is any viewport in it — the buffer stops stepping — so while that
## lasts the frame the loop would have drawn is drawn here instead.
func tick() -> void:
	await get_tree().process_frame
	if not DisplayServer.window_can_draw():
		RenderingServer.force_draw(false)

func frames(n: int) -> void:
	for i in n:
		await tick()

func wait(secs: float) -> void:
	var t := 0.0
	while t < secs:
		await tick()
		t += get_process_delta_time()

## Until a frame has been drawn since this was asked — or, after two seconds
## of none, a failure rather than a run that waits for ever.
func drawn_frame() -> void:
	_drawn = false
	var t := 0.0
	while not _drawn:
		await tick()
		t += get_process_delta_time()
		if t > 2.0:
			check(false, "a frame is drawn (none for two seconds)")
			return

## The buffer as it stands after the last step: R G the push, B A the speed.
func read() -> Image:
	await drawn_frame()
	return buffer.texture().get_image()

## The buffer at a world position.
func at(img: Image, world: Vector2) -> Color:
	var t := Vector2i(((world - buffer.origin) / S).floor())
	if t.x < 0 or t.y < 0 or t.x >= img.get_width() or t.y >= img.get_height():
		return Color(0, 0, 0, 0)
	return img.get_pixel(t.x, t.y)

func most(img: Image) -> float:
	var m := 0.0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			m = maxf(m, maxf(maxf(absf(c.r), absf(c.g)), maxf(absf(c.b), absf(c.a))))
	return m

## A body as wide as a patch, for pushing all of it at once.
class Wide extends CharacterBody2D:
	var body_size := Vector2(100, 40)

## A body of the kind the buffer asks about: in the actors group, moving.
func body(pos: Vector2, vel: Vector2, wide: bool = false) -> CharacterBody2D:
	var b: CharacterBody2D = Wide.new() if wide else CharacterBody2D.new()
	b.add_to_group("actors")
	add_child(b)
	b.global_position = pos
	b.velocity = vel
	return b

## Moves `b` by its own speed every frame until it has gone `far`.
func carry(b: CharacterBody2D, far: float) -> void:
	var gone := 0.0
	while gone < far:
		await tick()
		var step := b.velocity * get_process_delta_time()
		b.global_position += step
		gone += step.length()

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	RenderingServer.frame_post_draw.connect(func() -> void: _drawn = true)
	var world := Node2D.new()
	add_child(world)
	Arena.register(world)
	buffer = VelocityBuffer.new()
	add_child(buffer)
	buffer.follow(ORIGIN, SIZE)
	await frames(3)
	await _still()
	await _foliage()
	await _wake()
	await _blast(world)
	await _camera()
	await _globals()
	print("[VELOCITY] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## --- the air ----------------------------------------------------------------

func _still() -> void:
	await wait(0.1)
	check(most(await read()) == 0.0, "still air stays still")
	var stood := body(Vector2(100, WAKE_Y), Vector2.ZERO)
	var crept := body(Vector2(200, WAKE_Y), Vector2(VelocityBuffer.SLOWEST * 0.5, 0))
	await carry(crept, 4.0)
	check(most(await read()) == 0.0, "a body standing in it, or creeping slower than %.0f, writes nothing"
		% VelocityBuffer.SLOWEST)
	stood.free()
	crept.free()

func _wake() -> void:
	var runner := body(Vector2(0, WAKE_Y), Vector2(400, 0))
	await carry(runner, 130.0)
	var img := await read()
	var behind := runner.global_position - Vector2(60, 0)
	var under := at(img, runner.global_position)
	check(at(img, behind).r > 0.05, "a body running right leaves the air behind it pushed right (%.3f)" % at(img, behind).r)
	check(absf(under.b - VelocityBuffer.push_of(runner.velocity).x) < 0.001 and under.a == 0.0,
		"and moving at the body's own speed under it, eased into the buffer (%.3f for %.3f)"
			% [under.b, VelocityBuffer.push_of(runner.velocity).x])
	check(absf(at(img, Vector2(-40, WAKE_Y)).r) < 0.001 and absf(at(img, behind + Vector2(0, -50)).r) < 0.001,
		"and none where it has not been: before it started, or well above its path")
	# Watch one spot of its wake once it has gone.
	runner.free()
	var highest := 0.0
	var lowest := 0.0
	var t := 0.0
	var last := 1.0
	while t < 3.0:
		var c := at(await read(), behind)
		highest = maxf(highest, c.r)
		lowest = minf(lowest, c.r)
		last = c.r
		t += get_process_delta_time()
	check(highest > 0.1 and lowest < -0.01,
		"the push swings back past rest once the body has gone (from %.3f to %.3f)" % [highest, lowest])
	check(absf(last) < 0.02, "and dies away in a few seconds (%.4f)" % last)

func _blast(world: Node2D) -> void:
	var blast := AreaBurst.new()
	blast.setup(Payload.new(), BLAST_AT, 0, null, null)
	world.add_child(blast)
	await wait(0.2)
	var img := await read()
	var right := at(img, BLAST_AT + Vector2(30, 0))
	var left := at(img, BLAST_AT + Vector2(-30, 0))
	var above := at(img, BLAST_AT + Vector2(0, -30))
	check(right.r > 0.05 and left.r < -0.05 and above.g < -0.05,
		"a blast pushes outward all round (right %.2f, left %.2f, up %.2f)" % [right.r, left.r, above.g])

## Where the push along the column at world `x` is, down the column: the
## middle of it, weighed by how hard it is pushed, in world units — from the
## top of the buffer to `deepest`, clear of everything tried under it.
func _middle_down(img: Image, x: float, deepest: float) -> float:
	var sum := 0.0
	var weight := 0.0
	var y := buffer.origin.y + S * 0.5
	while y < deepest:
		var w := absf(at(img, Vector2(x, y)).r)
		sum += w * y
		weight += w
		y += S
	return sum / maxf(weight, 0.000001)

func _camera() -> void:
	# A wake thirty units tall round CAMERA_Y.
	var runner := body(Vector2(-40, CAMERA_Y), Vector2(500, 0))
	await carry(runner, 90.0)
	runner.free()
	await wait(0.1)
	var before := _middle_down(await read(), 0.0, WAKE_Y - 25.0)
	# The camera moves ten pixels right and twelve down — further than the wake
	# is tall — and the buffer slides under it.
	buffer.follow(ORIGIN + Vector2(10, 12) * S, SIZE)
	var after := _middle_down(await read(), 0.0, WAKE_Y - 25.0)
	check(absf(before - CAMERA_Y) < 4.0 and absf(after - before) < 2.0,
		"when the camera moves, what was pushed stays where it was in the world (down %.1f, then %.1f)"
			% [before, after])
	buffer.follow(ORIGIN, SIZE)

## What every shader is told, read back through one: the world the buffer
## covers and the world's clock, written into the pixels of a float viewport.
## (`global_shader_parameter_get` answers only in the editor.)
func _globals() -> void:
	var probe := SubViewport.new()
	probe.size = Vector2i(2, 1)
	probe.use_hdr_2d = true
	probe.transparent_bg = true
	probe.disable_3d = true
	probe.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(probe)
	var rect := ColorRect.new()
	rect.size = Vector2(2, 1)
	var m := ShaderMaterial.new()
	m.shader = Shader.new()
	m.shader.code = """shader_type canvas_item;
render_mode unshaded, blend_disabled;
global uniform vec4 velocity_area;
global uniform float velocity_time;
void fragment() {
	COLOR = FRAGCOORD.x < 1.0 ? velocity_area : vec4(velocity_time, 0.0, 0.0, 1.0);
}
"""
	rect.material = m
	probe.add_child(rect)
	await frames(2)
	await drawn_frame()
	var first := probe.get_texture().get_image()
	var a := buffer.area()
	var told := first.get_pixel(0, 0)
	check(Vector4(told.r, told.g, told.b, told.a) == Vector4(a.position.x, a.position.y, a.size.x, a.size.y),
		"every shader is told the world the buffer covers (%s for %s)" % [str(told), str(a)])
	var then := first.get_pixel(1, 0).r
	await wait(0.5)
	await drawn_frame()
	var now := probe.get_texture().get_image().get_pixel(1, 0).r
	check(now > then + 0.3, "and the world's clock, which runs (%.2f, then %.2f)" % [then, now])
	probe.queue_free()

## --- the foliage ------------------------------------------------------------

## A viewport drawing the world at the buffer's grid, as the pixel camera
## does, with the patches standing in it and no wind blowing.
func _stage(patches: Array) -> SubViewport:
	var stage := SubViewport.new()
	stage.size = SIZE
	stage.transparent_bg = true
	stage.disable_3d = true
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	stage.canvas_transform = Transform2D(0.0, Vector2.ONE / S, 0.0, -ORIGIN / S)
	for f: Foliage in patches:
		stage.add_child(f)
		(f.material as ShaderMaterial).set_shader_parameter("wind", 0.0)
	return stage

## Each patch's picture as it is drawn now, in pixels of the picture.
func drawn(stage: SubViewport, patches: Array) -> Array:
	await drawn_frame()
	var img := stage.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var out: Array = []
	for f: Foliage in patches:
		var corner := Vector2i(((f.position - ORIGIN) / S).round()) - Vector2i(f.margin, f.picture.get_height())
		out.append(img.get_region(Rect2i(corner, f.picture.get_size())))
	return out

## How far the row `k` pixels over the floor has moved across, from `rest` to
## `bent`: the shift that lines up the most of its pixels, colour for colour,
## with the row it came from — that row, or one or two above it, since a tip
## comes down as it leans.
func row_shift(rest: Image, bent: Image, k: int) -> int:
	var y := bent.get_height() - k
	var best := 0
	var most_matched := -1
	for s in range(-10, 11):
		for drop in 3:
			var from := y - drop
			if from < 0:
				continue
			var matched := 0
			for x in bent.get_width():
				var c := bent.get_pixel(x, y)
				var sx := x - s
				if c.a > 0.0 and sx >= 0 and sx < rest.get_width() and rest.get_pixel(sx, from) == c:
					matched += 1
			# The smaller shift wins a tie: still grass is still.
			if matched > most_matched or (matched == most_matched and absi(s) < absi(best)):
				most_matched = matched
				best = s
	return best

## How far a patch leans, on average, over the rows from `from_k` to `to_k`
## pixels over the floor.
func lean(rest: Image, bent: Image, from_k: int, to_k: int) -> float:
	var sum := 0.0
	for k in range(from_k, to_k + 1):
		sum += row_shift(rest, bent, k)
	return sum / float(to_k - from_k + 1)

func _top_row(img: Image) -> int:
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.0:
				return y
	return img.get_height()

func _foliage() -> void:
	var right := Foliage.of("grass")
	right.grow(GRASS_SPAN, 11)
	right.position = GRASS_RIGHT
	var left := Foliage.of("grass")
	left.grow(GRASS_SPAN, 11)
	left.position = GRASS_LEFT
	var bush := Foliage.of("bush")
	bush.grow(32, 5)
	bush.position = BUSH_AT
	var patches := [right, left, bush]
	var stage := _stage(patches)
	var regions: Array = []
	for f: Foliage in patches:
		var r := Rect2(f.position - Vector2(f.margin, f.picture.get_height()) * S, Vector2(f.picture.get_size()) * S)
		for other: Rect2 in regions:
			check(not r.intersects(other), "(the patches tried stand clear of each other: %s, %s)" % [str(r), str(other)])
		check(Rect2(ORIGIN, Vector2(SIZE) * S).encloses(r), "(and inside the buffer: %s)" % str(r))
		regions.append(r)
	await wait(0.2)
	var rest := await drawn(stage, patches)
	var picture := right.picture.duplicate() as Image
	picture.convert(Image.FORMAT_RGBA8)
	check((rest[0] as Image).get_data() == picture.get_data(),
		"a patch nothing pushes, with no wind, is drawn pixel for pixel as it was grown")
	var half := right.tallest / 2
	check(is_zero_approx(lean(rest[0], rest[0], half, right.tallest - 2)), "(a patch lined up with itself leans nowhere)")
	# Each patch pushed all at once by a body as wide as it, moving its way,
	# then gone — a runner leaves its freshest push at the end it leaves by,
	# and the air's own runners are tried after this. And up through the bush
	# from under the floor until well over its top.
	var middle := Vector2(GRASS_SPAN * S * 0.5, -16)
	var shove_right := body(GRASS_RIGHT + middle, Vector2(450, 0), true)
	var shove_left := body(GRASS_LEFT + middle, Vector2(-450, 0), true)
	var jumper := body(BUSH_AT + Vector2(16, 30), Vector2(0, -700))
	await carry(jumper, 70.0)
	shove_right.free()
	shove_left.free()
	jumper.free()
	await wait(0.08)
	var bent := await drawn(stage, patches)
	var colours := {}
	for y in picture.get_height():
		for x in picture.get_width():
			colours[picture.get_pixel(x, y)] = true
	for i in 2:
		var way := 1.0 if i == 0 else -1.0
		var moved := lean(rest[i], bent[i], half, right.tallest - 2)
		check(moved * way > 1.0, "pushed %s, the grass leans %s (its upper half by %.1f pixels)"
			% ["right" if way > 0 else "left", "right" if way > 0 else "left", moved])
		var own := true
		var img: Image = bent[i]
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.0 and not colours.has(img.get_pixel(x, y)):
					own = false
		check(own, "by whole pixels of its own colours, nothing blended")
		var roots := true
		var floor_row := img.get_height() - 1
		for x in img.get_width():
			if img.get_pixel(x, floor_row) != (rest[i] as Image).get_pixel(x, floor_row):
				roots = false
		check(roots, "and its roots stay where they grew")
	check(_top_row(bent[2]) < _top_row(rest[2]),
		"a bush pushed up rises (its top from row %d to %d)" % [_top_row(rest[2]), _top_row(bent[2])])
	stage.queue_free()
