# Font credits

Both faces are under the **SIL Open Font License 1.1**, which permits use,
modification and redistribution — including inside a commercial game — as long
as the fonts are not sold on their own and the licence travels with them.

| File | Face | Author |
|---|---|---|
| `Silkscreen-Regular.ttf` | [Silkscreen](https://fonts.google.com/specimen/Silkscreen) | Jason Kottke |
| `PlayfairDisplay-Variable.ttf` | [Playfair Display](https://fonts.google.com/specimen/Playfair+Display) | Claus Eggers Sørensen |

Silkscreen is the pixel face: the title screen's menu, records line and settings,
the hideout and the assembly screen (UiKit's pixel look), the dialogue and
cutscene boxes, and all text drawn in the world (`PixelCamera.draw_text`). Its
import is set to **no antialiasing, no hinting and no
subpixel positioning** (`Silkscreen-Regular.ttf.import`) — a bitmap face has
exactly one correct shape per pixel, and letting FreeType smooth it turns the
stems grey. Draw it at whole multiples of 8px for the same reason.

Its lowercase is drawn as capitals, so prose set in it reads in capitals. That
is the look on every screen that uses it, the conversations included.

Playfair Display draws one word, `Enigami`, and nothing else. It is a variable
font used at its default weight; `graphics/ui/title_screen.gd` is the only
file that loads it.

The raid HUD and the results sheet are what still use `ThemeDB.fallback_font`,
at sizes below Silkscreen's — they are not in the pixel look.

Neither face carries a single Hangul glyph, so Korean is drawn in a face of its
own that lives beside the words it is for — see
[`localization/CREDITS.md`](../../../localization/CREDITS.md). `Loc` hangs it
off both faces above, and off `ThemeDB.fallback_font`, as a fallback: only the
writing Silkscreen lacks reaches it.
