class_name Touch
extends RefCounted

## The on-screen console: whether the game draws one, and what a thumb on it
## does to the rest of the game.
##
## A phone has no keyboard and no mouse, so a build for one has to put the
## controls on the glass. This is that setting and the plumbing under it; the
## console itself is a picture and is drawn in `mobile/view/touch_pad.gd`.
##
## **A key on the pad presses an action, and nothing else knows.** Every control
## in the game is read through `Input` — `Input.is_action_pressed("dash")`,
## `Input.get_vector("move_left", "move_right", "move_up", "move_down")` — so a
## key here sends the same
## action the keyboard would, through `Input.parse_input_event`, and the rules
## cannot tell the difference. Nothing in `feature/` mentions a finger.
##
## Sending an action rather than calling `Input.action_press` is deliberate:
## a parsed event both sets the state that is polled **and** travels the tree,
## which is what PAUSE, MAP and KIT need — those are answered in
## `_unhandled_input`, and an action pressed straight into `Input` never gets
## there. It is also idempotent, where `Input.action_release` is not: called
## twice it reports a second release, and a skill is cast on the release of its
## key.
##
## Where the setting is kept: its own file, beside the pointer speed, the
## bindings and the language, for the same reason. Whether the controls are on
## the glass is a property of the machine in front of the player, not of the
## profile being played on it.

const PATH := "user://enigami_touch.json"

## OFF never, ON always, and AUTO wherever the machine is one you touch. AUTO
## is the default for the same reason the language is guessed from the desktop:
## somebody on a phone should not have to find the settings with controls that
## are not on the screen yet.
##
## Which of them is in force is what the settings call mobile mode, and they
## show it as a switch: on or off, whichever AUTO came to until it is thrown,
## and ON or OFF for good once it has been.
enum { OFF, AUTO, ON }

## The modes by the name they are saved under.
const MODE_KEYS := ["off", "auto", "on"]

## The smallest change in how hard a key is held that is worth sending. A thumb
## on glass is never still, and an event a frame per pixel of tremor is noise.
const STEP := 0.02

## Which stick the pad aims with. The right one, because that is the one the
## player already aims with on a gamepad — see `Hands`, at the head of the
## player's input line, which needs no line changed for any of this.
const AIM_AXES := [JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]

static var mode: int = AUTO

## Every action the pad is holding down and how hard, so it never lets go of one
## it never pressed, always lets go of all of them when it leaves the screen,
## and can lean on one harder without letting go of it first.
static var _held: Dictionary = {}
static var _aim: Vector2 = Vector2.ZERO
static var _up: bool = false
## Whether this is a machine you touch: -1 until it has been asked once.
static var _is_touch: int = -1

## Whether the console should be on the screen at all. The pad asks every frame;
## whether there is anything to play with is its own question.
static func wanted() -> bool:
	match mode:
		ON:
			return true
		AUTO:
			return touch_device()
		_:
			return false

## Whether this machine is one you touch. The two exported mobile platforms
## answer yes whatever the hardware reports, since a phone is a phone even while
## Godot is still working out what it is attached to.
##
## Asked once and kept: `wanted()` is read every frame by the pad and again by
## the pointer, and neither the platform nor the glass in front of it changes
## while the game is running.
static func touch_device() -> bool:
	if _is_touch < 0:
		_is_touch = 1 if (DisplayServer.is_touchscreen_available()
			or OS.get_name() in ["Android", "iOS"]) else 0
	return _is_touch == 1

static func set_mode(m: int) -> void:
	mode = clampi(m, OFF, ON)
	save()

## --- the pad coming and going ----------------------------------------------

## The pad has arrived on the screen, or left it.
##
## While it is up the mouse is set aside — see `Controls.set_mouse_aside`, which
## carries why — and when it goes, everything it was holding is let go of.
## Called by the pad itself, so the one thing that knows whether it is on screen
## is the thing that is.
static func set_up(showing: bool) -> void:
	if showing == _up:
		return
	_up = showing
	Controls.set_mouse_aside(showing)
	if not showing:
		release_all()

static func up() -> bool:
	return _up

## --- what a key does --------------------------------------------------------

## Holds `action` down. `strength` is how hard, for an action that is read as
## one side of an axis: the game reads movement through `Input.get_axis`, which
## is the strength of the two actions either side of it. The pad's own movement
## stick does not lean — it holds its keys all the way or not at all, and how
## far it is dragged picks which of them (`TouchPad._drive`) — so the strength
## is for whatever does. A press already held is leant on rather than pressed
## again — the same event with a new strength, which moves the axis without
## reporting a second press to anything watching for one.
static func press(action: String, strength: float = 1.0) -> void:
	var want := clampf(strength, 0.0, 1.0)
	if _held.has(action) and absf(float(_held[action]) - want) < STEP:
		return
	_held[action] = want
	_send(action, true, want)

static func release(action: String) -> void:
	if not _held.has(action):
		return
	_held.erase(action)
	_send(action, false)

static func holding(action: String) -> bool:
	return _held.has(action)

## How hard `action` is being held, or 0 where it is not.
static func held_strength(action: String) -> float:
	return float(_held.get(action, 0.0))

## Let go of everything, and stop aiming. A thumb lifted by the game rather than
## by its owner — the pad hidden, the screen changed — must not leave an action
## pressed behind it, or the player walks into the next screen still running.
static func release_all() -> void:
	for action in _held.keys():
		_send(action, false)
	_held.clear()
	aim(Vector2.ZERO)

## Where the player is pointing, as a stick rather than a place: the pad has no
## pointer to put anywhere, and the game already knows how to aim from a stick.
## Only sent when it changes, so a still thumb is silent.
static func aim(at: Vector2) -> void:
	if at.is_equal_approx(_aim):
		return
	_aim = at
	for i in AIM_AXES.size():
		var m := InputEventJoypadMotion.new()
		m.device = 0
		m.axis = AIM_AXES[i]
		m.axis_value = at.x if i == 0 else at.y
		Input.parse_input_event(m)

static func aiming() -> Vector2:
	return _aim

static func _send(action: String, pressed: bool, strength: float = 1.0) -> void:
	if not InputMap.has_action(action):
		return
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	e.strength = strength if pressed else 0.0
	Input.parse_input_event(e)

## --- keeping the setting ----------------------------------------------------

static func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"mode": MODE_KEYS[clampi(mode, OFF, ON)]}))
	f.close()

static func load_saved() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	# Saved by name rather than by number, so the modes can be reordered without
	# a file written by an older build putting the game into the wrong one.
	var key := String((parsed as Dictionary).get("mode", ""))
	if MODE_KEYS.has(key):
		mode = MODE_KEYS.find(key)
