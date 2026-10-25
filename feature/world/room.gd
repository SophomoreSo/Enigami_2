class_name Room
extends Node2D

## One screen of the raid, seen from above: a floor plan of cells, open or
## solid, with a doorway in any of its four walls where a room stands beside
## it, whatever monsters and loot the map says are still here, and sometimes
## an extraction point.
##
## A doorway is walked through: the raid stands the room beside this one
## against it, where the floor puts it (`origin_of`), and the way runs on
## through the seam (`neighbours`). There is no up and no down in a room: a
## wall is walked round, and a thing on the floor is at the point on the floor
## it stands on. A pit is a hole in the floor (`pits`): a body that walks into
## one falls, and is stood back on the floor it left (`Player`); a monster
## will not walk into one, since to it a pit is as solid as a wall
## (`PIT_LAYER`); a dash carries the player over, and a bolt flies over.
##
## Everything in the room — its cells, its records, what it puts down — is in
## the room's own coordinates; what is handed to a body outside it is in the
## world's, through `to_global`.
##
## What stands on the floor is drawn in the order it stands down the floor
## (`y_sort_enabled`): a body walks behind a pillar and in front of it as it
## goes. That is a fact about a floor seen from above, and the picture leans
## on it.

signal enemy_killed(kind: String, pos: Vector2)
signal pickup_collected(pickup: Pickup)
## The drop a death left in this room, picked back up.
signal lost_kit_collected(kit: LostKit)
## The room's treasure box, opened. `items` are the loot records that came out.
signal box_opened(box: TreasureBox, items: Array)
## Ground was dug up here (`DigSpot`); `items` are what came out.
signal spot_dug(spot: DigSpot, items: Array)
signal extraction_progress(ratio: float, info: Dictionary)
signal extraction_done(info: Dictionary)
## Raised once the grid, the collision and the contents are all in place. A
## room is drawn once and then never again, so the view waits for this.
signal built()

const W := 40
const H := 22
const CELL := 32
## The mouth of a doorway in the west or east wall: the rows it spans; and of
## one in the north or south wall: the columns. Three cells, about the middle
## of the wall, so a body walks through without touching either side.
const DOOR_ROWS := [10, 11, 12]
const DOOR_COLS := [19, 20, 21]
## How far either side of a doorway's mouth nothing is put down when a room
## is filled — no box, no ground to dig, no monster — so the way in is clear.
const DOOR_CLEAR := 3
## The collision layer the pits stand on, and its bit: a monster that walks
## has it in its mask and is stopped at a pit's edge; the player and anything
## that flies do not.
const PIT_LAYER := 7
const PIT_BIT := 1 << (PIT_LAYER - 1)

## How many cells across and down this room is. Every room a raid builds is
## `W` by `H`, one screen; a room laid by hand (`HandLaidRoom`) is as wide as
## its rows, and a camera follows the player along it.
var cols: int = W
var rows: int = H
var solid: PackedByteArray = PackedByteArray()
## The pits, a cell each, the grid `solid` is: a pit is an open cell with no
## floor in it.
var pits: PackedByteArray = PackedByteArray()
## dir -> true, a doorway in that wall: any of the four.
var doors: Dictionary = {}
var coord: Vector2i = Vector2i.ZERO
var data: Dictionary = {}           ## live room record owned by RaidMap
var rng := RandomNumberGenerator.new()
var body: StaticBody2D
## The pits' edges, for the monsters that walk (`PIT_LAYER`).
var pit_body: StaticBody2D
var player: Player = null
var danger: int = 1
## The rooms stood up beside this one, by side (`Raid`): a query that falls
## past this room's edge on a side with one is that room's to answer, so a body
## sees, flies and walks across the seam between them. A side with none is rock.
var neighbours: Dictionary = {}

var extraction: Dictionary = {}     ## empty when this room has no exit
## How long the player has been holding the exit, in seconds.
var extract_hold: float = 0.0
## Whether the player is standing in an exit that would let them go: inside
## its rect, and nothing sealing it. What a held `interact` acts on, said out
## loud so the console can offer USE there.
var extract_offered: bool = false
var _extract_active: bool = false
## The open cells as a grid to find a way through, built by `path_between`:
## this room's and, across each seam with a room beside, that room's too, so
## a way round a wall can run through the doorway. `_paths_span` is the cells
## it covers, this room's top-left cell (0, 0), for it to be built again when
## the rooms beside change.
var _paths: AStarGrid2D = null
var _paths_span: Rect2i = Rect2i()
## The box this room's loot is kept in, or null when it was found with none.
var box: TreasureBox = null
## The ground worth digging in this room, dug or not.
var digs: Array[DigSpot] = []
## How far apart two spots of it are kept, and how far from the box: one dug
## should not be one stood on while opening something else.
const DIG_APART := 96.0
## The benches standing in it, to sit on (`Bench`): the ones its record names,
## `benches`, each `{"pos": [x, y]}`, and any put down since (`add_bench`).
var benches: Array[Bench] = []

func _ready() -> void:
	y_sort_enabled = true

func build(room_coord: Vector2i, record: Dictionary, doorset: Dictionary, seed_base: int) -> void:
	coord = room_coord
	data = record
	# Every side with a room beyond it: a doorway in that wall.
	doors = {}
	for dir in doorset:
		doors[int(dir)] = true
	danger = int(record.get("danger", 1))
	extraction = record.get("extraction", {})
	rng.seed = hash(Vector2i(seed_base, 0)) ^ hash(coord) ^ int(record.get("variant", 0))
	_generate()
	_build_collision()
	_spawn_contents()
	built.emit()

## --- grid -------------------------------------------------------------------
func _idx(x: int, y: int) -> int:
	return y * cols + x

func _set_cell(x: int, y: int, v: int) -> void:
	if x < 0 or y < 0 or x >= cols or y >= rows:
		return
	solid[_idx(x, y)] = v

func is_solid(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= cols or y >= rows:
		return true
	return solid[_idx(x, y)] == 1

func is_solid_at(gp: Vector2) -> bool:
	var l := to_local(gp)
	var n := _beside(l)
	if n != null:
		return n.is_solid_at(gp)
	return is_solid(int(floor(l.x / CELL)), int(floor(l.y / CELL)))

## Whether cell (x, y) is a pit: open, with no floor in it.
func is_pit(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= cols or y >= rows or pits.size() != solid.size():
		return false
	return pits[_idx(x, y)] == 1

## Whether the world point `gp` is over a pit — here, or in the room beside.
func is_pit_at(gp: Vector2) -> bool:
	var l := to_local(gp)
	var n := _beside(l)
	if n != null:
		return n.is_pit_at(gp)
	return is_pit(int(floor(l.x / CELL)), int(floor(l.y / CELL)))

## Whether a body stands on floor at the world point `gp`: open, and no pit.
func is_floor_at(gp: Vector2) -> bool:
	return not is_solid_at(gp) and not is_pit_at(gp)

## Whether the room's own point `l` is in rock — here, or in the room beside.
func _solid_local(l: Vector2) -> bool:
	return is_solid_at(to_global(l))

func out_of_bounds(gp: Vector2) -> bool:
	var l := to_local(gp)
	var n := _beside(l)
	if n != null:
		return n.out_of_bounds(gp)
	return l.x < -64 or l.y < -64 or l.x > cols * CELL + 64 or l.y > rows * CELL + 64

## Whether `gp` is somewhere in this room's own cells.
func owns(gp: Vector2) -> bool:
	var l := to_local(gp)
	return l.x >= 0.0 and l.y >= 0.0 and l.x < cols * CELL and l.y < rows * CELL

## Where this room's cells are in the world.
func bounds() -> Rect2:
	return Rect2(global_position, Vector2(cols, rows) * CELL)

## The room beside that the room's own point `l` falls in, or null: the one on
## the side `l` is out past, within this room's rows for a side room and its
## columns for one above or below. Out past a corner is nobody's.
func _beside(l: Vector2) -> Room:
	var side := -1
	var across := l.x >= 0.0 and l.x < cols * CELL
	var down := l.y >= 0.0 and l.y < rows * CELL
	if down and l.x < 0.0:
		side = Components.W
	elif down and l.x >= cols * CELL:
		side = Components.E
	elif across and l.y < 0.0:
		side = Components.N
	elif across and l.y >= rows * CELL:
		side = Components.S
	if side < 0 or not neighbours.has(side):
		return null
	var n = neighbours[side]
	return n if n != null and is_instance_valid(n) else null

## Where a room at `c` on the floor stands in the world when the raid stands
## its rooms side by side: a room's size along for every column and row.
static func origin_of(c: Vector2i) -> Vector2:
	return Vector2(c) * Vector2(W, H) * CELL

static func centre_of(x: int, y: int) -> Vector2:
	return Vector2(float(x) + 0.5, float(y) + 0.5) * CELL

func cell_center(x: int, y: int) -> Vector2:
	return centre_of(x, y)

## Grid-marched sight line, used by monsters before they commit to a target.
func has_line_of_sight(a: Vector2, b: Vector2) -> bool:
	var la := to_local(a)
	var lb := to_local(b)
	var steps := int(la.distance_to(lb) / (CELL * 0.5)) + 1
	for i in range(1, steps):
		if _solid_local(la.lerp(lb, float(i) / float(steps))):
			return false
	return true

## Whether something could travel straight from `a` to `b` and stay `margin`
## clear of the rock on both sides. It walks the line either side of the
## straight one — a cell is wider than the gap between them, so nothing fits
## in the middle unseen — in steps a corner cannot slip between.
##
## Finer than `has_line_of_sight`, which answers whether one monster can see
## another and is happy to look past the tip of a corner: a bolt steered down
## that line clips it.
func clear_between(a: Vector2, b: Vector2, margin: float) -> bool:
	var la := to_local(a)
	var to := to_local(b) - la
	var dist := to.length()
	if dist < 1.0:
		return not _solid_local(la)
	var side := to.orthogonal() / dist * margin
	var steps := int(dist / 8.0) + 1
	for i in range(1, steps + 1):
		var at := la + to * (float(i) / float(steps))
		if _solid_local(at + side) or _solid_local(at - side):
			return false
	return true

## The way from `from` to `to` through the open cells — this room's, and the
## rooms' beside it across their seams — as the points to fly through in
## order, ending on `to`; or nothing, when there is no way or either end is
## inside the rock. What a HOMING bolt follows when a wall stands between it
## and what it is after (`Projectile`).
##
## The grid is built the first time anything asks, and again when the rooms
## beside change: a room's walls are settled by `build` and never move. A
## diagonal is only taken where both cells beside it are open, so a path never
## cuts a corner a bolt would clip.
func path_between(from: Vector2, to: Vector2) -> PackedVector2Array:
	var span := _span()
	if _paths == null or span != _paths_span:
		_paths_span = span
		_paths = AStarGrid2D.new()
		_paths.region = span
		_paths.cell_size = Vector2(CELL, CELL)
		_paths.offset = Vector2(CELL, CELL) * 0.5
		_paths.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		_paths.update()
		for y in range(span.position.y, span.end.y):
			for x in range(span.position.x, span.end.x):
				var shut := is_solid(x, y) if x >= 0 and x < cols and y >= 0 and y < rows \
					else _solid_local(centre_of(x, y))
				if shut:
					_paths.set_point_solid(Vector2i(x, y))
	var a := Vector2i((to_local(from) / CELL).floor())
	var b := Vector2i((to_local(to) / CELL).floor())
	var out := PackedVector2Array()
	if not _paths.is_in_boundsv(a) or not _paths.is_in_boundsv(b) \
			or _paths.is_point_solid(a) or _paths.is_point_solid(b):
		return out
	var cells := _paths.get_point_path(a, b)
	# The first point is the cell the bolt is already in.
	for i in range(1, cells.size() - 1):
		out.append(to_global(cells[i]))
	if not cells.is_empty():
		out.append(to)
	return out

## The cells the path grid covers: this room's, and each room beside's across
## a seam, in this room's cells — negative to the west and the north.
func _span() -> Rect2i:
	var west := _beside(Vector2(-1.0, 1.0))
	var east := _beside(Vector2(cols * CELL + 1.0, 1.0))
	var north := _beside(Vector2(1.0, -1.0))
	var south := _beside(Vector2(1.0, rows * CELL + 1.0))
	var x0 := -west.cols if west != null else 0
	var x1 := cols + (east.cols if east != null else 0)
	var y0 := -north.rows if north != null else 0
	var y1 := rows + (south.rows if south != null else 0)
	return Rect2i(x0, y0, x1 - x0, y1 - y0)

## Stops a lunge at the first wall on the way.
func clamp_dash(from: Vector2, to: Vector2) -> Vector2:
	var steps := int(from.distance_to(to) / 8.0) + 1
	var last := from
	for i in range(1, steps + 1):
		var p: Vector2 = from.lerp(to, float(i) / float(steps))
		if is_solid_at(p):
			return last
		last = p
	return to

## --- generation -------------------------------------------------------------
## A plain room, cut from the rock: a wall a cell thick round the floor, a
## doorway in it on each side a room stands beyond (`doors`), and a few
## blocks of rock standing on the floor to fight round, and now and then a
## pit in it — unless the record asks for a flat room. The bench does: it is
## somewhere to stand and try things, and a pillar through the middle of it is
## scenery nobody can use.
func _generate() -> void:
	solid.resize(W * H)
	solid.fill(0)
	pits.resize(W * H)
	pits.fill(0)
	for x in W:
		for y in H:
			_set_cell(x, y, 1 if x == 0 or y == 0 or x == W - 1 or y == H - 1 else 0)
	# A doorway is a gap in the wall, the mouth's width, on a side with a room
	# beyond it: the rooms are one floor walked along, through the seam.
	if doors.has(Components.W):
		for y in DOOR_ROWS:
			_set_cell(0, y, 0)
	if doors.has(Components.E):
		for y in DOOR_ROWS:
			_set_cell(W - 1, y, 0)
	if doors.has(Components.N):
		for x in DOOR_COLS:
			_set_cell(x, 0, 0)
	if doors.has(Components.S):
		for x in DOOR_COLS:
			_set_cell(x, H - 1, 0)

	# Blocks to fight round, in from the walls and clear of every doorway.
	if not bool(data.get("flat", false)):
		var block_count := rng.randi_range(3, 6)
		for i in block_count:
			var wide := rng.randi_range(1, 4)
			var tall := rng.randi_range(1, 3)
			var px := rng.randi_range(3, W - 4 - wide)
			var py := rng.randi_range(3, H - 4 - tall)
			if _by_a_door(px, py) or _by_a_door(px + wide - 1, py + tall - 1):
				continue
			for x in range(px, px + wide):
				for y in range(py, py + tall):
					_set_cell(x, y, 1)
		# A pit or two, two cells each way, in the open.
		for i in rng.randi_range(0, 2):
			var px := rng.randi_range(4, W - 7)
			var py := rng.randi_range(4, H - 7)
			if _by_a_door(px, py) or _by_a_door(px + 1, py + 1):
				continue
			for x in range(px, px + 2):
				for y in range(py, py + 2):
					if not is_solid(x, y):
						pits[_idx(x, y)] = 1

	# An exit must always be reachable: clear a pocket around it.
	if not extraction.is_empty():
		@warning_ignore("integer_division")
		var ex: int = int(extraction.get("x", int(W / 2)))
		@warning_ignore("integer_division")
		var ey: int = int(extraction.get("y", int(H / 2)))
		for x in range(ex - 3, ex + 4):
			for y in range(ey - 3, ey + 4):
				if x > 0 and x < W - 1 and y > 0 and y < H - 1:
					_set_cell(x, y, 0)
					pits[_idx(x, y)] = 0

func _build_collision() -> void:
	body = StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	_shapes(body, is_solid)
	# The pits, on their own layer: a wall to a monster that walks, and
	# nothing to the player, who falls in.
	pit_body = StaticBody2D.new()
	pit_body.collision_layer = PIT_BIT
	pit_body.collision_mask = 0
	add_child(pit_body)
	_shapes(pit_body, is_pit)

## The cells `held` answers for, as collision shapes on `on`: each row's run
## of them merged into one, so a room is a handful of shapes.
func _shapes(on: StaticBody2D, held: Callable) -> void:
	for y in rows:
		var x := 0
		while x < cols:
			if not held.call(x, y):
				x += 1
				continue
			var start := x
			while x < cols and held.call(x, y):
				x += 1
			var run := x - start
			var shape := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2(run * CELL, CELL)
			shape.shape = rect
			shape.position = Vector2(start * CELL + run * CELL * 0.5, y * CELL + CELL * 0.5)
			on.add_child(shape)

## --- contents ---------------------------------------------------------------
func _spawn_contents() -> void:
	if not data.has("enemies"):
		data["enemies"] = _roll_enemies()
	if not data.has("loot"):
		data["loot"] = _roll_loot()
	# Monsters that walked in from next door join the room's own, and they join
	# them after the roll. They are kept in a list of their own until then for
	# exactly that reason: a wanderer that arrived in a room nobody has opened
	# yet must not be mistaken for that room having already been filled, or it
	# would be the only thing in it when the player finally walks in.
	for e in data.get("arrivals", []):
		data["enemies"].append(e)
	data["arrivals"] = []
	for e in data["enemies"]:
		_spawn_enemy(e)
	_spawn_box()
	# Rolled after everything else, so a room that had none — one filled
	# before there was ground to dig — rolls its monsters and loot as it did.
	if not data.has("digs"):
		data["digs"] = _roll_digs()
	_spawn_digs()
	for rec in data.get("benches", []):
		var p: Array = rec.get("pos", [])
		if p.size() == 2:
			add_bench(Vector2(float(p[0]), float(p[1])))
	# Put down before the room was built, by `Raid`, out of what a death left
	# behind. It is not rolled and it is not loot: this room holds one only
	# because the player died standing in it.
	if data.has("lost_kit"):
		_spawn_lost_kit(data["lost_kit"])
	# The rock, thrown in here and walked out on. Lying here again it is the
	# room's to write down, when it is left — so it is out of the record until
	# then, and a rock picked up here is not found lying here next time.
	for r in data.get("rocks", []):
		_spawn_rock(r)
	data.erase("rocks")

func _roll_enemies() -> Array:
	var out: Array = []
	var kind := String(data.get("kind", "normal"))
	if kind == "entry":
		return out
	if kind == "boss":
		out.append({"kind": "ARBITER", "mod": "", "pos": [W * CELL * 0.7, H * CELL * 0.5]})
		return out
	var n := rng.randi_range(1, 2 + danger)
	if kind == "treasure":
		n += 1
	for i in n:
		var mk := Monsters.pick(rng, danger)
		var mod_id := ""
		if rng.randf() < 0.12 + 0.05 * float(danger):
			mod_id = String(Enemy.MODIFIERS[rng.randi() % Enemy.MODIFIERS.size()])
		var p := _random_open_point()
		out.append({"kind": mk, "mod": mod_id, "pos": [p.x, p.y]})
	return out

func _roll_loot() -> Array:
	var out: Array = []
	var kind := String(data.get("kind", "normal"))
	var n := 0
	if kind == "treasure":
		n = rng.randi_range(2, 4)
	elif kind == "normal" and rng.randf() < 0.5:
		n = 1
	for i in n:
		var p := _random_open_point()
		if rng.randf() < 0.3:
			out.append({"scrap": rng.randi_range(5, 18), "pos": [p.x, p.y]})
		else:
			var pool := Components.loot_pool()
			var cid: String = pool[rng.randi() % pool.size()]
			out.append({"id": cid, "pos": [p.x, p.y]})
	return out

## An open cell to put something down in: in from the walls, floor, and clear
## of every doorway.
func _random_open_point() -> Vector2:
	for attempt in 60:
		var x := rng.randi_range(2, cols - 3)
		var y := rng.randi_range(2, rows - 3)
		if not is_solid(x, y) and not is_pit(x, y) and not _by_a_door(x, y):
			return cell_center(x, y)
	@warning_ignore("integer_division")
	return cell_center(int(cols / 2), int(rows / 2))

## Whether a cell is in the way in from one of this room's doorways, where
## nothing the room is filled with is put down.
func _by_a_door(x: int, y: int) -> bool:
	for dir in doors:
		var mouth := door_rect(int(dir))
		if mouth.size == Vector2.ZERO:
			continue
		var c := mouth.get_center() / CELL
		if absf(float(x) + 0.5 - c.x) <= DOOR_CLEAR + 1.0 and absf(float(y) + 0.5 - c.y) <= DOOR_CLEAR + 1.0:
			return true
	return false

## A monster come in from another room, by its record (`Raid`): among this
## room's from now on, standing where the record says.
func arrive(rec: Dictionary) -> Enemy:
	if not data.has("enemies"):
		data["enemies"] = []
	(data["enemies"] as Array).append(rec)
	return _spawn_enemy(rec)

func _spawn_enemy(e: Dictionary) -> Enemy:
	var n := Enemy.new()
	n.setup(String(e["kind"]), danger, String(e.get("mod", "")))
	n.position = Vector2(float(e["pos"][0]), float(e["pos"][1]))
	n.room = self
	n.collision_layer = 4
	n.collision_mask = 1 | (0 if n.ai() == "flyer" else PIT_BIT)
	n.set_meta("record", e)
	add_child(n)
	# After the node is in the tree, because `Actor._ready` fills the bar: a
	# monster carries its wounds from one visit to the next, and only a raid
	# that starts over hands it a whole one back.
	if e.has("hp"):
		n.health = clampf(float(e["hp"]), 1.0, n.max_health)
	return n

## Writes what the live monsters have become back into the map's record of this
## room, so a room walked out of and back into is the room that was left —
## wounded monsters still wounded and standing where they were last seen —
## rather than the same dice rolled again. And the rock, if it was left here:
## lying, or still on its way down.
func save_state() -> void:
	var rocks: Array = []
	for c in get_children():
		if c is Enemy and not c.dead and c.has_meta("record"):
			var rec: Dictionary = c.get_meta("record")
			rec["pos"] = [c.position.x, c.position.y]
			rec["hp"] = c.health
		elif c is LooseRock and not c.is_queued_for_deletion():
			rocks.append((c as LooseRock).record())
	# A rock still in the air when the room is left is in it too: it comes down
	# where it was last in the open, the moment the room is walked back into.
	var w := Attacks.container()
	if w != null and is_instance_valid(w):
		for c in w.get_children():
			if c is Projectile and (c as Projectile).is_rock() and c.room == self and not c.is_queued_for_deletion() \
					and owns((c as Projectile).resting_place()):
				var at := to_local((c as Projectile).resting_place())
				rocks.append({"weapon": (c as Projectile).thrown, "pos": [at.x, at.y]})
	if rocks.is_empty():
		data.erase("rocks")
	else:
		data["rocks"] = rocks

## The room's loot goes into one box rather than onto the floor. Where it
## stands is written into the record the first time the room is filled — on the
## spot the first piece was rolled for, which is open floor — so the box is in
## the same place every time the room is walked into, and is still there, open,
## once it has been emptied. A room found with nothing in it gets no box.
func _spawn_box() -> void:
	if not data.has("box"):
		var loot: Array = data["loot"]
		if TreasureBox.takeable(loot).is_empty():
			return
		data["box"] = {"pos": loot[0]["pos"], "opened": false}
	var rec: Dictionary = data["box"]
	var p: Array = rec.get("pos", [])
	var at := spawn_point()
	if p.size() == 2:
		at = Vector2(float(p[0]), float(p[1]))
	box = TreasureBox.new()
	box.setup(data["loot"], at, bool(rec.get("opened", false)))
	box.player = player
	box.opened.connect(_on_box_opened)
	add_child(box)

func _on_box_opened(b: TreasureBox, items: Array) -> void:
	data["box"]["opened"] = true
	box_opened.emit(b, items)

## Ground worth digging, rolled with the room: one or two spots in an ordinary
## room and two or three where the treasure is, and none in the room a raid
## starts in or the boss's. Each is open floor, kept clear of the box and of
## the others, with something buried under it — some gold, a part, and now and
## then a second part: a treasure box's sort of haul (`DigSpot`).
func _roll_digs() -> Array:
	var kind := String(data.get("kind", "normal"))
	var n := 0
	if kind == "normal":
		n = rng.randi_range(1, 2)
	elif kind == "treasure":
		n = rng.randi_range(2, 3)
	var taken: Array[Vector2] = []
	var loot: Array = data.get("loot", [])
	if not loot.is_empty() and (loot[0] as Dictionary).has("pos"):
		var b: Array = loot[0]["pos"]
		taken.append(Vector2(float(b[0]), float(b[1])))
	var out: Array = []
	for i in n:
		var at := Vector2.INF
		for attempt in 12:
			var p := _random_open_point()
			if taken.all(func(t: Vector2) -> bool: return t.distance_to(p) >= DIG_APART):
				at = p
				break
		if at == Vector2.INF:
			continue
		taken.append(at)
		var buried: Array = [{"scrap": rng.randi_range(5, 18)}]
		var pool := Components.loot_pool()
		for k in (2 if rng.randf() < 0.3 else 1):
			buried.append({"id": pool[rng.randi() % pool.size()]})
		out.append({"pos": [at.x, at.y], "loot": buried, "dug": false})
	return out

func _spawn_digs() -> void:
	digs.clear()
	for rec in data.get("digs", []):
		var d := DigSpot.new()
		d.setup(rec)
		d.player = player
		d.dug.connect(func(s: DigSpot, items: Array) -> void: spot_dug.emit(s, items))
		add_child(d)
		digs.append(d)

## A bench standing at `at` — the middle of a cell on the floor, the way a
## treasure box stands — for whoever plays this room to sit on.
func add_bench(at: Vector2) -> Bench:
	var b := Bench.new()
	b.setup(at)
	b.player = player
	add_child(b)
	benches.append(b)
	return b

## Whether a press of interact would sit the body down on a bench here.
func bench_offered() -> bool:
	for b in benches:
		if is_instance_valid(b) and b.offered():
			return true
	return false

## Whether holding interact would dig here.
func dig_offered() -> bool:
	for d in digs:
		if is_instance_valid(d) and d.offered():
			return true
	return false

## Whether a press of interact would open this room's box.
func box_offered() -> bool:
	return box != null and is_instance_valid(box) and box.offered()

## Whether a press of interact would pick the phone up off this room's floor
## (`PhoneProp`).
func phone_offered() -> bool:
	for c in get_children():
		if c is PhoneProp and (c as PhoneProp).offered():
			return true
	return false

## The kit a death left here, on the spot it fell on. That spot was somewhere
## the player was standing, so it is open floor — but a drop carried across a
## change to how rooms are built could land inside the rock, and a drop nobody
## can reach is worse than one in the wrong place. Anything but open floor
## falls back to where the room puts a player who walks in.
func _spawn_lost_kit(rec: Dictionary) -> void:
	var at := spawn_point()
	var p: Array = rec.get("pos", [])
	if p.size() == 2:
		var want := Vector2(float(p[0]), float(p[1]))
		if not _solid_local(want) and not out_of_bounds(to_global(want)):
			at = want
	var k := LostKit.new()
	k.setup(rec, at)
	k.room = self
	k.collected.connect(_on_lost_kit_collected)
	add_child(k)

## The rock, where it was left lying — or, should that be inside the room's
## rock, where the room puts a player who walks in.
func _spawn_rock(rec: Dictionary) -> void:
	var at := spawn_point()
	var p: Array = rec.get("pos", [])
	if p.size() == 2:
		var want := Vector2(float(p[0]), float(p[1]))
		if not _solid_local(want) and not out_of_bounds(to_global(want)):
			at = want
	LooseRock.drop(String(rec.get("weapon", "ROCK")), to_global(at), Vector2.ZERO, self, player)

func _on_lost_kit_collected(k: LostKit) -> void:
	# Out of the record as well as off the floor: walking back into this room
	# must not find it lying here again.
	data.erase("lost_kit")
	lost_kit_collected.emit(k)

func _on_pickup_collected(p: Pickup) -> void:
	pickup_collected.emit(p)

func on_enemy_died(e: Enemy) -> void:
	if e.has_meta("record"):
		data["enemies"].erase(e.get_meta("record"))
	# Monsters give back the parts their own attack was made of.
	var pool := Monsters.drop_pool(e.kind)
	var chance := 0.45
	if e.def.get("elite", false):
		chance = 0.9
	if e.def.get("boss", false):
		chance = 1.0
	if not pool.is_empty() and rng.randf() < chance:
		var drops := 1
		if e.def.get("boss", false):
			drops = 3
		for i in drops:
			var cid: String = pool[rng.randi() % pool.size()]
			var p := Pickup.new()
			# Where it fell in the room's own space: a pickup is the room's
			# child, and the room stands where the floor puts it. Given the
			# world point, one in any room but the floor's first landed a room
			# away, out of bounds, and was gone before it was seen.
			p.setup_component(cid, e.position)
			p.room = self
			p.collected.connect(_on_pickup_collected)
			add_child(p)
	var scrap_amount := int(e.def.get("scrap", 2))
	if scrap_amount > 0:
		var sp := Pickup.new()
		sp.setup_scrap(scrap_amount, e.position)
		sp.room = self
		sp.collected.connect(_on_pickup_collected)
		add_child(sp)
	if e.def.get("boss", false):
		data["boss_dead"] = true
	enemy_killed.emit(e.kind, e.global_position)

func enemies_left() -> int:
	var n := 0
	for c in get_children():
		if c is Enemy and not c.dead:
			n += 1
	return n

## --- doors & extraction -------------------------------------------------------
## The mouth of the doorway in the wall on side `dir`: the cells of the wall
## the way runs through, as a rect a little over a cell deep, so a body in the
## mouth is in it.
func door_rect(dir: int) -> Rect2:
	match dir:
		Components.W: return Rect2(0, DOOR_ROWS[0] * CELL, CELL * 1.2, DOOR_ROWS.size() * CELL)
		Components.E: return Rect2((cols - 1.2) * CELL, DOOR_ROWS[0] * CELL, CELL * 1.2, DOOR_ROWS.size() * CELL)
		Components.N: return Rect2(DOOR_COLS[0] * CELL, 0, DOOR_COLS.size() * CELL, CELL * 1.2)
		Components.S: return Rect2(DOOR_COLS[0] * CELL, (rows - 1.2) * CELL, DOOR_COLS.size() * CELL, CELL * 1.2)
	return Rect2()

## The middle of the way out of this room toward `dir`: the doorway in that
## wall.
func way_point(dir: int) -> Vector2:
	return door_rect(dir).get_center()

## Where a body arriving through `from_dir` is put down: two cells in from the
## doorway on that side.
##
## Static, and paired with `centre_of` for the same reason: a monster wandering
## into a room has to be given somewhere to stand in it, and the room it is
## walking into is not loaded — only the one the player is in ever is.
static func arrival_point(from_dir: int) -> Vector2:
	match from_dir:
		Components.W: return centre_of(2, DOOR_ROWS[1])
		Components.E: return centre_of(W - 3, DOOR_ROWS[1])
		Components.N: return centre_of(DOOR_COLS[1], 2)
		Components.S: return centre_of(DOOR_COLS[1], H - 3)
	@warning_ignore("integer_division")
	return centre_of(int(W / 2), int(H / 2))

## Where a player arriving through `from_dir` should be put down: the doorway's
## own arrival point, or the nearest open floor to it should that be rock.
func entry_point(from_dir: int) -> Vector2:
	return standing_near(arrival_at(from_dir))

## The same, for this room: where its doorways are. A room carved to the
## raid's one shape answers `arrival_point`; one laid by hand says where its
## own are (`MadeRoom`).
func arrival_at(from_dir: int) -> Vector2:
	return arrival_point(from_dir)

func spawn_point() -> Vector2:
	@warning_ignore("integer_division")
	return standing_near(cell_center(int(cols / 2), int(rows / 2)))

## `at`, or the nearest place to it a body can stand: an open cell, in from
## the room's edge, measured in cells and nearest first.
func standing_near(at: Vector2) -> Vector2:
	var cell := Vector2i(int(floor(at.x / CELL)), int(floor(at.y / CELL)))
	if _standable(cell):
		return at
	for r in range(1, maxi(cols, rows)):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := cell + Vector2i(dx, dy)
				if _standable(c):
					return cell_center(c.x, c.y)
	return at

## Room to stand: the cell floor, and in from the edge.
func _standable(c: Vector2i) -> bool:
	if c.x < 1 or c.x >= cols - 1 or c.y < 1 or c.y >= rows - 1:
		return false
	return not is_solid(c.x, c.y) and not is_pit(c.x, c.y)

func extraction_rect() -> Rect2:
	if extraction.is_empty():
		return Rect2()
	@warning_ignore("integer_division")
	var c: Vector2 = cell_center(int(extraction.get("x", W / 2)), int(extraction.get("y", H / 2)))
	return Rect2(c - Vector2(48, 48), Vector2(96, 96))

func extraction_blocked_reason() -> String:
	if extraction.is_empty():
		return Loc.t("hud.extract.no_exit")
	match String(extraction.get("cond", "free")):
		"cost":
			if GameState.raid_scrap < int(extraction.get("cost", 20)):
				return Loc.t("hud.extract.needs_scrap",
					[int(extraction.get("cost", 20)), GameState.raid_scrap])
		"boss":
			if not bool(data.get("boss_dead", false)):
				return Loc.t("hud.extract.sealed")
	return ""

func _process(delta: float) -> void:
	_update_extraction(delta)

func _update_extraction(delta: float) -> void:
	if extraction.is_empty() or player == null or not is_instance_valid(player):
		return
	# The body walks out, and only with the player's hands in it: from inside a
	# monster, F is for the monster's business, not for an exit the body happens
	# to be standing in.
	var inside := extraction_rect().has_point(to_local(player.global_position)) and player.vessel() == player
	var reason := extraction_blocked_reason()
	extract_offered = inside and reason == ""
	if inside and reason == "" and Input.is_action_pressed("interact") and not player.controls_locked():
		extract_hold += delta
		_extract_active = true
		if int(extract_hold * 8.0) != int((extract_hold - delta) * 8.0):
			Cues.at(&"extract_tick", player.global_position)
		var need := float(extraction.get("time", 2.5))
		extraction_progress.emit(clampf(extract_hold / need, 0.0, 1.0), extraction)
		if extract_hold >= need:
			extraction_done.emit(extraction)
			extract_hold = 0.0
	else:
		if _extract_active:
			extraction_progress.emit(0.0, extraction)
		_extract_active = false
		extract_hold = maxf(0.0, extract_hold - delta * 2.0)

## Which doorway a point is standing in, or -1 for none. A doorway is walked
## through into the room beside, which stands against this one.
func door_at(gp: Vector2) -> int:
	var l := to_local(gp)
	for dir in doors:
		if door_rect(int(dir)).has_point(l):
			return int(dir)
	return -1
