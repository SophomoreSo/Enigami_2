extends Node2D
## The mouse pointer the game draws for itself.
##
## The game does not move the system pointer. It drove it once, to serve a
## sensitivity setting, and on macOS that cannot be made to behave: the call
## that moves a pointer unhooks it from the mouse underneath, and keeping it on
## the window unhooks it outright. Taking the mouse moves it as well, to the
## middle of the window. `app/pointer.gd` has the whole finding. So the game
## keeps a pointer of its own instead, moves that at whatever speed the setting
## asks for, and only hides the system's while the player has the controls.
##
## What is checked here: the picture, the speed, that the system pointer stays
## wherever the hand left it, and that nothing has crept back in that moves or
## holds it — and who is doing the pointing: the system for a window, the
## player's hand in play, and the computer while it has the player, when the
## crosshair is the computer's and the system pointer is shown beside it.
##
## A window is needed: an Image would build anywhere, but a cursor is only a
## cursor once something is showing it.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[PTR] PASS ", what)
	else:
		fails += 1
		push_error("PTR FAIL: " + what)

## Colours come back off an 8-bit image a step away from what went in, so the
## comparison has to be within a step rather than exact.
func same(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 \
		and absf(a.b - b.b) < 0.01 and absf(a.a - b.a) < 0.01

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _ready() -> void:
	var was := Pointer.sensitivity
	_picture()
	_speed()
	_on_grid()
	await _in_play()
	await _left_where_it_is()
	await _taken_over()
	_hands_off()
	Pointer.set_sensitivity(was)
	print("[PTR] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

func _picture() -> void:
	var tex := Pointer.texture()
	check(tex != null, "the pointer is built rather than loaded")
	if tex == null:
		return
	var img := tex.get_image()
	var side: int = (Pointer.ART.size() + 2) * Pointer.SCALE
	check(img.get_width() == side and img.get_height() == side,
		"it is %d px square, art plus a pixel of edge all round (%dx%d)"
			% [side, img.get_width(), img.get_height()])

	var hot := Pointer.hotspot()
	check(same(img.get_pixel(int(hot.x), int(hot.y)), Pointer.INK),
		"the hotspot is the bright dot at the middle of the crosshair")
	check(img.get_pixel(0, 0).a == 0.0 and img.get_pixel(side - 1, side - 1).a == 0.0,
		"the corners are clear, so it is a crosshair and not a block")

	# The dark edge is the half of the drawing nothing writes down: it is worked
	# out from the body, so what is checked is that it got worked out at all.
	var inked := 0
	var edged := 0
	var clear := 0
	for y in side:
		for x in side:
			var c := img.get_pixel(x, y)
			if c.a == 0.0:
				clear += 1
			elif same(c, Pointer.INK):
				inked += 1
			elif same(c, Pointer.EDGE):
				edged += 1
	check(inked > 0 and edged > inked,
		"every bright pixel is carried by a darker edge (%d ink, %d edge)" % [inked, edged])
	check(clear > inked + edged, "and most of it is still see-through (%d clear)" % clear)
	check(Pointer._tex != null, "and one was built at boot")

## How far the mouse carries the game's own pointer.
func _speed() -> void:
	var bounds := Vector2(1280, 720)
	var at := Vector2(600, 400)
	var moved := Vector2(10, -6)

	Pointer.set_sensitivity(1.0)
	check(Pointer.carry(at, moved, bounds) == at + moved,
		"at 1.0 the pointer goes exactly as far as the mouse did")
	Pointer.set_sensitivity(2.0)
	check(Pointer.carry(at, moved, bounds) == at + moved * 2.0,
		"at 2.0 it goes twice as far (%s)" % str(Pointer.carry(at, moved, bounds)))
	Pointer.set_sensitivity(0.5)
	check(Pointer.carry(at, moved, bounds) == at + moved * 0.5,
		"at 0.5 it goes half as far (%s)" % str(Pointer.carry(at, moved, bounds)))

	Pointer.set_sensitivity(2.5)
	var corner := Pointer.carry(Vector2(1275, 5), Vector2(40, -40), bounds)
	check(corner.x <= bounds.x - 1.0 and corner.y >= 0.0,
		"and it is kept on the screen it is drawn on (%s)" % str(corner))

	Pointer.set_sensitivity(99.0)
	check(Pointer.sensitivity <= Pointer.MAX_SENS,
		"the setting is held between %.1f and %.1f (%.1f)"
			% [Pointer.MIN_SENS, Pointer.MAX_SENS, Pointer.sensitivity])
	Pointer.set_sensitivity(1.7)
	Pointer.sensitivity = 1.0
	Pointer.load_saved()
	check(is_equal_approx(Pointer.sensitivity, 1.7),
		"and is written down, so the desk keeps it (%.1f)" % Pointer.sensitivity)

	# Nobody has the controls in this scene, so the system is doing the
	# pointing and the game's pointer is simply where that is.
	check(not Pointer.game_is_pointing(),
		"with nobody holding the controls, the system does the pointing")
	check(Pointer._crosshair != null and not Pointer._crosshair.visible,
		"and the game's own crosshair is not drawn over it")
	check(Pointer._worn == null,
		"nor worn by the window: it points with the system's own arrow")

## A real player holding the controls, which is the only time the setting does
## anything — and the thing that has to be checked, because a settings screen is
## never in that state. Every screen the player stands on builds one of these.
func _in_play() -> void:
	var held := Player.new()
	add_child(held)
	await frames(2)
	check(Pointer.game_is_pointing(), "with the controls held, the game does the pointing")
	check(Input.mouse_mode == Input.MOUSE_MODE_HIDDEN,
		"so the game hides the system pointer (mode %d)" % Input.mouse_mode)
	check(Pointer._crosshair.visible, "and draws its own crosshair")
	check(Pointer._worn == Pointer._tex,
		"which the window wears too, for whenever its own pointer is on show")

	Pointer.set_sensitivity(2.0)
	Pointer.point = Vector2(400, 300)
	var e := InputEventMouseMotion.new()
	e.relative = Vector2(30, -10)
	Pointer._input(e)
	check(Pointer.point.is_equal_approx(Vector2(460, 280)),
		"a mouse moved (30,-10) at 2.0 carries it (60,-20) (%s)" % str(Pointer.point))

	Pointer.set_sensitivity(0.5)
	Pointer.point = Vector2(400, 300)
	Pointer._input(e)
	check(Pointer.point.is_equal_approx(Vector2(415, 295)),
		"and at 0.5, half of it (%s)" % str(Pointer.point))

	# At 1.0 it is the hidden pointer itself rather than the sum of how far that
	# has been moved, which loses whatever an edge stops and every fraction of a
	# point Godot drops, and so wanders off it.
	Pointer.set_sensitivity(1.0)
	Pointer.point = Vector2(400, 300)
	e.position = Vector2(700, 500)
	Pointer._input(e)
	check(Pointer.point.is_equal_approx(e.position),
		"and at 1.0 it is wherever the system's own pointer is (%s)" % str(Pointer.point))
	var screen := get_viewport().get_visible_rect().size
	e.position = Vector2(-40, screen.y + 100)
	Pointer._input(e)
	check(Pointer.point.is_equal_approx(Vector2(0, screen.y - 1)),
		"kept on the screen when that has left the window (%s)" % str(Pointer.point))

	await frames(2)
	check(Pointer._crosshair.position.is_equal_approx(Pointer.on_grid(Pointer.point - Pointer.hotspot())),
		"the crosshair is drawn where the game is pointing (%s)" % str(Pointer._crosshair.position))

	# And it follows the picture's grid rather than the screen's. Nothing draws
	# the world in this scene, so the slide is set by hand; in a raid the camera
	# hands one over every frame, and half of them are odd.
	var odd := Vector2(-3, -3)
	Pointer.pixel_origin = odd
	await frames(2)
	var drawn := Pointer._crosshair.position
	check(posmod(int(drawn.x - odd.x), Pointer.SCALE) == 0
			and posmod(int(drawn.y - odd.y), Pointer.SCALE) == 0,
		"and onto the odd pixels with the picture when the slide is odd (%s)" % str(drawn))
	Pointer.pixel_origin = Vector2.ZERO

	held.queue_free()
	await frames(3)
	check(not Pointer.game_is_pointing() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
		"and the system has its pointer back the moment the controls are let go")
	check(Pointer._worn == null, "as its own arrow")

## The crosshair is drawn over the picture at the picture's own scale, so it has
## to sit on the picture's grid — and that grid is not the screen's. A
## `PixelCamera` slides its image by whatever the real camera had left over, so
## the grid starts on an odd screen pixel about half the time. Snapping to the
## screen's own corner instead passed on the even half and put every art pixel
## of the crosshair across two screen ones on the odd half, which is exactly
## what `pixel_camera_test` counts.
func _on_grid() -> void:
	var s := Pointer.SCALE
	for origin: Vector2 in [Vector2.ZERO, Vector2(-2, -2), Vector2(-3, -2), Vector2(-3, -3)]:
		Pointer.pixel_origin = origin
		var on := 0
		var near := 0
		var tries := 0
		for i in 2 * s:
			for j in 2 * s:
				var at := Vector2(100.0 + float(i), 60.0 + float(j))
				var landed := Pointer.on_grid(at)
				var back := at - landed
				tries += 1
				if posmod(int(landed.x - origin.x), s) == 0 and posmod(int(landed.y - origin.y), s) == 0:
					on += 1
				# On the grid is not enough on its own — the far corner of the
				# screen is on it too. It has to be the corner `at` sits in.
				if back.x >= 0.0 and back.x < float(s) and back.y >= 0.0 and back.y < float(s):
					near += 1
		check(on == tries and near == tries,
			"with the picture's grid starting at %s, the crosshair lands on the corner it is in (%d and %d of %d)"
				% [str(origin), on, near, tries])
	Pointer.pixel_origin = Vector2.ZERO

## Neither taking the controls nor letting go of them moves the system pointer.
## Taking the mouse parked it in the middle of the window, so every menu opened
## with the pointer there, and putting it back under the crosshair on the way
## out was a move as well. Hidden, it stays wherever the hand leaves it: here,
## where no hand is on the mouse, exactly where it was — with the crosshair
## somewhere else entirely, which is where the hand-back used to put it.
func _left_where_it_is() -> void:
	var before := DisplayServer.mouse_get_position()
	var held := Player.new()
	add_child(held)
	await frames(2)
	var hid := DisplayServer.mouse_get_position()
	check(Input.mouse_mode == Input.MOUSE_MODE_HIDDEN and hid == before,
		"taking the controls hides the system pointer where it is (%s, was %s)"
			% [str(hid), str(before)])
	Pointer.point = Vector2(260, 180)
	held.queue_free()
	await frames(3)
	var back := DisplayServer.mouse_get_position()
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and back == before,
		"and letting go shows it there again, not under the crosshair or in the middle (%s, was %s)"
			% [str(back), str(before)])

## The computer with the controls: the game holding the player — a conversation,
## a stun — or something playing them in their place. Both pointers are on the
## screen then. The crosshair stays and is the computer's, so the mouse does not
## move it, and the system pointer is shown beside it as its own arrow. A window
## over that is the system's alone, and with it put away the crosshair is back
## where the computer had it.
func _taken_over() -> void:
	Pointer.set_sensitivity(1.0)
	var screen := get_viewport().get_visible_rect().size
	var held := Player.new()
	add_child(held)
	await frames(2)
	check(Pointer.who() == Pointer.Who.HAND, "(the player has the controls, and the pointing)")
	Pointer.point = Vector2(400, 300)
	held.talk_locked = true
	await frames(2)
	check(Pointer.who() == Pointer.Who.COMPUTER and Pointer.computer_is_pointing() and Pointer.game_is_pointing(),
		"held in a conversation, the computer has the pointing")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
		"so the system pointer is in sight (mode %d)" % Input.mouse_mode)
	check(Pointer._worn == null, "as the system's own arrow, not a second crosshair")
	check(Pointer._crosshair.visible and Pointer.point.is_equal_approx(Vector2(400, 300)),
		"beside the game's crosshair, which stays where it was (%s)" % str(Pointer.point))

	var e := InputEventMouseMotion.new()
	e.relative = Vector2(30, -10)
	e.position = Vector2(700, 500)
	Pointer._input(e)
	await frames(2)
	check(Pointer.point.is_equal_approx(Vector2(400, 300)),
		"the mouse moves the system pointer and not the crosshair (%s)" % str(Pointer.point))
	Pointer.lead(Vector2(900, 200))
	await frames(2)
	check(Pointer.point.is_equal_approx(Vector2(900, 200))
			and Pointer._crosshair.position.is_equal_approx(Pointer.on_grid(Pointer.point - Pointer.hotspot())),
		"the computer leads it, and the crosshair is drawn where it was led (%s)" % str(Pointer.point))
	check(Pointer.lead(Vector2(-50, 9000)).is_equal_approx(Vector2(0, screen.y - 1)),
		"kept on the screen, as the hand's is")
	Pointer.lead(Vector2(900, 200))

	# The pause menu over it, and any other window: the system's alone.
	get_tree().paused = true
	await frames(3)
	check(Pointer.who() == Pointer.Who.SYSTEM and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE
			and Pointer._worn == null and not Pointer._crosshair.visible,
		"paused, the system pointer is the only pointer")
	get_tree().paused = false
	await frames(3)
	check(Pointer.computer_is_pointing() and Pointer._crosshair.visible
			and Pointer.point.is_equal_approx(Vector2(900, 200)),
		"and resumed, the crosshair is back where the computer had it (%s)" % str(Pointer.point))
	held.input_locked = true
	await frames(2)
	check(Pointer.who() == Pointer.Who.SYSTEM and not Pointer._crosshair.visible,
		"a screen that takes the keys is the system's too, though the conversation goes on under it")
	held.input_locked = false
	await frames(2)
	check(Pointer.computer_is_pointing() and Pointer.point.is_equal_approx(Vector2(900, 200)),
		"and put away, the computer has the pointer back where it was (%s)" % str(Pointer.point))

	# Handed back. The hand takes the pointer up where the hand is, the way it
	# does coming out of a menu — checked only if nobody at the desk moved the
	# mouse in the meantime, which no test can promise.
	var before := get_viewport().get_mouse_position()
	held.talk_locked = false
	await frames(2)
	var after := get_viewport().get_mouse_position()
	check(Pointer.who() == Pointer.Who.HAND and Input.mouse_mode == Input.MOUSE_MODE_HIDDEN
			and Pointer._crosshair.visible and Pointer._worn == Pointer._tex,
		"the conversation over, the player has the pointing and the system pointer is hidden again")
	if before.is_equal_approx(after):
		check(Pointer.point.is_equal_approx(Pointer.on_screen(after, screen)),
			"taken up where the hand is, not where the computer left it (%s)" % str(Pointer.point))

	# A stun is the game holding the player just the same.
	check(held.stun(0.25), "(a stun takes)")
	await frames(3)
	check(Pointer.computer_is_pointing() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and Pointer._crosshair.visible,
		"stunned, the crosshair stays and the system pointer is shown beside it")
	var guard := 0
	while held.stunned() and guard < 600:
		await get_tree().process_frame
		guard += 1
	await frames(3)
	check(Pointer.who() == Pointer.Who.HAND, "and come round, the pointing is the player's")

	# And something playing the player in their place points with the crosshair.
	var bot := ComputerHands.new()
	held.input.add(bot)
	await frames(2)
	check(Pointer.computer_is_pointing() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE
			and Pointer._worn == null and Pointer._crosshair.visible,
		"with the computer's hands on the player, both pointers are on the screen")
	bot.point_at(Vector2(640, 100))
	await frames(3)
	check(Pointer.point.is_equal_approx(Vector2(640, 100)),
		"and the crosshair goes where the computer points (%s)" % str(Pointer.point))
	Pointer._input(e)
	await frames(2)
	check(Pointer.point.is_equal_approx(Vector2(640, 100)), "whatever the mouse does meanwhile")
	held.input.remove(bot)
	await frames(2)
	check(Pointer.who() == Pointer.Who.HAND, "taken off, the pointing is the player's again")

	held.queue_free()
	await frames(3)
	check(Pointer.who() == Pointer.Who.SYSTEM and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE
			and not Pointer._crosshair.visible,
		"and with nobody on the screen at all, the system's")

## The rule the week cost: the system pointer is the system's. Nothing in the
## game moves it, holds it, or argues with it — and taking the mouse would move
## it, to the middle of the window, so nothing takes it either.
func _hands_off() -> void:
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
		"while the system is pointing, the pointer is visible and free")
	var src := FileAccess.get_file_as_string("res://app/pointer.gd")
	check(not src.contains("CONFINED"), "nothing in the pointer holds it on the window")
	var moving := PackedStringArray()
	for path in game_scripts("res://"):
		var code := FileAccess.get_file_as_string(path)
		if code.contains("warp_mouse") or code.contains("MOUSE_MODE_CAPTURED"):
			moving.append(path)
	check(moving.is_empty(),
		"and nothing in the game moves it or takes the mouse (%s)" % ", ".join(moving))

## Every script the game runs: all of them but the tests', which stand in for a
## hand and may move the pointer the way one would.
func game_scripts(dir: String) -> PackedStringArray:
	var found := PackedStringArray()
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() == "gd":
			found.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		if dir == "res://" and d == "tests":
			continue
		found.append_array(game_scripts(dir.path_join(d)))
	return found
