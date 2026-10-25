class_name SampleSkillsPanel
extends BenchDrawer

## The bench's sample skills, in a drawer on the right edge of the screen
## (`Sandbox.samples`) — the dragon test's graph, the Jean Grey test's, and the
## seeker arrow — each under the weapon it was built for and a line on what it
## does. Picking one puts it on that weapon at the bench, over the
## bench's copy and never the profile's, puts that weapon in hand, and pushes
## the drawer back in so it can be tried at once. It is a `BenchDrawer`, like
## the tools on the left, and either can be out without the other.
##
## Its tab hangs high on the right, under the top of the screen: on a phone the
## console's DASH and cast stick are lower down that edge, and a tab over one of
## them would be pulled every time the thumb went for it.

## The drawer's top edge.
const TOP := 136.0

func _top() -> float:
	return TOP

func _on_right() -> bool:
	return true

func _drawer_name() -> String:
	return "samples"

func _fill() -> void:
	_grid.add_child(UiKit.label(Loc.t("hud.sandbox.samples"), UiKit.PIXEL_TEXT, UiKit.TEXT, true))
	for s in Sandbox.samples():
		var id := String(s["id"])
		var board: SkillBoard = (s["board"] as Callable).call()
		_add(board.skill_name.to_upper(), UiKit.ACCENT, func() -> void:
			if sandbox.load_sample(id):
				set_out(false))
		var what := "%s  %s" % [Weapons.name_for(String(s["weapon"])).to_upper(), _says(id)]
		_grid.add_child(UiKit.label(what, UiKit.PIXEL_TEXT, UiKit.DIM, true))

## What a sample does, in a line.
static func _says(id: String) -> String:
	match id:
		"dragon":
			return Loc.t("hud.sandbox.sample.dragon")
		"jean_grey":
			return Loc.t("hud.sandbox.sample.jean_grey")
		"seeker":
			return Loc.t("hud.sandbox.sample.seeker")
	return ""
