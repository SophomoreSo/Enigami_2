class_name DragonTestHud
extends Control

## The dragon test's read-outs, along the top and the foot of the screen so the
## halls between stay clear: the tape counter, the guards still standing, what
## the charge in hand would chain to, and the skill itself. Set in the pixel
## face the menus use (`PixelDraw`), in any language.

const BIG := PixelDraw.SIZE * 2

const INK := Color(0.93, 0.92, 0.98)
const DIM := Color(0.6, 0.56, 0.72)
const PINK := Color(1.0, 0.3, 0.62)
const CYAN := Color(0.35, 0.95, 1.0)
const AMBER := Color(1.0, 0.76, 0.35)
const RED := Color(1.0, 0.22, 0.28)
const SHADOW := Color(0.02, 0.01, 0.05, 0.9)
const CHARGE := Color(0.78, 0.68, 1.0)

var screen: DragonTest
var _px := PixelDraw.new(self)
var _banner: String = ""
var _banner_color: Color = CYAN
var _banner_time: float = 0.0
var _rewind_time: float = 0.0

func _ready() -> void:
	UiKit.fill_screen(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_clear(one_cast: bool) -> void:
	if one_cast:
		_banner = Loc.t("hud.dragon.one_cast", [screen.total_guards])
		_banner_color = CYAN
	else:
		_banner = Loc.t("hud.dragon.clear", [screen.best_cast, screen.total_guards])
		_banner_color = AMBER
	_banner_time = DragonTest.RESET_DELAY

func rewind() -> void:
	_banner_time = 0.0
	_rewind_time = 0.8

func _process(delta: float) -> void:
	UiKit.sync_screen(self)
	_banner_time = maxf(0.0, _banner_time - delta)
	_rewind_time = maxf(0.0, _rewind_time - delta)
	queue_redraw()

func _draw() -> void:
	if screen == null or not is_instance_valid(screen) or screen.player == null:
		return
	var vp := get_viewport_rect().size
	_draw_tape()
	_draw_guards(vp)
	_draw_chain(vp)
	_draw_skill(vp)
	_draw_banners(vp)

func _text(at: Vector2, s: String, col: Color, font_size: int = PixelDraw.SIZE) -> void:
	_px.text(at + Vector2(2, 2), s, Color(SHADOW, SHADOW.a * col.a), -1.0, font_size)
	_px.text(at, s, col, -1.0, font_size)

## `s` ending at `right`.
func _right(right: float, y: float, s: String, col: Color) -> void:
	_text(Vector2(right - PixelDraw.ink_width(s), y), s, col)

func _centered(y: float, s: String, col: Color, font_size: int = PixelDraw.SIZE) -> void:
	_text(Vector2((size.x - PixelDraw.ink_width(s, font_size)) * 0.5, y), s, col, font_size)

## The corner of a tape being played back: a recording light and the counter.
func _draw_tape() -> void:
	if fmod(screen.elapsed, 1.0) < 0.62:
		draw_rect(Rect2(24, 16, 12, 12), RED)
	var play := Loc.t("hud.dragon.play")
	_text(Vector2(46, 30), play, INK)
	var tip := Vector2(58.0 + PixelDraw.ink_width(play) + 10.0, 22)
	draw_colored_polygon(PackedVector2Array([tip + Vector2(-10, -7), tip + Vector2(0, 0),
		tip + Vector2(-10, 7)]), INK)
	var t := int(screen.elapsed)
	@warning_ignore("integer_division")
	_text(Vector2(tip.x + 16.0, 30), "%02d:%02d:%02d" % [t / 3600, (t / 60) % 60, t % 60], DIM)

## One figure per guard, struck through once they are down.
func _draw_guards(vp: Vector2) -> void:
	var n := screen.total_guards
	var step := 16.0
	var x0 := vp.x * 0.5 - float(n) * step * 0.5 + 60.0
	_right(x0 - 16.0, 30, Loc.t("hud.dragon.guards"), DIM)
	for i in n:
		var at := Vector2(x0 + float(i) * step, 12)
		if i < screen.guards_left:
			draw_rect(Rect2(at + Vector2(3, 0), Vector2(6, 6)), PINK)
			draw_rect(Rect2(at + Vector2(1, 7), Vector2(10, 11)), PINK)
		else:
			draw_rect(Rect2(at + Vector2(1, 1), Vector2(10, 17)), Color(PINK, 0.3), false, 2.0)
			draw_line(at + Vector2(-1, 18), at + Vector2(13, 0), RED, 2.0)

## What a release right now would chain to, against the guards on the floor. It
## counts the hold as it builds, so the moment the charge is enough is visible.
## While a cast is on its way through it reports that cast instead — the charge
## it was bought with is spent and gone, and reading 1 through the run of a
## nine-link chain said nothing about what was happening on screen.
func _draw_chain(vp: Vector2) -> void:
	var p := screen.player
	# The empty hand in hand: no graph, and nothing a release would chain to.
	if p.runner == null:
		return
	var n := screen.cast_chain if not p.runner.is_ready() \
		else screen.chain_length(int(p.charge))
	var need := screen.total_guards
	_right(vp.x - 24.0, 30, Loc.t("hud.dragon.chain", [n, need]), CYAN if n >= need else PINK)

## The graph in hand: its card and cooldown, the charge with a mark where it
## reaches every guard, the mana paying for it, and the keys.
func _draw_skill(vp: Vector2) -> void:
	var p := screen.player
	var r: SkillRunner = p.runner
	if r == null:
		return
	var y := vp.y - 58.0
	var card := Rect2(24, y, 272, 40)
	draw_rect(card, Color(0.05, 0.03, 0.1, 0.88))
	_px.text(card.position + Vector2(12, 26), "%s  %s" % [Controls.short_label_for("cast_skill"),
		r.board.skill_name.to_upper()], INK, card.size.x - 20.0)
	UiKit.draw_cooldown(self, card, r.ready_ratio(), r.ready_flash, Color(0.55, 0.4, 0.9))

	var bar := Rect2(316, y + 4, 320, 14)
	var enough := screen.chain_length(int(p.charge)) >= screen.total_guards
	draw_rect(bar, Color(0, 0, 0, 0.65))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * p.charge_ratio(), bar.size.y)),
		CYAN if enough else CHARGE)
	var need := screen.charge_to_clear()
	if need >= 0:
		var nx := bar.position.x + bar.size.x * float(need) / p.charge_cap()
		draw_rect(Rect2(nx - 1.0, bar.position.y - 5.0, 3.0, bar.size.y + 10.0), AMBER)
	draw_rect(bar, Color(0.5, 0.45, 0.72), false, 2.0)
	var mana := Rect2(316, y + 26, 320, 8)
	draw_rect(mana, Color(0, 0, 0, 0.65))
	draw_rect(Rect2(mana.position, Vector2(mana.size.x * p.mana_ratio(), mana.size.y)),
		Color(0.38, 0.55, 0.95))

	_text(Vector2(656, y + 18), Loc.t("hud.dragon.hold"), DIM)
	_text(Vector2(656, y + 38), Loc.t("hud.dragon.release"), DIM)
	_right(vp.x - 24.0, y + 38, Loc.t("hud.dragon.keys"), DIM)

func _draw_banners(vp: Vector2) -> void:
	# One line at a time in that space: clearing the floor inside the opening
	# four seconds used to print the result straight over the title.
	if screen.elapsed < 4.0 and _rewind_time <= 0.0 and _banner_time <= 0.0:
		var a := clampf((4.0 - screen.elapsed) / 0.6, 0.0, 1.0)
		_neon(96, Loc.t("hud.dragon.title"), Color(CYAN, a))
		_centered(124, Loc.t("hud.dragon.subtitle", [screen.total_guards]), Color(INK, a))
	if _banner_time > 0.0:
		var a := clampf(_banner_time / 0.4, 0.0, 1.0)
		_neon(96, _banner, Color(_banner_color, a))
	if _rewind_time > 0.0:
		# The tape stutters as it winds back.
		if fmod(_rewind_time * 10.0, 1.0) < 0.7:
			var at := Vector2(vp.x * 0.5 - 96.0, 110)
			for i in 2:
				var tip := at + Vector2(float(i) * 16.0, 0)
				draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(16, -12),
					tip + Vector2(16, 12)]), INK)
			_text(at + Vector2(44, 12), Loc.t("hud.dragon.rewind"), INK, BIG)

## Neon: the colour laid over a pink ghost of itself, a little off register.
func _neon(y: float, s: String, col: Color) -> void:
	var x := (size.x - PixelDraw.ink_width(s, BIG)) * 0.5
	_px.text(Vector2(x + 3, y + 3), s, Color(PINK, col.a * 0.8), -1.0, BIG)
	_px.text(Vector2(x, y), s, col, -1.0, BIG)
