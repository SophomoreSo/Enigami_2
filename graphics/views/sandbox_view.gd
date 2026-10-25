class_name SandboxView
extends Node2D

## The bench's screen: camera, the raid's own HUD, the drawer of bench tools on
## the left and of sample skills on the right, and the same assembly overlay
## the raid uses.

var sandbox: Sandbox
var camera: Camera2D
var pixels: PixelCamera
var hud: Hud
var editor: SkillEditor
## The board, the map's page beside it, which says the bench has no map, the
## monster dictionary and the perks.
var pages: ScreenPages
## The perks' page: the screen's last tab, the perks' own (`PerkScreen`, in
## perks/view), bought with the gold banked at home as at the hideout.
var perk_screen: PerkScreen
var panel: SandboxPanel
var samples: SampleSkillsPanel

func _ready() -> void:
	sandbox = get_parent() as Sandbox
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
	# The raid's readout, the same as in a raid: a skill tried here should read
	# the way it will once it is carried.
	hud = Hud.new()
	layer.add_child(hud)
	editor = SkillEditor.new()
	editor.visible = false
	editor.closed.connect(func() -> void: sandbox.set_editing(false))
	editor.board_changed.connect(func() -> void: sandbox.on_board_changed())
	layer.add_child(editor)
	pages = ScreenPages.new(editor, func() -> void: sandbox.set_editing(false),
		ScreenTabs.PAGES_WITH_PERKS)
	perk_screen = PerkScreen.new()
	pages.add(ScreenTabs.PERKS, perk_screen)

	panel = SandboxPanel.new()
	panel.sandbox = sandbox
	layer.add_child(panel)
	samples = SampleSkillsPanel.new()
	samples.sandbox = sandbox
	layer.add_child(samples)

	sandbox.editing_changed.connect(_on_editing)

func _process(_delta: float) -> void:
	if sandbox == null or not is_instance_valid(sandbox):
		return
	hud.player = sandbox.player

## See RaidView._unhandled_input: the editor consumes its own close key. The
## map's key puts the screen up on the map's page, as it does in a raid. The
## board, the map and the dictionary answer both keys themselves; the perks'
## page does not, so over it each key puts its own page up, as in a raid.
func _unhandled_input(event: InputEvent) -> void:
	if sandbox == null or not is_instance_valid(sandbox):
		return
	if event.is_action_pressed("open_editor"):
		if sandbox.editing and pages.page != ScreenTabs.GRAPH:
			pages.put(ScreenTabs.GRAPH)
		else:
			sandbox.set_editing(not sandbox.editing)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_map"):
		if sandbox.editing:
			pages.put(ScreenTabs.MAP)
		else:
			pages.page = ScreenTabs.MAP
			sandbox.set_editing(true)
		get_viewport().set_input_as_handled()
	# Pause is deliberately not taken here. It used to walk straight out of the
	# bench, which meant a press people expect to stop the game for a moment
	# instead threw the screen away and left them in the hideout. `app/game.gd`
	# has it now, and puts the pause menu up the way it does in a raid.

func _on_editing(on: bool) -> void:
	if on:
		# Every weapon on the bench's kit, down the board's left, the one in hand
		# open.
		editor.configure_shelf(SkillEditor.shelf_of(sandbox.player), sandbox.player.weapon_id,
			sandbox.inventory, true, SkillEditor.hand_of(sandbox.player))
		pages.put(pages.page)
	# The bench controls share a canvas layer with the editor and would cover
	# the board. Nothing there is usable while assembling anyway.
	else:
		pages.away()
	panel.visible = not on
	samples.visible = not on
	# And the HUD, whose bars stand where the board's way back does.
	hud.visible = not on
