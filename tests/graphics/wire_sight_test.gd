extends Node
## What Legna Dennis's sight shows (`WireSight`), read off the frame in the
## wire test: without it, nothing of the wires — the floor over them is the
## floor; with it, the world gone dark, a wire carrying power drawn bright and
## golden over it, and the gate it powers lit at its end; and a wire whose
## generator is crashed drawn dull, the gate at its end gone dark.
##
## Needs a real renderer: what shows is read off the frame.

const GameScript := preload("res://app/game.gd")

var fails := 0
var game: Node
var _drawn := false

func check(ok: bool, what: String) -> void:
	if ok:
		print("[SIGHT] PASS ", what)
	else:
		fails += 1
		push_error("SIGHT FAIL: " + what)

## A frame, with the window kept drawing: a covered one on macOS draws nothing.
func tick() -> void:
	await get_tree().process_frame
	if not DisplayServer.window_can_draw():
		RenderingServer.force_draw(false)

func wait(secs: float) -> void:
	var t := 0.0
	while t < secs:
		await tick()
		t += get_process_delta_time()

## The frame on screen, once one has been drawn.
func frame() -> Image:
	_drawn = false
	var t := 0.0
	while not _drawn and t < 2.0:
		await tick()
		t += get_process_delta_time()
	return get_viewport().get_texture().get_image()

## Where a point of the world lands on the screen.
func on_screen(at: Vector2) -> Vector2i:
	return Vector2i((get_viewport().get_final_transform() * get_viewport().get_canvas_transform() * at).round())

## The colour of `im` round `at`, a little square of it averaged.
func around(im: Image, at: Vector2i) -> Color:
	var sum := Color(0, 0, 0, 0)
	var n := 0
	for y in range(at.y - 1, at.y + 2):
		for x in range(at.x - 1, at.x + 2):
			if x >= 0 and y >= 0 and x < im.get_width() and y < im.get_height():
				sum += im.get_pixel(x, y)
				n += 1
	return sum / maxf(n, 1)

## How golden a colour is: red and green well over blue.
func golden(c: Color) -> float:
	return minf(c.r, c.g) - c.b

func luma(c: Color) -> float:
	return c.r * 0.299 + c.g * 0.587 + c.b * 0.114

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	RenderingServer.frame_post_draw.connect(func() -> void: _drawn = true)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	GameState.reset_profile()
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await wait(0.2)
	game.goto_wire_test()
	await wait(0.6)
	var t: WireTest = game.current
	var room := t.room
	var door: ElectricGate = room.gates["2"]
	var to_door: Wire = null
	for w: Wire in room.wires:
		if w.powers == door:
			to_door = w
	check(to_door != null, "a wire powers the back room's door")
	if to_door == null:
		_end()
		return
	# Down the hall's floor, the wire from the generator by the vault gate to
	# the back room's door; the floor away from it; and the door's beams.
	var on_wire := on_screen(room.to_global(Vector2(20.5 * Room.CELL, 14.5 * Room.CELL + 1.0)))
	var on_floor := on_screen(room.to_global(Vector2(20.5 * Room.CELL, 18.5 * Room.CELL)))
	var on_door := on_screen(door.world_span().get_center())

	var off := await frame()
	var wire_off := around(off, on_wire)
	var floor_off := around(off, on_floor)
	check(golden(wire_off) < 0.15 and absf(luma(wire_off) - luma(floor_off)) < 0.12,
		"without the sight, the floor over a wire is the floor (%s, %s)" % [wire_off, floor_off])

	game._vision_key()
	await wait(0.6)
	var seen := await frame()
	var wire_on := around(seen, on_wire)
	var floor_on := around(seen, on_floor)
	check(golden(wire_on) > 0.2, "with it, a live wire is drawn golden over the floor (%s)" % wire_on)
	check(luma(floor_on) < luma(floor_off) * 0.5,
		"and the world goes dark under it (%.2f, was %.2f)" % [luma(floor_on), luma(floor_off)])
	var door_on := around(seen, on_door)
	check(door_on.r > door_on.g + 0.3 and door_on.r > door_on.b + 0.2,
		"the gate the wire powers is lit red at its end (%s)" % door_on)

	to_door.generator.apply_damage(Generator.HEALTH)
	await wait(0.4)
	var dead := await frame()
	var wire_dead := around(dead, on_wire)
	var door_dead := around(dead, on_door)
	check(golden(wire_dead) < 0.1 and luma(wire_dead) > luma(floor_on) + 0.1,
		"its generator crashed, the wire is drawn dull: still there, no longer live (%s)" % wire_dead)
	check(door_dead.r < door_dead.b + 0.15, "and the gate at its end has gone dark (%s)" % door_dead)

	game._vision_key()
	await wait(0.6)
	var after := await frame()
	check(golden(around(after, on_wire)) < 0.15 and around(after, on_floor).s < 0.12,
		"the next press: magic off, grey, and the wires gone (%s)" % around(after, on_wire))
	_end()

func _end() -> void:
	print("[SIGHT] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
