class_name ScreenTabs
extends RefCounted

## The top of the screen the weapons' graphs, the map, the monster dictionary
## and the perks are pages of, laid out the way a browser's is: the back arrow
## in the corner, which puts the screen away, and beside it a tab a page —
## GRAPH, the assembly board, MAP, the floor plan, FOES, every monster met
## and the skills seen of it (`MonsterDex`), and PERKS, what the player buys for
## themselves (`PerkScreen`, in perks/view). A press on a tab puts its page up
## under the same top, and the page that is up has its tab lit. The keys are the
## same tabs: the one that opens assembly puts the graph up and the map's key
## the map, and either, pressed on its own page, puts the screen away. The
## dictionary and the perks have no key: each is a tab away from the others.
##
## Every page draws it, the same pixels in the same place, over the same veil
## (`SkillEditor`, `MapPanel`, `MonsterDex`, `PerkScreen`): going from one to
## another changes what is under the top and nothing in it. The first three
## tabs are on it wherever it comes up (`PAGES`). A raid has a floor plan for
## the map's page to show; the bench, the hideout's workbench and the rest have
## none, and the page says so (`ScreenPages`). PERKS is on it where the perks
## can be bought — a raid, the hideout's workbench and the bench
## (`PAGES_WITH_PERKS`) — last, so the others' tabs stand where they do
## everywhere else.
##
## Drawn in UiKit's pixel look, like the pages under it. At a desk the back
## arrow is a button like COPY and PASTE, in the board's corner, and the tabs
## are as tall; for a thumb they are plates THUMB_BTN tall, words at a thumb's
## size.

const GRAPH := "graph"
const MAP := "map"
const DEX := "dex"
const PERKS := "perks"
## The pages every screen has, in the order their tabs stand along the top.
const PAGES := [GRAPH, MAP, DEX]
## The pages of a screen the perks can be bought on, in the same order.
const PAGES_WITH_PERKS := [GRAPH, MAP, DEX, PERKS]

## What the screen lays over the world, whichever page is up: only a light
## veil, since a raid behind it goes on and has to stay readable.
const VEIL := Color(0.04, 0.05, 0.07, 0.62)

## The least a tab stands across, at a desk and for a thumb: a word wider than
## that widens its own. Tabs stand TAB_GAP apart.
const TAB_W := 92.0
const THUMB_TAB_W := 132.0
const TAB_GAP := 4.0

## What the back arrow and a tab are lit in: the colour of COPY and PASTE.
const LIT := Color(0.55, 0.9, 1.0)

## Where the back arrow stands: in the screen's top-left corner, where the
## board's own layout leaves it room (`SkillEditor.CORNER`).
static func back_rect(thumb: bool) -> Rect2:
	if thumb:
		return Rect2(Vector2.ONE * SkillEditor.THUMB_EDGE, Vector2.ONE * SkillEditor.THUMB_BTN)
	return Rect2(SkillEditor.CORNER, Vector2.ONE * SkillEditor.CLOSE_SIDE)

## Where the tabs of `pages` stand, in order along the top from the back arrow,
## as tall as it is.
static func tab_rects(pages: Array, thumb: bool) -> Array:
	var back := back_rect(thumb)
	var x := back.end.x + (12.0 if thumb else SkillEditor.BTN_GAP)
	var out: Array = []
	for id in pages:
		var w := _tab_width(String(id), thumb)
		out.append(Rect2(x, back.position.y, w, back.size.y))
		x += w + TAB_GAP
	return out

## How far along the top the back arrow and the tabs run.
static func end_x(pages: Array, thumb: bool) -> float:
	var rects := tab_rects(pages, thumb)
	return back_rect(thumb).end.x if rects.is_empty() else (rects.back() as Rect2).end.x

## The page whose tab is under `pos`, or "" for none.
static func page_at(pages: Array, pos: Vector2, thumb: bool) -> String:
	var rects := tab_rects(pages, thumb)
	for i in rects.size():
		if (rects[i] as Rect2).has_point(pos):
			return String(pages[i])
	return ""

## What a page's tab says.
static func title(id: String) -> String:
	return Loc.t("hud.tabs.%s" % id)

## A tab is its word with room either side of it, on the PIXEL grid.
static func _tab_width(id: String, thumb: bool) -> float:
	var label := title(id)
	if thumb:
		var ink := PixelDraw.ink_width(label, Loc.text_size(label, UiKit.THUMB_TEXT))
		return maxf(THUMB_TAB_W, ceilf((ink + 48.0) / PixelDraw.PX) * PixelDraw.PX)
	return maxf(TAB_W, ceilf((PixelDraw.ink_width(label) + 40.0) / PixelDraw.PX) * PixelDraw.PX)

## The top as it is drawn over `open`'s page: the back arrow, lit while
## `back_hot`, and the tabs — `open`'s lit and edged twice, as the page that is
## up, and `hover`'s edged as the one under the pointer.
static func draw(px: PixelDraw, pages: Array, open: String, back_hot: bool, hover: String,
		thumb: bool) -> void:
	var back := back_rect(thumb)
	var arrow := Loc.t("menu.pause.arrow")
	if thumb:
		px.plate(back, arrow, LIT, back_hot, true)
	else:
		px.button(back, arrow, back_hot)
	var rects := tab_rects(pages, thumb)
	for i in rects.size():
		var id := String(pages[i])
		_draw_tab(px, rects[i], title(id), id == open, id == hover, thumb)

static func _draw_tab(px: PixelDraw, r: Rect2, label: String, up: bool, hot: bool, thumb: bool) -> void:
	if up:
		px.rect(r, Color(LIT.r, LIT.g, LIT.b, 0.3))
		px.frame(r, LIT)
		px.frame(r.grow(-PixelDraw.PX), LIT)
	else:
		px.rect(r, Color(0.16, 0.3, 0.4, 0.9) if hot else Color(0.11, 0.13, 0.17, 0.9))
		var edge := LIT if hot else Color(0.32, 0.4, 0.5)
		px.frame(r, edge)
		# A thumb's plates all have two PIXELs of edge.
		if thumb:
			px.frame(r.grow(-PixelDraw.PX), edge)
	var ink := Color(1, 1, 1) if up else (Color(0.92, 0.98, 1.0) if hot else Color(0.7, 0.8, 0.9))
	if thumb:
		var font_size := Loc.text_size(label, UiKit.THUMB_TEXT)
		px.text(Vector2(r.position.x + (r.size.x - PixelDraw.ink_width(label, font_size)) * 0.5,
			r.position.y + (r.size.y + 20.0) * 0.5), label, ink, -1.0, font_size)
		return
	px.text(r.position + Vector2((r.size.x - PixelDraw.ink_width(label)) * 0.5, (r.size.y + 10.0) * 0.5),
		label, ink)
