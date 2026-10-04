class_name CaveEel
extends Critter
## An eel living in a crevice in a grotto's wall (docs/ECOSYSTEM.md). Hidden, only its eyes glow
## faintly in the dark cleft. When the axolotl comes near, in front of the crevice and in its line
## of sight, the eyes brighten and bubbles rise (the telegraph, 0.9 s); then it strikes out along the
## line it saw him on, up to STRIKE_REACH, and pulls back. It never leaves the crevice and never
## strikes through rock. While it is out it can be swiped; two hits defeat it (a completion entry).

const NOTICE_R := 4.2
const STRIKE_REACH := 2.3
const ALERT_TIME := 0.9
const STRIKE_TIME := 0.22
const HOLD_TIME := 0.18
const RETRACT_TIME := 0.5
const COOLDOWN := 2.5
const CONTACT_R := 0.55
const SEGS := 7

## Crevice mouth on the wall, and the wall's normal into the cave.
var mouth: Vector3
var normal: Vector3
var state := "hidden"
var state_t := 0.0
var ext := 0.0
## How far this strike reaches: STRIKE_REACH, or less if rock or a ledge is closer along the line.
var reach := STRIKE_REACH
var _dir := Vector3.FORWARD
var _hurt := false
var _body_mat: ShaderMaterial
var _segs_mi: MeshInstance3D
var _head: Node3D
var _eye_mat: StandardMaterial3D
var _bubble_t := 0.0


var _probe_from := Vector3.ZERO
var _probe_dir := Vector3.FORWARD
var _probe_len := 10.0


## Lives in the wall found from `from` (inside the cave) along `dir` (see late_place).
func place(p_ball: MossBall, from: Vector3, dir: Vector3, cave_radius: float, seed_v: int) -> void:
	setup(p_ball, "eel", "grotto wall", seed_v)
	hp = 2
	seen_radius = 4.5
	p_ball.add_child(self)
	_probe_from = from
	_probe_dir = dir.normalized()
	_probe_len = cave_radius + 3.0
	mouth = from + _probe_dir * (cave_radius - 1.5)
	normal = -_probe_dir
	global_position = mouth
	_dir = normal
	visible = false


func late_place() -> void:
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(_probe_from, _probe_from + _probe_dir * _probe_len, SOLID_MASK))
	if not hit.is_empty():
		mouth = hit["position"]
	# The wall faces back into the cave (the surface is two-sided, so its reported normal may not).
	normal = -_probe_dir
	global_position = mouth
	_dir = normal
	visible = true
	_build()
	_pose()


func _build() -> void:
	# The crevice (a dark cleft, visible even when the eel hides), the body as one batch of
	# segments, the head, and the glowing eyes (their own material: they brighten as it notices him).
	var up := ball.up_at(mouth)
	var cleft := Node3D.new()
	add_child(cleft)
	cleft.global_transform = Transform3D(Basis(normal.cross(up).normalized(), up, normal).orthonormalized(), mouth - normal * 0.02)
	Critter.part(Critter.sphere(0.3, 10), Critter.mat(Color(0.02, 0.02, 0.02)), cleft, Vector3.ZERO, Vector3(0.9, 1.3, 0.12))
	# One continuous body (Expansion 6: it was a chain of balls), laid along the head-to-tail points by
	# the same body shader as the parasites, in the eel's own mottled olive.
	_body_mat = ShaderMaterial.new()
	_body_mat.shader = Parasite.BODY_SHADER
	_body_mat.set_shader_parameter("noise_tex", Parasite.NOISE)
	# A moray (owner reference photos): dark olive-brown with pale reticulated markings.
	_body_mat.set_shader_parameter("color_a", Color(0.16, 0.14, 0.08))
	_body_mat.set_shader_parameter("color_b", Color(0.22, 0.2, 0.11))
	_body_mat.set_shader_parameter("spot", Color(0.8, 0.74, 0.44))
	_body_mat.set_shader_parameter("spot_lo", 0.47)
	_body_mat.set_shader_parameter("glow_gain", 0.15)
	_body_mat.set_shader_parameter("npts", SEGS + 1)
	var mi := MeshInstance3D.new()
	mi.mesh = Parasite._body_tube()
	mi.material_override = _body_mat
	mi.top_level = true
	mi.custom_aabb = AABB(Vector3.ONE * -4.0, Vector3.ONE * 8.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 60.0
	add_child(mi)
	_segs_mi = mi
	_head = Node3D.new()
	_head.top_level = true
	add_child(_head)
	# A moray's head: a long skull tapering to a blunt snout, the lower jaw hanging a little open
	# over a dark mouth, pale markings round the jaw.
	var hc := Color(0.2, 0.18, 0.1)
	var pale := Color(0.72, 0.66, 0.4)
	var jaw_xf := Transform3D(Basis(Vector3.RIGHT, 0.2).scaled(Vector3(0.78, 0.42, 1.65)), Vector3(0, -0.075, -0.1))
	Critter.part(Critter.merge([
			[Critter.sphere(0.17, 12), hc, Critter.xf(Vector3(0, 0.02, 0.02), Vector3(0.95, 0.85, 1.7))],
			[Critter.sphere(0.1, 10), hc, Critter.xf(Vector3(0, 0.0, -0.24), Vector3(0.9, 0.75, 1.3))],
			[Critter.sphere(0.12, 8), Color(0.08, 0.02, 0.02), Critter.xf(Vector3(0, -0.04, -0.12), Vector3(0.75, 0.3, 1.5))],
			[Critter.sphere(0.13, 10), pale, jaw_xf],
			[Critter.sphere(0.05, 6), pale, Critter.xf(Vector3(0.09, -0.02, -0.06), Vector3(1.0, 0.6, 1.6))],
			[Critter.sphere(0.05, 6), pale, Critter.xf(Vector3(-0.09, -0.02, -0.06), Vector3(1.0, 0.6, 1.6))]]), Critter.vc_mat(), _head)
	_eye_mat = Critter.mat(Color(0.9, 0.95, 0.5), Color(0.8, 1.0, 0.3))
	var eyes := []
	for side in [-1.0, 1.0]:
		eyes.append([Critter.sphere(0.04, 6), Color(1, 1, 1), Critter.xf(Vector3(side * 0.1, 0.1, -0.14))])
	Critter.part(Critter.merge(eyes), _eye_mat, _head)


func tick(dt: float) -> void:
	if defeated or _head == null:
		return
	state_t += dt
	var p := player()
	match state:
		"hidden":
			ext = 0.0
			if state_t > 0.2 and _sees(p):
				_go("alert")
				_dir = _aim(p.body_center())
				Sfx.play("eel_bubbles", mouth)
		"alert":
			_bubble_t -= dt
			if _bubble_t <= 0.0:
				_bubble_t = 0.12
				WaterFX.inst.sparkle(mouth + normal * 0.25 + ball.up_at(mouth) * 0.2, Color(0.8, 0.95, 1.0, 0.7), 4, 0.8, 0.05, 0.9)
			if state_t >= ALERT_TIME:
				_go("strike")
				_hurt = false
				var q := PhysicsRayQueryParameters3D.create(mouth + _dir * 0.2, mouth + _dir * (STRIKE_REACH + 0.2), SOLID_MASK)
				var hit := get_world_3d().direct_space_state.intersect_ray(q)
				reach = STRIKE_REACH if hit.is_empty() else maxf(0.0, (hit["position"] as Vector3).distance_to(mouth) - 0.25)
				Sfx.play("eel_strike", mouth)
		"strike":
			ext = reach * clampf(state_t / STRIKE_TIME, 0.0, 1.0)
			_check_contact(p)
			if state_t >= STRIKE_TIME:
				_go("hold")
		"hold":
			ext = reach
			_check_contact(p)
			if state_t >= HOLD_TIME:
				_go("retract")
		"retract":
			ext = reach * (1.0 - clampf(state_t / RETRACT_TIME, 0.0, 1.0))
			if state_t >= RETRACT_TIME:
				_go("cooldown")
		"cooldown":
			ext = 0.0
			if state_t >= COOLDOWN:
				_go("hidden")
	_pose()


func _go(s: String) -> void:
	state = s
	state_t = 0.0


## The axolotl is near, in front of the crevice and in its line of sight (no rock between).
func _sees(p: Axolotl) -> bool:
	if not player_here():
		return false
	var to := p.body_center() - mouth
	if to.length() > NOTICE_R or to.normalized().dot(normal) < 0.2:
		return false
	return not line_blocked(mouth + normal * 0.25, p.body_center())


## Strike direction toward `target`, kept within 50 degrees of the wall's normal.
func _aim(target: Vector3) -> Vector3:
	var d := (target - mouth).normalized()
	var ang := d.angle_to(normal)
	if ang > deg_to_rad(50.0):
		var axis := normal.cross(d).normalized()
		d = normal.rotated(axis, deg_to_rad(50.0))
	# Never out further than open water allows (the strike stops short of rock).
	return d


func _check_contact(p: Axolotl) -> void:
	if _hurt or not player_here():
		return
	if _dist_to_body(p.body_center()) < CONTACT_R:
		_hurt = true
		strike_player(mouth)


func _dist_to_body(pt: Vector3) -> float:
	var a := mouth
	var b := mouth + _dir * ext
	var ab := b - a
	var k := clampf((pt - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return pt.distance_to(a + ab * k)


func _pose() -> void:
	if _head == null:
		return
	var up := ball.up_at(mouth)
	var tail := mouth - normal * 0.5
	var head := mouth + _dir * ext - normal * (0.12 if ext < 0.05 else 0.0)
	# Head first, then back into the crevice (the body shader runs head to tail).
	var pts := PackedVector4Array()
	var ups := PackedVector4Array()
	pts.resize(Parasite.MAX_SEGS)
	ups.resize(Parasite.MAX_SEGS)
	for i in SEGS + 1:
		var k := 1.0 - float(i) / SEGS
		var p := tail.lerp(head, k)
		# A sideways ripple along the body while it is out.
		p += _dir.cross(up).normalized() * sin(k * 9.0 - state_t * 12.0) * 0.06 * clampf(ext, 0.0, 1.0) * (1.0 - k * 0.6)
		pts[i] = Vector4(p.x, p.y, p.z, 0.15 * lerpf(1.05, 0.85, float(i) / SEGS))
		ups[i] = Vector4(up.x, up.y, up.z, 0.0)
	_segs_mi.global_position = head
	_body_mat.set_shader_parameter("pts", pts)
	_body_mat.set_shader_parameter("ups", ups)
	_segs_mi.visible = ext > 0.05 and not defeated
	var look := _dir if ext > 0.05 else normal
	_head.global_transform = Transform3D(Basis(look.cross(up).normalized(), up, -look).orthonormalized(), head)
	_head.visible = not defeated
	var glow := 0.25
	if state == "alert":
		glow = 1.0 + 0.8 * sin(state_t * 30.0)
	elif state in ["strike", "hold", "retract"]:
		glow = 1.6
	_eye_mat.emission_energy_multiplier = glow


func is_hidden() -> bool:
	return defeated or state in ["hidden", "cooldown"]


func discover_point() -> Vector3:
	return mouth + _dir * ext


func hittable() -> bool:
	return not defeated and ext > 0.6


func closest_body_point(pt: Vector3) -> Vector3:
	var a := mouth
	var b := mouth + _dir * ext
	var ab := b - a
	var k := clampf((pt - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return a + ab * k


func body_extent() -> float:
	return 0.18


func hit(stages: int, _from_pos: Vector3) -> bool:
	if not hittable():
		return false
	hp -= stages
	WaterFX.inst.sparkle(mouth + _dir * ext, Color(0.8, 1.0, 0.7, 0.9), 10, 1.2, 0.06, 0.6)
	if hp <= 0:
		defeated = true
		ext = 0.0
		_pose()
		Game.inst.critter_defeated(self)
		return true
	# Stung: it pulls straight back in and stays hidden longer.
	_go("retract")
	state_t = RETRACT_TIME * (1.0 - ext / maxf(reach, 0.01))
	return true


func restore_defeated() -> void:
	defeated = true
	ext = 0.0
	_pose()
