class_name PerkPage
extends VBoxContainer

## The perks, a row each, as the hideout's perk station shows them (`Perks`):
## what a perk is and how many of its steps are bought, what it does, and the
## price of the next step on the button that buys it — or, once there are none
## left, that all of them are. Built in the pixel look of the counter's rows,
## and at a thumb's size in mobile mode as every station's panel is
## (`UiKit.text`).
##
## On the bench (`Perks.trial`) nothing is bought: each row's button says ON or
## OFF, and a press flips every step of the perk at once, for nothing.
##
## It only buys, or toggles. The gold in the corner and everything else round it
## is the frame's, which a station's panel stands in (`HideoutWorldView`): a step
## bought says so (`bought`), as does a perk toggled (`toggled`), and the frame
## is built again round a new page.

signal bought(id: String)
signal toggled(id: String)

func _ready() -> void:
	add_theme_constant_override("separation", 10)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id in Perks.ids():
		add_child(_row(String(id)))

## One perk: its name and steps, the button that buys the next one, and what it
## does under them, wrapping inside the panel rather than widening it.
func _row(id: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	var title := UiKit.label(Loc.t("perks.page.row", [Perks.name_for(id), Perks.active(id), Perks.steps(id)]),
		UiKit.text(UiKit.PIXEL_TEXT), UiKit.TEXT, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var cost := Perks.next_cost(id)
	if Perks.trial:
		var on := Perks.is_on(id)
		var t := UiKit.button(Loc.t("perks.page.on" if on else "perks.page.off"),
			UiKit.GOOD if on else UiKit.DIM, true)
		t.pressed.connect(func() -> void:
			if Perks.toggle(id):
				Audio.play("ui")
				toggled.emit(id))
		head.add_child(t)
	elif cost < 0:
		head.add_child(UiKit.label(Loc.t("perks.page.all"), UiKit.text(UiKit.PIXEL_TEXT), UiKit.DIM, true))
	else:
		var b := UiKit.button("%d" % cost, UiKit.WARN, true)
		b.disabled = not Perks.can_buy(id)
		b.pressed.connect(func() -> void:
			if Perks.buy(id):
				Audio.play("pickup")
				bought.emit(id))
		head.add_child(b)
	v.add_child(head)
	var says := UiKit.label(Perks.desc_for(id), UiKit.text(UiKit.PIXEL_TEXT), UiKit.DIM, true)
	says.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(says)
	return v
