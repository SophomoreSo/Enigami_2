class_name ControlsPanel
extends PanelContainer

## The input settings: how fast the pointer moves, how much a stick's aim is
## helped, whether the game is in mobile mode — and, while it is, where its
## buttons stand — and which key does what.
##
## The pointer and mobile mode sit at the top rather than with the volumes,
## because what they belong with is this — they are controls, and this is the
## page controls are on. They are drawn in the same two columns as the bindings
## under them, so the name and the thing that sets it line up all the way down
## the panel.
##
## **In mobile mode it is a different list** (`UiKit.mobile`), laid out for a
## thumb: the aim's help, the switch, and SET BUTTON POSITIONS, each a row THUMB
## tall. The pointer's speed and the bindings are a desk's — the mouse is put
## away while the console is up, and there is no key on the glass to press for
## a binding — so they are not on it; where the console's buttons stand is what
## SET BUTTON POSITIONS is for. Throwing the switch off brings them back. The
## panel is built in one layout or the other, and whoever holds it builds the
## page again when the mode is thrown, as for a language.

## Set before it enters the tree to build it in UiKit's pixel look. Both screens
## that hold one do — the title's settings and the pause menu.
var pixel: bool = false

var _listening: String = ""
var _rows: Dictionary = {}
var _mobile: UiKit.Switch = null
var _arrange: Button = null

func _ready() -> void:
	_build()
	# Self-sufficient, so the panel reads right wherever it is put. Both screens
	# that hold one happen to rebuild it themselves, and the one being thrown
	# away in that rebuild bows out below rather than redressing a corpse.
	Loc.language_changed.connect(_relanguage)

## How fast the game's own pointer moves — the crosshair, while the player has
## the controls. Menus are the system pointer's and stay as the desk has them,
## so this is aim speed; `app/pointer.gd` says why it can be nothing else. It
## answers while the slider is being dragged, so it is set by feel and needs no
## number beside it. RESET below is the bindings' own and does not reach up.
func _pointer_row(name_width: int, bind_width: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_name(Loc.t("controls.sensitivity"), name_width))
	var s := HSlider.new()
	s.min_value = Pointer.MIN_SENS
	s.max_value = Pointer.MAX_SENS
	s.step = Pointer.STEP
	s.value = Pointer.sensitivity
	s.custom_minimum_size = Vector2(bind_width, 24)
	UiKit.pixel_slider(s)
	s.value_changed.connect(func(v: float) -> void: Pointer.set_sensitivity(v))
	row.add_child(s)
	return row

## How much a stick's aim is bent toward what it is near — a gamepad's, or the
## console's on the glass (`AimAssist`): none of it at the left end, all of it
## at the right. The pointer is never bent, so this sits under the pointer's
## own row as the other half of aiming, and like it answers while it is dragged.
func _assist_row(name_width: int, bind_width: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_name(Loc.t("controls.aim_assist"), name_width))
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = AimAssist.STEP
	s.value = AimAssist.strength
	s.custom_minimum_size = Vector2(bind_width, 24)
	UiKit.pixel_slider(s)
	s.value_changed.connect(func(v: float) -> void: AimAssist.set_strength(v))
	row.add_child(s)
	return row

## Mobile mode: a console on the screen for a thumb to play on —
## `mobile/view/touch_pad.gd`, and `mobile/input/touch.gd` for what a key on it does —
## and the title's menu laid out as tiles big enough to land a thumb on.
##
## A switch, showing whether the console is on. A fresh install is in AUTO,
## which is on wherever the machine is one you touch and off everywhere else —
## what a phone wants without anybody having to find this row first — so until
## it is thrown the switch shows what AUTO came to. Throwing it is an answer for
## good, for the machines that are both — a tablet with a keyboard, a desk with
## a touchscreen — and for looking at the thing on a desk.
func _touch_row(name_width: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_name(Loc.t("controls.mobile"), name_width))
	_mobile = UiKit.switch(Touch.wanted(), func(on: bool) -> void:
		Audio.play("ui")
		Touch.set_mode(Touch.ON if on else Touch.OFF)
		_show_arrange())
	row.add_child(_mobile)
	return row

## Where mobile mode's buttons stand, put there by the player on a screen of its
## own (`TouchLayoutEditor`) — one button, across both columns, under the switch
## it belongs to. Only there while mobile mode is on: with the console off there
## is nothing on the glass to move.
func _arrange_row() -> Control:
	_arrange = UiKit.button(Loc.t("controls.arrange.open"), UiKit.ACCENT, pixel)
	_arrange.pressed.connect(_open_arrange)
	_show_arrange()
	return _arrange

func _show_arrange() -> void:
	if _arrange != null and is_instance_valid(_arrange):
		_arrange.visible = Touch.wanted()

## Over everything — the page this is on, and the pause menu or the title under
## that — on a layer of its own, which goes when the screen closes. Running
## while the game is paused, since the pause menu is one way here.
func _open_arrange() -> void:
	Audio.play("ui")
	var layer := CanvasLayer.new()
	layer.layer = 30
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var editor := TouchLayoutEditor.new()
	layer.add_child(editor)
	add_child(layer)
	editor.closed.connect(func() -> void:
		layer.queue_free()
		if _arrange != null and is_instance_valid(_arrange) and _arrange.is_visible_in_tree():
			_arrange.grab_focus())

## The title's settings and the pause menu each hold one of these, and mobile
## mode thrown in one is in force in the other. So the switch is set from the
## mode every time the panel comes on screen, rather than left showing the one
## it was built with — and SET BUTTON POSITIONS comes and goes with it.
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree() \
			and _mobile != null and is_instance_valid(_mobile):
		_mobile.show_on(Touch.wanted())
		_show_arrange()

func _relanguage(_lang: String) -> void:
	if is_queued_for_deletion():
		return
	_rebuild()

## Built rather than refreshed, so a change of language reaches the action
## names as well as the buttons. Whatever was being listened for is dropped:
## the panel it was going to land in no longer exists.
func _rebuild() -> void:
	_listening = ""
	_rows.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_build()

## Whether the panel is laid out for a thumb: in the pixel look, in mobile mode.
func thumb() -> bool:
	return pixel and UiKit.mobile()

## A row's name, in the column the rows keep: the size the mode writes a menu's
## words at.
func _name(text: String, width: float) -> Label:
	var l := UiKit.label(text, UiKit.text(11) if pixel else 11, UiKit.TEXT, pixel)
	l.custom_minimum_size = Vector2(width, 0)
	return l

func _build() -> void:
	add_theme_stylebox_override("panel", UiKit.style(UiKit.PANEL, Color(0.22, 0.3, 0.38), 1, 3, pixel))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4 if pixel else 3)
	add_child(v)
	if thumb():
		_build_for_a_thumb(v)
		return
	v.add_child(UiKit.label(Loc.t("controls.heading"), 13, UiKit.ACCENT, pixel))
	v.add_child(UiKit.hline(pixel))
	# The pixel face runs up to twice as wide, so both columns widen with it:
	# 200 holds the longest action name, 352 the longest default binding.
	var name_width := 200 if pixel else 150
	var bind_width := 352 if pixel else 200
	v.add_child(_pointer_row(name_width, bind_width))
	v.add_child(_assist_row(name_width, bind_width))
	v.add_child(_touch_row(name_width))
	v.add_child(_arrange_row())
	v.add_child(UiKit.hline(pixel))
	for entry in Controls.ACTIONS:
		var action: String = entry[0]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var l := UiKit.label(Controls.action_name(action), 11, UiKit.TEXT, pixel)
		l.custom_minimum_size = Vector2(name_width, 0)
		row.add_child(l)
		var b := UiKit.button(Controls.label_for(action), UiKit.ACCENT, pixel)
		b.custom_minimum_size = Vector2(bind_width, 24)
		b.pressed.connect(func() -> void:
			_listening = action
			_refresh())
		row.add_child(b)
		_rows[action] = b
		v.add_child(row)
	var rb := UiKit.button(Loc.t("controls.reset"), UiKit.BAD, pixel)
	rb.pressed.connect(func() -> void:
		Controls.reset()
		_refresh())
	v.add_child(rb)

## Mobile mode's list: what a thumb sets, and nothing a thumb cannot. No heading
## of its own — the one a desk's carries is about pressing a key for a binding —
## and no bindings under it.
func _build_for_a_thumb(v: VBoxContainer) -> void:
	UiKit.pass_presses(self)
	v.add_theme_constant_override("separation", 8)
	var name_width := int(UiKit.setting_label_w())
	v.add_child(_assist_row(name_width, 0))
	v.add_child(_touch_row(name_width))
	v.add_child(_arrange_row())

func _refresh() -> void:
	for a in _rows:
		var b: Button = _rows[a]
		b.text = Loc.t("controls.listening") if a == _listening else Controls.label_for(a)

func _input(event: InputEvent) -> void:
	if _listening == "" or not visible:
		return
	if not event.is_pressed():
		return
	if event is InputEventKey and (event as InputEventKey).keycode == KEY_ESCAPE:
		_listening = ""
		_refresh()
		get_viewport().set_input_as_handled()
		return
	if Controls.rebind(_listening, event):
		Audio.play("place")
		_listening = ""
		_refresh()
		get_viewport().set_input_as_handled()
