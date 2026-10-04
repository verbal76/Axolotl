extends RefCounted
## Cohesion audit P2 and P3 (docs/research/audit-2026-10-02/AUDIT.md):
## - P2: the pause menu's line for the ball he is on (`BallView.progress_line`, `PauseMenu.ball_line`):
##   its % restored and whether its water tunnel is open (it opens at Vortex.CONNECT_AT), above the
##   run-wide table, with the menu still fitting landscape with nothing to scroll.
## - P3: the first-arrival establishing view (`Game._arrived`): the whole-ball view for about 3 s the
##   first time a tunnel brings him to a ball, once per run, saved as the run world's "balls_seen".
## Runs inside the unit suite (--only=_test_pause_ball_progress / --only=_test_arrival_view).

var t
var u   # (the unit suite: place_at, _hold_threats, _fit_problems)
var g: Game
var p: Axolotl


func _init(runner, unit) -> void:
	t = runner
	u = unit
	g = runner.g
	p = g.player


# --- P2 ---------------------------------------------------------------------------------------

func pause_ball_progress() -> void:
	var vs: Array = g.vortices
	var was := {}
	for v: Vortex in vs:
		was[v] = v.connected
	var rest := {}
	for b: MossBall in g.balls:
		rest[b] = b.restoration
	# (Text only, with nothing processed in between: a 74% set here never opens a tunnel.)
	var ts: MossBall = g.balls[3]    # Terrace Steps: one tunnel out
	var mm: MossBall = g.balls[0]    # Mossy Meadow: two
	var rc: MossBall = g.balls[4]    # Reed Canyon: none out
	for v: Vortex in vs:
		v.connected = false
	var lines := {}
	for k in [[ts, 0.42], [ts, 0.69], [ts, 0.70], [ts, 0.74], [ts, 1.0], [mm, 0.42], [mm, 1.0], [rc, 0.42]]:
		var b: MossBall = k[0]
		b.restoration = k[1]
		lines["%s %.4f" % [b.display_name, k[1]]] = BallView.progress_line(b, vs)
	# A tunnel already open in the save reads open whatever the % (never "opens at" once open).
	ts.restoration = 0.42
	for v: Vortex in ts.vortices:
		if v.ball_a == ts:
			v.connected = true
	var shut_but_saved_open := BallView.progress_line(ts, vs)
	for b: MossBall in rest:
		b.restoration = rest[b]
	for v: Vortex in vs:
		v.connected = was[v]
	var want := {
		"Terrace Steps 0.4200": "Terrace Steps  ·  42% restored  ·  tunnel opens at 70%",
		"Terrace Steps 0.6900": "Terrace Steps  ·  69% restored  ·  tunnel opens at 70%",
		"Terrace Steps 0.7000": "Terrace Steps  ·  70% restored  ·  tunnel open",
		"Terrace Steps 0.7400": "Terrace Steps  ·  74% restored  ·  tunnel open",
		"Terrace Steps 1.0000": "Terrace Steps  ·  100% restored  ·  tunnel open",
		"Mossy Meadow 0.4200": "Mossy Meadow  ·  42% restored  ·  tunnels open at 70%",
		"Mossy Meadow 1.0000": "Mossy Meadow  ·  100% restored  ·  tunnels open",
		"Reed Canyon 0.4200": "Reed Canyon  ·  42% restored",
	}
	var bad: Array[String] = []
	for k in want:
		if lines.get(k, "") != want[k]:
			bad.append("%s: '%s'" % [k, lines.get(k, "")])
	t.check("pause_ball_line_percent_and_tunnel", bad.is_empty() and shut_but_saved_open.ends_with("tunnel open"),
			"; ".join(bad) if not bad.is_empty() else str(lines.values()))
	# 70% opens the way on; it is never the ball's end.
	var ends := false
	for k in lines:
		var s: String = lines[k]
		ends = ends or s.contains("complete") or s.contains("done") or s.contains("finished") or s.contains("cleared")
	t.check("pause_ball_line_never_reads_as_done", not ends and Vortex.CONNECT_AT == 0.7, "")

	# In the pause menu, in play: the line above the run-wide table, which keeps its counts.
	var hb: MossBall = g.balls[1]    # Current Hollows, two tunnels shut: the longest line there is
	var release: Callable = u._hold_threats(hb)
	u.place_at(1, hb.surface_point(hb.start_dir, 0.2), MossBall.frame_at(hb.start_dir, 0).z)
	await t.frames(3)
	var r1 := hb.restoration
	var hw := {}
	for v: Vortex in hb.vortices:
		hw[v] = v.connected
		if v.ball_a == hb:
			v.connected = false
	hb.restoration = 0.42
	var pm := g.pause_menu
	pm.open()
	await t.frames(3)
	var detail := pm._run_detail.text
	var line := "Current Hollows  ·  42% restored  ·  tunnels open at 70%"
	t.check("pause_menu_shows_this_ball", pm._ball_line == line and detail.contains(line) and detail.find(line) < detail.find("[table")
			and detail.contains("Moss restored") and detail.contains("Game finished") and pm._run_time.text.contains("% complete"),
			"'%s' | %s" % [pm._ball_line, detail.left(220)])
	# At its fullest, on landscape phones, nothing to scroll (as _test_menus_no_scroll, with this line).
	var saved_t2 := g.tier2
	g.tier2 = Tier2.new()
	g.tier2.unlock(Tier2.CANNON)
	g.tier2.unlock(Tier2.BUBBLE)
	g.tier2.equip(Tier2.BUBBLE)
	pm._refresh()
	pm._treasure.visible = true
	pm._loadout.visible = true
	(pm._panel.find_child("Ask", true, false) as Button).pressed.emit()
	await t.frames(2)
	var ok := true
	var rows: Array[String] = []
	for w in [1280, 1560, 1600]:
		for side in ["left", "right"]:
			var area := Rect2(90 if side == "left" else 12, 12, w - 90 - 12, 720 - 24)
			pm.layout_in(area)
			await t.frames(2)
			var why: String = u._fit_problems(pm._panel, area, PauseMenu.MIN_TOUCH)
			if not area.encloses(pm._panel.get_global_rect()):
				why += " panel %s" % pm._panel.get_global_rect()
			var font := pm._run_detail.get_theme_font("normal_font")
			var lw := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
			if lw > pm._run_detail.size.x:
				why += " ball line %.0f px in %.0f (wraps)" % [lw, pm._run_detail.size.x]
			ok = ok and why == ""
			rows.append("%dx720 %s: panel %s %s" % [w, side, pm._panel.get_global_rect().size, "fits" if why == "" else why])
	(pm._panel.find_child("Cancel", true, false) as Button).pressed.emit()
	pm.close()
	g.tier2 = saved_t2
	await t.frames(2)
	t.check("pause_ball_line_fits_landscape_no_scroll", ok, "; ".join(rows))
	# Not from the title (no run is being played) and not in the aquarium experiences.
	pm.open(true)
	await t.frames(2)
	var title_line := pm._ball_line
	var title_detail_hidden := not pm._run_detail.visible
	pm.close()
	await t.frames(1)
	var st := g.state
	g.state = "aquarium"
	var aq_line := pm.ball_line()
	g.state = st
	t.check("pause_ball_line_only_in_play", title_line == "" and title_detail_hidden and aq_line == "", "title '%s', aquarium '%s'" % [title_line, aq_line])
	# Nothing new in the play HUD.
	var hud_text := false
	for n in g.hud.find_children("*", "Label", true, false):
		hud_text = hud_text or (n as Label).text.contains("% restored") or (n as Label).text.contains("tunnel")
	t.check("pause_ball_line_not_in_hud", not hud_text, "")
	hb.restoration = r1
	for v: Vortex in hw:
		v.connected = hw[v]
	release.call()


# --- P3 ---------------------------------------------------------------------------------------

## One tunnel ride: from v's a end (b end when `rev`) until the landing is over.
func _ride(v: Vortex, rev: bool) -> void:
	var src: MossBall = v.ball_b if rev else v.ball_a
	u.place_at(src.index, src.surface_point(src.start_dir, 0.2), MossBall.frame_at(src.start_dir, 0).z)
	p.restore_full()
	await t.frames(3)
	g._start_cinematic("travel", {"v": v, "reverse": rev})
	var f := 0
	while g.cinematic != "" and f < 60 * 12:
		await t.frames(1)
		f += 1


func _touch() -> void:
	var ev := InputEventScreenTouch.new()
	ev.pressed = true
	ev.position = Vector2(640, 360)
	Input.parse_input_event(ev)
	await t.frames(1)
	var ev2 := ev.duplicate() as InputEventScreenTouch
	ev2.pressed = false
	Input.parse_input_event(ev2)


## Waits out an open view, measuring it: [frames shown, largest camera step in a frame, held still
## (no move, no hurt, nothing processed), caption, camera step the frame after it returned].
func _watch(bv: BallView, skip_after := -1.0) -> Array:
	var frames := 0
	var step := 0.0
	var still := true
	var pos0 := p.global_position
	var hp0 := p.health
	var run0: float = g.clock.run_s
	var cap := bv._label.text
	var prev := g.cam.global_position
	while bv.active and frames < 60 * 8:
		if skip_after >= 0.0 and frames == int(skip_after * 60.0):
			await _touch()
		else:
			await t.frames(1)
		frames += 1
		step = maxf(step, g.cam.global_position.distance_to(prev))
		prev = g.cam.global_position
		if bv.active:
			still = still and g.get_tree().paused and not p.can_process() and not g.ecosystem.can_process() \
					and p.global_position.distance_to(pos0) < 0.01 and p.health == hp0 and absf(g.clock.run_s - run0) < 0.001 and not g.hud.visible
	await t.frames(1)
	var after := g.cam.global_position.distance_to(prev)
	return [frames, step, still, cap, after]


func arrival_view() -> void:
	var bv: BallView = g.ball_view
	var cam: FollowCam = g.cam
	var keep := {"views": g.arrival_views, "seen": g.balls_seen.duplicate(), "arrival": g.arrival, "checkpoint": g.checkpoint}
	var was := {}
	for v: Vortex in g.vortices:
		was[v] = v.connected
		v.connected = true
	var holds: Array = []
	for b: MossBall in g.balls:
		holds.append(u._hold_threats(b))
	var d0 := cam.unsafe_drawn
	var c0 := cam.corrected_frames
	var links: Array = g.vortices.map(func(v: Vortex) -> Array: return [v.ball_a.index, v.ball_b.index])
	t.check("arrival_links_as_expected", links == [[0, 1], [1, 2], [0, 3], [1, 4], [2, 5], [3, 6]], str(links))

	# --- Old saves (no "balls_seen"): worked out from where the run shows he has been. ---
	var fresh := Game.seen_from_save({}, {}, links)
	var kept := Game.seen_from_save({"balls_seen": ["b1", "b3"], "ball": 4}, {"b6.bloom.1": 1.0}, links)
	var old := Game.seen_from_save({"ball": 1, "arrival": {"v": 3, "rev": false}, "stats": {"travels": [[0, false], [1, false]]}},
			{"b1.tut.parasite.0": 1.0, "b7.bloom.2": 3.0, "species.snail": 2.0, "vortex.b1-b2": 4.0}, links)
	var old_keys := old.keys()
	old_keys.sort()
	var only_here := Game.seen_from_save({"ball": 0, "stats": {"travels": []}}, {"b1.bloom.0": 1.0}, links)
	t.check("arrival_seen_old_save_migration", fresh.is_empty() and kept.keys() == ["b1", "b3"]
			and old_keys == ["b1", "b2", "b3", "b4", "b5", "b7"] and only_here.keys() == ["b1"],
			"fresh %s, kept %s, old %s, ball 1 only %s" % [fresh.keys(), kept.keys(), old_keys, only_here.keys()])

	g.arrival_views = true
	g.balls_seen = {}
	var n0 := bv.arrivals_shown
	var v12: Vortex = g.vortices[0]    # Mossy Meadow -> Current Hollows
	var v23: Vortex = g.vortices[1]    # Current Hollows -> Giant Stems
	var v14: Vortex = g.vortices[2]    # Mossy Meadow -> Terrace Steps
	var v25: Vortex = g.vortices[3]    # Current Hollows -> Reed Canyon

	# First arrival on Current Hollows: the view, about 3 s, then control straight back.
	await _ride(v12, false)
	var opened := bv.active and bv.auto_s > 0.0 and bv.arrivals_shown == n0 + 1 and p.ball == g.balls[1]
	var w := await _watch(bv)
	var secs := float(w[0]) / 60.0
	var at := p.global_position
	var back := not bv.active and not g.get_tree().paused and g.hud.visible and p.controls_enabled and p.state == "normal" \
			and cam.process_mode == Node.PROCESS_MODE_INHERIT and not cam.cinematic and g.cinematic == ""
	p.bot_input = Vector2(0, 1)
	await t.seconds(0.6)
	p.bot_input = Vector2.ZERO
	var walked := p.global_position.distance_to(at)
	t.check("arrival_view_plays_on_first_arrival", opened and String(w[3]).begins_with("Current Hollows") and String(w[3]).contains("skip"),
			"opened %s, shown %d, caption '%s'" % [opened, bv.arrivals_shown - n0, String(w[3]).replace("\n", " / ")])
	t.check("arrival_view_about_3s_and_held_safe", secs > 2.4 and secs < 3.6 and bool(w[2]),
			"%.2f s, run held still (no move, hurt, clock or processing) %s" % [secs, w[2]])
	t.check("arrival_view_smooth_camera", float(w[1]) < 2.5 and float(w[4]) < 0.3,
			"largest camera step %.2f m/frame, %.2f m the frame after control returned" % [w[1], w[4]])
	t.check("arrival_view_control_restored", back and walked > 1.0, "back %s, walked %.2f m in 0.6 s" % [back, walked])
	# Saved at once (the landing's save), so a reload never plays it again.
	var rs := RunSave.open(g.run_save.path)
	var saved_seen: Array = (rs.run().get("world", {}) as Dictionary).get("balls_seen", [])
	var reloaded := Game.seen_from_save(rs.run().get("world", {}), rs.earned(), links)
	t.check("arrival_seen_saved_round_trip", saved_seen.has("b2") and reloaded.keys() == g.seen_list() and g.seen_list() == ["b2"],
			"saved %s, reloaded %s, live %s" % [saved_seen, reloaded.keys(), g.seen_list()])

	# Never on Ball 1 (the tutorial's reveal is its view), never a second time.
	await _ride(v12, true)
	var on_b1 := bv.active
	await t.frames(5)
	await _ride(v12, false)
	var again := bv.active
	await t.frames(5)
	t.check("arrival_view_not_on_second_arrival", not on_b1 and not again and bv.arrivals_shown == n0 + 1 and p.ball == g.balls[1],
			"ball 1 %s, second arrival %s, shown %d" % [on_b1, again, bv.arrivals_shown - n0])
	# Not after a death (he re-forms at the arrival point).
	g._die("hurt")
	var f := 0
	while (g.cinematic != "" or p.state != "normal") and f < 60 * 10:
		await t.frames(1)
		f += 1
	await t.frames(5)
	t.check("arrival_view_not_after_death", not bv.active and bv.arrivals_shown == n0 + 1 and p.ball == g.balls[1] and p.state == "normal",
			"active %s, shown %d, ball %d" % [bv.active, bv.arrivals_shown - n0, p.ball.index + 1])
	# Not after a reload: the saved set as the next launch reads it.
	g.balls_seen = Game.seen_from_save(RunSave.open(g.run_save.path).run().get("world", {}), {}, links)
	await _ride(v12, true)
	await _ride(v12, false)
	var after_reload := bv.active
	await t.frames(5)
	t.check("arrival_view_not_after_reload", not after_reload and bv.arrivals_shown == n0 + 1, "")

	# Any press skips it (after the opening grace); control comes back the same way.
	await _ride(v23, false)
	var opened2 := bv.active
	var w2 := await _watch(bv, 0.6)
	var back2 := not bv.active and not g.get_tree().paused and p.controls_enabled and g.hud.visible
	t.check("arrival_view_skipped_by_input", opened2 and float(w2[0]) / 60.0 < 1.8 and back2 and float(w2[4]) < 0.3,
			"opened %s, back after %.2f s, control %s" % [opened2, float(w2[0]) / 60.0, back2])

	# An old save: balls it shows he has been on stay quiet, one he has not been on still plays.
	g.balls_seen = Game.seen_from_save({"ball": 0, "stats": {"travels": [[0, false]]}}, {}, links)
	await _ride(v14, false)
	var quiet := not bv.active
	await t.frames(5)
	await _ride(v25, false)
	var plays := bv.active and p.ball == g.balls[4]
	if bv.active:
		await _watch(bv, 0.5)
	t.check("arrival_view_old_save_migration_live", quiet and plays, "Terrace Steps quiet %s, Reed Canyon plays %s" % [quiet, plays])

	# Off during a Treasure Hunt is in _arrived; off when the run is not in play (aquarium / title):
	# the due view is dropped, never shown late.
	g.balls_seen.erase("b3")
	var st := g.state
	g._arrived(g.balls[2])
	g.state = "aquarium"
	g._update_arrival_view()
	g.state = st
	var dropped := g._arrival_due.is_empty() and not bv.active and g.balls_seen.has("b3")
	t.check("arrival_view_dropped_outside_play", dropped, "")

	t.check("arrival_view_camera_never_unsafe", cam.unsafe_drawn == d0,
			"%d unsafe, %d corrected%s" % [cam.unsafe_drawn - d0, cam.corrected_frames - c0, "" if cam.unsafe_worst == "" else ": " + cam.unsafe_worst])
	# Back as it was.
	for v: Vortex in was:
		v.connected = was[v]
	g.arrival_views = keep["views"]
	g.balls_seen = keep["seen"]
	g.arrival = keep["arrival"]
	g.checkpoint = keep["checkpoint"]
	for r in holds:
		r.call()
	var b0: MossBall = g.balls[0]
	u.place_at(0, b0.surface_point(b0.start_dir, 0.2), MossBall.frame_at(b0.start_dir, 0).z)
	p.restore_full()
	await t.frames(3)
