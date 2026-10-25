# Font credits

A language whose writing the bundled Latin faces do not carry brings a face of
its own, in its own folder.

| File | Face | Author | Licence |
|---|---|---|---|
| `kor/font.woff` | [둥근모꼴 + Fixedsys](https://noonnu.cc/font_page/250) (DungGeunMo), v1.200 | 길형진 (orioncactus), after the 1990s DOS bitmap face 둥근모꼴 by 김중태 | **Public domain** — the font's own `name[0]` reads `Public Domain`. Redistribution, modification and commercial use are all allowed; selling the font file on its own is not. |

The file is the author's web build, taken unmodified from the distribution
[noonnu](https://noonnu.cc/font_page/250) points at
(`projectnoonnu/noonfonts_six@1.2`). It is WOFF rather than TTF only because
that is the smaller of the two files the author publishes — 1.6 MB against 7.2 —
and Godot reads both. Its home is <https://cactus.tistory.com/193>.

## Why this face

It is a 16-pixel bitmap face, which is the smallest a Hangul syllable can be
drawn at and still be read: every syllable stacks two or three letters into one
square, so it needs the height that Latin does not. Its import is set to **no
antialiasing, no hinting and no subpixel positioning**
(`kor/font.woff.import`), the same as Silkscreen's, for the same reason — a
bitmap face has exactly one correct shape per pixel.

It carries all 11,172 Hangul syllables, so nothing the game says can fall
through it, and Latin of its own, which nothing uses: Silkscreen already has
those glyphs, so only the writing it lacks reaches this face.

## The grid

Silkscreen is an 8-pixel face drawn at 16, so Latin lands on `UiKit.PIXEL`'s
two-pixel grid. 둥근모꼴 is a 16-pixel face drawn at 16, so Hangul lands on a
one-pixel grid — finer, still whole pixels, and deliberate. Drawn at twice the
size it would sit on the same grid as the Latin, and stand 26 pixels tall
against capitals of 10.

`tests/shared/loc_test` holds every language to whole pixels and to an import
with no smoothing in it; `tests/graphics/*_pixel_test` hold the two-pixel grid
for the languages that are on it, and say in their output when they have not.
