class_name Projectile
extends Node2D

## A travelling bolt. Collision is resolved analytically against actor radii and
## the room's solid grid, so attacks need no physics bodies of their own.
## `graphics/views/projectile_view.gd` draws it and keeps its own trail.
##
## It flies on the floor seen from above: its position is a point on the
## floor, and what it strikes is whatever stands within reach of that point.
## A lobbed one — a thrown stone, a shuriken, a Lobber's shot — flies the same
## line on the floor and an arc over it (`height`, `lob`): thrown up out of
## the hand, it comes down where it was aimed, strikes nothing it passes over
## while it is up. A wall stops it as it stops anything: the walls stand taller
## than any throw. Where it comes down
## is the end of it: a stone lies there, a shuriken sticks there, and anything
## else bursts there (`Attacks.land`).
##
## Off a thrown weapon (`Weapons.is_thrown`) the bolt is the weapon itself — the
## rock — and it does not fade when it is done: it comes down off whatever it
## struck, or out of the end of its throw, and lies where it lands for whoever
## threw it to pick back up (`LooseRock`). The rest of a volley it went out in
## are copies of it, and those go the way any bolt does. Any of them — the rock
## or the rune, the weapon or a copy — strikes whoever threw it as well, once it
## has been clear of their hand (`_struck_by`). One that meets a wall with its
## throw not yet spent casts the throw there (`Attacks.land`), and so does one
## that comes down out of the air with it not yet spent.
##
## Off a stacked weapon (`Weapons.is_stacked`) every bolt of a volley is one of
## the stack — a shuriken — and it does not fade either: it sticks where it
## strikes, in the wall at the point it met it or in the last enemy it struck,
## and out of the end of its throw it lies on the floor where it came down
## (`StuckShuriken`).
##
## Three parts change how any of them flies. BOUNCE has it come back off the
## walls it meets, so many times, before one ends it (`_bounce`). BOOMERANG
## (RETURN) turns it for home at the end of its range, or off a wall it cannot
## bounce off: back toward whoever cast it, striking afresh on the way, and a
## thrown stone or a shuriken back into the hand that threw it (`_turn_back`,
## `_caught`). CHAIN sends a fresh bolt out of each enemy it strikes at the
## nearest other one, a jump fewer left on it (`_chain_from`).

## Longest hop a bolt may take before its collision is sampled again. Walls are
## a 32px grid and a target only a few pixels across, so a fast bolt has to be
## walked in pieces: sampled once a frame, a shot carrying SPEED parts steps
## clean over a one-cell wall and out the far side of whatever it was aimed
## at. The hops cost nothing — even the fastest build needs a handful.
const MAX_STEP := 12.0
## The pull on a thrown thing in the air — the rock, the rune, a shuriken — in
## world units a second squared: a throw is a short, steep arc that comes down
## hard. A monster's lobbed shot has the easier lob (`LOB_GRAVITY`): the same
## throw, slower up and slower down.
const THROW_GRAVITY := 1500.0
const LOB_GRAVITY := 620.0
## How high over the floor a bolt leaves the hand, and how far up a thing in
## the air can be and still strike a body under it: about a body's middle, and
## about a body's height. Higher than that, it passes over.
const HAND_HEIGHT := 14.0
const STRIKE_HEIGHT := 36.0
## How long a lobbed throw may stay in the air. Its arc is what brings it down,
## not its range (`lobbed`), and this is the backstop under that: a throw over
## a pit, or out over nothing, still ends.
const LOB_LIFE := 6.0

## How long a bolt may stay in the air whatever it is doing. Range is what
## actually ends a shot now — see `Payload.range_px` — and this is the backstop
## under it: a bolt that is barely moving, or one arcing at the top of a lob,
## would otherwise sit there spending its range a pixel at a time. It is the
## least a bolt gets: one with more range than it could fly in that time — RANGE
## stacked, on a slow weapon — is given long enough to fly it (`setup`), so this
## never cuts a shot short; it only stops one hanging about.
const LIFE := 3.0

## What a bolt whose SPEED is stacked to its limit leaves at, in pixels a
## second, whatever its weapon: across a room in a tenth of a second, which is
## as good as a beam. Short of the limit, SPEED multiplies the bolt's own pace,
## and the quickest that gets — a gun's bolt one SPEED short — is under a third
## of this, so reaching the limit is a step and not one more notch.
const LASER_SPEED := 12000.0

## HOMING. How hard one HOMING turns a bolt towards what it is after, as the
## share of the turn it makes in a second. Every one stacked turns as hard
## again, which is the difference between flying wide of a corner and taking it.
## It went from five to ten when bolts were given half the range they had: at
## the same pace, a turn twice as hard draws the same curve at half the size, so
## one HOMING still comes round onto something beside it before it is spent.
const HOMING_TURN := 10.0
## A homing bolt turns by the distance it covers, as one flying at this pace
## would turn over it, whenever it is going faster: a turn counted by time
## alone is no turn at all at laser speed, where a frame is two hundred pixels.
## A gun's bolt flies a little under it, so nothing slower turns differently.
const HOMING_PACE := 1200.0
## How far a homing bolt looks for something to go after, at the least: it
## looks as far as it has yet to fly, so one with RANGE on it goes after
## whatever it can reach, however far that is (`_quarry`).
const HOMING_SIGHT := 520.0
## A homing bolt loses pace in a turn — the harder the turn, the more — and
## that is what lets it tighten onto something it would otherwise circle. Once
## it is flying straight at what it is steering for (`HOMING_STRAIGHT`, the
## cosine of how straight) it picks the pace it left at back up, this share of
## it a second, so a bolt that has gone round a corner does not crawl the rest
## of the way. It never drops below `HOMING_SLOWEST` of that pace, or a bolt
## turned right round would stop dead and hang there.
const HOMING_REGAIN := 2.0
const HOMING_STRAIGHT := 0.98
const HOMING_SLOWEST := 0.05
## How often a homing bolt looks again at whether a wall stands between it and
## its target, and works out the way round if one does, in seconds; and how
## near a point on that way counts as reached, which has it look at once.
const REPATH := 0.08
const WAYPOINT_NEAR := 14.0
## How much room a homing bolt wants either side of a straight line before it
## calls the line clear: a line that only just misses a corner is one a bolt
## that is still turning clips on the way past.
const CLEARANCE := 8.0
## BOOMERANG. How hard a bolt on its way home turns to keep on whoever it is
## going back to, as the share of the turn it makes in a second: twice a
## HOMING's, since they move and it is meant to arrive.
const RETURN_TURN := 20.0
## CHAIN. How far a link looks for the next enemy from the one struck.
const CHAIN_SIGHT := 300.0

var payload: Payload
## How it moves on the floor, in world units a second.
var velocity: Vector2 = Vector2.RIGHT * 400.0
var team: int = 0
var attacker: Actor = null
var room = null
var radius: float = 5.0
## How far this bolt carries before it fades, taken off the payload at spawn so
## nothing has to ask a payload that may be gone.
var range_px: float = Payload.BASE_RANGE
var life: float = LIFE
var hits_left: int = 1
## The arc over the floor of a lobbed bolt: how high it is, how fast that is
## changing (up is positive), and the pull bringing it down. Nothing, on a bolt
## that flies flat.
var height: float = 0.0
var vertical: float = 0.0
var gravity: float = 0.0
var homing_strength: float = 0.0
## Where a homing bolt is steering for when a wall stands between it and its
## target: a point on the way round. `_repath` counts down to looking again.
var _waypoint: Vector2 = Vector2.ZERO
var _has_waypoint: bool = false
var _repath: float = 0.0
## The pace a homing bolt left at, which is the pace it gets back to.
var _pace: float = 0.0
var _hit: Array = []
## How far this bolt has flown, against `range_px`.
var _travelled: float = 0.0
## The thrown weapon this bolt is, or "": the rock, which comes down where it
## ends rather than fading. `thrower` is whose it is. A `ghost` is a copy of it
## that the same cast sent — the rest of a DUPLICATE's volley, a lap that came
## round with the rock already gone — which strikes as it does and is gone once
## it comes down: there is only the one rock.
var thrown: String = ""
var thrower: Player = null
var ghost: bool = false
## Whether a thrown bolt has been clear of whoever threw it yet. Till then it
## cannot strike them: it starts in their hand.
var _left_thrower: bool = false
## How far clear of its thrower a thrown bolt has to have been before it can
## strike them, past where the two would touch.
const LEAVE_MARGIN := 6.0
## The stacked weapon this bolt is one of, or "": the shuriken, which sticks
## where it ends rather than fading. `thrower` is whose it is.
var sticks: String = ""
## The last place the bolt stood that was open, for a rock that ends in a wall
## to come down from.
var _last_open: Vector2 = Vector2.ZERO
## BOUNCE: how many more walls it comes back off.
var bounces_left: int = 0
## BOOMERANG: whether it is on its way home.
var _returning: bool = false
## CHAIN: how many jumps a hit of this bolt has left to send on.
var _chain_left: int = 0

func setup(p: Payload, pos: Vector2, dir: Vector2, t: int, atk: Actor, rm) -> void:
	payload = p
	position = pos
	team = t
	attacker = atk
	room = rm
	radius = 5.0 * p.size
	range_px = maxf(p.range_px, 1.0)
	velocity = dir.normalized() * 420.0 * p.speed
	if p.at_limit("SPEED"):
		velocity = dir.normalized() * LASER_SPEED
	life = maxf(LIFE, range_px / maxf(velocity.length(), 1.0) * 1.25)
	hits_left = 1 + p.pierce
	homing_strength = HOMING_TURN * float(p.homing)
	bounces_left = p.bounce
	_chain_left = p.chain
	_last_open = pos

## Throws the bolt: out of the hand, in an arc under `pull` that comes down
## `carry` world units along the floor from where it is, at the pace it has.
## The arc, not the range, is what ends it; its life is given the time to fly
## it, and a backstop (`LOB_LIFE`) under that.
func lob(carry: float, pull: float = THROW_GRAVITY) -> void:
	gravity = pull
	height = HAND_HEIGHT
	var pace := maxf(velocity.length(), 1.0)
	var flight := maxf(carry, 1.0) / pace
	# What it has to leave at, up, to be back on the floor at the end of the
	# flight: h + v t - g t² / 2 = 0.
	vertical = pull * flight * 0.5 - height / flight
	life = maxf(life, maxf(flight * 1.25, LOB_LIFE))

func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		_expire()
		return
	if _returning:
		_steer_home(delta)
	if homing_strength > 0.0:
		_fly_homing(delta)
		return

	# This frame's flight, and no further than the range it has left: a bolt
	# quick enough to cover the rest of its range inside one frame — a laser
	# at any frame rate, anything fast at a slow one — still flies that rest,
	# striking what is on the way, rather than fading where it stands. A
	# lobbed throw has no range to run out of: its arc brings it down.
	var travel := velocity * delta
	var left := _range_left()
	var spent := travel.length() >= left
	if spent:
		travel = travel.limit_length(maxf(left, 0.0))
	_travelled += travel.length()
	var hops := maxi(1, int(ceil(travel.length() / MAX_STEP)))
	var hop := travel / float(hops)
	for i in hops:
		position += hop
		if _rise(delta / float(hops)):
			return
		if _sample():
			return
		_last_open = global_position
	if spent:
		_out_of_range()

## A homing bolt's frame, in hops no longer than `MAX_STEP`, turning before
## each one rather than once for the frame: a laser's frame flown straight would
## take it through the corner it was turning for. Otherwise the same flight as
## any bolt's.
func _fly_homing(delta: float) -> void:
	var t := delta
	while t > 0.0:
		var pace := maxf(velocity.length(), 1.0)
		var step := minf(t, MAX_STEP / pace)
		_home(maxf(step, step * pace / HOMING_PACE))
		var hop := velocity * step
		var left := _range_left()
		var spent := hop.length() >= left
		if spent:
			hop = hop.limit_length(maxf(left, 0.0))
		_travelled += hop.length()
		position += hop
		if _rise(step):
			return
		if _sample():
			return
		_last_open = global_position
		if spent:
			_out_of_range()
			return
		t -= step

## A step of the arc, for a lobbed bolt: up, and down under its pull, and down
## onto the floor at the end of it, where it lands (`_land_here`). Whether
## that was the end of it.
func _rise(delta: float) -> bool:
	if gravity <= 0.0:
		return false
	vertical -= gravity * delta
	height += vertical * delta
	if height <= 0.0 and vertical < 0.0:
		height = 0.0
		_land_here()
		return true
	return false

## Whether the bolt is low enough over the floor to meet what stands on it.
func _low() -> bool:
	return height <= STRIKE_HEIGHT

## How far the bolt has yet to fly before its range is out. A lobbed throw has
## no range to run out of — its arc brings it down — unless it is to come back,
## when its range is where it turns.
func _range_left() -> float:
	return INF if lobbed() and payload.returns <= 0 else range_px - _travelled

## Out of range: the shot turns for home if it has a return on it, and is
## otherwise spent, and says so. A bolt that simply blinked out would read as
## the game dropping it rather than as a rule the player can shoot around. The
## rock is out of throw, not spent: it falls from where it has got to.
func _out_of_range() -> void:
	if _turn_back():
		return
	if is_rock():
		_fall_out()
		return
	if sticks != "":
		_drop_out()
		return
	Cues.at(&"impact", global_position, {"payload": payload, "kind": "fade"})
	_expire()

## HOMING: turns the bolt towards the nearest enemy — straight at it while
## nothing stands between them, and otherwise at the furthest point it can fly
## straight to on the way round the walls (`Room.path_between`). How well it
## keeps to that way is how hard it turns, which is how many HOMING are
## stacked: one knows the way and flies wide of the corners, several take them.
func _home(delta: float) -> void:
	if _pace <= 0.0:
		_pace = velocity.length()
	var t := _quarry()
	if t == null:
		# Nothing to turn for, so it is flying straight: a bolt whose quarry
		# died while it was braking for the turn does not crawl on from there.
		var now := velocity.length()
		if now > 0.01 and now < _pace:
			velocity *= minf(_pace, now + HOMING_REGAIN * _pace * delta) / now
		return
	var goal: Vector2 = t.global_position
	if room != null and not is_instance_valid(room):
		room = null
	if room != null and room.has_method("path_between") and room.has_method("clear_between"):
		_repath -= delta
		if _repath <= 0.0 or (_has_waypoint and global_position.distance_to(_waypoint) < WAYPOINT_NEAR):
			_repath = REPATH
			_has_waypoint = false
			if not room.clear_between(global_position, goal, CLEARANCE):
				_find_waypoint(goal)
		if _has_waypoint:
			goal = _waypoint
	var to := goal - global_position
	if to.length() < 0.01:
		return
	var heading := to.normalized()
	# The turn, as it has always been: blending the two velocities turns the
	# bolt and shortens it, the more the further it has to turn.
	velocity = velocity.lerp(heading * velocity.length(), clampf(homing_strength * delta, 0.0, 1.0))
	var pace := velocity.length()
	var dir := velocity / pace if pace > 0.01 else heading
	if pace < _pace and dir.dot(heading) > HOMING_STRAIGHT:
		pace = minf(_pace, pace + HOMING_REGAIN * _pace * delta)
	velocity = dir * maxf(pace, _pace * HOMING_SLOWEST)

## What a homing bolt is after: the nearest enemy within sight that it has not
## struck already. One it has passed through is not something to turn back
## for, and with PIERCE on it the bolt has somewhere else to be.
func _quarry() -> Actor:
	var best: Actor = null
	var best_d := maxf(HOMING_SIGHT, range_px - _travelled)
	for a: Actor in Attacks.targets(team):
		if _hit.has(a):
			continue
		var d := global_position.distance_to(a.global_position)
		if d < best_d:
			best_d = d
			best = a
	return best

## The furthest point on the way to `goal` that the bolt can fly straight at,
## taken as the last one before a wall first gets in the way: steering for the
## next cell along would have it wobble down a corridor it could cross in one
## line. When not even the next cell is clear — the bolt is hard against a
## wall — that cell is what it steers for, which takes it off the wall.
func _find_waypoint(goal: Vector2) -> void:
	var way: PackedVector2Array = room.path_between(global_position, goal)
	if way.is_empty():
		return
	_waypoint = furthest_clear(room, global_position, way)
	_has_waypoint = true

## Where a bolt at `from` makes for, on its way to `goal`: `goal` itself when
## nothing stands between, and otherwise the furthest point on the way round it
## can fly straight to (`furthest_clear`). What AUTO-AIM points a homing bolt
## at as it goes, so it leaves along the way and not into the wall.
static func way_toward(rm, from: Vector2, goal: Vector2) -> Vector2:
	if rm == null or not is_instance_valid(rm) or not rm.has_method("path_between") \
			or rm.clear_between(from, goal, CLEARANCE):
		return goal
	var way: PackedVector2Array = rm.path_between(from, goal)
	return goal if way.is_empty() else furthest_clear(rm, from, way)

## The last point of `way` reachable from `from` in a straight line before a
## wall first gets in the way — or its first, hard against a wall.
static func furthest_clear(rm, from: Vector2, way: PackedVector2Array) -> Vector2:
	var out := way[0]
	for point in way:
		if not rm.clear_between(from, point, CLEARANCE):
			break
		out = point
	return out

## Whether the room's rock stands at `at`. A wall is as tall as any throw.
func _wall_at(at: Vector2) -> bool:
	return room != null and room.has_method("is_solid_at") and room.is_solid_at(at)

## One collision sample where the bolt is standing. Returns true once the
## caller is to stop walking it: the bolt is gone, or it has turned — off a
## wall, or for home — and the rest of the frame's flight was the old way.
func _sample() -> bool:
	# The room a bolt was fired in can be torn down under it — walking through
	# a door frees one room and builds the next — and a reference to a freed
	# node still reads as non-null, so asking it anything at all is an error
	# rather than a false. Dropped here, a stray bolt stops testing itself
	# against walls that no longer exist and simply runs out.
	if room != null and not is_instance_valid(room):
		room = null
	if _wall_at(global_position):
		if bounces_left > 0:
			bounces_left -= 1
			_bounce()
			return true
		Cues.at(&"impact", global_position, {"payload": payload, "kind": "wall"})
		if _turn_back():
			return true
		if is_rock():
			# Not yet spent on anything it struck: the throw goes off here,
			# at the last open place before the wall, and the stone drops.
			if hits_left > 0:
				Attacks.land(payload, _last_open, velocity.normalized(), attacker, room, team)
			_come_down(_off_the_wall(), true)
			return true
		if sticks != "":
			_stick(_surface())
			return true
		queue_free()
		return true
	if room != null and room.has_method("out_of_bounds") and room.out_of_bounds(global_position):
		if is_rock():
			_come_down(Vector2.ZERO, true)
			return true
		queue_free()
		return true

	if _returning:
		var home := _home_actor()
		if home != null and global_position.distance_to(home.global_position) <= radius + home.hurt_radius:
			_caught(home)
			return true

	# Up in its arc it passes over what stands under it.
	if not _low():
		return false
	for a in _struck_by():
		if _hit.has(a):
			continue
		if global_position.distance_to(a.global_position) <= radius + a.hurt_radius:
			_hit.append(a)
			Attacks.resolve_hit(payload, a, global_position, velocity.normalized(), attacker, room, team)
			if _chain_left > 0:
				_chain_from(a)
			hits_left -= 1
			if hits_left <= 0:
				Cues.at(&"impact", global_position, {"payload": payload, "kind": "spent"})
				if is_rock():
					# Off whatever it struck: back the way it came a little,
					# before it drops at their feet.
					_come_down(-velocity * 0.25, false, 180.0)
					return true
				if sticks != "":
					_stick(global_position, a)
					return true
				queue_free()
				return true
	return false

## A lobbed bolt come down onto the floor at the end of its arc: the stone
## lies where it came down and the shuriken sticks there; any other bursts
## there with whatever it carried (`Attacks.land`), and is gone. A throw not
## yet spent on anything it struck goes off where it lands, the same way.
func _land_here() -> void:
	if _turn_back():
		return
	var dir := velocity.normalized() if velocity.length() > 0.01 else Vector2.DOWN
	if is_rock():
		if hits_left > 0:
			Attacks.land(payload, global_position, dir, attacker, room, team)
		_come_down(velocity * 0.3)
		return
	if sticks != "":
		_stick(global_position)
		return
	if hits_left > 0:
		Attacks.land(payload, global_position, dir, attacker, room, team)
	Cues.at(&"impact", global_position, {"payload": payload, "kind": "ground"})
	queue_free()

## A thrown stone out of throw in the air — out of range or out of time — comes
## down where it has got to, striking what it falls onto with the throw until
## it reaches the floor (`LooseRock.arm`).
func _fall_out() -> void:
	var r := LooseRock.drop(thrown, global_position, velocity * 0.5, room, thrower, height, vertical)
	r.arm(payload, team, attacker, _hit, hits_left, _left_thrower)
	queue_free()

## Whether this is a thrown thing in an arc over the floor, which flies its arc
## out: nothing ends it but what it meets — a wall, a body in its
## way low enough — or the floor it comes down on, where the throw goes off
## (`Attacks.land`). Its range is a flat shot's, and ANTI-GRAVITY makes it one.
func lobbed() -> bool:
	return gravity > 0.0

## What this bolt can strike: the other side, and — off a thrown weapon, the
## rock or the rune, once it has been clear of them — whoever threw it.
func _struck_by() -> Array:
	var out := Attacks.targets(team)
	if _returning or thrown == "" or thrower == null or not is_instance_valid(thrower) or thrower.dead:
		return out
	if not _left_thrower:
		if global_position.distance_to(thrower.global_position) > radius + thrower.hurt_radius + LEAVE_MARGIN:
			_left_thrower = true
		return out
	# The Arena's list is not ours to add to.
	return out + [thrower]

func _expire() -> void:
	if is_rock():
		_fall_out()
		return
	if sticks != "":
		_drop_out()
		return
	queue_free()

## Brought down where it is, now: the rock falls from here and the shuriken
## drops, as out of the end of a throw, and any other bolt is simply gone.
## For the air being swept at a cut (`Raid`), so a thrown weapon is not swept
## with it.
func drop_now() -> void:
	_expire()

## Whether this bolt is the rock itself, and not a copy of it.
func is_rock() -> bool:
	return thrown != "" and not ghost

## The rock, done flying: it comes down where it is — or, off a wall, where it
## last stood in the open — sliding on at `moving`, tossed up `lift`, and lies
## there for whoever threw it.
func _come_down(moving: Vector2, from_open: bool = false, lift: float = 0.0) -> void:
	LooseRock.drop(thrown, _last_open if from_open else global_position, moving, room, thrower,
		height, lift)
	queue_free()

## How a rock comes back off the wall it has flown into: what was running
## along the wall carries on, slower, and what ran into it turns round.
func _off_the_wall() -> Vector2:
	if _crossed_into():
		return Vector2(velocity.x * 0.5, -velocity.y * 0.3)
	return Vector2(-velocity.x * 0.3, velocity.y * 0.3)

## Which way a bolt in the wall ran into it: whether the open place it came
## from is open straight across from where it stands — then it came up or down
## the screen into the wall, onto its face across — or not, and it came at the
## wall from the side.
func _crossed_into() -> bool:
	var level := Vector2(global_position.x, _last_open.y)
	return room != null and room.has_method("is_solid_at") and not room.is_solid_at(level)

## BOUNCE: back off the wall it has just flown into, at its full pace, from the
## last place it stood in the open — what ran into the wall turned round, what
## was running along it carried on. A homing bolt looks for its way again
## from here.
func _bounce() -> void:
	if _crossed_into():
		velocity.y = -velocity.y
	else:
		velocity.x = -velocity.x
	global_position = _last_open
	_has_waypoint = false
	_repath = 0.0
	Cues.at(&"impact", global_position, {"payload": payload, "kind": "bounce"})

## BOOMERANG: the bolt turns for home — whoever cast it, or the hands that
## threw it — with its range and its strikes fresh, flat, and steering for
## nothing but them (`_steer_home`). Whether it turned: not without a return
## on it, not twice, and not with nobody left to go back to, when it ends as it
## would have. Out of a wall it starts from the last open place before it.
func _turn_back() -> bool:
	if payload.returns <= 0 or _returning:
		return false
	var home := _home_actor()
	if home == null:
		return false
	_returning = true
	if room != null and room.has_method("is_solid_at") and room.is_solid_at(global_position):
		global_position = _last_open
	_travelled = 0.0
	_hit.clear()
	hits_left = 1 + payload.pierce
	gravity = 0.0
	height = minf(height, HAND_HEIGHT)
	vertical = 0.0
	homing_strength = 0.0
	_has_waypoint = false
	# At its full pace: a homing bolt braking in a turn, a lobbed stone at the
	# top of its arc, leaves for home as fast as it set out.
	var pace := maxf(velocity.length(), _pace)
	if pace < 1.0:
		pace = 420.0 * payload.speed
	velocity = (home.global_position - global_position).normalized() * pace
	life = maxf(life, LIFE)
	Cues.at(&"impact", global_position, {"payload": payload, "kind": "turn"})
	return true

## On the way home: turns toward whoever it is going back to, keeping its
## pace. With nobody left to go back to it flies on straight, and ends when its
## range does.
func _steer_home(delta: float) -> void:
	var home := _home_actor()
	if home == null:
		return
	var to := home.global_position - global_position
	if to.length() < 0.01:
		return
	var pace := velocity.length()
	velocity = velocity.lerp(to.normalized() * pace, clampf(RETURN_TURN * delta, 0.0, 1.0))
	if velocity.length() > 0.01:
		velocity = velocity.normalized() * pace

## Who a returning bolt goes back to: the hands that threw it — the body, or
## the monster the player is in — or else whoever cast it; null once they are
## dead or gone.
func _home_actor() -> Actor:
	if thrower != null and is_instance_valid(thrower) and not thrower.dead:
		return thrower.vessel()
	if attacker != null and is_instance_valid(attacker) and attacker is Actor and not attacker.dead:
		return attacker
	return null

## Home: a thrown stone is back in the hand that threw it, a shuriken back in
## its stack if there is room, and any other bolt simply done.
func _caught(home: Actor) -> void:
	if thrown != "" and not ghost and thrower != null and is_instance_valid(thrower) \
			and thrower.weapons.has(thrown) and not thrower.holds(thrown):
		thrower.take_back(thrown, home)
		Cues.at(&"rock_back", global_position, {"weapon": thrown})
	elif sticks != "" and thrower != null and is_instance_valid(thrower) and thrower.take_one_back(sticks):
		Cues.at(&"shuriken_back", global_position, {"weapon": sticks})
	queue_free()

## CHAIN: out of the enemy just struck, a fresh bolt at the nearest other one
## within sight that this bolt has not struck, with a jump fewer left on it
## and no return of its own (`Attacks.chain_bolt`). With no other enemy in
## sight the chain ends here.
func _chain_from(struck: Actor) -> void:
	var from := struck.global_position
	var best: Actor = null
	var best_d := CHAIN_SIGHT
	for a: Actor in Attacks.targets(team):
		if a == struck or _hit.has(a) or not is_instance_valid(a) or a.dead:
			continue
		var d := from.distance_to(a.global_position)
		if d < best_d:
			best_d = d
			best = a
	if best == null:
		return
	var link := payload.clone()
	link.chain = _chain_left - 1
	link.returns = 0
	link.duplicates = 1
	link.follow_up = true
	Attacks.chain_bolt(link, from, (best.global_position - from).normalized(), team, attacker, room, _hit)

## What this bolt is not to strike: what the bolt it is a link of struck
## already, the enemy it leaves among them.
func spare(struck: Array) -> void:
	_hit = struck.duplicate()

## The shuriken, done flying: stuck at `at` — in the wall it met, on the floor
## it came down on, or in `into`, the enemy it struck last — pointing the way
## it was going.
func _stick(at: Vector2, into: Actor = null) -> void:
	StuckShuriken.lodge(sticks, at, velocity, room, thrower, into)
	queue_free()

## The shuriken, out of throw with nothing struck: it drops from where it has
## got to, carrying on a little the way it went, until it is on the floor.
func _drop_out() -> void:
	StuckShuriken.drop(sticks, global_position, velocity * 0.2, room, thrower, height)
	queue_free()

## Where a bolt that has flown into the wall met it: between the last place it
## stood in the open and where it stands now, halved until it is a pixel either
## side — so a shuriken sticks at the face of the wall, and not a hop inside it.
func _surface() -> Vector2:
	var open := _last_open
	var shut := global_position
	if room == null or not room.has_method("is_solid_at"):
		return open
	for i in 6:
		var mid := open.lerp(shut, 0.5)
		if room.is_solid_at(mid):
			shut = mid
		else:
			open = mid
	return open

## Where the rock would come down if it were brought down now: for a room
## being walked out of with the rock still in the air.
func resting_place() -> Vector2:
	return _last_open
