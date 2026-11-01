class_name Player
extends Actor

## A body on a floor seen from above, and a live skill circuit: the graph of
## the weapon in hand.
##
## The body walks eight ways and every way between, as hard as the stick is
## pushed, dashes the way it is going, and faces the way it last walked or was
## turned; what it does from frame to frame is the `player` machine in the
## content database (`_setup_fsm`). There is no jump: the floor is the whole
## of where it can be, and a wall is walked round.
##
## One board, the weapon's own — its attack form on the root, and whatever the
## player has built on after it — and two ways to fire it. The attack button
## runs the graph as it is, again and again for as long as it is held, and
## costs nothing. Holding the cast button charges it instead: mana buys the
## cast life, which a graph with a cycle in it spends on laps, and letting go
## casts it with whatever the hold paid for. The graph's own length decides
## the cadence either way.
##
## Up to three weapons are carried (`MAX_WEAPONS`), each with its own graph and
## its own wait between casts, and one of them is in hand: the one the two
## buttons fire. A slot's key, or a step along with the wheel, puts another in
## hand at once (`switch_to`) — so three weapons are three skills, a key apart.
## There are four slots (`SLOTS`), each on its key: a weapon's three, and after
## them the empty hand's (`EMPTY_HAND`). A slot with no weapon in it — the
## fourth always, and the second and third while fewer are carried — is an
## empty hand: nothing in it, and the empty hand's own graph to cast
## (`hand_board`), a PUNCH at its root, which goes off only while every attack
## it makes is one.
## A weapon put away goes on with what it was doing: a cast already out lands,
## and its wait runs down, so it is ready again by the time it is drawn.
##
## A thrown weapon (`Weapons.is_thrown`) — the rock — is the one thing here that
## is somewhere: in a hand, in the air, or on the floor. The flow its graph
## sends throws it, and until it is picked back up (`LooseRock`) the weapon
## casts nothing; see `holders`.
##
## A stacked weapon (`Weapons.is_stacked`) — the shuriken — is a count instead:
## so many in hand, one spent on every bolt its graph sends, and one more for
## every one picked back up where it struck (`StuckShuriken`). At none it
## casts nothing; see `stock`.
##
## A bench (`Bench`) is somewhere to sit: interact at one sits the body down on
## it, and it stays sat until it is asked to do anything else (`sit`).
##
## A pit in the room's floor (`Room.pits`) is fallen into: the body walks over
## its edge, drops, loses a little health, and is stood back on the floor it
## left, held for a moment (`_mind_pits`). A dash carries it over.
##
## A hit carrying POSSESS puts the player's hands into the monster it strikes
## (`possess`). The body stays where it was, standing still, and the monsters go
## on hunting it — it dies, and the raid is lost. The input line drives the
## monster instead: it walks, talks to whoever is in reach and attacks with its
## own attack, or with the player's weapon once it has taken it out of the
## body's hands (`take_weapon`) — and it picks the rock up off the floor the
## way the body does, and throws it. The other monsters take it for one of them
## until it hurts one of them. It ends when the time runs out, when the player
## steps out, or when the monster dies; the monster is left stunned, and the
## weapon goes back to the body. The rock does not: it is in the monster's hand,
## and the monster lets go of it where it stands.

signal cast_fired()
signal parry_success()
## Another weapon was put in hand.
signal weapon_switched(weapon: String)
## The player's hands went into a monster, or came back out of one. `monster`
## is null when it was freed on the way out.
signal possessed(monster: Enemy)
signal released(monster)

## The most weapons carried at once. `GameState.MAX_CARRIED` is the same number
## from the profile's side: what a raid can be walked into with.
const MAX_WEAPONS := Loadout.MAX_WEAPONS
## The slot of the empty hand: the fourth, after the most weapons carried,
## whatever is carried before it. With it, or any slot no weapon is in, in hand
## there is no weapon (`weapon_id` is "") and no graph (`runner` is null) — see
## `empty_handed`.
const EMPTY_HAND := MAX_WEAPONS
## How many slots there are to have in hand: a weapon's each, carried or not,
## and the empty hand's.
const SLOTS := Loadout.SLOTS
## How long a monster stands stunned once the player has stepped out of it,
## which is the head start they have on it.
const RELEASE_STUN := 1.2
## How near the monster has to stand to the body, feet to feet, for a press
## of interact to take the weapon out of its hands.
const TAKE_REACH := 56.0

## The silhouette the sprite stands on the feet — how wide, how tall — and the
## reach of a hit against the body, on the floor.
const BODY := Vector2(20.0, 30.0)
const HURT_RADIUS := 13.0
## How long a blow that gets through leaves the player untouchable. A full
## second is room to pick the body up and walk it out of whatever landed the
## hit, rather than be chain-hit where they stand. It is also the gate a
## monster leaning on the player deals its contact damage through, so it sets
## how fast being stood on wears the health bar down.
const HURT_INVULN := 1.0

const RUN_SPEED := 250.0
## A sprint is the same walk half as fast again, for as long as it is asked
## for. It costs nothing and changes nothing else: the body turns and stops as
## it does at a walk.
const SPRINT_SPEED := 375.0
const GROUND_ACCEL := 2600.0
const FRICTION := 2400.0
## The dash is a movement tool first: it wants to be over almost before it has
## registered, and to be there again the moment it is wanted. Speed carries the
## reach so the window can stay short, and the recovery runs from the press
## rather than from the end of the move, so a third of it is gone before the
## dash has even let go — which is what makes chaining them feel free.
##
## It goes the way the stick is held, any of the eight ways and every way
## between, or the way the body faces when nothing is held: the same move
## whichever way, and the one way across a room's floor faster than walking.
##
## The reach is about two and a half cells of the room grid: far enough to be
## through something and out the other side, short enough to be a step rather
## than a leap across the room.
const DASH_SPEED := 880.0
const DASH_TIME := 0.09
const DASH_COOLDOWN := 0.30
## What a dash is worth as a dodge, counted from the press. It is set a hair
## longer than the dash itself so the move is covered end to end, and a blow
## arriving as the dash finishes still passes through.
const DASH_INVULN := 0.10
## How much longer the weapon waits between casts than its graph alone would.
## A bare graph is three or four cells long, so left alone it comes round again
## in a fortieth of a second — a held button became a blur with no swing in it
## to read. The multiplier is what makes a cast a swing rather than a stream:
## at ten a bare sword lunges about two and a half times a second, slow enough
## to see each one start and end, and still quick enough to chain. A graph with
## more built on it waits proportionally longer, and every OVERCLOCK on it
## shortens the wait as it always did.
const CAST_COOLDOWN_MUL := 10.0
## A stick has no cursor to point at, so it aims at a point far enough down
## itself to be past anything's reach. How far a lunge actually goes is how far
## the stick is pushed — see `aim_reach`.
const STICK_AIM_REACH := 2000.0
## How far the right stick has to be pushed before it aims at all. Past it, how
## much further says how far the attack reaches (`reach_of`).
const STICK_DEAD := 0.35

## A fall into a pit: what it costs in health, how long the body is held
## before it stands again, and the grace after it.
const PIT_DAMAGE := 8.0
const FALL_TIME := 0.6
const FALL_GRACE := 0.5

## Stamina is what a dash spends. The dash keeps its short cooldown, which is
## what makes chaining feel responsive; stamina is the separate question of how
## long you may keep chaining before you have to stop. Four dashes' worth, and
## a pause before it starts coming back, so a retreat is a decision rather than
## something held down.
const MAX_STAMINA := 100.0
const DASH_STAMINA := 25.0
const STAMINA_REGEN := 38.0    ## per second
const STAMINA_PAUSE := 0.45    ## quiet after a dash before any of it returns

## Mana, and the charge a hold of the cast button builds out of it, are a
## `Charge` of the player's (`_charge`): what it builds, bleeds, pays and
## refills is there, and whether a hold may charge at all is said here
## (`can_charge`). Its numbers are kept here by name, for whoever names them
## through the player.
const MAX_MANA := Charge.MAX_MANA
const MANA_REGEN := Charge.MANA_REGEN
const MANA_PAUSE := Charge.MANA_PAUSE
const CHARGE_TTL_RATE := Charge.CHARGE_TTL_RATE
const MANA_PER_TTL := Charge.MANA_PER_TTL
const MAX_CHARGE_TTL := Charge.MAX_CHARGE_TTL
const CHARGE_DECAY := Charge.CHARGE_DECAY
const CAST_BUFFER := Charge.CAST_BUFFER

## The kit in the hands (`Loadout`): the weapons carried and their graphs, the
## slot in hand, the thrown weapons by whose hands each is in, the stacked by
## how many are left, and the empty hand's graph. The rest of the game reads
## it through the player by the names it always had, which stand here and
## reach into it.
var _kit := Loadout.new()
var weapons: Array[String]:
	get: return _kit.weapons
	set(v): _kit.weapons = v
var runners: Array[SkillRunner]:
	get: return _kit.runners
	set(v): _kit.runners = v
var hand_board: SkillBoard:
	get: return _kit.hand_board
	set(v): _kit.hand_board = v
var hand_runner: SkillRunner:
	get: return _kit.hand_runner
	set(v): _kit.hand_runner = v
## Which slot is in hand, and so which of them the buttons fire.
var hand: int:
	get: return _kit.hand
	set(v): _kit.hand = v
## The weapon in hand and its runner: no weapon ("") and the empty hand's
## runner with an empty hand in hand.
var weapon_id: String:
	get: return _kit.weapon_id
	set(v): _kit.weapon_id = v
var runner: SkillRunner:
	get: return _kit.runner
	set(v): _kit.runner = v
## The monster the player's hands are in, or null — see `possess`.
var possessing: Enemy = null
## Seconds left before the player is put back in their own body, and how many
## there were to begin with.
var possess_left: float = 0.0
var possess_for: float = 0.0
## Where the monster the player is in last stood, for a rock in its hand to be
## let go of there should the monster be gone by the time they step out.
var _vessel_at: Vector2 = Vector2.ZERO
## The thrown weapons by whose hands each is in, and the stacked by how many
## are left: the kit's (`Loadout`).
var holders: Dictionary:
	get: return _kit.holders
	set(v): _kit.holders = v
var stock: Dictionary:
	get: return _kit.stock
	set(v): _kit.stock = v
## Whether the attack button was down a frame ago, so a press on a rock that
## is not in the hand is answered once rather than every frame it is held.
var _was_attacking: bool = false
## Whether the press still held is the one that threw the rock out of the hands
## the player is in. It is spent until it is let go: a click lasts a few frames,
## and the rest of it would otherwise be a monster's own attack — a Crawler
## slashing the air beside the throw, a Gunman firing and giving itself away.
var _press_spent: bool = false
## Whether the monster has taken the weapon out of the body's hands. While it
## has, the weapon's graph is cast from the monster, and the body holds nothing.
var vessel_armed: bool = false
## The room the body is in. A bench sat on is stood up off as it changes: the
## bench was the room's.
var room = null:
	set(r):
		if r != room:
			stand_up()
		room = r
var aim: Vector2 = Vector2.RIGHT
## Where the player is pointing, in world space, as opposed to `aim` which is
## only the direction. A lunge lands here rather than a fixed distance out.
var aim_point: Vector2 = Vector2.ZERO
## How far the attack being aimed should go, 0 to 1: how far past its dead zone
## the right stick is pushed, a gamepad's or the touch console's. 0 still goes
## `Attacks.REACH_MIN` of the attack's own distance; 1 goes all of it. The
## pointer always asks for all of it — a mouse points at a place, and a lunge
## already lands on that place (`aim_point`).
var aim_reach: float = 1.0
## The bench the body sits on, or null — see `sit`.
var seat: Bench = null
## Who this body is, as a hero (`Heroes`): '' for whoever the profile plays
## as (`GameState.hero`). A world that stands its own up sets it before the
## body is put down (`WireTest`), and it is drawn as them.
var hero: String = ""
## Whether a way held since the body sat down has yet to be let go of: a walk
## into the bench, carried on over the walk to its seat, stands nobody up until
## it has been (`_mind_seat`).
var _sat_holding: bool = false

var _dash_time: float = 0.0
var _dash_cd: float = 0.0
var _dash_dir: Vector2 = Vector2.DOWN
## How much longer the body is held after a fall, and where it fell: the pit
## it dropped into, for the picture to show it drop there.
var fell: float = 0.0
var fell_at: Vector2 = Vector2.ZERO
## The last place the body stood on floor, which is where it is stood again
## after a fall.
var _footing: Vector2 = Vector2.ZERO
var _held_by_fall := HandsOff.new()
var stamina: float = MAX_STAMINA
var _stamina_pause: float = 0.0
## The player's own numbers with what the profile adds to them
## (`GameState.boost`) — the bars' ceilings, how much faster the body walks, and
## how fast and how far a hold charges. Taken when the body comes up, and again
## whenever what is added changes (`_reboost`), so a perk bought in the hideout
## reaches the body standing there.
var max_stamina: float = MAX_STAMINA
var _pace_mul: float = 1.0
## Mana, and the charge a hold builds out of it (`Charge`). The HUD, the
## picture and the tests read it through the player by the names it always
## had, so those stand here and reach into it.
var _charge := Charge.new()
var mana: float:
	get: return _charge.mana
	set(v): _charge.mana = v
var max_mana: float:
	get: return _charge.max_mana
	set(v): _charge.max_mana = v
## Extra life being built up while the button is held, in TTL.
var charge: float:
	get: return _charge.charge
	set(v): _charge.charge = v
## What the last release actually paid for, carried by the cast it bought.
var cast_charge: float:
	get: return _charge.cast_charge
	set(v): _charge.cast_charge = v
## True while the cast button is actually buying life.
var charging: bool:
	get: return _charge.charging
## True while the cast button is pouring the player's mana into a spent rune
## (`refill_rune`), the same way.
var refilling: bool = false

## How fast a hold pours mana into a spent rune, in mana a second: a full
## rune's worth in under a second, more with DEEP CHARGE.
const RUNE_FILL := 60.0
var parry_time: float = 0.0
## Everything the player is asked to do comes down this line: their own hands
## at the head of it, then whatever else wants a say — a screen that takes the
## keys, a conversation that holds them still, a walk that brings them over to
## talk. The body reads what comes out of the far end, and never `Input`
## itself. See `InputProvider`.
var input: InputProvider
## Set while a screen over the game takes the keys — the skill editor. It puts
## the hands off on the line, and setting it back takes them on again.
var input_locked: bool = false:
	set(on):
		input_locked = on
		input.put(_held_by_screen, on)
## Set by an NPC for as long as they are talking to this player: the talk key
## still moves the conversation on, but nothing else the player does acts.
var talk_locked: bool = false:
	set(on):
		talk_locked = on
		input.put(_held_by_talk, on)
var _held_by_screen := HandsOff.new(true)
var _held_by_talk := HandsOff.new()
## On the line for as long as the player stands stunned (`Actor.stun`): the
## hands come off the body the way they do for a conversation, and go back on
## the frame it comes round.
var _held_by_stun := HandsOff.new()
## What the line asked of the body this physics frame. The state's actions
## read it rather than asking again.
var _asked := InputState.new()
## What the view must play regardless of what the body is doing — a pose a
## story's line holds the player in (`Npc.direct`) — or "" to let the view
## choose from the body's own motion. The body itself is not held: that is
## the conversation's to do.
var forced_anim: String = ""

## Movement runs as a state machine. Every frame the senses are read, the state
## is re-picked from them, and only then does that state act — so the state an
## action runs in describes this frame, not the one before a dash. All of it —
## the states, what each does, which can follow which and what opens each way
## — is the `player` machine in the content database
## (`data/db/machines/player.sql`). What is left here is what its rows name:
## the actions a state takes and the senses a condition reads, handed over in
## `_setup_fsm`.
var machine: Machine
var current_state: FSMNode
## Log state transitions.
var debug_mode: bool = false
## The way held this frame, on the floor, no longer than 1: where the stick
## points and how far.
var _dir: Vector2 = Vector2.ZERO

func _init() -> void:
	input = InputProvider.new(self)
	input.add(Hands.new())
	input.add(AimAssist.new())

func _ready() -> void:
	team = 0
	max_health = GameState.max_health()
	super._ready()
	hurt_radius = HURT_RADIUS
	_make_body(BODY.x, BODY.y)
	add_to_group("player")
	_setup_fsm()
	current_state = machine.start
	_reboost()
	GameState.boosts_changed.connect(_reboost)
	Magic.changed.connect(_on_magic)

func _notification(what: int) -> void:
	# Not _exit_tree: a player carried between rooms leaves the tree and comes
	# back without _ready running again, and would return with no states.
	if what == NOTIFICATION_PREDELETE and machine != null:
		machine.cleanup()

## The words the machine's rows are written in: the actions a state's steps
## take, and the senses its conditions read. Which states there are, what each
## does, which can follow which and when is the table's to say, and a row's to
## change; a row naming a word that is not here is reported, not guessed at.
func _setup_fsm() -> void:
	machine = Machine.build("player", {
		"brake": _action_brake,
		"run": _action_run,
		"dash": _action_dash,
		"rush": _action_rush,
	}, {
		"dashing": is_dashing,
		"moving": func() -> bool: return _dir != Vector2.ZERO,
	})
	for fault in machine.faults:
		push_error("Player: the player machine — %s" % fault)
	if machine.start == null:
		push_error("Player: no state to start in, so the player will not move — is data/enigami.db built and shipped?")

## Hands the player one weapon and the graph on it: a kit of one.
func setup(weapon: String, board: SkillBoard) -> void:
	setup_kit([weapon], [board])

## Hands the player a kit: up to MAX_WEAPONS weapons, in slot order, the graph
## on each, and which slot is in hand — one with no weapon in it for none. The runners are rebuilt wholesale; the
## old ones go away with their signals, and so does whatever was being charged.
##
## A thrown weapon comes in the body's hand — unless the kit before this one
## had it out of hand: the hideout and the bench hand the kit out again
## whenever a graph changes, and a rock lying on the floor is not also in the
## hand for it.
##
## A stacked weapon comes with its whole stack, and the same goes the other way:
## one the kit before this one carried keeps what it had left, so a graph
## changed at the bench does not fill a stack thrown half away.
func setup_kit(ids: Array, boards: Array, in_hand: int = 0) -> void:
	_kit.setup(ids, boards, in_hand, _make_runner, self)
	_charge.let_go()

## Every graph the player runs: each weapon's and the empty hand's.
func _every_runner() -> Array[SkillRunner]:
	return _kit.every_runner()

## Whether an empty hand is in hand — the fourth slot, or one no weapon is
## carried in: no weapon, and the empty hand's graph to cast.
func empty_handed() -> bool:
	return _kit.empty_handed()

## One weapon's graph, run live. What it fires is finalized as that weapon's,
## whichever weapon is in hand by the time it lands.
func _make_runner(weapon: String, board: SkillBoard) -> SkillRunner:
	var r := SkillRunner.new(board)
	r.cooldown_mul = _cast_mul()
	r.forms_only = not Magic.on
	r.base_payload_provider = func() -> Payload: return Weapons.base_payload(weapon)
	r.fired.connect(_on_fired.bind(weapon))
	r.cycle_started.connect(_on_cycle_started)
	r.dilation_requested.connect(func(sec: float) -> void: TimeCtl.dilate(sec, 0.42))
	r.parry_opened.connect(_on_parry_opened)
	return r

## Puts the weapon in `slot` in hand, 0 for the first carried — or nothing at
## all for a slot no weapon is in, EMPTY_HAND always. Whether it did: not for a
## slot past the last, nor for the one already in hand, nor with no kit at all.
##
## It is instant, and it costs whatever was being charged: the hold was buying
## life for the weapon being put away, and does not follow the hand to the next
## one. That weapon keeps the wait it was in, and anything it had already cast
## still lands.
func switch_to(slot: int) -> bool:
	if not _kit.may_switch(slot):
		return false
	_charge.let_go()
	if runner != null:
		runner.ttl_bonus = 0
		runner.set_active(false)
	_kit.switch_to(slot)
	weapon_switched.emit(weapon_id)
	Cues.at(&"weapon_switch", global_position, {"weapon": weapon_id, "slot": hand})
	return true

## --- the rock ---------------------------------------------------------------

## Whether the thrown weapon `id` is in a hand the player has: the body's, or
## the monster's they are in.
func holds(id: String) -> bool:
	return _kit.holds(id)

## Whether the weapon in hand can go off from the hands the player is in: a
## thrown weapon only from the hands holding it; any other from the body, and
## from a monster once it has taken it. A graph that only ever headbutts needs
## none of that (`bare_handed`): the head is always there.
func can_cast() -> bool:
	if runner == null:
		return false
	# A spent rune's graph casts nothing until it is filled again; the stone is
	# thrown bare instead (`_throw_bare`).
	if rune_spent_in_hand():
		return false
	# An empty hand has nothing in it to strike with but the fist.
	if empty_handed():
		return bare_handed()
	if Weapons.is_thrown(weapon_id):
		return (holds(weapon_id) and holders[weapon_id] == vessel()) or bare_handed()
	if Weapons.is_stacked(weapon_id) and stock_of(weapon_id) <= 0:
		return bare_handed()
	return possessing == null or vessel_armed or bare_handed()

## Whether every attack the graph in hand fires is one the body makes with
## nothing in its hands — a HEADBUTT (`Weapons.BARE_FORMS`) — so that it goes
## off whether the weapon is in hand or not: the rock lying elsewhere, every
## shuriken thrown, the hands in a monster that has not taken the weapon
## (`Loadout.bare_handed`).
func bare_handed() -> bool:
	return _kit.bare_handed()

## The hands the weapon in hand is in, for whatever draws it there: the body,
## the monster the player is in once it holds it, or null — the empty hand, a
## thrown weapon out of hand, or a stack with none left in it.
func weapon_hands() -> Actor:
	if empty_handed():
		return null
	if Weapons.is_thrown(weapon_id):
		return holders[weapon_id] if holds(weapon_id) else null
	if Weapons.is_stacked(weapon_id) and stock_of(weapon_id) <= 0:
		return null
	if possessing != null and vessel_armed and is_instance_valid(possessing):
		return possessing
	return self

## The thrown weapon `id`, back in hand: picked up off the floor by `hands` —
## the body, or the monster the player is in (`LooseRock`).
func take_back(id: String, hands: Actor) -> void:
	_kit.take_back(id, hands)

## The thrown weapon `id`, out of hand: lying somewhere the player has not been
## back to — a raid walked back into after it was put down with the rock on
## the floor.
func let_go(id: String) -> void:
	_kit.let_go(id)

## --- the shuriken -----------------------------------------------------------

## How many of the stacked weapon `id` are in hand: 0 for one not carried, and
## for one that is not a stack.
func stock_of(id: String) -> int:
	return _kit.stock_of(id)

## One of the stacked weapon `id` back in hand, picked up where it struck
## (`StuckShuriken`). Whether there was room for it: not for a weapon not
## carried, nor in a stack that is already whole.
func take_one_back(id: String) -> bool:
	return _kit.take_one_back(id)

## --- possession -------------------------------------------------------------

## The body the player's hands are in: the monster they possess, or their own.
## Whatever stands in for the player — someone talking to them, the line's aim,
## the walk over to talk — measures from this.
func vessel() -> Actor:
	if possessing != null and is_instance_valid(possessing) and not possessing.dead:
		return possessing
	return self

## Whether a hit could put the player's hands into `e`: a monster still
## standing, nobody else's, and not a boss — its room is its own.
static func can_possess(e) -> bool:
	return e is Enemy and is_instance_valid(e) and not (e as Enemy).dead \
		and (e as Enemy).pilot == null and not bool((e as Enemy).def.get("boss", false))

## Puts the player's hands into `e` for `seconds`. From inside one monster this
## is a hop to the next: the first is let go of as if stepped out of. Whatever
## was being charged is let go of, and the weapon stays in the body's hands
## until the monster takes it. Whether it took.
func possess(e: Enemy, seconds: float) -> bool:
	if seconds <= 0.0 or not can_possess(e):
		return false
	if possessing != null:
		release()
	possessing = e
	possess_left = seconds
	possess_for = seconds
	vessel_armed = false
	_charge.let_go()
	for r in _every_runner():
		r.ttl_bonus = 0
		r.set_active(false)
	velocity = Vector2.ZERO
	e.take_pilot(self)
	input.drive(e)
	possessed.emit(e)
	Cues.at(&"possess", e.global_position, {"kind": e.kind, "seconds": seconds})
	return true

## Back into the player's own body, wherever it was left, with the weapon back
## in its hands. The monster is left stunned for `RELEASE_STUN`, and is one of
## them again. A rock in its hand is let go of where it stands: it is not the
## monster's, and it is not the body's either until the body walks over to it.
func release() -> void:
	if possessing == null:
		return
	var e := possessing
	possessing = null
	possess_left = 0.0
	vessel_armed = false
	input.drive(self)
	var at := e.global_position if is_instance_valid(e) else _vessel_at
	for id in holders.keys():
		if holders[id] != self:
			holders.erase(id)
			LooseRock.drop(id, at, Vector2(0.0, -120.0), room, self)
	var left = null
	if is_instance_valid(e):
		left = e
		if not e.dead:
			e.release_pilot(RELEASE_STUN)
			Cues.at(&"possess_end", e.global_position, {"kind": e.kind})
	released.emit(left)

## Whether a press of interact would take the weapon: the monster the player is
## in, standing at the body, with nothing in its hands yet — and a weapon in the
## body's to take.
func can_take_weapon() -> bool:
	return not empty_handed() and possessing != null and is_instance_valid(possessing) and not possessing.dead \
		and not vessel_armed and possessing.global_position.distance_to(global_position) <= TAKE_REACH

## The weapon, out of the body's hands and into the monster's: from now on the
## buttons cast its graph from there. A rock in the body's hand goes with it.
## Whether it was taken.
func take_weapon() -> bool:
	if not can_take_weapon():
		return false
	vessel_armed = true
	for id in holders.keys():
		if holders[id] == self:
			holders[id] = possessing
	possessing.attacking = false
	Cues.at(&"weapon_taken", possessing.global_position, {"weapon": weapon_id})
	return true

## A frame of being inside a monster: the time running down, the key that steps
## out, the monster gone, and the press that takes the weapon.
func _mind_possession(delta: float, s: InputState) -> void:
	if not is_instance_valid(possessing) or possessing.dead:
		release()
		return
	_vessel_at = possessing.global_position
	possess_left -= delta
	if possess_left <= 0.0 or s.step_out_pressed:
		release()
		return
	if s.use_pressed:
		take_weapon()

## The body dies with the player's hands elsewhere: they come back to it.
func _kill() -> void:
	release()
	stand_up()
	super._kill()

## Puts the slot `step` along in hand: 1 for the next, -1 for the one before,
## every slot of the four in turn, empty or not, and round from the empty hand
## to the first.
func switch_by(step: int) -> bool:
	if weapons.is_empty() or step == 0:
		return false
	return switch_to(posmod(hand + step, SLOTS))

func stamina_ratio() -> float:
	return clampf(stamina / max_stamina, 0.0, 1.0)

func mana_ratio() -> float:
	return _charge.mana_ratio()

## Takes what the profile adds to the player's own numbers again: a perk was
## bought, a profile opened. What a ceiling gained is added to what is under it,
## so a full bar stays full; one that came down leaves nothing over it.
func _reboost() -> void:
	var had_health := max_health
	max_health = GameState.max_health()
	health = minf(health + maxf(max_health - had_health, 0.0), max_health)
	var had_stamina := max_stamina
	max_stamina = MAX_STAMINA + GameState.boost("max_stamina")
	stamina = minf(stamina + maxf(max_stamina - had_stamina, 0.0), max_stamina)
	_charge.reboost(MAX_MANA + GameState.boost("max_mana"), 1.0 + GameState.boost("charge_speed"),
		MAX_CHARGE_TTL + GameState.boost("max_charge"))
	_pace_mul = 1.0 + GameState.boost("move_speed")
	for r in _every_runner():
		r.cooldown_mul = _cast_mul()

## What every cast off the player waits, against its graph alone
## (`CAST_COOLDOWN_MUL`), with what the profile takes off it — never below
## half, whatever is bought.
func _cast_mul() -> float:
	return CAST_COOLDOWN_MUL * maxf(1.0 - GameState.boost("cast_speed"), 0.5)

## Mana taken back off an enemy by a MANA DRAIN attack. It lands whatever the
## charge is doing, unlike regeneration: the quiet after a hold (`Charge.pause`) exists to stop it
## refilling itself the moment it is released, and this was earned by landing a
## hit rather than by waiting.
func gain_mana(amount: float) -> void:
	_charge.gain(amount)

## How full the charge is, against the most this player can hold.
func charge_ratio() -> float:
	return _charge.ratio()

## One ceiling for every skill in the game, with what the profile adds to it
## (DEEP CHARGE). Nothing here asks what shape the board is: charging engages
## the same way on all of them, and what the life it buys is worth is then up
## to what the player built.
func charge_cap() -> float:
	return _charge.cap

## A frame of the hold: it charges only while the cast button is held on a
## graph that may be charged (`can_charge`), and bleeds off otherwise
## (`Charge.tick`).
func _update_charge(delta: float, holding: bool) -> void:
	_charge.tick(delta, holding, can_charge())

func can_dash() -> bool:
	return _dash_cd <= 0.0 and stamina >= DASH_STAMINA

## A graph still recovering cannot be charged. The wait is the graph's own
## cadence, and letting a hold run alongside it would buy the next cast's life
## out of time already being spent — a long graph would come back charged for
## free, and the hold would stop being a decision made against the cooldown.
## Holding through the wait is not punished: the charge simply starts building
## the moment the graph comes free.
##
## Nor can a rock that is not in the hand: there is nothing to throw at the end
## of the hold — unless the graph only headbutts, which needs no rock to.
##
## Nor anything while magic is off: the life a hold buys is spent by the parts
## round the board, and with forms alone there is nothing to spend it. A
## release still casts, as a tap does.
##
## Nor the rune: the cast button fills it (`refill_rune`) and never charges it,
## and what a throw of it carries is the charge stored in it (`rune_charge`).
func can_charge() -> bool:
	return Magic.on and runner != null and runner.is_ready() and can_cast() and not rune_in_hand()

## Whether the weapon in hand is the rune (`Weapons.is_rune`).
func rune_in_hand() -> bool:
	return not empty_handed() and Weapons.is_rune(weapon_id)

## Whether the weapon in hand is the rune and it is spent: its graph casts
## nothing until it is filled again (`refill_rune`), though the stone can still
## be thrown bare (`_throw_bare`).
func rune_spent_in_hand() -> bool:
	return rune_in_hand() and GameState.rune.spent

## The mana a full rune holds for this player (`Rune.full`): one full charge,
## deeper with DEEP CHARGE.
func rune_full() -> float:
	return Rune.full(charge_cap())

## The charge a throw of the lit rune carries (`Rune.charge_in`): as much as
## the mana in it buys, up to the most this player can charge. The rune pays
## for it, not the player.
func rune_charge() -> int:
	return GameState.rune.charge_in(charge_cap())

## A hold of the cast button with a spent rune in hand pours the player's own
## mana into it, as fast as RUNE_FILL and for as long as there is mana to pour,
## from the body that holds it. Full, it is lit again (`rune_lit`): the next
## throw of it carries the charge it holds. Whether the hold went into the rune.
func refill_rune(delta: float, holding: bool) -> bool:
	refilling = false
	if not holding or not rune_spent_in_hand() or possessing != null or not holds(weapon_id):
		return false
	refilling = true
	var pour := _charge.pour(minf(RUNE_FILL * delta, GameState.rune.lacks(charge_cap())))
	if GameState.rune.fill(pour, charge_cap()):
		refilling = false
		Cues.at(&"rune_lit", global_position, {"weapon": weapon_id})
	return true

## Throws the weapon in hand bare: the stone itself, with the weapon's own
## numbers and nothing its graph would build into it — no part's work, no
## follow-up, no charge. What a spent rune is: still a stone to throw, its skill
## gone out of it until it is filled again. The throw goes the way any throw of
## it does (`_on_fired`), out of the hand and onto the floor to be picked up.
func _throw_bare() -> void:
	var p := Weapons.base_payload(weapon_id)
	p.form = "PROJECTILE"
	_on_fired(p, weapon_id)

## Magic went off, or came back: every graph carried is cast as its forms
## alone, or whole again (`SkillRunner.forms_only`), and what counts as
## bare-handed is asked again, since it was walked the other way.
func _on_magic(on: bool) -> void:
	for r in _every_runner():
		r.forms_only = not on
	_kit.forget_bare()

## A graph was edited under its runner: every weapon carried walks its own
## again. Assembly only ever opens the one in hand, and the rest cost nothing
## to be sure of.
func rebuild_runner() -> void:
	_kit.refresh()

func _on_parry_opened(seconds: float) -> void:
	parry_time = maxf(parry_time, seconds)

## A cycle started. If a release was waiting for one, this is the cast it
## bought: the life it paid for went in with the cycle, and the wait is over.
## Only the weapon in hand ever starts one — a weapon put away is not cast — so
## there is no asking whose it was.
func _on_cycle_started() -> void:
	_charge.buffer = 0.0
	# A cast of the lit rune takes the charge stored in it — the life was read as
	# the cycle started (`rune_charge`) — and spends it: the throw goes out, and
	# the rune is dead until it is filled again.
	if rune_in_hand() and not GameState.rune.spent:
		GameState.rune.spend()
		Cues.at(&"rune_spent", global_position, {"weapon": weapon_id})

## A graph's flow left its board: the attack. `weapon` is whose graph it was —
## the weapon in hand, unless it says — since a cast still in flight when the
## weapon was put away lands as that weapon's, not as the one drawn since.
##
## It goes off from whichever body holds the weapon: the monster's, once it has
## taken it — which gives the monster away only if what it throws hurts one of
## them (`Attacks.resolve_hit`).
##
## Off a thrown weapon, a bolt is the weapon itself. The flow that finds the rock
## in the hand it goes off from throws it, with everything the graph built into
## it, and leaves the hand empty; any other flow the same cast sends — a lap
## that comes round once the rock has gone — throws copies of it, which are gone
## when they come down. A flow off the rock that is not a bolt does not throw
## it: it is struck with, or cast from, and stays in the hand.
##
## Off a stacked weapon every bolt is one of the stack, thrown: a volley of three
## spends three, and one with fewer left throws what is left — none, when the
## stack ran out while the cast was still going round. A flow that is not a bolt
## spends nothing, as off the rock.
func _on_fired(payload: Payload, weapon: String = "") -> void:
	if weapon == "":
		weapon = weapon_id
	var from := vessel()
	var p := Weapons.finalize(weapon, payload)
	var ctx := {
		"attacker": from, "room": room, "team": team,
		"aim": aim, "reach": aim_reach, "origin": from.global_position,
		"lobbed": Weapons.uses_lobbed_shots(weapon), "aim_point": aim_point,
	}
	if Weapons.is_thrown(weapon) and p.form == "PROJECTILE":
		ctx["thrown"] = weapon
		ctx["thrower"] = self
		if holds(weapon) and holders[weapon] == from:
			holders.erase(weapon)
			_press_spent = true
		else:
			ctx["ghost"] = true
	if Weapons.is_stacked(weapon) and p.form == "PROJECTILE":
		var throwing := mini(clampi(p.duplicates, 1, 9), stock_of(weapon))
		if throwing <= 0:
			return
		p.duplicates = throwing
		stock[weapon] = stock_of(weapon) - throwing
		ctx["sticks"] = weapon
		ctx["thrower"] = self
	Attacks.spawn(p, ctx)
	cast_fired.emit()

## How far the right stick asks an attack to reach, from how hard it is pushed:
## nothing at the edge of its dead zone, all of it at the rim.
static func reach_of(push: float) -> float:
	return clampf(inverse_lerp(STICK_DEAD, 1.0, push), 0.0, 1.0)

## The push that asks for `reach`, for whatever aims through the stick without a
## hand on one — the touch console. A hair past the dead zone at nothing, so the
## shortest reach still aims.
static func push_for(reach: float) -> float:
	return lerpf(STICK_DEAD + 0.01, 1.0, clampf(reach, 0.0, 1.0))

## Whether a cast asked for has still to go off, or is going off: the release
## is in the buffer, or the graph's pulse is still out. For whatever has to
## keep aiming a cast until it has gone — the touch console, whose thumb leaves
## the stick in the same moment it casts.
func casting() -> bool:
	return _charge.waiting() or (runner != null and not runner.is_ready())

func on_dashed() -> void:
	invuln = maxf(invuln, 0.12)

## Whether the player's own input is ignored: a screen has the keys, someone is
## talking to them, or anything else has taken the hands off on their line.
func controls_locked() -> bool:
	return input.held()

## Whether the computer has the body rather than the player: the game is holding
## it — a conversation, a stun — or walking it somewhere, or something other
## than the player's hands is playing it (`ComputerHands`). Not while a screen
## has the keys: the player put the body aside for that themselves, and nothing
## is driving it. `Pointer` asks: taken over, the crosshair is the computer's
## and the system pointer is shown beside it.
func taken_over() -> bool:
	return not input_locked and input.taken_over()

func _process(delta: float) -> void:
	_process_status(delta)
	# The body's stun holds the body. With the hands in a monster it is the
	# monster's own stun that holds them.
	input.put(_held_by_stun, stunned() and possessing == null)
	if parry_time > 0.0:
		parry_time -= delta
	var s := input.state()
	var pressed := s.attack and not _was_attacking
	_was_attacking = s.attack
	if not s.attack:
		_press_spent = false
	if possessing != null:
		_mind_possession(delta, s)
	# Another weapon in hand, by its slot's key or by a step along. Before the
	# buttons are read, so the press that draws a weapon and a button already
	# held are answered by the weapon drawn.
	if s.weapon_slot >= 0:
		switch_to(s.weapon_slot)
	elif s.weapon_step != 0:
		switch_by(s.weapon_step)
	# The hands the player is in cannot cast the weapon in hand: a monster's own
	# attack, then, until it holds the weapon.
	var castable := can_cast()
	if possessing != null and not castable:
		_attack_as_monster(delta, s)
		return
	# A monster the player's graph goes off from — it took the weapon, or the
	# graph only headbutts — does not go on with its own attack beside it.
	if possessing != null:
		possessing.attacking = false
	# The body's hand is empty — the rock is out — and nothing goes off. Said
	# once a press, so it does not read as a dropped input. The empty hand's
	# graph that wants a weapon has nothing to say it about.
	# The rune in hand: the cast button never casts it and never charges it. It
	# fills it, when it is spent (`refill_rune`), and otherwise does nothing;
	# the attack button throws it.
	var rune := rune_in_hand()
	refill_rune(delta, s.cast)
	# A spent rune in the body's hand is still a stone: the attack button throws
	# it bare (`_throw_bare`), its graph cast not at all.
	if pressed and rune_spent_in_hand() and possessing == null and holds(weapon_id) \
			and holders[weapon_id] == self:
		_throw_bare()
	elif not castable and not empty_handed() and (pressed or (s.cast_released and not rune)):
		Cues.at(&"refused", global_position, {"kind": "thrown", "weapon": weapon_id})
	# Holding the cast button charges; letting go is what fires it. A tap is
	# simply a charge of nothing, so a quick press still casts as it always did.
	var holding := s.cast and not rune
	# Taken before the charge is touched: on the frame of the release the button
	# already reads as up, and letting the bleed-off run first shaved a fifth
	# off what the player had actually paid for.
	if s.cast_released and castable and not rune:
		_charge.release()
	_update_charge(delta, holding)
	_charge.wait(delta)
	# The attack button runs the graph as it is, for as long as it is held and
	# as often as the graph comes round — and never while a charge is being
	# built, which would spend the cast the hold is paying for on nothing.
	var attacking := not holding and s.attack and castable
	if runner != null:
		# Whatever a release paid for rides on the cast it bought, and on no
		# other: the life is read once, as a cycle starts, so it is offered only
		# while the release is still waiting for one.
		runner.ttl_bonus = _charge.ttl_bonus()
		# A throw of the lit rune carries the charge stored in it, for nothing.
		if rune and not GameState.rune.spent:
			runner.ttl_bonus = rune_charge()
		runner.set_active(castable and (_charge.waiting() or attacking))
		runner.update(delta)
	# The weapons put away are not cast, but they go on: a cast already out
	# plays through, and each one's wait runs down in its slot.
	for r in _every_runner():
		if r != runner:
			r.ttl_bonus = 0
			r.set_active(false)
			r.update(delta)
	# Aiming is the player's hand as much as walking is: while a screen has the
	# controls, the weapon stays where it was pointing instead of following the
	# pointer round a menu.
	_update_aim(s)

## Inside a monster with the weapon still in the body's hands: either button is
## the monster's own attack, for as long as it is held, and nothing charges —
## a hold buys life for the weapon's graph, and that is back at the body. The
## weapons go on recovering in their slots meanwhile.
func _attack_as_monster(delta: float, s: InputState) -> void:
	possessing.attacking = (s.attack and not _press_spent) or s.cast
	_update_charge(delta, false)
	_charge.buffer = 0.0
	_charge.cast_charge = 0.0
	for r in _every_runner():
		r.ttl_bonus = 0
		r.set_active(false)
		r.update(delta)
	_update_aim(s)

## Points the weapon where the line says the hand points — the stick or the
## pointer, see `Hands` — and leaves it where it was while the line says the
## hand is off it.
func _update_aim(s: InputState = null) -> void:
	if s == null:
		s = input.state()
	if not s.aiming:
		return
	if s.aim != Vector2.ZERO:
		aim = s.aim
	aim_reach = s.aim_reach
	aim_point = s.aim_point

func _physics_process(delta: float) -> void:
	if dead:
		return
	# With the hands in a monster the body is asked for nothing, and stands
	# where it was left: the monster reads the line for itself.
	_asked = input.state() if possessing == null else InputState.new()
	_mind_seat()
	# Sat down, the body goes nowhere: a way still held from before it sat is
	# not a step.
	_dir = _asked.move if seat == null else Vector2.ZERO
	# The body faces the way it walks, and when it stands still the way it
	# last walked — or the way whatever walked it here turned it, to face what
	# it came for.
	face(_dir)
	face(_asked.turn)
	if _dash_cd > 0.0:
		_dash_cd -= delta
	# A dash owns the body outright: nothing is sensed or refilled while it
	# runs.
	if _dash_time <= 0.0:
		_sense(delta)

	if current_state != null:
		var next := current_state.find_next_node()
		if next != null:
			_change_state(next)
		current_state.perform()

	move_and_slide()
	# The state that just ran set `velocity` from the controls; a knockback is
	# not something the player asked for, so it moves them on its own.
	apply_shove(delta)
	_mind_pits(delta)

## A frame on the floor: where the body last stood on floor, and whether it
## has walked over a pit's edge — not in a dash, which carries it over, and
## not while it is already falling — which drops it, costs it, and stands it
## back where it last stood.
func _mind_pits(delta: float) -> void:
	if fell > 0.0:
		fell -= delta
		if fell <= 0.0:
			fell = 0.0
			input.remove(_held_by_fall)
		return
	if room == null or not is_instance_valid(room) or not room.has_method("is_pit_at"):
		return
	if room.is_pit_at(global_position):
		if not is_dashing():
			_fall_in()
		return
	if not room.is_solid_at(global_position):
		_footing = global_position

## Into the pit: the fall's damage, which gets through whatever grace was
## running, the body back on its footing, held for the fall, and a moment's
## grace after it.
func _fall_in() -> void:
	fell_at = global_position
	fell = FALL_TIME
	stand_up()
	input.add(_held_by_fall)
	_dash_time = 0.0
	velocity = Vector2.ZERO
	Cues.at(&"fell", fell_at, {"team": team})
	apply_damage(PIT_DAMAGE, [], null, false)
	if dead:
		return
	global_position = _footing
	invuln = maxf(invuln, FALL_TIME + FALL_GRACE)

func _change_state(new_state: FSMNode) -> void:
	if debug_mode:
		print("State: %s → %s" % [_state_label(current_state), _state_label(new_state)])
	current_state = new_state

## Everything a state is picked from and acts on that is not the body itself:
## the stamina, which only comes back once the dashing stops.
func _sense(delta: float) -> void:
	if _stamina_pause > 0.0:
		_stamina_pause = maxf(0.0, _stamina_pause - delta)
	elif stamina < max_stamina:
		stamina = minf(max_stamina, stamina + STAMINA_REGEN * delta)

## --- state actions ----------------------------------------------------------
## What a state's steps can take, by the names `_setup_fsm` gives them. Each is
## one thing the body does on a frame; which a state takes, and in what order,
## is the table's.

## How fast the body goes flat out this frame: a walk, or a sprint while one
## is asked for, either quickened by what the profile adds (`_pace_mul`) and
## slowed by a chill.
func _pace() -> float:
	return (SPRINT_SPEED if _asked.sprint else RUN_SPEED) * _pace_mul * speed_scale()

## Slows to a stop.
func _action_brake() -> void:
	velocity = velocity.move_toward(Vector2.ZERO, FRICTION * get_physics_process_delta_time())

## Speeds up toward the way held, as hard as it is held: a stick half over
## walks at half pace.
func _action_run() -> void:
	velocity = velocity.move_toward(_dir * _pace(), GROUND_ACCEL * get_physics_process_delta_time())

## A press starts a dash, when the stamina and the cooldown allow. It takes
## over from the next frame, when the machine sees it under way.
func _action_dash() -> void:
	if _asked.dash_pressed and _dash_cd <= 0.0:
		if stamina < DASH_STAMINA:
			# Nothing happening at all reads as a dropped input, so say why.
			Cues.at(&"refused", global_position, {"kind": "stamina"})
		else:
			stamina -= DASH_STAMINA
			_stamina_pause = STAMINA_PAUSE
			# Whichever way they are held, or the way they face if they are not:
			# `facing` is set from `_dir` at the top of the frame, so it is
			# already what a moving player is asking for.
			_dash_dir = _dir.normalized() if _dir != Vector2.ZERO else facing
			_dash_time = DASH_TIME
			_dash_cd = DASH_COOLDOWN
			# Armed once, at the press, rather than topped up every frame of the
			# dash: what the move is worth as a dodge is then a window of its own
			# length, and not the dash's length plus whatever the top-up was.
			invuln = maxf(invuln, DASH_INVULN)
			Cues.at(&"dash", global_position, {"dir": _dash_dir})

## A dash under way carries the body until its time runs out.
func _action_rush() -> void:
	_dash_time -= get_physics_process_delta_time()
	velocity = _dash_dir * DASH_SPEED

## A guard window opened by ON PARRY swallows the hit and runs the branch flow.
func apply_damage(amount: float, elements: Array = [], source: Node = null, is_hit: bool = true) -> float:
	if parry_time > 0.0 and is_hit and amount > 0.0:
		parry_time = 0.0
		TimeCtl.hitstop(0.12)
		Cues.at(&"parry", global_position)
		invuln = maxf(invuln, 0.4)
		parry_success.emit()
		if runner != null:
			var p: Payload = runner.consume_parry()
			if p != null:
				_on_fired(p)
		return 0.0
	var dealt := super.apply_damage(amount, elements, source, is_hit)
	# A blow that gets through stands the body up off a bench.
	if dealt > 0.0 and is_hit:
		stand_up()
	# Damage over time ticks every frame, so the cue and the i-frames hang off
	# the blow that lit the burn rather than off the burning. Without `is_hit`
	# one Arbiter shot played its hurt sound a hundred and fifty times over the
	# 2.5s fire, and re-armed invulnerability every frame it did — which made
	# being on fire the safest place in the game.
	if dealt > 0.0 and is_hit:
		Cues.at(&"hurt", global_position, {"team": team})
		invuln = maxf(invuln, HURT_INVULN)
	return dealt

## --- a bench ----------------------------------------------------------------

## Sits the body down on `b` where it stands — at the seat, where the walk
## over brought it (`Bench`), to within WalkTo.THERE; it is not moved the rest
## of the way — and still. It stays sat until it is asked to do anything else
## — a step, a dash, an attack, a cast (`_mind_seat`) — or interact is pressed
## at the bench again, a blow gets through, it dies, or it leaves the room.
## The body sitting is the body standing still, as far as anything else in
## the game goes: only the picture of it sits.
func sit(b: Bench) -> void:
	if b == null or not is_instance_valid(b) or seat == b:
		return
	seat = b
	_sat_holding = true
	velocity = Vector2.ZERO
	Cues.at(&"sit", b.global_position, {"kind": "down"})

## Up off the bench, if the body is on one.
func stand_up() -> void:
	if seat == null:
		return
	seat = null
	Cues.at(&"sit", global_position, {"kind": "up"})

## A frame on a bench: whatever is asked of the body stands it up, and what
## asked goes ahead on the same frame — but not a way held since it sat down,
## until that has been let go of and pushed again. A bench gone from under it
## stands it up too.
func _mind_seat() -> void:
	if seat == null:
		return
	if _asked.move == Vector2.ZERO:
		_sat_holding = false
	if not is_instance_valid(seat) or (_asked.move != Vector2.ZERO and not _sat_holding) \
			or _asked.dash_pressed or _asked.attack or _asked.cast:
		stand_up()

## Whether the body sits on a bench.
func seated() -> bool:
	return seat != null and is_instance_valid(seat)

## --- read by the view -------------------------------------------------------
func is_dashing() -> bool:
	return _dash_time > 0.0

## Whether the body is down a pit, between falling in and standing again.
func falling() -> bool:
	return fell > 0.0

## Whether the body is walking: a way is held, and it is not sat down.
func is_walking() -> bool:
	return _dir != Vector2.ZERO

## The movement state, by name: Idle, Walk or Dash.
func state_name() -> String:
	return _state_label(current_state)

func _state_label(state: FSMNode) -> String:
	return state.label if state != null else "Unknown"

## 0 → 1 as the dash comes back; 1 when it is ready.
func dash_recovery() -> float:
	if _dash_cd <= 0.0:
		return 1.0
	return clampf(1.0 - _dash_cd / DASH_COOLDOWN, 0.0, 1.0)
