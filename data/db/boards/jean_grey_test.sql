-- The rock's graph in the Jean Grey test (feature/world/jean_grey_test.gd): the
-- rock's own throw for its root, and POSSESS on it twice, so a guard the rock
-- strikes is the player's for ten seconds — long enough to walk the hall and
-- throw it on into the next. Named in the code.

INSERT INTO boards (id) VALUES ('jean_grey');

INSERT INTO board_parts (board_id, x, y, part, facing, root) VALUES
	('jean_grey', 4, 2, 'PROJECTILE', 'E', 1),
	('jean_grey', 5, 2, 'POSSESS', 'E', 0),
	('jean_grey', 6, 2, 'POSSESS', 'E', 0);
