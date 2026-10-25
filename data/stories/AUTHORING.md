# Writing a story for Enigami

A story is one conversation between a character (an NPC) and the player, on a
map, written as a graph of nodes in `data/stories/<id>.json`. There are two
ways a story plays, and each has its own guide, complete on its own — hand a
model one or the other, not both:

- [AUTHORING_FROZEN.md](AUTHORING_FROZEN.md) — **frozen**: the player walks up
  and presses to talk, is held still, and the story runs in the box at the top
  of the screen, a press per line. A staged conversation.
- [AUTHORING_FREE.md](AUTHORING_FREE.md) — **free**: the player keeps playing,
  and the character talks in bubbles that move on by themselves. Ambient talk,
  with a question now and then.

Both read the same file format; the mode is the file's `mode` key, and the
guides differ in what plays well. The game's own reference for the format is
[README.md](README.md); the checker is `StoryMaker.problems_in`
(`story/rules/story_maker.gd`), and `tests/run.sh tests/story/story_maker_test.tscn`
runs it over every file here.
