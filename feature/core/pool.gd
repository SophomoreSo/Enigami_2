class_name Pool
extends Resource

## A handful of things made once and lent out again and again, instead of made
## and thrown away every time one is wanted: aarthificial's "Different Kind of
## Pooling" (Legacy Devlog #19), worked from its transcript.
##
## The devlog's three points, as they land here:
##
##   * **A pool is a resource** — not a node in some screen that everything has
##     to find, and not a singleton everything has to name. Whatever spawns is
##     handed the pool it draws from, made in code or saved as a .tres, so two
##     spawners of the same thing can draw from two pools of it.
##   * **A thing goes back when it is done, not when it is let go of.** The
##     borrower `dispose`s it when it has finished with it; a thing with
##     somewhere to go first — a spark fading, a number drifting up — finishes
##     going and then hands itself back (`give_back`).
##   * **A thing is lent to a scope**: the screen it was spawned into. It can
##     look at anything there while it is out, but it stays where the pool
##     keeps it, under the tree's root and past every screen, so the scope
##     going cannot take it along. When the scope leaves the tree the pool takes
##     back at once everything still lent to it, finished or not — the
##     devlog's sceneUnloaded — so nothing outlives the screen it belonged to,
##     and nothing is lost with it either.
##
## Beside `Arena` because the two are a pair: Arena is where what is spawned
## into the world goes, a pool is where it comes from — the rules' things and
## the picture's alike, so nothing here draws.
##
## What a pool lends is any node. One that has a `pool` property is told which
## pool it came from, to hand itself back to; one with `_lent()` has it called
## each time it goes out, to be made new again; one with `_disposed()` has it
## called when its borrower lets go, and is trusted to hand itself back when it
## is done — anything without goes back the moment it is disposed. A thing
## waiting in the pool is hidden and still; it pauses with the game when it is
## out, since what the pool lends belongs to the world and not to the menus
## over it.

## What the pool is of: a script whose `new()` makes one.
@export var item: Script
## The most it keeps waiting. One handed back past that is let go of, so a
## burst of a hundred sparks does not leave a hundred lying about for good.
@export var keep: int = 48

## What is waiting to be lent, last back first out.
var _idle: Array[Node] = []
## What is out, by instance id: the instance id of the scope it was lent to.
var _out: Dictionary = {}
## Scope instance id -> the things lent to it.
var _lent: Dictionary = {}
## Where everything the pool has made lives, lent or waiting.
var _holder: Node2D = null

func _init(of: Script = null, most: int = 48) -> void:
	item = of
	keep = most

## One thing, lent to `scope`: a waiting one if there is one, a new one if not,
## shown and running. Taken back when `scope` leaves the tree, if not before.
func borrow(scope: Node) -> Node:
	var thing: Node = null
	while thing == null and not _idle.is_empty():
		var t: Node = _idle.pop_back()
		if is_instance_valid(t):
			thing = t
	if thing == null:
		thing = item.new()
		if "pool" in thing:
			thing.pool = self
		_home().add_child(thing)
	var scope_id := scope.get_instance_id() if scope != null else 0
	_out[thing.get_instance_id()] = scope_id
	if scope != null:
		if not _lent.has(scope_id):
			_lent[scope_id] = []
			scope.tree_exiting.connect(_collect.bind(scope_id), CONNECT_ONE_SHOT)
		(_lent[scope_id] as Array).append(thing)
	thing.process_mode = Node.PROCESS_MODE_INHERIT
	if thing is CanvasItem:
		(thing as CanvasItem).visible = true
	if thing.has_method("_lent"):
		thing._lent()
	return thing

## The borrower has finished with `thing`. If it has somewhere to go first, it
## goes there and hands itself back; otherwise it goes back now.
func dispose(thing: Node) -> void:
	if not is_out(thing):
		return
	if thing.has_method("_disposed"):
		thing._disposed()
	else:
		give_back(thing)

## `thing` back in the pool, now: hidden, still, and waiting to be lent again —
## or let go of, if the pool already has as many waiting as it keeps.
func give_back(thing: Node) -> void:
	if thing == null or not is_instance_valid(thing) or not is_out(thing):
		return
	var scope_id: int = _out[thing.get_instance_id()]
	_out.erase(thing.get_instance_id())
	if _lent.has(scope_id):
		(_lent[scope_id] as Array).erase(thing)
	thing.process_mode = Node.PROCESS_MODE_DISABLED
	if thing is CanvasItem:
		(thing as CanvasItem).visible = false
	if _idle.size() >= keep:
		thing.queue_free()
	else:
		_idle.append(thing)

## Whether `thing` is out on loan.
func is_out(thing: Node) -> bool:
	return thing != null and is_instance_valid(thing) and _out.has(thing.get_instance_id())

## How many are out, and how many are waiting.
func out_count() -> int:
	return _out.size()

func idle_count() -> int:
	return _idle.size()

## A scope leaving the tree: everything still lent to it comes back at once.
func _collect(scope_id: int) -> void:
	var things: Array = _lent.get(scope_id, [])
	_lent.erase(scope_id)
	for t in things.duplicate():
		give_back(t)

## The holder, made the first time anything is, under the tree's root. Put
## there at the end of the frame, since a screen being set up holds the root
## busy, so the very first thing a pool makes runs from the next frame on.
func _home() -> Node2D:
	if _holder == null or not is_instance_valid(_holder):
		_holder = Node2D.new()
		_holder.name = "Pool"
		_holder.process_mode = Node.PROCESS_MODE_PAUSABLE
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null:
			tree.root.add_child.call_deferred(_holder, true)
	return _holder
