class_name GhostTestView
extends Node2D

## The ghost test's screen: the camera, the HUD, and the same assembly
## overlay the bench uses, for the rock's graph.
##
## The ground is three screens across, so the camera goes along it after
## whoever the player is in — the body, or the monster their hands are in —
## easing after them, and never past either end. It does not go up or down:
## the ground is a screen high.

var screen: GhostTest
var camera: Camera2D
var pixels: PixelCamera
var editor: SkillEditor
## The board and the map's page beside it, which says the ground has no map.
var pages: ScreenPages
var hud: GhostHud

## How quickly the camera closes on whoever it follows: the share of the way
## it goes in a second.
const FOLLOW := 5.0

func _ready() -> void:
	screen = get_parent() as GhostTest
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
	hud = GhostHud.new()
	hud.screen = screen
	layer.add_child(hud)
	editor = SkillEditor.new()
	editor.visible = false
	editor.closed.connect(func() -> void: screen.set_editing(false))
	editor.board_changed.connect(func() -> void: screen.on_board_changed())
	layer.add_child(editor)
	pages = ScreenPages.new(editor, func() -> void: screen.set_editing(false))

	screen.editing_changed.connect(_on_editing)
	screen.stolen.connect(func(seconds: float) -> void: hud.show_stolen(seconds))
	screen.fell.connect(func() -> void: hud.show_fell())
	screen.floor_reset.connect(func() -> void:
		hud.again()
		follow(0.0, true))
	follow(0.0, true)

func _process(delta: float) -> void:
	follow(delta, false)

## Takes the camera towards whoever the player is in, by `delta`'s worth of
## `FOLLOW` — or all the way, with `snap`.
func follow(delta: float, snap: bool) -> void:
	if screen == null or not is_instance_valid(screen) or screen.room == null:
		return
	var want := camera.position
	var p := screen.player
	if p != null and is_instance_valid(p):
		want.x = p.vessel().global_position.x
	var width := float(screen.room.cols * Room.CELL)
	var half := get_viewport().get_visible_rect().size.x * 0.5
	want.x = clampf(want.x, half, width - half) if width > half * 2.0 else width * 0.5
	want.y = screen.room.rows * Room.CELL * 0.5
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
		editor.configure(screen.board, screen.inventory, true,
			screen.player.runner if screen.player != null and is_instance_valid(screen.player) else null)
		pages.put(pages.page)
	else:
		pages.away()
	# The read-outs share a layer with the editor and would sit on its header.
	hud.visible = not on
