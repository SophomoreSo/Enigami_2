class_name Crate
extends Actor

## A little wooden box on a room's floor with a few coins in it. Anything that
## strikes it breaks it — a blow, a bolt, a thrown rock, a monster's blast —
## and the gold it held spills out across the floor (`Pickup`) for the player
## to walk over. Broken, it is gone for the rest of the raid.
##
## It is an actor so that every attack there is reaches it the way it reaches
## a monster (`Attacks.targets`): on a side of its own, `TEAM`, which the
## player's side and the monsters' alike can strike. But it is nothing to go
## after — a homing bolt, an aimed blow, a pet and the aim's pull all look past
## it (`Actor.sought`) — and breaking it is no kill. It does not move, burn,
## chill or stun, and a body walks round it: it stands on the walls' layer.
##
## Its record is the room's own (`Room` keeps them under `crates`), shared
## rather than copied: `pos`, the `gold` in it, and whether it is `broken`, so
## a room walked out of and back into has its crates as they were left. Where
## one stands is laid in the map creator (`MadeRoom.CRATE`).
## `graphics/views/crate_view.gd` draws it.

## Broken open: its gold is to spill where it stood.
signal broke(crate: Crate)

## The side crates are on: neither the player's (0) nor the monsters' (1).
const TEAM := 2
## How wide it stands on the floor, and how tall up the screen from its feet.
const W := 18.0
const H := 16.0

var record: Dictionary = {}

func setup(rec: Dictionary) -> void:
	record = rec
	var p: Array = rec.get("pos", [])
	if p.size() == 2:
		position = Vector2(float(p[0]), float(p[1]))

func _ready() -> void:
	# One blow of anything breaks it.
	max_health = 1.0
	team = TEAM
	hurt_radius = 12.0
	sought = false
	super._ready()
	_make_body(W, H)
	# In the way, as a wall is: bodies walk round it, and it is pushed by none.
	collision_layer = 1
	collision_mask = 0

## The gold it holds.
func gold() -> int:
	return int(record.get("gold", 0))

func is_broken() -> bool:
	return bool(record.get("broken", false))

## It stands where it stands: a blow does not shove it, nor anything throw it.
func knockback(_dir: Vector2, _force: float, _thrower: int = -1) -> void:
	pass

## Nothing takes on it: no burn, no chill, no soaking.
func afflict(_amount: float, _elements: Array) -> void:
	pass

func stun(_seconds: float) -> bool:
	return false

## Broken rather than killed: no death, and no kill to count.
func _kill() -> void:
	if dead:
		return
	dead = true
	record["broken"] = true
	died.emit(self)
	broke.emit(self)
	Cues.at(&"crate_break", global_position, {"gold": gold()})
	queue_free()
