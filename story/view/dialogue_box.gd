class_name DialogueBox
extends Control

## A conversation, in the manner of Celeste: a dark box across the top of the
## screen with the speaker's portrait framed at one end, their name on a tab,
## and the line typing in a letter at a time, each letter rising into place as it
## arrives. When the line is a question the answers are listed under it.
##
## How a line looks comes from its row in the database: `speaker` puts the portrait on
## the left (the NPC) or the right (the player), `sprite` swaps its art, and
## `emotion` tints, trembles or hops the portrait, gives it a mark, and trembles
## or ripples the letters (see `Style.EMOTIONS`) — unless the line names an
## `effect` of its own for them (`Style.TEXT_EFFECTS`).
##
## Screen space, at the screen's resolution: this is reading text, and the pixel
## camera would blur it. The portrait is the one piece of pixel art in it, blown
## up by a whole multiple so every art pixel stays square.
##
## **In mobile mode it is laid out for a thumb** (`UiKit.mobile`). The box runs
## most of the width of the screen and its words are written twice the size —
## at a desk's size a line stands under a millimetre of a phone's glass. And the
## answers are not lines in it: each is a plate under the box, as wide as the
## box and PLATE tall, there once the question is out. A plate is tapped to give
## its answer: it lights as a thumb comes down on it, and gives the answer as
## the thumb lifts off it — one that slides off first gives nothing. Under the
## plates, and beside the arrow on a line with none, the box says so in words.
##
## While the answers are up the whole glass is the box's, taken in `_input`
## ahead of the console, which is earlier in the tree. Anywhere else a tap is
## the console's page, which is interact — and with a question open, interact
## gives whichever answer is lit. So with the answers up, a tap anywhere but on
## a plate gives nothing.

## Over the pixel picture and its prompts, under the screens (5) and the HUD (10).
const LAYER := 4
const TOP := 44.0
## Kept out of the top corners, where the bench panel and the raid's bag sit.
const SIDE_CLEAR := 350.0
const MAX_WIDTH := 600.0
const MIN_WIDTH := 420.0
const PAD := 14.0
const PORTRAIT := 112.0
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
## How far an answer sits in from the line, to leave room for the marker.
const CHOICE_INDENT := 22.0
## Space between the line and the first answer, and after the last.
const CHOICE_GAP := 8.0
## Seconds the box takes to open out from its middle.
const OPEN_TIME := 0.14
## A letter rises this far into place, over this long.
const POP_RISE := 5.0
const POP_TIME := 0.12
## Where an emotion's mark sits, in from the portrait's top outer corner.
const MARK_INSET := Vector2(18.0, 20.0)

## --- for a thumb --------------------------------------------------------------
## Mobile mode's box: clear of the screen's edges by THUMB_SIDE, as wide as
## THUMB_WIDTH where the screen has it, and hung low enough for the name's tab,
## which stands twice as tall. The HUD and the console's keys are both off the
## screen while somebody talks, so there are no corners to keep out of.
const THUMB_TOP := 52.0
const THUMB_SIDE := 40.0
const THUMB_WIDTH := 1100.0
const THUMB_PORTRAIT := 120.0
const THUMB_PAD := 16.0
## The least an answer's plate stands, the room between two, and from a plate's
## edge to its words — past the marker's room, on the left.
const PLATE := 64.0
const PLATE_GAP := 8.0
const PLATE_PAD := 20.0
const PLATE_MARK := 36.0
## The mouse, as a finger: mobile mode on a desk has one pointer and no index.
const MOUSE := -1

var npc: Npc
var _font: Font
var _open: float = 0.0
var _t: float = 0.0
## The line the arrival times below belong to.
var _node: String = ""
## When each letter of the line came out, by `_t`.
var _arrived := PackedFloat32Array()
## Mobile mode's plates as they stand this frame, one rect an answer, for the
## thumb to be tested against: empty unless a question is out.
var _plates: Array[Rect2] = []
## The thumb on a plate: which finger, and which answer. Empty with none.
var _press: Dictionary = {}
## Fingers that came down while the answers were up, until they lift, wherever
## they wander: left to the console, one would be a tap on the page.
var _mine: Dictionary = {}

func _ready() -> void:
	UiKit.fill_screen(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_font = UiKit.PIXEL_FONT

func _process(delta: float) -> void:
	UiKit.sync_screen(self)
	_t += delta
	var talking := npc != null and is_instance_valid(npc) and npc.is_talking()
	# Opens with a snap and is simply gone when the talking stops: there is no
	# line left to show while it closed.
	_open = minf(_open + delta / OPEN_TIME, 1.0) if talking else 0.0
	_track_arrivals(talking)
	_keep_plates(talking)
	queue_redraw()

## --- for a thumb: the plates ----------------------------------------------------

## Whether the box is laid out for a thumb: mobile mode.
func thumb() -> bool:
	return UiKit.mobile()

## The sizes the box is written at: a desk's, or twice that for a thumb.
func _text_size() -> int:
	return TEXT_SIZE * 2 if thumb() else TEXT_SIZE

func _name_size() -> int:
	return NAME_SIZE * 2 if thumb() else NAME_SIZE

func _line_h() -> float:
	return LINE_H * 2.0 if thumb() else LINE_H

func _tab_h() -> float:
	return TAB_HEIGHT * 2.0 - 4.0 if thumb() else TAB_HEIGHT

func _pad() -> float:
	return THUMB_PAD if thumb() else PAD

## Where mobile mode's box and its plates stand, worked out from the line and
## its answers: `box`, `portrait`, the line's `rows`, and `plates` — one
## `{rect, rows}` an answer, under the box. The box is as tall as its line and
## no taller: the plates are things of their own under it, so it does not grow
## when they come.
func _thumb_layout() -> Dictionary:
	var w := clampf(size.x - THUMB_SIDE * 2.0, MIN_WIDTH, THUMB_WIDTH)
	var text_w := w - THUMB_PORTRAIT - THUMB_PAD * 3.0
	var rows := _wrap(npc.current_line(), text_w, _text_size())
	var h := maxf(THUMB_PORTRAIT, _line_h() * rows.size()) + THUMB_PAD * 2.0
	var box := Rect2(roundf((size.x - w) * 0.5), THUMB_TOP, w, h)
	var on_right := npc.speaker() == "player"
	var portrait := Rect2(
		Vector2(box.end.x - THUMB_PAD - THUMB_PORTRAIT if on_right else box.position.x + THUMB_PAD,
			box.position.y + THUMB_PAD),
		Vector2(THUMB_PORTRAIT, THUMB_PORTRAIT))
	var plates: Array = []
	var y := box.end.y + PLATE_GAP
	for c in npc.choices():
		var words := _wrap(String(c.get("text", "")), w - PLATE_MARK - PLATE_PAD * 2.0, _text_size())
		var tall := maxf(PLATE, _line_h() * words.size() + PLATE - _line_h())
		plates.append({"rect": Rect2(box.position.x, y, w, tall), "rows": words})
		y += tall + PLATE_GAP
	return {"box": box, "portrait": portrait, "rows": rows, "plates": plates,
		"on_right": on_right, "foot": y}

## The plates a thumb can land on this frame. A thumb on one whose question has
## gone from under it is on nothing.
func _keep_plates(talking: bool) -> void:
	_plates.clear()
	if talking and thumb() and _open >= 1.0 and npc.is_choosing():
		for plate in _thumb_layout()["plates"]:
			_plates.append(plate["rect"])
	if not _press.is_empty() and int(_press["index"]) >= _plates.size():
		_press = {}

## The game stopping, or starting again, under a thumb: a lift while it was
## stopped is one nobody saw.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_UNPAUSED:
		_press = {}
		_mine.clear()

## The plate under `at`, or -1.
func _plate_at(at: Vector2) -> int:
	for i in _plates.size():
		if _plates[i].has_point(at):
			return i
	return -1

## A thumb while the answers are up. Down on a plate lights its answer, and
## lifted off the same plate gives it; slid off first, it gives nothing. Down
## anywhere else does nothing at all. Either way the finger is this box's until
## it lifts, whatever it does meanwhile. With no answers up everything is left
## for the console, whose page brings the line out or goes on.
##
## The system hands a touch over as a click as well, and first. That click is
## swallowed with the touch it belongs to while the answers are up, or the
## console would take it for a tap on the page, and give the answer lit.
func _input(event: InputEvent) -> void:
	var finger := MOUSE
	var at := Vector2.INF
	var down := false
	var lifted := false
	var touch := event as InputEventScreenTouch
	var drag := event as InputEventScreenDrag
	var click := event as InputEventMouseButton
	var moved := event as InputEventMouseMotion
	if touch != null:
		finger = touch.index
		at = touch.position
		down = touch.pressed
		lifted = not touch.pressed
	elif drag != null:
		finger = drag.index
		at = drag.position
	elif click != null and click.button_index == MOUSE_BUTTON_LEFT:
		at = click.position
		if click.device == InputEvent.DEVICE_ID_EMULATION:
			# The touch's own click: the box's while the answers are up, and
			# nothing more — the touch that follows is the press.
			if not _plates.is_empty() or not _mine.is_empty():
				get_viewport().set_input_as_handled()
			return
		down = click.pressed
		lifted = not click.pressed
	elif moved != null:
		if moved.device == InputEvent.DEVICE_ID_EMULATION:
			if not _mine.is_empty():
				get_viewport().set_input_as_handled()
			return
		at = moved.position
	else:
		return

	if down:
		# A finger coming down is a new touch, whatever it was before.
		_mine.erase(finger)
		if _plates.is_empty():
			return
		_mine[finger] = true
		get_viewport().set_input_as_handled()
		var i := _plate_at(at)
		if i >= 0:
			# One thumb at a time: a second on another plate lights that one
			# and takes the answer over.
			npc.select(i)
			_press = {"finger": finger, "index": i}
		return
	if not _mine.has(finger):
		return
	get_viewport().set_input_as_handled()
	var on_one := not _press.is_empty() and int(_press["finger"]) == finger
	if lifted:
		_mine.erase(finger)
		if on_one:
			var i := int(_press["index"])
			_press = {}
			if _plate_at(at) == i:
				npc.choose(i)
	elif on_one and _plate_at(at) != int(_press["index"]):
		_press = {}

## Notes when each letter comes out, so it can rise into place in its own time.
## The reveal stops dead at the end of the line, so this cannot be read off how
## far past a letter it has run — the last few would never finish arriving. A
## press that finishes the line brings everything left out at once, already in
## place: the player asked to read it, not to watch it.
func _track_arrivals(talking: bool) -> void:
	if not talking:
		_node = ""
		_arrived.clear()
		return
	if npc.node_id != _node:
		_node = npc.node_id
		_arrived.clear()
	var shown := int(npc.revealed)
	var fresh := shown - _arrived.size()
	var at := _t if fresh <= 2 else _t - POP_TIME
	for i in maxi(fresh, 0):
		_arrived.append(at)

func _draw() -> void:
	if _open <= 0.0:
		return
	if thumb():
		_draw_for_a_thumb()
		return
	var w := clampf(size.x - SIDE_CLEAR * 2.0, MIN_WIDTH, MAX_WIDTH)
	var text_w := w - PORTRAIT - PAD * 3.0
	var line_h := LINE_H
	# Wrapped from the whole line, not the part revealed so far, so a word never
	# jumps to the next row halfway through coming in.
	var rows := _wrap(npc.current_line(), text_w, TEXT_SIZE)
	var options: Array = []
	for c in npc.choices():
		options.append(_wrap(String(c.get("text", "")), text_w - CHOICE_INDENT, TEXT_SIZE))

	# Sized for the answers from the first letter, even though they only appear
	# once the question is out, so the box never grows under the reader's eye.
	var text_h := line_h * rows.size()
	if not options.is_empty():
		text_h += CHOICE_GAP * 2.0 + LINE_H
		for opt in options:
			text_h += line_h * opt.size()
	var h := maxf(PORTRAIT, text_h) + PAD * 2.0
	var full := Rect2(roundf((size.x - w) * 0.5), TOP, w, h)

	var e := 1.0 - pow(1.0 - _open, 3.0)
	if _open < 1.0:
		var opening := Rect2(full.position.x, full.get_center().y - h * 0.5 * e, w, h * e)
		draw_rect(opening, Style.DIALOGUE_FILL)
		draw_rect(opening, Style.DIALOGUE_EDGE, false, 2.0)
		return

	var node := npc.current_node()
	var mood := Style.emotion(String(node.get("emotion", "neutral")))
	var on_right := npc.speaker() == "player"
	var portrait := Rect2(
		Vector2(full.end.x - PAD - PORTRAIT if on_right else full.position.x + PAD, full.position.y + PAD),
		Vector2(PORTRAIT, PORTRAIT))

	_draw_name_tab(portrait, on_right)
	draw_rect(full, Style.DIALOGUE_FILL)
	draw_rect(full, Style.DIALOGUE_EDGE, false, 2.0)
	_draw_portrait(portrait, _portrait_art(node), mood, on_right)

	var pen := Vector2(full.position.x + PAD if on_right else portrait.end.x + PAD, full.position.y + PAD)
	var text_right := portrait.position.x - PAD if on_right else full.end.x - PAD
	_draw_line(pen, rows, line_h, Style.letter_motion(node))
	pen.y += line_h * rows.size()

	if npc.is_choosing():
		pen.y += CHOICE_GAP
		for i in options.size():
			var opt: PackedStringArray = options[i]
			var chosen := i == npc.selected
			if chosen:
				var mid := pen.y + line_h * 0.5
				var nudge := roundf(absf(sin(_t * 6.0)) * 3.0)
				draw_colored_polygon(PackedVector2Array([
					Vector2(pen.x + 2.0 + nudge, mid - 6.0), Vector2(pen.x + 11.0 + nudge, mid),
					Vector2(pen.x + 2.0 + nudge, mid + 6.0),
				]), Style.DIALOGUE_MARK)
			for row in opt:
				_text(pen + Vector2(CHOICE_INDENT, 0), row, TEXT_SIZE,
					Style.DIALOGUE_TEXT if chosen else Style.DIALOGUE_CHOICE)
				pen.y += line_h
		pen.y += CHOICE_GAP
		_text(pen, _choice_hint(), HINT_SIZE, Style.DIALOGUE_HINT)
	elif npc.line_finished():
		# The bouncing arrow: the line is out, and a press moves on.
		var m := Vector2(text_right - 8.0, full.end.y - PAD - 4.0 - roundf(absf(sin(_t * 5.0)) * 5.0))
		draw_colored_polygon(PackedVector2Array([
			m + Vector2(-8, -8), m + Vector2(8, -8), m,
		]), Style.DIALOGUE_MARK)

## Mobile mode's box: the same parts, at a thumb's size, with the answers on
## plates under it. See `_thumb_layout` for where everything stands.
func _draw_for_a_thumb() -> void:
	var l := _thumb_layout()
	var full: Rect2 = l["box"]
	var e := 1.0 - pow(1.0 - _open, 3.0)
	if _open < 1.0:
		var opening := Rect2(full.position.x, full.get_center().y - full.size.y * 0.5 * e,
			full.size.x, full.size.y * e)
		draw_rect(opening, Style.DIALOGUE_FILL)
		draw_rect(opening, Style.DIALOGUE_EDGE, false, 2.0)
		return
	var node := npc.current_node()
	var mood := Style.emotion(String(node.get("emotion", "neutral")))
	var on_right: bool = l["on_right"]
	var portrait: Rect2 = l["portrait"]
	var rows: PackedStringArray = l["rows"]
	_draw_name_tab(portrait, on_right)
	draw_rect(full, Style.DIALOGUE_FILL)
	draw_rect(full, Style.DIALOGUE_EDGE, false, 2.0)
	_draw_portrait(portrait, _portrait_art(node), mood, on_right)
	var pen := Vector2(full.position.x + THUMB_PAD if on_right else portrait.end.x + THUMB_PAD,
		full.position.y + THUMB_PAD)
	var text_right := portrait.position.x - THUMB_PAD if on_right else full.end.x - THUMB_PAD
	_draw_line(pen, rows, _line_h(), Style.letter_motion(node))

	if npc.is_choosing():
		var plates: Array = l["plates"]
		for i in plates.size():
			_draw_plate(plates[i], i)
		_text(Vector2(full.position.x, float(l["foot"])), _choice_hint(), HINT_SIZE, Style.DIALOGUE_HINT)
	elif npc.line_finished():
		# The bouncing arrow, twice the size, and what it is asking for beside it,
		# in words: on the glass there is no key for it to name.
		var m := Vector2(text_right - 16.0, full.end.y - THUMB_PAD - 4.0 - roundf(absf(sin(_t * 5.0)) * 5.0))
		draw_colored_polygon(PackedVector2Array([
			m + Vector2(-16, -16), m + Vector2(16, -16), m,
		]), Style.DIALOGUE_MARK)
		var hint := Loc.t("hud.dialogue.next_touch")
		_text(Vector2(text_right - 44.0 - _width(hint, HINT_SIZE), full.end.y - THUMB_PAD - LINE_H),
			hint, HINT_SIZE, Style.DIALOGUE_HINT)

## One answer's plate: the box's own ground and edge, lit for the answer picked,
## with the marker before its words.
func _draw_plate(plate: Dictionary, i: int) -> void:
	var r: Rect2 = plate["rect"]
	var rows: PackedStringArray = plate["rows"]
	var chosen := i == npc.selected
	draw_rect(r, Style.DIALOGUE_FILL)
	draw_rect(r, Style.DIALOGUE_EDGE if chosen else Color(Style.DIALOGUE_EDGE, 0.35), false, 2.0)
	var top := r.position.y + (r.size.y - _line_h() * rows.size()) * 0.5
	if chosen:
		var mid := r.position.y + r.size.y * 0.5
		var nudge := roundf(absf(sin(_t * 6.0)) * 4.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(r.position.x + 12.0 + nudge, mid - 12.0), Vector2(r.position.x + 28.0 + nudge, mid),
			Vector2(r.position.x + 12.0 + nudge, mid + 12.0),
		]), Style.DIALOGUE_MARK)
	for k in rows.size():
		_text(Vector2(r.position.x + PLATE_MARK + PLATE_PAD, top + _line_h() * k), rows[k], _text_size(),
			Style.DIALOGUE_TEXT if chosen else Style.DIALOGUE_CHOICE)

## The name on a tab over the portrait's end of the box, drawn first so the
## box's edge runs across its foot.
func _draw_name_tab(portrait: Rect2, on_right: bool) -> void:
	var speaker := npc.speaker_name()
	var tab_w := _width(speaker, _name_size()) + 24.0
	var x := portrait.end.x - tab_w if on_right else portrait.position.x
	var tab := Rect2(Vector2(x, portrait.position.y - _pad() - _tab_h() + 2.0), Vector2(tab_w, _tab_h()))
	draw_rect(tab, Style.DIALOGUE_TAB)
	_text(tab.position + Vector2(12.0, (_tab_h() - _line_h()) * 0.5), speaker,
		_name_size(), Style.DIALOGUE_NAME)

## Whose face goes in the frame: the line's own `sprite` if it names one the
## atlas has, otherwise whoever is speaking — in their face for the line's
## emotion, where the atlas has one.
func _portrait_art(node: Dictionary) -> String:
	var art := Style.hero_portrait_art(GameState.hero) if npc.speaker() == "player" \
		else Style.npc_art(String(npc.data.get("sprite", "")))
	var override := String(node.get("sprite", ""))
	if Style.has_character(override):
		art = override
	return Style.portrait_art(art, String(node.get("emotion", "")))

## The speaker's sprite, cropped to its drawn pixels and scaled up whole, facing
## into the box. They run through their idle faster and hop while the line is
## coming in, so they read as the one talking; the emotion does the rest.
func _draw_portrait(frame: Rect2, art: String, mood: Dictionary, flip: bool) -> void:
	draw_rect(frame, Style.DIALOGUE_PORTRAIT_BG)
	# In real colours: a Control's draw calls wear no material, and the
	# player's frames are painted in map colours (see `SkinnedCharacter`).
	var frames := Sprites.resolved_frames(art)
	var speaking := not npc.line_finished()
	var count := frames.get_frame_count("idle")
	var tex := frames.get_frame_texture("idle", int(_t * (10.0 if speaking else 4.0)) % count)
	var src := Sprites.art_rect(art)
	var factor := floorf(minf((frame.size.x - 16.0) / src.size.x, (frame.size.y - 16.0) / src.size.y))
	var dst_size := src.size * factor
	var hop := 0.0
	if speaking and fmod(_t, 0.24) < 0.12:
		hop = float(mood.get("hop", 1.0)) * factor
	# Deterministic noise rather than randf, so a portrait never draws from the
	# random numbers the fight is using.
	var shake := float(mood.get("shake", 0.0))
	var tremble := Vector2(roundf(sin(_t * 83.0) * shake), roundf(cos(_t * 71.0) * shake))
	var dst := Rect2(frame.position + Vector2(roundf((frame.size.x - dst_size.x) * 0.5),
		frame.size.y - 6.0 - dst_size.y - hop) + tremble, dst_size)
	var tint: Color = mood.get("tint", Color.WHITE)
	if flip:
		# Mirrored about the portrait's centre line, to face the text on its left.
		draw_set_transform(Vector2(dst.get_center().x * 2.0, 0.0), 0.0, Vector2(-1.0, 1.0))
	draw_texture_rect_region(tex, dst, src, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(frame, Style.DIALOGUE_EDGE, false, 2.0)
	var corner := Vector2(frame.position.x + MARK_INSET.x if flip else frame.end.x - MARK_INSET.x,
		frame.position.y + MARK_INSET.y)
	_draw_mark(String(mood.get("mark", "")), corner)

## The little sign an emotion puts by the face, drawn from primitives.
func _draw_mark(kind: String, at: Vector2) -> void:
	if kind == "":
		return
	var col: Color = Style.EMOTE_COLORS.get(kind, Style.DIALOGUE_MARK)
	var p := at + Vector2(0, roundf(sin(_t * 5.0) * 2.0))
	match kind:
		"exclaim":
			draw_rect(Rect2(p + Vector2(-3, -12), Vector2(6, 13)), col)
			draw_rect(Rect2(p + Vector2(-3, 4), Vector2(6, 6)), col)
		"dots":
			for i in 3:
				if int(_t * 3.0) % 4 > i:
					draw_rect(Rect2(p + Vector2(-13.0 + i * 9.0, 0), Vector2(5, 5)), col)
		"sparkle":
			for s in [Vector2(-7, -5), Vector2(7, 6)]:
				var r := 4.0 + roundf(absf(sin(_t * 6.0 + s.x)) * 3.0)
				draw_rect(Rect2(p + s - Vector2(1, r), Vector2(2, r * 2.0)), col)
				draw_rect(Rect2(p + s - Vector2(r, 1), Vector2(r * 2.0, 2)), col)
		"drop", "sweat":
			# A tear runs down; sweat just hangs there.
			var d := p + Vector2(0, roundf(fmod(_t * 18.0, 18.0)) if kind == "drop" else 0.0)
			draw_colored_polygon(PackedVector2Array([
				d + Vector2(0, -8), d + Vector2(5, 2), d + Vector2(0, 6), d + Vector2(-5, 2),
			]), col)
		"vein":
			var pulse := 1.0 + absf(sin(_t * 8.0)) * 0.3
			for a in 4:
				var dir := Vector2.RIGHT.rotated(a * PI * 0.5 + PI * 0.25)
				draw_line(p + dir * 3.0 * pulse, p + dir * 9.0 * pulse, col, 3.0)

## The line so far, a letter at a time, each rising into place from when it came
## out (see `_track_arrivals`), trembling, rippling or hopping as `motion` asks
## (`Style.letter_offset`).
func _draw_line(pen: Vector2, rows: PackedStringArray, line_h: float, motion: Dictionary) -> void:
	var shown := mini(int(npc.revealed), _arrived.size())
	var ascent := roundf(_font.get_ascent(_text_size()))
	var i := 0
	for row in rows:
		var x := pen.x
		for k in row.length():
			if i >= shown:
				return
			var p := clampf((_t - _arrived[i]) / POP_TIME, 0.0, 1.0)
			var col := Style.DIALOGUE_TEXT
			col.a *= p
			var off := Vector2(0, POP_RISE * (1.0 - p)).round() + Style.letter_offset(motion, i, _t)
			x += _font.draw_char(get_canvas_item(), Vector2(x, pen.y + ascent) + off,
				row.unicode_at(k), _text_size(), col)
			i += 1
		i += 1   # the space the wrap swallowed
		pen.y += line_h

## How to answer, in whatever the player has the keys bound to. On the glass
## there are no keys for it to name: an answer's plate is tapped to give it.
func _choice_hint() -> String:
	if thumb() or Controls.on_glass():
		return Loc.t("hud.dialogue.choose_touch")
	return Loc.t("hud.dialogue.choose", [Controls.short_label_for("move_up"),
		Controls.short_label_for("move_down"), Controls.short_label_for("interact")])

## Draws `text` with its top-left corner at `pos`.
func _text(pos: Vector2, text: String, font_size: int, color: Color) -> void:
	# Rounded onto whole pixels: the face's ascent is 16.48px, and a baseline
	# half a pixel down draws the whole row between two rows of them.
	draw_string(_font, (pos + Vector2(0, _font.get_ascent(font_size))).round(), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _width(text: String, font_size: int) -> float:
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

## Greedy word wrap into rows no wider than `width`. A single word wider than
## the box gets a row of its own rather than being split.
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
