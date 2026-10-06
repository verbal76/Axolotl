class_name RestoreHints
extends RefCounted
## Owner, 2026-10-02: help a player who has searched an unrestored area for a while and clearly
## missed something, without turning Mote into a checklist. Per zone of his ball, the play seconds
## Gill has spent in it since its last progress (a parasite killed or a mote restored there):
##  - under SHIMMER_S: nothing;
##  - from SHIMMER_S: each of the zone's remaining targets sends up a tall, wispy, soft-pink plume that
##    shows over the terrain and over the ball's curve (owner, 2026-10-06: the green one blended in);
##  - from GUIDE_S: also, every GUIDE_EVERY_S, a little string of bubbles (GuideBubbles) leaves Gill
##    toward the nearest one, weaving as it goes and popping one bubble at a time, with a soft
##    "blub" now and then (at most every SOUND_EVERY_S).
## Owner, 2026-10-06: both start 30 s sooner than before, and the "N left" note is gone (the world's
## own cues are enough).
## Progress in the zone starts it over. Only authored targets that still count for restoration are
## used: never returners (Repopulation), never anything already done. The economy is untouched: this
## only reads. Not saved (a continued run starts quiet).

const SHIMMER_S := 60.0
const GUIDE_S := 150.0
const SHIMMER_EVERY_S := 2.6
const GUIDE_EVERY_S := 3.6
const SOUND_EVERY_S := 10.0
const PLUMES_MAX := 4
## Soft coral pink: organic, never neon; it stands apart from every green of the moss.
const COL := Color(0.98, 0.6, 0.72, 0.62)

## Zone key ("b<ball>.<zone>") -> play seconds searched since its last progress.
var stuck := {}
var _done := {}
var _shim_t := 0.0
var _guide_t := 0.0
var _sound_t := 0.0
## The plumes (one pool for all of them).
var plume_fx: HintPlumes
## The bubble strings (two, so one can finish popping while the next leaves him).
var guides: Array[GuideBubbles] = []
var _guide_next := 0
## For tests: bubble strings sent and sounds played.
var guides_sent := 0
var sounds := 0
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
		_done[bk] = done_all
	zone = ("b%d.*" % b.index) if whole else "b%d.%s" % [b.index, id]
	stage = 0
	if quiet or not enabled or targets.is_empty():
		return
	var t: float = stuck.get(zone, 0.0) + dt
	stuck[zone] = t
	stage = 2 if t >= GUIDE_S else (1 if t >= SHIMMER_S else 0)
	if stage == 0:
		return
	targets.sort_custom(func(a: Vector3, c: Vector3) -> bool: return a.distance_squared_to(gill_pos) < c.distance_squared_to(gill_pos))
	_shim_t -= dt
	if _shim_t <= 0.0:
		_shim_t = SHIMMER_EVERY_S
		plumes = mini(PLUMES_MAX, targets.size())
		for k in plumes:
			_plume(b, targets[k])
	_sound_t -= dt
	if stage >= 2:
		_guide_t -= dt
		if _guide_t <= 0.0:
			_guide_t = GUIDE_EVERY_S
			var up := (gill_pos - b.global_position).normalized()
			var from := gill_pos + up * 0.7
			last_guide_dir = (targets[0] - from).normalized()
			_send_guide(b, from, targets[0])


## A string of bubbles from just above Gill toward `toward` (and, not too often, its soft sound).
func _send_guide(b: MossBall, from: Vector3, toward: Vector3) -> void:
	guides_sent += 1
	if _sound_t <= 0.0:
		_sound_t = SOUND_EVERY_S
		sounds += 1
		Sfx.play("hint_bubbles", from, -9.0, 0.06)
	var parent := WaterFX.inst if WaterFX.inst != null else (Game.inst as Node)
	if parent == null or not parent.is_inside_tree():
		return
	if guides.size() < 2:
		var gb := GuideBubbles.new()
		gb.name = "GuideBubbles%d" % guides.size()
		parent.add_child(gb)
		guides.append(gb)
	var g: GuideBubbles = guides[_guide_next]
	_guide_next = (_guide_next + 1) % guides.size()
	g.launch(b.global_position, from, toward)


## A tall, wispy plume rising from a target (owner, 2026-10-06; HintPlumes): taller than the ball's
## curve hides near him, so it shows over a crest; soft pink against the moss. Each lasts about as
## long as the old green puffs did (it is longer in space, not in time).
func _plume(b: MossBall, pos: Vector3) -> void:
	var parent := WaterFX.inst if WaterFX.inst != null else (Game.inst as Node)
	if parent == null or not parent.is_inside_tree():
		return
	if plume_fx == null or not is_instance_valid(plume_fx):
		plume_fx = HintPlumes.new()
		plume_fx.name = "HintPlumes"
		parent.add_child(plume_fx)
	var up := (pos - b.global_position).normalized()
	plume_fx.emit(pos - up * 0.2, up)
	if WaterFX.inst != null:
		WaterFX.inst.sparkle(pos + up * 0.4, COL, 6, 0.5, 0.09, 1.3)
