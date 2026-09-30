extends RefCounted
## Organic enemy movement (Open Issue #3): motion traces for visual review, and the checks that the
## expression layer (scripts/actors/organic_motion.gd) is deterministic, individual, frame-rate
## independent, bounded by the world, absent from committed attacks, and cheap.
##
## Driven from unit_tests.gd (`_test_organic_motion`, `_phase_organic_trace`). Creatures are stepped
## synchronously (their own _physics_process / tick at a fixed dt), so a simulated minute costs a
## fraction of a second and the result is the same on every machine.

var t
var g: Game
var p: Axolotl
var ut

const DT := 1.0 / 60.0


func _init(p_ut) -> void:
	ut = p_ut
	t = ut.t
	g = ut.g
	p = ut.p


# --- Switch --------------------------------------------------------------------------------

## The layer's global switch (absent before the layer existed: the baseline traces ran without it).
func set_organic(on: bool) -> void:
	var path := "res://scripts/actors/organic_motion.gd"
	if ResourceLoader.exists(path):
		var s: GDScript = load(path)
		s.set("enabled", on)


func organic_on() -> bool:
	var path := "res://scripts/actors/organic_motion.gd"
	if ResourceLoader.exists(path):
		return bool((load(path) as GDScript).get("enabled"))
	return false


# --- Helpers -------------------------------------------------------------------------------

func hold_everything() -> Callable:
	g.ecosystem.set_physics_process(false)
	var held: Array = []
	for b in g.balls:
		for pp in b.parasites:
			if pp.is_physics_processing():
				pp.set_physics_process(false)
				held.append(pp)
	return func() -> void:
		for pp in held:
			if is_instance_valid(pp):
				pp.set_physics_process(true)
		g.ecosystem.set_physics_process(true)


## Local top-down frame at `centre_dir` on ball `b`: [origin, east, north].
func frame(b: MossBall, centre_dir: Vector3) -> Array:
	var fr := MossBall.frame_at(centre_dir, 0.0)
	return [b.surface_point(centre_dir), fr.x, -fr.z]


func local(fr: Array, pos: Vector3) -> Vector2:
	var rel: Vector3 = pos - fr[0]
	return Vector2(rel.dot(fr[1]), rel.dot(fr[2]))


func local_angle(fr: Array, dir: Vector3) -> float:
	return atan2(dir.dot(fr[1]), dir.dot(fr[2]))


## The player well away from `pos` on `b` (far enough never to be noticed, near enough that
## parasites there still run: Game.ACTIVE_RADIUS).
func park_player_near(b: MossBall, pos: Vector3, dist := 22.0) -> void:
	var u := b.up_at(pos)
	var ax := MossBall.frame_at(u, 0.0).x
	var d := u.rotated(ax, dist / b.radius)
	p.place(b, b.surface_point(d, 0.2), Vector3.FORWARD)
	p.velocity = Vector3.ZERO
	p.bot_input = Vector2.ZERO
	p.invuln_t = 99999.0


func park_player_elsewhere(b: MossBall) -> void:
	var o: MossBall = g.balls[(b.index + 1) % g.balls.size()]
	p.place(o, o.surface_point(o.start_dir, 0.2), Vector3.FORWARD)
	p.velocity = Vector3.ZERO
	p.bot_input = Vector2.ZERO
	p.invuln_t = 99999.0


func par_full_snapshot(par: Parasite) -> Dictionary:
	var s: Dictionary = ut._par_snapshot(par)
	for k in ["state_t", "hit_cd", "_shaken", "_alerted_t", "_wary_t", "_perk_t", "_spit_cd", "_quiet_t", "_mode", "_mode_t",
			"_circle_len", "_circled", "_flank", "_los", "_los_check", "_unseen_t", "_graze_target", "_graze_t", "_pushed",
			"_attack_from", "_attack_dir", "_stretch_v", "_windup_v", "home_dir", "home_radius", "_clear_pos", "vel", "_latched",
			"_hurt_done", "standing_on", "_turn_side"]:
		s[k] = par.get(k)
	s["rng_state"] = par._rng.state
	var om = par.get("_org")
	if om != null:
		s["_org"] = om.snapshot()
	return s


func par_full_restore(par: Parasite, s: Dictionary) -> void:
	ut._par_restore(par, s)
	for k in s:
		if k in ["pos", "heading", "up", "trail", "trail_up", "state", "clock", "phase", "amp", "last", "rng_state", "_org"]:
			continue
		par.set(k, s[k])
	par._rng.state = s["rng_state"]
	if s.has("_org"):
		par.get("_org").restore(s["_org"])


func subjects(kind: int, variant := "", n := 8) -> Array:
	var out: Array = []
	for b in g.balls:
		for par in b.parasites:
			if par.is_alive() and par.kind == kind and par.variant == variant and par.state == "graze":
				out.append(par)
				if out.size() >= n:
					return out
	return out


# --- Traces (visual review) ----------------------------------------------------------------

## Writes top-down motion traces of every enemy type to <out>/trace_<tag>.csv:
## species,id,t,x,y,alt,heading,state,extra   (x east / y north in metres round the subject's home).
func trace() -> void:
	var tag: String = Settings.test_args.get("org", "on")
	set_organic(tag != "off")
	var secs := float(Settings.test_args.get("secs", "120"))
	var release := hold_everything()
	var lines: PackedStringArray = ["species,id,t,x,y,alt,heading,state,extra"]
	# Parasites grazing, each kind, up to 8 individuals.
	for kv in [[Parasite.Kind.SMALL, "", "par_small"], [Parasite.Kind.MEDIUM, "", "par_medium"], [Parasite.Kind.LARGE, "", "par_large"], [Parasite.Kind.MEDIUM, "spitter", "par_spitter"]]:
		var subs := subjects(kv[0], kv[1])
		for i in subs.size():
			var par: Parasite = subs[i]
			var b := par.ball
			var snap := par_full_snapshot(par)
			park_player_near(b, b.surface_point(par.home_dir))
			await t.frames(2)
			seed(1000 + i)
			var fr := frame(b, par.home_dir)
			for f in int(secs * 60.0):
				par._physics_process(DT)
				if f % 6 == 0:
					lines.append(_par_line(kv[2], i, f * DT, fr, par))
			par_full_restore(par, snap)
			par._set_state("graze")
	# Parasites closing in on him (from 7 m, five bearings), until they commit, then the attack.
	var cb := _combat_ball()
	var centre: Vector3 = cb.arrival_dir.rotated(MossBall.frame_at(cb.arrival_dir, 0).x, deg_to_rad(9.0)).normalized()
	var fr_c := frame(cb, centre)
	for kv in [[Parasite.Kind.SMALL, "chase_small"], [Parasite.Kind.MEDIUM, "chase_medium"], [Parasite.Kind.LARGE, "chase_large"]]:
		var par: Parasite = null
		for q in cb.parasites:
			if q.is_alive() and q.kind == kv[0] and q.variant == "":
				par = q
				break
		if par == null:
			continue
		var snap := par_full_snapshot(par)
		for k in 5:
			var r: Array = await chase_run(cb, centre, par, k * 72.0 + 10.0, 12.0)
			for row in r[1]:
				lines.append("%s,%d,%.2f,%.3f,%.3f,%.3f,%.4f,%s,%.3f" % [kv[1], k, row[0], local(fr_c, row[1]).x, local(fr_c, row[1]).y, 0.0, local_angle(fr_c, row[2]), row[3], row[4]])
			par_full_restore(par, snap)
			par._set_state("graze")
	# Critters: stalkers prowling, puffers drifting, crabs resting and walking back, eels hidden.
	var idx := {}
	for c in g.ecosystem.all_critters():
		if not (c is ReedStalker or c is Pufferfish or c is CrabGuardian or c is CaveEel) or c.defeated:
			continue
		var sp: String = c.species
		var i: int = idx.get(sp, 0)
		idx[sp] = i + 1
		var b: MossBall = c.ball
		park_player_elsewhere(b)
		await t.frames(2)
		if c is ReedStalker:
			var st := c as ReedStalker
			var fr := frame(b, st.patch_dir)
			for f in int(secs * 60.0):
				st.tick(DT)
				if f % 6 == 0:
					lines.append(_crit_line("stalker", i, f * DT, fr, st.global_position, b.altitude(st.global_position), st.heading, st.state, _head_yaw(st._head, st.heading, b)))
		elif c is Pufferfish:
			var pf := c as Pufferfish
			var fr := frame(b, pf.home_dir)
			for f in int(secs * 60.0):
				pf.tick(DT)
				if f % 6 == 0:
					lines.append(_crit_line("puffer", i, f * DT, fr, pf.global_position, b.altitude(pf.global_position) - pf._ground_alt - pf.hover, -pf.global_basis.z, "hover", 0.0))
		elif c is CrabGuardian:
			var cr := c as CrabGuardian
			var fr := frame(b, b.up_at(cr.post))
			var rig: Node3D = cr._rig
			for k in 4:
				if k > 0:
					var u := b.up_at(cr.post)
					cr._snap(b.surface_point(b.up_at(cr.post + cr.facing.rotated(u, (k - 2) * 0.7) * 4.0)))
					cr._go("retreat")
				for f in int(12.0 * 60.0):
					cr.tick(DT)
					if f % 6 == 0:
						lines.append(_crit_line("crab", k, f * DT, fr, cr.global_position, 0.0, cr.facing, cr.state, rig.rotation.y))
		elif c is CaveEel:
			var e := c as CaveEel
			var fr := frame(b, b.up_at(e.mouth))
			for f in int(60.0 * 60.0):
				e.tick(DT)
				if f % 6 == 0:
					var look: Vector3 = -e._head.global_basis.z
					lines.append(_crit_line("eel", i, f * DT, fr, e._head.global_position, 0.0, look, e.state, rad_to_deg(look.angle_to(e.normal))))
	var f := FileAccess.open(ut.t.out_dir.path_join("trace_%s.csv" % tag), FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	t.check("organic_trace_written", lines.size() > 1000, "%d rows (%s)" % [lines.size(), tag])
	release.call()


func _par_line(sp: String, i: int, tm: float, fr: Array, par: Parasite) -> String:
	var l := local(fr, par.global_position)
	var head_fwd: Vector3 = -par._segs[0].global_basis.z
	var extra := rad_to_deg(signf(par.heading.cross(head_fwd).dot(par.up)) * par.heading.angle_to(head_fwd))
	return "%s,%d,%.2f,%.3f,%.3f,%.3f,%.4f,%s,%.3f" % [sp, i, tm, l.x, l.y, par.ball.altitude(par.global_position), local_angle(fr, par.heading), par.state, extra]


func _crit_line(sp: String, i: int, tm: float, fr: Array, pos: Vector3, alt: float, hdg: Vector3, state: String, extra: float) -> String:
	var l := local(fr, pos)
	return "%s,%d,%.2f,%.3f,%.3f,%.3f,%.4f,%s,%.3f" % [sp, i, tm, l.x, l.y, alt, local_angle(fr, hdg), state, extra]


func _head_yaw(head: Node3D, heading: Vector3, b: MossBall) -> float:
	var hf: Vector3 = -head.global_basis.z
	var u := b.up_at(head.global_position)
	return rad_to_deg(signf(heading.cross(hf).dot(u)) * heading.angle_to(hf))


## The ball the combat test uses (two small, a medium, a large parasite, and an upgrade).
func _combat_ball() -> MossBall:
	var b: MossBall = g.balls[3]
	for bi in range(3, g.balls.size()):
		var kinds := {}
		for par in g.balls[bi].parasites:
			kinds[par.kind] = int(kinds.get(par.kind, 0)) + 1
		if int(kinds.get(Parasite.Kind.SMALL, 0)) >= 2 and kinds.has(Parasite.Kind.MEDIUM) and kinds.has(Parasite.Kind.LARGE) and not g.balls[bi].upgrades.is_empty():
			return g.balls[bi]
	return b


## One parasite set down `dist_m` (7 m) from him on bearing `bearing` (deg), hunting him until it
## commits (then 1.5 s more of the attack). Returns [seconds to commit (-1 never), rows
## [t, pos, heading, state, speed]].
func chase_run(b: MossBall, centre: Vector3, par: Parasite, bearing: float, timeout: float, dist_m := 7.0) -> Array:
	var fr := MossBall.frame_at(centre, 0.0)
	var him := b.surface_point(centre)
	p.place(b, b.surface_point(centre, 0.1), -fr.z)
	p.velocity = Vector3.ZERO
	p.bot_input = Vector2.ZERO
	p.invuln_t = 99999.0
	await t.frames(2)
	var start := b.surface_point(b.up_at(him + (-fr.z).rotated(b.up_at(him), deg_to_rad(bearing)) * dist_m))
	var d := b.up_at(start)
	par.home_dir = d
	par.home_radius = deg_to_rad(14.0)
	par.global_position = b.surface_point(d, par._ground_offset)
	par.up = d
	par.heading = (him - start - d * (him - start).dot(d)).normalized().rotated(d, 1.2)
	par._trail.clear()
	par._trail_up.clear()
	for i in 12:
		par._trail.push_back(par.global_position - par.heading * par.spacing * i * 0.5)
		par._trail_up.push_back(d)
	par._set_state("graze")
	par._graze_target = par.global_position
	par._graze_t = 5.0
	par._alerted_t = 0.0
	par._wary_t = 0.0
	par._shaken = 0.0
	par.hit_cd = 0.0
	par._circled = false
	par._flank = 0.0
	par._los_check = 0.0
	par._mode = "approach"
	var om = par.get("_org")
	if om != null:
		om.reset_weights()
	par._update_segments(0.0)
	Parasite._last_commit.clear()
	var rows: Array = []
	var t_commit := -1.0
	var after := 0.0
	var last := par.global_position
	for f in int(timeout * 60.0):
		par._physics_process(DT)
		var v := par.global_position.distance_to(last) / DT
		last = par.global_position
		if f % 3 == 0:
			rows.append([f * DT, par.global_position, par.heading, par.state, v])
		if t_commit < 0.0 and par.state == "windup":
			t_commit = f * DT
		if t_commit >= 0.0:
			after += DT
			if after > 1.5:
				break
	return [t_commit, rows]


# --- Checks --------------------------------------------------------------------------------

func run_checks() -> void:
	for kind in [Parasite.Kind.SMALL, Parasite.Kind.MEDIUM, Parasite.Kind.LARGE]:
		if subjects(kind, "", 2).size() < 2 or _first(ReedStalker) == null:
			t.check("organic_subjects", false, "needs living grazing parasites of each size and a stalker (run it before the all-clear tests)")
			return
	var release := hold_everything()
	var was_on := organic_on()
	set_organic(true)
	var saved := _save_world()
	_check_signals()
	_check_rng()
	await _check_determinism()
	await _check_frame_rate()
	await _check_bounds()
	await _check_committed()
	await _check_pursuit()
	await _check_cost()
	set_organic(was_on)
	_restore_world(saved)
	release.call()
	p.invuln_t = 0.0
	p.restore_full()
	await t.frames(2)


## Every creature this touches, as it was (the suite runs on after this test).
func _save_world() -> Array:
	var out := []
	for b in g.balls:
		for par in b.parasites:
			if par.is_alive() and par.state == "graze":
				out.append([par, par_full_snapshot(par)])
	for c in g.ecosystem.all_critters():
		out.append([c, _crit_snapshot(c)])
	return out


func _restore_world(saved: Array) -> void:
	for e in saved:
		if e[0] is Parasite:
			par_full_restore(e[0], e[1])
			(e[0] as Parasite)._set_state("graze")
		else:
			_crit_restore(e[0], e[1])
	Parasite._last_commit.clear()


func _crit_snapshot(c: Critter) -> Dictionary:
	var s := {"xf": c.global_transform, "rng": c.rng.state}
	for k in ["state", "state_t", "heading", "_target", "_lock", "_vel", "_trail", "cooldown", "_near_t", "_hurt", "facing", "wary_t",
			"inflate", "puffed", "calm_t", "_wander", "_wander_t", "ext", "_dir", "reach", "_stepping", "contact_cd", "_clock"]:
		if k in c:
			var v = c.get(k)
			s[k] = v.duplicate() if v is Array else v
	if c.org != null:
		s["org"] = c.org.snapshot()
	return s


func _crit_restore(c: Critter, s: Dictionary) -> void:
	c.global_transform = s["xf"]
	c.rng.state = s["rng"]
	for k in s:
		if k in ["xf", "rng", "org"]:
			continue
		var v = s[k]
		c.set(k, v.duplicate() if v is Array else v)
	if s.has("org"):
		c.org.restore(s["org"])


func _profiles() -> Array:
	# [name, profile, seeds of real individuals, channel]
	var out := []
	for kv in [["small", Parasite.Kind.SMALL, "", OrganicMotion.PARASITE_SMALL], ["medium", Parasite.Kind.MEDIUM, "", OrganicMotion.PARASITE_MEDIUM],
			["large", Parasite.Kind.LARGE, "", OrganicMotion.PARASITE_LARGE], ["spitter", Parasite.Kind.MEDIUM, "spitter", OrganicMotion.PARASITE_SPITTER]]:
		var seeds := []
		for b in g.balls:
			for par in b.parasites:
				if par.kind == kv[1] and par.variant == kv[2] and seeds.size() < 10:
					seeds.append(par._rng.seed)
		out.append([kv[0], kv[3], seeds, "yaw"])
	for kv in [["stalker", ReedStalker, OrganicMotion.STALKER, "yaw"], ["puffer", Pufferfish, OrganicMotion.PUFFER, "wander"],
			["crab", CrabGuardian, OrganicMotion.CRAB, "lift"], ["eel", CaveEel, OrganicMotion.EEL, "look"]]:
		var seeds := []
		for c in g.ecosystem.all_critters():
			if is_instance_of(c, kv[1]):
				seeds.append(c.rng.seed)
		out.append([kv[0], kv[2], seeds, kv[3]])
	return out


static func _series(om: OrganicMotion, channel: String, secs: float, dt: float) -> Array:
	var out := []
	for i in int(secs / dt):
		om.step(dt, 1.0, 1.0, 1.0)
		match channel:
			"yaw":
				out.append(om.yaw)
			"wander":
				out.append(om.wander2().x)
			"lift":
				out.append(om.lift)
			_:
				out.append(om.look)
	return out


static func corr(a: Array, c: Array) -> float:
	var n := mini(a.size(), c.size())
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


## Individual, unsynchronised, not repeating: every species' signals.
func _check_signals() -> void:
	var sync_ok := true
	var rep_ok := true
	var sync_rows: Array[String] = []
	var rep_rows: Array[String] = []
	for pr in _profiles():
		var seeds: Array = pr[2]
		if seeds.is_empty():
			continue
		# Same-species individuals over three minutes (at least 8: the real ones, then more seeds
		# of the same kind for species with fewer in the world).
		var all_seeds := seeds.duplicate()
		var k := 0
		while all_seeds.size() < 8:
			all_seeds.append(hash([seeds[0], "extra", k]))
			k += 1
		var ser := []
		for sd in all_seeds.slice(0, 10):
			ser.append(_series(OrganicMotion.new(sd, pr[1]), pr[3], 180.0, 0.1))
		var sum := 0.0
		var most := 0.0
		var n := 0
		for i in ser.size():
			for j in range(i + 1, ser.size()):
				var c := absf(corr(ser[i], ser[j]))
				sum += c
				most = maxf(most, c)
				n += 1
		var mean := sum / n
		sync_ok = sync_ok and mean < 0.3
		sync_rows.append("%s n=%d mean %.2f max %.2f" % [pr[0], ser.size(), mean, most])
		# No short-period repetition: over three minutes, the signal never matches itself shifted
		# by 5..60 s (a loop would; a lone sine, or a steady rhythm, scores about 1.0).
		var worst := 0.0
		for sr in ser:
			for lag in range(50, 601, 10):
				worst = maxf(worst, corr(sr.slice(0, sr.size() - lag), sr.slice(lag)))
		rep_ok = rep_ok and worst < 0.85
		rep_rows.append("%s %.2f" % [pr[0], worst])
	t.check("organic_individuals_not_in_step", sync_ok, "pairwise |correlation| of each species' signal over 3 min: " + ", ".join(sync_rows))
	t.check("organic_no_short_period_repetition", rep_ok, "worst self-match over 3 min at 5-60 s lags: " + ", ".join(rep_rows))
	# Frame-rate independence of the signal itself (30 vs 60 Hz, weights changing on the way).
	var a := OrganicMotion.new(12345, OrganicMotion.PARASITE_MEDIUM)
	var c := OrganicMotion.new(12345, OrganicMotion.PARASITE_MEDIUM)
	var diff := 0.0
	for f in 30 * 20:
		var wp := 1.0 if f < 300 else 0.3
		a.step(1.0 / 60.0, wp, 1.0, 1.0)
		a.step(1.0 / 60.0, wp, 1.0, 1.0)
		c.step(1.0 / 30.0, wp, 1.0, 1.0)
		diff = maxf(diff, maxf(absf(a.yaw - c.yaw), absf(a.speed - c.speed)))
	t.check("organic_signal_frame_rate_independent", diff < 1e-6, "30 vs 60 Hz: outputs differ by at most %.9f" % diff)


## The layer never draws from any generator: the gameplay sequence is untouched by creatures
## moving with it, and its own outputs need no generator at all.
func _check_rng() -> void:
	seed(55)
	var r1 := randi()
	seed(55)
	var om := OrganicMotion.new(99, OrganicMotion.PARASITE_LARGE)
	for i in 5000:
		om.step(1.0 / 60.0, 1.0, 1.0, 1.0)
		om.wander2()
		om.warp(i / 60.0, 1.7)
	var subs := subjects(Parasite.Kind.MEDIUM, "", 2)
	for par in subs:
		var snap := par_full_snapshot(par)
		park_player_near(par.ball, par.ball.surface_point(par.home_dir))
		for f in 600:
			par._physics_process(DT)
		par_full_restore(par, snap)
	for c in g.ecosystem.all_critters():
		if c is ReedStalker or c is Pufferfish or c is CrabGuardian or c is CaveEel:
			var cs := _crit_snapshot(c)
			for f in 120:
				c.tick(DT)
			_crit_restore(c, cs)
	var r2 := randi()
	t.check("organic_leaves_gameplay_rng_alone", r1 == r2, "")


## Twin runs from the same state trace the same path exactly.
func _check_determinism() -> void:
	var a := OrganicMotion.new(777, OrganicMotion.STALKER)
	var c := OrganicMotion.new(777, OrganicMotion.STALKER)
	var same := true
	for i in 3600:
		a.step(DT, 1.0, 1.0, 1.0)
		c.step(DT, 1.0, 1.0, 1.0)
		same = same and a.yaw == c.yaw and a.speed == c.speed and a.look == c.look and a.lift == c.lift
	var drift := 0.0
	for kind in [Parasite.Kind.SMALL, Parasite.Kind.LARGE]:
		var par: Parasite = subjects(kind, "", 1)[0]
		park_player_near(par.ball, par.ball.surface_point(par.home_dir))
		await t.frames(2)
		var snap := par_full_snapshot(par)
		var runs := []
		for r in 2:
			par_full_restore(par, snap)
			var path := []
			for f in 1200:
				par._physics_process(DT)
				path.append(par.global_position)
			runs.append(path)
		par_full_restore(par, snap)
		for i in runs[0].size():
			drift = maxf(drift, (runs[0][i] as Vector3).distance_to(runs[1][i]))
	var st := _first(ReedStalker) as ReedStalker
	park_player_elsewhere(st.ball)
	await t.frames(2)
	var ss := _crit_snapshot(st)
	var sp := []
	for r in 2:
		_crit_restore(st, ss)
		var path := []
		for f in 1200:
			st.tick(DT)
			path.append(st.global_position)
		sp.append(path)
	_crit_restore(st, ss)
	for i in sp[0].size():
		drift = maxf(drift, (sp[0][i] as Vector3).distance_to(sp[1][i]))
	t.check("organic_deterministic", same and drift == 0.0, "twin signals identical %s; twin 20 s paths (small, large, stalker) differ by %.9f m" % [same, drift])


func _first(cls) -> Critter:
	for c in g.ecosystem.all_critters():
		if is_instance_of(c, cls) and not c.defeated:
			return c
	return null


## Mean distance between two sampled paths.
static func _gap(a: Array, c: Array) -> float:
	var n := mini(a.size(), c.size())
	var sum := 0.0
	for i in n:
		sum += (a[i] as Vector3).distance_to(c[i])
	return sum / maxf(n, 1)


## A grazing parasite and a prowling stalker at 30 and at 60 Hz, with the layer on and off: the
## layer adds no frame-rate dependence of its own.
func _check_frame_rate() -> void:
	var rows: Array[String] = []
	var ok := true
	var par: Parasite = subjects(Parasite.Kind.MEDIUM, "", 1)[0]
	park_player_near(par.ball, par.ball.surface_point(par.home_dir))
	await t.frames(2)
	var snap := par_full_snapshot(par)
	var gap := {}
	for on in [false, true]:
		set_organic(on)
		var paths := []
		for rate in [60, 30]:
			par_full_restore(par, snap)
			var path := []
			for f in 8 * rate:
				par._physics_process(1.0 / rate)
				if f % (rate / 10) == 0:
					path.append(par.global_position)
			paths.append(path)
		gap[on] = _gap(paths[0], paths[1])
	par_full_restore(par, snap)
	set_organic(true)
	rows.append("medium parasite 8 s: 30 vs 60 Hz mean gap %.3f m on, %.3f m off" % [gap[true], gap[false]])
	ok = ok and gap[true] < maxf(gap[false] * 1.5, 0.25)
	var st := _first(ReedStalker) as ReedStalker
	park_player_elsewhere(st.ball)
	await t.frames(2)
	var ss := _crit_snapshot(st)
	var sgap := {}
	for on in [false, true]:
		set_organic(on)
		var paths := []
		for rate in [60, 30]:
			_crit_restore(st, ss)
			var path := []
			for f in 8 * rate:
				st.tick(1.0 / rate)
				if f % (rate / 10) == 0:
					path.append(st.global_position)
			paths.append(path)
		sgap[on] = _gap(paths[0], paths[1])
	_crit_restore(st, ss)
	set_organic(true)
	rows.append("stalker 8 s: %.3f m on, %.3f m off" % [sgap[true], sgap[false]])
	ok = ok and sgap[true] < maxf(sgap[false] * 1.5, 0.25)
	t.check("organic_paths_frame_rate_independent", ok, "; ".join(rows))


## Five simulated minutes of each type with the layer on: the world always wins (home, patch,
## territory and hover limits; never on a ravine floor, buried, or through a wall).
func _check_bounds() -> void:
	var rows: Array[String] = []
	var ok := true
	var space := g.get_world_3d().direct_space_state
	var frames := 5 * 60 * 60
	for kv in [[Parasite.Kind.SMALL, ""], [Parasite.Kind.MEDIUM, ""], [Parasite.Kind.LARGE, ""], [Parasite.Kind.MEDIUM, "spitter"]]:
		for par in subjects(kv[0], kv[1], 2):
			var b: MossBall = par.ball
			park_player_near(b, b.surface_point(par.home_dir))
			await t.frames(2)
			var snap := par_full_snapshot(par)
			var off_home := 0.0
			for on in [false, true]:
				set_organic(on)
				par_full_restore(par, snap)
				var most := 0.0
				var low := INF
				var floor_t := 0
				var walls := 0
				var last: Vector3 = par.global_position + par.up * par.seg_radius
				for f in frames:
					par._physics_process(DT)
					if f % 2 != 0:
						continue
					var now: Vector3 = par.global_position + par.up * par.seg_radius
					if par.state == "graze":
						most = maxf(most, par._angle_from_home(par.global_position) / par.home_radius)
						var alt := b.altitude(par.global_position)
						low = minf(low, alt)
						if not b.carves.is_empty() and b.ravine_carve(b.up_at(par.global_position)) > 0.3 and alt < 1.0:
							floor_t += 1
						if now.distance_to(last) > 0.001 and now.distance_to(last) < 0.5:
							var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(last, now, 1))
							if not hit.is_empty() and (hit["normal"] as Vector3).dot(par.up) < 0.6:
								walls += 1
					last = now
				if not on:
					off_home = most
				else:
					ok = ok and low > -0.8 and floor_t == 0 and walls == 0 and most <= maxf(off_home * 1.1, 1.15)
					rows.append("%s%s: home %.2f (off %.2f), lowest %.2f m, ravine floor %d, walls %d" % [["", "small", "medium", "large"][kv[0]], "/spitter" if kv[1] != "" else "", most, off_home, low, floor_t, walls])
			par_full_restore(par, snap)
			set_organic(true)
	# Stalkers in their patch and out of rock.
	var n_st := 0
	for c in g.ecosystem.all_critters():
		if not c is ReedStalker or n_st >= 2:
			continue
		n_st += 1
		var st := c as ReedStalker
		park_player_elsewhere(st.ball)
		await t.frames(2)
		var ss := _crit_snapshot(st)
		var worst := 0.0
		var walls := 0
		var last := st.global_position
		for f in frames:
			st.tick(DT)
			var u := st.ball.up_at(st.global_position)
			worst = maxf(worst, rad_to_deg(u.angle_to(st.patch_dir)) - st.patch_deg)
			if f % 2 == 0:
				if last.distance_to(st.global_position) > 0.001 and st.line_blocked(last + st.ball.up_at(last) * 0.3, st.global_position + u * 0.3):
					walls += 1
				last = st.global_position
		_crit_restore(st, ss)
		ok = ok and worst <= 2.0 and walls == 0
		rows.append("stalker: %.2f deg past its patch (limit 2), walls %d" % [maxf(worst, 0.0), walls])
	# Puffers: near home, at their height.
	var n_pf := 0
	for c in g.ecosystem.all_critters():
		if not c is Pufferfish or n_pf >= 2:
			continue
		n_pf += 1
		var pf := c as Pufferfish
		park_player_elsewhere(pf.ball)
		await t.frames(2)
		var ss := _crit_snapshot(pf)
		var res := {}
		for on in [false, true]:
			set_organic(on)
			_crit_restore(pf, ss)
			var far := 0.0
			var dev := 0.0
			for f in frames:
				pf.tick(DT)
				far = maxf(far, rad_to_deg(pf.ball.up_at(pf.global_position).angle_to(pf.home_dir)) - pf.home_deg)
				if f > 600:
					dev = maxf(dev, absf(pf.ball.altitude(pf.global_position) - pf._ground_alt - pf.hover))
			res[on] = [far, dev]
		set_organic(true)
		_crit_restore(pf, ss)
		# (One puffer is carried off by a strong current without the layer too (its home pull is
		# weaker than the flow): pre-existing, reported, not judged here.)
		var escapes: bool = res[false][0] > 5.0
		ok = ok and (escapes or res[true][0] <= maxf(res[false][0] + 1.0, 1.5)) and res[true][1] <= res[false][1] + 0.35
		rows.append("puffer: %.2f deg past home (off %.2f%s), height off by %.2f m (off %.2f)" % [res[true][0], res[false][0], ", carried off by the current without the layer too" if escapes else "", res[true][1], res[false][1]])
	# Crab: at its post.
	var cr := _first(CrabGuardian) as CrabGuardian
	if cr != null:
		park_player_elsewhere(cr.ball)
		await t.frames(2)
		var ss := _crit_snapshot(cr)
		cr._go("rest")
		var far := 0.0
		var turn := 0.0
		for f in frames:
			cr.tick(DT)
			far = maxf(far, cr.global_position.distance_to(cr.post))
			turn = maxf(turn, absf(cr._rig.rotation.y))
		_crit_restore(cr, ss)
		ok = ok and far <= 0.35 and turn <= 0.4
		rows.append("crab: %.2f m from its post at most, body turn %.0f deg" % [far, rad_to_deg(turn)])
	var e := _first(CaveEel) as CaveEel
	if e != null:
		park_player_elsewhere(e.ball)
		await t.frames(2)
		var es := _crit_snapshot(e)
		var far := 0.0
		for f in frames:
			e.tick(DT)
			far = maxf(far, e._head.global_position.distance_to(e.mouth))
		ok = ok and far <= 0.2 and e.state == "hidden" and e.ext == 0.0
		_crit_restore(e, es)
		rows.append("eel: head %.2f m from its crevice mouth at most" % far)
	t.check("organic_bounded_by_the_world_5_minutes", ok, "; ".join(rows))


## Committed attacks are exactly the same with the layer on and off (from the same moment).
func _check_committed() -> void:
	var rows: Array[String] = []
	var ok := true
	var cb := _combat_ball()
	var centre: Vector3 = cb.arrival_dir.rotated(MossBall.frame_at(cb.arrival_dir, 0).x, deg_to_rad(9.0)).normalized()
	for kind in [Parasite.Kind.SMALL, Parasite.Kind.MEDIUM, Parasite.Kind.LARGE]:
		var par: Parasite = null
		for q in cb.parasites:
			if q.is_alive() and q.kind == kind and q.variant == "":
				par = q
				break
		if par == null:
			continue
		var home := par_full_snapshot(par)
		# Set down 5 m from him, run until its wind-up starts, then from that frame twice.
		await chase_run(cb, centre, par, 30.0, 0.0, 5.0)
		var el := 0
		while par.state != "windup" and el < 12 * 60:
			par._physics_process(DT)
			el += 1
		var committed := par.state == "windup"
		var snap := par_full_snapshot(par)
		var paths := []
		for on in [true, false]:
			set_organic(on)
			par_full_restore(par, snap)
			Parasite._last_commit.clear()
			var path := []
			for f in 240:
				par._physics_process(DT)
				if not par.state in ["windup", "attack", "recover"]:
					break
				path.append([par.state, par.global_position, par.heading, par.closest_body_point(p.body_center())])
			paths.append(path)
		set_organic(true)
		var same: bool = committed and paths[0].size() > 20 and paths[0] == paths[1]
		ok = ok and same
		rows.append("%s: %d committed frames identical %s" % [["", "small", "medium", "large"][kind], paths[0].size(), same])
		par_full_restore(par, home)
		par._set_state("graze")
	# Stalker telegraph, pounce and recovery; crab warning and charge; eel strike.
	var st := _first(ReedStalker) as ReedStalker
	park_player_elsewhere(st.ball)
	await t.frames(2)
	var ss := _crit_snapshot(st)
	st._go("telegraph")
	st._lock = st.heading.rotated(st.ball.up_at(st.global_position), 0.7)
	var s0 := _crit_snapshot(st)
	var sp := []
	for on in [true, false]:
		set_organic(on)
		_crit_restore(st, s0)
		var path := []
		for f in 240:
			st.tick(DT)
			if not st.state in ["telegraph", "pounce", "recover"]:
				break
			path.append([st.state, st.global_position, st.heading, st.closest_body_point(p.body_center())])
		sp.append(path)
	set_organic(true)
	_crit_restore(st, ss)
	ok = ok and sp[0] == sp[1] and sp[0].size() > 100
	rows.append("stalker: %d frames identical %s" % [sp[0].size(), sp[0] == sp[1]])
	var cr := _first(CrabGuardian) as CrabGuardian
	if cr != null:
		var cs := _crit_snapshot(cr)
		var b := cr.ball
		var stand := b.surface_point(b.up_at(cr.post + cr.facing * 3.0), 0.2)
		p.place(b, stand, cr.post - stand)
		p.invuln_t = 99999.0
		await t.frames(2)
		cr._go("warn")
		var c0 := _crit_snapshot(cr)
		var cp := []
		for on in [true, false]:
			set_organic(on)
			_crit_restore(cr, c0)
			var path := []
			for f in 240:
				cr.tick(DT)
				if not cr.state in ["warn", "charge"]:
					break
				path.append([cr.state, cr.global_position, cr.facing])
			cp.append(path)
		set_organic(true)
		_crit_restore(cr, cs)
		ok = ok and cp[0] == cp[1] and cp[0].size() > 60
		rows.append("crab: %d frames identical %s" % [cp[0].size(), cp[0] == cp[1]])
	var e := _first(CaveEel) as CaveEel
	if e != null:
		var es := _crit_snapshot(e)
		var b := e.ball
		var front := b.surface_point(b.up_at(e.mouth + e.normal * 2.2), 0.2)
		p.place(b, front, e.mouth - front)
		p.invuln_t = 99999.0
		await t.frames(2)
		e._go("alert")
		e._dir = e._aim(p.body_center())
		var e0 := _crit_snapshot(e)
		var ep := []
		for on in [true, false]:
			set_organic(on)
			_crit_restore(e, e0)
			var path := []
			for f in 150:
				e.tick(DT)
				path.append([e.state, e.ext, e._dir, e.hittable(), e.closest_body_point(p.body_center())])
			ep.append(path)
		set_organic(true)
		_crit_restore(e, es)
		e._pose()
		ok = ok and ep[0] == ep[1]
		rows.append("eel: %d frames identical %s" % [ep[0].size(), ep[0] == ep[1]])
	t.check("organic_committed_attacks_identical", ok, "; ".join(rows))


## Closing in still works: from 5.5 m the same parasite commits in about the same time with the
## layer on as without it (within 15% in total over four approach bearings).
func _check_pursuit() -> void:
	var cb := _combat_ball()
	var centre: Vector3 = cb.arrival_dir.rotated(MossBall.frame_at(cb.arrival_dir, 0).x, deg_to_rad(9.0)).normalized()
	var rows: Array[String] = []
	var ok := true
	for kind in [Parasite.Kind.SMALL, Parasite.Kind.MEDIUM, Parasite.Kind.LARGE]:
		var par: Parasite = null
		for q in cb.parasites:
			if q.is_alive() and q.kind == kind and q.variant == "":
				par = q
				break
		if par == null:
			continue
		var home := par_full_snapshot(par)
		var tot := {true: 0.0, false: 0.0}
		var n := {true: 0, false: 0}
		for bearing in [10.0, 100.0, 190.0, 280.0]:
			var tt := {}
			for on in [false, true]:
				set_organic(on)
				par_full_restore(par, home)
				var r: Array = await chase_run(cb, centre, par, bearing, 12.0, 5.5)
				tt[on] = r[0]
			if tt[true] >= 0.0:
				n[true] += 1
			if tt[false] >= 0.0:
				n[false] += 1
			if tt[true] >= 0.0 and tt[false] >= 0.0:
				tot[true] += tt[true]
				tot[false] += tt[false]
		set_organic(true)
		par_full_restore(par, home)
		par._set_state("graze")
		var ratio: float = tot[true] / maxf(tot[false], 0.001)
		ok = ok and n[true] >= n[false] and n[true] >= 3 and absf(ratio - 1.0) <= 0.15
		rows.append("%s: committed %d/4 on, %d/4 off, time on/off %.2f (%.2f s vs %.2f s)" % [["", "small", "medium", "large"][kind], n[true], n[false], ratio, tot[true], tot[false]])
	Parasite._last_commit.clear()
	t.check("organic_pursuit_still_reaches", ok, "; ".join(rows))


## Cost: the layer itself, and a representative population with it on and off.
func _check_cost() -> void:
	var om := OrganicMotion.new(4242, OrganicMotion.PARASITE_MEDIUM)
	var t0 := Time.get_ticks_usec()
	for i in 20000:
		om.step(DT, 1.0, 1.0, 1.0)
	var per := float(Time.get_ticks_usec() - t0) / 20000.0
	# Twelve grazing parasites of one ball (the most that run near him) and the creatures.
	var pars := []
	var b: MossBall = null
	for bb in g.balls:
		var here := []
		for par in bb.parasites:
			if par.is_alive() and par.state == "graze":
				here.append(par)
		if here.size() > pars.size():
			pars = here.slice(0, 12)
			b = bb
	park_player_near(b, (pars[0] as Parasite).global_position, 10.0)
	await t.frames(2)
	var snaps := []
	for par in pars:
		snaps.append(par_full_snapshot(par))
	var us := {true: INF, false: INF}
	for rep in 3:
		for on in [false, true]:
			set_organic(on)
			for i in pars.size():
				par_full_restore(pars[i], snaps[i])
			var t1 := Time.get_ticks_usec()
			for f in 300:
				for par in pars:
					(par as Parasite)._physics_process(DT)
			us[on] = minf(us[on], float(Time.get_ticks_usec() - t1) / (300.0 * pars.size()))
	for i in pars.size():
		par_full_restore(pars[i], snaps[i])
	set_organic(true)
	var crit := []
	for c in g.ecosystem.all_critters():
		if (c is ReedStalker or c is Pufferfish or c is CrabGuardian or c is CaveEel) and crit.size() < 8:
			crit.append(c)
	var cs := []
	for c in crit:
		cs.append(_crit_snapshot(c))
	var cus := {true: INF, false: INF}
	for rep in 3:
		for on in [false, true]:
			set_organic(on)
			for i in crit.size():
				_crit_restore(crit[i], cs[i])
			var t2 := Time.get_ticks_usec()
			for f in 300:
				for c in crit:
					c.tick(DT)
			cus[on] = minf(cus[on], float(Time.get_ticks_usec() - t2) / (300.0 * crit.size()))
	for i in crit.size():
		_crit_restore(crit[i], cs[i])
	set_organic(true)
	t.check("organic_cost_bounded", per < 5.0 and us[true] - us[false] < 8.0 and cus[true] - cus[false] < 8.0,
			"layer %.2f us per creature per frame; grazing parasite %.1f us on, %.1f off (%d of them); critter %.1f us on, %.1f off (%d)" % [per, us[true], us[false], pars.size(), cus[true], cus[false], crit.size()])
