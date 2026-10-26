class_name BirdView
extends Node2D

## A bird (`Bird`): a small pale one seen side on, a dove's grey with a white
## breast and a dark line round it, so it reads on a floor at night — a pixel
## of the buffer the world is drawn into a letter of its art. On the floor it
## stands and pecks, its head going down for a moment every so often, facing
## the way it last turned; flown, it flaps up off its shadow, the shadow left
## on the floor smaller and fainter the higher it gets.
##
## Drawn by `paint`, which the map creator's table draws it with too, smaller.

const S := PixelCamera.SCALE
## Its art, facing right, its feet on the bottom row: `#` its back, `+` its
## breast, `o` its eye, `>` its beak, `|` its legs. Round all of it, wherever
## it stops, is drawn a line (`EDGE`).
const STAND := [
	"....##..",
	"...#o#>.",
	".####+..",
	"####++..",
	".####+..",
	"..|.|...",
]
const PECK := [
	"........",
	"........",
	".####...",
	"####+#..",
	".###+o#.",
	"..|.|.>.",
]
const WINGS_UP := [
	"..#......",
	"..##.....",
	".#####o>.",
	"..###....",
]
const WINGS_DOWN := [
	".........",
	".#####o>.",
	"..###....",
	"..##.....",
]
const BACK := Color(0.64, 0.67, 0.74)
const BREAST := Color(0.95, 0.94, 0.91)
const EDGE := Color(0.09, 0.08, 0.11)
const EYE := Color(0.05, 0.04, 0.04)
const BEAK := Color(0.96, 0.66, 0.22)
const SHADOW := Color(0.0, 0.0, 0.0, 0.3)
## How often it pecks, at the least and the most, how long its head is down,
## and how many times a second its wings beat in flight.
const PECK_EVERY := Vector2(0.9, 2.6)
const PECK_FOR := 0.22
const BEATS := 12.0

var bird: Bird
var _t: float = 0.0
var _next_peck: float = 0.0
var _peck: float = 0.0

func _ready() -> void:
	bird = get_parent() as Bird
	_next_peck = randf_range(PECK_EVERY.x, PECK_EVERY.y)

func _process(delta: float) -> void:
	_t += delta
	if _peck > 0.0:
		_peck -= delta
	else:
		_next_peck -= delta
		if _next_peck <= 0.0:
			_next_peck = randf_range(PECK_EVERY.x, PECK_EVERY.y)
			_peck = PECK_FOR
	queue_redraw()

func _draw() -> void:
	if bird == null or not is_instance_valid(bird):
		return
	var px := float(S)
	# Its shadow on the floor where it is, fading as it climbs.
	var fade := clampf(1.0 - bird.height / (Bird.CLIMB * Bird.FLIGHT), 0.0, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 3.0 * px * (0.5 + 0.5 * fade), Color(SHADOW, SHADOW.a * fade))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var art: Array = STAND
	if bird.flying:
		art = WINGS_UP if fmod(_t * BEATS, 2.0) < 1.0 else WINGS_DOWN
	elif _peck > 0.0:
		art = PECK
	paint(self, Vector2(0.0, -bird.height), px, art, bird.facing)

## `art` standing on `foot` — the middle of its bottom row — a pixel of the
## buffer `px` across, facing right for a `facing` of 1 and left for -1: as the
## game draws it, and at whatever size the map creator's table does.
static func paint(c: CanvasItem, foot: Vector2, px: float, art: Array = STAND, facing: int = 1) -> void:
	var rows := art.size()
	var wide := String(art[0]).length()
	var at := func(x: int, y: int) -> Vector2:
		@warning_ignore("integer_division")
		var across := x - wide / 2 if facing >= 0 else wide / 2 - 1 - x
		return foot + Vector2(across, y - rows) * px
	var filled := func(x: int, y: int) -> bool:
		return x >= 0 and y >= 0 and x < wide and y < rows and String(art[y])[x] != "."
	# The line round it: every pixel beside one of it that is not one of it.
	for y in range(-1, rows + 1):
		for x in range(-1, wide + 1):
			if filled.call(x, y):
				continue
			if filled.call(x - 1, y) or filled.call(x + 1, y) or filled.call(x, y - 1) or filled.call(x, y + 1):
				c.draw_rect(Rect2(at.call(x, y), Vector2.ONE * px), EDGE)
	for y in rows:
		var row := String(art[y])
		for x in wide:
			var col: Color
			match row[x]:
				"#":
					col = BACK
				"+":
					col = BREAST
				"o":
					col = EYE
				">", "|":
					col = BEAK
				_:
					continue
			c.draw_rect(Rect2(at.call(x, y), Vector2.ONE * px), col)
