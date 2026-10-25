class_name MapMakerView
extends Node2D

## The map creator's screen (`MapMaker`). While a map is being laid it is the
## table (`MapTable`), and nothing else. While one is being played it is what a
## raid's screen is: a camera on whoever the player is in, the raid's own HUD,
## and the assembly overlay the bench uses — with a line saying which keys set
## the floor again and go back to the table. And it is seen in the light its
## tileset is drawn for (`MapTiles.ambient`): the Moonlit Grove at night, by
## its lanterns and its fires.
##
## A made map can be bigger than the screen either way, so the camera goes
## after the player both ways, easing after them, and never past the map's
## edge; a map no bigger than the screen is held in the middle of it.

## How quickly the camera closes on whoever it follows: the share of the way
## it goes in a second.
const FOLLOW := 5.0

var maker: MapMaker
var camera: Camera2D
var pixels: PixelCamera
var hud: Hud
var keys: Keys
var editor: SkillEditor
## The board and the map's page beside it, which says a played map has no
## floor plan to show.
var pages: ScreenPages
var table: MapTable

## The keys a played map answers to, along the foot of the screen.
class Keys extends Control:
	var _px := PixelDraw.new(self)

	func _ready() -> void:
		UiKit.fill_screen(self)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		UiKit.sync_screen(self)
		queue_redraw()

	## Not on the console: a phone has none of these keys, and the pad's own
	## MENU and KIT are what do the same there.
	func _draw() -> void:
		if UiKit.mobile():
			return
		var line := Loc.t("hud.maker.keys")
		var at := Vector2(size.x - 24.0 - PixelDraw.text_width(line), size.y - 16.0)
		_px.text(at + Vector2(2, 2), line, Color(0, 0, 0, 0.8))
		_px.text(at, line, UiKit.DIM)

func _ready() -> void:
	maker = get_parent() as MapMaker
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
	# The raid's readout, the same as in a raid: a map is played the way it
	# will be once it is somewhere in the game.
	hud = Hud.new()
	hud.visible = false
	layer.add_child(hud)
	keys = Keys.new()
	keys.visible = false
	layer.add_child(keys)
	editor = SkillEditor.new()
	editor.visible = false
	editor.closed.connect(func() -> void: maker.set_editing(false))
	editor.board_changed.connect(func() -> void: maker.on_board_changed())
	layer.add_child(editor)
	pages = ScreenPages.new(editor, func() -> void: maker.set_editing(false))
	# The table is laid once the maker has its map on it. A view is ready before
	# the node it is the picture of, and the map kept from the last visit is put
	# back in the maker's own `_ready`.
	if maker.is_node_ready():
		_lay_table(layer)
	else:
		maker.ready.connect(_lay_table.bind(layer), CONNECT_ONE_SHOT)

	maker.playing_changed.connect(_on_playing)
	maker.editing_changed.connect(_on_editing)
	maker.floor_reset.connect(func() -> void: follow(0.0, true))

func _lay_table(layer: CanvasLayer) -> void:
	table = MapTable.new()
	table.maker = maker
	layer.add_child(table)

func _process(delta: float) -> void:
	if maker == null or not is_instance_valid(maker):
		return
	hud.player = maker.player
	follow(delta, false)

## Takes the camera towards whoever the player is in, by `delta`'s worth of
## `FOLLOW` — or all the way, with `snap`.
func follow(delta: float, snap: bool) -> void:
	if maker.room == null or not is_instance_valid(maker.room):
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

## See RaidView._unhandled_input: the editor consumes its own keys, R included.
## Only a map being played has any here: the table has its own. The map's key
## puts the screen up on the map's page, as it does in a raid.
func _unhandled_input(event: InputEvent) -> void:
	if maker == null or not is_instance_valid(maker) or not maker.playing:
		return
	if event.is_action_pressed("open_editor"):
		maker.set_editing(not maker.editing)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_map") and not maker.editing:
		pages.page = ScreenTabs.MAP
		maker.set_editing(true)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		# Back to the table rather than into the pause menu: that is one more
		# press away, from the table.
		maker.stop()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.is_pressed() and not event.is_echo() \
			and (event as InputEventKey).physical_keycode == KEY_R and not maker.editing:
		maker.reset_floor()
		get_viewport().set_input_as_handled()

func _on_playing(on: bool) -> void:
	table.visible = not on
	hud.visible = on
	keys.visible = on
	pixels.lighting.ambient = MapTiles.of(maker.tileset).ambient() if on else Color.WHITE
	if on:
		follow(0.0, true)

func _on_editing(on: bool) -> void:
	if on:
		if maker.player != null and is_instance_valid(maker.player):
			editor.configure_shelf(SkillEditor.shelf_of(maker.player), maker.player.weapon_id,
				maker.inventory, true, SkillEditor.hand_of(maker.player))
		else:
			editor.configure(maker.board(), maker.inventory, true, null)
		pages.put(pages.page)
	else:
		pages.away()
	# The line of keys shares a layer with the editor and would lie on its foot,
	# and the HUD's bars where its way back stands.
	keys.visible = maker.playing and not on
	hud.visible = maker.playing and not on
