class_name PixelCamera
extends CanvasLayer

## The world, drawn at the art's own resolution and shown at SCALE×.
##
## Actors are 16px art drawn at 2× (`Sprites.PIXEL_SCALE`), but rooms, attacks
## and effects are primitives placed at full resolution, so a slash could land
## between two of a knight's pixels. This puts the whole world on the art's
## grid: a SubViewport shares the screen's World2D and draws it at 1/SCALE, and
## the result is laid over the screen with nearest filtering. The HUD and the
## overlays sit on higher layers and stay sharp.
##
## A grid alone would move the camera in SCALE-pixel steps. So the buffer runs
## BORDER pixels past the screen on every side, its view is snapped to whole
## world pixels, and the image is slid across that border by whatever the real
## camera had left over. This is the smooth pixel-perfect camera from
## https://discussions.unity.com/t/1586409, which does it as a URP render pass
## with a crop shader.
##
## That thread ends on stray vertical lines, put down to float precision. They
## are nearest sampling landing exactly on a texel edge, where rounding picks
## either neighbour. The slide here is rounded to whole screen pixels, so at 2×
## every screen pixel samples a quarter texel in from an edge and never on one.
##
## The real camera is left alone. It still maps the mouse into the world, which
## is why aiming needs nothing from this.
##
## What it asks of everything drawn in the world: a line narrower than SCALE
## world units covers no pixel centre at this resolution and is not drawn at
## all. That is how the room grid and the tile outlines disappeared when this
## went in, at 1.0 wide; they, and every other line that was set thinner, are
## SCALE wide now.
##
## It carries the air the picture is drawn in, too: a `VelocityBuffer` the
## size of its own buffer and on the same grid, which the foliage reads to
## bend where something moves through it — the way the package that buffer
## comes from hangs it on the camera.
##
## And the light it is shown in: a `Lighting`, which takes this buffer as the
## world's colours, draws the world a second time for how it faces, and adds
## every lamp there is to it, a pass each — on the same grid again, so light
## falls in the pixels the world is drawn in.
##
## And the glass in it: a `Glazing`, which draws the world once more for where
## the glass is and puts the glass into the lit picture — what is behind clear
## glass seen through it, what is in front of a mirror shown in it. What is
## laid over the screen is the picture that comes to; with nothing lit and no
## glass on the screen, it is this buffer as it was.

const SCALE := int(Sprites.PIXEL_SCALE)
const BORDER := 1
## Over the world's own canvas, under the screens (5) and the HUD (10).
const LAYER := 1

## Views are drawn on this render layer and no other (see `Views`). While a
## pixel camera is up the screen leaves the layer out, so the world is not drawn
## a second time underneath a picture that covers it.
const WORLD_LAYER := 1 << 19

## The pixel font world text is set in, and its native size in buffer pixels.
const FONT := preload("res://graphics/assets/fonts/Silkscreen-Regular.ttf")
const TEXT_SIZE := 8
## How the picture is graded as it is shown: grey while magic is off
## (`Magic`), and the slow-motion look while time is dilated (`TimeCtl`) — see
## the shader. And how fast each goes in and comes back, in wholes a second:
## the grey over a few frames, so it reads as the colour going rather than a
## cut, and the slow faster, so it lands with the slowing it is the look of.
const GRADE := preload("res://graphics/assets/shaders/picture_grade.gdshader")
const GREY_SPEED := 5.0
const SLOW_IN := 12.0
const SLOW_OUT := 6.0

## Pixel cameras currently up. A screen swap frees the old one at the end of the
## frame the new one arrived in, and the old one must not hand the world layer
## back to the screen while the new one still needs it left out.
static var _live := 0

var _view: SubViewport
var _image: Sprite2D
## How far the picture has gone grey: 0 in magic, 1 with it off.
var _grey := 0.0
## How far it has gone into the slow-motion look: 0 at full speed, 1 dilated.
var _slow := 0.0
var _grade: ShaderMaterial
## The wall clock at the last frame, in microseconds: the slow eases on it,
## since the frame's own delta is the dilated one.
var _clock := 0
## What everything moving does to the air in the picture, on its grid.
var velocity: VelocityBuffer
## The light the picture is shown in, on its grid.
var lighting: Lighting
## The glass in the picture, worked out after the light.
var glazing: Glazing

## Draws text into the world, centred on `at`, `size` in buffer pixels.
##
## Text drawn at world size is rasterised at that size and then shrunk into the
## buffer through a filter, so it arrives blurred before the picture is ever
## blown back up — the room names went to mush that way. Drawing `size` under a
## SCALE× transform puts each glyph pixel on exactly one buffer pixel instead.
static func draw_text(c: CanvasItem, at: Vector2, text: String, color: Color,
		shadow: Color = Color(0, 0, 0, 0), size: int = TEXT_SIZE, font: Font = FONT) -> void:
	# TEXT_SIZE is Silkscreen's own 8px, one art pixel per glyph pixel. A line
	# in writing Silkscreen does not have is drawn in the language's face, which
	# has its own size — see `Loc.text_size`.
	size = Loc.text_size(text, size)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var o := (at / SCALE - Vector2(w * 0.5, 0.0)).round()
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * SCALE)
	if shadow.a > 0.0:
		c.draw_string(font, o + Vector2.ONE, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, shadow)
	c.draw_string(font, o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _enter_tree() -> void:
	_live += 1
	get_viewport().canvas_cull_mask &= ~(WORLD_LAYER | Lighting.NORMAL_LAYER | Lighting.BACKDROP_LAYER | Glazing.LAYER)

func _exit_tree() -> void:
	_live -= 1
	if _live == 0:
		get_viewport().canvas_cull_mask |= WORLD_LAYER | Lighting.NORMAL_LAYER | Lighting.BACKDROP_LAYER | Glazing.LAYER
		# Nothing is drawing the world any more, so the grid left for whatever is
		# drawn over it is the screen's own.
		if is_instance_valid(Pointer):
			Pointer.pixel_origin = Vector2.ZERO

func _ready() -> void:
	layer = LAYER
	# After the camera it copies has settled this frame, so the picture is
	# never a frame behind a shake.
	process_priority = 100
	# Up before the picture is, so its viewports are drawn first each frame and
	# what bends this frame bends in this frame's picture.
	velocity = VelocityBuffer.new()
	add_child(velocity)
	_view = SubViewport.new()
	_view.world_2d = get_viewport().world_2d
	_view.disable_3d = true
	_view.snap_2d_transforms_to_pixel = true
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# How the world faces is drawn for the light alone, and where the glass is
	# for the glazing alone: neither ever into the picture.
	_view.canvas_cull_mask = 0xFFFFFFFF & ~(Lighting.NORMAL_LAYER | Glazing.LAYER)
	add_child(_view)
	# After the buffer it lights, so its passes are drawn after it each frame.
	lighting = Lighting.new()
	lighting.colour = _view
	add_child(lighting)
	# After the light, so the glass is worked out in the picture it comes to.
	glazing = Glazing.new()
	add_child(glazing)
	_image = Sprite2D.new()
	_image.centered = false
	_image.texture = _view.get_texture()
	_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_grade = ShaderMaterial.new()
	_grade.shader = GRADE
	_grey = 0.0 if Magic.on else 1.0
	_slow = 1.0 if TimeCtl.is_dilated() else 0.0
	_grade.set_shader_parameter("grey", _grey)
	_grade.set_shader_parameter("slow", _slow)
	_image.material = _grade
	_clock = Time.get_ticks_usec()
	add_child(_image)
	_follow()

func _process(delta: float) -> void:
	var want := 0.0 if Magic.on else 1.0
	if _grey != want:
		_grey = move_toward(_grey, want, delta * GREY_SPEED)
		_grade.set_shader_parameter("grey", _grey)
	var now := Time.get_ticks_usec()
	var real := minf(float(now - _clock) / 1000000.0, 0.1)
	_clock = now
	var slowed := 1.0 if TimeCtl.is_dilated() else 0.0
	if _slow != slowed:
		_slow = move_toward(_slow, slowed, real * (SLOW_IN if slowed > _slow else SLOW_OUT))
		_grade.set_shader_parameter("slow", _slow)
	_follow()

## How far the picture has gone into the slow-motion look, 0 to 1.
func slow() -> float:
	return _slow

func _follow() -> void:
	var vp := get_viewport()
	var want := Vector2i((vp.get_visible_rect().size / SCALE).ceil()) + Vector2i.ONE * BORDER * 2
	if _view.size != want:
		_view.size = want
	var xf := vp.get_canvas_transform()
	var zoom := xf.get_scale().x
	var corner := xf.affine_inverse() * Vector2.ZERO    # the world at the screen's top-left
	var grid := (corner / SCALE).floor() * SCALE
	var leftover := corner - grid                       # 0..SCALE world units
	_view.canvas_transform = Transform2D(0.0, Vector2.ONE / SCALE, 0.0,
		-grid / SCALE + Vector2.ONE * BORDER)
	_image.scale = Vector2.ONE * zoom * SCALE
	_image.position = -Vector2.ONE * BORDER * SCALE * zoom - (leftover * zoom).round()
	# The buffer's first pixel is this one's, BORDER pixels out from the grid.
	velocity.follow(grid - Vector2.ONE * BORDER * SCALE, want)
	lighting.follow(grid - Vector2.ONE * BORDER * SCALE, want, _view.canvas_transform)
	glazing.follow(grid - Vector2.ONE * BORDER * SCALE, want, _view.canvas_transform, lighting.picture())
	_image.texture = glazing.picture()
	# The crosshair is drawn over this picture, at this picture's scale, by the
	# shell — which has no other way to learn where this grid starts. Handed over
	# rather than fetched: `PixelCamera` is a graphics class and the pointer is
	# not, and the standing check deletes the graphics autoloads this file needs.
	# See `Pointer.on_grid`.
	Pointer.pixel_origin = _image.position

## The picture as it is shown, lit and glazed: what the phone's camera sees
## (`PhoneScreen`).
func picture() -> Texture2D:
	return _image.texture if _image != null else null
