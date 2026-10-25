-- The raid's floor: which hand-made map stands where on its 7 by 5 grid,
-- what kind of room it is, how dangerous, and which way out it offers. Two
-- rooms side by side are joined through doorways their maps mark (`<` `>`),
-- and two one above the other through gates (`U` `D`); an exit stands on the
-- room's `E`. What each column means is the README's **A floor**. In play a
-- room stands where its column and row put it, and a doorway is walked
-- through into the room beside, stood up as the player nears it (`Raid`).
--
-- Laid from what the old generator grew from one seed, a room a map, to start
-- from: every room here is a map the map creator opens (raid_<x>_<y>).

INSERT INTO raid_rooms (x, y, map_id, kind, danger, exit) VALUES
	(0, 1, 'raid_0_1', 'treasure', 2, NULL),
	(1, 1, 'raid_1_1', 'treasure', 3, NULL),
	(2, 1, 'raid_2_1', 'boss', 5, 'arbiter'),
	(0, 2, 'raid_0_2', 'normal', 2, NULL),
	(1, 2, 'raid_1_2', 'normal', 2, NULL),
	(2, 2, 'raid_2_2', 'normal', 3, NULL),
	(0, 3, 'raid_0_3', 'normal', 1, NULL),
	(1, 3, 'raid_1_3', 'normal', 2, NULL),
	(2, 3, 'raid_2_3', 'normal', 2, NULL),
	(3, 3, 'raid_3_3', 'normal', 3, 'toll'),
	(0, 4, 'raid_0_4', 'entry', 1, 'entry'),
	(1, 4, 'raid_1_4', 'normal', 3, 'crack'),
	(2, 4, 'raid_2_4', 'normal', 2, NULL),
	(3, 4, 'raid_3_4', 'normal', 2, NULL),
	(4, 4, 'raid_4_4', 'treasure', 3, NULL);
