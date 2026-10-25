class_name ShadowCaster
extends Node2D

## Something that stands in a lamp's light and throws a shadow: the edges of
## it, each knowing which way it faces. It draws nothing itself. Whatever is
## lighting the picture (`Lighting`) asks which casters there are every frame,
## and has each lamp that throws shadows draw the edges near it its own way
## (`shadow.gdshader`): an edge turned from the lamp is drawn out away from it,
## and that is the edge's shadow.
##
## The edges are kept as a mesh, made once and drawn for every lamp — the
## video's shadow caster, and Unity's `ShadowUtility` it comes from: an edge is
## four corners, two that stay on it and two that go, with the way it faces
## kept where a picture's corner would keep its place in the texture. Nothing
## here is worked out again when a lamp moves, or when the caster does: where
## it is is the node's own transform.
##
## A caster is put wherever the thing that throws the shadow is, by its view:
## a room's rock is one (`RoomView`), and a body another (`ActorView`).
##
## A body throws no edges' shadow: it stands on the floor the lights are on,
## and leaves a patch of shadow at its feet, away from the light (`Lighting`).
## Its figure, what it is drawn as (`figures`), is where it stands, which no
## shadow on the floor darkens.

## The group every caster in the tree is in, which is how it is found.
const GROUP := &"shadow_casters"
## How fast the shadow at a body's feet goes as it leaves the ground and comes
## back as it lands: all of it in an eighth of a second.
const FEET_EASE := 8.0

## The edges, as `shadow.gdshader` draws them, or null with none.
var mesh: ArrayMesh = null
## What they cover, in the caster's own space.
var bounds := Rect2()
## Whether this is one closed shape that a light can be inside — a body, not
## a room's rock. A light inside one that is the body's own takes no shadow
## from it: a body on fire lights the room round it. A spot inside one still
## has the body throw a shadow (`beyond`).
var body := false
## What a body is drawn as — its sprite, and what it holds — which is its
## figure: where it stands, for the lights. With none, its outline is.
var figures: Array[CanvasItem] = []
## What it is the body of: the patch a light leaves at its feet is there while
## it stands on the floor.
var standing: CharacterBody2D = null
## How much of that shadow there is, 0 to 1. A body on a floor seen from above
## is always on it, so this is all of it; it is kept for what lifts a thing
## off the floor and wants its shadow to shrink (`Projectile.height`).
var feet := 1.0

var _shape := PackedVector2Array()

func _enter_tree() -> void:
	add_to_group(GROUP)

func _process(delta: float) -> void:
	if standing != null and is_instance_valid(standing):
		var up: float = standing.get("height") if standing.get("height") != null else 0.0
		feet = move_toward(feet, 1.0 if up <= 0.0 else 0.0, delta * FEET_EASE)

## Loose edges: `ends` two points to an edge, and `facings` the way each
## faces — out of the thing it is an edge of.
func edges(ends: PackedVector2Array, facings: PackedVector2Array) -> void:
	body = false
	_shape = PackedVector2Array()
	_build(ends, facings)

## One closed shape with no dents in it, its corners in the order a clock's
## hand passes them as it is drawn: a body.
func outline(points: PackedVector2Array) -> void:
	var edged := _outlined(points)
	_build(edged[0], edged[1])
	body = true
	_shape = points

## A box.
func box(rect: Rect2) -> void:
	outline(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y),
		rect.end, Vector2(rect.position.x, rect.end.y)]))

## What it covers, in the world.
func covers() -> Rect2:
	return global_transform * bounds

## Whether the world point `at` is inside it, for a body.
func holds(at: Vector2) -> bool:
	return body and Geometry2D.is_point_in_polygon(to_local(at), _shape)

## What draws the body: the view it is put in, which is where the world has
## it among everything else drawn.
func drawn() -> CanvasItem:
	var view := get_parent() as CanvasItem
	return view if view != null else self

## Draws a body's figure on `on`, which draws into a buffer whose canvas lies
## across the world as `view` does: on the same pixels the world draws it on,
## in `colour`, and thrown by `thrown`, a transform of the world, when that is
## anything. Each picture marks where it is solid (`bodies.gdshader`,
## `figure_shadow.gdshader`); a body with none drawn marks its outline.
func draw_figure(on: CanvasItem, view: Transform2D, colour: Color, thrown := Transform2D.IDENTITY) -> void:
	var drew := false
	for f in figures:
		if f == null or not is_instance_valid(f) or not f.is_visible_in_tree() \
				or f.modulate.a <= 0.0 or f.self_modulate.a <= 0.0:
			continue
		var picture := _picture(f)
		if picture.is_empty():
			continue
		on.draw_set_transform_matrix(thrown * view.affine_inverse() * _placed(f, view))
		on.draw_texture_rect_region(picture[0], picture[1], picture[2], colour)
		drew = true
	if not drew and body:
		on.draw_set_transform_matrix(thrown * global_transform)
		on.draw_colored_polygon(_shape, colour)
	on.draw_set_transform_matrix(Transform2D.IDENTITY)

## What a sprite draws this frame, as it draws it: its texture, where in its
## own space, and what of the texture — or nothing, for one with nothing to
## draw. An animated sprite's frame, or a sprite's region and frame, placed
## by its offset, centred or not, and turned over as it is.
static func _picture(f: CanvasItem) -> Array:
	var tex: Texture2D = null
	var from := Rect2()
	var at := Vector2.ZERO
	var centred := true
	var flip := Vector2i.ZERO
	if f is AnimatedSprite2D:
		var a := f as AnimatedSprite2D
		if a.sprite_frames == null or not a.sprite_frames.has_animation(a.animation):
			return []
		tex = a.sprite_frames.get_frame_texture(a.animation, a.frame)
		if tex == null:
			return []
		from = Rect2(Vector2.ZERO, tex.get_size())
		at = a.offset
		centred = a.centered
		flip = Vector2i(int(a.flip_h), int(a.flip_v))
	elif f is Sprite2D:
		var s := f as Sprite2D
		tex = s.texture
		if tex == null:
			return []
		var whole := s.region_rect if s.region_enabled else Rect2(Vector2.ZERO, tex.get_size())
		var cell := whole.size / Vector2(s.hframes, s.vframes)
		@warning_ignore("integer_division")
		from = Rect2(whole.position + Vector2(s.frame % s.hframes, s.frame / s.hframes) * cell, cell)
		at = s.offset
		centred = s.centered
		flip = Vector2i(int(s.flip_h), int(s.flip_v))
	else:
		return []
	if centred:
		at -= from.size * 0.5
	if f.get_viewport() != null and f.get_viewport().snap_2d_transforms_to_pixel:
		at = (at + Vector2(0.5, 0.5)).floor()
	var size := from.size
	if flip.x != 0:
		size.x = -size.x
	if flip.y != 0:
		size.y = -size.y
	return [tex, Rect2(at, size), from]

## Where a viewport that snaps to whole pixels, its canvas lying across the
## world as `view` does, draws `item`: every step down to it snapped, its own
## place and its parent's, as the engine snaps them.
static func _placed(item: CanvasItem, view: Transform2D) -> Transform2D:
	var chain: Array[CanvasItem] = []
	var n: Node = item
	while n is CanvasItem:
		chain.push_front(n as CanvasItem)
		if (n as CanvasItem).top_level:
			break
		n = n.get_parent()
	var xf := view
	for c in chain:
		var own := c.get_transform()
		own.origin = (own.origin + Vector2(0.5, 0.5)).floor()
		xf.origin = (xf.origin + Vector2(0.5, 0.5)).floor()
		xf = xf * own
	return xf

## One closed shape's edges, its corners in the order a clock's hand passes
## them: the two ends of each, and the way each faces, out of the shape.
static func _outlined(points: PackedVector2Array) -> Array:
	var ends := PackedVector2Array()
	var facings := PackedVector2Array()
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		var along := (b - a).normalized()
		ends.append(a)
		ends.append(b)
		facings.append(Vector2(along.y, -along.x))
	return [ends, facings]

func _build(ends: PackedVector2Array, facings: PackedVector2Array) -> void:
	mesh = _strips(ends, facings)
	bounds = Rect2(ends[0], Vector2.ZERO) if not ends.is_empty() else Rect2()
	for end in ends:
		bounds = bounds.expand(end)

## The edges as `shadow.gdshader` draws them, or null with none: each four
## corners, two that stay on it and two that go.
static func _strips(ends: PackedVector2Array, facings: PackedVector2Array) -> ArrayMesh:
	@warning_ignore("integer_division")
	var count := ends.size() / 2
	if count == 0:
		return null
	var points := PackedVector2Array()
	var faces := PackedVector2Array()
	var goes := PackedColorArray()
	var order := PackedInt32Array()
	for i in count:
		var a := ends[i * 2]
		var b := ends[i * 2 + 1]
		var facing := facings[i]
		var first := points.size()
		points.append_array([a, b, b, a])
		faces.append_array([facing, facing, facing, facing])
		goes.append_array([Color(0, 0, 0), Color(0, 0, 0), Color(1, 0, 0), Color(1, 0, 0)])
		order.append_array([first, first + 1, first + 2, first, first + 2, first + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_TEX_UV] = faces
	arrays[Mesh.ARRAY_COLOR] = goes
	arrays[Mesh.ARRAY_INDEX] = order
	var made := ArrayMesh.new()
	made.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return made
