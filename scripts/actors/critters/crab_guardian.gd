class_name CrabGuardian
extends Critter
## Territorial crab guarding a grotto's mouth (docs/ECOSYSTEM.md). It rests at its post. When the
## axolotl enters its territory it turns to face him, raises both claws and clacks (the warning).
## If he stays close after the warning it charges sideways across the ground; only the charge hurts.
## It never leaves its territory and walks back to its post afterwards, when it is briefly
## wary rather than aggressive. Three swipes defeat it; that stays so (a completion entry).

const WARN_R := 5.0
const CHARGE_R := 3.8
const TERRITORY := 6.0
const WARN_TIME := 1.2
const CHARGE_SPEED := 4.5
const CHARGE_TIME := 1.1
const CONTACT_R := 0.75

var post: Vector3
var facing := Vector3.FORWARD
var state := "rest"
var state_t := 0.0
var wary_t := 0.0
var _vel := Vector3.ZERO
var _rig: Node3D
var _claws: Array[Node3D] = []
var _legs: Array[Node3D] = []
var _shell_mat: StandardMaterial3D
var _walk := 0.0


func place(p_ball: MossBall, at: Vector3, face: Vector3, seed_v: int) -> void:
	setup(p_ball, "crab", "grotto mouth", seed_v)
	hp = 3
	seen_radius = 7.0
	p_ball.add_child(self)
	post = at
	var up := ball.up_at(at)
	facing = (face - up * face.dot(up)).normalized()
	_build()
	global_position = at


func late_place() -> void:
	_snap(post)
	post = global_position


func _build() -> void:
	# Merged meshes: the body, each claw arm (they pivot), and the legs.
	_rig = Node3D.new()
	add_child(_rig)
	_shell_mat = Critter.vc_mat().duplicate()
	var shell := Color(0.78, 0.32, 0.18)
	var under := Color(0.95, 0.8, 0.62)
	var dark := Color(0.12, 0.06, 0.05)
	var body := [[Critter.sphere(0.5, 14), shell, Critter.xf(Vector3(0, 0.3, 0), Vector3(1.15, 0.45, 0.8))],
			[Critter.sphere(0.45, 10), under, Critter.xf(Vector3(0, 0.2, 0), Vector3(1.05, 0.3, 0.72))]]
	var legs := []
	for side in [-1.0, 1.0]:
		body.append([Critter.sphere(0.07, 8), dark, Critter.xf(Vector3(side * 0.16, 0.55, -0.3))])
		body.append([Critter.sphere(0.03, 6), shell, Critter.xf(Vector3(side * 0.16, 0.46, -0.3), Vector3(1, 3, 1))])
		var shoulder := Node3D.new()
		shoulder.position = Vector3(side * 0.42, 0.32, -0.3)
		_rig.add_child(shoulder)
		Critter.part(Critter.merge([[Critter.sphere(0.12, 8), shell, Critter.xf(Vector3(side * 0.12, 0, -0.18), Vector3(0.8, 0.8, 1.6))],
				[Critter.sphere(0.2, 10), shell, Critter.xf(Vector3(side * 0.2, 0.02, -0.46), Vector3(0.9, 0.7, 1.3))],
				[Critter.sphere(0.1, 8), under, Critter.xf(Vector3(side * 0.28, -0.04, -0.66), Vector3(0.6, 0.5, 1.4))]]), _shell_mat, shoulder)
		_claws.append(shoulder)
		for k in 3:
			legs.append([Critter.sphere(0.05, 6), shell, Critter.xf(Vector3(side * 0.68, 0.16, -0.12 + k * 0.2), Vector3(3.2, 0.9, 0.9))])
	Critter.part(Critter.merge(body), _shell_mat, _rig)
	var leg_node := Node3D.new()
	_rig.add_child(leg_node)
	Critter.part(Critter.merge(legs), _shell_mat, leg_node)
	_legs.append(leg_node)


func _snap(pos: Vector3) -> void:
	var hit := ground_under(pos, GROUND_MASK)
	var p: Vector3 = hit["position"] if hit else ball.surface_point(ball.up_at(pos))
	var up := ball.up_at(p)
	facing = (facing - up * facing.dot(up)).normalized()
	global_transform = Transform3D(Basis(facing.cross(up).normalized(), up, -facing).orthonormalized(), p)


func tick(dt: float) -> void:
	if defeated:
		return
	state_t += dt
	wary_t = maxf(0.0, wary_t - dt)
	var p := player()
	var here := player_here()
	var to: Vector3 = (p.body_center() - global_position) if p else Vector3.ZERO
	var up := ball.up_at(global_position)
	var flat := to - up * to.dot(up)
	var dist := flat.length()
	var near_post := p != null and (p.global_position - post).length() < WARN_R + 0.5
	match state:
		"rest":
			_vel = Vector3.ZERO
			# Small idle shuffles at the post.
			if (global_position - post).length() > 0.5:
				_move_toward(post, 1.2, dt)
			if here and wary_t <= 0.0 and dist < WARN_R and near_post and absf(to.dot(up)) < 2.0 and not line_blocked(global_position + up * 0.4, p.body_center()):
				_go("warn")
				Sfx.play("crab_clack", global_position)
		"warn":
			_turn_to(flat, dt, 8.0)
			if not here or dist > WARN_R + 0.8:
				_go("rest")
			elif state_t >= WARN_TIME:
				if dist < CHARGE_R:
					_go("charge")
					_vel = flat.normalized() * CHARGE_SPEED
					Sfx.play("crab_skitter", global_position)
				else:
					_go("rest")
					wary_t = 0.6
		"charge":
			var next := global_position + _vel * dt
			if (next - post).length() > TERRITORY or state_t > CHARGE_TIME or _blocked(_vel):
				_go("retreat")
			else:
				_snap(next)
			if here and p.body_center().distance_to(global_position + up * 0.3) < CONTACT_R + 0.3:
				strike_player(global_position)
				_go("retreat")
		"retreat":
			_move_toward(post, 2.2, dt)
			if (global_position - post).length() < 0.4 or state_t > 4.0:
				_go("rest")
				wary_t = 1.2
		"stunned":
			if state_t > 0.7:
				_go("retreat")
	_animate(dt)


func _go(s: String) -> void:
	state = s
	state_t = 0.0


func _move_toward(target: Vector3, speed: float, dt: float) -> void:
	var up := ball.up_at(global_position)
	var d := target - global_position
	d -= up * d.dot(up)
	if d.length() < 0.05:
		return
	_walk += dt * speed * 6.0
	_snap(global_position + d.normalized() * minf(d.length(), speed * dt))


func _blocked(v: Vector3) -> bool:
	var up := ball.up_at(global_position)
	var from := global_position + up * 0.35
	return line_blocked(from, from + v.normalized() * 0.7)


func _turn_to(flat: Vector3, dt: float, rate: float) -> void:
	if flat.length() < 0.01:
		return
	facing = facing.slerp(flat.normalized(), clampf(dt * rate, 0.0, 1.0)).normalized()
	_snap(global_position)


func _animate(dt: float) -> void:
	var raise := 1.0 if state in ["warn", "charge"] else 0.0
	for i in _claws.size():
		var c: Node3D = _claws[i]
		var target := -1.1 * raise + 0.08 * sin(state_t * 14.0 + i) * raise
		c.rotation.x = lerpf(c.rotation.x, target, clampf(dt * 10.0, 0.0, 1.0))
	if state in ["charge", "retreat"]:
		_walk += dt * 18.0
	for i in _legs.size():
		(_legs[i] as Node3D).rotation.y = sin(_walk) * 0.12
		(_legs[i] as Node3D).position.y = absf(sin(_walk * 2.0)) * 0.03
	_shell_mat.albedo_color = Color(1.6, 1.3, 1.2) if state == "stunned" else Color(1, 1, 1)


func wake_points() -> Array:
	if defeated or state == "rest":
		return []
	var up := ball.up_at(global_position)
	return [[global_position + up * 0.2, 0.55, _vel, 0.5]]


func hittable() -> bool:
	return not defeated


func closest_body_point(_p: Vector3) -> Vector3:
	return global_position + ball.up_at(global_position) * 0.3


func body_extent() -> float:
	return 0.55


func hit(stages: int, from_pos: Vector3) -> bool:
	if defeated:
		return false
	hp -= stages
	WaterFX.inst.sparkle(global_position + ball.up_at(global_position) * 0.4, Color(1.0, 0.7, 0.5, 0.9), 10, 1.4, 0.06, 0.6)
	if hp <= 0:
		defeated = true
		Game.inst.critter_defeated(self)
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector3(1.0, 0.1, 1.0), 0.5)
		tw.tween_callback(func(): visible = false)
		return true
	# Knocked back a step and stunned for a moment.
	var up := ball.up_at(global_position)
	var away := global_position - from_pos
	away -= up * away.dot(up)
	_snap(global_position + away.normalized() * 0.6)
	_vel = Vector3.ZERO
	_go("stunned")
	return true


func restore_defeated() -> void:
	super.restore_defeated()
	state = "rest"
