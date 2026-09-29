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
	var _stalk: Node3D
	var _stalk_shape: CollisionShape3D
	var _stalk_radius := 0.0

	func build(p_ball: MossBall, xf: Transform3D, size: Vector3, p_zone: String) -> void:
		ball = p_ball
		zone_id = p_zone
		global_transform = xf
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
		_build_stalk(xf, size)

	## A raised brittle cap stands on a brittle moss stalk rooted in the real ground below (hills
	## included): the formation reaches the ground, collides like it looks, and the whole of it
	## crumbles and regrows together. Without the stalk an elevated cap hung in open water, read
	## as the top of a formation whose lower part was missing, and Gill could walk underneath.
	func _build_stalk(xf: Transform3D, size: Vector3) -> void:
		var up := ball.up_at(xf.origin)
		var ground := ball.surface_point(up)
		var height := (xf.origin - up * size.y * 0.5 - ground).dot(up)
		if height < 0.3:
			return
		var sink := 0.4
		var r_top := size.x * 0.26
		_stalk_radius = size.x * 0.44
		var base_y := -size.y * 0.5 - height - sink
		_stalk_shape = CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = (r_top + _stalk_radius) * 0.5
		cyl.height = height + sink
		_stalk_shape.shape = cyl
		_stalk_shape.position = Vector3(0, base_y + (height + sink) * 0.5, 0)
		add_child(_stalk_shape)
		# Grows from its root (scale.y) when the formation regrows.
		_stalk = Node3D.new()
		_stalk.name = "Stalk"
		_stalk.set_meta("grounded", "brittle-moss stalk")
		_stalk.position = Vector3(0, base_y, 0)
		add_child(_stalk)
		var mi := MeshInstance3D.new()
		mi.mesh = MeshLib.stem_mesh(_stalk_radius, r_top, height + sink + size.y * 0.25, 12)
		mi.material_override = ball.moss_material
		_stalk.add_child(mi)

	## Regrowing waits until Gill is clear of the cap and of the stalk's footprint.
	func _clear_of_player() -> bool:
		var pl := Game.inst.player
		var off := pl.global_position - _home.origin
		if off.length() <= 1.4:
			return false
		if _stalk == null:
			return true
		var up := ball.up_at(_home.origin)
		return (off - up * off.dot(up)).length() > _stalk_radius + 0.6

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
		if Game.paused_for_aquarium():
			return
		_t += dt
		match _state:
			"shaking":
				global_position = _home.origin + Vector3(randf() - 0.5, 0, randf() - 0.5) * 0.06
				if _t > 0.8:
					_state = "gone"
					_t = 0.0
					_shape.disabled = true
					_mesh.visible = false
					if _stalk != null:
						_stalk_shape.disabled = true
						_stalk.visible = false
					global_position = _home.origin
					var up := ball.up_at(global_position)
					for i in 10:
						WaterFX.inst._spawn_puff(global_position + Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * 0.8,
								-up * randf_range(1.0, 3.0), 1.2, randf_range(0.06, 0.12), Color(0.5, 0.48, 0.42, 0.9), 0.8)
			"gone":
				if (_t > 3.5 or restored) and _clear_of_player():
					_state = "regrow"
					_t = 0.0
			"regrow":
				_shape.disabled = false
				_mesh.visible = true
				_mesh.scale.y = minf(1.0, _t / 0.6)
				if _stalk != null:
					_stalk_shape.disabled = false
					_stalk.visible = true
					_stalk.scale.y = minf(1.0, _t / 0.6)
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
		# Collision is the drawn leaf (Expansion 6).
		for shape in MeshLib.leaf_collision_shapes(length, width):
			var cs := CollisionShape3D.new()
			cs.shape = shape
			add_child(cs)
		var mi := MeshInstance3D.new()
		mi.mesh = MeshLib.platform_leaf_mesh(length, width, true)
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
		# Collision is the drawn leaf (Expansion 6), centred on the stalk's top like the leaf.
		for shape in MeshLib.leaf_collision_shapes(leaf_len, leaf_w):
			var cs := CollisionShape3D.new()
			cs.shape = shape
			cs.position = Vector3(0, stem_len + 0.1, leaf_len * 0.5)
			add_child(cs)
		var leaf := MeshInstance3D.new()
		leaf.mesh = MeshLib.platform_leaf_mesh(leaf_len, leaf_w)
		leaf.position = Vector3(0, stem_len + 0.1, leaf_len * 0.5)
		leaf.material_override = leaf_mat
		add_child(leaf)

	func _physics_process(dt: float) -> void:
		if Game.paused_for_aquarium():
			return
		_t += dt
		var a := sin(_t * TAU * _freq + _phase) * _amp
		global_transform = Transform3D(_base.basis * Basis(Vector3.RIGHT, a), _base.origin)


## Hidden permanent health upgrade inside each interior moss cave.
class Upgrade extends Node3D:
	var ball: MossBall
	var dir := Vector3.UP
	var h_hint := 0.0
	## A point on the ledge it rests on (caves), or null: then it drops onto the terrain from h_hint.
	var anchor: Variant = null
	var taken := false
	## "health" (the original caves: +1 gill) or "pearl" (new grottoes: a discovery that refills
	## health; the six gills are already reachable from the original caves).
	var kind := "health"
	var _t := 0.0
	var _placed := false
	var _mat: StandardMaterial3D
	var _leaf: MeshInstance3D

	func setup(p_ball: MossBall, p_dir: Vector3, h: float, p_anchor: Variant = null) -> void:
		ball = p_ball
		dir = p_dir
		h_hint = h
		anchor = p_anchor

	func _ready() -> void:
		_mat = StandardMaterial3D.new()
		var col := Color(1.0, 0.86, 0.74) if kind == "pearl" else Color(0.4, 1.0, 0.9)
		_mat.albedo_color = col
		_mat.emission_enabled = true
		_mat.emission = col
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
			# From just above its ledge when it has one (Expansion 6: in a small grotto a ray from
			# h + 1.5 m over the terrain started inside the dome and found the ceiling).
			var top: Vector3 = (anchor as Vector3) + ball.up_at(anchor) * 0.5 if anchor != null else ball.surface_point(dir, h_hint + 1.5)
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
