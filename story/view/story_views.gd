class_name StoryViews
extends RefCounted

## Which view each story node is given.
##
## The table lives here rather than in `graphics/views.gd` so that putting a new
## kind of character or staging node on screen is an edit inside `story/` alone.
## `Views` still does the attaching — one watcher for the whole tree, as it has
## always been — and asks here once its own table has missed.
##
## Same contract as that table: most specific first, and a node with no entry
## simply gets no view.

static func view_script_for(n: Node) -> GDScript:
	if n is Npc:
		return NpcView
	if n is CutsceneActor:
		return CutsceneActorView
	if n is Cutscene:
		return CutsceneView
	if n is StoryMaker:
		return StoryMakerView
	return null
