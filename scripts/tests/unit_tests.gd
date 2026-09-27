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
	for name_ in ["_test_sphere_walk", "_test_jump_and_burst", "_test_coyote_and_buffer", "_test_swipe_direction_and_stages", "_test_hard_landing", "_test_food", "_test_darter_and_burrower", "_test_food_repopulates", "_test_motes", "_test_checkpoint_and_regen", "_test_crumble", "_test_restoration_continuity", "_test_vortex", "_test_current", "_test_canopy", "_test_upgrades", "_test_ui", "_test_all_clear"]:
		if only == "" or name_.contains(only):
			await call(name_)


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
	return (p.global_position - p.ball.global_position).length() - p.ball.radius


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


func _swipe_at(par: Parasite, behind: bool) -> void:
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


func _test_swipe_direction_and_stages() -> void:
	var small := first_alive(0, Parasite.Kind.SMALL, "meadow")
	await t.seconds(0.2)
	await _swipe_at(small, false)
	t.check("swipe_misses_in_front", small.is_alive(), "hp %d" % small.hp)
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
		if mm.zone_id == "meadow" and mm.is_available():
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
	place_at(0, m.anchor + m.anchor_up * 0.3 + (m.global_position - m.anchor) * 0.0 - fwd * 1.8 + side * 2.2, fwd)
	await t.frames(2)
	await press("lunge")
	var v0 := m.vel
	var dv := 0.0
	for k in 24:
		await t.frames(1)
		dv = maxf(dv, (m.vel - v0).length())
		v0 = m.vel
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
	await t.seconds(5.0)
	t.check("brittle_moss_regrows", c._state == "solid", c._state)
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
	for i in 60 * 8:
		await t.frames(1)
		if g.cinematic == "connect":
			saw_cine = true
		if saw_cine and g.cinematic == "":
			break
	t.check("vortex_connects_at_70_with_cinematic", v.connected and saw_cine and g.cinematic == "" and p.controls_enabled, "restoration %.2f" % b0.restoration)
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
	var above := Levels.leaf_mid(f1.global_transform, 2.4, 0.0).origin + b.up_at(f1.global_position) * 8.5
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
	t.check("aquarium_fully_clean", is_equal_approx(g.aquarium.clean, 1.0) and g.env.fog_density < 0.003, "fog %.4f" % g.env.fog_density)
