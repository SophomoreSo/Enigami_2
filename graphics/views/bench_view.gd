class_name BenchView
extends Node2D

## A bench to sit on (`Bench`): a seat of planks four pixels off the floor on a
## leg at each end, and a back of two slats on two posts — drawn behind whoever
## sits on it, so a body sitting down sits in front of the back and on the seat
## (`PlayerView`'s sitting pose sits on that seat). Over it, while a press would
## sit the body down, the key that does: `PixelDraw.key_cap`, as a treasure box
## and a station show it, so walking up to a bench asks for the same press the
## same way.
##
## Drawn in pixels of the buffer the world is drawn into (`paint`), which the
## map creator's table draws it with too, smaller.

const S := PixelCamera.SCALE
## The bench stands on the floor at its position: its foot is the origin.
const FLOOR := 0.0
## Its size, in pixels of the buffer: as wide, its seat this high off the floor,
## and the top of its back this high.
const WIDE := 22
const SEAT := 4
const BACK := 15
## Space between the top of the back and the bottom of the key.
const PROMPT_GAP := 6.0

var bench: Bench
var _t: float = 0.0
## The key sits on its own layer, as a treasure box's does: drawn at the
## screen's resolution in PixelDraw's blocks, and never covered by somebody
## walking past.
var _prompt_layer: CanvasLayer
var _prompt: Node2D
var _px: PixelDraw

func _ready() -> void:
	bench = get_parent() as Bench
	# Behind whoever sits on it: sorted a little up the floor from its foot.
	position.y = -6.0
	_prompt_layer = CanvasLayer.new()
	_prompt_layer.layer = PixelCamera.LAYER + 1
	_prompt_layer.follow_viewport_enabled = true
	add_child(_prompt_layer)
	_prompt = Node2D.new()
	_prompt.draw.connect(_draw_prompt)
	_prompt_layer.add_child(_prompt)
	_px = PixelDraw.new(_prompt)

func _process(delta: float) -> void:
	_t += delta
	if bench != null and is_instance_valid(bench):
		_prompt.position = (global_position / S).round() * S
	_prompt.queue_redraw()

func _draw() -> void:
	paint(self, Vector2(0.0, FLOOR), float(S))

## The bench, standing on `foot` — the middle of the floor under it — a pixel of
## the buffer `px` across: as the game draws it, and at whatever size the map
## creator's table does.
static func paint(c: CanvasItem, foot: Vector2, px: float) -> void:
	@warning_ignore("integer_division")
	var left := -WIDE / 2
	var right := left + WIDE
	var box := func(x: int, y: int, w: int, h: int, col: Color) -> void:
		c.draw_rect(Rect2(foot + Vector2(x, -y - h) * px, Vector2(w, h) * px), col)
	# The back: two posts, and a slat across them twice.
	for post in [left + 1, right - 3]:
		box.call(post, SEAT, 2, BACK - SEAT, Style.BENCH_SHADE)
	for slat in [BACK - 3, BACK - 8]:
		box.call(left, slat, WIDE, 2, Style.BENCH_SHADE)
		box.call(left, slat + 1, WIDE, 1, Style.BENCH_WOOD)
	# A leg at each end, down to the floor.
	for leg in [left + 1, right - 3]:
		box.call(leg, 0, 2, SEAT, Style.BENCH_SHADE)
	# The seat, lit along its top.
	box.call(left - 1, SEAT - 2, WIDE + 2, 2, Style.BENCH_WOOD)
	box.call(left - 1, SEAT - 1, WIDE + 2, 1, Style.BENCH_LIT)

## The interact key over the bench while a press would sit the body down.
func _draw_prompt() -> void:
	if bench == null or not is_instance_valid(bench) or not bench.offered():
		return
	_px.key_cap(Vector2(0.0, FLOOR - BACK * S - PROMPT_GAP), Controls.short_label_for("interact"), _t)
