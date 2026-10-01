extends RefCounted
## GAME LAYER — runs a newly downloaded OTA without an app restart ("soft restart").
##
## Runtime r5 (Android build 22) only mounts a package in Boot._init, so a downloaded update used
## to wait for a cold start. This does the same thing in-process, using only what the r5 native
## layer already exposes:
##   1. the native layer mounts the package itself: Boot.core.boot() re-selects PENDING, re-checks
##      its signed manifest, runtime, size and SHA-256, counts the start BEFORE mounting (so a
##      crash still counts towards MAX_UNHEALTHY_STARTS) and mounts with
##      ProjectSettings.load_resource_pack(path, true) exactly as Boot._init does;
##   2. the game layer is torn down (main scene and any other game nodes; the Settings autoload is
##      detached from its script), every cached game-layer script is recompiled IN PLACE from the
##      new pack (GDScriptCache re-reads a script loaded with CACHE_MODE_IGNORE), and cached
##      resources are re-read from the new pack (CACHE_MODE_REPLACE, leaves first);
##   3. Settings gets the new settings.gd, the boot-health checkpoint is re-armed (the new game
##      must report ready and survive Boot.HEALTHY_AFTER_MS again before the native layer moves
##      PENDING to CURRENT), and the main scene is loaded again from the new pack.
## Native scripts (scripts/boot/, the generated build info) are never reloaded: the running APK's
## versions stay in charge whatever a pack contains.
##
## No script with live instances is ever recompiled (debug and release templates handle that
## differently), and nothing below the point of no return runs from a frame of a game-layer
## script other than this one, which recompiles itself last, from a native deferred call.
##
## Every step before the point of no return can fail without effect: the game simply keeps
## running. After it (scripts recompiled), a failure re-mounts the package that was running and
## recompiles back to it. Each OTA id is attempted at most once per install (record file).

const SELF_PATH := "res://scripts/core/soft_restart.gd"
const SETTINGS_PATH := "res://scripts/core/settings.gd"
const TRACE_PATH := "res://scripts/core/startup_trace.gd"
const GILL_LOOK_PATH := "res://scripts/actors/gill_look.gd"
## Never recompiled: the native layer and its generated build info belong to the APK.
const NATIVE_PREFIXES := ["res://scripts/boot/", "res://scripts/generated/"]
const CURTAIN_NAME := "AutoUpdateCurtain"
## Engine metadata (survives scene changes and script reloads) describing the last soft restart
## of this process: {from, to, where, usec, scripts, resources, note}.
const META := "mote_soft_restart"
const RECORD_PATH := "user://ota_autoupdate.json"
const RECORD_KEEP := 20
## Set by tests to keep the player's record untouched.
static var record_path := RECORD_PATH


# --- record (once per OTA id; reasons for Diagnostics) ---------------------------------------

static func record_read() -> Dictionary:
	var d := {"attempts": {}, "order": [], "last": {}}
	if FileAccess.file_exists(record_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(record_path))
		if parsed is Dictionary:
			for k in d:
				if (parsed as Dictionary).has(k) and typeof(parsed[k]) == typeof(d[k]):
					d[k] = parsed[k]
	return d


static func _record_write(d: Dictionary) -> void:
	var tmp := record_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(d, "  ", true))
	f.close()
	DirAccess.rename_absolute(tmp, record_path)


static func was_attempted(ota_id: String) -> bool:
	return (record_read()["attempts"] as Dictionary).has(ota_id)


## Written BEFORE anything is changed, so a crash during the attempt still prevents a retry.
static func record_attempt(ota_id: String, from_id: String, where: String) -> void:
	var d := record_read()
	var e := {"from": from_id if from_id != "" else "bundled baseline", "where": where,
			"time": Time.get_datetime_string_from_system(true) + "Z", "result": "started"}
	(d["attempts"] as Dictionary)[ota_id] = e
	var order: Array = d["order"]
	order.erase(ota_id)
	order.append(ota_id)
	while order.size() > RECORD_KEEP:
		(d["attempts"] as Dictionary).erase(order.pop_front())
	d["last"] = e.merged({"ota_id": ota_id})
	_record_write(d)


static func record_result(ota_id: String, result: String) -> void:
	var d := record_read()
	var a: Dictionary = d["attempts"]
	if a.has(ota_id):
		(a[ota_id] as Dictionary)["result"] = result
	if str((d["last"] as Dictionary).get("ota_id", "")) == ota_id:
		(d["last"] as Dictionary)["result"] = result
	_record_write(d)
	print("[AUTOUPDATE] %s: %s" % [ota_id, result])


# --- helpers (dynamic calls only: the classes they reach may have just been recompiled) ------

static func _mark(label: String) -> void:
	var tr: Script = load(TRACE_PATH)
	if tr != null and tr.has_method("mark"):
		tr.call("mark", label)
	else:
		print("[STARTUP] ", label)


static func _wait_workers() -> void:
	var gl: Script = load(GILL_LOOK_PATH) if ResourceLoader.exists(GILL_LOOK_PATH) else null
	if gl != null and gl.has_method("wait_idle"):
		gl.call("wait_idle")


static func _boot_log_since(core, n: int) -> void:
	var log: Array = core.boot_log
	for i in range(n, log.size()):
		print("[OTA] ", log[i])


## Every game-layer script and resource below `dir`, as resource paths (remaps resolved).
static func _walk(dir: String, scripts: Array[String], others: Array[String]) -> void:
	for f in ResourceLoader.list_directory(dir):
		if f.ends_with("/"):
			if not f.begins_with("."):
				_walk(dir.path_join(f.trim_suffix("/")), scripts, others)
		elif f.get_extension() == "gd":
			scripts.append(dir.path_join(f))
		else:
			others.append(dir.path_join(f))


static func is_native(path: String) -> bool:
	for p in NATIVE_PREFIXES:
		if path.begins_with(p):
			return true
	return false


## Re-reads every CACHED game-layer resource and script from whatever is mounted now.
## Resources first (so preload() constants pick up the new files), then scripts twice: the
## first pass reads the new code in place, the second recompiles everything against the new
## code of everything else and collects real errors. Returns {scripts, resources, errors}.
## (`under` limits it to one directory: tests.)
static func reload_game_layer(skip: Array = [], under := "res://") -> Dictionary:
	var scripts: Array[String] = []
	var others: Array[String] = []
	_walk(under, scripts, others)
	var n_res := 0
	var cached: Array[String] = []
	for p in others:
		if not is_native(p) and ResourceLoader.has_cached(p):
			cached.append(p)
	# Leaves first (shader includes, textures, audio), then what refers to them (shaders, materials,
	# meshes, scenes), so each reload finds its dependencies already re-read.
	cached.sort_custom(func(a: String, b: String) -> bool: return _res_rank(a) < _res_rank(b) or (_res_rank(a) == _res_rank(b) and a < b))
	for p in cached:
		if p.get_extension() in ["gdshaderinc", "gdshader"]:
			# Shader code is updated in place on the cached object. (Re-loading an include with a
			# REPLACE mode makes the shaders that use it re-preprocess while that same include is
			# still being loaded, which fails as a circular load and logs a compile error.)
			var sh: Resource = ResourceLoader.load(p)
			var code := FileAccess.get_file_as_string(p)
			if sh != null and code != "" and sh.get("code") != code:
				sh.set("code", code)
		else:
			ResourceLoader.load(p, "", ResourceLoader.CACHE_MODE_REPLACE)
		n_res += 1
	var todo: Array[String] = []
	for p in scripts:
		if is_native(p) or p == SELF_PATH or skip.has(p) or not ResourceLoader.has_cached(p):
			continue
		todo.append(p)
	for p in todo:
		ResourceLoader.load(p, "", ResourceLoader.CACHE_MODE_IGNORE)
	var errors: Array[String] = []
	for p in todo:
		var s: Script = ResourceLoader.load(p)
		var err := s.reload(true) if s != null else ERR_CANT_OPEN
		if err != OK or not s.can_instantiate():
			errors.append("%s (%s)" % [p.get_file(), error_string(err)])
	return {"scripts": todo.size(), "resources": n_res, "errors": errors}


static func _res_rank(path: String) -> int:
	match path.get_extension():
		"gdshaderinc":
			return 0
		"gdshader", "shader":
			return 2
		"tres", "res":
			return 3
		"tscn", "scn":
			return 4
	return 1


## A plain-engine copy of Mote's loading screen (no game script, so it can stay up while every
## game script is recompiled). The new game's own loading screen takes over and removes it.
static func _curtain(tree: SceneTree, text: String) -> CanvasLayer:
	var old := tree.root.get_node_or_null(CURTAIN_NAME)
	if old != null:
		old.free()
	var c := CanvasLayer.new()
	c.name = CURTAIN_NAME
	c.layer = 101
	c.process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.1, 0.1, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	c.add_child(bg)
	var art := TextureRect.new()
	if ResourceLoader.exists("res://assets/icon/splash.png"):
		art.texture = load("res://assets/icon/splash.png")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.set_anchors_preset(Control.PRESET_CENTER)
	var win := DisplayServer.window_get_size()
	var sz := clampf(320.0 * tree.root.get_visible_rect().size.y / float(win.y), 150.0, 360.0) if win.y > 0 else 213.0
	art.offset_left = -sz / 2.0
	art.offset_right = sz / 2.0
	art.offset_top = -sz / 2.0
	art.offset_bottom = sz / 2.0
	bg.add_child(art)
	var title := Label.new()
	title.text = "MOTE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(0.98, 0.82, 0.86))
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.18, 0.16, 0.8))
	title.add_theme_constant_override("outline_size", 8)
	_band(title, -sz / 2.0 - 130.0, -sz / 2.0 - 16.0)
	bg.add_child(title)
	var status := Label.new()
	status.text = text
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 24)
	status.add_theme_color_override("font_color", Color(0.85, 0.95, 0.92, 0.75))
	_band(status, sz / 2.0 + 22.0, sz / 2.0 + 60.0)
	bg.add_child(status)
	tree.root.add_child(c)
	return c


static func _band(c: Control, top: float, bottom: float) -> void:
	c.anchor_left = 0.0
	c.anchor_right = 1.0
	c.anchor_top = 0.5
	c.anchor_bottom = 0.5
	c.offset_top = top
	c.offset_bottom = bottom


## Removes the curtain (called by the new game once its own loading screen is on screen).
static func lift_curtain() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var c := tree.root.get_node_or_null(CURTAIN_NAME) if tree != null else null
	if c != null:
		c.queue_free()


# --- the soft restart ----------------------------------------------------------------------

## Detaches the Settings autoload from its script (it keeps its node, name and place, so the
## global `Settings` stays valid) and removes it from the tree while scripts are recompiled.
static func _detach_settings(tree: SceneTree) -> Node:
	var st := tree.root.get_node_or_null("Settings")
	if st == null:
		return null
	for c in st.get_incoming_connections():
		var sig: Signal = c["signal"]
		if sig.is_connected(c["callable"]):
			sig.disconnect(c["callable"])
	tree.root.remove_child(st)
	st.set_script(null)
	return st


## Gives Settings the (now current) settings.gd and puts it back right after Boot, where the
## engine created it: _enter_tree and _ready run again and read the settings from disk.
static func _attach_settings(tree: SceneTree, st: Node) -> void:
	if st == null:
		return
	st.set_script(load(SETTINGS_PATH))
	st.request_ready()
	tree.root.add_child(st)
	var boot := tree.root.get_node_or_null("Boot")
	tree.root.move_child(st, boot.get_index() + 1 if boot != null else 0)


## Frees everything the game layer put under the root (the main scene and anything else),
## keeping only the native Boot, the Settings autoload and the curtain.
static func _free_game_nodes(tree: SceneTree, keep: Array) -> void:
	tree.unload_current_scene()
	for c in tree.root.get_children():
		if not keep.has(c):
			c.free()


## Applies the verified PENDING package `m` now. `where` names the moment ("launch", "title",
## "resume"). `save` (optional) saves the run and profile and returns "" or why it could not:
## nothing happens if it fails. Returns "" once the new game layer is on its way in, or the
## reason the current game keeps running (also recorded for Diagnostics).
static func apply(m: Dictionary, where: String, save := Callable()) -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var core = Boot.core
	var id: String = m.get("ota_id", "")
	var from: Dictionary = (core.active as Dictionary).duplicate(true)
	var from_id: String = from.get("ota_id", "")
	if save.is_valid():
		var why: String = save.call()
		if why != "":
			record_attempt(id, from_id, where)
			record_result(id, "not applied: progress could not be saved first (%s); still running %s" % [why, from_id if from_id != "" else "the bundled game"])
			return "progress could not be saved: " + why
	record_attempt(id, from_id, where)
	_mark("game: update %s: soft restart begins (%s)" % [id, where])
	var curtain := _curtain(tree, "Updating...")
	# Let every game-layer frame on the call stack finish before anything is torn down.
	await tree.process_frame
	_wait_workers()

	# 1. The native layer verifies and mounts the package (same code path as a cold start).
	var boot_before: Dictionary = (core.state["boot"] as Dictionary).duplicate(true)
	var log_n: int = core.boot_log.size()
	core.device_save_schema = Boot._device_save_schema()
	var picked: Dictionary = core.boot(func(path: String) -> bool: return ProjectSettings.load_resource_pack(path, true))
	_boot_log_since(core, log_n)
	if picked.get("ota_id", "") != id:
		# Not mounted (the native layer rejected it or the mount failed). It re-mounted at most the
		# package that is already running; the game below was never touched.
		core.active = from
		core.state["boot"] = boot_before
		core.save_state()
		curtain.queue_free()
		var said: Array = (core.boot_log as Array).slice(log_n)
		var why := "the native layer did not mount it (%s)" % ("; ".join(said) if not said.is_empty() else "no reason given")
		record_result(id, "not applied: %s; still running %s" % [why, from_id if from_id != "" else "the bundled game"])
		return why

	# 2. Point of no return: tear the old game layer down and recompile it from the new pack.
	var marks: Array = (load(TRACE_PATH).get("marks") as Array).duplicate()
	var settings := tree.root.get_node_or_null("Settings")
	_free_game_nodes(tree, [Boot, settings, curtain])
	tree.paused = false
	Engine.time_scale = 1.0
	await tree.process_frame
	_wait_workers()
	var st := _detach_settings(tree)
	var t0 := Time.get_ticks_usec()
	var r := reload_game_layer()
	var note := "%d scripts, %d resources re-read in %.0f ms" % [r["scripts"], r["resources"], (Time.get_ticks_usec() - t0) / 1000.0]
	var errors: Array = r["errors"]
	var result := ""
	if not errors.is_empty():
		# The new game layer does not compile here. Go back to what was running, if it can be
		# mounted again (an OTA package can; the bundled game is still underneath).
		result = "new game layer did not compile (%s)" % ", ".join(errors.slice(0, 4))
		# A package whose game layer cannot compile on this runtime is as unusable as one that
		# cannot be mounted: rejected like the native layer rejects those (never retried, never
		# re-downloaded; PENDING cleared, so no cold start runs it either).
		core.mark_bad(m, "game layer does not compile on this runtime (in-process update)")
		core.state["boot"] = boot_before
		core.save_state()
		if from_id != "" and ProjectSettings.load_resource_pack(core.package_path(from_id), true):
			core.active = from
			var back := reload_game_layer()
			result += "; returned to %s (%d errors)" % [from_id, (back["errors"] as Array).size()]
		elif from_id == "":
			core.active = {}
			result += "; the bundled game cannot be re-mounted in-process: continuing, the next start decides"
	_attach_settings(tree, st)
	var tr: Script = load(TRACE_PATH)
	if tr != null:
		tr.set("marks", marks)
	if result == "":
		_mark("game: soft restart: %s mounted, %s" % [id, note])
	else:
		_mark("game: soft restart into %s FAILED: %s" % [id, result])
	# 3. The new game must prove itself: re-arm the native boot-health checkpoint. PENDING becomes
	# CURRENT (and the old CURRENT becomes PREVIOUS) only when it reports ready and keeps running.
	Boot.healthy = false
	Boot.set("_ready_at", -1)
	Boot.set("_ready_frames", 0)
	Engine.set_meta(META, {"from": from_id, "to": core.active.get("ota_id", ""), "wanted": id, "where": where,
			"usec": Time.get_ticks_usec(), "scripts": r["scripts"], "resources": r["resources"], "note": note,
			"result": result, "announced": false})
	record_result(id, ("failed: " + result) if result != "" else "mounted in-process (%s, %s); new game layer starting" % [where, note])
	# This script last, from a native deferred call (none of its frames are on the stack by then),
	# then the main scene from the new pack.
	ResourceLoader.load.call_deferred(SELF_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	tree.change_scene_to_file.call_deferred(str(ProjectSettings.get_setting("application/run/main_scene")))
	# (The new loading screen lifts the curtain; this is only a backstop.)
	tree.create_timer(20.0, true).timeout.connect(curtain.queue_free)
	return ""
