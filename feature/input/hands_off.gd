class_name HandsOff
extends InputMiddleware

## Takes the hands off the body: nothing the player presses walks, sprints,
## turns, dashes, charges, casts, changes weapon or steps out of a monster,
## and the weapon stays where it was last pointed. A screen over the game
## puts one on the player's line, and so does a conversation in the box
## (`Player.input_locked`, `Player.talk_locked`).
##
## It stands after the hands and before anything that steers, so the game can
## still walk a body its player may not move. The acts it stops, it stops by
## shutting their gates, so one raised further down the line — a dash something
## presses for the body — is stopped as well.

## Whether it is a screen's. A window over the game is the player's own doing:
## they put the body aside for it, and their pointer is for its buttons. Any
## other hold is the game holding the body for itself — a conversation, a stun
## — which is the computer taking it over (`takes_over`).
var for_screen: bool = false

func _init(screen: bool = false) -> void:
	rank = HOLD
	for_screen = screen

func takes_over() -> bool:
	return not for_screen

func process(s: InputState) -> InputState:
	s.move = Vector2.ZERO
	s.turn = Vector2.ZERO
	s.sprint = false
	s.attack = false
	s.cast = false
	s.aiming = false
	s.can_dash = false
	s.can_cast = false
	s.can_switch = false
	s.can_use = false
	s.can_step_out = false
	return s
