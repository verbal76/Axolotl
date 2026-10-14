class_name Tier2Combat
extends Node
## Executes the equipped Tier-2 ability (docs/TIER2.md). No manual aiming: the player chooses when
## and roughly where (the way Gill faces); Gill handles the precision. Each ability is a short
## authored moment inside his normal movement (he keeps his collision; the camera is never
## snapped) and then control returns.
##
## - Water Cannon: the valid hostile closest to his facing (shortest signed angle, so +10 and -10
##   degrees are equally close and 350 degrees is -10), in range, in the cone, in sight. He turns
##   to it quickly but smoothly, braces, and fires a jet: 2 stages and a knock back.
## - Bubble Blast: a shockwave round his body centre filling the upper hemisphere (above the
##   ground plane through him, plus a little below): each valid hostile inside and in sight is hit
##   once. Plants are blown radially outward and settle over about 2.5 s (Wake.add_blast).
## - Gill Rush: up to three different valid hostiles, the first the one best ahead of him, each next
##   the nearest reachable one from the last impact without doubling back. He really travels
##   between them (a nose lunge each: BAM, redirect, BAM, redirect, BAM); a leg whose path is
##   blocked, leaves the ground over a ravine or runs too long ends the chain safely.
##
## Valid hostiles are Game._strikeable: live parasites, active hittable creatures (crabs, eels,
## stalkers, pufferfish) and practice targets. Ambient fish, shrimp, snails, food and Motes are never
## in it. Selection is deterministic (ties broken by distance, then by instance id).

const CANNON_RANGE := 10.0
const CANNON_CONE := deg_to_rad(70.0)
const CANNON_STAGES := 2
const CANNON_TURN := 0.16
const CANNON_FIRE := 0.24
const CANNON_SPEED := 30.0

const BUBBLE_R := 4.2
## How far below the ground plane through his body centre the blast still reaches.
const BUBBLE_BELOW := 0.4
const BUBBLE_STAGES := 1
const BUBBLE_BRACE := 0.14

const RUSH_ACQUIRE := 7.0
const RUSH_FIRST_CONE := deg_to_rad(80.0)
const RUSH_LEG_MAX := 7.5
const RUSH_MAX := 3
const RUSH_SPEED := 13.0
const RUSH_SIGHT := 0.07
const RUSH_LEG_TIME := 0.75
const RUSH_STAGES := 1
## Later targets: never one almost straight back the way he came (turning is also penalised in the
## choice, so he doubles back only when nothing else is left).
const RUSH_MAX_TURN := deg_to_rad(165.0)

## Terrain only (what nothing sees or strikes through).
const SOLID_MASK := 1

var active := ""
var _t := 0.0
var _target: Node3D = null
var _plan: Array = []
var _leg := 0
var _leg_t := 0.0
var _hit_ids := {}
var _p: Axolotl
## Diagnostics for tests: what the last activation did.
var last := {}


# --- Pure selection (tested directly) --------------------------------------------------------

## Unsigned angle between his facing and the direction to `to`, measured round `up` (0..PI).
static func facing_offset(facing: Vector3, up: Vector3, from: Vector3, to: Vector3) -> float:
	return absf(Tier2.signed_angle(facing, to - from, up))


## Water Cannon's pick from `cands` ([{node, pos, seen}]): smallest facing offset within the cone and
## range; ties by distance, then instance id. Returns the chosen entry or {}.
static func pick_cannon(facing: Vector3, up: Vector3, origin: Vector3, cands: Array) -> Dictionary:
	var best := {}
	var best_key := [INF, INF, INF]
	for c in cands:
		var pos: Vector3 = c["pos"]
		var dist := origin.distance_to(pos)
		if dist > CANNON_RANGE or not c.get("seen", true):
			continue
		var off := facing_offset(facing, up, origin, pos)
		if off > CANNON_CONE:
			continue
		# (Offsets within a hundredth of a degree are a tie: then the nearer one.)
		var key := [snappedf(off, 0.0002), dist, float(c.get("id", 0))]
		if _less(key, best_key):
			best_key = key
			best = c
	return best


## Whether `pos` is inside Bubble Blast's volume round `centre` (upper hemisphere of BUBBLE_R, plus
## BUBBLE_BELOW under the ground plane through the centre).
static func in_bubble(centre: Vector3, up: Vector3, pos: Vector3) -> bool:
	var d := pos - centre
	return d.length() <= BUBBLE_R and d.dot(up) >= -BUBBLE_BELOW


## Gill Rush's chain from `origin` facing `facing`: up to RUSH_MAX distinct entries of `cands`
## ([{node, pos, seen, id}]). `reachable(a, b)` says whether he can rush from a to b.
static func plan_rush(facing: Vector3, up: Vector3, origin: Vector3, cands: Array, reachable: Callable) -> Array:
	var chain := []
	var left := []
	for c in cands:
		if origin.distance_to(c["pos"]) <= RUSH_ACQUIRE and c.get("seen", true):
			left.append(c)
	var at := origin
	var dir := facing
	while chain.size() < RUSH_MAX and not left.is_empty():
		var best := {}
		var best_key := [INF, INF, INF]
		for c in left:
			var pos: Vector3 = c["pos"]
			var dist := at.distance_to(pos)
			if dist > RUSH_LEG_MAX:
				continue
			var off := facing_offset(dir, up, at, pos)
			if chain.is_empty():
				if off > RUSH_FIRST_CONE:
					continue
				var key := [snappedf(off + dist * 0.06, 0.0002), dist, float(c.get("id", 0))]
				if _less(key, best_key) and reachable.call(at, pos):
					best_key = key
					best = c
			else:
				if off > RUSH_MAX_TURN:
					continue
				var key2 := [snappedf(dist + off * 0.8, 0.0002), off, float(c.get("id", 0))]
				if _less(key2, best_key) and reachable.call(at, pos):
					best_key = key2
					best = c
		if best.is_empty():
			break
		chain.append(best)
		left.erase(best)
		var flat: Vector3 = (best["pos"] as Vector3) - at
		flat -= up * flat.dot(up)
		if flat.length() > 0.01:
			dir = flat.normalized()
		at = best["pos"]
	return chain


## Lexicographic a < b for equal-length number arrays.
static func _less(a: Array, b: Array) -> bool:
	for i in a.size():
		if a[i] != b[i]:
			return a[i] < b[i]
	return false


# --- World wrappers ------------------------------------------------------------------------

## Valid hostiles near Gill as selection entries.
func candidates(p: Axolotl) -> Array:
	var out := []
	var c0 := p.body_center()
	for par in Game.inst._strikeable(p):
		var pos: Vector3 = par.closest_body_point(c0)
		out.append({"node": par, "pos": pos, "seen": sight(p, c0, pos), "id": par.get_instance_id()})
	return out


## Terrain between a and b? (Leaves, plants and platforms never block.)
func sight(p: Axolotl, a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, SOLID_MASK)
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or (hit["position"] as Vector3).distance_to(b) < 0.35


## Whether he can rush along the ground from a to b: nothing solid in the way (at body height), no
## ravine under the path, and inside the tank.
func rush_reachable(p: Axolotl, a: Vector3, b: Vector3) -> bool:
	var ball := p.ball
	var up := ball.up_at(a)
	if not sight(p, a + up * 0.1, b + ball.up_at(b) * 0.1):
		return false
	for i in 9:
		var q := a.lerp(b, float(i) / 8.0)
		var d := ball.up_at(q)
		if ball.ravine_at(d) != "" and ball.ravine_carve(d) > 0.3:
			return false
	return true


# --- Activation and drive --------------------------------------------------------------------

## The Tier-2 button was pressed: starts the equipped ability if it is ready and he can act.
func try_start(p: Axolotl) -> bool:
	var g := Game.inst
	if active != "" or not g.tier2.is_ready(g.clock.play_s) or p.state != "normal":
		return false
	_p = p
	_t = 0.0
	_hit_ids.clear()
	_target = null
	_plan = []
	_leg = 0
	_leg_t = 0.0
	active = g.tier2.equipped
	g.tier2.start_cooldown(g.clock.play_s)
	last = {"ability": active, "targets": [], "hits": 0, "legs": 0, "ended": ""}
	match active:
		Tier2.CANNON:
			var cands := candidates(p)
			var pick := pick_cannon(p.facing, p.up, p.body_center(), cands)
			_target = pick.get("node", null)
			if _target:
				last["targets"] = [_target]
			WaterFX.inst.gather(p.head_position() + p.facing * 0.3, 0.9)
			Sfx.play("burst", p.global_position, -4.0)
		Tier2.BUBBLE:
			Sfx.play("land_hard", p.global_position, -2.0)
		Tier2.RUSH:
			_plan = plan_rush(p.facing, p.up, p.body_center(), candidates(p), func(a, b): return rush_reachable(p, a, b))
			last["targets"] = _plan.map(func(c): return c["node"])
			if _plan.is_empty():
				last["ended"] = "no target"
	Settings.haptic("tap")
	g._hide_prompt("special", true)
	return true


## One physics frame of the active ability. Returns [horizontal velocity, vertical velocity or NAN
## to leave it to gravity]. Called by Axolotl while `active` is set.
func drive(p: Axolotl, dt: float, vh: Vector3) -> Array:
	_t += dt
	var up := p.up
	match active:
		Tier2.CANNON:
			vh = vh.move_toward(Vector3.ZERO, 30.0 * dt)
			if _target and is_instance_valid(_target) and _target.is_alive():
				var flat: Vector3 = _target.global_position - p.global_position
				flat -= up * flat.dot(up)
				if flat.length() > 0.05:
					p.facing = p._slerp_tangent(p.facing, flat.normalized(), minf(1.0, dt / maxf(0.02, CANNON_TURN - _t + dt)))
			if _t >= CANNON_FIRE and not last.has("fired"):
				last["fired"] = true
				_fire_cannon(p)
			if _t >= CANNON_FIRE + 0.12:
				_end("done")
			return [vh, NAN]
		Tier2.BUBBLE:
			vh = vh.move_toward(Vector3.ZERO, 40.0 * dt)
			if _t >= BUBBLE_BRACE and not last.has("fired"):
				last["fired"] = true
				_blast(p)
			if _t >= BUBBLE_BRACE + 0.2:
				_end("done")
			return [vh, NAN]
		Tier2.RUSH:
			return _drive_rush(p, dt, vh)
	_end("none")
	return [vh, NAN]


func _drive_rush(p: Axolotl, dt: float, vh: Vector3) -> Array:
	var up := p.up
	if _leg >= _plan.size():
		# Recover: a short glide to a stop, then control returns.
		vh = vh.move_toward(Vector3.ZERO, 35.0 * dt)
		if _t >= 0.14:
			_end("done" if last["ended"] == "" else last["ended"])
		return [vh, NAN]
	var c: Dictionary = _plan[_leg]
	var node: Node3D = c["node"]
	if node == null or not is_instance_valid(node) or not node.is_alive() or _hit_ids.has(node.get_instance_id()):
		_next_leg("target gone")
		return [vh * 0.5, NAN]
	var aim: Vector3 = node.closest_body_point(p.body_center())
	var flat := aim - p.body_center()
	var vert := flat.dot(up)
	flat -= up * vert
	_leg_t += dt
	# (Each leg: a brief sight, then the nose lunge. A leg that stops being safe ends the chain.)
	if _leg_t < RUSH_SIGHT:
		if flat.length() > 0.05:
			p.facing = p._slerp_tangent(p.facing, flat.normalized(), minf(1.0, 30.0 * dt))
		return [vh.move_toward(Vector3.ZERO, 40.0 * dt), NAN]
	if _leg_t > RUSH_LEG_TIME or not rush_reachable(p, p.body_center(), aim):
		_plan.resize(_leg)
		last["ended"] = "unsafe leg" if _leg_t <= RUSH_LEG_TIME else "leg too long"
		return [vh * 0.3, NAN]
	if flat.length() > 0.05:
		p.facing = p._slerp_tangent(p.facing, flat.normalized(), minf(1.0, 25.0 * dt))
	vh = p.facing * RUSH_SPEED
	var vup := NAN
	if absf(vert) > 0.15:
		vup = clampf(vert / 0.12, -6.0, 8.0)
	if p.body_center().distance_to(aim) < 0.55 + 0.25:
		_strike(p, node, RUSH_STAGES, 1.4)
		WaterFX.inst.impulse(aim, 1.6, 0.4)
		_next_leg("")
		vh *= 0.35
	return [vh, vup]


func _next_leg(why: String) -> void:
	_leg += 1
	_leg_t = 0.0
	last["legs"] = _leg
	if why != "" and last["ended"] == "":
		last["ended"] = why


func _fire_cannon(p: Axolotl) -> void:
	var from := p.head_position() + p.facing * 0.2
	var to: Vector3 = from + p.facing * CANNON_RANGE
	if _target and is_instance_valid(_target) and _target.is_alive():
		to = _target.closest_body_point(from)
	var time := maxf(0.05, from.distance_to(to) / CANNON_SPEED)
	WaterFX.inst.jet(from, to, time)
	WaterFX.inst.burst_fx(from, -p.facing, p.up)
	p.model.happy_t = 0.0
	Sfx.play("swipe_hit", p.global_position, -2.0)
	if _target and is_instance_valid(_target) and _target.is_alive():
		var tgt := _target
		get_tree().create_timer(time, false).timeout.connect(func():
			if is_instance_valid(tgt) and tgt.is_alive():
				_strike(p, tgt, CANNON_STAGES, 1.8)
				WaterFX.inst.sparkle(tgt.global_position, Color(0.8, 0.95, 1.0, 0.9), 14, 2.2, 0.07, 0.6))


func _blast(p: Axolotl) -> void:
	var centre := p.body_center()
	var up := p.up
	var hits := 0
	for c in candidates(p):
		if in_bubble(centre, up, c["pos"]) and c["seen"]:
			var n: Node3D = c["node"]
			if _strike(p, n, BUBBLE_STAGES, 2.0):
				hits += 1
	WaterFX.inst.landing_ring(p.global_position, up, BUBBLE_R * 0.9)
	WaterFX.inst.blast_shell(centre, up, BUBBLE_R)
	if Game.inst.wake:
		Game.inst.wake.add_blast(p.global_position, BUBBLE_R, 2.6)
	if p.cam and p.cam.has_method("shake"):
		p.cam.shake(0.14)
	Settings.haptic("land")


## Hits `n` once per activation. Returns true if it landed.
func _strike(p: Axolotl, n: Node3D, stages: int, knock: float) -> bool:
	var id := n.get_instance_id()
	if _hit_ids.has(id):
		return false
	_hit_ids[id] = true
	var ok: bool = n.hit(stages, p.global_position) if n is Critter else n.hit(stages, p.global_position, knock)
	if ok:
		last["hits"] = int(last["hits"]) + 1
		Settings.haptic("tap")
	return ok


func _end(why: String) -> void:
	if last.get("ended", "") == "":
		last["ended"] = why
	active = ""
	_target = null
	_plan = []


## Cancels whatever is running (death, cinematics, leaving play).
func cancel() -> void:
	if active != "":
		_end("cancelled")
