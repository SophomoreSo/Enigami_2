class_name WireBase
extends HandLaidRoom

## The wire test's ground: a hall two screens across, with a vault through the
## wall at its far end shut by an electric gate (`ElectricGate`), and a back
## room in the hall's far corner shut by another.
##
## Legna Dennis comes in at the hall's bottom corner. By the vault's gate a
## generator hums in plain sight (`Generator`) — and powers the back room's
## gate, not the vault's: its wire runs back under the hall's floor and up to
## the back room's door. The vault's gate is powered from the back room: its
## wire runs from the generator in there along the top of the hall and down
## the vault's wall to the gate. So the way into the vault is the wires,
## followed with the sight on (`Sight`): the vault gate's back to the back
## room; the back room's back to the generator by the vault gate, which
## crashed opens the back room; and the one in the back room crashed, which
## opens the vault. Its core is what to reach.
##
## `LAYOUT` (`HandLaidRoom`): `#` is solid, `P` is where the player starts,
## `G` a generator, a digit an electric gate across the cells marked with it —
## `1` the vault's, `2` the back room's — and `V` the vault's core. `WIRES`
## is where the wires run, the same size: a letter a wire, from the generator
## standing on a cell of it to the gate beside its other end.

const LAYOUT := [
	"################################################################################",
	"#.........#.............................#......................................#",
	"#.........#.............................#......................................#",
	"#....G....#.............................#......................................#",
	"#.........#.............................#.........##...........................#",
	"#.........#.............................#.........##...........................#",
	"#.........#.............................#......................................#",
	"####222####.............................#......................................#",
	"#.......................................#......................................#",
	"#...............###.....................#......................................#",
	"#...............###.....................1...................VV.................#",
	"#...............###.....................1...................VV.................#",
	"#.......................................1......................................#",
	"#.......................................#......................................#",
	"#...................................G...#......................................#",
	"#.......................................#......................................#",
	"#.........................###...........#...........................##.........#",
	"#.........................###...........#...........................##.........#",
	"#.........................###...........#......................................#",
	"#.P.....................................#......................................#",
	"#.......................................#......................................#",
	"################################################################################",
]

const WIRES := [
	"................................................................................",
	"................................................................................",
	"................................................................................",
	".....aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.......................................",
	"........................................a.......................................",
	"........................................a.......................................",
	"........................................a.......................................",
	"........................................a.......................................",
	".....b..................................a.......................................",
	".....b..................................a.......................................",
	".....b..........................................................................",
	".....b..........................................................................",
	".....b..........................................................................",
	".....b..........................................................................",
	".....bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb...........................................",
	"................................................................................",
	"................................................................................",
	"................................................................................",
	"................................................................................",
	"................................................................................",
	"................................................................................",
	"................................................................................",
]

## The gate the vault is shut by.
const VAULT_GATE := "1"

var generators: Array[Generator] = []
## The electric gates, by the digit marking each.
var gates: Dictionary = {}
var wires: Array[Wire] = []

func layout() -> Array:
	return LAYOUT

## The letter of the wire running through cell (x, y), or "." for none.
func wire_at(x: int, y: int) -> String:
	if y < 0 or y >= WIRES.size():
		return "."
	var row := String(WIRES[y])
	return row[x] if x >= 0 and x < row.length() else "."

## What stands on the floor: what powers what — the generators, the gates,
## and the wires from the one to the other.
func _spawn_contents() -> void:
	super._spawn_contents()
	_wire_up()

func _wire_up() -> void:
	var standing := {}
	for c in cells_marked("G"):
		var g := Generator.new()
		g.position = stand_point(c)
		add_child(g)
		generators.append(g)
		standing[c] = g
	for id in _gate_marks():
		var gate := ElectricGate.new()
		gate.across(_rect_of(cells_marked(id)))
		gates[id] = gate
	for letter in _wire_letters():
		var run := _trace(letter)
		var fed := _gate_beside(run[-1]) if not run.is_empty() else ""
		if run.is_empty() or fed == "":
			push_error("WireBase: wire %s runs from no generator or to no gate" % letter)
			continue
		var w := Wire.new()
		w.generator = standing[run[0]]
		w.powers = gates[fed]
		w.path = _through(run, _gate_cell_beside(run[-1]))
		add_child(w)
		wires.append(w)
		(gates[fed] as ElectricGate).feeds.append(w)
	# After their wires, so each comes up powered.
	for id in gates:
		add_child(gates[id])

## Every gate's digit, in the order they are first met down the layout.
func _gate_marks() -> PackedStringArray:
	var out := PackedStringArray()
	for y in rows:
		for x in cols:
			var m := mark_at(x, y)
			if m >= "1" and m <= "9" and not out.has(m):
				out.append(m)
	return out

## Every wire's letter.
func _wire_letters() -> PackedStringArray:
	var out := PackedStringArray()
	for y in rows:
		for x in cols:
			var l := wire_at(x, y)
			if l != "." and not out.has(l):
				out.append(l)
	return out

## The cells wire `letter` runs through, in order from the generator standing
## on one of them: a step at a time to the next cell beside the last that it
## runs through, until there is none.
func _trace(letter: String) -> Array[Vector2i]:
	var run: Array[Vector2i] = []
	for c in cells_marked("G"):
		if wire_at(c.x, c.y) == letter:
			run.append(c)
			break
	if run.is_empty():
		return run
	var seen := {run[0]: true}
	while true:
		var next := Vector2i(-1, -1)
		for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var c: Vector2i = run[-1] + d
			if not seen.has(c) and wire_at(c.x, c.y) == letter:
				next = c
				break
		if next.x < 0:
			break
		seen[next] = true
		run.append(next)
	return run

## The cell of a gate beside cell `c`, or (-1, -1) for none.
func _gate_cell_beside(c: Vector2i) -> Vector2i:
	for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var m := mark_at(c.x + d.x, c.y + d.y)
		if m >= "1" and m <= "9":
			return c + d
	return Vector2i(-1, -1)

## The digit of the gate beside cell `c`, or "" for none.
func _gate_beside(c: Vector2i) -> String:
	var g := _gate_cell_beside(c)
	return mark_at(g.x, g.y) if g.x >= 0 else ""

## A run of cells as a path through their middles, a point where it turns,
## and on to the edge of the gate's cell `gate` it ends beside.
static func _through(run: Array[Vector2i], gate: Vector2i) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in run.size():
		var turns := i == 0 or i == run.size() - 1 or (run[i] - run[i - 1]) != (run[i + 1] - run[i])
		if turns:
			out.append((Vector2(run[i]) + Vector2(0.5, 0.5)) * CELL)
	out.append((Vector2(run[-1] + gate) * 0.5 + Vector2(0.5, 0.5)) * CELL)
	return out

## The rect cells `cells` cover, in the room's own space.
static func _rect_of(cells: Array[Vector2i]) -> Rect2:
	var r := Rect2(Vector2(cells[0]) * CELL, Vector2.ONE * CELL)
	for c in cells:
		r = r.merge(Rect2(Vector2(c) * CELL, Vector2.ONE * CELL))
	return r

func spawn_point() -> Vector2:
	var door := cells_marked("P")
	return stand_point(door[0] if not door.is_empty() else Vector2i(2, rows - 3))

## The vault's core, in the room's own space: the middle of its cells.
func core() -> Rect2:
	return _rect_of(cells_marked("V"))

## Whether the world point `at` is on the vault's core.
func on_core(at: Vector2) -> bool:
	var l := to_local(at)
	return mark_at(int(floor(l.x / CELL)), int(floor(l.y / CELL))) == "V"

## Every generator running again, as the ground is set again; the gates come
## back up with their power.
func restore() -> void:
	for g in generators:
		g.restore()
