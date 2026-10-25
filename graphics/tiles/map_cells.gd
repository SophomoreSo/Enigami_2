class_name MapCells
extends RefCounted

## A made map's cells, the way whatever draws it asks for them (`MapTiles`):
## its two layers (`MadeRoom`), read a cell at a time, the same whether they
## are a room standing in the world or a map on the creator's table.
##
## Past the map's edge the plan is wall — the map is shut in there — and
## nothing is put about it. What that wall looks like is the tileset's to say.

var cols := 0
var rows := 0
var plan := PackedStringArray()
var dressing := PackedStringArray()
## Which tileset draws them, and which region's rock the plain rock is.
var tileset := ""
var region := 0

## A room's.
static func of_room(room: MadeRoom) -> MapCells:
	return of_rows(room.plan, room.dressing, room.tileset, room.region)

## A map's on the creator's table.
static func of_maker(maker: MapMaker) -> MapCells:
	return of_rows(maker.plan(), maker.dressing(), maker.tileset, maker.region)

static func of_rows(laid: PackedStringArray, about: PackedStringArray,
		drawn_in: String = "", deep: int = 0) -> MapCells:
	var m := MapCells.new()
	m.plan = laid
	m.dressing = about
	m.rows = laid.size()
	for row in laid:
		m.cols = maxi(m.cols, row.length())
	m.tileset = drawn_in
	m.region = deep
	return m

func holds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < cols and y < rows

## The mark the plan has in cell (x, y): wall past its edge.
func ground(x: int, y: int) -> String:
	if not holds(x, y) or x >= plan[y].length():
		return MadeRoom.ROCK
	return plan[y][x]

## Whether cell (x, y) is wall: solid, whatever kind.
func solid(x: int, y: int) -> bool:
	return MadeRoom.is_ground(ground(x, y))

## Whether cell (x, y) is a pit in the floor.
func pit(x: int, y: int) -> bool:
	return ground(x, y) == MadeRoom.PIT

## What is put about cell (x, y): `.` for nothing.
func prop(x: int, y: int) -> String:
	if y < 0 or y >= dressing.size() or x < 0 or x >= dressing[y].length():
		return MadeRoom.OPEN
	return dressing[y][x]
