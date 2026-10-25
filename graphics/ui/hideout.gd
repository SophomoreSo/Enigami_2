class_name Hideout
extends Control

## Between raids. Pick the weapons you will carry — up to three, and the one
## the rack is left on is the one in hand — build on their graphs, spend loot
## on the facilities, and deploy.
##
## Built in UiKit's pixel look, like the title and the assembly screen: every
## piece of text is Silkscreen at a multiple of its native 8px and every box is
## square and unsmoothed.
##
## The pixel face runs up to twice as wide as the one it replaced, which this
## screen — three columns of dense text — has no room for: a line that ran past
## its column wraps inside it rather than widening it.
##
## Nothing here explains itself. There was a status line along the bottom that
## said what the mouse was on — a facility's effect, why a board would not fit,
## what a purchase cost — and it was taken out by hand: a panel is its rows and
## the way out of them, and nothing else.
##
## As a station's panel in mobile mode (`UiKit.mobile`) the same rows are built
## for a thumb: the words at THUMB_TEXT, and everything to press THUMB tall —
## which the kit's buttons already are there. The room builds the panel again
## when the mode is thrown under it (`HideoutWorldView`).

signal deploy_requested(weapon: String)
signal title_requested()
## The graph on the weapon the rack is on was asked for.
signal edit_requested()
## The rack was left on a different weapon: picked, or the hand moved on to it
## because the one it was on was put back. On the whole screen nobody needs to
## know — the columns beside it are rebuilt with it — but as a station's panel
## the room outside it is what carries the choice to the gate.
signal weapon_changed(weapon: String)

## Wide enough for the longest line each column cannot wrap: a weapon's name on
## a button, and a stash row's part with a count beside it.
const COL_WEAPONS := 320.0
const COL_FACILITIES := 348.0
## The least a weapon's plate is across on the rack in mobile mode, where they
## stand RACK_COLUMNS to a row: wide enough for the longest name (SHURIKEN, in
## English), so every plate is as wide as every other and they share out the
## row between them.
const RACK_PLATE := 240.0
## How many plates stand in a row of the rack in mobile mode: six weapons are
## two rows of three, as six names are wider than a phone's page.
const RACK_COLUMNS := 3

var weapon_id: String = ""
## Which of the two columns this screen is. "" builds both under a header and
## a deploy footer — the screen the hideout used to be, kept for anything that
## still wants it whole. Set to "weapons" or "shop" and it builds that column
## alone, which is how the hideout's stations open them: the room is the header
## and the gate is the footer now.
var section: String = ""
var _root: VBoxContainer

func _ready() -> void:
	# Whole, this is the screen and owns the viewport. As one section it is the
	# contents of somebody else's panel: no screen-filling, no ground of its own
	# and no resizing itself every frame, or it would lay its column out against
	# the viewport while sitting in a box a third of the size.
	if section == "":
		UiKit.fill_screen(self)
		var bg := ColorRect.new()
		bg.color = UiKit.BG
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(bg)
	# Off, and not merely un-asked-for: a script with a `_process` is processing
	# from the moment it enters the tree, so leaving it alone left `sync_screen`
	# stretching a panel's column back out to the whole viewport every frame,
	# with its buttons a screen and a half off to the right.
	set_process(section == "")
	# In a page for a thumb, a press that lands between the rows is the page's:
	# it is what the list is dragged by.
	if section != "" and UiKit.mobile():
		UiKit.pass_presses(self)
	Loc.language_changed.connect(_relanguage)
	if weapon_id == "" or not GameState.owned_weapons.has(weapon_id):
		weapon_id = GameState.owned_weapons[0] if GameState.owned_weapons.size() > 0 else "SWORD"
	rebuild()

func _process(_d: float) -> void:
	UiKit.sync_screen(self)

## Whole, this fills the viewport and its size is not up for discussion. As one
## section it is a block of rows inside somebody else's panel, and a plain
## Control reports no size at all — which let the column run straight out of the
## bottom of the frame it was put in, taking the way out with it.
func _get_minimum_size() -> Vector2:
	if section == "" or _root == null or not is_instance_valid(_root):
		return Vector2.ZERO
	return _root.get_combined_minimum_size()

## Every label here is written once in `rebuild`, so a change of language is
## the same rebuild a purchase or a slot change already asks for.
func _relanguage(_lang: String) -> void:
	rebuild()

func rebuild() -> void:
	if _root != null:
		_root.queue_free()
	_root = VBoxContainer.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if section == "":
		_root.offset_left = 28
		_root.offset_right = -28
		_root.offset_top = 20
		_root.offset_bottom = -20
	_root.add_theme_constant_override("separation", 10)
	add_child(_root)

	if section != "":
		_root.add_child(_section_column())
		update_minimum_size()
		return

	_root.add_child(_header())
	_root.add_child(UiKit.hline(true))

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 12)
	_root.add_child(cols)
	cols.add_child(_weapons_column())
	cols.add_child(_facilities_column())

	_root.add_child(_footer())

## The one column this screen was asked for, filling what it is given. On the
## whole screen a column is one of three side by side and keeps its own width;
## alone in a station's panel it takes the panel.
func _section_column() -> Control:
	var c: Control
	match section:
		"weapons": c = _weapons_column()
		_: c = _facilities_column()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.custom_minimum_size = Vector2(0, 0)
	return c

## --- the kit, in the pixel look ---------------------------------------------
## A station's panel in mobile mode writes its words at a thumb's size; the
## whole screen never does, having three columns of them to fit.
func _label(text: String, color: Color = UiKit.TEXT, font_size: int = UiKit.PIXEL_TEXT) -> Label:
	return UiKit.label(text, UiKit.text(font_size) if section != "" else font_size, color, true)

## A line that is allowed to run on: it wraps inside its column instead of
## pushing the column wider.
func _wrapped(text: String, color: Color = UiKit.DIM) -> Label:
	var l := _label(text, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _button(text: String, accent: Color = UiKit.ACCENT) -> Button:
	return UiKit.button(text, accent, true)

## A button carrying a name of any length: it takes the row and cuts the name
## short rather than pushing the buttons beside it off the panel.
func _row_button(text: String, accent: Color = UiKit.ACCENT) -> Button:
	var b := _button(text, accent)
	b.clip_text = true
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b

func _pad() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

## The box a long list sits in. On the whole screen, where three columns share
## one screen, it is a short window `window` tall with a bar of its own. In a
## station's panel the panel already scrolls, and a bar inside a bar is one too
## many: there the list runs its full length and the panel is what gives.
func _scrolled(list: Control, window: int) -> Control:
	if section != "":
		return list
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(0, window)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UiKit.pixel_scroll(sc)
	sc.add_child(list)
	return sc

func _header() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	h.add_child(UiKit.title(Loc.t("hideout.heading"), 22, true))
	h.add_child(_label(Loc.t("hideout.scrap", [GameState.scrap]), UiKit.WARN))
	var r: Dictionary = GameState.records
	h.add_child(_label(Loc.t("hideout.records", [
		r["raids"], r["escapes"], r["deaths"], r["kills"]]), UiKit.DIM))
	h.add_child(_pad())
	var tb := _button(Loc.t("hideout.title"))
	tb.pressed.connect(func() -> void: title_requested.emit())
	h.add_child(tb)
	return h

## --- weapons ----------------------------------------------------------------
func _weapons_column() -> Control:
	var p := UiKit.panel(UiKit.PANEL, Color(0.22, 0.3, 0.38), true)
	p.custom_minimum_size = Vector2(COL_WEAPONS, 0)
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.add_child(_label(Loc.t("hideout.weapons.heading", [GameState.MAX_CARRIED]), UiKit.ACCENT))
	v.add_child(UiKit.hline(true))
	# One under another at a desk. For a thumb they stand side by side,
	# RACK_COLUMNS to a row: a plate THUMB tall for each, stacked, left no room
	# on a phone for what the rack says under them, and BUILD went off the bottom.
	var rack: Container = v
	if section != "" and UiKit.mobile():
		var grid := GridContainer.new()
		grid.columns = RACK_COLUMNS
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		rack = grid
		v.add_child(rack)
	# The kit, as the gate would carry it: a weapon in it wears the number of
	# its slot, which is the key that draws it in a raid.
	var kit := GameState.carried()
	for id in Weapons.ids():
		var owned: bool = GameState.owned_weapons.has(id)
		var selected: bool = id == weapon_id
		var wc := Style.weapon_color(id)
		var slot := kit.find(id)
		# Two characters either way, for the mark and for the slot, so the name
		# does not shift as either moves. Not on a plate, which is the name
		# alone: there the weapon in hand is the plate lit in its colour, the
		# rest of the kit is in theirs and what stays home is dimmed — and a
		# phone draws the next weapon with one key rather than a slot's number.
		# Five names with the mark and the number before them are wider than a
		# phone's page.
		var mark := ("> " if selected else "  ") + ("%d " % (slot + 1) if slot >= 0 else "  ")
		if rack != v:
			mark = ""
		var b := _button(Loc.t("hideout.weapons.row", [mark,
			Weapons.name_for(id), "" if owned else Loc.t("hideout.weapons.lost")]),
			wc if selected or slot >= 0 else UiKit.DIM)
		b.disabled = not owned
		b.custom_minimum_size = Vector2(0, maxf(40 if selected else 34, UiKit.thumb()))
		if rack != v:
			b.custom_minimum_size.x = RACK_PLATE
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if selected:
			b.add_theme_color_override("font_color", wc)
			b.add_theme_stylebox_override("normal", UiKit.style(
				Color(wc.r, wc.g, wc.b, 0.2), wc, 2, 3, true))
		# Picking a weapon takes it in hand, and into the kit with it: a free
		# slot, or the slot of the weapon the rack was on when there is none.
		b.pressed.connect(func() -> void:
			var was := weapon_id
			weapon_id = id
			GameState.carry(id, was)
			weapon_changed.emit(id)
			rebuild())
		rack.add_child(b)
	# What the weapon is, and nothing more. The numbers behind it — what it
	# multiplies, what it costs to die carrying it — were four more wrapped
	# blocks under this one, and are gone. A thumb's rack has a row's gap under
	# its plates already, and the page no room for another.
	if rack == v:
		v.add_child(UiKit.spacer(6))
	v.add_child(_wrapped(Weapons.desc_for(weapon_id)))
	# And the graph on it: what has been built onto the weapon's own part, and
	# the way onto the assembly board to build more. TAB opens the same board
	# from the floor.
	v.add_child(UiKit.spacer(6))
	var graph := HBoxContainer.new()
	graph.add_theme_constant_override("separation", 6)
	var used := GameState.weapon_board(weapon_id).used_components()
	var n := 0
	for id in used:
		n += int(used[id])
	var line := _label(Loc.t("hideout.weapons.graph", [Components.name_for(Weapons.root_part(weapon_id)), n]), UiKit.DIM)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.clip_text = true
	graph.add_child(line)
	# Back on the rack: out of the kit, and the hand goes to a weapon that is
	# still in it. Not the last one carried, which is what the gate needs.
	var leave := _button(Loc.t("hideout.weapons.leave"), UiKit.WARN)
	leave.disabled = not kit.has(weapon_id) or kit.size() < 2
	leave.pressed.connect(func() -> void:
		if GameState.leave_behind(weapon_id):
			weapon_id = GameState.carried()[0]
			weapon_changed.emit(weapon_id)
		rebuild())
	graph.add_child(leave)
	var build := _button(Loc.t("hideout.weapons.build"), UiKit.GOOD)
	build.disabled = not GameState.owned_weapons.has(weapon_id)
	build.pressed.connect(func() -> void: edit_requested.emit())
	graph.add_child(build)
	v.add_child(graph)
	return p

## --- facilities & stash -----------------------------------------------------
func _facilities_column() -> Control:
	var p := UiKit.panel(UiKit.PANEL, Color(0.22, 0.3, 0.38), true)
	p.custom_minimum_size = Vector2(COL_FACILITIES, 0)
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	p.add_child(v)
	v.add_child(_label(Loc.t("hideout.facilities.heading"), UiKit.ACCENT))
	v.add_child(UiKit.hline(true))
	for key in GameState.FACILITY_INFO:
		var info: Dictionary = GameState.FACILITY_INFO[key]
		var lvl: int = GameState.facilities[key]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var lbl := _label(Loc.t("hideout.facilities.row", [GameState.facility_name(key), lvl]))
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		if lvl >= int(info["max"]):
			row.add_child(_label(Loc.t("hideout.facilities.max"), UiKit.DIM))
		else:
			var b := _button("%d" % GameState.facility_cost(key), UiKit.WARN)
			b.disabled = not GameState.can_upgrade(key)
			b.pressed.connect(func() -> void:
				if GameState.upgrade_facility(key):
					Audio.play("pickup")
					rebuild())
			row.add_child(b)
		v.add_child(row)

	v.add_child(UiKit.spacer(8))
	v.add_child(_shop_shelf())
	v.add_child(UiKit.spacer(8))
	var sh := HBoxContainer.new()
	sh.add_child(_label(Loc.t("hideout.stash.heading"), UiKit.ACCENT))
	sh.add_child(_pad())
	# No arrow in the pixel face: three of them go in, one comes out.
	var fb := _button(Loc.t("hideout.stash.forge"), UiKit.WARN)
	fb.disabled = not GameState.can_forge()
	fb.pressed.connect(_forge)
	sh.add_child(fb)
	v.add_child(sh)
	v.add_child(UiKit.hline(true))

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	v.add_child(_scrolled(list, 104))
	var any := false
	for id in Components.loot_pool():
		var n := int(GameState.stash.get(id, 0))
		if n <= 0:
			continue
		any = true
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var l := _label(Loc.t("hideout.stash.row", [Components.name_for(id), n]), Style.component_color(id))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		row.add_child(l)
		var sc := _button(Loc.t("hideout.stash.scrap"), UiKit.DIM)
		sc.pressed.connect(func() -> void:
			if GameState.scrap_component(id) > 0:
				Audio.play("erase")
			rebuild())
		row.add_child(sc)
		list.add_child(row)
	if not any:
		list.add_child(_wrapped(Loc.t("hideout.stash.empty")))
	return p

## --- the merchant's shelf ---------------------------------------------------
## Parts for scrap, which the hideout had no way to buy: everything in it was
## either found in a raid or melted out of three things that were. A part you
## are one short of is now a thing you can go and get.
##
## Priced by `GameState`, never here — what a part is worth is a rule.
func _shop_shelf() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var head := HBoxContainer.new()
	head.add_child(_label(Loc.t("hideout.shop.heading"), UiKit.ACCENT))
	head.add_child(_pad())
	head.add_child(_label(Loc.t("hideout.scrap", [GameState.scrap]), UiKit.WARN))
	v.add_child(head)
	v.add_child(UiKit.hline(true))

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	v.add_child(_scrolled(list, 104))

	for id in GameState.shop_stock():
		var price: int = GameState.shop_price(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var l := _label(Components.name_for(id), Style.component_color(id))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		row.add_child(l)
		var b := _button(Loc.t("hideout.shop.price", [price]), UiKit.WARN)
		b.disabled = not GameState.can_buy(id)
		b.pressed.connect(func() -> void:
			Audio.play("pickup" if GameState.buy_component(id) else "deny")
			rebuild())
		row.add_child(b)
		list.add_child(row)
	return v

func _forge() -> void:
	# Spend the most plentiful spares first, so a unique part is never melted.
	var ids: Array = GameState.stash.keys()
	ids.sort_custom(func(a, b) -> bool:
		return int(GameState.stash[a]) > int(GameState.stash[b]))
	var pick: Array[String] = []
	for id in ids:
		var n := int(GameState.stash[id])
		for i in n:
			if pick.size() < GameState.FORGE_INPUTS:
				pick.append(String(id))
	if pick.size() < GameState.FORGE_INPUTS:
		return
	if GameState.forge_component(pick) != "":
		Audio.play("pickup")
	rebuild()

## --- deploy -----------------------------------------------------------------
func _footer() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.add_child(_pad())
	# The standing warning, unless there is something more pressing to say: a
	# kit still lying in a raid is what this deployment is for, and it is the
	# last thing read before the button that starts one.
	if GameState.has_lost_kit():
		h.add_child(_label(Loc.t("hideout.footer.kit_waiting",
			[GameState.lost_kit_size()]), UiKit.WARN))
	else:
		h.add_child(_label(Loc.t("hideout.footer.warning"), UiKit.BAD))
	var b := _button(Loc.t("hideout.footer.deploy"), UiKit.GOOD)
	b.custom_minimum_size = Vector2(180, 40)
	b.disabled = not GameState.owned_weapons.has(weapon_id)
	b.pressed.connect(func() -> void:
		deploy_requested.emit(weapon_id))
	h.add_child(b)
	return h
