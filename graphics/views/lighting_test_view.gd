class_name LightingTestView
extends Node2D

## The lighting test's screen (`LightingTest`): a camera on the player, the
## read-outs (`LightingTestHud`), and the light the ground is seen in, which
## the keys change:
##
##   T   how dark it is: a night darker than the grove's own, so every light
##       shows; the grove's moonlight (`MapTiles.ambient`); and day.
##   C   the light on the crosshair: nothing, a lantern (a point), a
##       lightbulb (a spot, pointing down the floor) or a tube of light (an
##       area), to hold up to anyone from any side.
##   R   the ground again; ESC back to the bench.
##
## There is no sun to try: a sun throws rock's shadows all one way, and the
## ground is shut in by its walls, so one would light nothing within them.
##
## The ground is wider than the screen, so the camera goes along it after the
## player, easing after them, and never past either end.

## The light the ground is seen in, in the order T goes through them.
const TIMES := ["night", "grove", "day"]
const NIGHT := Color(0.3, 0.33, 0.45)
## What the crosshair can carry, in the order C goes through them, and the
## kind of light each gives: its row of `lights`.
const HELD := ["nothing", "lantern", "bulb", "tube"]
const HELD_KINDS := {"lantern": "lantern", "bulb": "lightbulb", "tube": "ceiling_tube"}
## The held light is drawn over every body: it is on the crosshair, not the floor.
const HELD_Z := 60
## How quickly the camera closes on the player: the share of the way it goes
## in a second.
const FOLLOW := 5.0

var screen: LightingTest
var camera: Camera2D
var pixels: PixelCamera
var hud: LightingTestHud
## Which of TIMES the ground is seen in.
var time := 0
## Which of HELD the crosshair carries.
var held := 0

var _held: HeldLight
var _t := 0.0

## The light on the crosshair, drawn as what gives it: a lantern, a lightbulb
## under its shade, or a tube.
class HeldLight extends Node2D:
	var what := "nothing"
	var t := 0.0

	func _draw() -> void:
		match what:
			"lantern":
				MadeRoomView.paint_prop(self, "L", Vector2.ZERO, float(PixelCamera.SCALE), t, 7)
			"bulb":
				MadeRoomView.paint_prop(self, "B", Vector2.ZERO, float(PixelCamera.SCALE), t, 7)
			"tube":
				MapTiles.box(self, -10, -2, 20, 2, Color(0.55, 0.62, 0.66))
				MapTiles.box(self, -9, -1, 18, 1, Color(0.86, 0.97, 1.0))

func _ready() -> void:
	screen = get_parent() as LightingTest
	camera = Camera2D.new()
	camera.position = Vector2(Room.W * Room.CELL, Room.H * Room.CELL) * 0.5
	add_child(camera)
	camera.make_current()
	Fx.register_camera(camera)
	pixels = PixelCamera.new()
	add_child(pixels)

	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	hud = LightingTestHud.new()
	hud.view = self
	layer.add_child(hud)

	_held = HeldLight.new()
	_held.visible = false
	_held.z_index = HELD_Z
	_held.visibility_layer = PixelCamera.WORLD_LAYER
	# What gives a light gives its own: no lamp brightens it and no dark dims it.
	_held.material = Lighting.glow()
	add_child(_held)

	_light_the_ground()
	screen.floor_reset.connect(func() -> void: follow(0.0, true))
	follow(0.0, true)

func _process(delta: float) -> void:
	if screen == null or not is_instance_valid(screen):
		return
	_t += delta
	follow(delta, false)
	if _held.visible:
		# The light where the crosshair is, whatever the thing it is hangs by.
		var gives: Array = Shine.on(_held)
		var off: Vector2 = (gives[0] as Shine).position if not gives.is_empty() else Vector2.ZERO
		_held.global_position = (Pointer.world_point(self) - off).round()
		_held.t = _t
		_held.queue_redraw()

## Takes the camera towards the player, by `delta`'s worth of `FOLLOW` — or
## all the way, with `snap`.
func follow(delta: float, snap: bool) -> void:
	if screen.room == null or not is_instance_valid(screen.room):
		return
	var map := Vector2(screen.room.cols, screen.room.rows) * Room.CELL
	var view := get_viewport().get_visible_rect().size
	var want := map * 0.5
	var p := screen.player
	if p != null and is_instance_valid(p):
		var at := p.vessel().global_position
		if map.x > view.x:
			want.x = clampf(at.x, view.x * 0.5, map.x - view.x * 0.5)
		if map.y > view.y:
			want.y = clampf(at.y, view.y * 0.5, map.y - view.y * 0.5)
	camera.position = want if snap else camera.position.lerp(want, clampf(FOLLOW * delta, 0.0, 1.0))

func _light_the_ground() -> void:
	match String(TIMES[time]):
		"night":
			pixels.lighting.ambient = NIGHT
		"grove":
			pixels.lighting.ambient = MapTiles.of(LightingTest.TILESET).ambient()
		_:
			pixels.lighting.ambient = Color.WHITE

## The crosshair given the light of what it carries now, or none.
func _hold() -> void:
	var what := String(HELD[held])
	Shine.put_out(_held)
	_held.what = what
	_held.visible = what != "nothing"
	if _held.visible:
		Shine.give(_held, String(HELD_KINDS[what]))
	_held.queue_redraw()

## The keys this screen answers to. Not while the pause menu is up: it is not
## this screen's then.
func _unhandled_input(event: InputEvent) -> void:
	if screen == null or not is_instance_valid(screen):
		return
	if event.is_action_pressed("pause"):
		screen.leave()
		get_viewport().set_input_as_handled()
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_T:
			time = (time + 1) % TIMES.size()
			_light_the_ground()
		KEY_C:
			held = (held + 1) % HELD.size()
			_hold()
		KEY_R:
			screen.reset_floor()
		_:
			return
	Audio.play("ui")
	get_viewport().set_input_as_handled()
