extends Node
## The menus, and the tables they are read from.
##
## Every menu a screen shows is rows in the content database
## (`data/db/menus/`): its name, and its items in order, each opening a menu
## or naming an act of the screen's. A row naming an act the screen does not
## have, or opening a menu the screen has no page for, is a button that does
## nothing — and nothing says so unless something asks. This asks: every menu
## the title and the pause menu show, against the acts and pages each really
## has; that every menu in the table is one some screen shows; that the words
## come out in the language being played and fall back on the rows' English;
## and what the schema promises to refuse, tried against a scratch copy of it.
##
## No renderer needed: the screens are made to ask them their acts, and never
## put on the tree; nothing here draws. The refusals print an `SQL error` line
## each from the extension, which is the point of them, and the item nobody
## answers to prints the error `Menus.press` is there to print.

const SRC := "res://data/db"
const SCRATCH := "user://menus_test.db"
const GameScript := preload("res://app/game.gd")

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[MENUS] PASS ", what)
	else:
		fails += 1
		push_error("MENUS FAIL: " + what)

func _ready() -> void:
	# --- the tables -----------------------------------------------------------
	check(Db.available(), "the database opens (%s)" % Db.PATH)
	for table in ["menus", "menu_items"]:
		check(Db.has_table(table), "there is a table of %s" % table)
	check(Db.meta("schema_version") == str(Db.SCHEMA_VERSION),
		"the database is at the schema the code reads (file says %s, code says %d)"
			% [Db.meta("schema_version"), Db.SCHEMA_VERSION])
	var ids := Menus.ids()
	check(ids.has("title") and ids.has("pause"), "the title and PAUSED are menus (%s)" % str(ids))

	# --- every row against the screen that shows it ---------------------------
	var title := TitleScreen.new()
	var game: Node = GameScript.new()
	for menu in TitleScreen.MENUS:
		var found := Menus.problems(menu, title.acts_for(menu).keys(), TitleScreen.MENUS)
		check(found.is_empty(), "the title's %s menu reads clean%s"
			% [menu, "" if found.is_empty() else " — " + "; ".join(found)])
	for menu in GameScript.PAUSE_MENUS:
		var found := Menus.problems(menu, game._pause_acts(menu).keys(), GameScript.PAUSE_MENUS)
		check(found.is_empty(), "the pause menu's %s menu reads clean%s"
			% [menu, "" if found.is_empty() else " — " + "; ".join(found)])
	for id in ids:
		check(TitleScreen.MENUS.has(id) or GameScript.PAUSE_MENUS.has(id),
			"the %s menu is one some screen shows" % id)
	# The buttons the screens keep by name have to be there to keep.
	var title_ids := Menus.items("title").map(func(i: Dictionary) -> String: return String(i["id"]))
	check(title_ids.has("start") and title_ids.has("settings"),
		"the title has START and SETTINGS, which the screen hands the keyboard to (%s)" % str(title_ids))
	var pause_ids := Menus.items("pause").map(func(i: Dictionary) -> String: return String(i["id"]))
	check(pause_ids.has("title") and pause_ids.has("park") and pause_ids.has("abandon"),
		"PAUSED has the three ways to the title the shell shows and hides (%s)" % str(pause_ids))
	title.free()
	game.free()

	# --- read the way the screens read them -----------------------------------
	Loc.set_language(Loc.DEFAULT)
	var items := Menus.items("title")
	check(items.size() == 6 and String(items[0]["id"]) == "start" and String(items[0]["text"]) == "START"
			and String(items[0].get("opens", "")) == "save_slots",
		"the title's items come out in order, START first, and START leads to the save slots (%s)" % str(items))
	check(not items[1].has("opens") and not bool(items[1]["exit"]),
		"SANDBOX opens no menu and is no way out: an act of the screen's")
	check(String(items[2]["id"]) == "map_maker" and String(items[2]["text"]) == "MAP CREATOR"
			and not items[2].has("opens") and not bool(items[2]["exit"]),
		"and so is MAP CREATOR, under it (%s)" % str(items[2]))
	check(String(items[3]["id"]) == "story_maker" and String(items[3]["text"]) == "STORY MAKER"
			and not items[3].has("opens") and not bool(items[3]["exit"]),
		"and STORY MAKER, under that (%s)" % str(items[3]))
	check(Menus.name_for("settings") == "SETTINGS" and String(items[4]["text"]) == "SETTINGS",
		"an item with no text of its own says the name of the menu it opens (%s)" % str(items[4]))
	check(Menus.name_for("title") == "", "the title has no heading")
	check(Menus.name_for("nowhere") == "" and Menus.items("nowhere").is_empty()
			and Menus.text_for("title", "nowhere") == "" and not Menus.exists("nowhere"),
		"a menu that is not there is empty, not an error")
	var pause := Menus.items("pause")
	var exits: Array = pause.filter(func(i: Dictionary) -> bool: return bool(i["exit"]))
	var doors: Array = pause.filter(func(i: Dictionary) -> bool: return i.has("opens"))
	check(String(pause[0]["id"]) == "resume" and not bool(pause[0]["exit"])
			and exits.size() == 3 and doors.size() == 2,
		"PAUSED is BACK TO GAME on top, two doors, and three ways out at its foot")
	check(Menus.text_for("pause", "general") == Menus.name_for("general")
			and Menus.name_for("general") == "GENERAL SETTINGS"
			and Menus.text_for("settings", "general") == Menus.name_for("general"),
		"GENERAL SETTINGS is written once, as its own name, and both doors to it say it")
	check(Menus.problems("pause", ["resume", "title", "park", "abandon"], ["pause", "general", "controls"]).is_empty(),
		"the checker passes PAUSED with the acts and pages the shell has")
	check(Menus.problems("pause", ["resume"], ["pause", "general", "controls"]).size() == 3,
		"and names each act the screen lacks (%s)"
			% str(Menus.problems("pause", ["resume"], ["pause", "general", "controls"])))
	check(Menus.problems("pause", ["resume", "title", "park", "abandon"], ["pause"]).size() == 2,
		"and each door to a page the screen has not got")
	check(Menus.problems("nowhere", [], []).size() == 1, "and a menu that is not there")

	# --- what pressing does ---------------------------------------------------
	var opened: Array = []
	var acted: Array = []
	var open := func(menu: String) -> void: opened.append(menu)
	var acts := {"quit": func() -> void: acted.append("quit")}
	Menus.press("title", items[0], acts, open).call()
	Menus.press("title", items[5], acts, open).call()
	check(opened == ["save_slots"] and acted == ["quit"],
		"a door opens what it names, an act runs what the screen gave it (%s, %s)" % [str(opened), str(acted)])
	Menus.press("title", {"id": "nowhere"}, acts, open).call()
	check(opened.size() == 1 and acted.size() == 1,
		"and an item nobody answers to does nothing, and says so above")

	# --- in every language ----------------------------------------------------
	var was := Loc.language
	var spelled: Array = []
	for lang in Loc.languages():
		Loc.set_language(lang)
		var start := Menus.text_for("title", "start")
		var heading := Menus.name_for("general")
		check(start == Loc.t("menu.title.start") and heading == Loc.t("menu.general.heading"),
			"in %s a menu says what localization/ says (%s, %s)" % [lang, start, heading])
		check(Menus.text_for("title", "settings") == Loc.t("menu.settings.heading"),
			"and a door says the name of its page in %s (%s)" % [lang, Menus.text_for("title", "settings")])
		spelled.append(start)
	var unique: Array = []
	for line in spelled:
		if not unique.has(line):
			unique.append(line)
	check(unique.size() == spelled.size(), "each language spells START its own way (%s)" % str(spelled))
	Loc.set_language(was)
	var src := Menus.source("pause")
	check(String(src.get("name", "")) == "PAUSED" and (src["items"] as Array).size() == 6
			and (src["items"] as Array).any(func(it: Dictionary) -> bool:
				return it.get("id", "") == "general" and not it.has("text")),
		"the source is the rows as written: the English, and no text on a door")

	# --- what the schema refuses ----------------------------------------------
	var db = _scratch()
	if db == null:
		check(false, "a scratch copy of the schema can be made to try it against")
	else:
		var menu := "INSERT INTO menus (id, name) VALUES ('x', 'X')"
		var nameless := "INSERT INTO menus (id) VALUES ('y')"
		var door := "INSERT INTO menu_items (menu_id, id, position, opens) VALUES ('x', 'go', 0, 'x')"
		var out := "INSERT INTO menu_items (menu_id, id, position, text, exit) VALUES ('x', 'back', 1, 'BACK', 1)"
		check(_accepted(db, [menu, nameless, door, out]), "a sound menu is accepted (%s)" % db.error_message)
		check(not _accepted(db, [menu, "INSERT INTO menu_items (menu_id, id, position) VALUES ('x', 'mute', 0)"]),
			"an item with nothing to say and nowhere to go is refused")
		check(not _accepted(db, [menu, door.replace("0, 'x')", "0, 'z')")]), "a door to a menu that is not there is refused")
		check(not _accepted(db, [menu, nameless, door.replace("0, 'x')", "0, 'y')")]),
			"an item with no text of its own opening a menu with no name is refused")
		check(_accepted(db, [menu, nameless, door.replace("position, opens)", "position, text, opens)").replace("0, 'x')", "0, 'GO', 'y')")]),
			"but one with a word of its own may open it")
		check(not _accepted(db, [menu, out, out.replace("'back'", "'again'")]), "two items in one position are refused")
		check(not _accepted(db, [menu, out, out.replace("1, 'BACK'", "2, 'BACK'")]), "and two with one id")
		check(not _accepted(db, [menu.replace("'x'", "'X'")]), "a menu id that is not lower case is refused")
		check(not _accepted(db, [menu.replace("'X'", "''")]), "and a name with nothing in it")
		check(not _accepted(db, [menu, out.replace(", 1)", ", 2)")]), "exit is yes or no")
		check(not _accepted(db, [menu, out.replace("'BACK'", "''")]), "an item with an empty word is refused")
		db.close_db()
		DirAccess.remove_absolute(SCRATCH)

	print("[MENUS] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## A fresh database with the real schema in it, foreign keys on, or null.
func _scratch():
	if not ClassDB.class_exists("SQLite"):
		return null
	if FileAccess.file_exists(SCRATCH):
		DirAccess.remove_absolute(SCRATCH)
	var db = ClassDB.instantiate("SQLite")
	db.path = SCRATCH
	db.foreign_keys = true
	db.verbosity_level = 0
	if not db.open_db():
		push_error("MENUS: could not open %s: %s" % [SCRATCH, db.error_message])
		return null
	var schema := FileAccess.get_file_as_string(SRC.path_join("schema.sql"))
	if schema == "" or not db.query(schema):
		push_error("MENUS: the schema did not run: %s" % db.error_message)
		return null
	return db

## Whether `statements` go in and commit, the way build.sh commits them. What
## went in is taken out again afterwards, so every try starts from nothing.
func _accepted(db, statements: Array) -> bool:
	var ok: bool = db.query("BEGIN")
	for s in statements:
		ok = ok and db.query(s)
	ok = ok and db.query("COMMIT")
	if not ok:
		db.query("ROLLBACK")
		return false
	db.query("DELETE FROM menus")
	return true
