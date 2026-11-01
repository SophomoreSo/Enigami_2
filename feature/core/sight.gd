extends Node

## A sight: what a hero sees on the vision key (`magic_toggle`, Y) that nobody
## else does — Legna Dennis the wires an electrical system draws its power
## down (`Heroes.sight_of`, `Wire`), and so the generator at the far end of
## one. The key goes round what there is to see: the world as it is, the
## hero's own sight, the world with magic off (`Magic`), and back. A hero with
## no sight of their own turns magic off and on with it, as everyone always
## has.
##
## What a sight shows is the picture's (`WireSight`): this says only which
## one is on. Like magic it is a state of the world, not of the profile —
## never saved, and put away when the screen changes (`Game._clear`).

signal changed(seeing: String)

## The sight that is on: '' for none, or one a hero has (`heroes.sight`).
var seeing: String = ""

func set_seeing(s: String) -> void:
	if s == seeing:
		return
	seeing = s
	changed.emit(seeing)
	Cues.emit_cue(&"sight", {"seeing": seeing})

## The vision key, pressed by a hero whose own sight is `own` ('' for none):
## the world as it is goes to their sight, their sight to magic off, and magic
## off back to the world as it is. With no sight of their own, magic goes off
## and comes back.
func cycle(own: String) -> void:
	if own == "":
		set_seeing("")
		Magic.toggle()
	elif seeing != "":
		set_seeing("")
		Magic.set_on(false)
	elif not Magic.on:
		Magic.set_on(true)
	else:
		set_seeing(own)
