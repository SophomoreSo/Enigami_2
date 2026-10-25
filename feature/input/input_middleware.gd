class_name InputMiddleware
extends RefCounted

## One stop on an `InputProvider`'s line. It is handed the frame's
## `InputState`, changes whatever it has a say in, and hands it on: the hands
## fill it in, a conversation empties it again, a walk writes over where it
## goes. None of them knows the others are there, and the body knows none of
## them.

## Where on the line it stands, lowest first. Middlewares of one rank stand in
## the order they joined.
##   HANDS   what fills the state in: the player's own hands (`Hands`), or
##           anything else that might drive a body.
##   ASSIST  what helps the hands say what they meant (`AimAssist`). Before the
##           holds, so a hold still has the last word.
##   HOLD    what takes the hands off it again (`HandsOff`).
##   STEER   what drives the body for itself (`WalkTo`). After the holds, so the
##           game can still walk a body nobody may move — the devlog puts its
##           navigation after its dialogue for the same reason.
const HANDS := 0
const ASSIST := 5
const HOLD := 10
const STEER := 20

var rank: int = HANDS
## The body the line drives, set when the middleware joins one.
var body: Node2D = null
## Whether it has said all it had to. A finished middleware leaves the line by
## itself, the next time the line is read.
var done: bool = false

## This middleware's say in the frame: change `state`, and hand it on.
func process(state: InputState) -> InputState:
	return state

## Whether, for as long as it stands on a line, the body is the computer's
## rather than the player's: the game is holding it for itself or walking it
## somewhere, or something else is playing it in the player's place. Most
## things on a line only help or stop the player's own hands, and do not.
## `Pointer` asks, through the player (`Player.taken_over`): while the computer
## has the body the crosshair is the computer's too, and the system pointer is
## shown beside it.
func takes_over() -> bool:
	return false
