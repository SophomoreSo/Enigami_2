-- SAGE, the Old Tinker at the bench in the sandbox (feature/world/sandbox.gd).
--
-- One INSERT per line, naming only the columns the line sets: what is left
-- out is NULL, and a NULL is the character's line_ default, or nothing at
-- all. A question is a line followed by its answers, in the order they are
-- offered. Every column is described in ../README.md.

INSERT INTO characters (id, name, sprite, player_name, start,
		line_speaker, line_emotion, line_voice, line_speed)
	VALUES ('SAGE', 'Old Tinker', 'wizzard_m', 'Knight', 'hello',
		'npc', 'neutral', 'low', 45);

INSERT INTO nodes (character_id, id, text, emotion, sfx, camera, next) VALUES
	('SAGE', 'hello', 'Ah, a new face. Nothing you break in here stays broken.',
		'happy', 'pickup', '{"focus": "both", "zoom": 1.5, "time": 0.6}', 'ask');

INSERT INTO nodes (character_id, id, text, emotion) VALUES
	('SAGE', 'ask', 'What would you like to know?', 'thinking');
INSERT INTO choices (character_id, node_id, position, text, next) VALUES
	('SAGE', 'ask', 0, 'How do skills work?', 'circuits'),
	('SAGE', 'ask', 1, 'What does charging do?', 'charge'),
	('SAGE', 'ask', 2, 'Who are you?', 'who'),
	('SAGE', 'ask', 3, 'Nothing. Bye.', NULL);

INSERT INTO nodes (character_id, id, text, next) VALUES
	('SAGE', 'circuits', 'Every skill is a circuit. The longer the path, the longer you wait for the next shot.',
		'ask_again');

INSERT INTO nodes (character_id, id, text, emotion, speed, next) VALUES
	('SAGE', 'charge', 'Build a loop, then hold the cast button. Charge buys the pulse more laps.',
		'happy', 55, 'ask_again');

INSERT INTO nodes (character_id, id, text, emotion, camera) VALUES
	('SAGE', 'who', 'I tinker. Mostly with things that explode.',
		'happy', '{"focus": "npc", "zoom": 2.0, "time": 0.4}');
INSERT INTO choices (character_id, node_id, position, text, next) VALUES
	('SAGE', 'who', 0, 'Sounds dangerous.', 'danger'),
	('SAGE', 'who', 1, 'Back to my questions.', 'ask');

INSERT INTO nodes (character_id, id, text, emotion, sfx, camera, next) VALUES
	('SAGE', 'danger', 'Only out on a raid. In here, the dummy won''t mind.',
		'surprised', 'explode', '{"focus": "npc", "zoom": 1.5, "shake": 8, "time": 0.2}', 'danger_reply');

INSERT INTO nodes (character_id, id, text, speaker, voice, camera, next) VALUES
	('SAGE', 'danger_reply', 'Noted. I''ll aim at the dummy.',
		'player', 'high', '{"focus": "player", "zoom": 1.5, "time": 0.4}', 'ask_again');

INSERT INTO nodes (character_id, id, text, emotion, camera) VALUES
	('SAGE', 'ask_again', 'Anything else?',
		'thinking', '{"focus": "both", "zoom": 1.5, "time": 0.4}');
INSERT INTO choices (character_id, node_id, position, text, next) VALUES
	('SAGE', 'ask_again', 0, 'How do skills work?', 'circuits'),
	('SAGE', 'ask_again', 1, 'What does charging do?', 'charge'),
	('SAGE', 'ask_again', 2, 'That''s all, thanks.', 'bye');

INSERT INTO nodes (character_id, id, text, emotion, camera) VALUES
	('SAGE', 'bye', 'Go on, then. Break something.', 'happy', 'reset');
