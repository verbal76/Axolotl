class_name Bloom
extends Node3D
## Checkpoint: a small healthy moss bloom. Opens and glows when touched and becomes the
## regeneration point.

var ball: MossBall
var dir := Vector3.UP
var h_hint := 0.0
var active := false
var _open := 0.0
var _bright := 0.0
var _petals: Array[Node3D] = []
var _glow_mat: StandardMaterial3D
var _petal_mat: StandardMaterial3D
var _ready_pos := false
var _t := 0.0


func setup(p_ball: MossBall, p_dir: Vector3, h := 0.0) -> void:
	ball = p_ball
	dir = p_dir.normalized()
	h_hint = h


func _ready() -> void:
	var stem_mat := StandardMaterial3D.new()
	stem_mat.albedo_color = Color(0.25, 0.55, 0.2)
	var stem := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.04
	cm.bottom_radius = 0.07
	cm.height = 0.5
	cm.radial_segments = 6
	stem.mesh = cm
	stem.material_override = stem_mat
	stem.position = Vector3(0, 0.25, 0)
	add_child(stem)
	_petal_mat = StandardMaterial3D.new()
	_petal_mat.albedo_color = Color(0.45, 0.8, 0.4)
	_petal_mat.emission_enabled = true
	_petal_mat.emission = Color(0.4, 1.0, 0.7)
	_petal_mat.emission_energy_multiplier = 0.0
	_petal_mat.rim_enabled = true
	_petal_mat.rim = 0.5
	for i in 6:
		var p := Node3D.new()
		p.position = Vector3(0, 0.5, 0)
		p.rotation = Vector3(0, TAU * i / 6.0, 0)
		add_child(p)
		var leaf := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.16
		s.height = 0.32
		s.radial_segments = 8
		s.rings = 4
		leaf.mesh = s
		leaf.material_override = _petal_mat
		leaf.scale = Vector3(0.45, 1.0, 0.18)
		leaf.position = Vector3(0, 0.14, 0.0)
		var hinge := Node3D.new()
		p.add_child(hinge)
		hinge.add_child(leaf)
		_petals.append(hinge)
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.albedo_color = Color(0.7, 1.0, 0.8)
	_glow_mat.emission_enabled = true
	_glow_mat.emission = Color(0.5, 1.0, 0.75)
	_glow_mat.emission_energy_multiplier = 0.3
	var core := MeshInstance3D.new()
	var cs := SphereMesh.new()
	cs.radius = 0.09
	cs.height = 0.18
	core.mesh = cs
	core.material_override = _glow_mat
	core.position = Vector3(0, 0.55, 0)
	add_child(core)


func respawn_point() -> Vector3:
	var up := ball.up_at(global_position)
	return global_position + up * 0.35 + global_basis.z * 0.9


func activate() -> void:
	if active:
		return
	active = true
	Sfx.play("checkpoint", global_position)
	WaterFX.inst.sparkle(global_position + global_basis.y * 0.6, Color(0.5, 1.0, 0.75, 0.9), 16, 1.2)


func brighten() -> void:
	_bright = 1.5


func _process(dt: float) -> void:
	_t += dt
	if not _ready_pos and ball:
		var top := ball.surface_point(dir, h_hint + 3.0)
		var q := PhysicsRayQueryParameters3D.create(top, ball.global_position, 1 | 2)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty() or Engine.get_physics_frames() > 2:
			var p: Vector3 = hit.position if not hit.is_empty() else ball.surface_point(dir)
			global_transform = Transform3D(MossBall.frame_at(ball.up_at(p), 0.0), p - ball.up_at(p) * 0.05)
			_ready_pos = true
	_open = move_toward(_open, 1.0 if active else 0.0, dt * 1.4)
	_bright = maxf(0.0, _bright - dt)
	for p in _petals:
		p.rotation.x = lerpf(0.15, 1.15, smoothstep(0.0, 1.0, _open)) + sin(_t * 1.5) * 0.04
	var e := _open * (1.6 + sin(_t * 2.0) * 0.3) + _bright * 4.0
	_petal_mat.emission_energy_multiplier = e * 0.5
	_glow_mat.emission_energy_multiplier = 0.3 + e * 1.5
