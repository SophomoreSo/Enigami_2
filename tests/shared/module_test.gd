extends Node
## Where each module may reach, read off the code itself: every class and
## autoload a script names, against the folder the script lives in.
##
## ARCHITECTURE.md's table, one row per module: the folders a module's scripts
## may name anything in, the shell's globals they may name besides, and the
## one-line exceptions the doc carries — pinned to the file that has each, so a
## second file doing the same fails. `app/` has no row: the shell is the one
## place allowed to know all of them.
##
## Three things the table cannot say, checked after it:
##   GONE     edges cut on purpose, by file, so a rewrite does not bring one back
##            without anybody noticing. Cutting an edge is a line here.
##   NEVER    what no rule — `feature/`, `story/rules/`, `circuit/`, `perks/rules/` —
##            may name: a picture, the console, checked by class as the table
##            does; and the engine's own drawing, sound and asset names, because
##            the doc's promise that no rule draws, names a colour, loads a sprite
##            or plays a sound is a promise about names the table cannot see.
##   counts   the edges between each pair of modules, printed and not judged, so
##            a review can see which way the wiring is going.
##
## Comments and strings are left out before looking, so a doc comment that
## mentions a class is not a dependency on it — except for the asset names,
## which live in strings and are looked for there. No renderer needed.

## What a module's scripts may name: anything defined in these folders, these
## names besides, and for a file in `except`, those names too.
const MAY := [
	{"module": "res://circuit/", "folders": ["res://circuit/"], "names": ["Loc"],
		"except": {"res://circuit/components.gd": ["Db"]},
		"what": "the circuit names nothing but itself and Loc — and components.gd the parts table, through Db"},
	{"module": "res://feature/", "folders": ["res://feature/", "res://circuit/"],
		"names": ["Loc", "Cues", "Pointer", "Db"],
		"except": {"res://feature/world/sandbox.gd": ["Npc"]},
		"what": "the rules name the circuit, Loc, Cues, the pointer and Db — and sandbox.gd its guest"},
	{"module": "res://story/rules/", "folders": ["res://story/rules/", "res://feature/"],
		"names": ["Loc", "Cues", "Db"],
		"what": "the telling's rules name the game's rules, Loc, Cues and Db"},
	{"module": "res://graphics/", "folders": ["res://graphics/", "res://feature/", "res://circuit/",
			"res://mobile/input/", "res://app/"],
		"except": {"res://graphics/views.gd": ["StoryViews"],
			"res://graphics/ui/controls_panel.gd": ["TouchLayoutEditor"],
			"res://graphics/views/hideout_world_view.gd": ["PerkPage"],
			"res://graphics/views/raid_view.gd": ["PerkScreen"],
			"res://graphics/views/sandbox_view.gd": ["PerkScreen"]},
		"what": "the picture reads the rules, the circuit, the console's input and the shell — views.gd hands off to StoryViews, controls_panel.gd opens TouchLayoutEditor, hideout_world_view.gd puts up PerkPage, raid_view.gd and sandbox_view.gd PerkScreen"},
	{"module": "res://story/view/", "folders": ["res://story/view/", "res://story/rules/",
			"res://graphics/", "res://feature/", "res://app/"],
		"what": "the telling's picture reads its rules, the picture, the game's rules and the shell"},
	{"module": "res://mobile/input/", "folders": ["res://mobile/input/", "res://app/"],
		"what": "the console's input names nothing but itself and the shell"},
	{"module": "res://mobile/view/", "folders": ["res://mobile/view/", "res://mobile/input/",
			"res://graphics/", "res://feature/", "res://app/"],
		"what": "the console's picture reads its input, the picture, the rules and the shell"},
	{"module": "res://perks/rules/", "folders": ["res://perks/rules/", "res://feature/"],
		"names": ["Loc", "Cues", "Db"],
		"what": "the perks' rules name the game's rules, Loc, Cues and Db"},
	{"module": "res://perks/view/", "folders": ["res://perks/view/", "res://perks/rules/",
			"res://graphics/", "res://feature/", "res://app/"],
		"what": "the perks' picture reads their rules, the picture, the game's rules and the shell"},
]

## Edges cut on purpose: file -> the names it no longer reaches for. A name
## here coming back is a failure, however permitted the direction.
const GONE := {
	"res://feature/world/raid.gd": ["Controls"],
	"res://circuit/board_code.gd": ["Loc"],
	"res://circuit/skill_board.gd": ["Loc"],
	"res://circuit/skill_runner.gd": ["Loc"],
	"res://app/game.gd": ["Npc", "Station"],
}

## What the rules never name: a picture, or anything that knows a finger.
const RULES := ["res://feature/", "res://story/rules/", "res://circuit/", "res://perks/rules/"]
const NEVER := ["res://graphics/", "res://story/view/", "res://mobile/", "res://perks/view/"]

## And of the engine's own: what would draw, colour, load a picture or make a
## sound. The physics nodes the rules stand on are not among these.
const ENGINE_NEVER := ["Color", "Label", "RichTextLabel", "Sprite2D", "AnimatedSprite2D",
	"CanvasLayer", "Control", "Camera2D", "AudioStreamPlayer", "AudioStreamPlayer2D",
	"AudioStream", "Texture2D", "ImageTexture", "Font", "FontFile", "Line2D", "Polygon2D",
	"ColorRect", "TextureRect", "AudioServer", "RenderingServer"]
const ENGINE_NEVER_WORDS := "(?<![\\w.])(?:queue_redraw|modulate|draw_[a-z_]+)(?![\\w])"
const ASSET_LITERAL := "\"[^\"]*\\.(?:png|ogg|wav|mp3|ttf|otf|tres|gdshader)\""
## A rule that names a file's kind because it writes the player's own files of
## that kind, and loads none of the game's: the phone keeps its photos as PNGs
## (ARCHITECTURE.md, the phone's row). Pinned to the file, as `except` is.
const ASSET_PARDON := ["res://feature/core/phone.gd"]

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[MODULE] PASS ", what)
	else:
		fails += 1
		push_error("MODULE FAIL: " + what)

func _ready() -> void:
	var defined := _defined()
	check(defined.size() > 40, "every class and autoload is found (%d of them)" % defined.size())
	var names := _named(defined)
	check(names.has("res://circuit/skill_runner.gd") and names.has("res://mobile/input/touch.gd"),
		"and every script is read (%d of them)" % names.size())

	# --- the table ---------------------------------------------------------------
	var unrowed: Array = []
	for path: String in names:
		if not path.begins_with("res://app/") and _row_for(path).is_empty():
			unrowed.append(path)
	check(unrowed.is_empty(), "every script outside the shell has a row (%s)" % ", ".join(unrowed))
	for rule in MAY:
		var strays: Array = []
		for path: String in names:
			if not path.begins_with(String(rule["module"])):
				continue
			var pardon: Array = (rule.get("except", {}) as Dictionary).get(path, [])
			for n: String in names[path]:
				if (rule.get("names", []) as Array).has(n) or pardon.has(n):
					continue
				var home := String(defined[n])
				var allowed := false
				for folder: String in rule["folders"]:
					allowed = allowed or home.begins_with(folder)
				if not allowed:
					strays.append("%s names %s" % [path.get_file(), n])
		check(strays.is_empty(), "%s (%s)" % [rule["what"], ", ".join(strays)])

	# --- what was cut stays cut ------------------------------------------------------
	var back: Array = []
	for path: String in GONE:
		for n: String in GONE[path]:
			if names.has(path) and (names[path] as Array).has(n):
				back.append("%s names %s again" % [path.get_file(), n])
	check(back.is_empty(), "no edge cut on purpose has come back (%s)" % ", ".join(back))

	# --- the rules draw nothing ----------------------------------------------------------
	var drawn: Array = []
	for path: String in names:
		if not _under(path, RULES):
			continue
		for n: String in names[path]:
			if _under(String(defined[n]), NEVER):
				drawn.append("%s names %s" % [path.get_file(), n])
	check(drawn.is_empty(),
		"no rule names a picture or the console (%s)" % ", ".join(drawn))
	var engine: Array = _engine_strays()
	check(engine.is_empty(),
		"no rule names the engine's drawing, sound or assets (%s)" % ", ".join(engine))

	# --- how the wiring is going -------------------------------------------------------
	var pairs := {}
	for path: String in names:
		var from := _module_of(path)
		for n: String in names[path]:
			var to := _module_of(String(defined[n]))
			if to != from:
				var key := "%s -> %s" % [from.trim_prefix("res://").trim_suffix("/"),
					to.trim_prefix("res://").trim_suffix("/")]
				pairs[key] = int(pairs.get(key, 0)) + 1
	var keys := pairs.keys()
	keys.sort()
	for key in keys:
		print("[MODULE] INFO %-28s %3d edges" % [key, pairs[key]])
	print("[MODULE] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

func _under(path: String, folders: Array) -> bool:
	for folder: String in folders:
		if path.begins_with(folder):
			return true
	return false

func _row_for(path: String) -> Dictionary:
	for rule in MAY:
		if path.begins_with(String(rule["module"])):
			return rule
	return {}

## The module a script belongs to: its top folder, except that `story/` and
## `mobile/` are two modules each, split the way the doc splits them.
func _module_of(path: String) -> String:
	for m in ["res://story/rules/", "res://story/view/", "res://mobile/input/", "res://mobile/view/"]:
		if path.begins_with(m):
			return m
	return "res://" + path.trim_prefix("res://").get_slice("/", 0) + "/"

## Every global name in the project, and the script it lives in: the classes,
## and the autoloads by the name they are reached through.
func _defined() -> Dictionary:
	var out := {}
	var named := RegEx.create_from_string("(?m)^class_name\\s+(\\w+)")
	for path in _scripts("res://"):
		var m := named.search(FileAccess.get_file_as_string(path))
		if m != null:
			out[m.get_string(1)] = path
	for prop in ProjectSettings.get_property_list():
		var key := String(prop["name"])
		if key.begins_with("autoload/"):
			out[key.trim_prefix("autoload/")] = String(ProjectSettings.get_setting(key)).trim_prefix("*")
	return out

## Every script outside `tests/`, and the global names it uses other than its
## own. A name counts only as a word of its own — not the tail of another, and
## not a member after a dot, which is how `UiKit.Switch` names `UiKit` alone.
func _named(defined: Dictionary) -> Dictionary:
	var word := RegEx.create_from_string("(?<![\\w.])[A-Z]\\w*")
	var out := {}
	for path in _scripts("res://"):
		var used := {}
		for line in FileAccess.get_file_as_string(path).split("\n"):
			for m in word.search_all(_code_of(line)):
				var n := m.get_string()
				if defined.has(n) and String(defined[n]) != path:
					used[n] = true
		out[path] = used.keys()
	return out

## The engine names a rule may not use, looked for the same way — and the asset
## names, which are strings, looked for in the strings a comment does not hide.
func _engine_strays() -> Array:
	var word := RegEx.create_from_string("(?<![\\w.])[A-Z]\\w*")
	var calls := RegEx.create_from_string(ENGINE_NEVER_WORDS)
	var asset := RegEx.create_from_string(ASSET_LITERAL)
	var out: Array = []
	for path in _scripts("res://"):
		if not _under(path, RULES):
			continue
		var seen := {}
		var at := 0
		for line in FileAccess.get_file_as_string(path).split("\n"):
			at += 1
			var code := _code_of(line)
			for m in word.search_all(code):
				if ENGINE_NEVER.has(m.get_string()):
					seen[m.get_string()] = at
			for m in calls.search_all(code):
				seen[m.get_string()] = at
			var kept := line.strip_edges()
			if not kept.begins_with("#") and not ASSET_PARDON.has(path):
				for m in asset.search_all(kept.get_slice("#", 0)):
					seen[m.get_string()] = at
		for n in seen:
			out.append("%s:%d names %s" % [path.get_file(), seen[n], n])
	return out

## A line with its strings and its comment taken out. Strings first, so a `#`
## inside one does not cut the line short; per line, so an apostrophe in a
## comment can never open a string that swallows the code under it.
static func _code_of(line: String) -> String:
	var quoted := RegEx.create_from_string("\"(?:\\\\.|[^\"\\\\])*\"|'(?:\\\\.|[^'\\\\])*'")
	return quoted.sub(line, "\"\"", true).get_slice("#", 0)

func _scripts(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for sub in DirAccess.get_directories_at(dir):
		if sub.begins_with(".") or (dir == "res://" and sub == "tests"):
			continue
		out.append_array(_scripts(dir.path_join(sub)))
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() == "gd":
			out.append(dir.path_join(file))
	return out
