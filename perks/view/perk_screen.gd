class_name PerkScreen
extends Control

## The perks as a page of the screen the weapons' graphs, the map and the
## monster dictionary are pages of, a tab along its top (`ScreenTabs`): the back
## arrow in the corner puts the screen away, and another page's tab puts that
## page up in this one's place (`page_picked`). ESC puts it away too.
##
## Under the top, a window on the screen's veil, the one the other pages lie
## on: the heading and the gold there is to spend, and the perks a row each
## (`PerkPage`), bought here as at the hideout's perk station. The rows scroll
## when a thumb's run longer than the screen. Whoever puts the screen up says
## which pages it has (`pages`): a raid, the hideout's workbench and the
## bench, the only screens the perks are on, have all four.

signal closed()
## A tab along the screen's top was pressed, for a page other than this one:
## whoever holds the screen puts that page up in its place.
signal page_picked(id: String)

## The pages of the screen this is a page of, in the order their tabs stand.
var pages: Array = ScreenTabs.PAGES_WITH_PERKS.duplicate()

## How wide the window stands, at a desk and for a thumb, short of the screen's
## own width; and its padding, and the row its heading and gold stand in.
const W := 620.0
const THUMB_W := 760.0
const PAD := 24.0
const HEADER_H := 52.0

const BG := Color(0.07, 0.08, 0.11, 0.97)
const EDGE := Color(0.35, 0.55, 0.75, 0.85)

## What along the top is under the pointer: the back arrow, or a page's tab.
var _back_hot: bool = false
var _page_hot: String = ""
var _px := PixelDraw.new(self)
var _scroll: ScrollContainer
var _page: PerkPage = null
## Where the rows were last laid, so they are moved only when the window is.
var _laid := Rect2()

func _ready() -> void:
	UiKit.fill_screen(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_fill()
	set_process(true)

## The rows, built again: a step bought changes the one it was bought on and
## the buttons of every other, since the gold went.
func _fill() -> void:
	if _page != null and is_instance_valid(_page):
		_scroll.remove_child(_page)
		_page.queue_free()
	_page = PerkPage.new()
	_page.bought.connect(func(_id: String) -> void: _fill.call_deferred())
	_page.toggled.connect(func(_id: String) -> void: _fill.call_deferred())
	_scroll.add_child(_page)
	_laid = Rect2()

func _process(_delta: float) -> void:
	UiKit.sync_screen(self)
	var win := window_rect()
	if win != _laid:
		_laid = win
		_scroll.position = win.position + Vector2(PAD, HEADER_H)
		_scroll.size = win.size - Vector2(PAD * 2.0, HEADER_H + PAD)
	queue_redraw()

## The window: under the top, as wide as `W` (a thumb's `THUMB_W`) or the screen
## allows, and as tall as the rows need, as far as the screen goes — centred in
## what is left under the tabs.
func window_rect() -> Rect2:
	var thumb := UiKit.mobile()
	var screen := get_viewport_rect().size
	var top := ScreenTabs.back_rect(thumb).end.y + 12.0
	var w := minf(THUMB_W if thumb else W, screen.x - 32.0)
	var rows := _page.get_combined_minimum_size().y if _page != null and is_instance_valid(_page) else 0.0
	var h := minf(HEADER_H + rows + PAD, screen.y - top - 16.0)
	var y := maxf(top, top + (screen.y - top - 16.0 - h) * 0.5)
	return Rect2(_px.snap(Vector2((screen.x - w) * 0.5, y)), Vector2(w, h))

## Handled here rather than in `_gui_input` so the key works whether or not the
## page holds focus, and marked handled so nothing behind it opens the pause
## menu on the same press.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()

## The top answers the pointer, and a thumb, which the system hands over as a
## click. The rows are buttons of their own and answer for themselves.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_point(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_point(event.position)
		if event.pressed:
			_press()
		elif event.device == InputEvent.DEVICE_ID_EMULATION:
			# A thumb that has lifted is pointing at nothing.
			_point(Vector2(-1, -1))
		accept_event()

func _point(pos: Vector2) -> void:
	_back_hot = ScreenTabs.back_rect(UiKit.mobile()).has_point(pos)
	_page_hot = ScreenTabs.page_at(pages, pos, UiKit.mobile())

## Lets go of what it lit before it goes: it is not under the pointer any more
## by the time the screen comes back.
func _press() -> void:
	if _back_hot:
		_back_hot = false
		Audio.play("ui")
		closed.emit()
	elif _page_hot != "":
		var id := _page_hot
		_page_hot = ""
		if id != ScreenTabs.PERKS:
			page_picked.emit(id)

func _draw() -> void:
	var win := window_rect()
	_px.rect(Rect2(Vector2.ZERO, get_viewport_rect().size), ScreenTabs.VEIL)
	_px.rect(win, BG)
	_px.frame(win, EDGE)
	var base := win.position.y + PAD + 10.0
	_px.text(Vector2(win.position.x + PAD, base), ScreenTabs.title(ScreenTabs.PERKS), UiKit.TEXT)
	# On the bench nothing is spent, so in the gold's place it says the perks
	# are toggled there.
	var gold := Loc.t("perks.page.trial") if Perks.trial else Loc.t("hideout.scrap", [GameState.scrap])
	_px.text(Vector2(win.end.x - PAD - PixelDraw.ink_width(gold), base), gold,
		UiKit.GOOD if Perks.trial else UiKit.WARN)
	ScreenTabs.draw(_px, pages, ScreenTabs.PERKS, _back_hot, _page_hot, UiKit.mobile())
