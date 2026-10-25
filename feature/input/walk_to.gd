class_name WalkTo
extends InputMiddleware

## Walks the body to a spot on the floor, then turns it to face the way it was
## asked: the devlog's navigation. It writes over which way the hands say to
## go, slows a sprint to a walk, and shuts the gate on a dash, which would
## carry the body off the walk; the weapon's buttons stay the hands'. For as
## long as it walks the body is the computer's (`takes_over`), so the
## crosshair the weapon points with rests where it was and the mouse does not
## move it.
##
## A push the other way is the player taking the body back. The walk gives up
## on the spot, and that push goes through on the same frame. A push already
## held when the walk began is not that: it was there before whatever asked for
## the walk, and is walked over like any other until it is let go of or turned
## another way. Push again after that and it counts. Otherwise a player
## running past someone, pressing to talk to them, would refuse their own
## press.
##
## Something in the way, a wall or a pit, leaves the body short of the spot;
## once it stops getting any closer, the walk calls that there.
##
## It takes its step once a physics frame, however often the line is read. A
## drawn frame between two physics frames reads the line too, and must not count
## as time walked.

## Close enough to be there.
const THERE := 3.0
## How far out it starts to ease off, so the body walks up to the spot rather
## than running into it and sliding past.
const EASE := 24.0
## A push at least this hard, and at least this much of it against the walk,
## takes the body back.
const REFUSE := 0.25
## How long it waits without getting any closer before it calls that there.
const PATIENCE := 0.25
## Two pushes are the same push while they point this much the same way.
const SAME_WAY := 0.7

## Where it is going, on the floor.
var to: Vector2 = Vector2.ZERO
## Which way to face once there, or zero for whichever way it walked.
var face: Vector2 = Vector2.ZERO
## How it ended: there, or taken back by the player. Neither while it walks.
var arrived: bool = false
var refused: bool = false
## How hard it pushes, 0..1: the body's whole run, or less of it for a stroll
## a story asks for. A push that refuses it is measured against REFUSE still.
var pace: float = 1.0

var _begun: bool = false
## The push the hands were already holding when the walk began, until it is
## let go of or turned another way.
var _stale: Vector2 = Vector2.ZERO
var _closest: float = INF
var _waited: float = 0.0
var _stepped_on: int = -1

func _init(spot: Vector2, facing: Vector2 = Vector2.ZERO) -> void:
	rank = STEER
	to = spot
	face = facing

## Leaves the line without getting anywhere: for whoever asked for the walk,
## when what it was walking to is gone.
func cancel() -> void:
	done = true

func takes_over() -> bool:
	return true

func process(s: InputState) -> InputState:
	if done or body == null:
		return s
	var gap: Vector2 = to - body.global_position
	if Engine.is_in_physics_frame() and Engine.get_physics_frames() != _stepped_on:
		_stepped_on = Engine.get_physics_frames()
		_step(gap, s.move)
	if refused:
		return s
	s.can_dash = false
	s.sprint = false
	if arrived:
		s.move = Vector2.ZERO
		s.turn = face
	else:
		s.move = (gap / EASE).limit_length(pace)
	return s

## A physics frame of it: whether the player has taken the body back, and
## whether it has got there.
func _step(gap: Vector2, held: Vector2) -> void:
	var push := held if held.length() >= REFUSE else Vector2.ZERO
	if not _begun:
		_begun = true
		_stale = push
	elif push == Vector2.ZERO or push.normalized().dot(_stale.normalized()) < SAME_WAY:
		_stale = Vector2.ZERO
	if push != Vector2.ZERO and _stale == Vector2.ZERO and gap.length() > 0.0 \
			and push.normalized().dot(gap.normalized()) <= -REFUSE:
		refused = true
		done = true
		return
	if gap.length() <= THERE:
		_arrive()
		return
	# Getting closer starts the patience over; standing against something
	# uses it up.
	if gap.length() < _closest - 0.5:
		_closest = gap.length()
		_waited = 0.0
	else:
		_waited += body.get_physics_process_delta_time()
		if _waited >= PATIENCE:
			_arrive()

func _arrive() -> void:
	arrived = true
	done = true
