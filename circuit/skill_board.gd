class_name SkillBoard
extends RefCounted

## A grid of placed components plus the rules for placing them.
## Pure data: the simulation lives in SkillRunner.
##
## Every board is rooted. The flow starts at `root`, the cell the weapon's own
## part is filed under — the sword's DASHSLASH, the gun's PROJECTILE, a
## monster's SLASH — and whatever stands there is the source of every cycle. It
## is moved and turned like any part (`move_root`), but it never leaves the
## board and nothing is dropped on it: it is the weapon's, not the bag's, and
## the build is everything wired on round it. There is no INPUT part any more;
## the root is where a flow starts.
##
## And every board lets its flow out at one place: the middle of its right edge
## (`way_out`). A flow that leaves there is an attack; one that leaves anywhere
## else is lost. There is no OUTPUT part any more either: the edge is where a
## flow becomes an attack, and it is the board's, not the build's.
##
## A flow goes from a part into the part beside it and no further: an empty cell
## carries nothing (`follow`). So a build is a chain of parts touching, from the
## root to the way out. A weapon with nothing built on it fires because its own
## part starts against the way out; to build onto it, the part is moved back and
## the build goes in between.

signal changed()

## Where a board is rooted when whoever makes it does not say: the left end of
## the middle row of the 7x5 the game ships. A root moves like any part, so this
## is only where one starts — and where every root stood while it could not
## move, which is how a save or a code written then is read back (`deserialize`,
## `BoardCode.decode`).
const ROOT := Vector2i(0, 2)

## How a board is written down (`serialize`). A save that says none was written
## while SWIFT STRIKE and EXPLODE covered two cells each, and is read back the
## way `shrink_two_cell_parts` says.
const VERSION := 2

## The parts that covered two cells until every part came to cover one.
const ONCE_TWO_CELLS := ["DASHSLASH", "EXPLODE"]

## What one OVERCLOCK takes off a board's cycle, as a share of the cycle with
## none: the same for the first as for the tenth.
const OVERCLOCK_STEP := 0.05
## The least a board's cycle can be brought down to by OVERCLOCKs, as a share of
## the cycle with none. Reached at twelve; a thirteenth does nothing.
const OVERCLOCK_FLOOR := 0.4

var width: int = 7
var height: int = 5
var skill_name: String = "Skill"

## Vector2i -> { "id": String, "rot": int }. Only origin cells are stored here.
var cells: Dictionary = {}
## Vector2i -> Vector2i origin, for every covered cell (including origins).
var occupancy: Dictionary = {}
## The cell the root is filed under: where the flow starts. It goes where the
## root goes (`move_root`), and nothing stands there on a board with no root.
var root: Vector2i = ROOT

func _init(w: int = 7, h: int = 5, n: String = "Skill") -> void:
	width = w
	height = h
	skill_name = n

func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height

func origin_at(c: Vector2i) -> Variant:
	return occupancy.get(c, null)

func comp_at(c: Vector2i) -> Dictionary:
	var o = occupancy.get(c, null)
	if o == null:
		return {}
	return cells.get(o, {})

## Component whose ORIGIN is exactly this cell (flows may only enter at origins).
func comp_origin_at(c: Vector2i) -> Dictionary:
	return cells.get(c, {})

## --- the root ---------------------------------------------------------------

## Whether the part filed under `origin` is the root: the weapon's own part.
func is_root(origin: Vector2i) -> bool:
	return origin == root and cells.has(root)

func has_root() -> bool:
	return cells.has(root)

## The root's cell, or null while nothing sits there.
func find_root() -> Variant:
	if cells.has(root):
		return root
	return null

## The part at the root: {id, rot}, or {} while nothing sits there.
func root_entry() -> Dictionary:
	return cells.get(root, {})

## Roots the board at `at` with `id`, facing `rot`. Whatever was the root
## before goes, and so does anything standing where the new one will: this is
## for whoever makes a board — a weapon, a monster, a test. A hand on the
## workbench moves the root with `move_root`, which never knocks anything off.
func set_root(id: String, at: Vector2i = ROOT, rot: int = 0) -> bool:
	if not Components.exists(id):
		return false
	var cover := Components.footprint(id, at, rot)
	for c in cover:
		if not in_bounds(c):
			return false
	if cells.has(root):
		_erase_origin(root)
	root = at
	for c in cover:
		var o = occupancy.get(c, null)
		if o != null:
			_erase_origin(o)
	cells[at] = {"id": id, "rot": rot}
	for c in cover:
		occupancy[c] = at
	changed.emit()
	return true

## Whether the root could stand at `at`, facing `rot`: on the grid, and over
## nothing but its own cells.
func can_move_root(at: Vector2i, rot: int) -> bool:
	var entry := root_entry()
	if entry.is_empty():
		return false
	for c in Components.footprint(String(entry["id"]), at, rot):
		if not in_bounds(c):
			return false
		var o = occupancy.get(c, null)
		if o != null and o != root:
			return false
	return true

## The root moved to `at` and turned to face `rot`, as a hand on the workbench
## moves it — or only turned, with `at` the cell it is filed under. It is never
## set down over another part: false, with nothing moved, when there is no room.
func move_root(at: Vector2i, rot: int) -> bool:
	if not can_move_root(at, rot):
		return false
	var id := String(root_entry()["id"])
	_erase_origin(root)
	root = at
	cells[at] = {"id": id, "rot": rot}
	for c in Components.footprint(id, at, rot):
		occupancy[c] = at
	changed.emit()
	return true

## --- the way out --------------------------------------------------------------

## The row the way out is on: the middle one — of an even number of rows, the
## upper of the two in the middle.
static func middle(rows: int) -> int:
	@warning_ignore("integer_division")
	return (rows - 1) / 2

## The cell a flow leaves the board from, heading east: the middle of the right
## edge. Whatever leaves this cell eastward is the board's attack.
func way_out() -> Vector2i:
	return Vector2i(width - 1, middle(height))

## Where a flow goes, sent out of `from` — the cell a part emits from — heading
## `dir`: into the cell beside it, and no further. What comes back is that port,
## as everything else here reads it:
##
##   from, dir  where it set off, and which way
##   out        true when it left the board by the way out, and is an attack
##   to, id     the part in that cell, taken or not, and the cell
##   why        what stopped it, or "" when nothing did:
##
##     edge    it ran off the board, anywhere but the way out
##     empty   there is nothing there to take it
##     side    the tail half of a two-cell part, which has no port
##     facing  the part there sends its own flow back this way
##
## So a port with no `why` either went `out` or landed on `to`. One place knows
## how a port resolves — the walk in `trace`, the loop check and the runner all
## ask here — so no two of them can come to different answers about one flow.
func follow(from: Vector2i, dir: int) -> Dictionary:
	var port := {"from": from, "dir": dir, "why": ""}
	var next := from + Components.dir_to_vec(dir)
	if not in_bounds(next):
		if dir == Components.E and from == way_out():
			port["out"] = true
		else:
			port["why"] = "edge"
		return port
	var occ = occupancy.get(next, null)
	if occ == null:
		port["why"] = "empty"
		return port
	var met: Dictionary = cells[occ]
	port["to"] = next
	port["id"] = String(met["id"])
	if occ != next:
		port["why"] = "side"
	elif not Components.world_inputs(String(met["id"]), int(met["rot"])).has(Components.opposite(dir)):
		port["why"] = "facing"
	return port

## Everything on the board moved by `by`, the root with it. Only ever asked for
## a move that keeps every part on the grid.
func _shift(by: Vector2i) -> void:
	if by == Vector2i.ZERO:
		return
	var moved: Dictionary = {}
	for origin in cells:
		moved[origin + by] = cells[origin]
	cells = moved
	var covered: Dictionary = {}
	for c in occupancy:
		covered[c + by] = occupancy[c] + by
	occupancy = covered
	root += by
	changed.emit()

## A board from before the OUTPUT was retired, put where its flow used to end.
## `outputs` is every cell an OUTPUT stood in. An OUTPUT was where a flow became
## an attack, and the way out is that now, so a board whose one OUTPUT took its
## flow heading east from the part beside it is slid along until that OUTPUT's
## cell is just past the way out: the flow that fed it then leaves the board
## there, and the build fires as it did. Anything else stays where it was and
## shows where its flow now stops — no OUTPUT or more than one, one fed some
## other way or by nothing, or a build that would not fit slid that far.
func slide_onto_way_out(outputs: Array) -> void:
	if outputs.size() != 1:
		return
	var at: Vector2i = outputs[0]
	var fed := 0
	for origin in cells:
		for port in _ports_from(origin):
			if port["from"] + Components.dir_to_vec(int(port["dir"])) != at:
				continue
			if int(port["dir"]) != Components.E:
				return
			fed += 1
	if fed != 1:
		return
	var by := way_out() + Vector2i(1, 0) - at
	for origin in cells:
		var entry: Dictionary = cells[origin]
		for c in Components.footprint(String(entry["id"]), origin + by, int(entry["rot"])):
			if not in_bounds(c):
				return
	_shift(by)

## A board from before every part covered one cell, its flow joined up again.
## A SWIFT STRIKE or an EXPLODE stood across two cells then: the one it is filed
## under, where its flow came in, and the next one along the way it faces,
## where its flow went out. It reads back covering the first alone, with the
## cell its flow left by empty and nothing carrying the flow over it — so it
## is moved on into that cell. Whatever it handed its flow to, it hands it to
## still, and the build in front of a sword's root goes on from it as it did;
## anything that fed it runs into the cell it left, which is where to mend it.
func shrink_two_cell_parts() -> void:
	var moves: Array = []
	for origin in cells:
		var entry: Dictionary = cells[origin]
		if not ONCE_TWO_CELLS.has(String(entry["id"])):
			continue
		var facing := Components.rotate_dir(Components.E, int(entry["rot"]))
		var ahead: Vector2i = origin + Components.dir_to_vec(facing)
		if in_bounds(ahead) and not occupancy.has(ahead):
			moves.append([origin, ahead])
	for move in moves:
		var origin: Vector2i = move[0]
		var ahead: Vector2i = move[1]
		var id := String(cells[origin]["id"])
		var rot := int(cells[origin]["rot"])
		if origin == root:
			move_root(ahead, rot)
		elif can_place(id, ahead, rot):
			_erase_origin(origin)
			place(id, ahead, rot)

## --- placing ----------------------------------------------------------------

func can_place(id: String, origin: Vector2i, rot: int) -> bool:
	if not Components.exists(id):
		return false
	# The root is the weapon's: nothing is dropped on it. Whoever makes the
	# board roots it (`set_root`), and a hand only ever moves it (`move_root`).
	if origin == root and cells.has(root):
		return false
	for c in Components.footprint(id, origin, rot):
		if not in_bounds(c):
			return false
		var o = occupancy.get(c, null)
		if o != null and o != origin:
			return false
	return true

func place(id: String, origin: Vector2i, rot: int) -> bool:
	if not can_place(id, origin, rot):
		return false
	erase_at(origin)
	cells[origin] = {"id": id, "rot": rot}
	for c in Components.footprint(id, origin, rot):
		occupancy[c] = origin
	changed.emit()
	return true

## Removes whatever covers `c` (clicking any cell of a two-cell part removes
## it), and says what it was — or "" for an empty cell, and for the root, which
## is never removed this way.
func erase_at(c: Vector2i) -> String:
	var o = occupancy.get(c, null)
	if o == null or o == root:
		return ""
	return _erase_origin(o)

## The part filed under `o`, taken off the board, root or not.
func _erase_origin(o: Vector2i) -> String:
	var entry: Dictionary = cells.get(o, {})
	if entry.is_empty():
		return ""
	var id: String = entry["id"]
	for cc in Components.footprint(id, o, entry["rot"]):
		occupancy.erase(cc)
	cells.erase(o)
	changed.emit()
	return id

func _count_of(id: String) -> int:
	var n := 0
	for c in cells:
		if cells[c]["id"] == id:
			n += 1
	return n

## id -> count of every component the build put on the board. The root is not
## among them: it is the weapon's, and neither came out of a pool nor goes back
## into one.
func used_components() -> Dictionary:
	var used: Dictionary = {}
	for c in cells:
		if c == root:
			continue
		var id: String = cells[c]["id"]
		used[id] = int(used.get(id, 0)) + 1
	return used

## Static properties the runner and the editor both need.
##
## Overclock speeds the board's clock up. Every one takes the same share of the
## board's own cycle off, OVERCLOCK_STEP, until the cycle is down to
## OVERCLOCK_FLOOR of what it was; past that one more does nothing. The clock is
## what carries it, so the walk and the wait after it shrink together and the
## preview reads it off the same walk as the game.
func analyze() -> Dictionary:
	var oc := _count_of("OVERCLOCK")
	var speed := 1.0 / maxf(1.0 - OVERCLOCK_STEP * float(oc), OVERCLOCK_FLOOR)
	var forms := 0
	for c in cells:
		if Components.get_def(cells[c]["id"]).get("cat", "") == Components.CAT_FORM:
			forms += 1
	return {
		"overclock": oc,
		"speed_mul": speed,
		"forms": forms,
		"cells_used": occupancy.size(),
		"has_root": has_root(),
	}

## Walks the board exactly as the runner will, reporting what is actually
## wired up. This is what lets the editor show a break instead of leaving the
## player to work out why a board that looks connected produces nothing.
##
## Returns:
##   reachable  origin -> true, for every part the flow can actually get to
##   links      [exit_cell, entry_cell] pairs that genuinely carry flow
##   outs       the ports whose flow leaves by the way out: the board's attacks
##   breaks     joints where two parts touch but the receiving one will not
##              take the flow
##   leaks      places where the flow runs into empty space, or off the board
##              anywhere but the way out
##   gets_out   whether any flow leaves by the way out at all
##   dead       origin -> true, for every part caught in a loop with no way out
##   dead_links the links inside those loops, so the editor can draw one round
##              them instead of a box round each
func trace() -> Dictionary:
	var reachable: Dictionary = {}
	var links: Array = []
	var outs: Array = []
	var breaks: Array = []
	var leaks: Array = []
	# A loop is a property of the wiring and not of what the root happens to
	# reach, so it is found over the whole board and before the walk below.
	# Every link out of a caught part stays inside its loop — that is what being
	# caught means — so its ports are exactly the loop's own seams.
	var dead := dead_loops()
	var dead_links: Array = []
	for origin in dead:
		for port in _ports_from(origin):
			if String(port["why"]) == "" and port.has("to"):
				dead_links.append([port["from"], port["to"]])
	var start = find_root()
	if start == null:
		return {"reachable": reachable, "links": links, "outs": outs, "breaks": breaks,
			"leaks": leaks, "dead": dead, "dead_links": dead_links,
			"has_root": false, "gets_out": false}

	# Each part is queued the once, the first time the flow reaches it, so the
	# sweep is over when the board is — a ring is walked, not chased round.
	var queue: Array = [start]
	reachable[start] = true
	while not queue.is_empty():
		var origin: Vector2i = queue.pop_front()
		for port in _ports_from(origin):
			var why := String(port["why"])
			if why == "edge" or why == "empty":
				leaks.append(port)
				continue
			if why != "":
				breaks.append(port)
				continue
			if not port.has("to"):
				outs.append(port)
				continue
			var to: Vector2i = port["to"]
			links.append([port["from"], to])
			if not reachable.has(to):
				reachable[to] = true
				queue.append(to)
	return {"reachable": reachable, "links": links, "outs": outs, "breaks": breaks,
		"leaks": leaks, "dead": dead, "dead_links": dead_links,
		"has_root": true, "gets_out": not outs.is_empty()}

## Where one part's ports lead, a port at a time and each as `follow` gives it:
## its flows in the order they leave, and then a trigger's branch.
func _ports_from(origin: Vector2i) -> Array:
	var entry: Dictionary = cells.get(origin, {})
	if entry.is_empty():
		return []
	var id: String = entry["id"]
	var rot: int = entry["rot"]
	var ex := Components.exit_cell(id, origin, rot)
	var dirs: Array = Components.world_outputs(id, rot)
	var pd := Components.world_payload_out(id, rot)
	if pd >= 0:
		dirs = dirs + [pd]
	var out: Array = []
	for d in dirs:
		out.append(follow(ex, int(d)))
	return out

## Every part caught in a loop the flow can never leave, as origin -> true.
##
## A part is caught when it can reach itself and everything it can reach can
## reach it back: whatever goes in goes round and round, and nothing past it
## ever sees anything. A ring with a branch out of it is not caught — that
## branch is where the flow leaves, and a ring running its payload back through
## its own stat parts on its way out of the board is the whole point of
## building one. Nor is a ring one of whose own parts sends a flow out of the
## board: that is the same way out with no part between.
##
## Read off the whole board rather than out from the root, because a ring with
## nothing feeding it is the same trap with nothing in it yet.
##
## The exception is a part that does its work on the way in rather than by
## sending a flow out — TIME DILATION, ON PARRY. A loop with one of those in it
## fires it once a lap for as long as the pulse's life holds out, so the parts
## round it are working, not dead.
func dead_loops() -> Dictionary:
	var out: Dictionary = {}
	var links: Dictionary = {}
	var leaves: Dictionary = {}
	for origin in cells:
		var to: Array = []
		for port in _ports_from(origin):
			if String(port["why"]) != "":
				continue
			if port.has("to"):
				to.append(port["to"])
			else:
				leaves[origin] = true
		links[origin] = to
	# What each part leads to, however far away. A board is a few dozen cells at
	# most, so this is one walk per part and no cleverness.
	var reach: Dictionary = {}
	for origin in cells:
		reach[origin] = _reach_from(links, origin)
	for origin in cells:
		var seen: Dictionary = reach[origin]
		if not seen.has(origin):
			continue                                    # not on a loop at all
		var trapped := true
		for other in seen:
			if not (reach[other] as Dictionary).has(origin):
				trapped = false                         # and there is the way out
				break
			if leaves.has(other):
				trapped = false                         # round, and out of the board
				break
			if Components.acts_on_entry(String(cells[other]["id"])):
				trapped = false                         # going nowhere, but working
				break
		if trapped:
			out[origin] = true
	return out

## Everything `start` leads to, directly or through others. Seeded with what
## `start` links to rather than with `start` itself, so a part turns up in its
## own answer only when the wiring really does come back round to it.
static func _reach_from(links: Dictionary, start: Vector2i) -> Dictionary:
	var seen: Dictionary = {}
	var queue: Array = (links.get(start, []) as Array).duplicate()
	while not queue.is_empty():
		var at: Vector2i = queue.pop_front()
		if seen.has(at):
			continue
		seen[at] = true
		queue.append_array(links.get(at, []))
	return seen

## Tags describe what a board does: the `tag` of every part on it, once each.
func compute_tags() -> Array[String]:
	var t: Array[String] = []
	for c in cells:
		var tag := String(Components.get_def(String(cells[c]["id"])).get("tag", ""))
		if tag != "" and not t.has(tag):
			t.append(tag)
	return t

func is_empty() -> bool:
	return cells.is_empty()

func serialize() -> Dictionary:
	var out: Array = []
	for c in cells:
		out.append({"x": c.x, "y": c.y, "id": cells[c]["id"], "rot": cells[c]["rot"]})
	return {"version": VERSION, "w": width, "h": height, "name": skill_name,
		"root": [root.x, root.y], "cells": out}

## Reads a board back out of a save. A part the game no longer has — a WIRE, a
## BEND, an INPUT, an OUTPUT — is left out, and its cell left empty; a board
## that had an OUTPUT is then put where its flow used to end
## (`slide_onto_way_out`). A save from before a root could move wrote none
## down, and its root is where every root stood then: `ROOT`. One from before
## every part covered one cell wrote no `version` down either, and has its
## SWIFT STRIKEs and EXPLODEs moved on into the cells they let their flow out
## of (`shrink_two_cell_parts`) before its OUTPUT is looked for — the flow that
## fed one came out of those cells.
static func deserialize(d: Dictionary) -> SkillBoard:
	var b := SkillBoard.new(int(d.get("w", 7)), int(d.get("h", 5)), String(d.get("name", "Skill")))
	var at: Array = d.get("root", [])
	if at.size() == 2:
		b.root = Vector2i(int(at[0]), int(at[1]))
	var outputs: Array = []
	for e in d.get("cells", []):
		var id := Components.current_id(String(e["id"]))
		var cell := Vector2i(int(e["x"]), int(e["y"]))
		if Components.is_retired(id):
			if id == "OUTPUT":
				outputs.append(cell)
			continue
		b.place(id, cell, int(e["rot"]))
	if int(d.get("version", 1)) < 2:
		b.shrink_two_cell_parts()
	b.slide_onto_way_out(outputs)
	return b

func duplicate_board() -> SkillBoard:
	return SkillBoard.deserialize(serialize())

## A copy of this board with the root taken off it: how the board looks while
## the root is in hand, which this board never stands without.
func without_root() -> SkillBoard:
	var b := duplicate_board()
	b._erase_origin(b.root)
	return b

## How far a build drawn on `other` moves to come onto this board: its way out
## onto this one's. A build is a chain ending at the way out, so that is what
## has to line up — and a bigger board has its way out further over and lower
## down, so a build carried between two goes with it.
func _offset(other: SkillBoard) -> Vector2i:
	return way_out() - other.way_out()

## Whether every part of `other` would land inside this board's grid, moved onto
## its way out (`_offset`). The grid belongs to the workbench that grew it, not
## to the build drawn on it, so a build off a bigger one fits only if nothing
## hangs over the edge.
func fits(other: SkillBoard) -> bool:
	var by := _offset(other)
	for origin in other.cells:
		var entry: Dictionary = other.cells[origin]
		for c in Components.footprint(String(entry["id"]), origin + by, int(entry["rot"])):
			if not in_bounds(c):
				return false
	return true

## Where this board's root would stand to take `other` on, as [origin, rot]:
## where `other`'s own root hands its flow over, so the build goes on from this
## weapon's part the way it went on from its author's. The two need not be the
## same size — a part covers as many cells as its row in `parts` says — so it is
## the cells they hand the flow over from that are put together, facing the
## same way.
## With no root in `other`, or no room on the grid for this one there, it stays
## where it is. Empty on a board with no root of its own.
func _root_spot(other: SkillBoard) -> Array:
	var mine := root_entry()
	if mine.is_empty():
		return []
	var stay := [root, int(mine["rot"])]
	var theirs := other.root_entry()
	if theirs.is_empty():
		return stay
	var id := String(mine["id"])
	var rot := int(theirs["rot"])
	var hand := Components.exit_cell(String(theirs["id"]), other.root, rot) + _offset(other)
	var at := hand - Components.exit_cell(id, Vector2i.ZERO, rot)
	for c in Components.footprint(id, at, rot):
		if not in_bounds(c):
			return stay
	return [at, rot]

## The parts of `other` that would come onto this board, as [id, origin, rot]:
## everything of it that lands inside the grid and clear of where this board's
## own root will stand. A shared build carries its author's root along with the
## rest, and that one does not come: this weapon's own part takes its place.
func adoptable(other: SkillBoard) -> Array:
	var taken := {}
	var spot := _root_spot(other)
	if not spot.is_empty():
		for c in Components.footprint(String(root_entry()["id"]), spot[0], int(spot[1])):
			taken[c] = true
	var by := _offset(other)
	var out: Array = []
	for origin in other.cells:
		if other.is_root(origin):
			continue
		var entry: Dictionary = other.cells[origin]
		var id := String(entry["id"])
		var rot := int(entry["rot"])
		var clear := true
		for c in Components.footprint(id, origin + by, rot):
			if not in_bounds(c) or taken.has(c):
				clear = false
		if clear:
			out.append([id, origin + by, rot])
	return out

## What taking `other` on would cost from a pool: id -> how many of each part
## that would come onto the board.
func adoption_cost(other: SkillBoard) -> Dictionary:
	var need: Dictionary = {}
	for part in adoptable(other):
		var id := String(part[0])
		need[id] = int(need.get(id, 0)) + 1
	return need

## Takes on `other`'s parts, keeping this board's own grid, its own name and
## its own root — which is what a shared code hands over: a circuit, not the
## workbench it was drawn on, not what its author called it, and not the weapon
## it was built onto. This weapon's own part goes where the author's stood
## (`_root_spot`), so the build goes on from it.
##
## All or nothing: a build that does not fit leaves this board exactly as it
## was. The parts are moved across rather than re-`place`d because `other` is
## already a board — its footprints are clear of each other — so the only thing
## that could have been wrong is the grid, and `fits` has just settled that;
## what stood where the root now stands is left behind, see `adoptable`.
func adopt(other: SkillBoard) -> bool:
	if not fits(other):
		return false
	var spot := _root_spot(other)
	var parts := adoptable(other)
	for origin in cells.keys().duplicate():
		if origin != root:
			_erase_origin(origin)
	# The grid round the root is clear now, so it has room wherever it goes.
	if not spot.is_empty():
		move_root(spot[0], int(spot[1]))
	for part in parts:
		var id := String(part[0])
		var origin: Vector2i = part[1]
		var rot := int(part[2])
		cells[origin] = {"id": id, "rot": rot}
		for c in Components.footprint(id, origin, rot):
			occupancy[c] = origin
	changed.emit()
	return true

## Grows the grid (hideout workbench upgrades do this). It grows round what is
## on it: the new columns come in on the left, and the new rows above or below
## as the middle needs them, so a build stays against the way out — which is on
## the right edge, and goes where the edge goes. What fired before an upgrade
## fires after it.
func resize_grid(w: int, h: int) -> void:
	var grown := Vector2i(maxi(width, w), maxi(height, h))
	var by := Vector2i(grown.x - width, middle(grown.y) - middle(height))
	width = grown.x
	height = grown.y
	_shift(by)
	changed.emit()
