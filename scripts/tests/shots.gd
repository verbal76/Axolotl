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
	if only == "leafclose":
		await _leaf_close(g, g.balls[2], "leaf_close")
		for b in g.balls:
			b.add_heal(Vector3.UP, 340.0, 0.0)
		g.g_disp = 1.0
		g.aquarium.apply(1.0)
		await _leaf_close(g, g.balls[2], "leaf_close_restored")
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
	t.log_line("PERF %s  %.1f ms/frame  draw calls %d  triangles %d  video mem %.1f MB" % [label, ms,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
	t.g.player.bot_input = Vector2.ZERO
