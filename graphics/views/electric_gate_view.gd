class_name ElectricGateView
extends Node2D

## An electric gate (`ElectricGate`): a post at either end of the doorway it
## stands across, and between them, while it is up, two beams crackling red —
## each a pixel wide, jumping a pixel off true here and there, a bright spark
## running down them — which light the doorway (`Shine`, "electric_gate").
## Down, the posts' emitters are dark and the doorway is empty. Going down and
## coming up is the cue's (`gate`), and a body shocked by it (`gate_shock`).
##
## Drawn in pixels of the buffer the world is drawn into: along the gate, from
## the end at the top or the left, and across it from its middle.

const S := PixelCamera.SCALE
## A post's length along the gate and its width across it, in pixels.
const POST_LONG := 3
const POST_WIDE := 7
## Where the two beams run across the gate, from its middle.
const BEAMS := [-2, 2]
const POST := Color(0.30, 0.32, 0.36)
const POST_LIT := Color(0.55, 0.58, 0.64)
const POST_DARK := Color(0.12, 0.13, 0.16)
const EMITTER_ON := Color(1.0, 0.45, 0.52)
const EMITTER_OFF := Color(0.24, 0.08, 0.10)
const BEAM := Color(1.0, 0.24, 0.38)
const BEAM_CORE := Color(1.0, 0.86, 0.9)

var gate: ElectricGate
var _t := 0.0

func _ready() -> void:
	gate = get_parent() as ElectricGate
	gate.switched.connect(func(_up: bool) -> void: _light())
	_light()

## Its light while it is up: the shape of its beams, as long as they are.
func _light() -> void:
	Shine.put_out(self)
	if not gate.is_up():
		return
	var s := Shine.of("electric_gate")
	if gate.upright():
		s.size.y = gate.span.size.y
	else:
		# Turned to shine along the gate's own way across the screen.
		s.direction = 0.0
		s.size.y = gate.span.size.x
	Shine.give(self, s, gate.span.get_center())

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	if gate == null or not is_instance_valid(gate):
		return
	var up := gate.is_up()
	var n := int((gate.span.size.y if gate.upright() else gate.span.size.x) / S)
	# The beams, between the posts: flickering, a pixel off true where they
	# crackle, and a spark running down each.
	if up:
		var on := 0.75 + 0.25 * sin(_t * 41.0)
		var spark := int(fmod(_t * 60.0, float(n)))
		for b in BEAMS.size():
			for i in range(POST_LONG, n - POST_LONG):
				var crackle := _crackle(i, b)
				var col := BEAM_CORE if absi(i - spark) <= 1 else Color(BEAM, on)
				_box(i, int(BEAMS[b]) + crackle, 1, 1, col)
	# The posts at either end, each with its emitter facing the other.
	for end in 2:
		var from := 0 if end == 0 else n - POST_LONG
		@warning_ignore("integer_division")
		var side := -POST_WIDE / 2
		_box(from, side, POST_LONG, POST_WIDE, POST)
		_box(from, side, POST_LONG, 1, POST_LIT)
		_box(from, side + POST_WIDE - 1, POST_LONG, 1, POST_DARK)
		var face := from + POST_LONG - 1 if end == 0 else from
		_box(face, -2, 1, 5, EMITTER_ON if up else EMITTER_OFF)

## How far pixel `i` of beam `b` jumps off true this moment: now and then a
## pixel either way, the same for a few frames.
func _crackle(i: int, b: int) -> int:
	var tick := int(_t * 24.0)
	var h := absi(hash(Vector3i(i >> 1, b, tick)))
	if h % 9 == 0:
		return 1
	if h % 9 == 1:
		return -1
	return 0

## A run of pixels `long` along the gate from pixel `along`, and `wide` across
## it from pixel `across` — the gate's middle is 0 across.
func _box(along: int, across: int, long: int, wide: int, col: Color) -> void:
	var r := gate.span
	var at: Vector2
	var size: Vector2
	if gate.upright():
		at = Vector2(r.get_center().x + across * S, r.position.y + along * S)
		size = Vector2(wide, long) * S
	else:
		at = Vector2(r.position.x + along * S, r.get_center().y + across * S)
		size = Vector2(long, wide) * S
	draw_rect(Rect2(at, size), col)
