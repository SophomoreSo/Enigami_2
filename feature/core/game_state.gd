extends Node

## Persistent player state: stash, weapons and the graph on each, hideout
## facilities, and the raid kit that is put at risk every time the player
## deploys.

signal stash_changed()
## The kit changed under whoever is showing it: a profile opened, a weapon's
## graph edited, a slot wiped.
signal kit_changed()
signal records_changed()
## What is added to the player's own numbers changed — a perk bought, a profile
## opened — and whoever holds one of those numbers takes it again (`boost`).
signal boosts_changed()
## Who is played as changed: a hero picked on a bench (`set_hero`).
signal hero_changed(id: String)

## How many profiles can be kept side by side. The title screen offers this
## many rows; `graphics/ui/title_screen.gd` reads it rather than counting its
## own, so the two cannot disagree.
const SAVE_SLOTS := 3

## Where a profile saved before there were slots lives. It is read once, at
## boot, and becomes slot 1 — see `_migrate_legacy_save`.
const SAVE_PATH := "user://enigami_save.json"

static func slot_path(n: int) -> String:
	return "user://enigami_save_%d.json" % clampi(n, 1, SAVE_SLOTS)

## Which profile is being played, 1..SAVE_SLOTS. Everything saved goes here,
## and the title screen sets it by opening one.
var slot: int = 1
## There is always another rock. It cannot be lost, so a run of bad raids never
## leaves the player with nothing to deploy.
const FREE_WEAPON := "ROCK"
## The most weapons a raid is walked into with. One is in hand at a time, and
## the others are a key away (`Player.switch_to`).
const MAX_CARRIED := 3

## --- hideout property -------------------------------------------------------
var stash: Dictionary = {}              ## component id -> count, safe at home
var owned_weapons: Array[String] = []
## Weapons every profile is handed, once: a new one starts with them, and one
## saved before a weapon was in the game is given it the first time it loads
## (`_hand_out`). Once only, so a weapon lost to a death since is not given back.
const HANDED_OUT := ["SHOVEL", "SHURIKEN", "RUNE"]
## Which of them this profile has been handed.
var handed_out: Array[String] = []
## weapon id -> the graph on it. A weapon is its graph: the weapon's own part
## on the root, and whatever the player has wired on after it. There is no
## skill without a weapon and no weapon without a graph, so a weapon lost on
## a raid takes its graph down with it, and one won back brings it home. The
## empty hand's is here too, under `Weapons.HAND`: it is no weapon, and nothing
## takes it down.
var weapon_boards: Dictionary = {}
## How many graphs every weapon keeps to choose between. Always this many, each
## weapon's, from the first: nothing is added and nothing taken away.
const GRAPH_PRESETS := 3
## weapon id -> its presets, `{"on": i, "kept": [serialized, ...]}`: which of
## the GRAPH_PRESETS is the graph on it, and the others as they were left — a
## blueprint each, `{}` for one never built on. The one `on` is the weapon's
## graph itself (`weapon_boards`, a raid's copy while one is out), and its
## entry in `kept` is whatever it was when it was last put away. A weapon with
## no entry is on its first, and has never put one away. See `switch_preset`.
var graph_presets: Dictionary = {}
## The weapons picked on the rack to carry, in the order they are slotted: at
## most MAX_CARRIED. It may still name a weapon the vault no longer has — one
## lost on a raid and not walked back out yet — and `carried` leaves those out.
var loadout: Array[String] = []
var scrap: int = 0
## The level every facility is at in a profile that has built nothing.
const FACILITY_START := 1
var facilities: Dictionary = {
	"workbench": FACILITY_START,  ## skill board size
	"vault": FACILITY_START,      ## stash capacity per component
	"forge": FACILITY_START,      ## craft components from scrap
	"scrapper": FACILITY_START,   ## scrap value when breaking things down
	"medbay": FACILITY_START,     ## max health and between-raid healing
}

## --- raid state -------------------------------------------------------------
var in_raid: bool = false
## The kit a raid was walked into with: the weapons, in slot order, and the live
## copy of the graph on each. A raid writes on its copies — an edit made in the
## field, a part spent out of the bag — and walking out is what takes them home.
var raid_weapons: Array[String] = []
var raid_graphs: Dictionary = {}          ## weapon id -> SkillBoard
## Which of them is in hand: the one that is cast, and the one assembly opens.
## The player says so as they switch (`Raid`), so a raid put down and picked
## back up is holding what it was holding.
var raid_hand: int = 0
## The weapon in hand, and the live copy of its graph. When a raid carried one
## weapon these were the whole kit, and everything that asks about "the raid's
## weapon" still means this one.
var raid_weapon: String:
	get:
		return raid_weapons[raid_hand] if raid_hand >= 0 and raid_hand < raid_weapons.size() else ""
var raid_board: SkillBoard:
	get:
		return raid_graphs.get(raid_weapon, null)
var raid_bag: Dictionary = {}             ## loose components found this raid
var raid_scrap: int = 0
var raid_seed: int = 0
## Weapons picked back up off a previous death, riding along. They are cargo
## rather than kit: a recovered weapon cannot be drawn mid-raid, so it only
## becomes the player's again by being walked out of the raid — and is dropped
## again by dying with it. It rides bare: what was built onto it went into the
## bag when it was picked up (`recover_lost_kit`).
var raid_carried_weapons: Array[String] = []
## A raid put down mid-run, or {}. MAIN MENU inside a raid writes the run here
## instead of ending it, and opening the slot again walks back into it.
##
## The map is laid again from the content database, so none of it is in here: what a run
## changes is which rooms hold what, where the player is standing and how they
## are doing, and the clock. See `Raid.park` for the shape, `RaidMap.to_save`
## for the rooms inside it.
var raid_progress: Dictionary = {}

## --- what a death leaves behind ---------------------------------------------
## Dying does not destroy the kit any more; it drops it. Everything the run was
## carrying is left lying on the spot the player fell on, and the next
## deployment goes back into the same map to fetch it: the seed is kept, so the
## floor is the same floor, the room is in the same place, and the drop is in
## the room it was left in.
##
## One drop at a time. Dying on the way back to it leaves a newer one and the
## older one is gone, which is what a second death costs. It is written into the
## save, because outliving the run that made it is the whole point of it.
##
## The shape:
##   {"seed": int, "room": [x, y], "pos": [x, y],
##    "weapons": [id], "boards": {id: serialized}, "bag": {id: n}, "scrap": int}
## `boards` holds the graph of every weapon that fell, the free one's included:
## the rock itself is never lost, but what was built onto it is.
var lost_kit: Dictionary = {}

## --- records ----------------------------------------------------------------
var records: Dictionary = {
	"raids": 0, "escapes": 0, "deaths": 0, "kills": 0, "best_haul": 0,
}

## Whether this profile has been shown the opening scene. It is kept with the
## profile rather than with the settings on purpose: starting a new game is what
## earns the prologue, and wiping a profile earns it again.
var intro_seen: bool = false

## What the people the player has met remember of them: fact -> whole number.
## Free talk writes it (`Facts`, in story/rules) and nothing here reads it; it
## is kept with the profile for the same reason `intro_seen` is — a new game
## is somebody new to them, and the next slot is somebody else.
var memory: Dictionary = {}

## The monster dictionary's: the monsters this profile has met in a raid, by
## kind, and which of their skills it has seen them use, as "KIND:board".
## Only a raid writes here (`Raid`) — the bench and the tests are not
## somewhere a monster is met — and a new game knows none of them.
var bestiary: Dictionary = {"monsters": [], "skills": []}
## The perks the player has bought: perk -> how many of its steps. Bought and
## read by perks/rules (`Perks`), which is what knows what a perk is; nothing
## here reads it. It is kept with the profile for the reason `memory` is.
var perks: Dictionary = {}

## The rune's store (`Rune`): the charge in it and whether it is spent, kept
## with the profile wherever the rune is. The rune is what knows what to do
## with it; this keeps it, saves it and reads it back.
var rune := Rune.new()

## Whatever adds to the player's own numbers from outside the rules: functions
## from a stat's name to what they add to it, each asked in turn by `boost`.
## The perks put theirs here (perks/rules), which is how what they add reaches
## the rules without the rules naming them. Nothing here, nothing added.
var boost_sources: Array[Callable] = []

const FACILITY_INFO := {
	"workbench": {"name": "Workbench", "max": 5},
	"vault": {"name": "Vault", "max": 5},
	"forge": {"name": "Forge", "max": 5},
	"scrapper": {"name": "Scrapper", "max": 5},
	"medbay": {"name": "Medbay", "max": 5},
}

## A facility's name, in the language being played. The table above is the
## fallback under it, so a facility added there is named before anybody
## translates it.
##
## What each one does is not written anywhere: the counter had a line along the
## bottom that said so while the mouse was on a row, and it was taken out.
func facility_name(key: String) -> String:
	return Loc.opt("hideout.facilities.info.%s.name" % key,
		String((FACILITY_INFO.get(key, {}) as Dictionary).get("name", key)))

func _ready() -> void:
	_migrate_legacy_save()
	# The one last written, so the records under the title menu belong to the
	# profile the player was last in rather than to whichever slot is first.
	load_slot(last_played_slot())

## A profile saved before there were slots becomes slot 1, so nobody loses one
## by updating. It runs once: after the rename there is nothing left to move.
func _migrate_legacy_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(slot_path(1)):
		return
	DirAccess.rename_absolute(ProjectSettings.globalize_path(SAVE_PATH),
		ProjectSettings.globalize_path(slot_path(1)))

## Gives a profile every weapon in `HANDED_OUT` it has not been handed yet.
func _hand_out() -> void:
	for w in HANDED_OUT:
		if handed_out.has(w):
			continue
		handed_out.append(w)
		if not owned_weapons.has(w):
			owned_weapons.append(w)

func _ensure_free_weapon() -> void:
	if not owned_weapons.has(FREE_WEAPON):
		owned_weapons.append(FREE_WEAPON)

## Builds a starting profile in memory, and only in memory. It used to write
## itself to disk on the way out, which is wrong now that a slot can be empty:
## booting would have stamped the first slot before the player had touched it,
## and emptying a slot would have filled it straight back in. Whoever wants this
## one kept says so.
func _new_profile() -> void:
	stash.clear()
	_forget_raid()
	lost_kit = {}
	# The hideout as a new game finds it. Left alone, the facilities were
	# whatever the profile open before this one had made of them, so a new game
	# started with somebody else's workbench.
	for key in facilities:
		facilities[key] = FACILITY_START
	records = {"raids": 0, "escapes": 0, "deaths": 0, "kills": 0, "best_haul": 0}
	intro_seen = false
	hero = Heroes.first()
	memory = {}
	bestiary = {"monsters": [], "skills": []}
	perks = {}
	rune.reset()
	owned_weapons = ["ROCK", "SWORD", "GUN", "SHOVEL", "SHURIKEN", "RUNE"]
	handed_out.assign(HANDED_OUT)
	loadout = []
	weapon_boards.clear()
	graph_presets = {}
	scrap = 40
	# A handful of parts to build a first graph with: something for every
	# weapon's root.
	for id in ["PROJECTILE", "SLASH", "DAMAGE", "FIRE", "PIERCE"]:
		stash[id] = 2
	for w in owned_weapons:
		weapon_boards[w] = Weapons.make_board(w)

## --- derived stats ----------------------------------------------------------
func max_health() -> float:
	return 80.0 + 20.0 * float(facilities["medbay"]) + boost("max_health")

## What everything in `boost_sources` adds to `stat`: `max_health`,
## `max_stamina` and `max_mana` in points, `max_charge` in the life a hold can
## buy, `move_speed`, `charge_speed` and `gold` as a share more, `cast_speed`
## as a share off the wait between casts.
func boost(stat: String) -> float:
	var total := 0.0
	for source in boost_sources:
		if source.is_valid():
			total += float(source.call(stat))
	return total

## What `amount` of gold found in a raid comes to, with what adds to it.
func gold_found(amount: int) -> int:
	return roundi(float(amount) * (1.0 + boost("gold")))

func board_size() -> Vector2i:
	var l: int = facilities["workbench"]
	return Vector2i(6 + l, 4 + l)

func stash_cap() -> int:
	return 4 + 3 * int(facilities["vault"])

func facility_cost(key: String) -> int:
	return 60 * int(facilities[key]) * int(facilities[key])

func can_upgrade(key: String) -> bool:
	return facilities[key] < int(FACILITY_INFO[key]["max"]) and scrap >= facility_cost(key)

func upgrade_facility(key: String) -> bool:
	if not can_upgrade(key):
		return false
	scrap -= facility_cost(key)
	facilities[key] += 1
	if key == "workbench":
		var s := board_size()
		for w in weapon_boards:
			(weapon_boards[w] as SkillBoard).resize_grid(s.x, s.y)
	stash_changed.emit()
	save_game()
	return true

## --- stash ------------------------------------------------------------------
func add_component(id: String, n: int = 1, pool: Variant = null) -> void:
	var target: Dictionary = stash if pool == null else (pool as Dictionary)
	var cap := stash_cap() if target == stash else 99
	target[id] = mini(int(target.get(id, 0)) + n, cap)
	stash_changed.emit()

func component_count(id: String, pool: Dictionary) -> int:
	return int(pool.get(id, 0))

func take_component(id: String, pool: Dictionary) -> bool:
	if int(pool.get(id, 0)) <= 0:
		return false
	pool[id] = int(pool[id]) - 1
	if pool[id] <= 0:
		pool.erase(id)
	stash_changed.emit()
	return true

func return_component(id: String, pool: Dictionary) -> void:
	pool[id] = int(pool.get(id, 0)) + 1
	stash_changed.emit()

## Trading what is built on a board for what another build needs, against a
## pool of parts: everything `have` is built out of goes back, and `need` — id
## to how many — comes out. A shared code is a blueprint and not the parts, so
## pasting one costs exactly what building it by hand would have; what it
## needs is `SkillBoard.adoption_cost`, which is also why the sandbox, where
## parts are free, never asks. The root is the weapon's and is in neither.
##
## All or nothing. If the pool cannot cover the difference nothing moves at all,
## so a refused paste leaves the bag exactly as it found it, and what is missing
## comes back instead: id -> how many more are needed. `{}` means it went
## through. `have` may be null, for a board being filled from nothing.
func trade_board(have: SkillBoard, need: Dictionary, pool: Dictionary) -> Dictionary:
	var back: Dictionary = have.used_components() if have != null else {}
	var missing: Dictionary = {}
	for id in need:
		var short := int(need[id]) - int(back.get(id, 0)) - int(pool.get(id, 0))
		if short > 0:
			missing[id] = short
	if not missing.is_empty():
		return missing
	for id in back:
		for i in int(back[id]):
			return_component(id, pool)
	for id in need:
		for i in int(need[id]):
			take_component(id, pool)
	return {}

## What the forge asks: this much scrap and this many spare parts, melted down
## for one random part from the loot pool. The counter's button greys itself on
## `can_forge`, so the price is written here once and on no screen.
const FORGE_COST := 25
const FORGE_INPUTS := 3

## Whether the forge would take what is on the shelves: the scrap, and enough
## spare parts to melt, of whatever kind.
func can_forge() -> bool:
	return scrap >= FORGE_COST and stash_total() >= FORGE_INPUTS

## Every part on the shelves, of every kind.
func stash_total() -> int:
	var n := 0
	for id in stash:
		n += int(stash[id])
	return n

## Forge: spend the scrap and the spare parts for one random better part.
func forge_component(inputs: Array[String]) -> String:
	if inputs.size() < FORGE_INPUTS or scrap < FORGE_COST:
		return ""
	for id in inputs:
		if not take_component(id, stash):
			return ""
	scrap -= FORGE_COST
	var pool := Components.loot_pool()
	var out: String = pool[randi() % pool.size()]
	add_component(out, 1)
	save_game()
	return out

## --- the merchant -----------------------------------------------------------
## What a part costs at the counter, by what kind of part it is. Every price is
## above what breaking one down pays — a scrapper at its cap returns 25 — so
## buying a part to scrap it is never a trade, at any level of the hideout.
const SHOP_PRICES := {
	Components.CAT_FORM: 60,
	Components.CAT_STATES: 55,
	Components.CAT_BEHAVIOR: 65,
	Components.CAT_PROJECTILE_BEHAVIOR: 65,
	Components.CAT_SUMMON_BEHAVIOR: 65,
	Components.CAT_FLOW: 70,
	Components.CAT_TRIGGER: 55,
}

## What the counter is selling: every part, in palette order.
func shop_stock() -> Array:
	return Components.loot_pool()

func shop_price(id: String) -> int:
	var cat := String(Components.get_def(id).get("cat", Components.CAT_BEHAVIOR))
	return int(SHOP_PRICES.get(cat, 50))

func can_buy(id: String) -> bool:
	return Components.exists(id) and scrap >= shop_price(id) \
		and component_count(id, stash) < stash_cap()

## One part, bought. False when the scrap is short or the vault has no room for
## another of that part — the stash cap is per component, and a purchase that
## silently vanished into a full shelf would be scrap for nothing.
func buy_component(id: String) -> bool:
	if not can_buy(id):
		return false
	scrap -= shop_price(id)
	add_component(id, 1)
	save_game()
	return true

func scrap_component(id: String) -> int:
	if not take_component(id, stash):
		return 0
	var gain := 5 * int(facilities["scrapper"])
	scrap += gain
	stash_changed.emit()
	save_game()
	return gain

## --- the weapons' graphs ----------------------------------------------------

## The graph on `weapon_id`, the board its runner walks. A weapon with none yet
## — a profile written before weapons had graphs, a weapon just won back with
## nothing on it — is handed the bare one it started with, and keeps it.
func weapon_board(weapon_id: String) -> SkillBoard:
	if not weapon_boards.has(weapon_id):
		var b := Weapons.make_board(weapon_id)
		var s := board_size()
		b.resize_grid(s.x, s.y)
		weapon_boards[weapon_id] = b
	return weapon_boards[weapon_id]

## Whether nothing has been built onto `weapon_id`'s graph: the root and the
## structure, and no part of the player's own.
func graph_is_bare(weapon_id: String) -> bool:
	return not weapon_boards.has(weapon_id) \
		or (weapon_boards[weapon_id] as SkillBoard).used_components().is_empty()

## Which of the weapon's GRAPH_PRESETS is the graph on it, 0 to the last.
func preset_on(weapon_id: String) -> int:
	return clampi(int((graph_presets.get(weapon_id, {}) as Dictionary).get("on", 0)), 0, GRAPH_PRESETS - 1)

## Puts `weapon_id`'s preset `to` on it: the graph on it now is kept as the one
## it was, and `to`'s is built in its place, on the same board — the raid's copy
## while one is out, and the parts out of the raid's bag; at home the weapon's
## own, and out of the stash.
##
## A kept preset is a blueprint and not the parts, the way a shared code is
## (`trade_board`): the parts the graph is built of go back as it is put away,
## and the ones the preset needs come out, so a part is only ever on the graph
## in use and is never locked up in one put away. That is also why a preset is
## not lost with the weapon: a death takes the graph on it, and what it was
## built of, and the others are only how to build them again. A preset never
## built on is the weapon's bare graph, and putting it on puts everything else
## back on the shelves.
##
## All or nothing, as a paste is: with the parts short nothing moves and the
## weapon stays on the one it was on, and what is missing comes back, id ->
## how many more. `{}` means it went through, and it is saved there and then.
func switch_preset(weapon_id: String, to: int) -> Dictionary:
	var on := preset_on(weapon_id)
	if to == on or to < 0 or to >= GRAPH_PRESETS:
		return {}
	var out := in_raid and raid_graphs.has(weapon_id)
	var board: SkillBoard = raid_graphs[weapon_id] if out else weapon_board(weapon_id)
	var pool: Dictionary = raid_bag if out else stash
	var kept := _kept_presets(weapon_id)
	var want := Weapons.make_board(weapon_id)
	if not (kept[to] as Dictionary).is_empty():
		want = SkillBoard.deserialize(kept[to])
	# The grid only grows, so a preset kept on it always fits; one that somehow
	# does not is built again from bare rather than in pieces.
	if not board.fits(want):
		want = Weapons.make_board(weapon_id)
	var missing := trade_board(board, board.adoption_cost(want), pool)
	if not missing.is_empty():
		return missing
	kept[on] = board.serialize()
	board.adopt(want)
	graph_presets[weapon_id] = {"on": to, "kept": kept}
	kit_changed.emit()
	save_game()
	return {}

## `weapon_id`'s presets as they were put away, GRAPH_PRESETS of them: `{}` for
## one never built on.
func _kept_presets(weapon_id: String) -> Array:
	var kept: Array = ((graph_presets.get(weapon_id, {}) as Dictionary).get("kept", []) as Array).duplicate()
	kept.resize(GRAPH_PRESETS)
	for i in kept.size():
		if not (kept[i] is Dictionary):
			kept[i] = {}
	return kept

## Parts a graph is built out of, `board`'s player-placed ones, back on the
## shelves. What the vault has no room for is lost, as it is for any haul.
func _shelve_parts(board: SkillBoard) -> void:
	var used := board.used_components()
	for id in used:
		add_component(String(id), int(used[id]))

## --- the kit the gate carries -----------------------------------------------

## The weapons a deployment would carry, in slot order: the ones picked on the
## rack that the vault still has. Never none while the vault has any — with
## nothing picked it is the first weapon on the rack, which is what the rack
## was always left on.
func carried() -> Array[String]:
	var out: Array[String] = []
	for w in loadout:
		if owned_weapons.has(w) and not out.has(w) and out.size() < MAX_CARRIED:
			out.append(w)
	if out.is_empty() and not owned_weapons.is_empty():
		out.append(owned_weapons[0])
	return out

func is_carried(weapon_id: String) -> bool:
	return carried().has(weapon_id)

## Puts `weapon_id` in the kit, if the vault has it. With a slot free it takes
## the next one. With none, it takes the slot of `instead_of` — the weapon the
## rack was on — or the last. Whether it is carried now.
func carry(weapon_id: String, instead_of: String = "") -> bool:
	if not owned_weapons.has(weapon_id):
		return false
	var kit := carried()
	if kit.has(weapon_id):
		return true
	if kit.size() < MAX_CARRIED:
		kit.append(weapon_id)
	else:
		var at := kit.find(instead_of)
		kit[at if at >= 0 else kit.size() - 1] = weapon_id
	loadout = kit
	kit_changed.emit()
	save_game()
	return true

## Takes `weapon_id` out of the kit. The last one stays: a raid is not walked
## into empty-handed. Whether it was left.
func leave_behind(weapon_id: String) -> bool:
	var kit := carried()
	if kit.size() <= 1 or not kit.has(weapon_id):
		return false
	kit.erase(weapon_id)
	loadout = kit
	kit_changed.emit()
	save_game()
	return true

## --- raid lifecycle ---------------------------------------------------------
## Deploying binds the kit — every weapon carried, and the graph on each — into
## something that is lost on death. Everything left at home stays safe.
##
## `kit` is the weapons to carry, in slot order, or one weapon's id for a kit
## of one; with neither it is what the rack was left on (`carried`). `in_hand`
## is the one walked in holding: the first, unless it says.
func deploy(kit: Variant = null, in_hand: String = "") -> void:
	var ids: Array[String] = []
	if kit is String:
		ids.append(String(kit))
	elif kit is Array:
		for w in kit:
			if not ids.has(String(w)) and ids.size() < MAX_CARRIED:
				ids.append(String(w))
	if ids.is_empty():
		ids = carried()
	in_raid = true
	raid_weapons = ids
	raid_graphs.clear()
	for w in ids:
		raid_graphs[w] = weapon_board(w).duplicate_board()
	# The empty hand goes out with a copy of its graph as the weapons do, built
	# onto out of the bag; it comes home on the way out and is never lost.
	raid_graphs[Weapons.HAND] = weapon_board(Weapons.HAND).duplicate_board()
	raid_hand = maxi(ids.find(in_hand), 0)
	raid_bag.clear()
	raid_scrap = 0
	raid_carried_weapons.clear()
	# A kit still lying where a death left it decides which map this is. The
	# same seed builds the same floor, so the room it was dropped in is in the
	# same place with the same way in — going back for it is a route the player
	# has already walked. With nothing waiting, the floor is rolled fresh.
	raid_seed = int(lost_kit.get("seed", 0)) if has_lost_kit() else randi()
	if raid_seed == 0:
		raid_seed = 1   # 0 reads as "no seed" to the raid; never hand it one
	# A fresh deployment, not the one that was put down: nothing of the last
	# raid's progress belongs to this one.
	raid_progress = {}
	for w in ids:
		if w != FREE_WEAPON:
			owned_weapons.erase(w)
	records["raids"] = int(records["raids"]) + 1
	records_changed.emit()
	save_game()

func extract() -> Dictionary:
	# Edits made mid-raid come home with the kit: the parts spent on them left
	# the bag when they were placed, so nothing is counted twice.
	for w in raid_weapons + [Weapons.HAND]:
		if raid_graphs.has(w):
			weapon_boards[w] = raid_graphs[w]
	# Whatever was recovered from an earlier death comes home as its own: the
	# weapon back on the rack, bare. What was built onto it was in the bag, so
	# it comes home with the haul, or on whichever graph it was built onto since.
	var recovered: Array[String] = []
	for w in raid_carried_weapons:
		if not owned_weapons.has(w):
			owned_weapons.append(w)
		recovered.append(Weapons.name_for(w))
	var haul := raid_bag.duplicate()
	for id in haul:
		add_component(id, int(haul[id]))
	scrap += raid_scrap
	for w in raid_weapons:
		if not owned_weapons.has(w):
			owned_weapons.append(w)
	records["escapes"] = int(records["escapes"]) + 1
	records["best_haul"] = max(int(records["best_haul"]), _haul_size(haul))
	var result := {"haul": haul, "scrap": raid_scrap, "weapon": raid_weapon,
		"weapons": raid_weapons.duplicate(), "recovered": recovered}
	_end_raid()
	return result

## The whole kit leaves with the run: every weapon carried, the graph on each
## (and every part built into it), and everything found on the way. None of it
## is destroyed — it is put down where the player fell, and `where` is that
## spot, as `{"room": [x, y], "pos": [x, y]}` from the raid. The free weapon is
## not lost, but its graph is: it comes back to the rack bare.
##
## Called with nowhere to leave it, the kit is simply gone, which is what it has
## always been and what ABANDON RAID still means: forfeiting is a decision, and
## a decision does not leave a trail to follow back.
func die(where: Dictionary = {}) -> Dictionary:
	# What was built onto the weapons that fell, all of them together.
	var parts: Dictionary = {}
	for w in raid_weapons:
		if raid_graphs.has(w):
			_bag_parts(raid_graphs[w], parts)
	var lost := {
		"weapon": raid_weapon, "weapons": raid_weapons.duplicate(),
		"haul": raid_bag.duplicate(), "scrap": raid_scrap,
		"parts": parts, "dropped": false,
	}
	if _can_drop(where):
		lost_kit = _drop_at(where)
		lost["dropped"] = true
	# The graphs went down with the weapons, whichever weapons they were. The
	# empty hand's stays at home as it went out: what was built onto its copy
	# went down with the run.
	for w in raid_weapons:
		weapon_boards.erase(w)
	records["deaths"] = int(records["deaths"]) + 1
	_end_raid()
	return lost

func has_lost_kit() -> bool:
	return not lost_kit.is_empty()

## Whether there is a spot to leave the kit on at all. A room and a position in
## it are what the next raid needs to put it back on the floor; without both
## there is nowhere to go and get it.
func _can_drop(where: Dictionary) -> bool:
	return (where.get("room", []) as Array).size() == 2 \
		and (where.get("pos", []) as Array).size() == 2

## Everything this run was carrying, written down as one drop.
##
## What is dropped is the raid's own copy of each graph, edits and all, the same
## ones extracting would have written home — under the weapon each is on, and
## the free weapon's graph as much as any, since that is what was built and lost.
func _drop_at(where: Dictionary) -> Dictionary:
	var boards: Dictionary = {}
	for w in raid_weapons:
		if raid_graphs.has(w):
			boards[w] = (raid_graphs[w] as SkillBoard).serialize()
	var weapons: Array = []
	for w in raid_weapons:
		if w != FREE_WEAPON and not weapons.has(w):
			weapons.append(w)
	for w in raid_carried_weapons:
		if not weapons.has(w):
			weapons.append(w)
	return {
		"seed": raid_seed,
		"room": (where["room"] as Array).duplicate(),
		"pos": (where["pos"] as Array).duplicate(),
		"weapons": weapons,
		"boards": boards,
		"bag": raid_bag.duplicate(),
		"scrap": raid_scrap,
	}

## Picking a drop up puts it back into the run, not into the vault: what is
## recovered is being carried, and it has to be walked out of the raid like
## everything else found down here. Dying with it drops the lot again.
##
## Every part in it goes into the bag — the ones built onto the graphs that
## fell as much as the loose ones — so the bench can build them onto what is
## in hand there and then. The weapons ride along as cargo, bare.
##
## Returns what was in it, for whoever is announcing it, or {} when there was
## nothing to pick up.
func recover_lost_kit() -> Dictionary:
	if not has_lost_kit():
		return {}
	var kit := lost_kit.duplicate(true)
	for id in kit.get("bag", {}):
		if Components.is_retired(String(id)):
			continue
		add_component(Components.current_id(String(id)), int((kit["bag"] as Dictionary)[id]), raid_bag)
	raid_scrap += int(kit.get("scrap", 0))
	var boards: Dictionary = kit.get("boards", {})
	for w in boards:
		var used := SkillBoard.deserialize(boards[w]).used_components()
		for id in used:
			add_component(String(id), int(used[id]), raid_bag)
	for w in kit.get("weapons", []):
		if not raid_carried_weapons.has(String(w)):
			raid_carried_weapons.append(String(w))
	lost_kit = {}
	save_game()
	return kit

## How much is lying out there, as one number, for a screen that wants to say
## whether a drop is worth the walk rather than list it.
func lost_kit_size() -> int:
	return kit_size(lost_kit) if has_lost_kit() else 0

## What a drop holds, as one number: a weapon counts for one, and so does every
## part built onto a graph that fell and every component in the bag. Scrap is
## not counted — it is the one thing in a drop that is only worth what it says.
func kit_size(kit: Dictionary) -> int:
	var n: int = (kit.get("weapons", []) as Array).size()
	var boards: Dictionary = kit.get("boards", {})
	for w in boards:
		var used := SkillBoard.deserialize(boards[w]).used_components()
		for id in used:
			n += int(used[id])
	return n + _haul_size(kit.get("bag", {}))

## A raid is over and what it cost or paid has been settled. Written out on the
## spot: the drop a death leaves is the one piece of a run that is meant to be
## found by a later one, and a kit that only existed until the app closed would
## be a promise the save could not keep.
func _end_raid() -> void:
	_ensure_free_weapon()
	_forget_raid()
	records_changed.emit()
	save_game()

## Everything a raid holds, dropped. On its own this is not an outcome — the
## kit is neither carried home nor lost by it — so only `extract`, `die` and a
## new profile call it, each having already settled what became of the kit.
func _forget_raid() -> void:
	in_raid = false
	raid_weapons = []
	raid_graphs.clear()
	raid_hand = 0
	raid_bag.clear()
	raid_scrap = 0
	raid_carried_weapons.clear()
	raid_progress = {}

## Puts the raid down where it stands, and writes it out. `where` is what the
## raid knows about itself; the kit it was carrying is already here.
##
## The run is not over: `in_raid` stays true, the kit stays checked out of the
## vault, and nothing is counted. Picking the slot back up resumes it.
func park_raid(where: Dictionary) -> void:
	if not in_raid:
		return
	raid_progress = where
	save_game()

## Whether opening this slot walks back into a raid rather than the hideout.
func has_parked_raid() -> bool:
	return in_raid and not raid_progress.is_empty()

## A raid left in memory with nothing written down cannot be resumed — the app
## was closed mid-run rather than parked. The kit went with it, the way it
## always has; this only stops the flag outliving the raid it describes.
func drop_unparked_raid() -> void:
	if in_raid and raid_progress.is_empty():
		_end_raid()
		save_game()
	save_game()

func _haul_size(d: Dictionary) -> int:
	var n := 0
	for k in d:
		n += int(d[k])
	return n

func register_kill() -> void:
	records["kills"] = int(records["kills"]) + 1

## --- the monster dictionary -------------------------------------------------
func knows_monster(kind: String) -> bool:
	return (bestiary["monsters"] as Array).has(kind)

func knows_skill(kind: String, skill: String) -> bool:
	return (bestiary["skills"] as Array).has("%s:%s" % [kind, skill])

## A monster met. Saved on the spot when it is the first of its kind: what has
## been seen stays seen, whatever happens to the raid it was seen in.
func discover_monster(kind: String) -> void:
	if knows_monster(kind):
		return
	(bestiary["monsters"] as Array).append(kind)
	save_game()

## A monster seen using `skill`, which is a sight of the monster as well.
func discover_skill(kind: String, skill: String) -> void:
	if knows_skill(kind, skill):
		return
	if not knows_monster(kind):
		(bestiary["monsters"] as Array).append(kind)
	(bestiary["skills"] as Array).append("%s:%s" % [kind, skill])
	save_game()

## The opening scene has been played, or skipped. Saved on the spot: a prologue
## sat through once is never sat through again, whatever happens after it.
## Who the player plays as: a hero of the roster (`Heroes`), chosen sat down on
## a bench (`HeroSelect`). What it changes is to come; for now it is kept with
## the profile.
var hero: String = ""

## The hero picked on a bench: kept, and said. One not on the roster is not
## taken.
func set_hero(id: String) -> void:
	if id == hero or not Heroes.exists(id):
		return
	hero = id
	save_game()
	hero_changed.emit(id)

func mark_intro_seen() -> void:
	if intro_seen:
		return
	intro_seen = true
	save_game()

## What the profile says about itself, as whole numbers by name — what a free
## talker's criteria may ask about it without knowing where each number is
## kept. The ids are the `game` facts in data/db/schema.sql; a number added
## here is one more a line can ask about, once the schema names it.
func facts() -> Dictionary:
	return {
		"raids": int(records["raids"]),
		"escapes": int(records["escapes"]),
		"deaths": int(records["deaths"]),
		"kills": int(records["kills"]),
		"best_haul": int(records["best_haul"]),
		"scrap": scrap,
		"kit_waiting": 1 if has_lost_kit() else 0,
	}

## Writes the profile down for what a conversation changed in `memory` — unless
## the slot has never been written. The sandbox is open from the title with no
## slot picked, and something said there is no reason to stamp an empty slot
## with a profile nobody started (see `_new_profile`).
func keep_memory() -> void:
	if FileAccess.file_exists(slot_path(slot)):
		save_game()

## --- persistence ------------------------------------------------------------

## What the title screen needs to draw a slot without opening it: when it was
## last written, and what the profile in it has done. Reading a slot is not the
## same as playing it, so this never touches the live profile.
static func slot_info(n: int) -> Dictionary:
	var path := slot_path(n)
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var d: Dictionary = parsed
	return {"saved_at": int(d.get("saved_at", 0)), "records": d.get("records", {})}

## Whether there is a profile in slot `n` at all.
static func slot_used(n: int) -> bool:
	return not slot_info(n).is_empty()

## The slot written to most recently, or 1 when none has been.
static func last_played_slot() -> int:
	var best := 1
	var newest := 0
	for n in range(1, SAVE_SLOTS + 1):
		var at := int(slot_info(n).get("saved_at", 0))
		if at > newest:
			newest = at
			best = n
	return best

## Opens slot `n` — its profile if it has one, a fresh one if it does not — and
## makes it the slot everything saved from now on goes to.
func load_slot(n: int) -> bool:
	slot = clampi(n, 1, SAVE_SLOTS)
	var found := _read_save(slot_path(slot))
	if not found:
		_new_profile()
	_ensure_free_weapon()
	stash_changed.emit()
	kit_changed.emit()
	records_changed.emit()
	boosts_changed.emit()
	return found

## Throws a profile away. There is no undo, which is why the screen that offers
## it asks twice. Emptying the slot being played leaves a new profile in memory,
## so nothing goes on showing the records of a save that no longer exists.
func delete_slot(n: int) -> void:
	var path := slot_path(n)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if clampi(n, 1, SAVE_SLOTS) == slot:
		_new_profile()
		_ensure_free_weapon()
		stash_changed.emit()
		kit_changed.emit()
		records_changed.emit()
		boosts_changed.emit()

func _boards_out(boards: Dictionary) -> Dictionary:
	var out := {}
	for w in boards:
		out[w] = (boards[w] as SkillBoard).serialize()
	return out

func save_game() -> void:
	var data := {
		"saved_at": int(Time.get_unix_time_from_system()),
		"stash": stash,
		"weapons": owned_weapons,
		"handed_out": handed_out,
		"loadout": loadout,
		"weapon_boards": _boards_out(weapon_boards),
		"graph_presets": graph_presets,
		"scrap": scrap,
		"facilities": facilities,
		"records": records,
		"intro_seen": intro_seen,
		"hero": hero,
		"memory": memory,
		"bestiary": bestiary,
		"perks": perks,
		"rune_mana": rune.mana,
		"rune_spent": rune.spent,
		# The raid in progress, if there is one. It used to be left out, so a
		# profile saved mid-raid came back with the weapon gone from the vault
		# and no raid to account for it.
		"in_raid": in_raid,
		"raid_weapons": raid_weapons,
		"raid_graphs": _boards_out(raid_graphs),
		"raid_hand": raid_hand,
		"raid_bag": raid_bag,
		"raid_scrap": raid_scrap,
		"raid_seed": raid_seed,
		"raid_progress": raid_progress,
		"raid_carried_weapons": raid_carried_weapons,
		# Not raid state: a drop is what is left of a raid that is over, and it
		# has to still be there when the next one is deployed.
		"lost_kit": lost_kit,
	}
	var f := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()

## Reads the slot being played back off disk.
func load_game() -> bool:
	return _read_save(slot_path(slot))

func _read_save(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	stash.clear()
	for k in parsed.get("stash", {}):
		# A part the game no longer has leaves the shelves: DASH was in every
		# profile's first stash.
		if Components.is_retired(String(k)):
			continue
		stash[Components.current_id(String(k))] = int(parsed["stash"][k])
	owned_weapons.clear()
	for w in parsed.get("weapons", ["SWORD"]):
		owned_weapons.append(String(w))
	handed_out.clear()
	for w in parsed.get("handed_out", []):
		handed_out.append(String(w))
	_hand_out()
	# A profile saved before there was a kit to pick has none, which reads as
	# the rack left where it always was: on its first weapon.
	loadout = []
	for w in parsed.get("loadout", []):
		if not loadout.has(String(w)):
			loadout.append(String(w))
	weapon_boards.clear()
	var graphs = parsed.get("weapon_boards", {})
	if graphs is Dictionary:
		for w in graphs:
			weapon_boards[String(w)] = SkillBoard.deserialize(graphs[w])
	# A profile saved before there were presets is on every weapon's first, and
	# has put none away.
	graph_presets = {}
	var presets = parsed.get("graph_presets", {})
	if presets is Dictionary:
		for w in presets:
			var p = presets[w]
			if p is Dictionary:
				graph_presets[String(w)] = {"on": int(p.get("on", 0)),
					"kept": p.get("kept", []) if p.get("kept", []) is Array else []}
	scrap = int(parsed.get("scrap", 0))
	# Every facility as the save has it, and one the save says nothing of at
	# its first level — not at whatever the profile open before this one had.
	var fac: Dictionary = parsed.get("facilities", {})
	for k in facilities:
		facilities[k] = int(fac[k]) if fac.has(k) else FACILITY_START
	# A profile saved before there was an opening scene has already played the
	# game, so it is not shown one now.
	intro_seen = bool(parsed.get("intro_seen", true))
	# A profile from before there were heroes, or naming one no longer there,
	# plays as the first.
	hero = String(parsed.get("hero", ""))
	if not Heroes.exists(hero):
		hero = Heroes.first()
	# Whole numbers going in; JSON hands every number back as a float.
	memory = {}
	var kept = parsed.get("memory", {})
	if kept is Dictionary:
		for k in kept:
			memory[String(k)] = int(kept[k])
	# A profile saved before there were perks has bought none.
	perks = {}
	var bought = parsed.get("perks", {})
	if bought is Dictionary:
		for k in bought:
			perks[String(k)] = int(bought[k])
	# A save from before the rune has it full (`Rune.load`).
	rune.load(parsed)
	# The same for the records: one the save does not mention is nought.
	var rec: Dictionary = parsed.get("records", {})
	for k in records:
		records[k] = int(rec.get(k, 0))
	# A profile saved before the dictionary has met nothing yet.
	bestiary = {"monsters": [], "skills": []}
	var dex = parsed.get("bestiary", {})
	if dex is Dictionary:
		for key in ["monsters", "skills"]:
			for v in (dex as Dictionary).get(key, []):
				(bestiary[key] as Array).append(String(v))
	lost_kit = _kit_read(parsed.get("lost_kit", {}))
	_read_raid(parsed)
	_read_library(parsed)
	return true

## The raid half of a save. A profile written before raids were kept has none
## of these keys, which reads as a profile standing in the hideout — which is
## what it was.
func _read_raid(parsed: Dictionary) -> void:
	_forget_raid()
	if not bool(parsed.get("in_raid", false)):
		return
	in_raid = true
	var kit = parsed.get("raid_weapons", [])
	if kit is Array and not (kit as Array).is_empty():
		var graphs = parsed.get("raid_graphs", {})
		for w in kit:
			var id := String(w)
			if raid_weapons.has(id) or raid_weapons.size() >= MAX_CARRIED:
				continue
			raid_weapons.append(id)
			if graphs is Dictionary and (graphs as Dictionary).has(id):
				raid_graphs[id] = SkillBoard.deserialize(graphs[id])
		raid_hand = clampi(int(parsed.get("raid_hand", 0)), 0, raid_weapons.size() - 1)
	else:
		# A raid written when one weapon was all a raid carried: a kit of one.
		var one := String(parsed.get("raid_weapon", ""))
		if one != "":
			raid_weapons.append(one)
			var board = parsed.get("raid_board", {})
			if board is Dictionary and not (board as Dictionary).is_empty():
				raid_graphs[one] = SkillBoard.deserialize(board)
	for k in parsed.get("raid_bag", {}):
		if Components.is_retired(String(k)):
			continue
		raid_bag[Components.current_id(String(k))] = int(parsed["raid_bag"][k])
	# A raid written before weapons had graphs carried a list of boards; what
	# was built on them rides on in the bag, and the weapon's own bare graph
	# stands in for the one it never had.
	for b in parsed.get("raid_boards", []):
		_bag_parts(SkillBoard.deserialize(b), raid_bag)
	for w in raid_weapons:
		if not raid_graphs.has(w):
			raid_graphs[w] = Weapons.make_board(w)
	# The empty hand's copy, or one of the graph at home for a raid written
	# before the hand had one.
	var out = parsed.get("raid_graphs", {})
	if out is Dictionary and (out as Dictionary).has(Weapons.HAND):
		raid_graphs[Weapons.HAND] = SkillBoard.deserialize(out[Weapons.HAND])
	else:
		raid_graphs[Weapons.HAND] = weapon_board(Weapons.HAND).duplicate_board()
	# Recovered weapons used to ride with the graphs they fell with, as a list
	# of boards and then by weapon. What was built on those rides on in the
	# bag now, the way a drop picked up today does.
	var cargo = parsed.get("raid_carried_boards", {})
	if cargo is Dictionary:
		for w in cargo:
			_bag_parts(SkillBoard.deserialize(cargo[w]), raid_bag)
	elif cargo is Array:
		for b in cargo:
			_bag_parts(SkillBoard.deserialize(b), raid_bag)
	for w in parsed.get("raid_carried_weapons", []):
		raid_carried_weapons.append(String(w))
	raid_scrap = int(parsed.get("raid_scrap", 0))
	raid_seed = int(parsed.get("raid_seed", 0))
	raid_progress = parsed.get("raid_progress", {})

## A profile written while skills were boards of their own, kept in a library
## and slotted into weapons. The weapons have graphs now and the library is
## gone: what was built on those boards goes onto the shelves, so nothing the
## player found or made is lost, and each weapon starts from its bare graph.
func _read_library(parsed: Dictionary) -> void:
	for s in parsed.get("skills", []):
		_shelve_parts(SkillBoard.deserialize(s))

## A drop as an older save wrote it, brought up to date: its boards were a
## list of skills, and are a graph per weapon now, so what those skills were
## built out of goes into the drop's bag instead — it is picked up all at once
## either way.
func _kit_read(kit: Dictionary) -> Dictionary:
	if kit.is_empty():
		return {}
	var out := kit.duplicate(true)
	var boards = out.get("boards", {})
	if boards is Array:
		var bag: Dictionary = out.get("bag", {})
		for b in boards:
			_bag_parts(SkillBoard.deserialize(b), bag)
		out["bag"] = bag
		out["boards"] = {}
	return out

## `board`'s player-placed parts, counted into `bag`.
func _bag_parts(board: SkillBoard, bag: Dictionary) -> void:
	var used := board.used_components()
	for id in used:
		bag[id] = int(bag.get(id, 0)) + int(used[id])

## Starts this slot over. The wipe is meant to stick, so it is written out.
func reset_profile() -> void:
	_new_profile()
	_ensure_free_weapon()
	save_game()
	stash_changed.emit()
	kit_changed.emit()
	boosts_changed.emit()
