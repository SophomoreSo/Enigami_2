class_name MonsterDex
extends Control

## The monster dictionary: the third page of the screen the weapons' graphs and
## the map are on (`ScreenTabs`), with its tab along the same top. Every monster
## a raid puts in front of the player has an entry (`Monsters.DEX`), numbered in
## that order down two columns of cards on the left: one not yet met is `??`,
## number and all but the number, and one met shows itself and its name.
##
## The entry picked is opened on the right: the monster standing, its number
## and name, what it is made of — health, pace, reach, what it is worth — and
## its skills. A skill is `??` until the monster has been seen using it, and
## one seen is shown as the graph it is (`BoardPicture`): the board the monster
## casts, drawn the way the assembly screen draws the player's, so what it does
## can be read off it and built — a part under the pointer saying what it is
## and does on a card, as there.
##
## What has been met and seen is the profile's (`GameState.bestiary`), written
## by a raid as it happens (`Raid._meet`).
##
## Drawn in UiKit's pixel look, like the pages beside it, over the same veil.

signal closed()
## A tab along the top was pressed, for a page other than this one.
signal page_picked(id: String)

var pages: Array = ScreenTabs.PAGES.duplicate()
## The entry open on the right, by its place in `Monsters.DEX`, and which of its
## skills is shown.
var picked: int = 0
var skill: int = 0

const PAD := 20.0
## A card down the left: two columns of them, CARD_GAP apart.
const CARD := Vector2(152, 120)
const CARD_GAP := 8.0
## The monster standing, on the right, and how far the words beside it stand.
const PORTRAIT := 168.0
const BG := Color(0.07, 0.08, 0.11, 0.97)
const EDGE := Color(0.35, 0.55, 0.75, 0.85)
const SLOT := Color(0.1, 0.11, 0.15)
const UNKNOWN := Color(0.32, 0.36, 0.44)

var _px := PixelDraw.new(self)
var _picture: BoardPicture
## Which board the picture has, as "KIND:skill", so it is built once a pick.
var _pictured := ""
var _t := 0.0
var _back_hot := false
var _page_hot := ""
var _card_hot := -1
var _skill_hot := -1

func _ready() -> void:
	UiKit.fill_screen(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_picture = BoardPicture.new()
	_picture.visible = false
	add_child(_picture)
	visibility_changed.connect(_on_shown)
	set_process(true)

## Opened on the first monster met, if the one open has not been.
func _on_shown() -> void:
	if not visible or GameState.knows_monster(_kind()):
		return
	for i in Monsters.DEX.size():
		if GameState.knows_monster(String(Monsters.DEX[i])):
			_pick(i)
			return

func _process(delta: float) -> void:
	UiKit.sync_screen(self)
	_t += delta
	_sync_picture()
	queue_redraw()

## Handled here rather than in `_gui_input` so the keys work whether or not the
## page holds focus. The other pages' keys put those pages up.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
	elif event.is_action_pressed("open_editor"):
		page_picked.emit(ScreenTabs.GRAPH)
	elif event.is_action_pressed("open_map"):
		page_picked.emit(ScreenTabs.MAP)
	else:
		return
	get_viewport().set_input_as_handled()

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
	var thumb := UiKit.mobile()
	var l := _layout()
	_back_hot = ScreenTabs.back_rect(thumb).has_point(pos)
	_page_hot = ScreenTabs.page_at(pages, pos, thumb)
	_card_hot = -1
	for i in Monsters.DEX.size():
		if card_rect(i).has_point(pos):
			_card_hot = i
	_skill_hot = -1
	var plates: Array = l["skills"]
	for i in plates.size():
		if (plates[i] as Rect2).has_point(pos):
			_skill_hot = i
	# The skill's graph, for the card a part under the pointer says itself on.
	_picture.point_at(pos)

## Lets go of what it lit before anything goes: it is not under the pointer
## any more by the time the screen comes back.
func _press() -> void:
	if _back_hot:
		_back_hot = false
		Audio.play("ui")
		closed.emit()
	elif _page_hot != "":
		var id := _page_hot
		_page_hot = ""
		if id != ScreenTabs.DEX:
			page_picked.emit(id)
	elif _card_hot >= 0:
		_pick(_card_hot)
		Audio.play("ui")
	elif _skill_hot >= 0:
		skill = _skill_hot
		Audio.play("ui")

## Opens entry `i` on the right, on its first skill.
func _pick(i: int) -> void:
	picked = clampi(i, 0, Monsters.DEX.size() - 1)
	skill = 0

func _kind() -> String:
	return String(Monsters.DEX[clampi(picked, 0, Monsters.DEX.size() - 1)])

## The picture is there while the skill open is one that has been seen.
func _sync_picture() -> void:
	var kind := _kind()
	var keys := Monsters.skills_of(kind)
	skill = clampi(skill, 0, maxi(keys.size() - 1, 0))
	var seen := not keys.is_empty() and GameState.knows_skill(kind, String(keys[skill]))
	_picture.visible = seen
	if not seen:
		return
	var key := "%s:%s" % [kind, keys[skill]]
	if key != _pictured:
		_pictured = key
		_picture.show_board(Monsters.build_board(kind, String(keys[skill])))
	_picture.fit = _layout()["graph"]

## --- where everything stands --------------------------------------------------

## The window, under the top; the cards' column, the entry's `detail`, its
## `portrait`, the `skills` plates and the `graph` the open skill is drawn in.
func _layout() -> Dictionary:
	var thumb := UiKit.mobile()
	var vp := get_viewport_rect().size
	var top := ScreenTabs.back_rect(thumb).end.y + 16.0
	var w := minf(vp.x - 32.0, 1120.0)
	var win := Rect2(_px.snap(Vector2((vp.x - w) * 0.5, top)), Vector2(w, vp.y - top - 16.0))
	var list := Vector2(win.position.x + PAD, win.position.y + 52.0)
	var x := list.x + CARD.x * 2.0 + CARD_GAP + 24.0
	var detail := Rect2(x, list.y, win.end.x - PAD - x, win.end.y - PAD - list.y)
	var portrait := Rect2(detail.position, Vector2(PORTRAIT, PORTRAIT))
	var tall := UiKit.THUMB if thumb else 30.0
	var row := portrait.end.y + 36.0
	var skills: Array = []
	var at := detail.position.x
	for key in Monsters.skills_of(_kind()):
		var r := Rect2(at, row, _skill_width(_kind(), String(key), thumb), tall)
		skills.append(r)
		at = r.end.x + 8.0
	var graph_top := row + tall + 12.0
	return {
		"win": win, "list": list, "detail": detail, "portrait": portrait,
		"skills": skills, "row": row,
		"graph": Rect2(detail.position.x, graph_top, detail.size.x, detail.end.y - graph_top),
	}

## Where the card for entry `i` stands: down two columns, in the dictionary's
## order across and then down.
func card_rect(i: int) -> Rect2:
	var list: Vector2 = _layout()["list"]
	@warning_ignore("integer_division")
	var r := i / 2
	return Rect2(list + Vector2(float(i % 2) * (CARD.x + CARD_GAP), float(r) * (CARD.y + CARD_GAP)), CARD)

## What a skill's plate says: its name once seen, `??` until then.
func skill_label(kind: String, key: String) -> String:
	return Loc.t("hud.dex.skill.%s" % key) if GameState.knows_skill(kind, key) else Loc.t("hud.dex.unknown")

func _skill_width(kind: String, key: String, thumb: bool) -> float:
	var label := skill_label(kind, key)
	var ink := PixelDraw.ink_width(label, Loc.text_size(label, UiKit.THUMB_TEXT)) if thumb \
		else PixelDraw.ink_width(label)
	return maxf(ScreenTabs.THUMB_TAB_W if thumb else ScreenTabs.TAB_W, ceilf((ink + 40.0) / PixelDraw.PX) * PixelDraw.PX)

## --- the drawing -----------------------------------------------------------------

func _draw() -> void:
	var l := _layout()
	var win: Rect2 = l["win"]
	_px.rect(Rect2(Vector2.ZERO, get_viewport_rect().size), ScreenTabs.VEIL)
	_px.rect(win, BG)
	_px.frame(win, EDGE)
	var base := win.position.y + PAD + 10.0
	_px.text(Vector2(win.position.x + PAD, base), Loc.t("hud.dex.title"), UiKit.TEXT)
	var met := 0
	for kind in Monsters.DEX:
		if GameState.knows_monster(String(kind)):
			met += 1
	var found := Loc.t("hud.dex.found", [met, Monsters.DEX.size()])
	_px.text(Vector2(win.end.x - PAD - PixelDraw.ink_width(found), base), found, UiKit.DIM)
	for i in Monsters.DEX.size():
		_draw_card(i)
	_draw_entry(l)
	ScreenTabs.draw(_px, pages, ScreenTabs.DEX, _back_hot, _page_hot, UiKit.mobile())

## One card: its number, and the monster and its name once it has been met.
func _draw_card(i: int) -> void:
	var kind := String(Monsters.DEX[i])
	var r := card_rect(i)
	var known := GameState.knows_monster(kind)
	var open := i == picked
	var col := Style.monster_color(kind) if known else UNKNOWN
	_px.rect(r, Color(col.r, col.g, col.b, 0.22) if open else SLOT)
	_px.frame(r, col if open else (Color(1, 1, 1, 0.5) if i == _card_hot else Color(col.r, col.g, col.b, 0.45)))
	if open:
		_px.frame(r.grow(-PixelDraw.PX), col)
	_px.text(r.position + Vector2(10, 22), Loc.t("hud.dex.number", [i + 1]), UiKit.DIM)
	var name_at := Vector2(r.position.x + 8.0, r.end.y - 12.0)
	if not known:
		_unknown(r.get_center() + Vector2(0, -6), UNKNOWN)
		_px.text_centered(name_at, Loc.t("hud.dex.unknown"), UNKNOWN, r.size.x - 16.0)
		return
	_draw_monster(kind, Rect2(r.position + Vector2(8, 28), Vector2(r.size.x - 16.0, r.size.y - 60.0)))
	_px.text_centered(name_at, Monsters.name_for(kind).to_upper(), UiKit.TEXT, r.size.x - 16.0)

## The entry open on the right.
func _draw_entry(l: Dictionary) -> void:
	var kind := _kind()
	var known := GameState.knows_monster(kind)
	var portrait: Rect2 = l["portrait"]
	var col := Style.monster_color(kind) if known else UNKNOWN
	_px.rect(portrait, SLOT)
	_px.frame(portrait, Color(col.r, col.g, col.b, 0.6))
	var words := Vector2(portrait.end.x + 24.0, portrait.position.y)
	var width := (l["detail"] as Rect2).end.x - words.x
	_px.text(words + Vector2(0, 14), Loc.t("hud.dex.number", [picked + 1]), UiKit.DIM)
	var big := Loc.text_size(Monsters.name_for(kind), PixelDraw.SIZE * 2)
	if not known:
		_unknown(portrait.get_center(), UNKNOWN, 3)
		_px.text(words + Vector2(0, 52), Loc.t("hud.dex.unknown"), UNKNOWN, width, PixelDraw.SIZE * 2)
		_px.text(words + Vector2(0, 84), Loc.t("hud.dex.unmet"), UiKit.DIM, width)
	else:
		_draw_monster(kind, portrait.grow(-12.0))
		_px.text(words + Vector2(0, 52), Monsters.name_for(kind).to_upper(), UiKit.TEXT, width, big)
		var def := Monsters.get_def(kind)
		var lines := [
			Loc.t("hud.dex.stat.health", [int(def["hp"])]),
			Loc.t("hud.dex.stat.speed", [int(def["speed"])]),
			Loc.t("hud.dex.stat.reach", [int(def["attack_range"])]),
			Loc.t("hud.dex.stat.scrap", [int(def["scrap"])]),
		]
		if bool(def.get("boss", false)):
			lines.append(Loc.t("hud.dex.boss"))
		elif bool(def.get("elite", false)):
			lines.append(Loc.t("hud.dex.elite"))
		for i in lines.size():
			_px.text(words + Vector2(0, 84 + 20 * i), String(lines[i]), UiKit.DIM, width)

	# The skills: a plate each, the open one lit, and the graph of it under them
	# once it has been seen used — `??` until then.
	_px.text(Vector2(portrait.position.x, float(l["row"]) - 10.0), Loc.t("hud.dex.skills"), UiKit.TEXT)
	var keys := Monsters.skills_of(kind)
	var plates: Array = l["skills"]
	var thumb := UiKit.mobile()
	for i in plates.size():
		var r: Rect2 = plates[i]
		var label := skill_label(kind, String(keys[i]))
		if thumb:
			_px.plate(r, label, ScreenTabs.LIT, i == skill, i == skill or i == _skill_hot)
		elif i == skill:
			_px.rect(r, Color(ScreenTabs.LIT.r, ScreenTabs.LIT.g, ScreenTabs.LIT.b, 0.3))
			_px.frame(r, ScreenTabs.LIT)
			_px.frame(r.grow(-PixelDraw.PX), ScreenTabs.LIT)
			_px.text(r.position + Vector2((r.size.x - PixelDraw.ink_width(label)) * 0.5, (r.size.y + 10.0) * 0.5),
				label, Color.WHITE)
		else:
			_px.button(r, label, i == _skill_hot)
	var graph: Rect2 = l["graph"]
	if keys.is_empty() or GameState.knows_skill(kind, String(keys[skill])):
		return
	_px.rect(graph, SLOT)
	_px.frame(graph, Color(UNKNOWN, 0.6))
	_unknown(graph.get_center() + Vector2(0, -12), UNKNOWN, 3)
	_px.text_centered(Vector2(graph.position.x, graph.get_center().y + 40.0), Loc.t("hud.dex.unseen"),
		UiKit.DIM, graph.size.x)

## `??`, big, centred on `c`.
func _unknown(c: Vector2, col: Color, times: int = 2) -> void:
	var font_size := PixelDraw.SIZE * times
	var mark := Loc.t("hud.dex.unknown")
	_px.text(Vector2(c.x - PixelDraw.ink_width(mark, font_size) * 0.5, c.y + 5.0 * float(times)), mark, col, -1.0,
		font_size)

## The monster standing in `box`, at the biggest whole magnification that fits,
## going through its idle film.
func _draw_monster(kind: String, box: Rect2) -> void:
	var base := Style.monster_art(kind)
	var frames := Sprites.resolved_frames(base)
	if frames == null or not frames.has_animation("idle") or frames.get_frame_count("idle") == 0:
		return
	var n := frames.get_frame_count("idle")
	var tex := frames.get_frame_texture("idle", int(_t * 6.0) % n)
	if tex == null:
		return
	var art := Sprites.art_rect(base)
	if art.size.x <= 0.0 or art.size.y <= 0.0:
		art = Rect2(Vector2.ZERO, tex.get_size())
	var zoom := maxf(1.0, floorf(minf(box.size.x / art.size.x, box.size.y / art.size.y)))
	var drawn := art.size * zoom
	var at := _px.snap(box.position + (box.size - drawn) * 0.5)
	draw_texture_rect_region(tex, Rect2(at, drawn), art, Style.monster_tint(kind))
