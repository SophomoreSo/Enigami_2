extends Node
## Every language says everything, says it with the same placeholders in the
## same order, and can actually be drawn.
##
## The mistakes this is here to catch are all silent ones. A line nobody
## translated falls back to English and reads as a bug report from the wrong
## country. A `%s` and a `%d` swapped round prints a name where a number should
## be, or prints nothing at all. A key renamed in a screen and not in the files
## reads as its own name on screen. And a language whose letters no font on the
## machine carries draws as a column of empty boxes — which looks like the game
## is broken rather than like a font is missing.
##
## It also holds the two halves of the text together: what `localization/eng`
## says has to match the English left in the code and in `data/`, because that
## English is the fallback under it. If the two drift, a part added to
## `Components` would quietly ship with no translated name in any language and
## nothing would say so until somebody read the screen in Korean.
##
## No renderer needed: nothing here draws. Measuring a string and asking a font
## whether it has a letter both work headless.

const SRC_DIRS := ["res://app", "res://feature", "res://graphics", "res://perks"]

var fails := 0
var _was_language := ""

func check(ok: bool, what: String) -> void:
	if ok:
		print("[LOC] PASS ", what)
	else:
		fails += 1
		push_error("LOC FAIL: " + what)

func _ready() -> void:
	# The language is saved to `user://` the moment it is set, so a test that
	# walks through all of them has to put the machine back as it found it.
	_was_language = Loc.language

	_check_files()
	_check_coverage()
	_check_fallbacks()
	_check_conversations()
	_check_keys_exist()
	_check_nothing_hardcoded()
	_check_cues_carry_ids()
	_check_switching()
	_check_fonts()
	_check_pixel_face()
	_check_bubbles()

	Loc.set_language(_was_language)
	print("[LOC] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## --- the files --------------------------------------------------------------

func _check_files() -> void:
	for lang in Loc.languages():
		var dir := Loc.DIR.path_join(lang)
		check(DirAccess.dir_exists_absolute(dir), "%s has a folder" % lang)
		for kind in Loc.OVERLAY_DIRS:
			check(DirAccess.dir_exists_absolute(dir.path_join(kind)),
				"%s has a %s folder" % [lang, kind])
		for domain in Loc.DOMAINS:
			var path := dir.path_join(domain + ".json")
			check(FileAccess.file_exists(path), "%s has %s.json" % [lang, domain])
			if FileAccess.file_exists(path):
				var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
				check(parsed is Dictionary, "%s/%s.json is an object" % [lang, domain])

## --- the same keys, with the same placeholders ------------------------------

func _check_coverage() -> void:
	var base := _strings(Loc.DEFAULT)
	check(base.size() > 0, "%s says something at all (%d lines)" % [Loc.DEFAULT, base.size()])
	for lang in Loc.languages():
		if lang == Loc.DEFAULT:
			continue
		var them := _strings(lang)
		var missing: Array = []
		var extra: Array = []
		var shifted: Array = []
		for key in base:
			if not them.has(key):
				missing.append(key)
			elif _slots(String(base[key])) != _slots(String(them[key])):
				shifted.append(key)
		for key in them:
			if not base.has(key):
				extra.append(key)
		check(missing.is_empty(), "%s says every line %s does (missing: %s)"
			% [lang, Loc.DEFAULT, _first(missing)])
		check(extra.is_empty(), "%s says nothing %s does not (extra: %s)"
			% [lang, Loc.DEFAULT, _first(extra)])
		# `%` fills placeholders in order, so a translation may reword around
		# them but never reorder or retype them.
		check(shifted.is_empty(),
			"%s fills the same placeholders in the same order (wrong: %s)"
			% [lang, _first(shifted)])
		for key in base:
			if them.has(key):
				check_blank(lang, key, String(them[key]))

func check_blank(lang: String, key: String, line: String) -> void:
	if line.strip_edges() == "":
		fails += 1
		push_error("LOC FAIL: %s leaves %s blank" % [lang, key])

## The conversion specifiers in a line, in order: "%s x%d" -> ["%s", "%d"].
## `%%` is a literal per cent and takes no value, so it is left out.
func _slots(line: String) -> Array:
	var out: Array = []
	var re := RegEx.create_from_string("%[-+ #0]*[0-9]*(?:\\.[0-9]+)?[a-zA-Z%]")
	for m in re.search_all(line):
		if m.get_string() != "%%":
			out.append(m.get_string())
	return out

## --- what the code still carries --------------------------------------------

## The English in the parts table, `Weapons.DEFS` and their like is the
## fallback under `localization/eng`. Two homes for one sentence only stays safe while
## something compares them, and this is that something: add a part, and the
## line below is what tells you its name has nowhere to be translated yet.
func _check_fallbacks() -> void:
	var eng := _strings(Loc.DEFAULT)
	var checked := 0
	for id in Components.ids():
		checked += _same(eng, "parts.%s.name" % id, String(Components.get_def(id)["name"]))
		checked += _same(eng, "parts.%s.desc" % id, String(Components.get_def(id)["desc"]))
	for id in Weapons.DEFS:
		checked += _same(eng, "weapons.%s.name" % id, String(Weapons.DEFS[id]["name"]))
		checked += _same(eng, "weapons.%s.desc" % id, String(Weapons.DEFS[id]["desc"]))
	checked += _same(eng, "weapons.%s.name" % Weapons.HAND, String(Weapons.HAND_DEF["name"]))
	checked += _same(eng, "weapons.%s.desc" % Weapons.HAND, String(Weapons.HAND_DEF["desc"]))
	for id in Monsters.DEFS:
		checked += _same(eng, "monsters.%s" % id, String(Monsters.DEFS[id]["name"]))
	for id in Perks.ids():
		checked += _same(eng, "perks.%s.name" % id, String(Perks.get_def(id)["name"]))
		checked += _same(eng, "perks.%s.desc" % id, String(Perks.get_def(id)["desc"]))
	# A facility has a name and nothing else to say: what each one does used to
	# be written on the counter's status line, and went out with it.
	for key in GameState.FACILITY_INFO:
		var info: Dictionary = GameState.FACILITY_INFO[key]
		checked += _same(eng, "hideout.facilities.info.%s.name" % key, String(info["name"]))
	for entry in Controls.ACTIONS:
		checked += _same(eng, "controls.action.%s" % String(entry[0]), String(entry[1]))
	for id in RaidMap.EXIT_NAMES:
		checked += _same(eng, "hud.exit.%s" % id, String(RaidMap.EXIT_NAMES[id]))
	for i in Components.DIR_NAME.size():
		checked += _same(eng, "parts.direction.%s" % Components.DIR_NAME[i],
			String(Components.DIR_NAME[i]))
	# A menu's name and what its items say, the same way: the rows are the
	# fallback, by id. An item with no text of its own says the name of the
	# menu it opens, and has no line to hold.
	for id in Menus.ids():
		var menu := Menus.source(id)
		if menu.has("name"):
			checked += _same(eng, "menu.%s.heading" % id, String(menu["name"]))
		if menu.has("note"):
			checked += _same(eng, "menu.%s.note" % id, String(menu["note"]))
		for item in menu.get("items", []):
			if item.has("text"):
				checked += _same(eng, "menu.%s.%s" % [id, String(item["id"])], String(item["text"]))
	print("[LOC] %d lines checked against the English left in the code" % checked)

func _same(eng: Dictionary, key: String, in_code: String) -> int:
	if not eng.has(key):
		fails += 1
		push_error("LOC FAIL: nothing in %s answers to '%s' (the code says %s)"
			% [Loc.DEFAULT, key, in_code.left(40)])
	elif String(eng[key]) != in_code:
		fails += 1
		push_error("LOC FAIL: '%s' has drifted from the code\n   code: %s\n   %s: %s"
			% [key, in_code, Loc.DEFAULT, String(eng[key])])
	return 1

## --- conversations and scenes ----------------------------------------------

## The same rule one level down: the words in `data/` are the fallback, so the
## default language must repeat them exactly and every other language must
## cover the same lines. A beat inserted into a scene shifts every translation
## under it, and this is what turns that into a failure rather than a scene
## that says the wrong things.
func _check_conversations() -> void:
	for id in Dialogue.ids():
		var src := Dialogue.source(id)
		var nodes: Dictionary = src.get("nodes", {})
		for lang in Loc.languages():
			var over := _read(Loc.DIR.path_join(lang).path_join("dialogue/%s.json" % id.to_lower()))
			check(not over.is_empty(), "%s has words for %s" % [lang, id])
			var lines: Dictionary = over.get("nodes", {})
			for key in nodes:
				var node: Dictionary = nodes[key]
				if not lines.has(key):
					fails += 1
					push_error("LOC FAIL: %s never says %s's '%s'" % [lang, id, key])
					continue
				var line: Dictionary = lines[key]
				check(String(line.get("text", "")) != "",
					"%s gives %s's '%s' something to say" % [lang, id, key])
				var answers: Array = line.get("choices", [])
				var choices: Array = node.get("choices", [])
				check(answers.size() == choices.size(),
					"%s gives %s's '%s' all %d answers (%d)"
						% [lang, id, key, choices.size(), answers.size()])
				if lang == Loc.DEFAULT:
					_same_text(lang, "%s/%s" % [id, key], String(node.get("text", "")),
						String(line.get("text", "")))
			for key in lines:
				check(nodes.has(key), "every line %s translates for %s is one %s has ('%s')"
					% [lang, id, id, key])
			# What they say free, rule by rule, the same way.
			var rules: Dictionary = src.get("rules", {})
			var said: Dictionary = over.get("rules", {})
			for key in rules:
				if not said.has(key):
					fails += 1
					push_error("LOC FAIL: %s never says %s's rule '%s'" % [lang, id, key])
					continue
				var rule_line: Dictionary = said[key]
				check(String(rule_line.get("text", "")) != "",
					"%s gives %s's rule '%s' something to say" % [lang, id, key])
				if lang == Loc.DEFAULT:
					_same_text(lang, "%s/%s" % [id, key], String((rules[key] as Dictionary).get("text", "")),
						String(rule_line.get("text", "")))
			for key in said:
				check(rules.has(key), "every rule %s translates for %s is one %s has ('%s')"
					% [lang, id, id, key])

	for id in CutsceneScript.ids():
		var src := _read(CutsceneScript.path_for(id))
		var beats: Array = src.get("beats", [])
		for lang in Loc.languages():
			var over := _read(Loc.DIR.path_join(lang).path_join("scenes/%s.json" % id.to_lower()))
			check(not over.is_empty(), "%s has words for the %s scene" % [lang, id])
			var lines: Dictionary = over.get("beats", {})
			for i in beats.size():
				var beat: Dictionary = beats[i]
				var spoken := String(beat.get("text", "")) != ""
				var said := lines.has(str(i))
				check(spoken == said,
					"%s covers beat %d of %s exactly when the scene speaks there" % [lang, i, id])
				if spoken and said and lang == Loc.DEFAULT:
					_same_text(lang, "%s beat %d" % [id, i], String(beat["text"]),
						String((lines[str(i)] as Dictionary).get("text", "")))
			for key in lines:
				check(key.is_valid_int() and int(key) < beats.size(),
					"every beat %s translates for %s is one the scene has ('%s')"
						% [lang, id, key])

func _same_text(lang: String, where: String, in_data: String, in_loc: String) -> void:
	if in_data != in_loc:
		fails += 1
		push_error("LOC FAIL: %s has drifted from data/ at %s\n   data: %s\n   %s: %s"
			% [lang, where, in_data.left(60), lang, in_loc.left(60)])

## --- the keys the screens actually ask for ----------------------------------

## Every `Loc.t("…")` written out in full, across both modules and the shell.
## A key renamed in one place and not the other reads as its own name on
## screen, which is the sort of thing that ships.
func _check_keys_exist() -> void:
	var re := RegEx.create_from_string('Loc\\.(?:t|opt|has)\\("([a-z0-9_.]+)"')
	var asked: Dictionary = {}
	for path in _scripts():
		var src := FileAccess.get_file_as_string(path)
		for m in re.search_all(src):
			var key := m.get_string(1)
			if not asked.has(key):
				asked[key] = path
	check(asked.size() > 0, "the screens ask for lines by name (%d of them)" % asked.size())
	var unknown: Array = []
	for key in asked:
		if not Loc.has(key):
			unknown.append("%s (%s)" % [key, String(asked[key]).get_file()])
	check(unknown.is_empty(), "every line a screen asks for exists (missing: %s)" % _first(unknown))
	# A share code's refusal is an id the circuit returns and the editor spells as
	# `editor.code_error.<id>`, which the scan above cannot see; so every id the
	# decoder can return is asked for here by name.
	var unspelled: Array = []
	for id in BoardCode.REFUSALS:
		if not Loc.has("editor.code_error.%s" % id):
			unspelled.append(String(id))
	check(unspelled.is_empty(),
		"every refusal a share code can meet has a line (missing: %s)" % _first(unspelled))

## A sentence written into a screen instead of into `localization/` does not
## fail anywhere: it simply stays in English in every language, and the only
## way anybody finds out is by reading a Korean screen and seeing a line of
## English on it. These are the calls that carry a line to the player, so a
## quoted string opening one of them is always a line that was missed.
const MESSAGE_SINKS := ["_notify", "_say", "note",
	"_share.note", "_banner =", "prompt =", "txt =",
	"_message =", "hint ="]

## The same, for the calls that draw a line somewhere rather than hand it to a
## screen. They all take the place first, so what is looked for is a quoted
## line further along the call — one that starts with a letter and has a space
## in it, which a format like `"%02d:%02d"` or a mark like `"> "` does not.
const DRAW_SINKS := ["_px.text", "_px.text_centered", "_line", "_text", "_neon",
	"PixelCamera.draw_text"]

func _check_nothing_hardcoded() -> void:
	var found: Array = []
	for path in _scripts():
		var src := FileAccess.get_file_as_string(path)
		for sink in MESSAGE_SINKS:
			# A call needs its bracket, or `l["note"]` reads as one; an
			# assignment has its `=` in the name above. Either way the quoted
			# part has to hold two letters to be a line at all — `_message = ""`
			# is a line being cleared, not one being written.
			var word := "[^\"\n]*[A-Za-z][^\"\n]*[A-Za-z]"
			var tail := ("\\s*\"%s" % word) if sink.ends_with("=") \
				else ("\\s*\\(\\s*\"%s" % word)
			var re := RegEx.create_from_string(
				"(?<![A-Za-z0-9_])%s%s" % [sink.replace(".", "\\.").replace(" =", "\\s*="), tail])
			for m in re.search_all(src):
				# Where the line starts, so the report can be read back to a file.
				var upto := src.substr(0, m.get_start())
				found.append("%s:%d %s" % [String(path).get_file(),
					upto.count("\n") + 1, sink])
	for path in _scripts():
		var src := FileAccess.get_file_as_string(path)
		for sink in DRAW_SINKS:
			var re := RegEx.create_from_string(
				"(?<![A-Za-z0-9_])%s\\([^\n]*,\\s*\"[A-Za-z][^\"\n]*[ ][^\"\n]*\""
					% sink.replace(".", "\\."))
			for m in re.search_all(src):
				var upto := src.substr(0, m.get_start())
				found.append("%s:%d %s" % [String(path).get_file(),
					upto.count("\n") + 1, sink])
	check(found.is_empty(),
		"every line the game says to the player comes out of localization/ (written in: %s)"
			% _first(found))

## A cue carries ids, never a line. The picture spells them, in the language
## being played — so a rule that writes a line into a cue's dictionary, a boss
## announcing its second form in English, is drawn as it is in every language,
## and none of the sinks above sees it, because a Dictionary key is not a call.
func _check_cues_carry_ids() -> void:
	var re := RegEx.create_from_string("\"text\"\\s*:\\s*\"[^\"\\n]*[A-Za-z]")
	var found: Array = []
	for path in _scripts(["res://feature", "res://story/rules", "res://circuit", "res://perks/rules"]):
		var src := FileAccess.get_file_as_string(path)
		for m in re.search_all(src):
			var upto := src.substr(0, m.get_start())
			found.append("%s:%d" % [String(path).get_file(), upto.count("\n") + 1])
	check(found.is_empty(),
		"no rule writes a line into a cue; the picture spells the id (%s)" % _first(found))

func _scripts(dirs: Array = SRC_DIRS) -> Array:
	var out: Array = []
	var queue: Array = dirs.duplicate()
	while not queue.is_empty():
		var dir: String = queue.pop_front()
		for sub in DirAccess.get_directories_at(dir):
			queue.append(dir.path_join(sub))
		for file in DirAccess.get_files_at(dir):
			if file.get_extension() == "gd":
				out.append(dir.path_join(file))
	return out

## --- switching --------------------------------------------------------------

func _check_switching() -> void:
	var seen: Array = []
	var announced: Array = []
	Loc.language_changed.connect(func(l: String) -> void: announced.append(l))
	for lang in Loc.languages():
		Loc.set_language(lang)
		check(Loc.language == lang, "the game switches to %s" % lang)
		var line := Loc.t("menu.title.start")
		check(line != "menu.title.start", "and START has a word in %s" % lang)
		seen.append(line)
	# Switching to the language already in play is not a change, so the count is
	# one short of the walk above when it starts in the first language.
	check(announced.size() >= Loc.languages().size() - 1,
		"and announces every switch it actually makes (%d)" % announced.size())
	# Two languages that spell everything the same way would mean one of them is
	# silently reading the other's file.
	var unique: Array = []
	for line in seen:
		if not unique.has(line):
			unique.append(line)
	check(unique.size() == seen.size(), "each language spells START its own way (%s)" % str(seen))

## --- the face ---------------------------------------------------------------

## The check that catches a column of empty boxes. Every letter of every line a
## language carries has to be one the fonts the game draws with can actually
## draw — through the fallback chain `Loc` hangs off them, which is where
## Korean comes from, since neither bundled face has a single Hangul glyph.
func _check_fonts() -> void:
	for lang in Loc.languages():
		Loc.set_language(lang)
		for font in [UiKit.PIXEL_FONT, ThemeDB.fallback_font]:
			var missing := _undrawable(font as Font, _strings(lang))
			check(missing == "", "every letter %s uses has a glyph in %s%s"
				% [lang, _font_name(font as Font),
					"" if missing == "" else " — none for %s" % missing])
		# A line with no glyphs measures zero wide, which is the same thing said
		# in the units a layout cares about.
		var sample := Loc.t("menu.title.start")
		check(UiKit.PIXEL_FONT.get_string_size(sample, HORIZONTAL_ALIGNMENT_LEFT, -1,
			UiKit.PIXEL_TEXT).x > 0.0, "and START in %s measures wider than nothing" % lang)
		# The settings screen writes every language's name in its own script,
		# whichever one is being played — so the face that is loaded has to
		# spell all of them, not just the one it is for. A name it cannot spell
		# does not come out as empty boxes: `allow_system_fallback` quietly
		# substitutes one of the machine's own fonts, and one smooth line turns
		# up in the middle of a pixel menu.
		var names: Dictionary = {}
		for other in Loc.languages():
			names[other] = Loc.language_name(other)
		for font in [UiKit.PIXEL_FONT, ThemeDB.fallback_font]:
			var absent := _undrawable(font as Font, names)
			check(absent == "",
				"and while playing in %s, every language's own name draws in %s%s"
					% [lang, _font_name(font as Font),
						"" if absent == "" else " — none for %s" % absent])

## The first character of `lines` that `font` cannot draw, described, or "".
func _undrawable(font: Font, lines: Dictionary) -> String:
	for key in lines:
		var line := String(lines[key])
		for i in line.length():
			var c := line.unicode_at(i)
			# Spaces and the control characters below them are never in a font.
			if c <= 32:
				continue
			if not font.has_char(c):
				return "'%s' (U+%04X, in %s)" % [char(c), c, key]
	return ""

func _font_name(font: Font) -> String:
	var n := font.get_font_name()
	return n if n != "" else "the fallback font"

## --- whole pixels -----------------------------------------------------------

## A language with a face of its own has to be drawn in it, and drawn on whole
## pixels. These are the three ways that quietly stops being true — the face
## goes missing and the machine's own fonts stand in; the import is changed and
## FreeType starts smoothing it; a size is used that its grid does not divide —
## and none of them show up as an error, only as text that has gone soft.
func _check_pixel_face() -> void:
	for lang in Loc.languages():
		Loc.set_language(lang)
		check(not Loc.borrows_glyphs(),
			"%s is drawn in a face the game ships, not in whatever the machine has" % lang)
		var path := Loc.font_path()
		if path == "":
			print("[LOC] %s needs no face of its own — the bundled Latin ones carry it" % lang)
		else:
			var face := load(path) as FontFile
			check(face != null, "%s's own face loads (%s)" % [lang, path.get_file()])
			if face != null:
				check(face.antialiasing == TextServer.FONT_ANTIALIASING_NONE,
					"and is imported with no antialiasing (%d)" % face.antialiasing)
				check(face.subpixel_positioning == TextServer.SUBPIXEL_POSITIONING_DISABLED,
					"and no subpixel positioning (%d)" % face.subpixel_positioning)
				check(face.hinting == TextServer.HINTING_NONE,
					"and no hinting (%d)" % face.hinting)
		# Every line, measured in the face the screens actually draw with — a
		# language's own face is reached through the fallback chain hung off it.
		var ragged: Array = []
		var lines := _strings(lang)
		for key in lines:
			var w: float = UiKit.PIXEL_FONT.get_string_size(String(lines[key]),
				HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.PIXEL_TEXT).x
			if w != floorf(w):
				ragged.append("%s (%.2fpx)" % [key, w])
		check(ragged.is_empty(),
			"%s measures to whole pixels at %dpx (ragged: %s)"
				% [lang, UiKit.PIXEL_TEXT, _first(ragged)])
		# Every size the pixel look asks for, put through the snap. A language
		# with a face of its own has to come back at a whole multiple of it:
		# 둥근모꼴 at 24px is a face and a half, and hands back some strokes a
		# pixel wider than others.
		if Loc.font_path() != "":
			var off: Array = []
			for want in [8, 12, UiKit.PIXEL_TEXT, 22, 24, 32]:
				var got := Loc.pixel_size(want)
				if got % Loc.face_size() != 0 or got < Loc.face_size():
					off.append("%d -> %d" % [want, got])
			check(off.is_empty(), "%s snaps every size to its %dpx face (off: %s)"
				% [lang, Loc.face_size(), _first(off)])
			# And a line the Latin faces can spell keeps the size it asked for,
			# so a damage number does not double because the menus did.
			check(Loc.text_size("123", 8) == 8,
				"and a line Silkscreen can spell keeps its own size in %s (%d)"
					% [lang, Loc.text_size("123", 8)])
			check(Loc.text_size(Loc.t("hud.exit.sign"), 8) == Loc.pixel_size(8),
				"while one it cannot goes to the face's own (%d)"
					% Loc.text_size(Loc.t("hud.exit.sign"), 8))
		# The screens that draw at a size written into them rather than asking
		# for one. They can, because PIXEL_TEXT is a whole multiple of every
		# face the game carries — which stops being true the moment a language
		# arrives whose face does not divide it, and nothing else would say so.
		var fixed := {
			"CutsceneBox.TEXT_SIZE": CutsceneBox.TEXT_SIZE,
			"CutsceneBox.NAME_SIZE": CutsceneBox.NAME_SIZE,
			"CutsceneBox.HINT_SIZE": CutsceneBox.HINT_SIZE,
			"DialogueBox.TEXT_SIZE": DialogueBox.TEXT_SIZE,
			"DialogueBox.NAME_SIZE": DialogueBox.NAME_SIZE,
			"DialogueBox.HINT_SIZE": DialogueBox.HINT_SIZE,
			"PixelDraw.SIZE": PixelDraw.SIZE,
			"UiKit.PIXEL_TEXT": UiKit.PIXEL_TEXT,
		}
		var unfit: Array = []
		for name in fixed:
			if int(fixed[name]) % Loc.face_size() != 0:
				unfit.append("%s=%d" % [name, int(fixed[name])])
		check(unfit.is_empty(), "%s's %dpx face divides every size written into a screen (off: %s)"
			% [lang, Loc.face_size(), _first(unfit)])
		print("[LOC] %s draws on a %d-pixel grid (UiKit.PIXEL is %d)"
			% [lang, UiKit.pixel_grid(), UiKit.PIXEL])

## --- free talk's bubbles ------------------------------------------------------

## A free line has to fit its bubble, in every language. The bubble grows to
## `MOST_ROWS` rows of `WIDTH` and then cuts the line short with an ellipsis —
## so a line that runs on is words nobody reads — and a translation is usually
## the one that runs on. Every letter has to be one the pixel face draws, too:
## these lines are not in the files `_check_fonts` reads.
func _check_bubbles() -> void:
	for lang in Loc.languages():
		Loc.set_language(lang)
		var long: Array = []
		var lines := {}
		for id in Dialogue.ids():
			var rules: Dictionary = Dialogue.character(id).get("rules", {})
			for key in rules:
				var text := String((rules[key] as Dictionary).get("text", ""))
				lines["%s/%s" % [id, key]] = text
				var rows := PixelDraw.wrap(text, SpeechBubble.WIDTH, 99)
				if rows.size() > SpeechBubble.MOST_ROWS:
					long.append("%s/%s (%d rows)" % [id, key, rows.size()])
		check(not lines.is_empty() and long.is_empty(),
			"every free line fits its bubble in %s (too long: %s)" % [lang, _first(long)])
		var missing := _undrawable(UiKit.PIXEL_FONT, lines)
		check(missing == "", "and every letter of them draws in the pixel face in %s%s"
			% [lang, "" if missing == "" else " — none for %s" % missing])

## --- reading ----------------------------------------------------------------

## One language's whole vocabulary, flattened the way `Loc` flattens it, read
## off disk rather than out of `Loc` — so this is checking the files, not
## checking the loader against itself.
func _strings(lang: String) -> Dictionary:
	var out: Dictionary = {}
	for domain in Loc.DOMAINS:
		_flatten(_read(Loc.DIR.path_join(lang).path_join(domain + ".json")), domain, out)
	return out

func _flatten(d: Dictionary, prefix: String, into: Dictionary) -> void:
	for k in d:
		var key := "%s.%s" % [prefix, k]
		var v = d[k]
		if v is Dictionary:
			_flatten(v, key, into)
		elif v is Array:
			for i in (v as Array).size():
				into["%s.%d" % [key, i]] = String((v as Array)[i])
		else:
			into[key] = String(v)

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func _first(list: Array, most: int = 3) -> String:
	if list.is_empty():
		return "none"
	var head: Array = list.slice(0, most)
	return ", ".join(head) + ("" if list.size() <= most else " … and %d more" % (list.size() - most))
