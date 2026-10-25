class_name StationView
extends Node2D

## A station of the hideout (`Station`), seen from above: the thing that stands
## there, drawn on the floor at the station's feet, so it sorts among the
## bodies by where it stands (`HideoutWorld.y_sort_enabled`) — a body that has
## walked up to the counter is drawn in front of it, and one up the floor
## behind it is drawn behind. The sign over it and the words on the sign are
## the room's (`HideoutWorldView`): they hang over everything, and a plate is
## no fitting.
##
## Which fitting is which station is a look, and lives here with the drawing of
## it, out of the atlas's own fittings where it has them: the rack is a board
## with the weapons hung on it, the counter a plank with the flasks it sells
## stood along it and a crate beside, the perks a plinth with a skull on it
## between two lamps, and the gate a door in the wall the station stands by,
## shut.
##
## Drawn in pixels of the buffer the world is drawn into (`PixelCamera.SCALE`),
## as the bench is (`BenchView.paint`).

const S := PixelCamera.SCALE
## What hangs on the rack, and what stands along the counter.
const RACK_WEAPONS := ["weapon_regular_sword", "weapon_axe", "weapon_bow", "weapon_knife"]
const COUNTER_FLASKS := ["flask_red", "flask_blue", "flask_green"]
## The rack's board and the counter's plank, in pixels of the buffer.
const RACK_W := 52
const RACK_H := 30
const COUNTER_W := 56
const COUNTER_H := 12
## How far the gate's door is from the station, in cells: the wall it is set in.
const GATE_WALL := 2

var station: Station
var _was_open := true

func _ready() -> void:
	station = get_parent() as Station
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

## A shut gate is drawn shut, so the picture is asked for again when that
## changes and not every frame.
func _process(_delta: float) -> void:
	if station != null and is_instance_valid(station) and station.open != _was_open:
		_was_open = station.open
		queue_redraw()

func _draw() -> void:
	if station == null or not is_instance_valid(station):
		return
	match station.id:
		"weapons":
			_draw_rack()
		"shop":
			_draw_counter()
		"perks":
			_draw_shrine()
		"gate":
			_draw_gate()
		_:
			_draw_mat()

## A block `w` by `h` pixels of the buffer, its bottom-left `x` across from the
## feet and `y` up off the floor.
func _box(x: int, y: int, w: int, h: int, col: Color) -> void:
	draw_rect(Rect2(Vector2(x, -y - h) * S, Vector2(w, h) * S), col)

## An atlas tile standing with the middle of its bottom edge at `foot`, in
## pixels of the buffer from the feet.
func _tile(name: String, foot: Vector2, tint: Color = Color.WHITE) -> void:
	var tex := Sprites.texture(name)
	if tex == null:
		return
	var size := tex.get_size() * S
	draw_texture_rect(tex, Rect2(foot * S - Vector2(size.x * 0.5, size.y), size), false, tint)

## The weapon rack: a board of dark steel with a lit rail along its top, and
## the weapons hung along it, point down.
func _draw_rack() -> void:
	@warning_ignore("integer_division")
	var left := -RACK_W / 2
	_box(left - 1, -1, RACK_W + 2, 3, Style.HIDEOUT_SHADOW)
	_box(left, 0, RACK_W, RACK_H, Style.HIDEOUT_STEEL)
	_box(left, RACK_H - 2, RACK_W, 2, Style.HIDEOUT_STEEL_LIT)
	_box(left, 2, RACK_W, 1, Style.HIDEOUT_PILLAR)
	var step := float(RACK_W - 8) / float(RACK_WEAPONS.size())
	for i in RACK_WEAPONS.size():
		var x := roundf(float(left) + 4.0 + step * (float(i) + 0.5))
		_tile(String(RACK_WEAPONS[i]), Vector2(x, -4.0))

## The counter: a plank on a dark front, the flasks it sells stood along it,
## and a crate of more beside it.
func _draw_counter() -> void:
	@warning_ignore("integer_division")
	var left := -COUNTER_W / 2
	_box(left - 1, -1, COUNTER_W + 2, 2, Style.HIDEOUT_SHADOW)
	_box(left, 0, COUNTER_W, COUNTER_H, Style.BENCH_SHADE)
	_box(left - 1, COUNTER_H, COUNTER_W + 2, 3, Style.BENCH_WOOD)
	_box(left - 1, COUNTER_H + 3, COUNTER_W + 2, 1, Style.BENCH_LIT)
	var step := float(COUNTER_W - 8) / float(COUNTER_FLASKS.size())
	for i in COUNTER_FLASKS.size():
		var x := roundf(float(left) + 4.0 + step * (float(i) + 0.5))
		_tile(String(COUNTER_FLASKS[i]), Vector2(x, -(COUNTER_H + 4)))
	_tile("crate", Vector2(float(left + COUNTER_W) + 10.0, 0.0))

## The perks: a plinth of stone with a skull on it, a lamp either side.
func _draw_shrine() -> void:
	_box(-11, -1, 22, 2, Style.HIDEOUT_SHADOW)
	_box(-10, 0, 20, 8, Style.HIDEOUT_PILLAR)
	_box(-10, 7, 20, 1, Style.HIDEOUT_STEEL_LIT)
	_tile("skull", Vector2(0.0, -8.0))
	for side in [-1.0, 1.0]:
		_tile("flask_big_yellow", Vector2(side * 18.0, 0.0))

## The gate: the door, shut, set in the wall beside the station — dimmed while
## the gate is not open — and a mat on the floor before it, where to stand.
func _draw_gate() -> void:
	_box(-12, -3, 24, 6, Style.HIDEOUT_STEEL)
	_box(-11, -2, 22, 4, Style.HIDEOUT_STEEL_LIT if station.open else Style.HIDEOUT_PILLAR)
	var wall := Vector2(GATE_WALL * Room.CELL, Room.CELL * 0.5) / S
	var tint := Color.WHITE if station.open else Color(0.55, 0.5, 0.55)
	_tile("doors_leaf_closed", wall, tint)

## Anything else: a mat to stand on.
func _draw_mat() -> void:
	_box(-12, -3, 24, 6, Style.HIDEOUT_STEEL)
