class_name GhostBase
extends HandLaidRoom

## The ghost test's ground: three screens across, a yard, a hall past the gate,
## and the vault beyond that, with a diamond kept on an island in it where only
## something that flies can reach it. The camera follows whoever the player is
## in.
##
## The player comes in by a nook in the yard's corner, walled round but for a
## gap at its top, which none of the guards can see into — the one place to wait
## unseen. A Crawler watches the yard from in front of the gate. Inside the gate
## a Gunman watches it, too far off to see the nook or the yard's far end and
## close enough to shoot anything that walks up to the gate. At the far end of
## the hall there is a Crawler, and through the doorway beyond it the vault: a
## Gunman and a Warden on the floor, a Drifter in the air, and a last Gunman by
## the pit round the island — a pit four cells wide, past any dash, that only
## a body that flies goes over.
##
## Everyone the way through is walked past or hopped into stands along one row
## of the floor, the sixteenth, from the gate guard to the last Gunman: the
## way in is along it from one guard to the next, and the way out back along
## it, the diamond passed from one guard to the next as the rock is on the way
## in. The rest stand off it. A throw seen by a Gunman, from a guard the player
## is in, is a guard shot dead under the player's hands, unless it hurts nobody.
##
## `LAYOUT` (`HandLaidRoom`): `#` is solid, `O` a pit, `P` is where the player
## starts, `,` is the rest of the nook — the start, where the diamond has to be
## brought — `D` is where the diamond lies, and a digit is a guard's post,
## which guard being `POSTS`'s to say. Anything else is open.

const LAYOUT := [
	"########################################################################################################################",
	"#.............................#..................................#.......................................OOOOOOOOOOOOOO#",
	"#.............................#..................................#.......................................OOOOOOOOOOOOOO#",
	"#.............................#..................................#.......................................OOOOOOOOOOOOOO#",
	"#.............................#..................................#.......................................OOOOOOOOOOOOOO#",
	"#.............................#..................................#.......................................OOOO......OOOO#",
	"#.............................#..................................#.......................................OOOO......OOOO#",
	"#.............................#..................................#.......................................OOOO...D..OOOO#",
	"#.............................#..................................#.......................................OOOO......OOOO#",
	"#.............................#..................................#.......................................OOOO......OOOO#",
	"#.............................#..................................#.......................................OOOOOOOOOOOOOO#",
	"#.............................#..................................#.......................................OOOOOOOOOOOOOO#",
	"#.............................#..................................#............4..................6.......OOOOOOOOOOOOOO#",
	"#.............................#......2...........................#.......................................OOOOOOOOOOOOOO#",
	"#......................................................................................................................#",
	"#......................................................................................................................#",
	"#............1..............................................3...........................................7..............#",
	"#..####................................................................................................................#",
	"#,,,,,#................................................................................................................#",
	"#,P,,,#.......................#..................................#......................5..............................#",
	"#,,,,,#.......................#..................................#.....................................................#",
	"########################################################################################################################",
]

## Who stands at each post, and which way they are looking when the test
## starts. They look round now and then (`Enemy.GLANCE_MIN`), and that is what
## there is to wait for. The one that flies holds its post in the air.
const POSTS := {
	"1": {"kind": "CRAWLER", "facing": Vector2.LEFT},
	"2": {"kind": "GUNMAN", "facing": Vector2.LEFT},
	"3": {"kind": "CRAWLER", "facing": Vector2.RIGHT},
	"4": {"kind": "GUNMAN", "facing": Vector2.RIGHT},
	"5": {"kind": "WARDEN", "facing": Vector2.LEFT},
	"6": {"kind": "DRIFTER", "facing": Vector2.LEFT},
	"7": {"kind": "GUNMAN", "facing": Vector2.LEFT},
}

func layout() -> Array:
	return LAYOUT

## The walls out of the layout, and the pits.
func _generate() -> void:
	super._generate()
	for y in rows:
		for x in cols:
			if mark_at(x, y) == "O":
				pits[_idx(x, y)] = 1

## One enemy record per post, in the shape `Room` spawns from, with the way the
## guard faces beside it: the guard in the middle of its cell.
func guard_records() -> Array:
	var out: Array = []
	for mark in POSTS:
		var post: Dictionary = POSTS[mark]
		var facing: Vector2 = post["facing"]
		for c in cells_marked(String(mark)):
			var p := stand_point(c)
			out.append({"kind": String(post["kind"]), "mod": "", "pos": [p.x, p.y],
				"facing": [facing.x, facing.y]})
	return out

## A guard put down looks the way its post says, rather than whichever way it
## happened to turn when it was made.
func _spawn_enemy(e: Dictionary) -> Enemy:
	var n := super._spawn_enemy(e)
	var way: Array = e.get("facing", [1.0, 0.0])
	n.face(Vector2(float(way[0]), float(way[1])))
	return n

func spawn_point() -> Vector2:
	var door_cells := cells_marked("P")
	return stand_point(door_cells[0] if not door_cells.is_empty() else Vector2i(2, rows - 3))

## Where the diamond lies when nobody has taken it: on the island.
func diamond_point() -> Vector2:
	var spots := cells_marked("D")
	return stand_point(spots[0] if not spots.is_empty() else Vector2i(cols - 8, 6))

## Whether `at` is in the nook the player started in.
func in_start(at: Vector2) -> bool:
	var l := to_local(at)
	var mark := mark_at(int(floor(l.x / CELL)), int(floor(l.y / CELL)))
	return mark == "," or mark == "P"
