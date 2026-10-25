class_name PixelDraw
extends RefCounted

## Drawing on the pixel grid, for a screen that draws itself rather than being
## built out of Controls. `UiKit`'s pixel look is the same thing for the ones
## that are built out of Controls, and the two have to agree: the same face at
## the same size, the same square unsmoothed borders a whole PIXEL wide.
##
## Everything here snaps to that grid. An edge half a PIXEL off puts a stroke
## across two rows of it instead of on one, which is the whole difference
## between pixel art and a smooth picture of pixel art.
##
## Bound to one CanvasItem and kept by it:
##
##     var _px := PixelDraw.new(self)
##     _px.rect(Rect2(0, 0, 100, 20), Color.BLACK)
##
## Screens using it: `SkillEditor` and `MapPanel`, the two pages of one screen
## under the same top (`ScreenTabs`), `SandboxPanel`, `Hud`, and the hideout's
## station signs — which draw it over the world rather than on a screen, and say
## in `HideoutWorldView` why the words cannot go into the world itself — and an
## NPC's talk prompt and a treasure box's, which are the same `key_cap` the
## signs show.

const PX := UiKit.PIXEL
const FONT := UiKit.PIXEL_FONT
const SIZE := UiKit.PIXEL_TEXT
## Baseline to baseline. Capitals stand 10px tall at PIXEL_TEXT and nothing in
## the face descends, so this leaves 10px clear between rows.
const LINE := 20.0

## A keycap, for a prompt that asks for a key: its face at its narrowest, room
## for one capital with a margin, in PXs.
const KEY_W := 11
const KEY_H := 9
## How far the face stands above its base, and so how far a press sinks it.
const KEY_DEPTH := 2
## One press every PRESS_EVERY seconds: down over PRESS_DOWN, held, then back up
## over PRESS_UP.
const PRESS_EVERY := 1.1
const PRESS_DOWN := 0.07
const PRESS_HOLD := 0.12
const PRESS_UP := 0.12

var _c: CanvasItem

func _init(c: CanvasItem) -> void:
	_c = c

func snap(p: Vector2) -> Vector2:
	return (p / PX).floor() * PX

func rect(r: Rect2, col: Color) -> void:
	var a := snap(r.position)
	_c.draw_rect(Rect2(a, snap(r.end) - a), col)

## A border one PIXEL wide, inside `r`. Four rects rather than an unfilled
## draw_rect, whose corners overlap and double up a translucent colour.
func frame(r: Rect2, col: Color) -> void:
	var a := snap(r.position)
	var z := snap(r.end)
	_c.draw_rect(Rect2(a.x, a.y, z.x - a.x, PX), col)
	_c.draw_rect(Rect2(a.x, z.y - PX, z.x - a.x, PX), col)
	_c.draw_rect(Rect2(a.x, a.y + PX, PX, z.y - a.y - 2 * PX), col)
	_c.draw_rect(Rect2(z.x - PX, a.y + PX, PX, z.y - a.y - 2 * PX), col)

## A filled diamond centred on `c`, `radius` PIXELs from its middle to each point.
func diamond(c: Vector2, radius: int, col: Color) -> void:
	var mid := snap(c - Vector2.ONE * PX * 0.5)
	for dy in range(-radius, radius + 1):
		var half := radius - absi(dy)
		_c.draw_rect(Rect2(mid.x - half * PX, mid.y + dy * PX, (2 * half + 1) * PX, PX), col)

## A filled circle on the grid, `radius` from its middle to its edge.
##
## Rasterised a pixel row at a time rather than drawn with `draw_circle`, which
## is a smooth polygon: a circle on this grid has one correct shape per radius,
## and it is made of whole blocks like everything else here. The on-screen
## console is what wants them — a thumbstick is the one thing in this game that
## has to be round.
func disc(c: Vector2, radius: float, col: Color) -> void:
	_circle(c, radius, 0.0, col)

## The same circle with a hole in it, `thick` PIXELs of edge left standing.
func ring(c: Vector2, radius: float, thick: float, col: Color) -> void:
	_circle(c, radius, maxf(radius - thick, 0.0), col)

## A stretch of that ring: the blocks of it whose middles lie within `half` of
## the direction `toward`, both angles as the screen has them — nothing is to
## the right, a quarter turn is straight down. The same blocks `ring` would
## draw, so a stretch laid over a ring lands on it exactly.
func arc(c: Vector2, radius: float, thick: float, toward: float, half: float, col: Color) -> void:
	var o := snap(c)
	var inner := maxf(radius - thick, 0.0)
	var steps := int(radius / PX)
	for i in range(-steps, steps + 1):
		var y := float(i) * PX
		var wide := _half(radius, y)
		if wide <= 0.0:
			continue
		var hole := _half(inner, y)
		var x := -wide
		while x < wide:
			var in_hole := hole > 0.0 and x >= -hole and x < hole
			var mid := Vector2(x + PX * 0.5, y + PX * 0.5)
			if not in_hole and absf(angle_difference(mid.angle(), toward)) <= half:
				_c.draw_rect(Rect2(o.x + x, o.y + y, PX, PX), col)
			x += PX

## The rows of a circle of `outer`, minus those of one of `inner`. Symmetric
## about the row and column the middle lands on, so a disc and the ring around
## it share a centre exactly.
func _circle(c: Vector2, outer: float, inner: float, col: Color) -> void:
	var o := snap(c)
	var steps := int(outer / PX)
	for i in range(-steps, steps + 1):
		var y := float(i) * PX
		var wide := _half(outer, y)
		if wide <= 0.0:
			continue
		var hole := _half(inner, y)
		if hole <= 0.0:
			_c.draw_rect(Rect2(o.x - wide, o.y + y, wide * 2.0, PX), col)
		else:
			_c.draw_rect(Rect2(o.x - wide, o.y + y, wide - hole, PX), col)
			_c.draw_rect(Rect2(o.x + hole, o.y + y, wide - hole, PX), col)

## Half the width of the row `y` of a circle of `radius`, in whole PIXELs.
func _half(radius: float, y: float) -> float:
	var w := radius * radius - y * y
	if radius <= 0.0 or w <= 0.0:
		return 0.0
	return floorf(sqrt(w) / PX) * PX

## The border of `r` lit clockwise from the middle of its top edge, `k` of the
## way round. Each side after the first starts a PIXEL past its corner, so no
## corner is lit twice and doubled up in a translucent colour.
func lap(r: Rect2, k: float, col: Color) -> void:
	var a := snap(r.position)
	var z := snap(r.end) - Vector2.ONE * PX
	var top := Vector2(snap(Vector2((a.x + z.x) * 0.5, 0.0)).x, a.y)
	var corners := [top, Vector2(z.x, a.y), z, Vector2(a.x, z.y), a, top]
	var total := 0.0
	for i in 5:
		var seg: Vector2 = corners[i + 1] - corners[i]
		total += absf(seg.x) + absf(seg.y)
	var lit := int(clampf(k, 0.0, 1.0) * total / PX)
	for i in 5:
		var seg: Vector2 = corners[i + 1] - corners[i]
		var steps := int((absf(seg.x) + absf(seg.y)) / PX)
		if steps == 0:
			continue
		var d := seg / float(steps)
		var start: Vector2 = corners[i] if i == 0 else corners[i] + d
		var n := mini(steps + (1 if i == 0 else 0), lit)
		if n <= 0:
			return
		var end := start + d * (n - 1)
		var lo := Vector2(minf(start.x, end.x), minf(start.y, end.y))
		_c.draw_rect(Rect2(lo, (start - end).abs() + Vector2.ONE * PX), col)
		lit -= n

## A keyboard key with `label` on it, standing on `foot` — the middle of the
## line under it — and pressing itself every PRESS_EVERY seconds of `t`: a pale
## face over a darker side, a dark rim round both, corners cut in steps. It is
## how a prompt says "press this" rather than spelling it out, and it says
## whichever key is bound, a word like "LMB" widening it.
func key_cap(foot: Vector2, label: String, t: float) -> void:
	# Square for a single key, wider for a word.
	var size := Vector2(maxf(ink_width(label) + 6 * PX, KEY_W * PX), KEY_H * PX)
	var sink := roundi(KEY_DEPTH * pressed(fmod(t, PRESS_EVERY))) * PX
	# The base stays put; the face rides KEY_DEPTH above it and sinks onto it.
	var base := Rect2(snap(Vector2(foot.x - size.x * 0.5, foot.y - PX - size.y)), size)
	var face := Rect2(base.position - Vector2(0.0, KEY_DEPTH * PX - sink), size)
	# The rim is opaque: it goes down as overlapping blocks, which would double
	# up a translucent colour.
	_stepped(face.merge(base).grow(PX), 2, Style.KEY_CAP_RIM)
	_stepped(base, 1, Style.KEY_CAP_SIDE)
	_stepped(face, 1, Style.KEY_CAP_FACE)
	# `text` takes a baseline, and capitals stand 5 blocks: 2 clear above them.
	text_centered(face.position + Vector2(0.0, 7 * PX), label, Style.KEY_CAP_TEXT, size.x)

## How far down a key_cap is, 0 up to 1 all the way, `t` seconds into a press.
static func pressed(t: float) -> float:
	if t < PRESS_DOWN:
		return ease(t / PRESS_DOWN, 0.5)
	t -= PRESS_DOWN
	if t < PRESS_HOLD:
		return 1.0
	t -= PRESS_HOLD
	if t < PRESS_UP:
		return 1.0 - ease(t / PRESS_UP, 2.0)
	return 0.0

## `r` filled with its corners cut `cut` blocks deep in steps, the pixel art way
## of rounding one.
func _stepped(r: Rect2, cut: int, col: Color) -> void:
	for i in cut + 1:
		var k := cut - i
		rect(Rect2(r.position + Vector2(k, i) * PX, r.size - Vector2(k, i) * 2 * PX), col)

## A meter: `ratio` of `r` filled, on its own ground, inside a one-PIXEL edge.
func bar(r: Rect2, ratio: float, fill: Color, ground: Color, edge: Color) -> void:
	rect(r, ground)
	rect(Rect2(r.position, Vector2(r.size.x * clampf(ratio, 0.0, 1.0), r.size.y)), fill)
	frame(r, edge)

## A button for a pointer: `label` in the middle of it, a PIXEL of edge, lit
## under the pointer. The assembly screen's COPY and PASTE, and the back arrow
## of the screen it is a page of (`ScreenTabs`).
func button(r: Rect2, label: String, hot: bool) -> void:
	rect(r, Color(0.16, 0.3, 0.4, 0.9) if hot else Color(0.11, 0.13, 0.17, 0.9))
	frame(r, Color(0.55, 0.9, 1.0) if hot else Color(0.32, 0.4, 0.5))
	text(r.position + Vector2((r.size.x - ink_width(label)) * 0.5, (r.size.y + 10.0) * 0.5), label,
		Color(0.92, 0.98, 1.0) if hot else Color(0.7, 0.8, 0.9))

## A plate for a thumb: its ground and its two PIXELs of edge in `accent`, lit
## under a thumb, drained when it has nothing to act on, and `label` in the
## middle of it at a thumb's size.
func plate(r: Rect2, label: String, accent: Color, hot: bool, on: bool) -> void:
	rect(r, Color(accent.r, accent.g, accent.b, 0.3) if (hot and on) else Color(0.11, 0.13, 0.17, 0.92))
	var edge := accent if on else Color(0.32, 0.34, 0.38)
	frame(r, edge)
	frame(r.grow(-PX), edge)
	if label == "":
		return
	var font_size := Loc.text_size(label, UiKit.THUMB_TEXT)
	text(Vector2(r.position.x + (r.size.x - ink_width(label, font_size)) * 0.5,
		r.position.y + (r.size.y + 20.0) * 0.5), label,
		Color(0.95, 0.98, 1.0) if on else Color(0.45, 0.48, 0.52), -1.0, font_size)

## A bitmap — one string per row, `#` for a PIXEL — with its top-left at `at`,
## each bitmap pixel `zoom` PIXELs square. Each run along a row goes down as one
## rect.
func icon(at: Vector2, rows: Array, col: Color, zoom: int = 1) -> void:
	var o := snap(at)
	var s := PX * zoom
	for y in rows.size():
		var row := String(rows[y])
		var x := row.find("#")
		while x >= 0:
			var end := x
			while end < row.length() and row[end] == "#":
				end += 1
			_c.draw_rect(Rect2(o.x + x * s, o.y + y * s, (end - x) * s, s), col)
			x = row.find("#", end)

func icon_centered(c: Vector2, rows: Array, col: Color, zoom: int = 1) -> void:
	icon(c - Vector2(String(rows[0]).length(), rows.size()) * PX * zoom * 0.5, rows, col, zoom)

## A bitmap turned `steps` quarter turns clockwise.
static func turn(rows: Array, steps: int) -> Array:
	var out := rows
	for s in posmod(steps, 4):
		var turned: Array = []
		for x in String(out[0]).length():
			var line := ""
			for y in range(out.size() - 1, -1, -1):
				line += String(out[y])[x]
			turned.append(line)
		out = turned
	return out

## `text` in the pixel face, its baseline at `pos`, cut short with an ellipsis
## when it is wider than `width`. `size` is for the few things written bigger
## than everything else — the console on the glass — and has to be a multiple
## of SIZE, where the face still lands on whole PIXELs.
func text(pos: Vector2, s: String, col: Color, width: float = -1.0, size: int = SIZE) -> void:
	if width > 0.0:
		s = clip(s, width, size)
	_c.draw_string(FONT, snap(pos), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

## The same, centred in `width` from `pos`.
func text_centered(pos: Vector2, s: String, col: Color, width: float, size: int = SIZE) -> void:
	s = clip(s, width, size)
	text(pos + Vector2((width - ink_width(s, size)) * 0.5, 0.0), s, col, -1.0, size)

static func text_width(s: String, size: int = SIZE) -> float:
	return FONT.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

## The width of the letters alone: every advance carries a pixel of the face's
## space after its letter — a PIXEL at SIZE — which would push anything centred
## on it off by half of one.
static func ink_width(s: String, size: int = SIZE) -> float:
	return text_width(s, size) - float(PX * size) / float(SIZE)

static func clip(s: String, width: float, size: int = SIZE) -> String:
	if text_width(s, size) <= width:
		return s
	var lo := 0
	var hi := s.length()
	while lo < hi:
		var mid := (lo + hi + 1) >> 1
		if text_width(s.left(mid) + "…", size) <= width:
			lo = mid
		else:
			hi = mid - 1
	return s.left(lo).strip_edges(false, true) + "…"

## `text` broken at spaces into rows no wider than `width`, at most `most` of
## them; the last row ends in an ellipsis if words were left over.
static func wrap(s: String, width: float, most: int) -> PackedStringArray:
	var words := s.split(" ", false)
	var rows := PackedStringArray()
	var row := ""
	for i in words.size():
		var trial := words[i] if row == "" else row + " " + words[i]
		if row == "" or text_width(trial) <= width:
			row = trial
		elif rows.size() == most - 1:
			rows.append(clip(row + " " + " ".join(words.slice(i)), width))
			return rows
		else:
			rows.append(row)
			row = words[i]
	if row != "":
		rows.append(row)
	return rows
