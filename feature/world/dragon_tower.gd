class_name DragonTower
extends HandLaidRoom

## The dragon test's building: laid by hand rather than generated, with a post
## for every guard and a door for the player. Seen from above, its storeys are
## four halls one under the other, each joined to the next by a doorway at the
## other end from the last, so the building is walked — and cut through — the
## way it was climbed.
##
## `LAYOUT` is one string per row of cells (`HandLaidRoom`): `#` is solid, `G`
## is a guard's post — the guard stands in the middle of that cell — `P` is the
## door the player comes in by, and anything else is open. The doorways between
## the halls are where the lunges between them pass — a lunge goes no further
## than the first wall in its way (`Room.clamp_dash`) — so moving a post or
## closing a doorway can break the chain; `tests/feature/dragon_test.tscn` says
## whether one cast still clears the floor. Nothing here draws.

const LAYOUT := [
	"########################################",
	"#......................................#",
	"#......................................#",
	"#......................................#",
	"#.............G....G...................#",
	"##################....##################",
	"#......................................#",
	"#......................................#",
	"#......................................#",
	"#...................G....G.............#",
	"##########################....##########",
	"#......................................#",
	"#......................................#",
	"#......................................#",
	"#...............................G....G.#",
	"#############################...########",
	"#......................................#",
	"#......................................#",
	"#......................................#",
	"#.P............G........G..............#",
	"#......................................#",
	"########################################",
]

## Who stands at the posts.
const GUARD := "GRUNT"

func layout() -> Array:
	return LAYOUT

## One enemy record per post, in the shape `Room` spawns from: the guard stands
## in the middle of its cell.
func guard_records() -> Array:
	var out: Array = []
	for c in cells_marked("G"):
		var p := stand_point(c)
		out.append({"kind": GUARD, "mod": "", "pos": [p.x, p.y]})
	return out

func spawn_point() -> Vector2:
	var door_cells := cells_marked("P")
	return stand_point(door_cells[0] if not door_cells.is_empty() else Vector2i(2, H - 3))
