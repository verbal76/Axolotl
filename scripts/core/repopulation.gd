class_name Repopulation
extends RefCounted
## Normal-mode repopulation (ledger row 11; spec docs/research/2026-09-30-DEVICE_AUDIT.md §D and
## owner ruling H): parasites slowly come back to zones Gill has cleared, so restored areas are not
## empty, while restoration stays permanent.
##
## Returners are new Parasites (`returner = true`, completion id "") kept in `ball.returners`, never
## in `ball.parasites`, so the completion catalog, the run save's earned ids, zone and ball
## restoration, the health map, gates, crumbles and vortices never see them. Killing one earns and
## restores nothing (Game.parasite_killed).
##
## Per zone with authored parasites: the first return comes at least `grace_s` of play after the zone
## was cleared (its last authored parasite killed), then one every `every_min_s`..`every_max_s`,
## hashed from (run key, ball, zone, n) with no global random draws. At most `Rules.cap_for(authored)`
## alive per zone (Normal: about a third, never below one: 3 originals give 1) and `ball_cap` per ball. Each return copies an authored parasite of the
## zone (its species, spitter variant, spawn direction and home), so the zone's species mix is kept.
## Arrivals happen only on the player's ball, at least `min_gill_m` from him and off camera, and never at an
## authored spot within `bloom_clear_m` of a bloom or `vortex_clear_m` of a vortex mouth.
##
## Hard Mode (HardMode, ledger row 12) reuses this class with its own Rules (rate, cap, grace, bloom
## buffer, a slower rate at low health and no returners into a zone at its vitality floor) and reads the
## alive returners per zone through `alive_in_zone` for its pressure model. When Gill reaches a sphere
## under a remote incursion, its abstract load is handed over as `owe()`d returners, which arrive through
## the same off-camera rules. Normal rules never owe, gate or slow anything.

const FORMAT := 1


## The tunables. `Repopulation.normal_rules()` is Normal mode (owner ruling H: initial values, tuned
## after phone feel tests); Hard Mode passes its own.
class Rules:
	var grace_s := 300.0
	var every_min_s := 240.0
	var every_max_s := 420.0
	## Zone cap = max(1, round(cap_frac x authored)) (owner, 2026-10-01: a 3-parasite zone returns
	## one; rounding never turns 3 into 2). Sizes in the game: 1-4 give 1, 5-7 give 2, 8 gives 3.
	var cap_frac := 1.0 / 3.0
	var ball_cap := 6
	var min_gill_m := 35.0
	## No returner spot this near a checkpoint bloom (owner, 2026-10-01: the smallest safe value, not
	## 20 m). From the parasites' own numbers: Gill re-forms 0.9 m from the bloom
	## (Bloom.respawn_point), so a spot 11 m from the bloom is at least 10.1 m from him there. That is
	## past every notice range (spitter 9 m, large 7.5 m, others 6.5 m), so none notices him on
	## arrival or at rest, and past the bloom pulse's Parasite.STARTLE_R (10 m), so it never needs
	## startling; the 1.1 m beyond the widest notice range is a further 0.4 s of the fastest crawl
	## (2.6 m/s) before one could start toward him, inside his 1.2-1.5 s re-form invulnerability.
	## 10 m would leave a spitter 0.1 m outside its range of him: too thin. (Measured at build from
	## the bloom's authored spot; repop_bloom_buffer checks the settled blooms and respawn points.)
	var bloom_clear_m := 11.0
	var vortex_clear_m := 12.0
	## Seconds between two arrivals on one ball (several zones due at once never arrive together).
	var spacing_s := 8.0

	func cap_for(authored: int) -> int:
		return 0 if authored <= 0 else maxi(1, roundi(cap_frac * authored))

	## Multiplies every interval between returns (Normal: 1; Hard doubles it at low health).
	func interval_scale() -> float:
		return 1.0

	## Whether a due zone may take a returner now (Normal: always; Hard: not at its vitality floor).
	func allows(_z: Dictionary) -> bool:
		return true


static func normal_rules() -> Rules:
	return Rules.new()


var rules: Rules
## Off: no zone is noted and nobody returns (the unit suite runs without it unless a test asks).
var enabled := true
## The run's key (its run id; a fixed key in seeded test runs): all timing hashes from it.
var key := ""
## Zone key ("b<ball>.<zone>") -> {ball, zone, authored: Array[Parasite], eligible: Array[Parasite],
## cap, cleared (play s, -1 = not yet), next (play s of the next return), n (returns so far)}.
var zones := {}
var balls: Array = []
var _last_arrival := {}
## Every arrival, for tests and the long simulation: {t, ball, zone, n, kind, variant, dist, on_camera}.
var arrivals: Array = []


func _init(p_rules: Rules = null) -> void:
	rules = p_rules if p_rules != null else Rules.new()


static func zone_key(ball_index: int, zone_id: String) -> String:
	return "b%d.%s" % [ball_index, zone_id]


## A uniform [0, 1) from the parts (FNV-1a over their text): deterministic, no random state.
static func unit(parts: Array) -> float:
	var h := 2166136261
	for byte in "|".join(parts.map(func(x): return str(x))).to_utf8_buffer():
		h = ((h ^ byte) * 16777619) & 0xFFFFFFFF
	# (A final avalanche so neighbouring n give unrelated values.)
	h ^= h >> 15
	h = (h * 0x2C1B3C6D) & 0xFFFFFFFF
	h ^= h >> 12
	return float(h) / 4294967296.0


## Whether a thing at `pos` (standing on `up`) could be seen: a spread of points round it and above it
## tested against the camera's frustum.
static func on_camera(cam: Camera3D, pos: Vector3, up: Vector3, spread := 1.5, height := 2.0) -> bool:
	if cam == null:
		return false
	var fx := MossBall.frame_at(up, 0.0)
	for off in [Vector3.ZERO, up * height * 0.5, up * height, fx.x * spread, -fx.x * spread, fx.z * spread, -fx.z * spread]:
		if cam.is_position_in_frustum(pos + off):
			return true
	return false


## Reads the world: each zone's authored parasites, which of their spots may ever take a returner,
## and the zone caps.
func build(p_balls: Array, p_vortices: Array) -> void:
	balls = p_balls
	_vortices = p_vortices
	zones.clear()
	for b: MossBall in balls:
		var by_zone := {}
		for par in b.parasites:
			if not by_zone.has(par.zone_id):
				by_zone[par.zone_id] = []
			by_zone[par.zone_id].append(par)
		for zid in by_zone:
			var authored: Array = by_zone[zid]
			zones[zone_key(b.index, zid)] = {"ball": b.index, "zone": zid, "authored": authored, "eligible": [],
					"cap": rules.cap_for(authored.size()), "cleared": -1.0, "next": -1.0, "n": 0}
	_find_spots()


var _vortices: Array = []
## True once every bloom has settled where it rests (blooms settle on their first frame, after the
## world is built): the spots are then measured from where the blooms and their re-form points are.
var blooms_settled := false


## Which authored spots may take a returner: clear of every vortex mouth and every checkpoint bloom
## (its authored spot and, once it has settled, where it rests and where Gill re-forms beside it).
func _find_spots() -> void:
	blooms_settled = true
	for b: MossBall in balls:
		var keep_out := []
		for v in _vortices:
			if v.ball_a == b:
				keep_out.append([b.surface_point(v.dir_a), rules.vortex_clear_m])
			if v.ball_b == b:
				keep_out.append([b.surface_point(v.dir_b), rules.vortex_clear_m])
		for bl in b.blooms:
			keep_out.append([b.surface_point(bl.dir, bl.h_hint), rules.bloom_clear_m])
			if bl.is_placed():
				keep_out.append([bl.global_position, rules.bloom_clear_m])
				keep_out.append([bl.respawn_point(), rules.bloom_clear_m])
			else:
				blooms_settled = false
		for z in zones.values():
			if int(z["ball"]) != b.index:
				continue
			var eligible := []
			for par in z["authored"]:
				var at := spot_of(b, par)
				var ok := true
				for k in keep_out:
					ok = ok and at.distance_to(k[0]) >= k[1]
				if ok:
					eligible.append(par)
			z["eligible"] = eligible


## Where a returner copying `par` arrives.
static func spot_of(b: MossBall, par: Parasite) -> Vector3:
	return b.surface_point(par.spawn_dir, par.spawn_h)


## Seconds from the n-th return in a zone to the next one.
func interval(z: Dictionary, n: int) -> float:
	return lerpf(rules.every_min_s, rules.every_max_s, unit([key, z["ball"], z["zone"], n, "every"])) * rules.interval_scale()


func alive_in_zone(z: Dictionary) -> int:
	var c := 0
	for r in (balls[z["ball"]] as MossBall).returners:
		if is_instance_valid(r) and r.is_alive() and r.zone_id == z["zone"]:
			c += 1
	return c


func alive_on_ball(b: MossBall) -> int:
	var c := 0
	for r in b.returners:
		if is_instance_valid(r) and r.is_alive():
			c += 1
	return c


static func _all_cleared(authored: Array) -> bool:
	for par in authored:
		if par.is_alive():
			return false
	return true


## One look (Game calls this twice a second in play; `now` = the run's play seconds). Notes newly
## cleared zones, tidies returners that are gone, and lets at most one returner arrive on the player's ball.
## Returns the new returner, or null.
func update(now: float, ball: MossBall, gill_pos: Vector3, cam: Camera3D) -> Parasite:
	if not enabled:
		return null
	for z in zones.values():
		if float(z["cleared"]) < 0.0 and _all_cleared(z["authored"]):
			z["cleared"] = now
			z["next"] = now + rules.grace_s
	for b: MossBall in balls:
		_tidy(b)
	if not blooms_settled:
		# (Nobody arrives until the spots are measured from where the blooms really rest.)
		var all_placed := true
		for b: MossBall in balls:
			for bl in b.blooms:
				all_placed = all_placed and bl.is_placed()
		if not all_placed:
			return null
		_find_spots()
	if ball == null:
		return null
	if now - float(_last_arrival.get(ball.index, -INF)) < rules.spacing_s or alive_on_ball(ball) >= rules.ball_cap:
		return null
	var due := []
	for z in zones.values():
		if int(z["ball"]) == ball.index and (int(z.get("owed", 0)) > 0 or (float(z["cleared"]) >= 0.0 and now >= float(z["next"]))) \
				and not (z["eligible"] as Array).is_empty() and alive_in_zone(z) < int(z["cap"]) and rules.allows(z):
			due.append(z)
	due.sort_custom(func(a, b): return float(a["next"]) < float(b["next"]))
	for z in due:
		var par := _arrive(z, now, ball, gill_pos, cam)
		if par != null:
			return par
	return null


## A returner was killed: when its zone was full, the next return counts from now.
func on_killed(par: Parasite, now: float) -> void:
	var z: Dictionary = zones.get(zone_key(par.ball.index, par.zone_id), {})
	if z.is_empty():
		return
	if alive_in_zone(z) + 1 >= int(z["cap"]):
		z["next"] = maxf(float(z["next"]), now + interval(z, int(z["n"])))


func _tidy(b: MossBall) -> void:
	var changed := false
	for r in b.returners.duplicate():
		if not is_instance_valid(r) or r.state == "gone":
			b.returners.erase(r)
			if is_instance_valid(r):
				r.queue_free()
			changed = true
	if changed:
		b.returners_changed()


func _arrive(z: Dictionary, now: float, b: MossBall, gill_pos: Vector3, cam: Camera3D) -> Parasite:
	var n := int(z["n"])
	var el: Array = z["eligible"]
	# The authored mix: a hashed pick among the zone's spots, then the same species at another
	# spot when that one is in view or too close to him.
	var first: Parasite = el[int(unit([key, z["ball"], z["zone"], n, "pick"]) * el.size()) % el.size()]
	var order := [first]
	var k0 := el.find(first)
	for i in range(1, el.size()):
		var q: Parasite = el[(k0 + i) % el.size()]
		if q.kind == first.kind and q.variant == first.variant:
			order.append(q)
	for tpl: Parasite in order:
		var at := spot_of(b, tpl)
		var up := b.up_at(at)
		var dist := at.distance_to(gill_pos)
		if dist < rules.min_gill_m or on_camera(cam, at, up):
			continue
		var crowded := false
		for r in b.returners:
			crowded = crowded or (is_instance_valid(r) and r.is_alive() and r.global_position.distance_to(at) < 2.5)
		if crowded:
			continue
		var par := Parasite.new()
		par.setup(b, tpl.kind, tpl.zone_id, tpl.spawn_dir, rad_to_deg(tpl.home_radius), tpl.spawn_h, false)
		par.make_returner(int(unit([key, z["ball"], z["zone"], n, "rng"]) * 2147483647.0))
		if tpl.variant == "spitter":
			par.make_spitter()
		par.name = "Returner_%s_%d" % [z["zone"], n]
		b.add_child(par)
		# (Where it really stands once placed: a spot can settle it elsewhere, e.g. off a terrace's
		# edge. That must be out of view and far from him too, or it does not come this time.)
		var real := par.global_position
		if real.distance_to(gill_pos) < rules.min_gill_m or on_camera(cam, real, b.up_at(real)):
			b.remove_child(par)
			par.free()
			continue
		dist = real.distance_to(gill_pos)
		b.returners.append(par)
		b.returners_changed()
		z["n"] = n + 1
		if int(z.get("owed", 0)) > 0:
			# (A handed-over incursion returner: the zone's own timing is left as it was.)
			z["owed"] = int(z["owed"]) - 1
		else:
			z["next"] = now + interval(z, n + 1)
		_last_arrival[b.index] = now
		arrivals.append({"t": now, "ball": b.index, "zone": z["zone"], "n": n, "kind": tpl.kind, "variant": tpl.variant,
				"dist": dist, "on_camera": on_camera(cam, par.global_position, b.up_at(par.global_position))})
		return par
	return null


## Hard Mode: `count` returners are owed to this zone (an incursion's abstract load, handed over when
## Gill reaches its sphere). They arrive through the usual rules (off camera, far from him, spacing,
## caps); owed returners beyond the zone's free room are dropped.
func owe(zkey: String, count: int) -> void:
	var z: Dictionary = zones.get(zkey, {})
	if z.is_empty() or count <= 0:
		return
	z["owed"] = clampi(int(z.get("owed", 0)) + count, 0, maxi(0, int(z["cap"]) - alive_in_zone(z)))


## The timers for the run save (`run["world"]["repop"]`, additive): only zones that were cleared.
## Returners alive now are not saved (a continued run starts without them; the timers carry on).
func to_dict() -> Dictionary:
	var zs := {}
	for k in zones:
		var z: Dictionary = zones[k]
		if float(z["cleared"]) >= 0.0:
			zs[k] = {"cleared": snappedf(float(z["cleared"]), 0.001), "next": snappedf(float(z["next"]), 0.001), "n": int(z["n"])}
			if int(z.get("owed", 0)) > 0:
				zs[k]["owed"] = int(z["owed"])
	return {"format": FORMAT, "zones": zs}


## Restores saved timers. A newer format is ignored (its zones simply start over, from the next
## look). Zones cleared in a save without timers (an older build) start their grace when first seen.
func from_dict(d: Dictionary) -> void:
	if d.is_empty() or int(d.get("format", 0)) > FORMAT:
		return
	var zs: Dictionary = d.get("zones", {})
	for k in zs:
		if not zones.has(k) or not zs[k] is Dictionary:
			continue
		var s: Dictionary = zs[k]
		var z: Dictionary = zones[k]
		z["cleared"] = float(s.get("cleared", -1.0))
		z["next"] = float(s.get("next", float(z["cleared"]) + rules.grace_s))
		z["n"] = maxi(0, int(s.get("n", 0)))
		if s.has("owed"):
			z["owed"] = maxi(0, int(s["owed"]))


## For the diagnostics and the long simulation.
func summary() -> String:
	var cleared := 0
	var alive := 0
	var arrived := 0
	for z in zones.values():
		if float(z["cleared"]) >= 0.0:
			cleared += 1
		arrived += int(z["n"])
	for b: MossBall in balls:
		alive += alive_on_ball(b)
	return "Repopulation: %d of %d parasite zones cleared, %d returns so far, %d alive" % [cleared, zones.size(), arrived, alive]
