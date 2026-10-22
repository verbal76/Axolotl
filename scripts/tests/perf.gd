extends RefCounted
## CPU cost breakdown (not run by the unit suite). Modes (`--perf=...`); every mode measures play
## unless `--state=title` (the title orbit round him) is given, except `title` and `play`, which name
## their scene:
##   balls (default)  per-ball baseline with categories of nodes toggled off
##   title | play     the whole frame's spread (median/p95/worst), slowest frames, and each script's
##                    cost (its nodes switched off one group at a time; `--groups=direct` times each
##                    group's own work by hand instead, `--groups=0` skips it)
##   nodes            per-node cost of the many-instance scripts, by ball / near-far / state
##   parasite         one awake grazing parasite's update split into its parts
##   gamesteps        Game's own per-frame steps
##   veg              vegetation triangles the renderer draws from the current view
##   render           render-side split (needs a display: xvfb + vulkan)
##   probe            known periodic work (horizon cull)
##   selftest         proves the by-hand timings leave the world unchanged (see "By-hand timing")

var t


func _avg(n: int) -> Array:
	await t.frames(5)
	var t0 := Time.get_ticks_usec()
	await t.frames(n)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / n
	return [ms, 0.0]


func _toggle(nodes: Array, on: bool) -> void:
	for n in nodes:
		if is_instance_valid(n):
			n.set_physics_process(on)


func run(runner) -> void:
	t = runner
	var mode := str(Settings.test_args.get("perf", "balls"))
	if mode == "selftest":
		await _selftest()
		return
	if mode in ["gamesteps", "parasite", "veg", "nodes"]:
		await _enter_scene()
		match mode:
			"gamesteps":
				_game_steps()
			"parasite":
				_parasite_parts()
			"veg":
				_veg_budget()
			"nodes":
				_nodes()
		return
	if mode == "render":
		await _render_split()
		return
	if mode == "probe":
		await _probe()
		return
	if mode == "title" or mode == "play":
		await _run_state(mode)
		return
	var g: Game = t.g
	for bi in 3:
		var b := g.balls[bi]
		g.player.place(b, b.surface_point(MossBall.dir_ll(10, 30), 0.2), Vector3.FORWARD)
		g.cam.snap_behind()
		await t.seconds(1.0)
		var base: Array = await _avg(120)
		t.log_line("ball %d baseline: %.2f ms per frame (whole engine, headless)" % [bi + 1, base[0]])
		var groups := {"parasites": [], "foods": [], "motes": [], "platforms": [], "player": [g.player]}
		for bb in g.balls:
			groups["parasites"].append_array(bb.parasites)
			groups["foods"].append_array(bb.foods)
			groups["motes"].append_array(bb.motes)
			groups["platforms"].append_array(bb.crumbles + bb.flex_leaves)
			for c in bb.get_meta("builder").root.get_children():
				if c is Platforms.SwayLeaf:
					groups["platforms"].append(c)
		for k in groups:
			_toggle(groups[k], false)
			var r: Array = await _avg(90)
			_toggle(groups[k], true)
			t.log_line("  without %-9s %.2f ms (saves %.2f)" % [k, r[0], base[0] - r[0]])


# --- Title / play frame budget ---------------------------------------------------------------

## Per-frame wall time (one process frame, headless --fixed-fps 60: one physics tick each) and
## the main thread's CPU time, over `n` frames.
func _sample(n: int) -> Dictionary:
	var tree: SceneTree = t.get_tree()
	await tree.process_frame
	var ms := PackedFloat32Array()
	var cpu0 := _main_cpu_ns()
	var last := Time.get_ticks_usec()
	for i in n:
		await tree.process_frame
		var now := Time.get_ticks_usec()
		ms.append((now - last) / 1000.0)
		last = now
	var s := ms.duplicate()
	s.sort()
	var total := 0.0
	for v in ms:
		total += v
	# The heaviest phase of an 8-frame cycle (the title's slowest frames fall every 8th frame), as
	# its mean over the other phases' mean.
	var ph := PackedFloat32Array()
	ph.resize(8)
	for i in n:
		ph[i % 8] += ms[i] / (n / 8.0)
	var top := 0
	for k in 8:
		if ph[k] > ph[top]:
			top = k
	var rest := 0.0
	for k in 8:
		if k != top:
			rest += ph[k] / 7.0
	return {"draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			"prims": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), "ms": ms, "p8": ph[top] - rest, "mean": total / n, "median": s[n / 2], "p95": s[int(n * 0.95)], "worst": s[n - 1],
			"cpu": (_main_cpu_ns() - cpu0) / 1e6 / n}


## The main thread's own CPU time so far (Linux schedstat, ns): unlike wall time it does not count
## waiting for a core the other processes on a shared machine are using.
func _main_cpu_ns() -> float:
	var f := FileAccess.open("/proc/%d/schedstat" % OS.get_process_id(), FileAccess.READ)
	if f == null:
		return 0.0
	return float(f.get_line().get_slice(" ", 0))


func _line(r: Dictionary) -> String:
	return "main-thread cpu %.2f ms/frame | wall mean %.2f ms, median %.2f, p95 %.2f, worst %.2f, 8-frame spike +%.2f" % [r["cpu"],
			r["mean"], r["median"], r["p95"], r["worst"], r["p8"]]


## Nodes doing per-frame work, grouped by script file (scriptless nodes by class).
func _groups() -> Dictionary:
	var out := {}
	var stack: Array[Node] = [t.get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n == t or not (n.is_processing() or n.is_physics_processing()):
			continue
		var s: Script = n.get_script()
		var key: String = s.resource_path.get_file() if s != null and s.resource_path != "" else n.get_class()
		if s != null and s.resource_path == "":
			key = "inner:" + n.get_class()
		if not out.has(key):
			out[key] = []
		out[key].append(n)
	return out


func _run_state(mode: String) -> void:
	var g: Game = t.g
	var n := int(Settings.test_args.get("frames", "600"))
	if mode == "title":
		g.player.velocity = Vector3.ZERO
		g._enter_title()
	await t.seconds(3.0)
	var base: Dictionary = await _sample(n)
	t.log_line("PERF %s baseline: %s, %d nodes" % [mode, _line(base), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	if DisplayServer.get_name() != "headless":
		t.log_line("PERF %s render: %d draw calls, %d objects, %d primitives, video mem %.0f MB" % [mode,
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
	var worst: Array = []
	var ms: PackedFloat32Array = base["ms"]
	for i in ms.size():
		worst.append([ms[i], i])
	worst.sort_custom(func(a, b): return a[0] > b[0])
	t.log_line("PERF %s slowest frames: %s" % [mode, ", ".join(worst.slice(0, 12).map(func(w): return "#%d %.1f" % [w[1], w[0]]))])
	if Settings.test_args.get("groups", "1") == "0":
		return
	var groups := _groups()
	if Settings.test_args.get("groups", "1") == "direct":
		await _direct(mode, groups)
		return
	var rows: Array = []
	# Each group is switched off and on in turn (3 pairs of 60 frames): the saving is the median of
	# the pairs' differences, so slow drift and other processes' load mostly cancel.
	for k in groups:
		var nodes: Array = groups[k]
		var was: Array = []
		for nd in nodes:
			was.append([nd.is_processing(), nd.is_physics_processing()])
		var diffs: Array = []
		var p8 := 0.0
		for rep in 3:
			var on: Dictionary = await _sample(60)
			for nd in nodes:
				if is_instance_valid(nd):
					nd.set_process(false)
					nd.set_physics_process(false)
			var off: Dictionary = await _sample(60)
			p8 += off["p8"] / 3.0
			for q in nodes.size():
				if is_instance_valid(nodes[q]):
					nodes[q].set_process(was[q][0])
					nodes[q].set_physics_process(was[q][1])
			diffs.append(on["cpu"] - off["cpu"])
		diffs.sort()
		rows.append([diffs[1], k, nodes.size(), diffs, p8])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	for row in rows:
		t.log_line("PERF %s  %-28s x%-4d saves %6.2f ms cpu (pairs %s; 8-frame spike %.2f -> %.2f)" % [mode, row[1], row[2], row[0],
				", ".join(row[3].map(func(d): return "%.2f" % d)), base["p8"], row[4]])


# --- By-hand timing that leaves the world as it found it ------------------------------------------
#
# Methodology (2026-10-22, replaces the timings of d34a62c and the older --groups=direct, whose
# numbers are not comparable with these): a node's _physics_process/_process (or one of its parts)
# is called by hand, but only inside ONE engine frame (no awaits), from a snapshot of every node the
# call could touch, which is put back after each call. So:
#   - nothing simulates on between samples: every repetition starts from the same state, and the
#     label a node is reported under (its state, near/far, which ball) is the state it was timed in;
#   - the world after a measurement equals the world before it (`--perf=selftest` proves it with an
#     independent fingerprint), so measuring one group never disturbs the next;
#   - no node can be freed mid-measurement (queue_free runs only at the end of a frame); a node whose
#     own call queues itself for deletion is reported and its timing dropped.
# A snapshot holds a node's script variables (arrays and dictionaries copied deeply, random number
# generators by state, script helper objects such as OrganicMotion one level down), its transform
# and processing flags, its descendants' transforms, plus Gill's, Game's and the run clock's script
# variables and the few static variables a call can change (Parasite._last_commit, ParasiteGlob.live,
# Mote.magnet_calls). Restoring writes back only what changed. Not restored: sounds a call starts and
# shader parameters it sets (visual only; the next real frame sets them again).

const SNAP_DEPTH := 2


func _copy(v: Variant) -> Variant:
	var ty := typeof(v)
	if ty == TYPE_ARRAY or ty == TYPE_DICTIONARY:
		return v.duplicate(true)
	if ty >= TYPE_PACKED_BYTE_ARRAY and ty <= TYPE_PACKED_VECTOR4_ARRAY:
		return v.duplicate()
	return v


func _snap(o: Object, children := true, depth := 0) -> Dictionary:
	var vars := {}
	var objs := {}
	for pr in o.get_property_list():
		if not (int(pr["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var k: String = pr["name"]
		var v: Variant = o.get(k)
		vars[k] = _copy(v)
		if typeof(v) == TYPE_OBJECT and not is_instance_valid(v):
			continue   # (a reference to something already freed: kept as is)
		if v is RandomNumberGenerator:
			objs[k] = ["rng", v, (v as RandomNumberGenerator).state]
		elif v is Object and is_instance_valid(v) and not (v is Node) and not (v is Resource) \
				and (v as Object).get_script() != null and depth < SNAP_DEPTH:
			objs[k] = ["obj", v, _snap(v, false, depth + 1)]
	var s := {"o": o, "vars": vars, "objs": objs}
	if o is Node:
		var nd: Node = o
		s["proc"] = [nd.is_processing(), nd.is_physics_processing()]
		var xf := {}
		if nd is Node3D:
			xf[nd] = [(nd as Node3D).transform, (nd as Node3D).visible]
		if children:
			for d in nd.find_children("*", "Node3D", true, false):
				xf[d] = [(d as Node3D).transform, (d as Node3D).visible]
		s["xf"] = xf
	return s


func _restore(s: Dictionary) -> void:
	var o: Object = s["o"]
	if not is_instance_valid(o):
		return
	var vars: Dictionary = s["vars"]
	for k in vars:
		var want: Variant = vars[k]
		if typeof(want) == TYPE_OBJECT and want != null and not is_instance_valid(want):
			continue   # (it held something since freed: nothing to put back)
		var now: Variant = o.get(k)
		if typeof(now) != typeof(want) or now != want:
			o.set(k, _copy(want))
	for k in s["objs"]:
		var e: Array = s["objs"][k]
		if e[0] == "rng":
			(e[1] as RandomNumberGenerator).state = e[2]
		else:
			_restore(e[2])
	if s.has("proc"):
		var nd: Node = o
		if nd.is_processing() != s["proc"][0]:
			nd.set_process(s["proc"][0])
		if nd.is_physics_processing() != s["proc"][1]:
			nd.set_physics_process(s["proc"][1])
		var xf: Dictionary = s["xf"]
		for n3 in xf:
			if is_instance_valid(n3):
				if (n3 as Node3D).transform != xf[n3][0]:
					(n3 as Node3D).transform = xf[n3][0]
				if (n3 as Node3D).visible != xf[n3][1]:
					(n3 as Node3D).visible = xf[n3][1]


## Snapshot of everything a by-hand call on `nodes` can change: the nodes (with their descendants),
## Gill, Game, the run clock, every ball's own variables and the static variables named above.
func _ctx_snap(nodes: Array) -> Dictionary:
	var g: Game = t.g
	var snaps: Array = []
	for n in nodes:
		snaps.append(_snap(n))
	var shared: Array = [_snap(g.player), _snap(g, false), _snap(g.clock, false)]
	for b in g.balls:
		shared.append(_snap(b, false))
	return {"snaps": snaps, "shared": shared, "commit": Parasite._last_commit.duplicate(true),
			"globs": ParasiteGlob.live.duplicate(), "magnet": Mote.magnet_calls}


func _ctx_restore(ctx: Dictionary) -> void:
	for s in ctx["snaps"]:
		_restore(s)
	for s in ctx["shared"]:
		_restore(s)
	Parasite._last_commit = (ctx["commit"] as Dictionary).duplicate(true)
	Mote.magnet_calls = ctx["magnet"]
	# (A glob spat during a timing: freed, and the list put back.)
	for gl in ParasiteGlob.live.duplicate():
		if not (ctx["globs"] as Array).has(gl) and is_instance_valid(gl):
			gl.queue_free()
	ParasiteGlob.live.assign(ctx["globs"])


## One real frame's worth of a node's own work, as the engine would run it now.
func _frame_call(nd: Node) -> void:
	var dt := 1.0 / 60.0
	if nd.is_physics_processing() and nd.has_method("_physics_process"):
		nd._physics_process(dt)
	if nd.is_processing() and nd.has_method("_process"):
		nd._process(dt)


func _pct(sorted_us: PackedFloat64Array, q: float) -> float:
	return sorted_us[mini(sorted_us.size() - 1, int(sorted_us.size() * q))]


## Times `fn(node)` for each of `nodes` (`reps` calls each, every call from the same snapshot) and
## labels each node by `label_fn(node)` read before its first call. Synchronous: one engine frame.
## Returns {"rows": [[label, median_us, p90_us], ...], "skipped": invalid nodes, "freed": nodes
## whose own call queued them for deletion (dropped)}.
func _time_nodes(nodes: Array, reps: int, fn: Callable, label_fn: Callable) -> Dictionary:
	var live: Array = nodes.filter(func(n): return is_instance_valid(n) and not (n as Node).is_queued_for_deletion())
	var ctx := _ctx_snap(live)
	var rows: Array = []
	var freed := 0
	for i in live.size():
		var nd: Node = live[i]
		var label: String = label_fn.call(nd)
		var per := PackedFloat64Array()
		for r in reps:
			var t0 := Time.get_ticks_usec()
			fn.call(nd)
			per.append(Time.get_ticks_usec() - t0)
			if nd.is_queued_for_deletion():
				break
			_restore(ctx["snaps"][i])
		if nd.is_queued_for_deletion():
			freed += 1
		else:
			per.sort()
			rows.append([label, _pct(per, 0.5), _pct(per, 0.9)])
		_ctx_restore(ctx)
	return {"rows": rows, "skipped": nodes.size() - live.size(), "freed": freed}


## Times `fn()` (a whole group's frame, or one game step) `reps` times from one snapshot of `nodes`
## (plus the shared state), restoring after every call. Synchronous. Returns [median_us, p90_us].
func _time_frozen(nodes: Array, reps: int, fn: Callable) -> Array:
	var live: Array = nodes.filter(func(n): return is_instance_valid(n) and not (n as Node).is_queued_for_deletion())
	var ctx := _ctx_snap(live)
	var per := PackedFloat64Array()
	for r in reps:
		var t0 := Time.get_ticks_usec()
		fn.call()
		per.append(Time.get_ticks_usec() - t0)
		_ctx_restore(ctx)
	per.sort()
	return [_pct(per, 0.5), _pct(per, 0.9)]


## Starts the scene every by-hand mode measures: play by default, the title with `--state=title`.
func _enter_scene() -> String:
	var g: Game = t.g
	var st := str(Settings.test_args.get("state", "play"))
	if st == "title":
		g.player.velocity = Vector3.ZERO
		g._enter_title()
	await t.seconds(2.0)
	return st


## Each group's own per-frame work (`--groups=direct`): the whole group's frame from one frozen state,
## 30 times (medians).
func _direct(mode: String, groups: Dictionary) -> void:
	var rows: Array = []
	var total := 0.0
	for k in groups:
		var nodes: Array = groups[k]
		var r: Array = _time_frozen(nodes, 30, func():
			for nd in nodes:
				if is_instance_valid(nd):
					_frame_call(nd))
		rows.append([r[0] / 1000.0, k, nodes.size(), r[1] / 1000.0])
		total += r[0] / 1000.0
	rows.sort_custom(func(a, b): return a[0] > b[0])
	t.log_line("PERF %s direct (frozen): scripts' own per-frame work %.2f ms in all" % [mode, total])
	for row in rows:
		if row[0] >= 0.01:
			t.log_line("PERF %s  %-28s x%-4d %6.3f ms per frame (p90 %.3f)" % [mode, row[1], row[2], row[0], row[3]])


## A node's bucket: his ball or another, near him (Game.ACTIVE_RADIUS) or far, and its state.
func _bucket(nd: Node) -> String:
	var g: Game = t.g
	var same: bool = "ball" in nd and nd.ball == g.player.ball
	var near: bool = g.near_player((nd as Node3D).global_position)
	var st: String = str(nd.state) if "state" in nd else "-"
	return "%s ball, %s, %s" % ["his" if same else "other", "near" if near else "far", st]


const NODE_SCRIPTS := ["parasite.gd", "mote.gd", "food.gd", "bloom.gd", "starfish.gd"]


## Per-node cost of the many-instance scripts (`--perf=nodes`), summed by bucket so sleeping and
## awake instances show separately. Returns {script: {bucket: [count, total_us]}} (for selftest).
func _nodes(log_it := true) -> Dictionary:
	# (Synchronous: the whole sweep runs in one engine frame.)
	var groups := _groups()
	var out := {}
	for key in NODE_SCRIPTS:
		if not groups.has(key):
			continue
		var res := _time_nodes(groups[key], 30, _frame_call, _bucket)
		var buckets := {}
		for row in res["rows"]:
			if not buckets.has(row[0]):
				buckets[row[0]] = [0, 0.0]
			buckets[row[0]][0] += 1
			buckets[row[0]][1] += row[1]
		out[key] = buckets
		if log_it:
			for b in buckets:
				t.log_line("NODES %-14s %-34s x%-4d %.3f ms per frame (%.1f us each)" % [key, b, buckets[b][0], buckets[b][1] / 1000.0, buckets[b][1] / buckets[b][0]])
			if res["skipped"] > 0 or res["freed"] > 0:
				t.log_line("NODES %-14s skipped %d invalid, dropped %d that freed themselves" % [key, res["skipped"], res["freed"]])
	return out


## The parasites awake near him in `state`, by their state now.
func _awake_parasites(state: String) -> Array:
	var g: Game = t.g
	var out: Array = []
	for b in g.balls:
		for q in b.parasites:
			if is_instance_valid(q) and q.ball == g.player.ball and g.near_player(q.global_position) and q.state == state:
				out.append(q)
	return out


## One awake grazing parasite's update split into its parts (`--perf=parasite`), each part timed on
## every such parasite from the same frozen state (medians over them).
func _parasite_parts() -> void:
	var g: Game = t.g
	var dt := 1.0 / 60.0
	var awake := _awake_parasites("graze")
	var parts := {
		"whole _physics_process": func(q): q._physics_process(dt),
		"_update_segments": func(q): q._update_segments(dt),
		"  _push_body": func(q): q._push_body(),
		"_snap_ground (1 ray)": func(q): q._snap_ground(),
		"_ground_ahead (1 ray)": func(q): q._ground_ahead(q.global_position + q.heading * 0.3),
		"_wall_ahead (1 ray)": func(q): q._wall_ahead(q.heading * 0.05),
		"_ravine_ahead": func(q): q._ravine_ahead(q.heading * 0.05),
		"_express": func(q): q._express(dt, g.player),
		"set_look": func(q): q.set_look(q._gray, q._flash, q._windup_v),
		"_avoid_blooms": func(q): q._avoid_blooms(q.heading),
		"_angle_from_home": func(q): q._angle_from_home(q.global_position),
	}
	t.log_line("PARASITE %d awake grazing near him; seg_count %s" % [awake.size(), str(awake.map(func(q): return q.seg_count))])
	for k in parts:
		var res := _time_nodes(awake, 40, parts[k], func(q): return str(q.state))
		var med := PackedFloat64Array()
		for row in res["rows"]:
			med.append(row[1])
		med.sort()
		if med.is_empty():
			continue
		t.log_line("PARASITE %-24s %6.1f us each (median over %d; slowest %.1f)" % [k, _pct(med, 0.5), med.size(), med[med.size() - 1]])


## Whether the renderer draws `gi` for a camera at `cam` with `frustum` (Godot 4.7.2,
## servers/rendering/renderer_scene_cull.cpp): visible in the tree; its world-space AABB (world_aabb) not wholly
## outside a frustum plane; and the distance from the camera to that AABB's CENTRE inside its
## visibility range. With fading on, an instance is drawn (fading, at full triangle cost) out to
## end + end_margin and in to begin - begin_margin; with fading off the margin is hysteresis that
## depends on the previous frame, so the plain range is used.
## A MultiMesh's instance transforms (node-local). Read from the `veg_transforms` the game stores on
## every vegetation chunk (MossBall.fill_chunk: ball-local, the node standing at their centroid)
## when present, since the headless RenderingServer keeps no instance transforms (it reads back
## identity); otherwise read back from the MultiMesh (correct with a real renderer).
static func instance_xforms(mmi: MultiMeshInstance3D) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	if mmi.has_meta("veg_transforms"):
		for x: Transform3D in mmi.get_meta("veg_transforms"):
			out.append(Transform3D(x.basis, x.origin - mmi.position))
		return out
	var mm := mmi.multimesh
	for j in mm.instance_count:
		out.append(mm.get_instance_transform(j))
	return out


## The world-space bounds the renderer culls `gi` by: its custom AABB if set, else its mesh's or
## (MultiMesh) the union of every instance's mesh bounds, or the MultiMesh's own custom AABB. Built
## from the resources, not RenderingServer, whose MultiMesh bounds are empty in headless runs.
static func world_aabb(gi: GeometryInstance3D) -> AABB:
	var local := AABB()
	if gi.custom_aabb.has_volume():
		local = gi.custom_aabb
	elif gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh != null:
		var mm := (gi as MultiMeshInstance3D).multimesh
		var xs := instance_xforms(gi as MultiMeshInstance3D)
		if mm.custom_aabb.has_volume():
			local = mm.custom_aabb
		elif mm.mesh != null and not xs.is_empty():
			var m := mm.mesh.get_aabb()
			local = xs[0] * m
			for j in range(1, xs.size()):
				local = local.merge(xs[j] * m)
	elif gi is MeshInstance3D and (gi as MeshInstance3D).mesh != null:
		local = (gi as MeshInstance3D).mesh.get_aabb()
	return gi.global_transform * local


static func renderer_draws(gi: GeometryInstance3D, cam: Vector3, frustum: Array[Plane]) -> bool:
	if not gi.is_visible_in_tree():
		return false
	var aabb := world_aabb(gi)
	for pl in frustum:
		# (Outside if the whole box is in front of a plane: test the corner furthest behind it.)
		var far_pt := aabb.position + Vector3(aabb.size.x if pl.normal.x < 0.0 else 0.0, aabb.size.y if pl.normal.y < 0.0 else 0.0, aabb.size.z if pl.normal.z < 0.0 else 0.0)
		if pl.distance_to(far_pt) > 0.0:
			return false
	var d := cam.distance_to(aabb.get_center())
	var fade := gi.visibility_range_fade_mode != GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	var end_m := gi.visibility_range_end_margin if fade else 0.0
	var begin_m := gi.visibility_range_begin_margin if fade else 0.0
	if gi.visibility_range_end > 0.0 and d > gi.visibility_range_end + end_m:
		return false
	if gi.visibility_range_begin > 0.0 and d < gi.visibility_range_begin - begin_m:
		return false
	return true


## Vegetation triangles the camera's view draws (`--perf=veg`, play by default, `--state=title`):
## every vegetation instance under each ball's Vegetation node and its far-view copy (MultiMeshes
## and plain meshes, at any depth) that the renderer draws by `renderer_draws`, read as the game
## left it (its horizon cull is not re-run here), by plant mesh and by each instance's distance.
## Methodology change (2026-10-22): the d34a62c numbers used the node origin and ignored range
## begin and nested or far-view nodes; they are not comparable.
func _veg_budget() -> void:
	var g: Game = t.g
	var cam: Vector3 = g.get_viewport().get_camera_3d().global_position
	var frustum: Array[Plane] = g.get_viewport().get_camera_3d().get_frustum()
	t.log_line("VEG camera %s, player %.1f m away, state %s" % [str(cam), cam.distance_to(g.player.global_position), g.state])
	var bands := [10.0, 20.0, 30.0, 45.0, 60.0, 1e9]
	var by_mesh := {}
	var by_band := PackedFloat64Array()
	by_band.resize(bands.size())
	var total := 0.0
	var nodes_drawn := 0
	var tri_cache := {}
	var headless := DisplayServer.get_name() == "headless"
	var unplaced := 0
	for b in g.balls:
		var roots: Array[Node] = [b._veg_parent]
		if b.far_vegetation() != null:
			roots.append(b.far_vegetation())
		for root in roots:
			for c in root.find_children("*", "GeometryInstance3D", true, false):
				var gi: GeometryInstance3D = c
				var mesh: Mesh = null
				var xforms: Array[Transform3D] = []
				if gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh != null:
					mesh = (gi as MultiMeshInstance3D).multimesh.mesh
					xforms = instance_xforms(gi as MultiMeshInstance3D)
					if headless and not gi.has_meta("veg_transforms"):
						unplaced += 1
				elif gi is MeshInstance3D:
					mesh = (gi as MeshInstance3D).mesh
					xforms.append(Transform3D.IDENTITY)
				if mesh == null or not renderer_draws(gi, cam, frustum):
					continue
				nodes_drawn += 1
				if not tri_cache.has(mesh):
					tri_cache[mesh] = MossBall._mesh_tris(mesh)
				var tris: int = tri_cache[mesh]
				var mat: Material = gi.material_override
				var name: String = mesh.resource_name if mesh.resource_name != "" else ("%s/%s" % [mat.resource_name if mat else "?", str(mesh.get_aabb().size.snapped(Vector3.ONE * 0.01))])
				if not by_mesh.has(name):
					by_mesh[name] = [0.0, 0, tris]
				for x in xforms:
					var d := (gi.global_transform * x.origin).distance_to(cam)
					var k := 0
					while d > bands[k]:
						k += 1
					by_band[k] += tris
					by_mesh[name][0] += tris
					by_mesh[name][1] += 1
					total += tris
	t.log_line("VEG drawn vegetation: %.0f k triangles in %d nodes" % [total / 1000.0, nodes_drawn])
	if unplaced > 0:
		t.log_line("VEG   (%d MultiMeshes without stored transforms: headless, so placed at their node; run under xvfb for exact bands)" % unplaced)
	var lo := 0.0
	for k in bands.size():
		t.log_line("VEG   %5.0f-%-5s m: %7.1f k tris (%2.0f%%)" % [lo, ("%.0f" % bands[k]) if bands[k] < 1e8 else "far", by_band[k] / 1000.0, 100.0 * by_band[k] / maxf(total, 1.0)])
		lo = bands[k]
	var rows: Array = []
	for n in by_mesh:
		rows.append([by_mesh[n][0], n, by_mesh[n][1], by_mesh[n][2]])
	rows.sort_custom(func(a, b2): return a[0] > b2[0])
	for r in rows.slice(0, 18):
		t.log_line("VEG   %-26s %7.1f k tris  %6d instances x %4d tris" % [r[1], r[0] / 1000.0, r[2], r[3]])


# --- Self-test of the measurement method (`--perf=selftest`) -------------------------------------

## An independent fingerprint of the gameplay world (not built from the snapshots): every node doing
## per-frame work and Gill, by position, rotation and the gameplay fields it has, plus the run clock,
## Game's state, the static variables a call can touch and the node count.
func _fingerprint() -> Array:
	var g: Game = t.g
	var out: Array = [g.state, g.clock.run_s, Parasite._last_commit.duplicate(true), ParasiteGlob.live.size(),
			Mote.magnet_calls, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))]
	var nodes := _actor_nodes()
	nodes.append(g.player)
	for n in nodes:
		if not is_instance_valid(n):
			out.append("freed")
			continue
		var row: Array = [str(n.get_path())]
		if n is Node3D:
			row.append((n as Node3D).global_transform)
			row.append((n as Node3D).visible)
		for f in ["state", "state_t", "hp", "health", "velocity", "vel", "heading", "eaten", "active", "_alerted_t", "_graze_target"]:
			if f in n:
				row.append(n.get(f))
		if "_rng" in n and n.get("_rng") is RandomNumberGenerator:
			row.append((n.get("_rng") as RandomNumberGenerator).state)
		out.append(row)
	return out


func _first_diff(a: Array, b: Array) -> String:
	if a.size() != b.size():
		return "size %d -> %d" % [a.size(), b.size()]
	for i in a.size():
		if typeof(a[i]) != typeof(b[i]) or a[i] != b[i]:
			return "%s -> %s" % [str(a[i]).left(200), str(b[i]).left(200)]
	return ""


func _selftest() -> void:
	var g: Game = t.g
	await t.seconds(3.0)
	var groups := _groups()
	t.log_line("SELFTEST %d nodes doing per-frame work" % _actor_nodes().size())
	# (1) No by-hand mode changes the world: fingerprint before and after, in the same frame.
	for case in ["nodes", "parasite", "direct", "gamesteps"]:
		var f0 := _fingerprint()
		match case:
			"nodes":
				_nodes(false)
			"parasite":
				_parasite_parts()
			"direct":
				_direct("selftest", _groups())
			"gamesteps":
				_game_steps()
		var d := _first_diff(f0, _fingerprint())
		t.check("perf_%s_leaves_world_unchanged" % case, d == "", d)
	# (1b) The fingerprint does see mutation: the old method (calls with no restore) changes it.
	var awake := _awake_parasites("graze")
	var ctx0 := _ctx_snap(awake)
	var fa := _fingerprint()
	for q in awake:
		for r in 30:
			_frame_call(q)
	var moved := _first_diff(fa, _fingerprint())
	_ctx_restore(ctx0)
	t.check("perf_fingerprint_detects_mutation", awake.size() > 0 and moved != "" and _first_diff(fa, _fingerprint()) == "",
			"%d awake parasites; unrestored calls changed: %s" % [awake.size(), moved.left(160)])
	# (2) Labels: every node is reported under the state it was timed in, and is back in it afterwards.
	var labels_ok := true
	var detail := ""
	for key in NODE_SCRIPTS:
		if not groups.has(key):
			continue
		var before := {}
		for n in groups[key]:
			if is_instance_valid(n):
				before[n] = _bucket(n)
		var res := _time_nodes(groups[key], 5, _frame_call, _bucket)
		for n in before:
			if before[n] != _bucket(n):
				labels_ok = false
				detail = "%s %s: %s after, %s before" % [key, n.name, _bucket(n), before[n]]
		var got := {}
		for row in res["rows"]:
			got[row[0]] = got.get(row[0], 0) + 1
		var want := {}
		for n in before:
			want[before[n]] = want.get(before[n], 0) + 1
		if got != want:
			labels_ok = false
			detail = "%s buckets %s, nodes were %s" % [key, str(got), str(want)]
	t.check("perf_labels_match_timed_state", labels_ok, detail)
	# (3) Repeatable: the same world measured twice gives the same buckets; times within noise.
	var r1 := _nodes(false)
	var r2 := _nodes(false)
	var same_buckets := true
	var ratios: Array = []
	for key in r1:
		if (r1[key] as Dictionary).keys() != (r2[key] as Dictionary).keys():
			same_buckets = false
		var a := 0.0
		var b := 0.0
		for bk in r1[key]:
			a += r1[key][bk][1]
			b += r2[key].get(bk, [0, 0.0])[1]
		ratios.append("%s %.2f" % [key, b / maxf(a, 0.001)])
	t.check("perf_nodes_repeatable", same_buckets, "second/first total time: " + ", ".join(ratios))
	# (4) Freed nodes never crash a measurement: one freed before (skipped), one queued for deletion
	# before (skipped), one that frees itself in its own call (dropped, reported). (Throwaway nodes:
	# freeing a real food here would leave it in its ball's list, which the game never does.)
	var foods: Array = []
	for b in g.balls:
		for f in b.foods:
			if is_instance_valid(f):
				foods.append(f)
	var spare: Array = []
	for i in 3:
		var n3 := Node3D.new()
		g.add_child(n3)
		spare.append(n3)
	(spare[0] as Node).free()
	(spare[1] as Node).queue_free()
	var res2 := _time_nodes([spare[0], spare[1], foods[0], foods[1]], 3, _frame_call, _bucket)
	var res3 := _time_nodes([spare[2]], 3, func(n): n.queue_free(), _bucket)
	t.check("perf_freed_nodes_safe", res2["skipped"] == 2 and res2["rows"].size() == 2 and res3["freed"] == 1 and res3["rows"].is_empty(),
			"skipped %d, timed %d; self-freeing dropped %d" % [res2["skipped"], res2["rows"].size(), res3["freed"]])
	# (5) Vegetation visibility uses the renderer's geometry: the distance to the instances' AABB
	# centre, not the node's origin; range begin; the frustum.
	var cam := Camera3D.new()
	g.add_child(cam)
	cam.global_transform = Transform3D(Basis.IDENTITY, Vector3(5000, 0, 0))   # looking down -Z
	var frustum: Array[Plane] = cam.get_frustum()
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = BoxMesh.new()
	mm.instance_count = 1
	mm.set_instance_transform(0, Transform3D(Basis.IDENTITY, Vector3(0, 0, 30)))   # 30 m nearer the camera than the node
	mmi.multimesh = mm
	g.add_child(mmi)
	# (Recorded as MossBall.fill_chunk records a chunk: parent-local instance transforms. Here the
	# node's origin is 50 m from the camera and its one box 30 m nearer, so the box's centre is 20 m.)
	var place := func(z: float) -> void:
		mmi.position = Vector3(5000, 0, z)
		var rec: Array[Transform3D] = [Transform3D(Basis.IDENTITY, mmi.position + Vector3(0, 0, 30))]
		mmi.set_meta("veg_transforms", rec)
	place.call(-50.0)
	mmi.visibility_range_end = 40.0
	var near_box := renderer_draws(mmi, cam.global_position, frustum)
	mmi.visibility_range_begin = 30.0
	var begin_hides := not renderer_draws(mmi, cam.global_position, frustum)
	mmi.visibility_range_begin = 0.0
	place.call(100.0)   # behind the camera
	var behind_hidden := not renderer_draws(mmi, cam.global_position, frustum)
	place.call(-50.0)
	mmi.visibility_range_end = 15.0
	mmi.visibility_range_end_margin = 10.0
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	var fading_drawn := renderer_draws(mmi, cam.global_position, frustum)   # 20 m: inside 15 + 10 while fading
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	var plain_cut := not renderer_draws(mmi, cam.global_position, frustum)
	t.check("perf_veg_visibility_geometry", near_box and begin_hides and behind_hidden and fading_drawn and plain_cut,
			"AABB centre %s, begin %s, frustum %s, fade margin %s, no-fade cut %s (box %s, %.1f m)" % [near_box, begin_hides, behind_hidden, fading_drawn, plain_cut,
			str(world_aabb(mmi)), cam.global_position.distance_to(world_aabb(mmi).get_center())])
	mmi.queue_free()
	cam.queue_free()


## Direct timings of known periodic work (`--perf=probe`).
func _probe() -> void:
	var g: Game = t.g
	g._enter_title()
	await t.seconds(2.0)
	# The 4 Hz horizon cull of every ball, as shipped and as it was before ledger row 28 (every
	# vegetation node's tags read on each pass), 21 passes each, interleaved; medians.
	var now_ms: Array = []
	var old_ms: Array = []
	for rep in 21:
		await t.get_tree().process_frame
		var t0 := Time.get_ticks_usec()
		for b in g.balls:
			b.update_visibility(g.cam.global_position)
		now_ms.append((Time.get_ticks_usec() - t0) / 1000.0)
		await t.get_tree().process_frame
		t0 = Time.get_ticks_usec()
		for b in g.balls:
			_old_update_visibility(b, g.cam.global_position)
		old_ms.append((Time.get_ticks_usec() - t0) / 1000.0)
	now_ms.sort()
	old_ms.sort()
	# (Game culls one ball a frame in turn: the most any one frame carries is the dearest ball.)
	var dearest := 0.0
	for b in g.balls:
		var per: Array = []
		for rep in 11:
			var t1 := Time.get_ticks_usec()
			b.update_visibility(g.cam.global_position)
			per.append((Time.get_ticks_usec() - t1) / 1000.0)
		per.sort()
		dearest = maxf(dearest, per[5])
	t.log_line("PROBE update_visibility dearest single ball: %.2f ms" % dearest)
	t.log_line("PROBE update_visibility all balls: now %.2f ms (p90 %.2f), before %.2f ms (p90 %.2f)" % [now_ms[10], now_ms[18], old_ms[10], old_ms[18]])
	for b in g.balls:
		t.log_line("PROBE ball %d: %d terrain chunks, %d veg children, %d field materials, %d veg materials, %d blooms, %d motes" % [b.index,
				b.terrain_chunks.size(), b._veg_parent.get_child_count(), b.field_materials.size(), b.veg_materials.size(), b.blooms.size(), b.motes.size()])


## Game's own per-frame steps, timed one by one (`--perf=gamesteps`; medians of 60 calls, each from
## the same frozen world, which is put back after every call: see "By-hand timing" above).
func _game_steps() -> void:
	var g: Game = t.g
	var dt := 1.0 / 60.0
	var steps := {
		"check_blooms": func(): g._check_blooms(),
		"check_shrines": func(): g._check_shrines(),
		"check_vortex_entry": func(): g._check_vortex_entry(),
		"update_tutorial": func(): g._update_tutorial(dt),
		"check_vortex_connections": func(): g._check_vortex_connections(),
		"update_restoration": func(): g._update_restoration(dt),
		"update_mote_lights": func(): g._update_mote_lights(),
		"update_food": func(): g._update_food(dt),
		"update_hints": func(): g._update_hints(dt),
		"update_all_clear": func(): g._update_all_clear(dt),
		"resume_position": func(): g._resume_position(),
		"clock_tick": func(): g.clock.tick(dt, true),
		"autosave": func(): g._autosave(dt),
	}
	var actors := _actor_nodes()
	for k in steps:
		var r: Array = _time_frozen(actors, 60, steps[k])
		t.log_line("PROBE game %-26s %.3f ms (p90 %.3f)" % [k, r[0] / 1000.0, r[1] / 1000.0])


## Every node doing per-frame work except Game itself (snapshotted as shared state).
func _actor_nodes() -> Array:
	var out: Array = []
	var groups := _groups()
	for k in groups:
		for n in groups[k]:
			if n != t.g:
				out.append(n)
	return out


## MossBall.update_visibility before ledger row 28 (for the probe's before/after).
func _old_update_visibility(b: MossBall, cam_pos: Vector3) -> void:
	var to_cam := cam_pos - b.global_position
	var dist := to_cam.length()
	if dist < b.radius + 1.0:
		return
	var cam_dir := to_cam / dist
	var horizon := acos(clampf(b.radius / dist, -1.0, 1.0)) + acos(clampf(b.radius / (b.radius + b.terrain_max_h + 8.0), -1.0, 1.0))
	for i in b.terrain_chunks.size():
		b.terrain_chunks[i].visible = cam_dir.angle_to(b._chunk_dirs[i]) < horizon + b._chunk_ang[i]
	for c in b._veg_parent.get_children():
		if c is Node3D and c.has_meta("chunk_dir"):
			(c as Node3D).visible = cam_dir.angle_to(c.get_meta("chunk_dir")) < horizon + float(c.get_meta("chunk_ang", 0.9))


## Render-side split on the title (`--perf=render`, xvfb + vulkan; lavapipe, so relative only):
## the frame's mean time and draw counts with one kind of thing switched off at a time.
func _render_split() -> void:
	var g: Game = t.g
	g._enter_title()
	await t.seconds(2.0)
	var n := int(Settings.test_args.get("frames", "20"))
	var own := g.player.ball
	var t0: float = g._title_t
	var keys: Array = str(Settings.test_args.get("keys", "no sun shadow,no vegetation,no other balls,no own terrain,no water fx,no aquarium,no shader feeds,no creatures")).split(",")
	# Off and on in turn, each sample from the same point of the orbit (the main thread's CPU time:
	# script plus the render work it records; lavapipe's own rasterising runs on other threads).
	for k in keys:
		var diffs: Array = []
		var r_off: Dictionary
		for rep in 3:
			g._title_t = t0
			await t.get_tree().process_frame
			var on: Dictionary = await _sample(n)
			_render_toggle(g, own, k, false)
			g._title_t = t0
			await t.get_tree().process_frame
			r_off = await _sample(n)
			_render_toggle(g, own, k, true)
			diffs.append(on["cpu"] - r_off["cpu"])
			if rep == 0:
				t.log_line("PERF render %-16s on: cpu %.2f ms, %d draws, %d objects, %d prims" % [k, on["cpu"], on["draws"], on["objects"], on["prims"]])
		diffs.sort()
		t.log_line("PERF render %-16s saves %.2f ms main-thread cpu (pairs %s) | off: %d draws, %d objects, %d prims, wall %.0f ms" % [k, diffs[1],
				", ".join(diffs.map(func(d): return "%.2f" % d)), r_off["draws"], r_off["objects"], r_off["prims"], r_off["mean"]])


func _render_toggle(g: Game, own: MossBall, k: String, on: bool) -> void:
	match k:
		"no sun shadow":
			g.aquarium.sun.shadow_enabled = on
		"no glow":
			g.env.glow_enabled = on
		"no vegetation":
			for b in g.balls:
				b._veg_parent.visible = on
		"no other balls":
			for b in g.balls:
				if b != own:
					b.visible = on
		"no own terrain":
			for c in own.terrain_chunks:
				c.set_layer_mask_value(1, on)
		"no water fx":
			g.water_fx.visible = on
		"no aquarium":
			g.aquarium.visible = on
		"no shader feeds":
			# (The per-frame shader parameters: the wake and the water's impulses.)
			for nd in [g.water_fx, g.wake]:
				if nd != null:
					nd.set_process(on)
		"no far-side creatures":
			# (Only those over each ball's horizon from the camera, by update_visibility's rule.)
			var cp: Vector3 = g.cam.global_position
			for b in g.balls:
				var to_cam := cp - b.global_position
				var dist := to_cam.length()
				var horizon := acos(clampf(b.radius / dist, -1.0, 1.0)) + acos(clampf(b.radius / (b.radius + b.terrain_max_h + 8.0), -1.0, 1.0))
				for c in b.parasites + b.motes + b.foods + b.critters + b.blooms:
					if is_instance_valid(c) and (c as Node3D).global_position.distance_to(b.global_position) > 0.1:
						var dir: Vector3 = (c as Node3D).global_position - b.global_position
						if (to_cam / dist).angle_to(dir) > horizon:
							c.visible = on
		"creature cull":
			# (MossBall's render-only creature cull; "off" draws the far side's creatures: a negative saving is its gain.)
			MossBall.creature_cull = on
			for b in g.balls:
				b.update_visibility(g.cam.global_position)
		"no creatures":
			for b in g.balls:
				for c in b.parasites + b.motes + b.foods + b.critters + b.blooms:
					if is_instance_valid(c):
						c.visible = on
