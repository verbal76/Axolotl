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
##
## Vortex currents (ledger row 14, owner: the tunnels read as straight pipes; they must read as moving
## water currents): the logical travel path `points` stays fixed, and the visible centreline is carried
## by a slow, bounded, deterministic offset D(u, time) (`current_offset`): w(u) = sin(pi u)^1.5 keeps the
## mouths anchored and lets mid-span move most, and per axis (sideways, vertical, along) three slow sines
## at incommensurate frequencies, phases and phase gradients along u sum to a meander, each connection with
## its own stable personality (seeded by its link index). The jets', streams' and debris' vertex shaders
## (shaders/vortex_current.gdshaderinc) evaluate the same formula from the phases set here, and
## `ride_pose` adds it on the CPU, so Gill rides inside the moving current. u (0 = ball A, 0.5 = midpoint,
## 1 = ball B) is the stable parameter along the connection, available to every vortex shader.

const CONNECT_AT := 0.7
## Radius of the helix the jets wind along (and of the old tube, kept for the mouth clearance).
const TUBE_RADIUS := 2.1
const JETS := 5
const JET_R := 0.42
const STREAMS := 3
const POOL_R := 5.2
## Each connection's faint hue (owner, 2026-09-30: nearby vortices were mistaken for one another), by
## its index in Levels.LINKS: the same at both ends, stable, and chosen so no two connections that
## share a ball look alike. Mostly in the bright water (TINT_AMT), so they stay water.
const TINTS := [Color(1.0, 0.36, 0.62), Color(0.36, 1.0, 0.42), Color(1.0, 0.72, 0.22), Color(0.7, 0.46, 1.0),
		Color(1.0, 0.42, 0.3), Color(0.32, 0.52, 1.0)]
const TINT_AMT := 0.5
## The current's three terms per axis: base angular speeds (rad/s; periods ~37 s, ~63 s, ~114 s before
## each connection's own scaling) and their share of the amplitude. Slow on purpose: a drift, never a wobble.
const CUR_OMEGA := [0.17, 0.1, 0.055]
const CUR_SHARE := [0.46, 0.34, 0.2]
## Amplitude share per axis: sideways, vertical, along the connection (depth).
const CUR_AXES := Vector3(1.0, 0.78, 0.3)

## Platform state (owner, 2026-10-04: from the ground the player cannot see whether the funnel has
## reached the next ball). A glowing ring round each tidal pool shows travel readiness, read from
## travel_ready() only. Never colour alone (red/green colour-vision deficiency): not ready is a
## muted red, DASHED, dim and slowly breathing; ready is a muted green, CONTINUOUS, brighter and
## steadily flowing. Per state: [colour, gain, dashes (0 = continuous), breathing swing, flow].
const STATE_LOOK := {
	false: [Color(0.72, 0.3, 0.17), 0.8, 1.0, 0.3, 0.0],
	true: [Color(0.33, 0.78, 0.52), 1.0, 0.0, 0.0, 1.0],
}
## Seconds the ring takes to change state (the 70% moment is also marked by the connect shot).
const STATE_FADE_S := 1.2

## Off: the shipped straight tunnels (before/after comparisons in the render harness).
static var currents := true

## Hard Mode's remote distress (ledger row 12; §E2 of docs/research/2026-09-30-DEVICE_AUDIT.md, owner
## rulings J-M), per severity level S0..S3: the luminance swing of the pulse, its period (s; never under
## 2 s) and the tint amount (S0 = TINT_AMT, today's look). Each end's half shows its own sphere's level;
## shown levels crossfade over DISTRESS_FADE_S. Purely visual: travel, unlocks and collision never read it.
const DISTRESS_SWING := [0.0, 0.12, 0.25, 0.40]
const DISTRESS_PERIOD := [6.0, 6.0, 4.0, 2.5]
const DISTRESS_TINT := [0.5, 0.55, 0.62, 0.72]
const DISTRESS_FADE_S := 3.0

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
## This connection's hue (TINTS).
var tint := Color.WHITE
## Its index in Levels.LINKS: seeds the current's personality.
var link_index := 0
## The current's clock (s): advances with play, so the meander is a pure function of (link, time).
var current_time := 0.0
## Per term k: amplitude (m), angular speed (rad/s), phase (rad) and phase gradient along u, per axis.
var cur_amp: Array[Vector3] = []
var cur_omega: Array[Vector3] = []
var cur_phi: Array[Vector3] = []
var cur_kap: Array[Vector3] = []
## Sideways, vertical, along (columns), in world space.
var cur_basis := Basis()
var _cur_mats: Array[ShaderMaterial] = []
## Hard Mode: the severity level (0..3) each end's half signals (set by HardMode at 4 Hz), the level
## shown now (crossfading toward it) and each half's pulse phase (rad). Normal never sets them, and
## nothing is sent to the shaders until it does.
var distress_level: Array[int] = [0, 0]
var distress_shown: Array[float] = [0.0, 0.0]
var distress_phase: Array[float] = [0.0, 0.0]
var _distress_on := false
## The platform state shown (0 = not ready .. 1 = ready), easing toward travel_ready(); -1 until the
## first frame, which snaps to it (a loaded save or a return shows the right state at once).
var ready_shown := -1.0


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
	_setup_current(p0, p3)
	var jets := MeshInstance3D.new()
	jets.mesh = _jet_mesh(JETS, TUBE_RADIUS, JET_R, 7, 0.0)
	_jet_mat = _make_jet_mat(0.85, 9.0)
	jets.material_override = _jet_mat
	jets.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	jets.name = "Jets"
	jets.extra_cull_margin = current_bound()
	add_child(jets)
	# Thinner streams of spray further in, between the jets.
	var streams := MeshInstance3D.new()
	streams.mesh = _jet_mesh(STREAMS, TUBE_RADIUS * 0.55, 0.11, 4, PI / STREAMS)
	_stream_mat = _make_jet_mat(0.5, 13.0)
	streams.material_override = _stream_mat
	streams.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	streams.name = "Streams"
	streams.extra_cull_margin = current_bound()
	add_child(streams)
	_mouth_a = _make_mouth(ball_a, dir_a)
	_mouth_b = _make_mouth(ball_b, dir_b)
	for i in 2:
		var root := _mouth_b if i == 1 else _mouth_a
		_pool_mats[i].set_shader_parameter("u_end", float(i))
		var dm := _debris_mats[i]
		dm.set_shader_parameter("u_end", float(i))
		dm.set_shader_parameter("length_m", _length)
		dm.set_shader_parameter("cur_basis", root.global_basis.inverse() * cur_basis)
		_cur_mats.append(dm)
	_jet_mat.set_shader_parameter("cur_basis", cur_basis)
	_stream_mat.set_shader_parameter("cur_basis", cur_basis)
	_cur_mats.append_array([_jet_mat, _stream_mat])
	_update_current()
	_rush_a = _make_rush(_mouth_a)
	_rush_b = _make_rush(_mouth_b)


## The current's personality, fixed by the link index (never by the gameplay random sequence).
func _setup_current(p0: Vector3, p3: Vector3) -> void:
	var along := (p3 - p0).normalized()
	var side := along.cross(Vector3.UP)
	if side.length() < 0.2:
		side = along.cross(Vector3.RIGHT)
	side = side.normalized()
	var vert := side.cross(along).normalized()
	cur_basis = Basis(side, vert, along)
	var rng := RandomNumberGenerator.new()
	rng.seed = 91733 + link_index * 7919
	# Mid-span sway in metres: room to bend, and still clearly a route between the two mouths.
	var big := clampf(_length * 0.11, 3.0, 9.0) * rng.randf_range(0.85, 1.15)
	cur_amp.clear()
	cur_omega.clear()
	cur_phi.clear()
	cur_kap.clear()
	for k in 3:
		var a := Vector3.ZERO
		var w := Vector3.ZERO
		var ph := Vector3.ZERO
		var kp := Vector3.ZERO
		for ax in 3:
			a[ax] = big * CUR_AXES[ax] * CUR_SHARE[k] * rng.randf_range(0.8, 1.2)
			w[ax] = CUR_OMEGA[k] * rng.randf_range(0.75, 1.3)
			ph[ax] = rng.randf_range(0.0, TAU)
			kp[ax] = rng.randf_range(-3.0, 3.0)
		cur_amp.append(a)
		cur_omega.append(w)
		cur_phi.append(ph)
		cur_kap.append(kp)


## The largest offset the current can ever reach (m).
func current_bound() -> float:
	var s := Vector3.ZERO
	for a in cur_amp:
		s += a.abs()
	return s.length()


## The current's envelope along u: 0 at both mouths, 1 mid-span.
static func current_weight(u: float) -> float:
	return pow(maxf(sin(PI * clampf(u, 0.0, 1.0)), 0.0), 1.5)


## The visible centreline's offset from the logical path at u (0 = A .. 1 = B) at `time` (s): the same
## formula as shaders/vortex_current.gdshaderinc.
func current_offset_at(u: float, time: float) -> Vector3:
	if not currents or cur_amp.is_empty():
		return Vector3.ZERO
	var s := Vector3.ZERO
	for k in 3:
		for ax in 3:
			s[ax] += cur_amp[k][ax] * sin(fposmod(cur_omega[k][ax] * time + cur_phi[k][ax], TAU) + cur_kap[k][ax] * u)
	return cur_basis * (s * current_weight(u))


## The offset now (what the shaders draw this frame).
func current_offset(u: float) -> Vector3:
	return current_offset_at(u, current_time)


## The visible (meandering) centreline at u.
func visual_point(u: float) -> Vector3:
	return (sample(u)[0] as Vector3) + current_offset(u)


func _update_current() -> void:
	var on := 1.0 if currents else 0.0
	for k in 3:
		var ph := Vector3.ZERO
		for ax in 3:
			ph[ax] = fposmod(cur_omega[k][ax] * current_time + cur_phi[k][ax], TAU)
		for m in _cur_mats:
			m.set_shader_parameter("cur_amp%d" % k, cur_amp[k] * on)
			m.set_shader_parameter("cur_ph%d" % k, ph)
			m.set_shader_parameter("cur_kap%d" % k, cur_kap[k])


func _make_jet_mat(opacity: float, flow: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/vortex_jets.gdshader")
	m.set_shader_parameter("length_m", _length)
	m.set_shader_parameter("opacity", opacity)
	m.set_shader_parameter("flow_speed", flow)
	_tint(m)
	return m


func _tint(m: ShaderMaterial) -> void:
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("tint_amt", TINT_AMT if tint != Color.WHITE else 0.0)


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
	_tint(pm)
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
	_tint(m)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-POOL_R, -1, -POOL_R), Vector3(POOL_R * 2, 9, POOL_R * 2)).grow(current_bound() * 0.5)
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


## THE travel eligibility: Game._check_vortex_entry lets Gill in only through this, and the platform
## ring shows only this, so the two can never disagree.
func travel_ready() -> bool:
	return connected


## The ring's look for a shown state: [colour, gain, dashes, breathing swing, flow].
static func state_look(shown: float) -> Array:
	var a: Array = STATE_LOOK[false]
	var b: Array = STATE_LOOK[true]
	var k := clampf(shown, 0.0, 1.0)
	return [(a[0] as Color).lerp(b[0], k), lerpf(a[1], b[1], k), lerpf(a[2], b[2], k), lerpf(a[3], b[3], k), lerpf(a[4], b[4], k)]


func _update_state(dt: float) -> void:
	var want := 1.0 if travel_ready() else 0.0
	ready_shown = want if ready_shown < 0.0 else move_toward(ready_shown, want, dt / STATE_FADE_S)
	var lk := state_look(ready_shown)
	for pm in _pool_mats + [_jet_mat, _stream_mat]:
		pm.set_shader_parameter("state_col", lk[0])
		pm.set_shader_parameter("state_gain", lk[1])
		pm.set_shader_parameter("state_dash", lk[2])
		pm.set_shader_parameter("state_breathe", lk[3])
		pm.set_shader_parameter("state_flow", lk[4])


func pulse() -> void:
	_pulse = 1.0
	Sfx.play("vortex_pulse", _mouth_a.global_position, -6.0)
	# A little rush of water drawn along the tunnel.
	var k := int(clampf(strength, 0.0, 1.0) * (points.size() - 1) * 0.9)
	for i in range(0, k, 6):
		WaterFX.inst._spawn_puff(points[i] + current_offset(float(i) / (points.size() - 1)) + Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * TUBE_RADIUS,
				(points[mini(i + 1, points.size() - 1)] - points[i]).normalized() * 6.0, 1.0, 0.1, Color(0.7, 0.95, 1.0, 0.6), 0.2)


func _process(dt: float) -> void:
	_target = clampf(ball_a.restoration / CONNECT_AT, 0.0, 1.0)
	strength = move_toward(strength, _target, dt * 0.08)
	_pulse = maxf(0.0, _pulse - dt * 1.2)
	_b_open = move_toward(_b_open, 1.0 if connected else 0.0, dt * 0.7)
	# The spiral revolves faster as it strengthens: a slow stir, then a hurricane.
	spin_phase = fmod(spin_phase + dt * (0.35 + strength * 2.2), TAU * 64.0)
	current_time += dt
	_update_current()
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
	_update_state(dt)
	if _distress_on:
		_update_distress(dt)
	_update_rush(_rush_a, 0.1 + strength)
	_update_rush(_rush_b, 1.1 if connected else 0.0)


## Hard Mode: the level each end's half signals (0 = normal .. 3 = urgent).
func set_distress(level_a: int, level_b: int) -> void:
	if not _distress_on:
		if level_a == 0 and level_b == 0:
			return
		_distress_on = true
		# (Every connection pulses on its own phase, never in step with the others.)
		distress_phase = [link_index * 1.31, link_index * 1.31]
	distress_level = [clampi(level_a, 0, 3), clampi(level_b, 0, 3)]


## Back to exactly Normal's look at once (tests that drew distress clean up with it).
func clear_distress() -> void:
	distress_level = [0, 0]
	distress_shown = [0.0, 0.0]
	if _distress_on:
		_update_distress(0.0)
	_distress_on = false


## The shown (crossfaded) look of one end's half: [luminance swing, period s, tint amount].
func distress_look(end: int) -> Array:
	var lv := clampf(distress_shown[end], 0.0, 3.0)
	var i := mini(int(floor(lv)), 2)
	var k := lv - i
	return [lerpf(DISTRESS_SWING[i], DISTRESS_SWING[i + 1], k), maxf(2.0, lerpf(DISTRESS_PERIOD[i], DISTRESS_PERIOD[i + 1], k)),
			lerpf(DISTRESS_TINT[i], DISTRESS_TINT[i + 1], k)]


func _update_distress(dt: float) -> void:
	var looks := []
	for e in 2:
		distress_shown[e] = move_toward(distress_shown[e], float(distress_level[e]), dt / DISTRESS_FADE_S)
		var lk := distress_look(e)
		distress_phase[e] = fmod(distress_phase[e] + dt * TAU / float(lk[1]), TAU * 64.0)
		looks.append(lk)
	var da := Vector2(looks[0][0], looks[0][1])
	var db := Vector2(looks[1][0], looks[1][1])
	var dx := Vector4(distress_phase[0], distress_phase[1], looks[0][2], looks[1][2])
	for m in [_jet_mat, _stream_mat, _pool_mats[0], _pool_mats[1], _debris_mats[0], _debris_mats[1]]:
		(m as ShaderMaterial).set_shader_parameter("distress_a", da)
		(m as ShaderMaterial).set_shader_parameter("distress_b", db)
		(m as ShaderMaterial).set_shader_parameter("distress_x", dx)


func _update_rush(p: AudioStreamPlayer3D, s: float) -> void:
	if p.stream == null:
		return
	var db := linear_to_db(maxf(0.0001, s * 0.8))
	# (Only when it moves audibly: per-frame writes raced the engine's audio thread, ledger row 37.)
	AudioDirector.set_volume(p, db, s <= 0.0)
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


## The axolotl's pose on the ride at t (0..1 from A): carried round the path beside the first jet, a
## little inside it, as the spiral revolves: a corkscrew. At both ends he is at the eye of the pool.
## The ride follows the logical path's timing, carried by the current's offset (ledger row 14), so he
## stays inside the meandering water the shaders draw.
## Returns [position, direction of travel from A to B, up (toward the path: his belly to the jet),
## the visible centreline point, its direction].
func ride_pose(t: float) -> Array:
	var ride := func(tt: float) -> Vector3:
		var f := _frame(tt)
		var env := smoothstep(0.0, 0.07, tt) * (1.0 - smoothstep(0.93, 1.0, tt))
		var a := helix_angle(tt, 0.0) + spin_phase
		var r := helix_radius(tt, TUBE_RADIUS - 0.6) * env
		return (f[0] as Vector3) + current_offset(tt) + ((f[2] as Vector3) * cos(a) + (f[3] as Vector3) * sin(a)) * r
	var p: Vector3 = ride.call(t)
	var fwd: Vector3 = ((ride.call(minf(t + 0.004, 1.0)) as Vector3) - (ride.call(maxf(t - 0.004, 0.0)) as Vector3)).normalized()
	var f := _frame(t)
	var axis := (f[0] as Vector3) + current_offset(t)
	var axis_f := (visual_point(minf(t + 0.004, 1.0)) - visual_point(maxf(t - 0.004, 0.0))).normalized()
	var inward := axis - p
	if inward.length() < 0.2:
		inward = f[2]
	var up := (inward - fwd * inward.dot(fwd)).normalized()
	return [p, fwd, up, axis, axis_f]
