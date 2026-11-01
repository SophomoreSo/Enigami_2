class_name WireSight
extends CanvasLayer

## What Legna Dennis's sight shows (`Sight`, "wires"): every wire there is
## (`Wire`), drawn over the picture the world is shown in — which goes dark
## under it while the sight is on (`PixelCamera`) — so what is under the floor
## and in the walls is seen through them.
##
## A wire carrying power glows, and sparks run down it the way the power goes:
## from its generator to what it powers. One whose generator is crashed is
## dull, and nothing runs down it. Each generator at the end of one is ringed,
## green while it runs and red once it is crashed, since a generator is what
## following a wire is for; and what it powers at the other end — an electric
## gate's beams — is lit while it is up and dull once it is down.
##
## Over the picture rather than in it, on a layer of its own just above the
## pixel camera's, and lying across the world as the camera has it; drawn on
## the art's grid all the same, a pixel of the buffer SCALE world units
## across, so it reads as part of the picture.

const LAYER := PixelCamera.LAYER + 1
const S := PixelCamera.SCALE
## How fast the sight comes on and goes off: all of it in this share of a
## second.
const FADE_SPEED := 6.0
## How fast the sparks run down a live wire, in world units a second, and how
## far apart they are.
const SPARK_SPEED := 150.0
const SPARK_GAP := 72.0
const CABLE := Color(0.62, 0.48, 0.22)
const GLOW := Color(1.0, 0.86, 0.32, 0.28)
const SPARK := Color(1.0, 0.97, 0.7)
const DEAD := Color(0.36, 0.37, 0.42)
const RUNNING := Color(0.45, 1.0, 0.55)
const CRASHED := Color(1.0, 0.3, 0.3)
const POWERED := Color(1.0, 0.36, 0.46)

var _fade := 0.0
var _t := 0.0
var _painter: Painter

func _ready() -> void:
	layer = LAYER
	follow_viewport_enabled = true
	_painter = Painter.new()
	_painter.sight = self
	_painter.visible = false
	add_child(_painter)

func _process(delta: float) -> void:
	_t += delta
	var want := 1.0 if Sight.seeing == "wires" else 0.0
	_fade = move_toward(_fade, want, delta * FADE_SPEED)
	_painter.visible = _fade > 0.0
	if _painter.visible:
		_painter.queue_redraw()

## How far the sight is on, 0 to 1.
func shown() -> float:
	return _fade

## Draws every wire in the tree as the sight shows it.
class Painter extends Node2D:
	var sight: WireSight

	func _draw() -> void:
		var a := sight.shown()
		var ringed := {}
		var lit := {}
		for n in get_tree().get_nodes_in_group(Wire.GROUP):
			var w := n as Wire
			if w == null or not w.is_inside_tree() or w.path.size() < 2:
				continue
			var path := w.world_path()
			var live := w.live()
			for i in range(1, path.size()):
				_run(path[i - 1], path[i], live, a)
			if live:
				_sparks(path, w.length(), a)
			var g := w.generator
			if g != null and is_instance_valid(g) and not ringed.has(g):
				ringed[g] = true
				_ring(g.global_position + Vector2(0.0, -Generator.H * 0.5), g.running(), a)
			var gate := w.powers as ElectricGate
			if gate != null and is_instance_valid(gate) and not lit.has(gate):
				lit[gate] = true
				_gate(gate, a)

	## A stretch of wire from `from` to `to`, along a row or down a column: its
	## glow round it while it is live, and the cable down its middle.
	func _run(from: Vector2, to: Vector2, live: bool, a: float) -> void:
		var r := _line(from, to, 1)
		if live:
			draw_rect(r.grow(S), Color(WireSight.GLOW, WireSight.GLOW.a * a))
		draw_rect(r, Color(WireSight.CABLE if live else WireSight.DEAD, a))

	## The sparks running down a live wire from its generator's end, `length`
	## long: one every SPARK_GAP, each a few pixels of light.
	func _sparks(path: PackedVector2Array, length: float, a: float) -> void:
		var head := fmod(sight._t * WireSight.SPARK_SPEED, WireSight.SPARK_GAP)
		while head < length:
			var at := _along(path, head)
			var p := (at / S).floor() * S
			draw_rect(Rect2(p - Vector2.ONE * S, Vector2.ONE * S * 3.0), Color(WireSight.SPARK, a))
			head += WireSight.SPARK_GAP

	## The ring round a generator at the end of a wire: green while it runs, red
	## once it is crashed, pulsing.
	func _ring(at: Vector2, running: bool, a: float) -> void:
		var pulse := 0.5 + 0.5 * sin(sight._t * 5.0)
		var col := WireSight.RUNNING if running else WireSight.CRASHED
		draw_arc(at, 26.0 + pulse * 4.0, 0.0, TAU, 32, Color(col, a * (0.55 + 0.45 * pulse)), float(S))

	## An electric gate at the far end of a wire, where its beams are: lit while
	## it is up, with a glow round them, and dull once it is down.
	func _gate(gate: ElectricGate, a: float) -> void:
		var r := gate.world_span()
		var line := _line(Vector2(r.get_center().x, r.position.y), Vector2(r.get_center().x, r.end.y), 1) \
			if gate.upright() else _line(Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y), 1)
		if gate.is_up():
			draw_rect(line.grow(S * 2), Color(WireSight.POWERED, 0.3 * a))
			draw_rect(line, Color(WireSight.POWERED, a))
		else:
			draw_rect(line, Color(WireSight.DEAD, a))

	## The point `d` along `path` from its start.
	static func _along(path: PackedVector2Array, d: float) -> Vector2:
		for i in range(1, path.size()):
			var seg := path[i - 1].distance_to(path[i])
			if d <= seg:
				return path[i - 1].move_toward(path[i], d)
			d -= seg
		return path[path.size() - 1]

	## The rect a stretch from `from` to `to` covers, `wide` pixels of the
	## buffer across its way, on the art's grid.
	static func _line(from: Vector2, to: Vector2, wide: int) -> Rect2:
		var lo := (from.min(to) / S).floor() * S
		var hi := (from.max(to) / S).floor() * S + Vector2.ONE * S * wide
		return Rect2(lo, hi - lo)
