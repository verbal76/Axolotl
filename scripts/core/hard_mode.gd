class_name HardMode
extends RefCounted
## Hard Mode, the territorial tug of war (ledger row 12; spec docs/research/2026-09-30-DEVICE_AUDIT.md
## §E, §E2, the owner rulings of 2026-09-30 and the final ruling, option (b): slow remote incursions).
## Opt-in at New Run (`run["mode"] = "hard"`); a run without the key is Normal and never creates this.
##
## Vitality: every zone has V in [floor, 1]. Drawn moss health = permanent health x lerp(0.35, 1, V)
## (MossBall.set_vitality_image); the health map, restoration, earned ids, gates, crumbles and vortices
## never read V, so nothing earned can be lost and no route can close.
## - Load L of a zone = its live parasites and returners (small 1, medium 2, spitter 2, large 3), plus an
##   incursion's abstract load on a remote sphere.
## - On his current sphere (the full local model): dV/dt = -0.0010 x min(L, 6) / 3 while L > 0, for at
##   most two zones at once (the most loaded); +0.002/s at L = 0; a kill +0.12 eased over 3 s; a
##   restored Mote +0.10.
## - Floors: F = 0.20 + 0.40 x done/total, +0.10 with a touched bloom in the zone; a restored ball's
##   area-weighted mean stays >= 0.65.
## - Remote spheres are data only and frozen, except one incursion at a time: every 15-25 min of play
##   (hashed from the run key and n) on a sphere with a restored zone that he did not leave in the last
##   10 min; its abstract load ramps to the zone caps and decays at 15 % of the local rate, to the
##   floor plateau. When he arrives the abstract load is handed to Repopulation as owed returners.
## - Distress (derived, never saved): per sphere h = (V - F) / (1 - F); active pressure A = load >= 2
##   and V fell in the last 20 s; S1 h < 0.90, S2 < 0.65,
##   S3 < 0.35, each left 0.05 above its entry; without pressure one level down per 8 s. Every
##   connection's half at a remote threatened sphere signals its level (Vortex.set_distress).
## - Time is the run's play clock only (nothing while closed, paused, on the title or in the aquarium);
##   every choice is hashed (Repopulation.unit) from the run key: no random generator at all.

const FORMAT := 1
const MODE := "hard"
## The controller's rate (Game ticks it four times a second of play).
const TICK_S := 0.25
## A longer gap between two ticks (a load, a stall) never counts more than this.
const MAX_DT := 1.0
const DECAY_PER_S := 0.0010
const LOAD_CAP := 6.0
const KILL_GAIN := 0.12
const KILL_EASE_S := 3.0
const MOTE_GAIN := 0.10
const PASSIVE_PER_S := 0.002
const FLOOR_MIN := 0.20
const FLOOR_SPAN := 0.40
const BLOOM_FLOOR := 0.10
const COMPLETED_MEAN := 0.65
const MAX_LOSING := 2
const REMOTE_SHARE := 0.15
const INCURSION_MIN_S := 900.0
const INCURSION_MAX_S := 1500.0
const LEFT_RECENTLY_S := 600.0
## How long an incursion's abstract load takes to ramp up to the zone caps.
const INCURSION_RAMP_S := 120.0
## Zones an incursion presses at most (the anti-collapse rule: no more than two losing per sphere).
const INCURSION_ZONES := 2
const BALL_CAP := 10
## Distress levels: h below S_ENTER[k] enters level k + 1; a level is left S_EXIT above its entry.
const S_ENTER := [0.90, 0.65, 0.35]
const S_EXIT := 0.05
const STEP_DOWN_S := 8.0
const FALL_WINDOW_S := 20.0
const ACTIVE_LOAD := 2.0
## "Living aquarium" (a moment, never a completion id): every ball's mean V at least this.
const LIVING_V := 0.9
## A zone's vitality map is repainted once its V has moved this far from what was painted.
const REPAINT_DV := 0.01


## Hard Mode's returner rules (§E anti-collapse and anti-lock): a 240 s grace, then one every 180-300 s
## per zone (doubled while his health is 2 or less), cap ceil(0.5 x authored) per zone and 10 per ball,
## no returner within 20 m of a bloom, and none into a zone at its vitality floor.
class HardRules extends Repopulation.Rules:
	var slow := false
	var hard_ref: WeakRef = null

	func _init() -> void:
		grace_s = 240.0
		every_min_s = 180.0
		every_max_s = 300.0
		cap_frac = 0.5
		ball_cap = HardMode.BALL_CAP
		bloom_clear_m = 11.0    # (owner ruling 2026-10-01: the same proven buffer as Normal)

	func cap_for(authored: int) -> int:
		return 0 if authored <= 0 else ceili(cap_frac * authored)

	func interval_scale() -> float:
		return 2.0 if slow else 1.0

	func allows(z: Dictionary) -> bool:
		var h: HardMode = hard_ref.get_ref() if hard_ref != null else null
		return h == null or not h.at_floor(Repopulation.zone_key(int(z["ball"]), str(z["zone"])))


static func hard_rules() -> HardRules:
	return HardRules.new()


## The run's key (its run id; a fixed key in seeded test runs): every choice hashes from it.
var key := ""
var balls: Array = []
var vortices: Array = []
## Zone key -> {key, ball, zone, dir, radius (rad), area, authored (Array of Parasite), weights (Array),
## mb (the ball's own zone dict: done, total, completed), blooms (Array of Bloom), pix (Array)}.
var zones := {}
## Ball index -> Array of zone keys, in a stable order.
var ball_zones: Array = []
var ball_area: Array[float] = []
## Zone key -> V.
var v := {}
## Zone key -> Array of kill gains still easing in.
var eases := {}
## The remote incursion developing now: {} or {ball, start, n, zones: {zone key: {count, cap, w}}}.
var incursion := {}
## Plateaued incursions still waiting for him: ball index -> {zone key: abstract count}.
var pending := {}
var n_incursions := 0
var next_incursion := -1.0
## Ball index -> play second he last left it.
var left_at := {}
var living_seen := false
## Distress per ball (derived, never saved).
var levels: Array[int] = []
var _step_t: Array[float] = []
var _hist: Array = []
var losing := {}
var current := -1
var _last_now := -1.0
var _painted := {}
var _pix: Array = []
## Optional hooks (the long simulation): zone key -> real load; owed returners; ball -> restored.
var load_fn := Callable()
var owe_fn := Callable()
var completed_fn := Callable()
var cleared_fn := Callable()
var bloom_fn := Callable()
## Zone key -> whether a returner can ever arrive there (Repopulation's eligible spots): an incursion
## presses only zones its load can really come back to.
var can_return_fn := Callable()
## Every incursion start and hand-over, for tests and the simulation: {t, what, ball, zones}.
var events: Array = []
## The incursion interval (s of play; INCURSION_MIN_S..MAX_S): variables so the simulation can measure
## the ruling's remedy (a longer interval) without changing the game.
var incursion_min_s := INCURSION_MIN_S
var incursion_max_s := INCURSION_MAX_S
## True while drawing (the game): the vitality maps are painted and the vortices told.
var draw := true
## Emitted once per run when the whole aquarium is living (every ball restored, every mean V >= 0.9).
signal living_aquarium


static func weight_of(par: Parasite) -> float:
	if par.variant == "spitter":
		return 2.0
	return float(par.kind)


## Reads the world: every zone of every ball (its area, authored parasites, blooms and the map pixels
## it covers). V starts at 1 (nothing lost before pressure acts).
func build(p_balls: Array, p_vortices: Array) -> void:
	balls = p_balls
	vortices = p_vortices
	zones.clear()
	ball_zones.clear()
	ball_area.clear()
	for b: MossBall in balls:
		var keys: Array[String] = []
		var area := 0.0
		for zid in b.zones:
			var mz: Dictionary = b.zones[zid]
			var zk := Repopulation.zone_key(b.index, str(zid))
			var rad := deg_to_rad(float(mz["radius"]))
			var z := {"key": zk, "ball": b.index, "zone": str(zid), "dir": (mz["dir"] as Vector3).normalized(), "radius": rad,
					"area": 1.0 - cos(minf(rad, PI)), "authored": [], "weights": [], "mb": mz, "blooms": []}
			for par in b.parasites:
				if par.zone_id == str(zid):
					z["authored"].append(par)
					z["weights"].append(weight_of(par))
			for bl in b.blooms:
				if (bl.dir as Vector3).normalized().angle_to(z["dir"]) <= rad:
					z["blooms"].append(bl)
			zones[zk] = z
			keys.append(zk)
			area += float(z["area"])
			if not v.has(zk):
				v[zk] = 1.0
		ball_zones.append(keys)
		ball_area.append(maxf(area, 1e-6))
	_reset_derived()
	_build_pixels()


## The simulation's world: `layout` is an Array of balls, each an Array of zones {zone, area, weights,
## total, done, bloom}, all data (no nodes).
func build_data(layout: Array) -> void:
	zones.clear()
	ball_zones.clear()
	ball_area.clear()
	draw = false
	for bi in layout.size():
		var keys: Array[String] = []
		var area := 0.0
		for zd: Dictionary in layout[bi]:
			var zk := Repopulation.zone_key(bi, str(zd["zone"]))
			zones[zk] = {"key": zk, "ball": bi, "zone": str(zd["zone"]), "dir": Vector3.UP, "radius": 0.0, "area": float(zd["area"]),
					"authored": [], "weights": (zd["weights"] as Array).duplicate(),
					"mb": {"done": int(zd["done"]), "total": int(zd["total"]), "completed": int(zd["done"]) >= int(zd["total"])},
					"blooms": [], "bloom_touched": bool(zd.get("bloom", false))}
			keys.append(zk)
			area += float(zd["area"])
			if not v.has(zk):
				v[zk] = 1.0
		ball_zones.append(keys)
		ball_area.append(maxf(area, 1e-6))
	_reset_derived()


## The world as data, for the simulation (build_data).
func layout() -> Array:
	var out := []
	for bi in ball_zones.size():
		var bl := []
		for zk in ball_zones[bi]:
			var z: Dictionary = zones[zk]
			bl.append({"zone": z["zone"], "area": z["area"], "weights": z["weights"], "total": int(z["mb"]["total"]),
					"done": int(z["mb"]["done"]), "bloom": not (z["blooms"] as Array).is_empty()})
		out.append(bl)
	return out


func _reset_derived() -> void:
	levels.clear()
	_step_t.clear()
	_hist.clear()
	for i in ball_zones.size():
		levels.append(0)
		_step_t.append(0.0)
		_hist.append([])


# --- World reads ---------------------------------------------------------------------------------

func floor_of(zk: String) -> float:
	var z: Dictionary = zones[zk]
	var total := int(z["mb"]["total"])
	var r := 1.0 if total <= 0 else clampf(float(z["mb"]["done"]) / total, 0.0, 1.0)
	return minf(1.0, FLOOR_MIN + FLOOR_SPAN * r + (BLOOM_FLOOR if _bloom_touched(z) else 0.0))


func at_floor(zk: String) -> bool:
	return zones.has(zk) and float(v[zk]) <= floor_of(zk) + 1e-6


func _bloom_touched(z: Dictionary) -> bool:
	if bloom_fn.is_valid():
		return bloom_fn.call(z["key"])
	if z.has("bloom_touched"):
		return bool(z["bloom_touched"])
	for bl in z["blooms"]:
		if is_instance_valid(bl) and bl.active:
			return true
	return false


func ball_completed(bi: int) -> bool:
	if completed_fn.is_valid():
		return completed_fn.call(bi)
	if bi < balls.size():
		return (balls[bi] as MossBall).completed
	for zk in ball_zones[bi]:
		if int(zones[zk]["mb"]["done"]) < int(zones[zk]["mb"]["total"]):
			return false
	return true


func _zone_restored(zk: String) -> bool:
	var mz: Dictionary = zones[zk]["mb"]
	return bool(mz.get("completed", false))


## All the zone's authored parasites are gone (returners may come).
func _cleared(zk: String) -> bool:
	if cleared_fn.is_valid():
		return cleared_fn.call(zk)
	var z: Dictionary = zones[zk]
	if not z.has("authored") or (z["authored"] as Array).is_empty():
		return (z["weights"] as Array).size() > 0 and bool(z["mb"].get("completed", false))
	for par in z["authored"]:
		if is_instance_valid(par) and par.is_alive():
			return false
	return true


## The zone's real load (live authored parasites and returners homed there).
func real_load(zk: String) -> float:
	if load_fn.is_valid():
		return load_fn.call(zk)
	var z: Dictionary = zones[zk]
	var l := 0.0
	for par in z["authored"]:
		if is_instance_valid(par) and par.is_alive():
			l += weight_of(par)
	if int(z["ball"]) < balls.size():
		for r in (balls[int(z["ball"])] as MossBall).returners:
			if is_instance_valid(r) and r.is_alive() and r.zone_id == z["zone"]:
				l += weight_of(r)
	return l


## The abstract load an incursion (developing or plateaued) puts on the zone.
func abstract_load(zk: String) -> float:
	var bi := int(zones[zk]["ball"])
	if not incursion.is_empty() and int(incursion["ball"]) == bi and (incursion["zones"] as Dictionary).has(zk):
		var iz: Dictionary = incursion["zones"][zk]
		return float(iz["count"]) * float(iz["w"])
	if pending.has(bi) and (pending[bi] as Dictionary).has(zk):
		var pz: Dictionary = pending[bi][zk]
		return float(pz["count"]) * float(pz["w"])
	return 0.0


func zone_load(zk: String) -> float:
	return real_load(zk) + abstract_load(zk)


# --- Reads for the HUD, the vortices and tests ------------------------------------------------------

func ball_mean(bi: int) -> float:
	var s := 0.0
	for zk in ball_zones[bi]:
		s += float(zones[zk]["area"]) * float(v[zk])
	return s / ball_area[bi]


func ball_floor(bi: int) -> float:
	var s := 0.0
	for zk in ball_zones[bi]:
		s += float(zones[zk]["area"]) * floor_of(zk)
	return s / ball_area[bi]


## Normalised sphere health h = (V - F) / (1 - F) (1 when the floor is already 1).
func ball_h(bi: int) -> float:
	var f := ball_floor(bi)
	if f >= 0.9999:
		return 1.0
	return clampf((ball_mean(bi) - f) / (1.0 - f), 0.0, 1.0)


func ball_load(bi: int) -> float:
	var s := 0.0
	for zk in ball_zones[bi]:
		s += zone_load(zk)
	return s


## The zone at `dir` on the ball (the nearest centre relative to its size), or "" outside every zone.
func zone_at(bi: int, dir: Vector3) -> String:
	var best := ""
	var bq := 1.12
	var d := dir.normalized()
	for zk in ball_zones[bi]:
		var z: Dictionary = zones[zk]
		var q := d.angle_to(z["dir"]) / maxf(float(z["radius"]), 0.001)
		if q < bq:
			bq = q
			best = zk
	return best


## The level the vortex halves at this sphere show: its own level when remote, 0 on his own sphere.
func signal_level(bi: int) -> int:
	return 0 if bi == current else levels[bi]


# --- Events -------------------------------------------------------------------------------------

func on_kill(bi: int, zone_id: String) -> void:
	var zk := Repopulation.zone_key(bi, zone_id)
	if not zones.has(zk):
		return
	if not eases.has(zk):
		eases[zk] = []
	(eases[zk] as Array).append(KILL_GAIN)


func on_mote(bi: int, zone_id: String) -> void:
	var zk := Repopulation.zone_key(bi, zone_id)
	if zones.has(zk):
		v[zk] = minf(1.0, float(v[zk]) + MOTE_GAIN)


# --- The tick -----------------------------------------------------------------------------------

## One step (Game: four times a second of play; `now` = the run's play seconds, `cur` = his ball,
## `health` = his fronds, for the slower return rate at 2 or less).
func tick(now: float, cur: int, health := 99) -> void:
	var dt := 0.0 if _last_now < 0.0 else clampf(now - _last_now, 0.0, MAX_DT)
	_last_now = now
	if next_incursion < 0.0:
		next_incursion = now + incursion_interval(n_incursions)
	if cur != current:
		if current >= 0:
			left_at[current] = now
		current = cur
	_arrive(cur, now)
	var lost := {}
	losing.clear()
	if cur >= 0 and cur < ball_zones.size():
		_local(cur, dt, lost)
	var inc_before := {}
	if not incursion.is_empty():
		for zk in incursion["zones"]:
			inc_before[zk] = float(v[zk])
	_remote(cur, dt, now, lost)
	_ease(dt)
	for bi in ball_zones.size():
		_hold_floors(bi, lost)
	if dt > 0.0:
		_check_plateau(now, inc_before)
	_distress(now, dt)
	if draw:
		_paint()
		_tell_vortices()
	if not living_seen and _living():
		living_seen = true
		living_aquarium.emit()


func _local(bi: int, dt: float, lost: Dictionary) -> void:
	var loaded := []
	for zk in ball_zones[bi]:
		var l := zone_load(zk)
		if l > 0.0:
			if float(v[zk]) > floor_of(zk) + 1e-6:
				loaded.append([l, zk])
		else:
			v[zk] = minf(1.0, float(v[zk]) + PASSIVE_PER_S * dt)
	# (At most two zones of a ball lose at once: the most loaded, ties in the ball's own order.)
	loaded.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and str(a[1]) < str(b[1])))
	for i in mini(MAX_LOSING, loaded.size()):
		var zk: String = loaded[i][1]
		var dv := DECAY_PER_S * minf(float(loaded[i][0]), LOAD_CAP) / 3.0 * dt
		_lose(zk, dv, lost)


func _lose(zk: String, dv: float, lost: Dictionary) -> void:
	var f := floor_of(zk)
	var before := float(v[zk])
	var after := maxf(f, before - dv)
	v[zk] = after
	if after < before:
		lost[zk] = float(lost.get(zk, 0.0)) + before - after
		losing[zk] = true


func _remote(cur: int, dt: float, now: float, lost: Dictionary) -> void:
	if incursion.is_empty():
		if now >= next_incursion:
			_start_incursion(cur, now)
		return
	var bi := int(incursion["ball"])
	var zs: Dictionary = incursion["zones"]
	var k := clampf((now - float(incursion["start"])) / INCURSION_RAMP_S, 0.0, 1.0)
	var room := BALL_CAP - _real_returners(bi)
	var total := 0
	for zk in zs:
		total += int(zs[zk]["count"])
	for zk in zs:
		var iz: Dictionary = zs[zk]
		var want := ceili(float(iz["cap"]) * k)
		# (No more returners into a zone at its floor; the ball's cap holds.)
		while int(iz["count"]) < want and total < room and not at_floor(zk):
			iz["count"] = int(iz["count"]) + 1
			total += 1
		var l := float(iz["count"]) * float(iz["w"])
		if l > 0.0:
			_lose(zk, REMOTE_SHARE * DECAY_PER_S * minf(l, LOAD_CAP) / 3.0 * dt, lost)



## The floor plateau: once fully ramped, none of its zones can lose any more (each at its floor, or the
## restored ball's 0.65 mean holding them). The incursion ends there and its signal settles; its load
## waits for him.
func _check_plateau(now: float, before: Dictionary) -> void:
	if incursion.is_empty() or now - float(incursion["start"]) < INCURSION_RAMP_S:
		return
	var zs: Dictionary = incursion["zones"]
	for zk in zs:
		if not at_floor(zk) and float(v[zk]) < float(before.get(zk, -1.0)) - 1e-12:
			return
	var bi := int(incursion["ball"])
	var pz := {}
	for zk in zs:
		pz[zk] = {"count": int(zs[zk]["count"]), "w": float(zs[zk]["w"])}
	pending[bi] = pz
	events.append({"t": now, "what": "plateau", "ball": bi, "zones": zs.keys()})
	incursion = {}


func _real_returners(bi: int) -> int:
	if bi >= balls.size():
		return 0
	var c := 0
	for r in (balls[bi] as MossBall).returners:
		if is_instance_valid(r) and r.is_alive():
			c += 1
	return c


## Seconds from the n-th incursion's start to the next one's.
func incursion_interval(n: int) -> float:
	return lerpf(incursion_min_s, incursion_max_s, Repopulation.unit([key, "incursion", n, "every"]))


## The spheres an incursion may start on now: not his, not one he left in the last 10 min, none
## already waiting for him, with a restored zone and a cleared zone above its floor.
func incursion_candidates(cur: int, now: float) -> Array:
	var out := []
	for bi in ball_zones.size():
		if bi == cur or pending.has(bi) or now - float(left_at.get(bi, -INF)) < LEFT_RECENTLY_S:
			continue
		var restored := false
		for zk in ball_zones[bi]:
			restored = restored or _zone_restored(zk)
		if restored and not _incursion_zones(bi).is_empty():
			out.append(bi)
	return out


func _incursion_zones(bi: int) -> Array:
	var out := []
	for zk in ball_zones[bi]:
		var z: Dictionary = zones[zk]
		if not (z["weights"] as Array).is_empty() and _cleared(zk) and float(v[zk]) > floor_of(zk) + 0.01 \
				and (not can_return_fn.is_valid() or can_return_fn.call(zk)):
			out.append(zk)
	return out


func _start_incursion(cur: int, now: float) -> void:
	var cands := incursion_candidates(cur, now)
	if cands.is_empty():
		return
	var n := n_incursions
	var bi: int = cands[int(Repopulation.unit([key, "incursion", n, "ball"]) * cands.size()) % cands.size()]
	var pool := _incursion_zones(bi)
	var zs := {}
	for i in mini(INCURSION_ZONES, pool.size()):
		var j := int(Repopulation.unit([key, "incursion", n, "zone", i]) * pool.size()) % pool.size()
		var zk: String = pool[j]
		pool.remove_at(j)
		var ws: Array = zones[zk]["weights"]
		var w := 0.0
		for x in ws:
			w += float(x)
		zs[zk] = {"count": 0, "cap": ceili(0.5 * ws.size()), "w": w / ws.size()}
	incursion = {"ball": bi, "start": now, "n": n, "zones": zs}
	n_incursions = n + 1
	next_incursion = now + incursion_interval(n_incursions)
	events.append({"t": now, "what": "start", "ball": bi, "zones": zs.keys()})


## He reached a sphere with an incursion (developing or plateaued): its abstract load becomes real
## returners (Repopulation.owe: off camera, far from him, the usual spacing), and the local model resumes.
func _arrive(cur: int, now: float) -> void:
	var hand := {}
	if not incursion.is_empty() and int(incursion["ball"]) == cur:
		hand = incursion["zones"]
		incursion = {}
	elif pending.has(cur):
		hand = pending[cur]
		pending.erase(cur)
	else:
		return
	for zk in hand:
		var c := int(hand[zk]["count"])
		if c > 0 and owe_fn.is_valid():
			owe_fn.call(zk, c)
	events.append({"t": now, "what": "arrive", "ball": cur, "zones": hand.keys()})


func _ease(dt: float) -> void:
	var rate := KILL_GAIN / KILL_EASE_S * dt
	for zk in eases.keys():
		var arr: Array = eases[zk]
		var add := 0.0
		for i in range(arr.size() - 1, -1, -1):
			var a := minf(float(arr[i]), rate)
			add += a
			arr[i] = float(arr[i]) - a
			if float(arr[i]) <= 1e-9:
				arr.remove_at(i)
		v[zk] = minf(1.0, float(v[zk]) + add)
		if arr.is_empty():
			eases.erase(zk)


## Never below a floor (floors rise as zones are restored); a restored ball's mean never below 0.65:
## this tick's losses are given back first, then every zone is lifted alike.
func _hold_floors(bi: int, lost: Dictionary) -> void:
	for zk in ball_zones[bi]:
		var f := floor_of(zk)
		if float(v[zk]) < f:
			v[zk] = f
	if not ball_completed(bi):
		return
	var deficit := (COMPLETED_MEAN - ball_mean(bi)) * ball_area[bi]
	if deficit <= 1e-9:
		return
	var lsum := 0.0
	for zk in ball_zones[bi]:
		lsum += float(zones[zk]["area"]) * float(lost.get(zk, 0.0))
	if lsum > 0.0:
		var k := minf(1.0, deficit / lsum)
		for zk in ball_zones[bi]:
			if lost.has(zk):
				var back := float(lost[zk]) * k
				v[zk] = float(v[zk]) + back
				if k >= 1.0:
					losing.erase(zk)
		deficit = (COMPLETED_MEAN - ball_mean(bi)) * ball_area[bi]
	for _i in 4:
		if deficit <= 1e-9:
			break
		var room := 0.0
		for zk in ball_zones[bi]:
			if float(v[zk]) < 1.0:
				room += float(zones[zk]["area"])
		if room <= 0.0:
			break
		var d := deficit / room
		for zk in ball_zones[bi]:
			if float(v[zk]) < 1.0:
				v[zk] = minf(1.0, float(v[zk]) + d)
		deficit = (COMPLETED_MEAN - ball_mean(bi)) * ball_area[bi]


func _distress(now: float, dt: float) -> void:
	for bi in ball_zones.size():
		var vb := ball_mean(bi)
		var hist: Array = _hist[bi]
		hist.append([now, vb])
		while hist.size() > 2 and now - float(hist[0][0]) > FALL_WINDOW_S:
			hist.pop_front()
		var falling: bool = vb < float(hist[0][1]) - 1e-7
		# (Owner ruling 2026-10-01: a warning shows the sphere's current condition, not that he has not
		# come yet. A plateaued incursion no longer pushes, so its signal settles; its load still waits
		# there and arrives as returners when he does, so staying away gains nothing.)
		var active := ball_load(bi) >= ACTIVE_LOAD and falling
		var lv := levels[bi]
		if active:
			var h := ball_h(bi)
			while lv < 3 and h < float(S_ENTER[lv]):
				lv += 1
			while lv > 0 and h >= float(S_ENTER[lv - 1]) + S_EXIT:
				lv -= 1
			_step_t[bi] = 0.0
		elif lv > 0:
			_step_t[bi] += dt
			if _step_t[bi] >= STEP_DOWN_S:
				_step_t[bi] = 0.0
				lv -= 1
		levels[bi] = lv


func _living() -> bool:
	for bi in ball_zones.size():
		if not ball_completed(bi) or ball_mean(bi) < LIVING_V:
			return false
	return true


# --- Drawing ------------------------------------------------------------------------------------

## Which zone each pixel of a ball's 64 x 32 vitality map belongs to (-1: none, drawn at full).
func _build_pixels() -> void:
	_pix.clear()
	_painted.clear()
	for bi in ball_zones.size():
		var map := PackedInt32Array()
		map.resize(MossBall.VIT_W * MossBall.VIT_H)
		for y in MossBall.VIT_H:
			var la := (0.5 - (y + 0.5) / MossBall.VIT_H) * PI
			for x in MossBall.VIT_W:
				var lo := ((x + 0.5) / MossBall.VIT_W - 0.5) * TAU
				var d := Vector3(cos(la) * sin(lo), sin(la), cos(la) * cos(lo))
				var zk := zone_at(bi, d)
				map[y * MossBall.VIT_W + x] = (ball_zones[bi] as Array).find(zk) if zk != "" else -1
		_pix.append(map)


func _paint(force := false) -> void:
	for bi in mini(balls.size(), _pix.size()):
		var dirty := force or not _painted.has(bi)
		if not dirty:
			for zk in ball_zones[bi]:
				if absf(float(v[zk]) - float((_painted[bi] as Dictionary).get(zk, -1.0))) > REPAINT_DV:
					dirty = true
					break
		if not dirty:
			continue
		var keys: Array = ball_zones[bi]
		var vals := PackedByteArray()
		vals.resize(keys.size())
		var snap := {}
		for i in keys.size():
			vals[i] = clampi(roundi(float(v[keys[i]]) * 255.0), 0, 255)
			snap[keys[i]] = float(v[keys[i]])
		var map: PackedInt32Array = _pix[bi]
		var data := PackedByteArray()
		data.resize(map.size())
		for i in map.size():
			data[i] = 255 if map[i] < 0 else vals[map[i]]
		(balls[bi] as MossBall).set_vitality_image(Image.create_from_data(MossBall.VIT_W, MossBall.VIT_H, false, Image.FORMAT_R8, data))
		_painted[bi] = snap


func _tell_vortices() -> void:
	for vt in vortices:
		(vt as Vortex).set_distress(signal_level((vt as Vortex).ball_a.index), signal_level((vt as Vortex).ball_b.index))


## Paints every ball now (when the run opens).
func paint_all() -> void:
	_paint(true)


# --- Save ---------------------------------------------------------------------------------------

## `run["world"]["vitality"]` (additive; the distress levels are derived and never saved).
func to_dict() -> Dictionary:
	var vs := {}
	for zk in v:
		vs[zk] = snappedf(float(v[zk]), 0.00001)
	var es := {}
	for zk in eases:
		es[zk] = (eases[zk] as Array).map(func(x): return snappedf(float(x), 0.00001))
	var pd := {}
	for bi in pending:
		pd[str(bi)] = (pending[bi] as Dictionary).duplicate(true)
	var la := {}
	for bi in left_at:
		la[str(bi)] = snappedf(float(left_at[bi]), 0.001)
	return {"format": FORMAT, "v": vs, "ease": es, "incursion": incursion.duplicate(true), "pending": pd, "n": n_incursions,
			"next": snappedf(next_incursion, 0.001), "left": la, "living": living_seen}


## Restores a saved state. A newer format is ignored (V starts again at 1; nothing earned is touched).
func from_dict(d: Dictionary) -> void:
	if d.is_empty() or int(d.get("format", 0)) > FORMAT:
		return
	var vs: Dictionary = d.get("v", {})
	for zk in vs:
		if zones.has(zk):
			v[zk] = clampf(float(vs[zk]), 0.0, 1.0)
	eases.clear()
	var es: Dictionary = d.get("ease", {})
	for zk in es:
		if zones.has(zk) and es[zk] is Array:
			eases[zk] = (es[zk] as Array).map(func(x): return float(x))
	incursion = {}
	var inc: Dictionary = d.get("incursion", {})
	if not inc.is_empty() and int(inc.get("ball", -1)) >= 0 and int(inc["ball"]) < ball_zones.size():
		var zs := {}
		for zk in inc.get("zones", {}):
			if zones.has(zk):
				var iz: Dictionary = inc["zones"][zk]
				zs[zk] = {"count": int(iz.get("count", 0)), "cap": int(iz.get("cap", 0)), "w": float(iz.get("w", 1.0))}
		incursion = {"ball": int(inc["ball"]), "start": float(inc.get("start", 0.0)), "n": int(inc.get("n", 0)), "zones": zs}
	pending.clear()
	var pd: Dictionary = d.get("pending", {})
	for bs in pd:
		var pz := {}
		for zk in pd[bs]:
			if zones.has(zk):
				pz[zk] = {"count": int(pd[bs][zk].get("count", 0)), "w": float(pd[bs][zk].get("w", 1.0))}
		pending[int(bs)] = pz
	n_incursions = int(d.get("n", 0))
	next_incursion = float(d.get("next", -1.0))
	left_at.clear()
	var la: Dictionary = d.get("left", {})
	for bs in la:
		left_at[int(bs)] = float(la[bs])
	living_seen = bool(d.get("living", false))


## For the diagnostics.
func summary() -> String:
	var parts: Array[String] = []
	for bi in ball_zones.size():
		parts.append("%d:%.2f/S%d" % [bi + 1, ball_mean(bi), levels[bi]])
	var inc := "none" if incursion.is_empty() else "ball %d since %.0f s" % [int(incursion["ball"]) + 1, float(incursion["start"])]
	return "Hard Mode: mean V per ball %s; incursion %s; waiting %s; next at %.0f s (%d so far)" % [" ".join(parts), inc,
			str(pending.keys().map(func(x): return x + 1)), next_incursion, n_incursions]
