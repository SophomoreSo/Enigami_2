extends Node2D
## The player's state machine, and the tables it is read from.
##
## All of the machine is rows in the content database
## (`data/db/machines/player.sql`): the states, the steps each takes every
## frame, the graph of ways between them, and the conditions that open each
## way, written as questions about what the player senses. What `Player` keeps
## is the words those rows name — its actions and its senses. Four things can
## go wrong between the two and none says so at run time: a row can name an
## action or a sense the player does not have, a condition can be written so
## that it does not read, the graph can leave a state with no way in, and a
## split can add up to more or less than one. Each is a failure here, and so
## is a set of conditions that opens two ways at once, or none. What the
## schema refuses is tried against a scratch copy of it. Then a real player is
## stood up, to see that the machine it built is the one the table describes
## and that it moves on it.

const SRC := "res://data/db"
const SCRATCH := "user://machine_test.db"
const ACTIONS := ["brake", "run", "dash", "rush"]

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[MACHINE] PASS ", what)
	else:
		fails += 1
		push_error("MACHINE FAIL: " + what)

func phys(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func spawn(at: Vector2) -> Player:
	var p := Player.new()
	p.collision_layer = 2
	p.collision_mask = 1
	p.position = at
	add_child(p)
	return p

## Presses an action the way a player does, and lets the machine re-pick.
func press(action: String, hold: int = 3) -> void:
	Input.action_press(action)
	await phys(hold)
	Input.action_release(action)

func _ready() -> void:
	# --- the table ------------------------------------------------------------
	check(Db.available(), "the database opens (%s)" % Db.PATH)
	for table in ["machines", "states", "steps", "conditions", "transitions"]:
		check(Db.has_table(table), "there is a %s table" % table)
	var ids := Machine.ids()
	check(ids.has("player"), "the player has a machine (%s)" % str(ids))
	for id in ids:
		var found := Machine.problems(id)
		check(found.is_empty(), "the %s machine reads clean%s"
			% [id, "" if found.is_empty() else " — " + "; ".join(found)])
		var lost := _unreachable(Machine.source(id))
		check(lost.is_empty(), "every state of %s has a way in from its start%s"
			% [id, "" if lost.is_empty() else " — not " + ", ".join(lost)])
		var idle := _unasked(Machine.source(id))
		check(idle.is_empty(), "every condition of %s opens a way%s"
			% [id, "" if idle.is_empty() else " — not " + ", ".join(idle)])

	var src := Machine.source("player")
	var states: Dictionary = src.get("states", {})
	check(String(src.get("start", "")) == "idle" and states.size() == 3,
		"the player starts idle and has three states (%s, %d)" % [src.get("start", ""), states.size()])
	var labels: Array = []
	for sid in states:
		labels.append(String(states[sid].get("label", "")))
	check(labels == ["Idle", "Walk", "Dash"],
		"named Idle, Walk and Dash, in that order (%s)" % str(labels))
	var does := {}
	for sid in states:
		does[sid] = " ".join(states[sid].get("steps", []))
	check(does.get("idle") == "brake dash" and does.get("walk") == "run dash" and does.get("dash") == "rush",
		"each state takes its steps in order: brake or run, then dash — and a dash rushes (%s)" % str(does))
	var edges: Array = src.get("transitions", [])
	check(edges.size() == 6, "every state has a way into every other: six ways out (%d)" % edges.size())
	var pairs: Dictionary = {}
	for t in edges:
		pairs["%s>%s" % [t.get("from_id", ""), t.get("to_id", "")]] = true
	var complete := true
	for a in states:
		for b in states:
			if a != b and not pairs.has("%s>%s" % [a, b]):
				complete = false
	check(complete, "and no pair is missing")
	var out_of_idle: Array = []
	for t in edges:
		if String(t.get("from_id", "")) == "idle":
			out_of_idle.append(String(t.get("to_id", "")))
	check(out_of_idle == ["dash", "walk"],
		"the ways out of idle are asked dash first, then walk (%s)" % str(out_of_idle))
	var questions: Dictionary = src.get("conditions", {})
	check(questions.keys() == ["dashing", "walking", "standing"],
		"three conditions open them (%s)" % str(questions.keys()))

	# --- the checker catches what it is for -----------------------------------
	# Written out here rather than kept as broken rows in the database: these
	# are the mistakes a writer makes, and every one is silent at run time if
	# nothing goes looking.
	var base := {"id": "m", "start": "a",
		"states": {"a": {"label": "A", "steps": ["do_a"]}, "b": {"label": "B", "steps": ["do_b", "do_a"]}},
		"conditions": {"go": "ready", "back": "not ready and (a or b)"},
		"transitions": [
			{"from_id": "a", "position": 0, "to_id": "b", "condition": "go", "probability": 1.0},
			{"from_id": "b", "position": 0, "to_id": "a", "condition": "back", "probability": 1.0},
		]}
	check(Machine.problems_in(base).is_empty(), "a sound machine has no problems (%s)" % str(Machine.problems_in(base)))
	check(_caught(base, {"start": "zz"}, "start -> zz"), "a start that names no state is caught")
	check(_caught(base, {"transitions": [{"from_id": "a", "position": 0, "to_id": "zz", "condition": "go"}]}, "does not exist"),
		"a way to a state that does not exist is caught")
	check(_caught(base, {"transitions": [{"from_id": "zz", "position": 0, "to_id": "a", "condition": "go"}]}, "leaves a state"),
		"a way out of a state that does not exist is caught")
	check(_caught(base, {"transitions": [{"from_id": "a", "position": 0, "to_id": "b", "condition": ""}]}, "no condition"),
		"a way with no condition is caught")
	check(_caught(base, {"transitions": [{"from_id": "a", "position": 0, "to_id": "b", "condition": "away"}]}, "asks away, which is not a condition"),
		"a way asking a condition that is not written is caught")
	check(_caught(base, {"transitions": [{"from_id": "a", "position": 0, "to_id": "b", "condition": "go", "probability": 0.5}]}, "add up to 0.50"),
		"a split that does not add up to one is caught")
	check(_caught(base, {"transitions": [
			{"from_id": "a", "position": 0, "to_id": "b", "condition": "go", "probability": 0.5},
			{"from_id": "a", "position": 0, "to_id": "a", "condition": "back", "probability": 0.5}]}, "disagree"),
		"a split whose rows disagree on the condition is caught")
	check(_caught(base, {"states": {"a": {"label": "A", "steps": []}, "b": {"label": "B", "steps": ["do_b"]}}}, "a does nothing"),
		"a state with no steps is caught")
	check(_caught(base, {"states": {"a": {"label": "A", "steps": ["do_a", ""]}, "b": {"label": "B", "steps": ["do_b"]}}}, "a step of a names no action"),
		"a step that names no action is caught")
	check(_caught(base, {"conditions": {"go": " ", "back": "not ready"}}, "go says nothing"),
		"a condition that says nothing is caught")
	check(_caught(base, {"conditions": {"go": "ready and", "back": "not ready"}}, "go does not read"),
		"a condition cut off in the middle is caught")
	# Anywhere else these two would quietly be asked as the first half of
	# themselves: `ready` and `(ready)`.
	check(_caught(base, {"conditions": {"go": "ready steady", "back": "not ready"}}, "go does not read"),
		"a condition missing the word between two names is caught")
	check(_caught(base, {"conditions": {"go": "(ready) steady) or (go", "back": "not ready"}}, "brackets do not pair"),
		"and one whose brackets do not pair")
	check(Machine.problems_in({"start": "a", "states": {}}).has("no states"), "a machine with no states is caught")

	# --- what the schema refuses ------------------------------------------------
	# The build runs with foreign keys on and these same constraints, so what
	# is refused here is refused there.
	var db = _scratch()
	if db == null:
		check(false, "a scratch copy of the schema can be made to try it against")
	else:
		var m := "INSERT INTO machines (id, start) VALUES ('m', 'a')"
		var ab := "INSERT INTO states (machine_id, id, label) VALUES ('m', 'a', 'A'), ('m', 'b', 'B')"
		var steps := "INSERT INTO steps (machine_id, state_id, position, action) VALUES ('m', 'a', 0, 'do_a'), ('m', 'b', 0, 'do_b')"
		var asks := "INSERT INTO conditions (machine_id, id, expression) VALUES ('m', 'go', 'ready'), ('m', 'back', 'not ready')"
		var ways := "INSERT INTO transitions (machine_id, from_id, position, to_id, condition) VALUES ('m', 'a', 0, 'b', 'go'), ('m', 'b', 0, 'a', 'back')"
		check(_accepted(db, [m, ab, steps, asks, ways]), "a sound machine is accepted (%s)" % db.error_message)
		check(_accepted(db, [m, ab, steps, ways, asks]), "and its conditions may be written after the ways that ask them")
		check(not _accepted(db, [m, ab, steps, asks, ways.replace("'back')", "'away')")]),
			"a way asking a condition that is not written is refused when the build commits")
		check(not _accepted(db, [m, ab, steps.replace("('m', 'b', 0", "('m', 'zz', 0"), asks, ways]),
			"a step of a state that does not exist is refused")
		check(not _accepted(db, [m, ab, steps.replace("('m', 'b', 0", "('m', 'a', 0"), asks, ways]),
			"two steps in one position are refused")
		check(not _accepted(db, [m, ab, steps.replace("'do_b'", "''"), asks, ways]), "a step with no action is refused")
		check(not _accepted(db, [m, ab, steps, asks.replace("'not ready'", "'   '"), ways]), "a condition that says nothing is refused")
		check(not _accepted(db, [m, ab, steps, asks,
				ways + ", ('m', 'a', 0, 'a', 'back')"]), "the rows of one split asking different conditions are refused")
		db.close_db()
		DirAccess.remove_absolute(SCRATCH)

	# --- building it over an owner --------------------------------------------
	var actions := {}
	for a in ACTIONS:
		actions[a] = _nothing
	# The senses read from here, so the questions can be put to any of them.
	var world := {"dashing": false, "moving": false}
	var senses := {}
	for s in world:
		senses[s] = func(): return world[s]
	var whole := Machine.build("player", actions, senses)
	check(whole.faults.is_empty() and whole.states.size() == 3 and whole.conditions.size() == 3
			and whole.start == whole.states.get("idle"),
		"over an owner with every word, the whole machine is built (%s)" % str(whole.faults))
	# Exactly one holds, whatever the player senses: which is why the order a
	# state asks its ways in only says which is asked first, and why no state
	# is ever left with nowhere to be.
	var wrong: Array = []
	var tried := 0
	for dashing in [false, true]:
		for moving in [false, true]:
			world["dashing"] = dashing
			world["moving"] = moving
			var open: Array = []
			for cid in whole.conditions:
				if (whole.conditions[cid] as Callable).call():
					open.append(cid)
			tried += 1
			if open.size() != 1:
				wrong.append("%s: %s" % [str(world), str(open)])
	check(wrong.is_empty(), "exactly one of the conditions holds, whatever the player senses (%d of %d not%s)"
		% [wrong.size(), tried, "" if wrong.is_empty() else ": " + wrong[0]])

	var fewer := actions.duplicate()
	fewer.erase("rush")
	var short_one := Machine.build("player", fewer, senses)
	check(short_one.faults.size() == 1 and String(short_one.faults[0]).contains("dash does rush"),
		"a state taking a step the owner cannot is reported (%s)" % str(short_one.faults))
	check(short_one.states.size() == 2 and short_one.start != null, "and the rest is still built")
	var blind := senses.duplicate()
	blind.erase("moving")
	var unsure := Machine.build("player", actions, blind)
	check(unsure.faults.size() == 2 and String(unsure.faults[0]).contains("reads moving, which the owner does not sense"),
		"a condition reading a sense the owner does not have is reported, once for each (%s)" % str(unsure.faults))
	check(unsure.conditions.size() == 1 and unsure.states["idle"].next_nodes.size() == 1,
		"and the ways they open are left out: idle keeps dash alone (%d)" % unsure.states["idle"].next_nodes.size())
	var vague := senses.duplicate()
	vague["dashing"] = func(): return 1
	var unsettled := Machine.build("player", actions, vague)
	check(unsettled.faults.size() == 1 and String(unsettled.faults[0]).contains("answers int, not true or false"),
		"a condition that answers anything but true or false is reported (%s)" % str(unsettled.faults))
	var nobody := Machine.build("nobody", actions, senses)
	check(nobody.start == null and nobody.states.is_empty() and not nobody.faults.is_empty(),
		"a machine not in the table is one with nothing in it, and a problem (%s)" % str(nobody.faults))
	for built in [whole, short_one, unsure, unsettled]:
		built.cleanup()

	# --- and the real player runs on it ---------------------------------------
	var p := spawn(Vector2(300, 380))
	await phys(2)
	check(p.machine != null and p.machine.faults.is_empty(),
		"the player builds its machine with nothing unresolved (%s)" % str(p.machine.faults if p.machine != null else "no machine"))
	check(p.machine.states.size() == 3 and p.current_state == p.machine.states.get("idle"),
		"and stands in idle (%s)" % p.state_name())
	check(p.state_name() == "Idle", "which it calls Idle (%s)" % p.state_name())
	var wired := true
	for sid in p.machine.states:
		var node: FSMNode = p.machine.states[sid]
		wired = wired and node.steps.size() == (states[sid]["steps"] as Array).size() and node.next_nodes.size() == 2
		for step in node.steps:
			wired = wired and step.is_valid()
		for way in node.next_nodes:
			wired = wired and (way["condition"] as Callable).is_valid() and (way["destinations"] as Array).size() == 1
	check(wired, "every state takes all its steps, and has two certain ways out, each with a condition that answers")

	Input.action_press("move_right")
	await phys(6)
	check(p.state_name() == "Walk", "holding right walks (%s)" % p.state_name())
	Input.action_release("move_right")
	await phys(12)
	check(p.state_name() == "Idle", "letting go stands (%s)" % p.state_name())
	Input.action_press("move_up")
	await phys(6)
	check(p.state_name() == "Walk" and p.velocity.y < 0.0 and p.facing_name() == Actor.FACE_UP,
		"holding up walks up the screen, facing up (%s, %s)" % [p.state_name(), p.facing_name()])
	Input.action_release("move_up")
	await phys(12)
	# The press is seen on the physics frame after it, the dash starts inside
	# that frame's steps, and the state is re-picked at the top of the next.
	await press("dash", 2)
	await phys(2)
	check(p.state_name() == "Dash", "a dash is a Dash (%s)" % p.state_name())
	var came_back := false
	for i in 60:
		await phys(1)
		if p.state_name() == "Idle":
			came_back = true
			break
	check(came_back, "and over, the body stands again")

	print("[MACHINE] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

func _nothing() -> void:
	pass

## The states no path from the start reaches, by id.
func _unreachable(def: Dictionary) -> Array:
	var states: Dictionary = def.get("states", {})
	var out: Dictionary = {}
	for t in def.get("transitions", []):
		var from_id := String(t.get("from_id", ""))
		if not out.has(from_id):
			out[from_id] = []
		(out[from_id] as Array).append(String(t.get("to_id", "")))
	var seen := {}
	var open: Array = [String(def.get("start", ""))]
	while not open.is_empty():
		var at: String = open.pop_back()
		if at == "" or seen.has(at) or not states.has(at):
			continue
		seen[at] = true
		for to in out.get(at, []):
			open.append(to)
	var lost: Array = []
	for sid in states:
		if not seen.has(sid):
			lost.append(String(sid))
	return lost

## The conditions no way out asks, by id.
func _unasked(def: Dictionary) -> Array:
	var asked := {}
	for t in def.get("transitions", []):
		asked[String(t.get("condition", ""))] = true
	var idle: Array = []
	for cid in def.get("conditions", {}):
		if not asked.has(cid):
			idle.append(String(cid))
	return idle

## Whether checking `base` with `patch` laid over it, key by key, complains
## about `want`.
func _caught(base: Dictionary, patch: Dictionary, want: String) -> bool:
	var def := base.duplicate(true)
	for key in patch:
		def[key] = patch[key]
	for problem in Machine.problems_in(def):
		if String(problem).contains(want):
			return true
	return false

## A fresh database with the real schema in it, foreign keys on, or null.
func _scratch():
	if not ClassDB.class_exists("SQLite"):
		return null
	if FileAccess.file_exists(SCRATCH):
		DirAccess.remove_absolute(SCRATCH)
	var db = ClassDB.instantiate("SQLite")
	db.path = SCRATCH
	db.foreign_keys = true
	db.verbosity_level = 0
	if not db.open_db():
		push_error("MACHINE: could not open %s: %s" % [SCRATCH, db.error_message])
		return null
	var schema := FileAccess.get_file_as_string(SRC.path_join("schema.sql"))
	if schema == "" or not db.query(schema):
		push_error("MACHINE: the schema did not run: %s" % db.error_message)
		return null
	return db

## Whether `statements` go in and commit, the way build.sh commits them. What
## went in is taken out again afterwards, so every try starts from nothing.
func _accepted(db, statements: Array) -> bool:
	var ok: bool = db.query("BEGIN")
	for s in statements:
		ok = ok and db.query(s)
	ok = ok and db.query("COMMIT")
	if not ok:
		db.query("ROLLBACK")
		return false
	db.query("DELETE FROM machines")
	return true
