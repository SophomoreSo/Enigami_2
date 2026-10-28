class_name Bird
extends Node2D

## A bird on a room's floor, pecking about, that flies off as the player
## comes near — their own body, or a monster their hands are in — and as
## anything goes off close by: a blow, a shot, a strike landing. It goes up
## and away from whatever scared it, and is gone; and as it goes it startles
## the birds round it, so a flock lifts off together, the nearest first.
##
## Until then it keeps to where it was laid, hopping a little way now and then
## and turning one way and the other. Nothing strikes it and nothing goes after
## it: it is not an actor, only something on the floor that answers to who
## comes near.
##
## Its record is the room's own (`Room` keeps them under `birds`), shared
## rather than copied: `pos`, and whether it has `flown`, so a room walked out
## of and back into has only the birds that did not fly. Where one stands is
## laid in the map creator (`MadeRoom.BIRD`). `graphics/views/bird_view.gd`
## draws it.

## It took off: `away` is the way it flies, across the floor.
signal took_off(bird: Bird, away: Vector2)
## Out of the room for good.
signal flew(bird: Bird)

## How near the player comes, in world units, before it flies.
const SCARE := 96.0
## How near something has to go off — a blow, a shot, a strike landing.
const NOISE := 160.0
## How near another bird has to take off to startle it, and how long it takes
## to answer one that does, at the least and the most: the nearer, the sooner.
const FLOCK := 128.0
const STARTLE := Vector2(0.05, 0.3)
## Its flight: how fast it goes across the floor and how fast it climbs, how
## far its way may wander off straight away from what scared it, in radians,
## and how long it is in sight before it is gone.
const FLY_SPEED := 260.0
const CLIMB := 150.0
const SPREAD := 0.6
const FLIGHT := 1.4
## How long it stays in one place, at the least and the most, before it hops,
## and how far a hop takes it.
const STAY := Vector2(1.5, 4.0)
const HOP := 10.0

var record: Dictionary = {}
var room: Room = null
## The way it is looking: 1 right, -1 left.
var facing: int = 1
## Whether it has taken off.
var flying: bool = false
## How far up off the floor it is, in world units: the picture lifts it by
## this and leaves its shadow on the floor.
var height: float = 0.0
## Its way across the floor in flight, and how fast.
var velocity: Vector2 = Vector2.ZERO
## How long it has been in the air.
var aloft: float = 0.0
## Counts down to its next hop, and — once a bird near it has taken off — to
## its own.
var _stay: float = 0.0
var _startled: float = -1.0
var _from: Vector2 = Vector2.ZERO
var _dice := RandomNumberGenerator.new()

func setup(rec: Dictionary) -> void:
	record = rec
	var p: Array = rec.get("pos", [])
	if p.size() == 2:
		position = Vector2(float(p[0]), float(p[1]))
	_dice.seed = hash(position)
	facing = 1 if _dice.randf() < 0.5 else -1
	_stay = _dice.randf_range(STAY.x, STAY.y)

func _ready() -> void:
	add_to_group("birds")
	Cues.fired.connect(_on_cue)

func _process(delta: float) -> void:
	if flying:
		_fly(delta)
		return
	if _startled >= 0.0:
		_startled -= delta
		if _startled < 0.0:
			take_off(_from)
		return
	var scarer := _scarer()
	if scarer != null:
		take_off(scarer.global_position)
		return
	_stay -= delta
	if _stay <= 0.0:
		_stay = _dice.randf_range(STAY.x, STAY.y)
		_hop()

## Whoever is near enough to scare it: the player's body, or a monster their
## hands are in. Null for nobody.
func _scarer() -> Node2D:
	for p in get_tree().get_nodes_in_group("player"):
		var body := p as Node2D
		if body == null or (p is Actor and (p as Actor).dead):
			continue
		if body.global_position.distance_to(global_position) <= SCARE:
			return body
		if p is Player:
			var hands := (p as Player).vessel()
			if hands != p and hands.global_position.distance_to(global_position) <= SCARE:
				return hands
	return null

## A hop a little way along the floor, or only a turn where there is no floor
## to hop to.
func _hop() -> void:
	facing = -facing if _dice.randf() < 0.5 else facing
	var to := global_position + Vector2(float(facing), _dice.randf_range(-0.6, 0.6)).normalized() * HOP
	if room == null or not is_instance_valid(room) or room.is_floor_at(to):
		global_position = to

## Something going off near it: an attack going out, or one landing.
func _on_cue(cue: StringName, d: Dictionary) -> void:
	if flying or (cue != &"attack" and cue != &"impact"):
		return
	var at: Vector2 = d.get("pos", Vector2.INF)
	if at.distance_to(global_position) <= NOISE:
		take_off(at)

## Up and away from `from`: across the floor straight away from it, give or
## take SPREAD, climbing as it goes — and the birds round it startled into
## following.
func take_off(from: Vector2) -> void:
	if flying:
		return
	flying = true
	_startled = -1.0
	var away := global_position - from
	if away.length() < 0.01:
		away = Vector2(float(facing), 0.0)
	away = away.normalized().rotated(_dice.randf_range(-SPREAD, SPREAD))
	velocity = away * FLY_SPEED
	if absf(away.x) > 0.01:
		facing = 1 if away.x > 0.0 else -1
	record["flown"] = true
	took_off.emit(self, away)
	Cues.at(&"bird_flight", global_position, {"away": away})
	for n in get_tree().get_nodes_in_group("birds"):
		var other := n as Bird
		if other != null and other != self:
			other.startle(global_position)

## A bird at `at` took off: one near enough follows it up, a moment later, the
## nearer the sooner, flying away from where it was.
func startle(at: Vector2) -> void:
	if flying or _startled >= 0.0:
		return
	var d := at.distance_to(global_position)
	if d > FLOCK:
		return
	_startled = lerpf(STARTLE.x, STARTLE.y, d / FLOCK)
	_from = at

func _fly(delta: float) -> void:
	aloft += delta
	global_position += velocity * delta
	height += CLIMB * delta
	if aloft >= FLIGHT:
		flew.emit(self)
		queue_free()
