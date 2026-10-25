class_name LostKit
extends Node2D

## Everything a death left on the floor, lying on the spot it fell.
##
## One node and one pickup: the weapon, the graph that was built onto it, the
## components in the bag and the scrap all come back in a single touch — there
## is nothing to sort through and nothing to leave behind by accident.
## What is in it is `record`, which is the drop `GameState` has been keeping
## since the run that made it, written into this room's record when the map was
## built. It lies where it was put, on the floor, and stays put: a landmark
## that slid around would be a worse one. `graphics/views/lost_kit_view.gd`
## draws it.

signal collected(kit: LostKit)

## Wider than a loose part's reach. A drop is the thing the whole run was for,
## so brushing past it counts; it does not have to be stood on exactly.
const PICKUP_RANGE := 30.0

var record: Dictionary = {}
var room = null

func setup(rec: Dictionary, at: Vector2) -> void:
	record = rec
	position = at

func _ready() -> void:
	add_to_group("lost_kits")

func _process(_delta: float) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var p := players[0] as Node2D
	if p != null and global_position.distance_to(p.global_position) < PICKUP_RANGE:
		collected.emit(self)
		Cues.at(&"kit_back", global_position, {"size": size()})
		queue_free()

## What is in it, as one number: a weapon counts for one, and so does every
## part built onto a graph that fell and every component in the bag. Scrap is
## not counted — it is the one thing in here that is only worth what it says.
## The profile counts it, since the profile is what wrote it down.
func size() -> int:
	return GameState.kit_size(record)
