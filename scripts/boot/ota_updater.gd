extends Node
## NATIVE LAYER — HTTPS update client for one channel.
## pointer (latest.json) -> signed manifest -> PCK into a temporary file -> verify -> READY.
## Nothing here touches the package that is currently running.

signal finished(result: String)

var core
var pointer_url: String
var busy := false
## Last channel pointer seen (what is AVAILABLE — never what is running).
var remote: Dictionary = {}
var _available: Array = []   # [manifest_bytes, sig_b64, manifest] of a checked, unpulled update


func _fetch(url: String, to_file := "", limit := -1, timeout := 30.0) -> Array:
	var req := HTTPRequest.new()
	req.timeout = timeout
	req.max_redirects = 8
	req.use_threads = true
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


func _done(kind: String, result: String) -> String:
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
	_available = []
	var p: Array = await _fetch(pointer_url + "?t=%d" % Time.get_unix_time_from_system())
	if not p[0]:
		return _done("check", "channel unreachable (%s); keeping current package" % p[1])
	var ptr: Variant = JSON.parse_string((p[2] as PackedByteArray).get_string_from_utf8())
	if not ptr is Dictionary or not (ptr as Dictionary).has_all(["ota_id", "seq", "manifest_url", "signature_url", "channel"]):
		return _done("check", "invalid channel pointer")
	remote = ptr
	if remote["channel"] != core.channel:
		return _done("check", "pointer is for channel '%s'" % remote["channel"])
	if core.is_bad(remote["ota_id"]):
		return _done("check", "latest is %s, which was rejected or rolled back here; not re-downloading" % remote["ota_id"])
	if int(remote["seq"]) <= core.known_seq():
		return _done("check", "up to date (latest %s)" % remote["ota_id"])
	var mb: Array = await _fetch(remote["manifest_url"])
	var sb: Array = await _fetch(remote["signature_url"])
	if not (mb[0] and sb[0]):
		return _done("check", "manifest download failed (%s%s); keeping current package" % [mb[1], sb[1]])
	var sig := (sb[2] as PackedByteArray).get_string_from_utf8()
	var res: Array = core.check_manifest(mb[2], sig)
	if res[1] != "":
		return _done("check", "rejected %s: %s" % [remote["ota_id"], res[1]])
	var m: Dictionary = res[0]
	if m["ota_id"] != remote["ota_id"]:
		return _done("check", "pointer/manifest mismatch (%s vs %s)" % [remote["ota_id"], m["ota_id"]])
	_available = [mb[2], sig, m]
	core.event("check", "update available: %s (game %s, %s)" % [m["ota_id"], m["game_version"], str(m["source_sha"]).left(12)])
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
	var m: Dictionary = _available[2]
	var id: String = m["ota_id"]
	var tmp: String = core.incoming_path(id)
	DirAccess.remove_absolute(tmp)
	var d: Array = await _fetch(m["pck_url"], tmp, int(m["pck_size"]) + 1, 900.0)
	if not d[0]:
		DirAccess.remove_absolute(tmp)
		return _done("download", "download of %s failed (%s); incomplete file deleted" % [id, d[1]])
	core.event("download", "downloaded %s" % id)
	var why: String = core.stage_incoming(_available[0], _available[1])
	_available = []
	if why != "":
		return _done("download", "rejected %s: %s" % [id, why])
	var msg := ("%s ready: restart to run it" % id) if not core.slot("pending").is_empty() else ("%s downloaded: activate on restart when ready" % id)
	return _done("download", msg)
