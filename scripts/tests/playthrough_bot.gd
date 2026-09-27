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
var failures: Array = []
var _stick := Vector2.ZERO
var _shots := true


func run(runner) -> void:
	t = runner
	g = t.g
	p = g.player
	_shots = DisplayServer.get_name() != "headless"
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
	t.check("ball2_fully_restored", g.balls[1].completed, "%.2f" % g.balls[1].restoration)
	await enter_vortex(g.balls[1].vortex_out, false)
	t.check("reached_ball3", p.ball == g.balls[2], "")
	await t.shot("pt_30_ball3")
	await clear_ball(2, 1.01, [])
	t.check("ball3_fully_restored", g.balls[2].completed, "%.2f" % g.balls[2].restoration)
	# Backtrack: #3 -> #2 -> #1 through the bidirectional vortices.
	await enter_vortex(g.balls[1].vortex_out, true)
	t.check("backtrack_to_ball2", p.ball == g.balls[1], "")
	await enter_vortex(g.balls[0].vortex_out, true)
	t.check("backtrack_to_ball1", p.ball == g.balls[0], "")
	await clear_ball(0, 1.01, [])
	t.check("ball1_fully_restored", g.balls[0].completed, "%.2f" % g.balls[0].restoration)
	mark("300% restored")
	await t.shot("pt_40_all_restored")
	# Quiet period, then ALL CLEAR, then free roam continues.
	var shown := false
	for i in 240:
		await wait(0.5)
		if g.hud.all_clear_label.modulate.a > 0.05:
			shown = true
			mark("ALL CLEAR shown")
			await t.shot("pt_50_all_clear")
			break
	t.check("all_clear_shown", shown, "")
	await wander(20.0)
	t.check("free_roam_continues", p.controls_enabled and p.state == "normal" and g.state == "play", "")
	await t.shot("pt_60_free_roam")
	_report()


# --- reporting ---------------------------------------------------------------------------

func mark(what: String) -> void:
	timeline.append([sim_time, what])
	t.log_line("[%6.1fs] %s  (R: %.2f %.2f %.2f, hp %d/%d, deaths %d)" % [sim_time, what, g.balls[0].restoration, g.balls[1].restoration,
			g.balls[2].restoration, p.health, p.max_health, g.stats["deaths"]])


func _report() -> void:
	t.log_line("stats: " + str(g.stats))
	t.log_line("stuck recoveries: %d" % stuck_events)
	for f in failures:
		t.log_line("fallback: " + f)
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


func tick() -> void:
	await t.frames(1)
	sim_time += 1.0 / 60.0


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
func goto(target: Variant, radius := 0.9, timeout := 45.0, allow_vortex: Vortex = null, fight := true) -> bool:
	var el := 0.0
	var check_t := 0.0
	var last := p.global_position
	var escalate := 0
	var side := 1.0
	while el < timeout:
		var tgt: Vector3 = target.call() if target is Callable else target
		var flat := tangent_to(tgt)
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
		if p.health <= 1 and p.max_health > 1:
			await eat_nearby(8.0)
		var dir := flat.normalized()
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
				escalate += 1
				match escalate % 4:
					1:
						await hop_toward(tgt, true)
					2:
						await sidestep(dir, side, 0.7)
					3:
						side = -side
						await sidestep(dir, side, 1.1)
					0:
						await sidestep(-dir, 1.0, 0.6)
						await hop_toward(tgt, true)
			else:
				escalate = 0
	set_stick(Vector2.ZERO)
	failures.append("goto timeout on ball %d" % p.ball.index)
	return false


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
func hop_chain(tops: Array, retries := 4, start_back: Variant = null) -> bool:
	var i := 0
	var tries := 0
	while i < tops.size():
		var tgt = tops[i]
		var ok := await hop_toward(tgt, true)
		if ok:
			# Centre on the platform before the next hop.
			await settle_on(tgt)
			i += 1
			tries = 0
		else:
			tries += 1
			if tries > retries:
				failures.append("hop chain failed at step %d on ball %d" % [i, p.ball.index])
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

func _threat() -> Parasite:
	for par in p.ball.parasites:
		if par.is_alive() and par.state in ["chase", "windup", "attack"] and par.global_position.distance_to(p.global_position) < 2.6 \
				and absf(height_of(par.global_position)) < 1.2:
			return par
	return null


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
		# Turn away so the parasite is behind, then swipe.
		for k in 5:
			set_stick(stick_for(-flat, 0.35))
			await tick()
		set_stick(Vector2.ZERO)
		await press("swipe")
		await wait(0.35)
		el += 0.45
	set_stick(Vector2.ZERO)
	return not par.is_alive()


func eat_nearby(timeout := 10.0) -> bool:
	var el := 0.0
	while el < timeout:
		var best: Food = null
		var bd := 25.0
		for f in p.ball.foods:
			if is_instance_valid(f) and f.is_catchable():
				var d: float = f.catch_point().distance_to(p.global_position)
				if d < bd:
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
func lunge_at(target: Callable, timeout := 20.0) -> bool:
	var el := 0.0
	var h0 := p.health
	var start_motes: int = g.stats["motes"]
	var start_eat: int = g.stats["eaten"][0] + g.stats["eaten"][1] + g.stats["eaten"][2]
	while el < timeout:
		var tgt: Vector3 = target.call()
		var flat := tangent_to(tgt)
		var dist := flat.length()
		if dist > 2.2:
			set_stick(stick_for(flat))
			await tick()
			el += 1.0 / 60.0
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
		# Back off a little if we overshot.
		if tangent_to(target.call()).length() < 0.6:
			for k in 20:
				set_stick(stick_for(-tangent_to(target.call())))
				await tick()
	return false


func capture_mote(m: Mote) -> bool:
	if not m.is_available():
		return true
	await goto(func(): return m.global_position, 2.0, 40.0)
	var ok := await lunge_at(func(): return m.global_position, 25.0)
	if ok:
		await wait(1.0)
	return not m.is_available()


# --- routines ----------------------------------------------------------------------------

func tutorial() -> void:
	var b := g.balls[0]
	mark("tutorial start")
	# 1-3: walk, jump onto M1, jump + water burst across to M2.
	await goto(b.surface_point(MossBall.dir_ll(84.0, 0)), 0.7, 20.0, null, false)
	var m1 := b.surface_point(MossBall.dir_ll(79, 0), 1.3)
	var m2 := b.surface_point(MossBall.dir_ll(56.5, 0), 2.3)
	for attempt in 5:
		if await hop_chain([m1], 3):
			if await hop_toward(m2, true, 0.1):
				break
		await goto(b.surface_point(MossBall.dir_ll(84.0, 0)), 0.7, 20.0, null, false)
	mark("reached parasite platform")
	# 4-5: tail swipe the small parasite -> colour returns.
	var par: Parasite = b.parasites[0]
	await fight_parasite(par)
	mark("first parasite restored")
	await t.shot("pt_02_first_restore")
	# 6-7: touch the bloom.
	var bloom: Bloom = b.blooms[0]
	await goto(bloom.global_position, 0.6, 10.0)
	await wait(0.5)
	t.check("tutorial_bloom_checkpoint", g.checkpoint == bloom, "")
	# The gentle framing shot plays by itself; wait for it.
	for i in 60 * 8:
		await tick()
		if g.cinematic == "" and i > 60 * 2:
			break
	mark("tutorial complete")
	t.check("tutorial_under_60s", sim_time < 60.0, "%.1fs" % sim_time)


func clear_ball(bi: int, target: float, skip_zones: Array) -> void:
	var b := g.balls[bi]
	var lb: LevelBuilder = b.get_meta("builder")
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
			var task: Dictionary = tasks.pop_front()
			await _do_task(b, task, routines_done)
	# Caves (optional content, but the bot verifies every upgrade).
	for h in lb.bot_hints:
		if h.has("cave") and not routines_done.has("cave"):
			routines_done["cave"] = true
			await cave(b, h)
	mark("ball %d at %.0f%%" % [bi + 1, b.restoration * 100.0])


func _collect_tasks(b: MossBall, lb: LevelBuilder, skip_zones: Array, done: Dictionary) -> Array:
	var tasks := []
	var special := {}
	for h in lb.bot_hints:
		if h.has("tower") and not done.has("tower"):
			tasks.append({"kind": "tower", "hint": h, "pos": func(): return b.surface_point(MossBall.dir_ll(h["lat"], h["lon"]))})
		if h.has("mesa") and not done.has("mesa"):
			tasks.append({"kind": "mesa", "hint": h, "pos": func(): return b.surface_point(MossBall.dir_ll(h["site"][0], h["site"][1]))})
		if h.has("canopy") and not done.has("canopy"):
			tasks.append({"kind": "canopy", "hint": h, "pos": func(): return (h["spiral"][0] as Transform3D).origin})
	for par in b.parasites:
		if par.is_alive() and not par.zone_id in skip_zones and par.state != "init":
			if not (done.has("canopy") == false and par.zone_id == "canopy") and not (par.zone_id == "mesa" and not done.has("mesa")):
				tasks.append({"kind": "kill", "ref": par, "pos": func(): return par.global_position})
	for m in b.motes:
		if m.is_available() and not m.zone_id in skip_zones:
			var elevated: bool = m.h_hint > 2.5
			if elevated and not done.has("fallback_%s" % m.zone_id):
				continue
			tasks.append({"kind": "mote", "ref": m, "pos": func(): return m.global_position})
	# After the special routines ran, anything elevated left over is retried generically.
	for k in ["tower", "mesa", "canopy"]:
		if done.has(k):
			for m in b.motes:
				if m.is_available() and m.h_hint > 2.5 and not m.zone_id in skip_zones:
					tasks.append({"kind": "mote", "ref": m, "pos": func(): return m.global_position})
	return tasks


func _do_task(b: MossBall, task: Dictionary, done: Dictionary) -> void:
	match task["kind"]:
		"kill":
			var par: Parasite = task["ref"]
			if not par.is_alive():
				return
			await goto(func(): return par.global_position, 2.0, 40.0)
			await fight_parasite(par, 25.0)
		"mote":
			await capture_mote(task["ref"])
		"tower":
			done["tower"] = true
			await tower(b, task["hint"])
		"mesa":
			done["mesa"] = true
			await mesa(b, task["hint"])
		"canopy":
			done["canopy"] = true
			await canopy(b, task["hint"])


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
	var ok := await hop_chain(chain, 5, start)
	if ok:
		for m in b.motes:
			if m.h_hint > 3.5 and m.is_available() and m.global_position.distance_to(p.global_position) < 5.0:
				await lunge_at(func(): return m.global_position, 15.0)


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
		await goto(start, 0.8, 40.0)
		if await hop_chain(chain, 2, start):
			break
	mark("on mesa top: %s" % str(height_of(b.surface_point(b.up_at(p.global_position))) < -5.0))
	for par in b.parasites:
		if par.zone_id == "mesa" and par.is_alive():
			await fight_parasite(par, 20.0)
	for m in b.motes:
		if m.zone_id == "mesa" and m.is_available():
			await lunge_at(func(): return m.global_position, 15.0)


func canopy(b: MossBall, h: Dictionary) -> void:
	mark("canopy climb")
	var spiral: Array = h["spiral"]
	var chain := []
	for xf in spiral:
		chain.append(Levels.leaf_mid(xf, 2.0, 0.0).origin + (xf as Transform3D).basis.y * 0.1)
	var base: Vector3 = b.surface_point(b.up_at((spiral[0] as Transform3D).origin))
	var start := base + (Levels.leaf_mid(spiral[0], 3.5, 0.0).origin - (spiral[0] as Transform3D).origin)
	start = b.surface_point(b.up_at(start))
	for attempt in 4:
		await goto(start, 0.8, 40.0)
		if await hop_chain(chain.slice(0, 5), 3, start):
			# Mote beside the 5th spiral leaf.
			for m in b.motes:
				if m.zone_id == "canopy" and m.is_available() and m.global_position.distance_to(p.global_position) < 3.5:
					await lunge_at(func(): return m.global_position, 8.0)
			await settle_on(chain[4])
			if await hop_chain(chain.slice(5), 3, start):
				break
	mark("top of spiral")
	var c1: Transform3D = h["c1"]
	var c1b: Transform3D = h["c1b"]
	var c2: Transform3D = h["c2"]
	var c3: Transform3D = h["c3"]
	await hop_chain([Levels.leaf_mid(c1, 1.2, 0.0).origin], 3)
	await goto(Levels.leaf_mid(c1, 2.6, 0.0).origin, 0.5, 6.0)   # canopy bloom
	# C3 branch: mote near the tip.
	await hop_chain([Levels.leaf_mid(c1, 0.6, 0.0).origin, Levels.leaf_mid(c3, 1.0, 0.0).origin], 3)
	for m in b.motes:
		if m.zone_id == "canopy" and m.is_available() and m.global_position.distance_to(Levels.leaf_mid(c3, 4.0, 0.0).origin) < 3.0:
			await goto(Levels.leaf_mid(c3, 3.2, 0.0).origin, 0.5, 8.0)
			await lunge_at(func(): return m.global_position, 10.0)
	# Back across to C2 via C1b, fight the medium parasite, grab the mote.
	await hop_chain([Levels.leaf_mid(c3, 0.8, 0.0).origin, Levels.leaf_mid(c1, 0.8, 0.0).origin, Levels.leaf_mid(c1, 3.8, 0.0).origin,
			Levels.leaf_mid(c1b, 2.0, 0.0).origin, Levels.leaf_mid(c2, 1.2, 1.0).origin], 3)
	for par in b.parasites:
		if par.zone_id == "canopy" and par.kind == Parasite.Kind.MEDIUM and par.is_alive():
			await fight_parasite(par, 15.0)
	for m in b.motes:
		if m.zone_id == "canopy" and m.is_available() and m.global_position.distance_to(c2.origin) < 6.0:
			await lunge_at(func(): return m.global_position, 10.0)
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
		await goto(door, 0.8, 10.0)
		var tops := []
		for l in ledges:
			tops.append((l as Node3D).global_transform * Vector3(0, float(l.get_meta("top")), 0))
		await goto(b.surface_point(b.up_at(tops[0])) + (door - b.surface_point(b.up_at(door))) * 0.0, 1.6, 10.0)
		if await hop_chain(tops, 3):
			var u = b.upgrades[0]
			await goto(u._leaf.global_position, 0.3, 5.0)
			await wait(0.5)
			if u.taken:
				mark("upgrade collected: max health %d" % p.max_health)
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
	for i in 60 * 10:
		await tick()
		if p.ball == dest and g.cinematic == "":
			break
	await wait(0.5)
	mark("arrived on ball %d" % (p.ball.index + 1))


func wander(time: float) -> void:
	var el := 0.0
	var dir := p.facing
	while el < time:
		set_stick(stick_for(dir))
		await wait(0.5)
		el += 0.5
		if randf() < 0.2:
			dir = dir.rotated(p.up, randf_range(-1.0, 1.0))
		if randf() < 0.1:
			await press("jump")
	set_stick(Vector2.ZERO)
	await eat_nearby(10.0)
