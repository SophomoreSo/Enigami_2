class_name Enemy
extends Actor

## One monster. Movement comes from its AI kind and its attacks come from a
## SkillBoard run through the same SkillRunner the player uses. What it looks
## like is `graphics/views/enemy_view.gd`, which reads the state below.
##
## It stands on a floor seen from above, as the player does: it walks any way
## on it, faces the way it goes or the way it looks, and a wall is a thing it
## slides along. A flyer is the one kind off the floor, by a `height` the
## picture lifts it by; everything it does is still measured at its feet.
##
## A monster can be possessed (`Player.possess`): while it is, its `pilot` is
## the player, it is on their side, and it does what their input line says
## rather than what its own mind would — walks at its own pace, and attacks
## with its own attack when they press. The rest of the monsters take it for
## one of them until it has hurt one of them (`revealed`), and hunt it after.

## How much longer a monster waits between attacks than its board alone would.
##
## Monster boards are short by design — a Crawler is a SLASH and nothing else —
## and a short board comes round again almost immediately, so every monster in
## the game was attacking twelve to thirty times a second: a Sentry held down a
## wall of bolts, and walking into a Crawler was a death with no blow in it to
## read. The player's own casts are paced the same way, by
## `Player.CAST_COOLDOWN_MUL`.
##
## It is one number for every monster on purpose. What separates a Crawler's
## slash from an Arbiter's volley is already in their boards — length and heat —
## so scaling the whole cadence keeps those differences and only sets the pace
## they play out at.
const ATTACK_COOLDOWN_MUL := 20.0

## A monster only notices what is in front of it. Something standing this close
## behind its back is noticed anyway: that is not being crept up on, that is
## being stood on.
const BLIND_MARGIN := 10.0
## A monster standing idle looks over its shoulder now and then, somewhere
## between these many seconds apart, so one that happened to stop facing a wall
## is not blind for the rest of the raid — and so the moment its back is turned
## is something to wait for.
const GLANCE_MIN := 2.0
const GLANCE_MAX := 4.0
## How long a monster that has just noticed somebody waits before it attacks:
## the moment it notices them has to read before the first blow does.
const ALERT_TIME := 0.3
## How long one that has lost sight of what it was hunting goes on to where it
## last saw them before it gives up: long enough to follow them through a
## doorway and round the corner beyond it.
const PURSUE_TIME := 6.0
## How high a flyer hovers over the floor, and how far it bobs.
const FLY_HEIGHT := 40.0
const FLY_BOB := 6.0
## A jumper's lunge: how long it waits between lunges, how long a lunge
## carries it, how much faster than its walk, and the wind-up before each.
const LUNGE_EVERY := 1.3
const LUNGE_TIME := 0.35
const LUNGE_PACE := 1.6
const LUNGE_WIND := 0.2

## Its attack went off, cast off `skill`'s board — by it, or by a player whose
## hands are in it. A raid hears it, for the monster dictionary.
signal attacked(skill: String)

var kind: String = "CRAWLER"
var def: Dictionary = {}
var board: SkillBoard
var runner: SkillRunner
var room = null
var target: Actor = null
var modifier: String = ""
## Something loud it has been called to (`lure_to`): where, and for how much
## longer it keeps coming. One that goes anywhere goes to it as it would to
## what it hunts, until it notices somebody — hunting comes first — or the
## call stops; and stands over it when it gets there.
var lure := Vector2.INF
var lure_for := 0.0
## Whether the call it is going to is its own: where it last saw what it was
## hunting (`_acquire`), rather than something it heard.
var _pursuing := false
## How near the call it stands over it rather than walking on through.
const LURE_STOP := 24.0

## Half the silhouette: the hurt radius, and what the collider is built from.
var size: float = 14.0
## Whether the monster has seen its target. A view marks it; the AI acts on it.
## Seeing takes the target in front of it (see `_in_front`); once it has, it
## turns to keep them there, so it stays seen until range or a wall breaks it.
var aggro: bool = false
## Counts down from ALERT_TIME from the moment it notices somebody it had not
## — `aggro` coming on, and not kept on — and it does not attack until it is
## out. A view shows it, over its head.
var alert: float = 0.0
## Counts down through the wind-up before a lunge, so the lunge can be read
## before it lands.
var telegraph: float = 0.0
## 1 until a boss changes form, then 2.
var phase: int = 1
## The board it is casting now, as the key it is under in its kind's DEFS:
## `board`, or the Arbiter's second form's. What the monster dictionary calls
## its skill (`Monsters.skills_of`).
var skill: String:
	get:
		return "board_phase2" if phase == 2 and def.has("board_phase2") else "board"

## The way a walker patrols, on the floor.
var _patrol_dir: Vector2 = Vector2.RIGHT
var _glance: float = 0.0
## A jumper's lunge: the wait to the next, how long the one under way has
## left, and the way it goes.
var _lunge_cd: float = 0.0
var _lunge: float = 0.0
var _lunge_dir: Vector2 = Vector2.RIGHT
var _bob: float = 0.0
var _lobbed_shots: bool = false
var _danger: int = 1

## A possessed monster, under the player's keys. The least pace it walks at,
## so a monster that never walks of its own accord — a Sentry — still can.
const PILOTED_PACE := 110.0
## A monster after one thing turns on another it can see in front of it only
## when that one is this much nearer: nearer by a little is not worth a turn,
## and two things the same distance off would have it swinging between them.
const SWITCH_NEARER := 0.6

## The player whose hands are in this monster, or null while it runs its own
## mind — see `Player.possess`.
var pilot: Player = null
## Whether a possessed monster has shown itself: until a hit of its hurts one of
## them it passes for one of them, and none of them hunts it. Attacking is not
## enough — a swing at nothing, a throw that misses — and a hit that puts the
## player's hands into the next one lets go of this one as it lands
## (`Attacks.resolve_hit`).
var revealed: bool = false
## Whether its pilot is attacking with its own attack, this frame. The pilot
## says so (`Player._attack_as_monster`).
var attacking: bool = false

## Rolled onto a monster to make it more than its kind. The effects are applied
## below; what each one looks like is the graphics module's business.
const MODIFIERS := ["swift", "armored", "volatile", "glacial"]

func setup(id: String, danger: int = 1, mod_id: String = "") -> void:
	kind = id
	def = Monsters.get_def(id)
	modifier = mod_id
	size = float(def["size"])
	_lobbed_shots = bool(def.get("lobbed", false))
	_danger = danger
	var scale_hp := 1.0 + 0.16 * float(max(danger - 1, 0))
	max_health = float(def["hp"]) * scale_hp
	hurt_radius = size
	if modifier == "armored":
		max_health *= 1.6
	if modifier == "swift":
		max_health *= 0.8
	health = max_health

func _ready() -> void:
	team = 1
	super._ready()
	add_to_group("enemies")
	_make_body(size * 1.5, size * 1.9)
	board = Monsters.build_board(kind)
	_make_runner()
	# Found facing any of the four ways, not always to the right.
	_patrol_dir = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN][randi() % 4]
	face(_patrol_dir)
	_glance = randf_range(GLANCE_MIN, GLANCE_MAX)
	if ai() == "flyer":
		height = FLY_HEIGHT

func _make_runner() -> void:
	runner = SkillRunner.new(board)
	runner.cooldown_mul = ATTACK_COOLDOWN_MUL
	runner.forms_only = not Magic.on
	var dmg_scale := 1.0 + 0.14 * float(max(_danger - 1, 0))
	if modifier == "armored":
		dmg_scale *= 1.15
	# A quarter past the furthest it will ever shoot from, so a bolt loosed at
	# the edge of its range still lands on someone backing away — and never less
	# than an ordinary bolt carries, so the ones that fight up close are not
	# firing shorter shots than anybody else.
	var reach := maxf(float(def.get("attack_range", 0.0)) * 1.25, Payload.BASE_RANGE)
	# What one shot is worth and how fast it flies are the same for every
	# monster, unless its kind says otherwise: the Gunman's say so.
	var hit := float(def.get("damage", 7.0)) * dmg_scale
	var pace := float(def.get("shot_speed", 0.85))
	runner.base_payload_provider = func() -> Payload:
		var p := Payload.new()
		p.damage = hit
		p.speed = pace
		p.size = 1.0
		p.range_px = reach
		return p
	runner.fired.connect(_on_fired)

func _on_fired(p: Payload) -> void:
	if dead:
		return
	var aim: Vector2
	var at := Vector2.INF
	if piloted():
		# Where the pilot is pointing. Going off gives nothing away; hurting one
		# of them does (`Attacks.resolve_hit`).
		aim = pilot.aim
		at = pilot.aim_point
	else:
		if target == null or not is_instance_valid(target):
			return
		aim = (target.global_position - global_position).normalized()
		at = target.global_position
	if modifier == "glacial" and not p.elements.has("ICE"):
		p.elements.append("ICE")
	Attacks.spawn(p, {
		"attacker": self, "room": room, "team": team,
		"aim": aim, "origin": global_position, "lobbed": _lobbed_shots, "aim_point": at,
	})
	attacked.emit(skill)
	if bool(def.get("spent_by_attack", false)):
		_go_up(p)

## Spent by its attack, as the Bomber is (`spent_by_attack`): the blow is the
## last thing it does. What it carried goes up where it stands — wherever the
## blow left it — as the same flow with no form under it, which a NEAR on it
## makes a touch on everything round it (`Attacks.spawn`), with a bang, and it
## dies in it, whether the blow found anybody or not. A player whose hands are
## in it is put back in their own body, as from any monster that dies.
func _go_up(p: Payload) -> void:
	var blast := p.clone()
	blast.form = ""
	Cues.at(&"area_blast", global_position, {"payload": blast})
	Attacks.spawn(blast, {"attacker": null, "room": room, "team": team, "aim": Vector2.RIGHT,
		"origin": global_position})
	_kill()

func _process(delta: float) -> void:
	_process_status(delta)
	# Its board follows magic as the player's does: cast whole, or as its forms
	# alone. Asked every frame rather than heard, since a monster comes and goes
	# and the runner says nothing when it is told what it already is.
	runner.forms_only = not Magic.on
	_bob += delta
	if telegraph > 0.0:
		telegraph -= delta
	if piloted():
		# The pilot's hands, not its own mind: it attacks when they say, with
		# its own attack, and a stun holds it as it holds any monster.
		runner.set_active(attacking and not stunned())
		if not stunned():
			runner.update(delta)
		return
	alert = maxf(alert - delta, 0.0)
	lure_for = maxf(lure_for - delta, 0.0)
	_acquire()
	var want_attack := aggro and target != null and _in_range()
	if def.get("boss", false):
		_boss_logic(delta)
		want_attack = aggro and target != null
	runner.set_active(want_attack and alert <= 0.0 and not stunned())
	# A stunned monster's board waits with it: a cast already on its way would
	# otherwise land while it stands there, and that is an attack.
	if not stunned():
		runner.update(delta)
	_update_facing(delta)

## Monsters look at what they are hunting, and at where they are going
## otherwise — a patrolling Lobber should not moonwalk. One with nothing to
## hunt and nowhere to go looks another way every few seconds.
func _update_facing(delta: float) -> void:
	if aggro and target != null and is_instance_valid(target):
		_face_target()
	elif lured():
		face(lure - global_position)
	elif velocity.length() > 4.0:
		face(velocity)
	elif not stunned():
		_glance -= delta
		if _glance <= 0.0:
			_glance = randf_range(GLANCE_MIN, GLANCE_MAX)
			face(facing.rotated(PI * 0.5 * (1.0 if randf() < 0.5 else -1.0)))

func _face_target() -> void:
	face(target.global_position - global_position)

## Something loud at `at` — somebody digging (`DigSpot`). One with nothing to
## hunt, that is not the player's, turns to look that way and keeps looking for
## a while rather than glancing straight back. Whether it then sees anybody is
## noticing's business (`_acquire`), so a wall between still hides them.
func hear(at: Vector2) -> void:
	if dead or piloted() or aggro or stunned():
		return
	face(at - global_position)
	_glance = GLANCE_MAX

## Called to `at` — a phone ringing (`Phone.call_monsters`) — for `seconds`:
## it goes there, if it is one that goes anywhere, and stands over it when it
## gets there. Hunting comes first: one that has noticed somebody keeps after
## them, and one that notices somebody on the way goes after them instead.
func lure_to(at: Vector2, seconds: float) -> void:
	if dead or piloted() or stunned() or not moves():
		return
	lure = at
	lure_for = maxf(lure_for, seconds)
	_pursuing = false
	if not aggro:
		face(at - global_position)
		_glance = GLANCE_MAX

## Whether it is after somebody: has them, or is going to where it last saw
## them. What the raid asks before it lets a monster's room go, to carry the
## hunt on without it (`Raid`).
func hunting() -> bool:
	return (aggro and target != null) or (lured() and _pursuing)

## Set after `a` from somewhere else — a hunter come in from another room,
## where it was after them (`Raid`): it has them, and it knows where they
## were, so losing sight of them again sends it there.
func hunt(a: Actor) -> void:
	if dead or a == null or not is_instance_valid(a):
		return
	target = a
	aggro = true
	alert = ALERT_TIME
	lure = a.global_position
	lure_for = PURSUE_TIME
	_pursuing = true

## Whether it is on its way to a call, with nothing to hunt.
func lured() -> bool:
	return lure_for > 0.0 and not (aggro and target != null)

## Whether its kind goes anywhere of its own accord: a turret holds its ground
## and a walker its beat, whatever they hear.
func moves() -> bool:
	return String(def.get("ai", "")) in ["runner", "jumper", "flyer", "boss"]

## Whether it is going somewhere — after what it hunts, or to a call — and
## where that is.
func _driven() -> bool:
	return (aggro and target != null) or lured()

func _goal() -> Vector2:
	if aggro and target != null:
		return target.global_position
	return lure

## Whether it has got to the call it is going to, and stands over it.
func _at_goal() -> bool:
	return lured() and lure.distance_to(global_position) <= LURE_STOP

## Whether the target is on the side this monster is looking at. A boss is
## never crept up on: its room is its own, and it knows who is in it.
func _in_front() -> bool:
	return _faces(target.global_position)

## Whether `at` is on the side this monster is looking at — or right on its
## back, which is being stood on rather than crept up on.
func _faces(at: Vector2) -> bool:
	if def.get("boss", false):
		return true
	return (at - global_position).dot(facing) >= -BLIND_MARGIN

## Which movement script this monster runs. A view reads it to decide what a
## hover should look like.
func ai() -> String:
	return String(def["ai"])

## --- possessed -------------------------------------------------------------

## Whether the player's hands are in this monster.
func piloted() -> bool:
	return pilot != null and is_instance_valid(pilot)

## The player's hands go in: it is on their side, sees nobody and hunts nobody,
## and a stun it was standing in is over, so it answers them at once.
func take_pilot(p: Player) -> void:
	pilot = p
	team = 0
	Arena.sides_changed()
	revealed = false
	attacking = false
	aggro = false
	alert = 0.0
	target = null
	telegraph = 0.0
	runner.ttl_bonus = 0
	runner.set_active(false)
	if stunned():
		stun_time = 0.0

## The player's hands come out: it is one of them again, and stands stunned for
## `stun_for` — however recently it came round from the last stun.
func release_pilot(stun_for: float) -> void:
	pilot = null
	team = 1
	Arena.sides_changed()
	revealed = false
	attacking = false
	aggro = false
	alert = 0.0
	target = null
	runner.set_active(false)
	velocity = Vector2.ZERO
	stun_guard = 0.0
	stun(stun_for)

## Mana a MANA DRAIN hit gives back: a possessed monster's goes to its pilot.
func gain_mana(amount: float) -> void:
	if piloted():
		pilot.gain_mana(amount)

## Walks as the pilot's line says, at its own pace, any way on the floor; a
## flyer hovers as it goes.
func _ai_piloted(delta: float, spd: float) -> void:
	var s := pilot.input.state()
	var pace := maxf(spd, PILOTED_PACE * speed_scale())
	if s.sprint:
		pace *= Player.SPRINT_SPEED / Player.RUN_SPEED
	face(s.move)
	face(s.turn)
	var accel := 1400.0 if ai() == "flyer" else 1800.0
	velocity = velocity.move_toward(s.move * pace, accel * delta)
	if ai() == "flyer":
		_hover()

## --- hunting ----------------------------------------------------------------

## Whether `a` is something a monster hunts: whatever stands for the player —
## their own body — or a monster the player is in that has shown itself.
func _hunts(a) -> bool:
	if a == null or not is_instance_valid(a) or a == self or (a as Actor).dead:
		return false
	if (a as Node).is_in_group("player"):
		return true
	return a is Enemy and (a as Enemy).piloted() and (a as Enemy).revealed

## The nearest thing there is to hunt, or null. With `noticed`, only what it
## would notice where it stands: in reach, in sight, and in front of it.
func _nearest_quarry(noticed: bool = false) -> Actor:
	var best: Actor = null
	var best_d := INF
	# Off the Arena's list rather than a walk of two groups, which every monster
	# did up to twice a frame.
	for a in Arena.actors():
		if not _hunts(a):
			continue
		var at := (a as Actor).global_position
		var d := global_position.distance_to(at)
		if d >= best_d:
			continue
		if noticed and (d > float(def["aggro"]) or not _sees(at) or not _faces(at)):
			continue
		best_d = d
		best = a
	return best

## What it is after. Having noticed something it keeps after it — unless
## something else it can see in front of it is much nearer, a monster the player
## is in giving itself away beside it, say. Until then it looks for the nearest
## thing to hunt: the player's body, or a monster the player is in that has
## given itself away. Noticing somebody it had not starts its ALERT_TIME.
func _acquire() -> void:
	var was := aggro
	if aggro and _hunts(target):
		var other := _nearest_quarry(true)
		if other != null and other != target and global_position.distance_to(other.global_position) \
				< global_position.distance_to(target.global_position) * SWITCH_NEARER:
			target = other
	else:
		target = _nearest_quarry()
	if target == null:
		aggro = false
		alert = 0.0
		return
	var d := global_position.distance_to(target.global_position)
	# Noticing takes the target in front; having noticed, it only has to keep
	# them in reach and in sight, since it turns to follow them.
	aggro = d <= float(def["aggro"]) and _sees(target.global_position) and (aggro or _in_front())
	if aggro and not was:
		alert = ALERT_TIME
		_pursuing = false
	elif not aggro:
		alert = 0.0
		# Lost sight of them, or lost them out of reach: it goes on to where
		# they were when it did, for a while, rather than standing there — out
		# through the doorway after them, if that is where they went.
		if was and moves():
			lure = target.global_position
			lure_for = maxf(lure_for, PURSUE_TIME)
			_pursuing = true

## Whether nothing solid stands between it and `at`.
func _sees(at: Vector2) -> bool:
	if room != null and room.has_method("has_line_of_sight"):
		return room.has_line_of_sight(global_position, at)
	return true

func _in_range() -> bool:
	return global_position.distance_to(target.global_position) <= float(def["attack_range"])

func _physics_process(delta: float) -> void:
	if dead:
		return
	var spd := float(def["speed"]) * speed_scale()
	if modifier == "swift":
		spd *= 1.5
	if stunned():
		_stand_stunned()
	elif piloted():
		_ai_piloted(delta, spd)
	else:
		match String(def["ai"]):
			"runner": _ai_runner(delta, spd)
			"walker": _ai_walker(delta, spd)
			"jumper": _ai_jumper(delta, spd)
			"turret": _ai_turret()
			"flyer": _ai_flyer(delta, spd)
			"boss": _ai_boss(delta, spd)
	move_and_slide()
	# The AI above has just written `velocity` outright, so anything the world
	# is pushing this monster with is carried separately and applied here.
	apply_shove(delta)
	# Standing stunned is doing nothing, and that includes hurting by touch; so
	# is being somebody else's hands.
	if not stunned() and not piloted():
		_contact_damage(delta)

## A stunned monster does nothing of its own: it stops where it is, mid-stride,
## hanging where it was if it flies. A shove still carries it, since that is
## the world's and not its own.
func _stand_stunned() -> void:
	velocity = Vector2.ZERO

## The way from here to where it is going, on the floor.
func _way() -> Vector2:
	var to := _goal() - global_position
	return to.normalized() if to.length() > 0.01 else Vector2.ZERO

func _ai_runner(delta: float, spd: float) -> void:
	if _driven() and not _at_goal():
		velocity = velocity.move_toward(_way() * spd, 1400.0 * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)

## A walker keeps its beat: along its way until it meets a wall, then back.
func _ai_walker(_delta: float, spd: float) -> void:
	if is_on_wall():
		_patrol_dir = -_patrol_dir
	velocity = _patrol_dir * spd

## A jumper lunges along the floor at what it is after, a wind-up before each
## and a wait between, and stands still otherwise.
func _ai_jumper(delta: float, spd: float) -> void:
	_lunge_cd -= delta
	if _lunge > 0.0:
		_lunge -= delta
		velocity = _lunge_dir * spd * LUNGE_PACE
		return
	velocity = velocity.move_toward(Vector2.ZERO, 1600.0 * delta)
	if _driven() and not _at_goal() and _lunge_cd <= 0.0:
		_lunge_cd = LUNGE_EVERY
		_lunge = LUNGE_TIME
		_lunge_dir = _way()
		telegraph = LUNGE_WIND

## A turret holds its ground.
func _ai_turret() -> void:
	velocity = Vector2.ZERO

## A flyer hovers over the floor and drifts after what it is after, bobbing as
## it goes; with nothing to go after it hangs where it is, bobbing.
func _ai_flyer(delta: float, spd: float) -> void:
	_hover()
	if _driven():
		velocity = velocity.lerp(_way() * spd, clampf(2.0 * delta, 0.0, 1.0))
	else:
		velocity = velocity.lerp(Vector2.ZERO, clampf(2.0 * delta, 0.0, 1.0))

## Where a flyer is off the floor this frame.
func _hover() -> void:
	height = FLY_HEIGHT + sin(_bob * 3.0) * FLY_BOB

func _ai_boss(delta: float, spd: float) -> void:
	if not _driven() or _at_goal():
		velocity = velocity.move_toward(Vector2.ZERO, 800.0 * delta)
		return
	var way := _way()
	var dist := _goal().distance_to(global_position)
	# Phase one keeps its distance; phase two closes and pressures. A call it
	# is going to it just goes to.
	var want := Vector2.ZERO
	if lured():
		want = way * spd * 0.7
	elif phase == 1:
		want = way * spd * (-0.6 if dist < 200.0 else 0.7)
	else:
		want = way * spd * 1.25
	velocity = velocity.move_toward(want, 1200.0 * delta)

func _boss_logic(_delta: float) -> void:
	if phase == 1 and health_ratio() < 0.5:
		phase = 2
		board = Monsters.build_board(kind, "board_phase2")
		_make_runner()
		# The monster and the phase it has entered, not a line about them: the
		# picture spells that, in the language being played.
		Cues.at(&"boss_phase", global_position, {"kind": kind, "phase": phase})

func _contact_damage(delta: float) -> void:
	var dmg := float(def["contact"])
	if dmg <= 0.0 or target == null or not is_instance_valid(target):
		return
	if global_position.distance_to(target.global_position) <= hurt_radius + target.hurt_radius:
		target.apply_damage(dmg * delta * 4.0, [], self)

func _kill() -> void:
	if dead:
		return
	if modifier == "volatile":
		var p := Payload.new()
		p.size = 1.3
		# No form, so the NEAR is the attack: everything round where it died is
		# hurt and burnt, and it goes up with a bang.
		p.near = 1
		p.spread = Payload.new()
		p.spread.damage = 18.0
		p.spread.elements = ["FIRE"] as Array[String]
		Cues.at(&"area_blast", global_position, {"payload": p})
		Attacks.spawn(p, {"attacker": null, "room": room, "team": team, "aim": Vector2.RIGHT, "origin": global_position})
	if room != null and room.has_method("on_enemy_died"):
		room.on_enemy_died(self)
	super._kill()

func apply_damage(amount: float, elements: Array = [], source: Node = null, is_hit: bool = true) -> float:
	if modifier == "armored":
		amount *= 0.7
	# A blow in the back is the end of not having noticed: it turns round to
	# whoever it is hunting, and sees them if they are near enough to be seen.
	if is_hit and not aggro and target != null and is_instance_valid(target):
		_face_target()
	return super.apply_damage(amount, elements, source, is_hit)
