class_name Headbutt
extends DashSlash

## PUNCH: a fist thrown along the aim from where the attacker stands, into the
## first enemy in the way and no further. The attacker does not move: it is
## a blow, not a lunge, and SWIFT STRIKE is the form that carries a body along
## the aim. PIERCE carries the fist on into the next one, and it stops against
## the last it strikes. It is the one attack with no weapon in it
## (`Weapons.BARE_FORMS`). It draws as a lunge's line does (`DashSlashView`),
## from the body to where the fist stopped.

## Which way the fist goes. `to` is no use for it: against a wall it can be
## `from` itself.
var aim: Vector2 = Vector2.RIGHT

func _cut() -> void:
	var length := from.distance_to(to)
	# The fist is out in front of the body by the body's own reach, so what it
	# meets is whatever stands that close to the end of the line it reaches.
	var front: float = attacker.hurt_radius if attacker != null and is_instance_valid(attacker) else 0.0
	var met: Array = []
	for a in Attacks.targets(team):
		var off: Vector2 = a.global_position - from
		var along := off.dot(aim)
		if along < -a.hurt_radius:
			continue   # behind it
		if absf(off.cross(aim)) > thickness + a.hurt_radius:
			continue   # beside the line
		if along - a.hurt_radius - front > length:
			continue   # further than it goes
		met.append([along, a])
	met.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	var hits_left := 1 + payload.pierce
	var stop := length
	for entry in met:
		var a: Actor = entry[1]
		Attacks.resolve_hit(payload, a, a.global_position, aim, attacker, room, team)
		hits_left -= 1
		if hits_left <= 0:
			# Spent on this one: the fist stops against it.
			stop = clampf(float(entry[0]) - a.hurt_radius - front, 0.0, length)
			break
	# Where the fist got to, which is all that is drawn. The body stays put.
	to = from + aim * (stop + front)
