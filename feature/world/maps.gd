class_name Maps
extends RefCounted

## The maps made in the map creator (`MapMaker`), kept as rows: each map's
## level info, its layers, and each layer's grid of cells, a row of the grid
## a row — the `maps`, `map_layers` and `map_rows` tables (data/db/schema.sql).
## A map comes out as a `MadeRoom` (`load_room`) and goes in as one (`save`).
## What is in one is data/db/README.md's **A map**.
##
## Two places hold them. The ones the game ships with are in the content
## database (`Db`), built from `data/db/maps/*.sql`, which the game only reads.
## The ones made on this machine are in `user://maps.db`, beside the save, which
## it writes: SAVE puts a map there, and one there stands in front of a shipped
## one under its name. Run from the project — the editor, or `godot --path` —
## SAVE also writes the map out as `data/db/maps/<id>.sql`, for `build.sh` to
## build into the content database and for it to ship.

## The player's own maps.
const MINE := "user://maps.db"
## Where a map is written out as SQL, run from the project.
const SOURCE_DIR := "res://data/db/maps"
## The most letters a map's name is kept to.
const ID_LENGTH := 24
## A map's layers, the floor plan first: a layer's place here is its `level`.
const LAYERS := ["plan", "dressing"]

## The tables of `MINE`, as schema.sql has them, made there the first time it
## is opened. Kept the same as schema.sql's: `tests/feature/map_maker_test`
## holds the two together.
const TABLES := [
	"""CREATE TABLE IF NOT EXISTS maps (
	id      TEXT PRIMARY KEY CHECK (id <> '' AND id = lower(id)),
	tileset TEXT NOT NULL DEFAULT '',
	region  INTEGER NOT NULL DEFAULT 0 CHECK (region BETWEEN 0 AND 3),
	width   INTEGER NOT NULL CHECK (width >= 1),
	height  INTEGER NOT NULL CHECK (height >= 1)
)""",
	"""CREATE TABLE IF NOT EXISTS map_layers (
	map_id    TEXT NOT NULL REFERENCES maps (id) ON DELETE CASCADE,
	layer     TEXT NOT NULL CHECK (layer IN ('plan', 'dressing')),
	level     INTEGER NOT NULL,
	reference TEXT CHECK (reference IS NULL OR reference <> ''),
	PRIMARY KEY (map_id, layer)
)""",
	"""CREATE TABLE IF NOT EXISTS map_rows (
	map_id TEXT NOT NULL,
	layer  TEXT NOT NULL,
	y      INTEGER NOT NULL CHECK (y >= 0),
	cells  TEXT NOT NULL,
	PRIMARY KEY (map_id, layer, y),
	FOREIGN KEY (map_id, layer) REFERENCES map_layers (map_id, layer) ON DELETE CASCADE
)""",
]

## Somewhere else to keep the player's maps, in place of `MINE`, and nothing
## shipped looked at: a test's scratch folder, which a `maps.db` goes into.
static var scratch_dir: String = ""

static var _mine = null
static var _mine_at := ""

## Whether this run may write into the project's own folder.
static func in_project() -> bool:
	return OS.has_feature("editor")

## Where the maps made on this machine are kept.
static func store_path() -> String:
	return scratch_dir.path_join("maps.db") if scratch_dir != "" else MINE

## The name a map is filed under, from one as it was typed: lower case, letters
## and digits, with an underscore for each run of anything set between them.
## "" for a name with nothing in it to keep.
static func id_for(typed: String) -> String:
	var out := ""
	for ch in typed.strip_edges().to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
		elif out != "" and not out.ends_with("_"):
			out += "_"
	return out.left(ID_LENGTH).trim_suffix("_")

## Every map there is, by id, in order.
static func ids() -> PackedStringArray:
	var found := {}
	for r in _ask_mine("SELECT id FROM maps"):
		found[String(r["id"])] = true
	for r in _ask_shipped("SELECT id FROM maps"):
		found[String(r["id"])] = true
	var out := PackedStringArray(found.keys())
	out.sort()
	return out

## Where the map `id` is kept: the player's own database, or the content
## database it shipped in — or "" when there is none by that name.
static func path_of(id: String) -> String:
	if id == "":
		return ""
	if not _ask_mine("SELECT id FROM maps WHERE id = ?", [id]).is_empty():
		return store_path()
	if not _ask_shipped("SELECT id FROM maps WHERE id = ?", [id]).is_empty():
		return Db.PATH
	return ""

static func exists(id: String) -> bool:
	return path_of(id) != ""

## Keeps `room` as the map `id`, in the player's own database, over whatever
## was kept there under that name — all of it or none of it. Run from the
## project, it is written out as SQL too (`sql_for`).
static func save(id: String, room: MadeRoom) -> Error:
	if id == "" or id != id_for(id) or room == null or room.plan.is_empty():
		return ERR_INVALID_PARAMETER
	var mine = _store(true)
	if mine == null or not mine.run("BEGIN"):
		return ERR_CANT_OPEN
	var wide := 0
	for row in room.plan:
		wide = maxi(wide, row.length())
	var ok: bool = mine.run("DELETE FROM maps WHERE id = ?", [id]) \
		and mine.run("INSERT INTO maps (id, tileset, region, width, height) VALUES (?, ?, ?, ?, ?)",
			[id, room.tileset, room.region, wide, room.plan.size()])
	for level in LAYERS.size():
		var layer := String(LAYERS[level])
		var picture = room.references.get(layer, null)
		ok = ok and mine.run("INSERT INTO map_layers (map_id, layer, level, reference) VALUES (?, ?, ?, ?)",
			[id, layer, level, picture if picture is String and picture != "" else null])
		var grid := _grid(room, layer)
		for y in grid.size():
			ok = ok and mine.run("INSERT INTO map_rows (map_id, layer, y, cells) VALUES (?, ?, ?, ?)",
				[id, layer, y, grid[y]])
	if not ok:
		mine.run("ROLLBACK")
		return ERR_FILE_CANT_WRITE
	if not mine.run("COMMIT"):
		mine.run("ROLLBACK")
		return ERR_FILE_CANT_WRITE
	if in_project() and scratch_dir == "":
		_write_source(id, room)
	return OK

## The map `id` as a room of its own, not yet in the tree and not yet stood
## (`MadeRoom.stand`) — or null when there is no such map. Read again each
## time: a map saved over while the game runs is the map that comes back.
static func load_room(id: String) -> MadeRoom:
	if id == "":
		return null
	var from := "mine"
	var level := _ask_mine("SELECT * FROM maps WHERE id = ?", [id])
	if level.is_empty():
		from = "shipped"
		level = _ask_shipped("SELECT * FROM maps WHERE id = ?", [id])
	if level.is_empty():
		return null
	var room := MadeRoom.new()
	room.name = id.to_pascal_case()
	room.tileset = String(level[0].get("tileset", ""))
	room.region = int(level[0].get("region", 0))
	for l in _ask(from, "SELECT layer, reference FROM map_layers WHERE map_id = ?", [id]):
		if l.get("reference") != null:
			room.references[String(l["layer"])] = String(l["reference"])
	var grids := {}
	for layer in LAYERS:
		grids[layer] = []
	for r in _ask(from, "SELECT layer, cells FROM map_rows WHERE map_id = ? ORDER BY layer, y", [id]):
		if grids.has(String(r["layer"])):
			(grids[String(r["layer"])] as Array).append(String(r["cells"]))
	room.dressing = PackedStringArray(grids["dressing"])
	room.plan = PackedStringArray(grids["plan"])
	return room

## Throws the map `id` away, where this run may: out of the player's own
## database, and run from the project its SQL as well. A map the game shipped
## with is not this run's to remove.
static func remove(id: String) -> Error:
	if id == "" or _ask_mine("SELECT id FROM maps WHERE id = ?", [id]).is_empty():
		return ERR_FILE_NOT_FOUND
	if not _store().run("DELETE FROM maps WHERE id = ?", [id]):
		return ERR_FILE_CANT_WRITE
	if in_project() and scratch_dir == "":
		var source := SOURCE_DIR.path_join("%s.sql" % id)
		if FileAccess.file_exists(source):
			DirAccess.remove_absolute(source)
	return OK

## The map `id` as the SQL that builds it into the content database: its level,
## its layers and every row of every grid, in the file `build.sh` reads.
static func sql_for(id: String, room: MadeRoom) -> String:
	var wide := 0
	for row in room.plan:
		wide = maxi(wide, row.length())
	var out := "-- The map `%s`, as the map creator saved it (feature/world/maps.gd).\n" % id
	out += "-- What is in one is data/db/README.md's **A map**.\n\n"
	out += "INSERT INTO maps (id, tileset, region, width, height) VALUES\n"
	out += "\t(%s, %s, %d, %d, %d);\n\n" % [_q(id), _q(room.tileset), room.region, wide, room.plan.size()]
	var layers: Array = []
	for level in LAYERS.size():
		var layer := String(LAYERS[level])
		var picture = room.references.get(layer, null)
		layers.append("\t(%s, %s, %d, %s)" % [_q(id), _q(layer), level,
			_q(picture) if picture is String and picture != "" else "NULL"])
	out += "INSERT INTO map_layers (map_id, layer, level, reference) VALUES\n%s;\n" % ",\n".join(layers)
	for layer in LAYERS:
		var grid := _grid(room, String(layer))
		var lines: Array = []
		for y in grid.size():
			lines.append("\t(%s, %s, %d, %s)" % [_q(id), _q(String(layer)), y, _q(grid[y])])
		out += "\n-- %s\nINSERT INTO map_rows (map_id, layer, y, cells) VALUES\n%s;\n" % [layer, ",\n".join(lines)]
	return out

static func _write_source(id: String, room: MadeRoom) -> void:
	DirAccess.make_dir_recursive_absolute(SOURCE_DIR)
	var f := FileAccess.open(SOURCE_DIR.path_join("%s.sql" % id), FileAccess.WRITE)
	if f == null:
		push_warning("Maps: could not write %s/%s.sql" % [SOURCE_DIR, id])
		return
	f.store_string(sql_for(id, room))
	f.close()

## A layer's grid as it is kept: every row there is, the plan's for a layer
## that has fewer, so a map always has the plan's size in every layer.
static func _grid(room: MadeRoom, layer: String) -> PackedStringArray:
	var rows: PackedStringArray = room.plan if layer == "plan" else room.dressing
	var out := PackedStringArray()
	for y in room.plan.size():
		out.append(rows[y] if y < rows.size() else MadeRoom.OPEN.repeat(room.plan[y].length()))
	return out

static func _q(v: String) -> String:
	return "'%s'" % v.replace("'", "''")

## The player's database, open — or null where there is none yet and `make`
## does not ask for one: only a save makes the file. A file gone from under an
## open connection — a test sweeping its folder — is let go of rather than read.
static func _store(make := false):
	var at := store_path()
	var there := FileAccess.file_exists(at)
	if _mine != null and (_mine_at != at or not there):
		_mine.close()
		_mine = null
	if _mine == null:
		if not there and not make:
			return null
		_mine = Db.writable(at)
		_mine_at = at
		if _mine != null:
			for sql in TABLES:
				_mine.run(sql)
	return _mine

static func _ask(from: String, sql: String, bindings: Array = []) -> Array:
	return _ask_mine(sql, bindings) if from == "mine" else _ask_shipped(sql, bindings)

static func _ask_mine(sql: String, bindings: Array = []) -> Array:
	var mine = _store()
	return mine.rows(sql, bindings) if mine != null else []

## The content database's maps — none for a test keeping to its scratch, and
## none from a build of the database older than the tables.
static func _ask_shipped(sql: String, bindings: Array = []) -> Array:
	if scratch_dir != "" or not Db.has_table("maps"):
		return []
	return Db.rows(sql, bindings)
