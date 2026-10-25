class_name Bench
extends Node2D

## A bench to sit on. Walk up to it and press interact, and the game takes the
## body the rest of the way — walks it over to the middle of the seat (`WalkTo`,
## the walk over to talk to somebody), where it sits down (`Player.sit`) — and
## it stays sat until it is asked to do anything else: a step, a dash, an
## attack, a cast, or interact at it again. A push the other way
## on the walk is the player taking the body back, and nothing sits down. It is
## the same gesture as a treasure box and a station: stand close enough, press
## the key. Sitting does nothing but sit.
##
## It stands on the floor, on the middle of the cell it was put down in, the
## way a treasure box does. A room holds the ones it was given
## (`Room.benches`): the hideout stands one between its stations, and a map made
## in the map creator one wherever one was laid (`MadeRoom.BENCH`).
##
## Nothing here draws. `graphics/views/bench_view.gd` draws it, and the key
## over it while a press would sit the body down.

## How near the body has to stand to it, on the floor, to sit on it.
const RANGE := 36.0

var player: Player = null
## Whether the player is close enough right now, recomputed every frame so the
## view can show the prompt without asking twice.
var near: bool = false
## The walk over to the seat, on the player's line while it walks, or null.
var _approach: WalkTo = null

func setup(at: Vector2) -> void:
	position = at

func _ready() -> void:
	add_to_group("benches")

func _process(_delta: float) -> void:
	near = player != null and is_instance_valid(player) and not player.dead \
		and player.global_position.distance_to(global_position) <= RANGE
	if _approach != null:
		_mind_approach()
		return
	if not Input.is_action_just_pressed("interact") or player == null or not is_instance_valid(player) \
			or player.input_locked or player.controls_locked():
		return
	if player.seat == self:
		player.stand_up()
	elif offered():
		_come_over()

## The body walked over to the seat, the way it is walked over to talk: on the
## player's own line, and theirs to refuse. Already there, it sits straight down.
func _come_over() -> void:
	if player.global_position.distance_to(global_position) <= WalkTo.THERE:
		player.sit(self)
		return
	_approach = WalkTo.new(global_position)
	player.input.add(_approach)

## The walk over, each frame: there, and the body sits down, facing the way it
## walked; or it ended without getting there — pushed the other way, carried
## off, a screen come up over the game — and nothing does.
func _mind_approach() -> void:
	if not is_instance_valid(player) or player.dead:
		_approach = null
		return
	if _approach.arrived:
		_approach = null
		if near and player.seat == null:
			player.sit(self)
	elif _approach.done or not near or player.input_locked:
		_approach.cancel()
		_approach = null

## Whether a press of interact would sit the body down on it: in reach, its
## own body and not one the player's hands are in, not on a seat already, and
## not on its way over to this one.
func offered() -> bool:
	return near and _approach == null and player.vessel() == player and player.seat == null

## Whether somebody sits on it.
func taken() -> bool:
	return player != null and is_instance_valid(player) and player.seat == self
