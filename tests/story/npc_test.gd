extends Node2D
## Talking to an NPC: interact only works up close, a press finishes a line
## still coming in before it moves on, a question waits for an answer picked
## with up and down, the answer decides what comes next, and walking away ends
## it. Attacks never treat a bystander as a target. Every conversation in the
## database reads cleanly.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[NPC] PASS ", what)
	else:
		fails += 1
		push_error("NPC FAIL: " + what)

func phys(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

## Presses an action the way a player does. A synthetic press only reads as
## just-pressed on the physics frame after it, so give it two.
func press(action: String = "interact") -> void:
	Input.action_press(action)
	await phys(2)
	Input.action_release(action)
	await phys(1)

func until(cond: Callable, limit: int = 240) -> bool:
	for i in limit:
		if cond.call():
			return true
		await get_tree().physics_frame
	return bool(cond.call())

## Waits for the current line to finish typing by itself.
func listen(n: Npc) -> void:
	var guard := 0
	while n.is_talking() and not n.line_finished() and guard < 600:
		await get_tree().physics_frame
		guard += 1

func _ready() -> void:
	var p := Player.new()
	p.collision_layer = 2
	p.collision_mask = 1
	p.position = Vector2(300, 380)
	add_child(p)
	var n := Npc.new()
	n.setup("SAGE")
	n.collision_layer = 0
	n.collision_mask = 1
	n.position = Vector2(600, 380)
	add_child(n)
	var ended := [0]
	var picks: Array = []
	var letters := [0]
	n.conversation_ended.connect(func(_n: Npc) -> void: ended[0] += 1)
	n.choice_made.connect(func(_n: Npc, from: String, i: int) -> void: picks.append([from, i]))
	Cues.fired.connect(func(cue: StringName, _d: Dictionary) -> void:
		if cue == &"talk_letter":
			letters[0] += 1)
	await phys(40)

	check(n.global_position == Vector2(600, 380) and n.motion_mode == CharacterBody2D.MOTION_MODE_FLOATING,
		"the NPC stands where it was put on the floor, and nothing pulls it anywhere")
	check(not n.is_in_group("actors"), "and is no target for attacks")

	# The database.
	check(Dialogue.ids().has("SAGE"), "the SAGE's lines are read from the database (%s)" % str(Dialogue.ids()))
	for id in Dialogue.ids():
		check(Dialogue.problems(id).is_empty(),
			"%s's conversation has no broken links or empty lines %s" % [id, str(Dialogue.problems(id))])
	var sage := Dialogue.character("SAGE")
	var filled := true
	for key in sage["nodes"]:
		for col in sage:
			if String(col).begins_with(Dialogue.LINE_DEFAULT):
				filled = filled and sage["nodes"][key].has(String(col).trim_prefix(Dialogue.LINE_DEFAULT))
	check(filled, "every line picks up the character's line_ defaults")
	check(Dialogue.character("NOBODY") == sage, "an NPC with no conversation talks like the SAGE")

	# Too far away.
	await press()
	check(not n.in_range and not n.is_talking(), "a press from across the room does nothing")

	# Up close, on the NPC's left.
	p.global_position = Vector2(560, n.global_position.y)
	await phys(2)
	check(n.in_range, "standing next to them is in range")
	check(n.facing.x < 0.0, "and they turn to face the player")
	await press()
	check(n.node_id == "hello", "a press starts the conversation at the start (%s)" % n.node_id)
	check(not n.line_finished(), "which types out rather than appearing at once")
	check(n.speaker() == "npc" and n.speaker_name() == n.display_name, "and the NPC is the one saying it")

	# Held still while listening.
	check(p.controls_locked(), "the player is held while the conversation lasts")
	var stood := p.global_position
	Input.action_press("move_left")
	Input.action_press("dash")
	await phys(12)
	Input.action_release("move_left")
	Input.action_release("dash")
	await phys(2)
	check(p.global_position.distance_to(stood) < 1.0 and n.is_talking(),
		"walking and dashing do nothing mid-conversation (moved %.1f)" % p.global_position.distance_to(stood))

	# A press mid-line finishes it without skipping ahead.
	await press()
	check(n.node_id == "hello" and n.line_finished(), "a press mid-line finishes that line")
	await press()
	check(n.node_id == "ask", "the next press follows the line on to the question")

	# A question can't be answered before it has been asked.
	await press("move_down")
	check(not n.is_choosing() and n.selected == 0, "the answers wait until the question is out")
	await listen(n)
	check(letters[0] > 0, "letters typing out are announced for a voice to follow (%d)" % letters[0])
	check(n.is_choosing() and n.choices().size() == 4, "then four answers are open (%d)" % n.choices().size())

	# Moving the highlight, wrapping both ways.
	await press("move_down")
	check(n.selected == 1, "down moves to the next answer (%d)" % n.selected)
	await press("move_up")
	await press("move_up")
	check(n.selected == 3, "up past the first wraps to the last (%d)" % n.selected)
	await press("move_down")
	check(n.selected == 0, "down past the last wraps to the first (%d)" % n.selected)

	# The answer decides what comes next.
	await press("move_down")
	await press()
	check(n.node_id == "charge", "picking 'What does charging do?' leads to its answer (%s)" % n.node_id)
	check(picks.size() == 1 and picks[0] == ["ask", 1], "and reports which answer was given (%s)" % str(picks))
	check(n.selected == 0, "a new line starts with the highlight back on top")
	check(n.reveal_rate() == float(n.current_node()["speed"]), "a line types at the speed its file gives it")

	check(not n.line_finished(), "the answer is still typing")
	await press()
	check(n.node_id == "charge" and n.line_finished(), "a press brings the rest of it out")
	await press()
	check(n.node_id == "ask_again", "a plain line after it carries on (%s)" % n.node_id)

	# An answer can lead into another question.
	p.global_position = Vector2(300, n.global_position.y)
	await phys(2)
	check(not n.is_talking() and ended[0] == 1, "being carried away mid-question ends the conversation")
	check(not p.controls_locked(), "and lets the player move again")
	p.global_position = Vector2(560, n.global_position.y)
	await phys(2)
	await press()
	check(n.node_id == "hello", "and talking again starts over")
	await listen(n)
	await press()
	await listen(n)
	await press("move_down")
	await press("move_down")
	await press()
	check(n.node_id == "who", "picking 'Who are you?' leads to its line (%s)" % n.node_id)
	await listen(n)
	check(n.is_choosing() and n.choices().size() == 2, "which asks a question of its own")
	var given := picks.size()
	# An answer pointed at rather than stepped to — a thumb coming down on its
	# plate, on the glass — is picked, and that is all.
	n.select(1)
	check(n.selected == 1 and n.node_id == "who" and picks.size() == given,
		"an answer pointed at is picked, and not given")
	n.select(7)
	check(n.selected == 1, "and one that is not there is not")
	n.select(0)
	await press("move_down")
	await press()
	check(n.node_id == "ask", "'Back to my questions' returns to the first question (%s)" % n.node_id)

	# An answer that leads nowhere ends it on the spot.
	await listen(n)
	await press("move_up")
	await press()
	check(not n.is_talking() and ended[0] == 2, "'Nothing. Bye.' ends the conversation at once")

	# A goodbye line ends it on the press after.
	await press()
	await listen(n)
	await press()
	await listen(n)
	await press("move_down")
	await press()
	await listen(n)
	await press()
	check(n.node_id == "ask_again", "reached 'Anything else?' (%s)" % n.node_id)
	await listen(n)
	await press("move_up")
	await press()
	check(n.node_id == "bye" and not n.has_more(), "'That's all' leads to a last line (%s)" % n.node_id)
	await listen(n)
	await press()
	check(not n.is_talking() and ended[0] == 3, "and a press on it ends the conversation")

	# The player can have lines of their own.
	n.node_id = "danger_reply"
	check(n.speaker() == "player" and n.speaker_name() == String(sage["player_name"]),
		"a line the table gives the player is said by the player, under their name")
	n.end_conversation()

	# Walked over. A press from anywhere in range brings the player to where
	# people stand to talk before anything opens.
	var spot := n.global_position.x - Npc.TALK_SPOT
	p.global_position = Vector2(n.global_position.x - 62.0, n.global_position.y)
	await phys(4)
	await press()
	check(n.approaching() and not n.is_talking(), "a press from further out walks the player over first")
	check(await until(func() -> bool: return n.is_talking()), "and the conversation opens once they are there")
	check(absf(p.global_position.x - spot) <= WalkTo.THERE + 1.0,
		"standing TALK_SPOT out, on the side they came from (%.1f off)" % (p.global_position.x - spot))
	check(p.facing.x > 0.0 and p.controls_locked(), "facing them, and held")
	n.end_conversation()

	# Standing right on them, they step back to talk — and turn round to face them.
	p.global_position = Vector2(n.global_position.x - 6.0, n.global_position.y)
	await phys(4)
	await press()
	check(await until(func() -> bool: return n.is_talking()), "standing on top of them, a press still opens it")
	check(absf(p.global_position.x - spot) <= WalkTo.THERE + 1.0,
		"once they have stepped back to the spot (%.1f off)" % (p.global_position.x - spot))
	check(p.facing.x > 0.0, "turned to face them, though the step back was the other way")
	n.end_conversation()

	# From up the floor as well as from the side: the spot is TALK_SPOT out
	# the way the player came, whichever way that is.
	p.global_position = n.global_position + Vector2(0.0, -62.0)
	await phys(4)
	await press()
	check(await until(func() -> bool: return n.is_talking()), "walked up to from up the floor, a press opens it the same")
	check(absf(p.global_position.distance_to(n.global_position) - Npc.TALK_SPOT) <= WalkTo.THERE + 1.0
			and p.global_position.y < n.global_position.y and absf(p.global_position.x - n.global_position.x) < 2.0,
		"standing TALK_SPOT up the floor from them (%s)" % str(p.global_position - n.global_position))
	check(p.facing.y > 0.0 and n.facing.y < 0.0, "the two of them facing each other, down and up the floor")
	n.end_conversation()

	# Changing your mind on the way over.
	p.global_position = Vector2(n.global_position.x - 62.0, n.global_position.y)
	await phys(4)
	await press()
	check(n.approaching(), "the walk over has begun")
	Input.action_press("move_left")
	await phys(3)
	check(not n.approaching() and not n.is_talking(), "a push the other way is a change of mind: nothing opens")
	var turned_from := p.global_position.x
	await phys(12)
	Input.action_release("move_left")
	await phys(2)
	check(p.global_position.x < turned_from - 10.0 and not p.controls_locked() and not n.is_talking(),
		"and the player walks off free (%.0f)" % (p.global_position.x - turned_from))

	# Locked input, like the skill editor being open.
	p.global_position = Vector2(spot, n.global_position.y)
	await phys(4)
	p.input_locked = true
	await press()
	check(n.in_range and not n.is_talking() and not n.approaching(),
		"no conversation starts while the player's input is locked, nor any walk over")
	p.input_locked = false

	print("[NPC] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
