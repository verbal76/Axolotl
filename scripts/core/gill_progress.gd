class_name GillProgress
extends RefCounted
## Permanent progression (docs/SKILL_TREE.md): the red starfish collected and the skill-tree nodes
## bought. It belongs to the PROFILE, not to a run: New Run, OTA updates and rollbacks keep it.
##
## Home: its own file, user://gill_progress.json (never run.json, never settings.cfg):
## - no older build knows this file, so no older build (b22's bundled game, any earlier OTA) ever
##   rewrites or deletes it: a rollback cannot destroy it, and the next update finds it intact;
## - Settings.save() rewrites settings.cfg from scratch in every build, and RunSave replaces the
##   whole "run" on New Run: both are the wrong semantics and the wrong risk.
##
## Loss-proof economy (owner ruling 7): the ONE document holds both the collected starfish ids and
## the purchased nodes, and the balance is DERIVED (collected - sum of purchased costs), never
## stored. So no crash can leave "collected but its value lost", "spent but not unlocked" or
## "unlocked without spending": every write replaces the whole document atomically.
##
## Writes: the new document goes to .tmp, is read back and checked, the current main file is copied
## to .bak, and .tmp is renamed over the main file (an atomic replace), so at every instant the main
## file is either the old document or the new one, whole. Reading: every readable candidate (main,
## .bak and a complete .tmp left by an interrupted write) is MERGED: both sets only ever grow (no
## respec, no refund), so their union is the newest state and a damaged or older copy can only add
## nothing. Then reconcile (see _reconcile). A document from a NEWER format is read for play but
## never written (a later build may understand fields this one does not).

const FORMAT := 1
const KIND := "mote.gill_progress"
const PATH := "user://gill_progress.json"

var path := PATH
## Starfish id -> {"t": unix time, "v": game version}. Only ids in StarfishTable count.
var collected := {}
## Node id -> {"cost": int, "t": unix time, "n": purchase number}. Only SkillTree ids give effects.
var purchased := {}
## Entries this build does not know (kept verbatim in the file, never counted as currency; see
## _reconcile): a rollback never erases what a newer build recorded.
var foreign_collected := {}
var foreign_purchased := {}
var seq := 0
## Why the state is what it is, for Diagnostics: "new", "loaded", "recovered ...", "merged ...".
var origin := ""
var notes: Array[String] = []
var read_only := false
var last_save_result := "not saved yet"
## Spent more than collected (a hand-edited or damaged file): the nodes are kept, the balance shows 0.
var overspent := 0
## Onboarding (docs/ONBOARDING.md): flag -> true for each one done. The four player-facing flags are
## Onboarding.FLAGS ("intro", "feeding", "parasite", "starfish"); "first_frond" notes that the
## first run's empty frond was given (never again on a later run). Like the starfish, flags only
## ever get set (a merge is their union), and keys this build does not know are kept.
var onboarding := {}
## Whether any copy read had the onboarding record (else the profile predates it and is migrated
## once, Game._setup_onboarding). Until then nothing about onboarding is written.
var onb_known := false


# --- Opening ------------------------------------------------------------------------------------

static func open(p_path := PATH) -> GillProgress:
	var gp := GillProgress.new()
	gp.path = p_path
	gp._load()
	return gp


static func _read(p: String) -> Dictionary:
	if not FileAccess.file_exists(p):
		return {"ok": false, "why": "missing"}
	var txt := FileAccess.get_file_as_string(p)
	if txt.strip_edges() == "":
		return {"ok": false, "why": "empty"}
	var parsed: Variant = JSON.parse_string(txt)
	if not parsed is Dictionary:
		return {"ok": false, "why": "unreadable"}
	var d: Dictionary = parsed
	if str(d.get("kind", "")) != KIND or not d.has("format"):
		return {"ok": false, "why": "not a progress file"}
	return {"ok": true, "data": d}


func _load() -> void:
	var found := []
	var why := {}
	for suffix in ["", ".bak", ".tmp"]:
		var r := _read(path + suffix)
		if r["ok"]:
			found.append([suffix, r["data"]])
		else:
			why[suffix] = r["why"]
	if found.is_empty():
		if why[""] == "missing":
			origin = "new"
		else:
			origin = "new (the progress file was %s and no backup was readable)" % why[""]
			_set_aside(path)
		return
	var used: Array[String] = []
	for f in found:
		var d: Dictionary = f[1]
		if int(d.get("format", 0)) > FORMAT:
			read_only = true
		_merge(d)
		used.append("main" if f[0] == "" else str(f[0]).trim_prefix("."))
	var main_ok: bool = found[0][0] == ""
	if main_ok and found.size() == 1:
		origin = "loaded"
	elif main_ok:
		origin = "loaded; merged with " + ", ".join(used.slice(1))
	else:
		origin = "recovered from %s (main file %s)" % [", ".join(used), why.get("", "?")]
		if why.get("", "missing") != "missing":
			_set_aside(path)
	if read_only:
		origin += "; read-only: written by a newer format than %d" % FORMAT
	_reconcile()
	# A recovery is written back at once (main whole again), unless read-only.
	if not main_ok and not read_only:
		save()


## Keeps an unreadable main file aside (never deleted), for diagnosis.
static func _set_aside(p: String) -> void:
	if FileAccess.file_exists(p):
		DirAccess.rename_absolute(p, "%s.unreadable-%d" % [p, Time.get_ticks_usec()])


## Union of a document into this state (both sets only ever grow).
func _merge(d: Dictionary) -> void:
	seq = maxi(seq, int(d.get("seq", 0)))
	var c: Variant = d.get("collected", {})
	if c is Dictionary:
		for id in c:
			if not collected.has(str(id)):
				collected[str(id)] = c[id] if c[id] is Dictionary else {}
	elif c is Array:
		for id in c:
			collected[str(id)] = {}
	var o: Variant = d.get("onboarding", null)
	if o is Dictionary:
		onb_known = true
		for k in o:
			if bool(o[k]):
				onboarding[str(k)] = true
	var p: Variant = d.get("purchased", {})
	if p is Dictionary:
		for id in p:
			if not purchased.has(str(id)):
				purchased[str(id)] = p[id]


## Reconcile on load (owner ruling 7):
## - unknown starfish ids are dropped from the count (kept verbatim in the file);
## - a purchase is dropped only when it is PROVABLY invalid (a malformed record, or an id that is
##   not a node id at all); a known node whose prerequisites are missing is never revoked; a node
##   this build does not know keeps its recorded cost as spent (so a rollback can mint nothing);
## - spent over collected: the nodes are kept, the balance shows 0, and it is logged.
func _reconcile() -> void:
	var star_shape := RegEx.create_from_string("^star\\.b[0-9]+\\.[0-9]+$")
	for id in collected.keys():
		if StarfishTable.has(id):
			continue
		# (A well-formed id from a newer table is kept in the file; anything else is garbage.)
		if star_shape.search(id) != null:
			foreign_collected[id] = collected[id]
			notes.append("unknown starfish id %s not counted (kept in the file)" % id)
		else:
			notes.append("malformed starfish id %s dropped" % id)
		collected.erase(id)
	for id in purchased.keys():
		var rec: Variant = purchased[id]
		var shaped := RegEx.create_from_string("^[a-z]+\\.[0-9]+$").search(id) != null
		if not shaped or not rec is Dictionary:
			purchased.erase(id)
			notes.append("malformed purchase %s dropped" % id)
			continue
		var r: Dictionary = rec
		if SkillTree.has(id):
			r["cost"] = SkillTree.cost(id)
			var miss := SkillTree.missing(id, purchased)
			if not miss.is_empty():
				notes.append("%s kept although %s is missing (never revoked)" % [id, ", ".join(miss)])
		else:
			if not r.has("cost") or int(r["cost"]) < 0:
				purchased.erase(id)
				notes.append("unknown purchase %s without a cost dropped" % id)
				continue
			foreign_purchased[id] = r
			purchased.erase(id)
			notes.append("unknown node %s kept, its cost %d counted as spent" % [id, int(r["cost"])])
	overspent = maxi(0, spent() - collected.size())
	if overspent > 0:
		notes.append("spent %d exceeds collected %d: nodes kept, balance shown as 0" % [spent(), collected.size()])
	for n in notes:
		print("[GILL] ", n)


# --- The economy (derived) -----------------------------------------------------------------------

func spent() -> int:
	var k := 0
	for id in purchased:
		k += SkillTree.cost(id)
	for id in foreign_purchased:
		k += int(foreign_purchased[id].get("cost", 0))
	return k


## Starfish to spend: collected minus the costs of everything bought, never below 0.
func balance() -> int:
	return maxi(0, collected.size() - spent())


func has_star(id: String) -> bool:
	return collected.has(id)


func stars() -> int:
	return collected.size()


func owns(id: String) -> bool:
	return purchased.has(id)


func skills() -> int:
	return purchased.size()


## The family's tier: the highest of its nodes owned (0 none).
func tier(family: String) -> int:
	var best := 0
	for id in purchased:
		if str(id).get_slice(".", 0) == family:
			best = maxi(best, int(str(id).get_slice(".", 1)))
	return best


func tiers() -> Dictionary:
	var out := {}
	for f in SkillTree.FAMILIES:
		out[f] = tier(f)
	return out


func node_state(id: String) -> String:
	return SkillTree.state(id, purchased, balance())


## A starfish touched: recorded and written at once. False if already had or unknown.
func collect(id: String) -> bool:
	if collected.has(id) or not StarfishTable.has(id):
		return false
	collected[id] = {"t": int(Time.get_unix_time_from_system()), "v": GameVersion.GAME_VERSION}
	save()
	return true


## Buys a node: only when its prerequisites are owned and it is affordable, and only if the whole
## document is written (a failed write leaves nothing bought). Returns "" or why not.
func buy(id: String) -> String:
	if not SkillTree.has(id):
		return "unknown"
	if purchased.has(id):
		return "owned"
	if not SkillTree.missing(id, purchased).is_empty():
		return "locked"
	if balance() < SkillTree.cost(id):
		return "unaffordable"
	if read_only:
		return "read-only"
	purchased[id] = {"cost": SkillTree.cost(id), "t": int(Time.get_unix_time_from_system()), "n": purchased.size() + foreign_purchased.size() + 1}
	if not save():
		purchased.erase(id)
		return "not saved"
	return ""


# --- Writing ---------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var c := collected.duplicate(true)
	c.merge(foreign_collected)
	var p := purchased.duplicate(true)
	p.merge(foreign_purchased)
	var id: Dictionary = Boot.identity()
	var d := {"format": FORMAT, "kind": KIND, "seq": seq, "collected": c, "purchased": p,
			"written_by": {"game_version": GameVersion.GAME_VERSION, "ota_id": str(id.get("ota_id", "none"))}}
	if onb_known:
		d["onboarding"] = onboarding.duplicate()
	return d


# --- Onboarding flags ------------------------------------------------------------------------

func onb_done(flag: String) -> bool:
	return onboarding.has(flag)


## Sets a flag and writes the profile at once. False if it was already set.
func mark_onb(flag: String) -> bool:
	if onboarding.has(flag):
		return false
	onboarding[flag] = true
	onb_known = true
	save()
	return true


## Once, for a profile from before onboarding existed: what the player has already done counts
## (docs/ONBOARDING.md, Migration). `played` = a run in progress or finished; `past_tutorial` = a
## saved or finished run past Ball 1's tutorial. Returns the flags set.
func migrate_onboarding(played: bool, past_tutorial: bool) -> Array:
	if onb_known:
		return []
	onb_known = true
	var set_now := []
	var progress := stars() > 0 or skills() > 0 or not foreign_collected.is_empty() or not foreign_purchased.is_empty()
	if played or past_tutorial or progress:
		set_now.append("intro")
	if past_tutorial:
		set_now.append_array(["feeding", "parasite", "first_frond"])
	if progress:
		set_now.append("starfish")
	for f in set_now:
		onboarding[f] = true
	notes.append("onboarding migrated: %s" % (", ".join(set_now) if not set_now.is_empty() else "new player, nothing done"))
	save()
	return set_now


## Writes the whole document atomically (tmp, verify, main -> .bak copy, rename over main).
## `fail_at` is for tests only: "tmp" stops after writing .tmp, "verify" corrupts it first.
func save(fail_at := "") -> bool:
	if read_only:
		last_save_result = "not saved: the progress file is from a newer format"
		return false
	seq += 1
	var txt := JSON.stringify(to_dict(), "\t", true)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		last_save_result = "failed: cannot write (%s)" % error_string(FileAccess.get_open_error())
		return false
	f.store_string(txt if fail_at != "verify" else txt.substr(0, txt.length() / 2))
	f.flush()
	f.close()
	var back := _read(tmp)
	if not back["ok"] or int((back["data"] as Dictionary).get("seq", -1)) != seq:
		last_save_result = "failed: the written copy did not read back"
		DirAccess.remove_absolute(tmp)
		return false
	if fail_at == "tmp":
		last_save_result = "stopped after .tmp (test)"
		return true
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".bak")
	var err := DirAccess.rename_absolute(tmp, path)
	last_save_result = "ok" if err == OK else "failed: %s" % error_string(err)
	return err == OK


## Removes the file and its companions (tests only).
static func erase(p_path: String) -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(p_path + suffix):
			DirAccess.remove_absolute(p_path + suffix)


func diagnostics_text() -> String:
	var L: Array[String] = []
	L.append("Red starfish & skills (permanent)")
	L.append("  Red Starfish %d/%d  ·  Skills %d/%d  ·  to spend %d" % [stars(), StarfishTable.COUNT, skills(), SkillTree.COUNT, balance()])
	L.append("  File: %s, format %d, write %d; %s" % [path, FORMAT, seq, origin])
	L.append("  Last save: %s" % last_save_result)
	var onb: Array[String] = []
	for f in ["intro", "feeding", "parasite", "starfish"]:
		onb.append("%s %s" % [f, "done" if onb_done(f) else "-"])
	L.append("  Onboarding: %s" % ", ".join(onb))
	for n in notes:
		L.append("  Note: " + n)
	return "\n".join(L)
