-- The sound bank: a row a sound effect. See "A sound" in README.md.
--
-- Every sound is silent until it is made: give its `description` to Stable
-- Audio as the prompt, save what comes back at its `path` (a WAV; Godot
-- imports it on the next run of the editor or `--import`), set `use_flag` to
-- 'Y', and rebuild. A flag on a file that is not there warns at boot and
-- stays silent. Nothing is synthesised in code (app/audio/audio.gd).
--
-- The descriptions say what each sound was like when it was synthesised, so
-- the made ones keep the game's character; make them say something else to
-- change it.

INSERT INTO sounds (id, path, description, use_flag) VALUES
	('shoot', 'res://audio/sfx/shoot.wav', 'Short retro video game laser shot: a square-wave blip falling from high to low pitch over 120 milliseconds, a little crackle, 8-bit arcade style, dry, no reverb', 'N'),
	('zap', 'res://audio/sfx/zap.wav', 'Quick electric zap: a sharp sawtooth buzz sweeping down fast over 100 milliseconds, bright and thin, 8-bit arcade stun crackle, dry, no reverb', 'N'),
	('slash', 'res://audio/sfx/slash.wav', 'Short sword swing whoosh: 140 milliseconds of bright filtered noise fading fast, retro arcade blade slash, dry, no reverb', 'N'),
	('hit', 'res://audio/sfx/hit.wav', 'Punchy low impact thud: a square wave dropping in pitch over 90 milliseconds with gritty noise, retro game hit, dry, no reverb', 'N'),
	('explode', 'res://audio/sfx/explode.wav', 'Muffled low explosion: 360 milliseconds of dark filtered noise decaying, retro arcade blast, dry, no reverb', 'N'),
	('jump', 'res://audio/sfx/jump.wav', 'Quick rising jump blip: a soft triangle wave sweeping up an octave over 100 milliseconds, 8-bit platformer jump, dry, no reverb', 'N'),
	('dash', 'res://audio/sfx/dash.wav', 'Fast rush of air: 160 milliseconds of bright hissing noise fading quickly, retro game dash whoosh, dry, no reverb', 'N'),
	('hurt', 'res://audio/sfx/hurt.wav', 'Harsh hurt grunt: a sawtooth buzz falling in pitch over 220 milliseconds with light noise, retro game damage taken, dry, no reverb', 'N'),
	('death', 'res://audio/sfx/death.wav', 'Long falling death groan: a gritty sawtooth sweeping down to a low rumble over 600 milliseconds, retro arcade defeat, dry, no reverb', 'N'),
	('pickup', 'res://audio/sfx/pickup.wav', 'Bright rising pickup chime: a triangle wave climbing over 110 milliseconds, cheerful 8-bit coin collect, dry, no reverb', 'N'),
	('place', 'res://audio/sfx/place.wav', 'Tiny soft click: a triangle-wave tick of 50 milliseconds, a piece set down on a board, retro UI, dry, no reverb', 'N'),
	('erase', 'res://audio/sfx/erase.wav', 'Tiny soft falling tick: a triangle wave dropping over 60 milliseconds, a piece taken off a board, retro UI, dry, no reverb', 'N'),
	('ui', 'res://audio/sfx/ui.wav', 'Very short clean UI click: a single triangle-wave tone at 880 hertz for 35 milliseconds, menu press, dry, no reverb', 'N'),
	('deny', 'res://audio/sfx/deny.wav', 'Low buzzing refusal: a square wave dropping slightly over 130 milliseconds with a little grit, retro game error, dry, no reverb', 'N'),
	('extract', 'res://audio/sfx/extract.wav', 'Rising triumphant chime: a triangle wave sweeping up an octave over half a second, retro game level complete, dry, no reverb', 'N'),
	('parry', 'res://audio/sfx/parry.wav', 'Bright metallic ring: a triangle wave falling from high over 180 milliseconds, retro game parry clang, dry, no reverb', 'N'),
	('boss', 'res://audio/sfx/boss.wav', 'Deep ominous drone hit: a low sawtooth growl sinking over 800 milliseconds with grit, a boss changing form, dark, dry, no reverb', 'N'),
	('voice', 'res://audio/sfx/voice.wav', 'Tiny soft speech blip: a quiet square-wave beep of 40 milliseconds, text typing under dialogue, retro, dry, no reverb', 'N');
