extends Node

## The phone: the player's own, carried wherever they are played — a raid, the
## hideout — and brought up on its key (`open_phone`, P). What it looks like
## and what is on its screen is the picture's (`PhoneScreen`); this is what it
## is as a rule. An alarm, set for so many minutes and counted down on the
## clock of the world it is in (`tick`), that rings when it runs out — loud
## enough that every monster near it that goes anywhere comes to see
## (`Enemy.lure_to`), wherever it is: in the player's hand, or put down on the
## floor of a room (`PhoneProp`) and walked away from, which is the point of
## putting it down. And the photos it takes, kept as files beside the save
## (`save_photo`), for its gallery.
##
## Where it was put down is the run's: a phone left on a raid's floor is still
## there when its room is walked back into, goes with a parked raid
## (`Raid.park`), and is back in the hand when the raid is over or the hideout
## left (`recover`) — it is the player's, and they do not go without it.

## Something about it changed: the alarm, the ringing, where it is, the photos.
signal changed()
## The alarm went off.
signal rang()
## Put down on a floor, and picked back up.
signal put_down()
signal picked_up()

## How long a ring lasts, how far it is heard, and how often while it rings the
## monsters in earshot are called to it.
const RING_TIME := 12.0
const HEARING := 640.0
const CALL_EVERY := 0.5
## The least and the most an alarm is set for, in seconds.
const ALARM_MIN := 5.0
const ALARM_MAX := 30.0 * 60.0

## Where the photos go, beside the save. A test points it at a folder of its own.
static var photo_dir := "user://photos"

## Seconds until the alarm rings, or -1 with none set.
var alarm: float = -1.0
## Seconds of ringing left; 0 while it is quiet.
var ringing: float = 0.0
## Where it lies, put down: {} in the hand, else `world` ("raid" or
## "hideout"), `coord` [x, y], the raid room's, and `pos` [x, y] in it.
var placed: Dictionary = {}

var _call := 0.0

func carried() -> bool:
	return placed.is_empty()

## Whether an alarm is set and still counting.
func alarm_set() -> bool:
	return alarm >= 0.0

func set_alarm(seconds: float) -> void:
	alarm = clampf(seconds, ALARM_MIN, ALARM_MAX)
	ringing = 0.0
	Cues.emit_cue(&"phone", {"kind": "set"})
	changed.emit()

## The alarm off — set and waiting, or ringing: either way it is spent.
func clear_alarm() -> void:
	var was := alarm >= 0.0 or ringing > 0.0
	alarm = -1.0
	ringing = 0.0
	if was:
		Cues.emit_cue(&"phone", {"kind": "stop"})
	changed.emit()

## The clock, run by the world the phone is in on its own time: a raid's,
## which runs on under every screen, or the hideout's. `here` is where the
## phone is in that world — the player, carried, or the prop, lying in the
## room being stood in — or null for one lying somewhere out of sight, which
## rings unheard.
func tick(delta: float, here: Variant) -> void:
	var just_rang := false
	if alarm >= 0.0:
		alarm -= delta
		if alarm <= 0.0:
			alarm = -1.0
			ringing = RING_TIME
			_call = 0.0
			just_rang = true
			Cues.emit_cue(&"phone", {"kind": "ring"})
			rang.emit()
			changed.emit()
	if ringing > 0.0:
		# The ring is whole, however late the tick that set it off ran — and
		# the first call goes out on that tick.
		if not just_rang:
			ringing = maxf(ringing - delta, 0.0)
		_call -= delta
		if _call <= 0.0:
			_call = CALL_EVERY
			if here is Vector2:
				call_monsters(here as Vector2)
		if ringing == 0.0:
			Cues.emit_cue(&"phone", {"kind": "stop"})
			changed.emit()

## One ring, at `at`: every monster in earshot is called to it, for a little
## longer than the next ring is away — so one keeps coming while the phone
## keeps ringing, and stops where it is when the phone does.
func call_monsters(at: Vector2) -> void:
	Cues.at(&"phone_ring", at)
	var tree := get_tree()
	if tree == null:
		return
	for e in tree.get_nodes_in_group("enemies"):
		if e is Enemy and (e as Enemy).global_position.distance_to(at) <= HEARING:
			(e as Enemy).lure_to(at, CALL_EVERY + 0.25)

## Put down at `pos` on the floor of `world`'s room `coord` — the hideout's
## is (0, 0) — to be walked away from. `pos` is the room's own; `heard_at` is
## where in the world it is heard put down, when the room is not at the origin.
func put_down_at(world: String, coord: Vector2i, pos: Vector2, heard_at: Variant = null) -> void:
	placed = {"world": world, "coord": [coord.x, coord.y], "pos": [pos.x, pos.y]}
	Cues.at(&"phone", heard_at if heard_at is Vector2 else pos, {"kind": "down"})
	put_down.emit()
	changed.emit()

func pick_up() -> void:
	if placed.is_empty():
		return
	placed = {}
	Cues.emit_cue(&"phone", {"kind": "up"})
	picked_up.emit()
	changed.emit()

## Whether it lies in `world`'s room `coord`.
func lies_in(world: String, coord: Vector2i) -> bool:
	if placed.is_empty() or String(placed.get("world", "")) != world:
		return false
	var c: Array = placed.get("coord", [])
	return c.size() == 2 and Vector2i(int(c[0]), int(c[1])) == coord

## Where it lies in its room, for one put down.
func placed_pos() -> Vector2:
	var p: Array = placed.get("pos", [])
	return Vector2(float(p[0]), float(p[1])) if p.size() == 2 else Vector2.ZERO

## Back in the hand: the raid is over, or the hideout left, with it lying on
## the floor — picked up on the way out. The alarm goes on counting.
func recover() -> void:
	if placed.is_empty():
		return
	placed = {}
	picked_up.emit()
	changed.emit()

## As a new profile has it: nothing set, nothing ringing, in the hand.
func reset() -> void:
	alarm = -1.0
	ringing = 0.0
	placed = {}
	changed.emit()

## What a parked raid keeps of it, and what it is put back to.
func to_save() -> Dictionary:
	return {"alarm": alarm, "placed": placed.duplicate(true)}

func restore(saved: Dictionary) -> void:
	alarm = float(saved.get("alarm", -1.0))
	ringing = 0.0
	placed = (saved.get("placed", {}) as Dictionary).duplicate(true)
	changed.emit()

## --- photos ------------------------------------------------------------------

## Keeps `image` as a photo, and says where it went — "" for one that could
## not be kept.
func save_photo(image: Image) -> String:
	if image == null or image.is_empty():
		return ""
	DirAccess.make_dir_recursive_absolute(photo_dir)
	var stamp := Time.get_datetime_string_from_system(false, false)
	stamp = stamp.replace("-", "").replace(":", "").replace("T", "_")
	var path := ""
	for n in 100:
		path = photo_dir.path_join("photo_%s_%02d.png" % [stamp, n])
		if not FileAccess.file_exists(path):
			break
	if image.save_png(path) != OK:
		return ""
	Cues.emit_cue(&"phone", {"kind": "shutter"})
	changed.emit()
	return path

## Every photo there is, the newest first.
func photos() -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(photo_dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".png"):
			out.append(photo_dir.path_join(f))
	out.sort()
	out.reverse()
	return out

func delete_photo(path: String) -> void:
	if path.begins_with(photo_dir) and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		changed.emit()
