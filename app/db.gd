extends Node

## The content database, `data/enigami.db`: what the game reads and never
## writes, kept as tables. The conversations, the player's state machine, the
## parts and the boards the game ships with, the menus, what grows on the
## rooms' floors and the light shining things give are in it today;
## whatever else is better kept as rows than as a file goes in beside them. It is built from
## the SQL under `data/db/` by the `build.sh` there — the README beside it has
## the tables and how to change them — and committed built, so nothing at run
## time needs anything but the file.
##
## This is the one script that names SQLite. A module asks for rows and gets
## dictionaries back:
##
##     Db.rows("SELECT id, name FROM characters WHERE id = ?", ["SAGE"])
##     Db.records("nodes", "character_id = ?", ["SAGE"], "rowid")
##
## The game writes to none of that. What a player makes for themselves and
## keeps is in a database of its own under `user://` — the maps they lay
## (`Maps`) — opened with `writable`, which asks the same way:
##
##     var mine = Db.writable("user://maps.db")
##     mine.run("INSERT INTO maps (id) VALUES (?)", ["keep"])
##
## It sits in `app/` for the reason `Loc` does: the rules name a character and
## a line, the picture reads that line's camera, and neither should have to
## know the words came out of a table. See ARCHITECTURE.md.
##
## **Every query falls back to nothing.** With the extension missing on a
## platform, or the file not shipped, a query answers with no rows and the
## reason is said once — so a build with no database plays with nobody to
## talk to, rather than crashing at the first NPC.

const PATH := "res://data/enigami.db"
## The tables this build of the game reads. `data/db/schema.sql` writes the
## same number into `meta`, and `tests/story/dialogue_test` holds the two
## together, so a schema changed on one side is a failing test and not a
## conversation that reads as empty.
const SCHEMA_VERSION := 18

enum State { CLOSED, OPEN, FAILED }

## The connection, untyped on purpose: `SQLite` is an extension class, and a
## script that named it would not parse on a platform without the library.
var _db = null
var _state := State.CLOSED
var _columns: Dictionary = {}   ## table -> what PRAGMA table_info says of it

## Whether there is a database to ask. Opens it on the first call.
func available() -> bool:
	return _open()

## The rows `sql` selects, each a Dictionary keyed by column name, with SQL
## NULL as null. `bindings` fill the `?`s in order and are never spliced in as
## text, so a line with a quote in it is just a line.
func rows(sql: String, bindings: Array = []) -> Array:
	if not _open():
		return []
	if not _db.query_with_bindings(sql, bindings):
		push_error("Db: %s\n   in: %s" % [_db.error_message, sql])
		return []
	return _db.query_result

## The first row `sql` selects, or {}.
func row(sql: String, bindings: Array = []) -> Dictionary:
	var all := rows(sql, bindings)
	return all[0] if not all.is_empty() else {}

## The first column of the first row, or `fallback` — for a count, a name, a
## setting.
func value(sql: String, bindings: Array = [], fallback = null):
	var r := row(sql, bindings)
	if r.is_empty():
		return fallback
	var v = r.values()[0]
	return fallback if v == null else v

## The rows of `table` as content — what a file would have held:
##
##   * A NULL is left out, so a line with no `sfx` has no `sfx` key rather
##     than a null one, and `node.get("sfx", "")` reads it the way it always
##     did.
##   * A column declared JSON comes out parsed — a Dictionary, an Array, a
##     String — or, when its text is not JSON, as that text: a `camera` is a
##     framing or the word `reset`, exactly as it was in the file. A number
##     SQLite kept as a number is already what parsing it would give, and
##     comes out as it is: an effect's `8` or `1.6`.
##
## `where` and `order` are SQL the caller writes; `bindings` fill the `?`s in
## `where`. Keys are Strings, whatever the extension hands back.
func records(table: String, where: String = "", bindings: Array = [], order: String = "") -> Array:
	var sql := "SELECT * FROM " + table
	if where != "":
		sql += " WHERE " + where
	if order != "":
		sql += " ORDER BY " + order
	var json := json_columns(table)
	var out: Array = []
	for r in rows(sql, bindings):
		var rec := {}
		for col in r:
			var v = r[col]
			if v == null:
				continue
			var key := String(col)
			if json.has(key) and v is String:
				# An instance parse rather than JSON.parse_string, which logs
				# an engine error for text that is not JSON — and `reset` is
				# not, on purpose.
				var json_doc := JSON.new()
				if json_doc.parse(String(v)) == OK:
					v = json_doc.data
			rec[key] = v
		out.append(rec)
	return out

## The columns of `table` as `PRAGMA table_info` describes them — `name`,
## `type` as declared, `notnull`, `dflt_value`, `pk` — or nothing for no such
## table. Asked once per table and remembered until `reopen`.
func columns(table: String) -> Array:
	if not _columns.has(table):
		_columns[table] = rows("PRAGMA table_info(%s)" % table)
	return _columns[table]

## The columns of `table` declared JSON, which `records` parses.
func json_columns(table: String) -> PackedStringArray:
	var out := PackedStringArray()
	for c in columns(table):
		if String(c.get("type", "")).to_upper() == "JSON":
			out.append(String(c["name"]))
	return out

func has_table(table: String) -> bool:
	return int(value("SELECT count(*) FROM sqlite_master WHERE type = 'table' AND name = ?", [table], 0)) > 0

## What `meta` says under `key` — `schema_version`, `source_hash` — or
## `fallback` when it says nothing.
func meta(key: String, fallback: String = "") -> String:
	return String(value("SELECT value FROM meta WHERE key = ?", [key], fallback))

## Lets go of the file and forgets what it knew of the tables, so the next
## question opens whatever is there now. `data/db/build.sh` puts a new file in
## place, and a handle on the old one would go on reading the old lines;
## `Dialogue.reload` calls this for that reason.
func reopen() -> void:
	_close()
	_columns.clear()
	_state = State.CLOSED

func _open() -> bool:
	if _state != State.CLOSED:
		return _state == State.OPEN
	if not ClassDB.class_exists("SQLite"):
		_state = State.FAILED
		push_error("Db: the SQLite extension is not loaded, so %s cannot be read — see addons/godot-sqlite/README.md" % PATH)
		return false
	if not FileAccess.file_exists(PATH):
		_state = State.FAILED
		push_error("Db: nothing at %s — run data/db/build.sh, and see that the export includes data/*.db" % PATH)
		return false
	_db = ClassDB.instantiate("SQLite")
	_db.path = PATH
	# Read-only is not a preference: it is what lets the file be read out of
	# the .pck, through the extension's own VFS, on every platform alike.
	_db.read_only = true
	_db.verbosity_level = 0
	if not _db.open_db():
		_state = State.FAILED
		push_error("Db: could not open %s: %s" % [PATH, _db.error_message])
		_db = null
		return false
	_state = State.OPEN
	return true

func _close() -> void:
	if _db != null:
		_db.close_db()
		_db = null

## A database the game writes, at `path` — under `user://`, the player's own —
## made there on the first question if it is not there yet. Null where SQLite
## cannot be had, which is a store with nothing in it to whoever asks.
func writable(path: String) -> RefCounted:
	if not ClassDB.class_exists("SQLite"):
		return null
	return Writable.new(path)

## A connection to one of those, asked the way `Db` is asked: `rows` for what a
## query selects, and `run` for a change, which says whether it went through.
## Foreign keys are on, so a row cascades away with what it hangs off.
class Writable extends RefCounted:
	var path: String
	var _db = null

	func _init(at: String) -> void:
		path = at

	func rows(sql: String, bindings: Array = []) -> Array:
		if not _open():
			return []
		if not _db.query_with_bindings(sql, bindings):
			push_error("Db: %s\n   in: %s\n   at: %s" % [_db.error_message, sql, path])
			return []
		return _db.query_result

	func run(sql: String, bindings: Array = []) -> bool:
		if not _open():
			return false
		if not _db.query_with_bindings(sql, bindings):
			push_error("Db: %s\n   in: %s\n   at: %s" % [_db.error_message, sql, path])
			return false
		return true

	func close() -> void:
		if _db != null:
			_db.close_db()
			_db = null

	func _open() -> bool:
		if _db != null:
			return true
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		_db = ClassDB.instantiate("SQLite")
		_db.path = path
		_db.verbosity_level = 0
		if not _db.open_db():
			push_error("Db: could not open %s: %s" % [path, _db.error_message])
			_db = null
			return false
		_db.query("PRAGMA foreign_keys = ON;")
		return true

func _exit_tree() -> void:
	_close()
