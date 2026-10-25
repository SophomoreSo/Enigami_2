class_name AtlasTiles
extends RefCounted

## The floor and the walls of a room, as tiles cut from the shared atlas
## (0x72's DungeonTileset II, `Sprites.ATLAS_PATH`), which is itself a top-down
## tileset: a floor of flagstones, and walls with a dark top and a lit front
## face, the way a wall seen from above and a little in front shows both.
##
## One `TileSet` is built the first time anything asks, over the atlas at its
## own 16-pixel grid, with a tile at every place a named tile stands
## (`TILES`), and handed to every `TileMapLayer` a room draws itself with
## (`RoomView`). A wall tile sorts by its foot (`y_sort_origin`), so a body
## up the floor from a wall is drawn behind its front and one down the floor
## from it in front.
##
## Which tile stands for what is a look, and lives here with the set rather
## than in `Style`: these are the atlas's own names for its own tiles.

const TILE := 16
## The floor: flagstones, the first by far the commonest, the rest scattered
## through it for the floor not to read as a grid.
const FLOORS := ["floor_1", "floor_2", "floor_3", "floor_4", "floor_5", "floor_6", "floor_7", "floor_8"]
## The walls: the front face of one, and the ends of a front where it meets
## open floor to the left or the right; and the top, and its ends.
const WALL_FRONT := "wall_mid"
const WALL_FRONT_LEFT := "wall_left"
const WALL_FRONT_RIGHT := "wall_right"
const WALL_TOP := "wall_top_mid"
const WALL_TOP_LEFT := "wall_top_left"
const WALL_TOP_RIGHT := "wall_top_right"
## A pit: the hole in the floor.
const PIT := "hole"
## Every tile the set holds, by its name in the atlas: the floors, the walls,
## and a few more a room may put on them.
const TILES := ["floor_1", "floor_2", "floor_3", "floor_4", "floor_5", "floor_6", "floor_7", "floor_8",
	"wall_mid", "wall_left", "wall_right", "wall_top_mid", "wall_top_left", "wall_top_right",
	"wall_hole_1", "wall_hole_2", "wall_banner_blue", "wall_banner_red", "wall_banner_green",
	"wall_banner_yellow", "hole", "edge_down", "floor_ladder", "crate", "skull"]
## The one source in the set, by id.
const SOURCE := 0

static var _set: TileSet = null
static var _at: Dictionary = {}

## The set, built once.
static func tileset() -> TileSet:
	if _set != null:
		return _set
	_set = TileSet.new()
	_set.tile_size = Vector2i(TILE, TILE)
	var src := TileSetAtlasSource.new()
	src.texture = load(Sprites.ATLAS_PATH)
	src.texture_region_size = Vector2i(TILE, TILE)
	for name: String in TILES:
		var at := coords(name)
		if at.x < 0:
			continue
		src.create_tile(at)
		var data := src.get_tile_data(at, 0)
		# A wall sorts by its foot, where it meets the floor; a floor tile is
		# under everything and never sorted at all.
		if name.begins_with("wall") or name == "crate":
			data.y_sort_origin = TILE / 2
	_set.add_source(src, SOURCE)
	return _set

## Where the tile `name` stands in the atlas, in tiles — or (-1, -1) for a
## name the atlas has not got, or one that does not stand on its grid.
static func coords(name: String) -> Vector2i:
	if _at.has(name):
		return _at[name]
	var out := Vector2i(-1, -1)
	if Sprites.has_tile(name):
		var r: Rect2 = Sprites.texture(name).region
		if int(r.position.x) % TILE == 0 and int(r.position.y) % TILE == 0 \
				and int(r.size.x) == TILE and int(r.size.y) == TILE:
			out = Vector2i(int(r.position.x) / TILE, int(r.position.y) / TILE)
	_at[name] = out
	return out

## A layer of these tiles, scaled to the world's cell and drawn pixel for
## pixel; `sorted` for walls, which stand among the bodies, and not for a
## floor, which lies under all of them.
static func layer(sorted: bool) -> TileMapLayer:
	var l := TileMapLayer.new()
	l.tile_set = tileset()
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	l.scale = Vector2.ONE * (float(Room.CELL) / float(TILE))
	l.y_sort_enabled = sorted
	return l

## The floor tile for cell (x, y): the first flagstone mostly, and another
## now and then, the same one every time for the same cell and `salt`.
static func floor_at(x: int, y: int, salt: int) -> String:
	var h := hash(Vector3i(x, y, salt))
	if h % 7 != 0:
		return FLOORS[0]
	return FLOORS[1 + (h / 7) % (FLOORS.size() - 1)]

## The wall tile for a solid cell with open floor below it or not (`front`),
## and open floor to its left or right.
static func wall_at(front: bool, open_left: bool, open_right: bool) -> String:
	if front:
		if open_left:
			return WALL_FRONT_LEFT
		if open_right:
			return WALL_FRONT_RIGHT
		return WALL_FRONT
	if open_left:
		return WALL_TOP_LEFT
	if open_right:
		return WALL_TOP_RIGHT
	return WALL_TOP
