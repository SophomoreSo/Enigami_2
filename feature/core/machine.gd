class_name Machine
extends RefCounted

## A state machine, read whole from the content database and built into the
## `FSMNode`s its owner runs: the rows of `machines`, `states`, `steps`,
## `conditions` and `transitions` (see `data/db/README.md`).
##
## Everything the machine is lives in the table: which states there are, what
## each does every frame, which can follow which and in what order the ways
## out are asked, how a way splits by probability, and what opens it. What the
## owner keeps is the words the rows are written in, handed to `build` by
## name: its *actions*, each one thing the body does on a frame, which a
## state's steps take in order; and its *senses*, each one thing it can tell
## about itself, which a condition reads. So the player keeps `_action_gravity`
## and whether it is on the floor, and the table says that a fall is steering,
## gravity, a jump and a dash, and that the way into it is open when
## `not dashing and not on_floor and wall == 0 and velocity.y >= 0`.
##
## A condition is a Godot `Expression`, parsed once, over the senses by name
## and nothing else — not the owner, not the scene — and asked afresh each
## time its way out is tried.
##
## Nothing here falls back. A machine that is not in the database, a step
## naming an action its owner does not have, or a condition that does not
## read, reads a sense the owner does not have or answers anything but true or
## false, comes back as `faults` and without those parts, and the owner is
## expected to say so loudly. The player cannot move without one, and there is
## no version of it that half moves.

## The machine's id in the table.
var id: String = ""
## The state it begins in, or null when it could not be built.
var start: FSMNode = null
## Every state by id.
var states: Dictionary = {}
## Every condition by id, as the Callable its ways out ask. One that could not
## be built is a fault instead.
var conditions: Dictionary = {}
## What is wrong with it, in words. Empty when the machine is whole.
var faults: Array = []

## Every machine in the database, by id.
static func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for r in Db.rows("SELECT id FROM machines ORDER BY id"):
		out.append(String(r["id"]))
	return out

## A machine as the database has it, in the shape `problems_in` checks and
## `build` builds from: the `machines` row, with `states` under it by id, each
## carrying its `steps` — the names of its actions, in order — `conditions` by
## id, each its expression, and `transitions` as a list in the order they are
## tried. Empty when there is no such machine.
static func source(machine_id: String) -> Dictionary:
	var found := Db.records("machines", "id = ?", [machine_id])
	if found.is_empty():
		return {}
	var def: Dictionary = found[0]
	var state_rows: Dictionary = {}
	for s in Db.records("states", "machine_id = ?", [machine_id], "rowid"):
		s["steps"] = []
		state_rows[String(s["id"])] = s
	for step in Db.records("steps", "machine_id = ?", [machine_id], "state_id, position"):
		var state = state_rows.get(String(step["state_id"]))
		if state != null:
			(state["steps"] as Array).append(String(step["action"]))
	def["states"] = state_rows
	var condition_rows: Dictionary = {}
	for c in Db.records("conditions", "machine_id = ?", [machine_id], "rowid"):
		condition_rows[String(c["id"])] = String(c["expression"])
	def["conditions"] = condition_rows
	def["transitions"] = Db.records("transitions", "machine_id = ?", [machine_id], "from_id, position, rowid")
	return def

## Builds `id` over its owner's `actions` — name to Callable, one thing the
## body does — and `senses` — name to Callable, answering what a condition
## reads by that name.
static func build(machine_id: String, actions: Dictionary, senses: Dictionary) -> Machine:
	var m := Machine.new()
	m.id = machine_id
	var def := source(machine_id)
	if def.is_empty():
		m.faults.append("no machine called '%s' in %s" % [machine_id, Db.PATH])
		return m
	m.faults = problems_in(def)
	var rows: Dictionary = def["states"]
	for sid in rows:
		var steps: Array[Callable] = []
		var lacking: Array = []
		for action in rows[sid]["steps"]:
			if actions.has(action):
				steps.append(actions[action])
			else:
				lacking.append(action)
		if not lacking.is_empty():
			m.faults.append("state %s does %s, which the owner cannot" % [sid, ", ".join(lacking)])
			continue
		var node := FSMNode.new(steps)
		node.id = String(sid)
		node.label = String(rows[sid].get("label", sid))
		m.states[String(sid)] = node
	# The senses in one order, so a condition can be handed them as a list.
	var names := PackedStringArray()
	var reads: Array[Callable] = []
	for sense in senses:
		names.append(String(sense))
		reads.append(senses[sense])
	var texts: Dictionary = def["conditions"]
	for cid in texts:
		var parsed = _parse(String(texts[cid]), names)
		if not parsed is Expression:
			continue   # said already, by problems_in
		var wrong := _try(parsed, reads)
		if wrong != "":
			m.faults.append("condition %s %s" % [cid, wrong])
			continue
		m.conditions[String(cid)] = _asker(parsed, reads)
	# Rows sharing a from and a position are one way out, split between them.
	var ways: Dictionary = {}
	var order: Array = []
	for t in def["transitions"]:
		var from_id := String(t.get("from_id", ""))
		var to_id := String(t.get("to_id", ""))
		var condition := String(t.get("condition", ""))
		if not m.states.has(from_id) or not m.states.has(to_id) or not m.conditions.has(condition):
			continue   # said already, by problems_in, or by the state or the condition above
		var key := "%s\n%d" % [from_id, int(t.get("position", 0))]
		if not ways.has(key):
			ways[key] = {"from": m.states[from_id], "condition": m.conditions[condition], "destinations": []}
			order.append(key)
		(ways[key]["destinations"] as Array).append({
			"node": m.states[to_id], "probability": float(t.get("probability", 1.0))})
	for key in order:
		var way: Dictionary = ways[key]
		var from: FSMNode = way["from"]
		var destinations: Array = way["destinations"]
		if destinations.size() == 1:
			from.add_next_node(way["condition"], destinations[0]["node"])
		else:
			from.add_probabilistic_transition(way["condition"], destinations)
	var start_id := String(def.get("start", ""))
	m.start = m.states.get(start_id, null)
	if m.start == null and rows.has(start_id):
		m.faults.append("the start, %s, could not be built" % start_id)
	return m

## Mistakes in a machine that would otherwise show as a state nobody leaves,
## a way out nobody takes, or a split that does not add up. Phrased the way
## `Dialogue.problems` phrases them, and checked by `tests/feature/machine_test`.
static func problems(machine_id: String) -> Array:
	var def := source(machine_id)
	if def.is_empty():
		return ["no machine called '%s' in %s" % [machine_id, Db.PATH]]
	return problems_in(def)

## The same check against a machine already in hand, in the shape `source`
## returns — so the checker itself can be put in front of a deliberately
## broken one without a broken row having to live in the database. It needs no
## owner: whether a name is one the owner has is `build`'s to find out.
static func problems_in(def: Dictionary) -> Array:
	var found: Array = []
	var state_rows = def.get("states", {})
	if not state_rows is Dictionary or state_rows.is_empty():
		return ["no states"]
	if not state_rows.has(String(def.get("start", ""))):
		found.append("start -> %s" % def.get("start", ""))
	for sid in state_rows:
		var steps = state_rows[sid].get("steps", []) if state_rows[sid] is Dictionary else []
		if not steps is Array or steps.is_empty():
			found.append("%s does nothing" % sid)
			continue
		for action in steps:
			if String(action) == "":
				found.append("a step of %s names no action" % sid)
	var condition_rows = def.get("conditions", {})
	if not condition_rows is Dictionary:
		condition_rows = {}
	for cid in condition_rows:
		var parsed = _parse(String(condition_rows[cid]), PackedStringArray())
		if not parsed is Expression:
			found.append("condition %s %s" % [cid, parsed])
	var transitions = def.get("transitions", [])
	if not transitions is Array:
		transitions = []
	# Each way out: how much of a whole its rows add up to, and their condition.
	var ways: Dictionary = {}
	for t in transitions:
		if not t is Dictionary:
			found.append("a way out that is not a row")
			continue
		var from_id := String(t.get("from_id", ""))
		var to_id := String(t.get("to_id", ""))
		var where := "%s -> %s" % [from_id, to_id]
		if not state_rows.has(from_id):
			found.append("%s leaves a state that does not exist" % where)
		if not state_rows.has(to_id):
			found.append("%s leads to a state that does not exist" % where)
		var condition := String(t.get("condition", ""))
		if condition == "":
			found.append("%s has no condition" % where)
		elif not condition_rows.has(condition):
			found.append("%s asks %s, which is not a condition" % [where, condition])
		var p := float(t.get("probability", 1.0))
		if p <= 0.0 or p > 1.0:
			found.append("%s has a probability of %s" % [where, str(p)])
		var at := int(t.get("position", 0))
		var key := "%s\n%d" % [from_id, at]
		if not ways.has(key):
			ways[key] = {"from": from_id, "at": at, "sum": 0.0, "condition": condition}
		var way: Dictionary = ways[key]
		way["sum"] = float(way["sum"]) + p
		if String(way["condition"]) != condition:
			found.append("the ways out of %s at %d disagree on their condition" % [from_id, at])
	for key in ways:
		var way: Dictionary = ways[key]
		if absf(float(way["sum"]) - 1.0) > 0.001:
			found.append("the ways out of %s at %d add up to %.2f, not 1" % [way["from"], way["at"], way["sum"]])
	return found

## Breaks the cycles the states hold each other in. Call when the owner goes.
func cleanup() -> void:
	for s in states.values():
		(s as FSMNode).cleanup()
	states.clear()
	conditions.clear()
	start = null

## A condition's text parsed over the senses in `names`, or, when it does not
## read, why not. An `Expression` stops at the end of the first whole
## expression it finds and says nothing of the rest, so `on_floor dir != 0`
## would quietly be asked as `on_floor`. In brackets, what follows it has to
## be the closing one — and a text whose own brackets do not pair could close
## them early, so that is refused first.
static func _parse(text: String, names: PackedStringArray) -> Variant:
	if text.strip_edges() == "":
		return "says nothing"
	if not _paired(text):
		return "does not read: its brackets do not pair"
	var e := Expression.new()
	if e.parse("(" + text + ")", names) != OK:
		var why := e.get_error_text()
		# The bracket it wants is one nobody wrote; what it means is this.
		if why == "Expected ')'":
			why = "it goes on after a whole expression, with no `and` or `or` to join the rest"
		return "does not read: " + why
	return e

## Whether `text`'s round brackets pair up, outside its quotes.
static func _paired(text: String) -> bool:
	var depth := 0
	var quote := ""
	for ch in text:
		if quote != "":
			if ch == quote:
				quote = ""
		elif ch == "\"" or ch == "'":
			quote = ch
		elif ch == "(":
			depth += 1
		elif ch == ")":
			depth -= 1
			if depth < 0:
				return false
	return depth == 0

## Why `expression` cannot be asked of the senses `reads` answers, or "" when
## it can. It is asked once, with the senses as they are, so that a name that
## is no sense, or an answer that is no answer, is a fault now rather than a
## way out that quietly never opens. Nothing short-circuits in an
## `Expression`, so one asking touches every name in it.
static func _try(expression: Expression, reads: Array[Callable]) -> String:
	var values := _read(reads)
	var answer = expression.execute(values, null, false, true)
	if expression.has_execute_failed():
		var why := expression.get_error_text()
		# Of a stray name, all the engine says is that there is no `self` to
		# look it up on. Asked again of something that writes down whatever it
		# is asked for, it says which.
		var probe := Unsensed.new()
		expression.execute(values, probe, false, true)
		if not probe.asked.is_empty():
			return "reads %s, which the owner does not sense" % probe.asked[0]
		if expression.has_execute_failed():
			why = expression.get_error_text()
		return "cannot be asked: " + why
	if not answer is bool:
		return "answers %s, not true or false" % type_string(typeof(answer))
	return ""

## The Callable a way out asks: `expression`, of the senses as they are now.
static func _asker(expression: Expression, reads: Array[Callable]) -> Callable:
	return func() -> bool:
		var answer = expression.execute(_read(reads), null, false, true)
		return answer is bool and answer

## What the senses say now, in the order they were named.
static func _read(reads: Array[Callable]) -> Array:
	var values := []
	for read in reads:
		values.append(read.call())
	return values

## Nothing, which writes down every name it is asked for.
class Unsensed extends RefCounted:
	var asked: Array = []

	func _get(property: StringName) -> Variant:
		asked.append(String(property))
		return null
