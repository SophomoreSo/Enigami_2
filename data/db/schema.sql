-- The tables in data/enigami.db.
--
-- Read by `Db` (app/db.gd), read-only, and never written by the game. Built
-- into data/enigami.db by build.sh here, together with every .sql in the
-- folders beside this file, inside one transaction with foreign keys on. How
-- to write a conversation into these tables is in README.md here; this file
-- is the contract the code reads against.
--
-- Two conventions the loader leans on, stated once:
--
--   * A column declared JSON holds a JSON document as text, and comes out of
--     `Db.records` parsed — an object, a list, a string — exactly as the same
--     value read out of a JSON file did; text that is not JSON comes out as
--     the text. That is how a line's `camera` reaches the picture as the
--     dictionary it expects, or as the word "reset".
--   * A NULL is a key that is not there. `Db.records` leaves it out, so a
--     line with no `sfx` has no `sfx`, rather than one that is null.

CREATE TABLE meta (
	key   TEXT PRIMARY KEY,
	value TEXT NOT NULL
);
-- `Db.SCHEMA_VERSION` in app/db.gd is the same number: bump both when a
-- change is one older code could not read. build.sh adds `source_hash`.
INSERT INTO meta (key, value) VALUES ('schema_version', '18');

-- How a portrait and the letters behave while a line is said: the ids
-- `Style.EMOTIONS` (graphics/style.gd) draws. A line naming one not here
-- fails the build, where a JSON file would quietly have read as neutral.
CREATE TABLE emotions (
	id TEXT PRIMARY KEY
);
INSERT INTO emotions (id) VALUES
	('neutral'), ('happy'), ('sad'), ('angry'), ('surprised'), ('thinking'), ('scared');

-- The register of the blip under the typing: the keys of `VOICE_PITCH` in
-- app/audio/audio_cues.gd, and `none` for no blip at all.
CREATE TABLE voices (
	id TEXT PRIMARY KEY
);
INSERT INTO voices (id) VALUES ('low'), ('mid'), ('high'), ('none');

-- Everyone with something to say: a conversation in the box, opening on
-- `start`, free talk in `rules` further down, or both.
--
-- The `line_` columns are what their lines say when a line does not say it
-- itself: `Dialogue` fills a line's missing `voice` from `line_voice`, and so
-- on for every column with that prefix — add one, and it is a default too.
CREATE TABLE characters (
	id           TEXT PRIMARY KEY CHECK (id <> '' AND id = upper(id)),
	name         TEXT NOT NULL CHECK (name <> ''),     -- on the tab when they speak
	sprite       TEXT NOT NULL CHECK (sprite <> ''),   -- their character in the atlas, in the world and on the portrait
	player_name  TEXT,                                 -- on the tab when the player speaks; NULL reads hud.dialogue.player
	start        TEXT,                                 -- the line a conversation in the box opens on; NULL: they only talk free
	line_speaker TEXT NOT NULL DEFAULT 'npc' CHECK (line_speaker IN ('npc', 'player')),
	line_emotion TEXT NOT NULL DEFAULT 'neutral' REFERENCES emotions (id),
	line_voice   TEXT NOT NULL DEFAULT 'low' REFERENCES voices (id),
	line_speed   INTEGER NOT NULL DEFAULT 45 CHECK (line_speed >= 1),   -- letters per second
	-- Checked when the build commits, since the line comes after the character.
	FOREIGN KEY (id, start) REFERENCES nodes (character_id, id) DEFERRABLE INITIALLY DEFERRED
);

-- The lines: the tree itself. Where a line leads is `next`, or the answers
-- in `choices` when it is a question; neither, and the conversation ends on
-- the press after it.
--
-- The rules read `text`, `next`, `speaker`, `name` and `speed`. Every other
-- column is for the picture and the sound bank, and reaches them as it is,
-- by column name: a new kind of direction is a column here and a reader
-- there, with nothing to change in between.
CREATE TABLE nodes (
	character_id TEXT NOT NULL REFERENCES characters (id) ON DELETE CASCADE,
	id           TEXT NOT NULL CHECK (id <> ''),
	text         TEXT NOT NULL CHECK (text <> ''),
	speaker      TEXT CHECK (speaker IN ('npc', 'player')),   -- NULL: the character's line_speaker
	name         TEXT,                                        -- overrides the name on the tab for this line
	speed        INTEGER CHECK (speed >= 1),                  -- letters per second; NULL: line_speed
	emotion      TEXT REFERENCES emotions (id),               -- NULL: line_emotion
	sprite       TEXT,                                        -- swaps the portrait for this line
	camera       JSON CHECK (camera IS NULL OR camera = 'reset' OR json_valid(camera)),
	                                                          -- {"focus", "zoom", "shake", "time"}, or reset
	sfx          TEXT REFERENCES sounds (id) DEFERRABLE INITIALLY DEFERRED,  -- a sound of the bank (`sounds`), as the line starts
	voice        TEXT REFERENCES voices (id),                 -- NULL: line_voice
	next         TEXT,                                        -- the line a press moves on to; NULL ends, unless there are choices
	PRIMARY KEY (character_id, id),
	FOREIGN KEY (character_id, next) REFERENCES nodes (character_id, id) DEFERRABLE INITIALLY DEFERRED
);

-- A line in the box belongs to somebody the box opens on. A character with no
-- `start` only talks free, and a line in the box for them is one that nothing
-- will ever reach.
CREATE TRIGGER nodes_need_a_start
BEFORE INSERT ON nodes
WHEN (SELECT start FROM characters WHERE id = NEW.character_id) IS NULL
BEGIN
	SELECT RAISE(ABORT, 'a line in the box for somebody the box never opens on');
END;

-- The answers to a question, in `position` order. `next` NULL ends the
-- conversation on that answer.
CREATE TABLE choices (
	character_id TEXT NOT NULL,
	node_id      TEXT NOT NULL,
	position     INTEGER NOT NULL CHECK (position >= 0),
	text         TEXT NOT NULL CHECK (text <> ''),
	next         TEXT,
	PRIMARY KEY (character_id, node_id, position),
	FOREIGN KEY (character_id, node_id) REFERENCES nodes (character_id, id) ON DELETE CASCADE,
	FOREIGN KEY (character_id, next) REFERENCES nodes (character_id, id) DEFERRABLE INITIALLY DEFERRED
);

-- ---- free talk ----------------------------------------------------------------
--
-- The other way a character talks: free, in a bubble over whoever is
-- speaking, while the player goes on playing. Nobody is held still, a line
-- moves on by itself once it has had time to be read, and nothing follows a
-- tree. Every line is a rule: the event it answers, the criteria the facts
-- must meet for it, and the changes it makes to them once it has been said.
-- Of the rules an event could get, the one with the most criteria that all
-- hold is said — the most specific thing there is to say. It is aarthificial's
-- Typewriter (Legacy devlog #23), after Elan Ruskin's dynamic dialog for
-- Valve. `FreeTalk` (story/rules/free_talk.gd) plays it; how to write it is in
-- README.md here.

-- What the characters know: whole numbers by name, 0 until something sets
-- them. `scope` is how long one is kept —
--
--   save   with the profile, for good (`GameState.memory`)
--   visit  until the player leaves the world they are in
--   game   what the game counts for itself, read off the profile each time it
--          is asked (`GameState.facts`); a line may ask about one and never
--          change it
--
-- Every event and every rule is a fact too, declared by the triggers below:
-- how many times the event has been raised, or the line said — an event
-- under its own name, a rule as `<CHARACTER>.<rule>`. A name means one thing,
-- so a fact that shares one with an event fails the build.
CREATE TABLE facts (
	id    TEXT PRIMARY KEY CHECK (id <> ''),
	scope TEXT NOT NULL CHECK (scope IN ('save', 'visit', 'game'))
);
-- The keys of `GameState.facts()` (feature/core/game_state.gd), and
-- tests/story/free_talk_test fails on one that is not.
INSERT INTO facts (id, scope) VALUES
	('raids', 'game'), ('escapes', 'game'), ('deaths', 'game'), ('kills', 'game'),
	('best_haul', 'game'), ('scrap', 'game'), ('kit_waiting', 'game');

-- What a line can answer. An event with a `cue` is a moment the game already
-- announces (app/cues.gd), heard by every free talker the player is in
-- earshot of: that cue, whenever it carries everything `match` says. An event
-- with none is raised by the game — the three below, by name — or by a line
-- that `triggers` it.
CREATE TABLE events (
	id    TEXT PRIMARY KEY CHECK (id <> '' AND id = lower(id)),
	cue   TEXT CHECK (cue <> ''),
	match JSON CHECK (match IS NULL OR (json_valid(match) AND json_type(match) = 'object')),
	CHECK (match IS NULL OR cue IS NOT NULL)
);

CREATE TRIGGER events_are_facts
AFTER INSERT ON events
BEGIN
	INSERT INTO facts (id, scope) VALUES (NEW.id, 'save');
END;

-- talk: a press of interact beside them while nothing is being said.
-- near: the player coming into earshot.
-- leave: the player going out of it, halfway through talk they started.
INSERT INTO events (id) VALUES ('talk'), ('near'), ('leave');

-- The moments a free talker notices. Each is a cue `feature/` sends, and
-- tests/story/free_talk_test fails on one it does not. When a cue is more
-- than one of these, the one that matches more of it is answered first.
INSERT INTO events (id, cue, match) VALUES
	('dash',        'dash',    NULL),
	('winded',      'refused', '{"kind": "stamina"}'),
	('parry',       'parry',   NULL),
	('strike',      'hit',     '{"target_team": 1}'),
	('kill',        'hit',     '{"target_team": 1, "killed": true}'),
	('hurt',        'hurt',    '{"team": 0}');

-- The lines. `speaker` says whose head the bubble is over; the columns shared
-- with `nodes` mean what they mean there, and fall back on the character's
-- `line_` defaults the same way.
CREATE TABLE rules (
	character_id TEXT NOT NULL REFERENCES characters (id) ON DELETE CASCADE,
	id           TEXT NOT NULL CHECK (id <> ''),
	listens      TEXT REFERENCES events (id),                 -- the event it answers; NULL: said only as another's `next`
	once         INTEGER NOT NULL DEFAULT 0 CHECK (once IN (0, 1)),   -- 1: never said twice
	text         TEXT NOT NULL CHECK (text <> ''),
	speaker      TEXT CHECK (speaker IN ('npc', 'player')),   -- NULL: the character's line_speaker
	speed        INTEGER CHECK (speed >= 1),                  -- letters per second; NULL: line_speed
	emotion      TEXT REFERENCES emotions (id),               -- NULL: line_emotion
	sfx          TEXT REFERENCES sounds (id) DEFERRABLE INITIALLY DEFERRED,  -- a sound of the bank (`sounds`), as the line starts
	voice        TEXT REFERENCES voices (id),                 -- NULL: line_voice
	hold         REAL CHECK (hold >= 0),                      -- seconds it stays up once it is out; NULL: long enough to read
	next         TEXT,                                        -- said after it, whatever the facts
	triggers     TEXT REFERENCES events (id),                 -- raised after it: whatever answers best is said next
	PRIMARY KEY (character_id, id),
	FOREIGN KEY (character_id, next) REFERENCES rules (character_id, id) DEFERRABLE INITIALLY DEFERRED,
	CHECK (next IS NULL OR triggers IS NULL)
);

CREATE TRIGGER rules_are_facts
AFTER INSERT ON rules
BEGIN
	INSERT INTO facts (id, scope) VALUES (NEW.character_id || '.' || NEW.id, 'save');
END;

-- What the facts must be for a rule to be said: every row of it at once.
CREATE TABLE criteria (
	character_id TEXT NOT NULL,
	rule_id      TEXT NOT NULL,
	fact         TEXT NOT NULL REFERENCES facts (id) DEFERRABLE INITIALLY DEFERRED,
	op           TEXT NOT NULL DEFAULT '=' CHECK (op IN ('=', '<>', '<', '<=', '>', '>=')),
	value        INTEGER NOT NULL CHECK (typeof(value) = 'integer'),
	FOREIGN KEY (character_id, rule_id) REFERENCES rules (character_id, id) ON DELETE CASCADE
);

-- What a rule does to the facts once it has been said: `set` one to the
-- value, or `add` the value to it — a negative one takes away.
CREATE TABLE changes (
	character_id TEXT NOT NULL,
	rule_id      TEXT NOT NULL,
	fact         TEXT NOT NULL REFERENCES facts (id) DEFERRABLE INITIALLY DEFERRED,
	op           TEXT NOT NULL DEFAULT 'set' CHECK (op IN ('set', 'add')),
	value        INTEGER NOT NULL CHECK (typeof(value) = 'integer'),
	FOREIGN KEY (character_id, rule_id) REFERENCES rules (character_id, id) ON DELETE CASCADE
);

-- What the game counts, it counts: a line may ask, and never change it.
CREATE TRIGGER changes_leave_game_facts_alone
BEFORE INSERT ON changes
WHEN (SELECT scope FROM facts WHERE id = NEW.fact) = 'game'
BEGIN
	SELECT RAISE(ABORT, 'a line cannot change a fact the game counts for itself');
END;

-- ---- state machines --------------------------------------------------------
--
-- The player's movement is a state machine (feature/actors/player.gd), and
-- all of it lives here: the states, what each one does every frame, the graph
-- of ways out of each, and what opens every way. The owner keeps only the
-- words the rows are written in, and hands them to `Machine.build` by name:
-- its *actions*, which a state's steps take — each one thing the body does on
-- a frame — and its *senses*, which a condition reads. A step naming an
-- action the owner does not have, or a condition reading a sense it does not
-- have, is reported by `Machine.build` and fails tests/feature/machine_test.

CREATE TABLE machines (
	id    TEXT PRIMARY KEY CHECK (id <> ''),
	start TEXT NOT NULL,   -- the state it begins in
	FOREIGN KEY (id, start) REFERENCES states (machine_id, id) DEFERRABLE INITIALLY DEFERRED
);

CREATE TABLE states (
	machine_id TEXT NOT NULL REFERENCES machines (id) ON DELETE CASCADE,
	id         TEXT NOT NULL CHECK (id <> ''),
	label      TEXT NOT NULL CHECK (label <> ''),   -- what `state_name()` reports; the debug log and the tests read it
	PRIMARY KEY (machine_id, id)
);

-- What a state does each frame: its steps, taken in `position` order, each
-- an action by the owner's name for it. A state with no steps does nothing,
-- and `Machine.problems` says so.
CREATE TABLE steps (
	machine_id TEXT NOT NULL,
	state_id   TEXT NOT NULL,
	position   INTEGER NOT NULL CHECK (position >= 0),
	action     TEXT NOT NULL CHECK (action <> ''),
	PRIMARY KEY (machine_id, state_id, position),
	FOREIGN KEY (machine_id, state_id) REFERENCES states (machine_id, id) ON DELETE CASCADE
);

-- What opens a way out: a question about the owner's senses, by name, that
-- answers true or false — `not dashing and on_floor and dir != 0`. It is read
-- as Godot's `Expression`: `and` `or` `not`, comparisons, arithmetic, a
-- sense's own fields (`velocity.y`) and the engine's functions (`abs(dir)`),
-- over the senses and nothing else.
CREATE TABLE conditions (
	machine_id TEXT NOT NULL REFERENCES machines (id) ON DELETE CASCADE,
	id         TEXT NOT NULL CHECK (id <> ''),
	expression TEXT NOT NULL CHECK (trim(expression) <> ''),
	PRIMARY KEY (machine_id, id)
);

-- The graph. The ways out of a state are tried in `position` order and the
-- first whose `condition` holds is taken. Rows sharing a `from_id` and a
-- `position` are one way out that splits between their `to_id`s by
-- `probability`, which then add up to 1; one row, and the way is certain.
CREATE TABLE transitions (
	machine_id  TEXT NOT NULL,
	from_id     TEXT NOT NULL,
	position    INTEGER NOT NULL CHECK (position >= 0),
	to_id       TEXT NOT NULL,
	condition   TEXT NOT NULL CHECK (condition <> ''),   -- whether the way is open: the id of one of the machine's conditions
	probability REAL NOT NULL DEFAULT 1.0 CHECK (probability > 0.0 AND probability <= 1.0),
	PRIMARY KEY (machine_id, from_id, position, to_id),
	FOREIGN KEY (machine_id, from_id) REFERENCES states (machine_id, id) ON DELETE CASCADE,
	FOREIGN KEY (machine_id, to_id) REFERENCES states (machine_id, id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
	FOREIGN KEY (machine_id, condition) REFERENCES conditions (machine_id, id) DEFERRABLE INITIALLY DEFERRED
);

-- One condition per way out: the rows of a split agree on when it is open.
CREATE TRIGGER transitions_one_condition_in
BEFORE INSERT ON transitions
WHEN EXISTS (SELECT 1 FROM transitions t
	WHERE t.machine_id = NEW.machine_id AND t.from_id = NEW.from_id
		AND t.position = NEW.position AND t.condition <> NEW.condition)
BEGIN
	SELECT RAISE(ABORT, 'the rows of one way out name different conditions');
END;

CREATE TRIGGER transitions_one_condition_up
BEFORE UPDATE OF machine_id, from_id, position, condition ON transitions
WHEN EXISTS (SELECT 1 FROM transitions t
	WHERE t.machine_id = NEW.machine_id AND t.from_id = NEW.from_id
		AND t.position = NEW.position AND t.condition <> NEW.condition
		AND NOT (t.to_id = NEW.to_id AND t.from_id = OLD.from_id AND t.position = OLD.position))
BEGIN
	SELECT RAISE(ABORT, 'the rows of one way out name different conditions');
END;

-- ---- parts and boards ------------------------------------------------------
--
-- The parts a skill board is built from (circuit/components.gd), and the
-- boards the game ships with (feature/core/boards.gd). A part is its numbers —
-- heat, cells, the sides its flow leaves by — and what it does to a flow as
-- the flow enters it: effects on the payload the flow carries
-- (circuit/payload.gd). What an effect *means* is code, `SkillRunner._apply`,
-- and so is what a form, a trigger or a flag does once an attack carries it.
-- What a part looks like is graphics/style.gd's, keyed by the same id.
--
-- Where a flow starts is not a part of its own: every board has a root, one
-- of its parts — a weapon's own DASHSLASH, a monster's SLASH — and that is the
-- source of every cycle. Nor is where it becomes an attack: that is the
-- board's way out, the middle of its right edge (`SkillBoard.way_out`). INPUT
-- and OUTPUT, which used to be those two, are retired and keep their numbers.

-- The kinds of part, which the palette groups them by, in the order it lays
-- their blocks out (`Components.categories`). A kind no part is of has no block.
CREATE TABLE categories (
	id TEXT PRIMARY KEY CHECK (id <> '' AND id = lower(id))
);

-- Every number a part has ever had in a shared code (circuit/board_code.gd).
-- A code written today has to mean the same board next year, so a number is
-- a part's for good: **only ever add to the end**. A part that is retired
-- keeps its number, and one that is renamed hands its number to its new id —
-- unless the new id has a number of its own already, which is two parts made
-- one: then the old id keeps its number, and a code reads it as the new id
-- (`renamed_parts`, `BoardCode.decode`).
-- tests/circuit/code_test holds every number already given out to its part.
CREATE TABLE codes (
	code INTEGER PRIMARY KEY CHECK (code BETWEEN 0 AND 63),   -- six bits in a code
	id   TEXT NOT NULL UNIQUE CHECK (id <> '' AND id = upper(id))
);

-- The parts, in the order the palette shows them. Every one has a number.
CREATE TABLE parts (
	id          TEXT PRIMARY KEY CHECK (id <> '' AND id = upper(id)),
	name        TEXT NOT NULL CHECK (name <> ''),                    -- the English, under localization/<lang>/parts.json
	category    TEXT NOT NULL REFERENCES categories (id) DEFERRABLE INITIALLY DEFERRED,
	heat        REAL NOT NULL DEFAULT 0 CHECK (heat >= 0),           -- added to the cooldown of a cast that passes through
	cells       INTEGER NOT NULL DEFAULT 1 CHECK (cells IN (1, 2)),  -- its footprint, and a tick for each cell
	stack_limit INTEGER CHECK (stack_limit >= 1),                    -- how many of it one flow can stack; past it the part costs its heat and does nothing. NULL: any number
	tag         TEXT CHECK (tag IN ('ranged', 'melee', 'area', 'mobility', 'trigger')),   -- what it makes a board, for a weapon to accept
	description TEXT NOT NULL CHECK (description <> ''),             -- the English, too
	FOREIGN KEY (id) REFERENCES codes (id) DEFERRABLE INITIALLY DEFERRED
);

-- The sides a part's flow leaves by, as the part faces east, in the order the
-- flows leave. A part takes flow on every other side — inputs are never
-- declared — so rotation decides where a flow goes, never where it may come
-- from; the root takes flow like any other part, so a ring may run back
-- through it. A `branch` is a trigger's second way out, and carries its
-- payload.
CREATE TABLE ports (
	part_id TEXT NOT NULL REFERENCES parts (id) ON DELETE CASCADE,
	side    TEXT NOT NULL CHECK (side IN ('E', 'S', 'W', 'N')),
	kind    TEXT NOT NULL DEFAULT 'flow' CHECK (kind IN ('flow', 'branch')),
	PRIMARY KEY (part_id, side)
);

-- One branch to a part.
CREATE UNIQUE INDEX ports_one_branch ON ports (part_id) WHERE kind = 'branch';

-- What a part does to a flow as the flow enters it, in `position` order. Most
-- change one field of the payload the flow carries:
--
--   set       the field becomes `value`
--   add       `value` is added to it
--   multiply  it is multiplied by `value`
--   toggle    a flag flips
--   include   `value` joins a list, once
--
-- and two change the fight instead, and name no field:
--
--   dilate    the world and the board slow for `value` seconds
--   guard     a guard window opens for `value` seconds; a hit absorbed in it
--             runs the part's branch
--
-- and one turns the part before it inside out, and names no field or value:
--
--   invert    what the part the flow came from did is taken back, and its
--             rows of `inversions` are done instead
--
-- `value` is read as JSON — 8, 1.6, 'true' — and a word may go without its
-- quotes: 'FIRE'. Which fields a payload has, and what each holds, is the
-- payload's to say: `Components` holds every row to it as it reads them, and
-- tests/circuit/parts_test fails on a row that does not fit.
--
-- An `add` or a `multiply` may be worth more the more of its part a flow has
-- stacked: `per_stack` is added to `value` for every one of the part the flow
-- has already been through, so the second adds `value + per_stack` and the
-- third `value + 2 × per_stack`. NULL: every one is worth the same.
CREATE TABLE effects (
	part_id   TEXT NOT NULL REFERENCES parts (id) ON DELETE CASCADE,
	position  INTEGER NOT NULL CHECK (position >= 0),
	field     TEXT CHECK (field <> ''),
	op        TEXT NOT NULL CHECK (op IN ('set', 'add', 'multiply', 'toggle', 'include', 'dilate', 'guard', 'invert')),
	value     JSON,
	per_stack REAL,
	PRIMARY KEY (part_id, position),
	CHECK ((field IS NULL) = (op IN ('dilate', 'guard', 'invert'))),
	CHECK ((value IS NULL) = (op IN ('toggle', 'invert'))),
	CHECK (per_stack IS NULL OR op IN ('add', 'multiply'))
);

-- What a part does instead when an INVERT comes straight after it: rows like
-- its effects, in `position` order, done once the runner has put back every
-- field its effects changed. They change fields only — a part's opposite is
-- what the struck enemy gets instead (a heal for its damage, a cleanse for its
-- burn), or the attack made the other way (smaller for SIZE) — so the ops are
-- the five that do. A part with no rows here has no opposite, and an INVERT
-- after it does nothing (`SkillRunner._invert`).
CREATE TABLE inversions (
	part_id  TEXT NOT NULL REFERENCES parts (id) ON DELETE CASCADE,
	position INTEGER NOT NULL CHECK (position >= 0),
	field    TEXT NOT NULL CHECK (field <> ''),
	op       TEXT NOT NULL CHECK (op IN ('set', 'add', 'multiply', 'toggle', 'include')),
	value    JSON,
	PRIMARY KEY (part_id, position),
	CHECK ((value IS NULL) = (op = 'toggle'))
);

-- Parts the game no longer has. They keep their numbers, and a board saved
-- or shared while they were in still reads, with each of them left out
-- (`SkillBoard.deserialize`, `BoardCode.decode`).
CREATE TABLE retired_parts (
	id TEXT PRIMARY KEY REFERENCES codes (id)
);

-- Parts the game still has under a new id. A board, a stash or a drop saved
-- under the old id reads back under the new one (`Components.current_id`).
CREATE TABLE renamed_parts (
	old_id TEXT PRIMARY KEY CHECK (old_id <> '' AND old_id = upper(old_id)),
	new_id TEXT NOT NULL REFERENCES parts (id) DEFERRABLE INITIALLY DEFERRED
);

-- The boards the game ships with: each weapon's own graph as a new profile
-- gets it, every monster's, the dragon test's. What a player builds onto a
-- weapon's graph is theirs, and lives in the save. Which part feeds which is
-- not written down: the parts' ports and the way each faces already say it,
-- and `SkillBoard.trace` walks it. Every board marks one of its parts as its
-- root, where its flow starts; feature/core/boards.gd refuses one without. A
-- flow goes from a part into the part beside it, and leaves the board by the
-- middle of its right edge, so a board is a chain from its root to there —
-- tests/feature/boards_test fails one whose flow runs out anywhere else.
CREATE TABLE boards (
	id     TEXT PRIMARY KEY CHECK (id <> '' AND id = lower(id)),
	width  INTEGER NOT NULL DEFAULT 7 CHECK (width BETWEEN 1 AND 16),     -- the most a shared code carries
	height INTEGER NOT NULL DEFAULT 5 CHECK (height BETWEEN 1 AND 16),
	name   TEXT CHECK (name <> '')   -- what it is called when whoever builds it does not say
);

-- A part on a board: the cell it is placed in, and the way its east side
-- faces. A two-cell part covers the next cell that way too.
CREATE TABLE board_parts (
	board_id TEXT NOT NULL REFERENCES boards (id) ON DELETE CASCADE,
	x        INTEGER NOT NULL CHECK (x >= 0),
	y        INTEGER NOT NULL CHECK (y >= 0),
	part     TEXT NOT NULL REFERENCES parts (id) DEFERRABLE INITIALLY DEFERRED,
	facing   TEXT NOT NULL DEFAULT 'E' CHECK (facing IN ('E', 'S', 'W', 'N')),
	root     INTEGER NOT NULL DEFAULT 0 CHECK (root IN (0, 1)),   -- 1 on the part the flow starts in
	PRIMARY KEY (board_id, x, y)
);

-- One root to a board.
CREATE UNIQUE INDEX board_parts_one_root ON board_parts (board_id) WHERE root = 1;

-- ---- menus -----------------------------------------------------------------
--
-- The menus a screen is made of: the title's, the save slots behind its
-- START, its SETTINGS and the two pages behind them, and PAUSED. A menu is
-- its name — the heading over it, and what a button opening it says — and
-- its items, in `position` order, each one thing: the menu it `opens`, or an
-- act of the screen that shows it, by the item's id. The screen keeps only
-- the acts, handed to `Menus` (graphics/ui/menus.gd) by name the way the
-- player hands `Machine` its actions, and lays the items out: one that is a
-- way out of the menu (`exit`) sits pinned at its foot. What an item looks
-- like — its colour, the mark over a tile — is the screen's, keyed by the
-- item's id, the way a part's look is `Style`'s.
--
-- The English here is the fallback under localization/<lang>/menu.json, by
-- id: `menu.<menu>.heading` for a name, `menu.<menu>.<item>` for an item's
-- text. tests/shared/loc_test fails if the two drift.

CREATE TABLE menus (
	id   TEXT PRIMARY KEY CHECK (id <> '' AND id = lower(id)),
	name TEXT CHECK (name <> ''),  -- the heading over it; NULL for one with none, the title's, which the seal heads
	note TEXT CHECK (note <> '')   -- a line under the heading, for a question that says what answering it costs; NULL: none
);

CREATE TABLE menu_items (
	menu_id  TEXT NOT NULL REFERENCES menus (id) ON DELETE CASCADE,
	id       TEXT NOT NULL CHECK (id <> ''),
	position INTEGER NOT NULL CHECK (position >= 0),
	text     TEXT CHECK (text <> ''),      -- what it says; NULL: the name of the menu it opens
	opens    TEXT REFERENCES menus (id),   -- the menu it leads to; NULL: an act of the screen's, by the item's id
	exit     INTEGER NOT NULL DEFAULT 0 CHECK (exit IN (0, 1)),   -- 1: a way out of the menu, gathered at its foot
	PRIMARY KEY (menu_id, id),
	UNIQUE (menu_id, position),
	CHECK (text IS NOT NULL OR opens IS NOT NULL)
);

-- An item with no text of its own says the name of the menu it opens, so
-- that menu has to have one — and to be written before it, since this asks
-- as the item goes in.
CREATE TRIGGER menu_items_say_something
BEFORE INSERT ON menu_items
WHEN NEW.text IS NULL AND (SELECT name FROM menus WHERE id = NEW.opens) IS NULL
BEGIN
	SELECT RAISE(ABORT, 'an item with no text of its own opens a menu with no name');
END;

-- ---- foliage ---------------------------------------------------------------
--
-- What grows on the rooms' floors — grass, flowers, a bush — as `Foliage`
-- (graphics/foliage.gd) draws it: aarthificial's interactive foliage, a
-- picture whose pixels sway in the wind and bend where something moving has
-- left its speed in the velocity buffer (graphics/velocity_buffer.gd). A kind
-- is how it is drawn and how it moves: which picture it is (`form`), which
-- way it gives (`sway` — `along` the ground and lower as it leans, as grass
-- and flowers do, or `any` way, as a bush does), how tall it stands, how
-- thickly, and how far a push or the wind moves its tip. How the air itself
-- springs back — how stiff, how damped, how far a push spreads — is the
-- buffer's, and shared by everything that reads it, so it stays code; and so
-- does the look: a kind's colours are graphics/style.gd's, by the same id, and
-- a kind with none yet grows in grass's.

CREATE TABLE foliage (
	id       TEXT PRIMARY KEY CHECK (id <> '' AND id = lower(id)),
	form     TEXT NOT NULL CHECK (form IN ('blades', 'flowers', 'bush')),  -- the picture: blades of grass, flowers on stems, a bush on its stems
	sway     TEXT NOT NULL CHECK (sway IN ('along', 'any')),               -- along the ground, lower as it leans; or any way at all
	shortest INTEGER NOT NULL CHECK (shortest >= 1),                       -- the shortest plant, in pixels of the picture
	tallest  INTEGER NOT NULL CHECK (tallest >= shortest),                 -- and the tallest
	density  REAL NOT NULL CHECK (density > 0 AND density <= 1),           -- the share of a patch's columns a plant stands in
	push     REAL NOT NULL CHECK (push >= 0),                              -- how far a full push moves a tip, in pixels
	wind     REAL NOT NULL CHECK (wind >= 0)                               -- how far the wind sways one, in pixels
);

-- What a room grows: of each kind, how many patches and how long each is, in
-- cells of the room's grid. Where each grows is rolled by `RoomView` from the
-- room's own seed — on a floor with open air over it, never on spikes and
-- never at the room's edge — so a room looks the same every time. Kinds are
-- drawn in the order they are written here, each over the last.
CREATE TABLE growths (
	foliage  TEXT PRIMARY KEY REFERENCES foliage (id) ON DELETE CASCADE,
	fewest   INTEGER NOT NULL DEFAULT 0 CHECK (fewest >= 0),
	most     INTEGER NOT NULL CHECK (most >= fewest),
	shortest INTEGER NOT NULL CHECK (shortest >= 1),
	longest  INTEGER NOT NULL CHECK (longest >= shortest)
);

-- ---- lights ----------------------------------------------------------------
--
-- The light a shining thing gives — a lantern, a fire, a lightbulb, a torch,
-- a strip of neon — as the deferred lights (graphics/lighting.gd) add it to
-- the picture. A light is not a thing of its own in the world: it is a
-- property of whatever gives it (`Shine`, graphics/shine.gd), and a kind of
-- shining thing is a row here, which every thing of that kind gives. The
-- types are Blender's:
--
--   point   light every way from a point, as bright as it gets over `radius`
--           and dimming to nothing at `reach` past it
--   sun     the same light over everything, from one way and no distance at
--           all: `direction` is the way it travels
--   spot    a point's light in a cone `spot_size` wide, pointing
--           `direction`, fading to its edge over `spot_blend` of it
--   area    light from the whole of a shape — a rectangle or an ellipse
--           `size_x` across the way it points and `size_y` along it —
--           dimming to nothing at `reach` from its edge, and leaving it
--           `spread` wide about `direction`: 180 its face, 360 all round
--
-- A column a type has no use for is left as its default.

CREATE TABLE lights (
	id         TEXT PRIMARY KEY CHECK (id <> '' AND id = lower(id)),
	type       TEXT NOT NULL CHECK (type IN ('point', 'sun', 'spot', 'area')),
	color      TEXT NOT NULL DEFAULT '#ffffff'
	           CHECK (length(color) = 7 AND color GLOB '#[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]'),
	power      REAL NOT NULL DEFAULT 1 CHECK (power >= 0),                          -- 1 shows what it lights twice as bright as the room's own light would
	radius     REAL NOT NULL DEFAULT 0 CHECK (radius >= 0),                         -- point, spot: how big what gives it is, in world units
	reach      REAL NOT NULL DEFAULT 160 CHECK (reach > 0),                         -- point, spot, area: how far it goes past that, in world units
	falloff    REAL NOT NULL DEFAULT 2 CHECK (falloff > 0),                         -- how it dims over its reach: 1 in a straight line, 2 easing into nothing
	direction  REAL NOT NULL DEFAULT 90,                                            -- sun, spot, area: the way it shines, in degrees: 0 right, 90 down, 270 up
	spot_size  REAL NOT NULL DEFAULT 45 CHECK (spot_size > 0 AND spot_size <= 360),  -- spot: how wide its cone is, in degrees
	spot_blend REAL NOT NULL DEFAULT 0.15 CHECK (spot_blend BETWEEN 0 AND 1),        -- spot: the share of the cone it fades to its edge over
	shape      TEXT NOT NULL DEFAULT 'rectangle' CHECK (shape IN ('rectangle', 'ellipse')),  -- area
	size_x     REAL NOT NULL DEFAULT 32 CHECK (size_x >= 0),                        -- area: across the way it shines, in world units
	size_y     REAL NOT NULL DEFAULT 4 CHECK (size_y >= 0),                         -- area: along the way it shines
	spread     REAL NOT NULL DEFAULT 180 CHECK (spread > 0 AND spread <= 360),      -- area: how wide it leaves the shape, in degrees
	volume     REAL NOT NULL DEFAULT 0 CHECK (volume >= 0),                         -- how much of it the air in front of the picture catches
	shadows    INTEGER NOT NULL DEFAULT 1 CHECK (shadows IN (0, 1)),                -- whether what stands in it throws a shadow
	flicker    REAL NOT NULL DEFAULT 0 CHECK (flicker BETWEEN 0 AND 1),             -- how much it wavers, the way a flame does: 0 steady
	x          REAL NOT NULL DEFAULT 0,                                             -- where it is from the thing that gives it, in world units
	y          REAL NOT NULL DEFAULT 0
);

-- ---- perks -----------------------------------------------------------------
-- What a player buys for themselves with gold and keeps, a step at a time
-- (perks/rules, `Perks`). A perk raises one of the player's own numbers — its
-- `stat`, by the name the rules ask `GameState.boost` for it — by `per_step`
-- for every step bought: `max_health`, `max_stamina` and `max_mana` in points,
-- `max_charge` in the life a hold can buy, `move_speed`, `charge_speed` and
-- `gold` as a share more, `cast_speed` as a share off the wait between casts. The `name` and `description` are the English, laid
-- under localization/<lang>/perks.json.
CREATE TABLE perks (
	id          TEXT PRIMARY KEY CHECK (id <> '' AND id = upper(id)),
	name        TEXT NOT NULL CHECK (name <> ''),
	stat        TEXT NOT NULL CHECK (stat IN ('max_health', 'max_stamina', 'max_mana',
	            'max_charge', 'move_speed', 'charge_speed', 'cast_speed', 'gold')),
	per_step    REAL NOT NULL CHECK (per_step > 0),
	description TEXT NOT NULL CHECK (description <> '')
);

-- A perk's steps, from the first, and what each costs in gold. A step is only
-- ever bought after the one before it, so they run 1, 2, 3 with nothing missed;
-- tests/perks/perks_test holds them to it.
CREATE TABLE perk_steps (
	perk_id TEXT NOT NULL REFERENCES perks (id) ON DELETE CASCADE,
	step    INTEGER NOT NULL CHECK (step >= 1),
	cost    INTEGER NOT NULL CHECK (cost > 0),
	PRIMARY KEY (perk_id, step)
);

-- ---- maps ------------------------------------------------------------------
-- The rooms made in the map creator (`MapMaker`) that the game ships with: a
-- map is its level's info, its layers, and each layer's grid of cells, a row
-- of the grid a row here. `Maps` (feature/world/maps.gd) reads them, and the
-- maps a player makes are kept in the same three tables in a database of
-- their own, `user://maps.db`, which the game writes. Run from the project,
-- the creator writes each map it saves as a .sql file under maps/ as well,
-- to build in here and ship; the README's **A map** says what is in one.
--
-- The level: its id, the tileset that draws it — `grove`, or `rock` or ''
-- for the plain rock a raid's rooms are cut from — which region's rock that
-- is, and its size in cells, which every layer's grid is.
CREATE TABLE maps (
	id      TEXT PRIMARY KEY CHECK (id <> '' AND id = lower(id)),
	tileset TEXT NOT NULL DEFAULT '',
	region  INTEGER NOT NULL DEFAULT 0 CHECK (region BETWEEN 0 AND 3),
	width   INTEGER NOT NULL CHECK (width >= 1),
	height  INTEGER NOT NULL CHECK (height >= 1)
);

-- A map's layers: `plan`, the floor plan — the walls, and what stands on the
-- floor; `dressing`, what is put about it. `level` is the layer's place, the
-- plan first — plan 0, dressing 1 — and `reference` the picture the layer was
-- laid over, a res:// or user:// path, NULL for none.
CREATE TABLE map_layers (
	map_id    TEXT NOT NULL REFERENCES maps (id) ON DELETE CASCADE,
	layer     TEXT NOT NULL CHECK (layer IN ('plan', 'dressing')),
	level     INTEGER NOT NULL,
	reference TEXT CHECK (reference IS NULL OR reference <> ''),
	PRIMARY KEY (map_id, layer)
);

-- A layer's grid: a row of cells a row here, top to bottom from 0, a character
-- a cell and `.` for nothing, as the map creator lays them.
CREATE TABLE map_rows (
	map_id TEXT NOT NULL,
	layer  TEXT NOT NULL,
	y      INTEGER NOT NULL CHECK (y >= 0),
	cells  TEXT NOT NULL,
	PRIMARY KEY (map_id, layer, y),
	FOREIGN KEY (map_id, layer) REFERENCES map_layers (map_id, layer) ON DELETE CASCADE
);

-- ---- the raid's floor --------------------------------------------------------
-- Which map stands where: the raid's rooms on a grid of RaidMap.MW by MH, from
-- (0, 0) in the top-left, each a map of the tables above. A room is joined to
-- the room beside it through doorways its map marks, and to the room above or
-- below through gates (`RaidMap`). `kind` is what the room is to the raid —
-- `entry`, where a run starts; `boss`, the Arbiter's; `treasure`; `normal` —
-- and `danger` how much harder its monsters are, 1 to 5. `exit` is the way out
-- it offers, standing on its map's `E`: `entry` and `crack` free, `toll` for
-- gold, `arbiter` once the boss is down — or NULL for none.
CREATE TABLE raid_rooms (
	x      INTEGER NOT NULL CHECK (x BETWEEN 0 AND 6),
	y      INTEGER NOT NULL CHECK (y BETWEEN 0 AND 4),
	map_id TEXT NOT NULL REFERENCES maps (id) DEFERRABLE INITIALLY DEFERRED,
	kind   TEXT NOT NULL CHECK (kind IN ('entry', 'normal', 'treasure', 'boss')),
	danger INTEGER NOT NULL DEFAULT 1 CHECK (danger BETWEEN 1 AND 5),
	exit   TEXT CHECK (exit IS NULL OR exit IN ('entry', 'arbiter', 'toll', 'crack')),
	PRIMARY KEY (x, y)
);
-- One way in.
CREATE UNIQUE INDEX raid_rooms_one_entry ON raid_rooms (kind) WHERE kind = 'entry';

-- ---- the heroes -----------------------------------------------------------------
-- Who the player can play as: a row a hero, in the order they stand on the
-- bench's screen (`place`, from 1), the character of the atlas each is drawn
-- as (`sprite`, one `Sprites.has_character` knows) and the colour each wears
-- on their card. What a hero can do is a column here: so far `sight`, what
-- they see on the vision key that nobody else does (`Sight`).
-- Rows are data/db/heroes/heroes.sql; see "A hero" in README.md.
CREATE TABLE heroes (
	id     TEXT PRIMARY KEY CHECK (id <> '' AND id = lower(id)),
	place  INTEGER NOT NULL UNIQUE CHECK (place >= 1),
	sprite TEXT NOT NULL CHECK (sprite <> ''),
	color  TEXT NOT NULL CHECK (length(color) = 7 AND color GLOB '#[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]'),
	prompt TEXT NOT NULL DEFAULT '',                      -- who they are, for the tool their sprites are made with (HEROES.md)
	sight  TEXT NOT NULL DEFAULT '' CHECK (sight IN ('', 'wires'))  -- '' nothing; 'wires' the wires an electrical system draws its power down
);

-- ---- the sound bank -----------------------------------------------------------
-- Every sound effect the game plays, by the id the code and the content name
-- it by (`Audio.play`; a line's `sfx`). `path` is where its file goes — the
-- prompt in `description` given to Stable Audio by hand, and what comes back
-- saved there — and `use_flag` whether that file is played: 'Y' plays it;
-- 'N', the default, is silence, as is a 'Y' with no file there yet. Nothing
-- is synthesised (app/audio/audio.gd): a sound is silent until it is made and
-- switched on, one at a time. Rows are data/db/sounds/sounds.sql; see "A
-- sound" in README.md.
CREATE TABLE sounds (
	id          TEXT PRIMARY KEY CHECK (id <> '' AND id = lower(id)),
	path        TEXT NOT NULL CHECK (path LIKE 'res://audio/sfx/%'),
	description TEXT NOT NULL CHECK (description <> ''),
	use_flag    TEXT NOT NULL DEFAULT 'N' CHECK (use_flag IN ('Y', 'N'))
);
