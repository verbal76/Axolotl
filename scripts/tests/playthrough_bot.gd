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
	await t.shot("pt_60_free_roam")
	_report()


# --- reporting ---------------------------------------------------------------------------

func mark(what: String) -> void:
	timeline.append([sim_time, what])
	var rs := PackedStringArray()
	for bb in g.balls:
		rs.append("%.2f" % bb.restoration)
	t.log_line("[%6.1fs] %s  (R: %s, hp %d/%d, deaths %d)" % [sim_time, what, " ".join(rs), p.health, p.max_health, g.stats["deaths"]])


func _report() -> void:
	t.log_line("stats: " + str(g.stats))
	t.log_line("stuck recoveries: %d" % stuck_events)
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


func tick() -> void:
	await t.frames(1)
	sim_time += 1.0 / 60.0
	_hb += 1.0 / 60.0
	var now := Time.get_ticks_usec()
	if _last_us > 0:
		var ms := (now - _last_us) / 1000.0
		_perf_n += 1
		_perf_proc += ms
		_perf_max = maxf(_perf_max, ms)
	_last_us = now
	if _hb >= float(Settings.test_args.get("hb", "20")):
		_hb = 0.0
		t.log_line("heartbeat %.0fs ball %d h %.1f act '%s' R %.2f %.2f %.2f hp %d cine '%s' state %s %s" % [sim_time, p.ball.index + 1,
				(p.global_position - p.ball.global_position).length() - p.ball.radius, activity, g.balls[0].restoration,
				g.balls[1].restoration, g.balls[2].restoration, p.health, g.cinematic, p.state, goto_info])


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
	var inside := _cave_of(p.global_position)
	if not inside.is_empty() and _cave_of(tgt0).is_empty() and not _in_cave_escape:
		_in_cave_escape = true
		await goto(inside["door"], 0.8, 15.0, null, false)
		await goto(inside["entry"], 0.8, 10.0, null, false)
		_in_cave_escape = false
	var el := 0.0
	var check_t := 0.0
	var last := p.global_position
	var escalate := 0
	var side := 1.0
	while el < timeout:
		var tgt: Vector3 = target.call() if target is Callable else target
		var flat := tangent_to(tgt)
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
		if p.health <= 1 and p.max_health > 1:
			await eat_nearby(8.0)
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
	failures.append("goto timeout on ball %d" % p.ball.index)
	return false


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
		var ok := await hop_toward(tgt, true)
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
		if Settings.test_args.has("trace_fight") and int(el * 10) % 10 == 0:
			t.log_line("approach t=%.1f dist %.2f dh %.2f par %s" % [sim_time, dist, height_of(cp), par.state])
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
			t.log_line("fight t=%.1f dist %.2f dh %.2f par %s hp %d pgrounded %s" % [sim_time, dist, height_of(cp), par.state, par.hp, p.grounded])
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
func lunge_at(target: Callable, timeout := 20.0, stay := false) -> bool:
	var el := 0.0
	var h0 := p.health
	var start_motes: int = g.stats["motes"]
	var start_eat: int = g.stats["eaten"][0] + g.stats["eaten"][1] + g.stats["eaten"][2]
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
	if ok:
		await wait(1.0)
	return not m.is_available()


# --- routines ----------------------------------------------------------------------------

func tutorial() -> void:
	var b := g.balls[0]
	mark("tutorial start")
	# 1-3: walk, jump onto M1, jump + water burst across to M2 — with a run-up, like a player.
	var toward := b.surface_point(MossBall.dir_ll(60, 0))
	for attempt in 5:
		await goto(b.surface_point(MossBall.dir_ll(86.0, 0)), 0.7, 20.0, null, false)
		for i in 120:
			set_stick(stick_for(tangent_to(toward)))
			await tick()
			if b.up_at(p.global_position).angle_to(MossBall.dir_ll(79, 0)) < deg_to_rad(8.5):
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
			if Levels._latlon(b.up_at(p.global_position)).x <= 75.6:
				break
		await press("jump")
		for i in 18:
			set_stick(stick_for(tangent_to(toward)))
			await tick()
		await press("jump")
		for i in 60:
			set_stick(stick_for(tangent_to(b.surface_point(MossBall.dir_ll(57.5, 0)))))
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
		await hop_toward(b.surface_point(MossBall.dir_ll(57.5, 0), 2.9), true, 0.1)
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
		if h.has("mesa") and (not done.has("mesa") or done.has("retry_mesa")):
			tasks.append({"kind": "mesa", "hint": h, "pos": func(): return b.surface_point(MossBall.dir_ll(h["site"][0], h["site"][1]))})
		if h.has("canopy") and (not done.has("canopy") or done.has("retry_canopy")):
			tasks.append({"kind": "canopy", "hint": h, "pos": func(): return (h["spiral"][0] as Transform3D).origin})
		# Expansion 4 climbs: needed while an elevated mote in their zones is still there.
		if h.has("route") and int(done.get("route:" + str(h["route"]), 0)) < 3 and _route_pending(b, h):
			tasks.append({"kind": "route", "hint": h, "pos": func(): return h["start"]})
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
		await goto(h["start"], 0.8, 45.0)
		var ok := await hop_chain(tops, 3, h["start"])
		for m in b.motes:
			if m.is_available() and m.zone_id in h["zones"] and m.h_hint > 2.5 and m.global_position.distance_to(end) < 6.0:
				await lunge_at(func(): return m.global_position, 12.0, true)
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
		await goto(start, 0.8, 40.0)
		if await hop_chain(chain, 2, start):
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
					await goto(start, 0.8, 40.0)
					await hop_chain(chain, 2, start)
				var ok := await lunge_at(func(): return m.global_position, 15.0, true)
				t.log_line("mesa mote attempt %d: %s (on top %s, mote h %.2f above him)" % [attempt, "caught" if ok else "missed", on_top.call(), height_of(m.global_position)])


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
		await goto(door, 0.8, 10.0)
		var tops := []
		for l in ledges:
			tops.append((l as Node3D).global_transform * Vector3(0, float(l.get_meta("top")), 0))
		await goto(b.surface_point(b.up_at(tops[0])) + (door - b.surface_point(b.up_at(door))) * 0.0, 1.6, 10.0)
		if await hop_chain(tops, 3):
			var u = h["reward"]
			await goto(u._leaf.global_position, 0.3, 5.0)
			await wait(0.5)
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
	for i in 60 * 10:
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
