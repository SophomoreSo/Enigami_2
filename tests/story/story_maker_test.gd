extends Node2D
## The story maker's rules: a conversation written as a graph of nodes — who
## says what, with what expression and what motion in the letters, what anyone
## does as it starts, and where it leads, on to a node or by the answers to a
## question — put in, changed, linked and taken away; kept as a plain file and
## read back, a story written the old way read as a chain; handed to a
## character in the shape the database's conversations come in, and to a
## scene; and played on a map stood up empty, in each of its three ways: in
## the box with the player held still, free in bubbles with a question asked
## in the box, and as a novel read a press at a time with nobody playing —
## the walks walked, the poses held, the questions answered.
##
## No renderer needed: nothing here draws. Stories, and the map they are
## played on, are kept in scratch folders for the length of the test, never
## in the project's own.

const SCRATCH := "user://story_maker_test"
const MAPS := "user://story_maker_test_maps"

var fails := 0
var maker: StoryMaker

func check(ok: bool, what: String) -> void:
	if ok:
		print("[STORY] PASS ", what)
	else:
		fails += 1
		push_error("STORY FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

## A press the way a player makes one: a synthetic press only reads as
## just-pressed on the physics frame after it.
func press(action: String = "interact") -> void:
	Input.action_press(action)
	await physics(2)
	Input.action_release(action)
	await physics(1)

func until(cond: Callable, limit: int = 300) -> bool:
	for i in limit:
		if cond.call():
			return true
		await get_tree().physics_frame
	return bool(cond.call())

## Waits for the line in the box to finish typing by itself.
func listen(n: Npc) -> void:
	await until(func() -> bool: return not n.is_talking() or n.line_finished(), 600)

## A map to play on: the clearing a new map is, with a monster posted in it,
## a box and ground to dig, to show a story leaves them out.
func stage() -> MadeRoom:
	var r := MadeRoom.new()
	var plan := PackedStringArray()
	for y in Room.H:
		if y == 0:
			plan.append("*".repeat(Room.W))
		elif y >= Room.H - 2:
			plan.append("%".repeat(Room.W))
		else:
			plan.append("|" + MadeRoom.OPEN.repeat(Room.W - 2) + "|")
	var floor_row := plan[Room.H - 3]
	for mark: Array in [[4, MadeRoom.START], [10, MadeRoom.BOX], [14, MadeRoom.DIG], [20, "c"]]:
		floor_row = floor_row.left(int(mark[0])) + String(mark[1]) + floor_row.substr(int(mark[0]) + 1)
	plan[Room.H - 3] = floor_row
	r.plan = plan
	r.tileset = "grove"
	return r

func enemies() -> Array:
	return get_tree().get_nodes_in_group("enemies")

func beat_called(sc: Cutscene, id: String) -> Dictionary:
	for b in sc.beats:
		if String((b as Dictionary).get("id", "")) == id:
			return b
	return {}

func _ready() -> void:
	Stories.scratch_dir = SCRATCH
	Maps.scratch_dir = MAPS
	_sweep(SCRATCH)
	_sweep(MAPS)
	StoryMaker.forget()
	var laid := stage()
	check(Maps.save("stage", laid) == OK and Maps.ids() == PackedStringArray(["stage"]), "a map to play on is kept in the scratch folder")
	laid.free()
	maker = StoryMaker.new()
	add_child(maker)
	await frames(2)
	var npc := StoryMaker.NPC
	var player := StoryMaker.PLAYER

	# --- a new story --------------------------------------------------------
	check(maker.node_count() == 0 and maker.start == "" and maker.story_id == "" and not maker.unsaved and maker.mode == StoryMaker.NEW_MODE,
		"a new story has no nodes, no start, no name, nothing to save, and plays in the box")
	check(maker.npc_name == StoryMaker.NEW_NAME and maker.sprite == StoryMaker.NEW_SPRITE
			and maker.player_name == StoryMaker.NEW_PLAYER_NAME,
		"with the bench's own character in it, to start from")
	check(maker.map_id == "" and maker.map_to_play() == "stage", "set on whichever map there is (%s)" % maker.map_to_play())
	check(not maker.has_lines() and maker.play() == "empty" and not maker.playing, "and with nothing to say it cannot be played, and says why")

	# --- writing it: nodes, their properties, and the links between them ----------
	var a := maker.add_node(StoryMaker.FIRST_AT)
	check(a == "1" and maker.node_count() == 1 and maker.start == a and maker.at_of(a) == StoryMaker.FIRST_AT
			and maker.properties_of(a).is_empty() and not maker.has_line(a) and maker.text_of(a) == "" and maker.unsaved,
		"the first node put in has no properties at all, and is where the story starts")
	check(StoryMaker.PROPERTIES.all(func(k: String) -> bool: return maker.can_add(a, k)) and not maker.can_add(a, "hat")
			and not maker.can_add("9", "line"),
		"every kind of property can be added to it, and nothing that is none, and to no node that is not there")
	check(maker.add_property(a, "line") == 0 and maker.has_line(a) and maker.speaker_of(a) == npc and maker.text_of(a) == ""
			and maker.properties_of(a) == PackedStringArray(["line"]),
		"a line added is the character's, with nothing said yet")
	check(not maker.can_add(a, "line") and maker.add_property(a, "line") < 0 and maker.add_property(a, "hat") < 0,
		"a node has one line at most")
	check(maker.set_text(a, "Ah. A new face.") and maker.text_of(a) == "Ah. A new face." and not maker.set_text("9", "x"),
		"a node's words are changed, and no other's")
	var b := maker.add_node_after(a, true)
	check(b == "2" and maker.has_line(b) and maker.speaker_of(b) == player and maker.at_of(b) == StoryMaker.FIRST_AT + StoryMaker.ALONG
			and maker.next_of(a) == b,
		"a node put in after another with a line of its own is the other's turn, stands along from it, and is led to")
	maker.set_text(b, "Through? I walked in the front.")
	var c := maker.add_node_after(b, true)
	check(c == "3" and maker.speaker_of(c) == npc and maker.next_of(b) == c, "turn and turn about")
	maker.set_text(c, "What would you like to know?")
	check(maker.toggle_speaker(b) and maker.speaker_of(b) == npc and maker.toggle_speaker(b) and maker.speaker_of(b) == player
			and not maker.set_speaker(b, "cat"),
		"a line is given to the other of the two, and back, and to nobody else")
	var bare := maker.add_node_after(c)
	check(maker.properties_of(bare).is_empty() and maker.next_of(c) == bare and not maker.toggle_speaker(bare),
		"a node put in after another without a line has nothing, and is led to; with no line it has nobody to give one to")
	check(maker.set_text(bare, "Hm.") and maker.has_line(bare) and maker.speaker_of(bare) == player and maker.text_of(bare) == "Hm.",
		"words set on a node with no line give it one, said by whoever's turn it is")
	check(maker.add_property(bare, "emotion") == 0 and maker.remove_property(bare, "line") and not maker.has_line(bare)
			and maker.text_of(bare) == "" and maker.properties_of(bare) == PackedStringArray(["emotion"]) and not maker.remove_property(bare, "line"),
		"a line taken away goes with its words, and leaves the rest")
	maker.remove_node(bare)
	check(maker.link(a, c) and maker.next_of(a) == c and maker.link(a, b) and maker.next_of(a) == b,
		"a node is led elsewhere, and back")
	check(not maker.link(a, a) and not maker.link(a, "9") and maker.next_of(a) == b,
		"but not to itself, nor to a node that is not there")
	check(maker.link(c, "") and maker.next_of(c) == "" and not maker.node(c).has("next"), "and to nowhere, which is the end")
	check(maker.move_node(c, Vector2i(600, 100)) and maker.at_of(c) == Vector2i(600, 100) and not maker.move_node("9", Vector2i.ZERO),
		"a node is moved about the desk")

	# --- a question ---------------------------------------------------------------
	check(maker.add_property(c, "choices") == 0 and maker.asks(c) and maker.choices_of(c).size() == 1
			and String(maker.choices_of(c)[0]["text"]) == "" and not maker.can_add(c, "choices"),
		"answers added make a node a question, with one answer to write")
	check(maker.set_choice_text(c, 0, "Who are you?") and not maker.link(c, a) and maker.next_of(c) == "",
		"which leads nowhere but by its answers")
	check(maker.add_choice(c, "Nothing. Bye.") == 1 and maker.set_choice_text(c, 1, "Nothing. Goodbye.")
			and String(maker.choices_of(c)[1]["text"]) == "Nothing. Goodbye.",
		"and another, whose words are changed")
	var d := maker.add_node(Vector2i(900, 20))
	check(maker.link_choice(c, 0, d) and String(maker.choices_of(c)[0]["next"]) == d, "an answer is led to a node")
	check(maker.add_property(d, "line") == 0 and maker.speaker_of(d) == npc,
		"a line on a node an answer leads to is said by whoever asked, the answer having been the other's")
	maker.set_text(d, "I tinker. Mostly with things that explode.")
	check(maker.link(d, c) and maker.next_of(d) == c, "which may lead back to the question")
	check(not maker.link_choice(c, 5, d) and not maker.link_choice(c, 0, "9") and maker.link_choice(c, 1, "")
			and not maker.choices_of(c)[1].has("next"),
		"an answer that is not there, or a node that is not, is refused; an answer led nowhere ends the story")
	var e := maker.add_node(Vector2i(900, 200), npc, "Go on, then.")
	check(maker.has_line(e) and maker.link_choice(c, 1, e) and maker.remove_node(e) and not maker.holds(e)
			and not maker.choices_of(c)[1].has("next") and not maker.remove_node(e),
		"a node taken off the desk is off every link that led to it")
	var f := maker.add_node(Vector2i(900, 300), npc, "Nobody comes here.")
	check(maker.reachable() == PackedStringArray([a, b, c, d]),
		"the story reaches its nodes along its links from the start, and not one nothing leads to (%s)" % str(maker.reachable()))
	check(maker.remove_choice(c, 1) and maker.choices_of(c).size() == 1 and maker.remove_choice(c, 0) and not maker.asks(c)
			and maker.has_property(c, "choices") and not maker.remove_choice(c, 0),
		"answers are taken away one at a time, and with the last gone the node is no question, its answers still there to write")
	check(maker.link(c, d) and maker.next_of(c) == d and maker.remove_property(c, "choices") and not maker.has_property(c, "choices")
			and maker.next_of(c) == d and not maker.remove_property(c, "choices"),
		"so it leads on again; and the property is taken away whole")
	maker.link(c, "")
	maker.add_choice(c, "Who are you?")
	maker.link_choice(c, 0, d)
	maker.add_choice(c, "Nothing. Bye.")
	check(maker.set_start(f) and maker.start == f and maker.reachable() == PackedStringArray([f]) and not maker.set_start("9"),
		"the start is moved, and the story is what that reaches")
	maker.set_start(a)
	maker.remove_node(f)

	# --- what a node wears and does ---------------------------------------------------
	check(maker.add_property(a, "emotion") == 0 and maker.emotion_of(a) == StoryMaker.NEW_EMOTION and maker.has_property(a, "emotion")
			and not maker.can_add(a, "emotion"),
		"an expression added starts as no face at all, and a node has one at most")
	check(maker.set_emotion(a, "happy") and maker.emotion_of(a) == "happy" and not maker.set_emotion(a, "furious")
			and not maker.set_emotion(a, "") and maker.emotion_of(a) == "happy",
		"it wears one the picture draws, and no other")
	check(maker.set_emotion(a, "neutral") and maker.has_property(a, "emotion") and maker.remove_property(a, "emotion")
			and not maker.node(a).has("emotion") and maker.emotion_of(a) == StoryMaker.LINE_EMOTION,
		"neutral is a face like any other; taken away, the node wears none")
	check(maker.set_emotion(a, "happy") and maker.has_property(a, "emotion"), "and set where there is none, it is added")
	check(maker.add_property(d, "effect") == 0 and maker.effect_of(d) == StoryMaker.NEW_EFFECT and not maker.can_add(d, "effect"),
		"letters added start waving")
	check(maker.set_effect(d, "shake") and maker.effect_of(d) == "shake" and not maker.set_effect(d, "zoom") and not maker.set_effect(d, "")
			and maker.remove_property(d, "effect") and maker.effect_of(d) == "" and not maker.node(d).has("effect"),
		"they move one of the ways there are; taken away, as the expression moves them")
	maker.set_effect(d, "shake")
	check(maker.add_property(a, "action") == 0 and maker.actions_of(a)[0] == {"who": npc, "do": "walk", "to": player}
			and maker.can_add(a, "action"),
		"an action added: the character walks toward the player — and a node may have any number")
	check(maker.add_action(b, player, "walk") == 0 and maker.set_action(b, 0, "to", "left")
			and maker.actions_of(b)[0] == {"who": player, "do": "walk", "to": "left", "steps": StoryMaker.NEW_STEPS},
		"a walk left goes so many cells")
	check(maker.set_action(b, 0, "steps", 3) and int(maker.actions_of(b)[0]["steps"]) == 3
			and maker.set_action(b, 0, "to", "up") and not maker.set_action(b, 0, "to", "sideways")
			and not maker.set_action(b, 0, "who", "cat"),
		"and only so many, any of the four ways on the floor and none other, and only one of the two")
	check(maker.set_action(b, 0, "do", "face") and maker.actions_of(b)[0] == {"who": player, "do": "face", "dir": "toward"},
		"a turn keeps what a turn takes and nothing of a walk's")
	check(maker.set_action(b, 0, "dir", "up") and not maker.set_action(b, 0, "dir", "sideways")
			and maker.set_action(b, 0, "do", "pose") and maker.actions_of(b)[0] == {"who": player, "do": "pose", "pose": "idle"},
		"and a pose starts standing")
	check(maker.set_action(b, 0, "pose", "sit") and not maker.set_action(b, 0, "pose", "") and not maker.set_action(b, 0, "hat", "x")
			and maker.add_action(b, npc, "sing") < 0 and maker.actions_of(b).size() == 1,
		"a pose is any the sprite may have; a key that is none, and a doing that is none, are refused")
	check(maker.add_action(d, npc, "pose") == 0 and maker.add_property(d, "action") == 1 and maker.remove_property(d, "action")
			and not maker.node(d).has("actions") and not maker.remove_action(d, 0),
		"actions are any number, and taken away whole")
	check(maker.add_action(d, npc, "pose") == 0 and maker.set_action(d, 0, "pose", "hit") and maker.add_action(d) == 1
			and maker.remove_action(d, 1) and maker.actions_of(d).size() == 1,
		"or one at a time")
	# A beat of staging between the first two lines: the character turns away.
	var g := maker.add_node(Vector2i(180, 200))
	maker.add_action(g, npc, "face")
	maker.set_action(g, 0, "dir", "left")
	maker.link(a, g)
	maker.link(g, b)
	check(maker.properties_of(g) == PackedStringArray(["action"]) and maker.reachable() == PackedStringArray([a, g, b, c, d])
			and maker.has_lines(),
		"a node with nothing to say and something to do is in the story like any other")
	check(maker.properties_of(d) == PackedStringArray(["line", "effect", "action"])
			and maker.properties_of(a) == PackedStringArray(["line", "emotion", "action"]),
		"and what a node has is told in one order, whatever order it came in")

	# --- the checker -----------------------------------------------------------------
	check(maker.problems().is_empty(), "the story reads clean (%s)" % str(maker.problems()))
	check(StoryMaker.problems_in({"nodes": {}}).has("no lines") and StoryMaker.problems_in({"lines": []}).has("no lines"),
		"the checker catches nothing to say")
	var one := {"start": "1", "nodes": {"1": {"speaker": npc, "text": "Hi."}}}
	check(StoryMaker.problems_in(one).is_empty(), "and passes one line")
	check(StoryMaker.problems_in({"mode": "opera", "start": "1", "nodes": one["nodes"]}).size() == 1
			and StoryMaker.problems_in({"start": "9", "nodes": one["nodes"]}).size() == 2,
		"a way of playing that is none, a start that names no node (and then nothing leads to the one there)")
	check(StoryMaker.problems_in({"start": "1", "nodes": {"1": {"speaker": "cat", "text": "Meow."}}}).size() == 1
			and StoryMaker.problems_in({"start": "1", "nodes": {"1": {"text": "x", "emotion": "furious"}}}).size() == 1
			and StoryMaker.problems_in({"start": "1", "nodes": {"1": {"text": "x", "effect": "zoom"}}}).size() == 1
			and StoryMaker.problems_in({"start": "1", "nodes": {"1": {"text": "x", "actions": [{"do": "sing"}]}}}).size() == 1,
		"a node said by nobody, an expression nobody draws, a motion that is none, a doing that is none")
	check(StoryMaker.problems_in({"start": "1", "nodes": {"1": {"choices": [{"text": "Yes."}]}}}).is_empty()
			and StoryMaker.problems_in({"start": "1", "nodes": {"1": {}}}).size() == 1,
		"answers with no words before them ask nothing wrong; a node with nothing at all says and does nothing")
	check(StoryMaker.problems_in({"start": "1", "nodes": {"1": {"text": "x", "next": "9"}}}).size() == 1
			and StoryMaker.problems_in({"start": "1", "nodes": {"1": {"text": "x", "choices": [{"text": "a", "next": "9"}, {"text": ""}]}}}).size() == 2
			and StoryMaker.problems_in({"start": "1", "nodes": {"1": {"text": "x"}, "2": {"text": "y"}}}).size() == 1
			and StoryMaker.problems_in({"start": "1", "nodes": {"1": {"actions": []}}}).size() == 1,
		"a link to a node that is not there, an answer with nothing to say, a node nothing leads to, one that says and does nothing")

	# --- handed to the character, and to the scene ---------------------------------
	var def := maker.character()
	var nodes: Dictionary = def["nodes"]
	var rules: Dictionary = def["rules"]
	check(String(def["id"]) == StoryMaker.CHARACTER and String(def["name"]) == StoryMaker.NEW_NAME and String(def["start"]) == a
			and nodes.size() == 5 and String(nodes[a]["next"]) == g and String(nodes[g]["next"]) == b and not nodes[a].has("at"),
		"the character is handed the story as the database hands a conversation: a node a line, from the start, leading on")
	check(String(nodes[a]["emotion"]) == "happy" and String(nodes[a]["actions"][0]["do"]) == "walk"
			and int(nodes[a]["speed"]) == StoryMaker.LINE_SPEED and String(nodes[a]["voice"]) == StoryMaker.LINE_VOICE,
		"each wearing what it wears and doing what it does, and saying what a line in the database would where it does not say itself")
	check((nodes[c]["choices"] as Array).size() == 2 and String(nodes[c]["choices"][0]["next"]) == d and not nodes[c].has("next")
			and String(nodes[d]["next"]) == c and String(nodes[d]["effect"]) == "shake",
		"a question's answers lead on, and a node's letters go with it")
	check(String(nodes[g]["text"]) == "" and (nodes[g]["actions"] as Array).size() == 1,
		"a beat of staging says nothing and does something")
	check(String(rules[a]["listens"]) == FreeTalk.TALK and not rules[b].has("listens") and int(rules[a]["once"]) == 0
			and float(rules[g]["hold"]) == 0.0 and not rules[b].has("hold") and rules[c].has("choices") and String(rules[d]["next"]) == c,
		"and free: the first answers a press, a beat of staging holds for no time, a question keeps its answers")
	var in_box := Dialogue.problems_in({"start": def["start"], "nodes": def["nodes"]})
	check(in_box.size() == 1 and String(in_box[0]).contains("no text"),
		"the conversations' own checker passes the box's half of it but for the beat of staging, which has nothing to say on purpose (%s)" % str(in_box))
	var scene := maker.scene_script(Vector2(300, 400), Vector2(200, 400))
	var beats: Array = scene["beats"]
	check(beats.size() == 5 and String(beats[0]["id"]) == a and String(beats[0]["next"]) == g
			and String(beats[0]["do"][0]["fade"]) == "in"
			and beats[0]["do"][1] == {"move": npc, "speed": StoryMaker.WALK_SPEED, "near": player, "gap": Npc.TALK_SPOT},
		"a novel's beats: the start first, coming up out of black, leading on by id, a walk a move up near the other")
	check(beat_called(scene_wrap(scene), g)["do"] == [{"face": npc, "dir": "left"}]
			and beat_called(scene_wrap(scene), b)["do"] == [{"anim": player, "play": "sit"}]
			and beat_called(scene_wrap(scene), d)["do"] == [{"anim": npc, "play": "hit"}]
			and String(beat_called(scene_wrap(scene), d)["effect"]) == "shake" and String(beat_called(scene_wrap(scene), d)["next"]) == c,
		"a turn a face, a pose an anim held, the letters' motion with the beat")
	var ask := beat_called(scene_wrap(scene), c)
	check((ask["choices"] as Array).size() == 2 and String(ask["choices"][0]["next"]) == d and not ask.has("next"),
		"and a question its answers")
	check(float(scene["camera"]["zoom"]) == StoryMaker.NOVEL_ZOOM and String(scene["cast"][npc]["facing"]) == "left"
			and String(scene["cast"][player]["sprite"]) == StoryMaker.PLAYER_SPRITE and CutsceneScript.problems_in(scene).is_empty(),
		"with the two of them cast facing each other, the camera in close, and the scenes' own checker passes it (%s)" % str(CutsceneScript.problems_in(scene)))
	maker.set_action(b, 0, "do", "walk")
	maker.set_action(b, 0, "to", "right")
	check(beat_called(scene_wrap(maker.scene_script(Vector2.ZERO, Vector2.ZERO)), b)["do"]
			== [{"move": player, "speed": StoryMaker.WALK_SPEED, "by": [float(StoryMaker.NEW_STEPS * Room.CELL), 0.0]}],
		"a walk right is a move by so many cells across the floor")
	maker.set_action(b, 0, "do", "pose")
	maker.set_action(b, 0, "pose", "sit")

	# --- the ways of playing --------------------------------------------------
	check(maker.set_mode_id("novel") and maker.mode == StoryMaker.Mode.NOVEL and maker.mode_id() == "novel"
			and not maker.set_mode_id("opera") and maker.mode == StoryMaker.Mode.NOVEL,
		"the way it is played is set by its id, and an id that is none is refused")
	maker.set_mode(StoryMaker.Mode.FROZEN)

	# --- keeping it -------------------------------------------------------------
	check(Stories.id_for(" First Meeting! ") == "first_meeting" and Stories.id_for("...") == "",
		"a story's name is filed the way a map's is")
	check(maker.save_as("   ") == "name" and Stories.ids().is_empty(), "a story with no name to file it under is not kept")
	check(maker.save_as("Test Story") == "" and maker.story_id == "test_story" and not maker.unsaved,
		"SAVE keeps it under its name")
	var path := Stories.path_of("test_story")
	check(path == SCRATCH.path_join("test_story.json") and FileAccess.file_exists(path), "as a file of its own (%s)" % path)
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(parsed is Dictionary and String(parsed["mode"]) == "frozen" and String(parsed["start"]) == a
			and (parsed["nodes"] as Dictionary).size() == 5 and str(parsed["nodes"][a]["at"]) == str([40.0, 60.0])
			and String(parsed["nodes"][a]["next"]) == g and (parsed["nodes"][c]["choices"] as Array).size() == 2
			and String(parsed["nodes"][b]["actions"][0]["pose"]) == "sit" and not parsed.has("spot"),
		"plain JSON: the map, the way it plays, who is in it, the start, and the nodes — where each stands, what it says, does and leads to")
	check(Stories.ids() == PackedStringArray(["test_story"]) and Stories.exists("test_story") and not Stories.exists("nowhere"),
		"which the list of stories finds")
	maker.set_text(a, "Ah, a new face.")
	maker.set_map("stage")
	maker.set_spot(Vector2i(12, Room.H - 3))
	check(maker.unsaved and maker.save_as("test story") == "", "a story changed and saved again goes over the old one")
	var again := Stories.load_story("test_story")
	check(String(again["nodes"][a]["text"]) == "Ah, a new face." and String(again["map"]) == "stage"
			and int(again["spot"][0]) == 12 and int(again["spot"][1]) == Room.H - 3,
		"and what is read back is what was saved last, the map and the character's spot with it")
	maker.new_story()
	check(maker.node_count() == 0 and maker.start == "" and maker.story_id == "" and not maker.unsaved and maker.spot == Vector2i(-1, -1),
		"NEW clears the desk")
	check(maker.add_node(Vector2i.ZERO) == "1", "and the next node put in is the first again")
	check(maker.save_as("other") == "" and Stories.ids() == PackedStringArray(["other", "test_story"]),
		"a second story is kept beside the first")
	check(maker.open("test_story") and maker.node_count() == 5 and maker.start == a and maker.story_id == "test_story"
			and maker.properties_of(g) == PackedStringArray(["action"]) and maker.properties_of(d) == PackedStringArray(["line", "effect", "action"])
			and maker.map_id == "stage" and maker.spot == Vector2i(12, Room.H - 3) and not maker.unsaved
			and maker.add_node(Vector2i.ZERO) == str(int(g) + 1),
		"LOAD puts a kept story back on the desk as it was saved, and the next node put in is past every id")
	maker.remove_node(str(int(g) + 1))
	check(not maker.open("nowhere") and maker.story_id == "test_story", "and a story that is not there leaves the desk alone")
	check(Stories.remove("other") == OK and Stories.ids() == PackedStringArray(["test_story"]), "a story thrown away is gone from the list")
	var hand := FileAccess.open(SCRATCH.path_join("by_hand.json"), FileAccess.WRITE)
	hand.store_string('{"lines": ["One.", {"speaker": "player", "text": "Two."}], "mode": "opera"}')
	hand.close()
	check(maker.open("by_hand") and maker.node_count() == 2 and maker.start == "1" and maker.speaker_of("1") == npc
			and maker.text_of("1") == "One." and maker.speaker_of("2") == player and maker.next_of("1") == "2"
			and maker.mode == StoryMaker.NEW_MODE and maker.map_to_play() == "stage",
		"a story written the old way, as a list of lines, is a chain of nodes, and what it leaves out is the new story's")
	hand = FileAccess.open(SCRATCH.path_join("by_hand.json"), FileAccess.WRITE)
	hand.store_string('{"start": "7", "nodes": {"2": {"text": "Alone.", "next": "9", "speaker": "cat", "effect": "zoom", "choices": "no", "actions": [{"do": "sing"}, {"do": "walk", "who": "player", "to": "left"}]}}}')
	hand.close()
	check(maker.open("by_hand") and maker.start == "2" and maker.next_of("2") == "" and maker.speaker_of("2") == npc
			and maker.effect_of("2") == "" and not maker.asks("2") and maker.actions_of("2").size() == 1
			and maker.actions_of("2")[0] == {"who": player, "do": "walk", "to": "left", "steps": StoryMaker.NEW_STEPS},
		"and a file written badly by hand is squared off: a start that is nowhere is the first node, a link to nowhere no link, a doing that is none dropped")
	hand = FileAccess.open(SCRATCH.path_join("by_hand.json"), FileAccess.WRITE)
	hand.store_string('{"start": "1", "nodes": {"1": {"actions": [{"do": "face"}], "next": "2"}, "2": {"text": "x", "emotion": "neutral", "choices": []}}}')
	hand.close()
	check(maker.open("by_hand") and not maker.has_line("1") and maker.properties_of("1") == PackedStringArray(["action"])
			and maker.has_property("2", "emotion") and maker.emotion_of("2") == "neutral"
			and maker.has_property("2", "choices") and not maker.asks("2") and maker.properties_of("2") == PackedStringArray(["line", "emotion", "choices"]),
		"a node in a file has the properties it is written with and no others: no line where it has no words, a neutral face, answers with none in them yet")
	Stories.remove("by_hand")
	maker.open("test_story")

	# --- played in the box ------------------------------------------------------
	var changes: Array = []
	maker.playing_changed.connect(func(on: bool) -> void: changes.append(on))
	check(maker.play() == "" and maker.playing and changes == [true], "PLAY stands the map up")
	await frames(2)
	await physics(6)
	var room := maker.room
	check(room != null and room.cols == Room.W and room.rows == Room.H and room.is_solid(5, Room.H - 2) and not room.is_solid(5, 5),
		"the map laid, cell for cell")
	check(enemies().is_empty() and room.box == null and room.digs.is_empty(),
		"and stood empty: nobody at the post, no box, nothing to dig")
	check(maker.player != null and maker.npc != null and maker.scene == null, "with a body in it and the character on it, and no scene")
	var n := maker.npc
	check(n.mode == Npc.Mode.FREEZE and not n.free_story and n.npc_id == StoryMaker.CHARACTER and n.display_name == StoryMaker.NEW_NAME
			and n.nodes.size() == 5 and n.start == a and n.is_in_group("npcs") and not n.is_in_group("actors"),
		"the character talks in the box, is called what the story calls them, and is no target")
	var p := maker.player
	check(p.weapons.size() == mini(Player.MAX_WEAPONS, Weapons.ids().size()) and p.runner.board == maker.graphs[p.weapon_id]
			and p.runner.board != GameState.weapon_board(p.weapon_id),
		"the body carries a kit's worth, on copies of the profile's graphs")
	var at := room.spawn_point()
	check(p.global_position.distance_to(at) < 4.0
			and n.global_position.is_equal_approx(room.stand_point(Vector2i(12, Room.H - 3))),
		"the body stands at the start and the character in the story's spot, on the floor (%s)" % str(n.global_position))
	# Up close, a press walks the player over and opens the box.
	p.global_position = n.global_position + Vector2(-50.0, 0.0)
	await physics(2)
	check(n.in_range and not n.is_talking(), "walked up, the player is in range and nothing has been said")
	await press()
	var opened := await until(func() -> bool: return n.is_talking())
	check(opened and n.node_id == a and p.controls_locked(), "a press up close starts the story in the box, and holds the player")
	check(n.current_line() == "Ah, a new face." and n.speaker() == npc and n.speaker_name() == StoryMaker.NEW_NAME
			and String(n.current_node().get("emotion", "")) == "happy",
		"on its first node, said by the character, wearing its expression")
	# The first node walks the character up to the player: a step short of them.
	var walked := await until(func() -> bool: return not n.walking(), 300)
	check(walked and absf(n.global_position.x - (p.global_position.x + Npc.TALK_SPOT)) < 4.0 and n.is_talking(),
		"and walks the character up to the player, a step short, with the box still open (%.0f from %.0f)" % [n.global_position.x, p.global_position.x])
	await listen(n)
	await press()
	var staged := await until(func() -> bool: return n.node_id == b, 60)
	check(staged and n.facing.x < 0.0 and n.is_talking(), "a press past it goes through the beat of staging to the line after: the character turned away, and stays so")
	check(p.forced_anim == "sit", "the player's line holds the player in its pose")
	await listen(n)
	await press()
	await listen(n)
	check(n.node_id == c and n.is_choosing() and n.choices().size() == 2, "the question is asked, with its two answers")
	await press("move_down")
	check(n.selected == 1, "down moves to the next answer")
	await press("move_up")
	await press()
	check(n.node_id == d and n.forced_anim == "hit" and String(n.current_node().get("effect", "")) == "shake",
		"the first answer leads to its node, which holds the character in its pose and moves its letters")
	await listen(n)
	await press()
	check(n.node_id == c and n.forced_anim == "hit", "which leads back to the question, the pose still held")
	await listen(n)
	await press("move_down")
	await press()
	await physics(2)
	check(not n.is_talking() and not p.controls_locked() and n.forced_anim == "" and p.forced_anim == "",
		"the other answer ends the story, lets the player go, and lets go of every pose")
	maker.stop()
	await frames(2)
	check(not maker.playing and changes == [true, false] and maker.room == null and maker.player == null and maker.npc == null
			and get_tree().get_nodes_in_group("player").is_empty() and get_tree().get_nodes_in_group("npcs").is_empty(),
		"leaving play strikes the map, the body and the character")
	check(maker.node_count() == 5 and maker.text_of(a) == "Ah, a new face.", "and the story is as it was")

	# --- played free --------------------------------------------------------------
	maker.set_mode(StoryMaker.Mode.FREE)
	check(maker.play() == "", "PLAY again, free")
	await frames(2)
	await physics(6)
	n = maker.npc
	p = maker.player
	check(n != null and n.mode == Npc.Mode.FREE and n.free_story and n.free_talk.rules.size() == 5, "the character talks free, with a rule a node")
	p.global_position = n.global_position + Vector2(-50.0, 0.0)
	await physics(2)
	check(n.answers_press(), "and up close a press would get an answer")
	await press()
	check(n.free_talk.is_talking() and n.free_talk.line_id == a and not n.is_talking() and not p.controls_locked(),
		"a press starts the story free: in a bubble, with the player's hands their own")
	var went := await until(func() -> bool: return n.free_talk.line_id == b, 900)
	check(went and n.facing.x < 0.0, "the next lines follow by themselves, the beat of staging gone by with its turn made")
	var asked := await until(func() -> bool: return n.is_talking() and n.node_id == c, 900)
	check(asked and not n.free_talk.is_talking() and p.controls_locked(), "the question is asked in the box, the player held for it")
	await listen(n)
	await press()
	var on_free := await until(func() -> bool: return n.free_talk.line_id == d and not n.is_talking(), 60)
	check(on_free and not p.controls_locked() and n.forced_anim == "hit", "the answer given, the story goes on free from where it leads, the pose held")
	var asked_again := await until(func() -> bool: return n.is_talking() and n.node_id == c, 900)
	check(asked_again, "and comes round to the question again")
	await listen(n)
	await press("move_down")
	await press()
	await physics(2)
	check(not n.is_talking() and not n.free_talk.is_talking() and n.forced_anim == "", "the other answer ends it")
	maker.stop()
	await frames(2)

	# --- played as a novel ----------------------------------------------------------
	maker.set_mode(StoryMaker.Mode.NOVEL)
	check(maker.play() == "", "PLAY again, as a novel")
	await frames(2)
	await physics(6)
	var sc := maker.scene
	check(sc != null and maker.player == null and maker.npc == null and maker.reading(),
		"a novel stands no body and no character to talk to: a scene, being read")
	check(sc.cast.has(npc) and sc.cast.has(player) and sc.beats.size() == 5 and sc.index == 0
			and sc.speaker_name() == StoryMaker.NEW_NAME and sc.line() == "Ah, a new face.",
		"with the two of them cast, on the first beat")
	var who: CutsceneActor = sc.cast[npc]
	var you: CutsceneActor = sc.cast[player]
	check(not sc.own_stage and sc.get_children().filter(func(ch: Node) -> bool: return ch is StaticBody2D).is_empty(),
		"on the map's own floor, with no stage of the scene's")
	check(who.facing.x < 0.0 and you.facing.x > 0.0 and who.global_position.x > you.global_position.x, "facing each other")
	check(Arena.current() == sc, "the scene is the world while it runs")
	var came := await until(func() -> bool: return not who.walking(), 900)
	check(came and absf(who.global_position.x - (you.global_position.x + Npc.TALK_SPOT)) < 2.0,
		"the first beat walks the character up near the player, a step short (%.0f from %.0f)" % [who.global_position.x, you.global_position.x])
	var typed := await until(func() -> bool: return sc.line_finished(), 600)
	check(typed and sc.waiting_for_press(), "a line types itself out and waits to be read")
	sc.press()
	var through := await until(func() -> bool: return sc.index == int(sc._by_id[b]), 60)
	check(through and who.facing.x < 0.0 and you.forced_anim == "sit",
		"a press goes through the beat of staging, which turns the character, to the player's line, which holds the player's pose")
	sc.press()
	sc.press()
	await frames(1)
	check(String(sc.beat()["id"]) == c and not sc.is_choosing(), "the question, still typing")
	await until(func() -> bool: return sc.line_finished(), 600)
	check(sc.is_choosing() and sc.choices().size() == 2 and sc.selected == 0, "and asked, with its answers")
	sc.move_selection(1)
	check(sc.selected == 1, "the highlight moves")
	sc.move_selection(1)
	check(sc.selected == 0, "and wraps")
	sc.press()
	await frames(1)
	check(String(sc.beat()["id"]) == d and who.forced_anim == "hit" and String(sc.beat().get("effect", "")) == "shake",
		"a press gives the answer picked, on to its beat: the pose held, the letters moving")
	sc.press()
	sc.press()
	await frames(1)
	check(String(sc.beat()["id"]) == c, "which leads back to the question")
	await until(func() -> bool: return sc.is_choosing(), 600)
	sc.move_selection(1)
	sc.choose(sc.selected)
	await frames(3)
	check(not maker.playing and maker.scene == null and Arena.current() == maker,
		"the other answer ends the novel: the desk is back, and the world is its own again")
	check(maker.play() == "" and maker.reading(), "read again")
	await frames(2)
	maker.scene.skip()
	await frames(3)
	check(not maker.playing and maker.scene == null, "and skipped, it is over at once")
	# A story with a spot the map has no room in — in the wall down its left —
	# puts the character along the floor from the start instead.
	maker.set_spot(Vector2i(0, 3))
	maker.set_mode(StoryMaker.Mode.FROZEN)
	maker.play()
	await frames(2)
	await physics(4)
	var along := maker.room.stand_point(Vector2i(4 + StoryMaker.APART, Room.H - 3))
	check(maker.npc.global_position.is_equal_approx(along),
		"with no room to stand where the story says, the character stands along the floor from the start (%s)" % str(maker.npc.global_position))
	maker.stop()
	await frames(2)
	# And with no map kept anywhere, nothing to play it on.
	Maps.scratch_dir = MAPS + "_none"
	check(maker.map_to_play() == "" and maker.play() == "map" and not maker.playing,
		"with no map kept anywhere there is nothing to play it on, and PLAY says so")
	Maps.scratch_dir = MAPS

	# --- kept between visits -----------------------------------------------------------
	maker.add_node_after(d)
	var left: Dictionary = maker.nodes.duplicate(true)
	maker.queue_free()
	await frames(2)
	maker = StoryMaker.new()
	add_child(maker)
	await frames(2)
	check(maker.nodes == left and maker.start == a and maker.unsaved and maker.story_id == "test_story" and maker.map_id == "stage",
		"the story on the desk is still there when the maker is come back to, unsaved as it was")
	maker.queue_free()
	await frames(2)
	StoryMaker.forget()
	maker = StoryMaker.new()
	add_child(maker)
	await frames(2)
	check(maker.node_count() == 0 and maker.story_id == "", "and forgotten, the next visit starts on a new one")

	# --- the stories the game ships with --------------------------------------------------
	Stories.scratch_dir = ""
	var shipped := Stories.ids()
	check(shipped.has("first_meeting"), "there is a first_meeting to start from (%s)" % str(shipped))
	for id in shipped:
		var found := StoryMaker.problems_in(Stories.load_story(id))
		check(found.is_empty(), "%s.json reads clean%s" % [id, "" if found.is_empty() else " — " + "; ".join(found)])
		maker.open(id)
		var as_scene := CutsceneScript.problems_in(maker.scene_script(Vector2(300, 400), Vector2(200, 400)))
		var told := maker.character()
		var as_talk := Dialogue.problems_in({"start": told["start"], "nodes": told["nodes"]})
		check(as_scene.is_empty() and as_talk.is_empty(), "and plays as a scene and as a conversation (%s %s)" % [str(as_scene), str(as_talk)])
	maker.queue_free()
	await frames(2)

	_sweep(SCRATCH)
	_sweep(MAPS)
	Maps.scratch_dir = ""
	StoryMaker.forget()
	print("[STORY] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## A scene handed in, as a `Cutscene` holds its beats, for `beat_called`.
func scene_wrap(scene: Dictionary) -> Cutscene:
	var c := Cutscene.new()
	c.beats = scene["beats"]
	_wraps.append(c)
	return c

var _wraps: Array = []

func _exit_tree() -> void:
	for w in _wraps:
		(w as Node).free()

## Empties a scratch folder, and takes it away.
func _sweep(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir)
