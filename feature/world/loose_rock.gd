class_name LooseRock
extends Node2D

## The rock, lying where it came down: a thrown weapon out of hand
## (`Weapons.is_thrown`). It comes down onto the floor, hops once or twice off
## it, slides to a stop and lies there, and the hands that threw it pick it
## back up by walking over it — the player's own, or a monster's they are in
## (`Player.possess`). A monster with its own mind never does: it is not
## theirs. Until it is picked up, the weapon casts nothing.
##
## It is on a floor seen from above: its position is where it is on the floor,
## and how far up off it it is at the moment is `height`, which only the
## picture and a body under it care about. Across the floor it slides under
## `FRICTION`; up and down it goes under the world's pull, and bounces off
## the floor while it comes down fast enough.
##
## There is only ever the one. One whose weapon is back in hand some other way —
## a kit handed out again, at the bench or in the hideout — is not the rock any
## more, and goes.
##
## A room walked out of with it lying there keeps it (`Room.save_state`), and
## walking back in finds it where it was. `graphics/views/loose_rock_view.gd`
## draws it.
##
## One a throw ran out in the air (`Projectile._fall_out`) is still the throw
## as it comes down (`arm`): it strikes what it comes down onto — each once,
## and none the throw had struck already — and where it first meets the rock,
## a wall on the way or the floor it comes down on, the throw goes off
## (`Attacks.land`) if it was not spent on what it struck. Then it is only a
## rock.

signal picked_up(rock: LooseRock, by: Actor)

## Half its size on the floor: the tile it is drawn with is eight pixels of the
## picture across, two of the world's each.
const RADIUS := 8.0
## The pull bringing it down, in world units a second squared, and the fastest
## it comes down.
const GRAVITY := 1500.0
const MAX_FALL := 900.0
## How much of its speed it keeps, the other way, off what it hits; and how
## slowly it has to be coming down to stop rather than bounce.
const BOUNCE := 0.35
const REST_SPEED := 110.0
## How quickly it stops sliding once it is down.
const FRICTION := 900.0
## How close the hands have to come: touching it, give or take.
const REACH := 8.0
## How long it has to have been down before hands can take it: one put down at
## the feet is not straight back in them.
const SETTLE := 0.3
## The longest step it takes across the floor between looks at the room.
const MAX_STEP := 6.0

## Which weapon this is.
var weapon: String = "ROCK"
## Whose it is: the only hands that pick it up are this player's.
var thrower: Player = null
var room = null
## How it is sliding across the floor, in world units a second.
var velocity: Vector2 = Vector2.ZERO
## How far up off the floor it is, and how fast that is changing, up positive.
var height: float = 0.0
var vertical: float = 0.0
## Whether it lies still on the floor.
var resting: bool = false
## How long it has been down, out of the air.
var _down: float = 0.0
var _placed: bool = false
## The throw it is still, coming down: what it strikes with, for which side, as
## whose blow, and what it has struck already; null once it is down.
var strikes: Payload = null
var _team: int = 0
var _attacker: Actor = null
var _hit: Array = []
var _hits_left: int = 1
## Whether it may strike its thrower: whether the throw had left their hand.
var _at_thrower: bool = false

## Puts the rock `weapon` down at `at`, sliding at `moving`, `up` off the floor
## and tossed up at `lift`, in `in_room` — or, with no room to lie in, wherever
## attacks are kept — for `by` to pick back up. What a bolt that was the rock
## becomes when it is done flying, and what a monster lets go of when the
## player steps out of it.
static func drop(weapon_id: String, at: Vector2, moving: Vector2, in_room, by: Player,
		up: float = 0.0, lift: float = 0.0) -> LooseRock:
	var r := LooseRock.new()
	r.weapon = weapon_id
	r.thrower = by
	r.velocity = moving
	r.height = maxf(up, 0.0)
	r.vertical = lift
	r._home_in(at, in_room, by)
	return r

func _ready() -> void:
	add_to_group("loose_rocks")

## Makes a rock just dropped out of a throw still the throw as it comes down:
## it strikes what it comes down onto with `p`, for `team`, as `atk`'s blow,
## sparing what the throw struck already (`struck`), as many more times as the
## throw had left (`left`) — and its thrower too, if the throw had left their
## hand.
func arm(p: Payload, team: int, atk: Actor, struck: Array, left: int, at_thrower: bool) -> void:
	if p == null or left <= 0:
		return
	strikes = p
	_team = team
	_attacker = atk if atk != null and is_instance_valid(atk) else null
	_hit = struck.duplicate()
	_hits_left = left
	_at_thrower = at_thrower

func _process(delta: float) -> void:
	if room != null and not is_instance_valid(room):
		room = null
	if not _placed:
		_placed = true
		_unstick()
	if not resting:
		_fly(delta)
	else:
		_down += delta
	_offer()

## A frame of coming down, hopping off the floor, and sliding along it once it
## is down: only a rock from then on.
func _fly(delta: float) -> void:
	if height > 0.0 or vertical > 0.0:
		vertical = maxf(vertical - GRAVITY * delta, -MAX_FALL)
		height += vertical * delta
		if height <= 0.0:
			height = 0.0
			_land()
	else:
		_down += delta
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
		if velocity.is_zero_approx():
			velocity = Vector2.ZERO
			resting = true
			_spend_on_rock()
			return
	_travel(delta)

## The frame's travel across the floor, in hops no longer than MAX_STEP, each
## looked at for a wall — which it comes back off — and, still the throw, for
## what it touches on the way.
func _travel(delta: float) -> void:
	var travel := velocity * delta
	if travel.length() < 0.01:
		return
	var hops := maxi(1, int(ceil(travel.length() / MAX_STEP)))
	var step := travel / float(hops)
	for i in hops:
		var next := global_position + step
		if _solid(next + step.normalized() * radius):
			_spend_on_rock()
			velocity = -velocity * BOUNCE
			return
		global_position = next
		if strikes != null:
			_strike()

## Coming down as the throw still: what it touches is struck, each once. Spent,
## it hops back off the last one struck, as a thrown rock does, and is a rock.
func _strike() -> void:
	if height > Projectile.STRIKE_HEIGHT:
		return
	var reached := Attacks.targets(_team)
	if _at_thrower and thrower != null and is_instance_valid(thrower) and not thrower.dead:
		# The Arena's list is not ours to add to.
		reached = reached + [thrower]
	for a in reached:
		if _hit.has(a) or not is_instance_valid(a):
			continue
		if global_position.distance_to(a.global_position) <= radius + a.hurt_radius:
			_hit.append(a)
			var dir := velocity.normalized() if velocity.length() > 1.0 else Vector2.DOWN
			Attacks.resolve_hit(strikes, a, global_position, dir, _attacker, room, _team)
			_hits_left -= 1
			if _hits_left <= 0:
				strikes = null
				velocity = -velocity * 0.25
				vertical = 180.0
				return

## Down onto the floor: either off it again, slower, or stopped coming down and
## only sliding now. Only a rock from here on.
func _land() -> void:
	_spend_on_rock()
	var hit := -vertical
	if hit > REST_SPEED:
		vertical = hit * BOUNCE
		velocity *= 0.7
	else:
		vertical = 0.0
	Cues.at(&"rock_down", global_position, {"weapon": weapon, "speed": hit})

## The throw it still was, if any, goes off here, where it met the rock — a
## wall, the floor — unless it was spent on what it struck on the way down.
## Only a rock after.
func _spend_on_rock() -> void:
	if strikes == null:
		return
	if _hits_left > 0:
		var dir := velocity.normalized() if velocity.length() > 1.0 else Vector2.DOWN
		Attacks.land(strikes, global_position, dir, _attacker, room, _team)
	strikes = null

## Picked up by the hands that threw it, if they are on it. Or gone, if the
## weapon is back in hand some other way.
func _offer() -> void:
	if thrower == null or not is_instance_valid(thrower) or thrower.dead:
		return
	if not thrower.weapons.has(weapon):
		return
	if thrower.holds(weapon):
		queue_free()
		return
	if _down < SETTLE:
		return
	var hands := thrower.vessel()
	if _hands_on(hands, REACH):
		thrower.take_back(weapon, hands)
		Cues.at(&"rock_back", global_position, {"weapon": weapon})
		picked_up.emit(self, hands)
		queue_free()

## Whether the room's rock is at `at`. A room torn down under it is no room.
func _solid(at: Vector2) -> bool:
	if room != null and not is_instance_valid(room):
		room = null
	return room != null and room.has_method("is_solid_at") and room.is_solid_at(at)

## Put down inside the rock — a record carried across a change to how rooms are
## built, a throw that ended hard against a corner — it is moved out to the
## nearest open place, up to three cells off; failing that, put where the room
## puts a player who walks in.
func _unstick() -> void:
	if not _solid(global_position):
		return
	for ring in range(1, Room.CELL * 3):
		for way in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			var at := global_position + way * float(ring)
			if not _solid(at):
				global_position = at
				return
	if room != null and room.has_method("spawn_point"):
		global_position = room.spawn_point()

## Puts it in the world at `at`: in `in_room`, or failing that in the room `by`
## stands in, and with no room at all wherever attacks are kept — one left
## lying anywhere but a room would go nowhere when the room goes, or outlast
## it.
func _home_in(at: Vector2, in_room, by: Node) -> void:
	var where = in_room
	if (where == null or not is_instance_valid(where)) and by != null and is_instance_valid(by):
		where = by.get("room")
	room = where if where != null and is_instance_valid(where) else null
	var host: Node = room if room != null else Attacks.container()
	position = (host as Node2D).to_local(at) if host is Node2D else at
	if host != null:
		host.add_child(self)

## Whether `hands` are on it: within `reach` of touching it, on the floor.
func _hands_on(hands: Node2D, reach: float) -> bool:
	if hands == null or not is_instance_valid(hands):
		return false
	var theirs := float(hands.get("hurt_radius")) if hands.get("hurt_radius") != null else 0.0
	return global_position.distance_to(hands.global_position) <= radius + theirs + reach

## What a room writes down for it when the player walks out leaving it there.
func record() -> Dictionary:
	return {"weapon": weapon, "pos": [position.x, position.y]}
