-- APPRENTICE, the Old Tinker's apprentice, by the wall at the bench's far end
-- (feature/world/sandbox.gd). They only talk free: every line below is a rule,
-- said in a bubble while the player goes on playing (see ../README.md, "Free
-- talk"). What they teach is footwork, and they watch for it: each lesson waits
-- for the move it asks for, and the move is what moves the lesson on.
--
-- The rules are grouped by the event they answer. Within an event, the one
-- with the most criteria that all hold is said, and a tie goes to the one
-- written first.

INSERT INTO characters (id, name, sprite, player_name, line_voice)
	VALUES ('APPRENTICE', 'Apprentice', 'dwarf_f', 'Knight', 'mid');

-- Kept for good: whether the footwork has all been taught.
-- Kept for a visit: what they have already said once since the player came in.
INSERT INTO facts (id, scope) VALUES
	('apprentice_taught', 'save'),
	('apprentice_waved', 'visit'),
	('apprentice_nagged', 'visit'),
	('apprentice_waited', 'visit'),
	('apprentice_winced', 'visit');

-- Raised to get the next lesson out of them, whichever it is by now.
INSERT INTO events (id) VALUES ('lesson');

-- ---- someone coming over ------------------------------------------------------

INSERT INTO rules (character_id, id, listens, once, text, emotion) VALUES
	('APPRENTICE', 'hello', 'near', 1, 'Oh! Somebody new. Come here, I''ll show you some footwork.', 'happy');

INSERT INTO rules (character_id, id, listens, text, emotion) VALUES
	('APPRENTICE', 'back', 'near', 'You''re back!', 'happy');
INSERT INTO criteria (character_id, rule_id, fact, op, value) VALUES
	('APPRENTICE', 'back', 'APPRENTICE.intro', '>=', 1),
	('APPRENTICE', 'back', 'apprentice_waved', '=', 0);
INSERT INTO changes (character_id, rule_id, fact, op, value) VALUES
	('APPRENTICE', 'back', 'apprentice_waved', 'set', 1);

-- ---- a press of interact ----------------------------------------------------

-- The first time: who they are, and an offer. The player answers.
INSERT INTO rules (character_id, id, listens, once, text, next) VALUES
	('APPRENTICE', 'intro', 'talk', 1, 'I''m meant to be sweeping. Want to learn some footwork instead?', 'intro_reply');
INSERT INTO rules (character_id, id, text, speaker, voice, next) VALUES
	('APPRENTICE', 'intro_reply', 'Sweeping sounds safer.', 'player', 'high', 'intro_more');
INSERT INTO rules (character_id, id, text, emotion, triggers) VALUES
	('APPRENTICE', 'intro_more', 'Nothing in here is safe. That''s the fun of it.', 'happy', 'lesson');

-- Every time after, until it has all been taught: back to the lesson they
-- were on. `intro` is spent, so this is what a press gets instead.
INSERT INTO rules (character_id, id, listens, text, triggers) VALUES
	('APPRENTICE', 'resume', 'talk', 'Where were we? Right, footwork.', 'lesson');
INSERT INTO criteria (character_id, rule_id, fact, op, value) VALUES
	('APPRENTICE', 'resume', 'APPRENTICE.intro', '>=', 1),
	('APPRENTICE', 'resume', 'apprentice_taught', '=', 0);

-- A kit left lying in a raid, once a visit — ahead of the lesson, since it
-- asks about more.
INSERT INTO rules (character_id, id, listens, text, emotion) VALUES
	('APPRENTICE', 'kit_nag', 'talk', 'Your kit''s still lying where you fell, you know. Same floor, same room.', 'thinking');
INSERT INTO criteria (character_id, rule_id, fact, op, value) VALUES
	('APPRENTICE', 'kit_nag', 'APPRENTICE.intro', '>=', 1),
	('APPRENTICE', 'kit_nag', 'kit_waiting', '=', 1),
	('APPRENTICE', 'kit_nag', 'apprentice_nagged', '=', 0);
INSERT INTO changes (character_id, rule_id, fact, op, value) VALUES
	('APPRENTICE', 'kit_nag', 'apprentice_nagged', 'set', 1);

-- Once it has all been taught, two last things, and then nothing: with
-- nothing left to say, the prompt over their head stops showing.
INSERT INTO rules (character_id, id, listens, once, text, emotion) VALUES
	('APPRENTICE', 'no_raids', 'talk', 1, 'You haven''t even been down yet? The gate''s in the hideout.', 'surprised');
INSERT INTO criteria (character_id, rule_id, fact, op, value) VALUES
	('APPRENTICE', 'no_raids', 'apprentice_taught', '=', 1),
	('APPRENTICE', 'no_raids', 'raids', '=', 0);

INSERT INTO rules (character_id, id, listens, once, text, emotion) VALUES
	('APPRENTICE', 'bye_for_now', 'talk', 1, 'That''s all I''ve got. Go and break something.', 'happy');
INSERT INTO criteria (character_id, rule_id, fact, op, value) VALUES
	('APPRENTICE', 'bye_for_now', 'apprentice_taught', '=', 1);

-- ---- the lessons --------------------------------------------------------------
--
-- Not `once`: which one is said is decided by what the player has done so far,
-- so asking again always gets the lesson they are on.

INSERT INTO rules (character_id, id, listens, text) VALUES
	('APPRENTICE', 'teach_double', 'lesson', 'Jump, then jump again while you''re still in the air.');
INSERT INTO criteria (character_id, rule_id, fact, op, value) VALUES
	('APPRENTICE', 'teach_double', 'double_jump', '=', 0);

INSERT INTO rules (character_id, id, listens, text) VALUES
	('APPRENTICE', 'teach_wall', 'lesson', 'Now a wall. Jump at one, and jump again as you touch it.');
INSERT INTO criteria (character_id, rule_id, fact, op, value) VALUES
	('APPRENTICE', 'teach_wall', 'double_jump', '>=', 1),
	('APPRENTICE', 'teach_wall', 'wall_kick', '=', 0);

INSERT INTO rules (character_id, id, listens, text) VALUES
	('APPRENTICE', 'teach_dash', 'lesson', 'Last one: dash. Sideways only, mind. Never up.');
INSERT INTO criteria (character_id, rule_id, fact, op, value) VALUES
	('APPRENTICE', 'teach_dash', 'double_jump', '>=', 1),
	('APPRENTICE', 'teach_dash', 'wall_kick', '>=', 1),
	('APPRENTICE', 'teach_dash', 'dash', '=', 0);

-- The end, taught all the way through...
INSERT INTO rules (character_id, id, listens, once, text, emotion) VALUES
	('APPRENTICE', 'lessons_done', 'lesson', 1, 'That''s everything I know. The Tinker knows the rest.', 'happy');
INSERT INTO criteria (character_id, rule_id, fact, op, value) VALUES
	('APPRENTICE', 'lessons_done', 'double_jump', '>=', 1),
	('APPRENTICE', 'lessons_done', 'wall_kick', '>=', 1),
	('APPRENTICE', 'lessons_done', 'dash', '>=', 1),
	('APPRENTICE', 'lessons_done', 'APPRENTICE.teach_dash', '>=', 1);
INSERT INTO changes (character_id, rule_id, fact, op, value) VALUES
	('APPRENTICE', 'lessons_done', 'apprentice_taught', 'set', 1);

-- ...or to someone who had done it all before being asked.
INSERT INTO rules (character_id, id, listens, once, text, emotion) VALUES
	('APPRENTICE', 'knew_it_all', 'lesson', 1, 'You know all this already, don''t you? Never mind me, then.', 'sad');
INSERT INTO criteria (character_id, rule_id, fact, op, value) VALUES
	('APPRENTICE', 'knew_it_all', 'double_jump', '>=', 1),
	('APPRENTICE', 'knew_it_all', 'wall_kick', '>=', 1),
	('APPRENTICE', 'knew_it_all', 'dash', '>=', 1);
INSERT INTO changes (character_id, rule_id, fact, op, value) VALUES
	('APPRENTICE', 'knew_it_all', 'apprentice_taught', 'set', 1);

-- ---- what they see the player do ----------------------------------------------

-- A move they asked for: praise, and the next lesson.
INSERT INTO rules (character_id, id, listens, once, text, emotion, triggers) VALUES
	('APPRENTICE', 'nice_double', 'double_jump', 1, 'There you go! The air holds you once.', 'happy', 'lesson');
INSERT INTO criteria (character_id, rule_id, fact, op, value) VALUES
	('APPRENTICE', 'nice_double', 'APPRENTICE.teach_double', '>=', 1);

INSERT INTO rules (character_id, id, listens, once, text, emotion, triggers) VALUES
	('APPRENTICE', 'nice_wall', 'wall_kick', 1, 'Ha! Walls are only floors standing up.', 'happy', 'lesson');
INSERT INTO criteria (character_id, rule_id, fact, op, value) VALUES
	('APPRENTICE', 'nice_wall', 'APPRENTICE.teach_wall', '>=', 1);

INSERT INTO rules (character_id, id, listens, once, text, emotion, triggers) VALUES
	('APPRENTICE', 'nice_dash', 'dash', 1, 'Quick! Too quick to hit, for a moment.', 'surprised', 'lesson');
INSERT INTO criteria (character_id, rule_id, fact, op, value) VALUES
	('APPRENTICE', 'nice_dash', 'APPRENTICE.teach_dash', '>=', 1);

-- A move they had not got round to yet.
INSERT INTO rules (character_id, id, listens, once, text, emotion, next) VALUES
	('APPRENTICE', 'show_off', 'double_jump', 1, 'Show-off.', 'angry', 'show_off_reply');
INSERT INTO criteria (character_id, rule_id, fact, op, value) VALUES
	('APPRENTICE', 'show_off', 'APPRENTICE.teach_double', '=', 0);
INSERT INTO rules (character_id, id, text, speaker, voice) VALUES
	('APPRENTICE', 'show_off_reply', 'Just stretching.', 'player', 'high');

INSERT INTO rules (character_id, id, listens, once, text, emotion) VALUES
	('APPRENTICE', 'winded', 'winded', 1, 'Out of breath? Four dashes to a full bar. Watch it under your health.', 'thinking'),
	('APPRENTICE', 'parried', 'parry', 1, 'A parry! Where did you learn that?', 'surprised');

INSERT INTO rules (character_id, id, listens, text, emotion) VALUES
	('APPRENTICE', 'ouch', 'hurt', 'Ouch! Keep moving, it helps.', 'scared');
INSERT INTO criteria (character_id, rule_id, fact, op, value) VALUES
	('APPRENTICE', 'ouch', 'apprentice_winced', '=', 0);
INSERT INTO changes (character_id, rule_id, fact, op, value) VALUES
	('APPRENTICE', 'ouch', 'apprentice_winced', 'set', 1);

-- ---- walking off halfway --------------------------------------------------------

INSERT INTO rules (character_id, id, listens, once, text, emotion) VALUES
	('APPRENTICE', 'wait', 'leave', 1, 'Hey! I wasn''t finished!', 'angry');

INSERT INTO rules (character_id, id, listens, text) VALUES
	('APPRENTICE', 'wait_again', 'leave', 'Fine. I''ll be here.');
INSERT INTO criteria (character_id, rule_id, fact, op, value) VALUES
	('APPRENTICE', 'wait_again', 'APPRENTICE.wait', '>=', 1),
	('APPRENTICE', 'wait_again', 'apprentice_waited', '=', 0);
INSERT INTO changes (character_id, rule_id, fact, op, value) VALUES
	('APPRENTICE', 'wait_again', 'apprentice_waited', 'set', 1);
