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
## corners alone.

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
## vertices is picked once and remembered.
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
		var face := corners[0] == UPPER and corners[1] == UPPER and corners[2] == TRANSITION and corners[3] == TRANSITION
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
## is a pit where `pit` says so. The index of the tile, or -1 for none.
func floor_tile(i: int, j: int, pit: Callable) -> int:
	var at := func(x: int, y: int) -> int: return LOWER if pit.call(x, y) else UPPER
	return _by_corners.get(_index(at.call(i - 1, j - 1), at.call(i, j - 1), at.call(i - 1, j), at.call(i, j)), -1)

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
## (i, j) are and whose bottom corners cells (i-1, j+1) and (i, j+1). `rock`
## says which cells are wall. The index of the tile, or -1 for none.
func wall_tile(i: int, j: int, rock: Callable) -> int:
	if not cliff:
		return _by_corners.get(_index(_v(i - 1, j, rock), _v(i, j, rock), _v(i - 1, j + 1, rock), _v(i, j + 1, rock)), -1)
	# The 4x4 of vertices round the tile: rows j-1 to j+2, columns i-2 to i+1.
	var key := PackedByteArray()
	key.resize(16)
	for r in 4:
		for c in 4:
			key[r * 4 + c] = _v(i - 2 + c, j - 1 + r, rock)
	var k := key.hex_encode()
	if _picked.has(k):
		return _picked[k]
	var best := -1
	var best_score := -999999
	for t in tiles.size():
		var pattern: Array = tiles[t]["pattern"]
		if pattern.is_empty():
			continue
		var score := 0
		for r in 4:
			for c in 4:
				var want := int(pattern[r][c])
				if want == ANY:
					continue
				var middle := MIDDLE.has(Vector2i(r, c))
				if int(key[r * 4 + c]) == want:
					score += 10 if middle else 1
				else:
					score -= 30 if middle else 1
		if score > best_score:
			best_score = score
			best = t
	_picked[k] = best
	return best

## What vertex cell (x, y) is for the walls: upper for a wall, transition for
## open floor directly under a wall — where the wall's face stands — and lower
## for the rest.
func _v(x: int, y: int, rock: Callable) -> int:
	if rock.call(x, y):
		return UPPER
	if rock.call(x, y - 1):
		return TRANSITION
	return LOWER

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
