extends Node
## A room's picture at a seam (`RoomView`). With a room stood up beside it,
## the cells past that edge are that room's to draw: no wall of this one is
## laid over them, which had a player walking through walls that were not
## there. As rooms are stood up beside it and taken down, only what is past
## that side is laid again — and the picture is what laying it whole makes,
## the rock past the edge back as it was once they are gone.

var fails := 0
var raid: Raid

func check(ok: bool, what: String) -> void:
	if ok:
		print("[SEAM] PASS ", what)
	else:
		fails += 1
		push_error("SEAM FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _ready() -> void:
	GameState.reset_profile()
	for n in range(1, GameState.SAVE_SLOTS + 1):
		GameState.delete_slot(n)
	seed(20261028)
	raid = Raid.new()
	add_child(raid)
	await frames(4)
	# The rooms are stood up and taken down here, not by where the player is.
	raid.set_process(false)

	var tried := 0
	for c: Vector2i in [raid.map.entry, raid.map.entry + Vector2i(1, 0), raid.map.entry + Vector2i(0, -1)]:
		if raid.map.has_room(c):
			await _round(c)
			tried += 1
	check(tried >= 2, "rooms tried at their seams (%d)" % tried)

	print("[SEAM] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## The rooms at `coords` up, and no others, and their pictures laid.
func _only(coords: Array) -> void:
	for c in raid.rooms.keys():
		if not coords.has(c):
			raid._unload_room(c)
	for c in coords:
		if not raid.rooms.has(c):
			raid._load_room(c)
	await frames(2)

## What room `c`'s picture lays, as words: every tile of the floor and of the
## walls, and every edge it throws shadows off.
func _picture(c: Vector2i) -> String:
	var view := Views.of(raid.rooms[c]) as RoomView
	var out := ""
	for layer: TileMapLayer in [view._floor, view._walls]:
		var cells := layer.get_used_cells()
		cells.sort()
		for cell in cells:
			out += "%s%s " % [cell, layer.get_cell_atlas_coords(cell)]
		out += "| "
	if view.shadow.mesh != null:
		out += str(view.shadow.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
	return out

## The walls room `c` lays wholly over the cells of the rooms beside it: a
## wall's tile at (i, j) straddles cells i-1 and i of row j.
func _over_theirs(c: Vector2i) -> int:
	var room: Room = raid.rooms[c]
	var walls := (Views.of(room) as RoomView)._walls
	var over := 0
	for cell in walls.get_used_cells():
		if room.beside_owns(cell.x - 1, cell.y) and room.beside_owns(cell.x, cell.y):
			over += 1
	return over

## Room `c` alone, beside each room it has a doorway to in turn, beside all of
## them at once, and alone again.
func _round(c: Vector2i) -> void:
	await _only([c])
	var alone := _picture(c)
	check(alone.length() > 100, "room %s alone lays its floor and walls" % str(c))
	var all := [c]
	for side in raid.map.doors_for(c).keys():
		var b: Vector2i = c + RaidMap.dir_delta(int(side))
		if not raid.map.has_room(b):
			continue
		all.append(b)
		await _only([c, b])
		check(_over_theirs(c) == 0, "room %s lays no wall over the cells of %s beside it" % [str(c), str(b)])
		await _whole_again(c, "beside %s" % str(b))
	await _only(all)
	check(_over_theirs(c) == 0, "room %s lays no wall over the rooms all round it" % str(c))
	await _whole_again(c, "with every room round it up")
	await _only([c])
	check(_picture(c) == alone, "room %s with them taken down lays the rock past its edges as it did alone" % str(c))

## Room `c`'s picture laid again only past the sides that changed is what it
## lays laid again whole.
func _whole_again(c: Vector2i, how: String) -> void:
	var by_sides := _picture(c)
	(Views.of(raid.rooms[c]) as RoomView)._on_reshaped()
	await frames(2)
	check(_picture(c) == by_sides, "room %s %s, laid again by its sides, is the room laid whole" % [str(c), how])
