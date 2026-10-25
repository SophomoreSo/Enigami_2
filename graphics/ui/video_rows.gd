class_name VideoRows

## The settings that are about the machine rather than the game: whether the
## window takes the whole display, whether an impact is allowed to move the
## camera, and whether the assembly screen moves its hints — the part under
## the pointer, and the way out. All three are `Video`'s.
##
## Two screens carry settings — the title's and the pause menu's — and they are
## built by different files. A setting written out in both would become two
## settings the day one of them was changed and the other was not, so the rows
## are made here and both screens ask for them.

## One `UiKit.ChoiceRow` per setting, each showing the answer in force and
## wired to set it. Rebuilt with the menu that holds them, which is what puts
## them into a language switched from inside it.
##
## A phone or a tablet has no window to take the display with — the game is the
## display there — so the screen row is left off on those, rather than offering
## a choice that changes nothing.
static func rows() -> Array:
	var out: Array = []
	if not OS.has_feature("mobile"):
		out.append(UiKit.choice_row(Loc.t("menu.video.screen"),
			PackedStringArray([Loc.t("menu.video.windowed"), Loc.t("menu.video.fullscreen")]),
			1 if Video.fullscreen else 0,
			func(i: int) -> void: Video.set_fullscreen(i == 1)))
	out.append(UiKit.choice_row(Loc.t("menu.video.shake"),
		PackedStringArray([Loc.t("menu.video.off"), Loc.t("menu.video.on")]),
		1 if Video.screen_shake else 0,
		func(i: int) -> void: Video.set_screen_shake(i == 1)))
	out.append(UiKit.choice_row(Loc.t("menu.video.icons"),
		PackedStringArray([Loc.t("menu.video.off"), Loc.t("menu.video.on")]),
		1 if Video.icon_motion else 0,
		func(i: int) -> void: Video.set_icon_motion(i == 1)))
	return out
