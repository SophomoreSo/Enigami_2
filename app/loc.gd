extends Node

## Every word the game says, in whichever language is picked.
##
## The text lives outside the code, under `localization/<lang>/<domain>.json`,
## one file per part of the game. A screen asks for a line by name:
##
##     Loc.t("menu.title.start")            # "START"  ·  "시작"
##     Loc.t("hud.extract.hold", [key])   # "hold %s to extract" filled in
##
## Both modules may read it. It sits in `app/` for the same reason `Cues` does:
## the rules name a part and a monster, the picture names a button and a
## heading, and neither should have to reach into the other to find out how
## that word is spelled today. See `localization/README.md` for the format and
## ARCHITECTURE.md for where it sits.
##
## **Every lookup falls back.** A key the current language has not translated
## reads in the default language; a key nothing has reads as the key itself,
## with one warning. A language is therefore always playable the moment its
## folder exists, however little of it is filled in — which is what lets a
## translation land in pieces instead of all at once.

const DIR := "res://localization"
const DEFAULT := "eng"

## Kept out of the save: the language is a property of whoever is sitting at
## the machine, not of the profile they are playing, so wiping a profile must
## not put the game back into a language its player cannot read.
const PATH := "user://enigami_language.json"

## The languages offered, in menu order. `name` is deliberately written in the
## language itself — someone who has landed in the wrong one has to be able to
## find their way out of it.
##
## `fonts` names faces to borrow glyphs from for writing neither the bundled
## Latin faces nor the language's own face carries. Silkscreen and Playfair are
## Latin-only, so without a face of its own a Korean line draws as empty boxes;
## these are the last resort behind one.
##
## `face` is the size at which one pixel of the language's face is one pixel on
## screen — the size its glyphs were drawn at. Silkscreen is an 8px face, so
## Latin at `UiKit.PIXEL_TEXT` is doubled and lands on `UiKit.PIXEL`'s 2-pixel
## grid. 둥근모꼴 is a 16px face, so Hangul at that same size lands on a 1-pixel
## grid — finer, still whole pixels, and the only way to have it readable: a
## 16px Hangul body doubled would stand 26px tall against capitals of 10.
##
## It is also what `pixel_size` rounds to. A bitmap face has exactly one correct
## shape per pixel, and at a size its own size does not divide, FreeType hands
## back some strokes a pixel wider than others — hard-edged and ragged.
const LANGUAGES := {
	"eng": {"name": "English", "locale": "en", "face": 8, "fonts": []},
	"kor": {"name": "한국어", "locale": "ko", "face": 16, "fonts": [
		"Apple SD Gothic Neo", "AppleGothic", "Malgun Gothic", "Noto Sans CJK KR",
		"Noto Sans KR", "NanumGothic", "Source Han Sans K", "UnDotum",
	]},
}

## The face a language ships, looked for in its own folder. Godot reads all of
## these, and the upstream file is taken as it comes rather than converted.
const FONT_NAMES := ["font.woff2", "font.woff", "font.ttf", "font.otf"]

## The domain files every language is expected to carry. A missing one is not
## an error — its keys simply fall back — but `tests/shared/loc_test` reads
## this list to check that nothing has been left behind.
const DOMAINS := ["menu", "hud", "hideout", "editor", "controls", "parts",
	"weapons", "monsters", "perks"]

## Folders of per-id files rather than one flat file: a conversation and a
## scene are keyed by the id of the character or scene they belong to.
const OVERLAY_DIRS := ["dialogue", "scenes"]

## The fonts the game draws with. Their fallback chain is rewritten whenever the
## language changes; `ThemeDB.fallback_font` covers every `draw_string` that
## does not name a face of its own.
const PIXEL_FONT := preload("res://graphics/assets/fonts/Silkscreen-Regular.ttf")
const SERIF_FONT := preload("res://graphics/assets/fonts/PlayfairDisplay-Variable.ttf")

signal language_changed(lang: String)

var language: String = DEFAULT

var _strings: Dictionary = {}     ## "domain.key" -> String, the current language
var _base: Dictionary = {}        ## the same for DEFAULT, the fallback under it
var _overlays: Dictionary = {}    ## "dialogue/sage" -> Dictionary, read on demand
var _missing: Dictionary = {}     ## keys already warned about, so it warns once
var _loaded: bool = false
## Silkscreen with nothing behind it, for asking what it can spell on its own —
## the real one answers for its whole fallback chain, which is the question the
## chain exists to stop anybody having to ask.
var _latin: FontFile = null
## The faces behind it, in the order they are consulted, each with the size it
## was drawn at: `[{"font": FontFile, "face": int}]`. Built by `_apply_fonts`.
var _faces: Array = []

func _ready() -> void:
	_load_saved()

## --- reading ----------------------------------------------------------------

## The line called `key`, which is `<domain>.<name>` — the file it lives in and
## the name inside it. `args` fills a line that carries `%` placeholders.
##
## Formatting happens here rather than at the call site so the whole line,
## placeholders and all, is one thing a translator edits — but `%` fills them
## in **order**, so every language has to keep the same placeholders in the
## same sequence. Rewording around them is free; swapping two of them silently
## prints a name where a number should be. `tests/shared/loc_test` compares
## every line's placeholders against the default language for exactly that.
func t(key: String, args: Array = []) -> String:
	var s := _lookup(key)
	if args.is_empty():
		return s
	# A translation with the wrong number of placeholders would otherwise
	# return an empty string and take the line off the screen with no clue why.
	var out: String = s % args
	if out == "" and s != "":
		push_warning("Loc: '%s' does not take %d value(s) in %s" % [key, args.size(), language])
		return s
	return out

## Whether anything at all answers to `key`. For a screen that draws a line
## only when there is one to draw.
func has(key: String) -> bool:
	_ensure_loaded()
	return _strings.has(key) or _base.has(key)

## `key` if it exists, `fallback` if it does not — for text keyed by something
## the rules invented, like a part id, where a missing entry means "this one has
## no word of its own yet" rather than "someone forgot".
func opt(key: String, fallback: String) -> String:
	_ensure_loaded()
	if _strings.has(key):
		return String(_strings[key])
	if _base.has(key):
		return String(_base[key])
	return fallback

func _lookup(key: String) -> String:
	_ensure_loaded()
	if _strings.has(key):
		return String(_strings[key])
	if _base.has(key):
		return String(_base[key])
	if not _missing.has(key):
		_missing[key] = true
		push_warning("Loc: nothing says '%s'" % key)
	return key

## --- text that belongs to a data file ---------------------------------------

## The translated text for one dialogue character or one scene, as
## `localization/<lang>/<kind>/<id>.json`. Empty when the language has none,
## which leaves the text in `data/` standing.
##
## `Dialogue` and `CutsceneScript` lay this over the file they read. The flow —
## where a line leads, who walks where, what the camera does — stays in `data/`,
## so a translator never has to touch the structure and a writer never has to
## touch six languages. See `localization/README.md`.
func overlay(kind: String, id: String) -> Dictionary:
	var key := "%s/%s" % [kind, id.to_lower()]
	if _overlays.has(key):
		return _overlays[key]
	var d := _read(DIR.path_join(language).path_join(key + ".json"))
	if d.is_empty() and language != DEFAULT:
		d = _read(DIR.path_join(DEFAULT).path_join(key + ".json"))
	_overlays[key] = d
	return d

## --- switching --------------------------------------------------------------

func set_language(lang: String) -> void:
	if not LANGUAGES.has(lang):
		push_warning("Loc: no language '%s'" % lang)
		return
	if lang == language and _loaded:
		return
	language = lang
	_load()
	_save()
	language_changed.emit(lang)

## The ids of the languages on offer, in the order the menu shows them.
func languages() -> Array:
	return LANGUAGES.keys()

## What to call a language on a button, written in that language.
func language_name(lang: String) -> String:
	return String((LANGUAGES.get(lang, {}) as Dictionary).get("name", lang))

## The face a language ships, or "" when it has none and is borrowing glyphs
## from whatever the machine happens to have.
func font_path(lang: String = language) -> String:
	for file in FONT_NAMES:
		var path := DIR.path_join(lang).path_join(file)
		if ResourceLoader.exists(path):
			return path
	return ""

## Whether this language is being written in glyphs borrowed from the machine
## rather than in a face the game ships.
##
## It matters for more than fidelity. A borrowed face is an outline font drawn
## from curves at whatever size it likes, so a screen written in one cannot be
## promised to land on whole pixels at all, however the text server is
## configured — it is readable, and it is not pixel art. A language with a face
## of its own is held to `pixel_grid` instead.
func borrows_glyphs() -> bool:
	if font_path() != "":
		return false
	var names: Array = (LANGUAGES.get(language, {}) as Dictionary).get("fonts", [])
	return not names.is_empty()

## The size one pixel of a language's face is drawn at, 1:1. See `face` above.
func face_size(lang: String = language) -> int:
	return maxi(1, int((LANGUAGES.get(lang, {}) as Dictionary).get("face", 8)))

## `want`, rounded down to a size the language's own face draws cleanly at, and
## never below that face's own size — there is no such thing as half a pixel of
## a bitmap glyph, and an 8px Hangul syllable is not a smaller syllable but a
## broken one.
##
## A language with no face of its own keeps exactly the size it asked for: those
## sizes were chosen for Silkscreen and are already whole multiples of it.
func pixel_size(want: int) -> int:
	if font_path() == "":
		return want
	var n := face_size()
	return maxi(n, want - want % n)

## The size to draw this particular line at, which depends on the face that
## will end up drawing it rather than on the language being played.
##
## Latin keeps the size it asked for, in every language: a damage number is
## drawn in Silkscreen whatever the menus are set to, and has no reason to
## change size because they changed. A line the bundled faces cannot spell is
## rounded to the face that can — and the world draws at 8px, which is half of
## 둥근모꼴 and would hand back every other row of every syllable.
##
## It has to be the line and not the language because a screen can hold both at
## once: the settings write every language's name in its own script, and a
## skill the player named in Korean is still named that after a switch back.
func text_size(text: String, want: int) -> int:
	var n := face_for(text)
	if n <= 0 or want % n == 0:
		return want
	return maxi(n, want - want % n)

## The size the face that will draw `text` was drawn at, or 0 when the bundled
## Latin faces spell all of it and nothing needs to move.
func face_for(text: String) -> int:
	var missing: Array[int] = []
	for i in text.length():
		var c := text.unicode_at(i)
		if c > 32 and not _latin_face().has_char(c) and not missing.has(c):
			missing.append(c)
	if missing.is_empty():
		return 0
	for entry in _faces:
		var f: Font = entry["font"]
		var spells := true
		for c in missing:
			if not f.has_char(c):
				spells = false
				break
		if spells:
			return int(entry["face"])
	return 0

func _latin_face() -> FontFile:
	if _latin == null:
		_latin = PIXEL_FONT.duplicate() as FontFile
		_latin.fallbacks = []
	return _latin

## --- loading ----------------------------------------------------------------

func _ensure_loaded() -> void:
	if not _loaded:
		_load()

func _load() -> void:
	_loaded = true
	_missing.clear()
	_overlays.clear()
	_base = _read_language(DEFAULT)
	_strings = _base if language == DEFAULT else _read_language(language)
	_apply_locale()
	_apply_fonts()
	# A conversation already read is in the old language; `Dialogue` and
	# `CutsceneScript` notice that for themselves the next time they are asked.

func _read_language(lang: String) -> Dictionary:
	var out: Dictionary = {}
	for domain in DOMAINS:
		var file := _read(DIR.path_join(lang).path_join(domain + ".json"))
		_flatten(file, domain, out)
	return out

## `{"slot": {"hint": "…"}}` in `hud.json` becomes `hud.slot.hint`. Nesting is
## for whoever reads the file; the lookup only ever sees one flat name.
func _flatten(d: Dictionary, prefix: String, into: Dictionary) -> void:
	for k in d:
		var key := "%s.%s" % [prefix, k]
		var v = d[k]
		if v is Dictionary:
			_flatten(v, key, into)
		elif v is Array:
			# A list is addressed by position: `hud.map.pressure.0`, `.1`, `.2`…
			for i in (v as Array).size():
				into["%s.%d" % [key, i]] = String((v as Array)[i])
		else:
			into[key] = String(v)

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Loc: %s is not an object" % path)
		return {}
	return parsed

## --- the face ---------------------------------------------------------------

## Points the bundled fonts, and the one every plain `draw_string` uses, at a
## face that carries the language's writing. Setting `fallbacks` rather than
## appending to it means switching back and forth never stacks up chains.
##
## A face shipped with the language wins over one borrowed from the machine: a
## build that carries `localization/<lang>/font.ttf` looks the same everywhere,
## which one leaning on the player's system fonts cannot promise.
func _apply_fonts() -> void:
	var chain: Array[Font] = []
	_faces.clear()
	# Every language's face, not just the one being played: the settings screen
	# writes each language's name in its own script whatever is set, and a skill
	# named in one language keeps that name after a switch to another. The
	# language being played goes first, so its face answers for anything two of
	# them could both draw.
	var order: Array = [language]
	for lang in LANGUAGES:
		if not order.has(lang):
			order.append(lang)
	for lang in order:
		var bundled := font_path(lang)
		if bundled == "":
			continue
		var f = load(bundled)
		if f is Font:
			chain.append(f)
			_faces.append({"font": f, "face": face_size(lang)})
	var names: Array = (LANGUAGES.get(language, {}) as Dictionary).get("fonts", [])
	if not names.is_empty():
		var sys := SystemFont.new()
		sys.font_names = PackedStringArray(names)
		# Anti-aliasing off so borrowed glyphs sit on the same grid as the
		# pixel face they are standing in for.
		sys.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		sys.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		chain.append(sys)
	for font in [PIXEL_FONT, SERIF_FONT, ThemeDB.fallback_font]:
		if font is Font:
			(font as Font).fallbacks = chain

## Godot's own text — the strings it puts in a file dialog or a default
## tooltip — follows `TranslationServer`, which knows nothing about the files
## above. One line keeps the engine speaking the same language as the game.
func _apply_locale() -> void:
	var locale := String((LANGUAGES.get(language, {}) as Dictionary).get("locale", "en"))
	TranslationServer.set_locale(locale)

## --- remembering ------------------------------------------------------------

func _load_saved() -> void:
	var lang := ""
	if FileAccess.file_exists(PATH):
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f != null:
			var parsed = JSON.parse_string(f.get_as_text())
			f.close()
			if parsed is Dictionary:
				lang = String((parsed as Dictionary).get("language", ""))
	if not LANGUAGES.has(lang):
		lang = _guess_language()
	language = lang
	_load()

## First run, with nothing saved: start in the language the machine is set to,
## if the game has it. Somebody on a Korean desktop should not have to find the
## settings screen in English before the game will speak to them.
func _guess_language() -> String:
	var os_locale := OS.get_locale_language()
	for lang in LANGUAGES:
		if String((LANGUAGES[lang] as Dictionary).get("locale", "")) == os_locale:
			return lang
	return DEFAULT

func _save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"language": language}))
	f.close()
