extends Node
## The conversations database, and the format it is written in.
##
## Every conversation is rows in `data/enigami.db`, built from the SQL under
## `data/db/` by the `build.sh` there. Three things can go wrong between the
## two, and none of them says so at run time: the extension that reads the
## file can fail to load on a platform, the file can be a build of older SQL
## than the SQL now beside it, and a tree can be written so that a line leads
## nowhere. Each is a failure here. Then what the schema promises to refuse is
## tried against a scratch copy of it, so the promise is checked rather than
## believed — the real file is read-only, as it should be.
##
## No renderer needed: nothing here draws. The refusals print an `SQL error`
## line each from the extension, which is the point of them.

const SRC := "res://data/db"
const SCRATCH := "user://dialogue_test.db"

var fails := 0
## The last rowids of the facts and events the schema itself declares.
var _schema_facts := 0
var _schema_events := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[DIALOGUE] PASS ", what)
	else:
		fails += 1
		push_error("DIALOGUE FAIL: " + what)

func _ready() -> void:
	# --- the door -------------------------------------------------------------
	check(ClassDB.class_exists("SQLite"), "the SQLite extension is loaded (addons/godot-sqlite)")
	check(Db.available(), "the database opens (%s)" % Db.PATH)
	check(Db.meta("schema_version") == str(Db.SCHEMA_VERSION),
		"the database is at the schema the code reads (file says %s, code says %d)"
			% [Db.meta("schema_version"), Db.SCHEMA_VERSION])
	for table in ["meta", "emotions", "voices", "characters", "nodes", "choices",
			"facts", "events", "rules", "criteria", "changes"]:
		check(Db.has_table(table), "there is a %s table" % table)
	check(Db.json_columns("nodes").has("camera"), "a line's camera is a JSON column")
	check(Db.json_columns("events").has("match"), "and so is what an event asks of its cue")

	# --- it is the build of the sources beside it -----------------------------
	var built := Db.meta("source_hash")
	var now := _source_hash()
	check(built == now,
		"enigami.db is the build of the .sql under data/db as they are now — run data/db/build.sh (built from %s, sources are %s)"
			% [built.left(12), now.left(12)])

	# --- every conversation ---------------------------------------------------
	var ids := Dialogue.ids()
	check(ids.has("SAGE"), "the SAGE has a conversation (%s)" % str(ids))
	for id in ids:
		var found := Dialogue.problems(id)
		check(found.is_empty(), "%s's conversation reads clean%s"
			% [id, "" if found.is_empty() else " — " + "; ".join(found)])
		var lost := _unreachable(Dialogue.source(id))
		check(lost.is_empty(), "every one of %s's lines can be reached from the start%s"
			% [id, "" if lost.is_empty() else " — not " + ", ".join(lost)])

	# --- read the way the file was read ---------------------------------------
	var sage := Dialogue.source("SAGE")
	var nodes: Dictionary = sage.get("nodes", {})
	check(String(sage.get("start", "")) == "hello" and nodes.size() == 9,
		"the SAGE opens on hello and has nine lines (%s, %d)" % [sage.get("start", ""), nodes.size()])
	check(String(sage.get("name", "")) == "Old Tinker" and String(sage.get("sprite", "")) == "wizzard_m",
		"and is the Old Tinker, drawn as wizzard_m")
	var hello: Dictionary = nodes.get("hello", {})
	var cam = hello.get("camera", null)
	check(cam is Dictionary and String(cam.get("focus", "")) == "both" and is_equal_approx(float(cam.get("zoom", 0.0)), 1.5),
		"a camera framing comes out of its JSON column as the dictionary the picture reads (%s)" % str(cam))
	var bye_cam = nodes.get("bye", {}).get("camera", null)
	check(bye_cam is String and bye_cam == "reset", "and the word reset comes out as the word (%s)" % str(bye_cam))
	check(not hello.has("speed") and not hello.has("voice") and not hello.has("name") and not hello.has("sprite"),
		"a column left NULL is a key that is not there")
	check(String(hello.get("next", "")) == "ask" and String(hello.get("sfx", "")) == "pickup",
		"and one set is there as it was written")
	var answers: Array = nodes.get("ask", {}).get("choices", [])
	var texts: Array = []
	for a in answers:
		texts.append(String(a.get("text", "")))
	check(answers.size() == 4 and texts[0] == "How do skills work?" and texts[3] == "Nothing. Bye."
			and String(answers[0].get("next", "")) == "circuits" and not answers[3].has("next"),
		"a question's answers come out in order, and one with nothing next ends the conversation (%s)" % str(texts))
	check(not nodes.get("circuits", {}).has("choices"), "a plain line has no answers")

	var played := Dialogue.character("SAGE")
	var lines: Dictionary = played.get("nodes", {})
	var first: Dictionary = lines.get("hello", {})
	check(String(first.get("speaker", "")) == "npc" and String(first.get("voice", "")) == "low"
			and int(first.get("speed", 0)) == 45,
		"the character's line_ defaults fill a line that does not say (%s)" % str(first))
	check(String(first.get("emotion", "")) == "happy" and String(lines.get("circuits", {}).get("emotion", "")) == "neutral",
		"an emotion a line sets stays, one it does not is the character's usual")
	var reply: Dictionary = lines.get("danger_reply", {})
	check(String(reply.get("speaker", "")) == "player" and String(reply.get("voice", "")) == "high"
			and int(lines.get("charge", {}).get("speed", 0)) == 55,
		"and a line that says keeps its own")

	# --- the checker catches what it is for -----------------------------------
	# Written out here rather than kept as broken rows in the database: these
	# are the mistakes a writer makes, and every one of them is silent at run
	# time if nothing goes looking.
	var base := {"id": "X", "start": "a", "nodes": {
		"a": {"id": "a", "text": "hi", "next": "b"},
		"b": {"id": "b", "text": "bye", "choices": [{"text": "ok", "next": "a"}, {"text": "no"}]},
	}}
	check(Dialogue.problems_in(base).is_empty(), "a sound tree has no problems (%s)" % str(Dialogue.problems_in(base)))
	check(_caught(base, {"start": "nowhere"}, "start -> nowhere"), "a start that names no line is caught")
	check(_caught(base, {"nodes": {"a": {"text": "hi", "next": "c"}}}, "a -> c"), "a line leading nowhere is caught")
	check(_caught(base, {"nodes": {"a": {"text": "", "next": "b"}}}, "a has no text"), "a line with nothing to say is caught")
	check(_caught(base, {"nodes": {"b": {"text": "bye", "choices": [{"text": ""}]}}}, "answer with no text"),
		"an answer with nothing to say is caught")
	check(_caught(base, {"nodes": {"b": {"text": "bye", "choices": [{"text": "ok", "next": "zz"}]}}}, "b -> zz"),
		"an answer leading nowhere is caught")
	check(_caught(base, {"nodes": {"b": {"text": "bye", "next": "a", "choices": [{"text": "ok"}]}}}, "both"),
		"a question that also has a next is caught")
	check(Dialogue.problems_in({"start": "a", "nodes": {}}).has("no lines"), "a conversation with no lines is caught")

	# --- what the schema refuses ----------------------------------------------
	# The build runs with foreign keys on and these same constraints, so what
	# is refused here is refused there.
	var db = _scratch()
	if db == null:
		check(false, "a scratch copy of the schema can be made to try it against")
	else:
		var person := "INSERT INTO characters (id, name, sprite, start) VALUES ('X', 'X', 'knight_m', 'a')"
		var a := "INSERT INTO nodes (character_id, id, text, next) VALUES ('X', 'a', 'hi', 'b')"
		var b := "INSERT INTO nodes (character_id, id, text, camera) VALUES ('X', 'b', 'bye', 'reset')"
		var answer := "INSERT INTO choices (character_id, node_id, position, text, next) VALUES ('X', 'b', 0, 'ok', NULL)"
		check(_accepted(db, [person, a, b, answer]), "a sound conversation is accepted (%s)" % db.error_message)
		check(not _accepted(db, [person, a]), "a line that leads to no line is refused when the build commits")
		check(not _accepted(db, [person, b]), "a start that names no line is refused")
		check(not _accepted(db, [person, a, b, answer.replace("NULL", "'zz'")]), "an answer leading nowhere is refused")
		check(not _accepted(db, [person, a.replace("'hi'", "''"), b]), "a line with nothing to say is refused")
		check(not _accepted(db, [person, a.replace("text, next", "text, emotion, next").replace("'hi', 'b'", "'hi', 'hapy', 'b'"), b]),
			"an emotion nobody draws is refused")
		check(not _accepted(db, [person, a.replace("text, next", "text, voice, next").replace("'hi', 'b'", "'hi', 'loud', 'b'"), b]),
			"a voice nobody has is refused")
		check(not _accepted(db, [person, a.replace("text, next", "text, speaker, next").replace("'hi', 'b'", "'hi', 'narrator', 'b'"), b]),
			"a speaker who is neither the npc nor the player is refused")
		check(not _accepted(db, [person, a, b.replace("'reset'", "'{\"focus\": both}'")]), "a camera that is neither JSON nor reset is refused")
		check(not _accepted(db, [person.replace("'X', 'X'", "'x', 'X'"), a.replace("'X'", "'x'"), b.replace("'X'", "'x'")]),
			"a character id that is not upper case is refused")
		check(not _accepted(db, [person, a, b, answer, answer.replace("'ok'", "'again'")]), "two answers in one position are refused")

		# Free talk. The first is sound, and every one after it breaks it once.
		var talker := "INSERT INTO characters (id, name, sprite) VALUES ('Y', 'Y', 'elf_m')"
		var said := "INSERT INTO rules (character_id, id, listens, text) VALUES ('Y', 'r', 'talk', 'hi')"
		var knows := "INSERT INTO facts (id, scope) VALUES ('y_seen', 'visit')"
		var asks := "INSERT INTO criteria (character_id, rule_id, fact, op, value) VALUES ('Y', 'r', 'raids', '>=', 1)"
		var does := "INSERT INTO changes (character_id, rule_id, fact, op, value) VALUES ('Y', 'r', 'y_seen', 'set', 1)"
		check(_accepted(db, [talker, said, knows, asks, does]),
			"a character with no box, who only talks free, is accepted (%s)" % db.error_message)
		check(not _accepted(db, [talker, "INSERT INTO nodes (character_id, id, text) VALUES ('Y', 'a', 'hi')"]),
			"a line in the box for somebody with no start is refused")
		check(not _accepted(db, [talker, said.replace("'talk'", "'tlak'")]), "a rule answering an event nobody declared is refused")
		check(not _accepted(db, [talker, said, asks.replace("'raids'", "'raid'")]),
			"a criterion on a fact nobody declared is refused when the build commits")
		check(not _accepted(db, [talker, said, asks.replace("'>='", "'=>'")]), "a comparison that is not one is refused")
		check(not _accepted(db, [talker, said, asks.replace(", 1)", ", 'one')")]),
			"a criterion that is not a whole number is refused")
		check(not _accepted(db, [talker, said, does.replace("'y_seen'", "'raids'")]), "a change to what the game counts is refused")
		check(not _accepted(db, [talker, said, knows.replace("'visit'", "'forever'")]), "a scope that is not one is refused")
		check(not _accepted(db, [talker, said.replace("text)", "text, next)").replace("'hi')", "'hi', 'gone')")]),
			"a rule whose next is no rule is refused when the build commits")
		check(not _accepted(db, [talker, said.replace("text)", "text, next, triggers)").replace("'hi')", "'hi', 'r', 'talk')")]),
			"a rule with both a next rule and an event to raise is refused")
		check(not _accepted(db, [talker, said.replace("text)", "text, once)").replace("'hi')", "'hi', 2)")]),
			"once is yes or no")
		check(not _accepted(db, [talker, said, "INSERT INTO facts (id, scope) VALUES ('talk', 'save')"]),
			"a fact named for an event is refused: a name means one thing")
		check(not _accepted(db, ["INSERT INTO events (id, cue, match) VALUES ('x_moment', 'jump', '[1]')"]),
			"an event whose match is not an object is refused")
		check(not _accepted(db, ["INSERT INTO events (id, match) VALUES ('x_moment', '{\"kind\": \"air\"}')"]),
			"an event that matches a cue it does not name is refused")
		db.close_db()
		DirAccess.remove_absolute(SCRATCH)

	print("[DIALOGUE] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## The hash `data/db/build.sh` writes into `meta` as `source_hash`: for
## schema.sql and then every .sql in the folders beside it in byte order, the
## path relative to data/db and the file's sha256, a line each, hashed again.
## Change one, change both.
func _source_hash() -> String:
	var rels: Array = ["schema.sql"]
	var rest: Array = []
	for sub in DirAccess.get_directories_at(SRC):
		_collect_sql(SRC.path_join(sub), sub, rest)
	rest.sort()
	rels.append_array(rest)
	var listing := ""
	for rel in rels:
		listing += "%s\n%s\n" % [rel, FileAccess.get_sha256(SRC.path_join(rel))]
	return listing.sha256_text()

func _collect_sql(dir: String, rel: String, out: Array) -> void:
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() == "sql":
			out.append(rel + "/" + file)
	for sub in DirAccess.get_directories_at(dir):
		_collect_sql(dir.path_join(sub), rel + "/" + sub, out)

## The lines no path from the start reaches, by name.
func _unreachable(def: Dictionary) -> Array:
	var nodes: Dictionary = def.get("nodes", {})
	var seen := {}
	var open: Array = [String(def.get("start", ""))]
	while not open.is_empty():
		var at: String = open.pop_back()
		if at == "" or seen.has(at) or not nodes.has(at):
			continue
		seen[at] = true
		var node: Dictionary = nodes[at]
		open.append(String(node.get("next", "")))
		for c in node.get("choices", []):
			open.append(String(c.get("next", "")))
	var lost: Array = []
	for key in nodes:
		if not seen.has(key):
			lost.append(String(key))
	return lost

## Whether checking `base` with `patch` laid over it — a node in the patch
## replaces the node of that name whole — complains about `want`.
func _caught(base: Dictionary, patch: Dictionary, want: String) -> bool:
	var def := base.duplicate(true)
	for key in patch:
		if key == "nodes":
			for name in patch["nodes"]:
				def["nodes"][name] = patch["nodes"][name]
		else:
			def[key] = patch[key]
	for problem in Dialogue.problems_in(def):
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
		push_error("DIALOGUE: could not open %s: %s" % [SCRATCH, db.error_message])
		return null
	var schema := FileAccess.get_file_as_string(SRC.path_join("schema.sql"))
	if schema == "" or not db.query(schema):
		push_error("DIALOGUE: the schema did not run: %s" % db.error_message)
		return null
	# What the schema declares itself, which every try leaves standing.
	db.query("SELECT (SELECT max(rowid) FROM facts) AS facts, (SELECT max(rowid) FROM events) AS events")
	_schema_facts = int(db.query_result[0]["facts"])
	_schema_events = int(db.query_result[0]["events"])
	return db

## Whether `statements` go in and commit, the way build.sh commits them. What
## went in is taken out again afterwards, so every try starts from nothing —
## the facts and events a try declared as well, since a rule declares a fact
## of its own and the next try would find it already there.
func _accepted(db, statements: Array) -> bool:
	var ok: bool = db.query("BEGIN")
	for s in statements:
		ok = ok and db.query(s)
	ok = ok and db.query("COMMIT")
	if not ok:
		db.query("ROLLBACK")
		return false
	db.query("DELETE FROM characters")
	db.query("DELETE FROM facts WHERE rowid > %d" % _schema_facts)
	db.query("DELETE FROM events WHERE rowid > %d" % _schema_events)
	return true
