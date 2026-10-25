class_name CutsceneBox
extends Control

## The narration under a directed scene: what is being said now, typed a letter
## at a time, with the name of whoever is saying it when anyone is, and under a
## question its answers, the one picked marked. It reads the `Cutscene` every
## frame and never writes to it. The letters move as the beat's emotion or its
## own effect asks (`Style.letter_motion`).
##
## Deliberately its own panel rather than the `DialogueBox`: a conversation is
## framed around two portraits facing each other, and a prologue is a voice over
## a room. It sits at the bottom so the stage above it is never covered.
##
## In mobile mode (`UiKit.mobile`) it is the conversation's box's size: most of
## the width of the screen, its words twice as big, for the same glass.

const LAYER := 32

const SIDE_CLEAR := 140.0
const MAX_WIDTH := 760.0
const MIN_WIDTH := 420.0
const BOTTOM := 74.0
const PAD := 18.0
## Silkscreen, like the rest of the game's own text, at the one size that every
## face the game carries divides: twice Silkscreen's native 8px, and once
## 둥근모꼴's 16px. A face has exactly one correct shape per pixel, so a size
## either of them did not draw comes back with some strokes a pixel wider than
## others — see `Loc.pixel_size`, and `tests/shared/loc_test`, which checks
## these three against every language.
const TEXT_SIZE := UiKit.PIXEL_TEXT
const NAME_SIZE := UiKit.PIXEL_TEXT
const HINT_SIZE := UiKit.PIXEL_TEXT
## Baseline to baseline, on the PIXEL grid. The face's own height is 20.48px at
## this size, and a row placed on a fraction of a pixel is a row drawn between
## two of them. `PixelDraw.LINE` is the same spacing the assembly screen uses.
const LINE_H := PixelDraw.LINE
const TAB_HEIGHT := 24.0
const ROWS_SHOWN := 3       ## the panel is this tall whatever the line, so it never jumps
const OPEN_TIME := 0.18
const MARK_INSET := Vector2(16.0, 16.0)
## How far an answer sits in from the line, to leave room for the marker, and
## the space between the line and the first answer, and after the last.
const CHOICE_INDENT := 22.0
const CHOICE_GAP := 8.0
## Mobile mode's panel: as wide as THUMB_WIDTH where the screen has it, clear of
## its edges by THUMB_SIDE, and nearer the bottom, the hint under it being one
## short line.
const THUMB_WIDTH := 1100.0
const THUMB_SIDE := 40.0
const THUMB_BOTTOM := 52.0

var cut: Cutscene
var _font: Font
var _open: float = 0.0
var _t: float = 0.0

func _ready() -> void:
	UiKit.fill_screen(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_font = UiKit.PIXEL_FONT

func _process(delta: float) -> void:
	UiKit.sync_screen(self)
	_t += delta
	# Open while there is a line to read, and gone the moment there is not: a
	# beat that only walks somebody across the room shows no panel at all.
	var showing := cut != null and is_instance_valid(cut) and not cut.done and cut.line() != ""
	_open = minf(_open + delta / OPEN_TIME, 1.0) if showing else 0.0
	queue_redraw()

## Whether the panel is laid out for a thumb: mobile mode.
func thumb() -> bool:
	return UiKit.mobile()

## The sizes the panel is written at: a desk's, or twice that for a thumb.
func _text_size() -> int:
	return TEXT_SIZE * 2 if thumb() else TEXT_SIZE

func _name_size() -> int:
	return NAME_SIZE * 2 if thumb() else NAME_SIZE

func _line_h() -> float:
	return LINE_H * 2.0 if thumb() else LINE_H

func _tab_h() -> float:
	return TAB_HEIGHT * 2.0 - 4.0 if thumb() else TAB_HEIGHT

## Where the panel stands: `ROWS_SHOWN` rows of the size it is written at —
## and under a question, its answers and the hint for picking one.
func box_rect() -> Rect2:
	var w := clampf(size.x - SIDE_CLEAR * 2.0, MIN_WIDTH, MAX_WIDTH)
	if thumb():
		w = clampf(size.x - THUMB_SIDE * 2.0, MIN_WIDTH, THUMB_WIDTH)
	var rows := _line_h() * float(ROWS_SHOWN)
	var answers := _answers(w)
	if not answers.is_empty():
		rows += CHOICE_GAP * 2.0 + _line_h()
		for opt in answers:
			rows += _line_h() * (opt as PackedStringArray).size()
	var h := PAD * 2.0 + rows
	return Rect2(Vector2((size.x - w) * 0.5, size.y - (THUMB_BOTTOM if thumb() else BOTTOM) - h),
		Vector2(w, h))

## The answers the beat offers, each wrapped to fit beside the marker; none
## for a beat that asks nothing.
func _answers(w: float) -> Array:
	var out: Array = []
	if cut == null or not is_instance_valid(cut):
		return out
	for c in cut.choices():
		if c is Dictionary:
			out.append(_wrap(String((c as Dictionary).get("text", "")), w - PAD * 2.0 - CHOICE_INDENT, _text_size()))
	return out

func _draw() -> void:
	if _open <= 0.0:
		return
	var box := box_rect()
	var w := box.size.x
	var text_w := w - PAD * 2.0
	var line_h := _line_h()
	# Rises the last few pixels as it opens, which reads as the scene handing
	# the line over rather than the panel being switched on.
	box.position.y += (1.0 - _open) * 8.0

	var fill := Color(UiKit.PANEL.r, UiKit.PANEL.g, UiKit.PANEL.b, 0.93 * _open)
	draw_rect(box, fill)
	draw_rect(box, Color(UiKit.LINE.r, UiKit.LINE.g, UiKit.LINE.b, _open), false, 2.0)

	var speaker := cut.speaker_name()
	if speaker != "":
		_draw_name_tab(box, speaker)

	# Wrapped from the whole line rather than the part typed so far, so a word
	# never jumps down a row halfway through arriving.
	var rows := _wrap(cut.line(), text_w, _text_size())
	var pen := box.position + Vector2(PAD, PAD)
	var ink := Color(UiKit.TEXT.r, UiKit.TEXT.g, UiKit.TEXT.b, _open)
	_draw_letters(pen, rows, line_h, ink)
	pen.y += line_h * rows.size()

	if cut.is_choosing():
		# The answers under the line, the one picked marked, and how to pick.
		var answers := _answers(w)
		pen.y += CHOICE_GAP
		for i in answers.size():
			var opt: PackedStringArray = answers[i]
			var chosen := i == cut.selected
			if chosen:
				var mid := pen.y + line_h * 0.5
				var nudge := roundf(absf(sin(_t * 6.0)) * 3.0)
				draw_colored_polygon(PackedVector2Array([
					Vector2(pen.x + 2.0 + nudge, mid - 6.0), Vector2(pen.x + 11.0 + nudge, mid),
					Vector2(pen.x + 2.0 + nudge, mid + 6.0),
				]), Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, _open))
			for row in opt:
				_text(pen + Vector2(CHOICE_INDENT, 0), row, _text_size(),
					ink if chosen else Color(UiKit.DIM.r, UiKit.DIM.g, UiKit.DIM.b, _open))
				pen.y += line_h
		pen.y += CHOICE_GAP
		_text(pen, _choice_hint(), HINT_SIZE, Color(UiKit.DIM.r, UiKit.DIM.g, UiKit.DIM.b, 0.8 * _open))
	elif cut.waiting_for_press() and cut.line_finished():
		_draw_mark(box)
	_draw_hint(box)

## The line so far, a letter at a time, each moved as the beat's emotion or
## its own effect asks.
func _draw_letters(pen: Vector2, rows: PackedStringArray, line_h: float, ink: Color) -> void:
	var motion := Style.letter_motion(cut.beat())
	var shown := int(cut.revealed)
	var ascent := roundf(_font.get_ascent(_text_size()))
	var i := 0
	for row in rows:
		var x := pen.x
		for k in row.length():
			if i >= shown:
				return
			x += _font.draw_char(get_canvas_item(), (Vector2(x, pen.y + ascent)).round() + Style.letter_offset(motion, i, _t),
				row.unicode_at(k), _text_size(), ink)
			i += 1
		i += 1   # the space the wrap swallowed
		pen.y += line_h

## How to answer, in whatever the player has the keys bound to — the words
## the conversation's box uses, since it is the same question.
func _choice_hint() -> String:
	if thumb() or Controls.on_glass():
		return Loc.t("hud.dialogue.choose_touch")
	return Loc.t("hud.dialogue.choose", [Controls.short_label_for("move_up"),
		Controls.short_label_for("move_down"), Controls.short_label_for("interact")])

## The speaker's name on a tab over the top-left corner. Narration has no
## speaker and so gets no tab — which is how the two read apart.
func _draw_name_tab(box: Rect2, speaker: String) -> void:
	var w := _width(speaker, _name_size()) + PAD * 1.6
	var tab := Rect2(box.position + Vector2(PAD, -_tab_h()), Vector2(w, _tab_h()))
	draw_rect(tab, Color(UiKit.PANEL.r, UiKit.PANEL.g, UiKit.PANEL.b, 0.97 * _open))
	draw_rect(tab, Color(UiKit.LINE.r, UiKit.LINE.g, UiKit.LINE.b, _open), false, 2.0)
	var c := Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, _open)
	_text(tab.position + Vector2(PAD * 0.8, (_tab_h() - _line_h()) * 0.5), speaker, _name_size(), c)

## The blinking wedge that says the line is read and a press moves it on.
func _draw_mark(box: Rect2) -> void:
	var a := 0.35 + 0.65 * (0.5 + 0.5 * sin(_t * 6.0))
	var at := box.end - MARK_INSET
	var c := Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, a * _open)
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(-7, -5), at + Vector2(3, -5), at + Vector2(-2, 3)]), c)

func _draw_hint(box: Rect2) -> void:
	# `interact` rather than `ui_accept`: a scene answers either — see
	# `Cutscene._unhandled_input` — and `interact` is the one every other prompt
	# in the game names and the one the rebinding screen can move. On the glass
	# it is a tap anywhere on the screen, and that is what is said instead.
	var hint := Loc.t("hud.cutscene.hint_touch")
	if not Controls.on_glass():
		hint = Loc.t("hud.cutscene.hint", [
			Controls.short_label_for("interact"), Controls.short_label_for("ui_cancel")])
	var c := Color(UiKit.DIM.r, UiKit.DIM.g, UiKit.DIM.b, 0.8 * _open)
	_text(Vector2(box.position.x, box.end.y + 7.0), hint, HINT_SIZE, c)

## --- text -------------------------------------------------------------------

func _text(pos: Vector2, text: String, font_size: int, color: Color) -> void:
	# Rounded onto whole pixels: the face's ascent is 16.48px, and a baseline
	# half a pixel down draws the whole row between two rows of them.
	draw_string(_font, (pos + Vector2(0, _font.get_ascent(font_size))).round(), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _width(text: String, font_size: int) -> float:
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

## Greedy word wrap into rows no wider than `width`. A word wider than the box
## gets a row of its own rather than being split.
func _wrap(text: String, width: float, font_size: int) -> PackedStringArray:
	var rows := PackedStringArray()
	var row := ""
	for word in text.split(" ", false):
		var trial := word if row == "" else row + " " + word
		if row != "" and _width(trial, font_size) > width:
			rows.append(row)
			row = word
		else:
			row = trial
	if row != "":
		rows.append(row)
	return rows
