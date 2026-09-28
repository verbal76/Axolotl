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
	large._mat.set_shader_parameter("gray_front", large._gray)
	await t.seconds(0.6)
	await t.shot("12_parasite_one_third_grey")
	large._gray = 2.0 / 3.0
	large._mat.set_shader_parameter("gray_front", large._gray)
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
	t.log_line("PERF %s  %.1f ms/frame  draw calls %d  triangles %d  video mem %.1f MB" % [label, ms,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
	t.g.player.bot_input = Vector2.ZERO
