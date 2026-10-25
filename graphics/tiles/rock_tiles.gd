class_name RockTiles
extends MapTiles

## The plain rock a raid's rooms are cut from (`RoomView`), as a tileset: worn
## grey flagstones and a wall of cut stone, made with PixelLab (`rock_walls`
## and `rock_pits` in `graphics/assets/tiles/`), in the region's tint, which
## the creator's MAP offers to turn.

func id() -> String:
	return "rock"

func kind_marks() -> PackedStringArray:
	return PackedStringArray([MadeRoom.ROCK])

func kind_name(_mark: String) -> String:
	return Loc.t("hud.maker.tiles.rock.rock")

## A raid's rooms go darker and redder the deeper they lie: the region's tint,
## lightened, over the stone.
func room_tint(region: int) -> Color:
	return Style.region_tint(region).lerp(Color.WHITE, 0.55)
