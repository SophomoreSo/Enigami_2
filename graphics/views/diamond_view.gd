class_name DiamondView
extends Node2D

## The ghost test's diamond (`Diamond`), cut in pixels of the world's picture:
## a pale stone with its facets lit, a glint running across it, and while it
## lies anywhere but in a hand, a slow glow on the floor under it so it is found
## again from across the hall. Carried, it rides still over the carrier's head,
## lifted off the floor by the diamond's own `height`.

## The stone, a pixel of the picture a letter: `#` its edge, `+` its face, `*`
## the table that catches the light.
const STONE := [
	"..#####..",
	".#*+*+*#.",
	"#########",
	".#+++++#.",
	"..#+++#..",
	"...#+#...",
	"....#....",
]
const EDGE := Color(0.62, 0.9, 1.0)
const FACE := Color(0.82, 0.97, 1.0)
const TABLE := Color(1.0, 1.0, 1.0)
const GLOW := Color(0.55, 0.88, 1.0)
## How often a glint crosses it, in seconds, and how long it takes to.
const GLINT_EVERY := 1.6
const GLINT_TIME := 0.3

var diamond: Diamond
var _t: float = 0.0

func _ready() -> void:
	diamond = get_parent() as Diamond
	# Over the room and whoever stands in it: it is the one thing to find.
	z_index = 40
	material = Lighting.glow()

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	if diamond == null or not is_instance_valid(diamond):
		return
	var px := float(Sprites.PIXEL_SCALE)
	var w := float((STONE[0] as String).length())
	var h := float(STONE.size())
	# Standing on its point: the stone's foot on the floor where it lies, and
	# up off it by however high it is carried.
	var foot := Vector2(0.0, -diamond.height)
	var top_left := (foot - Vector2(w * 0.5, h) * px).floor()
	if diamond.carrier == null:
		var a := 0.18 + 0.1 * sin(_t * 3.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, 10.0 * px, Color(GLOW, a * 0.4))
		draw_circle(Vector2.ZERO, 5.0 * px, Color(GLOW, a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# The glint: one column of the stone lit white, sweeping left to right.
	var into := fmod(_t, GLINT_EVERY)
	var glint := int(into / GLINT_TIME * w) if into < GLINT_TIME else -1
	for y in STONE.size():
		var row := String(STONE[y])
		for x in row.length():
			var ch := row[x]
			if ch == ".":
				continue
			var col := EDGE if ch == "#" else (TABLE if ch == "*" else FACE)
			if x == glint or x == glint - 1:
				col = TABLE
			draw_rect(Rect2(top_left + Vector2(x, y) * px, Vector2.ONE * px), col)
