extends RefCounted
## Beginning-to-end automated playthrough. The bot plays through the SAME input actions the
## touch HUD / gamepad produce (analog move_* strengths, jump, swipe, lunge) — it never
## teleports the axolotl or edits game state. It starts at the title screen, completes the
## tutorial, restores Moss Ball #1 to ~75%, travels on, fully restores #2 and #3 (including
## every cave), backtracks through both vortices to finish #1, waits for ALL CLEAR, then keeps
## free-roaming.

var t
var g: Game
var p: Axolotl
var t0 := 0.0
var sim_time := 0.0
var timeline: Array = []
var stuck_events := 0
## Where each stuck recovery happened: "ball N (lat, lon)" -> count (cohesion audit, 2026-10-02:
## a spot many recoveries share is a candidate terrain snag, not just the bot's routing).
var stuck_at := {}
var failures: Array = []
var _stick := Vector2.ZERO
var _shots := true


func run(runner) -> void:
	t = runner
	g = t.g
	p = g.player
	_shots = DisplayServer.get_name() != "headless"
	if Settings.test_args.get("start", "") == "b2to1":
		g.start_play(true)
		var bb := g.balls[1]
		p.place(bb, bb.surface_point(MossBall.dir_ll(66, 74), 0.3), Vector3.FORWARD)
		g.audio.set_ball(1, false)
		g.balls[0].vortex_out.connected = true
		await wait(1.0)
		for h in bb.get_meta("builder").bot_hints:
			if h.has("cave"):
				var door: Vector3 = h["door"]
				var inward := (door - (h["entry"] as Vector3)).normalized()
				var centre := door + inward * 7.0
				t.log_line("cave dbg: dist to centre %.2f door dist %.2f cave_of %s" % [p.global_position.distance_to(centre), p.global_position.distance_to(door), str(not _cave_of(p.global_position).is_empty())])
		await enter_vortex(g.balls[0].vortex_out, true)
		t.check("debug_reached_ball1", p.ball == g.balls[0], "")
		_report()
		return
	if Settings.test_args.get("start", "") == "trapprobe":
		# Debug: can he be held somewhere near --at=x,y,z on --ball=N? Every grid point within
		# --r m: dropped there, then the stick held each way for 1 s and a jump; points where he
		# moves under 0.5 m whichever way he is pushed are reported.
		g.start_play(true)
		var tb := g.balls[int(Settings.test_args.get("ball", "7")) - 1]
		var at_s := str(Settings.test_args.get("at", "-172,-5,55")).split(",")
		var c0 := Vector3(float(at_s[0]), float(at_s[1]), float(at_s[2]))
		var rr := float(Settings.test_args.get("r", "2.5"))
		var stp := float(Settings.test_args.get("step", "0.4"))
		var cu := tb.up_at(c0)
		var cf := MossBall.frame_at(cu, 0.0)
		g.audio.set_ball(tb.index, false)
		p.invuln_t = 99999.0
		var trapped := 0
		var n := 0
		var x := -rr
		while x <= rr + 0.001:
			var z := -rr
			while z <= rr + 0.001:
				if Vector2(x, z).length() <= rr:
					var q := tb.surface_point(tb.up_at(c0 + cf.x * x + cf.z * z), 0.35)
					p.place(tb, q, cf.z)
					p.velocity = Vector3.ZERO
					await wait(0.4)
					var start := p.global_position
					var fl: Object = p._floor_collider()
					var most := 0.0
					var ndir := int(Settings.test_args.get("dirs", "4"))
					for k in ndir:
						p.place(tb, start, cf.z)
						p.velocity = Vector3.ZERO
						await tick()
						set_stick(stick_for(cf.z.rotated(cu, TAU * k / ndir)))
						await wait(1.0)
						most = maxf(most, p.global_position.distance_to(start))
					set_stick(Vector2.ZERO)
					p.place(tb, start, cf.z)
					p.velocity = Vector3.ZERO
					await tick()
					await press("jump")
					await wait(1.0)
					most = maxf(most, p.global_position.distance_to(start))
					n += 1
					if Settings.test_args.has("verbose"):
						t.log_line("probe point %s alt %.2f floor %s moved at most %.2f" % [str(start), tb.altitude(start), fl, most])
					if most < 0.5:
						trapped += 1
						t.log_line("TRAP at %s (grid %.1f,%.1f) alt %.2f floor %s moved at most %.2f" % [str(start), x, z, tb.altitude(start), fl, most])
				z += stp
			x += stp
		t.log_line("TRAPPROBE %d of %d points held" % [trapped, n])
		_report()
		return
	if Settings.test_args.get("start", "") == "vortexrace":
		# Regression (backtrack_to_ball1, 2026-09-29): the ride through a vortex starts while the
		# walk to its mouth is busy elsewhere (here: forced from 30 m off), so the walk never sees
		# him at the mouth. He must still end up on the far ball and stay there.
		g.start_play(true)
		var rb := g.balls[1]
		var rv: Vortex = g.balls[0].vortex_out
		rv.connected = true
		var rm: Vector3 = rv.mouth_pos(true)
		var ru := rb.up_at(rm)
		var off := MossBall.frame_at(ru, 0).x * 30.0
		p.place(rb, rb.surface_point(rb.up_at(rm + off), 0.3), -off)
		g.audio.set_ball(1, false)
		await wait(1.0)
		_test_busy = 12.0
		var walk := {"done": false, "ok": false}
		var go := func():
			walk["ok"] = await goto(func(): return rv.mouth_pos(true), 0.3, 90.0, rv)
			walk["done"] = true
		go.call()
		await wait(1.0)
		g._start_cinematic("travel", {"v": rv, "reverse": true})
		var waited := 0.0
		while not walk["done"] and waited < 95.0:
			await wait(0.5)
			waited += 0.5
		await wait(15.0)
		t.check("vortexrace_walk_ends_with_the_ride", walk["done"] and walk["ok"] and waited < 25.0, "done %s ok %s after %.1f s" % [walk["done"], walk["ok"], waited])
		t.check("vortexrace_stays_on_far_ball", p.ball == g.balls[0], "on ball %d" % (p.ball.index + 1))
		_report()
		return
	if Settings.test_args.get("start", "") == "b2vortex":
		# Debug scenario: from moss ball #2's cave entrance to the vortex toward #3.
		g.start_play(true)
		var b2 := g.balls[1]
		var lb2: LevelBuilder = b2.get_meta("builder")
		for h in lb2.bot_hints:
			if h.has("cave"):
				p.place(b2, h["entry"] + b2.up_at(h["entry"]) * 0.3, Vector3.FORWARD)
		g.audio.set_ball(1, false)
		b2.vortex_out.connected = true
		await wait(1.0)
		await enter_vortex(b2.vortex_out, false)
		t.check("debug_reached_ball3", p.ball == g.balls[2], "")
		_report()
		return
	if Settings.test_args.get("start", "") == "probe":
		# Debug: what stands at --ball=N --lat --lon (surfaces above the ground, top down).
		g.start_play(true)
		var pb := g.balls[int(Settings.test_args.get("ball", "3")) - 1]
		var dd := MossBall.dir_ll(float(Settings.test_args.get("lat", "0")), float(Settings.test_args.get("lon", "0")))
		var top := pb.surface_point(dd, 20.0)
		t.log_line("probe: terrain %.2f m above the base sphere, ravine cut %.2f m ('%s'), %d hills, %d ravines" % [pb.terrain_height(dd), pb.ravine_carve(dd), pb.ravine_at(dd), pb.hills.size(), pb.carves.size()])
		var space := g.get_world_3d().direct_space_state
		var excl: Array[RID] = []
		for k in 8:
			var q := PhysicsRayQueryParameters3D.create(top, pb.surface_point(dd, -1.0), 0xFFFF)
			q.exclude = excl
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				break
			var col: Object = hit["collider"]
			t.log_line("probe: %.2f m up: %s layer %d meta %s" % [pb.altitude(hit["position"]), str(col), (col as CollisionObject3D).collision_layer, str(col.get_meta("grounded", col.get_meta("terrain_kind", ""))) if col is Node else ""])
			excl.append((col as CollisionObject3D).get_rid())
		_report()
		return
	if Settings.test_args.get("start", "") == "fight":
		# Debug scenario: fight one parasite (--ball=N --zone=Z [--kind=K]) from 8 m off.
		g.start_play(true)
		var fb := g.balls[int(Settings.test_args.get("ball", "3")) - 1]
		var zone := str(Settings.test_args.get("zone", "far"))
		var kind := int(Settings.test_args.get("kind", "2"))
		for par in fb.parasites:
			if par.zone_id == zone and par.kind == kind:
				var u := fb.up_at(par.global_position)
				var off := MossBall.frame_at(u, 0).x * 8.0
				p.place(fb, fb.surface_point(fb.up_at(par.global_position + off), 0.3), -off)
				g.audio.set_ball(fb.index, false)
				await wait(1.0)
				var ok := await fight_parasite(par, 60.0)
				t.log_line("fight %s %s: %s, hp %d, state %s, variant %s" % [zone, kind, ok, par.hp, par.state, par.variant])
				t.check("debug_fight", ok, "")
				break
		_report()
		return
	if Settings.test_args.get("start", "") == "caves":
		# Debug scenario: every hidden cave entered and its reward reached, starting outside.
		g.start_play(true)
		for b in g.balls:
			if Settings.test_args.has("ball") and int(Settings.test_args["ball"]) != b.index + 1:
				continue
			for h in (b.get_meta("builder") as LevelBuilder).bot_hints:
				if h.has("cave"):
					var out: Vector3 = h["entry"] + ((h["entry"] as Vector3) - (h["door"] as Vector3)).normalized() * 6.0
					p.place(b, b.surface_point(b.up_at(out), 0.3), Vector3.FORWARD)
					p.restore_full()
					g.audio.set_ball(b.index, false)
					if Settings.test_args.has("noeel"):
						for c in b.critters:
							if c is CaveEel:
								(c as CaveEel).restore_defeated()
					await wait(1.0)
					await cave(b, h)
					t.check("debug_cave_b%d_%s" % [b.index + 1, str(b.upgrades.find(h["reward"]))], h["reward"].taken, "")
		_report()
		return
	if Settings.test_args.get("start", "") == "eels":
		# Debug scenario: each cave eel fought with the 100% tactic, starting at its cave's entry.
		g.start_play(true)
		for b in g.balls:
			for c in b.critters:
				if c is CaveEel and str(Settings.test_args.get("eel", (c as CaveEel).threat_id)) in (c as CaveEel).threat_id:
					# Outside, beyond the eel's cave (the 100% phase arrives from elsewhere).
					var ch: Dictionary = {}
					for h in (b.get_meta("builder") as LevelBuilder).bot_hints:
						if h.has("cave") and (ch.is_empty() or (h["centre"] as Vector3).distance_to((c as CaveEel).mouth) < (ch["centre"] as Vector3).distance_to((c as CaveEel).mouth)):
							ch = h
					var out: Vector3 = ch["entry"] + ((ch["entry"] as Vector3) - (ch["door"] as Vector3)).normalized() * 9.0
					p.place(b, b.surface_point(b.up_at(out), 0.3), Vector3.FORWARD)
					g.audio.set_ball(b.index, false)
					if Settings.test_args.has("hp"):
						# (The 100% phase can reach an eel low on health, as the release run did.)
						p.max_health = maxi(p.max_health, 5)
						p.health = int(Settings.test_args["hp"])
					await wait(1.0)
					await _fight_eel(c as CaveEel)
					t.check("debug_eel_%s" % (c as CaveEel).threat_id, (c as CaveEel).defeated, "")
		_report()
		return
	if Settings.test_args.get("start", "") == "stats":
		# Debug: the completion ids and per-ball content counts (for reports).
		g.start_play(true)
		t.log_line("IDS " + JSON.stringify(g.completion.order))
		for sb in g.balls:
			var slb: LevelBuilder = sb.get_meta("builder")
			var climbs := 0
			for h in slb.bot_hints:
				if h.has("route"):
					climbs += 1
			var lo := INF
			var hi := -INF
			for k in 2000:
				var dd := Vector3(sin(k * 2.39996) * sqrt(1.0 - pow(1.0 - 2.0 * (k + 0.5) / 2000.0, 2.0)), 1.0 - 2.0 * (k + 0.5) / 2000.0, cos(k * 2.39996) * sqrt(1.0 - pow(1.0 - 2.0 * (k + 0.5) / 2000.0, 2.0))).normalized()
				lo = minf(lo, sb.terrain_height(dd) - sb.ravine_carve(dd))
				hi = maxf(hi, sb.terrain_height(dd))
			var top := 0.0
			for h in slb.bot_hints:
				if h.has("tops"):
					for tp in h["tops"]:
						top = maxf(top, sb.altitude(tp) + sb.terrain_height(sb.up_at(tp)))
			t.log_line("BALL %d radius %.0f parasites %d motes %d blooms %d upgrades %d critters %d gates %d columns %d streams %d ravines %d crossings %d climbs %d events %d terrain %.1f..%.1f m highest climb top %.1f m" % [sb.index + 1, sb.radius,
					sb.parasites.size(), sb.motes.size(), sb.blooms.size(), sb.upgrades.size(), sb.critters.size(), sb.gates.size(), sb.columns.size(), sb.streams.size(),
					slb.ravines.size(), slb.crossings.size(), climbs, sb.events_total, lo, hi, top])
		_report()
		return
	if Settings.test_args.get("start", "") == "cross":
		# Debug scenario: the planned way from --from=lat,lon to --to=lat,lon on --ball=N, every
		# restoration gate open, repeated --n times (ravine falls counted).
		g.start_play(true)
		var xb := g.balls[int(Settings.test_args.get("ball", "1")) - 1]
		for gt in xb.gates:
			(gt as RestorationGate).open(false)
			t.log_line("gate %s %s: open %s at %.2f m up" % [gt.zone_id, gt.kind, gt.is_open, xb.altitude(gt.global_position)])
		var fr := str(Settings.test_args.get("from", "56,33")).split(",")
		var to := str(Settings.test_args.get("to", "67,42")).split(",")
		var d0 := MossBall.dir_ll(float(fr[0]), float(fr[1]))
		var d1 := MossBall.dir_ll(float(to[0]), float(to[1]))
		p.max_health = 6
		await wait(1.0)
		if Settings.test_args.has("section"):
			# Cross-section of what stands across the way at --section=lat,lon (east-west, 3 m each side).
			var sc := str(Settings.test_args["section"]).split(",")
			var sd := MossBall.dir_ll(float(sc[0]), float(sc[1]))
			var fx := MossBall.frame_at(sd, 0.0).x
			var space := g.get_world_3d().direct_space_state
			for i in range(-12, 13):
				var at := xb.surface_point(sd, 0.0) + fx * (i * 0.25)
				var u := xb.up_at(at)
				var q := PhysicsRayQueryParameters3D.create(at + u * 6.0, at - u * 5.0, 1)
				var hit := space.intersect_ray(q)
				t.log_line("section %+.2f m: %s" % [i * 0.25, "nothing" if hit.is_empty() else "%.2f m up, slope %.0f deg, %s (origin %.2f m up)" % [xb.altitude(hit["position"]), rad_to_deg((hit["normal"] as Vector3).angle_to(xb.up_at(hit["position"]))),
						str(hit["collider"]), xb.altitude((hit["collider"] as Node3D).global_position)]])
		for k in int(Settings.test_args.get("n", "3")):
			p.place(xb, xb.surface_point(d0, 0.3), MossBall.frame_at(d0, 0.0).z)
			p.restore_full()
			g.audio.set_ball(xb.index, false)
			await wait(1.0)
			var falls0 := int(g.stats.get("ravine_falls", 0))
			var ok := await goto(xb.surface_point(d1), 1.5, 60.0, null, false)
			t.log_line("cross %d: arrived %s, ravine falls %d" % [k, ok, int(g.stats.get("ravine_falls", 0)) - falls0])
		_report()
		return
	if Settings.test_args.get("start", "") == "clear":
		# Debug scenario: one world cleared completely from its arrival point (--ball=N).
		g.start_play(true)
		var cb := g.balls[int(Settings.test_args.get("ball", "2")) - 1]
		p.place(cb, cb.surface_point(cb.arrival_dir, 0.3), MossBall.frame_at(cb.arrival_dir, 0.0).z)
		g.audio.set_ball(cb.index, false)
		p.max_health = 6
		p.restore_full()
		await wait(1.0)
		var t0 := sim_time
		await clear_ball(cb.index, 1.01, [])
		t.check("debug_clear_ball%d" % (cb.index + 1), cb.completed, "%.2f in %.0f s, deaths %d, ravine falls %d" % [cb.restoration, sim_time - t0, int(g.stats["deaths"]), int(g.stats.get("ravine_falls", 0))])
		# (--then_eels: afterwards, the 100% eel tactic on each of its cave eels still alive.)
		if Settings.test_args.has("then_eels"):
			for c in cb.critters:
				if c is CaveEel and not (c as CaveEel).defeated:
					await _fight_eel(c as CaveEel)
					t.check("debug_eel_%s" % (c as CaveEel).threat_id, (c as CaveEel).defeated, "")
		_report()
		return
	if Settings.test_args.get("start", "") == "meadow":
		# Debug scenario: the tutorial, then Mossy Meadow cleared completely, then its vortex.
		g._enter_title()
		await wait(1.0)
		g.title._on_play()
		await wait(0.5)
		await tutorial()
		await clear_ball(0, 1.01, [])
		t.check("debug_meadow_cleared", g.balls[0].completed, "%.2f in %.0f s, deaths %d, ravine falls %d" % [g.balls[0].restoration, sim_time, int(g.stats["deaths"]), int(g.stats.get("ravine_falls", 0))])
		await enter_vortex(g.balls[0].vortex_out, false)
		t.check("debug_meadow_vortex", p.ball == g.balls[1], "")
		_report()
		return
	g.all_clear.connect(func(): _all_clear_at = sim_time; mark("ALL CLEAR shown"))
	# Start from the title screen like a player would.
	g._enter_title()
	await wait(2.0)
	await t.shot("pt_00_title")
	g.title._on_play()
	mark("play pressed")
	await wait(0.5)
	await t.shot("pt_01_start")

	await tutorial()
	await clear_ball(0, 0.74, ["under"])
	await t.shot("pt_10_ball1_partial")
	t.check("ball1_vortex_opened_by_play", g.balls[0].vortex_out.connected, "restoration %.2f" % g.balls[0].restoration)
	await enter_vortex(g.balls[0].vortex_out, false)
	t.check("reached_ball2", p.ball == g.balls[1], "")
	await t.shot("pt_20_ball2")
	await clear_ball(1, 1.01, [])
	t.log_line("ball 2 after first visit: %.0f%%" % (g.balls[1].restoration * 100.0))
	await enter_vortex(g.balls[1].vortex_out, false)
	t.check("reached_ball3", p.ball == g.balls[2], "")
	await t.shot("pt_30_ball3")
	await clear_ball(2, 1.01, [])
	t.log_line("ball 3 after first visit: %.0f%%" % (g.balls[2].restoration * 100.0))
	# Backtrack: #3 -> #2 -> #1 through the bidirectional vortices.
	await enter_vortex(g.balls[1].vortex_out, true)
	t.check("backtrack_to_ball2", p.ball == g.balls[1], "")
	await enter_vortex(g.balls[0].vortex_out, true)
	t.check("backtrack_to_ball1", p.ball == g.balls[0], "")
	await clear_ball(0, 1.01, [])
	t.log_line("ball 1 after returning: %.0f%%" % (g.balls[0].restoration * 100.0))
	for bi in [1, 2, 0]:
		if not g.balls[bi].completed:
			await travel_to(bi)
			await clear_ball(bi, 1.01, [])
	# Expansion 4: the branches (each opens once the ball it hangs off is 70% restored).
	for bi in [3, 6, 4, 5]:
		if bi < g.balls.size():
			await travel_to(bi)
			t.check("reached_ball%d" % (bi + 1), p.ball == g.balls[bi], "")
			await t.shot("pt_7%d_ball%d" % [bi, bi + 1])
			await clear_ball(bi, 1.01, [])
	for bi in g.balls.size():
		if not g.balls[bi].completed:
			await travel_to(bi)
			await clear_ball(bi, 1.01, [])
	if p.ball.index != 0:
		await travel_to(0)
	mark("all balls restored" if g.balls.all(func(bb): return bb.completed) else "finished (incomplete)")
	for bi in g.balls.size():
		t.check("ball%d_fully_restored" % (bi + 1), g.balls[bi].completed, "%.2f" % g.balls[bi].restoration)
	await t.shot("pt_40_all_restored")
	# Quiet period, then ALL CLEAR, then free roam continues.
	var done_at := sim_time
	for i in 240:
		if _all_clear_at >= 0.0:
			break
		await wait(0.5)
	if g.hud.all_clear_label.modulate.a > 0.05:
		await t.shot("pt_50_all_clear")
	t.check("all_clear_shown", _all_clear_at >= 0.0, "at %.1fs" % _all_clear_at)
	await wander(20.0)
	t.check("free_roam_continues", p.controls_enabled and p.state == "normal" and g.state == "play", "")
	# The camera safety invariant over a whole game (FollowCam._audit: every frame drawn).
	var cam: FollowCam = g.cam
	t.check("camera_never_drawn_unsafe_whole_game", cam.audited_frames > 10000 and cam.unsafe_drawn == 0,
			"%d frames audited, %d unsafe, %d requested places corrected%s" % [cam.audited_frames, cam.unsafe_drawn, cam.corrected_frames, "" if cam.unsafe_worst == "" else ": first " + cam.unsafe_worst])
	await t.shot("pt_60_free_roam")
	# Expansion 6: 100% by legitimate play. The normal finish is below 100%; then the bot goes
	# after everything the catalog still lists (blooms, species, cave eels...) the way a player
	# would, and the finish time stays what it was.
	await hundred()
	_report()


# --- 100% --------------------------------------------------------------------------------

func _missing_ids() -> Array[String]:
	var out: Array[String] = []
	var e: Dictionary = g.run_save.earned()
	for id in g.completion.order:
		if not e.has(id):
			out.append(id)
	return out


func hundred() -> void:
	var before := g.completion_percent()
	var fin: float = g.clock.finish_s
	mark("normal finish: %.1f%% complete, finished in %.2f s" % [before, fin])
	t.check("normal_finish_below_100", before < 100.0 and g.clock.state == "finished", "%.1f%%" % before)
	t.log_line("missing after the normal finish: %s" % str(_missing_ids()))
	for attempt in 3:
		var missing := _missing_ids()
		if missing.is_empty():
			break
		for id in missing:
			if g.run_save.earned().has(id):
				continue
			await _complete(id)
	var after := g.completion_percent()
	var left := _missing_ids()
	mark("completionist done: %.2f%%, %d left %s" % [after, left.size(), str(left)])
	t.check("hundred_percent_by_play", left.is_empty() and after == 100.0, "%.2f%%; left %s" % [after, str(left)])
	t.check("finish_time_kept_through_100", g.clock.finish_s == fin and g.clock.state == "finished", "%.2f -> %.2f" % [fin, g.clock.finish_s])


## Goes and earns one catalog id by play.
func _complete(id: String) -> void:
	var bi := int(id.substr(1, id.find(".") - 1)) - 1 if id.begins_with("b") else -1
	activity = "100%: " + id
	if id.begins_with("species."):
		var sp := id.substr(8)
		for c in g.ecosystem.all_critters():
			if c.species == sp:
				await _see(c)
				if g.run_save.earned().has(id):
					return
		return
	if bi < 0:
		return
	if p.ball.index != bi:
		await travel_to(bi)
	var b := g.balls[bi]
	if id.contains(".bloom."):
		var bl: Bloom = b.blooms[int(id.get_slice(".", 2))]
		for i in 3:
			if g.run_save.earned().has(id):
				break
			await _reach(b, bl.global_position)
			await goto(bl.global_position, 0.4, 8.0)
	elif id.contains(".cave."):
		var u = b.upgrades[int(id.get_slice(".", 2))]
		for h in (b.get_meta("builder") as LevelBuilder).bot_hints:
			if h.has("cave") and h["reward"] == u:
				await cave(b, h)
	elif id.contains(".eel."):
		for c in b.critters:
			if c is CaveEel and (c as CaveEel).threat_id == id:
				await _fight_eel(c as CaveEel)
	elif id.contains(".crab."):
		for c in b.critters:
			if c is CrabGuardian and (c as CrabGuardian).threat_id == id:
				await goto(c.global_position, 3.0, 30.0)
				await fight_crab(c as CrabGuardian, 25.0)
	elif id.contains(".mote."):
		# A Mote the main pass missed (the mesa's, on its living platforms, can be knocked off): up
		# its world's climb (the mesa by its own routine), then take it.
		for m in b.motes:
			if str(m.get_meta("completion_id", "")) != id or not m.is_available():
				continue
			for attempt in 3:
				if g.run_save.earned().has(id):
					break
				if m.zone_id == "mesa":
					for h in (b.get_meta("builder") as LevelBuilder).bot_hints:
						if h.has("mesa"):
							await mesa(b, h)
				else:
					await _reach(b, m.global_position)
					await goto(m.global_position, 0.4, 8.0)
	else:
		t.log_line("100%%: no play handler for %s" % id)


## Gets to `pos` on ball `b`: over the ground, or up the registered climb that ends nearest it.
func _reach(b: MossBall, pos: Vector3) -> void:
	if height_of(pos) < 1.2:
		await goto(pos, 0.6, 40.0)
		return
	var best: Dictionary = {}
	var bd := INF
	for h in (b.get_meta("builder") as LevelBuilder).bot_hints:
		if h.has("route"):
			for tp in h["tops"]:
				var d := (tp as Vector3).distance_to(pos)
				if d < bd:
					bd = d
					best = h
	if not best.is_empty():
		var tops: Array = best["tops"]
		var k := 0
		for i in tops.size():
			if (tops[i] as Vector3).distance_to(pos) < (tops[k] as Vector3).distance_to(pos):
				k = i
		if best.get("lift", false):
			await ride_column(best)
		else:
			await goto(best["start"], 1.0, 40.0)
			await hop_chain(tops.slice(0, k + 1))
	await goto(pos, 0.6, 10.0)


## Stands where a player would see creature `c` (within its seen radius, a clear line of sight).
func _see(c: Critter) -> void:
	var b: MossBall = c.ball
	if p.ball != b:
		await travel_to(b.index)
	var pt: Vector3 = c.discover_point()
	var up := b.up_at(pt)
	var away := MossBall.frame_at(up, 30.0).z
	if c is CaveEel:
		away = (c as CaveEel).normal
	var stand := b.surface_point(b.up_at(pt + away * minf(c.seen_radius * 0.6, 3.0)), 0.1)
	if height_of(pt) > 1.2 and not c is CaveEel:
		await _reach(b, pt)
	else:
		await goto(stand, 0.8, 40.0)
	await wait(1.0)


## A cave eel: stand in front of its crevice just outside its reach and let it strike; fully out,
## its head is within a swipe (the swipe turns to it), so swipe then; repeat until it is beaten.
func _fight_eel(e: CaveEel) -> void:
	var b: MossBall = e.ball
	# Its grotto (the cave hint whose centre is nearest the crevice): go in by the door, never
	# over the roof above it.
	var cave_h: Dictionary = {}
	var cd := INF
	for h in (b.get_meta("builder") as LevelBuilder).bot_hints:
		if h.has("cave") and (h["centre"] as Vector3).distance_to(e.mouth) < cd:
			cd = (h["centre"] as Vector3).distance_to(e.mouth)
			cave_h = h
	for round_ in 12:
		if e.defeated:
			return
		var front := b.surface_point(b.up_at(e.mouth + e.normal * (CaveEel.STRIKE_REACH + 0.45)), 0.1)
		if not cave_h.is_empty() and (_cave_of(p.global_position) != cave_h or height_of(p.global_position) > 1.2):
			var ok_e := await goto(cave_h["entry"], 0.8, 60.0)
			var at_e := p.global_position.distance_to(cave_h["entry"])
			var ok_d := await goto(cave_h["door"], 0.8, 15.0)
			if round_ == 0:
				var dr: Vector3 = cave_h["door"]
				var du := b.up_at(dr)
				var ex := []
				var from := dr + du * 9.0
				for k in 5:
					var qq := PhysicsRayQueryParameters3D.create(from, dr - du * 2.0, 0xFFFFFFFF, ex)
					var hh := p.get_world_3d().direct_space_state.intersect_ray(qq)
					if hh.is_empty():
						break
					var col: Object = hh["collider"]
					t.log_line("    over the door: %s (%s, parent %s) at alt %.2f" % [col, col.get_class(), (col as Node).get_parent().name if col is Node else "", b.altitude(hh["position"])])
					ex.append(hh["rid"])
				t.log_line("    him: %s alt %.2f floor %s" % [str(p.global_position.round()), b.altitude(p.global_position), p._floor_collider()])
				t.log_line("  eel %s grotto: entry %s reached %s (%.1f m off), door %s reached %s (%.1f m off, %s), him alt %.2f, same cave as front %s" % [e.threat_id, str((cave_h["entry"] as Vector3).round()), ok_e, at_e,
						str((cave_h["door"] as Vector3).round()), ok_d, p.global_position.distance_to(cave_h["door"]), goto_info, b.altitude(p.global_position), _cave_of(front) == cave_h])
		# (Inside its grotto already: straight to the spot. The route planner would take him out and
		# over the grotto's roof toward a point that is under it.)
		var direct := not cave_h.is_empty() and _cave_of(p.global_position) == cave_h
		var was_planning := _planning
		_planning = _planning or direct
		await goto(front, 0.4, 25.0, null, false)
		_planning = was_planning
		set_stick(Vector2.ZERO)
		var seen := ""
		var most := 0.0
		for i in 60 * 6:
			await tick()
			most = maxf(most, e.ext)
			if not seen.contains(e.state):
				seen += e.state + " "
			if e.hittable() and e.ext > e.reach * 0.8:
				await press("swipe")
				break
		t.log_line("eel %s round %d: at %.2f m from the mouth (front %.2f), states %s, out %.2f of %.2f, hp %d" % [e.threat_id, round_, p.global_position.distance_to(e.mouth), p.global_position.distance_to(front), seen, most, e.reach, e.hp])
		if round_ == 0 and p.global_position.distance_to(front) > 1.5:
			var q := PhysicsRayQueryParameters3D.create(p.body_center(), front + b.up_at(front) * 0.3, 1)
			var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
			t.log_line("  eel %s: front %s alt %.2f carve %.2f, cave of front %s, of him %s; mouth alt %.2f; blocked %s at %s; goto %s" % [e.threat_id, str(front.round()), b.altitude(front), b.ravine_carve(b.up_at(front)),
					str(_cave_of(front).get("centre", "none")), str(_cave_of(p.global_position).get("centre", "none")), b.altitude(e.mouth), not hit.is_empty(), str(hit.get("position", Vector3.ZERO)), goto_info])
		await wait(1.0)


# --- reporting ---------------------------------------------------------------------------

func mark(what: String) -> void:
	timeline.append([sim_time, what])
	var rs := PackedStringArray()
	for bb in g.balls:
		rs.append("%.2f" % bb.restoration)
	t.log_line("[%6.1fs] %s  (R: %s, hp %d/%d, deaths %d)" % [sim_time, what, " ".join(rs), p.health, p.max_health, g.stats["deaths"]])


## Gill's place as "ball N (lat, lon)", rounded to 2 degrees (spots a few metres apart group).
func _here() -> String:
	var ll: Vector2 = Levels._latlon(p.ball.up_at(p.global_position))
	return "ball %d (%d, %d)" % [p.ball.index + 1, int(round(ll.x / 2.0) * 2), int(round(ll.y / 2.0) * 2)]


func _note_stuck() -> void:
	var k := _here()
	stuck_at[k] = int(stuck_at.get(k, 0)) + 1


func _report() -> void:
	t.log_line("stats: " + str(g.stats))
	t.log_line("stuck recoveries: %d" % stuck_events)
	# The spots most recoveries share (cohesion audit).
	var keys := stuck_at.keys()
	keys.sort_custom(func(a, b): return stuck_at[a] > stuck_at[b])
	for k in keys.slice(0, 15):
		t.log_line("stuck spot: %s x%d" % [k, stuck_at[k]])
	for f in failures:
		t.log_line("fallback: " + f)
	if _perf_n > 0:
		t.log_line("cpu wall time per frame (headless, includes bot): avg %.2f ms over %d frames, worst %.2f ms" % [_perf_proc / _perf_n, _perf_n, _perf_max])
	var q = g.quality
	if q and q.history.size() > 0:
		var s := 0.0
		for v in q.history:
			s += v
		t.log_line("fps samples: %d avg %.1f min %.1f (quality level %d)" % [q.history.size(), s / q.history.size(), q.history.min(), q.level])


# --- low level input (identical to the HUD) ----------------------------------------------

func wait(s: float) -> void:
	var n := int(ceil(s * 60.0))
	for i in n:
		await tick()


var _all_clear_at := -1.0
var activity := ""
var goto_info := ""
var _perf_n := 0
var _perf_proc := 0.0
var _perf_phys := 0.0
var _last_us := 0
var _perf_max := 0.0
var _hb := 0.0
var _last_hp := 99
var _last_eat_try := -99.0
var _high_logged := {}


func _nearest_threat() -> String:
	var best := "none"
	var bd := 4.0
	for par in p.ball.hostiles():
		if par.is_alive() and par.global_position.distance_to(p.global_position) < bd:
			bd = par.global_position.distance_to(p.global_position)
			best = "parasite %s %.1f m" % [par.zone_id, bd]
	for c in p.ball.critters:
		if c.species in ["eel", "crab", "puffer"] and not c.defeated and c.global_position.distance_to(p.global_position) < bd:
			bd = c.global_position.distance_to(p.global_position)
			best = "%s %.1f m" % [c.species, bd]
	return best


func tick() -> void:
	await t.frames(1)
	sim_time += 1.0 / 60.0
	# Onboarding's cards (docs/ONBOARDING.md): read for a moment, then Got it / Begin, as a player.
	if g.onboarding != null and g.onboarding.ui.waiting_for_tap() and g.onboarding.ui.shown_t > 1.0:
		mark("onboarding card dismissed: %s" % g.onboarding.ui._title.text)
		g.onboarding.ui.tap()
	_hb += 1.0 / 60.0
	_trace_n += 1
	if Settings.test_args.has("trace_input") and _trace_n % 60 == 0:
		t.log_line("  input %.0fs: stick %s controls %s game %s state %s vel %.2f grounded %s floor %s pos %s goto %s stack %s" % [sim_time, str(_stick), p.controls_enabled, g.state, p.state, p.velocity.length(), p.grounded, p._floor_collider(), str(p.global_position.snapped(Vector3.ONE * 0.01)), goto_info, str(get_stack().slice(1, 4).map(func(f): return "%s:%d" % [f["function"], f["line"]]))])
	var now := Time.get_ticks_usec()
	if _last_us > 0:
		var ms := (now - _last_us) / 1000.0
		_perf_n += 1
		_perf_proc += ms
		_perf_max = maxf(_perf_max, ms)
	_last_us = now
	# Invariant (Expansion 6): no parasite ends up high above the ground unless it is flying.
	if int(sim_time * 60.0) % 120 == 0:
		for par in p.ball.parasites:
			if par.is_alive() and not par.state in ["flung", "init"] and par.ball.altitude(par.global_position) > par.spawn_h + 2.0:
				var key := "%d" % par.get_instance_id()
				if not _high_logged.has(key):
					_high_logged[key] = true
					t.log_line("PARASITE HIGH: %s %s %s at %.1f m (spawned %.1f m), state %s, standing on %s" % [par.zone_id, par.variant, str(par.get_meta("completion_id", "")),
							par.ball.altitude(par.global_position), par.spawn_h, par.state, str(par.standing_on.get_meta("grounded", par.standing_on.name)) if is_instance_valid(par.standing_on) else "-"])
	if p.health < _last_hp:
		t.log_line("hurt at %.1fs: hp %d (%s; nearest threat %s)" % [sim_time, p.health, activity, _nearest_threat()])
	_last_hp = p.health
	if _hb >= float(Settings.test_args.get("hb", "20")):
		_hb = 0.0
		t.log_line("heartbeat %.0fs ball %d h %.1f act '%s' R %.2f %.2f %.2f hp %d cine '%s' state %s %s" % [sim_time, p.ball.index + 1,
				(p.global_position - p.ball.global_position).length() - p.ball.radius, activity, g.balls[0].restoration,
				g.balls[1].restoration, g.balls[2].restoration, p.health, g.cinematic, p.state, goto_info])

		if Settings.test_args.has("trace_stuck"):
			var near: Parasite = null
			for par in p.ball.parasites:
				if par.is_alive() and (near == null or par.global_position.distance_to(p.global_position) < near.global_position.distance_to(p.global_position)):
					near = par
			if near:
				t.log_line("  STUCK nearest parasite %s kind %d state %s dist %.2f dh %.2f alt %.2f on %s; me grounded %s floor %s" % [near.zone_id, near.kind, near.state,
						near.global_position.distance_to(p.global_position), height_of(near.global_position), p.ball.altitude(near.global_position),
						near.standing_on.name if near.standing_on else "-", p.grounded, str(p.get_last_slide_collision().get_collider().name) if p.get_last_slide_collision() else "-"])


func set_stick(v: Vector2) -> void:
	_stick = v.limit_length(1.0)
	for pair in [["move_right", maxf(0.0, _stick.x)], ["move_left", maxf(0.0, -_stick.x)], ["move_forward", maxf(0.0, _stick.y)], ["move_back", maxf(0.0, -_stick.y)]]:
		if pair[1] > 0.0:
			Input.action_press(pair[0], pair[1])
		else:
			Input.action_release(pair[0])


func press(action: String) -> void:
	Input.action_press(action)
	await tick()
	Input.action_release(action)


## Stick value that moves toward a world-space direction (camera-relative, like a player).
func stick_for(world_dir: Vector3, mag := 1.0) -> Vector2:
	var cf: Vector3 = -g.cam.global_basis.z
	cf = cf - p.up * cf.dot(p.up)
	if cf.length() < 0.05:
		cf = g.cam.global_basis.y - p.up * g.cam.global_basis.y.dot(p.up)
	cf = cf.normalized()
	var cr := cf.cross(p.up)
	var d := world_dir - p.up * world_dir.dot(p.up)
	if d.length() < 0.0001:
		return Vector2.ZERO
	d = d.normalized()
	return Vector2(d.dot(cr), d.dot(cf)) * mag


func tangent_to(pos: Vector3) -> Vector3:
	var d := pos - p.global_position
	return d - p.up * d.dot(p.up)


func height_of(pos: Vector3) -> float:
	return (pos - p.global_position).dot(p.up)


# --- navigation --------------------------------------------------------------------------

func _avoid_mouths(dir: Vector3, allow: Vortex) -> Vector3:
	for v in g.vortices:
		if v == allow or not v.connected:
			continue
		for at_b in [false, true]:
			var m: Vector3 = v.mouth_pos(at_b)
			var d := p.global_position - m
			var dist := d.length()
			if dist < 4.5:
				var push := d - p.up * d.dot(p.up)
				dir += push.normalized() * (4.5 - dist) * 0.8
	return dir


## Walk to a position on the current ball. Handles small obstacles with hops and sidesteps.
func _cave_of(pos: Vector3) -> Dictionary:
	for h in p.ball.get_meta("builder").bot_hints:
		if h.has("cave"):
			var door: Vector3 = h["door"]
			var centre := p.ball.surface_point(p.ball.up_at(h["entry"]).slerp(p.ball.up_at(door), 1.0))
			# Dome centre is 1 unit + radius behind the door along the entry->door line.
			var inward := (door - (h["entry"] as Vector3)).normalized()
			centre = door + inward * 7.0
			if pos.distance_to(centre) < 7.6:
				return h
	return {}


func goto(target: Variant, radius := 0.9, timeout := 45.0, allow_vortex: Vortex = null, fight := true) -> bool:
	# Leave a cave through its door when the destination is outside it.
	var tgt0: Vector3 = target.call() if target is Callable else target
	# World expansion: round the ravines (or over a crossing), and into walled hollows by the door.
	if not _planning:
		if p.ball.ravine_carve(p.ball.up_at(tgt0)) > 0.3 and p.ball.altitude(tgt0) < 1.0:
			t.log_line("goto: target at %s is down in a ravine; not following it" % str(Levels._latlon(p.ball.up_at(tgt0)).round()))
			return false
		await _follow_plan(tgt0, allow_vortex, fight)
	var inside := _cave_of(p.global_position)
	if not inside.is_empty() and _cave_of(tgt0).is_empty() and not _in_cave_escape:
		_in_cave_escape = true
		await goto(inside["door"], 0.8, 15.0, null, false)
		await goto(inside["entry"], 0.8, 10.0, null, false)
		_in_cave_escape = false
	var el := 0.0
	var ball0 := p.ball
	var check_t := 0.0
	var last := p.global_position
	var escalate := 0
	var side := 1.0
	var falls0 := int(g.stats.get("ravine_falls", 0))
	while el < timeout:
		# Walking into a vortex that is allowed ends the walk once its ride starts (or has already
		# happened inside a fight, a meal or a detour below): chasing the far mouth after the ride
		# would walk him out of the arrival pool and straight back in.
		if allow_vortex != null and (g.cinematic == "travel" or p.ball != ball0):
			set_stick(Vector2.ZERO)
			return true
		# (Carried off to another ball by an open whirlpool it wandered into: this walk is over; the
		# caller takes him back. Run on 2026-10-02 sat on ball 1 for 3000 s chasing ball 2's mesa.)
		if allow_vortex == null and p.ball != ball0:
			set_stick(Vector2.ZERO)
			return false
		var tgt: Vector3 = target.call() if target is Callable else target
		var flat := tangent_to(tgt)
		# (Off a crossing and put back on a rim, maybe not at its end: that leg is over.)
		if _crossing and int(g.stats.get("ravine_falls", 0)) > falls0:
			set_stick(Vector2.ZERO)
			return false
		goto_info = "d=%.1f pos=%s" % [flat.length(), str(Levels._latlon(p.ball.up_at(p.global_position)).round())]
		if flat.length() < radius and absf(height_of(tgt)) < 2.5:
			set_stick(Vector2.ZERO)
			return true
		if p.state != "normal":
			set_stick(Vector2.ZERO)
			await tick()
			el += 1.0 / 60.0
			continue
		if fight:
			var threat := _threat()
			if threat:
				await fight_parasite(threat, 6.0)
		# Expansion 5's creatures: read their telegraphs and get out of the way (or fight a crab).
		var ct := _critter_threat()
		if ct:
			await handle_critter(ct)
		if _test_busy > 0.0:
			# (Regression scenarios: stand in for a fight, a meal or a detour that takes a while.)
			var busy := _test_busy
			_test_busy = 0.0
			await wait(busy)
		if p.health <= 1 and p.max_health > 1 and sim_time - _last_eat_try > 12.0:
			# (At most every 12 s, and counted against the timeout: with no food in reach this
			# once stalled a goto for good.)
			_last_eat_try = sim_time
			var t0 := sim_time
			await eat_nearby(8.0)
			el += sim_time - t0
		var dir := flat.normalized()
		if not _in_cave_escape and not _cave_of(p.global_position).is_empty() and _cave_of(tgt).is_empty():
			var cave := _cave_of(p.global_position)
			_in_cave_escape = true
			await goto(cave["door"], 0.8, 15.0, null, false)
			await goto(cave["entry"], 0.8, 10.0, null, false)
			_in_cave_escape = false
			continue
		if not _in_cave_escape:
			dir = _avoid_domes(dir, tgt)
		dir = _wall_follow(dir)
		# A ravine's edge just ahead (not on a crossing): plan a way round from here, or keep
		# along the edge.
		if not _crossing and not p.ball.carves.is_empty() and p.ball.ravine_carve(p.up) < 0.3 \
				and p.ball.ravine_carve(p.ball.up_at(p.global_position + dir * 1.6)) > 0.3:
			if not _planning and await _follow_plan(tgt, allow_vortex, fight):
				continue
			var side_v := dir.cross(p.up).normalized()
			var l := p.ball.ravine_carve(p.ball.up_at(p.global_position + dir * 0.8 + side_v * 1.2))
			var r := p.ball.ravine_carve(p.ball.up_at(p.global_position + dir * 0.8 - side_v * 1.2))
			dir = (side_v if l < r else -side_v)
		dir = _avoid_mouths(dir, allow_vortex)
		var mag := 1.0 if flat.length() > 2.0 else clampf(flat.length() / 2.0, 0.35, 1.0)
		set_stick(stick_for(dir, mag))
		await tick()
		el += 1.0 / 60.0
		check_t += 1.0 / 60.0
		if check_t >= 0.8:
			check_t = 0.0
			var moved := p.global_position.distance_to(last)
			last = p.global_position
			if moved < 1.0 and flat.length() > radius:
				stuck_events += 1
				_note_stuck()
				escalate += 1
				# Escalating detours: hop, then walk around the obstacle on alternating sides.
				match escalate % 5:
					1:
						await hop_toward(tgt, true)
					2:
						await detour(dir, side, 70.0, 1.5)
					3:
						side = -side
						await detour(dir, side, 70.0, 2.5)
					4:
						await detour(dir, side, 100.0, 4.0)
					0:
						side = -side
						await detour(dir, side, 100.0, 5.0)
						await hop_toward(tgt, true)
			else:
				escalate = 0
	set_stick(Vector2.ZERO)
	failures.append("goto timeout on ball %d at %s (%s)" % [p.ball.index, _here(), activity])
	return false


# --- paths round ravines and into walled hollows (world expansion) --------------------------

var _planning := false
var _crossing := false
var _trace_n := 0
## A one-off busy spell inside the next walk's loop (the vortexrace regression).
var _test_busy := 0.0


## Walks the planned legs to `tgt` (if any are needed).
func _follow_plan(tgt: Vector3, allow_vortex: Vortex, fight: bool) -> bool:
	var legs := _plan(p.global_position, tgt)
	if legs.is_empty():
		return false
	t.log_line("plan %s -> %s via %s" % [str(Levels._latlon(p.ball.up_at(p.global_position)).round()), str(Levels._latlon(p.ball.up_at(tgt)).round()),
			str(legs.map(func(w): return Levels._latlon(p.ball.up_at(w[0])).round()))])
	_planning = true
	for i in legs.size():
		var leg: Array = legs[i]
		_crossing = leg[1]
		# (Right at a bridge's end before stepping on: a narrow stem is easy to miss from a metre off.)
		var lining_up: bool = i + 1 < legs.size() and legs[i + 1][1]
		var ok := await goto(leg[0], 0.4 if lining_up else 1.0, 40.0, allow_vortex, fight)
		if _crossing and not ok:
			var key := str(p.ball.index) + str((leg[0] as Vector3).round())
			_failed_crossings[key] = int(_failed_crossings.get(key, 0)) + 1
			t.log_line("crossing to %s failed (%d); planning again from here" % [str(Levels._latlon(p.ball.up_at(leg[0])).round()), _failed_crossings[key]])
			_crossing = false
			_planning = false
			_replans += 1
			if _replans > 6:
				_replans = 0
				return false
			return await _follow_plan(tgt, allow_vortex, fight)
	_replans = 0
	_crossing = false
	_planning = false
	return true


## Crossings the bot fell off (ball + far end -> times): after two it walks round instead.
var _failed_crossings := {}
var _replans := 0


## Whether walking straight from `a` to `c` on the current ball keeps off every ravine.
func _clear_path(a: Vector3, c: Vector3) -> bool:
	var b := p.ball
	if b.carves.is_empty():
		return true
	var da := b.up_at(a)
	var dc := b.up_at(c)
	var n := int(ceil(da.angle_to(dc) * b.radius / 0.7)) + 1
	# (The last 2.5 m don't count: a Mote drifting out over a ravine is caught from its edge.)
	var len_m := da.angle_to(dc) * b.radius
	for i in n + 1:
		if len_m * (1.0 - float(i) / n) < 2.5 and len_m > 2.5:
			break
		if b.ravine_carve(da.slerp(dc, float(i) / n)) > 0.3:
			return false
	return true


## Ground points just past each end of each ravine (straight on and to either side).
func _ravine_ends() -> Array:
	var b := p.ball
	var out := []
	for rv in (b.get_meta("builder") as LevelBuilder).ravines:
		var pts: Array = rv["points"]
		for e in [[0, 1], [pts.size() - 1, pts.size() - 2]]:
			var end_d: Vector3 = pts[e[0]]
			var inner: Vector3 = pts[e[1]]
			var axis := inner.cross(end_d).normalized()
			var beyond := end_d.rotated(axis, (float(rv["half"]) + 3.0) / b.radius)
			var side_axis := beyond.cross(axis).normalized()
			out.append(b.surface_point(beyond))
			for sgn in [-1.0, 1.0]:
				out.append(b.surface_point(beyond.rotated(side_axis, sgn * (float(rv["half"]) + 3.0) / b.radius)))
	return out


## Waypoints from `a` to `c` on the current ball: [] when the straight way is fine (or nothing
## better is known). Walled hollows are entered and left by their door (while it is open); ravines
## are walked round, or crossed on a raised bridge.
func _plan(a: Vector3, c: Vector3) -> Array:
	var b := p.ball
	var lb: LevelBuilder = b.get_meta("builder")
	for h in lb.bot_hints:
		if not h.has("hollow") or not (h["gate"] as RestorationGate).is_open:
			continue
		var inside: Vector3 = h["inside"]
		var door: Vector3 = h["door"]
		var out_dir: Vector3 = door - inside
		out_dir = (out_dir - b.up_at(door) * out_dir.dot(b.up_at(door))).normalized()
		var d_out := b.surface_point(b.up_at(door + out_dir * 3.5))
		var d_in := b.surface_point(b.up_at(door - out_dir * 3.0))
		var a_in := a.distance_to(inside) < 9.0
		var c_in := c.distance_to(inside) < 9.0
		if c_in and not a_in:
			return _plan_ravines(a, d_out) + [[d_out, false], [d_in, false]]
		if a_in and not c_in:
			return [[d_in, false], [d_out, false]] + _plan_ravines(d_out, c)
	return _plan_ravines(a, c)


func _plan_ravines(a: Vector3, c: Vector3) -> Array:
	if _clear_path(a, c):
		return []
	var b := p.ball
	var lb: LevelBuilder = b.get_meta("builder")
	var best := []
	var best_cost := INF
	var ends := _ravine_ends()
	for w in ends:
		if _clear_path(a, w) and _clear_path(w, c):
			var cost: float = a.distance_to(w) + w.distance_to(c)
			if cost < best_cost:
				best_cost = cost
				best = [[w, false]]
	for w1 in ends:
		if not _clear_path(a, w1):
			continue
		for w2 in ends:
			if w2 != w1 and _clear_path(w1, w2) and _clear_path(w2, c):
				var cost2: float = a.distance_to(w1) + w1.distance_to(w2) + w2.distance_to(c)
				if cost2 < best_cost:
					best_cost = cost2
					best = [[w1, false], [w2, false]]
	# A bridge standing across (not stepping stones: those are a climb).
	for cr in lb.crossings:
		if cr.has("stones") or (cr["gate"] != null and not (cr["gate"] as RestorationGate).is_open):
			continue
		for pair in [[cr["a"], cr["b"]], [cr["b"], cr["a"]]]:
			if int(_failed_crossings.get(str(b.index) + str((pair[1] as Vector3).round()), 0)) >= 2:
				continue
			if _clear_path(a, pair[0]) and _clear_path(pair[1], c):
				var cost3: float = a.distance_to(pair[0]) + (pair[0] as Vector3).distance_to(pair[1]) + (pair[1] as Vector3).distance_to(c) + 6.0
				if cost3 < best_cost:
					best_cost = cost3
					best = [[pair[0], false], [pair[1], true]]
	if best.is_empty():
		t.log_line("plan: no way round the ravines from %s to %s (cut %.2f / %.2f m there)" % [str(Levels._latlon(b.up_at(a)).round()), str(Levels._latlon(b.up_at(c)).round()),
				b.ravine_carve(b.up_at(a)), b.ravine_carve(b.up_at(c))])
	return best


## Up a bubble column from its vent to near its top, then across to the ledge beside it.
func ride_column(h: Dictionary) -> bool:
	var top: Vector3 = h["tops"][0]
	var ledge: Vector3 = h["tops"][1]
	await goto(h["start"], 0.45, 40.0)
	for i in 60 * 8:
		var f := tangent_to(top)
		set_stick(stick_for(f, clampf(f.length(), 0.0, 0.4)))
		await tick()
		if height_of(top) < 0.6:
			break
	for i in 60 * 4:
		set_stick(stick_for(tangent_to(ledge)))
		await tick()
		if p.grounded and i > 10:
			break
	set_stick(Vector2.ZERO)
	await tick()
	var ok := absf(height_of(ledge)) < 0.7 and tangent_to(ledge).length() < 1.8
	if not ok:
		t.log_line("column %s: missed the ledge (%.1f m below it, %.1f m across; rose to %.1f m up)" % [h["route"], height_of(ledge), tangent_to(ledge).length(), p.ball.altitude(p.global_position)])
	return ok


func detour(dir: Vector3, side: float, angle_deg: float, time: float) -> void:
	var n := int(time * 60)
	for i in n:
		var d := dir.rotated(p.up, deg_to_rad(angle_deg) * side)
		set_stick(stick_for(d))
		await tick()
		if i % 30 == 29 and p.velocity.length() < 1.0:
			await press("jump")


var _in_cave_escape := false


## Steer around cave domes (unless the destination is inside one).
func _avoid_domes(dir: Vector3, tgt: Vector3) -> Vector3:
	if not _cave_of(tgt).is_empty():
		return dir
	for h in p.ball.get_meta("builder").bot_hints:
		if not h.has("cave"):
			continue
		var door: Vector3 = h["door"]
		var centre := door + (door - (h["entry"] as Vector3)).normalized() * 7.0
		var away := p.global_position - centre
		# (The tangent-plane distance alone also matches a dome on the far side of the ball.)
		if away.length() > 14.0:
			continue
		away -= p.up * away.dot(p.up)
		var dist := away.length()
		if dist < 11.5:
			var tang := away.normalized().cross(p.up)
			if tang.dot(dir) < 0.0:
				tang = -tang
			var k := clampf((11.5 - dist) / 3.0, 0.0, 1.0)
			dir = (dir * (1.0 - k) + (tang * 0.8 + away.normalized() * 0.6) * k).normalized()
	return dir
var _follow_side := 0.0
var _follow_clear := 0.0


## Bug-style obstacle handling: if a steep surface blocks the way, slide along it on one
## consistent side until the path is clear again.
func _wall_follow(dir: Vector3) -> Vector3:
	var from := p.body_center()
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 2.4, 1 | 2)
	q.exclude = [p.get_rid()]
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or (hit.normal as Vector3).dot(p.up) > 0.55:
		_follow_clear += 1.0 / 60.0
		if _follow_clear > 1.2:
			_follow_side = 0.0
		return dir
	_follow_clear = 0.0
	var n: Vector3 = hit.normal
	n = (n - p.up * n.dot(p.up)).normalized()
	var along := n.cross(p.up).normalized()
	if _follow_side == 0.0:
		_follow_side = 1.0 if along.dot(dir) >= 0.0 else -1.0
	return (along * _follow_side * 0.85 + n * 0.15).normalized()


func sidestep(dir: Vector3, side: float, time: float) -> void:
	var s := dir.cross(p.up) * side
	var n := int(time * 60)
	for i in n:
		set_stick(stick_for(s + dir * 0.3))
		await tick()


## Jump toward a target, using the water burst to extend if needed.
func hop_toward(target: Variant, allow_burst := true, burst_height := 0.25) -> bool:
	var tgt: Vector3 = target.call() if target is Callable else target
	# Turn toward the target first.
	for i in 4:
		set_stick(stick_for(tangent_to(tgt), 0.3))
		await tick()
	await wait_grounded(1.0)
	await press("jump")
	var bursted := false
	var frames := 0
	while frames < 60 * 3:
		tgt = target.call() if target is Callable else target
		var flat := tangent_to(tgt)
		var h := height_of(tgt)
		var dist := flat.length()
		var mag := 1.0 if dist > 1.2 else clampf(dist / 1.2, 0.0, 1.0)
		set_stick(stick_for(flat, mag))
		var vup := p.velocity.dot(p.up)
		if allow_burst and not bursted and p.burst_available and not p.grounded and frames > 6:
			var need_height := h > burst_height and vup < 2.0
			var need_distance := dist > 3.0 and vup < 0.5
			if need_height or need_distance:
				await press("jump")
				bursted = true
		await tick()
		frames += 1
		if p.grounded and frames > 4:
			break
	set_stick(Vector2.ZERO)
	await tick()
	tgt = target.call() if target is Callable else target
	return tangent_to(tgt).length() < 1.4 and absf(height_of(tgt)) < 0.7


func wait_grounded(timeout := 3.0) -> bool:
	var n := int(timeout * 60)
	for i in n:
		if p.grounded:
			return true
		await tick()
	return p.grounded


## Hop along a chain of platform tops. Each entry is a Vector3 or a Callable returning one.
func hop_chain(tops: Array, retries := 4, start_back: Variant = null, no_settle: Array = []) -> bool:
	var i := 0
	var tries := 0
	var total_fails := 0
	while i < tops.size():
		var tgt = tops[i]
		# Don't jump at brittle moss that has crumbled; wait for it to regrow.
		var tp: Vector3 = tgt.call() if tgt is Callable else tgt
		for c in p.ball.crumbles:
			if c.global_position.distance_to(tp) < 1.5:
				for k in 60 * 6:
					if c._state == "solid":
						break
					await tick()
		# A parasite on him at the foot of a climb: deal with it first, as a player would.
		var threat := _threat()
		if threat:
			await fight_parasite(threat, 6.0)
		var ok := await hop_toward(tgt, true)
		if Settings.test_args.has("hoplog"):
			t.log_line("hop %d -> %s: ok %s, now %.2f m up, %.2f m from the target" % [i, str(tp.round()), str(ok), height_of(p.global_position), p.global_position.distance_to(tp)])
		if ok:
			# Centre on the platform before the next hop (never linger on brittle moss).
			if not i in no_settle:
				await settle_on(tgt)
			i += 1
			tries = 0
		else:
			tries += 1
			total_fails += 1
			if tries > retries or total_fails > retries * 3:
				failures.append("hop chain failed at step %d on ball %d at %s (%s)" % [i, p.ball.index, _here(), activity])
				return false
			await wait_grounded(2.0)
			# If we fell off, climb back from the start.
			var cur = tops[maxi(0, i - 1)]
			var cur_pos: Vector3 = cur.call() if cur is Callable else cur
			if i > 0 and height_of(cur_pos) > 0.8:
				if start_back != null:
					await goto(start_back, 0.8, 30.0)
				i = 0
	return true


func settle_on(target: Variant) -> void:
	for k in 40:
		var tgt: Vector3 = target.call() if target is Callable else target
		var flat := tangent_to(tgt)
		if flat.length() < 0.35:
			break
		set_stick(stick_for(flat, clampf(flat.length(), 0.25, 0.6)))
		await tick()
	set_stick(Vector2.ZERO)
	await wait(0.1)


# --- combat / feeding --------------------------------------------------------------------

## (Self-defence covers returners too; completion routing never does: it walks `ball.parasites`
## only, so repopulation never sends the bot after a parasite that is not in the catalog.)
func _threat() -> Parasite:
	for par in p.ball.hostiles():
		if par.is_alive() and par.state in ["chase", "windup", "attack"] and par.global_position.distance_to(p.global_position) < 2.6 \
				and absf(height_of(par.global_position)) < 1.2:
			return par
	return null


## A creature showing its telegraph (or charging) near the axolotl, or null.
func _critter_threat() -> Critter:
	for c in p.ball.critters:
		if not c.active or c.defeated:
			continue
		var d: float = c.global_position.distance_to(p.global_position)
		if c is CrabGuardian and c.state in ["warn", "charge"] and d < 6.0:
			return c
		if c is CaveEel and c.state == "alert" and (c as CaveEel).mouth.distance_to(p.body_center()) < CaveEel.STRIKE_REACH + 1.0:
			return c
		if c is ReedStalker and (c.state == "telegraph" or (c.state in ["stalk", "recover"] and d < 4.5)):
			return c
		if c is Pufferfish and c.puffed and d < c.radius() + 1.6:
			return c
	return null


## What a player learns to do: sidestep a stalker's locked pounce line, back out of an eel's reach
## while it bubbles, steer clear of a puffed pufferfish, and beat a crab that is guarding the way
## (hit it while it warns or after its charge, sidestep the charge).
func handle_critter(c: Critter) -> void:
	var up := p.up
	if c is ReedStalker and c.state != "telegraph":
		# It is shadowing him (or lying low after a pounce): turn on it and drive it off.
		var el := 0.0
		while not c.defeated and c.state != "telegraph" and el < 4.0:
			var to := c.global_position - p.global_position
			to -= up * to.dot(up)
			if to.length() > 1.8:
				set_stick(stick_for(to.normalized()))
				await tick()
				el += 1.0 / 60.0
				continue
			for k in 5:
				set_stick(stick_for(-to.normalized(), 0.35))
				await tick()
			set_stick(Vector2.ZERO)
			await press("swipe")
			await wait(0.35)
			el += 0.45
		set_stick(Vector2.ZERO)
	elif c is ReedStalker:
		var lock: Vector3 = (c as ReedStalker)._lock
		var side := lock.cross(up).normalized()
		if side.dot(p.global_position - c.global_position) < 0.0:
			side = -side
		for k in 30:
			set_stick(stick_for(side))
			await tick()
		set_stick(Vector2.ZERO)
		# After the pounce it lies low: strike back if it is close.
		for k in 40:
			await tick()
			if c.state == "recover" and c.global_position.distance_to(p.global_position) < 2.6:
				await press("swipe")
				break
	elif c is CaveEel:
		var e := c as CaveEel
		var away := p.body_center() - e.mouth
		away -= up * away.dot(up)
		for k in 40:
			set_stick(stick_for(away.normalized()))
			await tick()
			if e.state not in ["alert", "strike", "hold"]:
				break
		set_stick(Vector2.ZERO)
	elif c is Pufferfish:
		var away := p.global_position - c.global_position
		away -= up * away.dot(up)
		for k in 30:
			set_stick(stick_for(away.normalized()))
			await tick()
		set_stick(Vector2.ZERO)
	elif c is CrabGuardian:
		await fight_crab(c as CrabGuardian, 12.0)


func fight_crab(crab: CrabGuardian, timeout := 15.0) -> void:
	var el := 0.0
	while not crab.defeated and el < timeout and p.state == "normal":
		var to := crab.global_position - p.global_position
		to -= p.up * to.dot(p.up)
		if crab.state == "charge":
			var side := crab._vel.cross(p.up).normalized()
			if side.dot(-to) < 0.0:
				side = -side
			for k in 12:
				set_stick(stick_for(side))
				await tick()
			el += 0.2
			continue
		if to.length() > 1.9:
			set_stick(stick_for(to.normalized()))
			await tick()
			el += 1.0 / 60.0
			continue
		# Close: turn away so the tail sweeps across it, then swipe.
		for k in 5:
			set_stick(stick_for(-to.normalized(), 0.35))
			await tick()
		set_stick(Vector2.ZERO)
		await press("swipe")
		await wait(0.35)
		el += 0.45
	set_stick(Vector2.ZERO)


## Swipe a parasite: bring it behind/beside, then tail-swipe. Dodges big telegraphs.
func fight_parasite(par: Parasite, timeout := 25.0) -> bool:
	var el := 0.0
	while par.is_alive() and el < timeout:
		if p.state != "normal":
			await tick()
			el += 1.0 / 60.0
			continue
		var cp := par.closest_body_point(p.body_center())
		var flat := tangent_to(cp)
		var dist := flat.length()
		if par.kind == Parasite.Kind.LARGE and par.state == "windup" and dist < 4.0:
			# Readable telegraph: step sideways out of the lunge line (or burst away).
			var away := flat.normalized().cross(p.up)
			for k in 22:
				set_stick(stick_for(away))
				await tick()
			el += 22.0 / 60.0
			continue
		if Settings.test_args.has("trace_fight") and int(el * 10) % 10 == 0:
			t.log_line("approach t=%.1f dist %.2f dh %.2f par %s" % [sim_time, dist, height_of(cp), par.state])
		# (Across a ravine from him: go round, never straight over the edge.)
		if dist > 1.5 and not _planning and not _clear_path(p.global_position, cp):
			if p.ball.ravine_carve(p.ball.up_at(cp)) > 0.3:
				t.log_line("fight: %s parasite is down in a ravine; leaving it" % par.zone_id)
				break
			# (Only along a planned way round; with none, leave it for later.)
			var t0 := sim_time
			var went := await _follow_plan(cp, null, false)
			el += sim_time - t0
			if not went:
				t.log_line("fight: no way round to the %s parasite; leaving it for now" % par.zone_id)
				break
			continue
		if dist > 1.5 or absf(height_of(cp)) > 1.0:
			if absf(height_of(cp)) > 1.0 and dist < 2.5:
				await hop_toward(cp, true)
			else:
				var tgt := cp
				for k in 12:
					set_stick(stick_for(tangent_to(tgt)))
					await tick()
			el += 0.2
			continue
		if Settings.test_args.has("trace_fight"):
			t.log_line("fight t=%.1f dist %.2f dh %.2f par %s hp %d pgrounded %s controls %s" % [sim_time, dist, height_of(cp), par.state, par.hp, p.grounded, p.controls_enabled])
		# Turn away so the parasite is behind, then swipe.
		for k in 5:
			set_stick(stick_for(-flat, 0.35))
			await tick()
		set_stick(Vector2.ZERO)
		await press("swipe")
		await wait(0.35)
		el += 0.45
	set_stick(Vector2.ZERO)
	if par.is_alive():
		t.log_line("fight timed out: %s %s kind %d %s at %s (%.1f m up), state %s hp %d; he is at %s (%.1f m up), %.1f m apart" % [par.zone_id, par.variant, par.kind,
				str(par.get_meta("completion_id", "")), str(Levels._latlon(par.ball.up_at(par.global_position)).snapped(Vector2.ONE * 0.1)), par.ball.altitude(par.global_position), par.state, par.hp,
				str(Levels._latlon(p.ball.up_at(p.global_position)).snapped(Vector2.ONE * 0.1)), p.ball.altitude(p.global_position), par.global_position.distance_to(p.global_position)])
	return not par.is_alive()


func _clear_line(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	q.exclude = [p.get_rid()]
	return p.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func eat_nearby(timeout := 10.0) -> bool:
	var el := 0.0
	while el < timeout:
		var best: Food = null
		var bd := 25.0
		for f in p.ball.foods:
			if is_instance_valid(f) and f.is_catchable():
				var d: float = f.catch_point().distance_to(p.global_position)
				# Only food he can walk straight to (lunge_at goes in a straight line): not food on
				# the far side of a cave wall or a mound.
				if d < bd and _clear_line(p.body_center(), f.catch_point()):
					bd = d
					best = f
		if best == null:
			await wait(0.5)
			el += 0.5
			continue
		var ok := await lunge_at(func(): return best.catch_point() if is_instance_valid(best) else p.global_position, 6.0)
		if ok:
			return true
		el += 1.0
	return false


## Approach something small and catch it with the lunge (jumping first if it's higher).
func lunge_at(target: Callable, timeout := 20.0, stay := false) -> bool:
	var el := 0.0
	if Settings.test_args.has("trace_input"):
		t.log_line("  lunge_at %s from %s (%.1f m), timeout %.0f" % [str((target.call() as Vector3).snapped(Vector3.ONE * 0.1)), str(p.global_position.snapped(Vector3.ONE * 0.1)), (target.call() as Vector3).distance_to(p.global_position), timeout])
	var h0 := p.health
	var start_motes: int = g.stats["motes"]
	var start_eat: int = g.stats["eaten"][0] + g.stats["eaten"][1] + g.stats["eaten"][2]
	var prog_t := 0.0
	var prog_d := INF
	while el < timeout:
		var tgt: Vector3 = target.call()
		var flat := tangent_to(tgt)
		var dist := flat.length()
		if dist > 2.2:
			if stay:
				set_stick(stick_for(flat, 0.15))
			else:
				set_stick(stick_for(flat))
			await tick()
			el += 1.0 / 60.0
			# Walking straight at it and getting no nearer (a wall, a mound, a cave's side): give
			# up rather than push into it for the rest of the timeout (World 7 eel grotto, 2026-09-29).
			prog_t += 1.0 / 60.0
			if prog_t >= 1.5:
				if not stay and prog_d - dist < 0.3:
					stuck_events += 1
					_note_stuck()
					set_stick(Vector2.ZERO)
					return false
				prog_t = 0.0
				prog_d = dist
			continue
		# Line up.
		for k in 4:
			set_stick(stick_for(tangent_to(target.call()), 0.3))
			await tick()
		set_stick(Vector2.ZERO)
		var h := height_of(target.call())
		if h > 0.65:
			await press("jump")
			for k in 30:
				await tick()
				if height_of(target.call()) < 0.35 or p.velocity.dot(p.up) < 0.5:
					break
		await press("lunge")
		await wait(0.4)
		el += 0.6
		var eaten: int = g.stats["eaten"][0] + g.stats["eaten"][1] + g.stats["eaten"][2]
		if g.stats["motes"] > start_motes or eaten > start_eat:
			return true
		await wait_grounded(1.5)
		# Back off a little if we overshot (gently when perched: don't walk off the edge).
		if tangent_to(target.call()).length() < 0.6:
			for k in 20:
				set_stick(stick_for(-tangent_to(target.call()), 0.3) if stay else stick_for(-tangent_to(target.call())))
				await tick()
	return false


func capture_mote(m: Mote) -> bool:
	if not m.is_available():
		return true
	await goto(func(): return m.global_position, 2.0, 40.0)
	var ok := await lunge_at(func(): return m.global_position, 25.0)
	if not ok:
		t.log_line("mote %s missed: %.1f m away, %.1f m above him, h_hint %.1f" % [m.zone_id, m.global_position.distance_to(p.global_position), height_of(m.global_position) - height_of(p.global_position), m.h_hint])
	if ok:
		await wait(1.0)
	return not m.is_available()


# --- routines ----------------------------------------------------------------------------

func tutorial() -> void:
	var b := g.balls[0]
	mark("tutorial start")
	# 1-3: walk, jump onto M1, jump + water burst across to M2 — with a run-up, like a player.
	var toward := b.surface_point(Levels.tut_dir(12.57))
	for attempt in 5:
		await goto(b.surface_point(Levels.tut_dir(1.68)), 0.7, 20.0, null, false)
		for i in 120:
			set_stick(stick_for(tangent_to(toward)))
			await tick()
			if b.surface_point(b.up_at(p.global_position)).distance_to(b.surface_point(Levels.tut_dir(Levels.TUT_M1_M))) < 3.56:
				break
		await press("jump")
		for i in 50:
			set_stick(stick_for(tangent_to(toward)))
			await tick()
		await wait_grounded(2.0)
		if height_of(b.surface_point(b.up_at(p.global_position))) > -1.0:
			continue   # didn't make it onto M1
		for i in 90:
			set_stick(stick_for(tangent_to(toward)))
			await tick()
			if Levels.tut_m(b.up_at(p.global_position)) >= 6.03:
				break
		await press("jump")
		for i in 18:
			set_stick(stick_for(tangent_to(toward)))
			await tick()
		await press("jump")
		for i in 60:
			set_stick(stick_for(tangent_to(b.surface_point(Levels.tut_dir(Levels.TUT_M2_M)))))
			await tick()
			if p.grounded and i > 10:
				break
		set_stick(Vector2.ZERO)
		await wait_grounded(2.0)
		if height_of(b.surface_point(b.up_at(p.global_position))) < -2.0:
			break
	mark("reached parasite platform")
	# 4-5: tail swipe the small parasite -> colour returns.
	var par: Parasite = b.parasites[0]
	await fight_parasite(par)
	mark("first parasite restored")
	await t.shot("pt_02_first_restore")
	# The gentle framing shot plays by itself; wait for it.
	for i in 60 * 8:
		await tick()
		if g.cinematic == "" and i > 60 * 2:
			break
	# 6-7: touch the bloom.
	var bloom: Bloom = b.blooms[0]
	for attempt in 3:
		await goto(bloom.global_position, 0.5, 12.0)
		await wait(0.5)
		if g.checkpoint == bloom:
			break
		# Fell off the platform: climb back up.
		await hop_toward(b.surface_point(Levels.tut_dir(Levels.TUT_M2_M), Levels.TUT_M2_TOP), true, 0.1)
	t.check("tutorial_bloom_checkpoint", g.checkpoint == bloom, "")
	mark("tutorial complete")
	t.check("tutorial_under_60s", sim_time < 60.0, "%.1fs" % sim_time)


func clear_ball(bi: int, target: float, skip_zones: Array) -> void:
	var b := g.balls[bi]
	var lb: LevelBuilder = b.get_meta("builder")
	if p.ball != b:
		failures.append("clear_ball %d skipped: not on that ball" % (bi + 1))
		return
	mark("clearing ball %d" % (bi + 1))
	var routines_done := {}
	var passes := 0
	while b.restoration < target - 0.0001 and passes < 4:
		passes += 1
		var tasks := _collect_tasks(b, lb, skip_zones, routines_done)
		if tasks.is_empty():
			break
		while not tasks.is_empty():
			if b.restoration >= target - 0.0001:
				break
			# Nearest-first.
			tasks.sort_custom(func(a, c): return a["pos"].call().distance_to(p.global_position) < c["pos"].call().distance_to(p.global_position))
			if p.ball != b:
				mark("swept off ball %d by a whirlpool; going back" % (bi + 1))
				await travel_to(bi)
				if p.ball != b:
					break
			var task: Dictionary = tasks.pop_front()
			await _do_task(b, task, routines_done)
	# Caves (optional content, but the bot verifies every upgrade and pearl).
	for h in lb.bot_hints:
		if h.has("cave") and not (h["reward"] as Node).get("taken"):
			await cave(b, h)
	mark("ball %d at %.0f%%" % [bi + 1, b.restoration * 100.0])
	for par in b.parasites:
		if par.is_alive():
			t.log_line("  remaining parasite zone %s kind %d state %s" % [par.zone_id, par.kind, par.state])
	for m in b.motes:
		if m.is_available():
			t.log_line("  remaining mote zone %s h %.1f" % [m.zone_id, m.h_hint])


func _collect_tasks(b: MossBall, lb: LevelBuilder, skip_zones: Array, done: Dictionary) -> Array:
	var tasks := []
	var special := {}
	for k in ["tower", "mesa", "canopy"]:
		if done.has(k) and done[k] < 3 and _routine_pending(b, k):
			done["retry_" + k] = true
	for h in lb.bot_hints:
		if h.has("tower") and (not done.has("tower") or done.has("retry_tower")):
			tasks.append({"kind": "tower", "hint": h, "pos": func(): return b.surface_point(MossBall.dir_ll(h["lat"], h["lon"]))})
		# (With a bubble column up to the mesa that is not flowing yet, come back once it is: that
		# is the easy way up; the swaying platforms are the skilled one.)
		var col_waiting := false
		for hh in lb.bot_hints:
			if str(hh.get("route", "")) == "mesa column" and b.lift_at((hh["start"] as Vector3) + b.up_at(hh["start"]) * 0.5) <= 0.0:
				col_waiting = true
		# (--skip_mesa=1, debug: leave the mesa to the 100% pass, to prove its Mote handler.)
		if h.has("mesa") and not col_waiting and (not done.has("mesa") or done.has("retry_mesa")) and Settings.test_args.get("skip_mesa", "0") != "1":
			tasks.append({"kind": "mesa", "hint": h, "pos": func(): return b.surface_point(MossBall.dir_ll(h["site"][0], h["site"][1]))})
		if h.has("canopy") and (not done.has("canopy") or done.has("retry_canopy")):
			tasks.append({"kind": "canopy", "hint": h, "pos": func(): return (h["spiral"][0] as Transform3D).origin})
		# Expansion 4 climbs: needed while an elevated mote in their zones is still there.
		if h.has("route") and not h.get("audit", false) and int(done.get("route:" + str(h["route"]), 0)) < 3 and _route_pending(b, h):
			tasks.append({"kind": "route", "hint": h, "pos": func(): return h["start"]})
	# (Walled hollows wait until their door opens.)
	var shut := []
	for h in lb.bot_hints:
		if h.has("hollow") and not (h["gate"] as RestorationGate).is_open:
			shut.append(h["zone"])
	skip_zones = skip_zones + shut
	for par in b.parasites:
		if par.is_alive() and not par.zone_id in skip_zones and par.state != "init":
			if not (done.has("canopy") == false and par.zone_id == "canopy") and not (par.zone_id == "mesa" and not done.has("mesa")):
				tasks.append({"kind": "kill", "ref": par, "pos": func(): return par.global_position})
	for m in b.motes:
		# Elevated Motes (towers, mesa, canopy) are handled by their climbing routines.
		if m.is_available() and not m.zone_id in skip_zones and m.h_hint <= 2.5:
			tasks.append({"kind": "mote", "ref": m, "pos": func(): return m.global_position})
	return tasks


func _routine_pending(b: MossBall, k: String) -> bool:
	var zones := []
	match k:
		"tower": zones = [b.crumbles[0].zone_id] if b.crumbles.size() > 0 else []
		"mesa": zones = ["mesa"]
		"canopy": zones = ["canopy", "drop"]
	for m in b.motes:
		if m.is_available() and m.zone_id in zones and m.h_hint > 2.5:
			return true
	if k != "tower":
		for par in b.parasites:
			if par.is_alive() and par.zone_id in zones:
				return true
	return false


func _do_task(b: MossBall, task: Dictionary, done: Dictionary) -> void:
	activity = "%s %s" % [task["kind"], (task["ref"].zone_id if task.has("ref") else "")]
	match task["kind"]:
		"kill":
			var par: Parasite = task["ref"]
			if not par.is_alive():
				return
			await goto(func(): return par.global_position, 2.0, 40.0)
			await fight_parasite(par, 25.0)
		"mote":
			await capture_mote(task["ref"])
		"route":
			var h: Dictionary = task["hint"]
			done["route:" + str(h["route"])] = int(done.get("route:" + str(h["route"]), 0)) + 1
			await climb_route(b, h)
		"tower", "mesa", "canopy":
			var k: String = task["kind"]
			done[k] = int(done.get(k, 0)) + 1
			done.erase("retry_" + k)
			match k:
				"tower": await tower(b, task["hint"])
				"mesa": await mesa(b, task["hint"])
				"canopy": await canopy(b, task["hint"])


func _route_pending(b: MossBall, h: Dictionary) -> bool:
	var tops: Array = h["tops"]
	var end: Vector3 = tops[tops.size() - 1]
	for m in b.motes:
		if m.is_available() and m.zone_id in h["zones"] and m.h_hint > 2.5 and m.global_position.distance_to(end) < 6.0:
			return true
	return false


## A generic climb (Expansion 4): walk to its start, hop along its tops, catch the elevated
## motes near the top.
func climb_route(b: MossBall, h: Dictionary) -> void:
	mark("climb: %s" % h["route"])
	var tops: Array = h["tops"]
	var end: Vector3 = tops[tops.size() - 1]
	for attempt in 3:
		var ok := false
		if h.get("lift", false):
			ok = await ride_column(h)
		else:
			await goto(h["start"], 0.8, 45.0)
			ok = await hop_chain(tops, 3, h["start"])
		for m in b.motes:
			if m.is_available() and m.zone_id in h["zones"] and m.h_hint > 2.5 and m.global_position.distance_to(end) < 6.0:
				await lunge_at(func(): return m.global_position, 12.0, true)
		# (Off a climb that ends over a ravine: on to the far rim.)
		if ok and h.has("exit"):
			await hop_chain(h["exit"], 3)
		if ok and not _route_pending(b, h):
			mark("climbed %s" % h["route"])
			return
	t.log_line("climb %s: still pending after 3 attempts" % h["route"])


func tower(b: MossBall, h: Dictionary) -> void:
	var lb: LevelBuilder = b.get_meta("builder")
	var lat: float = h["lat"]
	var lon: float = h["lon"]
	var hd: float = h["heading"]
	var top := func(z: float, y: float) -> Vector3: return lb.at(lat, lon, hd, 0, y, z).origin
	var start: Vector3 = top.call(2.4, 0.0)
	mark("tower on ball %d" % (b.index + 1))
	await goto(start, 0.6, 40.0)
	var chain := [top.call(0.0, 1.4), top.call(-2.6, 2.8), top.call(-5.1, 3.1), top.call(-7.1, 3.6), top.call(-10.0, 4.2)]
	for attempt in 3:
		var ok := await hop_chain(chain, 4, start, [2, 3])
		if ok:
			for m in b.motes:
				if m.h_hint > 3.5 and m.is_available() and m.global_position.distance_to(p.global_position) < 5.0:
					await lunge_at(func(): return m.global_position, 15.0, true)
		var done := true
		for m in b.motes:
			if m.h_hint > 3.5 and m.zone_id == (b.crumbles[0].zone_id if b.crumbles.size() > 0 else "") and m.is_available():
				done = false
		if done:
			break
		await wait(4.0)   # let the brittle moss regrow
		await goto(start, 0.6, 40.0)


func mesa(b: MossBall, h: Dictionary) -> void:
	var lb: LevelBuilder = b.get_meta("builder")
	var S: Array = h["site"]
	mark("mesa (living platforms)")
	var leaves: Array = []
	for child in lb.root.get_children():
		if child is Platforms.SwayLeaf:
			leaves.append(child)
	leaves.sort_custom(func(a, c): return a._stem_len < c._stem_len)
	var start: Vector3 = lb.at(S[0], S[1], S[2], 0, 0, 13.5).origin
	var chain := []
	for lf in leaves:
		chain.append(func(): return lf.global_transform * Vector3(0, lf._stem_len + 0.15, 0))
	chain.append(lb.at(S[0], S[1], S[2], 0, 6.3, 1.2).origin)
	for attempt in 4:
		if await _up_mesa(b, lb, start, chain):
			break
	var on_top := func() -> bool: return height_of(b.surface_point(b.up_at(p.global_position))) < -5.0
	mark("on mesa top: %s" % str(on_top.call()))
	for par in b.parasites:
		if par.zone_id == "mesa" and par.is_alive():
			await fight_parasite(par, 20.0)
	for attempt in 4:
		for m in b.motes:
			if m.zone_id == "mesa" and m.is_available():
				if not on_top.call():
					# Knocked or backed off the mesa: ride the living platforms back up first.
					t.log_line("mesa: off the top before mote attempt %d; climbing back" % attempt)
					await _up_mesa(b, lb, start, chain)
				var ok := await lunge_at(func(): return m.global_position, 15.0, true)
				t.log_line("mesa mote attempt %d: %s (on top %s, mote h %.2f above him)" % [attempt, "caught" if ok else "missed", on_top.call(), height_of(m.global_position)])


## Up onto the mesa: by its bubble column once that flows (the arrival meadow healed), otherwise
## over the swaying living platforms.
func _up_mesa(b: MossBall, lb: LevelBuilder, start: Vector3, chain: Array) -> bool:
	for hh in lb.bot_hints:
		if str(hh.get("route", "")) == "mesa column" and b.lift_at((hh["start"] as Vector3) + b.up_at(hh["start"]) * 0.5) > 0.0:
			if await ride_column(hh):
				var tops: Array = hh["tops"]
				await goto(tops[tops.size() - 1], 0.8, 8.0)
				return true
	await goto(start, 0.8, 40.0)
	return await hop_chain(chain, 2, start)


func canopy(b: MossBall, h: Dictionary) -> void:
	mark("canopy climb")
	var spiral: Array = h["spiral"]
	var chain := []
	for xf in spiral:
		chain.append(Levels.leaf_mid(xf, 2.0, 0.0).origin + (xf as Transform3D).basis.y * 0.1)
	var base: Vector3 = b.surface_point(b.up_at((spiral[0] as Transform3D).origin))
	var start := base + (Levels.leaf_mid(spiral[0], 4.4, 0.0).origin - (spiral[0] as Transform3D).origin)
	start = b.surface_point(b.up_at(start))
	for attempt in 4:
		await goto(start, 0.8, 40.0)
		if await hop_chain(chain.slice(0, 7), 3, start):
			# Mote beside the 7th spiral leaf.
			for m in b.motes:
				if m.zone_id == "canopy" and m.is_available() and m.global_position.distance_to(p.global_position) < 3.5:
					await lunge_at(func(): return m.global_position, 8.0)
			await settle_on(chain[6])
			if await hop_chain(chain.slice(7), 3, start):
				break
	mark("top of spiral")
	var c1: Transform3D = h["c1"]
	var c1b: Transform3D = h["c1b"]
	var c2: Transform3D = h["c2"]
	var c3: Transform3D = h["c3"]
	# The spiral ends beside C3 (Expansion 6): its mote near the tip first.
	await hop_chain([Levels.leaf_mid(c3, 1.0, 0.0).origin], 3)
	for m in b.motes:
		if m.zone_id == "canopy" and m.is_available() and m.global_position.distance_to(Levels.leaf_mid(c3, 4.0, 0.0).origin) < 3.0:
			await goto(Levels.leaf_mid(c3, 3.2, 0.0).origin, 0.5, 8.0)
			await lunge_at(func(): return m.global_position, 10.0)
	# Across to C1 and its bloom.
	await hop_chain([Levels.leaf_mid(c3, 0.8, 0.0).origin, Levels.leaf_mid(c1, 0.8, 0.0).origin], 3)
	await goto(Levels.leaf_mid(c1, 2.6, 0.0).origin, 0.5, 6.0)   # canopy bloom
	# Back across to C2 via C1b, fight the medium parasite, grab the mote.
	await hop_chain([Levels.leaf_mid(c1, 3.8, 0.0).origin,
			Levels.leaf_mid(c1b, 2.0, 0.0).origin, Levels.leaf_mid(c2, 1.2, 1.0).origin], 3)
	for par in b.parasites:
		if par.zone_id == "canopy" and par.kind == Parasite.Kind.MEDIUM and par.is_alive():
			await fight_parasite(par, 15.0)
	for attempt in 3:
		for m in b.motes:
			if m.zone_id == "canopy" and m.is_available() and m.global_position.distance_to(c2.origin) < 6.0:
				await lunge_at(func(): return m.global_position, 10.0, true)
	# The big one: walk off C2's tip -> uncontrolled drop -> extreme superhero landing.
	mark("canopy drop")
	await goto(Levels.leaf_mid(c2, 3.8, 0.0).origin, 0.5, 8.0)
	for k in 120:
		set_stick(stick_for(-c2.basis.z))
		await tick()
		if not p.grounded and k > 10:
			break
	set_stick(Vector2.ZERO)
	await wait_grounded(6.0)
	mark("landed after canopy drop (extreme landings so far: %d)" % g.stats["extreme_landings"])
	for par in b.parasites:
		if par.zone_id == "drop" and par.is_alive():
			await fight_parasite(par, 20.0)


func cave(b: MossBall, h: Dictionary) -> void:
	mark("cave on ball %d" % (b.index + 1))
	var ledges: Array = h["ledges"]
	var entry: Vector3 = h["entry"]
	var door: Vector3 = h["door"]
	for attempt in 3:
		await goto(entry, 0.8, 60.0)
		for c in b.critters:
			if c is CrabGuardian and not c.defeated and c.post.distance_to(entry) < 6.0:
				await fight_crab(c, 20.0)
		await goto(door, 0.8, 10.0)
		var tops := []
		for l in ledges:
			tops.append((l as Node3D).global_transform * Vector3(0, float(l.get_meta("top")), 0))
		await goto(b.surface_point(b.up_at(tops[0])) + (door - b.surface_point(b.up_at(door))) * 0.0, 1.6, 10.0)
		if await hop_chain(tops, 3):
			var u = h["reward"]
			await goto(u._leaf.global_position, 0.3, 5.0)
			await wait(0.5)
			if not u.taken:
				t.log_line("cave b%d: on the last ledge, reward %.2f m away (%.2f m above him)" % [b.index + 1, p.global_position.distance_to(u._leaf.global_position), height_of(u._leaf.global_position) - height_of(p.global_position)])
			if u.taken:
				mark("upgrade collected: max health %d" % p.max_health)
				# Leave the cave the way we came in.
				await wait_grounded(3.0)
				await goto(door, 0.8, 20.0)
				await goto(entry, 0.8, 20.0)
				return
	failures.append("cave upgrade not reached on ball %d" % (b.index + 1))


func enter_vortex(v: Vortex, from_b: bool) -> void:
	var mb: MossBall = v.ball_b if from_b else v.ball_a
	var dest: MossBall = v.ball_a if from_b else v.ball_b
	if p.ball != mb:
		failures.append("enter_vortex: wrong ball")
		return
	mark("heading into vortex %d->%d" % [mb.index + 1, dest.index + 1])
	await goto(func(): return v.mouth_pos(from_b), 0.3, 90.0, v)
	for i in 60 * 20:
		await tick()
		if p.ball == dest and g.cinematic == "":
			break
	await wait(0.5)
	mark("arrived on ball %d" % (p.ball.index + 1))


## Travels through the vortex network (a breadth-first path over the links).
func travel_to(bi: int) -> void:
	var guard := 0
	while p.ball.index != bi and guard < 8:
		guard += 1
		var prev := {p.ball.index: -1}
		var queue := [p.ball.index]
		while not queue.is_empty():
			var cur: int = queue.pop_front()
			for link in Levels.LINKS:
				for k in 2:
					var a: int = link[k]
					var c: int = link[1 - k]
					if a == cur and not prev.has(c):
						prev[c] = cur
						queue.append(c)
		if not prev.has(bi):
			failures.append("no route to ball %d" % (bi + 1))
			return
		var step := bi
		while prev[step] != p.ball.index:
			step = prev[step]
		for v in p.ball.vortices:
			if (v.ball_a == p.ball and v.ball_b.index == step) or (v.ball_b == p.ball and v.ball_a.index == step):
				await enter_vortex(v, v.ball_b == p.ball)
				break


## Whether the ground ahead along `dir` (to 3.5 m) is clear of any ravine.
func _wander_clear(dir: Vector3) -> bool:
	var b := p.ball
	for dist in [1.0, 2.0, 3.5]:
		var d := b.up_at(p.global_position + dir * dist)
		if b.ravine_carve(d) > 0.02 or b.ravine_at(d) != "":
			return false
	return true


func wander(time: float) -> void:
	var el := 0.0
	var dir := p.facing
	while el < time:
		# (Never off a ravine's rim: run 77 wandered into one three times in a row after ALL CLEAR.)
		if not _wander_clear(dir):
			for turn in [PI, PI * 0.5, -PI * 0.5, PI * 0.75, -PI * 0.75]:
				if _wander_clear(dir.rotated(p.up, turn)):
					dir = dir.rotated(p.up, turn)
					break
		set_stick(stick_for(dir))
		await wait(0.5)
		el += 0.5
		if randf() < 0.2:
			dir = dir.rotated(p.up, randf_range(-1.0, 1.0))
		if randf() < 0.1:
			await press("jump")
	set_stick(Vector2.ZERO)
	await eat_nearby(10.0)
