extends Node

## Screen feel: shake, impact sparks and damage numbers. Everything is drawn
## from primitives so the game needs no art assets.
##
## Nothing here changes the simulation — a shake that stops and a spark that
## fades leave the fight exactly as it was. The clock effects that *do* change
## it (hitstop, dilation) are a rule and live in `feature/core/time_control.gd`.

var camera: Camera2D = null

var _shake: float = 0.0
var _shake_decay: float = 7.0

## How deep the bars over the top and the bottom of the screen stand, in
## screen pixels: a conversation in the box brings them in, and says how deep
## they are as they come and go (`Letterbox`). Nothing under them is seen, so
## a camera taken while they are there may go that much further up or down —
## see `direct`.
var bars: float = 0.0

## The camera while something has taken it — see `direct`.
var _directing := false
var _releasing := false
var _home_pos := Vector2.ZERO
var _home_zoom := Vector2.ONE
## What it was asked to centre on, framed afresh every frame (`_framed`).
var _focus := Vector2.ZERO
var _want_zoom := Vector2.ONE
var _move_time: float = 0.4

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(d: float) -> void:
	if camera != null and is_instance_valid(camera):
		if _shake > 0.01:
			_shake = maxf(0.0, _shake - _shake_decay * (1.0 / 60.0))
			camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
		elif camera.offset != Vector2.ZERO:
			camera.offset = camera.offset.lerp(Vector2.ZERO, 0.4)
		_steer(d)

func register_camera(c: Camera2D) -> void:
	camera = c
	_directing = false
	_releasing = false

## Nothing asks whether shake is wanted before asking for it: every cue that
## lands one is describing the hit, not the setting. The setting is read here,
## once, so turning it off is one answer rather than a flag threaded through
## `CueVisuals` — and a shake already running settles back to nothing either
## way, which `_process` is what does.
func shake(amount: float) -> void:
	if not Video.screen_shake:
		return
	_shake = maxf(_shake, amount)

## Takes the screen's camera for a while — a conversation framing who is
## talking, say: centres on `focus` (a world point) at `zoom` times the screen's
## own zoom, easing there over `time` seconds, until `release` hands it back.
##
## It never zooms out past the screen's own framing, and never shows anything
## that framing did not: a close-up by a wall slides along rather than reveal the
## dark past the room. What is under the `bars` is not shown, so while there are
## any it goes as much further up or down as they are deep — as deep as they
## are at the moment, coming in or going out.
func direct(focus: Vector2, zoom: float = 1.0, time: float = 0.4) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	if not _directing:
		_directing = true
		_home_pos = camera.global_position
		_home_zoom = camera.zoom
	_releasing = false
	_want_zoom = _home_zoom * maxf(zoom, 1.0)
	_focus = focus
	_move_time = maxf(time, 0.0)

## Eases the camera back to where the screen had it, over `time` seconds.
func release(time: float = 0.4) -> void:
	if not _directing:
		return
	_releasing = true
	_focus = _home_pos
	_want_zoom = _home_zoom
	_move_time = maxf(time, 0.0)

## Whether something has the camera. A screen that moves its own camera leaves
## it be until it is handed back.
func directing() -> bool:
	return _directing

func _steer(d: float) -> void:
	if not _directing:
		return
	# Covers 99% of the way in `_move_time`, whatever the frame rate.
	var k := 1.0 if _move_time <= 0.0 else 1.0 - exp(-d * 4.6 / _move_time)
	camera.zoom = camera.zoom.lerp(_want_zoom, k)
	# Where it is going, and where that has brought it, are framed afresh every
	# frame, at the zoom it has come to and as deep as the bars stand now.
	var going := _framed(_focus, _want_zoom)
	camera.global_position = _framed(camera.global_position.lerp(going, k), camera.zoom)
	if _releasing and camera.global_position.distance_to(_home_pos) < 0.5 \
			and camera.zoom.distance_to(_home_zoom) < 0.002:
		camera.global_position = _home_pos
		camera.zoom = _home_zoom
		_directing = false
		_releasing = false

## `at`, moved no further than it must be for a camera there at `zoom` to show
## nothing the screen's own framing did not, but what is under the bars.
func _framed(at: Vector2, zoom: Vector2) -> Vector2:
	var screen := camera.get_viewport_rect().size
	var slack := screen / _home_zoom * 0.5 - screen / zoom * 0.5
	slack.y += bars / zoom.y
	slack = slack.max(Vector2.ZERO)
	return at.clamp(_home_pos - slack, _home_pos + slack)

## --- spawned visuals --------------------------------------------------------
## Loose visuals are lent to whatever screen is running rather than made for
## it and thrown away. Every moment of a fight asks for some — a hit, a jump, a
## landing, a slide down a wall asks every frame — so each kind is drawn from a
## pool of its own (`Pool`): borrowed, set going and let go of in one breath,
## it plays itself out and goes back to wait for the next. A screen that goes
## away takes back at once whatever it still had out, so none outlives the
## fight it belonged to.
var sparks := Pool.new(Spark, 64)
var rings := Pool.new(Ring, 16)
var words := Pool.new(FloatText, 24)

## The cracks slams have left in the rock, which are not lent and given back
## like the rest: a crack is a mark on the room, and stays. They are kept for
## as long as the world they were made in, by that world and the room in it —
## each [where, facing, force], where in the room's own space — so a room
## walked out of and back into has them where they were (`lay_cracks`). The
## oldest goes when a room has more than CRACKS_A_ROOM.
const CRACKS_A_ROOM := 24
var _marks: Dictionary = {}

func _world() -> Node:
	return Arena.current()

func burst(pos: Vector2, color: Color, count: int = 8, power: float = 180.0) -> void:
	var world := _world()
	if world == null:
		return
	var n := sparks.borrow(world) as Spark
	n.setup(pos, color, count, power)
	sparks.dispose(n)

func ring(pos: Vector2, color: Color, radius: float) -> void:
	var world := _world()
	if world == null:
		return
	var n := rings.borrow(world) as Ring
	n.setup(pos, color, radius)
	rings.dispose(n)

## A crack in the rock at `pos`, on a face turned to `normal`, as wide as
## `force` says — what a body slammed into a wall leaves (`Actor.SLAM_SPEED`).
## It stays: in the room the world is standing in, for as long as that world
## is up, and it is still there when the room is walked back into.
func crack(pos: Vector2, normal: Vector2, force: float) -> void:
	var world := _world()
	if world == null:
		return
	var room = world.get("room")
	if not (room is Node2D) or not is_instance_valid(room):
		return
	var here := (room as Node2D).to_local(pos)
	var key := _room_key(room)
	var marks: Array = _marks.get(key, [])
	marks.append([here, normal, force])
	while marks.size() > CRACKS_A_ROOM:
		marks.pop_front()
	_marks[key] = marks
	_forget_gone_worlds()
	_lay_crack(room, here, normal, force)

## Every crack `room` has had made in it, laid again: a room's view asks once
## the room has been built (`RoomView._on_built`).
func lay_cracks(room: Node2D) -> void:
	for m: Array in _marks.get(_room_key(room), []):
		_lay_crack(room, m[0], m[1], float(m[2]))

## The cracks in `room` as they stand, for a test to count.
func cracks_in(room: Node2D) -> Array:
	var view := Views.of(room)
	var on: Node = view if view != null else room
	return on.get_children().filter(func(c: Node) -> bool: return c is Crack and not c.is_queued_for_deletion())

## A crack put in `room`'s picture, over its rock and under everything that
## stands in front of it: a made room's ground is drawn at -7, the old rooms'
## rock at -1 — where the crack goes after it — and the rest draw their rock
## under their own view.
func _lay_crack(room: Node2D, here: Vector2, normal: Vector2, force: float) -> void:
	var view := Views.of(room)
	var on: Node = view if view != null else room
	var there := cracks_in(room)
	if there.size() >= CRACKS_A_ROOM:
		(there[0] as Node).queue_free()
	var z := 0
	if view is MadeRoomView:
		z = -6
	elif view is RoomView:
		z = -1
	var n := Crack.new()
	n.setup(here, normal, force, z)
	on.add_child(n)

## Which room of which world `room` is: the world it stands in, and its place
## on that world's floor.
static func _room_key(room: Node) -> String:
	var world := room.get_parent()
	var coord = room.get("coord")
	return "%d|%s" % [world.get_instance_id() if world != null else 0,
		str(coord) if coord != null else ""]

## The cracks of worlds that are gone — a raid over, the hideout left.
func _forget_gone_worlds() -> void:
	for key: String in _marks.keys():
		if not is_instance_id_valid(int(key.get_slice("|", 0))):
			_marks.erase(key)

func damage_number(pos: Vector2, amount: float, color: Color = Color(1, 1, 1)) -> void:
	text(pos, "%d" % int(round(amount)), color)

func text(pos: Vector2, s: String, color: Color = Color(1, 1, 1)) -> void:
	var world := _world()
	if world == null:
		return
	var n := words.borrow(world) as FloatText
	n.setup(pos, s, color)
	words.dispose(n)

## --- primitives -------------------------------------------------------------
## Each is set up afresh every time it is lent, and let go of the moment it is:
## `_disposed` is a primitive saying it has a little left to play, and it hands
## itself back to its pool once it has played it.
##
## All three are their own light (`Lighting.glow`): a spark is as bright in a
## dark room, and no lamp makes a number brighter.
class Spark extends Node2D:
	var pool: Pool = null
	var parts: Array = []
	var life: float = 0.45
	var color: Color = Color.WHITE

	func _init() -> void:
		material = Lighting.glow()

	func setup(pos: Vector2, c: Color, count: int, power: float) -> void:
		position = pos
		color = c
		z_index = 60
		life = 0.45
		parts.clear()
		for i in count:
			var a := randf() * TAU
			parts.append({
				"p": Vector2.ZERO,
				"v": Vector2(cos(a), sin(a)) * randf_range(0.4, 1.0) * power,
				"s": randf_range(1.5, 3.5),
			})
		queue_redraw()

	func _disposed() -> void:
		pass

	func _process(delta: float) -> void:
		life -= delta
		if life <= 0.0:
			pool.give_back(self)
			return
		for part in parts:
			part["p"] += part["v"] * delta
			part["v"] *= 0.90
			part["v"].y += 260.0 * delta
		queue_redraw()

	func _draw() -> void:
		var a := clampf(life / 0.45, 0.0, 1.0)
		for part in parts:
			var c := color
			c.a = a
			draw_circle(part["p"], part["s"] * a, c)

class Ring extends Node2D:
	var pool: Pool = null
	var life: float = 0.3
	var max_life: float = 0.3
	var color: Color = Color.WHITE
	var radius: float = 30.0

	func _init() -> void:
		material = Lighting.glow()

	func setup(pos: Vector2, c: Color, r: float) -> void:
		position = pos
		color = c
		radius = r
		z_index = 60
		life = max_life
		queue_redraw()

	func _disposed() -> void:
		pass

	func _process(delta: float) -> void:
		life -= delta
		if life <= 0.0:
			pool.give_back(self)
			return
		queue_redraw()

	func _draw() -> void:
		var t := 1.0 - life / max_life
		var c := color
		c.a = 1.0 - t
		draw_arc(Vector2.ZERO, radius * (0.3 + t), 0, TAU, 28, c, 2.5 + 3.0 * (1.0 - t))

## A crack in rock: jagged lines out from where a body struck it, into the rock
## and along its face, drawn on the world's pixel grid. It is a mark on the
## rock, not a light: dark, and lit as the rock is. It does not fade: it is
## the room's for as long as the room is (`Fx.crack`).
class Crack extends Node2D:
	const INK := Color(0.04, 0.03, 0.03, 0.85)
	const EDGE := Color(1.0, 1.0, 1.0, 0.18)
	var lines: Array = []

	## At `pos` in the room, `z` deep among what the room's view draws.
	func setup(pos: Vector2, normal: Vector2, force: float, z: int) -> void:
		position = pos
		z_index = z
		lines.clear()
		var reach := clampf(10.0 + 10.0 * force, 12.0, 34.0)
		var into := -normal.normalized() if normal.length() > 0.01 else Vector2.RIGHT
		var dice := RandomNumberGenerator.new()
		dice.seed = hash(pos.round())
		# Five main lines, fanned over the half the rock is in, each walked out
		# in jagged steps, and a branch off some of them.
		for i in 5:
			var a := into.angle() + lerpf(-1.35, 1.35, (float(i) + dice.randf_range(0.2, 0.8)) / 5.0)
			var length := reach * dice.randf_range(0.55, 1.0)
			var path := _walk(Vector2.ZERO, a, length, dice)
			lines.append(path)
			if dice.randf() < 0.6 and path.size() > 2:
				var from: Vector2 = path[int(path.size() / 2.0)]
				lines.append(_walk(from, a + dice.randf_range(-0.9, 0.9), length * 0.45, dice))
		queue_redraw()

	static func _walk(from: Vector2, angle: float, length: float, dice: RandomNumberGenerator) -> PackedVector2Array:
		var path := PackedVector2Array([from])
		var at := from
		var steps := maxi(2, int(length / 5.0))
		for k in steps:
			var turn := angle + dice.randf_range(-0.6, 0.6)
			at += Vector2.from_angle(turn) * (length / steps)
			path.append(at.round())
		return path

	func _draw() -> void:
		# Lines at least the pixel camera's SCALE wide, or they cover no pixel.
		for path: PackedVector2Array in lines:
			var lit := PackedVector2Array()
			for pt in path:
				lit.append(pt + Vector2(0, 2))
			draw_polyline(lit, EDGE, 2.0)
			draw_polyline(path, INK, 2.0)
		draw_circle(Vector2.ZERO, 3.0, INK)

class FloatText extends Node2D:
	var pool: Pool = null
	var life: float = 0.8
	var label: String = ""
	var color: Color = Color.WHITE

	func _init() -> void:
		material = Lighting.glow()

	func setup(pos: Vector2, s: String, c: Color) -> void:
		position = pos + Vector2(randf_range(-6, 6), -8)
		label = s
		color = c
		z_index = 70
		life = 0.8
		queue_redraw()

	func _disposed() -> void:
		pass

	func _process(delta: float) -> void:
		life -= delta
		position.y -= 46.0 * delta
		if life <= 0.0:
			pool.give_back(self)
			return
		queue_redraw()

	func _draw() -> void:
		var c := color
		c.a = clampf(life / 0.5, 0.0, 1.0)
		PixelCamera.draw_text(self, Vector2.ZERO, label, c, Color(0, 0, 0, c.a * 0.8))
