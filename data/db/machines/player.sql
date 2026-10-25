-- The player's movement machine (feature/actors/player.gd).
--
-- All of it is here: three states, what each does every frame, which can
-- follow which, and what opens each way. The body stands on a floor seen
-- from above, so there is no up and no down in it: it stands, it walks the
-- way it is held, and it dashes the way it is going, and every state can
-- reach every other. What the player keeps is the words these rows are
-- written in — the actions a step takes and the senses a condition reads —
-- which `Player._setup_fsm` hands over by name.

INSERT INTO machines (id, start) VALUES ('player', 'idle');

INSERT INTO states (machine_id, id, label) VALUES
	('player', 'idle', 'Idle'),
	('player', 'walk', 'Walk'),
	('player', 'dash', 'Dash');

-- What each state does every frame, in order. The actions:
--
--   brake    slows to a stop
--   run      speeds up toward the way held, as hard as it is held
--   dash     a press starts a dash, when the stamina and the cooldown allow
--   rush     a dash under way carries the body until its time runs out
INSERT INTO steps (machine_id, state_id, position, action) VALUES
	('player', 'idle', 0, 'brake'),
	('player', 'idle', 1, 'dash'),

	('player', 'walk', 0, 'run'),
	('player', 'walk', 1, 'dash'),

	('player', 'dash', 0, 'rush');

-- What opens each way: a question about what the player senses on the frame.
--
--   dashing   a dash is under way
--   moving    a way is held: the stick is off its middle, or a key is down
--
-- Exactly one of these holds on any frame, whatever the senses say, and
-- tests/feature/machine_test tries them all to be sure — so the order a
-- state's ways are asked in only says which is asked first.
INSERT INTO conditions (machine_id, id, expression) VALUES
	('player', 'dashing',  'dashing'),
	('player', 'walking',  'not dashing and moving'),
	('player', 'standing', 'not dashing and not moving');

-- The ways out, asked in order: the first whose condition holds is taken.
-- Close a way by deleting its row.

-- Out of idle.
INSERT INTO transitions (machine_id, from_id, position, to_id, condition) VALUES
	('player', 'idle', 0, 'dash', 'dashing'),
	('player', 'idle', 1, 'walk', 'walking');

-- Out of a walk.
INSERT INTO transitions (machine_id, from_id, position, to_id, condition) VALUES
	('player', 'walk', 0, 'dash', 'dashing'),
	('player', 'walk', 1, 'idle', 'standing');

-- Out of a dash: back to the walk, or to a standstill.
INSERT INTO transitions (machine_id, from_id, position, to_id, condition) VALUES
	('player', 'dash', 0, 'walk', 'walking'),
	('player', 'dash', 1, 'idle', 'standing');
