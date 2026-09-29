class_name RunSave
extends RefCounted
## The run save: one run in progress (world progress, earned completion ids, run clock) plus the
## records that outlive runs (best finish time, past finishes). Stored as JSON in user://run.json,
## separate from user://settings.cfg, whose format (save schema 1) is unchanged; this file has its
## own FORMAT. Older game builds ignore it, so rolling back an OTA cannot damage it.
##
## Writes are atomic (write .tmp, keep the previous file as .bak, rename). A damaged file falls back
## to the .bak; if both are unreadable the damaged file is kept aside (never deleted) and a new run
## starts. A file written by a NEWER format is never overwritten: the game plays without saving
## until an update that understands it is back.

const FORMAT := 1
const PATH := "user://run.json"

var path := PATH
var data := {}
## Why this run exists, for Diagnostics: "loaded", "new", "migrated", "recovered from backup", …
var origin := ""
## True when the file on disk must not be written (it comes from a newer format).
var read_only := false
var last_save_result := "not saved yet"


static func open(p_path := PATH) -> RunSave:
	var rs := RunSave.new()
	rs.path = p_path
	var main := _read(p_path)
	if main["ok"]:
		rs._adopt(main["data"], "loaded")
	else:
		var bak := _read(p_path + ".bak")
		if bak["ok"]:
			rs._adopt(bak["data"], "recovered from backup (%s)" % main["why"])
		elif main["why"] == "missing":
			rs.data = new_data({})
			rs.origin = "new (no run save yet: earlier versions of Mote saved no progress, so there was nothing to migrate)"
			rs.data["history"]["migration"] = "none: created by game version %s; no earlier progress existed on this device" % GameVersion.GAME_VERSION
		else:
			var aside := "%s.unreadable-%d" % [p_path, Time.get_ticks_usec()]
			DirAccess.rename_absolute(p_path, aside)
			rs.data = new_data({})
			rs.origin = "new (the run save was unreadable: %s; kept as %s)" % [main["why"], aside.get_file()]
	return rs


static func _read(p: String) -> Dictionary:
	if not FileAccess.file_exists(p):
		return {"ok": false, "why": "missing"}
	var txt := FileAccess.get_file_as_string(p)
	var parsed: Variant = JSON.parse_string(txt)
	if not parsed is Dictionary or not (parsed as Dictionary).has("format"):
		return {"ok": false, "why": "unreadable"}
	return {"ok": true, "data": parsed}


func _adopt(d: Dictionary, why: String) -> void:
	var fmt := int(d.get("format", 0))
	if fmt > FORMAT:
		# Written by a newer Mote: keep it untouched and play without saving.
		read_only = true
		data = new_data({})
		origin = "read-only: the run save is format %d, newer than this game understands (%d)" % [fmt, FORMAT]
		return
	data = migrate(d)
	origin = why if fmt == FORMAT else "%s; migrated from format %d" % [why, fmt]


## Brings any older format up to FORMAT. Conservative: unknown keys are kept, nothing earned is
## dropped. (Format 1 is the first; later formats add steps here.)
static func migrate(d: Dictionary) -> Dictionary:
	var out: Dictionary = d.duplicate(true)
	var base := new_data({})
	for k in base:
		if not out.get(k) is Dictionary:
			out[k] = base[k]
	for part in ["run", "records"]:
		var defaults: Dictionary = base[part]
		for k in defaults:
			if not (out[part] as Dictionary).has(k):
				out[part][k] = defaults[k]
	out["format"] = FORMAT
	return out


static func new_data(records: Dictionary) -> Dictionary:
	var rec := {"best_finish_s": -1.0, "best_run_id": "", "finishes": []}
	for k in records:
		rec[k] = records[k]
	return {"format": FORMAT, "run": new_run(), "records": rec, "history": {}}


static func new_run() -> Dictionary:
	# Its own generator: the global one is seeded for deterministic test runs and must not move.
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return {
		"id": "%08x%08x" % [rng.randi(), rng.randi()],
		"clock": RunClock.new().to_dict(),
		"earned": {},
		"world": {},
		"catalog_version_at_start": Completion.CATALOG_VERSION,
		"game_versions": [],
		"ota_ids": [],
		"finish": {},
		# Tier-2 abilities found this run (Tier2.to_dict); not completion entries.
		"tier2": {},
	}


func run() -> Dictionary:
	return data["run"]


func records() -> Dictionary:
	return data["records"]


func earned() -> Dictionary:
	return run()["earned"]


## A fresh run; records (best time, past finishes) are kept.
func start_new_run() -> void:
	data["run"] = new_run()
	origin = "new run"


## Records a finish (called once per run, when its clock finishes).
func record_finish(finish_s: float, pct: float, catalog_version: int, identity: Dictionary) -> void:
	var r := run()
	r["finish"] = {"finish_s": finish_s, "percent": pct, "catalog_version": catalog_version,
			"game_version": GameVersion.GAME_VERSION, "ota_id": identity.get("ota_id", "none"),
			"timer_model": RunClock.TIMER_MODEL}
	var rec := records()
	(rec["finishes"] as Array).append({"run_id": r["id"], "finish_s": finish_s, "percent": pct,
			"catalog_version": catalog_version, "game_version": GameVersion.GAME_VERSION})
	if rec["best_finish_s"] < 0.0 or finish_s < rec["best_finish_s"]:
		rec["best_finish_s"] = finish_s
		rec["best_run_id"] = r["id"]


## Notes which game version / OTA played part of this run (for later verification).
func note_identity(identity: Dictionary) -> void:
	for pair in [["game_versions", GameVersion.GAME_VERSION], ["ota_ids", str(identity.get("ota_id", "none"))]]:
		var arr: Array = run()[pair[0]]
		if not arr.has(pair[1]):
			arr.append(pair[1])


func save() -> bool:
	if read_only:
		last_save_result = "not saved: the run save on disk is from a newer format"
		return false
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		last_save_result = "failed: cannot write (%s)" % error_string(FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(data, "\t", true, true))
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path + ".bak")
		DirAccess.rename_absolute(path, path + ".bak")
	var err := DirAccess.rename_absolute(tmp, path)
	last_save_result = "ok" if err == OK else "failed: %s" % error_string(err)
	return err == OK


## Removes the run save and its backup (tests only).
static func erase(p_path: String) -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(p_path + suffix):
			DirAccess.remove_absolute(p_path + suffix)
