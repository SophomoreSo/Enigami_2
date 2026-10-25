class_name Station
extends Node2D

## A place in the hideout you walk up to and press interact at: the weapon rack,
## the merchant's counter, the gate out.
##
## It is the same gesture as talking to an `Npc` and as holding an extraction in
## a raid — stand close enough, press the key — and deliberately not a button:
## the hideout is a room now, and what is in a room is walked to.
##
## Nothing here draws. `graphics/views/hideout_world_view.gd` puts the sign over
## it and says what pressing it would do; this only knows where it stands, how
## close is close enough, and whether it is open for business.

## Pressed while the player was in range.
signal used(station: Station)

## How close the player has to stand, centre to centre. Wider than an NPC's
## talking range: a station is furniture with a footprint, not a person, and
## walking "up to" a counter should not mean standing inside it.
const RANGE := 84.0

## Which station this is — "weapons", "shop", "gate". The world reads
## it to decide what a press opens; nothing else should care.
var id: String = ""
## What the sign over it says.
var label: String = ""
## A station that cannot be used right now still stands there and still says
## what it is — it just does not answer. The gate is shut like this until the
## kit is worth carrying.
var open: bool = true
## Why it is shut, in the player's language, or "". Shown under the sign.
var closed_reason: String = ""
var player: Player = null
## Whether the player is close enough right now, recomputed every frame so the
## view can light the sign without asking twice.
var near: bool = false

func _process(_delta: float) -> void:
	near = _in_range()

func _in_range() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	return global_position.distance_to(player.global_position) <= RANGE

## One press. The range is checked here rather than by whoever is listening, so
## a station reached by any other route answers on the same terms.
func interact() -> void:
	if not open or not _in_range():
		return
	used.emit(self)
