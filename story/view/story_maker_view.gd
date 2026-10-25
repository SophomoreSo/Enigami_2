class_name StoryMakerView
extends Node2D

## The story maker's screen (`StoryMaker`). While a story is being written it
## is the desk (`StoryDesk`), and nothing else. While one is being played FREE
## or FROZEN it is what a raid's screen is: a camera on the player, going after
## them along a map bigger than the screen and never past its edge, the raid's
## own HUD — which steps aside while they are talked to — and a line saying
## which keys talk and go back to the desk. The character's own picture, the
## prompt over their head, the box, the bars FROZEN brings in over the top and
## the bottom of the screen while it runs (`Letterbox`), and the bubble are
## their view's (`NpcView`).
## A NOVEL brings its own camera and its panel along the foot of the screen
## (`CutsceneView`), and this puts nothing over it.

## How quickly the camera closes on whoever it follows: the share of the way
## it goes in a second.
const FOLLOW := 5.0

var maker: StoryMaker
## The camera and the pixel picture, there while a story is played with a
## body in it, and struck with it: a novel is seen by its own.
var camera: Camera2D = null
var pixels: PixelCamera = null
var hud: Hud
var keys: Keys
var desk: StoryDesk
var _layer: CanvasLayer

## The keys a played story answers to, along the foot of the screen.
class Keys extends Control:
	var _px := PixelDraw.new(self)

	func _ready() -> void:
		UiKit.fill_screen(self)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		UiKit.sync_screen(self)
		queue_redraw()

	## Not on the console: a phone has none of these keys, and the pad's own
	## USE and MENU are what do the same there.
	func _draw() -> void:
		if UiKit.mobile():
			return
		var line := Loc.t("hud.story.keys")
		var at := Vector2(size.x - 24.0 - PixelDraw.text_width(line), size.y - 16.0)
		_px.text(at + Vector2(2, 2), line, Color(0, 0, 0, 0.8))
		_px.text(at, line, UiKit.DIM)

func _ready() -> void:
	maker = get_parent() as StoryMaker
	_layer = CanvasLayer.new()
	_layer.layer = 10
	add_child(_layer)
	# The raid's readout, the same as in a raid: a story is played the way it
	# will be once it is somewhere in the game.
	hud = Hud.new()
	hud.visible = false
	_layer.add_child(hud)
	keys = Keys.new()
	keys.visible = false
	_layer.add_child(keys)
	# The desk is laid once the maker has its story on it. A view is ready
	# before the node it is the picture of, and the story kept from the last
	# visit is put back in the maker's own `_ready`.
	if maker.is_node_ready():
		_lay_desk()
	else:
		maker.ready.connect(_lay_desk, CONNECT_ONE_SHOT)
	maker.playing_changed.connect(_on_playing)

func _lay_desk() -> void:
	desk = StoryDesk.new()
	desk.maker = maker
	_layer.add_child(desk)

func _process(delta: float) -> void:
	if maker == null or not is_instance_valid(maker):
		return
	hud.player = maker.player
	# A conversation framing the two of them has the camera until it hands it
	# back (`Fx.direct`), and going after the player would pull against it.
	if not Fx.directing():
		follow(delta, false)

## Takes the camera towards whoever the player is in, by `delta`'s worth of
## `FOLLOW` — or all the way, with `snap`.
func follow(delta: float, snap: bool) -> void:
	if camera == null or maker.room == null or not is_instance_valid(maker.room):
		return
	var map := Vector2(maker.room.cols, maker.room.rows) * Room.CELL
	var view := get_viewport().get_visible_rect().size
	var want := map * 0.5
	var p := maker.player
	if p != null and is_instance_valid(p):
		var at := p.vessel().global_position
		if map.x > view.x:
			want.x = clampf(at.x, view.x * 0.5, map.x - view.x * 0.5)
		if map.y > view.y:
			want.y = clampf(at.y, view.y * 0.5, map.y - view.y * 0.5)
	camera.position = want if snap else camera.position.lerp(want, clampf(FOLLOW * delta, 0.0, 1.0))

## The pause key on a played story goes back to the desk rather than into the
## pause menu: that is one more press away, from the desk. A novel answers
## the key itself, by skipping to its end (`Cutscene`), which is the same way
## back.
func _unhandled_input(event: InputEvent) -> void:
	if maker == null or not is_instance_valid(maker) or not maker.playing or maker.reading():
		return
	if event.is_action_pressed("pause"):
		maker.stop()
		get_viewport().set_input_as_handled()

func _on_playing(on: bool) -> void:
	desk.visible = not on
	if not on:
		hud.visible = false
		keys.visible = false
		_strike_camera()
		return
	# The light a map's tileset is drawn for comes back with the tilesets
	# (PLAN.md, step 15); until then a story is seen in the light every room is.
	if maker.scene != null and is_instance_valid(maker.scene):
		# A novel is seen by its own camera.
		return
	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()
	Fx.register_camera(camera)
	pixels = PixelCamera.new()
	add_child(pixels)
	hud.visible = true
	keys.visible = true
	follow(0.0, true)

func _strike_camera() -> void:
	if camera != null and is_instance_valid(camera):
		camera.queue_free()
	if pixels != null and is_instance_valid(pixels):
		pixels.queue_free()
	camera = null
	pixels = null
	Fx.register_camera(null)
