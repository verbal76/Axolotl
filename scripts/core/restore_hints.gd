class_name RestoreHints
extends RefCounted
## Owner, 2026-10-02: help a player who has searched an unrestored area for a while and clearly
## missed something, without turning Mote into a checklist. Per zone of his ball, the play seconds
## Gill has spent in it since its last progress (a parasite killed or a mote restored there):
##  - under SHIMMER_S: nothing;
##  - from SHIMMER_S: each of the zone's remaining targets sends up a slow green plume that shows over
##    the terrain;
##  - from GUIDE_S: also a faint drift of glimmers leaves Gill toward the nearest one (in 3D: up or
##    down a slope, a pillar or into a cave mouth too);
##  - at COUNT_S, once: a small fading note of how many are left in the area.
## Progress in the zone starts it over. Only authored targets that still count for restoration are
## used: never returners (Repopulation), never anything already done. The economy is untouched: this
## only reads. Not saved (a continued run starts quiet).

const SHIMMER_S := 90.0
const GUIDE_S := 180.0
const COUNT_S := 300.0
const SHIMMER_EVERY_S := 2.6
const GUIDE_EVERY_S := 1.7
const PLUMES_MAX := 4
const COL := Color(0.55, 1.0, 0.62, 0.8)

## Zone key ("b<ball>.<zone>") -> play seconds searched since its last progress.
var stuck := {}
var _done := {}
var _counted := {}
var _shim_t := 0.0
var _guide_t := 0.0
## For tests: the zone key Gill is in (unrestored only; "b<ball>.*" when he is in none, or in one with
## nothing left, while the ball still has targets), the stage there (0-3) and the last guide
## direction (unit, world space).
var zone := ""
var stage := 0
var last_guide_dir := Vector3.ZERO
var plumes := 0
## Off: no clock, no cues (the unit suite runs without it unless a test asks).
var enabled := true


## The unrestored zone that `dir` (from the ball's centre) lies in, or "" (deepest inside wins).
static func zone_at(b: MossBall, dir: Vector3) -> String:
	var best := ""
	var best_f := 1.0
	for id in b.zones:
		var z: Dictionary = b.zones[id]
		if z["completed"]:
			continue
		var f := dir.angle_to(z["dir"]) / deg_to_rad(float(z["radius"]))
		if f <= best_f:
			best_f = f
			best = id
	return best


## Positions of the zone's targets that still count: authored parasites alive, motes not restored.
static func remaining(b: MossBall, zone_id: String) -> Array:
	var out: Array = []
	for par in b.parasites:
		if is_instance_valid(par) and not par.returner and par.zone_id == zone_id and par.hp > 0:
			out.append(par.global_position)
	for m in b.motes:
		if is_instance_valid(m) and m.zone_id == zone_id and m.state in ["init", "wander"]:
			out.append(m.global_position)
	return out


## Every frame of play. `quiet`: the tutorial is speaking (no hints, no clock).
func update(dt: float, b: MossBall, gill_pos: Vector3, quiet: bool) -> void:
	for id in b.zones:
		var key := "b%d.%s" % [b.index, id]
		var d: int = b.zones[id]["done"]
		if _done.get(key, d) != d:
			stuck[key] = 0.0
			_counted.erase(key)
		_done[key] = d
	var id := zone_at(b, (gill_pos - b.global_position).normalized())
	var targets := remaining(b, id) if id != "" else []
	# Owner, v96 phone test: waiting between areas (or in one already cleared while others are not)
	# must not leave him without help. Then the clock is the ball's own, its progress anywhere starts
	# it over, and the hints point to what is left anywhere on the ball.
	var whole := false
	if targets.is_empty():
		whole = true
		id = ""
		for zid in b.zones:
			if not b.zones[zid]["completed"]:
				targets.append_array(remaining(b, zid))
		var done_all := 0
		for zid in b.zones:
			done_all += int(b.zones[zid]["done"])
		var bk := "b%d.*" % b.index
		if _done.get(bk, done_all) != done_all:
			stuck[bk] = 0.0
			_counted.erase(bk)
		_done[bk] = done_all
	zone = ("b%d.*" % b.index) if whole else "b%d.%s" % [b.index, id]
	stage = 0
	if quiet or not enabled or targets.is_empty():
		return
	var t: float = stuck.get(zone, 0.0) + dt
	stuck[zone] = t
	stage = 3 if t >= COUNT_S else (2 if t >= GUIDE_S else (1 if t >= SHIMMER_S else 0))
	if stage == 0:
		return
	targets.sort_custom(func(a: Vector3, c: Vector3) -> bool: return a.distance_squared_to(gill_pos) < c.distance_squared_to(gill_pos))
	_shim_t -= dt
	if _shim_t <= 0.0:
		_shim_t = SHIMMER_EVERY_S
		plumes = mini(PLUMES_MAX, targets.size())
		for k in plumes:
			_plume(b, targets[k])
	if stage >= 2:
		_guide_t -= dt
		if _guide_t <= 0.0:
			_guide_t = GUIDE_EVERY_S
			var up := (gill_pos - b.global_position).normalized()
			var from := gill_pos + up * 0.7
			last_guide_dir = (targets[0] - from).normalized()
			if WaterFX.inst != null:
				WaterFX.inst.wisp(from + last_guide_dir * 1.0, from + last_guide_dir * 5.0, 1.6, COL, 7)
	if stage == 3 and not _counted.has(zone):
		_counted[zone] = true
		var hud = Game.inst.hud if Game.inst != null else null
		if hud != null:
			var where := "on this moss ball" if whole else "in this area"
			hud.show_discovery("%d left to restore %s" % [targets.size(), where] if targets.size() != 1 else "1 left to restore %s" % where)


## A slow plume rising from a target, tall enough to show over a ridge or out of a hollow.
func _plume(b: MossBall, pos: Vector3) -> void:
	if WaterFX.inst == null:
		return
	var up := (pos - b.global_position).normalized()
	WaterFX.inst.sparkle(pos + up * 0.4, COL, 6, 0.5, 0.09, 1.3)
	for k in 5:
		WaterFX.inst._spawn_puff(pos + up * (0.3 + k * 0.5), up * 1.4, 2.4, 0.22 - k * 0.025, COL * Color(1, 1, 1, 0.75 - k * 0.1), 0.2)
