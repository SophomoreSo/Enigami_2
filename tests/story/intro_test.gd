extends Node
## The opening scene, and the format it is written in.
##
## Two halves. First every file in `data/scenes` is read and checked the way
## `npc_test` checks the dialogue files — a misspelt direction or a walk to a
## mark that does not exist is a beat that quietly does nothing, and that is the
## sort of mistake that only shows up in front of a player. Then the real
## `intro.json` is played through beat by beat, so what the file says and what
## the stage does are checked against each other rather than separately.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[INTRO] PASS ", what)
	else:
		fails += 1
		push_error("INTRO FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## Runs the scene until `cond` comes true, or gives up. Beats that walk somebody
## across the room take as long as the walk takes, so a test cannot count frames
## and be right about it.
func until(cond: Callable, most: int = 600) -> bool:
	for i in most:
		if cond.call():
			return true
		await get_tree().process_frame
	return false

func _ready() -> void:
	# --- the files ----------------------------------------------------------
	var ids := CutsceneScript.ids()
	check(ids.has("intro"), "there is an intro.json to play (found %s)" % str(ids))
	for id in ids:
		var found := CutsceneScript.problems(String(id))
		check(found.is_empty(), "%s.json reads clean%s" % [id,
			"" if found.is_empty() else " — " + "; ".join(found)])

	# --- the checker catches what it is for ---------------------------------
	# Written out here rather than kept as broken files in the project: these
	# are the mistakes a writer makes, and every one of them is silent at run
	# time if nothing goes looking.
	var base := {
		"marks": {"here": [0, 420]},
		"cast": {"you": {"sprite": "knight_m", "at": "here"}},
	}
	check(_caught(base, [{"text": "fine", "do": [{"mvoe": "you", "to": "here"}]}], "naming none of"),
		"a misspelt direction is caught")
	check(_caught(base, [{"do": [{"move": "nobody", "to": "here"}]}], "not in the cast"),
		"directing someone who is not in the cast is caught")
	check(_caught(base, [{"do": [{"move": "you", "to": "nowhere"}]}], "not a mark"),
		"walking to a mark that does not exist is caught")
	check(_caught(base, [{"do": [{"face": "you", "dir": "sideways"}]}], "left, right, up or down"),
		"facing a direction that is none of the four is caught")
	check(_caught(base, [{}], "does nothing"),
		"a beat with no text, directions or hold is caught")
	check(CutsceneScript.problems_in({"cast": {}, "beats": []}).has("no beats"),
		"a scene with no beats at all is caught")

	# --- playing the real thing ---------------------------------------------
	var cut := Cutscene.new()
	cut.scene_id = "intro"
	var ended := [false]
	cut.finished.connect(func() -> void: ended[0] = true)
	add_child(cut)
	await frames(2)

	check(cut.cast.has("you") and cut.cast.has("tinker"),
		"the cast is on the stage (%s)" % str(cut.cast.keys()))
	var you: CutsceneActor = cut.cast["you"]
	var tinker: CutsceneActor = cut.cast["tinker"]
	# `you` has no `at` in the file, so the scene opens without them.
	check(not you.on_stage, "someone with no starting mark waits off stage")
	check(tinker.on_stage, "someone with one is standing on it")
	check(is_equal_approx(tinker.global_position.x, 610.0),
		"and is standing on the mark named, not near it (%.0f)" % tinker.global_position.x)
	check(tinker.facing.x < 0.0, "facing the way the cast list says")

	check(cut.index == 0 and cut.line() != "", "the scene opens on its first line")
	check(cut.speaker_name() == "", "narration carries no name on the tab")

	# A beat with a line types itself out and then waits, however long it is
	# left alone. Waited on rather than counted in frames: how long a line takes
	# is the file's business, and a test that counts frames is a test that fails
	# the day someone edits the text.
	var was := cut.index
	var typed := await until(func() -> bool: return cut.line_finished())
	check(typed, "a line types itself out")
	await frames(20)
	check(cut.index == was, "and the beat then waits to be read")

	cut.press()
	await frames(1)
	check(cut.index == was + 1, "a press on a read line moves to the next beat")
	check(not cut.line_finished(), "which starts typing from nothing")
	cut.press()
	check(cut.line_finished() and cut.index == was + 1,
		"and a press part-way brings the rest of the line out without skipping it")

	# From here the scene is played the way a player plays it: pressing whenever
	# it is waiting to be read, and letting everything else take its own time.
	var entered := await play(cut, func() -> bool: return you.on_stage and you.walking())
	check(entered, "an `enter` direction brings someone on and starts them walking")
	var stopped := await play(cut, func() -> bool: return not you.walking())
	check(stopped, "and the beat waits for the walk to finish")
	check(is_equal_approx(you.global_position.x, 90.0),
		"landing on the mark exactly (%.0f)" % you.global_position.x)

	# `move`: a press part-way through puts them on the mark at once rather
	# than abandoning the walk where it stood.
	var moving := await play(cut, func() -> bool: return you.walking() and you.global_position.x > 100.0)
	check(moving, "a `move` direction sets them walking again")
	cut.press()
	check(not you.walking() and is_equal_approx(you.global_position.x, 330.0),
		"a press lands a walk on its mark rather than abandoning it (%.0f)"
			% you.global_position.x)

	# An `anim` direction is state, not a moment: it stays on the cast member
	# for the picture to read until something else is asked for.
	var animated := await play(cut, func() -> bool: return tinker.forced_anim == "hit")
	check(animated, "an `anim` direction holds someone in an animation")
	var released := await play(cut, func() -> bool: return tinker.forced_anim == "idle")
	check(released, "and a later one hands them back")

	# Interact — the console's tap on the page — brings a line out whole, and
	# the next one moves the beat on. Sent the way the console sends it, as an
	# action down the tree rather than a call.
	var typing := await play(cut, func() -> bool: return cut.line() != "" and not cut.line_finished())
	check(typing, "a later line is typing")
	var at := cut.index
	await send("interact")
	check(cut.index == at and cut.line_finished(), "interact part-way brings the rest of the line out")
	await send("interact")
	check(cut.index == at + 1, "and on a read line moves the beat on")

	# --- skipping -----------------------------------------------------------
	check(not cut.done, "the scene is still running before it is skipped")
	cut.skip()
	check(cut.done and ended[0], "Esc ends the whole scene")
	cut.queue_free()

	# --- and it is only shown once ------------------------------------------
	GameState.reset_profile()
	check(not GameState.intro_seen, "a new profile has not seen the opening")
	GameState.mark_intro_seen()
	check(GameState.intro_seen, "playing it through marks it seen")
	GameState.intro_seen = false
	GameState.save_game()
	GameState.intro_seen = true
	check(GameState.load_game() and not GameState.intro_seen,
		"and that mark is kept in the save, so it survives a restart")

	print("[INTRO] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## Plays the scene forward the way a player does — pressing whenever it is
## waiting to be read — until `cond` comes true.
func play(cut: Cutscene, cond: Callable, most: int = 3000) -> bool:
	for i in most:
		if cond.call():
			return true
		if cut.done:
			return false
		if cut.waiting_for_press() and cut.line_finished():
			cut.press()
		await get_tree().process_frame
	return false

## Presses `action` and lets it go, the way the console does: an event sent
## down the tree, which is what a scene answers.
func send(action: String) -> void:
	for down in [true, false]:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = down
		e.strength = 1.0 if down else 0.0
		Input.parse_input_event(e)
		await frames(2)

## Whether checking a scene made of `beats` complains about `want`.
func _caught(base: Dictionary, beats: Array, want: String) -> bool:
	var def := base.duplicate(true)
	def["beats"] = beats
	for problem in CutsceneScript.problems_in(def):
		if String(problem).contains(want):
			return true
	return false
