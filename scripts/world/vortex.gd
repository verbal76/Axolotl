class_name Vortex
extends Node3D
## Water vortex between two moss balls. Its strength grows continuously with the source ball's
## restoration; the spiral reaches the next ball at ~70%. Once connected it stays open and works in
## both directions.
##
## Expansion 6 (owner: "a spiral of water jets ... a revolving tidal pool spinning hurricane jet of
## water that he's circling through", not a solid tube with a cone jammed in the dirt): a swirling
## tidal pool lies on the moss at each end, sand and bubbles spiral up out of it, and JETS jets of
## water wind as a helix round the path between the balls, flaring out into the pools. The spiral
## revolves (`spin_phase`), and the ride carries Gill round the path beside one of the jets.

const CONNECT_AT := 0.7
## Radius of the helix the jets wind along (and of the old tube, kept for the mouth clearance).
const TUBE_RADIUS := 2.1
const JETS := 5
const JET_R := 0.42
const STREAMS := 3
const POOL_R := 5.2

var ball_a: MossBall
var ball_b: MossBall
var dir_a := Vector3.UP
var dir_b := Vector3.UP
var connected := false
var strength := 0.0          # displayed (smoothed)
var points := PackedVector3Array()
var ups := PackedVector3Array()
var _target := 0.0
var _pulse := 0.0
var _jet_mat: ShaderMaterial
var _stream_mat: ShaderMaterial
var _mouth_a: Node3D
var _mouth_b: Node3D
var _pool_mats: Array[ShaderMaterial] = []
var _debris_mats: Array[ShaderMaterial] = []
var _b_open := 0.0
## How far the spiral has revolved (radians); the shaders turn the jets by it.
var spin_phase := 0.0
## Helix turns along the whole path.
var turns := 4.0
var _rush_a: AudioStreamPlayer3D
var _rush_b: AudioStreamPlayer3D
var _length := 1.0


func setup(a: MossBall, b: MossBall, p_dir_a: Vector3, p_dir_b: Vector3) -> void:
	ball_a = a
	ball_b = b
	dir_a = p_dir_a.normalized()
	dir_b = p_dir_b.normalized()
	# A ball can have several ways out (the chain and branches); vortex_out stays the original
	# chain's, so the first link registered wins it.
	if a.vortex_out == null:
		a.vortex_out = self
	a.vortices.append(self)
	b.vortices.append(self)
	b.vortex_in = self
	b.arrival_dir = dir_b


func _ready() -> void:
	# Path: a cubic curve leaving A along its normal and entering B along its normal.
	var p0 := ball_a.surface_point(dir_a, 0.6)
	var p3 := ball_b.surface_point(dir_b, 0.6)
	var span := p0.distance_to(p3)
	var p1 := p0 + dir_a * span * 0.35
	var p2 := p3 + dir_b * span * 0.35
	var n := 90
	var ref := (p3 - p0).cross(dir_a).normalized()
	for i in n:
		var t := float(i) / (n - 1)
		var u := 1.0 - t
		var p := u * u * u * p0 + 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * p3
		points.append(p)
		ups.append(ref.rotated(((p3 - p0).normalized()), t * PI * 0.5))
	_length = 0.0
	for i in range(1, n):
		_length += points[i].distance_to(points[i - 1])
	turns = clampf(_length / 9.0, 3.0, 7.0)
	var jets := MeshInstance3D.new()
	jets.mesh = _jet_mesh(JETS, TUBE_RADIUS, JET_R, 7, 0.0)
	_jet_mat = _make_jet_mat(0.85, 9.0)
	jets.material_override = _jet_mat
	jets.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	jets.name = "Jets"
	add_child(jets)
	# Thinner streams of spray further in, between the jets.
	var streams := MeshInstance3D.new()
	streams.mesh = _jet_mesh(STREAMS, TUBE_RADIUS * 0.55, 0.11, 4, PI / STREAMS)
	_stream_mat = _make_jet_mat(0.5, 13.0)
	streams.material_override = _stream_mat
	streams.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	streams.name = "Streams"
	add_child(streams)
	_mouth_a = _make_mouth(ball_a, dir_a)
	_mouth_b = _make_mouth(ball_b, dir_b)
	_rush_a = _make_rush(_mouth_a)
	_rush_b = _make_rush(_mouth_b)


func _make_jet_mat(opacity: float, flow: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/vortex_jets.gdshader")
	m.set_shader_parameter("length_m", _length)
	m.set_shader_parameter("opacity", opacity)
	m.set_shader_parameter("flow_speed", flow)
	return m


## Path point, forward and the (side, up) frame at t (0..1), interpolated.
func _frame(t: float) -> Array:
	var s := sample(t)
	var fwd: Vector3 = s[1]
	var u: Vector3 = s[2]
	var side := fwd.cross(u).normalized()
	u = side.cross(fwd).normalized()
	return [s[0], fwd, u, side]


## The helix's radius at t: it flares out near both ends, where the jets sweep down into the pools.
func helix_radius(t: float, r: float) -> float:
	var e := clampf(7.0 / _length, 0.02, 0.3)
	var flare := (1.0 - smoothstep(0.0, e, t)) + smoothstep(1.0 - e, 1.0, t)
	return r * (1.0 + 0.85 * flare)


## Angle round the path of a helix of phase `ph` at t, before the spin.
func helix_angle(t: float, ph: float) -> float:
	return ph + t * turns * TAU


func _helix_point(t: float, r: float, ph: float) -> Vector3:
	var f := _frame(t)
	var a := helix_angle(t, ph)
	return (f[0] as Vector3) + ((f[2] as Vector3) * cos(a) + (f[3] as Vector3) * sin(a)) * helix_radius(t, r)


## `count` tubes wound round the path as a helix of radius `r`, `jr` thick with `sides` sides,
## evenly spaced round it from `phase0`. CUSTOM0 = the path point each ring belongs to, CUSTOM1 =
## the path's direction there (w = which jet), so the shader can revolve the spiral round the path.
func _jet_mesh(count: int, r: float, jr: float, sides: int, phase0: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	st.set_custom_format(1, SurfaceTool.CUSTOM_RGBA_FLOAT)
	var n := int(clampf(turns * 22.0, 90.0, 160.0))
	var base := 0
	for j in count:
		var ph := phase0 + TAU * j / count
		for i in n:
			var t := float(i) / (n - 1)
			var f := _frame(t)
			var c := _helix_point(t, r, ph)
			var dt := 0.5 / (n - 1)
			var tang := (_helix_point(minf(t + dt, 1.0), r, ph) - _helix_point(maxf(t - dt, 0.0), r, ph)).normalized()
			var n1 := (c - (f[0] as Vector3))
			n1 = (n1 - tang * n1.dot(tang)).normalized()
			var n2 := tang.cross(n1).normalized()
			# Thin at the ends (they come out of the pools), swelling slightly along the way.
			var th := jr * (0.6 + 0.4 * smoothstep(0.0, 0.05, t) * (1.0 - smoothstep(0.95, 1.0, t))) * (1.0 + 0.18 * sin(t * 37.0 + j * 2.3))
			for k in sides + 1:
				var a := TAU * k / sides
				var nrm := n1 * cos(a) + n2 * sin(a)
				st.set_normal(nrm)
				st.set_uv(Vector2(float(k) / sides, t))
				st.set_custom(0, Color((f[0] as Vector3).x, (f[0] as Vector3).y, (f[0] as Vector3).z, t))
				st.set_custom(1, Color((f[1] as Vector3).x, (f[1] as Vector3).y, (f[1] as Vector3).z, float(j)))
				st.add_vertex(c + nrm * th)
		for i in n - 1:
			for k in sides:
				var a0 := base + i * (sides + 1) + k
				var b0 := a0 + sides + 1
				st.add_index(a0)
				st.add_index(b0)
				st.add_index(a0 + 1)
				st.add_index(a0 + 1)
				st.add_index(b0)
				st.add_index(b0 + 1)
		base += n * (sides + 1)
	var mesh := st.commit()
	return mesh


func _make_mouth(b: MossBall, d: Vector3) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	root.global_transform = Transform3D(MossBall.frame_at(d, 0.0), b.surface_point(d, 0.0))
	var pool := MeshInstance3D.new()
	pool.mesh = _pool_mesh(b, d, root)
	var pm := ShaderMaterial.new()
	pm.shader = preload("res://shaders/vortex_pool.gdshader")
	pool.material_override = pm
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pool.name = "Pool"
	root.add_child(pool)
	_pool_mats.append(pm)
	root.add_child(_debris(b.index * 7 + int(d.x * 100.0)))
	return root


## A disc lying on the ground round the mouth (following the ball's curve and hills), in the
## mouth's local space: UV.x round, UV.y 0 at the eye .. 1 at the rim; NORMAL = the ground's up.
func _pool_mesh(b: MossBall, d: Vector3, root: Node3D) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 12
	var seg := 48
	var fr := MossBall.frame_at(d, 0.0)
	var inv := root.global_transform.affine_inverse()
	for i in rings + 1:
		var rr := POOL_R * pow(float(i) / rings, 1.4)
		for k in seg + 1:
			var a := TAU * k / seg
			var off := fr.x * cos(a) * rr + fr.z * sin(a) * rr
			var dd := (b.global_position + d * b.radius + off - b.global_position).normalized()
			# A little above the moss, the eye just below the rim so the water reads as a basin.
			var p := b.surface_point(dd, 0.07 + 0.05 * float(i) / rings)
			st.set_normal((inv.basis * dd).normalized())
			st.set_uv(Vector2(float(k) / seg, float(i) / rings))
			st.add_vertex(inv * p)
	for i in rings:
		for k in seg:
			var a0 := i * (seg + 1) + k
			var b0 := a0 + seg + 1
			st.add_index(a0)
			st.add_index(b0)
			st.add_index(a0 + 1)
			st.add_index(a0 + 1)
			st.add_index(b0)
			st.add_index(b0 + 1)
	return st.commit()


## Sand, moss bits and bubbles spiralling up out of the pool into the jets.
func _debris(seed_v: int) -> MultiMeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = q
	mm.instance_count = 70
	for i in mm.instance_count:
		mm.set_instance_transform(i, Transform3D())
		var bubble := i % 3 == 0
		var c := Color(0.85, 0.97, 1.0, 0.8) if bubble else (Color(0.62, 0.52, 0.36, 0.9) if i % 3 == 1 else Color(0.36, 0.5, 0.22, 0.9))
		mm.set_instance_color(i, c)
		mm.set_instance_custom_data(i, Color(rng.randf(), rng.randf_range(1.2, POOL_R * 0.8), rng.randf_range(0.18, 0.35), rng.randf_range(0.05, 0.12) * (1.4 if bubble else 1.0)))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/vortex_debris.gdshader")
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-POOL_R, -1, -POOL_R), Vector3(POOL_R * 2, 9, POOL_R * 2))
	mi.name = "Debris"
	_debris_mats.append(m)
	return mi


func _make_rush(parent: Node3D) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.bus = "Ambience"
	var s = load("res://assets/audio/amb_vortex.wav") if ResourceLoader.exists("res://assets/audio/amb_vortex.wav") else null
	p.stream = s
	p.unit_size = 5.0
	p.max_distance = 45.0
	p.volume_db = -40.0
	parent.add_child(p)
	return p


func mouth_pos(at_b: bool) -> Vector3:
	# The eye of the pool, at the height the old funnel's mouth stood (travel starts there).
	var d := dir_b if at_b else dir_a
	return (_mouth_b if at_b else _mouth_a).global_position + d * 0.9


func pulse() -> void:
	_pulse = 1.0
	Sfx.play("vortex_pulse", _mouth_a.global_position, -6.0)
	# A little rush of water drawn along the tunnel.
	var k := int(clampf(strength, 0.0, 1.0) * (points.size() - 1) * 0.9)
	for i in range(0, k, 6):
		WaterFX.inst._spawn_puff(points[i] + Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * TUBE_RADIUS,
				(points[mini(i + 1, points.size() - 1)] - points[i]).normalized() * 6.0, 1.0, 0.1, Color(0.7, 0.95, 1.0, 0.6), 0.2)


func _process(dt: float) -> void:
	_target = clampf(ball_a.restoration / CONNECT_AT, 0.0, 1.0)
	strength = move_toward(strength, _target, dt * 0.08)
	_pulse = maxf(0.0, _pulse - dt * 1.2)
	_b_open = move_toward(_b_open, 1.0 if connected else 0.0, dt * 0.7)
	# The spiral revolves faster as it strengthens: a slow stir, then a hurricane.
	spin_phase = fmod(spin_phase + dt * (0.35 + strength * 2.2), TAU * 64.0)
	var grow := 1.0 if connected else strength * 0.96
	# The spiral physically reaches out toward the next ball.
	for m in [_jet_mat, _stream_mat]:
		m.set_shader_parameter("grow", grow)
		m.set_shader_parameter("strength", 0.25 + strength * 0.75)
		m.set_shader_parameter("pulse", _pulse)
		m.set_shader_parameter("spin_phase", spin_phase)
	for i in 2:
		var s := strength if i == 0 else _b_open
		var pm := _pool_mats[i]
		pm.set_shader_parameter("strength", 0.15 + s * 0.85)
		pm.set_shader_parameter("reach", 0.3 + s * 0.7 if i == 0 else maxf(s, 0.001))
		pm.set_shader_parameter("pulse", _pulse)
		pm.set_shader_parameter("spin_phase", spin_phase)
		var dm := _debris_mats[i]
		dm.set_shader_parameter("strength", s)
		dm.set_shader_parameter("spin_phase", spin_phase)
	_mouth_b.visible = _b_open > 0.001
	_update_rush(_rush_a, 0.1 + strength)
	_update_rush(_rush_b, 1.1 if connected else 0.0)


func _update_rush(p: AudioStreamPlayer3D, s: float) -> void:
	if p.stream == null:
		return
	var db := linear_to_db(maxf(0.0001, s * 0.8))
	p.volume_db = db
	if s > 0.01 and not p.playing:
		p.play()
	elif s <= 0.01 and p.playing:
		p.stop()


## Position/orientation along the tunnel for travel. t = 0 at A, 1 at B.
func sample(t: float) -> Array:
	var f := clampf(t, 0.0, 1.0) * (points.size() - 1)
	var i := mini(int(f), points.size() - 2)
	var k := f - i
	var p := points[i].lerp(points[i + 1], k)
	var fwd := (points[i + 1] - points[i]).normalized()
	var u := ups[i].lerp(ups[i + 1], k).normalized()
	return [p, fwd, u]


## Gill's pose on the ride at t (0..1 from A): carried round the path beside the first jet, a
## little inside it, as the spiral revolves: a corkscrew. At both ends he is at the eye of the pool.
## Returns [position, direction of travel from A to B, up (toward the path: his belly to the jet)].
func ride_pose(t: float) -> Array:
	var ride := func(tt: float) -> Vector3:
		var f := _frame(tt)
		var env := smoothstep(0.0, 0.07, tt) * (1.0 - smoothstep(0.93, 1.0, tt))
		var a := helix_angle(tt, 0.0) + spin_phase
		var r := helix_radius(tt, TUBE_RADIUS - 0.6) * env
		return (f[0] as Vector3) + ((f[2] as Vector3) * cos(a) + (f[3] as Vector3) * sin(a)) * r
	var p: Vector3 = ride.call(t)
	var fwd: Vector3 = ((ride.call(minf(t + 0.004, 1.0)) as Vector3) - (ride.call(maxf(t - 0.004, 0.0)) as Vector3)).normalized()
	var f := _frame(t)
	var inward := (f[0] as Vector3) - p
	if inward.length() < 0.2:
		inward = f[2]
	var up := (inward - fwd * inward.dot(fwd)).normalized()
	return [p, fwd, up, f[0], f[1]]
