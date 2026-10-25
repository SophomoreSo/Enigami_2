class_name Heroes
extends RefCounted

## The roster: who the player can play as, as the content database lists them
## (`heroes`, data/db/heroes/heroes.sql) — a row a hero, in the order they
## stand on the bench's screen (`HeroSelect`), with the character of the atlas
## each is drawn as and the colour each wears, which is the picture's to read. Who is played as is the
## profile's (`GameState.hero`), chosen sat down on a bench. What a hero can
## do is to come: the table grows a column for it when it does, and for now a
## hero is a face and a name.

## Every hero there is, in the order they stand.
static func ids() -> PackedStringArray:
	var out := PackedStringArray()
	if not Db.available() or not Db.has_table("heroes"):
		return out
	for row in Db.rows("SELECT id FROM heroes ORDER BY place"):
		out.append(String(row["id"]))
	return out

static func exists(id: String) -> bool:
	return id != "" and ids().has(id)

## The first of the roster: who a new profile plays as, and who one that names
## a hero no longer there falls back to. "" with no roster at all.
static func first() -> String:
	var all := ids()
	return all[0] if not all.is_empty() else ""

## The character of the atlas standing in for `id` until their own sprites are
## made.
static func sprite_of(id: String) -> String:
	return String(Db.value("SELECT sprite FROM heroes WHERE id = ?", [id], ""))

## Who `id` is, for the tool their sprites are made with: the words the table
## keeps (graphics/assets/sprites/HEROES.md).
static func prompt_of(id: String) -> String:
	return String(Db.value("SELECT prompt FROM heroes WHERE id = ?", [id], ""))

## The colour `id` wears on their card, as the table writes it ("#rrggbb"). A
## colour is the picture's (`HeroSelect.color_of`): the rules hand the words on.
static func color_html(id: String) -> String:
	return String(Db.value("SELECT color FROM heroes WHERE id = ?", [id], "#ffffff"))

## What `id` is called, in the language being played: the English is the
## id's words as the fallback.
static func name_for(id: String) -> String:
	return Loc.opt("hud.heroes.name.%s" % id, id.replace("_", " ").to_upper())
