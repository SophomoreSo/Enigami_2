class_name Glazing
extends Node

## Glass (`Glass`), worked out once the picture is: a pass of its own over the
## picture the pixel camera is about to show, lit or not, in two parts.
##
##   marks     the world drawn again, as the normals are (`Lighting`), for
##             where the glass is. Every pane draws itself into it as what it
##             is (`glass.gdshader`): glass, of which kind, and for a mirror
##             the way from each pixel to what it shows. Anything else draws
##             its colours, as it would anywhere, and a colour is nothing
##             beside a mark (`glazing.gdshaderinc`) — so whatever is drawn
##             over a pane afterwards wipes its mark out by as much as it
##             covers it. What stands in front of the glass is never seen
##             through it, and never in it.
##   glazed    the picture with the glass in it (`glazing.gdshader`). Under
##             clear glass, what is behind it, a little tinted. Under a mirror,
##             what is in front of it, read off the picture across the mirror's
##             face and fading the deeper into it the pixel lies, over what
##             the mirror itself was drawn as. Under a back mirror — one that
##             faces the eye — whatever stands in front of it, BACK_SHIFT off,
##             read off the marks: what they have that is not glass is what
##             the world draws in front of the back of the picture.
##
## It comes after the light, so what is seen through glass is lit as it is
## anywhere, and what a mirror shows is shown lit. A mirror shows the picture
## as it was before the glazing: one mirror seen in another shows as what was
## drawn there.
##
## The back of the picture (`Lighting.BACKDROP_LAYER`) is left out of the
## marks, as it is out of the normals: it is behind any glass put in the
## world, and most of what a frame costs to draw. So nothing of a room's tile
## field covers a pane, and a pane goes only where the tile field has nothing
## in front of it: the tile field of a made map draws its glass's frames, and
## the room's view puts a pane over each cell of glass that can be seen
## (`MadeRoomView`). And what the world draws behind the glass that is not the
## back of the picture — nothing, in a made map — is in the marks wherever no
## pane covers it, where a back mirror would show it as standing in front.
##
## With no glass on the screen nothing is worked out, and nothing drawn: the
## camera shows the picture as it came.
##
## Float buffers, as the normals', and for their reason.

## World units to a pixel of every buffer: the pixel camera's.
const S := PixelCamera.SCALE
## What is drawn on this render layer is drawn into the marks and nowhere else:
## the glass itself (`Glass`).
const LAYER := 1 << 16

## What clear glass does to what is seen through it.
const CLEAR_TINT := Color(0.84, 0.93, 0.97)
## What a mirror does to what it shows; how much of that it shows at its face,
## over what it was drawn as; and how deep into it, in pixels, that has faded
## to nothing.
const MIRROR_TINT := Color(0.78, 0.88, 0.96)
const MIRROR_SHOWS := 0.72
const MIRROR_DEEP := 40.0
## How much a back mirror shows of what stands in front of it, and how far off
## it shows it, in pixels of the buffer, across and down — a mirror hung a
## little out of true (`Glass.shift`).
const BACK_SHOWS := 0.5
const BACK_SHIFT := Vector2i(10, -4)

const MARK := preload("res://graphics/assets/shaders/glass.gdshader")
const GLAZE := preload("res://graphics/assets/shaders/glazing.gdshader")

## What each kind of glass wears, by kind: made once.
static var _worn: Dictionary = {}

## The world position of every buffer's first pixel, and their size in
## pixels: the pixel camera's.
var origin := Vector2.ZERO
var size := Vector2i.ZERO
## How many of the glass's nodes reach the screen this frame.
var glass_shown := 0

var _marks: SubViewport
var _glazed: SubViewport
var _glaze: ShaderMaterial
var _under: Texture2D
var _working := false

## What glass of `kind` wears (`glass.gdshader`): one material to a kind.
static func wear(kind: Glass.Kind) -> ShaderMaterial:
	if not _worn.has(kind):
		var m := ShaderMaterial.new()
		m.shader = MARK
		m.set_shader_parameter("kind", int(kind))
		_worn[kind] = m
	return _worn[kind]

func _ready() -> void:
	# In the order they are drawn each frame, after the picture: where the glass
	# is, and the picture with it in.
	_marks = _viewport(true)
	_marks.world_2d = get_viewport().world_2d
	_marks.snap_2d_transforms_to_pixel = true
	# Nothing but nothing where no glass is, whatever the project clears to.
	_marks.transparent_bg = true
	_marks.canvas_cull_mask = 0xFFFFFFFF & ~(Lighting.BACKDROP_LAYER | Lighting.NORMAL_LAYER)
	_glazed = _viewport(false)
	# Over the whole picture wherever the camera is: on a layer of its own.
	var over := CanvasLayer.new()
	over.layer = -1
	_glazed.add_child(over)
	var all := ColorRect.new()
	all.set_anchors_preset(Control.PRESET_FULL_RECT)
	all.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glaze = ShaderMaterial.new()
	_glaze.shader = GLAZE
	_glaze.set_shader_parameter("marks", _marks.get_texture())
	_glaze.set_shader_parameter("clear_tint", Vector3(CLEAR_TINT.r, CLEAR_TINT.g, CLEAR_TINT.b))
	_glaze.set_shader_parameter("mirror_tint", Vector3(MIRROR_TINT.r, MIRROR_TINT.g, MIRROR_TINT.b))
	_glaze.set_shader_parameter("mirror_shows", MIRROR_SHOWS)
	_glaze.set_shader_parameter("mirror_deep", MIRROR_DEEP)
	_glaze.set_shader_parameter("back_shows", BACK_SHOWS)
	all.material = _glaze
	over.add_child(all)

func _viewport(float_buffer: bool) -> SubViewport:
	var v := SubViewport.new()
	v.disable_3d = true
	v.use_hdr_2d = float_buffer
	v.size = Vector2i.ONE
	v.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(v)
	return v

## The picture to show: the one it was handed, with the glass in it — or as it
## was handed, with no glass on the screen.
func picture() -> Texture2D:
	return _glazed.get_texture() if _working else _under

## Whether there is any glass on the screen to work out this frame.
func working() -> bool:
	return _working

## The marks, as a texture: see `glazing.gdshaderinc` for what a pixel holds.
func marks() -> Texture2D:
	return _marks.get_texture()

## The world rect the buffers cover.
func area() -> Rect2:
	return Rect2(origin, Vector2(size) * S)

## The buffers cover `texels` pixels from `at`, the world position of the
## first, `view` is how the world lies across them, and `under` is the picture
## the glass goes into — the light's (`Lighting.picture`). Called by the
## camera every frame, after the light.
func follow(at: Vector2, texels: Vector2i, view: Transform2D, under: Texture2D) -> void:
	origin = at
	_under = under
	if texels != size:
		size = texels
		_marks.size = size
		_glazed.size = size
	glass_shown = _shown()
	_working = glass_shown > 0
	var mode := SubViewport.UPDATE_ALWAYS if _working else SubViewport.UPDATE_DISABLED
	_marks.render_target_update_mode = mode
	_glazed.render_target_update_mode = mode
	if not _working:
		return
	_marks.canvas_transform = view
	_glaze.set_shader_parameter("picture", under)

## How many of the glass's nodes have a pane on the screen.
func _shown() -> int:
	var shown := area()
	var n := 0
	for node in get_tree().get_nodes_in_group(Glass.GROUP):
		var glass := node as Glass
		if glass != null and glass.panes() > 0 and glass.is_visible_in_tree() and shown.intersects(glass.covers()):
			n += 1
	return n
