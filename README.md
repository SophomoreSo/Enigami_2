# Enigami

A single-player 2D game seen from above, in the Hyper Light Drifter way:
pixel-art sprites on a floor the player walks round, where skills are
circuits assembled on a grid and loot is only yours once you walk it out of
the raid. The second Enigami: v1, a 2D platformer, stays where it is in
`WIPGames/Enigami/`; this is a new project built from it, step by step, as
`PLAN.md` says, a commit a step.

Built on Godot 4.5. Nothing in it is 3D. Monsters and bystanders are
animated sprites cut at runtime from one CC0 atlas ([0x72's 16x16
DungeonTileset II](https://0x72.itch.io/dungeontileset-ii), see
`graphics/assets/sprites/CREDITS.md`), the heroes are sprite sheets in four
facings made with PixelLab (`graphics/assets/sprites/HEROES.md`), the rooms
are tiles, and the whole UI is drawn from primitives. Every sound is a file
the sound bank lists (`data/db/sounds/`), silent until it is made and
switched on. The only other assets are two OFL fonts
(`graphics/assets/fonts/CREDITS.md`) and the studio's logos.

The rules and the picture are two separate modules, `feature/` and
`graphics/`, with a one-way seam between them — see
[ARCHITECTURE.md](ARCHITECTURE.md). The content — conversations, the
player's state machine, the parts, the boards, the maps — is a database,
`data/enigami.db`, built from the SQL under `data/db/` (`data/db/README.md`).

## Running

```bash
godot                                   # opens the project
tests/run.sh tests/circuit tests/feature tests/story tests/perks tests/shared   # the headless half
tests/run.sh --display --exclude '*shot*' tests/graphics tests/mobile          # these need a window
```

Every scene gets a deadline, a log per scene lands in `.test-logs/`, and the
run exits nonzero if anything failed that isn't quarantined
(`tests/quarantine.txt`). The run points `HOME` at `.test-home/` in the
project, so a test's reset of the profile never touches the save you play.

A fresh checkout has no `.godot/`, so nothing resolves a `class_name` until
`godot --headless --import --path .` has run once.

## Building

`data/db/build.sh` rebuilds the content database from its SQL. CI
(`.github/workflows/ci.yml`) runs the tests headless, checks the module
split holds, runs the graphics tests under Xvfb and exports Linux, Windows,
macOS, Android and iOS on a `v*` tag.
