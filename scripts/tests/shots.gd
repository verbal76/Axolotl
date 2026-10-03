extends RefCounted
## Rendered screenshots of key moments for visual review.

var t


func run(runner) -> void:
	t = runner
	var g: Game = t.g
	var only: String = Settings.test_args.get("only", "")
	await t.seconds(1.0)
	if only == "" or only == "start":
		await t.shot("01_start")
	if only == "" or only == "title":
		g._enter_title()
		await t.seconds(2.0)
		await t.shot("02_title")
		g.start_play(true)
	if only == "diag":
		g._enter_title()
		await t.seconds(1.0)
		g.pause_menu.open(true)
		g.diagnostics.open()
		await t.seconds(0.5)
		await t.shot("diag_page")
		g.diagnostics.close()
		g.pause_menu.close()
	if only == "about":
		g._enter_title()
		await t.seconds(1.0)
		g.pause_menu.open(true)
		g.diagnostics.open()
		await t.seconds(0.5)
		await t.shot("about_page")
		g.diagnostics._install.visible = true
		g.diagnostics._tech.visible = true
		g.diagnostics._text_at = -100000
		await t.seconds(0.5)
		await t.shot("about_technical")
		g.diagnostics.close()
		g.pause_menu.close()
	if only == "applying":
		# The activation modal over the title (HOT_ATTIC_INFRA.md §2).
		g._enter_title()
		await t.seconds(1.0)
		preload("res://scripts/core/update_activation.gd").show_modal(g.get_tree())
		await t.seconds(0.4)
		await t.shot("applying_update")
		await t.seconds(0.3)
		await t.shot("applying_update_b")
		preload("res://scripts/core/update_activation.gd").modal(g.get_tree()).queue_free()
	if only == "ooze":
		# The green ooze on a ravine floor, seen from its rim (owner, 2026-10-01).
		var b: MossBall = g.balls[0]
		var pts: Array = b.carves[0][0]
		var mid: Vector3 = (pts[pts.size() / 2] as Vector3).normalized()
		var nxt: Vector3 = (pts[mini(pts.size() / 2 + 1, pts.size() - 1)] as Vector3).normalized()
		var along := (nxt - mid).normalized()
		var rim := mid.rotated(along, (float(b.carves[0][1]) + float(b.carves[0][3]) + 1.5) / b.radius)
		g.player.place(b, b.surface_point(rim, 0.1), b.global_position + mid * b.radius - b.surface_point(rim))
		g.cam.snap_behind()
		g.cam.pitch = -0.45
		await t.seconds(3.0)
		var oz := b.get_node("RavineOoze") as RavineOoze
		if Settings.test_args.has("ooze-red"):
			var rm := StandardMaterial3D.new()
			rm.albedo_color = Color(1, 0, 0)
			rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			rm.cull_mode = BaseMaterial3D.CULL_DISABLED
			oz.material_override = rm
			oz.visibility_range_end = 0.0
			t.log_line("ooze aabb %s, surfaces %d, verts %d" % [oz.get_aabb(), oz.mesh.get_surface_count(), oz.mesh.surface_get_array_len(0)])
		t.log_line("ooze: bubbles spawned %d" % oz.spawned)
		await t.seconds(0.1)
		await t.seconds(0.1)
		await t.shot("ooze_ball1")
		await t.seconds(0.6)
		# From above, looking straight down at the middle of the first ravine.
		var top := Camera3D.new()
		g.add_child(top)
		var mid_w := b.global_position + mid * b.radius
		top.global_position = b.global_position + mid * (b.radius + 7.0) + mid.cross(along) * 3.0
		top.look_at(mid_w, along)
		top.make_current()
		await t.seconds(0.5)
		await t.shot("ooze_ball1_b")
		# Each end of each ravine, from above and a little back along it (owner, 2026-10-02: the
		# pool ended square, climbing the slope).
		for ci in b.carves.size():
			var cp: Array = b.carves[ci][0]
			for e in [0, cp.size() - 1]:
				var end_d: Vector3 = (cp[e] as Vector3).normalized()
				var inward: Vector3 = (cp[1 if e == 0 else cp.size() - 2] as Vector3).normalized()
				var back := (inward - end_d).normalized()
				var end_w := b.surface_point(end_d)
				top.global_position = end_w + end_d * 9.0 + back * 6.0
				top.look_at(end_w - back * 1.5, end_d)
				await t.seconds(0.4)
				await t.shot("ooze_end_c%d_%d" % [ci, e])
		top.queue_free()
	if only == "hud":
		# Touch controls over bright moss: idle, then the stick pushed and lunge held.
		Settings.input_mode = Settings.InputMode.TOUCH
		var b := g.balls[0]
		g.player.place(b, b.surface_point(MossBall.dir_ll(60, 20), 0.1), Vector3.FORWARD)
		g.cam.snap_behind()
		await t.seconds(1.5)
		await t.shot("hud_idle")
		g.hud._stick_touch = 0
		g.hud._stick_vec = Vector2(0.55, -0.6)
		g.hud._pressed["lunge"] = 1.0
		await t.seconds(0.1)
		await t.shot("hud_active")
		g.hud._stick_touch = -1
		g.hud._stick_vec = Vector2.ZERO
	if only == "" or only == "under":
		# Walk the camera underneath moss ball #1 to look at gravel overhead.
		var b := g.balls[0]
		g.player.place(b, b.surface_point(MossBall.dir_ll(-80, 30), 0.1), Vector3.FORWARD)
		g.cam.snap_behind()
		g.cam.pitch = -0.1
		await t.seconds(1.5)
		await t.shot("03_underneath")
	if only == "" or only == "tut":
		var b := g.balls[0]
		g.player.place(b, b.surface_point(MossBall.dir_ll(66, 0), 0.1), b.surface_point(MossBall.dir_ll(50, 0)) - b.surface_point(MossBall.dir_ll(66, 0)))
		g.cam.snap_behind()
		await t.seconds(1.5)
		await t.shot("04_tutorial_view")
	for i in 3:
		if only == "" or only == "ball%d" % (i + 1):
			var b := g.balls[i]
			g.player.place(b, b.surface_point(MossBall.dir_ll(10, 30 + i * 40), 0.2), Vector3.FORWARD)
			g.cam.snap_behind()
			await t.seconds(1.5)
			await t.shot("05_ball%d" % (i + 1))
	if only == "" or only == "caves":
		# Every cave: its entrance from outside, and its interior from the door.
		for b in g.balls:
			var lb: LevelBuilder = b.get_meta("builder")
			for h in lb.bot_hints:
				if not h.has("cave"):
					continue
				var entry: Vector3 = h["entry"]
				var door: Vector3 = h["door"]
				var out_dir := b.up_at(entry)
				var back := (entry - door)
				back -= out_dir * back.dot(out_dir)
				g.player.place(b, b.surface_point(b.up_at(entry + back.normalized() * 2.5), 0.2), door - entry)
				g.cam.snap_behind()
				await t.seconds(1.2)
				await t.shot("cave_b%d_entrance" % (b.index + 1))
				g.player.place(b, b.surface_point(b.up_at(door), 0.2), door - entry)
				g.cam.snap_behind()
				await t.seconds(1.2)
				await t.shot("cave_b%d_inside" % (b.index + 1))
	if only == "" or only == "veg":
		# Vegetation: walk into each kind of growth, shot mid-stride (the wake) and after stopping.
		var views := [[0, 29.0, 9.0, "meadow_medium"], [0, -59.0, 31.0, "reeds_tall"], [0, 45.0, 40.0, "short"]]
		for v in views:
			var b := g.balls[v[0]]
			var at := MossBall.dir_ll(v[1], v[2])
			g.player.place(b, b.surface_point(at, 0.2), -MossBall.frame_at(at, 0.0).z)
			g.cam.snap_behind()
			g.player.use_bot_input = true
			g.player.bot_input = Vector2(0.1, 0.5)
			await t.seconds(0.9)
			await t.shot("veg_%s_moving" % v[3])
			g.player.bot_input = Vector2.ZERO
			await t.seconds(2.5)
			await t.shot("veg_%s_stopped" % v[3])
		g.player.use_bot_input = false
	if only == "" or only == "critters":
		# Expansion 5: each species from where a player meets it (threats in their telegraphs).
		var seen := {}
		for c in g.ecosystem.all_critters():
			if seen.has(c.species):
				continue
			seen[c.species] = true
			var b: MossBall = c.ball
			var pt: Vector3 = c.discover_point()
			var up := b.up_at(pt)
			var away := MossBall.frame_at(up, 30.0).z
			if c is CaveEel:
				away = (c as CaveEel).normal
			elif c is CrabGuardian:
				away = (c as CrabGuardian).facing
			var dist := 3.2 if c is CaveEel else (2.6 if c is ShrimpShoal or c is CanopySnail or c is LeafHopper else 4.2)
			var stand := b.surface_point(b.up_at(pt + away * dist), 0.3)
			if c is GlowWorms:
				stand = b.surface_point(b.up_at((c as GlowWorms).cave_centre), 0.3)
			g.player.place(b, stand, pt - stand)
			g.audio.set_ball(b.index, false)
			g.cam.snap_behind()
			g.cam.pitch = 0.35 if c is GlowWorms or c is CanopySnail or c is LeafHopper or c is Pufferfish else 0.15
			await t.seconds(1.6 if c is CaveEel else 1.2)
			await t.shot("critter_%s" % c.species)
		# The stalker's telegraph in the reeds.
		for c in g.ecosystem.all_critters():
			if c is ReedStalker:
				var st := c as ReedStalker
				var b: MossBall = st.ball
				var up := b.up_at(st.global_position)
				var stand := b.surface_point(b.up_at(st.global_position + MossBall.frame_at(up, 0).z * 3.6), 0.3)
				g.player.place(b, stand, st.global_position - stand)
				g.audio.set_ball(b.index, false)
				g.cam.snap_behind()
				await t.seconds(0.5)
				st._go("telegraph")
				st._lock = (stand - st.global_position).normalized()
				await t.seconds(0.5)
				await t.shot("critter_stalker_telegraph")
				break
	if only == "" or only == "climbs":
		# Every ball-3 jungle stem ladder and the mesa, from where a player stands underneath.
		for bi in [2, 1]:
			var b := g.balls[bi]
			for h in (b.get_meta("builder") as LevelBuilder).bot_hints:
				if not h.has("route") or not (str(h["route"]).begins_with("jungle") or h["route"] == "mesa"):
					continue
				if str(h["route"]).begins_with("jungle") and not (str(h["route"]) in ["jungle stem 3", "jungle stem 20", "jungle stem 41"]):
					continue
				var st: Vector3 = h["start"]
				var first: Vector3 = (h["tops"] as Array)[0]
				var back := st - (first - st).normalized() * 3.0
				g.player.place(b, b.surface_point(b.up_at(back), 0.2), first - back)
				g.cam.snap_behind()
				g.cam.pitch = 0.05
				await t.seconds(1.2)
				await t.shot("climb_b%d_%s" % [bi + 1, str(h["route"]).replace(" ", "_")])
	if only == "" or only == "world":
		# Expansion 4's balls: each climb's start, looking at its first step.
		for bi in range(3, g.balls.size()):
			var b := g.balls[bi]
			var lb: LevelBuilder = b.get_meta("builder")
			var k := 0
			for h in lb.bot_hints:
				if not h.has("route"):
					continue
				var st: Vector3 = h["start"]
				var first: Vector3 = (h["tops"] as Array)[0]
				var back := st - (first - st).normalized() * 4.0
				g.player.place(b, b.surface_point(b.up_at(back), 0.2), first - back)
				g.cam.snap_behind()
				g.cam.pitch = 0.25
				await t.seconds(1.2)
				await t.shot("world_b%d_%d_%s" % [bi + 1, k, str(h["route"]).replace(" ", "_")])
				k += 1
	if only == "perfaq":
		# Where this package's frame time goes: three slowed views, with each new piece switched
		# off in turn (cumulatively).
		var b1 := g.balls[0]
		var b7 := g.balls[6]
		var sets := [[b1, b1.surface_point(MossBall.dir_ll(10.0, 30.0), 0.2), Vector3.FORWARD, "ball1_10_30"],
				[g.balls[4], Vector3.ZERO, Vector3.ZERO, "ball5_bridge"]]
		for h in (g.balls[4].get_meta("builder") as LevelBuilder).bot_hints:
			if h.has("route"):
				sets[1][1] = (h["start"] as Vector3) + g.balls[4].up_at(h["start"]) * 0.2
				sets[1][2] = (h["tops"][0] as Vector3) - (h["start"] as Vector3)
				break
		for h in (b7.get_meta("builder") as LevelBuilder).bot_hints:
			if h.has("cave"):
				sets.append([b7, b7.surface_point(b7.up_at(h["door"]), 0.2), (h["door"] as Vector3) - (h["entry"] as Vector3), "cave_b7"])
				break
		for step in ["all", "no_fish", "no_pebbles_stones", "no_gravel_floor", "no_bedroom", "no_shrines"]:
			match step:
				"no_fish":
					g.fish.visible = false
				"no_pebbles_stones":
					for n in g.aquarium.pebble_tiles:
						n.visible = false
					g.aquarium.get_node("GravelStones").visible = false
				"no_gravel_floor":
					g.aquarium.get_node("GravelFloor").visible = false
				"no_bedroom":
					g.aquarium.bedroom.visible = false
				"no_shrines":
					for b in g.balls:
						for sh in b.shrines:
							sh.visible = false
			for st in sets:
				g.player.place(st[0], st[1], st[2])
				g.cam.snap_behind()
				await _perf_view("%s %s" % [st[3], step])
	if only == "perfsplit":
		# Where the frame time goes (Expansion 6 performance pass): two heavy views, measured with
		# everything, then with each Expansion 6 feature switched off in turn (cumulatively).
		var sets := []
		for bi in [2, 3]:
			var b := g.balls[bi]
			var at := MossBall.dir_ll(10.0, 110.0) if bi == 2 else Vector3.ZERO
			if bi == 3:
				for h in (b.get_meta("builder") as LevelBuilder).bot_hints:
					if h.has("route"):
						sets.append([b, (h["start"] as Vector3) + b.up_at(h["start"]) * 0.2, (h["tops"][0] as Vector3) - (h["start"] as Vector3), "ball4_terraces"])
						break
			else:
				sets.append([b, b.surface_point(at, 0.2), Vector3.FORWARD, "ball3_10_110"])
		# Shadow casters by kind: triangle totals.
		var tally := {}
		var stack: Array = [g]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			stack.append_array(n.get_children())
			if n is GeometryInstance3D and ((n as VisualInstance3D).layers & MossBall.SHADOW_CASTER_LAYER) != 0:
				var tris := 0
				var mesh: Mesh = null
				var mult := 1
				if n is MeshInstance3D:
					mesh = (n as MeshInstance3D).mesh
				elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh:
					mesh = (n as MultiMeshInstance3D).multimesh.mesh
					mult = (n as MultiMeshInstance3D).multimesh.instance_count
				if mesh:
					for si in mesh.get_surface_count():
						var arr := mesh.surface_get_arrays(si)
						var idx = arr[Mesh.ARRAY_INDEX]
						tris += (idx.size() if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
				var key := n.get_parent().get_class() + "/" + str(n.get_parent().get_script().get_global_name() if n.get_parent().get_script() else "") + " " + str(n.get_parent().get_meta("grounded", ""))
				var cur: Array = tally.get(key, [0, 0])
				tally[key] = [cur[0] + tris * mult, cur[1] + 1]
		for k in tally:
			t.log_line("CASTERS %s: %d triangles in %d meshes" % [k, tally[k][0], tally[k][1]])
		var steps := ["all", "mask_none", "no_shadows", "no_vortices", "no_sprouts", "no_corals", "no_shafts", "no_parasites"]
		for step in steps:
			match step:
				"mask_none":
					g.aquarium.sun.shadow_caster_mask = 0
				"no_shadows":
					g.aquarium.sun.shadow_enabled = false
				"no_vortices":
					for v in g.vortices:
						v.visible = false
				"no_sprouts":
					for b in g.balls:
						for n in b.sprout_nodes:
							n.visible = false
				"no_corals":
					for b in g.balls:
						for n in b.coral_nodes:
							n.visible = false
				"no_shafts":
					for m in g.aquarium.shaft_mats:
						m.set_shader_parameter("strength", 0.0)
					for n in g.aquarium.get_children():
						if n is MeshInstance3D and (n as MeshInstance3D).material_override in g.aquarium.shaft_mats:
							n.visible = false
				"no_parasites":
					for b in g.balls:
						for par in b.parasites:
							par.visible = false
			for st in sets:
				g.player.place(st[0], st[1], st[2])
				g.cam.snap_behind()
				await _perf_view("%s %s" % [st[3], step])
	if only == "perf":
		# Rendering cost at fixed views: frame time (software renderer here, so a proxy for GPU
		# fill cost, not phone numbers), draw calls, triangles and video memory.
		var views := [[0, 66.0, 0.0, 50.0], [0, 10.0, 30.0, 0.0], [1, 10.0, 70.0, 0.0], [2, 10.0, 110.0, 0.0], [0, -59.0, 31.0, 0.0], [1, 30.0, -20.0, 0.0]]
		for v in views:
			var b := g.balls[v[0]]
			var at := MossBall.dir_ll(v[1], v[2])
			g.player.place(b, b.surface_point(at, 0.2), Vector3.FORWARD if v[3] == 0.0 else b.surface_point(MossBall.dir_ll(v[3], v[2])) - b.surface_point(at))
			g.cam.snap_behind()
			await _perf_view("ball%d_%d_%d" % [v[0] + 1, v[1], v[2]])
		var lb: LevelBuilder = g.balls[0].get_meta("builder")
		for h in lb.bot_hints:
			if h.has("cave"):
				g.player.place(g.balls[0], g.balls[0].surface_point(g.balls[0].up_at(h["door"]), 0.2), (h["door"] as Vector3) - (h["entry"] as Vector3))
				g.cam.snap_behind()
				await _perf_view("cave_b1")
		# The new areas (Expansion 4): the first climb on each, looking up it, and ball 7's grotto.
		for bi in range(3, g.balls.size()):
			var nb := g.balls[bi]
			var nlb: LevelBuilder = nb.get_meta("builder")
			for h in nlb.bot_hints:
				if h.has("route"):
					g.player.place(nb, (h["start"] as Vector3) + nb.up_at(h["start"]) * 0.2, (h["tops"][0] as Vector3) - (h["start"] as Vector3))
					g.cam.snap_behind()
					await _perf_view("ball%d_%s" % [bi + 1, str(h["route"]).replace(" ", "_")])
					break
		var glb: LevelBuilder = g.balls[6].get_meta("builder")
		for h in glb.bot_hints:
			if h.has("cave"):
				g.player.place(g.balls[6], g.balls[6].surface_point(g.balls[6].up_at(h["door"]), 0.2), (h["door"] as Vector3) - (h["entry"] as Vector3))
				g.cam.snap_behind()
				await _perf_view("cave_b7")
				break
		# The fully restored, clear tank (Expansion 6): the same first views.
		for b in g.balls:
			b.add_heal(Vector3.UP, 340.0, 0.0)
		g.g_disp = 1.0
		g.aquarium.apply(1.0)
		for v in [views[1], views[3]]:
			var b := g.balls[v[0]]
			g.player.place(b, b.surface_point(MossBall.dir_ll(v[1], v[2]), 0.2), Vector3.FORWARD)
			g.cam.snap_behind()
			await _perf_view("restored_ball%d_%d_%d" % [v[0] + 1, v[1], v[2]])
		var ob := g.balls[0]
		g.player.place(ob, ob.surface_point(MossBall.dir_ll(40, 90), 0.2), ob.surface_point(MossBall.dir_ll(25, 95)) - ob.surface_point(MossBall.dir_ll(40, 90)))
		g.cam.snap_behind()
		g.cam.pitch = -0.05
		await _perf_view("restored_open_water")
		# The aquarium experiences (this package): each mode, from the restored tank.
		var pr: Presentation = g.presentation
		pr.enter("play")
		await _perf_view("aq_room")
		pr.go("inspect")
		await _perf_view("aq_inspect")
		pr.go("live")
		await _perf_view("aq_live_tank")
		pr.go("swim")
		pr.ui.swim_stick = Vector2(0, 1)
		await _perf_view("aq_swim")
		pr.ui.swim_stick = Vector2.ZERO
		pr.exit()
		await _perf_view("aq_back_in_play")
	if only == "perfaqv":
		# Where the aquarium views' frame time goes (this package): each view with everything, then
		# with the room's lamps, the room, the far plants and the fish switched off in turn.
		for b in g.balls:
			b.add_heal(Vector3.UP, 340.0, 0.0)
		g.g_disp = 1.0
		g.aquarium.apply(1.0)
		await t.seconds(1.0)
		var pr: Presentation = g.presentation
		pr.enter("play")
		var bed: Bedroom = g.aquarium.bedroom
		# (The first pass only warms up: the first entry builds the far view and compiles shaders.)
		for step in ["warmup", "all", "no_room", "no_far_plants", "no_fish"]:
			match step:
				"no_room":
					bed.visible = false
				"no_far_plants":
					for b in g.balls:
						if b.far_vegetation() != null:
							b.far_vegetation().visible = false
				"no_fish":
					g.fish.visible = false
			pr.go("room")
			await _perf_view("aq_room %s" % step)
			pr.go("live")
			await _perf_view("aq_live %s" % step)
			pr.go("swim")
			pr.ui.swim_held = true
			await _perf_view("aq_swim %s" % step)
			pr.ui.swim_held = false
			pr.back()
			await t.seconds(0.3)
	if only == "perfaqw":
		# The aquarium views like for like: each measured on first entry and again once warm, murky
		# and restored (same code in both builds compared).
		var pr: Presentation = g.presentation
		for state in ["murky", "clean"]:
			if state == "clean":
				for b in g.balls:
					b.add_heal(Vector3.UP, 340.0, 0.0)
				g.g_disp = 1.0
				g.aquarium.apply(1.0)
				await t.seconds(1.0)
			pr.enter("play")
			for round_ in 2:
				for m in ["room", "inspect", "live", "swim"]:
					pr.go(m)
					await t.seconds(2.0)
					await _perf_view("aqw_%s_%s_%s" % [state, "first" if round_ == 0 else "warm", m])
			pr.exit()
			await t.seconds(1.0)
	if only == "perfroom":
		# The Room view with the bedroom shown and hidden in turn (its visibility check paused).
		var pr: Presentation = g.presentation
		pr.enter("play")
		pr.go("room")
		await t.seconds(3.0)
		await _perf_view("room warmup")
		var bed: Bedroom = g.aquarium.bedroom
		for k in 6:
			g.aquarium._room_t = 1e9
			bed.visible = k % 2 == 1
			await _perf_view("room %s %d" % ["shown" if bed.visible else "hidden", k / 2])
		g.aquarium._room_t = 0.0
		bed.visible = true
		pr.exit()
	if only == "vtint":
		# Each connection's hue (owner, 2026-09-30): every ball's vortex mouths seen together from
		# above-and-behind the middle of them, murky then restored, and each mouth close up.
		g.player.invuln_t = 9999
		for v in g.vortices:
			v._target = 1.0
			v.strength = 1.0
			v.connected = true
		for state in ["murky", "clean"]:
			if state == "clean":
				for b in g.balls:
					b.add_heal(Vector3.UP, 340.0, 0.0)
				g.g_disp = 1.0
				g.aquarium.apply(1.0)
			await t.seconds(1.5)
			for b in g.balls:
				var mouths: Array[Vector3] = []
				for v in b.vortices:
					mouths.append((v as Vortex)._mouth_a.global_position if (v as Vortex).ball_a == b else (v as Vortex)._mouth_b.global_position)
				if mouths.size() < 2:
					continue
				var mid := Vector3.ZERO
				for m in mouths:
					mid += m
				mid /= mouths.size()
				var up := b.up_at(mid)
				var spread := 0.0
				for m in mouths:
					spread = maxf(spread, m.distance_to(mid))
				g.player.place(b, b.surface_point(up, 0.2), MossBall.frame_at(up, 0.0).z)
				var side := MossBall.frame_at(up, 0.0).z
				_close(g, mid + up * (spread * 0.9 + 8.0) + side * (spread * 0.8 + 6.0), mid, up)
				await t.seconds(1.2)
				await t.shot("vtint_%s_ball%d_all" % [state, b.index + 1])
				var k := 0
				for m in mouths:
					var mu := b.up_at(m)
					var toward := (mid - m)
					toward -= mu * toward.dot(mu)
					var back := -toward.normalized() if toward.length() > 0.1 else MossBall.frame_at(mu, 0.0).z
					_close(g, m + mu * 4.5 - back * -9.0, m + mu * 1.5, mu)
					await t.seconds(0.8)
					await t.shot("vtint_%s_ball%d_mouth%d" % [state, b.index + 1, k])
					k += 1
		_open(g)
	if only == "b2out":
		var b := g.balls[1]
		var v: Vortex = b.vortex_out
		v.connected = true
		var d := b.up_at(v.mouth_pos(false))
		var off := d.rotated(MossBall.frame_at(d, 0).x, deg_to_rad(12.0))
		g.player.place(b, b.surface_point(off, 0.3), b.surface_point(d) - b.surface_point(off))
		g.cam.snap_behind()
		await t.seconds(2.0)
		await t.shot("dbg_b2out")
		var mind := 99.0
		for i in 240:
			g.player.use_bot_input = true
			g.player.bot_input = Vector2(0, 1)
			await t.frames(1)
			var dd: float = v.mouth_pos(false).distance_to(g.player.body_center())
			if dd < mind:
				mind = dd
				t.log_line("closer %.2f frame %d cine '%s' state %s block %s conn %s" % [dd, i, g.cinematic, g.player.state, g._vortex_block, v.connected])
		t.log_line("after walking: ball %d cine %s dist %.2f" % [g.player.ball.index, g.cinematic, g.player.global_position.distance_to(v.mouth_pos(false))])
		await t.shot("dbg_b2out_walk")
	if only == "b2tower":
		var b := g.balls[1]
		var lb: LevelBuilder = b.get_meta("builder")
		var xf := lb.at(-48, -34, 150, 3.5, 0, 4.0)
		g.player.place(b, xf.origin + xf.basis.y * 0.3, lb.at(-48, -34, 150, 0, 0, -5.0).origin - xf.origin)
		g.cam.snap_behind()
		g.cam.pitch = 0.5
		await t.seconds(2.0)
		await t.shot("dbg_b2tower")
		for m in b.motes:
			if m.h_hint > 3.5:
				t.log_line("tower mote h_hint %.1f anchor-height %.2f pos-height %.2f state %s" % [m.h_hint, (m.anchor - b.global_position).length() - b.radius,
						(m.global_position - b.global_position).length() - b.radius, m.state])
	if only == "terrain":
		# Rolling meadow hills from the player's camera, and the south hills.
		var b := g.balls[0]
		for v in [[18, 0, 36, -9, "a"], [26, 20, 31, 22, "b"], [-40, 30, -52, 22, "c"]]:
			var from := MossBall.dir_ll(v[0], v[1])
			var to := MossBall.dir_ll(v[2], v[3])
			g.player.place(b, b.surface_point(from, 0.1), b.surface_point(to) - b.surface_point(from))
			g.cam.snap_behind()
			g.cam.pitch = 0.18
			await t.seconds(1.5)
			await t.shot("terrain_%s" % v[4])
	if only == "review":
		await _review(g)
	if only == "lightdbg":
		for b in g.balls:
			b.add_heal(Vector3.UP, 340.0, 0.0)
		g.g_disp = 1.0
		g.aquarium.apply(1.0)
		var b2 := g.balls[2]
		_look(g, 2, b2.surface_point(MossBall.dir_ll(10, 110), 0.2), Vector3.FORWARD, 0.9)
		await t.seconds(1.5)
		t.log_line("sun shadow %s opacity %.2f energy %.2f window %.2f; lamp %s" % [g.aquarium.sun.shadow_enabled, g.aquarium.sun.shadow_opacity, g.aquarium.sun.light_energy, g.aquarium.window_light.light_energy, str(Aquarium.light_params)])
		await t.shot("light_top")
		g.cam.pitch = 0.3
		await t.seconds(0.5)
		await t.shot("light_side")
		# Grading variants on the same view (lighting experiments; not a regression view).
		var e: Environment = g.env
		var variants := [["agx", Environment.TONE_MAPPER_AGX, 1.0, 1.0, 1.0, 0.0026],
				["agx_graded", Environment.TONE_MAPPER_AGX, 1.1, 0.85, 1.08, 0.006],
				["filmic_graded", Environment.TONE_MAPPER_FILMIC, 1.0, 0.82, 1.1, 0.006]]
		for v in variants:
			e.tonemap_mode = v[1]
			e.tonemap_exposure = v[2]
			e.adjustment_enabled = true
			e.adjustment_saturation = v[3]
			e.adjustment_contrast = v[4]
			e.fog_density = v[5]
			await t.seconds(0.3)
			await t.shot("light_side_%s" % v[0])
	if only == "rays":
		# Light through the water (owner, 2026-10-02): soft beams, and the ripple light moving over
		# the ground and Gill. A clear tank (two moments half a second apart, to see it move), then murky.
		for clean in [1.0, 0.15]:
			for b in g.balls:
				b.add_heal(Vector3.UP, 340.0 if clean > 0.5 else 0.0, 0.0)
			g.g_disp = clean
			g.aquarium.apply(clean)
			var tag := "clear" if clean > 0.5 else "murky"
			# Low, looking out across the ball toward open water and its beams.
			_look(g, 0, g.balls[0].surface_point(MossBall.dir_ll(84, 0), 0.2), Aquarium.light_params["lamp_dir"], -0.2)
			await t.seconds(1.5)
			await t.shot("rays_%s_beams" % tag)
			# Close over Gill on open ground: the moving web on the moss and on him.
			_look(g, 0, g.balls[0].surface_point(MossBall.dir_ll(84, 40), 0.2), Vector3.FORWARD, 0.9)
			g.cam.distance = 2.6
			await t.seconds(1.0)
			await t.shot("rays_%s_ground_a" % tag)
			await t.seconds(0.5)
			await t.shot("rays_%s_ground_b" % tag)
			g.cam.distance = 4.4
	if only == "worldr":
		# The terrain vocabulary (ridges, terraces, arch, bridge, shelves), healed, from further back.
		for b in g.balls:
			b.add_heal(Vector3.UP, 340.0, 0.0)
		g.g_disp = 1.0
		g.aquarium.apply(1.0)
		for bi in range(3, g.balls.size()):
			var b := g.balls[bi]
			var k := 0
			for h in (b.get_meta("builder") as LevelBuilder).bot_hints:
				if not h.has("route") or h.get("audit", false):
					continue
				var st: Vector3 = h["start"]
				var tops: Array = h["tops"]
				var mid: Vector3 = tops[tops.size() / 2]
				var back := st - (mid - st).normalized() * 7.0
				_look(g, bi, b.surface_point(b.up_at(back), 0.2), mid - back, 0.35)
				await t.seconds(1.0)
				await t.shot("wr_b%d_%d_%s" % [bi + 1, k, str(h["route"]).replace(" ", "_")])
				k += 1
	if only == "balls":
		# Whole moss balls from the side (owner reference: a sprouted moss ball), murky then healed,
		# and a close look at the healed moss.
		await _ball_shots(g, "murky_")
		for b in g.balls:
			b.add_heal(Vector3.UP, 340.0, 0.0)
		g.g_disp = 1.0
		g.aquarium.apply(1.0)
		await _ball_shots(g, "clear_")
	if only == "vortex":
		await _vortex_shots(g, "murky_")
		for b in g.balls:
			b.add_heal(Vector3.UP, 340.0, 0.0)
		g.g_disp = 1.0
		g.aquarium.apply(1.0)
		await _vortex_shots(g, "clear_")
	if only == "vcur":
		await _vcur_shots(g)
	if only == "hard":
		await load("res://scripts/tests/hard_tests.gd").new(t, g).shots(self)
	if only == "feedback":
		await _feedback(g, "")
		for b in g.balls:
			b.add_heal(Vector3.UP, 340.0, 0.0)
		g.g_disp = 1.0
		g.aquarium.apply(1.0)
		await _feedback(g, "_restored")
	if only == "critterclose":
		await _critter_close(g)
	if only == "parasite":
		await _parasite_shots(g)
	if only == "gill":
		await _gill_shots(g, "gill")
		for b in g.balls:
			b.add_heal(Vector3.UP, 340.0, 0.0)
		g.g_disp = 1.0
		g.aquarium.apply(1.0)
		await _gill_shots(g, "gill_restored")
	if only == "menus":
		await _menus_shots(g)
	if only == "cohesion":
		# Cohesion audit (2026-10-02): what a player sees on arriving at each ball, through the
		# ordinary follow camera with the touch HUD: two headings each (as he lands, then turned).
		Settings.input_mode = Settings.InputMode.TOUCH
		g.player.invuln_t = 9999
		for bi in g.balls.size():
			var b: MossBall = g.balls[bi]
			var arrive: Vector3 = b.start_dir if bi == 0 else b.arrival_dir
			var fr := MossBall.frame_at(arrive, 0.0)
			for k in 2:
				var face := fr.z if k == 0 else fr.z.rotated(arrive, 2.1)
				g.player.place(b, b.surface_point(arrive, 0.2), face)
				g.cam.snap_behind()
				await t.seconds(1.8)
				await t.shot("coh_b%d_%d" % [bi + 1, k])
	if only == "cohesion2":
		# Cohesion audit: threat vs collectable at play distance (about 7 m ahead, ordinary camera),
		# on Ball 2 unrestored: a parasite, a Mote, food, a red starfish and a bloom.
		Settings.input_mode = Settings.InputMode.TOUCH
		g.player.invuln_t = 9999
		var b: MossBall = g.balls[1]
		for pp in b.parasites:
			pp.set_physics_process(false)
		var stars := []
		for st in g.starfish.stars:
			if is_instance_valid(st) and st.ball == b:
				stars.append(st)
		var subjects := {"parasite": b.parasites, "mote": b.motes, "food": b.foods, "starfish": stars, "bloom": b.blooms}
		for key in subjects:
			var arr: Array = subjects[key]
			var it: Node3D = null
			for x in arr:
				if is_instance_valid(x) and x is Node3D:
					it = x
					break
			if it == null:
				continue
			var up := b.up_at(it.global_position)
			var fr := MossBall.frame_at(up, 30.0)
			var at := b.surface_point((b.global_position + (it.global_position - b.global_position) - fr.z * 7.0 - b.global_position).normalized(), 0.2)
			g.player.place(b, at, it.global_position - at)
			g.cam.snap_behind()
			await t.seconds(1.5)
			await t.shot("coh2_%s" % key)
	if only == "ballview":
		# The whole-ball view on demand (ledger row 21): the menu row, then the view on three balls
		# (Ball 5 sits by the tank's glass), then back.
		Settings.input_mode = Settings.InputMode.TOUCH
		g.pause_menu.open()
		await t.seconds(0.5)
		await t.shot("ballview_menu")
		g.pause_menu.close()
		for bi in [0, 4, 6]:
			var b: MossBall = g.balls[bi]
			g.player.place(b, b.surface_point(b.start_dir, 0.2), MossBall.frame_at(b.start_dir, 0).z)
			g.cam.snap_behind()
			await t.seconds(1.5)
			g.ball_view.open()
			await t.seconds(2.5)
			await t.shot("ballview_ball%d" % (bi + 1))
			g.ball_view.close()
			await t.seconds(1.5)
		await t.shot("ballview_back")
	if only == "aqframes":
		await load("res://scripts/tests/aq_nav_tests.gd").new(t, g).frames_phase()
	if only == "aqgill":
		await load("res://scripts/tests/aq_nav_tests.gd").new(t, g).renders_phase()
	if only == "colours":
		await _colour_shots(g)
	if only == "sway":
		await _sway_shots(g)
	if only == "gillanim":
		await _gill_anim(g)
	if only == "loco":
		await _loco_shots(g)
	if only == "skilltitle":
		# (The Skills page opened from the title screen, as the owner saw it.)
		g._enter_title()
		await t.seconds(1.5)
		await t.shot("skilltitle_menu")
		g.title._on_skills()
		await t.seconds(0.6)
		await t.shot("skilltitle_page")
	if only == "onboarding":
		await _onboarding_shots(g)
	if only == "skilltree":
		await _skilltree_shots(g)
	if only == "starfish":
		await _starfish_shots(g)
	if only == "glide":
		await _glide_shots(g)
	if only == "brace":
		await _brace_shots(g)
	if only == "perfstar":
		await _perf_starfish(g)
	if only == "organic":
		await _organic_shots(g)
	if only == "loco2":
		await _loco2_shots(g)
	if only == "spots":
		await _spot_shots(g)
	if only == "report":
		await _report_shots(g)
	if only == "camaudit":
		await _camera_audit(g)
	if only == "room":
		await _room_shots(g, "room_murky")
		for b in g.balls:
			b.add_heal(Vector3.UP, 340.0, 0.0)
		g.g_disp = 1.0
		g.aquarium.apply(1.0)
		await _room_shots(g, "room_clean")
	if only == "treasurehunt":
		for id in g.completion.order:
			g.run_save.earned()[id] = 0.0
		for b in g.balls:
			b.add_heal(Vector3.UP, 340.0, 0.0)
		g.g_disp = 1.0
		g.aquarium.apply(1.0)
		await _treasure_hunt_shots(g)
	if only == "thspots":
		for id in g.completion.order:
			g.run_save.earned()[id] = 0.0
		for b in g.balls:
			b.add_heal(Vector3.UP, 340.0, 0.0)
		g.g_disp = 1.0
		g.aquarium.apply(1.0)
		await _treasure_spot_shots(g)
	if only == "treasures":
		for b in g.balls:
			b.add_heal(Vector3.UP, 340.0, 0.0)
		g.g_disp = 1.0
		g.aquarium.apply(1.0)
		await _treasure_shots(g)
	if only == "bala":
		for b in g.balls:
			b.add_heal(Vector3.UP, 340.0, 0.0)
		g.g_disp = 1.0
		g.aquarium.apply(1.0)
		await _bala_shots(g)
	if only == "tier2":
		await _tier2_shots(g)
	if only == "uiq":
		await _ui_shots(g)
	if only == "aqquick":
		# Quick iteration: the views from the room at three states of the tank.
		for st in [["murky", 0.0], ["half", 0.5], ["clean", 1.0]]:
			if st[1] > 0.0:
				for b in g.balls:
					b.add_heal(Vector3.UP, 340.0 * st[1], 0.0)
				g.g_disp = st[1]
				g.aquarium.apply(st[1])
			var pr := g.presentation
			pr.enter("play")
			await t.seconds(2.5)
			await t.shot("aqq_%s_1room" % st[0])
			pr.go("inspect")
			await t.seconds(2.5)
			await t.shot("aqq_%s_2inspect" % st[0])
			pr.go("live")
			await t.seconds(3.0)
			await t.shot("aqq_%s_3live" % st[0])
			pr.exit()
			await t.seconds(0.5)
	if only == "aquarium":
		await _aquarium_shots(g, "aq_murky")
		for b in g.balls:
			b.add_heal(Vector3.UP, 340.0, 0.0)
		g.g_disp = 1.0
		g.aquarium.apply(1.0)
		await _aquarium_shots(g, "aq_clean")
	if only == "gravel":
		await _gravel_shots(g, "gravel_murky")
		for b in g.balls:
			b.add_heal(Vector3.UP, 340.0, 0.0)
		g.g_disp = 1.0
		g.aquarium.apply(1.0)
		await _gravel_shots(g, "gravel_clean")
	if only == "leafclose":
		await _leaf_close(g, g.balls[2], "leaf_close")
		for b in g.balls:
			b.add_heal(Vector3.UP, 340.0, 0.0)
		g.g_disp = 1.0
		g.aquarium.apply(1.0)
		await _leaf_close(g, g.balls[2], "leaf_close_restored")
	if only == "plants":
		await _plant_shots(g)
	if only == "seafan":
		await _sea_fan_shots(g, "murky")
		_heal_all(g)
		await t.seconds(1.0)
		await _sea_fan_shots(g, "restored")
	if only == "touchup":
		# (Leaves and the sea fan only: quick review of surface and twig changes.)
		await _leaf_views(g, "murky")
		_heal_all(g)
		await t.seconds(1.0)
		await _leaf_views(g, "restored")
		await _sea_fan_shots(g, "restored")
	if only == "plantperf":
		await _plant_perf(g)
	if only == "look":
		await _look_shots(g)
	if only == "perflook":
		# Frame cost of the E6f materials at the views they fill (a short subset of "perf"):
		# open moss, a mound field, stems, the ball 1 cave, ball 7's shelf, a stone column close.
		g.player.invuln_t = 9999
		var pv := [[0, 10.0, 30.0], [0, -59.0, 31.0], [1, 10.0, 70.0], [2, 10.0, 110.0]]
		for v in pv:
			var b := g.balls[v[0]]
			g.player.place(b, b.surface_point(MossBall.dir_ll(v[1], v[2]), 0.2), Vector3.FORWARD)
			g.cam.snap_behind()
			await _perf_view("ball%d_%d_%d" % [v[0] + 1, v[1], v[2]])
		for bi in [0, 6]:
			var b := g.balls[bi]
			for h in (b.get_meta("builder") as LevelBuilder).bot_hints:
				if h.has("cave"):
					g.player.place(b, b.surface_point(b.up_at(h["door"]), 0.2), (h["door"] as Vector3) - (h["entry"] as Vector3))
					g.cam.snap_behind()
					await _perf_view("cave_b%d" % (bi + 1))
					break
		for h in (g.balls[6].get_meta("builder") as LevelBuilder).bot_hints:
			if h.has("route"):
				var nb := g.balls[6]
				g.player.place(nb, (h["start"] as Vector3) + nb.up_at(h["start"]) * 0.2, (h["tops"][0] as Vector3) - (h["start"] as Vector3))
				g.cam.snap_behind()
				await _perf_view("ball7_first_route")
				break
	if only == "" or only == "moments":
		await _moments(g)
	if only == "" or only == "restored":
		for b in g.balls:
			for z in b.zones:
				b.add_heal(b.zones[z]["dir"], b.zones[z]["radius"] * 1.2, 0.0)
			b.add_heal(Vector3.UP, 340.0, 0.0)
		g.g_disp = 1.0
		g.aquarium.apply(1.0)
		var b := g.balls[0]
		g.player.place(b, b.surface_point(MossBall.dir_ll(10, 30), 0.2), Vector3.FORWARD)
		g.cam.snap_behind()
		await t.seconds(1.5)
		await t.shot("06_restored")
		g.player.place(b, b.surface_point(MossBall.dir_ll(-80, 30), 0.1), Vector3.FORWARD)
		g.cam.snap_behind()
		g.cam.pitch = -0.1
		await t.seconds(1.5)
		await t.shot("07_restored_under")


## The bedroom (docs/AQUARIUM.md): the room view's composition, and a few corners of the room.
func _room_shots(g: Game, tag: String) -> void:
	g.player.invuln_t = 9999
	var env: Environment = g.aquarium.env
	var fog := env.fog_enabled
	env.fog_enabled = false
	g.cam.cinematic = true
	var bed: Bedroom = g.aquarium.bedroom
	var views := [["1view", bed.view_pos, bed.view_look], ["2desk", Vector3(-300, 500, 2000), Vector3(-1300, 100, 1000)],
			["3bed", Vector3(-600, 400, 900), Vector3(1100, -300, 2400)], ["4tv", Vector3(400, 300, 1600), Vector3(-1200, 0, 2400)],
			["5tank", Vector3(250, 120, 900), Vector3(0, -20, 0)]]
	for v in views:
		g.cam.cine_pos = v[1]
		g.cam.cine_look = v[2]
		g.cam.cine_up = Vector3.UP
		await t.seconds(1.6)
		await t.shot("%s_%s" % [tag, v[0]])
	g.cam.cinematic = false
	env.fog_enabled = fog


## One Treasure Hunt spot of each kind (owner: high on a leaf, on a rock, in a cave, in tall grass,
## out on the ground), as he comes up to it: from behind him, then a closer look.
func _treasure_spot_shots(g: Game) -> void:
	g.player.invuln_t = 9999
	for b in g.balls:
		for par in b.parasites:
			par.visible = false
			par.set_physics_process(false)
	var wanted := [["leaf", 2], ["leaf", 5], ["rock", 0], ["rock", 3], ["cave", 6], ["cave", 1], ["grass", 4], ["grass", 0], ["ground", 1]]
	var objs := ["duck", "gnome", "toaster", "cone", "tv", "microscope", "skateboard", "fire_hat", "toy_car"]
	var n := 0
	for w in wanted:
		var b: MossBall = g.balls[w[1]]
		var rng := RandomNumberGenerator.new()
		rng.seed = 11 + n
		var sets := TreasureHunt.spot_sets(b, 1.0, rng)
		var list: Array = sets[w[0]]
		if list.is_empty():
			continue
		var pos: Vector3 = list[rng.randi() % list.size()]["pos"]
		var node := TreasureModels.node(objs[n % objs.size()], 1.0)
		b.add_child(node)
		var up := b.up_at(pos)
		node.global_transform = Transform3D(Basis(MossBall.frame_at(up, 0.0).x, up, MossBall.frame_at(up, 0.0).z).rotated(up, 0.7), pos).scaled_local(node.scale)
		# Stand him a few metres off on the same surface (or the ground below) and look past him.
		var fr := MossBall.frame_at(up, 0.0)
		var from := pos
		var space := g.get_world_3d().direct_space_state
		for dd in [3.0, 2.2, 4.0]:
			var found := false
			for k in 12:
				var o: Vector3 = pos + fr.z.rotated(up, TAU * k / 12.0) * dd
				var h := space.intersect_ray(PhysicsRayQueryParameters3D.create(o + up * 1.2, o - up * 3.0, TreasureHunt.SOLID_MASK))
				if h.is_empty() or (h["normal"] as Vector3).dot(up) < 0.7:
					continue
				if space.intersect_ray(PhysicsRayQueryParameters3D.create((h["position"] as Vector3) + up * 0.5, pos + up * 0.5, TreasureHunt.SOLID_MASK)).is_empty():
					from = h["position"]
					found = true
					break
			if found:
				break
		var dir := pos - from
		g.player.place(b, from + up * 0.15, dir - up * dir.dot(up))
		g.audio.set_ball(b.index, false)
		g.cam.snap_behind()
		g.cam.pitch = 0.2
		await t.seconds(1.3)
		await t.shot("thspot_%d_%s_w%d" % [n, w[0], b.index + 1])
		g.cam.cinematic = true
		g.cam.cine_pos = pos + up * 1.6 + (from - pos).normalized() * 2.6
		g.cam.cine_look = pos + up * 0.4
		g.cam.cine_up = up
		await t.seconds(0.8)
		await t.shot("thspot_%d_%s_w%d_close" % [n, w[0], b.index + 1])
		g.cam.cinematic = false
		node.queue_free()
		n += 1


## A walkable spot a couple of metres from `target` (for the Treasure Hunt shots).
func _th_approach(b: MossBall, target: Vector3, dist := 2.4) -> Vector3:
	var up := b.up_at(target)
	var fr := MossBall.frame_at(up, 0.0)
	for dd in [dist, dist + 0.8, dist - 0.6]:
		for k in 12:
			var q := b.surface_point((target + fr.z.rotated(up, TAU * k / 12.0) * dd - b.global_position).normalized())
			if TreasureHunt.spot_ok(b, q, 0.3) and TreasureHunt.path_ok(b, q, target):
				return q
	return b.surface_point((target + fr.z * dist - b.global_position).normalized())


func _th_face(g: Game, tp: TreasurePlay, dist := 2.4) -> Array:
	var tg: Dictionary = TreasureHunt.current(tp.st())
	var b: MossBall = g.balls[int(tg["world"])]
	var target: Vector3 = tp.node.global_position
	var from := _th_approach(b, target, dist)
	var up := b.up_at(from)
	var dir := target - from
	g.player.place(b, from + up * 0.1, dir - up * dir.dot(up))
	g.audio.set_ball(b.index, false)
	g.cam.snap_behind()
	g.cam.pitch = 0.22
	return [b, target, from]


## Treasure Hunt in play (docs/TREASURE_HUNT.md): the HUD, a first-hunt object near him, the
## pickup (confetti, fireworks, his dance), the finish card, and a second-hunt object at half size.
func _treasure_hunt_shots(g: Game) -> void:
	g.player.invuln_t = 9999
	for b in g.balls:
		for par in b.parasites:
			par.visible = false
			par.set_physics_process(false)
	var tp: TreasurePlay = g.treasure
	tp.start()
	await t.seconds(2.5)
	# The celebration on open ground, from the side: confetti, the fireworks overhead, the dance.
	var ob := g.balls[0]
	var od := MossBall.dir_ll(20.0, 60.0)
	var ospot := ob.surface_point(od)
	var oup := ob.up_at(ospot)
	var ofr := MossBall.frame_at(oup, 0.0)
	var tg0: Dictionary = TreasureHunt.current(tp.st())
	tg0["pos"] = [ospot.x, ospot.y, ospot.z]
	tg0["world"] = 0.0
	tp._despawn()
	tp.refresh()
	await t.seconds(0.3)
	g.player.place(ob, ospot - ofr.z * 1.7 + oup * 0.1, ofr.z)
	g.cam.snap_behind()
	await t.seconds(0.6)
	var side := ofr.x
	g.cam.cinematic = true
	g.cam.cine_pos = ospot + side * 6.5 + oup * 2.2 - ofr.z * 1.0
	g.cam.cine_look = ospot + oup * 1.6 - ofr.z * 1.0
	g.cam.cine_up = oup
	await t.seconds(0.8)
	await t.shot("th_open_before")
	Input.action_press("lunge")
	await t.frames(2)
	Input.action_release("lunge")
	await t.seconds(0.2)
	await t.shot("th_open_confetti")
	await t.seconds(0.5)
	await t.shot("th_open_fireworks")
	await t.seconds(0.35)
	await t.shot("th_open_fireworks2")
	g.cam.cine_pos = g.player.global_position + side * 2.4 + oup * 0.9 + ofr.z * 0.3
	g.cam.cine_look = g.player.global_position + oup * 0.7
	for k in 6:
		await t.seconds(0.3)
		await t.shot("th_open_dance_%d" % k)
	g.cam.cinematic = false
	await t.seconds(2.5)
	# The same object at first-hunt size and second-hunt size, side by side, beside him.
	var cmp := []
	for k in 2:
		var n2 := TreasureModels.node("duck", 1.0 if k == 0 else 0.5)
		ob.add_child(n2)
		var gp := ob.surface_point((ospot + ofr.x * (k * 2.6 - 1.3) + ofr.z * 1.2 - ob.global_position).normalized())
		n2.global_transform = Transform3D(Basis(ofr.x, ob.up_at(gp), ofr.z).rotated(ob.up_at(gp), PI * 0.8), gp).scaled_local(n2.scale)
		cmp.append(n2)
	g.player.place(ob, ospot - ofr.z * 1.0 + oup * 0.1, ofr.z)
	g.cam.cinematic = true
	g.cam.cine_pos = ospot + ofr.z * 6.0 + oup * 2.2
	g.cam.cine_look = ospot + ofr.z * 0.8 + oup * 0.4
	await t.seconds(1.0)
	await t.shot("th_size_duck_full_vs_half")
	for n2 in cmp:
		n2.queue_free()
	g.cam.cinematic = false
	g.cam.snap_behind()
	await t.seconds(0.5)
	# The first four objects, each in its world, from behind him a couple of metres away (the
	# HUD in the corner); the first one also close up; each collected by a lunge.
	for n in 4:
		var f := await _th_face(g, tp, 3.2)
		await t.seconds(1.0)
		await t.shot("th_%d_near_%s" % [n + 1, TreasureHunt.current(tp.st())["kind"]])
		if n == 0:
			var up: Vector3 = (f[0] as MossBall).up_at(f[1])
			g.cam.cinematic = true
			g.cam.cine_pos = (f[1] as Vector3) + up * 1.6 + ((f[2] as Vector3) - (f[1] as Vector3)).normalized() * 2.4
			g.cam.cine_look = (f[1] as Vector3) + up * 0.4
			g.cam.cine_up = up
			await t.seconds(1.0)
			await t.shot("th_1_close")
			g.cam.cinematic = false
			g.cam.snap_behind()
		# Walk in and lunge.
		for k in 60:
			var flat: Vector3 = (f[1] as Vector3) - g.player.global_position
			flat -= g.player.up * flat.dot(g.player.up)
			if flat.length() < 1.9:
				break
			g.player.use_bot_input = true
			var cf: Vector3 = -g.cam.global_basis.z
			cf = (cf - g.player.up * cf.dot(g.player.up)).normalized()
			var cr := cf.cross(g.player.up)
			var d := flat.normalized()
			g.player.bot_input = Vector2(d.dot(cr), d.dot(cf))
			await t.frames(2)
		g.player.bot_input = Vector2.ZERO
		Input.action_press("lunge")
		await t.frames(2)
		Input.action_release("lunge")
		await t.seconds(3.0)
	await t.shot("th_after_finds")
	# The finish: straight to the last object.
	var st: Dictionary = tp.st()
	st["index"] = 13
	tp.refresh()
	await t.seconds(0.5)
	var f2 := await _th_face(g, tp, 2.0)
	await t.seconds(0.6)
	Input.action_press("lunge")
	await t.frames(2)
	Input.action_release("lunge")
	await t.seconds(1.2)
	await t.shot("th_final_pickup")
	await t.seconds(3.0)
	await t.shot("th_complete_card")
	(tp.panel._card.find_child("NewHunt", true, false) as Button).pressed.emit()
	await t.seconds(1.0)
	await t.shot("th_new_hunt_message")
	await t.seconds(3.0)
	var f3 := await _th_face(g, tp, 3.2)
	await t.seconds(1.0)
	await t.shot("th_hunt2_near_%s" % TreasureHunt.current(st)["kind"])
## The fourteen Treasure Hunt objects (docs/TREASURE_HUNT.md): each alone, close, on open ground in
## a restored world, then the whole set in a row for scale against him.
func _treasure_shots(g: Game) -> void:
	g.player.invuln_t = 9999
	var b := g.balls[0]
	var d := MossBall.dir_ll(20.0, 60.0)
	var at := b.surface_point(d)
	var up := b.up_at(at)
	var fr := MossBall.frame_at(up, 0.0)
	g.player.place(b, b.surface_point((at + fr.z * 30.0 - b.global_position).normalized(), 0.2), fr.z)
	g.cam.cinematic = true
	for k in TreasureHunt.KINDS:
		var n := TreasureModels.node(k[0], 1.0)
		b.add_child(n)
		var gp := b.surface_point(d)
		n.global_transform = Transform3D(Basis(fr.x, up, fr.z).rotated(up, 0.6), gp)
		var sz: float = TreasureModels.BASE_SIZE[k[0]]
		g.cam.cine_pos = gp + up * sz * 0.75 - fr.z * sz * 1.7 + fr.x * sz * 0.9
		g.cam.cine_look = gp + up * sz * 0.35
		g.cam.cine_up = up
		await t.seconds(1.2)
		await t.shot("treasure_%s" % k[0])
		n.queue_free()
	# The set in a row, with him beside it for scale.
	var row := []
	for i in TreasureHunt.KINDS.size():
		var n := TreasureModels.node(TreasureHunt.KINDS[i][0], 1.0)
		b.add_child(n)
		var gp := b.surface_point((at + fr.x * (i - 6.5) * 2.2 - b.global_position).normalized())
		n.global_transform = Transform3D(Basis(fr.x, b.up_at(gp), fr.z).rotated(b.up_at(gp), PI), gp)
		row.append(n)
	g.player.place(b, b.surface_point((at + fr.x * -17.0 - b.global_position).normalized(), 0.2), fr.x)
	g.cam.cine_pos = at + up * 7.0 + fr.z * 20.0 + fr.x * -4.0
	g.cam.cine_look = at + fr.x * -4.0 + up * 0.5
	await t.seconds(1.5)
	await t.shot("treasure_row")
	for n in row:
		n.queue_free()
	g.cam.cinematic = false


## The bala sharks (owner): close beside the trio in Swim Mode, from the side and behind, and the
## whole tank in Live Tank.
func _bala_shots(g: Game) -> void:
	var pr := g.presentation
	pr.enter("play")
	pr.go("swim")
	await t.seconds(0.5)
	var balas: Array = g.fish.fish.filter(func(f): return f["kind"] == "bala")
	for k in 3:
		var c := Vector3.ZERO
		var v := Vector3.ZERO
		for f in balas:
			c += f["pos"]
			v += f["vel"]
		c /= balas.size()
		var fwd := Vector3(v.x, 0, v.z).normalized() if Vector3(v.x, 0, v.z).length() > 0.1 else Vector3.FORWARD
		var side := fwd.cross(Vector3.UP).normalized()
		var off: Vector3 = [side * 9.0, -fwd * 11.0 + Vector3.UP * 2.0, side * -7.0 + fwd * 8.0][k]
		pr.swimmer.global_position = c + off
		pr.swimmer.velocity = Vector3.ZERO
		var look := (c - pr.swimmer.global_position).normalized()
		pr.swimmer.cam_yaw = atan2(-look.x, -look.z)
		pr.swimmer.cam_pitch = asin(clampf(look.y, -1.0, 1.0))
		pr.swimmer.model.visible = false
		await t.frames(3)
		await t.shot("bala_%d" % k)
		pr.swimmer.model.visible = true
		await t.seconds(1.5)
	pr.go("live")
	pr.live_view = 0
	await t.seconds(3.0)
	await t.shot("bala_live")
	pr.exit()


## Tier 2 (docs/TIER2.md): each ability mid-effect at the World 3 shrine's practice targets, the
## HUD button's glyph for each (ready and cooling down), and the pause menu's loadout.
func _tier2_shots(g: Game) -> void:
	g.player.invuln_t = 9999
	var sh: Tier2Shrine = g.balls[2].shrines[0]
	var b := sh.ball
	for id in Tier2.ORDER:
		g.tier2.unlock(id)
	g.hud.reveal_special()
	for par in b.parasites:
		par.visible = false
		par.set_physics_process(false)
	for id in Tier2.ORDER:
		# A quiet spot on World 3 with three practice targets set out ahead of him (left, centre,
		# right), as the shrine's own are.
		var spot := b.surface_point(MossBall.dir_ll(10, 40 + Tier2.ORDER.find(id) * 25), 0.1)
		var up := b.up_at(spot)
		var fr := MossBall.frame_at(up, 0.0)
		_look(g, b.index, spot, -fr.z, 0.28)
		await t.seconds(1.0)
		var at: Vector3 = g.player.global_position
		up = b.up_at(at)
		var face: Vector3 = g.player.facing
		var side := face.cross(up).normalized()
		var near := 0.6 if id == Tier2.BUBBLE else 1.0
		for k in 3:
			var tg := PracticeTarget.new()
			tg.place(b, at + face * [4.0, 5.5, 4.5][k] * near + side * [-2.0, 0.0, 2.0][k] * near + up * 0.6, 8800 + Tier2.ORDER.find(id) * 10 + k)
			g.practice_targets.append(tg)
		await t.frames(2)
		t.log_line("tier2 setup %s: targets alive %d" % [id, g.practice_targets.size()])
		g.tier2.equip(id)
		g.tier2.ready_at = 0.0
		await t.seconds(1.6)
		await t.shot("t2_%s_ready" % id)
		Input.action_press("special")
		await t.frames(2)
		Input.action_release("special")
		await t.seconds({Tier2.CANNON: 0.2, Tier2.BUBBLE: 0.15, Tier2.RUSH: 0.3}[id])
		await t.shot("t2_%s_action" % id)
		await t.seconds(0.25)
		await t.shot("t2_%s_action2" % id)
		t.log_line("tier2 %s: last %s; targets %s; gill %s" % [id, g.t2.last, g.practice_targets.map(func(x): return x.global_position if is_instance_valid(x) else "freed"), g.player.global_position])
		await t.seconds(1.6)
		await t.shot("t2_%s_cooling" % id)
		for tg in g.practice_targets.duplicate():
			if is_instance_valid(tg):
				tg.queue_free()
		g.practice_targets.clear()
	g.pause_menu.open()
	await t.seconds(0.5)
	await t.shot("t2_loadout")
	g.pause_menu.close()


## The aquarium experiences (docs/AQUARIUM.md), through the real controller: the room, inspection
## (centre and both ends of its drag), each Live Tank view and Swim Mode (still, swimming, near fish).
## The UI package (owner, 2026-09-30): title with the Settings gear, Settings from the title, the
## colours workspace (top, scrolled to the bottom, turned front / side / back, two presets and a
## fine-tuned look), and the aquarium's controls (room, Live Tank, Swim).
func _ui_shots(g: Game) -> void:
	var pm: PauseMenu = g.pause_menu
	g._enter_title()
	await t.seconds(1.5)
	await t.shot("ui_01_title")
	g.title._on_settings()
	await t.seconds(0.8)
	await t.shot("ui_02_settings_from_title")
	pm.close()
	await t.seconds(0.4)
	await t.shot("ui_03b_back_to_title")
	g.title._on_colours()
	await t.seconds(1.2)
	var page: GillPage = pm.gill_page
	await t.shot("ui_04_colours_open")
	for v in [["front", PI], ["side", PI * 0.5], ["rear", 0.0]]:
		page._touched = true
		page.yaw = v[1]
		await t.seconds(0.4)
		await t.shot("ui_06_turned_%s" % v[0])
	page.yaw = PI * 0.78
	(page.find_child("Morph_golden", true, false) as Button).pressed.emit()
	await t.seconds(0.5)
	await t.shot("ui_07_preset_golden")
	(page.find_child("Morph_melanoid", true, false) as Button).pressed.emit()
	await t.seconds(0.5)
	await t.shot("ui_08_preset_melanoid")
	(page.find_child("Morph_pink", true, false) as Button).pressed.emit()
	page._body_hue.value = 0.3
	page._dots_bright.value = 0.5
	await t.seconds(0.5)
	await t.shot("ui_09_fine_tuned")
	(page.find_child("Morph_pink", true, false) as Button).pressed.emit()
	(page.find_child("Done", true, false) as Button).pressed.emit()
	await t.seconds(0.5)
	g.title._on_aquarium()
	await t.seconds(2.5)
	await t.shot("ui_10_aquarium_room")
	g.presentation.go("live")
	await t.seconds(2.5)
	await t.shot("ui_11_live_tank")
	g.presentation.back()
	await t.seconds(0.6)
	g.presentation.go("swim")
	await t.seconds(1.5)
	await t.shot("ui_12_swim_hud")
	g.presentation.back()
	await t.seconds(0.6)
	g.presentation.back()
	await t.seconds(0.6)


func _aquarium_shots(g: Game, tag: String) -> void:
	g.player.invuln_t = 9999
	var pr := g.presentation
	pr.enter("play")
	await t.seconds(2.5)
	await t.shot("%s_1room" % tag)
	pr.go("inspect")
	await t.seconds(2.5)
	await t.shot("%s_2inspect" % tag)
	pr.inspect_drag(Vector2(-400, 0))
	await t.seconds(2.0)
	await t.shot("%s_3inspect_left" % tag)
	pr.inspect_drag(Vector2(800, 60))
	await t.seconds(2.0)
	await t.shot("%s_4inspect_right" % tag)
	pr.go("live")
	for i in Presentation.LIVE_VIEWS.size():
		await t.seconds(3.0)
		await t.shot("%s_5live_%s" % [tag, Presentation.LIVE_VIEWS[pr.live_view][0]])
		pr.next_live_view()
	pr.go("swim")
	await t.seconds(1.5)
	await t.shot("%s_6swim_start" % tag)
	# (Pull down to climb, then level out and swim.)
	pr.ui.swim_stick = Vector2(0, 1)
	pr.ui.swim_held = true
	await t.seconds(1.2)
	pr.ui.swim_stick = Vector2(0, -0.6)
	await t.seconds(1.0)
	pr.ui.swim_stick = Vector2.ZERO
	await t.seconds(2.5)
	await t.shot("%s_7swim_fast" % tag)
	pr.ui.swim_held = false
	# Out in open water among the fish.
	var f: Vector3 = g.fish.nearest_point(Vector3(0, 20, 0))
	pr.swimmer.global_position = f + Vector3(0, 2, 14)
	pr.swimmer.velocity = Vector3.ZERO
	pr.swimmer.cam_yaw = 0.0
	pr.swimmer.cam_pitch = 0.05
	await t.seconds(1.2)
	await t.shot("%s_8swim_fish" % tag)
	pr.back()
	await t.seconds(1.0)
	pr.back()
	await t.seconds(1.0)


## The gravel (docs/AQUARIUM.md): close, normal and grazing views inside the tank, and one through
## the front glass from the room.
func _gravel_shots(g: Game, tag: String) -> void:
	g.player.invuln_t = 9999
	g.cam.cinematic = true
	var views := [
		["1close", Vector3(118, -94, 70), Vector3(112, -108, 52)],
		["2normal", Vector3(150, -62, 150), Vector3(100, -104, 90)],
		["3grazing", Vector3(-150, -104, 170), Vector3(-110, -106, 110)],
		["4back", Vector3(-40, -80, 40), Vector3(-60, -100, -150)],
		["5glass", Vector3(40, -70, 330), Vector3(20, -100, 150)],
	]
	for v in views:
		g.cam.cine_pos = v[1]
		g.cam.cine_look = v[2]
		g.cam.cine_up = Vector3.UP
		await t.seconds(1.6)
		await t.shot("%s_%s" % [tag, v[0]])
	g.cam.cinematic = false


func _ball_shots(g: Game, tag: String) -> void:
	g.player.invuln_t = 9999
	for bi in [0, 2, 3, 5]:
		var b := g.balls[bi]
		_look(g, bi, b.surface_point(Vector3.UP, 0.2), Vector3.FORWARD)
		g.cam.cinematic = true
		var side := Vector3(0.8, 0.12, 0.6).normalized()
		g.cam.cine_pos = b.global_position + side * b.radius * 2.7
		g.cam.cine_look = b.global_position + Vector3.UP * b.radius * 0.1
		g.cam.cine_up = Vector3.UP
		await t.seconds(1.5)
		await t.shot("mb_%sb%d_side" % [tag, bi + 1])
		g.cam.cine_pos = b.global_position + Vector3(0.5, 0.75, 0.45).normalized() * b.radius * 1.35
		g.cam.cine_look = b.surface_point(Vector3(0.3, 0.9, 0.3).normalized())
		await t.seconds(1.0)
		await t.shot("mb_%sb%d_top" % [tag, bi + 1])
	g.cam.cinematic = false


## The vortex (Expansion 6 owner review): growing, open from afar and close, its tidal pool, the
## corkscrew ride, and the arrival pool.
func _vortex_shots(g: Game, tag: String) -> void:
	var p := g.player
	p.invuln_t = 9999
	var b0 := g.balls[0]
	var v: Vortex = b0.vortex_out
	var vd := v.dir_a
	var fr := MossBall.frame_at(vd, 0.0)
	v.connected = false
	v.strength = 0.45
	var off := vd.rotated(fr.x, deg_to_rad(20.0))
	_look(g, 0, b0.surface_point(off, 0.2), b0.surface_point(vd) - b0.surface_point(off), 0.12)
	await t.seconds(1.2)
	await t.shot("vx_%s1_growing" % tag)
	v.connected = true
	v.strength = 1.0
	await t.seconds(2.0)
	await t.shot("vx_%s2_open_far" % tag)
	off = vd.rotated(fr.x, deg_to_rad(11.0))
	_look(g, 0, b0.surface_point(off, 0.2), b0.surface_point(vd) - b0.surface_point(off), 0.3)
	await t.seconds(1.0)
	await t.shot("vx_%s3_pool" % tag)
	off = vd.rotated(fr.z, deg_to_rad(9.0))
	_look(g, 0, b0.surface_point(off, 0.2), b0.surface_point(vd) - b0.surface_point(off), -0.25)
	await t.seconds(1.0)
	await t.shot("vx_%s4_up_the_spiral" % tag)
	g._start_cinematic("travel", {"v": v, "reverse": false})
	for k in [0.9, 1.6, 2.4, 3.3, 4.2, 5.4]:
		await t.seconds(k - g.cine_t)
		await t.shot("vx_%s5_ride_%.1f" % [tag, k])
	await t.seconds(1.5)
	var b1 := v.ball_b
	var bd := v.dir_b
	var off2 := bd.rotated(MossBall.frame_at(bd, 0).x, deg_to_rad(14.0))
	_look(g, b1.index, b1.surface_point(off2, 0.2), b1.surface_point(bd) - b1.surface_point(off2), 0.25)
	await t.seconds(1.0)
	await t.shot("vx_%s6_arrival_pool" % tag)


func _look(g: Game, bi: int, pos: Vector3, face: Vector3, pitch := 0.32) -> void:
	var b := g.balls[bi]
	g.player.place(b, pos, face)
	g.audio.set_ball(bi, false)
	g.cam.snap_behind()
	g.cam.pitch = pitch


func _moments(g: Game) -> void:
	var p := g.player
	p.invuln_t = 9999
	# Tutorial prompts on the touch HUD.
	var b0 := g.balls[0]
	_look(g, 0, b0.surface_point(MossBall.dir_ll(84, 0), 0.2), b0.surface_point(MossBall.dir_ll(70, 0)) - b0.surface_point(MossBall.dir_ll(84, 0)))
	g._show_prompt("jump")
	await t.seconds(1.0)
	await t.shot("10_prompt_jump")
	g._hide_prompt("jump", false)
	# Health gills close up (3 of 4 unlocked active: 3 + one upgrade, one lost).
	p.max_health = 4
	p.health = 3
	p.model.set_health(3, 4, false)
	g.cam.distance = 2.2
	g.cam.pitch = 0.7
	await t.seconds(1.0)
	await t.shot("11_health_gills")
	g.cam.distance = 4.4
	# Parasite colour drain: a large parasite after one and two hits.
	var large: Parasite = null
	for par in b0.parasites:
		if par.kind == Parasite.Kind.LARGE:
			large = par
	var up := b0.up_at(large.global_position)
	var side := MossBall.frame_at(up, 0).x
	_look(g, 0, b0.surface_point(b0.up_at(large.global_position + side * 3.5), 0.2), -side)
	large.set_physics_process(false)
	large._gray_target = 1.0 / 3.0
	large._gray = 1.0 / 3.0
	large.set_look(large._gray, 0.0, 0.0)
	await t.seconds(0.6)
	await t.shot("12_parasite_one_third_grey")
	large._gray = 2.0 / 3.0
	large.set_look(large._gray, 0.0, 0.0)
	await t.seconds(0.3)
	await t.shot("13_parasite_two_thirds_grey")
	large.set_physics_process(true)
	# A Regeneration Mote lighting the moss.
	var m: Mote = b0.motes[0]
	var mu := b0.up_at(m.anchor)
	_look(g, 0, m.anchor + mu * 0.3 - MossBall.frame_at(mu, 0).z * -2.5, MossBall.frame_at(mu, 0).z * -1.0)
	await t.seconds(1.0)
	await t.shot("14_mote")
	# Vortex, connected, then mid-travel surf.
	var v: Vortex = b0.vortex_out
	v.connected = true
	v.strength = 1.0
	var vd := b0.up_at(v.mouth_pos(false))
	var off := vd.rotated(MossBall.frame_at(vd, 0).x, deg_to_rad(18.0))
	_look(g, 0, b0.surface_point(off, 0.2), b0.surface_point(vd) - b0.surface_point(off), 0.15)
	await t.seconds(1.5)
	await t.shot("15_vortex_open")
	g._start_cinematic("travel", {"v": v, "reverse": false})
	await t.seconds(2.4)
	await t.shot("16_vortex_surf")
	await t.seconds(4.5)
	await t.shot("17_arrive_ball2")
	# Current-swept grasses on Moss Ball #2.
	var b1 := g.balls[1]
	_look(g, 1, b1.surface_point(MossBall.dir_ll(0, 120), 0.2), Vector3.FORWARD)
	await t.seconds(1.5)
	await t.shot("18_ball2_current")
	# Canopy on Moss Ball #3, and the jungle from below.
	var b2 := g.balls[2]
	var lb: LevelBuilder = b2.get_meta("builder")
	for h in lb.bot_hints:
		if h.has("canopy"):
			var c2: Transform3D = h["c2"]
			_look(g, 2, Levels.leaf_mid(c2, 2.0, 0.0).origin + b2.up_at(c2.origin) * 0.3, -c2.basis.z, 0.25)
			await t.seconds(1.5)
			await t.shot("19_canopy_top")
			var sp: Transform3D = h["spiral"][0]
			_look(g, 2, b2.surface_point(b2.up_at(sp.origin + sp.basis.z * -5.0), 0.2), sp.origin - (sp.origin + sp.basis.z * -5.0), 0.6)
			await t.seconds(1.5)
			await t.shot("20_jungle_spiral")
		if h.has("cave"):
			var door: Vector3 = h["door"]
			var inward := (door - (h["entry"] as Vector3)).normalized()
			_look(g, 2, door + inward * 1.5 + b2.up_at(door) * 0.3, inward, 0.35)
			await t.seconds(1.5)
			await t.shot("21_cave_interior")
			_look(g, 2, h["entry"] + b2.up_at(h["entry"]) * 0.3 - inward * 2.0, inward, 0.2)
			await t.seconds(1.5)
			await t.shot("22_cave_hidden_entrance")
	# ALL CLEAR text over the restored tank.
	for b in g.balls:
		b.add_heal(Vector3.UP, 340.0, 0.0)
	g.g_disp = 1.0
	g.aquarium.apply(1.0)
	_look(g, 0, b0.surface_point(MossBall.dir_ll(-5, 200), 0.2), Vector3.FORWARD, 0.1)
	g.hud.show_all_clear()
	await t.seconds(3.0)
	await t.shot("23_all_clear")


## A fixed-camera close shot (the follow camera's cinematic override, fully weighted).
func _close(g: Game, pos: Vector3, look: Vector3, up: Vector3) -> void:
	g.cam.cinematic = true
	g.cam.cine_pos = pos
	g.cam.cine_look = look
	g.cam.cine_up = up
	g.cam._cine_weight = 1.0


func _open(g: Game) -> void:
	g.cam.cinematic = false
	g.cam._cine_weight = 0.0


## Expansion 6's whole-game visual review: the same views before and after, so the change can be
## judged side by side. Unrestored views first, then the tank part and fully restored.
func _review(g: Game) -> void:
	var p := g.player
	p.invuln_t = 9999
	var names := ["meadow", "hollows", "stems", "terraces", "canyon", "spire", "grotto"]
	# Each ball, from the player's camera at a characteristic spot (Expansion 4 balls: the first climb).
	var spots := [[0, 10.0, 30.0], [1, 10.0, 70.0], [2, 10.0, 110.0]]
	for s in spots:
		var b := g.balls[s[0]]
		_look(g, s[0], b.surface_point(MossBall.dir_ll(s[1], s[2]), 0.2), Vector3.FORWARD)
		await t.seconds(1.5)
		await t.shot("r_ball%d_%s" % [s[0] + 1, names[s[0]]])
	for bi in range(3, g.balls.size()):
		var b := g.balls[bi]
		for h in (b.get_meta("builder") as LevelBuilder).bot_hints:
			if h.has("route"):
				var st: Vector3 = h["start"]
				var first: Vector3 = (h["tops"] as Array)[0]
				var back := st - (first - st).normalized() * 5.0
				_look(g, bi, b.surface_point(b.up_at(back), 0.2), first - back, 0.3)
				await t.seconds(1.5)
				await t.shot("r_ball%d_%s" % [bi + 1, names[bi]])
				break
	# Open water: from high on ball 1 looking out across the tank at the other balls.
	var b0 := g.balls[0]
	_look(g, 0, b0.surface_point(MossBall.dir_ll(40, 90), 0.2), b0.surface_point(MossBall.dir_ll(25, 95)) - b0.surface_point(MossBall.dir_ll(40, 90)), -0.05)
	await t.seconds(1.5)
	await t.shot("r_open_water")
	# Dense reeds; the jungle; the high canopy; a spiral climb from below and a jungle ladder.
	_look(g, 0, b0.surface_point(MossBall.dir_ll(-59, 31), 0.2), -MossBall.frame_at(MossBall.dir_ll(-59, 31), 0.0).z, 0.2)
	await t.seconds(1.5)
	await t.shot("r_reeds")
	var b2 := g.balls[2]
	var lb2: LevelBuilder = b2.get_meta("builder")
	for h in lb2.bot_hints:
		if h.has("route") and h["route"] == "jungle stem 20":
			var st: Vector3 = h["start"]
			var first: Vector3 = (h["tops"] as Array)[0]
			var back := st - (first - st).normalized() * 3.5
			_look(g, 2, b2.surface_point(b2.up_at(back), 0.2), first - back, 0.45)
			await t.seconds(1.5)
			await t.shot("r_jungle_ladder")
			# Standing on a mid-ladder leaf, looking at the next one (the footing a player has).
			var tops: Array = h["tops"]
			var k := tops.size() / 2
			var here: Vector3 = tops[k]
			_look(g, 2, here + b2.up_at(here) * 0.15, (tops[k + 1] as Vector3) - here, 0.55)
			await t.seconds(1.5)
			await t.shot("r_ladder_leaf_footing")
			await _leaf_close(g, b2, "r_leaf_close")
	for h in lb2.bot_hints:
		if h.has("canopy"):
			var c2: Transform3D = h["c2"]
			_look(g, 2, Levels.leaf_mid(c2, 2.0, 0.0).origin + b2.up_at(c2.origin) * 0.3, -c2.basis.z, 0.25)
			await t.seconds(1.5)
			await t.shot("r_high_canopy")
			var sp: Transform3D = h["spiral"][0]
			_look(g, 2, b2.surface_point(b2.up_at(sp.origin + sp.basis.z * -5.0), 0.2), sp.origin - (sp.origin + sp.basis.z * -5.0), 0.6)
			await t.seconds(1.5)
			await t.shot("r_spiral_climb")
	var b5 := g.balls[5]
	for h in (b5.get_meta("builder") as LevelBuilder).bot_hints:
		if h.has("route") and h["route"] == "spire":
			var st: Vector3 = h["start"]
			var first: Vector3 = (h["tops"] as Array)[0]
			var back := st - (first - st).normalized() * 6.0
			_look(g, 5, b5.surface_point(b5.up_at(back), 0.2), first - back, 0.55)
			await t.seconds(1.5)
			await t.shot("r_spire_spiral")
	# A cave: the mouth from outside and the interior.
	for h in lb2.bot_hints:
		if h.has("cave"):
			var door: Vector3 = h["door"]
			var inward := (door - (h["entry"] as Vector3)).normalized()
			_look(g, 2, h["entry"] + b2.up_at(h["entry"]) * 0.3 - inward * 3.0, inward, 0.2)
			await t.seconds(1.5)
			await t.shot("r_cave_mouth")
			_look(g, 2, door + inward * 1.5 + b2.up_at(door) * 0.3, inward, 0.35)
			await t.seconds(1.5)
			await t.shot("r_cave_inside")
	await _gill_shots(g, "r_gill")
	# Parasites: a large one crawling, close; then struck and drifting away limp.
	var large: Parasite = null
	for par in b0.parasites:
		if par.kind == Parasite.Kind.LARGE and par.is_alive():
			large = par
			break
	if large != null:
		var up := b0.up_at(large.global_position)
		var side := MossBall.frame_at(up, 0).x
		_look(g, 0, b0.surface_point(b0.up_at(large.global_position + side * 6.0), 0.2), -side)
		await t.seconds(1.0)
		var lp := large.global_position
		_close(g, lp + up * 1.1 + side * 2.2, lp + up * 0.2, up)
		await t.seconds(0.8)
		await t.shot("r_parasite_close")
		_open(g)
		while large.is_alive():
			large.hit_cd = 0.0
			large.hit(3, large.global_position - side, 1.0)
			await t.frames(1)
		await t.seconds(0.4)
		_close(g, lp + up * 1.6 + side * 3.2, large.global_position, up)
		await t.shot("r_parasite_death_0_4s")
		await t.seconds(0.8)
		_close(g, lp + up * 2.2 + side * 4.0, large.global_position, up)
		await t.shot("r_parasite_death_1_2s")
		await t.seconds(1.3)
		_close(g, lp + up * 3.0 + side * 5.0, large.global_position, up)
		await t.shot("r_parasite_drift_2_5s")
		_open(g)
	# Expansion 5 creatures.
	var seen := {}
	for c in g.ecosystem.all_critters():
		if seen.has(c.species) or not (c.species in ["crab", "stalker", "eel", "puffer", "snail", "shrimp"]):
			continue
		seen[c.species] = true
		var b: MossBall = c.ball
		var pt: Vector3 = c.discover_point()
		var up := b.up_at(pt)
		var away := MossBall.frame_at(up, 30.0).z
		if c is CaveEel:
			away = (c as CaveEel).normal
		elif c is CrabGuardian:
			away = (c as CrabGuardian).facing
		var dist := 3.2 if c is CaveEel else (2.4 if c is ShrimpShoal or c is CanopySnail else 4.0)
		var stand := b.surface_point(b.up_at(pt + away * dist), 0.3)
		_look(g, b.index, stand, pt - stand, 0.35 if c is CanopySnail or c is Pufferfish else 0.15)
		await t.seconds(1.4 if c is CaveEel else 1.0)
		await t.shot("r_critter_%s" % c.species)
	# Restoration: the same two views unrestored (above), then part and fully restored.
	for stage in [["half", 0.5], ["full", 1.0]]:
		var k: float = stage[1]
		for b in g.balls:
			if k >= 1.0:
				b.add_heal(Vector3.UP, 340.0, 0.0)
			else:
				var n := 0
				for z in b.zones:
					if n % 2 == 0:
						b.add_heal(b.zones[z]["dir"], b.zones[z]["radius"] * 1.2, 0.0)
					n += 1
		g.g_disp = k
		g.aquarium.apply(k)
		_look(g, 0, b0.surface_point(MossBall.dir_ll(10, 30), 0.2), Vector3.FORWARD)
		await t.seconds(1.5)
		await t.shot("r_ball1_meadow_%s" % stage[0])
		_look(g, 0, b0.surface_point(MossBall.dir_ll(40, 90), 0.2), b0.surface_point(MossBall.dir_ll(25, 95)) - b0.surface_point(MossBall.dir_ll(40, 90)), -0.05)
		await t.seconds(1.5)
		await t.shot("r_open_water_%s" % stage[0])
		_look(g, 2, b2.surface_point(MossBall.dir_ll(10, 110), 0.2), Vector3.FORWARD)
		await t.seconds(1.5)
		await t.shot("r_ball3_stems_%s" % stage[0])
		await _leaf_close(g, b2, "r_leaf_close_%s" % stage[0])


## The owner's phone-review items close up: a rosette plant, a mote swimming, the crab, the
## pufferfish calm and puffed, a burrowing worm out of its hole.
func _feedback(g: Game, sfx: String) -> void:
	g.player.invuln_t = 9999
	var b2 := g.balls[2]
	# A fern rosette on Giant Stems (the jungle floor).
	_look(g, 2, b2.surface_point(MossBall.dir_ll(10, 110), 0.2), Vector3.FORWARD, 0.3)
	await t.seconds(1.2)
	await t.shot("fb_rosettes" + sfx)
	# A mote, drifting (the camera just off it).
	var b0 := g.balls[0]
	var m: Mote = null
	for x in b0.motes:
		if x.is_available():
			m = x
			break
	if m != null:
		var mu := b0.up_at(m.global_position)
		var side := MossBall.frame_at(mu, 0).x
		_look(g, 0, b0.surface_point(b0.up_at(m.global_position + side * 4.0), 0.2), -side)
		await t.seconds(0.6)
		m.push(side * 1.2)
		for i in 20:
			await t.frames(1)
			_close(g, m.global_position + side * 0.9 + mu * 0.25, m.global_position, mu)
		await t.shot("fb_mote_moving" + sfx)
		_open(g)
	for c in g.ecosystem.all_critters():
		if c is CrabGuardian or c is Pufferfish:
			if c is CrabGuardian and not (c as CrabGuardian).ball.index == 6:
				continue
			var b: MossBall = c.ball
			var pt: Vector3 = c.discover_point()
			var up := b.up_at(pt)
			var away: Vector3 = (c as CrabGuardian).facing if c is CrabGuardian else MossBall.frame_at(up, 30.0).z
			_look(g, b.index, b.surface_point(b.up_at(pt + away * 7.0), 0.3), pt - b.surface_point(b.up_at(pt + away * 7.0)), 0.2)
			await t.seconds(0.8)
			var sd := away.cross(up).normalized()
			var d := 2.4 if c is CrabGuardian else 2.0
			_close(g, pt + away * d + sd * d * 0.6 + up * d * 0.5, pt, up)
			await t.seconds(0.6)
			if c is Pufferfish:
				var pf := c as Pufferfish
				pf.puffed = false
				pf.inflate = 0.0
				pf._pose(0.0)
				await t.shot("fb_puffer_calm" + sfx)
				pf.inflate = 1.0
				pf.puffed = true
				pf._pose(0.0)
				_close(g, pt + away * 3.2 + sd * 1.8 + up * 1.4, pt, up)
				await t.frames(2)
				await t.shot("fb_puffer_puffed" + sfx)
			else:
				await t.shot("fb_crab" + sfx)
			_open(g)
			if c is Pufferfish:
				break
	# A burrowing worm, out of its hole.
	for bb in g.balls:
		for f in bb.foods:
			if (f as Food).type == Food.Type.BURROWER:
				var fo := f as Food
				fo.state = "exposed"
				fo.expose = 0.5
				await t.frames(2)
				var hp: Vector3 = fo._hole_pos
				if hp == Vector3.ZERO:
					continue
				var up := bb.up_at(hp)
				var sd := MossBall.frame_at(up, 0).x
				_look(g, bb.index, bb.surface_point(bb.up_at(hp + sd * 5.0), 0.2), -sd)
				await t.seconds(0.8)
				fo.state = "exposed"
				_close(g, hp + sd * 1.3 + up * 0.5, hp + up * 0.25, up)
				await t.seconds(0.5)
				await t.shot("fb_burrower" + sfx)
				_open(g)
				return


## Each Expansion 5 species close up (judging silhouettes and construction), then as the player
## first meets it.
func _critter_close(g: Game) -> void:
	g.player.invuln_t = 9999
	var seen := {}
	for c in g.ecosystem.all_critters():
		if seen.has(c.species):
			continue
		seen[c.species] = true
		var b: MossBall = c.ball
		var pt: Vector3 = c.discover_point()
		var up := b.up_at(pt)
		var away := MossBall.frame_at(up, 30.0).z
		if c is CaveEel:
			away = (c as CaveEel).normal
		elif c is CrabGuardian:
			away = (c as CrabGuardian).facing
		var stand := b.surface_point(b.up_at(pt + away * 6.0), 0.3)
		if c is GlowWorms:
			stand = b.surface_point(b.up_at((c as GlowWorms).cave_centre), 0.3)
		_look(g, b.index, stand, pt - stand, 0.2)
		await t.seconds(1.0)
		var d := 1.6 if c is ShrimpShoal or c is CanopySnail or c is LeafHopper else 2.6
		if c is GlowWorms:
			d = 3.0
		var side := away.cross(up).normalized()
		_close(g, pt + away * d + side * d * 0.5 + up * d * 0.45, pt, up)
		await t.seconds(0.8 if not c is CaveEel else 1.5)
		await t.shot("cc_%s" % c.species)
		if c is CaveEel:
			# Out of its crevice, mid-strike (its body).
			var e := c as CaveEel
			e.set_active(false)
			e.ext = 1.6
			e._dir = e.normal
			e._pose()
			await t.frames(2)
			await t.shot("cc_eel_out")
			e.set_active(true)
		_open(g)


## Parasites of each size close up, crawling; then a large one struck and drifting away.
func _parasite_shots(g: Game) -> void:
	var b0 := g.balls[0]
	g.player.invuln_t = 9999
	for kind in [Parasite.Kind.SMALL, Parasite.Kind.MEDIUM, Parasite.Kind.LARGE]:
		var par: Parasite = null
		for x in b0.parasites:
			if x.kind == kind and x.is_alive():
				par = x
				break
		if par == null:
			continue
		var up := b0.up_at(par.global_position)
		var side := MossBall.frame_at(up, 0).x
		_look(g, 0, b0.surface_point(b0.up_at(par.global_position + side * 7.0), 0.2), -side)
		await t.seconds(1.2)
		var lp := par.global_position
		var d := 1.4 + par.seg_radius * 6.0
		_close(g, lp + up * d * 0.6 + side * d, lp + up * 0.1, up)
		await t.seconds(0.7)
		await t.shot("par_%d" % kind)
		_open(g)
		if kind == Parasite.Kind.LARGE:
			while par.is_alive():
				par.hit_cd = 0.0
				par.hit(3, par.global_position - side, 1.0)
				await t.frames(1)
			for k in [[0.15, "par_struck_0_15s"], [0.6, "par_dying_0_75s"], [0.9, "par_drift_1_65s"], [1.2, "par_drift_2_85s"]]:
				await t.seconds(k[0])
				_close(g, lp + up * (2.0 + k[0] * 2.0) + side * (3.5 + k[0] * 2.0), par.global_position, up)
				await t.shot(k[1])
			_open(g)


## Gill close up: three-quarter front, side on and from above.
func _gill_shots(g: Game, prefix: String) -> void:
	var p := g.player
	var b0 := g.balls[0]
	var gp := b0.surface_point(MossBall.dir_ll(12, 30), 0.1)
	_look(g, 0, gp, Vector3.FORWARD)
	await t.seconds(1.5)
	var gu := p.up
	var gf := p.facing
	var gr := gf.cross(gu).normalized()
	var head := p.global_position + gu * 0.35 + gf * 0.35
	_close(g, head + gf * 1.5 + gr * 0.9 + gu * 0.5, head, gu)
	await t.seconds(0.5)
	await t.shot(prefix + "_front")
	_close(g, p.global_position + gu * 0.4 + gr * 2.0 + gf * 0.2, p.global_position + gu * 0.3, gu)
	await t.seconds(0.4)
	await t.shot(prefix + "_side")
	_close(g, p.global_position + gu * 2.2 - gf * 1.0, p.global_position + gu * 0.2 + gf * 0.2, gu)
	await t.seconds(0.4)
	await t.shot(prefix + "_top")
	_open(g)


## His idles and tail whip (dev-000024 physical playtest polish), frame by frame. Slowed down
## (Engine.time_scale) so the software renderer catches each moment at its time.
func _gill_anim(g: Game) -> void:
	var p := g.player
	var m := p.model
	for b in g.balls:
		b.add_heal(Vector3.UP, 340.0, 0.0)
	g.g_disp = 1.0
	g.aquarium.apply(1.0)
	var b0 := g.balls[0]
	_look(g, 0, b0.surface_point(MossBall.dir_ll(12, 30), 0.1), Vector3.FORWARD)
	await t.seconds(1.5)
	var gu := p.up
	var gf := p.facing
	var gr := gf.cross(gu).normalized()
	var c := p.global_position + gu * 0.3
	Engine.time_scale = 0.2
	var names := ["lookaround", "scoot", "tilt", "stretch", "lookup"]
	var times := [[0.0, 0.6, 1.1, 1.7, 2.1, 2.9, 3.4, 4.1, 4.6], [0.0, 0.8, 1.2, 2.1, 2.6, 3.3, 3.8], [0.0, 0.8, 1.37, 1.95, 2.8], [0.0, 0.7, 1.0, 1.8, 2.3, 2.5, 3.4], [0.0, 0.8, 1.6, 2.4, 3.3]]
	var kinds: Array = Settings.test_args.get("kinds", "0,1,2,3").split(",", false)
	for ks in kinds:
		var k := int(ks)
		for view in ["side", "front"]:
			if view == "side":
				_close(g, c + gr * 2.3 + gf * 0.5 + gu * 0.45, c + gf * 0.1, gu)
			else:
				_close(g, c + gf * 2.1 + gr * 1.0 + gu * 0.7, c, gu)
			m.idle_kind = AxolotlModel.Idle.NONE
			await t.seconds(0.6)
			var from := p.global_position
			m.start_idle(k)
			m.idle_side = 1.0
			var shot_i := 0
			for target in times[k]:
				while m.idle_kind == k and m.idle_s < target:
					await t.frames(1)
				await t.shot("idle_%s_%s_%d" % [names[k], view, shot_i])
				t.log_line("idle %s %s at %.2f s: rig offset %s, body moved %.4f m" % [names[k], view, m.idle_s, str(m.rig.position), from.distance_to(p.global_position)])
				shot_i += 1
			while m.idle_kind == k:
				await t.frames(1)
			await t.seconds(0.4)
			t.log_line("idle %s done: rig offset %s (|%.4f|), body moved %.4f m" % [names[k], str(m.rig.position), m.rig.position.length(), from.distance_to(p.global_position)])
	# The whip from above (its arc is the hit area) and from the game camera.
	for view in (["above", "game"] if Settings.test_args.get("whip", "1") == "1" else []):
		if view == "above":
			_close(g, c + gu * 3.6 + gf * 1.2, c - gf * 0.4, gf)
		else:
			_open(g)
			g.cam.snap_behind()
		m.idle_kind = AxolotlModel.Idle.NONE
		Engine.time_scale = 1.0
		await t.seconds(0.8)
		Engine.time_scale = 0.08
		Input.action_press("swipe")
		await t.frames(1)
		Input.action_release("swipe")
		var i := 0
		for target in ([0.02, 0.05, 0.08, 0.1, 0.13, 0.17, 0.24, 0.35, 0.5] if view == "above" else [0.05, 0.09, 0.13, 0.2]):
			while m.whip_active() and m._whip_s < target:
				await t.frames(1)
			await t.shot("whip_%s_%d" % [view, i])
			t.log_line("whip %s at %.3f s: tail tip %.0f deg" % [view, m._whip_s, rad_to_deg(m.whip_tip_az)])
			i += 1
	Engine.time_scale = 1.0
	_open(g)


## Mote Open Issue #1: his body through a turn on the spot, a running curve, onto a slope and over
## a short lip, slowed down. `--nofollow=1` shows the old rigid body (and no pull over the lip) for
## a before/after pair.
func _loco_shots(g: Game) -> void:
	var p := g.player
	var m := p.model
	var old: bool = Settings.test_args.get("nofollow", "0") == "1"
	m.follow = not old
	for b in g.balls:
		b.add_heal(Vector3.UP, 340.0, 0.0)
	g.g_disp = 1.0
	g.aquarium.apply(1.0)
	var b0 := g.balls[0]
	var at := MossBall.dir_ll(12, 30)
	var up := b0.up_at(b0.surface_point(at))
	var fwd := -MossBall.frame_at(up, 0.0).z
	var right := fwd.cross(up)
	var frame := Transform3D(Basis(right, up, -fwd), b0.surface_point(at))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.42, 0.3)
	mat.roughness = 0.9
	var hold := func(dir: Vector3) -> void:
		var cf: Vector3 = -g.cam.global_basis.z
		cf = (cf - p.up * cf.dot(p.up)).normalized()
		var cr := cf.cross(p.up)
		var d := (dir - p.up * dir.dot(p.up)).normalized()
		p.bot_input = Vector2(d.dot(cr), d.dot(cf))
	p.use_bot_input = true
	p.invuln_t = 9999
	# 1. A quarter turn from a standstill, from above.
	p.place(b0, b0.surface_point(at, 0.05), fwd)
	g.cam.snap_behind()
	await t.seconds(1.2)
	var c := p.global_position + up * 0.2
	_close(g, c + up * 3.2 + fwd * 0.3 + right * 0.4, c + right * 0.2, fwd)
	await t.seconds(0.5)
	var at_f := [3, 6, 9, 13, 20, 40]
	var fi := 0
	for f in 41:
		# (Only a turn: he faces round on the spot, then would set off; stop him there.)
		hold.call(right if f < 8 else Vector3.ZERO)
		if f >= 8:
			p.bot_input = Vector2.ZERO
		await t.frames(1)
		if fi < at_f.size() and f == at_f[fi]:
			Engine.time_scale = 0.02
			await t.frames(1)
			await t.shot("turn_%d" % fi)
			Engine.time_scale = 1.0
			fi += 1
	p.bot_input = Vector2.ZERO
	# 2. A running curve, from above and behind.
	p.place(b0, b0.surface_point(at, 0.05), fwd)
	_open(g)
	g.cam.snap_behind()
	await t.seconds(0.3)
	var dir := fwd
	for f in 150:
		if f >= 60:
			dir = dir.rotated(p.up, -0.05)
		hold.call(fwd if f < 60 else dir)
		await t.frames(1)
		if f == 100:
			var cc := p.global_position + p.up * 0.2
			_close(g, cc + p.up * 3.4 - p.facing * 0.6, cc - p.facing * 0.3, p.facing)
			Engine.time_scale = 0.1
			await t.frames(2)
			await t.shot("curve")
			Engine.time_scale = 1.0
	p.bot_input = Vector2.ZERO
	_open(g)
	# 3. Onto a 30 degree slope (side view), and 4. over a 0.3 m lip (side view).
	for what in ["slope", "lip"]:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var mi := MeshInstance3D.new()
		if what == "slope":
			var run := 1.0 / tan(deg_to_rad(30.0))
			var pts := PackedVector3Array()
			for x in [-1.5, 1.5]:
				pts.append(Vector3(x, -0.4, -(1.6 - 0.4 * run)))
				pts.append(Vector3(x, 2.0, -(1.6 + 2.0 * run)))
				pts.append(Vector3(x, 2.0, -(1.6 + 2.0 * run + 3.0)))
				pts.append(Vector3(x, -0.4, -(1.6 + 2.0 * run + 3.0)))
			var sh := ConvexPolygonShape3D.new()
			sh.points = pts
			cs.shape = sh
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for q in [[0, 1, 5, 4], [1, 2, 6, 5], [0, 4, 7, 3], [4, 5, 6, 7], [0, 3, 2, 1], [3, 7, 6, 2]]:
				for k in [0, 1, 2, 0, 2, 3]:
					st.add_vertex(pts[q[k]])
			st.generate_normals()
			mi.mesh = st.commit()
		else:
			var bx := BoxShape3D.new()
			bx.size = Vector3(3.0, 0.7, 6.0)
			cs.shape = bx
			var bm := BoxMesh.new()
			bm.size = bx.size
			mi.mesh = bm
			cs.position = Vector3(0, -0.05, -(1.3 + 3.0))
			mi.position = cs.position
		mi.material_override = mat
		body.add_child(cs)
		body.add_child(mi)
		g.add_child(body)
		body.global_transform = frame
		await t.frames(2)
		p.place(b0, b0.surface_point(at, 0.05), fwd)
		g.cam.snap_behind()
		await t.seconds(0.6)
		var side := p.global_position + up * 0.4 + fwd * 1.6
		_close(g, side + right * 2.6 + up * 0.2, side, up)
		await t.seconds(0.3)
		var shots_at: Array = [0.3, 0.38, 0.46, 0.56] if what == "slope" else [0.2, 0.28, 0.33, 0.4, 0.5]
		var el := 0.0
		var si := 0
		Engine.time_scale = 1.0
		while si < shots_at.size() and el < 3.0:
			if old:
				p._lip_armed = false
			hold.call(fwd)
			await t.frames(1)
			el += 1.0 / 60.0
			if el >= shots_at[si]:
				Engine.time_scale = 0.05
				await t.frames(1)
				await t.shot("%s_%d" % [what, si])
				t.log_line("%s %d at %.2f s: %.2f m ahead, %.2f m up, pulls %d" % [what, si, el, (p.global_position - frame.origin).dot(fwd), (p.global_position - frame.origin).dot(up), p.mantles])
				Engine.time_scale = 1.0
				si += 1
		p.bot_input = Vector2.ZERO
		body.queue_free()
		await t.frames(2)
	Engine.time_scale = 1.0
	_open(g)


## Locomotion before/after (second pass, after the phone playtest of dev-000033): each scenario is
## driven with the stick as a player would, and captured at fixed times from the GAMEPLAY camera
## (`--view=game`) or from the side (`--view=side`), so the same run on two builds compares frame for
## frame. `--scen=a,b` picks scenarios; `--rt=ball:lat:lon:heading;...` adds real authored spots.
func _loco2_shots(g: Game) -> void:
	var p := g.player
	for b in g.balls:
		b.add_heal(Vector3.UP, 340.0, 0.0)
	g.g_disp = 1.0
	g.aquarium.apply(1.0)
	var view: String = Settings.test_args.get("view", "game")
	var pick: String = Settings.test_args.get("scen", "")
	var b0 := g.balls[0]
	var at := MossBall.dir_ll(12, 30)
	var up0 := b0.up_at(b0.surface_point(at))
	var fwd0 := -MossBall.frame_at(up0, 0.0).z
	var right0 := fwd0.cross(up0)
	var frame := Transform3D(Basis(right0, up0, -fwd0), b0.surface_point(at))
	p.use_bot_input = true
	p.invuln_t = 99999
	var hold := func(dir: Vector3) -> void:
		var cf: Vector3 = -g.cam.global_basis.z
		cf = (cf - p.up * cf.dot(p.up)).normalized()
		var cr := cf.cross(p.up)
		var d := (dir - p.up * dir.dot(p.up)).normalized()
		p.bot_input = Vector2(d.dot(cr), d.dot(cf))
	# Profiles (ahead, height) for rigs, drawn in moss.
	var band_run := 0.35 / tan(deg_to_rad(70.0))
	var profs := {
		"incline": [Vector2(1.3, -0.4), Vector2(1.6, 0.0), Vector2(1.6 + 1.2 / tan(deg_to_rad(30.0)), 1.2), Vector2(9.0, 1.2)],
		"lip": [Vector2(1.3, -0.4), Vector2(1.6, 0.0), Vector2(1.6 + band_run, 0.35), Vector2(1.6 + band_run + 0.9 / tan(deg_to_rad(30.0)), 1.25), Vector2(9.0, 1.25)],
		"face": [Vector2(1.3, -0.4), Vector2(1.6, 0.0), Vector2(1.6 + 2.6 / tan(deg_to_rad(66.0)), 2.6), Vector2(9.0, 2.6)],
	}
	var scen := []
	# [name, rig, start offset (right, ahead), heading (deg from fwd0, + to the right), stick script, capture times]
	scen.append(["flat", "", Vector2(0, 0), 0.0, func(tt: float) -> Vector3: return fwd0, [0.5, 0.7, 0.9, 1.1]])
	scen.append(["broad_turn", "", Vector2(0, 0), 0.0, func(tt: float) -> Vector3: return fwd0 if tt < 0.5 else fwd0.rotated(up0, -0.5), [0.55, 0.7, 0.85, 1.0, 1.2]])
	scen.append(["sharp_turn", "", Vector2(0, 0), 0.0, func(tt: float) -> Vector3: return fwd0 if tt < 0.5 else fwd0.rotated(up0, -1.75), [0.55, 0.62, 0.7, 0.8, 0.95]])
	scen.append(["incline", "incline", Vector2(0, -1.5), 0.0, func(tt: float) -> Vector3: return fwd0, [0.4, 0.55, 0.7, 0.85, 1.0, 1.2]])
	scen.append(["lip", "lip", Vector2(0, -1.5), 0.0, func(tt: float) -> Vector3: return fwd0, [0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.15, 1.3, 1.5]])
	scen.append(["angled", "lip", Vector2(-2.2, -1.0), 40.0, func(tt: float) -> Vector3: return fwd0.rotated(up0, -deg_to_rad(40.0)), [0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.15, 1.3, 1.5]])
	scen.append(["face", "face", Vector2(0, -1.5), 0.0, func(tt: float) -> Vector3: return fwd0, [0.4, 0.6, 0.8, 1.0, 1.3, 1.7]])
	scen.append(["lateral", "incline", Vector2(-2.0, 2.4), 90.0, func(tt: float) -> Vector3: return right0, [0.3, 0.5, 0.7, 0.9]])
	var rigs := {}
	var mat: Material = b0.moss_material
	for k in profs:
		var prof: Array = profs[k]
		var pts := PackedVector3Array()
		var z0: float = (prof[0] as Vector2).x
		var z1: float = (prof[prof.size() - 1] as Vector2).x
		for x in [-5.0, 5.0]:
			pts.append(Vector3(x, -0.4, -z0))
			for v in prof:
				pts.append(Vector3(x, (v as Vector2).y, -(v as Vector2).x))
			pts.append(Vector3(x, -0.4, -z1))
		var sh := ConvexPolygonShape3D.new()
		sh.points = pts
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var m := prof.size() + 2
		for i in m:
			var i1 := (i + 1) % m
			for idx in [i, m + i1, m + i, i, i1, m + i1]:
				st.add_vertex(pts[idx])
		st.generate_normals()
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var cs := CollisionShape3D.new()
		cs.shape = sh
		body.add_child(cs)
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = mat
		body.add_child(mi)
		rigs[k] = body
	# Real authored spots from the incline survey.
	for spec in str(Settings.test_args.get("rt", "")).split(";", false):
		var f := spec.split(":")
		var bi := int(f[0])
		var bb := g.balls[bi]
		var d := MossBall.dir_ll(float(f[1]), float(f[2]))
		var fr := MossBall.frame_at(d, 0.0)
		var hdg := deg_to_rad(float(f[3]))
		var fw: Vector3 = fr.x * sin(hdg) - fr.z * cos(hdg)
		scen.append(["real_b%d_%s_%s" % [bi + 1, f[1], f[2]], "@%d" % bi, bb.surface_point(d, 0.04), fw, func(tt: float) -> Vector3: return fw, [0.3, 0.6, 0.9, 1.2, 1.5, 1.8, 2.2]])
	for sc in scen:
		if pick != "" and not pick.split(",").has(sc[0]) and not (pick == "real" and str(sc[0]).begins_with("real")):
			continue
		var rig: String = sc[1]
		var body: StaticBody3D = rigs.get(rig, null)
		var bb := b0
		var start: Vector3
		var face: Vector3
		if rig.begins_with("@"):
			bb = g.balls[int(rig.substr(1))]
			start = sc[2]
			face = sc[3]
		else:
			if body:
				g.add_child(body)
				body.global_transform = frame
			var off: Vector2 = sc[2]
			start = b0.surface_point(b0.up_at(frame.origin + right0 * off.x + fwd0 * off.y), 0.05)
			if rig == "incline" and off.y > 1.0:
				start = frame * Vector3(off.x, 0.95, -(1.6 + 0.95 / tan(deg_to_rad(30.0))))
			face = fwd0.rotated(up0, -deg_to_rad(float(sc[3])))
		await t.frames(2)
		p.place(bb, start, face)
		g.cam.snap_behind()
		await t.seconds(0.8)
		var times: Array = sc[5]
		var fn: Callable = sc[4]
		var el := 0.0
		var ci := 0
		while ci < times.size():
			hold.call(fn.call(el))
			if view == "side":
				var c := p.global_position + p.up * 0.35
				var sdir := (fn.call(0.0) as Vector3).cross(p.up).normalized()
				_close(g, c + sdir * 3.2 + p.up * 0.6 - (fn.call(0.0) as Vector3) * 0.3, c, p.up)
			await t.frames(1)
			el += 1.0 / Engine.physics_ticks_per_second
			if el >= float(times[ci]) - 0.001:
				await t.shot("%s_%s_%d" % [sc[0], view, ci])
				var sp := g.get_viewport().get_camera_3d().unproject_position(p.body_center())
				t.log_line("LOCO2 %s %s %d at %.2f s: crawls %d screen %d %d" % [sc[0], view, ci, el, p.get("mantles") if "mantles" in p else 0, int(sp.x), int(sp.y)])
				ci += 1
		p.bot_input = Vector2.ZERO
		_open(g)
		if body:
			g.remove_child(body)
	# Swimming (Swim Mode): up, down, and turning while climbing.
	if pick == "" or pick.split(",").has("swim"):
		var pr: Presentation = g.presentation
		pr.enter("play")
		pr.go("swim")
		await t.seconds(1.0)
		for sw in [["swim_up", Vector2(0, -1)], ["swim_down", Vector2(0, 1)], ["swim_yawpitch", Vector2(0.8, -0.6)]]:
			pr.ui.swim_held = true
			pr.ui.swim_stick = Vector2.ZERO
			pr.swimmer.pitch = 0.0
			await t.seconds(1.0)
			for k in 5:
				pr.ui.swim_stick = sw[1]
				await t.seconds(0.18)
				await t.shot("%s_%s_%d" % [sw[0], view, k])
				var sp2 := g.get_viewport().get_camera_3d().unproject_position(pr.swimmer.global_position)
				t.log_line("LOCO2 %s %s %d at 0 s: crawls 0 screen %d %d" % [sw[0], view, k, int(sp2.x), int(sp2.y)])
			pr.ui.swim_stick = Vector2.ZERO
		pr.ui.swim_held = false
		pr.exit()

## The landscape menus (00038, phone audit 2026-09-30 §A): Settings and the colours page at this
## window's size with a 90 px camera cut-out on the left (drawn as a black bar), from the pause menu
## (as it opens, and at its fullest: Tier 2 row, Treasure Hunt, the New Run question) and from the
## title. Run it at 1280x720 and 1600x720 (--resolution).
func _menus_shots(g: Game) -> void:
	var pm: PauseMenu = g.pause_menu
	var w := int(g.get_viewport().get_visible_rect().size.x)
	UiStyle.test_inset = Vector4(90, 0, 0, 0)
	var cut := CanvasLayer.new()
	cut.layer = 100
	var bar := ColorRect.new()
	bar.color = Color(0, 0, 0, 0.92)
	bar.position = Vector2.ZERO
	bar.size = Vector2(90, 720)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cut.add_child(bar)
	g.add_child(cut)
	t.log_line("window %s, viewport %s" % [str(DisplayServer.window_get_size()), str(g.get_viewport().get_visible_rect().size)])
	pm.open()
	await t.seconds(0.6)
	await t.shot("menus_%d_settings_pause" % w)
	t.log_line("settings panel %s" % str(pm._panel.get_global_rect()))
	var t2 := g.tier2
	g.tier2 = Tier2.new()
	g.tier2.unlock(Tier2.CANNON)
	g.tier2.unlock(Tier2.BUBBLE)
	g.tier2.equip(Tier2.BUBBLE)
	pm._refresh()
	pm._loadout.visible = true
	pm._treasure.visible = true
	pm._treasure.text = "Resume Treasure Hunt"
	(pm._panel.find_child("Ask", true, false) as Button).pressed.emit()
	await t.seconds(0.3)
	pm._layout()
	await t.seconds(0.3)
	await t.shot("menus_%d_settings_pause_fullest" % w)
	t.log_line("settings panel at its fullest %s" % str(pm._panel.get_global_rect()))
	(pm._panel.find_child("Cancel", true, false) as Button).pressed.emit()
	g.tier2 = t2
	pm._open_gill()
	await t.seconds(1.2)
	await t.shot("menus_%d_colours_pause" % w)
	t.log_line("colours column %s stage %s" % [str(pm.gill_page.controls.get_global_rect()), str(pm.gill_page.stage.get_global_rect())])
	(pm.gill_page.find_child("Done", true, false) as Button).pressed.emit()
	pm.close()
	await t.seconds(0.3)
	g._enter_title()
	await t.seconds(1.5)
	g.title._on_settings()
	await t.seconds(0.6)
	await t.shot("menus_%d_settings_title" % w)
	pm.close()
	await t.seconds(0.3)
	g.title._on_colours()
	await t.seconds(1.2)
	await t.shot("menus_%d_colours_title" % w)
	(pm.gill_page.find_child("Done", true, false) as Button).pressed.emit()
	await t.seconds(0.3)
	UiStyle.test_inset = Vector4.ZERO
	cut.queue_free()


## The colours page (owner request): each morph on the page, then two of them in the world.
func _colour_shots(g: Game) -> void:
	var b0 := g.balls[0]
	_look(g, 0, b0.surface_point(MossBall.dir_ll(12, 30), 0.1), Vector3.FORWARD)
	await t.seconds(1.5)
	g.pause_menu.open()
	await t.seconds(0.3)
	await t.shot("colours_menu")
	g.pause_menu._open_gill()
	for mo in GillLook.MORPHS:
		(g.pause_menu.gill_page.find_child("Morph_" + mo["id"], true, false) as Button).pressed.emit()
		await t.seconds(0.4)
		await t.shot("colours_page_%s" % mo["id"])
	g.pause_menu.gill_page._body_hue.value = 0.3
	g.pause_menu.gill_page._dots_bright.value = 0.5
	await t.seconds(0.4)
	await t.shot("colours_page_tuned")
	g.pause_menu.close()
	var p := g.player
	for id in ["golden", "wild", "melanoid"]:
		Settings.set_gill_look(id, 0.0, 1.0, 0.0, 1.0)
		var gu := p.up
		var gf := p.facing
		var gr := gf.cross(gu).normalized()
		var head := p.global_position + gu * 0.35 + gf * 0.35
		_close(g, head + gf * 1.5 + gr * 0.9 + gu * 0.5, head, gu)
		await t.seconds(0.5)
		await t.shot("colours_world_%s" % id)
	Settings.set_gill_look("pink", 0.0, 1.0, 0.0, 1.0)
	# Patterns: each built-in as markings, two in full colour, and a picture "from the phone".
	var gu2 := p.up
	var gf2 := p.facing
	var gr2 := gf2.cross(gu2).normalized()
	var head2 := p.global_position + gu2 * 0.35 + gf2 * 0.2
	for pat in GillLook.PATTERNS:
		if pat[0] == "none":
			continue
		for mode in [0, 1]:
			if mode == 1 and not pat[0] in ["hearts", "stars"]:
				continue
			Settings.set_gill_pattern(pat[0], mode, 3)
			_close(g, head2 + gf2 * 1.3 + gr2 * 1.2 + gu2 * 0.9, head2 - gf2 * 0.3, gu2)
			await t.seconds(0.5)
			await t.shot("pattern_%s_%s" % [pat[0], ["markings", "colour"][mode]])
	var photo := Image.load_from_file(ProjectSettings.globalize_path("res://assets/icon/icon_192.png"))
	var pp := OS.get_user_data_dir().path_join("shot_pick.png")
	photo.save_png(pp)
	g.pause_menu.open(true)
	g.pause_menu._open_gill(true)
	g.pause_menu.gill_page.import_picture(pp)
	Settings.set_gill_pattern(GillLook.UPLOAD, 1, 2)
	await t.seconds(0.5)
	await t.shot("pattern_page_upload")
	# The pattern swatches themselves (drawn off the main thread since this package).
	await t.seconds(0.4)
	await t.shot("pattern_page_swatches")
	(g.pause_menu.gill_page.find_child("Done", true, false) as Button).pressed.emit()
	_close(g, head2 + gf2 * 1.3 + gr2 * 1.2 + gu2 * 0.9, head2 - gf2 * 0.3, gu2)
	await t.seconds(0.5)
	await t.shot("pattern_upload_world")
	Settings.set_gill_pattern("none", 0, 3)
	_open(g)
	# The title screen's button.
	g.title.show_title()
	await t.seconds(0.5)
	await t.shot("title_with_colours")
	g.title._on_colours()
	await t.seconds(0.5)
	await t.shot("title_colours_page")
	(g.pause_menu.gill_page.find_child("Done", true, false) as Button).pressed.emit()


## Undisturbed vegetation over time (dev-000024 playtest polish): the same view every 0.25 s with
## the axolotl far away, for a reed bed, a jungle ladder, and a restored ball's sprouts.
func _sway_shots(g: Game) -> void:
	var p := g.player
	var views := []
	var b0 := g.balls[0]
	var reeds := MossBall.dir_ll(-59, 31)
	var ru := b0.up_at(b0.surface_point(reeds))
	var rf := MossBall.frame_at(ru, 0.0)
	views.append(["reeds", b0, b0.surface_point(reeds, 1.1) + rf.x * 3.2, b0.surface_point(reeds, 0.5), ru])
	var b2 := g.balls[2]
	var lb: LevelBuilder = b2.get_meta("builder")
	for n in lb.root.get_children():
		if n is StaticBody3D and (n as StaticBody3D).collision_layer == LevelBuilder.CLIMB_LAYER and n.has_meta("leaves") and (n.get_meta("leaves") as Array).size() >= 10:
			var xf: Transform3D = (n.get_meta("leaves") as Array)[4][0]
			var up := b2.up_at(xf.origin)
			views.append(["ladder", b2, xf.origin + xf.basis.x * 4.5 + up * 1.2, xf.origin - xf.basis.z * 1.0 + up * 0.3, up])
			break
	var top := MossBall.dir_ll(62, 20)
	var tu := b0.up_at(b0.surface_point(top))
	var tf := MossBall.frame_at(tu, 0.0)
	views.append(["restored_sprouts", b0, b0.surface_point(top, 2.2) + tf.x * 5.0, b0.surface_point(top, 1.0), tu])
	for v in views:
		var b: MossBall = v[1]
		if v[0] == "restored_sprouts":
			for bb in g.balls:
				bb.add_heal(Vector3.UP, 340.0, 0.0)
			g.g_disp = 1.0
			g.aquarium.apply(1.0)
		# He waits well away, so nothing but the water moves the plants.
		var away := b.up_at(v[3]).rotated(MossBall.frame_at(b.up_at(v[3]), 0).x, deg_to_rad(40.0))
		p.place(b, b.surface_point(away, 0.2), Vector3.FORWARD)
		g.audio.set_ball(b.index, false)
		_close(g, v[2], v[3], v[4])
		await t.seconds(2.0)
		for k in 16:
			await t.shot("sway_%s_%02d" % [v[0], k])
			await t.seconds(0.25)
	_open(g)


## A jungle ladder's leaves side on from 3 m, half way up: how each leaf grows from the stem.
func _leaf_close(g: Game, b: MossBall, name_: String) -> void:
	var lb: LevelBuilder = b.get_meta("builder")
	for n in lb.root.get_children():
		if n is StaticBody3D and (n as StaticBody3D).collision_layer == LevelBuilder.CLIMB_LAYER and n.has_meta("leaves"):
			var ls: Array = n.get_meta("leaves")
			if ls.size() < 10:
				continue
			var xf: Transform3D = ls[4][0]
			var up := b.up_at(xf.origin)
			var side := xf.basis.x.normalized()
			var base := xf.origin
			_look(g, b.index, b.surface_point(b.up_at(base + side * 4.0), 0.2), -side, 0.3)
			await t.seconds(0.6)
			_close(g, base + side * 3.2 - xf.basis.z * 0.8 + up * 0.9, base - xf.basis.z * 0.9, up)
			await t.seconds(0.6)
			await t.shot(name_)
			_open(g)
			return


func _perf_view(label: String) -> void:
	# Measured while the axolotl walks (movers active, the vegetation wake running).
	t.g.player.use_bot_input = true
	t.g.player.bot_input = Vector2(0.3, 0.5)
	await t.seconds(1.0)
	await RenderingServer.frame_post_draw
	var t0 := Time.get_ticks_usec()
	for i in 60:
		await RenderingServer.frame_post_draw
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / 60.0
	t.log_line("PERF %s  %.1f ms/frame  draw calls %d  triangles %d  video mem %.1f MB  ram %.1f MB (peak %.1f)  nodes %d" % [label, ms,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, Performance.get_monitor(Performance.MEMORY_STATIC_MAX) / 1048576.0,
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	t.g.player.bot_input = Vector2.ZERO


## Arbitrary views for reviewing worlds: --views="name:ball,lat,lon,face_lat,face_lon[,pitch[,dist[,h]]];..."
## (ball numbered from 1); --heal=1 shows them restored; --orbit=1 adds views from high above.
func _spot_shots(g: Game) -> void:
	g.player.invuln_t = 9999
	if Settings.test_args.get("heal", "0") == "1":
		for b in g.balls:
			b.add_heal(Vector3.UP, 340.0, 0.0)
		g.g_disp = 1.0
		g.aquarium.apply(1.0)
	for spec: String in str(Settings.test_args.get("views", "")).split(";", false):
		var nm_rest: PackedStringArray = spec.split(":")
		var v: PackedStringArray = nm_rest[1].split(",")
		var bi := int(v[0]) - 1
		var b := g.balls[bi]
		var at := MossBall.dir_ll(float(v[1]), float(v[2]))
		var to := MossBall.dir_ll(float(v[3]), float(v[4]))
		var h := float(v[7]) if v.size() > 7 else 0.2
		var pos := b.surface_point(at, h)
		var face := b.surface_point(to) - pos
		face -= b.up_at(pos) * face.dot(b.up_at(pos))
		_look(g, bi, pos, face.normalized(), float(v[5]) if v.size() > 5 else 0.32)
		if v.size() > 6:
			g.cam.distance = float(v[6])
		await t.seconds(1.2)
		await t.shot(nm_rest[0])


## Before/after views of every world for the expansion report (identical in old and new builds):
## the whole ball from the side and from above, and two views on the ground (its arrival point and
## the far side), murky and then healed.
func _report_shots(g: Game) -> void:
	for pass_ in ["murky", "healed"]:
		if pass_ == "healed":
			for b in g.balls:
				b.add_heal(Vector3.UP, 340.0, 0.0)
			g.g_disp = 1.0
			g.aquarium.apply(1.0)
		g.player.invuln_t = 9999
		for bi in g.balls.size():
			var b := g.balls[bi]
			var arrive: Vector3 = b.start_dir if bi == 0 else b.arrival_dir
			_look(g, bi, b.surface_point(arrive, 0.2), MossBall.frame_at(arrive, 0.0).z)
			g.cam.cinematic = true
			g.cam.cine_pos = b.global_position + Vector3(0.8, 0.12, 0.6).normalized() * b.radius * 2.7
			g.cam.cine_look = b.global_position + Vector3.UP * b.radius * 0.1
			g.cam.cine_up = Vector3.UP
			await t.seconds(1.5)
			await t.shot("rep_%s_b%d_1side" % [pass_, bi + 1])
			g.cam.cine_pos = b.global_position + Vector3(0.5, 0.75, 0.45).normalized() * b.radius * 1.6
			g.cam.cine_look = b.surface_point(Vector3(0.3, 0.9, 0.3).normalized())
			await t.seconds(1.0)
			await t.shot("rep_%s_b%d_2top" % [pass_, bi + 1])
			g.cam.cinematic = false
			for k in 2:
				var at := arrive if k == 0 else -arrive.rotated(MossBall.frame_at(arrive, 0.0).x, 0.5)
				var fr := MossBall.frame_at(at, 45.0)
				_look(g, bi, b.surface_point(at, 0.2), fr.z)
				g.cam.distance = 7.0
				g.cam.pitch = 0.42
				await t.seconds(1.2)
				await t.shot("rep_%s_b%d_%dground" % [pass_, bi + 1, k + 3])


## Camera audit (world expansion): the ordinary follow camera where the bigger worlds test it:
## part way up and at the top of each long climb, at a ravine's rim looking across, and in the
## middle of each cave, looking at the door.
func _camera_audit(g: Game) -> void:
	g.player.invuln_t = 9999
	for bi in g.balls.size():
		var b := g.balls[bi]
		var lb: LevelBuilder = b.get_meta("builder")
		for h in lb.bot_hints:
			if h.has("route") and not h.get("branch", false) and (h["tops"] as Array).size() >= 8 and not str(h["route"]).begins_with("jungle"):
				var tops: Array = h["tops"]
				for k in [tops.size() / 2, tops.size() - 1]:
					var at: Vector3 = tops[k]
					var nxt: Vector3 = tops[mini(k + 1, tops.size() - 1)] if k < tops.size() - 1 else tops[k - 1]
					var face := nxt - at
					face -= b.up_at(at) * face.dot(b.up_at(at))
					if face.length() < 0.1:
						face = MossBall.frame_at(b.up_at(at), 0.0).z
					_look(g, bi, at + b.up_at(at) * 0.2, face.normalized())
					await t.seconds(1.2)
					await t.shot("cam_b%d_%s_%s" % [bi + 1, str(h["route"]).replace(" ", "_"), "top" if k == tops.size() - 1 else "mid"])
			if h.has("cave"):
				var c: Vector3 = h["centre"]
				_look(g, bi, b.surface_point(b.up_at(c), 0.2), (h["door"] as Vector3) - c)
				await t.seconds(1.2)
				await t.shot("cam_b%d_cave_%s" % [bi + 1, str(b.upgrades.find(h["reward"]))])
		for rv in lb.ravines:
			var pts: Array = rv["points"]
			var mid: Vector3 = (pts[pts.size() / 2] as Vector3)
			var side := mid.cross(pts[pts.size() - 1] - pts[0]).normalized()
			var rim := mid.rotated(side.cross(mid).normalized(), (float(rv["half"]) + 1.2) / b.radius)
			_look(g, bi, b.surface_point(rim, 0.2), b.surface_point(mid) - b.surface_point(rim))
			await t.seconds(1.2)
			await t.shot("cam_b%d_%s" % [bi + 1, str(rv["id"]).replace(".", "_")])


# --- Skill tree, red starfish, Glide (docs/SKILL_TREE.md) ------------------------------------------

func _set_progress(g: Game, stars: int, ids: Array) -> void:
	var gp := g.gill
	gp.collected.clear()
	gp.purchased.clear()
	for sid in StarfishTable.ids().slice(0, stars):
		gp.collected[sid] = {"t": 0}
	for id in ids:
		gp.purchased[id] = {"cost": SkillTree.cost(id), "t": 0, "n": gp.purchased.size() + 1}
	gp.save()
	g.player.apply_skills(gp.tiers())


func _page_shot(g: Game, name_: String, select := "") -> void:
	var page: SkillTreePage = g.pause_menu.skill_page
	page.refresh()
	if select != "":
		page.select(select, false)
		(page.buttons[select] as Button).grab_focus()
	await t.seconds(0.4)
	await t.shot(name_)


## The skill tree page: empty, partial and full; the locked, unaffordable and available cards; the
## unlock's frames; the pause menu's line; at 1280x720 and at a narrow 19.5:9 phone shape.
func _skilltree_shots(g: Game) -> void:
	var b0 := g.balls[0]
	_look(g, 0, b0.surface_point(MossBall.dir_ll(12, 30), 0.1), Vector3.FORWARD)
	await t.seconds(1.5)
	var sizes := [["", Vector2i(0, 0)], ["_phone", Vector2i(1560, 720)]]
	for sz in sizes:
		if sz[0] != "":
			DisplayServer.window_set_size(sz[1])
			await t.seconds(0.5)
		_set_progress(g, 0, [])
		g.pause_menu.open()
		await t.seconds(0.3)
		g.pause_menu._open_skills()
		await _page_shot(g, "skilltree_empty" + sz[0], "lunge.1")
		_set_progress(g, 12, ["lunge.1", "quick.1", "burst.1", "glide.1", "burst.2"])
		await _page_shot(g, "skilltree_partial_locked" + sz[0], "lunge.3")
		_set_progress(g, 7, ["lunge.1", "quick.1", "burst.1", "glide.1", "burst.2"])
		await _page_shot(g, "skilltree_partial_unaffordable" + sz[0], "glide.2")
		_set_progress(g, 12, ["lunge.1", "quick.1", "burst.1", "glide.1", "burst.2"])
		await _page_shot(g, "skilltree_partial_available" + sz[0], "glide.2")
		var page: SkillTreePage = g.pause_menu.skill_page
		page.buy("glide.2")
		for k in 3:
			await t.seconds([0.06, 0.15, 0.3][k])
			await t.shot("skilltree_unlock_%d%s" % [k + 1, sz[0]])
		_set_progress(g, 30, SkillTree.ids())
		await _page_shot(g, "skilltree_full" + sz[0], "glide.3")
		page.done.emit()
		await t.seconds(0.4)
		await t.shot("skilltree_pause_menu" + sz[0])
		g.pause_menu.close()
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await t.seconds(0.5)
	g._enter_title()
	await t.seconds(1.0)
	await t.shot("skilltree_title_menu")
	g.title._on_skills()
	await _page_shot(g, "skilltree_from_title", "quick.3")
	g.pause_menu.skill_page.done.emit()
	g.start_play(true)
	_set_progress(g, 0, [])


## A starfish framed directly (a still camera `dist` m back and a little above it, Gill set off to
## one side so he never hides it).
func _star_frame(g: Game, s: Starfish, dist: float, heading := 30.0) -> void:
	var b := s.ball
	var up := b.up_at(s.rest)
	var fr := MossBall.frame_at(up, heading)
	var side := b.surface_point(b.up_at(s.rest + fr.x * 2.5), 0.1)
	var hit := Starfish.probe(b, b.up_at(s.rest + fr.x * 1.6), b.altitude(s.rest))
	if not hit.is_empty() and absf(b.altitude(hit[0]) - b.altitude(s.rest)) < 0.6:
		side = hit[0] + b.up_at(hit[0]) * 0.1
	g.player.place(b, side, s.rest - side)
	g.audio.set_ball(b.index, false)
	_close(g, s.rest + up * (0.5 + dist * 0.35) + fr.z * dist, s.rest + up * 0.1, up)
	await t.seconds(1.2)


## A starfish from the gameplay camera: `dist` m back from it, facing it.
func _star_view(g: Game, s: Starfish, dist: float, heading := 0.0) -> void:
	var b := s.ball
	var up := b.up_at(s.rest)
	var fr := MossBall.frame_at(up, heading)
	var at := b.surface_point(b.up_at(s.rest + fr.z * dist), 0.1)
	# (For a perch or a leaf: from the same height, standing on it where possible.)
	var hit := Starfish.probe(b, b.up_at(s.rest + fr.z * dist), b.altitude(s.rest))
	if not hit.is_empty() and absf(b.altitude(hit[0]) - b.altitude(s.rest)) < 0.8:
		at = hit[0] + b.up_at(hit[0]) * 0.1
	_look(g, b.index, at, s.rest - at, 0.28)
	await t.seconds(1.2)


## Several starfish (ground, rock, leaf, cave, the gravel's edge) close and at a distance, murky and
## restored; then a pickup's frames and the HUD chip.
func _starfish_shots(g: Game) -> void:
	await t.seconds(1.0)
	var picks := [["star.b1.00", "moss"], ["star.b1.01", "rock"], ["star.b3.01", "leaf"], ["star.b1.05", "cave"], ["star.b2.03", "tower"], ["star.b6.02", "sky_leaf"], ["star.b5.01", "clearing"]]
	for state in ["murky", "restored"]:
		if state == "restored":
			for b in g.balls:
				b.add_heal(Vector3.UP, 340.0, 0.0)
			g.g_disp = 1.0
			g.aquarium.apply(1.0)
			await t.seconds(1.0)
		for pk in picks:
			var s: Starfish = g.starfish.find(pk[0])
			if s == null:
				continue
			await _star_frame(g, s, 1.8, 30.0)
			await t.shot("starfish_%s_close_%s" % [pk[1], state])
			if pk[1] != "cave":
				await _star_frame(g, s, 10.0, 30.0)
				await t.shot("starfish_%s_far_%s" % [pk[1], state])
			else:
				await _star_frame(g, s, 3.5, 200.0)
				await t.shot("starfish_%s_far_%s" % [pk[1], state])
			_open(g)
	# A pickup: walk into it, frames just after.
	var s: Starfish = g.starfish.find("star.b1.00")
	var p := g.player
	p.use_bot_input = true
	await _star_view(g, s, 2.2, 10.0)
	for i in 120:
		var off := s.pick_point() - p.global_position
		var cf: Vector3 = -g.cam.global_basis.z
		cf = (cf - p.up * cf.dot(p.up)).normalized()
		var d := (off - p.up * off.dot(p.up)).normalized()
		p.bot_input = Vector2(d.dot(cf.cross(p.up)), d.dot(cf))
		await t.frames(1)
		if g.gill.has_star(s.id):
			break
	p.bot_input = Vector2.ZERO
	Engine.time_scale = 0.2
	for k in 3:
		await t.frames([1, 4, 10][k])
		await t.shot("starfish_pickup_%d" % (k + 1))
	Engine.time_scale = 1.0
	p.use_bot_input = false


## Glide: the posture from behind (the gameplay camera), from the side and in a turn, a plain fall
## for comparison, and a representative transfer (the Undercut bridges) before (no Glide: short) and
## after (Glide II: across).
## Pushed by a current (ledger row 19): the brace from the gameplay camera, close and from the side
## (gesture off for comparison), a step sequence, and the drag marks fading over time from above.
func _brace_shots(g: Game) -> void:
	var p := g.player
	p.use_bot_input = true
	p.invuln_t = 9999
	var b := g.balls[1]
	g.ecosystem.set_physics_process(false)
	for pp in b.parasites:
		pp.set_physics_process(false)
	var lat := float(Settings.test_args.get("lat", "6"))
	var lon := float(Settings.test_args.get("lon", "150"))
	var spot := func(heading: float) -> void:
		var d := MossBall.dir_ll(lat, lon)
		p.place(b, b.surface_point(d, 0.1), -MossBall.frame_at(d, heading).z)
		p.bot_input = Vector2.ZERO
		g.cam.snap_behind()
		g.audio.set_ball(1, false)
	var views := func(tag: String) -> void:
		await t.shot("brace_%s_mid" % tag)
		var c := p.global_position + p.up * 0.15
		var flow := p.current_push.normalized() if p.current_push.length() > 0.01 else p.facing.cross(p.up)
		var right := p.facing.cross(p.up)
		_close(g, c + right * 1.1 - p.facing * 0.9 + p.up * 0.75, c, p.up)
		await t.frames(2)
		await t.shot("brace_%s_close" % tag)
		# Side on to the current: looking across the flow, upstream to the left of the frame.
		var across := flow.cross(p.up).normalized()
		_close(g, c + across * 1.6 + p.up * 0.22, c, p.up)
		await t.frames(2)
		await t.shot("brace_%s_side" % tag)
		_open(g)
	for heading in [90.0, 0.0]:
		var h := "h%d" % int(heading)
		Axolotl.brace_enabled = false
		spot.call(heading)
		await t.seconds(1.5)
		t.log_line("%s off: push %.2f" % [h, p.current_push.length()])
		await views.call(h + "_off")
		Axolotl.brace_enabled = true
		spot.call(heading)
		await t.seconds(1.8)
		var lp: Vector3 = p.model.global_transform.basis.orthonormalized().inverse() * p.current_push
		t.log_line("%s on: push %.2f brace %.2f marks live %d; push in his frame %s (x right, -z ahead), upstream %s, rig rot %s, tail tip az %.2f"
				% [h, p.current_push.length(), p.current_brace, WaterFX.inst.marks_live, str(lp), str(p.model._brace_up), str(p.model.rig.rotation), p.model.whip_tip_az])
		await views.call(h + "_on")
	# The steps: close, every 0.15 s.
	spot.call(90.0)
	await t.seconds(1.5)
	for i in 8:
		var c := p.global_position + p.up * 0.15
		var right := p.facing.cross(p.up)
		_close(g, c + right * 1.0 - p.facing * 0.6 + p.up * 0.9, c, p.up)
		await t.frames(1)
		await t.shot("brace_step_%d" % i)
		await t.frames(4)
	_open(g)
	# The marks fading: braced for 3 s, then the gesture off (no new marks) and the camera held over
	# the trail, a frame every half second.
	spot.call(90.0)
	await t.seconds(3.0)
	Axolotl.brace_enabled = false
	var c0 := p.global_position
	var u := p.up
	var back := -p.current_push.normalized() if p.current_push.length() > 0.01 else p.facing
	var mid := c0 + back * 0.6
	var side := back.cross(u).normalized()
	for i in 9:
		_close(g, mid + u * 1.3 + side * 0.5 - back * 0.3, mid, back)
		await t.frames(1)
		t.log_line("fade %d: marks live %d" % [i, WaterFX.inst.marks_live])
		await t.shot("brace_marks_%.1fs" % (i * 0.5))
		await t.seconds(0.5)
	_open(g)
	Axolotl.brace_enabled = true


func _glide_shots(g: Game) -> void:
	var p := g.player
	p.use_bot_input = true
	p.invuln_t = 9999
	var b0 := g.balls[0]
	var at := MossBall.dir_ll(12, 30)
	var hold := func(dir: Vector3) -> void:
		var cf: Vector3 = -g.cam.global_basis.z
		cf = (cf - p.up * cf.dot(p.up)).normalized()
		var d := (dir - p.up * dir.dot(p.up)).normalized()
		p.bot_input = Vector2(d.dot(cf.cross(p.up)), d.dot(cf))
	for gt in [0, 3]:
		p.apply_skills({"glide": gt})
		var up := b0.up_at(b0.surface_point(at))
		var fwd := -MossBall.frame_at(up, 0.0).z
		p.place(b0, b0.surface_point(at, 9.0), fwd)
		g.cam.snap_behind()
		Input.action_press("jump")
		for f in 50:
			hold.call(fwd)
			await t.frames(1)
		await t.shot("glide_behind" if gt == 3 else "fall_behind_no_glide")
		if gt == 3:
			var c := p.global_position + p.up * 0.2
			var right := p.facing.cross(p.up)
			_close(g, c + right * 3.0 + p.up * 0.5 - p.facing * 0.4, c, p.up)
			await t.frames(1)
			Engine.time_scale = 0.05
			await t.frames(2)
			await t.shot("glide_side")
			Engine.time_scale = 1.0
			_open(g)
			# A turn, from the gameplay camera.
			var dir := p.facing
			for f in 30:
				dir = dir.rotated(p.up, -0.06)
				hold.call(dir)
				await t.frames(1)
			await t.shot("glide_turn")
		Input.action_release("jump")
		p.bot_input = Vector2.ZERO
		for i in 300:
			await t.frames(1)
			if p.grounded:
				break
		await t.seconds(0.5)
	# The Undercut bridges (ball 7): from the crown of one toward the other.
	var b := g.balls[6]
	var from: Vector3 = Starfish.probe(b, MossBall.dir_ll(-32.9, 93.1), 3.9)[0]
	var to: Vector3 = Starfish.probe(b, MossBall.dir_ll(-29.3, 109.7), 1.2)[0]
	for gt in [0, 2]:
		p.apply_skills({"glide": gt, "burst": 3 if gt > 0 else 0})
		p.place(b, from + b.up_at(from) * 0.2, to - from)
		g.cam.snap_behind()
		g.audio.set_ball(6, false)
		await t.seconds(1.0)
		if gt == 0:
			await t.shot("transfer_takeoff")
		var start := p.global_position
		for i in 120:
			hold.call(to - p.global_position)
			await t.frames(1)
			var ahead := p.global_position + (to - p.global_position).normalized() * 0.55
			var hit := g.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(ahead + p.up * 0.6, ahead - p.up * 0.9, 1 | 2 | 8))
			if not p.grounded or hit.is_empty() or (p.global_position - (hit["position"] as Vector3)).dot(p.up) > 0.35 or p.global_position.distance_to(start) > 5.0:
				break
		Input.action_press("jump")
		var air := 0
		var shot_mid := false
		for i in 400:
			hold.call(to - p.global_position)
			await t.frames(1)
			air += 1
			if air == 39:
				Input.action_release("jump")
				await t.frames(1)
				Input.action_press("jump")
				if gt == 0:
					await t.frames(1)
					Input.action_release("jump")
			if air == 70 and not shot_mid:
				shot_mid = true
				await t.shot("transfer_mid_%s" % ("glide2" if gt > 0 else "no_glide"))
			if p.grounded and air > 6:
				break
		Input.action_release("jump")
		p.bot_input = Vector2.ZERO
		await t.seconds(0.6)
		await t.shot("transfer_landed_%s" % ("glide2" if gt > 0 else "no_glide"))
	p.apply_skills({})
	p.use_bot_input = false


func _pipelines() -> int:
	var n := 0
	for k in ["PIPELINE_COMPILATIONS_CANVAS", "PIPELINE_COMPILATIONS_MESH", "PIPELINE_COMPILATIONS_SURFACE", "PIPELINE_COMPILATIONS_DRAW", "PIPELINE_COMPILATIONS_SPECIALIZATION"]:
		if ClassDB.class_has_integer_constant("Performance", k):
			n += int(Performance.get_monitor(ClassDB.class_get_integer_constant("Performance", k)))
	return n


## Performance with starfish in view (docs/SKILL_TREE.md): each view with every starfish hidden,
## then shown (the same frames otherwise), and the GPU pipelines the first starfish in view
## compiled (none expected: they reuse the Mote core's material features and its glow shader).
func _perf_starfish(g: Game) -> void:
	var first := true
	for sid in ["star.b1.00", "star.b1.01", "star.b3.01", "star.b2.02", "star.b7.03"]:
		var s: Starfish = g.starfish.find(sid)
		if s == null:
			continue
		for st in g.starfish.stars:
			st.visible = false
		await _star_view(g, s, 4.0, 30.0)
		# (Standing still, the same view: hidden, shown, hidden again, shown again.)
		for rep in 2:
			await _perf_still("%s_hidden_%d" % [sid, rep])
			var pc0 := _pipelines()
			for st in g.starfish.stars:
				st.visible = true
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var pc1 := _pipelines()
			if rep == 0:
				t.log_line("PIPELINES %s first frames with starfish shown: +%d compilations%s" % [sid, pc1 - pc0, " (the first starfish ever drawn)" if first else ""])
			first = false
			await _perf_still("%s_shown_%d" % [sid, rep])
			for st in g.starfish.stars:
				st.visible = false
		for st in g.starfish.stars:
			st.visible = true


func _perf_still(label: String) -> void:
	t.g.player.bot_input = Vector2.ZERO
	await t.seconds(0.5)
	await RenderingServer.frame_post_draw
	var t0 := Time.get_ticks_usec()
	for i in 60:
		await RenderingServer.frame_post_draw
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / 60.0
	t.log_line("PERF %s  %.1f ms/frame  draw calls %d  triangles %d" % [label, ms, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])

## Organic enemy movement (Open Issue #3): each enemy type from a fixed camera, one frame a second
## for STRIP_N seconds (--org=on|off picks the expression layer; frames org_<type>_<n>.png).
func _organic_shots(g: Game) -> void:
	var tag: String = Settings.test_args.get("org", "on")
	var sp := "res://scripts/actors/organic_motion.gd"
	if ResourceLoader.exists(sp):
		(load(sp) as GDScript).set("enabled", tag != "off")
	var n := int(Settings.test_args.get("strip", "16"))
	var p := g.player
	p.invuln_t = 99999.0
	for b in g.balls:
		b.add_heal(Vector3.UP, 340.0, 0.0)
	g.g_disp = 1.0
	g.aquarium.apply(1.0)
	var park := func(b: MossBall, pos: Vector3, dist: float) -> void:
		var u := b.up_at(pos)
		p.place(b, b.surface_point(u.rotated(MossBall.frame_at(u, 0.0).x, dist / b.radius), 0.2), Vector3.FORWARD)
		g.audio.set_ball(b.index, false)
	var subjects: Array = []
	for kind in [Parasite.Kind.SMALL, Parasite.Kind.MEDIUM, Parasite.Kind.LARGE]:
		var done := false
		for b in g.balls:
			for par in b.parasites:
				if not done and par.is_alive() and par.kind == kind and par.variant == "" and par.state == "graze":
					subjects.append(["par%d" % kind, par])
					done = true
	for c in g.ecosystem.all_critters():
		for want in [["stalker", ReedStalker], ["puffer", Pufferfish], ["crab", CrabGuardian], ["eel", CaveEel]]:
			if is_instance_of(c, want[1]) and not subjects.any(func(s): return s[0] == want[0]):
				subjects.append([want[0], c])
	for s in subjects:
		var name_: String = s[0]
		var node: Node3D = s[1]
		var b: MossBall = node.get("ball")
		var home: Vector3 = node.global_position
		if node is Parasite:
			home = b.surface_point((node as Parasite).home_dir)
		elif node is ReedStalker:
			home = b.surface_point((node as ReedStalker).patch_dir)
		elif node is CrabGuardian:
			home = (node as CrabGuardian).post
		elif node is CaveEel:
			home = (node as CaveEel).mouth
		park.call(b, home, 24.0)
		var u := b.up_at(home)
		var fr := MossBall.frame_at(u, 0.0)
		for i in n:
			var at: Vector3 = node.global_position
			if node is CaveEel:
				var e := node as CaveEel
				_close(g, e.mouth + e.normal * 1.6 + u * 0.35, e.mouth, u)
			elif node is CrabGuardian:
				_close(g, at + u * 3.0 + (node as CrabGuardian).facing * 2.2, at, u)
			elif node is Pufferfish:
				_close(g, home + fr.x * 7.0 + u * 0.3, home + u * (node as Pufferfish).hover * 0.5, u)
			else:
				# Top-down over its home, far enough to see where it goes.
				var hgt := 9.0 if name_ != "par1" else 7.0
				_close(g, home + u * hgt + fr.z * 0.5, home, -fr.z)
			await t.seconds(1.0)
			await t.shot("org_%s_%02d" % [name_, i])
	_open(g)


# --- Onboarding (docs/ONBOARDING.md) ------------------------------------------------------------

func _onb_flags(g: Game, done: Array) -> void:
	var d := {}
	for f in done:
		d[f] = true
	g.run_save.set_lessons(d)


## A drifter `ahead` m in front of Gill that the camera really sees.
func _onb_jelly(g: Game, ahead: float) -> Food:
	var p := g.player
	var b := p.ball
	var right := p.facing.cross(p.up).normalized()
	var f := Food.new()
	var d := b.up_at(p.global_position + p.facing * ahead)
	f.setup(b, Food.Type.DRIFTER, b.surface_point(d, 0.7), d, 25.0)
	f.state = "idle"
	b.add_child(f)
	b.foods.append(f)
	for cand in [[ahead, 0.0], [ahead, -1.5], [ahead, 1.5], [ahead - 1.0, 0.0], [ahead - 1.0, -2.0], [ahead - 1.0, 2.0], [ahead - 2.0, -1.0], [ahead - 2.0, 1.0]]:
		f.global_position = b.surface_point(b.up_at(p.global_position + p.facing * float(cand[0]) + right * float(cand[1])), 0.7)
		if g.onboarding.visible_to_player(f.global_position, Onboarding.FOOD_SEE_M):
			break
	return f


## Renders of the intro screen, the objectives, each card, and the parasite lesson's staged
## restoration (start, middle, end) for review.
func _onboarding_shots(g: Game) -> void:
	var o := g.onboarding
	var p := g.player
	p.use_bot_input = true
	p.invuln_t = 99999.0
	# The intro over the title, as a first new run starts.
	_onb_flags(g, [])
	g.run_save.earned().clear()
	g.clock = RunClock.from_dict({"state": "not_started"})
	g._enter_title()
	await t.seconds(1.5)
	g.title._on_play()
	await t.seconds(0.8)
	await t.shot("onb_intro")
	o.ui.tap()
	await t.seconds(0.5)
	# Feeding: the objective, then the close camera on the frond, then the card.
	_onb_flags(g, ["intro", "parasite", "starfish"])
	var b := g.balls[0]
	var d := b.start_dir
	p.place(b, b.surface_point(d, 0.1), -MossBall.frame_at(d, 180.0).z)
	g.cam.snap_behind()
	await t.seconds(1.0)
	g.cam.snap_behind()
	o.run_frond = false
	o.on_play_started(false)
	p.health = p.max_health - 1
	p.model.set_health(p.health, p.max_health, false)
	var f := _onb_jelly(g, 4.0)
	await t.seconds(1.0)
	t.log_line("feeding objective '%s' (%s), target seen %s" % [o.objective, o.ui.objective_text(), o.visible_to_player(f.global_position, Onboarding.FOOD_SEE_M)])
	await t.shot("onb_feed_objective")
	g._eat(p, f)
	await t.seconds(Onboarding.CLOSE_S - 0.05)
	await t.shot("onb_feed_close_before")
	await t.seconds(Onboarding.FROND_S * 0.5)
	await t.shot("onb_feed_close_restoring")
	await t.seconds(Onboarding.FROND_S * 0.5 + 0.7)
	await t.shot("onb_feed_card")
	o.ui.tap()
	await t.seconds(1.5)
	# The first parasite: the objective, then the staged restoration, then the card.
	_onb_flags(g, ["intro", "feeding", "starfish"])
	var par: Parasite = b.parasites[0]
	var pp := par.global_position
	var up := b.up_at(pp)
	var from := b.surface_point(b.up_at(pp + MossBall.frame_at(up, 0.0).z * 5.5), 0.1)
	p.place(b, from, pp - from)
	g.cam.snap_behind()
	await t.seconds(0.6)
	g.cam.snap_behind()
	await t.seconds(0.6)
	await t.shot("onb_parasite_objective")
	par.hit_cd = 0.0
	par.hit(par.hp, par.global_position)
	await t.seconds(Onboarding.RISE_S + 0.15)
	await t.shot("onb_kill_1_start")
	await t.seconds(Onboarding.REVEAL_S * 0.45)
	await t.shot("onb_kill_2_mid")
	await t.seconds(Onboarding.REVEAL_S * 0.55 - 0.15)
	await t.shot("onb_kill_3_end")
	await t.seconds(Onboarding.HOLD_S + 0.6)
	await t.shot("onb_kill_card")
	o.ui.tap()
	await t.seconds(0.5)
	await t.shot("onb_kill_camera_returning")
	await t.seconds(1.5)
	await t.shot("onb_kill_back_to_play")
	# The first Red Starfish: the card.
	_onb_flags(g, ["intro", "feeding", "parasite"])
	var s: Starfish = g.starfish.find("star.b1.00")
	if s == null and not g.starfish.stars.is_empty():
		s = g.starfish.stars[0]
	if s != null:
		g.starfish.collect(s)
		await t.seconds(0.6)
		await t.shot("onb_star_card")
		o.ui.tap()


# --- 00040-plants: tall stem plants and the climbable leaves' golden-pothos look ---------------

## The sprouted stem-plant meshes on ball `b` (Levels._sprouts): distinct meshes whose material
## is a stem plant's (its tip colour is the ball's SPROUT_TIPS), the tall crown's first.
func _stem_meshes(b: MossBall) -> Array:
	var tall := []
	var medium := []
	for n in b.sprout_nodes:
		var mmi := n as MultiMeshInstance3D
		if mmi == null or mmi.multimesh == null:
			continue
		var m: ShaderMaterial = mmi.material_override
		if m == null or m.get_shader_parameter("healthy_b") != Levels.SPROUT_TIPS[b.index]:
			continue
		var into: Array = tall if float(m.get_shader_parameter("plant_height")) > 2.0 else medium
		if not into.has([mmi.multimesh.mesh, m]):
			var seen := false
			for e in into:
				seen = seen or e[0] == mmi.multimesh.mesh
			if not seen:
				into.append([mmi.multimesh.mesh, m])
	return [tall, medium]


## World materials and geometry (E6f): fixed views of every ball's ground and the first of each
## kind of formation on it (mound, ridge, terrace, arch, shelf, stone column, stem), a cave from
## inside and the tank floor, so a material change can be judged before and after. `look_ball=N`
## limits it to one ball.
func _look_shots(g: Game) -> void:
	g.player.invuln_t = 9999
	var only_b := int(Settings.test_args.get("look_ball", "0")) - 1
	var b0 := g.balls[0]
	if only_b < 0:
		var m0 := b0.surface_point(MossBall.dir_ll(66, 0), 0.1)
		_look(g, 0, m0, b0.surface_point(MossBall.dir_ll(50, 0)) - m0, 0.2)
		await t.seconds(1.5)
		await t.shot("lk_murky_b1_meadow")
	_heal_all(g)
	await t.seconds(1.0)
	for bi in g.balls.size():
		if only_b >= 0 and bi != only_b:
			continue
		var b := g.balls[bi]
		var lb: LevelBuilder = b.get_meta("builder")
		_look(g, bi, b.surface_point(MossBall.dir_ll(10, 30 + bi * 40), 0.2), Vector3.FORWARD, 0.25)
		await t.seconds(1.2)
		await t.shot("lk_b%d_ground" % (bi + 1))
		var seen := {}
		for c in lb.root.get_children():
			if not c is Node3D:
				continue
			var kind := ""
			if c.has_meta("terrain_kind"):
				kind = str(c.get_meta("terrain_kind"))
			elif str(c.get_meta("grounded", "")) == "stem":
				kind = "stem"
			elif str(c.get_meta("grounded", "")) == "cushion":
				kind = "mound"
			if kind == "" or kind == "terrace tier" or seen.has(kind):
				continue
			seen[kind] = true
			var o: Vector3 = (c as Node3D).global_position
			var up := b.up_at(o)
			var fr := MossBall.frame_at(up, 0.0)
			var top := float(c.get_meta("top", 2.5))
			var dist := clampf(float(c.get_meta("radius", 1.5)) * 2.0 + 3.0, 4.0, 11.0)
			_close(g, o + up * (top * 0.6 + 1.2) + fr.x * dist, o + up * top * 0.45, up)
			await t.seconds(0.8)
			await t.shot("lk_b%d_%s" % [bi + 1, kind.replace(" ", "_")])
		_open(g)
		for h in lb.bot_hints:
			if h.has("cave"):
				g.player.place(b, b.surface_point(b.up_at(h["door"]), 0.2), (h["door"] as Vector3) - (h["entry"] as Vector3))
				g.cam.snap_behind()
				await t.seconds(1.0)
				await t.shot("lk_b%d_cave" % (bi + 1))
				break
	if only_b < 0:
		await _gravel_shots(g, "lk_tank")


func _heal_all(g: Game) -> void:
	for b in g.balls:
		b.add_heal(Vector3.UP, 340.0, 0.0)
	g.g_disp = 1.0
	g.aquarium.apply(1.0)


## Turntables of every stem-plant variant (still: no sway), the crown in place at three
## distances, the far view, and the climbable leaves close and mid-range, murky and restored.
func _plant_shots(g: Game) -> void:
	var b: MossBall = g.balls[0]
	# The climbable leaves first, murky (neglected tank).
	await _leaf_views(g, "murky")
	_heal_all(g)
	await t.seconds(1.0)
	await _leaf_views(g, "restored")
	g.player.place(b, b.surface_point(MossBall.dir_ll(-40, -30), 0.2), Vector3.FORWARD)
	await t.seconds(0.5)
	var sets: Array = _stem_meshes(b)
	t.log_line("PLANTS ball1 variants: tall %d, medium %d" % [sets[0].size(), sets[1].size()])
	for n in b.sprout_nodes:
		(n as Node3D).visible = false
	# (Each plant alone in open water above the ball, so nothing else is in the frame.)
	var spot := MossBall.dir_ll(89, 0)
	var up := b.up_at(b.surface_point(spot))
	var fr := MossBall.frame_at(up, 0.0)
	var base := b.surface_point(spot, 30.0)
	g.aquarium.env.fog_enabled = false
	for si in 2:
		var scale := 4.5 if si == 0 else 1.6
		for v in sets[si].size():
			var mat: ShaderMaterial = (sets[si][v][1] as ShaderMaterial).duplicate()
			mat.set_shader_parameter("sway", 0.0)
			mat.set_shader_parameter("wake_gain", 0.0)
			mat.set_shader_parameter("cam_fade", 0.0)
			var mi := MeshInstance3D.new()
			mi.mesh = sets[si][v][0]
			mi.material_override = mat
			b.add_child(mi)
			mi.global_transform = Transform3D(MossBall.frame_at(up, 0.0).scaled(Vector3.ONE * scale), base)
			var h := 1.2 * scale
			for k in 3:
				var a := TAU * k / 3.0
				_close(g, base + (fr.x * cos(a) + fr.z * sin(a)) * h * 1.0 + up * h * 0.6, base + up * h * 0.5, up)
				await t.seconds(0.5)
				await t.shot("turn_%s_v%d_%d" % ["tall" if si == 0 else "medium", v, k * 120])
			# The top of the plant, close: the stems must end in leaves.
			_close(g, base + fr.z * h * 0.42 + up * h * 1.2, base + up * h * 0.82, up)
			await t.seconds(0.5)
			await t.shot("turn_%s_v%d_top" % ["tall" if si == 0 else "medium", v])
			mi.queue_free()
	g.aquarium.env.fog_enabled = true
	for n in b.sprout_nodes:
		(n as Node3D).visible = true
	# The crown in place on ball 1's top, at three distances.
	# (Aimed at the tall plant nearest lat 72 lon 140, among the crown's thickest growth.)
	var cd := MossBall.dir_ll(72, 140)
	var best := -2.0
	for n in b.sprout_nodes:
		var mmi := n as MultiMeshInstance3D
		if mmi == null or float((mmi.material_override as ShaderMaterial).get_shader_parameter("plant_height")) < 2.0:
			continue
		for x in mmi.get_meta("veg_transforms"):
			var dd: Vector3 = (x as Transform3D).origin.normalized()
			if dd.dot(MossBall.dir_ll(72, 140)) > best:
				best = dd.dot(MossBall.dir_ll(72, 140))
				cd = dd
	var cu := b.up_at(b.surface_point(cd))
	var cx := MossBall.frame_at(cu, 0.0).x
	for dist in [5.0, 12.0, 28.0]:
		_close(g, b.surface_point(cd, 1.0 + dist * 0.25) + cx * dist, b.surface_point(cd, 1.8), cu)
		await t.seconds(1.5)
		await t.shot("crown_%dm" % int(dist))
	# Far: the whole ball from across the tank, then the room view.
	var far_up := Vector3.UP
	_close(g, b.global_position + Vector3(0.3, 0.55, 1.0).normalized() * b.radius * 3.2, b.global_position + Vector3(0, b.radius * 0.4, 0), far_up)
	await t.seconds(1.5)
	await t.shot("far_ball1")
	_open(g)
	var pr: Presentation = g.presentation
	pr.enter("play")
	await t.seconds(2.0)
	await t.shot("far_room")
	pr.exit()
	await t.seconds(1.0)


## Climbable leaves, close and mid-range: ball 3's ladder leaves and ball 6's canopy.
func _leaf_views(g: Game, tag: String) -> void:
	for bi in [2, 5]:
		var b: MossBall = g.balls[bi]
		var lb: LevelBuilder = b.get_meta("builder")
		# (A ladder's merged leaves, else the fifth single climbing leaf: a spiral's.)
		var pick: Array = []
		var singles := 0
		for n in lb.root.get_children():
			if not n.has_meta("leaves"):
				continue
			var ls: Array = n.get_meta("leaves")
			if ls.size() >= 6:
				pick = ls[4]
				break
			singles += 1
			if singles == 5 and pick.is_empty():
				pick = ls[0]
		if not pick.is_empty():
			if true:
				var xf: Transform3D = pick[0]
				var len: float = pick[1]
				var up := b.up_at(xf.origin)
				var side := xf.basis.x.normalized()
				var base := xf.origin
				var mid := base - xf.basis.z * len * 0.5
				_look(g, b.index, b.surface_point(b.up_at(base + side * 4.0), 0.2), -side, 0.3)
				await t.seconds(0.6)
				_close(g, mid + side * len * 0.55 + up * len * 0.45, mid, up)
				await t.seconds(0.6)
				await t.shot("leaves_b%d_close_%s" % [bi + 1, tag])
				_close(g, mid + side * 9.0 + up * 4.0 - xf.basis.z * 2.0, mid - up * 1.5, up)
				await t.seconds(0.6)
				await t.shot("leaves_b%d_mid_%s" % [bi + 1, tag])
				_open(g)


## Rendering cost of the worst vegetation views, restored (the crowns grown): the crown in
## place, the restored first views, ball 3's giant stems and ball 6's canopy, the room view.
func _plant_perf(g: Game) -> void:
	_heal_all(g)
	await t.seconds(1.0)
	var views := [[0, 62.0, 20.0, 0.0], [0, 75.0, 200.0, 0.0], [0, 10.0, 30.0, 0.0], [2, 60.0, 110.0, 0.0], [2, 10.0, 110.0, 0.0], [1, 70.0, -20.0, 0.0], [5, 30.0, 0.0, 0.0]]
	for v in views:
		var b := g.balls[v[0]]
		var at := MossBall.dir_ll(v[1], v[2])
		g.player.place(b, b.surface_point(at, 0.2), Vector3.FORWARD)
		g.cam.snap_behind()
		await _perf_view("restored_ball%d_%d_%d" % [v[0] + 1, v[1], v[2]])
		await t.shot("perf_ball%d_%d_%d" % [v[0] + 1, v[1], v[2]])
	# The sea fan, facing it from 11 m (the gameplay view) and from 5 m.
	var b0: MossBall = g.balls[0]
	for n in (b0.get_meta("builder") as LevelBuilder).root.get_children():
		if n.get_meta("terrain_kind", "") == "sea fan":
			var fx := (n as Node3D).global_transform
			for dist in [11.0, 5.0]:
				var stand := b0.surface_point(b0.up_at(fx.origin + fx.basis.z.normalized() * dist), 0.2)
				g.player.place(b0, stand, fx.origin - stand)
				g.cam.snap_behind()
				await _perf_view("restored_seafan_%dm" % int(dist))
				await t.shot("perf_seafan_%dm" % int(dist))
	var pr: Presentation = g.presentation
	pr.enter("play")
	await _perf_view("aq_room")
	pr.exit()


## The Coral Garden's sea fan (00040-plants, owner phone report): gameplay distance, close front
## and oblique, about 45 degrees, near-profile and side, and the junctions close up.
func _sea_fan_shots(g: Game, tag: String) -> void:
	var b: MossBall = g.balls[0]
	var lb: LevelBuilder = b.get_meta("builder")
	var fan: Node3D = null
	for n in lb.root.get_children():
		if n.get_meta("terrain_kind", "") == "sea fan":
			fan = n
	if fan == null:
		t.log_line("no sea fan")
		return
	var xf := fan.global_transform
	var x := xf.basis.x.normalized()
	var y := xf.basis.y.normalized()
	var z := xf.basis.z.normalized()
	var c := xf.origin + y * 3.6
	var mi: MeshInstance3D = null
	for k in fan.get_children():
		if k is MeshInstance3D:
			mi = k
	t.log_line("SEAFAN %s tris %d stats %s" % [tag, MossBall._mesh_tris(mi.mesh), str(fan.get_meta("fan_stats", {}))])
	# 1. Gameplay: Gill 11 m in front of it, the ordinary follow camera.
	var stand := b.surface_point(b.up_at(xf.origin + z * 11.0 + x * 1.5), 0.2)
	g.player.place(b, stand, xf.origin - stand)
	g.cam.snap_behind()
	await t.seconds(1.2)
	await t.shot("seafan_%s_1_gameplay" % tag)
	# (Gill moved out of the close views.)
	g.player.place(b, b.surface_point(b.up_at(xf.origin + z * 30.0), 0.2), z)
	var views := [["2_close_front", c + z * 5.0 + x * 0.6 - y * 0.6, c], ["2b_close_oblique", c + (z * 0.8 + x * 0.6).normalized() * 5.0, c + y * 0.4],
			["3_45deg", c + (z + x).normalized() * 9.0, c], ["4_near_profile", c + (x * 0.97 + z * 0.24).normalized() * 9.5, c],
			["4b_side", c + x * 9.5 + y * 0.5, c], ["5_junctions_hub", xf.origin + y * 1.4 + z * 2.2 + x * 0.5, xf.origin + y * 1.5],
			["5b_junctions_outer", xf.origin + y * 4.3 + z * 2.4 - x * 1.4, xf.origin + y * 4.6 - x * 1.6]]
	for v in views:
		_close(g, v[1], v[2], y)
		await t.seconds(0.6)
		await t.shot("seafan_%s_%s" % [tag, v[0]])
	_open(g)


# --- Vortex currents (ledger row 14) ------------------------------------------------------

## A free camera at `pos` looking at `look` (the follow camera in its cinematic mode).
func _vc_cam(g: Game, pos: Vector3, look: Vector3, up: Vector3) -> void:
	_close(g, pos, look, up)
	g.cam.global_position = pos
	g.cam.look_at(look, up)


## Every view twice at the same moment of the current: "on" (the meander) and "off" (the shipped
## straight tunnel), files vc_<name>_on / vc_<name>_off.
func _vc_pair(g: Game, name_: String) -> void:
	for mode in ["on", "off"]:
		Vortex.currents = mode == "on"
		await t.frames(3)
		await t.shot("vc_%s_%s" % [name_, mode])
	Vortex.currents = true


func _vc_time(g: Game, tm: float) -> void:
	for v: Vortex in g.vortices:
		v.current_time = tm
	await t.frames(2)


## Side view (perpendicular to the connection) and a second, high oblique angle of one connection.
func _vc_side(v: Vortex, dist_k := 0.8) -> Array:
	var mid: Vector3 = v.sample(0.5)[0]
	var b := v.cur_basis
	var view_side: Vector3 = b.x
	# (From whichever side of the tunnel is away from the aquarium's middle.)
	if view_side.dot(mid) < 0.0:
		view_side = -view_side
	return [mid + view_side * v._length * dist_k + b.y * v._length * 0.12, mid, b.y]


func _vc_oblique(v: Vortex, dist_k := 0.7) -> Array:
	var mid: Vector3 = v.sample(0.5)[0]
	var b := v.cur_basis
	var d := (b.y * 0.85 + b.z * 0.45 + b.x * 0.3).normalized()
	return [mid + d * v._length * dist_k, mid, b.z]


func _vcur_shots(g: Game) -> void:
	var p := g.player
	p.invuln_t = 9999
	for v: Vortex in g.vortices:
		v.connected = true
		v._target = 1.0
		v.strength = 1.0
	_heal_all(g)
	g.hud.visible = false
	# Park Gill out of the way on ball 1 (the follow camera is replaced by the free one anyway).
	p.place(g.balls[0], g.balls[0].surface_point(Vector3.UP, 0.2), Vector3.FORWARD)
	await t.seconds(2.0)
	var v: Vortex = g.vortices[0]
	# The moment the middle of 1-2 is most displaced in the first ten minutes.
	var best_t := 0.0
	var best := 0.0
	for i in 600:
		var d := v.current_offset_at(0.5, float(i)).length()
		if d > best:
			best = d
			best_t = float(i)
	t.log_line("VCUR most displaced: 1-2 at %.0f s, %.1f m (bound %.1f, length %.0f)" % [best_t, best, v.current_bound(), v._length])
	await _vc_time(g, best_t)
	# 1. Side view and second angle of 1-2 and 1-4.
	for li in [0, 2, 3]:
		var vv: Vortex = g.vortices[li]
		var nm := "%d-%d" % [vv.ball_a.index + 1, vv.ball_b.index + 1]
		var sv := _vc_side(vv)
		_vc_cam(g, sv[0], sv[1], sv[2])
		await t.seconds(0.6)
		await _vc_pair(g, "side_" + nm)
		var ob := _vc_oblique(vv)
		_vc_cam(g, ob[0], ob[1], ob[2])
		await t.seconds(0.6)
		await _vc_pair(g, "oblique_" + nm)
	# 2. Several together: the three connections at Current Hollows (ball 2) from high above it, and
	# the two out of Mossy Meadow (ball 1).
	var b1 := g.balls[1]
	var cen := b1.global_position
	var away := (g.balls[0].global_position - b1.global_position).normalized()
	var top := b1.global_position + Vector3(-25.0, 122.0, 30.0)
	_vc_cam(g, top, cen, away)
	await t.seconds(0.6)
	await _vc_pair(g, "together_ball2")
	_vc_cam(g, g.balls[0].global_position + Vector3(-40, 150, 140), g.balls[0].global_position, Vector3.UP)
	await t.seconds(0.6)
	await _vc_pair(g, "together_ball1")
	var tog := {
		"together_ball2_sw": [b1.global_position + Vector3(-30.0, 80.0, 125.0), b1.global_position + Vector3(-50.0, 0.0, -40.0)],
		"together_ball2_w": [b1.global_position + Vector3(-150.0, 70.0, 60.0), b1.global_position + Vector3(0.0, -5.0, -20.0)],
		"together_ball1_se": [g.balls[0].global_position + Vector3(110.0, 60.0, 120.0), g.balls[0].global_position + Vector3(30.0, 5.0, 20.0)],
	}
	for nm in tog:
		_vc_cam(g, tog[nm][0], tog[nm][1], Vector3.UP)
		await t.seconds(0.6)
		await _vc_pair(g, nm)
	# 3. Long-time non-repetition: the side view of 1-2 at moments up to half an hour apart.
	var sv0 := _vc_side(v)
	_vc_cam(g, sv0[0], sv0[1], sv0[2])
	for tm in [0.0, 20.0, 45.0, 90.0, 180.0, 400.0, 900.0, 1800.0]:
		await _vc_time(g, tm)
		await t.frames(2)
		await t.shot("vc_time_1-2_%04d" % int(tm))
	# 4. Both mouths while the middle is displaced (and the whole span for context).
	await _vc_time(g, best_t)
	for at_b in [false, true]:
		var mb: MossBall = v.ball_b if at_b else v.ball_a
		var m := v.mouth_pos(at_b)
		var mu := mb.up_at(m)
		var u_in := 0.18 if not at_b else 0.82
		var toward: Vector3 = v.sample(u_in)[0]
		var sd := v.cur_basis.x
		_vc_cam(g, m + mu * 7.0 + sd * 16.0, m.lerp(toward, 0.35), mu)
		await t.seconds(0.6)
		await _vc_pair(g, "mouth_%s_1-2" % ("b" if at_b else "a"))
	# 5. Gill travelling inside the moving current: an outside camera beside the middle, then the
	# game's own ride camera. (The current is at its most displaced moment.)
	var cam2 := Camera3D.new()
	g.add_child(cam2)
	cam2.fov = g.cam.fov
	cam2.near = g.cam.near
	cam2.far = g.cam.far
	cam2.environment = g.cam.environment
	cam2.attributes = g.cam.attributes
	for mode in ["on", "off"]:
		Vortex.currents = mode == "on"
		await _vc_time(g, best_t - 2.4)
		p.place(g.balls[0], g.balls[0].surface_point(v.dir_a, 0.2), Vector3.FORWARD)
		await t.frames(2)
		g._start_cinematic("travel", {"v": v, "reverse": false})
		cam2.make_current()
		for k in [2.0, 2.6, 3.2]:
			await t.seconds(k - g.cine_t)
			var e := clampf(g.cine_t / 6.0, 0.0, 1.0)
			e = e * e * (3.0 - 2.0 * e)
			var at: Vector3 = v.visual_point(e)
			cam2.global_position = at + v.cur_basis.x * 17.0 + v.cur_basis.y * 5.0 - v.cur_basis.z * 4.0
			cam2.look_at(at, v.cur_basis.y)
			await t.frames(1)
			await t.shot("vc_ride_out_%s_%.1f" % [mode, k])
		g.cam.make_current()
		await t.seconds(0.9)
		await t.shot("vc_ride_in_%s_4.1" % mode)
		while g.cinematic != "":
			await t.frames(1)
	Vortex.currents = true
	cam2.queue_free()
	# 6. Performance in the worst views: inside the current mid-span (all the jets round the camera),
	# a whole tunnel filling the screen, and three tunnels at once; currents on and off alternately.
	await _vc_time(g, best_t)
	p.place(g.balls[0], g.balls[0].surface_point(Vector3.DOWN, 0.2), Vector3.FORWARD)
	var views := {
		"inside_1-2": [v.visual_point(0.42), v.visual_point(0.62), v.cur_basis.y],
		"side_close_1-2": _vc_side(v, 0.45),
		"together_ball2": [top, cen, away],
	}
	for nm in views:
		var vw: Array = views[nm]
		_vc_cam(g, vw[0], vw[1], vw[2])
		await t.seconds(0.5)
		await t.shot("vc_perfview_%s" % nm)
		for rep in 3:
			for mode in ["off", "on"]:
				Vortex.currents = mode == "on"
				await _perf_still("vcur %s %s %d" % [nm, mode, rep])
	Vortex.currents = true
	_open(g)

