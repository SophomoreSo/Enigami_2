class_name Wire
extends Node2D

## A wire: the way an electrical system's power comes to it from its generator
## (`Generator`), run under the floor and through the walls. Nobody sees it
## but a hero with the sight for it (`Sight`, Legna Dennis) — what that sight
## shows is the picture's (`WireSight`) — and followed back from what it
## powers, it is how the generator is found.
##
## `path` is where it runs, in its own space — its parent's, the room's — from
## the generator's end to the end at what it powers: a point at every turn,
## each straight stretch between two of them along a row or down a column of
## cells. It carries power while its generator runs.

## Every wire in the tree is in this group, which is how a sight finds them.
const GROUP := &"wires"

var path := PackedVector2Array()
## Where its power comes from, and what it powers: an electric gate.
var generator: Generator = null
var powers: Node2D = null

func _enter_tree() -> void:
	add_to_group(GROUP)

## Whether it carries power: its generator is there, and running.
func live() -> bool:
	return generator != null and is_instance_valid(generator) and generator.running()

## Where it runs, in the world, from the generator's end.
func world_path() -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in path:
		out.append(to_global(p))
	return out

## How long it is, end to end.
func length() -> float:
	var n := 0.0
	for i in range(1, path.size()):
		n += path[i - 1].distance_to(path[i])
	return n
