-- The rock's graph in the ghost test (feature/world/ghost_test.gd): the
-- rock's own throw for its root, and POSSESS on it twice, so a guard the rock
-- strikes is the player's for ten seconds — long enough to walk the hall and
-- throw it on into the next. Named in the code.

INSERT INTO boards (id) VALUES ('ghost');

INSERT INTO board_parts (board_id, x, y, part, facing, root) VALUES
	('ghost', 4, 2, 'PROJECTILE', 'E', 1),
	('ghost', 5, 2, 'POSSESS', 'E', 0),
	('ghost', 6, 2, 'POSSESS', 'E', 0);
