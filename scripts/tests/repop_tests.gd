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
	t.log_line("SURVEY cap table (n: zones, cap, share): " + _cap_table(r))
	for radius in [20.0, 11.0]:
		var rr := Repopulation.new(Repopulation.normal_rules())
		rr.rules.bloom_clear_m = radius
		rr.key = "survey"
		rr.build(g.balls, g.vortices)
		var per: Array[String] = []
		var tot := 0
		var excl := 0
		var bloom_excl := 0
		for b in g.balls:
			var ok := 0
			var zs := _zones_of(rr, b.index)
			for z in zs:
				if not (z["eligible"] as Array).is_empty():
					ok += 1
				excl += (z["authored"] as Array).size() - (z["eligible"] as Array).size()
				for q in z["authored"]:
					var at := Repopulation.spot_of(b, q)
					for bl in b.blooms:
						if at.distance_to(b.surface_point(bl.dir, bl.h_hint)) < radius:
							bloom_excl += 1
							break
			tot += ok
			per.append("b%d %d/%d" % [b.index + 1, ok, zs.size()])
		t.log_line("SURVEY bloom %.0f m: eligible zones %s = %d of %d; spots excluded %d (by a bloom %d)" % [radius, ", ".join(per), tot, rr.zones.size(), excl, bloom_excl])
	t.check("repop_survey", true, "")


# --- returners -------------------------------------------------------------------------------

func run_checks() -> void:
	var was: bool = g.repop.enabled
	g.repop.enabled = false
	await _no_ids_no_restoration_change()
	await _not_before_grace()
	await _caps()
	await _offscreen_and_far()
	_bloom_buffer()
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
		var n := (z["authored"] as Array).size()
		# max(1, round(n / 3)), and never far over a third except where it can only be one.
		formula = formula and int(z["cap"]) == maxi(1, roundi(n / 3.0)) and (n <= 2 or float(z["cap"]) / n <= 0.4) and int(z["cap"]) >= 1
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
			"zone cap max(1, round(n/3)) on every real size, <= 40%% above n=2: %s; sizes %s; never over a zone cap (worst %+d) or %d per ball; authored species only; min gap %.0f s; %s" % [formula, _cap_table(r), worst_zone,
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
				if at.distance_to(b.surface_point(bl.dir, bl.h_hint)) < r.rules.bloom_clear_m:
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
			"%d arrivals with Gill at 6 spots on each of 7 balls, nearest %.1f m, none on camera; %d authored spots excluded (bloom %.0f m / vortex 12 m) %s %s" % [arrivals, min_d,
			excluded, r.rules.bloom_clear_m, ", ".join(bad), ", ".join(near)])


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

## Every ball restored (as a finished run continues), then on each ball in turn: Gill roams for
## --minutes=N of game frames (default 5) while the returners' clock runs --speed=K times faster
## (default 12, so 5 minutes of frames are an hour of repopulation). Checked: returner timing
## (none before the grace, gaps >= the minimum), caps, distance and camera at every arrival (no
## pop-in), kills earning nothing; food healthy near him when he leaves it alone and bounded by
## the cooldowns when he eats everything he can reach (no exploit); the cost of both systems.
func sim() -> void:
	var minutes := float(Settings.test_args.get("minutes", "5"))
	var speed := float(Settings.test_args.get("speed", "12"))
	g.repop.enabled = false
	var r := _fresh(g.rng_key())
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	# Restore the whole aquarium silently (as _apply_run does for a finished run).
	for b in g.balls:
		for par in b.parasites:
			if par.is_alive():
				par.restore_cleared()
				b.restore_event(par.zone_id, b.surface_point(par.spawn_dir))
		for m in b.motes:
			if m.state != "done":
				m.restore_done()
				b.restore_event(m.zone_id, b.surface_point(m.home_dir()))
	var restored := g.balls.all(func(b): return b.completed)
	var earned0: Dictionary = g.run_save.earned().duplicate()
	var res0 := g.balls.map(func(b): return [b.events_done, b.restoration])
	p.invuln_t = 1e9
	var now := 0.0
	var frames_per_ball := int(minutes * 60.0 * 60.0)
	var problems: Array[String] = []
	var lines: Array[String] = []
	var kills := 0
	var us_repop := 0
	var n_repop := 0
	var us_food := 0
	var phys_with: Array[float] = []
	var phys_without: Array[float] = []
	var total_arrivals := 0
	var food_on_cam := 0
	var food_near_min := 999
	var food_mean_min := 999.0
	var food_zero := 0
	var fill_min := 1.0
	var fill_lines: Array[String] = []
	var food_samples := 0
	var exploit_lines: Array[String] = []
	for b in g.balls:
		var d0 := b.start_dir
		p.place(b, b.surface_point(d0, 0.2), -MossBall.frame_at(d0, 0.0).z)
		g.audio.set_ball(b.index, false)
		g.cam.snap_behind()
		var a0 := r.arrivals.size()
		var f0 := g.food.arrivals.size()
		var peak := 0
		var zone_peak := 0
		var near_sum := 0
		var near_n := 0
		var near_min := 999
		var near_zero := 0
		var fill_sum := 0.0
		var ball_min := 999
		var eaten := 0
		var eat_from := frames_per_ball / 2
		var near_at_eat := 0
		var heading_t := 0.0
		var t_ball0 := now
		for fr in frames_per_ball:
			# Roaming: walk, turning now and then; a fresh spot every 90 s.
			heading_t -= 1.0 / 60.0
			if heading_t <= 0.0:
				heading_t = rng.randf_range(3.0, 9.0)
				var a := rng.randf_range(-PI, PI)
				p.bot_input = Vector2(sin(a), cos(a)) * 0.8
			if fr % (90 * 60) == 0 and fr > 0:
				var dd := MossBall.dir_ll(rng.randf_range(-60.0, 60.0), rng.randf_range(-180.0, 180.0))
				p.place(b, b.surface_point(dd, 0.3), -MossBall.frame_at(dd, rng.randf() * 360.0).z)
				g.cam.snap_behind()
			await t.frames(1)
			var pt: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			var alive := r.alive_on_ball(b)
			if alive > 0:
				phys_with.append(pt)
			else:
				phys_without.append(pt)
			if fr % 30 == 0:
				now += 0.5 * speed
				var u0 := Time.get_ticks_usec()
				var rr := r.update(now, b, p.global_position, g.cam)
				us_repop += Time.get_ticks_usec() - u0
				n_repop += 1
				if rr != null:
					var e: Dictionary = r.arrivals[r.arrivals.size() - 1]
					if float(e["dist"]) < 35.0 or bool(e["on_camera"]):
						problems.append("b%d %s arrived %.1f m away%s" % [b.index + 1, e["zone"], e["dist"], " in view" if e["on_camera"] else ""])
				peak = maxi(peak, r.alive_on_ball(b))
				for z in _zones_of(r, b.index):
					zone_peak = maxi(zone_peak, r.alive_in_zone(z) - int(z["cap"]))
				# He fights back: a returner that reaches him is killed (the game's own path).
				for q in b.returners:
					if is_instance_valid(q) and q.is_alive() and q.state not in ["init", "dying"] and q.global_position.distance_to(p.global_position) < 3.0:
						q.hit_cd = 0.0
						if q.hit(q.hp, p.global_position):
							kills += 1
			# Food health: sampled when he has been where he is for a minute (arrivals keep their
			# cooldowns, so a place he just reached fills over the next minute or two).
			if fr % 300 == 0 and fr % (90 * 60) >= 60 * 60:
				var near := 0
				for f in b.foods:
					if is_instance_valid(f) and f.global_position.distance_to(p.global_position) < 55.0:
						near += 1
				var any_local := false
				var want := 0
				var have := 0
				var regs := g.food.regions_of(b)
				for ri in regs.size():
					if g.food.is_local(b, regs[ri], p.global_position):
						any_local = true
						want += int(regs[ri]["target"])
						have += mini(g.food.count_in(b, ri), int(regs[ri]["target"]))
				if fr < eat_from and any_local:
					fill_sum += float(have) / maxf(1.0, want)
					ball_min = mini(ball_min, b.foods.filter(func(f): return is_instance_valid(f)).size())
					near_sum += near
					near_n += 1
					near_min = mini(near_min, near)
					if near == 0:
						near_zero += 1
			# Second half: he eats everything he can get to, at once (the exploit attempt).
			if fr == eat_from:
				for f in b.foods:
					if is_instance_valid(f) and f.global_position.distance_to(p.global_position) < 80.0:
						near_at_eat += 1
			if fr >= eat_from and fr % 120 == 0:
				for f in b.foods.duplicate():
					if is_instance_valid(f) and f.is_catchable() and f.catch_point().distance_to(p.global_position) < 25.0:
						g._eat(p, f)
						eaten += 1
		var arrivals := r.arrivals.slice(a0)
		total_arrivals += arrivals.size()
		# Timing: per zone, the first after the grace, then gaps of at least the minimum.
		var last := {}
		for e in arrivals:
			var k := Repopulation.zone_key(b.index, e["zone"])
			var z: Dictionary = r.zones[k]
			if not last.has(k) and float(e["t"]) - float(z["cleared"]) < r.rules.grace_s - 0.01:
				problems.append("%s first return %.0f s after clearing" % [k, float(e["t"]) - float(z["cleared"])])
			if last.has(k) and float(e["t"]) - float(last[k]) < r.rules.every_min_s - 0.01:
				problems.append("%s returns %.0f s apart" % [k, float(e["t"]) - float(last[k])])
			last[k] = e["t"]
		if peak > r.rules.ball_cap or zone_peak > 0:
			problems.append("b%d over a cap (ball peak %d, zone over by %d)" % [b.index + 1, peak, zone_peak])
		var foods := g.food.arrivals.slice(f0)
		for e in foods:
			if bool(e["on_camera"]) or float(e["dist"]) < FoodDirector.ARRIVE_MIN_M:
				food_on_cam += 1
		var eat_min := (frames_per_ball - eat_from) / 3600.0
		var local := 0
		for reg in g.food.regions_of(b):
			if g.food.is_local(b, reg, p.global_position):
				local += 1
		food_near_min = mini(food_near_min, near_min)
		food_mean_min = minf(food_mean_min, float(near_sum) / maxf(1.0, near_n))
		var fill := fill_sum / maxf(1.0, near_n)
		# (Where a ball's region targets add up past its cap, the cap shares the food out: that
		# fraction is the most any place can hold.)
		var tsum := 0
		for reg in g.food.regions_of(b):
			tsum += int(reg["target"])
		var ceiling := minf(1.0, float(FoodDirector.ball_cap(b)) / maxf(1.0, tsum))
		fill_min = minf(fill_min, fill / ceiling)
		fill_lines.append("b%d fill %.0f%% of %.0f%% possible, ball >= %d (old fixed target %d)" % [b.index + 1, fill * 100.0, ceiling * 100.0, ball_min, b.food_target])
		food_zero += near_zero
		food_samples += near_n
		# No exploit: what he can eat is what was there plus one per region per cooldown at most
		# (the old refill brought one every 1-2.5 s wherever he was).
		var bound := near_at_eat + g.food.regions_of(b).size() * ceili(eat_min * 60.0 / FoodDirector.COOLDOWN_MIN) + 2
		if eaten > bound:
			problems.append("b%d: ate %d, over the cooldown bound %d" % [b.index + 1, eaten, bound])
		exploit_lines.append("%d<=%d" % [eaten, bound])
		lines.append("b%d: %.0f min of returns, %d returners (peak %d alive, firsts %s), food near him mean %.1f min %d, ate %d in %.1f min (%.1f/min), %d food arrivals" % [b.index + 1,
				(now - t_ball0) / 60.0, arrivals.size(), peak, ",".join(arrivals.slice(0, 3).map(func(e): return "%.0f" % (float(e["t"]) - t_ball0))),
				float(near_sum) / maxf(1.0, near_n), near_min, eaten, eat_min, eaten / maxf(0.01, eat_min), foods.size()])
		t.log_line("SIM " + lines[lines.size() - 1])
		# (He leaves the ball: its returners stay and sleep, as parasites on other balls do.)
	p.bot_input = Vector2.ZERO
	var earned_ok := true
	for id in g.run_save.earned():
		if not earned0.has(id) and (str(id).contains(".parasite") or str(id).contains(".mote")):
			earned_ok = false
	var res_ok := g.balls.map(func(b): return [b.events_done, b.restoration]) == res0
	t.log_line("SIM cost: repopulation update %.1f us per look (%d looks); median physics frame %.2f ms with returners alive (%d frames), %.2f ms without (%d)" % [float(us_repop) / maxi(1, n_repop), n_repop,
			_median(phys_with), phys_with.size(), _median(phys_without), phys_without.size()])
	t.log_line("SIM " + r.summary() + "; %d killed by him" % kills)
	t.check("repop_sim_returners", restored and total_arrivals > 0 and problems.is_empty(), "%d arrivals over 7 balls; %s" % [total_arrivals, "; ".join(problems.slice(0, 6))])
	t.check("repop_sim_no_restoration_change", earned_ok and res_ok and kills > 0, "%d returners killed; restoration and earned ids unchanged %s" % [kills, earned_ok and res_ok])
	# Healthy: the regions round him are kept near their targets (how much is within 55 m depends on
	# where food regions are authored; the ball totals are reported beside the old fixed targets).
	t.check("repop_sim_food_healthy", food_on_cam == 0 and fill_min >= 0.75 and problems.is_empty(),
			"local regions filled (lowest per-ball mean, of what the cap allows) %.0f%% [%s]; food within 55 m: lowest per-ball mean %.1f, %d of %d samples empty, min %d; %d arrivals in view or too close; eaten vs bound per ball %s" % [fill_min * 100.0, ", ".join(fill_lines), food_mean_min,
			food_zero, food_samples, food_near_min, food_on_cam, ", ".join(exploit_lines)])
	_clear_returners()


static func _median(a: Array[float]) -> float:
	if a.is_empty():
		return 0.0
	var c := a.duplicate()
	c.sort()
	return c[c.size() / 2]


## "n=1: 30 zones -> 1 (100%), ..." over the real authored zone sizes.
func _cap_table(r: Repopulation) -> String:
	var by := {}
	for z in r.zones.values():
		var n := (z["authored"] as Array).size()
		by[n] = int(by.get(n, 0)) + 1
	var ns := by.keys()
	ns.sort()
	var out: Array[String] = []
	for n in ns:
		var c := r.rules.cap_for(n)
		out.append("n=%d: %d zones -> %d (%.0f%%)" % [n, by[n], c, 100.0 * c / n])
	return ", ".join(out)


## Every spot a returner may use is clear of every checkpoint bloom as it settled, and of the point
## Gill re-forms at: past every notice range and the bloom's startle radius.
func _bloom_buffer() -> void:
	var r := _fresh()
	var worst := INF
	var worst_rp := INF
	var bad: Array[String] = []
	var checked := 0
	for z in r.zones.values():
		var b := g.balls[z["ball"]]
		for q in z["eligible"]:
			var at := Repopulation.spot_of(b, q)
			for bl in b.blooms:
				var bp: Vector3 = bl.global_position if bl.is_placed() else b.surface_point(bl.dir, bl.h_hint)
				var d_auth := at.distance_to(b.surface_point(bl.dir, bl.h_hint))
				var d_bl := at.distance_to(bp)
				var d_rp := at.distance_to(bl.respawn_point()) if bl.is_placed() else d_bl - 0.9
				checked += 1
				worst = minf(worst, d_bl)
				worst_rp = minf(worst_rp, d_rp)
				if d_auth < r.rules.bloom_clear_m or d_bl < r.rules.bloom_clear_m or d_rp < r.rules.bloom_clear_m or not bl.is_placed():
					bad.append("b%d %s %.1f m (re-form point %.1f m)" % [b.index + 1, z["zone"], d_bl, d_rp])
	t.check("repop_bloom_buffer", r.blooms_settled and r.rules.bloom_clear_m >= 11.0 and bad.is_empty() and checked > 0,
			"%d spot-bloom pairs: every spot >= %.0f m from every bloom as authored and as settled (nearest %.1f m), and from where he re-forms (nearest %.1f m) (startle radius %.0f m, widest notice 9 m) %s" % [checked,
			r.rules.bloom_clear_m, worst, worst_rp, Parasite.STARTLE_R, ", ".join(bad)])
