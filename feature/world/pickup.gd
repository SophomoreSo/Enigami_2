class_name Pickup
extends Node2D

## A component or scrap knocked loose by a kill. It leaps out of the monster —
## a hop up off the floor and a skid across it — and is drawn to whoever walks
## past. The loot a room is found with is not one of these: that is kept in the
## room's `TreasureBox`. `graphics/views/pickup_view.gd` draws it.
##
## It is on the floor seen from above: its position is where it is on the
## floor, and `height` how far up off it it is in its hop, which only the
## picture cares about.

signal collected(pickup: Pickup)

## The pull on one in the air, how fast it skids to a stop on the floor, and
## how much of its hop it keeps off the floor.
const GRAVITY := 900.0
const FRICTION := 240.0
const BOUNCE := 0.4

var component_id: String = ""
var scrap_amount: int = 0
## How it is going across the floor.
var velocity: Vector2 = Vector2.ZERO
## How far up off the floor it is, and how fast that is changing, up positive.
var height: float = 0.0
var vertical: float = 0.0
var room = null
var _magnet: bool = false
var _life: float = 0.0

func setup_component(id: String, pos: Vector2) -> void:
	component_id = id
	position = pos
	_leap(80.0, 180.0)

func setup_scrap(amount: int, pos: Vector2) -> void:
	scrap_amount = amount
	position = pos
	_leap(60.0, 150.0)

## Out of whatever dropped it: any way across the floor, and up.
func _leap(across: float, up: float) -> void:
	velocity = Vector2.from_angle(randf() * TAU) * randf_range(across * 0.4, across)
	vertical = randf_range(up * 0.7, up)
	height = 0.01

func _ready() -> void:
	add_to_group("pickups")

func _process(delta: float) -> void:
	_life += delta
	var players := get_tree().get_nodes_in_group("player")
	var player: Node2D = players[0] if players.size() > 0 else null

	if player != null and _life > 0.35:
		var d := global_position.distance_to(player.global_position)
		if d < 70.0:
			_magnet = true
		if _magnet:
			velocity = velocity.lerp((player.global_position - global_position).normalized() * 420.0, clampf(9.0 * delta, 0.0, 1.0))
			height = move_toward(height, 0.0, 200.0 * delta)
		if d < 18.0:
			collected.emit(self)
			Cues.at(&"pickup", global_position,
				{"id": component_id, "scrap": scrap_amount})
			queue_free()
			return

	if not _magnet:
		# The hop: up and down under the world's pull, a little bounce off the
		# floor, and the skid slowing while it is down.
		if height > 0.0 or vertical > 0.0:
			vertical -= GRAVITY * delta
			height += vertical * delta
			if height <= 0.0:
				height = 0.0
				vertical = -vertical * BOUNCE if vertical < -60.0 else 0.0
		else:
			velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
		if room != null and room.has_method("is_solid_at"):
			var next := global_position + velocity * delta
			if room.is_solid_at(next):
				velocity = -velocity * 0.5
	position += velocity * delta

func label() -> String:
	if scrap_amount > 0:
		return "%d gold" % scrap_amount
	return Components.name_for(component_id)
