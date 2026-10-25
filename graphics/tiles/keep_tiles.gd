class_name KeepTiles
extends MapTiles

## The hall the hideout is, as a tileset: swept flagstones and a brick wall
## with lanterns set in its face, made with PixelLab (`keep_walls` in
## `graphics/assets/tiles/`). It has no pits: the hideout's floor is whole.

func id() -> String:
	return "keep"

func kind_marks() -> PackedStringArray:
	return PackedStringArray([MadeRoom.ROCK])

func kind_name(_mark: String) -> String:
	return Loc.t("hud.maker.tiles.keep.stone")

func open_colour() -> Color:
	return Color(0.16, 0.13, 0.11)

func outside_colour() -> Color:
	return Color(0.08, 0.065, 0.055)
