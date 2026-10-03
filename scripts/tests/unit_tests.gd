extends RefCounted
## System-level checks of every mechanic in the spec, driven through the real player
## controller with the same input actions the touch HUD / gamepad use.

var t
var g: Game
var p: Axolotl


func run(runner) -> void:
	t = runner
	g = t.g
	p = g.player
	p.use_bot_input = true
	# (Repopulation is off in the unit suite: tests clear zones and run long, and returners turning up
	# would change their worlds. _test_repopulation drives its own instances.)
	if g.repop != null:
		g.repop.enabled = false
		g.hints.enabled = false
	await t.seconds(0.5)
	var only: String = Settings.test_args.get("only", "")
	for name_ in ["_test_startup", "_test_ota_and_version", "_test_mesh_winding", "_test_terrain", "_test_ravines", "_test_ooze_bubbles", "_test_view_clearances", "_test_camera_rises_over", "_test_title_safe", "_test_camera_invariant", "_test_ball_view", "_test_hud_corner", "_test_restore_hints", "_test_home_coherence", "_test_terrain_grounded", "_test_no_floating_platforms", "_test_parasite_locomotion", "_test_parasite_body_and_death", "_test_parasite_combat", "_test_organic_motion", "_test_gill_look", "_test_gill_idles", "_test_gill_colours", "_test_gill_patterns", "_test_tail_whip", "_test_gill_traction", "_test_gill_incline_transitions", "_test_traction_no_shortcuts", "_test_gill_body_follow", "_test_swim_body_follow", "_test_ambient_sway", "_test_placements", "_test_tutorial_route", "_test_sphere_walk", "_test_jump_and_burst", "_test_coyote_and_buffer", "_test_swipe_direction_and_stages", "_test_hard_landing", "_test_food", "_test_food_reach", "_test_darter_and_burrower", "_test_food_repopulates", "_test_motes", "_test_checkpoint_and_regen", "_test_crumble", "_test_restoration_gates", "_test_retract_gates_gone", "_test_bubble_columns", "_test_restoration_continuity", "_test_health_map", "_test_vortex", "_test_vortex_tints", "_test_vortex_currents", "_test_vortex_currents_travel", "_test_current", "_test_current_brace", "_test_canopy", "_test_canopy_plain_jumps", "_test_climbs_physical", "_test_jungle_ladders_physical", "_test_leaf_geometry", "_test_leaf_footing", "_test_caves", "_test_mounds", "_test_vegetation", "_test_vortex_mouths_clear", "_test_route_audit", "_test_new_areas", "_test_ecosystem", "_test_music", "_test_opening_audio", "_test_run_clock", "_test_completion_catalog", "_test_completion_frozen", "_test_run_save_file", "_test_run_timer_live", "_test_run_continue", "_test_timer_integrity", "_test_resume_points_safe", "_phase_continue_write", "_phase_continue_read", "_test_upgrades", "_test_ui", "_test_menus_no_scroll", "_test_menu_touch", "_test_tier2_rules", "_test_tier2_world", "_test_ambient_fish", "_test_parasite_never_buried", "_test_tier2_loadout", "_test_aquarium_experiences", "_test_aquarium_polish", "_test_all_clear", "_test_treasure_unlock", "_test_treasure_generation", "_test_treasure_play", "_phase_treasure_stress", "_phase_live_fish_diag", "_phase_cpu_probe", "_phase_incline_survey", "_phase_loco_diag", "_phase_crawl_trace", "_phase_mouth_crawls", "_phase_organic_trace", "_test_skilltree_graph", "_test_progress_store", "_test_starfish_spots", "_test_starfish_pickup", "_test_skill_ui", "_test_quick_gill", "_test_lunge_skills", "_test_burst_skills", "_test_glide_control", "_test_glide_transfers", "_test_mote_magnet", "_phase_starfish_survey", "_phase_starfish_sweep", "_phase_glide_probe", "_test_plants_terminal_growth", "_test_sea_fan_depth", "_test_repopulation", "_phase_repop_survey", "_phase_repop_sim", "_test_aquarium_gill", "_phase_aq_nav", "_test_tutorials_and_title", "_test_onb_progress", "_test_onb_owner_save", "_test_onb_per_run", "_test_onb_toggle", "_test_onb_intro", "_test_onb_feeding", "_test_onb_parasite", "_test_onb_feed_first", "_test_onb_tunnel", "_test_onb_starfish", "_test_onb_softlock", "_test_onb_relaunch", "_test_onb_restoration_equal", "_test_hard_mode", "_test_hard_mode_save", "_test_polish_a", "_test_leaf_motion", "_test_death_and_arrival", "_test_camera_never_drawn_unsafe", "_phase_world_hash", "_phase_th_bench", "_phase_hard_write", "_phase_hard_read", "_phase_hard_newrun", "_phase_hard_finish", "_phase_hard_sim", "_phase_hard_intervals", "_phase_onb_owner", "_phase_onb_write", "_phase_onb_read", "_phase_onb_kill", "_phase_onb_toggle", "_phase_cohesion_probe"]:
		# "_phase_*" tests are halves of a relaunch test: they run only when asked for by name
		# (in a child process started by _test_run_continue).
		if name_.begins_with("_phase") and not only.split(",", false).has(name_):
			continue
		# (--only may list several, comma-separated: to run tests together in one process.)
		var picked := only == ""
		for o in only.split(",", false):
			picked = picked or name_.contains(o)
		if picked:
			# A test that stops on a script error reports nothing; count that as a failure.
			var before: int = t.results.size()
			var started := Time.get_ticks_msec()
			await call(name_)
			print("[TIME] %s %d" % [name_, Time.get_ticks_msec() - started])
			if t.results.size() == before:
				t.check("test_completed:" + name_, false, "reported no checks (stopped on a script error?)")


# --- startup ------------------------------------------------------------------------------

## The measured milestones of THIS process's startup (no sleeps): Mote's loading screen was the
## first frame, before any world building; the world then came up in stages; nothing waited on
## the network; the first usable frame came last and the loading screen handed over.
func _test_startup() -> void:
	var at := func(label: String) -> float: return StartupTrace.ms(label)
	var shown: float = at.call("first frame drawn: Mote loading screen visible")
	var usable: float = at.call("first frame drawn: play usable")
	var order := [at.call("autoload Settings"), at.call("main scene: Game._ready begins"), shown,
			at.call("aquarium built"), at.call("moss ball 1 built"), at.call("moss ball 3 built"),
			at.call("HUD, menus, title built"), usable]
	var in_order := not order.has(-1.0)
	for i in range(1, order.size()):
		in_order = in_order and order[i] >= order[i - 1]
	t.check("startup_milestones_in_order", in_order, str(order))
	t.check("startup_loading_screen_is_first_frame", shown >= 0.0 and shown < at.call("aquarium built"), "loading screen %.1f ms, aquarium %.1f ms" % [shown, at.call("aquarium built")])
	var ls: Array = g.loading_stages
	var nb := Levels.CENTERS.size()
	var honest := not ls.is_empty() and ls.has("Growing moss ball 1 of %d" % nb) and ls.has("Growing moss ball %d of %d" % [nb, nb])
	for s in ls:
		honest = honest and not str(s).contains("%")
	t.check("startup_stages_named_no_percentages", honest, ", ".join(ls))
	t.check("startup_hands_over_to_game", g.ready_done and (not is_instance_valid(g.loading) or g.loading._fade >= 0.0), "")
	# The native bootstrap did no network work before the game was usable: its only startup work
	# is choosing a stored package, and an automatic check needs boot health first. (The game
	# layer's own launch check, AutoUpdate, is capped at AutoUpdate.LAUNCH_CAP_MS and never runs
	# in test runs; the OTA tests cover its policy.)
	var net_before := false
	# (boot_marks exists from runtime r5 on; the game layer also runs on r4 bootstraps.)
	for m in StartupTrace.timeline(Boot.get("boot_marks") if "boot_marks" in Boot else []):
		if str(m[0]).contains("automatic OTA check") and m[1] / 1000.0 < usable:
			net_before = true
	t.check("startup_no_ota_check_before_usable", usable >= 0.0 and not net_before and not Boot.auto_check("start"), "")
	t.check("startup_summary_for_pause_menu", StartupTrace.summary().begins_with("Last launch: Mote on screen after"), StartupTrace.summary())


# --- repopulation (ledger row 11; scripts/tests/repop_tests.gd) ------------------------------

func _test_repopulation() -> void:
	var rt = load("res://scripts/tests/repop_tests.gd").new(self)
	await rt.run_checks()


## Region targets, zone caps and the spots returners may use, per ball (for review).
func _phase_repop_survey() -> void:
	var rt = load("res://scripts/tests/repop_tests.gd").new(self)
	rt.survey()


## The long simulation: every ball restored, returners and food over hours of play (--minutes=N per ball).
func _phase_repop_sim() -> void:
	var rt = load("res://scripts/tests/repop_tests.gd").new(self)
	await rt.sim()


# --- Hard Mode (ledger row 12; scripts/tests/hard_tests.gd) ----------------------------------------

func _hard() -> RefCounted:
	return load("res://scripts/tests/hard_tests.gd").new(t, g, self)


## The model, the Normal guarantees, the vortex distress and the drawn vitality (in this process,
## cleaned up after; this run stays Normal).
func _test_hard_mode() -> void:
	await _hard().run_checks()


## A real Hard run saved and continued, and New Run's Hard choice (fresh child processes).
func _test_hard_mode_save() -> void:
	await _hard().save_checks()


func _phase_hard_write() -> void:
	await _hard().phase_write()


func _phase_hard_read() -> void:
	await _hard().phase_read()


func _phase_hard_finish() -> void:
	await _hard().phase_finish()


func _phase_hard_newrun() -> void:
	await _hard().phase_newrun()


func _phase_hard_intervals() -> void:
	await _hard().sim_intervals()


## §E / §E2 simulation and the chore-loop proof (--seeds=1,2,3 --hours=12).
func _phase_hard_sim() -> void:
	await _hard().sim()


# --- organic enemy movement (Open Issue #3; scripts/tests/organic_tests.gd) ------------------

func _test_organic_motion() -> void:
	var ot = load("res://scripts/tests/organic_tests.gd").new(self)
	await ot.run_checks()


## Motion traces of every enemy type for visual review (--org=on|off, --secs=120).
func _phase_organic_trace() -> void:
	var ot = load("res://scripts/tests/organic_tests.gd").new(self)
	await ot.trace()


# --- caves (Expansion 2) -------------------------------------------------------------------

func _cave_list() -> Array:
	var out := []
	for b in g.balls:
		for h in (b.get_meta("builder") as LevelBuilder).bot_hints:
			if h.has("cave"):
				out.append([b, h])
	return out


## Whether the head sphere (a little smaller than the guard's, so resting against a wall does not
## count) is in `body`'s walls or ceiling. Ground he can stand on is not a wall: walking up a
## slope, the upright head meets the rising ground, as it always has.
func _head_in(body: Node, shrink := 0.03) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = Axolotl.HEAD_RADIUS - shrink
	q.shape = sph
	q.transform = Transform3D(Basis(), p.head_center())
	q.collision_mask = 1 | 2
	var space := g.get_world_3d().direct_space_state
	var mine := false
	for hit in space.intersect_shape(q, 8):
		mine = mine or hit["collider"] == body
	if not mine:
		return false
	var pts := space.collide_shape(q, 16)
	for k in range(0, pts.size(), 2):
		var out: Vector3 = pts[k + 1] - pts[k]
		if out.length() > 0.001 and out.normalized().dot(p.up) <= cos(p.floor_max_angle):
			return true
	return false


## Caves (phone-found defects): an arched natural mouth instead of a doorway, the axolotl walks in and
## out, his head never enters the walls or ceiling, collision is exactly what is drawn, the
## ceiling is high enough over the whole floor, and each cave is its own shape.
func _test_caves() -> void:
	var caves := _cave_list()
	# (A cave whose door is sealed until its zone heals, like the Glow Chamber's boulder, is tested
	# open: the seal has its own test.)
	for b in g.balls:
		for h in (b.get_meta("builder") as LevelBuilder).bot_hints:
			if h.has("hollow") and h.has("gate") and not (h["gate"] as RestorationGate).is_open:
				(h["gate"] as RestorationGate).open(false)
	var arched := true
	var clear := true
	var dims: Array[String] = []
	var agree := true
	for c in caves:
		var h: Dictionary = c[1]
		var info: Dictionary = h["shape"]
		var widest := 0.0
		var top := 0.0
		for o in info["outline"]:
			widest = maxf(widest, o[1])
			if o[1] > 0.0:
				top = maxf(top, o[0])
		# A doorway is full width all the way up; an arch narrows toward a rounded crown.
		var full := 0
		var open := 0
		var high_w := 0.0
		for o in info["outline"]:
			if o[1] > 0.0:
				open += 1
				if o[1] >= widest * 0.9:
					full += 1
				if o[0] >= top * 0.85:
					high_w = maxf(high_w, o[1])
		arched = arched and high_w < widest * 0.6 and full < open * 0.6
		clear = clear and widest * 2.0 >= 2.3 and top >= 2.1
		dims.append("%.2f m wide x %.2f m high" % [widest * 2.0, top])
		# Collision is the drawn triangles, exactly.
		var body: StaticBody3D = h["body"]
		var mesh: ArrayMesh = (body.get_child(1) as MeshInstance3D).mesh
		var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var faces: PackedVector3Array = ((body.get_child(0) as CollisionShape3D).shape as ConcavePolygonShape3D).get_faces()
		agree = agree and verts.size() == faces.size() and verts.size() > 0
		for k in range(0, verts.size(), 97):
			agree = agree and verts[k].is_equal_approx(faces[k])
	t.check("cave_mouths_arched_not_rectangular", caves.size() == 8 and arched, ", ".join(dims))
	# Expansion 6: each reward rests on its top ledge (a small grotto's pearl had been on the ceiling).
	var off_ledge: Array[String] = []
	for c in caves:
		var h: Dictionary = c[1]
		var u = h["reward"]
		var d: float = (u.global_position as Vector3).distance_to(h["upgrade"])
		if d > 0.35:
			off_ledge.append("b%d: %.2f m from its ledge top" % [(c[0] as MossBall).index + 1, d])
	t.check("cave_rewards_on_their_top_ledge", off_ledge.is_empty(), ", ".join(off_ledge))
	t.check("cave_mouth_clearance", clear, "the axolotl is 0.6 m wide and about 0.6 m tall")
	var uniq := {}
	for d in dims:
		uniq[d] = true
	t.check("caves_vary", uniq.size() == caves.size(), "")
	t.check("cave_collision_is_drawn_mesh", agree, "")
	# Ceiling over every floor point inside (away from the walls by the axolotl's body): at least 1.8 m.
	var low := INF
	var where := ""
	for c in caves:
		var b: MossBall = c[0]
		var h: Dictionary = c[1]
		var body: StaticBody3D = h["body"]
		var centre: Vector3 = h["centre"]
		var up := b.up_at(centre)
		var fx := MossBall.frame_at(up, 0.0)
		var r_in: float = h["shape"]["interior_radius"] - 0.35
		for gx in range(-8, 9):
			for gz in range(-8, 9):
				var off := (fx.x * gx + fx.z * gz) * 0.5
				if off.length() > r_in:
					continue
				var fp := b.surface_point(b.up_at(centre + off), 0.05)
				var q := PhysicsRayQueryParameters3D.create(fp, fp + b.up_at(fp) * 8.0, 1)
				var excl: Array[RID] = []
				for k in 6:
					q.exclude = excl
					var hit := g.get_world_3d().direct_space_state.intersect_ray(q)
					if hit.is_empty():
						break
					if hit["collider"] == body:
						var hgt: float = (hit["position"] - fp).length()
						if hgt < low:
							low = hgt
							where = "ball %d" % (b.index + 1)
						break
					excl.append(hit["rid"])
	t.check("cave_ceiling_clear_over_floor", low >= 1.8, "lowest ceiling over the floor %.2f m (%s)" % [low, where])
	# Walk in through the mouth and back out.
	var through := true
	for c in caves:
		var b: MossBall = c[0]
		var h: Dictionary = c[1]
		var centre: Vector3 = h["centre"]
		var entry: Vector3 = h["entry"]
		var door: Vector3 = h["door"]
		p.invuln_t = 999
		place_at(b.index, b.surface_point(b.up_at(entry), 0.2), door - entry)
		var inside := false
		for f in 420:
			stick_toward(centre - p.global_position)
			await t.frames(1)
			if p.global_position.distance_to(centre) < float(h["shape"]["interior_radius"]) - 2.0:
				inside = true
				break
		var outside := false
		for f in 480:
			stick_toward(entry - p.global_position)
			await t.frames(1)
			if p.global_position.distance_to(entry) < 1.2:
				outside = true
				break
		p.bot_input = Vector2.ZERO
		through = through and inside and outside
		if not (inside and outside):
			t.log_line("cave ball %d: in %s out %s" % [b.index + 1, inside, outside])
	t.check("cave_walk_in_and_out", through, "")
	# Head containment: from the middle, walk straight at the wall in ten directions (jumping to
	# reach up under the vault); every frame the head stays out of the walls and ceiling.
	var frames_in := 0
	var frames := 0
	# (Walking at the walls must not collect the caves' hearts and pearls: _test_upgrades does that.)
	var pickups: Array[Node] = []
	for b in g.balls:
		for u in b.upgrades:
			if u.process_mode != Node.PROCESS_MODE_DISABLED:
				u.process_mode = Node.PROCESS_MODE_DISABLED
				pickups.append(u)
	for c in caves:
		var b: MossBall = c[0]
		var h: Dictionary = c[1]
		var body: StaticBody3D = h["body"]
		var centre: Vector3 = h["centre"]
		var up := b.up_at(centre)
		var mouth: Vector3 = (h["door"] as Vector3) - centre
		for k in 10:
			var dir := MossBall.frame_at(up, 0.0).z.rotated(up, TAU * k / 10.0)
			if dir.angle_to(mouth - up * mouth.dot(up)) < deg_to_rad(25.0):
				continue
			place_at(b.index, b.surface_point(up, 0.2), dir)
			for f in 200:
				stick_toward(dir)
				if f % 50 == 30:
					Input.action_press("jump")
				elif f % 50 == 40:
					Input.action_release("jump")
				await t.frames(1)
				frames += 1
				if _head_in(body):
					frames_in += 1
			Input.action_release("jump")
	p.bot_input = Vector2.ZERO
	for u in pickups:
		u.process_mode = Node.PROCESS_MODE_INHERIT
	t.check("cave_head_stays_out_of_walls", frames > 1000 and frames_in == 0, "%d of %d frames with the head in the rock" % [frames_in, frames])


## Mounds (the platforms, owner phone feedback "walls too straight, a perfect 90 into the
## ground"): tops exactly at their designed height, sides that sweep into the ground, and the sweep
## only standable in its lowest part (so it is no step up); the head stays out of their walls too.
func _test_mounds() -> void:
	var space := g.get_world_3d().direct_space_state
	var n := 0
	var top_ok := true
	var bad_tops: Array[String] = []
	var worst_step := 0.0
	var worst_at := ""
	for b in g.balls:
		var lb: LevelBuilder = b.get_meta("builder")
		for body in _grounded_nodes(lb.root):
			if body.get_meta("grounded") != "cushion":
				continue
			n += 1
			var centre: Vector3 = body.global_position
			var up := b.up_at(centre)
			var top: float = body.get_meta("top")
			var radius: float = body.get_meta("radius")
			# The top, straight down onto the middle (looking past anything above it, like a cave roof).
			var hit := _ray_to(space, centre + up * (top + 2.0), centre, body)
			if hit.is_empty() or absf((hit["position"] - centre).dot(up) - top) > 0.08:
				top_ok = false
				bad_tops.append("ball %d top %.2f at %s (found %s)" % [b.index + 1, top, str(Levels._latlon(up).snapped(Vector2(0.1, 0.1))), "nothing" if hit.is_empty() else "%.2f" % (hit["position"] - centre).dot(up)])
			# The flanks, on eight sides outside the top: any point Gill could stand on (slope under
			# 52 degrees) must be low, so the sweep into the ground is no step up.
			for k in 8:
				var side := MossBall.frame_at(up, 0.0).x.rotated(up, TAU * k / 8.0)
				for step in 30:
					var r := radius * 2.2 - step * 0.05
					if r <= radius * 1.02:
						break
					var from := centre + side * r + up * (top + 2.0)
					var rh := _ray_to(space, from, from - up * (top + 4.0), body)
					if rh.is_empty():
						continue
					var slope := rad_to_deg((rh["normal"] as Vector3).angle_to(b.up_at(rh["position"])))
					if slope < 52.0:
						# Height above the ground right under that point (the mound may stand on a
						# rolling hill, or in a ravine where its skirt lies on the walls).
						var hh: float = b.altitude(rh["position"])
						if hh > worst_step:
							worst_step = hh
							worst_at = "ball %d mound r %.1f top %.1f, %.2f m out, slope %.0f" % [b.index + 1, radius, top, r, slope]
	t.check("mounds_tops_at_design_height", n >= 10 and top_ok, "%d mounds %s" % [n, ", ".join(bad_tops)])
	t.check("mounds_flare_not_a_step", worst_step < 0.35, "highest standable point on a flank %.2f m above the ground (%s)" % [worst_step, worst_at])
	# Walk straight at the tutorial mound M2 (open ground): the head stops at its wall.
	var b0 := g.balls[0]
	var m2_dir := Levels.tut_dir(Levels.TUT_M2_M)
	var m2: StaticBody3D = null
	for body in _grounded_nodes((b0.get_meta("builder") as LevelBuilder).root):
		if body.get_meta("grounded") == "cushion" and (m2 == null or b0.up_at(body.global_position).angle_to(m2_dir) < b0.up_at(m2.global_position).angle_to(m2_dir)):
			m2 = body
	var up0 := b0.up_at(m2.global_position)
	var side0 := MossBall.frame_at(up0, 0.0).x
	place_at(0, b0.surface_point(b0.up_at(m2.global_position + side0 * 5.0), 0.2), -side0)
	var inside := 0
	var touched := false
	for f in 180:
		stick_toward(m2.global_position - p.global_position)
		await t.frames(1)
		if _head_in(m2):
			inside += 1
		touched = touched or _head_in(m2, -0.08)
	p.bot_input = Vector2.ZERO
	t.check("head_stays_out_of_mound_walls", touched and inside == 0, "reached the wall %s; head in it %d of 180 frames" % [touched, inside])


## First hit on `body` along a ray, looking past anything else in the way.
func _ray_to(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, body: Node) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 2)
	var excl: Array[RID] = []
	for k in 8:
		q.exclude = excl
		var hit := space.intersect_ray(q)
		if hit.is_empty() or hit["collider"] == body:
			return hit
		excl.append(hit["rid"])
	return {}


# --- vegetation (Expansion 3) ---------------------------------------------------------------

func _veg_fields(b: MossBall, family := "") -> Array:
	var out := []
	for c in b.find_child("Vegetation", false, false).get_children():
		if c.has_meta("veg_family") and (family == "" or c.get_meta("veg_family") == family):
			out.append(c)
	return out


## Largest wake bend on plants of height `h` around `centre` (sampled on a small disc).
func _bend_near(centre: Vector3, reach: float, h := 1.0) -> float:
	var b := p.ball
	var up := b.up_at(centre)
	var fx := MossBall.frame_at(up, 0.0)
	var best := 0.0
	for i in 9:
		for j in 9:
			var off := (fx.x * (i - 4) + fx.z * (j - 4)) * (reach / 4.0)
			var base := b.surface_point(b.up_at(centre + off), 0.0)
			best = maxf(best, g.wake.bend_at(b, base, h).length())
	return best


## Tall stem plants end in foliage (00040-plants, ledger row 10; DEVICE_AUDIT §C): above every
## stem's tip there are young leaves (no bare stick), each ball grows at least four variant meshes
## of both its tall crown and its smaller stem plants (no clones), the meshes keep the sway
## convention (UV.y 0 at the base to 1 at the tip) and stay within their triangle budget. Also
## the climbable leaves wear the golden-pothos look (row 15), on the same material as before.
func _test_plants_terminal_growth() -> void:
	var bare: Array[String] = []
	var tips_n := 0
	var few: Array[String] = []
	var uv_bad: Array[String] = []
	var over: Array[String] = []
	var per_ball: Array[String] = []
	for b in g.balls:
		var sets := {"tall": [], "medium": []}
		for n in b.sprout_nodes:
			var mmi := n as MultiMeshInstance3D
			if mmi == null or mmi.multimesh == null or mmi.multimesh.mesh == null or mmi.multimesh.mesh.resource_name != "stem_plant":
				continue
			var fam := "tall" if float((mmi.material_override as ShaderMaterial).get_shader_parameter("plant_height")) > 2.0 else "medium"
			if not (sets[fam] as Array).has(mmi.multimesh.mesh):
				(sets[fam] as Array).append(mmi.multimesh.mesh)
		for fam in sets:
			var meshes: Array = sets[fam]
			# Distinct meshes with distinct geometry.
			var sigs := {}
			for m in meshes:
				var v: PackedVector3Array = (m as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				sigs["%d %.4f %.4f" % [v.size(), v[v.size() / 2].x, (m as ArrayMesh).get_aabb().size.y]] = true
			if sigs.size() < 4:
				few.append("ball %d %s: %d variants" % [b.index + 1, fam, sigs.size()])
			for m in meshes:
				var arr: Array = (m as ArrayMesh).surface_get_arrays(0)
				var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
				var lo := INF
				var hi := -INF
				for u in uvs:
					lo = minf(lo, u.y)
					hi = maxf(hi, u.y)
				if absf(lo) > 0.001 or absf(hi - 1.0) > 0.001:
					uv_bad.append("ball %d %s UV.y %.3f..%.3f" % [b.index + 1, fam, lo, hi])
				var tris := (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
				if tris > (640 if fam == "tall" else 240):
					over.append("ball %d %s %d triangles" % [b.index + 1, fam, tris])
				# No bare tip: within a young leaf's reach of each stem's tip, foliage rises clearly
				# above the tip.
				for tp in (m as ArrayMesh).get_meta("tips", []):
					tips_n += 1
					var tip: Vector3 = tp[0]
					var ax: Vector3 = tp[1]
					var sz: float = tp[2]
					var above := -INF
					for v in vs:
						var d := v - tip
						var along := d.dot(ax)
						if (d - ax * along).length() <= sz * 0.6:
							above = maxf(above, along)
					if above < sz * 0.3:
						bare.append("ball %d %s: foliage only %.3f above a tip (leaf %.3f)" % [b.index + 1, fam, above, sz])
		per_ball.append("b%d %d/%d" % [b.index + 1, (sets["tall"] as Array).size(), (sets["medium"] as Array).size()])
	t.check("stem_plants_end_in_foliage", tips_n > 100 and bare.is_empty(), "%d stem tips checked; %s" % [tips_n, str(bare.slice(0, 4))])
	t.check("stem_plants_four_variants_per_ball", few.is_empty() and per_ball.size() == g.balls.size(), "tall/medium meshes per ball: %s; %s" % [", ".join(per_ball), str(few)])
	t.check("stem_plants_keep_sway_uv", uv_bad.is_empty(), str(uv_bad.slice(0, 4)))
	t.check("stem_plants_triangle_budget", over.is_empty(), str(over.slice(0, 4)))
	# The climbable leaves' material: the pothos look on, leaf data (flutter) kept.
	var pothos_ok := true
	for b in g.balls:
		var lb: LevelBuilder = b.get_meta("builder")
		pothos_ok = pothos_ok and lb.leaf_mat != null and float(lb.leaf_mat.get_shader_parameter("pothos")) == 1.0 and bool(lb.leaf_mat.get_shader_parameter("leaf_data"))
	t.check("climb_leaves_wear_pothos_look", pothos_ok, "")


## The Coral Garden's sea fan (00040-plants, owner phone report) is real 3D branching: round
## tapering branches with a radius, some fore/aft depth (never a paper-thin sheet), faces wound
## outward, a broad fan's silhouette, and collision that is exactly the drawn tubes.
func _test_sea_fan_depth() -> void:
	var fan: Node3D = null
	for n in (g.balls[0].get_meta("builder") as LevelBuilder).root.get_children():
		if n.get_meta("terrain_kind", "") == "sea fan":
			fan = n
	if not t.check("sea_fan_present", fan != null, ""):
		return
	var st: Dictionary = fan.get_meta("fan_stats", {})
	var mi: MeshInstance3D = null
	var cs: CollisionShape3D = null
	for k in fan.get_children():
		if k is MeshInstance3D:
			mi = k
		elif k is CollisionShape3D:
			cs = k
	var aabb := mi.mesh.get_aabb()
	var depth := aabb.size.z
	var width := aabb.size.x
	t.check("sea_fan_has_depth", width > 6.0 and depth >= 0.08 * width and aabb.size.y > 6.0,
			"%.2f m wide, %.2f m tall, %.2f m deep (%.0f%% of its width)" % [width, aabb.size.y, depth, depth / width * 100.0])
	t.check("sea_fan_branches_are_tubes", float(st.get("min_radius", 0.0)) >= 0.025 and int(st.get("branches", 0)) > 30,
			"%d branches, %d cross-links, %d tips; thinnest radius %.3f m" % [st.get("branches", 0), st.get("links", 0), st.get("tips", 0), st.get("min_radius", 0.0)])
	# Every branch grows out of another's tube and every cross-link ends inside one: no floating twig.
	t.check("sea_fan_no_detached_twigs", st.has("detached") and int(st["detached"]) == 0, "%s detached" % str(st.get("detached", "?")))
	var wrong := _front_faces_out_normals(mi.mesh as ArrayMesh)
	var tris := MossBall._mesh_tris(mi.mesh)
	t.check("sea_fan_faces_outward", wrong == 0, "%d of %d faces inward" % [wrong, tris])
	var faces := (cs.shape as ConcavePolygonShape3D).get_faces()
	t.check("sea_fan_collision_is_the_drawn_fan", faces.size() / 3 == tris and tris < 6000, "%d collision faces, %d drawn triangles" % [faces.size() / 3, tris])


## Faces whose winding disagrees with their own vertex normals (outward tubes).
func _front_faces_out_normals(mesh: ArrayMesh) -> int:
	var a := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var nn: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var wrong := 0
	for i in range(0, v.size(), 3):
		var n := (v[i + 2] - v[i]).cross(v[i + 1] - v[i])
		if n.length_squared() > 1e-12 and n.dot(nn[i] + nn[i + 1] + nn[i + 2]) <= 0.0:
			wrong += 1
	return wrong


## Reactive vegetation: families placed on the terrain and clear of what matters, no collision,
## and the wake (body, bow, tail and trail, plus parasites) behaves: follows the axolotl, grows
## with speed and with a tail whip, settles when he stops, recovers behind him, is the same at
## any frame rate, and never touches the global random generator.
func _test_vegetation() -> void:
	var b := g.balls[0]
	var lb: LevelBuilder = b.get_meta("builder")
	var fams := {}
	var attached := true
	var worst_alt := 0.0
	var clear_ok := true
	var clear := Levels._veg_keep_clear(lb)
	for f in _veg_fields(b):
		fams[f.get_meta("veg_family")] = fams.get(f.get_meta("veg_family"), 0) + (f.get_meta("veg_transforms") as Array).size()
		for x in f.get_meta("veg_transforms"):
			var w: Vector3 = b.global_transform * (x as Transform3D).origin
			var alt := b.altitude(w)
			worst_alt = maxf(worst_alt, absf(alt + 0.05))
			attached = attached and absf(alt + 0.05) < 0.03
			clear_ok = clear_ok and not clear.call(b.up_at(w))
	t.check("veg_families_placed", fams.get("medium", 0) >= 800 and fams.get("tall", 0) >= 800, str(fams))
	t.check("veg_rooted_on_terrain", attached, "worst %.3f m off the ground" % worst_alt)
	t.check("veg_keeps_clear_of_landmarks", clear_ok, "blooms, motes, holes, cave mouths, platforms, brittle moss, vortices")
	var bodies := 0
	for bb in g.balls:
		for n in bb.find_child("Vegetation", false, false).find_children("*", "CollisionObject3D", true, false):
			bodies += 1
	t.check("veg_has_no_collision", bodies == 0, "%d collision objects" % bodies)
	# Walking through the reeds is as quick as walking on open ground (no invisible barriers).
	var reeds := MossBall.dir_ll(-59, 31)
	var open_ := MossBall.dir_ll(-10, -40)
	var dist := []
	for at in [open_, reeds]:
		place_at(0, b.surface_point(at, 0.2), -MossBall.frame_at(at, 0.0).x)
		p.invuln_t = 999
		await t.seconds(0.3)
		var from := p.global_position
		p.bot_input = Vector2(0, 0.6)
		await t.seconds(1.0)
		p.bot_input = Vector2.ZERO
		dist.append(from.distance_to(p.global_position))
	t.check("veg_does_not_slow_or_block", dist[1] > dist[0] * 0.85, "open %.2f m, reeds %.2f m in 1 s" % [dist[0], dist[1]])
	# The wake follows him, and is stronger at speed. (His own wake: the reed bed is a stalker's
	# habitat, and one pouncing on him would swamp it; creature wakes have their own tests.)
	g.ecosystem.set_physics_process(false)
	for c in g.ecosystem.active:
		c.set_active(false)
	g.ecosystem.active = []
	# (Parasites held still too until the recovery is measured: the reed bed's large one now
	# hunts him through the reeds, which would stir the very spot being measured.)
	var held: Array = []
	for pp in b.parasites:
		if pp.is_physics_processing():
			pp.set_physics_process(false)
			held.append(pp)
	place_at(0, b.surface_point(reeds, 0.2), -MossBall.frame_at(reeds, 0.0).x)
	await t.seconds(1.5)
	var rest := _bend_near(p.body_center(), 0.8, 2.2)
	# 5 m from him, at a spot no parasite is near (they disturb plants too).
	var far := INF
	for k in 12:
		var spot := p.global_position + p.facing.rotated(p.up, TAU * k / 12.0) * 5.0
		var lonely := true
		for pp in b.parasites:
			lonely = lonely and (not pp.is_alive() or pp.global_position.distance_to(spot) > 3.0)
		if lonely:
			far = g.wake.bend_at(b, b.surface_point(b.up_at(spot), 0.0), 2.2).length()
			break
	p.bot_input = Vector2(0, 0.3)
	await t.seconds(0.8)
	var creep := _bend_near(p.body_center(), 0.8, 2.2)
	p.bot_input = Vector2(0, 1.0)
	await t.seconds(0.8)
	var run := _bend_near(p.body_center(), 0.8, 2.2)
	var ahead := g.wake.bend_at(b, b.surface_point(b.up_at(p.head_position() + p.facing * 0.5), 0.0), 2.2).length()
	t.check("wake_follows_axolotl", run > 0.8 and far < 0.01 and ahead > 0.3, "around him %.2f, 5 m away %.3f, just ahead %.2f" % [run, far, ahead])
	t.check("wake_grows_with_speed", rest < creep and creep < run * 0.85 and rest < 0.6, "standing %.2f, creeping %.2f, running %.2f" % [rest, creep, run])
	# Behind him the plants recover progressively; when he stops, the wake settles and stays settled.
	# (Measured where the trail is strongest 1-3 m behind: its samples lie about 0.6 m apart at a
	# run, so one fixed spot can fall between two of them.)
	var passed := p.global_position - p.facing * 2.0
	var just := 0.0
	for i in 21:
		var q := p.global_position - p.facing * (1.0 + i * 0.1)
		var bq := g.wake.bend_at(b, b.surface_point(b.up_at(q), 0.0), 2.2).length()
		if bq > just:
			just = bq
			passed = q
	p.bot_input = Vector2.ZERO
	await t.seconds(0.6)
	var mid := g.wake.bend_at(b, b.surface_point(b.up_at(passed), 0.0), 2.2).length()
	await t.seconds(1.4)
	var later := g.wake.bend_at(b, b.surface_point(b.up_at(passed), 0.0), 2.2).length()
	var settled1 := _bend_near(p.body_center(), 0.8, 2.2)
	await t.seconds(2.0)
	var settled2 := _bend_near(p.body_center(), 0.8, 2.2)
	g.ecosystem.set_physics_process(true)
	for pp in held:
		pp.set_physics_process(true)
	t.check("wake_recovers_behind", just > 0.3 and mid < just and later < just * 0.15, "passed %.2f, 0.6 s %.2f, 2 s %.2f (he stopped %.2f m from that spot)" % [just, mid, later, p.global_position.distance_to(passed)])
	t.check("wake_settles_when_stopped", g.wake._trail.is_empty() and absf(settled2 - settled1) < 0.02 and settled2 <= rest + 0.05,
			"%.2f then %.2f (standing level %.2f)" % [settled1, settled2, rest])
	# The tail: a swipe sweeps the plants beside the tail far harder than standing still.
	var tail_before := 0.0
	var tail_during := 0.0
	var sk := p.model.skeleton
	var tail_at := func() -> Vector3: return sk.global_transform * sk.get_bone_global_pose(9).origin
	tail_before = _bend_near(tail_at.call(), 0.9, 2.2)
	await controls_ready()
	Input.action_press("swipe")
	for f in 20:
		await t.frames(1)
		if f == 1:
			Input.action_release("swipe")
		tail_during = maxf(tail_during, _bend_near(tail_at.call(), 0.9, 2.2))
	Input.action_release("swipe")
	t.check("wake_tail_whip_sweeps", tail_during > tail_before + 0.3, "beside the tail %.2f standing, %.2f in a whip" % [tail_before, tail_during])
	# Other movers: a parasite nearby disturbs the plants around it too. (The wake follows the
	# parasites nearest the axolotl, so probe beside the nearest one, at least 3 m from him.)
	# (Earlier tests clear ball 1's parasites, so use a live one on any ball.)
	var par: Parasite = null
	for bb in g.balls:
		for pp in bb.parasites:
			if par == null and pp.is_alive() and pp.visible and bb.altitude(pp.global_position) < 0.5:
				par = pp
	var par_bend := 0.0
	var par_note := "no ground parasite left"
	if par:
		b = par.ball
		place_at(b.index, b.surface_point(b.up_at(par.global_position + MossBall.frame_at(b.up_at(par.global_position), 0).x * 6.0), 0.2), p.facing)
		p.invuln_t = 999
		await t.seconds(0.4)
		var nearest: Parasite = null
		for pp in b.parasites:
			if pp.is_alive() and pp.visible and (nearest == null or pp.global_position.distance_to(p.global_position) < nearest.global_position.distance_to(p.global_position)):
				nearest = pp
		var near_pts := 0
		for i in g.wake.count:
			var pa: Vector4 = g.wake.points_a[i]
			if Vector3(pa.x, pa.y, pa.z).distance_to(nearest.global_position) < 1.5:
				near_pts += 1
		par_note = "nearest parasite %.1f m from him, %.2f m up, state %s, %d wake points on it" % [nearest.global_position.distance_to(p.global_position),
				b.altitude(nearest.global_position), nearest.state, near_pts]
		if nearest.global_position.distance_to(p.global_position) > 3.0 and b.altitude(nearest.global_position) < 0.5:
			par_bend = g.wake.bend_at(b, b.surface_point(b.up_at(nearest.global_position + MossBall.frame_at(b.up_at(nearest.global_position), 0).z * 0.25), 0.0), 1.0).length()
	t.check("wake_parasites_disturb_plants", par != null and par_bend > 0.15, "%.2f beside a parasite (%s)" % [par_bend, par_note])
	# Frame rate: the same walk simulated at 30 and 60 fps leaves the same wake.
	b = g.balls[0]
	g.wake.set_process(false)
	var probes := []
	for fps in [30, 60]:
		place_at(0, b.surface_point(open_, 0.2), -MossBall.frame_at(open_, 0.0).x)
		p.set_physics_process(false)
		g.wake._trail.clear()
		g.wake._prev.clear()
		g.wake._speed_s = 0.0
		var start := p.global_position
		var dir := p.facing
		var dt: float = 1.0 / fps
		for k in fps:
			p.velocity = dir * 4.0
			p.global_position = start + dir * 4.0 * dt * (k + 1)
			g.wake.update(dt)
		var probe := b.surface_point(b.up_at(start + dir * 2.0 + MossBall.frame_at(p.up, 0).x * 0.4), 0.0)
		probes.append(g.wake.bend_at(b, probe, 1.0).length())
		p.set_physics_process(true)
	g.wake.set_process(true)
	p.velocity = Vector3.ZERO
	t.check("wake_frame_rate_independent", absf(probes[0] - probes[1]) < 0.12 * maxf(probes[0], probes[1]) and probes[1] > 0.04, "30 fps %.3f, 60 fps %.3f" % [probes[0], probes[1]])
	# Cosmetic only: building vegetation never moves the global random sequence gameplay uses.
	seed(77)
	var a1 := randi()
	seed(77)
	var extra := Vegetation.field(b, "medium", MossBall.dir_ll(0, 0), 3.0, 20, 5)
	var a2 := randi()
	for n in extra:
		n.queue_free()
	t.check("veg_leaves_gameplay_rng_alone", a1 == a2, "")


# --- world expansion (Expansion 4) -----------------------------------------------------------

## Every vortex mouth has open water round it: no platform, mound, cave or leaf within 4 m.
func _test_vortex_mouths_clear() -> void:
	var space := g.get_world_3d().direct_space_state
	var bad: Array[String] = []
	for v in g.vortices:
		for at_b in [false, true]:
			var bb: MossBall = v.ball_b if at_b else v.ball_a
			var q := PhysicsShapeQueryParameters3D.new()
			var sph := SphereShape3D.new()
			sph.radius = 4.0
			q.shape = sph
			q.transform = Transform3D(Basis(), v.mouth_pos(at_b))
			q.collision_mask = 1 | 2
			for hit in space.intersect_shape(q, 16):
				if hit["collider"] != bb.static_body and not hit["collider"] is Axolotl:
					bad.append("vortex %d-%d on ball %d: %s" % [v.ball_a.index + 1, v.ball_b.index + 1, bb.index + 1, hit["collider"].get_meta("terrain_kind", hit["collider"].get_meta("grounded", "body"))])
	t.check("vortex_mouths_clear", g.vortices.size() == Levels.LINKS.size() and bad.is_empty(), "%d vortices; %s" % [g.vortices.size(), ", ".join(bad)])


## The floor under a point, as his feet find it: a ray down the middle and four 6 cm off it, the
## first that lands (one ray alone can slip through a seam between two triangles of a concave mesh).
func _floor_probe(space: PhysicsDirectSpaceState3D, at: Vector3, up: Vector3) -> Dictionary:
	var side := up.cross(Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.FORWARD).normalized()
	var side2 := up.cross(side)
	for o in [Vector3.ZERO, side, -side, side2, -side2]:
		var from: Vector3 = at + o * 0.06
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from + up * 0.6, from - up * 1.0, p.collision_mask))
		if not hit.is_empty():
			return hit
	return {}


## Reachability audit (geometric): every registered climb (terraces, arch, ridge, bridge, spire,
## shelves) steps only between real standable surfaces, each within a plain jump (or jump + water
## burst) of the last, with headroom above; its elevated motes are within reach of its top.
## Whether the bubble column at `at` only flows once its zone heals.
func _column_gated(b: MossBall, at: Vector3) -> bool:
	for c in b.columns:
		var off: Vector3 = at - (c[0] as Vector3)
		if (off - (c[1] as Vector3) * off.dot(c[1])).length() <= float(c[2]) + 0.5:
			return c.size() > 5 and c[5] != null
	return false


func _test_route_audit() -> void:
	var space := g.get_world_3d().direct_space_state
	var n := 0
	var bad: Array[String] = []
	var worst_rise := 0.0
	var worst_gap := 0.0
	for b in g.balls:
		for h in (b.get_meta("builder") as LevelBuilder).bot_hints:
			if not h.has("route"):
				continue
			n += 1
			var pts: Array = [h["start"]] + (h["tops"] as Array)
			var prev: Vector3 = pts[0]
			for k in range(1, pts.size()):
				var tp: Vector3 = pts[k]
				var up := b.up_at(tp)
				# A bubble column carries him from its vent to near its top: check the column is
				# really there all the way, not a jump.
				if h.get("lift", false) and k == 1:
					var carried := true
					# (A column that flows once its zone heals is checked as it will be.)
					for f in [0.1, 0.4, 0.7, 0.9]:
						carried = carried and b.in_column(prev.lerp(tp, f) + up * 0.2)
					if not carried:
						bad.append("ball %d %s: no bubble column from its vent to its top" % [b.index + 1, h["route"]])
					prev = tp
					continue
				var hit := _floor_probe(space, tp, up)
				# (A path that rises once a zone heals is checked as risen: its spacing, not its floor.)
				var floor_ok: bool = h.get("gated", false) or (not hit.is_empty() and rad_to_deg((hit["normal"] as Vector3).angle_to(up)) < 52.0)
				var qh := PhysicsRayQueryParameters3D.create(tp + up * 0.2, tp + up * 1.4, p.collision_mask)
				var head_ok := space.intersect_ray(qh).is_empty()
				var rise := (tp - prev).dot(up)
				var gap := ((tp - prev) - up * (tp - prev).dot(up)).length()
				worst_rise = maxf(worst_rise, rise)
				worst_gap = maxf(worst_gap, gap)
				# The axolotl's measured reach (a standing plain jump: 4.0 m at 0.5 m up, 3.5 m at 1.0, 2.9 m at
				# 1.6; with the water burst 5.9-7.0 m at 1.6 m up), plus 1 m because these points lie
				# inside the surfaces, not on their edges. Ordinary climbs need only a standing plain
				# jump; those that teach or need the burst (the tutorial, cave ledges) may use it.
				var reach: float = (5.5 if rise <= 2.2 else 4.3) if h.get("burst", false) else (4.4 - 0.97 * maxf(rise, 0.0)) + 1.0
				var plain_ok: bool = h.get("burst", false) or rise <= 1.6
				# A step along one continuous walkable surface (up an arch, along a crest) is a walk,
				# not a jump.
				var walk := true
				for f in [0.2, 0.4, 0.6, 0.8]:
					var mp: Vector3 = prev.lerp(tp, f)
					var mu := b.up_at(mp)
					var mh := space.intersect_ray(PhysicsRayQueryParameters3D.create(mp + mu * 0.5, mp - mu * 0.6, p.collision_mask))
					walk = walk and not mh.is_empty() and rad_to_deg((mh["normal"] as Vector3).angle_to(mu)) < 45.0
				if walk:
					plain_ok = true
					reach = INF
				if not floor_ok or not head_ok or rise > 2.6 or not plain_ok or gap > reach:
					var what := "nothing" if hit.is_empty() else "%s at %.0f°" % [(hit["collider"] as Node).name, rad_to_deg((hit["normal"] as Vector3).angle_to(up))]
					bad.append("ball %d %s step %d: floor %s (%s) headroom %s rise %.2f gap %.2f" % [b.index + 1, h["route"], k, floor_ok, what, head_ok, rise, gap])
				prev = tp
			var end: Vector3 = pts[pts.size() - 1]
			for m in b.motes:
				if m.zone_id in h["zones"] and m.h_hint > 2.5 and m.global_position.distance_to(end) < 6.0:
					if m.global_position.distance_to(end) > 3.2:
						bad.append("ball %d %s: mote %.1f m from the top" % [b.index + 1, h["route"], m.global_position.distance_to(end)])
	for x in bad:
		t.log_line(x)
	t.check("routes_reachable_by_design", n >= 9 and bad.is_empty(), "%d climbs; biggest step up %.2f m (jump 1.85, + burst ~2.6), widest gap %.2f m; ordinary climbs within a standing plain jump" % [n, worst_rise, worst_gap])
	# Readable from the ground (owner phone report, Giant Stems): every climb starts on open
	# ground, and its first step is a plain jump up (no burst) close to where you stand, so a player
	# underneath can see where it begins. Climbs that branch off another climb start on that one.
	var unreadable: Array[String] = []
	var worst_first := 0.0
	for b in g.balls:
		for h in (b.get_meta("builder") as LevelBuilder).bot_hints:
			if not h.has("route") or h.get("branch", false):
				continue
			var st: Vector3 = h["start"]
			var up := b.up_at(st)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(st + up * 0.5, st - up * 1.0, p.collision_mask))
			var on_ground: bool = not hit.is_empty() and hit["collider"] is StaticBody3D and (hit["collider"] as StaticBody3D).collision_layer == 1 \
					and rad_to_deg((hit["normal"] as Vector3).angle_to(up)) < 52.0
			var first: Vector3 = (h["tops"] as Array)[0]
			var rise := (first - st).dot(up)
			var gap := ((first - st) - up * rise).length()
			# (A bubble column's climb begins at its vent: the bubbles show where.)
			if h.get("lift", false):
				rise = 0.0 if b.in_column(st + up * 0.5) else 99.0
				gap = 0.0
			worst_first = maxf(worst_first, rise)
			if not on_ground or rise > 1.6 or gap > 3.5:
				unreadable.append("ball %d %s: start on ground %s, first step up %.2f m, %.2f m away" % [b.index + 1, h["route"], on_ground, rise, gap])
	for x in unreadable:
		t.log_line(x)
	t.check("climbs_start_with_a_plain_step_from_the_ground", unreadable.is_empty(), "highest first step %.2f m (a plain jump reaches 1.85 m)" % worst_first)
	# Nothing that looks like a platform is out of reach: every standable leaf, brittle cap, swaying
	# leaf, mound or shelf more than 2.6 m above the ground under it lies on a climb; leaves that are
	# only decoration (no collision) hang like fronds rather than lying flat like platforms.
	var orphan_tops: Array[String] = []
	var flat_decor: Array[String] = []
	var checked := 0
	for b in g.balls:
		var lb: LevelBuilder = b.get_meta("builder")
		var pts: Array[Vector3] = []
		for h in lb.bot_hints:
			if h.has("route"):
				pts.append(h["start"])
				for q in h["tops"]:
					pts.append(q)
		for node in lb.root.get_children():
			if node.has_meta("decor_leaf"):
				var lup := b.up_at((node as Node3D).global_position)
				if absf((node as Node3D).global_basis.z.normalized().dot(lup)) < 0.5:
					flat_decor.append("ball %d %s" % [b.index + 1, node.name])
				continue
			var tp := Vector3.INF
			if node.has_meta("top_point"):
				tp = node.get_meta("top_point")
			elif node.has_meta("top") and node is Node3D:
				tp = (node as Node3D).global_transform * Vector3(0, float(node.get_meta("top")), 0)
			if tp == Vector3.INF:
				continue
			var u := b.up_at(tp)
			var gh := space.intersect_ray(PhysicsRayQueryParameters3D.create(tp - u * 0.3, b.global_position, 1))
			var above: float = (tp - (gh["position"] as Vector3)).dot(u) if gh else 0.0
			if above <= 2.6:
				continue
			checked += 1
			var near := INF
			for q in pts:
				near = minf(near, q.distance_to(tp))
			if near > 2.5:
				orphan_tops.append("ball %d %s %s %.1f m up at %s (nearest climb point %.1f m)" % [b.index + 1, node.get_meta("terrain_kind", node.get_meta("grounded", node.get_class())),
						node.name, above, Levels._latlon(b.up_at(tp)).round(), near])
	for x in orphan_tops + flat_decor:
		t.log_line(x)
	t.check("elevated_platforms_all_on_climbs", orphan_tops.is_empty() and checked > 20, "%d elevated platforms checked; %s" % [checked, str(orphan_tops)])
	t.check("decor_leaves_do_not_look_like_platforms", flat_decor.is_empty(), str(flat_decor))
	# Every elevated mote belongs to a climb that reaches it (none is decoration out of reach).
	var orphans: Array[String] = []
	for b in g.balls:
		var routes := []
		for h in (b.get_meta("builder") as LevelBuilder).bot_hints:
			if h.has("route") or h.has("tower") or h.has("mesa") or h.has("canopy"):
				routes.append(h)
		for m in b.motes:
			if m.h_hint <= 2.5:
				continue
			var served := false
			for h in routes:
				if h.has("route"):
					var tops: Array = h["tops"]
					served = served or (m.zone_id in h["zones"] and m.global_position.distance_to(tops[tops.size() - 1]) < 6.0)
				else:
					served = true if b.index < 3 else served
			if not served:
				orphans.append("ball %d %s" % [b.index + 1, m.zone_id])
	t.check("elevated_motes_have_routes", orphans.is_empty(), ", ".join(orphans))
	# Open Issue #2: a bubble column that is a platform's way up stands right beside it (its axis
	# within the cap's rim + 1.5 m of the platform's middle), so it reads as the way up. (A column
	# that only flows once its zone heals is a shortcut beside a route that is always there.)
	var far_cols: Array[String] = []
	var lifts := 0
	for b in g.balls:
		for h in (b.get_meta("builder") as LevelBuilder).bot_hints:
			if not (h.has("route") and h.get("lift", false)) or not b.in_column(h["start"]) or _column_gated(b, h["start"]):
				continue
			lifts += 1
			var tops: Array = h["tops"]
			var goal: Vector3 = tops[tops.size() - 1]
			var up := b.up_at(goal)
			var off: Vector3 = (h["start"] as Vector3) - goal
			var flat := (off - up * off.dot(up)).length()
			if flat > 4.3:
				far_cols.append("ball %d %s %.1f m" % [b.index + 1, h["route"], flat])
	t.check("lift_columns_beside_their_platforms", lifts >= 3 and far_cols.is_empty(), "%d lifts; too far: %s" % [lifts, ", ".join(far_cols)])


# --- Expansion 5: ecosystem -----------------------------------------------------------------

func _crit(sp: String, bi := -1) -> Critter:
	for c in g.ecosystem.all_critters():
		if c.species == sp and (bi < 0 or c.ball.index == bi):
			return c
	return null


## Waits until `cond` holds (up to `timeout` s of play); returns the play time it took (-1 if never).
func _until(cond: Callable, timeout: float) -> float:
	var el := 0.0
	while el < timeout:
		if cond.call():
			return el
		await t.frames(1)
		el += 1.0 / 60.0
	return -1.0


func _test_ecosystem() -> void:
	var eco: Ecosystem = g.ecosystem
	var all := eco.all_critters()
	# Habitats: every species present, each where it belongs.
	var n := {}
	for c in all:
		n[c.species] = n.get(c.species, 0) + 1
	var hab_ok := n.size() == 8
	var why: Array[String] = []
	for c in all:
		var b: MossBall = c.ball
		match c.species:
			"glowworm":
				if (c as GlowWorms).count < 20:
					why.append("ball %d glow-worms %d" % [b.index + 1, (c as GlowWorms).count])
			"snail", "hopper":
				if b.altitude(c.global_position) < 1.0:
					why.append("ball %d %s on the ground (%.2f m up)" % [b.index + 1, c.species, b.altitude(c.global_position)])
				# (A hopper can land on any step of its climb, so every one of them must be up off the moss.)
				if c.species == "hopper":
					var hop := c as LeafHopper
					for si in hop.steps.size():
						var perch := hop._perch(si)
						if b.altitude(perch) < 1.0:
							why.append("ball %d hopper perch %d at %.2f m" % [b.index + 1, si, b.altitude(perch)])
							break
			"puffer":
				# Its patch hovers well up; puffed with him close it may sink to face him, but never
				# below 0.9 m over the ground (AQ1: so a tail swipe can reach it).
				var pu := c as Pufferfish
				var home_alt: float = pu._ground_alt + pu.hover
				if home_alt < 1.2 or (not pu.defeated and b.altitude(c.global_position) < pu._ground_alt + 0.85):
					why.append("ball %d puffer low (home %.2f, now %.2f)" % [b.index + 1, home_alt, b.altitude(c.global_position)])
			"eel":
				var e := c as CaveEel
				if b.altitude(e.mouth) < 0.5 or b.altitude(e.mouth) > 2.5:
					why.append("ball %d eel mouth at %.2f m" % [b.index + 1, b.altitude(e.mouth)])
	hab_ok = hab_ok and why.is_empty()
	t.check("eco_species_in_their_habitats", hab_ok, "%s %s" % [str(n), str(why)])
	# Only the axolotl's ball, near him, runs.
	place(0, 28, 5)
	await t.seconds(0.6)
	var act_ok := not eco.active.is_empty()
	for c in eco.active:
		act_ok = act_ok and c.ball == p.ball and c.global_position.distance_to(p.global_position) < Critter.ACTIVE_RANGE
	var inactive := 0
	for c in all:
		if not c.active:
			inactive += 1
	t.check("eco_only_nearby_creatures_run", act_ok and inactive > all.size() / 2, "%d active of %d" % [eco.active.size(), all.size()])
	# Creatures never draw from the random sequence gameplay (and the test bot) rely on.
	seed(55)
	var r1 := randi()
	seed(55)
	for c in all:
		for k in 30:
			c.tick(1.0 / 60.0)
	var r2 := randi()
	t.check("eco_leaves_gameplay_rng_alone", r1 == r2, "")
	# Deterministic: two shoals from the same seed, disturbed the same way, move the same way.
	var s1 := ShrimpShoal.new()
	var s2 := ShrimpShoal.new()
	s1.place(g.balls[0], MossBall.dir_ll(20, 20), 5.0, 999)
	s2.place(g.balls[0], MossBall.dir_ll(20, 20), 5.0, 999)
	for k in 90:
		s1.tick(1.0 / 60.0)
		s2.tick(1.0 / 60.0)
	var same: bool = s1.centre.is_equal_approx(s2.centre) and s1._mm.get_instance_transform(3).origin.is_equal_approx(s2._mm.get_instance_transform(3).origin)
	for s in [s1, s2]:
		g.balls[0].critters.erase(s)
		s.queue_free()
	t.check("eco_deterministic", same, "")
	# No creature can hurt the axolotl where he respawns or arrives (blooms, arrival points).
	var unfair: Array[String] = []
	for b in g.balls:
		var spots: Array[Vector3] = [b.surface_point(b.start_dir), b.surface_point(b.arrival_dir)]
		for bl in b.blooms:
			spots.append(bl.respawn_point())
		for sp in spots:
			for c in b.critters:
				var bad := false
				if c is CrabGuardian:
					bad = (c as CrabGuardian).post.distance_to(sp) < CrabGuardian.WARN_R + 1.0
				elif c is CaveEel:
					bad = (c as CaveEel).mouth.distance_to(sp) < CaveEel.STRIKE_REACH + 1.0
				elif c is ReedStalker:
					bad = (c as ReedStalker)._in_patch(sp, 1.0)
				elif c is Pufferfish:
					bad = b.surface_point((c as Pufferfish).home_dir).distance_to(sp) < 4.0
				if bad:
					unfair.append("ball %d %s near %s" % [b.index + 1, c.species, Levels._latlon(b.up_at(sp)).round()])
	t.check("eco_no_threats_at_respawn_or_arrival", unfair.is_empty(), str(unfair))
	for sub in [_test_crab, _test_eel, _test_stalker, _test_puffer, _test_ambient]:
		await sub.call()
		t.log_line("after %s: deaths %d, cinematic '%s', on ball %d at %s" % [sub.get_method(), int(g.stats["deaths"]), g.cinematic, p.ball.index + 1, str(Levels._latlon(p.ball.up_at(p.global_position)).round())])
	# Cost: every creature near the axolotl on the busiest ball, per physics frame.
	place(2, 28, -26)
	await t.seconds(0.6)
	var t0 := Time.get_ticks_usec()
	for k in 60:
		for c in eco.active:
			c.tick(1.0 / 60.0)
	var us := (Time.get_ticks_usec() - t0) / 60.0
	t.check("eco_tick_cheap", us < 1500.0, "%d creatures active, %.0f us per frame" % [eco.active.size(), us])
	p.invuln_t = 0.0
	p.restore_full()


func _test_crab() -> void:
	var crab := _crit("crab", 3) as CrabGuardian
	var b := crab.ball
	var up := b.up_at(crab.post)
	var out := crab.facing
	p.restore_full()
	p.invuln_t = 0.0
	# Close to its post: it warns first (claws up, clack), then charges; only the charge hurts.
	var stand := b.surface_point(b.up_at(crab.post + out * 3.0), 0.2)
	place_at(b.index, stand, crab.post - stand)
	g.audio.set_ball(b.index, false)
	var h0 := p.health
	var tw: float = await _until(func(): return crab.state == "warn", 3.0)
	var hurt_in_warn := false
	var el := 0.0
	var t_charge := -1.0
	var far := 0.0
	while el < 4.0:
		await t.frames(1)
		el += 1.0 / 60.0
		if crab.state == "warn" and t_charge < 0.0 and p.health < h0:
			hurt_in_warn = true
		if crab.state == "charge" and t_charge < 0.0:
			t_charge = el
		far = maxf(far, crab.global_position.distance_to(crab.post))
	t.check("crab_warns_before_charging", tw >= 0.0 and t_charge >= CrabGuardian.WARN_TIME - 0.05 and not hurt_in_warn,
			"warned after %.2f s, charged %.2f s later" % [tw, t_charge])
	t.check("crab_charge_hurts", p.health < h0, "health %d -> %d" % [h0, p.health])
	t.check("crab_stays_in_territory", far <= CrabGuardian.TERRITORY + 0.2, "furthest %.2f m from its post" % far)
	# Leave: it walks back to its post.
	p.restore_full()
	place_at(b.index, b.surface_point(b.up_at(crab.post + out * 14.0), 0.2), out)
	await t.seconds(5.0)
	t.check("crab_returns_to_post", crab.global_position.distance_to(crab.post) < 0.7 and crab.state == "rest", "%.2f m, %s" % [crab.global_position.distance_to(crab.post), crab.state])
	# Standing at the edge of its territory: a warning, never a charge.
	p.invuln_t = 0.0
	stand = b.surface_point(b.up_at(crab.post + out * 4.5), 0.2)
	place_at(b.index, stand, crab.post - stand)
	var h1 := p.health
	var charged := false
	el = 0.0
	while el < 4.0:
		await t.frames(1)
		el += 1.0 / 60.0
		charged = charged or crab.state == "charge"
	t.check("crab_warning_only_at_the_edge", not charged and p.health == h1, "")
	# Three hits defeat it, once.
	p.invuln_t = 999
	var n0: int = g.run_save.earned().size()
	for k in 3:
		crab.hit(1, p.global_position)
		await t.seconds(0.2)
	var again := crab.hit(1, p.global_position)
	await t.seconds(0.2)
	t.check("crab_defeated_counts_once", crab.defeated and not again and g.run_save.earned().has(crab.threat_id) and g.run_save.earned().size() == n0 + 1,
			"%s earned %s" % [crab.threat_id, g.run_save.earned().has(crab.threat_id)])
	p.invuln_t = 0.0


func _test_eel() -> void:
	var eel := _crit("eel", 4) as CaveEel
	var b := eel.ball
	p.restore_full()
	p.invuln_t = 0.0
	# Behind the rock, close to the crevice: it never notices him through the wall.
	var behind := b.surface_point(b.up_at(eel.mouth - eel.normal * 1.6), 0.2)
	place_at(b.index, behind, eel.mouth - behind)
	g.audio.set_ball(b.index, false)
	var noticed: float = await _until(func(): return eel.state != "hidden", 2.5)
	t.check("eel_never_strikes_through_rock", noticed < 0.0, "")
	# In front of it: eyes and bubbles first, then the strike.
	var front := b.surface_point(b.up_at(eel.mouth + eel.normal * 2.4), 0.2)
	place_at(b.index, front, eel.mouth - front)
	var ta: float = await _until(func(): return eel.state == "alert", 2.5)
	var ts: float = await _until(func(): return eel.ext > 0.3, 2.5)
	var most := 0.0
	var el := 0.0
	while el < 1.0:
		most = maxf(most, eel.ext)
		await t.frames(1)
		el += 1.0 / 60.0
	t.check("eel_telegraphs_then_strikes", ta >= 0.0 and ts >= CaveEel.ALERT_TIME - 0.05, "alert after %.2f s, strike %.2f s later" % [ta, ts])
	t.check("eel_stays_in_its_crevice", most <= CaveEel.STRIKE_REACH + 0.01 and eel.mouth.distance_to(eel.global_position) < 0.01, "reached %.2f m" % most)
	# Swiped while it is out: two hits and it is gone for good.
	p.invuln_t = 999
	var hits := 0
	el = 0.0
	while not eel.defeated and el < 15.0:
		# (Stay in front of it: each strike knocks him back.)
		if eel.state in ["hidden", "cooldown"] and p.global_position.distance_to(front) > 0.5:
			place_at(b.index, front, eel.mouth - front)
		if eel.hittable() and eel.hit(1, p.global_position):
			hits += 1
		await t.frames(1)
		el += 1.0 / 60.0
	t.check("eel_defeated_while_out", eel.defeated and hits == 2 and g.run_save.earned().has(eel.threat_id), "%d hits" % hits)
	p.invuln_t = 0.0


func _test_stalker() -> void:
	var st := _crit("stalker", 4) as ReedStalker
	var b := st.ball
	# (The canyon's parasites graze nearby; this test is about the stalker alone, so they are held,
	# but not the creatures.)
	var held: Array = []
	for pp in b.parasites:
		if pp.is_physics_processing():
			pp.set_physics_process(false)
			held.append(pp)
	var release := func() -> void:
		for pp in held:
			if is_instance_valid(pp):
				pp.set_physics_process(true)
	p.restore_full()
	p.invuln_t = 0.0
	# The reeds move where it is before it can be seen: with him well away, its wake bends them.
	var centre := b.surface_point(st.patch_dir)
	var fr := MossBall.frame_at(st.patch_dir, 0.0)
	var outside := b.surface_point(b.up_at(centre + fr.z * (deg_to_rad(st.patch_deg) * b.radius + 9.0)), 0.2)
	place_at(b.index, outside, centre - outside)
	g.audio.set_ball(b.index, false)
	await t.seconds(1.5)
	# Plants part around it: the strongest bend on a ring just beside its body.
	var bend := 0.0
	var su := b.up_at(st.global_position)
	for k in 8:
		var ring := st.global_position + MossBall.frame_at(su, k * 45.0).z * 0.7
		bend = maxf(bend, g.wake.bend_at(b, b.surface_point(b.up_at(ring)), 3.0).length())
	# (Too far to see it: beyond the distance at which it can be discovered.)
	var away := p.body_center().distance_to(st.global_position)
	t.check("stalker_moves_the_reeds_unseen", bend > 0.2 and away > st.seen_radius and st.state == "prowl", "bend %.2f beside it, %.1f m from him" % [bend, away])
	# In its patch, close: it stalks, then telegraphs (rears, hisses, reeds thrash) before pouncing
	# along a locked line. A sidestep during the telegraph avoids the pounce.
	# (Standing on the patch side of it, in its patch and in plain sight of it: where it has prowled
	# to by now depends on how long the suite ran before, so the spot is chosen round it.)
	var up := b.up_at(st.global_position)
	var off := centre - st.global_position
	off -= up * off.dot(up)
	off = off.normalized() if off.length() > 0.5 else MossBall.frame_at(up, 0.0).z
	var near := b.surface_point(b.up_at(st.global_position + off * 3.2), 0.2)
	for k in 12:
		var cand := b.surface_point(b.up_at(st.global_position + off.rotated(up, k * TAU / 12.0) * 3.2), 0.2)
		if st._in_patch(cand, 1.0) and not st.line_blocked(st.global_position + up * 0.3, cand + b.up_at(cand) * 0.25):
			near = cand
			break
	place_at(b.index, near, st.global_position - near)
	var tt: float = await _until(func(): return st.state == "telegraph", 6.0)
	var h0 := p.health
	var lock := st._lock
	var side := lock.cross(b.up_at(p.global_position)).normalized()
	place_at(b.index, b.surface_point(b.up_at(p.global_position + side * 2.2), 0.2), p.facing)
	var tp: float = await _until(func(): return st.state == "pounce", 2.0)
	await t.seconds(0.6)
	t.check("stalker_telegraphs_then_pounces", tt >= 0.0 and tp >= ReedStalker.TELEGRAPH - 0.05, "telegraph after %.2f s, pounce %.2f s later" % [tt, tp])
	t.check("stalker_sidestep_avoids_pounce", p.health == h0 and st.heading.dot(lock) > 0.95, "")
	# Standing in the line instead: the pounce lands.
	p.invuln_t = 0.0
	var h1 := p.health
	await _until(func(): return st.state in ["stalk", "prowl"], 4.0)
	off = centre - st.global_position
	off -= b.up_at(st.global_position) * off.dot(b.up_at(st.global_position))
	off = off.normalized() if off.length() > 0.5 else MossBall.frame_at(b.up_at(st.global_position), 0.0).z
	near = b.surface_point(b.up_at(st.global_position + off * 3.0), 0.2)
	place_at(b.index, near, st.global_position - near)
	await _until(func(): return st.state == "telegraph", 6.0)
	await _until(func(): return st.state == "recover", 2.0)
	t.check("stalker_pounce_hurts_in_line", p.health < h1, "health %d -> %d" % [h1, p.health])
	# Out of its patch it gives up.
	p.invuln_t = 999
	place_at(b.index, outside, centre - outside)
	var gave: float = await _until(func(): return st.state == "prowl", 5.0)
	t.check("stalker_gives_up_outside_its_patch", gave >= 0.0, "")
	# Driven off, it comes back to its patch later, when he is away.
	st.hit(1, p.global_position)
	await t.frames(2)
	st.hit(1, p.global_position)
	var gone := st.defeated and not st.visible
	g.clock.play_s += ReedStalker.RETURN_AFTER + 1.0
	place_at(b.index, b.surface_point(b.up_at(centre + fr.z * 32.0), 0.2), fr.z)
	var back: float = await _until(func(): return not st.defeated, 2.0)
	t.check("stalker_driven_off_then_returns", gone and back >= 0.0 and st._in_patch(st.global_position, 0.5), "")
	release.call()
	p.invuln_t = 0.0


func _test_puffer() -> void:
	var pf := _crit("puffer", 1) as Pufferfish
	var b := pf.ball
	p.restore_full()
	p.invuln_t = 0.0
	var under := b.surface_point(b.up_at(pf.global_position), 0.2)
	var aside := b.surface_point(b.up_at(pf.global_position + MossBall.frame_at(b.up_at(under), 0).z * 2.0), 0.2)
	place_at(b.index, aside, under - aside)
	g.audio.set_ball(b.index, false)
	# (From calm: an earlier visit may have left it puffed, frozen so while he was far away.)
	pf.inflate = 0.0
	pf.puffed = false
	var tin: float = await _until(func(): return pf.inflate > 0.99, 3.0)
	t.check("puffer_puffs_up_near", tin >= PufferFish_INFLATE_MIN and pf.puffed, "fully puffed after %.2f s" % tin)
	# Touching it puffed hurts once (then a pause); a swipe bats it away, it is not beaten.
	# (It may already have brushed him while puffing up: start from a clean slate.)
	p.restore_full()
	p.invuln_t = 0.0
	pf.contact_cd = 0.0
	var h0 := p.health
	pf.global_position = p.body_center() + b.up_at(p.global_position) * 0.4
	await t.frames(2)
	var h1 := p.health
	pf.global_position = p.body_center() + b.up_at(p.global_position) * 0.4
	await t.frames(20)
	t.check("puffer_contact_hurts_once", h1 == h0 - 1 and p.health >= h1 - 0, "health %d -> %d -> %d" % [h0, h1, p.health])
	p.invuln_t = 0.0
	p.restore_full()
	await _test_puffer_beaten()


## The pufferfish can be beaten with the tail swipe, pressed as a player would (it was unbeatable:
## hit() only batted it away, and the one hovering 3.2 m up over Reed Canyon's crests floated out of
## the swipe's reach). Standing under that one: it notices him, puffs, sinks to face him, and three
## swipes that land beat it. Each hit knocks it back; it is never left unhittable; beaten, it is gone
## (no contact damage, nothing to hit), earns nothing, and returns to its patch later.
func _test_puffer_beaten() -> void:
	var pf: Pufferfish = null
	for c in g.ecosystem.all_critters():
		if c is Pufferfish and (pf == null or (c as Pufferfish).hover > pf.hover):
			pf = c
	var b := pf.ball
	var release := _hold_threats(b)
	g.ecosystem.set_physics_process(true)   # (the puffer itself must run; nothing else nearby does)
	for c in g.ecosystem.all_critters():
		if c != pf and c.ball == b:
			c.set_active(false)
	p.restore_full()
	p.invuln_t = 999.0
	pf.hp = Pufferfish.HP
	pf.puffed = false
	pf.inflate = 0.0
	var home := b.surface_point(pf.home_dir, 0.2)
	place_at(b.index, home, MossBall.frame_at(pf.home_dir, 0).z)
	var start_gap: float = b.altitude(pf.global_position) - b.altitude(p.body_center())
	var reach: float = await _until(func(): return g._swipe_offset(p, pf) != Vector3.ZERO, 6.0)
	var earned0: int = g.run_save.earned().size()
	var presses := 0
	var landed := 0
	var hp_seen := []
	for i in 12:
		if pf.defeated:
			break
		# Keep it in reach, as a player would step toward it; then swipe.
		for k in 40:
			var flat: Vector3 = pf.global_position - p.global_position
			flat -= p.up * flat.dot(p.up)
			if flat.length() < 1.3 and g._swipe_offset(p, pf) != Vector3.ZERO:
				break
			stick_toward(flat.normalized())
			await t.frames(3)
		p.bot_input = Vector2.ZERO
		var hp0 := pf.hp
		await press("swipe")
		presses += 1
		await t.seconds(0.45)
		if pf.hp < hp0:
			landed += 1
			hp_seen.append(pf.hp)
	var stuck: bool = pf.hit_cd > Pufferfish.HIT_CD + 0.01
	t.check("puffer_beaten_by_tail_swipes", pf.defeated and landed == Pufferfish.HP and hp_seen == [2, 1, 0], "from %.1f m above him it came into reach after %.1f s; %d presses, %d landed %s, beaten %s" % [start_gap, reach, presses, landed, str(hp_seen), pf.defeated])
	var h0 := p.health
	p.invuln_t = 0.0
	pf.global_position = p.body_center()
	await t.frames(10)
	t.check("puffer_beaten_is_gone", not pf.visible and not pf.hittable() and not pf.is_alive() and p.health == h0 and not stuck and g.run_save.earned().size() == earned0, "visible %s hittable %s health %d -> %d earned %d -> %d" % [pf.visible, pf.hittable(), h0, p.health, earned0, g.run_save.earned().size()])
	g.clock.play_s += Pufferfish.RETURN_AFTER + 1.0
	place_at(b.index, b.surface_point(b.up_at(home + MossBall.frame_at(pf.home_dir, 0).z * 30.0), 0.2), MossBall.frame_at(pf.home_dir, 0).z)
	var back: float = await _until(func(): return not pf.defeated, 2.0)
	t.check("puffer_returns_later", back >= 0.0 and pf.visible and pf.hp == Pufferfish.HP, "")
	for c in g.ecosystem.all_critters():
		c.set_active(false)
	g.ecosystem.active = []
	release.call()
	p.invuln_t = 0.0
	p.restore_full()


const PufferFish_INFLATE_MIN := 0.5


func _test_ambient() -> void:
	# (Behaviour only: nothing here may hurt him, e.g. a parasite grazing near the shoal.)
	p.restore_full()
	p.invuln_t = 999.0
	# Shrimp scatter when he rushes at them, and drift back together.
	var sh := _crit("shrimp", 0) as ShrimpShoal
	var b := sh.ball
	var from := b.surface_point(b.up_at(sh.centre + MossBall.frame_at(b.up_at(sh.centre), 0).z * 6.0), 0.2)
	place_at(b.index, from, sh.centre - from)
	g.audio.set_ball(b.index, false)
	var ran: float = await _until(func():
		stick_toward(sh.centre - p.global_position)
		return sh.scatter > 0.9, 4.0)
	p.bot_input = Vector2.ZERO
	var calm: float = await _until(func(): return sh.scatter < 0.05, 12.0)
	t.check("shrimp_scatter_then_regroup", ran >= 0.0 and calm >= 0.0, "scattered after %.2f s, regrouped %.2f s later (he is %.1f m from them, grounded %s, speed %.1f, at %s, deaths %d, ravine falls %d, cine %s)" % [ran, calm,
			p.global_position.distance_to(sh.centre), p.grounded, p.velocity.length(), str(Levels._latlon(b.up_at(p.global_position)).round()), int(g.stats["deaths"]), int(g.stats.get("ravine_falls", 0)), g.cinematic])
	# A snail tucks into its shell when he comes close.
	var sn := _crit("snail", 5) as CanopySnail
	b = sn.ball
	place_at(b.index, sn.global_position + b.up_at(sn.global_position) * 0.3 + MossBall.frame_at(b.up_at(sn.global_position), 0).z * 1.2, -MossBall.frame_at(b.up_at(sn.global_position), 0).z)
	g.audio.set_ball(b.index, false)
	var tuck: float = await _until(func(): return sn.tuck > 0.9, 2.0)
	t.check("snail_tucks_in_when_near", tuck >= 0.0, "")
	# A hopper springs up its climb ahead of him: settled on its step, then he lands on its leaf (as
	# a player climbing up to it does).
	var hp_ := _crit("hopper", 5) as LeafHopper
	b = hp_.ball
	await _until(func(): return hp_._hop < 0.0 and hp_._rest <= 0.0, 3.0)
	var i0 := hp_.index
	var h0 := b.altitude(hp_.global_position)
	place_at(b.index, hp_.global_position + b.up_at(hp_.global_position) * 1.0, -MossBall.frame_at(b.up_at(hp_.global_position), 0).z)
	await _until(func(): return hp_.index != i0 and hp_._hop < 0.0, 3.0)
	t.check("hopper_leads_up_the_climb", hp_.index > i0 and b.altitude(hp_.global_position) > h0 + 0.5, "step %d -> %d, %.1f -> %.1f m" % [i0, hp_.index, h0, b.altitude(hp_.global_position)])
	# Glow-worms dim and draw up near him.
	var gw := _crit("glowworm", 0) as GlowWorms
	b = gw.ball
	place_at(b.index, b.surface_point(b.up_at(gw.cave_centre), 0.2), MossBall.frame_at(b.up_at(gw.cave_centre), 0).z)
	g.audio.set_ball(b.index, false)
	await t.seconds(0.6)
	var pp: Vector3 = gw._mat.get_shader_parameter("player_pos")
	t.check("glowworms_react_to_him", gw.count >= 20 and pp.distance_to(p.body_center()) < 0.5, "%d worms" % gw.count)
	# Every species is a discovery, counted once.
	var ids := 0
	for id in g.run_save.earned():
		if str(id).begins_with("species."):
			ids += 1
	g.discover_species("snail")
	g.discover_species("snail")
	var after := 0
	for id in g.run_save.earned():
		if str(id).begins_with("species."):
			after += 1
	t.check("species_discovered_once", g.species_known("snail") and after - ids <= 1 and g.completion.has("species.snail"), "%d species known" % after)


## The new areas: four more balls, each distinct (size, palette, landmarks), linked as branches;
## their content is in the completion catalog; their caves are natural and hold pearls.
func _test_new_areas() -> void:
	t.check("world_has_seven_balls", g.balls.size() == 7 and g.vortices.size() == 6, "%d balls, %d vortices" % [g.balls.size(), g.vortices.size()])
	var sizes := {}
	var kinds := {}
	for bi in range(3, g.balls.size()):
		var b := g.balls[bi]
		sizes[b.radius] = true
		var ks := {}
		for c in (b.get_meta("builder") as LevelBuilder).root.get_children():
			if c.has_meta("terrain_kind"):
				ks[c.get_meta("terrain_kind")] = true
		kinds[bi] = ks.keys()
	t.check("new_balls_distinct", sizes.size() == 4 and str(kinds[3]) != str(kinds[4]) and str(kinds[4]) != str(kinds[5]) and str(kinds[5]) != str(kinds[6]), str(kinds))
	var pearls := 0
	for bi in range(3, g.balls.size()):
		for u in g.balls[bi].upgrades:
			pearls += 1 if u.kind == "pearl" else 0
	# (Four grottoes since Expansion 4; the world expansion added Hollow Grotto's Glow Chamber.)
	t.check("new_caves_hold_pearls", pearls == 5, "%d pearls" % pearls)
	# Blooms (where a continued run resumes) in the new areas have something to stand on right
	# under their respawn point (ground or a formation's top, never a formation's flank), so the
	# axolotl respawns standing where he is placed.
	var perched := []
	var space := g.get_world_3d().direct_space_state
	for bi in range(3, 7):
		var bb: MossBall = g.balls[bi]
		for bl in bb.blooms:
			var rp: Vector3 = bl.respawn_point()
			var u := bb.up_at(rp)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(rp + u * 0.3, rp - u * 3.0))
			var drop: float = (rp - hit["position"]).dot(u) if hit else 99.0
			var steep: bool = hit and (hit["normal"] as Vector3).dot(u) < cos(p.floor_max_angle)
			if drop > 0.6 or steep:
				perched.append("ball %d %s: %.2f m above %s" % [bi + 1, bl.get_meta("completion_id", "?"), drop, "a slope" if steep else "support"])
	t.check("new_blooms_resume_standing", perched.is_empty(), str(perched))
	var ids := g.completion.order.filter(func(id): return id.begins_with("b4.") or id.begins_with("b5.") or id.begins_with("b6.") or id.begins_with("b7."))
	t.check("new_areas_in_completion", ids.size() > 40 and g.completion.has("vortex.b1-b4") and g.completion.has("vortex.b4-b7") and g.completion.has("b7.restored"), "%d new ids" % ids.size())


# --- run timer, completion, run save ----------------------------------------------------

## Pinned: the current game's completion ids (sha256 of the ids in catalog order). A change means
## completion content changed: bump Completion.CATALOG_VERSION, update docs/COMPLETION.md, re-pin.
const CATALOG_IDS_SHA := "1cfa75341286c8804e19109c0aac54ad8dbc28c36e6066a4a885806df66176bf"
const CATALOG_SIZE := 348


## The timer's rules on a bare clock: start, what counts, background, finish, frame rates.
func _test_run_clock() -> void:
	var c := RunClock.new()
	c.tick(1.0, true)
	t.check("timer_new_run_starts_at_zero_not_started", c.state == "not_started" and c.run_s == 0.0, "")
	t.check("timer_starts_once", c.start() and not c.start() and c.state == "running", "")
	for i in 60:
		c.tick(1.0 / 60.0, true)
	var one := c.run_s
	for i in 60:
		c.tick(1.0 / 60.0, false)
	t.check("timer_counts_active_play_only", is_equal_approx(one, 1.0) and is_equal_approx(c.run_s, 1.0), "%.4f then %.4f" % [one, c.run_s])
	c.suspend()
	c.tick(0.2, true)
	c.resume()
	c.tick(30.0, true)
	c.tick(0.1, true)
	t.check("timer_background_not_counted", is_equal_approx(c.run_s, 1.1), "%.4f (backgrounded 0.2 s, 30 s resume frame discarded)" % c.run_s)
	c.tick(5.0, true)
	t.check("timer_frame_cap", is_equal_approx(c.run_s, 1.1 + RunClock.MAX_FRAME_S), "%.4f" % c.run_s)
	var before := c.run_s
	t.check("timer_finish_freezes", c.finish() and c.finish_s == before and not c.finish(), "%.3f" % c.finish_s)
	for i in 120:
		c.tick(1.0 / 60.0, true)
	t.check("timer_after_finish_frozen", c.finish_s == before and c.run_s == before and c.shown_s() == before and c.play_s > before + 1.9,
			"finish %.3f, play %.3f" % [c.finish_s, c.play_s])
	var c2 := RunClock.from_dict(JSON.parse_string(JSON.stringify(c.to_dict(), "", true, true)))
	t.check("timer_survives_serialisation", c2.state == "finished" and c2.finish_s == c.finish_s and c2.play_s == c.play_s, "")
	# Same simulated play at different frame rates: same time (to within one frame).
	var times: Array[float] = []
	for fps in [30, 60, 144]:
		var k := RunClock.new()
		k.start()
		for i in 600 * fps / 60:
			k.tick(1.0 / fps, true)
		times.append(k.run_s)
	t.check("timer_same_across_frame_rates", absf(times[0] - 10.0) < 1e-6 and absf(times[1] - 10.0) < 1e-6 and absf(times[2] - 10.0) < 1e-6, str(times))
	# Never the wall clock: the timer code reads no clock at all, and the game feeds it frame deltas.
	# (An exported pack holds compiled scripts only; this source check runs in the project, as CI does.)
	var src := FileAccess.get_file_as_string("res://scripts/core/run_clock.gd")
	var gsrc := FileAccess.get_file_as_string("res://scripts/core/game.gd")
	if src == "" or gsrc == "":
		t.log_line("timer_wall_clock_independent: script source not in this build (exported pack); checked in the project run")
	else:
		var clean := not src.contains("Time.") and not src.contains("OS.get_") and not src.contains("unix")
		t.check("timer_wall_clock_independent", clean and gsrc.contains("clock.tick(dt, state == \"play\")"), "")
	t.check("timer_format_long_runs", RunClock.format(0.0) == "0.00" and RunClock.format(65.432) == "1:05.43" and RunClock.format(3723.456) == "1:02:03.45"
			and RunClock.format(360000.0) == "100:00:00.00", "%s %s %s" % [RunClock.format(65.432), RunClock.format(3723.456), RunClock.format(360000.0)])


## The catalog: ids, percentages, finishing vs 100%, duplicates, growth.
func _test_completion_catalog() -> void:
	var cat: Completion = g.completion
	var ids := "\n".join(cat.order)
	var sha := ids.sha256_text()
	var cat_counts := cat.categories({})
	t.log_line("catalog v%d: %d entries; %s" % [Completion.CATALOG_VERSION, cat.size(), str(cat_counts.keys().map(func(k): return "%s %d" % [k, int(cat_counts[k]["total"])]))])
	t.check("completion_ids_unique_and_pinned", cat.size() == CATALOG_SIZE and cat.entries.size() == cat.order.size() and sha == CATALOG_IDS_SHA,
			"%d ids, sha %s" % [cat.size(), sha])
	var share := 0.0
	for c in Completion.CATEGORIES:
		share += Completion.CATEGORIES[c][1]
	t.check("completion_shares_sum_to_100", is_equal_approx(share, 100.0), "%.1f" % share)
	t.check("completion_zero", cat.percent({}) == 0.0 and cat.remaining({}).size() == cat.size(), "")
	var half := {}
	for id in cat.order.slice(0, 20):
		half[id] = 1
	var pc := cat.percent(half)
	t.check("completion_partial", pc > 0.0 and pc < 100.0 and cat.remaining(half).size() == cat.size() - 20, "%.2f%%" % pc)
	# Finishing (every ball restored) without the caves, blooms and wildlife: below 100%
	# (restoration 45% + milestones 13.5% since catalog version 3 added wildlife).
	var fin := {}
	for id in cat.order:
		if cat.entries[id]["category"] in ["restoration", "milestones"]:
			fin[id] = 1
	t.check("completion_finished_below_100", is_equal_approx(cat.percent(fin), 58.5) and cat.percent_display(fin) == 58, "%.2f%%" % cat.percent(fin))
	var all := {}
	for id in cat.order:
		all[id] = 1
	var all_but := all.duplicate()
	all_but.erase(cat.order[cat.order.size() - 1])
	t.check("completion_exactly_100", cat.percent(all) == 100.0 and cat.remaining(all).is_empty() and cat.percent(all_but) < 100.0
			and cat.percent_display(all_but) <= 99, "all %.2f, all but one %.2f" % [cat.percent(all), cat.percent(all_but)])
	var extra := all.duplicate()
	extra["b9.future.thing"] = 1
	t.check("completion_never_above_100", cat.percent(extra) == 100.0 and cat.earned_known(extra).size() == cat.size(), "")
	# Duplicates: earning an id twice counts once (on a copy of this run's earned ids).
	var saved := g.run_save.earned().duplicate()
	var id0: String = cat.order[0]
	g.run_save.earned().erase(id0)
	var n := g.run_save.earned().size()
	var first := g._earn(id0)
	var second := g._earn(id0)
	t.check("completion_duplicate_counts_once", first and not second and g.run_save.earned().size() == n + 1, "")
	g.run_save.run()["earned"] = saved
	# Growth: a later OTA adds content. The denominator grows, the percentage may drop, nothing earned is lost.
	var grown := Completion.build_from_world(g.balls, g.vortices)
	grown.add("b9.meadow.mote.0", "restoration", "Mote returned")
	grown.add("b9.cave.0", "caves", "Hidden cave")
	var was := cat.percent(all)
	var now := grown.percent(all)
	t.check("completion_growth_changes_denominator", grown.size() == cat.size() + 2 and now < was and now > 90.0
			and grown.earned_known(all).size() == cat.size() and grown.remaining(all) == ["b9.meadow.mote.0", "b9.cave.0"], "%.2f%% -> %.2f%%" % [was, now])
	# Every completion-bearing node carries its id.
	var stamped := true
	for b in g.balls:
		for n2 in b.parasites + b.motes + b.upgrades + b.blooms:
			stamped = stamped and cat.has(n2.get_meta("completion_id", ""))
	t.check("completion_ids_on_world", stamped, "")


## World expansion: every completion id a released OTA could have awarded is still in the catalog
## (CatalogFrozen), and explicit ids on authored content are honoured while positional ones step
## round them.
func _test_completion_frozen() -> void:
	var cat: Completion = g.completion
	var missing := []
	for id in CatalogFrozen.V3:
		if not cat.has(id):
			missing.append(id)
	# A save from before the expansion (everything v3 listed earned) keeps all of it and counts
	# below 100% now (the new content is still to find); every bloom it could resume at is still one.
	var v3_earned := {}
	for id in CatalogFrozen.V3:
		v3_earned[id] = true
	var v3_pct: float = cat.percent(v3_earned)
	var bloom_ok := true
	for id in CatalogFrozen.V3:
		if str(id).contains(".bloom."):
			var bi := int(str(id).substr(1, str(id).find(".") - 1)) - 1
			var k := int(str(id).get_slice(".", 2))
			bloom_ok = bloom_ok and k < g.balls[bi].blooms.size() and str(g.balls[bi].blooms[k].get_meta("completion_id", "")) == str(id)
	t.check("v3_save_migrates", v3_pct > 30.0 and v3_pct < 100.0 and bloom_ok, "a v3 save counts %.1f%% now; its blooms all resolve %s" % [v3_pct, bloom_ok])
	t.check("shipped_completion_ids_kept", missing.is_empty() and CatalogFrozen.V3.size() == 172, "%d of %d v3 ids missing: %s" % [missing.size(), CatalogFrozen.V3.size(), str(missing.slice(0, 8))])
	# Explicit ids: two parasites in one zone, the second authored as ".0"; the first takes ".1".
	var b := g.balls[0]
	var zone: String = b.parasites[0].zone_id
	var saved := b.parasites.duplicate()
	var tag := Completion.ball_tag(0)
	# (Stand-ins with just the fields the builder reads.)
	var stand := func(fixed: String) -> Parasite:
		var pp := Parasite.new()
		pp.zone_id = "probe"
		if fixed != "":
			pp.set_meta("fixed_id", fixed)
		return pp
	var a: Parasite = stand.call("")
	var c: Parasite = stand.call(tag + ".probe.parasite.0")
	b.parasites = [a, c]
	var probe := Completion.build_from_world([b], [])
	b.parasites = saved
	var ids := [a.get_meta("completion_id"), c.get_meta("completion_id")]
	t.check("explicit_completion_ids_honoured", ids == [tag + ".probe.parasite.1", tag + ".probe.parasite.0"] and probe.has(ids[0]) and probe.has(ids[1]), str(ids))
	a.free()
	c.free()


## The run save file: new, reload, migration, damage, newer formats, best time, new run.
func _test_run_save_file() -> void:
	var dir := "user://run_save_test"
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("run.json")
	RunSave.erase(path)
	# Existing players: settings.cfg only, no run file. Nothing is invented.
	var rs := RunSave.open(path)
	t.check("run_save_migration_from_no_progress", rs.origin.begins_with("new") and rs.earned().is_empty() and rs.run()["clock"]["state"] == "not_started"
			and rs.records()["best_finish_s"] < 0.0 and (rs.records()["finishes"] as Array).is_empty()
			and str(rs.data["history"].get("migration", "")).begins_with("none"), rs.origin)
	rs.earned()["b1.tut.parasite.0"] = 1.5
	var ck := RunClock.new()
	ck.start()
	ck.tick(0.2, true)
	rs.run()["clock"] = ck.to_dict()
	t.check("run_save_writes", rs.save() and FileAccess.file_exists(path), rs.last_save_result)
	var rs2 := RunSave.open(path)
	t.check("run_save_reloads", rs2.origin == "loaded" and rs2.earned().has("b1.tut.parasite.0") and is_equal_approx(float(rs2.run()["clock"]["run_s"]), 0.2)
			and rs2.run()["id"] == rs.run()["id"], rs2.origin)
	# Best time: kept across runs, only improved by a faster finish.
	rs2.record_finish(100.0, 70.0, 1, {})
	rs2.start_new_run()
	rs2.record_finish(90.0, 80.0, 1, {})
	rs2.start_new_run()
	rs2.record_finish(120.0, 100.0, 1, {})
	t.check("run_save_best_time", rs2.records()["best_finish_s"] == 90.0 and (rs2.records()["finishes"] as Array).size() == 3, str(rs2.records()["best_finish_s"]))
	rs2.start_new_run()
	t.check("run_save_new_run_keeps_records", rs2.earned().is_empty() and rs2.records()["best_finish_s"] == 90.0, "")
	rs2.save()
	# A damaged file falls back to the backup; the damaged file is never deleted silently.
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	var rs3 := RunSave.open(path)
	t.check("run_save_damaged_uses_backup", rs3.origin.begins_with("recovered from backup") and rs3.earned().has("b1.tut.parasite.0"), rs3.origin)
	# A file from a newer format is never overwritten.
	var newer := {"format": RunSave.FORMAT + 1, "run": {"earned": {"x": 1}}, "records": {}}
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(newer))
	f.close()
	var rs4 := RunSave.open(path)
	var wrote := rs4.save()
	var still: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	t.check("run_save_newer_format_untouched", rs4.read_only and not wrote and int(still["format"]) == RunSave.FORMAT + 1, rs4.origin)
	# Older/partial data is completed conservatively: nothing earned is dropped.
	var old := RunSave.migrate({"format": 0, "run": {"earned": {"b1.bloom.0": 3.0}}})
	t.check("run_save_migrates_partial_data", old["format"] == RunSave.FORMAT and (old["run"]["earned"] as Dictionary).has("b1.bloom.0")
			and old["run"].has("clock") and old["records"]["best_finish_s"] < 0.0, "")
	# OTAs never touch the run save: the OTA client only uses user://ota.
	var boot_src := FileAccess.get_file_as_string("res://scripts/boot/ota_core.gd") + FileAccess.get_file_as_string("res://scripts/boot/boot.gd")
	if boot_src == "":
		t.log_line("run_save_outside_ota_storage: script source not in this build (exported pack); checked in the project run")
	else:
		t.check("run_save_outside_ota_storage", boot_src.contains("user://ota") and not boot_src.contains("run.json") and RunSave.PATH == "user://run.json", "")
	RunSave.erase(path)
	for x in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(x))


## The live game: the run started at play; play counts; the pause menu and background do not;
## saving writes the clock; Diagnostics and the UI show it.
func _test_run_timer_live() -> void:
	t.check("timer_started_at_play", g.clock.state in ["running", "finished"] and g.state == "play", g.clock.state)
	var a := g.clock.run_s
	await t.seconds(1.0)
	var b := g.clock.run_s
	t.check("timer_advances_in_play", absf(b - a - 1.0) < 0.05, "%.3f s for 1 s of play" % (b - a))
	g.pause_menu.open()
	await t.seconds(1.0)
	var c := g.clock.run_s
	g.pause_menu.close()
	t.check("timer_paused_by_pause_menu", c == b, "%.3f -> %.3f" % [b, c])
	await t.frames(2)
	g._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var d := g.clock.run_s
	await t.seconds(1.0)
	var e := g.clock.run_s
	# What going to the background wrote (read before resuming, when later autosaves may follow).
	var on_disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(g.run_save.path))
	g._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await t.seconds(0.5)
	t.check("timer_paused_in_background", e == d and g.clock.run_s > e, "%.3f -> %.3f while backgrounded" % [d, e])
	t.check("run_saved_when_backgrounded", is_equal_approx(float(on_disk["run"]["clock"]["run_s"]), d), "%.3f on disk" % float(on_disk["run"]["clock"]["run_s"]))
	var diag := StartupTrace.timeline_text()
	t.check("diagnostics_show_run_timer", diag.contains("Run timer & completion") and diag.contains("Timer state: running") and diag.contains("Completion:")
			and diag.contains("format %d" % RunSave.FORMAT), "")
	Settings.show_run_timer = true
	await t.frames(2)
	var shown := g.hud.timer_label.visible and g.hud.timer_label.text.contains(".")
	Settings.show_run_timer = false
	await t.frames(2)
	t.check("hud_run_timer_toggle", shown and not g.hud.timer_label.visible, "")
	g.pause_menu.open()
	await t.frames(2)
	var pm := g.pause_menu
	var ok: bool = pm._run_time.text.begins_with("Run time") and pm._run_time.text.contains("% complete") and pm._run_detail.text.contains("Game finished: not yet")
	g.pause_menu.close()
	t.check("pause_menu_shows_run", ok, pm._run_time.text)
	# The title offers Continue and New Run for a saved run, and New Run asks first.
	g.title.show_title()
	var ask: Button = g.title._new_run.find_child("Ask", true, false)
	var titled: bool = g.title._play.text == "Continue" and g.title._new_run.visible and g.title._run_info.text.begins_with("Run time")
	ask.pressed.emit()
	var asks: bool = not ask.visible and (g.title._new_run.find_child("Yes", true, false) as Button).is_visible_in_tree()
	g.title.hide_title()
	t.check("title_continue_and_new_run", titled and asks and g.state == "play", g.title._run_info.text)


## Relaunch: a child process plays and saves, a second child continues the same run.
func _test_run_continue() -> void:
	var path := "user://continue_test.json"
	RunSave.erase(path)
	# Same engine, same game (a project folder or an exported pack), headless, fixed 60 fps.
	var base: Array = ["--headless", "--fixed-fps", "60", "--max-fps", "0"]
	# Godot consumes --main-pack, so a run from an exported pack names its file with --pack=<file>.
	var project := ProjectSettings.globalize_path("res://")
	if Settings.test_args.has("pack"):
		base += ["--main-pack", Settings.test_args["pack"]]
	elif project != "":
		base += ["--path", project]
	else:
		t.check("relaunch_children_ran", false, "running from an exported pack: pass --pack=<its file> to run the relaunch test")
		return
	var outs := []
	for phase in ["_phase_continue_write", "_phase_continue_read"]:
		var out := []
		var cmd: Array = base + ["--", "--test=unit", "--only=" + phase, "--run-save=" + path, "--out=" + ProjectSettings.globalize_path("user://continue_out")]
		var code := OS.execute(OS.get_executable_path(), cmd, out, true)
		outs.append(code)
		if code != 0:
			t.log_line("%s exited %d; output:\n%s" % [phase, code, str(out[0]).right(3000)])
		for line in str(out[0]).split("\n"):
			if line.begins_with("[TEST] PASS") or line.begins_with("[TEST] FAIL"):
				var parts := line.substr(7).split(" ", false, 2)
				t.check("relaunch/" + parts[1], parts[0] == "PASS", parts[2] if parts.size() > 2 else "")
	t.check("relaunch_children_ran", outs == [0, 0], str(outs))
	RunSave.erase(path)


## First launch: play a little, clear things, find a bloom and a cave, then save (as quitting does).
func _phase_continue_write() -> void:
	var b := g.balls[0]
	var par: Parasite = b.parasites[0]
	par.hit_cd = 0.0
	par.hit(par.hp, par.global_position)
	var m: Mote = b.motes[0]
	place(0, 0, 0)
	p.global_position = m.global_position
	m.capture()
	await t.seconds(1.5)
	# Clearing the tutorial patch plays its framing shot; blooms are found in normal play.
	var waited := 0
	while (g.cinematic != "" or waited < 90) and waited < 900:
		await t.frames(1)
		waited += 1
	var bl: Bloom = b.blooms[1]
	place_at(0, bl.global_position + b.up_at(bl.global_position) * 0.3, p.facing)
	await t.seconds(0.3)
	var u = g.balls[1].upgrades[0]
	u.taken = true
	g.upgrade_collected(u)
	await t.seconds(1.0)
	# Then on to a new area (Expansion 4's Hollow Grotto): clear a parasite, take a cave's pearl and
	# find a bloom there, so the run continues on that ball.
	var b7 := g.balls[6]
	var par7: Parasite = b7.parasites[0]
	par7.hit_cd = 0.0
	par7.hit(par7.hp, par7.global_position)
	var pearl = b7.upgrades[0]
	pearl.taken = true
	g.upgrade_collected(pearl)
	var bl7: Bloom = b7.blooms[1]
	place_at(6, bl7.global_position + b7.up_at(bl7.global_position) * 0.3, -MossBall.frame_at(b7.up_at(bl7.global_position), 0.0).z)
	g.audio.set_ball(6, false)
	# Expansion 5: beat Hollow Grotto's guardian crab (a completion entry that must stay beaten).
	var crab7: CrabGuardian = null
	for c in b7.critters:
		if c is CrabGuardian:
			crab7 = c
	p.invuln_t = 999
	for k in 3:
		crab7.hit(1, p.global_position)
		await t.seconds(0.2)
	g.discover_species("crab")
	p.invuln_t = 0.0
	await t.seconds(1.0)
	g.save_run()
	var st := {"earned": g.run_save.earned().keys(), "run_s": g.clock.run_s, "r0": b.restoration, "r6": b7.restoration, "checkpoint": bl7.get_meta("completion_id"),
			"max_hp": p.max_health, "par": par.get_meta("completion_id"), "mote": m.get_meta("completion_id"), "run_id": g.run_save.run()["id"],
			"par7": par7.get_meta("completion_id"), "pearl": pearl.get_meta("completion_id", ""), "crab7": crab7.threat_id}
	var f := FileAccess.open(g.run_save.path + ".expect", FileAccess.WRITE)
	f.store_string(JSON.stringify(st))
	f.close()
	t.check("write_earned_progress", st["earned"].size() >= 9 and crab7.defeated and st["earned"].has(crab7.threat_id) and b.restoration > 0.0 and b7.restoration > 0.0 and g.checkpoint == bl7
			and p.ball == b7 and pearl.kind == "pearl" and st["earned"].has(st["pearl"]), str(st["earned"]))


## Second launch (as after quitting, or after an OTA restart): the same run continues.
func _phase_continue_read() -> void:
	var st: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(g.run_save.path + ".expect"))
	var b := g.balls[0]
	var earned: Array = g.run_save.earned().keys()
	var same := earned.size() == (st["earned"] as Array).size()
	for id in st["earned"]:
		same = same and earned.has(id)
	t.check("read_same_run_and_earned", g.run_save.run()["id"] == st["run_id"] and same and g.has_run_in_progress(), "%s; saved %s; now %s" % [g.run_save.origin, st["earned"], earned])
	t.check("read_timer_continues", g.clock.run_s >= float(st["run_s"]) and g.clock.run_s < float(st["run_s"]) + 1.0,
			"saved %.3f, now %.3f" % [float(st["run_s"]), g.clock.run_s])
	t.check("read_restoration_restored", is_equal_approx(b.restoration, float(st["r0"])) and is_equal_approx(g.ball_disp[0], b.restoration), "%.3f" % b.restoration)
	var par: Parasite
	var mote: Mote
	for x in b.parasites:
		if x.get_meta("completion_id") == st["par"]:
			par = x
	for x in b.motes:
		if x.get_meta("completion_id") == st["mote"]:
			mote = x
	t.check("read_cleared_things_stay_cleared", par != null and not par.is_alive() and not par.visible and mote != null and mote.state == "done" and not mote.visible, "")
	t.check("read_cave_and_health", g.balls[1].upgrades[0].taken and p.max_health == int(st["max_hp"]), "max hp %d" % p.max_health)
	var b7 := g.balls[6]
	var par7: Parasite
	for x in b7.parasites:
		if x.get_meta("completion_id") == st["par7"]:
			par7 = x
	t.check("read_new_area_progress", par7 != null and not par7.is_alive() and b7.upgrades[0].taken and is_equal_approx(b7.restoration, float(st["r6"]))
			and is_equal_approx(g.ball_disp[6], b7.restoration), "ball 7 restoration %.3f (saved %.3f)" % [b7.restoration, float(st["r6"])])
	# The beaten guardian stays beaten (and not counted twice); the species stays discovered; the
	# other creatures are there as usual.
	var crab7: CrabGuardian = null
	var others := 0
	for c in b7.critters:
		if c is CrabGuardian:
			crab7 = c
		elif c.visible:
			others += 1
	var dup := 0
	for id in g.run_save.earned():
		if id == st["crab7"]:
			dup += 1
	t.check("read_creatures_restored", crab7 != null and crab7.defeated and not crab7.visible and crab7.threat_id == st["crab7"] and dup == 1
			and g.species_known("crab") and others > 0, "crab %s defeated %s; %d other creatures" % [st["crab7"], crab7.defeated if crab7 else false, others])
	t.check("read_resumes_at_last_bloom", g.checkpoint != null and g.checkpoint.get_meta("completion_id") == st["checkpoint"]
			and p.ball == b7 and p.global_position.distance_to(g.checkpoint.respawn_point()) < 1.0,
			"checkpoint %s (saved %s), ball %d, %.2f m from its respawn point" % [g.checkpoint.get_meta("completion_id") if g.checkpoint else "none", st["checkpoint"],
			p.ball.index, p.global_position.distance_to(g.checkpoint.respawn_point()) if g.checkpoint else -1.0])
	var before := g.clock.run_s
	await t.seconds(1.0)
	t.check("read_timer_runs_on", g.clock.run_s > before + 0.9, "")


# --- music -------------------------------------------------------------------------------

## The owner's two songs are the music: both load, play once each (no loop) and alternate, on
## every moss ball; travelling to another ball keeps the current song going.
func _test_music() -> void:
	var a := g.audio
	var ok := a._songs.size() == 2
	var lens: Array[String] = []
	for s in a._songs:
		ok = ok and s is AudioStreamOggVorbis and not (s as AudioStreamOggVorbis).loop
		lens.append("%.1f s" % (s.get_length() if s else 0.0))
	t.check("music_owner_songs_load", ok and a._songs[0].get_length() > 100.0 and a._songs[1].get_length() > 95.0, ", ".join(lens))
	var legacy := false
	for f in DirAccess.get_files_at("res://assets/audio"):
		legacy = legacy or RegEx.create_from_string("^music_b\\d_l\\d").search(f) != null
	t.check("music_generated_layers_removed", not legacy, "")
	a.set_ball(0, false)
	var first := a.current_song()
	var playing: bool = a._song.playing
	a.set_ball(2, true)
	t.check("music_travel_keeps_song", a.current_song() == first and a._song.playing == playing and playing, "")
	var order: Array[int] = [a.song_index]
	for i in 3:
		a.next_song()
		order.append(a.song_index)
	t.check("music_songs_alternate", order[0] != order[1] and order[1] != order[2] and order[0] == order[2] and order[1] == order[3], str(order))
	t.check("music_on_the_music_bus", a._song.bus == "Music", "")
	# Muffling: a murky ball stays recognisable, a healed one is clear, and the cutoff glides.
	var lp: AudioEffectLowPassFilter = AudioServer.get_bus_effect(AudioServer.get_bus_index("Music"), 0)
	var rs: Array[float] = [0.0, 0.0, 0.0]
	a.update_mix(rs, 0.0, 0)
	var murky: float = a.cutoff_target
	rs[0] = 1.0
	a.update_mix(rs, 0.3, 0)
	var clear: float = a.cutoff_target
	lp.cutoff_hz = AudioDirector.MURKY_HZ
	a._glide_cutoff(1.0 / 60.0)
	var step: float = lp.cutoff_hz
	t.check("music_murky_still_recognisable", murky >= 2000.0 and clear >= 17000.0 and step > AudioDirector.MURKY_HZ and step < 2500.0,
			"murky %.0f Hz, healed %.0f Hz, one frame of glide %.0f Hz" % [murky, clear, step])
	# The real handover: near the end of a song, the next one starts by itself.
	var before: int = a.song_index
	a._song.seek(a.current_song().get_length() - 0.4)
	# Audio plays in real time while the test clock runs faster, so wait on the wall clock.
	var until := Time.get_ticks_msec() + 2500
	while Time.get_ticks_msec() < until and a.song_index == before:
		await g.get_tree().process_frame
	t.check("music_next_song_starts_when_one_ends", a.song_index != before and a._song.playing,
			"%d -> %d at %.1f s" % [before, a.song_index, a._song.get_playback_position()])


# --- helpers -----------------------------------------------------------------------------

func place(bi: int, lat: float, lon: float, h := 0.1, heading := 0.0) -> void:
	var b := g.balls[bi]
	var d := MossBall.dir_ll(lat, lon)
	p.place(b, b.surface_point(d, h), -MossBall.frame_at(d, heading).z)
	p.velocity = Vector3.ZERO
	p.bot_input = Vector2.ZERO
	g.cam.snap_behind()
	g.audio.set_ball(bi, false)


func place_at(bi: int, pos: Vector3, face: Vector3) -> void:
	p.place(g.balls[bi], pos, face)
	p.velocity = Vector3.ZERO
	p.bot_input = Vector2.ZERO
	g.cam.snap_behind()


func press(action: String) -> void:
	Input.action_press(action)
	await t.frames(1)
	Input.action_release(action)


func stick_toward(world_dir: Vector3) -> void:
	var cf: Vector3 = -g.cam.global_basis.z
	cf = (cf - p.up * cf.dot(p.up)).normalized()
	var cr := cf.cross(p.up)
	var d := (world_dir - p.up * world_dir.dot(p.up)).normalized()
	p.bot_input = Vector2(d.dot(cr), d.dot(cf))


func height() -> float:
	return p.ball.altitude(p.global_position)


func wait_grounded(timeout := 4.0) -> bool:
	var n := int(timeout * 60)
	for i in n:
		await t.frames(1)
		if p.grounded:
			return true
	return false


func first_alive(ball_i: int, kind: int, zone := "") -> Parasite:
	for par in g.balls[ball_i].parasites:
		if par.is_alive() and par.kind == kind and (zone == "" or par.zone_id == zone):
			return par
	return null


# --- tests -------------------------------------------------------------------------------

func _surface_height(b: MossBall, dir: Vector3, h_hint: float) -> float:
	# (From just above where it should stand: a Mote tucked under an overhang stands on the
	# ground beneath it, not on the overhang.)
	var top := b.surface_point(dir, maxf(h_hint, 0.0) + 0.6)
	var q := PhysicsRayQueryParameters3D.create(top, b.global_position, 1 | 2 | LevelBuilder.CLIMB_LAYER)
	var hit := g.get_world_3d().direct_space_state.intersect_ray(q)
	return -99.0 if hit.is_empty() else b.altitude(hit.position)


func _test_ota_and_version() -> void:
	await preload("res://scripts/tests/ota_tests.gd").new(t).run()


## Godot culls back faces and treats clockwise-from-outside as front, so every solid
## procedural mesh must have (c - a) x (b - a) pointing away from its interior.
func _front_faces_out(mesh: ArrayMesh, interior: Callable) -> int:
	var v: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var wrong := 0
	for i in range(0, v.size(), 3):
		var n := (v[i + 2] - v[i]).cross(v[i + 1] - v[i])
		if n.length_squared() < 1e-12:
			continue
		var c := (v[i] + v[i + 1] + v[i + 2]) / 3.0
		if n.dot(c - (interior.call(c) as Vector3)) <= 0.0:
			wrong += 1
	return wrong


func _test_mesh_winding() -> void:
	var cushion := _front_faces_out(MeshLib.cushion_mesh(1.4, 2.8, 1.5), func(_c: Vector3) -> Vector3: return Vector3(0, 1.0, 0))
	t.check("cushion_faces_outward", cushion == 0, "%d inward faces" % cushion)
	var mound: ArrayMesh = MeshLib.mound(1.4, 2.8, 1.5, 7)[0]
	var mound_bad := _front_faces_out(mound, func(c: Vector3) -> Vector3: return Vector3(0, minf(c.y, 0.0) - 1.0, 0))
	t.check("mound_faces_outward", mound_bad == 0, "%d inward faces" % mound_bad)
	var stem := _front_faces_out(MeshLib.stem_mesh(0.3, 0.2, 3.0, 9), func(c: Vector3) -> Vector3: return Vector3(0, c.y, 0))
	t.check("stem_faces_outward", stem == 0, "%d inward faces" % stem)
	# Cave: the outside faces out, the inside faces into the cave, the jambs face into the mouth.
	var cave: Array = MeshLib.cave_mound({"seed": 3})
	var f: PackedVector3Array = cave[1]
	var parts: Dictionary = cave[2]
	var wrong := [0, 0, 0]
	for k in range(0, f.size(), 3):
		var n := (f[k + 2] - f[k]).cross(f[k + 1] - f[k])
		if n.length_squared() < 1e-10:
			continue
		var c := (f[k] + f[k + 1] + f[k + 2]) / 3.0
		var ti := k / 3
		var part := 0 if ti < parts["inner"] else (1 if ti < parts["jamb"] else 2)
		var axis := Vector3(0.0, c.y, 0.0)
		if part == 2:
			# Jambs face into the mouth (toward its centre line), or down where the two meet over
			# it as the roof; faces lying on the centre line itself have no side.
			var nn := n.normalized()
			if not (nn.y < -0.2 or nn.x * c.x < 0.0 or absf(c.x) < 0.005):
				wrong[part] += 1
			continue
		var want: Vector3 = [c - axis, axis - c][part]
		if want.length_squared() > 1e-6 and n.dot(want) <= 0.0:
			wrong[part] += 1
	t.check("cave_faces_correct_side", wrong == [0, 0, 0], "wrong faces outer %d, inner %d, jambs %d of %d" % [wrong[0], wrong[1], wrong[2], parts["total"]])


## World expansion: restoration settles into each ball's health map, so any number of healed
## patches keeps every one of them (the old splat list held 64 and dropped the smallest), and the
## CPU reading agrees with what the shaders are given.
func _test_health_map() -> void:
	var b := g.balls[6]
	var dirs: Array[Vector3] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	for i in 100:
		dirs.append(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized())
	var before := []
	for d in dirs:
		before.append(b.health_at(d))
	for d in dirs:
		b.add_heal(d, 3.0, 0.3)
	await t.seconds(1.0)
	var kept := 0
	for d in dirs:
		if b.health_at(d) > 0.95:
			kept += 1
	var mats_ok := true
	for m in b.field_materials:
		mats_ok = mats_ok and m.get_shader_parameter("health_map") == b.health_tex
	t.check("health_map_keeps_every_heal", kept == dirs.size() and b.heals.is_empty() and mats_ok,
			"%d of %d patches healed after settling; still growing %d; every material has the map %s" % [kept, dirs.size(), b.heals.size(), mats_ok])
	# Edge of a patch: half way out it is still lush, just past its edge it is not.
	var d0 := dirs[0]
	var axis := d0.cross(Vector3.UP).normalized()
	var inside := b.health_at(d0.rotated(axis, deg_to_rad(1.2)))
	t.check("health_map_patch_shape", inside > 0.9 and before[0] < 0.5 or inside > 0.9, "healed %.2f half way out (was %.2f)" % [inside, before[0]])


## World expansion: restoration changes geography. A gate on a zone opens when the zone heals
## (played out live, at once on a resumed save), is solid where it is drawn once open, and never
## moves into him.
func _test_restoration_gates() -> void:
	var b := g.balls[0]
	var at := MossBall.dir_ll(-10, -40)
	var fr := MossBall.frame_at(at, 0.0)
	var saved := [b.events_total, b.events_done, b.restoration, b.completed]
	# (The probes heal a zone, which eases the aquarium and the vortices along; put those back too.)
	var eased := [g.g_disp, g.ball_disp[0]]
	var vortex_eased := {}
	for v in g.vortices:
		vortex_eased[v] = v.strength
	var release := _hold_threats(b)
	var make := func(zone: String, kind: String, offset_m: float) -> RestorationGate:
		b.add_zone(zone, at, 4.0)
		b.register_event(zone)
		var gt := RestorationGate.new()
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(4.0, 0.4, 1.4)
		mi.mesh = bm
		gt.add_child(mi)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = bm.size
		cs.shape = sh
		gt.add_child(cs)
		var base := b.xform_on_dir(at.rotated(fr.x, offset_m / b.radius), 0.0, 0.0)
		var open_xf := base.translated_local(Vector3(0, 2.0, 0))
		var closed_xf := base.translated_local(Vector3(0, -0.5, 0)) * Transform3D(Basis(Vector3.RIGHT, 0.4), Vector3.ZERO)
		gt.setup(b, zone, kind, closed_xf, open_xf, 1.5)
		b.add_child(gt)
		return gt
	var top_hit := func(gt: RestorationGate) -> float:
		var top: Vector3 = gt.open_xf * Vector3(0, 0.2, 0)
		var up := b.up_at(top)
		var hit := g.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(top + up * 2.0, top - up * 0.6, 1))
		return 9.0 if hit.is_empty() else (hit.position as Vector3).distance_to(top)
	# Rise: shut before, open and solid after its zone heals.
	place_at(0, b.surface_point(at.rotated(fr.x, 12.0 / b.radius), 0.2), fr.z)
	var rise: RestorationGate = make.call("probe_rise", "rise", 0.0)
	await t.frames(2)
	var before: float = top_hit.call(rise)
	b.complete_event("probe_rise", rise.global_position)
	await t.seconds(2.0)
	var after: float = top_hit.call(rise)
	t.check("gate_rises_when_zone_heals", before > 0.5 and rise.is_open and after < 0.05 and rise.global_transform.origin.distance_to(rise.open_xf.origin) < 0.01 and rise.has_meta("settled"),
			"before: nothing solid at its open top (%.2f m off); after: open %s, solid there within %.3f m" % [before, rise.is_open, after])
	# Grow: waits while he stands where it is growing, then grows once he steps off.
	var grow: RestorationGate = make.call("probe_grow", "grow", 6.0)
	await t.frames(2)
	place_at(0, grow.open_xf.origin - b.up_at(grow.open_xf.origin) * 1.5, fr.z)
	p.global_position = grow.open_xf.origin
	p.set_physics_process(false)
	b.complete_event("probe_grow", grow.global_position)
	await t.seconds(2.0)
	var waited := not grow.is_open
	p.set_physics_process(true)
	place_at(0, b.surface_point(at.rotated(fr.x, 12.0 / b.radius), 0.2), fr.z)
	await t.seconds(2.0)
	t.check("gate_never_moves_into_him", waited and grow.is_open and top_hit.call(grow) < 0.05, "waited while he stood there %s; open once he left %s" % [waited, grow.is_open])
	# Resumed save: open at once.
	var res: RestorationGate = make.call("probe_resume", "rise", -6.0)
	await t.frames(1)
	b.restore_event("probe_resume", res.global_position)
	var at_once := res.is_open and res.global_transform.origin.distance_to(res.open_xf.origin) < 0.01
	# (And its collision with it: the body, not only the drawn node, stands open.)
	await t.frames(2)
	var solid_res: float = top_hit.call(res)
	t.check("gate_open_on_resume", at_once and solid_res < 0.05, "open in the same frame %s, solid at its open top within %.3f m (zone %s, gates on ball %d)" % [at_once, solid_res, str(b.zones.get("probe_resume", {})), b.gates.size()])
	for gt in [rise, grow, res]:
		b.gates.erase(gt)
		b.zones.erase(gt.zone_id)
		gt.queue_free()
	b.events_total = saved[0]
	b.events_done = saved[1]
	b.restoration = saved[2]
	b.completed = saved[3]
	g.g_disp = eased[0]
	g.ball_disp[0] = eased[1]
	for v in vortex_eased:
		v.strength = vortex_eased[v]
	release.call()


## World expansion: a bubble column carries him up and he hangs near its top (burst restored);
## a column tied to a zone stays still until that zone heals, then flows.
func _test_bubble_columns() -> void:
	var b := g.balls[0]
	var lb: LevelBuilder = b.get_meta("builder")
	var release := _hold_threats(b)
	var pocket := MossBall.dir_ll(74, 62)
	place_at(0, b.surface_point(pocket, 0.1), MossBall.frame_at(pocket, 0.0).z)
	p.bot_input = Vector2.ZERO
	var top_h := 0.0
	for i in 60 * 3:
		await t.frames(1)
		top_h = maxf(top_h, height())
	var hang := height()
	t.check("bubble_column_lifts_and_holds", top_h > 4.0 and hang > 3.5 and p.burst_available and not p.grounded,
			"rose to %.1f m, hanging at %.1f m, burst ready %s" % [top_h, hang, p.burst_available])
	# Swim off the top: he falls back to the ground as usual.
	p.bot_input = Vector2(0, 1)
	await t.seconds(1.0)
	p.bot_input = Vector2.ZERO
	await wait_grounded()
	# Canopy Spire's glide shaft: dropped in near its top he sinks gently all the way down and lands
	# unhurt (no hard or extreme landing).
	var b6 := g.balls[5]
	var shaft: Array = []
	for c in b6.columns:
		if float(c[4]) < 0.0:
			shaft = c
	var glide_ok := false
	var glide_detail := "no glide shaft on Canopy Spire"
	if not shaft.is_empty():
		# (Canopy Spire's own parasites held too: one wandering into him is not what this measures.)
		var release6 := _hold_threats(b6)
		p.restore_full()
		var hp0 := p.health
		var ext0 := int(g.stats["extreme_landings"])
		var hard0 := int(g.stats["hard_landings"])
		place_at(5, (shaft[0] as Vector3) + (shaft[1] as Vector3) * 24.0, MossBall.frame_at(shaft[1], 0.0).z)
		g.audio.set_ball(5, false)
		await t.seconds(2.0)
		var sink := -p.velocity.dot(p.up)
		await wait_grounded(20.0)
		glide_ok = sink > 1.0 and sink < 2.4 and p.health == hp0 and int(g.stats["extreme_landings"]) == ext0 and int(g.stats["hard_landings"]) == hard0
		glide_detail = "sinking at %.1f m/s; health %d -> %d; hard landings +%d, extreme +%d" % [sink, hp0, p.health,
				int(g.stats["hard_landings"]) - hard0, int(g.stats["extreme_landings"]) - ext0]
		release6.call()
	t.check("glide_shaft_floats_him_down", glide_ok, glide_detail)
	# A dormant column (its zone not healed) does nothing; healing the zone sets it flowing.
	var at := MossBall.dir_ll(-10, -40)
	b.add_zone("probe_col", at, 4.0)
	b.register_event("probe_col")
	var saved := [b.events_total, b.events_done, b.restoration, b.completed]
	var eased := [g.g_disp, g.ball_disp[0]]
	var vortex_eased := {}
	for v in g.vortices:
		vortex_eased[v] = v.strength
	var n_cols := b.columns.size()
	lb.bubble_column(at, 0.9, 4.5, 5.0, "probe_col")
	var gate: RestorationGate = b.columns[n_cols][5]
	place_at(0, b.surface_point(at, 0.1), MossBall.frame_at(at, 0.0).z)
	await t.seconds(1.5)
	var still := height()
	b.complete_event("probe_col", b.surface_point(at))
	await t.seconds(3.0)
	var lifted := height()
	t.check("bubble_column_flows_when_healed", still < 0.3 and lifted > 3.0 and gate.flow >= 1.0 and gate.visible,
			"%.1f m before healing, %.1f m after (flow %.1f)" % [still, lifted, gate.flow])
	b.columns.resize(n_cols)
	b.gates.erase(gate)
	b.zones.erase("probe_col")
	gate.queue_free()
	b.events_total = saved[0] - 1
	b.events_done = saved[1]
	b.restoration = saved[2]
	b.completed = saved[3]
	g.g_disp = eased[0]
	g.ball_disp[0] = eased[1]
	for v in vortex_eased:
		v.strength = vortex_eased[v]
	release.call()
	p.bot_input = Vector2(0, 1)
	await t.seconds(0.8)
	p.bot_input = Vector2.ZERO
	await wait_grounded()


## World expansion: a ravine cut through a plateau. Its floor is the ball's base surface; the
## collision is the drawn ground; coming down on the floor costs one frond and puts Gill back on
## the rim he left; on his last frond it is a death (re-forming at the bloom); the floor is never
## taken for safe footing. (Built for the test on open meadow ground, then taken away again.)
## Owner, 2026-10-01: the ooze's bubbles are their own fixed pool. They never take effects from Gill or
## anything else, stay inside the valley (about 0.5 m up, under the rim), stay bounded over time and
## leave nothing behind across repeated valley deaths.
func _test_ooze_bubbles() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/world/ravine_ooze.gd")
	t.check("ooze_bubbles_own_pool", not src.contains("WaterFX"), "the ooze script draws nothing from WaterFX's shared pool")
	var b := g.balls[0]
	var oz := b.get_node("RavineOoze") as RavineOoze
	var pts: Array = b.carves[0][0]
	var mid: Vector3 = (pts[pts.size() / 2] as Vector3).normalized()
	var nxt: Vector3 = (pts[pts.size() / 2 + 1] as Vector3).normalized()
	var along := (nxt - mid).normalized()
	var rim := mid.rotated(along, (float(b.carves[0][1]) + float(b.carves[0][3]) + 1.5) / b.radius)
	var release := _hold_threats(b)
	place_at(0, b.surface_point(rim, 0.1), b.global_position + mid * b.radius - b.surface_point(rim))
	g.cam.snap_behind()
	g.cam.pitch = -0.45
	var count0 := oz.get_child_count()
	var puffs0: int = WaterFX.inst._puff_next
	var peak := 0
	var worst_over := -INF
	var s0 := oz.spawned
	for i in 60 * 12:
		await t.frames(1)
		peak = maxi(peak, oz.alive())
		for k in RavineOoze.BUBBLE_POOL:
			var st := oz.bubble_state(k)
			if st.is_empty():
				continue
			var pos: Vector3 = st[0]
			var base: Vector3 = st[1]
			var up := base.normalized()
			var h := (pos - base).dot(up)
			worst_over = maxf(worst_over, h - float(st[2]))
	var made := oz.spawned - s0
	t.check("ooze_bubbles_bounded", peak <= RavineOoze.BUBBLE_POOL and oz._mm.instance_count == RavineOoze.BUBBLE_POOL and made > 20,
			"%d made in 12 s, at most %d alive of %d slots" % [made, peak, RavineOoze.BUBBLE_POOL])
	t.check("ooze_bubbles_stay_low", worst_over <= 0.001, "highest above its own cap by %.3f m (cap <= %.2f m)" % [worst_over, RavineOoze.BUBBLE_TOP_M])
	# (Gill is idle on the rim: any puffs spent in that time were his or the world's, not the ooze's.)
	t.check("ooze_bubbles_no_shared_puffs", WaterFX.inst._puff_next == puffs0, "shared pool cursor %d -> %d" % [puffs0, WaterFX.inst._puff_next])
	# Repeated valley deaths: nothing accumulates.
	for n in 5:
		g._start_cinematic("ravine", {"to": [b, b.surface_point(rim, 0.1)]})
		for i in 60 * 3:
			await t.frames(1)
			if g.cinematic == "":
				break
		await t.frames(30)
	t.check("ooze_bubbles_survive_deaths", oz.get_child_count() == count0 and oz.alive() <= RavineOoze.BUBBLE_POOL and oz._mm.instance_count == RavineOoze.BUBBLE_POOL
			and p.model.position.y == 0.0, "children %d -> %d, alive %d, model y %.2f" % [count0, oz.get_child_count(), oz.alive(), p.model.position.y])
	release.call()


## Owner, 2026-10-02: the tall tank-floor blades keep clear of every moss ball and water tunnel, and
## the camera never dips under the ground however far he looks down.
func _test_view_clearances() -> void:
	# The tank blades at their widest, swung to every extreme of their sway: none reaches into a
	# ball or a tunnel (owner, 2026-10-02: giant stretched strips across the view).
	var aq := g.aquarium
	var arr: Array = (aq._blades.mesh as Mesh).surface_get_arrays(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var spheres: Array = []
	for b in g.balls:
		spheres.append([b.global_position, b.radius, "ball %d" % (b.index + 1)])
	for v in g.vortices:
		for k in 121:
			spheres.append([v.visual_point(k / 120.0), Vortex.TUBE_RADIUS, "a tunnel"])
	var worst := INF
	var where := ""
	var trimmed := 0
	var hidden := 0
	for i in aq._blade_xfs.size():
		var xf: Transform3D = aq._blade_xfs[i]
		var sc := xf.basis.get_scale()
		var h: float = aq._blade_h[i]
		if h < sc.y - 0.01:
			trimmed += 1
		if h <= 0.0:
			hidden += 1
			continue
		var tx := Transform3D(xf.basis.orthonormalized().scaled(Vector3(sc.x, h, sc.z)), xf.origin)
		for j in vs.size():
			var tt := uvs[j].y
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var w: Vector3 = tx * (vs[j] + Vector3(sx * aq.BLADE_SWAY.x, 0, sz * aq.BLADE_SWAY.y) * tt * tt)
					for sp in spheres:
						var gap: float = w.distance_to(sp[0]) - float(sp[1])
						if gap < worst:
							worst = gap
							where = "%s (blade %d)" % [sp[2], i]
	t.log_line("tank blades shortened %d (hidden %d) of %d" % [trimmed, hidden, aq._blade_xfs.size()])
	t.check("tank_blades_clear_balls_and_tunnels", worst >= aq.BLADE_MARGIN - 0.5, "swaying blades stay %.1f m outside %s" % [worst, where])
	# Looking as far down as he can, on a crest and on flat ground: the camera stays above the terrain.
	# (Put back where he was afterwards: later tests read the world round him.)
	var home := [p.ball.index, p.global_position, p.facing]
	var lowest := INF
	for bi in [0, 2, 4]:
		var b: MossBall = g.balls[bi]
		# (Its creatures held still: later tests pick sleeping parasites on these balls.)
		var release := _hold_threats(b)
		for k in 6:
			var d := MossBall.dir_ll(-30.0 + k * 12.0, k * 55.0)
			place_at(bi, b.surface_point(d, 0.1), MossBall.frame_at(d, 0).z)
			g.cam.snap_behind()
			for f in 20:
				g.cam.pitch = FollowCam.PITCH_MIN
				await t.frames(1)
			var cd: Vector3 = g.cam.global_position - b.global_position
			lowest = minf(lowest, cd.length() - b.radius - b.terrain_height(cd.normalized()))
		release.call()
	t.check("camera_never_under_ground", lowest >= FollowCam.GROUND_CLEAR - 0.01, "lowest %.2f m above the terrain" % lowest)
	g.cam.pitch = 0.32
	place_at(home[0], home[1], home[2])
	await t.frames(2)


func _test_ravines() -> void:
	var b := g.balls[0]
	var at := MossBall.dir_ll(-10, -40)
	var fr := MossBall.frame_at(at, 0.0)
	var n_hills := b.hills.size()
	var n_carves := b.carves.size()
	# (Sized in metres: 12 m of plateau either side, a ravine 3.2 m across with 1.4 m walls.)
	var m2a := func(m: float) -> float: return m / b.radius
	b.add_plateau(at, m2a.call(14.0), 3.0, 2.5)
	var r0 := at.rotated(fr.z, m2a.call(10.0))
	var r1 := at.rotated(fr.z, -m2a.call(10.0))
	b.add_ravine([r0, at, r1], 3.2, 3.0, 1.4, "test.ravine")
	b.finalize_terrain()
	await t.frames(2)
	var side := at.rotated(fr.x, m2a.call(5.5))
	var floor_h := b.terrain_height(at)
	var top_h := b.terrain_height(side)
	t.check("ravine_shape", floor_h < 0.01 and absf(top_h - 3.0) < 0.05 and b.ravine_at(at) == "test.ravine" and b.ravine_at(side) == "",
			"floor %.2f m, plateau %.2f m; floor is ravine %s" % [floor_h, top_h, b.ravine_at(at)])
	var space := g.get_world_3d().direct_space_state
	var worst := 0.0
	var flat_worst := 0.0
	for k in 25:
		var x := -6.0 + k * 0.5
		var d := at.rotated(fr.x, m2a.call(x)).normalized()
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(b.surface_point(d, 4.0), b.global_position, 1))
		var gap := 9.0 if hit.is_empty() else absf(b.altitude(hit.position))
		if absf(x) < 1.4 or absf(x) > 3.2:
			flat_worst = maxf(flat_worst, gap)
		else:
			worst = maxf(worst, gap)
	# (On the floor and the plateau the ground is the smooth shape to a centimetre; on the steep
	# walls the 0.8 m triangles cut its curve by up to a sixth of a metre or so, and collision is
	# those same triangles.)
	t.check("ravine_collision_is_drawn_ground", flat_worst < 0.03 and worst < 0.2, "floor and top within %.3f m, walls within %.3f m" % [flat_worst, worst])
	# Walk off the rim into it.
	var release := _hold_threats(b)
	var earned_before := g.run_save.earned().size()
	var fall := func(hp: int) -> Array:
		place_at(0, b.surface_point(side, 0.3), -fr.x)
		var want: Vector3 = g.respawn_target()[1]
		p.invuln_t = 0.0
		p.health = hp
		p.model.set_health(hp, p.max_health, false)
		await t.seconds(0.8)
		var rim := p.global_position
		var falls0 := int(g.stats.get("ravine_falls", 0))
		var deaths0: int = g.stats["deaths"]
		var across := b.surface_point(at.rotated(fr.x, -m2a.call(4.0)))
		var safe_in_ravine := false
		for i in 60 * 4:
			stick_toward(across - p.global_position)
			await t.frames(1)
			if b.ravine_at(b.up_at(p.last_safe_pos)) != "":
				safe_in_ravine = true
			if g.cinematic != "":
				break
		p.bot_input = Vector2.ZERO
		var kind := g.cinematic
		var sank := 0.0
		for i in 60 * 8:
			await t.frames(1)
			sank = minf(sank, p.model.position.y)
			if g.cinematic == "" and p.state == "normal":
				break
		await t.seconds(0.5)
		return [kind, int(g.stats.get("ravine_falls", 0)) - falls0, g.stats["deaths"] - deaths0, want, safe_in_ravine, sank]
	# Owner, 2026-10-02: a fall into the ooze is a death at any health: his checkpoint, a third of
	# his fronds.
	var r: Array = await fall.call(3)
	var back := p.global_position
	t.check("ravine_fall_at_full_health_is_a_death", r[0] == "ravine" and r[1] == 1 and r[2] == 1 and p.health == Game.respawn_health(p.max_health)
			and back.distance_to(r[3]) < 1.0 and p.state == "normal" and not r[4],
			"shot %s; falls %d, deaths %d; health %d of %d; %.2f m from his checkpoint; safe spot ever in the ravine %s" % [r[0], r[1], r[2], p.health, p.max_health, back.distance_to(r[3]), r[4]])
	# Owner, 2026-10-01: he sinks into the ooze and is gone before he reforms on the rim, upright.
	t.check("ravine_fall_sinks_into_ooze", r[5] < -Game.OOZE_SINK_M * 0.9 and p.model.position.y == 0.0 and p.model.dissolve < 0.01,
			"sank %.2f m; model y now %.2f, dissolve %.2f" % [-r[5], p.model.position.y, p.model.dissolve])
	var oozed: Array[String] = []
	for bb in g.balls:
		var oz := bb.get_node_or_null("RavineOoze") as RavineOoze
		var built := n_carves if bb == b else bb.carves.size()   # (this test adds its own ravine to b)
		if built > 0 and (oz == null or oz.mesh.get_surface_count() == 0):
			oozed.append("ball %d" % (bb.index + 1))
	t.check("ravine_ooze_on_every_ravine_ball", oozed.is_empty(), "missing on %s" % str(oozed))
	var r2: Array = await fall.call(1)
	t.check("ravine_fall_on_last_frond_is_a_death", r2[0] == "ravine" and r2[2] == 1 and p.state == "normal" and p.health == Game.respawn_health(p.max_health)
			and p.global_position.distance_to(r2[3]) < 1.0 and g.run_save.earned().size() >= earned_before,
			"shot %s; deaths %d; re-formed with %d of %d, %.2f m from his checkpoint" % [r2[0], r2[2], p.health, p.max_health, p.global_position.distance_to(r2[3])])
	release.call()
	# Take the test ground away again.
	b.hills.resize(n_hills)
	b.carves.resize(n_carves)
	b._cells_dirty = true
	b.finalize_terrain()
	await t.frames(2)
	p.restore_full()


## Rolling hills: smooth, walkable, and the collision matches what is drawn.
## Every structure that rises from a moss ball (moss cushions, cave domes, stems) must meet the
## ground all the way round its base: no floating caps with a gap Gill can walk into. Measures
## each structure's lowest vertex ring in world space against the real terrain (hills included).
## No collision body hangs over open water unless it floats by design (leaves on stems): the
## phone playtest found the brittle-moss bridge caps floating like broken formation tops.
func _test_no_floating_platforms() -> void:
	var all := _unsupported_bodies(true)
	var bad := _unsupported_bodies(false)
	for f in bad:
		t.log_line(f)
	var brittle_supported := true
	for b in g.balls:
		for c in b.crumbles:
			var up := b.up_at(c.global_position)
			var q := PhysicsRayQueryParameters3D.create(c.global_position - up * 0.45, c.global_position - up * 6.0, 1 | 2)
			q.hit_from_inside = true
			var hit := g.get_world_3d().direct_space_state.intersect_ray(q)
			brittle_supported = brittle_supported and not hit.is_empty() and hit.collider == c and c._stalk != null
	t.check("terrain_no_unsupported_platforms", bad.is_empty() and all.size() > 50, "%d elevated bodies over water, all by design (leaves on stems); %d unsupported" % [all.size(), bad.size()])
	t.check("brittle_moss_caps_on_grounded_stalks", brittle_supported and g.balls[0].crumbles.size() >= 2, "")


## Every static collision body on the balls whose lowest point hangs more than 0.3 m above the
## ground with nothing directly beneath it, unless it is tagged as floating by design.
func _unsupported_bodies(include_by_design := true) -> Array[String]:
	var out: Array[String] = []
	var space := g.get_world_3d().direct_space_state
	for b in g.balls:
		var stack: Array = [b]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			stack.append_array(node.get_children())
			if not node is StaticBody3D or node == b.static_body:
				continue
			var body := node as StaticBody3D
			# The underside: every vertex within 5 cm of the lowest one; probe below its centre.
			var pts: Array[Vector3] = []
			var alts: Array[float] = []
			var lo := INF
			for mi in body.get_children():
				if mi is MeshInstance3D and (mi as MeshInstance3D).mesh != null:
					for v in (mi as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
						var w: Vector3 = (mi as MeshInstance3D).global_transform * v
						pts.append(w)
						alts.append(b.altitude(w))
						lo = minf(lo, alts[-1])
				elif mi is MultiMeshInstance3D:
					# Stem ladders draw their leaves as one MultiMesh.
					var mm: MultiMesh = (mi as MultiMeshInstance3D).multimesh
					var verts: PackedVector3Array = mm.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
					for lxf in mi.get_meta("leaf_transforms", []):
						var ixf: Transform3D = (mi as MultiMeshInstance3D).global_transform * (lxf as Transform3D)
						for v in verts:
							var w: Vector3 = ixf * v
							pts.append(w)
							alts.append(b.altitude(w))
							lo = minf(lo, alts[-1])
			if lo == INF or lo <= 0.3:
				continue
			var lowest := Vector3.ZERO
			var n_low := 0
			for i in pts.size():
				if alts[i] <= lo + 0.05:
					lowest += pts[i]
					n_low += 1
			lowest /= n_low
			var up := b.up_at(lowest)
			var q := PhysicsRayQueryParameters3D.create(lowest - up * 0.02, lowest - up * (lo + 0.5), 1 | 2)
			q.hit_from_inside = true
			var hit := space.intersect_ray(q)
			var gap: float = lo if hit.is_empty() else (lowest - (hit.position as Vector3)).dot(up)
			if gap <= 0.15:
				continue
			var by_design: String = body.get_meta("floats_by_design", "")
			if by_design != "" and not include_by_design:
				continue
			var at := Levels._latlon((body.global_position - b.global_position).normalized())
			out.append("ball %d %s %s at lat %.0f lon %.0f: underside %.2f m above ground, %.2f m of open water beneath%s" % [b.index + 1, body.get_class(), body.get_script().get_global_name() if body.get_script() else "", at.x, at.y, lo, gap, (" (by design: %s)" % by_design) if by_design != "" else ""])
	return out


# --- Parasite body motion -------------------------------------------------------------------

## The centipede-like parasites must move like articulated creatures, not rigid sticks: the head
## lays the path, a wave travels from head to tail, turns bend the body, segments keep their
## spacing, and the motion is frame-rate independent and deterministic. Uses sleeping parasites
## on Moss Ball #3 (Gill is elsewhere) and drives their heads along scripted paths.
func _test_parasite_locomotion() -> void:
	var b := g.balls[2]
	var large: Parasite = null
	var medium: Parasite = null
	for par in b.parasites:
		if par.kind == Parasite.Kind.LARGE and large == null and par.state == "graze":
			large = par
		elif par.kind == Parasite.Kind.MEDIUM and medium == null and par.state == "graze":
			medium = par
	if large == null or medium == null:
		t.check("parasite_locomotion_subjects", false, "no sleeping large+medium parasite on ball 3")
		return
	var snaps := [_par_snapshot(large), _par_snapshot(medium)]
	large.set_physics_process(false)
	medium.set_physics_process(false)
	var dt := 1.0 / 60.0
	var n: int = large.seg_count
	var r: float = large.seg_radius
	# Warm up so the trail covers the whole body, then record 4 s of straight travel.
	_drive([large, medium], large.speed * 0.8, 0.0, 90, dt)
	var rec := _drive([large, medium], large.speed * 0.8, 0.0, 240, dt)
	var lat: Array = rec[0]   # per segment: lateral offset series for the large parasite
	var peak := 0.0
	var jitter := 0.0
	for i in n:
		for f in range(1, lat[i].size()):
			peak = maxf(peak, absf(lat[i][f]))
			jitter = maxf(jitter, absf(lat[i][f] - lat[i][f - 1]))
	var mixed := 0
	for f in lat[0].size():
		var pos := 0
		var neg := 0
		for i in range(1, n):
			if lat[i][f] > 0.01 * r:
				pos += 1
			elif lat[i][f] < -0.01 * r:
				neg += 1
		if pos > 0 and neg > 0:
			mixed += 1
	var lag := _best_lag(lat[2], lat[n - 1], 90)
	t.check("parasite_straight_travel_has_body_wave", peak > 0.18 * r and peak < 0.5 * r, "peak sideways %.3f m (segment radius %.2f)" % [peak, r])
	t.check("parasite_body_not_rigid", mixed > lat[0].size() * 0.6, "body curved (both sides of the path) in %d of %d frames" % [mixed, lat[0].size()])
	t.check("parasite_wave_travels_head_to_tail", lag > 2, "segment %d follows segment 3 by %d frames" % [n, lag])
	t.check("parasite_motion_smooth_no_twitch", jitter < 0.06 * r, "largest frame-to-frame sideways step %.4f m" % jitter)
	t.check("parasite_segments_keep_spacing", _spacing_ok(rec[1], large.spacing), "")
	t.check("parasite_multiple_creatures_animate", _spacing_ok(rec[2], medium.spacing) and _max_abs(rec[3]) > 0.1 * medium.seg_radius, "medium peak %.3f" % _max_abs(rec[3]))
	# Gradual and sharp turns bend the body (head direction vs tail direction).
	_drive([large], large.speed * 0.8, 70.0, 80, dt)
	var bend_gentle := _body_bend(large)
	_drive([large], large.speed * 0.8, 0.0, 120, dt)
	var sharp := _drive([large], large.speed * 0.8, 260.0, 30, dt)
	var bend_sharp := _body_bend(large)
	t.check("parasite_turns_curve_the_body", bend_gentle > 20.0 and bend_sharp > bend_gentle and _spacing_ok(sharp[1], large.spacing), "gentle turn %.0f deg, sharp turn %.0f deg" % [bend_gentle, bend_sharp])
	# Stopping calms the wave to a restrained idle ripple; starting again brings it back.
	_drive([large], 0.0, 0.0, 120, dt)
	var idle := _drive([large], 0.0, 0.0, 120, dt)
	var idle_peak := _max_abs(idle[0])
	_drive([large], large.speed * 0.8, 0.0, 120, dt)
	var again := _drive([large], large.speed * 0.8, 0.0, 60, dt)
	t.check("parasite_idle_restrained_then_resumes", idle_peak > 0.0 and idle_peak < 0.5 * peak and _max_abs(again[0]) > 0.7 * peak, "idle %.3f m, moving %.3f m" % [idle_peak, _max_abs(again[0])])
	# Frame-rate independence and determinism, from the same starting state.
	var start := _par_snapshot(large)
	_drive([large], large.speed * 0.8, 30.0, 60, 1.0 / 60.0)
	var at60 := _seg_positions(large)
	_par_restore(large, start)
	_drive([large], large.speed * 0.8, 30.0, 30, 1.0 / 30.0)
	var at30 := _seg_positions(large)
	_par_restore(large, start)
	_drive([large], large.speed * 0.8, 30.0, 60, 1.0 / 60.0)
	var again60 := _seg_positions(large)
	var d30 := 0.0
	var drep := 0.0
	for i in n:
		d30 = maxf(d30, at60[i].distance_to(at30[i]))
		drep = maxf(drep, at60[i].distance_to(again60[i]))
	t.check("parasite_motion_frame_rate_independent", d30 < 0.3 * r, "30 vs 60 fps: segments differ by at most %.3f m" % d30)
	t.check("parasite_motion_deterministic", drep < 0.00001, "")
	# Cost per creature per frame (desktop; the phone is slower but the work is tiny).
	var t0 := Time.get_ticks_usec()
	for k in 200:
		large._update_segments(dt)
	var us := (Time.get_ticks_usec() - t0) / 200.0
	t.check("parasite_motion_cheap", us < 400.0, "%.0f us per large parasite per frame" % us)
	_par_restore(large, snaps[0])
	_par_restore(medium, snaps[1])
	large.set_physics_process(true)
	medium.set_physics_process(true)


## Moves each head along the ball (speed m/s, turning deg/s) and updates the bodies; returns
## [large lateral series per segment, large spacing samples, medium spacing, medium laterals].
func _drive(pars: Array, v: float, turn: float, frames: int, dt: float) -> Array:
	var lat := []
	var spacing := []
	var spacing_m := []
	var lat_m := []
	for par in pars:
		(par as Parasite).state = "graze"
	for i in (pars[0] as Parasite).seg_count:
		lat.append([])
	if pars.size() > 1:
		for i in (pars[1] as Parasite).seg_count:
			lat_m.append([])
	for f in frames:
		for k in pars.size():
			var par: Parasite = pars[k]
			var b := par.ball
			par.heading = par.heading.rotated(par.up, deg_to_rad(turn) * dt)
			var dir := (par.global_position + par.heading * v * dt - b.global_position).normalized()
			par.global_position = b.surface_point(dir, par._ground_offset)
			par.up = b.up_at(par.global_position)
			par.heading = (par.heading - par.up * par.heading.dot(par.up)).normalized()
			par._update_segments(dt)
			var pos := _seg_positions(par)
			var wave := _wave_offsets(par, pos)
			var gaps := []
			for i in pos.size():
				if i > 0:
					gaps.append(pos[i].distance_to(pos[i - 1]))
			if k == 0:
				spacing.append(gaps)
				for i in pos.size():
					lat[i].append(wave[i])
			else:
				spacing_m.append(gaps)
				for i in pos.size():
					lat_m[i].append(wave[i])
	return [lat, spacing, spacing_m, lat_m]


## Each segment's sideways offset from its own point on the head's trail (the body wave alone,
## whatever the shape of the path).
func _wave_offsets(par: Parasite, pos: Array[Vector3]) -> Array[float]:
	var out: Array[float] = []
	for i in pos.size():
		var base := par._sample_trail(par.spacing * i)
		var along := par.heading if i == 0 else par._sample_trail(par.spacing * (i - 1)) - base
		along -= par.up * along.dot(par.up)
		out.append((pos[i] - base).dot(along.normalized().cross(par.up).normalized()) if along.length() > 0.0001 else 0.0)
	return out


func _seg_positions(par: Parasite) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for s in par._segs:
		out.append(s.global_position)
	return out


func _spacing_ok(samples: Array, spacing: float) -> bool:
	for gaps in samples:
		for gp in gaps:
			if gp < spacing * 0.7 or gp > spacing * 1.35:
				return false
	return true


func _max_abs(series: Array) -> float:
	var m := 0.0
	for s in series:
		for x in s:
			m = maxf(m, absf(x))
	return m


## Frame lag (0..max_lag) at which `b` best matches `a` shifted later in time.
func _best_lag(a: Array, b: Array, max_lag: int) -> int:
	var best := 0
	var best_v := -INF
	for lag in max_lag:
		var acc := 0.0
		for f in range(a.size() - lag):
			acc += a[f] * b[f + lag]
		if acc > best_v:
			best_v = acc
			best = lag
	return best


## Angle between where the head points and where the tail end points (degrees).
func _body_bend(par: Parasite) -> float:
	var pos := _seg_positions(par)
	var tail: Vector3 = pos[pos.size() - 2] - pos[pos.size() - 1]
	return rad_to_deg(par.heading.angle_to(tail - par.up * tail.dot(par.up)))


func _par_snapshot(par: Parasite) -> Dictionary:
	return {"pos": par.global_position, "heading": par.heading, "up": par.up, "trail": par._trail.duplicate(),
			"trail_up": par._trail_up.duplicate(), "state": par.state, "clock": par._clock, "phase": par._wave_phase,
			"amp": par._wave_amp, "last": par._last_head, "crawl": par._crawl, "gait": par._gait, "stretch": par._stretch_v}


func _par_restore(par: Parasite, s: Dictionary) -> void:
	par.global_position = s["pos"]
	par.heading = s["heading"]
	par.up = s["up"]
	par._trail = s["trail"].duplicate()
	par._trail_up = s["trail_up"].duplicate()
	par.state = s["state"]
	par._clock = s["clock"]
	par._wave_phase = s["phase"]
	par._wave_amp = s["amp"]
	par._last_head = s["last"]
	par._crawl = s["crawl"]
	par._gait = s["gait"]
	par._stretch_v = s["stretch"]
	par._update_segments(0.0)


func _test_terrain_grounded() -> void:
	var worst := {}
	var floating: Array[String] = []
	var n := 0
	for b in g.balls:
		var lb: LevelBuilder = b.get_meta("builder")
		for node in _grounded_nodes(lb.root):
			n += 1
			var kind: String = node.get_meta("grounded")
			var gap := _base_gap(b, node)
			worst[kind] = maxf(worst.get(kind, -INF), gap)
			if gap > 0.05:
				var at := Levels._latlon((node.global_position - b.global_position).normalized())
				floating.append("ball %d %s at lat %.0f lon %.0f: base up to %.2f m above ground" % [b.index + 1, kind, at.x, at.y, gap])
	for f in floating:
		t.log_line(f)
	t.check("terrain_structures_meet_the_ground", n > 50 and floating.is_empty(), "%d structures; worst base gap by kind %s; %d floating" % [n, str(worst), floating.size()])


func _grounded_nodes(root: Node) -> Array:
	var out := []
	for c in root.get_children():
		if c.has_meta("grounded"):
			out.append(c)
		out.append_array(_grounded_nodes(c))
	return out


## Largest height of the structure's base ring (its lowest vertices) above the ground below it.
func _base_gap(b: MossBall, node: Node3D) -> float:
	var gap := -INF
	for mi in node.get_children():
		if not mi is MeshInstance3D or (mi as MeshInstance3D).mesh == null:
			continue
		var verts: PackedVector3Array = (mi as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var lo := INF
		for v in verts:
			lo = minf(lo, v.y)
		for v in verts:
			if v.y <= lo + 0.02:
				gap = maxf(gap, b.altitude((mi as MeshInstance3D).global_transform * v))
	return gap


func _test_terrain() -> void:
	var b := g.balls[0]
	t.check("terrain_has_hills", b.hills.size() >= 5, "%d hills" % b.hills.size())
	# Smooth profile across the biggest meadow hill: no steps, gentle slopes, flat crest.
	var hl: Array = b.hills[2]
	var c: Vector3 = hl[0]
	var ang: float = hl[1]
	var axis := c.cross(Vector3.UP).normalized()
	var max_slope := 0.0
	var max_step := 0.0
	var prev := -1.0
	# (Sampled every 10 cm or so across it, whatever its size.)
	var n := maxi(120, int(ang * 2.4 * b.radius / 0.1))
	for i in n + 1:
		var a := lerpf(-ang * 1.2, ang * 1.2, float(i) / n)
		var hgt := b.terrain_height(c.rotated(axis, a))
		if prev >= 0.0:
			var run := (ang * 2.4 / n) * b.radius
			max_slope = maxf(max_slope, absf(hgt - prev) / run)
			max_step = maxf(max_step, absf(hgt - prev))
		prev = hgt
	t.check("terrain_hills_smooth_and_gentle", max_slope < 0.5 and max_step < 0.06, "max slope %.2f, max step %.3f" % [max_slope, max_step])
	t.check("terrain_hill_height_kept", absf(b.terrain_height(c) - float(hl[2])) < 0.15, "crest %.2f authored %.2f" % [b.terrain_height(c), hl[2]])
	# Collision follows the drawn surface everywhere on the hill.
	var worst := 0.0
	for k in 40:
		var d := c.rotated(axis, ang * (k % 10) * 0.1).rotated(c, TAU * floorf(k / 10.0) / 4.0 + 0.3)
		var q := PhysicsRayQueryParameters3D.create(b.surface_point(d, 3.0), b.global_position, 1)
		var hit := g.get_world_3d().direct_space_state.intersect_ray(q)
		worst = maxf(worst, 9.0 if hit.is_empty() else absf(b.altitude(hit.position)))
	t.check("terrain_collision_matches_surface", worst < 0.08, "worst gap %.3f" % worst)
	# The drawn surface faces outward: every ground chunk and the far mesh.
	var inward := 0
	var meshes: Array = [b.get_node("MossSurface").mesh]
	for ch in b.terrain_chunks:
		meshes.append(ch.mesh)
	for mesh: ArrayMesh in meshes:
		var arr := mesh.surface_get_arrays(0)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		for i in range(0, idx.size(), 3):
			var nrm := (v[idx[i + 2]] - v[idx[i]]).cross(v[idx[i + 1]] - v[idx[i]])
			if nrm.length_squared() > 1e-10 and nrm.dot(v[idx[i]]) <= 0.0:
				inward += 1
	t.check("terrain_surface_faces_outward", inward == 0 and b.terrain_chunks.size() == 24, "%d inward faces over %d chunks and the far mesh" % [inward, b.terrain_chunks.size()])
	# He can walk up and over a hill (and stays on the ground doing it).
	var start := c.rotated(axis, -ang * 1.25)
	place(0, rad_to_deg(asin(start.y)), rad_to_deg(atan2(start.x, start.z)))
	await wait_grounded(2.0)
	var crest_seen := 0.0
	var air := 0
	var frames := 0
	for i in 240:
		stick_toward(b.surface_point(c.rotated(axis, ang * 1.4)) - p.global_position)
		await t.frames(1)
		frames += 1
		if not p.grounded:
			air += 1
		crest_seen = maxf(crest_seen, b.terrain_height(b.up_at(p.global_position)))
		# Done once over the crest and back off the far foot.
		if crest_seen > float(hl[2]) * 0.9 and b.up_at(p.global_position).angle_to(c) > ang * 1.05:
			break
	p.bot_input = Vector2.ZERO
	t.check("terrain_walk_over_hill", crest_seen > float(hl[2]) * 0.9 and air < frames * 0.15, "crest reached %.2f of %.2f, airborne %d/%d frames" % [crest_seen, hl[2], air, frames])


func _test_placements() -> void:
	# Every authored actor must land on the surface it was designed for (not on a cave roof,
	# inside a dome, or under a structure).
	var bad := []
	var n := 0
	for b in g.balls:
		var caves := []
		for h in b.get_meta("builder").bot_hints:
			if h.has("cave"):
				caves.append(b.up_at(h["door"]))
		for par in b.parasites:
			n += 1
			var hh := _surface_height(b, par.spawn_dir, par.spawn_h)
			if hh < par.spawn_h - 0.8 or hh > par.spawn_h + 2.3:
				bad.append("ball%d parasite %s h %.1f expected %.1f" % [b.index + 1, par.zone_id, hh, par.spawn_h])
		for m in b.motes:
			n += 1
			var hh := _surface_height(b, m._dir, m.h_hint)
			if hh < m.h_hint - 0.8 or hh > m.h_hint + 2.3:
				bad.append("ball%d mote %s h %.1f expected %.1f" % [b.index + 1, m.zone_id, hh, m.h_hint])
		for bl in b.blooms:
			n += 1
			var hh := _surface_height(b, bl.dir, bl.h_hint)
			if absf(hh - bl.h_hint) > 0.8:
				bad.append("ball%d bloom h %.1f expected %.1f" % [b.index + 1, hh, bl.h_hint])
		for hole in b.food_spots:
			n += 1
			for c in caves:
				if (hole["dir"] as Vector3).angle_to(c) < deg_to_rad(12):
					bad.append("ball%d burrow hole inside cave" % (b.index + 1))
	t.check("actors_placed_on_intended_surfaces", bad.is_empty(), "%d checked; %s" % [n, "; ".join(bad)])
	# World expansion: nothing a player must reach starts down in a ravine (or on its walls).
	var in_cut: Array[String] = []
	for b in g.balls:
		if b.carves.is_empty():
			continue
		for par in b.parasites:
			if b.ravine_carve(par.spawn_dir) > 0.3:
				in_cut.append("ball%d parasite %s" % [b.index + 1, par.zone_id])
		for m in b.motes:
			if b.ravine_carve(m._dir) > 0.3 and m.h_hint < 1.0:
				in_cut.append("ball%d mote %s" % [b.index + 1, m.zone_id])
		for bl in b.blooms:
			if b.ravine_carve(bl.dir) > 0.3 and bl.h_hint < 1.0:
				in_cut.append("ball%d bloom" % (b.index + 1))
	t.check("nothing_starts_in_a_ravine", in_cut.is_empty(), str(in_cut))


func _test_tutorial_route() -> void:
	# The opening terrain must teach: walk -> jump onto M1 -> jump + water burst across to M2.
	# (Laid out in metres from the pole, Levels.TUT_*: the tutorial kept its size when the ball grew.)
	var b := g.balls[0]
	var pole_m := func() -> float: return Levels.tut_m(b.up_at(p.global_position))
	var results := []
	for start_m in [0.21, 1.68, 2.3]:
		place(0, Levels.tut_lat(start_m), 0, 0.2, 180)
		p.invuln_t = 999
		await wait_grounded()
		var toward := b.surface_point(Levels.tut_dir(8.38)) - p.global_position
		# Walk toward M1 and jump just before the wall.
		for i in 120:
			stick_toward(toward)
			await t.frames(1)
			if b.surface_point(b.up_at(p.global_position)).distance_to(b.surface_point(Levels.tut_dir(Levels.TUT_M1_M))) < 3.56:
				break
		await press("jump")
		for i in 50:
			stick_toward(toward)
			await t.frames(1)
		p.bot_input = Vector2.ZERO
		await wait_grounded()
		var on_m1 := height() > 1.0
		# Across the gap: jump from the far edge, burst at the apex.
		for i in 90:
			stick_toward(toward)
			await t.frames(1)
			if pole_m.call() >= 6.03 or height() < 1.0:
				break
		t.log_line("start %.2f m: at edge %.2f m h %.2f grounded %s" % [start_m, pole_m.call(), height(), p.grounded])
		await press("jump")
		for i in 18:
			stick_toward(toward)
			await t.frames(1)
		await press("jump")
		for i in 60:
			stick_toward(toward)
			await t.frames(1)
			if p.grounded and i > 10:
				break
		p.bot_input = Vector2.ZERO
		await wait_grounded()
		var on_m2 := height() > 2.6
		t.log_line("   landed %.2f m h %.2f" % [pole_m.call(), height()])
		results.append([start_m, on_m1, on_m2])
	var ok := results.all(func(r): return r[1] and r[2])
	t.check("tutorial_jump_then_burst_route", ok, str(results))
	# Without the water burst, the gap to M2 is too wide: the burst is genuinely taught.
	place(0, Levels.tut_lat(5.03), 0, 1.5, 180)
	await wait_grounded()
	var toward2 := b.surface_point(Levels.tut_dir(12.57)) - p.global_position
	for i in 90:
		stick_toward(toward2)
		await t.frames(1)
		if pole_m.call() >= 6.45:
			break
	await press("jump")
	for i in 70:
		stick_toward(toward2)
		await t.frames(1)
		if p.grounded and i > 10:
			break
	p.bot_input = Vector2.ZERO
	await wait_grounded()
	t.check("tutorial_gap_needs_burst", height() < 2.0, "plain jump landed at h %.2f" % height())
	p.invuln_t = 0.0


func _test_sphere_walk() -> void:
	# Walk continuously "forward" and go all the way around moss ball #1.
	# (Round the equator: the one great circle clear of the upland's ravines and the formations.)
	place(0, 0, -140, 0.2, 90)
	await wait_grounded()
	p.invuln_t = 999
	var prev_up := p.up
	var travelled := 0.0
	var air_frames := 0
	var flips := 0
	var max_dev := 0.0
	var frames := 0
	p.bot_input = Vector2(0, 1)
	# (70 s went round the original 24 m ball; the time allowed grows with its size.)
	while travelled < TAU and frames < int(60 * 70 * g.balls[0].radius / 24.0):
		await t.frames(1)
		frames += 1
		travelled += prev_up.angle_to(p.up)
		prev_up = p.up
		if not p.grounded:
			air_frames += 1
		if g.cam.cam_up.dot(p.up) < 0.2:
			flips += 1
		max_dev = maxf(max_dev, absf(height()))
		# Keep going "forward" relative to the camera; hop small obstacles.
		if frames % 90 == 0 and p.velocity.length() < 2.0:
			await press("jump")
	p.bot_input = Vector2.ZERO
	t.check("sphere_walk_full_circle", travelled >= TAU, "travelled %.0f deg in %.1fs" % [rad_to_deg(travelled), frames / 60.0])
	t.check("sphere_walk_mostly_grounded", air_frames < frames * 0.15, "air %d/%d frames" % [air_frames, frames])
	t.check("camera_no_flip", flips == 0, "flip frames %d" % flips)
	t.check("stays_on_surface", max_dev < 4.0, "max height deviation %.2f" % max_dev)
	p.invuln_t = 0.0


func _test_jump_and_burst() -> void:
	place(0, -5, -150, 0.2, 0)
	await wait_grounded()
	await t.seconds(0.3)
	var h0 := height()
	var jumps := [0]
	var bursts := [0]
	var cj := func(): jumps[0] += 1
	var cb := func(): bursts[0] += 1
	p.jumped.connect(cj)
	p.burst_used.connect(cb)
	await press("jump")
	var apex := 0.0
	for i in 70:
		await t.frames(1)
		apex = maxf(apex, height() - h0)
	t.check("jump_apex", apex > 1.5 and apex < 2.2, "apex %.2f" % apex)
	await wait_grounded()
	# Jump, then a second press in the air = directional water burst (exactly once).
	p.bot_input = Vector2(0, 1)
	await press("jump")
	await t.seconds(0.35)
	var v_before := p.velocity.dot(p.up)
	await press("jump")
	await t.frames(1)
	var v_after := p.velocity.dot(p.up)
	t.check("burst_on_second_press", bursts[0] == 1 and v_after > v_before + 3.0, "vup %.1f -> %.1f bursts %d" % [v_before, v_after, bursts[0]])
	t.check("burst_follows_direction", (p.velocity - p.up * p.velocity.dot(p.up)).length() > 7.0, "horizontal %.1f" % (p.velocity - p.up * p.velocity.dot(p.up)).length())
	await t.seconds(0.1)
	var v3 := p.velocity.dot(p.up)
	await press("jump")
	await t.frames(1)
	t.check("no_third_air_action", bursts[0] == 1 and jumps[0] == 2 and p.velocity.dot(p.up) <= v3 + 0.1, "bursts %d jumps %d" % [bursts[0], jumps[0]])
	p.bot_input = Vector2.ZERO
	var landed := await wait_grounded()
	await t.frames(2)
	t.check("landing_resets_burst", landed and p.burst_available, "available %s" % p.burst_available)
	p.jumped.disconnect(cj)
	p.burst_used.disconnect(cb)


func _test_coyote_and_buffer() -> void:
	# Coyote time: walk off the tutorial cushion M1 and jump a few frames late.
	var b := g.balls[0]
	var m1 := Levels.tut_dir(Levels.TUT_M1_M)
	var edge_dir := Levels.tut_dir(5.74)
	place_at(0, b.surface_point(edge_dir, 1.4), b.surface_point(Levels.tut_dir(8.38)) - b.surface_point(edge_dir))
	p.invuln_t = 999
	await wait_grounded()
	var jumps := [0]
	var cj := func(): jumps[0] += 1
	p.jumped.connect(cj)
	p.bot_input = Vector2(0, 1)
	var left_ground := -1
	for i in 120:
		await t.frames(1)
		if not p.grounded:
			left_ground = i
			break
	await t.frames(4)   # ~0.067 s after leaving the ledge
	await press("jump")
	await t.frames(1)
	t.check("coyote_jump", jumps[0] == 1 and p.velocity.dot(p.up) > 6.0, "left at %d, jumps %d vup %.1f" % [left_ground, jumps[0], p.velocity.dot(p.up)])
	# Jump buffering: burst, then press again just before landing -> jumps on touchdown.
	await t.frames(10)
	await press("jump")  # burst
	p.bot_input = Vector2.ZERO
	for i in 200:
		await t.frames(1)
		if p.velocity.dot(p.up) < 0.0 and height() < 0.75 + (1.3 if b.up_at(p.global_position).angle_to(m1) < 1.885 / (b.radius + Levels.UPLAND_H) else 0.0):
			break
	var before: int = jumps[0]
	await press("jump")
	var buffered := false
	for i in 30:
		await t.frames(1)
		if jumps[0] > before:
			buffered = true
			break
	t.check("jump_buffer", buffered, "jumps %d -> %d" % [before, jumps[0]])
	p.jumped.disconnect(cj)
	await wait_grounded()
	p.invuln_t = 0.0


## Waits out any cinematic (e.g. the tutorial's framing shot after its patch is cleared), which
## takes the controls away for a few seconds, so an input test is not decided by timing.
func controls_ready() -> void:
	for i in 60 * 8:
		if g.cinematic == "" and p.controls_enabled:
			return
		await t.frames(1)


func _swipe_at(par: Parasite, behind: bool) -> void:
	await controls_ready()
	var b := par.ball
	var up := b.up_at(par.global_position)
	var fwd := MossBall.frame_at(up, 0).z * -1.0
	var pos := par.global_position + fwd * 1.1
	var face := fwd if behind else -fwd
	place_at(b.index, b.surface_point(b.up_at(pos), 0.1), face)
	p.invuln_t = 999
	await t.frames(2)
	await press("swipe")
	await t.seconds(0.4)


## Stand 1.1 from the parasite, facing `fwd`, with the parasite `deg` degrees off that facing.
## The parasite is held still meanwhile (a small one darts when he appears beside it, which would
## change the very angle being tested); the caller lets it go again.
func _place_at_angle(par: Parasite, deg: float) -> void:
	await controls_ready()
	par.set_physics_process(false)
	var b := par.ball
	var up := b.up_at(par.global_position)
	var fwd := MossBall.frame_at(up, 0).z * -1.0
	var pos := par.global_position - fwd.rotated(up, deg_to_rad(deg)) * 1.1
	place_at(b.index, b.surface_point(b.up_at(pos), 0.1), fwd)
	p.invuln_t = 999
	await t.frames(2)


func _test_swipe_direction_and_stages() -> void:
	await t.seconds(0.2)
	# Arc geometry, without aim assist: only a 90-degree cone straight ahead is safe.
	var small := first_alive(0, Parasite.Kind.SMALL, "meadow")
	await _place_at_angle(small, 25.0)
	g.player_swipe(p)
	t.check("swipe_misses_front_cone", small.is_alive(), "hp %d" % small.hp)
	await _place_at_angle(small, 65.0)
	g.player_swipe(p)
	t.check("swipe_hits_270_arc", not small.is_alive(), "hp %d" % small.hp)
	small.set_physics_process(true)
	# Aim assist: a parasite dead ahead gets swept after a part-way turn.
	var ahead := first_alive(0, Parasite.Kind.SMALL, "meadow")
	await _place_at_angle(ahead, 0.0)
	var f0 := p.facing
	await press("swipe")
	await t.seconds(0.4)
	ahead.set_physics_process(true)
	var turned := rad_to_deg(f0.angle_to(p.facing))
	t.check("swipe_aim_turns_and_hits_ahead", not ahead.is_alive() and turned > 20.0 and turned < 62.0, "hp %d turned %.0f deg" % [ahead.hp, turned])
	small = first_alive(0, Parasite.Kind.SMALL, "east")
	await _swipe_at(small, true)
	t.check("swipe_kills_small_behind", not small.is_alive(), "hp %d" % small.hp)
	var med := first_alive(0, Parasite.Kind.MEDIUM, "east")
	await _swipe_at(med, true)
	t.check("medium_first_hit_half_grey", med.hp == 1 and is_equal_approx(med._gray_target, 0.5), "hp %d grey %.2f" % [med.hp, med._gray_target])
	await t.seconds(0.6)
	await _swipe_at(med, true)
	t.check("medium_second_hit_kills", not med.is_alive() and med._gray_target >= 1.0, "hp %d" % med.hp)
	var large := first_alive(0, Parasite.Kind.LARGE)
	var stages := []
	for i in 3:
		var before := large.hp
		for attempt in 6:
			await t.seconds(1.6)
			while large.state == "flung":
				await t.frames(5)
			await _swipe_at(large, true)
			if large.hp < before:
				break
		stages.append(snappedf(large._gray_target, 0.01))
	t.check("large_three_stage_desaturation", stages == [0.33, 0.67, 1.0] and not large.is_alive(), str(stages))
	# Head-to-rear order: the head segment has the lowest seg_t.
	var s0: float = large._segs[0].get_instance_shader_parameter("seg_t")
	var s_last: float = large._segs[large._segs.size() - 1].get_instance_shader_parameter("seg_t")
	t.check("desaturation_head_to_rear", s0 < s_last, "head %.2f tail %.2f" % [s0, s_last])
	# Death: drains, detaches, drifts away, then becomes a cheap speck.
	var saw_drift := false
	for i in 60 * 20:
		await t.frames(1)
		if large.state == "drifting":
			saw_drift = true
		if large.state == "gone":
			break
	t.check("dead_parasite_drifts_then_handoff", saw_drift and large.state == "gone", "state %s" % large.state)


func _test_hard_landing() -> void:
	var small := first_alive(0, Parasite.Kind.SMALL, "west")
	var b := g.balls[0]
	await t.frames(2)
	var d := b.up_at(small.global_position)
	place_at(0, b.surface_point(d, 4.6), MossBall.frame_at(d, 0).z)
	p.invuln_t = 999
	var kinds := []
	var cl := func(k): kinds.append(k)
	p.landed.connect(cl)
	await wait_grounded()
	await t.frames(3)
	t.check("hard_landing_kills_small", "hard" in kinds and not small.is_alive(), str(kinds))
	# Larger parasite: one damage stage plus knockback.
	var med := first_alive(0, Parasite.Kind.MEDIUM, "west")
	await t.frames(2)
	var hp0 := med.hp
	var mp := med.global_position
	d = b.up_at(med.global_position)
	place_at(0, b.surface_point(d, 4.6), MossBall.frame_at(d, 0).z)
	await wait_grounded()
	await t.seconds(0.3)
	t.check("hard_landing_one_stage_on_medium", med.hp == hp0 - 1 and med.global_position.distance_to(mp) > 0.5, "hp %d->%d moved %.2f" % [hp0, med.hp, med.global_position.distance_to(mp)])
	p.landed.disconnect(cl)
	p.invuln_t = 0.0


func _spawn_food(type: int) -> Food:
	var b := p.ball
	var f := Food.new()
	var pos := p.head_position() + p.facing * 1.2
	if type == Food.Type.BURROWER:
		var hole := {"dir": b.up_at(pos), "h": 0.0, "occupied": false}
		f.setup_burrower(b, hole)
		f.state = "exposed"
		f.expose = 0.5
		f._cd = 99
	else:
		f.setup(b, type, pos, b.up_at(pos), 30.0)
		f.state = "idle"
		f._cd = 99
		f._hover = height() + 0.25
	b.add_child(f)
	b.foods.append(f)
	return f


func _eat_test(type: int, start_health: int, expect: int, label: String) -> void:
	place(0, -12, -130, 0.1, 90)
	p.invuln_t = 999
	await wait_grounded()
	p.health = start_health
	p.model.set_health(p.health, p.max_health, false)
	var f := _spawn_food(type)
	await t.frames(3)
	if type == Food.Type.BURROWER:
		f._update_burrower(0.0, p)
		f.state = "exposed"
		f.expose = 0.5
	await press("lunge")
	await t.seconds(0.4)
	t.check(label, not is_instance_valid(f) and p.health == expect, "health %d expected %d" % [p.health, expect])


func _test_food() -> void:
	await _eat_test(Food.Type.DRIFTER, 1, 2, "drifter_restores_1")
	await _eat_test(Food.Type.DARTER, 1, 3, "darter_restores_2")
	p.max_health = 3
	await _eat_test(Food.Type.BURROWER, 1, 3, "burrower_restores_all")
	await _eat_test(Food.Type.DRIFTER, 3, 3, "eat_at_full_health")
	p.invuln_t = 0.0


func _test_food_reach() -> void:
	# Drifters and darters hover at about head height.
	var hovers := []
	for i in 40:
		var probe := Food.new()
		probe.setup(p.ball, Food.Type.DRIFTER if i % 2 == 0 else Food.Type.DARTER, Vector3.ZERO, Vector3.UP, 20.0)
		hovers.append(probe._hover)
		probe.free()
	var jump_apex := Axolotl.JUMP_V * Axolotl.JUMP_V / (2.0 * Axolotl.GRAVITY)
	t.check("lunge_reach_stays_below_jump", Game.LUNGE_AIM_ABOVE < jump_apex - 0.2, "lunge %.2f jump %.2f" % [Game.LUNGE_AIM_ABOVE, jump_apex])
	t.check("food_hovers_at_head_height", hovers.min() >= Food.HOVER_MIN and hovers.max() <= Food.HOVER_MAX and Food.HOVER_MAX <= 0.9, "%.2f..%.2f" % [hovers.min(), hovers.max()])
	# Food floating well above the head and off to one side: the lunge turns and rises to it.
	place(0, -12, -130, 0.1, 90)
	p.invuln_t = 999
	await wait_grounded()
	p.health = 1
	p.model.set_health(p.health, p.max_health, false)
	var f := _spawn_food(Food.Type.DRIFTER)
	f.set_physics_process(false)   # hold it still: only the lunge's aim is being tested
	var side := p.facing.rotated(p.up, deg_to_rad(35.0))
	f.global_position = p.body_center() + side * 1.8 + p.up * 1.4
	await t.frames(2)
	await press("lunge")
	await t.seconds(0.5)
	var too_high := _spawn_food(Food.Type.DRIFTER)
	too_high.set_physics_process(false)
	too_high.global_position = p.body_center() + p.facing * 1.5 + p.up * (Game.LUNGE_AIM_ABOVE + 0.6)
	t.check("lunge_ignores_food_out_of_reach", Game.inst.lunge_target(p, p.facing) != too_high, "")
	p.ball.foods.erase(too_high)
	too_high.queue_free()
	t.check("lunge_rises_and_turns_to_high_food", not is_instance_valid(f) and p.health == 2, "health %d" % p.health)
	# The lunge's own wake no longer blows nearby food away.
	await wait_grounded()
	var g := _spawn_food(Food.Type.DRIFTER)
	g.global_position = p.body_center() - p.facing * 1.6
	var g0 := g.global_position
	await press("lunge")
	await t.seconds(0.8)
	var moved := g.global_position.distance_to(g0) if is_instance_valid(g) else -1.0
	t.check("lunge_wake_leaves_food_in_place", is_instance_valid(g) and moved < 0.5, "moved %.2f" % moved)
	if is_instance_valid(g):
		p.ball.foods.erase(g)
		g.queue_free()
	p.invuln_t = 0.0


func _test_darter_and_burrower() -> void:
	place(0, -12, -130, 0.1, 90)
	await wait_grounded()
	p.invuln_t = 999
	var f := _spawn_food(Food.Type.DARTER)
	f._cd = 0.0
	var start := f.global_position
	p.bot_input = Vector2(0, 1)
	var darted := false
	for i in 90:
		await t.frames(1)
		if not is_instance_valid(f):
			break
		if f.state == "dart" or f.state == "pause":
			darted = true
	p.bot_input = Vector2.ZERO
	t.check("darter_senses_and_darts", darted, "moved %.2f" % (f.global_position.distance_to(start) if is_instance_valid(f) else -1.0))
	if is_instance_valid(f):
		f.queue_free()
		p.ball.foods.erase(f)
	place(0, -12, -110, 0.1, 90)
	await wait_grounded()
	var w := _spawn_food(Food.Type.BURROWER)
	w._cd = 0.0
	await t.frames(2)
	w.state = "exposed"
	w.expose = 0.5
	var retreated := false
	p.bot_input = Vector2(0, 1)
	for i in 60:
		await t.frames(1)
		if w.state == "retreating" or w.state == "hidden":
			retreated = true
	p.bot_input = Vector2.ZERO
	place(0, -12, -80, 0.1, 90)
	var reemerged := false
	for i in 60 * 12:
		await t.frames(1)
		if w.state == "exposed":
			reemerged = true
			break
	t.check("burrower_retreats_and_reemerges", retreated and reemerged, "retreated %s reemerged %s" % [retreated, reemerged])
	p.invuln_t = 0.0


## Food comes back after it is eaten (repopulation: local region targets and cooldowns, arrivals
## out of view; the detailed rules are in _test_repopulation).
func _test_food_repopulates() -> void:
	var b := g.balls[0]
	place(0, 10, -20, 0.1, 0)
	b.foods = b.foods.filter(func(f): return is_instance_valid(f))
	for f in b.foods.duplicate():
		f.eaten()
		b.foods.erase(f)
	await t.frames(2)
	var want := 0
	for reg in g.food.regions_of(b):
		reg["ready"] = 0.0
		if g.food.is_local(b, reg, p.global_position):
			want += 1
	var spawned_far := true
	var start := b.foods.size()
	for i in 60 * 30:
		await t.frames(1)
		if b.foods.size() > start:
			var nf: Food = b.foods[b.foods.size() - 1]
			if nf.type != Food.Type.BURROWER and b.up_at(nf.global_position).angle_to(p.up) < deg_to_rad(10):
				spawned_far = false
			start = b.foods.size()
		if b.foods.size() >= want:
			break
	# (The region he stands in may stay in view the whole time: it can wait.)
	t.check("food_repopulates_out_of_view", want > 0 and b.foods.size() >= maxi(1, want - 1) and spawned_far, "count %d in 30 s (local regions %d)" % [b.foods.size(), want])


func _test_motes() -> void:
	var b := g.balls[0]
	var m: Mote = null
	for mm in b.motes:
		if mm.h_hint < 0.1 and mm.is_available() and m == null:
			m = mm
	var up := b.up_at(m.global_position)
	var fwd := MossBall.frame_at(up, 0).z * -1.0
	# Touching without lunging does nothing.
	place_at(0, m.anchor + m.anchor_up * 0.3 - fwd * 0.4, fwd)
	p.invuln_t = 999
	await t.seconds(1.0)
	t.check("mote_not_auto_collected", m.is_available(), m.state)
	# Near miss: the lunge's water pushes it away.
	var side := fwd.cross(up)
	m.set_physics_process(false)   # hold it still so only the lunge's water moves it
	m.vel = Vector3.ZERO
	# Pass beside where the mote actually is (it wanders up to ~3.5 from its anchor).
	var mp := m.global_position - m.anchor_up * (m.global_position - m.anchor).dot(m.anchor_up)
	# (No food near it: a lunge homing in on food is a catch, not a near miss, and pushes nothing.)
	for f in b.foods.duplicate():
		if is_instance_valid(f) and f.global_position.distance_to(mp) < 6.0:
			b.foods.erase(f)
			f.queue_free()
	place_at(0, mp + m.anchor_up * 0.3 - fwd * 1.8 + side * 1.6, fwd)
	await t.frames(2)
	await press("lunge")
	var v0 := m.vel
	var dv := 0.0
	var hit := false
	for k in 24:
		await t.frames(1)
		hit = hit or p.lunge_hit
		dv = maxf(dv, (m.vel - v0).length())
		v0 = m.vel
	m.set_physics_process(true)
	t.check("mote_pushed_by_near_miss", m.is_available() and dv > 0.6, "velocity change %.2f (lunge hit something: %s)" % [dv, hit])
	await t.seconds(1.5)
	# Aim and lunge: captured, dives into the moss, restores the patch.
	var r0 := b.restoration
	for attempt in 6:
		up = b.up_at(m.global_position)
		var to := m.global_position - p.global_position
		var gp := m.global_position - m.anchor_up * (m.global_position - m.anchor).dot(m.anchor_up)
		place_at(0, gp + m.anchor_up * 0.3 - fwd * 1.3, fwd)
		await wait_grounded(1.0)
		await t.frames(1)
		var d := m.global_position - p.head_position()
		p.facing = (d - p.up * d.dot(p.up)).normalized()
		var mind := 99.0
		if (m.global_position - p.global_position).dot(p.up) > 0.8:
			await press("jump")
			for k in 30:
				await t.frames(1)
				if (m.global_position - p.head_position()).dot(p.up) < 0.3 or p.velocity.dot(p.up) < 1.0:
					break
			var dd := m.global_position - p.head_position()
			p.facing = (dd - p.up * dd.dot(p.up)).normalized()
		Input.action_press("lunge")
		await t.frames(1)
		Input.action_release("lunge")
		for k in 24:
			mind = minf(mind, m.global_position.distance_to(p.head_position()))
			await t.frames(1)
		t.log_line("mote attempt %d: min head distance %.2f mote h %.2f state %s lunge %.2f" % [attempt, mind, (m.global_position - p.global_position).dot(p.up), m.state, p.lunge_t])
		if not m.is_available():
			break
	await t.seconds(1.2)
	t.check("mote_captured_with_lunge", m.state == "done" and b.restoration > r0, "state %s restoration %.3f -> %.3f" % [m.state, r0, b.restoration])
	p.invuln_t = 0.0


func _test_checkpoint_and_regen() -> void:
	var b := g.balls[0]
	var bloom: Bloom = b.blooms[0]
	place_at(0, bloom.global_position + b.up_at(bloom.global_position) * 0.3, MossBall.frame_at(b.up_at(bloom.global_position), 0).z)
	await t.seconds(0.5)
	t.check("bloom_activates", bloom.active and g.checkpoint == bloom, "")
	var r_before := b.restoration
	var kills_before: int = g.stats["kills"]
	place(0, -20, -140, 0.1, 0)
	await wait_grounded()
	p.invuln_t = 0.0
	for i in p.max_health:
		p.invuln_t = 0.0
		p.take_damage(1, p.global_position + p.facing)
		await t.frames(2)
	t.check("death_enters_regeneration", p.state == "dead" and g.cinematic == "regen", "state %s cine %s" % [p.state, g.cinematic])
	for i in 60 * 6:
		await t.frames(1)
		if g.cinematic == "":
			break
	t.check("regenerates_at_last_bloom", p.global_position.distance_to(bloom.respawn_point()) < 1.5 and p.state == "normal", "dist %.2f" % p.global_position.distance_to(bloom.respawn_point()))
	t.check("regeneration_with_a_third_of_health", p.health == Game.respawn_health(p.max_health), "health %d/%d" % [p.health, p.max_health])
	t.check("restoration_survives_regeneration", is_equal_approx(b.restoration, r_before) and g.stats["kills"] == kills_before, "")


func _test_crumble() -> void:
	var b := g.balls[0]
	var c: Platforms.Crumble = b.crumbles[0]
	var up := b.up_at(c.global_position)
	place_at(0, c.global_position + up * 0.6, MossBall.frame_at(up, 0).z)
	p.invuln_t = 999
	var fell := false
	for i in 60:
		await t.frames(1)
		if c._state == "gone":
			fell = true
			break
	t.check("brittle_moss_crumbles", fell, c._state)
	# The whole raised formation (cap and stalk) is gone: Gill drops to the ground below it and
	# nothing regrows into Gill while Gill stays at the foot of it.
	await t.seconds(5.0)
	var stalk_gone: bool = c._stalk == null or (not c._stalk.visible and c._stalk_shape.disabled)
	t.check("brittle_moss_whole_formation_crumbles", stalk_gone and b.altitude(p.global_position) < 0.6, "player %.2f m above ground" % b.altitude(p.global_position))
	t.check("brittle_moss_waits_for_gill_to_move", c._state == "gone", c._state)
	place_at(0, b.surface_point(b.up_at(c.global_position).rotated(Vector3.UP, 0.25), 0.1), MossBall.frame_at(up, 0).z)
	await t.seconds(1.5)
	t.check("brittle_moss_regrows", c._state == "solid" and (c._stalk == null or (c._stalk.visible and not c._stalk_shape.disabled)), c._state)
	p.invuln_t = 0.0


func _test_restoration_continuity() -> void:
	# Tiny actions make tiny changes: the global aquarium value never jumps.
	var b := g.balls[0]
	var zone := "under"
	var par: Parasite = null
	for pp in b.parasites:
		if pp.zone_id == zone and pp.is_alive():
			par = pp
	var g_prev := g.g_disp
	var max_step := 0.0
	var vortex_prev: float = b.vortex_out.strength
	var vortex_step := 0.0
	par.hit(par.hp, par.global_position)
	for i in 60 * 5:
		await t.frames(1)
		max_step = maxf(max_step, g.g_disp - g_prev)
		vortex_step = maxf(vortex_step, b.vortex_out.strength - vortex_prev)
		g_prev = g.g_disp
		vortex_prev = b.vortex_out.strength
	t.check("aquarium_changes_continuously", max_step > 0.0 and max_step < 0.001, "max per-frame step %.5f" % max_step)
	t.check("vortex_grows_continuously", vortex_step > 0.0 and vortex_step < 0.003, "max per-frame step %.5f" % vortex_step)


func _complete_until(b: MossBall, target: float) -> void:
	for par in b.parasites:
		if b.restoration >= target:
			return
		if par.is_alive():
			par.hit(par.hp, par.global_position)
			await t.frames(1)
	for m in b.motes:
		if b.restoration >= target:
			return
		if m.is_available():
			m.capture()
			await t.seconds(0.9)


## Each vortex connection's faint hue (owner, 2026-09-30): stable by link, the same on its jets and
## at both ends, and no two connections from the same ball alike; travel itself is untouched.
func _test_vortex_tints() -> void:
	var same_ends := true
	var stable := true
	for li in g.vortices.size():
		var v: Vortex = g.vortices[li]
		stable = stable and v.tint == Vortex.TINTS[li % Vortex.TINTS.size()]
		var mats: Array = [v._jet_mat, v._stream_mat] + v._pool_mats + v._debris_mats
		for m in mats:
			same_ends = same_ends and (m as ShaderMaterial).get_shader_parameter("tint") == v.tint \
					and is_equal_approx(float((m as ShaderMaterial).get_shader_parameter("tint_amt")), Vortex.TINT_AMT)
	var distinct := true
	var worst := INF
	for b in g.balls:
		for i in b.vortices.size():
			for j in range(i + 1, b.vortices.size()):
				var a: Color = (b.vortices[i] as Vortex).tint
				var c: Color = (b.vortices[j] as Vortex).tint
				var d := Vector3(a.r - c.r, a.g - c.g, a.b - c.b).length()
				worst = minf(worst, d)
				distinct = distinct and d > 0.3
	t.check("vortex_tints_per_connection", same_ends and stable and distinct and g.vortices.size() == Levels.LINKS.size(),
			"%d connections, both ends %s, stable %s, closest pair sharing a ball %.2f apart" % [g.vortices.size(), same_ends, stable, worst])


## Vortex currents (ledger row 14): the visible centreline meanders as a moving water current over a
## fixed logical path. The stable parameter u (0 = ball A, 0.5 = midpoint, 1 = ball B) reaches every
## vortex shader; the mouths stay anchored; the offset is bounded, slow and keeps clear of the balls;
## several influences per axis; no two connections in sync; deterministic; no repeat over 30 minutes.
func _test_vortex_currents() -> void:
	# u along the connection.
	var u_ok := true
	var u_bad: Array[String] = []
	for v: Vortex in g.vortices:
		var mesh: ArrayMesh = (v.get_node("Jets") as MeshInstance3D).mesh
		var arr := mesh.surface_get_arrays(0)
		var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		var cus: PackedFloat32Array = arr[Mesh.ARRAY_CUSTOM0]
		var lo := INF
		var hi := -INF
		var mid_err := INF
		var same := true
		for i in uvs.size():
			lo = minf(lo, uvs[i].y)
			hi = maxf(hi, uvs[i].y)
			same = same and is_equal_approx(cus[i * 4 + 3], uvs[i].y)
			# (Each ring's own path point is the logical path at its u; the rings nearest the middle.)
			if absf(uvs[i].y - 0.5) < 0.02:
				mid_err = minf(mid_err, Vector3(cus[i * 4], cus[i * 4 + 1], cus[i * 4 + 2]).distance_to(v.sample(uvs[i].y)[0]))
		var ends := (v.sample(0.0)[0] as Vector3).distance_to(v.mouth_pos(false)) < 2.0 and (v.sample(1.0)[0] as Vector3).distance_to(v.mouth_pos(true)) < 2.0
		var mats := is_equal_approx(float(v._pool_mats[0].get_shader_parameter("u_end")), 0.0) and is_equal_approx(float(v._pool_mats[1].get_shader_parameter("u_end")), 1.0) \
				and is_equal_approx(float(v._debris_mats[0].get_shader_parameter("u_end")), 0.0) and is_equal_approx(float(v._debris_mats[1].get_shader_parameter("u_end")), 1.0)
		var code := v._jet_mat.shader.code.contains("vortex_current.gdshaderinc") and v._debris_mats[0].shader.code.contains("vortex_current.gdshaderinc")
		var ok := is_zero_approx(lo) and is_equal_approx(hi, 1.0) and same and mid_err < 0.05 and ends and mats and code
		if not ok:
			u_bad.append("%d-%d: u %.3f..%.3f custom %s mid %.3f ends %s mats %s code %s" % [v.ball_a.index + 1, v.ball_b.index + 1, lo, hi, same, mid_err, ends, mats, code])
		u_ok = u_ok and ok
	t.check("vortex_current_u_parameter", u_ok and g.vortices.size() == Levels.LINKS.size(), "; ".join(u_bad))
	# Mouths anchored, bounded, slow, clear of every ball, several influences per axis.
	var worst_mouth := 0.0
	var worst_ratio := 0.0
	var worst_speed := 0.0
	var worst_clear := INF
	var min_peak := INF
	var min_split := INF
	var detail: Array[String] = []
	for v: Vortex in g.vortices:
		var bound := v.current_bound()
		var peak := 0.0
		for i in 900:
			var tm := i * 4.03
			worst_mouth = maxf(worst_mouth, maxf(v.current_offset_at(0.0, tm).length(), v.current_offset_at(1.0, tm).length()))
			worst_mouth = maxf(worst_mouth, maxf(v.current_offset_at(0.02, tm).length(), v.current_offset_at(0.98, tm).length()) / bound * 0.1)
			for j in 11:
				var u := 0.08 + 0.84 * j / 10.0
				var d := v.current_offset_at(u, tm)
				peak = maxf(peak, d.length())
				worst_ratio = maxf(worst_ratio, d.length() / bound)
				if i % 9 == 0:
					# The current never brings the water nearer a ball than the straight tunnel was
					# (or, where that was far, keeps the jets well clear of it).
					var lp: Vector3 = v.sample(u)[0]
					var vp: Vector3 = lp + d
					for b in g.balls:
						var cl_v := vp.distance_to(b.global_position) - b.radius - v.helix_radius(u, Vortex.TUBE_RADIUS)
						var cl_l := lp.distance_to(b.global_position) - b.radius - v.helix_radius(u, Vortex.TUBE_RADIUS)
						worst_clear = minf(worst_clear, cl_v - minf(cl_l, 4.0))
			var sp := (v.current_offset_at(0.5, tm + 0.1) - v.current_offset_at(0.5, tm)).length() / 0.1
			worst_speed = maxf(worst_speed, sp)
		min_peak = minf(min_peak, peak / v._length)
		worst_ratio = maxf(worst_ratio, peak / (v._length * 0.16))
		for ax in 3:
			var ws := [v.cur_omega[0][ax], v.cur_omega[1][ax], v.cur_omega[2][ax]]
			for i in 3:
				for j in range(i + 1, 3):
					min_split = minf(min_split, absf(ws[i] - ws[j]) / maxf(ws[i], ws[j]))
		detail.append("%d-%d len %.0f bound %.1f peak %.1f" % [v.ball_a.index + 1, v.ball_b.index + 1, v._length, bound, peak])
	t.check("vortex_current_mouths_anchored", worst_mouth < 0.02, "worst offset at the mouths %.4f m" % worst_mouth)
	t.check("vortex_current_bounded", worst_ratio <= 1.0 and worst_clear > -0.5 and min_peak > 0.03, "max |D| / min(bound, 16%% of length) %.2f; clearance from every ball vs the straight tunnel's (capped at 4 m) %+.1f m; smallest peak %.1f%% of length; %s" % [worst_ratio, worst_clear, min_peak * 100.0, ", ".join(detail)])
	t.check("vortex_current_slow_several_influences", worst_speed < 1.6 and min_split > 0.15, "mid-span speed <= %.2f m/s; closest two frequencies on one axis differ by %.0f%%" % [worst_speed, min_split * 100.0])
	# No two connections in sync: correlation of their mid-span offsets over 20 minutes (and of their
	# shapes, the quarter-span against the three-quarter-span).
	var series: Array = []
	for v: Vortex in g.vortices:
		var sr: Array[Vector3] = []
		for i in 2400:
			sr.append(v.cur_basis.inverse() * v.current_offset_at(0.5, i * 0.5))
		series.append(sr)
	var worst_corr := 0.0
	for a in series.size():
		for b in range(a + 1, series.size()):
			for ax in 3:
				var sab := 0.0
				var saa := 0.0
				var sbb := 0.0
				for i in 2400:
					var x: float = series[a][i][ax]
					var y: float = series[b][i][ax]
					sab += x * y
					saa += x * x
					sbb += y * y
				worst_corr = maxf(worst_corr, absf(sab) / sqrt(maxf(saa * sbb, 1e-9)))
	t.check("vortex_current_not_in_sync", worst_corr < 0.5, "largest |correlation| between two connections on one axis %.2f" % worst_corr)
	# Deterministic: the same personality rebuilt from the link index, the same offset every time.
	var det := true
	for v: Vortex in g.vortices:
		var v2 := Vortex.new()
		v2.link_index = v.link_index
		v2._length = v._length
		v2._setup_current(v.points[0], v.points[v.points.size() - 1])
		for k in 3:
			det = det and v2.cur_amp[k] == v.cur_amp[k] and v2.cur_omega[k] == v.cur_omega[k] and v2.cur_phi[k] == v.cur_phi[k] and v2.cur_kap[k] == v.cur_kap[k]
		det = det and v2.cur_basis == v.cur_basis
		for tm in [0.0, 13.7, 999.1, 7201.3]:
			det = det and v2.current_offset_at(0.37, tm) == v.current_offset_at(0.37, tm)
		v2.free()
	# The shaders get this frame's phases from the same clock.
	await t.frames(2)
	var v0: Vortex = g.vortices[0]
	var ph := Vector3.ZERO
	for ax in 3:
		ph[ax] = fposmod(v0.cur_omega[0][ax] * v0.current_time + v0.cur_phi[0][ax], TAU)
	var shader_sync := (v0._jet_mat.get_shader_parameter("cur_ph0") as Vector3).is_equal_approx(ph) and (v0._debris_mats[1].get_shader_parameter("cur_ph0") as Vector3).is_equal_approx(ph)
	t.check("vortex_current_deterministic", det and shader_sync and v0.current_time > 0.0, "rebuilt identical %s, shader phases match the clock %s" % [det, shader_sync])
	# Long-time non-repetition: the first minute of mid-span motion never comes back within 30 minutes.
	var worst_rep := INF
	for v: Vortex in g.vortices:
		var sr: Array[Vector3] = []
		for i in 1800:
			sr.append(v.current_offset_at(0.5, i * 1.0))
		var rms := 0.0
		for i in 60:
			rms += sr[i].length_squared()
		rms = sqrt(rms / 60.0)
		for lag in range(40, 1740):
			var e := 0.0
			for i in range(0, 60, 2):
				e += (sr[i + lag] - sr[i]).length_squared()
			worst_rep = minf(worst_rep, sqrt(e / 30.0) / maxf(rms, 0.01))
	t.check("vortex_current_no_repeat_30_min", worst_rep > 0.2, "closest return of the first minute: %.0f%% of its rms" % (worst_rep * 100.0))


## Vortex currents (ledger row 14): travel is preserved. Every connection, both ways, with the current
## on: same destination, the same frame count as the straight tunnel (currents off), the same landing,
## and Gill inside the moving current (within the jets' helix round the visible centreline), carried
## away from the logical path by it.
func _test_vortex_currents_travel() -> void:
	p.invuln_t = 9999
	for v: Vortex in g.vortices:
		v.connected = true
		v.strength = 1.0
	var rows: Array[String] = []
	var all_ok := true
	var worst_inside := 0.0
	var max_carry := 0.0
	var worst_frames := 0
	for li in g.vortices.size():
		var v: Vortex = g.vortices[li]
		var land := {}
		var frames_ := {}
		for mode in ["off", "on", "on_rev"]:
			Vortex.currents = (mode as String) != "off"
			var rev: bool = mode == "on_rev"
			var start: MossBall = v.ball_b if rev else v.ball_a
			var dest: MossBall = v.ball_a if rev else v.ball_b
			place_at(start.index, start.surface_point(Vector3.UP, 0.2), Vector3.FORWARD)
			await t.frames(2)
			# (A different moment of the meander on each connection: well displaced mid-span.)
			v.current_time = 137.0 + li * 53.0
			var n0: int = g.stats["travels"].size()
			g._start_cinematic("travel", {"v": v, "reverse": rev})
			var n := 0
			for i in 60 * 9:
				await t.frames(1)
				n += 1
				if g.cinematic != "travel":
					break
				var k := clampf(g.cine_t / 6.0, 0.0, 1.0)
				var e := k * k * (3.0 - 2.0 * k)
				var tt := 1.0 - e if rev else e
				var vis := v.visual_point(tt)
				var inside := p.global_position.distance_to(vis) / v.helix_radius(tt, Vortex.TUBE_RADIUS)
				if Vortex.currents:
					worst_inside = maxf(worst_inside, inside)
					max_carry = maxf(max_carry, (vis - (v.sample(tt)[0] as Vector3)).length())
			frames_[mode] = n
			# (Then the assisted landing sets him down on the arrival point.)
			for i in 60 * 3:
				if g.cinematic == "":
					break
				await t.frames(1)
			land[mode] = p.global_position
			var ok: bool = p.ball == dest and g.cinematic == "" and g.stats["travels"].size() == n0 + 1 and g.stats["travels"][n0] == [v.ball_a.index, rev]
			all_ok = all_ok and ok
			if not ok:
				rows.append("%d-%d %s: on ball %d cine '%s'" % [v.ball_a.index + 1, v.ball_b.index + 1, mode, p.ball.index + 1, g.cinematic])
			await t.frames(10)
		var df := absi(int(frames_["on"]) - int(frames_["off"]))
		worst_frames = maxi(worst_frames, df)
		var dl: float = (land["on"] as Vector3).distance_to(land["off"])
		all_ok = all_ok and df <= 2 and dl < 0.6
		rows.append("%d-%d frames %d/%d (rev %d) landing %.2f m apart" % [v.ball_a.index + 1, v.ball_b.index + 1, frames_["off"], frames_["on"], frames_["on_rev"], dl])
	Vortex.currents = true
	t.check("vortex_current_travel_preserved", all_ok and worst_frames <= 2, "; ".join(rows))
	t.check("vortex_current_gill_rides_inside", worst_inside < 1.0 and max_carry > 1.5, "worst distance from the visible centreline %.0f%% of the jets' radius; current carried him up to %.1f m off the logical path" % [worst_inside * 100.0, max_carry])


func _test_vortex() -> void:
	var b0 := g.balls[0]
	var v: Vortex = b0.vortex_out
	place(0, 20, 60, 0.1, 90)
	await t.frames(5)
	t.check("vortex_closed_below_70", not v.connected, "restoration %.2f" % b0.restoration)
	var step := 1.0 / b0.events_total
	await _complete_until(b0, 0.7 - step)
	await t.seconds(1.0)
	t.check("vortex_still_closed_below_70", not v.connected and b0.restoration < 0.7, "restoration %.2f" % b0.restoration)
	await _complete_until(b0, 0.7)
	var saw_cine := false
	for i in 60 * 16:
		await t.frames(1)
		if g.cinematic == "connect":
			saw_cine = true
		# (Every way out of this ball opens together: the chain and its branch, one shot each.)
		if saw_cine and g.cinematic == "" and g._pending_connect.is_empty():
			break
	var all_open := true
	for vv in b0.vortices:
		if vv.ball_a == b0:
			all_open = all_open and vv.connected
	t.check("vortex_connects_at_70_with_cinematic", v.connected and all_open and saw_cine and g.cinematic == "" and p.controls_enabled, "restoration %.2f; open %s all %s shot %s cine '%s' pending %d controls %s" % [b0.restoration, v.connected, all_open, saw_cine, g.cinematic, g._pending_connect.size(), p.controls_enabled])
	# Enter the vortex: travel to moss ball #2.
	var mouth := v.mouth_pos(false)
	place_at(0, b0.surface_point(b0.up_at(mouth), 0.1), MossBall.frame_at(b0.up_at(mouth), 0).z)
	var surfed := false
	for i in 60 * 9:
		await t.frames(1)
		if g.cinematic == "travel" and p.model.surf > 0.5:
			surfed = true
		if surfed and g.cinematic == "":
			break
	t.check("vortex_travel_to_ball2", p.ball == g.balls[1] and surfed, "ball %d" % p.ball.index)
	# And back again (bidirectional).
	await t.seconds(0.5)
	var b1 := g.balls[1]
	var mb := v.mouth_pos(true)
	var away := b1.up_at(mb).rotated(MossBall.frame_at(b1.up_at(mb), 0).x, deg_to_rad(15.0))
	place_at(1, b1.surface_point(away, 0.1), Vector3.FORWARD)
	await t.seconds(0.3)
	place_at(1, b1.surface_point(b1.up_at(mb), 0.1), MossBall.frame_at(b1.up_at(mb), 0).z)
	for i in 60 * 9:
		await t.frames(1)
		if g.cinematic == "" and p.ball == g.balls[0]:
			break
	t.check("vortex_bidirectional", p.ball == g.balls[0], "ball %d" % p.ball.index)


func _test_current() -> void:
	var b := g.balls[1]
	place(1, 0, 150, 0.1, 90)
	await wait_grounded()
	p.invuln_t = 999
	var flow := b.current_at(p.global_position + p.up * 0.5).normalized()
	var dists := []
	for sgn in [1.0, -1.0]:
		place(1, 0, 150, 0.1, 90)
		await wait_grounded()
		await t.frames(2)
		var start := p.global_position
		for i in 60:
			stick_toward(flow * sgn)
			await t.frames(1)
		dists.append(p.global_position.distance_to(start))
	p.bot_input = Vector2.ZERO
	t.check("current_affects_traversal", dists[0] > dists[1] * 1.25, "with %.2f against %.2f" % [dists[0], dists[1]])
	# Jump distance with vs against the current.
	var jd := []
	for sgn in [1.0, -1.0]:
		place(1, 0, 150, 0.1, 90)
		await wait_grounded()
		var start := p.global_position
		stick_toward(flow * sgn)
		await t.frames(20)
		var s2 := p.global_position
		await press("jump")
		for i in 90:
			stick_toward(flow * sgn)
			await t.frames(1)
			if p.grounded and i > 5:
				break
		jd.append(p.global_position.distance_to(s2))
	p.bot_input = Vector2.ZERO
	t.check("current_affects_jumps", jd[0] > jd[1] * 1.2, "with %.2f against %.2f" % [jd[0], jd[1]])
	# Knockback of a large parasite is carried by the current.
	var large := first_alive(1, Parasite.Kind.LARGE)
	await t.frames(5)
	var lp := large.global_position
	var lflow := b.current_at(lp).normalized()
	await _swipe_at(large, true)
	await t.seconds(1.8)
	var moved := large.global_position - lp
	t.check("current_carries_knocked_parasite", moved.dot(lflow) > 0.6, "downstream %.2f state %s" % [moved.dot(lflow), large.state])
	p.invuln_t = 0.0


## Pushed by a current along the ground (ledger row 19): he braces against it, scaled by how hard
## he is pushed, and his feet leave small pooled drag marks that fade; none swimming, in a column or
## in the air; movement is identical with the gesture on and off; no gameplay random numbers drawn.
func _test_current_brace() -> void:
	var b := g.balls[1]
	var release := _hold_threats(b)
	var m := p.model
	var fx := WaterFX.inst
	p.invuln_t = 999
	# The brace weight follows the push: sampled across the current's band (strong at its equator,
	# fading toward the poles), standing still on open ground.
	var rows := []
	var worst := 0.0
	var lo := 1.0
	var hi := 0.0
	var mono := true
	for k in 11:
		mono = mono and Axolotl.brace_for_push(0.12 * (k + 1)) >= Axolotl.brace_for_push(0.12 * k)
	for lat in [0.0, 12.0, 24.0, 32.0, 38.0, 44.0, 52.0, 70.0]:
		place(1, lat, 150, 0.1, 90)
		if not await wait_grounded():
			continue
		await t.seconds(1.0)
		if not p.grounded:
			continue
		var push := p.current_push.length()
		var want := Axolotl.brace_for_push(push)
		worst = maxf(worst, absf(p.current_brace - want))
		lo = minf(lo, p.current_brace)
		hi = maxf(hi, p.current_brace)
		rows.append("lat %d push %.2f brace %.2f drawn %.2f" % [lat, push, p.current_brace, m._brace_w])
	t.check("brace_follows_push_strength", rows.size() >= 6 and worst < 0.05 and lo < 0.15 and hi > 0.45 and mono,
			"worst off %.3f, range %.2f..%.2f, curve monotonic %s; %s" % [worst, lo, hi, mono, "; ".join(rows)])
	# Not pushed: on a ball without a current he never braces.
	place(0, -10, -40, 0.1, 0)
	await wait_grounded()
	var still_max := 0.0
	for i in 60:
		await t.frames(1)
		still_max = maxf(still_max, p.current_brace + m._brace_w)
	# In the air: a jump in the strongest push; zero every airborne frame.
	place(1, 0, 150, 0.1, 90)
	await wait_grounded()
	await t.seconds(1.0)
	var before_jump := p.current_brace
	await press("jump")
	var air_max := 0.0
	var air_frames := 0
	for i in 90:
		await t.frames(1)
		if not p.grounded:
			air_frames += 1
			air_max = maxf(air_max, p.current_brace + m._brace_w)
		elif i > 5:
			break
	# In a column and swimming: the controller's and the model's gates (the state set directly).
	p.set_physics_process(false)
	p.grounded = true
	p.current_push = p.facing * 1.5
	p._in_column = true
	p._update_current_brace(0.5)
	var col_w := p.current_brace
	p._in_column = false
	m.swim = 1.0
	p._update_current_brace(0.5)
	var swim_w := p.current_brace
	m.current_brace = 1.0
	m.grounded = true
	var swim_drawn := m.brace_weight()
	m.swim = 0.0
	var ground_drawn := m.brace_weight()
	m.grounded = false
	var air_drawn := m.brace_weight()
	m.grounded = true
	p.set_physics_process(true)
	t.check("brace_zero_unpushed_air_column_swimming", still_max == 0.0 and air_frames > 10 and air_max == 0.0 and col_w == 0.0 and swim_w == 0.0
			and swim_drawn == 0.0 and air_drawn == 0.0 and ground_drawn > 0.9 and before_jump > 0.3,
			"unpushed %.2f; air %.2f over %d frames (braced %.2f before the jump); column %.2f; swimming %.2f (drawn %.2f); air drawn %.2f; ground drawn %.2f"
			% [still_max, air_max, air_frames, before_jump, col_w, swim_w, swim_drawn, air_drawn, ground_drawn])
	# Movement and velocity identical with the gesture on and off: standing in the push, then
	# walking across it, then still again.
	var traces := []
	var on_max_w := 0.0
	var on_marks := 0
	var lifted := [false, false, false, false]
	var rig_low := 0.0
	var live_max := 0
	# (A first pass warms the spot up: the first walk after arriving differs by a few hundredths of
	# a millimetre from every later one, gesture or not. Then on, off, and on again.)
	for pass_ in 4:
		var on := pass_ != 2
		Axolotl.brace_enabled = on
		place(1, 0, 150, 0.1, 90)
		await wait_grounded()
		await t.frames(10)
		var m0 := m.drag_marks
		var tr := []
		for i in 240:
			p.bot_input = Vector2(0.7, 0.2) if i >= 90 and i < 150 else Vector2.ZERO
			await t.frames(1)
			tr.append([p.global_position, p.velocity, p.grounded])
			if on:
				on_max_w = maxf(on_max_w, p.current_brace)
				rig_low = minf(rig_low, m.rig.position.y)
				live_max = maxi(live_max, fx.marks_live)
				for k in 4:
					lifted[k] = lifted[k] or m._brace_lift(k) > 0.5
		p.bot_input = Vector2.ZERO
		if on:
			on_marks = m.drag_marks - m0
		traces.append(tr)
	Axolotl.brace_enabled = true
	var dpos := 0.0
	var dvel := 0.0
	var dgr := 0
	for pair in [[1, 2], [2, 3]]:
		var ta: Array = traces[pair[0]]
		var tb: Array = traces[pair[1]]
		for i in ta.size():
			dpos = maxf(dpos, (ta[i][0] as Vector3).distance_to(tb[i][0]))
			dvel = maxf(dvel, (ta[i][1] as Vector3).distance_to(tb[i][1]))
			dgr += 0 if ta[i][2] == tb[i][2] else 1
	var moved := (traces[1][0][0] as Vector3).distance_to(traces[1][traces[1].size() - 1][0])
	t.check("brace_movement_identical_on_off", dpos == 0.0 and dvel == 0.0 and dgr == 0 and moved > 1.0,
			"on vs off and off vs on: max position difference %.7f m, velocity %.7f m/s, grounded mismatches %d over %d frames each (moved %.1f m)" % [dpos, dvel, dgr, traces[1].size(), moved])
	t.check("brace_gesture_drawn", on_max_w > 0.4 and rig_low < -0.02 and not lifted.has(false) and on_marks >= 4,
			"brace up to %.2f, body down %.3f m, every foot re-planted %s, %d marks scraped" % [on_max_w, -rig_low, str(lifted), on_marks])
	# The pool stays bounded, and each mark fades out and frees its slot.
	var dt := 1.0 / 60.0
	var up := p.up
	for i in WaterFX.MARK_POOL * 3:
		fx.drag_mark(p.global_position, up, p.facing, 0.2, 0.075, 1.0)
	var full := fx.marks_live
	var h := fx.drag_mark(p.global_position, up, p.facing, 0.2, 0.075, 1.0)
	var slot := h % WaterFX.MARK_POOL
	var alphas := []
	var stale_ok := true
	for i in int((WaterFX.MARK_LIFE + 0.5) / dt):
		fx._update_marks(dt)
		if i % 30 == 29:
			alphas.append(snappedf(fx.mark_alpha(slot), 0.01))
	stale_ok = not fx.drag_mark_stretch(h, p.global_position, p.global_position + p.facing * 0.1, 0.05)
	var fades: bool = alphas[1] > 0.9 and alphas[alphas.size() - 1] == 0.0
	for i in range(2, alphas.size()):
		fades = fades and alphas[i] <= alphas[i - 1]
	t.check("drag_marks_pooled_and_fade", full == WaterFX.MARK_POOL and live_max <= WaterFX.MARK_POOL and live_max > 0 and fades and fx.marks_live == 0 and stale_ok and not fx._mark_mi.visible,
			"%d spawned -> %d live (pool %d); in play up to %d live; one mark's alpha each 0.5 s: %s; all gone after %.1f s %s (layer hidden %s); stale handle refused %s"
			% [WaterFX.MARK_POOL * 3 + 1, full, WaterFX.MARK_POOL, live_max, str(alphas), WaterFX.MARK_LIFE, fx.marks_live == 0, not fx._mark_mi.visible, stale_ok])
	# No gameplay random numbers: a detached model bracing and scraping marks for ten seconds.
	var m2 := AxolotlModel.new()
	m2.set_process(false)
	add_child_safe(m2)
	m2.global_transform = m.global_transform
	m2.current_brace = 1.0
	m2.current_push = p.facing.cross(p.up) * 1.3
	m2.grounded = true
	m2.idle_ok = true
	seed(4711)
	var r1 := randi()
	seed(4711)
	for i in 600:
		m2._process(dt)
		fx._update_marks(dt)
	var r2 := randi()
	var m2_marks := m2.drag_marks
	m2.queue_free()
	for i in int(WaterFX.MARK_LIFE / dt) + 2:
		fx._update_marks(dt)
	t.check("brace_draws_no_gameplay_random", r1 == r2 and m2_marks > 10, "sequence %s; %d marks scraped meanwhile" % ["untouched" if r1 == r2 else "MOVED", m2_marks])
	t.log_line("brace samples: %s" % "; ".join(rows))
	release.call()
	p.invuln_t = 0.0


func _test_canopy() -> void:
	var b := g.balls[2]
	var lb: LevelBuilder = b.get_meta("builder")
	var hint: Dictionary = {}
	for h in lb.bot_hints:
		if h.has("canopy"):
			hint = h
	var c2: Transform3D = hint["c2"]
	var tip := Levels.leaf_mid(c2, 4.6, 0.0)
	var large: Parasite = null
	for par in b.parasites:
		if par.zone_id == "drop" and par.kind == Parasite.Kind.LARGE:
			large = par
	# Let moss ball #3 wake up.
	place_at(2, Levels.leaf_mid(c2, 2.0, 0.0).origin + b.up_at(c2.origin) * 0.3, -c2.basis.z)
	g.audio.set_ball(2, false)
	await wait_grounded()
	await t.seconds(0.5)
	var hp0 := large.hp
	t.log_line("drop large: state %s dist-from-tip-ground %.2f" % [large.state, large.global_position.distance_to(b.surface_point(b.up_at(tip.origin)))])
	p.health = 3
	p.max_health = 3
	p.model.set_health(3, 3, false)
	var kinds := []
	var cl := func(k): kinds.append(k)
	p.landed.connect(cl)
	var braced := false
	# Walk off the canopy tip and fall all the way down.
	p.invuln_t = 999
	var left := false
	for i in 60 * 5:
		if not left:
			stick_toward(-c2.basis.z)
			if not p.grounded and i > 5:
				left = true
				p.bot_input = Vector2.ZERO
		await t.frames(1)
		if p.fall_danger:
			braced = true
		if "extreme" in kinds or "hard" in kinds or "leaf" in kinds:
			break
	t.log_line("canopy walk-off landings: %s height %.1f" % [str(kinds), height()])
	p.bot_input = Vector2.ZERO
	await t.frames(3)
	t.check("dangerous_fall_telegraph", braced, "")
	t.check("extreme_canopy_landing", "extreme" in kinds, str(kinds))
	t.check("extreme_landing_costs_one_health", p.health == 2, "health %d" % p.health)
	t.log_line("landing->large distance %.2f" % large.closest_body_point(p.global_position).distance_to(p.global_position))
	t.check("extreme_landing_two_stages", large.hp == maxi(0, hp0 - 2), "hp %d -> %d" % [hp0, large.hp])
	# At one health, fall damage never removes the final segment.
	p.health = 1
	p.model.set_health(1, 3, false)
	kinds.clear()
	place_at(2, Levels.leaf_mid(c2, 2.0, 0.0).origin + b.up_at(c2.origin) * 0.3, -c2.basis.z)
	await wait_grounded()
	for i in 60 * 5:
		if p.grounded:
			stick_toward(-c2.basis.z)
		else:
			p.bot_input = Vector2.ZERO
		await t.frames(1)
		if kinds.size() > 0 and kinds[kinds.size() - 1] != "soft":
			break
	p.bot_input = Vector2.ZERO
	t.check("fall_never_removes_final_segment", "extreme" in kinds and p.health == 1 and p.state == "normal", "health %d kinds %s" % [p.health, str(kinds)])
	# Flexible leaf cushions a long fall and rebounds modestly.
	var f1: Platforms.FlexLeaf = hint["f1"]
	var c3: Transform3D = hint["c3"]
	p.health = 3
	kinds.clear()
	# Dropped over F1's outer half, out beyond the spiral leaves' reach (the column above it is
	# open water: checked, so this really lands on the flexible leaf).
	var on_leaf := Levels.leaf_mid(f1.global_transform, 1.2, 0.0).origin
	var above := on_leaf + b.up_at(f1.global_position) * 8.5
	var blocker := g.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(above, on_leaf + b.up_at(f1.global_position) * 0.4, 1 | 2))
	t.check("flex_leaf_drop_column_open", blocker.is_empty(), "")
	place_at(2, above, -c3.basis.z)
	var rebound_v := 0.0
	var landed_leaf := false
	for i in 60 * 4:
		await t.frames(1)
		if "leaf" in kinds:
			landed_leaf = true
		if landed_leaf:
			rebound_v = maxf(rebound_v, p.velocity.dot(p.up))
	p.landed.disconnect(cl)
	t.check("flex_leaf_cushions_fall", landed_leaf and p.health == 3 and not ("extreme" in kinds.slice(0, 1)), str(kinds))
	t.check("flex_leaf_modest_rebound", rebound_v > 3.0 and rebound_v < 12.5, "rebound %.1f" % rebound_v)
	p.invuln_t = 0.0


## Owner playtest: a child could not start the Moss Ball #3 canopy climb. The spiral must be
## climbable with plain jumps (no water burst): from the ground onto the first leaf, then leaf to
## leaf; and no leaf may have a platform hanging low over it.
func _test_canopy_plain_jumps() -> void:
	var b := g.balls[2]
	var lb: LevelBuilder = b.get_meta("builder")
	var h: Dictionary = {}
	for x in lb.bot_hints:
		if x.has("canopy"):
			h = x
	var spiral: Array = h["spiral"]
	var space := g.get_world_3d().direct_space_state
	var prev := 0.0
	var worst_step := 0.0
	var low_head := INF
	var low_where := ""
	for xf in spiral:
		var top := b.altitude(Levels.leaf_mid(xf, 1.5, 0.0).origin)
		worst_step = maxf(worst_step, top - prev)
		prev = top
		for along in [0.4, 1.0, 1.6, 2.2, 2.8]:
			for side in [-0.6, 0.0, 0.6]:
				var m := Levels.leaf_mid(xf, along, side)
				var up := b.up_at(m.origin)
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(m.origin + up * 0.2, m.origin + up * 3.0, 1 | 2))
				if not hit.is_empty() and xf != spiral[spiral.size() - 1]:
					if (hit.position - m.origin).dot(up) < low_head:
						low_where = "leaf %d along %.1f side %.1f under %s at h %.2f" % [spiral.find(xf), along, side, str(hit["collider"]), b.altitude(hit.position)]
					low_head = minf(low_head, (hit.position - m.origin).dot(up))
	t.check("canopy_steps_within_a_plain_jump", worst_step <= 1.1 and b.altitude(Levels.leaf_mid(spiral[0], 1.5, 0.0).origin) <= 1.0, "first leaf %.2f m, largest step %.2f m (jump apex 1.85 m)" % [b.altitude(Levels.leaf_mid(spiral[0], 1.5, 0.0).origin), worst_step])
	t.check("canopy_spiral_headroom", low_head >= 1.5, "lowest headroom above a spiral leaf %.2f m (%s)" % [low_head, low_where])
	# Physically: from the ground beside the first leaf, plain jumps only, all the way up.
	p.invuln_t = 999
	var ground := b.surface_point(b.up_at(Levels.leaf_mid(spiral[0], 4.4, 0.0).origin), 0.1)
	place_at(2, ground, (Levels.leaf_mid(spiral[0], 1.5, 0.0).origin - ground).normalized())
	await wait_grounded()
	var reached := 0
	for k in spiral.size():
		var target := Levels.leaf_mid(spiral[k], 1.6, 0.0).origin
		for i in 10:
			stick_toward(target - p.global_position)
			await t.frames(1)
		await press("jump")
		for i in 90:
			var off := target - p.global_position
			off -= p.up * off.dot(p.up)
			if off.length() > 0.3:
				stick_toward(off)
			else:
				p.bot_input = Vector2.ZERO
			await t.frames(1)
			if p.grounded and i > 12:
				break
		p.bot_input = Vector2.ZERO
		await wait_grounded()
		var on := absf(b.altitude(p.global_position) - b.altitude(target)) < 0.35 and p.global_position.distance_to(target) < 1.8
		if not on:
			t.log_line("plain-jump climb stopped at leaf %d: at h %.2f, leaf top h %.2f" % [k, b.altitude(p.global_position), b.altitude(target)])
			break
		reached += 1
	p.invuln_t = 0.0
	t.check("canopy_climb_with_plain_jumps", reached == spiral.size(), "reached leaf %d of %d with plain jumps" % [reached, spiral.size()])


## Physically, from the ground at each climb's start to its top, with plain jumps: the towers and
## the new areas' climbs. Every jump is a normal touch jump. (The mesa's swaying platforms in the
## current take timing and the water burst; the playthrough bot climbs them on both seeds.)
func _test_climbs_physical() -> void:
	var picks := []
	for b in g.balls:
		for h in (b.get_meta("builder") as LevelBuilder).bot_hints:
			if h.has("route") and h["route"] in ["spire", "terraces", "shelves", "high shelf", "tower", "canopy"]:
				picks.append([b, h])
	var results := []
	var all_ok := true
	p.invuln_t = 999
	for e in picks:
		var h: Dictionary = e[1]
		var tops: Array = h["tops"]
		var reached: int = await _climb(e[0], h)
		all_ok = all_ok and reached == tops.size()
		results.append("b%d %s %d/%d" % [e[0].index + 1, h["route"], reached, tops.size()])
	p.invuln_t = 0.0
	t.check("climbs_with_plain_jumps", all_ok and picks.size() >= 7, ", ".join(results))


## Every jungle-stem ladder on Giant Stems (the owner's phone report), climbed from the ground to
## its top leaf with plain jumps.
func _test_jungle_ladders_physical() -> void:
	var b := g.balls[2]
	var n := 0
	var bad: Array[String] = []
	var leaves := 0
	p.invuln_t = 999
	for h in (b.get_meta("builder") as LevelBuilder).bot_hints:
		# (Every jungle stem, and the Great Trunk up to the High Crown.)
		if not (h.has("route") and (str(h["route"]).begins_with("jungle") or str(h["route"]) == "great trunk")):
			continue
		n += 1
		var tops: Array = h["tops"]
		leaves += tops.size()
		var reached: int = await _climb(b, h)
		if reached < tops.size():
			bad.append("%s %d/%d" % [h["route"], reached, tops.size()])
	p.invuln_t = 0.0
	t.check("jungle_ladders_climbed_with_plain_jumps", n >= 71 and bad.is_empty(), "%d stems, %d leaves; short: %s" % [n, leaves, str(bad)])


## Expansion 6 (timer integrity): dying and respawning, and travelling by vortex, never reset or
## rewind the run timer; an unfinished run never records a best finish.
func _test_timer_integrity() -> void:
	var clock: RunClock = g.clock
	var best0: float = g.run_save.records()["best_finish_s"]
	place_at(0, g.balls[0].surface_point(MossBall.dir_ll(10, 30), 0.2), Vector3.FORWARD)
	await t.seconds(1.0)
	var before := clock.play_s
	p.invuln_t = 0.0
	for i in 12:
		p.invuln_t = 0.0
		p.take_damage(1, p.global_position + Vector3(0.5, 0, 0))
		await t.frames(2)
	await t.seconds(4.0)
	var after_death := clock.play_s
	t.check("timer_keeps_running_through_death", after_death > before + 2.0 and clock.state == "running" and g.stats["deaths"] >= 1,
			"%.2f -> %.2f s, deaths %d, state %s" % [before, after_death, g.stats["deaths"], clock.state])
	var v: Vortex = g.balls[0].vortex_out
	v.connected = true
	var t0 := clock.play_s
	g._start_cinematic("travel", {"v": v, "reverse": false})
	var mono := true
	var last := t0
	for i in 60 * 8:
		await t.frames(1)
		mono = mono and clock.play_s >= last
		last = clock.play_s
		if g.cinematic == "" and i > 30:
			break
	t.check("timer_continues_through_vortex_travel", mono and clock.play_s > t0 + 1.0 and clock.state == "running", "%.2f -> %.2f s on ball %d" % [t0, clock.play_s, p.ball.index + 1])
	t.check("unfinished_run_sets_no_best", g.run_save.records()["best_finish_s"] == best0 and clock.state != "finished", "best %.2f (was %.2f)" % [g.run_save.records()["best_finish_s"], best0])
	p.invuln_t = 0.0


## Expansion 6 (resume positions): every bloom is where a run resumes and where the axolotl comes
## back after losing: there he lands on solid footing, stays put (no sliding off), is not inside
## anything, and nothing hurts him in his first seconds there.
func _test_resume_points_safe() -> void:
	var bad: Array[String] = []
	var n := 0
	for b in g.balls:
		for bl in b.blooms:
			if not bl.is_placed():
				continue
			n += 1
			var rp: Vector3 = bl.respawn_point()
			# The game's own respawn: lost near this bloom, re-formed at it (Game._cine_regen).
			place_at(b.index, b.surface_point(b.up_at(rp), 0.2), Vector3.FORWARD)
			g.audio.set_ball(b.index, false)
			g.checkpoint = bl
			p.state = "dead"
			g._on_player_died()
			for i in 60 * 6:
				await t.frames(1)
				if g.cinematic == "":
					break
			p.bot_input = Vector2.ZERO
			var hp := p.health
			await t.seconds(0.6)
			var settled := p.global_position
			var grounded := p.grounded
			await t.seconds(1.4)
			var slid := p.global_position.distance_to(settled)
			# (Current Hollows' current drifts him a little by design.)
			var allow := 1.2 if b.index == 1 else 0.3
			if p.global_position.distance_to(rp) > 5.0:
				t.log_line("far: b%d bloom %s -> now ball %d at %s, state %s, cinematic '%s', vortex conn %s" % [b.index + 1, str(rp), p.ball.index + 1, str(p.global_position), p.state, g.cinematic, str(g.balls[b.index].vortex_out.connected if g.balls[b.index].vortex_out else "-")])
			if p.health < hp:
				var near := []
				for par in b.parasites:
					if par.global_position.distance_to(p.last_hit_from) < 3.0:
						near.append("parasite %s %s %.1f m" % [par.zone_id, par.state, par.global_position.distance_to(p.last_hit_from)])
				for c in b.critters:
					if c.global_position.distance_to(p.last_hit_from) < 4.0:
						near.append("%s %.1f m" % [c.species, c.global_position.distance_to(p.last_hit_from)])
				t.log_line("hit at b%d bloom %s from %s (%.1f m away): %s" % [b.index + 1, str(rp.snapped(Vector3.ONE * 0.1)), str(p.last_hit_from.snapped(Vector3.ONE * 0.1)), p.last_hit_from.distance_to(rp), str(near)])
			if not grounded or slid > allow or p.health < hp or p.global_position.distance_to(rp) > allow + 0.9:
				bad.append("b%d bloom at %s: grounded %s, slid %.2f m, hurt %s, %.2f m from its point" % [b.index + 1, str(rp.snapped(Vector3.ONE * 0.1)), grounded, slid, p.health < hp, p.global_position.distance_to(rp)])
	for x in bad:
		t.log_line(x)
	t.check("resume_points_safe", bad.is_empty() and n >= 20, "%d blooms; %s" % [n, str(bad.slice(0, 4))])


## Expansion 6 addendum (parasite combat, docs/ECOSYSTEM.md "Parasites"): each size fights its own
## way, hurt ones may flee inside their territory and recover a little, neighbours are alerted
## locally and spread round him, a spitter lobs slow globs, and all of it stays fair: telegraphed,
## never through rock, within an attack budget, deterministic. Played out on the open ground of one
## of the new balls with the parasites involved moved there; everything is restored afterwards.
func _test_parasite_combat() -> void:
	# The first of the new balls with two small, a medium and a large parasite, and a cave.
	var b := g.balls[3]
	for bi in range(3, g.balls.size()):
		var kinds := {}
		for par in g.balls[bi].parasites:
			kinds[par.kind] = int(kinds.get(par.kind, 0)) + 1
		if int(kinds.get(Parasite.Kind.SMALL, 0)) >= 2 and kinds.has(Parasite.Kind.MEDIUM) and kinds.has(Parasite.Kind.LARGE) and not g.balls[bi].upgrades.is_empty():
			b = g.balls[bi]
			break
	var lb: LevelBuilder = b.get_meta("builder")
	g.ecosystem.set_physics_process(false)
	var saved := {}
	for par in b.parasites:
		saved[par] = [_par_snapshot(par), par.hp, par.home_dir, par.home_radius, par._brave, par.variant, par._gray_target, par.attack_reach, par.windup_time]
		par.set_physics_process(false)
	# Open ground: beside the vortex arrival (kept clear of platforms by design).
	var centre := b.arrival_dir.rotated(MossBall.frame_at(b.arrival_dir, 0).x, deg_to_rad(9.0)).normalized()
	var fr := MossBall.frame_at(centre, 0.0)
	var at := func(east: float, north: float) -> Vector3:
		return b.surface_point((b.surface_point(centre) + fr.x * east - fr.z * north - b.global_position).normalized())
	var put := func(par: Parasite, pos: Vector3, home_deg := 14.0) -> void:
		var d := b.up_at(pos)
		par.home_dir = d
		par.home_radius = deg_to_rad(home_deg)
		par.global_position = b.surface_point(d, par._ground_offset)
		par.up = d
		par._trail.clear()
		par._trail_up.clear()
		for i in 12:
			par._trail.push_back(par.global_position)
			par._trail_up.push_back(d)
		par._set_state("graze")
		par._graze_target = par.global_position
		par._graze_t = 5.0
		par._alerted_t = 0.0
		par._wary_t = 0.0
		par._shaken = 0.0
		par.hit_cd = 0.0
		par._want_retreat = false
		par._regen_ok = false
		par._circled = false
		par._flank = 0.0
		par._los_check = 0.0
		par._update_segments(0.0)
		par.set_physics_process(true)
	var park := func() -> void:
		# (Back where each was before the test, well away from him: a parked parasite left beside
		# him was killed by a later swipe, and restoring it afterwards double-counted its kill.)
		for par in b.parasites:
			par.set_physics_process(false)
			if par.is_alive():
				_par_restore(par, saved[par][0])
				par._set_state("graze")
		for gl in ParasiteGlob.live.duplicate():
			gl.queue_free()
		ParasiteGlob.live.clear()
	var pick := func(kind: int) -> Parasite:
		for par in b.parasites:
			if par.is_alive() and par.kind == kind:
				return par
		return null
	var smalls: Array = []
	for par in b.parasites:
		if par.is_alive() and par.kind == Parasite.Kind.SMALL:
			smalls.append(par)
	var med: Parasite = pick.call(Parasite.Kind.MEDIUM)
	var large: Parasite = pick.call(Parasite.Kind.LARGE)
	if smalls.size() < 2 or med == null or large == null:
		t.check("parasite_combat_subjects", false, "%d small, medium %s, large %s on ball %d" % [smalls.size(), str(med), str(large), b.index + 1])
		return
	var small: Parasite = smalls[0]
	var hero := func(pos: Vector3, face: Vector3) -> void:
		place_at(b.index, b.surface_point(b.up_at(pos), 0.1), face)
		g.audio.set_ball(b.index, false)
		p.restore_full()
	await controls_ready()

	# --- Small: rushes in with darting bursts and commits quickly; latches on a hit. ---
	hero.call(at.call(0.0, 0.0), fr.z * -1.0)
	p.invuln_t = 999
	put.call(small, at.call(0.0, 5.5))
	var speeds: Array[float] = []
	var last := small.global_position
	var tw := -1.0
	for i in 150:
		await t.frames(1)
		speeds.append(small.global_position.distance_to(last) * 60.0)
		last = small.global_position
		if small.state == "windup" and tw < 0.0:
			tw = i / 60.0
			break
	var fast := 0.0
	var slow := INF
	for v in speeds.slice(5):
		fast = maxf(fast, v)
		slow = minf(slow, v)
	t.check("small_parasite_darts_in", fast > small.speed * 1.4 and slow < small.speed * 0.6 and tw > 0.0 and tw < 2.5,
			"burst %.1f m/s, pause %.1f m/s, committed after %.2f s" % [fast, slow, tw])
	p.invuln_t = 0.0
	var latched := false
	for i in 90:
		await t.frames(1)
		latched = latched or small._latched > 0.0
	t.check("small_parasite_latches_on_a_hit", latched and small.windup_time <= 0.5, "windup %.2f s" % small.windup_time)
	park.call()

	# --- Medium: circles for a better angle before it commits. ---
	hero.call(at.call(0.0, 0.0), fr.z * -1.0)
	p.invuln_t = 999
	put.call(med, at.call(0.0, 5.0))
	var circled := false
	var bearing0 := INF
	var swept := 0.0
	var committed := false
	for i in 60 * 6:
		await t.frames(1)
		var off: Vector3 = med.global_position - p.global_position
		off -= p.up * off.dot(p.up)
		var bearing := atan2(off.dot(fr.x), off.dot(-fr.z))
		if med._mode == "circle":
			circled = true
			if bearing0 == INF:
				bearing0 = bearing
			swept = maxf(swept, absf(wrapf(bearing - bearing0, -PI, PI)))
		if med.state == "windup":
			committed = true
			break
	t.check("medium_parasite_circles_then_commits", circled and swept > deg_to_rad(30.0) and committed,
			"circled %s, swept %.0f deg round him, then committed %s" % [circled, rad_to_deg(swept), committed])
	park.call()

	# --- Large: a coiled wind-up, then a heavy committed charge with a long recovery; a sidestep
	# during the wind-up avoids it, standing still does not. ---
	for dodge in [false, true]:
		hero.call(at.call(0.0, 0.0), fr.z * -1.0)
		p.invuln_t = 0.0
		var hp0 := p.health
		put.call(large, at.call(0.0, 4.5))
		var wstart := -1.0
		var coil := 1.0
		var run_from := Vector3.ZERO
		var ran := 0.0
		var rec_t := 0.0
		var el := 0.0
		while el < 8.0:
			await t.frames(1)
			el += 1.0 / 60.0
			if large.state == "windup":
				if wstart < 0.0:
					wstart = el
					if dodge:
						# Seen it coil: step well aside.
						hero.call(p.global_position + fr.x * 2.8, fr.z * -1.0)
				coil = minf(coil, large._stretch_v)
			elif large.state == "attack":
				if run_from == Vector3.ZERO:
					run_from = large.global_position
				ran = maxf(ran, large.global_position.distance_to(run_from))
			elif large.state == "recover" and run_from != Vector3.ZERO:
				rec_t += 1.0 / 60.0
			elif run_from != Vector3.ZERO:
				break
		var hurt := p.health < hp0
		if not dodge:
			t.check("large_parasite_heavy_charge", large.windup_time >= 1.0 and coil < 0.85 and ran > 2.5 and rec_t > 1.2 and hurt,
					"wind-up %.1f s (coiled to %.2f), charged %.1f m, recovered %.1f s, hurt %s" % [large.windup_time, coil, ran, rec_t, hurt])
		else:
			t.check("large_charge_dodged_by_sidestep", wstart >= 0.0 and not hurt, "")
		park.call()

	# --- Retreat: a timid medium, hurt to half, breaks off; never leaves its territory; left
	# alone it recovers one stage, once. A brave one stands its ground. ---
	hero.call(at.call(0.0, 0.0), fr.z * -1.0)
	p.invuln_t = 999
	med._brave = false
	put.call(med, at.call(0.0, 2.0), 9.0)
	med.hit(1, p.global_position)
	var fled := false
	var worst_out := 0.0
	var far_from_him := 0.0
	for i in 60 * 5:
		await t.frames(1)
		fled = fled or med.state == "retreat"
		if med.state == "retreat":
			worst_out = maxf(worst_out, med._angle_from_home(med.global_position) / med.home_radius)
		far_from_him = maxf(far_from_him, med.global_position.distance_to(p.global_position))
	t.check("hurt_parasite_retreats", fled and med.hp == 1 and far_from_him > 4.0, "fled %s, got %.1f m away" % [fled, far_from_him])
	t.check("retreat_stays_in_territory", worst_out < 1.08, "furthest %.2f of its home radius" % worst_out)
	# He walks off: it recovers one stage after a while, and only one.
	hero.call(at.call(0.0, -14.0), fr.z)
	await t.seconds(11.5)
	var healed := med.hp
	await t.seconds(12.0)
	t.check("escaped_parasite_recovers_once", healed == 2 and med.hp == 2, "hp %d after 11.5 s, %d after 23.5 s (max %d)" % [healed, med.hp, med.max_hp])
	# Killed while fleeing, it goes to the twitch and the limp drift. (A temporary twin in the same
	# zone: its own registration balances its kill, so the world's parasites stay as they were.)
	park.call()
	hero.call(at.call(0.0, 0.0), fr.z * -1.0)
	var twin_f := Parasite.new()
	twin_f.setup(b, Parasite.Kind.MEDIUM, med.zone_id, b.up_at(at.call(0.0, 1.6)), 9.0)
	b.add_child(twin_f)
	await t.frames(2)
	put.call(twin_f, at.call(0.0, 1.6), 9.0)
	twin_f.hp = 1
	twin_f._set_state("retreat")
	await t.frames(20)
	twin_f.hit(1, p.global_position)
	var died := twin_f.state == "dying"
	var drifted := false
	for i in 90:
		await t.frames(1)
		drifted = drifted or twin_f.state == "drifting"
	t.check("fleeing_parasite_dies_limp", died and drifted, "dying %s, then drifting %s" % [died, drifted])
	twin_f.queue_free()
	var brave := smalls[1] as Parasite
	t.check("small_parasites_never_flee", brave._brave, "")
	park.call()

	# --- Pack alert: one that sees him alerts grazing neighbours within ALERT_R (not beyond), and
	# they spread round him instead of queueing. ---
	hero.call(at.call(0.0, 0.0), fr.z * -1.0)
	p.invuln_t = 999
	var a: Parasite = smalls[0]
	var near_q: Parasite = smalls[1]
	var far_q: Parasite = large
	put.call(a, at.call(0.0, 5.0))
	put.call(near_q, at.call(-4.0, 9.5), 30.0)
	put.call(far_q, at.call(9.0, 13.0), 30.0)
	a.set_physics_process(false)
	near_q.set_physics_process(false)
	far_q.set_physics_process(false)
	var dn: float = near_q.global_position.distance_to(a.global_position)
	var df: float = far_q.global_position.distance_to(a.global_position)
	a.set_physics_process(true)
	near_q.set_physics_process(true)
	far_q.set_physics_process(true)
	await t.frames(3)
	t.check("pack_alert_reaches_neighbours", a.state == "chase" and near_q._alerted_t > 0.0 and near_q.state == "chase", "neighbour %.1f m away: %s" % [dn, near_q.state])
	t.check("pack_alert_is_local", far_q._alerted_t == 0.0 and df > Parasite.ALERT_R, "one %.1f m away: %s" % [df, far_q.state])
	park.call()
	# A group engaging: spread round him, never more than MAX_COMMITTED committed at once, attack
	# starts spaced out.
	hero.call(at.call(0.0, 0.0), fr.z * -1.0)
	p.invuln_t = 999
	var group: Array = [smalls[0], smalls[1], med]
	if smalls.size() > 2:
		group.append(smalls[2])
	for k in group.size():
		var ang := TAU * k / group.size() * 0.35
		put.call(group[k], p.global_position + (-fr.z).rotated(p.up, ang) * 4.5)
	var most := 0
	var starts: Array[int] = []
	var prev_w := {}
	var min_gap := INF
	var samples := 0
	var crowd := 0
	var spread := 0.0
	for i in 60 * 6:
		await t.frames(1)
		var n := 0
		for q in group:
			if q.state in ["windup", "attack"]:
				n += 1
			if q.state == "windup" and not prev_w.get(q, false):
				starts.append(i)
			prev_w[q] = q.state == "windup"
		most = maxi(most, n)
		if i >= 60 and i % 10 == 0:
			# Those closing in, holding at reach or winding up (a lunging one is briefly on top of him).
			# (Ones right at him have just lunged through him: he stands still and cannot be hurt here.)
			var closing: Array = group.filter(func(q): return q.state in ["chase", "windup"] and q.global_position.distance_to(p.global_position) > 1.0)
			var crowded := false
			for x in closing.size():
				for y in range(x + 1, closing.size()):
					var gd: float = (closing[x] as Parasite).global_position.distance_to((closing[y] as Parasite).global_position)
					min_gap = minf(min_gap, gd)
					crowded = crowded or gd < 0.6
			samples += 1
			crowd += 1 if crowded else 0
			var bearings: Array[float] = []
			for q in group:
				var off: Vector3 = (q as Parasite).global_position - p.global_position
				bearings.append(atan2(off.dot(fr.x), off.dot(-fr.z)))
			bearings.sort()
			# How much of the circle round him they cover: all of it but the widest empty gap.
			var widest := TAU - (bearings[bearings.size() - 1] - bearings[0])
			for k in range(1, bearings.size()):
				widest = maxf(widest, bearings[k] - bearings[k - 1])
			spread = maxf(spread, TAU - widest)
	starts.sort()
	var tight := 999
	for k in range(1, starts.size()):
		tight = mini(tight, starts[k] - starts[k - 1])
	# (Darting ones may cross close for a moment; they must not bunch up.)
	t.check("group_spreads_round_him", samples > 20 and crowd <= samples / 15 and spread > deg_to_rad(50.0),
			"a pair within 0.6 m in %d of %d samples (closest %.2f m), spread %.0f deg round him" % [crowd, samples, min_gap, rad_to_deg(spread)])
	t.check("group_attack_budget", most <= Parasite.MAX_COMMITTED and starts.size() >= 2 and tight >= Parasite.COMMIT_GAP_FRAMES,
			"at most %d committed at once, %d attacks, closest starts %d frames apart" % [most, starts.size(), tight])
	park.call()

	# --- Spitter: keeps its distance, telegraphs, spits a slow glob; a sidestep dodges it; a swipe
	# bats it back; rock stops it; it never notices him through rock. ---
	var sp := med
	sp.make_spitter()
	sp.hp = sp.max_hp
	for dodge in [false, true]:
		hero.call(at.call(0.0, 0.0), fr.z * -1.0)
		g.cam.snap_behind()
		p.invuln_t = 0.0
		var hp0 := p.health
		put.call(sp, at.call(0.0, 6.0))
		var w0 := -1.0
		var launched := -1.0
		var el := 0.0
		var closest := INF
		var gl: ParasiteGlob = null
		while el < 7.0:
			await t.frames(1)
			el += 1.0 / 60.0
			closest = minf(closest, sp.global_position.distance_to(p.global_position))
			if sp.state == "windup" and w0 < 0.0:
				w0 = el
			if sp._glob != null and launched < 0.0:
				launched = el
				gl = sp._glob
				if dodge:
					hero.call(p.global_position + fr.x * 1.6, fr.z * -1.0)
			if launched > 0.0 and (gl == null or not is_instance_valid(gl) or gl._done):
				break
		var flight := el - launched
		if not dodge:
			t.check("spitter_telegraphs_and_spits", w0 >= 0.0 and launched - w0 >= 0.8 and closest > 2.4 and p.health < hp0,
					"wind-up %.2f s, kept %.1f m off, glob in flight %.2f s, hurt %s" % [launched - w0, closest, flight, p.health < hp0])
			t.check("glob_dodge_window", (launched - w0) + flight >= 1.4 and ParasiteGlob.SPEED <= 5.5, "%.2f s from the first sign to impact" % [(launched - w0) + flight])
		else:
			t.check("glob_dodged_by_sidestep", launched > 0.0 and p.health == hp0, "")
		park.call()
	# Batted back: a swipe as it arrives sends it back into the spitter.
	hero.call(at.call(0.0, 0.0), fr.z * -1.0)
	p.invuln_t = 999
	put.call(sp, at.call(0.0, 6.0))
	sp.set_physics_process(false)
	sp.hp = sp.max_hp
	var gl2 := ParasiteGlob.new()
	gl2.launch(sp, b, sp.global_position + sp.up * 0.4 + (p.global_position - sp.global_position).normalized() * 0.4, p.body_center())
	var swiped := false
	var last_pos := gl2.global_position
	var was_reflected := false
	for i in 120:
		await t.frames(1)
		if gl2 == null or not is_instance_valid(gl2) or gl2._done:
			break
		last_pos = gl2.global_position
		was_reflected = was_reflected or gl2.reflected
		# (Swung as it comes within the tail's reach: the hit frame lands a moment later, before
		# the glob reaches his body.)
		if gl2.global_position.distance_to(p.body_center()) < 2.0 and not gl2.reflected and not swiped:
			swiped = true
			await press("swipe")
	for i in 120:
		await t.frames(1)
		if is_instance_valid(gl2) and not gl2._done:
			last_pos = gl2.global_position
			was_reflected = was_reflected or gl2.reflected
	t.check("glob_batted_back_hurts_spitter", sp.hp < sp.max_hp, "spitter hp %d of %d (swiped %s, reflected %s, glob last %.1f m from the spitter, %.2f m up)" % [sp.hp, sp.max_hp,
			swiped, was_reflected, last_pos.distance_to(sp.global_position), b.altitude(last_pos)])
	# Rock stops a glob: fired straight down at the moss, it splats there and never passes through.
	var gl3 := ParasiteGlob.new()
	var gp: Vector3 = at.call(3.0, 3.0) + b.up_at(at.call(3.0, 3.0)) * 1.5
	gl3.launch(sp, b, gp, gp - b.up_at(gp) * 5.0)
	var lowest := INF
	for i in 60:
		await t.frames(1)
		if not is_instance_valid(gl3) or gl3._done:
			break
		lowest = minf(lowest, b.altitude(gl3.global_position))
	t.check("glob_stops_on_terrain", not is_instance_valid(gl3) or gl3._done, "lowest %.2f m above the ground" % lowest)
	# Never through rock: the cave nearest this ground, him deep inside it, a parasite (and the
	# spitter) outside behind its wall, within noticing range.
	var cave_h: Dictionary = {}
	for h in lb.bot_hints:
		if h.has("cave"):
			cave_h = h
	var blind := true
	if not cave_h.is_empty():
		var cen: Vector3 = cave_h["centre"]
		var back := (cen - (cave_h["door"] as Vector3)).normalized()
		var r: float = cave_h["radius"]
		hero.call(cen + back * (r - 2.2) + b.up_at(cen) * 0.3, back * -1.0)
		p.invuln_t = 999
		for q in [smalls[0], sp]:
			put.call(q, cen + back * (r + 1.8), 30.0)
		for i in 60 * 3:
			await t.frames(1)
			for q in [smalls[0], sp]:
				if (q as Parasite).state != "graze" or (q as Parasite)._glob != null:
					blind = false
		t.check("parasites_never_notice_through_rock", blind, "%.1f m apart through the wall" % smalls[0].global_position.distance_to(p.global_position))
	park.call()

	# Never from off-screen: behind the camera it holds its fire.
	hero.call(at.call(0.0, 0.0), fr.z * -1.0)
	g.cam.snap_behind()
	p.invuln_t = 999
	put.call(sp, at.call(0.0, 7.5 * -1.0))
	await t.frames(2)
	var off_screen := not sp._on_screen()
	var spat := false
	for i in 60 * 4:
		await t.frames(1)
		spat = spat or sp._glob != null or sp.state == "windup"
		if sp._on_screen():
			off_screen = false
	t.check("spitter_never_fires_from_off_screen", off_screen and not spat, "")
	park.call()
	# Blooms are not camped: one grazing right beside a bloom moves off it and stays off.
	if not b.blooms.is_empty():
		var bl: Bloom = b.blooms[0]
		hero.call(at.call(0.0, 0.0), fr.z * -1.0)
		var q0: Parasite = smalls[1]
		put.call(q0, bl.respawn_point() + MossBall.frame_at(b.up_at(bl.respawn_point()), 0).x * 0.4, 12.0)
		q0.home_dir = b.up_at(bl.respawn_point())
		var near_t := 0.0
		for i in 60 * 8:
			await t.frames(1)
			if i > 120 and q0.global_position.distance_to(bl.respawn_point()) < 1.5:
				near_t += 1.0 / 60.0
		t.check("parasites_do_not_camp_blooms", near_t < 0.5, "%.1f s within 1.5 m of the bloom after the first 2 s" % near_t)
		park.call()
	# Cost: the combat reasoning of an engaged parasite (sight, budget, spacing) per frame.
	hero.call(at.call(0.0, 0.0), fr.z * -1.0)
	for k in 3:
		put.call(group[k], p.global_position + (-fr.z).rotated(p.up, 0.8 * k) * 4.0)
		(group[k] as Parasite).set_physics_process(false)
		(group[k] as Parasite)._set_state("chase")
	var t0 := Time.get_ticks_usec()
	for k in 200:
		for q in group.slice(0, 3):
			(q as Parasite)._physics_process(1.0 / 60.0)
	var us := float(Time.get_ticks_usec() - t0) / 600.0
	t.check("parasite_combat_cheap", us < 400.0, "%.0f us per engaged parasite per frame (desktop)" % us)
	park.call()

	# --- It never climbs what its crawl cannot: sent under a jungle ladder's first leaf (and past
	# its stem), a parasite stays on the ground.
	var jb := g.balls[2]
	var lad: Dictionary = {}
	for h in (jb.get_meta("builder") as LevelBuilder).bot_hints:
		if h.has("route") and str(h["route"]).begins_with("jungle"):
			lad = h
			break
	if not lad.is_empty():
		var twin_c := Parasite.new()
		var st: Vector3 = lad["start"]
		var leaf0: Vector3 = (lad["tops"] as Array)[0]
		twin_c.setup(jb, Parasite.Kind.MEDIUM, jb.parasites[0].zone_id, jb.up_at(st), 20.0, 0.0, false)
		jb.add_child(twin_c)
		place_at(jb.index, jb.surface_point(jb.up_at(st - (leaf0 - st) * 3.0), 0.2), Vector3.FORWARD)
		await t.frames(2)
		twin_c._set_state("graze")
		var highest := 0.0
		for k in 4:
			# Crawl toward the ground under the leaf and on past the stem, from different sides.
			var aim: Vector3 = leaf0 + (leaf0 - st).rotated(jb.up_at(leaf0), k * 0.6) * (0.5 + k * 0.4)
			twin_c._graze_target = jb.surface_point(jb.up_at(aim))
			twin_c._graze_t = 99.0
			for i in 60 * 3:
				await t.frames(1)
				highest = maxf(highest, jb.altitude(twin_c.global_position) - twin_c._ground_offset)
		t.check("parasites_never_climb_stems", highest < Parasite.MAX_STEP + 0.1, "highest %.2f m off the ground (first leaf %.2f m up)" % [highest, jb.altitude(leaf0)])
		twin_c.hp = 0
		twin_c.queue_free()

	# --- No hits while a cinematic has his controls (the vortex-connection shot): a parasite right
	# by him holds off, and nothing can hurt him until he can act again.
	hero.call(at.call(0.0, 0.0), fr.z * -1.0)
	p.invuln_t = 0.0
	var hp_c := p.health
	put.call(med, at.call(0.0, 1.2))
	med.variant = ""
	g._start_cinematic("connect", {"v": b.vortices[0]})
	var committed_c := false
	for i in 60 * 3:
		await t.frames(1)
		committed_c = committed_c or med.state in ["windup", "attack"]
	p.take_damage(1, med.global_position)
	var hurt_c := p.health < hp_c
	g._end_cinematic()
	t.check("no_attacks_while_controls_taken", not committed_c and not hurt_c, "committed %s, hurt %s" % [committed_c, hurt_c])
	park.call()

	# --- Determinism: the same parasite set up twice decides the same way, and setting one up
	# never draws from the gameplay random sequence. ---
	seed(4242)
	var r1 := randf()
	seed(4242)
	var twin := Parasite.new()
	twin.setup(b, Parasite.Kind.MEDIUM, "far", med.spawn_dir, 10.0, 0.0, false)
	var r2 := randf()
	var twin2 := Parasite.new()
	twin2.setup(b, Parasite.Kind.MEDIUM, "far", med.spawn_dir, 10.0, 0.0, false)
	var same := twin._brave == twin2._brave and twin._circle_dir == twin2._circle_dir and twin._rng.randf() == twin2._rng.randf()
	t.check("parasite_decisions_deterministic", same and r1 == r2, "")
	twin.free()
	twin2.free()

	# --- Vegetation: a charging parasite pushes the plants harder than a grazing one. ---
	hero.call(at.call(0.0, 0.0), fr.z * -1.0)
	p.invuln_t = 999
	put.call(large, at.call(0.0, 4.5))
	var graze_w := 0.0
	var charge_w := 0.0
	for i in 60 * 5:
		await t.frames(1)
		if i < 30:
			continue
		for k in g.wake.count:
			var pa: Vector4 = g.wake.points_a[k]
			if Vector3(pa.x, pa.y, pa.z).distance_to(large.global_position) < 0.05:
				var w: float = g.wake.points_b[k].w
				if large.state == "attack":
					charge_w = maxf(charge_w, w)
				elif large.state == "graze" or large.state == "chase":
					graze_w = maxf(graze_w, w)
		if large.state == "recover":
			break
	t.check("charge_stirs_the_plants", charge_w > graze_w and charge_w > 0.7, "wake strength charging %.2f, crawling %.2f" % [charge_w, graze_w])
	park.call()

	# No real parasite may die in this test (its kill would count; restoring it would count twice).
	var killed := []
	for par in saved:
		if not par.is_alive() and saved[par][1] > 0:
			killed.append(str(par.get_meta("completion_id", par.zone_id)))
	t.check("combat_test_kills_no_real_parasite", killed.is_empty(), str(killed))
	# Put everything back as it was.
	for par in saved:
		var sv: Array = saved[par]
		_par_restore(par, sv[0])
		par.hp = sv[1]
		par.home_dir = sv[2]
		par.home_radius = sv[3]
		par._brave = sv[4]
		par.variant = sv[5]
		par._gray_target = sv[6]
		par.attack_reach = sv[7]
		par.windup_time = sv[8]
		par._alerted_t = 0.0
		par._want_retreat = false
		par._regen_ok = false
		par.set_physics_process(true)
	for gl in ParasiteGlob.live.duplicate():
		gl.queue_free()
	ParasiteGlob.live.clear()
	g.ecosystem.set_physics_process(true)
	p.invuln_t = 0.0


## Expansion 6: Gill reads as a soft, freckled axolotl, not shiny pink plastic, and none of it
## changed how he collides: one body sphere (the head guard separate), no collision on the gills,
## fins or decoration.
func _test_gill_look() -> void:
	var skin := 0
	var glossy: Array[String] = []
	for mi in p.model.find_children("*", "MeshInstance3D", true, false):
		var m: Material = (mi as MeshInstance3D).material_override
		if m == null and (mi as MeshInstance3D).mesh != null and (mi as MeshInstance3D).mesh.get_surface_count() > 0:
			m = (mi as MeshInstance3D).get_surface_override_material(0)
		if m is ShaderMaterial and (m as ShaderMaterial).shader == AxolotlModel.SKIN_SHADER:
			skin += 1
		elif m is StandardMaterial3D and (m as StandardMaterial3D).roughness < 0.45 and mi.get_parent() not in [p.model.eye_l, p.model.eye_r]:
			glossy.append(str(mi.name))
	t.check("gill_soft_skin_not_plastic", skin >= 8 and glossy.is_empty(), "%d skin parts; glossy non-eye parts: %s" % [skin, str(glossy)])
	var shapes := p.find_children("*", "CollisionShape3D", true, false)
	var in_model := p.model.find_children("*", "CollisionObject3D", true, false)
	t.check("gill_collision_unchanged", shapes.size() == 1 and (shapes[0] as CollisionShape3D).shape is SphereShape3D
			and is_equal_approx(((shapes[0] as CollisionShape3D).shape as SphereShape3D).radius, Axolotl.BODY_RADIUS) and in_model.is_empty(),
			"%d collision shapes on the axolotl, %d collision objects in the model" % [shapes.size(), in_model.size()])


# --- dev-000024 physical playtest polish ------------------------------------------------------

## Holds every threat on the ball still (restored by the returned callable).
func _hold_threats(b: MossBall) -> Callable:
	g.ecosystem.set_physics_process(false)
	var held: Array = []
	for pp in b.parasites:
		if pp.is_physics_processing():
			pp.set_physics_process(false)
			held.append(pp)
	return func() -> void:
		for pp in held:
			if is_instance_valid(pp):
				pp.set_physics_process(true)
		g.ecosystem.set_physics_process(true)


## Idles: now and then, standing still, one of four little animations; cosmetic only.
func _test_gill_idles() -> void:
	var b := g.balls[0]
	var release := _hold_threats(b)
	var m := p.model
	var open_ := MossBall.dir_ll(-10, -40)
	place_at(0, b.surface_point(open_, 0.2), -MossBall.frame_at(open_, 0.0).x)
	p.invuln_t = 0.0
	# The first idle comes after a random wait inside IDLE_FIRST, once he is standing still.
	var still_at := -1.0
	var began_at := -1.0
	var clock := 0.0
	for i in 60 * 12:
		await t.frames(1)
		clock += 1.0 / 60.0
		if still_at < 0.0 and m._still_s > 0.0:
			still_at = clock
		if m.idle_kind != AxolotlModel.Idle.NONE:
			began_at = clock
			break
	var wait := began_at - still_at
	t.check("idle_starts_after_standing_still", began_at > 0.0 and wait >= AxolotlModel.IDLE_FIRST.x - 0.05 and wait <= AxolotlModel.IDLE_FIRST.y + 0.1,
			"still from %.2f s, first idle at %.2f s (wait %.2f s)" % [still_at, began_at, wait])
	# Input ends an idle at once, and he moves off as quickly as from a plain stand.
	var from := p.global_position
	p.bot_input = Vector2(0, 0.8)
	await t.frames(2)
	var cancelled := m.idle_kind == AxolotlModel.Idle.NONE
	await t.seconds(0.5)
	var moved_idle := from.distance_to(p.global_position)
	p.bot_input = Vector2.ZERO
	place_at(0, b.surface_point(open_, 0.2), -MossBall.frame_at(open_, 0.0).x)
	await t.seconds(0.6)
	from = p.global_position
	p.bot_input = Vector2(0, 0.8)
	await t.seconds(0.5)
	var moved_plain := from.distance_to(p.global_position)
	p.bot_input = Vector2.ZERO
	t.check("idle_cancels_on_input_without_delay", cancelled and moved_idle > moved_plain * 0.97,
			"cancelled within 2 frames %s; moved %.3f m out of an idle, %.3f m from a plain stand" % [cancelled, moved_idle, moved_plain])
	# Every idle leaves the gameplay body, its collision and facing exactly where they were, and
	# the drawn model settles back to rest.
	place_at(0, b.surface_point(open_, 0.2), -MossBall.frame_at(open_, 0.0).x)
	await t.seconds(0.6)
	var shape := p.find_children("*", "CollisionShape3D", true, false)[0] as CollisionShape3D
	var worst := 0.0
	var worst_rig := 0.0
	var worst_rest := 0.0
	var model_xf := m.transform
	for k in AxolotlModel.IDLE_LEN.size():
		var pos0 := p.global_position
		var face0 := p.facing
		var shape0 := shape.global_transform
		m.start_idle(k)
		var ran := 0
		while m.idle_kind == k and ran < 60 * 6:
			await t.frames(1)
			ran += 1
			worst = maxf(worst, maxf(p.global_position.distance_to(pos0), shape.global_transform.origin.distance_to(shape0.origin)) + face0.angle_to(p.facing))
			worst_rig = maxf(worst_rig, m.rig.position.length())
		await t.seconds(0.5)
		worst_rest = maxf(worst_rest, m.rig.position.length() + m.rig.rotation.length() * 0.2)
	t.check("idles_never_move_gameplay_body", worst < 0.0001 and m.transform.is_equal_approx(model_xf),
			"worst body/collision/facing change %.6f; the model node itself unmoved %s" % [worst, m.transform.is_equal_approx(model_xf)])
	t.check("idles_animate_and_return_to_rest", worst_rig > 0.1 and worst_rest < 0.015, "largest drawn offset %.3f m; after: %.4f" % [worst_rig, worst_rest])
	# Anything else going on suppresses idles (the controller's side).
	var blocked := []
	var cases := {
		"airborne": func(on: bool) -> void: p.grounded = not on,
		"swipe": func(on: bool) -> void: p.swipe_t = 0.2 if on else -1.0,
		"lunge (feeding)": func(on: bool) -> void: p.lunge_t = 0.2 if on else -1.0,
		"hurt": func(on: bool) -> void: p.hurt_lock = 0.3 if on else 0.0,
		"landing": func(on: bool) -> void: p.land_lock = 0.3 if on else 0.0,
		"controls taken": func(on: bool) -> void: p.controls_enabled = not on,
		"cinematic (vortex, death, respawn)": func(on: bool) -> void: g.cinematic = "travel" if on else "",
		"not in play": func(on: bool) -> void: p.state = "dead" if on else "normal",
		"moving": func(on: bool) -> void: p.move_input = Vector2(0, 0.5) if on else Vector2.ZERO,
		"current pull": func(on: bool) -> void: p.ext_vel = p.facing * 2.0 if on else Vector3.ZERO,
		"current push (brace)": func(on: bool) -> void: p.current_brace = 0.5 if on else 0.0,
		"falling danger": func(on: bool) -> void: p.fall_danger = on,
	}
	p.set_physics_process(false)
	p.grounded = true
	p.velocity = Vector3.ZERO
	var base_ok := p.idle_allowed()
	for key in cases:
		(cases[key] as Callable).call(true)
		if not p.idle_allowed():
			blocked.append(key)
		(cases[key] as Callable).call(false)
	p.set_physics_process(true)
	# (And the model's side: a forced idle stops at once for anything the model itself plays.)
	var mblocked := []
	var mcases := ["hurt_t", "land_t", "burst_t", "happy_t", "perk_t", "lunge_t", "swipe_t", "surf", "brace", "dissolve", "current_brace"]
	var m2 := AxolotlModel.new()
	m2.set_process(false)
	m2.visible = false
	add_child_safe(m2)
	for key in mcases:
		m2.idle_ok = true
		m2.grounded = true
		m2.start_idle(0)
		m2.set(key, 0.5 if key in ["surf", "brace", "dissolve", "current_brace"] else 0.1)
		m2._update_idle(1.0 / 60.0)
		if m2.idle_kind == AxolotlModel.Idle.NONE:
			mblocked.append(key)
		m2.set(key, 0.0 if key in ["surf", "brace", "dissolve", "current_brace"] else -1.0)
	t.check("incompatible_states_suppress_idles", base_ok and blocked.size() == cases.size() and mblocked.size() == mcases.size(),
			"allowed when idle %s; blocked by %s; model stops for %s" % [base_ok, str(blocked), str(mblocked)])
	# Twenty minutes of standing still: all four idles, never the same one twice running, no fixed
	# order, the waits spread over IDLE_GAP; and none of it touches gameplay's random sequence.
	seed(55)
	var r1 := randi()
	seed(55)
	var seq: Array[int] = []
	var starts: Array[float] = []
	var ends: Array[float] = []
	var prev := AxolotlModel.Idle.NONE
	m2.idle_ok = true
	var dt := 1.0 / 30.0
	for i in 30 * 60 * 20:
		m2._process(dt)
		if m2.idle_kind != prev:
			if m2.idle_kind != AxolotlModel.Idle.NONE:
				seq.append(m2.idle_kind)
				starts.append(i * dt)
			else:
				ends.append(i * dt)
			prev = m2.idle_kind
	var r2 := randi()
	var repeats := 0
	for i in range(1, seq.size()):
		repeats += 1 if seq[i] == seq[i - 1] else 0
	var kinds := {}
	for k in seq:
		kinds[k] = true
	var grams := {}
	for i in range(0, seq.size() - 3):
		grams[str(seq.slice(i, i + 4))] = true
	var gap_lo := INF
	var gap_hi := 0.0
	for i in range(1, starts.size()):
		var gap := starts[i] - ends[i - 1]
		gap_lo = minf(gap_lo, gap)
		gap_hi = maxf(gap_hi, gap)
	t.check("idles_varied_not_repeated", kinds.size() == AxolotlModel.IDLE_RANDOM and repeats == 0 and grams.size() > 4 and seq.size() >= 40 and seq.size() <= 150
			and gap_lo >= AxolotlModel.IDLE_GAP.x - 0.05 and gap_hi <= AxolotlModel.IDLE_GAP.y + 0.05,
			"%d idles in 20 min, kinds %s, %d back-to-back repeats, %d different runs of four, gaps %.1f..%.1f s" % [seq.size(), str(kinds.keys()), repeats, grams.size(), gap_lo, gap_hi])
	t.check("idles_leave_gameplay_rng_alone", r1 == r2, "")
	m2.queue_free()
	release.call()


## His colours (owner request): morph swatches and fine-tuning in the pause menu, applied live to
## him and the preview, saved per device in settings (the save schema is unchanged); and the
## stretch idle's little yawn.
func _test_gill_colours() -> void:
	var m := p.model
	var pink: Dictionary = GillLook.MORPHS[0]
	var default_ok: bool = Settings.gill_morph == "pink" and m.look_base().is_equal_approx(pink["base"]) \
			and pink["base"] == Color(0.98, 0.58, 0.66) and pink["freckle"] == Color(0.72, 0.34, 0.44)
	var bases := {}
	for mo in GillLook.MORPHS:
		bases[str(mo["base"])] = true
	t.check("gill_colour_default_is_original_pink", default_ok and bases.size() == GillLook.MORPHS.size(),
			"%s, base %s; %d distinct morphs" % [Settings.gill_morph, str(m.look_base()), bases.size()])
	# The pause menu's page: a swatch recolours him and the preview at once and is saved.
	var pm := g.pause_menu
	pm.open()
	await t.frames(2)
	pm._open_gill()
	await t.frames(2)
	var page := pm.gill_page
	var page_open := page.visible and not pm._panel.visible
	(page.find_child("Morph_golden", true, false) as Button).pressed.emit()
	await t.frames(1)
	var golden := GillLook.morph("golden")
	var live := m.look_base().is_equal_approx(golden["base"]) and page.preview.look_base().is_equal_approx(golden["base"])
	# Fine-tuning: the body's hue shifts, the freckles' shade changes.
	page._body_hue.value = 0.25
	page._dots_bright.value = 0.6
	await t.frames(1)
	var tuned := m.look_base()
	var hue_moved := absf(angle_difference(tuned.h * TAU, (golden["base"] as Color).h * TAU)) > 1.2
	var fr: Color = m._skin_mats[0].get_shader_parameter("freckle_color")
	var dots_darker := fr.v < (golden["freckle"] as Color).v * 0.7
	var cf := ConfigFile.new()
	cf.load("user://settings.cfg")
	var saved := str(cf.get_value("gill", "morph", "")) == "golden" and absf(float(cf.get_value("gill", "body_hue", 0.0)) - 0.25) < 0.001 \
			and int(cf.get_value("meta", "save_schema", -1)) == SaveSchema.SAVE_SCHEMA and SaveSchema.SAVE_SCHEMA == 1
	# Read back as on the next launch.
	Settings.gill_morph = "pink"
	Settings.gill_body_hue = 0.0
	Settings._load()
	var reloaded := Settings.gill_morph == "golden" and absf(Settings.gill_body_hue - 0.25) < 0.001 and absf(Settings.gill_dots_bright - 0.6) < 0.001
	t.check("gill_colour_picker_live_and_saved", page_open and live and hue_moved and dots_darker and saved and reloaded,
			"page %s; live on him and in the preview %s; hue moved %s, freckles darker %s; saved in settings (schema 1) %s; read back %s"
			% [page_open, live, hue_moved, dots_darker, saved, reloaded])
	# Reset and Done; the preview stops drawing once the page is closed.
	(page.find_child("Reset", true, false) as Button).pressed.emit()
	var reset_ok := is_zero_approx(Settings.gill_body_hue) and is_equal_approx(Settings.gill_dots_bright, 1.0) and Settings.gill_morph == "golden"
	(page.find_child("Morph_pink", true, false) as Button).pressed.emit()
	(page.find_child("Done", true, false) as Button).pressed.emit()
	await t.frames(1)
	var closed := not page.visible and pm._panel.visible and page._vp.render_target_update_mode == SubViewport.UPDATE_DISABLED
	pm.close()
	await t.frames(1)
	t.check("gill_colour_reset_and_back", reset_ok and closed and m.look_base().is_equal_approx(pink["base"]) and not g.get_tree().paused,
			"reset %s, closed %s, pink again %s" % [reset_ok, closed, m.look_base().is_equal_approx(pink["base"])])
	# The stretch's yawn: once per stretch, a real sound.
	var b := g.balls[0]
	var release := _hold_threats(b)
	var open_ := MossBall.dir_ll(-10, -40)
	place_at(0, b.surface_point(open_, 0.2), -MossBall.frame_at(open_, 0.0).x)
	p.invuln_t = 0.0
	await t.seconds(1.2)
	var y0 := m.yawns
	m.start_idle(AxolotlModel.Idle.STRETCH)
	await t.seconds(AxolotlModel.IDLE_LEN[AxolotlModel.Idle.STRETCH] + 0.2)
	var y1 := m.yawns
	m.start_idle(AxolotlModel.Idle.TILT)
	await t.seconds(AxolotlModel.IDLE_LEN[AxolotlModel.Idle.TILT] + 0.2)
	t.check("stretch_yawns_once", y1 - y0 == 1 and m.yawns == y1 and Sfx.inst.stream("gill_yawn") != null,
			"%d yawn(s) in a stretch, %d in a head tilt; sound loaded %s" % [y1 - y0, m.yawns - y1, Sfx.inst.stream("gill_yawn") != null])
	release.call()


## His patterns (owner request): built-in patterns tile seamlessly, replace his freckles, show as
## markings or in full colour at a chosen size; a picture from the phone becomes his pattern; the
## page opens straight from the title screen. All in settings, save schema unchanged.
func _test_gill_patterns() -> void:
	var m := p.model
	# Built-ins: drawn, tileable (the first and last columns and rows meet).
	# (Tiled, the last column meets the first: that step must be no sharper than the pattern's own
	# sharpest step between neighbouring pixels anywhere inside it.)
	var drawn := 0
	var seam_excess := 0.0
	for pat in GillLook.PATTERNS:
		if pat[0] == "none":
			continue
		var img := GillLook.draw_pattern(pat[0])
		var n := img.get_width()
		var cover := 0.0
		var seam := 0.0
		var inner := 0.0
		for i in n:
			if i % 2 == 0:
				for j in range(0, n, 8):
					cover += img.get_pixel(i, j).a
			seam = maxf(seam, maxf(absf(img.get_pixel(0, i).a - img.get_pixel(n - 1, i).a), absf(img.get_pixel(i, 0).a - img.get_pixel(i, n - 1).a)))
			for k in range(1, n - 1, 3):
				inner = maxf(inner, maxf(absf(img.get_pixel(k, i).a - img.get_pixel(k + 1, i).a), absf(img.get_pixel(i, k).a - img.get_pixel(i, k + 1).a)))
		seam_excess = maxf(seam_excess, seam - inner)
		drawn += 1 if cover > 20.0 else 0
	t.check("gill_patterns_drawn_and_tileable", drawn == GillLook.PATTERNS.size() - 1 and seam_excess <= 0.05,
			"%d built-in patterns drawn; seam steps at most %.2f sharper than inside" % [drawn, seam_excess])
	# Choosing one: on his skin in place of the freckles; mode and repeats follow the page.
	var pm := g.pause_menu
	pm.open()
	await t.frames(2)
	pm._open_gill()
	await t.frames(1)
	var page := pm.gill_page
	(page.find_child("Pattern_hearts", true, false) as Button).pressed.emit()
	await t.frames(1)
	var sm: ShaderMaterial = m._skin_mats[0]
	var on_ok: bool = float(sm.get_shader_parameter("pattern_on")) == 1.0 and sm.get_shader_parameter("pattern_tex") != null and int(sm.get_shader_parameter("pattern_mode")) == 0
	page._full_colour.button_pressed = true
	page._pattern_size.value = 6
	await t.frames(1)
	var tuned_ok: bool = int(sm.get_shader_parameter("pattern_mode")) == 1 and is_equal_approx(float(sm.get_shader_parameter("pattern_scale")), 6.0) \
			and Settings.gill_pattern == "hearts" and Settings.gill_pattern_mode == 1 and Settings.gill_pattern_size == 6
	var src := (load("res://shaders/axolotl_skin.gdshader") as Shader).code
	var replaces := src.find("* (1.0 - pattern_on)") > 0
	t.check("gill_pattern_on_skin_replacing_freckles", on_ok and tuned_ok and replaces and page.preview._skin_mats[0].get_shader_parameter("pattern_tex") != null,
			"on %s; full colour and 6 repeats %s; freckles give way %s" % [on_ok, tuned_ok, replaces])
	# A picture from the phone: any size, cropped square, shrunk, stored, and read back next launch.
	var pic := Image.create(480, 300, false, Image.FORMAT_RGB8)
	for y in 300:
		for x in 480:
			pic.set_pixel(x, y, Color(0.1, 0.2, 0.6) if (x / 40 + y / 40) % 2 == 0 else Color(0.95, 0.9, 0.8))
	var pic_path := OS.get_user_data_dir().path_join("test_pick.jpg")
	pic.save_jpg(pic_path)
	page.import_picture(pic_path)
	await t.frames(1)
	var stored := Image.load_from_file(GillLook.UPLOAD_PATH)
	var up_ok := Settings.gill_pattern == GillLook.UPLOAD and stored != null and stored.get_width() == GillLook.PATTERN_PX and stored.get_height() == GillLook.PATTERN_PX \
			and not Settings.gill_pattern_alpha and (page.find_child("Pattern_upload", true, false) as Button).visible and sm.get_shader_parameter("pattern_tex") != null
	page.import_picture(OS.get_user_data_dir().path_join("no_such_picture.png"))
	var bad_ok := (page.find_child("PatternNote", true, false) as Label).text != "" and Settings.gill_pattern == GillLook.UPLOAD
	Settings.gill_pattern = "none"
	Settings._load()
	var cf := ConfigFile.new()
	cf.load("user://settings.cfg")
	var reload_ok := Settings.gill_pattern == GillLook.UPLOAD and int(cf.get_value("meta", "save_schema", -1)) == 1
	t.check("gill_picture_upload_becomes_pattern", up_ok and bad_ok and reload_ok,
			"uploaded, %dx%d, on him %s; a bad file refused politely %s; kept for next launch (schema 1) %s" % [stored.get_width() if stored else 0, stored.get_height() if stored else 0, up_ok, bad_ok, reload_ok])
	# Freckles again, and back to the menu.
	(page.find_child("Pattern_none", true, false) as Button).pressed.emit()
	page._full_colour.button_pressed = false
	page._pattern_size.value = 3
	await t.frames(1)
	var cleared: bool = float(sm.get_shader_parameter("pattern_on")) == 0.0 and Settings.gill_pattern == "none"
	(page.find_child("Done", true, false) as Button).pressed.emit()
	pm.close()
	await t.frames(1)
	# From the title screen: straight to the page with its preview, and Done goes back to the title.
	var ts: TitleScreen = g.title
	var direct_ok := false
	var back_ok := false
	if ts != null:
		ts._on_colours()
		await t.frames(2)
		direct_ok = pm.visible and page.visible and not pm._panel.visible and page._vp.render_target_update_mode == SubViewport.UPDATE_ALWAYS
		(page.find_child("Done", true, false) as Button).pressed.emit()
		await t.frames(1)
		back_ok = not pm.visible and not page.visible
	t.check("gill_colours_from_title_screen", cleared and ts != null and direct_ok and back_ok,
			"pattern cleared %s; title screen found %s; opens straight to the page %s; Done returns %s" % [cleared, ts != null, direct_ok, back_ok])
	DirAccess.remove_absolute(pic_path)


## dev-000025 phone test: the menus' scrollbar must be easy to grab with a thumb. Its touch area
## is at least 3x the 8 px the default theme gave it (UiStyle.SCROLL_TOUCH_W), inside the panel,
## covering no button, toggle or slider; grabbing it on its undrawn part and dragging scrolls.
## The ambient fish (docs/AQUARIUM.md): about ten, four kinds; never targets, never completion; the
## gameplay random sequence is the same with or without them; they stay in the water (inside the
## glass, above the gravel, out of every moss ball); Gill close makes them dart off, a school
## scatters and regroups.
func _test_ambient_fish() -> void:
	var af: AmbientFish = g.fish
	var kinds := {}
	for f in af.fish:
		kinds[f["kind"]] = int(kinds.get(f["kind"], 0)) + 1
	t.check("fish_thirteen_of_five_kinds", af.fish.size() == AmbientFish.COUNT and AmbientFish.COUNT == 13 and kinds.size() == 5 and kinds.get("bala", 0) == 3, str(kinds))
	var targeted := 0
	for b in g.balls:
		var saved := p.ball
		p.ball = b
		for x in g._strikeable(p):
			if x.get_parent() == af or x == af:
				targeted += 1
		p.ball = saved
	var in_catalog := g.completion.order.filter(func(id): return id.contains("fish") or id.contains("tetra") or id.contains("gourami")).size()
	t.check("fish_never_targets_or_completion", targeted == 0 and in_catalog == 0 and not af.fish.any(func(f): return f["node"] is Critter), "targetable %d, catalog ids %d" % [targeted, in_catalog])
	# Determinism: stepping the fish never touches the global generator.
	var st := af.fish.map(func(f): return [f["pos"], f["vel"], f["goal"]])
	seed(4242)
	var r0 := [randi(), randi()]
	seed(4242)
	for i in 600:
		af.step(1.0 / 60.0, Vector3.INF)
	var r1 := [randi(), randi()]
	t.check("fish_leave_gameplay_rng_alone", r0 == r1, "")
	# Two minutes of swimming: always inside the tank, never inside a moss ball.
	var worst_out := 0.0
	var worst_in := -INF
	var paused := 0
	for i in 60 * 120:
		af.step(1.0 / 60.0, Vector3.INF)
		if i % 30 == 0:
			for f in af.fish:
				var pos: Vector3 = f["pos"]
				worst_out = maxf(worst_out, (pos - pos.clamp(af.tank_min, af.tank_max)).length())
				for o in af.obstacles:
					worst_in = maxf(worst_in, (o[1] as float) - 9.0 - pos.distance_to(o[0]))
				if (f["vel"] as Vector3).length() < 1.0:
					paused += 1
	t.check("fish_stay_in_the_water", worst_out < 0.01 and worst_in < 0.0 and paused > 0, "outside the tank by %.2f, inside a ball by %.2f, paused samples %d" % [worst_out, worst_in, paused])
	# A bump: Gill right beside a tetra sends it (and its school) darting off; later they regroup.
	# (A fresh school with the shipped seed, so the bump and regroup do not depend on how long the
	# live fish have swum in earlier suite tests: the result is the same in any test order.)
	var live_af := af
	af = AmbientFish.new()
	g.add_child(af)
	af.setup(live_af._tank[0], live_af._tank[1], live_af._balls)
	for i in 60 * 180:
		af.step(1.0 / 60.0, Vector3.INF)
	# (The tetra with the most schoolmates nearby: by this point in the full suite the school may have
	# strung out, and a lone first tetra alarms only itself.)
	var all_tets: Array = af.fish.filter(func(f): return f["kind"] == "tetra")
	var tet: Dictionary = all_tets[0]
	var best_n := -1
	for a in all_tets:
		var n := all_tets.filter(func(b): return b != a and (b["pos"] as Vector3).distance_to(a["pos"]) < 6.0).size()
		if n > best_n:
			best_n = n
			tet = a
	# (How spread the school is before the bump: "regrouped" means back to that, or within 30 m.)
	var c0 := Vector3.ZERO
	for f in all_tets:
		c0 += f["pos"]
	c0 /= all_tets.size()
	var spread0 := 0.0
	for f in all_tets:
		spread0 = maxf(spread0, c0.distance_to(f["pos"]))
	var gill: Vector3 = (tet["pos"] as Vector3) + Vector3(0.5, 0, 0)
	var d0: float = gill.distance_to(tet["pos"])
	for i in 45:
		af.step(1.0 / 60.0, gill)
	var d1: float = gill.distance_to(tet["pos"])
	var alarmed := af.fish.filter(func(f): return f["kind"] == "tetra" and f["alarm"] > 0.2).size()
	for i in 60 * 25:
		af.step(1.0 / 60.0, Vector3.INF)
	var calm := af.fish.all(func(f): return f["alarm"] <= 0.0)
	var tets := af.fish.filter(func(f): return f["kind"] == "tetra")
	var c := Vector3.ZERO
	for f in tets:
		c += f["pos"]
	c /= tets.size()
	var spread := 0.0
	for f in tets:
		spread = maxf(spread, c.distance_to(f["pos"]))
	t.check("fish_scatter_then_regroup", d1 > d0 + 3.0 and alarmed >= 2 and calm and spread < maxf(30.0, spread0 * 1.15),
			"darted %.1f -> %.1f m; %d tetras alarmed; calm again %s; school within %.1f m (before the bump %.1f m)" % [d0, d1, alarmed, calm, spread, spread0])
	af.queue_free()
	af = live_af
	# The bala sharks (owner): the largest fish, a skittish trio that bolts together and regroups.
	var balas := af.fish.filter(func(f): return f["kind"] == "bala")
	var bl: Dictionary = balas[0]
	var bgill: Vector3 = (bl["pos"] as Vector3) + Vector3(0.8, 0, 0)
	var bd0: float = bgill.distance_to(bl["pos"])
	for i in 45:
		af.step(1.0 / 60.0, bgill)
	var bd1: float = bgill.distance_to(bl["pos"])
	var b_alarmed := balas.filter(func(f): return f["alarm"] > 0.2).size()
	for i in 60 * 25:
		af.step(1.0 / 60.0, Vector3.INF)
	var bc := Vector3.ZERO
	for f in balas:
		bc += f["pos"]
	bc /= balas.size()
	var b_spread := 0.0
	for f in balas:
		b_spread = maxf(b_spread, bc.distance_to(f["pos"]))
	var largest: bool = AmbientFish.KINDS.keys().all(func(k): return AmbientFish.KINDS[k]["len"] <= AmbientFish.KINDS["bala"]["len"])
	t.check("bala_trio_bolts_and_regroups", largest and bd1 > bd0 + 4.0 and b_alarmed >= 2 and b_spread < 45.0,
			"largest %s; darted %.1f -> %.1f; %d alarmed; trio within %.1f" % [largest, bd0, bd1, b_alarmed, b_spread])
	for i in st.size():
		af.fish[i]["pos"] = st[i][0]
		af.fish[i]["vel"] = st[i][1]
		af.fish[i]["goal"] = st[i][2]


# --- Tier 2 (docs/TIER2.md) ---------------------------------------------------------------

## The rules on their own: angles (wraparound), Water Cannon's pick, Bubble Blast's volume, Gill
## Rush's chain, and the loadout model (unlock order, one equipped, shared cooldown, save).
func _test_tier2_rules() -> void:
	var up := Vector3.UP
	var fwd := Vector3.FORWARD
	var o := Vector3.ZERO
	var at := func(deg: float, dist: float) -> Vector3: return o + fwd.rotated(up, deg_to_rad(deg)) * dist
	var offs := [Tier2Combat.facing_offset(fwd, up, o, at.call(10.0, 5.0)), Tier2Combat.facing_offset(fwd, up, o, at.call(-10.0, 5.0)),
			Tier2Combat.facing_offset(fwd, up, o, at.call(350.0, 5.0)), Tier2Combat.facing_offset(fwd, up, o, at.call(90.0, 5.0)),
			Tier2Combat.facing_offset(fwd, up, o, at.call(-90.0, 5.0)), Tier2Combat.facing_offset(fwd, up, o, at.call(270.0, 5.0)),
			Tier2Combat.facing_offset(fwd, up, o, at.call(360.0, 5.0))]
	var degs: Array = offs.map(func(x): return snappedf(rad_to_deg(x), 0.01))
	t.check("tier2_shortest_angle_wraps", degs == [10.0, 10.0, 10.0, 90.0, 90.0, 90.0, 0.0], str(degs))
	var cand := func(deg: float, dist: float, id: int, seen := true) -> Dictionary: return {"node": null, "pos": at.call(deg, dist), "seen": seen, "id": id}
	var a: Dictionary = Tier2Combat.pick_cannon(fwd, up, o, [cand.call(-90.0, 3.0, 1), cand.call(10.0, 6.0, 2)])
	var b: Dictionary = Tier2Combat.pick_cannon(fwd, up, o, [cand.call(90.0, 3.0, 1), cand.call(350.0, 6.0, 2)])
	var tie_near: Dictionary = Tier2Combat.pick_cannon(fwd, up, o, [cand.call(10.0, 6.0, 1), cand.call(-10.0, 4.0, 2)])
	var tie_same: Dictionary = Tier2Combat.pick_cannon(fwd, up, o, [cand.call(-10.0, 5.0, 9), cand.call(10.0, 5.0, 3)])
	t.check("cannon_prefers_what_he_faces", a.get("id") == 2 and b.get("id") == 2 and tie_near.get("id") == 2 and tie_same.get("id") == 3,
			"+10 over -90: %s; 350 over +90: %s; tie, nearer: %s; exact tie, lower id: %s" % [a.get("id"), b.get("id"), tie_near.get("id"), tie_same.get("id")])
	var none: Array = [Tier2Combat.pick_cannon(fwd, up, o, [cand.call(0.0, Tier2Combat.CANNON_RANGE + 0.5, 1)]),
			Tier2Combat.pick_cannon(fwd, up, o, [cand.call(100.0, 3.0, 1)]),
			Tier2Combat.pick_cannon(fwd, up, o, [cand.call(0.0, 3.0, 1, false)])]
	t.check("cannon_respects_range_cone_sight", none.all(func(x): return x.is_empty()), "out of range, outside the cone, behind rock: none picked")
	var inside := [Tier2Combat.in_bubble(o, up, Vector3(3, 0, 0)), Tier2Combat.in_bubble(o, up, Vector3(2, 2.5, 0)), Tier2Combat.in_bubble(o, up, Vector3(0, 4.0, 0)),
			Tier2Combat.in_bubble(o, up, Vector3(1, -0.3, 0))]
	var outside := [Tier2Combat.in_bubble(o, up, Vector3(3, -1.0, 0)), Tier2Combat.in_bubble(o, up, Vector3(4.5, 0, 0)), Tier2Combat.in_bubble(o, up, Vector3(0, -2.0, 0))]
	t.check("bubble_upper_hemisphere", inside.all(func(x): return x) and outside.all(func(x): return not x), "beside, above, elevated, just below the plane: in; well below, beyond the radius: out")
	var all_ok := func(_a, _b): return true
	var counts := []
	for n in [1, 2, 3, 4, 6]:
		var cs := []
		for i in n:
			cs.append(cand.call(-40.0 + 20.0 * i, 2.5 + i * 0.8, i + 1))
		var chain: Array = Tier2Combat.plan_rush(fwd, up, o, cs, all_ok)
		var ids := {}
		for c in chain:
			ids[c["id"]] = true
		counts.append([chain.size(), ids.size()])
	t.check("rush_chains_up_to_three_distinct", counts == [[1, 1], [2, 2], [3, 3], [3, 3], [3, 3]], str(counts))
	var blocked: Array = Tier2Combat.plan_rush(fwd, up, o, [cand.call(0.0, 3.0, 1), cand.call(20.0, 4.0, 2)], func(_a, bpos): return (bpos as Vector3).distance_to(at.call(0.0, 3.0)) > 0.1)
	var behind: Array = Tier2Combat.plan_rush(fwd, up, o, [cand.call(170.0, 2.0, 1)], all_ok)
	t.check("rush_skips_unreachable_and_behind", blocked.size() == 1 and blocked[0]["id"] == 2 and behind.is_empty(), "blocked one skipped: %s; one behind him: %d" % [blocked.map(func(c): return c["id"]), behind.size()])
	# Loadout: fixed order, first unlock equipped, locked ones cannot be equipped, one at a time.
	var m := Tier2.new()
	var e0 := m.equip(Tier2.CANNON)
	m.unlock(Tier2.RUSH)
	m.unlock(Tier2.CANNON)
	var e1 := m.equip(Tier2.BUBBLE)
	var e2 := m.equip(Tier2.CANNON)
	t.check("tier2_loadout_rules", not e0 and not e1 and e2 and m.equipped == Tier2.CANNON and m.unlocked == [Tier2.CANNON, Tier2.RUSH],
			"unlocked %s, equipped %s" % [str(m.unlocked), m.equipped])
	# Cooldown: shared, so swapping does not skip it.
	m.equipped = Tier2.RUSH
	m.start_cooldown(100.0)
	var r0 := m.is_ready(101.0)
	m.equip(Tier2.CANNON)
	var r1 := m.is_ready(101.0)
	var r2 := m.is_ready(100.0 + Tier2.COOLDOWN[Tier2.RUSH] + 0.01)
	t.check("tier2_swap_keeps_cooldown", not r0 and not r1 and r2 and absf(m.charge(100.0 + Tier2.COOLDOWN[Tier2.RUSH] * 0.5) - 0.5) < 0.01, "")
	var back := Tier2.from_dict(m.to_dict())
	var junk := Tier2.from_dict({"unlocked": ["cannon", "laser", 3], "equipped": "laser"})
	t.check("tier2_saves_and_drops_unknowns", back.unlocked == m.unlocked and back.equipped == m.equipped and junk.unlocked == [Tier2.CANNON] and junk.equipped == Tier2.CANNON, str(junk.to_dict()))


## A flat spot on ball `bi` with nothing hostile (parasite or creature) within `clear` metres.
func _quiet_spot(bi: int, clear := 13.0) -> Vector3:
	var b := g.balls[bi]
	for lat in range(-70, 80, 7):
		for lon in range(-175, 180, 9):
			var d := MossBall.dir_ll(lat, lon)
			if b.ravine_carve(d) > 0.01 or absf(b.terrain_height(d)) > 0.01:
				continue
			var pos := b.surface_point(d)
			var busy := false
			for par in b.parasites:
				if par.is_alive() and par.global_position.distance_to(pos) < clear:
					busy = true
			for c in b.critters:
				if c.global_position.distance_to(pos) < clear:
					busy = true
			for m in b.motes:
				if m.global_position.distance_to(pos) < 6.0:
					busy = true
			if not busy and _open_around(b, pos):
				return pos
	return Vector3.INF


## Open water round `pos`: nothing solid (terrain, platforms, leaves, gates) within 7 m at body
## height, nor overhead. (Earlier tests heal worlds, raising gates and bridges over spots that were
## clear at the start.)
func _open_around(b: MossBall, pos: Vector3) -> bool:
	var up := b.up_at(pos)
	var space := g.get_world_3d().direct_space_state
	var fr := MossBall.frame_at(up, 0.0)
	for h in [0.8, 1.6]:
		var o: Vector3 = pos + up * h
		for k in 12:
			var dir := (fr.z.rotated(up, TAU * k / 12.0)).normalized()
			if not space.intersect_ray(PhysicsRayQueryParameters3D.create(o, o + dir * 7.0, 1 | 2 | 8)).is_empty():
				return false
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(pos + up * 0.3, pos + up * 8.0, 1 | 2 | 8)).is_empty()


func _clear_practice() -> void:
	for tg in g.practice_targets.duplicate():
		if is_instance_valid(tg):
			tg.remove()
	g.practice_targets.clear()


## A practice target has popped (it is freed once hit).
func _popped(tg) -> bool:
	return not is_instance_valid(tg) or tg.defeated


func _practice_at(pos: Vector3) -> PracticeTarget:
	var tg := PracticeTarget.new()
	tg.place(p.ball, pos, 9000 + g.practice_targets.size())
	g.practice_targets.append(tg)
	return tg


## Presses the Tier-2 button (as a player would) and waits until the ability has finished.
func _fire_tier2(timeout := 3.0) -> float:
	await _until(func(): return g.t2.active == "", 3.0)
	var before: Dictionary = g.t2.last
	await press("special")
	# (It starts on his next physics frame: wait for that, then for it to finish.)
	var started: float = await _until(func(): return g.t2.active != "" or g.t2.last != before, 0.3)
	if started < 0.0:
		return -1.0
	return await _until(func(): return g.t2.active == "", timeout)


## The pause menu's Tier-2 loadout: hidden until one is found; found ones equip on tap (exactly one
## equipped, saved, cooldown untouched); ones not found are locked; hidden when opened from the title.
func _test_tier2_loadout() -> void:
	var saved_t2 := g.tier2
	g.tier2 = Tier2.new()
	var pm := g.pause_menu
	var lo: Tier2Loadout = pm._loadout
	pm.open()
	await t.frames(2)
	var hidden0 := not lo.visible
	pm.close()
	g.tier2.unlock(Tier2.CANNON)
	g.tier2.unlock(Tier2.BUBBLE)
	g.tier2.start_cooldown(Time.get_ticks_msec() / 1000.0)
	var ready_at := g.tier2.ready_at
	pm.open()
	await t.frames(2)
	var bb: Button = lo.find_child("Tier2_" + Tier2.BUBBLE, true, false)
	var br: Button = lo.find_child("Tier2_" + Tier2.RUSH, true, false)
	var shown := lo.visible and lo.is_visible_in_tree()
	bb.pressed.emit()
	br.pressed.emit()
	await t.frames(1)
	var ok_equip := g.tier2.equipped == Tier2.BUBBLE and br.disabled and not bb.disabled and is_equal_approx(g.tier2.ready_at, ready_at)
	var on_disk: Dictionary = g.run_save.run().get("tier2", {})
	pm.close()
	pm.open(true)
	await t.frames(2)
	var title_hidden := not lo.visible
	pm.close()
	t.check("tier2_loadout_equips", hidden0 and shown and ok_equip and on_disk.get("equipped", "") == Tier2.BUBBLE and title_hidden,
			"hidden %s shown %s equipped %s saved %s title-hidden %s" % [hidden0, shown, g.tier2.equipped, on_disk, title_hidden])
	g.tier2 = saved_t2
	g.get_tree().paused = false
	await t.frames(2)


## A parasite knocked or flung inside the terrain (seed 4242 offline: one ended 3.1 m under World
## 7's upland, out of reach, so the world could not be finished) is put back on open ground.
func _test_parasite_never_buried() -> void:
	var b := g.balls[6]
	var par: Parasite = null
	for x in b.parasites:
		if x.is_alive() and x.state == "graze":
			par = x
			break
	var release := _hold_threats(b)
	par.set_physics_process(true)
	var up := b.up_at(par.global_position)
	var fr := MossBall.frame_at(up, 0.0)
	p.invuln_t = 999.0
	place_at(6, b.surface_point((par.global_position + fr.z * 9.0 - b.global_position).normalized(), 0.2), -fr.z)
	await t.frames(10)
	var home := par.global_position
	up = b.up_at(home)
	par.global_position = home - up * 3.1
	var buried0: float = b.altitude(par.global_position)
	await t.frames(30)
	var alt1: float = b.altitude(par.global_position)
	t.check("parasite_never_left_buried", buried0 < -2.5 and alt1 > -0.3 and par.global_position.distance_to(home) < 3.0,
			"put %.2f m under; after half a second %.2f m, %.2f m from where it stood" % [buried0, alt1, par.global_position.distance_to(home)])
	release.call()
	await t.frames(2)


## The aquarium experiences (docs/AQUARIUM.md): repeated entry and exit leave the run exactly as it
## was (position, clock, completion, saves, Tier 2, health, the global generator); every mode works;
## inspection stays outside the glass; Swim Mode stays in the water, earns nothing and Gill cannot
## be hurt; Back steps out one level; from the title it returns to the title; nothing leaks.
func _test_aquarium_experiences() -> void:
	var pr: Presentation = g.presentation
	var b0 := g.balls[0]
	var release := _hold_threats(b0)
	p.restore_full()
	var spot := _quiet_spot(0)
	var up := b0.up_at(spot)
	place_at(0, spot + up * 0.2, -MossBall.frame_at(up, 0.0).z)
	await t.seconds(0.6)
	g.save_run()
	var pos0 := p.global_position
	var basis0 := p.global_basis
	var run0: float = g.clock.run_s
	var earned0 := g.run_save.earned().duplicate(true)
	var tier0 := g.tier2.to_dict()
	var hp0 := p.health
	var par_pos := []
	for par in b0.parasites:
		par_pos.append(par.global_position)
	await t.frames(2)
	var nodes0 := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	# (The generator is checked across the time in the aquarium only: seeded on the way in, read on
	# the way out, before any play frame, since ordinary play draws from it.)
	var rng_ok := true
	var modes_ok := true
	var clock_ok := true
	var outside_ok := true
	for round_ in 3:
		seed(777 + round_)
		var r0 := [randi(), randi()]
		seed(777 + round_)
		pr.enter("play")
		var run_in: float = g.clock.run_s
		modes_ok = modes_ok and g.state == "aquarium" and pr.mode == "room" and pr.ui.visible and not p.visible and g.aquarium.outside
		await t.seconds(0.8)
		pr.go("inspect")
		pr.inspect_drag(Vector2(-5000, 5000))
		await t.seconds(1.2)
		outside_ok = outside_ok and absf(pr.inspect_yaw) <= Presentation.INSPECT_YAW + 0.001 and g.cam.global_position.z > Aquarium.TANK_MAX.z
		pr.go("live")
		for v in Presentation.LIVE_VIEWS.size():
			pr.next_live_view()
			await t.seconds(0.4)
		modes_ok = modes_ok and pr.mode == "live"
		pr.go("swim")
		await t.seconds(0.5)
		modes_ok = modes_ok and pr.swimmer != null and not g.aquarium.outside
		pr.ui.swim_stick = Vector2(0.3, 1.0)
		pr.ui.swim_held = true
		await t.seconds(1.5)
		pr.ui.swim_stick = Vector2.ZERO
		pr.ui.swim_held = false
		clock_ok = clock_ok and is_equal_approx(g.clock.run_s, run_in)
		# Back, one level at a time (as Android back does): swim -> room -> play.
		g._go_back()
		modes_ok = modes_ok and pr.mode == "room" and pr.swimmer == null
		await t.seconds(0.3)
		g._go_back()
		rng_ok = rng_ok and [randi(), randi()] == r0
		modes_ok = modes_ok and pr.mode == "" and g.state == "play" and not pr.ui.visible and p.visible and p.controls_enabled
		await t.frames(2)
	t.check("aquarium_modes_and_back", modes_ok, "mode %s state %s" % [pr.mode, g.state])
	t.check("aquarium_clock_never_counts", clock_ok, "run %.3f" % g.clock.run_s)
	t.check("aquarium_inspection_outside_glass", outside_ok, "yaw %.2f cam z %.1f" % [pr.inspect_yaw, g.cam.global_position.z])
	var moved := 0.0
	for i in par_pos.size():
		if is_instance_valid(b0.parasites[i]):
			moved = maxf(moved, (b0.parasites[i] as Node3D).global_position.distance_to(par_pos[i]))
	t.check("aquarium_run_untouched", p.global_position.is_equal_approx(pos0) and p.global_basis.is_equal_approx(basis0) and g.run_save.earned() == earned0
			and g.tier2.to_dict() == tier0 and p.health == hp0 and rng_ok,
			"moved %.4f, earned %d->%d, rng same %s" % [p.global_position.distance_to(pos0), earned0.size(), g.run_save.earned().size(), rng_ok])
	t.check("aquarium_world_stands_still", moved < 0.01, "parasite moved %.3f" % moved)
	await t.seconds(0.5)
	var nodes1 := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	# (The tank's own collision is built once, on the first swim: its body and six shapes.)
	t.check("aquarium_no_leaks", nodes1 - nodes0 <= 7, "nodes %d -> %d" % [nodes0, nodes1])
	# Swim Mode: two minutes of hard swimming in every direction stays in the water, out of the
	# moss balls, earns nothing, and Gill cannot be hurt even swimming through a parasite.
	pr.enter("play")
	run0 = g.clock.run_s
	pr.go("swim")
	await t.frames(3)
	var sw := pr.swimmer
	var worst_out := 0.0
	var worst_in := 0.0
	var travelled := 0.0
	var last := sw.global_position
	var dirs := [Vector2(0, 1), Vector2(1, 0.3), Vector2(-1, 0.5), Vector2(0.2, -1)]
	for k in 8:
		sw.heading = k * 0.9
		sw.pitch = [0.9, -0.9, 0.0, 0.5][k % 4]
		pr.ui.swim_stick = dirs[k % 4]
		pr.ui.swim_held = true
		for f in 60 * 8:
			await t.frames(1)
			if f % 20 == 0:
				var sp := sw.global_position
				travelled += sp.distance_to(last)
				last = sp
				worst_out = maxf(worst_out, (sp - sp.clamp(Aquarium.TANK_MIN, Aquarium.TANK_MAX)).length())
				for b in g.balls:
					worst_in = maxf(worst_in, b.radius * 0.75 - sp.distance_to(b.global_position))
	pr.ui.swim_stick = Vector2.ZERO
	pr.ui.swim_held = false
	t.check("swim_stays_in_the_water", travelled > 200.0 and worst_out < 0.5 and worst_in <= 0.0, "swum %.0f, outside by %.2f, inside a ball by %.2f" % [travelled, worst_out, worst_in])
	var par: Node3D = null
	for x in b0.parasites:
		if x.is_alive():
			par = x
			break
	if par != null:
		sw.global_position = par.global_position
		sw.velocity = Vector3.ZERO
	await t.seconds(1.0)
	t.check("swim_earns_nothing_and_gill_safe", g.run_save.earned() == earned0 and p.health == hp0 and p.state == "presentation" and is_equal_approx(g.clock.run_s, run0),
			"earned %d, hp %d, state %s" % [g.run_save.earned().size(), p.health, p.state])
	pr.exit()
	await t.frames(2)
	t.check("swim_exit_restores_gill", p.global_position.is_equal_approx(pos0) and p.state == "normal" and g.state == "play", "")
	# From the title: Back returns to the title, not to play.
	g._enter_title()
	pr.enter("title")
	await t.seconds(0.4)
	pr.back()
	t.check("aquarium_from_title_returns_there", g.state == "title" and g.title.visible and not pr.active(), "state %s" % g.state)
	g.start_play(true)
	# Not from mid-cinematic: the pause menu's Aquarium is unavailable then.
	g.cinematic = "connect"
	g.pause_menu._refresh()
	var dis: bool = g.pause_menu._aquarium.disabled
	g.cinematic = ""
	g.pause_menu._refresh()
	t.check("aquarium_not_mid_cinematic", dis and not g.pause_menu._aquarium.disabled, "")
	release.call()
	await t.frames(2)


## Shrines, unlocks and the three abilities in the world, driven by the Tier-2 button.
func _test_tier2_world() -> void:
	var where := {}
	for b in g.balls:
		for s in b.shrines:
			where[s.ability] = b.index
	t.check("tier2_shrines_in_worlds_3_5_7", where == {Tier2.CANNON: 2, Tier2.BUBBLE: 4, Tier2.RUSH: 6}, str(where))
	var saved_t2 := g.tier2
	g.tier2 = Tier2.new()
	var b0 := g.balls[0]
	var release := _hold_threats(b0)
	p.restore_full()
	p.invuln_t = 999.0
	# Nothing before a shrine: no button, and pressing does nothing.
	var spot := _quiet_spot(0)
	var up := b0.up_at(spot)
	var fr := MossBall.frame_at(up, 0.0)
	place_at(0, spot + up * 0.2, -fr.z)
	await t.seconds(0.5)
	# (Earlier tests may have used an ability legitimately: what counts is that this press does nothing.)
	var last0: Dictionary = g.t2.last
	var fired0: float = await _fire_tier2(0.5)
	await t.frames(4)
	t.check("tier2_nothing_before_a_shrine", fired0 < 0.0 and g.t2.last == last0 and g.t2.active == "", "button shown %s; last %s; game %s cine '%s' player %s controls %s ball %d paused %s" % [g.hud.special_shown(), g.t2.last, g.state, g.cinematic, p.state, p.controls_enabled, p.ball.index, g.get_tree().paused])
	# The World 3 shrine: touched in play, it gives Water Cannon, equips it, shows the button and
	# sets out practice targets; the run save carries it.
	var sh: Tier2Shrine = g.balls[2].shrines[0]
	sh.set_taken(false)
	g.take_shrine(sh)
	var targets_out := g.practice_targets.size()
	g.save_run()
	var saved: Dictionary = g.run_save.run()["tier2"]
	await t.frames(2)
	t.check("tier2_shrine_unlocks_and_equips", g.tier2.equipped == Tier2.CANNON and g.hud.special_shown() and targets_out == 3 and saved.get("unlocked", []) == [Tier2.CANNON] and sh.taken,
			"equipped %s, button %s, practice targets %d, saved %s" % [g.tier2.equipped, g.hud.special_shown(), targets_out, str(saved)])
	_clear_practice()
	# Water Cannon: two targets, one 10 degrees off his facing and one 90 degrees off, both in range:
	# the button hits the one he faces (and only it).
	var face := -fr.z
	var c0 := p.body_center()
	var ta := _practice_at(c0 + face.rotated(up, deg_to_rad(10.0)) * 5.0 + up * 0.2)
	var tb := _practice_at(c0 + face.rotated(up, deg_to_rad(-90.0)) * 3.0 + up * 0.2)
	await t.frames(2)
	g.tier2.ready_at = 0.0
	await _fire_tier2()
	await t.seconds(0.5)
	t.check("water_cannon_hits_the_one_he_faces", _popped(ta) and not _popped(tb) and g.t2.last.get("hits", 0) == 1, "10 degrees off: %s; 90 degrees off: %s; %s" % [_popped(ta), _popped(tb), str(g.t2.last)])
	# Cooldown: pressing again at once does nothing; swapping cannot skip it.
	var used0: Dictionary = g.t2.last
	await press("special")
	await t.frames(2)
	t.check("tier2_cooldown_blocks_repeat", g.t2.last == used0 and g.t2.active == "" and not g.tier2.is_ready(g.clock.play_s), "charge %.2f" % g.tier2.charge(g.clock.play_s))
	_clear_practice()
	# Bubble Blast: every valid target inside the upper hemisphere is hit once (beside him, up on a
	# ledge-height point), none outside; the plants round him are blown outward and settle.
	g.tier2.unlock(Tier2.BUBBLE)
	g.tier2.equip(Tier2.BUBBLE)
	g.tier2.ready_at = 0.0
	c0 = p.body_center()
	var near := [_practice_at(c0 + fr.x * 2.5 + up * 0.3), _practice_at(c0 - fr.x * 1.5 - fr.z * 2.0 + up * 0.2), _practice_at(c0 + fr.z * 1.8 + up * 2.6)]
	var far := _practice_at(c0 - fr.z * 6.0 + up * 0.3)
	await t.frames(2)
	var plant := b0.surface_point(b0.up_at(p.global_position + fr.x * 2.6))
	await _fire_tier2()
	await t.frames(6)
	var bend_now := g.wake.bend_at(b0, plant, 1.0)
	var out_dir := (plant - p.global_position)
	out_dir -= up * out_dir.dot(up)
	var outward := bend_now.normalized().dot(out_dir.normalized())
	var hits: int = g.t2.last.get("hits", 0)
	await t.seconds(1.5)
	var bend_mid := g.wake.bend_at(b0, plant, 1.0).length()
	await t.seconds(2.0)
	var bend_late := g.wake.bend_at(b0, plant, 1.0).length()
	t.check("bubble_blast_hits_each_once_in_volume", near.all(func(x): return _popped(x)) and not _popped(far) and hits == 3, "hits %d; far one %s; %s" % [hits, _popped(far), str(g.t2.last)])
	t.check("bubble_blast_blows_plants_out_then_settles", bend_now.length() > 0.3 and outward > 0.6 and bend_mid > 0.02 and bend_late < bend_now.length() * 0.2,
			"bend %.2f (outward %.2f), after 1.5 s %.2f, after 3.5 s %.2f" % [bend_now.length(), outward, bend_mid, bend_late])
	_clear_practice()
	# Gill Rush: 1, 2, 3 and 5 targets ahead: that many lunges up to three, never one twice; he
	# really travels (not a teleport) and control comes back.
	g.tier2.unlock(Tier2.RUSH)
	g.tier2.equip(Tier2.RUSH)
	var rush_res := []
	for n in [1, 2, 3, 5]:
		place_at(0, spot + up * 0.2, -fr.z)
		await t.seconds(0.4)
		c0 = p.body_center()
		var ts := []
		for i in n:
			ts.append(_practice_at(c0 - fr.z * (2.2 + i * 1.3) + fr.x * (0.9 if i % 2 == 0 else -0.9) + up * 0.1))
		await t.frames(2)
		g.tier2.ready_at = 0.0
		var p0 := p.global_position
		var max_step := 0.0
		var prev := p0
		await press("special")
		for f in 180:
			await t.frames(1)
			max_step = maxf(max_step, p.global_position.distance_to(prev))
			prev = p.global_position
			if g.t2.active == "":
				break
		var killed := ts.filter(func(x): return _popped(x)).size()
		rush_res.append([n, g.t2.last.get("hits", 0), killed, snappedf(max_step, 0.01), g.t2.active == "" and p.controls_enabled])
		_clear_practice()
	var rush_ok := true
	for r in rush_res:
		rush_ok = rush_ok and r[1] == mini(r[0], 3) and r[2] == mini(r[0], 3) and r[3] < 0.4 and r[4]
	t.check("gill_rush_one_two_three_max", rush_ok, "[targets, hits, beaten, largest step per frame, control back] %s" % str(rush_res))
	# A later target across a ravine is never rushed at: the chain stops at the rim.
	var lb: LevelBuilder = b0.get_meta("builder")
	var cr: Dictionary = lb.crossings[0]
	var rim_a: Vector3 = cr["a"]
	var rim_b: Vector3 = cr["b"]
	var ra_up := b0.up_at(rim_a)
	var toward := (rim_b - rim_a)
	toward -= ra_up * toward.dot(ra_up)
	place_at(0, rim_a + ra_up * 0.2 - toward.normalized() * 1.2, toward)
	await t.seconds(0.4)
	var t_here := _practice_at(p.body_center() + toward.normalized() * 0.8 + ra_up * 0.2)
	# (Out over the ravine at rim height: in range, but reaching it means leaving the rim.)
	var over := rim_a.lerp(rim_b, 0.5)
	var t_over := _practice_at(b0.surface_point(b0.up_at(over), b0.altitude(rim_a) + 0.4))
	await t.frames(2)
	g.tier2.ready_at = 0.0
	var falls0 := int(g.stats.get("ravine_falls", 0))
	await _fire_tier2()
	await t.seconds(0.3)
	t.check("gill_rush_never_crosses_a_ravine", _popped(t_here) and not _popped(t_over) and int(g.stats.get("ravine_falls", 0)) == falls0 and p.state == "normal",
			"near %s, across %s, ravine falls +%d; %s" % [_popped(t_here), _popped(t_over), int(g.stats.get("ravine_falls", 0)) - falls0, str(g.t2.last)])
	_clear_practice()
	g.tier2 = saved_t2
	release.call()
	p.invuln_t = 0.0
	p.restore_full()


## The aquarium/UI polish package (docs/AQUARIUM.md): the two swim controls and their inversion,
## Settings from the title's gear, the fish seen from the room, and the colours workspace.
## The aquarium stand-in explores without entering the scenery (00039-aquarium-gill;
## scripts/tests/aq_nav_tests.gd): the audit's worst homes, determinism, the close-up's camera.
func _test_aquarium_gill() -> void:
	var at = load("res://scripts/tests/aq_nav_tests.gd").new(t, g)
	await at.quick()


## The long measurement (--only=_phase_aq_nav [--ball=N] [--homes=24] [--mins=10] [--twin=120]).
func _phase_aq_nav() -> void:
	var at = load("res://scripts/tests/aq_nav_tests.gd").new(t, g)
	await at.nav_phase()


func _test_aquarium_polish() -> void:
	var pr: Presentation = g.presentation
	var pm: PauseMenu = g.pause_menu
	var b0 := g.balls[0]
	var release := _hold_threats(b0)
	p.restore_full()
	var spot := _quiet_spot(0)
	var up := b0.up_at(spot)
	place_at(0, spot + up * 0.2, -MossBall.frame_at(up, 0.0).z)
	await t.seconds(0.5)
	g.save_run()
	var run0: float = g.clock.run_s
	var earned0 := g.run_save.earned().duplicate(true)
	var invert0 := Settings.swim_invert_y
	# The bedroom is built once after startup (never during it), and is ready before any room view.
	var bed_ms: float = g.aquarium.room_build_ms
	t.check("bedroom_built_after_startup", bed_ms >= 0.0 and g.aquarium._bedroom != null and StartupTrace.has("aquarium: the rest") and not StartupTrace.has("aquarium: bedroom and the rest"),
			"built in %.1f ms" % bed_ms)
	# --- Swim: exactly two controls, the stick aims his nose, Swim propels along it ---
	pr.enter("play")
	pr.go("swim")
	await t.frames(3)
	var sw := pr.swimmer
	var names: Array = pr.ui.swim_buttons().keys()
	t.check("swim_exactly_two_controls", names == ["swim"] and not ("swim_up" in pr.ui) and not ("swim_fast" in pr.ui) and not ("swim_look" in pr.ui),
			"buttons %s" % [names])
	# The stick lives on the left half; a touch there takes it, the button takes its own touch.
	var vp := g.get_viewport().get_visible_rect().size
	var sb: Array = pr.ui.swim_buttons()["swim"]
	pr.ui._down(0, Vector2(vp.x * 0.2, vp.y * 0.7))
	pr.ui._move(0, Vector2(vp.x * 0.2, vp.y * 0.7 + 200.0), Vector2(0, 200))
	var stick_down: Vector2 = pr.ui.swim_stick
	pr.ui._down(1, sb[0])
	var held: bool = pr.ui.swim_held
	pr.ui._up(1, sb[0])
	pr.ui._up(0, Vector2(vp.x * 0.2, vp.y * 0.7 + 200.0))
	t.check("swim_touch_controls", stick_down.y < -0.5 and held and not pr.ui.swim_held and pr.ui.swim_stick == Vector2.ZERO,
			"stick %s held %s" % [stick_down, held])
	# Pitch: pulling down (stick y < 0) raises his nose by default, lowers it when inverted.
	var pitches := []
	for inv in [false, true]:
		Settings.swim_invert_y = inv
		sw.pitch = 0.0
		sw.velocity = Vector3.ZERO
		pr.ui.swim_stick = Vector2(0, -1)
		await t.seconds(0.6)
		pr.ui.swim_stick = Vector2.ZERO
		pitches.append(sw.pitch)
		await t.seconds(0.3)
	t.check("swim_pitch_default_and_inverted", pitches[0] > 0.3 and pitches[1] < -0.3, "pitch %.2f / inverted %.2f" % pitches)
	Settings.swim_invert_y = false
	# Yaw: the stick turns him; the camera follows behind his nose.
	sw.pitch = 0.0
	var h0 := sw.heading
	pr.ui.swim_stick = Vector2(1, 0)
	await t.seconds(0.8)
	pr.ui.swim_stick = Vector2.ZERO
	var turned := absf(wrapf(sw.heading - h0, -PI, PI))
	await t.seconds(1.2)
	t.check("swim_stick_turns_him", turned > 0.5 and absf(wrapf(sw.cam_yaw - sw.heading, -PI, PI)) < 0.3, "turned %.2f, cam lag %.2f" % [turned, wrapf(sw.cam_yaw - sw.heading, -PI, PI)])
	# Swim held: speed builds along his nose. Released: he glides to a stop.
	sw.pitch = 0.2
	sw.velocity = Vector3.ZERO
	pr.ui.swim_held = true
	await t.seconds(2.0)
	var v_on := sw.velocity
	var along := v_on.normalized().dot(sw.nose())
	pr.ui.swim_held = false
	await t.seconds(0.5)
	var v_glide := sw.velocity.length()
	await t.seconds(6.0)
	var v_end := sw.velocity.length()
	t.check("swim_button_propels_along_nose", v_on.length() > 5.0 and along > 0.9 and v_glide > 1.0 and v_end < v_glide * 0.3,
			"speed %.1f along %.2f, glide %.1f -> %.1f" % [v_on.length(), along, v_glide, v_end])
	# Without Swim he never moves off by himself.
	sw.velocity = Vector3.ZERO
	var still0 := sw.global_position
	await t.seconds(1.0)
	t.check("swim_no_drift_without_input", sw.global_position.distance_to(still0) < 0.05, "%.3f" % sw.global_position.distance_to(still0))
	# The setting persists in settings.cfg [controls] (schema unchanged).
	Settings.swim_invert_y = true
	Settings.save()
	var cf := ConfigFile.new()
	cf.load("user://settings.cfg")
	var saved_inv: bool = cf.get_value("controls", "swim_invert_y", false)
	Settings.swim_invert_y = invert0
	Settings.save()
	t.check("swim_invert_persists", saved_inv and int(cf.get_value("meta", "save_schema", 1)) == 1, "saved %s" % saved_inv)
	pr.back()
	await t.seconds(0.3)
	# --- Live Tank fish: all thirteen, the bala trio, drawn larger from outside, same simulation ---
	pr.go("live")
	await t.seconds(1.0)
	var kinds := {}
	var in_bounds := true
	var scaled := true
	for f in g.fish.fish:
		kinds[f["kind"]] = int(kinds.get(f["kind"], 0)) + 1
		var n: Node3D = f["node"]
		in_bounds = in_bounds and (f["pos"] as Vector3) == (f["pos"] as Vector3).clamp(Aquarium.TANK_MIN, Aquarium.TANK_MAX)
		scaled = scaled and n.visible and is_equal_approx(n.scale.x, Aquarium.OUTSIDE_FISH_SCALE)
	var p0: Vector3 = g.fish.fish[0]["pos"]
	await t.seconds(0.5)
	var swimming: bool = (g.fish.fish[0]["pos"] as Vector3).distance_to(p0) > 0.05
	t.check("live_tank_fish_present", g.fish.fish.size() == AmbientFish.COUNT and kinds.get("bala", 0) == 3 and in_bounds and scaled and swimming,
			"%d fish %s, in bounds %s, scaled %s, swimming %s" % [g.fish.fish.size(), kinds, in_bounds, scaled, swimming])
	var far_ok := true
	for b in g.balls:
		far_ok = far_ok and ((b as MossBall).far_vegetation() == null or (b as MossBall).far_vegetation().visible)
	pr.back()
	await t.seconds(0.2)
	var run_out: float = g.clock.run_s
	pr.exit()
	await t.frames(3)
	var back_scale := true
	for f in g.fish.fish:
		back_scale = back_scale and is_equal_approx((f["node"] as Node3D).scale.x, 1.0)
	for b in g.balls:
		far_ok = far_ok and ((b as MossBall).far_vegetation() == null or not (b as MossBall).far_vegetation().visible)
	t.check("fish_scale_only_outside", back_scale and far_ok and g.fish.display_scale == 1.0, "scale back %s far %s" % [back_scale, far_ok])
	t.check("aquarium_polish_run_untouched", g.run_save.earned() == earned0 and is_equal_approx(run_out, run0),
			"earned %d -> %d, clock %.3f -> %.3f" % [earned0.size(), g.run_save.earned().size(), run0, run_out])
	release.call()
	# --- The title: a gear opens the same Settings (diagnostics included); Back returns ---
	g._enter_title()
	await t.frames(3)
	var run_file0 := FileAccess.get_file_as_string(RunSave.PATH)
	run0 = g.clock.run_s
	var gear: Button = g.title.gear
	var gr := gear.get_global_rect()
	var gear_ok := gear.is_visible_in_tree() and gear.name == "SettingsGear" and gear.icon != null and gr.size.x >= 88.0 and gr.size.y >= 88.0 \
			and Rect2(Vector2.ZERO, vp).encloses(gr)
	t.check("title_settings_gear", gear_ok, "rect %s in %s" % [gr, vp])
	gear.pressed.emit()
	await t.frames(3)
	var diag_btn: Button = null
	for c in pm.find_children("*", "Button", true, false):
		if (c as Button).text == "About / Diagnostics":
			diag_btn = c
	var st_ok: bool = pm.visible and pm._from_title and diag_btn != null and diag_btn.is_visible_in_tree() and not g.get_tree().paused and g.state == "title"
	var resume := pm._panel.find_child("Resume", true, false) as Button
	resume.pressed.emit()
	await t.frames(3)
	t.check("title_settings_open_and_back", st_ok and not pm.visible and g.title.visible and g.state == "title"
			and FileAccess.get_file_as_string(RunSave.PATH) == run_file0 and is_equal_approx(g.clock.run_s, run0),
			"opened %s diag %s resume '%s'" % [st_ok, diag_btn != null, resume.text])
	# --- The colours page: controls left, Gill right, always visible, turned by dragging him ---
	g.title._on_colours()
	await t.frames(4)
	var page: GillPage = pm.gill_page
	# (Laid out as on a 1280 x 720 phone with a 90 px cut-out on the left.)
	var area := Rect2(90, 14, 1280 - 90 - 16, 692)
	page.layout_in(area)
	await t.frames(2)
	vp = Vector2(1280, 720)
	var cr := page.controls.get_global_rect()
	var sr := page.stage.get_global_rect()
	var split_ok := cr.end.x <= sr.position.x + 0.5 and area.encloses(cr) and area.encloses(sr) and sr.size.x >= 500.0 and sr.size.y >= 600.0 \
			and page.controls.get_combined_minimum_size().x <= cr.size.x + 0.5 and page.controls.get_combined_minimum_size().y <= cr.size.y + 0.5
	t.check("colours_split_workspace", split_ok, "controls %s stage %s min %s" % [cr, sr, page.controls.get_combined_minimum_size()])
	# No scrolling at all (owner ruling 2026-09-30): no scroll container, and the last control (the
	# pattern repeats) is on screen beside him, with nothing moved.
	var scrolls := page.find_children("*", "ScrollContainer", true, false)
	var last_r := page._pattern_size.get_global_rect()
	t.check("colours_no_scroll_gill_always_shown", scrolls.is_empty() and area.encloses(last_r) and cr.encloses(last_r) and page.stage.get_global_rect() == sr and page.stage.is_visible_in_tree(),
			"scroll containers %d, repeats slider %s, stage %s" % [scrolls.size(), last_r, page.stage.get_global_rect()])
	# A preset recolours him at once; so does a slider.
	var base0 := page.preview.look_base()
	(page.find_child("Morph_golden", true, false) as Button).pressed.emit()
	await t.frames(1)
	var base1 := page.preview.look_base()
	page._body_hue.value = 0.3
	await t.frames(1)
	var base2 := page.preview.look_base()
	t.check("colours_live_update", base1 != base0 and base2 != base1 and Settings.gill_morph == "golden", "%s %s %s" % [base0, base1, base2])
	# Dragging on him turns him and never scrolls; a slider never turns him.
	page._touched = true
	page._yaw_v = 0.0
	var yaw0 := page.yaw
	var col0 := page.column.get_global_rect()
	var c := sr.get_center()
	var to_win := g.get_viewport().get_screen_transform()
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = to_win * c
	ev.global_position = ev.position
	g.get_viewport().push_input(ev)
	for k in 5:
		var mv := InputEventMouseMotion.new()
		mv.button_mask = MOUSE_BUTTON_MASK_LEFT
		mv.position = to_win * (c + Vector2(30.0 * (k + 1), 40.0 * (k + 1)))
		mv.global_position = mv.position
		mv.relative = to_win.basis_xform(Vector2(30.0, 40.0))
		g.get_viewport().push_input(mv)
		await t.frames(1)
	var rel := ev.duplicate() as InputEventMouseButton
	rel.pressed = false
	rel.position = to_win * (c + Vector2(150, 200))
	rel.global_position = rel.position
	g.get_viewport().push_input(rel)
	await t.frames(2)
	var yaw1 := page.yaw
	t.check("colours_drag_turns_gill", absf(yaw1 - yaw0) > 0.5 and page.column.get_global_rect() == col0, "yaw %.2f -> %.2f column %s" % [yaw0, yaw1, page.column.get_global_rect()])
	page._yaw_v = 0.0
	await t.frames(2)
	var yaw2 := page.yaw
	page._dots_bright.value = 0.7
	await t.frames(3)
	t.check("colours_slider_never_turns", absf(page.yaw - yaw2) < 0.01, "%.3f" % (page.yaw - yaw2))
	# Persisted as before ([gill], schema 1), and restored by Pink.
	var cf2 := ConfigFile.new()
	cf2.load("user://settings.cfg")
	t.check("colours_persist", cf2.get_value("gill", "morph", "") == "golden" and is_equal_approx(float(cf2.get_value("gill", "dots_bright", 0.0)), 0.7), "")
	(page.find_child("Morph_pink", true, false) as Button).pressed.emit()
	(page.find_child("Done", true, false) as Button).pressed.emit()
	await t.frames(2)
	pm.close()
	await t.frames(2)
	g.title._on_play()
	await t.seconds(0.5)


## The landscape menus (phone audit 2026-09-30 §A, owner rulings; release 00038): Settings and the
## colours page fit a phone's 720-px design height with nothing to scroll, at 1280 x 720 (16:9),
## 1560 x 720 (19.5:9) and 1600 x 720 (20:9), with a 90 px camera cut-out on either side: every control
## inside the safe area, no two touch targets overlapping, none under 56 px tall. Settings is checked
## at its fullest (Tier 2 row, Treasure Hunt and the New Run question all showing) and from the title.
## Pause order: Resume, then Return to Title directly beneath it.
## The Tutorials toggle (owner ruling 2026-10-01, docs/ONBOARDING.md; it replaces Replay tutorial) is
## in Settings from the title and in-run; the title menu with the New Run question open keeps every
## control on screen (owner phone screenshot, 2026-10-01: the question pushed the last buttons off
## the bottom). (The toggle's behaviour: _test_onb_toggle and _test_onb_per_run.)
func _phase_th_bench() -> void:
	var dirs := PackedVector3Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 200000:
		dirs.append(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized())
	for rep in 3:
		var t0 := Time.get_ticks_usec()
		var acc := 0.0
		for b in g.balls:
			for d in dirs:
				acc += b.terrain_height(d)
		t.log_line("THBENCH %.0f ms for %d calls (sum %.3f)" % [(Time.get_ticks_usec() - t0) / 1000.0, dirs.size() * g.balls.size(), acc])
	# Where the time goes: the cell lookup alone, and the ravine distance alone.
	var t1 := Time.get_ticks_usec()
	var nc := 0
	var ncv := 0
	for b in g.balls:
		for d in dirs:
			var cell = b._cells.get(b._cell_key(d))
			if cell != null:
				nc += 1
				ncv += (cell[1] as Array).size()
	var t2 := Time.get_ticks_usec()
	for b in g.balls:
		for d in dirs:
			var cell = b._cells.get(b._cell_key(d))
			if cell != null:
				for k in cell[1]:
					MossBall._polyline_angle(d, b.carves[k][0])
	t.log_line("THPARTS lookup %.0f ms (%d hits, %d carve terms); lookup+polyline %.0f ms" % [(t2 - t1) / 1000.0, nc, ncv, (Time.get_ticks_usec() - t2) / 1000.0])


## Startup work (2026-10-01): a hash of the whole built world (every mesh's vertices, every collision
## shape's faces, every node transform under each ball) and of terrain heights; must not change.
func _phase_world_hash() -> void:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var n_mesh := 0
	var n_shape := 0
	for b in g.balls:
		var stack: Array = [b]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			for c in n.get_children():
				stack.append(c)
			if n is Node3D:
				ctx.update(var_to_bytes((n as Node3D).transform))
			if n is MeshInstance3D and (n as MeshInstance3D).mesh is ArrayMesh:
				var m: ArrayMesh = (n as MeshInstance3D).mesh
				for si in m.get_surface_count():
					ctx.update((m.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array).to_byte_array())
				n_mesh += 1
			if n is CollisionShape3D and (n as CollisionShape3D).shape is ConcavePolygonShape3D:
				ctx.update(((n as CollisionShape3D).shape as ConcavePolygonShape3D).get_faces().to_byte_array())
				n_shape += 1
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		var hs := PackedFloat64Array()
		for i in 4000:
			hs.append(b.terrain_height(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()))
		ctx.update(hs.to_byte_array())
	t.log_line("WORLDHASH %s meshes %d shapes %d" % [ctx.finish().hex_encode(), n_mesh, n_shape])


## Leaves (owner 2026-10-01): a landing gives a little and springs back, settling in about a second
## (not a trampoline: visual only); the current ball's leaves sway with its current.
func _test_leaf_motion() -> void:
	var lm: LeafMotion = g.leaf_motion
	var b: MossBall = g.balls[0]
	lm.landed(b, b.surface_point(Vector3.UP, 0.5), 12.0)
	var peak := 0.0
	var flips := 0
	var last_sign := 1.0
	var settle := -1.0
	for i in 120:
		await t.frames(1)
		peak = maxf(peak, lm.y)
		var sg := signf(lm.v) if absf(lm.v) > 0.01 else last_sign
		if sg != last_sign:
			flips += 1
			last_sign = sg
		var target := LeafMotion.STAND if LeafMotion.leaf_under(g.player) != null else 0.0
		if settle < 0.0 and i > 10 and absf(lm.y - target) < 0.002 and absf(lm.v) < 0.01:
			settle = i / 60.0
	var cur_set := 0
	for bb in g.balls:
		if (bb as MossBall).current_strength > 0.0 and (bb as MossBall).leaf_mat != null and float((bb as MossBall).leaf_mat.get_shader_parameter("cur_strength")) > 0.0:
			cur_set += 1
	var cleared: bool = LeafMotion.leaf_under(g.player) != null or b.leaf_mat == null or (b.leaf_mat.get_shader_parameter("press") as Vector4) == Vector4.ZERO
	t.check("leaf_landing_give", peak >= 0.02 and peak <= LeafMotion.MAX_DIP and flips <= 3 and settle > 0.0 and settle <= 1.6 and cleared,
			"peak %.3f m, %d direction changes, settled after %.2f s, cleared %s" % [peak, flips, settle, cleared])
	t.check("leaf_current_sway_set", cur_set >= 1, "%d ball(s) with a current drive their leaves" % cur_set)


## Polish pass A (owner brief 2026-10-01): mobile ergonomics and small QOL.
func _test_polish_a() -> void:
	# Right-thumb cluster: no touch areas overlap, >= 20 px dead space between neighbours, every
	# button inside the safe area, on several landscape shapes; edge touches go to the nearest button.
	var hud: Hud = g.hud
	var win := g.get_tree().root
	var size0 := win.size
	var worst := INF
	var outside := []
	var wrong := 0
	for sz in [Vector2i(1280, 720), Vector2i(2400, 1080), Vector2i(1600, 720), Vector2i(1334, 750), Vector2i(960, 540)]:
		win.size = sz
		await t.frames(2)
		hud._layout()
		var bi: Dictionary = hud._buttons
		var keys := bi.keys()
		for i in keys.size():
			var a: Dictionary = bi[keys[i]]
			var reach := Rect2(a["c"] - Vector2.ONE * a["r"], Vector2.ONE * a["r"] * 2.0)
			if not hud._safe.encloses(reach):
				outside.append("%s@%s" % [keys[i], str(sz)])
			for j in range(i + 1, keys.size()):
				var b: Dictionary = bi[keys[j]]
				worst = minf(worst, a["c"].distance_to(b["c"]) - 1.25 * (a["r"] + b["r"]))
		# A touch just inside swipe's area on the side facing jump presses swipe, not jump.
		var j: Dictionary = bi[Hud.BTN_JUMP]
		var sw: Dictionary = bi[Hud.BTN_SWIPE]
		var edge: Vector2 = sw["c"] + (j["c"] - sw["c"]).normalized() * sw["r"] * 1.2
		if hud.button_at(edge) != Hud.BTN_SWIPE:
			wrong += 1
	win.size = size0
	await t.frames(2)
	hud._layout()
	# No empty hint ring during a cinematic; the hint comes back with the controls (and a pause/resume
	# during the shot leaves it right).
	hud.show_prompt("swipe")
	var shown0 := hud.prompts_shown()
	hud.set_cinematic(true)
	var during := hud.prompts_shown()
	g.pause_menu.open()
	await t.frames(2)
	g.pause_menu.close()
	await t.frames(2)
	var after_pause := hud.prompts_shown()
	hud.set_cinematic(false)
	await t.frames(2)
	var back := hud.prompts_shown() and hud.prompts.has("swipe")
	hud.hide_prompt("swipe")
	t.check("prompt_ring_hidden_in_cinematics", shown0 and not during and not after_pause and back,
			"before %s, during %s, after pause %s, back %s" % [shown0, during, after_pause, back])
	# Diagnostics: the game-layer page opens from Settings, shows a status headline and the full
	# text, fits the screen, offers Install only while an update waits, and closes with Back.
	g.pause_menu.open(true)
	await t.frames(2)
	(g.pause_menu._panel.find_child("AboutDiagnostics", true, false) as Button).pressed.emit()
	await t.frames(3)
	var dp: DiagnosticsPage = g.diagnostics
	var screen := dp._root.get_viewport_rect()
	var fits := screen.encloses(dp._panel.get_global_rect())
	var diag_ok: bool = dp.visible and dp._status.text != "" and dp._text.text.contains("DIAGNOSTICS") and not dp._install.visible and fits
	g._go_back()
	await t.frames(2)
	diag_ok = diag_ok and not dp.visible and g.pause_menu.visible
	g.pause_menu.close()
	t.check("diagnostics_page_simple", diag_ok, "status '%s', fits %s (%s in %s)" % [dp._status.text, fits, str(dp._panel.get_global_rect()), str(screen)])
	# Exit on the title: present, inside the screen, apart from the menu column, behind a question.
	g._enter_title()
	await t.frames(4)
	var ts := g.title
	var ex: Button = ts.exit_box.get_node("Ask")
	var exr := ex.get_global_rect()
	var gap := INF
	for c in ts._column.get_children():
		if (c as Control).is_visible_in_tree():
			var cr := (c as Control).get_global_rect()
			gap = minf(gap, exr.position.x - cr.end.x)
	ex.pressed.emit()
	await t.frames(2)
	var asks: bool = (ts.exit_box.get_node("Confirm") as Control).visible and ts.get_viewport().get_visible_rect().encloses(ts.exit_box.get_global_rect())
	ts.show_title()
	await t.frames(2)
	var reset: bool = not (ts.exit_box.get_node("Confirm") as Control).visible
	t.check("title_exit_safe", gap > 200.0 and asks and reset and exr.size.y >= 44.0, "gap to menu %.0f px, question on screen %s, reset %s, height %.0f" % [gap, asks, reset, exr.size.y])
	g.start_play(true)
	await t.frames(3)
	await t.frames(40)
	var fl: String = g.frame_stats.line("play")
	t.check("frame_stats_in_diagnostics", fl.contains("fps") and g.run_diagnostics_text().contains("Frames title"), fl)
	# Automatic updates: a return from the background stays a safe moment for RESUME_WINDOW_S, so a
	# native check starting at the same instant no longer costs the install (owner phone 2026-10-01).
	var au: AutoUpdate = g.auto_update
	au._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	au._process(1.0)
	var open_after_1s := au._resume_left > 0.0
	au._process(AutoUpdate.RESUME_WINDOW_S)
	t.check("auto_update_resume_window", open_after_1s and au._resume_left == 0.0, "window %.0f s" % AutoUpdate.RESUME_WINDOW_S)
	# Title pacing: the phone video's mix (17 ms with 50-67 ms frames) caps the title at an even 30;
	# a steady 60 does not.
	var phone: Array[float] = []
	var steady: Array[float] = []
	for i in 90:
		phone.append(0.017 if i % 3 != 0 else 0.066)
		steady.append(0.0167)
	t.check("title_pacing_caps_only_uneven", Game.title_should_cap(phone) and not Game.title_should_cap(steady) and not g.title_capped, "")
	t.check("hud_thumb_targets_separated", worst >= 20.0 and outside.is_empty() and wrong == 0,
			"min dead space %.1f px, outside safe %s, edge misroutes %d" % [worst, str(outside), wrong])


func _test_tutorials_and_title() -> void:
	# The title with the New Run question open.
	var ts := g.title
	g._enter_title()
	await t.frames(5)
	ts._new_run.visible = true
	(ts._new_run.get_node("Ask") as Button).pressed.emit()
	await t.frames(3)
	var screen := ts._root.get_viewport_rect()
	var off := []
	for c in ts._column.find_children("*", "Control", true, false):
		var cc := c as Control
		if cc.is_visible_in_tree() and not screen.encloses(cc.get_global_rect()):
			off.append("%s %s" % [cc.name, cc.get_global_rect()])
	t.check("title_new_run_question_fits", off.is_empty() and not ts._colours.visible and not ts._skills.visible and not ts._aquarium.visible
			and ts._play.is_visible_in_tree(), ", ".join(off))
	(ts._new_run.find_child("Cancel", true, false) as Button).pressed.emit()
	await t.frames(3)
	t.check("title_buttons_back_after_cancel", ts._colours.visible and ts._skills.visible and ts._aquarium.visible
			and (ts._new_run.get_node("Ask") as Control).visible, "")
	# Settings from the title: the Tutorials toggle (on), and no Replay tutorial any more.
	var pm := g.pause_menu
	pm.open(true)
	await t.frames(3)
	var tb := pm._panel.find_child("Tutorials", true, false) as CheckButton
	t.check("tutorials_toggle_from_title_settings", tb != null and tb.is_visible_in_tree() and tb.button_pressed == Settings.tutorials
			and pm._panel.find_child("ReplayTutorial", true, false) == null, "toggle %s" % (tb != null))
	pm.close()
	await t.frames(1)
	pm.open()
	await t.frames(2)
	t.check("tutorials_toggle_in_run_settings_too", tb != null and tb.is_visible_in_tree(), "")
	pm.close()
	ts.hide_title()
	g.start_play(true)
	await t.frames(3)


func _test_menus_no_scroll() -> void:
	var pm := g.pause_menu
	var saved_t2 := g.tier2
	g.tier2 = Tier2.new()
	g.tier2.unlock(Tier2.CANNON)
	g.tier2.unlock(Tier2.BUBBLE)
	g.tier2.equip(Tier2.BUBBLE)
	var results: Array[String] = []
	var ok := true
	pm.open()
	await t.frames(3)
	# As it opens on this window (its own safe-area layout, wrapped text measured at its width).
	var screen := pm._root.get_viewport_rect()
	var pr0 := pm._panel.get_global_rect()
	t.check("settings_opens_on_screen", screen.encloses(pr0) and pr0.size.y <= 696.0, "panel %s in %s" % [pr0, screen])
	# Pause order.
	var acts: Array = pm._left.get_children().filter(func(n: Node) -> bool: return (n as Control).visible)
	var rr := (pm._panel.find_child("Resume", true, false) as Control).get_global_rect()
	var tr := (pm._panel.find_child("ReturnToTitle", true, false) as Control).get_global_rect()
	t.check("pause_order_resume_then_title", acts.size() >= 2 and acts[0].name == "Resume" and acts[1].name == "ReturnToTitle"
			and is_equal_approx(tr.position.x, rr.position.x) and absf(tr.position.y - rr.end.y - 8.0) < 0.5,
			"%s; Resume %s, Return to Title %s" % [acts.map(func(n: Node) -> String: return str(n.name)), rr, tr])
	# At its fullest.
	pm._treasure.visible = true
	pm._loadout.visible = true
	(pm._panel.find_child("Ask", true, false) as Button).pressed.emit()
	for from_title in [false, true]:
		if from_title:
			(pm._panel.find_child("Cancel", true, false) as Button).pressed.emit()
			pm.close()
			await t.frames(1)
			pm.open(true)
			await t.frames(3)
		var skills_ok := (pm._panel.find_child("Skills", true, false) as Control).is_visible_in_tree()
		for w in [1280, 1560, 1600]:
			for side in ["left", "right"]:
				var area := Rect2(90 if side == "left" else 12, 12, w - 90 - 12, 720 - 24)
				pm.layout_in(area)
				await t.frames(2)
				var bad := _fit_problems(pm._panel, area, PauseMenu.MIN_TOUCH)
				if not area.encloses(pm._panel.get_global_rect()):
					bad += " panel %s" % pm._panel.get_global_rect()
				if not skills_ok:
					bad += " no Skills button"
				ok = ok and bad == ""
				if bad != "" or side == "left":
					results.append("settings%s %dx720 %s: panel %s %s" % [" (title)" if from_title else "", w, side, pm._panel.get_global_rect().size, "fits" if bad == "" else bad])
	pm.close()
	await t.frames(2)
	t.check("settings_fits_landscape_no_scroll", ok, "; ".join(results))
	# The colours page, from the pause menu, with "Mine" showing (the fullest pattern grid).
	results.clear()
	ok = true
	pm.open()
	await t.frames(2)
	pm._open_gill()
	await t.frames(3)
	var page := pm.gill_page
	(page._patterns[GillLook.UPLOAD] as Control).visible = true
	for w in [1280, 1560, 1600]:
		for side in ["left", "right"]:
			var area := Rect2(90 if side == "left" else 16, 14, w - 90 - 16, 692)
			page.layout_in(area)
			await t.frames(2)
			var bad := _fit_problems(page, area, 56.0)
			var cr := page.controls.get_global_rect()
			var sr := page.stage.get_global_rect()
			if cr.intersects(sr) or page.controls.get_combined_minimum_size().y > cr.size.y + 0.5 or sr.size.x < 500.0:
				bad += " controls %s (min %s) stage %s" % [cr, page.controls.get_combined_minimum_size(), sr]
			ok = ok and bad == ""
			if bad != "" or side == "left":
				results.append("colours %dx720 %s: column %.0f, stage %.0f x %.0f, %s" % [w, side, cr.size.x, sr.size.x, sr.size.y, "fits" if bad == "" else bad])
	page._style_patterns()
	pm.close()
	await t.frames(2)
	t.check("colours_fits_landscape_no_scroll", ok, "; ".join(results))
	g.tier2 = saved_t2
	g.get_tree().paused = false
	await t.frames(2)


## Every visible control under `root` inside `area`, no scroll container, no two touch targets
## overlapping and none under `min_h` tall. "" when it all fits, otherwise what does not.
func _fit_problems(root: Control, area: Rect2, min_h: float) -> String:
	var bad: Array[String] = []
	var targets: Array[Control] = []
	for n in root.find_children("*", "Control", true, false):
		var c := n as Control
		if not c.is_visible_in_tree():
			continue
		if c is ScrollContainer:
			bad.append("scroll container %s" % c.name)
		if not (c is BaseButton or c is Slider or c is Label or c is RichTextLabel or c is SubViewportContainer):
			continue
		var r := c.get_global_rect()
		if not area.grow(0.5).encloses(r):
			bad.append("%s outside at %s" % [c.name, r])
		if c is BaseButton or c is Slider:
			if r.size.y < min_h - 0.01:
				bad.append("%s only %.0f px tall" % [c.name, r.size.y])
			for q in targets:
				if q.get_global_rect().intersects(r):
					bad.append("%s overlaps %s" % [c.name, q.name])
			targets.append(c)
	return ", ".join(bad)


## Fingers on the menus (phone audit 2026-09-30 §A: a swipe from the Body slider recoloured Gill):
## a drag that starts on any control scrolls nothing and changes nothing: swatches, pattern cells,
## sliders (on the thumb going up or down, or on the track away from it), toggles. A tap on a
## slider's track and a sideways drag of its thumb still work, as does a tap on a swatch.
func _test_menu_touch() -> void:
	var pm := g.pause_menu
	var look := func() -> Array:
		return [Settings.gill_morph, snappedf(Settings.gill_body_hue, 0.0001), snappedf(Settings.gill_body_bright, 0.0001), snappedf(Settings.gill_dots_hue, 0.0001),
				snappedf(Settings.gill_dots_bright, 0.0001), Settings.gill_pattern, Settings.gill_pattern_mode, Settings.gill_pattern_size]
	var levels := func() -> Array:
		return [Settings.show_run_timer, Settings.reduced_hud, Settings.haptics, Settings.swim_invert_y, snappedf(Settings.music_volume, 0.0001), snappedf(Settings.sfx_volume, 0.0001)]
	var rects := func(root: Control) -> Array:
		var out := []
		for n in root.find_children("*", "Control", true, false):
			if (n as Control).is_visible_in_tree():
				out.append((n as Control).get_global_rect())
		return out
	pm.open()
	await t.frames(2)
	pm._open_gill()
	await t.frames(3)
	var page := pm.gill_page
	page.layout_in(Rect2(90, 14, 1280 - 90 - 16, 692))
	await t.frames(2)
	Settings.set_gill_look("pink", 0.0, 1.0, 0.0, 1.0)
	Settings.set_gill_pattern("spots", 0, 3)
	page.refresh()
	await t.frames(1)
	var look0: Array = look.call()
	var rects0: Array = rects.call(page)
	var drags := []
	for id in ["pink", "golden", "melanoid", "gfp"]:
		drags.append(["swatch " + id, (page._swatches[id] as Control).get_global_rect().get_center(), Vector2(0, -160)])
	for id in ["none", "hearts", "leopard"]:
		drags.append(["pattern " + id, (page._patterns[id] as Control).get_global_rect().get_center(), Vector2(0, 160)])
	drags.append(["Full colour", page._full_colour.get_global_rect().get_center(), Vector2(0, -150)])
	for s in [page._body_hue, page._body_bright, page._dots_hue, page._dots_bright, page._pattern_size]:
		var sl := s as TouchSlider
		var r := sl.get_global_rect()
		var thumb := Vector2(r.position.x + sl.thumb_x(), r.get_center().y)
		drags.append(["%s thumb, up" % sl.name, thumb, Vector2(14, -170)])
		drags.append(["%s thumb, down" % sl.name, thumb, Vector2(-10, 170)])
		var away := Vector2(r.position.x + (r.size.x * 0.9 if sl.thumb_x() < r.size.x * 0.5 else r.size.x * 0.1), r.get_center().y)
		drags.append(["%s track, sideways" % sl.name, away, Vector2(-120, 30)])
		drags.append(["%s track, up" % sl.name, away, Vector2(0, -160)])
	var changed: Array[String] = []
	for d in drags:
		await _drag(d[1], d[2])
		if look.call() != look0:
			changed.append("%s recoloured %s" % [d[0], look.call()])
			Settings.set_gill_look("pink", 0.0, 1.0, 0.0, 1.0)
			Settings.set_gill_pattern("spots", 0, 3)
			page.refresh()
		if rects.call(page) != rects0:
			changed.append("%s moved the page" % d[0])
	t.check("colours_drags_neither_scroll_nor_recolour", changed.is_empty() and drags.size() >= 25, "%d drags; %s" % [drags.size(), ", ".join(changed)])
	# What a finger should still do: tap a swatch, tap the track, slide the thumb sideways.
	await _drag((page._swatches["golden"] as Control).get_global_rect().get_center(), Vector2(4, 3))
	var picked := Settings.gill_morph == "golden"
	var hr := page._body_hue.get_global_rect()
	await _drag(Vector2(hr.position.x + hr.size.x * 0.85, hr.get_center().y), Vector2.ZERO)
	var tapped := page._body_hue.value > 0.25
	var br := page._body_bright.get_global_rect()
	var b0 := page._body_bright.value
	await _drag(Vector2(br.position.x + page._body_bright.thumb_x(), br.get_center().y), Vector2(-60, 6))
	var slid := page._body_bright.value < b0 - 0.1
	t.check("colours_taps_and_thumb_still_work", picked and tapped and slid, "swatch %s, track tap -> hue %.2f, thumb slide shade %.2f -> %.2f" % [picked, page._body_hue.value, b0, page._body_bright.value])
	Settings.set_gill_look("pink", 0.0, 1.0, 0.0, 1.0)
	Settings.set_gill_pattern("none", 0, 3)
	page.refresh()
	(page.find_child("Done", true, false) as Button).pressed.emit()
	await t.frames(2)
	# Settings: the toggles and the Music / Sound sliders.
	pm.layout_in(Rect2(90, 12, 1280 - 90 - 12, 696))
	await t.frames(2)
	var lv0: Array = levels.call()
	var srects0: Array = rects.call(pm._panel)
	var sdrags := []
	for c in [pm._timer_toggle, pm._reduced, pm._haptics, pm._swim_invert]:
		sdrags.append([str(c.name), (c as Control).get_global_rect().get_center(), Vector2(0, -150)])
	for s in [pm._music, pm._sfx]:
		var sl := s as TouchSlider
		var r := sl.get_global_rect()
		var thumb := Vector2(r.position.x + sl.thumb_x(), r.get_center().y)
		sdrags.append(["%s thumb, up" % sl.name, thumb, Vector2(12, -160)])
		var away := Vector2(r.position.x + (r.size.x * 0.9 if sl.thumb_x() < r.size.x * 0.5 else r.size.x * 0.1), r.get_center().y)
		sdrags.append(["%s track, up" % sl.name, away, Vector2(0, 160)])
	changed.clear()
	for d in sdrags:
		await _drag(d[1], d[2])
		if levels.call() != lv0:
			changed.append("%s changed %s" % [d[0], levels.call()])
		if rects.call(pm._panel) != srects0:
			changed.append("%s moved the panel" % d[0])
	t.check("settings_drags_neither_scroll_nor_change", changed.is_empty() and sdrags.size() >= 8 and pm._panel.find_children("*", "ScrollContainer", true, false).is_empty(),
			"%d drags; %s" % [sdrags.size(), ", ".join(changed)])
	# A tap still flips a toggle (and is saved); flip it back.
	var h0 := Settings.haptics
	await _drag(pm._haptics.get_global_rect().get_center(), Vector2.ZERO)
	var flipped := Settings.haptics != h0
	await _drag(pm._haptics.get_global_rect().get_center(), Vector2.ZERO)
	t.check("settings_tap_still_toggles", flipped and Settings.haptics == h0, "")
	pm.close()
	await t.frames(2)


## A finger's press at `at` (design px), a move by `by` in eight steps, and its release.
func _drag(at: Vector2, by: Vector2) -> void:
	var to_win := g.get_viewport().get_screen_transform()
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	ev.pressed = true
	ev.position = to_win * at
	ev.global_position = ev.position
	g.get_viewport().push_input(ev)
	await t.frames(1)
	if by != Vector2.ZERO:
		for k in 8:
			var mv := InputEventMouseMotion.new()
			mv.button_mask = MOUSE_BUTTON_MASK_LEFT
			mv.position = to_win * (at + by * (k + 1) / 8.0)
			mv.global_position = mv.position
			mv.relative = to_win.basis_xform(by / 8.0)
			g.get_viewport().push_input(mv)
			await t.frames(1)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = to_win * (at + by)
	up.global_position = up.position
	g.get_viewport().push_input(up)
	await t.frames(2)


func add_child_safe(n: Node) -> void:
	g.add_child(n)


## The tail whip: the tail visibly sweeps the arc, the arc is drawn over the real hit area, and the
## swipe's timing, reach and damage are what they were.
func _test_tail_whip() -> void:
	var b := g.balls[0]
	var release := _hold_threats(b)
	var m := p.model
	var open_ := MossBall.dir_ll(-10, -40)
	place_at(0, b.surface_point(open_, 0.2), -MossBall.frame_at(open_, 0.0).x)
	p.invuln_t = 999
	await t.seconds(0.5)
	t.check("swipe_rules_unchanged", is_equal_approx(Axolotl.SWIPE_TIME, 0.3) and is_equal_approx(Game.SWIPE_REACH, 1.95)
			and is_equal_approx(Game.SWIPE_FRONT_DOT, 0.7071) and is_equal_approx(Game.SWIPE_AIM_MAX, deg_to_rad(60.0)) and is_equal_approx(Game.SWIPE_AIM_TARGET, deg_to_rad(80.0)),
			"time %.2f s, reach %.2f m, safe cone dot %.4f" % [Axolotl.SWIPE_TIME, Game.SWIPE_REACH, Game.SWIPE_FRONT_DOT])
	# A medium twin (never registered, never killed) straight behind him at a set distance.
	var twin := Parasite.new()
	twin.setup(b, Parasite.Kind.MEDIUM, "whip_test", open_, 9.0, 0.0, false)
	b.add_child(twin)
	await t.frames(2)
	twin.set_physics_process(false)
	b.parasites.append(twin)
	var put_behind := func(dist: float, deg: float) -> void:
		var back := (-p.facing).rotated(p.up, deg_to_rad(deg))
		var d := b.up_at(p.global_position + back * dist)
		twin.global_position = b.surface_point(d, twin._ground_offset)
		twin.up = d
		twin.heading = back
		twin._trail.clear()
		twin._trail_up.clear()
		for i in 12:
			twin._trail.push_back(twin.global_position + back * 0.05 * i)
			twin._trail_up.push_back(d)
		twin._update_segments(0.0)
		twin.hp = 2
		twin.hit_cd = 0.0
		twin._set_state("graze")
	# Timing: the hit lands on the same frame of the swipe as before (30% into its 0.3 s).
	put_behind.call(1.2, 0.0)
	var face0 := p.facing
	Input.action_press("swipe")
	var frame := 0
	var hit_frame := -1
	var started := -1
	var az: Array[float] = []
	var az_at_hit := 0.0
	var side := 0.0
	for i in 60:
		await t.frames(1)
		if i == 0:
			Input.action_release("swipe")
		if started < 0 and p.swipe_t >= 0.0:
			started = i
			side = m.swipe_side
		if started >= 0:
			frame += 1
			az.append(m.whip_tip_az * side)
			if hit_frame < 0 and twin.hp < 2:
				hit_frame = frame
				az_at_hit = rad_to_deg(m.whip_tip_az * side)
	var expect := int(ceil(0.3 * Axolotl.SWIPE_TIME * 60.0 - 0.0001))
	t.check("swipe_hit_timing_unchanged", hit_frame == expect and twin.hp == 1 and p.swipe_cd >= 0.0,
			"hit on frame %d of the swipe (expected %d, 0.09 s); one stage of damage (hp %d of 2)" % [hit_frame, expect, twin.hp])
	# The drawn tail sweeps from one side round behind him to the other, most of the arc.
	var lo := INF
	var hi := -INF
	for a in az:
		lo = minf(lo, a)
		hi = maxf(hi, a)
	var last := rad_to_deg(az[az.size() - 1])
	t.check("tail_sweeps_the_arc", rad_to_deg(hi - lo) >= 200.0 and absf(az_at_hit) < 45.0 and absf(last) < 12.0 and not m.whip_active(),
			"tail tip from %.0f to %.0f deg (%.0f of the arc's 270), %.0f deg at the hit frame, back to %.0f deg" % [rad_to_deg(lo), rad_to_deg(hi), rad_to_deg(hi - lo), az_at_hit, last])
	# Reach: hit exactly when the target is within SWIPE_REACH of his body centre (plus its body).
	var agree := true
	var hits := 0
	var misses := 0
	var detail := []
	for dist in [1.0, 1.6, 2.0, 2.4, 2.9, 3.4]:
		for deg in [0.0, 70.0, -110.0]:
			put_behind.call(dist, deg)
			var c := p.body_center()
			var to: Vector3 = twin.closest_body_point(c) - c
			var in_reach := to.length() <= Game.SWIPE_REACH + twin.body_extent() and absf(to.dot(p.up)) <= 1.5
			g.player_swipe(p)
			var was_hit := twin.hp < 2
			hits += 1 if was_hit else 0
			misses += 0 if was_hit else 1
			if was_hit != in_reach:
				agree = false
				detail.append("%.1f m %d deg" % [dist, deg])
	t.check("swipe_reach_unchanged", agree and hits > 0 and misses > 0, "%d hits, %d misses; mismatches: %s" % [hits, misses, str(detail)])
	# The drawn arc is the hit area: out to SWIPE_REACH, centred on his body centre, 270 degrees.
	var aabb := m.swipe_fx.mesh.get_aabb()
	var r := maxf(aabb.end.x, -aabb.position.x)
	t.check("swipe_arc_drawn_to_scale", absf(aabb.end.z - Game.SWIPE_REACH) < 0.02 and absf(r - Game.SWIPE_REACH) < 0.02 and m.swipe_fx.position.is_equal_approx(Vector3(0, 0.25, 0))
			and is_equal_approx(AxolotlModel.ARC_SPAN, PI * 1.5), "arc reaches %.2f m back, %.2f m to the sides" % [aabb.end.z, r])
	b.parasites.erase(twin)
	twin.queue_free()
	p.facing = face0
	release.call()


## Plants and leaves move a little on their own, each out of step with its neighbours; the wake
## still adds to it; all of it in the shaders (no per-plant scripts).
func _test_ambient_sway() -> void:
	var b := g.balls[0]
	var centre := b.global_position
	# Neighbouring plants of a field: series of their sway, sampled over 20 s.
	var bases: Array[Vector3] = []
	var f0: MultiMeshInstance3D = _veg_fields(b, "medium")[0]
	var xfs: Array = f0.get_meta("veg_transforms")
	var first: Vector3 = b.global_transform * (xfs[0] as Transform3D).origin
	var near := xfs.duplicate()
	near.sort_custom(func(a, c) -> bool: return (b.global_transform * (a as Transform3D).origin).distance_to(first) < (b.global_transform * (c as Transform3D).origin).distance_to(first))
	for i in 24:
		bases.append(b.global_transform * (near[i] as Transform3D).origin)
	var series := func(base: Vector3, tint: float) -> Array:
		var out := []
		var up := (base - centre).normalized()
		var ax := MossBall.frame_at(up, 0.0).x
		for k in 200:
			out.append(Vegetation.ambient_bend(base, centre, tint, k * 0.1, 0.13, 1.3).dot(ax))
		return out
	var ss := []
	for bb in bases:
		ss.append(series.call(bb, 0.9))
	var mean_r := 0.0
	var locked := 0
	var pairs := 0
	for i in ss.size():
		for j in range(i + 1, ss.size()):
			var r := _corr(ss[i], ss[j])
			mean_r += absf(r)
			locked += 1 if r > 0.9 else 0
			pairs += 1
	mean_r /= pairs
	t.check("neighbour_plants_sway_out_of_step", mean_r < 0.35 and locked <= pairs / 20, "24 neighbouring reeds (within %.1f m): mean |r| %.2f, %d of %d pairs in step" % [bases[23].distance_to(first), mean_r, locked, pairs])
	# Blades within one plant (their tints) flutter on their own phases too.
	var blade := []
	for tint in [0.72, 0.78, 0.83, 0.9, 0.97]:
		blade.append(series.call(bases[0], tint))
	var br := 0.0
	var bn := 0
	for i in blade.size():
		for j in range(i + 1, blade.size()):
			br += _corr(blade[i], blade[j])
			bn += 1
	br /= bn
	# Small: the tip of a medium reed moves a few centimetres to a couple of decimetres.
	var peak := 0.0
	for sr in ss:
		for v in sr:
			peak = maxf(peak, absf(v))
	var tip := peak * Vegetation.FAMILIES["medium"]["height"] * 0.6
	t.check("blades_in_a_plant_not_in_lockstep", br < 0.9, "mean r between blades of one plant %.2f" % br)
	t.check("ambient_sway_small", tip > 0.03 and tip < 0.3, "largest tip swing of a medium reed %.2f m" % tip)
	# Climbing and platform leaves: each leaf of a ladder has its own phase and flaps a few
	# centimetres at the tip; the stems stay rigid.
	var lb: LevelBuilder = g.balls[2].get_meta("builder")
	var ladder: StaticBody3D = null
	for n in lb.root.get_children():
		if n is StaticBody3D and (n as StaticBody3D).collision_layer == LevelBuilder.CLIMB_LAYER and n.has_meta("leaves") and (n.get_meta("leaves") as Array).size() >= 10:
			ladder = n
			break
	var phases := {}
	var ups_ok := true
	var leaf_series := []
	var st := MeshLib.leaf_surface()
	var nv := 0
	for lf in ladder.get_meta("leaves"):
		var local: Transform3D = ladder.global_transform.affine_inverse() * (lf[0] as Transform3D)
		nv = MeshLib._leaf_into(st, local, lf[1], lf[2], true, nv)
	var arrays := st.commit_to_arrays()
	var custom: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
	for i in range(0, custom.size(), 4):
		phases[snappedf(custom[i + 3], 0.0001)] = Vector3(custom[i], custom[i + 1], custom[i + 2])
	for ph in phases:
		ups_ok = ups_ok and absf((phases[ph] as Vector3).length() - 1.0) < 0.01
		var sr := []
		for k in 200:
			sr.append(Vegetation.leaf_flutter(ph, ladder.global_position, k * 0.1, Levels.LEAF_FLUTTER, 1.1))
		leaf_series.append(sr)
	var lr := 0.0
	var ln := 0
	var lpeak := 0.0
	for i in leaf_series.size():
		for v in leaf_series[i]:
			lpeak = maxf(lpeak, absf(v))
		if i > 0:
			lr += absf(_corr(leaf_series[i], leaf_series[i - 1]))
			ln += 1
	lr /= maxi(ln, 1)
	var mats_ok := true
	for bi in g.balls.size():
		var blb: LevelBuilder = g.balls[bi].get_meta("builder")
		mats_ok = mats_ok and float(blb.leaf_mat.get_shader_parameter("flutter")) > 0.0 and bool(blb.leaf_mat.get_shader_parameter("leaf_data")) \
				and (blb.stem_mat.get_shader_parameter("flutter") == null or float(blb.stem_mat.get_shader_parameter("flutter")) == 0.0)
	var n_leaves: int = (ladder.get_meta("leaves") as Array).size()
	t.check("ladder_leaves_each_move_on_their_own", phases.size() == n_leaves and ups_ok and lr < 0.4 and lpeak > 0.02 and lpeak < 0.1 and mats_ok,
			"%d leaves, %d phases; neighbour |r| %.2f; tip flap up to %.3f m; every ball's leaves flutter, stems rigid %s" % [n_leaves, phases.size(), lr, lpeak, mats_ok])
	# Disturbance adds to the ambient motion, which carries on once the wake has passed.
	var probe_base := bases[3]
	var ambient := Vegetation.ambient_bend(probe_base, centre, 0.9, 1.0, 0.13, 1.3)
	var up3 := (probe_base - centre).normalized()
	g.wake.set_process(false)
	p.set_physics_process(false)
	place_at(0, probe_base + up3 * 0.2 + MossBall.frame_at(up3, 0).x * 0.4, MossBall.frame_at(up3, 0).z)
	p.velocity = MossBall.frame_at(up3, 0).z * -4.0
	for k in 6:
		g.wake.update(1.0 / 60.0)
	var disturbed := g.wake.bend_at(b, probe_base, 0.95)
	place_at(0, b.surface_point(MossBall.dir_ll(-10, -40), 0.2), Vector3.FORWARD)
	p.velocity = Vector3.ZERO
	for k in 60 * 4:
		g.wake.update(1.0 / 60.0)
	var after := g.wake.bend_at(b, probe_base, 0.95)
	p.set_physics_process(true)
	g.wake.set_process(true)
	var src := (load("res://shaders/vegetation.gdshader") as Shader).code
	var adds := src.find("bend += wake_bend(") > 0 and src.find("VERTEX += bend * w * len") > src.find("bend += wake_bend(") and src.find("float bph") > 0
	t.check("disturbance_adds_to_ambient_then_settles_back", disturbed.length() > ambient.length() and after.length() < 0.02 and ambient.length() > 0.01 and adds,
			"ambient %.3f; wake while he passes %.3f; wake 4 s later %.3f (plants back to their own sway); shader adds both %s" % [ambient.length(), disturbed.length(), after.length(), adds])
	# Bounded: all of it in the two shaders. No vegetation node has a script; every vegetation
	# node is instanced; the leaf and root motion is a material setting.
	var scripted := 0
	var not_instanced := 0
	for bb in g.balls:
		for n in bb.find_child("Vegetation", false, false).find_children("*", "", true, false):
			if n.get_script() != null:
				scripted += 1
			if n is MeshInstance3D:
				not_instanced += 1
	t.check("ambient_motion_bounded_gpu_only", scripted == 0 and not_instanced == 0, "%d scripted vegetation nodes, %d non-instanced" % [scripted, not_instanced])


func _corr(a: Array, c: Array) -> float:
	var n := a.size()
	var ma := 0.0
	var mc := 0.0
	for i in n:
		ma += a[i]
		mc += c[i]
	ma /= n
	mc /= n
	var sab := 0.0
	var saa := 0.0
	var scc := 0.0
	for i in n:
		sab += (a[i] - ma) * (c[i] - mc)
		saa += (a[i] - ma) * (a[i] - ma)
		scc += (c[i] - mc) * (c[i] - mc)
	return sab / sqrt(maxf(saa * scc, 1e-12))


## Expansion 6: a parasite is one continuous body (no bead chain), and a defeated one does not
## float off as a rigid stick: a quick twitch or two that dies away, then a limp curve drifting
## off, its residual ripple fading.
func _test_parasite_body_and_death() -> void:
	var b := g.balls[0]
	var beads := 0
	var bodies := 0
	for par in b.parasites:
		bodies += 1 if par._body != null and par._body.mesh != null else 0
		for sgi in par._segs:
			beads += 1 if sgi.mesh != null else 0
	t.check("parasite_one_continuous_body", beads == 0 and bodies == b.parasites.size() and bodies > 0, "%d parasites, %d bodies, %d bead meshes" % [b.parasites.size(), bodies, beads])
	# (Current Hollows' far large parasite: Mossy Meadow's only large one is needed alive later by
	# the swipe-stage test.)
	b = g.balls[1]
	var large := first_alive(1, Parasite.Kind.LARGE, "far")
	p.invuln_t = 999
	place_at(1, b.surface_point(b.up_at(large.global_position + MossBall.frame_at(b.up_at(large.global_position), 0).x * 8.0), 0.2), Vector3.FORWARD)
	await t.seconds(0.5)
	large.set_physics_process(true)
	while large.is_alive():
		large.hit_cd = 0.0
		large.hit(3, large.global_position + Vector3(0.5, 0, 0), 1.0)
		await t.frames(1)
	# The twitch: sideways offset of the tail from the body's resting line, early and late in dying.
	var tw_early := 0.0
	var tw_late := 0.0
	var prev := _seg_positions(large)
	var move_early := 0.0
	for i in 30:
		await t.frames(1)
		var now := _seg_positions(large)
		var m := 0.0
		for k in now.size():
			m = maxf(m, now[k].distance_to(prev[k]))
		if large.state == "dying":
			if large.state_t < 0.2:
				tw_early = maxf(tw_early, m)
			elif large.state_t > 0.4:
				tw_late = maxf(tw_late, m)
		prev = now
	t.check("struck_parasite_twitches_then_stills", tw_early > 0.01 and tw_late < tw_early * 0.4, "per-frame twitch %.3f m at first, %.3f m after 0.4 s" % [tw_early, tw_late])
	while large.state != "drifting":
		await t.frames(1)
	# Limp: the body is curved, not a straight line; the ripple (shape change relative to the body)
	# fades over the first seconds.
	# (The bend angles between neighbouring segments: independent of the body's slow tumble.)
	var bends := func(a: Array[Vector3]) -> Array:
		var out := []
		for k in range(1, a.size() - 1):
			out.append((a[k] - a[k - 1]).angle_to(a[k + 1] - a[k]))
		return out
	var shape_change := func(a: Array[Vector3], c: Array[Vector3]) -> float:
		var ba: Array = bends.call(a)
		var bc: Array = bends.call(c)
		var d := 0.0
		for k in ba.size():
			d = maxf(d, absf(float(ba[k]) - float(bc[k])))
		return d
	await t.seconds(0.5)
	var s0 := _seg_positions(large)
	await t.frames(3)
	var early_ripple: float = shape_change.call(s0, _seg_positions(large))
	await t.seconds(2.5)
	var s1 := _seg_positions(large)
	await t.frames(3)
	var late_ripple: float = shape_change.call(s1, _seg_positions(large))
	var pts := _seg_positions(large)
	var line := (pts[pts.size() - 1] - pts[0])
	var sag := 0.0
	for q in pts:
		var r: Vector3 = q - pts[0]
		sag = maxf(sag, (r - line.normalized() * r.dot(line.normalized())).length())
	t.check("defeated_parasite_drifts_limp", sag > large.spacing * 0.5 and late_ripple < early_ripple * 0.5,
			"curve %.2f m off straight (spacing %.2f); ripple %.3f rad early, %.3f rad later" % [sag, large.spacing, early_ripple, late_ripple])
	p.invuln_t = 0.0


## Every climb leaf in the game (owner phone report, Expansion 6): [ball, body, xform, length, width].
func _all_climb_leaves() -> Array:
	var out := []
	for b in g.balls:
		var lb: LevelBuilder = b.get_meta("builder")
		for n in lb.root.get_children():
			if n is CollisionObject3D and n.has_meta("leaves"):
				for e in n.get_meta("leaves"):
					out.append([b, n, e[0], e[1], e[2]])
		for f in b.flex_leaves:
			for e in f.get_meta("leaves", []):
				out.append([b, f, e[0], e[1], e[2]])
	return out


## Expansion 6, owner phone report (spiral leaves): every climb leaf, checked geometrically:
## - its collision is the drawn leaf: rays onto the drawn upper surface hit it within 6 cm, and
##   nothing solid lies just beyond its drawn edge;
## - it grows from its stem: its stalk's root is inside the stem;
## - it is broad: around its landing point a 0.7 m circle (the axolotl turning) is all leaf;
## - consecutive leaves of a spiral are distinct: a clear angular gap between them.
func _test_leaf_geometry() -> void:
	var space := g.get_world_3d().direct_space_state
	var leaves := _all_climb_leaves()
	var mismatch: Array[String] = []
	var beside: Array[String] = []
	var floating: Array[String] = []
	var narrow: Array[String] = []
	var worst_dev := 0.0
	for e in leaves:
		var b: MossBall = e[0]
		var body: CollisionObject3D = e[1]
		var xf: Transform3D = e[2]
		var len: float = e[3]
		var w: float = e[4]
		var up := xf.basis.y.normalized()
		for tt in [0.15, 0.3, 0.5, 0.7, 0.85]:
			var hw := w * 0.5 * MeshLib.leaf_profile(tt)
			# (Just off the midrib: a ray exactly on the collision's crest can graze it.)
			for s in [-0.8, -0.4, 0.04, 0.4, 0.8]:
				var pt := xf * Vector3(s * hw, MeshLib.leaf_top_y(tt, s, w), -tt * len)
				var q := PhysicsRayQueryParameters3D.create(pt + up * 0.25, pt - up * 0.25, body.collision_layer)
				var hit := space.intersect_ray(q)
				if hit.is_empty() or hit["collider"] != body:
					mismatch.append("b%d %s t%.2f s%.2f: no collision under the drawn leaf (hit %s)" % [b.index + 1, body.name, tt, s, "nothing" if hit.is_empty() else str(hit["collider"])])
				else:
					worst_dev = maxf(worst_dev, (hit.position as Vector3).distance_to(pt))
					if (hit.position as Vector3).distance_to(pt) > 0.06:
						mismatch.append("b%d t%.2f s%.1f: %.2f m off the drawn surface" % [b.index + 1, tt, s, (hit.position as Vector3).distance_to(pt)])
			for s in [-1.2, 1.2]:
				var pt := xf * Vector3(s * hw, MeshLib.leaf_top_y(tt, 1.0, w), -tt * len)
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(pt + up * 0.25, pt - up * 0.3, body.collision_layer))
				if not hit.is_empty() and hit["collider"] == body:
					beside.append("b%d t%.2f: solid beyond the drawn edge" % [b.index + 1, tt])
		# Its stalk's root, inside the stem it grows from (flex leaves are on their own thin stem).
		var rooted := false
		for back in [0.45]:
			var pq := PhysicsPointQueryParameters3D.new()
			pq.position = xf * Vector3(0, 0.3, back)
			pq.collision_mask = 1
			rooted = rooted or not space.intersect_point(pq, 4).is_empty()
		if not rooted:
			floating.append("b%d leaf at h %.1f: stalk root not in a stem" % [b.index + 1, b.altitude(xf.origin)])
		# Room to turn round at the landing point.
		var land := Levels.leaf_mid(xf, minf(1.4, len * 0.5), 0.0).origin
		for k in 12:
			var a := TAU * k / 12.0
			var off := (xf.basis.x.normalized() * cos(a) + xf.basis.z.normalized() * sin(a)) * 0.7
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(land + off + up * 0.4, land + off - up * 0.5, body.collision_layer))
			if hit.is_empty() or hit["collider"] != body:
				narrow.append("b%d leaf at h %.1f (%.1f x %.1f m): edge within 0.7 m of the landing point" % [b.index + 1, b.altitude(xf.origin), len, w])
				break
	for x in mismatch.slice(0, 12) + beside.slice(0, 12) + floating.slice(0, 12) + narrow.slice(0, 12):
		t.log_line(x)
	t.check("leaf_collision_is_the_drawn_leaf", mismatch.is_empty() and beside.is_empty() and leaves.size() > 950,
			"%d climb leaves; worst gap between drawn surface and collision %.3f m; %d off, %d solid beyond an edge" % [leaves.size(), worst_dev, mismatch.size(), beside.size()])
	t.check("leaves_grow_from_their_stems", floating.is_empty(), "%d leaves whose stalk does not reach a stem" % floating.size())
	t.check("leaves_have_room_to_turn", narrow.is_empty(), "%d leaves with less than a 0.7 m circle of footing at the landing point" % narrow.size())
	# Spiral staging: the plan-view angular gap between consecutive leaves round each stem.
	var min_gap := INF
	var n_pairs := 0
	for b in g.balls:
		for n in (b.get_meta("builder") as LevelBuilder).root.get_children():
			if not (n is StaticBody3D and n.has_meta("leaves") and (n as StaticBody3D).collision_layer == LevelBuilder.CLIMB_LAYER):
				continue
			var ls: Array = n.get_meta("leaves")
			for i in ls.size() - 1:
				var gap := _leaf_angle_gap(b, ls[i], ls[i + 1])
				if gap < 12.0:
					t.log_line("b%d ladder leaves %d-%d at h %.1f: %.1f degrees apart (%s, %s)" % [b.index + 1, i, i + 1, b.altitude((ls[i][0] as Transform3D).origin), gap, str(ls[i].slice(1)), str(ls[i + 1].slice(1))])
				min_gap = minf(min_gap, gap)
				n_pairs += 1
	for sp in _spirals():
		for i in (sp[1] as Array).size() - 1:
			var gap := _leaf_angle_gap(sp[0], sp[1][i], sp[1][i + 1])
			if gap < 12.0:
				t.log_line("b%d spiral leaves %d-%d: %.1f degrees apart" % [sp[0].index + 1, i, i + 1, gap])
			min_gap = minf(min_gap, gap)
			n_pairs += 1
	t.check("spiral_leaves_distinct", min_gap >= 12.0 and n_pairs > 900, "%d consecutive pairs; smallest clear angle between neighbours %.1f degrees" % [n_pairs, min_gap])


## The two spirals built from single leaves (Giant Stems canopy, Canopy Spire): [ball, [[xf, len, w], ...]].
func _spirals() -> Array:
	var out := []
	var b2 := g.balls[2]
	for h in (b2.get_meta("builder") as LevelBuilder).bot_hints:
		if h.has("canopy"):
			var ls := []
			for xf in h["spiral"]:
				ls.append([xf, 3.0, Levels.SPIRAL_LEAF_W])
			out.append([b2, ls])
	# Canopy Spire's spirals (the spire and, since the world expansion, the Sky Spire): each one's
	# leaves, grouped by the stem they grow round.
	var b5 := g.balls[5]
	var groups := []
	for n in (b5.get_meta("builder") as LevelBuilder).root.get_children():
		if n is StaticBody3D and n.has_meta("leaves") and (n as StaticBody3D).collision_layer == 2:
			var e: Array = n.get_meta("leaves")[0]
			if not is_equal_approx(e[1], 3.0):
				continue
			var d := b5.up_at((e[0] as Transform3D).origin)
			var placed := false
			for gr in groups:
				if d.angle_to(gr[0]) * b5.radius < 6.0:
					gr[1].append(e)
					placed = true
					break
			if not placed:
				groups.append([d, [e]])
	for gr in groups:
		var sp: Array = gr[1]
		sp.sort_custom(func(a, c): return b5.altitude((a[0] as Transform3D).origin) < b5.altitude((c[0] as Transform3D).origin))
		out.append([b5, sp])
	return out


## Clear angle (degrees, in plan round the stem the leaves grow from) between two leaves' outlines.
func _leaf_angle_gap(b: MossBall, la: Array, lb_: Array) -> float:
	var xa: Transform3D = la[0]
	var xb: Transform3D = lb_[0]
	var up := b.up_at(xa.origin)
	# The stem axis: back along each leaf from its base, where the two base directions meet.
	var centre := (xa.origin + xa.basis.z.normalized() * 0.6 + xb.origin + xb.basis.z.normalized() * 0.6) * 0.5
	var spans := []
	for e in [la, lb_]:
		var xf: Transform3D = e[0]
		var len: float = e[1]
		var w: float = e[2]
		var mid := -xf.basis.z
		mid -= up * mid.dot(up)
		var half := 0.0
		for k in 11:
			var tt := 0.1 + 0.08 * k
			var pt := xf * Vector3(w * 0.5 * MeshLib.leaf_profile(tt), 0, -tt * len)
			var v := pt - centre
			v -= up * v.dot(up)
			half = maxf(half, rad_to_deg(absf(mid.signed_angle_to(v, up))))
		spans.append([mid, half])
	var between := rad_to_deg((spans[0][0] as Vector3).angle_to(spans[1][0]))
	return between - float(spans[0][1]) - float(spans[1][1])


## Expansion 6, owner phone report: on the leaves themselves, as a player does it. On every leaf of
## both leaf spirals and of a spread of jungle ladders: land in the middle and near the edge,
## turn to aim in four directions (never walked off), jump straight up beside the stem (not
## blocked, not wedged), pass underneath the lowest leaf (never touched), and climb back down
## to the ground (never wedged between leaf and stem). Then two ladders climbed twice over.
func _test_leaf_footing() -> void:
	p.invuln_t = 999
	var sets := []
	for sp in _spirals():
		sets.append(sp)
	var b2 := g.balls[2]
	var k := 0
	for n in (b2.get_meta("builder") as LevelBuilder).root.get_children():
		if n is StaticBody3D and (n as StaticBody3D).collision_layer == LevelBuilder.CLIMB_LAYER and n.has_meta("leaves"):
			if k % 9 == 0:
				sets.append([b2, n.get_meta("leaves"), n])
			k += 1
	var tried := 0
	var off_turn: Array[String] = []
	var off_edge: Array[String] = []
	var blocked: Array[String] = []
	for st in sets:
		var b: MossBall = st[0]
		for e in st[1]:
			var xf: Transform3D = e[0]
			var len: float = e[1]
			var w: float = e[2]
			var land := Levels.leaf_mid(xf, minf(1.4, len * 0.5), 0.0).origin
			var out := -xf.basis.z
			tried += 1
			place_at(b.index, land + xf.basis.y * 0.3, out)
			await wait_grounded()
			var h0 := height()
			# Aim: swing round to each direction in turn, pushing the stick until he faces it (as a
			# player lines up a jump), then letting go.
			for a in [PI * 0.5, PI, -PI * 0.5, 0.0]:
				var aim := out.rotated(xf.basis.y.normalized(), a)
				for fr in 30:
					stick_toward(aim)
					await t.frames(1)
					var fl := aim - p.up * aim.dot(p.up)
					if p.facing.dot(fl.normalized()) > cos(deg_to_rad(20.0)):
						break
				p.bot_input = Vector2.ZERO
				await t.frames(10)
			await t.frames(20)
			if not p.grounded or absf(height() - h0) > 0.2:
				off_turn.append("b%d leaf h %.1f: after turning at h %.2f (was %.2f)" % [b.index + 1, h0, height(), h0])
			# Near the edge.
			var edge := xf * Vector3(w * 0.5 * MeshLib.leaf_profile(0.5) * 0.7, MeshLib.leaf_top_y(0.5, 0.7, w), -0.5 * len)
			place_at(b.index, edge + xf.basis.y * 0.3, out)
			await wait_grounded()
			if absf(height() - b.altitude(edge)) > 0.2:
				off_edge.append("b%d leaf h %.1f: edge landing ended at h %.2f" % [b.index + 1, b.altitude(edge), height()])
			# Straight up beside the stem.
			var near := Levels.leaf_mid(xf, len * 0.16, 0.0).origin
			place_at(b.index, near + xf.basis.y * 0.3, out)
			await wait_grounded()
			var hs := height()
			var peak := hs
			await press("jump")
			for i in 90:
				await t.frames(1)
				peak = maxf(peak, height())
				if p.grounded and i > 10:
					break
			var settled := await wait_grounded(3.0)
			if peak - hs < 1.2 or not settled:
				blocked.append("b%d leaf h %.1f: jump by the stem rose %.2f m, landed %s" % [b.index + 1, hs, peak - hs, settled])
	t.check("turning_on_a_leaf_keeps_footing", off_turn.is_empty() and tried > 140, "%d leaves; %s" % [tried, str(off_turn.slice(0, 6))])
	t.check("edge_landings_hold", off_edge.is_empty(), str(off_edge.slice(0, 6)))
	t.check("jump_beside_the_stem_clear", blocked.is_empty(), str(blocked.slice(0, 6)))
	# Underneath the lowest leaf of each sampled ladder, and back down from its top.
	var touched: Array[String] = []
	var stuck: Array[String] = []
	for st in sets:
		if st.size() < 3:
			continue
		var b: MossBall = st[0]
		var body: CollisionObject3D = st[2]
		var ls: Array = st[1]
		var first: Transform3D = ls[0][0]
		var tip := Levels.leaf_mid(first, float(ls[0][1]) + 0.6, 0.0).origin
		var ground := b.surface_point(b.up_at(tip), 0.15)
		place_at(b.index, ground, first.basis.z)
		await wait_grounded()
		for i in 60:
			stick_toward(first.basis.z)
			await t.frames(1)
			for c in p.get_slide_collision_count():
				if p.get_slide_collision(c).get_collider() == body:
					touched.append("b%d %s" % [b.index + 1, body.name])
		p.bot_input = Vector2.ZERO
		# Down from the top leaf: walk off outward, and keep walking out until on the ground.
		var top: Transform3D = ls[ls.size() - 1][0]
		place_at(b.index, Levels.leaf_mid(top, 1.3, 0.0).origin + top.basis.y * 0.3, -top.basis.z)
		await wait_grounded()
		var still := 0.0
		var ok := false
		for i in 60 * 14:
			var outward := p.global_position - body.global_position
			stick_toward(outward)
			await t.frames(1)
			if height() < 0.5 and p.grounded:
				ok = true
				break
			still = still + 1.0 / 60.0 if (not p.grounded and p.velocity.length() < 0.3) else 0.0
			if still > 1.0:
				break
		p.bot_input = Vector2.ZERO
		if not ok:
			stuck.append("b%d %s: descent ended at h %.2f (%s)" % [b.index + 1, body.name, height(), "wedged" if still > 1.0 else "timed out"])
	t.check("underneath_leaves_clear", touched.is_empty(), str(touched.slice(0, 6)))
	t.check("climb_down_never_wedges", stuck.is_empty(), str(stuck.slice(0, 6)))
	# Repeated traversal: two ladders, up, down (above), and up again.
	var again := []
	var kk := 0
	for h in (b2.get_meta("builder") as LevelBuilder).bot_hints:
		if h.has("route") and str(h["route"]).begins_with("jungle") and kk < 2:
			kk += 1
			var r1: int = await _climb(b2, h)
			var r2: int = await _climb(b2, h)
			again.append("%s %d,%d/%d" % [h["route"], r1, r2, (h["tops"] as Array).size()])
			if r1 < (h["tops"] as Array).size() or r2 < (h["tops"] as Array).size():
				again.append("SHORT")
	t.check("ladders_climbed_twice", not "SHORT" in again and kk == 2, ", ".join(again))
	p.invuln_t = 0.0


## Climbs `h` (a route hint on `b`) from its start with plain touch jumps; returns how many of its
## steps were reached in order.
func _climb(b: MossBall, h: Dictionary) -> int:
	var tops: Array = h["tops"]
	var st: Vector3 = h["start"]
	place_at(b.index, st + b.up_at(st) * 0.2, ((tops[0] as Vector3) - st))
	g.audio.set_ball(b.index, false)
	await wait_grounded()
	var reached := 0
	var k := 0
	while k < tops.size():
		var target: Vector3 = tops[k]
		var flat := target - p.global_position
		flat -= p.up * flat.dot(p.up)
		if (target - p.global_position).dot(p.up) < 0.3 and flat.length() < 1.2:
			reached = k + 1
			k += 1
			continue
		var upward := (target - p.global_position).dot(p.up) > 0.3
		if upward:
			# Take off from outside the next leaf's footprint (as a player does): step back
			# until about 2 m out, then jump toward it.
			for i in 40:
				flat = target - p.global_position
				flat -= p.up * flat.dot(p.up)
				if flat.length() >= 1.9:
					break
				stick_toward(-flat)
				await t.frames(1)
		for i in 6:
			stick_toward(target - p.global_position)
			await t.frames(1)
		if upward or flat.length() > 2.5:
			await press("jump")
		for i in 110:
			var off := target - p.global_position
			off -= p.up * off.dot(p.up)
			if off.length() > 0.3:
				stick_toward(off)
			else:
				p.bot_input = Vector2.ZERO
			await t.frames(1)
			if p.grounded and i > 12 and off.length() < 0.6:
				break
		p.bot_input = Vector2.ZERO
		await wait_grounded()
		# On this step, or already on a later one (a jump that carried further up the climb).
		var on := -1
		for j in range(k, tops.size()):
			var tj: Vector3 = tops[j]
			if absf(b.altitude(p.global_position) - b.altitude(tj)) <= 0.45 and p.global_position.distance_to(tj) <= 1.9:
				on = j
		if on < 0:
			t.log_line("ball %d %s: stopped before step %d of %d (at h %.2f, step h %.2f, %.2f m away)" % [b.index + 1, h["route"], k + 1, tops.size(),
					b.altitude(p.global_position), b.altitude(target), p.global_position.distance_to(target)])
			break
		reached = on + 1
		k = on + 1
	return reached


func _test_upgrades() -> void:
	p.max_health = 3
	p.health = 3
	# The original caves' heart upgrades (balls 1-3): each adds a gill.
	var got: Array[String] = []
	for b in g.balls:
		for u in b.upgrades:
			if u.kind == "health":
				var was := p.max_health
				place_at(b.index, u._leaf.global_position - b.up_at(u._leaf.global_position) * 0.3, MossBall.frame_at(b.up_at(u.global_position), 0).z)
				await t.seconds(0.4)
				got.append("ball %d %s (taken %s, state %s)" % [b.index + 1, "+1" if p.max_health > was else "nothing", u.taken, g.state])
	t.check("three_cave_upgrades_to_six", p.max_health == 6 and p.health == 6, "max %d; %s" % [p.max_health, ", ".join(got)])
	# The new grottoes' pearls: each refills health and adds no gill.
	var pearls := 0
	var ok := true
	for b in g.balls:
		for u in b.upgrades:
			if u.kind == "pearl":
				p.health = 2
				place_at(b.index, u._leaf.global_position - b.up_at(u._leaf.global_position) * 0.3, MossBall.frame_at(b.up_at(u.global_position), 0).z)
				await t.seconds(0.4)
				ok = ok and u.taken and p.health == p.max_health and p.max_health == 6
				pearls += 1
	t.check("pearls_refill_health_not_max", pearls == 5 and ok, "%d pearls, max %d" % [pearls, p.max_health])


func _test_ui() -> void:
	# Expansion 6 performance: a phone that cannot hold its frame rate loses the ceiling light's
	# shadows first; the best level keeps them, casting only from the selected casters.
	var lvl: int = g.quality.level
	g.quality.force_level(0)
	var on0: bool = g.aquarium.sun.shadow_enabled and g.aquarium.sun.shadow_caster_mask == MossBall.SHADOW_CASTER_LAYER
	g.quality.force_level(1)
	var off1: bool = not g.aquarium.sun.shadow_enabled
	g.quality.force_level(lvl)
	t.check("shadows_first_to_scale_down", on0 and off1, "level 0 shadows %s, level 1 shadows off %s" % [on0, off1])
	g.pause_menu.open()
	await t.frames(2)
	t.check("pause_menu_pauses", g.get_tree().paused and g.pause_menu.visible, "")
	g.pause_menu.close()
	await t.frames(2)
	t.check("pause_menu_resumes", not g.get_tree().paused, "")
	Settings.reduced_hud = true
	Settings.save()
	await t.frames(1)
	t.check("reduced_hud_fades_controls", is_equal_approx(g.hud._target_alpha, 0.12), "%.2f" % g.hud._target_alpha)
	Settings.reduced_hud = false
	Settings.save()
	var jb := InputEventJoypadButton.new()
	jb.button_index = JOY_BUTTON_Y
	jb.pressed = true
	Input.parse_input_event(jb)
	await t.frames(2)
	t.check("controller_input_hides_touch_controls", Settings.input_mode == Settings.InputMode.PAD and g.hud._target_alpha == 0.0, "")
	var tt := InputEventScreenTouch.new()
	tt.index = 5
	tt.position = Vector2(900, 200)
	tt.pressed = true
	Input.parse_input_event(tt)
	await t.frames(1)
	tt = tt.duplicate()
	tt.pressed = false
	Input.parse_input_event(tt)
	await t.frames(2)
	t.check("touch_restores_controls", Settings.input_mode == Settings.InputMode.TOUCH and g.hud._target_alpha == 1.0,
			"mode %d alpha %.2f cine %s vis %s" % [Settings.input_mode, g.hud._target_alpha, g.hud._cinematic, g.hud._controls_visible])
	Settings.haptics = false
	Settings.haptic("heavy")
	Settings.haptics = true
	t.check("haptics_toggle", true, "")


func _test_all_clear() -> void:
	for b in g.balls:
		place(b.index, -30, 30, 0.2, 0)
		p.invuln_t = 999
		await t.seconds(0.3)
		for k in 3:
			for par in b.parasites:
				if par.is_alive():
					par.hit_cd = 0.0
					par.hit(par.hp, par.global_position)
			for m in b.motes:
				if m.is_available():
					m.capture()
			await t.seconds(1.2)
	var done := true
	for b in g.balls:
		done = done and b.completed and is_equal_approx(b.restoration, 1.0)
	var rs := PackedStringArray()
	for b in g.balls:
		rs.append("%.2f%s" % [b.restoration, "" if b.completed else "*"])
	t.check("all_three_balls_reach_100", done, " ".join(rs))
	# Finishing: the run's time froze on the frame the last ball was restored.
	var fin: float = g.clock.finish_s
	var rec: Dictionary = g.run_save.run()["finish"]
	t.check("run_finished_when_all_balls_restored", g.clock.is_finished() and fin > 0.0 and g.run_save.earned().has(Completion.ENDING_ID)
			and float(rec.get("finish_s", -1.0)) == fin and g.run_save.records()["best_finish_s"] == fin, "finish %s, %.2f%%" % [RunClock.format(fin), g.completion_percent()])
	var reached := -1.0
	var shown := -1.0
	var el := 0.0
	while el < 200.0:
		await t.frames(30)
		el += 0.5
		if reached < 0.0 and g.g_disp >= 0.999:
			reached = el
		if g.hud.all_clear_label.modulate.a > 0.05:
			shown = el
			break
	t.check("all_clear_after_quiet_period", reached >= 0.0 and shown - reached >= 11.0, "g reached 1 at %.1fs, ALL CLEAR at %.1fs" % [reached, shown])
	await t.seconds(10.0)
	t.check("free_roam_after_all_clear", p.controls_enabled and g.state == "play" and g.hud.all_clear_label.modulate.a < 0.05, "")
	t.check("finish_time_frozen_after_more_play", g.clock.finish_s == fin and g.clock.shown_s() == fin and g.clock.play_s > fin + 20.0
			and g.hud.finish_label.text.begins_with("Finished in " + RunClock.format(fin)), "%s, play %.1f s" % [g.hud.finish_label.text, g.clock.play_s])
	var on_disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(g.run_save.path))
	# (Through JSON the time can come back a last binary digit different: agree to a microsecond;
	# the timer shows centiseconds.)
	t.check("finish_saved", on_disk["run"]["clock"]["state"] == "finished" and absf(float(on_disk["run"]["clock"]["finish_s"]) - fin) < 1e-6,
			"on disk: state %s, finish %s; in play: finish %s; last save %s, read only %s, path %s" % [on_disk["run"]["clock"]["state"],
			str(on_disk["run"]["clock"]["finish_s"]), str(fin), g.run_save.last_save_result, g.run_save.read_only, g.run_save.path])
	# (Expansion 6: clear water keeps a little haze, 0.007, so the far glass and room recede.)
	t.check("aquarium_fully_clean", is_equal_approx(g.aquarium.clean, 1.0) and g.env.fog_density < 0.0075, "fog %.4f" % g.env.fog_density)


# --- Treasure Hunt (docs/TREASURE_HUNT.md) ---------------------------------------------------
# These run after _test_all_clear: every world restored through play (every gate open), as in
# the real postgame. The run is then brought to exactly 100% the way a finished save would be.

func _make_complete() -> void:
	for id in g.completion.order:
		if not g.run_save.earned().has(id):
			g.run_save.earned()[id] = 0.0


func _treasure_reset() -> void:
	g.run_save.run()["treasure"] = {}
	g.treasure.refresh()


## Unlock: below 100% nothing (no button anywhere); at 100% the title and the pause menu offer it;
## a save from before this feature (no "treasure" key at all) that is at 100% qualifies unchanged.
func _test_treasure_unlock() -> void:
	var earned0 := g.run_save.earned().duplicate()
	var pct_before := g.completion_percent()
	var tp: TreasurePlay = g.treasure
	var below := not tp.eligible() and pct_before < 100.0
	g.title.show_title()
	var title_hidden: bool = not g.title._treasure.visible
	g.title.hide_title()
	g.pause_menu.open()
	await t.frames(2)
	var pause_hidden: bool = not g.pause_menu._treasure.visible
	g.pause_menu.close()
	t.check("treasure_locked_below_100", below and title_hidden and pause_hidden, "%.2f%%, title button %s, pause row %s" % [pct_before, not title_hidden, not pause_hidden])
	_make_complete()
	var at100 := tp.eligible() and is_equal_approx(g.completion_percent(), 100.0)
	g.title.show_title()
	var title_shown: bool = g.title._treasure.visible
	g.title.hide_title()
	g.pause_menu.open()
	await t.frames(2)
	var pause_shown: bool = g.pause_menu._treasure.visible and g.pause_menu._treasure.text != ""
	g.pause_menu.close()
	t.check("treasure_open_at_100", at100 and title_shown and pause_shown, "")
	# An old save: the same finished run, written before Treasure Hunt existed.
	var old: Dictionary = g.run_save.data.duplicate(true)
	(old["run"] as Dictionary).erase("treasure")
	var migrated := RunSave.migrate(old)
	var c := Completion.new()
	var old_pct: float = g.completion.percent(migrated["run"]["earned"])
	var st := TreasureHunt.state_of(migrated["run"])
	t.check("treasure_old_100_save_qualifies", migrated["run"].has("treasure") and TreasureHunt.eligible(old_pct) and not TreasureHunt.has_hunt(st)
			and migrated["run"]["earned"] == g.run_save.earned(), "%.2f%%" % old_pct)
	t.check("treasure_no_completion_change", Completion.CATALOG_VERSION == 4 and g.completion.size() == 348 and not g.completion.order.any(func(id): return "treasure" in id),
			"catalog v%d, %d ids" % [Completion.CATALOG_VERSION, g.completion.size()])


## Generation: 14 objects, all different, two per world, interleaved; the same seed gives the same
## hunt, a new seed a new one; every spot valid; sizes 100% then 50% for good.
func _test_treasure_generation() -> void:
	var a := TreasureHunt.generate(424242, 1.0, g.balls)
	var b2 := TreasureHunt.generate(424242, 1.0, g.balls)
	var kinds := {}
	var per := {}
	var consecutive := 0
	for i in a.size():
		kinds[a[i]["kind"]] = true
		per[a[i]["world"]] = int(per.get(a[i]["world"], 0)) + 1
		if i > 0 and a[i]["world"] == a[i - 1]["world"]:
			consecutive += 1
	var world_by_world := true
	for i in range(1, a.size()):
		if int(a[i]["world"]) < int(a[i - 1]["world"]):
			world_by_world = false
	t.check("treasure_14_all_kinds_two_per_world", a.size() == 14 and kinds.size() == 14 and per.size() == 7 and per.values().all(func(n): return n == 2),
			"%d targets, %d kinds, per world %s" % [a.size(), kinds.size(), str(per)])
	t.check("treasure_order_interleaved", consecutive == 0 and not world_by_world, "worlds %s" % str(a.map(func(x): return x["world"] + 1)))
	t.check("treasure_same_seed_same_hunt", a == b2, "")
	var c2 := TreasureHunt.generate(99, 1.0, g.balls)
	t.check("treasure_new_seed_new_hunt", c2.map(func(x): return x["kind"]) != a.map(func(x): return x["kind"])
			and c2.map(func(x): return x["pos"]) != a.map(func(x): return x["pos"]), "")
	# Every spot of 12 hunts (both sizes): in its world, on the ground, clear, not in a ravine.
	var bad := []
	var worst_alt := 0.0
	var kinds_seen := {}
	var first_special := []
	var later_special := []
	for k in 12:
		var hunt := TreasureHunt.generate(1000 + k * 7919, 1.0 if k % 2 == 0 else 0.5, g.balls)
		var hp := {}
		var special := 0
		for tg in hunt:
			var w: int = tg["world"]
			hp[w] = int(hp.get(w, 0)) + 1
			var bb: MossBall = g.balls[w]
			var pos := TreasureHunt.target_pos(tg)
			kinds_seen[tg["spot"]] = int(kinds_seen.get(tg["spot"], 0)) + 1
			if tg["spot"] in ["ground", "grass"]:
				worst_alt = maxf(worst_alt, absf(bb.altitude(pos)))
			else:
				special += 1
				# Up high or in a cave: resting on something, never inside the ground.
				if bb.altitude(pos) < -0.3:
					bad.append("%s buried" % tg["spot"])
			var nearest := -1
			var nd := INF
			for ob in g.balls:
				var dd: float = ob.altitude(pos)
				if absf(dd) < nd:
					nd = absf(dd)
					nearest = ob.index
			if nearest != w or not TreasureHunt.target_ok(bb, tg):
				bad.append("%s %s w%d" % [tg["kind"], tg["spot"], w + 1])
		for i in range(1, hunt.size()):
			if hunt[i]["world"] == hunt[i - 1]["world"]:
				bad.append("consecutive")
		if not hp.values().all(func(n): return n == 2):
			bad.append("per-world")
		(first_special if k % 2 == 0 else later_special).append(special)
	# Owner: ground, tall grass, high on a leaf, on a rock, in a cave; the first hunt mostly on
	# the ground and grass with a few of the others, later hunts drawing on all of them.
	t.check("treasure_spot_kinds_mixed", TreasureHunt.SPOT_KINDS.all(func(sk): return kinds_seen.has(sk))
			and first_special.all(func(n): return n >= 1 and n <= 4) and later_special.all(func(n): return n >= 6),
			"kinds %s; first hunts' high/cave/rock %s, later %s" % [str(kinds_seen), str(first_special), str(later_special)])
	t.check("treasure_spots_valid", bad.is_empty() and worst_alt < 0.5, "12 hunts, 168 spots: %d bad %s; worst %.2f m off the ground" % [bad.size(), str(bad.slice(0, 5)), worst_alt])
	# The global generator does not move when a hunt is generated.
	seed(777)
	var r0 := [randi(), randi()]
	seed(777)
	TreasureHunt.generate(5, 1.0, g.balls)
	t.check("treasure_leaves_gameplay_rng_alone", [randi(), randi()] == r0, "")
	# Sizes: first hunt 1, every later hunt 0.5 (never halved again).
	t.check("treasure_sizes_first_then_half", TreasureHunt.scale_for_hunt(1) == 1.0 and TreasureHunt.scale_for_hunt(2) == 0.5
			and TreasureHunt.scale_for_hunt(3) == 0.5 and TreasureHunt.scale_for_hunt(9) == 0.5, "")


## A spot a couple of metres from the target that he can walk from (for the pickup tests).
func _approach(b: MossBall, target: Vector3, skip := 0) -> Vector3:
	var up := b.up_at(target)
	var fr := MossBall.frame_at(up, 0.0)
	# Up on a leaf or rock: the spot beside it the game promised when it chose the place.
	if b.altitude(target) > 0.5:
		var tg: Dictionary = TreasureHunt.current(g.treasure.st())
		if str(tg.get("spot", "")) in ["leaf", "rock"]:
			var ap := TreasureHunt.approach_point(b, TreasureHunt.target_pos(tg), float(tg.get("scale", 1.0)))
			if ap != Vector3.INF:
				return ap
	# In a cave (or anywhere else): a spot on the same surface beside it.
	if b.altitude(target) > 0.5 or not TreasureHunt.spot_ok(b, target, 0.3):
		var space := g.get_world_3d().direct_space_state
		for dist in [1.6, 2.1, 1.2]:
			for k in 12:
				var o: Vector3 = target + fr.z.rotated(up, TAU * k / 12.0) * dist
				var h := space.intersect_ray(PhysicsRayQueryParameters3D.create(o + up * 1.0, o - up * 1.2, TreasureHunt.SOLID_MASK))
				if h.is_empty() or absf(((h["position"] as Vector3) - target).dot(up)) > 0.35 or (h["normal"] as Vector3).dot(up) < 0.7:
					continue
				var q: Vector3 = h["position"]
				if space.intersect_ray(PhysicsRayQueryParameters3D.create(q + up * 0.45, target + up * 0.45, TreasureHunt.SOLID_MASK)).is_empty():
					return q
	for dist in [2.3, 3.0, 1.8]:
		for k in 12:
			var d := fr.z.rotated(up, TAU * k / 12.0)
			var q := b.surface_point((target + d * dist - b.global_position).normalized())
			# (Level with it, as a player walking up would be: not down in a dip below it.)
			if absf((q - target).dot(up)) < 0.6 and TreasureHunt.spot_ok(b, q, 0.3) and TreasureHunt.path_ok(b, q, target):
				if skip == 0:
					return q
				skip -= 1
	return Vector3.INF


## Lunges at the current object from a walkable spot near it; returns true if it was collected.
func _lunge_at_current(tp: TreasurePlay) -> bool:
	var st: Dictionary = tp.st()
	var tg: Dictionary = TreasureHunt.current(st)
	var b: MossBall = g.balls[int(tg["world"])]
	var target: Vector3 = tp.node.global_position if tp.node else TreasureHunt.target_pos(tg)
	var from := _approach(b, target)
	if from == Vector3.INF:
		return false
	var dir := target - from
	place_at(b.index, from + b.up_at(from) * 0.1, dir - b.up_at(from) * dir.dot(b.up_at(from)))
	await t.seconds(0.4)
	var idx0 := int(st["index"])
	tp.near_miss = INF
	for tries in 3:
		if tries > 0:
			# (As a player would after a miss: step round it and try from another side.)
			var side := target - p.global_position
			side -= p.up * side.dot(p.up)
			var around := target - side.normalized().rotated(p.up, 1.75 * (1.0 if tries == 1 else -1.0)) * 1.8
			for k in 60:
				var fl: Vector3 = around - p.global_position
				fl -= p.up * fl.dot(p.up)
				if fl.length() < 0.4:
					break
				stick_toward(fl.normalized())
				await t.frames(2)
		# Walk up close, then lunge (as a player would).
		for k in 90:
			var flat: Vector3 = target - p.global_position
			flat -= p.up * flat.dot(p.up)
			if flat.length() < 1.6 + tp.reach() * 0.5:
				break
			stick_toward(flat.normalized())
			await t.frames(2)
		p.bot_input = Vector2.ZERO
		var before := p.global_position
		await press("lunge")
		await t.seconds(0.6)
		# (Wedged where nothing moves him: start again from the next open spot beside it.)
		if p.global_position.distance_to(before) < 0.05 and int(st["index"]) == idx0:
			var alt := _approach(b, target, tries + 1)
			if alt != Vector3.INF:
				var d2 := target - alt
				place_at(b.index, alt + b.up_at(alt) * 0.1, d2 - b.up_at(alt) * d2.dot(b.up_at(alt)))
				await t.seconds(0.4)
		if Settings.test_args.get("trace_lunge", "0") == "1":
			t.log_line("LUNGE try %d: state %s controls %s floor %s moved %.2f m, now %.2f m from it, near miss %.2f" % [tries, p.state,
					p.controls_enabled, p.is_on_floor(), p.global_position.distance_to(before), p.global_position.distance_to(target), tp.near_miss])
		if int(st["index"]) > idx0:
			return true
	return false


## Stress (run by name only, after _test_all_clear): --hunts=N seeded hunts from --seed0, every
## object attempted by a real approach and lunge; each miss is logged (seed, kind, spot, world,
## Diagnostic (by name only): Gill running a curve for 10 s on ball 1; the engine's own process and
## physics time per frame (the locomotion's per-frame cost, like for like between builds).
func _phase_cpu_probe() -> void:
	var b := g.balls[0]
	var spot := _quiet_spot(0)
	var up := b.up_at(spot)
	place_at(0, spot + up * 0.2, -MossBall.frame_at(up, 0.0).z)
	await t.seconds(1.0)
	p.use_bot_input = true
	var proc := 0.0
	var phys := 0.0
	var n := 0
	for i in 600:
		p.bot_input = Vector2(sin(i * 0.02), cos(i * 0.02)).normalized()
		await t.frames(1)
		if i >= 60:
			proc += Performance.get_monitor(Performance.TIME_PROCESS)
			phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
			n += 1
	p.bot_input = Vector2.ZERO
	t.log_line("CPUPROBE process %.3f ms physics %.3f ms per frame over %d frames" % [proc / n * 1000.0, phys / n * 1000.0, n])
	# His own per-frame work, timed directly (medians, so other load on the machine barely counts).
	var mt: Array[float] = []
	var pt: Array[float] = []
	p.bot_input = Vector2(1, 0)
	for i in 400:
		var t0 := Time.get_ticks_usec()
		p.model._process(1.0 / 60.0)
		var t1 := Time.get_ticks_usec()
		p._physics_process(1.0 / 60.0)
		var t2 := Time.get_ticks_usec()
		mt.append(float(t1 - t0))
		pt.append(float(t2 - t1))
		if i % 20 == 0:
			await t.frames(1)
	p.bot_input = Vector2.ZERO
	mt.sort()
	pt.sort()
	t.log_line("CPUPROBE2 model median %.0f us p90 %.0f us | body median %.0f us p90 %.0f us" % [mt[200], mt[360], pt[200], pt[360]])
	# Pressed against a tall face (the controller reads the ground ahead while blocked).
	var up2 := b.up_at(p.global_position)
	var fwd2 := -MossBall.frame_at(up2, 0.0).z
	var root := Node3D.new()
	g.add_child(root)
	var frame := Transform3D(Basis(fwd2.cross(up2), up2, -fwd2), b.surface_point(up2))
	_rig_lip(root, frame, 1.0, 1.2, 3.0)
	await t.frames(2)
	place_at(0, b.surface_point(up2, 0.05), fwd2)
	await t.seconds(0.3)
	var wt: Array[float] = []
	for i in 300:
		stick_toward(fwd2)
		var t0 := Time.get_ticks_usec()
		p._physics_process(1.0 / 60.0)
		wt.append(float(Time.get_ticks_usec() - t0))
		if i % 20 == 0:
			await t.frames(1)
	p.bot_input = Vector2.ZERO
	wt.sort()
	t.log_line("CPUPROBE3 against a wall: body median %.0f us p90 %.0f us" % [wt[150], wt[270]])
	root.queue_free()


## position) and then skipped so the rest of the hunt is still tried.
func _phase_treasure_stress() -> void:
	_make_complete()
	var tp: TreasurePlay = g.treasure
	var hunts := int(Settings.test_args.get("hunts", "8"))
	var seed0 := int(Settings.test_args.get("seed0", "1000"))
	var tried := 0
	var missed := []
	for h in hunts:
		_treasure_reset()
		var st: Dictionary = tp.st()
		# (Every other hunt a second hunt, so both sizes are covered.)
		if h % 2 == 1:
			TreasureHunt.begin_hunt(st, g.balls, seed0 + h * 7919 + 1)
		TreasureHunt.begin_hunt(st, g.balls, seed0 + h * 7919)
		st["active"] = true
		tp._despawn()
		tp.refresh()
		await t.frames(3)
		for i in TreasureHunt.COUNT:
			var tg: Dictionary = TreasureHunt.current(st)
			tried += 1
			if await _lunge_at_current(tp):
				await _until(func(): return not tp.celebrating, 8.0)
				await t.frames(2)
				if tp.panel.card_open():
					tp.panel._close_card()
			else:
				var b: MossBall = g.balls[int(tg["world"])]
				var pos := TreasureHunt.target_pos(tg)
				var from := _approach(b, tp.node.global_position if tp.node else pos)
				missed.append("%s/%s" % [tg["kind"], tg.get("spot", "")])
				t.log_line("STRESS MISS seed %d hunt %d idx %d kind %s spot %s world %d scale %.2f pos %s alt %.2f approach %s (%.2f m) reach %.2f near miss %.2f, him at %s" % [
						int(st["seed"]), int(st["hunt"]), i, tg["kind"], tg.get("spot", ""), int(tg["world"]) + 1, float(tg.get("scale", 1.0)),
						str(pos.snapped(Vector3.ONE * 0.01)), b.altitude(pos), str(from.snapped(Vector3.ONE * 0.01)) if from != Vector3.INF else "none",
						from.distance_to(pos) if from != Vector3.INF else -1.0, tp.reach(), tp.near_miss, str(p.global_position.snapped(Vector3.ONE * 0.01))])
				TreasureHunt.collect(st, int(st["index"]))
				tp._despawn()
				tp.refresh()
				await t.frames(3)
	t.log_line("STRESS %d of %d collected; misses %s" % [tried - missed.size(), tried, str(missed)])
	t.check("treasure_stress_all_collectible", missed.is_empty(), "%d missed of %d" % [missed.size(), tried])


## Diagnostic (by name only): each fish seen from the real Live Tank camera in every view, sampled
## over time: alive, visible, simulating, in the tank, its length on screen in pixels, and whether a
## moss ball hides it.
func _phase_live_fish_diag() -> void:
	var pr: Presentation = g.presentation
	var fish: AmbientFish = g.fish
	var view_px := Vector2(g.get_viewport().get_visible_rect().size)
	var sec := float(Settings.test_args.get("secs", "12"))
	pr.enter("play")
	pr.go("live", true)
	for vi in 4:
		pr.live_view = vi
		if vi > 0:
			pr.next_live_view()
			pr.live_view = vi
		await t.seconds(1.5)
		var onscreen_sum := 0.0
		var samples := 0
		var px_all: Array[float] = []
		var bala_px: Array[float] = []
		var hidden := 0
		var out_of_tank := 0
		var not_vis := 0
		var el := 0.0
		while el < sec:
			await t.seconds(1.0)
			el += 1.0
			var cam: Camera3D = g.get_viewport().get_camera_3d()
			var n := 0
			for f in fish.fish:
				var mi: MeshInstance3D = f["node"]
				var k: Dictionary = AmbientFish.KINDS[f["kind"]]
				if not mi.is_visible_in_tree():
					not_vis += 1
				var pos := mi.global_position
				if pos.x < fish.tank_min.x - 1 or pos.x > fish.tank_max.x + 1 or pos.y < fish.tank_min.y - 1 or pos.y > fish.tank_max.y + 1 or pos.z < fish.tank_min.z - 1 or pos.z > fish.tank_max.z + 1:
					out_of_tank += 1
				if cam.is_position_behind(pos) or not Rect2(Vector2.ZERO, view_px).has_point(cam.unproject_position(pos)):
					continue
				var fwd := mi.global_basis.z.normalized()
				var a: Vector2 = cam.unproject_position(pos + fwd * k["len"] * 0.5)
				var b: Vector2 = cam.unproject_position(pos - fwd * k["len"] * 0.5)
				var px: float = a.distance_to(b)
				var q := PhysicsRayQueryParameters3D.create(cam.global_position, pos, 1 | 2)
				if not g.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
					hidden += 1
					continue
				n += 1
				px_all.append(px)
				if f["kind"] == "bala":
					bala_px.append(px)
			onscreen_sum += n
			samples += 1
		px_all.sort()
		bala_px.sort()
		t.log_line("LIVEFISH view %s: fish unhidden on screen avg %.1f of %d; px median %.1f max %.1f; bala px median %.1f (n %d); hidden by balls %d; not visible %d; out of tank %d; cam %s fov %.1f viewport %s" % [
				pr.LIVE_VIEWS[vi][0], onscreen_sum / maxf(1, samples), fish.fish.size(),
				px_all[px_all.size() / 2] if px_all.size() > 0 else 0.0, px_all.back() if px_all.size() > 0 else 0.0,
				bala_px[bala_px.size() / 2] if bala_px.size() > 0 else 0.0, bala_px.size(), hidden, not_vis, out_of_tank,
				str(g.get_viewport().get_camera_3d().global_position.round()), g.get_viewport().get_camera_3d().fov, str(view_px)])
	t.log_line("LIVEFISH water %.2f glass clean %.2f, fish processing %s" % [g.aquarium.water_q if "water_q" in g.aquarium else -1.0, -1.0, fish.is_physics_processing()])
	pr.exit()
	t.check("live_fish_diag_ran", true, "")


func _full_scale(kind: String) -> float:
	var n := TreasureModels.node(kind, 1.0)
	var k := n.scale.x
	n.free()
	return k


func _test_treasure_play() -> void:
	_make_complete()
	_treasure_reset()
	var tp: TreasurePlay = g.treasure
	var pct0 := g.completion_percent()
	var earned0 := g.run_save.earned().size()
	var fin0: float = g.clock.finish_s
	var run0: float = g.clock.run_s
	p.restore_full()
	p.invuln_t = 9999.0
	for b in g.balls:
		_hold_threats(b)
	tp.start()
	await t.frames(3)
	var st: Dictionary = tp.st()
	t.check("treasure_starts_first_hunt", TreasureHunt.has_hunt(st) and int(st["hunt"]) == 1 and float(st["scale"]) == 1.0 and tp.node != null
			and tp.panel != null and tp.panel.current_name() == TreasureHunt.kind_name(TreasureHunt.current(st)["kind"]), "")
	# Only the current object exists in the world.
	var in_world := 0
	for b in g.balls:
		for n in b.get_children():
			if n.has_meta("treasure_index"):
				in_world += 1
	t.check("treasure_only_current_exists", in_world == 1 and tp.node.get_meta("treasure_index") == 0, "%d in the world" % in_world)
	# Save and reload reproduce it exactly.
	g.save_run()
	var back := RunSave.open(g.run_save.path)
	var st2 := TreasureHunt.state_of(back.run())
	t.check("treasure_reload_same_hunt", st2["targets"] == st["targets"] and int(st2["index"]) == 0 and int(st2["seed"]) == int(st["seed"]), "")
	# Not collected by touching, by the tail or by Tier 2; not by anything but his lunge.
	var tg: Dictionary = TreasureHunt.current(st)
	var b0: MossBall = g.balls[int(tg["world"])]
	var target: Vector3 = tp.node.global_position
	# (Walk up to it; if the random hunt put it where this approach wedges him, try the next
	# approach point, as the lunge helper does. The test is about touching, not route finding.)
	var touched := false
	for skip in 4:
		var from := _approach(b0, target, skip)
		if from == Vector3.INF:
			break
		place_at(b0.index, from + b0.up_at(from) * 0.1, target - from)
		await t.seconds(0.3)
		for k in 80:
			var flat: Vector3 = target - p.global_position
			flat -= p.up * flat.dot(p.up)
			stick_toward(flat.normalized())
			await t.frames(2)
			if p.global_position.distance_to(target) < 1.2:
				break
		p.bot_input = Vector2.ZERO
		touched = p.global_position.distance_to(target) < 1.5
		if touched:
			break
		t.log_line("TREASURE TOUCH approach %d wedged at %.2f m; trying the next" % [skip, p.global_position.distance_to(target)])
	var idx_touch := int(st["index"])
	await press("swipe")
	await t.seconds(0.5)
	var strikeable: bool = g._strikeable(p).any(func(x): return x == tp.node or (x is Node and (x as Node).is_ancestor_of(tp.node)))
	var saved_t2 := g.tier2
	g.tier2 = Tier2.new()
	for id in Tier2.ORDER:
		g.tier2.unlock(id)
	var t2_fired := 0
	for id in Tier2.ORDER:
		g.tier2.equip(id)
		g.tier2.ready_at = 0.0
		if await _fire_tier2(3.0) >= 0.0:
			t2_fired += 1
		await t.seconds(0.3)
	g.tier2 = saved_t2
	t.check("treasure_not_by_touch_tail_or_tier2", touched and idx_touch == 0 and int(st["index"]) == 0 and not strikeable and t2_fired == 3 and tp.node != null,
			"touching %s, index %d, strikeable %s, Tier 2 fired %d" % [touched, int(st["index"]), strikeable, t2_fired])
	# A future object cannot be taken early: it does not exist yet, and nothing advances out of turn.
	t.check("treasure_future_not_collectible", not TreasureHunt.collect(st, 1) and int(st["index"]) == 0, "")
	# The lunge collects it: saved at once, one step, the celebration, then the next object.
	var got := await _lunge_at_current(tp)
	var saved := TreasureHunt.state_of(RunSave.open(g.run_save.path).run())
	var dancing: bool = tp.celebrating and (p.state == "celebrate" or p.model.dancing())
	t.check("treasure_lunge_collects", got and int(st["index"]) == 1 and int(saved["index"]) == 1 and tp.last.get("index", -1) == 0, "index %d, saved %d" % [int(st["index"]), int(saved["index"])])
	t.check("treasure_celebration_runs", dancing and tp.node == null, "celebrating %s, state %s, dance %s" % [tp.celebrating, p.state, p.model.dancing()])
	# During the celebration nothing more can be taken.
	var double := tp.try_collect(p, p.body_center(), p.head_position())
	await _until(func(): return not tp.celebrating, 6.0)
	await t.frames(3)
	t.check("treasure_no_double_and_clean_end", not double and int(st["index"]) == 1 and p.state == "normal" and p.controls_enabled and not p.model.dancing()
			and tp.node != null and tp.node_index == 1 and p.is_on_floor(),
			"index %d, state %s, next shown %s, on the floor %s (%.2f m up: the first object may be on a perch)" % [int(st["index"]), p.state, tp.node != null, p.is_on_floor(), p.ball.altitude(p.global_position)])
	# The celebration's effects draw on their own generators (the game's frames in between may use
	# the global one legitimately, so this is checked on the effects themselves).
	seed(99)
	var q0 := [randi(), randi()]
	seed(99)
	for c in TreasurePlay.CONFETTI:
		WaterFX.inst.sparkle(p.global_position, c, 9, 2.4, 0.06, 1.3)
	tp._firework(p.global_position, p.up, 0.0)
	t.check("treasure_celebration_leaves_rng_alone", [randi(), randi()] == q0, "")
	# The aquarium experiences neither show nor change it.
	var before: Array = st["targets"].duplicate(true)
	g.presentation.enter("play")
	await t.frames(3)
	var hidden: bool = not tp.node.visible
	g.presentation.go("swim")
	await t.seconds(0.5)
	g.presentation.exit()
	await t.frames(3)
	tp.stop()
	tp.start()
	await t.frames(3)
	t.check("treasure_modes_do_not_change_it", hidden and st["targets"] == before and int(st["index"]) == 1 and tp.node.visible and tp.node_index == 1, "")
	# A saved spot that became bad is replaced by a good one in the same world; same object, same place in the order.
	var cur: Dictionary = TreasureHunt.current(st)
	var cw: MossBall = g.balls[int(cur["world"])]
	# (A random hunt may already have moved this object once, e.g. off a top with no room: count the
	# recovery, not the total.)
	var rec0 := int(cur.get("recovered", 0))
	# (The new spot is judged by its kind, as the game judges it: a leaf, rock or cave perch is not a
	# ground spot.)
	# (Deep in the world's core, not 3 m under the spot: from a leaf, rock or cave perch 3 m down is
	# often open ground, a good spot, so nothing was recovered.)
	var buried := cw.global_position.lerp(TreasureHunt.target_pos(cur), 0.3)
	cur["pos"] = [buried.x, buried.y, buried.z]
	tp.stop()
	tp.start()
	await t.frames(3)
	var fixed := TreasureHunt.current(st)
	t.check("treasure_bad_spot_recovered", fixed["kind"] == cur["kind"] and int(fixed["world"]) == int(cur["world"]) and int(st["index"]) == 1
			and TreasureHunt.target_ok(cw, fixed) and int(fixed.get("recovered", 0)) == rec0 + 1,
			"kind %s world %d index %d recovered %d -> %d" % [fixed["kind"], int(fixed["world"]), int(st["index"]), rec0, int(fixed.get("recovered", 0))])
	# dev-000030 (2026-09-29): tower and shelf tops with no room beside the object could hold it, so a
	# hunt could not be finished. Those tops are no longer hiding places, and a saved hunt whose
	# current object sits on one moves it (same world, same object) when it is shown.
	# (Each checked at the size that had no room: the world-2 top has room for a half-size object.)
	var perch_bad := [[2, Vector3(-67.37, -17.74, -127.34), 1.0], [2, Vector3(-67.37, -17.74, -127.34), 0.5],
			[2, Vector3(-65.43, -19.99, -127.99), 1.0], [2, Vector3(-65.43, -19.99, -127.99), 0.5], [1, Vector3(160.5, -21.69, -17.13), 1.0]]
	var perch_rejected := 0
	for pb in perch_bad:
		if not TreasureHunt.target_ok(g.balls[pb[0]], {"spot": "rock", "pos": [pb[1].x, pb[1].y, pb[1].z], "scale": pb[2]}):
			perch_rejected += 1
	var cur2: Dictionary = TreasureHunt.current(st)
	var cur2_was := cur2.duplicate(true)
	cur2["world"] = float(perch_bad[0][0])
	cur2["spot"] = "rock"
	cur2["pos"] = [perch_bad[0][1].x, perch_bad[0][1].y, perch_bad[0][1].z]
	tp.stop()
	tp.start()
	await t.frames(3)
	var perch_moved: Dictionary = TreasureHunt.current(st)
	var perch_mb: MossBall = g.balls[int(perch_moved["world"])]
	var perch_moved_ok: bool = int(perch_moved["world"]) == perch_bad[0][0] and TreasureHunt.target_pos(perch_moved).distance_to(perch_bad[0][1]) > 0.5 \
			and TreasureHunt.target_ok(perch_mb, perch_moved)
	t.check("treasure_no_perch_without_room", perch_rejected == 5 and perch_moved_ok, "%d of 5 bad tops rejected; moved to %s (%s)" % [perch_rejected, str(TreasureHunt.target_pos(perch_moved).round()), perch_moved.get("spot", "")])
	# (Back to the hunt as it was, for the rest of the test.)
	for key in cur2_was:
		cur2[key] = cur2_was[key]
	tp._despawn()
	tp.refresh()
	await t.frames(3)
	# The rest of the first hunt, each by a real lunge; then the finish.
	var found := 1
	var misses := []
	for i in 13:
		var k: String = TreasureHunt.current(st).get("kind", "")
		var hit := await _lunge_at_current(tp)
		if not hit:
			# (The test's approach can fall just short of a random spot (CI 2026-10-01: a ground spot,
			# near miss 0.13 m): log it, try again; then move the spot as the game moves a bad one and try
			# once more. The check is about finishing a hunt by lunges, not about this helper's aim.)
			t.log_line("TREASURE RETRY seed %d target %s player %s near_miss %.2f" % [int(st["seed"]), JSON.stringify(TreasureHunt.current(st)),
					str(p.global_position), tp.near_miss])
			hit = await _lunge_at_current(tp)
			if not hit:
				TreasureHunt.recover(st, int(st["index"]), g.balls)
				tp.stop()
				tp.start()
				await t.frames(3)
				hit = await _lunge_at_current(tp)
		if hit:
			found += 1
		else:
			# (Everything needed to replay the miss: the hunt's seed and the target as saved.)
			misses.append(k)
			t.log_line("TREASURE MISS seed %d target %s player %s near_miss %.2f" % [int(st["seed"]), JSON.stringify(TreasureHunt.current(st)),
					str(p.global_position), tp.near_miss])
			break
		if i < 12:
			await _until(func(): return not tp.celebrating, 6.0)
			await t.frames(2)
	await _until(func(): return tp.panel.card_open(), 8.0)
	t.check("treasure_full_hunt_by_lunges", found == 14 and TreasureHunt.is_complete(st) and int(st["completed_hunts"]) == 1 and tp.panel.card_open(),
			"found %d, missed %s" % [found, str(misses)])
	t.check("treasure_never_touches_completion_or_clock", is_equal_approx(g.completion_percent(), pct0) and g.run_save.earned().size() == earned0
			and g.clock.finish_s == fin0 and is_equal_approx(g.clock.run_s, run0), "%.2f%% -> %.2f%%, finish %.2f -> %.2f" % [pct0, g.completion_percent(), fin0, g.clock.finish_s])
	# New hunt: new order, new places, half size.
	var first: Array = st["targets"].duplicate(true)
	(tp.panel._card.find_child("NewHunt", true, false) as Button).pressed.emit()
	await t.frames(3)
	var second: Array = st["targets"]
	var moved := 0
	for i in 14:
		var pa := TreasureHunt.target_pos(first[i])
		var nearest := INF
		for q in second:
			nearest = minf(nearest, pa.distance_to(TreasureHunt.target_pos(q)))
		if nearest > 3.0:
			moved += 1
	t.check("treasure_second_hunt_new_and_half", int(st["hunt"]) == 2 and float(st["scale"]) == 0.5 and int(st["index"]) == 0 and not g.get_tree().paused
			and second.map(func(x): return x["kind"]) != first.map(func(x): return x["kind"]) and moved >= 12
			and tp.node != null and is_equal_approx(tp.node.scale.x / _full_scale(TreasureHunt.current(st)["kind"]), 0.5),
			"hunt %d, scale %.2f, %d of 14 spots new" % [int(st["hunt"]), float(st["scale"]), moved])
	var got2 := await _lunge_at_current(tp)
	await _until(func(): return not tp.celebrating, 6.0)
	t.check("treasure_half_size_still_collectible", got2 and int(st["index"]) == 1, "")
	# A third hunt stays at half (not a quarter).
	st["index"] = 14
	st["completed_hunts"] = 2
	tp.start()
	await t.frames(2)
	t.check("treasure_third_hunt_still_half", int(st["hunt"]) == 3 and float(st["scale"]) == 0.5, "scale %.2f" % float(st["scale"]))
	# Quit right after a find: the save holds exactly that find.
	var idx_a := int(st["index"])
	var got3 := await _lunge_at_current(tp)
	if not got3:
		# (This check is about the save after a find, not about awkward spots: a random spot the
		# test's approach cannot reach is moved the way the game moves a bad spot, then tried again.)
		t.log_line("TREASURE QUIT find missed at %s (world %d); recovering the spot and trying again"
				% [str(TreasureHunt.target_pos(TreasureHunt.current(st))), int(TreasureHunt.current(st)["world"])])
		TreasureHunt.recover(st, int(st["index"]), g.balls)
		tp.stop()
		tp.start()
		await t.frames(3)
		idx_a = int(st["index"])
		got3 = await _lunge_at_current(tp)
	var on_disk := TreasureHunt.state_of(RunSave.open(g.run_save.path).run())
	t.check("treasure_quit_mid_celebration_safe", got3 and int(on_disk["index"]) == idx_a + 1 and on_disk["targets"] == st["targets"],
			"found %s, index on disk %d (expected %d), targets match %s" % [got3, int(on_disk["index"]), idx_a + 1, on_disk["targets"] == st["targets"]])
	await _until(func(): return not tp.celebrating, 6.0)
	tp.stop()
	await t.frames(2)



# --- His body and traction (Mote Open Issue #1) --------------------------------------------

## Test ground for the traction tests: bodies on the terrain layer, in the frame of a quiet, flat
## spot (x right, y up, -z ahead).
func _rig_body(root: Node3D, xf: Transform3D, shape: Shape3D, mesh: Mesh) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	var cs := CollisionShape3D.new()
	cs.shape = shape
	sb.add_child(cs)
	if mesh != null:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		sb.add_child(mi)
	root.add_child(sb)
	sb.global_transform = xf
	return sb


## A block `h` high whose near face is `ahead` metres in front of the spot (a lip).
func _rig_lip(root: Node3D, frame: Transform3D, ahead: float, h: float, depth := 2.5, width := 3.0) -> StaticBody3D:
	var sh := BoxShape3D.new()
	sh.size = Vector3(width, h + 0.4, depth)
	var bm := BoxMesh.new()
	bm.size = sh.size
	return _rig_body(root, frame * Transform3D(Basis(), Vector3(0, (h - 0.4) * 0.5, -(ahead + depth * 0.5))), sh, bm)


## A face rising at `deg` from `ahead` metres in front of the spot to `rise` metres, then a flat top.
func _rig_face(root: Node3D, frame: Transform3D, ahead: float, deg: float, rise: float, top := 2.0, width := 3.0) -> StaticBody3D:
	var run := 1.0 / tan(deg_to_rad(deg))
	var pts := PackedVector3Array()
	for x in [-width * 0.5, width * 0.5]:
		pts.append(Vector3(x, -0.4, -(ahead - 0.4 * run)))
		pts.append(Vector3(x, rise, -(ahead + rise * run)))
		pts.append(Vector3(x, rise, -(ahead + rise * run + top)))
		pts.append(Vector3(x, -0.4, -(ahead + rise * run + top)))
	var sh := ConvexPolygonShape3D.new()
	sh.points = pts
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quads := [[0, 1, 5, 4], [1, 2, 6, 5], [0, 4, 7, 3], [4, 5, 6, 7], [0, 3, 2, 1], [3, 7, 6, 2]]
	for q in quads:
		for k in [0, 1, 2, 0, 2, 3]:
			st.add_vertex(pts[q[k]])
	st.generate_normals()
	return _rig_body(root, frame, sh, st.commit())


## Pushes him straight ahead for `s` seconds; returns [max height, final height, frames grounded]
## (heights above the tangent plane of `frame`, the test ground's own level).
func _push_ahead(frame: Transform3D, s: float) -> Array:
	var fwd := -frame.basis.z
	var hi := -INF
	var on := 0
	for f in int(s * 60):
		stick_toward(fwd)
		await t.frames(1)
		hi = maxf(hi, _rig_h(frame))
		on += 1 if p.grounded else 0
	p.bot_input = Vector2.ZERO
	return [hi, _rig_h(frame), on]


func _rig_h(frame: Transform3D) -> float:
	return (p.global_position - frame.origin).dot(frame.basis.y)


## Distributed traction: a short steep lip is pulled over once his front has purchase above it; a
## lip above CRAWL_MAX still needs a jump; a long steep face (over 52 degrees, metres high) loses him
## his traction and he slides back down: no wall adhesion, no ratcheting over repeated attempts;
## walkable slopes are walked as before.
func _test_gill_traction() -> void:
	var b := g.balls[0]
	var release := _hold_threats(b)
	p.invuln_t = 999
	var spot := _quiet_spot(0)
	var up := b.up_at(spot)
	var fwd := -MossBall.frame_at(up, 0.0).z
	var frame := Transform3D(Basis(fwd.cross(up), up, -fwd), b.surface_point(up))
	var root := Node3D.new()
	g.add_child(root)
	var start := func() -> void:
		place_at(0, b.surface_point(up, 0.05), fwd)
		await t.seconds(0.4)
	var m0: int = p.get("mantles") if "mantles" in p else 0
	# Short lips: pulled over.
	var lips := []
	var lips_ok := true
	for h in [0.22, 0.3, 0.4]:
		var lip := _rig_lip(root, frame, 1.3, h, 8.0)
		await t.frames(2)
		await start.call()
		var r: Array = await _push_ahead(frame, 1.5)
		var on_top: bool = r[1] > h - 0.06 and p.grounded and (p.global_position - frame.origin).dot(fwd) > 1.6
		lips_ok = lips_ok and on_top
		lips.append("%.2f m: %s (at %.2f m)" % [h, "over" if on_top else "NOT over", r[1]])
		lip.free()
	var m_now: int = p.get("mantles") if "mantles" in p else 0
	t.check("traction_short_lip_pulled_over", lips_ok and m_now >= m0 + 2, ", ".join(lips) + "; %d pulls" % (m_now - m0))
	# A lip taller than Axolotl.CRAWL_MAX: no crawl (a jump is needed, and still works).
	var tall := _rig_lip(root, frame, 1.3, 0.62, 8.0)
	await t.frames(2)
	await start.call()
	var m1: int = p.get("mantles") if "mantles" in p else 0
	var rt: Array = await _push_ahead(frame, 2.0)
	var m1b: int = p.get("mantles") if "mantles" in p else 0
	var stayed: bool = rt[0] < 0.2 and m1b == m1
	stick_toward(fwd)
	await press("jump")
	await _push_ahead(frame, 0.6)
	await wait_grounded()
	t.check("traction_tall_lip_needs_a_jump", stayed and _rig_h(frame) > 0.55, "pushing: highest %.2f m, %d pulls; after a jump %.2f m up" % [rt[0], m1b - m1, _rig_h(frame)])
	tall.free()
	# Long steep faces: he never gets up them by pushing, and after each push slides back to the
	# bottom (no adhesion); repeated pushes get no higher (no ratchet).
	var faces := []
	var faces_ok := true
	for deg in [56.0, 62.0, 75.0]:
		var face := _rig_face(root, frame, 1.2, deg, 3.0)
		await t.frames(2)
		await start.call()
		var highs := []
		var m2: int = p.get("mantles") if "mantles" in p else 0
		var rests := []
		for k in 4:
			var r2: Array = await _push_ahead(frame, 1.1)
			highs.append(r2[0])
			await t.seconds(0.5)
			rests.append(_rig_h(frame))
		# Jumping into it: up with the jump, then down again.
		stick_toward(fwd)
		await press("jump")
		await _push_ahead(frame, 0.4)
		await t.seconds(1.2)
		var after_jump := _rig_h(frame)
		var m2b: int = p.get("mantles") if "mantles" in p else 0
		var ok: bool = highs.max() < 0.45 and highs[3] <= highs[0] + 0.05 and rests.max() < 0.12 and after_jump < 0.12 and m2b == m2 and p.grounded
		faces_ok = faces_ok and ok
		faces.append("%.0f deg: pushes reach %s m, rests at %s, after a jump %.2f, %d pulls" % [deg, str(highs.map(func(x): return snappedf(x, 0.01))),
				str(rests.map(func(x): return snappedf(x, 0.01))), after_jump, m2b - m2])
		face.free()
	# A steep face of narrow ledges (0.35 m risers, 0.2 m treads: 60 degrees overall): each ledge is
	# no top to pull onto, so pushing never ratchets him up it.
	var steps := []
	for k in 7:
		steps.append(_rig_lip(root, frame, 1.3 + 0.2 * k, 0.35 * (k + 1), 3.0))
	await t.frames(2)
	await start.call()
	var m4: int = p.mantles
	var st_hi := []
	for k in 4:
		var r4: Array = await _push_ahead(frame, 1.1)
		st_hi.append(snappedf(r4[0], 0.01))
		await t.seconds(0.4)
	faces_ok = faces_ok and st_hi.max() < 0.8 and st_hi[3] <= st_hi[0] + 0.05
	faces.append("ledged face: pushes reach %s m, %d pulls" % [str(st_hi), p.mantles - m4])
	for s_ in steps:
		s_.free()
	t.check("traction_long_steep_face_slides_no_ratchet", faces_ok, "; ".join(faces))
	# Walkable slopes: walked up as before.
	var walks := []
	var walk_ok := true
	for deg in [30.0, 45.0]:
		var ramp := _rig_face(root, frame, 1.2, deg, 1.2, 8.0)
		await t.frames(2)
		await start.call()
		var r3: Array = await _push_ahead(frame, 1.5)
		walk_ok = walk_ok and r3[0] > 1.1
		walks.append("%.0f deg: %.2f m up" % [deg, r3[0]])
		ramp.free()
	t.check("traction_walkable_slopes_walked", walk_ok, ", ".join(walks))
	root.queue_free()
	await t.frames(2)
	# Ravine walls stay unscalable: from low and halfway up a ravine's wall, pushing up it, he
	# never pulls himself out; he slides to the floor and is put back at the rim as always.
	var at := MossBall.dir_ll(-10, -40)
	var fr := MossBall.frame_at(at, 0.0)
	var n_hills := b.hills.size()
	var n_carves := b.carves.size()
	var m2a := func(m: float) -> float: return m / b.radius
	b.add_plateau(at, m2a.call(14.0), 3.0, 2.5)
	b.add_ravine([at.rotated(fr.z, m2a.call(10.0)), at, at.rotated(fr.z, -m2a.call(10.0))], 3.2, 3.0, 1.4, "test.traction")
	b.finalize_terrain()
	await t.frames(2)
	var rav := []
	var rav_ok := true
	for frac in [0.25, 0.5]:
		# The point on the wall at that height (walking out from the middle of the floor).
		var wd := at
		for k in 80:
			wd = at.rotated(fr.x, m2a.call(1.6 + k * 0.03))
			if b.terrain_height(wd) >= 3.0 * frac:
				break
		var out := (b.surface_point(at.rotated(fr.x, m2a.call(5.0))) - b.surface_point(wd)).normalized()
		place_at(0, b.surface_point(wd, 0.35), out)
		p.health = p.max_health
		var m3: int = p.mantles
		var start_h := (p.global_position - b.global_position).length() - b.radius
		var top := 0.0
		for f in 90:
			stick_toward(out)
			await t.frames(1)
			if g.cinematic != "":
				break
			top = maxf(top, (p.global_position - b.global_position).length() - b.radius)
		p.bot_input = Vector2.ZERO
		var got_out := b.ravine_carve(p.up) < 0.15 and g.cinematic == ""
		rav_ok = rav_ok and not got_out and p.mantles == m3 and top <= start_h + 0.05
		rav.append("placed %.2f m up the wall: highest %.2f m of 3, pulls %d, %s" % [start_h, top, p.mantles - m3, "OUT" if got_out else "slid back down"])
		for f in 60 * 6:
			if g.cinematic == "" and p.state == "normal":
				break
			await t.frames(1)
		p.restore_full()
	t.check("traction_ravine_walls_unscalable", rav_ok, "; ".join(rav))
	b.hills.resize(n_hills)
	b.carves.resize(n_carves)
	b._cells_dirty = true
	b.finalize_terrain()
	await t.frames(2)
	p.invuln_t = 0.0
	release.call()


## The segments of his spine in the world (bone i to bone i + 1, pointing toward the tail).
func _spine_dirs(m: AxolotlModel) -> Array[Vector3]:
	var sk := m.skeleton
	var pts: Array[Vector3] = []
	for i in AxolotlModel.BONE_Z.size():
		pts.append(sk.global_transform * sk.get_bone_global_pose(i).origin)
	var out: Array[Vector3] = []
	for i in pts.size() - 1:
		out.append((pts[i + 1] - pts[i]).normalized())
	return out


## Largest bend between his front and the rest of his spine (radians, about `up`).
func _spine_yaw_bend(m: AxolotlModel, up: Vector3) -> float:
	var d := _spine_dirs(m)
	var a := d[0] - up * d[0].dot(up)
	var worst := 0.0
	for i in range(1, d.size()):
		var c := d[i] - up * d[i].dot(up)
		worst = maxf(worst, absf(a.signed_angle_to(c, up)))
	return worst


## Signed bend from his front to his tail (radians, about `up`); the travelling S-wave averages out
## of it over a stride, the body following a turn does not.
func _spine_yaw_signed(m: AxolotlModel, up: Vector3) -> float:
	var d := _spine_dirs(m)
	var a := d[0] - up * d[0].dot(up)
	var c := d[d.size() - 1] - up * d[d.size() - 1].dot(up)
	return a.signed_angle_to(c, up)


## Head leads, body follows, tail completes the motion: turning, each segment of his spine swings
## round after the one ahead of it (head first); the body bends through the turn and straightens
## once he is done; walking onto a slope, the front pitches first and the rest follows; placing him
## (a teleport, a respawn) leaves no smear. All of it is the model: the gameplay body turns and
## moves exactly as it did.
func _test_gill_body_follow() -> void:
	var b := g.balls[0]
	var release := _hold_threats(b)
	p.invuln_t = 999
	var spot := _quiet_spot(0)
	var up := b.up_at(spot)
	var fwd := -MossBall.frame_at(up, 0.0).z
	var right := fwd.cross(up)
	var m := p.model
	place_at(0, b.surface_point(up, 0.05), fwd)
	await t.seconds(1.0)
	var straight := _spine_yaw_bend(m, up)
	# A quarter turn from a standstill (he turns on the spot, then sets off).
	var n := AxolotlModel.BONE_Z.size() - 1
	var crossed: Array = []
	crossed.resize(n)
	crossed.fill(-1)
	var bend_max := 0.0
	var face_at := -1
	for f in 60:
		stick_toward(right)
		await t.frames(1)
		var d := _spine_dirs(m)
		for i in n:
			var c := d[i] - up * d[i].dot(up)
			# (Segments point to the tail: a quarter turn right takes them from -fwd to -right.)
			if crossed[i] < 0 and absf((-fwd).signed_angle_to(c, up)) > PI * 0.25:
				crossed[i] = f
		if face_at < 0 and p.facing.dot(right) > 0.7071:
			face_at = f
		bend_max = maxf(bend_max, _spine_yaw_bend(m, up))
	p.bot_input = Vector2.ZERO
	var ordered := not crossed.has(-1)
	# (Within a frame: the body wave rides on top of it.)
	for i in range(1, n):
		ordered = ordered and crossed[i] >= crossed[i - 1] - 1
	t.check("body_follows_head_through_a_turn", ordered and crossed[n - 1] - crossed[0] >= 4 and bend_max > deg_to_rad(25.0) and straight < deg_to_rad(7.0),
			"segments swing round on frames %s (the body faced round on frame %d); bend up to %.0f deg; standing straight %.1f deg" % [str(crossed), face_at, rad_to_deg(bend_max), rad_to_deg(straight)])
	await t.seconds(1.5)
	var settled := _spine_yaw_bend(m, up)
	t.check("body_straightens_after_the_turn", settled < deg_to_rad(7.0), "%.1f deg" % rad_to_deg(settled))
	# Responsiveness: the gameplay body turns exactly as before (the follow-through is all model).
	t.check("controls_turn_unchanged", face_at >= 0 and face_at <= 12, "faced round in %d frames" % face_at)
	# Running through a turn bends him too.
	place_at(0, b.surface_point(up, 0.05), fwd)
	await t.seconds(0.3)
	var run_bend := 0.0
	var run_straight := 0.0
	var turn_dir := fwd
	# (Averaged over two strides of the body wave, 64 frames, so the wave itself cancels out.)
	for f in 180:
		# Running ahead, then curving round to the right.
		if f >= 96:
			turn_dir = turn_dir.rotated(p.up, -0.05)
		stick_toward(fwd if f < 96 else turn_dir)
		await t.frames(1)
		if f >= 32 and f < 96:
			run_straight += _spine_yaw_signed(m, p.up) / 64.0
		if f >= 112 and f < 176:
			run_bend += _spine_yaw_signed(m, p.up) / 64.0
	p.bot_input = Vector2.ZERO
	t.check("body_bends_running_through_a_turn", absf(run_bend) > deg_to_rad(10.0) and absf(run_straight) < deg_to_rad(5.0),
			"curving: tail %.0f deg off the head on average; running straight %.0f deg" % [rad_to_deg(run_bend), rad_to_deg(run_straight)])
	# Pitch: onto a 30 degree slope, the front pitches up first; on it, the whole body lies along it.
	var root := Node3D.new()
	g.add_child(root)
	var frame := Transform3D(Basis(right, up, -fwd), b.surface_point(up))
	var ramp := _rig_face(root, frame, 1.6, 30.0, 2.5, 2.0)
	await t.frames(2)
	place_at(0, b.surface_point(up, 0.05), fwd)
	await t.seconds(0.4)
	var lead := -INF
	var along := []
	for f in 150:
		stick_toward(fwd)
		await t.frames(1)
		var d := _spine_dirs(m)
		var pf := asin(clampf(-d[0].dot(up), -1.0, 1.0))
		var pb := asin(clampf(-d[n - 1].dot(up), -1.0, 1.0))
		var on := (p.global_position - frame.origin).dot(fwd)
		# Crossing onto the slope: head on it, tail still behind on the flat.
		if on > 1.4 and on < 2.0:
			lead = maxf(lead, pf - pb)
		if height() > 1.0 and height() < 1.9 and p.grounded:
			var worst := 0.0
			for i in n:
				worst = maxf(worst, absf(rad_to_deg(asin(clampf(-d[i].dot(up), -1.0, 1.0))) - 30.0))
			along.append(worst)
	p.bot_input = Vector2.ZERO
	t.check("body_pitch_conforms_progressively", lead > deg_to_rad(10.0) and not along.is_empty() and along.min() < 9.0,
			"front leads the tail by %.0f deg onto the slope; on it every segment within %s deg of the slope" % [rad_to_deg(lead), str(snappedf(along.min(), 0.1)) if not along.is_empty() else "-"])
	ramp.free()
	root.queue_free()
	# A teleport leaves no smear: straight at once, where he is.
	place_at(0, b.surface_point(up, 0.05), fwd)
	await t.seconds(0.2)
	for f in 20:
		stick_toward(right if f < 10 else -fwd)
		await t.frames(1)
	var far := b.up_at(spot + fwd * 12.0)
	place_at(0, b.surface_point(far, 0.05), right)
	await t.frames(1)
	var sk := m.skeleton
	var tail := sk.global_transform * sk.get_bone_global_pose(n).origin
	var smear := 0.0
	for i in m._f_yaw.size():
		smear = maxf(smear, maxf(absf(m._f_yaw[i]), absf(m._f_pitch[i])))
	t.check("place_clears_the_body_trail", smear < deg_to_rad(1.0) and tail.distance_to(p.global_position) < 1.2, "follow bend %.1f deg, tail %.2f m from him" % [rad_to_deg(smear), tail.distance_to(p.global_position)])
	p.invuln_t = 0.0
	release.call()


## Swim Mode: the swimmer's body bends through its turns and dives (the same model).
func _test_swim_body_follow() -> void:
	var pr: Presentation = g.presentation
	var b0 := g.balls[0]
	var release := _hold_threats(b0)
	pr.enter("play")
	pr.go("swim")
	await t.seconds(0.6)
	var sw := pr.swimmer
	var m := sw.model
	pr.ui.swim_held = true
	pr.ui.swim_stick = Vector2.ZERO
	sw.pitch = 0.0
	await t.seconds(1.0)
	var yaw_bend := 0.0
	pr.ui.swim_stick = Vector2(1.0, 0.0)
	for f in 60:
		await t.frames(1)
		if f >= 20:
			yaw_bend += _spine_yaw_signed(m, sw.global_basis.y) / 40.0
	pr.ui.swim_stick = Vector2.ZERO
	await t.seconds(1.5)
	var calm := 0.0
	for f in 40:
		await t.frames(1)
		calm += _spine_yaw_signed(m, sw.global_basis.y) / 40.0
	var pitch_bend := 0.0
	pr.ui.swim_stick = Vector2(0.0, 1.0)
	for f in 45:
		await t.frames(1)
		var d := _spine_dirs(m)
		var x := sw.global_basis.x
		var a := d[0] - x * d[0].dot(x)
		var c := d[d.size() - 1] - x * d[d.size() - 1].dot(x)
		pitch_bend = maxf(pitch_bend, a.angle_to(c))
	pr.ui.swim_stick = Vector2.ZERO
	pr.ui.swim_held = false
	yaw_bend = absf(yaw_bend)
	calm = absf(calm)
	t.check("swimmer_bends_through_turns_and_dives", yaw_bend > deg_to_rad(12.0) and pitch_bend > deg_to_rad(6.0) and calm < deg_to_rad(5.0),
			"turning %.0f deg, diving %.0f deg, gliding straight %.0f deg" % [rad_to_deg(yaw_bend), rad_to_deg(pitch_bend), rad_to_deg(calm)])
	pr.exit()
	await t.frames(2)
	release.call()



## Crawling opens no shortcut up designed elevated content: walking at every elevated platform,
## mound, mesa, shelf, terrace, stone column and rising stone from the open ground round it (twelve
## sides, every other one met at an angle, no jumping), a crawl never gets him onto its top.
## (Crawls over a band on the way up a walkable flank, and walks up designed ramps, are logged, not
## failed.) A crawl is also, by construction, less than a plain jump from where he stands.
func _test_traction_no_shortcuts() -> void:
	var space := g.get_world_3d().direct_space_state
	p.invuln_t = 99999
	var probes := 0
	var bodies := 0
	var pulls := 0
	var shortcuts: Array[String] = []
	var walked: Array[String] = []
	var pulled: Array[String] = []
	for b in g.balls:
		var release := _hold_threats(b)
		var lb: LevelBuilder = b.get_meta("builder")
		for node in lb.root.get_children():
			if not (node is StaticBody3D or node is AnimatableBody3D) or node.has_meta("decor_leaf"):
				continue
			var tp := Vector3.INF
			if node.has_meta("top_point"):
				tp = node.get_meta("top_point")
			elif node.has_meta("top"):
				tp = (node as Node3D).global_transform * Vector3(0, float(node.get_meta("top")), 0)
			if tp == Vector3.INF:
				continue
			var u := b.up_at(tp)
			if b.altitude(tp) < 0.6 or b.ravine_carve(u) > 0.05:
				continue
			bodies += 1
			var fr := MossBall.frame_at(u, 0.0)
			for k in 12:
				var dir: Vector3 = fr.z.rotated(u, TAU * k / 12.0)
				# Out from under the top until open, gentle ground, then 1.2 m further.
				var start := Vector3.INF
				for s in range(4, 40):
					var d := b.up_at(tp + dir * (s * 0.25))
					var gp := b.surface_point(d)
					var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(gp + d * 3.5, gp - d * 0.5, 1 | 2 | 8))
					# (The ground itself, not the foot of the body or anything else on it.)
					if hit.is_empty() or absf(b.altitude(hit["position"])) > 0.06 or (hit["normal"] as Vector3).dot(d) < 0.9:
						continue
					var d2 := b.up_at(tp + dir * (s * 0.25 + 1.2))
					if b.ravine_carve(d2) > 0.05:
						break
					start = b.surface_point(d2, 0.05)
					break
				if start == Vector3.INF:
					continue
				var d0 := b.up_at(start)
				if not space.intersect_ray(PhysicsRayQueryParameters3D.create(start + d0 * 0.2, start + d0 * 2.5, 1 | 2 | 8)).is_empty():
					continue
				probes += 1
				var to := tp - start
				# (Every other side is met at an angle, 30 degrees off the top, alternately left and
				# right: a side can read differently met obliquely.)
				var skew := 0.0 if k % 2 == 0 else (0.52 if k % 4 == 1 else -0.52)
				var aim := (to - d0 * to.dot(d0)).normalized().rotated(d0, skew)
				place_at(b.index, start, aim)
				await t.frames(8)
				var h0 := b.altitude(p.global_position)
				var m0: int = p.mantles
				var hi := h0
				for f in 100:
					stick_toward(aim if skew != 0.0 else tp - p.global_position)
					await t.frames(1)
					if p.grounded:
						hi = maxf(hi, b.altitude(p.global_position))
					if g.cinematic != "":
						break
				p.bot_input = Vector2.ZERO
				var np: int = p.mantles - m0
				pulls += np
				var what := "ball %d %s %s (top %.1f m up) from the %d side: up to %.2f m, %d pulls" % [b.index + 1, node.get_meta("terrain_kind", node.get_meta("grounded", node.get_class())),
						node.name, b.altitude(tp), k, hi - h0, np]
				# (A shortcut is getting onto the elevated top with a pull; a pull over a lip on the
				# way up a walkable flank, or a walk up a designed ramp, is not.)
				if np > 0:
					pulled.append(what)
					if hi >= b.altitude(tp) - 0.45:
						shortcuts.append(what)
				elif hi - h0 > 0.6:
					walked.append(what)
				for f in 60 * 5:
					if g.cinematic == "" and p.state == "normal":
						break
					await t.frames(1)
		release.call()
	p.invuln_t = 0.0
	p.restore_full()
	for x in walked:
		t.log_line("walked up (no pull): " + x)
	for x in pulled:
		t.log_line("pulled over a lip: " + x)
	for x in shortcuts:
		t.log_line("SHORTCUT: " + x)
	t.check("traction_opens_no_shortcuts", shortcuts.is_empty() and bodies > 40 and probes > 150,
			"%d elevated bodies, %d approaches, %d pulls over lips on the way; %d walk-ups by design ramps; shortcuts: %s" % [bodies, probes, pulls, walked.size(), str(shortcuts)])



## A solid whose top follows a profile of (ahead, height) points from `frame` (x right, -z ahead),
## `width` across: a convex outline (its slopes only ever ease off going up). Drawn too.
func _rig_profile(root: Node3D, frame: Transform3D, prof: Array, width := 4.0) -> StaticBody3D:
	var pts := PackedVector3Array()
	var z0: float = (prof[0] as Vector2).x
	var z1: float = (prof[prof.size() - 1] as Vector2).x
	for x in [-width * 0.5, width * 0.5]:
		pts.append(Vector3(x, -0.4, -z0))
		for v in prof:
			pts.append(Vector3(x, (v as Vector2).y, -(v as Vector2).x))
		pts.append(Vector3(x, -0.4, -z1))
	var sh := ConvexPolygonShape3D.new()
	sh.points = pts
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var m := prof.size() + 2
	for k in m:
		var k1 := (k + 1) % m
		for idx in [k, m + k1, m + k, k, k1, m + k1]:
			st.add_vertex(pts[idx])
	for side in [0, m]:
		for k in range(1, m - 1):
			for idx in ([side, side + k, side + k + 1] if side == 0 else [side, side + k + 1, side + k]):
				st.add_vertex(pts[idx])
	st.generate_normals()
	return _rig_body(root, frame, sh, st.commit())


## The profile of an ordinary incline with a steep foot: flat ground to `ahead`, a band `band` m
## high at `band_deg`, then an incline at `inc_deg` rising `inc_rise` m, then a flat top 2 m deep.
func _incline_prof(ahead: float, band: float, band_deg: float, inc_deg: float, inc_rise: float) -> Array:
	var z := ahead
	var out := [Vector2(z - 0.3, -0.4), Vector2(z, 0.0)]
	z += band / tan(deg_to_rad(band_deg))
	out.append(Vector2(z, band))
	z += inc_rise / tan(deg_to_rad(inc_deg))
	out.append(Vector2(z, band + inc_rise))
	out.append(Vector2(z + 2.0, band + inc_rise))
	return out


## Owner's phone playtest of dev-000033: an ordinary mossy incline whose foot is a short steep band
## (the head met it, he face-planted, got no purchase, and slid sideways along its foot). Now:
## straight at it or met at an angle, just holding the stick (no jump, no burst), he crawls up the
## band and walks on up the incline to the top; while a tall band (a cushion's wall, a designed
## jump) or a steep band with no purchase beyond it still stops him: no crawl, and he rests back
## at its foot every time (no adhesion, no ratchet).
func _test_gill_incline_transitions() -> void:
	var b := g.balls[0]
	var release := _hold_threats(b)
	p.invuln_t = 999
	var spot := _quiet_spot(0)
	var up := b.up_at(spot)
	var root := Node3D.new()
	g.add_child(root)
	var crawl_cases := [
		["0.25 m band at 70, 30 deg incline", _incline_prof(1.4, 0.25, 70.0, 30.0, 0.9), 0.0],
		["0.45 m band at 62, 35 deg incline", _incline_prof(1.4, 0.45, 62.0, 35.0, 0.8), 0.0],
		["0.55 m band at 75, 20 deg incline", _incline_prof(1.4, 0.55, 75.0, 20.0, 0.5), 0.0],
		["0.3 m band at 80, 40 deg incline", _incline_prof(1.4, 0.3, 80.0, 40.0, 0.8), 0.0],
		["0.25 m band at 70, met at 35 deg", _incline_prof(1.4, 0.25, 70.0, 30.0, 0.9), 35.0],
		["0.45 m band at 62, met at 50 deg", _incline_prof(1.4, 0.45, 62.0, 35.0, 0.8), 50.0],
		["0.3 m band at 80, met at 25 deg", _incline_prof(1.4, 0.3, 80.0, 40.0, 0.8), -25.0],
	]
	var res := []
	var all_ok := true
	for cc in crawl_cases:
		var fwd0 := -MossBall.frame_at(up, 0.0).z
		var fwd := fwd0.rotated(up, deg_to_rad(float(cc[2])))
		# (The rig faces its own way; he comes at it from `fwd`, at an angle to it.)
		var frame := Transform3D(Basis(fwd0.cross(up), up, -fwd0), b.surface_point(up))
		var prof: Array = cc[1]
		var top: float = (prof[prof.size() - 1] as Vector2).y
		var body := _rig_profile(root, frame, prof, 8.0)
		await t.frames(2)
		var start := b.surface_point(up, 0.05) - fwd * 0.2
		place_at(0, start, fwd)
		await t.seconds(0.4)
		var m0: int = p.mantles
		var t_top := -1.0
		for f in 60 * 5:
			stick_toward(fwd)
			await t.frames(1)
			if t_top < 0.0 and p.grounded and _rig_h(frame) > top - 0.1:
				t_top = f / 60.0
		p.bot_input = Vector2.ZERO
		var why := "" if t_top > 0.0 else " (" + str((p.call("crawl_probe", fwd) as Dictionary).get("why", "crawlable") if p.has_method("crawl_probe") else "-") + ")"
		var ok := t_top > 0.0 and p.mantles > m0
		all_ok = all_ok and ok
		res.append("%s: %s, %d crawls" % [cc[0], ("on top in %.2f s" % t_top) if t_top > 0.0 else "NOT up (at %.2f m of %.2f)%s" % [_rig_h(frame), top, why], p.mantles - m0])
		body.free()
		await t.frames(2)
	t.check("incline_with_steep_foot_crawled", all_ok, "; ".join(res))
	# Barriers: a cushion-like wall (0.85 m at 75 degrees, then its rounded rim), a steep band with
	# nowhere to plant beyond it (on up at 58 degrees), and a sheer 1.2 m face.
	var bars := [
		["cushion wall 0.85 m at 75", [Vector2(1.1, -0.4), Vector2(1.4, 0.0), Vector2(1.4 + 0.85 / tan(deg_to_rad(75.0)), 0.85), Vector2(1.9 + 0.85 / tan(deg_to_rad(75.0)), 1.1), Vector2(4.0, 1.1)]],
		["band then 58 deg on up", [Vector2(1.1, -0.4), Vector2(1.4, 0.0), Vector2(1.4 + 0.3 / tan(deg_to_rad(70.0)), 0.3), Vector2(1.4 + 0.3 / tan(deg_to_rad(70.0)) + 2.0 / tan(deg_to_rad(58.0)), 2.3), Vector2(6.0, 2.3)]],
		["sheer 1.2 m face", [Vector2(1.1, -0.4), Vector2(1.4, 0.0), Vector2(1.45, 1.2), Vector2(4.0, 1.2)]],
	]
	var bres := []
	var bars_ok := true
	for bc in bars:
		var fwd := -MossBall.frame_at(up, 0.0).z
		var frame := Transform3D(Basis(fwd.cross(up), up, -fwd), b.surface_point(up))
		var body := _rig_profile(root, frame, bc[1], 8.0)
		await t.frames(2)
		for ang in [0.0, 40.0]:
			var d := fwd.rotated(up, deg_to_rad(ang))
			place_at(0, b.surface_point(up, 0.05), d)
			await t.seconds(0.3)
			var m0: int = p.mantles
			var highs := []
			var rests := []
			for k in 3:
				var hi := -INF
				for f in 70:
					stick_toward(d)
					await t.frames(1)
					hi = maxf(hi, height())
				p.bot_input = Vector2.ZERO
				await t.seconds(0.5)
				highs.append(snappedf(hi, 0.01))
				rests.append(snappedf(height(), 0.01))
			var ok: bool = p.mantles == m0 and highs.max() < 0.25 and rests.max() < 0.1 and highs[2] <= highs[0] + 0.05
			bars_ok = bars_ok and ok
			bres.append("%s at %d deg: pushes reach %s m, rests at %s, %d crawls" % [bc[0], int(ang), str(highs), str(rests), p.mantles - m0])
		body.free()
		await t.frames(2)
	t.check("incline_barriers_still_stop_him", bars_ok, "; ".join(bres))
	root.queue_free()
	release.call()
	# Real authored ground (found by _phase_incline_survey, where dev-000033 stopped dead): an
	# arch's end on Canopy Spire's ball rising out of the moss with a steep lip at its foot, and a
	# ridge's flank on the first ball with a steep kink low on it. Holding forward, he gets up.
	var real := [[2, -63.4, -119.9, 146.0, 0.8, "arch end, ball 3"], [0, -63.5, 174.3, 101.0, 0.35, "ridge flank, ball 1"]]
	var rres := []
	var real_ok := true
	for rc in real:
		var bb := g.balls[int(rc[0])]
		var rel2 := _hold_threats(bb)
		var d := MossBall.dir_ll(float(rc[1]), float(rc[2]))
		var fr := MossBall.frame_at(d, 0.0)
		var hdg := deg_to_rad(float(rc[3]))
		var fw: Vector3 = fr.x * sin(hdg) - fr.z * cos(hdg)
		place_at(bb.index, bb.surface_point(d, 0.04), fw)
		await t.seconds(0.2)
		var m0: int = p.mantles
		var hi := 0.0
		for f in 150:
			stick_toward(fw)
			await t.frames(1)
			if p.grounded:
				hi = maxf(hi, height())
		p.bot_input = Vector2.ZERO
		var ok: bool = p.mantles > m0 and hi >= float(rc[4])
		real_ok = real_ok and ok
		rres.append("%s: up %.2f m, %d crawls" % [rc[5], hi, p.mantles - m0])
		rel2.call()
	t.check("incline_real_terrain_crawled", real_ok, "; ".join(rres))
	p.invuln_t = 0.0


# --- Incline survey (diagnostic, run by name) ------------------------------------------------

## The ground straight ahead of `start` along `fwd`: [[s, h, collider, normal·up], ...] every `step`
## metres up to `reach` (h above `start`'s own distance from the ball's centre), or short over a gap.
func _scan_ahead(b: MossBall, space: PhysicsDirectSpaceState3D, start: Vector3, fwd: Vector3, reach := 2.6, step := 0.08) -> Array:
	var c := b.global_position
	var r0 := (start - c).length()
	var out := []
	var q := PhysicsRayQueryParameters3D.new()
	q.collision_mask = 1 | 2
	q.hit_back_faces = false
	var q2 := PhysicsRayQueryParameters3D.new()
	q2.collision_mask = 1 | 2
	var top_prev := c + b.up_at(start) * (r0 + 2.0)
	for k in int(reach / step) + 1:
		var s := k * step
		var dir := b.up_at(start + fwd * s)
		q.from = c + dir * (r0 + 2.0)
		q.to = c + dir * (r0 - 1.0)
		# (Something rising through 2 m between the columns: a tall wall, the profile ends there.)
		q2.from = top_prev
		q2.to = q.from
		top_prev = q.from
		if k > 0 and not space.intersect_ray(q2).is_empty():
			return out
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return out
		out.append([s, ((hit["position"] as Vector3) - c).length() - r0, hit["collider"], (hit["normal"] as Vector3).dot(dir)])
	return out


## A steep band in a profile from _scan_ahead: {i0, i1, s0, s1, rise, steepest (deg), beyond (deg over
## the next 0.5 m), beyond_ok (walkable ground goes on past it), before_ok}, or {} when there is none.
func _steep_band(prof: Array, step := 0.08) -> Dictionary:
	var steep := tan(deg_to_rad(48.0))
	var i0 := -1
	for i in range(1, prof.size()):
		if (prof[i][1] - prof[i - 1][1]) / step > tan(deg_to_rad(52.0)):
			i0 = i - 1
			break
	if i0 < 0:
		return {}
	# (Back to where it starts to be steep.)
	while i0 > 0 and (prof[i0][1] - prof[i0 - 1][1]) / step > steep:
		i0 -= 1
	var i1 := i0 + 1
	var hi := 0.0
	while i1 < prof.size() and (prof[i1][1] - prof[i1 - 1][1]) / step > steep:
		hi = maxf(hi, (prof[i1][1] - prof[i1 - 1][1]) / step)
		i1 += 1
	i1 -= 1
	var before_ok := true
	for i in range(1, i0 + 1):
		if absf(prof[i][1] - prof[i - 1][1]) / step > tan(deg_to_rad(35.0)):
			before_ok = false
	var n_b := int(0.5 / step)
	var beyond_ok := i1 + n_b < prof.size()
	if beyond_ok:
		for i in range(i1 + 1, i1 + n_b + 1):
			if (prof[i][1] - prof[i - 1][1]) / step > tan(deg_to_rad(52.0)) or absf(prof[i][1] - prof[i - 1][1]) > 0.5:
				beyond_ok = false
	var beyond := NAN
	if i1 + n_b < prof.size():
		beyond = rad_to_deg(atan((prof[i1 + n_b][1] - prof[i1][1]) / (n_b * step)))
	return {"i0": i0, "i1": i1, "s0": prof[i0][0], "s1": prof[i1][0], "rise": prof[i1][1] - prof[i0][1], "steepest": rad_to_deg(atan(hi)),
			"beyond": beyond, "beyond_ok": beyond_ok, "before_ok": before_ok, "h_top": prof[i1][1]}


func _collider_kind(b: MossBall, col: Object) -> String:
	if col == b.static_body:
		return "ground"
	if col is Node:
		var nd := col as Node
		return str(nd.get_meta("terrain_kind", nd.get_meta("grounded", nd.get_class()))) + ":" + str(nd.name)
	return "?"


## Diagnostic: every place on every ball where, walking straight in from open, gentle ground, the
## ground ahead rises through a steep band (over 52 degrees, what the body treats as wall): he is
## driven straight at it (just the stick, no jump) and whether he gets up onto the ground beyond is
## logged, with the band's height, its steepest part, what lies beyond it and what it is.
## --sball=<i> one ball; --scap=<n> pushes per ball; --sstep=<m> start spacing.
func _phase_incline_survey() -> void:
	var space := g.get_world_3d().direct_space_state
	p.invuln_t = 99999
	var only_ball := int(Settings.test_args.get("sball", "-1"))
	var cap := int(Settings.test_args.get("scap", "90"))
	var spacing := float(Settings.test_args.get("sstep", "2.0"))
	var totals := {}
	var json_rows := []
	for b in g.balls:
		if only_ball >= 0 and b.index != only_ball:
			continue
		var release := _hold_threats(b)
		var n := int(4.0 * PI * b.radius * b.radius / (spacing * spacing))
		var seen := {}
		var cands := []
		var sq := PhysicsShapeQueryParameters3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 0.3
		sq.shape = sph
		sq.collision_mask = 1 | 2 | LevelBuilder.CLIMB_LAYER
		for i in n:
			# (A Fibonacci lattice over the ball.)
			var yy := 1.0 - 2.0 * (i + 0.5) / n
			var rr := sqrt(1.0 - yy * yy)
			var th := PI * (3.0 - sqrt(5.0)) * i
			var d := Vector3(cos(th) * rr, yy, sin(th) * rr)
			if b.ravine_carve(d) > 0.02:
				continue
			var gp := b.surface_point(d)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(gp + d * 3.0, gp - d * 0.5, 1 | 2))
			if hit.is_empty() or (hit["normal"] as Vector3).dot(d) < 0.9 or absf(b.altitude(hit["position"])) > 0.08:
				continue
			var start: Vector3 = hit["position"]
			sq.transform = Transform3D(Basis(), start + d * 0.36)
			if not space.intersect_shape(sq, 1).is_empty():
				continue
			var fr := MossBall.frame_at(d, 0.0)
			for k in 8:
				var fwd: Vector3 = (-fr.z).rotated(d, TAU * (k + 0.37 * (i % 3)) / 8.0)
				var prof := _scan_ahead(b, space, start, fwd)
				if prof.size() < 20:
					continue
				var band := _steep_band(prof)
				if band.is_empty() or not band["before_ok"] or band["s0"] < 0.5 or band["rise"] < 0.08 or band["rise"] > 1.6:
					continue
				var foot: Vector3 = start + fwd * float(band["s0"])
				var key := str((foot - b.global_position).snapped(Vector3.ONE * 1.5)) + ":" + str(k % 4)
				if seen.has(key):
					continue
				seen[key] = true
				band["start"] = start
				band["fwd"] = fwd
				band["kind"] = _collider_kind(b, prof[band["i1"]][2])
				cands.append(band)
		# Crawlable-looking first (a short band with walkable ground on beyond it), then the rest.
		cands.sort_custom(func(x, y): return (10.0 if x["beyond_ok"] else 0.0) - x["rise"] > (10.0 if y["beyond_ok"] else 0.0) - y["rise"])
		var stride := maxi(1, int(ceil(cands.size() / float(cap))))
		t.log_line("SURVEY ball %d: %d starts, %d candidate bands, pushing every %d" % [b.index + 1, n, cands.size(), stride])
		for ci in range(0, cands.size(), stride):
			var band: Dictionary = cands[ci]
			var start: Vector3 = band["start"]
			var fwd: Vector3 = band["fwd"]
			var u0 := b.up_at(start)
			# (What the controller itself reads there, from just short of the band.)
			var verdict := "-"
			if p.has_method("crawl_probe"):
				var near: Vector3 = start + fwd * maxf(0.0, float(band["s0"]) - 0.5)
				var nu := b.up_at(near)
				var nh := space.intersect_ray(PhysicsRayQueryParameters3D.create(near + nu * 0.5, near - nu * 0.5, 1 | 2))
				if not nh.is_empty():
					place_at(b.index, nh["position"] + nu * 0.02, fwd)
					await t.frames(3)
					var pr: Dictionary = p.call("crawl_probe", fwd)
					verdict = ("crawl %.2f" % float(pr["rise"])) if pr.get("crawl", false) else (str(pr.get("why", "?")) + (" %.2f" % float(pr["rise"]) if pr.has("rise") else ""))
			place_at(b.index, start + u0 * 0.04, fwd)
			await t.frames(6)
			var m0: int = p.mantles
			var r0 := (start - b.global_position).length()
			var best_h := -INF
			var best_s := -INF
			var blocked := 0
			for f in 150:
				stick_toward(fwd)
				await t.frames(1)
				if g.cinematic != "":
					break
				var off := p.global_position - start
				best_s = maxf(best_s, off.dot(fwd))
				if p.grounded:
					best_h = maxf(best_h, (p.global_position - b.global_position).length() - r0)
				blocked += 1 if p._blocked else 0
			p.bot_input = Vector2.ZERO
			var off2 := p.global_position - start
			var side := absf(off2.dot(fwd.cross(u0)))
			var over: bool = best_h >= float(band["h_top"]) - 0.12 and best_s >= float(band["s1"]) - 0.05
			var lat := rad_to_deg(asin(clampf(u0.y, -1.0, 1.0)))
			var lon := rad_to_deg(atan2(u0.x, u0.z))
			var f0 := MossBall.frame_at(u0, 0.0)
			var hd := int(rad_to_deg(atan2(fwd.dot(f0.x), -fwd.dot(f0.z))))
			var row := "ball %d (%.1f, %.1f) hd %d: band at %.2f m, rise %.2f m, steepest %.0f deg, beyond %s deg (%s), %s -> %s: up %.2f m, along %.2f m, side %.2f m, blocked %d f, pulls %d, probe: %s" % [
					b.index + 1, lat, lon, hd, band["s0"], band["rise"], band["steepest"],
					"-" if is_nan(band["beyond"]) else str(snappedf(band["beyond"], 1.0)), "walkable" if band["beyond_ok"] else "no purchase", band["kind"],
					"OVER" if over else "STUCK", best_h, best_s, side, blocked, p.mantles - m0, verdict]
			t.log_line("SURVEY " + row)
			var cls: String = ("crawlable" if band["beyond_ok"] and band["rise"] <= 0.7 else ("tall" if band["beyond_ok"] else "nopurchase")) + ("_over" if over else "_stuck")
			totals[cls] = int(totals.get(cls, 0)) + 1
			json_rows.append({"ball": b.index, "lat": lat, "lon": lon, "hd": hd, "fwd": [fwd.x, fwd.y, fwd.z], "start": [start.x, start.y, start.z], "s0": band["s0"], "s1": band["s1"],
					"rise": band["rise"], "steepest": band["steepest"], "beyond": 0.0 if is_nan(band["beyond"]) else band["beyond"], "beyond_ok": band["beyond_ok"],
					"kind": band["kind"], "over": over, "up": best_h, "along": best_s, "side": side, "pulls": p.mantles - m0, "probe": verdict})
			for f in 60 * 5:
				if g.cinematic == "" and p.state == "normal":
					break
				await t.frames(1)
			p.restore_full()
		release.call()
	t.log_line("SURVEY TOTALS " + str(totals))
	var fo := FileAccess.open(t.out_dir.path_join("incline_survey.json"), FileAccess.WRITE)
	if fo:
		fo.store_string(JSON.stringify(json_rows))
	t.check("incline_survey_ran", not json_rows.is_empty(), str(totals))



## Diagnostic (run by name): how much his body visibly bends in ordinary play, from the gameplay
## camera. Each scenario is driven with the stick exactly as a player would (camera-relative, the
## camera assisting behind him) with the follow-through on and off; logged per scenario: whether
## the follow runs (follow, conform), the head-to-tail bend (mean |signed|, peak), and how far the
## tail tip and the hips sit on screen from where a rigid body would put them (pixels at the
## viewport's size), plus the gameplay body's own turn (so responsiveness can be compared).
func _phase_loco_diag() -> void:
	var b := g.balls[0]
	var release := _hold_threats(b)
	p.invuln_t = 99999
	var spot := _quiet_spot(0)
	var up := b.up_at(spot)
	var fwd := -MossBall.frame_at(up, 0.0).z
	var m := p.model
	var vp := g.get_viewport().get_visible_rect().size
	var n := AxolotlModel.BONE_Z.size()
	var scen := {
		"straight": func(f: int) -> Vector2: return Vector2(0, 1),
		"broad_turn": func(f: int) -> Vector2: return Vector2(0, 1) if f < 30 else Vector2(0.45, 0.9).normalized(),
		"sharp_turn": func(f: int) -> Vector2: return Vector2(0, 1) if f < 30 else Vector2(1, 0.1).normalized(),
		"reverse": func(f: int) -> Vector2: return Vector2(0, 1) if f < 40 else Vector2(0.15, -1).normalized(),
		"zigzag": func(f: int) -> Vector2: return Vector2(0.8 * (1.0 if (f / 25) % 2 == 0 else -1.0), 0.8).normalized(),
		"turn_in_place": func(f: int) -> Vector2: return Vector2(1, 0) if f < 10 else Vector2.ZERO,
	}
	for follow_on in [false, true]:
		m.follow = follow_on
		for name_ in scen:
			place_at(0, b.surface_point(up, 0.05), fwd)
			await t.seconds(0.6)
			var fn: Callable = scen[name_]
			var bend_sum := 0.0
			var bend_pk := 0.0
			var tail_px: Array[float] = []
			var hip_px: Array[float] = []
			var flags := {}
			var yaw_turned := 0.0
			var prev_f := p.facing
			for f in 100:
				p.bot_input = fn.call(f)
				await t.frames(1)
				flags["%s/%s" % [m.follow, m.conform]] = int(flags.get("%s/%s" % [m.follow, m.conform], 0)) + 1
				yaw_turned += absf(prev_f.signed_angle_to(p.facing, p.up))
				prev_f = p.facing
				var sb := _spine_yaw_signed(m, p.up)
				bend_sum += absf(sb)
				bend_pk = maxf(bend_pk, absf(sb))
				var sk := m.skeleton
				var cam: Camera3D = g.cam
				for pair in [[n - 1, tail_px], [5, hip_px]]:
					var bi: int = pair[0]
					var actual: Vector3 = sk.global_transform * sk.get_bone_global_pose(bi).origin
					var rigid: Vector3 = sk.global_transform * sk.get_bone_global_rest(bi).origin
					if not cam.is_position_behind(actual):
						(pair[1] as Array[float]).append(cam.unproject_position(actual).distance_to(cam.unproject_position(rigid)))
			p.bot_input = Vector2.ZERO
			tail_px.sort()
			hip_px.sort()
			var med := func(a: Array[float]) -> float: return a[a.size() / 2] if not a.is_empty() else -1.0
			var p90 := func(a: Array[float]) -> float: return a[int(a.size() * 0.9)] if not a.is_empty() else -1.0
			t.log_line("LOCODIAG follow=%s %-13s flags %s | bend mean %.0f deg peak %.0f deg | tail px med %.0f p90 %.0f max %.0f | hips px med %.0f p90 %.0f | body turned %.0f deg (viewport %dx%d)" % [
					str(follow_on), name_, str(flags), rad_to_deg(bend_sum / 100.0), rad_to_deg(bend_pk), med.call(tail_px), p90.call(tail_px), tail_px[-1] if not tail_px.is_empty() else -1.0,
					med.call(hip_px), p90.call(hip_px), rad_to_deg(yaw_turned), vp.x, vp.y])
	m.follow = true
	p.invuln_t = 0.0
	release.call()
	t.check("loco_diag_ran", true, "")



## Diagnostic (run by name): pushes him from `--at=ball:lat:lon:heading[;...]` for 3 s and logs,
## frame by frame around each crawl, where he is, what he stands on and what the crawl read.
func _phase_crawl_trace() -> void:
	p.invuln_t = 99999
	for spec in str(Settings.test_args.get("at", "")).split(";", false):
		var f := spec.split(":")
		var b := g.balls[int(f[0])]
		var release := _hold_threats(b)
		var d := MossBall.dir_ll(float(f[1]), float(f[2]))
		var fr := MossBall.frame_at(d, 0.0)
		var hdg := deg_to_rad(float(f[3]))
		var fw: Vector3 = fr.x * sin(hdg) - fr.z * cos(hdg)
		place_at(b.index, b.surface_point(d, 0.04), fw)
		await t.frames(6)
		var m0: int = p.mantles
		for k in 180:
			stick_toward(fw)
			await t.frames(1)
			var fc := p._floor_collider()
			if k % 10 == 0 or p.mantles != m0:
				t.log_line("TRACE %s f%d alt %.2f grounded %s blocked %s crawl_t %.2f mantles %d floor %s %s" % [spec, k, height(), p.grounded, p._blocked, p._mantle_t, p.mantles,
						_collider_kind(b, fc) if fc else "-", str(p._crawl.get("rise", "")) if p.mantles != m0 else ""])
				m0 = p.mantles
		p.bot_input = Vector2.ZERO
		release.call()
	t.check("crawl_trace_ran", true, "")


## Diagnostic (run only when named): crawlable transitions around every vortex mouth, and whether a
## crawl there carries him toward the mouth (into its 2 m entry radius).
func _phase_mouth_crawls() -> void:
	p.invuln_t = 99999
	var total := 0
	var crawls := 0
	var toward := 0
	var inside := 0
	for v in g.vortices:
		for at_b in [false, true]:
			var b: MossBall = v.ball_b if at_b else v.ball_a
			var m: Vector3 = v.mouth_pos(at_b)
			var mu := b.up_at(m)
			var fr := MossBall.frame_at(mu, 0.0)
			var here := 0
			for r in [2.2, 2.8, 3.4, 4.0, 4.6, 5.4]:
				for k in 16:
					var a := TAU * k / 16.0
					var off: Vector3 = (fr.x * cos(a) + fr.z * sin(a)) * r
					var d := b.up_at(m + off)
					place_at(b.index, b.surface_point(d, 0.04), fr.x)
					await t.frames(2)
					for h in 8:
						var hd := TAU * h / 8.0
						var dir: Vector3 = fr.x * cos(hd) + fr.z * sin(hd)
						total += 1
						var c: Dictionary = p.crawl_probe(dir)
						if c.get("crawl", false):
							crawls += 1
							here += 1
							var e: Vector3 = c["edge"]
							var f0 := (p.global_position - m) - p.up * (p.global_position - m).dot(p.up)
							var f1 := (e - m) - p.up * (e - m).dot(p.up)
							if f1.length() < f0.length() - 0.1:
								toward += 1
							if f1.length() < 2.3:
								inside += 1
								t.log_line("MOUTHCRAWL ball %d mouth %s r %.1f az %d hd %d rise %.2f edge_to_mouth %.2f" % [b.index + 1, "b" if at_b else "a", r, k, h, float(c["rise"]), f1.length()])
			t.log_line("MOUTH ball %d end %s crawls %d" % [b.index + 1, "b" if at_b else "a", here])
	t.log_line("MOUTHSUM probes %d crawls %d toward_mouth %d edge_within_2.3m %d" % [total, crawls, toward, inside])
	t.check("mouth_crawls_ran", true, "")


# --- Skill tree and red starfish (docs/SKILL_TREE.md; the checks live in skill_tests.gd) ----------

var _sk


func _skills():
	if _sk == null:
		_sk = load("res://scripts/tests/skill_tests.gd").new(self)
	return _sk


func _test_skilltree_graph() -> void:
	await _skills().graph()


func _test_progress_store() -> void:
	await _skills().store()


func _test_starfish_spots() -> void:
	await _skills().spots()


func _test_starfish_pickup() -> void:
	await _skills().pickup()


func _test_skill_ui() -> void:
	await _skills().ui()


func _test_quick_gill() -> void:
	await _skills().quick()


func _test_lunge_skills() -> void:
	await _skills().lunge()


func _test_burst_skills() -> void:
	await _skills().burst()


func _test_glide_control() -> void:
	await _skills().glide_control()


func _test_glide_transfers() -> void:
	await _skills().glide_transfers()


func _test_mote_magnet() -> void:
	await _skills().magnet()


func _phase_starfish_survey() -> void:
	await _skills().survey()


func _phase_starfish_sweep() -> void:
	await _skills().sweep()


func _phase_glide_probe() -> void:
	await _skills().glide_probe()


## Opening audio (00037-opening-audio): the household-aquarium bed heard from the loading screen.
func _test_opening_audio() -> void:
	var paths := ["res://assets/audio/amb_water.wav", "res://assets/audio/amb_aerator.wav"]
	# A fresh director, as at launch: the bed starts silent and fades in, then glides, never jumps.
	var a := AudioDirector.new()
	g.add_child(a)
	await t.frames(1)
	var ok := a._water.stream != null and a._aerator.stream != null and a._water.playing and a._aerator.playing
	for p in [a._water, a._aerator]:
		var st := p.stream as AudioStreamWAV
		ok = ok and st != null and st.loop_mode != AudioStreamWAV.LOOP_DISABLED and p.bus == "Ambience"
	var lw := (a._water.stream as AudioStreamWAV).get_length() if a._water.stream else 0.0
	var la := (a._aerator.stream as AudioStreamWAV).get_length() if a._aerator.stream else 0.0
	t.check("opening_bed_loops", ok and absf(lw - 17.0) < 0.1 and absf(la - 13.0) < 0.1, "water %.1f s, aerator %.1f s (co-prime loops)" % [lw, la])
	var first := a.bed_levels()
	var worst_step := 0.0
	var prev := first
	for i in 150:
		await t.frames(1)
		var now := a.bed_levels()
		if prev.x > -40.0:
			worst_step = maxf(worst_step, absf(now.x - prev.x))
		prev = now
	t.check("opening_bed_fades_in", first.x < -30.0 and absf(prev.x - a.WATER_DB) < 0.6 and absf(prev.y - a.AERATOR_DB) < 0.6,
			"first %.1f dB, after 2.5 s water %.1f / aerator %.1f dB" % [first.x, prev.x, prev.y])
	# Title: the songs start and the bed eases under them, with no step over 0.2 dB a frame.
	a.set_ball(0, false)
	worst_step = 0.0
	prev = a.bed_levels()
	for i in 60:
		await t.frames(1)
		var now := a.bed_levels()
		worst_step = maxf(worst_step, absf(now.x - prev.x))
		prev = now
	t.check("opening_bed_eases_under_music", absf(prev.x - (a.WATER_DB + a.BED_UNDER_MUSIC_DB)) < 0.6 and worst_step <= a.BED_GLIDE / 60.0 + 0.01,
			"water %.1f dB, largest step %.2f dB/frame" % [prev.x, worst_step])
	a._song.stop()
	a.queue_free()
	await t.frames(2)
	# In the running game: exactly one player per bed layer (no stacking), routed through the Sound
	# slider's bus.
	var counts := {}
	var stack: Array[Node] = [g.get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is AudioStreamPlayer and (n as AudioStreamPlayer).stream != null:
			var rp := (n as AudioStreamPlayer).stream.resource_path
			if rp in paths:
				counts[rp] = int(counts.get(rp, 0)) + 1
	var amb := AudioServer.get_bus_index("Ambience")
	t.check("opening_bed_single_players_through_sound_bus", counts.get(paths[0], 0) == 1 and counts.get(paths[1], 0) == 1 and amb >= 0 and AudioServer.get_bus_send(amb) == "SFX",
			str(counts))


# --- onboarding (docs/ONBOARDING.md; scripts/tests/onboarding_tests.gd) -----------------------------

var _onb = null


func _onboarding():
	if _onb == null:
		_onb = load("res://scripts/tests/onboarding_tests.gd").new(self)
	return _onb


func _test_onb_progress() -> void:
	await _onboarding().progress()


func _test_onb_owner_save() -> void:
	await _onboarding().owner_save()


func _test_onb_per_run() -> void:
	await _onboarding().per_run()


func _test_onb_toggle() -> void:
	await _onboarding().toggle()


func _phase_onb_toggle() -> void:
	await _onboarding().phase_toggle()


func _test_onb_intro() -> void:
	await _onboarding().intro()


func _test_onb_feeding() -> void:
	await _onboarding().feeding()


func _test_onb_parasite() -> void:
	await _onboarding().parasite()


func _test_onb_feed_first() -> void:
	await _onboarding().feed_first()


func _test_onb_tunnel() -> void:
	await _onboarding().tunnel()


func _test_onb_starfish() -> void:
	await _onboarding().starfish()


func _test_onb_softlock() -> void:
	await _onboarding().softlock()


func _test_onb_relaunch() -> void:
	await _onboarding().relaunch()


func _test_onb_restoration_equal() -> void:
	await _onboarding().restoration_equal()


func _phase_onb_owner() -> void:
	await _onboarding().phase_owner()


func _phase_onb_write() -> void:
	await _onboarding().phase_write()


func _phase_onb_read() -> void:
	await _onboarding().phase_read()


func _phase_onb_kill() -> void:
	await _onboarding().phase_kill()



## Owner, 2026-10-02: a kill regrows its own area even when it dies elsewhere; an area searched a
## while starts helping (plume, then a guide toward the nearest outstanding target, then a count).
## Ledger row 36: a required parasite stays with the area it keeps dead. A fling no longer re-homes it
## where it lands; a chase may spill past the edge; far outside, it is put back home unseen.
func _test_home_coherence() -> void:
	var b: MossBall = g.player.ball
	var par: Parasite = null
	for q in b.parasites:
		if q.zone_id != "tut" and q.hp > 0 and q.state not in ["dying", "drifting", "gone"] and g.near_player(q.global_position) and q.global_position.distance_to(g.player.global_position) > 6.0:
			par = q
			break
	if par == null:
		t.check("home_coherence_setup", false, "no live parasite near Gill on ball %d" % g.balls.find(b))
		return
	if par.state == "init":
		par._init_on_ground()
	var home0 := par.home_dir
	# Flung (tail swipe, water cannon, a current): it lands somewhere else but keeps its home.
	par.hit_cd = 0.0
	par.fling(par.up * 4.0 + MossBall.frame_at(par.up, 0.0).x * 6.0)
	await t.seconds(2.5)
	t.check("fling_keeps_home", par.home_dir.angle_to(home0) < 0.001 and par.state != "flung", "home moved %.1f deg, state %s" % [rad_to_deg(par.home_dir.angle_to(home0)), par.state])
	par.set_physics_process(false)
	var side := MossBall.frame_at(home0, 0.0).x
	var at := func(k: float) -> Vector3:
		return b.surface_point(home0.rotated(side, par.home_radius * k).normalized(), par._ground_offset)
	par._set_state("graze")
	# A chase spilling past the edge is not a stray; well outside is.
	par.global_position = at.call(2.0)
	var spill_ok := not par.strayed()
	par.global_position = at.call(3.5)
	t.check("stray_only_well_outside", spill_ok and par.strayed(), "2.0 radii strayed=%s, 3.5 radii strayed=%s" % [not spill_ok, par.strayed()])
	# Returned home where nobody sees it (a camera looking away, in this same frame: nothing drawn).
	var look := Camera3D.new()
	g.add_child(look)
	look.global_position = b.global_position + home0 * (b.radius + 400.0)
	look.look_at(look.global_position + home0 * 10.0, MossBall.frame_at(home0, 0.0).z)
	look.make_current()
	var moved := par.return_home_unseen()
	g.cam.make_current()
	look.free()
	var ang := b.up_at(par.global_position).angle_to(home0)
	t.check("stray_returns_home_unseen", moved and ang < par.home_radius and not par.strayed(), "moved %s, %.1f deg from home (radius %.1f)" % [moved, rad_to_deg(ang), rad_to_deg(par.home_radius)])
	# In view it waits (never pops in or out before his eyes).
	par.global_position = at.call(3.5)
	var seen := par.return_home_unseen() if Repopulation.on_camera(g.cam, par.global_position, par.up) else false
	t.check("stray_waits_while_seen", not seen, "moved while on camera")
	par.global_position = b.surface_point(home0, par._ground_offset)
	par._set_state("graze")
	par.set_physics_process(true)


func _test_restore_hints() -> void:
	var b: MossBall = g.balls[0]
	var zid := ""
	var par: Parasite = null
	for q in b.parasites:
		var z: Dictionary = b.zones[q.zone_id]
		if q.zone_id != "tut" and q.hp > 0 and int(z["total"]) - int(z["done"]) >= 3:
			zid = q.zone_id
			par = q
			break
	if par == null:
		t.check("restore_hints_setup", false, "no zone with 3 outstanding targets on ball 1")
		return
	var z: Dictionary = b.zones[zid]
	# Outstanding targets are exactly the zone's unfinished events (no returners, nothing done).
	var left := RestoreHints.remaining(b, zid)
	t.check("hint_targets_are_outstanding", left.size() == int(z["total"]) - int(z["done"]), "%d targets, %d events left" % [left.size(), int(z["total"]) - int(z["done"])])
	# Killed far outside its area: the moss regrows at its home, not where it fell.
	var home := b.surface_point(par.spawn_dir)
	var away_dir := par.spawn_dir.rotated(MossBall.frame_at(par.spawn_dir, 0).x, deg_to_rad(float(z["radius"]) + 25.0)).normalized()
	var h_home := b.health_at(par.spawn_dir)
	var h_away := b.health_at(away_dir)
	var done0: int = z["done"]
	par.global_position = b.surface_point(away_dir, 0.3)
	t.check("kill_restores_home_spot", g.restore_spot(par).distance_to(home) < 0.01, "spot %.1f m from home" % g.restore_spot(par).distance_to(home))
	par.hp = 1
	par.hit_cd = 0.0
	if par.state == "init":
		par.state = "graze"
	par.hit(1, par.global_position + Vector3.UP)
	await t.seconds(2.0)
	var d_home := b.health_at(par.spawn_dir) - h_home
	var d_away := b.health_at(away_dir) - h_away
	t.check("kill_heals_home_not_death_spot", int(z["done"]) == done0 + 1 and d_home > 0.2 and absf(d_away) < 0.05, "home +%.2f, death spot %+.2f, zone %d -> %d" % [d_home, d_away, done0, int(z["done"])])
	# Hints: quiet first, then plumes, then a guide toward the nearest, then a count once.
	var h := RestoreHints.new()
	var gp := b.surface_point(z["dir"], 0.1)
	var stages := []
	for sec in 320:
		h.update(1.0, b, gp, false)
		if sec in [80, 100, 200, 310]:
			stages.append(h.stage)
	left = RestoreHints.remaining(b, zid)
	left.sort_custom(func(a: Vector3, c: Vector3) -> bool: return a.distance_squared_to(gp) < c.distance_squared_to(gp))
	var want: Vector3 = (left[0] - (gp + (gp - b.global_position).normalized() * 0.7)).normalized()
	t.check("hints_escalate_slowly", stages == [0, 1, 2, 3] and h.plumes > 0, "stages at 80/100/200/310 s: %s, plumes %d" % [stages, h.plumes])
	t.check("hint_guides_to_nearest_in_3d", h.last_guide_dir.dot(want) > 0.999, "guide . nearest %.4f" % h.last_guide_dir.dot(want))
	var st: float = h.stuck[h.zone]
	h.update(30.0, b, gp, true)
	var quiet_ok: bool = h.stage == 0 and is_equal_approx(h.stuck[h.zone], st)
	# Real progress (a kill or a capture, so the zone's tally stays true for later tests).
	var progressed := false
	for q in b.parasites:
		if q.zone_id == zid and q.hp > 0 and not q.returner:
			q.hp = 1
			q.hit_cd = 0.0
			if q.state == "init":
				q.state = "graze"
			progressed = q.hit(1, q.global_position + Vector3.UP)
			break
	if not progressed:
		for m in b.motes:
			if m.zone_id == zid and m.state in ["init", "wander"]:
				m.state = "done"
				g.mote_restored(m)
				break
	h.update(1.0, b, gp, false)
	t.check("hints_quiet_in_tutorial_and_reset_on_progress", quiet_ok and h.stage == 0 and h.stuck[h.zone] <= 1.01, "after progress: stage %d, %.0f s searched" % [h.stage, h.stuck[h.zone]])


## Owner, 2026-10-02: a root curtain that has drawn up out of its doorway is gone, not left shrunk
## and floating above it.
func _test_retract_gates_gone() -> void:
	var seen := []
	for b in g.balls:
		for gt in b.gates:
			if gt.kind != "retract":
				continue
			var was_open: bool = gt.is_open
			gt._apply(1.0)
			var gone: bool = not gt.visible
			gt._apply(1.0 if was_open else 0.0)
			seen.append("ball %d %s: cleared hidden %s, shut shown %s" % [b.index + 1, gt.zone_id, gone, gt.visible or was_open])
			if not gone or not (gt.visible or was_open):
				t.check("retract_gates_gone_when_open", false, ", ".join(seen))
				return
	t.check("retract_gates_gone_when_open", not seen.is_empty(), ", ".join(seen))


## Owner, 2026-10-02: backed against a pillar the camera jammed against his head, zoomed in at an
## odd angle. It now rises over what stands behind him (a low wall: a little; a tall pillar: up
## to looking down on him), keeps its distance where it can, and settles back once clear.
func _test_camera_rises_over() -> void:
	var b: MossBall = g.balls[0]
	var release := _hold_threats(b)
	var home := [p.ball.index, p.global_position, p.facing]
	var d := MossBall.dir_ll(-35, 120)
	var fr := MossBall.frame_at(d, 0)
	place_at(0, b.surface_point(d, 0.1), fr.z)
	await t.seconds(1.0)
	var out := []
	for tall in [1.6, 9.0]:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.7
		cyl.height = tall
		cs.shape = cyl
		body.add_child(cs)
		g.add_child(body)
		var up := b.up_at(p.global_position)
		var behind := -g.cam.yaw_dir
		body.global_transform = Transform3D(Basis(MossBall.frame_at(up, 0)), p.global_position + behind * 1.4 + up * (tall * 0.5 - 0.2))
		await t.seconds(2.0)
		var cam_d: float = g.cam.global_position.distance_to(p.global_position + up * 0.85)
		var rel: Vector3 = g.cam.global_position - body.global_position
		var horiz := (rel - up * rel.dot(up)).length()
		var inside: bool = horiz < 0.7 and absf(rel.dot(up)) < float(tall) * 0.5
		out.append([tall, g.cam._rise, cam_d, inside])
		body.queue_free()
		await t.seconds(3.0)
		out.append(["clear", g.cam._rise, g.cam._cur_dist])
	release.call()
	place_at(home[0], home[1], home[2])
	await t.frames(2)
	var low: Array = out[0]
	var high: Array = out[2]
	t.check("camera_rises_over_what_is_behind", float(low[1]) > 0.05 and float(low[2]) > 3.5 and float(high[1]) > 0.5 and float(high[2]) > 1.8 and not low[3] and not high[3]
			and float(out[1][1]) < 0.01 and float(out[3][1]) < 0.01 and float(out[3][2]) > 4.3,
			"low wall: rise %.2f rad, %.1f m from him; tall pillar: rise %.2f rad, %.1f m; after each: rise %.2f / %.2f, distance %.1f m" % [low[1], low[2], high[1], high[2], out[1][1], out[3][1], out[3][2]])
## Owner, 2026-10-02: every death costs the same (back to his checkpoint with a third of his
## fronds, nothing earned lost); a tunnel's arrival is the checkpoint on a new ball until a bloom;
## the ride ends in a soft assisted landing that his buttons can decorate but never derail.
func _test_death_and_arrival() -> void:
	var hs := []
	for m in [3, 4, 5, 6]:
		hs.append(Game.respawn_health(m))
	t.check("death_health_third_of_max", hs == [1, 2, 2, 2], "max 3/4/5/6 -> %s" % str(hs))
	var release := _hold_threats(g.balls[0])
	var b0: MossBall = g.balls[0]
	# (On the first ball: earlier tests may have left him anywhere.)
	place_at(0, b0.surface_point(b0.start_dir, 0.2), MossBall.frame_at(b0.start_dir, 0).z)
	await t.frames(2)
	var keep := [g.checkpoint, g.arrival.duplicate(), p.max_health]
	var earned0 := g.run_save.earned().size()
	var stars0 := g.gill.collected.size()
	var rest0: Array = []
	for b in g.balls:
		rest0.append(b.restoration)
	var away := MossBall.dir_ll(10, 40)
	var die := func(how: String) -> Array:
		place_at(p.ball.index, p.ball.surface_point(away if p.ball == b0 else p.ball.start_dir, 0.2), MossBall.frame_at(away, 0).z)
		await t.frames(2)
		var d0: int = g.stats["deaths"]
		p.invuln_t = 0.0
		if how == "ooze":
			g.ravine_fall(p)
		else:
			p.health = 0
			p.died.emit()
		for i in 60 * 8:
			await t.frames(1)
			if g.cinematic == "" and p.state == "normal":
				break
		var near := INF
		for par in p.ball.hostiles():
			if par.is_alive() and par.state in ["windup", "attack"]:
				near = minf(near, par.global_position.distance_to(p.global_position))
		return [p.global_position, p.health, int(g.stats["deaths"]) - d0, p.state, near, p.invuln_t]
	# A new run before any bloom: the safe start.
	g.checkpoint = null
	g.arrival = {}
	var r: Array = await die.call("hurt")
	var start := b0.surface_point(b0.start_dir, 0.2)
	t.check("death_before_any_bloom_goes_to_start", r[0].distance_to(start) < 1.0 and r[1] == Game.respawn_health(p.max_health) and r[2] == 1,
			"%.2f m from the start, %d fronds" % [r[0].distance_to(start), r[1]])
	# With a bloom: hurt and ooze deaths alike, at max 3..6, again and again.
	var bl: Bloom = null
	for x in b0.blooms:
		if x.is_placed():
			bl = x
			break
	g.checkpoint = bl
	var log := []
	var ok := true
	var i := 0
	for m in [3, 4, 5, 6, 6]:
		p.max_health = m
		p.health = m
		var how: String = ["hurt", "ooze"][i % 2]
		r = await die.call(how)
		var dist: float = r[0].distance_to(bl.respawn_point())
		var safe: bool = r[3] == "normal" and r[5] > 0.5 and r[4] > 6.5
		ok = ok and dist < 1.0 and r[1] == Game.respawn_health(m) and r[2] == 1 and safe
		log.append("%s max %d -> %d fronds, %.2f m, attacker %.1f m, invuln %.1f s" % [how, m, r[1], dist, r[4], r[5]])
		i += 1
	t.check("death_any_cause_to_bloom_with_third", ok, "; ".join(log))
	var rest_ok := true
	for k in g.balls.size():
		rest_ok = rest_ok and g.balls[k].restoration >= rest0[k]
	t.check("death_loses_nothing_earned", g.run_save.earned().size() >= earned0 and g.gill.collected.size() == stars0 and rest_ok,
			"earned %d -> %d, starfish %d -> %d, restoration kept %s" % [earned0, g.run_save.earned().size(), stars0, g.gill.collected.size(), rest_ok])
	# Every re-form spot is clear of the ooze and on top of the ground.
	var bad := []
	for b in g.balls:
		for x in b.blooms:
			var rp: Vector3 = x.respawn_point()
			if b.ravine_at(b.up_at(rp)) != "" or b.altitude(rp) < -0.05:
				bad.append("ball %d bloom" % (b.index + 1))
	for v in g.vortices:
		for rev in [false, true]:
			var a: Array = g.arrival_point(v, rev)
			var ab: MossBall = a[0]
			if ab.ravine_at(ab.up_at(a[1])) != "" or ab.altitude(a[1]) < -0.05:
				bad.append("arrival on ball %d" % (ab.index + 1))
	t.check("respawn_spots_safe", bad.is_empty(), str(bad))
	# Rides: each tunnel both ways, with the buttons mashed in turn.
	var modes := ["none", "swipe", "lunge", "jump", "stick", "mash"]
	var space := g.get_world_3d().direct_space_state
	var rides := []
	var worst := {"clip": 0, "turn": 0.0, "hand": 0.0, "level": 0.0, "off": 0.0, "up": 1.0, "walk": INF}
	var anims := {"swipe": false, "lunge": false, "burst": false}
	var n := 0
	for v in g.vortices:
		var was: bool = v.connected
		v.connected = true
		for rev in [false, true]:
			var mode: String = modes[n % modes.size()]
			n += 1
			var src: MossBall = v.ball_b if rev else v.ball_a
			place_at(src.index, src.surface_point(src.start_dir, 0.2), MossBall.frame_at(src.start_dir, 0).z)
			g._start_cinematic("travel", {"v": v, "reverse": rev})
			var prev := Vector3.INF
			var prev_q := Quaternion.IDENTITY
			var last_travel := Vector3.ZERO
			var f := 0
			while g.cinematic != "" and f < 60 * 12:
				var landing: bool = g.cinematic == "land"
				if landing:
					var press := ""
					match mode:
						"swipe": press = "swipe" if f % 6 == 0 else ""
						"lunge": press = "lunge" if f % 20 == 0 else ""
						"jump": press = "jump" if f % 10 == 0 else ""
						"mash": press = ["swipe", "lunge", "jump"][f % 3]
					if press != "":
						Input.action_press(press)
					if mode in ["stick", "mash"]:
						Input.action_press("move_left")
				await t.frames(1)
				for a in ["swipe", "lunge", "jump", "move_left"]:
					Input.action_release(a)
				f += 1
				if g.cinematic == "travel":
					last_travel = p.global_position
					continue
				if g.cinematic != "land":
					continue
				anims["swipe"] = anims["swipe"] or p.model.swipe_t >= 0.0
				anims["lunge"] = anims["lunge"] or p.model.lunge_t >= 0.0
				anims["burst"] = anims["burst"] or p.model.burst_t >= 0.0
				var pos := p.global_position
				var q := p.global_basis.orthonormalized().get_rotation_quaternion()
				if prev == Vector3.INF:
					worst["hand"] = maxf(worst["hand"], pos.distance_to(last_travel))
				else:
					var qq := PhysicsRayQueryParameters3D.create(prev, pos, 1)
					qq.exclude = [p.get_rid()]
					var to_end: float = pos.distance_to(g.cine_data["to"])
					if to_end > 0.15 and not space.intersect_ray(qq).is_empty():
						worst["clip"] += 1
					worst["turn"] = maxf(worst["turn"], prev_q.angle_to(q))
				prev = pos
				prev_q = q
			var a: Array = g.arrival_point(v, rev)
			var nrm: Vector3 = a[2]
			worst["off"] = maxf(worst["off"], p.global_position.distance_to(a[1]))
			worst["up"] = minf(worst["up"], p.up.dot(nrm))
			worst["level"] = maxf(worst["level"], absf((-p.global_basis.z).normalized().dot(nrm)))
			var ok_end: bool = g.cinematic == "" and p.state == "normal" and p.controls_enabled and p.ball == a[0] and not g.arrival.is_empty() and g.arrival["v"] == v and g.arrival["rev"] == rev
			# Straight back in his hands: he walks off at once.
			var at := p.global_position
			p.bot_input = Vector2(0, 1)
			await t.seconds(0.6)
			p.bot_input = Vector2.ZERO
			worst["walk"] = minf(worst["walk"], p.global_position.distance_to(at))
			rides.append("%d%s %s %s" % [vortices_index(v), "r" if rev else "", mode, "ok" if ok_end else "NOT DONE"])
		v.connected = was
	var all_done := true
	for x in rides:
		all_done = all_done and not x.ends_with("NOT DONE")
	t.check("vortex_lands_softly_on_the_ground", all_done and worst["clip"] == 0 and worst["turn"] < 0.12 and worst["hand"] < 0.5 and worst["off"] < 0.3 and worst["up"] > 0.98 and worst["level"] < 0.15,
			"%d rides; clipping frames %d, largest turn in a frame %.3f rad, hand-over jump %.2f m, off the spot %.2f m, up . ground %.3f, nose . ground %.3f; %s" % [rides.size(), worst["clip"], worst["turn"], worst["hand"], worst["off"], worst["up"], worst["level"], ", ".join(rides)])
	t.check("vortex_landing_actions_show_and_control_returns", anims["swipe"] and anims["lunge"] and anims["burst"] and worst["walk"] > 1.0,
			"seen swipe %s, lunge %s, burst %s; walked %.2f m in 0.6 s after touchdown" % [anims["swipe"], anims["lunge"], anims["burst"], worst["walk"]])
	# On the new ball before any bloom: a death goes back to the arrival point, not to another ball.
	var v0: Vortex = g.vortices[0]
	var land: Array = g.arrival_point(v0, false)
	var lb: MossBall = land[0]
	g.arrival = {"v": v0, "rev": false}
	place_at(lb.index, lb.surface_point(lb.start_dir, 0.2), MossBall.frame_at(lb.start_dir, 0).z)
	r = await die.call("hurt")
	t.check("death_after_arrival_goes_to_arrival", p.ball == lb and r[0].distance_to(land[1]) < 1.0, "ball %d, %.2f m from the arrival point" % [p.ball.index + 1, r[0].distance_to(land[1])])
	# Saved and continued: the arrival is in the run's world and leads back to the same point.
	var w: Dictionary = g._capture_world()
	var saved: Dictionary = w.get("arrival", {})
	t.check("arrival_checkpoint_saved", int(saved.get("v", -1)) == 0 and saved.get("rev", true) == false, str(saved))
	# A bloom touched there supersedes it.
	var nb: Bloom = null
	for x in lb.blooms:
		if x.is_placed():
			nb = x
			break
	if nb != null:
		place_at(lb.index, nb.global_position, MossBall.frame_at(lb.up_at(nb.global_position), 0).z)
		await t.frames(10)
		r = await die.call("ooze")
		t.check("bloom_supersedes_arrival", g.arrival.is_empty() and g.checkpoint == nb and r[0].distance_to(nb.respawn_point()) < 1.0,
				"arrival %s, checkpoint is that bloom %s, %.2f m from it" % [str(g.arrival), g.checkpoint == nb, r[0].distance_to(nb.respawn_point())])
	g.checkpoint = keep[0]
	g.arrival = keep[1]
	p.max_health = keep[2]
	p.restore_full()
	release.call()
	place_at(0, b0.surface_point(b0.start_dir, 0.2), MossBall.frame_at(b0.start_dir, 0).z)


func vortices_index(v: Vortex) -> int:
	return g.vortices.find(v)


## Owner, 2026-10-02: behind the title menu the current pushed Gill off a cliff into a ravine's
## ooze; he sank and stayed sunk (the menu runs no cinematics), and the orbit camera swung through
## the cliff. On the title no current moves him, the ooze does nothing, and the orbit stays in
## front of walls and above the ground.
func _test_title_safe() -> void:
	var was: String = g.state
	# A ball with a current, at its strongest band.
	var cb: MossBall = null
	for b in g.balls:
		if b.current_strength > 0.0:
			cb = b
			break
	var moved := -1.0
	if cb != null:
		var d := cb.current_axis.cross(MossBall.frame_at(cb.current_axis, 0).x).normalized()
		place_at(cb.index, cb.surface_point(d, 0.2), MossBall.frame_at(d, 0).z)
		await t.seconds(1.0)
		g.state = "title"
		var at := p.global_position
		await t.seconds(4.0)
		moved = p.global_position.distance_to(at)
		g.state = was
	# On a ravine floor of the first ball, with the title up: no ooze death, and the orbit camera
	# never inside the ground or behind a wall, all the way round.
	var b0: MossBall = g.balls[0]
	# (A floor spot open to the water above it: not under a bridge or a leaf.)
	var space0 := g.get_world_3d().direct_space_state
	var fd := Vector3.ZERO
	for cv in b0.carves:
		for pt in cv[0]:
			var dd: Vector3 = (pt as Vector3).normalized()
			var fp := b0.surface_point(dd, 0.4)
			if b0.ravine_at(dd) != "" and space0.intersect_ray(PhysicsRayQueryParameters3D.create(fp, fp + dd * 8.0, 1)).is_empty():
				fd = dd
				break
		if fd != Vector3.ZERO:
			break
	g.state = "title"
	g.cam.cinematic = true   # (as _enter_title: the orbit drives the camera)
	place_at(0, b0.surface_point(fd, 0.1), MossBall.frame_at(fd, 0).z)
	g.ravine_fall(p)
	await t.seconds(2.0)   # (the orbit blends in)
	var no_death: bool = g.cinematic == "" and p.state == "normal"
	var lowest := INF
	var blocked := 0
	var space := g.get_world_3d().direct_space_state
	for f in 60 * 55:
		await t.frames(1)
		if f % 6 != 0:
			continue
		var cp: Vector3 = g.cam.global_position
		var rel := cp - b0.global_position
		lowest = minf(lowest, rel.length() - b0.radius - b0.terrain_height(rel.normalized()))
		var q := PhysicsRayQueryParameters3D.create(p.global_position + p.up * 0.4, cp, 1)
		q.exclude = [p.get_rid()]
		if not space.intersect_ray(q).is_empty():
			blocked += 1
	g.state = was
	g.cam.cinematic = false
	t.check("title_no_current_no_ooze", (cb == null or moved < 0.3) and no_death,
			"moved %.2f m in 4 s on ball %d's current; ooze on the title: cinematic '%s', state %s" % [moved, cb.index + 1 if cb else 0, g.cinematic, p.state])
	t.check("title_camera_clear_round_him", lowest >= FollowCam.GROUND_CLEAR - 0.05 and blocked == 0,
			"lowest %.2f m above the ground, view blocked %d times over a full turn in a ravine" % [lowest, blocked])
	place_at(0, b0.surface_point(b0.start_dir, 0.2), MossBall.frame_at(b0.start_dir, 0).z)


## THE CAMERA SAFETY INVARIANT, attacked (owner, 2026-10-02: a class defect). Every kind of camera
## writer and transition, driven to its extremes; the frames actually drawn are audited
## (FollowCam._audit). First with the safety stage off on the death path, to prove the harness
## sees the class; then everything with it on: no drawn frame may be under a ball's ground or
## inside a solid. `corrected` counts the frames whose requested place was unsafe and was resolved.
func _test_camera_invariant() -> void:
	var cam: FollowCam = g.cam
	if cam.audited_frames == 0:
		t.check("camera_audit_runs", false, "no frame was audited (frame_pre_draw)")
		return
	var rows := []
	var b0: MossBall = g.balls[0]
	var hold := []
	for b in g.balls:
		hold.append(_hold_threats(b))
	# A slope with rising ground behind him: where a hill on ball 1 meets the flat.
	var slope_sites := []
	for bi in [0, 2, 4]:
		var b: MossBall = g.balls[bi]
		for h in b.hills.slice(0, 2):
			var fr := MossBall.frame_at(h[0], 0)
			slope_sites.append([bi, (h[0] as Vector3).rotated(fr.x, float(h[1]) * 1.05).normalized(), (h[0] as Vector3)])
	var face_from := func(site: Array) -> Vector3:
		var b: MossBall = g.balls[site[0]]
		var at := b.surface_point(site[1])
		var hill := b.surface_point(site[2])
		return at - hill   # (facing away from the hill: the camera behind him is over/into it)
	var die := func(how: String) -> void:
		p.invuln_t = 0.0
		if how == "ooze":
			g.ravine_fall(p)
		else:
			p.health = 1
			p.take_damage(1, p.global_position + p.facing)
		for i in 60 * 8:
			g.cam.pitch = FollowCam.PITCH_MIN
			await t.frames(1)
			if g.cinematic == "" and p.state == "normal":
				break
	# The harness sees the class: the death path with the stage off draws unsafe frames.
	var site: Array = slope_sites[0]
	place_at(site[0], g.balls[site[0]].surface_point(site[1], 0.1), face_from.call(site))
	await t.frames(5)
	cam.enforce = false
	var u0 := cam.unsafe_drawn
	await die.call("hurt")
	var off_unsafe := cam.unsafe_drawn - u0
	cam.enforce = true
	cam.unsafe_drawn = u0   # (deliberate: not counted against the suite-wide check)
	cam.unsafe_worst = ""
	var run := func(name: String, fn: Callable) -> void:
		var c0 := cam.corrected_frames
		var d0 := cam.unsafe_drawn
		var a0 := cam.audited_frames
		await fn.call()
		rows.append("%s: %d frames, %d corrected, %d unsafe" % [name, cam.audited_frames - a0, cam.corrected_frames - c0, cam.unsafe_drawn - d0])
	# 1. Free-look at its extremes: full down, full up, fast spins, walking, on every kind of ground.
	await run.call("free-look", func() -> void:
		for bi in [0, 2, 4]:
			var b: MossBall = g.balls[bi]
			var dirs := []
			for h in b.hills.slice(0, 3):
				dirs.append(h[0])
				dirs.append((h[0] as Vector3).rotated(MossBall.frame_at(h[0], 0).x, float(h[1]) * 0.8).normalized())
			for cv in b.carves.slice(0, 2):
				var pts: Array = cv[0]
				dirs.append((pts[pts.size() / 2] as Vector3).normalized())
			for k in 3:
				dirs.append(MossBall.dir_ll(-40.0 + k * 40.0, k * 100.0))
			for d in dirs:
				place_at(bi, b.surface_point(d, 0.2), MossBall.frame_at(d, 0).z)
				for f in 36:
					cam.pitch = FollowCam.PITCH_MIN if f % 12 < 8 else FollowCam.PITCH_MAX
					cam.swipe_delta = Vector2(0.25, 0.0)
					p.bot_input = Vector2(0, 1) if f % 3 == 0 else Vector2.ZERO
					await t.frames(1)
				p.bot_input = Vector2.ZERO)
	# 2. Deaths with the camera fully down and a slope behind: hurt deaths, repeated.
	await run.call("hurt deaths on slopes", func() -> void:
		for st in slope_sites:
			place_at(st[0], g.balls[st[0]].surface_point(st[1], 0.1), face_from.call(st))
			await t.frames(10)
			await die.call("hurt")
			await die.call("hurt"))
	# 3. Ooze deaths (any health), on a ravine floor.
	await run.call("ooze deaths", func() -> void:
		var pts: Array = b0.carves[0][0]
		for k in [1, pts.size() / 2]:
			var d: Vector3 = (pts[k] as Vector3).normalized()
			place_at(0, b0.surface_point(d, 0.1), MossBall.frame_at(d, 0).z)
			p.health = p.max_health
			await t.frames(5)
			await die.call("ooze"))
	# 4. Knocked about near ground and walls (not fatal), camera constrained.
	await run.call("knockback by terrain", func() -> void:
		for st in slope_sites.slice(0, 3):
			place_at(st[0], g.balls[st[0]].surface_point(st[1], 0.1), face_from.call(st))
			for k in 3:
				p.health = p.max_health
				p.invuln_t = 0.0
				p.take_damage(1, p.global_position - (face_from.call(st) as Vector3).normalized())
				for f in 40:
					cam.pitch = FollowCam.PITCH_MIN
					await t.frames(1))
	# 5. Tunnel rides and assisted landings, buttons mashed on the way down.
	await run.call("vortex rides + landings", func() -> void:
		for v in g.vortices:
			var was: bool = v.connected
			v.connected = true
			var src: MossBall = v.ball_a
			place_at(src.index, src.surface_point(src.start_dir, 0.2), MossBall.frame_at(src.start_dir, 0).z)
			g._start_cinematic("travel", {"v": v, "reverse": false})
			for f in 60 * 10:
				if g.cinematic == "land":
					Input.action_press(["swipe", "lunge", "jump"][f % 3])
				await t.frames(1)
				for a in ["swipe", "lunge", "jump"]:
					Input.action_release(a)
				if g.cinematic == "":
					break
			v.connected = was)
	# 6. Story shots: the reveal and a tunnel connection.
	await run.call("cinematic shots", func() -> void:
		place_at(0, b0.surface_point(b0.start_dir, 0.2), MossBall.frame_at(b0.start_dir, 0).z)
		g._start_cinematic("frame", {})
		for f in 60 * 5:
			await t.frames(1)
			if g.cinematic == "":
				break
		g._start_cinematic("connect", {"v": g.vortices[0]})
		for f in 60 * 6:
			await t.frames(1)
			if g.cinematic == "":
				break)
	# 7. Title orbit round him in a ravine and beside a hill, then back to play.
	await run.call("title orbit", func() -> void:
		var was: String = g.state
		var pts: Array = b0.carves[0][0]
		for d in [(pts[pts.size() / 2] as Vector3).normalized(), slope_sites[0][1]]:
			place_at(0, b0.surface_point(d, 0.1), MossBall.frame_at(d, 0).z)
			g.state = "title"
			cam.cinematic = true
			await t.seconds(12.0)
			g.state = was
			cam.cinematic = false
			await t.seconds(1.0))
	# 8. Pause and resume mid-death; a continued run's resume.
	await run.call("pause + resume + continue", func() -> void:
		var st: Array = slope_sites[1]
		place_at(st[0], g.balls[st[0]].surface_point(st[1], 0.1), face_from.call(st))
		p.invuln_t = 0.0
		p.health = 1
		p.take_damage(1, p.global_position + p.facing)
		await t.frames(20)
		g.get_tree().paused = true
		await t.frames(30)
		g.get_tree().paused = false
		for i in 60 * 6:
			await t.frames(1)
			if g.cinematic == "" and p.state == "normal":
				break
		g._resume_ball = p.ball.index
		g._resume_position()
		await t.frames(30))
	for r in hold:
		r.call()
	p.restore_full()
	place_at(0, b0.surface_point(b0.start_dir, 0.2), MossBall.frame_at(b0.start_dir, 0).z)
	await t.frames(2)
	var corrected := 0
	var unsafe := 0
	for r in rows:
		var parts := (r as String).split(", ")
		corrected += int(parts[1].split(" ")[0])
		unsafe += int(parts[2].split(" ")[0])
	t.check("camera_invariant_harness_sees_the_class", off_unsafe > 0, "with the safety stage off, the death path drew %d unsafe frames" % off_unsafe)
	t.check("camera_invariant_holds_everywhere", unsafe == 0 and corrected > 0,
			"%d requested places corrected, %d unsafe frames drawn; %s%s" % [corrected, unsafe, "; ".join(rows), "" if cam.unsafe_worst == "" else " | first: " + cam.unsafe_worst])


## Cohesion audit (2026-10-02): the top-left corner holds the Treasure Hunt box and the starfish
## chip; a starfish picked up during a hunt shows its chip below the box, never over it.
func _test_hud_corner() -> void:
	var tp: TreasurePlay = g.treasure
	tp._ensure_panel()
	var panel: TreasurePanel = tp.panel
	# (TreasurePlay shows the panel only while hunting: held still here.)
	tp.set_process(false)
	panel.visible = true
	panel._box.visible = true
	panel._name.text = "Golden snail shell"
	panel._count.text = "3 of 14 found"
	panel._layout()
	await t.frames(3)
	var chip := g.hud.star_chip
	g.hud.star_collected(4, 30, 1)
	await t.frames(2)
	var box := panel.box_rect()
	var cr := Rect2(chip.position, chip.size)
	var apart := box.size != Vector2.ZERO and not box.intersects(cr)
	panel.visible = false
	g.hud.star_collected(4, 30, 1)
	var home := is_equal_approx(chip.position.y, g.hud._safe.position.y + 40 * g.hud.canvas.scale_k)
	chip._t = -1.0
	chip.modulate.a = 0.0
	tp.set_process(true)
	t.check("hud_starfish_chip_clear_of_hunt_box", apart and home, "box %s, chip during hunt %s, chip after at y %.0f" % [box, cr, chip.position.y])
	var fonts := [panel._count.get_theme_font_size("font_size")]
	for l in panel._box.find_children("*", "Label", true, false):
		fonts.append((l as Label).get_theme_font_size("font_size"))
	t.check("hud_hunt_box_text_legible", fonts.min() >= 18, str(fonts))


## Cohesion audit probe (2026-10-02; run by name, reports only): how close each ball's threats and
## collectables sit to lethal ravine ooze. A parasite whose home area takes in ravine floor fights
## him at the edge; a collectable within 2 m of the floor baits a fall.
func _phase_cohesion_probe() -> void:
	var near_floor := func(b: MossBall, at: Vector3) -> float:
		var up := b.up_at(at)
		var fr := MossBall.frame_at(up, 0.0)
		for r in [0.0, 0.5, 1.0, 1.5, 2.0, 3.0, 4.0]:
			for k in 12:
				var off: Vector3 = (fr.x * cos(k * TAU / 12.0) + fr.z * sin(k * TAU / 12.0)) * r
				if b.ravine_at(b.up_at(at + off)) != "":
					return r
		return 99.0
	var lines := []
	for b: MossBall in g.balls:
		if b.carves.is_empty():
			lines.append("ball %d: no ravines" % (b.index + 1))
			continue
		var par_in := 0
		var par_names := []
		for pp in b.parasites:
			var hits := 0
			var fr := MossBall.frame_at(pp.home_dir, 0.0)
			for i in 120:
				var a := randf() * TAU
				var rr: float = sqrt(randf()) * pp.home_radius
				var d: Vector3 = pp.home_dir.rotated((fr.x * cos(a) + fr.z * sin(a)).normalized(), rr).normalized()
				if b.ravine_at(d) != "":
					hits += 1
			if hits > 0:
				par_in += 1
				par_names.append("%s %d%%" % [pp.zone_id, int(hits * 100 / 120)])
		var col := {"mote": 0, "bloom": 0, "food": 0, "starfish": 0}
		var tot := {"mote": 0, "bloom": 0, "food": 0, "starfish": 0}
		var sets := {"mote": b.motes, "bloom": b.blooms, "food": b.foods, "starfish": g.starfish.stars.filter(func(st): return is_instance_valid(st) and st.ball == b)}
		for key in sets:
			for it in sets[key]:
				if not is_instance_valid(it):
					continue
				tot[key] += 1
				if near_floor.call(b, (it as Node3D).global_position) <= 2.0:
					col[key] += 1
		lines.append("ball %d: %d ravines; parasites with ooze in their home area %d/%d [%s]; within 2 m of ooze: motes %d/%d, blooms %d/%d, food %d/%d, starfish %d/%d" % [
				b.index + 1, b.carves.size(), par_in, b.parasites.size(), ", ".join(par_names), col["mote"], tot["mote"], col["bloom"], tot["bloom"],
				col["food"], tot["food"], col["starfish"], tot["starfish"]])
	for l in lines:
		t.log_line("[COHESION] " + l)
	t.check("cohesion_probe_ran", lines.size() == g.balls.size(), "")


# --- whole-ball view on demand (ledger row 21; BallView) ---------------------------------

## The whole-ball view, on every ball: opened from the pause menu (and the pad's Back), the run stands
## still (no movement, damage or clock), the camera is far out and inside the tank, never drawn
## unsafe; any touch or button returns, to exactly the follow place it left, with control back.
func _test_ball_view() -> void:
	var bv: BallView = g.ball_view
	var cam: FollowCam = g.cam
	var mode0: int = Settings.input_mode
	var hold := []
	for b in g.balls:
		hold.append(_hold_threats(b))
	# The shot itself, statically: inside the glass and far out, from every side of every ball.
	var shot_ok := true
	var shot_bad := ""
	for b: MossBall in g.balls:
		for i in 26:
			var up := MossBall.dir_ll(-80.0 + (i % 9) * 20.0, i * 47.0)
			var face := MossBall.frame_at(up, 0).z
			for orbit in [0.0, 1.7, 3.6]:
				var sh := BallView.shot(b, up, face, orbit)
				var pos: Vector3 = sh[0]
				var inside := pos == BallView.in_tank(pos)
				var far := pos.distance_to(b.global_position) > b.radius + 12.0
				if not (inside and far) and shot_bad == "":
					shot_bad = "ball %d up %s: inside %s, %.1f m from centre" % [b.index + 1, up.snapped(Vector3.ONE * 0.01), inside, pos.distance_to(b.global_position)]
				shot_ok = shot_ok and inside and far
	t.check("ball_view_shot_inside_tank_and_far", shot_ok, shot_bad)
	var push := func(ev: InputEvent) -> void:
		Input.parse_input_event(ev)
	var rows := []
	var all_ok := true
	var d0 := cam.unsafe_drawn
	var c0 := cam.corrected_frames
	for b: MossBall in g.balls:
		place_at(b.index, b.surface_point(b.start_dir, 0.2), MossBall.frame_at(b.start_dir, 0).z)
		p.restore_full()
		await t.frames(20)
		var pos0 := p.global_position
		var cam0 := cam.global_transform
		var hp0: int = p.health
		var run0: float = g.clock.run_s
		# Moving when it opens: he must not drift while it shows.
		p.velocity = p.facing * 3.0
		var opened := true
		if b.index % 2 == 0:
			g.pause_menu.open()
			await t.frames(2)
			var btn := g.pause_menu.find_child("ViewWholeBall", true, false) as Button
			opened = btn != null and btn.visible and not btn.disabled and btn.size.y >= PauseMenu.MIN_TOUCH
			btn.pressed.emit()
		else:
			var ev := InputEventJoypadButton.new()
			ev.button_index = JOY_BUTTON_BACK
			ev.pressed = true
			push.call(ev)
			await t.frames(1)
			var ev2 := ev.duplicate() as InputEventJoypadButton
			ev2.pressed = false
			push.call(ev2)
		await t.frames(2)
		opened = opened and bv.active and g.get_tree().paused and not g.pause_menu.visible and not g.hud.visible
		# (From here the run must stand exactly still; the pad path lets one frame of play run first.)
		pos0 = p.global_position
		hp0 = p.health
		run0 = g.clock.run_s
		# While it shows nothing in the run may act on him (no threat, current or clock runs).
		var far := 0.0
		var frozen := true
		for f in 150:
			await t.frames(1)
			frozen = frozen and not p.can_process() and not g.can_process() and not g.ecosystem.can_process()
			far = maxf(far, cam.global_position.distance_to(b.global_position) - b.radius)
		var still := frozen and p.global_position.distance_to(pos0) < 0.01 and p.health == hp0 and absf(g.clock.run_s - run0) < 0.001
		# Any touch returns (a key on odd balls).
		if b.index % 2 == 0:
			var tev := InputEventScreenTouch.new()
			tev.pressed = true
			tev.position = Vector2(640, 360)
			push.call(tev)
			await t.frames(1)
			var tev2 := tev.duplicate() as InputEventScreenTouch
			tev2.pressed = false
			push.call(tev2)
		else:
			var kev := InputEventJoypadButton.new()
			kev.button_index = JOY_BUTTON_A
			kev.pressed = true
			push.call(kev)
			await t.frames(1)
			var kev2 := kev.duplicate() as InputEventJoypadButton
			kev2.pressed = false
			push.call(kev2)
		var back_f := 0
		for f in 60 * 4:
			await t.frames(1)
			back_f = f
			if not bv.active:
				break
		var cam_back := cam.global_transform.origin.distance_to(cam0.origin)
		var home := not bv.active and not g.get_tree().paused and g.hud.visible and p.controls_enabled \
				and p.global_position.distance_to(pos0) < 0.05 and cam_back < 0.25 and cam.process_mode == Node.PROCESS_MODE_INHERIT
		var ok := opened and still and far > 20.0 and home
		all_ok = all_ok and ok
		rows.append("ball %d: open %s, still %s, %.0f m out, back in %d frames, camera %.2f m off%s" % [b.index + 1, opened, still, far, back_f, cam_back, "" if ok else " FAIL"])
		p.velocity = Vector3.ZERO
	t.check("ball_view_every_ball_frozen_and_returns", all_ok, "; ".join(rows))
	t.check("ball_view_never_drawn_unsafe", cam.unsafe_drawn == d0, "%d unsafe, %d corrected%s" % [cam.unsafe_drawn - d0, cam.corrected_frames - c0, "" if cam.unsafe_worst == "" else ": " + cam.unsafe_worst])
	# Not mid-cinematic: the menu entry is greyed and the pad button does nothing.
	var b0: MossBall = g.balls[0]
	place_at(0, b0.surface_point(b0.start_dir, 0.2), MossBall.frame_at(b0.start_dir, 0).z)
	g._start_cinematic("frame", {})
	await t.frames(2)
	g.pause_menu.open()
	await t.frames(2)
	var greyed := (g.pause_menu.find_child("ViewWholeBall", true, false) as Button).disabled
	g.pause_menu.close()
	var refused := not bv.open()
	for f in 60 * 6:
		await t.frames(1)
		if g.cinematic == "":
			break
	t.check("ball_view_not_during_cinematics", greyed and refused and not bv.active, "greyed %s, refused %s" % [greyed, refused])
	# Android back closes it too.
	await t.frames(30)
	var opened2 := bv.open()
	await t.frames(30)
	g._go_back()
	for f in 60 * 3:
		await t.frames(1)
		if not bv.active:
			break
	# The caption: name, % restored, and the tunnel's threshold only while one out is still shut.
	var vb: Vortex = g.vortices[0]
	var vwas := vb.connected
	vb.connected = false
	var cap_shut := BallView.caption(vb.ball_a, g.vortices)
	vb.connected = true
	var cap_open := BallView.caption(vb.ball_a, [vb])
	vb.connected = vwas
	t.check("ball_view_caption", cap_shut.begins_with(vb.ball_a.display_name) and cap_shut.contains("% restored") and cap_shut.contains("opens at 70%")
			and not cap_open.contains("opens at"), "%s | %s" % [cap_shut, cap_open])
	t.check("ball_view_back_closes", opened2 and not bv.active and not g.get_tree().paused and not g.pause_menu.visible, "")
	for r in hold:
		r.call()
	p.restore_full()
	# (The pad presses above switched the HUD to controller mode.)
	Settings._set_mode(mode0)


## The whole suite, every test's camera: no frame drawn under a ball's ground or inside a solid, and
## play never drawn through another camera.
func _test_camera_never_drawn_unsafe() -> void:
	var cam: FollowCam = g.cam
	t.check("camera_never_drawn_unsafe_suite_wide", cam.audited_frames > 1000 and cam.unsafe_drawn == 0,
			"%d frames audited, %d unsafe%s" % [cam.audited_frames, cam.unsafe_drawn, "" if cam.unsafe_worst == "" else ": first " + cam.unsafe_worst])
