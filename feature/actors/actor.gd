class_name Actor
extends CharacterBody2D

## Shared body for the player and every monster: health, elemental status and
## knockback. What an actor looks like is not here — `graphics/views/actor_view`
## attaches itself to every actor and reads the state below to draw it.
##
## A body stands on a floor seen from above and a little in front. Its
## position is where its feet are on that floor: the point everything in the
## world is measured from — a hit's reach, a monster's aggro, who is near —
## and the one the picture sorts by, so a body walks behind what is further
## up the screen and in front of what is further down. There is no gravity,
## no floor to be on and no wall to hug: `move_and_slide` carries it where it
## is going, and a wall is a thing it slides along (`MOTION_MODE_FLOATING`).

signal died(actor: Actor)
signal damaged(actor: Actor, amount: float)
## Health was given back (`heal`) — by how much it really rose.
signal healed(actor: Actor, amount: float)

## How long, once a stun is over, before another can take. A STUN on a board
## that strikes twice a second would otherwise hold a monster still for good:
## with this, one stands stunned for its stun and then has this long to act,
## however fast the stuns come. It is what keeps a stun from being a lock
## whatever a part's row says, so it is a rule here and not a number there.
const STUN_GUARD := 1.5

## The four ways a body faces, as the picture draws them: down the screen,
## up it, and to a side — the side mirrored for left and right (`side`).
const FACE_DOWN := "down"
const FACE_UP := "up"
const FACE_SIDE := "side"

@export var max_health: float = 40.0
var health: float = 40.0
## How far from the feet a hit reaches this body, on the floor.
var hurt_radius: float = 14.0
var team: int = 1  ## 0 = player, 1 = monsters
## Whether it is something to go after: what a homing bolt turns for, an aimed
## blow swings at, a pet picks and the aim leans toward (`Arena.sought`). A
## crate is struck by what reaches it and sought by nothing (`Crate`).
var sought: bool = true
## The silhouette the picture stands on the feet: how wide, and how tall it
## stands up the screen from them. The collider is not this: it is the
## footprint, a flat shape round the feet (`_make_body`).
var body_size: Vector2 = Vector2(20.0, 30.0)
## The footprint `_make_body` made.
var _collider: RectangleShape2D = null
## Which way the actor is facing, as a way on the floor of length 1. A dash
## with no direction held goes this way, so it is a rule and not only a
## turned sprite. It starts facing down the screen, toward whoever is looking.
var facing: Vector2 = Vector2.DOWN
## How far off the floor the body is, in world units: nothing for anything
## standing on it, a flyer's hover. Everything on the floor is measured from
## the feet whatever this says — a hit's reach, who is near — and the picture
## lifts the sprite by it and leaves the shadow at the feet.
var height: float = 0.0
## The last side the facing had anything of: 1 right, -1 left. What a sprite
## drawn for one side is mirrored by, kept while the body faces straight up or
## down so a turn back to the side comes back the way it left.
var _side: int = 1

var burn_time: float = 0.0
var burn_dps: float = 0.0
var chill_time: float = 0.0
## How long this actor stands stunned yet, doing nothing of its own (`stunned`),
## and once that is over, how long before another stun can take.
var stun_time: float = 0.0
var stun_guard: float = 0.0
## WATER leaves an actor wet for a while (`afflict`). Wet, ICE does not chill
## it but freezes it solid: it stands where it is for `FREEZE_TIME`, the way a
## stun holds it, and the wet is gone into the ice. FIRE on a wet one dries it
## rather than setting it alight, and WATER on a burning one puts it out. After
## a freeze another cannot take for `FREEZE_GUARD`, or a board carrying WATER
## and ICE together would hold what it struck frozen for good.
const WET_TIME := 6.0
const FREEZE_TIME := 2.5
const FREEZE_GUARD := 1.5
var wet_time: float = 0.0
var freeze_time: float = 0.0
var freeze_guard: float = 0.0
var invuln: float = 0.0
var dead: bool = false

func _ready() -> void:
	health = max_health
	# A floor seen from above has no up: nothing is a floor to stand on or a
	# ceiling to hit, and a wall is slid along whichever way it faces.
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("actors")

func speed_scale() -> float:
	return 0.45 if chill_time > 0.0 else 1.0

func _process_status(delta: float) -> void:
	if invuln > 0.0:
		invuln -= delta
	if chill_time > 0.0:
		chill_time -= delta
	if stun_time > 0.0:
		stun_time -= delta
		if stun_time <= 0.0:
			_come_round()
	elif stun_guard > 0.0:
		stun_guard -= delta
	if wet_time > 0.0:
		wet_time -= delta
	if freeze_time > 0.0:
		freeze_time -= delta
		if freeze_time <= 0.0:
			freeze_time = 0.0
			freeze_guard = FREEZE_GUARD
	elif freeze_guard > 0.0:
		freeze_guard -= delta
	if burn_time > 0.0:
		burn_time -= delta
		apply_damage(burn_dps * delta, [], null, false)

## Returns the damage actually dealt (0 when blocked or already dead).
##
## `is_hit` separates a struck blow from a tick of damage over time: a tick
## ignores i-frames (it is already paid for) and does not count as a connection,
## so nothing reacts to it. Burning through an invulnerable roll still hurts.
func apply_damage(amount: float, elements: Array = [], _source: Node = null, is_hit: bool = true) -> float:
	if dead or amount <= 0.0:
		return 0.0
	if invuln > 0.0 and is_hit:
		return 0.0
	health -= amount
	if is_hit:
		damaged.emit(self, amount)
	afflict(amount, elements)
	if health <= 0.0:
		_kill()
	return amount

## What a blow of `amount` carrying `elements` leaves on this actor: a burn for
## FIRE, as hard as the blow was, a chill for ICE, and a soaking for WATER —
## in the order the flow picked them up, so WATER then ICE is a freeze in one
## blow. Wet changes what the other two do (`WET_TIME`). None is cut short by a
## lesser one landing on it. `apply_damage` does this for the blow it lands; a
## hit that cleanses does it itself, once the cleanse has been through
## (`Attacks.resolve_hit`).
func afflict(amount: float, elements: Array) -> void:
	for e in elements:
		if e == "WATER":
			wet_time = WET_TIME
			burn_time = 0.0
			burn_dps = 0.0
		elif e == "FIRE":
			if wet_time > 0.0:
				wet_time = 0.0
				continue
			burn_time = maxf(burn_time, 2.5)
			burn_dps = maxf(burn_dps, amount * 0.22)
		elif e == "ICE":
			if wet_time > 0.0 and freeze_time <= 0.0 and freeze_guard <= 0.0:
				freeze()
			else:
				chill_time = maxf(chill_time, 2.0)

## Frozen solid: held where it stands for `FREEZE_TIME`, the wet gone into the
## ice. Frozen is chilled through, so SHATTER breaks it (`thaw`).
func freeze() -> void:
	wet_time = 0.0
	freeze_time = FREEZE_TIME
	chill_time = maxf(chill_time, FREEZE_TIME)

func frozen() -> bool:
	return freeze_time > 0.0

## The cold goes out of it: no chill, and no ice if it was frozen — which ends
## the freeze like any other, so the guard after one starts.
func thaw() -> void:
	chill_time = 0.0
	if freeze_time > 0.0:
		freeze_guard = FREEZE_GUARD
	freeze_time = 0.0

## Gives back up to `amount` health, never past the most this actor has, and
## says so (`healed`). Returns what it really gave back: nothing to the dead,
## and nothing to one already whole.
func heal(amount: float) -> float:
	if dead or amount <= 0.0:
		return 0.0
	var got := minf(max_health, health + amount) - health
	if got <= 0.0:
		return 0.0
	health += got
	healed.emit(self, got)
	return got

## Stuns this actor for `seconds`, unless it is stunned already — a stun is not
## stretched by another landing on it — or has only just come round from one
## (`STUN_GUARD`). Whether it took.
func stun(seconds: float) -> bool:
	if dead or seconds <= 0.0 or stun_time > 0.0 or stun_guard > 0.0:
		return false
	stun_time = seconds
	return true

## Whether this actor is stunned: it stands where it is and does nothing of its
## own. A monster neither moves, casts nor touches (`Enemy`); the player's
## hands are taken off their line (`Player`).
func stunned() -> bool:
	return stun_time > 0.0 or freeze_time > 0.0

## Ends every burn, chill, soaking, freeze and stun on this actor at once. A
## stun or a freeze ended early is over like any other, so the guard after one
## starts. Whether there was anything to end.
func cleanse() -> bool:
	var had := burn_time > 0.0 or chill_time > 0.0 or stun_time > 0.0 or wet_time > 0.0 or freeze_time > 0.0
	burn_time = 0.0
	burn_dps = 0.0
	wet_time = 0.0
	thaw()
	if stun_time > 0.0:
		_come_round()
	return had

func _come_round() -> void:
	stun_time = 0.0
	stun_guard = STUN_GUARD

## A push the world is putting on this actor — a PUSH, a PULL —
## kept apart from the motion the actor chooses for itself.
##
## Every body here assigns `velocity` outright each physics frame: a turret
## writes zero into it, a patroller writes its patrol speed, a runner walks it
## towards its quarry. A push added into `velocity` was therefore gone before it
## had moved anything — a Sentry or a Lobber did not budge at all, and a drag
## that is nothing but pushes did nothing whatsoever. It has to live somewhere
## the movement code does not write.
var shove: Vector2 = Vector2.ZERO

## How fast a push bleeds off, in pixels per second per second. A shove reads as
## something that lands and is then over: at this rate a push of three hundred
## runs for about half a second and carries an enemy some seventy pixels.
const SHOVE_DECAY := 620.0

## Below this there is no push left worth moving anything for.
const SHOVE_MIN := 8.0

## A wall slam: an actor KNOCKBACK threw (`knockback`'s `slam_by`) that meets
## rock still going at least SLAM_SPEED into it, in pixels a second, cracks the
## rock (the `wall_slam` cue, which is the picture's) and is hurt and stunned
## by it. The hurt is SLAM_DAMAGE at that speed and as much more again as it was
## going faster, so a throw that has further to fly hits softer; the stun is
## SLAM_STUN, and is held to the same guard as any other. One slam to a throw:
## the push that is left runs along the wall as it always did.
##
## At this speed one KNOCKBACK on an ordinary hit slams into a wall up to about
## three cells away, and two up to twelve; a hit with no KNOCKBACK never does,
## however hard, nor does a PULL's drag.
const SLAM_SPEED := 260.0
const SLAM_DAMAGE := 10.0
const SLAM_STUN := 0.8
## The clock stops a moment on a slam, as on a hit (`Attacks.HITSTOP`).
const SLAM_HITSTOP := 0.05

## The side that threw this actor with KNOCKBACK, for as long as that throw is
## still carrying it — or -1 for a push that slams nothing. A kill a slam makes
## is that side's: one the player threw counts as the player's.
var slam_by: int = -1

## `slam_by` is the side throwing it with KNOCKBACK, whose throw can slam it into
## a wall; -1 for every other push.
func knockback(dir: Vector2, force: float, thrower: int = -1) -> void:
	shove += dir.normalized() * force
	if thrower >= 0:
		slam_by = thrower

## Moves the body by whatever the world is pushing it with, and lets that push
## die down. A body calls this once a physics frame, straight after its own
## `move_and_slide`, so the two motions stay separate and neither erases the
## other.
func apply_shove(delta: float) -> void:
	if shove.length() < SHOVE_MIN:
		shove = Vector2.ZERO
		slam_by = -1
		return
	var hit := move_and_collide(shove * delta)
	if hit != null:
		var into := shove.dot(-hit.get_normal())
		if slam_by >= 0 and into >= SLAM_SPEED and _is_rock(hit.get_collider()):
			_slam(hit.get_position(), hit.get_normal(), into)
		# Run along whatever stopped it rather than sticking to it, so a drag
		# that meets a wall still gathers the room along that wall.
		shove = shove.slide(hit.get_normal())
	shove = shove.move_toward(Vector2.ZERO, SHOVE_DECAY * delta)

## Whether what stopped a push is the world's rock — a room's, on the world's
## collision layer — and not another body.
static func _is_rock(c: Object) -> bool:
	return c is StaticBody2D and ((c as StaticBody2D).collision_layer & 1) != 0

## Thrown into rock at `speed`, meeting it at `at` on a face turned to `toward`:
## the rock cracks, and this actor is hurt and stunned (`SLAM_SPEED`). The throw
## is spent on it.
func _slam(at: Vector2, toward: Vector2, speed: float) -> void:
	var by := slam_by
	slam_by = -1
	var force := speed / SLAM_SPEED
	Cues.at(&"wall_slam", at, {"normal": toward, "force": force, "target_team": team})
	TimeCtl.hitstop(SLAM_HITSTOP)
	var dealt := apply_damage(SLAM_DAMAGE * force)
	if dead:
		if dealt > 0.0 and by == 0 and team != 0:
			GameState.register_kill()
		return
	if stun(SLAM_STUN):
		Cues.at(&"stun", global_position, {"seconds": SLAM_STUN, "target_team": team})

func _kill() -> void:
	if dead:
		return
	dead = true
	died.emit(self)
	Cues.at(&"death", global_position, {"actor": self})
	queue_free()

func health_ratio() -> float:
	return clampf(health / maxf(max_health, 1.0), 0.0, 1.0)

## Turns the actor to face `dir`, a way on the floor; zero leaves it as it is.
func face(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return
	facing = dir.normalized()
	if facing.x != 0.0:
		_side = 1 if facing.x > 0.0 else -1

## The side the body is turned to: 1 right, -1 left. Facing straight up or
## down it is the side last turned to, so a sprite drawn for one side is
## mirrored the way the body was going.
func side() -> int:
	return _side

## Which of the four drawn facings the body shows: down the screen, up it, or
## a side — whichever of the two axes the facing has more of, the side on a
## tie, as a body walking a diagonal reads as walking across.
func facing_name() -> String:
	return face_name_of(facing)

## The same for any way on the floor: what a body that is not an actor — an
## NPC, a cutscene's cast — asks, so every body picks its strip by one rule.
static func face_name_of(dir: Vector2) -> String:
	if absf(dir.y) > absf(dir.x):
		return FACE_DOWN if dir.y > 0.0 else FACE_UP
	return FACE_SIDE

## Adds the footprint: a flat collider round the feet, as wide as the
## silhouette and a little over half that deep, so a body slides along walls
## and stands a little way into a doorway before it is through. `h` is how
## tall the picture stands up from the feet, kept for whoever draws it.
func _make_body(w: float, h: float) -> void:
	body_size = Vector2(w, h)
	var shape := CollisionShape2D.new()
	_collider = RectangleShape2D.new()
	_collider.size = Vector2(w, w * 0.6)
	shape.shape = _collider
	add_child(shape)
