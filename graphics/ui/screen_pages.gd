class_name ScreenPages
extends RefCounted

## The pages of the screen over a world with no map of its own — the bench,
## the hideout's workbench, a played map and the tests: the assembly board, the
## map's page, which says there is no map (`MapPanel`, with none to show), and
## the monster dictionary (`MonsterDex`). The MAP tab stands along the top there
## as it does in a raid, and the map's key puts its page up as it does there.
##
## One page is up at a time. Whether the screen is up at all is the world's
## `editing`, and which page is up is this: a tab, or another page's key, puts
## that page up in its place without the screen going anywhere. A raid's
## pages are the raid's own states instead (`Raid.set_reading_map`,
## `Raid.set_reading_dex`, `RaidView`), since there reading the map is a thing
## the raid knows about.
##
## The bench and the hideout's workbench have the perks for a page as well, a
## tab past these three, built by whoever holds the screen, since the picture
## does not name the perks' page. The bench hands its page in (`add`), and it
## comes and goes with the others. The workbench's is not one of these: the
## tab is on every page here, and a press on it is the holder's to answer
## (`app/game.gd`, which puts the perks up in the screen's place).

var editor: SkillEditor
var map: MapPanel
var dex: MonsterDex
## The page that is up, or the one the screen comes up on while it is away.
var page := ScreenTabs.GRAPH
## Pages handed in from outside (`add`), by tab.
var _added: Dictionary = {}
var _tabs: Array
var _close: Callable

## Builds the map's page and the dictionary beside `ed`, on the layer it is on,
## and puts the screen away through `close` from either as the board does from
## its own. `tabs` are the tabs along the top of all three.
func _init(ed: SkillEditor, close: Callable, tabs: Array = ScreenTabs.PAGES) -> void:
	editor = ed
	_tabs = tabs.duplicate()
	_close = close
	map = MapPanel.new()
	map.visible = false
	ed.get_parent().add_child(map)
	dex = MonsterDex.new()
	dex.visible = false
	ed.get_parent().add_child(dex)
	for p in [map, dex]:
		p.closed.connect(close)
		p.page_picked.connect(put)
	ed.page_picked.connect(put)
	for p in [ed, map, dex]:
		p.pages = tabs.duplicate()

## `p` as the page under tab `id`, one more of these: a Control with the same
## `pages`, `closed` and `page_picked` the others have, on the layer they are on.
func add(id: String, p: Control) -> void:
	_added[id] = p
	p.visible = false
	p.pages = _tabs.duplicate()
	p.closed.connect(_close)
	p.page_picked.connect(put)
	editor.get_parent().add_child(p)

## Puts `id`'s page up and the others away. A page that is not one of these is
## left to whoever holds the screen.
func put(id: String) -> void:
	if not ScreenTabs.PAGES.has(id) and not _added.has(id):
		return
	page = id
	editor.visible = id == ScreenTabs.GRAPH
	map.visible = id == ScreenTabs.MAP
	dex.visible = id == ScreenTabs.DEX
	for k in _added:
		(_added[k] as Control).visible = k == id
	if editor.visible:
		editor.grab_focus()

## All away, with the screen; it comes up on the graph's page next time,
## unless the map's key is what brings it up.
func away() -> void:
	editor.visible = false
	map.visible = false
	dex.visible = false
	for p in _added.values():
		(p as Control).visible = false
	page = ScreenTabs.GRAPH

## The pages besides the board, for whoever frees them along with it.
func others() -> Array:
	return [map, dex] + _added.values()
