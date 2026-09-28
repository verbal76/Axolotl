class_name Vortex
extends Node3D
## Bathtub-drain-style water vortex between two moss balls. Its strength grows continuously
## with the source ball's restoration; the tunnel reaches the next ball at ~70%.
## Once connected it stays open and works in both directions.

const CONNECT_AT := 0.7
const TUBE_RADIUS := 2.1

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
var _tube_mat: ShaderMaterial
var _mouth_a: Node3D
var _mouth_b: Node3D
var _mouth_mats: Array[ShaderMaterial] = []
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
	var tube := MeshInstance3D.new()
	tube.mesh = MeshLib.tube_mesh(points, ups, TUBE_RADIUS, 20)
	_tube_mat = ShaderMaterial.new()
	_tube_mat.shader = preload("res://shaders/vortex.gdshader")
	_tube_mat.set_shader_parameter("along_scale", _length * 0.25)
	tube.material_override = _tube_mat
	tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tube.name = "Tunnel"
	add_child(tube)
	_mouth_a = _make_mouth(ball_a, dir_a)
	_mouth_b = _make_mouth(ball_b, dir_b)
	_mouth_b.scale = Vector3.ONE * 0.01
	_rush_a = _make_rush(_mouth_a)
	_rush_b = _make_rush(_mouth_b)


func _make_mouth(b: MossBall, d: Vector3) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	root.global_transform = Transform3D(MossBall.frame_at(d, 0.0), b.surface_point(d, 0.9))
	for layer in 3:
		var mi := MeshInstance3D.new()
		mi.mesh = MeshLib.funnel_mesh(TUBE_RADIUS * (1.0 + layer * 0.35), 0.25 + layer * 0.1, 1.2 + layer * 0.3, 24)
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/vortex.gdshader")
		m.set_shader_parameter("grow", 1.0)
		m.set_shader_parameter("along_scale", 6.0 + layer * 3.0)
		m.set_shader_parameter("spin", 1.5 - layer * 0.3)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(0, layer * 0.15, 0)
		root.add_child(mi)
		_mouth_mats.append(m)
	return root


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
	return (_mouth_b if at_b else _mouth_a).global_position


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
	var grow := 1.0 if connected else strength * 0.96
	# The tunnel physically extends toward the next ball.
	_tube_mat.set_shader_parameter("grow", grow)
	_tube_mat.set_shader_parameter("strength", 0.25 + strength * 0.75)
	_tube_mat.set_shader_parameter("pulse", _pulse)
	for i in _mouth_mats.size():
		var m := _mouth_mats[i]
		var at_b := i >= 3
		var s := (1.0 if connected else 0.0) if at_b else strength
		m.set_shader_parameter("strength", 0.15 + s * 0.85)
		m.set_shader_parameter("pulse", _pulse)
		m.set_shader_parameter("spin", (0.3 + s * 1.7) * (1.0 - (i % 3) * 0.2))
	_mouth_a.scale = Vector3.ONE * (0.35 + strength * 0.65)
	var b_target := 1.0 if connected else 0.01
	_mouth_b.scale = _mouth_b.scale.lerp(Vector3.ONE * b_target, minf(1.0, dt * 1.5))
	_mouth_a.rotate_object_local(Vector3.UP, dt * (0.4 + strength * 2.0))
	_mouth_b.rotate_object_local(Vector3.UP, dt * (0.4 + (2.0 if connected else 0.0)))
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
