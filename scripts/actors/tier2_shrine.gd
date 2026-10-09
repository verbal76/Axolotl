class_name Tier2Shrine
extends Node3D
## A Tier-2 shrine (docs/TIER2.md): an old spiral shell, half sunk in the moss at one of a world's
## landmarks, glowing while it still holds its ability for this run. Touching it (Game._check_shrines)
## gives Gill the ability and sets out a few harmless practice targets nearby (`practice`, points
## in world space) for a safe first try.

var ball: MossBall
var ability := ""
var dir := Vector3.UP
var h_hint := 0.0
## Where its practice targets float (world space, set by the level builder).
var practice: Array = []
var taken := false
var _ready_pos := false
var _t := 0.0
var _glow_mat: StandardMaterial3D
var _shell: Node3D


func setup(p_ball: MossBall, p_ability: String, p_dir: Vector3, h := 0.0) -> void:
	ball = p_ball
	ability = p_ability
	dir = p_dir.normalized()
	h_hint = h


func _ready() -> void:
	_shell = Node3D.new()
	add_child(_shell)
	var shell_mat := StandardMaterial3D.new()
	shell_mat.albedo_color = Color(0.78, 0.72, 0.6)
	shell_mat.roughness = 0.75
	shell_mat.rim_enabled = true
	shell_mat.rim = 0.35
	# A coiled shell: whorls shrinking along a rising spiral.
	for i in 7:
		var k := float(i) / 6.0
		var whorl := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = lerpf(0.22, 0.04, k)
		tm.outer_radius = lerpf(0.5, 0.12, k)
		tm.rings = 14
		tm.ring_segments = 8
		whorl.mesh = tm
		whorl.material_override = shell_mat
		whorl.position = Vector3(sin(k * 5.0) * 0.08, 0.12 + k * 0.62, cos(k * 5.0) * 0.08)
		whorl.rotation = Vector3(0.35, k * 2.4, 0.0)
		_shell.add_child(whorl)
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.albedo_color = Color(0.7, 0.95, 1.0)
	_glow_mat.emission_enabled = true
	_glow_mat.emission = Color(0.45, 0.9, 1.0)
	_glow_mat.emission_energy_multiplier = 1.4
	var core := MeshInstance3D.new()
	var cs := SphereMesh.new()
	cs.radius = 0.16
	cs.height = 0.32
	cs.radial_segments = 12
	cs.rings = 6
	core.mesh = cs
	core.material_override = _glow_mat
	core.position = Vector3(0, 0.34, 0)
	_shell.add_child(core)


func is_placed() -> bool:
	return _ready_pos


## Where Gill touches it.
func touch_point() -> Vector3:
	return global_position + ball.up_at(global_position) * 0.4


## Already taken this run (a continued run, or just now): dim, nothing to give.
func set_taken(v: bool) -> void:
	taken = v


func _process(dt: float) -> void:
	_t += dt
	if not _ready_pos and ball:
		var top := ball.surface_point(dir, h_hint + 3.0)
		var q := PhysicsRayQueryParameters3D.create(top, ball.global_position, 1 | 2 | LevelBuilder.CLIMB_LAYER)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty() or Engine.get_physics_frames() > 2:
			var p: Vector3 = hit.position if not hit.is_empty() else ball.surface_point(dir, h_hint)
			global_transform = Transform3D(MossBall.frame_at(ball.up_at(p), 30.0), p - ball.up_at(p) * 0.08)
			_ready_pos = true
	if _glow_mat:
		var pulse := 0.5 + 0.5 * sin(_t * 2.2)
		_glow_mat.emission_energy_multiplier = (0.25 if taken else 1.0 + pulse * 1.4)
		_shell.rotation.y = 0.0 if taken else sin(_t * 0.7) * 0.08
