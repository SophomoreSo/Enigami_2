class_name Menus
extends RefCounted

## The menus, read from the content database: the rows of `menus` and
## `menu_items` (see "A menu" in `data/db/README.md`). A menu is its name —
## the heading over it, and what a button opening it says — and its items in
## order, each one thing: the menu it opens, or an act of the screen that
## shows it, by the item's id.
##
## The screens keep only the acts, and lay the items out. `TitleScreen`
## builds its column (or its tiles) and the pages behind START and SETTINGS
## from here; the shell builds PAUSED and its pages. What an item looks like —
## its colour, the mark over a tile, how tall it stands — is the screen's,
## keyed by the item's id, the way a part's look is `Style`'s.
##
## Every word comes out in the language being played: the English in the rows
## is the fallback under `localization/<lang>/menu.json`, by id —
## `menu.<menu>.heading` for a name, `menu.<menu>.note` for the line under
## it, `menu.<menu>.<item>` for an item's text
## (`Loc.opt`). An item with no text of its own says the name of the menu it
## opens, so GENERAL SETTINGS is written once, as that menu's name, and every
## door to it says it.
##
## Nothing here falls back. A menu that is not in the table comes back with
## nothing on it, and an item naming an act the screen does not have is said
## loudly and left doing nothing; `problems` finds both, and
## `tests/graphics/menus_test` asks it about every menu each screen shows.

## Every menu in the table, by id.
static func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for r in Db.rows("SELECT id FROM menus ORDER BY id"):
		out.append(String(r["id"]))
	return out

## Whether there is a menu called `id`.
static func exists(id: String) -> bool:
	return not Db.records("menus", "id = ?", [id]).is_empty()

## A menu as the table has it: the `menus` row, with its `items` under it in
## the order they are shown, each a `menu_items` row — the English, before
## any translation is laid over it. Empty when there is no such menu.
## `loc_test` reads this to hold the English in the files to the English here.
static func source(id: String) -> Dictionary:
	var found := Db.records("menus", "id = ?", [id])
	if found.is_empty():
		return {}
	var def: Dictionary = found[0]
	def["items"] = Db.records("menu_items", "menu_id = ?", [id], "position")
	return def

## What `id` is called, in the language being played — the heading over it,
## and what an item opening it says — or "" for a menu with no name.
static func name_for(id: String) -> String:
	var name = Db.value("SELECT name FROM menus WHERE id = ?", [id])
	if name == null:
		return ""
	return Loc.opt("menu.%s.heading" % id, String(name))

## The line under `id`'s heading, in the language being played, or "" for a
## menu with none.
static func note_for(id: String) -> String:
	var note = Db.value("SELECT note FROM menus WHERE id = ?", [id])
	if note == null:
		return ""
	return Loc.opt("menu.%s.note" % id, String(note))

## The items on `id`, in order, each `{id, text, exit}` and, for one that
## leads to a menu, `opens` — `text` in the language being played, an item
## with none of its own saying the name of the menu it opens.
static func items(id: String) -> Array:
	var out: Array = []
	for r in Db.records("menu_items", "menu_id = ?", [id], "position"):
		var item := {"id": String(r["id"]), "exit": int(r.get("exit", 0)) == 1}
		if r.has("opens"):
			item["opens"] = String(r["opens"])
		item["text"] = _text(id, r)
		out.append(item)
	return out

## What one item says, or "" for one that is not there.
static func text_for(menu_id: String, item_id: String) -> String:
	for r in Db.records("menu_items", "menu_id = ? AND id = ?", [menu_id, item_id]):
		return _text(menu_id, r)
	return ""

## What pressing `item` does: `open` bound to the menu it opens, or the act
## `acts` holds under the item's id. An item with neither is a row the screen
## has no act for — said loudly, and the button does nothing, rather than a
## guess at what was meant.
static func press(menu_id: String, item: Dictionary, acts: Dictionary, open: Callable) -> Callable:
	if item.has("opens"):
		return open.bind(String(item["opens"]))
	var id := String(item.get("id", ""))
	if acts.has(id):
		return acts[id]
	push_error("Menus: nothing on this screen answers to '%s' on the %s menu — see data/db/menus/menus.sql" % [id, menu_id])
	return func() -> void: pass

## Mistakes in a menu that would otherwise show as a button that does
## nothing: a menu with nothing on it, an item that opens no menu and names no
## act in `acts`, and one that opens a menu not among `pages`, the menus the
## screen can show.
static func problems(menu_id: String, acts: Array, pages: Array) -> Array:
	var src := source(menu_id)
	if src.is_empty():
		return ["no menu called '%s' in %s" % [menu_id, Db.PATH]]
	var out: Array = []
	var rows: Array = src.get("items", [])
	if rows.is_empty():
		out.append("the %s menu has nothing on it" % menu_id)
	for r in rows:
		var id := String(r.get("id", ""))
		if r.has("opens"):
			if not pages.has(String(r["opens"])):
				out.append("'%s' on %s opens the %s menu, which this screen has no page for"
					% [id, menu_id, String(r["opens"])])
		elif not acts.has(id):
			out.append("'%s' on %s opens no menu, and this screen has no act called that"
				% [id, menu_id])
	return out

## An item's text as the screen shows it: its own, translated by its id, or
## the name of the menu it opens.
static func _text(menu_id: String, r: Dictionary) -> String:
	if r.has("text"):
		return Loc.opt("menu.%s.%s" % [menu_id, String(r["id"])], String(r["text"]))
	return name_for(String(r.get("opens", "")))
