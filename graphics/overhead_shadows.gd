class_name OverheadShadows
extends Node2D

## The shadows spotlights hung overhead cast on the floor (`MadeRoomView`'s
## spotlight, `lights`' `spotlight` row): each body standing in a spotlight's
## light lays its own silhouette — the frame its sprite is showing — on the
## floor away from the spot under the lamp, as long as a body that tall
## standing that far from it would throw under a lamp hung that high. A point
## at height z lands at distance·z / (hang − z) from the feet; taken at the
## middle of the body, that is one stretch for all of it, so the shadow is
## the sprite laid flat and drawn out along the way away from the lamp. Under
## the lamp it is a dark patch at the feet; stepping out it lengthens.
##
## A spotlight lights the ellipse of floor at the foot of its cone and nothing
## past it, so its shadows are only in that ellipse: past its rim there is
## none of its light for a body to keep off the floor. Each shadow is cut to
## it before it is drawn, and a body outside it throws none. Two spotlights
## whose pools meet give a body standing in both a shadow from each, each
## ending where its own light does.
##
## It is a picture, drawn in the world's colours before the light is worked
## out (`Lighting`), so a shadow is as dark as the light round it is bright.
## It reads the bodies it finds — anything in the `actors`, `npcs` or
## `cutscene_cast` groups whose view shows a sprite — and changes nothing.

## How dark a shadow is laid, and the patch under the feet where a body meets
## the floor whatever the lamp: its half-width and half-depth.
const DARK := Color(0.0, 0.0, 0.02, 0.8)
const FEET := Color(0.0, 0.0, 0.02, 0.5)
const FEET_SIZE := Vector2(11.0, 5.0)
## The least a lamp is above the middle of a body, so one hung lower than a
## body is tall still casts something finite.
const LEAST_ABOVE := 24.0
## How many corners an ellipse is drawn with.
const ROUND := 48
## The groups the bodies it casts are in.
const BODIES := [&"actors", &"npcs", &"cutscene_cast"]

## The spotlights: nodes standing on their cells, each giving its light
## (`Shine`) at the middle of its cell, the spot under the lamp.
var lamps: Array = []

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	for lamp in lamps:
		if lamp == null or not is_instance_valid(lamp):
			continue
		var lights: Array = Shine.on(lamp)
		if lights.is_empty():
			continue
		var light: Shine = lights[0]
		var under := to_local((lamp as Node2D).global_position + light.position)
		var radii := light.size * 0.5
		var pool := ellipse(under, radii)
		for body in _bodies():
			_cast(body, under, radii, MadeRoomView.SPOTLIGHT_HANG, pool)

## Every body there is to cast: one of each, whichever groups it is in.
func _bodies() -> Array:
	var seen := {}
	for group in BODIES:
		for n in get_tree().get_nodes_in_group(group):
			if n is Node2D and is_instance_valid(n) and not n.is_queued_for_deletion():
				seen[n] = true
	return seen.keys()

## `body`'s shadow in the light of a lamp hung `hang` over `under`, its pool
## the ellipse `radii` round it, `pool` as a polygon: nothing if the body is
## not standing in the light.
func _cast(body: Node2D, under: Vector2, radii: Vector2, hang: float, pool: PackedVector2Array) -> void:
	var view := Views.of(body)
	if view == null:
		return
	var spr = view.get("sprite")
	if not (spr is AnimatedSprite2D) or (spr as AnimatedSprite2D).sprite_frames == null:
		return
	var sprite := spr as AnimatedSprite2D
	var tex := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if tex == null:
		return
	var feet := to_local(body.global_position)
	if not inside(feet - under, radii):
		return
	var size := tex.get_size() * sprite.scale
	var art = view.get("art")
	var tall := Sprites.art_rect(String(art)).size.y * sprite.scale.y if art is String else size.y * 0.8
	var xf := lay(feet, under, tall, hang)
	# The frame where the sprite draws it, from the feet, mirrored as it is.
	var frame := Rect2(sprite.position - size * 0.5, size)
	_draw_cut(tex, frame, sprite.flip_h, xf, pool)
	var round := ellipse(feet, FEET_SIZE)
	for piece in Geometry2D.intersect_polygons(round, pool):
		draw_colored_polygon(piece, FEET)

## The frame `frame` of `tex`, laid on the floor by `xf`, cut to `pool`, and
## drawn dark: each corner of what is left taken back through `xf` to the
## place in the frame it came from, so the pixels are the sprite's own.
func _draw_cut(tex: Texture2D, frame: Rect2, mirrored: bool, xf: Transform2D, pool: PackedVector2Array) -> void:
	var quad := PackedVector2Array([xf * frame.position, xf * Vector2(frame.end.x, frame.position.y),
		xf * frame.end, xf * Vector2(frame.position.x, frame.end.y)])
	var base: Texture2D = tex
	var region := Rect2(Vector2.ZERO, tex.get_size())
	if tex is AtlasTexture:
		base = (tex as AtlasTexture).atlas
		region = (tex as AtlasTexture).region
	var back := xf.affine_inverse()
	for piece in Geometry2D.intersect_polygons(quad, pool):
		var uvs := PackedVector2Array()
		for corner in piece:
			var in_frame := (back * corner - frame.position) / frame.size
			if mirrored:
				in_frame.x = 1.0 - in_frame.x
			uvs.append((region.position + in_frame * region.size) / base.get_size())
		draw_polygon(piece, PackedColorArray([DARK]), uvs, base)

## How a body standing at `feet`, `tall` high, lies on the floor in the light
## of a lamp hung `hang` over `under`: what a point of its sprite, measured
## from the feet with up the screen negative, is laid at on the floor. Its
## height goes out along the way away from the lamp, stretched by how far it
## stands from it; its width goes across that way.
static func lay(feet: Vector2, under: Vector2, tall: float, hang: float) -> Transform2D:
	var off := feet - under
	var far := off.length()
	var away := off / far if far > 0.5 else Vector2.DOWN
	var stretch := maxf(far, 4.0) / maxf(hang - tall * 0.5, LEAST_ABOVE)
	return Transform2D(Vector2(away.y, -away.x), -away * stretch, feet)

## Whether `off`, from the middle of an ellipse `radii` across, is inside it.
static func inside(off: Vector2, radii: Vector2) -> bool:
	return Vector2(off.x / maxf(radii.x, 0.001), off.y / maxf(radii.y, 0.001)).length_squared() <= 1.0

## The ellipse `radii` round `at`, as a polygon.
static func ellipse(at: Vector2, radii: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in ROUND:
		var a := TAU * float(k) / float(ROUND)
		out.append(at + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return out
