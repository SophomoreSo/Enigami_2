-- The bench's sample skills that are no proving ground's own (feature/world/
-- sandbox.gd, `Sandbox.samples`). The dragon test's and the Jean Grey test's
-- are in their own files. Named in the code.
--
-- seeker: an arrow off the gun that will not be dodged. AUTO-AIM sends it at
-- the nearest enemy it can reach, three RANGE — RANGE's limit — carry it five
-- times as far, three HOMING turn it after that enemy and find it a way round
-- whatever is in between, and four SPEED — SPEED's limit — fly it at laser
-- speed. Twelve parts do not go in a row, so it snakes: along the top from the
-- root, back along the middle, and out along the bottom to the way out.

INSERT INTO boards (id) VALUES ('seeker');

INSERT INTO board_parts (board_id, x, y, part, facing, root) VALUES
	('seeker', 3, 0, 'PROJECTILE', 'E', 1),
	('seeker', 4, 0, 'AUTO_AIM', 'E', 0),
	('seeker', 5, 0, 'RANGE', 'E', 0),
	('seeker', 6, 0, 'RANGE', 'S', 0),
	('seeker', 6, 1, 'RANGE', 'W', 0),
	('seeker', 5, 1, 'HOMING', 'W', 0),
	('seeker', 4, 1, 'HOMING', 'W', 0),
	('seeker', 3, 1, 'HOMING', 'S', 0),
	('seeker', 3, 2, 'SPEED', 'E', 0),
	('seeker', 4, 2, 'SPEED', 'E', 0),
	('seeker', 5, 2, 'SPEED', 'E', 0),
	('seeker', 6, 2, 'SPEED', 'E', 0);
