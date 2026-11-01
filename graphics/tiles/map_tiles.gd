class_name MapTiles
extends RefCounted

## A tileset: how a map made in the map creator (`MadeRoom`), a raid's room and
## the hideout's hall are drawn, on the creator's table and in a room, out of
## the game's own tiles — a wall set and, where the floor can have pits in it,
## a pit set, each made with PixelLab and kept under `graphics/assets/tiles/`
## (`TerrainTiles`, and the README there). The Moonlit Grove, the rock a
## raid's rooms are cut from, and the hall the hideout is: `GroveTiles`,
## `RockTiles`, `KeepTiles`. Which there are is `IDS`; another is its script,
## its id there and in `of`, its two sets in `graphics/assets/tiles/`, and its
## words under `hud.maker.tiles` in `localization/`.
##
## A set that is not there yet is drawn out of the atlas's own floor and walls
## instead (`AtlasTiles`), in the tileset's tint, so a tileset can be named
## before its tiles are made.
##
## What is put about a map — a lantern, a lightbulb, a fire, a fireplace, the
## glowing caps, the fireflies, the grass, the flowers, a bush, a fern — is the
## same in every tileset, and is here: the marks (`PROPS`), and their
## pictures, on the creator's table as they stand (`paint_prop_still`); in a
## room they move and light it (`MadeRoomView`, `Shine`).
##
## It is a picture, and only that. It reads a map's cells (`MapCells`) and
## changes nothing.

## A pixel of the buffer the world is drawn into, in world units; and a cell,
## in pixels of the buffer.
const S := PixelCamera.SCALE
const C := Room.CELL / PixelCamera.SCALE

## The tilesets, by id, in the order the map creator offers them. A map with
## none of these named is drawn in DEFAULT.
const IDS := ["grove", "rock", "keep"]
const DEFAULT := "rock"

## What can be put about a map, by the mark that puts each, in the order the
## creator offers them: the lights and the growing things a room draws
## (`MadeRoomView.LIGHTS`, `MadeRoomView.FOLIAGE`, `MadeRoomView.FERN`).
const PROPS := {"L": "lantern", "B": "lightbulb", "F": "fire", "H": "fireplace", "m": "mushrooms",
	"*": "fireflies", "S": "spotlight", "g": "grass", "f": "flowers", "b": "bush", "n": "fern"}
## Those that are foliage (`Foliage`), by the kind each grows, and the colours
## a still of each is drawn in on the table.
const FOLIAGE := {"g": "grass", "f": "flowers", "b": "bush"}
const LEAF := Color(0.24, 0.52, 0.26)
const LEAF_LIT := Color(0.40, 0.70, 0.36)
const BLOOM := Color(0.95, 0.72, 0.85)

## Magic stone's colours (`paint_magic`).
const MAGIC_STONE := Color(0.36, 0.26, 0.58)
const MAGIC_LIT := Color(0.68, 0.54, 0.95)
const MAGIC_DARK := Color(0.22, 0.14, 0.38)
const MAGIC_GLINT := Color(0.92, 0.86, 1.0)
## Glass, which is a wall of a kind until a tileset of its own draws it: a
## pane's blue, and a mirror's dark, over the wall it is drawn as.
const GLASS_TINT := Color(0.70, 0.90, 1.0)
const MIRROR_TINT := Color(0.45, 0.50, 0.60)
## The dark under a pit where a tileset has no pit set of its own.
const PIT_DARK := Color(0.02, 0.02, 0.03)

static var _made: Dictionary = {}

## The tileset's own tiles: its walls, and its pits, or null for a set that is
## not there (`TerrainTiles.of`).
var walls: TerrainTiles = null
var pits: TerrainTiles = null

## The tileset called `called`; DEFAULT for one that is not there.
static func of(called: String) -> MapTiles:
	if not IDS.has(called):
		called = DEFAULT
	if not _made.has(called):
		var t: MapTiles
		match called:
			"grove":
				t = GroveTiles.new()
			"keep":
				t = KeepTiles.new()
			_:
				t = RockTiles.new()
		t.walls = TerrainTiles.of(t.id() + "_walls")
		t.pits = TerrainTiles.of(t.id() + "_pits")
		_made[called] = t
	return _made[called]

## --- what a tileset says about itself -----------------------------------------

func id() -> String:
	return ""

## What it is called, in the language being played.
func title() -> String:
	return Loc.t("hud.maker.tiles.%s.title" % id())

## The walls and the floor it offers, by mark, in the order offered: its own
## kinds of wall, then a pit, and the magic stone every tileset has.
func ground_marks() -> PackedStringArray:
	var marks := kind_marks()
	marks.append(MadeRoom.PIT)
	marks.append(MadeRoom.MAGIC)
	return marks

## Its own kinds of wall, by mark.
func kind_marks() -> PackedStringArray:
	return PackedStringArray([MadeRoom.ROCK])

## What a mark of its ground is called: a pit and the magic stone alike in
## every tileset, glass too, and its own kinds as it calls them.
func ground_name(mark: String) -> String:
	if mark == MadeRoom.PIT:
		return Loc.t("hud.maker.pit")
	if mark == MadeRoom.MAGIC:
		return Loc.t("hud.maker.magic")
	if mark == "o":
		return Loc.t("hud.maker.glass.clear")
	if mark == "@":
		return Loc.t("hud.maker.glass.mirror")
	return kind_name(mark)

func kind_name(mark: String) -> String:
	return mark

## What a thing put about a map is called: the same in every tileset.
static func prop_name(mark: String) -> String:
	return Loc.t("hud.maker.prop.%s" % String(PROPS.get(mark, "lantern")))

## The tint the atlas's stone takes in this tileset, for a wall of `mark`, in
## `region`'s rock, where the tileset's own tiles are not there.
func tint(mark: String, region: int) -> Color:
	if mark == "o":
		return GLASS_TINT
	if mark == "@":
		return MIRROR_TINT
	return kind_tint(mark, region)

func kind_tint(_mark: String, region: int) -> Color:
	return Style.region_tint(region).lerp(Color.WHITE, 0.55)

## The tint a room drawn in this tileset's own tiles takes, in `region`'s
## rock: none, for a tileset that is its own colours.
func room_tint(_region: int) -> Color:
	return Color.WHITE

## The colour of what is past the map's edge on the creator's table, and under
## the floor's tiles.
func outside_colour() -> Color:
	return Style.region_tint(0).darkened(0.4)

func open_colour() -> Color:
	return Style.ROOM_BG

## The ground under a map on the creator's table, over `rect` of the sheet.
func paint_open(c: CanvasItem, rect: Rect2) -> void:
	c.draw_rect(rect, open_colour())

## The light there is in a room drawn in it with no lamp lit (`Lighting.ambient`).
func ambient() -> Color:
	return Color.WHITE

## --- a room's floor and walls ------------------------------------------------------
## The floor and the walls of a room, as tiles: laid in a `TileMapLayer` each
## for a room standing in the world, and drawn by hand for the creator's table.
## Both read the room's cells round `area`, in cells, as a survey of them
## (`TerrainTiles.Survey`) — whether each is wall, and whether a pit — asked
## once a cell of two callables, so a room's rock past its edge and a map's
## are drawn the same way.

## Two layers for a room: the floor, and the walls, which sort among the
## bodies. Out of the tileset's own tiles, or the atlas's.
func layers() -> Array:
	if walls == null:
		return [AtlasTiles.layer(false), AtlasTiles.layer(true)]
	var floor_layer := (pits if pits != null else walls).layer(false)
	return [floor_layer, walls.layer(true)]

## Lays the cells of `area` into `floor_layer` and `walls_layer` (`layers`).
## With the tileset's own tiles: the floor out of the pit set, a tile centred
## on each corner of four cells; the walls out of the wall set, straddling two
## cells across, the face in the wall's cell and the top above
## (`TerrainTiles`). Without: the atlas's floor, walls and hole, a tile a cell.
##
## The wall set has a tile for open floor too, all four of its corners floor,
## and the walls lay none of it: the floor is the floor layer's, the same floor
## (the pit set's was made from it), and the walls sort among the bodies above
## it — so a floor laid with them would be laid over everything on the floor
## under it, the pits and the marks left on it among them.
##
## `cells` is a survey of the cells round `area` (`TerrainTiles.Survey.of`).
func lay(floor_layer: TileMapLayer, walls_layer: TileMapLayer, cells: TerrainTiles.Survey, area: Rect2i, salt: int = 0) -> void:
	if walls == null:
		_lay_atlas(floor_layer, walls_layer, cells, area, salt)
		return
	var floor_set := pits if pits != null else walls
	var plain := pits.plain_upper() if pits != null else walls.plain_lower()
	var open_floor := walls.plain_lower()
	for j in range(area.position.y, area.end.y + 1):
		for i in range(area.position.x, area.end.x + 1):
			var cell := Vector2i(i, j)
			var f := floor_set.floor_tile(i, j, cells) if pits != null else plain
			if f >= 0:
				floor_layer.set_cell(cell, 0, floor_set.coords(f))
			var w := walls.wall_tile(i, j, cells)
			if w >= 0 and w != open_floor:
				walls_layer.set_cell(cell, 0, walls.coords(w))

## Takes up what `lay` lays over `area`, for part of a room to be laid again.
func unlay(floor_layer: TileMapLayer, walls_layer: TileMapLayer, area: Rect2i) -> void:
	# The dual tiles' area takes in its end; the atlas's, a tile a cell, not.
	var last := area.end if walls == null else area.end + Vector2i.ONE
	for j in range(area.position.y, last.y):
		for i in range(area.position.x, last.x):
			floor_layer.erase_cell(Vector2i(i, j))
			walls_layer.erase_cell(Vector2i(i, j))

func _lay_atlas(floor_layer: TileMapLayer, walls_layer: TileMapLayer, cells: TerrainTiles.Survey, area: Rect2i, salt: int) -> void:
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var cell := Vector2i(x, y)
			if cells.pit(x, y):
				floor_layer.set_cell(cell, AtlasTiles.SOURCE, AtlasTiles.coords(AtlasTiles.PIT))
				continue
			if not cells.rock(x, y):
				floor_layer.set_cell(cell, AtlasTiles.SOURCE, AtlasTiles.coords(AtlasTiles.floor_at(x, y, salt)))
				continue
			var tile := AtlasTiles.wall_at(not cells.rock(x, y + 1), not cells.rock(x - 1, y), not cells.rock(x + 1, y))
			walls_layer.set_cell(cell, AtlasTiles.SOURCE, AtlasTiles.coords(tile))

## The same, drawn by hand on `c` for the cells of `area`, in world units —
## the creator's table's chunks (`MapTable`). With the tileset's own tiles the
## floor and the walls are drawn as `lay` lays them, a dual tile reaching half
## a cell past the area each way; without, the atlas's, a tile a cell. The
## magic stone is drawn over either, whether or not magic is on: the table
## shows what was laid.
func paint_area(c: CanvasItem, cells: MapCells, area: Rect2i) -> void:
	var rock := func(x: int, y: int) -> bool: return cells.solid(x, y)
	var pit := func(x: int, y: int) -> bool: return cells.pit(x, y)
	var cell := float(Room.CELL)
	if walls == null:
		for y in range(area.position.y, area.end.y):
			for x in range(area.position.x, area.end.x):
				_tile(c, AtlasTiles.floor_at(x, y, cells.region * 7919), x, y, tint(MadeRoom.ROCK, cells.region))
				if cells.solid(x, y):
					var mark := cells.ground(x, y)
					var name := AtlasTiles.wall_at(not cells.solid(x, y + 1), not cells.solid(x - 1, y), not cells.solid(x + 1, y))
					_tile(c, name, x, y, tint(mark, cells.region))
				elif cells.pit(x, y):
					_tile(c, AtlasTiles.PIT, x, y, tint(MadeRoom.ROCK, cells.region))
	else:
		var around := TerrainTiles.Survey.of(area, rock, pit)
		var floor_set := pits if pits != null else walls
		var plain := pits.plain_upper() if pits != null else walls.plain_lower()
		for j in range(area.position.y, area.end.y + 1):
			for i in range(area.position.x, area.end.x + 1):
				var f := floor_set.floor_tile(i, j, around) if pits != null else plain
				floor_set.draw(c, f, Rect2(Vector2(i - 0.5, j - 0.5) * cell, Vector2.ONE * cell))
		# The walls, and none of the open floor they have a tile for (`lay`).
		var open_floor := walls.plain_lower()
		for j in range(area.position.y, area.end.y + 1):
			for i in range(area.position.x, area.end.x + 1):
				var w := walls.wall_tile(i, j, around)
				if w != open_floor:
					walls.draw(c, w, Rect2(Vector2(i - 0.5, j) * cell, Vector2.ONE * cell))
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if cells.ground(x, y) == MadeRoom.MAGIC:
				paint_magic(c, cells, x, y)

## Magic stone (`MadeRoom.MAGIC`), the same in every tileset: violet, lit along
## its top and dark along its foot, with a glint in it. Whether it is there to
## draw is the room's to say, but the creator's table draws it whatever the
## state, so what was laid can be seen.
func paint_magic(c: CanvasItem, cells: MapCells, x: int, y: int) -> void:
	var px := x * C
	var py := y * C
	box(c, px, py, C, C, MAGIC_STONE)
	if not cells.solid(x, y - 1):
		box(c, px, py, C, 2, MAGIC_LIT)
	if not cells.solid(x, y + 1):
		box(c, px, py + C - 1, C, 1, MAGIC_DARK)
	# A glint, somewhere in it, in the same place every time.
	box(c, px + 2 + odd(x, y, 7) % (C - 4), py + 3 + odd(x, y, 8) % (C - 5), 1, 1, MAGIC_GLINT)

## What is put about cell (x, y), as it stands: the thing with its feet in the
## middle of the cell, `still` of the way into whatever it does — a flame
## halfway up, a firefly lit — so the table shows it mid-motion and never moving.
func paint_prop_still(c: CanvasItem, cells: MapCells, x: int, y: int, still: float) -> void:
	var mark := cells.prop(x, y)
	if mark == MadeRoom.OPEN:
		return
	var foot := Vector2(x + 0.5, y + 1.0) * Room.CELL
	if FOLIAGE.has(mark):
		paint_foliage_still(c, mark, foot, float(S))
		return
	MadeRoomView.paint_prop(c, mark, foot, float(S), still, x * 31 + y)

## A patch of `mark`'s foliage standing on `foot`, a pixel of the buffer `px`
## across: blades of grass, blooms among them, or a bush. A room grows the real
## thing (`Foliage`); this is its still.
static func paint_foliage_still(c: CanvasItem, mark: String, foot: Vector2, px: float) -> void:
	var box_at := func(x: int, y: int, w: int, h: int, col: Color) -> void:
		c.draw_rect(Rect2(foot + Vector2(x, -y - h) * px, Vector2(w, h) * px), col)
	match mark:
		"b":
			box_at.call(-6, 0, 12, 6, LEAF)
			box_at.call(-4, 6, 8, 3, LEAF)
			box_at.call(-3, 7, 3, 2, LEAF_LIT)
			box_at.call(3, 3, 2, 2, LEAF_LIT)
		_:
			for k in 5:
				var bx := -6 + k * 3
				box_at.call(bx, 0, 1, 3 + (k * 7) % 4, LEAF if k % 2 == 0 else LEAF_LIT)
			if mark == "f":
				for k in [0, 2, 4]:
					box_at.call(-6 + k * 3 - 1, 3 + (k * 7) % 4, 3, 2, BLOOM)

## A tile's picture on the creator's table, for an entry of `layer` under its
## tab: a wall of `mark` as it stands alone — the top of one, out of the
## tileset's own tiles — a pit, the magic stone, or a thing put about a map as
## it stands — in the middle of `at`, `k` of the game's own size.
func icon(c: CanvasItem, layer: int, mark: String, at: Vector2, k: float) -> void:
	var cell := Vector2.ONE * Room.CELL * k
	var r := Rect2(at - cell * 0.5, cell)
	if layer == MapMaker.DRESSING:
		if FOLIAGE.has(mark):
			paint_foliage_still(c, mark, Vector2(at.x, r.end.y - 4.0 * k), float(S) * k)
		elif mark == MadeRoomView.SPOTLIGHT:
			# Hung low and narrow enough to fit the cell, its cone on the floor.
			MadeRoomView.paint_spotlight(c, Vector2(at.x, r.end.y - 2.0 * k), float(S) * k,
				Room.CELL * 0.75, Room.CELL * 0.45)
		else:
			MadeRoomView.paint_prop(c, mark, Vector2(at.x, r.end.y - 2.0 * k), float(S) * k, 0.6, 3)
		return
	if mark == MadeRoom.PIT:
		if pits != null:
			pits.draw(c, pits.plain_lower(), r)
		else:
			_tile_in(c, AtlasTiles.PIT, r, tint(MadeRoom.ROCK, 0))
		return
	if mark == MadeRoom.MAGIC:
		c.draw_rect(r, MAGIC_STONE)
		c.draw_rect(Rect2(r.position, Vector2(r.size.x, 2.0 * k)), MAGIC_LIT)
		c.draw_rect(Rect2(r.position.x, r.end.y - k, r.size.x, k), MAGIC_DARK)
		return
	if walls != null:
		# The face of a wall, in the kind's tint over it where the kind is not
		# the tileset's own stone.
		var face := -1
		for t in walls.tiles.size():
			if bool(walls.tiles[t]["face"]):
				face = t
				break
		if face >= 0:
			c.draw_texture_rect_region(walls.texture, r, Rect2(walls.rect(face)),
				Color.WHITE if mark == MadeRoom.ROCK else tint(mark, 0))
			return
	_tile_in(c, AtlasTiles.WALL_FRONT, r, tint(mark, 0))

## The atlas tile `name` over cell (x, y), tinted.
func _tile(c: CanvasItem, name: String, x: int, y: int, col: Color) -> void:
	_tile_in(c, name, Rect2(Vector2(x, y) * Room.CELL, Vector2.ONE * Room.CELL), col)

static func _tile_in(c: CanvasItem, name: String, r: Rect2, col: Color) -> void:
	var tex := Sprites.texture(name)
	if tex == null:
		c.draw_rect(r, col)
		return
	c.draw_texture_rect(tex, r, false, col)

## A stretch of a map drawn once and kept: the cells of `area`, painted by
## `paint`. The creator's table is drawn in pieces like this, so what is off
## the screen is never drawn and a change draws again only the piece it is in.
class Chunk extends Node2D:
	var paint: Callable
	var area := Rect2i()

	func _draw() -> void:
		if paint.is_valid():
			paint.call(self, area)

## A block `w` by `h` pixels of the buffer at (x, y) of it, in world units.
static func box(c: CanvasItem, x: int, y: int, w: int, h: int, col: Color) -> void:
	c.draw_rect(Rect2(Vector2(x, y) * S, Vector2(w, h) * S), col)

## Something that is the same for cell (x, y) every time and has no pattern to
## it: 0 to 999, different for every `salt`.
static func odd(x: int, y: int, salt: int = 0) -> int:
	return absi((x * 73856093) ^ (y * 19349663) ^ ((salt + 1) * 83492791)) % 1000
