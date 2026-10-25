-- The parts a skill board is built from (circuit/components.gd), in the order
-- the palette shows them — which is also the order the loot pool draws from.
--
-- A part is its numbers and what it does to a flow. `heat` is added to the
-- cooldown of every cast that passes through it; `cells` is its footprint and
-- its cost in ticks, so time on a board is distance on it. Its ports are the
-- sides a flow leaves it by, as it faces east. Its effects are what it does
-- to the payload a flow carries, as the flow enters it. The `name` and
-- `description` are the English, laid under localization/<lang>/parts.json
-- the way a line's text is laid under its translation.
--
-- What a part looks like — its colour, glyph and icon — is graphics/style.gd's,
-- keyed by the same id, and a part added here draws in its category's colour
-- until somebody gives it a look of its own. A part added here needs a number
-- in `codes`, or no board carrying it can be shared.
--
-- Where a flow starts and where it becomes an attack are not parts of their
-- own. They are the board's: its root, and its way out in the middle of its
-- right edge (circuit/skill_board.gd).

-- In the order the palette lays its blocks out. `states` is what a hit leaves
-- on what it strikes — FIRE, ICE, WATER, and POSSESS's hands in it — and
-- TIME DILATION's slowing of the world; it was `element`. `behavior` is COMMON MODIFIER on screen, and holds most of what
-- was the `stat` block — DAMAGE, SIZE, RANGE, SHATTER — as well; the two after
-- it are what a bolt is steered and carried by — SPEED, PIERCE, HOMING,
-- AUTO-AIM, ANTI-GRAVITY, BOUNCE, BOOMERANG and CHAIN — and what an attack
-- calls up beside itself: a bolt in the air, a pet.
INSERT INTO categories (id) VALUES
	('form'), ('states'), ('behavior'), ('projectile_behavior'), ('summon_behavior'),
	('flow'), ('trigger');

-- Every number a part has ever had in a shared code, in order. **Only ever
-- add to the end.** A code written today has to mean the same board next
-- year, so a number is a part's for good: INPUT, OUTPUT, WIRE and BEND keep
-- theirs though they are gone, and so does EXPLODE, which had the number it
-- had when it was called AREA. A code has six bits for it, so the last number there can be
-- is 63.
INSERT INTO codes (code, id) VALUES
	(0, 'INPUT'), (1, 'OUTPUT'), (2, 'WIRE'), (3, 'BEND'),
	(4, 'PROJECTILE'), (5, 'SLASH'), (6, 'EXPLODE'), (7, 'DASHSLASH'), (8, 'DASHSLASH_AUTO'),
	(9, 'FIRE'), (10, 'ICE'), (11, 'DAMAGE'), (12, 'SIZE'), (13, 'SPEED'),
	(14, 'PIERCE'), (15, 'DASH'), (16, 'BLINK'), (17, 'HOMING'), (18, 'REVERSE'),
	(19, 'SPLIT'), (20, 'TEE'), (21, 'DUPLICATE'), (22, 'OVERCLOCK'), (23, 'DELAY'), (24, 'TIME_DILATION'),
	(25, 'ON_HIT'), (26, 'ON_KILL'), (27, 'ON_PARRY'),
	(28, 'SHATTER'), (29, 'GRAVITY'), (30, 'MANA_DRAIN'),
	(31, 'RANGE'),
	(32, 'KNOCKBACK'),
	(33, 'ZAP'),
	(34, 'INVERT'), (35, 'STUN'),
	(36, 'POSSESS'),
	(37, 'AUTO_AIM'),
	(38, 'HEALTH_DRAIN'),
	(39, 'WATER'),
	(40, 'BRIDGE'),
	(41, 'HEADBUTT'),
	(42, 'SUMMON_PROJECTILE'), (43, 'SUMMON_PET'),
	(44, 'ANTI_GRAVITY'),
	(45, 'OFFENSIVE'),
	(46, 'KAMIKAZE'),
	(47, 'PULL'),
	(48, 'NEAR'),
	(49, 'HEAL'),
	(50, 'BOUNCE'), (51, 'RETURN'), (52, 'CHAIN');

-- WIRE and BEND carried a flow one cell and did nothing else to it, which
-- every part already does: any part takes flow on any side and sends it where
-- it points. (BRIDGE is that part again, with a number of its own: see the
-- flow block.) INPUT was where a flow started; a board's root is that now, the
-- weapon's own part (`SkillBoard.root`). OUTPUT was where a flow became an
-- attack; the middle of the board's right edge is that now
-- (`SkillBoard.way_out`). A board that still has any of them reads with the
-- part left out and its cell left empty, and one that ended on an OUTPUT is
-- slid along to where its flow used to end (`SkillBoard.slide_onto_way_out`).
--
-- DASH lunged the caster along the aim as the attack went off. The player has
-- a dash of their own on a key now, and SWIFT STRIKE is the lunge a board
-- makes, so it was a third way to do one thing.
--
-- SPLIT and TEE forked a flow in two. A board has one way out, so what a fork
-- made was walked round to it, and a ring with a TEE in it sent an attack out
-- on every lap. A trigger does that job: its branch goes round the ring and
-- each lap is one more follow-up. With no fork, a cast is one attack.
--
-- REVERSE turned a bolt round to come back at the caster a moment after it
-- left, and did nothing to any other form.
--
-- BLINK put the caster behind the nearest enemy in sight as the attack went
-- off, once a cast.
--
-- SUMMON_PROJECTILE, SUMMON BOLT, hung a bolt in the air over where the attack
-- was aimed, which fell and struck what it touched once. KAMIKAZE took its
-- place in the summon block.
--
-- EXPLODE burst every hit, landing it again on everything round the enemy it
-- struck, and on a flow with no form was a burst of its own where it went off.
-- NEAR took its place: what the parts after it do reaches the enemies round
-- the one struck. It had been AREA before it was EXPLODE, and was made over
-- under its new name; a save old enough to spell it AREA reads with it left
-- out, as one that spells it EXPLODE does now, and a code says its number.
--
-- GRAVITY pinned the enemy struck and dragged everything round it onto it.
-- NEAR and PULL do that between them now: the ones round the enemy struck
-- dragged in to it (`Attacks.resolve_hit`, a touch's `hook`).
INSERT INTO retired_parts (id) VALUES ('WIRE'), ('BEND'), ('INPUT'), ('OUTPUT'), ('DASH'),
	('SPLIT'), ('TEE'), ('REVERSE'), ('BLINK'), ('SUMMON_PROJECTILE'), ('EXPLODE'),
	('GRAVITY');

-- DASHSLASH_AUTO, SWIFT STRIKE+, was SWIFT STRIKE with AUTO-AIM built into it:
-- it lunged at the nearest enemy and through. AUTO-AIM is a part now, and does
-- that for any form, so SWIFT STRIKE+ is SWIFT STRIKE wherever it was — a
-- board, a stash, a drop — and AUTO-AIM is placed beside it. It keeps its own
-- number, since SWIFT STRIKE has one already; a code that says 8 reads as
-- SWIFT STRIKE through the rename (`BoardCode.decode`).
--
-- ZAP was a beam to where the cursor pointed, landing the instant it was cast.
-- A bolt whose SPEED is stacked to its limit crosses a room in a tenth of a
-- second (`Projectile.LASER_SPEED`), so ZAP was PROJECTILE and SPEED doing
-- what they do already, and it is PROJECTILE now wherever it was — a board, a
-- stash, a drop. It keeps its number, 33, since PROJECTILE has one already;
-- a code that says 33 reads as PROJECTILE.
INSERT INTO renamed_parts (old_id, new_id) VALUES ('DASHSLASH_AUTO', 'DASHSLASH'),
	('ZAP', 'PROJECTILE');


-- ---- form: what the attack is ------------------------------------------------
-- A form is only as good as the attack that draws it: feature/attacks/ spawns
-- each by its id, and `Weapons.finalize` weighs it. A weapon's own form is the
-- root of its graph, so every cast off it starts as that form; a form placed
-- after it makes the flow that instead.
--
-- HEADBUTT, PUNCH wherever a player reads it, is the one form with no weapon in
-- it: the fist does the striking. A graph whose every attack is a HEADBUTT goes
-- off whether its weapon is in hand or not — the rock lying elsewhere, every
-- shuriken thrown, the hands in a monster that has not taken the weapon
-- (`Player.can_cast`) — and none of the weapon's multipliers weigh it
-- (`Weapons.BARE_FORMS`). It is the root of the empty hand's graph
-- (`Weapons.HAND`).

INSERT INTO parts (id, name, category, heat, cells, tag, description) VALUES
	('PROJECTILE', 'PROJECTILE', 'form', 0.6, 1, 'ranged', 'Fires a bolt along the aim direction. The standard ranged form.'),
	('SLASH', 'SLASH', 'form', 0.5, 1, 'melee', 'An instant short arc at the aim direction. Fast, but reach is short.'),
	('DASHSLASH', 'SWIFT STRIKE', 'form', 1.0, 1, 'melee', 'Lunges along the aim direction, cutting everything on the path.'),
	('HEADBUTT', 'PUNCH', 'form', 0.5, 1, 'melee', 'A fist thrown a short way along the aim from where you stand, into the first enemy in the way, and no further. You do not move with it. It needs no weapon: it goes off with the weapon in hand or without it.');

INSERT INTO ports (part_id, side) VALUES
	('PROJECTILE', 'E'), ('SLASH', 'E'), ('DASHSLASH', 'E'), ('HEADBUTT', 'E');

INSERT INTO effects (part_id, position, field, op, value) VALUES
	('PROJECTILE', 0, 'form', 'set', 'PROJECTILE'),
	('SLASH', 0, 'form', 'set', 'SLASH'),
	('DASHSLASH', 0, 'form', 'set', 'DASHSLASH'),
	('HEADBUTT', 0, 'form', 'set', 'HEADBUTT');


-- ---- states (was element) -----------------------------------------------------

-- WATER is the third, and what it does is change the other two: a wet enemy
-- freezes under ICE and is only dried by FIRE (`Actor.afflict`).
INSERT INTO parts (id, name, category, heat, description) VALUES
	('FIRE', 'FIRE', 'states', 0.4, 'Adds flame. Struck enemies burn for damage over time; a wet one is only dried.'),
	('ICE', 'ICE', 'states', 0.4, 'Adds frost. Struck enemies are slowed; a wet one freezes solid for a moment.'),
	('WATER', 'WATER', 'states', 0.4, 'Soaks what it strikes. A wet enemy freezes solid under ICE, and FIRE only dries it; water puts a burning enemy out.');

INSERT INTO ports (part_id, side) VALUES ('FIRE', 'E'), ('ICE', 'E'), ('WATER', 'E');

INSERT INTO effects (part_id, position, field, op, value) VALUES
	('FIRE', 0, 'elements', 'include', 'FIRE'),
	('ICE', 0, 'elements', 'include', 'ICE'),
	('WATER', 0, 'elements', 'include', 'WATER');


-- ---- what was stat: in COMMON MODIFIER (`behavior`) now ---------------------------

-- `stack_limit` is how many of a part one flow can stack; a part without one
-- stacks for as long as the board has room. SIZE stops at three, which is an
-- attack four times the size. SPEED stops at four, and the fourth is the one
-- that matters: a bolt whose SPEED is at its limit flies at laser speed
-- (`Projectile.LASER_SPEED`). RANGE stops at three, which carries the gun's
-- bolt further than a room is wide — the most range there is to have — and
-- SWIFT STRIKE's lunge five times as far.
INSERT INTO parts (id, name, category, heat, stack_limit, description) VALUES
	('DAMAGE', 'DAMAGE +', 'behavior', 0.3, NULL, 'Raises damage, and each one stacked raises it by more than the last. Stable and simple, but interacts with little else.'),
	('SIZE', 'SIZE x', 'behavior', 0.4, 3, 'Scales the attack by 1.6. Melee arcs widen and reach further. Stacks up to 3.'),
	('SPEED', 'SPEED x', 'projectile_behavior', 0.35, 4, 'Bolts leave 1.5x faster. They also carry further before they fade, and are harder to dodge. Does nothing to any other attack. Stacks up to 4, and at 4 a bolt flies at laser speed.'),
	('RANGE', 'RANGE x', 'behavior', 0.35, 3, 'Bolts carry 1.75x as far before they fade, and SWIFT STRIKE lunges 1.75x as far. Does nothing to any other attack. Stacks up to 3, which is the most range there is.'),
	('SHATTER', 'SHATTER', 'behavior', 0.45, NULL, 'Breaks the frost on an enemy slowed by it: the hit lands far harder, and the enemy thaws. Each one stacked breaks harder still. Worth nothing on its own — pair it with ICE, or with a board that lands twice.');

INSERT INTO ports (part_id, side) VALUES
	('DAMAGE', 'E'), ('SIZE', 'E'), ('SPEED', 'E'), ('RANGE', 'E'), ('SHATTER', 'E');

-- SPEED's reach is gentler than the speed it buys, because range is the thing
-- being spent there: the part is worth taking for the speed, and the extra
-- reach is what keeps a fast bolt from running out of range before it
-- arrives — which is what the part has always said it does. RANGE is worth
-- more reach than SPEED throws in, because reach is all it buys: it does
-- nothing to how hard or how fast a bolt arrives, so it has to be the answer
-- when the thing you cannot do is reach. Their descriptions say 1.5x, 1.6
-- and 1.75x; change one, change the other.
--
-- A lunge is reach too, but not a range: SWIFT STRIKE's distance is the
-- attack's own (`Attacks.DASH_SLASH_REACH`), which a weapon's range does not
-- change, so RANGE carries it on a row of its own, `lunge`, by the same 1.75.
-- SPEED does not: a lunge already lands the instant it is cast.
--
-- DAMAGE grows with the stack (`per_stack`): one adds 8, as it always has, and
-- every one after it adds 4 more than the one before — 8, 12, 16 — so three are
-- worth 36 where three used to be worth 24. It grows by adding, not by
-- multiplying, on purpose: a charged ring walks a flow through the same part
-- lap after lap, and a multiply there doubles every few laps.
INSERT INTO effects (part_id, position, field, op, value, per_stack) VALUES
	('DAMAGE', 0, 'damage', 'add', 8, 4);

INSERT INTO effects (part_id, position, field, op, value) VALUES
	('SIZE', 0, 'size', 'multiply', 1.6),
	('SPEED', 0, 'speed', 'multiply', 1.5),
	('SPEED', 1, 'range_px', 'multiply', 1.2),
	('RANGE', 0, 'range_px', 'multiply', 1.75),
	('RANGE', 1, 'lunge', 'multiply', 1.75),
	('SHATTER', 0, 'shatter', 'add', 1);


-- ---- behavior -------------------------------------------------------------------

-- Every one of these stacks: each is a count on the payload, and what reads it
-- (feature/attacks/) does more for a higher one.
--
-- KNOCKBACK is PUSH on screen; the id stays, since saved boards and share codes
-- carry ids. PULL is its opposite, and what an INVERT makes of it: the field it
-- adds to is the same `hook`, which drags the enemy struck toward whoever
-- struck it, and no further than to just short of them (`Attacks.hook_force`).
INSERT INTO parts (id, name, category, heat, description) VALUES
	('PIERCE', 'PIERCE', 'projectile_behavior', 0.5, 'The attack passes through one enemy and carries on to the next. Each one stacked is one more enemy it passes through.'),
	('HOMING', 'HOMING', 'projectile_behavior', 0.6, 'Tracks the nearest enemy. Bolts curve and find their way round walls; melee forms re-aim themselves. Each one stacked turns a bolt tighter, so it holds a winding path it would otherwise fly wide of.'),
	('KNOCKBACK', 'PUSH', 'behavior', 0.5, 'Hits throw the enemy back the way the attack was going. Thrown hard into a wall, it cracks the wall and is hurt and stunned. Buys room, but can put it out of reach. Each one stacked throws harder.'),
	('PULL', 'PULL', 'behavior', 0.5, 'Hits drag the enemy toward whoever struck it, and it stops just short of them. Brings an enemy into reach, but brings it close. Each one stacked drags it from further off.'),
	('MANA_DRAIN', 'MANA DRAIN', 'behavior', 0.5, 'Every enemy this attack connects with gives mana back to the caster. What pays for the next charge is landing hits, not waiting. Each one stacked drains more.'),
	('HEALTH_DRAIN', 'HEALTH DRAIN', 'behavior', 0.6, 'Every enemy this attack hurts gives health back to the caster: a fifth of the damage dealt, and a fifth more for each one stacked. What keeps you standing is landing hits.'),
	('STUN', 'STUN', 'behavior', 0.6, 'Struck enemies are stunned: for a moment they stand where they are and cannot attack. Each one stacked holds them longer. Once it wears off, an enemy shrugs off the next stun for a while.'),
	('POSSESS', 'POSSESS', 'states', 0.9, 'Takes over the monster struck for 5 seconds, unharmed, longer for each one stacked. Your keys move it; it fights with its own attack, or your weapon once it takes it from your body, left behind and still hunted. Bosses resist it.'),
	('AUTO_AIM', 'AUTO-AIM', 'projectile_behavior', 0.4, 'Aims the attack at the nearest enemy, wherever you point: bolts go straight at it and SWIFT STRIKE lunges through it, as far as each reaches, and a swing turns to it. Each one stacked looks further for one.'),
	('ANTI_GRAVITY', 'ANTI-GRAVITY', 'projectile_behavior', 0.4, 'Bolts fly with no weight on them: a lobbed shot — the rock, the rune, a shuriken, a Lobber''s — goes straight instead of arcing. One is all it takes.'),
	('HEAL', 'HEAL', 'behavior', 0.5, 'Heals what the attack strikes by 8 once the blow has landed, and 8 more for each one stacked. The blow still lands; one it kills is not healed. Turned round by INVERT, it is 8 more damage instead.');

-- NEAR selects the enemies round the one the attack strikes, out to
-- `Attacks.NEAR_RADIUS` and further for each one stacked, and what every part
-- after it on the flow does reaches them too — the effects alone, not the
-- blow: they are not struck by the weapon, only touched by what comes after
-- the NEAR (`Payload.spread`, which the runner builds from those parts as the
-- flow goes on through them). The enemy struck takes the whole flow as ever.
-- A flow with no form has no blow and no enemy struck, and its NEAR selects
-- the enemies round where it goes off, its triggers going off on each: the
-- Hopper's board, the Arbiter's second, a trigger's branch with one on it. A
-- branch starts without the one before its trigger, as it starts without the
-- form (`SkillRunner._exit`). Its tag is an area's.
INSERT INTO parts (id, name, category, heat, tag, description) VALUES
	('NEAR', 'NEAR', 'behavior', 1.0, 'area', 'Every part after it reaches the enemies round the one the attack strikes too: FIRE burns them, STUN stuns them, DAMAGE hurts them. The blow itself lands on the enemy struck alone. Each one stacked reaches further.');

INSERT INTO ports (part_id, side) VALUES
	('PIERCE', 'E'), ('HOMING', 'E'),
	('KNOCKBACK', 'E'), ('PULL', 'E'), ('MANA_DRAIN', 'E'), ('HEALTH_DRAIN', 'E'),
	('STUN', 'E'), ('POSSESS', 'E'), ('AUTO_AIM', 'E'), ('ANTI_GRAVITY', 'E'), ('HEAL', 'E'), ('NEAR', 'E');

INSERT INTO effects (part_id, position, field, op, value) VALUES
	('PIERCE', 0, 'pierce', 'add', 1),
	('HOMING', 0, 'homing', 'add', 1),
	('KNOCKBACK', 0, 'knockback', 'add', 1),
	('PULL', 0, 'hook', 'add', 1),
	('MANA_DRAIN', 0, 'mana_drain', 'add', 1),
	('HEALTH_DRAIN', 0, 'health_drain', 'add', 1),
	('STUN', 0, 'stun', 'add', 0.8),
	('POSSESS', 0, 'possess', 'add', 5),
	('AUTO_AIM', 0, 'auto_aim', 'add', 1),
	('ANTI_GRAVITY', 0, 'anti_gravity', 'add', 1),
	('HEAL', 0, 'heal', 'add', 8),
	('NEAR', 0, 'near', 'add', 1);

-- Three more ways a bolt flies (`Projectile`). BOUNCE has it come back off the
-- walls and floors it meets, at its full pace, as many times as it has them,
-- before one ends it; a thrown stone bounces with its throw still in it.
-- RETURN is BOOMERANG on screen: at the end of its range, or off a wall it
-- cannot bounce off, the bolt turns back toward whoever cast it, its strikes
-- fresh, so it lands again on the way — and the rock, the rune and a shuriken
-- fly back into the hand that threw them, their throw uncast if it struck
-- nothing. CHAIN sends a fresh bolt out of each enemy struck at the nearest
-- other one, flat and with the same numbers, a jump fewer on it; a thrown
-- stone's links are bolts, and the stone goes on as it would have.
INSERT INTO parts (id, name, category, heat, description) VALUES
	('BOUNCE', 'BOUNCE', 'projectile_behavior', 0.4, 'Bolts come back off walls and floors instead of ending there, once. Each one stacked is one more bounce. A thrown stone bounces with its throw still in it.'),
	('RETURN', 'BOOMERANG', 'projectile_behavior', 0.6, 'Bolts turn back toward you at the end of their range, or off a wall, and strike again on the way. The rock, the rune and a shuriken fly back into your hand. One is all it takes.'),
	('CHAIN', 'CHAIN', 'projectile_behavior', 0.7, 'On a hit, a fresh bolt leaves the enemy struck for the nearest other one, with the same numbers. Each one stacked is one more jump.');

INSERT INTO ports (part_id, side) VALUES
	('BOUNCE', 'E'), ('RETURN', 'E'), ('CHAIN', 'E');

INSERT INTO effects (part_id, position, field, op, value) VALUES
	('BOUNCE', 0, 'bounce', 'add', 1),
	('RETURN', 0, 'returns', 'add', 1),
	('CHAIN', 0, 'chain', 'add', 1);


-- ---- summon ---------------------------------------------------------------------
-- What an attack calls up beside itself, every time a flow carrying one goes
-- off (`Attacks.spawn`), whatever its form, and with none. SUMMON PET calls a
-- pet that follows its summoner (`Pet`): one to a summoner, so a cast with one
-- already there calls no other, but tells the one there again what it does.
-- What it does is what the rest of the block on the same flow says: OFFENSIVE
-- sends it at the nearest enemy near its summoner, to strike it with the flow;
-- KAMIKAZE sends it at that enemy to blow itself up against it, the flow going
-- off as a burst round it (`Attacks.kamikaze`), and the pet is gone until a
-- cast calls another.
INSERT INTO parts (id, name, category, heat, description) VALUES
	('SUMMON_PET', 'SUMMON PET', 'summon_behavior', 0.8, 'Summons a pet that follows you about. On its own it does nothing else. One at a time: a cast while it is there summons no other, but tells it again what it does.'),
	('OFFENSIVE', 'OFFENSIVE', 'summon_behavior', 0.6, 'A pet summoned with it goes for the nearest enemy near you and strikes it with the attack''s numbers. Each one stacked strikes more often. Does nothing without a SUMMON PET.'),
	('KAMIKAZE', 'KAMIKAZE', 'summon_behavior', 0.8, 'A pet summoned with it flies at the nearest enemy near you and blows itself up against it: everything round it takes the attack''s numbers, and the pet is gone. Each one stacked bursts wider. Does nothing without a SUMMON PET.');

INSERT INTO ports (part_id, side) VALUES
	('SUMMON_PET', 'E'), ('OFFENSIVE', 'E'), ('KAMIKAZE', 'E');

INSERT INTO effects (part_id, position, field, op, value) VALUES
	('SUMMON_PET', 0, 'summon_pet', 'add', 1),
	('OFFENSIVE', 0, 'pet_offensive', 'add', 1),
	('KAMIKAZE', 0, 'pet_kamikaze', 'add', 1);


-- ---- flow ---------------------------------------------------------------------
-- OVERCLOCK does nothing to a flow: it runs the whole board on a faster clock,
-- which `SkillBoard.analyze` counts off the grid, and a flow crosses it without
-- spending a tick (`SkillRunner.NO_TICK`).
--
-- Nor does DELAY: what it does is its heat, the wait it adds to every cast
-- that passes through it (`SkillRunner.HEAT_TO_TICKS`), as much again for each
-- one. It used to be the part a flow was steered round with, at no heat, and
-- that is BRIDGE's job now. BRIDGE does nothing at all: it carries a flow one
-- cell, a tick as every part is, and that is all it is for — what WIRE and
-- BEND were, a part again.

INSERT INTO parts (id, name, category, heat, description) VALUES
	('DUPLICATE', 'DUPLICATE x3', 'flow', 3.0, 'Produces the same result three times at full damage. Generates a lot of heat.'),
	('OVERCLOCK', 'OVERCLOCK', 'flow', 0.0, 'Runs the whole board on a faster clock. Each one cuts the wait between casts by the same 5%; twelve bring it down to 40%, and it goes no lower. A flow goes through it without spending a tick.'),
	('DELAY', 'DELAY', 'flow', 2.0, 'Makes every cast that passes through it wait longer before the next, and each one more adds as much again. It does nothing else: it turns a flow and leaves it as it was.'),
	('TIME_DILATION', 'TIME DILATION', 'states', 2.0, 'Slows the world and the board alike. Not a speed buff — a change in the pace of the fight.'),
	('INVERT', 'INVERT', 'flow', 0.4, 'Turns the part right before it inside out: DAMAGE heals what it strikes and HEAL harms it, FIRE, ICE and STUN cleanse it, PUSH pulls and PULL pushes, and SIZE, SPEED and RANGE shrink. After anything else it does nothing.'),
	('BRIDGE', 'BRIDGE', 'flow', 0.0, 'Carries a flow one cell and does nothing else: it turns the flow and leaves it as it was. Steer a flow round to the way out with it, or walk a trigger''s branch round a ring and back.');

INSERT INTO ports (part_id, side) VALUES
	('DUPLICATE', 'E'), ('OVERCLOCK', 'E'), ('DELAY', 'E'), ('TIME_DILATION', 'E'),
	('INVERT', 'E'), ('BRIDGE', 'E');

-- INVERT does whatever the part before it has rows of `inversions` for: see
-- the foot of the file.
INSERT INTO effects (part_id, position, field, op, value) VALUES
	('DUPLICATE', 0, 'duplicates', 'multiply', 3),
	('TIME_DILATION', 0, NULL, 'dilate', 1.4),
	('INVERT', 0, NULL, 'invert', NULL);


-- ---- trigger: a second flow, run as the payload of a moment -------------------
-- Which moment is the part's id: `SkillRunner` keeps what each branch resolves
-- to under it, and a payload carries it as `on_hit`, `on_kill` or `on_parry`.

INSERT INTO parts (id, name, category, heat, tag, description) VALUES
	('ON_HIT', 'ON HIT', 'trigger', 0.6, 'trigger', 'Runs the branch flow as a payload when this skill connects.'),
	('ON_KILL', 'ON KILL', 'trigger', 0.6, 'trigger', 'Runs the branch flow as a payload only when this skill kills.'),
	('ON_PARRY', 'ON PARRY', 'trigger', 0.8, 'trigger', 'Opens a brief guard window as the flow passes. Absorbing a hit there runs the branch flow.');

INSERT INTO ports (part_id, side, kind) VALUES
	('ON_HIT', 'E', 'flow'), ('ON_HIT', 'S', 'branch'),
	('ON_KILL', 'E', 'flow'), ('ON_KILL', 'S', 'branch'),
	('ON_PARRY', 'E', 'flow'), ('ON_PARRY', 'S', 'branch');

-- The guard window is real seconds, like the overclock's settling delay and
-- for the same reason: a window counted in ticks would be shortened by a
-- faster clock. It used to be read off ON PARRY's own tick cost, which one
-- tick per cell would have cut to a third.
INSERT INTO effects (part_id, position, field, op, value) VALUES
	('ON_PARRY', 0, NULL, 'guard', 0.2);


-- ---- inversions: what a part does when an INVERT follows it -------------------
-- The runner puts back every field the part's effects changed, then does these
-- instead (`SkillRunner._invert`). What harms the struck enemy turns to what
-- helps it — DAMAGE's eight to a heal of eight, a burn, a chill or a stun to a
-- cleanse of all three — and what pulls pushes, what pushes pulls, and what
-- makes an attack more makes it less. A part with no rows here has no
-- opposite: an INVERT after a form or a trigger does nothing.
--
-- Each number is its effect's turned round: the heal is DAMAGE's add, and every
-- multiply here is one over the one above (1/1.6, 1/1.5, 1/1.2, 1/1.75).
-- Change one, change the other — tests/circuit/invert_test holds the
-- multiplies to it.
INSERT INTO inversions (part_id, position, field, op, value) VALUES
	('DAMAGE', 0, 'heal', 'add', 8),
	('HEAL', 0, 'damage', 'add', 8),
	('FIRE', 0, 'cleanse', 'set', 'true'),
	('ICE', 0, 'cleanse', 'set', 'true'),
	('STUN', 0, 'cleanse', 'set', 'true'),
	('KNOCKBACK', 0, 'hook', 'add', 1),
	('PULL', 0, 'knockback', 'add', 1),
	('SIZE', 0, 'size', 'multiply', 0.625),
	('SPEED', 0, 'speed', 'multiply', 0.6667),
	('SPEED', 1, 'range_px', 'multiply', 0.8333),
	('RANGE', 0, 'range_px', 'multiply', 0.5714),
	('RANGE', 1, 'lunge', 'multiply', 0.5714);
