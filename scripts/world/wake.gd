class_name Wake
extends Node
## The disturbance that movers make in vegetation (docs/VEGETATION.md): a short list of moving
## points (the axolotl's head, body and tail from his skeleton, a bow point ahead of him while he
## moves, nearby parasites) plus a fading trail of where he has been. Each frame the list is sent
## to the current moss ball's vegetation materials, where the vegetation shader bends every plant
## near a point away from it and along its motion. Nothing here touches gameplay: plants have no
## collision and no gameplay reads the wake.
##
## Frame-rate independent: point velocities are displacement over real delta time, the trail is
## sampled every TRAIL_DT seconds, and strengths are functions of speed and age (never
## accumulated per frame).

const MAX_POINTS := 32
const TRAIL_DT := 0.1
const TRAIL_LEN := 10
const TRAIL_LIFE := 1.0
## Body points while standing still: a gentle lean around him, never a blast.
const REST := 0.3
## Parasites near the axolotl that also disturb vegetation.
const MAX_PARASITES := 3
## Wake points from Expansion 5's creatures (reed stalkers, crabs, scattering shrimp), nearest first.
const MAX_CRITTER_POINTS := 8

## xyz = world position, w = radius of influence.
var points_a := PackedVector4Array()
## xyz = world velocity (m/s), w = strength.
var points_b := PackedVector4Array()
var count := 0
## Sphere around every point (xyz, radius): shaders skip plants outside it with one test.
var bounds := Vector4.ZERO

var _prev := {}          # key -> last world position (for velocities)
var _trail: Array = []   # [pos, vel, strength, age]
var _trail_t := 0.0
var _last_body := Vector3.ZERO
var _has_last := false
var _speed_s := 0.0      # smoothed speed factor 0..1
var _blasts: Array = []  # [pos, radius, life, age] (Bubble Blast)


func _ready() -> void:
	points_a.resize(MAX_POINTS)
	points_b.resize(MAX_POINTS)


func _process(dt: float) -> void:
	var g := Game.inst
	if g == null or g.player == null or g.player.ball == null:
		return
	update(dt)
	g.player.ball.set_veg_param("wake_a", points_a)
	g.player.ball.set_veg_param("wake_b", points_b)
	g.player.ball.set_veg_param("wake_count", count)
	g.player.ball.set_veg_param("wake_bounds", bounds)


## Rebuilds the point list for this frame (dt = real frame time).
func update(dt: float) -> void:
	var g := Game.inst
	var p: Axolotl = g.player
	count = 0
	if dt <= 0.0:
		return
	var up := p.up
	var v := p.velocity - up * p.velocity.dot(up)
	var sp := clampf(v.length() / Axolotl.RUN_SPEED, 0.0, 1.2)
	# Smoothed so starting and stopping ramp over ~0.25 s instead of snapping.
	_speed_s = lerpf(_speed_s, sp, 1.0 - exp(-dt / 0.25))
	var on_ground := p.grounded or p.state != "normal"
	var body_str := (REST + 0.9 * _speed_s) if p.state == "normal" else 0.0
	# Head, body and tail from the skeleton (the tail follows the swipe and the swim).
	var sk := p.model.skeleton
	var bones := [[0, 0.32], [3, 0.4], [6, 0.38], [8, 0.34], [10, 0.32]]
	for k in bones.size():
		var bi: int = bones[k][0]
		var pos: Vector3 = sk.global_transform * sk.get_bone_global_pose(bi).origin
		var key := "gill%d" % bi
		var vel: Vector3 = (pos - _prev[key]) / dt if _prev.has(key) else Vector3.ZERO
		_prev[key] = pos
		var s := body_str
		if bi >= 6:
			# The tail: its own sideways speed (a whip) adds a strong lateral sweep.
			var lateral: Vector3 = vel - v - up * (vel - v).dot(up)
			s += 0.75 * clampf(lateral.length() / 5.0, 0.0, 1.3)
		_add(pos, bones[k][1], vel, s)
	# The bow: plants just ahead start to part before he arrives.
	if _speed_s > 0.05:
		# Just in front of the nose (not beyond the plants it parts, or pushing "away" would
		# fight the forward drag), reaching a little further out.
		_add(p.head_position() + v * 0.04, 0.6, v, 0.8 * _speed_s)
	# The trail: where the body passed, fading so plants behind recover progressively. Samples are
	# taken at exact TRAIL_DT intervals (interpolated between frames), so the trail is the same at
	# any frame rate.
	var body := p.body_center()
	if not _has_last:
		_last_body = body
		_has_last = true
	for t in _trail:
		t[3] += dt
	var t0 := _trail_t
	_trail_t += dt
	while _trail_t >= TRAIL_DT:
		_trail_t -= TRAIL_DT
		# This sample's moment lies (_trail_t) seconds before now.
		var k := clampf((TRAIL_DT - t0) / dt, 0.0, 1.0) if dt > 0.0 else 1.0
		t0 -= TRAIL_DT
		if _speed_s > 0.08 and on_ground:
			_trail.push_front([_last_body.lerp(body, k), v, 0.9 * _speed_s, _trail_t])
	_trail = _trail.filter(func(t): return t[3] < TRAIL_LIFE)
	while _trail.size() > TRAIL_LEN:
		_trail.pop_back()
	_last_body = body
	for t in _trail:
		var age: float = t[3] / TRAIL_LIFE
		# A small rebound as it recovers: the plants overshoot a little, then settle.
		var s: float = t[2] * pow(1.0 - age, 2.0) * (1.0 + 0.35 * sin(age * 9.0))
		_add(t[0], 0.42 + 0.25 * age, t[1] * (1.0 - age), s)
	# Nearby parasites disturb vegetation too: head and tail.
	var near := []
	for par in p.ball.parasites:
		if par.is_alive() and par.visible and par.global_position.distance_to(p.global_position) < 30.0:
			near.append([par.global_position.distance_squared_to(p.global_position), par])
	near.sort_custom(func(a, b): return a[0] < b[0])
	for k in mini(MAX_PARASITES, near.size()):
		var par: Parasite = near[k][1]
		var pts := [par.global_position, par.closest_body_point(par.global_position - par.heading * 3.0)]
		for j in 2:
			var key := "par%d_%d" % [par.get_instance_id(), j]
			var vel: Vector3 = (pts[j] - _prev[key]) / dt if _prev.has(key) else Vector3.ZERO
			_prev[key] = pts[j]
			var r := par.seg_radius * 2.5 + 0.2
			_add(pts[j], r, vel, 0.25 + 0.6 * clampf(vel.length() / 2.5, 0.0, 1.2))
	# Creatures moving through the plants (Ecosystem): the reeds part where they really are.
	if g.ecosystem:
		for w in g.ecosystem.wake_points(p.global_position, MAX_CRITTER_POINTS):
			_add(w[0], w[1], w[2], w[3])
	# A Bubble Blast: the plants round it thrown radially outward, settling over its life with a
	# small rebound (a wide point at the centre pushes everything away; a ring of points runs out
	# with the shockwave front).
	for bl in _blasts:
		bl[3] += dt
	_blasts = _blasts.filter(func(bl): return bl[3] < bl[2])
	for bl in _blasts:
		var c0: Vector3 = bl[0]
		var br: float = bl[1]
		var k: float = bl[3] / bl[2]
		var s0 := 2.4 * pow(1.0 - k, 1.6) * (1.0 + 0.3 * sin(k * 14.0))
		_add(c0, br / 2.2, Vector3.ZERO, s0)
		var front := minf(1.0, bl[3] / 0.35)
		if front < 1.0:
			var fr := MossBall.frame_at(p.ball.up_at(c0), 0.0)
			for i in 6:
				var a := TAU * i / 6.0
				var d := fr.x * cos(a) + fr.z * sin(a)
				_add(c0 + d * br * front, 0.9, d * br / 0.35, 1.6 * (1.0 - front))
	# Bounds for the shader's quick reject.
	var c := Vector3.ZERO
	for i in count:
		c += Vector3(points_a[i].x, points_a[i].y, points_a[i].z)
	if count > 0:
		c /= count
	var rad := 0.0
	for i in count:
		rad = maxf(rad, Vector3(points_a[i].x, points_a[i].y, points_a[i].z).distance_to(c) + points_a[i].w * 2.5)
	bounds = Vector4(c.x, c.y, c.z, rad)


## A Bubble Blast at `pos`: plants within `radius` are blown outward and settle over `life` s.
## Cosmetic only (nothing in gameplay reads the wake).
func add_blast(pos: Vector3, radius: float, life := 2.6) -> void:
	_blasts.append([pos, radius, life, 0.0])


func _add(pos: Vector3, radius: float, vel: Vector3, strength: float) -> void:
	if count >= MAX_POINTS or strength <= 0.005:
		return
	points_a[count] = Vector4(pos.x, pos.y, pos.z, radius)
	points_b[count] = Vector4(vel.x, vel.y, vel.z, strength)
	count += 1


## CPU mirror of the vegetation shader's wake bend (shaders/vegetation.gdshader, wake_bend) for a
## plant whose base is at `base` (world) and whose height is `plant_h` on `ball`. Used by tests and
## by anything that needs to know how disturbed the plants are at a spot.
func bend_at(ball: MossBall, base: Vector3, plant_h: float) -> Vector3:
	var up := ball.up_at(base)
	var sum := Vector3.ZERO
	var wsum := 0.0
	var strongest := 0.0
	for i in count:
		var pa := points_a[i]
		var pb := points_b[i]
		var pos := Vector3(pa.x, pa.y, pa.z)
		var r := pa.w
		var d := base - pos
		var above := -d.dot(up)
		d -= up * d.dot(up)
		var dist := d.length()
		if dist > r * 2.5:
			continue
		# Movers above the plant's top (jumping over it) do not touch it.
		var fall := pb.w * (1.0 - smoothstep(r * 0.5, r * 2.5, dist)) * (1.0 - smoothstep(plant_h * 0.85, plant_h + r, above))
		if fall <= 0.0:
			continue
		var away := d / maxf(dist, 0.05)
		var vel := Vector3(pb.x, pb.y, pb.z)
		vel -= up * vel.dot(up)
		# Direction: the points' pushes averaged by strength; size: the strongest point (so the
		# many overlapping points of one body do not add up to a blast).
		var push := away + vel * 0.12
		sum += push * fall
		wsum += fall
		strongest = maxf(strongest, fall * push.length())
	if wsum <= 0.0:
		return Vector3.ZERO
	var b := sum / wsum
	var m := b.length()
	if m < 0.0001:
		return Vector3.ZERO
	return b / m * minf(strongest, 1.6)
