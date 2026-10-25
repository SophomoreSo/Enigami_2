class_name RoomView
extends Node2D

## A room, drawn from above: its floor, its walls, the pits in the floor,
## whatever exit it holds, and the foliage growing on its floor.
##
## The floor and the walls are tiles of the room's tileset (`MapTiles`: the
## game's own, `TerrainTiles`, or the atlas's standing in), on two layers: the
## floor under everything, and the walls sorted among the bodies by their
## feet, so a body walks behind a wall's front and in front of its top
## (`Room.y_sort_enabled`). Which tileset is a look: a raid's rooms are cut
## from the rock, a made map is drawn in the one it names, and the hideout's
## hall in its own (`Style`). Tiles never change while a room is loaded, so
## they are laid once the moment the room finishes building. The exit
## animates and the grass bends where somebody walks through it.
##
## The rock goes on past the room's edge, out to wherever the screen does. A
## room is 1280 across, and the screen is at least 1280x720 but takes the shape
## of the display: a phone longer than 16:9 shows more either side of the room,
## a squarer screen more above and below it. The camera stays on the room, so
## what those show is more of the rock the room was cut out of rather than the
## dark past the world, and a doorway's gap runs on through it, so a way out
## still reads as one.
##
## And how it stands to the light (`Lighting`): the edges of its rock, for a
## lamp to throw a shadow off, and the light its way out gives.

## The light a way out gives: how far it reaches in world units, how bright it
## is, and how much of it hangs in the air.
const EXIT_REACH := 170.0
const EXIT_LIGHT := 1.2
const EXIT_AIR := 0.06

var room: Room
## The tileset the room is drawn in.
var tiles: MapTiles
## The floor, and the walls.
var _floor: TileMapLayer
var _walls: TileMapLayer
## The rock's edges, for whatever lamp is near them to throw a shadow off.
var shadow: ShadowCaster
## The light of the way out, in a room that has one.
var exit_lamp: Lamp
## The patches growing on this room's floor, in the order they were grown
## (`Foliage`).
var plants: Array = []

func _ready() -> void:
	room = get_parent() as Room
	y_sort_enabled = true
	# What is drawn here itself is the way out, which is its own light.
	material = Lighting.glow()
	tiles = MapTiles.of(_tileset_id())
	var layers := tiles.layers()
	_floor = layers[0]
	_floor.z_index = -1
	_floor.visibility_layer = PixelCamera.WORLD_LAYER
	add_child(_floor)
	_walls = layers[1]
	_walls.visibility_layer = PixelCamera.WORLD_LAYER
	add_child(_walls)
	shadow = ShadowCaster.new()
	add_child(shadow)
	if room != null:
		room.built.connect(_on_built)
		# A room stood up beside this one draws what is past that edge, and one
		# taken down leaves the rock there again.
		room.beside_changed.connect(_on_reshaped)
	# The rock past the room is only as wide as the screen shows, so a screen
	# that changes shape — a window dragged, a phone turned — has it laid again.
	get_viewport().size_changed.connect(_on_reshaped)

func _on_built() -> void:
	_on_reshaped()
	_grow_foliage()
	_light_exit()
	# The cracks slams have left in this room, walked back into.
	Fx.lay_cracks(room)

## The rock as far as the screen shows it: its tiles, and the edges it throws
## shadows off.
func _on_reshaped() -> void:
	_lay_tiles()
	_cast()

## Which tileset the room is drawn in: a made map's own, the hideout's hall's,
## and the rock for a raid's rooms.
func _tileset_id() -> String:
	if room is MadeRoom and String((room as MadeRoom).tileset) != "":
		return (room as MadeRoom).tileset
	if room != null and room.get_parent() is HideoutWorld:
		return Style.HIDEOUT_TILESET
	return Style.RAID_TILESET

## Which tint the room takes: the tileset's say, by the region the room lies in.
func _tint() -> Color:
	var region := int(room.data.get("region", 0)) if room != null else 0
	if room is MadeRoom:
		region = (room as MadeRoom).region
	return tiles.room_tint(region)

## The floor and the walls, out as far as the screen shows past the room, laid
## by the tileset (`MapTiles.lay`): the pits in the floor open where the room
## has them, and the walls stand wherever the rock is, in the room and beyond.
## Where a room stands beside this one, its cells are its own to draw: a tile
## wholly over them is taken up again, and only those straddling the seam are
## laid by both, out of what both rooms are there.
func _lay_tiles() -> void:
	if room == null or not is_instance_valid(room) or room.solid.is_empty():
		return
	_floor.clear()
	_walls.clear()
	_floor.modulate = _tint()
	_walls.modulate = _tint()
	var out := reach(get_viewport())
	var salt := int(room.rng.seed % 65536)
	var area := Rect2i(-out.x, -out.y, room.cols + out.x * 2, room.rows + out.y * 2)
	tiles.lay(_floor, _walls, _rock, _pit, area, salt)
	for j in range(area.position.y, area.end.y + 1):
		for i in range(area.position.x, area.end.x + 1):
			var theirs := room.beside_owns(i - 1, j) and room.beside_owns(i, j)
			if theirs:
				_walls.erase_cell(Vector2i(i, j))
			if theirs and room.beside_owns(i - 1, j - 1) and room.beside_owns(i, j - 1):
				_floor.erase_cell(Vector2i(i, j))

## What grows on the room's floor is the `growths` rows of the content
## database: of each kind of foliage, how many patches and how long. Where each
## grows is decided here: along runs of open floor, never at the room's edge,
## never in a doorway, and never over a patch of its own kind. Which cells,
## how many and how long is rolled from the room's own seed, so a room looks
## the same every time it is walked into, and from a roll of its own rather
## than the room's, so the monsters and the loot fall as they always did.
func _grow_foliage() -> void:
	for p in plants:
		if is_instance_valid(p):
			p.queue_free()
	plants.clear()
	var ground := _ground()
	if ground.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = room.rng.seed ^ 0xf011a6e
	for row in Foliage.growths():
		var kind := String(row["foliage"])
		var want := rng.randi_range(int(row["fewest"]), int(row["most"]))
		var taken := {}
		var count := 0
		var tries := 0
		while count < want and tries < 40:
			tries += 1
			var long := rng.randi_range(int(row["shortest"]), int(row["longest"]))
			var start: Vector2i = ground.keys()[rng.randi() % ground.size()]
			var fits := true
			for k in long:
				var cell := start + Vector2i(k, 0)
				if not ground.has(cell) or taken.has(cell):
					fits = false
					break
			if not fits:
				continue
			for k in long:
				taken[start + Vector2i(k, 0)] = true
			count += 1
			_plant(kind, start, long, rng.randi())

## A patch of `kind`, `long` cells wide, standing on the floor of the cells
## from `start`: its picture's bottom edge, which is its roots, on the bottom
## of the cells, so it sorts among the bodies by where it grows.
func _plant(kind: String, start: Vector2i, long: int, roll: int) -> Foliage:
	var patch := Foliage.of(kind)
	@warning_ignore("integer_division")
	patch.grow(long * Room.CELL / Foliage.S, roll)
	patch.position = Vector2(start.x * Room.CELL, (start.y + 1) * Room.CELL)
	patch.visibility_layer = PixelCamera.WORLD_LAYER
	add_child(patch)
	plants.append(patch)
	return patch

## The cells foliage may grow on, as a set: open floor, in from the room's
## edge and clear of its doorways.
func _ground() -> Dictionary:
	var out := {}
	for y in range(1, room.rows - 1):
		for x in range(1, room.cols - 1):
			if not room.is_solid(x, y) and not room.is_pit(x, y) and not room._by_a_door(x, y):
				out[Vector2i(x, y)] = true
	return out

## How many cells past the room the screen shows on each side, across and down,
## with two more for a shake to swing into — for whatever draws a room's
## surroundings. Every screen frames a room at its own size and only ever
## closes in on it (`Fx.direct`), so the viewport is the most of the world
## there is to cover.
static func reach(vp: Viewport) -> Vector2i:
	var shown := vp.get_visible_rect().size
	var spare := (shown - Vector2(Room.W, Room.H) * Room.CELL).max(Vector2.ZERO) * 0.5
	return Vector2i((spare / Room.CELL).ceil()) + Vector2i(2, 2)

## Whether a cell is rock, out past the room's own edge as well as in it. Past
## an edge with a room stood up beside it — or round a corner from one — it is
## what that room says; past any other, all of the outside is, but for the gap
## a doorway cuts, which runs on through it.
func _rock(x: int, y: int) -> bool:
	if x >= 0 and y >= 0 and x < room.cols and y < room.rows:
		return room.is_solid(x, y)
	var beside := room.beside_at(x, y)
	if beside != null:
		return beside.is_solid_at(room.to_global(Room.centre_of(x, y)))
	if y >= 0 and y < room.rows and Room.DOOR_ROWS.has(y):
		if (x < 0 and room.doors.has(Components.W)) or (x >= room.cols and room.doors.has(Components.E)):
			return false
	if x >= 0 and x < room.cols and Room.DOOR_COLS.has(x):
		if (y < 0 and room.doors.has(Components.N)) or (y >= room.rows and room.doors.has(Components.S)):
			return false
	return true

## Whether a cell is a pit: the room's own, or the room's beside it past an
## edge, so the floor across the seam opens where that room's does.
func _pit(x: int, y: int) -> bool:
	var beside := room.beside_at(x, y)
	if beside != null:
		return beside.is_pit_at(room.to_global(Room.centre_of(x, y)))
	return room.is_pit(x, y)

func _process(_delta: float) -> void:
	if room != null and not room.extraction.is_empty():
		queue_redraw()
		if exit_lamp != null:
			exit_lamp.color = Style.EXIT_OPEN if room.extraction_blocked_reason() == "" else Style.EXIT_SEALED

## A way out lights the room round it, in its own colour: open or sealed.
func _light_exit() -> void:
	if exit_lamp != null:
		exit_lamp.queue_free()
		exit_lamp = null
	if room.extraction.is_empty():
		return
	exit_lamp = Lamp.of(Style.EXIT_OPEN, EXIT_REACH, EXIT_LIGHT)
	exit_lamp.volume = EXIT_AIR
	exit_lamp.position = room.extraction_rect().get_center()
	add_child(exit_lamp)

## Every line where the room's rock meets open floor, out as far as the screen
## shows: [from, to, the way the rock faces there], each as long a run as it
## goes on for. Rock beside rock is no line, and nor is a line between two
## cells of the room stood up beside this one, which casts its own. What a
## lamp throws shadows off (`_cast`).
func air_lines() -> Array:
	var lines: Array = []
	if room == null or not is_instance_valid(room) or room.solid.is_empty():
		return lines
	var cell := float(Room.CELL)
	var out := reach(get_viewport())
	# Along every line between two rows.
	for y in range(-out.y + 1, room.rows + out.y):
		var from := 0
		var way := 0
		for x in range(-out.x, room.cols + out.x + 1):
			var now := 0
			if x < room.cols + out.x:
				var below := _rock(x, y)
				var above := _rock(x, y - 1)
				if room.beside_owns(x, y) and room.beside_owns(x, y - 1):
					pass
				elif below and not above:
					now = -1
				elif above and not below:
					now = 1
			if now != way:
				if way != 0:
					lines.append([Vector2(from, y) * cell, Vector2(x, y) * cell, Vector2(0, way)])
				from = x
				way = now
	# Along every line between two columns.
	for x in range(-out.x + 1, room.cols + out.x):
		var from := 0
		var way := 0
		for y in range(-out.y, room.rows + out.y + 1):
			var now := 0
			if y < room.rows + out.y:
				var after := _rock(x, y)
				var before := _rock(x - 1, y)
				if room.beside_owns(x, y) and room.beside_owns(x - 1, y):
					pass
				elif after and not before:
					now = -1
				elif before and not after:
					now = 1
			if now != way:
				if way != 0:
					lines.append([Vector2(x, from) * cell, Vector2(x, y) * cell, Vector2(way, 0)])
				from = y
				way = now
	return lines

## The rock's edges, for a lamp to throw shadows off: every line where it
## meets open floor, each run of it one edge that faces the floor.
func _cast() -> void:
	var ends := PackedVector2Array()
	var facings := PackedVector2Array()
	for line: Array in air_lines():
		ends.append(line[0])
		ends.append(line[1])
		facings.append(line[2])
	shadow.edges(ends, facings)

func _draw() -> void:
	if room == null or not is_instance_valid(room) or room.extraction.is_empty():
		return
	var r := room.extraction_rect()
	var reason := room.extraction_blocked_reason()
	var col := Style.EXIT_OPEN if reason == "" else Style.EXIT_SEALED
	draw_rect(r, Color(col.r, col.g, col.b, 0.12))
	draw_rect(r, col, false, 2.0)
	var c := r.get_center()
	var t := float(Time.get_ticks_msec()) / 700.0
	for i in 3:
		var rad: float = 20.0 + float(i) * 12.0 + sin(t + float(i)) * 3.0
		draw_arc(c, rad, 0, TAU, 28, Color(col.r, col.g, col.b, 0.45 - 0.1 * float(i)), 2.0)
	var title := RaidMap.exit_name(room.extraction)
	PixelCamera.draw_text(self, c + Vector2(0, -60), title, col)
	if room.extract_hold > 0.0:
		var need := float(room.extraction.get("time", 2.5))
		draw_arc(c, 52.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(room.extract_hold / need, 0.0, 1.0),
			32, Color(0.6, 1.0, 0.8), 4.0)
