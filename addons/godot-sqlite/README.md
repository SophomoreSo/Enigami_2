# godot-sqlite

SQLite 3 for GDScript, as a GDExtension — <https://github.com/2shady4u/godot-sqlite>,
by Piet Bronders & Jeroen De Geeter, MIT (see [LICENSE.md](LICENSE.md)).

**Release v4.7** (January 2026), taken from that release's `bin.zip` as it
came, with nothing rebuilt. It is the last release built for Godot 4.5:
`gdsqlite.gdextension` says `compatibility_minimum = "4.5"`, and v4.8 moves
to 4.6. Update the engine before updating this.

The game reaches it through one door, `Db` (`app/db.gd`), and reads one
file, `data/enigami.db`. No other script names `SQLite`.

## What is in `bin/`

| Platform | Committed | Why |
|---|---|---|
| Linux x86_64, Windows x86_64, macOS universal, Android arm64 | yes, debug and release | the desk, CI, and every preset in `export_presets.cfg` |
| iOS arm64 | **no** — `fetch.sh ios` | the static libraries plus the godot-cpp archives they need are 280MB, for a build that is skipped until there is a team id (see `.github/README.md`) |
| Web | no — `fetch.sh web` | no preset |
| Android x86_64, Linux arm64 | no | no preset; take them from the same release if one appears |

The editor loads only the library for the machine it is on, so the iOS
entries in `gdsqlite.gdextension` cost nothing until an iOS export asks for
them — and then `fetch.sh ios` puts them in place. `.gitignore` keeps them out.

## Updating

1. Pick the newest release whose `gdsqlite.gdextension` has a
   `compatibility_minimum` the engine in `.github/workflows/ci.yml` meets.
2. Set `VERSION` in `fetch.sh`, run `fetch.sh all`, and delete from `bin/`
   what the table above says is not committed.
3. Copy the release's `gdsqlite.gdextension` over this one, then take out the
   entries for the platforms that are not committed, keeping iOS.
4. Run `tests/story/dialogue_test.tscn` — it fails first if the library does
   not load.
