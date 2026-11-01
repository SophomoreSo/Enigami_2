class_name ElectricGate
extends StaticBody2D

## An electric gate: beams across a doorway, standing in anybody's way and
## shocking whoever walks into them — while power comes to it down a wire
## (`Wire`) from a generator that is running (`Generator`). The moment none
## does, it is down: two dead posts, and the doorway open.
##
## Up, it stands on the walls' layer, so a body stops at it as at a wall; a
## bolt flies through it as it would through light. A body pressing into it is
## shocked — hurt a little and thrown back the way it came — no oftener than
## `SHOCK_EVERY`. Whether it is up is its power's to say and nothing else's:
## its generator crashed, it goes down; the place set again, it comes back.
##
## It stands where its foot is, the middle of the bottom of the cells it
## stands across, so it sorts among the bodies by it; `span` is those cells in
## its own space. `graphics/views/electric_gate_view.gd` draws it.

## It went down, its power gone, or came back up.
signal switched(up: bool)

## What a shock does: how much it hurts, how hard it throws the body back, and
## how long before the same body is shocked again.
const SHOCK_DAMAGE := 6.0
const SHOCK_THROW := 420.0
const SHOCK_EVERY := 0.6
## How far out of the beams the feet of a body pressing into them are, and a
## little: a body's footprint reaches half its width round its feet.
const SHOCK_REACH := 14.0

## The cells it stands across, in its own space: up from its foot.
var span := Rect2()
## The wires its power comes down.
var feeds: Array[Wire] = []
var _up := true
var _shape: CollisionShape2D
## Seconds before each body it has shocked can be shocked again, by body.
var _shocked: Dictionary = {}

## Stands it across `cells`, a rect of the room in the room's own space: its
## foot at the middle of their bottom edge.
func across(cells: Rect2) -> void:
	position = Vector2(cells.get_center().x, cells.end.y)
	span = Rect2(Vector2(-cells.size.x * 0.5, -cells.size.y), cells.size)

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var box := RectangleShape2D.new()
	box.size = span.size
	_shape = CollisionShape2D.new()
	_shape.shape = box
	_shape.position = span.get_center()
	add_child(_shape)
	_up = powered()
	_shape.disabled = not _up

## Whether power comes to it: down any wire whose generator runs.
func powered() -> bool:
	for w in feeds:
		if w.live():
			return true
	return false

## Whether it is up: standing across the way, beams and all.
func is_up() -> bool:
	return _up

## Whether it stands up and down the screen, across a doorway in a wall
## running that way, rather than across it.
func upright() -> bool:
	return span.size.y >= span.size.x

## The cells it stands across, in the world.
func world_span() -> Rect2:
	return Rect2(to_global(span.position), span.size)

func _physics_process(delta: float) -> void:
	var now := powered()
	if now != _up:
		_up = now
		_shape.set_deferred("disabled", not _up)
		Cues.at(&"gate", world_span().get_center(), {"up": _up, "upright": upright()})
		switched.emit(_up)
	for body in _shocked.keys():
		_shocked[body] = float(_shocked[body]) - delta
		if _shocked[body] <= 0.0 or not is_instance_valid(body):
			_shocked.erase(body)
	if _up:
		_shock_whoever_presses()

## Every body pressing into the beams, shocked: hurt, and thrown back off them
## the way it came at them.
func _shock_whoever_presses() -> void:
	var near := world_span().grow(SHOCK_REACH)
	var middle := world_span().get_center()
	# A copy: a shock can bring a body down, and the list with it.
	for a: Actor in Arena.actors().duplicate():
		if not is_instance_valid(a) or a.dead or a.team == Crate.TEAM or _shocked.has(a) or not near.has_point(a.global_position):
			continue
		var back := Vector2(signf(a.global_position.x - middle.x), 0.0) if upright() \
			else Vector2(0.0, signf(a.global_position.y - middle.y))
		if back == Vector2.ZERO:
			back = Vector2.LEFT if upright() else Vector2.DOWN
		_shocked[a] = SHOCK_EVERY
		a.apply_damage(SHOCK_DAMAGE)
		a.knockback(back, SHOCK_THROW)
		Cues.at(&"gate_shock", a.global_position, {"actor": a, "back": back})
