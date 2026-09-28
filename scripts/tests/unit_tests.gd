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
	await t.seconds(0.5)
	var only: String = Settings.test_args.get("only", "")
	for name_ in ["_test_startup", "_test_ota_and_version", "_test_mesh_winding", "_test_terrain", "_test_terrain_grounded", "_test_no_floating_platforms", "_test_parasite_locomotion", "_test_placements", "_test_tutorial_route", "_test_sphere_walk", "_test_jump_and_burst", "_test_coyote_and_buffer", "_test_swipe_direction_and_stages", "_test_hard_landing", "_test_food", "_test_food_reach", "_test_darter_and_burrower", "_test_food_repopulates", "_test_motes", "_test_checkpoint_and_regen", "_test_crumble", "_test_restoration_continuity", "_test_vortex", "_test_current", "_test_canopy", "_test_canopy_plain_jumps", "_test_caves", "_test_mounds", "_test_vegetation", "_test_vortex_mouths_clear", "_test_route_audit", "_test_new_areas", "_test_music", "_test_run_clock", "_test_completion_catalog", "_test_run_save_file", "_test_run_timer_live", "_test_run_continue", "_phase_continue_write", "_phase_continue_read", "_test_upgrades", "_test_ui", "_test_all_clear"]:
		# "_phase_*" tests are halves of a relaunch test: they run only when asked for by name
		# (in a child process started by _test_run_continue).
		if name_.begins_with("_phase") and only != name_:
			continue
		if only == "" or name_.contains(only):
			await call(name_)


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
	# is choosing a stored package, and an automatic check needs boot health first.
	var net_before := false
	# (boot_marks exists from runtime r5 on; the game layer also runs on r4 bootstraps.)
	for m in StartupTrace.timeline(Boot.get("boot_marks") if "boot_marks" in Boot else []):
		if str(m[0]).contains("automatic OTA check") and m[1] / 1000.0 < usable:
			net_before = true
	t.check("startup_no_ota_check_before_usable", usable >= 0.0 and not net_before and not Boot.auto_check("start"), "")
	t.check("startup_summary_for_pause_menu", StartupTrace.summary().begins_with("Last launch: Mote on screen after"), StartupTrace.summary())


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
	t.check("cave_mouths_arched_not_rectangular", caves.size() == 7 and arched, ", ".join(dims))
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
				bad_tops.append("ball %d top %.2f" % [b.index + 1, top])
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
						# Height above the mound's own base (it may stand on a rolling hill).
						var hh: float = b.altitude(rh["position"]) - b.altitude(centre)
						if hh > worst_step:
							worst_step = hh
							worst_at = "ball %d mound r %.1f top %.1f, %.2f m out, slope %.0f" % [b.index + 1, radius, top, r, slope]
	t.check("mounds_tops_at_design_height", n >= 10 and top_ok, "%d mounds %s" % [n, ", ".join(bad_tops)])
	t.check("mounds_flare_not_a_step", worst_step < 0.35, "highest standable point on a flank %.2f m above the ground (%s)" % [worst_step, worst_at])
	# Walk straight at the tutorial mound M2 (open ground): the head stops at its wall.
	var b0 := g.balls[0]
	var m2_dir := MossBall.dir_ll(57.5, 0)
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
	# The wake follows him, and is stronger at speed.
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
	var passed := p.global_position - p.facing * 1.2
	var just := g.wake.bend_at(b, b.surface_point(b.up_at(passed), 0.0), 2.2).length()
	p.bot_input = Vector2.ZERO
	await t.seconds(0.6)
	var mid := g.wake.bend_at(b, b.surface_point(b.up_at(passed), 0.0), 2.2).length()
	await t.seconds(1.4)
	var later := g.wake.bend_at(b, b.surface_point(b.up_at(passed), 0.0), 2.2).length()
	var settled1 := _bend_near(p.body_center(), 0.8, 2.2)
	await t.seconds(2.0)
	var settled2 := _bend_near(p.body_center(), 0.8, 2.2)
	t.check("wake_recovers_behind", just > 0.3 and mid < just and later < just * 0.15, "passed %.2f, 0.6 s %.2f, 2 s %.2f" % [just, mid, later])
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


## Reachability audit (geometric): every registered climb (terraces, arch, ridge, bridge, spire,
## shelves) steps only between real standable surfaces, each within a plain jump (or jump + water
## burst) of the last, with headroom above; its elevated motes are within reach of its top.
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
				var q := PhysicsRayQueryParameters3D.create(tp + up * 0.6, tp - up * 1.0, 1 | 2)
				var hit := space.intersect_ray(q)
				var floor_ok := not hit.is_empty() and rad_to_deg((hit["normal"] as Vector3).angle_to(up)) < 52.0
				var qh := PhysicsRayQueryParameters3D.create(tp + up * 0.2, tp + up * 1.4, 1 | 2)
				var head_ok := space.intersect_ray(qh).is_empty()
				var rise := (tp - prev).dot(up)
				var gap := ((tp - prev) - up * (tp - prev).dot(up)).length()
				worst_rise = maxf(worst_rise, rise)
				worst_gap = maxf(worst_gap, gap)
				if not floor_ok or not head_ok or rise > 2.6 or gap > 5.0:
					bad.append("ball %d %s step %d: floor %s headroom %s rise %.2f gap %.2f" % [b.index + 1, h["route"], k, floor_ok, head_ok, rise, gap])
				prev = tp
			var end: Vector3 = pts[pts.size() - 1]
			for m in b.motes:
				if m.zone_id in h["zones"] and m.h_hint > 2.5 and m.global_position.distance_to(end) < 6.0:
					if m.global_position.distance_to(end) > 3.2:
						bad.append("ball %d %s: mote %.1f m from the top" % [b.index + 1, h["route"], m.global_position.distance_to(end)])
	for x in bad:
		t.log_line(x)
	t.check("routes_reachable_by_design", n >= 9 and bad.is_empty(), "%d climbs; biggest step up %.2f m (jump 1.85, + burst ~2.6), widest gap %.2f m" % [n, worst_rise, worst_gap])
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
	t.check("new_caves_hold_pearls", pearls == 4, "%d pearls" % pearls)
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
const CATALOG_IDS_SHA := "d1c49999be977476571569650bdfdf6c5fca61acdccb66539ee353b42b060b94"
const CATALOG_SIZE := 157


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
	# Finishing (every ball restored) without the caves and blooms: below 100%.
	var fin := {}
	for id in cat.order:
		if cat.entries[id]["category"] in ["restoration", "milestones"]:
			fin[id] = 1
	t.check("completion_finished_below_100", is_equal_approx(cat.percent(fin), 65.0) and cat.percent_display(fin) == 65, "%.2f%%" % cat.percent(fin))
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
	await t.seconds(1.0)
	g.save_run()
	var st := {"earned": g.run_save.earned().keys(), "run_s": g.clock.run_s, "r0": b.restoration, "r6": b7.restoration, "checkpoint": bl7.get_meta("completion_id"),
			"max_hp": p.max_health, "par": par.get_meta("completion_id"), "mote": m.get_meta("completion_id"), "run_id": g.run_save.run()["id"],
			"par7": par7.get_meta("completion_id"), "pearl": pearl.get_meta("completion_id", "")}
	var f := FileAccess.open(g.run_save.path + ".expect", FileAccess.WRITE)
	f.store_string(JSON.stringify(st))
	f.close()
	t.check("write_earned_progress", st["earned"].size() >= 7 and b.restoration > 0.0 and b7.restoration > 0.0 and g.checkpoint == bl7
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
	var top := b.surface_point(dir, h_hint + 3.0)
	var q := PhysicsRayQueryParameters3D.create(top, b.global_position, 1 | 2)
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
			"amp": par._wave_amp, "last": par._last_head}


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
	var n := 120
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
	# The drawn surface faces outward.
	var mesh: ArrayMesh = b.get_node("MossSurface").mesh
	var arr := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var inward := 0
	for i in range(0, idx.size(), 3):
		var nrm := (v[idx[i + 2]] - v[idx[i]]).cross(v[idx[i + 1]] - v[idx[i]])
		if nrm.length_squared() > 1e-10 and nrm.dot(v[idx[i]]) <= 0.0:
			inward += 1
	t.check("terrain_surface_faces_outward", inward == 0, "%d inward faces" % inward)
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


func _test_tutorial_route() -> void:
	# The opening terrain must teach: walk -> jump onto M1 -> jump + water burst across to M2.
	var b := g.balls[0]
	var results := []
	for start_lat in [89.5, 86.0, 84.5]:
		place(0, start_lat, 0, 0.2, 180)
		p.invuln_t = 999
		await wait_grounded()
		var toward := b.surface_point(MossBall.dir_ll(70, 0)) - p.global_position
		# Walk toward M1 and jump just before the wall.
		for i in 120:
			stick_toward(toward)
			await t.frames(1)
			if b.up_at(p.global_position).angle_to(MossBall.dir_ll(79, 0)) < deg_to_rad(8.5):
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
			if Levels._latlon(b.up_at(p.global_position)).x <= 75.6 or height() < 1.0:
				break
		t.log_line("start %.1f: at edge lat %.2f h %.2f grounded %s" % [start_lat, Levels._latlon(b.up_at(p.global_position)).x, height(), p.grounded])
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
		t.log_line("   landed lat %.2f h %.2f" % [Levels._latlon(b.up_at(p.global_position)).x, height()])
		results.append([start_lat, on_m1, on_m2])
	var ok := results.all(func(r): return r[1] and r[2])
	t.check("tutorial_jump_then_burst_route", ok, str(results))
	# Without the water burst, the gap to M2 is too wide: the burst is genuinely taught.
	place(0, 78.0, 0, 1.5, 180)
	await wait_grounded()
	var toward2 := b.surface_point(MossBall.dir_ll(60, 0)) - p.global_position
	for i in 90:
		stick_toward(toward2)
		await t.frames(1)
		if Levels._latlon(b.up_at(p.global_position)).x <= 74.6:
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
	place(0, 0, -140, 0.2, 0)
	await wait_grounded()
	p.invuln_t = 999
	var prev_up := p.up
	var travelled := 0.0
	var air_frames := 0
	var flips := 0
	var max_dev := 0.0
	var frames := 0
	p.bot_input = Vector2(0, 1)
	while travelled < TAU and frames < 60 * 70:
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
	var m1 := MossBall.dir_ll(79, 0)
	var edge_dir := MossBall.dir_ll(76.3, 0)
	place_at(0, b.surface_point(edge_dir, 1.4), b.surface_point(MossBall.dir_ll(70, 0)) - b.surface_point(edge_dir))
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
		if p.velocity.dot(p.up) < 0.0 and height() < 0.75 + (1.3 if b.up_at(p.global_position).angle_to(m1) < deg_to_rad(4.5) else 0.0):
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
func _place_at_angle(par: Parasite, deg: float) -> void:
	await controls_ready()
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
	# Aim assist: a parasite dead ahead gets swept after a part-way turn.
	var ahead := first_alive(0, Parasite.Kind.SMALL, "meadow")
	await _place_at_angle(ahead, 0.0)
	var f0 := p.facing
	await press("swipe")
	await t.seconds(0.4)
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


func _test_food_repopulates() -> void:
	var b := g.balls[0]
	place(0, 10, -20, 0.1, 0)
	b.foods = b.foods.filter(func(f): return is_instance_valid(f))
	for f in b.foods.duplicate():
		f.eaten()
		b.foods.erase(f)
	var spawned_far := true
	var start := b.foods.size()
	for i in 60 * 30:
		await t.frames(1)
		if b.foods.size() > start:
			var nf: Food = b.foods[b.foods.size() - 1]
			if nf.type != Food.Type.BURROWER and b.up_at(nf.global_position).angle_to(p.up) < deg_to_rad(20):
				spawned_far = false
			start = b.foods.size()
		if b.foods.size() >= b.food_target:
			break
	t.check("food_repopulates_out_of_view", b.foods.size() >= b.food_target and spawned_far, "count %d" % b.foods.size())


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
	place_at(0, mp + m.anchor_up * 0.3 - fwd * 1.8 + side * 1.6, fwd)
	await t.frames(2)
	await press("lunge")
	var v0 := m.vel
	var dv := 0.0
	for k in 24:
		await t.frames(1)
		dv = maxf(dv, (m.vel - v0).length())
		v0 = m.vel
	m.set_physics_process(true)
	t.check("mote_pushed_by_near_miss", m.is_available() and dv > 0.6, "velocity change %.2f" % dv)
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
	t.check("regeneration_restores_health", p.health == p.max_health, "health %d/%d" % [p.health, p.max_health])
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
					low_head = minf(low_head, (hit.position - m.origin).dot(up))
	t.check("canopy_steps_within_a_plain_jump", worst_step <= 1.1 and b.altitude(Levels.leaf_mid(spiral[0], 1.5, 0.0).origin) <= 1.0, "first leaf %.2f m, largest step %.2f m (jump apex 1.85 m)" % [b.altitude(Levels.leaf_mid(spiral[0], 1.5, 0.0).origin), worst_step])
	t.check("canopy_spiral_headroom", low_head >= 1.5, "lowest headroom above a spiral leaf %.2f m" % low_head)
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


func _test_upgrades() -> void:
	p.max_health = 3
	p.health = 3
	for b in g.balls:
		var u = b.upgrades[0]
		place_at(b.index, u._leaf.global_position - b.up_at(u._leaf.global_position) * 0.3, MossBall.frame_at(b.up_at(u.global_position), 0).z)
		await t.seconds(0.4)
	t.check("three_cave_upgrades_to_six", p.max_health == 6 and p.health == 6, "max %d" % p.max_health)


func _test_ui() -> void:
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
	t.check("all_three_balls_reach_100", done, "%.2f %.2f %.2f" % [g.balls[0].restoration, g.balls[1].restoration, g.balls[2].restoration])
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
	t.check("finish_saved", on_disk["run"]["clock"]["state"] == "finished" and float(on_disk["run"]["clock"]["finish_s"]) == fin, "")
	t.check("aquarium_fully_clean", is_equal_approx(g.aquarium.clean, 1.0) and g.env.fog_density < 0.003, "fog %.4f" % g.env.fog_density)
