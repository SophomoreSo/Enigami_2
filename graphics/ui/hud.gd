class_name Hud
extends Control

## Raid HUD: health, the bars a fight spends, and the weapons carried — the
## one in hand lit, the others beside it under the number of the key that
## draws each.
##
## Drawn rather than built, in UiKit's pixel look: Silkscreen at its own size,
## boxes square and unsmoothed with a PIXEL of edge, everything on the PIXEL
## grid — the standard the assembly screen and the bench readout are held to,
## and `PixelDraw` is the kit for all three. This was the last screen still
## writing in the default face at nine pixels, which read as another game's
## interface laid over this one.
##
## The pixel face runs up to twice as wide as the one it replaced, so the
## numbers it stands on are bigger too: the bars and the gaps between them are
## all `PIXEL`-multiples.
##
## What is not here is deliberate. The map is a window of its own now — see
## `MapPanel`, opened from `RaidView` — and the bag is gone: a list of parts
## nobody can spend until they are at the workbench was five lines of the screen
## saying nothing the assembly screen does not say better. Nor are the two lines
## of keys that ran along the bottom: what each key does is the controls
## screen's to say. Nor is the graph's square that stood under the bars with
## the wait until the next cast on it. Nor is a line across the top saying what
## just happened — the player deployed, loot picked up, a box opened: nothing is
## written over the room.
##
## It steps aside while somebody talks to the player (`talking`). A conversation
## in the box holds the player still and has the screen, and the bars are a
## readout of a fight nobody is in: only something else to look at beside the
## box.
##
## And it is put away while the screen the assembly board is on is up, on
## either of its pages — the board's, or in a raid the map's — by the view that
## opens it, which knows when it does. The screen has it all, and its top, the
## back arrow and the tabs (`ScreenTabs`), stands in the corner the bars do.

## The bars in the top-left corner: health, then the two thin ones under it.
const BAR_W := 264.0
const BAR_AT := Vector2(24, 24)
const HEALTH_H := 24.0
const THIN_H := 12.0
## The baseline of the line under the bars, naming the weapons and what is
## burning, freezing or stunning whoever carries them: the last thing in the
## corner.
const WEAPON_LINE := 108.0
## How much of its colour a weapon that is carried but not in hand is written
## in: there to be read, and plainly not the one the buttons fire.
const AWAY := 0.4
## How far the prompt stands off the bottom, no longer pushed up by a row of
## cards.
const PROMPT_LIFT := 92.0

## What a bar is drawn on, and the edge around it. Shared by all four of them,
## so a meter reads as a meter wherever it is.
const BAR_GROUND := Color(0, 0, 0, 0.55)
const BAR_EDGE := Color(0.5, 0.6, 0.7, 0.8)

## How long the readout takes to step aside as a conversation opens, and to come
## back once it is over: about as long as the box takes to open.
const STEP_ASIDE := 0.14

## The grey MAGIC OFF is written in: the colour the world has gone.
const MAGIC_OFF_INK := Color(0.72, 0.72, 0.76)

var player: Player = null
var prompt: String = ""
## Whether the player stands in an exit that will take them. The HUD writes the
## line for it, since the line names the key that extracts, and which key that
## is — after a rebind, or on a phone — is the picture's to know.
var extract_offered: bool = false
var extract_ratio: float = 0.0
## How much of the readout is on the screen: 1, or 0 once it has stepped aside
## for a conversation.
var shown: float = 1.0
## The pixel grid, bound to this screen.
var _px := PixelDraw.new(self)

func _ready() -> void:
	UiKit.fill_screen(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	UiKit.sync_screen(self)
	shown = move_toward(shown, 0.0 if talking() else 1.0, delta / STEP_ASIDE)
	modulate.a = shown
	queue_redraw()

## Whether somebody is talking to the player in the box: `Player.talk_locked`,
## which the NPC holds for exactly as long as the conversation is open.
func talking() -> bool:
	return player != null and is_instance_valid(player) and player.talk_locked

func _draw() -> void:
	if player == null or not is_instance_valid(player) or shown <= 0.0:
		return
	var vp := get_viewport_rect().size
	_draw_health()
	_draw_prompts(vp)
	_draw_phone(vp)

## The phone's alarm, while one is set or ringing: along the top of the
## screen, in the middle, where neither the bars nor the console's plates
## stand — and that the phone is lying on a floor somewhere, while it is.
func _draw_phone(vp: Vector2) -> void:
	if not (Phone.alarm_set() or Phone.ringing > 0.0):
		return
	var band := 400.0
	var line := ""
	var ink := Color(0.85, 0.9, 0.95)
	if Phone.ringing > 0.0:
		line = Loc.t("hud.phone.hud.ringing")
		ink = UiKit.WARN
		ink.a = 0.55 + 0.45 * absf(sin(float(Time.get_ticks_msec()) / 90.0))
	else:
		line = Loc.t("hud.phone.hud.alarm", [PhoneScreen._clock(Phone.alarm)])
	if not Phone.carried():
		line += "  " + Loc.t("hud.phone.hud.down")
	_px.text_centered(Vector2((vp.x - band) * 0.5, 40.0), line, ink, band)

func _draw_health() -> void:
	var bar := Rect2(BAR_AT, Vector2(BAR_W, HEALTH_H))
	_px.bar(bar, player.health_ratio(), Color(0.9, 0.35, 0.38), BAR_GROUND, BAR_EDGE)
	# Inside the bar rather than over it: at this size the numbers are tall
	# enough to sit in it, and it is one less line down the side of the screen.
	_px.text(bar.position + Vector2(8, 18),
		Loc.t("hud.health", [int(player.health), int(player.max_health)]),
		Color(1, 1, 1, 0.9), BAR_W - 16.0)
	_draw_stamina()
	_draw_mana()

	# The weapons, and what is burning, freezing or stunning whoever carries
	# them, on one line: each stands where the one before it ended, so a long
	# name in any language pushes them along rather than being written over.
	var at := Vector2(BAR_AT.x, WEAPON_LINE)
	at.x = _draw_kit(at)
	# Magic off stands first on the line: it is what every weapon on it casts as.
	if not Magic.on:
		var off := Loc.t("hud.magic_off")
		_px.text(at, off, MAGIC_OFF_INK)
		at.x += PixelDraw.text_width(off) + 16.0
	if player.vessel() != player:
		var inside := Loc.t("hud.possessing", [Monsters.name_for(player.possessing.kind).to_upper(),
			ceili(player.possess_left)])
		_px.text(at, inside, Style.POSSESS_COLOR)
		at.x += PixelDraw.text_width(inside) + 16.0
	if player.burn_time > 0.0:
		var burning := Loc.t("hud.burning")
		_px.text(at, burning, Color(1, 0.5, 0.2))
		at.x += PixelDraw.text_width(burning) + 16.0
	if player.wet_time > 0.0:
		var wet := Loc.t("hud.wet")
		_px.text(at, wet, Style.ELEMENT_COLOR["WATER"])
		at.x += PixelDraw.text_width(wet) + 16.0
	# Frozen solid says so in place of the chill and the stun it is both of.
	if player.frozen():
		_px.text(at, Loc.t("hud.frozen"), Style.FROZEN_TINT)
	else:
		if player.chill_time > 0.0:
			var chilled := Loc.t("hud.chilled")
			_px.text(at, chilled, Color(0.5, 0.85, 1))
			at.x += PixelDraw.text_width(chilled) + 16.0
		if player.stunned():
			_px.text(at, Loc.t("hud.stunned"), Style.STUN_COLOR)

## What a weapon is called on the kit's line: its name, and in a kit of more
## than one the number of its slot before it — the key that draws it.
static func kit_label(weapon_id: String, slot: int, carried: int) -> String:
	var named := Weapons.name_for(weapon_id).to_upper()
	return named if carried < 2 else "%d %s" % [slot + 1, named]

## The four slots, left to right, starting at `at` (`Player.SLOTS`): the
## weapons carried, EMPTY in each slot no weapon is in — the second and third
## while fewer are carried, and the empty hand's always — the one in hand in its
## own colour and the rest dimmed. A player with no kit at all is
## the name of the weapon they hold, as the line always was. A rock out of hand
## says so, dimmed as well: it is in a slot and in no hand. A stack says how
## many are left in it, dimmed with none. Returns where the line goes on from.
func _draw_kit(at: Vector2) -> float:
	if player.weapons.is_empty():
		var named := kit_label(player.weapon_id, 0, 1)
		_px.text(at, named, Style.weapon_color(player.weapon_id))
		return at.x + PixelDraw.text_width(named) + 16.0
	var kit: Array = player.weapons
	for slot in Player.SLOTS:
		var id := String(kit[slot]) if slot < kit.size() else ""
		var label := kit_label(id, slot, Player.SLOTS) if id != "" \
			else "%d %s" % [slot + 1, Loc.t("hud.empty_hand")]
		var ink := Style.weapon_color(id)
		if slot != player.hand:
			ink.a *= AWAY
		if Weapons.is_thrown(id) and not player.holds(id):
			label = Loc.t("hud.thrown", [label])
			ink.a *= AWAY
		if Weapons.is_stacked(id):
			label = Loc.t("hud.stock", [label, player.stock_of(id)])
			if player.stock_of(id) <= 0:
				ink.a *= AWAY
		# The rune says how much mana is left in it, and when there is none, that
		# it is spent: dimmed, as a weapon that casts nothing is.
		if Weapons.is_rune(id):
			if GameState.rune.spent:
				var filled := clampf(GameState.rune.mana / maxf(player.rune_full(), 1.0), 0.0, 1.0)
				label = Loc.t("hud.rune_spent", [label, int(filled * 100.0)])
				ink.a *= AWAY
			else:
				label = Loc.t("hud.rune", [label])
		_px.text(at, label, ink)
		at.x += PixelDraw.text_width(label) + 16.0
	return at.x

## Slimmer and quieter than health: this is a budget, not a life. It is divided
## into one segment per dash, so the question it answers at a glance is "how
## many more dashes", not "what percentage".
func _draw_stamina() -> void:
	var bar := Rect2(BAR_AT + Vector2(0, HEALTH_H + 4.0), Vector2(BAR_W, THIN_H))
	var col := Color(0.45, 0.82, 0.62)
	if player.stamina < Player.DASH_STAMINA:
		col = Color(0.85, 0.55, 0.3)   # not enough left for another dash
	_px.rect(bar, BAR_GROUND)
	_px.rect(Rect2(bar.position, Vector2(bar.size.x * player.stamina_ratio(), bar.size.y)), col)
	# The notches are cut out of the fill a whole PIXEL wide, inside the edge
	# that is drawn over them: a hairline between two segments is the one thing
	# a grid this size cannot draw.
	var segments := int(round(player.max_stamina / Player.DASH_STAMINA))
	for i in range(1, segments):
		var sx := bar.position.x + bar.size.x * float(i) / float(segments)
		_px.rect(Rect2(sx - PixelDraw.PX, bar.position.y, PixelDraw.PX, bar.size.y), BAR_GROUND)
	_px.frame(bar, BAR_EDGE)

## Mana is what charging spends, so this draining is the price of a hold. What
## the price bought rides over the player's head instead — see `PlayerView`,
## which puts it where the eye is during the fight the hold is happening in.
func _draw_mana() -> void:
	var bar := Rect2(BAR_AT + Vector2(0, HEALTH_H + THIN_H + 8.0), Vector2(BAR_W, THIN_H))
	_px.bar(bar, player.mana_ratio(), Color(0.38, 0.55, 0.95), BAR_GROUND, BAR_EDGE)

func _draw_prompts(vp: Vector2) -> void:
	var band := 600.0
	var line := Loc.t("hud.extract.hold", [Controls.short_label_for("interact")]) \
		if extract_offered else prompt
	if line != "":
		_px.text_centered(Vector2((vp.x - band) * 0.5, vp.y - PROMPT_LIFT),
			line, Color(0.85, 0.95, 1.0), band)
	if extract_ratio > 0.0:
		var w := 304.0
		var r := Rect2(vp.x * 0.5 - w * 0.5, vp.y * 0.5 + 120.0, w, 16.0)
		_px.bar(r, extract_ratio, Color(0.5, 1.0, 0.8), Color(0, 0, 0, 0.6), BAR_EDGE)
		_px.text_centered(r.position + Vector2(0, -10.0), Loc.t("hud.extracting"),
			Color(0.7, 1.0, 0.9), w)
