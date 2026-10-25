class_name Controls
extends RefCounted

## Key rebinding. Overrides live in a small JSON file next to the save; the
## project's defaults stay untouched so a reset is always one click away.

const PATH := "user://enigami_controls.json"

const ACTIONS := [
	["move_left", "Move left"],
	["move_right", "Move right"],
	["move_up", "Up"],
	["move_down", "Crouch"],
	["dash", "Dash"],
	["sprint", "Sprint"],
	["attack", "Attack"],
	["cast_skill", "Charged cast"],
	["weapon_1", "Weapon 1"],
	["weapon_2", "Weapon 2"],
	["weapon_3", "Weapon 3"],
	["weapon_4", "Weapon 4"],
	["weapon_next", "Next weapon"],
	["weapon_prev", "Previous weapon"],
	["step_out", "Leave monster"],
	["open_editor", "Skill assembly"],
	["open_map", "Map"],
	["interact", "Interact / extract"],
	["magic_toggle", "Magic on / off"],
	["open_phone", "Phone"],
	["pause", "Pause"],
]

static var _defaults: Dictionary = {}

## The mouse bindings while the on-screen pad has the screen, and whether it
## has. See `set_mouse_aside`.
static var _aside: Dictionary = {}
static var _mouse_aside: bool = false

## What to call an action on the rebinding screen. The English in ACTIONS is
## the fallback, so an action added there is named before it is translated.
static func action_name(action: String) -> String:
	for entry in ACTIONS:
		if String(entry[0]) == action:
			return Loc.opt("controls.action.%s" % action, String(entry[1]))
	return Loc.opt("controls.action.%s" % action, action)

## Snapshot the project defaults once, so "reset" can restore them later.
static func capture_defaults() -> void:
	if not _defaults.is_empty():
		return
	for entry in ACTIONS:
		var a: String = entry[0]
		if InputMap.has_action(a):
			_defaults[a] = InputMap.action_get_events(a).duplicate()

## --- the glass --------------------------------------------------------------

## Puts the mouse bindings away while the on-screen console is up, and hands
## them back when it goes.
##
## A finger is not a mouse, but the system says it is: a touch is turned into a
## click at the point it landed on, and `attack` is bound to a click. A thumb
## resting on the movement keys would swing the weapon for as long as it rested
## there, and so would every tap on every other key. The pad presses those
## actions itself, so nothing is lost by taking the click away for as long as it
## is up.
##
## The bindings are kept rather than deleted: `events_for` still reports them,
## so the rebinding screen shows what the player chose and `save` writes it, and
## the drawer is emptied back into the InputMap the moment the pad leaves.
static func set_mouse_aside(aside: bool) -> void:
	if aside == _mouse_aside:
		return
	_mouse_aside = aside
	if aside:
		_take_mouse()
		return
	for a in _aside:
		for e in _aside[a]:
			InputMap.action_add_event(a, e)
	_aside.clear()

static func mouse_aside() -> bool:
	return _mouse_aside

## Whether the console has the screen, for a prompt that has to say what a thumb
## does rather than name a key: the mouse is put away for exactly as long as it
## is up.
static func on_glass() -> bool:
	return _mouse_aside

## Everything bound to `action`, whether or not the pad is holding the mouse.
## The bindings a screen shows and a file keeps are the player's, and the pad
## borrowing the mouse for a while is not a rebinding.
static func events_for(action: String) -> Array:
	var list := InputMap.action_get_events(action)
	if _aside.has(action):
		list.append_array(_aside[action])
	return list

## Moves every mouse binding into the drawer. Idempotent, so it can be run again
## after anything that puts events back into the InputMap.
static func _take_mouse() -> void:
	for entry in ACTIONS:
		var a: String = entry[0]
		if not InputMap.has_action(a):
			continue
		for e in InputMap.action_get_events(a):
			if not (e is InputEventMouseButton):
				continue
			InputMap.action_erase_event(a, e)
			if not _aside.has(a):
				_aside[a] = []
			(_aside[a] as Array).append(e)

## --- what a binding is called -----------------------------------------------

## What the key on the glass for `action` says, or "" where the console has no
## word for it. The words are `controls.pad.<action>`, so the file the console
## is written in is also the list of which actions it names — a direction is an
## arrow and a slot is its own number, and neither has a word here.
static func word_for(action: String) -> String:
	return Loc.opt("controls.pad.%s" % action, "")

static func label_for(action: String) -> String:
	if not InputMap.has_action(action):
		return Loc.t("controls.none")
	var names: Array[String] = []
	for e in events_for(action):
		if e is InputEventKey:
			names.append(OS.get_keycode_string((e as InputEventKey).physical_keycode))
		elif e is InputEventMouseButton:
			names.append(mouse_name((e as InputEventMouseButton).button_index))
		elif e is InputEventJoypadButton:
			names.append(Loc.t("controls.pad_button", [(e as InputEventJoypadButton).button_index]))
		elif e is InputEventJoypadMotion:
			var m := e as InputEventJoypadMotion
			names.append(Loc.t("controls.pad_axis", [m.axis, "+" if m.axis_value > 0 else "-"]))
	if names.is_empty():
		return Loc.t("controls.unbound")
	return " / ".join(names)

## The single binding a HUD should print: the first keyboard or mouse one, with
## the pad and any alternates left off. `label_for` lists everything, which is
## right for the rebinding screen and far too long for the HUD's square.
static func short_label_for(action: String) -> String:
	if not InputMap.has_action(action):
		return Loc.t("controls.none")
	# While the console has the screen there is no key to name: what the player
	# presses is the one under their thumb, so that is what a HUD should print.
	# Everything that tells the player which control does what reads this, so
	# one answer here is the whole difference between a square that says "LMB"
	# on a phone and one that says "HIT".
	if _mouse_aside:
		var word := word_for(action)
		if word != "":
			return word
	for e in events_for(action):
		if e is InputEventKey:
			# The game's own actions are bound by position on the board, so they
			# carry a physical code. Godot's built-in `ui_*` actions carry a
			# keycode instead and leave the physical one at zero, which read as
			# a binding with no name at all — an empty hint under a cutscene.
			var key := e as InputEventKey
			var code := key.physical_keycode if key.physical_keycode != 0 else key.keycode
			return OS.get_keycode_string(code)
		if e is InputEventMouseButton:
			return mouse_name((e as InputEventMouseButton).button_index)
	return Loc.t("controls.none")

## What a mouse button is called. The three under the fingers have their short
## names; the wheel is a button too, as far as a binding goes — one press a
## notch, up or down — and is called by what the hand does to it; anything
## else on the mouse goes by its number.
static func mouse_name(index: int) -> String:
	match index:
		MOUSE_BUTTON_LEFT:
			return "LMB"
		MOUSE_BUTTON_RIGHT:
			return "RMB"
		MOUSE_BUTTON_MIDDLE:
			return "MMB"
		MOUSE_BUTTON_WHEEL_UP:
			return Loc.t("controls.wheel_up")
		MOUSE_BUTTON_WHEEL_DOWN:
			return Loc.t("controls.wheel_down")
	return Loc.t("controls.mouse", [index])

## Replaces the keyboard/mouse binding of `action`, leaving the gamepad one.
static func rebind(action: String, event: InputEvent) -> bool:
	if not InputMap.has_action(action):
		return false
	if not (event is InputEventKey or event is InputEventMouseButton):
		return false
	for e in InputMap.action_get_events(action):
		if e is InputEventKey or e is InputEventMouseButton:
			InputMap.action_erase_event(action, e)
	_aside.erase(action)
	InputMap.action_add_event(action, event)
	# Bound while the pad is up: the binding is the player's and is kept, but
	# it goes straight into the drawer with the others until the pad goes.
	if _mouse_aside:
		_take_mouse()
	save()
	return true

static func reset() -> void:
	capture_defaults()
	_aside.clear()
	for a in _defaults:
		InputMap.action_erase_events(a)
		for e in _defaults[a]:
			InputMap.action_add_event(a, e)
	if _mouse_aside:
		_take_mouse()
	save()

static func save() -> void:
	var data: Dictionary = {}
	for entry in ACTIONS:
		var a: String = entry[0]
		if not InputMap.has_action(a):
			continue
		var list: Array = []
		for e in events_for(a):
			if e is InputEventKey:
				list.append({"t": "key", "k": (e as InputEventKey).physical_keycode})
			elif e is InputEventMouseButton:
				list.append({"t": "mouse", "b": (e as InputEventMouseButton).button_index})
		if not list.is_empty():
			data[a] = list
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()

static func load_saved() -> void:
	capture_defaults()
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for a in parsed:
		if not InputMap.has_action(a):
			continue
		_aside.erase(a)
		for e in InputMap.action_get_events(a):
			if e is InputEventKey or e is InputEventMouseButton:
				InputMap.action_erase_event(a, e)
		for entry in parsed[a]:
			if String(entry.get("t", "")) == "key":
				var k := InputEventKey.new()
				k.physical_keycode = int(entry["k"]) as Key
				InputMap.action_add_event(a, k)
			elif String(entry.get("t", "")) == "mouse":
				var m := InputEventMouseButton.new()
				m.button_index = int(entry["b"]) as MouseButton
				InputMap.action_add_event(a, m)
	if _mouse_aside:
		_take_mouse()
