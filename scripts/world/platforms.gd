class_name Platforms
## Factory for platform types built from code.


## Brittle, parasite-damaged moss slab. Crumbles shortly after being stood on and regrows
## a few seconds later; becomes permanently solid once its zone is restored.
class Crumble extends StaticBody3D:
	var zone_id := ""
	var ball: MossBall
	var restored := false
	var _state := "solid"   # solid shaking gone
	var _t := 0.0
	var _mesh: MeshInstance3D
	var _shape: CollisionShape3D
	var _home: Transform3D

	func build(p_ball: MossBall, xf: Transform3D, size: Vector3, p_zone: String) -> void:
		ball = p_ball
		zone_id = p_zone
		transform = xf
		_home = xf
		collision_layer = 2
		collision_mask = 0
		set_meta("unsafe", true)
		_shape = CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = size
		_shape.shape = b
		add_child(_shape)
		_mesh = MeshInstance3D.new()
		var m := MeshLib.cushion_mesh(size.x * 0.5, size.y, size.y * 0.5, 10)
		_mesh.mesh = m
		_mesh.position = Vector3(0, -size.y * 0.5, 0)
		_mesh.scale = Vector3(1.0, 1.0, size.z / size.x)
		_mesh.material_override = ball.moss_material
		add_child(_mesh)

	func stepped() -> void:
		if restored or _state != "solid":
			return
		_state = "shaking"
		_t = 0.0
		Sfx.play("crumble", global_position, -6.0)

	func restore() -> void:
		restored = true
		remove_meta("unsafe")
		if _state != "solid":
			_state = "regrow"
			_t = 0.0

	func _physics_process(dt: float) -> void:
		_t += dt
		match _state:
			"shaking":
				position = _home.origin + Vector3(randf() - 0.5, 0, randf() - 0.5) * 0.06
				if _t > 0.8:
					_state = "gone"
					_t = 0.0
					_shape.disabled = true
					_mesh.visible = false
					position = _home.origin
					var up := ball.up_at(global_position)
					for i in 10:
						WaterFX.inst._spawn_puff(global_position + Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * 0.8,
								-up * randf_range(1.0, 3.0), 1.2, randf_range(0.06, 0.12), Color(0.5, 0.48, 0.42, 0.9), 0.8)
			"gone":
				if _t > 3.5 or restored:
					var pl := Game.inst.player
					if pl.global_position.distance_to(global_position) > 1.4:
						_state = "regrow"
						_t = 0.0
			"regrow":
				_shape.disabled = false
				_mesh.visible = true
				_mesh.scale.y = minf(1.0, _t / 0.6)
				if _t > 0.6:
					_state = "solid"


## Flexible leaf on a stem: bends deeply under an impact, cushions falls, and (if bouncy)
## rebounds modestly. A hard impact can fling parasites standing on it into open water.
class FlexLeaf extends AnimatableBody3D:
	var ball: MossBall
	var bouncy := false
	var theta := 0.0
	var omega := 0.0
	var stiffness := 38.0
	var damping := 4.5
	var _pivot_xf: Transform3D
	var _length := 3.0
	var _pending_rebound := 0.0
	var _rebound_player: Axolotl
	var _prev_omega := 0.0

	func build(p_ball: MossBall, pivot: Transform3D, length: float, width: float, mat: Material, p_bouncy: bool) -> void:
		ball = p_ball
		bouncy = p_bouncy
		_pivot_xf = pivot
		_length = length
		global_transform = pivot
		collision_layer = 2
		collision_mask = 0
		sync_to_physics = true
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(width * 0.8, 0.25, length * 0.9)
		cs.shape = b
		cs.position = Vector3(0, -0.05, -length * 0.5)
		add_child(cs)
		var mi := MeshInstance3D.new()
		mi.mesh = MeshLib.platform_leaf_mesh(length, width)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)

	func absorb(player: Axolotl, impact: float, _fall: float) -> void:
		omega -= clampf(impact * 0.09, 0.4, 2.6)
		if bouncy and impact > 7.0:
			_pending_rebound = clampf(impact * 0.55, 5.0, 11.0)
			_rebound_player = player
		if impact > 9.0:
			for p in ball.parasites:
				if p.standing_on == self and p.is_alive():
					var up := ball.up_at(p.global_position)
					var out: Vector3 = (p.global_position - global_position)
					out -= up * out.dot(up)
					p.fling(up * 8.5 + out.normalized() * 4.0)
		WaterFX.inst.impulse(player.global_position, 1.6, 0.5)

	func _physics_process(dt: float) -> void:
		var load := 0.0
		var pl := Game.inst.player if Game.inst else null
		if pl and pl.grounded and pl._floor_collider() == self:
			load = 0.12
		var acc := -stiffness * (theta - (-load)) - damping * omega
		_prev_omega = omega
		omega += acc * dt
		theta = clampf(theta + omega * dt, -0.75, 0.35)
		# Rebound once the leaf starts springing back upward.
		if _pending_rebound > 0.0 and _prev_omega < 0.0 and omega >= 0.0:
			if _rebound_player and _rebound_player.grounded and _rebound_player._floor_collider() == self:
				_rebound_player.leaf_rebound(_pending_rebound)
			_pending_rebound = 0.0
		global_transform = Transform3D(_pivot_xf.basis * Basis(Vector3.RIGHT, theta), _pivot_xf.origin)


## Living moving platform: a tall plant swaying in the aquarium current with a broad leaf at
## the top (Moss Ball #2).
class SwayLeaf extends AnimatableBody3D:
	var ball: MossBall
	var _base: Transform3D
	var _stem_len := 3.0
	var _amp := 0.25
	var _freq := 0.5
	var _phase := 0.0
	var _t := 0.0

	func build(p_ball: MossBall, base: Transform3D, stem_len: float, leaf_len: float, leaf_w: float, amp: float, freq: float, phase: float,
			stem_mat: Material, leaf_mat: Material) -> void:
		ball = p_ball
		_base = base
		_stem_len = stem_len
		_amp = amp
		_freq = freq
		_phase = phase
		global_transform = base
		collision_layer = 2
		collision_mask = 0
		sync_to_physics = true
		var stem := MeshInstance3D.new()
		stem.mesh = MeshLib.stem_mesh(0.12, 0.08, stem_len, 6)
		stem.material_override = stem_mat
		add_child(stem)
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(leaf_w * 0.85, 0.25, leaf_len * 0.9)
		cs.shape = b
		cs.position = Vector3(0, stem_len, 0)
		add_child(cs)
		var leaf := MeshInstance3D.new()
		leaf.mesh = MeshLib.platform_leaf_mesh(leaf_len, leaf_w)
		leaf.position = Vector3(0, stem_len + 0.1, leaf_len * 0.5)
		leaf.material_override = leaf_mat
		add_child(leaf)

	func _physics_process(dt: float) -> void:
		_t += dt
		var a := sin(_t * TAU * _freq + _phase) * _amp
		global_transform = Transform3D(_base.basis * Basis(Vector3.RIGHT, a), _base.origin)


## Hidden permanent health upgrade inside each interior moss cave.
class Upgrade extends Node3D:
	var ball: MossBall
	var dir := Vector3.UP
	var h_hint := 0.0
	var taken := false
	var _t := 0.0
	var _placed := false
	var _mat: StandardMaterial3D
	var _leaf: MeshInstance3D

	func setup(p_ball: MossBall, p_dir: Vector3, h: float) -> void:
		ball = p_ball
		dir = p_dir
		h_hint = h

	func _ready() -> void:
		_mat = StandardMaterial3D.new()
		_mat.albedo_color = Color(0.4, 1.0, 0.9)
		_mat.emission_enabled = true
		_mat.emission = Color(0.35, 1.0, 0.9)
		_mat.emission_energy_multiplier = 3.0
		_leaf = MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.2
		s.height = 0.4
		_leaf.mesh = s
		_leaf.scale = Vector3(0.45, 1.3, 0.7)
		_leaf.material_override = _mat
		_leaf.position = Vector3(0, 0.6, 0)
		add_child(_leaf)
		var l := OmniLight3D.new()
		l.light_color = Color(0.4, 1.0, 0.9)
		l.omni_range = 4.0
		l.light_energy = 1.2
		l.position = Vector3(0, 0.7, 0)
		add_child(l)

	func _process(dt: float) -> void:
		_t += dt
		if not _placed:
			var top := ball.surface_point(dir, h_hint + 1.5)
			var q := PhysicsRayQueryParameters3D.create(top, ball.global_position, 1 | 2)
			var hit := get_world_3d().direct_space_state.intersect_ray(q)
			if not hit.is_empty() or Engine.get_physics_frames() > 2:
				var p: Vector3 = hit.position if not hit.is_empty() else ball.surface_point(dir)
				global_transform = Transform3D(MossBall.frame_at(ball.up_at(p), 0.0), p)
				_placed = true
			return
		if taken:
			return
		_leaf.rotation.y += dt * 1.2
		_leaf.position.y = 0.6 + sin(_t * 2.0) * 0.08
		var pl := Game.inst.player
		if pl.state == "normal" and pl.body_center().distance_to(_leaf.global_position) < 0.9:
			taken = true
			visible = false
			Game.inst.upgrade_collected(self)
