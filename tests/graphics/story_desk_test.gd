extends Node
## The story maker's screen, worked the way a person works it: in from the
## title, nodes put in from the bar and by a double click on the sheet, their
## words typed, dragged about and led one to another by their ports, written
## up in the inspector — who says it, its expression, its letters, its
## answers, what it does as it starts, where the story starts — a way of
## playing picked, a map imported, saved under a name, found again in the
## list, played each of the three ways and come back from.
##
## What the maker's rules do is `tests/story/story_maker_test`. This is the
## desk over them — that every press and drag gets to the rule it is for,
## that the whole of it fits the screen in both languages and both modes, and
## that the ways out of it land where they say.
##
## Stories, and the map they are played on, are kept in scratch folders for
## the length of the test, never in the project's own. No pixels are read.

const GameScript := preload("res://app/game.gd")
const SCRATCH := "user://story_desk_test"
const MAPS := "user://story_desk_test_maps"

var fails := 0
var game: Node
var maker: StoryMaker
var view: StoryMakerView
var desk: StoryDesk

func check(ok: bool, what: String) -> void:
	if ok:
		print("[DESK] PASS ", what)
	else:
		fails += 1
		push_error("DESK FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func on_glass(at: Vector2) -> Vector2:
	return get_window().get_final_transform() * at

func move(at: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = on_glass(at)
	m.global_position = m.position
	Input.parse_input_event(m)
	await frames(2)

func press(at: Vector2, down: bool, double: bool = false) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.double_click = double
	e.position = on_glass(at)
	e.global_position = e.position
	Input.parse_input_event(e)
	await frames(2)

## A press and a let-go on one spot.
func click(at: Vector2) -> void:
	await move(at)
	await press(at, true)
	await press(at, false)

## Two, quick, where the second is what the system calls a double click.
func double_click(at: Vector2) -> void:
	await click(at)
	await press(at, true, true)
	await press(at, false)

func click_on(c: Control) -> void:
	await click(c.get_global_rect().get_center())

## Pressed at `from`, carried to `to`, let go there.
func drag(from: Vector2, to: Vector2) -> void:
	await move(from)
	await press(from, true)
	await move(from.lerp(to, 0.5))
	await move(to)
	await press(to, false)

## A key, pressed and let go, with the letter it types.
func key(code: Key, letter: String = "") -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		if letter != "":
			e.unicode = letter.unicode_at(0)
		Input.parse_input_event(e)
		await frames(1)

## Types `text` the way a keyboard does, a letter at a time.
func type_in(text: String) -> void:
	for ch in text:
		var code := KEY_SPACE if ch == " " else (KEY_A + (ch.to_upper().unicode_at(0) - 65) if ch.to_upper() >= "A" and ch.to_upper() <= "Z" else KEY_PERIOD)
		await key(code, ch)

## A key with the platform's own shortcut modifier held.
func shortcut(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		e.command_or_control_autoremap = true
		Input.parse_input_event(e)
		await frames(2)

func action(which: String) -> void:
	var e := InputEventAction.new()
	e.action = which
	e.pressed = true
	Input.parse_input_event(e)
	await frames(3)

func focus_owner() -> Control:
	return get_viewport().gui_get_focus_owner()

## The button on the bar that says `words`.
func bar_button(words: String) -> Button:
	return desk._bar.find_children("*", "Button", true, false).filter(
		func(b: Button) -> bool: return b.text == words).front()

## The button in the inspector that says `words`, or null.
func inspect_button(words: String) -> Button:
	var found: Array = desk._inspect_rows.find_children("*", "Button", true, false).filter(
		func(b: Button) -> bool: return b.text == words)
	return found.front() if not found.is_empty() else null

## A click on `c`, scrolled into view first: the inspector is longer than the
## screen, and a button below its foot is where nothing can land.
func click_on_scrolled(c: Control) -> void:
	desk._inspect_scroll.ensure_control_visible(c)
	await frames(3)
	await click_on(c)

## The last button in the inspector that says `words`: an action's doer says
## the same name as the node's speaker above it.
func inspect_last(words: String) -> Button:
	var found: Array = desk._inspect_rows.find_children("*", "Button", true, false).filter(
		func(b: Button) -> bool: return b.text == words)
	return found.back() if not found.is_empty() else null

## The property panels in the inspector, in order.
func panels() -> Array:
	return desk._inspect_rows.get_children().filter(func(c: Node) -> bool: return c is PanelContainer)

## The cross on the head of the panel called `title`, or null.
func cross_of(title: String) -> Button:
	for p in panels():
		var head: HBoxContainer = (p as Node).get_child(0).get_child(0)
		if (head.get_child(0) as Button).text == title:
			return head.get_child(1)
	return null

## The entry for `kind` in the list + PROPERTY opens, or null: a button in
## the inspector's own column — where a panel's head, which may say the same,
## stands inside its panel.
func list_entry(kind: String) -> Button:
	for c in desk._inspect_rows.get_children():
		if c is Button and (c as Button).text == Loc.t("hud.story.property.%s" % kind):
			return c
	return null

## + PROPERTY pressed, and `kind` picked from the list it opens.
func add_property(kind: String) -> void:
	await click_on_scrolled(inspect_button(Loc.t("hud.story.add_property")))
	await click_on_scrolled(list_entry(kind))

## The inspector's buttons with no word on them — the crosses — in order.
func crosses() -> Array:
	return desk._inspect_rows.find_children("*", "Button", true, false).filter(
		func(b: Button) -> bool: return b.text == "")

## Every button up over the desk that says `words`.
func popup_buttons(words: String) -> Array:
	if desk._popup == null:
		return []
	return desk._popup.find_children("*", "Button", true, false).filter(
		func(b: Button) -> bool: return b.text == words)

## A point of the sheet, on the screen.
func on_sheet(at: Vector2) -> Vector2:
	return desk._sheet.global_position + at

func node_centre(id: String) -> Vector2:
	return on_sheet(desk.node_rect(id).get_center())

func port(id: String, choice: int = -1) -> Vector2:
	return on_sheet(desk.port_rect(id, choice).get_center())

func screen() -> Vector2:
	return get_viewport().get_visible_rect().size

## A map to play on: the clearing a new map is.
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
	plan[Room.H - 3] = plan[Room.H - 3].left(4) + MadeRoom.START + plan[Room.H - 3].substr(5)
	r.plan = plan
	r.tileset = "grove"
	return r

func _ready() -> void:
	var was_mode := Touch.mode
	var was_language := Loc.language
	Stories.scratch_dir = SCRATCH
	Maps.scratch_dir = MAPS
	_sweep(SCRATCH)
	_sweep(MAPS)
	var laid := stage()
	Maps.save("desk_stage", laid)
	laid.free()
	StoryMaker.forget()
	Touch.set_mode(Touch.OFF)
	Loc.set_language(Loc.DEFAULT)
	GameState.reset_profile()
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(6)
	await _the_door()
	await _the_desk()
	await _the_sheet()
	await _the_inspector()
	await _settings()
	await _keeping()
	await _playing()
	await _leaving()
	await _both_ways()
	Touch.set_mode(was_mode)
	Loc.set_language(was_language)
	_sweep(SCRATCH)
	_sweep(MAPS)
	Stories.scratch_dir = ""
	Maps.scratch_dir = ""
	StoryMaker.forget()
	print("[DESK] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## STORY MAKER is on the title, under MAP CREATOR, and goes to the desk.
func _the_door() -> void:
	var title := game.current as TitleScreen
	var ids: Array = Menus.items("title").map(func(i: Dictionary) -> String: return String(i["id"]))
	check(ids.find("story_maker") == ids.find("map_maker") + 1, "the title has STORY MAKER, straight under MAP CREATOR (%s)" % str(ids))
	var door: Button = null
	for b in title._menu_root.get_children():
		if (b as Button).text == Loc.t("menu.title.story_maker"):
			door = b
	var foot := title._menu_root.get_global_rect().end.y - title._stage.global_position.y
	check(door != null and title._menu_root.get_child_count() == 6 and foot <= TitleScreen.DESIGN.y,
		"as a line of its own, and the column it makes six of still ends on the design (%.0f of %.0f)" % [foot, TitleScreen.DESIGN.y])
	if door != null:
		door.pressed.emit()
	await frames(8)
	maker = game.current as StoryMaker
	check(game.state == GameScript.State.STORY_MAKER and maker != null, "pressing it goes to the story maker (%s)" % game.current)
	view = Views.of(maker) as StoryMakerView
	desk = view.desk if view != null else null
	check(desk != null and desk.is_visible_in_tree() and not maker.playing, "which opens on its desk, writing")
	check(not view.hud.visible and not view.keys.visible and view.camera == null, "with nothing of a played story's on the screen")

func _the_desk() -> void:
	var s := screen()
	check(desk._bar.position == Vector2.ZERO and is_equal_approx(desk._bar.size.x, s.x),
		"the bar runs across the top of the screen (%s)" % str(desk._bar.get_rect()))
	check(is_equal_approx(desk._side.size.x, StoryDesk.SIDE_W) and is_equal_approx(desk._side.get_rect().end.y, s.y),
		"and the column down the left, under it (%s)" % str(desk._side.get_rect()))
	check(is_equal_approx(desk._inspect.size.x, StoryDesk.INSPECT_W) and is_equal_approx(desk._inspect.get_rect().end.x, s.x)
			and is_equal_approx(desk._inspect.get_rect().end.y, s.y),
		"and the inspector down the right (%s)" % str(desk._inspect.get_rect()))
	check(is_equal_approx(desk._sheet.position.x, StoryDesk.SIDE_W) and is_equal_approx(desk._sheet.get_rect().end.x, s.x - StoryDesk.INSPECT_W)
			and is_equal_approx(desk._sheet.get_rect().end.y, s.y),
		"and the sheet has the rest, down to the screen's foot (%s)" % str(desk._sheet.get_rect()))
	check(desk._map.text == "DESK_STAGE", "the column says which map the story is set on (%s)" % desk._map.text)
	check(desk._modes.size() == 3 and (desk._modes[StoryMaker.Mode.FROZEN] as Button).disabled
			and not (desk._modes[StoryMaker.Mode.FREE] as Button).disabled,
		"and the three ways of playing it, the box's lit")
	check(desk._player_name.text == StoryMaker.NEW_PLAYER_NAME
			and desk._side.find_children("*", "LineEdit", true, false).size() == 1,
		"what the player is called, and nothing of the character: the characters are the map's")
	check(maker.node_count() == 0 and desk.selected == "" and desk._inspect_rows.get_child_count() == 1 and desk._text == null,
		"no nodes yet, and the inspector says so")
	check(desk._bar.get_combined_minimum_size().x <= s.x and desk._side.get_combined_minimum_size().x <= StoryDesk.SIDE_W
			and desk._side.get_combined_minimum_size().y <= desk._side.size.y,
		"nothing on it wants more room than it has")

## Nodes put in, given a line, typed, dragged about and led one to another.
func _the_sheet() -> void:
	await click_on(bar_button(Loc.t("hud.story.add_node")))
	check(maker.node_count() == 1 and maker.holds("1") and desk.selected == "1" and maker.start == "1"
			and maker.at_of("1") == StoryMaker.FIRST_AT and maker.properties_of("1").is_empty(),
		"+ NODE puts a node in where a story starts on the desk, with no properties, and picks it")
	check(panels().is_empty() and desk._text == null and inspect_button(Loc.t("hud.story.add_property")) != null
			and is_equal_approx(desk.node_height("1"), StoryDesk.NODE_PAD * 2.0 + StoryDesk.HEAD_H + StoryDesk.ROW_H),
		"its inspector has no panels, only + PROPERTY; on the sheet it is a head and a row saying it holds nothing")
	await click_on(inspect_button(Loc.t("hud.story.add_property")))
	var offered: Array = StoryMaker.PROPERTIES.filter(func(k: String) -> bool: return list_entry(k) != null)
	check(desk._adding and offered.size() == StoryMaker.PROPERTIES.size(),
		"+ PROPERTY opens the list of every kind there is to add (%s)" % str(offered))
	await click_on(list_entry("line"))
	check(maker.has_line("1") and maker.speaker_of("1") == StoryMaker.NPC and not desk._adding and panels().size() == 1
			and desk._text != null and focus_owner() == desk._text,
		"LINE picked from it: a panel of its own, the list shut, the keyboard on its words")
	await click_on(inspect_button(Loc.t("hud.story.add_property")))
	check(list_entry("line") == null and list_entry("action") != null and list_entry("emotion") != null,
		"the list offers no second line; an action it always offers")
	await click_on(inspect_button(Loc.t("hud.story.add_property")))
	check(not desk._adding, "pressed again, the list shuts")
	await click_on(desk._text)
	await type_in("Ah a new face.")
	check(maker.text_of("1") == "Ah a new face." and desk._text.text == maker.text_of("1"),
		"what is typed is the node's words, as they are typed (%s)" % maker.text_of("1"))
	check(inspect_button(StoryMaker.NEW_NAME.to_upper()) != null, "said by the character, by name")
	await key(KEY_ENTER)
	await frames(2)
	check(maker.node_count() == 2 and desk.selected == "2" and maker.next_of("1") == "2" and maker.has_line("2")
			and maker.speaker_of("2") == StoryMaker.PLAYER and focus_owner() == desk._text
			and maker.at_of("2") == maker.at_of("1") + StoryMaker.ALONG and maker.properties_of("2") == PackedStringArray(["line"]),
		"the return key on a line's words is the next node, with a line of the player's and nothing else, led to, with the keyboard on it")
	await type_in("Who are you.")
	var who := inspect_button(StoryMaker.NEW_PLAYER_NAME.to_upper())
	check(who != null, "the line's panel says the player says it")
	await click_on(who)
	check(maker.speaker_of("2") == StoryMaker.NPC and inspect_button(StoryMaker.NEW_NAME.to_upper()) != null,
		"a press on who says it gives it to the other")
	await click_on(inspect_button(StoryMaker.NEW_NAME.to_upper()))
	check(maker.speaker_of("2") == StoryMaker.PLAYER, "and back")
	# A double click on open sheet puts an empty node in there.
	var open := Vector2(80.0, desk._sheet.size.y - 120.0)
	await double_click(on_sheet(open))
	check(maker.node_count() == 3 and desk.selected == "3" and maker.at_of("3") == desk.desk_point(open)
			and maker.properties_of("3").is_empty() and desk._text == null,
		"a double click on open sheet puts an empty node in there, and picks it (%s)" % str(maker.at_of("3")))
	# Dragged, it moves, on the grid.
	var was := maker.at_of("3")
	await drag(node_centre("3"), node_centre("3") + Vector2(80.0, -40.0))
	var moved := maker.at_of("3") - was
	check(moved.x == 80 and absi(moved.y + 40) < int(StoryDesk.GRID) and maker.at_of("3") % int(StoryDesk.GRID) == Vector2i.ZERO
			and desk.selected == "3",
		"dragged, a node moves with the pointer, on the grid (%s from %s)" % [str(maker.at_of("3")), str(was)])
	# A port dragged onto a node leads there; onto nothing, nowhere.
	await drag(port("2"), node_centre("3"))
	check(maker.next_of("2") == "3", "a node's port dragged onto another leads there")
	await drag(port("2"), on_sheet(Vector2(desk._sheet.size.x - 30.0, 30.0)))
	check(maker.next_of("2") == "", "and onto nothing, nowhere")
	await drag(port("2"), node_centre("3"))
	check(maker.next_of("2") == "3" and desk.selected == "2", "and led there again, the node it comes from picked")
	# A click on a node picks it.
	await click(node_centre("1"))
	check(desk.selected == "1" and desk._text != null and desk._text.text == maker.text_of("1"),
		"a click on a node picks it, and its words are up: its line was opened when it was added")
	check(maker.unsaved, "and the story has something to save")

## The node picked, given properties one at a time in the inspector: added —
## open, to be filled in — set, folded shut and open, taken off.
func _the_inspector() -> void:
	await click(node_centre("3"))
	check(desk.selected == "3" and panels().is_empty(), "node 3 is picked, with no properties")
	await add_property("emotion")
	check(maker.has_property("3", "emotion") and maker.emotion_of("3") == StoryMaker.NEW_EMOTION and panels().size() == 1
			and inspect_button(Loc.t("hud.story.emotion.neutral")).disabled,
		"EXPRESSION added, as no face yet, in a panel")
	await click_on_scrolled(inspect_button(Loc.t("hud.story.emotion.happy")))
	check(maker.emotion_of("3") == "happy" and inspect_button(Loc.t("hud.story.emotion.happy")).disabled,
		"an expression is picked with its button, and lit")
	await add_property("effect")
	check(maker.effect_of("3") == StoryMaker.NEW_EFFECT and panels().size() == 2, "LETTERS added, waving")
	await click_on_scrolled(inspect_button(Loc.t("hud.story.effect.shake")))
	check(maker.effect_of("3") == "shake" and inspect_button(Loc.t("hud.story.effect.shake")).disabled, "and the motion picked")
	# Folded shut by its head, and open again.
	await click_on_scrolled(inspect_button(Loc.t("hud.story.property.effect")))
	check(not desk._open.has("3:effect") and inspect_button(Loc.t("hud.story.effect.shake")) == null and maker.effect_of("3") == "shake"
			and panels().size() == 2,
		"a panel's head folds it shut, and what it holds is kept")
	await click_on_scrolled(inspect_button(Loc.t("hud.story.property.effect")))
	check(desk._open.has("3:effect") and inspect_button(Loc.t("hud.story.effect.shake")) != null, "and open again")
	# Its cross takes it off at once: it holds no words.
	await click_on_scrolled(cross_of(Loc.t("hud.story.property.effect")))
	check(not maker.has_property("3", "effect") and panels().size() == 1, "the cross on its head takes it off the node, at once")
	# Answers make it a question.
	await add_property("choices")
	check(maker.asks("3") and maker.choices_of("3").size() == 1 and desk._answer_edits.size() == 1 and focus_owner() == desk._answer_edits[0],
		"ANSWERS added make it a question, the keyboard on the first answer")
	await type_in("Yes.")
	check(String(maker.choices_of("3")[0]["text"]) == "Yes.", "what is typed is the answer")
	await drag(port("3", 0), node_centre("1"))
	check(String(maker.choices_of("3")[0].get("next", "")) == "1", "an answer's port dragged onto a node leads there")
	await click_on_scrolled(cross_of(Loc.t("hud.story.property.choices")))
	check(maker.asks("3") and desk._armed == "drop:3:choices" and cross_of(Loc.t("hud.story.property.choices")).text == Loc.t("hud.story.sure"),
		"the cross on answers with words in them only asks, the first time")
	# Two actions, a panel each, numbered.
	await add_property("action")
	await add_property("action")
	check(maker.actions_of("3").size() == 2 and cross_of(Loc.t("hud.story.action_n", [1])) != null
			and cross_of(Loc.t("hud.story.action_n", [2])) != null,
		"ACTION added twice is two panels, numbered")
	check(maker.actions_of("3")[0] == {"who": StoryMaker.NPC, "do": "walk", "to": StoryMaker.PLAYER},
		"each starting as the character walking toward the player")
	await click_on_scrolled(inspect_button(Loc.t("hud.story.do.walk")))
	check(String(maker.actions_of("3")[0]["do"]) == "run", "a press on what it does goes on to the next doing")
	await click_on_scrolled(inspect_button(Loc.t("hud.story.to_whom", [StoryMaker.NEW_PLAYER_NAME.to_upper()])))
	check(String(maker.actions_of("3")[0]["to"]) == StoryMaker.NPC, "and on where it goes, to the next")
	await click_on_scrolled(inspect_button(Loc.t("hud.story.to_whom", [StoryMaker.NEW_NAME.to_upper()])))
	check(String(maker.actions_of("3")[0]["to"]) == "left" and int(maker.actions_of("3")[0]["steps"]) == StoryMaker.NEW_STEPS,
		"left, so many cells")
	await click_on_scrolled(inspect_button("+"))
	check(int(maker.actions_of("3")[0]["steps"]) == StoryMaker.NEW_STEPS + 1, "which a press on + makes one more")
	await click_on_scrolled(inspect_button(StoryMaker.NEW_NAME.to_upper()))
	check(String(maker.actions_of("3")[0]["who"]) == StoryMaker.PLAYER and String(maker.actions_of("3")[1]["who"]) == StoryMaker.NPC,
		"and a press on who does it gives it to the other, and the other action to nobody else")
	await click_on_scrolled(cross_of(Loc.t("hud.story.action_n", [2])))
	check(maker.actions_of("3").size() == 1 and String(maker.actions_of("3")[0]["do"]) == "run"
			and cross_of(Loc.t("hud.story.property.action")) != null,
		"the cross on the second takes that one off, and the first is ACTION again")
	await click_on_scrolled(cross_of(Loc.t("hud.story.property.action")))
	check(maker.actions_of("3").is_empty() and not maker.has_property("3", "action"), "and on the last, the last")
	check(maker.properties_of("3") == PackedStringArray(["emotion", "choices"])
			and panels().size() == 2 and (panels()[0].get_child(0).get_child(0).get_child(0) as Button).text == Loc.t("hud.story.property.emotion"),
		"what it has is shown in one order, whatever order it came in")
	await click_on_scrolled(inspect_button(Loc.t("hud.story.start_here")))
	check(maker.start == "3" and inspect_button(Loc.t("hud.story.is_start")) != null, "START HERE moves the start")
	await click(node_centre("1"))
	await click_on_scrolled(inspect_button(Loc.t("hud.story.start_here")))
	check(maker.start == "1", "and back")
	# A line with words in it asks before it goes, and comes back the other's.
	await click(node_centre("2"))
	check(desk.selected == "2" and maker.has_line("2"), "node 2 is picked, with its line")
	await click_on_scrolled(cross_of(Loc.t("hud.story.property.line")))
	check(maker.has_line("2") and desk._armed == "drop:2:line" and cross_of(Loc.t("hud.story.property.line")).text == Loc.t("hud.story.sure"),
		"the cross on a line with words in it only asks, the first time")
	await click_on_scrolled(cross_of(Loc.t("hud.story.property.line")))
	check(not maker.has_line("2") and maker.properties_of("2").is_empty() and panels().is_empty(),
		"and takes the line off the second, words and all")
	await add_property("line")
	check(maker.has_line("2") and maker.speaker_of("2") == StoryMaker.PLAYER and focus_owner() == desk._text,
		"a line added again is the player's turn, the character's line leading to it")
	await type_in("Who are you.")
	await click(node_centre("3"))
	await click_on_scrolled(inspect_button(Loc.t("hud.story.delete_node")))
	check(maker.holds("3") and desk._armed == "remove:3" and inspect_button(Loc.t("hud.story.sure")) != null,
		"DELETE NODE only asks, the first time")
	await click_on_scrolled(inspect_button(Loc.t("hud.story.sure")))
	check(not maker.holds("3") and maker.node_count() == 2 and maker.next_of("2") == "" and desk.selected == "1",
		"and takes the node off the desk the second, with every link to it, and picks the start")

## What the story is set on and how it plays, from the column.
func _settings() -> void:
	await click_on(desk._modes[StoryMaker.Mode.NOVEL])
	check(maker.mode == StoryMaker.Mode.NOVEL and (desk._modes[StoryMaker.Mode.NOVEL] as Button).disabled
			and not (desk._modes[StoryMaker.Mode.FROZEN] as Button).disabled,
		"a way of playing is picked with its button, and lit")
	await click_on(desk._modes[StoryMaker.Mode.FROZEN])
	check(maker.mode == StoryMaker.Mode.FROZEN, "and another")
	await click_on(desk._map)
	await frames(2)
	var maps: Array = popup_buttons("DESK_STAGE")
	check(desk._popup != null and maps.size() == 1 and (maps[0] as Button).disabled,
		"MAP puts up the maps the map creator has kept, the one the story is set on lit")
	await action("ui_cancel")
	check(desk._popup == null and not get_tree().paused, "the cancel key puts the list away, and does not pause the desk behind it")
	await click_on(desk._map)
	await frames(2)
	desk._import("desk_stage")
	await frames(2)
	check(maker.map_id == "desk_stage" and desk._popup == null, "a map picked is the story's, and the list goes")
	desk._player_name.text = "You"
	desk._player_name.text_changed.emit("You")
	await click(node_centre("2"))
	check(maker.player_name == "You" and inspect_button("YOU") != null, "and so is the player's")

func _keeping() -> void:
	desk._name.text = "   "
	desk._save()
	await frames(2)
	check(maker.unsaved and Stories.ids().is_empty() and desk._said == Loc.t("hud.story.refused.name"),
		"SAVE with no name keeps nothing, and says why (%s)" % desk._said)
	desk._name.text = "Desk Story"
	await shortcut(KEY_S)
	check(not maker.unsaved and Stories.exists("desk_story") and maker.story_id == "desk_story",
		"with a name, the save key keeps the story under it")
	check(desk._name.text == "desk_story" and desk._said.contains(Stories.path_of("desk_story")),
		"the field shows the name it was filed under, and the foot says where (%s)" % desk._said)
	desk._new()
	await frames(2)
	check(maker.node_count() == 0 and maker.story_id == "" and desk._name.text == "" and desk.selected == ""
			and maker.npc_name == StoryMaker.NEW_NAME and desk._player_name.text == StoryMaker.NEW_PLAYER_NAME and not maker.unsaved,
		"NEW clears the desk, the name and the character with it")
	desk._name.text = "desk story"
	desk._save()
	await frames(2)
	check((Stories.load_story("desk_story")["nodes"] as Dictionary).size() == 2 and desk._armed != "",
		"SAVE under the name of a story kept already only asks, the first time")
	desk._save()
	await frames(2)
	check((Stories.load_story("desk_story")["nodes"] as Dictionary).is_empty() and desk._armed == "", "and replaces it the second")
	desk._name.text = "other tale"
	maker.add_node(Vector2i.ZERO, StoryMaker.NPC, "Once.")
	desk._save()
	await frames(2)
	desk._open_list()
	await frames(3)
	var picks: Array = desk._popup.find_children("*", "Button", true, false).map(func(b: Button) -> String: return b.text)
	check(desk._popup != null and picks.has("OTHER_TALE") and picks.has("DESK_STORY"),
		"LOAD lists every story that is kept (%s)" % str(picks))
	desk._delete("other_tale")
	await frames(2)
	check(Stories.exists("other_tale") and desk._armed == "delete:other_tale", "DELETE only asks, the first time")
	desk._delete("other_tale")
	await frames(2)
	check(not Stories.exists("other_tale") and Stories.exists("desk_story"), "and throws that story away the second, and no other")
	await action("ui_cancel")
	maker.add_node_after("1")
	maker.set_text("2", "Twice.")
	desk._name.text = "desk story"
	# Over another story's name: the first press asks, the second replaces.
	desk._save()
	desk._save()
	await frames(2)
	check(maker.story_id == "desk_story" and (Stories.load_story("desk_story")["nodes"] as Dictionary).size() == 2,
		"the desk's story saved over the kept one under that name")
	desk._open_list()
	await frames(2)
	desk._load("desk_story")
	await frames(3)
	check(desk._popup == null and maker.story_id == "desk_story" and desk._name.text == "desk_story"
			and maker.node_count() == 2 and desk.selected == maker.start and desk._player_name.text == maker.player_name,
		"a story picked from the list is put on the desk under its name with its start picked, and the list goes")
	check(desk._open.is_empty() and desk._text == null and not panels().is_empty()
			and panels().size() == maker.properties_of(maker.start).size(),
		"its properties come up folded shut, a head each (%d)" % panels().size())
	await click_on_scrolled(inspect_button(Loc.t("hud.story.property.line")))
	check(desk._open.has(maker.start + ":line") and desk._text != null and desk._text.text == maker.text_of(maker.start)
			and panels().size() == maker.properties_of(maker.start).size(),
		"a press on a head opens that one, and its words are up")

## Each of the three ways, from PLAY, and back from each.
func _playing() -> void:
	maker.set_mode(StoryMaker.Mode.FROZEN)
	bar_button(Loc.t("hud.story.play")).pressed.emit()
	await frames(8)
	check(maker.playing and not desk.is_visible_in_tree() and view.hud.visible and view.keys.visible and view.camera != null,
		"PLAY puts the desk away and a played story's readout up, with a camera")
	check(view.hud.player == maker.player and Pointer.who() == Pointer.Who.HAND,
		"the raid's own HUD over the body in it, and the pointer the player's")
	var who := Views.of(maker.npc) as NpcView
	check(who != null and who.dialogue != null and who.bubble != null and get_tree().get_nodes_in_group("enemies").is_empty(),
		"the character has their view, with the box and the bubble, and nothing else stands in the map")
	var drawn := Views.of(maker.room) as MadeRoomView
	check(drawn != null and drawn.tiles.id() == "grove" and view.pixels.lighting.ambient == MapTiles.of("grove").ambient(),
		"the map drawn in its tileset, in its own light")
	check(game._touch_face() == TouchPad.Face.PLAY, "and the console wears its playing face")
	await action("pause")
	check(not maker.playing and desk.is_visible_in_tree() and not get_tree().paused and not view.hud.visible and view.camera == null,
		"the pause key on a played story goes back to the desk, and strikes the camera")
	check(get_tree().get_nodes_in_group("npcs").is_empty() and get_tree().get_nodes_in_group("player").is_empty(),
		"with nothing left standing from the play")
	maker.set_mode(StoryMaker.Mode.FREE)
	desk._play()
	await frames(8)
	who = Views.of(maker.npc) as NpcView
	check(maker.playing and maker.npc.mode == Npc.Mode.FREE and maker.npc.free_story and who != null and who.bubble != null,
		"played free, the character talks in a bubble, with questions for the box")
	await action("pause")
	check(not maker.playing and desk.is_visible_in_tree(), "and the pause key comes back from that too")
	maker.set_mode(StoryMaker.Mode.NOVEL)
	desk._play()
	await frames(8)
	var seen := Views.of(maker.scene) as CutsceneView
	check(maker.playing and maker.reading() and seen != null and seen.box != null and view.camera == null
			and not view.hud.visible and not view.keys.visible,
		"played as a novel, the scene brings its own camera and panel, and nothing of a raid's is up")
	check(seen.pixels.lighting.ambient == MapTiles.of("grove").ambient(), "in the map's light")
	check(game._touch_face() == TouchPad.Face.TALK, "and the console wears the face a scene does")
	await action("ui_cancel")
	await frames(3)
	check(not maker.playing and desk.is_visible_in_tree() and not get_tree().paused and maker.scene == null,
		"the cancel key skips the novel, back to the desk")
	maker.set_mode(StoryMaker.Mode.FROZEN)
	desk._new()
	desk._play()
	await frames(2)
	check(not maker.playing and desk._said == Loc.t("hud.story.refused.empty"),
		"PLAY on a story with nothing to say stays at the desk, and says why (%s)" % desk._said)
	desk._load("desk_story")
	await frames(2)

func _leaving() -> void:
	await action("pause")
	check(get_tree().paused and game.pause_menu.visible and game.pause_title.visible and not game.pause_abandon.visible,
		"the pause key on the desk opens PAUSED, with MAIN MENU on it")
	game._pause_to_title()
	await frames(6)
	check(game.state == GameScript.State.TITLE and not get_tree().paused, "MAIN MENU goes to the title")
	game.goto_story_maker()
	await frames(6)
	maker = game.current as StoryMaker
	view = Views.of(maker) as StoryMakerView
	desk = view.desk
	check(maker.story_id == "desk_story" and maker.node_count() == 2 and desk._name.text == "desk_story" and desk.selected == maker.start,
		"and the story that was on the desk is on it when the maker is come back to")
	(desk._bar.find_children("*", "Button", true, false)[0] as Button).pressed.emit()
	await frames(6)
	check(game.state == GameScript.State.TITLE, "the arrow in the desk's corner goes to the title too")
	game.goto_story_maker()
	await frames(6)
	maker = game.current as StoryMaker
	view = Views.of(maker) as StoryMakerView
	desk = view.desk

## In the other language and in mobile mode the desk is built again, and
## still fits: nothing wider than the bar, the columns their own widths and no
## taller than the screen, and the nodes still on it with the start picked —
## its properties folded shut, as a desk built afresh has them.
func _both_ways() -> void:
	for lang in Loc.languages():
		for thumb in [false, true]:
			Loc.set_language(lang)
			Touch.set_mode(Touch.ON if thumb else Touch.OFF)
			await frames(6)
			var s := screen()
			var how := "%s, %s" % [lang, "for a thumb" if thumb else "at a desk"]
			check(desk._bar.get_combined_minimum_size().x <= s.x and is_equal_approx(desk._bar.size.x, s.x),
				"the bar fits the screen (%s: %.0f of %.0f)" % [how, desk._bar.get_combined_minimum_size().x, s.x])
			check(is_equal_approx(desk._side.size.x, StoryDesk.SIDE_W) and desk._side.get_combined_minimum_size().y <= s.y - desk._bar.size.y,
				"the column is its own width and no taller than the room under the bar (%s: %s wants %s)"
					% [how, str(desk._side.size), str(desk._side.get_combined_minimum_size())])
			check(is_equal_approx(desk._inspect.size.x, StoryDesk.INSPECT_W) and desk._inspect_rows.get_combined_minimum_size().x <= StoryDesk.INSPECT_W - StoryDesk.PANEL_PAD * 2.0,
				"the inspector is its own width, and nothing in it wants more (%s: %.0f)" % [how, desk._inspect_rows.get_combined_minimum_size().x])
			check(is_equal_approx(desk._sheet.position.x, StoryDesk.SIDE_W) and desk._sheet.size.x > 0.0 and desk._sheet.size.y > 0.0,
				"and the sheet has the rest (%s: %s)" % [how, str(desk._sheet.get_rect())])
			check(maker.node_count() == 2 and desk.selected == maker.start and desk._player_name.text == maker.player_name
					and panels().size() == maker.properties_of(maker.start).size() and desk._text == null,
				"with the nodes still on it, the start picked, its properties folded shut as they come up, and the names (%s)" % how)
	Touch.set_mode(Touch.OFF)
	Loc.set_language(Loc.DEFAULT)
	await frames(4)

## Empties a scratch folder, and takes it away.
func _sweep(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir)
