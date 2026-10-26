extends Node
## Frames of the ghost test, for looking at: the ground as it opens, the
## player's hands in the gate guard, the vault with the diamond flown off its
## island, the hall from inside a Gunman, and the diamond back at the body.
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

func guard(screen: GhostTest, kind: String) -> Enemy:
	for c in screen.room.get_children():
		if c is Enemy and c.kind == kind:
			return c
	return null

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
	(game.current as Sandbox).open_ghost_test()
	await frames(40)
	var screen: GhostTest = game.current
	await shot("30_ghost_test")

	# The hands in the gate guard, walking it in.
	var gate := guard(screen, "CRAWLER")
	screen.player.possess(gate, 10.0)
	gate.global_position.x += 160.0
	await wait(0.5)
	await shot("31_ghost_in_the_gate_guard")

	# The vault, and the diamond flown off its island by the guard that flies.
	var flyer := guard(screen, "DRIFTER")
	screen.player.possess(flyer, 10.0)
	flyer.global_position = Vector2(106 * Room.CELL, 14 * Room.CELL)
	screen.diamond.take(flyer)
	await wait(1.2)
	await shot("32_ghost_diamond_flown_out")

	# The hall past the gate, from inside the Gunman watching it.
	var gunman := guard(screen, "GUNMAN")
	screen.player.possess(gunman, 10.0)
	await wait(1.2)
	await shot("33_ghost_gunman_at_the_gate")

	# Back at the body with it.
	screen.player.release()
	screen.diamond.place(screen.player.global_position)
	await wait(0.6)
	await shot("34_ghost_diamond_at_the_body")
	get_tree().quit()
