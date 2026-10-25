class_name SandboxPanel
extends BenchDrawer

## The bench's own tools, in a drawer on the left edge of the screen: a weapon to
## swap to, the dragon test, the Jean Grey test and the lighting test, a monster
## of every kind, a dummy, and the ways to clear the floor and to leave. What it
## is to be a drawer — the tab, the slide, holding the player still while it is
## out — is `BenchDrawer`'s; the sample skills are the drawer on the right.
##
## Everything else on the screen is the raid's own `Hud` over the same player —
## the bars, the slots, the armed skill's name — so a skill tried here reads the
## way it will when it is carried. The one readout that is the bench's is what
## the last three seconds of damage came to, under the HUD's corner.
##
## In mobile mode its buttons are a little under the kit's own THUMB, and three
## to a row rather than two, because there are fifteen of them and the drawer
## hangs under the HUD's corner: so they end above the bottom of a phone — five
## rows from TOP, where two to a row would make eight and leave the last off it.

## The damage readout's baseline, under the HUD's corner: clear of the armed
## skill's name, and of the line under it when the weapon refuses that skill.
const DPS_AT := Vector2(24, 246)
## The drawer's top edge.
const TOP := 264.0

func _top() -> float:
	return TOP

func _columns() -> int:
	return 3 if UiKit.mobile() else 2

func _drawer_name() -> String:
	return "tools"

func _fill() -> void:
	_add(Loc.t("hud.sandbox.swap_weapon"), UiKit.ACCENT, func() -> void: sandbox.cycle_weapon())
	_add(Loc.t("hud.sandbox.dragon_test"), UiKit.ACCENT, func() -> void: sandbox.open_dragon_test())
	_add(Loc.t("hud.sandbox.jean_grey_test"), UiKit.ACCENT, func() -> void: sandbox.open_jean_grey_test())
	_add(Loc.t("hud.sandbox.lighting_test"), UiKit.ACCENT, func() -> void: sandbox.open_lighting_test())
	for kind in Sandbox.MONSTER_BUTTONS:
		_add(Loc.t("hud.sandbox.spawn", [Monsters.name_for(kind)]), UiKit.WARN,
			func() -> void: sandbox.spawn_monster(kind))
	_add(Loc.t("hud.sandbox.spawn_dummy"), UiKit.GOOD, func() -> void: sandbox.spawn_dummy())
	_add(Loc.t("hud.sandbox.clear"), UiKit.BAD, func() -> void: sandbox.clear_monsters())
	_add(Loc.t("hud.sandbox.leave"), UiKit.ACCENT, func() -> void: sandbox.leave())

func _draw_more() -> void:
	_px.text(DPS_AT, Loc.t("hud.sandbox.dps", [sandbox.dps()]), UiKit.GOOD)
