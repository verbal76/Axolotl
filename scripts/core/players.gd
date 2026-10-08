class_name Players
extends RefCounted
## Player profiles (owner, 2026-10-08): more than one player on one phone ("I want to give my phone
## to my daughter ... she can save her own character"). Each player has their own run (and so their
## own completion, best finishes, Treasure Hunt, Hard Mode and lessons), their own Red Starfish and
## Skills, and their own colours and pattern. Device settings (sound, haptics, HUD, tutorials) are
## shared. Every character is still called Gill (GameVersion.CHARACTER_NAME); the player's name only
## picks whose save it is.
##
## Storage, chosen so nothing an older build knows ever changes:
## - The registry is its own file, user://players.json (Settings.save rewrites settings.cfg from
##   scratch in every build, so it can never live there).
## - The first player ("main") IS the existing save: user://run.json, user://gill_progress.json, the
##   colours in settings.cfg and user://gill_pattern.png, exactly where they always were. Nothing is
##   moved or migrated, so a rollback to an older build plays the main player's game unchanged.
## - Every other player lives in user://players/<id>/ (run.json, gill_progress.json, look.cfg,
##   gill_pattern.png), with the same atomic writes as the main files.
## Automated runs never read or write the registry: they are always the main player (and the test
## run paths stay their own).

const PATH := "user://players.json"
const DIR := "user://players/"
const MAIN := "main"
const MAX := 6
const NAME_MAX := 16
const MAIN_DEFAULT_NAME := "Player 1"

static var _doc := {}


static func _tests() -> bool:
	return Settings.test_mode != "" and not Settings.test_args.has("players")


static func _load() -> Dictionary:
	if not _doc.is_empty():
		return _doc
	var d: Variant = null
	if not _tests() and FileAccess.file_exists(PATH):
		d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not (d is Dictionary) or not (d.get("players") is Array):
		d = {}
	_doc = d
	_doc["players"] = (_doc.get("players", []) as Array).filter(func(e) -> bool:
		return e is Dictionary and str(e.get("id", "")) != "" and str(e.get("name", "")) != "")
	if not _ids(_doc).has(MAIN):
		(_doc["players"] as Array).push_front({"id": MAIN, "name": MAIN_DEFAULT_NAME})
	_doc["current"] = str(_doc.get("current", MAIN)) if _ids(_doc).has(str(_doc.get("current", MAIN))) else MAIN
	_doc["seq"] = int(_doc.get("seq", 1))
	return _doc


static func _save() -> bool:
	if _tests():
		return true
	var tmp := PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(_doc, "\t"))
	f.close()
	return DirAccess.rename_absolute(tmp, PATH) == OK


## Forgets what was read (tests; the next call reads the file again).
static func reload() -> void:
	_doc = {}


## [{"id", "name"}], the main player first.
static func list() -> Array:
	return (_load()["players"] as Array).duplicate(true)


static func list_ids() -> Array:
	return _ids(_load())


static func _ids(d: Dictionary) -> Array:
	return (d.get("players", []) as Array).map(func(e: Dictionary) -> String: return str(e["id"]))


static func current() -> String:
	if _tests():
		return MAIN
	return str(_load()["current"])


static func name_of(id: String) -> String:
	for e in _load()["players"]:
		if str(e["id"]) == id:
			return str(e["name"])
	return ""


static func current_name() -> String:
	return name_of(current())


## A name as it is kept: trimmed, at most NAME_MAX characters ("" if nothing is left).
static func clean_name(n: String) -> String:
	return n.strip_edges().replace("\n", " ").left(NAME_MAX).strip_edges()


static func can_add() -> bool:
	return (_load()["players"] as Array).size() < MAX


## Adds a player (not yet current); returns its id, or "" (no name, or MAX players already).
static func add(n: String) -> String:
	var nm := clean_name(n)
	if nm == "" or not can_add():
		return ""
	var d := _load()
	var id := "p%d" % int(d["seq"])
	d["seq"] = int(d["seq"]) + 1
	(d["players"] as Array).append({"id": id, "name": nm})
	DirAccess.make_dir_recursive_absolute(dir_of(id))
	_save()
	return id


static func rename(id: String, n: String) -> bool:
	var nm := clean_name(n)
	if nm == "":
		return false
	for e in _load()["players"]:
		if str(e["id"]) == id:
			e["name"] = nm
			return _save()
	return false


## Removes a player and their saves for good. The main player (the original save) is never removed;
## removing the current player makes the main player current.
static func remove(id: String) -> bool:
	if id == MAIN or not list_ids().has(id):
		return false
	var d := _load()
	d["players"] = (d["players"] as Array).filter(func(e: Dictionary) -> bool: return str(e["id"]) != id)
	if str(d["current"]) == id:
		d["current"] = MAIN
	var dir := DirAccess.open(dir_of(id))
	if dir != null:
		for f in dir.get_files():
			dir.remove(f)
		DirAccess.remove_absolute(dir_of(id))
	return _save()


static func set_current(id: String) -> bool:
	if not list_ids().has(id):
		return false
	_load()["current"] = id
	return _save()


static func dir_of(id: String) -> String:
	return DIR + id + "/"


# --- Where the current player's saves are --------------------------------------------------------

static func run_path() -> String:
	var id := current()
	return RunSave.PATH if id == MAIN else dir_of(id) + "run.json"


static func gill_path() -> String:
	var id := current()
	return GillProgress.PATH if id == MAIN else dir_of(id) + "gill_progress.json"


## The colours of a player other than the main one ("" for the main player: settings.cfg).
static func look_path() -> String:
	var id := current()
	return "" if id == MAIN else dir_of(id) + "look.cfg"


static func pattern_path() -> String:
	var id := current()
	return GillLook.UPLOAD_PATH if id == MAIN else dir_of(id) + "gill_pattern.png"
