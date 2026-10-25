class_name ResultsScreen
extends Control

signal continued()

## How a raid came out: what was carried, what was lost, and the way back to
## the hideout.
##
## In mobile mode (`UiKit.mobile`) the page is written for a phone held at arm's
## length: every line half as big again, what came out in a column of its own
## on the right so a long haul has the height of the screen rather than what is
## left under the rest, and the way back a plate THUMB tall.

## What the page is written against: it stands in the middle of the screen,
## whatever shape the screen is.
const DESIGN := Vector2(1280, 720)
const BACK_AT := Vector2(120, 560)
## Mobile mode's page: where its left column starts, where the haul's does, and
## the way back under the left one.
const THUMB_LEFT := 72.0
const THUMB_RIGHT := 720.0
const THUMB_BACK := Rect2(72, 592, 520, UiKit.THUMB)

var outcome: String = "extracted"
var payload: Dictionary = {}
var _font: Font
var _back: Button
## The size of screen the page was last stood in — see `_fit`.
var _fitted := Vector2(-1, -1)

func _ready() -> void:
	_font = ThemeDB.fallback_font
	UiKit.fill_screen(self)
	var bg := ColorRect.new()
	bg.color = UiKit.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Behind what this screen draws, not over it: a child is drawn after its
	# parent, and the ground was being laid over every line of the page.
	bg.show_behind_parent = true
	add_child(bg)
	_back = UiKit.button(Loc.t("menu.results.back"), UiKit.ACCENT)
	_back.custom_minimum_size = Vector2(280, 44)
	if UiKit.mobile():
		_back.custom_minimum_size = THUMB_BACK.size
		_back.add_theme_font_size_override("font_size", Loc.text_size(_back.text, 26))
	_back.pressed.connect(func() -> void: continued.emit())
	add_child(_back)
	_fit()
	_back.grab_focus()
	Audio.play("extract" if outcome == "extracted" else "death")

## The screen follows the window — a window dragged, a phone turned — and the
## page follows the screen.
func _process(_delta: float) -> void:
	UiKit.sync_screen(self)
	_fit()

func _fit() -> void:
	if size == _fitted:
		return
	_fitted = size
	_back.position = (THUMB_BACK.position if UiKit.mobile() else BACK_AT) + _origin()
	queue_redraw()

## Where the page's own top-left corner stands on the screen.
func _origin() -> Vector2:
	return ((size - DESIGN) * 0.5).floor()

## As on the HUD: the default face at a small size, and a language with a face
## of its own drawn at the size that face was made for. See `Hud._line`.
func _line(at: Vector2, s: String, align: int, width: float, font_size: int, col: Color) -> void:
	draw_string(_font, at, s, align, width, Loc.text_size(s, font_size), col)

func _draw() -> void:
	draw_set_transform(_origin())
	if UiKit.mobile():
		_draw_for_a_thumb()
		return
	var win := outcome == "extracted"
	var head := Loc.t("menu.results.won") if win else Loc.t("menu.results.lost")
	_line(Vector2(120, 160), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 46,
		UiKit.GOOD if win else UiKit.BAD)
	var sub := Loc.t("menu.results.won_sub", [String(payload.get("exit", Loc.t("menu.results.default_exit")))]) if win else \
		Loc.t("menu.results.lost_sub")
	_line(Vector2(124, 196), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiKit.DIM)

	var y := 260.0
	_line(Vector2(120, y), _weapons_line(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiKit.TEXT if win else UiKit.BAD)
	y += 26.0
	_line(Vector2(120, y), Loc.t("menu.results.scrap", [int(payload.get("scrap", 0))]),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiKit.WARN if win else UiKit.BAD)
	# What was built onto the weapon's graph went down with it, part by part.
	var lost_parts: Dictionary = payload.get("parts", {})
	if not lost_parts.is_empty():
		var built: Array[String] = []
		for id in lost_parts:
			built.append(Loc.t("menu.results.haul", [Components.name_for(String(id)), int(lost_parts[id])]))
		y += 26.0
		_line(Vector2(120, y), Loc.t("menu.results.build_lost", [Loc.t("editor.payload.separator").join(built)]),
			HORIZONTAL_ALIGNMENT_LEFT, 700, 13, UiKit.BAD)
	# What came back out with the player, and what is still down there. Both are
	# the same fact from either end of a run: a kit is only ever lost until
	# somebody walks back in for it.
	var recovered: Array = payload.get("recovered", [])
	if win and not recovered.is_empty():
		y += 26.0
		_line(Vector2(120, y), Loc.t("menu.results.recovered", [Loc.t("editor.payload.separator").join(recovered)]),
			HORIZONTAL_ALIGNMENT_LEFT, 700, 13, UiKit.GOOD)
	if not win and bool(payload.get("dropped", false)):
		y += 26.0
		_line(Vector2(120, y), Loc.t("menu.results.kit_waits"),
			HORIZONTAL_ALIGNMENT_LEFT, 700, 13, UiKit.WARN)
	y += 34.0
	_line(Vector2(120, y), Loc.t("menu.results.components"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiKit.ACCENT)
	y += 24.0
	var haul: Dictionary = payload.get("haul", {})
	if haul.is_empty():
		_line(Vector2(120, y), Loc.t("menu.results.none"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiKit.DIM)
	for id in haul:
		_line(Vector2(120, y), Loc.t("menu.results.haul", [Components.name_for(id), int(haul[id])]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Style.component_color(id) if win else Color(0.5, 0.4, 0.4))
		y += 20.0

## Mobile mode's page: the same lines, bigger, in two columns. The left says how
## it went — the outcome, the weapon, the scrap, and whatever was lost or left
## behind, each wrapped to the column — and the right lists what came out.
func _draw_for_a_thumb() -> void:
	var win := outcome == "extracted"
	var left := THUMB_LEFT
	var wide := THUMB_RIGHT - THUMB_LEFT - 48.0
	var head := Loc.t("menu.results.won") if win else Loc.t("menu.results.lost")
	_line(Vector2(left, 120), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 64,
		UiKit.GOOD if win else UiKit.BAD)
	var sub := Loc.t("menu.results.won_sub", [String(payload.get("exit", Loc.t("menu.results.default_exit")))]) if win else \
		Loc.t("menu.results.lost_sub")
	_line(Vector2(left + 4.0, 164), sub, HORIZONTAL_ALIGNMENT_LEFT, wide, 22, UiKit.DIM)

	var y := 236.0
	_line(Vector2(left, y), _weapons_line(),
		HORIZONTAL_ALIGNMENT_LEFT, wide, 24, UiKit.TEXT if win else UiKit.BAD)
	y += 40.0
	_line(Vector2(left, y), Loc.t("menu.results.scrap", [int(payload.get("scrap", 0))]),
		HORIZONTAL_ALIGNMENT_LEFT, wide, 24, UiKit.WARN if win else UiKit.BAD)
	var lost_parts: Dictionary = payload.get("parts", {})
	if not lost_parts.is_empty():
		var built: Array[String] = []
		for id in lost_parts:
			built.append(Loc.t("menu.results.haul", [Components.name_for(String(id)), int(lost_parts[id])]))
		y += 40.0
		y = _paragraph(Vector2(left, y), Loc.t("menu.results.build_lost",
			[Loc.t("editor.payload.separator").join(built)]), wide, 22, UiKit.BAD)
	var recovered: Array = payload.get("recovered", [])
	if win and not recovered.is_empty():
		y += 40.0
		y = _paragraph(Vector2(left, y), Loc.t("menu.results.recovered",
			[Loc.t("editor.payload.separator").join(recovered)]), wide, 22, UiKit.GOOD)
	if not win and bool(payload.get("dropped", false)):
		y += 40.0
		y = _paragraph(Vector2(left, y), Loc.t("menu.results.kit_waits"), wide, 22, UiKit.WARN)

	# What came out, down the right: a line a kind of part, with the height of
	# the screen to itself.
	var right := THUMB_RIGHT
	y = 120.0
	_line(Vector2(right, y), Loc.t("menu.results.components"), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UiKit.ACCENT)
	y += 44.0
	var haul: Dictionary = payload.get("haul", {})
	if haul.is_empty():
		_line(Vector2(right, y), Loc.t("menu.results.none"), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UiKit.DIM)
	for id in haul:
		_line(Vector2(right, y), Loc.t("menu.results.haul", [Components.name_for(id), int(haul[id])]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Style.component_color(id) if win else Color(0.5, 0.4, 0.4))
		y += 34.0

## A line that may run on, wrapped to `width` at `size` from `at`, which is its
## first baseline. Hands back the baseline of its last row.
func _paragraph(at: Vector2, s: String, width: float, font_size: int, col: Color) -> float:
	var px := Loc.text_size(s, font_size)
	draw_multiline_string(_font, at, s, HORIZONTAL_ALIGNMENT_LEFT, width, px, -1, col)
	var tall := _font.get_multiline_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, width, px).y
	return at.y + maxf(tall - _font.get_height(px), 0.0)

## What the run was carrying: the one weapon, or every weapon of a kit, in the
## order they were slotted.
func _weapons_line() -> String:
	var kit: Array = payload.get("weapons", [])
	if kit.size() < 2:
		return Loc.t("menu.results.weapon", [Weapons.name_for(String(payload.get("weapon", "SWORD")))])
	var names: Array[String] = []
	for w in kit:
		names.append(Weapons.name_for(String(w)))
	return Loc.t("menu.results.weapons", [Loc.t("editor.payload.separator").join(names)])
