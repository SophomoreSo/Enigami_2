class_name GroveTiles
extends MapTiles

## The Moonlit Grove: the hideout's old look, as a tileset — a mossy forest
## floor and ruined walls under ivy, made with PixelLab (`grove_walls` and
## `grove_pits` in `graphics/assets/tiles/`). Its kinds of wall — stone, earth,
## bark, planks and leaves — are each a shade of the one wall for now, on the
## creator's table.

const TINTS := {
	"#": Color(0.78, 0.86, 0.80),
	"%": Color(0.72, 0.62, 0.50),
	"|": Color(0.62, 0.52, 0.40),
	"=": Color(0.80, 0.70, 0.52),
	"*": Color(0.52, 0.78, 0.50),
}

func id() -> String:
	return "grove"

func kind_marks() -> PackedStringArray:
	return PackedStringArray(MadeRoom.GROUND.keys())

func kind_name(mark: String) -> String:
	return Loc.t("hud.maker.tiles.grove.%s" % String(MadeRoom.GROUND.get(mark, "stone")))

func kind_tint(mark: String, _region: int) -> Color:
	return TINTS.get(mark, TINTS["#"])

func open_colour() -> Color:
	return Color(0.10, 0.14, 0.11)

func outside_colour() -> Color:
	return Color(0.06, 0.09, 0.07)
