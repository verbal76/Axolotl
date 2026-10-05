extends RefCounted
## Cohesion audit 2026-10-02, proposals P5 and P7 (docs/research/audit-2026-10-02/AUDIT.md):
## small parasites read apart from Gill at distance, and every cave eel can be reached and hit.
## Runs inside the unit suite (--only=_test_eel_reach, --only=_test_parasite_readability).

var t
var g: Game


func _init(runner) -> void:
	t = runner
	g = runner.g


# --- P7: cave eels -------------------------------------------------------------------------

## The grotto (cave hint) an eel lives in: the one whose centre is nearest its crevice.
func _grotto(e: CaveEel) -> Dictionary:
	var best: Dictionary = {}
	var bd := INF
	for h in (e.ball.get_meta("builder") as LevelBuilder).bot_hints:
		if h.has("cave") and (h["centre"] as Vector3).distance_to(e.mouth) < bd:
			bd = (h["centre"] as Vector3).distance_to(e.mouth)
			best = h
	return best


func _ray_clear(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, Critter.SOLID_MASK)
	return g.player.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Gill can stand at `s` (on the floor, nothing over it) and walk there from the grotto's door
## (a clear line at body height, straight or by the middle of the floor).
func _standable(b: MossBall, h: Dictionary, s: Vector3) -> bool:
	var up := b.up_at(s)
	var q := PhysicsRayQueryParameters3D.create(s + up * 2.2, s - up * 0.5, Critter.SOLID_MASK)
	var hit := g.player.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or (hit["position"] as Vector3).distance_to(s) > 0.15:
		return false
	var door: Vector3 = h["door"]
	var mid := b.surface_point(b.up_at(h["centre"]), 0.0)
	var lift := func(p: Vector3) -> Vector3: return p + b.up_at(p) * 0.35
	return _ray_clear(lift.call(door), lift.call(s)) or (_ray_clear(lift.call(door), lift.call(mid)) and _ray_clear(lift.call(mid), lift.call(s)))


## What the eel does with Gill standing at `s` (placed there): whether it notices him, how far its
## strike gets, whether its head, fully out, is inside his swipe (and in clear view), and whether
## the strike touches him there.
func _strike_from(e: CaveEel, s: Vector3) -> Dictionary:
	var b := e.ball
	var p := g.player
	p.place(b, s, e.mouth - s)
	p.velocity = Vector3.ZERO
	var c := p.body_center()
	var out := {"sees": e._sees(p), "reach": 0.0, "in_swipe": false, "touches": false}
	if not out["sees"]:
		return out
	var aim := e._aim(c)
	var q := PhysicsRayQueryParameters3D.create(e.mouth + aim * 0.2, e.mouth + aim * (CaveEel.STRIKE_REACH + 0.2), Critter.SOLID_MASK)
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	var reach := CaveEel.STRIKE_REACH if hit.is_empty() else maxf(0.0, (hit["position"] as Vector3).distance_to(e.mouth) - 0.25)
	out["reach"] = reach
	var keep_ext := e.ext
	var keep_dir := e._dir
	e.ext = reach
	e._dir = aim
	var head := e.mouth + aim * reach
	out["in_swipe"] = reach > 0.6 and g._swipe_offset(p, e) != Vector3.ZERO and _ray_clear(c, head)
	out["touches"] = e._dist_to_body(c) < CaveEel.CONTACT_R
	e.ext = keep_ext
	e._dir = keep_dir
	return out


## Every standable spot in front of an eel (a fan of points, 1.6-4.2 m from its crevice) from which
## a swipe reaches it fully out.
func _eel_spots(e: CaveEel, h: Dictionary) -> Array:
	var b := e.ball
	var up := b.up_at(e.mouth)
	var spots := []
	var r := 1.6
	while r <= CaveEel.NOTICE_R + 0.01:
		for k in range(-9, 10):
			var dir := e.normal.rotated(up, deg_to_rad(k * 7.5))
			var s := b.surface_point(b.up_at(e.mouth + dir * r), 0.0)
			if not _standable(b, h, s):
				continue
			var res := _strike_from(e, s)
			if res["in_swipe"]:
				spots.append([s, res["touches"]])
		r += 0.25
	return spots


## The spot the eel offers to be fought from (before P7, the bot's old "front": straight out from
## the crevice, just beyond its reach).
func _stand_of(e: CaveEel) -> Vector3:
	var st = e.get("stand")
	if st != null:
		return st
	return e.ball.surface_point(e.ball.up_at(e.mouth + e.normal * (CaveEel.STRIKE_REACH + 0.45)), 0.1)


func _glow_of(e: CaveEel) -> float:
	return float(e.call("cleft_glow")) if e.has_method("cleft_glow") else 0.0


func eel_reach() -> void:
	var p := g.player
	var eels := []
	for c in g.ecosystem.all_critters():
		if c is CaveEel:
			eels.append(c)
	var no_spot := []
	var stand_bad := []
	var ledge_seen := []
	var glow_bad := []
	var report := PackedStringArray()
	p.invuln_t = 999
	for e: CaveEel in eels:
		var b := e.ball
		var h := _grotto(e)
		var spots := _eel_spots(e, h)
		var safe := spots.filter(func(x): return not x[1])
		# The spot the eel itself offers (the playthrough bot and the reach check go there).
		var stand := _stand_of(e)
		var st_res := _strike_from(e, stand)
		var st_ok: bool = _standable(b, h, stand) and bool(st_res["in_swipe"]) and not st_res["touches"]
		if spots.is_empty():
			no_spot.append(e.threat_id)
		if not st_ok:
			stand_bad.append("%s %s" % [e.threat_id, str(st_res)])
		# It never notices him on the grotto's climb (it guards the floor; no knock off a ledge).
		for l in h["ledges"]:
			var lt: Vector3 = (l as Node3D).global_position + b.up_at((l as Node3D).global_position) * float((l as Node3D).get_meta("top", 0.0))
			p.place(b, lt, e.mouth - lt)
			if e._sees(p):
				ledge_seen.append("%s ledge %.1f m up" % [e.threat_id, float((l as Node3D).get_meta("top", 0.0))])
		report.append("%s: %d spots (%d out of its touch), stand %s, strike %.2f m, moved %s deg" % [e.threat_id, spots.size(), safe.size(), "ok" if st_ok else "BAD", st_res["reach"], str(e.get("placed_deg"))])
	t.log_line("eel reach: " + "; ".join(report))
	t.check("eel_hittable_from_standable_spot", eels.size() >= 5 and no_spot.is_empty(), "%d eels; no spot: %s" % [eels.size(), str(no_spot)])
	t.check("eel_stand_spot_strikes_clear", stand_bad.is_empty(), str(stand_bad))
	t.check("eel_never_sees_him_on_its_ledges", ledge_seen.is_empty(), str(ledge_seen))
	# Live, through the real swipe: at its spot, the eel strikes and a swipe while it is out lands.
	var landed := []
	var missed := []
	var live := 0
	for e: CaveEel in eels:
		if e.defeated:
			# (Beaten by an earlier test in this process: _test_ecosystem's eel_defeated_while_out.)
			continue
		live += 1
		var b := e.ball
		var hp0 := e.hp
		var face := e.mouth - _stand_of(e)
		p.place(b, _stand_of(e), face)
		p.velocity = Vector3.ZERO
		p.bot_input = Vector2.ZERO
		g.cam.snap_behind()
		g.audio.set_ball(b.index, false)
		e._go("hidden")
		# (Hidden, Gill in its grotto: the cleft glows faintly and lets out a bubble now and then.)
		var cue := 0.0
		var hit := false
		var el := 0.0
		while el < 8.0 and not hit:
			await t.frames(1)
			el += 1.0 / 60.0
			cue = maxf(cue, _glow_of(e))
			if e.hittable() and e.ext > e.reach * 0.8:
				Input.action_press("swipe")
				await t.frames(1)
				Input.action_release("swipe")
				for k in 20:
					await t.frames(1)
					if e.hp < hp0:
						hit = true
						break
				if not hit:
					# Back to its spot for the next strike (a missed strike may have nudged him).
					p.place(b, _stand_of(e), face)
		(landed if hit else missed).append(e.threat_id)
		if cue <= 0.0:
			glow_bad.append(e.threat_id)
		# Leave it as it was (the shard's other tests and the playthrough expect live eels).
		e.hp = hp0
		e._go("hidden")
		e.ext = 0.0
		e._pose()
	p.invuln_t = 0.0
	t.check("eel_swipe_lands_from_its_spot", missed.is_empty() and live > 0 and landed.size() == live, "landed %s; missed %s (%d of %d not beaten before)" % [str(landed), str(missed), live, eels.size()])
	t.check("eel_cleft_glows_when_he_is_in_its_grotto", glow_bad.is_empty(), str(glow_bad))
	# Away from its grotto, the cleft is dark (no glow far off, only its eyes).
	var e0: CaveEel = eels[0]
	var far := e0.ball.surface_point(-e0.ball.up_at(e0.mouth), 0.2)
	p.place(e0.ball, far, Vector3.FORWARD)
	await t.frames(30)
	t.check("eel_cleft_dark_when_he_is_away", _glow_of(e0) <= 0.001, "%.3f" % _glow_of(e0))


# --- P5: small parasites at a distance ------------------------------------------------------

static func _hue_deg(c: Color) -> float:
	return c.h * 360.0


static func _hue_gap(a: Color, b: Color) -> float:
	var d := absf(_hue_deg(a) - _hue_deg(b))
	return minf(d, 360.0 - d)


static func _lum(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


func parasite_readability() -> void:
	var small: Parasite = null
	for b in g.balls:
		for x in b.parasites:
			# (A living one: earlier tests in the same world may have drained some, whose eyes are rightly out.)
			if x.kind == Parasite.Kind.SMALL and small == null and x.is_alive() and x._gray < 0.01:
				small = x
	t.check("parasite_small_found", small != null, "")
	if small == null:
		return
	var m := small._body_mat
	var head: Color = m.get_shader_parameter("color_a")
	var tail: Color = m.get_shader_parameter("color_b")
	var gill := AxolotlModel.BODY_COLOR
	var food := Color(1.0, 0.62, 0.42)
	# A value step: the body is clearly darker than Gill's pale pink (a dark shape against a pale
	# one) and is not the food's peach; the eyes glow in a colour far from both.
	t.check("parasite_small_darker_than_gill", _lum(head) < _lum(gill) * 0.4 and _lum(tail) < _lum(gill) * 0.4,
			"head %.2f, tail %.2f, Gill %.2f" % [_lum(head), _lum(tail), _lum(gill)])
	t.check("parasite_small_not_food_coloured", _hue_gap(head, food) >= 40.0 and _hue_gap(tail, food) >= 25.0,
			"head hue %.0f, tail %.0f, food %.0f" % [_hue_deg(head), _hue_deg(tail), _hue_deg(food)])
	var eye: StandardMaterial3D = small.eye_material()
	t.check("parasite_eyes_glow_away_from_gill_and_food", eye.emission_enabled and eye.emission_energy_multiplier > 1.0
			and _hue_gap(eye.emission, gill) >= 45.0 and _hue_gap(eye.emission, food) >= 20.0,
			"eye hue %.0f energy %.2f; Gill %.0f, food %.0f" % [_hue_deg(eye.emission), eye.emission_energy_multiplier, _hue_deg(gill), _hue_deg(food)])
	# The wind-up flares them; drained (defeated, the grey death drift), they go out.
	small.set_look(small._gray, 0.0, 1.0)
	var flare := eye.emission_energy_multiplier
	small.set_look(1.0, 0.0, 0.0)
	var out := eye.emission_energy_multiplier
	small.set_look(small._gray, 0.0, 0.0)
	t.check("parasite_eyes_flare_in_windup_out_when_drained", flare > Parasite.EYE_GLOW * 1.5 and out <= 0.05, "wind-up %.2f, drained %.2f" % [flare, out])
	# Every parasite has its own eye material (one's wind-up or death never lights another's).
	var mats := {}
	for b in g.balls:
		for x in b.parasites:
			mats[x.eye_material()] = true
	var n := 0
	for b in g.balls:
		n += b.parasites.size()
	t.check("parasite_eye_materials_own", mats.size() == n, "%d materials, %d parasites" % [mats.size(), n])
