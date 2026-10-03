class_name StartupTrace
extends RefCounted
## Startup milestones, from process start to the first usable screen, for Diagnostics, the
## Android log ("[STARTUP]") and the startup probe/tests. Times are milliseconds on the engine
## clock (Time.get_ticks_usec, zero when the engine starts); the gap between the process starting
## and the engine clock starting is read from /proc on Linux and Android.

## [label, usec on the engine clock]
static var marks: Array = []
## Engine clock zero, measured from process start (ms); -1 when the platform cannot say.
static var process_offset_ms := -1.0
static var _probe := false


static func mark(label: String) -> void:
	if marks.is_empty():
		process_offset_ms = _engine_start_after_process_ms()
		_probe = OS.get_cmdline_user_args().has("--startup-probe")
	var t := Time.get_ticks_usec()
	marks.append([label, t])
	if _probe:
		# (Startup probe only: this thread's own CPU time and its time kept waiting for a CPU, so a
		# measurement on a busy machine still shows the main thread's work; and the whole process's
		# CPU time, in 10 ms ticks.)
		var ss := _read_line("/proc/thread-self/schedstat").split(" ")
		var cpu := float(ss[0]) / 1e6 if ss.size() > 1 else -1.0
		var wait := float(ss[1]) / 1e6 if ss.size() > 1 else -1.0
		var st := _read_line("/proc/self/stat")
		var f := st.substr(st.rfind(")") + 2).split(" ") if st.contains(")") else PackedStringArray()
		var all := (float(f[11]) + float(f[12])) * 10.0 if f.size() > 12 else -1.0
		print("[STARTUP] %9.1f ms  %s  {main cpu %.1f ms, runqueue wait %.1f ms, all threads cpu %.0f ms}" % [t / 1000.0, label, cpu, wait, all])
	else:
		print("[STARTUP] %9.1f ms  %s" % [t / 1000.0, label])


## Marks `label` when the frame currently being prepared has been drawn.
static func mark_next_frame(label: String) -> void:
	RenderingServer.frame_post_draw.connect(func() -> void: mark(label), CONNECT_ONE_SHOT)


## Engine-clock milliseconds of the first mark named `label`, or -1.
static func ms(label: String) -> float:
	for m in marks:
		if m[0] == label:
			return m[1] / 1000.0
	return -1.0


static func has(label: String) -> bool:
	return ms(label) >= 0.0


## Every milestone, native (from the bootstrap, when it records them) and game layer, in order.
static func timeline(native: Array = []) -> Array:
	var all := native.duplicate()
	all.append_array(marks)
	all.sort_custom(func(a, b) -> bool: return a[1] < b[1])
	return all


## One line for the pause menu: when Mote first showed something, and when it was usable,
## counted from the app process starting (or from the engine starting where that is unknown).
static func summary() -> String:
	var shown := ms("first frame drawn: Mote loading screen visible")
	var usable := maxf(ms("first frame drawn: title usable"), ms("first frame drawn: play usable"))
	if shown < 0.0 or usable < 0.0:
		return ""
	var base := maxf(process_offset_ms, 0.0)
	return "Last launch: Mote on screen after %.1f s, ready after %.1f s (%s)" % [(base + shown) / 1000.0,
			(base + usable) / 1000.0, "from app start" if process_offset_ms >= 0.0 else "from engine start"]


## Called by the bootstrap's Diagnostics for the "Startup" section. It is the one game-layer text
## hook runtime r5's Diagnostics has, so it also carries the game's own diagnostic sections
## (run timer & completion) after the timeline.
static func timeline_text(native: Array = []) -> String:
	var L: Array[String] = []
	if process_offset_ms >= 0.0:
		L.append("  %9.0f ms  process started (Android/native startup before the engine clock)" % -process_offset_ms)
	for m in timeline(native):
		L.append("  %9.1f ms  %s" % [m[1] / 1000.0, m[0]])
	# Found by group, not by class, so this file never depends on the game scripts compiling.
	var tree := Engine.get_main_loop() as SceneTree
	var g: Node = tree.get_first_node_in_group("mote_game") if tree != null else null
	if g != null and g.has_method("run_diagnostics_text") and g.get("run_save") != null:
		L.append("")
		L.append(g.run_diagnostics_text())
	return "\n".join(L)


## Process age minus engine clock: how long after the process started the engine clock began.
static func _engine_start_after_process_ms() -> float:
	var stat := _read_line("/proc/self/stat")
	var up := _read_line("/proc/uptime")
	if stat == "" or up == "" or not stat.contains(")"):
		return -1.0
	# Fields after "(comm)": index 0 is field 3 (state); starttime is field 22 (clock ticks, 100/s).
	var f := stat.substr(stat.rfind(")") + 2).split(" ")
	if f.size() < 20:
		return -1.0
	var age_ms := (float(up.split(" ")[0]) - float(f[19]) / 100.0) * 1000.0
	return maxf(0.0, age_ms - Time.get_ticks_usec() / 1000.0)


static func _read_line(path: String) -> String:
	var fa := FileAccess.open(path, FileAccess.READ)
	return fa.get_line() if fa != null else ""
