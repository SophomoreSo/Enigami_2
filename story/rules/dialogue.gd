class_name Dialogue
extends RefCounted

## Conversations, read from the content database (`Db`, `data/enigami.db`): a
## character is a row in `characters`, their lines in the box are rows in
## `nodes`, and a question's answers are rows in `choices`. What they say free
## is rows in `rules`, with the `criteria` and `changes` of each under it — see
## `FreeTalk` for how those are played. The tables, and how to write either
## kind of talk into them, are in `data/db/README.md`.
##
## The rules only use a line's `text`, where it leads (`next`, `choices`), who
## says it (`speaker`, `name`) and how fast it types (`speed`). Every other
## column a line carries — emotion, camera, sprite, sound — belongs to the
## picture and the sound bank. It is handed on here as it came out of the
## table, keyed by column name and never named in this file, which is what
## lets a writer add a new kind of direction as a column with no change to
## the rules.

## Who an NPC with no conversation of their own talks like.
const FALLBACK := "SAGE"
## A character column starting with this is what their lines say when a line
## does not say it itself: `line_voice` fills an empty `voice`. Any column, so
## a default a writer adds to the table is a default here without a change.
const LINE_DEFAULT := "line_"

static var _cache: Dictionary = {}
## The language `_cache` was read in. The words are laid over a conversation
## as it is read, so what was read in one language is no use in the next, and
## the first thing asked for after a change of language finds it forgotten —
## which is how `Loc` never has to know this file exists.
static var _cache_language := ""

## Every character with a conversation, by id.
static func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for r in Db.rows("SELECT id FROM characters ORDER BY id"):
		out.append(String(r["id"]))
	return out

## A character's conversation, ready to play: their row, with `nodes` under it
## by name and each question's `choices` in order, their free `rules` by name,
## the character's `line_` defaults filled into every line and rule that does
## not set them, and the words in the language being played. Read once and
## shared; treat it as read-only.
static func character(id: String) -> Dictionary:
	_forget_another_language()
	if _cache.has(id):
		return _cache[id]
	var def := source(id)
	if def.is_empty():
		if id == FALLBACK:
			return {}
		push_warning("Dialogue: nobody called '%s' in %s, talking like %s" % [id, Db.PATH, FALLBACK])
		return character(FALLBACK)
	_fill_defaults(def)
	_translate(def, id)
	_cache[id] = def
	return def

## A character as the database has them, in no language and with no defaults
## filled: the `characters` row, with `nodes` under it by name and each
## question's `choices` under its line, in order, and `rules` by name in the
## order they were written, each carrying its `criteria` and its `changes`. A
## column left NULL is a key that is not there. Empty when there is nobody by
## that id. Read fresh every call — `character` is the one to play.
static func source(id: String) -> Dictionary:
	var found := Db.records("characters", "id = ?", [id])
	if found.is_empty():
		return {}
	var def: Dictionary = found[0]
	var nodes: Dictionary = {}
	for node in Db.records("nodes", "character_id = ?", [id], "rowid"):
		nodes[String(node["id"])] = node
	for c in Db.records("choices", "character_id = ?", [id], "node_id, position"):
		var node = nodes.get(String(c["node_id"]), null)
		if node == null:
			continue
		if not node.has("choices"):
			node["choices"] = []
		(node["choices"] as Array).append(c)
	def["nodes"] = nodes
	var rules: Dictionary = {}
	for rule in Db.records("rules", "character_id = ?", [id], "rowid"):
		rule["criteria"] = []
		rule["changes"] = []
		rules[String(rule["id"])] = rule
	for table in ["criteria", "changes"]:
		for row in Db.records(table, "character_id = ?", [id], "rowid"):
			var rule = rules.get(String(row["rule_id"]), null)
			if rule != null:
				(rule[table] as Array).append(row)
	def["rules"] = rules
	return def

## Forgets what has been read, and lets `Db` go of the file, so a rebuilt
## database is picked up without a restart. A change of language needs no
## call: see `_cache_language`. `CutsceneScript.reload` is the same for scenes.
static func reload() -> void:
	_cache.clear()
	Facts.reload()
	FreeTalk.reload()
	Db.reopen()

static func _forget_another_language() -> void:
	if _cache_language != Loc.language:
		_cache.clear()
		_cache_language = Loc.language

## Mistakes in a character's conversation that would otherwise only show up
## as one cut short, and only for whoever took that path through it. The
## build refuses most of them already (`data/db/build.sh`); this is the same
## question asked of what the game actually read.
static func problems(id: String) -> Array:
	var def := source(id)
	if def.is_empty():
		return ["nobody called '%s' in %s" % [id, Db.PATH]]
	return problems_in(def)

## The same check against a conversation already in hand, in the shape
## `source` returns — so the checker itself can be put in front of a
## deliberately broken one without a broken row having to live in the
## database. A character is asked about the box if they have lines there or a
## `start`, about free talk if they have rules, and has a problem if neither.
static func problems_in(def: Dictionary) -> Array:
	var all = def.get("nodes", {})
	var rules = def.get("rules", {})
	var boxed: bool = _link(def.get("start", null)) != "" or (all is Dictionary and not all.is_empty())
	var talks_free: bool = rules is Dictionary and not rules.is_empty()
	if not boxed and not talks_free:
		return ["no lines"]
	var found: Array = []
	if boxed:
		found.append_array(_box_problems(def))
	if talks_free:
		found.append_array(_free_problems(def))
	return found

## The tree in the box: a start that names no line, a line with nothing to
## say, one leading to a line that is not there, and a question that also has
## a line after it.
static func _box_problems(def: Dictionary) -> Array:
	var found: Array = []
	var all = def.get("nodes", {})
	if not all is Dictionary or all.is_empty():
		return ["no lines"]
	if not all.has(String(def.get("start", ""))):
		found.append("start -> %s" % def.get("start", ""))
	for key in all:
		var node = all[key]
		if not node is Dictionary:
			found.append("%s is not a line" % key)
			continue
		if String(node.get("text", "")) == "":
			found.append("%s has no text" % key)
		var choices = node.get("choices", [])
		if not choices is Array:
			choices = []
		var links: Array = [node.get("next", "")]
		if not choices.is_empty() and _link(node.get("next", "")) != "":
			found.append("%s has both a next line and answers — the answers win" % key)
		for c in choices:
			if not c is Dictionary or String(c.get("text", "")) == "":
				found.append("%s has an answer with no text" % key)
				continue
			links.append(c.get("next", ""))
		for to in links:
			var name := _link(to)
			if name != "" and not all.has(name):
				found.append("%s -> %s" % [key, name])
	return found

## Free talk has no tree to walk, so it is asked something else: a rule with
## nothing to say, a `next` that names no rule, one with a `next` and an event
## to raise as well, an event raised that none of the character's own rules
## answers — which ends their talk there every time — and a rule nothing can
## reach, answering no event and nobody's `next`.
static func _free_problems(def: Dictionary) -> Array:
	var found: Array = []
	var rules: Dictionary = def.get("rules", {})
	var reached := {}
	var answered := {}
	for key in rules:
		var rule = rules[key]
		if not rule is Dictionary:
			continue
		var event := _link(rule.get("listens", null))
		if event != "":
			reached[key] = true
			answered[event] = true
		var next := _link(rule.get("next", null))
		if next != "":
			reached[next] = true
	for key in rules:
		var rule = rules[key]
		if not rule is Dictionary:
			found.append("%s is not a rule" % key)
			continue
		if String(rule.get("text", "")) == "":
			found.append("%s has no text" % key)
		var next := _link(rule.get("next", null))
		var raised := _link(rule.get("triggers", null))
		if next != "" and not rules.has(next):
			found.append("%s -> %s" % [key, next])
		if next != "" and raised != "":
			found.append("%s has both a next rule and an event to raise" % key)
		if raised != "" and not answered.has(raised):
			found.append("%s raises %s, which none of theirs answers" % [key, raised])
		if not reached.has(key):
			found.append("%s answers nothing, and nothing leads to it" % key)
	return found

## Where a `next` points, as a name — "" for none, however none was written.
static func _link(to) -> String:
	return "" if to == null else String(to)

## Lays the language's words over the database's own, from
## `localization/<lang>/dialogue/<id>.json`.
##
## Only the words move: what is said, the names on the tab and the answers on a
## question. Where a line leads, what the camera does and what it sounds like
## stay in the database, so a translator never touches the shape of a
## conversation and a writer never touches six languages. A line the language
## has not reached keeps what the database says, which is what lets a new
## conversation be written and played before any of it is translated.
static func _translate(def: Dictionary, id: String) -> void:
	var over := Loc.overlay("dialogue", id)
	if over.is_empty():
		return
	for k in ["name", "player_name"]:
		if over.has(k):
			def[k] = String(over[k])
	var nodes: Dictionary = def.get("nodes", {})
	var lines: Dictionary = over.get("nodes", {})
	for key in nodes:
		if not (nodes[key] is Dictionary) or not lines.has(key):
			continue
		var node: Dictionary = nodes[key]
		var line: Dictionary = lines[key]
		for k in ["text", "name"]:
			if line.has(k):
				node[k] = String(line[k])
		var answers: Array = line.get("choices", [])
		var choices: Array = node.get("choices", [])
		# Position for position: an answer the language has not reached keeps
		# the words in the database, and where each one leads is never touched.
		for i in mini(answers.size(), choices.size()):
			if choices[i] is Dictionary:
				(choices[i] as Dictionary)["text"] = String(answers[i])
	# Free talk the same way, rule by rule, and only ever its words.
	var rules: Dictionary = def.get("rules", {})
	var said: Dictionary = over.get("rules", {})
	for key in rules:
		var over_rule = said.get(key, null)
		if rules[key] is Dictionary and over_rule is Dictionary and over_rule.has("text"):
			(rules[key] as Dictionary)["text"] = String(over_rule["text"])

## A line says what its character usually says unless it says otherwise: for
## every `line_<key>` column of the character, a line — in the box or free —
## with no `<key>` gets it.
static func _fill_defaults(def: Dictionary) -> void:
	var lines: Array = (def.get("nodes", {}) as Dictionary).values()
	lines.append_array((def.get("rules", {}) as Dictionary).values())
	for col in def:
		var key := String(col)
		if not key.begins_with(LINE_DEFAULT):
			continue
		var k := key.trim_prefix(LINE_DEFAULT)
		for line in lines:
			if line is Dictionary and not (line as Dictionary).has(k):
				(line as Dictionary)[k] = def[col]
