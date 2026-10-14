extends RefCounted
## Hard Mode (ledger row 12; spec docs/research/2026-09-30-DEVICE_AUDIT.md §E, §E2 and the final ruling,
## option (b)). Driven from unit_tests.gd (`_test_hard_mode`, `_test_hard_mode_save`, `_phase_hard_*`)
## and shots.gd (`--only=hard`).
##
## Isolation: the unit suite's own run is Normal and stays Normal. The model checks use their own
## HardMode instances over plain data with explicit clocks (no world state, no timers); the checks that
## draw on the real world clean up after themselves (MossBall.clear_vitality, Vortex.clear_distress);
## everything that needs a real Hard run happens in fresh child processes.

var t
var g: Game
var ut


func _init(p_t, p_g: Game, p_ut = null) -> void:
	t = p_t
	g = p_g
	ut = p_ut


# --- A small data world ------------------------------------------------------------------------

## Three balls of four (ball 1: two) equal zones. Ball 0 zone a..d: 4 small parasites each (cap 2);
## ball 1: two zones of four large (cap 2, L 6 at the cap); ball 2: four zones of 2 medium.
func _layout(done_frac := 0.0) -> Array:
	var out := []
	var specs := [[4, [1, 1, 1, 1]], [2, [3, 3, 3, 3]], [4, [2, 2]]]
	for s in specs:
		var bl := []
		for i in int(s[0]):
			var total := 8
			bl.append({"zone": "z%d" % i, "area": 1.0, "weights": s[1], "total": total, "done": roundi(total * done_frac), "bloom": false})
		out.append(bl)
	return out


## A model over `layout` with loads from `loads` (zone key -> L), every zone cleared.
func _model(layout: Array, loads: Dictionary, key := "hard-test") -> HardMode:
	var m := HardMode.new()
	m.key = key
	m.build_data(layout)
	m.load_fn = func(zk: String) -> float: return float(loads.get(zk, 0.0))
	m.cleared_fn = func(_zk: String) -> bool: return true
	return m


## Ticks from `t0` to `t1` (s) at the game's rate; `each` is called after every tick.
func _run(m: HardMode, t0: float, t1: float, cur: int, each := Callable()) -> float:
	var now := t0
	while now < t1 - 1e-9:
		now = minf(t1, now + HardMode.TICK_S)
		m.tick(now, cur)
		if each.is_valid():
			each.call(now)
	return now


func _near(a: float, b: float, eps := 1e-4) -> bool:
	return absf(a - b) <= eps


# --- In-process checks ---------------------------------------------------------------------------

func run_checks() -> void:
	_normal_untouched()
	_old_save_is_normal()
	_records()
	_dialog()
	_decay_rate()
	_max_two_losing()
	_floors_hold()
	_kill_and_mote()
	_other_ball_frozen()
	_no_decay_while_closed()
	_incursions()
	_incursion_fairness_timing()
	_distress_levels()
	_derived_on_load()
	_rng_isolated()
	_returner_rules()
	await _world_vitality()
	await _world_distress()
	_hue_kept()


## Normal (every existing test's run): nothing of Hard Mode exists or is drawn.
func _normal_untouched() -> void:
	var drawn := false
	for b in g.balls:
		drawn = drawn or b.vitality_img != null
		for mat in b.field_materials:
			drawn = drawn or mat.get_shader_parameter("vitality_on") == true
	var vort := false
	for v in g.vortices:
		vort = vort or v._distress_on
	var world := g._capture_world()
	t.check("hard_mode_saved_and_default_normal", g.hard == null and not g.is_hard() and not g.run_save.run().has("mode") and not (g.repop.rules is HardMode.HardRules)
			and not world.has("vitality") and not drawn and not vort and not g.hud.vitality_bar.visible,
			"hard %s, mode key %s, vitality saved %s, drawn %s, vortex distress %s, bar %s" % [g.hard != null, g.run_save.run().has("mode"), world.has("vitality"), drawn, vort, g.hud.vitality_bar.visible])
	t.check("hard_hud_normal_hidden", not g.hud.vitality_bar.visible and not g.hud.vitality_bar.want, "")
	t.check("hard_distress_none_in_normal", not vort, "")
	# Normal returner timing is the same formula as before Hard Mode (scale 1, no gate, nothing owed).
	var r := Repopulation.new(Repopulation.normal_rules())
	r.key = "normal-check"
	r.build(g.balls, g.vortices)
	var same := true
	for z in r.zones.values():
		for n in 5:
			var want := lerpf(240.0, 420.0, Repopulation.unit(["normal-check", z["ball"], z["zone"], n, "every"]))
			same = same and r.interval(z, n) == want and r.rules.allows(z) and not z.has("owed")
	var d := r.to_dict()
	t.check("hard_normal_repop_unchanged", same and r.rules.interval_scale() == 1.0 and r.rules.cap_for(3) == 1 and r.rules.cap_for(8) == 3
			and r.rules.ball_cap == 6 and r.rules.bloom_clear_m == 11.0, str(d))


## A save without a mode (every save before Hard Mode, and every Normal run) is Normal; a Hard run's
## mode survives migration; the run format stays 1.
func _old_save_is_normal() -> void:
	var path := "user://hard_old_save.json"
	RunSave.erase(path)
	var rs := RunSave.open(path)
	rs.save()
	var old := RunSave.open(path)
	var hard_data := RunSave.new_data({})
	hard_data["run"]["mode"] = "hard"
	var migrated := RunSave.migrate(hard_data)
	t.check("hard_old_save_is_normal", not old.run().has("mode") and str(old.run().get("mode", "normal")) == "normal" and RunSave.FORMAT == 1
			and str(migrated["run"].get("mode", "")) == "hard" and not RunSave.new_run().has("mode"), old.origin)
	RunSave.erase(path)


## Finishes: Normal records exactly as before (no mode key, its own best); Hard records carry the mode
## and keep their best apart.
func _records() -> void:
	var path := "user://hard_records.json"
	RunSave.erase(path)
	var rs := RunSave.open(path)
	rs.record_finish(500.0, 100.0, Completion.CATALOG_VERSION, {}, 3)
	var normal_keys: Array = (rs.records()["finishes"][0] as Dictionary).keys()
	var normal_ok: bool = not normal_keys.has("mode") and float(rs.records()["best_finish_s"]) == 500.0 and not rs.records().has("best_finish_s_hard") \
			and not (rs.run()["finish"] as Dictionary).has("mode")
	rs.start_new_run()
	rs.run()["mode"] = "hard"
	rs.record_finish(400.0, 100.0, Completion.CATALOG_VERSION, {}, 5, "hard")
	var rec := rs.records()
	var hard_ok: bool = float(rec["best_finish_s"]) == 500.0 and float(rec["best_finish_s_hard"]) == 400.0 and str(rec["finishes"][1]["mode"]) == "hard" \
			and str(rs.run()["finish"]["mode"]) == "hard"
	t.check("hard_records_carry_mode", normal_ok and hard_ok, str(rec))
	RunSave.erase(path)


## New Run asks Normal or Hard, on the title and in the pause menu.
func _dialog() -> void:
	var box: Control = g.title._new_run
	var yes: Button = box.find_child("Yes", true, false)
	var alt: Button = box.find_child("Alt", true, false)
	var wired := false
	if alt != null:
		for c in alt.get_signal_connection_list("pressed"):
			wired = wired or (c["callable"] as Callable).get_method() == "_on_new_run_hard"
	var pm: Control = g.pause_menu.find_child("NewRun", true, false)
	var pm_alt: Button = pm.find_child("Alt", true, false) if pm != null else null
	t.check("hard_new_run_two_choices", yes != null and yes.text == "Normal" and alt != null and alt.text == "Hard" and wired
			and pm_alt != null and pm_alt.text == "Hard" and (pm.find_child("Yes", true, false) as Button).text == "Normal",
			"title %s/%s, pause %s" % [yes.text if yes else "?", alt.text if alt else "?", pm_alt.text if pm_alt else "?"])


## dV/dt = -0.0010 x min(L, 6) / 3 per play second while loaded; +0.002/s when not.
func _decay_rate() -> void:
	var loads := {"b0.z0": 3.0, "b0.z1": 9.0}
	var m := _model(_layout(), loads)
	m.v["b0.z2"] = 0.5
	m.tick(0.0, 0)
	_run(m, 0.0, 100.0, 0)
	var a := float(m.v["b0.z0"])
	var b := float(m.v["b0.z1"])
	var c := float(m.v["b0.z2"])
	t.check("hard_vitality_decay_rate", _near(a, 0.9) and _near(b, 0.8) and _near(c, 0.7),
			"L 3: %.4f (want 0.9000), L 9 (capped at 6): %.4f (want 0.8000), L 0 from 0.5: %.4f (want 0.7000)" % [a, b, c])


## At most two zones of a ball lose at once (the most loaded).
func _max_two_losing() -> void:
	var loads := {"b0.z0": 1.0, "b0.z1": 4.0, "b0.z2": 2.0, "b0.z3": 3.0}
	var m := _model(_layout(), loads)
	var st := {"most": 0}
	m.tick(0.0, 0)
	_run(m, 0.0, 50.0, 0, func(_n): st["most"] = maxi(st["most"], m.losing.size()))
	var most: int = st["most"]
	var held: bool = m.v["b0.z0"] == 1.0 and m.v["b0.z2"] == 1.0 and m.v["b0.z1"] < 1.0 and m.v["b0.z3"] < 1.0
	t.check("hard_max_two_zones_losing", most == 2 and held, "most losing at once %d; V %s" % [most, str(m.v)])


## Floors: 0.20 + 0.40 x done/total (+0.10 with a touched bloom), never below; a restored ball's mean
## never below 0.65.
func _floors_hold() -> void:
	var layout := _layout(0.5)
	layout[0][1]["bloom"] = true
	layout[1] = [{"zone": "z0", "area": 1.0, "weights": [3, 3, 3, 3], "total": 4, "done": 4, "bloom": false},
			{"zone": "z1", "area": 1.0, "weights": [3, 3, 3, 3], "total": 4, "done": 4, "bloom": false}]
	var loads := {}
	for b in 2:
		for i in 4:
			loads["b%d.z%d" % [b, i]] = 6.0
	var m := _model(layout, loads)
	var lowest := INF
	var st := {"below": false, "mean_min": INF}
	_run(m, 0.0, 6000.0, 0, func(_n):
		for zk in m.v:
			if float(m.v[zk]) < m.floor_of(zk) - 1e-6:
				st["below"] = true)
	# Ball 0 zones: done 4/8 -> 0.40; with the bloom 0.50.
	var f0 := m.floor_of("b0.z0")
	var f1 := m.floor_of("b0.z1")
	var settled := true
	for i in 4:
		settled = settled and _near(float(m.v["b0.z%d" % i]), m.floor_of("b0.z%d" % i), 1e-6)
		lowest = minf(lowest, float(m.v["b0.z%d" % i]))
	# Ball 1 (restored, both zones loaded): he stands there and it decays, but its mean holds 0.65.
	_run(m, 6000.0, 12000.0, 1, func(_n):
		st["mean_min"] = minf(st["mean_min"], m.ball_mean(1))
		for zk in m.v:
			if float(m.v[zk]) < m.floor_of(zk) - 1e-6:
				st["below"] = true)
	var below: bool = st["below"]
	var mean_min: float = st["mean_min"]
	t.check("hard_floors_hold", not below and _near(f0, 0.4) and _near(f1, 0.5) and settled and _near(m.floor_of("b1.z0"), 0.6)
			and mean_min >= HardMode.COMPLETED_MEAN - 1e-6 and _near(m.ball_mean(1), 0.65, 1e-4),
			"floors %.2f / %.2f with bloom; settled %s; restored-ball mean min %.4f (V %.3f, %.3f)" % [f0, f1, settled, mean_min, m.v["b1.z0"], m.v["b1.z1"]])


## A kill gives +0.12 eased over 3 s; a restored Mote +0.10 at once.
func _kill_and_mote() -> void:
	# (Two more loaded zones keep z2 from losing or growing: only the kill moves it.)
	var loads := {"b0.z0": 6.0, "b0.z1": 6.0, "b0.z2": 1.0}
	var m := _model(_layout(), loads)
	m.v["b0.z2"] = 0.5
	_run(m, 0.0, 1.0, 0)
	m.on_kill(0, "z2")
	_run(m, 1.0, 2.5, 0)
	var mid := float(m.v["b0.z2"])
	_run(m, 2.5, 6.0, 0)
	var end := float(m.v["b0.z2"])
	m.on_mote(0, "z2")
	var mote := float(m.v["b0.z2"])
	t.check("hard_kill_and_mote_recover", _near(mid, 0.56, 1e-3) and _near(end, 0.62, 1e-6) and _near(mote, 0.72, 1e-6),
			"after 1.5 s %.4f (want 0.56), after 3 s+ %.4f (want 0.62), Mote %.4f (want 0.72)" % [mid, end, mote])


## A sphere he is not on, with no incursion, does not change at all.
func _other_ball_frozen() -> void:
	var loads := {"b1.z0": 6.0, "b1.z1": 6.0, "b2.z0": 2.0}
	var m := _model(_layout(), loads)
	m.v["b2.z1"] = 0.7
	m.next_incursion = 1e9
	var before := m.v.duplicate()
	_run(m, 0.0, 3000.0, 0)
	var same := true
	for zk in before:
		if not zk.begins_with("b0."):
			same = same and m.v[zk] == before[zk]
	t.check("hard_other_ball_frozen", same, "")


## Nothing while the app is closed, paused or in menus (the play clock stands still), and a long gap
## between two ticks never counts more than a second.
func _no_decay_while_closed() -> void:
	var loads := {"b0.z0": 6.0}
	var m := _model(_layout(), loads)
	m.tick(10.0, 0)
	var a := float(m.v["b0.z0"])
	for i in 400:
		m.tick(10.0, 0)
	var b := float(m.v["b0.z0"])
	m.tick(3610.0, 0)
	var c := float(m.v["b0.z0"])
	t.check("hard_no_decay_while_closed", a == b and _near(a - c, 0.002, 1e-9), "same clock: %.5f -> %.5f; an hour's gap took %.5f (one second's worth 0.002)" % [a, b, a - c])


## Incursions: hashed 15-25 min apart, one at a time, never his sphere or one he left in the last 10 min,
## only on a sphere with a restored zone, at most two zones, ramping to the caps, 15 % of the local rate,
## ending at the floor plateau (still signalling), handed over as owed returners when he arrives.
func _incursions() -> void:
	var layout := _layout(1.0)
	# Ball 2 has no restored zone: never a target. Ball 3 is another restored sphere like ball 1.
	for z in layout[2]:
		z["done"] = 0
	layout.append((layout[1] as Array).duplicate(true))
	var m := _model(layout, {})
	var owed := {}
	m.owe_fn = func(zk: String, c: int) -> void: owed[zk] = int(owed.get(zk, 0)) + c
	m.tick(0.0, 0)
	var first := m.next_incursion
	var first_ok := first >= HardMode.INCURSION_MIN_S and first <= HardMode.INCURSION_MAX_S and _near(first, m.incursion_interval(0), 1e-9)
	_run(m, 0.0, first - 1.0, 0)
	var none_before := m.incursion.is_empty()
	_run(m, first - 1.0, first + 0.5, 0)
	var inc := m.incursion.duplicate(true)
	var bi := int(inc.get("ball", -1))
	var started: bool = not inc.is_empty() and (bi == 1 or bi == 3) and (inc["zones"] as Dictionary).size() <= 2
	# Ramp to the caps (ceil(0.5 x 4 parasites) = 2 each) within INCURSION_RAMP_S.
	_run(m, first + 0.5, first + HardMode.INCURSION_RAMP_S + 1.0, 0)
	var capped := true
	for zk in m.incursion["zones"]:
		capped = capped and int(m.incursion["zones"][zk]["count"]) == 2
	# 15 % of the local rate at L 6 (two large): 0.0003 V/s.
	var zk0: String = (m.incursion["zones"] as Dictionary).keys()[0]
	var v0 := float(m.v[zk0])
	var t0 := first + HardMode.INCURSION_RAMP_S + 1.0
	_run(m, t0, t0 + 100.0, 0)
	var rate := (v0 - float(m.v[zk0])) / 100.0
	# One at a time: due again now, with another sphere free, no second incursion starts.
	m.next_incursion = t0 + 100.0
	var free_other: bool = m.incursion_candidates(0, t0 + 100.25).has(4 - bi)
	m.tick(t0 + 100.25, 0)
	var one_at_a_time: bool = free_other and int(m.incursion["n"]) == int(inc["n"]) and m.n_incursions == int(inc["n"]) + 1
	m.next_incursion = 1e9
	var st := {"plateau": -1.0}
	var end_t := t0 + 3000.0
	_run(m, t0 + 100.25, end_t, 0, func(n):
		if st["plateau"] < 0.0 and m.pending.has(bi):
			st["plateau"] = n)
	var plateau_t: float = st["plateau"]
	# (Its two zones are the whole sphere and it is restored: the 0.65 mean holds them above the floors.)
	var plateau_ok := plateau_t > 0.0 and _near(m.ball_mean(bi), HardMode.COMPLETED_MEAN, 1e-4) and m.incursion.is_empty()
	# (Owner ruling 2026-10-01: once it no longer pushes, the warning settles; the load still waits.)
	var settled := m.levels[bi] == 0 and m.signal_level(bi) == 0 and m.pending.has(bi)
	# Waiting spheres are not targets again; ball 2 (nothing restored) and his own never are.
	m.next_incursion = end_t
	m.tick(end_t + 0.25, 0)
	var second_ok: bool = not m.incursion.is_empty() and int(m.incursion["ball"]) == 4 - bi
	var cands_now := m.incursion_candidates(0, end_t + 0.5)
	# Arrival: the plateaued load becomes owed returners there, and the signal stops on his sphere.
	var now := end_t + 0.5
	m.tick(now, bi)
	var handed: bool = owed.size() == (inc["zones"] as Dictionary).size() and not m.pending.has(bi) and m.signal_level(bi) == 0
	for zk in owed:
		handed = handed and int(owed[zk]) == 2 and zk.begins_with("b%d." % bi)
	# Leaving: that sphere is not a target for the next 10 minutes.
	m.tick(now + 0.25, 0)
	var cands := m.incursion_candidates(0, now + 1.0)
	var cands_later := m.incursion_candidates(0, now + 0.25 + HardMode.LEFT_RECENTLY_S + 1.0)
	t.check("hard_incursion_timing", first_ok and none_before and started, "first at %.0f s (15-25 min: %s), ball %d, zones %s" % [first, first_ok, bi + 1, str(inc.get("zones", {}).keys())])
	t.check("hard_incursion_ramp_and_rate", capped and _near(rate, 0.0003, 2e-6), "caps reached %s; remote rate %.6f V/s (want 0.000300)" % [capped, rate])
	t.check("hard_incursion_one_at_a_time", one_at_a_time and second_ok and not cands_now.has(bi) and not cands_now.has(2) and not cands_now.has(0), "candidates then %s" % str(cands_now))
	t.check("hard_incursion_plateau_signal_settles", plateau_ok and settled, "plateau %.0f s after the start (mean %.3f); level %d" % [plateau_t - first, m.ball_mean(bi), m.levels[bi]])
	t.check("hard_incursion_handover_on_arrival", handed, "owed %s" % str(owed))
	t.check("hard_incursion_not_where_he_just_left", not cands.has(bi) and cands_later.has(bi), "now %s, 10 min later %s" % [str(cands), str(cands_later)])


## The final ruling's fairness margin, measured from the model rather than assumed: on a fully restored
## sphere at the maximum remote pressure, the first visible warning (S1) to S3 takes at least
## 2 x T_resp (700 s), and S1 to the floor plateau more than 600 + 350 s.
func _incursion_fairness_timing() -> void:
	# One zone carrying the whole sphere (the worst case: h falls as fast as the zone does).
	var layout := [[{"zone": "z0", "area": 1.0, "weights": [1], "total": 1, "done": 1, "bloom": false}],
			[{"zone": "z0", "area": 1.0, "weights": [3, 3, 3, 3], "total": 4, "done": 4, "bloom": false}]]
	var m := _model(layout, {})
	m.next_incursion = 0.0
	var st := {"s1": -1.0, "s3": -1.0, "plat": -1.0}
	_run(m, 0.0, 4000.0, 0, func(n):
		if st["s1"] < 0.0 and m.levels[1] >= 1:
			st["s1"] = n
		if st["s3"] < 0.0 and m.levels[1] >= 3:
			st["s3"] = n
		if st["plat"] < 0.0 and m.pending.has(1):
			st["plat"] = n)
	var s1: float = st["s1"]
	var s3: float = st["s3"]
	var plat: float = st["plat"]
	t.check("hard_fairness_margin", s1 > 0.0 and s3 - s1 >= 700.0 and plat - s1 > 950.0,
			"S1 at %.0f s, S3 at %.0f s (S1->S3 %.0f s, need >= 700), floor plateau %.0f s after S1 (need > 950)" % [s1, s3, s3 - s1, plat - s1])


## Distress follows pressure: S1 first while h >= 0.85, rising with it, hysteresis 0.05, and one level
## down per 8 s once relieved.
func _distress_levels() -> void:
	var layout := [[{"zone": "z0", "area": 1.0, "weights": [1], "total": 1, "done": 1, "bloom": false}],
			[{"zone": "z0", "area": 1.0, "weights": [3, 3, 3, 3], "total": 4, "done": 4, "bloom": false}]]
	var m := _model(layout, {})
	m.next_incursion = 0.0
	# (Owner ruling 2026-10-01: the warning follows the current condition. Levels rise while the
	# sphere loses; at the floor plateau the incursion stops pushing and the warning steps down, one
	# level per STEP_DOWN_S, while its load still waits for him.)
	var st := {"first_h": -1.0, "rising": true, "last": 0, "consistent": true, "top": 0, "plateau": -1.0, "steps": []}
	_run(m, 0.0, 1500.0, 0, func(_n):
		var lv: int = m.levels[1]
		var h := m.ball_h(1)
		if st["first_h"] < 0.0 and lv >= 1:
			st["first_h"] = h
		if st["plateau"] < 0.0 and m.pending.has(1):
			st["plateau"] = _n
		if st["plateau"] < 0.0 and lv < st["last"]:
			st["rising"] = false
		if st["plateau"] >= 0.0 and lv != st["last"]:
			(st["steps"] as Array).append([_n - float(st["plateau"]), lv])
		st["top"] = maxi(int(st["top"]), lv)
		st["last"] = lv
		# (Never a level whose entry the sphere has not reached.)
		for k in 3:
			if lv >= k + 1 and h >= float(HardMode.S_ENTER[k]) + 1e-9:
				st["consistent"] = false)
	var first_h: float = st["first_h"]
	var rising: bool = st["rising"]
	var consistent: bool = st["consistent"]
	var top: int = st["top"]
	var steps: Array = st["steps"]
	var step_ok := steps.size() == top and steps.size() > 0 and m.pending.has(1)
	# (The fall stays visible for FALL_WINDOW_S after the plateau, then one level per STEP_DOWN_S.)
	for i in steps.size():
		var due := HardMode.FALL_WINDOW_S + HardMode.STEP_DOWN_S * (i + 1)
		step_ok = step_ok and float(steps[i][0]) <= due + 2.0 * HardMode.TICK_S + 1e-6
		if i > 0:
			step_ok = step_ok and absf(float(steps[i][0]) - float(steps[i - 1][0]) - HardMode.STEP_DOWN_S) <= HardMode.TICK_S + 1e-6
	# Hysteresis: from S1, h back between 0.90 and 0.95 keeps S1; at 0.95 it is left.
	var hm := _model(layout, {"b1.z0": 6.0})
	hm.next_incursion = 1e9
	hm.levels[1] = 1
	hm.current = 0
	hm.v["b1.z0"] = 0.6 + 0.4 * 0.93
	hm._hist[1] = [[0.0, 1.0]]
	hm._distress(1.0, 0.25)
	var kept: int = hm.levels[1]
	hm.v["b1.z0"] = 0.6 + 0.4 * 0.951
	hm._hist[1] = [[0.0, 1.0]]
	hm._distress(1.25, 0.25)
	var left: int = hm.levels[1]
	t.check("hard_distress_tracks_pressure", rising and consistent and top == 3, "levels only rose while pressed, peak S%d" % top)
	t.check("hard_distress_before_major_regression", first_h >= 0.85, "S1 first at h %.3f" % first_h)
	t.check("hard_distress_clears_when_relieved", step_ok and m.levels[1] == 0, "steps (s after the plateau, level): %s; load still waiting %s" % [str(steps), m.pending.has(1)])
	t.check("hard_distress_hysteresis", kept == 1 and left == 0, "h 0.93 keeps S%d, h 0.951 gives S%d" % [kept, left])


## The levels are derived, never saved; a loaded state re-derives the same levels.
func _derived_on_load() -> void:
	var layout := _layout(1.0)
	var m := _model(layout, {})
	m.next_incursion = 0.0
	_run(m, 0.0, 700.0, 0)
	m.on_kill(0, "z1")
	_run(m, 700.0, 701.0, 0)
	var d := m.to_dict()
	var saved_levels := JSON.stringify(d).contains("level")
	var m2 := _model(layout, {})
	m2.from_dict(JSON.parse_string(JSON.stringify(d)))
	var same_dict := JSON.stringify(m2.to_dict()) == JSON.stringify(d)
	var fresh := m2.levels.duplicate()
	_run(m, 701.0, 760.0, 0)
	m2._last_now = 701.0
	m2.current = 0
	_run(m2, 701.0, 760.0, 0)
	var same_after := JSON.stringify(m2.to_dict()) == JSON.stringify(m.to_dict()) and m2.levels == m.levels
	t.check("hard_distress_derived_on_load", not saved_levels and same_dict and fresh == [0, 0, 0] and same_after,
			"levels then %s, re-derived %s; state equal after a minute: %s" % [str(m.levels), str(m2.levels), same_after])
	t.check("hard_save_mid_incursion_same_state", same_dict and same_after and not d["incursion"].is_empty(), str(d["incursion"]))


## Hard Mode draws no random numbers: the global generator is where it was, and the code has no
## generator of its own (every choice is a hash of the run key).
func _rng_isolated() -> void:
	seed(4321)
	var a := [randi(), randi(), randi()]
	seed(4321)
	var m := _model(_layout(1.0), {"b0.z0": 3.0})
	m.owe_fn = func(_zk: String, _c: int) -> void: pass
	_run(m, 0.0, 7200.0, 0)
	_run(m, 7200.0, 7300.0, 1)
	var b := [randi(), randi(), randi()]
	var src := FileAccess.get_file_as_string("res://scripts/core/hard_mode.gd")
	var calls := false
	for word in ["randf(", "randi(", "randomize(", "RandomNumberGenerator", "randf_range(", "randi_range(", "rand_from_seed("]:
		calls = calls or src.contains(word)
	t.check("hard_no_random_numbers", a == b and not calls and m.n_incursions > 0, "global sequence %s; incursions %d" % ["unchanged" if a == b else "MOVED", m.n_incursions])


## Hard's returner rules (§E): grace 240 s, then 180-300 s per zone (doubled at health 2 or less),
## cap ceil(0.5 x authored), 10 per ball, no spot within 20 m of a bloom, none into a zone at its floor.
func _returner_rules() -> void:
	var hr := HardMode.hard_rules()
	var m := _model(_layout(0.0), {"b0.z0": 6.0})
	hr.hard_ref = weakref(m)
	var r := Repopulation.new(hr)
	r.key = "hard-rules"
	var ok_int := true
	for n in 20:
		var z := {"ball": 0, "zone": "z0"}
		var iv := r.interval(z, n)
		ok_int = ok_int and iv >= 180.0 and iv <= 300.0
		hr.slow = true
		ok_int = ok_int and _near(r.interval(z, n), iv * 2.0, 1e-9)
		hr.slow = false
	var caps := [hr.cap_for(1), hr.cap_for(3), hr.cap_for(4), hr.cap_for(5), hr.cap_for(8)]
	var allows_before := hr.allows({"ball": 0, "zone": "z0"})
	_run(m, 0.0, 2000.0, 0)
	var allows_floor := hr.allows({"ball": 0, "zone": "z0"})
	t.check("hard_returner_rules", ok_int and caps == [1, 2, 2, 3, 4] and hr.ball_cap == 10 and hr.grace_s == 240.0 and hr.bloom_clear_m == 11.0
			and allows_before and not allows_floor, "caps %s; at the floor allows %s" % [str(caps), allows_floor])


# --- Checks drawn on the real world (cleaned up after) -------------------------------------------

func _cleanup_world() -> void:
	for b in g.balls:
		b.clear_vitality()
	for v in g.vortices:
		v.clear_distress()


## On the real world: vitality dims what is drawn and nothing else (health map, restoration, earned
## ids, vortices, gates and crumbles stay exactly as they were).
func _world_vitality() -> void:
	var m := HardMode.new()
	m.key = "hard-world"
	m.build(g.balls, g.vortices)
	var b0 := g.balls[0]
	var loads := {}
	for zk in m.ball_zones[0]:
		loads[zk] = 6.0
	m.load_fn = func(zk: String) -> float: return float(loads.get(zk, 0.0))
	m.next_incursion = 1e9
	var sig := func() -> Array:
		var out := []
		for b in g.balls:
			out.append([hash(b.health_img.get_data()) if b.health_img != null else 0, b.restoration, b.events_done, b.completed,
					b.gates.map(func(gt): return gt.is_open), b.crumbles.map(func(c): return c.restored), JSON.stringify(b.zones)])
		out.append(g.vortices.map(func(v): return v.connected))
		out.append(g.run_save.earned().duplicate())
		out.append(g.completion_percent())
		return out
	var before: Array = sig.call()
	m.paint_all()
	_run(m, 0.0, 3000.0, 0)
	await t.frames(2)
	var after: Array = sig.call()
	# What is drawn: health x lerp(0.35, 1, V), on the CPU mirror the shaders follow.
	var low := ""
	for zk in m.ball_zones[0]:
		if low == "" or float(m.v[zk]) < float(m.v[low]):
			low = zk
	var dir: Vector3 = m.zones[low]["dir"]
	var drawn := b0.drawn_health_at(dir)
	var want := b0.health_at(dir) * lerpf(0.35, 1.0, b0.vitality_at(dir))
	var vit_ok := absf(b0.vitality_at(dir) - float(m.v[low])) < 0.03
	var on := true
	for mat in b0.field_materials:
		on = on and mat.get_shader_parameter("vitality_on") == true and mat.get_shader_parameter("vitality_map") == b0.vitality_tex
	t.check("hard_vitality_drawn_only", on and vit_ok and _near(drawn, want, 1e-6), "zone %s V %.3f, map %.3f, drawn %.3f of health %.3f" % [low, m.v[low], b0.vitality_at(dir), drawn, b0.health_at(dir)])
	t.check("hard_vortex_gate_never_regress", before[before.size() - 3] == after[after.size() - 3] and JSON.stringify(before.slice(0, 7)) == JSON.stringify(after.slice(0, 7)), "")
	t.check("hard_completion_never_unearned", before[before.size() - 2] == after[after.size() - 2] and before[before.size() - 1] == after[after.size() - 1], "")
	_cleanup_world()
	var off := true
	for b in g.balls:
		off = off and b.vitality_img == null
		for mat in b.field_materials:
			off = off and mat.get_shader_parameter("vitality_on") != true
	t.check("hard_vitality_cleanup", off, "")


func _mat_vec(v: Vortex, which: String, end := 0) -> Vector2:
	var mat: ShaderMaterial
	match which:
		"jets": mat = v._jet_mat
		"pool": mat = v._pool_mats[end]
		"debris": mat = v._debris_mats[end]
	var x: Variant = mat.get_shader_parameter("distress_a")
	var y: Variant = mat.get_shader_parameter("distress_b")
	return Vector2((x as Vector2).x if x != null else 0.0, (y as Vector2).x if y != null else 0.0)


## The vortex network: every connection touching a threatened remote sphere signals on that sphere's
## half only, in its own hue; the other half only for its own sphere; nothing else changes.
func _world_distress() -> void:
	var m := HardMode.new()
	m.key = "hard-distress"
	m.build(g.balls, g.vortices)
	m.draw = false
	m.current = 0
	var pose := func() -> Array:
		var out := []
		for v: Vortex in g.vortices:
			out.append([v.sample(0.3), v.sample(0.7), v.mouth_pos(false), v.mouth_pos(true), v.ride_pose(0.4), v.connected, v._target,
					v.find_children("*", "CollisionObject3D", true, false).size(), v.points.size()])
		return out
	var before: Array = pose.call()
	# Sphere 2 (index 1) threatened at S2 while he is on sphere 1 (index 0).
	m.levels[1] = 2
	m._tell_vortices()
	for v: Vortex in g.vortices:
		v._update_distress(10.0)
	var after: Array = pose.call()
	var touching := []
	var correct := true
	var healthy := true
	var unrelated := true
	for v: Vortex in g.vortices:
		var ea := v.ball_a.index == 1
		var eb := v.ball_b.index == 1
		var jets := _mat_vec(v, "jets")
		var pool_a := _mat_vec(v, "pool", 0)
		var pool_b := _mat_vec(v, "pool", 1)
		if ea or eb:
			touching.append(v.link_index)
			var hot := jets.x if ea else jets.y
			var cold := jets.y if ea else jets.x
			correct = correct and _near(hot, 0.25, 1e-6) and _near((pool_a.x if ea else pool_b.y), 0.25, 1e-6)
			healthy = healthy and cold == 0.0 and (pool_b.y if ea else pool_a.x) == 0.0
		else:
			unrelated = unrelated and jets == Vector2.ZERO and pool_a == Vector2.ZERO and pool_b == Vector2.ZERO
	var links_of_1 := []
	for li in Levels.LINKS.size():
		if Levels.LINKS[li].has(1):
			links_of_1.append(li)
	t.check("hard_distress_correct_half", correct, "")
	t.check("hard_distress_healthy_half_normal", healthy, "")
	t.check("hard_distress_all_links_of_sphere", touching == links_of_1 and touching.size() == 3, "links %s" % str(touching))
	t.check("hard_distress_unrelated_links_normal", unrelated, "")
	# Both ends: sphere 1 (index 0) threatened too, at S1, while he is on sphere 4 (index 3).
	m.current = 3
	m.levels[0] = 1
	m._tell_vortices()
	for v: Vortex in g.vortices:
		v._update_distress(10.0)
	var v01: Vortex = g.vortices[0]
	var both := _mat_vec(v01, "jets")
	t.check("hard_distress_both_ends_independent", _near(both.x, 0.12, 1e-6) and _near(both.y, 0.25, 1e-6) and v01.distress_level == [1, 2],
			"link 1-2 halves %s" % str(both))
	# Crossfade over 3 s and a pulse that never runs faster than every 2 s.
	m.levels = [0, 3, 0, 0, 0, 0, 0]
	m._tell_vortices()
	var v12: Vortex = g.vortices[1]
	v12._update_distress(1.5)
	var half_way := v12.distress_shown[0]
	var periods_ok := true
	for k in 31:
		v12.distress_shown[0] = k * 0.1
		periods_ok = periods_ok and float(v12.distress_look(0)[1]) >= 2.0
	t.check("hard_distress_crossfade_and_period", absf(half_way - 2.5) < 1e-6 and periods_ok, "level 2 -> 3 after 1.5 s shown %.2f" % half_way)
	t.check("hard_distress_no_travel_change", JSON.stringify(before.map(func(x): return x.slice(0, 5))) == JSON.stringify(after.map(func(x): return x.slice(0, 5))), "")
	t.check("hard_distress_no_unlock_change", JSON.stringify(before.map(func(x): return x.slice(5, 7))) == JSON.stringify(after.map(func(x): return x.slice(5, 7))), "")
	t.check("hard_distress_no_collision_change", JSON.stringify(before.map(func(x): return x.slice(7, 9))) == JSON.stringify(after.map(func(x): return x.slice(7, 9))), "")
	_cleanup_world()
	var clean := true
	for v: Vortex in g.vortices:
		clean = clean and not v._distress_on and _mat_vec(v, "jets") == Vector2.ZERO
	t.check("hard_distress_cleanup", clean, "")


## Each connection keeps its own colour: at every level and pulse the tinted water's hue stays within
## 6 degrees of the connection's normal look and never moves away from its Vortex.TINTS hue (the
## pulse only brightens or darkens it; the S3 lift is toward white).
func _hue_kept() -> void:
	var foam := Color(0.9, 0.98, 1.0)
	var deep := Color(0.16, 0.62, 0.78)
	var worst := 0.0
	var away := false
	var hue_d := func(a: float, b: float) -> float:
		var d := absf(a - b) * 360.0
		return minf(d, 360.0 - d)
	for tint: Color in Vortex.TINTS:
		var base_foam := foam.lerp(tint, Vortex.TINT_AMT)
		var base_deep := deep.lerp(Color(deep.r * tint.r * 1.35, deep.g * tint.g * 1.35, deep.b * tint.b * 1.35), Vortex.TINT_AMT * 0.7)
		for lv in 4:
			var amt: float = Vortex.DISTRESS_TINT[lv]
			for p in [-1.0, 0.0, 1.0]:
				var gain: float = 1.0 + float(Vortex.DISTRESS_SWING[lv]) * p
				var f := foam.lerp(tint, amt) * gain
				var dd := base_deep * gain
				worst = maxf(worst, maxf(hue_d.call(f.h, base_foam.h), hue_d.call(dd.h, base_deep.h)))
				away = away or hue_d.call(f.h, tint.h) > hue_d.call(base_foam.h, tint.h) + 1e-4
	t.check("hard_distress_keeps_link_colour", worst <= 6.0 and not away, "largest hue shift from the connection's normal look %.1f deg; never further from its tint: %s" % [worst, not away])


# --- Child processes: a real Hard run --------------------------------------------------------------

func _child(phase: String, extra: Array) -> int:
	var base: Array = ["--headless", "--fixed-fps", "60", "--max-fps", "0", "--path", ProjectSettings.globalize_path("res://")]
	var pack: String = Settings.test_args.get("pack", "")
	if pack != "":
		base = ["--headless", "--fixed-fps", "60", "--max-fps", "0", "--main-pack", pack]
	var out := []
	var cmd: Array = base + ["--", "--test=unit", "--only=" + phase, "--out=" + ProjectSettings.globalize_path("user://hard_child_out")] + extra
	var code := OS.execute(OS.get_executable_path(), cmd, out, true)
	for line in str(out[0]).split("\n"):
		if line.begins_with("[TEST] PASS") or line.begins_with("[TEST] FAIL"):
			var parts := line.substr(7).split(" ", false, 2)
			t.check("hard_child/" + parts[1], parts[0] == "PASS", parts[2] if parts.size() > 2 else "")
	if code != 0:
		t.log_line("%s exited %d; output:\n%s" % [phase, code, str(out[0]).right(3000)])
	return code


## Save and Continue: a Hard run (with an incursion developing, another waiting and his own sphere
## pressed) is saved; a relaunch continues it as Hard with the same state. Then New Run's Hard choice,
## pressed on the title, starts a Hard run and keeps the records.
func save_checks() -> void:
	var path := ProjectSettings.globalize_path("user://hard_continue.json")
	RunSave.erase(path)
	var a := _child("_phase_hard_write", ["--run-save=" + path, "--mode=hard"])
	var b := _child("_phase_hard_read", ["--run-save=" + path])
	RunSave.erase(path)
	var path2 := ProjectSettings.globalize_path("user://hard_newrun.json")
	RunSave.erase(path2)
	var c := _child("_phase_hard_newrun", ["--run-save=" + path2])
	RunSave.erase(path2)
	var path3 := ProjectSettings.globalize_path("user://hard_finish.json")
	RunSave.erase(path3)
	var d := _child("_phase_hard_finish", ["--run-save=" + path3, "--mode=hard"])
	RunSave.erase(path3)
	t.check("hard_children_ran", [a, b, c, d] == [0, 0, 0, 0], str([a, b, c, d]))


func phase_write() -> void:
	t.check("write_is_hard", g.is_hard() and g.hard != null and g.repop.rules is HardMode.HardRules and str(g.run_save.run().get("mode", "")) == "hard", "")
	# Settled play on his sphere: the controller ticks with the play clock.
	await t.seconds(2.0)
	var ticked: bool = g.hard._last_now > 0.0 and g.hud.vitality_bar.visible and g.hud.vitality_bar.want
	t.check("write_ticks_in_play", ticked and absf(g.hard._last_now - g.clock.play_s) <= 0.3, "last tick %.2f, play %.2f" % [g.hard._last_now, g.clock.play_s])
	var drawn := true
	for b in g.balls:
		drawn = drawn and b.vitality_img != null
	t.check("write_vitality_drawn", drawn, "")
	# The controller's cost per tick (four ticks a second of play), on this machine.
	var t_us := Time.get_ticks_usec()
	var now0 := g.clock.play_s
	for i in 200:
		g.hard.tick(now0 + i * 0.25, g.player.ball.index, g.player.health)
	var per := (Time.get_ticks_usec() - t_us) / 200.0
	t.check("write_tick_cost", per < 2000.0, "%.0f us per tick (4 Hz: %.2f ms per second of play)" % [per, per * 4.0 / 1000.0])
	# A state worth saving: an incursion developing on ball 7, ball 4 waiting, ball 2 left a minute ago.
	var h := g.hard
	var z7: String = h.ball_zones[6][0]
	var z4: String = h.ball_zones[3][0]
	h.incursion = {"ball": 6, "start": g.clock.play_s - 30.0, "n": 3, "zones": {z7: {"count": 1, "cap": 2, "w": 1.5}}}
	h.pending = {3: {z4: {"count": 2, "w": 2.0}}}
	h.n_incursions = 4
	h.next_incursion = g.clock.play_s + 999.0
	h.left_at = {1: g.clock.play_s - 60.0}
	h.v[z7] = 0.83
	h.v[z4] = 0.61
	h.eases[h.ball_zones[0][0]] = [0.05]
	g.save_run()
	var on_disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(g.run_save.path))
	var saved: Dictionary = on_disk["run"]["world"].get("vitality", {})
	t.check("write_saved_vitality", str(on_disk["run"].get("mode", "")) == "hard" and not saved.is_empty() and not JSON.stringify(saved).contains("level")
			and int(saved["format"]) == HardMode.FORMAT and int(on_disk["format"]) == RunSave.FORMAT, "")
	var f := FileAccess.open(g.run_save.path + ".expect", FileAccess.WRITE)
	f.store_string(JSON.stringify({"vitality": saved, "play_s": g.clock.play_s, "run_id": g.run_save.run()["id"]}))
	f.close()


func phase_read() -> void:
	var exp: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(g.run_save.path + ".expect"))
	var sv: Dictionary = exp["vitality"]
	var h := g.hard
	t.check("read_is_hard", g.is_hard() and h != null and g.repop.rules is HardMode.HardRules and g.run_save.run()["id"] == exp["run_id"]
			and g.title.visible == false and g.run_line().begins_with("Hard Mode"), g.run_line())
	var d := h.to_dict()
	var vs_ok := true
	for zk in sv["v"]:
		# (Half a second of play has passed: his own sphere may have moved a little.)
		vs_ok = vs_ok and absf(float(d["v"][zk]) - float(sv["v"][zk])) <= 0.003
	var z7: String = h.ball_zones[6][0]
	t.check("read_same_vitality", vs_ok and absf(float(d["v"][z7]) - 0.83) <= 0.003, "")
	var norm := func(x) -> String: return JSON.stringify(JSON.parse_string(JSON.stringify(x)), "", true)
	t.check("read_same_incursions", norm.call(d["incursion"]) == norm.call(sv["incursion"]) and norm.call(d["pending"]) == norm.call(sv["pending"])
			and int(d["n"]) == 4 and float(d["next"]) == float(sv["next"]) and norm.call(d["left"]) == norm.call(sv["left"]),
			"incursion %s, pending %s" % [str(d["incursion"]), str(d["pending"])])
	# Derived on load: the waiting sphere signals again (from the state, not from a saved flag).
	await t.seconds(1.0)
	var hb := h.ball_h(3)
	var want := 0
	for k in 3:
		if hb < float(HardMode.S_ENTER[k]):
			want = k + 1
	t.check("read_distress_derived", h.levels[3] == want and h.pending.has(3) and h.signal_level(0) == 0, "ball 4 h %.3f -> S%d (want S%d); levels %s" % [hb, h.levels[3], want, str(h.levels)])
	DirAccess.remove_absolute(g.run_save.path + ".expect")


## Finishing a Hard run is finishing a Normal one: every ball restored (the same earned ids, whatever
## the vitality is), the time frozen, the record kept apart as a Hard finish.
func phase_finish() -> void:
	var h := g.hard
	t.check("finish_run_is_hard", g.is_hard() and h != null, "")
	# The struggle at its worst: every zone of every ball pressed to its floor.
	for zk in h.v:
		h.v[zk] = 0.0
	h.tick(g.clock.play_s + 0.25, g.player.ball.index)
	var normal_best := float(g.run_save.records()["best_finish_s"])
	# Everything restored silently, as a continued run restores it; then the last restoration reported.
	for b in g.balls:
		for par in b.parasites:
			if par.is_alive():
				par.restore_cleared()
				b.restore_event(par.zone_id, b.surface_point(par.spawn_dir))
				g._earn(par.get_meta("completion_id", ""))
		for m in b.motes:
			if m.state != "done":
				m.restore_done()
				b.restore_event(m.zone_id, b.surface_point(m.home_dir()))
				g._earn(m.get_meta("completion_id", ""))
	for b in g.balls:
		g._on_restoration_changed(b)
	var rec := g.run_save.records()
	var all_balls := true
	for b in g.balls:
		all_balls = all_balls and g.run_save.earned().has(Completion.ball_restored_id(b.index))
	t.check("hard_finish_same_as_normal", g.clock.is_finished() and g.run_save.earned().has(Completion.ENDING_ID) and all_balls
			and float(rec.get("best_finish_s_hard", -1.0)) == g.clock.finish_s and float(rec["best_finish_s"]) == normal_best
			and str(g.run_save.run()["finish"].get("mode", "")) == "hard",
			"finished %s at %.2f s; floors held V >= %.2f" % [g.clock.is_finished(), g.clock.finish_s, h.ball_mean(0)])
	# The struggle continues as postgame: the controller still ticks, the finish time stays frozen.
	var frozen := g.clock.finish_s
	await t.seconds(1.0)
	t.check("finish_struggle_continues", g.clock.finish_s == frozen and h._last_now > frozen, "")


## New Run on the title, Hard chosen: the scene reloads into a Hard run (this phase runs again there).
func phase_newrun() -> void:
	if g.is_hard():
		var rec := g.run_save.records()
		t.check("newrun_hard_chosen_starts_hard", g.hard != null and g.clock.state != "finished" and g.run_save.earned().is_empty()
				and str(rec.get("best_run_id", "")) == "kept-record", g.run_save.origin)
		return
	t.check("newrun_starts_normal", g.hard == null and not g.run_save.run().has("mode"), "")
	# A record to keep, then the title's New Run -> Hard, as a player presses it.
	g.run_save.records()["best_finish_s"] = 1234.0
	g.run_save.records()["best_run_id"] = "kept-record"
	g.save_run()
	g._enter_title()
	await t.frames(5)
	var ask: Button = g.title._new_run.find_child("Ask", true, false)
	ask.pressed.emit()
	await t.frames(2)
	var alt: Button = g.title._new_run.find_child("Alt", true, false)
	t.check("newrun_dialog_shown", alt.is_visible_in_tree() and (g.title._new_run.find_child("Yes", true, false) as Button).is_visible_in_tree(), "")
	alt.pressed.emit()
	# (The scene reloads; the runner in the new scene runs this phase again and reports.)
	await t.seconds(30.0)


# --- Simulation (§E _phase_hard_sim, §E2 seven spheres with travel, the chore-loop proof) ---------

## Hop times measured from playthroughs (§E2): median 21.0 s, p90 27.6 s, max 49.6 s.
func _hop_time(rng: RandomNumberGenerator) -> float:
	return clampf(21.0 * exp(rng.randfn(0.0, 0.213)), 12.0, 49.6)


func _hops(a: int, b: int) -> int:
	if a == b:
		return 0
	var dist := {a: 0}
	var q := [a]
	while not q.is_empty():
		var x: int = q.pop_front()
		for l in Levels.LINKS:
			for k in 2:
				if l[k] == x and not dist.has(l[1 - k]):
					dist[l[1 - k]] = dist[x] + 1
					q.append(l[1 - k])
	return dist.get(b, 99)


func _neighbours(a: int) -> Array:
	var out := []
	for l in Levels.LINKS:
		if l[0] == a:
			out.append(l[1])
		elif l[1] == a:
			out.append(l[0])
	return out


## One simulated player for `hours` on the real aquarium's zones (every sphere restored, postgame: the
## floors are highest and every zone takes returners). Returners on his sphere follow Hard's rules;
## remote spheres only get incursions. `kind`: idle | diligent | casual | responsive | distracted |
## completionist. `home` >= 0 keeps him on that sphere (§E's per-ball runs).
func simulate(kind: String, seed_v: int, hours: float, home := -1, opts := {}) -> Dictionary:
	var base := HardMode.new()
	base.build(g.balls, g.vortices)
	var layout := base.layout()
	for bl in layout:
		for z in bl:
			z["done"] = z["total"]
	# (Zones whose spots are all near a bloom or a mouth never take a returner: from the real world.)
	var rr := Repopulation.new(HardMode.hard_rules())
	rr.key = "sim"
	rr.build(g.balls, g.vortices)
	var can := {}
	for zk in rr.zones:
		can[zk] = not (rr.zones[zk]["eligible"] as Array).is_empty()
	var rules := HardMode.hard_rules()
	var m := HardMode.new()
	m.key = "sim-%s-%d" % [kind, seed_v]
	m.build_data(layout)
	m.incursion_min_s = float(opts.get("inc_min", HardMode.INCURSION_MIN_S))
	m.incursion_max_s = float(opts.get("inc_max", HardMode.INCURSION_MAX_S))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v * 7919 + kind.hash() % 1000
	# Returners alive: zone key -> Array of {w, kill_at}; per zone next arrival and owed.
	var alive := {}
	var nxt := {}
	var owed := {}
	var last_arrival := {}
	var weights := {}
	for zk in m.zones:
		alive[zk] = []
		weights[zk] = m.zones[zk]["weights"]
		nxt[zk] = rules.grace_s + Repopulation.unit([m.key, zk, "first"]) * 60.0
	m.load_fn = func(zk: String) -> float:
		var l := 0.0
		for r in alive[zk]:
			l += float(r["w"])
		return l
	m.cleared_fn = func(_zk: String) -> bool: return true
	m.can_return_fn = func(zk: String) -> bool: return bool(can.get(zk, false))
	m.owe_fn = func(zk: String, c: int) -> void: owed[zk] = int(owed.get(zk, 0)) + c
	var cur := home if home >= 0 else 0
	var dt := 1.0
	var total := hours * 3600.0
	var now := 0.0
	# Player state.
	var mode := "free"          # free | travel | respond | explore
	var arrive_t := 0.0
	var dest := -1
	var next_explore := (opts.get("explore_s", 1800.0) as float) * rng.randf_range(0.7, 1.3)
	var minute_t := 0.0
	var ignore_until := -1.0
	var interventions: Array = []   # {start, arrive, end, ball}
	var cur_int := {}
	var travel_answer := 0.0
	var answer_time := 0.0
	var below_floor := false
	var h_ok_t := 0.0
	var quiet_t := 0.0
	var summons: Array = []
	var prev_sig := []
	for i in 7:
		prev_sig.append(0)
	var pressure_events: Array = []
	var stabilised: Array = []   # [ball, t] when an answered sphere went back to S0
	var watch := {}
	var kills := 0
	var zone_cross := []
	var below06 := {}
	var mean_sum := []
	var mean_min := []
	var mean_max := []
	for i in 7:
		mean_sum.append(0.0)
		mean_min.append(INF)
		mean_max.append(-INF)
	var avg_from: float = float(opts.get("avg_from_s", 0.0))
	var avg_n := 0
	var delay_s: float = float(opts.get("delay_s", 0.0))
	var save_at: float = float(opts.get("save_at", -1.0))
	var save_ok := true
	var slow := false
	while now < total:
		now += dt
		# Returners arrive on his sphere (Hard rules: per zone timing, caps, spacing, never at a floor).
		if mode != "travel":
			for zk in m.ball_zones[cur]:
				if not can.get(zk, false):
					continue
				var due := int(owed.get(zk, 0)) > 0 or now >= float(nxt[zk])
				var cap: int = rules.cap_for((weights[zk] as Array).size())
				var on_ball := 0
				for zz in m.ball_zones[cur]:
					on_ball += (alive[zz] as Array).size()
				if not due or (alive[zk] as Array).size() >= cap or on_ball >= rules.ball_cap or m.at_floor(zk) \
						or now - float(last_arrival.get(cur, -INF)) < rules.spacing_s:
					continue
				var ws: Array = weights[zk]
				var n_arr := int(Repopulation.unit([m.key, zk, now, "pick"]) * ws.size()) % ws.size()
				var react: float
				match kind:
					"idle": react = INF
					"casual": react = rng.randf_range(20.0, 90.0) if rng.randf() < 0.5 else INF
					_: react = rng.randf_range(15.0, 75.0) if mode != "respond" else rng.randf_range(10.0, 40.0)
				(alive[zk] as Array).append({"w": float(ws[n_arr]), "kill_at": now + react, "seen": now})
				pressure_events.append(now)
				last_arrival[cur] = now
				if int(owed.get(zk, 0)) > 0:
					owed[zk] = int(owed[zk]) - 1
				else:
					nxt[zk] = now + lerpf(rules.every_min_s, rules.every_max_s, Repopulation.unit([m.key, zk, now, "every"])) * (2.0 if slow else 1.0)
			# He deals with what he finds (casual: half of them, rolling again every 10 minutes).
			for zk in m.ball_zones[cur]:
				var arr: Array = alive[zk]
				for i in range(arr.size() - 1, -1, -1):
					var r: Dictionary = arr[i]
					if kind == "casual" and r["kill_at"] == INF and now - float(r["seen"]) > 600.0:
						r["seen"] = now
						r["kill_at"] = now + rng.randf_range(20.0, 90.0) if rng.randf() < 0.5 else INF
					if now >= float(r["kill_at"]):
						arr.remove_at(i)
						m.on_kill(cur, str(m.zones[zk]["zone"]))
						kills += 1
		# Travel and responses.
		match mode:
			"travel", "explore":
				if now >= arrive_t:
					cur = dest
					if mode == "travel":
						cur_int["arrive"] = now
						travel_answer += now - float(cur_int["start"])
						mode = "respond"
					else:
						mode = "free"
						next_explore = now + float(opts.get("explore_s", 1800.0)) * rng.randf_range(0.7, 1.3)
			"respond":
				var left := 0
				for zk in m.ball_zones[cur]:
					left += (alive[zk] as Array).size() + int(owed.get(zk, 0))
				if left == 0 and now - float(cur_int["arrive"]) > 5.0:
					cur_int["end"] = now
					answer_time += now - float(cur_int["arrive"])
					interventions.append(cur_int)
					watch[cur] = {"t": now, "done": false, "iv": cur_int}
					cur_int = {}
					mode = "free"
		if mode == "free" and home < 0:
			minute_t += dt
			if minute_t >= 60.0:
				minute_t = 0.0
				var need := {"responsive": 1, "distracted": 2, "completionist": 3}.get(kind, 99) as int
				var target := -1
				var best := 0
				for bi in 7:
					if bi != cur and m.signal_level(bi) >= need and m.signal_level(bi) > best:
						best = m.signal_level(bi)
						target = bi
				if target >= 0 and delay_s > 0.0 and ignore_until < 0.0:
					ignore_until = now + delay_s
				if target >= 0 and (ignore_until < 0.0 or now >= ignore_until) and (delay_s > 0.0 or rng.randf() < 0.5):
					var hops := _hops(cur, target)
					var tt := 0.0
					for k in hops:
						tt += _hop_time(rng)
					tt += rng.randf_range(30.0, 90.0)
					if delay_s > 0.0:
						tt = float(opts.get("resp_s", 350.0))
					cur_int = {"start": now, "ball": target, "level": best}
					dest = target
					arrive_t = now + tt
					mode = "travel"
					ignore_until = -1.0
			if mode == "free" and now >= next_explore and kind != "idle":
				var nb := _neighbours(cur)
				dest = nb[rng.randi() % nb.size()]
				arrive_t = now + _hop_time(rng)
				mode = "explore"
		var shown_cur := cur
		m.tick(now, shown_cur, 3)
		# Metrics.
		for zk in m.v:
			if float(m.v[zk]) < m.floor_of(zk) - 1e-6:
				below_floor = true
			var b06 := float(m.v[zk]) < 0.6 - 1e-6
			if b06 and not below06.get(zk, false):
				zone_cross.append(now)
			below06[zk] = b06
		var all_ok := true
		var any_remote := false
		for bi in 7:
			all_ok = all_ok and m.ball_h(bi) >= 0.35
			var sg := m.signal_level(bi)
			if sg >= 1 and prev_sig[bi] == 0:
				summons.append(now)
			any_remote = any_remote or sg >= 1
			prev_sig[bi] = sg
			if now >= avg_from:
				var mv := m.ball_mean(bi)
				mean_sum[bi] += mv
				mean_min[bi] = minf(mean_min[bi], mv)
				mean_max[bi] = maxf(mean_max[bi], mv)
		if now >= avg_from:
			avg_n += 1
		if all_ok:
			h_ok_t += dt
		# (Pressure that stays counts too: returners alive and pressing, even when none are new.)
		if int(now) % 60 == 0:
			var any_alive := false
			for zk in m.ball_zones[cur]:
				any_alive = any_alive or not (alive[zk] as Array).is_empty()
			if any_alive or not m.losing.is_empty():
				pressure_events.append(now)
		if not any_remote:
			quiet_t += dt
		for e in m.events:
			if str(e["what"]) == "start" and float(e["t"]) == now:
				pressure_events.append(now)
		# Stabilised spheres: back at S0 after being answered; did they stay there 10 minutes?
		for bi in watch.keys():
			var w: Dictionary = watch[bi]
			if not w["done"] and m.levels[bi] == 0 and not w.has("s0"):
				w["s0"] = now
				(w["iv"] as Dictionary)["s0"] = now
			if w.has("s0") and not w["done"]:
				if m.levels[bi] > 0 and now - float(w["s0"]) < 600.0:
					w["done"] = true
					stabilised.append(false)
				elif now - float(w["s0"]) >= 600.0:
					w["done"] = true
					stabilised.append(true)
		# Save and reload mid-incursion: the copy carries on identically.
		if save_at > 0.0 and now >= save_at and not m.incursion.is_empty():
			save_at = -1.0
			var cp := HardMode.new()
			cp.key = m.key
			cp.build_data(layout)
			cp.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
			save_ok = JSON.stringify(cp.to_dict()) == JSON.stringify(m.to_dict())
	# Summaries.
	var per_hour := []
	for hidx in int(ceil(hours)):
		per_hour.append(summons.filter(func(x): return x > hidx * 3600.0 and x <= (hidx + 1) * 3600.0).size())
	per_hour.sort()
	var starts := interventions.map(func(x): return float(x["start"]))
	var gaps := []
	for i in range(1, starts.size()):
		gaps.append(starts[i] - starts[i - 1])
	gaps.sort()
	# Runs of interventions with less than 10 minutes of free play between them.
	var runs := []
	var run_len := 0
	for i in interventions.size():
		if i > 0 and float(interventions[i]["start"]) - float(interventions[i - 1]["end"]) < 600.0:
			run_len += 1
		else:
			if run_len > 0:
				runs.append(run_len)
			run_len = 1
	if run_len > 0:
		runs.append(run_len)
	runs.sort()
	var windows_ok := true
	var win: float = float(opts.get("window_s", 1800.0))
	var wt := 0.0
	while wt + win <= total:
		var any := false
		for e in pressure_events:
			if e > wt and e <= wt + win:
				any = true
				break
		windows_ok = windows_ok and any
		wt += win
	var crosses_ok := true
	for i in zone_cross.size():
		var c := 0
		for j in range(i, zone_cross.size()):
			if zone_cross[j] - zone_cross[i] <= 600.0:
				c += 1
		crosses_ok = crosses_ok and c <= 2
	var means := []
	for bi in 7:
		means.append(snappedf(mean_sum[bi] / maxf(1, avg_n), 0.001))
	return {"kind": kind, "seed": seed_v, "below_floor": below_floor, "h_ok": h_ok_t / total, "quiet": quiet_t / total,
			"summons_median": per_hour[per_hour.size() / 2] if not per_hour.is_empty() else 0, "summons": summons.size(),
			"interventions": interventions.size(), "gap_median": gaps[gaps.size() / 2] if not gaps.is_empty() else INF,
			"travel_frac": travel_answer / total, "ordinary_frac": 1.0 - (travel_answer + answer_time) / total,
			"runs_p95": runs[mini(runs.size() - 1, int(floor(runs.size() * 0.95)))] if not runs.is_empty() else 0,
			"stable_frac": float(stabilised.count(true)) / maxf(1, stabilised.size()), "stable_n": stabilised.size(),
			"windows_ok": windows_ok, "crosses_ok": crosses_ok, "incursions": m.n_incursions, "kills": kills, "means": means,
			"mean_min": mean_min.map(func(x): return snappedf(x, 0.001)), "mean_max": mean_max.map(func(x): return snappedf(x, 0.001)),
			"save_ok": save_ok, "events": m.events, "ivs": interventions, "final": _final(m, can, cur)}


func _final(m: HardMode, can: Dictionary, bi: int) -> Dictionary:
	var at_floor := true
	for zk in m.ball_zones[bi]:
		if can.get(zk, false):
			at_floor = at_floor and float(m.v[zk]) <= m.floor_of(zk) + 0.01
	return {"pressable_at_floor": at_floor, "mean": m.ball_mean(bi), "held": absf(m.ball_mean(bi) - HardMode.COMPLETED_MEAN) < 0.005}


## The ruling's remedy measured: longer incursion intervals (--intervals=900-1500,1800-3000,...).
func sim_intervals() -> void:
	var seeds: Array = Array(str(Settings.test_args.get("seeds", "1,2,3")).split(",", false)).map(func(x): return int(x))
	var hours := float(Settings.test_args.get("hours", "12"))
	for iv in str(Settings.test_args.get("intervals", "900-1500,1800-3000")).split(",", false):
		var lo := float(iv.split("-")[0])
		var hi := float(iv.split("-")[1])
		for kind in ["responsive", "distracted", "completionist"]:
			var q := []
			var s1 := []
			for s in seeds:
				var r := simulate(kind, s, hours, -1, {"inc_min": lo, "inc_max": hi})
				q.append(snappedf(float(r["quiet"]) * 100.0, 0.1))
				s1.append(r["summons_median"])
			t.log_line("HARDSIM interval %s %s: quiet %% %s, summons median/h %s" % [iv, kind, str(q), str(s1)])
	t.check("hard_sim_intervals_ran", true, "")


func sim() -> void:
	var seeds: Array = Array(str(Settings.test_args.get("seeds", "1,2,3")).split(",", false)).map(func(x): return int(x))
	var hours := float(Settings.test_args.get("hours", "12"))
	var t0 := Time.get_ticks_msec()
	# §E: three players, three simulated hours on each restored ball.
	var e_ok := {"idle": true, "diligent": true, "casual": true}
	for kind in ["idle", "diligent", "casual"]:
		for bi in 7:
			var r := simulate(kind, 1, 3.0, bi, {"avg_from_s": 3600.0, "window_s": 600.0, "explore_s": 1e12})
			var mv: float = r["means"][bi]
			var ok: bool = not r["below_floor"] and r["crosses_ok"] and r["windows_ok"]
			match kind:
				"idle": ok = ok and (r["final"]["pressable_at_floor"] or r["final"]["held"])
				"diligent": ok = ok and mv >= 0.85
				"casual": ok = ok and mv >= 0.65 and mv <= 0.95
			e_ok[kind] = e_ok[kind] and ok
			t.log_line("HARDSIM E %s ball %d: mean V %.3f (min %.3f max %.3f) over the last 2 h; below floor %s; zones crossing 0.6 ok %s; pressure every 10 min %s; kills %d" % [kind,
					bi + 1, mv, r["mean_min"][bi], r["mean_max"][bi], r["below_floor"], r["crosses_ok"], r["windows_ok"], r["kills"]])
	t.check("hard_sim_idle_converges_to_floors", e_ok["idle"], "")
	t.check("hard_sim_diligent_mean_085", e_ok["diligent"], "")
	t.check("hard_sim_casual_065_095", e_ok["casual"], "")
	# §E2 and the chore-loop proof: four players, twelve hours, several seeds, seven spheres with travel.
	var all := {}
	for kind in ["idle", "responsive", "distracted", "completionist"]:
		all[kind] = []
		for s in seeds:
			var r := simulate(kind, s, hours, -1, {"save_at": 3600.0 * 3.0})
			all[kind].append(r)
			t.log_line("HARDSIM E2 %s seed %d: incursions %d, summons %d (median/h %d), interventions %d, gap median %.0f s, travel %.1f%%, ordinary %.1f%%, quiet %.1f%%, h>=0.35 %.1f%%, runs p95 %d, stable %.0f%% of %d, pressure/30 min %s, below floor %s, save %s" % [
					kind, s, r["incursions"], r["summons"], r["summons_median"], r["interventions"], r["gap_median"], r["travel_frac"] * 100.0, r["ordinary_frac"] * 100.0,
					r["quiet"] * 100.0, r["h_ok"] * 100.0, r["runs_p95"], r["stable_frac"] * 100.0, r["stable_n"], r["windows_ok"], r["below_floor"], r["save_ok"]])
	var floor_ok := true
	var lock_ok := true
	var save_ok := true
	for kind in all:
		for r in all[kind]:
			floor_ok = floor_ok and not r["below_floor"]
			lock_ok = lock_ok and r["windows_ok"]
			save_ok = save_ok and r["save_ok"]
	t.check("hard_sim_never_below_floor", floor_ok, "")
	t.check("hard_sim_no_living_lock", lock_ok, "a pressure event in every 30 minutes, every player and seed")
	t.check("hard_sim_save_mid_incursion", save_ok, "")
	var resp_ok := true
	var quiet_unanswered: Array[String] = []
	var chore := {"summons": true, "gap": true, "travel": true, "runs": true, "ordinary": true, "quiet": true, "stable": true}
	for kind in ["responsive", "distracted"]:
		for r in all[kind]:
			resp_ok = resp_ok and float(r["h_ok"]) >= 0.95
	for kind in ["responsive", "distracted", "completionist"]:
		for r in all[kind]:
			chore["summons"] = chore["summons"] and int(r["summons_median"]) <= 3
			chore["gap"] = chore["gap"] and (int(r["interventions"]) < 2 or float(r["gap_median"]) >= 900.0)
			chore["travel"] = chore["travel"] and float(r["travel_frac"]) <= 0.15
			chore["runs"] = chore["runs"] and int(r["runs_p95"]) <= 2
			chore["ordinary"] = chore["ordinary"] and float(r["ordinary_frac"]) >= 0.70
			# (Quiet time is asserted where the summons are answered; the others' figures are logged. Since
			# the 2026-10-01 ruling an unanswered warning settles once the threat stops pushing.)
			if kind == "responsive":
				chore["quiet"] = chore["quiet"] and float(r["quiet"]) >= 0.70
			else:
				quiet_unanswered.append("%s %d: %.0f%%" % [kind, int(r["seed"]), float(r["quiet"]) * 100.0])
			chore["stable"] = chore["stable"] and (int(r["stable_n"]) == 0 or float(r["stable_frac"]) >= 0.9)
	t.check("hard_sim_responsive_keep_h035", resp_ok, "responsive and distracted keep every sphere at h >= 0.35 for >= 95% of the time")
	t.check("hard_sim_summons_median_le_3_per_hour", chore["summons"], "")
	t.check("hard_sim_interventions_15_min_apart", chore["gap"], "")
	t.check("hard_sim_distress_travel_le_15pct", chore["travel"], "")
	t.check("hard_sim_back_to_back_le_2", chore["runs"], "")
	t.check("hard_sim_ordinary_play_ge_70pct", chore["ordinary"], "")
	t.check("hard_sim_quiet_ge_70pct", chore["quiet"], "responsive players; S1 left unanswered (logged, owner question): " + ", ".join(quiet_unanswered))
	t.check("hard_sim_no_oscillation", chore["stable"], "")
	# The delay test: S1 ignored for 10 minutes, then the answer takes T_resp (350 s): he still arrives
	# before the floor plateau and brings the sphere back to S0.
	var delay_ok := true
	var lines: Array[String] = []
	for s in seeds:
		var r := simulate("responsive", s, 6.0, -1, {"delay_s": 600.0, "resp_s": 350.0})
		for iv in r["ivs"]:
			var bi := int(iv["ball"])
			var plateau := INF
			for e in r["events"]:
				if str(e["what"]) == "plateau" and int(e["ball"]) == bi and float(e["t"]) > float(iv["start"]) - 3600.0 and float(e["t"]) < plateau:
					plateau = float(e["t"])
			var before := float(iv.get("arrive", INF)) < plateau
			delay_ok = delay_ok and before and iv.has("end") and iv.has("s0")
			lines.append("b%d S%d: answered %.0f s, arrived %.0f s, plateau %s" % [bi + 1, int(iv["level"]), float(iv["start"]), float(iv.get("arrive", -1.0)), "none" if plateau == INF else "%.0f s" % plateau])
		delay_ok = delay_ok and int(r["interventions"]) > 0
	t.log_line("HARDSIM delay test: " + "; ".join(lines))
	t.check("hard_sim_delay_then_respond", delay_ok, "%d answered" % lines.size())
	t.log_line("HARDSIM took %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))


# --- Renders (shots.gd --only=hard) ----------------------------------------------------------------

func shots(sh) -> void:
	var p := g.player
	p.invuln_t = 9999
	if str(Settings.test_args.get("part", "")) == "incursion":
		sh._heal_all(g)
		await t.seconds(2.0)
		await _incursion_shots(sh)
		return
	for v: Vortex in g.vortices:
		v.connected = true
		v._target = 1.0
		v.strength = 1.0
	sh._heal_all(g)
	g.hud.visible = false
	p.place(g.balls[0], g.balls[0].surface_point(Vector3.UP, 0.2), Vector3.FORWARD)
	await t.seconds(2.0)
	var m := HardMode.new()
	m.key = "shots"
	m.build(g.balls, g.vortices)
	m.current = 0
	m.draw = false
	var set_levels := func(lv: Array) -> void:
		m.levels.assign(lv)
		m._tell_vortices()
		for v: Vortex in g.vortices:
			v.distress_shown = [float(v.distress_level[0]), float(v.distress_level[1])]
	# 1. One connection (1-2) from the side: healthy, end B mild (S1), severe (S3), both ends.
	var v0: Vortex = g.vortices[0]
	var sv: Array = sh._vc_side(v0, 0.75)
	for st in [["healthy", [0, 0, 0, 0, 0, 0, 0]], ["b_mild_S1", [0, 1, 0, 0, 0, 0, 0]], ["b_severe_S3", [0, 3, 0, 0, 0, 0, 0]]]:
		m.current = 0
		set_levels.call(st[1])
		sh._vc_cam(g, sv[0], sv[1], sv[2])
		# (The crest of the pulse, then its trough.)
		await _pulse_pair(sh, g, v0, 1, "hard_link12_" + st[0])
	m.current = 3
	set_levels.call([2, 3, 0, 0, 0, 0, 0])
	sh._vc_cam(g, sv[0], sv[1], sv[2])
	await _pulse_pair(sh, g, v0, 0, "hard_link12_both_A_S2_B_S3")
	# 2. Every link round one threatened sphere (2) pointing toward it, from high above.
	m.current = 6
	set_levels.call([0, 3, 0, 0, 0, 0, 0])
	# (From across the plane of its three connections, far enough back to see all of them.)
	var b1 := g.balls[1]
	var pc := b1.global_position
	var mids: Array[Vector3] = []
	for v: Vortex in g.vortices:
		if v.ball_a == b1 or v.ball_b == b1:
			mids.append(v.sample(0.5)[0])
	var nrm := (mids[0] - pc).cross(mids[1] - pc).normalized()
	var look := pc
	var reach := 0.0
	for mp in mids:
		look += mp
		reach = maxf(reach, mp.distance_to(pc))
	look /= mids.size() + 1
	var cam_up := (mids[0] - pc).normalized()
	# (Whichever side of that plane keeps the camera inside the tank, as far back as fits.)
	var box := AABB(Aquarium.TANK_MIN, Aquarium.TANK_MAX - Aquarium.TANK_MIN).grow(-3.0)
	var cam_at := look + nrm * reach
	var found := false
	for kk in [1.6, 1.4, 1.2, 1.0, 0.8, 0.6]:
		for sg in [1.0, -1.0]:
			if not found and box.has_point(look + nrm * sg * reach * kk):
				cam_at = look + nrm * sg * reach * kk
				found = true
	sh._vc_cam(g, cam_at, look, cam_up)
	await t.seconds(0.4)
	await t.shot("hard_sphere2_all_links_S3")
	set_levels.call([0, 0, 0, 0, 0, 0, 0])
	await t.frames(3)
	await t.shot("hard_sphere2_all_links_healthy")
	# 3. A mouth close up, the pool of the threatened end at S3.
	var mouth := v0.mouth_pos(true)
	var mu := g.balls[1].up_at(mouth)
	set_levels.call([0, 3, 0, 0, 0, 0, 0])
	sh._vc_cam(g, mouth + mu * 7.0 + MossBall.frame_at(mu, 0.0).z * 9.0, mouth, mu)
	await _pulse_pair(sh, g, v0, 1, "hard_mouth_b_S3")
	set_levels.call([0, 0, 0, 0, 0, 0, 0])
	await t.frames(3)
	await t.shot("hard_mouth_b_healthy")
	# 4. The signal clearing: S3 stepping down (8 s a level) with the 3 s crossfade, in 4 frames.
	set_levels.call([0, 3, 0, 0, 0, 0, 0])
	sh._vc_cam(g, sv[0], sv[1], sv[2])
	m.levels.assign([0, 0, 0, 0, 0, 0, 0])
	for k in 4:
		for vv: Vortex in g.vortices:
			vv.distress_level = [0, maxi(0, 3 - k)]
		await t.seconds(3.0)
		await t.shot("hard_clearing_%d" % k)
	# 5. Pulse strips: 8 frames over one period per level (end B of 1-2).
	for lv in [1, 2, 3]:
		set_levels.call([0, lv, 0, 0, 0, 0, 0])
		var per := float(v0.distress_look(1)[1])
		for k in 8:
			v0.distress_phase[1] = TAU * k / 8.0
			_freeze_phase(v0)
			await t.frames(2)
			await t.shot("hard_strip_S%d_%d" % [lv, k])
		t.log_line("HARD strip S%d: period %.1f s, swing %.2f, tint %.2f" % [lv, per, float(v0.distress_look(1)[0]), float(v0.distress_look(1)[2])])
	# Performance A/B at the same view (both ends of 1-2 at S3 against Normal), A-B-A-B.
	sh._vc_cam(g, sv[0], sv[1], sv[2])
	var ab := []
	for k in 4:
		if k % 2 == 0:
			for vv: Vortex in g.vortices:
				vv.clear_distress()
		else:
			m.current = 3
			set_levels.call([3, 3, 3, 3, 3, 3, 3])
		ab.append(await _frame_ms())
	t.log_line("HARD perf distress: Normal %.2f / %.2f ms, every half at S3 %.2f / %.2f ms per frame" % [ab[0], ab[2], ab[1], ab[3]])
	for v: Vortex in g.vortices:
		v.clear_distress()
	# 6. Vitality on the ground: one restored zone of ball 1 at V = 1, 0.6 and the floor of an
	# unfinished zone (0.2), from his camera.
	sh._open(g)
	var hb := HardMode.new()
	hb.key = "shots-v"
	hb.build(g.balls, g.vortices)
	var zk: String = hb.ball_zones[0][0]
	var big := 0.0
	for k2 in hb.ball_zones[0]:
		if float(hb.zones[k2]["radius"]) > big:
			big = float(hb.zones[k2]["radius"])
			zk = k2
	var zdir: Vector3 = hb.zones[zk]["dir"]
	var b0 := g.balls[0]
	p.place(b0, b0.surface_point(zdir.rotated(MossBall.frame_at(zdir, 0.0).x, -big * 0.8), 0.2), b0.surface_point(zdir) - b0.surface_point(zdir.rotated(MossBall.frame_at(zdir, 0.0).x, -big * 0.8)))
	g.cam.snap_behind()
	g.hud.visible = true
	g.hud.show_vitality(true)
	for vv in [1.0, 0.6, 0.2]:
		for k2 in hb.ball_zones[0]:
			hb.v[k2] = 1.0
		hb.v[zk] = vv
		hb.paint_all()
		g.hud.set_vitality(hb.ball_mean(0), vv, vv < 1.0)
		await t.seconds(1.5)
		await t.shot("hard_vitality_V%.1f" % vv)
	Settings.reduced_hud = true
	await t.seconds(0.5)
	await t.shot("hard_vitality_reduced_hud")
	Settings.reduced_hud = false
	# Performance A/B at this view: the vitality map off (Normal) and on, A-B-A-B.
	var vab := []
	for k in 4:
		if k % 2 == 0:
			for b in g.balls:
				b.clear_vitality()
			g.hud.show_vitality(false)
		else:
			hb.paint_all()
			g.hud.show_vitality(true)
		vab.append(await _frame_ms())
	t.log_line("HARD perf vitality: Normal %.2f / %.2f ms, Hard %.2f / %.2f ms per frame" % [vab[0], vab[2], vab[1], vab[3]])
	for b in g.balls:
		b.clear_vitality()
	g.hud.show_vitality(false)
	await _incursion_shots(sh)


## An incursion handed over: the owed returners arriving on the sphere he reached (a real Hard
## repopulation on ball 1's restored zones), each seen from his own camera a few metres away.
func _incursion_shots(sh) -> void:
	var p := g.player
	var b0 := g.balls[0]
	sh._open(g)
	var hr := HardMode.hard_rules()
	var rp := Repopulation.new(hr)
	rp.key = "shots-inc"
	rp.build(g.balls, g.vortices)
	var owed_n := 0
	for zz in rp.zones.values():
		if int(zz["ball"]) == 0 and not (zz["eligible"] as Array).is_empty():
			rp.owe(Repopulation.zone_key(0, zz["zone"]), 2)
			owed_n += int(zz.get("owed", 0))
	var nowhere := Vector3(0, 100000, 0)
	var came := 0
	for i in 40:
		if rp.update(1000.0 + i * 9.0, b0, nowhere, null) != null:
			came += 1
	t.log_line("HARD incursion hand-over render: %d owed, %d arrived" % [owed_n, came])
	await t.seconds(1.5)
	g.hud.visible = false
	var k3 := 0
	for r in b0.returners:
		if k3 >= 2 or not is_instance_valid(r) or not r.is_alive():
			continue
		var at: Vector3 = r.global_position
		var d := b0.up_at(at)
		var off := d.rotated(MossBall.frame_at(d, 0.0).x, deg_to_rad(4.0 / b0.radius * 57.3) * (1.0 if k3 == 0 else -1.0))
		var stand := b0.surface_point(off, 0.3)
		r.set_physics_process(false)
		r.set_process(false)
		p.place(b0, stand, at - stand)
		p.velocity = Vector3.ZERO
		g.cam.snap_behind()
		await t.seconds(1.2)
		await t.shot("hard_incursion_returner_%d" % k3)
		k3 += 1
	for r in b0.returners:
		if is_instance_valid(r):
			r.queue_free()
	b0.returners.clear()
	b0.returners_changed()


## Mean frame time (ms) over `n` frames at the current view.
func _frame_ms(n := 90) -> float:
	await t.frames(10)
	var t0 := Time.get_ticks_usec()
	for i in n:
		await RenderingServer.frame_post_draw
	return (Time.get_ticks_usec() - t0) / 1000.0 / n


## (The pulse at its crest and its trough for one end, for the before/after pair.)
func _pulse_pair(sh, g_: Game, v: Vortex, end: int, name_: String) -> void:
	await t.seconds(0.2)
	for ph in [["crest", PI * 0.5], ["trough", PI * 1.5]]:
		v.distress_phase[end] = ph[1]
		_freeze_phase(v)
		await t.frames(2)
		await t.shot("%s_%s" % [name_, ph[0]])


func _freeze_phase(v: Vortex) -> void:
	v._update_distress(0.0)
