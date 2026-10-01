extends RefCounted
## Repopulation (ledger row 11; spec docs/research/2026-09-30-DEVICE_AUDIT.md §D): returners and
## local food. Driven from unit_tests.gd (`_test_repopulation`, `_phase_repop_survey`,
## `_phase_repop_sim`).
##
## The logic checks use their own Repopulation / FoodDirector instances with explicit clocks, so a
## simulated hour costs a moment and never depends on the game's own timers (the game's repopulation
## is off in the unit suite).

var t
var g: Game
var p: Axolotl
var ut


func _init(p_ut) -> void:
	ut = p_ut
	t = ut.t
	g = ut.g
	p = ut.p


# --- helpers ---------------------------------------------------------------------------------

## A point no spot is near (far above the tank): every spot is "far from Gill".
func _nowhere() -> Vector3:
	return Vector3(0.0, 100000.0, 0.0)


func _fresh(key := "repop-test") -> Repopulation:
	var r := Repopulation.new(Repopulation.normal_rules())
	r.key = key
	r.build(g.balls, g.vortices)
	return r


func _zones_of(r: Repopulation, bi: int) -> Array:
	var out := []
	for k in r.zones:
		if int(r.zones[k]["ball"]) == bi:
			out.append(r.zones[k])
	return out


## Marks a zone cleared at `at` in this instance only (the world's parasites are untouched).
func _mark_cleared(z: Dictionary, at: float) -> void:
	z["cleared"] = at
	z["next"] = at + 300.0


## Removes every returner (tests clean up after themselves).
func _clear_returners() -> void:
	for b in g.balls:
		for rr in b.returners:
			if is_instance_valid(rr):
				rr.queue_free()
		b.returners.clear()
		b.returners_changed()


## A returner dies at once (no effects): what a kill leaves for the bookkeeping.
func _drop(rr: Parasite) -> void:
	rr.restore_cleared()


func _health_sig(b: MossBall) -> int:
	return hash(b.health_img.get_data()) if b.health_img != null else 0


## The ball with the most zones that can take returners.
func _busiest_ball(r: Repopulation) -> int:
	var best := 0
	var bn := -1
	for b in g.balls:
		var n := 0
		for z in _zones_of(r, b.index):
			if not (z["eligible"] as Array).is_empty():
				n += int(z["cap"])
		if n > bn:
			bn = n
			best = b.index
	return best


# --- survey ----------------------------------------------------------------------------------

func survey() -> void:
	var r := _fresh()
	var fd := FoodDirector.new()
	fd.setup("survey", g.balls)
	for b in g.balls:
		var caps := 0
		var zl: Array[String] = []
		for z in _zones_of(r, b.index):
			caps += int(z["cap"])
			zl.append("%s %d->cap %d (%d spots ok)" % [z["zone"], (z["authored"] as Array).size(), z["cap"], (z["eligible"] as Array).size()])
		var regs := fd.regions_of(b)
		var rl: Array[String] = []
		var tsum := 0
		for reg in regs:
			tsum += int(reg["target"])
			rl.append("%.0f°/%.0fm²->%d (%d holes)" % [reg["radius"], reg["area"], reg["target"], (reg["spots"] as Array).size()])
		t.log_line("SURVEY ball %d R %.0f m: parasites %d, zones %d, sum caps %d | food_target %d cap %d, regions %d sum targets %d, holes %d" % [b.index + 1, b.radius,
				b.parasites.size(), zl.size(), caps, b.food_target, FoodDirector.ball_cap(b), regs.size(), tsum, b.food_spots.size()])
		t.log_line("  zones: " + "; ".join(zl))
		t.log_line("  regions: " + "; ".join(rl))
		var off := 0.0
		for f in b.foods:
			if is_instance_valid(f) and f.type != Food.Type.BURROWER:
				off = maxf(off, absf(b.altitude(f.global_position)))
		t.log_line("  foods now %d, highest non-burrower altitude %.1f m" % [b.foods.size(), off])
	t.check("repop_survey", true, "")


# --- returners -------------------------------------------------------------------------------

func run_checks() -> void:
	var was: bool = g.repop.enabled
	g.repop.enabled = false
	await _no_ids_no_restoration_change()
	await _not_before_grace()
	await _caps()
	await _offscreen_and_far()
	await _saved_timers()
	await _food_local_targets_and_cooldown()
	await _food_rng_isolated()
	_clear_returners()
	g.repop.enabled = was


func _no_ids_no_restoration_change() -> void:
	var r := _fresh()
	var b := g.balls[_busiest_ball(r)]
	var z: Dictionary = {}
	for zz in _zones_of(r, b.index):
		if not (zz["eligible"] as Array).is_empty():
			z = zz
			break
	_mark_cleared(z, 0.0)
	var cat_before := g.completion.size()
	var ids_before := Completion.build_from_world(g.balls, g.vortices).order.duplicate()
	var rr := r.update(400.0, b, _nowhere(), null)
	t.check("repop_returner_arrives", rr != null, "zone %s" % z["zone"])
	if rr == null:
		return
	await t.frames(3)
	await t.seconds(2.0)
	var earned_before: Dictionary = g.run_save.earned().duplicate()
	var res := [b.restoration, b.events_done, b.completed, (b.zones[z["zone"]] as Dictionary).duplicate()]
	var hsig := _health_sig(b)
	var vort := g.vortices.map(func(v): return v.connected)
	var gates := b.gates.map(func(gt): return gt.is_open)
	var pct := g.completion_percent()
	var kills: int = g.stats["kills"]
	t.check("repop_returner_outside_catalog", not b.parasites.has(rr) and b.returners.has(rr) and rr.returner
			and str(rr.get_meta("completion_id", "x")) == "" and b.hostiles().has(rr), "")
	# Killed the way Gill kills (the game's own path).
	rr.state = "graze" if rr.state == "init" else rr.state
	rr.hit_cd = 0.0
	var died := rr.hit(rr.hp, rr.global_position + Vector3(0.5, 0, 0))
	await t.seconds(2.0)
	var ids_after := Completion.build_from_world(g.balls, g.vortices).order
	var same: bool = earned_before == g.run_save.earned() and is_equal_approx(b.restoration, res[0]) and b.events_done == res[1] and b.completed == res[2] \
			and b.zones[z["zone"]] == res[3] and _health_sig(b) == hsig and vort == g.vortices.map(func(v): return v.connected) \
			and gates == b.gates.map(func(gt): return gt.is_open) and is_equal_approx(pct, g.completion_percent()) and int(g.stats["kills"]) == kills
	t.check("repop_no_ids_no_restoration_change", died and same and ids_before == ids_after and g.completion.size() == cat_before,
			"killed %s; earned %d, restoration %.3f, events %d, health map %s, catalog %d ids unchanged" % [died, g.run_save.earned().size(), b.restoration, b.events_done,
			"same" if _health_sig(b) == hsig else "CHANGED", ids_after.size()])
	_clear_returners()


func _not_before_grace() -> void:
	var r := _fresh()
	var bi := _busiest_ball(r)
	var b := g.balls[bi]
	var z: Dictionary = {}
	for zz in _zones_of(r, bi):
		if not (zz["eligible"] as Array).is_empty():
			z = zz
			break
	# The zone is noticed as cleared when its last authored parasite is gone (here: the instance is
	# told so directly, at play second 1000).
	_mark_cleared(z, 1000.0)
	seed(4321)
	var expect := [randi(), randi()]
	seed(4321)
	var early := r.update(1299.5, b, _nowhere(), null)
	var on_time := r.update(1300.0, b, _nowhere(), null)
	var second_due := float(z["next"])
	# (Its first frame lays it on the ground; done here, synchronously, so no other system's draws
	# mix in: it draws only from its own generator.)
	if on_time != null and on_time.state == "init":
		on_time._init_on_ground()
	var got := [randi(), randi()]
	t.check("repop_not_before_grace", early == null and on_time != null and second_due >= 1300.0 + 240.0 and second_due <= 1300.0 + 420.0,
			"none at 299.5 s, one at 300 s; next due +%.0f s" % (second_due - 1300.0))
	# Timing hashes from (run, zone, n): the same run gives the same schedule, another run another.
	var r2 := _fresh()
	var r3 := _fresh("another-run")
	var z2: Dictionary = r2.zones[Repopulation.zone_key(bi, z["zone"])]
	var z3: Dictionary = r3.zones[Repopulation.zone_key(bi, z["zone"])]
	var same := true
	var differ := false
	var lo := INF
	var hi := 0.0
	for n in 40:
		same = same and is_equal_approx(r2.interval(z2, n), r.interval(z, n))
		differ = differ or not is_equal_approx(r3.interval(z3, n), r.interval(z, n))
		lo = minf(lo, r.interval(z, n))
		hi = maxf(hi, r.interval(z, n))
	t.check("repop_timing_hashed_no_global_rng", same and differ and lo >= 240.0 and hi <= 420.0 and got == expect,
			"intervals %.0f..%.0f s over 40; global sequence untouched %s" % [lo, hi, got == expect])
	_clear_returners()


func _caps() -> void:
	var r := _fresh()
	r.rules.spacing_s = 0.0
	var formula := true
	for z in r.zones.values():
		formula = formula and int(z["cap"]) == ceili(0.34 * (z["authored"] as Array).size())
	var worst_zone := 0
	var worst_ball := 0
	var report: Array[String] = []
	var mix_ok := true
	var gaps_ok := true
	var min_gap := INF
	var species := {}
	for b in g.balls:
		for z in _zones_of(r, b.index):
			_mark_cleared(z, 0.0)
		var expect := 0
		for z in _zones_of(r, b.index):
			if not (z["eligible"] as Array).is_empty():
				expect += int(z["cap"])
		expect = mini(expect, r.rules.ball_cap)
		var peak := 0
		var last_t := {}
		var now := 300.0
		# 1) Nobody is killed: they build up to the caps and stop.
		while now < 6000.0:
			r.update(now, b, _nowhere(), null)
			for z in _zones_of(r, b.index):
				worst_zone = maxi(worst_zone, r.alive_in_zone(z) - int(z["cap"]))
			peak = maxi(peak, r.alive_on_ball(b))
			now += 20.0
		worst_ball = maxi(worst_ball, peak)
		for rr in b.returners:
			if is_instance_valid(rr) and rr.is_alive():
				_drop(rr)
		# 2) Each one killed as soon as it arrives: the pace and the mix.
		var arrived := 0
		while now < 20000.0:
			var rr := r.update(now, b, _nowhere(), null)
			if rr != null:
				arrived += 1
				var k := Repopulation.zone_key(b.index, rr.zone_id)
				var z: Dictionary = r.zones[k]
				if last_t.has(k):
					min_gap = minf(min_gap, now - float(last_t[k]))
					gaps_ok = gaps_ok and now - float(last_t[k]) >= r.rules.every_min_s - 0.001
				last_t[k] = now
				var sk := "%d%s" % [rr.kind, rr.variant]
				if not species.has(k):
					species[k] = {}
				species[k][sk] = int(species[k].get(sk, 0)) + 1
				var authored_kinds := {}
				for q in z["eligible"]:
					authored_kinds["%d%s" % [q.kind, q.variant]] = true
				mix_ok = mix_ok and authored_kinds.has(sk)
				r.on_killed(rr, now)
				_drop(rr)
			now += 20.0
		report.append("b%d peak %d/%d, %d arrivals" % [b.index + 1, peak, expect, arrived])
		mix_ok = mix_ok and peak == expect
		_clear_returners()
		await t.frames(1)
	# The mix: every species a zone holds turns up among its returners (zones with plenty of arrivals).
	var missing: Array[String] = []
	for k in species:
		var z: Dictionary = r.zones[k]
		var total := 0
		for sk in species[k]:
			total += int(species[k][sk])
		for q in z["eligible"]:
			if total >= 20 and not (species[k] as Dictionary).has("%d%s" % [q.kind, q.variant]):
				missing.append("%s %d%s" % [k, q.kind, q.variant])
	mix_ok = mix_ok and missing.is_empty()
	t.check("repop_caps", formula and worst_zone <= 0 and worst_ball <= r.rules.ball_cap and mix_ok and gaps_ok,
			"zone cap ceil(0.34 x authored) %s; never over a zone cap (worst %+d) or %d per ball; authored species only; min gap %.0f s; %s" % [formula, worst_zone,
			r.rules.ball_cap, min_gap, ", ".join(report)])


func _offscreen_and_far() -> void:
	# Static: no spot that may take a returner is near a bloom or a vortex mouth.
	var r := _fresh()
	var near := []
	var excluded := 0
	for z in r.zones.values():
		var b := g.balls[z["ball"]]
		excluded += (z["authored"] as Array).size() - (z["eligible"] as Array).size()
		for q in z["eligible"]:
			var at := Repopulation.spot_of(b, q)
			for bl in b.blooms:
				if at.distance_to(b.surface_point(bl.dir, bl.h_hint)) < 20.0:
					near.append("%s bloom" % z["zone"])
			for v in g.vortices:
				for m in ([b.surface_point(v.dir_a)] if v.ball_a == b else []) + ([b.surface_point(v.dir_b)] if v.ball_b == b else []):
					if at.distance_to(m) < 12.0:
						near.append("%s vortex" % z["zone"])
	# Live: Gill stands at spots round each ball; every zone is due; whatever arrives is far and unseen.
	r.rules.spacing_s = 0.0
	var arrivals := 0
	var bad: Array[String] = []
	var min_d := INF
	var now := 10000.0
	for b in g.balls:
		for z in _zones_of(r, b.index):
			_mark_cleared(z, 0.0)
		for k in 6:
			var d := MossBall.dir_ll(-50.0 + 20.0 * k, 60.0 * k + 15.0 * b.index)
			p.place(b, b.surface_point(d, 0.2), -MossBall.frame_at(d, 70.0 * k).z)
			p.velocity = Vector3.ZERO
			g.cam.snap_behind()
			await t.frames(2)
			for z in _zones_of(r, b.index):
				z["next"] = 0.0
			for i in 12:
				var rr := r.update(now, b, p.global_position, g.cam)
				now += 30.0
				if rr == null:
					continue
				arrivals += 1
				var e: Dictionary = r.arrivals[r.arrivals.size() - 1]
				min_d = minf(min_d, float(e["dist"]))
				if float(e["dist"]) < 35.0 or bool(e["on_camera"]) or g.cam.is_position_in_frustum(rr.global_position):
					bad.append("b%d %s %.1f m%s" % [b.index + 1, e["zone"], e["dist"], " ON CAMERA" if e["on_camera"] else ""])
				_drop(rr)
		_clear_returners()
	ut.place(0, -12, -130, 0.1, 90)
	t.check("repop_offscreen_and_far", arrivals > 20 and bad.is_empty() and near.is_empty(),
			"%d arrivals with Gill at 6 spots on each of 7 balls, nearest %.1f m, none on camera; %d authored spots excluded (bloom 20 m / vortex 12 m) %s %s" % [arrivals, min_d,
			excluded, ", ".join(bad), ", ".join(near)])


func _saved_timers() -> void:
	var r: Repopulation = g.repop
	var keys := r.zones.keys()
	keys.sort()
	var picked := keys.slice(0, 3)
	var before := {}
	for i in picked.size():
		var z: Dictionary = r.zones[picked[i]]
		z["cleared"] = 100.0 + i
		z["next"] = 400.0 + i * 7.5
		z["n"] = i + 2
		before[picked[i]] = [z["cleared"], z["next"], z["n"]]
	g.save_run()
	var raw := FileAccess.get_file_as_string(g.run_save.path)
	var data: Dictionary = JSON.parse_string(raw) if raw != "" else {}
	var world: Dictionary = data.get("run", {}).get("world", {})
	var saved: Dictionary = world.get("repop", {})
	var r2 := _fresh(r.key)
	r2.from_dict(saved)
	var back := true
	for k in picked:
		var z: Dictionary = r2.zones[k]
		back = back and is_equal_approx(float(z["cleared"]), before[k][0]) and is_equal_approx(float(z["next"]), before[k][1]) and int(z["n"]) == before[k][2]
	# Untouched zones stay uncleared; a newer format is left alone; nothing else in the save moved.
	var untouched := true
	for k in r2.zones:
		if not picked.has(k):
			untouched = untouched and float(r2.zones[k]["cleared"]) < 0.0
	var r3 := _fresh(r.key)
	r3.from_dict({"format": Repopulation.FORMAT + 1, "zones": saved.get("zones", {})})
	var newer_ignored := true
	for k in picked:
		newer_ignored = newer_ignored and float(r3.zones[k]["cleared"]) < 0.0
	var additive := int(data.get("format", -1)) == RunSave.FORMAT and RunSave.FORMAT == 1 and world.has("stats") and world.has("checkpoint") \
			and int(saved.get("format", 0)) == 1 and (saved.get("zones", {}) as Dictionary).size() == picked.size()
	t.check("repop_saved_timers", back and untouched and newer_ignored and additive,
			"run[\"world\"][\"repop\"] format %d, %d zones round-trip %s; run save format %d" % [int(saved.get("format", 0)), (saved.get("zones", {}) as Dictionary).size(), back, int(data.get("format", -1))])
	for k in picked:
		r.zones[k]["cleared"] = -1.0
		r.zones[k]["next"] = -1.0
		r.zones[k]["n"] = 0
	g.save_run()


# --- food ------------------------------------------------------------------------------------

## A ball Gill is not on (the game's own food runs only on his), with the most regions.
func _food_ball() -> MossBall:
	var best: MossBall = null
	for b in g.balls:
		if b == p.ball:
			continue
		if best == null or b.food_regions.size() > best.food_regions.size():
			best = b
	return best


func _empty_food(b: MossBall) -> void:
	for f in b.foods:
		if is_instance_valid(f):
			if f.type == Food.Type.BURROWER:
				f.hole["occupied"] = false
			f.queue_free()
	b.foods.clear()


func _food_local_targets_and_cooldown() -> void:
	var b := _food_ball()
	_empty_food(b)
	var fd := FoodDirector.new()
	fd.setup("food-test", g.balls)
	var regs := fd.regions_of(b)
	var formula := true
	for reg in regs:
		formula = formula and int(reg["target"]) == clampi(roundi(float(reg["area"]) / 250.0), 1, 4)
	var gp := b.surface_point(regs[0]["dir"], 0.3)
	var local := []
	var want := 0
	for ri in regs.size():
		if fd.is_local(b, regs[ri], gp):
			local.append(ri)
			want += int(regs[ri]["target"])
	var cap := FoodDirector.ball_cap(b)
	var over_cap := false
	for s in 600:
		fd.update(1.0, b, gp, null)
		over_cap = over_cap or b.foods.size() > cap
	var counts := []
	var at_target := true
	var far_quiet := true
	for ri in regs.size():
		var c := fd.count_in(b, ri)
		counts.append(c)
		if local.has(ri):
			at_target = at_target and (c == int(regs[ri]["target"]) or b.foods.size() >= cap)
		else:
			far_quiet = far_quiet and c == 0
	var min_gap := INF
	var last := {}
	var hidden := true
	for e in fd.arrivals:
		var ri: int = e["region"]
		if last.has(ri):
			min_gap = minf(min_gap, float(e["t"]) - float(last[ri]))
		last[ri] = e["t"]
		hidden = hidden and float(e["dist"]) >= FoodDirector.ARRIVE_MIN_M and (e["type"] == Food.Type.BURROWER or float(e["alt"]) >= 6.5)
	# Eating one: its region rests 45..90 s before the next arrives.
	var full := -1
	for ri in local:
		if fd.count_in(b, ri) > 0 and full < 0:
			full = ri
	var eaten_ok := true
	var refill_s := -1.0
	if full >= 0:
		var victim: Food = null
		for f in b.foods:
			if is_instance_valid(f) and f.region == full:
				victim = f
		var t_eat := fd.t
		b.foods.erase(victim)
		fd.on_eaten(victim)
		victim.eaten()
		var n0 := fd.arrivals.size()
		for s in 120:
			fd.update(1.0, b, gp, null)
			if refill_s < 0.0:
				for k in range(n0, fd.arrivals.size()):
					if int(fd.arrivals[k]["region"]) == full:
						refill_s = float(fd.arrivals[k]["t"]) - t_eat
		eaten_ok = refill_s >= FoodDirector.COOLDOWN_MIN - 1.0 and refill_s <= FoodDirector.COOLDOWN_MAX + 1.5
	t.check("food_local_targets_and_cooldown", formula and at_target and far_quiet and not over_cap and min_gap >= FoodDirector.COOLDOWN_MIN - 0.001 and hidden and eaten_ok,
			"ball %d: %d regions (%d local, local target %d, cap %d), counts %s; arrivals %d, min gap in a region %.0f s, from above and >= %.0f m away %s; eaten one refilled after %.0f s" % [b.index + 1,
			regs.size(), local.size(), want, cap, str(counts), fd.arrivals.size(), min_gap, FoodDirector.ARRIVE_MIN_M, hidden, refill_s])
	_empty_food(b)
	g.food.initial(b)


func _food_rng_isolated() -> void:
	var b := _food_ball()
	var runs := []
	for key in ["iso-a", "iso-a", "iso-b"]:
		_empty_food(b)
		await t.frames(1)
		seed(2468)
		var expect := [randi(), randi(), randi()]
		seed(2468)
		var fd := FoodDirector.new()
		fd.setup(key, g.balls)
		fd.initial(b)
		var gp := b.surface_point(fd.regions_of(b)[0]["dir"], 0.3)
		for s in 400:
			fd.update(1.0, b, gp, null)
		var got := [randi(), randi(), randi()]
		var sig: Array = []
		for f in b.foods:
			sig.append("%d %d %s %.4f" % [f.type, f.region, str(f.global_position.snapped(Vector3.ONE * 0.001)), f._hover])
		runs.append([got == expect, sig])
	t.check("food_rng_isolated", runs[0][0] and runs[1][0] and runs[2][0] and runs[0][1] == runs[1][1] and runs[0][1] != runs[2][1],
			"global sequence untouched %s; same run same food %s; another run other food %s (%d organisms)" % [runs[0][0] and runs[1][0] and runs[2][0],
			runs[0][1] == runs[1][1], runs[0][1] != runs[2][1], (runs[0][1] as Array).size()])
	_empty_food(b)
	g.food.initial(b)


# --- the long simulation ------------------------------------------------------------------------

func sim() -> void:
	t.check("repop_sim", false, "not written yet")
