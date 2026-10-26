extends Node
## Frames of the dragon test, for looking at: the floor as it opens, a charge
## being held, the chain on its way through, the floor cleared, and the rewind.
##
## Needs a real renderer — `--headless` draws into a dummy and saves black.
## Writes to `user://shots` unless SHOTS_DIR names somewhere else.

const GameScript := preload("res://app/game.gd")
var dir: String = "user://shots"

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(dir.path_join(name + ".png"))
	print("[SHOT] ", name, " -> ", dir, "" if err == OK else " FAILED (%d)" % err)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func wait(secs: float) -> void:
	var t := 0.0
	while t < secs:
		await get_tree().process_frame
		t += get_process_delta_time()

func mouse(down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_RIGHT
	e.pressed = down
	Input.parse_input_event(e)

func _ready() -> void:
	if OS.has_environment("SHOTS_DIR"):
		dir = OS.get_environment("SHOTS_DIR")
	DirAccess.make_dir_recursive_absolute(dir)
	seed(15)
	var game := Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(6)
	game.goto_sandbox()
	await frames(10)
	(game.current as Sandbox).open_dragon_test()
	await frames(40)
	var screen: DragonTest = game.current
	await shot("20_dragon_test")

	mouse(true)
	await wait(1.6)
	await shot("21_dragon_charging")
	screen.player.charge = Player.MAX_CHARGE_TTL
	mouse(false)
	# Partway down the chain. The whole thing is over in about four tenths of a
	# second, so this has to be early to catch it running at all.
	await wait(0.18)
	await shot("22_dragon_chain")
	var guard := 0
	while screen.guards_left > 0 and guard < 600:
		await get_tree().process_frame
		guard += 1
	await wait(0.5)
	await shot("23_dragon_clear")
	await wait(DragonTest.RESET_DELAY)
	await frames(4)
	await shot("24_dragon_rewind")
	get_tree().quit()
