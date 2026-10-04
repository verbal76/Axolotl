extends RefCounted
## Owner-approved cohesion-audit remediation (docs/research/audit-2026-10-02/AUDIT.md, 2026-10-04):
## P1 (Ball 1's rim fights away from the lethal ooze, and the edge assist), P4 (Ball 3's canopy top)
## and P6 (the spread of creature threats). Driven from unit_tests.gd (`_test_rim_fights_clear_of_ooze`,
## `_test_edge_assist`, `_test_canopy_guard_leaf`, `_test_threat_spread`).

var t
var g: Game
var u
var p: Axolotl


func _init(p_t, p_g: Game, p_u) -> void:
	t = p_t
	g = p_g
	u = p_u
	p = g.player


# --- P1: the rim's parasites ---------------------------------------------------------------------

## How far a parasite's home area stays from any ravine cut (metres, on the base sphere: the real
## upland distance is a little longer), and how much of the area is lethal floor (0..1). Exact
## sampling (rings and spokes), no random draws.
static func home_vs_ravines(b: MossBall, pp: Parasite) -> Array:
	var fr := MossBall.frame_at(pp.home_dir, 0.0)
	var outer: float = pp.home_radius + 6.0 / b.radius
	var margin := INF
	var floor_w := 0.0
	var all_w := 0.0
	for i in 61:
		var a: float = outer * i / 60.0
		var inside: bool = a <= pp.home_radius
		for k in 72:
			var axis: Vector3 = (fr.x * cos(k * TAU / 72.0) + fr.z * sin(k * TAU / 72.0)).normalized()
			var d: Vector3 = pp.home_dir.rotated(axis, a).normalized()
			if b.ravine_carve(d) > 0.01:
				margin = minf(margin, maxf(0.0, (a - pp.home_radius) * b.radius))
			if inside:
				var w := maxf(a, 0.5 * outer / 60.0)
				all_w += w
				if b.ravine_at(d) != "":
					floor_w += w
	return [margin, floor_w / maxf(all_w, 0.0001)]


## P1 (a): Ball 1's Great Ravine rim and Split Crack parasites fight away from the edge: each home
## area stops at least 2 m short of the rim (the top of the ravine's wall), and no parasite on
## Ball 1 has lethal floor in its area (they had 16%, 13%, 5% and 12%). Every ball's numbers are logged.
func rim_fights_clear_of_ooze() -> void:
	var b1: MossBall = g.balls[0]
	var short: Array[String] = []
	var rows: Array[String] = []
	for pp: Parasite in b1.parasites:
		if not pp.zone_id in ["rim", "crack"]:
			continue
		var r := home_vs_ravines(b1, pp)
		var ll := Levels._latlon(pp.home_dir)
		rows.append("%s (%.1f, %.1f) %.1f m clear" % [pp.get_meta("completion_id", pp.zone_id), ll.x, ll.y, r[0]])
		if r[0] < 2.0:
			short.append(rows[-1])
	t.check("rim_fights_clear_of_ooze", short.is_empty() and rows.size() == 5, "%s; short of 2 m: %s" % [", ".join(rows), str(short)])
	var b1_floor := 0
	for b: MossBall in g.balls:
		if b.carves.is_empty():
			continue
		var with_floor: Array[String] = []
		for pp: Parasite in b.parasites:
			var r := home_vs_ravines(b, pp)
			if r[1] > 0.0:
				with_floor.append("%s %.0f%%" % [pp.zone_id, r[1] * 100.0])
		if b.index == 0:
			b1_floor = with_floor.size()
		t.log_line("[RIM] ball %d: parasites with ooze floor in their home area %d/%d %s" % [b.index + 1, with_floor.size(), b.parasites.size(), str(with_floor)])
	t.check("ball1_no_parasite_home_on_ooze", b1_floor == 0, "%d" % b1_floor)


# --- P1 (b): the edge assist ---------------------------------------------------------------------

## A point on Ball 1's Great Ravine south rim at longitude `lon`, `m` metres back from where its cut
## begins (negative: past it), and the way into the ravine (north, along the ground).
func _rim(lon: float, m: float) -> Array:
	var b: MossBall = g.balls[0]
	var rim_deg := Levels.GREAT_RAVINE_LAT - rad_to_deg((1.8 + 1.4) / b.radius)
	var d := MossBall.dir_ll(rim_deg - rad_to_deg(m / b.radius), lon)
	var north := MossBall.dir_ll(Levels.GREAT_RAVINE_LAT, lon)
	var pos := b.surface_point(d, 0.05)
	var into := b.surface_point(north) - pos
	into -= b.up_at(pos) * into.dot(b.up_at(pos))
	return [pos, into.normalized()]


## Waits for a death (if one began) to play out and for him to be back in play.
func _settle() -> void:
	for i in 60 * 12:
		await t.frames(1)
		if g.cinematic == "" and p.state == "normal" and i > 10:
			break
	p.bot_input = Vector2.ZERO
	p.restore_full()


## One move at the rim: placed `back_m` from it facing `face`, then `act` runs. Returns
## [ravine falls, rim stops, how far he moved toward the ravine (m)].
func _at_rim(lon: float, back_m: float, face_into: bool, act: Callable) -> Array:
	var rp := _rim(lon, back_m)
	var into: Vector3 = rp[1]
	u.place_at(0, rp[0], into if face_into else -into)
	p.restore_full()
	p.invuln_t = 0.0
	await u.wait_grounded()
	await t.frames(20)
	var start := p.global_position
	var falls0 := int(g.stats.get("ravine_falls", 0))
	var stops0 := p.edge_stops
	await act.call(into)
	for i in 90:
		await t.frames(1)
		if g.cinematic != "":
			break
	var moved := (p.global_position - start).dot(into)
	var out := [int(g.stats.get("ravine_falls", 0)) - falls0, p.edge_stops - stops0, moved]
	await _settle()
	return out


## P1 (b): a lunge on the ground or the knock-back of a hit stops at a ravine's rim; walking in and
## jumping in are untouched (both still end in the ooze); a lunge along a bridge goes on over it.
## Each stop is shown to matter: the same move with the assist off ends in the ooze.
func edge_assist() -> void:
	var b: MossBall = g.balls[0]
	var release: Callable = u._hold_threats(b)
	var lon := 18.0
	var lunge := func(_into: Vector3) -> void:
		await u.press("lunge")
	var r_on: Array = await _at_rim(lon, 1.0, true, lunge)
	Axolotl.edge_assist = false
	var r_off: Array = await _at_rim(lon, 1.0, true, lunge)
	Axolotl.edge_assist = true
	t.check("edge_lunge_stops_at_rim", r_on[0] == 0 and r_on[1] > 0 and r_off[0] == 1,
			"assist on: falls %d, stopped %d frames, moved %.2f m; off: falls %d, moved %.2f m" % [r_on[0], r_on[1], r_on[2], r_off[0], r_off[2]])
	# A hit from inland with his back to the rim: the knock-back throws him toward the ooze.
	var knock := func(into: Vector3) -> void:
		p.take_damage(1, p.global_position - into * 0.9 + p.up * 0.2)
	# (Measured 2026-10-04: a hit's knock-back carries him about 0.8 m; from 0.1 m or more short of
	# the lip he never reaches the ooze even without the assist. Standing on the lip itself he does.)
	var k_on: Array = await _at_rim(lon + 6.0, -0.1, false, knock)
	Axolotl.edge_assist = false
	var k_off: Array = await _at_rim(lon + 6.0, -0.1, false, knock)
	var k_back: Array = await _at_rim(lon + 6.0, 0.3, false, knock)
	Axolotl.edge_assist = true
	t.check("edge_knockback_held_at_rim", k_on[0] == 0 and k_on[1] > 0 and k_off[0] == 1 and k_back[0] == 0,
			"on the lip, assist on: falls %d, stopped %d frames; off: falls %d (thrown %.2f m); 0.3 m back, assist off: falls %d (thrown %.2f m)" % [
			k_on[0], k_on[1], k_off[0], k_off[2], k_back[0], k_back[2]])
	# Walking in still kills (owner: every ooze fall is a death).
	var walk := func(into: Vector3) -> void:
		for i in 150:
			u.stick_toward(into)
			await t.frames(1)
			if g.cinematic != "":
				break
		p.bot_input = Vector2.ZERO
	var w: Array = await _at_rim(lon, 1.0, true, walk)
	t.check("edge_walking_in_still_falls", w[0] == 1 and w[1] == 0, "falls %d, rim stops %d" % [w[0], w[1]])
	# A jump toward it is untouched too.
	var jump := func(into: Vector3) -> void:
		u.stick_toward(into)
		await t.frames(4)
		await u.press("jump")
		for i in 120:
			u.stick_toward(into)
			await t.frames(1)
			if g.cinematic != "":
				break
		p.bot_input = Vector2.ZERO
	var j: Array = await _at_rim(lon, 1.0, true, jump)
	t.check("edge_jumping_in_untouched", j[0] == 1 and j[1] == 0, "falls %d, rim stops %d" % [j[0], j[1]])
	# A lunge along the Split Crack's stone bridge goes on over the cut (there is footing there).
	var lb: LevelBuilder = b.get_meta("builder")
	var cr := {}
	for c in lb.crossings:
		if not c.has("stones") and absf(Levels._latlon(b.up_at(c["a"])).y + 110.0) < 15.0:
			cr = c
	var a: Vector3 = cr["a"]
	var c_end: Vector3 = cr["b"]
	var along := c_end - a
	along -= b.up_at(a) * along.dot(b.up_at(a))
	u.place_at(0, a + b.up_at(a) * 0.3 - along.normalized() * 0.3, along.normalized())
	p.restore_full()
	await u.wait_grounded()
	await t.frames(20)
	var s0 := p.global_position
	var f0 := int(g.stats.get("ravine_falls", 0))
	var st0 := p.edge_stops
	await u.press("lunge")
	await t.frames(60)
	var went := (p.global_position - s0).dot(along.normalized())
	t.check("edge_lunge_along_bridge_unchanged", went > 1.5 and int(g.stats.get("ravine_falls", 0)) == f0 and p.edge_stops == st0 and g.cinematic == "",
			"moved %.2f m along the bridge, %.2f m up; rim stops %d" % [went, b.altitude(p.global_position), p.edge_stops - st0])
	await _settle()
	release.call()


# --- P4: Ball 3's canopy ---------------------------------------------------------------------------

## P4: the canopy's medium parasite and the Mote it guards sit on the giant spiral's guard leaf
## (Levels.CANOPY_GUARD_LEAF, 12.8 m up), not across two stems from its top at 17.3 m; and both are
## reached and taken by play: plain jumps from the ground up the spiral, tail swipes on the leaf, a
## lunge for the Mote, staying up on the climb. (The hits are taken with invulnerability: this proves
## the place is reachable and the fight winnable from the leaf; the bot's playthrough fights it for real.)
func canopy_guard_leaf() -> void:
	var b: MossBall = g.balls[2]
	var lb: LevelBuilder = b.get_meta("builder")
	var h := {}
	for x in lb.bot_hints:
		if x.has("canopy"):
			h = x
	var spiral: Array = h["spiral"]
	var gl := Levels.CANOPY_GUARD_LEAF
	var leaf_top := Levels.leaf_mid(spiral[gl], 1.5, 0.0).origin
	var guard: Parasite = null
	for pp: Parasite in b.parasites:
		if str(pp.get_meta("completion_id", "")) == "b3.canopy.parasite.0":
			guard = pp
	var mote: Mote = null
	for m: Mote in b.motes:
		if str(m.get_meta("completion_id", "")) == "b3.canopy.mote.0":
			mote = m
	# (Where they were authored: their home spots. Earlier tests may have stirred them since.)
	var spot := func(pp: Parasite) -> Vector3: return b.surface_point(pp.spawn_dir, pp.spawn_h)
	var highest := 0.0
	for pp: Parasite in b.parasites:
		if pp.zone_id == "canopy":
			highest = maxf(highest, pp.spawn_h)
	var g_at: Vector3 = spot.call(guard) if guard else Vector3.ZERO
	var m_at: Vector3 = b.surface_point(mote.home_dir(), mote.h_hint) if mote else Vector3.ZERO
	var placed_ok := guard != null and mote != null and guard.kind == Parasite.Kind.MEDIUM \
			and absf(b.altitude(g_at) - b.altitude(leaf_top)) < 0.8 and g_at.distance_to(leaf_top) < 1.8 \
			and absf(b.altitude(m_at) - b.altitude(leaf_top)) < 0.8 and m_at.distance_to(leaf_top) < 1.8 and highest < 14.0
	t.check("canopy_guard_on_spiral_leaf", placed_ok, "leaf %d top %.1f m; parasite's home %.1f m up, %.2f m from the leaf's middle; Mote's %.1f m up, %.2f m; highest canopy parasite home %.1f m" % [gl + 1,
			b.altitude(leaf_top), b.altitude(g_at), g_at.distance_to(leaf_top), b.altitude(m_at), m_at.distance_to(leaf_top), highest])
	if not placed_ok:
		return
	# (Back at home for the by-play part, whatever earlier tests did to it.)
	if guard.is_alive() and guard.global_position.distance_to(g_at) > 1.5:
		guard.return_home_unseen()
	# By play: the spiral's leaves from the ground with plain jumps, to the guard leaf. (Base moves:
	# no skill-tree tiers left over from earlier tests.)
	var tiers0: Dictionary = p.skill_tiers.duplicate()
	p.apply_skills({})
	p.invuln_t = 999.0
	var ground := b.surface_point(b.up_at(Levels.leaf_mid(spiral[0], 4.4, 0.0).origin), 0.1)
	u.place_at(2, ground, (Levels.leaf_mid(spiral[0], 1.5, 0.0).origin - ground).normalized())
	g.audio.set_ball(2, false)
	p.restore_full()
	await u.wait_grounded()
	var reached := 0
	for k in gl + 1:
		var target := Levels.leaf_mid(spiral[k], 1.6, 0.0).origin
		for i in 10:
			u.stick_toward(target - p.global_position)
			await t.frames(1)
		await u.press("jump")
		for i in 90:
			var off := target - p.global_position
			off -= p.up * off.dot(p.up)
			if off.length() > 0.3:
				u.stick_toward(off)
			else:
				p.bot_input = Vector2.ZERO
			await t.frames(1)
			if p.grounded and i > 12:
				break
		p.bot_input = Vector2.ZERO
		await u.wait_grounded()
		if absf(b.altitude(p.global_position) - b.altitude(target)) > 0.35 or p.global_position.distance_to(target) > 1.8:
			t.log_line("guard-leaf climb stopped at leaf %d: at h %.2f, leaf top h %.2f" % [k, b.altitude(p.global_position), b.altitude(target)])
			break
		reached += 1
	# The fight, from the leaf: turn so it is behind, then swipe (as a player does).
	var el := 0.0
	var swipes := 0
	while guard.is_alive() and el < 25.0 and reached == gl + 1:
		var to := guard.closest_body_point(p.body_center()) - p.global_position
		to -= p.up * to.dot(p.up)
		if to.length() < 1.6:
			for k in 5:
				u.stick_toward(-to)
				p.bot_input *= 0.35
				await t.frames(1)
			p.bot_input = Vector2.ZERO
			await u.press("swipe")
			swipes += 1
			await t.frames(20)
			el += 0.42
		else:
			await t.frames(6)
			el += 0.1
	var on_leaf := b.altitude(p.global_position) > b.altitude(leaf_top) - 0.5
	t.check("canopy_guard_reached_and_beaten_by_play", reached == gl + 1 and not guard.is_alive() and on_leaf,
			"plain jumps to leaf %d of %d; parasite beaten %s after %d swipes (%.1f s); he is %.1f m up" % [reached, gl + 1, not guard.is_alive(), swipes, el, b.altitude(p.global_position)])
	# The Mote: from the leaf's outer end, lunge in along it toward the trunk (the trunk stops him; a
	# lunge out along a 3 m leaf would carry him off its tip).
	var got := false
	var lx: Transform3D = (spiral[gl] as Transform3D).affine_inverse()
	var inward: Vector3 = (spiral[gl] as Transform3D).basis.z
	for attempt in 3:
		if not mote.is_available():
			break
		var tip_end := Levels.leaf_mid(spiral[gl], 2.5, 0.0).origin
		for i in 60:
			var off := tip_end - p.global_position
			off -= p.up * off.dot(p.up)
			if off.length() < 0.2:
				break
			u.stick_toward(off)
			p.bot_input *= clampf(off.length(), 0.3, 0.6)
			await t.frames(1)
		for i in 8:
			u.stick_toward(inward)
			p.bot_input *= 0.3
			await t.frames(1)
		p.bot_input = Vector2.ZERO
		t.log_line("guard-leaf lunge %d: from %s, Mote at %s (leaf frame: side, up, -along)" % [attempt, str((lx * p.global_position).snapped(Vector3.ONE * 0.01)), str((lx * mote.global_position).snapped(Vector3.ONE * 0.01))])
		# (It bobs between about 0.3 and 1.4 m over the leaf: wait for it to come low, as a player
		# does, rather than jump-lunging round the trunk.)
		for i in 60 * 6:
			if (mote.global_position - p.global_position).dot(p.up) < 0.8:
				break
			await t.frames(1)
		await u.press("lunge")
		await t.frames(40)
		await u.wait_grounded()
	got = not mote.is_available()
	# (A lunge that slips off the leaf's side lands on the leaf below, a metre down: still on the climb.)
	t.check("canopy_guard_mote_taken_from_leaf", got and b.altitude(p.global_position) > b.altitude(leaf_top) - 1.5,
			"Mote taken %s; he is %.1f m up (leaf %.1f m)" % [got, b.altitude(p.global_position), b.altitude(leaf_top)])
	p.invuln_t = 0.0
	p.apply_skills(tiers0)


# --- P6: threats ------------------------------------------------------------------------------------

## P6: the creature threats are spread by pacing: Reed Canyon keeps a canyon stalker, the maze
## stalker, its crab, eel, puffer and spitter; its second canyon stalker hunts Giant Stems' western
## jungle floor, on the ground, clear of every required fight's area, bloom, arrival and vortex
## mouth. (Stalkers earn no completion id and are never saved: no id or save changes.)
func threat_spread() -> void:
	var rows: Array[String] = []
	var stalkers := {}
	for b: MossBall in g.balls:
		var n := {}
		for c in b.critters:
			if c.species in ["stalker", "crab", "eel", "puffer"]:
				n[c.species] = n.get(c.species, 0) + 1
		for pp: Parasite in b.parasites:
			if pp.variant == "spitter":
				n["spitter"] = n.get("spitter", 0) + 1
		stalkers[b.index] = n.get("stalker", 0)
		rows.append("ball %d %s" % [b.index + 1, str(n)])
	t.log_line("[THREATS] " + "; ".join(rows))
	var gs: MossBall = g.balls[2]
	var moved: ReedStalker = null
	for c in gs.critters:
		if c is ReedStalker and (c as ReedStalker).patch_dir.angle_to(MossBall.dir_ll(Ecosystem.GS_STALKER_LL.x, Ecosystem.GS_STALKER_LL.y)) < 0.01:
			moved = c
	var why: Array[String] = []
	if moved == null:
		why.append("no stalker at Giant Stems' western jungle floor")
	else:
		var patch_m: float = deg_to_rad(moved.patch_deg) * gs.radius
		var centre := gs.surface_point(moved.patch_dir)
		if gs.altitude(centre) > 0.3 or gs.altitude(moved.global_position) > 1.0:
			why.append("not on the ground")
		for pp: Parasite in gs.parasites:
			var gap: float = moved.patch_dir.angle_to(pp.home_dir) * gs.radius - patch_m - pp.home_radius * gs.radius
			if gap < 6.0:
				why.append("%.1f m from %s's area" % [gap, pp.get_meta("completion_id", pp.zone_id)])
		var spots: Array = [gs.surface_point(gs.arrival_dir), gs.surface_point(gs.start_dir)]
		for bl in gs.blooms:
			spots.append(bl.respawn_point())
		for v in g.vortices:
			if v.ball_a == gs:
				spots.append(v.mouth_pos(false))
			if v.ball_b == gs:
				spots.append(v.mouth_pos(true))
		for sp: Vector3 in spots:
			if moved._in_patch(sp, rad_to_deg(8.0 / gs.radius)):
				why.append("within 8 m of %s" % str(Levels._latlon(gs.up_at(sp)).round()))
	t.check("threat_spread_stalker_on_giant_stems", stalkers.get(2, 0) == 2 and stalkers.get(4, 0) == 2 and why.is_empty(),
			"stalkers on Giant Stems %d, Reed Canyon %d; %s" % [stalkers.get(2, 0), stalkers.get(4, 0), str(why)])
