extends Node
## A conversation on the glass, read and answered with thumbs alone.
##
## While somebody talks the whole screen is the page, and it is not drawn: a
## tap anywhere is interact — the line coming in out whole, or, once it is out,
## the next one — once a landing, however long the thumb stays.
##
## The box is mobile mode's: most of the width of the screen, its words twice
## the size, and each answer on a plate of its own under it. A plate is tapped
## to give its answer — lit as the thumb comes down, given as it lifts, and not
## given at all by a thumb that slides off first — and while the answers are up
## the glass is the box's: a tap anywhere but on a plate gives nothing.
##
## Played with the sandbox's SAGE, through the console's own `_input` and the
## box's, from the USE that opens the conversation to the tap that ends it —
## and with a thumb still down at either end, or resting on the glass through
## it, which does nothing to the face that comes up under it: the one that
## pressed USE does not turn the first line, and the one that tapped the last
## line away does not press DASH.

const GameScript := preload("res://app/game.gd")

var fails := 0
var game: Node
var pad: TouchPad
var npc: Npc
var player: Player

func check(ok: bool, what: String) -> void:
	if ok:
		print("[TALK] PASS ", what)
	else:
		fails += 1
		push_error("TALK FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func seconds(t: float) -> void:
	await get_tree().create_timer(t).timeout

func until(cond: Callable, most: int = 600) -> bool:
	for i in most:
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())

## A point in the 1280x720 the game is drawn at, where it lands on the window.
func on_glass(at: Vector2) -> Vector2:
	return get_window().get_final_transform() * at

## A finger landing, moving or lifting, sent the way the system sends one.
func touch(index: int, at: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = on_glass(at)
	e.pressed = pressed
	Input.parse_input_event(e)

func drag(index: int, at: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = on_glass(at)
	Input.parse_input_event(e)

## Down and straight back up.
func tap(at: Vector2) -> void:
	touch(0, at, true)
	await frames(2)
	touch(0, at, false)
	await frames(3)

func screen() -> Vector2:
	return get_viewport().get_visible_rect().size

## The middle of whichever control on the face that is up presses `action`.
func spot(action: String) -> Vector2:
	for c in TouchPad.CONTROLS:
		if pad.shown(c) and String(c.get("action", "")) == action:
			return TouchPad.area(TouchPad.placed(c, TouchPad.layout()), screen()).get_center()
	return Vector2(-1, -1)

## The plate answer `i` is on, where it stands on the screen.
func plate(i: int) -> Rect2:
	var b := box()
	return b._plates[i] if b != null and i < b._plates.size() else Rect2()

## The box the conversation is drawn in, wherever the SAGE's view keeps it.
func box() -> DialogueBox:
	var stack: Array = [npc]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is DialogueBox:
			return n
		stack.append_array(n.get_children())
	return null

func _ready() -> void:
	var was_mode := Touch.mode
	var was_size := DisplayServer.window_get_size()
	# Not 1:1. A press sent at a design position proves nothing on the one
	# window where a design position and a window position are the same number.
	DisplayServer.window_set_size(Vector2i(1440, 810))
	Touch.set_mode(Touch.ON)
	TouchPad.set_layout({}, false)
	GameState.reset_profile()
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(6)
	pad = game.touch_pad
	game.goto_sandbox()
	await frames(12)
	var sandbox := game.current as Sandbox
	npc = sandbox.npc
	player = sandbox.player
	await _opening()
	await _reading()
	await _answering()
	await _ending()
	Touch.set_mode(was_mode)
	DisplayServer.window_set_size(was_size)
	print("[TALK] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## --- opening ------------------------------------------------------------------

## USE opens it, and the thumb that pressed USE is still down as it does. Kept
## there and dragged, it does not turn the first line.
func _opening() -> void:
	await frames(2)
	# Where people stand to talk, so the press opens it at once.
	player.global_position = npc.global_position + Vector2(-Npc.TALK_SPOT, 0.0)
	player.velocity = Vector2.ZERO
	check(await until(func() -> bool: return pad.use_near), "by the SAGE, the weapon's button is USE")
	# A second thumb resting on the glass between the buttons, on nothing. The
	# page a conversation brings up is the whole screen, so it would be under it.
	var rest := Vector2(640, 300)
	touch(1, rest, true)
	await frames(2)
	check(not pad._down.has(1), "a thumb resting between the buttons is on no control")
	var use := spot("attack")
	touch(0, use, true)
	check(await until(func() -> bool: return npc.is_talking()), "and a thumb on USE opens the conversation")
	await frames(3)
	check(pad.face == TouchPad.Face.TALK, "which turns the whole screen into the page")
	drag(0, use + Vector2(-12.0, 6.0))
	drag(1, rest + Vector2(2.0, 1.0))
	await seconds(0.4)
	check(npc.node_id == "hello" and not npc.line_finished(),
		"the thumb that opened it, kept down, neither brings the first line out nor goes on")
	check(not Input.is_action_pressed("interact"),
		"and nor does the one that was resting: neither is holding anything down")
	touch(0, use, false)
	touch(1, rest, false)
	await frames(3)

## --- reading ------------------------------------------------------------------

## The page: a tap brings the line out, and the next goes on — once a landing,
## however long the thumb stays.
func _reading() -> void:
	var page := spot("interact")
	var b := box()
	check(b != null and b.thumb(), "the box is laid out for a thumb")
	check(not npc.line_finished(), "the first line is still coming in")
	await tap(page)
	check(npc.node_id == "hello" and npc.line_finished(), "a tap brings the rest of it out")
	touch(0, page, true)
	check(await until(func() -> bool: return npc.node_id == "ask", 30),
		"and the next tap goes on to the next line (%s)" % npc.node_id)
	await seconds(0.5)
	check(npc.node_id == "ask", "a thumb staying down does not go on again (%s)" % npc.node_id)
	touch(0, page, false)
	await frames(3)
	check(not Input.is_action_pressed("interact"), "lifted, it lets go")

## --- answering ----------------------------------------------------------------

## The plates: a tap on one gives its answer, and a thumb that slides off first
## gives nothing. With the answers up the page is not the console's: a tap off
## the plates, which there would give the answer lit, gives nothing either.
func _answering() -> void:
	check(await until(func() -> bool: return npc.is_choosing()) and npc.choices().size() == 4,
		"the question is out, with four answers")
	await frames(2)
	var b := box()
	check(b._plates.size() == 4, "each on a plate of its own (%d)" % b._plates.size())
	var on_screen := Rect2(Vector2.ZERO, screen())
	var sound := true
	for i in b._plates.size():
		var r := plate(i)
		sound = sound and on_screen.encloses(r) and r.size.y >= DialogueBox.PLATE \
			and r.size.x >= screen().x * 0.6
		if i > 0:
			sound = sound and r.position.y >= plate(i - 1).end.y
	check(sound, "every one on the screen, a thumb tall, most of its width, and none on another")
	check(b._choice_hint() == Loc.t("hud.dialogue.choose_touch"),
		"under them the box says to tap, not which key to press ('%s')" % b._choice_hint())

	# Off the plates a tap gives nothing, and picks nothing.
	var off := Vector2(40, 660)
	touch(0, off, true)
	await frames(2)
	check(not Input.is_action_pressed("interact"), "a thumb off the plates is not on the page")
	touch(0, off, false)
	await frames(3)
	check(npc.node_id == "ask" and npc.is_choosing() and npc.selected == 0,
		"and its tap gives nothing, and picks nothing (%s, %d)" % [npc.node_id, npc.selected])

	# A thumb that slides off its plate before it lifts gives nothing.
	touch(0, plate(1).get_center(), true)
	await frames(3)
	check(npc.selected == 1 and npc.node_id == "ask" and not b._press.is_empty(),
		"a thumb down on a plate lights its answer, and gives nothing yet (%d)" % npc.selected)
	drag(0, off)
	await frames(2)
	check(b._press.is_empty(), "slid off the plate, it is on nothing")
	touch(0, off, false)
	await frames(3)
	check(npc.node_id == "ask" and npc.is_choosing() and not Input.is_action_pressed("interact"),
		"and lifted there, it gives nothing, and was never the page's")

	# Tapped, a plate gives its answer.
	await tap(plate(0).get_center())
	check(npc.node_id == "circuits", "a tap on a plate gives its answer (%s)" % npc.node_id)

## --- ending -------------------------------------------------------------------

## Read on to the goodbye with taps. The tap that ends it is still down as the
## console comes back, and dragged over DASH it presses nothing. DASH, a key
## and nothing more: by the SAGE, HIT is USE, and a thumb come down on it
## again talks to them again.
func _ending() -> void:
	var page := spot("interact")
	await tap(page)
	check(npc.node_id == "circuits" and npc.line_finished(), "a tap brings the answer out")
	await tap(page)
	check(npc.node_id == "ask_again", "and the next goes on to another question (%s)" % npc.node_id)
	check(await until(func() -> bool: return npc.is_choosing()) and npc.choices().size() == 3,
		"which is out, with three answers")
	await frames(2)
	await tap(plate(2).get_center())
	check(npc.node_id == "bye", "and 'That's all, thanks.' is a tap away (%s)" % npc.node_id)
	await tap(page)
	check(npc.node_id == "bye" and npc.line_finished(), "the goodbye comes out")
	touch(0, page, true)
	check(await until(func() -> bool: return not npc.is_talking(), 30),
		"and a tap on it ends the conversation")
	await frames(3)
	check(pad.face == TouchPad.Face.PLAY, "and the console is the whole of it again")
	var dash := spot("dash")
	drag(0, dash)
	await frames(3)
	check(not Input.is_action_pressed("dash") and not Input.is_action_pressed("interact"),
		"the thumb that tapped it away, dragged over DASH, presses nothing")
	touch(0, dash, false)
	await frames(3)
	touch(0, dash, true)
	await frames(2)
	check(Input.is_action_pressed("dash"), "until it has lifted and come down again")
	touch(0, dash, false)
	await frames(3)
