extends Node

## What the game looks like on the machine it is running on: whether the window
## fills the screen, whether an impact is allowed to move the camera, and
## whether the assembly screen moves its hints: the part under the pointer, and
## the arrow its flow leaves by.
##
## Its own file beside the language, the key bindings and the pointer speed, and
## for the same reason: these are properties of the desk the game is sitting on,
## not of the profile being played on it. Throwing a save away does not put the
## window back or start the screen shaking again.

## Where the settings are kept.
const PATH := "user://enigami_video.json"

## Whether the window fills the screen.
##
## Off to start with. Taking the whole display is the sort of thing a game
## should be asked to do rather than do on the way in, and a window is the only
## state a player can get out of without finding this menu again.
var fullscreen: bool = false

## Whether an impact moves the camera. `Fx.shake` is what reads it.
##
## Off to start with, which is the answer to a question this setting exists to
## ask: shake is something a fair number of people cannot watch for long, and a
## comfort setting that has to be found before the game is playable defaults the
## wrong way round. Nothing about the fight changes either way — see `Fx`.
var screen_shake: bool = false

## Whether the assembly screen moves its hints: the part under the pointer,
## through its film (`Style.COMPONENT_MOTION`), every other part standing
## still on its icon at rest either way; and the way out, bobbing out of the
## board and back at the end a flow has to get to. `SkillEditor` is what
## reads it.
##
## On to start with: a part pointed at shows what it does by doing it, and the
## way out shows where a board's flow has to go. Off, both stand still.
var icon_motion: bool = true

func _ready() -> void:
	_load()
	apply()

func set_fullscreen(on: bool) -> void:
	if fullscreen == on:
		return
	fullscreen = on
	apply()
	_save()

func set_screen_shake(on: bool) -> void:
	if screen_shake == on:
		return
	screen_shake = on
	_save()

func set_icon_motion(on: bool) -> void:
	if icon_motion == on:
		return
	icon_motion = on
	_save()

## How long the window is kept being asked, and how often. The mode is a
## request, not an assignment: macOS animates the change over about a third of
## a second and drops anything asked while an earlier one is still settling. Two
## presses inside that window left the screen full with the setting reading
## WINDOWED — recoverable, since pressing FULL SCREEN and then WINDOWED again
## asks from a standstill, but two presses to undo one is not an answer.
##
## So the ask is repeated on a clock until the window is in the mode wanted and
## stays there. Seconds rather than frames because what is being outlasted is an
## animation, and the machine this runs on draws as many frames in that time as
## it likes. It is not stopped early by the mode looking right: mid-transition
## it reports the mode it is heading for, and an ask that stopped there would
## stop just before the one that would have taken.
const SETTLE_FOR := 2.0
const SETTLE_EVERY := 0.3

var _settle_left := 0.0
var _settle_next := 0.0

## Puts the window into the mode the setting asks for, and keeps asking for
## `SETTLE_FOR`. A headless run has no window to put anywhere, which is not a
## failure — it is how the tests that need no renderer are run.
func apply() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_settle_left = SETTLE_FOR
	_settle_next = 0.0
	_ask()

func _process(delta: float) -> void:
	if _settle_left <= 0.0:
		return
	_settle_left -= delta
	_settle_next -= delta
	if _settle_next <= 0.0:
		_ask()

## Asks once, and only when the window is not already in the mode wanted: the
## window is the display server's to report, and setting the mode to the one it
## is already in is a transition to where it already was.
func _ask() -> void:
	_settle_next = SETTLE_EVERY
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen \
		else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)

## --- the file ---------------------------------------------------------------

func _load() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not (parsed is Dictionary):
		return
	var d: Dictionary = parsed
	fullscreen = bool(d.get("fullscreen", fullscreen))
	screen_shake = bool(d.get("screen_shake", screen_shake))
	icon_motion = bool(d.get("icon_motion", icon_motion))

func _save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"fullscreen": fullscreen, "screen_shake": screen_shake,
		"icon_motion": icon_motion}))
	f.close()
