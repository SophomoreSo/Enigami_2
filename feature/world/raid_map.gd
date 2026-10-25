class_name RaidMap
extends RefCounted

## The raid is one connected map of rooms rather than a queue of fights, and it
## is laid by hand: which map stands where on the floor is the `raid_rooms` rows
## of the content database (data/db/floors/), and each room is a map made in the
## map creator (`Maps`), holding what was laid in it — the monsters at their
## posts, the box, the ground to dig — and nothing rolled. Room records live
## here, so a cleared room stays cleared and loot left on the floor is still
## there when you come back.
##
## Two rooms are joined through the doorways their maps mark (`<`, `>`, `U`,
## `D`), where both rooms are on the floor; an exit stands on a room's `E`
## (`MadeRoom`). A map that names a
## floor's room is read again each time a raid is laid, so a room changed in the
## map creator — the player's own copy stands in front of the shipped one — is
## the room the next raid walks into.

const MW := 7
const MH := 5

var rooms: Dictionary = {}          ## Vector2i -> record
var entry: Vector2i = Vector2i.ZERO
## The run's own number. The floor does not grow from it any more; it is what a
## death's drop is matched to the run with, and what a room's own dice — the
## drops a kill gives — are seeded from.
var seed_base: int = 0
var elapsed: float = 0.0            ## raid clock; pressure rises with it
## Each room's ways out, as its map marks them, and where a body arriving each
## way is put down in it — known for rooms nobody has walked into, for a
## monster that wanders into one.
var _ways: Dictionary = {}          ## Vector2i -> Array of sides
var _arrive: Dictionary = {}        ## Vector2i -> side -> Vector2

## Lays the floor out: every room `raid_rooms` names, read off its map — what
## is in it, the ways out it marks, and the exit the floor gives it, standing
## on its `E`. `s` is the run's number (`seed_base`).
func lay(s: int) -> void:
	seed_base = s
	rooms.clear()
	_ways.clear()
	_arrive.clear()
	for row in Db.rows("SELECT * FROM raid_rooms ORDER BY y, x"):
		var c := Vector2i(int(row["x"]), int(row["y"]))
		var id := String(row["map_id"])
		var made := Maps.load_room(id)
		if made == null:
			push_error("RaidMap: the floor's room %s is the map %s, which is not there" % [str(c), id])
			continue
		var rec := made.record()
		rec["kind"] = String(row["kind"])
		rec["danger"] = int(row["danger"])
		rec["region"] = made.region
		rec["visited"] = false
		rec["coord"] = c
		rec["map"] = id
		if row.get("exit") != null:
			var exit := String(row["exit"])
			var info: Dictionary = (EXITS.get(exit, EXITS["entry"]) as Dictionary).duplicate()
			info["id"] = exit
			info["name"] = EXIT_NAMES.get(exit, "EXIT")
			var at := made.exit_cell()
			if at.x < 0:
				var start := made.spawn_point()
				at = Vector2i(int(start.x / Room.CELL), int(start.y / Room.CELL))
			info["x"] = at.x
			info["y"] = at.y
			rec["extraction"] = info
		if rec["kind"] == "entry":
			entry = c
		rooms[c] = rec
		_ways[c] = made.ways()
		# Only the sides it has a way on: the room is not stood up here, so it
		# cannot look for a floor to put a body down on anywhere else.
		var arrive := {}
		for side in _ways[c]:
			arrive[side] = made.arrival_at(int(side))
		_arrive[c] = arrive
		made.free()

## The terms of each kind of exit: how long it is held, and what it asks — `free`,
## `cost` in gold, or `boss`, the Arbiter down. Which room has which is the
## floor's (`raid_rooms.exit`).
const EXITS := {
	"entry": {"cond": "free", "time": 3.0},
	"arbiter": {"cond": "boss", "time": 1.2},
	"toll": {"cond": "cost", "cost": 25, "time": 1.5},
	"crack": {"cond": "free", "time": 1.0},
}

## What each kind of exit is called, in English. This is the fallback under
## `hud.exit.<id>` in `localization/`, gathered here so `tests/shared/loc_test`
## can hold the two together.
const EXIT_NAMES := {
	"entry": "ENTRY GATE",
	"arbiter": "ARBITER GATE",
	"toll": "TOLL GATE",
	"crack": "CRACK IN THE WALL",
}

## What an exit is called on the door and on the results sheet. The `name` in
## the record above is the English fallback under it, like every other name the
## rules invent; `id` is what the translation is keyed by.
static func exit_name(info: Dictionary) -> String:
	return Loc.opt("hud.exit.%s" % String(info.get("id", "")),
		String(info.get("name", "EXIT")))

func has_room(c: Vector2i) -> bool:
	return rooms.has(c)

func get_record(c: Vector2i) -> Dictionary:
	return rooms.get(c, {})

## The sides of this room a way out leads from: one its map marks a doorway
## on, with a room of the floor beyond it.
func doors_for(c: Vector2i) -> Dictionary:
	var d: Dictionary = {}
	for side in _ways.get(c, []):
		if rooms.has(c + dir_delta(int(side))):
			d[int(side)] = true
	return d

## Where a body coming into the room at `c` through `from_dir` is put down —
## asked for a room that is not loaded, by a monster wandering into it.
func arrival(c: Vector2i, from_dir: int) -> Vector2:
	var arrive: Dictionary = _arrive.get(c, {})
	return arrive.get(from_dir, Room.arrival_point(from_dir))

static func dir_delta(dir: int) -> Vector2i:
	return Components.dir_to_vec(dir)

static func opposite(dir: int) -> int:
	return Components.opposite(dir)

## Raid pressure: the longer you stay, the more the place notices.
func pressure() -> int:
	return clampi(int(elapsed / 75.0), 0, 4)

func advance(delta: float) -> void:
	elapsed += delta

## --- putting the map down ---------------------------------------------------
## Only what the run has changed. The floor is laid again from the same rows,
## so what is written down is the records it filled in: which rooms have
## been opened, what is still standing in them and what is still on their floor.
##
## A record's `coord` is left out and put back from its key — a `Vector2i` does
## not survive JSON, and the key already says which room it is.
func to_save() -> Dictionary:
	var out: Dictionary = {}
	for c: Vector2i in rooms:
		var rec: Dictionary = (rooms[c] as Dictionary).duplicate(true)
		rec.erase("coord")
		out["%d,%d" % [c.x, c.y]] = rec
	return {"rooms": out, "elapsed": elapsed}

## The other half: the floor is laid first, then this writes the run back over
## it. A room the save does not mention keeps the one `lay` made, so a save
## from an older floor is missing rooms rather than broken by them.
func restore(saved: Dictionary) -> void:
	elapsed = float(saved.get("elapsed", 0.0))
	var saved_rooms: Dictionary = saved.get("rooms", {})
	for key in saved_rooms:
		var parts := String(key).split(",")
		if parts.size() != 2:
			continue
		var c := Vector2i(int(parts[0]), int(parts[1]))
		if not rooms.has(c):
			continue
		var rec: Dictionary = (saved_rooms[key] as Dictionary).duplicate(true)
		rec["coord"] = c
		rooms[c] = rec
