class_name AimAssist
extends InputMiddleware

## Aim assist, on the player's input line just after the hands: a stick's aim,
## bent toward whatever it is near enough to mean by an `AimCurve` — see there
## for how, and why it never snaps. Only a stick's. The pointer points at a
## place, and a place needs no help; a gamepad's right stick and the console on
## the glass, which aims through the same stick (`Touch`), point a way.
##
## What it bends toward is what the player could mean to hit: everything alive
## they can hurt (`Attacks.targets`), within `REACH`, with no wall between —
## a bolt would only meet the wall (`Room.has_line_of_sight`). Each one fills
## the angle its hurt radius fills from where the player stands.
##
## Which things those are changes all the time — one walks out from behind a
## wall, one dies, one comes into reach — and the curve changes with it, which
## would jump the weapon: the one thing the curve is built never to do. So a
## change is faded. The curve the stick was on and the one it is going to are
## both built, live, and the aim moves from the first to the second over
## `FADE`. A blend of curves that climb still climbs, so nothing the curve
## promises is lost on the way.
##
## How much of it the player wants is a setting, `strength`, kept with the
## machine like the pointer's speed: 0 is the stick as it is.

## How far off a target may be and still be one: about half a room.
const REACH := 640.0
## How much further out one already counted goes on counting, so a target
## pacing the edge of reach does not flicker in and out.
const REACH_SLACK := 32.0
## How long a change in what can be aimed at takes to come in.
const FADE := 0.2
## The most curves that may be fading at once. Past it the oldest is let go of.
const LAYERS_MAX := 4

const PATH := "user://enigami_aim_assist.json"
## The setting's grain, for the slider that sets it.
const STEP := 0.05

## How much of the bend the player wants, 0 to 1.
static var strength: float = 1.0

## The curves being faded between, oldest first: each the targets one is built
## around — instance ids, sorted — and how far in it has come. The oldest is
## all the way in; each after it fades in over the ones before.
var _layers: Array = []
## Where each target was last seen, by instance id — where it stood, and its
## hurt radius — so a curve fading out one that has died can still be built.
var _seen: Dictionary = {}
var _stepped_on: int = -1

func _init() -> void:
	rank = ASSIST

func process(s: InputState) -> InputState:
	if body == null or strength <= 0.0:
		return s
	# What can be aimed at is looked at once a drawn frame, which is the frame the
	# player aims in; a physics frame reads the line too, and bends with the same.
	if not Engine.is_in_physics_frame() and Engine.get_process_frames() != _stepped_on:
		_stepped_on = Engine.get_process_frames()
		_step(body.get_process_delta_time())
	if not s.aiming or not s.aim_by_stick or s.aim == Vector2.ZERO:
		return s
	s.aim = Vector2.from_angle(_bend(s.aim.angle()))
	s.aim_point = body.global_position + s.aim * Player.STICK_AIM_REACH
	return s

## Where the weapon points for a stick pointing at `x`: every curve under way,
## each faded in over the ones before it.
func _bend(x: float) -> float:
	var y := x
	for i in _layers.size():
		var layer: Dictionary = _layers[i]
		var f := _curve(layer["ids"]).at(x)
		y = f if i == 0 else lerpf(y, f, float(layer["t"]))
	return y

## Once a drawn frame: what can be aimed at now, and how far in each fade has come.
func _step(dt: float) -> void:
	var now := _targets_now()
	if _layers.is_empty():
		_layers.append({"ids": now, "t": 1.0})
	elif _layers[-1]["ids"] != now:
		_layers.append({"ids": now, "t": 0.0})
	for i in range(1, _layers.size()):
		_layers[i]["t"] = minf(1.0, float(_layers[i]["t"]) + dt / FADE)
	# A curve all the way in is the curve now; whatever it faded in over is done.
	for i in range(_layers.size() - 1, 0, -1):
		if float(_layers[i]["t"]) >= 1.0:
			_layers = _layers.slice(i)
			break
	while _layers.size() > LAYERS_MAX:
		_layers.pop_front()
		_layers[0]["t"] = 1.0
	var kept := {}
	for layer in _layers:
		for id in layer["ids"]:
			kept[id] = true
	for id in _seen.keys():
		if not kept.has(id):
			_seen.erase(id)

## The targets there are this frame, as sorted instance ids; and where every
## one the player could hurt was seen, counted or not, so the curves fading
## out a target going out of sight follow it while they do.
func _targets_now() -> Array:
	var from := body.global_position
	var room = body.get("room")
	var counted: Array = _layers[-1]["ids"] if not _layers.is_empty() else []
	var ids: Array = []
	for a: Actor in Attacks.targets(int(body.get("team"))):
		var id := a.get_instance_id()
		_seen[id] = [a.global_position, a.hurt_radius]
		var d := from.distance_to(a.global_position)
		if d > REACH + (REACH_SLACK if counted.has(id) else 0.0) or d < 1.0:
			continue
		if room != null and is_instance_valid(room) and room.has_method("has_line_of_sight") \
				and not room.has_line_of_sight(from, a.global_position):
			continue
		ids.append(id)
	ids.sort()
	return ids

## The curve around targets `ids`, as they are seen from where the body stands.
func _curve(ids: Array) -> AimCurve:
	var from := body.global_position
	var targets: Array = []
	for id in ids:
		var seen: Array = _seen.get(id, [])
		if seen.is_empty():
			continue
		var to: Vector2 = (seen[0] as Vector2) - from
		var d := to.length()
		if d < 1.0:
			continue
		targets.append(Vector2(to.angle(), asin(minf(1.0, float(seen[1]) / d))))
	return AimCurve.around(targets, strength)

## --- the setting ----------------------------------------------------------------

static func set_strength(v: float) -> void:
	strength = clampf(v, 0.0, 1.0)
	save()

static func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"strength": strength}))
	f.close()

static func load_saved() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		strength = clampf(float((parsed as Dictionary).get("strength", 1.0)), 0.0, 1.0)
