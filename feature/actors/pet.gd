class_name Pet
extends Node2D

## A pet summoned by SUMMON PET (`Attacks._summon_pet`). On its own it does
## nothing but keep its summoner company: it hovers behind their shoulder and
## follows them wherever they go, easing after them rather than stuck to them.
## One to a summoner. It is nobody's to hit, and goes when its summoner does —
## dead, or gone with the screen. Nothing here draws (`PetView`).
##
## It is on the floor seen from above like everything else: its position is a
## point on the floor behind its summoner, and it hovers `ABOVE` off it, which
## only the picture cares about.
##
## What else it does is what the flow that summoned it carried (`take`), and a
## later cast tells it again. OFFENSIVE: it darts at the nearest enemy within
## SIGHT of its summoner and strikes it with that flow, as often as
## STRIKE_EVERY lets it — more often for each one stacked — and comes back
## between strikes. KAMIKAZE: it darts at that enemy as soon as there is one,
## and blows itself up against it, the flow going off round it as a burst
## (`Attacks.kamikaze`); then it is gone, and the next cast with a SUMMON PET
## calls another.

## Where it hovers: behind its summoner on the floor, the way they are not
## facing, and up off the floor by their shoulder.
const BEHIND := 30.0
const ABOVE := 38.0
## How quickly it catches up, per second: higher is tighter.
const FOLLOW := 5.0
## How far it bobs up and down as it hovers, and how fast.
const BOB := 3.0
const BOB_SPEED := 3.2

## OFFENSIVE. How far from its summoner it looks for an enemy; how near it has
## to be to strike one; how long between strikes with one OFFENSIVE — each one
## more divides it; and how quickly it darts at one, against FOLLOW.
const SIGHT := 220.0
const REACH := 14.0
const STRIKE_EVERY := 1.2
const DART := 14.0

var summoner: Node2D = null
## Which side it faces: the way its summoner does, or the one it goes for.
var facing := 1
## How far up off the floor it hovers this frame.
var height := ABOVE
## What it strikes with: the flow that summoned it, its summons taken off it.
var payload: Payload = null
## How many OFFENSIVEs that flow carried: 0, and it never strikes.
var offensive := 0
## How many KAMIKAZEs it carried: 0, and it never blows itself up.
var kamikaze := 0
## The enemy it is going for, or null.
var target: Actor = null
var _cool := 0.0
var _t := 0.0

func _ready() -> void:
	add_to_group("pets")

## The way its summoner faces on the floor, as far as it says.
func _summoner_facing() -> Vector2:
	var way = summoner.get("facing")
	if way is Vector2 and (way as Vector2).length() > 0.01:
		return (way as Vector2).normalized()
	return Vector2.RIGHT

## Which side its summoner is turned to, as far as it says.
func _summoner_side() -> int:
	if summoner.has_method("side"):
		return int(summoner.call("side"))
	return 1 if _summoner_facing().x >= 0.0 else -1

## Where it wants to be on the floor: behind its summoner.
func home() -> Vector2:
	return summoner.global_position - _summoner_facing() * BEHIND

## Told what it does: by the flow that summoned it, and again by every cast that
## would have summoned it while it is there.
func take(p: Payload) -> void:
	payload = p
	offensive = p.pet_offensive if p != null else 0
	kamikaze = p.pet_kamikaze if p != null else 0

func _process(delta: float) -> void:
	if summoner == null or not is_instance_valid(summoner) or bool(summoner.get("dead")):
		queue_free()
		return
	_t += delta
	_cool = maxf(0.0, _cool - delta)
	height = ABOVE + sin(_t * BOB_SPEED) * BOB
	var want := home()
	var rate := FOLLOW
	target = _pick() if (offensive > 0 or kamikaze > 0) and payload != null else null
	# A kamikaze one waits for nothing: it has only the one blow.
	var going := target != null and (kamikaze > 0 or _cool <= 0.0)
	if going:
		want = target.global_position
		rate = DART
	global_position = global_position.lerp(want, 1.0 - exp(-rate * delta))
	if going and global_position.distance_to(target.global_position) <= REACH + target.hurt_radius:
		if kamikaze > 0:
			_blow_up()
			return
		_strike(target)
	if target != null:
		facing = 1 if target.global_position.x >= global_position.x else -1
	else:
		facing = _summoner_side()

## The nearest enemy of its summoner's within SIGHT of them, or null.
func _pick() -> Actor:
	var best: Actor = null
	var best_d := SIGHT
	var from := summoner.global_position
	for a in Attacks.quarries(int(summoner.get("team")) if summoner.get("team") != null else 0):
		if not is_instance_valid(a) or a.dead:
			continue
		var d := from.distance_to(a.global_position)
		if d <= best_d:
			best = a
			best_d = d
	return best

## Strikes `a` with the flow it was summoned with, as its summoner's blow, and
## waits before the next.
func _strike(a: Actor) -> void:
	var dir := (a.global_position - global_position).normalized()
	var atk: Actor = summoner as Actor
	Attacks.resolve_hit(payload.clone(), a, global_position, dir, atk, summoner.get("room"),
		int(summoner.get("team")) if summoner.get("team") != null else 0)
	_cool = STRIKE_EVERY / float(maxi(offensive, 1))

## KAMIKAZE: it goes off where it is — the flow it was summoned with bursting
## on everything round it, as its summoner's blow — and is gone.
func _blow_up() -> void:
	Attacks.kamikaze(payload.clone(), global_position,
		int(summoner.get("team")) if summoner.get("team") != null else 0, summoner as Actor, summoner.get("room"))
	queue_free()

## The pet `summoner` has, or null.
static func of(summoner: Node, tree: SceneTree) -> Pet:
	if tree == null:
		return null
	for p in tree.get_nodes_in_group("pets"):
		if is_instance_valid(p) and not p.is_queued_for_deletion() and (p as Pet).summoner == summoner:
			return p
	return null
