class_name PetView
extends Node2D

## A pet (`Pet`): a small round thing with two eyes and a pair of ears, in the
## summon colour, glowing a little, facing the way its summoner does. It blinks.
## An OFFENSIVE one wears a scowl, and reddens as it goes for an enemy. A
## KAMIKAZE one carries a lit fuse on its head, and flashes hot as it flies at
## the one it is going to blow itself up against.
##
## It hovers: drawn up off its floor position by its height, with a small
## shadow on the floor under it.

const BODY := Color(0.62, 0.86, 0.42)
const DARK := Color(0.10, 0.12, 0.10)
const FUSE := Color(0.55, 0.42, 0.30)
const SPARK := Color(1.0, 0.85, 0.35)
const HOT := Color(1.0, 0.55, 0.25)
const BLINK_EVERY := 3.0
const BLINK_FOR := 0.12
const SHADOW := Color(0, 0, 0, 0.3)

var pet: Pet
var _t := 0.0

func _ready() -> void:
	pet = get_parent() as Pet
	material = Lighting.glow()

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	if pet == null or not is_instance_valid(pet):
		return
	var f := float(pet.facing)
	# Its shadow on the floor, then the body up off it.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 7.0, SHADOW)
	draw_set_transform(Vector2(0.0, -pet.height), 0.0, Vector2.ONE)
	# Ears, then the body over them.
	draw_rect(Rect2(Vector2(-8, -12), Vector2(4, 6)), BODY.darkened(0.15))
	draw_rect(Rect2(Vector2(4, -12), Vector2(4, 6)), BODY.darkened(0.15))
	draw_circle(Vector2.ZERO, 10.0, BODY)
	draw_circle(Vector2(-3.0 * f, 4.0), 6.0, BODY.lightened(0.15))
	# Eyes, toward the way it faces; shut for a moment every few seconds.
	var shut := fmod(_t, BLINK_EVERY) < BLINK_FOR
	for x: float in [1.0, 5.0]:
		var at := Vector2(x * f - 2.0 * f, -2.0)
		if shut:
			draw_rect(Rect2(at - Vector2(2, 0), Vector2(4, 2)), DARK)
		else:
			draw_rect(Rect2(at - Vector2(1, 2), Vector2(2, 4)), DARK)
		# The scowl: a brow over each eye, slanting in.
		if pet.offensive > 0:
			var inward := 1.0 if x > 3.0 else -1.0
			draw_line(at + Vector2(-2.0, -5.0 - inward), at + Vector2(2.0, -5.0 + inward), DARK, 2.0)
	if pet.kamikaze > 0:
		# A fuse out of the top of its head, and a spark on the end that
		# flickers as it burns.
		draw_line(Vector2(0, -10), Vector2(2, -15), FUSE, 2.0)
		var lit := 0.6 + 0.4 * sin(_t * 30.0)
		draw_circle(Vector2(3, -17), 1.5 + lit, Color(SPARK.r, SPARK.g, SPARK.b, lit))
		if pet.target != null:
			var flash := 0.5 + 0.5 * sin(_t * 40.0)
			draw_circle(Vector2.ZERO, 13.0, Color(HOT.r, HOT.g, HOT.b, 0.2 + 0.35 * flash))
	elif pet.target != null:
		draw_circle(Vector2.ZERO, 12.0, Color(1.0, 0.35, 0.3, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
