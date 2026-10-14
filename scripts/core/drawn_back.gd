class_name DrawnBack
extends RefCounted
## Dead areas (owner finding, 2026-10-06, physical play): a player who keeps exploring a moss ball that
## still needs restoring must not wander for minutes through cleared, empty ground with nothing useful
## to fight. The hints (RestoreHints) say where the rest is; this makes sure something useful comes to
## meet him too.
##
## When, on his ball, Gill has gone DRY_S of play and TRAVEL_M of roaming without any restoration
## progress there, and no required (authored) parasite is left within NEAR_M of him, one of the ball's
## own outstanding parasites, grazing far away (FAR_M or more) where nobody sees it, is drawn back to the
## healed moss: it moves, unseen, to a spot where an authored parasite of a cleared zone once lived,
## DEST_MIN_M..DEST_MAX_M from him (about DEST_BEST_M), off camera, preferably ahead of where he is heading, clear of other
## parasites, on open ground (never a cave spot for a parasite that did not live in one, nor the other
## way round) and never by a vortex pad or a bloom (the spots Repopulation already allows).
##
## Why (audit, 2026-10-06): a ball's required parasites are a fixed, finite set at fixed homes that never
## respawn, and returners (Repopulation) restore nothing by design, so as a ball is cleared the useful
## enemies left are few and far while the cleared ground he crosses holds nothing useful.
##
## Nothing is added: the same parasite, the same species and variant, its own completion id and zone.
## Killing it counts exactly as before (its zone's event; the heal regrows at its original home, with
## the usual wisp there), so restoration, the catalog and the save are untouched (positions are not
## saved: a continued run finds it at home again). One at a time per ball, COOLDOWN_S apart, and only
## after another dry spell: no spawn storms, no farming (returners stay as they are and still restore
## nothing). Nothing random is drawn.

const DRY_S := 45.0
const TRAVEL_M := 45.0
const NEAR_M := 30.0
const FAR_M := 45.0
const DEST_MIN_M := 18.0
const DEST_MAX_M := 30.0
## The distance preferred among the allowed ones: about where a player looking round would spot it.
const DEST_BEST_M := 24.0
const COOLDOWN_S := 40.0
const CROWD_M := 6.0
## Destination spots on the ground only (an authored spot's own height above it, metres).
const MAX_SPOT_H := 0.6
const LOOK_S := 0.5

## Off: no clock, no moves (the unit suite runs without it unless a test asks).
var enabled := true
## Ball index -> {done, t (play s dry), m (metres roamed dry), last (position)}.
var dry := {}
var _next_ok := {}
var _look_t := 0.0
## Every move, for tests and diagnostics: {t, ball, zone, kind, from, to, gill_to_spot, on_camera}.
var moves: Array = []


## Every frame of play on a moss ball. `quiet`: the tutorial is speaking (its clock waits).
func update(dt: float, now: float, b: MossBall, gill_pos: Vector3, gill_fwd: Vector3, cam: Camera3D, quiet: bool, repop: Repopulation) -> Parasite:
	if not enabled or b == null:
		return null
	var r: Dictionary = dry.get(b.index, {})
	if r.is_empty() or int(r["done"]) != b.events_done:
		r = {"done": b.events_done, "t": 0.0, "m": 0.0, "last": gill_pos}
		dry[b.index] = r
	if not quiet:
		r["t"] = float(r["t"]) + dt
		# (A respawn or a ride jumps him: only ordinary movement counts as roaming.)
		r["m"] = float(r["m"]) + minf(gill_pos.distance_to(r["last"]), 3.0)
	r["last"] = gill_pos
	_look_t -= dt
	if _look_t > 0.0:
		return null
	_look_t = LOOK_S
	if float(r["t"]) < DRY_S or float(r["m"]) < TRAVEL_M or now < float(_next_ok.get(b.index, -INF)) or b.completed or repop == null:
		return null
	var par := draw_one(now, b, gill_pos, gill_fwd, cam, repop)
	if par != null:
		r["t"] = 0.0
		r["m"] = 0.0
		_next_ok[b.index] = now + COOLDOWN_S
	return par


## The ball's required parasites still to be killed.
static func outstanding(b: MossBall) -> Array:
	var out := []
	for par in b.parasites:
		if is_instance_valid(par) and not par.returner and par.hp > 0 and par.state not in ["dying", "drifting", "gone"]:
			out.append(par)
	return out


static func in_cave(b: MossBall, pos: Vector3) -> bool:
	for c in b.caves:
		if c.w > 0.0 and pos.distance_to(Vector3(c.x, c.y, c.z)) < c.w:
			return true
	return false


## The spots a parasite may be drawn to: where authored parasites of zones Gill has cleared lived
## (Repopulation's allowed spots: clear of vortex pads and blooms), on the ground.
static func spots(b: MossBall, repop: Repopulation) -> Array:
	var out := []
	for z in repop.zones.values():
		if int(z["ball"]) != b.index or not Repopulation._all_cleared(z["authored"]):
			continue
		for tpl: Parasite in z["eligible"]:
			if tpl.spawn_h <= MAX_SPOT_H:
				out.append(tpl.spawn_dir)
	return out


## Draws one outstanding parasite toward him now if the rules allow (see the class notes); returns it.
func draw_one(now: float, b: MossBall, gill_pos: Vector3, gill_fwd: Vector3, cam: Camera3D, repop: Repopulation) -> Parasite:
	var left := outstanding(b)
	if left.is_empty():
		return null
	for par: Parasite in left:
		if par.global_position.distance_to(gill_pos) < NEAR_M:
			return null
	var far := left.filter(func(p: Parasite) -> bool:
		return p.state == "graze" and p.global_position.distance_to(gill_pos) >= FAR_M \
				and not Repopulation.on_camera(cam, p.global_position, p.up))
	far.sort_custom(func(a: Parasite, c: Parasite) -> bool: return a.global_position.distance_to(gill_pos) < c.global_position.distance_to(gill_pos))
	var up := b.up_at(gill_pos)
	var fwd := gill_fwd - up * gill_fwd.dot(up)
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.ZERO
	var dirs := spots(b, repop)
	for par: Parasite in far:
		var cave_home := in_cave(b, b.surface_point(par.origin_dir()))
		var best := Vector3.ZERO
		var best_s := -INF
		for d: Vector3 in dirs:
			var at := b.surface_point(d)
			var dist := at.distance_to(gill_pos)
			if dist < DEST_MIN_M or dist > DEST_MAX_M or in_cave(b, at) != cave_home or Repopulation.on_camera(cam, at, d):
				continue
			var crowded := false
			for q in b.hostiles():
				crowded = crowded or (is_instance_valid(q) and q != par and q.is_alive() and q.global_position.distance_to(at) < CROWD_M)
			if crowded:
				continue
			var s := fwd.dot((at - gill_pos).normalized()) - absf(dist - DEST_BEST_M) / 20.0
			if s > best_s:
				best_s = s
				best = d
		if best == Vector3.ZERO:
			continue
		# (Where it would really stand: on the ground, out of view and not on top of him; else try the
		# next one.)
		var g: Array = par.ground_at(best)
		var real: Vector3 = g[0]
		if real.distance_to(gill_pos) < DEST_MIN_M - 2.0 or Repopulation.on_camera(cam, real, best) or b.altitude(real) > MAX_SPOT_H + 1.2:
			continue
		var from := par.global_position
		if not par.move_home(best):
			continue
		real = par.global_position
		moves.append({"t": now, "ball": b.index, "zone": par.zone_id, "kind": par.kind, "from": from, "to": real,
				"gill_to_spot": real.distance_to(gill_pos), "on_camera": Repopulation.on_camera(cam, real, par.up)})
		return par
	return null


func summary() -> String:
	return "drawn back: %d moves" % moves.size()
