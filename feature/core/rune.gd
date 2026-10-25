class_name Rune
extends RefCounted

## The rune's store (`Weapons.is_rune`): the charge stored in it, which its
## next throw carries for nothing, and whether it is spent. There is one rune,
## so one store of it, kept with the profile wherever the rune is — in hand,
## lying in a room, or dropped with the kit (`GameState.rune`). A throw spends
## it all: the rune casts nothing until the player's own mana has filled it
## again (`Player.refill_rune`). It starts lit, with one full charge of a
## player with no perks in it. Nothing here draws.

## What a new profile's holds: a full charge of a player with no perks.
const START := Charge.MAX_CHARGE_TTL * Charge.MANA_PER_TTL

var mana: float = START
var spent: bool = false

## The mana a full rune holds for a player who can charge to `cap`: what a
## hold to the most they can charge costs — so a rune holds one full charge,
## and DEEP CHARGE makes it a deeper one.
static func full(cap: float) -> float:
	return cap * Charge.MANA_PER_TTL

## The charge a throw of the lit rune carries for a player who can charge to
## `cap`: as much as the mana in it buys, up to that. The rune pays, not the
## player.
func charge_in(cap: float) -> int:
	return int(minf(cap, mana / Charge.MANA_PER_TTL))

## How much mana it lacks of full, for a player who can charge to `cap`.
func lacks(cap: float) -> float:
	return maxf(full(cap) - mana, 0.0)

## `amount` of mana poured in. Full, it is lit again, and says so: whether it
## lit on this pour.
func fill(amount: float, cap: float) -> bool:
	mana += amount
	if mana >= full(cap) - 0.001:
		mana = full(cap)
		spent = false
		return true
	return false

## A throw of the lit rune: the charge in it goes out with the throw, and the
## rune is dead until it is filled again.
func spend() -> void:
	mana = 0.0
	spent = true

## As a new profile has it.
func reset() -> void:
	mana = START
	spent = false

## Read back off the profile's save, a save from before the rune reading as
## full. `GameState.save_game` writes the two numbers by the same names.
func load(d: Dictionary) -> void:
	mana = maxf(float(d.get("rune_mana", START)), 0.0)
	spent = bool(d.get("rune_spent", false))
