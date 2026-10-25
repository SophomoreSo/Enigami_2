class_name LostKitView
extends Node2D

## The kit a death left on the floor, drawn to be found.
##
## A room is 1280 across and full of scrap and monsters, so this is not
## drawn as one more thing on the ground: a beam stands over it that clears the
## platforms, and a ring goes out from it on a slow pulse. Whatever else is
## happening in the room, the eye lands on it from the doorway.

var kit: LostKit
var _t: float = 0.0

## How far the beam stands over the drop. A room is 22 cells tall, so this is
## most of the height of one screen — it is meant to be seen over the furniture
## from the far side of the room, not to mark a square foot of floor.
const BEAM_H := 260.0
const BEAM_W := 10.0
## How often the ring goes out, in seconds, and how wide it gets.
const PULSE := 1.6
const PULSE_R := 70.0

func _ready() -> void:
	kit = get_parent() as LostKit
	# A beam and a ring are light already, and are drawn as their own.
	material = Lighting.glow()

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	if kit == null or not is_instance_valid(kit):
		return
	var c := Style.LOST_KIT
	var bob := sin(_t * 3.0) * 3.0
	_draw_beam(c)
	_draw_pulse(c)

	# The pack itself: a body, a flap and a strap, so it reads as something
	# somebody was carrying rather than as another crate of parts.
	var glow := c
	glow.a = 0.22 + 0.10 * sin(_t * 4.0)
	draw_circle(Vector2(0, bob), 22.0, glow)
	var dark := Color(0.08, 0.07, 0.06)
	draw_rect(Rect2(-11, bob - 9, 22, 18), c)
	draw_rect(Rect2(-11, bob - 9, 22, 18), dark, false, 2.0)
	draw_rect(Rect2(-11, bob - 3, 22, 4), dark)
	draw_rect(Rect2(-4, bob - 14, 8, 6), c)
	draw_rect(Rect2(-4, bob - 14, 8, 6), dark, false, 2.0)

## A column of light, brightest at the floor and gone by the top, so it points
## at the drop rather than hanging over it.
func _draw_beam(c: Color) -> void:
	var steps := 9
	for i in steps:
		var f := float(i) / float(steps)
		var a: float = (1.0 - f) * (0.20 + 0.06 * sin(_t * 2.5 + f * 3.0))
		var w: float = BEAM_W * (1.0 - f * 0.45)
		draw_rect(Rect2(-w * 0.5, -BEAM_H * (f + 1.0 / float(steps)),
			w, BEAM_H / float(steps)), Color(c.r, c.g, c.b, a))

## One ring on the way out at any time. It starts at the pack and fades as it
## widens, which is what makes it read as a signal rather than as a shockwave.
func _draw_pulse(c: Color) -> void:
	var f := fmod(_t, PULSE) / PULSE
	draw_arc(Vector2.ZERO, 8.0 + PULSE_R * f, 0.0, TAU, 28,
		Color(c.r, c.g, c.b, (1.0 - f) * 0.55), 2.0)
