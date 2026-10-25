class_name MapTable
extends Control

## The table a map is laid on, in the map creator (`MapMaker`): the sheet in
## the middle; down the left the two tools, the tabs, and what there is to lay
## under the tab that is up, a tile each; and along the top the map's name and
## what is done with it — SAVE, LOAD, NEW, MAP, a step back and forward, PLAY.
##
## A tab is a layer of the map (`MadeRoom`): GROUND, CREATURES and THINGS lay
## the plan — the walls and the floor, seen from above, and what stands on the
## floor — and PROPS what is put about it. What is laid lays in the tab's
## layer, and ERASE, and the right button, take away what is in it there and
## nothing else.
##
## What is laid is drawn the way the game draws it, by the map's tileset
## (`MapTiles`) — its floor and its walls, in its colours — and what stands in
## it out of the game's own pieces: a monster as the atlas character its kind
## wears and the player's start as the player (`Sprites`), the box and the
## ground to dig in theirs (`TreasureBoxView`, `DigSpotView`), and what is put
## about it as it stands (`MapTiles.paint_prop_still`). They stand still here;
## PLAY is where they move and light the room.
##
## The sheet is drawn in chunks of the map (`MapTiles.Chunk`), each drawn once
## and again only when something in it changes, and laid over the screen at
## the zoom it is seen at — so moving the map or bringing it nearer draws
## nothing again, and a map four screens each way is drawn only where it is
## seen. What follows the pointer is drawn over it on a sheet of its own.
##
## A pointer's screen: the left button lays what is in hand, the right one
## erases, SHIFT held drags a box of either, and the map is moved under the
## pointer by the middle button, the move keys or the MOVE tool, and brought
## nearer or further by the wheel. The map's own edges are what it is made
## bigger or smaller by: a grip stands just outside each side and corner, and
## one dragged takes that side with it, a cell at a time, while the foot says
## what size the map is coming to — the left and the top as well as the right
## and the foot, what is on the map staying where it is. A thumb has MOVE and
## ERASE for what it has no button for. Nothing here takes the keyboard but the name, so the keys
## are the map's whenever the name is not being typed.
##
## It makes no change of its own: everything it does is asked of the maker,
## which is what a test asks too.

# Pixel art halves whole numbers on purpose, all the way down.
@warning_ignore_start("integer_division")

## How wide the column down the left is, and how tall the line along the
## bottom.
const SIDE_W := 232.0
const FOOT_H := 28.0
## What there is to lay stands in rows of this many tiles, each no narrower
## than this: they share the column's width between them.
const TILES_ACROSS := 4
const TILE_W := 46.0
## The room a panel of the table's keeps inside its edge, in either mode.
const PANEL_PAD := 8.0
## How much of a room's cell one of the sheet's is, nearest first. A raid's
## room is the screen across, so with the column beside it a whole one is only
## seen at half.
const ZOOMS := [1.0, 0.5]
## Screen pixels a second the move keys carry the map.
const PAN_SPEED := 900.0
## How far past its own edge the map can be moved, in cells.
const PAD_CELLS := 4
## How far past the map's edge, in pixels of the screen, the pointer has hold of
## the edge — a thumb's further — and how big a grip on it is drawn.
const GRAB := 14.0
const GRAB_THUMB := 28.0
const GRIP := 12.0
## How long a button that asks twice stays asked, and a line stays said.
const ARM_TIME := 3.0
const SAY_TIME := 4.0
## Cells to a chunk of the sheet, each way.
const CHUNK := 8
## The tools: MOVE lays nothing, and the left button carries the map with it;
## ERASE lays nothing in the layer of the tab that is up.
const MOVE := "move"
const ERASE := "."
## The tabs; and what each is called, by its key under `hud.maker.tab`.
## GROUND, CREATURES and THINGS all lay in the plan: the walls and the floor
## under the first, the player's start and the monsters under the second, and
## what else stands in a room under the third; PROPS lays the dressing.
enum Tab { GROUND, CREATURES, THINGS, PROPS }
const TAB_KEYS := ["ground", "creatures", "things", "props"]
## How the tabs stand down the column, a row at a time: two to a row, but
## CREATURES, whose name is wider than half the column, across it.
const TAB_ROWS := [[Tab.GROUND], [Tab.CREATURES], [Tab.THINGS, Tab.PROPS]]
## How far into what is put about a map a still picture of it has got: a flame
## halfway up, a firefly lit.
const STILL := 0.6

const GRID := Color(1, 1, 1, 0.05)
const SCREEN_LINE := Color(0.45, 0.85, 1.0, 0.22)
const ICON_MOVE := [
	"...#...",
	"..###..",
	".#.#.#.",
	"#######",
	".#.#.#.",
	"..###..",
	"...#...",
]
const ICON_ERASE := [
	"#.....#",
	".#...#.",
	"..#.#..",
	"...#...",
	"..#.#..",
	".#...#.",
	"#.....#",
]

var maker: MapMaker
## The tab that is up, and what is in hand: a mark of its layer, MOVE, or
## ERASE. Each tab keeps the mark it was last left on.
var tab: int = Tab.GROUND
var brush: String = MadeRoom.ROCK
var _brushes: Dictionary = {}
## The map's tileset, which draws it.
var tiles: MapTiles

var _px := PixelDraw.new(self)
var _zoom_at: int = ZOOMS.size() - 1
## Where the map's first cell starts, on the sheet.
var _origin := Vector2.ZERO
var _framed: bool = false
var _hover := Vector2i(-1, -1)
## The mark a stroke under way is laying, or "" between strokes, and the last
## cell it laid.
var _stroke: String = ""
var _laying := false
var _last := Vector2i.ZERO
## A box being dragged: the corner it started from and what it will lay.
var _boxing: bool = false
var _box_from := Vector2i.ZERO
var _box_mark: String = ""
## Whether the pointer is carrying the map, and where it last had hold of it.
var _panning: bool = false
var _pan_at := Vector2.ZERO
## Which of the map's edges the pointer is on, and which it is dragging, each
## way: -1 the left or the top, 1 the right or the foot, 0 neither. And while
## one is dragged, what the map is coming to, in the cells it has now.
var _edge_hover := Vector2i.ZERO
var _sizing := Vector2i.ZERO
var _sized_to := Rect2i()
## The line the foot is saying, in what colour, and for how much longer.
var _said: String = ""
var _said_tone := UiKit.TEXT
var _said_left: float = 0.0
## What has been asked once and waits to be asked again — "save:<id>" over
## another map's name, "delete:<id>" — and for how much longer.
var _armed: String = ""
var _armed_left: float = 0.0
## The name the field was last given by the maker, to see the map change.
var _shown_id: String = ""
## Whether the chrome was built for a thumb.
var _thumb: bool = false

## The map's cells as they stand, for the chunks to draw from.
var _cells: MapCells
## chunk -> its two pieces: the floor and the walls, and what stands in it and
## is put about it, over them.
var _chunks: Dictionary = {}

var _sheet: Sheet
var _canvas: Node2D
var _grounds: Node2D
var _overlays: Node2D
var _over: Over
var _bar: PanelContainer
var _side: PanelContainer
var _name: LineEdit
var _undo_button: Button
var _redo_button: Button
var _tools: Dictionary = {}
var _tabs: Dictionary = {}
var _grid: GridContainer
## mark -> its tile, for the tab that is up.
var _palette: Dictionary = {}
## The name of what is in hand, under the tiles.
var _in_hand: Label
var _zoom: Button
## The tile the pointer is on, or "" for none: the foot says its name.
var _over_tile: String = ""
## What is up over the table — the list of kept maps, or MAP — or null.
var _popup: Control = null
## MAP's own rows, while it is up.
var _wide: Label
var _high: Label
var _region: Button
var _weapon: Button

## The open air of the map, and what is past its edge: the ground the chunks
## are laid on.
class Sheet extends Control:
	var table: MapTable
	func _draw() -> void:
		table._paint_sheet(self)

## What follows the pointer over it: the grid, the cell it is on, a box being
## dragged.
class Over extends Control:
	var table: MapTable
	func _draw() -> void:
		table._paint_over(self)

func _ready() -> void:
	UiKit.fill_screen(self)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tiles = MapTiles.of(maker.tileset)
	_build()
	Loc.language_changed.connect(func(_lang: String) -> void: _build())

## --- the chrome -------------------------------------------------------------

## Everything on the table but the map's own state, built for the language and
## the mode in force: built again when either changes.
func _build() -> void:
	var typed := _name.text if _name != null else maker.map_id
	for old in get_children():
		remove_child(old)
		old.queue_free()
	_popup = null
	_chunks.clear()
	_thumb = UiKit.mobile()
	_sheet = Sheet.new()
	_sheet.table = self
	_sheet.clip_contents = true
	_sheet.gui_input.connect(_on_sheet_input)
	_sheet.mouse_exited.connect(func() -> void: _point_at(Vector2i(-1, -1)))
	add_child(_sheet)
	_canvas = Node2D.new()
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sheet.add_child(_canvas)
	for layer in 2:
		var holder := Node2D.new()
		_canvas.add_child(holder)
	_grounds = _canvas.get_child(0)
	_overlays = _canvas.get_child(1)
	_over = Over.new()
	_over.table = self
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.add_child(_over)
	_build_bar(typed)
	_build_side()
	_shown_id = maker.map_id
	_cells = MapCells.of_maker(maker)
	_fit()
	_moved()
	_refresh()

func _build_bar(typed: String) -> void:
	_bar = _panel()
	add_child(_bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_bar.add_child(row)
	var back := _button(Loc.t("menu.pause.arrow"), UiKit.ACCENT)
	back.custom_minimum_size.x = 44.0
	back.pressed.connect(func() -> void: maker.leave())
	row.add_child(back)
	row.add_child(_word(Loc.t("hud.maker.title"), Color(0.9, 0.95, 1.0)))
	_name = LineEdit.new()
	_name.text = typed
	_name.placeholder_text = Loc.t("hud.maker.name")
	_name.max_length = Maps.ID_LENGTH
	_name.custom_minimum_size = Vector2(220.0, _plate())
	_name.add_theme_font_override("font", UiKit.PIXEL_FONT)
	_name.add_theme_font_size_override("font_size", UiKit.PIXEL_TEXT)
	_name.add_theme_color_override("font_color", UiKit.TEXT)
	_name.add_theme_color_override("font_placeholder_color", UiKit.DIM)
	_name.add_theme_stylebox_override("normal", UiKit.style(UiKit.BG, UiKit.LINE, 1, 0, true))
	_name.add_theme_stylebox_override("focus", UiKit.style(Color(0, 0, 0, 0), UiKit.ACCENT, 1, 0, true))
	_name.text_submitted.connect(func(_text: String) -> void: _name.release_focus())
	row.add_child(_name)
	_bar_button(row, "hud.maker.save", UiKit.GOOD, _save)
	_bar_button(row, "hud.maker.load", UiKit.ACCENT, _open_list)
	_bar_button(row, "hud.maker.new", UiKit.ACCENT, _new)
	_bar_button(row, "hud.maker.map", UiKit.ACCENT, _open_map)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	_undo_button = _bar_button(row, "hud.maker.undo", UiKit.ACCENT, _undo)
	_redo_button = _bar_button(row, "hud.maker.redo", UiKit.ACCENT, _redo)
	var play := _bar_button(row, "hud.maker.play", UiKit.GOOD, func() -> void: maker.play())
	play.custom_minimum_size.x = 96.0

func _bar_button(row: HBoxContainer, key: String, tone: Color, press: Callable) -> Button:
	var b := _button(Loc.t(key), tone)
	b.pressed.connect(press)
	row.add_child(b)
	return b

func _build_side() -> void:
	_side = _panel()
	add_child(_side)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_side.add_child(column)
	# The two tools, which lay in no layer of their own.
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 4)
	column.add_child(tools)
	_tools.clear()
	for tool in [MOVE, ERASE]:
		var b := _button(name_of(tool), UiKit.ACCENT)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			(b.get_theme_stylebox(state) as StyleBoxFlat).content_margin_left = 28.0
		_chosen_look(b)
		b.pressed.connect(take.bind(tool))
		b.draw.connect(func() -> void:
			PixelDraw.new(b).icon_centered(Vector2(16.0, b.size.y * 0.5),
				ICON_MOVE if tool == MOVE else ICON_ERASE, Color.WHITE if b.disabled or b.is_hovered() else UiKit.TEXT))
		tools.add_child(b)
		_tools[tool] = b
	# The tabs, in their rows (TAB_ROWS).
	var tabs := VBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	column.add_child(tabs)
	_tabs.clear()
	for row_tabs: Array in TAB_ROWS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		tabs.add_child(row)
		for t: int in row_tabs:
			var b := _button(Loc.t("hud.maker.tab.%s" % TAB_KEYS[t]), UiKit.ACCENT)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.clip_text = true
			_chosen_look(b)
			b.pressed.connect(take_tab.bind(t))
			row.add_child(b)
			_tabs[t] = b
	column.add_child(UiKit.hline(true))
	# What there is to lay under the tab that is up.
	_grid = GridContainer.new()
	_grid.columns = TILES_ACROSS
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	column.add_child(_grid)
	_in_hand = _word("", UiKit.ACCENT)
	_in_hand.clip_text = true
	column.add_child(_in_hand)
	column.add_child(UiKit.hline(true))
	_zoom = _side_button(column, func() -> void:
		_zoom_to((_zoom_at + 1) % ZOOMS.size(), _sheet.size * 0.5))
	_build_palette()

## The tiles of the tab that is up.
func _build_palette() -> void:
	for old in _grid.get_children():
		_grid.remove_child(old)
		old.queue_free()
	_palette.clear()
	for entry in entries(tab):
		_grid.add_child(_tile(entry))

## What there is to lay under tab `t`, by mark, in order.
func entries(t: int) -> PackedStringArray:
	match t:
		Tab.GROUND:
			return tiles.ground_marks()
		Tab.CREATURES:
			return MadeRoom.creatures()
		Tab.THINGS:
			return MadeRoom.things()
	return PackedStringArray(MapTiles.PROPS.keys())

## The layer of the map tab `t` lays in.
static func layer_of(t: int) -> int:
	return MapMaker.DRESSING if t == Tab.PROPS else MapMaker.PLAN

## One thing to lay, as a tile with its picture on it. The one in hand is lit
## and cannot be pressed again; its name stands under the tiles, and the foot
## says the name of whichever the pointer is on.
func _tile(entry: String) -> Button:
	var b := _button("", UiKit.ACCENT)
	b.custom_minimum_size = Vector2(TILE_W, maxf(_plate(), 48.0))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chosen_look(b)
	var in_tab := tab
	b.pressed.connect(take.bind(entry))
	b.draw.connect(func() -> void: _paint_tile(b, entry, in_tab))
	b.mouse_entered.connect(func() -> void: _over_tile = entry)
	b.mouse_exited.connect(func() -> void:
		if _over_tile == entry:
			_over_tile = "")
	_palette[entry] = b
	return b

## A button that cannot be pressed because it is what is chosen: lit, not
## greyed.
static func _chosen_look(b: Button) -> void:
	var chosen := b.get_theme_stylebox("disabled") as StyleBoxFlat
	chosen.bg_color = Color(UiKit.ACCENT, 0.22)
	chosen.border_color = UiKit.ACCENT
	b.add_theme_color_override("font_disabled_color", Color.WHITE)

## A number with a way down and a way up either side of it. SHIFT takes ten.
func _stepper(column: VBoxContainer, words: String, step: Callable) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	column.add_child(row)
	var caption := _word(words, UiKit.TEXT)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.clip_text = true
	row.add_child(caption)
	var value := _word("", UiKit.ACCENT)
	value.custom_minimum_size.x = 56.0
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for by: int in [-1, 1]:
		var b := _button("-" if by < 0 else "+", UiKit.ACCENT)
		b.custom_minimum_size.x = maxf(34.0, _plate())
		b.pressed.connect(func() -> void: step.call(by * (10 if Input.is_key_pressed(KEY_SHIFT) else 1)))
		row.add_child(b)
		if by < 0:
			row.add_child(value)
	return value

func _side_button(column: VBoxContainer, press: Callable) -> Button:
	var b := _button("", UiKit.ACCENT)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.pressed.connect(press)
	column.add_child(b)
	return b

## A word standing beside the buttons, in the middle of the row's height.
func _word(words: String, tone: Color) -> Label:
	var l := UiKit.label(words, UiKit.PIXEL_TEXT, tone, true)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

## A button of the table's: the kit's pixel one, never taking the keyboard, and
## at the table's own size in either mode — a thumb's is taller, but there are
## too many of them on one screen to stand a full thumb each, or to keep a
## thumb's room either side of every word.
func _button(words: String, tone: Color) -> Button:
	var b := UiKit.overlay_button(words, tone, true)
	b.custom_minimum_size = Vector2(0.0, _plate())
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.add_theme_font_size_override("font_size", Loc.text_size(words, UiKit.PIXEL_TEXT))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := b.get_theme_stylebox(state) as StyleBoxFlat
		box.content_margin_left = 10.0
		box.content_margin_right = 10.0
	return b

## How tall a thing to press stands on the table.
func _plate() -> float:
	return 56.0 if _thumb else 34.0

## A panel of the table's: the kit's pixel one, keeping the same room inside
## its edge in either mode — the column down the left is one width, and a
## thumb's wider margin would not leave it room for its tiles.
func _panel() -> PanelContainer:
	var p := UiKit.panel(UiKit.PANEL, UiKit.LINE, true)
	var box := p.get_theme_stylebox("panel") as StyleBoxFlat
	box.content_margin_left = PANEL_PAD
	box.content_margin_right = PANEL_PAD
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p

## What a tool, or a mark of tab `in_tab`, is called, in the language being
## played.
func name_of(entry: String, in_tab: int = tab) -> String:
	if entry == MOVE:
		return Loc.t("hud.maker.tool.move")
	if entry == ERASE:
		return Loc.t("hud.maker.tool.erase")
	match in_tab:
		Tab.GROUND:
			return tiles.ground_name(entry)
		Tab.PROPS:
			return MapTiles.prop_name(entry)
	match entry:
		MadeRoom.START:
			return Loc.t("hud.maker.mark.start")
		MadeRoom.BOX:
			return Loc.t("hud.maker.mark.box")
		MadeRoom.DIG:
			return Loc.t("hud.maker.mark.dig")
		MadeRoom.BENCH:
			return Loc.t("hud.maker.mark.bench")
		MadeRoom.DOOR_WEST:
			return Loc.t("hud.maker.mark.door_west")
		MadeRoom.DOOR_EAST:
			return Loc.t("hud.maker.mark.door_east")
		MadeRoom.DOOR_NORTH:
			return Loc.t("hud.maker.mark.door_north")
		MadeRoom.DOOR_SOUTH:
			return Loc.t("hud.maker.mark.door_south")
		MadeRoom.EXIT:
			return Loc.t("hud.maker.mark.exit")
	var kind := MadeRoom.monster_of(entry)
	return Monsters.name_for(kind).to_upper() if kind != "" else entry

## Takes `entry` in hand: a mark of the tab that is up, MOVE, or ERASE.
func take(entry: String) -> void:
	brush = entry
	if entry != MOVE and entry != ERASE:
		_brushes[tab] = entry
	_refresh()

## Puts tab `t` up: its layer is the one laid in and erased from, and in hand
## is what was last taken from it — or its first tile — unless a tool is.
func take_tab(t: int) -> void:
	tab = t
	if brush != MOVE and brush != ERASE:
		var marks := entries(t)
		brush = String(_brushes.get(t, marks[0] if not marks.is_empty() else ERASE))
	_build_palette()
	_refresh()

## Puts on the chrome whatever the maker has that it shows.
func _refresh() -> void:
	for entry in _palette:
		(_palette[entry] as Button).disabled = entry == brush
		# Its picture is in the map's tileset, which may just have changed.
		(_palette[entry] as Button).queue_redraw()
	for tool in _tools:
		(_tools[tool] as Button).disabled = tool == brush
	for t in _tabs:
		(_tabs[t] as Button).disabled = t == tab
	_in_hand.text = name_of(brush)
	_zoom.text = Loc.t("hud.maker.zoom", [int(ZOOMS[_zoom_at] * 100.0)])
	if is_instance_valid(_wide):
		_wide.text = str(maker.cols)
	if is_instance_valid(_high):
		_high.text = str(maker.rows)
	if is_instance_valid(_region):
		_region.text = Loc.t("hud.maker.region", [maker.region + 1])
	if is_instance_valid(_weapon):
		_weapon.text = Loc.t("hud.maker.weapon", [Weapons.name_for(maker.current_weapon()).to_upper()])
	if maker.map_id != _shown_id:
		_shown_id = maker.map_id
		_name.text = maker.map_id

## Where everything stands for the screen as it is: the bar across the top, the
## column down the left, and the sheet in what is left over the foot.
func _fit() -> void:
	var bar_h := _bar.get_combined_minimum_size().y
	_bar.position = Vector2.ZERO
	_bar.size = Vector2(size.x, bar_h)
	_side.position = Vector2(0.0, bar_h)
	_side.size = Vector2(SIDE_W, size.y - bar_h)
	var room := Rect2(SIDE_W, bar_h, size.x - SIDE_W, size.y - bar_h - FOOT_H)
	if _sheet.position != room.position or _sheet.size != room.size:
		_sheet.position = room.position
		_sheet.size = room.size
		_over.size = room.size
		if not _framed:
			_framed = true
			_frame_map()
		_keep_in_sight()
		_moved()

func _process(delta: float) -> void:
	UiKit.sync_screen(self)
	if _thumb != UiKit.mobile():
		_build()
	_fit()
	_undo_button.disabled = not maker.can_undo()
	_redo_button.disabled = not maker.can_redo()
	_said_left = maxf(0.0, _said_left - delta)
	if _armed != "":
		_armed_left -= delta
		if _armed_left <= 0.0:
			_disarm()
	# The move keys carry the map — but not while they are typing a name, nor
	# while one of them is half of a shortcut: SAVE's is a move key too.
	if is_visible_in_tree() and _popup == null and not _name.has_focus() \
			and not Input.is_key_pressed(KEY_CTRL) and not Input.is_key_pressed(KEY_META):
		var push := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if push != Vector2.ZERO:
			_origin -= push * PAN_SPEED * delta
			_keep_in_sight()
			_moved()
	queue_redraw()

## --- the map on the sheet -----------------------------------------------------

## How many screen pixels a cell of the map is across.
func cell_size() -> float:
	return Room.CELL * float(ZOOMS[_zoom_at])

## The cell under a point of the sheet. It may be off the map.
func cell_at(at: Vector2) -> Vector2i:
	return Vector2i(((at - _origin) / cell_size()).floor())

## Where on the sheet the cell `c` is.
func cell_rect(c: Vector2i) -> Rect2:
	return Rect2(_origin + Vector2(c) * cell_size(), Vector2.ONE * cell_size())

## Stands the whole map in the middle of the sheet, where it fits there, and
## otherwise its top-left corner in the sheet's.
func _frame_map() -> void:
	var map := Vector2(maker.cols, maker.rows) * cell_size()
	_origin = ((_sheet.size - map) * 0.5).max(Vector2.ONE * cell_size())

## The map is never moved clean off the sheet: its middle stays within the
## map's own edges and a little. On whole pixels of the look, so nothing on it
## lands between two.
func _keep_in_sight() -> void:
	var cs := cell_size()
	var pad := Vector2.ONE * PAD_CELLS * cs
	var map := Vector2(maker.cols, maker.rows) * cs
	var middle := (_sheet.size * 0.5 - _origin).clamp(-pad, map + pad)
	_origin = ((_sheet.size * 0.5 - middle) / UiKit.PIXEL).round() * UiKit.PIXEL

## Brings the map nearer or further, about the point `about` of the sheet.
func _zoom_to(level: int, about: Vector2) -> void:
	level = clampi(level, 0, ZOOMS.size() - 1)
	if level == _zoom_at:
		return
	var under := (about - _origin) / cell_size()
	_zoom_at = level
	_origin = about - under * cell_size()
	_keep_in_sight()
	_moved()
	_refresh()

## The map went somewhere else on the sheet, or nearer or further: the chunks
## go with it, as they are, and any it has brought into sight are drawn.
func _moved() -> void:
	_canvas.position = _origin
	_canvas.scale = Vector2.ONE * float(ZOOMS[_zoom_at])
	_ensure_chunks()
	_sheet.queue_redraw()
	_over.queue_redraw()

## Every chunk in sight, and one round it, made — and drawn the once — if it
## was not there yet.
func _ensure_chunks() -> void:
	if _sheet.size.x <= 0.0 or _sheet.size.y <= 0.0:
		return
	var last := Vector2i(maker.cols, maker.rows) - Vector2i.ONE
	var from := (cell_at(Vector2.ZERO) - Vector2i.ONE * CHUNK).clamp(Vector2i.ZERO, last) / CHUNK
	var to := (cell_at(_sheet.size) + Vector2i.ONE * CHUNK).clamp(Vector2i.ZERO, last) / CHUNK
	var whole := Rect2i(0, 0, maker.cols, maker.rows)
	for cy in range(from.y, to.y + 1):
		for cx in range(from.x, to.x + 1):
			var key := Vector2i(cx, cy)
			if _chunks.has(key):
				continue
			var area := Rect2i(key * CHUNK, Vector2i.ONE * CHUNK).intersection(whole)
			_chunks[key] = [_chunk(_grounds, area, _paint_grounds), _chunk(_overlays, area, _paint_overlays)]

func _chunk(holder: Node2D, area: Rect2i, paint: Callable) -> MapTiles.Chunk:
	var chunk := MapTiles.Chunk.new()
	chunk.area = area
	chunk.paint = paint
	holder.add_child(chunk)
	return chunk

## Every chunk gone, to be made again as it comes into sight: for a map that is
## another size, or another map.
func _drop_chunks() -> void:
	for key in _chunks:
		for chunk: Node2D in _chunks[key]:
			chunk.queue_free()
	_chunks.clear()

## Draws again every chunk the cells of `area` of `layer` could change the
## look of. A cell of the plan is drawn as it meets its neighbours, so theirs
## are drawn again too. What is put about the map changes the look of nothing
## but itself.
func _touch(area: Rect2i, layer: int = MapMaker.PLAN) -> void:
	var near := area.grow(1)
	if layer != MapMaker.DRESSING:
		_redraw(near, 0)
	_redraw(near, 1)

## Draws again piece `piece` (0 the floor and the walls, 1 what stands and is
## put about; -1 both) of every chunk `area` touches.
func _redraw(area: Rect2i, piece: int) -> void:
	var from := area.position.max(Vector2i.ZERO) / CHUNK
	var to := area.end.max(Vector2i.ZERO) / CHUNK
	for cy in range(from.y, to.y + 1):
		for cx in range(from.x, to.x + 1):
			var pieces: Array = _chunks.get(Vector2i(cx, cy), [])
			for i in pieces.size():
				if piece < 0 or i == piece:
					(pieces[i] as Node2D).queue_redraw()

## What is past the map's edge, and the ground under the map, under the chunks.
func _paint_sheet(cv: CanvasItem) -> void:
	cv.draw_rect(Rect2(Vector2.ZERO, _sheet.size), tiles.outside_colour())
	tiles.paint_open(cv, Rect2(_origin, Vector2(maker.cols, maker.rows) * cell_size()))

## The floor of every cell, and over it the walls and the pits.
func _paint_grounds(c: CanvasItem, area: Rect2i) -> void:
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			tiles.paint_floor(c, _cells, x, y)
			# Magic stone is drawn here whether or not magic is on: the table
			# shows what was laid, and the room decides what is there.
			if _cells.solid(x, y) or _cells.ground(x, y) == MadeRoom.MAGIC:
				tiles.paint_ground(c, _cells, x, y)
			elif _cells.pit(x, y):
				tiles.paint_pit(c, _cells, x, y)

## What stands in the map, and what is put about it.
func _paint_overlays(c: CanvasItem, area: Rect2i) -> void:
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var mark := _cells.ground(x, y)
			if mark != MadeRoom.OPEN and mark != MadeRoom.PIT and not MadeRoom.is_ground(mark) and mark != MadeRoom.MAGIC:
				paint_mark(c, mark, Rect2(Vector2(x, y) * Room.CELL, Vector2.ONE * Room.CELL))
			if _cells.prop(x, y) != MadeRoom.OPEN:
				tiles.paint_prop_still(c, _cells, x, y, STILL)

func _paint_over(cv: CanvasItem) -> void:
	var cs := cell_size()
	var view := Rect2(Vector2.ZERO, _sheet.size)
	var across := Vector2i(maker.cols, maker.rows)
	var map := Rect2(_origin, Vector2(across) * cs)
	# The grid, a line a cell and a brighter one a screen: a raid's room is one
	# screen, and a camera follows the player past it.
	var first := Vector2i(((view.position - _origin) / cs).floor()).clamp(Vector2i.ZERO, across)
	var last := Vector2i(((view.end - _origin) / cs).ceil()).clamp(Vector2i.ZERO, across)
	var line := maxf(1.0, UiKit.PIXEL * cs / Room.CELL)
	for x in range(first.x, last.x + 1):
		cv.draw_rect(Rect2(_origin.x + x * cs, map.position.y, line, map.size.y),
			SCREEN_LINE if x % Room.W == 0 else GRID)
	for y in range(first.y, last.y + 1):
		cv.draw_rect(Rect2(map.position.x, _origin.y + y * cs, map.size.x, line),
			SCREEN_LINE if y % Room.H == 0 else GRID)
	if _popup != null:
		return
	_paint_grips(cv, map)
	if _sizing != Vector2i.ZERO:
		var coming := Rect2(_origin + Vector2(_sized_to.position) * cs, Vector2(_sized_to.size) * cs)
		cv.draw_rect(coming, Color(UiKit.ACCENT, 0.10))
		_edge(cv, coming, UiKit.ACCENT)
		return
	if brush == MOVE and not _boxing:
		return
	if _boxing:
		var a := cell_rect(_box_from.clamp(Vector2i.ZERO, across - Vector2i.ONE))
		var b := cell_rect(_hover.clamp(Vector2i.ZERO, across - Vector2i.ONE))
		var box := a.merge(b)
		cv.draw_rect(box, Color(UiKit.ACCENT, 0.18))
		_edge(cv, box, UiKit.ACCENT)
	elif maker.holds(_hover):
		_edge(cv, cell_rect(_hover), Color.WHITE)

## A grip just outside each corner of the map and halfway along each of its
## sides, to drag that side by — lit, with the side itself, where the pointer
## has hold of one or is on it.
func _paint_grips(cv: CanvasItem, map: Rect2) -> void:
	var held := _sizing if _sizing != Vector2i.ZERO else _edge_hover
	var px := float(UiKit.PIXEL)
	var out := px * 2.0
	for sy: int in [-1, 0, 1]:
		for sx: int in [-1, 0, 1]:
			if sx == 0 and sy == 0:
				continue
			var at := Vector2(
				map.position.x - out - GRIP if sx < 0 else (map.end.x + out if sx > 0 else map.get_center().x - GRIP * 0.5),
				map.position.y - out - GRIP if sy < 0 else (map.end.y + out if sy > 0 else map.get_center().y - GRIP * 0.5))
			var grip := Rect2((at / px).round() * px, Vector2(GRIP, GRIP))
			var lit := (held.x != 0 and sx == held.x) or (held.y != 0 and sy == held.y)
			cv.draw_rect(grip, UiKit.ACCENT if lit else UiKit.DIM)
			_edge(cv, grip, UiKit.BG)
	if held.x != 0:
		cv.draw_rect(Rect2(map.position.x - px if held.x < 0 else map.end.x, map.position.y, px, map.size.y), UiKit.ACCENT)
	if held.y != 0:
		cv.draw_rect(Rect2(map.position.x, map.position.y - px if held.y < 0 else map.end.y, map.size.x, px), UiKit.ACCENT)

## A border a PIXEL wide, inside `r`.
func _edge(cv: CanvasItem, r: Rect2, col: Color) -> void:
	var w := float(UiKit.PIXEL)
	cv.draw_rect(Rect2(r.position, Vector2(r.size.x, w)), col)
	cv.draw_rect(Rect2(r.position.x, r.end.y - w, r.size.x, w), col)
	cv.draw_rect(Rect2(r.position.x, r.position.y + w, w, r.size.y - w * 2.0), col)
	cv.draw_rect(Rect2(r.end.x - w, r.position.y + w, w, r.size.y - w * 2.0), col)

## --- what stands in the map, drawn ----------------------------------------------

## What `mark` of the plan stands for — a monster's post, the player's start,
## the box, the ground to dig, a bench — drawn in the cell `r` as the game
## draws it, standing with its feet in the middle of the cell, where a made
## room stands it (`MadeRoom.stand_point`), smaller by as much as `r` is
## smaller than a room's cell. A raid room's ways out — a doorway in any of
## the four walls, its exit — are open cells in the game, and drawn here as
## signs: an arrow the way each leads, and the exit's diamond.
static func paint_mark(cv: CanvasItem, mark: String, r: Rect2) -> void:
	var k := r.size.x / float(Room.CELL)
	if MadeRoom.WAYS.has(mark):
		_paint_way(cv, int(MadeRoom.WAYS[mark]), r)
		return
	if mark == MadeRoom.EXIT:
		_paint_exit(cv, r)
		return
	var feet := r.get_center()
	match mark:
		MadeRoom.START:
			_paint_body(cv, Style.PLAYER_ART, Color.WHITE, feet, k, 0.0)
		MadeRoom.BOX:
			_paint_box(cv, feet, k)
		MadeRoom.DIG:
			_paint_dig(cv, feet, k)
		MadeRoom.BENCH:
			BenchView.paint(cv, feet, float(PixelCamera.SCALE) * k)
		_:
			var kind := MadeRoom.monster_of(mark)
			if kind != "":
				_paint_body(cv, Style.monster_art(kind), Style.monster_tint(kind), feet, k,
					Enemy.FLY_HEIGHT * k if flies(mark) else 0.0)

## A way out of the room, an arrow in the cell pointing the way it leads:
## through a doorway in the west, east, north or south wall, on a plate.
static func _paint_way(cv: CanvasItem, side: int, r: Rect2) -> void:
	var inner := r.grow(-r.size.x * 0.12)
	cv.draw_rect(inner, Color(0.1, 0.16, 0.22, 0.85))
	cv.draw_rect(inner, WAY_INK, false, maxf(1.0, r.size.x / 16.0))
	var c := inner.get_center()
	var v := Vector2(Components.dir_to_vec(side))
	var side_v := v.orthogonal()
	var reach := inner.size.x * 0.32
	cv.draw_colored_polygon(PackedVector2Array([c + v * reach, c - v * reach * 0.6 + side_v * reach * 0.8,
		c - v * reach * 0.6 - side_v * reach * 0.8]), WAY_INK)

## The way out of the raid, as the map has it: the green diamond of an exit.
static func _paint_exit(cv: CanvasItem, r: Rect2) -> void:
	var c := r.get_center()
	var reach := r.size.x * 0.36
	cv.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -reach), c + Vector2(reach, 0),
		c + Vector2(0, reach), c + Vector2(-reach, 0)]), MapPanel.EXIT_MARK)

## What a doorway's and a gate's arrow is drawn in.
const WAY_INK := Color(0.55, 0.9, 1.0)

## Whether `mark` posts a monster that flies: one drawn up off the floor
## (`Enemy.FLY_HEIGHT`) rather than standing on it.
static func flies(mark: String) -> bool:
	var kind := MadeRoom.monster_of(mark)
	return kind != "" and String(Monsters.get_def(kind)["ai"]) == "flyer"

## A character standing at `feet`: its first idle frame at the size every
## sprite is drawn (`Sprites.PIXEL_SCALE`), its drawn feet there — or `lift`
## up off the floor, for one that flies.
static func _paint_body(cv: CanvasItem, art: String, tint: Color, feet: Vector2, k: float, lift: float) -> void:
	var frames := Sprites.resolved_frames(art)
	if frames == null or not frames.has_animation("idle") or frames.get_frame_count("idle") == 0:
		return
	var s := Sprites.PIXEL_SCALE * k
	var drawn := Sprites.art_rect(art)
	var at := Vector2(feet.x - drawn.get_center().x * s, feet.y - lift - drawn.end.y * s)
	cv.draw_texture_rect(frames.get_frame_texture("idle", 0),
		Rect2(at.round(), Sprites.frame_size(art) * s), false, tint)

## The box, shut, as `TreasureBoxView` draws it, standing at `feet`.
static func _paint_box(cv: CanvasItem, feet: Vector2, k: float) -> void:
	var w := TreasureBoxView.W * k
	var h := TreasureBoxView.H * k
	var lid := TreasureBoxView.LID_H * k
	var body := Rect2(feet.x - w * 0.5, feet.y - h, w, h)
	var glow := Style.TREASURE_GLOW
	glow.a = 0.22
	cv.draw_circle(Vector2(body.get_center().x, body.position.y + 2.0 * k), 20.0 * k, glow)
	var top := Rect2(body.position.x - k, body.position.y - lid, w + 2.0 * k, lid)
	cv.draw_rect(top, Style.TREASURE_WOOD)
	cv.draw_rect(top, Style.TREASURE_EDGE, false, 2.0 * k)
	cv.draw_rect(Rect2(top.position.x, top.get_center().y - k, top.size.x, 2.0 * k), Style.TREASURE_BAND)
	cv.draw_rect(body, Style.TREASURE_WOOD)
	cv.draw_rect(Rect2(body.position.x, body.position.y + 4.0 * k, w, 3.0 * k), Style.TREASURE_BAND)
	cv.draw_rect(Rect2(body.get_center().x - 2.0 * k, body.position.y + 3.0 * k, 4.0 * k, 5.0 * k), Style.TREASURE_BAND)
	cv.draw_rect(body, Style.TREASURE_EDGE, false, 2.0 * k)

## Ground worth digging, as `DigSpotView` draws it: a lit mound at `feet`.
static func _paint_dig(cv: CanvasItem, feet: Vector2, k: float) -> void:
	var px := float(PixelCamera.SCALE) * k
	var w := DigSpotView.W * k
	var left := feet.x - w * 0.5
	var ground := feet.y
	var glow := DigSpotView.GLOW
	glow.a = 0.2
	cv.draw_circle(Vector2(feet.x, ground - px * 2.0), 18.0 * k, glow)
	cv.draw_rect(Rect2(left, ground - px, w, px), DigSpotView.EARTH_DARK)
	cv.draw_rect(Rect2(left + px, ground - px * 2.0, w - px * 2.0, px), DigSpotView.EARTH)
	cv.draw_rect(Rect2(left + px * 3.0, ground - px * 3.0, w - px * 6.0, px), DigSpotView.EARTH)
	cv.draw_rect(Rect2(left + px * 4.0, ground - px * 3.0, px * 3.0, px), DigSpotView.EARTH_LIT)
	cv.draw_rect(Rect2(left + px * 2.0, ground - px * 2.0, px * 2.0, px), DigSpotView.EARTH_LIT)
	cv.draw_rect(Rect2(feet.x, ground - px * 4.0, px, px), Color(1.0, 0.95, 0.7))

## A tile's picture: for the ground and what is put about, the tileset's own
## (`MapTiles.icon`); for what stands in the map, the thing itself in the
## middle of the tile, at the size the game draws it where that fits the tile
## and at half that where it does not — the Warden and the Arbiter are too big
## for one.
func _paint_tile(b: Button, entry: String, in_tab: int) -> void:
	var room := Rect2(Vector2.ZERO, b.size).grow(-4.0)
	if in_tab != Tab.THINGS and in_tab != Tab.CREATURES:
		tiles.icon(b, layer_of(in_tab), entry, room.get_center().round(), 1.0)
		return
	var stands := stands_in(entry)
	var k := 1.0 if stands.size.x <= room.size.x and stands.size.y <= room.size.y else 0.5
	var cs := Room.CELL * k
	var tall := stands.size.y * k
	# In the middle of the tile, whatever its own shape: `stands_in` is measured
	# from the thing's feet.
	var foot := Vector2(room.get_center().x - stands.get_center().x * k,
		room.get_center().y + tall * 0.5 - stands.end.y * k)
	paint_mark(b, entry, Rect2(foot - Vector2.ONE * cs * 0.5, Vector2.ONE * cs))

## The room what `mark` of the plan stands for takes up at the game's own size,
## measured from its feet, the middle of its cell: across from there, and up
## from it.
static func stands_in(mark: String) -> Rect2:
	var c := float(Room.CELL)
	match mark:
		MadeRoom.BOX:
			var high := TreasureBoxView.H + TreasureBoxView.LID_H
			return Rect2(-TreasureBoxView.W * 0.5 - 1.0, -high, TreasureBoxView.W + 2.0, high)
		MadeRoom.DIG:
			return Rect2(-DigSpotView.W * 0.5, -PixelCamera.SCALE * 4.0, DigSpotView.W, PixelCamera.SCALE * 4.0)
		MadeRoom.BENCH:
			var s := float(PixelCamera.SCALE)
			return Rect2(-(BenchView.WIDE * 0.5 + 1.0) * s, -BenchView.BACK * s, (BenchView.WIDE + 2.0) * s, BenchView.BACK * s)
	if MadeRoom.WAYS.has(mark) or mark == MadeRoom.EXIT:
		return Rect2(-c * 0.5, -c * 0.5, c, c)
	var art := Style.PLAYER_ART if mark == MadeRoom.START else Style.monster_art(MadeRoom.monster_of(mark))
	var drawn := Sprites.art_rect(art).size * Sprites.PIXEL_SCALE
	var lift := Enemy.FLY_HEIGHT if flies(mark) else 0.0
	return Rect2(-drawn.x * 0.5, -drawn.y - lift, drawn.x, drawn.y + lift)

## --- the pointer on the sheet -------------------------------------------------

func _on_sheet_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		var cell := cell_at(click.position)
		if click.pressed:
			# The name lets go of the keyboard: the keys are the map's again.
			get_viewport().gui_release_focus()
			if _sizing != Vector2i.ZERO:
				# Another button while an edge is dragged lets it go where it was.
				_sizing = Vector2i.ZERO
				_over.queue_redraw()
				_sheet.accept_event()
				return
			match click.button_index:
				MOUSE_BUTTON_LEFT:
					var edge := edge_at(click.position)
					if edge != Vector2i.ZERO:
						_begin_sizing(edge)
					elif brush == MOVE:
						_begin_pan(click.position)
					elif click.shift_pressed:
						_begin_box(cell, brush)
					else:
						_begin_stroke(cell, brush)
				MOUSE_BUTTON_RIGHT:
					if click.shift_pressed:
						_begin_box(cell, ERASE)
					else:
						_begin_stroke(cell, ERASE)
				MOUSE_BUTTON_MIDDLE:
					_begin_pan(click.position)
				MOUSE_BUTTON_WHEEL_UP:
					_zoom_to(_zoom_at - 1, click.position)
				MOUSE_BUTTON_WHEEL_DOWN:
					_zoom_to(_zoom_at + 1, click.position)
		elif click.button_index == MOUSE_BUTTON_LEFT and _sizing != Vector2i.ZERO:
			_end_sizing()
		elif click.button_index == MOUSE_BUTTON_LEFT or click.button_index == MOUSE_BUTTON_RIGHT:
			if _boxing:
				_boxing = false
				maker.begin_stroke()
				if maker.lay_box(_box_from, cell, _box_mark, layer_of(tab)):
					_changed(Rect2i(_box_from.min(cell), (_box_from - cell).abs() + Vector2i.ONE), _box_mark)
			_laying = false
			_stroke = ""
			if click.button_index == MOUSE_BUTTON_LEFT:
				_panning = false
		elif click.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = false
		_point_at(cell)
		_sheet.accept_event()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var cell := cell_at(motion.position)
		if not _panning and not _laying and not _boxing and _sizing == Vector2i.ZERO:
			var edge := edge_at(motion.position)
			if edge != _edge_hover:
				_edge_hover = edge
				_over.queue_redraw()
		if _sizing != Vector2i.ZERO:
			_size_to(motion.position)
		elif _panning:
			# By how far the pointer has got, not by what the event says it moved:
			# a thumb's drag, handed over as a mouse's, says nothing of that.
			_origin += motion.position - _pan_at
			_pan_at = motion.position
			_keep_in_sight()
			_moved()
		elif _laying:
			if maker.lay_line(_last, cell, _stroke, layer_of(tab)):
				_changed(Rect2i(_last.min(cell), (_last - cell).abs() + Vector2i.ONE), _stroke)
			_last = cell
		_point_at(cell)
	elif event is InputEventPanGesture:
		# Two fingers on a trackpad move the map, as they move any page. Taken
		# here, so that nothing further up the tree is handed the same gesture.
		_origin -= (event as InputEventPanGesture).delta * 12.0
		_keep_in_sight()
		_moved()
		_sheet.accept_event()
	elif event is InputEventMagnifyGesture:
		var pinch := event as InputEventMagnifyGesture
		if absf(pinch.factor - 1.0) > 0.02:
			_zoom_to(_zoom_at - 1 if pinch.factor > 1.0 else _zoom_at + 1, pinch.position)
		_sheet.accept_event()

## Lays `mark` from `cell`, and on along the drag. ERASE is a mark too: it
## lays nothing.
func _begin_stroke(cell: Vector2i, mark: String) -> void:
	maker.begin_stroke()
	_stroke = mark
	_laying = true
	_last = cell
	if maker.lay(cell, mark, layer_of(tab)):
		_changed(Rect2i(cell, Vector2i.ONE), mark)

func _begin_box(cell: Vector2i, mark: String) -> void:
	_boxing = true
	_box_from = cell
	_box_mark = mark

func _begin_pan(at: Vector2) -> void:
	_panning = true
	_pan_at = at

## Which of the map's edges the point `at` of the sheet has hold of, each way:
## -1 its left or its top, 1 its right or its foot, 0 neither — anywhere from
## the edge out to GRAB past it, and at a corner both. Inside the map is all
## for laying, edge cells as much as any.
func edge_at(at: Vector2) -> Vector2i:
	var map := Rect2(_origin, Vector2(maker.cols, maker.rows) * cell_size())
	var reach := GRAB_THUMB if _thumb else GRAB
	if map.has_point(at) or not map.grow(reach).has_point(at) or _popup != null:
		return Vector2i.ZERO
	var side := Vector2i.ZERO
	if at.x < map.position.x:
		side.x = -1
	elif at.x >= map.end.x:
		side.x = 1
	if at.y < map.position.y:
		side.y = -1
	elif at.y >= map.end.y:
		side.y = 1
	return side

## Takes hold of the edges `edge` says, the map as it is to start from.
func _begin_sizing(edge: Vector2i) -> void:
	_sizing = edge
	_edge_hover = edge
	_sized_to = Rect2i(0, 0, maker.cols, maker.rows)
	_over.queue_redraw()

## The edges held, taken to the line between cells nearest `at` — no nearer
## the other side than the least a map may be, and no further from it than the
## most — in the cells the map has now.
func _size_to(at: Vector2) -> void:
	var to := ((at - _origin) / cell_size()).round()
	var lo := Vector2i.ZERO
	var hi := Vector2i(maker.cols, maker.rows)
	for axis in 2:
		if _sizing[axis] < 0:
			lo[axis] = clampi(int(to[axis]), hi[axis] - MapMaker.MAX_SIZE[axis], hi[axis] - MapMaker.MIN_SIZE[axis])
		elif _sizing[axis] > 0:
			hi[axis] = clampi(int(to[axis]), lo[axis] + MapMaker.MIN_SIZE[axis], lo[axis] + MapMaker.MAX_SIZE[axis])
	var now := Rect2i(lo, hi - lo)
	if now != _sized_to:
		_sized_to = now
		_over.queue_redraw()

## Lets go of the edges: the map made the size it was dragged to — a step to
## take back, like a stroke — and what was on it left where it was on the
## sheet, the cells grown at its left and top coming in before it.
func _end_sizing() -> void:
	var to := _sized_to
	_sizing = Vector2i.ZERO
	if maker.resize(to.size, -to.position):
		_origin += Vector2(to.position) * cell_size()
		_changed_all()
		_keep_in_sight()
		_moved()
	_over.queue_redraw()

func _point_at(cell: Vector2i) -> void:
	if cell != _hover or _boxing:
		_hover = cell
		_over.queue_redraw()

## The cells of `area` changed, laying `mark`: the chunks they could change the
## look of are drawn again, and the chrome says what the map is now. A mark the
## plan holds one of was moved from wherever it was, which could be anywhere.
func _changed(area: Rect2i, mark: String = "") -> void:
	_cells = MapCells.of_maker(maker)
	var layer := layer_of(tab)
	if layer == MapMaker.PLAN and MadeRoom.ONE_OF.has(mark):
		_touch(Rect2i(0, 0, maker.cols, maker.rows), layer)
	else:
		_touch(area, layer)
	_refresh()
	_over.queue_redraw()

## Anything about the map may have changed — its size, its tileset, all of it:
## every chunk is made again as it comes into sight.
func _changed_all() -> void:
	tiles = MapTiles.of(maker.tileset)
	_cells = MapCells.of_maker(maker)
	_drop_chunks()
	_moved()
	_build_palette()
	_refresh()

## The keys that are the table's own: a step back and forward, and SAVE, the
## way they are everywhere. The name, while it is being typed, keeps its keys
## to itself, and none of these reaches here.
func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _popup != null or not event.is_pressed() or event.is_echo():
		return
	var key := event as InputEventKey
	if key == null or not key.is_command_or_control_pressed():
		return
	match key.keycode:
		KEY_Z:
			if key.shift_pressed:
				_redo()
			else:
				_undo()
		KEY_Y:
			_redo()
		KEY_S:
			_save()
		_:
			return
	get_viewport().set_input_as_handled()

## The cancel key puts away what is up over the table, the way it closes every
## other window here, before it would pause the table behind it.
func _unhandled_input(event: InputEvent) -> void:
	if _popup != null and is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		_close_popup()
		get_viewport().set_input_as_handled()
	elif _sizing != Vector2i.ZERO and event.is_action_pressed("ui_cancel"):
		# An edge being dragged is let go where it was.
		_sizing = Vector2i.ZERO
		_over.queue_redraw()
		get_viewport().set_input_as_handled()

## --- what the bar does --------------------------------------------------------

## Says a line along the foot for a while.
func _tell(line: String, tone: Color = UiKit.TEXT) -> void:
	_said = line
	_said_tone = tone
	_said_left = SAY_TIME

func _arm(what: String) -> void:
	_armed = what
	_armed_left = ARM_TIME

func _disarm() -> void:
	var was := _armed
	_armed = ""
	if _popup != null and was.begins_with("delete:"):
		_fill_list()

## SAVE: the map is kept under the name in the field. Under the name of another
## map that is kept already, the first press only asks.
func _save() -> void:
	var id := Maps.id_for(_name.text)
	if id != "" and id != maker.map_id and Maps.exists(id) and _armed != "save:" + id:
		_arm("save:" + id)
		_tell(Loc.t("hud.maker.replace", [id.to_upper()]), UiKit.WARN)
		Audio.play("ui")
		return
	_armed = ""
	var refused := maker.save_as(_name.text)
	if refused != "":
		_tell(Loc.t("hud.maker.refused.%s" % refused), UiKit.BAD)
		Audio.play("deny")
		return
	_tell(Loc.t("hud.maker.saved", [Maps.path_of(id)]), UiKit.GOOD)
	Audio.play("ui")
	_refresh()

func _new() -> void:
	maker.new_map()
	_frame_map()
	_changed_all()
	Audio.play("ui")

func _undo() -> void:
	if maker.undo():
		_keep_in_sight()
		_changed_all()

func _redo() -> void:
	if maker.redo():
		_keep_in_sight()
		_changed_all()

func _resize(by: Vector2i) -> void:
	if maker.resize(Vector2i(maker.cols, maker.rows) + by):
		_keep_in_sight()
		_changed_all()

## Draws the map in the tileset `id`.
func _set_tileset(id: String) -> void:
	if id == maker.tileset:
		return
	maker.set_tileset(id)
	_changed_all()
	# MAP is built again for it, once this press is over: what it offers
	# depends on the tileset.
	if _popup != null:
		_fill_map.call_deferred()

## --- what is put up over the table ------------------------------------------------

func _open_popup() -> bool:
	if _popup != null:
		return false
	_laying = false
	_stroke = ""
	_boxing = false
	_popup = Control.new()
	_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_popup)
	_over.queue_redraw()
	Audio.play("ui")
	return true

func _close_popup() -> void:
	if _popup == null:
		return
	remove_child(_popup)
	_popup.queue_free()
	_popup = null
	_armed = ""
	_wide = null
	_high = null
	_region = null
	_weapon = null
	_over.queue_redraw()
	Audio.play("ui")

## A frame over a shade, under `heading`, with the way back pinned at its foot.
func _frame(heading: String) -> UiKit.ScreenFrame:
	for old in _popup.get_children():
		_popup.remove_child(old)
		old.queue_free()
	_popup.add_child(UiKit.shade())
	var frame := UiKit.screen_frame(560.0, 56.0, 28.0, true)
	_popup.add_child(frame)
	frame.head.add_child(UiKit.title(heading, UiKit.text(24), true))
	frame.head.add_child(UiKit.hline(true))
	frame.foot.add_child(UiKit.spacer(8))
	var back := UiKit.overlay_button(Loc.t("hud.maker.back"), UiKit.ACCENT, true)
	back.pressed.connect(_close_popup)
	frame.foot.add_child(back)
	return frame

## LOAD: every map that is kept, each a button that puts it on the table, with
## a way to throw it away beside it that asks twice.
func _open_list() -> void:
	if _open_popup():
		_fill_list()

func _fill_list() -> void:
	var frame := _frame(Loc.t("hud.maker.load_heading"))
	var ids := Maps.ids()
	if ids.is_empty():
		frame.rows.add_child(UiKit.label(Loc.t("hud.maker.none"), UiKit.text(16), UiKit.DIM, true))
	for id in ids:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		frame.rows.add_child(row)
		var pick := UiKit.overlay_button(id.to_upper(), UiKit.ACCENT, true)
		pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.pressed.connect(func() -> void: _load(id))
		row.add_child(pick)
		var armed := _armed == "delete:" + id
		var bin := UiKit.overlay_button(Loc.t("hud.maker.sure" if armed else "hud.maker.delete"),
			UiKit.BAD if armed else UiKit.DIM, true)
		bin.pressed.connect(func() -> void: _delete(id))
		row.add_child(bin)

func _load(id: String) -> void:
	if not maker.open(id):
		_tell(Loc.t("hud.maker.refused.read"), UiKit.BAD)
		Audio.play("deny")
		return
	_close_popup()
	_frame_map()
	_keep_in_sight()
	_changed_all()
	_tell(Loc.t("hud.maker.loaded", [id.to_upper()]), UiKit.GOOD)

## Throwing a map away cannot be undone, so the first press only asks.
func _delete(id: String) -> void:
	if _armed != "delete:" + id:
		_arm("delete:" + id)
		_fill_list()
		Audio.play("ui")
		return
	_armed = ""
	Maps.remove(id)
	_fill_list()
	_tell(Loc.t("hud.maker.deleted", [id.to_upper()]), UiKit.WARN)
	Audio.play("deny")

## MAP: what the map is besides its cells — the tileset it is drawn in, how big
## it is, the plain rock's tint, and the weapon a played map starts in hand.
func _open_map() -> void:
	if _open_popup():
		_fill_map()

func _fill_map() -> void:
	if _popup == null:
		return
	var frame := _frame(Loc.t("hud.maker.map_heading"))
	var titles := PackedStringArray()
	for id in MapTiles.IDS:
		titles.append(MapTiles.of(id).title())
	frame.rows.add_child(UiKit.choice_row(Loc.t("hud.maker.tileset"), titles,
		MapTiles.IDS.find(tiles.id()), func(i: int) -> void: _set_tileset(String(MapTiles.IDS[i]))))
	_wide = _stepper(frame.rows, Loc.t("hud.maker.width"), func(by: int) -> void: _resize(Vector2i(by, 0)))
	_high = _stepper(frame.rows, Loc.t("hud.maker.height"), func(by: int) -> void: _resize(Vector2i(0, by)))
	_region = null
	if tiles.id() == "rock":
		_region = _side_button(frame.rows, func() -> void:
			maker.set_region((maker.region + 1) % Style.REGION_TINT.size())
			_changed_all())
	_weapon = _side_button(frame.rows, func() -> void:
		maker.cycle_weapon()
		_refresh())
	_refresh()

## --- the table itself -----------------------------------------------------------

## The ground under everything, and the line along the foot: what the table
## last said, or the name of the tile the pointer is on, or else what the
## pointer does here; and on the right the cell under the pointer, the map's
## size, and whether it has changed since it was kept.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiKit.BG)
	var foot := Rect2(SIDE_W, size.y - FOOT_H, size.x - SIDE_W, FOOT_H)
	_px.rect(foot, UiKit.PANEL)
	var base := foot.position + Vector2(12.0, 20.0)
	var where := "%dx%d" % [maker.cols, maker.rows]
	var tone := UiKit.DIM
	if _sizing != Vector2i.ZERO:
		# What the map is coming to, while an edge is dragged.
		where = "%dx%d" % [_sized_to.size.x, _sized_to.size.y]
		tone = UiKit.ACCENT
	elif maker.holds(_hover):
		where = "%d,%d   %s" % [_hover.x, _hover.y, where]
	var right := foot.end.x - 12.0 - PixelDraw.text_width(where)
	_px.text(Vector2(right, base.y), where, tone)
	if maker.unsaved:
		var unsaved := Loc.t("hud.maker.unsaved")
		right -= PixelDraw.text_width(unsaved) + 16.0
		_px.text(Vector2(right, base.y), unsaved, UiKit.WARN)
	var room := right - base.x - 16.0
	if _said_left > 0.0:
		_px.text(base, _said, _said_tone, room)
	elif _sizing != Vector2i.ZERO or _edge_hover != Vector2i.ZERO:
		_px.text(base, Loc.t("hud.maker.edge"), UiKit.TEXT, room)
	elif _over_tile != "":
		_px.text(base, name_of(_over_tile), UiKit.TEXT, room)
	else:
		_px.text(base, Loc.t("hud.maker.hint_touch" if _thumb else "hud.maker.hint"), UiKit.DIM, room)
