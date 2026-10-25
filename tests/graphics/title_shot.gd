extends Node
## Frames of the title screen, for looking at.
##
## The title is the one screen whose whole point is that it moves, so a single
## shot says nothing about it. This walks the clock and saves a strip, which is
## the only way to see whether the light is actually running the copper.
##
## Needs a real renderer — `--headless` draws into a dummy and saves black.
## Writes to `user://shots` unless SHOTS_DIR names somewhere else.

var dir: String = "user://shots"
var layer: CanvasLayer
var title: TitleScreen

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(dir.path_join(name + ".png"))
	print("[TITLE] ", name, " -> ", dir, "" if err == OK else " FAILED (%d)" % err)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _ready() -> void:
	if OS.has_environment("SHOTS_DIR"):
		dir = OS.get_environment("SHOTS_DIR")
	DirAccess.make_dir_recursive_absolute(dir)
	GameState.reset_profile()
	seed(4242)
	layer = CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	title = TitleScreen.new()
	layer.add_child(title)
	await frames(4)

	# A strip across ten seconds: the same length as the reference loop.
	for i in 8:
		await shot("t_%d" % i)
		await frames(72)

	# The focus moves, and the marks have to move with it.
	title._buttons[1].grab_focus()
	await frames(4)
	await shot("focus_sandbox")

	# START asks for a save slot instead of leaving the screen. The rows are set
	# up to show every state one can be in: two profiles with a date on them and
	# one slot with nothing in it.
	GameState.load_slot(1)
	GameState.save_game()
	GameState.load_slot(2)
	GameState.save_game()
	GameState.delete_slot(3)
	title._start_button.emit_signal("pressed")
	await frames(6)
	await shot("save_slots")
	# And one with its trashcan armed, which is what being asked twice looks
	# like: the can turns red and the row asks instead of saying a date.
	(title._slot_rows[1]["bin"] as Button).emit_signal("pressed")
	await frames(4)
	await shot("save_slots_armed")
	title._hide_save_slots()
	await frames(4)

	title._toggle_settings()
	await frames(10)
	await shot("settings")
	title._toggle_settings()
	await frames(30)

	# The board is a few thousand draw calls a frame. Worth knowing what that
	# costs, uncapped, on the machine it is being drawn on.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await frames(60)
	var t0 := Time.get_ticks_usec()
	await frames(240)
	var ms := float(Time.get_ticks_usec() - t0) / 240000.0
	print("[TITLE] traces=%d parts=%d  %.2f ms/frame uncapped (%.0f fps)"
		% [title._traces.size(), title._parts.size(), ms, 1000.0 / maxf(ms, 0.001)])
	get_tree().quit()
