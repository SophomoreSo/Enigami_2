class_name Components
extends RefCounted

## Every skill-board part, as the content database has it: the rows of
## `parts`, `ports`, `effects`, `codes`, `retired_parts` and `renamed_parts`
## (see `data/db/README.md`), read the first time anything asks and kept.
##
## A component occupies one (or two) grid cells and declares the ports its flow
## leaves by in LOCAL space. Rotation `r` turns a local direction `d` into world
## direction `(d + r) % 4`. Direction indices: 0=East 1=South 2=West 3=North.
##
## A part costs one tick per cell it occupies, so `cells` is its tick cost too:
## time on the board is distance on the board, and what a cycle costs can be
## counted off the grid instead of looked up part by part.
##
## Inputs are not declared. A part takes flow on any edge that is not one of its
## own outputs, so the arrows drawn on the board describe its behaviour
## completely: rotation decides where a flow goes, never where it may come from.
## Where a flow *starts* is not a part's to say either: it is the board's root,
## whichever part that is — see `SkillBoard.root`. Nor is where it becomes an
## attack: that is the middle of the board's right edge — see
## `SkillBoard.way_out`.
##
## What a part does to a flow is rows too: its effects, each a change to one
## field of the `Payload` the flow carries, which `SkillRunner._apply` makes as
## the flow enters. Every row is held to the payload as it is read, and one that
## does not fit is one of `faults()` and left out, rather than guessed at.
##
## This is the one script in the circuit that names `Db`. Behaviour only: the
## colour and glyph a part is drawn with are in `graphics/style.gd`, keyed by the
## same id, and a part added to the table draws in its category's colour until
## someone gives it a glyph of its own.

const E := 0
const S := 1
const W := 2
const N := 3

const DIR_VEC := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
## The sides as the tables write them, in the order of the indices above.
const SIDES := "ESWN"

# Categories are used for palette grouping and for weapon compatibility tags.
# What each one looks like is `Style.CAT_COLOR`, over in the graphics module.
const CAT_FORM := "form"
const CAT_STATES := "states"
const CAT_BEHAVIOR := "behavior"
const CAT_PROJECTILE_BEHAVIOR := "projectile_behavior"
const CAT_SUMMON_BEHAVIOR := "summon_behavior"
const CAT_FLOW := "flow"
const CAT_TRIGGER := "trigger"

## Fields of a payload the runner keeps for itself, which no effect may touch:
## a part's own heat is its `heat`; `stacks`, `branch`, `follow_up` and the
## triggers are how a trigger's branch is carried and chained; and `spread`,
## `touch` and `touch_at` are a NEAR's, built as the flow goes and set as a hit
## lands.
const KEPT := ["heat", "branch", "follow_up", "stacks", "on_hit", "on_kill", "on_parry",
	"spread", "touch", "touch_at"]

## id -> definition, in palette order. Fields:
##   name, cat, heat, cells (1 or 2), limit (how many of it one flow can stack,
##   0 for any number), tag ("" for none), outs (local output
##   dirs, in the order flows leave), payload_out
##   (local dir of a trigger's branch, -1 if none), effects (what entering it
##   does, see `_effect`), acts_on_entry (it does its work on the way in; see
##   below), code (its number in a shared code), desc
static var _defs: Dictionary = {}
## The categories, in the order the palette lays them out: the table's.
static var _cats: Array = []
## code -> id, a retired part's included.
static var _codes: Dictionary = {}
## Retired id -> true.
static var _retired: Dictionary = {}
## Old id -> the id the part goes by now.
static var _renamed: Dictionary = {}
static var _faults: Array = []
static var _read := false

static func get_def(id: String) -> Dictionary:
	_ensure()
	return _defs.get(id, {})

## Every part, in the order the palette shows them.
static func ids() -> Array:
	_ensure()
	return _defs.keys()

## Every category, in the order the palette lays its blocks out — whether or
## not any part is of it yet.
static func categories() -> Array:
	_ensure()
	return _cats.duplicate()

## The parts that drop, forge, sell and are spent from a stash, in the order
## the palette shows them: every part there is. Nothing is handed out for
## nothing — the one part that was, the OUTPUT, is the board's own edge now.
static func loot_pool() -> Array:
	return ids()

## What is wrong with the tables, in words: a row that does not fit what reads
## it. Empty when every part is whole. Said once, loudly, as they are read.
static func faults() -> Array:
	_ensure()
	return _faults.duplicate()

## Forgets what was read, so the next question reads the tables again —
## `data/db/build.sh` puts a new file in place while the game runs.
static func reload() -> void:
	_read = false
	_defs.clear()

## What to call a part on screen, and what to say it does, in the language
## being played. The `name` and `desc` from the table are the fallback under
## these: a part added there draws with its English name until somebody writes
## one for it, rather than drawing as its key or not at all.
static func name_for(id: String) -> String:
	return Loc.opt("parts.%s.name" % id, String(get_def(id).get("name", id)))

static func desc_for(id: String) -> String:
	return Loc.opt("parts.%s.desc" % id, String(get_def(id).get("desc", "")))

## A board's tags — `ranged`, `melee`, `trigger` — spelled for a reader. The tag
## itself stays the id the compatibility rules match on; only the label moves.
static func tag_name(tag: String) -> String:
	return Loc.opt("parts.tag.%s" % tag, tag)

## The same list, joined the way the language joins a list.
static func tag_names(tags: Array) -> String:
	var out: Array[String] = []
	for t in tags:
		out.append(tag_name(String(t)))
	return Loc.t("editor.payload.separator").join(out)

static func exists(id: String) -> bool:
	return not get_def(id).is_empty()

## Parts the game no longer has, which keep their numbers. See `retired_parts`.
static func retired_ids() -> Array:
	_ensure()
	return _retired.keys()

static func is_retired(id: String) -> bool:
	_ensure()
	return _retired.has(id)

## Old id -> the id the part goes by now. See `renamed_parts`.
static func renamed() -> Dictionary:
	_ensure()
	return _renamed.duplicate()

## The id a part goes by today. Whatever reads a part back out of a save asks
## this first, so a profile written before a rename keeps what it had.
static func current_id(id: String) -> String:
	_ensure()
	return String(_renamed.get(id, id))

## A part's number in a shared code, retired or not, or -1 for none.
static func code_of(id: String) -> int:
	_ensure()
	for n in _codes:
		if _codes[n] == id:
			return int(n)
	return -1

## The part a shared code means by `code` — perhaps a retired one — or "".
static func part_for_code(code: int) -> String:
	_ensure()
	return String(_codes.get(code, ""))

## Every number given out, number -> id.
static func codes() -> Dictionary:
	_ensure()
	return _codes.duplicate()

## What entering a part does, in order: {op, field, value}, with the value in
## the type its field holds — and `per_stack`, on a row that is worth more the
## more of the part a flow has stacked. See `SkillRunner._apply`.
static func effects_of(id: String) -> Array:
	return get_def(id).get("effects", [])

## What a part does instead when an INVERT comes straight after it, in order:
## {op, field, value}, like its effects — its rows of `inversions`. Empty for a
## part with no opposite. See `SkillRunner._invert`.
static func inversions_of(id: String) -> Array:
	return get_def(id).get("inversions", [])

## How many of a part one flow can stack: the part does its work that many
## times on a flow, and any more of it the flow passes do nothing but cost
## their heat. 0 for a part with no limit. Its `stack_limit`.
static func limit_of(id: String) -> int:
	return int(get_def(id).get("limit", 0))

## Whether a part does its work the moment a flow enters it, rather than by
## carrying that flow on out of the board — it slows the fight or opens a guard.
## `SkillRunner._apply` is where those two effects happen; the flag is worked
## out beside the part so that a board can tell a loop still doing something
## every lap from one that only swallows the flow — see `SkillBoard.dead_loops`.
static func acts_on_entry(id: String) -> bool:
	return bool(get_def(id).get("acts_on_entry", false))

## Ticks a flow spends inside a component: one for every cell it covers. Read
## from the footprint rather than stored beside it, so the two cannot drift.
static func tick_cost(id: String) -> int:
	return maxi(1, int(get_def(id).get("cells", 1)))

static func rotate_dir(local_dir: int, rot: int) -> int:
	return (local_dir + rot) % 4

## The opposite direction, used when checking whether two ports face each other.
static func opposite(dir: int) -> int:
	return (dir + 2) % 4

static func dir_to_vec(dir: int) -> Vector2i:
	return DIR_VEC[dir % 4]

## A side as the tables write it — E, S, W or N — as a direction, or -1.
static func side(letter: String) -> int:
	return SIDES.find(letter) if letter.length() == 1 else -1

## World-space edges a placed component will accept flow on: everything except
## the edges it sends flow out of. Two outputs meeting head-on is the only join
## that cannot carry a flow.
static func world_inputs(id: String, rot: int) -> Array:
	var out: Array = []
	var blocked := world_outputs(id, rot)
	var payload := world_payload_out(id, rot)
	for d in 4:
		if blocked.has(d) or d == payload:
			continue
		out.append(d)
	return out

## World-space main output directions of a placed component.
static func world_outputs(id: String, rot: int) -> Array:
	var out: Array = []
	for d in get_def(id).get("outs", []):
		out.append(rotate_dir(d, rot))
	return out

## World-space payload branch direction, or -1 when the component has none.
static func world_payload_out(id: String, rot: int) -> int:
	var p: int = get_def(id).get("payload_out", -1)
	if p < 0:
		return -1
	return rotate_dir(p, rot)

## Cells a component covers when placed at `origin` with `rot`.
## Two-cell components extend along their local +X axis.
static func footprint(id: String, origin: Vector2i, rot: int) -> Array:
	var cells: Array = [origin]
	if get_def(id).get("cells", 1) == 2:
		cells.append(origin + dir_to_vec(rotate_dir(E, rot)))
	return cells

## The cell a component emits from (the far cell for two-cell parts).
static func exit_cell(id: String, origin: Vector2i, rot: int) -> Vector2i:
	if get_def(id).get("cells", 1) == 2:
		return origin + dir_to_vec(rotate_dir(E, rot))
	return origin

const DIR_NAME := ["east", "south", "west", "north"]

static func dir_name(dir: int) -> String:
	return Loc.opt("parts.direction.%s" % DIR_NAME[dir % 4], DIR_NAME[dir % 4])

## --- reading the tables -------------------------------------------------------

static func _ensure() -> void:
	if not _read:
		_read = true
		_load()

static func _load() -> void:
	_defs.clear()
	_codes.clear()
	_retired.clear()
	_renamed.clear()
	_faults.clear()
	for c in Db.records("codes", "", [], "code"):
		_codes[int(c["code"])] = String(c["id"])
	_cats.clear()
	for c in Db.records("categories", "", [], "rowid"):
		_cats.append(String(c["id"]))
	for p in Db.records("parts", "", [], "rowid"):
		var id := String(p["id"])
		_defs[id] = {
			"name": String(p["name"]), "cat": String(p["category"]),
			"heat": float(p.get("heat", 0.0)), "cells": int(p.get("cells", 1)),
			"limit": int(p.get("stack_limit", 0)),
			"tag": String(p.get("tag", "")),
			"outs": [], "payload_out": -1, "effects": [], "inversions": [], "acts_on_entry": false,
			"code": -1, "desc": String(p["description"]),
		}
	for n in _codes:
		if _defs.has(_codes[n]):
			_defs[_codes[n]]["code"] = int(n)
	for port in Db.records("ports", "", [], "rowid"):
		var def: Dictionary = _defs.get(String(port["part_id"]), {})
		if def.is_empty():
			continue
		if String(port.get("kind", "flow")) == "branch":
			def["payload_out"] = side(String(port["side"]))
		else:
			(def["outs"] as Array).append(side(String(port["side"])))
	var shape := Payload.new()
	for row in Db.records("effects", "", [], "part_id, position"):
		var id := String(row["part_id"])
		var def: Dictionary = _defs.get(id, {})
		if def.is_empty():
			continue
		var made = _effect(row, shape)
		if made is String:
			_faults.append("%s's effect %d %s" % [id, int(row.get("position", 0)), made])
			continue
		(def["effects"] as Array).append(made)
		if made["op"] == "dilate" or made["op"] == "guard":
			def["acts_on_entry"] = true
	# A part's opposite is held to the payload the same way its effects are, and
	# changes a field like they do: the schema keeps the ops that change the
	# fight, and INVERT's own, out of the table already.
	for row in Db.records("inversions", "", [], "part_id, position"):
		var id := String(row["part_id"])
		var def: Dictionary = _defs.get(id, {})
		if def.is_empty():
			continue
		var made = _effect(row, shape)
		if made is Dictionary and made["field"] == &"":
			made = "%s, which changes no field — an opposite has to" % String(row.get("op", ""))
		if made is String:
			_faults.append("%s's opposite %d %s" % [id, int(row.get("position", 0)), made])
			continue
		(def["inversions"] as Array).append(made)
	for r in Db.records("retired_parts"):
		_retired[String(r["id"])] = true
	for r in Db.records("renamed_parts"):
		_renamed[String(r["old_id"])] = String(r["new_id"])
	if _defs.is_empty():
		_faults.append("no parts in %s" % Db.PATH)
	for fault in _faults:
		push_error("Components: %s" % fault)

## One row of `effects` as `SkillRunner._apply` makes it — {op, field, value},
## the field a StringName and the value in the type the field holds — or, when
## the row does not fit a payload like `shape`, why not, in words.
##
## A payload's own fields are the vocabulary: what one holds decides what can
## be done to it. A number is set, added to or multiplied; a whole number the
## same, by whole numbers, since a fraction would be cut off without a word; a
## flag set or toggled; a word set; a list included in.
static func _effect(row: Dictionary, shape: Payload) -> Variant:
	var op := String(row.get("op", ""))
	var value = row.get("value", null)
	if op == "invert":
		# INVERT's: what it changes is whatever the part before it changed, so
		# it names no field of its own, and has no amount to change one by.
		var named = row.get("field", null)
		var has_field: bool = named != null and str(named) != ""
		if has_field or value != null:
			return "invert with %s, which it takes nothing of — it turns round the part before it" \
				% ("a field" if has_field else "a value")
		return {"op": op, "field": &"", "value": null}
	if op == "dilate" or op == "guard":
		if not (value is float or value is int) or float(value) <= 0.0:
			return "%s for %s seconds, which is no time at all" % [op, str(value)]
		return {"op": op, "field": &"", "value": float(value)}
	var field := String(row.get("field", ""))
	if not field in shape:
		return "changes %s, which is not a field of a payload" % field
	if KEPT.has(field):
		return "changes %s, which the runner keeps for itself" % field
	var now = shape.get(field)
	var fit = null
	match typeof(now):
		TYPE_FLOAT:
			if op in ["set", "add", "multiply"] and (value is float or value is int):
				fit = float(value)
		TYPE_INT:
			if op in ["set", "add", "multiply"] and (value is float or value is int) \
					and float(value) == floorf(float(value)):
				fit = int(value)
		TYPE_BOOL:
			if op == "toggle":
				fit = true
			elif op == "set" and (value is bool or ((value is float or value is int) and float(value) in [0.0, 1.0])):
				fit = bool(value)
		TYPE_STRING:
			if op == "set" and value is String:
				fit = value
		TYPE_ARRAY:
			if op == "include" and value is String:
				fit = value
	if fit == null:
		var what := "" if value == null else " " + str(value)
		return "%s %s%s, which %s cannot take — %s" % [op, field, what, field, _takes(now)]
	var made := {"op": op, "field": StringName(field), "value": null if op == "toggle" else fit}
	# What the row is worth more for every one of its part already stacked.
	var per = row.get("per_stack", null)
	if per != null:
		var whole := typeof(now) == TYPE_INT
		if not op in ["add", "multiply"] or not (per is float or per is int) \
				or not typeof(now) in [TYPE_FLOAT, TYPE_INT] or (whole and float(per) != floorf(float(per))):
			return "%s %s by %s more per stack, which only an add or a multiply to a number can grow by" \
				% [op, field, str(per)]
		if whole:
			made["per_stack"] = int(per)
		else:
			made["per_stack"] = float(per)
	return made

## What can be done to a field holding what `now` holds, for a fault to say.
static func _takes(now) -> String:
	match typeof(now):
		TYPE_FLOAT:
			return "it is a number: set, add or multiply it by one"
		TYPE_INT:
			return "it is a whole number: set, add or multiply it by one"
		TYPE_BOOL:
			return "it is a flag: set it true or false, or toggle it"
		TYPE_STRING:
			return "it is a word: set it to one"
		TYPE_ARRAY:
			return "it is a list: include a word in it"
	return "nothing is done to it"
