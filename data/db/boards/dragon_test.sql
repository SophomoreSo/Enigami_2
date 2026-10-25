-- The board the dragon test's tower is built around (feature/world/dragon_test.gd):
-- a SWIFT STRIKE for its root, then an ON HIT whose branch walks two
-- OVERCLOCKs back round into the root, while its own flow leaves the board
-- straight ahead through AUTO-AIM — so every lunge, the first and each lap's,
-- goes at the nearest guard still standing and through. AUTO-AIM is on the
-- way out rather than in the ring, so a lap is four parts, and a full charge
-- buys ten. The root takes flow like any other part, which is what lets the
-- ring close on it. Named in the code.

INSERT INTO boards (id) VALUES ('dragon');

INSERT INTO board_parts (board_id, x, y, part, facing, root) VALUES
	('dragon', 4, 2, 'DASHSLASH', 'E', 1),
	('dragon', 5, 2, 'ON_HIT', 'E', 0),
	('dragon', 6, 2, 'AUTO_AIM', 'E', 0),
	('dragon', 5, 3, 'OVERCLOCK', 'W', 0),
	('dragon', 4, 3, 'OVERCLOCK', 'N', 0);
