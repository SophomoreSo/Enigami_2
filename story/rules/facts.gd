class_name Facts
extends RefCounted

## What the characters know: whole numbers by name, which free talk is written
## against (see `FreeTalk`, and the `facts` table in data/db/schema.sql). A fact
## nobody has set is 0, so a rule can ask about something before anything has
## happened to it.
##
## Where a fact is kept is its scope, and the database says which:
##
##   save   with the profile, in `GameState.memory`: for good, and per slot
##   visit  here, until the player leaves the world they were in. A world
##          registered in `Arena` that is not the one these were written in
##          is a new visit, and finds them forgotten.
##   game   nowhere: read off the profile each time it is asked
##          (`GameState.facts`), since the game already counts it
##
## Every event and every free line is a fact too — how many times it has been
## raised, or said — kept with the profile: an event under its own name, a line
## as `<CHARACTER>.<line>` (see `line`).

## fact -> scope, as the database declares them. Read once; see `reload`.
static var _scopes: Dictionary = {}
static var _visit: Dictionary = {}
## The world `_visit` was written in, by instance id; 0 for none.
static var _visit_world: int = 0

## A free line's own fact: how many times `character` has said `rule`.
static func line(character: String, rule: String) -> String:
	return "%s.%s" % [character, rule]

static func value(id: String) -> int:
	match scope(id):
		"game":
			return int(GameState.facts().get(id, 0))
		"visit":
			return int(_visit_now().get(id, 0))
	return int(GameState.memory.get(id, 0))

## Sets a fact. One the game counts for itself is not the talk's to set: the
## build refuses a change to one, so this only says so.
static func put(id: String, v: int) -> void:
	match scope(id):
		"game":
			push_warning("Facts: '%s' is counted by the game, and a line cannot change it" % id)
		"visit":
			_visit_now()[id] = v
		_:
			GameState.memory[id] = v

static func add(id: String, n: int = 1) -> void:
	put(id, value(id) + n)

## Whether every one of `criteria` holds — rows of the `criteria` table, each a
## `fact`, an `op` and a `value`. None at all always holds.
static func hold(criteria: Array) -> bool:
	for c in criteria:
		if not _holds(value(String(c.get("fact", ""))), String(c.get("op", "=")), int(c.get("value", 0))):
			return false
	return true

## Makes `changes` — rows of the `changes` table: `set` a fact to the value, or
## `add` the value to it.
static func change(changes: Array) -> void:
	for c in changes:
		var id := String(c.get("fact", ""))
		if String(c.get("op", "set")) == "add":
			add(id, int(c.get("value", 0)))
		else:
			put(id, int(c.get("value", 0)))

## Writes down what the profile now remembers. A count that goes up with every
## blow is not worth a write of its own; it goes down with the next line said.
static func keep() -> void:
	GameState.keep_memory()

## How long `id` is kept. One the database does not declare is kept with the
## profile — the build refuses a rule that names one, so that is only ever a
## count asked for by name.
static func scope(id: String) -> String:
	if _scopes.is_empty():
		for r in Db.rows("SELECT id, scope FROM facts"):
			_scopes[String(r["id"])] = String(r["scope"])
	return String(_scopes.get(id, "save"))

## Forgets the scopes read from the database, so a rebuilt one is read again.
## `Dialogue.reload` calls this.
static func reload() -> void:
	_scopes.clear()

## This visit's facts — forgotten first, if the player has gone somewhere new.
static func _visit_now() -> Dictionary:
	var world := Arena.current()
	var here := world.get_instance_id() if world != null else 0
	if here != _visit_world:
		_visit.clear()
		_visit_world = here
	return _visit

static func _holds(have: int, op: String, want: int) -> bool:
	match op:
		"=":
			return have == want
		"<>":
			return have != want
		"<":
			return have < want
		"<=":
			return have <= want
		">":
			return have > want
		">=":
			return have >= want
	return false
