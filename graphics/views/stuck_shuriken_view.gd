class_name StuckShurikenView
extends Node2D

## A shuriken where it struck (`StuckShuriken`): the star, standing in the wall
## or the monster with a point in it, the way it was going, or lying on the
## floor where it came down. Coming down, it turns over as it falls, drawn up
## off the floor by its height.
##
## One that can be taken back glints now and then, a pixel of light running
## along it, so a wall with several in it says where they are without a mark
## over each — and each glints in its own time, or a room of them would flash.

## How fast one coming down turns over, in radians a second.
const TUMBLE := 18.0
## How often it glints, in seconds, and for how long.
const GLINT_EVERY := 1.6
const GLINT_FOR := 0.18
const GLINT := Color(1, 1, 1, 0.85)

var shuriken: StuckShuriken
var _t: float = 0.0
var _spin: float = 0.0

func _ready() -> void:
	shuriken = get_parent() as StuckShuriken
	_t = randf() * GLINT_EVERY

func _process(delta: float) -> void:
	if shuriken == null or not is_instance_valid(shuriken):
		return
	_t += delta
	if shuriken.falling:
		_spin += delta * TUMBLE
	else:
		_spin = shuriken.heading.angle()
	queue_redraw()

func _draw() -> void:
	if shuriken == null or not is_instance_valid(shuriken):
		return
	var at := Vector2(0.0, -shuriken.height)
	var tex := Sprites.texture(Style.shuriken_art(_spin))
	if tex == null:
		draw_circle(at, 3.0, Style.weapon_color(shuriken.weapon))
		return
	draw_set_transform(at, 0.0, Vector2.ONE * Sprites.PIXEL_SCALE)
	draw_texture(tex, -(tex.get_size() * 0.5).floor())
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if shuriken.stuck() and fmod(_t, GLINT_EVERY) < GLINT_FOR:
		var px := Sprites.PIXEL_SCALE
		var k := fmod(_t, GLINT_EVERY) / GLINT_FOR
		# Down the lit arm, from the top left of the star towards its hole.
		var glint := Vector2(-3.0 + 2.0 * k, -3.0 + 2.0 * k).round() * px
		draw_rect(Rect2(glint, Vector2(px, px)), GLINT)
