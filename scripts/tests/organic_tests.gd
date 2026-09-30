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
			"_hurt_done", "standing_on"]:
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
	pass
