class_name MapPanel
extends Control

## The raid map, as a window of its own: the floor plan, where you are standing
## on it, which exits you have found and how long you have been down here.
##
## It used to be a corner of the HUD, small enough that a room was a dot and the
## links between them were left out entirely. A window has the room to draw the
## floor the way the player walks it, so it draws the corridors too — and it
## costs what the workbench costs: the raid runs on behind it, the clock keeps
## climbing, and the player stands still while they read.
##
## It is the MAP page of the screen the weapons' graphs are on, a tab each along
## its top (`ScreenTabs`): the back arrow in the corner puts the screen away,
## and the GRAPH tab puts the assembly board up in the map's place
## (`page_picked`). The keys say the same: M, or ESC, puts it away, and the key
## that opens assembly puts the board up instead.
##
## The tab is there wherever the screen is, a raid or not, and so is this page:
## over the bench, the hideout's workbench and everywhere else with no floor
## plan to show it is the map's window with nothing on it but that there is no
## map (`_draw_none`).
##
## Drawn in UiKit's pixel look, like the assembly screen it shares the raid
## with: every fill, border and letter a whole PIXEL on the PIXEL grid, all of
## it through `PixelDraw`.

signal closed()
## A tab along the screen's top was pressed, for a page other than the map: the
## raid puts that page up in its place.
signal page_picked(id: String)

## What the window is looking at. `RaidView` keeps both fresh, the same way it
## keeps the HUD fresh; with no map, the window says there is none.
var map: RaidMap = null
var room = null
## The pages of the screen this is a page of, in the order their tabs stand
## along its top.
var pages: Array = ScreenTabs.PAGES.duplicate()
## What along the top is under the pointer: the back arrow, or a page's tab.
var _back_hot: bool = false
var _page_hot: String = ""

const PX := UiKit.PIXEL
## A room, and the gap the corridor between two of them is drawn in.
const CELL := 56.0
const GAP := 8.0
## How thick a corridor is drawn, in PIXELs. Thin enough to read as a link
## between two rooms rather than a third room, wide enough to see at a glance.
const LINK := 3
const PAD := 24.0
## Title and clock share the top row; the grid starts under it.
const HEADER_H := 52.0
const LEGEND_TOP_GAP := 18.0
const LEGEND_ROW := 26.0
const LEGEND_COLS := 3
## The row that says how to put the map away, at a desk (`_foot`).
const FOOT_H := 34.0
## Where there is no map: the room under the title the line saying so stands in.
const NONE_H := 88.0
## A row's baseline, from the top of the row: capitals stand 10 tall.
const TEXT_DROP := 16.0
const SWATCH := 12.0

const BG := Color(0.07, 0.08, 0.11, 0.97)
const EDGE := Color(0.35, 0.55, 0.75, 0.85)
## A room nobody has walked into yet: the floor plan is known, what is on it
## is not.
const UNSEEN := Color(0.2, 0.24, 0.3)
const ROOM_EDGE := Color(0.14, 0.17, 0.22)
const PLAIN := Color(0.4, 0.5, 0.62)
const EXIT_MARK := Color(0.5, 1.0, 0.75)
const YOU := Color(1, 1, 1)
## The room a death left the kit in. Drawn whether or not the room has been
## opened: the whole reason this raid is the same floor as the last one is that
## the player can go back for it, and a marker they have to find first would be
## no help at all.
const KIT_MARK := Color(1.0, 0.86, 0.62)
## Where in that room the player fell: a skull, set on the room's square where
## the spot is in the room, so the map says which corner to look in as well as
## which room. Holes for eyes, a row of teeth; each `#` a PIXEL.
const SKULL := [
	".#####.",
	"#######",
	"#..#..#",
	"#######",
	".##.##.",
	".#####.",
	".#.#.#.",
]
## The same skull with nothing cut out of it, laid round it in the room's edge
## colour so it reads on a pale room as well as a dark one.
const SKULL_SOLID := [
	".#####.",
	"#######",
	"#######",
	"#######",
	".#####.",
	".#####.",
	".#####.",
]

## What a room is worth walking into, by the kind the rules gave it. Anything
## not named here is an ordinary room.
const KIND_COLORS := {
	"entry": Color(0.4, 0.8, 0.6),
	"boss": Color(0.9, 0.4, 0.5),
	"treasure": Color(0.9, 0.8, 0.4),
}

var _px := PixelDraw.new(self)

func _ready() -> void:
	UiKit.fill_screen(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(true)

func _process(_delta: float) -> void:
	UiKit.sync_screen(self)
	queue_redraw()

## Handled here rather than in `_gui_input` so the keys work whether or not the
## window holds focus, and marked handled so the screen that opened it does not
## see the same press and open it straight back up.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("open_map") or event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_editor"):
		page_picked.emit(ScreenTabs.GRAPH)
		get_viewport().set_input_as_handled()

## The top answers the pointer, and a thumb, which the system hands over as a
## click: the back arrow puts the screen away, and the graph's tab puts the
## board up in the map's place.
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
		if id != ScreenTabs.MAP:
			page_picked.emit(id)

## The window, centred on whatever size the screen happens to be: as wide with
## no map as with one, and only as tall as the line that says so.
func window_rect() -> Rect2:
	var tall := HEADER_H + NONE_H
	if map != null:
		tall = HEADER_H + RaidMap.MH * CELL + (RaidMap.MH - 1) * GAP \
			+ LEGEND_TOP_GAP + LEGEND_ROW * float(_legend_rows())
	var extent := Vector2(RaidMap.MW * CELL + (RaidMap.MW - 1) * GAP + PAD * 2.0, tall + _foot())
	var screen := get_viewport_rect().size
	return Rect2(_px.snap((screen - extent) * 0.5), extent)

func _draw() -> void:
	var win := window_rect()
	# The screen's own veil, the one the graph's page lies on: going from one
	# page to the other changes what is under the top and nothing round it.
	_px.rect(Rect2(Vector2.ZERO, get_viewport_rect().size), ScreenTabs.VEIL)
	_px.rect(win, BG)
	_px.frame(win, EDGE)
	if map == null:
		_draw_none(win)
	else:
		_draw_header(win)
		var grid := _origin(Vector2(win.position.x + PAD, win.position.y + HEADER_H))
		_draw_links(grid)
		_draw_rooms(grid)
		var under := grid.y + RaidMap.MH * CELL + (RaidMap.MH - 1) * GAP + LEGEND_TOP_GAP
		_draw_legend(Vector2(win.position.x + PAD, under), win.size.x - PAD * 2.0)
	if _foot() > 0.0:
		_draw_footer(win)
	ScreenTabs.draw(_px, pages, ScreenTabs.MAP, _back_hot, _page_hot, UiKit.mobile())

## The window with no map to show: its title where a map's is, and under it,
## in the middle of the room a floor plan would have, the line that says so.
## No clock: there is no raid for it to time.
func _draw_none(win: Rect2) -> void:
	_px.text(Vector2(win.position.x + PAD, win.position.y + PAD + 10.0), Loc.t("hud.map.title"), UiKit.TEXT)
	_px.text_centered(Vector2(win.position.x + PAD, win.position.y + HEADER_H + (NONE_H + 10.0) * 0.5),
		Loc.t("hud.map.none"), UiKit.DIM, win.size.x - PAD * 2.0)

## The title on the left, the raid clock on the right — the one number on this
## window that is still moving while it is up.
func _draw_header(win: Rect2) -> void:
	var base := win.position.y + PAD + 10.0
	_px.text(Vector2(win.position.x + PAD, base), Loc.t("hud.map.title"), UiKit.TEXT)
	var press := map.pressure()
	var clock := Loc.t("hud.map.clock", [
		int(map.elapsed / 60.0), int(map.elapsed) % 60,
		Loc.t("hud.map.pressure.%d" % clampi(press, 0, 4))])
	var col := UiKit.DIM if press < 3 else UiKit.BAD
	_px.text(Vector2(win.end.x - PAD - PixelDraw.ink_width(clock), base), clock, col)

## Where the plan's own top-left corner is drawn. A floor that grew to one side
## of the entry uses a corner of the board and nothing else, so what is drawn is
## the rooms there are, centred, rather than the whole 7x5 board they sit in.
func _origin(grid: Vector2) -> Vector2:
	var lo := Vector2i(RaidMap.MW, RaidMap.MH)
	var hi := Vector2i(-1, -1)
	for key in map.rooms:
		var c: Vector2i = key
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	if hi.x < lo.x:
		return grid
	var used := Vector2(hi - lo) + Vector2.ONE
	var board := Vector2(RaidMap.MW, RaidMap.MH)
	return _px.snap(grid + ((board - used) * 0.5 - Vector2(lo)) * (CELL + GAP))

## The corridors, drawn in the gaps between the rooms they join. Every room next
## to another one on the plan has a door through to it — see `RaidMap.doors_for`
## — so each pair is drawn once, from the room on the left or above.
func _draw_links(grid: Vector2) -> void:
	for key in map.rooms:
		var c: Vector2i = key
		for step in [Vector2i(1, 0), Vector2i(0, 1)]:
			var other: Vector2i = c + step
			if not map.rooms.has(other):
				continue
			var col := PLAIN if _visited(c) and _visited(other) else UNSEEN
			# Drawn under the rooms and a PIXEL into each of them, so what shows
			# is the gap bridged edge to edge with no seam at either end.
			var r := _cell_rect(grid, c)
			if step.x == 1:
				_px.rect(Rect2(r.end.x - PX, r.get_center().y - LINK * PX * 0.5,
					GAP + PX * 2, LINK * PX), col)
			else:
				_px.rect(Rect2(r.get_center().x - LINK * PX * 0.5, r.end.y - PX,
					LINK * PX, GAP + PX * 2), col)

func _cell_rect(grid: Vector2, c: Vector2i) -> Rect2:
	return Rect2(grid + Vector2(c.x * (CELL + GAP), c.y * (CELL + GAP)), Vector2(CELL, CELL))

func _draw_rooms(grid: Vector2) -> void:
	for key in map.rooms:
		var c: Vector2i = key
		var rec: Dictionary = map.rooms[c]
		var r := _cell_rect(grid, c)
		var visited := _visited(c)
		_px.rect(r, UNSEEN if not visited else _kind_color(String(rec["kind"])))
		_px.frame(r, ROOM_EDGE)
		# An exit is the one thing on the plan worth crossing the floor for, so
		# it is marked on the room rather than left to the room's own colour.
		if visited and rec.has("extraction"):
			_px.diamond(r.get_center(), 4, EXIT_MARK)
		# What a death left here. Under the "you are here" box and over
		# everything else, because between the two of them they are the whole
		# route this map is being opened to plan.
		if rec.has("lost_kit"):
			_px.frame(r.grow(-PX), KIT_MARK)
			_draw_skull(_fell_at(r, rec["lost_kit"]))
		# Where the player is standing, drawn last and two PIXELs thick: it has
		# to be findable in one glance at a window full of rooms.
		if room != null and c == room.coord:
			_px.frame(r, YOU)
			_px.frame(r.grow(-PX), YOU)

## Where on the room's square `r` the spot the kit lies on falls, the room's
## width and height each squeezed into the square inside its gold frame. A drop
## with no spot of its own is put in the middle.
func _fell_at(r: Rect2, kit: Dictionary) -> Vector2:
	var inner := r.grow(-PX * 2 - SKULL.size() * PX * 0.5)
	var p: Array = kit.get("pos", [])
	if p.size() != 2:
		return inner.get_center()
	var f := Vector2(float(p[0]) / (Room.W * Room.CELL), float(p[1]) / (Room.H * Room.CELL))
	f = f.clamp(Vector2.ZERO, Vector2.ONE)
	return inner.position + inner.size * f

## The skull, centred on `c`, with a one-PIXEL rim round it.
func _draw_skull(c: Vector2) -> void:
	for d in [Vector2(-PX, 0), Vector2(PX, 0), Vector2(0, -PX), Vector2(0, PX)]:
		_px.icon_centered(c + d, SKULL_SOLID, ROOM_EDGE)
	_px.icon_centered(c, SKULL, KIT_MARK)

## What is worth explaining on this map. The drop is in the list only while
## there is one to find, so an ordinary raid's legend is the two rows it has
## always been.
func _legend_items() -> Array:
	var items := [
		["you", YOU, "frame"],
		["entry", KIND_COLORS["entry"], "fill"],
		["boss", KIND_COLORS["boss"], "fill"],
		["treasure", KIND_COLORS["treasure"], "fill"],
		["exit", EXIT_MARK, "fill"],
		["unseen", UNSEEN, "fill"],
	]
	if _has_kit():
		items.append(["kit", KIT_MARK, "skull"])
	return items

func _legend_rows() -> int:
	return int(ceil(float(_legend_items().size()) / float(LEGEND_COLS)))

func _has_kit() -> bool:
	if map == null:
		return false
	for key in map.rooms:
		if (map.rooms[key] as Dictionary).has("lost_kit"):
			return true
	return false

func _visited(c: Vector2i) -> bool:
	return bool((map.rooms[c] as Dictionary).get("visited", false))

func _kind_color(kind: String) -> Color:
	var col: Color = KIND_COLORS.get(kind, PLAIN)
	return col

## What the colours mean, three to a row. Every room on the plan is one of
## these, and a map nobody can read is a map that was not worth opening.
func _draw_legend(at: Vector2, width: float) -> void:
	var items := _legend_items()
	var col_w := floorf(width / float(LEGEND_COLS) / PX) * PX
	for i in items.size():
		var item: Array = items[i]
		@warning_ignore("integer_division")
		var cell := at + Vector2((i % LEGEND_COLS) * col_w, (i / LEGEND_COLS) * LEGEND_ROW)
		var swatch := Rect2(cell + Vector2(0, TEXT_DROP - SWATCH), Vector2(SWATCH, SWATCH))
		# Each looks the way it does on the map: the room you are standing in is
		# an outline, not a block of white nothing else is, and the kit a skull.
		match String(item[2]):
			"frame":
				_px.frame(swatch, item[1])
			"skull":
				_draw_skull(swatch.get_center())
			_:
				_px.rect(swatch, item[1])
		_px.text(cell + Vector2(SWATCH + 8.0, TEXT_DROP),
			Loc.t("hud.map.legend.%s" % String(item[0])), UiKit.DIM,
			col_w - SWATCH - 16.0)

## How tall the row that says how to put the map away stands. A phone has no
## row: there is no key to name on the glass, which is clear under the screen,
## and the way out is the back arrow along the top.
func _foot() -> float:
	return 0.0 if UiKit.mobile() else FOOT_H

func _draw_footer(win: Rect2) -> void:
	_px.text_centered(Vector2(win.position.x + PAD, win.end.y - PAD + 2.0),
		Loc.t("hud.map.close", [Controls.short_label_for("open_map")]),
		UiKit.DIM, win.size.x - PAD * 2.0)
