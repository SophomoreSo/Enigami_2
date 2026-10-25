class_name TitleScreen
extends Control

signal start_requested()
signal sandbox_requested()
signal map_maker_requested()
signal story_maker_requested()

## The save slot picked on the way in, 1..SAVE_SLOTS, or -1 until one is.
##
## Picking one opens it — `GameState.load_slot` — so by the time
## `start_requested` goes out, the profile being played is that slot's. Read it
## from the handler if you need the number; the screen is freed straight after.
var save_slot: int = -1

## One drawing, grown from a seed at boot: a circuit board, with the seal of the
## game stamped over it and light running the traces.
##
## The board is generated rather than painted, and that is the whole reason the
## light works. A pulse is a slice of a trace's own polyline taken by arc
## length, so it turns every corner the copper turns. Over a picture it would
## have to be faked.
##
## Everything is laid out against DESIGN, and the design stands in the middle of
## the screen. The screen is at least DESIGN — `canvas_items` stretch scales it
## to any window — but takes the display's shape, so a phone longer than 16:9
## shows more either side and a squarer screen more above and below. The copper
## is grown past the design for that (BOARD_REACH) and baked at the screen's own
## size; the seal, the menu and the settle are where the design puts them.

const SERIF := preload("res://graphics/assets/fonts/PlayfairDisplay-Variable.ttf")
const PIXEL := preload("res://graphics/assets/fonts/Silkscreen-Regular.ttf")

const DESIGN := Vector2(1280, 720)
const GRID := 8.0            ## the board snaps to this
const CHAMFER := 4.0         ## corners are cut at 45°, the way copper is
const SEAL := Vector2(640, 262)
const SEAL_R := 206.0
const MENU_TOP := 538.0
const SAVE_SLOT_TOP := 556.0 ## the slot chooser sits lower, under its heading
const SAVE_SLOTS := GameState.SAVE_SLOTS

## How long an armed trashcan stays armed. Throwing a profile away cannot be
## undone, so the first press only arms it and a second one inside this is what
## does it — long enough to mean it, short enough not to be left loaded.
const ARM_TIME := 3.0

## The slot column is wider than the main menu's. A row carries three things
## across it — the name, a full date and time, and the can — and at the menu's
## own 400 they sat shoulder to shoulder with the focus mark in the date.
const SAVE_SLOT_WIDTH := 480.0
const SETTLE_TOP := 452.0    ## where the board starts sinking into black

## How far past the design the board is grown on each side, across and down. A
## screen of any shape but 16:9 shows more than the design does, so there is
## copper out there to show: enough for a screen three times as wide as it is
## tall, or one as tall as it is wide. Past that the board runs out into the
## ground, the way it always did at its edges.
const BOARD_REACH := Vector2(400, 280)

## Mobile mode's menu: the same entries, as a row of big square tiles with
## a mark over each name. A line of text 24 pixels high is a small thing to land
## a thumb on, and on a phone a thumb is all there is to land. See `_tile`.
const TILE := 152.0
const TILE_GAP := 24.0
## Clear of the pendant, which hangs to 526, and of the bottom of the screen.
const TILE_TOP := 542.0
## How far each corner of a tile's plate is cut back, at 45° like the copper.
const TILE_CUT := 10.0
## The name's room in a tile, which it is centred in: from here to the bottom
## margin. The mark stands over it, from MARK_TOP.
const TILE_NAME_TOP := 88.0
const TILE_NAME_BOTTOM := 16.0
const MARK_TOP := 28.0
## The marks are tables of characters, like the pointer's: `#` is ink and `.`
## is nothing, and a character is a MARK_UNIT block, two of the seal's pixels.
const MARK_UNIT := 4.0
## A column right of centre: the triangle's weight is all at its flat side, and
## centred by its box it sits left of the middle to the eye.
const MARK_START := [
	"..#..........",
	"..###........",
	"..####.......",
	"..######.....",
	"..########...",
	"..#########..",
	"..###########",
	"..#########..",
	"..########...",
	"..######.....",
	"..####.......",
	"..###........",
	"..#..........",
]
## The bench is where a board is tried out on something that stands still for
## it, so its mark is a target.
const MARK_SANDBOX := [
	"....#####....",
	"..##.....##..",
	".#.........#.",
	".#...###...#.",
	"#...#...#...#",
	"#..#.....#..#",
	"#..#..#..#..#",
	"#..#.....#..#",
	"#...#...#...#",
	".#...###...#.",
	".#.........#.",
	"..##.....##..",
	"....#####....",
]
## The map creator lays a room a cell at a time, so its mark is a wall going up:
## courses of blocks, each set half a block along from the one under it.
const MARK_MAP_MAKER := [
	"#############",
	"#.....#.....#",
	"#.....#.....#",
	"#############",
	"#..#.....#..#",
	"#..#.....#..#",
	"#############",
	"#.....#.....#",
	"#.....#.....#",
	"#############",
	"#..#.....#..#",
	"#..#.....#..#",
	"#############",
]
## The story maker writes what somebody says, so its mark is a speech bubble
## with lines of it inside.
const MARK_STORY_MAKER := [
	"#############",
	"#...........#",
	"#.#########.#",
	"#...........#",
	"#.#########.#",
	"#...........#",
	"#.######....#",
	"#...........#",
	"#############",
	"....#........",
	"...#.........",
	"..#..........",
	".#...........",
]
const MARK_SETTINGS := [
	".....###.....",
	".##..###..##.",
	".###########.",
	"..#########..",
	"..###...###..",
	"####.....####",
	"####.....####",
	"####.....####",
	"..###...###..",
	"..#########..",
	".###########.",
	".##..###..##.",
	".....###.....",
]
const MARK_QUIT := [
	"......#......",
	"......#......",
	"..#...#...#..",
	".#....#....#.",
	"#.....#.....#",
	"#.....#.....#",
	"#...........#",
	"#...........#",
	"#...........#",
	".#.........#.",
	"..#.......#..",
	"...##...##...",
	".....###.....",
]
## Which mark stands over which tile, by the item's id in the `title` menu's
## rows — the look of an item is the screen's, the way a part's is `Style`'s.
## An item with none here gets a plate with only its name on it.
const MARKS := {"start": MARK_START, "sandbox": MARK_SANDBOX, "map_maker": MARK_MAP_MAKER,
	"story_maker": MARK_STORY_MAKER, "settings": MARK_SETTINGS, "quit": MARK_QUIT}
## The menus this screen shows, each as a page of its own: the title's, the
## save slots behind START, the settings and the two pages behind them. What
## is on each is its rows (`Menus`); `_open` knows which page each is, and
## `acts_for` what its other items do.
const MENUS := ["title", "save_slots", "settings", "general", "controls"]

## The seal and the wordmark are drawn at this fraction of the screen and
## blitted back with nearest filtering. The copper is all axis-aligned and
## already reads as pixels; curves and serifs do not, and drawing them small
## and magnifying them is the only thing that puts them on the same grid.
const SEAL_SCALE := 0.5

## Read off the reference: a near-black ground, blue and violet copper, and one
## warm cream that only the seal and the wordmark are allowed to use.
const GROUND := Color(0.0, 0.047, 0.051)
const PLATE := Color(0.012, 0.043, 0.063)
const COPPER := [
	Color(0.043, 0.161, 0.251), Color(0.055, 0.145, 0.224),
	Color(0.094, 0.184, 0.290), Color(0.141, 0.290, 0.463),
	Color(0.220, 0.190, 0.380), Color(0.400, 0.320, 0.580),
	Color(0.560, 0.440, 0.700),
]
const CREAM := Color(1.0, 0.85, 0.72)
const HALO := Color(0.78, 0.86, 0.95)    ## the stipple: pale, not cyan
const SPARK := Color(0.62, 0.94, 1.0)
const MENU_INK := Color(0.41, 0.61, 0.95)
## An armed trashcan, and the DELETE? in the row beside it.
const WARN_INK := Color(0.96, 0.45, 0.42)

enum { PAD, VIA, CHIP, CAP, RES, DOTS }

var _t: float = 0.0
var _traces: Array = []      ## {pts, len, col, w}
var _parts: Array = []       ## {p, kind, col, d, s}
var _halo: Array = []        ## four alpha buckets of dot segments
var _pulses: Array = []      ## {i, t, v, len}
var _rng := RandomNumberGenerator.new()

var _board: SubViewport
var _board_painter: Node2D
var _seal_view: SubViewport
## Where the design stands on the screen: DESIGN, in the middle of whatever
## shape the screen is. The menus are laid out against DESIGN, so they are this
## one's children rather than the screen's; the settings pages, which centre
## themselves on the screen, are the screen's.
var _stage: Control
## The stage's corner on the screen, and the size of screen it was last fitted
## to — see `_fit_stage`.
var _origin := Vector2.ZERO
var _fitted := Vector2(-1, -1)
## The traces the screen shows any of, by index into `_traces`: the ones a pulse
## may run. Most of the board is out past the edges of a 16:9 screen.
var _shown := PackedInt32Array()
var _seal_painter: Node2D
var _menu_font: FontVariation
## The same face for the column's lines, set tighter than its own leading:
## Silkscreen carries ten pixels of air over its capitals at this size, and
## six lines at its own height would run off the foot of the design. Set
## this way, six stand as tall as five did at its own.
var _column_font: FontVariation
## The main menu: a column of lines, or in mobile mode a row of tiles.
var _menu_root: BoxContainer
## Whether the menu was laid out for mobile mode, and its tiles, each against
## the mark drawn over its name.
var _mobile: bool = false
var _tiles: Dictionary = {}
## The save slots: a column under the seal, or in mobile mode a page of its own
## — see `_build_save_slots`.
var _save_slot_root: Control
var _buttons: Array = []
var _start_button: Button
var _settings_button: Button
var _first_save_slot: Button
## The settings, and the two pages behind them, one per button: the volumes and
## the language on one, the rebinding list on the other. The settings themselves
## are nothing but the way to them, and only ever one of the three is up. Each
## is a scroll around its panel, so a page too long for the screen can still be
## reached — see `_settings_page`.
var _settings: UiKit.ScreenFrame
var _general: UiKit.ScreenFrame
var _controls: UiKit.ScreenFrame
## One entry per slot: {"n", "pick", "stamp", "bin"}, and "thumb" for a row
## built for mobile mode's page.
var _slot_rows: Array = []
## The heading over them, read with the page: it is drawn every frame.
var _slot_prompt: String = ""
## The slot whose trashcan is armed, or -1, and how long it stays that way.
var _armed_slot: int = -1
var _armed_left: float = 0.0

## Paints the copper once, into `_board`. Nothing on the board moves — the
## light that runs it is drawn live, over the top — and repainting ~7000
## static primitives every frame cost more than the whole rest of the screen
## put together (26 ms a frame on an M1 Max, against 2 ms baked).
class BoardPainter extends Node2D:
	var screen: TitleScreen
	func _draw() -> void:
		screen._paint_copper(self)

## Repaints the seal every frame at SEAL_SCALE. The seal breathes and its rune
## bands turn, so unlike the board this one cannot be baked — but at half
## resolution it is a couple of hundred primitives over a quarter of the
## pixels, which costs less than drawing it full-size once.
class SealPainter extends Node2D:
	var screen: TitleScreen
	func _draw() -> void:
		var breath := screen._breath()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(SEAL_SCALE, SEAL_SCALE))
		screen._paint_seal(self, breath)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		screen._paint_wordmark(self, breath, SEAL_SCALE)

func _ready() -> void:
	UiKit.fill_screen(self)
	# Nothing this screen blits wants smoothing: the board goes down 1:1 and
	# the seal is magnified on purpose.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rng.randomize()
	_menu_font = FontVariation.new()
	_menu_font.base_font = PIXEL
	_menu_font.spacing_glyph = 3
	_column_font = FontVariation.new()
	_column_font.base_font = PIXEL
	_column_font.spacing_glyph = 3
	_column_font.spacing_top = -4
	_column_font.spacing_bottom = -2
	_stage = Control.new()
	_stage.size = DESIGN
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_build_board()
	_build_seal_view()
	_build_menu()
	_build_save_slots()
	_build_settings()
	_build_general()
	_build_controls()
	Loc.language_changed.connect(_relanguage)
	Audio.play_music()

func _breath() -> float:
	return 0.5 + 0.5 * sin(_t * 0.7)

func _build_seal_view() -> void:
	_seal_view = SubViewport.new()
	_seal_view.size = Vector2i(DESIGN * SEAL_SCALE)
	_seal_view.transparent_bg = true
	_seal_view.disable_3d = true
	_seal_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_seal_painter = SealPainter.new()
	(_seal_painter as SealPainter).screen = self
	_seal_view.add_child(_seal_painter)
	add_child(_seal_view)

## --- the board --------------------------------------------------------------
## Seeded, so the board is the same board every boot: it is the game's face, not
## a different sketch each time you look at it.
func _build_board() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x1D0CE
	var face := Rect2(-40.0, -40.0, DESIGN.x + 80.0, DESIGN.y + 80.0)
	for i in 380:
		_grow_trace(rng, face)
	_build_halo(rng)
	# The copper past the design, for a screen that shows some. Grown from a seed
	# of its own and after the rest, so a 16:9 screen shows the board it always
	# did, trace for trace; each band round the design gets as many traces as the
	# same room had inside it, so the board is as dense out there as in here.
	var beyond := RandomNumberGenerator.new()
	beyond.seed = 0x1D0CF
	var all := face.grow_individual(BOARD_REACH.x, BOARD_REACH.y, BOARD_REACH.x, BOARD_REACH.y)
	for band: Rect2 in [
			Rect2(all.position.x, all.position.y, face.position.x - all.position.x, all.size.y),
			Rect2(face.end.x, all.position.y, all.end.x - face.end.x, all.size.y),
			Rect2(face.position.x, all.position.y, face.size.x, face.position.y - all.position.y),
			Rect2(face.position.x, face.end.y, face.size.x, all.end.y - face.end.y)]:
		for i in roundi(380.0 * band.get_area() / face.get_area()):
			_grow_trace(beyond, band)
	_fit_stage()
	for i in 16:
		var pu := {"i": 0, "t": 0.0, "v": 0.0, "len": 0.0}
		_respawn(pu)
		pu["t"] = rng.randf()
		_pulses.append(pu)
	_bake_board()

func _bake_board() -> void:
	_board = SubViewport.new()
	# The screen's own size, with the design where it stands in it. A screen
	# that changes shape has it baked again — see `_fit_stage`.
	_board.size = Vector2i(size.ceil()).max(Vector2i.ONE)
	_board.transparent_bg = true
	_board.disable_3d = true
	# UPDATE_ONCE draws a single frame and then switches itself off, which is
	# exactly the life of this texture: painted at boot, blitted thereafter.
	_board.render_target_update_mode = SubViewport.UPDATE_ONCE
	var painter := BoardPainter.new()
	painter.screen = self
	_board_painter = painter
	_board.add_child(painter)
	add_child(_board)

## Stands the design in the middle of the screen, once per size of screen: the
## stage the menus are on, the traces a pulse may run along, and the copper,
## baked again at the new size.
func _fit_stage() -> void:
	if size == _fitted:
		return
	_fitted = size
	# Whole PIXELs, so the pixel face and the copper land on the grid they are
	# drawn to rather than between two of its lines.
	_origin = ((size - DESIGN) * 0.5 / UiKit.PIXEL).floor() * UiKit.PIXEL
	_stage.position = _origin
	var screen := Rect2(-_origin, size)
	_shown.clear()
	for i in _traces.size():
		if (_traces[i]["box"] as Rect2).intersects(screen):
			_shown.append(i)
	if _board != null:
		_board.size = Vector2i(size.ceil()).max(Vector2i.ONE)
		_board.render_target_update_mode = SubViewport.UPDATE_ONCE
		_board_painter.queue_redraw()

const AXES := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]

## One run of copper, set down somewhere in `start` and kept to it, give or take
## the grid step a leg may run over its edge.
func _grow_trace(rng: RandomNumberGenerator, start: Rect2) -> void:
	var p := Vector2.ZERO
	# The board is thinned where the menu will sit rather than masked there
	# afterwards, so the copper that does survive still runs whole traces.
	for tries in 6:
		p = Vector2(snappedf(rng.randf_range(start.position.x, start.end.x), GRID),
			snappedf(rng.randf_range(start.position.y, start.end.y), GRID))
		var away := Vector2((p.x - SEAL.x) / 330.0, (p.y - 600.0) / 150.0).length()
		if away > 1.0 or rng.randf() < away * 0.35:
			break
	var dir: Vector2 = AXES[rng.randi() % 4]
	var raw := PackedVector2Array([p])
	var keep := start.grow(GRID)
	for leg in rng.randi_range(2, 7):
		var run := float(rng.randi_range(2, 11)) * GRID
		var q := p + dir * run
		if q.x < keep.position.x or q.x > keep.end.x or q.y < keep.position.y or q.y > keep.end.y:
			break
		p = q
		raw.append(p)
		dir = Vector2(dir.y, dir.x) * (1.0 if rng.randf() < 0.5 else -1.0)
	if raw.size() < 2:
		return

	# Most copper is dim blue; a quarter of it carries the violet, and a very
	# few runs the pale. Without that spread the board reads as one flat
	# texture rather than as layers of a board.
	var roll := rng.randf()
	var ci := rng.randi() % 3
	if roll > 0.95:
		ci = 6
	elif roll > 0.70:
		ci = 4 + rng.randi() % 2
	elif roll > 0.55:
		ci = 3
	var col: Color = COPPER[ci]
	var pts := _chamfer(raw)
	var total := 0.0
	for i in range(pts.size() - 1):
		total += pts[i].distance_to(pts[i + 1])
	if total < 24.0:
		return
	# Where it runs, for asking whether a screen shows any of it.
	var box := Rect2(pts[0], Vector2.ZERO)
	for corner in pts:
		box = box.expand(corner)
	_traces.append({"pts": pts, "len": total, "col": col,
		"w": 1.5 if rng.randf() < 0.72 else 2.5, "box": box})
	_place_parts(rng, raw, col)

## A right-angle corner in copper is cut at 45°, never square.
func _chamfer(pts: PackedVector2Array) -> PackedVector2Array:
	if pts.size() < 3:
		return pts
	var out := PackedVector2Array([pts[0]])
	for i in range(1, pts.size() - 1):
		var a := pts[i - 1]
		var b := pts[i]
		var c := pts[i + 1]
		var d1 := b - a
		var d2 := c - b
		var cut := minf(CHAMFER, minf(d1.length(), d2.length()) * 0.45)
		out.append(b - d1.normalized() * cut)
		out.append(b + d2.normalized() * cut)
	out.append(pts[pts.size() - 1])
	return out

func _place_parts(rng: RandomNumberGenerator, raw: PackedVector2Array, col: Color) -> void:
	for e in [raw[0], raw[raw.size() - 1]]:
		_parts.append({"p": e, "kind": PAD if rng.randf() < 0.6 else VIA,
			"col": col, "d": Vector2.RIGHT, "s": Vector2.ZERO})
	for i in range(raw.size() - 1):
		if rng.randf() > 0.5:
			continue
		var a := raw[i]
		var b := raw[i + 1]
		var d := (b - a).normalized()
		var p := a.lerp(b, rng.randf_range(0.25, 0.75)).snapped(Vector2(GRID, GRID) * 0.5)
		var roll := rng.randf()
		if roll < 0.3:
			_parts.append({"p": p, "kind": CHIP, "col": col, "d": d,
				"s": Vector2(float(rng.randi_range(3, 7)) * 6.0, float(rng.randi_range(2, 4)) * 6.0)})
		elif roll < 0.6:
			_parts.append({"p": p, "kind": CAP, "col": col, "d": d, "s": Vector2.ZERO})
		elif roll < 0.85:
			_parts.append({"p": p, "kind": RES, "col": col, "d": d, "s": Vector2.ZERO})
		else:
			_parts.append({"p": p, "kind": DOTS, "col": col, "d": d, "s": Vector2.ZERO})

## The stipple around the seal, bucketed by alpha so the whole halo costs four
## draw calls instead of two thousand.
func _build_halo(rng: RandomNumberGenerator) -> void:
	var buckets := [PackedVector2Array(), PackedVector2Array(),
		PackedVector2Array(), PackedVector2Array()]
	for i in 9000:
		var a := rng.randf() * TAU
		var k := rng.randf()
		if rng.randf() > pow(1.0 - k, 2.3):
			continue
		var out := rng.randf() < 0.72
		var r := SEAL_R + (2.0 + k * 24.0) if out else SEAL_R - (3.0 + k * 18.0)
		var p := (SEAL + Vector2(cos(a), sin(a)) * r).snapped(Vector2(2, 2))
		var b := clampi(int((1.0 - k) * 4.0), 0, 3)
		buckets[b].append(p)
		buckets[b].append(p + Vector2(2, 0))
	_halo = buckets

func _respawn(pu: Dictionary) -> void:
	# Only along copper the screen shows: a pulse past its edge is one nobody sees.
	if _shown.is_empty():
		return
	var i := _shown[_rng.randi() % _shown.size()]
	pu["i"] = i
	pu["t"] = -_rng.randf() * 0.9          # a beat of dark before it runs again
	pu["v"] = _rng.randf_range(110.0, 260.0) / maxf(float(_traces[i]["len"]), 40.0)
	pu["len"] = _rng.randf_range(30.0, 96.0)

## The piece of `pts` lying between arc lengths `a` and `b`.
func _arc_slice(pts: PackedVector2Array, a: float, b: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if b <= 0.0 or pts.size() < 2:
		return out
	a = maxf(a, 0.0)
	var walked := 0.0
	for i in range(pts.size() - 1):
		var p0 := pts[i]
		var p1 := pts[i + 1]
		var seg := p0.distance_to(p1)
		if seg <= 0.001:
			continue
		if walked + seg >= a and walked <= b:
			var f0 := clampf((a - walked) / seg, 0.0, 1.0)
			var f1 := clampf((b - walked) / seg, 0.0, 1.0)
			if out.is_empty():
				out.append(p0.lerp(p1, f0))
			out.append(p0.lerp(p1, f1))
		walked += seg
		if walked > b:
			break
	return out

## --- the menu ---------------------------------------------------------------
## A column of lines, or in mobile mode a row of tiles: the same entries
## either way, doing the same things. Which entries, in what order, and what
## each says is the `title` menu's rows; what each does is this screen's, by
## the item's id — `_open` for one that leads to a page, `acts_for` for the
## rest.
func _build_menu(focus: bool = true) -> void:
	_mobile = Touch.wanted()
	if _mobile:
		_menu_root = _tile_row()
	else:
		_menu_root = _column(MENU_TOP)
	var acts := acts_for("title")
	var made := {}
	for item in Menus.items("title"):
		var id := String(item["id"])
		var b := _menu_item(String(item["text"]), MARKS.get(id, []))
		b.pressed.connect(Menus.press("title", item, acts, _open))
		made[id] = b
	# The two the screen comes back to: START takes the keyboard when the menu
	# comes up, SETTINGS when the settings close over it.
	_start_button = made.get("start")
	_settings_button = made.get("settings")
	for id in ["start", "settings"]:
		if not made.has(id):
			push_error("TitleScreen: the title menu has no '%s' — see data/db/menus/menus.sql" % id)
	if _mobile:
		# Centred under the seal on whole pixels, now its width is known.
		var n := _menu_root.get_child_count()
		_menu_root.position.x = SEAL.x - floorf((TILE * n + TILE_GAP * (n - 1)) * 0.5)
	if focus and _start_button != null:
		_start_button.grab_focus()

## Mobile mode was thrown — on the controls page, which is the only place it
## can be — so everything here that is laid out for the one mode is laid out
## again for the other: the menu under the settings, the save slots, and the
## pages themselves, the one with the switch on it among them. Whichever was up
## is put back up, and the keyboard, which was on the switch if it was anywhere,
## is put on the switch that took its place.
func _remode() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	var on_switch := focused is UiKit.Switch and is_ancestor_of(focused)
	_rebuild()
	if on_switch and _controls != null and _controls.visible:
		for c in _controls.find_children("*", "", true, false):
			if c is UiKit.Switch:
				(c as Control).grab_focus()
				break

func _menu_item(text: String, mark: Array) -> Button:
	return _tile(text, mark) if _mobile else _menu_button(text, _menu_root)

## Opening a menu from an item that leads to one: the page it is on this
## screen. The rows name menus; this is the one place that knows which page
## each is, so a row opening one the screen has no page for is said, not
## guessed at.
func _open(menu: String) -> void:
	match menu:
		"save_slots":
			_show_save_slots()
		"settings":
			_toggle_settings()
		"general":
			_toggle_general()
		"controls":
			_toggle_controls()
		_:
			push_error("TitleScreen: no page for the %s menu" % menu)

## What an item that opens no menu does, by its id, on each menu this screen
## shows — the words its rows are written in. `back` is the way out of the
## page it is on: one level up, to wherever that page was opened from.
## `tests/graphics/menus_test` holds every row to these.
func acts_for(menu: String) -> Dictionary:
	match menu:
		"title":
			return {"sandbox": func() -> void: sandbox_requested.emit(),
				"map_maker": func() -> void: map_maker_requested.emit(),
				"story_maker": func() -> void: story_maker_requested.emit(),
				"quit": func() -> void: get_tree().quit()}
		"save_slots":
			return {"back": _hide_save_slots}
		"settings":
			return {"back": _toggle_settings}
		"general":
			return {"back": _toggle_general}
		"controls":
			return {"back": _toggle_controls}
	return {}

## The row mobile mode's tiles stand in, from TILE_TOP down. `_build_menu`
## centres it once the tiles are in it.
func _tile_row() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.position = Vector2(0.0, TILE_TOP)
	h.add_theme_constant_override("separation", int(TILE_GAP))
	_stage.add_child(h)
	return h

## One of mobile mode's tiles: a square TILE across, the whole of it the thing
## to press. The button carries only the name, low in the square — the plate
## and the mark over the name are drawn under it by `_draw_tiles`, the way the
## trashcans are, so they light with the name when the tile is pointed at. A
## name of two words too long for one line stands on two: the tile is the one
## width it is, and its name has room under the mark for a second line.
func _tile(text: String, mark: Array) -> Button:
	var b := _bare_button(text, 16)
	b.custom_minimum_size = Vector2(TILE, TILE)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var box := StyleBoxEmpty.new()
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = TILE_NAME_TOP
	box.content_margin_bottom = TILE_NAME_BOTTOM
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(s, box)
	_tiles[b] = mark
	_menu_root.add_child(b)
	return b

## START asks which save slot before it hands over. Each row says which slot it
## is, when that profile was last written, and offers a way to throw it away.
## Picking one opens it, so what `start_requested` hands on is that profile.
##
## In mobile mode it is a page like the settings', over the seal, and for the
## tiles' reason: a line of text 24 high with a can 28 high at the end of it is
## two small things to land a thumb on, and one of them throws a profile away.
## There a row is one plate to press, THUMB tall, with its can a plate of its
## own beside it.
func _build_save_slots() -> void:
	_slot_prompt = Menus.name_for("save_slots")
	_slot_rows.clear()
	if _mobile:
		_build_save_slot_page()
		return
	var column := _column(SAVE_SLOT_TOP, SAVE_SLOT_WIDTH)
	_save_slot_root = column
	_save_slot_root.visible = false
	for i in SAVE_SLOTS:
		var row := _slot_row(i + 1)
		_slot_rows.append(row)
		if i == 0:
			_first_save_slot = row["pick"]
	# Under the slots, what the menu's own rows put there: the way back.
	var acts := acts_for("save_slots")
	for item in Menus.items("save_slots"):
		var b := _menu_button(String(item["text"]), column)
		b.add_theme_font_size_override("font_size", Loc.text_size(b.text, 16))
		b.pressed.connect(Menus.press("save_slots", item, acts, _open))
	_refresh_slots()

## Mobile mode's save slots: the kit's frame, a plate per slot, and the menu's
## own way back pinned under them.
func _build_save_slot_page() -> void:
	var page := _settings_page()
	_save_slot_root = page
	var v := _settings_column(page, _slot_prompt)
	for i in SAVE_SLOTS:
		var row := _slot_plate(i + 1)
		_slot_rows.append(row)
		v.add_child(row["box"])
		if i == 0:
			_first_save_slot = row["pick"]
	_fill_page(page, "save_slots")
	_refresh_slots()

## One slot, for a thumb: a plate that says which slot it is and when it was
## last saved, the whole of it the thing to press, and the can on a plate of its
## own at the end, as wide as it is tall. The stamp rides on the plate rather
## than beside it, so a thumb on the date opens the slot like one on the name.
func _slot_plate(n: int) -> Dictionary:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var pick := UiKit.button(Loc.t("menu.save_slots.slot", [n]), UiKit.ACCENT, true)
	pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick.pressed.connect(func() -> void:
		save_slot = n
		GameState.load_slot(n)
		start_requested.emit())
	h.add_child(pick)
	var stamp := UiKit.label("", UiKit.THUMB_TEXT, UiKit.DIM, true)
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stamp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stamp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stamp.offset_right = -20.0
	pick.add_child(stamp)
	# No word on it: the can is drawn on the plate, at twice the size the
	# column's is, in the row's ink.
	var bin := UiKit.button("", UiKit.BAD, true)
	bin.custom_minimum_size = Vector2(UiKit.THUMB + 16.0, UiKit.THUMB)
	bin.pressed.connect(_bin_pressed.bind(n))
	bin.draw.connect(func() -> void:
		var col := WARN_INK if _armed_slot == n \
			else (Color.WHITE if bin.has_focus() or bin.is_hovered() else UiKit.DIM)
		_paint_bin(bin, (bin.size * 0.5).floor(), col, BIN_UNIT * 2.0))
	h.add_child(bin)
	return {"n": n, "pick": pick, "stamp": stamp, "bin": bin, "box": h, "thumb": true}

## One slot: its name on the left, when it was last saved on the right, and a
## trashcan past that. A row rather than a single button because the can has to
## be reachable on its own — by the mouse, and by the pad moving right onto it.
func _slot_row(n: int) -> Dictionary:
	var h := HBoxContainer.new()
	h.custom_minimum_size = Vector2(SAVE_SLOT_WIDTH, 0)
	h.add_theme_constant_override("separation", 0)
	_save_slot_root.add_child(h)

	# Sized to its own name rather than stretched across the row, so the marks
	# `_draw_focus_marks` sets either side of the focused control land against
	# SLOT 1 the way they do against every other line on this screen. Stretched,
	# the right-hand one sat in the middle of the date.
	var pick := _bare_button(Loc.t("menu.save_slots.slot", [n]), 24)
	pick.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pick.pressed.connect(func() -> void:
		save_slot = n
		GameState.load_slot(n)
		start_requested.emit())
	h.add_child(pick)

	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(gap)

	var stamp := Label.new()
	stamp.add_theme_font_override("font", _menu_font)
	stamp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(stamp)

	# No text of its own: the can is drawn over it by `_draw_slot_bins`, the way
	# everything else on this screen is drawn rather than dropped in as an image.
	var bin := _bare_button("", 16)
	bin.custom_minimum_size = Vector2(40, 28)
	bin.pressed.connect(_bin_pressed.bind(n))
	h.add_child(bin)
	return {"n": n, "pick": pick, "stamp": stamp, "bin": bin}

## What a slot's row says on the right.
##
## The stamp is the local date and time in a numeric form that reads the same in
## every language, so there is no sentence in it to translate — only the two
## words around it, for a slot with nothing in it and for one being thrown away.
func _slot_stamp(n: int) -> String:
	if _armed_slot == n:
		return Loc.t("menu.save_slots.slot_delete")
	@warning_ignore("static_called_on_instance")
	var at := int(GameState.slot_info(n).get("saved_at", 0))
	if at <= 0:
		return Loc.t("menu.save_slots.slot_empty")
	var local := at + int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d := Time.get_datetime_dict_from_unix_time(local)
	return "%04d-%02d-%02d %02d:%02d" % [d["year"], d["month"], d["day"], d["hour"], d["minute"]]

## Re-reads the slots off disk and puts what they say back on the rows. Cheap
## enough to call on every open and every delete: it is three small files.
func _refresh_slots() -> void:
	for row in _slot_rows:
		var n := int(row["n"])
		var line := _slot_stamp(n)
		var stamp: Label = row["stamp"]
		stamp.text = line
		if bool(row.get("thumb", false)):
			# A plate: the kit's ink, the kit's size, and its can drawn again.
			stamp.add_theme_font_size_override("font_size", Loc.text_size(line, UiKit.THUMB_TEXT))
			stamp.add_theme_color_override("font_color", WARN_INK if _armed_slot == n else UiKit.DIM)
			(row["bin"] as Button).queue_redraw()
			continue
		stamp.add_theme_font_size_override("font_size", Loc.text_size(line, 14))
		stamp.add_theme_color_override("font_color", WARN_INK if _armed_slot == n
			else Color(CREAM.r, CREAM.g, CREAM.b, 0.55))

## Throwing a profile away cannot be undone, so the first press only arms the
## can: the row turns red and says DELETE?, and a second press inside ARM_TIME
## is what actually empties the slot. Anything else lets it lapse.
func _bin_pressed(n: int) -> void:
	if _armed_slot == n:
		_armed_slot = -1
		GameState.delete_slot(n)
		_refresh_slots()
		Audio.play("deny")
		return
	_armed_slot = n
	_armed_left = ARM_TIME
	_refresh_slots()
	Audio.play("ui")

func _disarm() -> void:
	if _armed_slot < 0:
		return
	_armed_slot = -1
	_refresh_slots()

func _column(top: float, width: float = 400.0) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.position = Vector2(SEAL.x - width * 0.5, top)
	v.custom_minimum_size = Vector2(width, 0)
	v.add_theme_constant_override("separation", 2)
	_stage.add_child(v)
	return v

func _show_save_slots() -> void:
	_menu_root.visible = false
	_save_slot_root.visible = true
	# Read off disk each time it opens: a profile saved since the title came up
	# — the game was played and the player came back here — has a newer stamp.
	_armed_slot = -1
	_refresh_slots()
	_first_save_slot.grab_focus()
	Audio.play("ui")

func _hide_save_slots() -> void:
	_disarm()
	_save_slot_root.visible = false
	_menu_root.visible = true
	_start_button.grab_focus()
	Audio.play("ui")

## No chrome at all: the menu is text that brightens, and the marks flanking it
## are drawn by `_draw_focus_marks` so a gamepad player can see where they are.
func _menu_button(text: String, parent: VBoxContainer) -> Button:
	var b := _bare_button(text, 24)
	b.add_theme_font_override("font", _column_font)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(b)
	return b

## The look, without a home: the slot rows lay their buttons out themselves.
func _bare_button(text: String, px: int) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	var box := StyleBoxEmpty.new()
	box.content_margin_left = 22
	box.content_margin_right = 22
	box.content_margin_top = 1
	box.content_margin_bottom = 1
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(s, box)
	b.add_theme_font_override("font", _menu_font)
	b.add_theme_font_size_override("font_size", Loc.text_size(text, px))
	b.add_theme_color_override("font_color", MENU_INK)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	_buttons.append(b)
	return b

## SETTINGS holds nothing of its own any more: it is two buttons and the way
## back, and every setting lives on the page behind one of them. All three are
## the `settings` menu's rows, each door saying the name of the page it opens.
func _build_settings() -> void:
	_settings = _settings_page()
	_settings_column(_settings, Menus.name_for("settings"))
	_fill_page(_settings, "settings")

## The volumes and the language, on the page behind GENERAL SETTINGS. The rows
## themselves are the screen's; the way back under them is the menu's.
func _build_general() -> void:
	_general = _settings_page()
	var v := _settings_column(_general, Menus.name_for("general"))
	for row in SettingsRows.rows() + VideoRows.rows():
		v.add_child(row)
	_fill_page(_general, "general")

## The rebinding list, on the page behind CONTROL SETTINGS. It is eighteen rows
## of two columns — longer than every other setting put together — and inline
## it left the buttons under it somewhere off the bottom of a long scroll. A
## page of its own, as a sibling scroll rather than a panel swapped into the
## settings, so no page inherits another's scroll position.
func _build_controls() -> void:
	_controls = _settings_page()
	var v := _settings_column(_controls, Menus.name_for("controls"))
	var controls := ControlsPanel.new()
	controls.pixel = true
	v.add_child(controls)
	_fill_page(_controls, "controls")

## A page's items, from its menu's rows: a button each, in order, under
## whatever the page already holds. One that is a way out of the page is
## pinned in the frame's foot, so however long the rows above it grow it stays
## on the screen. What pressing each does is `_open` for a door and `acts_for`
## for the rest.
func _fill_page(page: UiKit.ScreenFrame, menu: String) -> void:
	var acts := acts_for(menu)
	var foot_open := false
	for item in Menus.items(menu):
		var b := UiKit.button(String(item["text"]), UiKit.ACCENT, true)
		b.pressed.connect(Menus.press(menu, item, acts, _open))
		if bool(item["exit"]):
			if not foot_open:
				page.foot.add_child(UiKit.spacer(8))
				foot_open = true
			page.foot.add_child(b)
		else:
			page.rows.add_child(b)

## An empty settings page, hidden until its button is pressed: UiKit's pixel
## look, like the menu that opens it. The pixel face runs up to twice as wide as
## the one it replaced, so the panel is wide — 600 holds the controls list's two
## columns, and the frame adds its bar.
##
## Centred, since the pages are three very different heights: SETTINGS is three
## buttons and the rebinding list is eighteen rows, and hung from a common top
## the short ones floated in the upper third of the screen. The rebinding list
## is taller than the room it has either way, so it fills that room from 56 and
## scrolls — its rows do, that is. The heading over them and the way back out
## from under them are pinned to the frame and go nowhere.
func _settings_page() -> UiKit.ScreenFrame:
	var f := UiKit.screen_frame(608.0, 56.0, 28.0, true)
	f.visible = false
	add_child(f)
	return f

## The column a page's rows go in, under a heading and a rule pinned above it.
## What the caller then puts in the page's `foot` is pinned under it.
func _settings_column(page: UiKit.ScreenFrame, heading: String) -> VBoxContainer:
	page.head.add_child(UiKit.label(heading, UiKit.text(24), UiKit.ACCENT, true))
	page.head.add_child(UiKit.hline(true))
	return page.rows

## The whole menu, in the new language. Everything here is text laid out once
## in `_ready`, so a change of language is a rebuild rather than a refresh —
## and whichever settings page was up is put back open, because that is where
## the switch was just pressed.
func _relanguage(_lang: String) -> void:
	_rebuild()

## Every menu and page on this screen, built again as the language and the mode
## now have them, with whichever was up put back up.
func _rebuild() -> void:
	var was_settings: bool = _settings != null and _settings.visible
	var was_general: bool = _general != null and _general.visible
	var was_controls: bool = _controls != null and _controls.visible
	var was_slots: bool = _save_slot_root != null and _save_slot_root.visible
	for old in [_menu_root, _save_slot_root, _settings, _general, _controls]:
		if old != null and is_instance_valid(old):
			old.get_parent().remove_child(old)
			old.queue_free()
	_buttons.clear()
	_tiles.clear()
	_slot_rows.clear()
	_armed_slot = -1
	_menu_root = null
	_save_slot_root = null
	_settings = null
	_general = null
	_controls = null
	_start_button = null
	_settings_button = null
	_first_save_slot = null
	_build_menu()
	_build_save_slots()
	_build_settings()
	_build_general()
	_build_controls()
	if was_settings or was_general or was_controls:
		_settings.visible = was_settings
		_general.visible = was_general
		_controls.visible = was_controls
		_menu_root.visible = false
	elif was_slots:
		_show_save_slots()

func _toggle_settings() -> void:
	# Settings can only be reached from the main column, so that is the one to
	# put back when it closes.
	_settings.visible = not _settings.visible
	_menu_root.visible = not _settings.visible
	# Leaving the settings leaves the pages behind them as well: reopening them
	# has to land on the settings, not on whichever page was last looked at.
	for page in [_general, _controls]:
		if page != null:
			page.visible = false
	if not _settings.visible and _settings_button != null:
		_settings_button.grab_focus()
	Audio.play("ui")

## The page behind GENERAL SETTINGS, in and out. The settings are the only way
## to it, so they are what comes back.
func _toggle_general() -> void:
	_general.visible = not _general.visible
	_settings.visible = not _general.visible
	Audio.play("ui")

## The page behind CONTROL SETTINGS, the same way.
func _toggle_controls() -> void:
	_controls.visible = not _controls.visible
	_settings.visible = not _controls.visible
	Audio.play("ui")

## Backing out: whichever page is up, then the settings, then the save slots.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _general != null and _general.visible:
		_toggle_general()
		get_viewport().set_input_as_handled()
	elif _controls != null and _controls.visible:
		_toggle_controls()
		get_viewport().set_input_as_handled()
	elif _settings != null and _settings.visible:
		_toggle_settings()
		get_viewport().set_input_as_handled()
	elif _save_slot_root != null and _save_slot_root.visible:
		# One press to call off an armed can, another to leave the list.
		if _armed_slot >= 0:
			_disarm()
		else:
			_hide_save_slots()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	UiKit.sync_screen(self)
	_fit_stage()
	_t += delta
	# Asked every frame, as the console asks it: nothing announces mobile mode
	# being thrown, and the switch that throws it is on a page of this screen.
	if _menu_root != null and Touch.wanted() != _mobile:
		_remode()
	if _armed_slot >= 0:
		_armed_left -= delta
		if _armed_left <= 0.0:
			_disarm()
	for pu in _pulses:
		pu["t"] += float(pu["v"]) * delta
		if pu["t"] > 1.0:
			_respawn(pu)
	if _seal_painter != null:
		_seal_painter.queue_redraw()
	queue_redraw()

## --- drawing ----------------------------------------------------------------
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), GROUND)
	# Baked at the screen's size with the design already where it stands in it.
	if _board != null:
		draw_texture(_board.get_texture(), Vector2.ZERO)
	# What is written against DESIGN is drawn where the design stands.
	draw_set_transform(_origin)
	_draw_pulses()
	_draw_settle()
	if _seal_view != null:
		draw_texture_rect(_seal_view.get_texture(), Rect2(Vector2.ZERO, DESIGN), false)
	_draw_save_slot_prompt()
	# The rest is the screen's own: marks read off the buttons, which are where
	# the design stands already, and the glass over the whole of it.
	draw_set_transform(Vector2.ZERO)
	_draw_focus_marks()
	_draw_slot_bins()
	_draw_glass()
	# On the glass rather than behind it, with the names their buttons carry:
	# under the scanlines a white mark came out striped beside a clean name.
	_draw_tiles()

## Into a texture the screen's size, the design where it stands in it, and only
## what the screen shows: most of the board is out past the edges of a 16:9
## screen, and painting it there would cost what the bake exists to save. The
## margin is for a part hanging over the edge from just outside it.
func _paint_copper(cv: CanvasItem) -> void:
	cv.draw_set_transform(_origin)
	var shown := Rect2(-_origin, size).grow(32.0)
	for trace in _traces:
		if (trace["box"] as Rect2).intersects(shown):
			cv.draw_polyline(trace["pts"], trace["col"], trace["w"])
	for pt in _parts:
		if shown.has_point(pt["p"]):
			_paint_part(cv, pt)

func _paint_part(cv: CanvasItem, pt: Dictionary) -> void:
	var p: Vector2 = pt["p"]
	var col: Color = pt["col"]
	var d: Vector2 = pt["d"]
	var n := Vector2(-d.y, d.x)
	match int(pt["kind"]):
		PAD:
			cv.draw_circle(p, 4.0, col)
			cv.draw_circle(p, 1.5, GROUND)
		VIA:
			cv.draw_arc(p, 4.5, 0.0, TAU, 10, col, 1.0)
		CHIP:
			var s: Vector2 = pt["s"]
			var r := Rect2(p - s * 0.5, s)
			cv.draw_rect(r, Color(col.r, col.g, col.b, 0.22))
			cv.draw_rect(r, col, false, 1.0)
			var pins := maxi(int(s.x / 6.0), 1)
			for i in pins:
				var x := r.position.x + 3.0 + float(i) * 6.0
				cv.draw_line(Vector2(x, r.position.y), Vector2(x, r.position.y - 3.0), col, 1.0)
				cv.draw_line(Vector2(x, r.end.y), Vector2(x, r.end.y + 3.0), col, 1.0)
		CAP:
			for k in 3:
				var o := d * (float(k) * 3.0 - 3.0)
				cv.draw_line(p + o - n * 7.0, p + o + n * 7.0, col, 1.0)
		RES:
			cv.draw_rect(Rect2(p - d * 7.0 - n * 3.0, d * 14.0 + n * 6.0).abs(), col, false, 1.0)
			cv.draw_line(p - n * 3.0, p + n * 3.0, col, 1.0)
		DOTS:
			for gx in 3:
				for gy in 4:
					cv.draw_rect(Rect2(p + d * float(gx) * 4.0 + n * float(gy) * 4.0,
						Vector2(2, 2)), col)

## The board sinks into black below the seal, so the menu has something to sit
## on. Thinning the copper when it is grown is not enough on its own — what
## survives still crosses the text, and text over a live trace is unreadable at
## any brightness.
func _draw_settle() -> void:
	# Smoothstep, not a power curve: anything that leaves the gradient at a
	# non-zero slope where it starts draws a visible seam across the board.
	# Across the whole screen and down to its foot, wherever those are from the
	# design, so the ground the menu sits on runs out to the edges.
	for i in int(size.y - _origin.y - SETTLE_TOP):
		var k := clampf(float(i) / 168.0, 0.0, 1.0)
		draw_rect(Rect2(-_origin.x, SETTLE_TOP + float(i), size.x, 1.0),
			Color(GROUND.r, GROUND.g, GROUND.b, 0.55 * k * k * (3.0 - 2.0 * k)))
	# The rest of the darkening is pooled behind the menu rather than spread
	# across the row, so the far corners keep the copper the reference has
	# there and only the text gets a clean ground.
	draw_set_transform(_origin + Vector2(SEAL.x, MENU_TOP + 76.0), 0.0, Vector2(3.4, 1.0))
	for i in 26:
		var k := 1.0 - float(i) / 26.0
		draw_circle(Vector2.ZERO, 20.0 + k * 112.0, Color(GROUND.r, GROUND.g, GROUND.b, 0.045))
	draw_set_transform(_origin)

func _draw_pulses() -> void:
	for pu in _pulses:
		var trace: Dictionary = _traces[int(pu["i"])]
		var head: float = float(pu["t"]) * float(trace["len"])
		var tail: float = float(pu["len"])
		for k in 3:
			var a := head - tail * (1.0 - float(k) / 3.0)
			var b := head - tail * (1.0 - float(k + 1) / 3.0)
			var seg := _arc_slice(trace["pts"], a, b)
			if seg.size() >= 2:
				var f := float(k + 1) / 3.0
				draw_polyline(seg, Color(SPARK.r, SPARK.g, SPARK.b, 0.16 + 0.64 * f * f),
					float(trace["w"]) + 0.5)

## Drawn into `_seal_view` at SEAL_SCALE and blitted back at 1/SEAL_SCALE with
## nearest filtering, so every curve here lands on the same coarse grid the
## copper does. Line widths are therefore in half-pixels: 2.0 is one pixel of
## the seal's grid, and anything odd blends across a row instead of filling it.
func _paint_seal(cv: CanvasItem, breath: float) -> void:
	var c := SEAL
	var r := SEAL_R

	for i in _halo.size():
		var pts: PackedVector2Array = _halo[i]
		if pts.is_empty():
			continue
		var a := (0.07 + 0.12 * float(i)) * (0.72 + 0.28 * breath)
		cv.draw_multiline(pts, Color(HALO.r, HALO.g, HALO.b, a), 2.0)

	# The bloom around the rim: concentric arcs fading outward, which is as
	# close to a soft glow as a line renderer gets. It wants to be wide and
	# weak — a few bright rings read as a target, not as light.
	for i in 26:
		var k := float(i) / 26.0
		cv.draw_arc(c, r + 1.0 + k * 44.0, 0.0, TAU, 96,
			Color(CREAM.r, CREAM.g, CREAM.b,
				(1.0 - k) * (1.0 - k) * 0.16 * (0.62 + 0.38 * breath)), 4.0)

	cv.draw_circle(c, r - 1.0, PLATE)
	cv.draw_arc(c, r, 0.0, TAU, 180, Color(CREAM.r, CREAM.g, CREAM.b, 0.82 + 0.18 * breath), 4.0)
	cv.draw_arc(c, r - 8.0, 0.0, TAU, 160, Color(CREAM.r, CREAM.g, CREAM.b, 0.26), 2.0)

	var ink := Color(0.32, 0.44, 0.70, 0.88)
	var dim := Color(0.26, 0.36, 0.60, 0.62)
	var faint := Color(0.23, 0.32, 0.56, 0.44)
	for k in [0.93, 0.855, 0.835, 0.755, 0.47, 0.45]:
		cv.draw_arc(c, r * k, 0.0, TAU, 128, faint if k < 0.5 else dim, 2.0)

	# The rune band turns about once every two minutes — under the threshold
	# where you would call it spinning, over the one where the seal looks dead.
	var rot := _t * 0.05
	for i in 98:
		var a := rot + TAU * float(i) / 98.0
		var d := Vector2(cos(a), sin(a))
		if i % 7 == 0:
			cv.draw_line(c + d * (r * 0.862), c + d * (r * 0.925), ink, 2.0)
			cv.draw_rect(Rect2(c + d * (r * 0.90) - Vector2(2, 2), Vector2(4, 4)), ink)
		else:
			cv.draw_line(c + d * (r * 0.868), c + d * (r * 0.90 + (6.0 if i % 2 == 0 else 2.0)),
				dim, 2.0)
	# A finer band inside it, turning the other way.
	for i in 60:
		var a := -rot * 1.6 + TAU * float(i) / 60.0
		var d := Vector2(cos(a), sin(a))
		cv.draw_line(c + d * (r * 0.775), c + d * (r * 0.80), faint, 2.0)

	# Two heptagrams, the inner one turned against the outer, with spokes
	# carrying the outer's points out to the rune band.
	var vp: Array = []
	for i in 7:
		var a := -PI * 0.5 + TAU * float(i) / 7.0
		vp.append(c + Vector2(cos(a), sin(a)) * (r * 0.70))
	for i in 7:
		cv.draw_line(vp[i], vp[(i + 3) % 7], ink, 2.0)
		cv.draw_circle(vp[i], 4.0, Color(0.45, 0.60, 0.88, 0.85))
		cv.draw_arc(vp[i], 8.0, 0.0, TAU, 10, dim, 2.0)
		var d: Vector2 = (vp[i] - c).normalized()
		cv.draw_line(c + d * (r * 0.70), c + d * (r * 0.835), faint, 2.0)
	var ip: Array = []
	for i in 7:
		var a := PI * 0.5 + TAU * (float(i) + 0.5) / 7.0
		ip.append(c + Vector2(cos(a), sin(a)) * (r * 0.45))
	for i in 7:
		cv.draw_line(ip[i], ip[(i + 2) % 7], faint, 2.0)

	# The plate the wordmark sits against, and the chamber under it.
	cv.draw_rect(Rect2(c - Vector2(r * 0.54, r * 0.28), Vector2(r * 1.08, r * 0.56)), dim, false, 2.0)
	cv.draw_rect(Rect2(c - Vector2(r * 0.50, r * 0.24), Vector2(r * 1.00, r * 0.48)), faint, false, 2.0)
	for i in 3:
		var a := PI * 0.5 + TAU * float(i) / 3.0
		var b := PI * 0.5 + TAU * float(i + 1) / 3.0
		cv.draw_line(c + Vector2(cos(a), sin(a)) * (r * 0.56),
			c + Vector2(cos(b), sin(b)) * (r * 0.56), dim, 2.0)
	# The lower half of the seal is the half the wordmark does not cover, so it
	# carries the detail: a graduated band, and the core hung at the bottom.
	for i in 46:
		var a := PI * 0.12 + PI * 0.76 * (float(i) / 45.0)
		var d := Vector2(cos(a), sin(a))
		cv.draw_line(c + d * (r * 0.615), c + d * (r * 0.615 + (8.0 if i % 5 == 0 else 4.0)),
			dim if i % 5 == 0 else faint, 2.0)
	cv.draw_arc(c, r * 0.615, PI * 0.10, PI * 0.90, 64, faint, 2.0)

	var core := c + Vector2(0, r * 0.50)
	cv.draw_arc(core, 14.0, 0.0, TAU, 18, ink, 2.0)
	cv.draw_arc(core, 9.0, 0.0, TAU, 14, dim, 2.0)
	cv.draw_circle(core, 4.0, Color(0.50, 0.66, 0.92, 0.85))
	for i in 6:
		var a := TAU * float(i) / 6.0 - rot * 2.0
		var d := Vector2(cos(a), sin(a))
		cv.draw_line(core + d * 14.0, core + d * 21.0, dim, 2.0)
	_diamond(cv, core, 26.0, faint)

	_paint_pendant(cv, c + Vector2(0, r), breath)

## The charm hanging off the bottom of the seal, and the one place the menu and
## the seal touch.
func _paint_pendant(cv: CanvasItem, top: Vector2, breath: float) -> void:
	var glow := Color(SPARK.r, SPARK.g, SPARK.b, 0.30 + 0.35 * breath)
	cv.draw_line(top, top + Vector2(0, 28), Color(CREAM.r, CREAM.g, CREAM.b, 0.55), 2.0)
	var node := top + Vector2(0, 34)
	for i in 4:
		cv.draw_circle(node, 5.0 + float(i) * 3.0, Color(glow.r, glow.g, glow.b, glow.a * 0.14))
	cv.draw_arc(node, 6.0, 0.0, TAU, 12, Color(CREAM.r, CREAM.g, CREAM.b, 0.85), 2.0)
	_diamond(cv, node + Vector2(0, 16), 8.0, Color(SPARK.r, SPARK.g, SPARK.b, 0.75 + 0.25 * breath))

func _diamond(cv: CanvasItem, p: Vector2, r: float, col: Color, w: float = 2.0) -> void:
	cv.draw_polyline(PackedVector2Array([
		p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r),
		p + Vector2(-r, 0), p + Vector2(0, -r)]), col, w)

## The wordmark is sized and placed in seal-grid pixels rather than being drawn
## large and scaled down: a glyph rasterised at 142 and squeezed into half the
## room comes back smooth, and smooth is the one thing it must not be.
func _paint_wordmark(cv: CanvasItem, breath: float, s: float) -> void:
	var text := "Enigami"
	var px := int(round(142.0 * s))
	var w := SERIF.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var at := Vector2(SEAL.x * s - w * 0.5, (SEAL.y + 46.0) * s).round()
	for i in 8:
		var a := TAU * float(i) / 8.0
		cv.draw_string(SERIF, at + (Vector2(cos(a), sin(a)) * 5.0 * s).round(), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, px,
			Color(CREAM.r, CREAM.g, CREAM.b, 0.05 + 0.035 * breath))
	# One grid pixel of offset, not two: at this size a second one stops being
	# a shadow and starts being an emboss.
	cv.draw_string(SERIF, at + Vector2(1, 1), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(0.0, 0.055, 0.11, 0.85))
	cv.draw_string(SERIF, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, CREAM)

func _draw_focus_marks() -> void:
	var f := get_viewport().gui_get_focus_owner()
	if f == null or not _buttons.has(f) or not (f as Control).is_visible_in_tree():
		return
	# A tile says it is the one by lighting its own frame, in `_draw_tiles`.
	if _tiles.has(f):
		return
	var r := (f as Control).get_global_rect()
	r.position -= global_position
	var y := r.position.y + r.size.y * 0.5
	var beat := 0.55 + 0.45 * sin(_t * 4.0)
	var col := Color(SPARK.r, SPARK.g, SPARK.b, beat)
	_diamond(self, Vector2(r.position.x + 8.0, y), 4.0, col, 1.5)
	_diamond(self, Vector2(r.end.x - 8.0, y), 4.0, col, 1.5)

## Mobile mode's tiles, under the names their buttons carry: a plate with its
## corners cut the way the copper's are, and the entry's mark over its name. In
## the menu's own ink, and white under the cursor or the pad, with the frame lit
## twice over and beating the way the marks either side of a line do — though
## never down to the frames round it: a beat that faded out left the tile that
## was picked looking like the ones that were not. A thumb down on a tile
## brightens its plate, since the thumb covers whatever else would say so.
func _draw_tiles() -> void:
	if _tiles.is_empty() or _menu_root == null or not _menu_root.is_visible_in_tree():
		return
	var focused := get_viewport().gui_get_focus_owner()
	var beat := 0.85 + 0.15 * sin(_t * 4.0)
	for b: Button in _tiles:
		var r := b.get_global_rect()
		r.position -= global_position
		var lit := focused == b
		var held := b.get_draw_mode() == BaseButton.DRAW_PRESSED \
			or b.get_draw_mode() == BaseButton.DRAW_HOVER_PRESSED
		var plate := _octagon(r, TILE_CUT)
		draw_colored_polygon(plate, Color(0.10, 0.17, 0.30, 0.95) if held
			else Color(PLATE.r, PLATE.g, PLATE.b, 0.92))
		plate.append(plate[0])
		if lit:
			draw_polyline(plate, Color(SPARK.r, SPARK.g, SPARK.b, beat), 2.0)
			var inner := _octagon(r.grow(-6.0), TILE_CUT - 2.0)
			inner.append(inner[0])
			draw_polyline(inner, Color(SPARK.r, SPARK.g, SPARK.b, 0.3), 2.0)
		else:
			draw_polyline(plate, Color(MENU_INK.r, MENU_INK.g, MENU_INK.b, 0.55), 2.0)
		_draw_mark(_tiles[b], Vector2(r.get_center().x, r.position.y + MARK_TOP),
			Color.WHITE if lit else MENU_INK)

## `r` with its corners cut back `cut` at 45°, as the eight points round it.
func _octagon(r: Rect2, cut: float) -> PackedVector2Array:
	var a := r.position
	var b := r.end
	return PackedVector2Array([
		Vector2(a.x + cut, a.y), Vector2(b.x - cut, a.y), Vector2(b.x, a.y + cut),
		Vector2(b.x, b.y - cut), Vector2(b.x - cut, b.y), Vector2(a.x + cut, b.y),
		Vector2(a.x, b.y - cut), Vector2(a.x, a.y + cut)])

## A mark, hung from the middle of its top edge: each run of `#` along a line
## of the table is one block MARK_UNIT high.
func _draw_mark(mark: Array, top_middle: Vector2, col: Color) -> void:
	if mark.is_empty():
		return
	var u := MARK_UNIT
	var at := (top_middle - Vector2(String(mark[0]).length() * u * 0.5, 0.0)).floor()
	for y in mark.size():
		var line: String = mark[y]
		var x := 0
		while x < line.length():
			if line[x] != "#":
				x += 1
				continue
			var run := 1
			while x + run < line.length() and line[x + run] == "#":
				run += 1
			draw_rect(Rect2(at + Vector2(x, y) * u, Vector2(run * u, u)), col)
			x += run

## The heading over the save slots. Drawn rather than laid out, so the column
## below it keeps the exact spacing the main menu has.
func _draw_save_slot_prompt() -> void:
	# Mobile mode's page carries its own heading, and its own cans.
	if _save_slot_root == null or not _save_slot_root.visible or _mobile:
		return
	var line := _slot_prompt
	var font_size := Loc.text_size(line, 16)
	var w := _menu_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(_menu_font, Vector2(SEAL.x - w * 0.5, SAVE_SLOT_TOP - 12.0), line,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(CREAM.r, CREAM.g, CREAM.b, 0.7))

## The trashcan at the end of each slot row. Drawn rather than dropped in as an
## image, like everything else here, on a 2-pixel unit so it lands on the same
## grid the copper does. It follows the row it belongs to: ordinary ink, white
## under the cursor or the pad, red once it is armed.
const BIN_UNIT := 2.0

func _draw_slot_bins() -> void:
	if _save_slot_root == null or not _save_slot_root.visible or _mobile:
		return
	var focused := get_viewport().gui_get_focus_owner()
	for row in _slot_rows:
		var bin: Button = row["bin"]
		var r := bin.get_global_rect()
		r.position -= global_position
		var col := MENU_INK
		if _armed_slot == int(row["n"]):
			col = WARN_INK
		elif focused == bin:
			col = Color.WHITE
		_draw_bin(r.get_center().floor(), col)

func _draw_bin(at: Vector2, col: Color) -> void:
	_paint_bin(self, at, col, BIN_UNIT)

## The can, drawn on `cv` with its middle at `at`, a block of it `u` across:
## this screen's own canvas for the column's, and the plate's for mobile mode's.
static func _paint_bin(cv: CanvasItem, at: Vector2, col: Color, u: float) -> void:
	# The handle, and the lid across the top of it.
	cv.draw_rect(Rect2(at + Vector2(-2, -7) * u, Vector2(4, 1) * u), col)
	cv.draw_rect(Rect2(at + Vector2(-5, -6) * u, Vector2(10, 1) * u), col)
	# Two walls and a base rather than a filled block, so it reads as a can.
	cv.draw_rect(Rect2(at + Vector2(-4, -4) * u, Vector2(1, 9) * u), col)
	cv.draw_rect(Rect2(at + Vector2(3, -4) * u, Vector2(1, 9) * u), col)
	cv.draw_rect(Rect2(at + Vector2(-4, 5) * u, Vector2(8, 1) * u), col)
	# And the two slots down its face.
	cv.draw_rect(Rect2(at + Vector2(-2, -3) * u, Vector2(1, 7) * u), col)
	cv.draw_rect(Rect2(at + Vector2(1, -3) * u, Vector2(1, 7) * u), col)

## Scanlines and a vignette, to sit the whole thing behind glass.
func _draw_glass() -> void:
	for y in range(0, int(size.y), 4):
		draw_rect(Rect2(0, float(y), size.x, 1), Color(0, 0, 0, 0.055))
	for i in 46:
		var k := float(i) / 46.0
		draw_rect(Rect2(Vector2(i, i), size - Vector2(i, i) * 2.0),
			Color(0, 0.02, 0.03, 0.055 * (1.0 - k)), false, 1.0)
