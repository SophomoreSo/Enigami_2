class_name Stories
extends RefCounted

## The stories written in the story maker (`StoryMaker`), as files: each a
## JSON file named for the story — `data/stories/first_meeting.json` is the
## story `first_meeting`. What is in one is `StoryMaker`'s to say, and the
## format is written out beside them in `data/stories/README.md`.
##
## Kept where the maps are kept (`Maps`), for the same reason. Run from the
## project — the editor, or `godot --path` — a story is saved into the project
## itself, beside the rest of the content, where it is committed and shipped
## with the game. An exported game cannot write into itself, so there a story
## goes to `user://stories`, and the ones the game shipped with are read from
## where they always were.

## The project's own stories, and the ones written on a machine the game was
## only installed on.
const PROJECT_DIR := "res://data/stories"
const USER_DIR := "user://stories"
const EXTENSION := "json"

## Somewhere else to keep them, in place of both: a test's scratch folder.
static var scratch_dir: String = ""

## Whether this run may write into the project's own folder.
static func in_project() -> bool:
	return OS.has_feature("editor")

## The folder a story is saved into.
static func save_dir() -> String:
	if scratch_dir != "":
		return scratch_dir
	return PROJECT_DIR if in_project() else USER_DIR

## The folders stories are looked for in, the one searched first leading: a
## story written on this machine stands in front of one the game shipped under
## its name.
static func dirs() -> PackedStringArray:
	if scratch_dir != "":
		return PackedStringArray([scratch_dir])
	if in_project():
		return PackedStringArray([PROJECT_DIR])
	return PackedStringArray([USER_DIR, PROJECT_DIR])

## The name a story is filed under, from one as it was typed: the way a map's
## is (`Maps.id_for`), so a story and the map it is set on are named alike.
static func id_for(typed: String) -> String:
	return Maps.id_for(typed)

## Every story there is, by id, in order.
static func ids() -> PackedStringArray:
	var found := {}
	for dir in dirs():
		if not DirAccess.dir_exists_absolute(dir):
			continue
		for file in DirAccess.get_files_at(dir):
			if file.get_extension() == EXTENSION:
				found[file.get_basename()] = true
	var out := PackedStringArray(found.keys())
	out.sort()
	return out

## Where the story `id` is, or "" when there is none by that name.
static func path_of(id: String) -> String:
	if id == "":
		return ""
	for dir in dirs():
		var path := dir.path_join("%s.%s" % [id, EXTENSION])
		if FileAccess.file_exists(path):
			return path
	return ""

static func exists(id: String) -> bool:
	return path_of(id) != ""

## Keeps `story` as the story `id`, as a file in the folder stories are saved
## into, over whatever was kept under that name. Plain JSON, a tab to a level,
## so a story reads in a diff and can be mended by hand.
static func save(id: String, story: Dictionary) -> Error:
	if id == "" or id != id_for(id):
		return ERR_INVALID_PARAMETER
	var err := DirAccess.make_dir_recursive_absolute(save_dir())
	if err != OK:
		return err
	var f := FileAccess.open(save_dir().path_join("%s.%s" % [id, EXTENSION]), FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(story, "\t") + "\n")
	f.close()
	return OK

## The story `id` as its file has it, or nothing when there is no such story
## or the file is not one. Read off the file each time: a story saved over
## while the game runs is the story that comes back.
static func load_story(id: String) -> Dictionary:
	var path := path_of(id)
	if path == "":
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

## Throws the story `id` away, where this run may: out of the folder it saves
## into. A story the game shipped with is not an exported game's to remove.
static func remove(id: String) -> Error:
	var path := save_dir().path_join("%s.%s" % [id, EXTENSION])
	if id == "" or not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	return DirAccess.remove_absolute(path)
