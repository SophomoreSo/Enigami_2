class_name BenchDrawer
extends Control

## A drawer of the bench's (`Sandbox`), on one edge of the screen: the kit's
## pixel buttons in a frame, pulled out by the tab on its inner edge and pushed
## back in by it. It starts in, so the bench opens on the fight. The bench's
## own tools are one, on the left (`SandboxPanel`); the sample skills are the
## other, on the right (`SampleSkillsPanel`). What goes in one is its own
## business (`_fill`); everything about being a drawer is here.
##
## While a drawer is out the bench holds the player still, the way any window
## over the fight does. Its buttons are pressed with the mouse the player would
## otherwise be aiming with, and on the console a thumb there would otherwise be
## the movement stick, whose zone is the whole left of the screen.
##
## In mobile mode (`UiKit.mobile`) a drawer is a thumb's: its buttons stand
## THUMB_PLATE tall with their words at a thumb's size, and the tab it is pulled
## by is THUMB_TAB — at a desk's it is 3mm of a phone's glass wide, with the
## movement stick's zone all round it.
##
## It steps aside with the HUD while somebody talks to the player (`Hud.talking`):
## the tab is the HUD's kind of thing, and a tab that answered then would pull
## the drawer out over the conversation, which nothing would move on until the
## drawer went back in.
##
## The tab is hit-tested here in `_input` rather than being a Button, because it
## has to answer while the drawer is in and the player is aiming: the game points
## with the crosshair then, and a Button hears only the hidden system pointer,
## which is somewhere else at any speed but 1.0; and the console takes a press
## on the left of the screen for its stick before any Control is asked — but
## after this, which is later in the tree.
##
## Drawn in UiKit's pixel look: the buttons are the kit's pixel ones, and
## everything drawn here goes through `PixelDraw`.

## The room inside the frame, and between buttons.
const PAD := 8.0
const GAP := 4
## The tab a drawer is pulled by, and the chevron on it, which points the way a
## press will send the drawer.
const TAB := Vector2(32, 64)
## The same for a thumb, and how tall a button in a drawer stands for one.
const THUMB_TAB := Vector2(64, 96)
const THUMB_PLATE := 64.0
const CHEVRON := ["#....", ".#...", "..#..", "...#.", "....#", "...#.", "..#..", ".#...", "#...."]
## Seconds to slide all the way.
const SLIDE := 0.16

const FILL := Color(0.07, 0.08, 0.11, 0.85)
const EDGE := Color(0.35, 0.5, 0.65, 0.6)

var sandbox: Sandbox
var _px := PixelDraw.new(self)
## The buttons. Everything else here is drawn every frame and so is already in
## whatever language is on; these are words written once, and a switch has to
## build them again.
var _grid: GridContainer = null
## Whether the drawer is out, and how far it has got there: 0 in, 1 out.
var _out: bool = false
var _slide: float = 0.0
var _tab_hover: bool = false
## Whether the buttons were built for a thumb. They are built again when the
## mode is thrown, which the pause menu's controls page does over the bench.
var _thumb: bool = false
## How much of it is on the screen: 1, or 0 once it has stepped aside for a
## conversation, in the HUD's time (`Hud.STEP_ASIDE`).
var shown: float = 1.0

## --- what a drawer says about itself ------------------------------------------
## Its top edge, and its tab's.
func _top() -> float:
	return 0.0

## Whether it comes in from the right edge rather than the left.
func _on_right() -> bool:
	return false

## How many buttons to a row.
func _columns() -> int:
	return 1

## Which drawer it is, to the bench, which holds the player still while any is
## out (`Sandbox.set_tools_open`).
func _drawer_name() -> String:
	return ""

## Puts its buttons in `_grid`, with `_add`.
func _fill() -> void:
	pass

## Anything drawn beside it every frame, before the drawer itself.
func _draw_more() -> void:
	pass

## --- being a drawer -------------------------------------------------------------
func _ready() -> void:
	UiKit.fill_screen(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_buttons()
	Loc.language_changed.connect(func(_l: String) -> void: _build_buttons())

func _build_buttons() -> void:
	_thumb = UiKit.mobile()
	if _grid != null and is_instance_valid(_grid):
		remove_child(_grid)
		_grid.queue_free()
	_grid = GridContainer.new()
	_grid.columns = _columns()
	_grid.add_theme_constant_override("h_separation", GAP)
	_grid.add_theme_constant_override("v_separation", GAP)
	add_child(_grid)
	_fill()
	# Every column as wide as the widest button, so the drawer is a block and
	# not a ragged edge.
	var widest := 0.0
	for b in _grid.get_children():
		widest = maxf(widest, (b as Control).get_combined_minimum_size().x)
	for b in _grid.get_children():
		(b as Control).custom_minimum_size.x = widest
	_place()

func _add(text: String, accent: Color, press: Callable) -> Button:
	var b := UiKit.overlay_button(text, accent, true)
	if _thumb:
		b.custom_minimum_size.y = THUMB_PLATE
		# The kit's thumb buttons pass a press on, for a page to be dragged by.
		# There is no page here: the drawer lies over the game, and a press on
		# one of its buttons is that button's and nobody else's.
		b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.pressed.connect(press)
	_grid.add_child(b)
	return b

## Pulls the drawer out or pushes it back in. The bench holds the player still
## for as long as it is out.
func set_out(out: bool) -> void:
	if out == _out:
		return
	_out = out
	sandbox.set_tools_open(out, _drawer_name())
	Audio.play("ui")

func is_out() -> bool:
	return _out

## The drawer where it stands this frame: all of its width off its edge when it
## is in, none of it when it is out, and on the grid in between.
func drawer_rect() -> Rect2:
	var px := PixelDraw.PX
	var extent := ((_grid.get_combined_minimum_size() + Vector2.ONE * PAD * 2.0) / px).ceil() * px
	var shift := floorf(-extent.x * (1.0 - smoothstep(0.0, 1.0, _slide)) / px) * px
	if _on_right():
		return Rect2(Vector2(size.x - extent.x - shift, _top()), extent)
	return Rect2(Vector2(shift, _top()), extent)

## On the drawer's inner edge, sharing its border, so it comes and goes with it
## and is all that is left on the screen once the drawer is in.
func tab_rect() -> Rect2:
	var tab := THUMB_TAB if UiKit.mobile() else TAB
	var d := drawer_rect()
	if _on_right():
		return Rect2(Vector2(d.position.x - tab.x + PixelDraw.PX, _top()), tab)
	return Rect2(Vector2(d.end.x - PixelDraw.PX, _top()), tab)

## Off the screen with the drawer while it is in, where nothing can press it
## and, since no button here takes focus, no key can reach it either.
func _place() -> void:
	_grid.position = drawer_rect().position + Vector2.ONE * PAD

func _process(delta: float) -> void:
	UiKit.sync_screen(self)
	if _thumb != UiKit.mobile():
		_build_buttons()
	_slide = move_toward(_slide, 1.0 if _out else 0.0, delta / SLIDE)
	_place()
	# The tab is the person's to press, so it lights under their pointer: the
	# crosshair while their hand is moving it, the system pointer otherwise —
	# a window, or the computer having the crosshair (`Pointer.hand_point`).
	_tab_hover = tab_rect().has_point(Pointer.hand_point())
	shown = move_toward(shown, 0.0 if talking() else 1.0, delta / Hud.STEP_ASIDE)
	modulate.a = shown
	queue_redraw()

## Whether somebody is talking to the bench's player in the box — see `Hud.talking`.
func talking() -> bool:
	return sandbox != null and is_instance_valid(sandbox) and sandbox.player != null \
		and is_instance_valid(sandbox.player) and sandbox.player.talk_locked

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or talking():
		return
	var at := Vector2.INF
	var press := false
	var click := event as InputEventMouseButton
	var touch := event as InputEventScreenTouch
	if click != null and click.button_index == MOUSE_BUTTON_LEFT:
		# While the game is pointing, a click lands where the crosshair is, not
		# where the hidden system pointer is.
		at = Pointer.point if Input.mouse_mode == Input.MOUSE_MODE_HIDDEN else click.position
		# The system hands a touch over as a click as well: the touch is the press.
		press = click.pressed and click.device != InputEvent.DEVICE_ID_EMULATION
	elif touch != null:
		at = touch.position
		press = touch.pressed
	else:
		return
	if not tab_rect().has_point(at):
		return
	get_viewport().set_input_as_handled()
	if press:
		set_out(not _out)

## ESC puts the drawer away, the way it closes every other window here, before
## it would pause the bench behind it.
func _unhandled_input(event: InputEvent) -> void:
	if _out and is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		set_out(false)
		get_viewport().set_input_as_handled()

func _draw() -> void:
	if sandbox == null or not is_instance_valid(sandbox) or shown <= 0.0:
		return
	_draw_more()
	var d := drawer_rect()
	if d.end.x > 0.0 and d.position.x < size.x:
		_px.rect(d, FILL)
		_px.frame(d, EDGE)
	var t := tab_rect()
	_px.rect(t, Color(0.12, 0.16, 0.21, 0.9) if _tab_hover else FILL)
	_px.frame(t, UiKit.ACCENT if _tab_hover else EDGE)
	# The chevron points the way a press sends the drawer: in towards its own
	# edge while it is out, and out across the screen while it is in.
	var inward := _out != _on_right()
	_px.icon_centered(t.get_center(), PixelDraw.turn(CHEVRON, 2) if inward else CHEVRON,
		Color.WHITE if _tab_hover else UiKit.TEXT, 2 if UiKit.mobile() else 1)
