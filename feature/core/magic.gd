extends Node

## Magic: on, as the game has always been, or off, by a key (`magic_toggle`,
## Y). Off, every graph in the game — the player's and the monsters' alike — is
## cast as its forms alone: the weapon's own attack, with nothing the other
## parts would do to it (`SkillRunner.forms_only`); a hold charges nothing
## (`Player.can_charge`); and what is only there in magic is not — the map
## creator's magic stone (`MadeRoom.MAGIC`), neither solid nor drawn.
##
## The picture goes grey with it (`PixelCamera`), which is the picture's own
## business: this is a rule, and names nothing of it. It is a state of the
## world, not of the profile — never saved, and put back on when the screen
## changes (`Game._clear`) — so a raid always starts in magic.

signal changed(on: bool)

var on: bool = true

func toggle() -> void:
	set_on(not on)

func set_on(v: bool) -> void:
	if v == on:
		return
	on = v
	changed.emit(on)
	Cues.emit_cue(&"magic", {"on": on})
