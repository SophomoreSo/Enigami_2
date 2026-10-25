class_name CutsceneView
extends Node2D

## Everything a directed scene puts on the screen: the camera over the stage,
## the floor it plays on — a hall seen from above, laid out of the atlas's
## floor and wall tiles round the middle of everywhere the script names
## (`AtlasTiles`) — the narration panel, and the fade the script calls for.
##
## The staging directions have already been carried out by the `Cutscene` before
## this hears anything. What arrives here on the `scene_direction` cue is the
## rest — `camera` and `fade` — which move nothing in the rules and so were left
## for the picture to answer. A new one is a case in `_direction` and a key in
## the file, with nothing to change in `feature/`.

## How far the stage's floor runs either side of the middle of the marks,
## across, and how many cells of it lie up and down the floor from there; and
## the wall along its far side, two cells of it, the top and the face.
const STAGE := 2400.0
const FLOOR_UP := 5
const FLOOR_DOWN := 4
const WALL := 2
## The rock beyond the walls, which the screen shows past the floor.
const BACK := Color(0.055, 0.062, 0.082)

var cut: Cutscene
var camera: Camera2D
var pixels: PixelCamera
var box: CutsceneBox
## The floor and the wall of a stage of the scene's own, laid once the stage
## is standing.
var _floor: TileMapLayer
var _walls: TileMapLayer
## 1 is full black. A scene opens black so a `fade: in` has something to lift.
var fade: float = 1.0
var _fade_to: float = 1.0
var _fade_rate: float = 0.0
var _curtain: ColorRect
var _directed: bool = false
## A view is attached as the scene enters the tree, which is before the scene's
## own `_ready` has read its file — so where the marks are, and therefore where
## the camera looks, is not known yet. The scene says when its stage is standing
## and this settles then, which is before the first beat can direct the camera.
var _settled: bool = false
## The middle of everywhere the script names, which is what the camera rests on
## and what the floor is laid around.
var _centre: Vector2 = Vector2.ZERO

func _ready() -> void:
	cut = get_parent() as Cutscene
	# Under the cast, who sort among themselves by their feet.
	z_index = -10
	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()
	Fx.register_camera(camera)
	pixels = PixelCamera.new()
	add_child(pixels)

	var layer := CanvasLayer.new()
	layer.layer = CutsceneBox.LAYER
	add_child(layer)
	box = CutsceneBox.new()
	box.cut = cut
	layer.add_child(box)

	# Over everything, including the panel: a fade takes the whole picture.
	var curtain_layer := CanvasLayer.new()
	curtain_layer.layer = CutsceneBox.LAYER + 1
	add_child(curtain_layer)
	_curtain = ColorRect.new()
	_curtain.color = Color(0, 0, 0, 1)
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtain_layer.add_child(_curtain)

	Cues.fired.connect(_on_cue)
	cut.finished.connect(_on_finished)

func _exit_tree() -> void:
	# A scene torn down mid-direction gives the camera back, or the screen after
	# it inherits a close-up of a room that no longer exists.
	if _directed:
		Fx.release(0.0)

func _process(delta: float) -> void:
	_settle()
	if _fade_rate > 0.0:
		fade = move_toward(fade, _fade_to, _fade_rate * delta)
	else:
		fade = _fade_to
	_curtain.color = Color(0, 0, 0, clampf(fade, 0.0, 1.0))
	queue_redraw()

func _on_cue(cue: StringName, data: Dictionary) -> void:
	if cue == &"scene_staged":
		_settle()
		return
	if cue != &"scene_direction":
		return
	var d = data.get("direction", {})
	if d is Dictionary:
		_direction(d)

## Frames the stage. A scene that says nothing about the camera is framed on the
## middle of everywhere it names, so it is in shot without the file having to
## think about it; a scene with a top-level `camera` is framed the way it asks.
## Either way this is where the camera rests, and a beat's own `camera`
## direction moves away from here and comes back to it.
func _settle() -> void:
	if _settled:
		return
	_settled = true
	var framing = cut.data.get("camera", {})
	if not framing is Dictionary:
		framing = {}
	_centre = _marks_centre()
	if (framing as Dictionary).has("focus"):
		_centre = cut.point_of(framing["focus"])
	camera.position = _centre
	camera.zoom = Vector2.ONE * maxf(float((framing as Dictionary).get("zoom", 1.0)), 0.1)
	_lay_stage()

## The middle of the marks: of the box round all of them.
func _marks_centre() -> Vector2:
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for mark in cut.marks:
		var at := cut.point_of(mark)
		low = low.min(at)
		high = high.max(at)
	if low.x > high.x:
		return Vector2.ZERO
	return (low + high) * 0.5

## The stage a scene of its own stands on: flagstones STAGE across, FLOOR_UP
## cells up the floor from the middle of the marks and FLOOR_DOWN down it, and
## a wall along the far side. A scene staged on a map's floor is drawn by the
## map, and lays none.
func _lay_stage() -> void:
	if not cut.own_stage or _floor != null:
		return
	_floor = AtlasTiles.layer(false)
	_floor.visibility_layer = PixelCamera.WORLD_LAYER
	add_child(_floor)
	_walls = AtlasTiles.layer(false)
	_walls.visibility_layer = PixelCamera.WORLD_LAYER
	add_child(_walls)
	var middle := Vector2i((_centre / Room.CELL).floor())
	var cols := int(STAGE / Room.CELL)
	@warning_ignore("integer_division")
	var left := middle.x - cols / 2
	var salt := hash(cut.scene_id) % 65536
	for x in range(left, left + cols):
		for y in range(middle.y - FLOOR_UP, middle.y + FLOOR_DOWN + 1):
			_floor.set_cell(Vector2i(x, y), AtlasTiles.SOURCE, AtlasTiles.coords(AtlasTiles.floor_at(x, y, salt)))
		for k in WALL:
			var y := middle.y - FLOOR_UP - 1 - k
			var tile := AtlasTiles.WALL_FRONT if k == 0 else AtlasTiles.WALL_TOP
			_walls.set_cell(Vector2i(x, y), AtlasTiles.SOURCE, AtlasTiles.coords(tile))

func _direction(d: Dictionary) -> void:
	if d.has("camera"):
		_camera(d["camera"])
	elif d.has("fade"):
		_fade(d)

## A `camera` direction, in the same words a dialogue line uses: what to centre
## on, how far in, how long to take, and a shake on its own that leaves the
## framing alone.
func _camera(value) -> void:
	if not value is Dictionary:
		if String(value) == "reset":
			Fx.release()
			_directed = false
		return
	var c: Dictionary = value
	if c.has("shake"):
		Fx.shake(float(c["shake"]))
		if not c.has("focus") and not c.has("zoom"):
			return
	var focus := camera.global_position
	if c.has("focus"):
		focus = cut.point_of(c["focus"])
	Fx.direct(focus, float(c.get("zoom", 1.0)), float(c.get("time", 0.4)))
	_directed = true

func _fade(d: Dictionary) -> void:
	# "in" means the picture comes in, so the black goes out.
	_fade_to = 0.0 if String(d.get("fade", "in")) == "in" else 1.0
	var time := float(d.get("time", 0.6))
	_fade_rate = 1.0 / time if time > 0.0 else 0.0
	if _fade_rate <= 0.0:
		fade = _fade_to

## However a scene ends — read through or skipped — it ends on black, so the
## screen after it is never cut to mid-shot.
func _on_finished() -> void:
	_fade_to = 1.0
	if _fade_rate <= 0.0:
		_fade_rate = 1.0 / 0.25

## --- the rock beyond --------------------------------------------------------

func _draw() -> void:
	# A scene staged on a map's floor is drawn by the map; the stage here is
	# a scene of its own, and past its floor and its wall lies rock, as far as
	# the screen goes.
	if not cut.own_stage or not _settled:
		return
	var cell := float(Room.CELL)
	var top := floorf(_centre.y / cell) * cell - float(FLOOR_UP + WALL) * cell
	var left := _centre.x - STAGE * 0.5
	draw_rect(Rect2(left, top - 900.0, STAGE, 900.0), BACK)
	draw_rect(Rect2(left, top + float(FLOOR_UP + FLOOR_DOWN + WALL + 1) * cell, STAGE, 600.0), BACK)
