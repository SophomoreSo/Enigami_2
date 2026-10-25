extends Node
## The part under the pointer moves on the assembly screen, through a film of
## its own (`Style.COMPONENT_MOTION`), the rest stand still, the way out bobs
## out of the board and back, and a setting stops both (`Video.icon_motion`).
##
## Every part has a film, cut into frames seven pixels square, the first being
## its icon at rest — so a board whose parts are kept still shows the icons it
## always did — and no frame the same as the one before it, or the part would
## sit still for a beat it was not given. The film goes round: every frame comes
## up in the order the strip draws them, held as long as it says, and then the
## first again. The screen moves the one part under the pointer — the part in
## hand, the board's part, or the parts' row — from the moment the pointer
## comes onto it, starting on its icon at rest, and keeps every other part on
## its icon at rest; with the setting off, that one too. The way out goes out
## and back by whole PIXELs, never closer than a PIXEL to the parts, and stands
## still with the setting off. And the setting is kept where the screen mode
## and the camera shake are, and is on where nobody has set it.
##
## No renderer needed: the films are pictures in a table, and which one the
## screen draws is a question it answers.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[MOTION] PASS ", what)
	else:
		fails += 1
		push_error("MOTION FAIL: " + what)

func _ready() -> void:
	_films()
	_round()
	_pointer()
	_screen()
	_way_out()
	_kept()
	print("[MOTION] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## Every part has a film, and every film is pictures of the icon's own size.
func _films() -> void:
	var missing: Array = []
	var not_at_rest: Array = []
	var misshapen: Array = []
	var stuck: Array = []
	for id in Components.ids():
		if not Style.COMPONENT_MOTION.has(id):
			missing.append(id)
			continue
		var motion: Dictionary = Style.COMPONENT_MOTION[id]
		var frames := Style.component_frames(id)
		if frames.is_empty() or frames[0] != Style.component_icon(id):
			not_at_rest.append(id)
		for row in motion["strip"]:
			if (String(row).length() + 1) % 8 != 0 or String(row).length() != String(motion["strip"][0]).length():
				misshapen.append("%s's strip" % id)
				break
		var hold: Array = motion.get("hold", [])
		if not hold.is_empty() and hold.size() != frames.size():
			misshapen.append("%s's holds" % id)
		if frames.size() < 2:
			stuck.append("%s, which has one frame" % id)
		for i in frames.size():
			var rows: Array = frames[i]
			var ok := rows.size() == 7
			for r in rows:
				ok = ok and String(r).length() == 7 and String(r).replace("#", "").replace(".", "") == ""
			if not ok:
				misshapen.append("%s frame %d" % [id, i])
			if i > 0 and rows == frames[i - 1]:
				stuck.append("%s frame %d" % [id, i])
	check(missing.is_empty(), "every part has a film (%s)" % ", ".join(missing))
	check(not_at_rest.is_empty(), "and each starts on its icon at rest (%s)" % ", ".join(not_at_rest))
	check(misshapen.is_empty(), "every frame is seven pixels square, of # and . (%s)" % ", ".join(misshapen))
	check(stuck.is_empty(), "and none is the frame before it again (%s)" % ", ".join(stuck))
	var strays: Array = []
	for id in Style.COMPONENT_MOTION:
		if not Components.exists(String(id)):
			strays.append(id)
	check(strays.is_empty(), "no film is for a part the game does not have (%s)" % ", ".join(strays))

## A film goes round: tick by tick, each frame for as long as it is held, in
## the order its strip draws them, and back to the first.
func _round() -> void:
	var wrong: Array = []
	for id in Style.COMPONENT_MOTION:
		var motion: Dictionary = Style.COMPONENT_MOTION[id]
		var frames := Style.component_frames(String(id))
		var hold: Array = motion.get("hold", [])
		var want: Array = []
		for i in frames.size():
			for k in (int(hold[i]) if i < hold.size() else 1):
				want.append(frames[i])
		var fps := float(motion["fps"])
		for tick in want.size() + 1:
			if Style.component_icon_at(String(id), (float(tick) + 0.5) / fps) != want[tick % want.size()]:
				wrong.append("%s at tick %d" % [id, tick])
				break
	check(wrong.is_empty(), "every film goes round, each frame held as long as it says (%s)" % ", ".join(wrong))
	check(Style.component_icon_at("NO_SUCH_PART", 3.0) == Style.component_icon("NO_SUCH_PART"),
		"a part with no film stands on its icon")

## Which part is under the pointer: the one in hand, wherever it is carried;
## else the board's part under it, filed under its origin; else the parts'
## row; else none.
func _pointer() -> void:
	var ed := SkillEditor.new()
	var b := SkillBoard.new(7, 5, "pointed at")
	b.place("FIRE", Vector2i(2, 1), 0)
	ed.board = b
	check(ed._under_pointer().is_empty(), "with the pointer on nothing, no part is under it")
	ed._hover_pal = 3
	check(ed._under_pointer() == ["parts", 3], "on a row of the parts, that row")
	ed._hover_pal = -1
	ed._hover_cell = Vector2i(2, 1)
	ed._under = ed._under_pointer()
	check(ed._under == ["board", Vector2i(2, 1), "FIRE"] and ed._pointed_at(Vector2i(2, 1))
			and not ed._pointed_at(Vector2i(0, 0)),
		"on a part on the board, that part and no other (%s)" % str(ed._under))
	ed._hover_cell = Vector2i(5, 3)
	check(ed._under_pointer().is_empty(), "on an empty cell, none")
	ed._drag_id = "ICE"
	check(ed._under_pointer() == ["hand", "ICE"], "with a part in hand, the part in hand, wherever the pointer is")
	ed.free()

## The screen draws the part under the pointer moving, from the moment the
## pointer came onto it, and every other part still — and nothing moving with
## the setting off. Sampled every twentieth of a second, quicker than the
## quickest film's tick, for two seconds, longer than any film rests on its
## first frame; the pointer comes on a little way into the screen's clock, so
## the film is seen to start there rather than at the clock's start.
func _screen() -> void:
	var was := Video.icon_motion
	var ed := SkillEditor.new()
	Video.icon_motion = true
	var came_on := 1.3
	ed._under_since = came_on
	var starts := true
	var follows := true
	var others_still := true
	var moved: Array = []
	for id in Components.ids():
		var off_rest := false
		for tick in 41:
			ed._flow_time = came_on + float(tick) * 0.05
			var drawn: Array = ed._icon(id, true)
			if tick == 0:
				starts = starts and drawn == Style.component_icon(id)
			follows = follows and drawn == Style.component_icon_at(id, ed._flow_time - came_on)
			off_rest = off_rest or drawn != Style.component_icon(id)
			others_still = others_still and ed._icon(id, false) == Style.component_icon(id)
		if off_rest:
			moved.append(id)
	check(starts, "the part under the pointer is its icon at rest the moment the pointer comes onto it")
	check(follows, "and from then on where its film has got to")
	check(moved.size() == Components.ids().size(),
		"every part moves some time in its first two seconds under the pointer (%d of %d)"
			% [moved.size(), Components.ids().size()])
	check(others_still, "and every part not under the pointer is its icon at rest, whatever the clock says")
	Video.icon_motion = false
	var still := true
	for id in Components.ids():
		for tick in 40:
			ed._flow_time = came_on + float(tick) * 0.05
			still = still and ed._icon(id, true) == Style.component_icon(id)
	check(still, "with the setting off, the part under the pointer is its icon at rest too")
	ed.free()
	Video.icon_motion = was

## The way out bobs out of the board and back, by whole PIXELs, out to
## WAY_OUT_BOB of them where there is the room and short of the parts where
## there is not — and with the setting off, not at all. A bob is sampled
## thirty times over, so every place it stops at is seen.
func _way_out() -> void:
	var was := Video.icon_motion
	var ed := SkillEditor.new()
	var px := float(UiKit.PIXEL)
	Video.icon_motion = true
	var seen := {}
	var whole := true
	var short := true
	for tick in 60:
		ed._flow_time = float(tick) * SkillEditor.WAY_OUT_BOB_TIME / 30.0
		var bob := ed._way_out_bob(200.0)
		seen[bob] = true
		whole = whole and is_equal_approx(fposmod(bob, px), 0.0)
		short = short and ed._way_out_bob(px * 2.0) <= px
	check(whole and seen.size() == SkillEditor.WAY_OUT_BOB + 1 and seen.has(0.0)
			and seen.has(float(SkillEditor.WAY_OUT_BOB) * px),
		"the way out bobs from where it rests out to WAY_OUT_BOB PIXELs and back, a PIXEL at a time (%s)"
			% str(seen.keys()))
	check(short, "and stops a PIXEL short of the parts where they stand near")
	Video.icon_motion = false
	var still := true
	for tick in 60:
		ed._flow_time = float(tick) * SkillEditor.WAY_OUT_BOB_TIME / 30.0
		still = still and ed._way_out_bob(200.0) == 0.0
	check(still, "with the setting off, the way out stands still")
	ed.free()
	Video.icon_motion = was

## Kept in Video's file, beside the screen mode and the camera shake, and on
## for a machine that has never said.
func _kept() -> void:
	var fresh: Node = (Video.get_script() as GDScript).new()
	check(bool(fresh.get("icon_motion")), "a machine that has never set it has the parts moving")
	fresh.free()
	var was := Video.icon_motion
	Video.set_icon_motion(not was)
	Video.icon_motion = was
	Video._load()
	check(Video.icon_motion == (not was), "the setting is written to %s and read back" % Video.PATH.get_file())
	Video.set_icon_motion(was)
