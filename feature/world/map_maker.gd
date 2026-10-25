class_name MapMaker
extends World

## The map creator: a grid of cells laid a mark at a time, in two layers
## (`MadeRoom`) — the floor plan, the walls and what stands on the floor, and
## the dressing, what is put about it — which SAVE keeps as rows (`Maps`) and
## PLAY stands up on the spot, to be walked and fought through with a kit off
## the bench. What the dressing's marks are, and how both layers look, is the
## picture's: the map's tileset, by id.
##
## Two things happen here, one at a time. A map is **laid**: `lay` and its kin
## change one layer, a stroke at a time, and every stroke can be taken back.
## Or it is **played**: the map is stood up as a room with a player in it,
## parts are free and the graphs are copies of the profile's, as on the bench,
## but the body is the profile's own and can die — and when it does, or R is
## pressed, the floor is set again as it was laid. Leaving play goes back to
## laying, with the map as it was.
##
## The map on the table is kept while the game runs: left for the title and
## come back to, it is as it was left, saved or not.
##
## Nothing here draws. `graphics/views/map_maker_view.gd` attaches itself to
## this node; the table the map is laid on is `graphics/ui/map_table.gd`, and
## a map stood up is drawn as every made room is (`MadeRoomView`).

signal exit_requested()
## The assembly board went up over a map being played, or came down.
signal editing_changed(on: bool)
## The map went from being laid to being played, or back.
signal playing_changed(on: bool)
## A map being played was set again as it was laid, with a fresh body in it.
signal floor_reset()

## The layers, as `MadeRoom` has them.
enum { PLAN, DRESSING }
## The least a map can be, in cells — a nook a body can just about move in,
## seen in the middle of the screen with the walls all round it — and the
## most, four of a raid's rooms each way. A new map is one room, one screen.
const MIN_SIZE := Vector2i(8, 6)
const MAX_SIZE := Vector2i(Room.W * 4, Room.H * 4)
const NEW_SIZE := Vector2i(Room.W, Room.H)
## How many strokes can be taken back.
const UNDO_STEPS := 100
## Seconds between the body dying and the floor being set again.
const RESET_DELAY := 2.4
## The tileset a map nobody has chosen one for is drawn in, by id.
const NEW_TILESET := "grove"
## Where a new map's start is: by its west wall, halfway down.
const NEW_START := Vector2i(4, 11)

## The map on the table from one visit to the next — see `_exit_tree`.
static var _kept: Dictionary = {}

## The name the map was last saved or opened under, or "" for one that never was.
var map_id: String = ""
var cols: int = NEW_SIZE.x
var rows: int = NEW_SIZE.y
## Which tileset draws it, and which region's rock the plain rock is
## (`MadeRoom.tileset`, `MadeRoom.region`).
var tileset: String = NEW_TILESET
var region: int = 0
## The picture each layer is laid over, by the layer's name, as `MadeRoom` has
## it: kept with the map, and nothing on the table draws it yet.
var references: Dictionary = {}
## Whether the map has changed since it was last saved or opened.
var unsaved: bool = false

var playing: bool = false
## The map stood up, and the body in it, while it is being played.
var room: MadeRoom = null
## Null between a body dying and the floor being set again.
var player: Player = null
## weapon id -> the graph tried here: a copy of the profile's, as on the bench.
var graphs: Dictionary = {}
## The weapon a played map starts in hand; the next ones round fill the kit.
var weapon_index: int = 0
## The editor's pool: unused, because parts are unlimited here as on the bench.
var inventory: Dictionary = {}
## Counts down while a fallen body waits for the floor to be set again.
var reset_in: float = 0.0

var _plan: PackedStringArray = PackedStringArray()
var _dressing: PackedStringArray = PackedStringArray()
var _undo: Array = []
var _redo: Array = []
## Whether the stroke being made has been remembered yet: its first change is
## what there is to go back to.
var _remembered: bool = false

func _ready() -> void:
	Arena.register(self)
	Cues.emit_cue(&"music_start")
	# A played map's bodies are drawn in the order of their feet down the floor.
	y_sort_enabled = true
	# Copies only: nothing tried here reaches the hideout. The empty hand's as
	# well.
	for w in Weapons.ids() + [Weapons.HAND]:
		graphs[w] = GameState.weapon_board(String(w)).duplicate_board()
	if _kept.is_empty():
		new_map()
	else:
		_take(_kept)
		unsaved = bool(_kept.get("unsaved", false))
		weapon_index = int(_kept.get("weapon_index", 0))

## What is on the table is kept for the next visit, whatever way this one ends.
func _exit_tree() -> void:
	_kept = _shot()
	_kept["unsaved"] = unsaved
	_kept["weapon_index"] = weapon_index

## Forgets the map kept from the last visit, so the next starts on a new one.
static func forget() -> void:
	_kept = {}

## --- the map ----------------------------------------------------------------

## The rows of each layer as they stand: what a save writes and a play stands up.
func plan() -> PackedStringArray:
	return _plan.duplicate()

func dressing() -> PackedStringArray:
	return _dressing.duplicate()

func holds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < cols and cell.y < rows

## The mark in `cell` of `layer`. Off the map the plan is all rock, and the
## dressing is nothing.
func mark_at(cell: Vector2i, layer: int = PLAN) -> String:
	if not holds(cell):
		return MadeRoom.ROCK if layer == PLAN else MadeRoom.OPEN
	return _rows(layer)[cell.y][cell.x]

func cells_marked(mark: String, layer: int = PLAN) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var laid := _rows(layer)
	for y in rows:
		var x := laid[y].find(mark)
		while x >= 0:
			out.append(Vector2i(x, y))
			x = laid[y].find(mark, x + 1)
	return out

## The map as a room, out of the tree and not stood up: what SAVE keeps and
## PLAY stands.
func made() -> MadeRoom:
	var r := MadeRoom.new()
	r.plan = _plan.duplicate()
	r.dressing = _dressing.duplicate()
	r.tileset = tileset
	r.region = region
	r.references = references.duplicate()
	return r

## A map nobody has laid anything on: a room — a wall round, open floor
## within — with the player's start by its west wall. It takes the place of
## the one on the table, which a step back brings back; the tileset stays the
## one chosen.
func new_map() -> void:
	begin_stroke()
	if not _plan.is_empty():
		_remember()
	cols = NEW_SIZE.x
	rows = NEW_SIZE.y
	_plan = PackedStringArray()
	for y in rows:
		if y == 0 or y == rows - 1:
			_plan.append(MadeRoom.ROCK.repeat(cols))
		else:
			_plan.append(MadeRoom.ROCK + MadeRoom.OPEN.repeat(cols - 2) + MadeRoom.ROCK)
	_dressing = _blank(cols, rows)
	_write(PLAN, NEW_START, MadeRoom.START)
	begin_stroke()
	region = 0
	references = {}
	map_id = ""
	unsaved = false

static func _blank(wide: int, high: int) -> PackedStringArray:
	var out := PackedStringArray()
	for y in high:
		out.append(MadeRoom.OPEN.repeat(wide))
	return out

## --- laying -----------------------------------------------------------------

## A stroke starts: everything laid until the next one is one step to take back.
func begin_stroke() -> void:
	_remembered = false

## Lays `mark` in `cell` of `layer`. A mark the plan holds one of is moved
## rather than laid twice. Whether the map changed.
func lay(cell: Vector2i, mark: String, layer: int = PLAN) -> bool:
	if not holds(cell) or mark_at(cell, layer) == mark:
		return false
	_remember()
	if layer == PLAN and MadeRoom.ONE_OF.has(mark):
		for c in cells_marked(mark):
			_write(PLAN, c, MadeRoom.OPEN)
	_write(layer, cell, mark)
	unsaved = true
	return true

## Lays `mark` in every cell from `from` to `to`, in a straight line: what a
## pointer dragged faster than a cell a frame leaves behind it.
func lay_line(from: Vector2i, to: Vector2i, mark: String, layer: int = PLAN) -> bool:
	var changed := false
	var steps := maxi(absi(to.x - from.x), absi(to.y - from.y))
	for i in steps + 1:
		var t := float(i) / float(maxi(steps, 1))
		changed = lay(Vector2i(Vector2(from).lerp(Vector2(to), t).round()), mark, layer) or changed
	return changed

## Lays `mark` in every cell of the box with `a` and `b` at opposite corners.
func lay_box(a: Vector2i, b: Vector2i, mark: String, layer: int = PLAN) -> bool:
	var changed := false
	for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
		for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
			changed = lay(Vector2i(x, y), mark, layer) or changed
	return changed

## Makes the map `to` cells across and down, within what a map may be, with
## what was on it moved `shift` cells right and down: both layers grown with
## nothing, or cut, at whichever edges that puts the change on — with no
## shift, its right and its foot; a shift of the cells it grows by, its left
## and its top. Whatever is cut off is gone, a mark the plan holds one of with
## it, and a step back brings it back. Whether it changed.
func resize(to: Vector2i, shift: Vector2i = Vector2i.ZERO) -> bool:
	to = to.clamp(MIN_SIZE, MAX_SIZE)
	if to == Vector2i(cols, rows) and shift == Vector2i.ZERO:
		return false
	begin_stroke()
	_remember()
	_plan = _sized(_plan, to, shift)
	_dressing = _sized(_dressing, to, shift)
	cols = to.x
	rows = to.y
	begin_stroke()
	unsaved = true
	return true

## `laid`, `to` cells across and down, what it had moved `shift` right and
## down: cut, or grown with nothing.
static func _sized(laid: PackedStringArray, to: Vector2i, shift: Vector2i = Vector2i.ZERO) -> PackedStringArray:
	var out := PackedStringArray()
	for y in to.y:
		var from := y - shift.y
		var row := laid[from] if from >= 0 and from < laid.size() else ""
		if shift.x > 0:
			row = MadeRoom.OPEN.repeat(shift.x) + row
		elif shift.x < 0:
			row = row.substr(-shift.x)
		out.append(row.left(to.x).rpad(to.x, MadeRoom.OPEN))
	return out

## Draws the map in another tileset: a step to take back, like a stroke.
func set_tileset(id: String) -> void:
	if id == tileset:
		return
	begin_stroke()
	_remember()
	tileset = id
	begin_stroke()
	unsaved = true

func set_region(to: int) -> void:
	if to != region:
		region = to
		unsaved = true

func can_undo() -> bool:
	return not _undo.is_empty()

func can_redo() -> bool:
	return not _redo.is_empty()

## Takes the last stroke back.
func undo() -> bool:
	if _undo.is_empty():
		return false
	_redo.append(_shot())
	_take(_undo.pop_back())
	unsaved = true
	return true

## Lays again the stroke last taken back.
func redo() -> bool:
	if _redo.is_empty():
		return false
	_undo.append(_shot())
	_take(_redo.pop_back())
	unsaved = true
	return true

func _rows(layer: int) -> PackedStringArray:
	return _dressing if layer == DRESSING else _plan

func _write(layer: int, cell: Vector2i, mark: String) -> void:
	if layer == DRESSING:
		_dressing[cell.y] = _swap(_dressing[cell.y], cell.x, mark)
	else:
		_plan[cell.y] = _swap(_plan[cell.y], cell.x, mark)

static func _swap(row: String, x: int, mark: String) -> String:
	return row.left(x) + mark + row.substr(x + 1)

## The map as it stands, to go back to: its layers, its tileset, and the name
## it goes by — a step back over NEW or LOAD is the map that was there, under
## its own name.
func _shot() -> Dictionary:
	return {"plan": _plan.duplicate(), "dressing": _dressing.duplicate(),
		"cols": cols, "rows": rows, "tileset": tileset, "region": region, "map_id": map_id,
		"references": references.duplicate()}

func _take(shot: Dictionary) -> void:
	cols = int(shot["cols"])
	rows = int(shot["rows"])
	_plan = (shot["plan"] as PackedStringArray).duplicate()
	_dressing = _sized(shot.get("dressing", PackedStringArray()), Vector2i(cols, rows))
	tileset = String(shot.get("tileset", NEW_TILESET))
	region = int(shot["region"])
	references = (shot.get("references", {}) as Dictionary).duplicate()
	map_id = String(shot["map_id"])
	_remembered = false

func _remember() -> void:
	if _remembered:
		return
	_remembered = true
	_undo.append(_shot())
	if _undo.size() > UNDO_STEPS:
		_undo.pop_front()
	_redo.clear()

## --- keeping ----------------------------------------------------------------

## Keeps the map as `called` (`Maps.save`). "" once it is kept, and otherwise
## why it was not, as an id for the screen to spell: `name` for a name with
## nothing in it to file a map under, `write` for a file that could not be
## written.
func save_as(called: String) -> String:
	var id := Maps.id_for(called)
	if id == "":
		return "name"
	var kept := made()
	var err := Maps.save(id, kept)
	kept.free()
	if err != OK:
		return "write"
	map_id = id
	unsaved = false
	return ""

## Puts the map `id` on the table in place of the one there, which a step back
## brings back. Whether there was such a map. One laid by hand in the file is
## taken as it is, squared off: its rows made one length, both layers the
## plan's size, and the whole kept within what a map may be.
func open(id: String) -> bool:
	var found := Maps.load_room(id)
	if found == null:
		return false
	begin_stroke()
	_remember()
	var wide := MIN_SIZE.x
	for row in found.plan:
		wide = maxi(wide, row.length())
	var size := Vector2i(wide, found.plan.size()).clamp(MIN_SIZE, MAX_SIZE)
	_plan = _sized(found.plan, size)
	_dressing = _sized(found.dressing, size)
	cols = size.x
	rows = size.y
	tileset = found.tileset
	region = found.region
	references = found.references.duplicate()
	found.free()
	begin_stroke()
	map_id = id
	unsaved = false
	return true

## --- playing ----------------------------------------------------------------

## Stands the map up and puts a body in it.
func play() -> void:
	if playing:
		return
	playing = true
	_stand()
	playing_changed.emit(true)

## Back to laying: the room and everything in it goes, and the map is as it was.
func stop() -> void:
	if not playing:
		return
	set_editing(false)
	_strike()
	playing = false
	playing_changed.emit(false)

## Sets a played map again as it was laid, with a fresh body at its start.
func reset_floor() -> void:
	if not playing:
		return
	set_editing(false)
	_strike()
	_stand()
	floor_reset.emit()

## The weapon after the one a played map starts in hand.
func cycle_weapon() -> void:
	weapon_index = (weapon_index + 1) % Weapons.ids().size()

func current_weapon() -> String:
	return String(Weapons.ids()[weapon_index % Weapons.ids().size()])

## The graph on the weapon in hand: what the assembly board over a played map
## edits — the empty hand's with that in hand.
func board() -> SkillBoard:
	var weapon := current_weapon()
	if player != null and is_instance_valid(player):
		weapon = Weapons.HAND if player.empty_handed() else player.weapon_id
	return graphs[weapon]

func _stand() -> void:
	reset_in = 0.0
	player = Player.new()
	player.collision_layer = 2
	player.collision_mask = 1
	player.hand_board = graphs[Weapons.HAND]
	add_child(player)
	_arm()
	player.died.connect(_on_player_died)

	room = made()
	# Before it is stood: what the room puts down is told who to answer to.
	room.player = player
	add_child(room)
	room.stand()
	player.room = room
	player.global_position = room.spawn_point()
	player.velocity = Vector2.ZERO

## A kit's worth off the rack, as the bench hands one out: the weapon the map
## starts on in hand, and the next ones round beside it.
func _arm() -> void:
	var ids := Weapons.ids()
	var kit: Array = []
	var boards: Array = []
	for k in mini(Player.MAX_WEAPONS, ids.size()):
		kit.append(ids[(weapon_index + k) % ids.size()])
		boards.append(graphs[String(kit[k])])
	player.setup_kit(kit, boards, 0)

func _strike() -> void:
	reset_in = 0.0
	Attacks.clear_in_flight(self)
	if player != null and is_instance_valid(player):
		# Out of the hunt now rather than at the end of the frame.
		player.remove_from_group("player")
		player.queue_free()
	player = null
	if room != null and is_instance_valid(room):
		# Nothing in the room being struck gets another turn (`Raid._enter_room`).
		room.process_mode = Node.PROCESS_MODE_DISABLED
		room.queue_free()
	room = null

## The body died. It is gone at the end of the frame, so it is let go of now:
## nothing that asks for the body in the room is handed one that is not there.
func _on_player_died(_a: Actor) -> void:
	player = null
	reset_in = RESET_DELAY

func _process(delta: float) -> void:
	if reset_in > 0.0:
		reset_in -= delta
		if reset_in <= 0.0:
			reset_floor()

func set_editing(on: bool) -> void:
	if editing == on or (on and not playing):
		return
	editing = on
	if player != null and is_instance_valid(player):
		player.input_locked = on
	editing_changed.emit(on)

func on_board_changed() -> void:
	if player != null and is_instance_valid(player):
		player.rebuild_runner()

## The played room's box in reach, ground under the shovel, or a bench.
func use_nearby() -> bool:
	return room != null and is_instance_valid(room) \
		and (room.box_offered() or room.dig_offered() or room.bench_offered())

func leave() -> void:
	exit_requested.emit()
