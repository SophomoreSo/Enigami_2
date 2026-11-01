class_name WireHud
extends Control

## The wire test's read-outs, along the top and the bottom of the screen so
## the ground between stays clear: the body's health; what is left to do, and
## how many of the generators are crashed; the clock; the vision key, and
## whether the sight is on; the keys; and a line across the middle when an
## attempt begins or ends.
##
## The ground is wider than the screen, so under what is left to do there is
## the whole of it, small: its stone, the gates — lit while they are up — the
## generators, green while they run and red once crashed, the vault's core,
## the body, and the stretch the screen is showing. The wires are on it only
## while the sight is on: seeing them is the sight's (`Sight`).
##
## Under it all, the vision key: what is being seen, and what the next press
## of it does.

const INK := Color(0.94, 0.93, 0.98)
const DIM := Color(0.62, 0.58, 0.74)
const GOLD := Color(1.0, 0.78, 0.32)
const SPARK := Color(1.0, 0.9, 0.45)
const CALM := Color(0.48, 0.95, 0.62)
const ALARM := Color(1.0, 0.3, 0.32)
const SHADOW := Color(0.02, 0.01, 0.05, 0.9)
const GROUND := Color(0.0, 0.0, 0.0, 0.65)
const EDGE := Color(0.5, 0.45, 0.72)
const BIG := PixelDraw.SIZE * 2
const MARGIN := 24.0
const BAR_W := 240.0
## How long the name of the test stays up once the screen opens.
const TITLE_TIME := 4.0
## How long the line saying the ground was set again stays up.
const AGAIN_TIME := 0.8
## The whole ground, small: one of its cells to this many pixels.
const MAP_CELL := 4.0
const MAP_TOP := 64.0
const MAP_ROCK := Color(0.42, 0.5, 0.52, 0.55)
const MAP_GROUND := Color(0.02, 0.03, 0.05, 0.6)
const BODY := Color(0.55, 0.92, 1.0)
const CORE := Color(0.36, 0.62, 1.0)
const GATE_UP := Color(1.0, 0.3, 0.42)
const GATE_DOWN := Color(0.3, 0.28, 0.34)
const WIRE := Color(1.0, 0.86, 0.32, 0.8)
const WIRE_DEAD := Color(0.45, 0.45, 0.5, 0.8)

var screen: WireTest
var _px := PixelDraw.new(self)
var _banner: String = ""
var _banner_color: Color = GOLD
var _banner_time: float = 0.0
var _again_time: float = 0.0

func _ready() -> void:
	UiKit.fill_screen(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_reached(seconds: float) -> void:
	_banner = Loc.t("hud.wire.reached", [_clock(seconds)])
	_banner_color = GOLD
	_banner_time = WireTest.RESET_DELAY

func show_fell() -> void:
	_banner = Loc.t("hud.wire.fell")
	_banner_color = ALARM
	_banner_time = WireTest.RESET_DELAY

func again() -> void:
	_banner_time = 0.0
	_again_time = AGAIN_TIME

func _process(delta: float) -> void:
	UiKit.sync_screen(self)
	_banner_time = maxf(0.0, _banner_time - delta)
	_again_time = maxf(0.0, _again_time - delta)
	queue_redraw()

func _draw() -> void:
	if screen == null or not is_instance_valid(screen):
		return
	var vp := get_viewport_rect().size
	var p := screen.player
	if p != null and is_instance_valid(p):
		_draw_body(p)
	_draw_goal(vp)
	_draw_map(vp)
	_draw_clock(vp)
	_draw_sight(vp)
	var keys := Loc.t("hud.wire.keys")
	_text(Vector2(vp.x - MARGIN - PixelDraw.ink_width(keys), vp.y - 22.0), keys, DIM)
	_draw_banners(vp)

func _text(at: Vector2, s: String, col: Color, font_size: int = PixelDraw.SIZE) -> void:
	_px.text(at + Vector2(2, 2), s, Color(SHADOW, SHADOW.a * col.a), -1.0, font_size)
	_px.text(at, s, col, -1.0, font_size)

func _centered(y: float, s: String, col: Color, width: float, font_size: int = PixelDraw.SIZE) -> void:
	_text(Vector2((width - PixelDraw.ink_width(s, font_size)) * 0.5, y), s, col, font_size)

## The body's health.
func _draw_body(p: Player) -> void:
	var bar := Rect2(MARGIN, 18.0, BAR_W, 18.0)
	_px.bar(bar, p.health_ratio(), Color(0.9, 0.35, 0.38), GROUND, EDGE)
	_px.text(bar.position + Vector2(8, 15), Loc.t("hud.wire.body", [int(p.health), int(p.max_health)]),
		Color(1, 1, 1, 0.9))

## What is left to do — the vault's gate to bring down, or the vault to get
## into — and under it how many of the generators are crashed.
func _draw_goal(vp: Vector2) -> void:
	if screen.over:
		return
	if screen.vault_shut():
		_centered(18.0, Loc.t("hud.wire.find"), SPARK, vp.x)
	else:
		_centered(18.0, Loc.t("hud.wire.open"), GOLD, vp.x)
	var down := Loc.t("hud.wire.crashed", [screen.crashed(), screen.room.generators.size()])
	_centered(42.0, down, DIM, vp.x)

## The ground, small, under what is left to do.
func _draw_map(vp: Vector2) -> void:
	var room := screen.room
	if room == null or not is_instance_valid(room):
		return
	var size_px := Vector2(room.cols, room.rows) * MAP_CELL
	var at := Vector2(floorf((vp.x - size_px.x) * 0.5), MAP_TOP)
	draw_rect(Rect2(at - Vector2(2, 2), size_px + Vector2(4, 4)), MAP_GROUND)
	for y in room.rows:
		var x := 0
		while x < room.cols:
			if not room.is_solid(x, y):
				x += 1
				continue
			var from := x
			while x < room.cols and room.is_solid(x, y):
				x += 1
			draw_rect(Rect2(at + Vector2(from, y) * MAP_CELL, Vector2(x - from, 1) * MAP_CELL), MAP_ROCK)
	var k := MAP_CELL / float(Room.CELL)
	# The wires, only while the sight sees them.
	if Sight.seeing == "wires":
		for w: Wire in room.wires:
			var path := w.world_path()
			for i in range(1, path.size()):
				draw_line(at + path[i - 1] * k, at + path[i] * k, WIRE if w.live() else WIRE_DEAD, 1.0)
	for id in room.gates:
		var gate: ElectricGate = room.gates[id]
		var r := gate.world_span()
		draw_rect(Rect2(at + r.position * k, r.size * k), GATE_UP if gate.is_up() else GATE_DOWN)
	for g: Generator in room.generators:
		draw_rect(Rect2(at + g.global_position * k - Vector2(3, 3), Vector2(6, 6)), CALM if g.running() else ALARM)
	var c := room.core()
	draw_rect(Rect2(at + c.position * k, c.size * k), CORE)
	# What the screen shows.
	var shown := get_viewport().get_camera_2d()
	if shown != null:
		var w := vp.x * k
		draw_rect(Rect2(at + Vector2(shown.global_position.x * k - w * 0.5, 0.0), Vector2(w, size_px.y)),
			Color(1, 1, 1, 0.35), false, 1.0)
	var p := screen.player
	if p != null and is_instance_valid(p):
		draw_rect(Rect2(at + p.global_position * k - Vector2(2, 3), Vector2(4, 6)), BODY)

## The clock, and the best way in so far beside it.
func _draw_clock(vp: Vector2) -> void:
	var clock := _clock(screen.attempt)
	if screen.best > 0.0:
		clock = Loc.t("hud.wire.best", [clock, _clock(screen.best)])
	_text(Vector2(vp.x - MARGIN - PixelDraw.ink_width(clock), 24.0), clock, DIM)

## The vision key: what is being seen, and what a press of it does next — the
## wires, magic off, and back (`Sight.cycle`).
func _draw_sight(vp: Vector2) -> void:
	var key := Controls.short_label_for("magic_toggle")
	var says := Loc.t("hud.wire.sight_off", [key])
	var col := INK
	if Sight.seeing == "wires":
		says = Loc.t("hud.wire.sight_on", [key])
		col = SPARK
	elif not Magic.on:
		says = Loc.t("hud.wire.magic_off", [key])
		col = DIM
	_text(Vector2(MARGIN, vp.y - 22.0), says, col)

func _draw_banners(vp: Vector2) -> void:
	# Under the map of the ground, clear of it.
	var y := MAP_TOP + float(screen.room.rows) * MAP_CELL + 52.0
	if _banner_time > 0.0:
		var a := clampf(_banner_time / 0.4, 0.0, 1.0)
		_centered(y, _banner, Color(_banner_color, a), vp.x, BIG)
	elif _again_time > 0.0:
		_centered(y, Loc.t("hud.wire.again"), Color(INK, clampf(_again_time / 0.3, 0.0, 1.0)), vp.x, BIG)
	elif screen.elapsed < TITLE_TIME:
		var a := clampf((TITLE_TIME - screen.elapsed) / 0.6, 0.0, 1.0)
		_centered(y, Loc.t("hud.wire.title"), Color(SPARK, a), vp.x, BIG)
		_centered(y + 30.0, Loc.t("hud.wire.subtitle"), Color(INK, a), vp.x)

## Seconds as minutes, seconds and tenths.
static func _clock(seconds: float) -> String:
	var tenths := int(seconds * 10.0)
	@warning_ignore("integer_division")
	return "%d:%02d.%d" % [tenths / 600, (tenths / 10) % 60, tenths % 10]
