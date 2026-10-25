class_name Loadout
extends RefCounted

## The kit in the player's hands: the weapons carried, in slot order, and the
## graph of each run live; which slot is in hand; the thrown weapons by whose
## hands each is in, and the stacked ones by how many are left; and the empty
## hand's graph, which every slot no weapon is in casts. What was a dozen
## fields and as many methods of `Player`'s own. The player keeps the names
## the rest of the game reads them by and reaches in.
##
## It knows how a kit is held, and nothing of what is done with it: who the
## hands are for a thrown weapon is an actor it is told, the runners are made
## by whoever hands the kit out (`setup`'s `make_runner`), and charging,
## possession and magic are the player's. Nothing here draws.

const MAX_WEAPONS := 3
## The slots: one a weapon carried, and one more the empty hand's, so the
## fourth — or the second and third while fewer are carried — is an empty hand.
const SLOTS := MAX_WEAPONS + 1

## The weapons carried, in slot order, and the graph of each, run live. A
## weapon is its skill, so this is every skill the player has to hand.
var weapons: Array[String] = []
var runners: Array[SkillRunner] = []
## The empty hand's graph, and its runner (`Weapons.HAND`). Whoever hands the
## kit out says which board it is, before they do; otherwise a bare one is
## made, PUNCH alone, and kept from one kit to the next.
var hand_board: SkillBoard = null
var hand_runner: SkillRunner = null
## Which slot is in hand, and so which of them the buttons fire: 0 to SLOTS - 1,
## a weapon's while it is under `weapons.size()` and an empty hand from there.
var hand: int = 0
## The weapon in hand and its runner: `weapons[hand]` and `runners[hand]`, kept
## beside them because nearly everything that asks about the player's weapon
## means this one — and with an empty hand in hand, no weapon ("") and the
## empty hand's runner.
var weapon_id: String = "SWORD"
var runner: SkillRunner = null
## The thrown weapons carried (`Weapons.is_thrown`) — the rock — by whose hands
## each is in: the body, or the monster the player is in. One out of hand has
## no entry: it is in the air, or lying where it came down (`LooseRock`). A
## thrown weapon is cast only from the hands holding it.
var holders: Dictionary = {}
## The stacked weapons carried (`Weapons.is_stacked`) — the shuriken — and how
## many of each are in hand: weapon id -> count, never more than its stack.
var stock: Dictionary = {}
## Runner -> whether every attack its graph fires is a HEADBUTT (`bare_handed`),
## walked once a graph and thrown away whenever a graph or the kit changes.
var _bare: Dictionary = {}

## Hands over a kit: up to MAX_WEAPONS weapons, in slot order, the graph on
## each, and which slot is in hand — one with no weapon in it for none. The
## runners are rebuilt wholesale by `make_runner` (a weapon and its board to a
## runner); the old ones go away with their signals.
##
## A thrown weapon comes in `body`'s hand — unless the kit before this one had
## it out of hand: the hideout and the bench hand the kit out again whenever a
## graph changes, and a rock lying on the floor is not also in the hand for it.
##
## A stacked weapon comes with its whole stack, and the same goes the other way:
## one the kit before this one carried keeps what it had left, so a graph
## changed at the bench does not fill a stack thrown half away.
func setup(ids: Array, boards: Array, in_hand: int, make_runner: Callable, body: Actor) -> void:
	var out: Array = []
	for w in weapons:
		if Weapons.is_thrown(w) and not holds(w):
			out.append(w)
	var had := stock.duplicate()
	weapons.clear()
	runners.clear()
	_bare.clear()
	holders.clear()
	stock.clear()
	for i in mini(mini(ids.size(), boards.size()), MAX_WEAPONS):
		var id := String(ids[i])
		weapons.append(id)
		runners.append(make_runner.call(id, boards[i]))
		if Weapons.is_thrown(id) and not out.has(id):
			holders[id] = body
		if Weapons.is_stacked(id):
			stock[id] = int(had.get(id, Weapons.stack_of(id)))
	if hand_board == null:
		hand_board = Weapons.make_board(Weapons.HAND)
	hand_runner = make_runner.call(Weapons.HAND, hand_board)
	if weapons.is_empty():
		runner = null
		hand = 0
		return
	hand = clampi(in_hand, 0, SLOTS - 1)
	hold_hand()

## `weapon_id` and `runner` for the slot in hand: no weapon and the empty
## hand's graph for an empty one.
func hold_hand() -> void:
	var armed := hand < weapons.size()
	weapon_id = weapons[hand] if armed else ""
	runner = runners[hand] if armed else hand_runner

## Every graph the player runs: each weapon's and the empty hand's.
func every_runner() -> Array[SkillRunner]:
	var all: Array[SkillRunner] = runners.duplicate()
	if hand_runner != null:
		all.append(hand_runner)
	return all

## Whether an empty hand is in hand — the fourth slot, or one no weapon is
## carried in: no weapon, and the empty hand's graph to cast.
func empty_handed() -> bool:
	return not weapons.is_empty() and hand >= weapons.size()

## Whether `slot` can be put in hand: not past the last, not the one in hand
## already, and not with no kit at all.
func may_switch(slot: int) -> bool:
	return not weapons.is_empty() and slot >= 0 and slot < SLOTS and slot != hand

## `slot` in hand. Whatever the one put away was in the middle of is the
## player's to let go of first.
func switch_to(slot: int) -> void:
	hand = slot
	hold_hand()

## Whether the thrown weapon `id` is in a hand the player has.
func holds(id: String) -> bool:
	var h = holders.get(id, null)
	return h != null and is_instance_valid(h)

## The thrown weapon `id`, back in `hands`: picked up off the floor.
func take_back(id: String, hands: Actor) -> void:
	holders[id] = hands

## The thrown weapon `id`, out of hand: lying somewhere the player has not been
## back to.
func let_go(id: String) -> void:
	holders.erase(id)

## How many of the stacked weapon `id` are in hand: 0 for one not carried, and
## for one that is not a stack.
func stock_of(id: String) -> int:
	return int(stock.get(id, 0))

## One of the stacked weapon `id` back in hand. Whether there was room for it:
## not for a weapon not carried, nor in a stack that is already whole.
func take_one_back(id: String) -> bool:
	if not stock.has(id) or stock_of(id) >= Weapons.stack_of(id):
		return false
	stock[id] = stock_of(id) + 1
	return true

## Whether every attack the graph in hand fires is one the body makes with
## nothing in its hands — a HEADBUTT (`Weapons.BARE_FORMS`) — so that it goes
## off whether the weapon is in hand or not. A graph that fires nothing is
## not: it has nothing to go off with. Walked offline, uncharged, the first
## time it is asked, and kept until a graph is edited (`refresh`) or the kit
## handed out again (`setup`).
func bare_handed() -> bool:
	if runner == null:
		return false
	var key := runner.get_instance_id()
	if not _bare.has(key):
		var dry := SkillRunner.new(runner.board)
		dry.base_payload_provider = runner.base_payload_provider
		dry.forms_only = runner.forms_only
		var outs: Array = dry.simulate()["outputs"]
		var bare := not outs.is_empty()
		for p: Payload in outs:
			bare = bare and not Weapons.needs_weapon(p.form)
		_bare[key] = bare
	return bool(_bare[key])

## What was walked for `bare_handed` is forgotten: a graph was walked the other
## way, or edited.
func forget_bare() -> void:
	_bare.clear()

## A graph was edited under its runner: every weapon carried walks its own
## again. Assembly only ever opens the one in hand, and the rest cost nothing
## to be sure of.
func refresh() -> void:
	_bare.clear()
	for r in every_runner():
		r.refresh()
