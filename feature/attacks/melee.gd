class_name MeleeArc
extends Node2D

## An instant sweep in front of the attacker. Reach and fan angle both scale
## with payload size, which is what makes SIZE feel different on a blade.

var payload: Payload
var team: int = 0
var attacker: Actor = null
var room = null
var reach: float = 54.0
var arc: float = 1.15
var aim: float = 0.0
var life: float = 0.18
var max_life: float = 0.18
var hits_left: int = 1
var _hit: Array = []
var follow_attacker: bool = true

func setup(p: Payload, dir: Vector2, t: int, atk: Actor, rm) -> void:
	payload = p
	team = t
	attacker = atk
	room = rm
	aim = dir.angle()
	reach = 54.0 * p.size
	arc = 1.15 * clampf(p.size, 0.7, 2.2)
	hits_left = 1 + p.pierce
	if atk != null:
		position = atk.global_position

func _ready() -> void:
	_strike()

func _strike() -> void:
	if payload.homing:
		var t := Attacks.nearest_target(global_position, team, 260.0)
		if t != null:
			aim = (t.global_position - global_position).angle()
	for a in Attacks.targets(team):
		if _hit.has(a) or hits_left <= 0:
			continue
		var to: Vector2 = a.global_position - global_position
		if to.length() > reach + a.hurt_radius:
			continue
		if absf(wrapf(to.angle() - aim, -PI, PI)) > arc * 0.5:
			continue
		_hit.append(a)
		Attacks.resolve_hit(payload, a, a.global_position, to.normalized(), attacker, room, team)
		hits_left -= 1

func _process(delta: float) -> void:
	life -= delta
	if follow_attacker and attacker != null and is_instance_valid(attacker):
		position = attacker.global_position
	if life <= 0.0:
		queue_free()
