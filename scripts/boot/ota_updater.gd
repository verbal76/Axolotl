extends Node
## NATIVE LAYER — HTTPS update client for one channel.
## pointer (latest.json) -> signed manifest -> PCK into a temporary file -> verify -> READY.
## Nothing here touches the package that is currently running, and nothing here blocks: every
## request is polled from the main loop without waiting on it, and every failure (no network, DNS, timeout, HTTP
## error, bad pointer/manifest/signature/runtime/hash) ends in a status, never in an exception.
## The game keeps running whatever it already runs.

signal finished(result: String)

var core
var pointer_url: String
var busy := false
## Seconds before a pointer/manifest request gives up (the package download gets longer).
var timeout := 15.0
var download_timeout := 900.0
## Last channel pointer seen (what is AVAILABLE — never what is running).
var remote: Dictionary = {}
## What the last check or download concluded, for Diagnostics:
## unchecked | checking | offline | up_to_date | available | downloading | downloaded |
## incompatible | rejected | failed
var status := "unchecked"
var status_detail := ""
## Whether the latest OTA on the channel can run on this app: "compatible", the reason it
## cannot, or "" when unknown.
var latest_compat := ""
var checked_at := ""
## Source commit of the game bundled in this APK. An OTA built from the same commit is the game
## already installed: while nothing newer is staged or running, it is reported as up to date
## instead of being downloaded again.
var bundled_source_sha := ""
var _available: Array = []   # [manifest_bytes, sig_b64, manifest] of a checked, unpulled update


func has_available() -> bool:
	return not _available.is_empty()


func _fetch(url: String, to_file := "", limit := -1, p_timeout := -1.0) -> Array:
	var req := HTTPRequest.new()
	req.timeout = p_timeout if p_timeout > 0.0 else timeout
	req.max_redirects = 8
	# Polled from the main loop, never blocking it (DNS, TLS and reads are all non-blocking).
	# Not threaded: in Godot 4.7.2 a threaded request to a server that accepts the connection
	# but never answers ignores `timeout` and stays busy forever (ota_hanging_server_does_not_block).
	req.use_threads = false
	req.download_chunk_size = 262144
	if to_file != "":
		req.download_file = to_file
		req.body_size_limit = limit
	add_child(req)
	var err := req.request(url)
	if err != OK:
		req.queue_free()
		return [false, "request error %d" % err, PackedByteArray()]
	var res: Array = await req.request_completed
	req.queue_free()
	if res[0] != HTTPRequest.RESULT_SUCCESS:
		return [false, "network result %d" % res[0], PackedByteArray()]
	if res[1] != 200:
		return [false, "HTTP %d" % res[1], PackedByteArray()]
	return [true, "", res[3]]


func _done(kind: String, result: String, p_status: String) -> String:
	status = p_status
	status_detail = result
	core.event(kind, result)
	core.save_state()
	busy = false
	finished.emit(result)
	return result


## Checks the channel; downloads and verifies the update when `download` is true.
func check(download := true) -> String:
	if busy:
		return "busy"
	busy = true
	status = "checking"
	_available = []
	checked_at = Time.get_datetime_string_from_system(true) + "Z"
	var p: Array = await _fetch(pointer_url + "?t=%d" % Time.get_unix_time_from_system())
	if not p[0]:
		return _done("check", "channel unreachable (%s); keeping current package" % p[1], "offline")
	var ptr: Variant = JSON.parse_string((p[2] as PackedByteArray).get_string_from_utf8())
	if not ptr is Dictionary or not (ptr as Dictionary).has_all(["ota_id", "seq", "manifest_url", "signature_url", "channel"]):
		return _done("check", "invalid channel pointer; keeping current package", "failed")
	remote = ptr
	latest_compat = ""
	if remote["channel"] != core.channel:
		return _done("check", "pointer is for channel '%s'" % remote["channel"], "failed")
	if core.is_bad(remote["ota_id"]):
		return _done("check", "latest is %s, which was rejected or rolled back here; not re-downloading" % remote["ota_id"], "rejected")
	if int(remote["seq"]) <= core.known_seq():
		latest_compat = "compatible"
		return _done("check", "up to date (latest %s)" % remote["ota_id"], "up_to_date")
	var mb: Array = await _fetch(remote["manifest_url"])
	var sb: Array = await _fetch(remote["signature_url"])
	if not (mb[0] and sb[0]):
		return _done("check", "manifest download failed (%s%s); keeping current package" % [mb[1], sb[1]], "offline")
	var sig := (sb[2] as PackedByteArray).get_string_from_utf8()
	var res: Array = core.check_manifest(mb[2], sig)
	if res[1] != "":
		var why: String = res[1]
		var incompatible := why.begins_with("native update required") or why.begins_with("incompatible runtime") or why.begins_with("save incompatible")
		latest_compat = why
		return _done("check", "%s %s: %s" % ["cannot use" if incompatible else "rejected", remote["ota_id"], why], "incompatible" if incompatible else "rejected")
	var m: Dictionary = res[0]
	if m["ota_id"] != remote["ota_id"]:
		return _done("check", "pointer/manifest mismatch (%s vs %s)" % [remote["ota_id"], m["ota_id"]], "rejected")
	latest_compat = "compatible"
	if bundled_source_sha != "" and str(m["source_sha"]) == bundled_source_sha and core.active.is_empty() \
			and core.slot("pending").is_empty() and core.slot("ready").is_empty():
		return _done("check", "up to date (latest %s is the game bundled in this app, %s)" % [m["ota_id"], bundled_source_sha.left(12)], "up_to_date")
	_available = [mb[2], sig, m]
	core.event("check", "update available: %s (game %s, %s)" % [m["ota_id"], m["game_version"], str(m["source_sha"]).left(12)])
	status = "available"
	status_detail = "update available: %s" % m["ota_id"]
	if not download:
		core.save_state()
		busy = false
		finished.emit("available")
		return "available"
	busy = false
	return await download_available()


func download_available() -> String:
	if busy:
		return "busy"
	if _available.is_empty():
		return "nothing to download: check first"
	busy = true
	status = "downloading"
	var m: Dictionary = _available[2]
	var id: String = m["ota_id"]
	var tmp: String = core.incoming_path(id)
	DirAccess.remove_absolute(tmp)
	var d: Array = await _fetch(m["pck_url"], tmp, int(m["pck_size"]) + 1, download_timeout)
	if not d[0]:
		DirAccess.remove_absolute(tmp)
		# Still available: a later check or the Download button can try again.
		return _done("download", "download of %s failed (%s); incomplete file deleted, keeping current package" % [id, d[1]], "failed")
	core.event("download", "downloaded %s" % id)
	var why: String = core.stage_incoming(_available[0], _available[1])
	_available = []
	if why != "":
		return _done("download", "rejected %s: %s" % [id, why], "rejected")
	var msg := ("%s ready: restart to run it" % id) if not core.slot("pending").is_empty() else ("%s downloaded: activate on restart when ready" % id)
	return _done("download", msg, "downloaded")
