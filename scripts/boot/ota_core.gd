extends RefCounted
## NATIVE LAYER — OTA state machine, manifest validation and package verification.
## Pure logic over a storage root (user://ota on device, a scratch dir in tests).
##
## Layout under `root`:
##   state.json                  CURRENT / PREVIOUS / PENDING / READY, bad list, boot health
##   packages/<ota_id>.pck       verified packages (promoted from .incoming-<ota_id>.pck)
##   manifests/<ota_id>.json     exact signed manifest bytes
##   manifests/<ota_id>.json.sig base64 RSA-SHA256 signature over those bytes
##
## A package is only ever loaded after its manifest signature, runtime, size and SHA-256 all
## check out. The APK's bundled game is the baseline that is always available.

const Config := preload("res://scripts/boot/ota_config.gd")

## Starts of the same OTA that never reached the healthy checkpoint before it is abandoned.
const MAX_UNHEALTHY_STARTS := 2
const REQUIRED := ["schema", "channel", "ota_id", "seq", "source_sha", "runtime_id", "game_version",
		"save_schema", "min_save_schema", "pck_url", "pck_sha256", "pck_size", "created_at",
		"minimum_bootstrap_version"]

var root: String
var runtime_id: String
var channel: String
var public_key_pem: String
var bootstrap_version: int
## Save schema currently on disk (from user://settings.cfg); 0 when there is no save yet.
var device_save_schema := 0
## Desktop-only local test hook (set from --ota-pointer=http://127.0.0.1...). Never on device.
var allow_local_http := false
var state: Dictionary = {}
## The manifest actually mounted by this process ({} = bundled baseline).
var active: Dictionary = {}
var boot_log: Array[String] = []


func _init(p_root := "user://ota", p_runtime := "", p_channel := Config.CHANNEL,
		p_key := Config.PUBLIC_KEY_PEM, p_bootstrap := Config.BOOTSTRAP_VERSION) -> void:
	root = p_root
	runtime_id = p_runtime if p_runtime != "" else Config.runtime_id()
	channel = p_channel
	public_key_pem = p_key
	bootstrap_version = p_bootstrap
	DirAccess.make_dir_recursive_absolute(root.path_join("packages"))
	DirAccess.make_dir_recursive_absolute(root.path_join("manifests"))
	load_state()


# --- state ---------------------------------------------------------------------------------

static func empty_state() -> Dictionary:
	return {"version": 1, "current": {}, "previous": {}, "pending": {}, "ready": {}, "bad": [],
			"disabled": false, "auto_activate": true, "rollback_count": 0,
			"boot": {"ota_id": "", "starts": 0, "healthy_id": ""}, "events": {}}


func load_state() -> void:
	state = empty_state()
	var path := root.path_join("state.json")
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		for k in parsed:
			state[k] = parsed[k]
	else:
		# A corrupt state file must never brick the install: start from the baseline.
		event("state", "state.json unreadable; reset to bundled baseline")


## Atomic: write a temp file then rename over the old one.
func save_state() -> void:
	var tmp := root.path_join("state.json.tmp")
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(state, "  ", true))
	f.close()
	DirAccess.rename_absolute(tmp, root.path_join("state.json"))


func event(kind: String, result: String) -> void:
	var ev: Dictionary = state["events"]
	ev[kind] = {"time": Time.get_datetime_string_from_system(true) + "Z", "result": result}
	boot_log.append("%s: %s" % [kind, result])


func slot(name: String) -> Dictionary:
	return state.get(name, {}) as Dictionary


func is_bad(ota_id: String) -> bool:
	return ota_id in (state["bad"] as Array)


func mark_bad(m: Dictionary, reason: String) -> void:
	var id: String = m.get("ota_id", "")
	if id != "" and not is_bad(id):
		(state["bad"] as Array).append(id)
	for s in ["pending", "ready"]:
		if slot(s).get("ota_id", "") == id:
			state[s] = {}
	if slot("current").get("ota_id", "") == id:
		state["current"] = slot("previous")
		state["previous"] = {}
		state["rollback_count"] = int(state["rollback_count"]) + 1
	elif slot("previous").get("ota_id", "") == id:
		state["previous"] = {}
	event("rejected", "%s: %s" % [id, reason])


func package_path(ota_id: String) -> String:
	return root.path_join("packages").path_join(ota_id + ".pck")


func incoming_path(ota_id: String) -> String:
	return root.path_join("packages").path_join(".incoming-%s.pck" % ota_id)


func manifest_path(ota_id: String) -> String:
	return root.path_join("manifests").path_join(ota_id + ".json")


# --- verification ----------------------------------------------------------------------------

static func sha256_bytes(data: PackedByteArray) -> PackedByteArray:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(data)
	return ctx.finish()


static func file_sha256(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	while f.get_position() < f.get_length():
		ctx.update(f.get_buffer(1 << 20))
	return ctx.finish().hex_encode()


func verify_signature(manifest_bytes: PackedByteArray, sig_b64: String) -> bool:
	var key := CryptoKey.new()
	if key.load_from_string(public_key_pem, true) != OK:
		return false
	var sig := Marshalls.base64_to_raw(sig_b64.strip_edges())
	if sig.is_empty():
		return false
	return Crypto.new().verify(HashingContext.HASH_SHA256, sha256_bytes(manifest_bytes), sig, key)


static func _is_hex(s: String, n: int) -> bool:
	if s.length() != n:
		return false
	for c in s:
		if not "0123456789abcdef".contains(c):
			return false
	return true


## "" when the manifest may be used on this device, otherwise the reason it may not.
## RUNTIME MISMATCH is reported distinctly: it means a new APK is needed, not a bad OTA.
func validate_manifest(m: Dictionary) -> String:
	for k in REQUIRED:
		if not m.has(k):
			return "invalid manifest: missing '%s'" % k
	if int(m["schema"]) != 1:
		return "invalid manifest: unknown schema %s" % m["schema"]
	if m["channel"] != channel:
		return "invalid manifest: channel '%s' (this install follows '%s')" % [m["channel"], channel]
	if m["runtime_id"] != runtime_id:
		return runtime_mismatch(str(m["runtime_id"]))
	if int(m["minimum_bootstrap_version"]) > bootstrap_version:
		return "native update required: OTA needs bootstrap v%d, installed v%d" % [int(m["minimum_bootstrap_version"]), bootstrap_version]
	if not _is_hex(str(m["source_sha"]), 40):
		return "invalid manifest: source_sha is not a 40-character git SHA"
	if not _is_hex(str(m["pck_sha256"]), 64):
		return "invalid manifest: pck_sha256 is not a SHA-256"
	if int(m["pck_size"]) <= 0:
		return "invalid manifest: pck_size"
	var url := str(m["pck_url"])
	if not (url.begins_with("https://") or (allow_local_http and url.begins_with("http://127.0.0.1:"))):
		return "invalid manifest: package URL must be HTTPS"
	if not str(m["ota_id"]).is_valid_filename() or str(m["ota_id"]).begins_with("."):
		return "invalid manifest: ota_id"
	var gv := str(m["game_version"]).split(".")
	if gv.size() != 3 or not (gv[0].is_valid_int() and gv[1].is_valid_int() and gv[2].is_valid_int()):
		return "invalid manifest: game_version is not MAJOR.MINOR.PATCH"
	return save_compat(m)


## Why an OTA for `other` cannot run here. An OTA built for an OLDER revision of this same
## runtime is permanently incompatible with this app ("incompatible runtime"); anything else
## needs a newer app ("native update required").
func runtime_mismatch(other: String) -> String:
	var re := RegEx.create_from_string("^(.*)-r(\\d+)$")
	var a := re.search(other)
	var b := re.search(runtime_id)
	if a != null and b != null and a.get_string(1) == b.get_string(1) and int(a.get_string(2)) < int(b.get_string(2)):
		return "incompatible runtime: OTA targets older runtime %s, this app runs %s (waiting for a compatible OTA)" % [other, runtime_id]
	return "native update required: OTA targets runtime %s, installed runtime is %s" % [other, runtime_id]


## An OTA reads saves from min_save_schema up to save_schema. A save newer than the OTA
## understands (e.g. after rolling back past a migration) blocks automatic activation.
func save_compat(m: Dictionary) -> String:
	if device_save_schema == 0:
		return ""
	if device_save_schema > int(m.get("save_schema", 0)):
		return "save incompatible: save schema %d is newer than OTA %s understands (%d)" % [device_save_schema, m.get("ota_id", "?"), int(m.get("save_schema", 0))]
	if device_save_schema < int(m.get("min_save_schema", 0)):
		return "save incompatible: OTA %s no longer reads save schema %d" % [m.get("ota_id", "?"), device_save_schema]
	return ""


## Signature + manifest checks on exact bytes. Returns [manifest, ""] or [{}, reason].
func check_manifest(manifest_bytes: PackedByteArray, sig_b64: String) -> Array:
	if not verify_signature(manifest_bytes, sig_b64):
		return [{}, "signature verification failed"]
	var parsed: Variant = JSON.parse_string(manifest_bytes.get_string_from_utf8())
	if not parsed is Dictionary:
		return [{}, "invalid manifest: not a JSON object"]
	var m: Dictionary = parsed
	var why := validate_manifest(m)
	return [m if why == "" else {}, why]


## Size and hash of a package file against its manifest.
func verify_package(m: Dictionary, path: String) -> String:
	if not FileAccess.file_exists(path):
		return "package missing"
	var f := FileAccess.open(path, FileAccess.READ)
	var size := f.get_length()
	f.close()
	if size != int(m["pck_size"]):
		return "size mismatch: %d bytes, manifest says %d" % [size, int(m["pck_size"])]
	var h := file_sha256(path)
	if h != str(m["pck_sha256"]):
		return "SHA-256 mismatch: got %s" % h
	return ""


## Re-checks a stored package: stored signed manifest must still verify and match.
func verify_installed(m: Dictionary) -> String:
	var id: String = m.get("ota_id", "")
	var mp := manifest_path(id)
	if not FileAccess.file_exists(mp) or not FileAccess.file_exists(mp + ".sig"):
		return "stored manifest missing"
	var res := check_manifest(FileAccess.get_file_as_bytes(mp), FileAccess.get_file_as_string(mp + ".sig"))
	if res[1] != "":
		return res[1]
	if (res[0] as Dictionary).get("pck_sha256") != m.get("pck_sha256"):
		return "stored manifest does not match state"
	return verify_package(res[0], package_path(id))


# --- download staging --------------------------------------------------------------------------

## Verifies a finished download at incoming_path() and promotes it. Never touches the active
## package. On any failure the temp file is deleted and nothing else changes.
func stage_incoming(manifest_bytes: PackedByteArray, sig_b64: String) -> String:
	var res := check_manifest(manifest_bytes, sig_b64)
	if res[1] != "":
		event("verify", "rejected: " + res[1])
		return res[1]
	var m: Dictionary = res[0]
	var id: String = m["ota_id"]
	var tmp := incoming_path(id)
	var why := verify_package(m, tmp)
	if why != "":
		DirAccess.remove_absolute(tmp)
		# Published packages are immutable, so a full-size file with the wrong hash will never
		# become valid: remember it. Short/interrupted downloads stay retryable.
		if why.begins_with("SHA-256 mismatch") and not is_bad(id):
			(state["bad"] as Array).append(id)
		event("verify", "rejected %s: %s (temp file deleted)" % [id, why])
		save_state()
		return why
	var f := FileAccess.open(manifest_path(id), FileAccess.WRITE)
	f.store_buffer(manifest_bytes)
	f.close()
	f = FileAccess.open(manifest_path(id) + ".sig", FileAccess.WRITE)
	f.store_string(sig_b64.strip_edges())
	f.close()
	DirAccess.remove_absolute(package_path(id))
	DirAccess.rename_absolute(tmp, package_path(id))
	state["ready"] = m
	event("verify", "verified %s (%d bytes, sha256 %s)" % [id, int(m["pck_size"]), str(m["pck_sha256"]).left(12)])
	if state["auto_activate"]:
		activate_ready()
	save_state()
	return ""


## READY -> PENDING: loaded on the next clean start.
func activate_ready() -> String:
	var r := slot("ready")
	if r.is_empty():
		return "nothing downloaded"
	var why := save_compat(r)
	if why != "":
		return why
	state["pending"] = r
	state["ready"] = {}
	event("activate", "%s will load on next start" % r["ota_id"])
	save_state()
	return ""


## Newest known OTA sequence (anything at or below it is not an update).
func known_seq() -> int:
	var best := 0
	for s in ["current", "pending", "ready"]:
		best = maxi(best, int(slot(s).get("seq", 0)))
	return best


# --- boot selection ------------------------------------------------------------------------------

## Chooses and mounts a package before any replaceable game resource is loaded.
## `loader` mounts a verified path and returns success (ProjectSettings.load_resource_pack
## on device). Every outcome falls back towards CURRENT, PREVIOUS and finally the baseline.
func boot(loader: Callable) -> Dictionary:
	active = {}
	if state["disabled"]:
		event("load", "OTA disabled by user: running bundled baseline")
		state["boot"]["ota_id"] = ""
		save_state()
		return active
	# Snapshot first: mark_bad() shifts PREVIOUS into CURRENT while we iterate.
	var candidates: Array = []
	for name in ["pending", "current", "previous"]:
		if not slot(name).is_empty():
			candidates.append([name, slot(name)])
	for c in candidates:
		var name: String = c[0]
		var m: Dictionary = c[1]
		var id: String = m["ota_id"]
		if is_bad(id):
			if slot(name).get("ota_id", "") == id:
				state[name] = {}
			continue
		var b: Dictionary = state["boot"]
		if b["ota_id"] == id and int(b["starts"]) >= MAX_UNHEALTHY_STARTS:
			mark_bad(m, "never reached boot health after %d starts" % int(b["starts"]))
			continue
		var why := validate_manifest(m)
		if why == "":
			why = verify_installed(m)
		if why != "":
			if why.begins_with("save incompatible") or why.begins_with("native update required"):
				event("load", "skipped %s: %s" % [id, why])
				continue
			if why.begins_with("incompatible runtime"):
				# Left over from before this APK was installed: it can never run here again.
				# Not a faulty OTA, so it is dropped rather than marked bad.
				if slot(name).get("ota_id", "") == id:
					state[name] = {}
				event("load", "dropped %s: %s" % [id, why])
				continue
			mark_bad(m, why)
			continue
		# Count the attempt BEFORE mounting, so a crash during load still counts.
		state["boot"] = {"ota_id": id, "starts": (int(b["starts"]) if b["ota_id"] == id else 0) + 1, "healthy_id": b.get("healthy_id", "")}
		save_state()
		if loader.call(package_path(id)):
			active = m
			event("load", "loaded %s (%s) from %s" % [id, name, str(m["source_sha"]).left(12)])
			save_state()
			return active
		mark_bad(m, "load_resource_pack failed")
	state["boot"] = {"ota_id": "", "starts": 0, "healthy_id": state["boot"].get("healthy_id", "")}
	event("load", "no OTA selected: running bundled baseline")
	save_state()
	return active


## The game reached its boot-health checkpoint with `active` mounted.
func mark_healthy() -> void:
	var id: String = active.get("ota_id", "")
	state["boot"] = {"ota_id": id, "starts": 0, "healthy_id": id}
	if id != "" and slot("pending").get("ota_id", "") == id:
		if slot("current").get("ota_id", "") != id:
			state["previous"] = slot("current")
		state["current"] = slot("pending")
		state["pending"] = {}
	event("health", "healthy: %s" % (id if id != "" else "bundled baseline"))
	_prune()
	save_state()


## CURRENT goes back to PREVIOUS on the next start; the abandoned OTA is not re-downloaded.
func rollback() -> String:
	var prev := slot("previous")
	var cur := slot("current")
	if cur.is_empty():
		return "no OTA to roll back from"
	if not prev.is_empty():
		var why := save_compat(prev)
		if why != "":
			return why
	if not is_bad(cur["ota_id"]):
		(state["bad"] as Array).append(cur["ota_id"])
	state["current"] = prev
	state["previous"] = {}
	state["pending"] = {}
	state["ready"] = {}
	state["rollback_count"] = int(state["rollback_count"]) + 1
	event("rollback", "rolled back from %s to %s on next start" % [cur["ota_id"], prev.get("ota_id", "bundled baseline")])
	save_state()
	return ""


func set_disabled(on: bool) -> void:
	state["disabled"] = on
	event("baseline", "OTA disabled: next start uses the bundled baseline" if on else "OTA re-enabled")
	save_state()


## Remove packages no slot refers to (never the active one).
func _prune() -> void:
	var keep := {}
	for s in ["current", "previous", "pending", "ready"]:
		var id: String = slot(s).get("ota_id", "")
		if id != "":
			keep[id] = true
	keep[active.get("ota_id", "")] = true
	for f in DirAccess.get_files_at(root.path_join("packages")):
		if f.begins_with(".incoming-"):
			DirAccess.remove_absolute(root.path_join("packages").path_join(f))
		elif f.ends_with(".pck") and not keep.has(f.get_basename()):
			DirAccess.remove_absolute(root.path_join("packages").path_join(f))
