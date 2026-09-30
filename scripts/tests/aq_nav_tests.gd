extends RefCounted
## Aquarium Gill navigation (release 00039-aquarium-gill; docs/research/2026-09-30-DEVICE_AUDIT.md §B):
## the stand-in's explorer (scripts/actors/gill_explorer.gd) measured against the scenery.
##
## Driven from unit_tests.gd (`_test_aquarium_gill`, `_phase_aq_nav`) and shots.gd (`aqgill`,
## `aqframes`). The explorer and the model are stepped synchronously at a fixed dt, so ten simulated
## minutes cost seconds and every run is the same on every machine.
##
## The body measurement is the audit's: six samples along him (head .. tail tip); a sample is "deep"
## when a sphere of half its radius at its centre meets the scenery (the inner half of the body is
## inside), "contact" when one of 0.85 of its radius does. It is taken twice: on the straight body
## along the model (the audit's own measure) and on the real bent body (the samples placed along the
## skeleton's spine bones, follow-through and swimming wave included).

const MASK := 1 | 2 | 8
const DT := 1.0 / 30.0
# Body samples in model space: [name, z, half-width, half-height] (the audit's).
const SAMPLES := [["head", -0.18, 0.16, 0.135], ["shoulder", 0.0, 0.21, 0.16], ["mid", 0.25, 0.19, 0.15],
		["hips", 0.5, 0.095, 0.105], ["tail", 0.8, 0.045, 0.07], ["tip", 0.98, 0.02, 0.03]]

var t
var g: Game
var pr: Presentation
var _sph := SphereShape3D.new()
var _q := PhysicsShapeQueryParameters3D.new()
var space: PhysicsDirectSpaceState3D


func _init(p_t, p_g: Game) -> void:
	t = p_t
	g = p_g
	_q.shape = _sph
	_q.collision_mask = MASK


func _hit(at: Vector3, r: float) -> bool:
	_sph.radius = r
	_q.transform = Transform3D(Basis.IDENTITY, at)
	return not space.intersect_shape(_q, 1).is_empty()


## Per sample: 0 clear, 1 contact, 2 deep. `bent`: on the skeleton's spine; else straight.
func body_state(bent: bool) -> PackedInt32Array:
	var m := pr.standin
	var xf := m.global_transform
	var out := PackedInt32Array()
	var bones := []
	if bent:
		var sk := m.skeleton
		var sxf := sk.global_transform
		for i in AxolotlModel.BONE_Z.size():
			bones.append(sxf * sk.get_bone_global_pose(i).origin)
	var up := xf.basis.y.normalized()
	for s in SAMPLES:
		var z: float = s[1]
		var drop := 0.03 * maxf(0.0, z - 0.35)
		var at: Vector3
		if bent:
			at = _along(bones, z) - up * drop
		else:
			at = xf * Vector3(0, AxolotlModel.BODY_Y - drop, z)
		var r: float = minf(s[2], s[3])
		var st := 0
		if _hit(at, r * 0.5):
			st = 2
		elif _hit(at, r * 0.85):
			st = 1
		out.append(st)
	return out


## The point at model z along the bone chain (linear between bones, extended past the last).
static func _along(bones: Array, z: float) -> Vector3:
	var bz: Array = AxolotlModel.BONE_Z
	var n := bz.size()
	for i in range(1, n):
		if z <= bz[i] or i == n - 1:
			var a: float = bz[i - 1]
			var b: float = bz[i]
			var f := (z - a) / (b - a)
			return (bones[i - 1] as Vector3).lerp(bones[i], f)
	return bones[n - 1]


# --- Homes -------------------------------------------------------------------------------

## The audit's home sampler: flat open ground on a lat/lon grid, spread evenly.
func homes(b: MossBall, want: int) -> Array:
	var cands := []
	for lat in range(-80, 81, 8):
		for lon in range(-180, 180, 11):
			var d := MossBall.dir_ll(lat, lon)
			var q := PhysicsRayQueryParameters3D.create(b.surface_point(d, 25.0), b.surface_point(d, -3.0), MASK)
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				continue
			var hp: Vector3 = hit["position"]
			if (hit["normal"] as Vector3).dot(b.up_at(hp)) < 0.8 or b.ravine_carve(b.up_at(hp)) > 0.01:
				continue
			cands.append(hp)
	var out := []
	var stride := maxf(1.0, cands.size() / float(want))
	var f := 0.0
	while int(f) < cands.size() and out.size() < want:
		out.append(cands[int(f)])
		f += stride
	return out


## The audit's eight worst homes (deep share under the old stand-in), from its CSV if given, else
## as recorded in the audit.
static func worst_homes(csv_path: String) -> Array:
	var rows := []
	if csv_path != "" and FileAccess.file_exists(csv_path):
		var f := FileAccess.open(csv_path, FileAccess.READ)
		f.get_line()
		while not f.eof_reached():
			var l := f.get_line().split(",")
			if l.size() < 7:
				continue
			rows.append([float(l[5]) / maxf(1.0, float(l[4])), int(l[0]) - 1, Vector3(float(l[1]), float(l[2]), float(l[3]))])
		rows.sort_custom(func(a, c): return a[0] > c[0])
	if rows.is_empty():
		for h in [[0.527, 4, Vector3(174.8083, -13.47337, 47.55797)], [0.494, 3, Vector3(-14.0, -2.912964, 147.3149)],
				[0.407, 0, Vector3(-30.63682, 37.2457, -13.64039)], [0.324, 6, Vector3(-226.5563, 6.340035, 105.057)],
				[0.31, 2, Vector3(-62.68784, 28.0, -108.4472)], [0.304, 3, Vector3(-9.883862, -0.581829, 149.2649)],
				[0.268, 5, Vector3(-219.9845, 42.0, -51.2963)], [0.251, 0, Vector3(-23.99251, -35.85624, 21.60295)]]:
			rows.append(h)
	return rows.slice(0, 8)


## The ground under a CSV home (its coordinates are rounded to 2 decimals).
func ground_at(b: MossBall, hp: Vector3) -> Vector3:
	var up := b.up_at(hp)
	var q := PhysicsRayQueryParameters3D.create(hp + up * 0.6, hp - up * 0.6, MASK)
	var hit := space.intersect_ray(q)
	return hit["position"] if not hit.is_empty() else hp


# --- One home, simulated -------------------------------------------------------------------

## A fresh stand-in and explorer at `home` (a fresh model: nothing carried over between runs).
func set_down(b: MossBall, home: Vector3, face := Vector3.ZERO) -> GillExplorer:
	if pr.standin:
		pr.standin.queue_free()
	pr.standin = AxolotlModel.new()
	pr.standin.name = "GillStandIn"
	g.add_child(pr.standin)
	pr.standin.set_process(false)
	var up := b.up_at(home)
	if face == Vector3.ZERO:
		face = -MossBall.frame_at(up, 0.0).z
	pr.start_explorer(b, home, face)
	return pr.explorer


## One synchronous step: the explorer, the model where it puts him, the model's own animation.
func sim_step() -> void:
	var t0 := Time.get_ticks_usec()
	pr.explorer.step(DT)
	var t1 := Time.get_ticks_usec()
	pr._apply_explorer()
	pr.standin._process(DT)
	_step_us += t1 - t0


var _step_us := 0
var _last_hits := 0
var _dbg_touch: bool = Settings.test_args.get("dbgtouch", "") != ""
var _dbg_left := int(Settings.test_args.get("dbg", "0"))


## Runs `secs` simulated seconds at one home; returns its measurements.
func run_home(b: MossBall, home: Vector3, secs: float, measure := true, sig_every := 0.0) -> Dictionary:
	var e := set_down(b, home)
	var n := int(secs / DT)
	var st := {"samples": 0, "deep": 0, "touch": 0, "deep_b": 0, "touch_b": 0, "reg": [0, 0, 0, 0, 0, 0],
			"reg_b": [0, 0, 0, 0, 0, 0], "max_home": 0.0, "sigs": [], "alt_min": 99.0,
			"alt_max": 0.0, "first_deep": -1.0, "touch_rest": 0}
	_step_us = 0
	_last_hits = 0
	var path := PackedVector3Array()
	var per_s := int(round(1.0 / DT))
	var sig_n := int(round(sig_every / DT)) if sig_every > 0.0 else 0
	for k in n:
		sim_step()
		if k % per_s == 0:
			path.append(e.p)
		if e.stats["hits"] != _last_hits:
			_last_hits = e.stats["hits"]
			if _dbg_left > 0:
				_dbg_left -= 1
				t.log_line("AQHIT ball %d t %.1f state %d speed %.2f free %.2f alt %.2f pitch %.2f yaw_v %.2f stuck %d backing %.2f arrived %s dist_goal %.2f p %s" % [b.index + 1, k * DT,
						e.state, e.speed, e._free_ahead, b.altitude(e.p), e.pitch, e.yaw_v, e.stuck_level, e._backing, e.arrived, e.p.distance_to(e.goal), e.p])
		if sig_n > 0 and k % sig_n == 0:
			st["sigs"].append(e.signature())
		if e.state == GillExplorer.SWIM:
			var a := b.altitude(e.p)
			st["alt_min"] = minf(st["alt_min"], a)
			st["alt_max"] = maxf(st["alt_max"], a)
		st["max_home"] = maxf(st["max_home"], e.home_distance(e.p))
		if measure and k % 3 == 0:
			st["samples"] += 1
			for bent in [false, true]:
				var bs := body_state(bent)
				var any_deep := false
				var any_touch := false
				for i in bs.size():
					if bs[i] == 2:
						any_deep = true
						st["reg_b" if bent else "reg"][i] += 1
					elif bs[i] == 1:
						any_touch = true
				var kd := "deep_b" if bent else "deep"
				var kt := "touch_b" if bent else "touch"
				st[kd] += 1 if any_deep else 0
				st[kt] += 1 if (any_touch and not any_deep) else 0
				if bent and any_touch and not any_deep and e.state != GillExplorer.SWIM:
					st["touch_rest"] += 1
				if any_deep and bent and st["first_deep"] < 0.0:
					st["first_deep"] = k * DT
				if (any_deep or (any_touch and _dbg_touch)) and _dbg_left > 0:
					_dbg_left -= 1
					t.log_line("AQDBG ball %d t %.1f %s %s state %d speed %.2f free %.2f alt %.2f stuck %d hits %d p %s" % [b.index + 1, k * DT,
							"bent" if bent else "straight", str(bs), e.state, e.speed, e._free_ahead, b.altitude(e.p), e.stuck_level, e.stats["hits"], e.p])
	st["path"] = path
	st["stats"] = e.stats.duplicate()
	st["step_us"] = float(_step_us) / maxf(1, n)
	st["visits"] = e.visits
	return st


## Route variety: the 1.5 m cells round home (on its tangent plane, within 9 m) with open water in
## the shell, and how many he swam through; and the closest his path comes to repeating itself
## (the mean distance between where he was and where he was tau seconds later, tau 5..60 s).
func variety(b: MossBall, home: Vector3, path: PackedVector3Array) -> Dictionary:
	var up := b.up_at(home)
	var fr := MossBall.frame_at(up, 0.0)
	var north := -fr.z
	var east := fr.x
	var reach := {}
	for i in range(-6, 7):
		for j in range(-6, 7):
			var c := Vector2((i + 0.5) * 1.5, (j + 0.5) * 1.5)
			if c.length() > 9.0:
				continue
			var at := home + north * c.x + east * c.y
			var d := b.up_at(at)
			for a in [0.8, 1.6, 2.6]:
				if not _hit(b.surface_point(d, a), 0.35):
					reach[Vector2i(i, j)] = true
					break
	var seen := {}
	for pp in path:
		var off := pp - home
		var c := Vector2i(floori(off.dot(north) / 1.5), floori(off.dot(east) / 1.5))
		if reach.has(c):
			seen[c] = true
	var loop_min := 99.0
	var loop_tau := 0
	for tau in range(5, 61):
		var s := 0.0
		var cnt := 0
		for k in range(0, path.size() - tau):
			s += path[k].distance_to(path[k + tau])
			cnt += 1
		if cnt > 0 and s / cnt < loop_min:
			loop_min = s / cnt
			loop_tau = tau
	return {"reach": reach.size(), "seen": seen.size(), "cover": float(seen.size()) / maxf(1, reach.size()), "loop_min": loop_min, "loop_tau": loop_tau}


# --- The phase: every ball x homes x minutes -------------------------------------------------

func nav_phase() -> void:
	pr = g.presentation
	var mins := float(Settings.test_args.get("mins", "10"))
	var per_ball := int(Settings.test_args.get("homes", "24"))
	var only_ball := int(Settings.test_args.get("ball", "0"))
	var twin_s := float(Settings.test_args.get("twin", "120"))
	var only_home := int(Settings.test_args.get("home", "-1"))
	pr.enter("play")
	await t.frames(3)
	pr.set_process(false)
	space = g.get_world_3d().direct_space_state
	var csv := FileAccess.open(t.out_dir.path_join("aq_nav_homes%s.csv" % ("" if only_ball == 0 else "_b%d" % only_ball)), FileAccess.WRITE)
	csv.store_line("ball,home_x,home_y,home_z,samples,deep,touch,deep_bent,touch_bent,hits,hip_touch,stuck_s,stuck_ep_max,l1,l2,l3,l4,goals,reached,abandoned,no_target,rest_s,rests,max_home,reach,seen,cover,loop_min,loop_tau,alt_min,alt_max,step_us,casts_per_step,overlaps_per_step,first_deep")
	var G := {"homes": 0, "samples": 0, "deep": 0, "touch": 0, "deep_b": 0, "touch_b": 0, "hits": 0, "hip": 0, "stuck_s": 0.0,
			"ep_max": 0.0, "l1": 0, "l2": 0, "l3": 0, "l4": 0, "goals": 0, "reached": 0, "aband": 0, "rest_s": 0.0, "rest_max": 0.0,
			"secs": 0.0, "cover_sum": 0.0, "cover_min": 9.0, "loop_min": 99.0, "twins": 0, "twins_same": 0, "us": 0.0, "casts": 0, "ovl": 0,
			"homes_deep": 0, "max_home": 0.0, "touch_rest": 0}
	var reg := PackedInt32Array([0, 0, 0, 0, 0, 0])
	var reg_b := PackedInt32Array([0, 0, 0, 0, 0, 0])
	var worst := []
	for b in g.balls:
		if only_ball > 0 and b.index != only_ball - 1:
			continue
		var hs := homes(b, per_ball)
		for hi in hs.size():
			if only_home >= 0 and hi != only_home:
				continue
			var home: Vector3 = hs[hi]
			var st := run_home(b, home, mins * 60.0)
			var s: Dictionary = st["stats"]
			var v := variety(b, home, st["path"])
			var steps := mins * 60.0 / DT
			G["homes"] += 1
			G["samples"] += st["samples"]
			for k in ["deep", "touch", "deep_b", "touch_b", "touch_rest"]:
				G[k] += st[k]
			G["homes_deep"] += 1 if st["deep_b"] > 0 else 0
			G["hits"] += s["hits"]
			G["hip"] += s["hip_touch"]
			G["stuck_s"] += s["stuck_s"]
			G["ep_max"] = maxf(G["ep_max"], s["stuck_ep_max"])
			for k in ["l1", "l2", "l3", "l4"]:
				G[k] += s[k]
			G["goals"] += s["goals"]
			G["reached"] += s["reached"]
			G["aband"] += s["abandoned"]
			G["rest_s"] += s["rest_s"]
			G["rest_max"] = maxf(G["rest_max"], s["rest_s"] / (mins * 60.0))
			G["secs"] += mins * 60.0
			G["cover_sum"] += v["cover"]
			G["cover_min"] = minf(G["cover_min"], v["cover"])
			G["loop_min"] = minf(G["loop_min"], v["loop_min"])
			G["us"] += st["step_us"]
			G["casts"] += s["casts"]
			G["ovl"] += s["overlaps"]
			G["max_home"] = maxf(G["max_home"], st["max_home"])
			for i in 6:
				reg[i] += st["reg"][i]
				reg_b[i] += st["reg_b"][i]
			worst.append([float(st["deep_b"] + st["touch_b"]) / maxf(1, st["samples"]), b.index, home, st["deep_b"], st["touch_b"], s["hits"], s["stuck_s"]])
			csv.store_line("%d,%.2f,%.2f,%.2f,%d,%d,%d,%d,%d,%d,%d,%.2f,%.2f,%d,%d,%d,%d,%d,%d,%d,%d,%.1f,%d,%.2f,%d,%d,%.3f,%.2f,%d,%.2f,%.2f,%.1f,%.2f,%.2f,%.1f" % [
					b.index + 1, home.x, home.y, home.z, st["samples"], st["deep"], st["touch"], st["deep_b"], st["touch_b"], s["hits"], s["hip_touch"],
					s["stuck_s"], s["stuck_ep_max"], s["l1"], s["l2"], s["l3"], s["l4"], s["goals"], s["reached"], s["abandoned"], s["no_target"],
					s["rest_s"], s["rests"], st["max_home"], v["reach"], v["seen"], v["cover"], v["loop_min"], v["loop_tau"], st["alt_min"], st["alt_max"],
					st["step_us"], float(s["casts"]) / steps, float(s["overlaps"]) / steps, st["first_deep"]])
			csv.flush()
			t.log_line("AQHOME ball %d home %d deep_b %d touch_b %d hits %d stuck %.1fs ep %.1f l2 %d l3 %d l4 %d goals %d reached %d rest %.0f%% cover %.0f%% loop %.2f step %.0fus" % [
					b.index + 1, hi, st["deep_b"], st["touch_b"], s["hits"], s["stuck_s"], s["stuck_ep_max"], s["l2"], s["l3"], s["l4"], s["goals"], s["reached"],
					100.0 * s["rest_s"] / (mins * 60.0), 100.0 * v["cover"], v["loop_min"], st["step_us"]])
			# Twin: the first minutes again from scratch, signature every 5 s.
			if hi % 8 == 0 and twin_s > 0.0:
				var a := run_home(b, home, twin_s, false, 5.0)
				var c := run_home(b, home, twin_s, false, 5.0)
				G["twins"] += 1
				var same: bool = a["sigs"] == c["sigs"] and a["sigs"].size() > 3
				G["twins_same"] += 1 if same else 0
				if not same:
					t.log_line("AQTWIN differ ball %d home %d: %s vs %s" % [b.index + 1, hi, str(a["sigs"].slice(-1)), str(c["sigs"].slice(-1))])
			await t.frames(1)
		t.log_line("AQBALL %d homes %d done" % [b.index + 1, hs.size()])
	csv.close()
	worst.sort_custom(func(a, c): return a[0] > c[0])
	var nh := maxf(1, G["homes"])
	var ns := maxf(1, G["samples"])
	var resolved: int = G["reached"] + G["aband"]
	t.log_line("AQNAV sim_minutes %.0f homes %d samples %d | straight deep %d (%.3f%%) contact %d (%.3f%%) | bent deep %d (%.3f%%) contact %d (%.3f%%; %d of them lying on a rest spot) homes_with_deep %d | late_avoid %d hip_touch %d | stuck %.1fs (%.3f%%) ep_max %.2fs l1 %d l2 %d l3 %d l4 %d | goals %d reached %d abandoned %d (%.1f%% reached) | rest %.1f%% (max home %.1f%%) | cover mean %.0f%% min %.0f%% loop_min %.2fm | max_home %.1fm | step %.1fus casts/step %.2f overlaps/step %.2f | twins %d/%d identical" % [
			G["secs"] / 60.0, G["homes"], G["samples"], G["deep"], 100.0 * G["deep"] / ns, G["touch"], 100.0 * G["touch"] / ns,
			G["deep_b"], 100.0 * G["deep_b"] / ns, G["touch_b"], 100.0 * G["touch_b"] / ns, G["touch_rest"], G["homes_deep"], G["hits"], G["hip"],
			G["stuck_s"], 100.0 * G["stuck_s"] / maxf(1.0, G["secs"]), G["ep_max"], G["l1"], G["l2"], G["l3"], G["l4"],
			G["goals"], G["reached"], G["aband"], 100.0 * G["reached"] / maxf(1, resolved), 100.0 * G["rest_s"] / maxf(1.0, G["secs"]), 100.0 * G["rest_max"],
			100.0 * G["cover_sum"] / nh, 100.0 * G["cover_min"], G["loop_min"], G["max_home"], G["us"] / nh, float(G["casts"]) / (G["secs"] / DT),
			float(G["ovl"]) / (G["secs"] / DT), G["twins_same"], G["twins"]])
	var names := []
	for s in SAMPLES:
		names.append(s[0])
	t.log_line("AQREGION %s straight deep %s bent deep %s" % [str(names), str(reg), str(reg_b)])
	for i in mini(8, worst.size()):
		t.log_line("AQWORSTNOW %.2f%% ball %d home %s deep_b %d contact_b %d hits %d stuck %.1fs" % [100.0 * worst[i][0], worst[i][1] + 1, worst[i][2], worst[i][3], worst[i][4], worst[i][5], worst[i][6]])
	# (Pass/fail is on the body as drawn: the skinned body lies along the spine bones. The rigid
	# straight line along the model, the audit's measure of the old rigid stand-in, is logged beside
	# it: in a climb or a curve it cuts corners the drawn body does not.)
	t.check("aq_nav_no_deep", G["deep_b"] == 0, "bent (drawn body) %d; rigid reference %d" % [G["deep_b"], G["deep"]])
	t.check("aq_nav_contact_under_0_2pct", 100.0 * G["touch_b"] / ns < 0.2, "bent %.3f%% (resting %d of %d); rigid reference %.3f%%" % [100.0 * G["touch_b"] / ns, G["touch_rest"], G["touch_b"], 100.0 * G["touch"] / ns])
	t.check("aq_nav_no_l4", G["l4"] == 0, "%d" % G["l4"])
	t.check("aq_nav_stuck", 100.0 * G["stuck_s"] / maxf(1.0, G["secs"]) < 1.0 and G["ep_max"] <= 4.0, "%.3f%% ep_max %.2fs" % [100.0 * G["stuck_s"] / maxf(1.0, G["secs"]), G["ep_max"]])
	t.check("aq_nav_destinations_reached", float(G["reached"]) / maxf(1, resolved) >= 0.9, "%d/%d" % [G["reached"], resolved])
	t.check("aq_nav_resting_share", G["rest_s"] / maxf(1.0, G["secs"]) <= 0.2 and G["rest_s"] > 0.0, "%.1f%%" % (100.0 * G["rest_s"] / maxf(1.0, G["secs"])))
	t.check("aq_nav_twins_identical", G["twins"] > 0 and G["twins_same"] == G["twins"], "%d/%d" % [G["twins_same"], G["twins"]])
	t.check("aq_nav_route_variety", G["loop_min"] > 0.75, "cover mean %.0f%% min %.0f%%, loop_min %.2f m" % [100.0 * G["cover_sum"] / nh, 100.0 * G["cover_min"], G["loop_min"]])
	pr.set_process(true)
	pr.exit()
	await t.frames(3)


# --- Quick check (the unit suite) -------------------------------------------------------------

## Three of the audit's worst homes, 90 simulated seconds each, and the close-up's camera.
func quick() -> void:
	pr = g.presentation
	pr.enter("play")
	await t.frames(3)
	pr.set_process(false)
	space = g.get_world_3d().direct_space_state
	var deep := 0
	var touch := 0
	var samples := 0
	var l4 := 0
	var hits := 0
	var rows := worst_homes("")
	for r in rows.slice(0, 3):
		var b: MossBall = g.balls[r[1]]
		var st := run_home(b, ground_at(b, r[2]), 90.0)
		deep += st["deep_b"]
		touch += st["touch_b"]
		samples += st["samples"]
		l4 += st["stats"]["l4"]
		hits += st["stats"]["hits"]
	t.check("aq_gill_no_deep_at_worst_homes", deep == 0 and l4 == 0, "deep %d contact %d of %d, late %d, l4 %d" % [deep, touch, samples, hits, l4])
	var b0: MossBall = g.balls[rows[0][1]]
	var h0 := ground_at(b0, rows[0][2])
	var a := run_home(b0, h0, 30.0, false, 2.0)
	var c := run_home(b0, h0, 30.0, false, 2.0)
	t.check("aq_gill_deterministic", a["sigs"] == c["sigs"], "%s" % str(a["sigs"].slice(-1)))
	# The Gill close-up: never nearer than his length, never through the scenery.
	pr.set_process(true)
	pr.standin.set_process(true)
	pr.go("live", true)
	pr.live_view = Presentation.LIVE_VIEWS.size() - 2
	pr.next_live_view()
	var cam_ok := true
	var min_d := 99.0
	for k in 60:
		await t.frames(3)
		var tgt := pr._camera_target(0.0)
		var d: float = (tgt[0] as Vector3).distance_to(tgt[1])
		min_d = minf(min_d, d)
		cam_ok = cam_ok and d >= Presentation.GILL_CAM_MIN - 0.01 and not _hit(tgt[0], 0.1)
	t.check("aq_gill_closeup_camera_clear", cam_ok, "min distance %.2f m" % min_d)
	pr.exit()
	await t.frames(3)


# --- Real frames: every Live Tank view at the audit's eight worst homes ------------------------

## The stand-in set down for real frames (Presentation drives him and the camera each frame).
func set_down_live(b: MossBall, home: Vector3) -> void:
	set_down(b, home)
	pr.standin.set_process(true)
	pr.standin.visible = true


## `--secs` per view (default 15). Rendered (xvfb): one screenshot per view per home.
func frames_phase() -> void:
	pr = g.presentation
	space = g.get_world_3d().direct_space_state
	var secs := float(Settings.test_args.get("secs", "15"))
	var rows := worst_homes(Settings.test_args.get("csv", ""))
	pr.enter("play")
	await t.frames(3)
	pr.go("live", true)
	var tot := {"frames": 0, "deep": 0, "touch": 0, "l4": 0, "cam_bad": 0, "cam_min": 99.0}
	for hi in rows.size():
		var r: Array = rows[hi]
		var b: MossBall = g.balls[r[1]]
		var home := ground_at(b, r[2])
		set_down_live(b, home)
		for v in Presentation.LIVE_VIEWS.size():
			pr.live_view = (v + Presentation.LIVE_VIEWS.size() - 1) % Presentation.LIVE_VIEWS.size()
			pr.next_live_view()
			var name_: String = Presentation.LIVE_VIEWS[v][0]
			var n := 0
			var deep := 0
			var touch := 0
			var px := 0.0
			var in_view := 0
			var cam_min := 99.0
			var cam_bad := 0
			var fr := 0
			var t0 := Time.get_ticks_msec()
			while fr < int(secs * 30.0):
				await t.frames(2)
				fr += 2
				var bs := body_state(true)
				n += 1
				if bs.has(2):
					deep += 1
				elif bs.has(1):
					touch += 1
				var cam := g.get_viewport().get_camera_3d()
				var sk := pr.standin.skeleton
				var hb := sk.global_transform * sk.get_bone_global_pose(0).origin
				var tb := sk.global_transform * sk.get_bone_global_pose(10).origin
				if cam.is_position_in_frustum(hb):
					in_view += 1
					px += cam.unproject_position(hb).distance_to(cam.unproject_position(tb))
				if name_ == "gill":
					var d := cam.global_position.distance_to(pr._cam_look)
					cam_min = minf(cam_min, d)
					if _hit(cam.global_position, 0.1):
						cam_bad += 1
			var ms := Time.get_ticks_msec() - t0
			await t.shot("aqframes_h%d_b%d_%s" % [hi, b.index + 1, name_])
			t.log_line("AQFRAMES home %d ball %d view %s frames %d deep %d contact %d in_view %d gill_px %.0f cam_min %s cam_in_scenery %d wall %.1fs" % [
					hi, b.index + 1, name_, n, deep, touch, in_view, px / maxf(1, in_view), ("%.2f" % cam_min) if name_ == "gill" else "-", cam_bad, ms / 1000.0])
			tot["frames"] += n
			tot["deep"] += deep
			tot["touch"] += touch
			tot["cam_bad"] += cam_bad
			if name_ == "gill":
				tot["cam_min"] = minf(tot["cam_min"], cam_min)
		tot["l4"] += pr.explorer.stats["l4"]
		t.log_line("AQFRAMESHOME %d stats %s" % [hi, str(pr.explorer.stats)])
	t.log_line("AQFRAMESTOTAL %s" % str(tot))
	t.check("aq_frames_no_deep", tot["deep"] == 0, "%d of %d" % [tot["deep"], tot["frames"]])
	t.check("aq_frames_contact_under_0_2pct", 100.0 * tot["touch"] / maxf(1, tot["frames"]) < 0.2, "%d of %d" % [tot["touch"], tot["frames"]])
	t.check("aq_frames_no_l4", tot["l4"] == 0, "%d" % tot["l4"])
	t.check("aq_frames_closeup_camera", tot["cam_bad"] == 0 and tot["cam_min"] >= Presentation.GILL_CAM_MIN - 0.05, "min %.2f in scenery %d" % [tot["cam_min"], tot["cam_bad"]])
	pr.exit()
	await t.frames(3)


# --- Renders in the Gill close-up ---------------------------------------------------------

## The close-up camera snapped to where it would be now, and a screenshot.
func _snap_shot(name_: String, note: String) -> void:
	var tgt := pr._camera_target(0.0)
	pr._cam_pos = tgt[0]
	pr._cam_look = tgt[1]
	pr._process(0.0)
	await t.frames(1)
	await t.shot(name_)
	var e := pr.explorer
	t.log_line("AQRENDER %s %s | state %d speed %.2f yaw_v %.2f alt %.2f free %.2f cam_d %.2f p %s" % [name_, note, e.state, e.speed, e.yaw_v,
			e.ball.altitude(e.p), e._free_ahead, (tgt[0] as Vector3).distance_to(tgt[1]), e.p])


func _near_collider(at: Vector3, r: float) -> Object:
	_sph.radius = r
	_q.transform = Transform3D(Basis.IDENTITY, at)
	var res := space.intersect_shape(_q, 4)
	return null if res.is_empty() else res[0]["collider"]


## Steps the explorer at `home` until `cond(e)` holds (at most `max_s` simulated seconds).
func _seek(b: MossBall, home: Vector3, cond: Callable, max_s: float) -> bool:
	set_down(b, home)
	var n := int(max_s / DT)
	for k in n:
		sim_step()
		if k * DT > 5.0 and cond.call(pr.explorer):
			return true
	return false


func renders_phase() -> void:
	pr = g.presentation
	space = g.get_world_3d().direct_space_state
	for b in g.balls:
		b.add_heal(Vector3.UP, 340.0, 0.0)
	g.g_disp = 1.0
	g.aquarium.apply(1.0)
	pr.enter("play")
	await t.frames(3)
	pr.go("live", true)
	pr.live_view = Presentation.LIVE_VIEWS.size() - 2
	pr.next_live_view()
	# (The view's buttons and the touch controls fade first: an untouched Live Tank.)
	await t.seconds(5.0)
	pr.set_process(false)
	var rows := worst_homes(Settings.test_args.get("csv", ""))
	# (--at=ball:x:y:z:secs[;...]: a shot at a given home after so many simulated seconds.)
	var at_list: String = Settings.test_args.get("at", "")
	if at_list != "":
		for item in at_list.split(";", false):
			var f := item.split(":")
			var ab: MossBall = g.balls[int(f[0]) - 1]
			set_down(ab, ground_at(ab, Vector3(float(f[1]), float(f[2]), float(f[3]))))
			for k in int(float(f[4]) / DT):
				sim_step()
			await _snap_shot("aqgill_at_%s" % item.replace(":", "_").replace(";", "_"), "stuck %d level %d" % [pr.explorer.stats["stuck_eps"], pr.explorer.stuck_level])
		pr.set_process(true)
		pr.exit()
		await t.frames(3)
		return
	var cands := []
	for r in rows:
		cands.append([g.balls[r[1]], ground_at(g.balls[r[1]], r[2])])
	for b in g.balls:
		for h in homes(b, 4):
			cands.append([b, h])
	# (Under a leaf: homes on the ground under the balls' leaves and platforms.)
	var leaf_cands := []
	for b in g.balls:
		for n in _layer_bodies(b, 2):
			var at: Vector3 = (n as Node3D).global_position
			var alt := b.altitude(at)
			if alt < 1.2 or alt > 3.6:
				continue
			var up := b.up_at(at)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at - up * 0.3, at - up * 6.0, MASK))
			if not hit.is_empty() and (hit["normal"] as Vector3).dot(up) > 0.8:
				leaf_cands.append([b, hit["position"]])
	t.log_line("AQRENDER leaf homes %d" % leaf_cands.size())
	var scen := [
		["open_water", func(e: GillExplorer) -> bool: return e.state == GillExplorer.SWIM and e.speed > 0.6 and e.ball.altitude(e.p) > 1.4 and _near_collider(e.p, 1.2) == null],
		["curving_round_moss", func(e: GillExplorer) -> bool: return e.state == GillExplorer.SWIM and absf(e.yaw_v) > 0.7 and e.speed > 0.35 and _near_collider(e.p, 0.9) != null],
		["under_leaf", func(e: GillExplorer) -> bool: return e.state == GillExplorer.SWIM and _leaf_above(e)],
		["near_mound", func(e: GillExplorer) -> bool: return e.state == GillExplorer.SWIM and _mound_beside(e)],
		["resting", func(e: GillExplorer) -> bool: return e.state == GillExplorer.REST and e._rest_left < 2.5],
		["pocket_escape", func(e: GillExplorer) -> bool: return e._backing > 0.0],
	]
	for sc in scen:
		var done := false
		for c in (leaf_cands.slice(0, 12) + cands if sc[0] == "under_leaf" else cands):
			if await _seek_and_shoot(c[0], c[1], sc[0], sc[1]):
				done = true
				break
		if not done:
			t.log_line("AQRENDER %s not found" % sc[0])
	# The worst home, now (the audit's shots there are the "before").
	var w: Array = cands[0]
	set_down(w[0], w[1])
	for k in int(20.0 / DT):
		sim_step()
	await _snap_shot("aqgill_after_worst_home_t20", "worst home, 20 s in")
	for k in int(40.0 / DT):
		sim_step()
	await _snap_shot("aqgill_after_worst_home_t60", "worst home, 60 s in")
	# Ten-minute path traces (seen from above).
	await _path_trace(w[0], w[1], "aqgill_path_trace_worst_home")
	var c2: Array = cands[8]
	await _path_trace(c2[0], c2[1], "aqgill_path_trace_ball%d" % (c2[0].index + 1))
	pr.set_process(true)
	pr.exit()
	await t.frames(3)
	t.check("aq_renders_ran", true, "")


func _leaf_above(e: GillExplorer) -> bool:
	var q := PhysicsRayQueryParameters3D.create(e.p, e.p + e._up * 2.2, 2)
	return not space.intersect_ray(q).is_empty()


func _mound_beside(e: GillExplorer) -> bool:
	var c := _near_collider(e.p, 1.0)
	return c != null and c != e.ball.static_body and c is CollisionObject3D and ((c as CollisionObject3D).collision_layer & 1) != 0 and e.ball.altitude(e.p) < 1.5


func _seek_and_shoot(b: MossBall, home: Vector3, name_: String, cond: Callable) -> bool:
	if not _seek(b, home, cond, 240.0):
		return false
	var e := pr.explorer
	await _snap_shot("aqgill_%s" % name_, "ball %d home %s t %.1f" % [b.index + 1, home, e.t])
	if name_ == "pocket_escape":
		for k in int(1.5 / DT):
			sim_step()
		await _snap_shot("aqgill_pocket_escape_2", "1.5 s later")
		for k in int(2.0 / DT):
			sim_step()
		await _snap_shot("aqgill_pocket_escape_3", "3.5 s later")
	return true


func _path_trace(b: MossBall, home: Vector3, name_: String) -> void:
	var st := run_home(b, home, 600.0, false)
	var path: PackedVector3Array = st["path"]
	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.vertex_color_use_as_albedo = true
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, mat)
	for i in path.size():
		var k := float(i) / maxf(1, path.size() - 1)
		im.surface_set_color(Color(1.0, 0.9 - 0.7 * k, 0.2 + 0.6 * k))
		im.surface_add_vertex(path[i])
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	g.add_child(mi)
	var up := b.up_at(home)
	var fr := MossBall.frame_at(up, 0.0)
	var cam_at := home + up * 19.0 + fr.z * 7.0
	g.cam.global_position = cam_at
	g.cam.look_at(home, -fr.z)
	g.aquarium.outside_camera(cam_at)
	await t.frames(2)
	await t.shot(name_)
	var v := variety(b, home, path)
	t.log_line("AQRENDER %s path %d points, max from home %.1f m, cover %.0f%%, rest %.0f s, goals %d" % [name_, path.size(), st["max_home"], 100.0 * v["cover"], st["stats"]["rest_s"], st["stats"]["goals"]])
	mi.queue_free()


func _layer_bodies(root: Node, bit: int) -> Array:
	var out := []
	for c in root.get_children():
		if c is CollisionObject3D and ((c as CollisionObject3D).collision_layer & bit) != 0:
			out.append(c)
		out.append_array(_layer_bodies(c, bit))
	return out
