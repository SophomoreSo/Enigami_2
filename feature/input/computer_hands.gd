class_name ComputerHands
extends InputMiddleware

## The computer's hands on a body, in the place of the player's own: a demo, a
## test, anything that plays the character for whoever is at the desk.
##
## It stands at the head of the line, straight after the player's `Hands`, and
## drops what they said — every key, button and stick — so the person watching
## moves nothing. What goes down the line instead is what it has been told:
## which way to walk, what is held, what was pressed. Everything after it is as
## it was. A hold still stops it and a walk still steers it: the computer plays
## by the rules the player does.
##
## It points with the game's own pointer and never the system's. `point_at`
## leads the crosshair to a place in the world (`Pointer.lead_to`) and the aim
## is read off where that lands, so a place off the screen is aimed at from the
## screen's edge, as a hand would have to. While it is on a line the body is
## taken over (`takes_over`), which is what tells `Pointer` to leave the
## crosshair to it and show the system pointer beside it.
##
## What is not on the line is not its to press: `interact`, the keys that open
## a screen and the pause menu are read off `Input` by whoever answers them, so
## the person at the desk can still pause a game the computer is playing.

## Which way to walk, as a way on the floor no longer than 1, and how hard.
var move: Vector2 = Vector2.ZERO
## Which way to face without walking, or zero to leave the facing alone.
var turn: Vector2 = Vector2.ZERO
## Sprinting, for as long as it is set, whichever way it walks.
var sprint: bool = false
## The attack button, held.
var attack: bool = false
## The cast button, held: what charges. Letting go of it is the release that
## casts, which is raised here.
var cast: bool = false:
	set(on):
		if cast and not on:
			_raise(&"cast_released")
		cast = on

## Where it is pointing, in the world, once it has been told (`point_at`). Until
## then the pointer rests wherever it was when the computer took over.
var _at: Vector2 = Vector2.ZERO
var _pointing: bool = false
## The weapon last asked for, by slot and by step, for as long as the act that
## asked is still being read.
var _slot: int = -1
var _step: int = 0
## The acts raised and not yet read by both kinds of frame — see `_happened`.
var _acts: Dictionary = {}

func takes_over() -> bool:
	return true

## Points at `at`, a place in the world the body stands in, and keeps pointing
## there until it is told somewhere else.
func point_at(at: Vector2) -> void:
	_at = at
	_pointing = true

## Walks `way`: a way on the floor, as hard as it is long (up to 1). Zero
## stands still.
func walk(way: Vector2) -> void:
	move = way.limit_length(1.0)

func dash() -> void:
	_raise(&"dash_pressed")

## Puts the weapon in `slot` in hand, 0 for the first carried.
func take_weapon(slot: int) -> void:
	_slot = slot
	_raise(&"weapon_slot")

## Puts the next weapon in hand, or with -1 the one before.
func step_weapon(step: int = 1) -> void:
	_step = signi(step)
	_raise(&"weapon_step")

## A press of interact, as the body's own line reads it: inside a monster, the
## press that takes the weapon from the player's hands.
func use() -> void:
	_raise(&"use_pressed")

## Out of the monster the player is in.
func step_out() -> void:
	_raise(&"step_out_pressed")

func process(_said: InputState) -> InputState:
	var s := InputState.new()
	s.move = move.limit_length(1.0)
	s.turn = turn
	s.sprint = sprint
	s.attack = attack
	s.cast = cast
	s.dash_pressed = _happened(&"dash_pressed")
	s.cast_released = _happened(&"cast_released")
	s.weapon_slot = _slot if _happened(&"weapon_slot") else -1
	s.weapon_step = _step if _happened(&"weapon_step") else 0
	s.use_pressed = _happened(&"use_pressed")
	s.step_out_pressed = _happened(&"step_out_pressed")
	if body != null:
		_aim(s)
	return s

## The game's pointer, led to wherever this has been told to point, and the aim
## read off where it landed the way the player's is read off theirs
## (`Hands._aim`) — never a stick, and never the system's pointer.
func _aim(s: InputState) -> void:
	var at := Pointer.lead_to(body, _at) if _pointing else Pointer.world_point(body)
	var m := at - body.global_position
	s.aiming = true
	s.aim_reach = 1.0
	s.aim = m.normalized() if m.length() > 4.0 else Vector2.ZERO
	s.aim_point = at

func _raise(act: StringName) -> void:
	_acts[act] = {"physics": true, "drawn": true, "physics_on": -1, "drawn_on": -1}

## Whether `act` happened, as the frame being asked in sees it. The body takes a
## dash in the physics frame it moves in and a cast's release in the drawn one
## (`InputState`), so each kind of frame has to see an act once and neither may
## see it twice. An act waits for each kind in turn, and the frame that reads
## it keeps it for every reading of that frame — the line may be read more than
## once in one.
func _happened(act: StringName) -> bool:
	if not _acts.has(act):
		return false
	var a: Dictionary = _acts[act]
	var physics := Engine.is_in_physics_frame()
	var kind := "physics" if physics else "drawn"
	var frame := Engine.get_physics_frames() if physics else Engine.get_process_frames()
	if a[kind]:
		a[kind] = false
		a[kind + "_on"] = frame
	return int(a[kind + "_on"]) == frame
