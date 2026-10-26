class_name GhostHud
extends Control

## The ghost test's read-outs, along the top and the bottom of the screen so
## the ground between stays clear: the body's health and, while the player is
## in a monster, whose and for how long; what is left to do; whether anyone has
## seen anything; the rock's graph and the keys; and a line across the middle
## when an attempt begins or ends.
##
## The ground is wider than the screen, so under what is left to do there is
## the whole of it, small: its stone and its pits, the guards on it — a Gunman marked apart,
## any guard who has seen something lit — the body, the diamond, the monster
## the player is in, and the stretch the screen is showing.

const INK := Color(0.94, 0.93, 0.98)
const DIM := Color(0.62, 0.58, 0.74)
const GOLD := Color(1.0, 0.78, 0.32)
const FLAME := Color(1.0, 0.45, 0.28)
const CALM := Color(0.48, 0.95, 0.62)
const ALARM := Color(1.0, 0.3, 0.32)
const SHADOW := Color(0.02, 0.01, 0.05, 0.9)
const GROUND := Color(0.0, 0.0, 0.0, 0.65)
const EDGE := Color(0.5, 0.45, 0.72)
const CARD := Color(0.05, 0.03, 0.1, 0.88)
const BIG := PixelDraw.SIZE * 2
const MARGIN := 24.0
const BAR_W := 240.0
## How long the name of the test stays up once the screen opens.
const TITLE_TIME := 4.0
## How long the line saying the ground was set again stays up.
const AGAIN_TIME := 0.8
## The whole ground, small: one of its cells to this many pixels across and
## down, so the map is three hundred and sixty across for the test's ground.
const MAP_CELL := 3.0
const MAP_TOP := 46.0
const MAP_ROCK := Color(0.42, 0.5, 0.52, 0.55)
const MAP_GROUND := Color(0.02, 0.03, 0.05, 0.6)
const MAP_PIT := Color(0.0, 0.0, 0.0, 0.9)
const BODY := Color(0.55, 0.92, 1.0)
const GUARD := Color(0.86, 0.36, 0.36)
const GUN := Color(1.0, 0.62, 0.22)

var screen: GhostTest
var _px := PixelDraw.new(self)
var _banner: String = ""
var _banner_color: Color = GOLD
var _banner_time: float = 0.0
var _again_time: float = 0.0

func _ready() -> void:
	UiKit.fill_screen(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_stolen(seconds: float) -> void:
	_banner = Loc.t("hud.ghost.stolen", [_clock(seconds)])
	_banner_color = GOLD
	_banner_time = GhostTest.RESET_DELAY

func show_fell() -> void:
	_banner = Loc.t("hud.ghost.fell")
	_banner_color = ALARM
	_banner_time = GhostTest.RESET_DELAY

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
		_draw_skill(p, vp)
	_draw_goal(vp)
	_draw_map(vp)
	_draw_watch(vp)
	_text(Vector2(vp.x - MARGIN - PixelDraw.ink_width(_keys()), vp.y - 22.0), _keys(), DIM)
	_draw_banners(vp)

func _text(at: Vector2, s: String, col: Color, font_size: int = PixelDraw.SIZE) -> void:
	_px.text(at + Vector2(2, 2), s, Color(SHADOW, SHADOW.a * col.a), -1.0, font_size)
	_px.text(at, s, col, -1.0, font_size)

func _centered(y: float, s: String, col: Color, width: float, font_size: int = PixelDraw.SIZE) -> void:
	_text(Vector2((width - PixelDraw.ink_width(s, font_size)) * 0.5, y), s, col, font_size)

func _keys() -> String:
	return Loc.t("hud.ghost.keys", [Controls.short_label_for("step_out")])

## The body's health, and under it the monster the player is in with the time
## they have left in it.
func _draw_body(p: Player) -> void:
	var bar := Rect2(MARGIN, 18.0, BAR_W, 18.0)
	_px.bar(bar, p.health_ratio(), Color(0.9, 0.35, 0.38), GROUND, EDGE)
	_px.text(bar.position + Vector2(8, 15), Loc.t("hud.ghost.body", [int(p.health), int(p.max_health)]),
		Color(1, 1, 1, 0.9))
	if p.vessel() == p:
		return
	var inside := Loc.t("hud.possessing", [Monsters.name_for(p.possessing.kind).to_upper(),
		ceili(p.possess_left)])
	_text(Vector2(MARGIN, 62.0), inside, Style.POSSESS_COLOR)
	_px.bar(Rect2(MARGIN, 70.0, BAR_W, 8.0), p.possess_left / maxf(p.possess_for, 0.01),
		Style.POSSESS_COLOR, GROUND, EDGE)

## What is left to do, from where the diamond is.
func _draw_goal(vp: Vector2) -> void:
	if screen.over:
		return
	var d := screen.diamond
	var says := Loc.t("hud.ghost.take")
	var col := INK
	if d.carried_by_player():
		says = Loc.t("hud.ghost.home")
		col = GOLD
	elif d.carrier != null:
		says = Loc.t("hud.ghost.carry")
		col = Style.POSSESS_COLOR
	elif d.global_position.distance_to(screen.room.diamond_point()) > 2.0:
		says = Loc.t("hud.ghost.down")
		col = FLAME
	_centered(34.0, says, col, vp.x)

## The ground, small, under what is left to do.
func _draw_map(vp: Vector2) -> void:
	var room := screen.room
	if room == null or not is_instance_valid(room):
		return
	var size_px := Vector2(room.cols, room.rows) * MAP_CELL
	var at := Vector2(floorf((vp.x - size_px.x) * 0.5), MAP_TOP)
	draw_rect(Rect2(at - Vector2(2, 2), size_px + Vector2(4, 4)), MAP_GROUND)
	# The stone and the pits, a run of cells at a time.
	_draw_runs(room, at, room.is_solid, MAP_ROCK)
	_draw_runs(room, at, room.is_pit, MAP_PIT)
	var k := MAP_CELL / float(Room.CELL)
	# What the screen shows.
	var shown := get_viewport().get_camera_2d()
	if shown != null:
		var w := vp.x * k
		draw_rect(Rect2(at + Vector2(shown.global_position.x * k - w * 0.5, 0.0), Vector2(w, size_px.y)),
			Color(1, 1, 1, 0.35), false, 1.0)
	for c in room.get_children():
		if c is Enemy and not c.dead:
			var e := c as Enemy
			var col := GUN if e.kind == "GUNMAN" else GUARD
			if e.piloted():
				col = Style.POSSESS_COLOR
			elif e.aggro and fmod(screen.elapsed, 0.5) < 0.25:
				col = Color.WHITE
			draw_rect(Rect2(at + e.global_position * k - Vector2(2, 2), Vector2(4, 4)), col)
	var p := screen.player
	if p != null and is_instance_valid(p):
		draw_rect(Rect2(at + p.global_position * k - Vector2(2, 3), Vector2(4, 6)), BODY)
	var gem := screen.diamond.global_position * k + at
	draw_colored_polygon(PackedVector2Array([gem + Vector2(0, -4), gem + Vector2(3, 0), gem + Vector2(0, 4),
		gem + Vector2(-3, 0)]), Color(0.85, 1.0, 1.0))

## Every run along a row of the cells `which(x, y)` says, in `col`.
func _draw_runs(room: Room, at: Vector2, which: Callable, col: Color) -> void:
	for y in room.rows:
		var x := 0
		while x < room.cols:
			if not which.call(x, y):
				x += 1
				continue
			var from := x
			while x < room.cols and which.call(x, y):
				x += 1
			draw_rect(Rect2(at + Vector2(from, y) * MAP_CELL, Vector2(x - from, 1) * MAP_CELL), col)

## Whether anyone is after the player, and the clock.
func _draw_watch(vp: Vector2) -> void:
	var n := screen.alerted()
	var says := Loc.t("hud.ghost.unseen") if n == 0 else Loc.t("hud.ghost.seen", [n])
	_text(Vector2(vp.x - MARGIN - PixelDraw.ink_width(says), 34.0), says, CALM if n == 0 else ALARM)
	var clock := _clock(screen.attempt)
	if screen.best > 0.0:
		clock = Loc.t("hud.ghost.best", [clock, _clock(screen.best)])
	_text(Vector2(vp.x - MARGIN - PixelDraw.ink_width(clock), 58.0), clock, DIM)

## The rock's graph on its card, cooling down; dimmed while the rock is not in
## the hands the player is in.
func _draw_skill(p: Player, vp: Vector2) -> void:
	if p.runner == null:
		return
	var card := Rect2(MARGIN, vp.y - 58.0, 300.0, 40.0)
	draw_rect(card, CARD)
	var held := p.can_cast()
	_px.text(card.position + Vector2(12, 26), "%s  %s" % [Controls.short_label_for("cast_skill"),
		p.runner.board.skill_name.to_upper()], INK if held else DIM, card.size.x - 20.0)
	UiKit.draw_cooldown(self, card, p.runner.ready_ratio(), p.runner.ready_flash, Style.POSSESS_COLOR)
	if not held:
		_text(Vector2(card.end.x + 16.0, card.position.y + 26.0), Loc.t("hud.ghost.rock_out"), FLAME)

func _draw_banners(vp: Vector2) -> void:
	# Under the map of the ground, clear of it.
	var y := MAP_TOP + float(screen.room.rows) * MAP_CELL + 52.0
	if _banner_time > 0.0:
		var a := clampf(_banner_time / 0.4, 0.0, 1.0)
		_centered(y, _banner, Color(_banner_color, a), vp.x, BIG)
	elif _again_time > 0.0:
		_centered(y, Loc.t("hud.ghost.again"), Color(INK, clampf(_again_time / 0.3, 0.0, 1.0)), vp.x, BIG)
	elif screen.elapsed < TITLE_TIME:
		var a := clampf((TITLE_TIME - screen.elapsed) / 0.6, 0.0, 1.0)
		_centered(y, Loc.t("hud.ghost.title"), Color(Style.POSSESS_COLOR, a), vp.x, BIG)
		_centered(y + 30.0, Loc.t("hud.ghost.subtitle"), Color(INK, a), vp.x)

## Seconds as minutes, seconds and tenths.
static func _clock(seconds: float) -> String:
	var tenths := int(seconds * 10.0)
	@warning_ignore("integer_division")
	return "%d:%02d.%d" % [tenths / 600, (tenths / 10) % 60, tenths % 10]
