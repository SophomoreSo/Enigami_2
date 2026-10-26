extends Node

## What every gameplay cue looks like.
##
## This is the graphics module's half of the seam: `feature/` says *a hit
## landed*, and the table below decides that a hit landed means six sparks in
## the payload's element colour and three pixels of shake. Retuning the feel of
## the whole game is an edit to this one file, and it touches no rule.
##
## An unhandled cue is silence, not an error.
##
## A cue carries ids and numbers, never a line: what a moment says on screen is
## spelled here, out of `localization/` like every other word, so a boss
## changing form is announced in the language being played.

func _ready() -> void:
	Cues.fired.connect(_on_cue)

func _on_cue(cue: StringName, d: Dictionary) -> void:
	var pos: Vector2 = d.get("pos", Vector2.ZERO)
	match cue:
		&"hit":
			Fx.burst(pos, Style.element_color(d.get("payload")), 6, 150.0)
			Fx.shake(3.0)
		&"impact":
			# A bolt that ran out of range rather than into something goes out
			# with a smaller, slower puff: the same colour, so it reads as the
			# same shot, but plainly not a hit.
			var kind := String(d.get("kind", ""))
			var col := Style.element_color(d.get("payload"))
			if kind == "fade":
				Fx.burst(pos, col, 5, 55.0)
			else:
				Fx.burst(pos, col, 6 if kind == "spent" else 5,
					130.0 if kind == "spent" else 110.0)
		&"melee_arc":
			Fx.shake(2.5)
		&"area_blast":
			Fx.shake(6.0)
		&"near":
			# NEAR's reach going out round the one struck: its ring is the
			# burst's own (`AreaBurstView`); no more than a nudge to the screen.
			Fx.shake(1.5)
		&"lunge_cut":
			Fx.shake(4.0)
		&"pet_kamikaze":
			# The pet goes up in pieces where it struck; the burst's own ring and
			# shake come with the blast (`area_blast`).
			Fx.burst(pos, Style.category_color(Components.CAT_SUMMON_BEHAVIOR), 14, 160.0)
		&"summon_pet":
			Fx.ring(pos, Style.category_color(Components.CAT_SUMMON_BEHAVIOR), 30.0)
			Fx.burst(pos, Style.category_color(Components.CAT_SUMMON_BEHAVIOR), 8, 90.0)
		&"rune_lit":
			# Filled to the top: it lights again.
			Fx.ring(pos, Style.RUNE_GLOW, 46.0)
			Fx.burst(pos, Style.RUNE_GLOW, 10, 140.0)
		&"rune_spent":
			# The last of its mana gone out with the cast that drained it.
			Fx.burst(pos, Style.RUNE_GLOW.darkened(0.4), 6, 60.0)
		&"stone_cast":
			# The throw going off where the stone stopped: a ring in its colour.
			Fx.ring(pos, Style.element_color(d.get("payload")), 34.0)
		&"wall_slam":
			# The rock cracks where the body struck it, and dust comes off it.
			var force := float(d.get("force", 1.0))
			Fx.crack(pos, d.get("normal", Vector2.LEFT), force)
			Fx.burst(pos, Style.WALL_DUST, 8, 120.0)
			Fx.shake(4.0 + 2.0 * minf(force, 2.0))
		&"magic":
			# The world's colour going, or coming back: a small shake under it.
			# The grey itself is the pixel camera's, every frame.
			Fx.shake(2.0)
		&"death":
			Fx.burst(pos, _death_color(d.get("actor")), 14, 230.0)
		&"dash":
			# Dust kicked off the floor at the feet, back the way the dash came
			# from. The body is drawn at its feet, so the dust is at `pos`.
			var way: Vector2 = d.get("dir", Vector2.DOWN)
			Fx.burst(pos - way * 6.0, Style.FOOT_DUST, 4, 70.0)
		&"fell":
			# Down a pit: dust up off its edge, and the screen jolts.
			Fx.burst(pos, Style.WALL_DUST, 6, 80.0)
			Fx.shake(5.0)
		&"refused":
			# The rule names what refused the press, and the word for it is the
			# picture's: WINDED, in the language being played. A weapon's
			# refusal comes with its own line, saying which skill it would not
			# carry.
			var kind := String(d.get("kind", ""))
			var text := String(d.get("text", ""))
			if kind == "stamina":
				text = Loc.t("hud.fx.winded")
			elif kind == "thrown":
				# The rock is not in the hand: NO ROCK, over whoever reached for it.
				text = Loc.t("hud.fx.no_weapon", [Weapons.name_for(String(d.get("weapon", ""))).to_upper()])
			Fx.text(pos + Vector2(0, -44), text, Style.refuse_color(kind))
		&"rock_down":
			# Dust off the floor, for a rock coming down hard enough to raise it.
			if float(d.get("speed", 0.0)) > 260.0:
				Fx.burst(pos, Style.WALL_DUST, 3, 60.0)
		&"rock_back", &"shuriken_back":
			Fx.burst(pos, Style.weapon_color(String(d.get("weapon", ""))), 6, 90.0)
		&"possess":
			# Into the monster: a ring closing on it, the colour of the part.
			Fx.ring(pos, Style.POSSESS_COLOR, 70.0)
			Fx.burst(pos, Style.POSSESS_COLOR, 12, 160.0)
		&"possess_end":
			Fx.burst(pos, Style.POSSESS_COLOR, 10, 120.0)
		&"weapon_taken":
			Fx.burst(pos, Style.POSSESS_COLOR, 6, 90.0)
		&"shatter":
			# Frost coming apart reads as shards, not as a bigger hit.
			Fx.burst(pos, Style.SHATTER_SPARK, 10, 210.0)
			Fx.shake(4.0)
		&"mana_drain":
			Fx.burst(pos, Style.MANA_SPARK, 4, 90.0)
		&"stun":
			Fx.burst(pos + Vector2(0, -18), Style.STUN_COLOR, 6, 70.0)
		&"cleanse":
			Fx.burst(pos, Style.CLEANSE_COLOR, 8, 120.0)
		&"parry":
			Fx.shake(8.0)
			Fx.ring(pos, Style.PARRY, 60.0)
			Fx.text(pos + Vector2(0, -30), Loc.t("hud.fx.parry"), Style.PARRY)
		&"hurt":
			Fx.shake(7.0)
		&"boss_phase":
			Fx.shake(14.0)
			Fx.ring(pos, Style.BOSS_RING, 160.0)
			Fx.text(pos + Vector2(0, -60), Loc.t("hud.fx.boss_phase",
				[Monsters.name_for(String(d.get("kind", ""))).to_upper()]), Style.BOSS_TEXT)
		&"pickup":
			Fx.burst(pos, Style.loot_color(String(d.get("id", "")), int(d.get("scrap", 0))), 6, 120.0)
		&"crate_break":
			# Splinters off the planks, and a glint of the gold coming out.
			Fx.burst(pos + Vector2(0, -8), CrateView.WOOD_LIT, 12, 170.0)
			Fx.burst(pos + Vector2(0, -8), CrateView.GOLD, 4 + int(d.get("gold", 0)), 120.0)
			Fx.shake(2.0)
		&"box_open":
			Fx.burst(pos + Vector2(0, -8), Style.TREASURE_BAND, 10 + 3 * int(d.get("count", 0)), 160.0)
		&"kit_back":
			# Bigger than a part being picked up, because it is: everything a
			# run was carrying, coming back in one go.
			Fx.burst(pos, Style.LOST_KIT, 18, 240.0)
			Fx.ring(pos, Style.LOST_KIT, 120.0)
		&"travel":
			Fx.burst(pos, Style.TRAVEL_DUST, 8, 120.0)
		&"extract_tick":
			Fx.burst(pos, Style.EXTRACT_SPARK, 2, 60.0)
		&"raid_lost":
			Fx.shake(16.0)

## A death throws the colour of whatever died.
func _death_color(actor) -> Color:
	if actor is Enemy and is_instance_valid(actor):
		if (actor as Enemy).phase > 1:
			return Style.BOSS_PHASE2_COLOR
		return Style.monster_color((actor as Enemy).kind)
	return Style.PLAYER_COLOR
