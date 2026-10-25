class_name StoryDesk
extends Control

## The desk a story is written at, in the story maker (`StoryMaker`): the
## story's nodes on a sheet in the middle, each a box showing what it holds,
## with a port on its right that leads on, or one on each of its answers;
## down the right the node picked, after Blender's properties — it starts
## with nothing, + PROPERTY adds what it needs (a line, an expression, a
## motion for its letters, an action, answers), and each is a panel that
## comes up folded shut — its head alone, which opens it and shuts it again —
## and comes off by its cross; down the left what the
## story is set on and how it is played; and along the top the story's name
## and what is done with it — SAVE, LOAD, NEW, a node put in, PLAY.
##
## A pointer's sheet: a node is picked up and carried, a port is dragged onto
## another node to lead there — or onto nothing, to lead nowhere — a double
## click on open sheet puts a node in there, the sheet itself is carried by a
## drag on it, the middle button or the move keys, and brought nearer or
## further by the wheel. The delete key takes the node picked off the desk,
## asking twice. Nothing here takes the keyboard but the fields, so the keys
## are the sheet's whenever nothing is being typed.
##
## It makes no change of its own: everything it does is asked of the maker,
## which is what a test asks too.

## How wide the column down the left is and the one down the right, and how
## tall the line along the bottom.
const SIDE_W := 232.0
const INSPECT_W := 316.0
## The room a panel of the desk's keeps inside its edge, in either mode.
const PANEL_PAD := 8.0
## How much of its own size a node is drawn at, nearest first.
const ZOOMS := [1.0, 0.5]
## Screen pixels a second the move keys carry the sheet.
const PAN_SPEED := 900.0
## A node's shape, at its own size: how wide, how much room inside its edge,
## how tall its head and each row under it stand, how many rows of its words
## it shows, and the port on its right, with how far round one the pointer has
## hold of it. Nodes stand on a grid of GRID.
const NODE_W := 224.0
const NODE_PAD := 6.0
const HEAD_H := 22.0
const ROW_H := PixelDraw.LINE
const TEXT_ROWS := 2
const PORT := 8.0
const GRAB := 10.0
const GRID := 8.0
## How far a link runs straight out of a port before it turns.
const LINK_RUN := 14.0
## How long a button that asks twice stays asked, and a line stays said.
const ARM_TIME := 3.0
const SAY_TIME := 4.0
const DOTS := Color(1, 1, 1, 0.06)
## The room a property's panel keeps inside its edge, and the room left at a
## panel head's left for the mark that says whether it is open.
const PROP_PAD := 6.0
const FOLD_ROOM := 26.0
## A property's panel open, and folded shut.
const ICON_OPEN := [
	".......",
	".......",
	"#######",
	".#####.",
	"..###..",
	"...#...",
	".......",
]
const ICON_SHUT := [
	"..#....",
	"..##...",
	"..###..",
	"..####.",
	"..###..",
	"..##...",
	"..#....",
]
const ICON_OUT := [
	"#.....#",
	".#...#.",
	"..#.#..",
	"...#...",
	"..#.#..",
	".#...#.",
	"#.....#",
]

var maker: StoryMaker
## The node picked, whose inspector is up, or "" for none.
var selected: String = ""

var _px := PixelDraw.new(self)
var _bar: PanelContainer
var _side: PanelContainer
var _sheet: Sheet
var _inspect: PanelContainer
var _inspect_rows: VBoxContainer
var _inspect_scroll: ScrollContainer
## The inspector's fields, while a node is picked: the words, the answers'
## words.
var _text: LineEdit = null
var _answer_edits: Array = []
## The properties folded open, by "<node>:<kind>" — an action's by
## "<node>:action:<place>". Every other is shut: a node's properties come up
## folded, a head each, and are opened one at a time. The desk's own, and no
## part of the story.
var _open: Dictionary = {}
## Whether the list of properties to add is open under + PROPERTY.
var _adding: bool = false
var _name: LineEdit
var _map: Button
## Mode -> its button.
var _modes: Dictionary = {}
var _player_name: LineEdit
## Where the sheet's origin stands on it, and how near the nodes are.
var _origin := Vector2.ZERO
var _zoom_at: int = 0
## The node the pointer is carrying, and where in it it was taken.
var _dragging: String = ""
var _grip := Vector2.ZERO
## A link being dragged: the node and the answer (-1 for its own) it comes
## from, and where the pointer has its end.
var _linking: Dictionary = {}
var _link_at := Vector2.ZERO
var _panning: bool = false
var _pan_at := Vector2.ZERO
## What is up over the desk — the list of kept stories, or the maps — or null.
var _popup: Control = null
## The line the desk is saying over the sheet's foot, in what colour, and for
## how much longer: what SAVE did, why PLAY or a save was refused.
var _said: String = ""
var _said_tone := UiKit.TEXT
var _said_left: float = 0.0
## What has been asked once and waits to be asked again — "save:<id>" over
## another story's name, "delete:<id>", "remove:<node>" — and for how long.
var _armed: String = ""
var _armed_left: float = 0.0
## The name the field was last given by the maker, to see the story change.
var _shown_id: String = ""
## Whether the chrome was built for a thumb.
var _thumb: bool = false

## The sheet the nodes stand on. What it shows is drawn by the desk.
class Sheet extends Control:
	var desk: StoryDesk
	func _draw() -> void:
		desk._paint_sheet(self)

func _ready() -> void:
	UiKit.fill_screen(self)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build()
	Loc.language_changed.connect(func(_lang: String) -> void: _build())

## --- the chrome -------------------------------------------------------------

## Everything on the desk but the story's own state, built for the language
## and the mode in force: built again when either changes.
func _build() -> void:
	var typed := _name.text if _name != null else maker.story_id
	for old in get_children():
		remove_child(old)
		old.queue_free()
	_popup = null
	_text = null
	_answer_edits.clear()
	_thumb = UiKit.mobile()
	_sheet = Sheet.new()
	_sheet.desk = self
	_sheet.clip_contents = true
	_sheet.gui_input.connect(_on_sheet_input)
	add_child(_sheet)
	_build_bar(typed)
	_build_side()
	_build_inspect()
	_shown_id = maker.story_id
	if not maker.holds(selected):
		selected = maker.start
	_fit()
	_refresh()
	_fill_inspect()

func _build_bar(typed: String) -> void:
	_bar = _panel()
	add_child(_bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_bar.add_child(row)
	var back := _button(Loc.t("menu.pause.arrow"), UiKit.ACCENT)
	back.custom_minimum_size.x = 44.0
	back.pressed.connect(func() -> void: maker.leave())
	row.add_child(back)
	row.add_child(_word(Loc.t("hud.story.title"), Color(0.9, 0.95, 1.0)))
	_name = _edit(typed, Loc.t("hud.story.name"))
	_name.max_length = Maps.ID_LENGTH
	_name.custom_minimum_size.x = 200.0
	_name.text_submitted.connect(func(_text: String) -> void: _name.release_focus())
	row.add_child(_name)
	_bar_button(row, "hud.story.save", UiKit.GOOD, _save)
	_bar_button(row, "hud.story.load", UiKit.ACCENT, _open_list)
	_bar_button(row, "hud.story.new", UiKit.ACCENT, _new)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	_bar_button(row, "hud.story.add_node", UiKit.ACCENT, _add_node)
	var play := _bar_button(row, "hud.story.play", UiKit.GOOD, _play)
	play.custom_minimum_size.x = 96.0

func _bar_button(row: HBoxContainer, key: String, tone: Color, press: Callable) -> Button:
	var b := _button(Loc.t(key), tone)
	b.pressed.connect(press)
	row.add_child(b)
	return b

## What the story is set on and how it is played, down the left.
func _build_side() -> void:
	_side = _panel()
	add_child(_side)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_side.add_child(column)
	column.add_child(_word(Loc.t("hud.story.map"), UiKit.DIM))
	_map = _side_button(column, _open_maps)
	column.add_child(UiKit.hline(true))
	column.add_child(_word(Loc.t("hud.story.mode"), UiKit.DIM))
	_modes.clear()
	for m in StoryMaker.MODE_IDS.size():
		var b := _side_button(column, func() -> void: _set_mode(m))
		_say_on(b, Loc.t("hud.story.modes.%s" % StoryMaker.MODE_IDS[m]))
		_chosen_look(b)
		_modes[m] = b
	# Who the character is and what they look like are not set here: the
	# characters are the map's, set where the map is made.
	column.add_child(UiKit.hline(true))
	column.add_child(_word(Loc.t("hud.story.player"), UiKit.DIM))
	_player_name = _edit(maker.player_name, Loc.t("hud.story.you"))
	_player_name.text_changed.connect(func(text: String) -> void:
		maker.set_player_name(text)
		_refresh()
		_fill_inspect())
	column.add_child(_player_name)

## The column down the right the node picked is written in: a list that
## scrolls, filled by `_fill_inspect`.
func _build_inspect() -> void:
	_inspect = _panel()
	add_child(_inspect)
	_inspect_scroll = ScrollContainer.new()
	_inspect_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UiKit.pixel_scroll(_inspect_scroll)
	_inspect.add_child(_inspect_scroll)
	_inspect_rows = VBoxContainer.new()
	_inspect_rows.add_theme_constant_override("separation", 6)
	_inspect_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inspect_scroll.add_child(_inspect_rows)

## The node picked, after Blender's properties: its head — which node, whether
## the story starts there, where it leads — then + PROPERTY, which opens the
## list of what can be added, and under it a panel for each property the node
## has, in the order the list offers them. A node starts with none. Built
## again whenever the node changes shape — a property, an answer or an action
## put in or taken away, a panel folded, a link made; the words are typed
## straight into the maker, and never rebuild it.
func _fill_inspect() -> void:
	for old in _inspect_rows.get_children():
		_inspect_rows.remove_child(old)
		old.queue_free()
	_text = null
	_answer_edits.clear()
	var id := selected
	if not maker.holds(id):
		var none := _word(Loc.t("hud.story.nothing_picked"), UiKit.DIM)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_inspect_rows.add_child(none)
		return
	# The head: which node, whether the story starts here, and where it leads.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	_inspect_rows.add_child(head)
	var title := _word(Loc.t("hud.story.node", [id]), Color(0.9, 0.95, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var starts := _button(Loc.t("hud.story.is_start" if maker.start == id else "hud.story.start_here"), UiKit.GOOD)
	_chosen_look(starts)
	starts.disabled = maker.start == id
	starts.pressed.connect(func() -> void:
		maker.set_start(id)
		_fill_inspect()
		_sheet.queue_redraw()
		Audio.play("ui"))
	head.add_child(starts)
	if not maker.asks(id):
		var leads := HBoxContainer.new()
		leads.add_theme_constant_override("separation", 4)
		_inspect_rows.add_child(leads)
		var to := maker.next_of(id)
		var where := _word(Loc.t("hud.story.leads_to", [to]) if to != "" else Loc.t("hud.story.leads_end"), UiKit.DIM)
		where.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		where.clip_text = true
		leads.add_child(where)
		if to != "":
			var cut := _button(Loc.t("hud.story.unlink"), UiKit.DIM)
			cut.pressed.connect(func() -> void:
				maker.link(id, "")
				_fill_inspect()
				_sheet.queue_redraw()
				Audio.play("ui"))
			leads.add_child(cut)
	# What can be added, and the list it opens.
	var add := _button(Loc.t("hud.story.add_property"), UiKit.GOOD)
	add.pressed.connect(func() -> void:
		_adding = not _adding
		_fill_inspect()
		Audio.play("ui"))
	_inspect_rows.add_child(add)
	if _adding:
		for kind in StoryMaker.PROPERTIES:
			if not maker.can_add(id, kind):
				continue
			var b := _button(Loc.t("hud.story.property.%s" % kind), UiKit.ACCENT)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			for state in ["normal", "hover", "pressed", "focus", "disabled"]:
				(b.get_theme_stylebox(state) as StyleBoxFlat).content_margin_left = FOLD_ROOM
			b.pressed.connect(func() -> void: _add_property(id, kind))
			_inspect_rows.add_child(b)
	_inspect_rows.add_child(UiKit.hline(true))
	# The properties it has.
	for kind in maker.properties_of(id):
		match kind:
			"line":
				_line_panel(id)
			"emotion":
				_emotion_panel(id)
			"effect":
				_effect_panel(id)
			"action":
				for i in maker.actions_of(id).size():
					_action_panel(id, i)
			"choices":
				_choices_panel(id)
	if not maker.properties_of(id).is_empty():
		_inspect_rows.add_child(UiKit.hline(true))
	# And the way off the desk.
	var remove := _button(Loc.t("hud.story.sure" if _armed == "remove:" + id else "hud.story.delete_node"), UiKit.BAD)
	remove.pressed.connect(func() -> void: _remove(id))
	_inspect_rows.add_child(remove)

## A property's panel: a head that folds it shut or open, with its name on it,
## and a cross that takes it off the node — at once, or, where `has_words`
## says it holds words that would go with it, on the second press. Under the
## head, what it holds: the column returned, or null while it is folded shut.
func _property(key: String, title: String, remove: Callable, has_words: Callable = Callable()) -> VBoxContainer:
	var box := PanelContainer.new()
	var look := UiKit.style(UiKit.BG, UiKit.LINE, 1, 0, true)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		look.set_content_margin(side, PROP_PAD)
	box.add_theme_stylebox_override("panel", look)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	_inspect_rows.add_child(box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	box.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	column.add_child(head)
	var shut := not _open.has(key)
	var fold := _button(title, UiKit.ACCENT)
	fold.alignment = HORIZONTAL_ALIGNMENT_LEFT
	fold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fold.clip_text = true
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		(fold.get_theme_stylebox(state) as StyleBoxFlat).content_margin_left = FOLD_ROOM
	fold.draw.connect(func() -> void:
		PixelDraw.new(fold).icon_centered(Vector2(14.0, fold.size.y * 0.5).floor(), ICON_SHUT if shut else ICON_OPEN,
			Color.WHITE if fold.is_hovered() else UiKit.TEXT))
	fold.pressed.connect(func() -> void:
		if shut:
			_open[key] = true
		else:
			_open.erase(key)
		_fill_inspect()
		Audio.play("ui"))
	head.add_child(fold)
	var cross := _icon_button(ICON_OUT, func() -> void: _drop(key, remove, has_words))
	if _armed == "drop:" + key:
		_say_on(cross, Loc.t("hud.story.sure"))
		cross.add_theme_color_override("font_color", UiKit.BAD)
	head.add_child(cross)
	return null if shut else column

## A property's cross: off the node at once — or, where it holds words that
## would go with it, on the second press.
func _drop(key: String, remove: Callable, has_words: Callable) -> void:
	if has_words.is_valid() and bool(has_words.call()) and _armed != "drop:" + key:
		_arm("drop:" + key)
		_fill_inspect()
		Audio.play("ui")
		return
	_armed = ""
	_open.erase(key)
	remove.call()
	_fill_inspect()
	_sheet.queue_redraw()
	Audio.play("deny")

## + PROPERTY's list, picked from: the property added, open, and the list
## shut; the keyboard on the words a line or answers bring.
func _add_property(id: String, kind: String) -> void:
	var at := maker.add_property(id, kind)
	_adding = false
	if at < 0:
		return
	# The one just added opens, to be filled in; the rest stay as they were.
	_open["%s:action:%d" % [id, at] if kind == "action" else "%s:%s" % [id, kind]] = true
	_fill_inspect()
	_sheet.queue_redraw()
	var typed: Control = null
	if kind == "line":
		typed = _text
	elif kind == "choices" and not _answer_edits.is_empty():
		typed = _answer_edits[0]
	if typed != null:
		typed.grab_focus()
		_inspect_scroll.ensure_control_visible.call_deferred(typed)
	Audio.play("ui")

## Two columns of buttons, an option each, the one in force lit: an
## expression, a motion of the letters.
func _grid(options: Array, picked: String, name_of: Callable, pick: Callable) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	for option in options:
		var b := _button(String(name_of.call(option)), UiKit.ACCENT)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		_chosen_look(b)
		b.disabled = String(option) == picked
		b.pressed.connect(func() -> void:
			pick.call(option)
			_fill_inspect()
			_sheet.queue_redraw()
			Audio.play("ui"))
		grid.add_child(b)
	return grid

## LINE: who says it — pressed, the other of the two — and the words, where
## the return key puts in the next line.
func _line_panel(id: String) -> void:
	var body := _property(id + ":line", Loc.t("hud.story.property.line"),
		func() -> void: maker.remove_property(id, "line"),
		func() -> bool: return maker.text_of(id).strip_edges() != "")
	if body == null:
		return
	var who := _button(_who(maker.speaker_of(id)), UiKit.ACCENT)
	who.alignment = HORIZONTAL_ALIGNMENT_LEFT
	who.pressed.connect(func() -> void:
		if maker.toggle_speaker(id):
			_say_on(who, _who(maker.speaker_of(id)))
			_sheet.queue_redraw()
			Audio.play("ui"))
	body.add_child(who)
	_text = _edit(maker.text_of(id), Loc.t("hud.story.line"))
	_text.text_changed.connect(func(text: String) -> void:
		maker.set_text(id, text)
		_sheet.queue_redraw())
	_text.text_submitted.connect(func(_typed: String) -> void: _next_line())
	body.add_child(_text)

## EXPRESSION: one of the faces the picture draws.
func _emotion_panel(id: String) -> void:
	var body := _property(id + ":emotion", Loc.t("hud.story.property.emotion"),
		func() -> void: maker.remove_property(id, "emotion"))
	if body == null:
		return
	body.add_child(_grid(Array(StoryMaker.emotions()), maker.emotion_of(id),
		func(e) -> String: return Loc.opt("hud.story.emotion.%s" % e, String(e).to_upper()),
		func(e) -> void: maker.set_emotion(id, String(e))))

## LETTERS: how the letters move, in place of what the expression does to them.
func _effect_panel(id: String) -> void:
	var body := _property(id + ":effect", Loc.t("hud.story.property.effect"),
		func() -> void: maker.remove_property(id, "effect"))
	if body == null:
		return
	body.add_child(_grid(StoryMaker.EFFECTS, maker.effect_of(id),
		func(e) -> String: return Loc.t("hud.story.effect.%s" % e),
		func(e) -> void: maker.set_effect(id, String(e))))

## An ACTION, a panel each, numbered when there is more than one: who does it
## and what, then what that kind of doing takes — where a walk goes and how
## far, a pose of the ones who has, a way to turn.
func _action_panel(id: String, i: int) -> void:
	var many := maker.actions_of(id).size() > 1
	var title := Loc.t("hud.story.action_n", [i + 1]) if many else Loc.t("hud.story.property.action")
	var body := _property("%s:action:%d" % [id, i], title, func() -> void: _drop_action(id, i))
	if body == null:
		return
	var a: Dictionary = maker.actions_of(id)[i]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	body.add_child(row)
	var who := String(a.get("who", StoryMaker.NPC))
	var who_button := _button(_who(who), UiKit.ACCENT)
	who_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who_button.clip_text = true
	who_button.pressed.connect(func() -> void:
		_set_action(id, i, "who", StoryMaker.PLAYER if who == StoryMaker.NPC else StoryMaker.NPC))
	row.add_child(who_button)
	var do := String(a.get("do", "walk"))
	var do_button := _button(Loc.t("hud.story.do.%s" % do), UiKit.ACCENT)
	do_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	do_button.clip_text = true
	do_button.pressed.connect(func() -> void:
		_set_action(id, i, "do", StoryMaker.DO[(StoryMaker.DO.find(do) + 1) % StoryMaker.DO.size()]))
	row.add_child(do_button)
	var what := HBoxContainer.new()
	what.add_theme_constant_override("separation", 4)
	body.add_child(what)
	match do:
		"walk", "run":
			var to := String(a.get("to", "player"))
			var to_button := _button(_to(to), UiKit.ACCENT)
			to_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			to_button.clip_text = true
			to_button.pressed.connect(func() -> void:
				_set_action(id, i, "to", StoryMaker.TO[(StoryMaker.TO.find(to) + 1) % StoryMaker.TO.size()]))
			what.add_child(to_button)
			if to == "left" or to == "right":
				var steps := int(a.get("steps", StoryMaker.NEW_STEPS))
				for by: int in [-1, 1]:
					var b := _button("-" if by < 0 else "+", UiKit.ACCENT)
					b.custom_minimum_size.x = _plate()
					b.pressed.connect(func() -> void: _set_action(id, i, "steps", steps + by))
					what.add_child(b)
					if by < 0:
						var count := _word(Loc.t("hud.story.steps", [steps]), UiKit.TEXT)
						count.custom_minimum_size.x = 72.0
						count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
						what.add_child(count)
		"pose":
			var pose := String(a.get("pose", "idle"))
			var poses := _poses(who)
			var pose_button := _button(Loc.opt("hud.story.pose.%s" % pose, pose.to_upper()), UiKit.ACCENT)
			pose_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pose_button.clip_text = true
			pose_button.pressed.connect(func() -> void:
				_set_action(id, i, "pose", poses[(poses.find(pose) + 1) % poses.size()]))
			what.add_child(pose_button)
		"face":
			var dir := String(a.get("dir", "toward"))
			var dir_button := _button(Loc.t("hud.story.dir.%s" % dir), UiKit.ACCENT)
			dir_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			dir_button.clip_text = true
			dir_button.pressed.connect(func() -> void:
				_set_action(id, i, "dir", StoryMaker.DIRS[(StoryMaker.DIRS.find(dir) + 1) % StoryMaker.DIRS.size()]))
			what.add_child(dir_button)

## Takes action `i` off node `id`, and moves which of those after it are open
## down a place with them.
func _drop_action(id: String, i: int) -> void:
	var n := maker.actions_of(id).size()
	maker.remove_action(id, i)
	_open.erase("%s:action:%d" % [id, i])
	for j in range(i + 1, n):
		if _open.has("%s:action:%d" % [id, j]):
			_open.erase("%s:action:%d" % [id, j])
			_open["%s:action:%d" % [id, j - 1]] = true

## ANSWERS: each answer's words, where it leads, and a cross for that one; and
## a way to give the question another.
func _choices_panel(id: String) -> void:
	var body := _property(id + ":choices", Loc.t("hud.story.property.choices"),
		func() -> void: maker.remove_property(id, "choices"),
		func() -> bool: return maker.choices_of(id).any(func(c) -> bool:
			return String((c as Dictionary).get("text", "")).strip_edges() != ""))
	if body == null:
		return
	var answers := maker.choices_of(id)
	for i in answers.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		body.add_child(row)
		var edit := _edit(String((answers[i] as Dictionary).get("text", "")), Loc.t("hud.story.answer"))
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.text_changed.connect(func(text: String) -> void:
			maker.set_choice_text(id, i, text)
			_sheet.queue_redraw())
		row.add_child(edit)
		_answer_edits.append(edit)
		var to := String((answers[i] as Dictionary).get("next", ""))
		var where := _word("#" + to if to != "" else Loc.t("hud.story.end"), UiKit.DIM)
		where.custom_minimum_size.x = 40.0
		where.clip_text = true
		row.add_child(where)
		var bin := _icon_button(ICON_OUT, func() -> void:
			maker.remove_choice(id, i)
			_fill_inspect()
			_sheet.queue_redraw()
			Audio.play("deny"))
		row.add_child(bin)
	var add_answer := _button(Loc.t("hud.story.add_answer"), UiKit.ACCENT)
	add_answer.pressed.connect(func() -> void:
		var i := maker.add_choice(id)
		_fill_inspect()
		_sheet.queue_redraw()
		if i >= 0 and i < _answer_edits.size():
			(_answer_edits[i] as LineEdit).grab_focus()
		Audio.play("ui"))
	body.add_child(add_answer)

func _set_action(id: String, i: int, key: String, value) -> void:
	if maker.set_action(id, i, key, value):
		_fill_inspect()
		_sheet.queue_redraw()
		Audio.play("ui")

## The poses `who` can be held in: what their sprite has — the player's own
## has one for everything the body does, an atlas character three or fewer.
func _poses(who: String) -> PackedStringArray:
	var art := StoryMaker.PLAYER_SPRITE if who == StoryMaker.PLAYER else Style.npc_art(maker.sprite)
	var frames := Sprites.frames_for(art)
	var out := PackedStringArray()
	for anim in frames.get_animation_names():
		if frames.get_frame_count(anim) == 0:
			continue
		# A hero's strips come one a facing — `idle_down`, `idle_side` — and a
		# pose is the motion, whichever way they face (`ActorView.play`).
		var motion := String(anim).get_slice("_", 0)
		if not out.has(motion):
			out.append(motion)
	if out.is_empty():
		out.append("idle")
	return out

## What who says a line is called: the character's name, or the player's, as
## the story has them — or, with nothing typed yet, which it is.
func _who(speaker: String) -> String:
	var called := maker.npc_name if speaker == StoryMaker.NPC else maker.player_name
	if called.strip_edges() == "":
		called = Loc.t("hud.story.npc" if speaker == StoryMaker.NPC else "hud.story.you")
	return called.to_upper()

## Where a walk goes, in words: toward whoever, or so many cells along.
func _to(to: String) -> String:
	if to == StoryMaker.PLAYER or to == StoryMaker.NPC:
		return Loc.t("hud.story.to_whom", [_who(to)])
	return Loc.t("hud.story.to.%s" % to)

## A button with a small picture on it rather than a word.
func _icon_button(icon: Array, press: Callable) -> Button:
	var b := _button("", UiKit.DIM)
	b.custom_minimum_size.x = _plate()
	b.pressed.connect(press)
	b.draw.connect(func() -> void:
		if b.text == "":
			PixelDraw.new(b).icon_centered((b.size * 0.5).floor(), icon,
				Color.WHITE if b.is_hovered() and not b.disabled else (UiKit.DIM if b.disabled else UiKit.TEXT)))
	return b

func _side_button(column: VBoxContainer, press: Callable) -> Button:
	var b := _button("", UiKit.ACCENT)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.pressed.connect(press)
	column.add_child(b)
	return b

## A word standing beside the buttons, in the middle of the row's height.
func _word(words: String, tone: Color) -> Label:
	var l := UiKit.label(words, UiKit.PIXEL_TEXT, tone, true)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

## A button of the desk's: the kit's pixel one, never taking the keyboard —
## that is the fields' to have — and at the desk's own size in either mode, for
## the map table's reason: too many of them on one screen to stand a full
## thumb each.
func _button(words: String, tone: Color) -> Button:
	var b := UiKit.overlay_button(words, tone, true)
	b.custom_minimum_size = Vector2(0.0, _plate())
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.add_theme_font_size_override("font_size", Loc.text_size(words, UiKit.PIXEL_TEXT))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := b.get_theme_stylebox(state) as StyleBoxFlat
		box.content_margin_left = 10.0
		box.content_margin_right = 10.0
	return b

## Puts `words` on a button, at the size the language writes them.
static func _say_on(b: Button, words: String) -> void:
	b.text = words
	b.add_theme_font_size_override("font_size", Loc.text_size(words, UiKit.PIXEL_TEXT))

## A button that cannot be pressed because it is what is chosen: lit, not
## greyed.
static func _chosen_look(b: Button) -> void:
	var chosen := b.get_theme_stylebox("disabled") as StyleBoxFlat
	chosen.bg_color = Color(UiKit.ACCENT, 0.22)
	chosen.border_color = UiKit.ACCENT
	b.add_theme_color_override("font_disabled_color", Color.WHITE)

## A field to type in, in the pixel look, saying `placeholder` while empty.
func _edit(text: String, placeholder: String) -> LineEdit:
	var e := LineEdit.new()
	e.text = text
	e.placeholder_text = placeholder
	e.custom_minimum_size = Vector2(0.0, _plate())
	e.add_theme_font_override("font", UiKit.PIXEL_FONT)
	e.add_theme_font_size_override("font_size", UiKit.PIXEL_TEXT)
	e.add_theme_color_override("font_color", UiKit.TEXT)
	e.add_theme_color_override("font_placeholder_color", UiKit.DIM)
	e.add_theme_stylebox_override("normal", UiKit.style(UiKit.BG, UiKit.LINE, 1, 0, true))
	e.add_theme_stylebox_override("focus", UiKit.style(Color(0, 0, 0, 0), UiKit.ACCENT, 1, 0, true))
	return e

## How tall a thing to press stands on the desk.
func _plate() -> float:
	return 56.0 if _thumb else 34.0

## A panel of the desk's: the kit's pixel one, keeping the same room inside
## its edge in either mode.
func _panel() -> PanelContainer:
	var p := UiKit.panel(UiKit.PANEL, UiKit.LINE, true)
	var box := p.get_theme_stylebox("panel") as StyleBoxFlat
	box.content_margin_left = PANEL_PAD
	box.content_margin_right = PANEL_PAD
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p

## Puts on the chrome whatever the maker has that it shows.
func _refresh() -> void:
	var map := maker.map_to_play()
	_say_on(_map, map.to_upper() if map != "" else Loc.t("hud.story.no_map"))
	for m in _modes:
		(_modes[m] as Button).disabled = m == maker.mode
	if maker.story_id != _shown_id:
		_shown_id = maker.story_id
		_name.text = maker.story_id
	_sheet.queue_redraw()

## The whole story put on the desk again: after NEW, or a story loaded.
func _took() -> void:
	_player_name.text = maker.player_name
	selected = maker.start
	_armed = ""
	_adding = false
	_open.clear()
	_frame_nodes()
	_refresh()
	_fill_inspect()

## Where everything stands for the screen as it is: the bar across the top,
## the column down the left, the inspector down the right, and the sheet in
## what is left, down to the screen's foot.
func _fit() -> void:
	var bar_h := _bar.get_combined_minimum_size().y
	_bar.position = Vector2.ZERO
	_bar.size = Vector2(size.x, bar_h)
	_side.position = Vector2(0.0, bar_h)
	_side.size = Vector2(SIDE_W, size.y - bar_h)
	_inspect.position = Vector2(size.x - INSPECT_W, bar_h)
	_inspect.size = Vector2(INSPECT_W, size.y - bar_h)
	var room := Rect2(SIDE_W, bar_h, size.x - SIDE_W - INSPECT_W, size.y - bar_h)
	if _sheet.position != room.position or _sheet.size != room.size:
		_sheet.position = room.position
		_sheet.size = room.size
		_sheet.queue_redraw()

func _process(delta: float) -> void:
	UiKit.sync_screen(self)
	if _thumb != UiKit.mobile():
		_build()
	_fit()
	if _said_left > 0.0:
		_said_left = maxf(0.0, _said_left - delta)
		# Gone off the sheet the frame it is over.
		if _said_left == 0.0:
			_sheet.queue_redraw()
	if _armed != "":
		_armed_left -= delta
		if _armed_left <= 0.0:
			_disarm()
	# The move keys carry the sheet — but not while they are typing, nor while
	# one of them is half of a shortcut: SAVE's is a move key too.
	if is_visible_in_tree() and _popup == null and get_viewport().gui_get_focus_owner() == null \
			and not Input.is_key_pressed(KEY_CTRL) and not Input.is_key_pressed(KEY_META):
		var push := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if push != Vector2.ZERO:
			_origin -= push * PAN_SPEED * delta
			_sheet.queue_redraw()
	queue_redraw()

## --- the nodes on the sheet ------------------------------------------------------

func zoom() -> float:
	return float(ZOOMS[_zoom_at])

## Where a point of the sheet is on the desk, at a node's own size, on the
## grid the nodes stand on.
func desk_point(at: Vector2) -> Vector2i:
	return Vector2i((((at - _origin) / zoom()) / GRID).round() * GRID)

## Where node `id` stands on the sheet, and how big it is.
func node_rect(id: String) -> Rect2:
	return Rect2(_origin + Vector2(maker.at_of(id)) * zoom(), Vector2(NODE_W, node_height(id)) * zoom())

## How tall node `id` is, at its own size: its head, and a row for each of
## what it holds — or one, saying it holds nothing.
func node_height(id: String) -> float:
	var rows := _rows_above(id) + maker.choices_of(id).size()
	return NODE_PAD * 2.0 + HEAD_H + ROW_H * float(maxi(rows, 1))

## How many rows node `id` shows above its answers: its words, where it has a
## line — one at least, for the room to write them — and a row for what it
## wears and does, where it wears or does anything.
func _rows_above(id: String) -> int:
	var n := 0
	if maker.has_line(id):
		n += maxi(_text_rows(id).size(), 1)
	if _chips(id) != "":
		n += 1
	return n

## The rows of node `id`'s words, as many as it shows.
func _text_rows(id: String) -> PackedStringArray:
	var text := maker.text_of(id)
	if text.strip_edges() == "":
		return PackedStringArray()
	return PixelDraw.wrap(text, NODE_W - NODE_PAD * 2.0 - PORT, TEXT_ROWS)

## What node `id` wears and does, in a few words: its expression and the
## motion in its letters, where it has been given them, and how much it does.
func _chips(id: String) -> String:
	var bits := PackedStringArray()
	if maker.has_property(id, "emotion"):
		var emotion := maker.emotion_of(id)
		bits.append(Loc.opt("hud.story.emotion.%s" % emotion, emotion.to_upper()))
	if maker.has_property(id, "effect"):
		bits.append(Loc.t("hud.story.effect.%s" % maker.effect_of(id)))
	var n := maker.actions_of(id).size()
	if n > 0:
		bits.append(Loc.t("hud.story.action_count_one" if n == 1 else "hud.story.action_count", [n]))
	return "  ".join(bits)

## The port of node `id` that leads on — its own, with `choice` -1, or its
## answer `choice`'s — on the sheet.
func port_rect(id: String, choice: int = -1) -> Rect2:
	var r := node_rect(id)
	var z := zoom()
	var y := r.position.y + (NODE_PAD + HEAD_H * 0.5) * z
	if choice >= 0:
		y = r.position.y + (NODE_PAD + HEAD_H + ROW_H * (float(_rows_above(id)) + float(choice) + 0.5)) * z
	return Rect2(Vector2(r.end.x - PORT * z * 0.5, y - PORT * z * 0.5), Vector2.ONE * PORT * z)

## The node under `at` on the sheet, or "": the one picked first, since it is
## drawn over the rest, then the latest put in.
func node_at(at: Vector2) -> String:
	if maker.holds(selected) and node_rect(selected).has_point(at):
		return selected
	var all := maker.ids()
	for i in range(all.size() - 1, -1, -1):
		if node_rect(all[i]).has_point(at):
			return all[i]
	return ""

## The port under `at`, within GRAB of it, as {"id", "choice"}, or nothing.
func port_at(at: Vector2) -> Dictionary:
	var reach := GRAB * zoom()
	for id in maker.ids():
		var ports: Array = [-1]
		for i in maker.choices_of(id).size():
			ports.append(i)
		for choice: int in ports:
			if choice == -1 and maker.asks(id):
				continue
			if port_rect(id, choice).grow(reach).has_point(at):
				return {"id": id, "choice": choice}
	return {}

## Brings the sheet to the nodes: the start in its top-left corner with a
## little room, or, with no nodes, the sheet's origin there.
func _frame_nodes() -> void:
	var at := Vector2.ZERO
	if maker.holds(maker.start):
		at = Vector2(maker.at_of(maker.start)) * zoom()
	elif not maker.ids().is_empty():
		at = Vector2(maker.at_of(maker.ids()[0])) * zoom()
	_origin = (Vector2(NODE_PAD * 4.0, NODE_PAD * 4.0) - at).round()

## Brings the nodes nearer or further, about the point `about` of the sheet.
func _zoom_to(level: int, about: Vector2) -> void:
	level = clampi(level, 0, ZOOMS.size() - 1)
	if level == _zoom_at:
		return
	var under := (about - _origin) / zoom()
	_zoom_at = level
	_origin = (about - under * zoom()).round()
	_sheet.queue_redraw()

## --- the pointer on the sheet -------------------------------------------------

func _on_sheet_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed:
			# A field lets go of the keyboard: the keys are the sheet's again.
			get_viewport().gui_release_focus()
			match click.button_index:
				MOUSE_BUTTON_LEFT:
					var port := port_at(click.position)
					var id := node_at(click.position)
					if not port.is_empty():
						_linking = port
						_link_at = click.position
						_pick(String(port["id"]))
					elif id != "":
						_pick(id)
						_dragging = id
						_grip = click.position - node_rect(id).position
					elif click.double_click:
						_pick(maker.add_node(desk_point(click.position)))
						if _text != null:
							_text.grab_focus()
						Audio.play("ui")
					else:
						_begin_pan(click.position)
				MOUSE_BUTTON_RIGHT:
					var id := node_at(click.position)
					if id != "":
						_pick(id)
				MOUSE_BUTTON_MIDDLE:
					_begin_pan(click.position)
				MOUSE_BUTTON_WHEEL_UP:
					_zoom_to(_zoom_at - 1, click.position)
				MOUSE_BUTTON_WHEEL_DOWN:
					_zoom_to(_zoom_at + 1, click.position)
		elif click.button_index == MOUSE_BUTTON_LEFT:
			if not _linking.is_empty():
				_end_link(click.position)
			_dragging = ""
			_panning = false
		elif click.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = false
		_sheet.queue_redraw()
		_sheet.accept_event()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if not _linking.is_empty():
			_link_at = motion.position
			_sheet.queue_redraw()
		elif _dragging != "":
			maker.move_node(_dragging, desk_point(motion.position - _grip))
			_sheet.queue_redraw()
		elif _panning:
			# By how far the pointer has got, not by what the event says it moved:
			# a thumb's drag, handed over as a mouse's, says nothing of that.
			_origin += motion.position - _pan_at
			_pan_at = motion.position
			_sheet.queue_redraw()
	elif event is InputEventPanGesture:
		# Two fingers on a trackpad move the sheet, as they move any page.
		_origin -= (event as InputEventPanGesture).delta * 12.0
		_sheet.queue_redraw()
		_sheet.accept_event()
	elif event is InputEventMagnifyGesture:
		var pinch := event as InputEventMagnifyGesture
		if absf(pinch.factor - 1.0) > 0.02:
			_zoom_to(_zoom_at - 1 if pinch.factor > 1.0 else _zoom_at + 1, pinch.position)
		_sheet.accept_event()

func _begin_pan(at: Vector2) -> void:
	_panning = true
	_pan_at = at

## Picks node `id`: its inspector comes up. "" picks nothing.
func _pick(id: String) -> void:
	if id == selected:
		return
	selected = id
	_armed = ""
	_adding = false
	_fill_inspect()
	_sheet.queue_redraw()

## A link let go: onto a node, it leads there; onto nothing, nowhere. Not
## onto the node it comes from.
func _end_link(at: Vector2) -> void:
	var from := String(_linking["id"])
	var choice := int(_linking["choice"])
	_linking = {}
	var to := node_at(at)
	if to == from:
		return
	var changed := maker.link_choice(from, choice, to) if choice >= 0 else maker.link(from, to)
	if changed:
		_fill_inspect()
		Audio.play("ui")

## --- the sheet, drawn ---------------------------------------------------------------

## The ground, the links, and the nodes over them — the one picked last, so
## it stands over the rest.
func _paint_sheet(cv: CanvasItem) -> void:
	var z := zoom()
	cv.draw_rect(Rect2(Vector2.ZERO, _sheet.size), UiKit.BG)
	# A dot every few cells of the grid, so the sheet is seen to move.
	var step := GRID * 4.0 * z
	var first := Vector2(fposmod(_origin.x, step), fposmod(_origin.y, step))
	var x := first.x
	while x < _sheet.size.x:
		var y := first.y
		while y < _sheet.size.y:
			cv.draw_rect(Rect2(x, y, UiKit.PIXEL, UiKit.PIXEL), DOTS)
			y += step
		x += step
	for id in maker.ids():
		if maker.asks(id):
			for i in maker.choices_of(id).size():
				var to := String((maker.choices_of(id)[i] as Dictionary).get("next", ""))
				if to != "":
					_paint_link(cv, port_rect(id, i).get_center(), node_rect(to), id == selected or to == selected)
		elif maker.next_of(id) != "":
			_paint_link(cv, port_rect(id).get_center(), node_rect(maker.next_of(id)), id == selected or maker.next_of(id) == selected)
	if not _linking.is_empty():
		var from := port_rect(String(_linking["id"]), int(_linking["choice"])).get_center()
		cv.draw_line(from, _link_at, UiKit.ACCENT, UiKit.PIXEL)
	for id in maker.ids():
		if id != selected:
			_paint_node(cv, id)
	if maker.holds(selected):
		_paint_node(cv, selected)
	_paint_said(cv)

## What the desk last said, on a plate over the sheet's foot, while it says
## it: and nothing there the rest of the time.
func _paint_said(cv: CanvasItem) -> void:
	if _said_left <= 0.0 or _said == "":
		return
	var px := PixelDraw.new(cv)
	var wide := minf(PixelDraw.text_width(_said) + 24.0, _sheet.size.x - 16.0)
	var plate := Rect2(floorf((_sheet.size.x - wide) * 0.5), _sheet.size.y - 36.0, wide, 28.0)
	px.rect(plate, UiKit.PANEL)
	px.frame(plate, Color(_said_tone.r, _said_tone.g, _said_tone.b, 0.6))
	px.text(plate.position + Vector2(12.0, 20.0), _said, _said_tone, plate.size.x - 24.0)

## A link from a port out to the left edge of the node it leads to: straight
## out of the port, across, and in, with a head at the end.
func _paint_link(cv: CanvasItem, from: Vector2, to_rect: Rect2, lit: bool) -> void:
	var z := zoom()
	var to := Vector2(to_rect.position.x, to_rect.position.y + (NODE_PAD + HEAD_H * 0.5) * z)
	var col := UiKit.ACCENT if lit else UiKit.LINE
	var run := LINK_RUN * z
	var pts := PackedVector2Array([from, from + Vector2(run, 0.0), Vector2(to.x - run, to.y), to])
	if to.x - run < from.x + run:
		# Leading back to a node on its left: round under the both of them.
		var under := maxf(from.y, to.y) + (NODE_W * 0.5) * z
		pts = PackedVector2Array([from, from + Vector2(run, 0.0), Vector2(from.x + run, under),
			Vector2(to.x - run, under), Vector2(to.x - run, to.y), to])
	cv.draw_polyline(pts, col, UiKit.PIXEL)
	cv.draw_colored_polygon(PackedVector2Array([to, to + Vector2(-6.0, -4.0) * z, to + Vector2(-6.0, 4.0) * z]), col)

## One node: its box, its head — a diamond where the story starts, who says
## its line where it has one, and its number — then what it holds: its words,
## what it wears and does, its answers, or a word saying it holds nothing;
## and the ports that lead on.
func _paint_node(cv: CanvasItem, id: String) -> void:
	var z := zoom()
	var r := node_rect(id)
	var px := PixelDraw.new(cv)
	var font := int(UiKit.PIXEL_TEXT * z)
	# A row is drawn from its top, and a line of text from its baseline.
	var lift := Vector2(0.0, roundf(PixelDraw.FONT.get_ascent(font)))
	var picked := id == selected
	px.rect(r, UiKit.PANEL)
	px.frame(r, UiKit.ACCENT if picked else UiKit.LINE)
	var pen := r.position + Vector2(NODE_PAD, NODE_PAD) * z
	var wide := (NODE_W - NODE_PAD * 2.0 - PORT) * z
	# The head: the start's diamond, who says its line where it has one, and the number.
	var head := Vector2(pen.x, pen.y + (HEAD_H - ROW_H) * 0.5 * z)
	var name_x := pen.x
	if maker.start == id:
		px.diamond(Vector2(pen.x + 6.0 * z, head.y + ROW_H * 0.5 * z), maxi(int(3.0 * z), 1), UiKit.GOOD)
		name_x += 20.0 * z
	var number := "#" + id
	var number_x := pen.x + wide - PixelDraw.text_width(number, font)
	if maker.has_line(id):
		px.text(Vector2(name_x, head.y) + lift, _who(maker.speaker_of(id)),
			UiKit.ACCENT if maker.speaker_of(id) == StoryMaker.NPC else UiKit.GOOD, number_x - 8.0 * z - name_x, font)
	px.text(Vector2(number_x, head.y) + lift, number, UiKit.DIM, -1.0, font)
	pen.y += HEAD_H * z
	# The words, or the room for them, where it has a line.
	if maker.has_line(id):
		var rows := _text_rows(id)
		if rows.is_empty():
			px.text(pen + lift, Loc.t("hud.story.line"), UiKit.DIM, wide, font)
			pen.y += ROW_H * z
		for row in rows:
			px.text(pen + lift, row, UiKit.TEXT, wide, font)
			pen.y += ROW_H * z
	var chips := _chips(id)
	if chips != "":
		px.text(pen + lift, chips, UiKit.WARN, wide, font)
		pen.y += ROW_H * z
	if _rows_above(id) == 0 and not maker.has_property(id, "choices"):
		px.text(pen + lift, Loc.t("hud.story.empty"), UiKit.DIM, wide, font)
	# The answers, a port each.
	var answers := maker.choices_of(id)
	for i in answers.size():
		var text := String((answers[i] as Dictionary).get("text", ""))
		px.text(pen + lift, "> " + (text if text != "" else Loc.t("hud.story.answer")), UiKit.TEXT if text != "" else UiKit.DIM, wide, font)
		_paint_port(cv, port_rect(id, i), String((answers[i] as Dictionary).get("next", "")) != "")
		pen.y += ROW_H * z
	if not maker.asks(id):
		_paint_port(cv, port_rect(id), maker.next_of(id) != "")

## A port: filled where it leads somewhere, a ring where it leads nowhere.
func _paint_port(cv: CanvasItem, r: Rect2, linked: bool) -> void:
	var px := PixelDraw.new(cv)
	px.rect(r, UiKit.ACCENT if linked else UiKit.PANEL)
	px.frame(r, UiKit.ACCENT)

## --- the keys ---------------------------------------------------------------

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _popup != null or not event.is_pressed() or event.is_echo():
		return
	var key := event as InputEventKey
	if key == null:
		return
	if key.is_command_or_control_pressed() and key.keycode == KEY_S:
		_save()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_DELETE and maker.holds(selected):
		_remove(selected)
		get_viewport().set_input_as_handled()

## The cancel key puts away what is up over the desk, before it would pause
## the desk behind it — and lets go of a link being dragged.
func _unhandled_input(event: InputEvent) -> void:
	if _popup != null and is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		_close_popup()
		get_viewport().set_input_as_handled()
	elif not _linking.is_empty() and event.is_action_pressed("ui_cancel"):
		_linking = {}
		_sheet.queue_redraw()
		get_viewport().set_input_as_handled()
	elif _adding and is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		# The list + PROPERTY opened goes before the desk would pause.
		_adding = false
		_fill_inspect()
		get_viewport().set_input_as_handled()

## --- what the bar does --------------------------------------------------------

## Says a line over the sheet's foot for a while.
func _tell(line: String, tone: Color = UiKit.TEXT) -> void:
	_said = line
	_said_tone = tone
	_said_left = SAY_TIME
	_sheet.queue_redraw()

func _arm(what: String) -> void:
	_armed = what
	_armed_left = ARM_TIME

func _disarm() -> void:
	var was := _armed
	_armed = ""
	if _popup != null and was.begins_with("delete:"):
		_fill_list()
	elif was.begins_with("remove:") or was.begins_with("drop:"):
		_fill_inspect()

## The return key on a line's words: the next node, with a line said by
## whoever's turn it is, put in after it and led to, picked, and the keyboard
## on its words — so a conversation is written straight on, a return a line.
## Its line comes up open, as one added with + PROPERTY does, to be typed in.
func _next_line() -> void:
	var id := maker.add_node_after(selected, true)
	_open[id + ":line"] = true
	_pick(id)
	_show(id)
	if _text != null:
		_text.grab_focus()
	Audio.play("ui")

## + NODE: a node with nothing in it, put in after the one picked, along from
## it and led on to, and picked in its turn. With nothing picked it goes in
## the middle of the sheet; the first of all where a story starts on the desk.
func _add_node() -> void:
	var id: String
	if maker.holds(selected):
		id = maker.add_node_after(selected)
	elif maker.node_count() == 0:
		id = maker.add_node(StoryMaker.FIRST_AT)
	else:
		id = maker.add_node(desk_point(_sheet.size * 0.5))
	_pick(id)
	_show(id)
	if _text != null:
		_text.grab_focus()
	Audio.play("ui")

## Brings node `id` into sight, port and all, by moving the sheet no further
## than it has to.
func _show(id: String) -> void:
	if not maker.holds(id):
		return
	var r := node_rect(id).grow(PORT * zoom() + NODE_PAD)
	var shift := Vector2.ZERO
	if r.end.x > _sheet.size.x:
		shift.x = _sheet.size.x - r.end.x
	if r.position.x + shift.x < 0.0:
		shift.x = -r.position.x
	if r.end.y > _sheet.size.y:
		shift.y = _sheet.size.y - r.end.y
	if r.position.y + shift.y < 0.0:
		shift.y = -r.position.y
	if shift != Vector2.ZERO:
		_origin += shift.round()
		_sheet.queue_redraw()

## Taking a node off the desk cannot be undone, so the first press only asks.
func _remove(id: String) -> void:
	if _armed != "remove:" + id:
		_arm("remove:" + id)
		_tell(Loc.t("hud.story.remove_asks", [id]), UiKit.WARN)
		_fill_inspect()
		Audio.play("ui")
		return
	_armed = ""
	maker.remove_node(id)
	if selected == id:
		selected = maker.start
	_fill_inspect()
	_sheet.queue_redraw()
	Audio.play("deny")

func _set_mode(m: int) -> void:
	maker.set_mode(m)
	_refresh()
	Audio.play("ui")

## SAVE: the story is kept under the name in the field. Under the name of
## another story that is kept already, the first press only asks.
func _save() -> void:
	var id := Stories.id_for(_name.text)
	if id != "" and id != maker.story_id and Stories.exists(id) and _armed != "save:" + id:
		_arm("save:" + id)
		_tell(Loc.t("hud.story.replace", [id.to_upper()]), UiKit.WARN)
		Audio.play("ui")
		return
	_armed = ""
	var refused := maker.save_as(_name.text)
	if refused != "":
		_tell(Loc.t("hud.story.refused.%s" % refused), UiKit.BAD)
		Audio.play("deny")
		return
	_tell(Loc.t("hud.story.saved", [Stories.path_of(id)]), UiKit.GOOD)
	Audio.play("ui")
	_refresh()

func _new() -> void:
	maker.new_story()
	_took()
	Audio.play("ui")

## PLAY: the story set going on its map. One with nothing to say, or no map to
## say it on, stays on the desk, and the foot says why.
func _play() -> void:
	get_viewport().gui_release_focus()
	var refused := maker.play()
	if refused != "":
		_tell(Loc.t("hud.story.refused.%s" % refused), UiKit.BAD)
		Audio.play("deny")

## --- what is put up over the desk --------------------------------------------

func _open_popup() -> bool:
	if _popup != null:
		return false
	get_viewport().gui_release_focus()
	_popup = Control.new()
	_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_popup)
	Audio.play("ui")
	return true

func _close_popup() -> void:
	if _popup == null:
		return
	remove_child(_popup)
	_popup.queue_free()
	_popup = null
	_armed = ""
	Audio.play("ui")

## A frame over a shade, under `heading`, with the way back pinned at its foot.
func _frame(heading: String) -> UiKit.ScreenFrame:
	for old in _popup.get_children():
		_popup.remove_child(old)
		old.queue_free()
	_popup.add_child(UiKit.shade())
	var frame := UiKit.screen_frame(560.0, 56.0, 28.0, true)
	_popup.add_child(frame)
	frame.head.add_child(UiKit.title(heading, UiKit.text(24), true))
	frame.head.add_child(UiKit.hline(true))
	frame.foot.add_child(UiKit.spacer(8))
	var back := UiKit.overlay_button(Loc.t("hud.story.back"), UiKit.ACCENT, true)
	back.pressed.connect(_close_popup)
	frame.foot.add_child(back)
	return frame

## LOAD: every story that is kept, each a button that puts it on the desk,
## with a way to throw it away beside it that asks twice.
func _open_list() -> void:
	if _open_popup():
		_fill_list()

func _fill_list() -> void:
	var frame := _frame(Loc.t("hud.story.load_heading"))
	var ids := Stories.ids()
	if ids.is_empty():
		frame.rows.add_child(UiKit.label(Loc.t("hud.story.none"), UiKit.text(16), UiKit.DIM, true))
	for id in ids:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		frame.rows.add_child(row)
		var pick := UiKit.overlay_button(id.to_upper(), UiKit.ACCENT, true)
		pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.pressed.connect(func() -> void: _load(id))
		row.add_child(pick)
		var armed := _armed == "delete:" + id
		var bin := UiKit.overlay_button(Loc.t("hud.story.sure" if armed else "hud.story.delete"),
			UiKit.BAD if armed else UiKit.DIM, true)
		bin.pressed.connect(func() -> void: _delete(id))
		row.add_child(bin)

func _load(id: String) -> void:
	if not maker.open(id):
		_tell(Loc.t("hud.story.refused.read"), UiKit.BAD)
		Audio.play("deny")
		return
	_close_popup()
	_took()
	_tell(Loc.t("hud.story.loaded", [id.to_upper()]), UiKit.GOOD)

## Throwing a story away cannot be undone, so the first press only asks.
func _delete(id: String) -> void:
	if _armed != "delete:" + id:
		_arm("delete:" + id)
		_fill_list()
		Audio.play("ui")
		return
	_armed = ""
	Stories.remove(id)
	_fill_list()
	_tell(Loc.t("hud.story.deleted", [id.to_upper()]), UiKit.WARN)
	Audio.play("deny")

## MAP: every map the map creator has kept, each a button that sets the story
## on it.
func _open_maps() -> void:
	if _open_popup():
		_fill_maps()

func _fill_maps() -> void:
	var frame := _frame(Loc.t("hud.story.map_heading"))
	var ids := Maps.ids()
	if ids.is_empty():
		frame.rows.add_child(UiKit.label(Loc.t("hud.story.no_maps"), UiKit.text(16), UiKit.DIM, true))
	for id in ids:
		var pick := UiKit.overlay_button(id.to_upper(), UiKit.ACCENT, true)
		pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if id == maker.map_to_play():
			UiKit.mark_chosen(pick)
		pick.pressed.connect(func() -> void: _import(id))
		frame.rows.add_child(pick)

func _import(id: String) -> void:
	maker.set_map(id)
	_close_popup()
	_refresh()

## --- the desk itself -----------------------------------------------------------

## The ground under everything.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiKit.BG)
