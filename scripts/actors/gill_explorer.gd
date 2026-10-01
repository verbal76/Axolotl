class_name GillExplorer
extends RefCounted
## Gill exploring the aquarium in the room, Inspection and Live Tank (release 00039-aquarium-gill,
## docs/research/2026-09-30-DEVICE_AUDIT.md §B and owner rulings E-G). A cosmetic brain for the
## stand-in model (Presentation); nothing in the run looks at it.
##
## He swims in a water shell over his moss ball (0.4-3.5 m above the ground) round where he was left:
## a soft home range of about 10 m (destinations fall off past 8 m, none beyond 12 m; steering may
## pass the edge). Every few seconds, or when he gets there, he picks somewhere new from twelve
## candidates scored for distance, novelty (a decaying memory of the 1.5 m cells he has been in),
## interest (leaf tops, mound tops, plant edges) and a route he can actually swim. Now and then the
## scorer picks a safe flat spot and he settles on it for a few seconds (the body laid on it).
##
## Steering is anticipatory context steering: sphere casts the size of his body (r 0.30) look ahead
## along 16 headings at three pitches (a few casts a frame, round-robin, the heading he is on always),
## so he curves before he reaches things, slows near them, turns no faster than an animal
## (1.6 rad/s, 0.6 m radius) and passes close without entering. The expression (drift, weave, speed
## swells, rise and fall, hover-and-look) is OrganicMotion's GILL_EXPLORE profile: the signal library
## only, no enemy behaviour. The body follow-through is the model's own (time based).
##
## Safety: a kinematic sphere (r 0.30, at spine height) carries him, sliding along anything the
## steering missed (a "late avoidance", counted; the target is none). The hips and the tail are felt
## every third frame and widen the turn if they touch. If he stops making progress (0.3 m in 2.5 s):
## L1 slow down and scan twice as much; L2 stop, back off 0.5 m and turn to the most open of 26
## directions; L3 a new destination in the open direction; L4 (last resort) back to the last free
## breadcrumb, but only when the view cuts, so it is never seen.
##
## Everything is deterministic: its own seeded generator and OrganicMotion's hashed rhythms.

const MASK := 1 | 2 | 8 | Aquarium.TANK_LAYER_BIT
## Real body dimensions (model space; -z is forward): head, tail tip, half-width, spine height.
const HEAD_Z := -0.27
const TAIL_Z := 1.03
const HALF_W := 0.225
const SPINE_Y := AxolotlModel.BODY_Y
## The safety sphere and the steering casts; a destination needs this much clear water round it.
const SAFE_R := 0.30
const DEST_CLEAR := 0.35
## The steering casts are the safety sphere's size (their margin is in how danger is read).
const STEER_R := SAFE_R
const HIPS_R := 0.10
const TAIL_R := 0.05
## The water shell (m above the ground under him).
const ALT_MIN := 0.4
const ALT_MAX := 3.5
## Home range (owner ruling E).
const RANGE := 10.0
const RANGE_SOFT := 8.0
const RANGE_MAX := 12.0
const CELL := 1.5
## Swimming: cruise speed (m/s), turn rate, turn radius, pitch limit.
const CRUISE := 1.05
const TURN_MAX := 1.6
const MIN_RADIUS := 0.6
const PITCH_MAX := 0.436
const N_AZ := 16
const ELS := [-0.436, 0.0, 0.436]
const CASTS := 4
## Stuck: progress window and distance.
const WINDOW := 2.5
const PROGRESS := 0.3
## Resting (owner ruling F): at most this share of the time.
const REST_SHARE := 0.17
## Where the audit measured his body (model z, half-width, half-height).
const ARRIVE := 0.5

enum { SWIM, SETTLE, REST, TAKEOFF }

var ball: MossBall
var home := Vector3.ZERO
var seed_v := 0
## The top of his water shell: ALT_MAX, or higher if he was left up on something tall.
var alt_max := ALT_MAX
## The spine point (the safety sphere's centre), his heading along the ground and his pitch.
var p := Vector3.ZERO
var face := Vector3.FORWARD
var pitch := 0.0
var speed := 0.0
var yaw_v := 0.0
var state := SWIM
## Where the model goes and how it moves (read by Presentation after step()).
var model_xf := Transform3D()
var swim_effort := 0.0
var grounded := false
var conform := false
var idle_ok := false
var model: AxolotlModel

# Destination and route.
var goal := Vector3.INF
var route: Array[Vector3] = []
var goal_rest := false
var arrived := true
var next_pick := 0.0
var _goal_t := 0.0
var _goal_timeout := 20.0
var _open_dir := Vector3.ZERO
# Resting.
var rest_spot := Vector3.ZERO
var rest_n := Vector3.UP
var rest_face := Vector3.FORWARD
var _rest_left := 0.0
var _trans := 0.0
var _hover_xf := Transform3D()
var _rest_xf := Transform3D()
var _last_rest_end := 0.0
var _rest_gap := 40.0
var _last_rest_cell := Vector3i(1 << 30, 0, 0)
# Clock, randomness, expression.
var t := 0.0
var rng := RandomNumberGenerator.new()
var om: OrganicMotion
# Steering memory: per slot (az * 3 + el) the free distance found, the look-ahead it was cast
# with, and when.
var _free := PackedFloat32Array()
var _cast_len := PackedFloat32Array()
var _cast_t := PackedFloat32Array()
var _rr := 0
var _best := -1
var _free_ahead := 9.0
var _north := Vector3.FORWARD
var _east := Vector3.RIGHT
var _up := Vector3.UP
var _ref := Vector3.FORWARD
# Body feel.
var _frame := 0
var _widen := 0.0
var _push := Vector3.ZERO
# Stuck recovery.
var stuck_level := 0
var _stuck_since := -1.0
var _stuck_at := Vector3.ZERO
var _ep_base := 0.0
## Just set down in the water: straight out, slowly, no turning yet (s left).
var _calm_t := 0.0
var _trail: Array = []
var _backing := 0.0
## After L2: the open way he is turning to (and for how long more), and where L3 looks.
var _recover_dir := Vector3.ZERO
var _recover_t := 0.0
var _back_dir := Vector3.ZERO
var _good_since := 0.0
var l4_pending := false
var _crumbs: Array[Vector3] = []
var _crumb_t := 0.0
# Novelty memory: cell -> Vector2(strength, time).
var visits := {}
var _visit_t := 0.0
# Physics.
var _space: PhysicsDirectSpaceState3D
var body: CharacterBody3D
var _sph := SphereShape3D.new()
var _q := PhysicsShapeQueryParameters3D.new()
var _ray := PhysicsRayQueryParameters3D.new()
## Counters (tests, diagnostics).
var stats := {}


## `parent`: where the safety sphere lives (in the world). `start_face`: where he was facing.
func setup(parent: Node3D, p_ball: MossBall, p_home: Vector3, start_face: Vector3, p_seed: int) -> void:
	ball = p_ball
	home = p_home
	seed_v = p_seed
	rng.seed = p_seed
	om = OrganicMotion.new(p_seed, OrganicMotion.GILL_EXPLORE)
	_q.shape = _sph
	_q.collision_mask = MASK
	_ray.collision_mask = MASK
	_free.resize(N_AZ * 3)
	_cast_len.resize(N_AZ * 3)
	_cast_t.resize(N_AZ * 3)
	_cast_t.fill(-99.0)
	stats = {"goals": 0, "reached": 0, "abandoned": 0, "hits": 0, "hip_touch": 0, "stuck_s": 0.0, "stuck_ep_max": 0.0,
			"stuck_eps": 0, "l1": 0, "l2": 0, "l3": 0, "l4": 0, "rest_s": 0.0, "rests": 0, "casts": 0, "overlaps": 0,
			"rest_goals": 0, "two_leg": 0, "no_target": 0}
	body = CharacterBody3D.new()
	body.name = "GillExplorerSafety"
	body.collision_layer = 0
	body.collision_mask = MASK
	body.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	body.safe_margin = 0.001
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = SAFE_R
	cs.shape = s
	body.add_child(cs)
	parent.add_child(body)
	_space = body.get_world_3d().direct_space_state
	var up := ball.up_at(home)
	_ref = MossBall.frame_at(up, 0.0).z * -1.0
	face = (start_face - up * start_face.dot(up))
	face = face.normalized() if face.length() > 0.05 else _ref
	_rest_gap = 30.0 + 40.0 * OrganicMotion.unit(seed_v, 90)
	alt_max = maxf(ALT_MAX, ball.altitude(home) + 2.5)
	_start()


func free_body() -> void:
	if is_instance_valid(body):
		body.queue_free()
	body = null


## Where he starts: settled where Gill was left, if his body fits there; otherwise just above.
func _start() -> void:
	var up := ball.up_at(home)
	if _rest_pose_ok(home, up, face):
		_begin_rest(home, up, face, 2.0 + 3.0 * OrganicMotion.unit(seed_v, 91))
		_trans = 1.0
		state = REST
		p = _hover_xf.origin + _hover_xf.basis.y * SPINE_Y
		model_xf = _rest_xf
		body.global_position = p
		return
	# Straight up from where he was, turning round if need be, until his whole body fits.
	var start := home + up * 0.3
	var at := home + up * 0.62
	var found := false
	for h in [0.62, 0.9, 1.3, 1.8, 2.5, 3.2]:
		var q: Vector3 = home + up * h
		if not _clear(q, DEST_CLEAR) or _cast_free(start, q, 0.15) < 0.999:
			continue
		# (Of the headings his body fits in, the most open ahead: he swims straight out.)
		var best_free := -1.0
		for k in 8:
			var f := face.rotated(up, k * TAU / 8.0)
			if _body_clear(Transform3D(Basis(f.cross(up).normalized(), up, -f), q - up * SPINE_Y), 1.0, 0.2):
				var fr := _cast_free(q, q + f * 2.0)
				if fr > best_free:
					best_free = fr
					at = q
					face = f
					found = true
		if found:
			break
	p = at
	body.global_position = p
	state = SWIM
	# (He first drifts straight out the open way, before turning anywhere.)
	_calm_t = 1.5
	_update_model_swim()


## Whether the straight body at model transform `xf` is clear of the scenery (sample radii scaled).
## `swing`: extra room toward the tail, where the swimming wave swings it from side to side.
func _body_clear(xf: Transform3D, scale: float, swing := 0.0) -> bool:
	for s in [[-0.18, 0.135], [0.0, 0.16], [0.25, 0.15], [0.5, 0.095], [0.8, 0.045], [0.98, 0.02]]:
		var z: float = s[0]
		if not _clear(xf * Vector3(0, SPINE_Y - 0.03 * maxf(0.0, z - 0.35), z), float(s[1]) * scale + swing * clampf(z / 0.8, 0.0, 1.0)):
			return false
	return true


# --- Physics helpers ------------------------------------------------------------------------

func _clear(at: Vector3, r: float) -> bool:
	_sph.radius = r
	_q.transform = Transform3D(Basis.IDENTITY, at)
	_q.motion = Vector3.ZERO
	stats["overlaps"] += 1
	return _space.intersect_shape(_q, 1).is_empty()


## The fraction of the way from `a` to `b` a sphere of radius `r` gets before touching (1 = clear).
func _cast_free(a: Vector3, b: Vector3, r := SAFE_R) -> float:
	_sph.radius = r
	_q.transform = Transform3D(Basis.IDENTITY, a)
	_q.motion = b - a
	stats["casts"] += 1
	var res := _space.cast_motion(_q)
	_q.motion = Vector3.ZERO
	return res[0]


func _ray_hit(a: Vector3, b: Vector3) -> Dictionary:
	_ray.from = a
	_ray.to = b
	return _space.intersect_ray(_ray)


# --- Frame --------------------------------------------------------------------------------

func _frame_at(at: Vector3) -> void:
	_up = ball.up_at(at)
	_north = (_ref - _up * _ref.dot(_up)).normalized()
	_east = _up.cross(_north)
	face = (face - _up * face.dot(_up))
	face = face.normalized() if face.length() > 0.01 else _north


func _slot_dir(i: int) -> Vector3:
	var az := (i / 3) * TAU / N_AZ
	var el: float = ELS[i % 3]
	var h := _north.rotated(_up, az)
	return h * cos(el) + _up * sin(el)


func _dir3() -> Vector3:
	return face * cos(pitch) + _up * sin(pitch)


func _az_of(v: Vector3) -> float:
	return atan2(v.dot(_east), v.dot(_north))


func _slot_near(v: Vector3) -> int:
	var az := wrapf(_az_of(v), 0.0, TAU)
	var k := int(round(az / (TAU / N_AZ))) % N_AZ
	var el := asin(clampf(v.normalized().dot(_up), -1.0, 1.0))
	var j := 1
	if el > 0.22:
		j = 2
	elif el < -0.22:
		j = 0
	return k * 3 + j


func home_distance(at: Vector3) -> float:
	var up := ball.up_at(home)
	var d := at - home
	return (d - up * d.dot(up)).length()


# --- Step ---------------------------------------------------------------------------------

func step(dt: float) -> void:
	if dt <= 0.0:
		return
	t += dt
	_frame += 1
	_frame_at(p)
	match state:
		SWIM:
			_swim(dt)
		SETTLE:
			_settle(dt)
		REST:
			_rest(dt)
		TAKEOFF:
			_takeoff(dt)
	if state == REST or state == SETTLE:
		stats["rest_s"] += dt if state == REST else 0.0
	# Where he has been (novelty) and where he was last free (breadcrumbs).
	_visit_t -= dt
	if _visit_t <= 0.0:
		_visit_t = 0.5
		var key := _cell(p)
		var v: Vector2 = visits.get(key, Vector2(0.0, t))
		visits[key] = Vector2(v.x * exp(-(t - v.y) / 150.0) + 0.5, t)
	_crumb_t -= dt
	if _crumb_t <= 0.0 and state == SWIM and stuck_level == 0 and _free_ahead > 0.2:
		_crumb_t = 1.0
		_crumbs.append(p)
		if _crumbs.size() > 30:
			_crumbs.pop_front()


static func _cell(at: Vector3) -> Vector3i:
	return Vector3i(floori(at.x / CELL), floori(at.y / CELL), floori(at.z / CELL))


func novelty(at: Vector3) -> float:
	var v: Vector2 = visits.get(_cell(at), Vector2.ZERO)
	var s := v.x * exp(-(t - v.y) / 150.0) if v.x > 0.0 else 0.0
	return 1.0 / (1.0 + s)


# --- Swimming ------------------------------------------------------------------------------

func _swim(dt: float) -> void:
	# Destinations.
	if goal == Vector3.INF or (arrived and t >= next_pick):
		_pick()
	var target := goal
	if not route.is_empty():
		target = route[0]
	var dist := p.distance_to(target)
	if not arrived:
		if dist < (0.35 if goal_rest and route.is_empty() else ARRIVE):
			if not route.is_empty() and route.size() > 1:
				route.pop_front()
			else:
				route.clear()
				arrived = true
				stats["reached"] += 1
				if goal_rest:
					_begin_settle()
					return
				next_pick = maxf(next_pick, t + 0.6 + 2.0 * OrganicMotion.unit(seed_v, 200 + stats["goals"]))
		elif t - _goal_t > _goal_timeout:
			_pick()
			return
	# Expression: full on the way, softer while he lingers; hover-and-look when it pauses him.
	om.step(dt, 0.4 if arrived else 1.0, 1.0, 1.0)
	var desired: Vector3
	var lingering := arrived
	if lingering:
		# Lingering round the place he reached: a slow drift, drawn back if he strays.
		desired = face.rotated(_up, om.yaw * 0.3)
		var back := goal - p
		if back.length() > 1.0:
			desired = desired.lerp(back.normalized(), clampf((back.length() - 1.0) * 0.8, 0.0, 1.0))
	else:
		desired = (target - p).normalized()
		# (The drift and weave bend the way there, less as he gets close.)
		desired = desired.rotated(_up, om.yaw * clampf(dist / 3.0, 0.0, 1.0))
	# The water shell and the home range pull gently.
	var alt := ball.altitude(p)
	var lift := om.lift if not lingering else om.lift * 0.5
	if alt < ALT_MIN + 0.2:
		desired += _up * (ALT_MIN + 0.2 - alt) * 2.5
	elif alt > alt_max - 0.2:
		desired -= _up * (alt - alt_max + 0.2) * 2.5
	elif not lingering:
		desired += _up * lift * 0.12
	var hd := home_distance(p)
	if hd > RANGE:
		desired += (home - p).normalized() * (hd - RANGE) * 0.4
	if _recover_t > 0.0:
		# (Recovering: the open way first.)
		_recover_t -= dt
		desired = _recover_dir
	desired = desired.normalized()
	# Look ahead: the casts this frame.
	var look := speed * 0.9 + 0.7
	_scan(look, CASTS * (2 if stuck_level >= 1 else 1))
	# Recovery: backing off.
	if _backing > 0.0:
		_backing -= dt
		speed = 0.0
		var mv := _back_dir * 0.55 * dt
		_move(mv)
		_update_model_swim()
		if _backing <= 0.0:
			_turn_to_open()
		return
	var steer := _choose(desired, look, alt)
	# Turn (rate-limited, eased; wider when the body touches).
	var st_flat := steer - _up * steer.dot(_up)
	var d_az := 0.0
	if st_flat.length() > 0.05:
		d_az = Tier2.signed_angle(face, st_flat.normalized(), _up)
	var max_rate := minf(TURN_MAX, maxf(0.7, speed / MIN_RADIUS)) * om.turn * (0.5 if _widen > 0.0 else 1.0)
	if lingering:
		max_rate = minf(max_rate, 0.35)
	if _calm_t > 0.0:
		_calm_t -= dt
		max_rate = 0.0
	yaw_v = move_toward(yaw_v, clampf(d_az * 2.2, -max_rate, max_rate), 4.0 * dt)
	var rise := 0.0
	if speed < 0.6 and absf(yaw_v) > 0.05:
		# Turning nearly on the spot swings the hips and tail round: only where they fit (else
		# he stops turning and lifts a little, clear of whatever is in the way).
		var nf := face.rotated(_up, yaw_v * dt * 4.0)
		var tail := p - nf * 0.85 - _up * 0.02
		var hips := p - nf * 0.45 - _up * 0.01
		if not _clear(tail, TAIL_R + 0.03) or not _clear(hips, HIPS_R + 0.03):
			yaw_v = 0.0
			rise = 0.25
	face = face.rotated(_up, yaw_v * dt).normalized()
	var want_pitch := clampf(asin(clampf(steer.dot(_up), -1.0, 1.0)), -PITCH_MAX, PITCH_MAX)
	# (Nose up tips the tail down: never so far that the tail would reach the ground.)
	want_pitch = minf(want_pitch, asin(clampf((alt - 0.12) / 1.0, -1.0, 1.0)))
	pitch = move_toward(pitch, want_pitch, 0.8 * dt)
	# Speed: cruise with the organic swell, slower near things, in tight turns, near the goal,
	# while lingering and in recovery.
	var v := CRUISE * om.speed
	v *= clampf((_free_ahead - 0.12) / 1.1, 0.0, 1.0)
	v *= 0.55 + 0.45 * cos(minf(absf(d_az), PI * 0.5))
	if lingering:
		v = minf(v, 0.15)
	else:
		v = minf(v, 0.25 + dist * 0.7)
	if stuck_level == 1:
		v *= 0.4
	if _calm_t > 0.0:
		v = minf(v, 0.3)
	speed = move_toward(speed, maxf(v, 0.0), (1.2 if v > speed else 2.5) * dt)
	_widen = maxf(0.0, _widen - dt)
	var motion := _dir3() * speed * dt + _push * dt + _up * rise * dt
	_push = _push.move_toward(Vector3.ZERO, dt * 0.6)
	_move(motion)
	_feel_body()
	_check_progress(dt, lingering)
	_update_model_swim()


## Casts this frame: the heading he is on, the best slot if its reading is old, then round-robin
## over the slots in front of him.
func _scan(look: float, budget: int) -> void:
	var d := _dir3()
	var f := _cast_free(p, p + d * look, STEER_R)
	_free_ahead = f * look
	budget -= 1
	if _best >= 0 and t - _cast_t[_best] > 0.2:
		_cast_slot(_best, look)
		budget -= 1
	var face_k := wrapi(int(round(_az_of(face) / (TAU / N_AZ))), 0, N_AZ)
	var tries := 0
	while budget > 0 and tries < 60:
		tries += 1
		_rr = (_rr + 1) % (11 * 3)
		var k := wrapi(face_k + (_rr / 3) - 5, 0, N_AZ)
		var i := k * 3 + (_rr % 3)
		if t - _cast_t[i] < 0.05:
			continue
		_cast_slot(i, look)
		budget -= 1


func _cast_slot(i: int, look: float) -> void:
	var f := _cast_free(p, p + _slot_dir(i) * look, STEER_R)
	_free[i] = f * look
	_cast_len[i] = look
	_cast_t[i] = t


## Danger of slot `i` for the look-ahead `look` (0 clear .. 1 blocked at once).
func _danger(i: int, look: float, alt: float) -> float:
	var dg := 0.35
	if t - _cast_t[i] < 1.2:
		var free := _free[i]
		if free >= _cast_len[i] - 0.001:
			free = maxf(free, look)
		dg = 1.0 - clampf((free - 0.05) / look, 0.0, 1.0)
	# The shell: diving below it or rising above it.
	var dv := _slot_dir(i).dot(_up) * look
	var a2 := alt + dv
	if a2 < ALT_MIN:
		dg = maxf(dg, clampf((ALT_MIN - a2) / 0.5, 0.0, 1.0))
	elif a2 > alt_max:
		dg = maxf(dg, clampf((a2 - alt_max) / 0.5, 0.0, 1.0))
	return dg


## The direction to steer: straight where he wants to go when that is clear, otherwise the most
## interesting safe slot (smoothed with its neighbours).
func _choose(desired: Vector3, look: float, alt: float) -> Vector3:
	var near := _slot_near(desired)
	var k := near / 3
	var j := near % 3
	var dn := maxf(_danger(near, look, alt), maxf(_danger(wrapi(k - 1, 0, N_AZ) * 3 + j, look, alt), _danger(wrapi(k + 1, 0, N_AZ) * 3 + j, look, alt)))
	var cur := _dir3()
	var best := -1
	var best_s := -1.0
	var scores := PackedFloat32Array()
	scores.resize(N_AZ * 3)
	for i in N_AZ * 3:
		var dir := _slot_dir(i)
		var ia := (1.0 + dir.dot(desired)) * 0.5
		var interest := ia * ia + 0.12 * maxf(0.0, dir.dot(cur))
		var dg := _danger(i, look, alt)
		var s := interest * (1.0 - dg) * (1.0 - dg)
		scores[i] = s
		if s > best_s:
			best_s = s
			best = i
	_best = best
	if dn < 0.12 and _free_ahead > 0.25:
		return desired
	# (Blend the best with its neighbours round the circle by their scores, so the heading moves
	# smoothly instead of in 22.5 degree steps.)
	var bk := best / 3
	var bj := best % 3
	var out := Vector3.ZERO
	for o in [-1, 0, 1]:
		var i: int = wrapi(bk + o, 0, N_AZ) * 3 + bj
		out += _slot_dir(i) * maxf(0.0, scores[i])
	if out.length() < 0.001:
		return _slot_dir(best)
	# Not straight at a wall he is right against: bias toward the desired way only if it is open.
	_open_dir = out.normalized()
	return _open_dir


## Moves the safety sphere by `motion`, sliding along anything it meets (counted).
func _move(motion: Vector3) -> void:
	body.global_position = p
	var m := motion
	var hit := false
	for k in 3:
		if m.length() < 0.00001:
			break
		var col := body.move_and_collide(m)
		if col == null:
			break
		# (Only running into something counts as a late avoidance, not sliding along it.)
		if m.normalized().dot(-col.get_normal()) > 0.25:
			hit = true
		m = col.get_remainder().slide(col.get_normal())
	if hit:
		stats["hits"] += 1
		# (Mark the heading blocked: the steering turns away next frame.)
		_free_ahead = 0.0
		var i := _slot_near(_dir3())
		_free[i] = 0.0
		_cast_t[i] = t
		_cast_len[i] = 1.0
	p = body.global_position


## Hips and tail, every third frame: a touch widens the turn and eases him away from it.
func _feel_body() -> void:
	if model == null or _frame % 3 != 0:
		return
	var sk := model.skeleton
	if sk == null or not sk.is_inside_tree():
		return
	for pair in [[7, HIPS_R], [10, TAIL_R]]:
		var at := sk.global_transform * sk.get_bone_global_pose(pair[0]).origin
		_sph.radius = pair[1]
		_q.transform = Transform3D(Basis.IDENTITY, at)
		stats["overlaps"] += 1
		var info := _space.get_rest_info(_q)
		if not info.is_empty():
			stats["hip_touch"] += 1
			_widen = 0.6
			var n: Vector3 = info.get("normal", Vector3.ZERO)
			if n.length() > 0.1:
				_push = n.normalized() * 0.25


# --- Stuck recovery ------------------------------------------------------------------------

func _check_progress(dt: float, lingering: bool) -> void:
	_trail.append([t, p])
	while _trail.size() > 2 and (_trail[1][0] as float) <= t - WINDOW:
		_trail.pop_front()
	var old: Array = _trail[0]
	var span := t - float(old[0])
	var moved := p.distance_to(old[1])
	# (Hovering to look round and lingering are not being stuck.)
	var trying := not lingering and (om.hes < 0.3 or _stuck_since >= 0.0)
	# (An episode lasts until he has got 0.3 m from where it began.)
	var still := moved < PROGRESS if _stuck_since < 0.0 else p.distance_to(_stuck_at) < PROGRESS
	if span >= WINDOW - 0.05 and still and trying:
		if _stuck_since < 0.0:
			# A new episode: L1 first, or straight to L2 if he was stuck here only a moment ago.
			_stuck_since = t
			_stuck_at = p
			stats["stuck_eps"] += 1
			_ep_base = 0.0 if stuck_level == 0 else 0.8
			stuck_level = 1
			stats["l1"] += 1
		var ep := t - _stuck_since + _ep_base
		stats["stuck_s"] += dt
		stats["stuck_ep_max"] = maxf(stats["stuck_ep_max"], t - _stuck_since)
		if stuck_level == 1 and ep > 0.8:
			stuck_level = 2
			stats["l2"] += 1
			_back_off()
		elif stuck_level == 2 and ep > 2.2:
			stuck_level = 3
			stats["l3"] += 1
			_pick(true)
		elif stuck_level == 3 and ep > 3.5:
			l4_pending = true
		_good_since = t
	else:
		if _stuck_since >= 0.0:
			# (Out of it: the next episode needs a whole fresh window without progress.)
			_trail.clear()
			_trail.append([t, p])
		_stuck_since = -1.0
		if stuck_level > 0 and t - _good_since > 4.0:
			stuck_level = 0
			l4_pending = false


## L2: stop, and back off up to half a metre, or rise, whichever is clearer for the spine, the
## hips and the tail (moving without turning never swings the tail into anything).
func _back_off() -> void:
	var d := _dir3()
	var back := -d
	var fb := _cast_free(p, p + back * 0.5)
	fb = minf(fb, _cast_free(p + back * 0.45, p + back * 0.95, HIPS_R + 0.03))
	fb = minf(fb, _cast_free(p + back * 0.85, p + back * 1.35, TAIL_R + 0.03))
	var fu := _cast_free(p, p + _up * 0.5)
	fu = minf(fu, _cast_free(p - d * 0.45, p - d * 0.45 + _up * 0.5, HIPS_R + 0.03))
	fu = minf(fu, _cast_free(p - d * 0.85, p - d * 0.85 + _up * 0.5, TAIL_R + 0.03))
	if ball.altitude(p) + 0.5 > alt_max:
		fu = 0.0
	_back_dir = back if fb >= fu else _up
	_backing = (0.5 * maxf(fb, fu)) / 0.55
	speed = 0.0
	yaw_v = 0.0
	if _backing < 0.1:
		_backing = 0.0
		_turn_to_open()


## After backing off: the most open of 26 directions (one full scan) becomes where he turns to
## next, at his usual turning rate.
func _turn_to_open() -> void:
	var best := Vector3.ZERO
	var best_f := -1.0
	for x in [-1, 0, 1]:
		for y in [-1, 0, 1]:
			for z in [-1, 0, 1]:
				if x == 0 and y == 0 and z == 0:
					continue
				var d: Vector3 = (_north * x + _up * y * 0.6 + _east * z).normalized()
				var f := _cast_free(p, p + d * 2.0)
				var alt2 := ball.altitude(p + d * 1.0)
				if alt2 < ALT_MIN or alt2 > alt_max:
					f *= 0.3
				# (Of equally open ways, the one needing the least turn.)
				f += 0.08 * d.dot(_dir3())
				if f > best_f:
					best_f = f
					best = d
	_recover_dir = best
	_recover_t = 2.5
	_cast_t.fill(-99.0)


## L4 (only ever under a camera cut or a change of view): back to the last free breadcrumb.
func on_cut() -> void:
	if not l4_pending:
		return
	for i in range(_crumbs.size() - 1, -1, -1):
		var c: Vector3 = _crumbs[i]
		if c.distance_to(p) > 0.8 and _clear(c, DEST_CLEAR):
			p = c
			body.global_position = p
			stats["l4"] += 1
			break
	l4_pending = false
	stuck_level = 0
	_stuck_since = -1.0
	_trail.clear()
	_cast_t.fill(-99.0)
	_pick()
	if model:
		model.reset_follow()


# --- Destinations --------------------------------------------------------------------------

## Twelve candidates, scored; `open_only`: only those in the open direction (stuck, L3).
func _pick(open_only := false) -> void:
	_frame_at(p)
	if not arrived and goal != Vector3.INF:
		stats["abandoned"] += 1
	stats["goals"] += 1
	var best_s := 0.0
	var best: Array = []
	var tired := clampf((t - _last_rest_end - _rest_gap) / 25.0, 0.0, 1.0)
	var rest_ok: bool = t > 8.0 and stats["rest_s"] < REST_SHARE * t and tired > 0.0
	for k in 12:
		var az := rng.randf() * TAU
		var dist := rng.randf_range(2.0, 9.5) if k % 4 != 3 else rng.randf_range(1.5, 4.0)
		var h := _north.rotated(_up, az)
		var od := _recover_dir if _recover_dir != Vector3.ZERO else _open_dir
		var odf := od - _up * od.dot(_up)
		if open_only and odf.length() > 0.1 and h.dot(odf.normalized()) < 0.2:
			h = odf.normalized().rotated(_up, rng.randf_range(-0.6, 0.6))
		var axis := _up.cross(h).normalized()
		var r := (p - ball.global_position).length()
		var cdir := _up.rotated(axis, dist / maxf(r, 1.0))
		var surface_kind := k % 2 == 1
		var q := Vector3.INF
		var interest := 0.2
		var can_rest := false
		var spot := Vector3.ZERO
		var n := Vector3.UP
		var alt_rng := rng.randf_range(0.7, 2.6)
		if surface_kind:
			# Onto the top of whatever is there (a leaf, a mound, the ground), to hover over it.
			var hit := _ray_hit(ball.surface_point(cdir, 7.0), ball.surface_point(cdir, -0.3))
			if hit.is_empty():
				continue
			n = hit["normal"]
			var cu := ball.up_at(hit["position"])
			if n.dot(cu) < 0.5:
				continue
			spot = hit["position"]
			q = spot + n * 0.62 + cu * 0.15
			var terrain: bool = hit.get("collider") == ball.static_body
			interest = 0.35 if terrain else 0.75
			can_rest = n.dot(cu) > 0.88
		else:
			q = ball.surface_point(cdir, alt_rng)
		if q == Vector3.INF:
			continue
		var hd := home_distance(q)
		if hd > RANGE_MAX:
			continue
		var qa := ball.altitude(q)
		if qa < ALT_MIN - 0.05 or qa > alt_max:
			continue
		if not _clear(q, DEST_CLEAR):
			continue
		# A route he can swim: straight, or two legs by a point above or beside the way.
		var legs: Array[Vector3] = []
		var route_f := 1.0
		if _cast_free(p, q) >= 0.999:
			legs = [q]
		else:
			var mid := (p + q) * 0.5
			var mu := ball.up_at(mid)
			for off in [mu * 1.6, (q - p).cross(mu).normalized() * 2.5, -(q - p).cross(mu).normalized() * 2.5]:
				var m: Vector3 = mid + off
				var ma := ball.altitude(m)
				if ma < ALT_MIN or ma > alt_max + 0.5:
					continue
				if _clear(m, DEST_CLEAR) and _cast_free(p, m) >= 0.999 and _cast_free(m, q) >= 0.999:
					legs = [m, q]
					route_f = 0.7
					break
		if legs.is_empty():
			continue
		var d := p.distance_to(q)
		var pref := smoothstep(1.0, 2.5, d) * (1.0 - 0.8 * smoothstep(8.0, 11.0, d))
		var rangef := 1.0 if hd <= RANGE_SOFT else lerpf(1.0, 0.12, (hd - RANGE_SOFT) / (RANGE_MAX - RANGE_SOFT))
		# (Toward home a little more the further out he is.)
		var homeward := 1.0 + 0.25 * clampf((home_distance(p) - 5.0) / 5.0, 0.0, 1.0) * (home - p).normalized().dot((q - p).normalized())
		var cont := 0.8 + 0.2 * (q - p).normalized().dot(face)
		var s := pref * rangef * (0.15 + novelty(q)) * (0.6 + interest) * route_f * cont * homeward * (0.85 + 0.3 * rng.randf())
		var rest := false
		if can_rest and rest_ok and _cell(spot) != _last_rest_cell:
			var rf := (q - p)
			rf -= n * rf.dot(n)
			if rf.length() > 0.05 and _rest_pose_ok(spot, n, rf.normalized()):
				# (The scorer, not a timer, chooses it: more and more attractive as he tires.)
				var sr := s * (1.0 + 3.0 * tired)
				if sr > s:
					s = sr
					rest = true
		if s > best_s:
			best_s = s
			best = [q, legs, rest, spot, n, route_f]
	_goal_t = t
	next_pick = t + 6.0 + 8.0 * OrganicMotion.unit(seed_v, 300 + stats["goals"])
	if best.is_empty():
		# Nowhere to go from here this time: linger and try again shortly.
		goal = p
		route.clear()
		arrived = true
		goal_rest = false
		next_pick = t + 1.5
		stats["goals"] -= 1
		stats["no_target"] += 1
		return
	goal = best[0]
	route = best[1]
	goal_rest = best[2]
	if best[5] < 1.0:
		stats["two_leg"] += 1
	if goal_rest:
		stats["rest_goals"] += 1
		rest_spot = best[3]
		rest_n = best[4]
	arrived = false
	var length := 0.0
	var prev := p
	for w in route:
		length += prev.distance_to(w)
		prev = w
	_goal_timeout = length / (CRUISE * 0.5) + 6.0


# --- Resting (owner ruling F) --------------------------------------------------------------

## Whether his body fits lying on the ground at `spot` (normal `n`, facing `f`): the ground under
## head, middle, hips and tail within a few centimetres of flat, nothing through the body, and room
## above to settle down into it.
func _rest_pose_ok(spot: Vector3, n: Vector3, f: Vector3) -> bool:
	var ff := (f - n * f.dot(n))
	if ff.length() < 0.05:
		return false
	ff = ff.normalized()
	var xf := Transform3D(Basis(ff.cross(n).normalized(), n, -ff), spot)
	for z in [-0.3, -0.05, 0.2, 0.45, 0.7, 0.95]:
		var hit := _ray_hit(xf * Vector3(0, 0.45, z), xf * Vector3(0, -0.35, z))
		if hit.is_empty():
			return false
		var h: float = (xf.affine_inverse() * (hit["position"] as Vector3)).y
		if absf(h) > 0.02:
			return false
	# (His idles move him a little while he rests (a scoot to each side, a stretch forward): the
	# ground round the front of him is felt too, and must be as flat and as clear.)
	for o in [Vector3(-0.2, 0, -0.3), Vector3(0.2, 0, -0.3), Vector3(-0.2, 0, 0.2), Vector3(0.2, 0, 0.2), Vector3(0, 0, -0.45)]:
		var hit := _ray_hit(xf * (o + Vector3(0, 0.45, 0)), xf * (o + Vector3(0, -0.35, 0)))
		if hit.is_empty():
			return false
		var h: float = (xf.affine_inverse() * (hit["position"] as Vector3)).y
		if absf(h) > 0.03:
			return false
	for s in [[-0.18, 0.135], [0.0, 0.16], [0.25, 0.15], [0.5, 0.095], [0.8, 0.045]]:
		var z: float = s[0]
		var at := xf * Vector3(0, SPINE_Y - 0.03 * maxf(0.0, z - 0.35), z)
		if not _clear(at, float(s[1]) * 0.9):
			return false
		if z < 0.3 and not _clear(at + n * 0.13, float(s[1]) + 0.1):
			return false
		if not _clear(at + n * 0.35, float(s[1])):
			return false
	return _clear(spot + n * (0.62 + SPINE_Y), SAFE_R)


func _begin_rest(spot: Vector3, n: Vector3, f: Vector3, secs: float) -> void:
	var ff := (f - n * f.dot(n)).normalized()
	rest_spot = spot
	rest_n = n
	rest_face = ff
	_rest_xf = Transform3D(Basis(ff.cross(n).normalized(), n, -ff), spot)
	_hover_xf = Transform3D(_rest_xf.basis, spot + n * 0.62)
	_rest_left = secs
	_last_rest_cell = _cell(spot)
	stats["rests"] += 1


func _begin_settle() -> void:
	var f := face
	if not _rest_pose_ok(rest_spot, rest_n, f):
		# (Checked for the way he was coming; if his heading changed, lie the way it was checked.)
		f = (rest_spot - p)
		f -= rest_n * f.dot(rest_n)
		if f.length() < 0.05 or not _rest_pose_ok(rest_spot, rest_n, f.normalized()):
			goal_rest = false
			next_pick = t
			return
	_begin_rest(rest_spot, rest_n, f, 4.0 + 8.0 * OrganicMotion.unit(seed_v, 100 + stats["rests"]))
	_settle_from = model_xf
	_trans = 0.0
	state = SETTLE


var _settle_from := Transform3D()


func _settle(dt: float) -> void:
	_trans = minf(1.0, _trans + dt / 1.8)
	var e := smoothstep(0.0, 1.0, _trans)
	# Down onto the spot: first over it, then lowering into it.
	var mid := _settle_from.interpolate_with(_hover_xf, smoothstep(0.0, 0.55, _trans))
	model_xf = mid.interpolate_with(_rest_xf, smoothstep(0.45, 1.0, _trans))
	swim_effort = lerpf(0.4, 0.0, e)
	grounded = _trans > 0.75
	conform = _trans > 0.85
	idle_ok = false
	speed = 0.0
	p = model_xf.origin + model_xf.basis.y * SPINE_Y
	if _trans >= 1.0:
		state = REST


func _rest(dt: float) -> void:
	_rest_left -= dt
	model_xf = _rest_xf
	swim_effort = 0.0
	grounded = true
	conform = true
	idle_ok = true
	speed = 0.0
	if _rest_left <= 0.0:
		state = TAKEOFF
		_trans = 0.0


func _takeoff(dt: float) -> void:
	_trans = minf(1.0, _trans + dt / 1.2)
	model_xf = _rest_xf.interpolate_with(_hover_xf, smoothstep(0.0, 1.0, _trans))
	swim_effort = lerpf(0.0, 0.45, _trans)
	grounded = _trans < 0.2
	conform = _trans < 0.15
	idle_ok = false
	p = model_xf.origin + model_xf.basis.y * SPINE_Y
	if _trans >= 1.0:
		state = SWIM
		body.global_position = p
		face = rest_face
		pitch = 0.0
		speed = 0.0
		_last_rest_end = t
		_rest_gap = 30.0 + 45.0 * OrganicMotion.unit(seed_v, 400 + stats["rests"])
		_trail.clear()
		goal_rest = false
		arrived = true
		next_pick = t
		_cast_t.fill(-99.0)


# --- Model ---------------------------------------------------------------------------------

func _update_model_swim() -> void:
	var d := _dir3()
	var upm := _up * cos(pitch) - face * sin(pitch)
	model_xf = Transform3D(Basis(d.cross(upm).normalized(), upm, -d), p - upm * SPINE_Y)
	swim_effort = clampf(0.3 + speed / 5.0 * 0.7, 0.3, 2.0)
	grounded = false
	conform = false
	idle_ok = false


## Everything that decides where he goes next, for determinism checks.
func signature() -> String:
	return "%.5f,%.5f,%.5f|%.5f,%.5f,%.5f|%d|%d|%d" % [p.x, p.y, p.z, face.x, face.y, face.z, state, stats["goals"], stats["hits"]]
