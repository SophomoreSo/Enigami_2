class_name TouchLayoutEditor
extends Control

## The console's buttons, to be put where the player's thumbs want them: the
## screen behind SET BUTTON POSITIONS on the control settings, which is there
## while mobile mode is.
##
## Every button is up at once — drawn the way the pad draws them, where the arrangement
## in force puts them (`TouchPad.layout`). A thumb, or the mouse, takes one and
## drags it. Let go somewhere it fits and it stays; let go where it does not —
## on another button, over the HUD's corner or this screen's own panel — and it
## goes back to where it was taken from, having been drawn red the whole way.
## Nothing is kept until SAVE. RESET puts every button back where the design
## has it, and CANCEL, or the way back out, leaves everything as it was.
##
## A button let go of keeps its distance from whichever corner of the screen it
## is nearest, the way the design's own keep theirs (`TouchPad.area`): moved to
## the left of a long phone, it stays that far from the left edge on a squarer
## screen rather than being carried off to the right with the rest.

signal closed()

## The panel down the left: how wide its words may run, and where it stands.
## The left is where the movement stick grows, so no button stands there
## unless the player puts one there, and this is the one screen that says so.
const PANEL_W := 336.0
const PANEL_X := 48.0

## The HUD's corner — the bars and the weapon's line under them — which no
## button may cover: a thumb on HIT would sit on the health bar for the whole
## of a fight.
const HUD_CORNER := Rect2(Hud.BAR_AT,
	Vector2(Hud.BAR_W, Hud.WEAPON_LINE + PixelDraw.LINE - Hud.BAR_AT.y))

## Behind it all: the settings page this was opened from, nearly out of sight.
const GROUND := Color(UiKit.BG, 0.95)
const CORNER_INK := Color(UiKit.DIM, 0.45)

## The arrangement being made: `TouchPad.layout`'s shape, kept only on SAVE.
var _working: Dictionary = {}
## The button being dragged, by index into `TouchPad.CONTROLS`, or -1; which
## finger has it (`TouchPad.MOUSE` for the mouse); how far from its middle —
## a plate's corner — it was taken; and where that middle or corner is now.
var _dragging := -1
var _finger := TouchPad.MOUSE
var _grab := Vector2.ZERO
var _now := Vector2.ZERO
## Whether this machine has reported a finger here: see `TouchPad._fingers`.
var _fingers := false
var _panel: PanelContainer
var _save: Button
var _px := PixelDraw.new(self)

func _ready() -> void:
	UiKit.fill_screen(self)
	# Everything under it is out of reach while it is up: the page it was opened
	# from, and whatever that page was opened over.
	mouse_filter = Control.MOUSE_FILTER_STOP
	_working = TouchPad.layout().duplicate(true)
	_build_panel()
	_save.grab_focus()

func _build_panel() -> void:
	_panel = UiKit.panel(UiKit.PANEL, UiKit.LINE, true)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_panel.add_child(v)
	v.add_child(UiKit.label(Loc.t("controls.arrange.heading"), 16, UiKit.ACCENT, true))
	v.add_child(UiKit.hline(true))
	var words := UiKit.label(Loc.t("controls.arrange.hint"), 16, UiKit.TEXT, true)
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.custom_minimum_size = Vector2(PANEL_W, 0)
	v.add_child(words)
	v.add_child(UiKit.spacer(4))
	_save = UiKit.button(Loc.t("controls.arrange.save"), UiKit.GOOD, true)
	_save.pressed.connect(_keep)
	var reset := UiKit.button(Loc.t("controls.arrange.reset"), UiKit.WARN, true)
	reset.pressed.connect(_reset)
	var cancel := UiKit.button(Loc.t("controls.arrange.cancel"), UiKit.DIM, true)
	cancel.pressed.connect(func() -> void: _close())
	var column := [_save, reset, cancel]
	for b: Button in column:
		# A thumb's, like every button the kit makes while mobile mode is on —
		# which it is, to be here at all.
		b.custom_minimum_size = Vector2(0, maxf(36, UiKit.thumb()))
		v.add_child(b)
	add_child(_panel)
	# The keyboard goes round these three and nowhere else: the page under them
	# has buttons of its own, a direction key away.
	for i in column.size():
		var b: Button = column[i]
		var up: Button = column[(i + column.size() - 1) % column.size()]
		var down: Button = column[(i + 1) % column.size()]
		b.focus_neighbor_top = b.get_path_to(up)
		b.focus_neighbor_bottom = b.get_path_to(down)
		b.focus_previous = b.get_path_to(up)
		b.focus_next = b.get_path_to(down)
		b.focus_neighbor_left = b.get_path_to(b)
		b.focus_neighbor_right = b.get_path_to(b)

func _process(_delta: float) -> void:
	UiKit.sync_screen(self)
	# Down the left, clear of the HUD's corner, in the middle of what is left.
	var room := size.y - HUD_CORNER.end.y
	_panel.position = Vector2(PANEL_X,
		floorf(HUD_CORNER.end.y + maxf((room - _panel.size.y) * 0.5, 16.0)))
	queue_redraw()

## --- moving a button ----------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	# The way back out is CANCEL's. Taken here, before the page underneath or
	# the pause menu can take the same press as a way out of themselves.
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		_close()
		get_viewport().set_input_as_handled()
		return
	var touch := event as InputEventScreenTouch
	if touch != null:
		_saw_a_finger(touch.index)
		_pointer(touch.index, touch.position, touch.pressed)
		return
	var drag := event as InputEventScreenDrag
	if drag != null:
		_saw_a_finger(drag.index)
		_pointer(drag.index, drag.position, true)
		return
	if _fingers:
		return          # the mouse under a finger is that finger again
	var click := event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT:
		_pointer(TouchPad.MOUSE, click.position, click.pressed)
		return
	var moved := event as InputEventMouseMotion
	if moved != null and _dragging >= 0:
		_pointer(TouchPad.MOUSE, moved.position, true)

## The system hands over a touch as a click first, so the first finger of all
## arrives as the mouse — and whatever that click picked up belongs to the
## finger from here on. See `TouchPad._saw_a_finger`.
func _saw_a_finger(index: int) -> void:
	if _fingers:
		return
	_fingers = true
	if _dragging >= 0 and _finger == TouchPad.MOUSE:
		_finger = index

## A pointer at `at`, down or not. Down on a button picks it up; moving carries
## what it holds; letting go puts it down. A press that lands on no button is
## left alone, for the panel's own buttons to have.
func _pointer(index: int, at: Vector2, pressed: bool) -> void:
	if _dragging >= 0:
		if index != _finger:
			return
		get_viewport().set_input_as_handled()
		if pressed:
			_now = _on_screen(TouchPad.CONTROLS[_dragging], at - _grab)
		else:
			_put_down()
		return
	if not pressed:
		return
	var i := _under(at)
	if i < 0:
		return
	_dragging = i
	_finger = index
	_now = _anchor(TouchPad.CONTROLS[i], _working)
	_grab = at - _now
	Audio.play("ui")
	get_viewport().set_input_as_handled()

## The button under `at`, or -1.
func _under(at: Vector2) -> int:
	var s := _screen()
	for i in TouchPad.CONTROLS.size():
		var c: Dictionary = TouchPad.CONTROLS[i]
		if TouchPad.movable(c) and TouchPad.area(TouchPad.placed(c, _working), s).has_point(at):
			return i
	return -1

## Where `c` stands on the screen as `l` has it: a round button's middle, a
## plate's top-left corner — what a drag carries.
func _anchor(c: Dictionary, l: Dictionary) -> Vector2:
	var p := TouchPad.placed(c, l)
	if c.has("rect"):
		return TouchPad.area(p, _screen()).position
	return TouchPad.middle(p, _screen())

## `at` as far as `c` can be carried towards it and stay whole on the screen.
func _on_screen(c: Dictionary, at: Vector2) -> Vector2:
	var s := _screen()
	if c.has("rect"):
		return at.clamp(Vector2.ZERO, s - (c["rect"] as Rect2).size)
	var r := Vector2.ONE * float(c["radius"])
	return at.clamp(r, s - r)

## `c` standing at `at` on the screen, as an arrangement keeps it: the corner it
## is nearest, and the place in the design that puts it there on this screen.
## On whole PIXELs, like everything the pad draws.
func _entry(c: Dictionary, at: Vector2) -> Dictionary:
	var s := _screen()
	var mid := at
	if c.has("rect"):
		mid = at + (c["rect"] as Rect2).size * 0.5
	var pin := Vector2(1.0 if mid.x > s.x * 0.5 else 0.0, 1.0 if mid.y > s.y * 0.5 else 0.0)
	var design := ((at - TouchPad.spare(s) * pin) / PixelDraw.PX).round() * PixelDraw.PX
	return {"at": design, "pin": pin}

## Whether button `i` can stay where `entry` puts it: whole on the screen, off
## the HUD's corner and this screen's panel, and clear of every other button by
## the slop a thumb is allowed either side (`TouchPad.SLOP`), which is what
## keeps a press from ever landing on two.
func _fits(i: int, entry: Dictionary) -> bool:
	var s := _screen()
	var c: Dictionary = TouchPad.CONTROLS[i]
	var mine := TouchPad.area(TouchPad.placed(c, {TouchPad.key_of(c): entry}), s)
	if not Rect2(Vector2.ZERO, s).encloses(mine):
		return false
	if mine.intersects(HUD_CORNER) or mine.intersects(_panel.get_global_rect()):
		return false
	var room := mine.grow(TouchPad.SLOP)
	for j in TouchPad.CONTROLS.size():
		var o: Dictionary = TouchPad.CONTROLS[j]
		if j == i or not TouchPad.movable(o):
			continue
		if TouchPad.area(TouchPad.placed(o, _working), s).grow(TouchPad.SLOP).intersects(room):
			return false
	return true

func _put_down() -> void:
	var c: Dictionary = TouchPad.CONTROLS[_dragging]
	var entry := _entry(c, _now)
	if _fits(_dragging, entry):
		_working[TouchPad.key_of(c)] = entry
		Audio.play("place")
	else:
		Audio.play("deny")
	_dragging = -1

## --- the way out --------------------------------------------------------------

func _keep() -> void:
	TouchPad.set_layout(_working)
	Audio.play("place")
	_close()

## Every button back where the design has it — here only, until SAVE.
func _reset() -> void:
	_working = {}
	_dragging = -1
	Audio.play("ui")

func _close() -> void:
	_dragging = -1
	Audio.play("ui")
	closed.emit()

func _screen() -> Vector2:
	return get_viewport_rect().size

## --- the picture ----------------------------------------------------------------

func _draw() -> void:
	var s := _screen()
	_px.rect(Rect2(Vector2.ZERO, s), GROUND)
	# Where the HUD stands in a fight, which nothing may cover.
	_px.frame(HUD_CORNER, CORNER_INK)
	_px.text_centered(HUD_CORNER.position + Vector2(0, HUD_CORNER.size.y * 0.5 + 5.0),
		Loc.t("controls.arrange.hud"), CORNER_INK, HUD_CORNER.size.x)
	for i in TouchPad.CONTROLS.size():
		var each: Dictionary = TouchPad.CONTROLS[i]
		if TouchPad.movable(each) and i != _dragging:
			TouchPad.paint_button(_px, TouchPad.placed(each, _working), s, false, true)
	if _dragging < 0:
		return
	# The one being carried, lit, and red with a red edge round it wherever it
	# could not stay.
	var c: Dictionary = TouchPad.CONTROLS[_dragging]
	var entry := _entry(c, _now)
	var ok := _fits(_dragging, entry)
	var p := TouchPad.placed(c, {TouchPad.key_of(c): entry})
	var r := TouchPad.area(p, s)
	# On a solid ground of its own: a button is see-through, and carried over
	# another the two words would be written over each other.
	if c.has("rect"):
		_px.rect(r, UiKit.BG)
	else:
		_px.disc(r.get_center(), r.size.x * 0.5, UiKit.BG)
	TouchPad.paint_button(_px, p, s, ok, ok)
	if not ok:
		if c.has("rect"):
			_px.frame(r.grow(PixelDraw.PX * 2), UiKit.BAD)
		else:
			_px.ring(r.get_center(), r.size.x * 0.5 + PixelDraw.PX * 3, TouchPad.EDGE_W, UiKit.BAD)
