class_name RaidView
extends Node2D

## Everything a raid puts on the screen: the camera that follows it, the HUD,
## and the screen with the assembly board, the map, the monster dictionary and
## the perks on it, a tab each along its top (`ScreenTabs`) — separate nodes,
## and only ever one of them up, so going from one tab to another is the raid
## putting one away and the other up. The perks' page is the perks' own
## (`PerkScreen`, in perks/view).
##
## It pulls from the raid every frame rather than being pushed at. The raid
## therefore has no HUD to update and no editor to configure — it just runs,
## and this reads it.

var raid: Raid
var camera: Camera2D
var pixels: PixelCamera
var hud: Hud
var editor: SkillEditor
var map_panel: MapPanel
var dex: MonsterDex
var perk_screen: PerkScreen

## How quickly the camera closes on the player in a room bigger than the
## screen: the share of the way it goes in a second.
const FOLLOW := 5.0

func _ready() -> void:
	raid = get_parent() as Raid
	camera = Camera2D.new()
	camera.position = Vector2(Room.W * Room.CELL, Room.H * Room.CELL) * 0.5
	camera.zoom = Vector2.ONE
	add_child(camera)
	camera.make_current()
	Fx.register_camera(camera)
	pixels = PixelCamera.new()
	add_child(pixels)

	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	hud = Hud.new()
	layer.add_child(hud)

	editor = SkillEditor.new()
	editor.visible = false
	editor.pages = ScreenTabs.PAGES_WITH_PERKS.duplicate()
	editor.closed.connect(func() -> void: raid.set_editing(false))
	editor.page_picked.connect(_on_page_picked)
	editor.board_changed.connect(func() -> void: raid.on_board_changed())
	layer.add_child(editor)

	map_panel = MapPanel.new()
	map_panel.visible = false
	map_panel.pages = ScreenTabs.PAGES_WITH_PERKS.duplicate()
	map_panel.closed.connect(func() -> void: raid.set_reading_map(false))
	map_panel.page_picked.connect(_on_page_picked)
	layer.add_child(map_panel)

	dex = MonsterDex.new()
	dex.visible = false
	dex.pages = ScreenTabs.PAGES_WITH_PERKS.duplicate()
	dex.closed.connect(func() -> void: raid.set_reading_dex(false))
	dex.page_picked.connect(_on_page_picked)
	layer.add_child(dex)

	perk_screen = PerkScreen.new()
	perk_screen.visible = false
	perk_screen.pages = ScreenTabs.PAGES_WITH_PERKS.duplicate()
	perk_screen.closed.connect(func() -> void: raid.set_reading_perks(false))
	perk_screen.page_picked.connect(_on_page_picked)
	layer.add_child(perk_screen)

	raid.editing_changed.connect(_on_editing)
	raid.reading_map_changed.connect(_on_reading_map)
	raid.reading_dex_changed.connect(_on_reading_dex)
	raid.on_phone_changed.connect(func(_on: bool) -> void: _put_hud_away())
	raid.choosing_changed.connect(func(_on: bool) -> void: _put_hud_away())
	raid.reading_perks_changed.connect(_on_reading_perks)
	raid.cut.connect(func() -> void: _cut = true)

func _process(delta: float) -> void:
	if raid == null or not is_instance_valid(raid):
		return
	follow(delta, false)
	hud.player = raid.player
	hud.prompt = raid.prompt
	hud.extract_offered = raid.room != null and is_instance_valid(raid.room) and raid.room.extract_offered
	hud.extract_ratio = raid.extract_ratio
	map_panel.map = raid.map
	map_panel.room = raid.room

## Takes the camera towards the player by `delta`'s worth of `FOLLOW`, or all
## the way with `snap` — and all the way out of a gate (`Raid.cut`). What it
## may show is the rooms stood up (`Raid.live_rect`): along a way they are
## bigger than the screen the camera goes after the player and never past
## their edge, and a way they are no bigger it holds their middle. A doorway
## is walked through with the room beside already standing, so the picture
## rolls on across the seam.
var _cut: bool = true

func follow(delta: float, snap: bool) -> void:
	var bounds := raid.live_rect()
	if bounds.size == Vector2.ZERO:
		return
	if _cut:
		_cut = false
		snap = true
	var view := get_viewport().get_visible_rect().size
	var want := bounds.get_center()
	var p := raid.player
	if p != null and is_instance_valid(p):
		var at := p.vessel().global_position
		if bounds.size.x > view.x:
			want.x = clampf(at.x, bounds.position.x + view.x * 0.5, bounds.end.x - view.x * 0.5)
		if bounds.size.y > view.y:
			want.y = clampf(at.y, bounds.position.y + view.y * 0.5, bounds.end.y - view.y * 0.5)
	camera.position = want if snap else camera.position.lerp(want, clampf(FOLLOW * delta, 0.0, 1.0))

## Event-driven rather than polled: when the editor consumes TAB to close
## itself, this must not see the same press and open it straight back up. Each
## key is its own tab: pressed over the other page, it puts its own up instead.
func _unhandled_input(event: InputEvent) -> void:
	if raid == null or raid.ended:
		return
	if event.is_action_pressed("open_editor"):
		raid.set_editing(not raid.editing)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_map"):
		# Only ever opened from here: the window itself consumes the same press
		# to close, so this never sees the one that puts it away.
		raid.set_reading_map(true)
		get_viewport().set_input_as_handled()

## A tab along the screen's top, pressed on the page that is up: its own page
## up in that one's place.
func _on_page_picked(id: String) -> void:
	match id:
		ScreenTabs.GRAPH:
			raid.set_editing(true)
		ScreenTabs.MAP:
			raid.set_reading_map(true)
		ScreenTabs.DEX:
			raid.set_reading_dex(true)
		ScreenTabs.PERKS:
			raid.set_reading_perks(true)

func _on_editing(on: bool) -> void:
	if on:
		# The kit carried, the raid's own copy of the graph on each, down the
		# board's left — the one in hand open, as it always was.
		editor.configure_shelf(SkillEditor.shelf_of(raid.player), raid.player.weapon_id,
			GameState.raid_bag, false, SkillEditor.hand_of(raid.player))
		# The kit's own graphs, so each weapon's presets stand under its board,
		# paid for out of the bag.
		editor.presets = true
		editor.visible = true
		editor.grab_focus()
	else:
		editor.visible = false
	_put_hud_away()

func _on_reading_map(on: bool) -> void:
	map_panel.visible = on
	_put_hud_away()

func _on_reading_dex(on: bool) -> void:
	dex.visible = on
	_put_hud_away()

func _on_reading_perks(on: bool) -> void:
	perk_screen.visible = on
	_put_hud_away()

## The HUD is away while any page of the screen is up: it has the screen, and
## its top stands where the HUD's bars do. And while the phone is.
func _put_hud_away() -> void:
	hud.visible = not (raid.editing or raid.reading_map or raid.reading_dex or raid.reading_perks
		or raid.on_phone or raid.choosing)
