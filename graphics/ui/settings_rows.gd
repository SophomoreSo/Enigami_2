class_name SettingsRows

## The settings that are about the game rather than the machine: the two
## volumes and the language. `VideoRows` holds the machine's, and this holds
## the rest, for the same reason — the title's settings and the pause menu are
## built by different files, and a row written out in both is two settings the
## day one of them is changed and the other is not.

## The music and sound sliders and the row of languages, each showing the answer
## in force and wired to set it. Rebuilt with the menu that holds them, which is
## what puts them into a language switched from inside it.
static func rows() -> Array:
	return [
		slider(Loc.t("menu.settings.music"), Audio.music_volume,
			func(val: float) -> void: Audio.set_music_volume(val)),
		# A click at the new volume, so what the slider set can be heard.
		slider(Loc.t("menu.settings.sound"), Audio.sfx_volume, func(val: float) -> void:
			Audio.set_sfx_volume(val)
			Audio.play("ui")),
		language_row(),
	]

## A label and a slider from 0 to 1, in the pixel look — and at a thumb's size
## in mobile mode, where the slider takes the rest of the row (`UiKit.pixel_slider`).
static func slider(name: String, value: float, cb: Callable) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.add_child(UiKit.setting_label(name))
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(240, 20)
	UiKit.pixel_slider(s)
	s.value_changed.connect(cb)
	h.add_child(s)
	return h

## One button per language, laid out like a slider row: the label on the left
## and the choices beside it. Each language is written in itself, so somebody
## who has landed in the wrong one can still find their way back. Switching is
## a rebuild of everything holding words, this row among them, so the button
## pressed is freed by its own press.
static func language_row() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.add_child(UiKit.setting_label(Loc.t("menu.settings.language")))
	for lang in Loc.languages():
		var picked: bool = lang == Loc.language
		var b := UiKit.button(Loc.language_name(lang),
			UiKit.ACCENT if picked else UiKit.DIM, true)
		# As a `ChoiceRow`'s answers do: in mobile mode they share the row.
		if UiKit.mobile():
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if picked:
			UiKit.mark_chosen(b)
		b.pressed.connect(func() -> void:
			Audio.play("ui")
			Loc.set_language(lang))
		h.add_child(b)
	return h
