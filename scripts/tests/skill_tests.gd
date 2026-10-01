extends RefCounted
## Skill tree, red starfish and Glide checks (docs/SKILL_TREE.md). Called from unit_tests.gd, whose
## helpers (place, press, stick_toward, wait_grounded, _climb ...) they use through `u`.

var u
var t
var g: Game
var p: Axolotl


func _init(p_u) -> void:
	u = p_u
	t = u.t
	g = u.g
	p = u.p


func tiers(d := {}) -> void:
	p.apply_skills(d)


func _ll(b: MossBall, pos: Vector3) -> Vector2:
	return Levels._latlon(b.up_at(pos))


func _v(p3: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [p3.x, p3.y, p3.z]


## Every restoration gate shut (false) or open (true), as the world is before or after healing.
## Returns the previous states, for _gates_restore.
func _gates(open: bool) -> Array:
	var prev := []
	for b in g.balls:
		for gt in b.gates:
			var rg: RestorationGate = gt
			prev.append([rg, rg.is_open])
			_gate_set(rg, open)
	await t.frames(3)
	return prev


func _gate_set(rg: RestorationGate, open: bool) -> void:
	if open:
		rg.open(false)
		return
	rg.is_open = false
	rg._t = -1.0
	var sync := rg.sync_to_physics
	rg.sync_to_physics = false
	rg._apply(0.0)
	rg.sync_to_physics = sync
	PhysicsServer3D.body_set_state(rg.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, rg.global_transform)
	rg.remove_meta("settled")


func _gates_restore(prev: Array) -> void:
	for e in prev:
		_gate_set(e[0], e[1])
	await t.frames(3)


# --- The graph ----------------------------------------------------------------------------------

## The owner's proof, kept as a test: over the graph as shipped (data), no cycles, all 15 reachable,
## 30 in all, and no reachable purchase state deadlocks (all 2^15 subsets); plus the checker's own
## negative tests (a cycle, and too few starfish, are caught).
func graph() -> void:
	var r := SkillTree.prove(StarfishTable.COUNT)
	t.check("skilltree_graph_proof", r["ok"] and r["acyclic"] and r["reachable"] and r["total"] == 30 and r["deadlocks"] == 0 and not r["bad_ref"],
			"acyclic %s, all 15 reachable %s, total %d, %d reachable purchase states, %d deadlocks" % [r["acyclic"], r["reachable"], r["total"], r["states"], r["deadlocks"]])
	var roots: Array = r["roots"]
	roots.sort()
	t.check("skilltree_roots_and_cross_links", roots == ["burst.1", "lunge.1", "quick.1"] and r["cross"] == 9 and SkillTree.NODES.size() == 15,
			"roots %s, %d cross-family prerequisites" % [str(roots), r["cross"]])
	var costs_ok := true
	for n in SkillTree.NODES:
		costs_ok = costs_ok and int(n["cost"]) == int(n["tier"]) and (int(n["tier"]) == 1 or (n["requires"] as Array).has("%s.%d" % [n["family"], int(n["tier"]) - 1]))
	t.check("skilltree_costs_by_tier", costs_ok, "")
	var cyc: Array = SkillTree.NODES.duplicate(true)
	cyc[0]["requires"] = ["lunge.3"]
	var rc := SkillTree.prove(30, cyc)
	var rp := SkillTree.prove(29)
	t.check("skilltree_checker_catches_bad_graphs", not rc["ok"] and not rc["acyclic"] and not rp["ok"] and not rp["reachable"] and rp["deadlocks"] > 0,
			"with a cycle: acyclic %s; with 29 starfish: full %s, %d deadlocks" % [rc["acyclic"], rp["reachable"], rp["deadlocks"]])
	var ids := {}
	var balls := {}
	var shaped := true
	var re := RegEx.create_from_string("^star\\.b([1-7])\\.[0-9]{2}$")
	for s in StarfishTable.STARS:
		ids[s["id"]] = true
		balls[int(s["ball"])] = true
		var m := re.search(s["id"])
		shaped = shaped and m != null and int(m.get_string(1)) == int(s["ball"]) and not s.has("requires")
	t.check("starfish_table_thirty_permanent_ids", StarfishTable.STARS.size() == 30 and ids.size() == 30 and balls.size() == 7 and shaped,
			"%d starfish, %d unique ids, on %d balls, none needs a skill" % [StarfishTable.STARS.size(), ids.size(), balls.size()])


# --- Loss-proof persistence --------------------------------------------------------------------

func _doc(collected: Array, purchased: Array, seq := 1, fmt := 1) -> Dictionary:
	var c := {}
	for id in collected:
		c[id] = {"t": 1, "v": GameVersion.GAME_VERSION}
	var pd := {}
	for id in purchased:
		pd[id] = {"cost": SkillTree.cost(id) if SkillTree.has(id) else 2, "t": 1, "n": 1}
	return {"format": fmt, "kind": GillProgress.KIND, "seq": seq, "collected": c, "purchased": pd}


func _write(path: String, txt: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(txt)
	f.close()


## A state is valid: every counted id is a real starfish, every purchase a real node, balance =
## collected - spent (>= 0), and no node's effect without its record.
func _valid(gp: GillProgress) -> bool:
	for id in gp.collected:
		if not StarfishTable.has(id):
			return false
	for id in gp.purchased:
		if not SkillTree.has(id):
			return false
	return gp.balance() == maxi(0, gp.stars() - gp.spent())


## The loss-proof matrix (owner ruling 7): every interrupted or damaged state reconciles to a valid
## one, and no collected starfish or purchase is lost.
func store() -> void:
	var S := StarfishTable.ids()
	var base := "user://t_gp_"
	var rows: Array[String] = []
	var ok_all := true
	# 1. Normal: collect, buy, reopen.
	var path := base + "normal.json"
	GillProgress.erase(path)
	var gp := GillProgress.open(path)
	var fresh := gp.origin == "new" and gp.stars() == 0 and gp.balance() == 0
	for i in 3:
		gp.collect(S[i])
	var bought := gp.buy("lunge.1") == ""
	var locked := gp.buy("lunge.3")
	var poor := gp.buy("lunge.2")
	var re := GillProgress.open(path)
	var ok := fresh and bought and locked == "locked" and poor != "" and re.stars() == 3 and re.owns("lunge.1") and re.balance() == 2 and _valid(re)
	t.check("progress_normal_roundtrip", ok, "fresh %s, 3 collected, lunge.1 bought, lunge.3 %s, lunge.2 %s; reopened: %d stars, balance %d (derived, never stored)" % [fresh, locked, poor, re.stars(), re.balance()])
	var stored := FileAccess.get_file_as_string(path)
	t.check("progress_balance_never_stored", not stored.contains("balance") and stored.contains("\"collected\"") and stored.contains("\"purchased\""), "")
	# 2. Truncated main with a good backup.
	path = base + "trunc.json"
	GillProgress.erase(path)
	_write(path + ".bak", JSON.stringify(_doc(S.slice(0, 5), ["lunge.1", "quick.1"], 7)))
	var full := JSON.stringify(_doc(S.slice(0, 6), ["lunge.1", "quick.1", "burst.1"], 8))
	_write(path, full.substr(0, full.length() / 2))
	gp = GillProgress.open(path)
	ok = gp.stars() == 5 and gp.skills() == 2 and gp.origin.begins_with("recovered") and _valid(gp) and GillProgress._read(path)["ok"]
	rows.append("truncated main + good .bak -> %d stars, %d skills (%s)" % [gp.stars(), gp.skills(), gp.origin])
	ok_all = ok_all and ok
	# 3. Corrupt (garbage) main with a good backup.
	path = base + "corrupt.json"
	GillProgress.erase(path)
	_write(path + ".bak", JSON.stringify(_doc(S.slice(0, 4), ["burst.1"], 3)))
	_write(path, "\u0000\u0007{{not json")
	gp = GillProgress.open(path)
	ok = gp.stars() == 4 and gp.owns("burst.1") and _valid(gp)
	rows.append("corrupt main + good .bak -> %d stars, burst.1 %s" % [gp.stars(), gp.owns("burst.1")])
	ok_all = ok_all and ok
	# 4. Both files present (the .bak one write older): the newer, whole, wins (union).
	path = base + "both.json"
	GillProgress.erase(path)
	_write(path + ".bak", JSON.stringify(_doc(S.slice(0, 4), ["burst.1"], 3)))
	_write(path, JSON.stringify(_doc(S.slice(0, 5), ["burst.1", "glide.1"], 4)))
	gp = GillProgress.open(path)
	ok = gp.stars() == 5 and gp.owns("glide.1") and gp.balance() == 3 and _valid(gp)
	rows.append("main + older .bak -> %d stars, %d skills, balance %d" % [gp.stars(), gp.skills(), gp.balance()])
	ok_all = ok_all and ok
	# 5. A write interrupted between the temp file and the rename: the new document is recovered.
	path = base + "tmp.json"
	GillProgress.erase(path)
	gp = GillProgress.open(path)
	for i in 2:
		gp.collect(S[i])
	gp.collected[S[2]] = {"t": 1}
	gp.purchased["quick.1"] = {"cost": 1, "t": 1, "n": 1}
	gp.save("tmp")
	var mid_main := GillProgress._read(path)
	gp = GillProgress.open(path)
	ok = mid_main["ok"] and (mid_main["data"]["collected"] as Dictionary).size() == 2 and gp.stars() == 3 and gp.owns("quick.1") and _valid(gp)
	rows.append("interrupted after .tmp, before the rename -> main had 2, recovered %d stars + quick.1 %s" % [gp.stars(), gp.owns("quick.1")])
	ok_all = ok_all and ok
	# 6. A write that failed to complete .tmp (truncated): nothing changes, and a stray broken .tmp is
	# ignored at load.
	path = base + "badtmp.json"
	GillProgress.erase(path)
	gp = GillProgress.open(path)
	gp.collect(S[0])
	gp.collected[S[1]] = {"t": 1}
	var saved := gp.save("verify")
	_write(path + ".tmp", "{\"format\": 1, \"kind\": \"mote.gill_pro")
	gp = GillProgress.open(path)
	ok = not saved and gp.stars() == 1 and _valid(gp)
	rows.append("truncated .tmp -> the write reports failure, main keeps %d star" % gp.stars())
	ok_all = ok_all and ok
	# 7. Unknown ids: a newer table's starfish and node are kept in the file but not counted (the
	# node's cost IS counted as spent, so nothing is minted); garbage is dropped.
	path = base + "unknown.json"
	GillProgress.erase(path)
	var d := _doc(S.slice(0, 4) + ["star.b8.00", "starfish!!"], ["lunge.1", "wings.1", "lunge"], 2)
	(d["purchased"] as Dictionary)["bogus.2"] = "x"
	_write(path, JSON.stringify(d))
	gp = GillProgress.open(path)
	gp.collect(S[5])
	var back: Dictionary = GillProgress._read(path)["data"]
	ok = gp.stars() == 5 and gp.skills() == 1 and gp.spent() == 3 and gp.balance() == 2 and _valid(gp) \
			and (back["collected"] as Dictionary).has("star.b8.00") and (back["purchased"] as Dictionary).has("wings.1") \
			and not (back["collected"] as Dictionary).has("starfish!!") and not (back["purchased"] as Dictionary).has("bogus.2")
	rows.append("unknown ids -> counted %d stars, %d skills, spent %d (a newer node's cost counts), kept in file: star.b8.00 %s, wings.1 %s; garbage dropped" % [gp.stars(), gp.skills(), gp.spent(),
			(back["collected"] as Dictionary).has("star.b8.00"), (back["purchased"] as Dictionary).has("wings.1")])
	ok_all = ok_all and ok
	# 8. A hand-edited over-spend: every node with 3 starfish. Nothing is revoked, the balance shows 0.
	path = base + "over.json"
	GillProgress.erase(path)
	_write(path, JSON.stringify(_doc(S.slice(0, 3), SkillTree.ids(), 5)))
	gp = GillProgress.open(path)
	ok = gp.skills() == 15 and gp.balance() == 0 and gp.overspent == 27 and gp.tier("glide") == 3 and _valid(gp) and gp.buy("lunge.1") == "owned"
	rows.append("hand-edited over-spend (15 nodes, 3 starfish) -> 15 kept, balance %d, over by %d, logged" % [gp.balance(), gp.overspent])
	ok_all = ok_all and ok
	# 9. A purchase whose prerequisites are missing (a hand edit or an older tree): never revoked.
	path = base + "prereq.json"
	GillProgress.erase(path)
	_write(path, JSON.stringify(_doc(S.slice(0, 10), ["glide.3"], 5)))
	gp = GillProgress.open(path)
	ok = gp.owns("glide.3") and gp.tier("glide") == 3 and gp.balance() == 7 and _valid(gp)
	rows.append("glide.3 without its prerequisites -> kept (tier %d), balance %d" % [gp.tier("glide"), gp.balance()])
	ok_all = ok_all and ok
	# 10. A newer format: read for play, never written.
	path = base + "newer.json"
	GillProgress.erase(path)
	var nd := _doc(S.slice(0, 2), ["burst.1"], 9, GillProgress.FORMAT + 1)
	nd["future"] = {"x": 1}
	var ntxt := JSON.stringify(nd)
	_write(path, ntxt)
	gp = GillProgress.open(path)
	var wrote := gp.collect(S[3])
	ok = gp.read_only and gp.stars() == 3 and gp.owns("burst.1") and FileAccess.get_file_as_string(path) == ntxt and gp.buy("lunge.1") == "read-only"
	rows.append("newer format -> read-only: plays with %d stars, the file is byte-identical" % gp.stars())
	ok_all = ok_all and ok and wrote
	# 11. A purchase that cannot be saved is not made ("spent but not unlocked" is impossible).
	path = "user://no_such_dir/gp.json"
	gp = GillProgress.open(path)
	gp.collected[S[0]] = {"t": 1}
	var why := gp.buy("lunge.1")
	ok = why == "not saved" and not gp.owns("lunge.1") and gp.balance() == 1
	rows.append("unwritable disk -> buy says %s, nothing bought, balance %d" % [why, gp.balance()])
	ok_all = ok_all and ok
	# 12. A starfish touched but not yet written when the app died stays in the world.
	path = base + "crash.json"
	GillProgress.erase(path)
	gp = GillProgress.open(path)
	gp.collect(S[0])
	gp.collected[S[1]] = {"t": 1}
	gp = GillProgress.open(path)
	ok = gp.has_star(S[0]) and not gp.has_star(S[1])
	rows.append("touched, not written -> %s kept, %s back in the world" % [S[0], S[1]])
	ok_all = ok_all and ok
	t.check("progress_loss_proof_matrix", ok_all, "; ".join(rows))
	# The store is its own file: New Run's run save never touches it, and settings.cfg is not used.
	var gpath := Game.gill_progress_path()
	var before := FileAccess.get_file_as_string(gpath) if FileAccess.file_exists(gpath) else ""
	g.run_save.save()
	var after := FileAccess.get_file_as_string(gpath) if FileAccess.file_exists(gpath) else ""
	t.check("progress_own_file_not_run_or_settings", before == after and gpath != Game.run_save_path() and not gpath.ends_with(".cfg") and GillProgress.PATH == "user://gill_progress.json",
			gpath)
	for suffix in ["normal", "trunc", "corrupt", "both", "tmp", "badtmp", "unknown", "over", "prereq", "newer", "crash"]:
		GillProgress.erase(base + suffix + ".json")


# --- Starfish spots ---------------------------------------------------------------------------------

## Survey (by name only): each table spot, its validators, clearances and a relocation if needed.
func survey() -> void:
	var only_ids := str(Settings.test_args.get("stars", "")).split(",", false)
	for e in StarfishTable.STARS:
		if not only_ids.is_empty() and not only_ids.has(e["id"]):
			continue
		var b: MossBall = g.balls[int(e["ball"]) - 1]
		var keep := Starfish.keep_clear_points(b)
		var ll: Array = e["ll"]
		var dir := MossBall.dir_ll(float(ll[0]), float(ll[1]))
		var hit := Starfish.probe(b, dir, float(e["alt"]))
		if hit.is_empty():
			t.log_line("STSURV %s no surface" % e["id"])
			continue
		var pos: Vector3 = hit[0]
		var sc := StarfishTable.SCALE
		var parts := "perch %s approach %s vort %s spot %s" % [TreasureHunt.perch_ok(b, pos, sc), TreasureHunt.perch_approach(b, pos, sc),
				TreasureHunt.clear_of_vortices(b, pos), TreasureHunt.spot_ok(b, pos, sc)]
		# (Authoring: relocations aim for a margin over the 1.5 m rule.)
		var r := Starfish.resolve(b, e, keep, float(Settings.test_args.get("margin", "1.75")))
		var np: Vector3 = r["pos"]
		var nll := _ll(b, np)
		if not r["valid"]:
			# A fine grid over the same surface: the valid point with the most room.
			var upv := b.up_at(pos)
			var frm := MossBall.frame_at(upv, 0.0)
			var best := Vector3.INF
			var best_c := 0.0
			for ix in range(-30, 31):
				for iz in range(-30, 31):
					var o := pos + frm.x * ix * 0.1 + frm.z * iz * 0.1
					var hh := Starfish.probe(b, (o - b.global_position).normalized(), b.altitude(pos))
					if hh.is_empty() or hh[1] != hit[1]:
						continue
					if Starfish.spot_valid(b, hh[0], e["kind"], keep):
						var cc := Starfish.clearance(hh[0], keep)
						if cc > best_c:
							best_c = cc
							best = hh[0]
			if best != Vector3.INF:
				var bl := _ll(b, best)
				t.log_line("STGRID %s most room on the same surface: ll=%.2f,%.2f alt=%.2f clear %.2f, %.2f m away" % [e["id"], bl.x, bl.y, b.altitude(best), best_c, best.distance_to(pos)])
			for h in (b.get_meta("builder") as LevelBuilder).bot_hints:
				if not h.has("tops"):
					continue
				for tp in h["tops"]:
					var tpos: Vector3 = tp
					if tpos.distance_to(pos) > 16.0:
						continue
					var tll := _ll(b, tpos)
					var alt_t := b.altitude(tpos)
					var alt_e := {"id": e["id"], "ll": [tll.x, tll.y], "alt": alt_t, "kind": e["kind"]}
					var rr := Starfish.resolve(b, alt_e, keep, 1.75)
					if rr["valid"]:
						var q: Vector3 = rr["pos"]
						var qll := _ll(b, q)
						t.log_line("STALT %s route %s top alt %.2f -> ll=%.2f,%.2f alt=%.2f clear %.2f, %.1f m from the table spot" % [e["id"], h["route"], alt_t, qll.x, qll.y, b.altitude(q), Starfish.clearance(q, keep), q.distance_to(pos)])
		t.log_line("STSURV %s kind %s alt %.2f col %s clear %.2f valid %s | %s | resolved valid %s relocated %s -> ll=%.2f,%.2f alt=%.2f clear %.2f moved %.2f" % [
				e["id"], e["kind"], b.altitude(pos), (hit[1] as Node).name, Starfish.clearance(pos, keep), Starfish.spot_valid(b, pos, e["kind"], keep), parts,
				r["valid"], r["relocated"], nll.x, nll.y, b.altitude(np), Starfish.clearance(np, keep), np.distance_to(pos)])
	t.check("starfish_survey_ran", true, "")


## Every table spot holds as authored (no relocation), by Treasure Hunt's own validators for its
## kind, at least 1.5 m from every Mote anchor, bloom, shrine and cave reward: with the world
## unrestored (every restoration gate shut) and restored (every gate open). And a spot that no
## longer holds is moved to the nearest valid point on the same feature, keeping its id.
func spots() -> void:
	var rows := {}
	var bad: Array[String] = []
	var min_clear := INF
	var kinds := {}
	for state in ["unrestored", "restored"]:
		var prev: Array = await _gates(state == "restored")
		for e in StarfishTable.STARS:
			var b: MossBall = g.balls[int(e["ball"]) - 1]
			var keep := Starfish.keep_clear_points(b)
			var r := Starfish.resolve(b, e, keep)
			var pos: Vector3 = r["pos"]
			var c := Starfish.clearance(pos, keep)
			min_clear = minf(min_clear, c)
			kinds[e["kind"]] = int(kinds.get(e["kind"], 0)) + (1 if state == "restored" else 0)
			if not r["valid"] or r["relocated"]:
				bad.append("%s %s: valid %s relocated %s clear %.2f" % [e["id"], state, r["valid"], r["relocated"], c])
		await _gates_restore(prev)
		rows[state] = true
	t.check("starfish_spots_valid_unrestored_and_restored", bad.is_empty(), "30 spots x 2 world states; min clearance %.2f m; kinds %s; %s" % [min_clear, str(kinds), "; ".join(bad)])
	t.check("starfish_spots_clear_of_motes_blooms_shrines_rewards", min_clear >= StarfishTable.CLEAR, "min %.2f m" % min_clear)
	# Relocation: pretend something now stands on two authored spots (a ground one and a rock one);
	# each moves to the nearest valid point on the same surface, its id kept.
	var moved: Array[String] = []
	var reloc_ok := true
	for id in ["star.b1.00", "star.b4.01"]:
		var e := StarfishTable.entry(id)
		var b: MossBall = g.balls[int(e["ball"]) - 1]
		var keep := Starfish.keep_clear_points(b)
		var r0 := Starfish.resolve(b, e, keep)
		var hit0 := Starfish.probe(b, MossBall.dir_ll(e["ll"][0], e["ll"][1]), float(e["alt"]))
		keep.append(r0["pos"])
		var r1 := Starfish.resolve(b, e, keep)
		var p1: Vector3 = r1["pos"]
		var hit1 := Starfish.probe(b, b.up_at(p1), b.altitude(p1))
		var same: bool = not hit1.is_empty() and hit1[1] == hit0[1]
		var d := p1.distance_to(r0["pos"])
		reloc_ok = reloc_ok and r1["valid"] and r1["relocated"] and same and d >= StarfishTable.CLEAR and d <= 3.2
		moved.append("%s moved %.2f m, same feature %s" % [id, d, same])
	t.check("starfish_invalid_spot_relocates_on_same_feature", reloc_ok, ", ".join(moved))
	# The field in play placed every one as authored.
	var rep: Dictionary = g.starfish.report
	var authored := rep.values().filter(func(v) -> bool: return v == "authored").size()
	var had := rep.values().filter(func(v) -> bool: return v == "collected").size()
	t.check("starfish_field_places_all_thirty", g.starfish.placed and authored + had == 30 and rep.size() == 30,
			"%d placed as authored, %d already collected, none relocated or invalid" % [authored, had])


## Touch pickup (no button, no lunge): walking into one collects it, and so does passing it in the
## air; it is written at once (one document, the balance derived); the HUD chip shows; its sound is
## its own. Nothing is picked up during a cinematic.
func pickup() -> void:
	var gp := g.gill
	var n0 := gp.stars()
	var ground: Array[Starfish] = []
	for id in ["star.b1.00", "star.b2.00", "star.b3.04", "star.b5.01", "star.b1.05", "star.b2.04", "star.b5.03"]:
		if g.starfish.find(id) != null:
			ground.append(g.starfish.find(id))
	if ground.size() < 3:
		t.check("starfish_touch_pickup_walking", false, "fewer than 3 ground starfish left to test with")
		return
	# Walk into one on open ground. (A spot left awkward by earlier suite tests, e.g. a wedge on the
	# way in, is logged and the next one tried: the check is that walking in collects it.)
	var s: Starfish = null
	var sid := ""
	var sp := Vector3.ZERO
	var b: MossBall = null
	var up := Vector3.UP
	var fr := Basis()
	var from := Vector3.ZERO
	var acts := [0]
	var count := func() -> void: acts[0] += 1
	for attempt in mini(3, ground.size()):
		s = ground[attempt]
		sid = s.id
		sp = s.pick_point()
		b = s.ball
		up = b.up_at(sp)
		fr = MossBall.frame_at(up, 0.0)
		from = b.surface_point(b.up_at(sp + fr.z * 3.0), 0.1)
		u.place_at(b.index, from, sp - from)
		await u.wait_grounded()
		# (No button: nothing he does on purpose happens on the way in.)
		acts[0] = 0
		for sg in [p.jumped, p.lunged, p.swiped, p.burst_used]:
			sg.connect(count)
		for a in ["jump", "lunge", "swipe", "special"]:
			Input.action_release(a)
		for i in 150:
			u.stick_toward(sp - p.global_position)
			await t.frames(1)
			if gp.has_star(sid):
				break
		p.bot_input = Vector2.ZERO
		for sg in [p.jumped, p.lunged, p.swiped, p.burst_used]:
			sg.disconnect(count)
		if gp.has_star(sid):
			break
		t.log_line("STARFISH WALK %s not reached: state %s, controls %s, game %s, cinematic '%s', %.1f m from it" % [sid, p.state,
				p.controls_enabled, g.state, g.cinematic, p.global_position.distance_to(sp)])
		n0 = gp.stars()
	var on_disk: Dictionary = GillProgress._read(gp.path).get("data", {})
	var walked: bool = gp.has_star(sid) and acts[0] == 0 and (on_disk.get("collected", {}) as Dictionary).has(sid)
	t.check("starfish_touch_pickup_walking", walked and gp.stars() == n0 + 1 and gp.balance() == gp.stars() - gp.spent(),
			"%s collected by walking into it, %d actions; on disk at once; %d collected (was %d), balance %d; state %s, %.1f m from it, hostiles within 15 m: %d"
			% [sid, acts[0], gp.stars(), n0, gp.balance(), p.state, p.global_position.distance_to(sp),
			b.hostiles().filter(func(h: Node) -> bool: return h.is_alive() and (h as Node3D).global_position.distance_to(p.global_position) < 15.0).size()])
	t.check("starfish_hud_chip_shows", g.hud.star_chip.showing() and g.hud.star_chip.text == "%d/30" % gp.stars(), g.hud.star_chip.text)
	await t.frames(30)
	t.check("starfish_gone_after_pickup", not is_instance_valid(s) or s.collected, "")
	# In the air: jump over one and pass through it.
	s = ground[1]
	sid = s.id
	sp = s.pick_point()
	var b2 := s.ball
	up = b2.up_at(sp)
	fr = MossBall.frame_at(up, 0.0)
	from = b2.surface_point(b2.up_at(sp - fr.z * 2.2), 0.1)
	u.place_at(b2.index, from, sp - from)
	await u.wait_grounded()
	await t.frames(10)
	var airborne_at_pick := false
	u.stick_toward(sp - p.global_position)
	await u.press("jump")
	for i in 120:
		u.stick_toward(sp - p.global_position)
		await t.frames(1)
		if gp.has_star(sid):
			airborne_at_pick = not p.grounded
			break
	p.bot_input = Vector2.ZERO
	await u.wait_grounded()
	t.check("starfish_touch_pickup_in_air", gp.has_star(sid) and airborne_at_pick, "%s collected mid-jump: %s" % [sid, airborne_at_pick])
	# Not while his controls are taken (a cinematic).
	s = ground[2]
	sid = s.id
	var b3 := s.ball
	p.controls_enabled = false
	u.place_at(b3.index, s.pick_point() + b3.up_at(s.pick_point()) * 0.1, MossBall.frame_at(b3.up_at(s.pick_point()), 0.0).z)
	await t.frames(5)
	var during := gp.has_star(sid)
	p.controls_enabled = true
	await t.frames(5)
	t.check("starfish_no_pickup_in_cinematic", not during and gp.has_star(sid), sid)
	# Its own sound: present, and not the Mote capture or the reward chime.
	var files := {}
	for nm in ["starfish", "skill_unlock", "mote_capture", "upgrade"]:
		# (The loaded sound, not the source file: an exported pack carries only the imported sample.)
		var path := "res://assets/audio/sfx_%s.wav" % nm
		var snd: AudioStreamWAV = load(path) as AudioStreamWAV if ResourceLoader.exists(path) else null
		files[nm] = snd.data.size() if snd != null else 0
	var st: AudioStream = Sfx.inst.stream("starfish")
	var su: AudioStream = Sfx.inst.stream("skill_unlock")
	t.check("starfish_and_unlock_sounds_distinct", st != null and su != null and st != Sfx.inst.stream("mote_capture") and st != Sfx.inst.stream("upgrade") and files["starfish"] > 0 and files["starfish"] != files["mote_capture"],
			str(files))


# --- The page -----------------------------------------------------------------------------------

func _states(page: SkillTreePage) -> Dictionary:
	var out := {}
	for id in page.buttons:
		out[id] = str((page.buttons[id] as Button).get_meta("state", ""))
	return out


func _nav(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	g.get_viewport().push_input(ev)
	await t.frames(1)
	ev = InputEventAction.new()
	ev.action = action
	ev.pressed = false
	g.get_viewport().push_input(ev)
	await t.frames(2)


## The skill tree page: reached from the pause menu and the title, the game stands still while it is
## open, node states and links, the card says exactly what is missing and what a node does before
## it is bought, buying applies at once, controller focus moves between nodes, and it fits.
func ui() -> void:
	var gp := g.gill
	var keep_c := gp.collected.duplicate(true)
	var keep_p := gp.purchased.duplicate(true)
	gp.collected.clear()
	gp.purchased.clear()
	for id in StarfishTable.ids().slice(0, 5):
		gp.collected[id] = {"t": 1}
	gp.purchased["lunge.1"] = {"cost": 1, "t": 1, "n": 1}
	gp.save()
	p.apply_skills(gp.tiers())
	var pm := g.pause_menu
	pm.open()
	await t.frames(2)
	pm._open_skills()
	await t.frames(3)
	var page := pm.skill_page
	var run0 := g.clock.run_s
	await t.frames(40)
	t.check("skill_page_from_pause_game_stands_still", page.visible and g.get_tree().paused and absf(g.clock.run_s - run0) < 0.0001 and not pm._panel.visible,
			"paused %s, clock moved %.3f s" % [g.get_tree().paused, g.clock.run_s - run0])
	var st := _states(page)
	t.check("skill_page_node_states", st["lunge.1"] == "purchased" and st["quick.1"] == "available" and st["magnet.1"] == "available" and st["lunge.2"] == "locked" and st["glide.1"] == "locked" and st["glide.3"] == "locked",
			str(st))
	page.select("lunge.3")
	var need_locked := page._card_need.text
	t.check("skill_card_locked_says_what_is_missing", page._card_state.text == "Locked" and need_locked.begins_with("Unlock Lunge II and Mote Magnet II first.") and page._buy.disabled, need_locked)
	page.select("quick.1")
	var eff := page._card_effect.text
	t.check("skill_card_shows_effect_before_buying", eff == SkillTree.EFFECTS["quick.1"] and not page._buy.disabled and not gp.owns("quick.1") and page._card_need.text.contains("Costs 1"), eff)
	var bal0 := gp.balance()
	var why := page.buy("quick.1")
	await t.frames(4)
	var disk: Dictionary = GillProgress._read(gp.path)["data"]
	t.check("skill_unlock_applies_at_once", why == "" and gp.owns("quick.1") and gp.balance() == bal0 - 1 and absf(p._run_scale - 1.06) < 0.0001 and (disk["purchased"] as Dictionary).has("quick.1") and page.flash_amount() > 0.0,
			"balance %d -> %d, run scale %.2f, on disk, flourish %.2f" % [bal0, gp.balance(), p._run_scale, page.flash_amount()])
	# Spend down to 0, then a 2-cost node reads as unaffordable with the exact shortfall.
	page.buy("burst.1")
	page.buy("magnet.1")
	page.buy("glide.1")
	page.select("quick.2")
	t.check("skill_card_unaffordable_says_shortfall", gp.balance() == 0 and _states(page)["quick.2"] == "unaffordable" and page._card_need.text.begins_with("Needs 2 red starfish; you have 0. Find 2 more.") and page._buy.disabled,
			page._card_need.text)
	var refused := page.buy("quick.2")
	t.check("skill_no_buy_when_unaffordable_or_locked", refused == "unaffordable" and page.buy("lunge.3") == "locked" and gp.skills() == 5, "%s" % refused)
	# Controller: focus moves between node buttons.
	(page.buttons["lunge.1"] as Button).grab_focus()
	await t.frames(2)
	var f0 := g.get_viewport().gui_get_focus_owner()
	await _nav("ui_right")
	var f1 := g.get_viewport().gui_get_focus_owner()
	await _nav("ui_down")
	var f2 := g.get_viewport().gui_get_focus_owner()
	t.check("skill_page_controller_focus", f0 == page.buttons["lunge.1"] and f1 == page.buttons["quick.1"] and f2 == page.buttons["quick.2"] and page.selected == "quick.2",
			"%s -> %s -> %s" % [f0.name if f0 else "none", f1.name if f1 else "none", f2.name if f2 else "none"])
	# Fits: every node inside the tree area and the screen, none overlapping, the card on screen.
	var vp := page.get_viewport_rect()
	var fits := true
	var rects: Array[Rect2] = []
	for id in page.buttons:
		var r := (page.buttons[id] as Button).get_global_rect()
		fits = fits and vp.encloses(r) and page.tree_area.get_global_rect().encloses(r)
		for q in rects:
			fits = fits and not q.intersects(r)
		rects.append(r)
	fits = fits and vp.encloses(page.card.get_global_rect()) and not page.card.get_global_rect().intersects(page.tree_area.get_global_rect())
	t.check("skill_page_fits_landscape", fits, "viewport %s" % str(vp.size))
	page.done.emit()
	await t.frames(3)
	t.check("skill_page_back_to_pause_menu", not page.visible and pm.visible and pm._panel.visible, "")
	var detail: String = pm._run_detail.text
	t.check("pause_shows_starfish_and_skills_separately", detail.contains("Red Starfish 5/30  ·  Skills 5/15"), detail.get_slice("\n", detail.count("\n")))
	pm.close()
	await t.frames(2)
	# From the title: straight to the page and back to the title.
	g.title._on_skills()
	await t.frames(3)
	var from_title := page.visible and pm.visible
	page.done.emit()
	await t.frames(3)
	t.check("skill_page_from_title", from_title and not page.visible and not pm.visible, "")
	# Finishes show the skills they were finished with (there is no skills-off mode).
	var keep_rec: Dictionary = g.run_save.data["records"].duplicate(true)
	var keep_fin: Dictionary = g.run_save.run()["finish"].duplicate(true)
	g.run_save.data["records"]["best_finish_s"] = -1.0
	g.run_save.record_finish(1234.5, 88.0, Completion.CATALOG_VERSION, Boot.identity(), gp.skills())
	var best := g.best_line()
	var fin_ok := best.ends_with("Skills %d/15" % gp.skills()) and g.finish_skills() == gp.skills() and int(g.run_save.run()["finish"]["skills"]) == gp.skills()
	g.run_save.data["records"] = keep_rec
	g.run_save.run()["finish"] = keep_fin
	t.check("finish_shows_skills", fin_ok, best)
	g.get_tree().paused = false
	gp.collected = keep_c
	gp.purchased = keep_p
	gp.save()
	p.apply_skills(gp.tiers())


# --- Movement skills ------------------------------------------------------------------------------

func _flat() -> void:
	u.place(0, -5, -150, 0.2, 0)
	p.invuln_t = 999
	await u.wait_grounded()
	await t.seconds(0.2)


func _hspeed() -> float:
	return (p.velocity - p.up * p.velocity.dot(p.up)).length()


## A run of `run_s`, then a jump straight on: [ground speed, takeoff-to-landing distance, speed
## 0.3 s into the air].
func _run_jump(run_s := 1.2) -> Array:
	await _flat()
	p.bot_input = Vector2(0, 1)
	await t.seconds(run_s)
	var sp := _hspeed()
	var at := p.global_position
	await u.press("jump")
	await t.seconds(0.3)
	var air_sp := _hspeed()
	await u.wait_grounded()
	var d := p.global_position - at
	d -= p.up * d.dot(p.up)
	p.bot_input = Vector2.ZERO
	await t.seconds(0.3)
	return [sp, d.length(), air_sp]


## Quick Gill scales the ground target only: ground speed x1.06 / 1.11 / 1.16, while the air target,
## and so every jump's reach, is unchanged.
func quick() -> void:
	var rows := []
	var base: Array = []
	var ok := true
	for q in 4:
		tiers({"quick": q})
		var r: Array = await _run_jump()
		if q == 0:
			base = r
		var want: float = SkillTree.TIERS["quick"]["run_scale"][q]
		var ratio: float = r[0] / base[0]
		var jd: float = r[1] / base[1]
		ok = ok and absf(ratio - want) < 0.015 and absf(jd - 1.0) < 0.03 and r[2] <= Axolotl.RUN_SPEED + 0.25
		rows.append("Q%d ground %.2f m/s (x%.3f), jump %.2f m (x%.3f), air speed %.2f" % [q, r[0], ratio, r[1], jd, r[2]])
	tiers()
	p.invuln_t = 0.0
	t.check("quick_gill_ground_only_jumps_unchanged", ok, "; ".join(rows))


## Lunge I reaches further; Lunge II steers with the stick; Lunge III catches from a little further.
## Treasure Hunt's own aim and reach are untouched (its constants; its stress test runs with L3).
func lunge() -> void:
	await _flat()
	var b := p.ball
	var saved_foods: Array = b.foods.duplicate()
	b.foods.clear()
	var travel := []
	for l in [0, 1]:
		tiers({"lunge": l})
		await _flat()
		var at := p.global_position
		await u.press("lunge")
		await t.seconds(0.6)
		var d := p.global_position - at
		d -= p.up * d.dot(p.up)
		travel.append(d.length())
	t.check("lunge1_reaches_further", travel[1] > travel[0] + 0.2 and travel[1] < travel[0] + 0.5, "L0 %.2f m, L1 %.2f m" % [travel[0], travel[1]])
	var turned := []
	for l in [1, 2]:
		tiers({"lunge": l})
		await _flat()
		await u.press("lunge")
		await t.frames(2)
		var f0 := p.facing
		u.stick_toward(f0.cross(p.up))
		await t.seconds(0.2)
		turned.append(rad_to_deg(f0.angle_to(p.facing)))
		p.bot_input = Vector2.ZERO
		await t.seconds(0.4)
	t.check("lunge2_steers_with_stick", turned[1] > 25.0 and turned[0] < 3.0, "turned L1 %.1f deg, L2 %.1f deg" % [turned[0], turned[1]])
	var caught := []
	for l in [0, 3]:
		tiers({"lunge": l})
		await _flat()
		var f: Food = u._spawn_food(Food.Type.DRIFTER)
		f.set_physics_process(false)
		# Beside him, outside the aim cone (no homing): 1.05 m from the lunge's sweep.
		var side := p.facing.cross(p.up)
		var want := p.body_center() + side * 1.05
		f.global_position += want - f.catch_point()
		await t.frames(2)
		await u.press("lunge")
		await t.seconds(0.4)
		caught.append(not is_instance_valid(f))
		if is_instance_valid(f):
			b.foods.erase(f)
			f.queue_free()
	t.check("lunge3_surer_catch", caught == [false, true], "1.05 m beside the sweep: L0 caught %s, L3 caught %s" % [caught[0], caught[1]])
	t.check("lunge_treasure_aim_and_reach_unchanged", TreasurePlay.REACH == 0.55 and TreasurePlay.AIM_RANGE == 3.6 and is_equal_approx(TreasurePlay.AIM_CONE, deg_to_rad(55.0)), "")
	for f in saved_foods:
		if is_instance_valid(f):
			b.foods.append(f)
	tiers()
	p.invuln_t = 0.0


## Up-only burst from the top of a jump: [highest point above the ground].
func _ceiling() -> float:
	await _flat()
	var p0 := p.global_position
	var up0 := p.up
	await u.press("jump")
	for i in 60:
		await t.frames(1)
		if p.velocity.dot(p.up) <= 0.0:
			break
	await u.press("jump")
	var top := 0.0
	for i in 90:
		await t.frames(1)
		top = maxf(top, (p.global_position - p0).dot(up0))
	await u.wait_grounded()
	return top


## Jump, directional burst at the top, stick held: distance takeoff -> landing.
func _burst_reach() -> float:
	await _flat()
	var at := p.global_position
	p.bot_input = Vector2(0, 1)
	await u.press("jump")
	for i in 60:
		await t.frames(1)
		if p.velocity.dot(p.up) <= 0.0:
			break
	await u.press("jump")
	await u.wait_grounded()
	var d := p.global_position - at
	d -= p.up * d.dot(p.up)
	p.bot_input = Vector2.ZERO
	return d.length()


## Water Burst I-III: the ceiling stays under the 3.9 m ledges (3.70 m or less), II carries further,
## III bends with the stick, and it is still once per air.
func burst() -> void:
	var ceil0: float = await _ceiling()
	tiers({"burst": 3})
	var ceil3: float = await _ceiling()
	# (And the directional burst, stronger now, at the top of a jump.)
	await _flat()
	var p0 := p.global_position
	var up0 := p.up
	p.bot_input = Vector2(0, 1)
	await u.press("jump")
	for i in 60:
		await t.frames(1)
		if p.velocity.dot(p.up) <= 0.0:
			break
	await u.press("jump")
	var dir_top := 0.0
	for i in 90:
		await t.frames(1)
		dir_top = maxf(dir_top, (p.global_position - p0).dot(up0))
	p.bot_input = Vector2.ZERO
	await u.wait_grounded()
	tiers()
	var analytic := Axolotl.JUMP_V * Axolotl.JUMP_V / 40.0 + pow(SkillTree.TIERS["burst"]["up_only"][3], 2) / 40.0
	t.check("burst_ceiling_under_ledges", absf(ceil3 - ceil0) < 0.01 and dir_top < ceil0 and ceil3 < 3.9 - 0.1 and analytic <= 3.70,
			"highest reach (jump + up-only burst, 60 Hz): base %.2f m, Water Burst III %.2f m; directional III %.2f m; analytic %.3f m; ledges 3.9 m" % [ceil0, ceil3, dir_top, analytic])
	var reach := []
	for bt in 4:
		tiers({"burst": bt})
		reach.append(await _burst_reach())
	tiers()
	t.check("burst_tiers_reach", reach[1] > reach[0] + 0.3 and reach[2] > reach[1] + 0.3 and absf(reach[3] - reach[2]) < 0.4,
			"jump + burst on the flat: %.2f / %.2f / %.2f / %.2f m" % reach)
	var bend := []
	for bt in [2, 3]:
		tiers({"burst": bt})
		await _flat()
		p.bot_input = Vector2(0, 1)
		await u.press("jump")
		await t.seconds(0.3)
		await u.press("jump")
		var v0 := p.velocity - p.up * p.velocity.dot(p.up)
		u.stick_toward(p.facing.cross(p.up))
		await t.seconds(0.4)
		var v1 := p.velocity - p.up * p.velocity.dot(p.up)
		bend.append(rad_to_deg(v0.angle_to(v1)))
		p.bot_input = Vector2.ZERO
		await u.wait_grounded()
	t.check("burst3_bends_with_stick", bend[1] > bend[0] + 10.0, "turned in 0.4 s: II %.1f deg, III %.1f deg" % bend)
	# Once per air, gliding or not: jump, glide, tap (burst), glide on, tap again (nothing).
	tiers({"burst": 3, "glide": 3})
	await _flat()
	var bursts := [0]
	var cb := func() -> void: bursts[0] += 1
	p.burst_used.connect(cb)
	Input.action_press("jump")
	await t.seconds(0.7)
	Input.action_release("jump")
	await t.frames(1)
	Input.action_press("jump")
	await t.seconds(0.6)
	Input.action_release("jump")
	await t.frames(1)
	Input.action_press("jump")
	await t.seconds(0.3)
	var avail := p.burst_available
	Input.action_release("jump")
	await u.wait_grounded()
	await t.frames(2)
	p.burst_used.disconnect(cb)
	t.check("burst_once_per_air_in_glide", bursts[0] == 1 and not avail and p.burst_available, "bursts %d; the glide never reset it; landing did" % bursts[0])
	tiers()
	p.invuln_t = 0.0


## Glide: hold Jump in the air; it opens near the top of a jump (or once falling), release ends it;
## no Glide skill, no glide; it never gains height; a held glide lands softly; it tires.
func glide_control() -> void:
	tiers()
	await _flat()
	var n0 := p.glides
	Input.action_press("jump")
	var seen := false
	for i in 90:
		await t.frames(1)
		seen = seen or p.gliding
	Input.action_release("jump")
	await u.wait_grounded()
	t.check("glide_needs_the_skill", not seen and p.glides == n0, "")
	tiers({"glide": 1})
	await _flat()
	var h0: float = u.height()
	var top_hold := 0.0
	var open_vup := INF
	var posture := 0.0
	Input.action_press("jump")
	for i in 70:
		await t.frames(1)
		top_hold = maxf(top_hold, u.height() - h0)
		if p.gliding and open_vup == INF:
			open_vup = p.velocity.dot(p.up)
		posture = maxf(posture, p.model.glide)
	Input.action_release("jump")
	await t.frames(1)
	var released := not p.gliding
	await u.wait_grounded()
	t.check("glide_opens_near_apex_and_release_ends", open_vup <= SkillTree.GLIDE_ENTER and open_vup > -3.0 and released and posture > 0.8,
			"opened at vup %.2f m/s, posture %.2f, ends on release %s" % [open_vup, posture, released])
	await _flat()
	var top_plain := 0.0
	await u.press("jump")
	for i in 70:
		await t.frames(1)
		top_plain = maxf(top_plain, u.height() - h0)
	await u.wait_grounded()
	t.check("glide_never_gains_height", top_hold <= top_plain + 0.02, "top %.2f m holding, %.2f m tapping" % [top_hold, top_plain])
	# Held from 14 m up: it tires toward a parachute descent and lands softly; without it, extreme.
	var kinds := {}
	for gt in [0, 3]:
		tiers({"glide": gt})
		await _flat()
		var fb := p.ball
		var upv := p.up
		p.place(fb, p.global_position + upv * 14.0, p.facing)
		var landed := [""]
		var cl := func(k: String) -> void: landed[0] = k
		p.landed.connect(cl)
		Input.action_press("jump")
		var sinks: Array[float] = []
		for i in 400:
			await t.frames(1)
			if p.gliding and i % 30 == 0:
				sinks.append(p.glide_sink)
			if p.grounded:
				break
		Input.action_release("jump")
		p.landed.disconnect(cl)
		kinds[gt] = [landed[0], sinks]
		await t.seconds(0.4)
	var s3: Array = kinds[3][1]
	var tiring: bool = s3.size() >= 3 and s3[s3.size() - 1] > s3[0] + 1.5 and s3[s3.size() - 1] <= SkillTree.GLIDE_S_END + 0.01
	t.check("glide_held_lands_soft_and_tires", kinds[0][0] == "extreme" and kinds[3][0] == "soft" and tiring,
			"from 14 m: no glide %s, Glide III %s; its sink %s m/s" % [kinds[0][0], kinds[3][0], str(s3.map(func(x): return snappedf(x, 0.1)))])
	tiers()
	p.health = p.max_health
	p.model.set_health(p.health, p.max_health, false)
	p.invuln_t = 0.0


# --- Mote Magnet ------------------------------------------------------------------------------------

## An available Mote in plain sight within range drifts toward him; it is never captured by it; a
## missed lunge startles it out of the pull; behind something solid it is not drawn.
func magnet() -> void:
	# (A ground Mote still free, on any ball: earlier tests may have returned the first ball's.)
	var b: MossBall = null
	var m: Mote = null
	for bb in g.balls:
		for mm in bb.motes:
			if mm.h_hint < 0.1 and mm.is_available() and m == null:
				m = mm
				b = bb
	# (Every Mote returned already, e.g. after the all-clear test: one comes back for this test and
	# goes home again at the end.)
	var revived := false
	if m == null:
		b = g.balls[0]
		for mm in b.motes:
			if mm.h_hint < 0.1 and m == null:
				m = mm
		m.state = "wander"
		m.visible = true
		m.intensity = 1.0
		m.scale = Vector3.ONE
		revived = true
	var bi := b.index
	var up := m.anchor_up
	var fwd := MossBall.frame_at(up, 0).z
	var trial := func(tier: int, sd: int) -> float:
		tiers({"magnet": tier})
		# (The same wander for both trials: a Mote's wander draws the global random numbers, so the
		# only difference between them is the Magnet.)
		seed(sd)
		m.global_position = m.anchor + up * 0.6
		m.vel = Vector3.ZERO
		u.place_at(bi, m.anchor + up * 0.2 + fwd * 3.2, -fwd)
		p.invuln_t = 999
		await t.frames(2)
		var d0 := m.global_position.distance_to(p.head_position())
		var closest := d0
		for i in 150:
			await t.frames(1)
			closest = minf(closest, m.global_position.distance_to(p.head_position()))
		return d0 - closest
	# (Averaged over a few fixed wanders: how much the Magnet adds depends on which way the Mote was
	# already drifting, so one trial can't judge it.)
	var gain0 := 0.0
	var gain3 := 0.0
	for sd in [7771, 1009, 4242, 31337]:
		gain0 += await trial.call(0, sd) / 4.0
		gain3 += await trial.call(3, sd) / 4.0
	var still := m.is_available()
	t.check("magnet_draws_mote_never_captures", gain3 > gain0 + 0.8 and still, "closed in by %.2f m with Magnet III, %.2f m without; still free: %s" % [gain3, gain0, still])
	# A miss startles it: the pull stops for a moment.
	tiers({"magnet": 3})
	m.global_position = m.anchor + up * 0.6
	u.place_at(bi, m.anchor + up * 0.2 + fwd * 2.5 + fwd.cross(up) * 2.0, -fwd)
	await u.wait_grounded()
	await t.frames(20)
	var on_before := m.magnet_on
	# (He must actually lunge for there to be a miss: a press while still settling or recovering from
	# an earlier lunge does nothing, so press again until one happens; at most three.)
	var lunges := [0]
	var count := func() -> void: lunges[0] += 1
	p.lunged.connect(count)
	# (A lunge that connects with something, e.g. a parasite that came in to fight (they pursue
	# sooner since 2026-10-01), is no miss: keep going until the Mote is startled; at most three.)
	for attempt in 3:
		await u.press("lunge")
		await t.seconds(0.4)
		if m.startle_t > 0.0:
			break
		await t.seconds(0.6)
	p.lunged.disconnect(count)
	var on_after := m.magnet_on
	t.check("magnet_startled_by_a_miss", on_before and not on_after and m.startle_t > 0.0, "drawn before %s, after the miss %s (startled %.1f s, lunges %d)" % [on_before, on_after, m.startle_t, lunges[0]])
	# No line of sight: a wall between them.
	await t.seconds(3.0)
	var wall := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(4, 3, 0.3)
	cs.shape = bx
	wall.add_child(cs)
	g.add_child(wall)
	var mid := m.anchor + up * 1.0 + fwd * 1.6
	wall.global_transform = Transform3D(MossBall.frame_at(up, 0), mid)
	var hidden: float = await trial.call(3, 7771)
	wall.queue_free()
	t.check("magnet_needs_line_of_sight", hidden < gain3 * 0.5 and m.is_available(), "behind a wall it closed in %.2f m" % hidden)
	# No randomness: with no Magnet it never runs; its code draws nothing; and a Mote stepped with the
	# same seed moves identically with Magnet III (out of his reach) and without.
	tiers()
	var calls0 := Mote.magnet_calls
	await t.seconds(2.0)
	var calls1 := Mote.magnet_calls
	var src := FileAccess.get_file_as_string("res://scripts/actors/mote.gd")
	var body := src.substr(src.find("func _magnet("), src.find("func startle(") - src.find("func _magnet("))
	var runs := []
	for tier in [0, 3]:
		tiers({"magnet": tier})
		m.set_physics_process(false)
		m.global_position = m.anchor + up * 0.6
		m.vel = Vector3.ZERO
		m._target = m.global_position
		m._retarget = 0.0
		m._t = 0.0
		u.place((bi + 1) % g.balls.size(), 10, 30, 0.2)
		seed(777)
		for i in 240:
			m._update_wander(1.0 / 60.0)
		runs.append([m.global_position, randi()])
		m.set_physics_process(true)
	tiers()
	t.check("magnet_draws_no_random_numbers", calls1 == calls0 and (not body.contains("rand") and body.length() > 100 or _no_source()) and runs[0][0].is_equal_approx(runs[1][0]) and runs[0][1] == runs[1][1],
			"calls with no Magnet in 2 s of play: %d; same seed, 240 steps, next random number: %s / %s" % [calls1 - calls0, str(runs[0][1]), str(runs[1][1])])
	if revived:
		m.restore_done()
	p.invuln_t = 0.0


# --- Glide transfers on the real authored geometry ----------------------------------------------------

## A point on the ball: [ball index, lat, lon, height above the base terrain] -> the surface there
## (probed from just above, so a perch's top rather than the ground under it).
func _pt(spec: Array) -> Vector3:
	var b: MossBall = g.balls[int(spec[0])]
	var hit := Starfish.probe(b, MossBall.dir_ll(float(spec[1]), float(spec[2])), float(spec[3]))
	return hit[0] if not hit.is_empty() else b.surface_point(MossBall.dir_ll(float(spec[1]), float(spec[2])), float(spec[3]))


func _flat_dir(v: Vector3) -> Vector3:
	return (v - p.up * v.dot(p.up)).normalized()


## Whether the ground drops away just ahead of him (the edge he takes off from).
func _edge_ahead(dir: Vector3) -> bool:
	var space := g.get_world_3d().direct_space_state
	var at := p.global_position + dir * 0.55
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + p.up * 0.6, at - p.up * 0.9, 1 | 2 | LevelBuilder.CLIMB_LAYER))
	return hit.is_empty() or (p.global_position - (hit["position"] as Vector3)).dot(p.up) > 0.35


## One try from `from` to `to` (ball bi): run to the edge and jump (or, `col`, ride a bubble column to
## its top and burst out), stick toward the target all the way. strat: {"burst": s after takeoff or
## -1, "release": s or -1 (never), "hold": false = a tap only (no glide)}. Returns where he came down
## and how far along the way he got.
func _attempt(bi: int, from: Vector3, to: Vector3, strat: Dictionary, col := false) -> Dictionary:
	var b: MossBall = g.balls[bi]
	Input.action_release("jump")
	u.place_at(bi, from + b.up_at(from) * 0.3, to - from)
	p.invuln_t = 999
	if col:
		for i in 480:
			await t.frames(1)
			if i > 60 and absf(p.velocity.dot(p.up)) < 1.2 and p._in_column:
				break
	else:
		await u.wait_grounded()
	await t.frames(2)
	var line := _flat_dir(to - from)
	var start := p.global_position
	var alt0: float = b.altitude(p.global_position)
	if col:
		# (Aim first: the burst out of the column goes where the stick points.)
		for i in 6:
			u.stick_toward(to - p.global_position)
			await t.frames(1)
		Input.action_press("jump")
	else:
		for i in 240:
			u.stick_toward(to - p.global_position)
			await t.frames(1)
			if not p.grounded or _edge_ahead(_flat_dir(to - p.global_position)) or (p.global_position - start).length() > 5.0:
				break
		Input.action_press("jump")
	var takeoff := p.global_position
	var landing := [""]
	var on_land := func(k: String) -> void: landing[0] = k
	p.landed.connect(on_land)
	var air := 0
	var burst_done := col
	var held := true
	var progress := 0.0
	var top := -INF
	var glided := false
	for i in 1200:
		await t.frames(1)
		air += 1
		var s := air / 60.0
		u.stick_toward(to - p.global_position)
		progress = maxf(progress, (p.global_position - takeoff).dot(line))
		top = maxf(top, b.altitude(p.global_position))
		glided = glided or p.gliding
		if not strat.get("hold", true) and held and air == 2:
			Input.action_release("jump")
			held = false
		if not burst_done and float(strat.get("burst", -1.0)) >= 0.0 and s >= float(strat["burst"]):
			burst_done = true
			Input.action_release("jump")
			if strat.get("up", false):
				# (An up-only burst: the stick let go for it, then back on the target.)
				p.bot_input = Vector2.ZERO
			await t.frames(1)
			Input.action_press("jump")
			if strat.get("up", false):
				await t.frames(1)
			if not strat.get("hold", true):
				await t.frames(1)
				Input.action_release("jump")
		if held and float(strat.get("release", -1.0)) >= 0.0 and s >= float(strat["release"]):
			Input.action_release("jump")
			held = false
		if p.grounded and air > 6:
			break
	Input.action_release("jump")
	p.bot_input = Vector2.ZERO
	await t.frames(2)
	p.landed.disconnect(on_land)
	var land := p.global_position
	var off := to - land
	off -= b.up_at(land) * off.dot(b.up_at(land))
	var dalt: float = b.altitude(land) - b.altitude(to)
	return {"ok": off.length() <= 1.6 and absf(dalt) <= 0.6, "dist": off.length(), "dalt": dalt, "progress": progress, "air": air / 60.0, "landing": landing[0],
			"top": top - alt0, "glided": glided, "across": (to - takeoff - b.up_at(takeoff) * (to - takeoff).dot(b.up_at(takeoff))).length()}


## The best of a set of strategies: [ok, best result, strategy].
func _best(bi: int, from: Vector3, to: Vector3, tier_set: Dictionary, strats: Array, col := false) -> Array:
	tiers(tier_set)
	var best := {}
	var best_s := {}
	for st in strats:
		var r: Dictionary = await _attempt(bi, from, to, st, col)
		if best.is_empty() or (r["ok"] and not best["ok"]) or (r["ok"] == best["ok"] and (r["dist"] < best["dist"] if r["ok"] else r["progress"] > best["progress"])):
			best = r
			best_s = st
		if r["ok"]:
			break
	tiers()
	return [best.get("ok", false), best, best_s]


const BURSTS := [-1.0, 0.25, 0.45, 0.65, 0.9, 1.2, 1.6]


func _strats(release := [-1.0]) -> Array:
	var out := []
	for rl in release:
		for bt in BURSTS:
			out.append({"burst": bt, "release": rl, "hold": true})
	return out


func _plain_strats() -> Array:
	var out := []
	for bt in BURSTS:
		out.append({"burst": bt, "release": -1.0, "hold": false})
	return out


## The transfers (docs/SKILL_TREE.md): each [name, ball, from, to, tier the design gives it, column?].
## Intended: base movement cannot, the named Glide tier can (and each higher one). Impossible: no
## tier, no burst timing, no release timing gets there.
## [name, ball, from, to, design tier, from a bubble column, glide-only (base movement cannot)].
const INTENDED := [
	["Undercut bridge crown -> the east bridge", 6, [6, -32.9, 93.1, 3.9], [6, -29.3, 109.7, 1.2], 1, false, true],
	["Undercut bridge crown -> the west bridge", 6, [6, -32.9, 110.1, 3.9], [6, -29.3, 93.4, 2.4], 2, false, true],
	["Grand Terraces crown -> the Twin Terrace bridge", 3, [3, 27.2, -64.1, 4.8], [3, 10.6, -65.2, 3.5], 1, false, false],
	["Twin Terrace bridge -> the Grand Terraces' second tier", 3, [3, 14.5, -65.2, 3.5], [3, 26.8, -54.2, 2.4], 1, false, false],
	["canopy crown leaf -> a jungle stem leaf 15 m below", 2, [2, 19.3, -35.2, 17.4], [2, 5.1, -34.3, 1.9], 1, false, false],
	["canopy column top -> a lower canopy leaf", 2, [2, 22.8, -31.0, 0.0], [2, 24.9, -24.5, 4.7], 1, true, false],
	["jungle stem leaf -> a lower stem leaf 14 m on", 2, [2, -41.8, 71.2, 15.4], [2, -43.9, 56.3, 8.0], 1, false, false],
]
## Candidates for glide-only transfers (probe only).
const EXTRA := [
	["Undercut bridge crown (east) -> the west bridge", 6, [6, -32.9, 110.1, 3.9], [6, -29.3, 93.4, 2.4], 2, false],
	["Twin Terrace bridge -> the Grand Terraces' second tier", 3, [3, 14.5, -65.2, 3.5], [3, 26.8, -54.2, 2.4], 3, false],
	["jungle stem leaf -> a stem leaf 10 m on", 2, [2, 34.0, -158.8, 8.7], [2, 42.4, -159.9, 8.1], 2, false],
	["high jungle stem leaf -> a stem leaf 10 m on", 2, [2, -65.5, 14.9, 13.3], [2, -68.8, 33.9, 12.9], 3, false],
	["jungle stem leaf -> a stem leaf 10 m on (b)", 2, [2, 22.7, 38.9, 2.6], [2, 13.8, 41.3, 1.9], 2, false],
	["jungle stem leaf -> a lower stem leaf 14 m on", 2, [2, -41.8, 71.2, 15.4], [2, -43.9, 56.3, 8.0], 1, false],
]
const IMPOSSIBLE := [
	["High Crown -> a far jungle stem (79 m)", 2, [2, 42.23, 113.3, 28.96], [2, -11.9, 139.1, 1.0]],
	["Sky Spire crown -> the Low Garden (70 m)", 5, [5, 38.3, 53.4, 30.6], [5, -48.6, 88.6, 1.3]],
	["High Crown -> the far side of Giant Stems (75 m)", 2, [2, 42.23, 113.3, 28.96], [2, 44.0, -161.6, 2.7]],
	["the Mesa's foot -> the Mesa top (gaining 6.3 m)", 1, [1, 14.6, -33.9, 0.0], [1, 15.0, -20.0, 6.4]],
]


## The authored barriers (shut): [name, ball, the gate's zone]; from outside to the far side.
const BARRIERS := [["the Reed Wall", 4, "canyon"], ["the Root Hollows curtain", 0, "south"], ["the Glow Chamber boulder", 6, "grotto"]]


## [from, to, centre, far-side normal] for a barrier gate: from 4 m in front of it to 4 m behind.
func _barrier_ends(bi: int, zone: String) -> Array:
	var b: MossBall = g.balls[bi]
	for gt in b.gates:
		var rg: RestorationGate = gt
		if rg.zone_id != zone:
			continue
		var c := rg.closed_xf.origin
		var inside := Vector3.INF
		for h in _hints(b):
			if h.has("gate") and h["gate"] == rg:
				inside = h["inside"]
		# (Across the gate: of its two horizontal axes, the one along which a line at body height from
		# one side to the other meets the gate itself.)
		var n := rg.closed_xf.basis.z
		var upc := b.up_at(c)
		var space := g.get_world_3d().direct_space_state
		for ax in [rg.closed_xf.basis.z, rg.closed_xf.basis.x]:
			var a: Vector3 = (ax - upc * ax.dot(upc)).normalized()
			var p0 := b.surface_point(b.up_at(c - a * 4.5), 0.9)
			var p1 := b.surface_point(b.up_at(c + a * 4.5), 0.9)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p0, p1, 1 | 2))
			if not hit.is_empty() and hit["collider"] == rg:
				n = a
				break
		n = (n - upc * n.dot(upc)).normalized()
		if inside != Vector3.INF and (inside - c).dot(n) < 0.0:
			n = -n
		var from := b.surface_point(b.up_at(c - n * 4.5))
		var to := b.surface_point(b.up_at(c + n * 4.5)) if inside == Vector3.INF else inside
		return [from, to, c, n]
	return []


func _barrier_strats(glide: bool) -> Array:
	var out := []
	for bt in [0.2, 0.35, 0.45, 0.55, 0.8]:
		out.append({"burst": bt, "release": -1.0, "hold": glide, "up": true})
		out.append({"burst": bt, "release": -1.0, "hold": glide})
	return out


## Diagnostic (by name only): every intended and impossible transfer at every tier, printed.
func glide_probe() -> void:
	var part := str(Settings.test_args.get("part", "all"))
	if part == "legs":
		for gt in [0, 3]:
			tiers({"glide": gt})
			u.place(0, 12, 30, 9.0)
			Input.action_press("jump")
			p.bot_input = Vector2(0, 1)
			await t.frames(70)
			var m := p.model
			var bas := m.global_basis.orthonormalized()
			var rows := []
			for i in 4:
				var hand: Node3D = m._elbows[i].get_child(m._elbows[i].get_child_count() - 1)
				var local := bas.inverse() * (hand.global_position - m.global_position)
				rows.append("leg %d hand at x %.2f y %.2f z %.2f" % [i, local.x, local.y, local.z])
			t.log_line("LEGS glide %d (gliding %s, weight %.2f): %s" % [gt, p.gliding, m.glide, "; ".join(rows)])
			Input.action_release("jump")
			p.bot_input = Vector2.ZERO
			await u.wait_grounded()
		tiers()
		t.check("legs", true, "")
		return
	if part == "coldbg":
		var prev0: Array = await _gates(true)
		tiers({"glide": 3, "burst": 3})
		var from := _pt([1, 21.9, -20.0, 0.0])
		var to := _pt([1, 14.7, -31.5, 1.6])
		var b: MossBall = g.balls[1]
		u.place_at(1, from + b.up_at(from) * 0.3, to - from)
		for i in 480:
			await t.frames(1)
			if i % 20 == 0:
				t.log_line("COL f%d alt %.2f vup %.2f in_col %s grounded %s" % [i, b.altitude(p.global_position), p.velocity.dot(p.up), p._in_column, p.grounded])
			if i > 60 and absf(p.velocity.dot(p.up)) < 1.2 and p._in_column:
				t.log_line("COL top at f%d alt %.2f" % [i, b.altitude(p.global_position)])
				break
		for i in 6:
			u.stick_toward(to - p.global_position)
			await t.frames(1)
		Input.action_press("jump")
		var start := p.global_position
		for i in 200:
			u.stick_toward(to - p.global_position)
			await t.frames(1)
			if i % 5 == 0:
				t.log_line("COL air f%d alt %.2f vup %.2f vh %.2f in_col %s gliding %s burst_avail %s dist %.2f" % [i, b.altitude(p.global_position), p.velocity.dot(p.up), (p.velocity - p.up * p.velocity.dot(p.up)).length(), p._in_column, p.gliding, p.burst_available, (p.global_position - start).length()])
			if p.grounded and i > 6:
				break
		Input.action_release("jump")
		tiers()
		await _gates_restore(prev0)
		t.check("coldbg", true, "")
		return
	var prev: Array = await _gates(true)
	if part in ["all", "barrier"]:
		await _gates_restore(prev)
		prev = await _gates(false)
		for e in BARRIERS:
			if Settings.test_args.has("barrier") and not str(e[0]).contains(str(Settings.test_args["barrier"])):
				continue
			var ends := _barrier_ends(int(e[1]), e[2])
			var bb: MossBall = g.balls[int(e[1])]
			t.log_line("BARRIER %s: from ll %s alt %.2f, to ll %s alt %.2f, gate at ll %s alt %.2f" % [e[0], str(_ll(bb, ends[0])), bb.altitude(ends[0]), str(_ll(bb, ends[1])), bb.altitude(ends[1]), str(_ll(bb, ends[2])), bb.altitude(ends[2])])
			for gt in [0, 3]:
				var ts := {"glide": 3, "burst": 3, "quick": 3} if gt == 3 else {}
				tiers(ts)
				var crossed := 0
				var deepest := -INF
				for st in _barrier_strats(gt == 3):
					var r: Dictionary = await _attempt(int(e[1]), ends[0], ends[1], st)
					var depth: float = (p.global_position - (ends[2] as Vector3)).dot(ends[3])
					if Settings.test_args.has("barrier"):
						t.log_line("BARRIER try %s: landed at ll %s alt %.2f, depth %.2f, progress %.2f" % [str(st), str(_ll(bb, p.global_position)), bb.altitude(p.global_position), depth, r["progress"]])
					deepest = maxf(deepest, depth)
					if depth > 0.8:
						crossed += 1
				tiers()
				t.log_line("BARRIER %s %s: crossed in %d of 10 tries, deepest %.1f m past it" % [e[0], "G3+B3+Q3" if gt == 3 else "no skills", crossed, deepest])
		await _gates_restore(prev)
		prev = await _gates(true)
	if part == "barrier":
		await _gates_restore(prev)
		t.check("glide_probe_ran", true, "")
		return
	for e in (EXTRA if part == "extra" else (INTENDED if part in ["all", "intended"] else [])):
		var from := _pt(e[2])
		var to := _pt(e[3])
		for gt in [0, 1, 2, 3]:
			var ts := {"glide": gt, "burst": 3 if gt >= 2 else 1} if gt > 0 else {"burst": 3}
			var r: Array = await _best(int(e[1]), from, to, ts, _strats([-1.0, 1.0]) if gt > 0 else _plain_strats(), e[5])
			var d: Dictionary = r[1]
			t.log_line("GLIDE %s G%d: %s, landed %.1f m from it (alt %+.1f), progress %.1f of %.1f m, air %.1f s, landing %s, strat %s" % [e[0], gt, "REACHED" if r[0] else "no", d["dist"], d["dalt"], d["progress"], d["across"], d["air"], d["landing"], str(r[2])])
	for e in (IMPOSSIBLE if part in ["all", "impossible"] else []):
		var from := _pt(e[2])
		var to := _pt(e[3])
		var r: Array = await _best(int(e[1]), from, to, {"glide": 3, "burst": 3, "quick": 3}, _strats([-1.0, 0.8, 1.5, 2.5]))
		var d: Dictionary = r[1]
		t.log_line("GLIDE %s G3: %s, best progress %.1f of %.1f m, landed %.1f m short, air %.1f s, strat %s" % [e[0], "REACHED" if r[0] else "no", d["progress"], d["across"], d["dist"], d["air"], str(r[2])])
	await _gates_restore(prev)
	t.check("glide_probe_ran", true, "")


# --- The no-upgrade sweep --------------------------------------------------------------------------

func _hints(b: MossBall) -> Array:
	return (b.get_meta("builder") as LevelBuilder).bot_hints


## Walks (and hops when stuck, with a water burst on a second hop) toward a starfish until he touches
## it. (It may already be gone: picked up on the way.)
func _walk_to_star(id: String, target: Vector3, timeout := 8.0) -> bool:
	var last := p.global_position
	var still := 0.0
	var hops := 0
	for i in int(timeout * 60):
		if g.gill.has_star(id):
			break
		var off := target - p.global_position
		u.stick_toward(off)
		await t.frames(1)
		still = still + 1.0 / 60.0 if p.global_position.distance_to(last) < 0.01 else 0.0
		last = p.global_position
		# (A small step or a low rock in the way: hop, as a player would; every other hop with a burst
		# toward it at the top.)
		if p.grounded and (still > 0.4 or (off.dot(p.up) > 0.5 and (off - p.up * off.dot(p.up)).length() < 2.2)):
			await u.press("jump")
			hops += 1
			if hops % 2 == 0:
				for j in 40:
					u.stick_toward(target - p.global_position)
					await t.frames(1)
					if p.velocity.dot(p.up) <= 0.5:
						break
				await u.press("jump")
			still = 0.0
	p.bot_input = Vector2.ZERO
	return g.gill.has_star(id)


## Routes (bot hints) whose climb passes within reach of `pos`: [[hint, top index], ...], lifts last.
func _routes_near(b: MossBall, pos: Vector3) -> Array:
	var out := []
	for h in _hints(b):
		if not h.has("route") or not h.has("tops") or not h.has("start"):
			continue
		var tops: Array = h["tops"]
		for k in tops.size():
			var tp: Vector3 = tops[k]
			if tp.distance_to(pos) < 2.6 and absf(b.altitude(tp) - b.altitude(pos)) < 0.8:
				out.append([h, k])
				break
	out.sort_custom(func(a, c) -> bool:
		var la := str(a[0]["route"]).contains("column")
		var lc := str(c[0]["route"]).contains("column")
		return (not la and lc) or (la == lc and int(a[1]) < int(c[1])))
	return out


## The route whose last top is where `start` is (a climb that begins up on another one).
func _route_ending_at(b: MossBall, start: Vector3) -> Dictionary:
	for h in _hints(b):
		if h.has("route") and h.has("tops") and not (h["tops"] as Array).is_empty():
			var last: Vector3 = (h["tops"] as Array)[(h["tops"] as Array).size() - 1]
			if last.distance_to(start) < 2.0:
				return h
	return {}


## One step of a climb: from where he stands to `target`, with a plain jump, or (`burst` > 0) a jump
## and a water burst toward it that many seconds in (base movement: no skill).
func _step(b: MossBall, target: Vector3, burst: float, back := 1.9) -> void:
	var flat := target - p.global_position
	flat -= p.up * flat.dot(p.up)
	var upward := (target - p.global_position).dot(p.up) > 0.3
	if upward:
		for i in 60:
			flat = target - p.global_position
			flat -= p.up * flat.dot(p.up)
			if flat.length() >= back:
				break
			u.stick_toward(-flat)
			await t.frames(1)
	for i in 6:
		u.stick_toward(target - p.global_position)
		await t.frames(1)
	if upward or flat.length() > 2.5 or burst > 0.0:
		await u.press("jump")
	var air := 0
	for i in 150:
		var off := target - p.global_position
		off -= p.up * off.dot(p.up)
		if off.length() > 0.3:
			u.stick_toward(off)
		else:
			p.bot_input = Vector2.ZERO
		await t.frames(1)
		air += 1
		if burst > 0.0 and air == int(burst * 60.0):
			await u.press("jump")
		if p.grounded and i > 12 and off.length() < 0.6:
			break
	p.bot_input = Vector2.ZERO
	await u.wait_grounded()


## Climbs a route's tops 0..k with base movement: a plain jump per step, and when that falls short, a
## jump with a burst (as the audited "burst" routes need). True when he stands on top k.
func _climb_steps(b: MossBall, tops: Array, k: int) -> bool:
	var i := 0
	while i <= k:
		var target: Vector3 = tops[i]
		var on := -1
		for tries in [[0.0, 1.9], [0.4, 1.9], [0.0, 1.3], [0.35, 2.6], [0.3, 1.3], [0.5, 2.6]]:
			await _step(b, target, tries[0], tries[1])
			on = -1
			for j in range(i, tops.size()):
				var tj: Vector3 = tops[j]
				if absf(b.altitude(p.global_position) - b.altitude(tj)) <= 0.6 and p.global_position.distance_to(tj) <= 2.0:
					on = j
			if on >= 0:
				break
			# (Fell short: back to where this step starts, as a player would try again.)
			if i > 0:
				var back: Vector3 = tops[i - 1]
				u.place_at(b.index, back + b.up_at(back) * 0.3, target - back)
			else:
				return false
			await u.wait_grounded()
		if on < 0:
			t.log_line("SWEEP climb: stuck before step %d of %d" % [i + 1, tops.size()])
			return false
		i = on + 1
	return true


## Climbs `h` up to top `k` (plain jumps, bursts where needed), first climbing the route that ends
## where this one starts when it begins up high. True when he stands on top k.
func _climb_to(b: MossBall, h: Dictionary, k: int) -> bool:
	var st: Vector3 = h["start"]
	if b.altitude(st) > 1.0:
		var pre := _route_ending_at(b, st)
		if pre.is_empty():
			return false
		var ps: Vector3 = pre["start"]
		u.place_at(b.index, ps + b.up_at(ps) * 0.2, (pre["tops"][0] as Vector3) - ps)
		await u.wait_grounded()
		if not await _climb_steps(b, pre["tops"], (pre["tops"] as Array).size() - 1):
			return false
	var h2 := h.duplicate()
	h2["tops"] = (h["tops"] as Array).slice(0, k + 1)
	if str(h["route"]).contains("column"):
		# A bubble column: ride it up, then burst out onto the shelf beside its top.
		u.place_at(b.index, st + b.up_at(st) * 0.2, (h2["tops"][h2["tops"].size() - 1] as Vector3) - st)
		for i in 480:
			await t.frames(1)
			if i > 60 and absf(p.velocity.dot(p.up)) < 1.2 and p._in_column:
				break
		# (Out onto the column's landing: the first top off the column's axis; the rest is walked.)
		var target: Vector3 = h2["tops"][h2["tops"].size() - 1]
		for tp in h2["tops"]:
			var fl: Vector3 = (tp as Vector3) - st
			fl -= b.up_at(st) * fl.dot(b.up_at(st))
			if fl.length() > 1.5:
				target = tp
				break
		t.log_line("SWEEP column %s: tops %s, landing at alt %.2f, %.2f m from the axis" % [h["route"], str((h["tops"] as Array).map(func(x): return snappedf(b.altitude(x), 0.01))), b.altitude(target), (target - st - b.up_at(st) * (target - st).dot(b.up_at(st))).length()])
		u.stick_toward(target - p.global_position)
		await t.frames(8)
		await u.press("jump")
		for i in 240:
			u.stick_toward(target - p.global_position)
			await t.frames(1)
			if p.grounded and i > 10:
				break
		p.bot_input = Vector2.ZERO
		await u.wait_grounded()
		return p.global_position.distance_to(target) < 2.5
	if b.altitude(st) <= 1.0:
		u.place_at(b.index, st + b.up_at(st) * 0.2, (h2["tops"][0] as Vector3) - st)
		await u.wait_grounded()
	return await _climb_steps(b, h2["tops"], k)


## From open ground a short walk away (a proven anchor: a bloom, a burrower hole or the arrival
## point, or open ground round it that Treasure Hunt's path check allows).
func _ground_start(b: MossBall, pos: Vector3) -> Vector3:
	var best := Vector3.INF
	for a in TreasureHunt.anchors(b):
		if a.distance_to(pos) < 30.0 and TreasureHunt.path_ok(b, a, pos) and (best == Vector3.INF or a.distance_to(pos) < best.distance_to(pos)):
			best = a
	if best != Vector3.INF:
		return best
	var up := b.up_at(pos)
	var fr := MossBall.frame_at(up, 0.0)
	for r in [3.0, 4.5, 6.0, 8.0]:
		for k in 12:
			var q := b.surface_point(b.up_at(pos + fr.z.rotated(up, TAU * k / 12.0) * r))
			if TreasureHunt.spot_ok(b, q, 0.5) and TreasureHunt.path_ok(b, q, pos):
				return q
	return Vector3.INF


## One starfish, physically, with no skills: how, and whether he got it.
func _sweep_one(s: Starfish, e: Dictionary) -> String:
	var b := s.ball
	var pos := s.pick_point()
	var sid := s.id
	var kind := str(e["kind"])
	if kind == "cave":
		for h in _hints(b):
			if h.has("cave") and (h["centre"] as Vector3).distance_to(pos) < 12.0:
				var entry: Vector3 = h["entry"]
				u.place_at(b.index, entry + b.up_at(entry) * 0.3, (h["door"] as Vector3) - entry)
				await u.wait_grounded()
				for i in 240:
					u.stick_toward((h["door"] as Vector3) - p.global_position)
					await t.frames(1)
					if p.global_position.distance_to(h["door"]) < 0.8:
						break
				if await _walk_to_star(sid, pos):
					return "walked in through the cave door"
		for h in _hints(b):
			if h.has("hollow") and (h["inside"] as Vector3).distance_to(pos) < 14.0:
				var door: Vector3 = h["door"]
				var out := door + ((door - (h["inside"] as Vector3)) * Vector3(1, 1, 1)).normalized() * 3.0
				u.place_at(b.index, b.surface_point(b.up_at(out), 0.3), pos - out)
				await u.wait_grounded()
				if await _walk_to_star(sid, pos, 12.0):
					return "walked in through the doorway"
	if float(e["alt"]) > 0.8:
		for rk in _routes_near(b, pos):
			var climbed: bool = await _climb_to(b, rk[0], int(rk[1]))
			# (Even if the last step read short, he may be on the perch: walk to it from there.)
			if await _walk_to_star(sid, pos, 6.0):
				return "climbed %s to step %d%s" % [rk[0]["route"], int(rk[1]) + 1, "" if climbed else " (then walked)"]
		# (A low perch with no route: from the ground beside it, a plain jump.)
		var gs := _ground_start(b, b.surface_point(b.up_at(pos)))
		if gs != Vector3.INF:
			u.place_at(b.index, gs + b.up_at(gs) * 0.3, pos - gs)
			await u.wait_grounded()
			if await _walk_to_star(sid, pos, 14.0):
				return "walked and jumped from the ground"
		# (From the ground beside it, all round: run in and jump, bursting at the top.)
		var up := b.up_at(pos)
		var fr := MossBall.frame_at(up, 0.0)
		for k in 8:
			var q := b.surface_point(b.up_at(pos + fr.z.rotated(up, TAU * k / 8.0) * 3.5))
			if b.altitude(q) > 0.6 or not TreasureHunt.spot_ok(b, q, 0.5):
				continue
			u.place_at(b.index, q + b.up_at(q) * 0.3, pos - q)
			await u.wait_grounded()
			await _step(b, pos, 0.4)
			if await _walk_to_star(sid, pos, 5.0):
				return "jumped up from the ground beside it"
		t.log_line("SWEEP %s: last at ll %s alt %.2f (the starfish at alt %.2f)" % [e["id"], str(_ll(b, p.global_position)), b.altitude(p.global_position), b.altitude(pos)])
		return "NOT REACHED (elevated)"
	var start := _ground_start(b, pos)
	if start == Vector3.INF:
		return "NOT REACHED (no ground start)"
	u.place_at(b.index, start + b.up_at(start) * 0.3, pos - start)
	await u.wait_grounded()
	if await _walk_to_star(sid, pos, 14.0):
		return "walked %.1f m from a proven anchor" % start.distance_to(pos)
	return "NOT REACHED (walk)"


## The physical deadlock proof (owner ruling 5): with no skills at all, the bot collects every one of
## the 30 starfish by moving to it (climbing the authored routes with plain jumps, riding bubble
## columns, walking into caves; restoration gates open, as a healed world has them). Each attempt
## starts from ground the game already proves reachable (a route's start, a cave's entry, a bloom).
func sweep() -> void:
	tiers()
	var prev: Array = await _gates(true)
	p.invuln_t = 999
	var rows: Array[String] = []
	var missed: Array[String] = []
	var got := 0
	var only_ids := str(Settings.test_args.get("stars", "")).split(",", false)
	for e in StarfishTable.STARS:
		var s: Starfish = g.starfish.find(e["id"])
		if s == null or (not only_ids.is_empty() and not only_ids.has(e["id"])):
			continue
		var how: String = await _sweep_one(s, e)
		if g.gill.has_star(e["id"]):
			got += 1
		else:
			missed.append("%s (%s)" % [e["id"], how])
		rows.append("%s: %s" % [e["id"], how])
		t.log_line("SWEEP %s %s" % [e["id"], how])
		await t.frames(2)
	p.invuln_t = 0.0
	await _gates_restore(prev)
	t.check("starfish_sweep_all_thirty_no_skills", g.gill.stars() == 30 and missed.is_empty() and p.skill_tiers.values().max() == 0,
			"%d of 30 collected with no skills; missed: %s" % [g.gill.stars(), str(missed)])


## Glide on the real authored geometry (owner ruling 3): every intended transfer is made with its
## design tier (and the Water Burst that tier requires) and NOT with base movement; every impossible
## one stays impossible with everything (Glide III, Water Burst III, Quick Gill III), whatever the
## burst and release timing; and no barrier is crossed by a skill that base movement cannot cross.
func glide_transfers() -> void:
	var prev: Array = await _gates(true)
	var rows: Array[String] = []
	var ok_all := true
	for e in INTENDED:
		var from := _pt(e[2])
		var to := _pt(e[3])
		var gt := int(e[4])
		var base: Array = await _best(int(e[1]), from, to, {}, _plain_strats(), e[5])
		var ts := {"glide": gt, "burst": 2 if gt >= 2 else 1}
		var with: Array = await _best(int(e[1]), from, to, ts, _strats([-1.0, 1.0]), e[5])
		var ok: bool = with[0] and (not base[0] or not e[6])
		ok_all = ok_all and ok
		rows.append("%s: base %s%s, Glide %s %s (%s landing)" % [e[0], "reached" if base[0] else "no", (" (" + str(base[1]["landing"]) + " landing)") if base[0] else "",
				SkillTree.ROMAN[gt], "reached" if with[0] else "NOT reached", with[1]["landing"]])
	t.check("glide_intended_transfers", ok_all, "; ".join(rows))
	rows.clear()
	ok_all = true
	for e in IMPOSSIBLE:
		var from := _pt(e[2])
		var to := _pt(e[3])
		var r: Array = await _best(int(e[1]), from, to, {"glide": 3, "burst": 3, "quick": 3}, _strats([-1.0, 0.8, 1.6]))
		var d: Dictionary = r[1]
		ok_all = ok_all and not r[0]
		rows.append("%s: %s, best %.1f of %.1f m" % [e[0], "REACHED" if r[0] else "no", d["progress"], d["across"]])
	t.check("glide_impossible_transfers", ok_all, "; ".join(rows))
	await _gates_restore(prev)
	prev = await _gates(false)
	rows.clear()
	ok_all = true
	for e in BARRIERS:
		var ends := _barrier_ends(int(e[1]), e[2])
		var crossed := [0, 0]
		for k in 2:
			tiers({"glide": 3, "burst": 3, "quick": 3} if k == 1 else {})
			for st in _barrier_strats(k == 1):
				await _attempt(int(e[1]), ends[0], ends[1], st)
				if (p.global_position - (ends[2] as Vector3)).dot(ends[3]) > 0.8:
					crossed[k] += 1
			tiers()
		# (A barrier base movement already gets past is reported, not a skill's doing.)
		ok_all = ok_all and (crossed[1] == 0 or crossed[0] > 0)
		rows.append("%s: crossed %d/10 with no skills, %d/10 gliding with every Glide, Burst and Quick tier III" % [e[0], crossed[0], crossed[1]])
	await _gates_restore(prev)
	t.check("glide_bypasses_no_barrier", ok_all, "; ".join(rows))
	p.invuln_t = 0.0


## True when scripts carry no source text (an exported pack holds compiled scripts only), so a test
## that reads source must rely on its behavioural checks instead.
func _no_source() -> bool:
	var sc := load("res://scripts/actors/mote.gd") as GDScript
	return sc == null or sc.source_code.is_empty()
