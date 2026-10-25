extends Node

## Gives every gameplay node its picture.
##
## A node in `feature/` or `story/rules/` knows nothing about how it is drawn:
## it is spawned, it enters the tree, and this hands it a view of its own. That
## is the whole reason a change to how the player looks and a change to how the
## player moves never land in the same file — and why the game still runs,
## silently and invisibly, with this module absent.
##
## One watcher serves every module, but the tables are owned separately: what a
## story node is drawn with is `story/view/story_views.gd`, so the two are never
## edited together.
##
## A view is a plain child node. It reads its parent's state every frame and
## draws from it; it never writes back.

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(n: Node) -> void:
	var script := view_script_for(n)
	if script == null:
		return
	var v: Node = script.new()
	v.name = "View"
	# Seen by the pixel camera only, not by the screen under its picture.
	if v is CanvasItem:
		(v as CanvasItem).visibility_layer = PixelCamera.WORLD_LAYER
	n.add_child(v)

## The view a gameplay node was given, or null. Handy for tests and for screens
## that need to reach the overlay a view built.
func of(n: Node) -> Node:
	if n == null or not is_instance_valid(n):
		return null
	return n.get_node_or_null("View")

## Most specific first: Player and Enemy are both Actors.
func view_script_for(n: Node) -> GDScript:
	if n is Player:
		return PlayerView
	if n is Enemy:
		return EnemyView
	if n is Projectile:
		return ProjectileView
	if n is Pet:
		return PetView
	if n is MeleeArc:
		return MeleeArcView
	if n is AreaBurst:
		return AreaBurstView
	if n is DashSlash:
		return DashSlashView
	if n is LooseRock:
		return LooseRockView
	if n is StuckShuriken:
		return StuckShurikenView
	# The rest of the game's nodes get theirs as each arrives (PLAN.md).
	# Story keeps its own table, in `story/view/story_views.gd`.
	return StoryViews.view_script_for(n)
