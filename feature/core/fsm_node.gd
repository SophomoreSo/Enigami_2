class_name FSMNode
extends RefCounted

## One state of a finite state machine.
##
## A state is what it does each frame — its steps, taken in order — and an
## ordered list of ways out of it. Each way out is a condition and where it
## leads; the first condition that holds wins. A transition may also split
## between several destinations by probability.

## What the state does each frame, in the order it does it.
var steps: Array[Callable] = []
var next_nodes: Array = []
## The state's id and the name it goes by, as its machine's table gives them;
## empty for a state built by hand.
var id: String = ""
var label: String = ""

func _init(step_funcs: Array[Callable] = []) -> void:
	steps = step_funcs

## Takes this state's steps, in order.
func perform() -> void:
	for step in steps:
		if step.is_valid():
			step.call()

## A deterministic transition: when `condition` holds, go to `node`.
func add_next_node(condition: Callable, node: FSMNode, probability: float = 1.0) -> void:
	next_nodes.append({
		"condition": condition,
		"destinations": [{"node": node, "probability": probability}],
	})

## A transition that picks one of several destinations when `condition` holds.
## `destinations` is an array of {"node": FSMNode, "probability": float} whose
## probabilities sum to 1.
func add_probabilistic_transition(condition: Callable, destinations: Array) -> void:
	var total := 0.0
	for dest in destinations:
		total += float(dest.get("probability", 0.0))
	if absf(total - 1.0) > 0.001:
		push_warning("Probabilistic transition probabilities sum to %f, expected 1.0" % total)
	next_nodes.append({
		"condition": condition,
		"destinations": destinations,
	})

## The state the first holding condition leads to, or null when none holds.
func find_next_node() -> FSMNode:
	for transition in next_nodes:
		if transition["condition"].call():
			return _select_destination(transition["destinations"])
	return null

func _select_destination(destinations: Array) -> FSMNode:
	if destinations.is_empty():
		return null
	if destinations.size() == 1 or float(destinations[0]["probability"]) >= 1.0:
		return destinations[0]["node"]
	var roll := randf()
	var cumulative := 0.0
	for dest in destinations:
		cumulative += float(dest["probability"])
		if roll <= cumulative:
			return dest["node"]
	# Floating point can leave the roll just past the last bucket.
	return destinations[destinations.size() - 1]["node"]

## States that lead to each other hold each other alive; this breaks the cycle.
func cleanup() -> void:
	next_nodes.clear()
	steps.clear()
