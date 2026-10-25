class_name Payload
extends RefCounted

## The value that travels along a skill flow. Every component mutates it, and
## whatever leaves the board by its way out becomes a real effect in the world.
##
## Its fields are the schema: a part's `effects` row names one, and is refused
## as the parts are read if the field is not here or cannot take what the row
## does (`Components._effect`); the workbench's preview has a word for each
## that does something when a hit lands (`Attacks.WORDS`); and `clone` copies
## every one. `fields()` lists them off the declarations, and
## tests/circuit/payload_test holds `clone` to the lot, so a field added here
## and forgotten there fails rather than being quietly lost at the first hop.

## How far a bolt carries before it fades, in pixels. A room is 40 cells of 32
## across, so the standard reach is an eighth of one — five cells: you fight
## inside a part of the room rather than across the whole of it, and closing the
## distance is most of what a ranged build spends its time doing. Every weapon scales it
## (`Weapons.finalize`), SPEED extends it, and a monster's shot is given the
## reach its own attack range needs (`Enemy._make_runner`).
##
## It is a property of the shot rather than a constant on the bolt because that
## is where the answer differs: a gun outranges a thrown rock, and a Sentry
## outranges both or it could never hit anything from where it sits.
const BASE_RANGE := 160.0

var damage: float = 10.0
var size: float = 1.0
var speed: float = 1.0
var range_px: float = BASE_RANGE
## How far a lunge carries, as a share of its own reach: SWIFT STRIKE's, which
## is a distance of the attack's own rather than a range a shot flies to — see
## `Attacks.DASH_SLASH_REACH`. RANGE is what changes it.
var lunge: float = 1.0
var form: String = ""              ## "", PROJECTILE, SLASH, DASHSLASH, HEADBUTT
var elements: Array[String] = []   ## FIRE / ICE
var pierce: int = 0                ## extra targets an attack passes through
## The behaviours below are counts, not flags: 0 is without, and every part of
## the kind the flow passes adds one, so a board that stacks them does the same
## thing harder — a tighter turn, a stronger drag, a longer throw.
var homing: int = 0                ## tracks the nearest enemy, and finds its way round walls
var auto_aim: int = 0              ## goes at the nearest enemy, wherever it was aimed
## Weightless: a bolt flies with no gravity on it — a lobbed one goes straight
## rather than arcing (ANTI-GRAVITY).
var anti_gravity: int = 0
## BOUNCE: how many walls and floors a bolt comes back off before one ends it.
var bounce: int = 0
## BOOMERANG (RETURN): a bolt turns back to whoever cast it at the end of its
## range, or off a wall, and strikes again on the way; a thrown stone comes
## back to the hand (`Projectile._turn_back`). One is all it takes.
var returns: int = 0
## CHAIN: on a hit, a fresh bolt leaves the enemy struck for the nearest other
## one, with one jump fewer left (`Projectile._chain_from`).
var chain: int = 0
var knockback: int = 0             ## the struck enemy is thrown on along the attack
## NEAR: how many the flow has been through, which is how far round the enemy
## struck it reaches (`Attacks.near_radius`), and `spread`, what every part after
## the first of them did — those parts' effects alone, on a payload of nothing,
## which the runner builds as the flow goes on through them (`SkillRunner._apply`).
## What lands on the enemies round the one struck is `spread` (`Attacks._near`);
## with no form there is no blow and no enemy struck, and it lands on the
## enemies round where the flow goes off.
var near: int = 0
var spread: Payload = null
## On a NEAR's touch, how hard the blow it spreads from landed, which is what a
## burn it carries is worked from; -1 on every other hit (`Attacks.resolve_hit`).
## And where its middle is — the enemy struck, or where a NEAR with no form went
## off — which a PULL on it drags the enemy touched in to.
var touch: float = -1.0
var touch_at: Vector2 = Vector2.ZERO
var shatter: int = 0               ## breaks the frost on a slowed enemy, for far more damage
var mana_drain: int = 0            ## every connection pays the caster back
var health_drain: int = 0          ## every hit that hurts heals the caster a share of it
var stun: float = 0.0              ## seconds the struck enemy stands stunned
## Seconds the player's hands go into the monster struck (`Player.possess`).
var possess: float = 0.0
## What the attack calls up beside itself as it goes off (`Attacks.spawn`): a
## pet for a SUMMON PET.
var summon_pet: int = 0
## What a pet this flow summons does (`Pet`): with OFFENSIVE it goes for the
## nearest enemy near its summoner and strikes it, more often for each one;
## with KAMIKAZE it goes for that enemy and blows itself up against it, wider
## for each one.
var pet_offensive: int = 0
var pet_kamikaze: int = 0
## What an INVERT makes of the part before it (the `inversions` rows), each
## landing on the struck enemy once the hit has: health given back, every burn,
## chill and stun it was carrying ended — though not what this same hit brings
## it — the struck one dragged toward whoever struck it rather than thrown on
## (KNOCKBACK's — and PULL's own, `hook` being what PULL adds to).
var heal: float = 0.0
var cleanse: bool = false
var hook: int = 0
var duplicates: int = 1
var heat: float = 0.0              ## accumulated while travelling; feeds cycle cooldown
var branch: String = ""            ## "", "ON_HIT", "ON_KILL", "ON_PARRY"
## Set on an attack spawned as a trigger's follow-up. The chain it belongs to is
## one blow, so its links do not each stop the clock like a blow of their own.
var follow_up: bool = false

## How many times each part has done its work on this flow, by id: what a
## part's `stack_limit` is counted against (`SkillRunner._apply`), and how
## anything asks whether a part has been stacked to its limit (`at_limit`).
var stacks: Dictionary = {}

## Trigger payloads resolved from branch flows, attached at fire time.
var on_hit: Payload = null
var on_kill: Payload = null
var on_parry: Payload = null

## The fields a payload has, in the order they are declared — the schema, read
## off the declarations once. `spread` is a payload of its own and is copied as
## one; the triggers are shared between a flow and its copies (`SHARED`).
static var _fields: Array[StringName] = []
const SHARED := [&"on_hit", &"on_kill", &"on_parry"]

static func fields() -> Array[StringName]:
	if _fields.is_empty():
		for prop in (Payload as GDScript).get_script_property_list():
			if prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
				_fields.append(StringName(prop["name"]))
	return _fields

## Every field, by hand, since this runs on every hop of every pulse: a copy
## by name over `fields()` costs several times as much. payload_test checks
## nothing is missing here.
func clone() -> Payload:
	var p := Payload.new()
	p.damage = damage
	p.size = size
	p.speed = speed
	p.range_px = range_px
	p.lunge = lunge
	p.form = form
	p.elements = elements.duplicate()
	p.pierce = pierce
	p.homing = homing
	p.auto_aim = auto_aim
	p.anti_gravity = anti_gravity
	p.bounce = bounce
	p.returns = returns
	p.chain = chain
	p.knockback = knockback
	p.near = near
	p.spread = spread.clone() if spread != null else null
	p.touch = touch
	p.touch_at = touch_at
	p.shatter = shatter
	p.mana_drain = mana_drain
	p.health_drain = health_drain
	p.stun = stun
	p.possess = possess
	p.summon_pet = summon_pet
	p.pet_offensive = pet_offensive
	p.pet_kamikaze = pet_kamikaze
	p.heal = heal
	p.cleanse = cleanse
	p.hook = hook
	p.duplicates = duplicates
	p.heat = heat
	p.branch = branch
	p.follow_up = follow_up
	p.stacks = stacks.duplicate()
	p.on_hit = on_hit
	p.on_kill = on_kill
	p.on_parry = on_parry
	return p

func has_element(e: String) -> bool:
	return elements.has(e)

## How many of part `id` this flow has been through that did their work.
func stack(id: String) -> int:
	return int(stacks.get(id, 0))

## Whether part `id` has a limit and this flow has reached it.
func at_limit(id: String) -> bool:
	var limit := Components.limit_of(id)
	return limit > 0 and stack(id) >= limit

## Does this payload do anything at all when it leaves the board? An attack, or
## with no form a NEAR, which touches the enemies round where it goes off.
func is_productive() -> bool:
	return form != "" or (near > 0 and spread != null)
