-- Each weapon's own graph, as a new profile gets it: the weapon's own part,
-- its root, and nothing else. It stands against the board's way out — the
-- middle of the right edge — so the flow it starts leaves the board at once,
-- and a weapon nobody has built on fires. The root is the weapon's and stays on
-- the board; the player moves it back and builds in front of it. A weapon names
-- its graph as `board` and its root part as `root` (feature/core/weapons.gd),
-- and tests/feature/boards_test holds the two to each other. Named in the
-- code, after the weapon, in the language being played.
--
-- The empty hand has one too (`Weapons.HAND`): what every slot of a kit no
-- weapon is in casts, a PUNCH (`HEADBUTT`) at its root.

INSERT INTO boards (id) VALUES ('sword'), ('gun'), ('rock'), ('shovel'), ('shuriken'), ('rune'), ('hand');

INSERT INTO board_parts (board_id, x, y, part, root) VALUES
	('sword', 6, 2, 'DASHSLASH', 1),
	('gun', 6, 2, 'PROJECTILE', 1),
	('rock', 6, 2, 'PROJECTILE', 1),
	('shovel', 6, 2, 'SLASH', 1),
	('shuriken', 6, 2, 'PROJECTILE', 1),
	('rune', 6, 2, 'PROJECTILE', 1),
	('hand', 6, 2, 'HEADBUTT', 1);
