class_name ShrimpShoal
extends Critter
## A little shoal of shrimp grazing over open moss (docs/ECOSYSTEM.md): they hover and flick about
## together, drifting round their patch. When the axolotl comes close and quickly (running, jumping
## or swiping) they scatter in all directions with a flurry, then drift back together. Harmless.

const COUNT := 9
const SCATTER_R := 4.5
const CALM_AFTER := 2.5
## Drawn larger than life so a shoal reads at phone scale (about 0.4 m long).
const SIZE := 1.8

var home_dir := Vector3.UP
var home_deg := 6.0
var centre := Vector3.ZERO
var scatter := 0.0
var calm_t := 0.0
var _target := Vector3.ZERO
var _vel := Vector3.ZERO
var _offs: Array[Vector3] = []
var _spread: Array[Vector3] = []
var _phase: Array[float] = []
var _mm: MultiMesh
var _ground_t := 0.0
var _ground_alt := 0.0


func place(p_ball: MossBall, p_home: Vector3, p_deg: float, seed_v: int) -> void:
	setup(p_ball, "shrimp", "open moss", seed_v)
	seen_radius = 6.0
	p_ball.add_child(self)
	home_dir = p_home.normalized()
	home_deg = p_deg
	centre = ball.surface_point(home_dir)
	_ground_alt = ball.altitude(centre)
	for i in COUNT:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.2, 1.0)
		_offs.append(Vector3(cos(a) * r, rng.randf_range(0.25, 0.6), sin(a) * r))
		_spread.append(Vector3.ZERO)
		_phase.append(rng.randf() * TAU)
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.mesh = _shrimp_mesh()
	_mm.instance_count = COUNT
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _mm
	mmi.material_override = _shrimp_mat()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = 45.0
	mmi.top_level = true
	add_child(mmi)
	_pick_target()
	_pose(0.0)


## A shrimp (Expansion 6: it read as a red hook): an arched, banded body with a carapace, a
## rostrum, eyes, long swept-back antennae, little legs underneath and a fanned tail; translucent
## coral with a paler belly (vertex colours). About 0.22 m long, head toward -Z.
static func _shrimp_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 13
	var sides := 8
	var body := Color(0.98, 0.52, 0.42)
	var band := Color(0.86, 0.36, 0.3)
	var belly := Color(1.0, 0.78, 0.66)
	var pts: Array = []
	var centres: Array = []
	for i in rings:
		var t := float(i) / (rings - 1)
		# Head at t = 0; the back arches, the tail curls a little under.
		var z := lerpf(-0.1, 0.11, t)
		var y := sin(t * PI) * 0.028 - pow(t, 3.0) * 0.03
		var c := Vector3(0, y, z)
		centres.append(c)
		var r := 0.03 if t < 0.35 else lerpf(0.029, 0.011, (t - 0.35) / 0.65)
		r *= 1.0 - 0.3 * pow(1.0 - t, 6.0)
		var ring: Array = []
		for k in sides:
			var a := TAU * k / sides
			ring.append(c + Vector3(cos(a) * r * 0.85, sin(a) * r, 0))
		pts.append(ring)
	for i in rings - 1:
		var t := float(i) / (rings - 1)
		var col := band if t > 0.35 and i % 2 == 0 else body
		for k in sides:
			var a: Vector3 = pts[i][k]
			var b: Vector3 = pts[i][(k + 1) % sides]
			var c: Vector3 = pts[i + 1][k]
			var d: Vector3 = pts[i + 1][(k + 1) % sides]
			var under := sin(TAU * (k + 0.5) / sides) < -0.3
			for v in [a, c, b, b, c, d]:
				st.set_color(belly if under else col)
				st.add_vertex(v)
	var head: Vector3 = centres[0]
	# Rostrum (a spike forward), eyes, antennae.
	for v in [head + Vector3(0, 0.02, 0.0), head + Vector3(0, 0.016, -0.06), head + Vector3(0.006, 0.012, 0.0)]:
		st.set_color(band)
		st.add_vertex(v)
	for side in [-1.0, 1.0]:
		var e := head + Vector3(side * 0.022, 0.018, 0.012)
		for tri in [[Vector3(0, 0.008, 0), Vector3(side * 0.008, 0, 0), Vector3(0, 0, -0.008)], [Vector3(0, -0.008, 0), Vector3(0, 0, -0.008), Vector3(side * 0.008, 0, 0)]]:
			for v in tri:
				st.set_color(Color(0.05, 0.03, 0.03))
				st.add_vertex(e + v)
		var root := head + Vector3(side * 0.012, 0.01, -0.02)
		var ant := [root, root + Vector3(side * 0.07, 0.05, 0.02), root + Vector3(side * 0.13, 0.06, 0.16), root + Vector3(side * 0.15, 0.04, 0.28)]
		for q in 3:
			var a0: Vector3 = ant[q]
			var a1: Vector3 = ant[q + 1]
			var w := Vector3(0, 0.0025, 0)
			for v in [a0 - w, a1, a0 + w]:
				st.set_color(body)
				st.add_vertex(v)
		# Little legs under the body.
		for l in 5:
			var lc: Vector3 = centres[3 + l]
			var lr := lc + Vector3(side * 0.012, -0.018, 0)
			for v in [lr, lr + Vector3(side * 0.014, -0.022, 0.006), lr + Vector3(0, 0, 0.008)]:
				st.set_color(belly)
				st.add_vertex(v)
	# Tail fan: five blades spread from the last segment.
	var tail: Vector3 = centres[rings - 1]
	for f in 5:
		var a := lerpf(-0.9, 0.9, float(f) / 4.0)
		var dirv := Vector3(sin(a) * 0.035, -0.005, cos(a) * 0.04)
		var sidev := Vector3(cos(a), 0, -sin(a)) * 0.009
		for v in [tail, tail + dirv - sidev, tail + dirv + sidev]:
			st.set_color(band)
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()


static var _smat: StandardMaterial3D


## Vertex-coloured, soft and a little translucent-looking (back-lit glow), faintly self-lit so the
## shoal reads in murky water.
static func _shrimp_mat() -> StandardMaterial3D:
	if _smat == null:
		_smat = StandardMaterial3D.new()
		_smat.vertex_color_use_as_albedo = true
		_smat.roughness = 0.45
		_smat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_smat.emission_enabled = true
		_smat.emission = Color(0.3, 0.1, 0.07)
		_smat.backlight_enabled = true
		_smat.backlight = Color(0.6, 0.3, 0.25)
	return _smat


func _pick_target() -> void:
	var d := home_dir.rotated(MossBall.frame_at(home_dir, rng.randf() * 360.0).x, deg_to_rad(rng.randf() * home_deg))
	_target = ball.surface_point(d)


func tick(dt: float) -> void:
	var p := player()
	var fast := false
	if player_here():
		var v := p.velocity
		fast = v.length() > 2.0 or not p.grounded
	if player_here() and fast and p.global_position.distance_to(centre) < SCATTER_R:
		if scatter < 0.5:
			Sfx.play("shrimp_scatter", centre)
			for i in COUNT:
				var away := (centre + _offs[i] - p.global_position).normalized()
				_spread[i] = (away + Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(0.0, 0.5), rng.randf_range(-0.5, 0.5))).normalized() * rng.randf_range(2.5, 4.5)
		scatter = 1.0
		calm_t = 0.0
	else:
		calm_t += dt
		if calm_t > CALM_AFTER:
			scatter = move_toward(scatter, 0.0, dt * 0.35)
	# The shoal drifts slowly round its patch.
	var up := ball.up_at(centre)
	var d := _target - centre
	d -= up * d.dot(up)
	if d.length() < 0.5:
		_pick_target()
	_vel = _vel.lerp(d.normalized() * 0.35, clampf(dt, 0.0, 1.0))
	centre = ball.surface_point(ball.up_at(centre + _vel * dt))
	_ground_t -= dt
	if _ground_t <= 0.0:
		_ground_t = 0.4
		var g := ground_under(centre, GROUND_MASK, 1.5, 2.0)
		if g:
			_ground_alt = ball.altitude(g["position"])
	_pose(dt)


func _pose(dt: float) -> void:
	var up := ball.up_at(centre)
	var base := ball.surface_point(up) + up * (_ground_alt - ball.altitude(ball.surface_point(up)))
	var fr := MossBall.frame_at(up, 0.0)
	var heading := (_vel - up * _vel.dot(up)).normalized() if _vel.length() > 0.02 else fr.z
	for i in COUNT:
		_phase[i] += dt * (3.0 + i * 0.3)
		var o: Vector3 = _offs[i]
		var local := fr.x * o.x + up * o.y + fr.z * o.z
		# Flicks: small darting hops.
		local += fr.x * sin(_phase[i]) * 0.08 + up * absf(sin(_phase[i] * 0.5)) * 0.05
		var pos := base + local + _spread[i] * scatter
		var h := heading.rotated(up, sin(_phase[i] * 0.7) * 0.6 + (PI if scatter > 0.5 and _spread[i].dot(heading) < 0.0 else 0.0))
		_mm.set_instance_transform(i, Transform3D(Basis(h.cross(up).normalized(), up, -h).orthonormalized().scaled(Vector3.ONE * SIZE), pos))
	global_position = base


func wake_points() -> Array:
	if scatter < 0.1:
		return []
	return [[centre + ball.up_at(centre) * 0.3, 1.2, _vel, 0.3 * scatter]]


func discover_point() -> Vector3:
	return centre
