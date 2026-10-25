class_name Letterbox
extends Control

## The screen gone wide while a conversation in the box has it: black bars
## come in over the top and the bottom of the picture, solid from the first
## pixel, until what is left between them is as wide for its height as a film
## in scope (`ASPECT`) — and go back out the same way once the conversation is
## over. A conversation in the box holds the player still and has the screen
## (`Npc`, in the box; FROZEN MOVEMENT in the story maker), and this is the
## picture saying so. Free talk leaves the screen as it is: the player goes on
## playing under it.
##
## The camera goes with them. Whoever stands on a room's floor stands where
## the bottom bar comes, so the two talking are taken into what the bars leave
## as they come in (`NpcView`, through `Fx.direct`); nothing under the bars is
## seen, so the camera may go as much further up or down than the screen's own
## framing as they stand deep, and they say how deep that is every frame
## (`Fx.bars`). The box hangs over the top bar the way it hung over the
## picture.
##
## Screen space, at the screen's resolution, on the PIXEL grid like the box. A
## screen as wide as that already, or wider, gets no bars.

## Over the pixel picture (`PixelCamera.LAYER`) and its prompts, one over it,
## and under the box (`DialogueBox.LAYER`).
const LAYER := 3
## How wide what is left between the bars stands for its height: scope, the
## widest a film is shown.
const ASPECT := 2.39
## Seconds the bars take to come all the way in, and to go all the way out.
const TIME := 0.6
const BAR := Color(0, 0, 0)

var npc: Npc
## How far in the bars are: 0 out of sight, 1 all the way in.
var shown: float = 0.0

func _ready() -> void:
	UiKit.fill_screen(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Before the camera is steered this frame, so it goes by where the bars are
	# now rather than where they were.
	process_priority = -1

func _process(delta: float) -> void:
	UiKit.sync_screen(self)
	var talking := npc != null and is_instance_valid(npc) and npc.is_talking()
	var was := shown
	shown = move_toward(shown, 1.0 if talking else 0.0, delta / TIME)
	# Said by bars that are there, or were a frame ago, and by no others: the
	# character nobody is talking to has no bars, and says nothing over them.
	if shown > 0.0 or was > 0.0:
		Fx.bars = drawn()
	queue_redraw()

## Bars taken away while they are in take the camera's room under them away
## with them.
func _exit_tree() -> void:
	if shown > 0.0:
		Fx.bars = 0.0

## How tall each bar stands all the way in, on the PIXEL grid.
func depth() -> float:
	var px := float(UiKit.PIXEL)
	return maxf(floorf((size.y - size.x / ASPECT) * 0.5 / px) * px, 0.0)

## How tall each stands now, eased at both ends so they set off gently and
## settle gently, on the PIXEL grid.
func drawn() -> float:
	var px := float(UiKit.PIXEL)
	return roundf(depth() * smoothstep(0.0, 1.0, shown) / px) * px

## Both bars, as far in as they have come, and opaque however far that is:
## the edges of the picture closing in, never a shade over it.
func _draw() -> void:
	var h := drawn()
	if h <= 0.0:
		return
	draw_rect(Rect2(0.0, 0.0, size.x, h), BAR)
	draw_rect(Rect2(0.0, size.y - h, size.x, h), BAR)
