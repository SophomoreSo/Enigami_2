class_name Charge
extends RefCounted

## The player's mana, and the charge a hold of the cast button builds out of
## it: what was a dozen fields and a tick spread through `Player`, with the
## same four-line reset written in three places. Mana is what charging spends,
## and the longer the hold the more of it goes. Holding the cast button builds
## the charge; releasing it is what casts, with whatever was built. Charging
## engages on every skill alike — nothing is special-cased on the shape of the
## board — and the life it buys is spent by whatever cycle the player put there
## to spend it. The first cast of a hold still goes out at once — charge is
## what the ones after it ride on, so holding is a decision about depth, not a
## wind-up that delays the opening shot.
##
## Whether a hold may charge at all is the player's to say (`Player.can_charge`:
## a graph still recovering, a rock out of hand, magic off, the rune in hand);
## this only builds, bleeds, pays and refills. Nothing here draws.

const MAX_MANA := 100.0
const MANA_REGEN := 20.0          ## per second
const MANA_PAUSE := 0.6           ## quiet after charging before any returns
const CHARGE_TTL_RATE := 12.0     ## extra life bought per second of holding
const MANA_PER_TTL := 1.4
const MAX_CHARGE_TTL := float(SkillRunner.MAX_TTL_BONUS)
const CHARGE_DECAY := 150.0       ## how fast an unspent charge bleeds off
const CAST_BUFFER := 0.18         ## grace for a release landing on a cooldown

var mana: float = MAX_MANA
## The bar's ceiling, with what the profile adds to it (`reboost`).
var max_mana: float = MAX_MANA
## Extra life being built up while the button is held, in TTL.
var charge: float = 0.0
## What the last release actually paid for, carried by the cast it bought.
var cast_charge: float = 0.0
## How long a release waits for a cycle to carry it, so one landing on the tail
## of the last cooldown still goes off instead of being swallowed.
var buffer: float = 0.0
## Quiet left after charging before mana comes back.
var pause: float = 0.0
## True while the cast button is actually buying life. Read rather than
## announced: it is a state that lasts, not a moment that happens.
var charging: bool = false
## What the profile adds: how much faster a hold builds (QUICK CHARGE), and
## the most it can build to (DEEP CHARGE).
var rate_mul: float = 1.0
var cap: float = MAX_CHARGE_TTL

## A frame of the hold. While the button is down and the hold `may` charge,
## the charge only ever holds or grows — letting the decay branch run once it
## reached the cap made the two fight each other frame by frame, charge
## sitting just under the cap while mana drained away into the gap being
## refilled. Let go, or held on a graph that may not charge, it bleeds off, and
## the mana comes back after its pause.
func tick(delta: float, holding: bool, may: bool) -> void:
	if holding and may:
		charging = true
		if charge < cap and mana > 0.0:
			# QUICK CHARGE builds it faster; the mana goes as fast as it builds.
			var want := CHARGE_TTL_RATE * rate_mul * delta
			var afford := mana / MANA_PER_TTL
			var gained := minf(minf(want, afford), cap - charge)
			charge += gained
			mana = maxf(0.0, mana - gained * MANA_PER_TTL)
		pause = MANA_PAUSE
		return
	charging = false
	charge = maxf(0.0, charge - CHARGE_DECAY * delta)
	if pause > 0.0:
		pause = maxf(0.0, pause - delta)
	elif mana < max_mana:
		mana = minf(max_mana, mana + MANA_REGEN * delta)

## The hold let go of for nothing: a weapon put away, the hands gone into a
## monster, a kit handed out again. Whatever was being charged is lost.
func let_go() -> void:
	charge = 0.0
	cast_charge = 0.0
	buffer = 0.0
	charging = false

## The button released on a graph that can cast: what was built is the cast's
## to carry, and the release waits CAST_BUFFER for a cycle to carry it.
func release() -> void:
	cast_charge = charge
	charge = 0.0
	buffer = CAST_BUFFER

## The release's wait runs down.
func wait(delta: float) -> void:
	buffer = maxf(0.0, buffer - delta)

## The life the cast starting now gets: what the release paid for, while the
## release is still waiting for one, and nothing after.
func ttl_bonus() -> int:
	return int(cast_charge) if buffer > 0.0 else 0

## Whether a release is still waiting for a cycle to carry it.
func waiting() -> bool:
	return buffer > 0.0

## Mana given back — by a MANA DRAIN landing — whatever the charge is doing.
func gain(amount: float) -> void:
	mana = minf(max_mana, mana + maxf(amount, 0.0))

## Up to `amount` of mana poured out — into a spent rune — and the quiet after
## charging with it, so the bar does not fill itself while it pours. How much
## went.
func pour(amount: float) -> float:
	var out := minf(maxf(amount, 0.0), mana)
	mana -= out
	pause = MANA_PAUSE
	return out

## How full the charge is, against the most this player can hold: a full bar
## is a full hold however far DEEP CHARGE has taken it.
func ratio() -> float:
	return clampf(charge / cap, 0.0, 1.0)

func mana_ratio() -> float:
	return clampf(mana / max_mana, 0.0, 1.0)

## What the profile adds, taken again: a perk bought, a profile opened. What
## the ceiling gained is added to what is under it, so a full bar stays full;
## one that came down leaves nothing over it.
func reboost(ceiling: float, quicker: float, deeper: float) -> void:
	var had := max_mana
	max_mana = ceiling
	mana = minf(mana + maxf(max_mana - had, 0.0), max_mana)
	rate_mul = quicker
	cap = deeper
