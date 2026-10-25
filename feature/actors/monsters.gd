class_name Monsters
extends RefCounted

## Monster attacks are built on the same boards the player uses. That is what
## makes their drops legible: a kill can yield a part the monster was visibly
## using, so watching an attack teaches you how to build it. A monster names its
## board by id — `board`, and for the Arbiter's second form `board_phase2` —
## and the boards themselves are rows in the content database
## (`data/db/boards/monsters.sql`). One with no board attacks with nothing.
##
## Stats only. Which atlas character draws a monster, what colour its death
## bursts, and how a modifier is marked all live in `graphics/style.gd`, keyed
## by the same ids used here — so a monster added here still spawns and fights
## before anyone has chosen how it should look.

const DEFS := {
	"CRAWLER": {
		"name": "Crawler", "hp": 32.0, "speed": 165.0, "ai": "runner",
		"size": 14.0,
		"aggro": 420.0, "attack_range": 60.0, "contact": 6.0, "scrap": 3,
		"board": "crawler",
	},
	"SENTRY": {
		"name": "Sentry", "hp": 46.0, "speed": 0.0, "ai": "turret",
		"size": 16.0,
		"aggro": 560.0, "attack_range": 280.0, "contact": 0.0, "scrap": 4,
		"board": "sentry",
	},
	"LOBBER": {
		"name": "Lobber", "hp": 38.0, "speed": 70.0, "ai": "walker",
		"size": 15.0,
		"aggro": 480.0, "attack_range": 420.0, "contact": 4.0, "scrap": 4,
		"board": "lobber",
		"lobbed": true,
	},
	## Lunges at what it hunts in bounds along the floor, a wind-up before each.
	"HOPPER": {
		"name": "Hopper", "hp": 52.0, "speed": 130.0, "ai": "jumper",
		"size": 17.0,
		"aggro": 440.0, "attack_range": 110.0, "contact": 8.0, "scrap": 5,
		"board": "hopper",
	},
	"DRIFTER": {
		"name": "Drifter", "hp": 30.0, "speed": 95.0, "ai": "flyer",
		"size": 13.0,
		"aggro": 520.0, "attack_range": 200.0, "contact": 5.0, "scrap": 4,
		"board": "drifter",
	},
	## Runs at whoever it hunts and, once close enough to punch them, does —
	## and goes up with it. Its board is a HEADBUTT (PUNCH) and a NEAR carrying
	## DAMAGE and FIRE, so what the punch does reaches everything round whoever
	## it struck; and its attack is the last thing it does (`spent_by_attack`):
	## it goes up where it stands, the same flow touching everything round it,
	## and dies in it. Fragile and quick, so it is a thing to stop before it
	## arrives.
	"BOMBER": {
		"name": "Bomber", "hp": 24.0, "speed": 185.0, "ai": "runner",
		"size": 13.0,
		"aggro": 460.0, "attack_range": 40.0, "contact": 0.0, "scrap": 4,
		"board": "bomber",
		"spent_by_attack": true,
	},
	"WARDEN": {
		"name": "Warden", "hp": 105.0, "speed": 105.0, "ai": "runner",
		"size": 20.0,
		"aggro": 560.0, "attack_range": 230.0, "contact": 9.0, "scrap": 10,
		"elite": true,
		"board": "warden",
	},
	## A person with a rifle — not a monster, and not met in a raid (`pick` never
	## names it): a guard of the Jean Grey test's building. It holds its post and
	## shoots what it notices, from further off than anything else sees, with a
	## shot quick enough to be hard to step out of and heavy enough that three
	## put a body down — two, once anything else has landed. Possessed, it walks
	## at a person's pace and its own attack is that shot.
	"GUNMAN": {
		"name": "Gunman", "hp": 40.0, "speed": 120.0, "ai": "turret",
		"size": 15.0,
		"aggro": 600.0, "attack_range": 440.0, "contact": 0.0, "scrap": 6,
		"board": "gunman",
		"damage": 45.0, "shot_speed": 2.2,
	},
	"DUMMY": {
		"name": "Test Dummy", "hp": 99999.0, "speed": 0.0, "ai": "turret",
		"size": 18.0,
		"aggro": 0.0, "attack_range": 0.0, "contact": 0.0, "scrap": 0,
	},
	## The dragon test's guards. One cut from any weapon drops one, and they hold
	## their posts, so a chain of lunges is judged on reach and line alone.
	"GRUNT": {
		"name": "Grunt", "hp": 1.0, "speed": 0.0, "ai": "turret",
		"size": 14.0,
		"aggro": 900.0, "attack_range": 0.0, "contact": 0.0, "scrap": 0,
	},
	"ARBITER": {
		"name": "Arbiter", "hp": 460.0, "speed": 120.0, "ai": "boss",
		"size": 34.0,
		"aggro": 900.0, "attack_range": 350.0, "contact": 14.0, "scrap": 60,
		"boss": true,
		"board": "arbiter",
		"board_phase2": "arbiter_phase2",
	},
}

const NORMAL_POOL := ["CRAWLER", "SENTRY", "LOBBER", "HOPPER", "DRIFTER", "BOMBER"]

## The monster dictionary's entries, in its order: every monster a raid puts in
## front of the player — the ones `pick` draws, then the Arbiter. A monster met
## nowhere but the bench or the tests has no entry.
const DEX := ["CRAWLER", "SENTRY", "LOBBER", "HOPPER", "DRIFTER", "BOMBER", "WARDEN", "ARBITER"]

## A monster's skills, as the keys its boards are under in DEFS: its attack,
## and the Arbiter's second form's. A monster with no board has none.
static func skills_of(id: String) -> Array:
	var out: Array = []
	for key in ["board", "board_phase2"]:
		if String(get_def(id).get(key, "")) != "":
			out.append(key)
	return out

static func get_def(id: String) -> Dictionary:
	return DEFS.get(id, DEFS["CRAWLER"])

## What to call a monster on screen. The `name` in DEFS is the fallback, so a
## monster added here is named before anybody translates it.
static func name_for(id: String) -> String:
	return Loc.opt("monsters.%s" % id, String(get_def(id)["name"]))

## The monster's attack — `board`, or the one it turns to, `board_phase2` — as
## the board its runner walks. A monster with none gets an empty one.
static func build_board(id: String, key: String = "board") -> SkillBoard:
	var board_id := String(get_def(id).get(key, ""))
	if board_id == "":
		return SkillBoard.new(7, 5, name_for(id))
	return Boards.build(board_id, name_for(id))

## Parts the monster's own attack is assembled from — its possible drops.
static func drop_pool(id: String) -> Array:
	var pool: Array = []
	for key in ["board", "board_phase2"]:
		var board_id := String(get_def(id).get(key, ""))
		if board_id == "":
			continue
		for cid in Boards.parts_of(board_id):
			if not pool.has(cid):
				pool.append(cid)
	return pool

## Picks a monster appropriate to how deep and how long the raid has run.
static func pick(rng: RandomNumberGenerator, danger: int) -> String:
	if danger >= 3 and rng.randf() < 0.22:
		return "WARDEN"
	return NORMAL_POOL[rng.randi() % NORMAL_POOL.size()]
