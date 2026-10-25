class_name RockTiles
extends MapTiles

## The plain rock a raid's rooms are cut from (`RoomView`), as a tileset: the
## atlas's stone in its region's tint, which the creator's MAP offers to turn.

func id() -> String:
	return "rock"

func kind_marks() -> PackedStringArray:
	return PackedStringArray([MadeRoom.ROCK])

func kind_name(_mark: String) -> String:
	return Loc.t("hud.maker.tiles.rock.rock")
