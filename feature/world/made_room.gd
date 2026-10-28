class_name MadeRoom
extends HandLaidRoom

## A room made in the map creator (`MapMaker`) and kept as rows in a database
## (`Maps`): its layers — rows of cells, written the way every hand-laid room
## is — its tileset and region, and the picture each layer was laid over.
## Anywhere a room is wanted, one is picked up and stood:
##
##     var room := Maps.load_room("keep")
##     add_child(room)
##     room.stand()
##
## Two layers, each one string a row and a character a cell, `.` for none:
##
##   plan      the floor plan, seen from above: the one layer the rules read.
##             A cell of it is open floor, or a wall (`GROUND`, by the kind of
##             wall it is), which is solid whatever kind it is, or magic stone
##             (`MAGIC`), which is a wall while magic is on and nothing while
##             it is off, or a pit (`PIT`), a hole in the floor a body falls
##             into; or what stands on the floor in it — `P` where the
##             player starts, `T` the room's treasure box, `x` ground worth
##             digging, `C` a crate with gold in it, `v` a bird, `_` a bench,
##             and a letter of `MONSTERS` a monster's post. Everything stands
##             on the middle of its cell.
##   dressing  what is put about the floor: a lantern, a fire, a patch of
##             grass.
##
## The second is the picture's, and nothing here reads it. Which marks it
## holds, and what each looks like, is the tileset's — `tileset`, by id —
## which draws the walls as well: every kind of wall is as solid as the next,
## and what kind it is says only how it looks.
##
## The rock goes on past the plan's edge, as it is drawn to (`RoomView`): the
## room is shut in on every side whatever its outermost cells hold, so a gap in
## a wall is an alcove and never a way out of the world — but for the mouth of
## a doorway, which the raid stands another room against.
##
## Nothing here draws.

## The walls changed under everything in the room: the magic stone went, or
## came back (`_on_magic`). For the picture, which draws the walls once.
signal ground_changed()

## The wall every hand-laid room is cut from: stone.
const ROCK := "#"
const OPEN := "."
const START := "P"
const BOX := "T"
const DIG := "x"
const CRATE := "C"
const BIRD := "v"
const BENCH := "_"
## The gold in a crate (`Crate`): a little, less than a dig turns up.
const CRATE_GOLD := Vector2i(2, 5)
## The kinds of wall, by the mark that lays each. All of them are solid,
## glass as much as stone: clear glass and a mirror are walls a body cannot go
## through, and what either shows is the picture's.
const GROUND := {"#": "stone", "%": "earth", "|": "bark", "=": "wood", "*": "leaves",
	"o": "glass", "@": "mirror"}
## Magic stone: a wall — solid, and drawn — while magic is on (`Magic`), and
## nothing at all while it is off. The one kind of wall that is not in
## `GROUND`, since `GROUND` is what is always there.
const MAGIC := "~"
## A pit: a hole in the floor (`Room.pits`).
const PIT := "O"
## A monster's post, by the letter that marks it.
const MONSTERS := {
	"c": "CRAWLER", "s": "SENTRY", "l": "LOBBER", "h": "HOPPER", "d": "DRIFTER",
	"b": "BOMBER", "w": "WARDEN", "g": "GUNMAN", "u": "GRUNT", "y": "DUMMY", "a": "ARBITER",
}
## The ways out of a room a raid stands it in (`RaidMap`): a doorway in any of
## its four walls, walked through — the cells of its mouth, laid against that
## edge. A room marks the ways it has, and the raid's floor says which room
## each leads to. Off a raid nothing reads them, and they are open cells like
## any.
const DOOR_WEST := "<"
const DOOR_EAST := ">"
const DOOR_NORTH := "U"
const DOOR_SOUTH := "D"
## Those marks, and the side of the room each is a way out on.
const WAYS := {DOOR_WEST: Components.W, DOOR_EAST: Components.E, DOOR_NORTH: Components.N, DOOR_SOUTH: Components.S}
## Where a raid room's way out of the raid stands, when the floor gives it one.
const EXIT := "E"
## The marks a room holds one of at most: a player starts in one place, a room
## keeps its loot in one box (`Room.box`), and it has one exit.
const ONE_OF := [START, BOX, EXIT]
## How far past the plan's edge the rock nothing leaves through goes, in cells.
const BEYOND := 4

## The floor plan: the rows of cells, top to bottom, all the same length.
@export var plan: PackedStringArray = PackedStringArray():
	set(value):
		plan = value
		_measure()
## What is put about it, a row to each of the plan's. A row it does not have
## is nothing.
@export var dressing: PackedStringArray = PackedStringArray()
## Which tileset draws it, by id: "" for the plain rock a raid's rooms are cut
## from. Which there are is the picture's (`graphics/tiles/`).
@export var tileset: String = ""
## Which region's rock the plain rock is: the tint a raid's rooms take from
## how deep they lie.
@export_range(0, 3) var region: int = 0
## The picture a layer was laid over, by the layer's name — "plan",
## "dressing" — as a res:// or user:// path. A layer with none is not here.
## Nothing in the room reads it; it is kept with the map for the creator.
var references: Dictionary = {}

func layout() -> Array:
	return Array(plan)

## Straight off the plan: `layout` copies it, and this is asked once a cell.
func mark_at(x: int, y: int) -> String:
	if y < 0 or y >= plan.size():
		return ROCK
	var row := plan[y]
	return row[x] if x >= 0 and x < row.length() else ROCK

## What is put about cell (x, y): `.` for nothing, and off the map.
func dressing_at(x: int, y: int) -> String:
	return _in(dressing, x, y)

static func _in(layer: PackedStringArray, x: int, y: int) -> String:
	if y < 0 or y >= layer.size() or x < 0 or x >= layer[y].length():
		return OPEN
	return layer[y][x]

## Whether `mark` is a wall: solid, whatever kind it is — and magic stone, for
## as long as magic is on.
static func is_ground(mark: String) -> bool:
	return GROUND.has(mark) or (mark == MAGIC and Magic.on)

## Whoever can be put in a cell of the plan, in the order the map creator
## offers them under CREATURES: the player's start, and each monster.
static func creatures() -> PackedStringArray:
	var out := PackedStringArray([START])
	for mark in MONSTERS:
		out.append(String(mark))
	return out

## Everything else that can be put in a cell of the plan that is not a wall, in
## the order the map creator offers it under THINGS: a pit, the box, the ground
## to dig, a crate, a bird, a bench, and the ways out.
static func things() -> PackedStringArray:
	var out := PackedStringArray()
	out.append(PIT)
	out.append(BOX)
	out.append(DIG)
	out.append(CRATE)
	out.append(BIRD)
	out.append(BENCH)
	for mark in [DOOR_WEST, DOOR_EAST, DOOR_NORTH, DOOR_SOUTH, EXIT]:
		out.append(mark)
	return out

## The monster `mark` posts, or "" for a mark that is not a monster's.
static func monster_of(mark: String) -> String:
	return String(MONSTERS.get(mark, ""))

## Solid wherever the plan has a wall of any kind, and off the end of a row;
## a pit wherever it has one.
func _generate() -> void:
	_measure()
	solid.resize(cols * rows)
	solid.fill(0)
	pits.resize(cols * rows)
	pits.fill(0)
	for y in rows:
		var row := plan[y] if y < plan.size() else ""
		for x in cols:
			if x >= row.length() or is_ground(row[x]):
				solid[_idx(x, y)] = 1
			elif row[x] == PIT:
				pits[_idx(x, y)] = 1

func _ready() -> void:
	super._ready()
	Magic.changed.connect(_on_magic)

## Magic went off, or came back: the magic stone goes, or stands again. The
## grid is read again, the rock the bodies walk round is built again, and the
## paths through the room are forgotten; the picture hears `ground_changed`. A
## body standing where stone comes back is pushed out of it by the engine, as
## out of any rock it ends up in. A room not yet stood has nothing to do: it is
## read as it stands when it is.
func _on_magic(_on: bool) -> void:
	if solid.is_empty():
		return
	_generate()
	for b in [body, pit_body]:
		if b != null and is_instance_valid(b):
			b.collision_layer = 0
			b.queue_free()
	_build_collision()
	_paths = null
	ground_changed.emit()

## Stands the room up out of its own plan: the grid, the rock, and whatever
## the marks say is in it.
func stand(seed_base: int = 0) -> void:
	build(Vector2i.ZERO, record(), {}, seed_base)

## The record `Room.build` fills the room from: the monsters at their posts,
## the box and the ground to dig where they were laid, and nothing rolled — a
## made room holds what was put in it. What the box and the ground hold is
## rolled from the plan itself — on dice of its own, not the room's — so the
## same map always hides the same things.
func record() -> Dictionary:
	var dice := RandomNumberGenerator.new()
	dice.seed = hash(plan)
	var rec := {"kind": "entry", "danger": 1, "region": region, "variant": hash(plan) % 65536,
		"enemies": monster_records(), "loot": [], "digs": [], "benches": [], "crates": [], "birds": []}
	var boxes := cells_marked(BOX)
	if not boxes.is_empty():
		var at := stand_point(boxes[0])
		rec["loot"] = _haul(dice, dice.randi_range(2, 4))
		rec["box"] = {"pos": [at.x, at.y], "opened": false}
	for c in cells_marked(BENCH):
		var at := stand_point(c)
		(rec["benches"] as Array).append({"pos": [at.x, at.y]})
	for c in cells_marked(DIG):
		var at := stand_point(c)
		var buried: Array = [{"scrap": dice.randi_range(5, 18)}]
		buried.append_array(_parts(dice, 2 if dice.randf() < 0.3 else 1))
		(rec["digs"] as Array).append({"pos": [at.x, at.y], "loot": buried, "dug": false})
	for c in cells_marked(CRATE):
		var at := stand_point(c)
		(rec["crates"] as Array).append({"pos": [at.x, at.y],
			"gold": dice.randi_range(CRATE_GOLD.x, CRATE_GOLD.y), "broken": false})
	for c in cells_marked(BIRD):
		var at := stand_point(c)
		(rec["birds"] as Array).append({"pos": [at.x, at.y], "flown": false})
	return rec

## One enemy record per post, in the shape `Room` spawns from: a monster
## stands on the middle of its cell.
func monster_records() -> Array:
	var out: Array = []
	for mark in MONSTERS:
		var kind := String(MONSTERS[mark])
		for c in cells_marked(String(mark)):
			var p := stand_point(c)
			out.append({"kind": kind, "mod": "", "pos": [p.x, p.y]})
	return out

## Where the player starts: in the cell marked for it, or with no such cell,
## on the open floor nearest the middle of the room.
func spawn_point() -> Vector2:
	var starts := cells_marked(START)
	if not starts.is_empty():
		return stand_point(starts[0])
	var middle := Vector2(cols, rows) * 0.5
	var best := Vector2i(-1, -1)
	for y in rows:
		for x in cols:
			if is_solid(x, y) or is_pit(x, y):
				continue
			if best.x < 0 or Vector2(x, y).distance_squared_to(middle) < Vector2(best).distance_squared_to(middle):
				best = Vector2i(x, y)
	if best.x < 0:
		return middle * CELL
	return stand_point(best)

## --- in a raid ---------------------------------------------------------------

## The sides this room has a way out on, by the marks it carries.
func ways() -> Array[int]:
	var out: Array[int] = []
	for mark in WAYS:
		if not cells_marked(String(mark)).is_empty():
			out.append(int(WAYS[mark]))
	return out

## The mouth of the doorway on side `dir`: every cell marked for it, as one
## rect. Nothing for a side with none.
func door_rect(dir: int) -> Rect2:
	var mark := ""
	for m in WAYS:
		if int(WAYS[m]) == dir:
			mark = String(m)
	if mark == "":
		return Rect2()
	var cells := cells_marked(mark)
	if cells.is_empty():
		return Rect2()
	var r := Rect2(Vector2(cells[0]) * CELL, Vector2(CELL, CELL))
	for c in cells:
		r = r.merge(Rect2(Vector2(c) * CELL, Vector2(CELL, CELL)))
	return r

## Where a body coming in through `from_dir` is put down: a cell and a half in
## from the doorway on that side, level with the middle of its mouth — as a
## carved room puts one down. A side the room marks no way on puts it where
## the room starts a player, which needs the room stood (`stand`) to find its
## floor.
func arrival_at(from_dir: int) -> Vector2:
	var mouth := door_rect(from_dir)
	if mouth.size != Vector2.ZERO:
		var c := mouth.get_center()
		match from_dir:
			Components.W: return Vector2(mouth.end.x + CELL * 1.5, c.y)
			Components.E: return Vector2(mouth.position.x - CELL * 1.5, c.y)
			Components.N: return Vector2(c.x, mouth.end.y + CELL * 1.5)
			Components.S: return Vector2(c.x, mouth.position.y - CELL * 1.5)
	return spawn_point()

## The cell its exit stands on, or (-1, -1) for a room that marks none.
func exit_cell() -> Vector2i:
	var at := cells_marked(EXIT)
	return at[0] if not at.is_empty() else Vector2i(-1, -1)

## What a box holds, a piece at a time: gold, or a part off the loot table.
func _haul(dice: RandomNumberGenerator, pieces: int) -> Array:
	var out: Array = []
	for i in pieces:
		if dice.randf() < 0.3:
			out.append({"scrap": dice.randi_range(5, 18)})
		else:
			out.append_array(_parts(dice, 1))
	return out

func _parts(dice: RandomNumberGenerator, count: int) -> Array:
	var out: Array = []
	var pool := Components.loot_pool()
	for i in count:
		if not pool.is_empty():
			out.append({"id": pool[dice.randi() % pool.size()]})
	return out

## The room's own rock, and the rock past its edge on every side — but for a
## side a doorway opens on (`doors`), where the raid stands the room beside
## against this one: its rock is the wall there, and the way runs on into it.
## Nothing of this room's reaches past that seam.
func _build_collision() -> void:
	super._build_collision()
	var wide := float(cols * CELL)
	var high := float(rows * CELL)
	var thick := float(BEYOND * CELL)
	var left := 0.0 if doors.has(Components.W) else -thick
	var right := wide if doors.has(Components.E) else wide + thick
	if not doors.has(Components.N):
		_slab(Rect2(left, -thick, right - left, thick))
	if not doors.has(Components.S):
		_slab(Rect2(left, high, right - left, thick))
	if not doors.has(Components.W):
		_slab(Rect2(-thick, 0.0, thick, high))
	if not doors.has(Components.E):
		_slab(Rect2(wide, 0.0, thick, high))

func _slab(side: Rect2) -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = side.size
	shape.shape = rect
	shape.position = side.get_center()
	body.add_child(shape)
