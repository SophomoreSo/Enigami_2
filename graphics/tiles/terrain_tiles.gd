class_name TerrainTiles
extends RefCounted

## One of the game's own tilesets, made with PixelLab (`create_topdown_tileset`)
## and kept under `graphics/assets/tiles/<name>/`: the sheet, `sheet.png`, and
## what each tile of it is, `tiles.json` — the metadata PixelLab writes, with a
## tile's slice of the sheet (`bounding_box`), which of the set's two terrains
## each of its four corners is (`corners`), and for a set with walls the 4x4
## pattern of terrain round it (`pattern_4x4`). See `graphics/assets/tiles/README.md`.
##
## A set holds two terrains, a lower and an upper, and its tiles are Wang
## tiles: each is drawn for what its four corners are, so a map is drawn on a
## **dual grid** — a tile straddles four cells, and its corners are what those
## cells are. Two kinds of set are used:
##
##   * **A pit set** (16 tiles, flat): the lower terrain is the pit's dark, the
##     upper the floor. The floor is drawn out of it, every tile centred on a
##     corner of four cells (`floor_tile`), a hole opening wherever a cell is a
##     pit.
##   * **A wall set** (25 tiles, a cliff): the lower terrain is the floor, the
##     upper the top of a wall, and between them the wall's front face, one
##     tile tall, drawn in the cell below the top (`wall_tile`). Seen a little
##     from the front, a wall standing on a cell shows its face in that cell
##     and its top in the cell above, so the walls are drawn with the plan's
##     rows shifted up one: a wall cell is an upper vertex, and the floor cell
##     under it the face. Across, a tile straddles two cells, so a wall a cell
##     wide is a cell wide with its edges rounded into the cells either side.
##
## Which tile shows what is PixelLab's own rule for its cliff sets: the tile
## whose 4x4 pattern best matches the terrain round the cell, the four middle
## values counting most (`_score`). A set with no face is picked by its four
## corners alone. Either is picked from the cells round it as they were read
## beforehand (`Survey`).

const DIR := "res://graphics/assets/tiles"
const TILE := 16
## The three things a vertex can be, as the metadata writes them, and the
## pattern's wildcard.
const LOWER := 0
const UPPER := 1
const TRANSITION := 2
const ANY := 255
## The middle four of a 4x4 pattern: the tile's own corners.
const MIDDLE := [Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 1), Vector2i(2, 2)]

## The set's name: its folder.
var name: String = ""
var texture: Texture2D
## Each tile: `rect` its slice of the sheet, `corners` [NW, NE, SW, SE] as
## LOWER/UPPER/TRANSITION, `pattern` four rows of four or empty, `face` whether
## it is a wall's front face — the top of its middle upper, the bottom the
## face — and `coords` where it stands in the sheet's grid of tiles.
var tiles: Array = []
## Whether the set has a face: 25 tiles with patterns.
var cliff: bool = false
## By the four corners, for a flat set: the 4-bit index NW·8 + NE·4 + SW·2 + SE.
var _by_corners: Dictionary = {}
## The tile picked for a neighbourhood, by the neighbourhood: a 4x4 of
## vertices is picked once and remembered, by its four columns (`Survey`).
var _picked: Dictionary = {}
var _set: TileSet = null

static var _loaded: Dictionary = {}

## The set called `called`, read once; null for one that is not there.
static func of(called: String) -> TerrainTiles:
	if _loaded.has(called):
		return _loaded[called]
	var t := TerrainTiles.new()
	t.name = called
	if not t._read():
		t = null
	_loaded[called] = t
	return t

func _read() -> bool:
	var folder := DIR.path_join(name)
	var sheet := folder.path_join("sheet.png")
	var meta := folder.path_join("tiles.json")
	if not ResourceLoader.exists(sheet) or not FileAccess.file_exists(meta):
		return false
	texture = load(sheet)
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(meta))
	if not parsed is Dictionary:
		return false
	var data: Dictionary = parsed.get("tileset_data", parsed)
	for raw in data.get("tiles", []):
		if not raw is Dictionary:
			continue
		var box: Dictionary = raw.get("bounding_box", {})
		var rect := Rect2i(int(box.get("x", 0)), int(box.get("y", 0)), int(box.get("width", TILE)), int(box.get("height", TILE)))
		var c: Dictionary = raw.get("corners", {})
		var corners := [_vertex(c.get("NW", "lower")), _vertex(c.get("NE", "lower")),
			_vertex(c.get("SW", "lower")), _vertex(c.get("SE", "lower"))]
		var pattern: Array = []
		var p = raw.get("pattern_4x4", null)
		if p is Dictionary:
			for row in ["row_0", "row_1", "row_2", "row_3"]:
				var r = p.get(row, null)
				if r is Array and (r as Array).size() == 4:
					pattern.append(r.map(func(v) -> int: return int(v)))
			if pattern.size() != 4:
				pattern = []
		var face: bool = corners[0] == UPPER and corners[1] == UPPER and corners[2] == TRANSITION and corners[3] == TRANSITION
		if not pattern.is_empty():
			# A face tile by its pattern: its middle's top upper, bottom transition.
			face = int(pattern[1][1]) == UPPER and int(pattern[1][2]) == UPPER \
				and int(pattern[2][1]) == TRANSITION and int(pattern[2][2]) == TRANSITION
		tiles.append({"rect": rect, "corners": corners, "pattern": pattern, "face": face,
			"coords": Vector2i(rect.position.x / TILE, rect.position.y / TILE)})
	cliff = tiles.size() > 16
	for i in tiles.size():
		var corners: Array = tiles[i]["corners"]
		if corners.has(TRANSITION):
			continue
		var key := _index(corners[0], corners[1], corners[2], corners[3])
		if not _by_corners.has(key):
			_by_corners[key] = i
	return not tiles.is_empty()

static func _vertex(word) -> int:
	match String(word):
		"upper":
			return UPPER
		"transition":
			return TRANSITION
	return LOWER

static func _index(nw: int, ne: int, sw: int, se: int) -> int:
	return (1 if nw == UPPER else 0) * 8 + (1 if ne == UPPER else 0) * 4 \
		+ (1 if sw == UPPER else 0) * 2 + (1 if se == UPPER else 0)

## --- the floor --------------------------------------------------------------

## The tile of the floor drawn at dual cell (i, j) — the tile centred on the
## corner the cells (i-1, j-1), (i, j-1), (i-1, j) and (i, j) meet at, which is
## drawn with its top-left at the middle of cell (i-1, j-1) — for a floor that
## is a pit where `cells` has one. The index of the tile, or -1 for none.
func floor_tile(i: int, j: int, cells: Survey) -> int:
	var p := cells.pits
	var w := cells.size.x
	var at := cells.index(i - 1, j - 1)
	# A corner is the floor, the upper, where it is no pit (`_index`).
	return _by_corners.get((0 if p[at] else 8) + (0 if p[at + 1] else 4)
		+ (0 if p[at + w] else 2) + (0 if p[at + w + 1] else 1), -1)

## The one tile of the set that is all its upper terrain — all floor, in a pit
## set — or -1.
func plain_upper() -> int:
	return _by_corners.get(15, -1)

## All its lower terrain: all floor, in a wall set.
func plain_lower() -> int:
	return _by_corners.get(0, -1)

## --- the walls --------------------------------------------------------------

## The tile of the walls drawn at dual cell (i, j): across, the tile straddling
## cells i-1 and i, with its top-left half a cell into cell (i-1, j); down the
## floor, the tile in row j, whose top corners are what cells (i-1, j) and
## (i, j) are and whose bottom corners cells (i-1, j+1) and (i, j+1). `cells`
## says which cells are wall. The index of the tile, or -1 for none.
func wall_tile(i: int, j: int, cells: Survey) -> int:
	var c := cells.columns
	if not cliff:
		var w := cells.size.x
		var at := cells.index(i - 1, j)
		return _by_corners.get(_index(c[at] & 3, c[at + 1] & 3, c[at + w] & 3, c[at + w + 1] & 3), -1)
	# The 4x4 of vertices round the tile — rows j-1 to j+2, columns i-2 to
	# i+1 — as its four columns, a byte each.
	var at := cells.index(i - 2, j - 1)
	var key: int = c[at] | c[at + 1] << 8 | c[at + 2] << 16 | c[at + 3] << 24
	if _picked.has(key):
		return _picked[key]
	var best := -1
	var best_score := -999999
	for t in tiles.size():
		var pattern: Array = tiles[t]["pattern"]
		if pattern.is_empty():
			continue
		var score := 0
		for r in 4:
			for col in 4:
				var want := int(pattern[r][col])
				if want == ANY:
					continue
				var middle := MIDDLE.has(Vector2i(r, col))
				if ((key >> (col * 8 + r * 2)) & 3) == want:
					score += 10 if middle else 1
				else:
					score -= 30 if middle else 1
		if score > best_score:
			best_score = score
			best = t
	_picked[key] = best
	return best

## --- the cells round the tiles ---------------------------------------------

## What the cells under a stretch of tiles are, read once each for the tiles
## to be picked from: whether each is wall, whether a pit, and what it is as a
## vertex of the walls. A floor's tile reads the four cells its corner is
## between, and a wall's the 4x4 of vertices round it, each of which is its
## cell and the cell over it — asked as each tile was picked, a room's every
## cell was asked some thirty times over, and a room is laid again whenever a
## room is stood up beside it or taken down.
class Survey extends RefCounted:
	## The first cell read, and how many were read across and down.
	var from := Vector2i.ZERO
	var size := Vector2i.ZERO
	## Each cell's, across and then down from `from`: 1 for wall, and 1 for a
	## pit.
	var rocks := PackedByteArray()
	var pits := PackedByteArray()
	## What each cell is as a vertex of the walls — upper for a wall, transition
	## for open floor directly under one, where the wall's face stands, and
	## lower for the rest — and below it, two bits each, what the three cells
	## under it are: a column of the 4x4 a wall's tile is picked by. Its own is
	## the lowest two bits.
	var columns := PackedByteArray()

	## The cells laying the dual tiles of `area` reads (`MapTiles.lay`), asked
	## of `rock` and `pit`: a floor's tile reaches a cell up and to the left of
	## its own, and a wall's two to the left, one to the right, two down, and
	## up one and the cell over that.
	static func of(area: Rect2i, rock: Callable, pit: Callable) -> Survey:
		var s := Survey.new()
		s.from = area.position - Vector2i(2, 2)
		s.size = area.size + Vector2i(4, 5)
		var n := s.size.x * s.size.y
		s.rocks.resize(n)
		s.pits.resize(n)
		s.columns.resize(n)
		s.read(Rect2i(s.from, s.size), rock, pit)
		return s

	## The dual tiles that read any of the cells of `rect`, as an area for
	## `MapTiles.lay` — what has to be laid again once they are read again.
	## A wall's tile reads from two cells to its left to one to its right, and
	## from two up to two down, and a floor's tile within that.
	static func tiles_reading(rect: Rect2i) -> Rect2i:
		return Rect2i(rect.position - Vector2i(1, 2), rect.size + Vector2i(2, 3))

	## The cells of `rect` asked again, of `rock` and `pit` — what is past a
	## room's side, once a room is stood up there or taken down — and the
	## columns brought up to date with them.
	func read(rect: Rect2i, rock: Callable, pit: Callable) -> void:
		var r := rect.intersection(Rect2i(from, size))
		for y in range(r.position.y, r.end.y):
			var at := index(r.position.x, y)
			for x in range(r.position.x, r.end.x):
				rocks[at] = 1 if rock.call(x, y) else 0
				pits[at] = 1 if pit.call(x, y) else 0
				at += 1
		# From the bottom up, so the column under each cell is done before it.
		# The top row has no cell over it to say it is a face, and no tile
		# reads it.
		var w := size.x
		var n := columns.size()
		for k in range(n - 1, -1, -1):
			var v := LOWER
			if rocks[k] != 0:
				v = UPPER
			elif k >= w and rocks[k - w] != 0:
				v = TRANSITION
			if k + w < n:
				v |= (columns[k + w] << 2) & 0xFF
			columns[k] = v

	## Where cell (x, y) is in each of them.
	func index(x: int, y: int) -> int:
		return (y - from.y) * size.x + x - from.x

	func rock(x: int, y: int) -> bool:
		return rocks[index(x, y)] != 0

	func pit(x: int, y: int) -> bool:
		return pits[index(x, y)] != 0

## --- as a TileSet -----------------------------------------------------------

## The set as a `TileSet` for a `TileMapLayer`, built once: one source, the
## sheet, with a tile at each of this set's tiles. A wall's face sorts by its
## foot, the bottom of its tile, so a body under it on the floor is drawn in
## front; every other tile sorts by its top, so a body beside a wall is never
## hidden behind the floor drawn into the tile's lower corners.
func tileset() -> TileSet:
	if _set != null:
		return _set
	_set = TileSet.new()
	_set.tile_size = Vector2i(TILE, TILE)
	var src := TileSetAtlasSource.new()
	src.texture = texture
	src.texture_region_size = Vector2i(TILE, TILE)
	for t in tiles:
		var coords: Vector2i = t["coords"]
		if src.has_tile(coords):
			continue
		src.create_tile(coords)
		var data := src.get_tile_data(coords, 0)
		@warning_ignore("integer_division")
		data.y_sort_origin = TILE / 2 if bool(t["face"]) else -TILE / 2
	_set.add_source(src, 0)
	return _set

## The sheet coordinates of tile `index`, for `TileMapLayer.set_cell`.
func coords(index: int) -> Vector2i:
	return tiles[index]["coords"]

## The slice of the sheet tile `index` is, for drawing it by hand.
func rect(index: int) -> Rect2i:
	return tiles[index]["rect"]

## A layer of this set's tiles, scaled to the world's cell and drawn pixel for
## pixel: `sorted` for the walls, which stand among the bodies, and not for a
## floor, which lies under all of them. Across, a wall layer's tiles straddle
## two cells, so the layer is set half a cell to the left (`wall_tile`).
func layer(sorted: bool) -> TileMapLayer:
	var l := TileMapLayer.new()
	l.tile_set = tileset()
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	l.scale = Vector2.ONE * (float(Room.CELL) / float(TILE))
	l.y_sort_enabled = sorted
	l.position = Vector2(-Room.CELL * 0.5, 0.0) if sorted else Vector2(-Room.CELL * 0.5, -Room.CELL * 0.5)
	return l

## Draws tile `index` by hand on `c`, over the world rect `r`.
func draw(c: CanvasItem, index: int, r: Rect2) -> void:
	if index < 0:
		return
	c.draw_texture_rect_region(texture, r, Rect2(rect(index)))
