extends RefCounted
## CPU cost breakdown (not run by the unit suite). `--test=perf` measures physics/process frame
## time per moss ball with categories of nodes toggled off, to find hot spots. `--perf=title` sits
## on the title (the orbit round him) and `--perf=play` stands him in play: both print the whole
## frame's spread (median/p95/worst), the engine's process/physics split, the slowest frames, and
## the cost of each script's per-frame work (that script's nodes switched off one group at a time).

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
	if mode == "gamesteps":
		await _game_steps()
		return
	if mode == "render":
		await _render_split()
		return
	if mode == "probe":
		await _probe()
		return
	if mode == "parasite":
		await _parasite_parts()
		return
	if mode == "veg":
		await _veg_budget()
		return
	if mode == "nodes":
		await _nodes()
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


## Each group's own per-frame calls, timed directly: every node's _process/_physics_process is
## called by hand (one frame's worth per round, 30 rounds, median) while the engine still runs the
## real frames between rounds. Exact, unlike switching groups off on a shared machine; the extra calls
## run the simulation on a little faster, which a perf run does not mind.
func _direct(mode: String, groups: Dictionary) -> void:
	var rows: Array = []
	var dt := 1.0 / 60.0
	var total := 0.0
	for k in groups:
		var nodes: Array = groups[k]
		var per: Array = []
		for rep in 30:
			await t.get_tree().process_frame
			var t0 := Time.get_ticks_usec()
			for nd in nodes:
				if not is_instance_valid(nd):
					continue
				if nd.is_physics_processing() and nd.has_method("_physics_process"):
					nd._physics_process(dt)
				if nd.is_processing() and nd.has_method("_process"):
					nd._process(dt)
			per.append((Time.get_ticks_usec() - t0) / 1000.0)
		per.sort()
		rows.append([per[15], k, nodes.size(), per[27]])
		total += per[15]
	rows.sort_custom(func(a, b): return a[0] > b[0])
	t.log_line("PERF %s direct: scripts' own per-frame work %.2f ms in all" % [mode, total])
	for row in rows:
		if row[0] >= 0.01:
			t.log_line("PERF %s  %-28s x%-4d %6.3f ms per frame (p90 %.3f)" % [mode, row[1], row[2], row[0], row[3]])


## Per-node cost of the many-instance scripts (`--perf=nodes`, in play or `--state=title`): each node's
## own _physics_process/_process timed by hand (median of 30), summed by whether the node is on his
## ball and near him, so sleeping and awake instances show separately.
func _nodes() -> void:
	var g: Game = t.g
	if str(Settings.test_args.get("state", "play")) == "title":
		g._enter_title()
	await t.seconds(2.0)
	var dt := 1.0 / 60.0
	var groups := _groups()
	for key in ["parasite.gd", "mote.gd", "food.gd", "bloom.gd", "starfish.gd"]:
		if not groups.has(key):
			continue
		var buckets := {}
		for nd in groups[key]:
			var per: Array = []
			for rep in 30:
				if rep % 10 == 0:
					await t.get_tree().process_frame
				var t0 := Time.get_ticks_usec()
				if nd.is_physics_processing() and nd.has_method("_physics_process"):
					nd._physics_process(dt)
				if nd.is_processing() and nd.has_method("_process"):
					nd._process(dt)
				per.append((Time.get_ticks_usec() - t0) / 1000.0)
			per.sort()
			var same: bool = "ball" in nd and nd.ball == g.player.ball
			var near: bool = g.near_player((nd as Node3D).global_position)
			var st: String = str(nd.state) if "state" in nd else "-"
			var b := "%s ball, %s, %s" % ["his" if same else "other", "near" if near else "far", st]
			if not buckets.has(b):
				buckets[b] = [0, 0.0]
			buckets[b][0] += 1
			buckets[b][1] += per[15]
		for b in buckets:
			t.log_line("NODES %-14s %-34s x%-4d %.3f ms per frame (%.1f us each)" % [key, b, buckets[b][0], buckets[b][1], buckets[b][1] * 1000.0 / buckets[b][0]])


## One awake parasite's update split into its parts (`--perf=parasite`): medians over the awake ones.
func _parasite_parts() -> void:
	var g: Game = t.g
	await t.seconds(2.0)
	var dt := 1.0 / 60.0
	var awake: Array = []
	for b in g.balls:
		for p in b.parasites:
			if is_instance_valid(p) and p.ball == g.player.ball and g.near_player(p.global_position) and p.state == "graze":
				awake.append(p)
	var parts := {
		"whole _physics_process": func(p): p._physics_process(dt),
		"_update_segments": func(p): p._update_segments(dt),
		"  _push_body": func(p): p._push_body(),
		"_snap_ground (1 ray)": func(p): p._snap_ground(),
		"_ground_ahead (1 ray)": func(p): p._ground_ahead(p.global_position + p.heading * 0.3),
		"_wall_ahead (1 ray)": func(p): p._wall_ahead(p.heading * 0.05),
		"_ravine_ahead": func(p): p._ravine_ahead(p.heading * 0.05),
		"_express": func(p): p._express(dt, g.player),
		"set_look": func(p): p.set_look(p._gray, p._flash, 0.0),
		"_avoid_blooms": func(p): p._avoid_blooms(p.heading),
		"_angle_from_home": func(p): p._angle_from_home(p.global_position),
	}
	t.log_line("PARASITE %d awake grazing near him; seg_count %s" % [awake.size(), str(awake.map(func(p): return p.seg_count))])
	for k in parts:
		var per: Array = []
		for rep in 40:
			if rep % 10 == 0:
				await t.get_tree().process_frame
			var t0 := Time.get_ticks_usec()
			for p in awake:
				parts[k].call(p)
			per.append((Time.get_ticks_usec() - t0) / 1000.0 / maxf(1, awake.size()))
		per.sort()
		t.log_line("PARASITE %-24s %6.1f us each (p90 %.1f)" % [k, per[20] * 1000.0, per[36] * 1000.0])


## Vegetation triangles the camera's view draws (`--perf=veg`, `--state=title|play`): every
## vegetation MultiMesh that is visible (horizon cull) and within its visibility range, its mesh's
## triangles x instances, by plant mesh and by each instance's distance from the camera.
func _veg_budget() -> void:
	var g: Game = t.g
	if str(Settings.test_args.get("state", "title")) == "title":
		g._enter_title()
	await t.seconds(2.0)
	var cam: Vector3 = g.cam.global_position
	var frustum: Array[Plane] = g.get_viewport().get_camera_3d().get_frustum()
	t.log_line("VEG camera %s, player %.1f m away, state %s" % [str(cam), cam.distance_to(g.player.global_position), g.state])
	var bands := [10.0, 20.0, 30.0, 45.0, 60.0, 1e9]
	var by_mesh := {}
	var by_band := PackedFloat64Array()
	by_band.resize(bands.size())
	var total := 0.0
	var tri_cache := {}
	for b in g.balls:
		b.update_visibility(cam)
		for c in b._veg_parent.get_children():
			if not (c is MultiMeshInstance3D) or not c.is_visible_in_tree():
				continue
			var mmi: MultiMeshInstance3D = c
			var mm := mmi.multimesh
			if mm == null or mm.mesh == null:
				continue
			var aabb := mmi.global_transform * mmi.get_aabb()
			var inside := true
			for pl in frustum:
				# (Outside if the whole box is in front of a plane.)
				var far_pt := aabb.position + Vector3(aabb.size.x if pl.normal.x < 0.0 else 0.0, aabb.size.y if pl.normal.y < 0.0 else 0.0, aabb.size.z if pl.normal.z < 0.0 else 0.0)
				if pl.distance_to(far_pt) > 0.0:
					inside = false
					break
			if not inside:
				continue
			var d0 := mmi.global_position.distance_to(cam)
			if mmi.visibility_range_end > 0.0 and d0 > mmi.visibility_range_end + mmi.visibility_range_end_margin:
				continue
			if not tri_cache.has(mm.mesh):
				tri_cache[mm.mesh] = MossBall._mesh_tris(mm.mesh)
			var tris: int = tri_cache[mm.mesh]
			var name: String = mm.mesh.resource_name if mm.mesh.resource_name != "" else ("%s/%s" % [mmi.material_override.resource_name if mmi.material_override else "?", str(mm.mesh.get_aabb().size.snapped(Vector3.ONE * 0.01))])
			if not by_mesh.has(name):
				by_mesh[name] = [0.0, 0, tris]
			for j in mm.instance_count:
				var p := mmi.global_transform * mm.get_instance_transform(j).origin
				var d := p.distance_to(cam)
				var k := 0
				while d > bands[k]:
					k += 1
				by_band[k] += tris
				by_mesh[name][0] += tris
				by_mesh[name][1] += 1
				total += tris
	t.log_line("VEG drawn vegetation: %.0f k triangles" % (total / 1000.0))
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


## Game's own per-frame steps in play, timed one by one (`--perf=gamesteps`; medians of 60 calls).
func _game_steps() -> void:
	var g: Game = t.g
	await t.seconds(2.0)
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
	for k in steps:
		var per: Array = []
		for rep in 60:
			if rep % 10 == 0:
				await t.get_tree().process_frame
			var t0 := Time.get_ticks_usec()
			steps[k].call()
			per.append((Time.get_ticks_usec() - t0) / 1000.0)
		per.sort()
		t.log_line("PROBE game %-26s %.3f ms (p90 %.3f)" % [k, per[30], per[54]])


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
