class_name StuckShuriken
extends Node2D

## A shuriken where it struck (`Weapons.is_stacked`): in a wall at the point it
## met it, pointing the way it was going, on the floor where it came down out
## of its arc, or riding in a monster at the place it went in. Out of a monster
## that has died it drops, and lies on the floor at the monster's feet.
##
## Lying still in a wall or on the floor, the hands that threw it take it back
## by walking over it — the player's own, or a monster's they are in
## (`Player.possess`) — and it is one more in the stack (`Player.stock`). Not
## while the stack is already whole: then it stays where it is. One in a
## monster is out of reach until the monster lets go of it, by dying.
##
## It belongs to the room it struck in and goes with it. A room walked out of
## keeps no record of it (`Room.save_state`), so one left behind is gone.
## `graphics/views/stuck_shuriken_view.gd` draws it.

signal picked_up(shuriken: StuckShuriken, by: Actor)

## How far from its point to the middle of it: the tile it is drawn with is
## seven pixels of the picture across, two of the world's each.
const RADIUS := 7.0
## How close the hands have to come: touching it, give or take.
const REACH := 10.0
## The pull bringing one down, in world units a second squared.
const GRAVITY := 1500.0
## How long it has to have been down before hands can take it.
const SETTLE := 0.3
## The longest step it takes across the floor between looks at the room.
const MAX_STEP := 6.0
## How far up off the floor a monster lets go of it as it dies: about a
## monster's middle, from where it drops to the floor.
const SHAKEN := 20.0

## Which weapon this is one of.
var weapon: String = "SHURIKEN"
## Whose it is: the only hands that take it back are this player's.
var thrower: Player = null
var room = null
## The monster it is in, and where on it from the monster's feet; null when
## it is in a wall, on the floor, or coming down.
var host: Actor = null
var _offset: Vector2 = Vector2.ZERO
## The way it was going when it struck, which is the way it points in what it
## struck.
var heading: Vector2 = Vector2.RIGHT
## Whether it is coming down rather than stuck.
var falling: bool = false
## How it is still going across the floor as it comes down, and how far up it
## is, and how fast that is changing, up positive.
var velocity: Vector2 = Vector2.ZERO
var height: float = 0.0
var vertical: float = 0.0
## How long it has been down, out of the air.
var _down: float = 0.0

## A shuriken of `weapon_id` stuck at `at`, going `moving` as it struck, in
## `in_room` — or in `into`, the monster it struck, at that place on it — for
## `by` to take back.
static func lodge(weapon_id: String, at: Vector2, moving: Vector2, in_room, by: Player,
		into: Actor = null) -> StuckShuriken:
	var s := _make(weapon_id, at, in_room, by)
	if moving.length() > 0.01:
		s.heading = moving.normalized()
	if into != null and is_instance_valid(into) and not into.dead:
		s.host = into
		s._offset = at - into.global_position
	return s

## A shuriken of `weapon_id` coming down from `at`, `up` off the floor, going
## `moving` across it, until it is on the floor: one out of throw with nothing
## struck.
static func drop(weapon_id: String, at: Vector2, moving: Vector2, in_room, by: Player,
		up: float = 0.0) -> StuckShuriken:
	var s := _make(weapon_id, at, in_room, by)
	s.falling = true
	s.velocity = moving
	s.height = maxf(up, 0.0)
	if moving.length() > 0.01:
		s.heading = moving.normalized()
	return s

static func _make(weapon_id: String, at: Vector2, in_room, by: Player) -> StuckShuriken:
	var s := StuckShuriken.new()
	s.weapon = weapon_id
	s.thrower = by
	s._home_in(at, in_room, by)
	return s

func _ready() -> void:
	add_to_group("stuck_shurikens")

func _process(delta: float) -> void:
	if room != null and not is_instance_valid(room):
		room = null
	if host != null:
		if is_instance_valid(host) and not host.dead:
			global_position = host.global_position + _offset
			return
		# The monster is gone, and lets go of it: it drops off the body to the
		# floor at its feet.
		host = null
		falling = true
		velocity = Vector2.ZERO
		height = SHAKEN
		vertical = 0.0
	if falling:
		_fall(delta)
		return
	_down += delta
	_offer()

## A frame of coming down: under the world's pull, and across the floor a
## little, stopping at a wall it meets; on the floor it lies where it is, and
## out past the room it is gone.
func _fall(delta: float) -> void:
	vertical -= GRAVITY * delta
	height += vertical * delta
	var travel := velocity * delta
	var hops := maxi(1, int(ceil(travel.length() / MAX_STEP)))
	for i in hops:
		var next := global_position + travel / float(hops)
		if _out_of_bounds(next):
			queue_free()
			return
		if _solid(next):
			velocity = Vector2.ZERO
			break
		global_position = next
	if height <= 0.0:
		height = 0.0
		vertical = 0.0
		falling = false
		if velocity.length() > 0.01:
			heading = velocity.normalized()
		velocity = Vector2.ZERO
		_down = 0.0

## Taken back by the hands that threw it, if they are on it and the stack has
## room for it.
func _offer() -> void:
	if _down < SETTLE:
		return
	if thrower == null or not is_instance_valid(thrower) or thrower.dead:
		return
	var hands := thrower.vessel()
	if not _hands_on(hands, REACH):
		return
	if not thrower.take_one_back(weapon):
		return
	Cues.at(&"shuriken_back", global_position, {"weapon": weapon})
	picked_up.emit(self, hands)
	queue_free()

## Whether it is where it can be taken back from: still, and in no monster.
func stuck() -> bool:
	return host == null and not falling

## Whether the room's rock is at `at`. A room torn down under it is no room.
func _solid(at: Vector2) -> bool:
	if room != null and not is_instance_valid(room):
		room = null
	return room != null and room.has_method("is_solid_at") and room.is_solid_at(at)

## Whether `at` is out past the room altogether.
func _out_of_bounds(at: Vector2) -> bool:
	return room != null and is_instance_valid(room) and room.has_method("out_of_bounds") \
		and room.out_of_bounds(at)

## Puts it in the world at `at`: in `in_room`, or failing that in the room `by`
## stands in, and with no room at all wherever attacks are kept.
func _home_in(at: Vector2, in_room, by: Node) -> void:
	var where = in_room
	if (where == null or not is_instance_valid(where)) and by != null and is_instance_valid(by):
		where = by.get("room")
	room = where if where != null and is_instance_valid(where) else null
	var host_node: Node = room if room != null else Attacks.container()
	position = (host_node as Node2D).to_local(at) if host_node is Node2D else at
	if host_node != null:
		host_node.add_child(self)

## Whether `hands` are on it: within `reach` of touching it, on the floor.
func _hands_on(hands: Node2D, reach: float) -> bool:
	if hands == null or not is_instance_valid(hands):
		return false
	var theirs := float(hands.get("hurt_radius")) if hands.get("hurt_radius") != null else 0.0
	return global_position.distance_to(hands.global_position) <= RADIUS + theirs + reach
