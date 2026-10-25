-- What grows on the rooms' floors, and how much of each a room grows. See
-- "Foliage" in README.md. The numbers are `Foliage`'s (graphics/foliage.gd):
-- change one here and rebuild, and every patch of that kind in the game is
-- drawn and moves that way. A new kind is a row here, a row of `growths` for
-- the rooms to grow it, and its colours in graphics/style.gd.
INSERT INTO foliage (id, form, sway, shortest, tallest, density, push, wind) VALUES
	('grass',   'blades',  'along', 4,  11, 0.85, 12, 4),
	('flowers', 'flowers', 'along', 8,  13, 0.3,  12, 4),
	('bush',    'bush',    'any',   8,  13, 1,    6,  2);

-- Drawn in this order, each over the last: a bush stands behind the grass,
-- and flowers come up through it.
INSERT INTO growths (foliage, fewest, most, shortest, longest) VALUES
	('bush',    0, 2, 1, 2),
	('grass',   4, 7, 3, 8),
	('flowers', 1, 3, 1, 3);
