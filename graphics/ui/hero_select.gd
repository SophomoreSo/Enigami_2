class_name HeroSelect
extends Control

## Who the player is: the hero they play as, chosen the way Metal Slug has it
## chosen. Sat down on a bench, the screen comes up over the world: SELECT YOUR
## CHARACTER along the top, the heroes in a row under it, a card each with
## their portrait on it in their own colour and their name under it, the one
## the cursor is on lit and the one played as marked; left and right, or the
## pointer, move the cursor, interact or jump takes the hero it is on
## (`picked`), and ESC puts the screen away with nothing changed (`closed`), as
## standing up does. Which heroes there are and what each looks like is the
## content database's (`Heroes`); who is played as is the profile's
## (`GameState.hero`); the shell puts the screen up and takes it down
## (`app/game.gd`). What each hero can do is to come: for now a hero is a face
## and a name.
##
## Drawn in UiKit's pixel look. A thumb works it as a pointer does: a touch on
## a card moves the cursor to it, and a second takes it.

signal picked(id: String)
signal closed()

const CARD := Vector2(208.0, 312.0)
const CARD_GAP := 24.0
const PORTRAIT_H := 216.0
const VEIL := Color(0.02, 0.03, 0.05, 0.82)
const PLATE := Color(0.08, 0.09, 0.12)
const INK := Color(0.92, 0.95, 1.0)
const DIM := Color(0.5, 0.56, 0.64)
## How fast the lit card's edge blinks, in blinks a second.
const BLINK := 2.2

## The roster, in the order the cards stand.
var ids: PackedStringArray = PackedStringArray()
## Which card the cursor is on.
var cursor: int = 0
var _t := 0.0
var _px: PixelDraw

func _ready() -> void:
	UiKit.fill_screen(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_px = PixelDraw.new(self)
	visible = false

func _process(delta: float) -> void:
	UiKit.sync_screen(self)
	_t += delta
	queue_redraw()

## Up, with the cursor on the hero played as.
func open() -> void:
	ids = Heroes.ids()
	cursor = maxi(ids.find(GameState.hero), 0)
	visible = true
	UiKit.sync_screen(self)
	queue_redraw()

## Handled here rather than in `_gui_input` so the keys work whether or not
## the screen holds focus, and marked handled so nothing under it — the body
## on the bench, which any key would stand up — sees the press.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		_move(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		_move(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") or event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		_take()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var over := card_at((event as InputEventMouseMotion).position)
		if over >= 0 and over != cursor:
			cursor = over
			Audio.play("ui")
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var over := card_at((event as InputEventMouseButton).position)
		if over >= 0:
			if over == cursor:
				_take()
			else:
				cursor = over
				Audio.play("ui")
			get_viewport().set_input_as_handled()

func _move(by: int) -> void:
	if ids.is_empty():
		return
	cursor = posmod(cursor + by, ids.size())
	Audio.play("ui")

func _take() -> void:
	if ids.is_empty():
		return
	picked.emit(ids[cursor])

## Where the card `i` stands: the row of them in the middle of the screen.
func card_rect(i: int) -> Rect2:
	var n := maxi(ids.size(), 1)
	var across := float(n) * CARD.x + float(n - 1) * CARD_GAP
	var left := floorf((size.x - across) * 0.5 / UiKit.PIXEL) * UiKit.PIXEL
	var top := floorf((size.y - CARD.y) * 0.5 / UiKit.PIXEL) * UiKit.PIXEL + 12.0
	return Rect2(Vector2(left + float(i) * (CARD.x + CARD_GAP), top), CARD)

## The card under `at`, or -1.
func card_at(at: Vector2) -> int:
	for i in ids.size():
		if card_rect(i).has_point(at):
			return i
	return -1

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), VEIL)
	if ids.is_empty():
		return
	var first := card_rect(0)
	var title := Loc.t("hud.heroes.title")
	var title_size := Loc.text_size(title, 32)
	_px.text_centered(Vector2(0.0, first.position.y - 36.0), title, INK, size.x, title_size)
	for i in ids.size():
		_draw_card(i, card_rect(i))
	# What the keys do, along the foot.
	var foot := "%s  %s      ESC  %s" % [Controls.short_label_for("interact"),
		Loc.t("hud.heroes.confirm"), Loc.t("hud.heroes.back")]
	_px.text_centered(Vector2(0.0, first.end.y + 44.0), foot, DIM, size.x)

## The colour `id` wears on their card: the roster's, read as a colour here and
## not in the rules, which name no colour (module_test).
static func color_of(id: String) -> Color:
	return Color.html(Heroes.color_html(id))

## A hero's card: their colour's plate, their portrait standing on it, their
## name under it; lit and blinking under the cursor, and marked as the one
## played as.
func _draw_card(i: int, r: Rect2) -> void:
	var id := ids[i]
	var col := color_of(id)
	var on := i == cursor
	var lit := on and fmod(_t * BLINK, 1.0) < 0.5
	_px.rect(r, PLATE)
	_px.rect(r, Color(col.r, col.g, col.b, 0.3 if on else 0.1))
	var edge := col.lightened(0.5) if lit else (col if on else Color(col.r, col.g, col.b, 0.45))
	_px.frame(r, edge)
	if on:
		_px.frame(r.grow(-UiKit.PIXEL), edge)
	var portrait := Rect2(r.position + Vector2(8.0, 8.0), Vector2(r.size.x - 16.0, PORTRAIT_H))
	_px.rect(portrait, Color(0.03, 0.04, 0.06))
	_draw_portrait(portrait, Style.hero_portrait_art(id), on, col)
	# The name, in two lines where it is wider than the card.
	var named := Heroes.name_for(id)
	var lines := PixelDraw.wrap(named, r.size.x - 16.0, 2)
	var base := portrait.end.y + 28.0
	for k in lines.size():
		_px.text_centered(Vector2(r.position.x, base + PixelDraw.LINE * float(k)), lines[k],
			INK if on else DIM, r.size.x)
	if id == GameState.hero:
		var tag := Loc.t("hud.heroes.playing")
		_px.text_centered(Vector2(r.position.x, r.end.y - 12.0), tag, col, r.size.x)

## The hero's portrait: their character's idle frame, at the biggest whole
## scale that fits, standing on the portrait's floor — moving on the card the
## cursor is on, still on the rest. A character the atlas does not have is
## drawn as the fallback.
func _draw_portrait(frame: Rect2, art: String, moving: bool, col: Color) -> void:
	if not Sprites.has_character(art):
		art = Style.NPC_FALLBACK_ART
	var frames := Sprites.resolved_frames(art)
	if frames == null or frames.get_frame_count("idle") == 0:
		return
	var count := frames.get_frame_count("idle")
	var tex := frames.get_frame_texture("idle", (int(_t * 5.0) % count) if moving else 0)
	var src := Sprites.art_rect(art)
	var factor := floorf(minf((frame.size.x - 24.0) / src.size.x, (frame.size.y - 24.0) / src.size.y))
	if factor < 1.0:
		return
	var dst_size := src.size * factor
	var dst := Rect2(frame.position + Vector2(roundf((frame.size.x - dst_size.x) * 0.5),
		frame.size.y - 12.0 - dst_size.y), dst_size)
	# A glow of their colour on the floor under them.
	_px.rect(Rect2(frame.position.x + 12.0, frame.end.y - 12.0, frame.size.x - 24.0, UiKit.PIXEL),
		Color(col.r, col.g, col.b, 0.6))
	draw_texture_rect_region(tex, dst, src, Color.WHITE if moving else Color(0.72, 0.74, 0.8))
