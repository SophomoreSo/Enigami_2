-- The perks a player can buy (perks/rules/perks.gd), in the order the perk
-- station's page lists them, and what each of their steps costs in gold.
--
-- Every perk has three steps, each dearer than the last: the first is a raid's
-- takings, the last something saved up for. They are priced against the
-- hideout's facilities (`GameState.facility_cost`, 60, 240, 540 a level), which
-- build the room up where these build the player up, and against a raid, which
-- brings home a few dozen gold.

INSERT INTO perks (id, name, stat, per_step, description) VALUES
	('TOUGHNESS', 'TOUGHNESS', 'max_health', 10, 'More health: 10 more for every step.'),
	('ENDURANCE', 'ENDURANCE', 'max_stamina', 25, 'More stamina: every step is one more dash before the bar runs dry.'),
	('SWIFTNESS', 'SWIFTNESS', 'move_speed', 0.06, 'Runs and sprints faster: every step adds 6%.'),
	('FOCUS', 'FOCUS', 'max_mana', 20, 'More mana to charge a cast with: 20 more for every step.'),
	('QUICK_CHARGE', 'QUICK CHARGE', 'charge_speed', 0.2, 'Holding the cast button charges faster: every step adds 20%. The mana goes as fast as the charge builds.'),
	('DEEP_CHARGE', 'DEEP CHARGE', 'max_charge', 9, 'A hold charges further before it is full: every step adds a quarter more, and costs the mana it buys.'),
	('QUICK_HANDS', 'QUICK HANDS', 'cast_speed', 0.06, 'A shorter wait between casts: every step takes off 6%.'),
	('SCAVENGER', 'SCAVENGER', 'gold', 0.15, 'More gold from everything found in a raid: every step adds 15%.');

INSERT INTO perk_steps (perk_id, step, cost) VALUES
	('TOUGHNESS', 1, 60), ('TOUGHNESS', 2, 140), ('TOUGHNESS', 3, 260),
	('ENDURANCE', 1, 60), ('ENDURANCE', 2, 140), ('ENDURANCE', 3, 260),
	('SWIFTNESS', 1, 60), ('SWIFTNESS', 2, 140), ('SWIFTNESS', 3, 260),
	('FOCUS', 1, 60), ('FOCUS', 2, 140), ('FOCUS', 3, 260),
	('QUICK_CHARGE', 1, 80), ('QUICK_CHARGE', 2, 180), ('QUICK_CHARGE', 3, 320),
	('DEEP_CHARGE', 1, 80), ('DEEP_CHARGE', 2, 180), ('DEEP_CHARGE', 3, 320),
	('QUICK_HANDS', 1, 80), ('QUICK_HANDS', 2, 180), ('QUICK_HANDS', 3, 320),
	('SCAVENGER', 1, 80), ('SCAVENGER', 2, 180), ('SCAVENGER', 3, 320);
