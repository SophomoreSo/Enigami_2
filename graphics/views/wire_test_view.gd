class_name WireTestView
extends Node2D

## The wire test's screen: the camera, the HUD, and the vault's core — the
## pedestal in the vault with a light in it, which is what to reach.
##
## The ground is two screens across, so the camera goes along it after the
## body, easing after it, and never past either end. It does not go up or
## down: the ground is a screen high. What Legna Dennis's sight shows is the
## pixel camera's (`WireSight`), as it is everywhere.

var screen: WireTest
var camera: Camera2D
var pixels: PixelCamera
var hud: WireHud
var core: Core

## How quickly the camera closes on the body: the share of the way it goes in
## a second.
const FOLLOW := 5.0

func _ready() -> void:
	screen = get_parent() as WireTest
	camera = Camera2D.new()
	camera.position = Vector2(Room.W * Room.CELL, Room.H * Room.CELL) * 0.5
	add_child(camera)
	camera.make_current()
	Fx.register_camera(camera)
	pixels = PixelCamera.new()
	add_child(pixels)
	# The ground is laid once the screen is ready, which is after this is.
	if screen.is_node_ready():
		_place_core()
	else:
		screen.ready.connect(_place_core)

	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	hud = WireHud.new()
	hud.screen = screen
	layer.add_child(hud)

	screen.reached.connect(func(seconds: float) -> void: hud.show_reached(seconds))
	screen.fell.connect(func() -> void: hud.show_fell())
	screen.floor_reset.connect(func() -> void:
		hud.again()
		follow(0.0, true))
	follow(0.0, true)

func _place_core() -> void:
	var at := screen.room.core()
	core = Core.new()
	core.visibility_layer = PixelCamera.WORLD_LAYER
	core.position = Vector2(at.get_center().x, at.end.y)
	add_child(core)

func _process(delta: float) -> void:
	follow(delta, false)

## Takes the camera towards the body, by `delta`'s worth of `FOLLOW` — or all
## the way, with `snap`.
func follow(delta: float, snap: bool) -> void:
	if screen == null or not is_instance_valid(screen) or screen.room == null:
		return
	var want := camera.position
	var p := screen.player
	if p != null and is_instance_valid(p):
		want.x = p.global_position.x
	var width := float(screen.room.cols * Room.CELL)
	var half := get_viewport().get_visible_rect().size.x * 0.5
	want.x = clampf(want.x, half, width - half) if width > half * 2.0 else width * 0.5
	want.y = screen.room.rows * Room.CELL * 0.5
	camera.position = want if snap else camera.position.lerp(want, clampf(FOLLOW * delta, 0.0, 1.0))

## The pause key leaves; R sets the ground again at once.
func _unhandled_input(event: InputEvent) -> void:
	if screen == null or not is_instance_valid(screen):
		return
	if event.is_action_pressed("pause"):
		screen.leave()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.is_pressed() and not event.is_echo() \
			and (event as InputEventKey).physical_keycode == KEY_R:
		screen.reset_floor()
		get_viewport().set_input_as_handled()

## The vault's core: a steel plate on the floor and a light hanging over it,
## breathing, which lights the vault round it (`Shine`, "crystal").
class Core extends Node2D:
	const S := PixelCamera.SCALE
	const PLATE := Color(0.22, 0.25, 0.30)
	const PLATE_LIT := Color(0.40, 0.45, 0.52)
	const RIM := Color(0.06, 0.07, 0.09)
	const GLOW := Color(0.36, 0.62, 1.0)
	const HEART := Color(0.88, 0.96, 1.0)

	var _t := 0.0

	func _ready() -> void:
		Shine.give(self, "crystal", Vector2(0.0, -20.0))

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var box := func(x: int, y: int, w: int, h: int, col: Color) -> void:
			draw_rect(Rect2(Vector2(x, -y - h) * S, Vector2(w, h) * S), col)
		# The plate, a step up off the floor, and the light over it.
		box.call(-12, 0, 24, 4, RIM)
		box.call(-11, 1, 22, 2, PLATE)
		box.call(-11, 3, 22, 1, PLATE_LIT)
		var lift := int(round(sin(_t * 2.0) * 1.5))
		var breath := 0.6 + 0.4 * sin(_t * 3.0)
		box.call(-4, 8 + lift, 8, 8, Color(GLOW, 0.35 * breath))
		box.call(-3, 9 + lift, 6, 6, GLOW)
		box.call(-1, 11 + lift, 2, 2, HEART)
