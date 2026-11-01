class_name Attacks
extends RefCounted

## Turns a resolved Payload into real things in the world, and resolves the
## hits those things cause (including trigger payloads).

## Every living actor that `team` is allowed to hurt.
## Every actor something of `team` can strike: the ones not on its side,
## alive. The Arena keeps the list (`Arena.against`), so this is a lookup and
## not a walk of the tree; it is the Arena's list, so read it and do not
## change it — one that wants its thrower or its caster besides adds them to a
## copy of its own.
static func targets(team: int) -> Array:
	return Arena.against(team)

## Of those, what is worth going after (`Arena.sought`): a crate is struck by
## whatever reaches it, and turned toward by nothing.
static func quarries(team: int) -> Array:
	return Arena.sought(team)

static func nearest_target(pos: Vector2, team: int, max_dist: float = 1e9) -> Actor:
	var best: Actor = null
	var best_d := max_dist
	for a in quarries(team):
		var d: float = pos.distance_to(a.global_position)
		if d < best_d:
			best_d = d
			best = a
	return best

## What an AUTO-AIM flow goes at from `from`: the nearest enemy within its
## sight, or null — and null for a flow with no AUTO-AIM on it.
static func auto_target(p: Payload, from: Vector2, team: int) -> Actor:
	if p.auto_aim <= 0:
		return null
	return nearest_target(from, team, auto_aim_sight(p))

static func auto_aim_sight(p: Payload) -> float:
	var sight := AUTO_AIM_SIGHT * (1.0 + AUTO_AIM_FURTHER * float(maxi(p.auto_aim - 1, 0)))
	if p.form == "PROJECTILE":
		sight = maxf(sight, p.range_px)
	elif p.form == "DASHSLASH":
		sight = maxf(sight, dash_slash_reach(p))
	return sight

## How far SWIFT STRIKE off `p` lunges when it is aimed all the way: its own
## reach, carried further by SIZE and RANGE (`Payload.lunge`).
static func dash_slash_reach(p: Payload) -> float:
	return DASH_SLASH_REACH * p.size * p.lunge

static func container() -> Node:
	return Arena.current()

## Everything an attack has put into the world and not finished with: bolts in
## the air, arcs and lunges still swinging, bursts still opening, and the
## follow-ups waiting their turn to fire.
##
## They are parented to the screen rather than to the room, because an attack
## has to outlive the actor that made it — so nothing about a room going away
## takes them with it, and a bolt fired on the way out of one room carried on
## across the next one, testing itself against walls that no longer existed. A
## screen calls this whenever the ground under them is replaced: a room change,
## a floor reset.
static func clear_in_flight(w: Node = null) -> void:
	var host: Node = w if w != null else container()
	if host == null or not is_instance_valid(host):
		return
	for c in host.get_children():
		if c is Projectile or c is MeleeArc or c is DashSlash or c is AreaBurst or c is Deferred:
			# Silenced as well as freed. A node queued for deletion still runs
			# out the frame it was queued in, and one of these taking a last
			# turn is not harmless: a follow-up coming due in those milliseconds
			# spawns a fresh attack, which lands in the world *after* this sweep
			# has been round and is the one thing it was meant to stop.
			c.process_mode = Node.PROCESS_MODE_DISABLED
			c.queue_free()

## A trigger's follow-up waits this long rather than going off inside the hit
## that caused it. Fired inline, a whole chain ran within a single frame, and
## every link read the attacker's position from before the current attack had
## moved them — so four chained dash-slashes computed the same start and the
## same destination and landed exactly on top of each other, reading as one
## dash that happened to hit four times. A beat between links lets each one
## start from where the last finished, and gives each its own dash to watch.
##
## What that needs is the frame after the hit, not a seventh of a second. At
## 0.14 a nine-link chain spent a second working through a room one metronome
## beat at a time, which is a chain of separate strikes rather than one long
## one; this is a few frames, enough to read each link and to let the lunge
## before it land the attacker.
const TRIGGER_DELAY := 0.045

## What one connection takes off the clock.
##
## A chain's links take the lighter one: the whole chain is a single blow, and
## stopping the clock in full for each of nine of them reads as a stutter rather
## than as a strike — and spends most of a second of real time doing it, because
## every stop slams the scale down and then eases back over the best part of ten
## frames.
const HITSTOP := 0.035
const CHAIN_HITSTOP := 0.010

## How far a lunge travels at size 1 with no RANGE on it. For DASHSLASH this is
## the cap on aiming it: the cursor decides where inside that range it lands.
## SIZE and RANGE carry it further (`Payload.lunge`).
const DASH_SLASH_REACH := 85.0

## HEADBUTT, PUNCH to a player. How far past the body's own reach the fist goes
## at size 1 with nothing in the way — a step, about a body and a half, where
## SWIFT STRIKE dashes — and how far to either side of its line it meets what
## is there. SIZE carries both further, as it
## does a swing's; RANGE does nothing to it, as to a swing.
const HEADBUTT_REACH := 44.0
const HEADBUTT_WIDTH := 12.0

## AUTO-AIM. How far one looks for something to go at, and how much further
## each one stacked looks: the first looks as far as SWIFT STRIKE+ used to,
## which was SWIFT STRIKE with this built in. A bolt looks as far as it
## carries, and a lunge as far as it lunges, if that is further, so one with
## RANGE on it goes at anything it can reach (`auto_aim_sight`).
const AUTO_AIM_SIGHT := 520.0
const AUTO_AIM_FURTHER := 0.5

## How much of its own distance an attack aimed at the shortest reach still
## covers. The right stick says how far a cast goes (`Player.aim_reach`, the
## `reach` a spawn is handed): a bolt's range, a thrown shot's arc, a lunge.
## Pushed just past its dead zone it goes this share of the way, and at
## the rim all of it. A burst and a swing happen where the caster stands and do
## not move with it.
const REACH_MIN := 0.3

## `reach`, 0 to 1, as the share of an attack's own distance it covers.
static func distance_for(reach: float) -> float:
	return lerpf(REACH_MIN, 1.0, clampf(reach, 0.0, 1.0))

## KNOCKBACK. The push it adds to a hit, in pixels a second, straight along the
## way the attack was going — on top of the hit's own shove, not instead of it.
## Bled off at `Actor.SHOVE_DECAY`, it carries an enemy that stands its ground
## some five cells, where an ordinary hit moves one less than a cell. Every
## KNOCKBACK stacked pushes as hard again. Thrown into a wall hard enough, the
## enemy cracks it and is hurt and stunned (`Actor.SLAM_SPEED`).
const KNOCKBACK_FORCE := 300.0

## PULL — and what an INVERT makes of KNOCKBACK, which is the same: how far
## short of whoever struck it the enemy dragged in stops, about a body apart.
const HOOK_SHORT := 28.0

## The shove every hit gives the enemy it strikes, along the attack, before
## anything on the flow adds to it or takes its place.
static func hit_shove(p: Payload) -> float:
	return 120.0 + p.damage * 2.0

## How hard `p`'s PULL drags, toward whoever struck: as hard as KNOCKBACK throws
## — the hit's own shove and KNOCKBACK_FORCE for every one stacked — and no
## harder than carries the enemy `far`, the gap to HOOK_SHORT of them, before
## the push bleeds off (`Actor.SHOVE_DECAY`): it ends up nearer them, never past.
static func hook_force(p: Payload, far: float) -> float:
	var strength := hit_shove(p) + KNOCKBACK_FORCE * float(p.hook)
	return minf(strength, sqrt(2.0 * Actor.SHOVE_DECAY * maxf(far, 0.0)))

## NEAR. How far round the enemy struck it reaches at size 1, about three
## cells, and how much further every NEAR stacked past the first carries it.
## KAMIKAZE's blast is as wide, and as much wider for each one stacked.
const NEAR_RADIUS := 90.0
const NEAR_WIDER := 0.5

## SHATTER. What a hit is worth against an enemy frost has already slowed: the
## frost breaks, the hit lands this much harder for every SHATTER stacked, and
## the enemy thaws. Breaking it is what pays, so there is one break to a chill —
## a board has to freeze them again to do it again.
const SHATTER_PER := 1.5

## MANA DRAIN. What one connection gives the caster back, for every MANA DRAIN
## stacked. Each connection pays, so a board that lands three bolts drains
## three times — that is what a leech build is for — and a trigger's follow-up
## pays like any other hit.
const MANA_PER_HIT := 6.0

## HEALTH DRAIN. The share of what a hit dealt that whoever struck it gets back
## as health, for every HEALTH DRAIN stacked. It is paid out of damage dealt, so
## a hit that hurt nothing — POSSESS taking a monster — heals nothing.
const HEALTH_DRAIN_SHARE := 0.2

## What a hit carrying `stacked` SHATTERs is multiplied by on a chilled enemy.
static func shatter_mul(stacked: int) -> float:
	return 1.0 + SHATTER_PER * float(stacked)

## How far `p`'s NEAR reaches round the enemy struck: its size, and every NEAR
## stacked on it.
static func near_radius(p: Payload) -> float:
	return reach_of(p.size, p.near)

## How far round its middle a reach of `stacked` NEARs — or KAMIKAZEs — goes at
## `size`.
static func reach_of(size: float, stacked: int) -> float:
	return NEAR_RADIUS * size * (1.0 + NEAR_WIDER * float(maxi(stacked - 1, 0)))

## Staggered follow-ups (DUPLICATE, multi-hit forms, triggers) are scheduled by
## a small node rather than a captured lambda: an attacker can die between the
## first strike and the last, and a node can re-check that before it fires.
class Deferred extends Node:
	var t: float = 0.0
	## "spawn" for a whole spawn put off — a trigger's follow-up — or "" for one
	## cast of a volley, the `i`-th of `count`, of the form `form`.
	var kind: String = ""
	var form: String = ""
	var i: int = 0
	var count: int = 1
	var payload: Payload
	var aim: Vector2 = Vector2.RIGHT
	var pos: Vector2 = Vector2.ZERO
	var team: int = 0
	## Untyped for the same reason `resolve_hit` takes it loose: the attacker
	## can be torn down while this is still counting down.
	var attacker = null
	var room: Node = null
	var ctx: Dictionary = {}
	## How far a scheduled lunge goes — see `Attacks.distance_for`.
	var far: float = 1.0

	func _process(delta: float) -> void:
		t -= delta
		if t > 0.0:
			return
		var atk: Actor = attacker if is_instance_valid(attacker) and attacker is Actor else null
		if kind == "spawn":
			# The full spawn path, so a trigger's attack behaves exactly as it
			# would fired straight off the board.
			var c := ctx.duplicate()
			c["attacker"] = atk
			# The attack that caused this has moved the attacker since, so a
			# follow-up aims where they are aiming now rather than down the
			# hit that triggered it: a chain of lunges kept on the old heading
			# walks past the target and every link after the first misses. The
			# origin stays at the impact point, so an ON HIT burst or bolt
			# still comes from where the hit landed.
			if atk != null:
				var live_aim = atk.get("aim")
				if live_aim is Vector2 and (live_aim as Vector2).length() > 0.01:
					c["aim"] = live_aim
			Attacks.spawn(payload, c)
		else:
			Attacks.cast_form(form, payload, aim, pos, team, atk, room, far, ctx, i, count)
		queue_free()

## Puts off the `i`-th cast of a volley of `count`, of `form`, by `seconds`.
static func _schedule(seconds: float, form: String, p: Payload, aim: Vector2, pos: Vector2,
		team: int, attacker: Actor, room, far: float, ctx: Dictionary, i: int, count: int) -> void:
	var w := container()
	if w == null or not is_instance_valid(w):
		return
	var d := Deferred.new()
	d.t = seconds
	d.form = form
	d.i = i
	d.count = count
	d.payload = p
	d.aim = aim
	d.pos = pos
	d.team = team
	d.attacker = attacker
	d.room = room
	d.far = far
	d.ctx = ctx
	w.add_child(d)

## Schedules a whole `spawn` — used for trigger follow-ups, which need the form
## re-resolved from scratch rather than one fixed attack kind.
static func _schedule_spawn(seconds: float, p: Payload, ctx: Dictionary) -> void:
	var w := container()
	if w == null or not is_instance_valid(w):
		return
	var d := Deferred.new()
	d.t = seconds
	d.kind = "spawn"
	d.payload = p
	d.ctx = ctx.duplicate()
	d.attacker = ctx.get("attacker", null)
	w.add_child(d)

## ctx keys: attacker (Actor), room (Node), aim (Vector2), team (int),
##           origin (Vector2), lobbed (bool — the bolts fly an arc over the
##           floor and come down where they land), aim_point (Vector2 — where
##           on the floor the aim is, which is where a lobbed bolt comes down;
##           down the aim as far as it carries when it is not said), reach
##           (float, 0 to 1 — how far the aim asks the attack to go; all of it
##           when it is not said),
##           and for a thrown weapon's bolts thrown (the weapon id), thrower
##           (the Player whose it is) and ghost (bool — every one of them a
##           copy, the weapon itself having gone already); for a stacked
##           weapon's, sticks (the weapon id: every bolt is one of the stack,
##           and sticks where it strikes) and thrower
static func spawn(payload: Payload, ctx: Dictionary) -> void:
	var w := container()
	if w == null or not is_instance_valid(w):
		return
	var attacker: Actor = ctx.get("attacker", null)
	var team: int = int(ctx.get("team", 0))
	var room = ctx.get("room", null)
	var aim: Vector2 = ctx.get("aim", Vector2.RIGHT)
	if aim.length() < 0.01:
		aim = Vector2.RIGHT
	aim = aim.normalized()
	var origin: Vector2 = ctx.get("origin", attacker.global_position if attacker != null else Vector2.ZERO)
	var far := distance_for(float(ctx.get("reach", 1.0)))

	# AUTO-AIM: at the nearest enemy, whatever the aim said. A lunge looks for
	# it again as it goes off (`_dash_slash`), which a volley's later ones do a
	# moment after this one.
	var locked := auto_target(payload, origin, team)
	if locked != null:
		var at := locked.global_position
		# A homing bolt leaves along the way round whatever stands between —
		# the floor under the feet of whoever loosed it, the edge of a ledge —
		# and its HOMING keeps it to that way. One without HOMING could not
		# follow it, so it goes straight, as AUTO-AIM says.
		if payload.form == "PROJECTILE" and payload.homing > 0:
			at = Projectile.way_toward(room, origin, at)
		aim = (at - origin).normalized()

	# What the attack calls up beside itself: a pet. Whatever the form, and
	# with none.
	if payload.summon_pet > 0:
		_summon_pet(payload, attacker)

	var count: int = clampi(payload.duplicates, 1, 9)
	# A thrown weapon throws itself (`Weapons.is_thrown`): the first of the
	# volley is the weapon, unless the flow says it is a copy, and the rest are
	# copies of it.
	var thrown := String(ctx.get("thrown", ""))
	# A stacked weapon throws one of itself a bolt (`Weapons.is_stacked`), and
	# each sticks where it strikes.
	var sticks := String(ctx.get("sticks", ""))
	# One announcement per cast, whatever the duplicate count: the form is what
	# the moment sounds like, and three bolts are one volley. A shuriken goes
	# out of the hand the way the rock does, so it is heard as a throw too.
	Cues.at(&"attack", origin, {"form": payload.form, "payload": payload, "aim": aim,
		"thrown": thrown if thrown != "" else sticks})
	var form: Dictionary = forms().get(payload.form, {})
	if form.is_empty():
		return
	# The first of a volley now, and each after it a little later, by the
	# form's own spacing — a bolt's all at once.
	for i in count:
		var wait := float(form["delay"]) * float(i)
		if wait <= 0.0:
			cast_form(payload.form, payload, aim, origin, team, attacker, room, far, ctx, i, count)
		else:
			_schedule(wait, payload.form, payload, aim, origin, team, attacker, room, far, ctx, i, count)

## Every form an attack goes off as, by its id — and "" for a flow with no
## form, which goes off as the NEAR on it: how long each of a volley's later
## casts waits on the one before (`delay`), and how one cast is made (`cast`),
## the `i`-th of `count`. One table for a cast made now (`spawn`) and one put
## off (`Deferred`), so the two cannot disagree about what a form is.
static var _forms: Dictionary = {}

static func forms() -> Dictionary:
	if _forms.is_empty():
		_forms = {
			"PROJECTILE": {"delay": 0.0, "cast": _cast_bolt},
			"SLASH": {"delay": 0.07, "cast": _cast_slash},
			"": {"delay": 0.1, "cast": _cast_near},
			"DASHSLASH": {"delay": 0.12, "cast": _cast_lunge},
			"HEADBUTT": {"delay": 0.12, "cast": _cast_punch},
		}
	return _forms

## One cast of `form`: the `i`-th of a volley of `count`, aimed `aim` from
## `origin`, as far as `far` says.
static func cast_form(form: String, p: Payload, aim: Vector2, origin: Vector2, team: int, atk: Actor,
		room, far: float, ctx: Dictionary, i: int, count: int) -> void:
	var f: Dictionary = forms().get(form, {})
	if f.is_empty():
		return
	(f["cast"] as Callable).call(p, aim, origin, team, atk, room, far, ctx, i, count)

## A bolt: a volley fans out 16 degrees either side. A thrown weapon throws
## itself (`Weapons.is_thrown`) — the first of the volley is the weapon, unless
## the flow says it is a copy, and the rest are copies — and a stacked one
## throws one of itself a bolt (`Weapons.is_stacked`), each sticking where it
## strikes. ANTI-GRAVITY takes the weight off a bolt that would have arced.
static func _cast_bolt(p: Payload, aim: Vector2, origin: Vector2, team: int, atk: Actor, room,
		far: float, ctx: Dictionary, i: int, count: int) -> void:
	var spread := 0.0 if count == 1 else deg_to_rad(lerpf(-16.0, 16.0, float(i) / float(count - 1)))
	var thrown := String(ctx.get("thrown", ""))
	var sticks := String(ctx.get("sticks", ""))
	var lobbed := bool(ctx.get("lobbed", false)) and p.anti_gravity <= 0
	var n := _projectile(p, origin, aim.rotated(spread), team, atk, room, lobbed, far,
		ctx.get("aim_point", Vector2.INF), thrown != "" or sticks != "")
	if thrown != "":
		n.thrown = thrown
		n.thrower = ctx.get("thrower", null)
		n.ghost = i > 0 or bool(ctx.get("ghost", false))
	elif sticks != "":
		n.sticks = sticks
		n.thrower = ctx.get("thrower", null)

## A swing: a volley fans out 22 degrees either side.
static func _cast_slash(p: Payload, aim: Vector2, _origin: Vector2, team: int, atk: Actor, room,
		_far: float, _ctx: Dictionary, i: int, count: int) -> void:
	var off := 0.0 if count == 1 else deg_to_rad(lerpf(-22.0, 22.0, float(i) / float(count - 1)))
	_melee(p, aim.rotated(off), team, atk, room)

## No form, so no blow and no enemy struck: a NEAR on the flow is the attack,
## touching the enemies round where it is cast — a monster's board that is
## one, a trigger's branch with one on it, at the hit that set it off. A volley
## scatters round the point. Without one, nothing goes off.
static func _cast_near(p: Payload, _aim: Vector2, origin: Vector2, team: int, atk: Actor, room,
		_far: float, _ctx: Dictionary, i: int, _count: int) -> void:
	if p.near <= 0 or p.spread == null:
		return
	var pos := origin + (Vector2.ZERO if i == 0 else Vector2(randf_range(-70, 70), randf_range(-40, 40)))
	_near_here(p, pos, team, atk, room)

static func _cast_lunge(p: Payload, aim: Vector2, _origin: Vector2, team: int, atk: Actor, room,
		far: float, _ctx: Dictionary, _i: int, _count: int) -> void:
	_dash_slash(p, aim, team, atk, room, far)

static func _cast_punch(p: Payload, aim: Vector2, _origin: Vector2, team: int, atk: Actor, room,
		_far: float, _ctx: Dictionary, _i: int, _count: int) -> void:
	_headbutt(p, aim, team, atk, room)

## A bolt off `p`, leaving `pos` along `dir`. Flat, it flies along the floor
## as far as its range and `far` say. Lobbed, it is thrown in an arc over the
## floor and comes down where the aim is — `aim_point`, no further than it
## carries and no further than `far` asks — under the world's pull on a
## thrown thing, the rock or a shuriken, or the easier lob a monster's shot
## has (`Projectile.lob`).
static func _projectile(p: Payload, pos: Vector2, dir: Vector2, team: int, atk: Actor, room,
		lobbed: bool, far: float = 1.0, aim_point: Vector2 = Vector2.INF, heavy: bool = false) -> Projectile:
	var n := Projectile.new()
	n.setup(p, pos, dir, team, atk, room)
	if lobbed:
		var carry := n.range_px * far
		if aim_point != Vector2.INF:
			carry = minf(carry, pos.distance_to(aim_point))
		n.lob(carry, Projectile.THROW_GRAVITY if heavy else Projectile.LOB_GRAVITY)
	else:
		n.range_px *= far
	container().add_child(n)
	return n

## CHAIN. One link of it: a fresh bolt off `p` leaving `from` along `dir` — out
## of the enemy struck, at the nearest other — sparing everything the bolt
## before it struck (`struck`), the one it leaves among them. It flies flat
## and fades, whatever the bolt before it was: a thrown stone's links are
## bolts, not stones, and the stone itself goes on as it would have.
static func chain_bolt(p: Payload, from: Vector2, dir: Vector2, team: int, atk: Actor, room,
		struck: Array) -> Projectile:
	var n := _projectile(p, from, dir, team, atk, room, false)
	n.spare(struck)
	Cues.at(&"chain", from, {"payload": p, "aim": dir})
	return n

static func _melee(p: Payload, dir: Vector2, team: int, atk: Actor, room) -> void:
	if atk == null or not is_instance_valid(atk):
		return
	if room != null and not is_instance_valid(room):
		room = null
	var n := MeleeArc.new()
	n.setup(p, dir, team, atk, room)
	container().add_child(n)
	Cues.at(&"melee_arc", n.global_position, {"payload": p})

## What a NEAR on `p` lands on each enemy it touches: what the parts after it
## did (`Payload.spread`) and nothing of the blow — but for what was the enemy
## struck's alone: another NEAR, or every touch would reach on again; and
## POSSESS, since the hands go into one monster. Its triggers go only with a
## NEAR that is the attack (`_near_here`). Its middle is `at` — the enemy
## struck, or where a NEAR with no form goes off — which a PULL on it drags the
## enemy touched in to. A touch stops the clock as lightly as a chain's link.
static func _touching(p: Payload, strength: float, at: Vector2) -> Payload:
	var t := p.spread.clone()
	t.form = ""
	t.near = 0
	t.spread = null
	t.possess = 0.0
	t.touch_at = at
	t.on_hit = null
	t.on_kill = null
	t.on_parry = null
	t.follow_up = true
	t.touch = maxf(strength, 0.0)
	return t

## NEAR on a flow with no form: there is no blow and nobody struck, and the
## enemies round `pos`, where it goes off, are touched by what came after it —
## its triggers going off on every one, since this is the attack.
static func _near_here(p: Payload, pos: Vector2, team: int, atk: Actor, room) -> void:
	var t := _touching(p, 0.0, pos)
	t.on_hit = p.on_hit
	t.on_kill = p.on_kill
	t.on_parry = p.on_parry
	_go_off(t, pos, near_radius(p), team, atk, room, null, &"near", atk is Player)

## A thrown stone — the rock, the rune — that meets the room's rock with its
## throw not yet spent casts what it carried there, where it stopped: a wall it
## flew into, the ground it fell to. A NEAR on it touches everything round the
## point, as a NEAR with no form does where it goes off, and an ON HIT on it
## goes off from the point, aimed the way the stone was going. Nothing else it
## carries has anything to land on. One spent on what it struck lands harmless,
## so a throw goes off once: on the enemy it hits, or where it stops.
static func land(p: Payload, pos: Vector2, dir: Vector2, atk: Actor, room, team: int) -> void:
	if atk != null and not is_instance_valid(atk):
		atk = null
	if room != null and not is_instance_valid(room):
		room = null
	if p.near > 0 and p.spread != null:
		_near_here(p, pos, team, atk, room)
	if p.on_hit != null:
		_schedule_spawn(TRIGGER_DELAY, _follow(p.on_hit), {
			"attacker": atk, "room": room, "team": team,
			"aim": dir if dir.length() > 0.01 else Vector2.RIGHT, "origin": pos, "lobbed": false,
		})
	Cues.at(&"stone_cast", pos, {"payload": p})

## NEAR on a hit: the enemies round the one `struck` at `pos` are touched by
## what came after it on the flow — not the enemy struck again, which has taken
## the whole of it — what they carry landing as hard as the blow did, `dealt`.
##
## A NEAR the player cast touches the player too, standing in its reach: what
## came after it lands on them as on an enemy — a HEAL heals them, a FIRE burns
## them. A monster's NEAR spares the monster that cast it.
static func _near(p: Payload, struck: Actor, pos: Vector2, dealt: float, atk: Actor, room, team: int) -> void:
	_go_off(_touching(p, dealt, struck.global_position), pos, near_radius(p), team, atk, room, struck, &"near",
		atk is Player)

## A ring of `p` opening at `pos` out to `radius`, round `spared` if it is
## given one, landing on everything it reaches, and heard and seen as `cue`.
static func _go_off(p: Payload, pos: Vector2, radius: float, team: int, atk: Actor, room,
		spared: Actor = null, cue: StringName = &"area_blast", hits_self: bool = false) -> void:
	var w := container()
	if w == null or not is_instance_valid(w):
		return
	if atk != null and not is_instance_valid(atk):
		atk = null
	if room != null and not is_instance_valid(room):
		room = null
	var n := AreaBurst.new()
	n.setup(p, pos, team, atk, room, radius, spared)
	n.hits_self = hits_self and atk != null
	w.add_child(n)
	Cues.at(cue, pos, {"payload": p})

static func _dash_slash(p: Payload, aim: Vector2, team: int, atk: Actor, room, far: float = 1.0) -> void:
	if atk == null or not is_instance_valid(atk):
		return
	if room != null and not is_instance_valid(room):
		room = null
	var start: Vector2 = atk.global_position
	var reach := dash_slash_reach(p) * far
	var dest: Vector2
	if p.auto_aim > 0:
		# AUTO-AIM: all the way to the nearest enemy and through it, however
		# far its reach — or, with nothing in sight, down the aim.
		var t := auto_target(p, start, team)
		if t == null:
			dest = start + aim * reach
		else:
			# The shortest lunge that still carries the cut past the target:
			# out to its centre, then just clear of its far side. Overshooting
			# by a fixed margin threw the attacker further away than the strike
			# needed and left the next one further to travel.
			var to: Vector2 = t.global_position - start
			var away: Vector2 = to.normalized() if to.length() > 0.01 else aim
			dest = start + away * (to.length() + t.hurt_radius + atk.hurt_radius)
	else:
		# Land on what the attacker is pointing at rather than a fixed distance
		# down the aim, so the lunge goes where it is aimed. Past the skill's
		# reach it still stops at the reach, which is what SIZE and RANGE buy. An
		# attacker with nothing to point at — every monster — keeps the aim.
		var want := start + aim * reach
		var pt = atk.get("aim_point")
		if pt is Vector2:
			want = pt
		dest = start + (want - start).limit_length(reach)
	if room != null and room.has_method("clamp_dash"):
		dest = room.clamp_dash(start, dest)
	var n := DashSlash.new()
	n.setup(p, start, dest, team, atk, room)
	container().add_child(n)
	Cues.at(&"lunge_cut", start, {"payload": p, "to": dest})

## A pet for whoever cast the flow, if they have none: one to a summoner. One
## already there is told again what it does — what this flow says (`Pet.take`).
static func _summon_pet(p: Payload, atk: Actor) -> void:
	var w := container()
	if w == null or not is_instance_valid(w) or atk == null or not is_instance_valid(atk):
		return
	var carried := p.clone()
	carried.summon_pet = 0
	var there := Pet.of(atk, w.get_tree())
	if there != null:
		there.take(carried)
		return
	var pet := Pet.new()
	pet.summoner = atk
	pet.take(carried)
	w.add_child(pet)
	pet.global_position = pet.home()
	Cues.at(&"summon_pet", pet.global_position, {})

## KAMIKAZE: a pet blowing itself up at `pos` (`Pet`). The flow it was summoned
## with goes off there as a blast, the whole of it landing on everything round
## — its every hit the attack's, triggers and all, as its summoner's blow — out
## as far as a NEAR reaches, and as much further for every KAMIKAZE stacked. A
## NEAR on the flow reaches on from none of its hits.
static func kamikaze(p: Payload, pos: Vector2, team: int, atk: Actor, room) -> void:
	var blast := p.clone()
	blast.near = 0
	blast.spread = null
	Cues.at(&"pet_kamikaze", pos, {"payload": p})
	_go_off(blast, pos, reach_of(p.size, maxi(p.pet_kamikaze, 1)), team, atk, room)

## HEADBUTT, PUNCH to a player: a fist thrown a short way down the aim from
## where the attacker stands — no further than the first wall — that stops on
## the first enemy it meets (`Headbutt`). The attacker does not move with it.
## HOMING turns it to the nearest enemy first, as far off as a swing looks for
## one; AUTO-AIM has pointed it already (`spawn`). Like a swing, it does not go
## further for being aimed further. It wants a body to throw it: an attacker
## gone by the time a volley's later ones come due punches nothing.
static func _headbutt(p: Payload, aim: Vector2, team: int, atk: Actor, room) -> void:
	if atk == null or not is_instance_valid(atk):
		return
	if room != null and not is_instance_valid(room):
		room = null
	var start: Vector2 = atk.global_position
	if p.homing:
		var t := nearest_target(start, team, 260.0)
		if t != null and t.global_position.distance_to(start) > 0.01:
			aim = (t.global_position - start).normalized()
	var dest := start + aim * HEADBUTT_REACH * p.size
	if room != null and room.has_method("clamp_dash"):
		dest = room.clamp_dash(start, dest)
	var n := Headbutt.new()
	n.setup(p, start, dest, team, atk, room)
	n.aim = aim
	n.thickness = HEADBUTT_WIDTH * p.size
	container().add_child(n)
	Cues.at(&"melee_arc", start, {"payload": p})

## A payload in words: its form, what it carries, and what it does when it
## lands, SHATTER's and MANA DRAIN's numbers included — which are this file's.
## Here rather than on `Payload`, which belongs to the circuit and knows
## nothing of what happens at the moment a hit lands.
static func summary(p: Payload) -> String:
	var parts: Array[String] = []
	var spreads := p.near > 0 and p.spread != null
	# With no form a NEAR is the attack, and is named where the form would be:
	# what lands is what came after it, on everything round where it goes off.
	if p.form == "" and spreads:
		parts.append(_stacked(Components.name_for("NEAR"), p.near))
		parts.append(Loc.t("editor.payload.damage", [p.spread.damage]))
		parts.append_array(_words(p.spread))
		return Loc.t("editor.payload.separator").join(parts)
	parts.append(Components.name_for(p.form) if p.form != "" else Loc.t("editor.payload.no_form"))
	parts.append(Loc.t("editor.payload.damage", [p.damage]))
	if p.size != 1.0:
		parts.append(Loc.t("editor.payload.size", [p.size]))
	if p.duplicates > 1:
		parts.append(Loc.t("editor.payload.duplicates", [p.duplicates]))
	parts.append_array(_words(p))
	# What reaches the enemies round the one struck: the parts after the NEAR.
	if spreads:
		var touched := _words(p.spread)
		if p.spread.damage > 0.0:
			touched.push_front(Loc.t("editor.payload.damage", [p.spread.damage]))
		parts.append(_stacked(Loc.t("editor.payload.near", [Loc.t("editor.payload.separator").join(touched)]), p.near))
	return Loc.t("editor.payload.separator").join(parts)

## How each field of a payload that does something when a hit lands reads in
## the workbench's preview, in the order they are said: the field, and how its
## word is made from its value —
##   count    the word, and "x N" for more than one of the part (`_stacked`)
##   flag     the word alone
##   number   the word with the value in it
##   shatter, mana, health   the word with a number of this file's worked in
## The word is `editor.payload.<field>` in the language being played. A field
## with no row here is said elsewhere or not at all (`WORDLESS`): the form,
## damage, size and count stand at the front of the line (`summary`), NEAR is
## said round what it touches, and the rest is the runner's or a hit's own.
## payload_test holds every field to one list or the other.
const WORDS := [
	[&"pierce", "number"],
	[&"homing", "count"],
	[&"auto_aim", "count"],
	[&"knockback", "count"],
	[&"shatter", "shatter"],
	[&"mana_drain", "mana"],
	[&"health_drain", "health"],
	[&"stun", "number"],
	[&"possess", "number"],
	[&"anti_gravity", "flag"],
	[&"bounce", "number"],
	[&"returns", "flag"],
	[&"chain", "number"],
	[&"summon_pet", "flag"],
	[&"pet_offensive", "count"],
	[&"pet_kamikaze", "count"],
	[&"heal", "number"],
	[&"cleanse", "flag"],
	[&"hook", "count"],
]
const WORDLESS := [&"damage", &"size", &"speed", &"range_px", &"lunge", &"form", &"elements",
	&"near", &"spread", &"touch", &"touch_at", &"duplicates", &"heat", &"branch", &"follow_up",
	&"stacks", &"on_hit", &"on_kill", &"on_parry"]

## What a payload carries and does when it lands, in words, but for its form,
## damage, size and count: a NEAR's touch has none of its own to name. The
## elements first, then every field of `WORDS` that is not nothing.
static func _words(p: Payload) -> Array[String]:
	var parts: Array[String] = []
	for e in p.elements:
		parts.append(Components.name_for(e).to_lower())
	for row: Array in WORDS:
		var field: StringName = row[0]
		var value = p.get(field)
		if not value:
			continue
		var key := "editor.payload.%s" % field
		match String(row[1]):
			"count":
				parts.append(_stacked(Loc.t(key), int(value)))
			"flag":
				parts.append(Loc.t(key))
			"number":
				parts.append(Loc.t(key, [value]))
			"shatter":
				parts.append(Loc.t(key, [shatter_mul(int(value))]))
			"mana":
				parts.append(Loc.t(key, [MANA_PER_HIT * float(value)]))
			"health":
				parts.append(Loc.t(key, [roundi(HEALTH_DRAIN_SHARE * 100.0 * float(value))]))
	return parts

## A behaviour's words in the preview, with how many of its part are stacked
## when that is more than one: what stacking it bought has no number of its own
## to show, the way SHATTER's and MANA DRAIN's do, so the count is the number.
static func _stacked(words: String, count: int) -> String:
	return words if count <= 1 else Loc.t("editor.payload.stacked", [words, count])

## A single connection: damage, feedback, and any trigger flows it unlocks.
##
## `attacker` is deliberately untyped: a projectile or a burst outlives whoever
## fired it, and a monster torn down mid-flight leaves behind a node that still
## passes `is_instance_valid` for a moment with its script already released.
## Declaring the parameter as `Actor` made the engine reject the whole call at
## that moment, so a shot from a dying enemy silently did no damage at all.
## Taking it loose and narrowing here costs the kill credit and any trigger
## flow that needs a live owner, and lands the hit.
static func resolve_hit(p: Payload, target: Actor, pos: Vector2, dir: Vector2, attacker, room, team: int) -> void:
	if target == null or not is_instance_valid(target) or target.dead:
		return
	var h := Hit.new()
	h.p = p
	h.target = target
	h.pos = pos
	h.dir = dir
	# Both halves are needed: a fully deleted node fails `is_instance_valid`,
	# and one still being torn down passes it but no longer answers to `is`.
	h.atk = attacker if is_instance_valid(attacker) and attacker is Actor else null
	h.room = room
	h.team = team
	for step: Array in hit_steps():
		if h.possessed and not bool(step[0]):
			continue
		if not (step[1] as Callable).call(h):
			return

## One connection going through the steps of `resolve_hit`: what came in, and
## what the steps before found out, for the steps after to read.
class Hit extends RefCounted:
	var p: Payload
	var target: Actor
	var pos: Vector2
	var dir: Vector2
	## Whoever struck, or null for nobody left to credit.
	var atk: Actor = null
	var room = null
	var team: int = 0
	## SHATTER on a chilled target, read before the blow lands (`_hit_blow`).
	var breaks := false
	## A NEAR's touch rather than a blow (`Payload.touch`).
	var touched := false
	## What the blow took, and how hard what the hit carries lands: the blow's
	## worth, or on a touch the blow it spreads from.
	var dealt := 0.0
	var strength := 0.0
	## POSSESS took the target: no blow, and only the tail of the steps.
	var possessed := false
	var killed := false

## The steps of a hit, in the order they run, each `[tail, step]`: `step` takes
## the `Hit` and says whether to go on, and `tail` marks the steps every
## connection ends with — the clock stopping, the hit heard, the triggers —
## which a POSSESS, having no blow, skips to. The order is a rule, and some of
## it is load-bearing:
##   - the blow reads the target's chill before it lands and thaws after, so an
##     ICE and SHATTER on one attack take two arrivals to break
##   - the cleanse goes before what this hit brings, so FIRE, FIRE, INVERT
##     turns round the second FIRE alone
##   - PULL stands in for the shove every blow gives, or the blow's would cancel it
##   - the drains, the heal and NEAR read what the blow dealt
##   - whether it killed is read at the end, after every step that could
static var _hit_steps: Array = []

static func hit_steps() -> Array:
	if _hit_steps.is_empty():
		_hit_steps = [
			[false, _hit_possess],
			[false, _hit_blow],
			[false, _hit_reveal],
			[false, _hit_shatter],
			[false, _hit_states],
			[false, _hit_shove],
			[false, _hit_knockback],
			[false, _hit_hook],
			[false, _hit_near],
			[false, _hit_stun],
			[false, _hit_mana_drain],
			[false, _hit_health_drain],
			[false, _hit_heal],
			[true, _hit_hitstop],
			[true, _hit_heard],
			[true, _hit_triggers],
		]
	return _hit_steps

## POSSESS takes the monster it strikes, and does it no harm: the hit is the
## player's hands going in, not a blow — no damage, no shove, nothing it
## carries. Something it cannot take, a boss, is struck as by anything else. A
## hop from one monster to the next is the same hands going in.
static func _hit_possess(h: Hit) -> bool:
	var pilot := _possessor(h.atk)
	if h.p.possess > 0.0 and pilot != null and Player.can_possess(h.target):
		pilot.possess(h.target as Enemy, h.p.possess)
		h.possessed = true
	return true

## The blow lands. SHATTER reads the target's state from before this hit, so
## an attack carrying ICE and SHATTER together does not shatter the chill it is
## in the middle of applying: it takes two arrivals, which is what makes it a
## combination rather than a flat damage part. A hit that cleanses lands bare,
## and what it carries goes on once the cleanse has been through (`_hit_states`).
## A NEAR's touch is no blow (`Payload.touch`): it lands what damage the parts
## after the NEAR gave it, if any, and does the rest whether or not that hurt —
## what it carries landing as hard as the blow it spreads from. A blow that
## lands nothing ends here.
static func _hit_blow(h: Hit) -> bool:
	h.breaks = h.p.shatter > 0 and h.target.chill_time > 0.0
	var damage := h.p.damage * shatter_mul(h.p.shatter) if h.breaks else h.p.damage
	h.touched = h.p.touch >= 0.0
	h.dealt = h.target.apply_damage(damage, [] if h.p.cleanse or h.touched else h.p.elements, h.atk)
	if h.dealt <= 0.0 and not h.touched:
		return false
	h.strength = maxf(h.dealt, h.p.touch) if h.touched else h.dealt
	return true

## A monster the player is in passes for one of them until it hurts one of
## them, and then it is found out (`Enemy.revealed`). Attacking alone gives
## nothing away — a swing at the air, a throw that misses — and a POSSESS hurts
## nobody, so a hop from one body to the next is never one of them hurt.
static func _hit_reveal(h: Hit) -> bool:
	if h.dealt > 0.0 and h.atk is Enemy and (h.atk as Enemy).piloted() and h.target.team != h.atk.team:
		(h.atk as Enemy).revealed = true
	return true

## The frost is what broke: the enemy thaws, and that takes the chill this same
## hit may have brought with it, so the next break needs a fresh one. Frozen
## solid, it is the ice that breaks, and it stands free again.
static func _hit_shatter(h: Hit) -> bool:
	if h.breaks:
		h.target.thaw()
		Cues.at(&"shatter", h.pos, {"payload": h.p, "damage": h.dealt})
	return true

## A cleanse — what an INVERT makes of FIRE, ICE or STUN — ends what the enemy
## struck was carrying when the hit reached it: every burn, chill and stun.
## What this hit brings is some other part's doing and not the cleanse's to
## end, so it goes on after, the stun further down included: FIRE, FIRE,
## INVERT turns round the second FIRE alone, and still burns from the first.
## A touch's states land here too, as hard as the blow it spreads from.
static func _hit_states(h: Hit) -> bool:
	if h.target.dead:
		return true
	if h.p.cleanse:
		if h.target.cleanse():
			Cues.at(&"cleanse", h.target.global_position, {"target_team": h.target.team})
		h.target.afflict(h.strength, h.p.elements)
	elif h.touched:
		h.target.afflict(h.strength, h.p.elements)
	return true

## Every hit gives the enemy it strikes a shove along the attack: no touch does,
## which is no blow, nor a PULL, which drags it the other way.
static func _hit_shove(h: Hit) -> bool:
	if not h.p.hook and not h.touched:
		h.target.knockback(h.dir, hit_shove(h.p))
	return true

## KNOCKBACK throws the struck enemy on the way the attack was going, which is
## the `dir` every form hands in: along a bolt's flight, out from a swing or a
## NEAR's middle, down the line of a lunge. It adds to whatever the hit did
## above. Thrown so, it can be slammed into a wall (`Actor.SLAM_SPEED`), and
## the slam is the thrower's side's.
static func _hit_knockback(h: Hit) -> bool:
	if h.p.knockback:
		h.target.knockback(h.dir, KNOCKBACK_FORCE * float(h.p.knockback), h.team)
	return true

## PULL, and what an INVERT made of KNOCKBACK: the struck enemy is dragged
## toward whoever struck it, as hard as KNOCKBACK throws it on but never past
## them (`hook_force`) — in place of the shove every hit gives, or a heavy
## blow's would cancel the pull. One a NEAR touched is dragged in to the NEAR's
## middle instead — the enemy struck, or where it went off — so a NEAR and a
## PULL gather the enemies round the one struck onto it. With nobody to drag it
## to, it is hauled back the way the attack came.
static func _hit_hook(h: Hit) -> bool:
	if not h.p.hook:
		return true
	var to := -h.dir
	var far := INF
	var toward := Vector2.INF
	if h.touched:
		toward = h.p.touch_at
	elif h.atk != null:
		toward = h.atk.global_position
	if toward != Vector2.INF:
		var gap := toward - h.target.global_position
		if gap.length() > 0.01:
			to = gap.normalized()
		far = gap.length() - HOOK_SHORT
	h.target.knockback(to, hook_force(h.p, far))
	return true

## NEAR: what the parts after it did reaches everything round the enemy it
## struck.
static func _hit_near(h: Hit) -> bool:
	if h.p.near > 0 and h.p.spread != null:
		_near(h.p, h.target, h.pos, h.dealt, h.atk, h.room, h.team)
	return true

static func _hit_stun(h: Hit) -> bool:
	if h.p.stun > 0.0 and h.target.stun(h.p.stun):
		Cues.at(&"stun", h.target.global_position, {"seconds": h.p.stun, "target_team": h.target.team})
	return true

static func _hit_mana_drain(h: Hit) -> bool:
	if h.p.mana_drain and h.atk != null and h.atk.has_method("gain_mana"):
		var drained := MANA_PER_HIT * float(h.p.mana_drain)
		h.atk.gain_mana(drained)
		Cues.at(&"mana_drain", h.pos, {"amount": drained})
	return true

static func _hit_health_drain(h: Hit) -> bool:
	if h.p.health_drain and h.atk != null:
		var back := h.atk.heal(h.dealt * HEALTH_DRAIN_SHARE * float(h.p.health_drain))
		if back > 0.0:
			Cues.at(&"heal", h.atk.global_position, {"amount": back, "target_team": h.atk.team})
	return true

## HEAL, and what an INVERT made of DAMAGE: health given back to the enemy
## struck, after the harm and only while it still stands, so a blow that kills
## stays a kill.
static func _hit_heal(h: Hit) -> bool:
	if h.p.heal > 0.0 and not h.target.dead:
		var healed := h.target.heal(h.p.heal)
		if healed > 0.0:
			Cues.at(&"heal", h.target.global_position, {"amount": healed, "target_team": h.target.team})
	return true

## A connection stops the clock for a frame. That is a rule — everything in the
## fight feels it — so it is applied here and not left to the screen. A chain's
## link stops it more lightly than a blow of its own.
static func _hit_hitstop(h: Hit) -> bool:
	TimeCtl.hitstop(CHAIN_HITSTOP if h.p.follow_up else HITSTOP)
	return true

## The hit is heard, and a kill counted — the player's, unless it was the player
## brought down by their own NEAR or their own thrown stone, or a thing on the
## crates' side broken: a crate, a generator.
static func _hit_heard(h: Hit) -> bool:
	h.killed = h.target.dead
	if h.killed and h.atk != null and h.atk.team == 0 and h.target.team != 0 and h.target.team != Crate.TEAM:
		GameState.register_kill()
	Cues.at(&"hit", h.pos, {"payload": h.p, "killed": h.killed, "target_team": h.target.team})
	return true

## The triggers the hit sets off: ON HIT on every connection, ON KILL on one
## that killed.
static func _hit_triggers(h: Hit) -> bool:
	var ctx := {
		"attacker": h.atk, "room": h.room, "team": h.team,
		"aim": h.dir, "origin": h.pos, "lobbed": false,
	}
	if h.p.on_hit != null:
		_schedule_spawn(TRIGGER_DELAY, _follow(h.p.on_hit), ctx)
	if h.killed and h.p.on_kill != null:
		_schedule_spawn(TRIGGER_DELAY, _follow(h.p.on_kill), ctx)
	return true

## The player whose hit this is — struck from their own body, or from a monster
## they are in — or null for anyone else's.
static func _possessor(atk: Actor) -> Player:
	if atk is Player:
		return atk as Player
	if atk is Enemy and (atk as Enemy).piloted():
		return (atk as Enemy).pilot
	return null

## A link of a chain, marked as belonging to the blow that caused it rather than
## being one of its own. A parry's riposte is deliberately not marked: that is a
## separate answer to a separate event, and it should land like one.
static func _follow(p: Payload) -> Payload:
	var f: Payload = (p as Payload).clone()
	f.follow_up = true
	return f
