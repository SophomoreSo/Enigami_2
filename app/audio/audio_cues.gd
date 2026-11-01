extends Node

## What every gameplay cue sounds like.
##
## The mirror of `graphics/cue_visuals.gd`, and deliberately separate from it:
## sound and picture answer to the same moments but neither has to know the
## other exists, and a silent build is a build with this autoload removed.

func _ready() -> void:
	Cues.fired.connect(_on_cue)

func _on_cue(cue: StringName, d: Dictionary) -> void:
	match cue:
		&"music_start":
			Audio.play_music()
		&"attack":
			match String(d.get("form", "")):
				"PROJECTILE":
					# A thrown weapon is not shot: it goes out of the hand with
					# a rush of air rather than a crack.
					if String(d.get("thrown", "")) != "":
						Audio.play("dash", 0.7)
					else:
						Audio.play("shoot")
				"SLASH": Audio.play("slash")
				# A punch is a swing of the arm, lower than a blade's.
				"HEADBUTT": Audio.play("slash", 0.7)
		&"rock_down":
			# A thud, for a rock coming down hard enough to be heard.
			if float(d.get("speed", 0.0)) > 260.0:
				Audio.play("hit", 0.5)
		&"rock_back":
			Audio.play("pickup", 1.25)
		&"shuriken_back":
			Audio.play("pickup", 1.5)
		&"area_blast":
			Audio.play("explode")
		&"near":
			Audio.play("zap", 1.5)
		&"lunge_cut", &"dash":
			Audio.play("dash")
		&"summon_pet":
			Audio.play("pickup", 0.9)
		&"rune_lit":
			Audio.play("pickup", 1.6)
		&"rune_spent":
			Audio.play("zap", 0.7)
		&"stone_cast":
			Audio.play("zap", 1.1)
		&"wall_slam":
			# A thud, heavier than a hit.
			Audio.play("hit", 0.55)
		&"magic":
			# Off, a low crackle as it goes; on, a bright note as it comes back.
			if bool(d.get("on", true)):
				Audio.play("pickup", 1.2)
			else:
				Audio.play("zap", 0.5)
		&"hit":
			Audio.play("hit", 1.0 + randf_range(-0.12, 0.12))
		&"death":
			Audio.play("death", 1.0 + randf_range(-0.1, 0.1))
		&"hurt":
			Audio.play("hurt")
		&"shatter":
			Audio.play("hit", 1.55)
		&"mana_drain":
			Audio.play("pickup", 1.4)
		&"stun":
			Audio.play("zap", 0.55)
		&"heal":
			Audio.play("pickup", 1.05)
		&"cleanse":
			Audio.play("pickup", 1.8)
		&"parry":
			Audio.play("parry")
		&"refused":
			Audio.play("deny", 0.85 if String(d.get("kind", "")) == "stamina" else 1.0)
		&"pickup":
			Audio.play("pickup")
		&"bird_flight":
			# Wingbeats, a little different every bird, so a flock is many.
			Audio.play("flutter", 1.0 + randf_range(-0.12, 0.12))
		&"crate_break":
			# A crack of wood: a hit's sound, low.
			Audio.play("hit", 0.7 + randf_range(-0.05, 0.05))
		&"generator_crash":
			# A machine coming apart: a blast, low.
			Audio.play("explode", 0.85)
		&"gate":
			# A gate going down crackles out low; coming up, it catches high.
			Audio.play("zap", 1.25 if bool(d.get("up", true)) else 0.45)
		&"gate_shock":
			Audio.play("zap", 1.0 + randf_range(-0.1, 0.1))
		&"sight":
			# A sight coming on: a thin high note. Going off is magic's to say.
			if String(d.get("seeing", "")) != "":
				Audio.play("zap", 1.7)
		&"box_open":
			# A pickup's chime, lower: several things at once, out of a box.
			Audio.play("pickup", 0.8)
		&"kit_back":
			# The extraction chime, a little lower: getting the kit back is the
			# same kind of relief, one step short of being out with it.
			Audio.play("extract", 0.85)
		&"boss_phase":
			Audio.play("boss")
		&"extract_done":
			Audio.play("extract")
		&"ui":
			Audio.play("ui", UI_PITCH.get(String(d.get("kind", "")), 1.0))
		&"phone":
			# The phone: up with a click, away with a lower one, an alarm set
			# with a chime, put down with a tap and picked up with the chime
			# again, and the shutter's snap.
			match String(d.get("kind", "")):
				"open": Audio.play("ui", 1.1)
				"close": Audio.play("ui", 0.85)
				"set": Audio.play("pickup", 1.3)
				"stop": Audio.play("ui", 0.7)
				"down": Audio.play("place")
				"up": Audio.play("pickup", 1.1)
				"shutter": Audio.play("place", 1.6)
		&"phone_ring":
			# The ring itself, every call while it rings: a high chirp.
			Audio.play("pickup", 1.6)
		&"possess":
			Audio.play("parry", 0.75)
		&"possess_end":
			Audio.play("ui", 0.8)
		&"weapon_taken":
			Audio.play("pickup", 0.9)
		&"weapon_switch":
			# The bench's weapon swap, a step higher for each slot along, so
			# three weapons are three notes and the hand learns which is which.
			Audio.play("ui", float(UI_PITCH.get("weapon", 1.0)) + 0.12 * float(int(d.get("slot", 0))))
		&"talk":
			_line_sound(d.get("line", {}))
		&"talk_letter":
			_voice(d.get("line", {}))
		&"scene_line":
			_line_sound(d.get("beat", {}))
		&"scene_letter":
			_voice(d.get("beat", {}))
		&"scene_direction":
			_direction_sound(d.get("direction", {}))

## A cutscene direction that names a sound. Everything else a direction carries
## is the picture's business and is ignored here, the same way a dialogue line's
## camera is.
func _direction_sound(d: Dictionary) -> void:
	if d.has("sfx"):
		_play_named(String(d["sfx"]), "A scene")

## The sound a dialogue line or a cutscene beat names for its start (`sfx`).
func _line_sound(line: Dictionary) -> void:
	_play_named(String(line.get("sfx", "")), "Dialogue")

## Plays a sound a data file asked for by name, and says so rather than falling
## silent when the bank has no such sound.
func _play_named(id: String, who: String) -> void:
	if id == "":
		return
	if not Audio.has(id):
		push_warning("%s asks for sound '%s', which is not in the bank" % [who, id])
		return
	Audio.play(id)

## The blip under a line's typing, in the register its `voice` names. "none", or
## a register this does not know, is silent.
func _voice(line: Dictionary) -> void:
	var voice := String(line.get("voice", "mid"))
	if VOICE_PITCH.has(voice):
		Audio.play("voice", VOICE_PITCH[voice])

const UI_PITCH := {"arm": 1.2}
const VOICE_PITCH := {"low": 0.72, "mid": 1.0, "high": 1.4}
