extends Node
## While somebody talks to the player in the box, the readout steps aside: the
## HUD's bars go as the box opens, and
## the bench's damage line and drawer tab go with them — the tab answering
## nothing until they are back. All of it comes back once the talking stops.
##
## Talk in a bubble is not that. The player goes on playing through it, so the
## readout stays where it is.
##
## Played on the bench with its two talkers: the apprentice, who talks free, and
## the SAGE, talked to in the box with the keys, from the press that opens the
## conversation to the answer that ends it.

const GameScript := preload("res://app/game.gd")

var fails := 0
var game: Node
var bench: Sandbox
var hud: Hud
var panel: SandboxPanel
var player: Player

func check(ok: bool, what: String) -> void:
	if ok:
		print("[TALKHUD] PASS ", what)
	else:
		fails += 1
		push_error("TALKHUD FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func until(cond: Callable, most: int = 600) -> bool:
	for i in most:
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())

## Long enough for the readout to step aside or come back, by the clock: a test
## window runs at whatever rate it likes, so a count of frames is no measure.
func settle() -> void:
	await get_tree().create_timer(Hud.STEP_ASIDE + 0.15).timeout
	await frames(2)

## An action pressed and let go the way a player does. A conversation reads it
## in a physics frame, so it is held for two.
func press(action: String) -> void:
	Input.action_press(action)
	for i in 2:
		await get_tree().physics_frame
	Input.action_release(action)
	for i in 2:
		await get_tree().physics_frame

## A thumb on the glass and straight off it, at `at` in the 1280x720 the game is
## drawn at. The drawer's tab answers a touch itself, wherever the pointer is.
func tap(at: Vector2) -> void:
	for down in [true, false]:
		var e := InputEventScreenTouch.new()
		e.index = 0
		e.position = get_window().get_final_transform() * at
		e.pressed = down
		Input.parse_input_event(e)
		await frames(2)
	await frames(3)

## Everything the readout draws is on the screen.
func all_there() -> bool:
	return hud.shown == 1.0 and is_equal_approx(hud.modulate.a, 1.0) \
		and panel.shown == 1.0 and is_equal_approx(panel.modulate.a, 1.0)

## None of it is.
func all_gone() -> bool:
	return hud.shown == 0.0 and is_zero_approx(hud.modulate.a) \
		and panel.shown == 0.0 and is_zero_approx(panel.modulate.a)

func _ready() -> void:
	var was_mode := Touch.mode
	var was_size := DisplayServer.window_get_size()
	# Not 1:1, where a design position and a window position are the same
	# number and a tap sent to the wrong one lands anyway.
	DisplayServer.window_set_size(Vector2i(1440, 810))
	# The keys. The console wears a face of its own in a conversation, which
	# `tests/mobile/talk_touch_test` plays.
	Touch.set_mode(Touch.OFF)
	GameState.reset_profile()
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(6)
	game.goto_sandbox()
	await frames(20)
	bench = game.current as Sandbox
	hud = Views.of(bench).hud
	panel = Views.of(bench).panel
	player = bench.player
	await settle()
	check(hud.player == player and all_there(), "before anybody talks the readout is all there")
	await _in_a_bubble()
	await _in_the_box()
	Touch.set_mode(was_mode)
	DisplayServer.window_set_size(was_size)
	print("[TALKHUD] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## The apprentice talks free: a bubble, and the player still playing. The bench
## stands the player by the SAGE, out of the apprentice's earshot, so walking up
## is coming into it.
func _in_a_bubble() -> void:
	var talker := bench.apprentice
	await frames(2)
	player.global_position = talker.global_position + Vector2(80.0, 0.0)
	player.velocity = Vector2.ZERO
	check(await until(func() -> bool: return talker.free_talk.is_talking()),
		"walked up to, the apprentice talks free")
	await settle()
	check(talker.free_talk.is_talking() and not player.talk_locked and all_there(),
		"and a bubble leaves the readout where it is: the player is still playing")

## The SAGE talks in the box.
func _in_the_box() -> void:
	var sage := bench.npc
	player.global_position = sage.global_position + Vector2(-Npc.TALK_SPOT, 0.0)
	player.velocity = Vector2.ZERO
	await until(func() -> bool: return sage.in_range)
	await press("interact")
	check(await until(func() -> bool: return sage.is_talking()),
		"a press by the SAGE opens a conversation in the box")
	await settle()
	check(all_gone(),
		"and the readout steps aside while it lasts: the bars, the tab and the damage line (%.2f, %.2f)"
			% [hud.shown, panel.shown])
	await tap(panel.tab_rect().get_center())
	check(not panel.is_out() and sage.is_talking(),
		"a tap where the tab was does not pull the drawer out over the conversation")

	# Talked through to the last answer, 'Nothing. Bye.', which ends it.
	for i in 8:
		if sage.is_choosing():
			break
		await press("interact")
	check(sage.is_choosing() and sage.choices().size() == 4, "the SAGE asks a question with four answers")
	await press("move_up")
	await press("interact")
	check(not sage.is_talking(), "and the last of them ends the conversation")
	await settle()
	check(all_there(), "the readout comes back once the talking stops")
	await tap(panel.tab_rect().get_center())
	check(panel.is_out(), "and the tab answers a tap again")
	panel.set_out(false)
	await settle()
