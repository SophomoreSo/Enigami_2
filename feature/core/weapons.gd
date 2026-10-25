class_name Weapons
extends RefCounted

## Weapons are the top-level choice made before a raid. A weapon is a graph:
## its own attack form is the root of a board — the sword's DASHSLASH, the
## gun's PROJECTILE — and everything the player wires on round it is the skill
## that weapon casts. There is no skill without a weapon and no weapon without
## its graph; what a raid carries is the weapon and the graph on it.
##
## The graph a new profile is handed for each weapon is a board in the content
## database (`data/db/boards/weapons.sql`): the root part and nothing else,
## standing against the board's way out, which is enough to fire. `root` names
## that part, so a screen can say
## what a weapon is before its board is built; `tests/feature/boards_test`
## holds the two to each other.
##
## A weapon can be `thrown`: the rock is not something that casts its graph
## but the thing its graph is cast into. There is one of it. The flow that
## sends it sends the rock itself, carrying everything built into the graph,
## and it lies where it comes down until it is picked back up; until then the
## weapon casts nothing. See `Player.holding`, and `LooseRock` for the rock on
## the floor.
##
## A weapon can be `stacked` instead: a stack of the same thing, spent one at a
## time — the shuriken. A raid walks in with the whole stack (`stack_of`), and
## every bolt its graph sends throws one, lobbed as the rock is, while there are
## any left: a volley of three spends three. Each sticks where it strikes, in
## a wall or in a monster, and is picked back up by walking over it; one left
## behind in a room walked out of is gone. With none left the weapon casts
## nothing. See `Player.stock`, and `StuckShuriken` for one where it struck.
##
## A weapon can be a `rune`: a rock with mana in it. It is thrown and picked
## back up the way the rock is, by the attack button alone, and a throw of it
## carries the charge stored in it for nothing (`GameState.rune`). A throw
## spends it: it is still a stone to throw, but bare, its graph cast not at all
## (`Player._throw_bare`), until it is filled again — by holding the cast button
## with it in hand, which pours the player's own mana into it
## (`Player.refill_rune`) and never casts it.
##
## Numbers only: the colour a weapon is named in, and the tile it is drawn
## with, are in `graphics/style.gd`.

const DEFS := {
	"SWORD": {
		"name": "Sword",
		"desc": "Close work. A lunge that cuts everything on its line; melee flows hit far harder, and bolts leave the blade sluggish.",
		"root": "DASHSLASH",
		"board": "sword",
		"base_damage": 12.0,
		"melee_mul": 1.45,
		"ranged_mul": 0.7,
		"projectile_speed": 0.8,
		"reach_mul": 0.7,
		"size_mul": 1.15,
		"gravity_shots": false,
	},
	"GUN": {
		"name": "Gun",
		"desc": "Range and speed. Bolts fly flat and fast; the stock makes a poor club.",
		"root": "PROJECTILE",
		"board": "gun",
		"base_damage": 9.0,
		"melee_mul": 0.6,
		"ranged_mul": 1.3,
		"projectile_speed": 1.6,
		"reach_mul": 1.5,
		"size_mul": 0.95,
		"gravity_shots": false,
	},
	"ROCK": {
		"name": "Rock",
		"desc": "One stone, thrown with everything built into it. It lands where it lands, and does nothing more until you pick it up.",
		"root": "PROJECTILE",
		"board": "rock",
		"base_damage": 7.5,
		"melee_mul": 1.1,
		"ranged_mul": 1.15,
		# Thrown as fast as a shuriken, and lobbed as every thrown thing is:
		# it arcs, and flies straight only with ANTI-GRAVITY on its graph.
		"projectile_speed": 1.4,
		"reach_mul": 1.0,
		"size_mul": 1.25,
		"gravity_shots": true,
		"thrown": true,
	},
	"SHOVEL": {
		"name": "Shovel",
		"desc": "A spade for a blade: it swings like anything heavy, and it digs. Hold the use key on lit ground to bring up what is buried there — loudly.",
		"root": "SLASH",
		"board": "shovel",
		"base_damage": 10.0,
		"melee_mul": 1.2,
		"ranged_mul": 0.6,
		"projectile_speed": 0.8,
		"reach_mul": 0.6,
		"size_mul": 1.1,
		"gravity_shots": false,
		"digs": true,
	},
	"RUNE": {
		"name": "Rune",
		"desc": "A stone with a charge stored in it, thrown as the rock is: the throw goes out charged, and costs you nothing. Thrown, it is spent: still a stone to throw, but bare, its skill gone out of it until you hold the cast button with it in hand to pour your own mana back in.",
		"root": "PROJECTILE",
		"board": "rune",
		"base_damage": 7.0,
		"melee_mul": 1.0,
		"ranged_mul": 1.15,
		# As the rock: as fast as a shuriken, and lobbed.
		"projectile_speed": 1.4,
		"reach_mul": 1.0,
		"size_mul": 1.15,
		"gravity_shots": true,
		"thrown": true,
		"rune": true,
	},
	"SHURIKEN": {
		"name": "Shuriken",
		"desc": "A stack of throwing stars, thrown with everything built into them. Each is lobbed, and sticks where it strikes; walk over one to take it back.",
		"root": "PROJECTILE",
		"board": "shuriken",
		"base_damage": 8.0,
		"melee_mul": 0.8,
		"ranged_mul": 1.1,
		"projectile_speed": 1.4,
		"reach_mul": 1.2,
		"size_mul": 0.85,
		# Lobbed, as every thrown thing is; straight only with ANTI-GRAVITY.
		"gravity_shots": true,
		"stack": 10,
	},
}

## The empty hand: what a hand with nothing in it casts — every slot of a kit no
## weapon is in (`Player.empty_handed`). The root of its graph is a PUNCH
## (`HEADBUTT`), the one form made with nothing in the hand, and it goes off only
## while every attack it makes is one (`Player.can_cast`). It is not a weapon:
## it is in no vault, on no rack and in no kit, and `ids` leaves it out. But it
## has a graph as a weapon does, kept in the profile beside theirs
## (`GameState.weapon_board`), with presets of its own, and these numbers.
const HAND := "HAND"
const HAND_DEF := {
	"name": "Empty hand",
	"desc": "Nothing in it but a fist: what the hand casts is a graph of punches.",
	"root": "HEADBUTT",
	"board": "hand",
	"base_damage": 8.0,
	"melee_mul": 1.0,
	"ranged_mul": 1.0,
	"projectile_speed": 1.0,
	"reach_mul": 1.0,
	"size_mul": 1.0,
	"gravity_shots": false,
}

static func get_def(id: String) -> Dictionary:
	if id == HAND:
		return HAND_DEF
	return DEFS.get(id, DEFS["SWORD"])

## The weapon's name and what it is like to swing, in the language being
## played. The `name` and `desc` above are the fallback under them, the same
## way `Components.name_for` falls back.
static func name_for(id: String) -> String:
	return Loc.opt("weapons.%s.name" % id, String(get_def(id)["name"]))

static func desc_for(id: String) -> String:
	return Loc.opt("weapons.%s.desc" % id, String(get_def(id)["desc"]))

static func ids() -> Array:
	return DEFS.keys()

## The part on the root of this weapon's graph: its own attack form.
static func root_part(id: String) -> String:
	return String(get_def(id)["root"])

## The starting payload every flow on this weapon begins with.
static func base_payload(weapon_id: String) -> Payload:
	var d := get_def(weapon_id)
	var p := Payload.new()
	p.damage = float(d["base_damage"])
	p.size = float(d["size_mul"])
	p.speed = float(d["projectile_speed"])
	return p

## The forms the body makes with nothing in its hands: the fist's, PUNCH. A graph whose
## every attack is one of them goes off whether its weapon is in hand or not
## (`Player.can_cast`), and the weapon's multipliers do not weigh it (`finalize`).
const BARE_FORMS := ["HEADBUTT"]

## Whether an attack of `form` is made with the weapon, so has to have it in hand.
static func needs_weapon(form: String) -> bool:
	return not BARE_FORMS.has(form)

## Weapon traits applied once the flow has resolved into an attack.
static func finalize(weapon_id: String, p: Payload) -> Payload:
	var d := get_def(weapon_id)
	match p.form:
		"HEADBUTT":
			# The fist strikes, not the weapon: none of its multipliers.
			pass
		"SLASH", "DASHSLASH":
			p.damage *= float(d["melee_mul"])
		"PROJECTILE":
			p.damage *= float(d["ranged_mul"])
			p.speed *= float(d["projectile_speed"])
			# How far the thing throws, which is the weapon's own answer and not
			# a side effect of how fast it throws: the gun reaches some seven
			# cells, the rock five, and a bolt off the sword not much more than
			# twice what a swing would have covered.
			p.range_px *= float(d["reach_mul"])
	# What a NEAR carries to the enemies round the one struck is no blow of the
	# weapon's, and nothing of the weapon weighs it: neither does it on a flow
	# with no form, where it is the attack.
	return p

static func uses_gravity_shots(weapon_id: String) -> bool:
	return bool(get_def(weapon_id)["gravity_shots"])

## Whether the weapon is itself what it throws: the rock. One flow of a cast
## sends it out of the hand, and the weapon casts nothing again until it has
## been picked back up.
static func is_thrown(weapon_id: String) -> bool:
	return bool(get_def(weapon_id).get("thrown", false))

## Whether the weapon is a rune: a thrown stone with mana in it, which a hold
## charges out of (`GameState.rune`).
static func is_rune(weapon_id: String) -> bool:
	return bool(get_def(weapon_id).get("rune", false))

## How many of the weapon a raid walks in with, when it is a stack of the same
## thing spent a throw at a time — the shuriken — or 0 for any other weapon.
static func stack_of(weapon_id: String) -> int:
	return int(get_def(weapon_id).get("stack", 0))

## Whether the weapon is a stack (`stack_of`).
static func is_stacked(weapon_id: String) -> bool:
	return stack_of(weapon_id) > 0

## Whether the weapon digs (`DigSpot`): the shovel, in hand on lit ground.
static func digs(weapon_id: String) -> bool:
	return bool(get_def(weapon_id).get("digs", false))

## The weapon's graph as a new profile gets it: its `board` in the content
## database (`data/db/boards/weapons.sql`), named after the weapon. What a
## player builds onto it is theirs and lives in the save; this is the bare one.
static func make_board(weapon_id: String) -> SkillBoard:
	return Boards.build(String(get_def(weapon_id)["board"]), name_for(weapon_id))
