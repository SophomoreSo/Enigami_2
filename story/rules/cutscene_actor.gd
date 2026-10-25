class_name CutsceneActor
extends CharacterBody2D

## Someone standing on the stage of a directed scene. It has a body, so it
## stands on the floor and walks about it, stopped by whatever a stage has
## standing on it, and it has no will of its own: where it goes is whatever the
## beat running now told it.
##
## Deliberately not an `Actor`, for the same reason an `Npc` is not one: attacks
## find their targets through the "actors" group, and nobody in a cutscene
## should ever be a target. Nothing here is drawn —
## `story/view/cutscene_actor_view.gd` shows it.

## How wide they are, and how tall their art stands; on the floor they take up
## their width, and a little over half of it deep (`Actor._make_body`).
const BODY := Vector2(18.0, 28.0)
## How fast a `move` walks when the direction does not say.
const WALK_SPEED := 70.0
## Near enough to a mark to have arrived. Wider than a pixel because a walk is
## stepped in whole frames and would otherwise tremble on the spot forever.
const ARRIVE := 3.0

## Who this is in the scene file — the key in `cast`.
var cast_id: String = ""
## The whole cast entry, passed straight through from the file. The rules read
## nothing out of it; the view reads `sprite`, exactly as a view reads an NPC's.
var cast: Dictionary = {}

## The way they face on the floor, a unit vector.
var facing: Vector2 = Vector2.RIGHT
## The side last turned to, 1 right and -1 left, for art drawn side on.
var _side: int = 1
var body_size: Vector2 = BODY
## What the view must play regardless of motion, set by an `anim` direction, or
## "" to let the view choose from how fast this is moving.
var forced_anim: String = ""
## Off stage: still cast, not yet walked on. Nothing draws or moves.
var on_stage: bool = true

var _walk_to: Vector2 = Vector2.ZERO
var _walk_speed: float = 0.0
var _walking: bool = false

func setup(id: String, entry: Dictionary) -> void:
	cast_id = id
	cast = entry
	if entry.has("facing"):
		face(CutsceneScript.way(String(entry["facing"])))

func _ready() -> void:
	add_to_group("cutscene_cast")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(body_size.x, body_size.x * 0.6)
	shape.shape = rect
	add_child(shape)

func _physics_process(_delta: float) -> void:
	if not on_stage:
		return
	if _walking:
		var gap := _walk_to - global_position
		if gap.length() <= ARRIVE:
			# Land exactly on the mark rather than near it, so two cast members
			# sent to the same spot on different days end up in the same place.
			global_position = _walk_to
			stop()
		else:
			velocity = gap.normalized() * _walk_speed
			face(gap)
	else:
		velocity = Vector2.ZERO
	move_and_slide()

## Walks to `spot` at `speed`, facing the way it is going. The beat that asked
## waits on `arrived`.
func walk_to(spot: Vector2, speed: float = WALK_SPEED) -> void:
	_walk_to = spot
	_walk_speed = maxf(speed, 1.0)
	_walking = true

## Puts them down somewhere with no walk at all.
func place_at(point: Vector2) -> void:
	global_position = point
	velocity = Vector2.ZERO
	_walking = false

func stop() -> void:
	_walking = false
	velocity = Vector2.ZERO

## Cuts a walk short by putting them where it was headed. What a press does to
## a beat still playing out: the scene never makes anyone wait for a walk.
func finish_walk() -> void:
	if _walking:
		global_position = _walk_to
		stop()

func walking() -> bool:
	return _walking

func arrived() -> bool:
	return not _walking

## Turns them to face `dir` on the floor; nothing for no way at all.
func face(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return
	facing = dir.normalized()
	if facing.x != 0.0:
		_side = 1 if facing.x > 0.0 else -1

## The side they are turned to: 1 right, -1 left (`Actor.side`).
func side() -> int:
	return _side

## Which of a character's facings shows the way they face (`Actor.facing_name`).
func facing_name() -> String:
	return Actor.face_name_of(facing)
