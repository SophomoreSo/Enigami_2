class_name CrateView
extends Node2D

## A crate with gold in it (`Crate`): a little box of planks, lit along its
## top, with a cross brace on its front and a glint of gold between the planks
## of its lid so it reads as worth breaking. Broken, it is gone — the
## splinters and the coins are the cue's (`crate_break`) and the pickups'.
##
## Drawn in pixels of the buffer the world is drawn into (`paint`), which the
## map creator's table draws it with too, smaller.

const S := PixelCamera.SCALE
## Its size, in pixels of the buffer: as wide, its front this tall, and its lid
## this deep up the screen behind the front.
const WIDE := 10
const FRONT := 7
const LID := 3
const WOOD := Color(0.55, 0.36, 0.18)
const WOOD_LIT := Color(0.74, 0.52, 0.28)
const WOOD_DARK := Color(0.33, 0.20, 0.09)
const EDGE := Color(0.14, 0.08, 0.04)
const GOLD := Color(1.0, 0.84, 0.36)

var crate: Crate

func _ready() -> void:
	crate = get_parent() as Crate

func _draw() -> void:
	paint(self, Vector2.ZERO, float(S))

## The crate, standing on `foot` — the middle of the floor under its front — a
## pixel of the buffer `px` across: as the game draws it, and at whatever size
## the map creator's table does.
static func paint(c: CanvasItem, foot: Vector2, px: float) -> void:
	@warning_ignore("integer_division")
	var left := -WIDE / 2
	var box := func(x: int, y: int, w: int, h: int, col: Color) -> void:
		c.draw_rect(Rect2(foot + Vector2(x, -y - h) * px, Vector2(w, h) * px), col)
	# Its shadow on the floor, and the outline round the whole of it.
	box.call(left, -1, WIDE + 1, 1, Color(0.0, 0.0, 0.0, 0.35))
	box.call(left - 1, 0, WIDE + 2, FRONT + LID + 1, EDGE)
	# The front: planks across, a darker seam between them, and a brace from
	# corner to corner.
	box.call(left, 0, WIDE, FRONT, WOOD)
	box.call(left, 3, WIDE, 1, WOOD_DARK)
	box.call(left, 0, 1, FRONT, WOOD_DARK)
	box.call(left + WIDE - 1, 0, 1, FRONT, WOOD_DARK)
	for k in WIDE - 2:
		@warning_ignore("integer_division")
		box.call(left + 1 + k, 1 + (k * (FRONT - 2)) / (WIDE - 3), 1, 1, WOOD_DARK)
	# The lid, lit, with the gold showing through the gap between its planks.
	box.call(left, FRONT, WIDE, LID, WOOD_LIT)
	box.call(left, FRONT + 1, WIDE, 1, WOOD)
	box.call(-1, FRONT + 1, 2, 1, GOLD)
