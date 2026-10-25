# Localization

Every word the game says, one folder per language:

```
localization/
├── eng/            English — the default, and the fallback under every other
│   ├── menu.json        the title, the save slots, settings, pause, results
│   ├── hud.json         the raid HUD, the bench, the dragon test
│   ├── hideout.json     the hideout screen and its facilities
│   ├── editor.json      skill assembly, the share sheet, what a board says
│   ├── controls.json    the action names and what a binding is called
│   ├── parts.json       every component's name and description
│   ├── weapons.json     every weapon's name and description
│   ├── monsters.json    every monster's name
│   ├── dialogue/        what each character says — one file per character
│   │   └── sage.json
│   └── scenes/          what each directed scene says — one file per scene
│       └── intro.json
└── kor/            한국어 — the same files, the same keys
    └── font.woff        and a face to write them in: Silkscreen has no Hangul
```

Edit these to change what any screen says. No code involved.

`tests/shared/loc_test.tscn` checks every language against every other one,
against the English left in the code, that every letter of it can actually be
drawn, and that no line has been written into a screen instead of into here.
Run it after an edit.

## Asking for a line

A screen names a line by the file it is in and the name inside it:

```gdscript
Loc.t("menu.title.start")                        # "START"  ·  "시작"
Loc.t("hud.bag.row", [Components.name_for(id), 3])   # "%s x%d" filled in
```

Nesting is for whoever reads the file; the name flattens with dots. These are
the same line:

```json
{"bag": {"row": "%s x%d"}}        ->  hud.bag.row
{"bag.row": "%s x%d"}             ->  hud.bag.row
```

A list is addressed by position, which is how the map's five pressure levels
are written:

```json
{"map": {"pressure": ["quiet", "stirring", …]}}
                                  ->  hud.map.pressure.0, hud.map.pressure.1
```

## Placeholders

A line carrying `%s`, `%d` or `%.2f` is filled in by `Loc.t`'s second argument.
**`%` fills them in order.** A translation may reword freely around them, and
may not reorder or retype them:

```json
"scrapped": "Scrapped %s for %d."          ✅  %s then %d
"scrapped": "%s을(를) 분해해 골드 %d을(를) 얻었습니다."   ✅  %s then %d
"scrapped": "골드 %d을(를) %s에서 얻었습니다."            ❌  %d then %s — prints a
                                                          name where a number goes
```

Where a language needs the other order, put the placeholder somewhere the order
still works — `"%d개 더 — %s"` rather than `"%s이(가) %d개 더"` — or ask for the
English to be rewritten so both can follow it. The test compares every line's
placeholders against the default language and fails on a swap.

Counting is a line each rather than an `s` on the end, because not every
language has plurals:

```json
"pulse_one": "%d pulse",
"pulse_many": "%d pulses"
```

Korean gives the same line twice, and reads right.

## Conversations and scenes

A conversation in the content database (`data/enigami.db`, written in
`data/db/dialogue/`) holds its shape — where each line leads, the camera, the
portrait, the sound. Only the **words** live here, laid over it by the line's
id:

```json
{
	"name": "Old Tinker",
	"player_name": "Knight",
	"nodes": {
		"hello": {"text": "Ah, a new face."},
		"ask": {"text": "What would you like to know?",
			"choices": ["How do skills work?", "Nothing. Bye."]}
	}
}
```

Answers are a plain list, in the order the question asks them — where each one
leads stays in `data/`, so a translator can never break a conversation.

Someone who talks free has `rules` rather than `nodes`, one per rule, and only
its words — which event it answers and when stays in `data/` too:

```json
{
	"name": "Apprentice",
	"rules": {
		"hello": {"text": "Oh! Somebody new."},
		"resume": {"text": "Where were we? Right, footwork."}
	}
}
```

A free line goes in a bubble of at most four rows, so a translation that runs
long fails `loc_test` rather than being cut short on screen.

A scene file is the same idea, addressed by the beat's position in
`data/scenes/<id>.json`, counting from zero, and naming the cast:

```json
{
	"cast": {"you": "Knight", "tinker": "Old Tinker"},
	"beats": {
		"0": {"text": "The seal held for a thousand years."},
		"5": {"text": "You're late."}
	}
}
```

Only beats that say something appear. **Inserting a beat in the middle of a
scene shifts every translation under it** — the test compares the default
language against `data/` line for line, so it fails rather than quietly putting
the wrong words in the wrong mouths.

## Falling back

Every lookup falls back, so a language is playable the moment its folder exists:

| What is missing | What happens |
|---|---|
| A line in the language being played | The default language's line |
| A line in every language | The key itself, and one warning |
| A whole domain file | Every key in it falls back |
| A part, weapon, monster or facility | The English in the parts table (`data/db/parts/parts.sql`), or in the code — `Weapons.DEFS` and its like |
| A menu's name, or what an item on it says | The English in the menus table (`data/db/menus/menus.sql`), by id: `menu.<menu>.heading`, `menu.<menu>.<item>`. A door says the name of the menu it opens, and has no line of its own |
| A dialogue line or a beat | The text in `data/` — the database, or the scene file |

That last pair is why the English in the code and in `data/` is still there: it
is the fallback, so a part added on the feature branch has a name on screen
before anybody has translated it. `loc_test` compares the two and fails if they
drift, which is what makes two homes for one sentence safe.

## Adding a language

1. Copy `eng/` to a new folder — three letters, lower case.
2. Add it to `LANGUAGES` in `app/loc.gd`: the folder name, what to call it
   **written in itself**, its two-letter locale, the `face` size its font was
   drawn at (see below), and the system font families to fall back on if its
   own face ever goes missing.
   If Silkscreen does not carry its writing, put a pixel face in the folder as
   `font.woff` with an `.import` copied from Korean's, and credit it in
   [CREDITS.md](CREDITS.md).
3. Translate. Run `tests/shared/loc_test.tscn`.

It appears in the settings panel on the title screen by itself. The choice is
kept in `user://enigami_language.json` — not in the save, so wiping a profile
cannot strand somebody in a language they do not read. With nothing saved, the
game starts in the machine's own language if it has it.

## The face

Silkscreen and Playfair are Latin-only: neither carries a single Hangul glyph,
so Korean would draw as a column of empty boxes without help. A language that
needs writing they do not have brings a face of its own, as
`localization/<lang>/font.woff` (`.woff2`, `.ttf` and `.otf` are read too —
whichever the author publishes smallest). `Loc` hangs it off the fonts the game
draws with as a fallback, so only the glyphs Silkscreen lacks reach it and
Latin keeps its own face.

**Every language's face is loaded at once, not just the one being played.** A
screen can hold two languages: the settings write each language's name in its
own script whatever is set, and a skill the player named in Korean still has
that name after a switch to English. A face that was not loaded does not show
as empty boxes either — the import allows a system fallback, so one smooth line
turns up in the middle of a pixel menu and nothing says why. `loc_test` checks
every language's name draws in every language.

Korean ships **둥근모꼴 + Fixedsys** — a 16-pixel bitmap face, public domain.
See [CREDITS.md](CREDITS.md) for its author and licence, and copy its
`.import` when adding another: **no antialiasing, no hinting, no subpixel
positioning**, exactly as Silkscreen is imported, because a bitmap face has one
correct shape per pixel and letting FreeType smooth it turns the stems grey.

Behind that sits a list of system font families per language in `LANGUAGES`
(`app/loc.gd`), tried in order. It is the safety net for a build whose font
file went missing, not the plan: a borrowed face is an outline font that lands
where it lands, and cannot be held to whole pixels at all.
`tests/shared/loc_test` fails if a language falls back to it.

### Two grids

Silkscreen is an 8-pixel face drawn at 16, so Latin sits on `UiKit.PIXEL`'s
**two-pixel** grid. 둥근모꼴 is a 16-pixel face drawn at 16, so Hangul sits on a
**one-pixel** grid — finer, still whole pixels, and on purpose. A Hangul
syllable stacks two or three letters into one square, so 16 pixels is about the
smallest it can be read at; drawn at twice the size it would share Latin's grid
and stand 26 pixels tall against capitals of 10.

`face` in `LANGUAGES` is where that number lives — 8 for Silkscreen, 16 for
둥근모꼴. **`Loc.text_size(text, want)` is what every screen asks**, and it
answers for the line rather than for the language: a line the Latin faces can
spell keeps exactly the size it asked for, and one they cannot is rounded down
to a multiple of the face that can. So the title menu gets 24px in English and
16 in Korean rather than a ragged 1.5×, a damage number stays at 8px in both,
and a Korean skill name on an English screen still lands on whole pixels.

That covers the screens that are not in the pixel look, too. The raid HUD and
the results sheet draw in the default face at 9–14px, which is *below* 둥근모꼴
and would hand back syllables with rows missing; `Hud._line` puts every one of
their lines through the same call.
The screen tests hold a language to `UiKit.PIXEL` only when it is on that grid, and
print what they skipped and why; `loc_test` holds every language to whole
pixels and to an import with no smoothing in it, which is the part that
actually keeps the text crisp.

## Exporting

The JSON files are plain files, not resources: an export preset needs
`localization/*/*.json` and `localization/*/*/*.json` in its non-resource
include filter, or the game will ship speaking nothing but its fallbacks. A
language's font **is** a resource and is included already — and if it were not,
`loc_test` would be the one to say so.
