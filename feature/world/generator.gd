class_name Generator
extends Actor

## A generator: the machine an electrical system draws its power from, down a
## wire (`Wire`) to what it powers — an electric gate (`ElectricGate`). The
## wire runs under the floor and through the walls, and nobody sees it but a
## hero with the sight for it (`Sight`, Legna Dennis): followed back from what
## it powers, it is how the generator behind a system is found.
##
## Crashed, it powers nothing. Anything that strikes it often enough wrecks
## it — a blow, a bolt, a thrown rock, a monster's blast — and every wire it
## feeds goes dead with it. It is an actor so that every attack reaches it the
## way it reaches a crate: on the crates' side (`Crate.TEAM`), which the
## player's and the monsters' can both strike, and sought by nothing — and
## crashing it is no kill. It does not move, burn, chill or stun, and it stands
## in the way, wrecked or not, until the place is set again (`restore`).
## `graphics/views/generator_view.gd` draws it.

## Wrecked: nothing it powered has power from it any more.
signal crashed(generator: Generator)
## Running again, the place set again.
signal restored(generator: Generator)

## What it takes to wreck it: a few blows of anything.
const HEALTH := 30.0
## How wide it stands on the floor, and how tall up the screen from its feet.
const W := 26.0
const H := 30.0

func _ready() -> void:
	max_health = HEALTH
	team = Crate.TEAM
	hurt_radius = 16.0
	sought = false
	super._ready()
	_make_body(W, H)
	# In the way, as a wall is: bodies walk round it, and it is pushed by none.
	collision_layer = 1
	collision_mask = 0

## Whether it is running: not crashed.
func running() -> bool:
	return not dead

## It stands where it stands: a blow does not shove it, nor anything throw it.
func knockback(_dir: Vector2, _force: float, _thrower: int = -1) -> void:
	pass

## Nothing takes on it: no burn, no chill, no soaking.
func afflict(_amount: float, _elements: Array) -> void:
	pass

func stun(_seconds: float) -> bool:
	return false

## Crashed rather than killed: no death and no kill, and it stays where it
## stood, a wreck out of the fight, which nothing strikes any more.
func _kill() -> void:
	if dead:
		return
	dead = true
	died.emit(self)
	crashed.emit(self)
	Cues.at(&"generator_crash", global_position)

## Running again, whole, as the place it stands in is set again.
func restore() -> void:
	dead = false
	health = max_health
	restored.emit(self)
