class_name SkillEditor
extends Control

## The assembly screen: one weapon's graph. It is deliberately not a safe menu:
## in a raid the world keeps running behind it, so the panel stays translucent
## and compact and every action is a single click.
##
## It is the GRAPH page of a screen with tabs along its top, like a browser's
## (`ScreenTabs`): the map is another page (`MapPanel`), a press on its tab or
## its key away (`page_picked`) — the raid's floor plan in a raid, and
## everywhere else the map's window saying there is no map — and the monster
## dictionary the third (`MonsterDex`).
##
## The root — the weapon's own part — is drawn as a port pointing the way it
## hands the flow over. The hand moves and turns it like any part, but it never
## leaves the board and nothing is dropped on it: it is the weapon's, not the
## bag's.
##
## Down the left of the board stand the weapons whose graphs it opens (`shelf`),
## a plate each with the weapon's own picture on it at the PIXEL grid's two: the
## one open lit in the weapon's colour, and a press on another opening that
## one's graph instead. The weapon in hand stays in hand — every carried weapon
## has a graph and a runner of its own, and this only shows another of them.
## They stand there whenever the screen is on weapons (`configure_shelf`), one
## of them or more; a screen on one board alone (`configure`) has none. Fewer
## than a kit's three, the slots no weapon is in stand after them bare, and last
## of all the empty hand's: plates with nothing on them, for a hand with nothing
## in it. Every one of them opens the empty hand's graph (`Weapons.HAND`), a
## PUNCH at its root, and all of them are lit while it is open — they are the
## same hand. Given no graph for it, they open nothing (`EMPTY_HAND`).
##
## In the middle of the board's right edge is the way out: an arrowhead through
## the frame, where a flow leaves the board and becomes an attack. It is not a
## part, and nothing is placed there — it is lit while a flow reaches it, and in
## the faults' red while none does, which is a board that casts nothing. A flow
## only goes from a part into the one beside it, so what reaches the arrow is a
## chain of parts touching, from the root to the cell against it. It bobs out
## of the board and back, pointing at the end a board's flow has to get to
## (`_way_out_bob`).
##
## Drawn in UiKit's pixel look, like the title and its settings: text is the
## pixel face at PIXEL_TEXT, and every fill, border, arrow and icon is whole
## PIXELs laid on the PIXEL grid, so the board reads as the same pixel art as the
## world under it. All of it goes through `PixelDraw`, which snaps to that grid.
## The pixel face has almost none of the symbols in `Style`'s part glyphs, so
## parts are drawn as their `Style.component_icon` instead — and the one under
## the pointer moving through its film, while that is let move
## (`Video.icon_motion`, `_icon`).
##
## The parts on the right are grouped by the category the rules give them —
## forms, elements, stats and the rest — each block named down the gutter beside
## it in the category's own colour, which is the colour its parts wear.
##
## There is no header over it but the screen's top: the board and the parts
## have the screen, side by side in the middle of it (`_desk_layout`), with the
## back arrow in its top-left corner — the way back every page of the menus has
## in its own — that closes it, the tabs beside it, and COPY and PASTE under the
## board. The screen it is opened over puts its HUD away while it is up: the
## board has the screen, and that corner is where the HUD's bars stand.
## COPY puts the board on the clipboard as a code, and PASTE builds the board
## out of the code on the clipboard. What a pasted code costs is decided here —
## see `_paste_code`.
##
## Against the board's right edge on the same row stand the weapon's presets
## (`GameState.GRAPH_PRESETS`), a plate each numbered from 1, the one on the
## weapon lit in its colour: a press on another puts that graph on the weapon
## and keeps this one as it was, paid for out of the same parts PASTE pays from
## (`GameState.switch_preset`). There are always three, and nothing adds one.
## They stand only where the screen is on a weapon's own graph — the
## workbench's and a raid's (`presets`) — and not on the bench's copies.
##
## **In mobile mode it is laid out for a thumb** (`UiKit.mobile`), and it is a
## different screen rather than this one drawn bigger — see "for a thumb" below.
## A desk's board is worked with a pointer: a wheel to turn a part, a second
## button to take one off, thirty-six parts in rows 20 high to pick from. A
## thumb has none of those. So there the board is as big as the screen lets it
## be, the parts come a category at a time, on tabs, each a tile to press, and
## what the wheel and the second button did are two plates under them: TURN and
## REMOVE, which act on the part a thumb last touched on the board.

signal board_changed()
signal closed()
## A tab along the screen's top was pressed, for a page other than this one:
## the screen that opened it puts that page up in its place.
signal page_picked(id: String)

## The least a desk's cell is across. A desk's board grows its cells past it to
## stand as tall as the parts beside it (`_desk_layout`), and a thumb's to fill
## its room; neither ever shrinks one under it.
const CELL := 50
## The least room a desk's layout leaves at either side of the screen, where the
## weapons, the board and the parts take all the rest.
const EDGE_LEAST := 8.0
## How far apart a desk's board and parts stand, from the board's frame to the
## parts' panel. See `_desk_layout`.
const BOARD_TO_PARTS := 48.0
## How near the parts a desk's board may come once the screen is too narrow to
## stand the weapons, the board and the parts BOARD_TO_PARTS apart: the biggest
## board a Workbench grows, beside the weapons, at 1280 across. The way out
## still has room between them.
const BOARD_TO_PARTS_LEAST := 16.0
## The weapons down the left of a desk's board (`shelf`): a plate each, SHELF_W
## by SHELF_H — the tallest weapon's tile, the bow's, at the PIXEL grid's two,
## with room round it — SHELF_GAP apart, SHELF_AWAY from the board's frame.
const SHELF_W := 44.0
const SHELF_H := 60.0
const SHELF_GAP := 8.0
const SHELF_AWAY := 12.0
## The plate that stands last on every shelf, the empty hand — and one in each
## slot of a kit no weapon is in — when the screen is given no graph for it: no
## weapon, and so no picture, and nothing to open.
const EMPTY_HAND := {"id": "", "board": null, "runner": null}
## How wide the room beside the tabs is, where a category's parts are laid: as
## wide as the two columns of named rows it held when parts had their names
## written on them, so the panel and the board beside it stand where they did.
const PAL_ROOM := 484.0
## The categories stand down the palette's left, a tab each, and the parts of
## the one whose tab is up stand beside them — the way mobile mode's column
## is, and for the same reason: a category's parts are what is looked through,
## and the rest are a press away. A tab is at least PAL_TAB_W across, and as
## wide as the widest word of any category's name, so none is cut
## (`_pal_tab_w`); the parts start PAL_TAB_GAP past the tabs.
const PAL_TAB_W := 112.0
const PAL_TAB_GAP := 10.0
## The space between one tab and the next.
const PAL_GROUP_GAP := 4.0
## The least a tab stands tall: two lines of its name, a long one wrapping
## onto the second. Taller where the panel is — stretched down to the foot of
## a bigger board — since the tabs share out whatever it stands.
const PAL_TAB_LEAST := 46.0
## The least a tab stands where the board beside it cannot grow as tall as the
## panel would be at PAL_TAB_LEAST — a screen too narrow for the cell — and the
## panel comes up to the board's foot instead: two lines of a name, LINE apart,
## and a PIXEL and more clear of them over and under.
const PAL_TAB_FLOOR := 36.0
## The space between one part's tile and the next, at a desk. A tile is a cell
## of the board across, two for a two-cell part — the part as it will stand
## on the board, with no name: hovering it names it on its card.
const PAL_TILE_GAP := 6.0

## No cell of the board: nothing hovered, nothing picked.
const NOWHERE := Vector2i(-1, -1)

## --- for a thumb --------------------------------------------------------------
## Mobile mode's screen, top to bottom and left to right:
##
##   * in the top-left corner the back arrow that closes it, THUMB_BTN square,
##     and beside it the screen's tabs; under it, where there are weapons to
##     choose between, a plate each, THUMB_BTN square, their pictures on them;
##   * the board, in the room under the back arrow and left of the parts, its
##     cells as big as that room lets them be: at a desk a cell is as big as
##     stands the board as tall as the parts, 78 on a first workbench's seven
##     by five, and here that grid stands at 90 — 82 beside the weapons — a
##     thumb's width. Under it, COPY and PASTE, each THUMB_BTN tall, and past
##     them, for the moment one lasts, a refusal or what COPY and PASTE did, on
##     a plate of its own;
##   * down the right, THUMB_PARTS wide and the screen's height, the parts: a
##     tab a category, and beside them the picked category's parts as a desk
##     shows them — each its icon alone, on a tile the size it stands on the
##     board, a cell of it across, rows of them as many as fit the column's
##     width — and under them the name of the part in hand and what it does,
##     since a thumb has no pointer to hover a tile with. A block with more
##     rows than fit the column scrolls, a row at a time. A drag means one
##     thing by the way it goes: up or down the tiles of a block that scrolls
##     it scrolls them, and any other way it takes the part to the board
##     (`_drag_plate`);
##   * under the parts, TURN and REMOVE.
##
## What a thumb does there: a touch on a part's tile takes it in hand, and a
## touch on an empty cell sets it down, facing the way TURN shows. A touch on a
## part on the board picks it — its tile lights, its tab comes up, and its name
## is written under the tiles — and TURN turns it where it stands and REMOVE
## puts it back in the bag. A part dragged is moved, from the tile or across
## the board, and
## one dragged back onto the parts is put away, as at a desk.
const THUMB_EDGE := 16.0
const THUMB_BTN := 64.0
## The least a thumb's COPY or PASTE is across: a word wider than that at a
## thumb's size widens its own.
const THUMB_COPY_W := 136.0
## The parts' column, the tabs down its left, and the room between things in it.
const THUMB_PARTS := 560.0
const THUMB_TAB_W := 132.0
const THUMB_GAP := 4.0
## The most a tab stands; with many categories they stand shorter, to fit.
const THUMB_PLATE := 72.0
## The size what the part in hand does is written at, under a thumb's tiles: the
## page's own, since the face is a pixel face and anything between its size and
## twice it lands its pixels between the screen's (editor_touch_test asks that
## every PIXEL block of the board be one colour). It runs to several lines, and
## stops where the column does.
const THUMB_DESC_TEXT := UiKit.THUMB_TEXT
## TURN and REMOVE, along the foot of the column: a button's height, as CODE and
## CLOSE are.
const THUMB_ACT := THUMB_BTN
## The most a cell is across: past this a short board would be all cells and no
## board. And the least, on a screen too small to be fair to anybody.
const THUMB_CELL_MOST := 98
const THUMB_CELL_LEAST := 34

var board: SkillBoard = null
var inventory: Dictionary = {}       ## component id -> count (the live pool)
var unlimited: bool = false          ## sandbox
var runner: SkillRunner = null       ## the graph running live, for the flow display
## The weapons whose graphs this screen opens, down the left of the board
## (`configure_shelf`): each `{id, board, runner}`, the runner the one showing
## that board live or null, in the order their plates stand. Empty — and nothing
## stands down the board's left — with one weapon or one board to show.
var shelf: Array = []
## Which of them is open: the one `board` and `runner` are.
var shelf_open: int = -1
## The weapon whose graph is open, or "" for a board that is no weapon's.
var weapon: String = ""
## Whether the weapon's presets stand under the board: set by whoever opens the
## screen on the weapons' own graphs, which are the ones a preset is kept for.
var presets: bool = false
## The pages of the screen this is a page of, in the order their tabs stand
## along its top (`ScreenTabs`).
var pages: Array = ScreenTabs.PAGES.duplicate()

var selected: String = ""
var rotation_step: int = 0
var _hover_cell: Vector2i = Vector2i(-1, -1)
var _hover_pal: int = -1
var _hover_shelf: int = -1
var _hover_close: bool = false
## The page whose tab along the top is under the pointer, or "".
var _hover_page: String = ""
var _hover_copy: bool = false
var _hover_paste: bool = false
## The preset whose plate is under the pointer, or -1.
var _hover_preset: int = -1
## Mobile mode's own things to press: a category's tab, by index, and the two
## plates under the parts.
var _hover_tab: int = -1
var _hover_turn: bool = false
var _hover_remove: bool = false
## Which category's parts mobile mode is showing, by index into `_pal_groups`.
var _tab: int = 0
## The part on the board a thumb last touched, by the cell it is filed under:
## what TURN and REMOVE act on. NOWHERE with none.
var _picked: Vector2i = NOWHERE
## A thumb down on a placed part that has not yet moved: the cell and where it
## landed. Lifted, it picks the part; dragged past a thumb's slop, it lifts the
## part off the board the way a desk's press does at once. Empty with none.
var _tap: Dictionary = {}
## The same for a thumb down on a part's tile: where it landed, which tile,
## and the scroll it found — not a take yet, since it may be a scroll
## (`_drag_plate`). `scrolling` once it is one.
var _plate_tap: Dictionary = {}
## Mobile mode's tiles, for a block too long for the column: the first row
## shown, how many rows are and how many there are, the pitch the rows stand
## at — how far a thumb goes to scroll them by one — and the row each part of
## the block is on.
var _plate_first: int = 0
var _plates_shown: int = 0
var _plate_rows: int = 0
var _plate_pitch: float = 0.0
var _tile_row: Dictionary = {}
## Drag state. `_drag_source` is -1 for a part pulled off the palette, 1 for
## one lifted off the board (which remembers where it came from so a bad drop
## can put it back instead of destroying it), and 2 for the root — which is not
## lifted at all: it stays where it stands until it is set down somewhere it
## fits (`SkillBoard.move_root`), so no drop, however bad, leaves the weapon
## without it.
var _drag_id: String = ""
var _drag_source: int = 0
var _drag_from: Vector2i = Vector2i(-1, -1)
var _drag_from_rot: int = 0
var _mouse_pos: Vector2 = Vector2.ZERO
var _trace_cache: Dictionary = {}
var _sim_dirty: bool = true
## How far each part sits from the root along the joints that carry flow, and
## the furthest of them. The edge highlight is driven off these — see
## `_rebuild_flow` — and `_flow_time` is what walks it along.
var _flow_depth: Dictionary = {}
## Every boundary the silhouette does not draw, as Vector3i(cell.x, cell.y,
## dir). Both cells sharing a boundary are filed under it: flush against each
## other they are the same line on screen, and it is the seam neither of them
## draws. A joint that carries flow is one, and so is a seam inside a loop the
## flow can never leave — what is switched off is still one shape.
var _fused_seam: Dictionary = {}
## Every cell of every part the flow only reaches through a trigger's side port.
## What runs along them is drawn in COND_TRACK — see `_rebuild_conditional`.
var _conditional: Dictionary = {}
## The silhouette of each wired shape, as a closed loop of corners. It is worked
## out from the same `_fused` test that decides which seams are drawn, so what
## looks like one shape is one outline. This is what the track is lit along.
var _flow_loops: Array = []
## The dots' runs over those outlines, as {loop, from, span, way}: a stretch of
## one of them, which way round it the dots go and where on it they set off.
## Each stretch runs the way the part under it sends the flow — see `_cut_loop`.
var _flow_arcs: Array = []
## The colour the way out's arrow is drawn in: what, if anything, reaches it.
## See `_rebuild_way_out`.
var _way_out_col: Color = BREAK
var _flow_time: float = 0.0
## What the pointer is on, for the one icon that moves (`_under_pointer`), and
## when it came onto it, by `_flow_time`.
var _under: Array = []
var _under_since: float = 0.0
var _message: String = ""
var _message_time: float = 0.0
## Whether the message is news rather than a refusal: what COPY and PASTE did.
var _message_good: bool = false
## The palette, laid out once per shape of screen, size of board and tab: a
## row per part of the category whose tab is up and, at a desk, a tab per
## category, both drawn and hit-tested from the same rects. See
## `_build_palette`.
var _pal_rows: Array = []
## A desk's category tabs, down the palette's left, by index into `_pal_groups`.
var _pal_tabs: Array = []
var _pal_height: float = 0.0
## Where the palette was laid out from: its first row's top-left, the gutter
## included.
var _pal_origin := Vector2.ZERO
## What the palette was laid out for — the mode, the screen, the tab — so it is
## laid out again when any of them changes. See `_layout_key`.
var _pal_key: Array = []
## The same, for the wiring's outline, which is kept in the screen's own
## coordinates and so goes stale when the board moves or changes size under it.
var _flow_key: Array = []
## Mobile mode's layout, and what it was worked out for. See `_thumb_layout`.
var _thumb_rects: Dictionary = {}
var _thumb_key: Array = []
## A desk's layout, kept for the screen, grid and weapons it was worked out for.
var _desk_rects: Dictionary = {}
var _desk_key: Array = []
## The parts in their blocks, worked out on first use and kept. See `_pal_groups`.
var _groups: Array = []
## Whether a draw is under way, and the cell's size and the board's corner as it
## found them. See `_draw`.
var _drawing := false
var _drawn_cell := 0.0
var _drawn_origin := Vector2.ZERO
var _ports: Array = []               ## PORT turned to face each direction
var _arrows: Array = []              ## ARROW likewise, for mobile mode's TURN
## The board drawn while the root is in hand. See `_shown_board`.
var _lifted: SkillBoard = null
var _px := PixelDraw.new(self)

## Whether the screen is laid out for a thumb: mobile mode.
func thumb() -> bool:
	return UiKit.mobile()

## How big a cell of the board is drawn: at a desk big enough for the board to
## stand as tall as the parts, and for a thumb as big as the room beside the
## parts allows — never under CELL either way.
func cell_size() -> float:
	if _drawing:
		return _drawn_cell
	return float(_thumb_layout()["cell"]) if thumb() else float(_desk_layout()["cell"])

## The top-left corner of the board's first cell.
func board_origin() -> Vector2:
	if _drawing:
		return _drawn_origin
	return _thumb_layout()["origin"] if thumb() else _desk_layout()["board"]

## Everything the layout in force is worked out from: the mode, the screen, the
## grid, the weapons down its left and the tab. What is kept in the screen's
## coordinates — the palette's rows, the wiring's outline — is kept against
## this and worked out again when it changes.
func _layout_key() -> Array:
	var b := current_board()
	return [thumb(), get_viewport_rect().size,
		Vector2i(b.width, b.height) if b != null else Vector2i.ZERO, shelf.size(), _tab, _plate_first]

## Where everything on mobile mode's screen stands, for a screen of this shape
## and a grid of this size: `close` in the top-left corner and the tabs of the
## screen's `pages` beside it; `column`, the parts' whole column, with its
## `tabs`, the `plates` room beside them, and `turn` and `remove` along its foot;
## the board's `cell`, `origin` and `frame`; and `copy` and `paste` under it,
## and `message` past them. COPY and PASTE are as wide as their words, so the
## language is part of what this is worked out for.
func _thumb_layout() -> Dictionary:
	var b := current_board()
	var grid := Vector2i(b.width, b.height) if b != null else Vector2i(7, 5)
	var vp := get_viewport_rect().size
	var groups := _pal_groups().size()
	var key := [vp, grid, groups, Loc.language, shelf.size(), pages.size()]
	if not _thumb_rects.is_empty() and _thumb_key == key:
		return _thumb_rects
	_thumb_key = key
	var l := {}
	var corner := ScreenTabs.back_rect(true)
	l["close"] = corner
	l["pages"] = ScreenTabs.tab_rects(pages, true)
	var column := Rect2(vp.x - THUMB_EDGE - THUMB_PARTS, THUMB_EDGE, THUMB_PARTS, vp.y - THUMB_EDGE * 2.0)
	l["column"] = column
	var acts := column.end.y - THUMB_ACT
	var half := floorf((column.size.x - 8.0) * 0.5 / PX) * PX
	l["turn"] = Rect2(column.position.x, acts, half, THUMB_ACT)
	l["remove"] = Rect2(column.end.x - half, acts, half, THUMB_ACT)
	# The tabs share the height over the two plates, as tall as THUMB_PLATE where
	# there is room and no taller.
	var room := acts - 8.0 - column.position.y
	var tab_h := _plate_height(room, groups)
	var tabs: Array = []
	for i in groups:
		tabs.append(Rect2(column.position.x, column.position.y + float(i) * (tab_h + THUMB_GAP),
			THUMB_TAB_W, tab_h))
	l["tabs"] = tabs
	l["plates"] = Rect2(column.position.x + THUMB_TAB_W + 8.0, column.position.y,
		column.size.x - THUMB_TAB_W - 8.0, room)

	# The board has the rest, under the back arrow and over a row for COPY and
	# PASTE: as big as fits, a cell an odd number of PIXELs so an icon still
	# lands in the middle of one (see `_cell_center`).
	var under := corner.end.y + 12.0
	# The weapons, where there are any to choose between, stand under the back
	# arrow (`_shelf_rect`), and the board's room starts past them.
	var from := THUMB_EDGE + (THUMB_BTN + 12.0 if not shelf.is_empty() else 0.0)
	var space := Rect2(from, under, column.position.x - 16.0 - from,
		vp.y - THUMB_EDGE - THUMB_BTN - 12.0 - under)
	var most := mini(int((space.size.x - 20.0) / float(grid.x)), int((space.size.y - 20.0) / float(grid.y)))
	most = clampi(most, THUMB_CELL_LEAST, THUMB_CELL_MOST)
	var c := most - posmod(most - PX, PX * 2)
	var across := Vector2(grid) * float(c)
	var at := _px.snap(space.position + (space.size - across - Vector2(20, 20)) * 0.5)
	l["cell"] = float(c)
	l["frame"] = Rect2(at, across + Vector2(20, 20))
	l["origin"] = at + Vector2(10, 10)
	var row := Vector2(at.x, (l["frame"] as Rect2).end.y + 12.0)
	l["copy"] = Rect2(row, Vector2(_thumb_copy_width(Loc.t("editor.share.copy")), THUMB_BTN))
	l["paste"] = Rect2(Vector2((l["copy"] as Rect2).end.x + 8.0, row.y),
		Vector2(_thumb_copy_width(Loc.t("editor.share.paste")), THUMB_BTN))
	# The message, for the moment it lasts, past PASTE in the same row: the row
	# along the top is the screen's tabs.
	var past := (l["paste"] as Rect2).end.x + 12.0
	l["message"] = Rect2(past, row.y, column.position.x - 16.0 - past, THUMB_BTN)
	_thumb_rects = l
	return l

## How wide a thumb's COPY or PASTE is for `label`: THUMB_COPY_W, or the word at
## a thumb's size with room either side of it, on the PIXEL grid.
func _thumb_copy_width(label: String) -> float:
	var ink := PixelDraw.ink_width(label, Loc.text_size(label, UiKit.THUMB_TEXT))
	return maxf(THUMB_COPY_W, ceilf((ink + 48.0) / PX) * PX)

## How tall each of `n` plates stands to share `room` between them, THUMB_GAP
## apart: THUMB_PLATE where they fit at that, and less where they do not.
func _plate_height(room: float, n: int) -> float:
	if n <= 0:
		return THUMB_PLATE
	return minf(THUMB_PLATE, floorf(((room + THUMB_GAP) / float(n) - THUMB_GAP) / PX) * PX)

## The part on the board a thumb picked, by its cell — or NOWHERE if there is
## none, or the board has changed under it and nothing is filed there now.
func _picked_part() -> Vector2i:
	var b := current_board()
	if _picked == NOWHERE or b == null or b.comp_origin_at(_picked).is_empty():
		_picked = NOWHERE
	return _picked

## A thumb's touch on the part at `cell`: it is picked, for TURN and REMOVE to
## act on, and a second touch lets it go. Picking takes it in hand as a lift
## would — its kind, and the way it faces — and brings its category's tab up,
## which is where its name is written.
func _pick(cell: Vector2i) -> void:
	var b := current_board()
	if b == null:
		return
	var origin = b.origin_at(cell)
	if origin == null:
		return
	if _picked == origin:
		_picked = NOWHERE
		Audio.play("ui")
		return
	var entry := b.comp_origin_at(origin)
	_picked = origin
	selected = String(entry["id"])
	rotation_step = int(entry["rot"])
	_show_tab(_tab_of(selected), false)
	_show_plate(selected)
	Audio.play("ui")

## Mobile mode's REMOVE: the picked part goes back in the bag.
func _remove_picked() -> void:
	if _picked_part() == NOWHERE:
		Audio.play("deny")
		return
	_take_off(_picked)

## Which tab `id`'s category is on.
func _tab_of(id: String) -> int:
	var groups := _pal_groups()
	for i in groups.size():
		if (groups[i]["ids"] as Array).has(id):
			return i
	return _tab

func _show_tab(i: int, sound: bool = true) -> void:
	if i == _tab:
		return
	_tab = i
	# Another block's tiles come up from its first row.
	_plate_first = 0
	if sound:
		Audio.play("ui")

## Whether the block that is up has more rows of tiles than mobile mode's
## column shows at once, and so scrolls.
func _plates_scroll() -> bool:
	if not thumb():
		return false
	_pal_list()
	return _plates_shown < _plate_rows

## Scrolls mobile mode's tiles so row `first` stands at the top, as far as
## there are rows to bring up.
func _scroll_plates(first: int) -> void:
	_pal_list()
	first = clampi(first, 0, maxi(0, _plate_rows - _plates_shown))
	if first == _plate_first:
		return
	_plate_first = first
	_update_hover(_mouse_pos)

## Scrolls the row `id`'s tile is on into the column, where its block scrolls
## and it is not already shown: what was picked on the board is lit where it
## can be seen.
func _show_plate(id: String) -> void:
	if not _plates_scroll() or not _tile_row.has(id):
		return
	var row := int(_tile_row[id])
	if row < _plate_first:
		_scroll_plates(row)
	elif row >= _plate_first + _plates_shown:
		_scroll_plates(row - _plates_shown + 1)

func _ready() -> void:
	UiKit.fill_screen(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for d in 4:
		_ports.append(PixelDraw.turn(PORT, d))
		_arrows.append(PixelDraw.turn(ARROW, d))
	set_process(true)

func configure(b: SkillBoard, inv: Dictionary, unlim: bool, r: SkillRunner = null) -> void:
	shelf = []
	shelf_open = -1
	weapon = ""
	_put(b, inv, unlim, r)

## Opens the screen on several weapons' graphs, one at a time: `entries` each
## `{id, board, runner}` — the runner the one running that board live, or null
## — in the order their plates stand down the left, and `open` the id of the
## one shown first, or the first if it is none of them. The parts are `inv`'s,
## as `configure` has them. After them stand a bare plate for each slot of a
## kit's three no weapon is in, and the empty hand's, each opening `hand` —
## `{board, runner}`, the empty hand's graph — and `open` "" is that one.
func configure_shelf(entries: Array, open: String, inv: Dictionary, unlim: bool,
		hand: Dictionary = {}) -> void:
	if entries.is_empty():
		return
	var bare: Dictionary = EMPTY_HAND
	if hand.get("board", null) != null:
		bare = {"id": Weapons.HAND, "board": hand["board"], "runner": hand.get("runner", null)}
	shelf = entries.duplicate()
	while shelf.size() < Player.MAX_WEAPONS:
		shelf.append(bare)
	shelf.append(bare)
	var at := 0
	for k in shelf.size():
		var id := String(shelf[k]["id"])
		if shelf[k]["board"] != null and (id == open or (open == "" and id == Weapons.HAND)):
			at = k
			break
	var e: Dictionary = shelf[at]
	_put(e["board"], inv, unlim, e.get("runner", null))
	weapon = String(e["id"])
	shelf_open = at

## A player's kit as a shelf: the weapons they carry, in slot order, the graph
## on each and the runner running it live.
static func shelf_of(p: Player) -> Array:
	var out: Array = []
	for i in mini(p.weapons.size(), p.runners.size()):
		var r: SkillRunner = p.runners[i]
		out.append({"id": p.weapons[i], "board": r.board, "runner": r})
	return out

## A player's empty hand, for `configure_shelf`: its graph and the runner
## running it live.
static func hand_of(p: Player) -> Dictionary:
	return {"board": p.hand_board, "runner": p.hand_runner}

## Opens the graph of the weapon at `i` on the shelf, with the parts as they
## are. The hand is not the screen's to change: the weapon in hand stays.
func _open_shelf(i: int) -> void:
	if i < 0 or i >= shelf.size() or i == shelf_open or shelf[i].get("board", null) == null \
			or shelf[i]["board"] == board:
		return
	Audio.play("ui")
	var e: Dictionary = shelf[i]
	_put(e["board"], inventory, unlimited, e.get("runner", null))
	weapon = String(e["id"])
	shelf_open = i

## The board, the parts and the runner the screen is on, with nothing it had
## worked out about another board kept.
func _put(b: SkillBoard, inv: Dictionary, unlim: bool, r: SkillRunner) -> void:
	board = b
	inventory = inv
	unlimited = unlim
	runner = r
	_sim_dirty = true
	_trace_cache = {}
	_picked = NOWHERE
	_tap = {}
	_plate_tap = {}

func current_board() -> SkillBoard:
	return board

func _process(delta: float) -> void:
	UiKit.sync_screen(self)
	_flow_time += delta
	var under := _under_pointer()
	if under != _under:
		_under = under
		_under_since = _flow_time
	if _message_time > 0.0:
		_message_time -= delta
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_pos = event.position
		_update_hover(event.position)
		_drag_tap()
		_drag_plate()
		accept_event()
	elif event is InputEventMouseButton:
		_mouse_pos = event.position
		_update_hover(event.position)
		if event.pressed:
			match event.button_index:
				MOUSE_BUTTON_LEFT:
					_press_left()
				MOUSE_BUTTON_RIGHT:
					_click_right()
				MOUSE_BUTTON_WHEEL_UP:
					_rotate(CCW)
				MOUSE_BUTTON_WHEEL_DOWN:
					_rotate(CW)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_release_left()
			# A thumb is not hovering once it has lifted: the system hands a touch
			# over as this click, and what it lit goes dark with it rather than
			# staying lit where the thumb last was.
			if event.device == InputEvent.DEVICE_ID_EMULATION:
				_clear_hover()
		accept_event()

## Keys are handled here rather than in _gui_input so they work whether or not
## the panel holds focus, and are marked handled so the screen that opened the
## editor does not act on the same press and re-open it.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	# The map's key is the map's tab: its page up in this one's place.
	if event.is_action_pressed("open_map"):
		page_picked.emit(ScreenTabs.MAP)
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	var key := event as InputEventKey
	# The key that opens it closes it: G as well as TAB, or whatever it is bound
	# to now.
	if key.is_action_pressed("open_editor") and not key.is_command_or_control_pressed():
		closed.emit()
		get_viewport().set_input_as_handled()
		return
	# The clipboard's own keys are COPY and PASTE here, as they are everywhere.
	if key.is_command_or_control_pressed():
		match key.keycode:
			KEY_C:
				_copy()
			KEY_V:
				_paste()
			_:
				return
		get_viewport().set_input_as_handled()
		return
	match key.keycode:
		KEY_R:
			_rotate(CCW)
		KEY_ESCAPE, KEY_TAB:
			closed.emit()
		_:
			return
	get_viewport().set_input_as_handled()

## At a desk the back arrow is a square in the screen's own top-left corner,
## and COPY and PASTE stand under the board, each as wide as its word and no
## narrower than BTN_W.
const CORNER := Vector2(16, 14)
const CLOSE_SIDE := 30.0
const BTN_H := 30.0
const BTN_W := 92.0
const BTN_GAP := 8.0

## Where a desk's board and parts stand: side by side in the middle of the
## screen, BOARD_TO_PARTS apart, the pair halfway across it — the board with
## COPY and PASTE under it, which go where it goes. `board` is the top-left of
## its first cell and `parts` that of the first row, the gutter the category
## names sit in included: what `board_origin` and the palette's rows are laid
## out from; `cell` is how big a cell is drawn, and `tall` how tall the two
## stand, COPY and PASTE left out. The back arrow stays in the screen's own
## corner.
##
## The board and the parts stand on the same lines, top and foot, and COPY and
## PASTE hang under that foot. The board's cells grow until its frame stands as
## tall as the parts' panel — on the PIXEL grid, an odd number of PIXELs so an
## icon lands in the middle of one, never under CELL and no wider than the
## screen has room for — and the panel is stretched down to the frame's foot
## where that came out taller (`_pal_panel`). Where the screen is too narrow
## for a cell that big the panel comes up to the frame's foot instead, its
## tabs shorter, down to PAL_TAB_FLOOR (`_pal_least`). The two, with COPY and
## PASTE under them, are halfway down.
##
## The weapons down the board's left go with it, and the three are in the
## middle together. Where they do not fit BOARD_TO_PARTS apart — the first
## board at a cell grown that big, or the biggest, beside the weapons, on a
## screen 1280 across — the room before the parts is what gives, down to
## BOARD_TO_PARTS_LEAST.
func _desk_layout() -> Dictionary:
	var vp := get_viewport_rect().size
	var b := current_board()
	var grid := Vector2(b.width, b.height) if b != null else Vector2(7, 5)
	var key := [vp, grid, shelf.size()]
	if not _desk_rects.is_empty() and _desk_key == key:
		return _desk_rects
	_desk_key = key
	var panel := _pal_panel_size()
	var weapons := SHELF_W + SHELF_AWAY if not shelf.is_empty() else 0.0
	var foot := BTN_GAP + BTN_H
	var cell := _odd_up(maxf(float(CELL), (panel.y - 20.0) / grid.y))
	var most := (vp.x - EDGE_LEAST * 2.0 - weapons - BOARD_TO_PARTS_LEAST - panel.x - 20.0) / grid.x
	if cell > most:
		cell = maxf(float(CELL), _odd_down(most))
	var frame := grid * cell + Vector2(20, 20)
	var tall := maxf(frame.y, _pal_least(cell))
	var gap := BOARD_TO_PARTS
	var over := weapons + frame.x + gap + panel.x - (vp.x - CORNER.x * 2.0)
	if over > 0.0:
		gap = maxf(BOARD_TO_PARTS_LEAST, gap - over)
	var left := _halfway(vp.x, weapons + frame.x + gap + panel.x) + weapons
	var top := _halfway(vp.y, tall + foot)
	_desk_rects = {
		"board": Vector2(left, top) + Vector2(10, 10),
		"parts": Vector2(left + frame.x + gap, top) + Vector2(10, 10),
		"cell": cell,
		"tall": tall,
	}
	return _desk_rects

## The least size at or over `across` that is a whole, odd number of PIXELs —
## 50, 54, 58 — so an icon centred in a cell that size lands on the grid.
static func _odd_up(across: float) -> float:
	return ceilf((across - PX) / (PX * 2.0)) * PX * 2.0 + PX

## The most at or under `across` that is a whole, odd number of PIXELs.
static func _odd_down(across: float) -> float:
	return floorf((across - PX) / (PX * 2.0)) * PX * 2.0 + PX

## Where the plate of the weapon at `i` on the shelf stands: down the left of a
## desk's board from the top of its frame, and under the back arrow for a thumb.
func _shelf_rect(i: int) -> Rect2:
	if thumb():
		var under := (_thumb_layout()["close"] as Rect2).end.y + 12.0
		return Rect2(Vector2(THUMB_EDGE, under + float(i) * (THUMB_BTN + THUMB_GAP)),
			Vector2(THUMB_BTN, THUMB_BTN))
	var frame := _board_frame()
	return Rect2(Vector2(frame.position.x - SHELF_AWAY - SHELF_W,
		frame.position.y + float(i) * (SHELF_H + SHELF_GAP)), Vector2(SHELF_W, SHELF_H))

## Where a thing `long` across starts, to stand halfway along `room`: on the
## PIXEL grid, and never before the start of it.
static func _halfway(room: float, long: float) -> float:
	return floorf(maxf(room - long, 0.0) * 0.5 / PX) * PX

## The back arrow that closes the screen, in its top-left corner.
func _close_rect() -> Rect2:
	return ScreenTabs.back_rect(thumb())

## COPY, under the board and level with its left edge: the board is what it
## copies, and what PASTE beside it builds.
func _copy_rect() -> Rect2:
	if thumb():
		return _thumb_layout()["copy"]
	var frame := _board_frame()
	return Rect2(Vector2(frame.position.x, frame.end.y + BTN_GAP),
		Vector2(_button_width(Loc.t("editor.share.copy")), BTN_H))

func _paste_rect() -> Rect2:
	if thumb():
		return _thumb_layout()["paste"]
	var copy := _copy_rect()
	return Rect2(Vector2(copy.end.x + BTN_GAP, copy.position.y),
		Vector2(_button_width(Loc.t("editor.share.paste")), BTN_H))

## Whether the weapon's presets stand under the board.
func _shows_presets() -> bool:
	return presets and weapon != "" and not unlimited

## Where the plate of preset `i` stands: on COPY and PASTE's row, square, the
## last against the board's right edge.
func _preset_rect(i: int) -> Rect2:
	var side := THUMB_BTN if thumb() else BTN_H
	var gap := THUMB_GAP if thumb() else BTN_GAP
	var frame := _board_frame()
	var n := GameState.GRAPH_PRESETS
	var x := frame.end.x - float(n) * side - float(n - 1) * gap + float(i) * (side + gap)
	return Rect2(Vector2(x, _copy_rect().position.y), Vector2(side, side))

## A desk's button for `label`: BTN_W, or the word with room either side of it.
func _button_width(label: String) -> float:
	return maxf(BTN_W, ceilf((PixelDraw.ink_width(label) + 40.0) / PX) * PX)

## The frame round the board: ten clear of its cells on every side.
func _board_frame() -> Rect2:
	if thumb():
		return _thumb_layout()["frame"]
	var b := current_board()
	var grid := Vector2(b.width, b.height) if b != null else Vector2(7, 5)
	return Rect2(board_origin() - Vector2(10, 10), grid * cell_size() + Vector2(20, 20))

func _clear_hover() -> void:
	_hover_cell = Vector2i(-1, -1)
	_hover_pal = -1
	_hover_shelf = -1
	_hover_close = false
	_hover_page = ""
	_hover_copy = false
	_hover_paste = false
	_hover_preset = -1
	_hover_tab = -1
	_hover_turn = false
	_hover_remove = false

func _update_hover(pos: Vector2) -> void:
	_clear_hover()
	_hover_close = _close_rect().has_point(pos)
	_hover_page = ScreenTabs.page_at(pages, pos, thumb())
	_hover_copy = _copy_rect().has_point(pos)
	_hover_paste = _paste_rect().has_point(pos)
	if _hover_close or _hover_page != "" or _hover_copy or _hover_paste:
		return
	if _shows_presets():
		for i in GameState.GRAPH_PRESETS:
			if _preset_rect(i).has_point(pos):
				_hover_preset = i
				return
	for i in shelf.size():
		if _shelf_rect(i).has_point(pos):
			_hover_shelf = i
			return
	if not thumb():
		_pal_list()
		for i in _pal_tabs.size():
			if (_pal_tabs[i] as Rect2).has_point(pos):
				_hover_tab = i
				return
	if thumb():
		var l := _thumb_layout()
		var tabs: Array = l["tabs"]
		for i in tabs.size():
			if (tabs[i] as Rect2).has_point(pos):
				_hover_tab = i
				return
		_hover_turn = (l["turn"] as Rect2).has_point(pos)
		_hover_remove = (l["remove"] as Rect2).has_point(pos)
		if _hover_turn or _hover_remove:
			return
	var b := current_board()
	if b != null:
		# A part in hand is held by its middle, so the cell it would be set down
		# by is the one under where that cell is drawn, not under the pointer.
		var rel := pos - _held_offset() - board_origin()
		if rel.x >= 0 and rel.y >= 0:
			var c := Vector2i(int(rel.x / cell_size()), int(rel.y / cell_size()))
			if b.in_bounds(c):
				_hover_cell = c
	if _pal_panel().has_point(pos):
		for i in _pal_list().size():
			if _pal_rect(i).has_point(pos):
				_hover_pal = i
				return

## How far the middle of the part in hand stands from the middle of the cell
## it is set down by — none for a one-cell part, half a cell for a two-cell
## one, the way it is turned — and nothing when the hand is empty.
func _held_offset() -> Vector2:
	if _drag_id == "":
		return Vector2.ZERO
	return _part_rect(_drag_id, Vector2i.ZERO, rotation_step).get_center() \
		- _cell_center(Vector2i.ZERO)

## Every part the palette offers, in the order its rows come — the pool's own
## order, gathered into category blocks.
func _palette_ids() -> Array:
	var ids: Array = []
	for row in _pal_list():
		ids.append(String(row["id"]))
	return ids

## The pool the palette is laid out from: every part there is.
func _pool_ids() -> Array:
	return Components.loot_pool()

## Rotation steps advance clockwise on screen (east -> south), so scrolling up
## turns a part anticlockwise.
const CW := 1
const CCW := -1

## The wheel turns whatever the cursor is on: a part already placed gets rotated
## in place, otherwise it sets the facing for the next placement.
func _rotate(dir: int) -> void:
	if _drag_id == "" and _hover_cell.x >= 0:
		var b := current_board()
		if b != null and not b.comp_at(_hover_cell).is_empty():
			_rotate_placed(b, _hover_cell, dir)
			return
	# With nothing under the cursor, the part a thumb picked — which is what
	# mobile mode's TURN is, there being no cursor to be over anything.
	if _drag_id == "" and _picked_part() != NOWHERE:
		_rotate_placed(current_board(), _picked, dir)
		return
	rotation_step = (rotation_step + dir + 4) % 4
	# Turned in hand, a two-cell part swings round its middle, which the
	# cursor holds: the cell it would land by moves with it.
	if _drag_id != "":
		_update_hover(_mouse_pos)
	Audio.play("ui")

func _rotate_placed(b: SkillBoard, cell: Vector2i, dir: int) -> void:
	var origin: Vector2i = b.origin_at(cell)
	var entry := b.comp_origin_at(origin)
	var id: String = entry["id"]
	var old_rot: int = entry["rot"]
	var new_rot: int = (old_rot + dir + 4) % 4
	# The root turns where it stands, and never off the board on the way.
	if b.is_root(origin):
		if not b.move_root(origin, new_rot):
			_notify(Loc.t("editor.no_room_turn", [Components.name_for(id)]))
			Audio.play("deny")
			return
		rotation_step = new_rot
		_sim_dirty = true
		Audio.play("ui")
		board_changed.emit()
		return
	b.erase_at(origin)
	if not b.can_place(id, origin, new_rot):
		# A two-cell part may have nowhere to swing; leave it as it was.
		b.place(id, origin, old_rot)
		_notify(Loc.t("editor.no_room_turn", [Components.name_for(id)]))
		Audio.play("deny")
		return
	b.place(id, origin, new_rot)
	rotation_step = new_rot
	_sim_dirty = true
	Audio.play("ui")
	board_changed.emit()

## Press starts either a drag (from the palette, or lifting a placed part) or a
## plain click-to-place on an empty cell.
func _press_left() -> void:
	if _hover_close:
		Audio.play("ui")
		closed.emit()
		return
	# The graph's own tab is the page that is up already: a press on it is a
	# press on nothing. Another page's puts that page up, which says so itself.
	if _hover_page != "":
		var id := _hover_page
		_hover_page = ""
		if id != ScreenTabs.GRAPH:
			page_picked.emit(id)
		return
	if _hover_copy:
		_copy()
		return
	if _hover_paste:
		_paste()
		return
	if _hover_preset >= 0:
		_put_preset(_hover_preset)
		return
	if _hover_shelf >= 0 and _drag_id == "":
		_open_shelf(_hover_shelf)
		return
	if _hover_tab >= 0:
		_show_tab(_hover_tab)
		return
	if _hover_turn:
		_rotate(CW)
		return
	if _hover_remove:
		_remove_picked()
		return
	if _hover_pal >= 0:
		# A thumb's press on a plate is not a take yet: up or down the plates it
		# may be a scroll (`_drag_plate`), and lifted where it landed it is a
		# touch (`_release_left`).
		if thumb():
			_plate_tap = {"index": _hover_pal, "at": _mouse_pos, "first": _plate_first}
			return
		_take_from_palette(_hover_pal)
		return
	if _hover_cell.x < 0:
		return
	var b := current_board()
	if b == null:
		return

	# Lifting a placed part: it leaves the board but not the pool, so it can be
	# dropped back down, returned to its old cell, or thrown at the palette. The
	# root is taken in hand the same way, and only ever moved (`_lift`).
	var existing := b.comp_at(_hover_cell)
	if not existing.is_empty():
		# A thumb's press is not a lift yet. It may be a touch — which picks the
		# part, for TURN and REMOVE to act on — and it is only a lift once the
		# thumb has moved off where it landed (`_drag_tap`).
		if thumb():
			_tap = {"cell": _hover_cell, "at": _mouse_pos}
			return
		_lift(b, _hover_cell)
		return

	_picked = NOWHERE
	if selected != "":
		_place_from_palette(_hover_cell)

## Takes the part at `cell` off the board and into the hand. The root comes into
## the hand without coming off the board: it stays where it stands, so the
## weapon is never without it, until it is set down somewhere it fits.
func _lift(b: SkillBoard, cell: Vector2i) -> void:
	var existing := b.comp_at(cell)
	if existing.is_empty():
		return
	_drag_id = String(existing["id"])
	_drag_from = b.origin_at(cell)
	_drag_from_rot = int(existing["rot"])
	rotation_step = _drag_from_rot
	_picked = NOWHERE
	# Held by its middle from here on, wherever on it the press came down.
	_update_hover(_mouse_pos)
	if b.is_root(_drag_from):
		_drag_source = 2
		Audio.play("ui")
		return
	_drag_source = 1
	selected = _drag_id
	b.erase_at(cell)
	_sim_dirty = true
	Audio.play("erase")

## The part on the palette's row `i`, taken in hand, to be dragged or set down.
func _take_from_palette(i: int) -> void:
	selected = String(_palette_ids()[i])
	_drag_id = selected
	_drag_source = -1
	_drag_from = Vector2i(-1, -1)
	_picked = NOWHERE
	_update_hover(_mouse_pos)
	Audio.play("ui")

## A thumb down on a part's plate has moved. Past a thumb's slop, straight up or
## down the plates of a block that scrolls — twice as far that way as across —
## it is a scroll, and from then on the plates go with the thumb a plate at a
## time; any other way it is a drag, and the part is taken in hand under it, as
## at a desk. A part carried to the board's foot goes down as steeply as it goes
## across, and is a drag.
func _drag_plate() -> void:
	if _plate_tap.is_empty():
		return
	var moved := _mouse_pos - (_plate_tap["at"] as Vector2)
	if bool(_plate_tap.get("scrolling", false)):
		_scroll_plates(int(_plate_tap["first"]) - roundi(moved.y / maxf(_plate_pitch, 1.0)))
		return
	if moved.length() <= UiKit.TOUCH_SLOP:
		return
	if absf(moved.y) > absf(moved.x) * 2.0 and _plates_scroll():
		_plate_tap["scrolling"] = true
		_drag_plate()
		return
	var i := int(_plate_tap["index"])
	_plate_tap = {}
	_take_from_palette(i)

## A thumb down on a placed part has moved: past a thumb's slop it is a drag,
## and the part comes up off the board under it.
func _drag_tap() -> void:
	if _tap.is_empty() or _mouse_pos.distance_to(_tap["at"]) <= UiKit.TOUCH_SLOP:
		return
	var cell: Vector2i = _tap["cell"]
	_tap = {}
	var b := current_board()
	if b != null:
		_lift(b, cell)

func _release_left() -> void:
	# A thumb that came down on a plate and lifted where it landed: a touch,
	# which takes the part in hand to be set down. Lifted after a scroll, it did
	# that and nothing more.
	if not _plate_tap.is_empty():
		var tap := _plate_tap
		_plate_tap = {}
		if not bool(tap.get("scrolling", false)):
			_take_from_palette(int(tap["index"]))
			_drag_id = ""
			_drag_source = 0
		return
	# A thumb that came down on a part and lifted where it landed: a touch.
	if not _tap.is_empty():
		var cell: Vector2i = _tap["cell"]
		_tap = {}
		_pick(cell)
		return
	if _drag_id == "":
		return
	var id := _drag_id
	var src := _drag_source
	_drag_id = ""
	_drag_source = 0

	if _hover_cell.x >= 0 and _drop_on(id, src, _hover_cell):
		return
	# The root never left its cell. Thrown at the palette it says why it stays.
	if src == 2:
		if _hover_cell.x < 0 and (_hover_pal >= 0 or _pal_panel().has_point(_mouse_pos)):
			_notify(Loc.t("editor.root_fixed", [Components.name_for(id)]))
			Audio.play("deny")
		return
	if src != 1:
		return  # a palette drag that went nowhere costs nothing

	# Dropping a lifted part on the palette discards it back into the pool;
	# anywhere else invalid, it simply goes back where it was. The whole panel
	# counts, gutter and the gaps between blocks included: a part thrown at the
	# palette was thrown away wherever on it it landed.
	if _hover_pal >= 0 or _pal_panel().has_point(_mouse_pos):
		_give(id)
		Audio.play("erase")
		board_changed.emit()
		return
	var b := current_board()
	if b != null:
		b.place(id, _drag_from, _drag_from_rot)
		rotation_step = _drag_from_rot
	_sim_dirty = true

func _drop_on(id: String, src: int, cell: Vector2i) -> bool:
	var b := current_board()
	if b != null and src == 2:
		return _drop_root(b, cell)
	if b == null or not b.can_place(id, cell, rotation_step):
		if src == -1:
			_notify(Loc.t("editor.no_room_place", [Components.name_for(id)]))
			Audio.play("deny")
		return false
	if src == -1 and not _take(id):
		_notify(Loc.t("editor.none_left", [Components.name_for(id)]))
		Audio.play("deny")
		return false
	# Dropping onto an occupied cell returns the part underneath to the pool.
	var existing := b.comp_at(cell)
	if not existing.is_empty():
		_give(String(existing["id"]))
	b.place(id, cell, rotation_step)
	_sim_dirty = true
	Audio.play("place")
	board_changed.emit()
	return true

## The root set down at `cell`, facing the way the hand has turned it. Only
## where it fits — on the grid, and over nothing but its own cells — and
## otherwise it stays where it was, and says so.
func _drop_root(b: SkillBoard, cell: Vector2i) -> bool:
	if cell == _drag_from and rotation_step == _drag_from_rot:
		return true
	var id := String(b.root_entry().get("id", ""))
	if not b.move_root(cell, rotation_step):
		_notify(Loc.t("editor.no_room_place", [Components.name_for(id)]))
		Audio.play("deny")
		rotation_step = _drag_from_rot
		return false
	_sim_dirty = true
	Audio.play("place")
	board_changed.emit()
	return true

## Whether the part in hand would go down at `cell`: where `can_place` says, or
## for the root where it could move to.
func _fits_held(b: SkillBoard, cell: Vector2i) -> bool:
	if _drag_source == 2:
		return b.can_move_root(cell, rotation_step)
	return b.can_place(_held_id(), cell, rotation_step)

func _place_from_palette(cell: Vector2i) -> void:
	_drop_on(selected, -1, cell)

## Kept for click-driven callers (and the smoke test): press then release.
func _click_left() -> void:
	_press_left()
	_release_left()

func _click_right() -> void:
	if _hover_cell.x < 0:
		return
	_take_off(_hover_cell)

## Takes the part at `cell` off the board and back into the pool: the second
## button's click, and mobile mode's REMOVE. Not the root, which is the
## weapon's and stays on the board.
func _take_off(cell: Vector2i) -> void:
	var b := current_board()
	if b == null:
		return
	var origin = b.origin_at(cell)
	if origin != null and b.is_root(origin):
		_notify(Loc.t("editor.root_fixed", [Components.name_for(String(b.comp_at(cell)["id"]))]))
		Audio.play("deny")
		return
	var removed := b.erase_at(cell)
	if removed != "":
		_give(removed)
		_picked = NOWHERE
		_sim_dirty = true
		Audio.play("erase")
		board_changed.emit()

func _take(id: String) -> bool:
	if unlimited:
		return true
	return GameState.take_component(id, inventory)

func _give(id: String) -> void:
	if unlimited:
		return
	GameState.return_component(id, inventory)

## A line for the moment it lasts: a refusal, or with `good` the news of what
## COPY or PASTE did.
func _notify(msg: String, good: bool = false) -> void:
	_message = msg
	_message_good = good
	_message_time = 2.2

## --- sharing ----------------------------------------------------------------
## A board is a circuit, and a circuit is something a player wants to hand to
## another player. `BoardCode` turns this one into a code and back: COPY puts
## the code on the clipboard, and PASTE builds the board out of the code on it.
## Everything the game has a say in — whether the build fits this workbench's
## grid, and whether the bag can pay for it — is decided here, where the board
## and the pool are. Neither does anything with a part in hand: the board it
## came off is short of it until it is set down.

## One of `BoardCode`'s refusals, spelled out: the id it returns and the numbers
## its line takes, as the line in `localization/<lang>/editor.json` under
## `code_error`. The circuit says what is wrong; the editor says it in words.
static func code_error_text(key: String, args: Array = []) -> String:
	return Loc.t("editor.code_error.%s" % key, args)

## COPY: the board onto the clipboard, as a code.
func _copy() -> void:
	var b := current_board()
	if b == null or _drag_id != "":
		return
	var code := BoardCode.encode(b)
	if code.is_empty():
		_notify(Loc.t("editor.share.uncodeable"))
		Audio.play("deny")
		return
	if not DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		_notify(Loc.t("editor.share.no_clipboard"))
		Audio.play("deny")
		return
	DisplayServer.clipboard_set(code)
	_notify(Loc.t("editor.share.copied", [BoardCode.clean(code).length()]), true)
	Audio.play("ui")

## PASTE: the board built out of the code on the clipboard, whatever else is on
## it dropped on the way — a stray space, a line break.
func _paste() -> void:
	if current_board() == null or _drag_id != "":
		return
	if not DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		_notify(Loc.t("editor.share.no_clipboard"))
		Audio.play("deny")
		return
	var got := BoardCode.clean(DisplayServer.clipboard_get())
	if got.is_empty():
		_notify(Loc.t("editor.share.clipboard_empty"))
		Audio.play("deny")
		return
	_paste_code(got.left(BoardCode.max_chars()))

## The board built out of `entry`, a code: refused whole, with the reason, when
## the code is wrong, the build does not fit this grid, or the bag cannot pay.
func _paste_code(entry: String) -> void:
	var b := current_board()
	if b == null:
		_notify(Loc.t("editor.share.no_board"))
		return
	var read := BoardCode.decode(entry)
	if String(read["error"]) != "":
		_notify(code_error_text(String(read["error"]), read["args"] as Array))
		Audio.play("deny")
		return
	var want: SkillBoard = read["board"]
	# The grid is this workbench's, not the code's, so a build off a bigger one
	# arrives only if none of it hangs over the edge.
	if not b.fits(want):
		_notify(Loc.t("editor.share.wrong_size", [want.width, want.height, b.width, b.height]))
		Audio.play("deny")
		return
	# A code is a blueprint and not the parts: it costs exactly what building the
	# same board by hand would have — for the parts that come onto this board,
	# which leaves out whatever the code has standing where this weapon's own
	# part is — and nothing moves unless all of it can be paid for. The sandbox,
	# where parts are free, is never asked.
	if not unlimited:
		var missing := GameState.trade_board(b, b.adoption_cost(want), inventory)
		if not missing.is_empty():
			_notify(Loc.t("editor.share.short_of", [_missing_text(missing)]))
			Audio.play("deny")
			return
	b.adopt(want)
	_picked = NOWHERE
	_sim_dirty = true
	_trace_cache = {}
	_notify(Loc.t("editor.share.built", [b.cells.size()]), true)
	Audio.play("place")
	board_changed.emit()

## --- presets ----------------------------------------------------------------
## Preset `i` onto the weapon open, in place of the graph on it, which is kept.
## The rules decide what it costs and keep it (`GameState.switch_preset`); this
## only says what came of it. Not with a part in hand: the board it came off is
## short of it until it is set down.
func _put_preset(i: int) -> void:
	if not _shows_presets() or _drag_id != "" or i == GameState.preset_on(weapon):
		return
	var missing := GameState.switch_preset(weapon, i)
	if not missing.is_empty():
		_notify(Loc.t("editor.share.short_of", [_missing_text(missing)]))
		Audio.play("deny")
		return
	_picked = NOWHERE
	_sim_dirty = true
	_trace_cache = {}
	_notify(Loc.t("editor.preset.on", [i + 1]), true)
	Audio.play("place")
	board_changed.emit()

## What a refused paste is short of, in the names the palette uses. The count
## goes in front of the name rather than after it, because several parts carry a
## number in their own name and "DUPLICATE x3 x1" reads as neither of them.
func _missing_text(missing: Dictionary) -> String:
	var ids: Array = missing.keys()
	ids.sort()
	var parts: Array[String] = []
	for id in ids:
		parts.append(Loc.t("editor.share.more_of", [int(missing[id]), Components.name_for(id)]))
	return Loc.t("editor.payload.separator").join(parts)

## --- drawing ----------------------------------------------------------------
const PX := UiKit.PIXEL
const LINE := PixelDraw.LINE

## A part's icon is drawn this many PIXELs per bitmap pixel on the board, and
## one PIXEL per bitmap pixel everywhere else.
const ICON_ZOOM := 2
## An empty cell of the board, and what a part sits on.
const CELL_FILL := Color(0.11, 0.13, 0.17)
const CELL_EDGE := Color(0.2, 0.24, 0.3)

## A part caught in a loop the flow can never leave. It is not drawn faint, the
## way a part nothing reaches is — it is drawn switched off: the category colour
## comes out of it altogether, and the silhouette round it goes to the red the
## faults are marked in, which is what says the loop is the fault. Hovering it
## says so in words.
const DEAD_FILL := Color(0.46, 0.48, 0.53)
const DEAD_EDGE := Color(0.95, 0.35, 0.35)
const DEAD_INK := Color(0.55, 0.57, 0.62)

## The two halves of the flow display. The silhouette round a wired run is lit
## the whole time — it says what is joined to what, which does not change from
## moment to moment — and the movement is carried by dots running that same
## outline. The outline is the track rather than a path through the middle of
## the parts, so a dot never crosses an icon. Both are measured in cells rather
## than in seconds or PIXELs, so they read at the same pace whatever the board
## is doing: a dot covers FLOW_RATE cells of outline a second, and they sit
## FLOW_DOT_SPAN of it apart, which is two to a cell edge.
const FLOW_EDGE := Color(0.6, 1.0, 0.85)
## The track under the dots, lit the whole way round a wired run. It is the same
## colour held low, so a run reads as live even between two dots, and a dot is
## that same line swelling as it passes rather than the only thing on it.
##
## Flat, not a wash: it takes the part edges it runs along rather than tinting
## them, so a wired run wears one colour the whole way round whatever is on it.
## A part keeps its category colour everywhere else — on its fill, its icon and
## any edge off the run — and being wired is what the outline now says.
const FLOW_TRACK := Color(0.3, 0.5, 0.43)
## A branch a trigger only grows when it fires — an ON HIT's side port, and
## everything downstream of it. It is wired, and it is as live as the rest of
## the board, but it is not part of every cycle: the flow takes it only on the
## condition. So it is the same track with the colour drained out of it rather
## than a track of its own, which says it carries flow and says what kind.
const COND_EDGE := Color(0.82, 0.84, 0.88)
const COND_TRACK := Color(0.36, 0.38, 0.42)
const FLOW_RATE := 0.8
## At the least cell. A bigger one — a desk's grown as tall as the parts, or a
## thumb's — keeps the dots two to an edge: see `_flow_dot_span`.
const FLOW_DOT_SPAN := float(CELL) * 0.5
## A dot is a length of the edge itself rather than a mark sitting on top of
## one: this many PIXELs of it, a PIXEL thick like the edge it replaces, so it
## reads as the outline lighting up under it and never bulges off the shape.
##
## It is a dash rather than a speck because of the corners: a dot of a couple of
## PIXELs turns one on paper and shows nothing, where a dash long enough to have
## two arms visibly bends round it. About half of FLOW_DOT_SPAN, so lit and
## unlit come out the same length and the track still reads as running dashes
## rather than as a line with nicks in it.
const FLOW_DOT := 6

## What is wrong is marked in two colours: amber for a flow that runs out into
## nothing — an empty cell, or off the board anywhere but the way out — and red
## for one a part will not take, which is also the way out's colour while no
## flow reaches it.
const LEAK := Color(0.9, 0.6, 0.35)
const BREAK := Color(1.0, 0.4, 0.4)

## What the pixel face has no glyph for, as bitmaps: one string per row, `#` for
## a PIXEL. Arrows point east and are turned to face the others.
const PORT := ["#..", "##.", "###", "##.", "#.."]
const ARROW := ["..#..", "...#.", "#####", "...#.", "..#.."]
const CROSS := ["#...#", ".#.#.", "..#..", ".#.#.", "#...#"]
const DOT := ["###", "###", "###"]
## Wide enough to read as two loops rather than as two more digits — it sits in
## the same column as counts like "x2", and a tighter one came out as "x00".
const INFINITY := [".##...##.", "#..#.#..#", "#...#...#", "#..#.#..#", ".##...##."]
## The way out: an arrowhead through the board's frame, in the middle of its
## right edge. It is cut the way the root's own point is — a PIXEL in for every
## PIXEL out from the middle — so the two read as a pair: the board's flow
## starts at one point and leaves by the other. This many PIXELs from its back,
## against the last cell, to its tip, which is as far outside the frame as the
## room there allows: for a thumb the parts stand sixteen from the board, and at
## a desk the board stands BOARD_TO_PARTS from them.
const WAY_OUT_DEEP := 8
const WAY_OUT_DEEP_THUMB := 12
## How far out of the board the way out bobs and back, in PIXELs, and how long
## one bob takes. It goes no further than the room before the parts allows: on
## a phone's widest board, next to none.
const WAY_OUT_BOB := 2
const WAY_OUT_BOB_TIME := 0.9

func _draw() -> void:
	# The cell's size and the board's corner, asked the once for the whole of
	# this draw. Every rect on the board is worked out from the two of them —
	# near a thousand askings a frame — and for a thumb each one is the layout
	# held up against the screen again. Nothing moves the board mid-draw; a
	# press or a test asking between draws is still answered from the layout.
	_drawing = false
	_drawn_cell = cell_size()
	_drawn_origin = board_origin()
	_drawing = true
	var vp := get_viewport_rect().size
	# Only a light veil: the fight behind this panel has to stay readable. The
	# screen's, so the map's page lies on the same one.
	draw_rect(Rect2(Vector2.ZERO, vp), ScreenTabs.VEIL)
	# The wiring's outline is kept where the board stood when it was worked out.
	# A screen that has changed shape, or mode, has the board somewhere else.
	var laid := _layout_key().slice(0, 4)
	if laid != _flow_key:
		_flow_key = laid
		_sim_dirty = true
	_draw_board()
	_draw_copy_paste()
	_draw_presets()
	_draw_shelf()
	if thumb():
		_draw_thumb_parts()
		_draw_thumb_message()
	else:
		_draw_palette()
		_draw_message(vp)
	_draw_top()
	_draw_hint(vp)
	_draw_drag()
	_drawing = false

## How many PIXELs a pixel of a part's icon is drawn at on the board: ICON_ZOOM
## at the least cell, and more as a bigger one has the room.
func _icon_zoom() -> int:
	return maxi(ICON_ZOOM, int(cell_size() / 25.0))

## A part's icon as it is drawn now: its icon at rest, unless it is the one
## under the pointer (`moving`) and that is let move (`Video.icon_motion`) —
## then where its film has got to since the pointer came onto it, which
## starts it on its first frame, the icon at rest, and goes on from there.
func _icon(id: String, moving: bool) -> Array:
	if moving and Video.icon_motion:
		return Style.component_icon_at(id, _flow_time - _under_since)
	return Style.component_icon(id)

## What the pointer is on, as far as the moving icon goes: the part in hand,
## which is under the pointer wherever it is carried; otherwise the board's
## part under it, and which part that is; otherwise the palette's row; and
## nothing. The film starts again whenever this changes — so it does when one
## part is swapped for another under a pointer standing still.
func _under_pointer() -> Array:
	if _drag_id != "":
		return ["hand", _drag_id]
	var b := current_board()
	if b != null and _hover_cell.x >= 0:
		var at = b.origin_at(_hover_cell)
		if at != null:
			return ["board", at, String((b.cells[at] as Dictionary).get("id", ""))]
	if _hover_pal >= 0:
		return ["parts", _hover_pal]
	return []

## Whether the board's part filed under `origin` is the one under the pointer.
func _pointed_at(origin: Vector2i) -> bool:
	return _under.size() == 3 and _under[0] == "board" and _under[1] == origin

## The same for a port's arrow, which at a thumb's cell is a speck at one.
func _port_zoom() -> int:
	return 2 if cell_size() >= 80.0 else 1

## How far apart the dots sit along the outline, and how many PIXELs of it a dot
## is: two dots to a cell's edge and half of each gap lit, whatever the cell.
func _flow_dot_span() -> float:
	return cell_size() * 0.5

func _flow_dot() -> int:
	return maxi(FLOW_DOT, int(cell_size() * 0.25 / float(PX)))

## The screen's top, over this page: the back arrow in the top-left corner,
## which closes it — the way back a page of the menus has in its own
## (`menu.pause.arrow`), so the corner means the same here as there — and the
## tabs beside it, the graph's lit (`ScreenTabs`).
func _draw_top() -> void:
	ScreenTabs.draw(_px, pages, ScreenTabs.GRAPH, _hover_close, _hover_page, thumb())

## The weapons down the left: a plate each, the weapon's own tile on it at the
## PIXEL grid's two, standing up as the tiles do — the open one lit in its
## colour and drawn whole, the rest dim until the pointer is on one. The empty
## hand's plates are bare, all lit together while its graph is open, and with
## no graph for it they do not light under the pointer.
func _draw_shelf() -> void:
	var on_hand := shelf_open >= 0 and String(shelf[shelf_open]["id"]) == Weapons.HAND
	for i in shelf.size():
		var r := _shelf_rect(i)
		var id := String(shelf[i]["id"])
		var c := Style.weapon_color(id)
		var open := i == shelf_open or (on_hand and id == Weapons.HAND)
		var hot := i == _hover_shelf and shelf[i]["board"] != null
		if thumb():
			_px.plate(r, "", c, hot, open)
		else:
			_px.rect(r, Color(c.r, c.g, c.b, 0.42 if open else (0.18 if hot else 0.06)))
			_px.frame(r, c if open else (Color(1, 1, 1, 0.5) if hot else Color(0.3, 0.32, 0.36)))
		if id == "" or id == Weapons.HAND:
			continue
		var tex := Sprites.texture(Style.weapon_art(id))
		if tex == null:
			continue
		var drawn := tex.get_size() * float(PX)
		draw_texture_rect(tex, Rect2(_px.snap(r.get_center() - drawn * 0.5), drawn), false,
			Color(1, 1, 1, 1.0 if open or hot else 0.55))

## The name of the weapon whose plate is under the pointer, on a card hung off
## the plate's side: a picture says less than a name, the GUN's being a bow —
## and a bare plate says nothing at all, which is why the empty hand's is named.
func _draw_shelf_hint(vp: Vector2) -> void:
	var id := String(shelf[_hover_shelf]["id"])
	if id == "":
		return
	var named := Weapons.name_for(id).to_upper()
	var on := _shelf_rect(_hover_shelf)
	var w := ceilf((PixelDraw.text_width(named) + HINT_PAD * 2.0) / PX) * PX
	var box := Rect2(_px.snap(Vector2(clampf(on.end.x + HINT_GAP, HINT_PAD, vp.x - w - HINT_PAD),
		on.position.y)), Vector2(w, 28.0))
	var c := Style.weapon_color(id)
	_px.rect(box, Color(0.07, 0.08, 0.11))
	_px.rect(box, Color(c.r, c.g, c.b, 0.12))
	_px.frame(box, c)
	_px.text(box.position + Vector2(HINT_PAD, 20.0), named, c)

## COPY and PASTE under the board: a desk's buttons, or a thumb's plates.
func _draw_copy_paste() -> void:
	var buttons := [[_copy_rect(), Loc.t("editor.share.copy"), _hover_copy],
		[_paste_rect(), Loc.t("editor.share.paste"), _hover_paste]]
	for button in buttons:
		var r: Rect2 = button[0]
		var label: String = button[1]
		var hot: bool = button[2]
		if thumb():
			_px.plate(r, label, Color(0.55, 0.9, 1.0), hot, true)
			continue
		_px.button(r, label, hot)

## The presets on COPY and PASTE's row, numbered: the one on the weapon lit in
## the weapon's colour, as its plate down the left is, and the others like
## COPY and PASTE.
func _draw_presets() -> void:
	if not _shows_presets():
		return
	var on := GameState.preset_on(weapon)
	var c := Style.weapon_color(weapon)
	for i in GameState.GRAPH_PRESETS:
		var r := _preset_rect(i)
		var label := str(i + 1)
		var hot := i == _hover_preset
		if thumb():
			_px.plate(r, label, c if i == on else Color(0.55, 0.9, 1.0), hot or i == on, true)
		elif i == on:
			_px.rect(r, Color(c.r, c.g, c.b, 0.42))
			_px.frame(r, c)
			_px.text(r.position + Vector2((r.size.x - PixelDraw.ink_width(label)) * 0.5,
				(r.size.y + 10.0) * 0.5), label, Color(0.95, 0.98, 1.0))
		else:
			_px.button(r, label, hot)

## The board as it is drawn: the board itself, except while the root is in
## hand. The weapon keeps the root where it stands until it is set down
## somewhere it fits (`_lift`), but the hand has it — it is drawn under the
## cursor (`_draw_drag`), so the board is drawn from a copy with it taken off,
## wiring and all, the way a lifted part leaves the board it came off.
func _shown_board() -> SkillBoard:
	var b := current_board()
	if b == null or _drag_id == "" or _drag_source != 2:
		if _lifted != null:
			_lifted = null
			_sim_dirty = true
		return b
	if _lifted == null:
		_lifted = b.without_root()
		_sim_dirty = true
	return _lifted

func _draw_board() -> void:
	var b := _shown_board()
	if b == null:
		return
	var frame := _board_frame()
	_px.rect(frame, Color(0.08, 0.09, 0.12, 0.92))
	_px.frame(frame, Color(0.3, 0.45, 0.6, 0.7))

	for y in b.height:
		for x in b.width:
			var r := _cell_rect(Vector2i(x, y)).grow(-2)
			_px.rect(r, CELL_EDGE)
			_px.rect(r.grow(-PX), CELL_FILL)

	if _trace_cache.is_empty() or _sim_dirty:
		_refresh_trace(b)
		_sim_dirty = false
	for origin in b.cells.keys():
		_draw_component(b, origin)
	# The faults go on after the parts rather than before them: the parts now
	# meet with nothing between them, so a cross sits on the seam itself and
	# would be painted over by whichever part is drawn second.
	_draw_faults()
	_draw_way_out(b)
	_draw_flow_dots()
	# The part a thumb picked, ringed: two PIXELs of white round the whole of it,
	# over the wiring, since it is the one TURN and REMOVE are about.
	if _picked_part() != NOWHERE:
		var entry := b.comp_origin_at(_picked)
		var ring := _part_rect(String(entry["id"]), _picked, int(entry["rot"]))
		_px.frame(ring, Color.WHITE)
		_px.frame(ring.grow(-PX), Color.WHITE)

	# Ghost of the part about to be placed. It is suppressed over an occupied
	# cell unless a part is genuinely in hand, so a placed part's own ports are
	# never overlaid by a second set.
	var held := _held_id()
	var occupied := _hover_cell.x >= 0 and not b.comp_at(_hover_cell).is_empty()
	if _hover_cell.x >= 0 and held != "" and (_drag_id != "" or not occupied):
		# Asked of the board itself: the drawn one has no root to move.
		var ok := _fits_held(current_board(), _hover_cell)
		# One box across the whole footprint, the shape the part would take. A
		# footprint half off the board shows the half that is on it, which is
		# why this grows from the hovered cell rather than from the footprint.
		var ghost := _cell_rect(_hover_cell)
		for c in Components.footprint(held, _hover_cell, rotation_step):
			if b.in_bounds(c):
				ghost = ghost.merge(_cell_rect(c))
		_px.rect(ghost, Color(0.4, 1.0, 0.6, 0.22) if ok else Color(1.0, 0.4, 0.4, 0.22))
		if ok:
			_draw_ports_preview(held, _hover_cell)

	_draw_live_flow(b)

## What the cursor is currently carrying: a dragged part, else the palette pick.
func _held_id() -> String:
	return _drag_id if _drag_id != "" else selected

func _draw_ports_preview(id: String, origin: Vector2i) -> void:
	var ex := Components.exit_cell(id, origin, rotation_step)
	for d in Components.world_outputs(id, rotation_step):
		_draw_port_arrow(ex, d, Color(0.5, 1.0, 0.7, 0.8))
	var p := Components.world_payload_out(id, rotation_step)
	if p >= 0:
		_draw_port_arrow(ex, p, Color(1.0, 0.6, 0.85, 0.8))

## The card a part is described on, and the room it is given: its name, then
## what it does, then — for a part switched off — why. A description is cut
## short past HINT_DESC_ROWS, which every part's fits in, in every language. The
## notice about a ring takes four rows in English; the card grows to however
## many the language being played takes, and only past HINT_DEAD_ROWS is it cut.
const HINT_W := 380.0
const HINT_DESC_ROWS := 8
const HINT_DEAD_ROWS := 6
const HINT_PAD := 8.0
## Between the card and what it is about, which it never covers.
const HINT_GAP := 8.0
## The most rows a card can take: a name, a description, and a ring's notice.
const HINT_MOST_ROWS := 1 + HINT_DESC_ROWS + 1 + HINT_DEAD_ROWS

## What the part under the cursor is and does, on a card hung off it: off its
## row in the parts, or off it on the board. A part switched off says why on the
## same card, under what it does. Nothing is wrong with the part — what is wrong
## is the wiring round it — so the card is hung off the whole ring then.
func _draw_hint(vp: Vector2) -> void:
	# Never with a part in hand, which is already saying something under the
	# cursor.
	if _drag_id != "":
		return
	if _hover_shelf >= 0:
		_draw_shelf_hint(vp)
		return
	var id := ""
	var on := Rect2()
	var dead := false
	if _hover_pal >= 0:
		id = String(_palette_ids()[_hover_pal])
		on = _pal_rect(_hover_pal)
	else:
		# Under a thumb there is no cursor to be over anything: the why is said
		# of the part the thumb picked, and nothing else is — its name is on the
		# tab that came up.
		var about := _hover_cell if _hover_cell.x >= 0 else _picked_part()
		var b := current_board()
		if b == null or about == NOWHERE:
			return
		var origin = b.origin_at(about)
		if origin == null:
			return
		var entry := b.comp_origin_at(origin)
		dead = _dead_at(origin)
		if _hover_cell.x >= 0:
			id = String(entry["id"])
		elif not dead:
			return
		on = _dead_group_rect(b, origin) if dead \
			else _part_rect(String(entry["id"]), origin, int(entry["rot"]))
	var rows := _hint_rows(id, dead)
	var box := _hint_box(vp, on, rows.size())
	var edge := DEAD_EDGE if dead else Style.component_color(id)
	# Opaque: it lands over the board and the panel alike, and two rows of
	# pixel text through each other are unreadable.
	_px.rect(box, Color(0.07, 0.08, 0.11))
	_px.rect(box, Color(edge.r, edge.g, edge.b, 0.12))
	_px.frame(box, edge)
	for i in rows.size():
		_px.text(box.position + Vector2(HINT_PAD, 20.0 + float(i) * LINE),
			rows[i][0], rows[i][1], HINT_W - HINT_PAD * 2.0)

## The card's rows, as [text, colour]: the part `id`'s name in its category's
## colour and what it does under it, and when it is `dead`, the notice saying
## why it is switched off. With no `id`, the notice alone.
func _hint_rows(id: String, dead: bool) -> Array:
	var rows: Array = []
	var width := HINT_W - HINT_PAD * 2.0
	var ink := Color(0.82, 0.86, 0.92)
	if id != "":
		rows.append([Components.name_for(id), Style.component_color(id)])
		for line in PixelDraw.wrap(Components.desc_for(id), width, HINT_DESC_ROWS):
			rows.append([line, ink])
	if dead:
		rows.append([Loc.t("editor.dead.title"), DEAD_EDGE])
		for line in PixelDraw.wrap(Loc.t("editor.dead.body"), width, HINT_DEAD_ROWS):
			rows.append([line, ink])
	return rows

## Where a card of `rows` rows goes for what is boxed by `on`: hung off it rather
## than off the cursor, since a box under the pointer would sit on the very
## thing it names. Below it and to the right, flipped back over it when either
## would run off the screen.
func _hint_box(vp: Vector2, on: Rect2, rows: int) -> Rect2:
	var extent := Vector2(HINT_W, 28.0 + float(maxi(rows - 1, 0)) * LINE)
	var at := on.end + Vector2(HINT_GAP, HINT_GAP)
	if at.x + extent.x > vp.x - HINT_PAD:
		at.x = on.position.x - HINT_GAP - extent.x
	if at.y + extent.y > vp.y - HINT_PAD:
		at.y = on.position.y - HINT_GAP - extent.y
	return Rect2(_px.snap(Vector2(
		clampf(at.x, HINT_PAD, vp.x - extent.x - HINT_PAD),
		clampf(at.y, HINT_PAD, vp.y - extent.y - HINT_PAD))), extent)

## The box round the whole ring the part at `origin` is caught in. The seams
## that came back with the loop are what holds it together: a part is in this
## ring if a seam joins it to something already in it, which is grown until
## nothing more joins. Two separate rings on one board therefore stay separate.
func _dead_group_rect(b: SkillBoard, origin: Vector2i) -> Rect2:
	var group := {origin: true}
	var grew := true
	while grew:
		grew = false
		for link in _trace_cache.get("dead_links", []):
			var from = b.origin_at(link[0])
			var to: Vector2i = link[1]
			if from == null or group.has(from) == group.has(to):
				continue
			group[from] = true
			group[to] = true
			grew = true
	var r := Rect2()
	for o in group:
		var entry := b.comp_origin_at(o)
		if entry.is_empty():
			continue
		var box := _part_rect(String(entry["id"]), o, int(entry["rot"]))
		r = box if r.size == Vector2.ZERO else r.merge(box)
	return r

## How solid the part in hand is drawn over the board: enough to read, and
## little enough that the ghost of where it would land shows through it.
const HELD_OVER_BOARD := 0.6

## The part in hand, drawn the way the board draws it and carried by the cursor:
## its middle under the pointer, turned the way the wheel has it. Over the board it is see-through, so the ghost under it still says
## whether it fits; anywhere else it is solid, since it is dragged over the
## palette and two rows of pixel text through each other are unreadable.
func _draw_drag() -> void:
	if _drag_id == "":
		return
	var id := _drag_id
	var rot := rotation_step
	var col := Style.component_color(id)
	var fade := HELD_OVER_BOARD if _hover_cell.x >= 0 else 1.0
	# Drawn at the board's top-left cell and carried to the cursor whole, by
	# whole PIXELs, so it comes out the shape the board gives it.
	var middle := _part_rect(id, Vector2i.ZERO, rot).get_center()
	draw_set_transform(((_mouse_pos - middle) / PX).round() * PX)
	# The root comes to its point in hand as it does on the board.
	var cut := -1
	if _drag_source == 2:
		var outs := Components.world_outputs(id, rot)
		cut = int(outs[0]) if not outs.is_empty() else -1
	_draw_part(id, Vector2i.ZERO, rot, cut, [
		_faded(Color(col.r, col.g, col.b, 0.28), fade), _faded(col.lightened(0.45), fade),
		_faded(col.lightened(0.3), fade), _faded(col.lightened(0.4), fade),
		_faded(Color(1.0, 0.55, 0.8), fade)], fade, true)
	draw_set_transform(Vector2.ZERO)

## `col` with its alpha scaled by `fade`.
func _faded(col: Color, fade: float) -> Color:
	return Color(col.r, col.g, col.b, col.a * fade)

func _cell_rect(c: Vector2i) -> Rect2:
	var side := cell_size()
	return Rect2(board_origin() + Vector2(c.x * side, c.y * side), Vector2(side, side))

## CELL is an odd number of PIXELs, so the middle of a cell is the middle of a
## PIXEL, and a bitmap an odd number of PIXELs across centres on it exactly. A
## thumb's cell is held to the same (`_thumb_layout`).
func _cell_center(c: Vector2i) -> Vector2:
	var side := cell_size()
	return board_origin() + Vector2(c.x * side + side * 0.5, c.y * side + side * 0.5)

## An arrow out of `at` across its `dir` edge, the point on the edge itself.
func _draw_port_arrow(at: Vector2i, dir: int, col: Color) -> void:
	var v := Vector2(Components.dir_to_vec(dir))
	var zoom := _port_zoom()
	_px.icon_centered(_cell_center(at) + v * (cell_size() * 0.5 - 3.0 * zoom), _ports[dir % 4], col, zoom)

## The wiring and the order the flow reaches it in are read off the same walk
## of the board, and both go stale on the same edit, so they are taken together.
func _refresh_trace(b: SkillBoard) -> void:
	_trace_cache = b.trace()
	_rebuild_flow(b)
	# Before the outline, which is drawn in two colours off the back of it.
	_rebuild_conditional(b)
	# After the joints, never before: the outline is drawn round whatever they
	# fused together.
	_rebuild_outline(b)
	_rebuild_way_out(b)

## How many joints each part sits from the root. `SkillBoard.trace` walks the
## board breadth-first and emits a link the first time the flow reaches its
## target, so reading the links back in that order settles every part at its
## shortest depth without walking the board a second time.
func _rebuild_flow(b: SkillBoard) -> void:
	_flow_depth = {}
	_fused_seam = {}
	# A ring with no way out is one shape whether or not anything feeds it, so
	# its own seams are taken off the wiring rather than off the walk below —
	# an unfed one would otherwise come out as a box round each of its parts.
	for link in _trace_cache.get("dead_links", []):
		_fuse(link[0], link[1])
	var input = b.find_root()
	if input == null:
		return
	_flow_depth[input] = 0
	for link in _trace_cache.get("links", []):
		# A link leaves by a part's exit cell, which on a two-cell part is not
		# the cell the part is filed under; both ends are resolved to origins.
		var exit_cell: Vector2i = link[0]
		var to: Vector2i = link[1]
		var from = b.origin_at(exit_cell)
		if from == null or not _flow_depth.has(from):
			continue
		# A link that runs back into a part already reached — a ring closing —
		# still fuses its own seam, which is why this is done before the depth
		# is settled below. The one seam left drawn is the one onto a dead ring:
		# the live wiring stops at its edge and the red goes right round it,
		# rather than the two running into each other as a single shape.
		var from_origin: Vector2i = from
		if _dead_at(from_origin) == _dead_at(to):
			_fuse(exit_cell, to)
		if _flow_depth.has(to):
			continue
		_flow_depth[to] = int(_flow_depth[from]) + 1

## The boundary between two cells that sit against each other, filed under both.
func _fuse(exit_cell: Vector2i, to: Vector2i) -> void:
	var dir := _step_dir(to - exit_cell)
	if dir < 0:
		return
	_fused_seam[Vector3i(exit_cell.x, exit_cell.y, dir)] = true
	_fused_seam[Vector3i(to.x, to.y, Components.opposite(dir))] = true

## Whether the part filed under `origin` is caught in a loop the flow can never
## leave. `SkillBoard.dead_loops` is what works that out; this is the editor
## asking the board about one part.
func _dead_at(origin: Vector2i) -> bool:
	return (_trace_cache.get("dead", {}) as Dictionary).has(origin)

## Every cell the flow only reaches by way of a trigger's side port: the branch
## an ON HIT grows when it fires, and everything downstream of that.
##
## Read as what is *left over*: the flow is walked from the root with every
## trigger's branch taken away, and whatever it can still reach is part of every
## cycle. A part on both — a branch that rejoins the main line, or one two
## triggers feed — is reached without the branch and so is not conditional,
## which is the right answer for it: it runs whether or not the trigger fires.
func _rebuild_conditional(b: SkillBoard) -> void:
	_conditional = {}
	var input = b.find_root()
	if input == null:
		return
	var straight: Dictionary = {}
	for link in _trace_cache.get("links", []):
		var exit_cell: Vector2i = link[0]
		var to: Vector2i = link[1]
		var from = b.origin_at(exit_cell)
		if from == null:
			continue
		if _is_branch(b, exit_cell, _step_dir(to - exit_cell)):
			continue
		straight[from] = (straight.get(from, []) as Array) + [to]
	var sure: Dictionary = {input: true}
	var queue: Array = [input]
	while not queue.is_empty():
		var origin: Vector2i = queue.pop_front()
		for to in straight.get(origin, []):
			if sure.has(to):
				continue
			sure[to] = true
			queue.append(to)
	for origin in _flow_depth.keys():
		if sure.has(origin):
			continue
		var entry := b.comp_origin_at(origin)
		if entry.is_empty():
			continue
		for c in Components.footprint(String(entry["id"]), origin, int(entry["rot"])):
			_conditional[c] = true

## Whether the flow leaving `exit_cell` heading `dir` is a trigger's branch: the
## flow out of its side port rather than the one it passes on.
func _is_branch(b: SkillBoard, exit_cell: Vector2i, dir: int) -> bool:
	var from = b.origin_at(exit_cell)
	if from == null:
		return false
	var entry := b.comp_origin_at(from)
	return not entry.is_empty() \
		and dir == Components.world_payload_out(String(entry["id"]), int(entry["rot"]))

## The two colours a stretch of track is lit in: the flow's own, or the drained
## one where what it runs along only carries flow on a trigger's condition.
func _track_colors(cell: Vector2i) -> Array:
	if _conditional.has(cell):
		return [COND_TRACK, COND_EDGE]
	return [FLOW_TRACK, FLOW_EDGE]

## The silhouette of every wired shape, as closed loops of points. Only parts
## the flow reaches are outlined: a part it cannot reach is not wired to
## anything, so it gets no track and carries no dots. Nor is a ring the flow
## reaches but can never leave — the flow really does go round it, and a track
## running dots round and round is exactly the reading it must not have.
##
## The track is drawn round the parts the root feeds, with the root itself left
## out of it. That is what puts its first tip on the side of the root the run
## leaves by: with a board running left to right, the track leaves the middle of
## the root's right edge, goes over and under everything after it, and meets
## again in the middle of the last part's far side, where the flow leaves it —
## through the frame, on a board that fires. The root is lit all the same, as a
## shape of its own whose dots run out to its point: see `_rebuild_root_outline`.
##
## It is the boundary of that region rather than the lit silhouette, so the
## side facing the root counts even though it is fused and never drawn — that
## is the tip the dots set off from. Each cell contributes one directed edge
## per open side, walked with the region on its right, and chaining those end to
## start gives loops that run clockwise on screen. A region with a hole in it
## yields the hole as a loop of its own, so the dots run that too.
##
## A side is only open onto what it is *joined* to, never onto what merely
## touches it: a run that comes back alongside itself — four parts wired round a
## square, say — has a seam down the middle with no flow across it, and the
## track goes in along one side of that seam and back out along the other. Both
## sides of it are outlined, so the dots follow the run rather than short-
## cutting from one leg of it to the next.
##
## Which way the dots then run round each of them is `_cut_loop`'s, and it is
## the way the flow runs: the shape of the outline says what is joined to what,
## and the wiring under it says which way it is going.
func _rebuild_outline(b: SkillBoard) -> void:
	_flow_arcs = []
	_flow_loops = []
	_rebuild_root_outline(b)
	var ends := _flow_ends(b)
	if ends.is_empty():
		return
	# The root is always left out: the run starts where it hands the flow over.
	# The far end is a part like any other, as wired as the ones behind it, so
	# it is outlined with them.
	var mid := {}
	for origin in b.cells.keys():
		if not _flow_depth.has(origin) or origin == ends[0] or _dead_at(origin):
			continue
		var entry: Dictionary = b.cells[origin]
		var cells := Components.footprint(String(entry["id"]), origin, int(entry["rot"]))
		for c in cells:
			# The part each cell belongs to, so a side can be asked whether it
			# is joined to what is on the other side of it.
			mid[c] = cells
	var edges := {}
	for c in mid.keys():
		for d in 4:
			# Touching is not joined. Two parts side by side with no flow
			# between them are two shapes however close they sit, so the track
			# runs down the seam and back out rather than straight over it —
			# the dots then go the way the flow goes instead of cutting a
			# corner the flow never cuts. It is the same test the edges are
			# drawn by, so the track keeps to the shape they draw.
			if mid.has(c + Components.dir_to_vec(d)) and _fused(mid[c], c, d):
				continue
			var seg := _outline_edge(c, d)
			var k := _point_key(seg[0])
			if not edges.has(k):
				edges[k] = []
			(edges[k] as Array).append(seg)
	# More than one edge can start at the same point — where four cells meet
	# corner to corner, and at either end of a seam the track runs down — and
	# which is taken decides the shape that comes out. The one turning furthest
	# right is, every time: that is what keeps the region on the right hand all
	# the way round, so the walk turns into a seam rather than carrying on over
	# it, and two parts touching only at a corner stay two shapes.
	#
	# The walk is over when it comes back to where it set off *and the outline
	# closes there*, which is not the same thing: a point the outline passes
	# through twice is passed twice. The mouth of a seam is exactly that — the
	# track runs in along one side and back out along the other, and both sides
	# meet the rest of the shape at the same corner — so stopping at the first
	# return would leave the far half of the seam lying about as a fragment of
	# its own, and the track would come up short of where the flow crosses.
	# Whether it closes is the same right-hand question as every other step: it
	# does when the turn asked for here is the edge the walk set off along.
	var flow := _flow_through(b, mid)
	var crossings := _crossings(b, mid)
	for start in edges.keys():
		while not (edges[start] as Array).is_empty():
			var loop := PackedVector2Array()
			var owners: Array = []
			var at: Vector2i = start
			var heading := Vector2.ZERO
			var first: Array = []
			while true:
				var here: Array = edges.get(at, [])
				if here.is_empty():
					break
				if at == start and not first.is_empty():
					if _rightmost(here + [first], heading) == here.size():
						break
				var pick := _rightmost(here, heading)
				var seg: Array = here[pick]
				here.remove_at(pick)
				if first.is_empty():
					first = seg
				loop.append(seg[0])
				owners.append(seg[2])
				heading = ((seg[1] as Vector2) - (seg[0] as Vector2)).normalized()
				at = _point_key(seg[1])
			# Two corners is a seam with the shape closed round both of its ends
			# — a branch that comes back alongside the line it left, and joins
			# it again at the far end. It is a crack rather than a slot cut in
			# from the outside, and it is as much of the outline as the rim is:
			# the two parts along it are not joined, and the track saying so is
			# the whole point. Anything shorter is not a shape at all.
			if loop.size() >= 2:
				_flow_loops.append({"loop": loop, "owners": owners})
				_cut_loop(loop, owners, flow, crossings, _flow_head(b, ends[0]),
					_flow_head(b, ends[1]))

## The root's own outline, lit the way a wired part's is, with its dots setting
## off from the middle of its back and going both ways round to its point. That
## point is the tip the run after it sets off from, so the flow is seen to come
## out of the weapon's own part rather than to start beside it.
##
## A shape of its own rather than one with what it feeds: joined to it, the seam
## its point sits on would be inside the shape, and the run after it would have
## nowhere to set off from but the root's own back. It is lit only while it hands
## the flow on to something that carries it — the same test as every other part:
## see `_hands_over`.
func _rebuild_root_outline(b: SkillBoard) -> void:
	var input = b.find_root()
	if input == null:
		return
	var entry := b.comp_origin_at(input)
	var id := String(entry["id"])
	var rot := int(entry["rot"])
	var cut := _port_cut(b, id, input, rot)
	if cut < 0 or not _hands_over(Components.exit_cell(id, input, rot)):
		return
	var f := _port_frame(_part_rect(id, input, rot), cut)
	var loop := _port_outline(f)
	var owners: Array = []
	for i in loop.size():
		owners.append(input)
	_flow_loops.append({"loop": loop, "owners": owners})
	# The tip strip is the middle one, and the back is cut level with it.
	@warning_ignore("integer_division")
	var across := (float((int(f[4]) - 1) / 2) + 0.5) * float(PX)
	var base: Vector2 = f[0]
	var w: Vector2 = f[2]
	_cut_at_ends(loop, owners, base + w * across,
		base + (f[1] as Vector2) * float(f[3]) + w * across, _loop_length(loop))

## Whether the flow out of `exit_cell` goes somewhere that carries it on: into a
## part not caught in a loop it can never leave, or out by the way out.
func _hands_over(exit_cell: Vector2i) -> bool:
	for out in _trace_cache.get("outs", []):
		if out["from"] == exit_cell:
			return true
	for link in _trace_cache.get("links", []):
		if link[0] == exit_cell and not _dead_at(link[1]):
			return true
	return false

## Which of the edges starting here to take next, as an index into `here`:
## whichever turns furthest right from the way the walk arrived. Right first,
## then straight on, then left, and back the way it came only when nothing else
## is on offer — that last is the far end of a seam, where the track has run in
## along one side and comes back along the other. With nothing arrived from,
## anything will do and the last is taken, as it always was.
func _rightmost(here: Array, heading: Vector2) -> int:
	if heading == Vector2.ZERO:
		return here.size() - 1
	var best := 0
	var best_rank := 4
	for i in here.size():
		var seg: Array = here[i]
		var way := ((seg[1] as Vector2) - (seg[0] as Vector2)).normalized()
		var turn := heading.cross(way)
		var rank := 0 if turn > 0.0 else (2 if turn < 0.0 else (1 if heading.dot(way) > 0.0 else 3))
		if rank < best_rank:
			best_rank = rank
			best = i
	return best

## Where the dots set off from and where they are heading: the root, and the
## part the flow finishes on, which is the furthest one it reaches. Empty when
## there is nothing to run between, as on a board that is only its root, and
## then no shape is outlined at all — the root's flow is the line to the way out
## and nothing else.
func _flow_ends(b: SkillBoard) -> Array:
	var input = b.find_root()
	if input == null:
		return []
	var best = null
	var best_rank := -1
	for origin in _flow_depth.keys():
		var entry := b.comp_origin_at(origin)
		# A dead ring is where the run stops, never where it is going: the dots
		# end on the last part that still leads somewhere.
		if entry.is_empty() or _dead_at(origin):
			continue
		var rank := int(_flow_depth[origin])
		if rank > best_rank:
			best_rank = rank
			best = origin
	if best == null or best == input:
		return []
	return [input, best]

## The middle of the seam a part sends its flow across. At either end of a run
## that is a tip of the outline: the root hands the flow over on one, and the
## last part is where it leaves on the other.
##
## The middle of the *part* will not do, a whole cell from the outline as it is.
## It comes out exactly as near some other side of the shape — a run leaving
## west has the cell it leaves into sitting exactly as far above whatever is
## below it — and the tip then lands wherever the arithmetic settles the tie
## rather than where the flow crosses. On the seam itself there is no tie.
func _flow_head(b: SkillBoard, origin: Vector2i) -> Vector2:
	var entry := b.comp_origin_at(origin)
	if entry.is_empty():
		return _part_center(b, origin)
	var id := String(entry["id"])
	var rot := int(entry["rot"])
	var outs := Components.world_outputs(id, rot)
	if outs.is_empty():
		return _part_center(b, origin)
	var v := Vector2(Components.dir_to_vec(int(outs[0])))
	return _cell_center(Components.exit_cell(id, origin, rot)) + v * (cell_size() * 0.5)

## The middle of the part filed under `origin`, which on a two-cell part is the
## middle of both its cells rather than of either one.
func _part_center(b: SkillBoard, origin: Vector2i) -> Vector2:
	var entry := b.comp_origin_at(origin)
	if entry.is_empty():
		return _cell_center(origin)
	return _part_rect(String(entry["id"]), origin, int(entry["rot"])).get_center()

## Which way the flow crosses each cell of the wired region, as the sum of the
## steps it takes over that cell's edges: a cell in the middle of a straight run
## is entered and left the same way and comes out pointing hard along it, and a
## part the flow turns on comes out pointing into the corner. Both ends of a
## step count, so a cell fed from outside the region — the one the root hands
## over to — still knows which way the flow arrived. Leaving by the way out is a
## step too, so the last part of a run knows which way it lets go.
##
## The two cells of a two-cell part are a step of their own: nothing is wired
## between them, but the flow crosses from the one to the other all the same.
func _flow_through(b: SkillBoard, mid: Dictionary) -> Dictionary:
	var flow: Dictionary = {}
	for step in _flow_steps(b):
		var from: Vector2i = step[0]
		var to: Vector2i = step[1]
		var way := Vector2(to - from)
		if way == Vector2.ZERO:
			continue
		way = way.normalized()
		for c in [from, to]:
			if mid.has(c):
				flow[c] = (flow.get(c, Vector2.ZERO) as Vector2) + way
	return flow

## Every step the flow takes from one cell into the next, as [from, to]: the
## links the walk found, each way out of the board, and a two-cell part's own
## step from the cell it is filed under to the one it emits from.
func _flow_steps(b: SkillBoard) -> Array:
	var steps: Array = []
	for link in _trace_cache.get("links", []):
		steps.append([link[0], link[1]])
	for out in _trace_cache.get("outs", []):
		var from: Vector2i = out["from"]
		steps.append([from, from + Components.dir_to_vec(int(out["dir"]))])
	for origin in b.cells.keys():
		var entry: Dictionary = b.cells[origin]
		var ex := Components.exit_cell(String(entry["id"]), origin, int(entry["rot"]))
		if ex != origin:
			steps.append([origin, ex])
	return steps

## Where the flow crosses the edge of the wired region, as Vector3i(cell.x,
## cell.y, dir) for the side of a cell in it: 1 where the flow comes in across
## that side — from the root — and -1 where it leaves — by the way out, back
## into the root round a ring, or into a ring it never comes out of.
##
## These are the ends of a run, and they are found here rather than read off
## which way a cell is crossed, which only finds them on a cell the flow goes
## straight across. A trigger that sends its branch off sideways, or a part the
## flow turns a corner on, is crossed on a slant, and none of its sides is
## square to that: the run then set off from a corner of it, or ended on one.
func _crossings(b: SkillBoard, mid: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for step in _flow_steps(b):
		var from: Vector2i = step[0]
		var to: Vector2i = step[1]
		var dir := _step_dir(to - from)
		if dir < 0:
			continue
		if mid.has(from) and not mid.has(to):
			out[Vector3i(from.x, from.y, dir)] = -1
		elif mid.has(to) and not mid.has(from):
			out[Vector3i(to.x, to.y, Components.opposite(dir))] = 1
	return out

## A closed outline cut into the runs the dots travel along, each stretch of it
## going the way the part it runs along sends the flow. That is the whole of the
## rule, and both readings fall out of it:
##
##   * A run with two ends — a line of parts from the root towards the way out
##     — has its two long sides pointing the same way and its two end caps
##     pointing across. The caps are where the runs meet, so the dots leave the
##     middle of the cap the root feeds, go both ways round, and arrive at the
##     middle of the one the flow leaves by. Nothing circles, exactly as before.
##     A cap is the side the flow crosses there (`crossings`), whichever way the
##     part behind it then turns the flow.
##   * A branch that comes back round — a ring, or a trigger's branch running
##     home along the row below — has every side pointing the same way round the
##     shape. There is no cap to meet at, so the dots go round with the flow
##     instead of one half of them running against it.
##
## `owners` is the cell each side of the outline belongs to, `flow` which way
## that cell is crossed and `crossings` the sides the flow comes in or goes out
## across; `head` and `tail` are only the fallback, for a shape with nothing
## wired to say which way it goes.
func _cut_loop(loop: PackedVector2Array, owners: Array, flow: Dictionary,
		crossings: Dictionary, head: Vector2, tail: Vector2) -> void:
	var total := _loop_length(loop)
	if total <= 0.0:
		return
	var runs := _runs_along(loop, owners, flow, crossings, total)
	if runs.is_empty():
		_cut_at_ends(loop, owners, head, tail, total)
		return
	for run in runs:
		_flow_arcs.append({"loop": loop, "owners": owners, "from": run["from"],
			"span": run["span"], "way": run["way"]})

## The outline split into stretches that carry their dots the same way, as
## [{from, span, way}] — `from` being where the dots on that stretch set off and
## `way` which way round the loop they then go, so a stretch the flow runs
## against the outline is kept from its far end.
##
## A side the flow crosses — in from the root, or out to wherever the run goes
## next (`crossings`) — is an end of the run, and is halved: the middle of it is
## the middle of the seam the flow crosses there, which is where the root hands
## over and where the last part lets go. The dots set off from that middle both
## ways where the flow comes in, and meet there where it goes out.
##
## Any other side square to the way its own cell is crossed decides nothing by
## itself: it is a cap, and it takes the way of the sides around it. Where those
## two disagree the cap is where the dots are born or die, and it is halved too.
##
## Empty when no side of the shape has anything to say, which is a shape the
## flow reaches without crossing any of its cells.
func _runs_along(loop: PackedVector2Array, owners: Array, flow: Dictionary,
		crossings: Dictionary, total: float) -> Array:
	var n := loop.size()
	var ways: Array = []
	var cross: Array = []
	var starts: Array = []
	var walked := 0.0
	for i in n:
		var step := loop[(i + 1) % n] - loop[i]
		var cell: Vector2i = owners[i]
		# Which side of its cell this is: the one it faces out of, on the
		# outline's left, since the shape is always on its right.
		var side := posmod(_step_dir(Vector2i(step.sign())) - 1, 4)
		var c := int(crossings.get(Vector3i(cell.x, cell.y, side), 0))
		var f: Vector2 = flow.get(cell, Vector2.ZERO)
		var along := step.normalized().dot(f)
		# A side the flow crosses runs by its halves (`_crossing_halves`), not
		# by the way its cell is crossed.
		ways.append(0 if c != 0 or is_zero_approx(along) else (1 if along > 0.0 else -1))
		cross.append(c)
		starts.append(walked)
		walked += step.length()
	# What each side says at its start and at its end: the same at both for a
	# side the flow runs along, one thing at each end for a side it crosses,
	# and nothing yet for a cap.
	var said: Array = []
	var any := false
	for i in n:
		var pair: Array = [int(ways[i]), int(ways[i])]
		if int(cross[i]) != 0:
			pair = _crossing_halves(int(cross[i]), _nearest_way(ways, cross, i, -1),
				_nearest_way(ways, cross, i, 1))
		said.append(pair)
		any = any or int(pair[0]) != 0
	if not any:
		return []
	# Each cap takes the run it sits between, and is cut in half when the two
	# disagree: that is an end of the flow, not a corner it carries on round.
	var pieces: Array = []
	for i in n:
		var from: float = starts[i]
		var span: float = (starts[(i + 1) % n] if i + 1 < n else total) - from
		var first := int(said[i][0])
		var second := int(said[i][1])
		if first == 0:
			first = _nearest_said(said, i, -1)
			second = _nearest_said(said, i, 1)
		if first == second:
			pieces.append({"from": from, "span": span, "way": first})
			continue
		pieces.append({"from": from, "span": span * 0.5, "way": first})
		pieces.append({"from": from + span * 0.5, "span": span * 0.5, "way": second})
	# Neighbours going the same way are one run, the last and the first
	# included: a shape the flow circles has no break in it anywhere.
	var runs: Array = []
	for p in pieces:
		if not runs.is_empty() and int(runs[-1]["way"]) == int(p["way"]):
			runs[-1]["span"] = float(runs[-1]["span"]) + float(p["span"])
			continue
		runs.append(p.duplicate())
	if runs.size() > 1 and int(runs[0]["way"]) == int(runs[-1]["way"]):
		runs[0]["from"] = runs[-1]["from"]
		runs[0]["span"] = float(runs[0]["span"]) + float(runs[-1]["span"])
		runs.remove_at(runs.size() - 1)
	# Forward runs set off where they begin; a run the dots take backwards sets
	# off at its far end, which is where the flow enters it.
	for run in runs:
		if int(run["way"]) < 0:
			run["from"] = fposmod(float(run["from"]) + float(run["span"]), total)
		run["way"] = float(run["way"])
	return runs

## The way the nearest side either side of `i` runs at the end facing it,
## `step` being which way to look. A side the flow crosses (`cross`) is taken
## as its halves run when nothing turns them: its second half looking back, its
## first looking on. Zero if no other side has anything to say.
func _nearest_way(ways: Array, cross: Array, i: int, step: int) -> int:
	var n := ways.size()
	for k in range(1, n):
		var j := posmod(i + step * k, n)
		var c := int(cross[j])
		if c != 0:
			return c if step < 0 else -c
		var w := int(ways[j])
		if w != 0:
			return w
	return 0

## What the nearest side either side of `i` says at the end facing it — its end
## looking back, its start looking on — `step` being which way to look. Zero
## only if nothing on the loop has anything to say, which the caller has
## already ruled out.
func _nearest_said(said: Array, i: int, step: int) -> int:
	var n := said.size()
	for k in range(1, n):
		var pair: Array = said[posmod(i + step * k, n)]
		var w := int(pair[1] if step < 0 else pair[0])
		if w != 0:
			return w
	return 0

## Which way the dots run along each half of a side the flow crosses, as
## [first half, second half] in the outline's own order: out of the middle
## where the flow comes in (`c` 1), and into it where the flow goes out (`c`
## -1). `before` and `after` are the ways of the runs either side, and a half
## one of them already runs through goes with it instead: round a ring the
## root feeds, the dots coming round carry on past where it feeds it rather
## than meeting the ones it sends the other way. Never both halves, though —
## that would have the dots meet where the flow comes in, or set off where it
## goes out.
func _crossing_halves(c: int, before: int, after: int) -> Array:
	var first := c if before == c else -c
	var second := -c if after == -c else c
	if first == c and second == -c:
		return [-c, c]
	return [first, second]

## The fallback: an outline cut into the two runs between `head` and `tail`,
## each kept from the head end onwards, for a shape whose own wiring says
## nothing about which way round it goes.
func _cut_at_ends(loop: PackedVector2Array, owners: Array, head: Vector2, tail: Vector2,
		total: float) -> void:
	var s0 := _cut_at(loop, head)
	var s1 := _cut_at(loop, tail)
	# The two runs share their ends and between them cover the outline exactly
	# once, so every part of it carries dots and none of it carries them twice.
	for way in [1.0, -1.0]:
		var span := fposmod((s1 - s0) * way, total)
		if span <= 0.0:
			continue
		_flow_arcs.append({"loop": loop, "owners": owners, "from": s0, "span": span,
			"way": way})

## How far round `loop` the outline comes closest to `to`. Measured against the
## segments rather than only the corners: a part's middle is nearer the middle
## of its own edge than any corner of it, and going by corners put both cuts on
## the same one whenever the two parts met there — a board whose two ends
## sit corner to corner then came out with no runs at all.
func _cut_at(loop: PackedVector2Array, to: Vector2) -> float:
	var best := 0.0
	var best_d := INF
	var walked := 0.0
	for i in loop.size():
		var a := loop[i]
		var step := loop[(i + 1) % loop.size()] - a
		var span := step.length()
		if span <= 0.0:
			continue
		var t := clampf((to - a).dot(step) / (span * span), 0.0, 1.0)
		var d := (a + step * t).distance_squared_to(to)
		if d < best_d:
			best_d = d
			best = walked + t * span
		walked += span
	return best

func _loop_length(loop: PackedVector2Array) -> float:
	var total := 0.0
	for i in loop.size():
		total += (loop[(i + 1) % loop.size()] - loop[i]).length()
	return total

## The point `s` round `loop` from its first corner, the way the outline runs
## there, how much of that straight run is left past the point, and which side
## of the loop it is, as [point, direction, left, side]. `s` wraps. The third of
## those is what lets a dot be laid down a run at a time: it says where the
## outline next turns; the fourth says whose side of the shape it is on, and so
## what colour the dot is there.
##
## The side `s` falls on is the last to start at or before it by `marks` —
## `_loop_marks` of the same loop — which is found by halving rather than by
## walking round from the first corner: a port's staircase has a corner every
## PIXEL, and a dot going down it asks at each one.
func _loop_sample(loop: PackedVector2Array, marks: PackedFloat64Array, s: float) -> Array:
	var i := marks.bsearch(s, false) - 1
	if i >= 0 and i < loop.size():
		var a := loop[i]
		var step := loop[(i + 1) % loop.size()] - a
		var span := step.length()
		var at := s - marks[i]
		if at < span:
			return [a + step * (at / span), step / span, span - at, i]
	return [loop[0], Vector2.RIGHT, 0.0, 0]

## How far round `loop` each of its sides starts, from its first corner, and
## after the last of them how far round the whole of it is — `_loop_length` —
## so one more entry than the loop has sides.
func _loop_marks(loop: PackedVector2Array) -> PackedFloat64Array:
	var marks := PackedFloat64Array()
	var walked := 0.0
	for i in loop.size():
		marks.append(walked)
		walked += (loop[(i + 1) % loop.size()] - loop[i]).length()
	marks.append(walked)
	return marks

## One side of `cell` as a directed segment with the shape on its right, which
## is what makes the loops these chain into come out clockwise. The cell comes
## with it: which way the dots run along a stretch of outline is the way the
## part under that stretch sends the flow, so each one has to remember whose
## side it is.
func _outline_edge(cell: Vector2i, dir: int) -> Array:
	var r := _cell_rect(cell)
	var top_right := Vector2(r.end.x, r.position.y)
	var bl := Vector2(r.position.x, r.end.y)
	match dir % 4:
		0: return [top_right, r.end, cell]
		1: return [r.end, bl, cell]
		2: return [bl, r.position, cell]
		_: return [r.position, top_right, cell]

## A corner as whole PIXELs, so two edges that meet there chain by an exact
## match rather than by comparing floats that were arrived at two ways.
func _point_key(p: Vector2) -> Vector2i:
	return Vector2i(roundi(p.x), roundi(p.y))

## Which of the four directions a one-cell step is, or -1 for anything else.
func _step_dir(step: Vector2i) -> int:
	for d in 4:
		if Components.dir_to_vec(d) == step:
			return d
	return -1

## Whether the boundary on `cell`'s `dir` side falls inside the silhouette
## rather than on it — the part's own next cell, or a joint that carries flow.
## Those are the seams nothing draws, which is what fuses a wired run into one
## shape while two parts that merely touch stay two boxes with a cross between.
func _fused(cells: Array, cell: Vector2i, dir: int) -> bool:
	if cells.has(cell + Components.dir_to_vec(dir)):
		return true
	return _fused_seam.has(Vector3i(cell.x, cell.y, dir % 4))

## The flow itself, over the top of the parts: dots running the silhouette of
## each wired shape. The outline under them says what is joined to what; these
## say it is live and carrying.
##
## They are spaced by distance along the run rather than per edge, so a corner
## does not bunch them and a long rail does not stretch them out. Which way any
## of them goes is the way the flow goes under it: on a line of parts they set
## off where the root hands over and arrive where the flow leaves, both ways
## round the shape; on a branch that comes back round to where it started they
## go round with it.
func _draw_flow_dots() -> void:
	# The track first and all of it, then the dots over the top. It is lit a
	# shape at a time rather than a run at a time, since the runs over one shape
	# cover it exactly once between them however it is cut up.
	for shape in _flow_loops:
		_draw_track(shape["loop"], shape["owners"])
	# A cell, not the gap between dots: the rate is cells of outline a second,
	# so sitting them closer together must not also slow them down.
	var travel := _flow_time * FLOW_RATE * cell_size()
	var apart := _flow_dot_span()
	for arc in _flow_arcs:
		var loop: PackedVector2Array = arc["loop"]
		# Where each side of the outline starts, measured the first time the run
		# is drawn and kept with it: a run lasts until the wiring is read again,
		# and its dots are placed every frame.
		if not arc.has("marks"):
			arc["marks"] = _loop_marks(loop)
		var marks: PackedFloat64Array = arc["marks"]
		var total := marks[marks.size() - 1]
		var way: float = arc["way"]
		var span: float = arc["span"]
		# Distance from the head cut, so a dot sets off from the start rather
		# than from wherever the outline happened to be written down first.
		var at := fmod(travel, apart)
		while at < span:
			# `way` places the dot and nothing else: a dot is the same mark
			# either way round, being drawn out from its middle.
			_draw_dot(loop, marks, arc["owners"], fposmod(float(arc["from"]) + at * way, total), total)
			at += apart

## The whole of one wired shape's outline, lit low: the line the dots run on.
## Drawn corner to corner rather than PIXEL by PIXEL — it does not fade — and a
## corner the outline turns out of the shape on belongs to the side arriving at
## it, exactly as it does for a dot, so no corner is laid down twice and doubled
## up should this ever be drawn in a colour that is not flat.
## Each side is lit in its own part's colour — the flow's, or the drained one
## for a branch that only runs on a trigger's condition. Down a seam the two
## meet: the band lies inside the shape on either side of the line, so a seam
## between the main line and the branch running home beside it comes out as the
## two of them side by side, a PIXEL each, rather than one over the other.
func _draw_track(loop: PackedVector2Array, owners: Array) -> void:
	for i in loop.size():
		var at := loop[i]
		var seg := loop[(i + 1) % loop.size()] - at
		var span := seg.length()
		if span <= 0.0:
			continue
		var along := seg / span
		var prev := at - loop[(i - 1 + loop.size()) % loop.size()]
		if prev.normalized().cross(along) > 0.0:
			at += along * float(PX)
			span -= float(PX)
		if span > 0.0:
			_draw_band(at, along, span,
				_track_colors(owners[i] if i < owners.size() else Vector2i(-1, -1))[0])

## A dot: FLOW_DOT PIXELs of the edge itself, lit, with `at` their middle. It is
## a length *of the outline* rather than a straight mark laid over it, so a dot
## going round a corner turns with the shape instead of carrying straight on off
## it. That is what the walk below is for: a piece per straight run the dot
## covers, which for a dot on a corner is two of them meeting there.
func _draw_dot(loop: PackedVector2Array, marks: PackedFloat64Array, owners: Array, at: float,
		total: float) -> void:
	var left := float(_flow_dot() * PX)
	# Started on the PIXEL grid rather than wherever the middle happens to fall:
	# every corner is on it too, so each piece below is whole PIXELs and none of
	# them is rounded away. A dot is then the same length wherever it is, which
	# it was not while a turn could lose one end of it to the snap.
	var s := fposmod(floorf((at - left * 0.5) / float(PX)) * float(PX), total)
	var along := Vector2.ZERO
	var lit := 0
	while left > 0.0:
		var hit := _loop_sample(loop, marks, s)
		var turn: Vector2 = hit[1]
		if along.cross(turn) > 0.0:
			# Where the outline turns out of the shape, both of its sides own
			# the same corner PIXEL. The arm arriving lays it and the arm
			# leaving steps over it: a dot on a corner is then as long as a dot
			# on a straight, and the fade does not double back on itself over
			# the one PIXEL both arms would otherwise put a step of it on.
			along = turn
			s = fposmod(s + float(PX), total)
			continue
		along = turn
		# Up to the next corner, or the rest of the dot if it reaches no corner.
		var run := minf(left, float(hit[2]))
		if run <= 0.0:
			break
		var owner_cell: Vector2i = owners[int(hit[3])] if int(hit[3]) < owners.size() \
			else Vector2i(-1, -1)
		_draw_dot_piece(hit[0], along, run, lit, _track_colors(owner_cell))
		lit += int(run / float(PX))
		s = fposmod(s + run, total)
		left -= run

## One straight piece of a dot: `span` of the outline from `at`, running
## `along`, starting `lit` PIXELs into the dot.
##
## A PIXEL at a time, because a dot is not one flat mark: it comes up out of the
## track it runs on and goes back down into it, brightest in the middle, the way
## the band sliding along a loading bar does. That is also what carries a dot
## round a corner without a seam — the fade is over the whole dot, so the two
## arms meeting there pick up where each other left off.
func _draw_dot_piece(at: Vector2, along: Vector2, span: float, lit: int, cols: Array) -> void:
	var step := along * float(PX)
	var whole := float(_flow_dot())
	for i in int(span / float(PX)):
		# Over the length of the whole dot, ends included: a PIXEL of it is
		# taken at its middle, so neither end comes out at nothing.
		var k := (float(lit + i) + 0.5) / whole
		# Out of the track and back into it, rather than out of nothing: the
		# line is already lit, and a dot is the length of it that is brightest.
		_draw_band(at + step * float(i), along, float(PX),
			(cols[0] as Color).lerp(cols[1], sin(PI * k)))

## `span` of the outline from `at`, running `along`, in `col`. The band is a
## PIXEL deep on the shape's side of the boundary — the loop's right, since the
## loops come out clockwise — so whatever is laid in it clips to the edge and
## the shape keeps its silhouette exactly.
func _draw_band(at: Vector2, along: Vector2, span: float, col: Color) -> void:
	var z := at + along * span + Vector2(-along.y, along.x) * float(PX)
	_px.rect(Rect2(Vector2(minf(at.x, z.x), minf(at.y, z.y)), (z - at).abs()), col)

## Only what is *wrong* is marked here: a cross where two parts touch but the
## receiving one will not take the flow, and a dot where the flow runs out into
## nothing — an empty cell, or off the board anywhere but the way out. What
## carries flow is not marked at all — the parts meet edge to edge, so the
## highlight running the chain is what shows a joint is live.
func _draw_faults() -> void:
	for br in _trace_cache.get("breaks", []):
		_px.icon_centered((_cell_center(br["from"]) + _cell_center(br["to"])) * 0.5, CROSS,
			Color(BREAK.r, BREAK.g, BREAK.b, 0.95))
	for leak in _trace_cache.get("leaks", []):
		var v := Vector2(Components.dir_to_vec(int(leak["dir"])))
		_px.icon_centered(_cell_center(leak["from"]) + v * (cell_size() * 0.5 + 5.0), DOT,
			Color(LEAK.r, LEAK.g, LEAK.b, 0.75))

## What the way out's arrow is drawn in: the flow's colour while a flow every
## cast sends gets there, the drained one while only a trigger's branch does,
## and the faults' red while nothing does — a board that casts nothing.
func _rebuild_way_out(b: SkillBoard) -> void:
	var sure := false
	var only_branch := false
	for out in _trace_cache.get("outs", []):
		var from: Vector2i = out["from"]
		if _conditional.has(from) or _is_branch(b, from, int(out["dir"])):
			only_branch = true
		else:
			sure = true
	_way_out_col = FLOW_EDGE if sure else (COND_EDGE if only_branch else BREAK)

## The way out, drawn on the frame in the middle of the right edge: an arrowhead
## with its back against the last cell and its tip outside the board, in the
## colour of what reaches it (`_rebuild_way_out`), bobbing out and back. A
## column of it at a time, each a PIXEL shorter at either end than the one
## before, centred on the row.
func _draw_way_out(b: SkillBoard) -> void:
	var r := _way_out_rect(b)
	r.position.x += _way_out_bob(_pal_panel().position.x - r.end.x)
	var deep := int(r.size.x / float(PX))
	for i in deep:
		var half := float(deep - 1 - i) * float(PX)
		_px.rect(Rect2(r.position.x + float(i * PX), r.get_center().y - float(PX) * 0.5 - half,
			float(PX), half * 2.0 + float(PX)), _way_out_col)

## Where the arrowhead stands: its back on the east side of the cell the way out
## is, centred on its row.
func _way_out_rect(b: SkillBoard) -> Rect2:
	var deep := WAY_OUT_DEEP_THUMB if cell_size() >= 80.0 else WAY_OUT_DEEP
	var extent := Vector2(deep, deep * 2 - 1) * float(PX)
	return Rect2(_cell_center(b.way_out()) + Vector2(cell_size() * 0.5, -extent.y * 0.5), extent)

## How far out of the board the way out is drawn now, in screen pixels, with
## `room` of them between its tip at rest and the parts: out and back by whole
## PIXELs, eased at both ends, as far as WAY_OUT_BOB and a PIXEL short of the
## parts — and not at all while the screen keeps still (`Video.icon_motion`).
func _way_out_bob(room: float) -> float:
	if not Video.icon_motion:
		return 0.0
	var most := mini(WAY_OUT_BOB, int(room / float(PX)) - 1)
	if most <= 0:
		return 0.0
	var out := 0.5 - 0.5 * cos(TAU * _flow_time / WAY_OUT_BOB_TIME)
	return roundf(out * float(most)) * float(PX)

## A two-cell part is one box across both of its cells rather than two boxes
## side by side: the seam between them would otherwise read as two parts, and
## run right through the icon sitting on it.
##
## The box is the cells themselves, with nothing trimmed off: parts that sit
## next to each other meet, and a wired run reads as one unbroken shape rather
## than as a row of tiles needing something drawn between them.
func _part_rect(id: String, origin: Vector2i, rot: int) -> Rect2:
	var r := _cell_rect(origin)
	for c in Components.footprint(id, origin, rot):
		r = r.merge(_cell_rect(c))
	return r

## A part's share of the silhouette, one cell edge at a time. Only the sides
## that are not fused are drawn, so parts the flow runs through come out as a
## single shape with no seams inside it: what is wired reads as one object, and
## two parts that merely touch stay two boxes with a cross between them.
##
## Each part draws only its own stretch, in its own colour, so the colour of
## the outline changes from one edge of the shape to the next. The whole of it
## stays lit: what is wired does not change from moment to moment, and the
## moving part of the picture is the dots over the top of it.
## A port is the one part that is not a box — see `_port_cut` — and its point
## is its edge on the side it points out of. The two sides running into that
## point stop where it starts, and the side is not drawn at all.
func _draw_part_edges(id: String, origin: Vector2i, rot: int, own: Color, cut: int = -1) -> void:
	var cells := Components.footprint(id, origin, rot)
	var r := _part_rect(id, origin, rot)
	var deep := _point_depth(r, cut) if cut >= 0 else 0.0
	# The point is cut into the cell the part emits from and no other: the
	# back cell of a two-cell root keeps its sides whole, rather than each of
	# them stopping as far short of its own end as the point is deep.
	var pointed := Components.exit_cell(id, origin, rot)
	for c in cells:
		for d in 4:
			if d == cut or _fused(cells, c, d):
				continue
			_px.rect(_trim_to_point(_edge_rect(cells, c, d), d, cut if c == pointed else -1, deep),
				own)
	if cut >= 0:
		_draw_port_point(r, cut, own)

## The one-PIXEL band along `cell`'s `dir` side, inside the cell. North and
## south take the corners and east and west stop short of them, so a translucent
## edge is never laid down twice where two sides meet — the same split
## `PixelDraw.frame` makes. Where the silhouette carries on north or south,
## though, there is no corner to yield: the band runs the whole height instead,
## and the rail stays unbroken across the seam it just fused.
func _edge_rect(cells: Array, cell: Vector2i, dir: int) -> Rect2:
	var r := _cell_rect(cell)
	if dir % 2 == 1:
		return Rect2(r.position.x, r.end.y - PX if dir % 4 == 1 else r.position.y,
			r.size.x, PX)
	var top := r.position.y + (0.0 if _fused(cells, cell, 3) else float(PX))
	var bot := r.end.y - (0.0 if _fused(cells, cell, 1) else float(PX))
	return Rect2(r.end.x - PX if dir % 4 == 0 else r.position.x, top, PX, bot - top)

## Which side a part comes to a point on, or -1 for everything that is a box,
## which is every part but the root. The root points the way it hands the flow
## over: it is the weapon's own part, and the point is what says so.
func _port_cut(b: SkillBoard, id: String, origin: Vector2i, rot: int) -> int:
	if not b.is_root(origin):
		return -1
	var outs := Components.world_outputs(id, rot)
	return int(outs[0]) if not outs.is_empty() else -1

## How far back a port is cut: the staircase runs at forty-five degrees from the
## middle of the side it points out of, so it reaches in as far as that side is
## wide, halved and landed on the grid.
func _point_depth(r: Rect2, dir: int) -> float:
	var v := Vector2(Components.dir_to_vec(dir))
	var across := absf(r.size.x * -v.y + r.size.y * v.x)
	@warning_ignore("integer_division")
	return float((int(across / float(PX)) - 1) / 2 * PX)

## A port as strips a PIXEL thick, running the way it points: each one is a
## PIXEL shorter than the one before as they go out from the middle, which is
## that forty-five degree cut written on the grid. The middle strip runs the
## whole depth, and is the point itself.
func _port_strips(r: Rect2, dir: int) -> Array:
	var f := _port_frame(r, dir)
	var base: Vector2 = f[0]
	var v: Vector2 = f[1]
	var w: Vector2 = f[2]
	var out := []
	for i in int(f[4]):
		var a := base + w * (float(i) * float(PX))
		var z := a + w * float(PX) + v * _strip_lead(f, i)
		out.append(Rect2(Vector2(minf(a.x, z.x), minf(a.y, z.y)), (z - a).abs()))
	return out

## What a port's strips are laid out by, as [base, v, w, deep, n]: the corner
## they are counted from, the way the port points, the way the strips stack,
## how deep the port is and how many strips there are.
func _port_frame(r: Rect2, dir: int) -> Array:
	var v := Vector2(Components.dir_to_vec(dir))
	var w := Vector2(-v.y, v.x)
	# The corner the strips are counted from: the one both `v` and `w` run away
	# from, so a port reads the same whichever way round it is turned.
	var base := Vector2(r.position.x if v.x + w.x > 0.0 else r.end.x,
		r.position.y if v.y + w.y > 0.0 else r.end.y)
	var deep := absf(r.size.x * v.x + r.size.y * v.y)
	var n := int(absf(r.size.x * w.x + r.size.y * w.y) / float(PX))
	return [base, v, w, deep, n]

## How far strip `i` of a port laid out by `f` runs: the whole depth in the
## middle, and a PIXEL less for every strip out from it.
func _strip_lead(f: Array, i: int) -> float:
	@warning_ignore("integer_division")
	return float(f[3]) - float(absi(i - (int(f[4]) - 1) / 2) * PX)

## A port's silhouette as a closed loop of corners, clockwise like every other
## outline the dots run: along one long side, down the staircase to the point
## and back, along the other long side and across the back. A corner every
## PIXEL of the staircase, so it is the outline of the strips exactly, and the
## track laid along it covers the PIXELs `_draw_port_point` lights.
func _port_outline(f: Array) -> PackedVector2Array:
	var base: Vector2 = f[0]
	var v: Vector2 = f[1]
	var w: Vector2 = f[2]
	var n := int(f[4])
	var loop := PackedVector2Array([base])
	for i in n:
		var lead := _strip_lead(f, i)
		loop.append(base + v * lead + w * (float(i) * float(PX)))
		loop.append(base + v * lead + w * (float(i + 1) * float(PX)))
	loop.append(base + w * (float(n) * float(PX)))
	return loop

## The ground and the tint under a part, which for a port is its strips rather
## than its box: the two corners it is cut back to a point from show the board
## behind them, and the cut is the shape of the part rather than a mark on it.
func _draw_part_body(r: Rect2, cut: int, col: Color) -> void:
	if cut < 0:
		_px.rect(r, col)
		return
	for strip in _port_strips(r, cut):
		_px.rect(strip, col)

## The point itself: the PIXEL each strip ends on, which taken together are the
## two runs of the staircase meeting at the tip.
func _draw_port_point(r: Rect2, dir: int, col: Color) -> void:
	var v := Vector2(Components.dir_to_vec(dir))
	for strip in _port_strips(r, dir):
		var tip := strip as Rect2
		if absf(v.x) > 0.0:
			tip.position.x = strip.end.x - float(PX) if v.x > 0.0 else strip.position.x
			tip.size.x = float(PX)
		else:
			tip.position.y = strip.end.y - float(PX) if v.y > 0.0 else strip.position.y
			tip.size.y = float(PX)
		_px.rect(tip, col)

## An edge band stopped where a port's point starts, so the straight sides give
## way to the staircase rather than running on behind it. Only the two sides
## across from the point are cut back: the side it points out of is not drawn,
## and the one behind it runs the full width.
func _trim_to_point(band: Rect2, dir: int, cut: int, deep: float) -> Rect2:
	if cut < 0 or dir % 2 == cut % 2:
		return band
	var v := Vector2(Components.dir_to_vec(cut))
	if v.x > 0.0:
		band.size.x -= deep
	elif v.x < 0.0:
		band.position.x += deep
		band.size.x -= deep
	elif v.y > 0.0:
		band.size.y -= deep
	else:
		band.position.y += deep
		band.size.y -= deep
	return band

func _draw_component(b: SkillBoard, origin: Vector2i) -> void:
	var entry: Dictionary = b.cells[origin]
	var id: String = entry["id"]
	var rot: int = entry["rot"]
	var col := Style.component_color(id)
	# Caught in a loop with no way out. It is drawn switched off whatever else
	# is true of it — being fed by the root is the very thing that makes it
	# dead code rather than a part waiting to be wired up.
	var dead := _dead_at(origin)
	# A part the flow cannot reach is drawn faint: it is on the board but dead.
	var live: bool = not dead and (not bool(_trace_cache.get("has_root", false)) \
		or _trace_cache.get("reachable", {}).has(origin))
	_draw_part(id, origin, rot, _port_cut(b, id, origin, rot), [
		Color(DEAD_FILL.r, DEAD_FILL.g, DEAD_FILL.b, 0.2) if dead \
			else Color(col.r, col.g, col.b, 0.28 if live else 0.08),
		# The edge is what carries the wiring now that the parts touch, so it is
		# drawn brighter than the part it bounds, and the run lights it on its
		# way past. A part the flow never reaches never lights: the same reading
		# the bridges gave, moved onto the part itself.
		DEAD_EDGE if dead else (col.lightened(0.45) if live else Color(col.r, col.g, col.b, 0.35)),
		DEAD_INK if dead else (col.lightened(0.3) if live else Color(col.r, col.g, col.b, 0.4)),
		DEAD_EDGE if dead else (col.lightened(0.4) if live else Color(col.r, col.g, col.b, 0.35)),
		DEAD_EDGE if dead else (Color(1.0, 0.55, 0.8) if live else Color(1.0, 0.55, 0.8, 0.35))],
		1.0, _pointed_at(origin))

## A part filed under `origin`, pointed on its `cut` side if it is the root, in
## `look`'s colours: its tint, its edge, its icon, the arrows its flow leaves by
## and the one its payload does. Its own ground goes under the tint, `ground`
## solid, so the grid it covers does not show through and draw a seam across a
## two-cell part. Its icon moves if it is the one under the pointer (`moving`).
func _draw_part(id: String, origin: Vector2i, rot: int, cut: int, look: Array,
		ground: float = 1.0, moving: bool = false) -> void:
	var r := _part_rect(id, origin, rot)
	_draw_part_body(r, cut, _faded(CELL_FILL, ground))
	_draw_part_body(r, cut, look[0])
	_draw_part_edges(id, origin, rot, look[1], cut)
	# No name under the icon: none fits a cell in the pixel face. Hovering the
	# part names it on a card instead. The icon is drawn at ICON_ZOOM here — a
	# cell is wide enough for it, and at palette size it was lost in the middle
	# of one.
	_px.icon_centered(r.get_center(), _icon(id, moving), look[2], _icon_zoom())
	var ex := Components.exit_cell(id, origin, rot)
	for d in Components.world_outputs(id, rot):
		_draw_port_arrow(ex, d, look[3])
	var pd := Components.world_payload_out(id, rot)
	if pd >= 0:
		_draw_port_arrow(ex, pd, look[4])

## Live pulses from the running circuit, so the board shows its own timing: a
## diamond that swells as the pulse crosses a part, and the part's border lit
## clockwise from the top as far as the pulse has got.
##
## A pulse is at whichever of a two-cell part's cells the flow entered by, so
## both are resolved back to the part: the wipe goes round the whole of it.
func _draw_live_flow(b: SkillBoard) -> void:
	var r := runner
	if r == null or r.board != b:
		return
	for p in r.pulses:
		var origin: Vector2i = b.origin_at(p.cell)
		var entry := b.comp_origin_at(origin)
		var box := _cell_rect(p.cell) if entry.is_empty() \
			else _part_rect(String(entry["id"]), origin, int(entry["rot"]))
		var k := p.progress()
		_px.diamond(box.get_center(), 3 + int(round(2.0 * sin(k * PI))), Color(0.6, 1.0, 0.85, 0.85))
		_px.lap(box, k, Color(0.5, 1.0, 0.8, 0.7))

## The parts, in blocks — one a category, in the order the categories table
## lists them (`Components.categories`), each holding its parts in the pool's
## order. A category no part is of has no block.
##
## Worked out on first use and kept, the pool being a constant: a thumb's layout
## is checked against how many blocks there are every time anything asks where
## something stands, and gathering them again for each asking was most of what
## a frame of mobile mode cost.
func _pal_groups() -> Array:
	if not _groups.is_empty():
		return _groups
	var by_cat := {}
	var order: Array = Components.categories()
	for id in _pool_ids():
		var cat := String(Components.get_def(id).get("cat", ""))
		if not by_cat.has(cat):
			by_cat[cat] = []
			# One the table does not list goes after those it does.
			if not order.has(cat):
				order.append(cat)
		(by_cat[cat] as Array).append(id)
	for cat in order:
		if by_cat.has(cat):
			_groups.append({"cat": cat, "ids": by_cat[cat]})
	return _groups

## A desk's palette placed: the tabs down its left, each as tall as the panel
## shares out between them, and beside them the rows of the category whose tab
## is up and no others. `_pal_rows` is what the rest of the screen asks — what
## is under a press, what is in the hand's reach — so the parts behind the
## other tabs are not there to be pressed. Worked out again when the tab
## changes (`_layout_key`).
func _build_palette() -> void:
	_pal_rows = []
	_pal_tabs = []
	var origin: Vector2 = _desk_layout()["parts"]
	_pal_origin = origin
	var groups := _pal_groups()
	_pal_height = float(_desk_layout()["tall"]) - 20.0
	if groups.is_empty():
		return
	var n := float(groups.size())
	var tall := maxf(PAL_TAB_FLOOR, floorf((_pal_height - (n - 1.0) * PAL_GROUP_GAP) / n / PX) * PX)
	for i in groups.size():
		_pal_tabs.append(Rect2(origin.x, origin.y + float(i) * (tall + PAL_GROUP_GAP), _pal_tab_w(), tall))
	_pal_height = maxf(_pal_height, n * tall + (n - 1.0) * PAL_GROUP_GAP)
	_tab = clampi(_tab, 0, groups.size() - 1)
	var cell := float(_desk_layout()["cell"])
	var foot := origin.y
	for t: Dictionary in _lay_tiles(groups[_tab]["ids"], Vector2(origin.x + _pal_gutter(), origin.y), cell, PAL_ROOM):
		_pal_rows.append({"id": t["id"], "rect": t["rect"]})
		foot = maxf(foot, (t["rect"] as Rect2).end.y)
	_pal_height = maxf(_pal_height, foot - origin.y)

## `ids` as tiles, a board cell of `cell` each across — two for a two-cell
## part — laid along a row from `at` as far as `wide` goes and on to the next:
## each {id, rect, row}.
static func _lay_tiles(ids: Array, at: Vector2, cell: float, wide: float) -> Array:
	var out: Array = []
	var x := at.x
	var row := 0
	for id in ids:
		var tile := Vector2(_tile_cells(String(id))) * cell
		if x > at.x and x + tile.x > at.x + wide:
			x = at.x
			row += 1
		out.append({"id": String(id), "row": row,
			"rect": Rect2(Vector2(x, at.y + float(row) * (cell + PAL_TILE_GAP)), tile)})
		x += tile.x + PAL_TILE_GAP
	return out

## How many cells across and down a part stands, unturned: its tile's size in
## the palette, in cells of the board.
static func _tile_cells(id: String) -> Vector2i:
	var most := Vector2i.ZERO
	for c: Vector2i in Components.footprint(id, Vector2i.ZERO, 0):
		most = most.max(c)
	return most + Vector2i.ONE

## Laid out again when the screen has changed shape under it, since every rect
## in it carries where it was worked out for — and when the mode has, or mobile
## mode's tab, which is a different set of rows.
func _pal_list() -> Array:
	var key := _layout_key()
	if _pal_rows.is_empty() or _pal_key != key:
		_pal_key = key
		if thumb():
			_build_thumb_parts()
		else:
			_build_palette()
	return _pal_rows

## Mobile mode's tiles: the parts of the category whose tab is up and no
## others, laid as a desk lays them (`_lay_tiles`) in the column beside the
## tabs, a thumb's board cell each. `_pal_rows` is what the rest of the screen
## asks — what is under a press, what is in the hand's reach — so the parts on
## the other tabs are not there to be pressed. A block with more rows than fit
## the column stands as many as fit, from row `_plate_first`, and the rest
## have no room on the screen (an empty rect) until it is scrolled to them.
func _build_thumb_parts() -> void:
	_pal_rows = []
	_pal_tabs = []
	_tile_row = {}
	var groups := _pal_groups()
	if groups.is_empty():
		return
	_tab = clampi(_tab, 0, groups.size() - 1)
	var room: Rect2 = _thumb_layout()["plates"]
	var cell := cell_size()
	var laid := _lay_tiles(groups[_tab]["ids"], room.position, cell, room.size.x)
	_plate_rows = int(laid[-1]["row"]) + 1 if not laid.is_empty() else 0
	_plate_pitch = cell + PAL_TILE_GAP
	_plates_shown = maxi(1, int((room.size.y + PAL_TILE_GAP) / _plate_pitch))
	_plate_first = clampi(_plate_first, 0, maxi(0, _plate_rows - _plates_shown))
	for t: Dictionary in laid:
		var row := int(t["row"])
		_tile_row[t["id"]] = row
		var r := Rect2()
		if row >= _plate_first and row < _plate_first + _plates_shown:
			r = (t["rect"] as Rect2)
			r.position.y -= float(_plate_first) * _plate_pitch
		_pal_rows.append({"id": t["id"], "rect": r})

func _pal_rect(i: int) -> Rect2:
	return _pal_list()[i]["rect"]

## The panel the blocks sit on: 10 clear of the rows on every side, the gutter
## included. Anything thrown at it is thrown at the palette.
func _pal_panel() -> Rect2:
	# For a thumb it is the whole column: tabs, plates, and the two under them.
	if thumb():
		return _thumb_layout()["column"]
	_pal_list()   # for _pal_height and _pal_origin, which the layout works out
	# Down to the board's foot where the board stands taller than the rows.
	return Rect2(_pal_origin - Vector2(10, 10),
		Vector2(_pal_gutter() + PAL_ROOM + 20, maxf(_pal_height + 20, float(_desk_layout()["tall"]))))

## The least a desk's parts panel can stand beside a board of `cell`: its tabs
## at PAL_TAB_FLOOR, or the category with the most parts in tiles that size,
## whichever is taller, 10 clear of them over and under.
func _pal_least(cell: float) -> float:
	var groups := _pal_groups()
	var n := float(groups.size())
	var tall := maxf(n * PAL_TAB_FLOOR + (n - 1.0) * PAL_GROUP_GAP, 0.0)
	var across := maxi(1, int((PAL_ROOM + PAL_TILE_GAP) / (cell + PAL_TILE_GAP)))
	for group in groups:
		var rows := ceilf(float((group["ids"] as Array).size()) / float(across))
		tall = maxf(tall, rows * (cell + PAL_TILE_GAP) - PAL_TILE_GAP)
	return tall + 20.0

## How big a desk's parts panel stands: 10 clear of its rows on every side, the
## gutter included. As tall as the tabs are at their least, a tab a category,
## or as the category with the most parts is in rows, whichever is taller —
## not as every category stacked, which is what it was before the tabs and
## which, at eight categories, stood taller than the board beside it can grow
## to (the board is sized to stand as tall as the panel). Counted off the
## categories rather than off the rows, since where the rows go is worked out
## from it.
func _pal_panel_size() -> Vector2:
	var groups := _pal_groups()
	var n := float(groups.size())
	var tall := maxf(n * PAL_TAB_LEAST + (n - 1.0) * PAL_GROUP_GAP, 0.0)
	# The tiles at the least cell there is: a bigger cell, which is worked out
	# from this, only stretches the panel down to the board's foot.
	var across := maxi(1, int((PAL_ROOM + PAL_TILE_GAP) / (CELL + PAL_TILE_GAP)))
	for group in groups:
		var rows := ceilf(float((group["ids"] as Array).size()) / float(across))
		tall = maxf(tall, rows * (CELL + PAL_TILE_GAP) - PAL_TILE_GAP)
	return Vector2(_pal_gutter() + PAL_ROOM + 20, tall + 20)

## How wide a desk's category tabs are: PAL_TAB_W, or wider where a word of a
## category's name — which wraps between its words, two lines at most — would
## not otherwise fit whole, with 6 clear either side. On the PIXEL grid.
func _pal_tab_w() -> float:
	var most := PAL_TAB_W
	for group in _pal_groups():
		for word in Style.category_name(String(group["cat"])).split(" ", false):
			most = maxf(most, PixelDraw.text_width(word) + 12.0)
	return ceilf(most / PX) * PX

## Where the parts start, from the panel's inside edge: past the tabs.
func _pal_gutter() -> float:
	return _pal_tab_w() + PAL_TAB_GAP

func _draw_palette() -> void:
	var panel := _pal_panel()
	_px.rect(panel, Color(0.08, 0.09, 0.12, 0.92))
	_px.frame(panel, Color(0.3, 0.45, 0.6, 0.7))

	_draw_pal_tabs()

	_draw_tiles()

## The palette's tiles, at a desk and for a thumb alike: each part as it stands
## on the board, a cell of it across, its icon at the board's size, and how
## many there are in its corner. One there are none of is drained, and the one
## in hand lit. A tile scrolled out of a thumb's column has no room, and is not
## drawn.
func _draw_tiles() -> void:
	var ids := _palette_ids()
	var zoom := _icon_zoom()
	for i in ids.size():
		var id: String = ids[i]
		var r := _pal_rect(i)
		if r.size.y <= 0.0:
			continue
		var have := unlimited or int(inventory.get(id, 0)) > 0
		var c := Style.component_color(id)
		_px.rect(r, CELL_FILL)
		_px.rect(r, Color(c.r, c.g, c.b, (0.42 if id == selected else 0.28) if have else 0.06))
		var edge := c.lightened(0.45) if have else Color(0.3, 0.32, 0.36)
		_px.frame(r, edge)
		if id == selected:
			_px.frame(r.grow(-PX), edge)
		var ink := c.lightened(0.3) if have else Color(c.r, c.g, c.b, 0.35)
		_px.icon_centered(r.get_center(), _icon(id, _drag_id == "" and i == _hover_pal), ink, zoom)
		_draw_count(r.end - Vector2(6, 6), id)
		if i == _hover_pal:
			_px.frame(r, Color(1, 1, 1, 0.5))

## The part in hand named under a thumb's tiles, and what it does, in what is
## left of the column under them — the desk's hover card, for a screen with no
## pointer to hover with. Nothing where nothing is in hand, or no room is left.
func _draw_thumb_named(room: Rect2) -> void:
	if selected == "":
		return
	var top := room.position.y
	for i in _palette_ids().size():
		var r := _pal_rect(i)
		if r.size.y > 0.0:
			top = maxf(top, r.end.y)
	top += 24.0
	var name_size := Loc.text_size(Components.name_for(selected), UiKit.THUMB_TEXT)
	if top + 40.0 > room.end.y:
		return
	_px.text(Vector2(room.position.x, top + 24.0), Components.name_for(selected),
		Style.component_color(selected), room.size.x, name_size)
	var size := Loc.text_size(Components.desc_for(selected), THUMB_DESC_TEXT)
	var line := float(size) * 1.25
	var at := top + 24.0 + 16.0 + line
	# Wrapped at the face's own size: `wrap` measures at PixelDraw's.
	var most := int((room.end.y - at + line) / line)
	if most <= 0:
		return
	var rows := PixelDraw.wrap(Components.desc_for(selected),
		room.size.x * float(PixelDraw.SIZE) / float(size), most)
	for k in rows.size():
		_px.text(Vector2(room.position.x, at + line * float(k)), rows[k], Color(0.82, 0.86, 0.92), room.size.x, size)

## A desk's category tabs: each in its category's colour, the one that is up
## lit and filled, its name centred on it a word a line where it is wider than
## the tab.
func _draw_pal_tabs() -> void:
	var groups := _pal_groups()
	for i in mini(groups.size(), _pal_tabs.size()):
		var r: Rect2 = _pal_tabs[i]
		var cat := String(groups[i]["cat"])
		var col := Style.category_color(cat)
		var up := i == _tab
		_px.rect(r, Color(col.r, col.g, col.b, 0.34) if up else Color(0.08, 0.09, 0.12, 0.92))
		_px.frame(r, col if up else Color(col.r, col.g, col.b, 0.45))
		if up:
			_px.frame(r.grow(-PX), col)
		if i == _hover_tab:
			_px.frame(r, Color(1, 1, 1, 0.5))
		var lines := _tab_lines(cat, r.size.x - 12.0)
		var top := r.position.y + (r.size.y + 10.0) * 0.5 - PixelDraw.LINE * 0.5 * float(lines.size() - 1)
		for k in lines.size():
			_px.text_centered(Vector2(r.position.x + 6.0, top + PixelDraw.LINE * k),
				lines[k], Color.WHITE if up else col, r.size.x - 12.0)

## A category's name in lines `wide` across — two at most, the rest cut short.
static func _tab_lines(cat: String, wide: float) -> PackedStringArray:
	var lines := PixelDraw.wrap(Style.category_name(cat), wide, 2)
	return lines if not lines.is_empty() else PackedStringArray([""])

## Where there is no end of parts — the bench — a part shows an infinity sign
## instead of a count, drawn because the pixel face has none. On its own,
## without the "x" a count has: the two together read as one more number.
func _endless() -> bool:
	return unlimited

func _count_width(id: String) -> float:
	if _endless():
		return INFINITY[0].length() * PX
	return PixelDraw.ink_width("x%d" % int(inventory.get(id, 0)))

## "x2", or the infinity, right-aligned on `right`.
func _draw_count(right: Vector2, id: String) -> void:
	var col := Color(0.6, 0.7, 0.8)
	var at := _px.snap(right - Vector2(_count_width(id), 0))
	if _endless():
		_px.icon(at + Vector2(0, -5 * PX), INFINITY, col)
	else:
		_px.text(at, Loc.t("editor.count", [int(inventory.get(id, 0))]), col)

## --- for a thumb: the drawing -----------------------------------------------------

## A message, for the moment it lasts, on a plate of its own past COPY and
## PASTE — at a desk it is written along the bottom. A refusal on red, and what
## COPY and PASTE did on green.
func _draw_thumb_message() -> void:
	if _message_time <= 0.0:
		return
	var r: Rect2 = _thumb_layout()["message"]
	_px.rect(r, Color(0.12, 0.28, 0.2, 0.9) if _message_good else Color(0.3, 0.14, 0.12, 0.9))
	_px.frame(r, UiKit.GOOD if _message_good else Color(1.0, 0.65, 0.55))
	# At the size everything else here is read at: it is a sentence. In two rows,
	# the plate standing in what COPY and PASTE leave of their row.
	var rows := PixelDraw.wrap(_message, r.size.x - 32.0, 2)
	var ink := Color(0.8, 1.0, 0.88) if _message_good else Color(1.0, 0.8, 0.72)
	var base := r.position.y + (r.size.y - PixelDraw.LINE * float(rows.size() - 1) + 10.0) * 0.5
	for i in rows.size():
		_px.text(Vector2(r.position.x + 16.0, base + PixelDraw.LINE * float(i)), rows[i], ink)

## The parts, for a thumb: a tab a category down the left of the column, the
## plates of the one that is up beside them, and TURN and REMOVE along the foot.
func _draw_thumb_parts() -> void:
	var l := _thumb_layout()
	var groups := _pal_groups()
	var tabs: Array = l["tabs"]
	for i in mini(groups.size(), tabs.size()):
		var r: Rect2 = tabs[i]
		var cat := String(groups[i]["cat"])
		var col := Style.category_color(cat)
		var up := i == _tab
		_px.rect(r, Color(col.r, col.g, col.b, 0.34) if up else Color(0.08, 0.09, 0.12, 0.92))
		_px.frame(r, col if up else Color(col.r, col.g, col.b, 0.45))
		if up:
			_px.frame(r.grow(-PX), col)
		if i == _hover_tab:
			_px.frame(r, Color(1, 1, 1, 0.5))
		# Centred down the tab, a line a word where the name is wider than it.
		var lines := Style.category_lines(cat, r.size.x - 8.0)
		var top := r.position.y + (r.size.y + 10.0) * 0.5 - PixelDraw.LINE * 0.5 * float(lines.size() - 1)
		for k in lines.size():
			_px.text_centered(Vector2(r.position.x + 4.0, top + PixelDraw.LINE * k),
				lines[k], Color.WHITE if up else col, r.size.x - 8.0)

	_draw_tiles()
	_draw_plate_cues(l["plates"], _plate_rows)
	_draw_thumb_named(l["plates"])
	var big := UiKit.THUMB_TEXT

	# TURN shows the way the part in hand faces — the one picked on the board, or
	# the next one set down — and turns it. REMOVE has something to take off only
	# while a part on the board is picked, and not the root, which stays.
	var turn: Rect2 = l["turn"]
	var turn_label := Loc.t("editor.turn")
	var turn_size := Loc.text_size(turn_label, big)
	_px.plate(turn, "", UiKit.ACCENT, _hover_turn, true)
	var arrow := ARROW[0].length() * PX * 3 + 16.0
	var turn_at := _px.snap(turn.position + Vector2(
		(turn.size.x - arrow - PixelDraw.ink_width(turn_label, turn_size)) * 0.5, (turn.size.y - 30.0) * 0.5))
	_px.icon(turn_at, _arrows[rotation_step], Color(0.8, 0.95, 1.0), 3)
	_px.text(Vector2(turn_at.x + arrow, turn.position.y + (turn.size.y + 20.0) * 0.5), turn_label,
		Color(0.95, 0.98, 1.0), -1.0, turn_size)
	var b := current_board()
	_px.plate(l["remove"], Loc.t("editor.remove"), Color(1.0, 0.55, 0.55), _hover_remove,
		_picked_part() != NOWHERE and b != null and not b.is_root(_picked))

## Where a block scrolls, a small arrow over its plates while there are more
## above, and one under them while there are more below, in the gaps the column
## leaves there.
func _draw_plate_cues(room: Rect2, count: int) -> void:
	if _plates_shown >= count:
		return
	var col := Color(0.8, 0.9, 1.0, 0.8)
	var mid := floorf(room.get_center().x / PX) * PX
	if _plate_first > 0:
		var top := room.position.y - 4.0 * PX
		_px.rect(Rect2(mid - PX, top, PX * 2.0, PX), col)
		_px.rect(Rect2(mid - PX * 3.0, top + PX, PX * 6.0, PX), col)
	if _plate_first + _plates_shown < count:
		var under := room.end.y + PX
		_px.rect(Rect2(mid - PX * 3.0, under, PX * 6.0, PX), col)
		_px.rect(Rect2(mid - PX, under + PX, PX * 2.0, PX), col)

## A message lasts a moment along the bottom: a refusal (no room, none left) in
## red, and what COPY and PASTE did in green. It is the only thing written there.
func _draw_message(vp: Vector2) -> void:
	if _message_time > 0.0:
		# Under the board's own left edge, and no further over than the parts.
		var x := board_origin().x
		_px.text(Vector2(x, vp.y - 24), _message,
			UiKit.GOOD if _message_good else Color(1.0, 0.65, 0.55), _pal_panel().end.x - x)
