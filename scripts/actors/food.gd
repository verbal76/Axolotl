class_name Food
extends Node3D
## Food organisms. DRIFTER (brine-shrimp-like) rides currents; DARTER (water-flea-like)
## hops away from an approaching axolotl then pauses; BURROWER (worm) peeks from the moss,
## retreats when disturbed, and re-emerges later.

enum Type { DRIFTER, DARTER, BURROWER }

var type: int = Type.DRIFTER
var ball: MossBall
var region_dir := Vector3.UP
var region_radius := deg_to_rad(20.0)
var state := "arrive"      # arrive idle dart pause | hidden emerging exposed retreating | eaten
var vel := Vector3.ZERO
var hole: Dictionary = {}
var expose := 0.0          # burrower: 0 hidden .. 1 fully exposed (partial = 0.5)
var _t := 0.0
var _cd := 0.0
var _dart_dir := Vector3.ZERO
var _vis: Node3D
var _parts: Array[Node3D] = []
var _hover := 1.0
var _hole_pos := Vector3.ZERO
var _hole_up := Vector3.UP


func setup(p_ball: MossBall, p_type: int, pos: Vector3, p_region_dir: Vector3, p_region_deg: float) -> void:
	ball = p_ball
	type = p_type
	region_dir = p_region_dir.normalized()
	region_radius = deg_to_rad(p_region_deg)
	position = pos
	_hover = randf_range(0.6, 1.8)


func setup_burrower(p_ball: MossBall, p_hole: Dictionary) -> void:
	ball = p_ball
	type = Type.BURROWER
	hole = p_hole
	hole["occupied"] = true
	state = "hidden"
	_cd = randf_range(0.2, 1.5)


func _ready() -> void:
	_vis = Node3D.new()
	add_child(_vis)
	match type:
		Type.DRIFTER: _build_drifter()
		Type.DARTER: _build_darter()
		Type.BURROWER: _build_burrower()


func _mat(c: Color, em := 0.25) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.4
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = em
	m.rim_enabled = true
	m.rim = 0.6
	return m


func _ball_mesh(r: float, m: Material, p: Node3D, pos: Vector3, scl: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 8
	s.rings = 4
	mi.mesh = s
	mi.material_override = m
	mi.position = pos
	mi.scale = scl
	mi.visibility_range_end = 35.0
	p.add_child(mi)
	return mi


func _build_drifter() -> void:
	var m := _mat(Color(1.0, 0.62, 0.42), 0.35)
	for i in 4:
		_ball_mesh(0.045 - i * 0.008, m, _vis, Vector3(0, 0, i * 0.06), Vector3(1, 1, 1.5))
	for i in 5:
		var leg := Node3D.new()
		leg.position = Vector3(0, -0.02, 0.02 + i * 0.03)
		_vis.add_child(leg)
		_ball_mesh(0.01, m, leg, Vector3(0.05, -0.02, 0), Vector3(4, 0.6, 1.2))
		_ball_mesh(0.01, m, leg, Vector3(-0.05, -0.02, 0), Vector3(4, 0.6, 1.2))
		_parts.append(leg)
	var eye := _mat(Color(0.05, 0.05, 0.05), 0.0)
	_ball_mesh(0.012, eye, _vis, Vector3(0.03, 0.02, -0.03), Vector3.ONE)
	_ball_mesh(0.012, eye, _vis, Vector3(-0.03, 0.02, -0.03), Vector3.ONE)


func _build_darter() -> void:
	var shell := _mat(Color(0.75, 0.9, 0.55), 0.3)
	_ball_mesh(0.09, shell, _vis, Vector3.ZERO, Vector3(0.8, 1.0, 1.0))
	var inner := _mat(Color(1.0, 0.5, 0.3), 0.5)
	_ball_mesh(0.035, inner, _vis, Vector3(0, 0.0, 0.02), Vector3.ONE)
	_ball_mesh(0.018, _mat(Color(0.05, 0.05, 0.05), 0.0), _vis, Vector3(0, 0.03, -0.08), Vector3.ONE)
	for side in [-1.0, 1.0]:
		var ant := Node3D.new()
		ant.position = Vector3(side * 0.03, 0.05, -0.05)
		_vis.add_child(ant)
		_ball_mesh(0.012, shell, ant, Vector3(side * 0.07, 0.04, 0), Vector3(6, 0.8, 0.8))
		_parts.append(ant)


func _build_burrower() -> void:
	var m := _mat(Color(0.95, 0.45, 0.5), 0.3)
	for i in 7:
		_ball_mesh(0.05, m, _vis, Vector3(0, i * 0.07, 0), Vector3(1, 1.3, 1))
		_parts.append(_vis.get_child(_vis.get_child_count() - 1))
	_ball_mesh(0.014, _mat(Color(0.05, 0.05, 0.05), 0.0), _vis, Vector3(0.03, 0.47, -0.03), Vector3.ONE)
	_ball_mesh(0.014, _mat(Color(0.05, 0.05, 0.05), 0.0), _vis, Vector3(-0.03, 0.47, -0.03), Vector3.ONE)


func is_catchable() -> bool:
	match type:
		Type.BURROWER:
			return (state == "exposed" or state == "emerging" or state == "retreating") and expose > 0.25
		_:
			return state != "eaten"


func catch_point() -> Vector3:
	if type == Type.BURROWER:
		return _hole_pos + _hole_up * (0.2 + 0.3 * expose)
	return global_position


func heal_amount(max_health: int) -> int:
	match type:
		Type.DRIFTER: return 1
		Type.DARTER: return 2
	return max_health


func eaten() -> void:
	state = "eaten"
	if type == Type.BURROWER:
		hole["occupied"] = false
	queue_free()


func _physics_process(dt: float) -> void:
	var g := Game.inst
	if g == null or g.player.ball != ball:
		return
	_t += dt
	_cd = maxf(0.0, _cd - dt)
	match type:
		Type.DRIFTER: _update_drifter(dt)
		Type.DARTER: _update_darter(dt, g.player)
		Type.BURROWER: _update_burrower(dt, g.player)


func _ground_height(up: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(global_position + up * 0.5, global_position - up * 6.0, 1 | 2)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return (global_position - ball.global_position).length() - ball.radius
	return global_position.distance_to(hit.position)


func _keep_in_region(up: Vector3, dt: float, strength: float) -> void:
	var ang := up.angle_to(region_dir)
	if ang > region_radius:
		var back := ball.surface_point(region_dir, 1.0) - global_position
		vel += (back - up * back.dot(up)).normalized() * strength * dt


func _update_drifter(dt: float) -> void:
	var up := ball.up_at(global_position)
	var h := _ground_height(up)
	if state == "arrive":
		# Drifts in from open water, settling toward the moss.
		vel += -up * 0.6 * dt
		if h < 2.5:
			state = "idle"
	else:
		vel += up * (_hover - h) * 0.8 * dt
	vel += ball.current_at(global_position) * 0.5 * dt
	vel += WaterFX.inst.push_at(global_position) * 4.0 * dt
	vel += Vector3(sin(_t * 2.1), sin(_t * 1.3), cos(_t * 1.7)) * 0.15 * dt
	_keep_in_region(up, dt, 0.4)
	vel = vel.limit_length(2.5)
	vel *= 1.0 - 0.5 * dt
	global_position += vel * dt
	_orient(vel, up)
	for i in _parts.size():
		_parts[i].rotation.x = sin(_t * 14.0 + i * 0.9) * 0.6


func _update_darter(dt: float, pl: Axolotl) -> void:
	var up := ball.up_at(global_position)
	var h := _ground_height(up)
	var d := pl.global_position.distance_to(global_position)
	match state:
		"arrive":
			vel += -up * 1.2 * dt
			if h < 2.0:
				state = "idle"
		"idle":
			vel += up * (_hover - h) * 1.0 * dt
			vel += WaterFX.inst.push_at(global_position) * 2.0 * dt
			vel *= 1.0 - 1.5 * dt
			var pl_speed := pl.velocity.length()
			if d < 3.3 and _cd <= 0.0 and (pl_speed > 1.0 or pl.lunge_t >= 0.0):
				# Senses the axolotl: sudden short hop, then a pause.
				var away := global_position - pl.global_position
				away -= up * away.dot(up)
				var side := away.cross(up).normalized() * randf_range(-1.0, 1.0)
				_dart_dir = (away.normalized() * 0.8 + side * 0.6 + up * randf_range(-0.1, 0.3)).normalized()
				state = "dart"
				_t = 0.0
				Sfx.play("dart", global_position, -10.0)
		"dart":
			vel = _dart_dir * 13.0
			if _t > 0.18:
				state = "pause"
				_t = 0.0
				vel *= 0.1
		"pause":
			vel *= 1.0 - 4.0 * dt
			if _t > 0.9:
				state = "idle"
				_cd = 0.3
	_keep_in_region(up, dt, 1.0)
	global_position += vel * dt
	_orient(pl.global_position - global_position, up)
	for i in _parts.size():
		_parts[i].rotation.z = sin(_t * (30.0 if state == "dart" else 6.0)) * 0.5 * (i * 2 - 1)


func _update_burrower(dt: float, pl: Axolotl) -> void:
	if _hole_pos == Vector3.ZERO:
		# Burrow holes are in the moss itself (never on top of plants above them).
		var dir: Vector3 = hole["dir"]
		_hole_pos = ball.surface_point(dir, hole.get("h", 0.0))
		_hole_up = ball.up_at(_hole_pos)
		global_transform = Transform3D(MossBall.frame_at(_hole_up, randf() * 360.0), _hole_pos - _hole_up * 0.5)
	var d := pl.global_position.distance_to(_hole_pos)
	var disturbed := d < 2.6 and (pl.velocity.length() > 1.5 or pl.lunge_t >= 0.0) or WaterFX.inst.push_at(_hole_pos).length() > 0.9
	match state:
		"hidden":
			expose = move_toward(expose, 0.0, dt * 3.0)
			if _cd <= 0.0 and d > 3.2:
				state = "emerging"
		"emerging":
			expose = move_toward(expose, 0.5, dt * 0.6)
			if expose >= 0.5:
				state = "exposed"
			if disturbed:
				state = "retreating"
				_t = 0.0
		"exposed":
			expose = 0.5 + sin(_t * 1.5) * 0.06
			if disturbed:
				state = "retreating"
				_t = 0.0
				Sfx.play("burrow", _hole_pos, -8.0)
		"retreating":
			# Short catch window while it pulls back into the moss.
			expose = move_toward(expose, 0.0, dt * 0.9)
			if expose <= 0.0:
				state = "hidden"
				_cd = randf_range(4.0, 7.0)
	global_position = _hole_pos - _hole_up * (0.5 - expose * 0.9)
	_vis.visible = expose > 0.02
	for i in _parts.size():
		_parts[i].position.x = sin(_t * 2.0 + i * 0.6) * 0.02 * i


func _orient(dir: Vector3, up: Vector3) -> void:
	var f := dir - up * dir.dot(up)
	if f.length() < 0.01:
		return
	f = f.normalized()
	global_basis = Basis(f.cross(up).normalized(), up, -f)
