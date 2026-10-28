class_name DragonTestView
extends Node2D

## The dragon test's screen: the camera, the tape over the picture, the HUD and
## the same assembly overlay the bench uses.
##
## The building is three screens tall, so the camera goes up it after the
## Dragon, easing after him through a chain of lunges and never past the top or
## the foot of it, and is back at the door the moment the floor is set again.
##
## Katana ZERO plays its levels back as tape, so this one does too: scanlines
## and a vignette over the world, a blue wash while a charge is held, blood left
## on the floor where a guard fell, and tracking noise as the tape rewinds for
## the next go.

var screen: DragonTest
var camera: Camera2D
var pixels: PixelCamera
var editor: SkillEditor
## The board and the map's page beside it, which says the tower has no map.
var pages: ScreenPages
var hud: DragonTestHud
var tape: Tape
var stains: Stains

## How quickly the camera closes on the Dragon: the share of the way it goes in
## a second.
const FOLLOW := 5.0

func _ready() -> void:
	screen = get_parent() as DragonTest
	camera = Camera2D.new()
	camera.position = Vector2(Room.W * Room.CELL, Room.H * Room.CELL) * 0.5
	add_child(camera)
	camera.make_current()
	Fx.register_camera(camera)
	pixels = PixelCamera.new()
	add_child(pixels)

	stains = Stains.new()
	# On the world's own layer: a child of a view is not given it, and anything
	# left on the default layer is drawn a second time under the pixel picture.
	stains.visibility_layer = PixelCamera.WORLD_LAYER

	# Over the world's picture, under the HUD.
	var glass := CanvasLayer.new()
	glass.layer = PixelCamera.LAYER + 1
	add_child(glass)
	tape = Tape.new()
	tape.screen = screen
	glass.add_child(tape)

	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	hud = DragonTestHud.new()
	hud.screen = screen
	layer.add_child(hud)
	editor = SkillEditor.new()
	editor.visible = false
	editor.closed.connect(func() -> void: screen.set_editing(false))
	editor.board_changed.connect(func() -> void: screen.on_board_changed())
	layer.add_child(editor)
	pages = ScreenPages.new(editor, func() -> void: screen.set_editing(false))

	screen.editing_changed.connect(_on_editing)
	screen.cleared.connect(func(one_cast: bool) -> void: hud.show_clear(one_cast))
	screen.floor_reset.connect(_on_floor_reset)
	Cues.fired.connect(_on_cue)

## The blood lies on the building's floor: drawn by the building's own view,
## after the floor and with it, so it is under everyone standing in the halls
## and every wall — which the room's view only has once the building is up.
## The camera follows; the first frame it can, it is there at once.
func _process(delta: float) -> void:
	if screen == null or not is_instance_valid(screen):
		return
	if stains.get_parent() == null:
		var floor_view := Views.of(screen.room)
		if floor_view != null:
			stains.z_index = -1
			floor_view.add_child(stains)
	follow(delta, not _followed)

var _followed := false

## Takes the camera towards the Dragon, by `delta`'s worth of `FOLLOW` — or
## all the way, with `snap`: across as far as the building is wider than the
## screen, and up and down as far as it is taller, never past its edges.
func follow(delta: float, snap: bool) -> void:
	if screen.room == null or not is_instance_valid(screen.room):
		return
	var p := screen.player
	if p == null or not is_instance_valid(p):
		return
	_followed = true
	var size := Vector2(screen.room.cols, screen.room.rows) * Room.CELL
	var half := get_viewport().get_visible_rect().size * 0.5
	var at := p.vessel().global_position - screen.room.global_position
	var want := size * 0.5
	if size.x > half.x * 2.0:
		want.x = clampf(at.x, half.x, size.x - half.x)
	if size.y > half.y * 2.0:
		want.y = clampf(at.y, half.y, size.y - half.y)
	want += screen.room.global_position
	camera.position = want if snap else camera.position.lerp(want, clampf(FOLLOW * delta, 0.0, 1.0))

## See RaidView._unhandled_input: the editor consumes its own keys, R included.
## The map's key puts the screen up on the map's page, as it does in a raid.
func _unhandled_input(event: InputEvent) -> void:
	if screen == null or not is_instance_valid(screen):
		return
	if event.is_action_pressed("open_editor"):
		screen.set_editing(not screen.editing)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_map") and not screen.editing:
		pages.page = ScreenTabs.MAP
		screen.set_editing(true)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		screen.leave()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.is_pressed() and not event.is_echo() \
			and (event as InputEventKey).physical_keycode == KEY_R and not screen.editing:
		screen.reset_floor()
		get_viewport().set_input_as_handled()

func _on_editing(on: bool) -> void:
	if on:
		editor.configure(screen.board, screen.inventory, true, screen.player.runner)
		pages.put(pages.page)
	else:
		pages.away()
	# The read-outs share a layer with the editor and would sit on its header.
	hud.visible = not on

func _on_floor_reset() -> void:
	follow(0.0, true)
	stains.clear()
	tape.rewind = Tape.REWIND
	hud.rewind()

## A guard's blood sprays away from the cut: the player has not been carried
## through yet when the death lands, so the lunge runs from them to the guard.
func _on_cue(cue: StringName, d: Dictionary) -> void:
	if cue != &"death" or screen == null or not is_instance_valid(screen):
		return
	if not (d.get("actor") is Enemy):
		return
	var pos: Vector2 = d.get("pos", Vector2.ZERO)
	var from := screen.player.global_position
	stains.add(stains.to_local(pos) if stains.is_inside_tree() else pos,
		(pos - from).normalized() if pos.distance_to(from) > 1.0 else Vector2.RIGHT)

## Where the guards fell, splashed across the floor away from the cut. Redrawn
## only when a splash is added or wiped.
class Stains extends Node2D:
	const DARK := Color(0.32, 0.02, 0.07)
	const WET := Color(0.62, 0.04, 0.12)
	const FRESH := Color(0.86, 0.1, 0.2)

	var splats: Array = []

	func add(pos: Vector2, dir: Vector2) -> void:
		splats.append({"p": pos, "d": dir, "seed": randi()})
		queue_redraw()

	func clear() -> void:
		splats.clear()
		queue_redraw()

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		for s in splats:
			rng.seed = int(s["seed"])
			var p: Vector2 = s["p"]
			var d: Vector2 = s["d"]
			draw_circle(p, 9.0, DARK)
			for i in 18:
				var t := rng.randf()
				var q: Vector2 = p + d.rotated(rng.randf_range(-0.55, 0.55)) * (8.0 + t * 58.0)
				draw_circle(q, lerpf(6.0, 2.0, t), WET if i % 3 else FRESH)

## The glass the tape is watched through.
class Tape extends Control:
	const REWIND := 0.7
	const WASH := Color(0.2, 0.42, 1.0)

	var screen: DragonTest
	## Counts down while the tape rewinds.
	var rewind: float = 0.0

	func _ready() -> void:
		UiKit.fill_screen(self)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		UiKit.sync_screen(self)
		rewind = maxf(0.0, rewind - delta)
		queue_redraw()

	func _draw() -> void:
		var vp := size
		if screen != null and is_instance_valid(screen) and screen.player != null \
				and screen.player.charge > 0.0:
			var k := screen.player.charge_ratio()
			draw_rect(Rect2(Vector2.ZERO, vp), Color(WASH.r, WASH.g, WASH.b, 0.04 + 0.12 * k))
		if rewind > 0.0:
			var k := rewind / REWIND
			draw_rect(Rect2(Vector2.ZERO, vp), Color(0.12, 0.05, 0.22, 0.3 * k))
			for i in 7:
				draw_rect(Rect2(0.0, randf() * vp.y, vp.x, 2.0 + randf() * 8.0),
					Color(0.85, 0.85, 1.0, 0.22 * k))
		for y in range(0, int(vp.y), 4):
			draw_rect(Rect2(0.0, float(y), vp.x, 1.0), Color(0, 0, 0, 0.09))
		for i in 30:
			var k := float(i) / 30.0
			draw_rect(Rect2(Vector2(i, i) * 2.0, vp - Vector2(i, i) * 4.0),
				Color(0.02, 0.0, 0.05, 0.07 * (1.0 - k)), false, 2.0)
