class_name LightingTestHud
extends Control

## The lighting test's read-outs (`LightingTestView`): a sign over each stretch
## of the ground saying what light stands in it, what the keys have set, in
## the top right, with how many lights are on the screen and how many of them
## throw shadows, and the keys along the foot. The name of the test across
## the middle for the first few seconds.

const INK := Color(0.94, 0.93, 0.98)
const DIM := Color(0.62, 0.62, 0.72)
const WARM := Color(1.0, 0.8, 0.45)
const COOL := Color(0.75, 0.9, 1.0)
const SHADOW := Color(0.02, 0.01, 0.05, 0.9)
const BIG := PixelDraw.SIZE * 2
const MARGIN := 24.0
## How long the name of the test stays up once the screen opens.
const TITLE_TIME := 4.0
## How far down the map the signs stand, in cells from its top: up the floor
## from the lights.
const SIGN_ROW := 3.5

var view: LightingTestView
var _px := PixelDraw.new(self)
var _t := 0.0

func _ready() -> void:
	UiKit.fill_screen(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	UiKit.sync_screen(self)
	_t += delta
	queue_redraw()

func _draw() -> void:
	if view == null or not is_instance_valid(view):
		return
	var vp := get_viewport_rect().size
	_draw_signs()
	_draw_settings(vp)
	if not UiKit.mobile():
		var keys := Loc.t("hud.light.keys")
		_text(Vector2(vp.x - MARGIN - PixelDraw.ink_width(keys), vp.y - 22.0), keys, DIM)
	if _t < TITLE_TIME:
		var a := clampf((TITLE_TIME - _t) / 0.6, 0.0, 1.0)
		# Over the signs, which hang over the rails.
		var y := vp.y * 0.14
		_centered(y, Loc.t("hud.light.title"), Color(WARM, a), vp.x, BIG)
		_centered(y + 30.0, Loc.t("hud.light.subtitle"), Color(INK, a), vp.x)

func _text(at: Vector2, s: String, col: Color, font_size: int = PixelDraw.SIZE) -> void:
	_px.text(at + Vector2(2, 2), s, Color(SHADOW, SHADOW.a * col.a), -1.0, font_size)
	_px.text(at, s, col, -1.0, font_size)

func _centered(y: float, s: String, col: Color, width: float, font_size: int = PixelDraw.SIZE) -> void:
	_text(Vector2((width - PixelDraw.ink_width(s, font_size)) * 0.5, y), s, col, font_size)

## Over each stretch of the ground, where the camera has it on the screen.
func _draw_signs() -> void:
	var onto := get_viewport().get_canvas_transform()
	for zone: Dictionary in LightingTest.ZONES:
		var what := String(zone["what"])
		var middle := (float(zone["from"]) + float(zone["to"]) + 1.0) * 0.5 * Room.CELL
		var at := onto * Vector2(middle, SIGN_ROW * Room.CELL)
		var says := Loc.t("hud.light.%s" % what)
		var col := COOL if what == "spot" else WARM
		_text(Vector2(roundf(at.x - PixelDraw.ink_width(says) * 0.5), roundf(at.y)), says, col)

## What the keys have set, one line each, and the count of the lights.
func _draw_settings(vp: Vector2) -> void:
	var what := String(LightingTestView.HELD[view.held])
	var held := Loc.t("hud.light.held.%s" % what)
	var lines := [
		Loc.t("hud.light.time", [Loc.t("hud.light.times.%s" % String(LightingTestView.TIMES[view.time]))]),
		Loc.t("hud.light.crosshair", [held]),
		Loc.t("hud.light.count", [view.pixels.lighting.lamps_lit, view.pixels.lighting.lamps_shadowed]),
	]
	for i in lines.size():
		var line := String(lines[i])
		_text(Vector2(vp.x - MARGIN - PixelDraw.ink_width(line), 34.0 + 24.0 * i), line,
			DIM if i == lines.size() - 1 else INK)
