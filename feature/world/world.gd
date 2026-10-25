class_name World
extends Node2D

## What every world the shell can stand a player in has in common — a raid, the
## hideout's room, the sandbox, the dragon test — so the shell can ask without
## naming which one is up.
##
## `editing` is whether an assembly board is open over the world. The shell
## opens and closes the boards and says so here; the world holds the player
## still under one. `use_nearby()` is whether a press of `interact` would do
## something where the player stands: an exit they are standing in with nothing
## sealing it, a station open and within reach, someone in talking range. Each
## world answers for what it stages, so a new thing to use is an edit to the
## world that has it — and the shell, which used to name a station and an NPC
## to work this out, names neither.

var editing: bool = false

func use_nearby() -> bool:
	return false

## Whether a panel of the world's own is up over it with the whole screen to
## itself and its own way out on it — a station's, in the hideout. The shell
## asks, to clear the console's keys from under one.
func paneled() -> bool:
	return false
