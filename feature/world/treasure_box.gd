class_name TreasureBox
extends Node2D

## The loot a room was found with, kept in one box instead of lying about the
## floor. Walk up to it and press interact: everything in it goes into the bag
## at once, and the box stays where it stood, open and empty, for the rest of
## the raid.
##
## It is the same gesture as a `Station` in the hideout and an exit in a raid —
## stand close enough, press the key. What is in it is `contents`, which is the
## room's own `loot` record, shared rather than copied: opening the box is what
## takes things off that record, so a room walked out of and back into has the
## box as it was left. `graphics/views/treasure_box_view.gd` draws it.

## Pressed open while the player was in reach. `items` are the records that
## came out of it, `{"id": ...}` or `{"scrap": ...}`, the way `Room` rolls them.
signal opened(box: TreasureBox, items: Array)

## How close the player has to stand, centre to centre. A box is furniture, so
## walking up to it should not mean standing inside it.
const RANGE := 56.0

var contents: Array = []
var is_open: bool = false
var player: Player = null
## Whether the player is close enough right now, recomputed every frame so the
## view can show the prompt without asking twice.
var near: bool = false

func setup(loot: Array, at: Vector2, already_open: bool) -> void:
	contents = loot
	position = at
	is_open = already_open

func _ready() -> void:
	add_to_group("treasure_boxes")

func _process(_delta: float) -> void:
	near = player != null and is_instance_valid(player) \
		and global_position.distance_to(player.global_position) <= RANGE
	if offered() and Input.is_action_just_pressed("interact") \
			and not player.input_locked and not player.controls_locked():
		open()

## Whether a press of interact would open it: shut, and the player in reach —
## with their hands in their own body, not in a monster somewhere else.
func offered() -> bool:
	return near and not is_open and player.vessel() == player

## Opens it, if it is shut and the player is in reach. The range is checked
## here rather than by whoever calls, so a box opened by any other route
## answers on the same terms.
func open() -> void:
	if not offered():
		return
	is_open = true
	var items := takeable(contents)
	for l in items:
		contents.erase(l)
	opened.emit(self, items)
	Cues.at(&"box_open", global_position, {"count": items.size()})

## What in a loot record can still be taken out. A raid parked while a part was
## still in the game can have it in here; it stays on the record and never
## comes out.
static func takeable(loot: Array) -> Array:
	return loot.filter(func(l: Dictionary) -> bool:
		return l.has("scrap") or not Components.is_retired(String(l.get("id", ""))))
