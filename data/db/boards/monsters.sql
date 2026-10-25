-- Every monster's attack, on the same boards the player builds — which is what
-- makes a drop legible: a kill yields a part the monster was seen using. A
-- monster names its board as `board` (feature/actors/monsters.gd), and the
-- Arbiter the one it turns to at half health as `board_phase2`. Named in the
-- code, after the monster. The Test Dummy and the dragon test's Grunts have
-- none, and attack with nothing.
--
-- Laid out like every board: the monster's own part is the root (`root` 1),
-- where the flow starts, and the chain runs from it into the middle of the
-- right edge, (6, 2), which is where its flow leaves as the attack. That part
-- is its form, or a NEAR: with no form under it, a NEAR selects the enemies
-- round where the monster stands, and what comes after it is the attack on
-- each of them (data/db/parts/parts.sql).

INSERT INTO boards (id) VALUES
	('crawler'), ('sentry'), ('lobber'), ('hopper'), ('drifter'), ('bomber'), ('warden'), ('arbiter'), ('arbiter_phase2'),
	('gunman');

INSERT INTO board_parts (board_id, x, y, part, facing, root) VALUES
	('crawler', 6, 2, 'SLASH', 'E', 1),

	('sentry', 6, 2, 'PROJECTILE', 'E', 1),

	('lobber', 5, 2, 'PROJECTILE', 'E', 1), ('lobber', 6, 2, 'DAMAGE', 'E', 0),

	-- Everything round where it lands, hurt as hard as a DAMAGE makes it.
	('hopper', 5, 2, 'NEAR', 'E', 1), ('hopper', 6, 2, 'DAMAGE', 'E', 0),

	('drifter', 5, 2, 'PROJECTILE', 'E', 1), ('drifter', 6, 2, 'HOMING', 'E', 0),

	-- A punch as hard as a DAMAGE makes it, burning, and the DAMAGE and the
	-- FIRE after the NEAR reaching everything round whoever it struck. It is
	-- the last thing the Bomber does (feature/actors/monsters.gd): the flow
	-- then goes up where it stands — the same NEAR with no form under it, which
	-- hurts and burns everything round the Bomber.
	('bomber', 3, 2, 'HEADBUTT', 'E', 1), ('bomber', 4, 2, 'NEAR', 'E', 0),
	('bomber', 5, 2, 'DAMAGE', 'E', 0), ('bomber', 6, 2, 'FIRE', 'E', 0),

	-- A frost bolt, three times over.
	('warden', 4, 2, 'PROJECTILE', 'E', 1), ('warden', 5, 2, 'ICE', 'E', 0),
	('warden', 6, 2, 'DUPLICATE', 'E', 0),

	('arbiter', 4, 2, 'PROJECTILE', 'E', 1), ('arbiter', 5, 2, 'FIRE', 'E', 0),
	('arbiter', 6, 2, 'DUPLICATE', 'E', 0),

	-- A blow on everything round it, as hard as a DAMAGE makes it, whose every
	-- touch sends a bolt, three times over. The ON HIT's branch drops to the
	-- row below, and the DUPLICATE turns it back up into the NEAR's line to
	-- leave the way it does, over BRIDGEs that add nothing to the wait. The
	-- DAMAGE stands after the ON HIT and off the branch's way, so the bolts are
	-- no harder for it; and they reach nobody else: a branch starts without the
	-- NEAR before its trigger.
	('arbiter_phase2', 2, 2, 'NEAR', 'E', 1), ('arbiter_phase2', 3, 2, 'ON_HIT', 'E', 0),
	('arbiter_phase2', 4, 2, 'DAMAGE', 'E', 0),
	('arbiter_phase2', 5, 2, 'BRIDGE', 'E', 0), ('arbiter_phase2', 6, 2, 'BRIDGE', 'E', 0),
	('arbiter_phase2', 3, 3, 'PROJECTILE', 'E', 0), ('arbiter_phase2', 4, 3, 'BRIDGE', 'E', 0),
	('arbiter_phase2', 5, 3, 'DUPLICATE', 'N', 0),

	-- The Jean Grey test's rifle: one bolt, which the Gunman's kind makes
	-- heavy and quick (feature/actors/monsters.gd).
	('gunman', 6, 2, 'PROJECTILE', 'E', 1);
