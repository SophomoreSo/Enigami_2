extends Node

## Where live world nodes belong.
##
## Attacks, loose pickups and scheduled follow-ups have to be parented
## somewhere that outlives the actor that made them but dies with the screen.
## Whatever screen is running — a raid, the sandbox, a test harness — registers
## itself here, and everything that spawns into the world asks for it by name
## rather than carrying a reference down through every call.
##
## And who is standing in it: every actor there is, by side, kept rather than
## looked up. A bolt asks what it can strike on every hop, a burst and a pet
## every frame, every monster what it can hunt — and each walked the whole
## tree's "actors" group for the answer and built a list of it, dozens of
## times a frame with a volley in the air. The lists are built once and kept
## until an actor comes or goes (`_on_node`) or dies (`_on_died`), and handed
## out as they are: whoever asks reads them and does not change them.

var world: Node = null

## Every actor standing, and those on each side, by `team` — or rather those
## not on a side, since what asks is what it can strike: `_against[team]`.
## Empty until asked for, and dropped when they are stale.
var _actors: Array = []
var _against: Dictionary = {}
var _stale := true

func _ready() -> void:
	get_tree().node_added.connect(_on_node)
	get_tree().node_removed.connect(_on_node)
	# And once a frame regardless: the sides are read off each actor as the
	# lists are built, and a side can change without a word (`sides_changed`
	# is the word, where the code knows it did).
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	_stale = true

func register(w: Node) -> void:
	world = w

func current() -> Node:
	if world == null or not is_instance_valid(world):
		return null
	return world

## Every actor in the world that is not dead. Read it; do not change it.
func actors() -> Array:
	_refresh()
	return _actors

## Every actor not on `team` that is not dead: what something of `team` can
## strike. Read it; do not change it.
func against(team: int) -> Array:
	_refresh()
	if not _against.has(team):
		var out: Array = []
		for a in _actors:
			if a.team != team:
				out.append(a)
		_against[team] = out
	return _against[team]

func _refresh() -> void:
	if not _stale:
		return
	_stale = false
	_actors.clear()
	_against.clear()
	for a in get_tree().get_nodes_in_group("actors"):
		if a is Actor and not a.dead:
			_actors.append(a)
			if not a.died.is_connected(_on_died):
				a.died.connect(_on_died)

## An actor came or went: the lists are stale. Told of every node, so it asks
## the cheap question first.
func _on_node(n: Node) -> void:
	if n is Actor:
		_stale = true

func _on_died(_a: Actor) -> void:
	_stale = true

## An actor changed sides — a monster the player's hands went into, or out of
## — so what each side can strike has changed with it.
func sides_changed() -> void:
	_stale = true
