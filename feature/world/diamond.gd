class_name Diamond
extends Node2D

## The ghost test's prize: one stone, lying where it was left until hands the
## player is in walk onto it — their own body's, or a monster's they are in
## (`Player.vessel`). Whoever holds it carries it over their head. When the
## hands leave that body — hopping on to the next, stepping out, the time
## running out, the body dying — it is let go of where that body stands, on the
## floor at its feet. Let go of over a pit, it is lost down it, and found again
## where it was kept. A monster with its own mind never picks it up: it is the
## player's to take.
##
## It is the rock's rule (`LooseRock`) for something that is not a weapon, so a
## theft carried through three bodies is passed on the way the rock is.
## `graphics/views/diamond_view.gd` draws it.

signal picked_up(by: Actor)
signal let_go(at: Vector2)

## How far round its middle it is, on the floor.
const RADIUS := 8.0
## How close the hands have to come: touching it, give or take.
const REACH := 8.0
## How far over the top of whoever carries it it rides: clear of the head,
## which is drawn taller than the body that bumps into things.
const OVERHEAD := 24.0
## How long it has to have been down before hands can take it: one let go of
## is not straight back in the hands that let it go.
const SETTLE := 0.3

## Whose hands can take it: the player's body, or whichever monster they are in.
var player: Player = null
## The room it lies in, for the pits in its floor.
var room: Room = null
## Who is carrying it, or null while it lies somewhere.
var carrier: Actor = null
## Where it is kept, and is found again when it goes down a pit.
var kept_at: Vector2 = Vector2.ZERO
## How far up off the floor it is, in world units: over the head of whoever
## carries it, and nothing while it lies on the floor. The picture lifts it by
## this; everything else is measured from where it is on the floor.
var height: float = 0.0
## How long it has been down, out of the hands.
var _down: float = 0.0
## Where the one carrying it last stood, for letting go of it there should
## they be gone by the time it is noticed.
var _held_at: Vector2 = Vector2.ZERO

## Puts it down at `at`, nobody's, ready to be taken.
func place(at: Vector2) -> void:
	carrier = null
	height = 0.0
	global_position = at
	_down = SETTLE

func _process(delta: float) -> void:
	if carrier != null:
		_carry()
	else:
		_down += delta
		_offer()

## Whether it is in the player's own hands: their body's, not a monster's.
func carried_by_player() -> bool:
	return carrier != null and carrier == player

## Whether hands could take it: lying still, and down long enough.
func settled() -> bool:
	return carrier == null and _down >= SETTLE

## Rides over the head of the hands holding it, for as long as they are the
## hands the player is in.
func _carry() -> void:
	var holding := is_instance_valid(carrier) and not (carrier as Actor).dead \
		and player != null and is_instance_valid(player) and not player.dead \
		and player.vessel() == carrier
	if not holding:
		_drop()
		return
	_held_at = carrier.global_position
	global_position = _held_at
	height = (carrier as Actor).height + (carrier as Actor).body_size.y + OVERHEAD

## Out of the hands: on the floor where they stood, or, over a pit, back where
## it is kept.
func _drop() -> void:
	carrier = null
	height = 0.0
	_down = 0.0
	global_position = _held_at
	if room != null and is_instance_valid(room) and room.is_pit_at(global_position):
		global_position = kept_at
	let_go.emit(global_position)
	Cues.at(&"diamond_down", global_position, {})

## Taken by `hands`.
func take(hands: Actor) -> void:
	carrier = hands
	_held_at = hands.global_position
	picked_up.emit(hands)
	Cues.at(&"diamond_taken", global_position, {})

func _offer() -> void:
	if _down < SETTLE or player == null or not is_instance_valid(player) or player.dead:
		return
	var hands := player.vessel()
	if _hands_on(hands, REACH):
		take(hands)

## Whether `hands` are on it, on the floor: touching it, give or take `reach`.
func _hands_on(hands: Node2D, reach: float) -> bool:
	if hands == null or not is_instance_valid(hands):
		return false
	var theirs := float(hands.get("hurt_radius")) if hands.get("hurt_radius") != null else 0.0
	return global_position.distance_to(hands.global_position) <= RADIUS + theirs + reach
