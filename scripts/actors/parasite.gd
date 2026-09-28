class_name Parasite
extends Node3D
## Invasive aquatic microparasite. Crawls on moss (and plants), grazes inside its home
## area, attacks the axolotl with readable telegraphs, and shows its remaining health only
## through colour: damage drains stolen vitality from the head toward the rear.

const SHADER := preload("res://shaders/parasite.gdshader")
const BODY_SHADER := preload("res://shaders/parasite_body.gdshader")
const MAX_SEGS := 12
## The shared body tube (rings x sides), laid along the segments by BODY_SHADER.
static var _tube: ArrayMesh
const NOISE := preload("res://assets/textures/noise_rgb.png")

enum Kind { SMALL = 1, MEDIUM = 2, LARGE = 3 }

var kind: int = Kind.SMALL
var ball: MossBall
var zone_id := ""
var hp := 1
var max_hp := 1
var home_dir := Vector3.UP
var home_radius := deg_to_rad(9.0)
var spawn_dir := Vector3.UP
var spawn_h := 0.0

var state := "init"   # init graze chase windup attack recover knocked flung dying drifting gone
var state_t := 0.0
## Simulated time for cosmetic motion (never wall-clock: segment positions feed hit tests).
var _clock := 0.0
var heading := Vector3.FORWARD
var up := Vector3.UP
var vel := Vector3.ZERO
var seg_count := 3
var seg_radius := 0.12
var spacing := 0.2
var speed := 2.4
var attack_reach := 1.4
var windup_time := 0.45
var lunge_dist := 1.2
var hit_cd := 0.0
## Seconds it holds off attacking after the bloom's pulse startled it (it can still be hit).
var _shaken := 0.0
var standing_on: Node = null
var _attack_from := Vector3.ZERO
var _attack_dir := Vector3.ZERO
var _graze_target := Vector3.ZERO
var _graze_t := 0.0
var _latched := 0.0
var _gray := 0.0
var _gray_target := 0.0
var _flash := 0.0
var _windup_v := 0.0
var _trail: Array[Vector3] = []
var _trail_up: Array[Vector3] = []
## Segment anchors (not drawn: the body is one continuous tube, `_body`); the head's carries the
## eyes and mandibles, the others the legs.
var _segs: Array[MeshInstance3D] = []
var _mat: ShaderMaterial
var _body: MeshInstance3D
var _body_mat: ShaderMaterial
var _spin := Vector3.ZERO
var _drift_t := 0.0
var _ground_offset := 0.1
var _pushed := Vector3.ZERO
## Body wave (see _update_segments): phase advances with distance travelled, so the motion is the
## same at any frame rate; amplitude follows how fast the head is really moving.
var _wave_phase := 0.0
var _wave_amp := 0.0
var _last_head := Vector3.ZERO


func setup(p_ball: MossBall, p_kind: int, p_zone: String, dir: Vector3, home_deg := 9.0, h := 0.0) -> void:
	ball = p_ball
	kind = p_kind
	zone_id = p_zone
	hp = kind
	max_hp = kind
	spawn_dir = dir.normalized()
	spawn_h = h
	home_dir = spawn_dir
	home_radius = deg_to_rad(home_deg)
	match kind:
		Kind.SMALL:
			seg_count = 3; seg_radius = 0.13; speed = 2.6; attack_reach = 1.5; windup_time = 0.5; lunge_dist = 1.3
		Kind.MEDIUM:
			seg_count = 6; seg_radius = 0.17; speed = 2.0; attack_reach = 1.8; windup_time = 0.6; lunge_dist = 1.7
		Kind.LARGE:
			seg_count = 9; seg_radius = 0.24; speed = 1.6; attack_reach = 3.2; windup_time = 0.9; lunge_dist = 3.3
	spacing = seg_radius * 1.45
	_ground_offset = seg_radius * 0.85
	ball.register_event(zone_id)


func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("noise_tex", NOISE)
	var palettes := [[Color(0.95, 0.2, 0.62), Color(1.0, 0.62, 0.12), Color(0.5, 1.0, 0.3)],
			[Color(0.7, 0.15, 0.95), Color(0.2, 0.9, 0.8), Color(1.0, 0.9, 0.2)],
			[Color(1.0, 0.35, 0.1), Color(0.95, 0.1, 0.45), Color(0.3, 0.9, 1.0)]]
	var p: Array = palettes[kind - 1]
	_body_mat = ShaderMaterial.new()
	_body_mat.shader = BODY_SHADER
	_body_mat.set_shader_parameter("noise_tex", NOISE)
	for m in [_mat, _body_mat]:
		m.set_shader_parameter("color_a", p[0])
		m.set_shader_parameter("color_b", p[1])
		m.set_shader_parameter("spot", p[2])
	_body_mat.set_shader_parameter("npts", seg_count)
	for i in seg_count:
		var mi := MeshInstance3D.new()
		mi.set_instance_shader_parameter("seg_t", (float(i) + 0.5) / seg_count)
		mi.top_level = true
		mi.scale = Vector3(1.0, 1.0, 1.35)
		add_child(mi)
		_segs.append(mi)
	_body = MeshInstance3D.new()
	_body.mesh = _body_tube()
	_body.material_override = _body_mat
	_body.top_level = true
	var ext := spacing * seg_count + seg_radius * 4.0 + 1.0
	_body.custom_aabb = AABB(Vector3(-ext, -ext, -ext), Vector3(ext, ext, ext) * 2.0)
	_body.visibility_range_end = 80.0
	add_child(_body)
	# Head details: beady eyes and mandibles.
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.05, 0.05, 0.05)
	eye_mat.roughness = 0.2
	for side in [-1.0, 1.0]:
		var e := MeshInstance3D.new()
		var es := SphereMesh.new()
		es.radius = seg_radius * 0.22
		es.height = seg_radius * 0.44
		es.radial_segments = 8
		es.rings = 4
		e.mesh = es
		e.material_override = eye_mat
		e.position = Vector3(side * seg_radius * 0.55, seg_radius * 0.45, -seg_radius * 0.6)
		_segs[0].add_child(e)
		var m := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = seg_radius * 0.18
		cm.height = seg_radius * 0.9
		cm.radial_segments = 6
		m.mesh = cm
		m.material_override = _mat
		m.set_instance_shader_parameter("seg_t", 0.02)
		m.position = Vector3(side * seg_radius * 0.35, -seg_radius * 0.2, -seg_radius * 1.1)
		m.rotation = Vector3(-PI / 2 + 0.3, 0, side * -0.4)
		m.name = "Mandible"
		_segs[0].add_child(m)
	# Tiny bristly legs on larger bodies, merged into one mesh per segment.
	if kind > Kind.SMALL:
		var leg := CylinderMesh.new()
		leg.top_radius = 0.0
		leg.bottom_radius = seg_radius * 0.12
		leg.height = seg_radius * 1.2
		leg.radial_segments = 4
		for i in range(1, seg_count - 1):
			var parts := []
			for side in [-1.0, 1.0]:
				parts.append([leg, Transform3D(Basis.from_euler(Vector3(0, 0, side * 1.1)), Vector3(side * seg_radius * 0.8, -seg_radius * 0.35, 0))])
			var l := MeshInstance3D.new()
			l.mesh = MeshLib.merge(parts)
			l.material_override = _mat
			l.set_instance_shader_parameter("seg_t", (float(i) + 0.5) / seg_count)
			l.visibility_range_end = 40.0
			_segs[i].add_child(l)
	for sgi in _segs:
		for c in sgi.get_children():
			if c is GeometryInstance3D:
				c.visibility_range_end = 40.0


## Colour state on the body and its appendages: grey front (0..1, head to rear), hit flash, and
## the wind-up glow.
func set_look(gray: float, flash_v: float, windup_v: float) -> void:
	for m in [_mat, _body_mat]:
		m.set_shader_parameter("gray_front", gray)
		m.set_shader_parameter("flash", flash_v)
		m.set_shader_parameter("windup", windup_v)


## The shared body tube: rings along UV.y (head 0 .. tail 1, plus the rounded caps the shader
## adds beyond both ends), sides round UV.x. Positions are placed entirely by the shader.
static func _body_tube() -> ArrayMesh:
	if _tube != null:
		return _tube
	var rings := 34
	var sides := 10
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var nrm := PackedVector3Array()
	for j in rings:
		for k in sides + 1:
			verts.append(Vector3(0, 0, float(j) * 0.01))
			uvs.append(Vector2(float(k) / sides, float(j) / (rings - 1)))
			nrm.append(Vector3.UP)
	var idx := PackedInt32Array()
	for j in rings - 1:
		for k in sides:
			var a := j * (sides + 1) + k
			var b := a + 1
			var c := a + sides + 1
			var d := c + 1
			idx.append_array([a, c, b, b, c, d])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	_tube = ArrayMesh.new()
	_tube.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return _tube


func is_alive() -> bool:
	return hp > 0


## Continuing a saved run: this parasite was already cleared. Gone at once, no effects.
func restore_cleared() -> void:
	hp = 0
	state = "gone"
	visible = false
	set_physics_process(false)


func head_pos() -> Vector3:
	return global_position


## Closest body point to `p` (for hit tests).
func closest_body_point(p: Vector3) -> Vector3:
	var best := global_position
	var bd := INF
	for s in _segs:
		var d := s.global_position.distance_squared_to(p)
		if d < bd:
			bd = d
			best = s.global_position
	return best


func body_extent() -> float:
	return seg_radius


# --- Update ------------------------------------------------------------------------------

func _physics_process(dt: float) -> void:
	if state == "gone":
		return
	var g := Game.inst
	if state == "init":
		_init_on_ground()
		return
	# Parasites on other moss balls sleep (they don't respawn and keep their state).
	if state != "drifting" and g.player.ball != ball:
		return
	state_t += dt
	hit_cd = maxf(0.0, hit_cd - dt)
	_shaken = maxf(0.0, _shaken - dt)
	_flash = maxf(0.0, _flash - dt * 3.0)
	_gray = move_toward(_gray, _gray_target, dt * 1.6)
	var target_windup := 1.0 if state == "windup" else 0.0
	_windup_v = move_toward(_windup_v, target_windup, dt * 4.0)
	set_look(_gray, _flash, _windup_v * (0.6 + 0.4 * sin(state_t * 30.0)))

	match state:
		"graze", "chase":
			_update_crawl(dt, g.player)
		"windup":
			_face(_attack_dir, dt * 10.0)
			_snap_ground()
			if state_t >= windup_time:
				_set_state("attack")
				_attack_from = global_position
				Sfx.play("parasite_snap", global_position, -2.0)
		"attack":
			var k := minf(1.0, state_t / 0.22)
			var p := _attack_from + _attack_dir * lunge_dist * sin(k * PI * 0.5)
			global_position = p
			_snap_ground()
			var pl: Axolotl = g.player
			if pl.state == "normal" and pl.body_center().distance_to(global_position + up * seg_radius) < 0.55 + seg_radius:
				pl.take_damage(1, global_position)
				if kind == Kind.SMALL:
					_latched = 0.45
				_set_state("recover")
			elif k >= 1.0:
				_set_state("recover")
		"recover":
			if _latched > 0.0:
				_latched -= dt
				var pl: Axolotl = g.player
				global_position = pl.body_center() + pl.up * 0.15 - pl.facing * 0.1
				if _latched <= 0.0:
					_snap_ground()
			else:
				_snap_ground()
			if state_t >= (1.0 if kind == Kind.LARGE else 0.7):
				_set_state("graze")
		"knocked":
			global_position += vel * dt
			vel = vel.move_toward(Vector3.ZERO, dt * 8.0)
			_snap_ground()
			if state_t > 0.4:
				_set_state("graze")
		"flung":
			_update_flung(dt)
		"dying":
			_snap_ground()
			if state_t > 0.55:
				_detach()
		"drifting":
			_update_drift(dt)
	_update_segments(dt)


func _init_on_ground() -> void:
	up = spawn_dir
	var top := ball.surface_point(spawn_dir, spawn_h + 3.0)
	var q := PhysicsRayQueryParameters3D.create(top, ball.global_position, 1 | 2)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		global_position = ball.surface_point(spawn_dir, _ground_offset)
	else:
		global_position = hit.position + up * _ground_offset
		standing_on = hit.collider
	heading = MossBall.frame_at(up, randf() * 360.0).z * -1.0
	for i in 12:
		_trail.push_back(global_position + heading * -spacing * i * 0.5)
		_trail_up.push_back(up)
	state = "graze"
	_graze_target = global_position
	# Laid out where it is at once (a parasite on another ball sleeps until the axolotl arrives).
	_update_segments(0.0)


func _set_state(s: String) -> void:
	state = s
	state_t = 0.0


func _update_crawl(dt: float, pl: Axolotl) -> void:
	var to_player := pl.global_position - global_position
	var d := to_player.length()
	var player_here := pl.ball == ball and pl.state == "normal"
	var in_home := _angle_from_home(pl.global_position) < home_radius * 1.7
	var aggro := 6.5 if kind != Kind.LARGE else 7.5
	if player_here and d < aggro and in_home and absf(to_player.dot(up)) < 2.2:
		if state != "chase":
			_set_state("chase")
	elif state == "chase":
		_set_state("graze")
	var dir: Vector3
	var spd := speed
	if state == "chase":
		dir = to_player - up * to_player.dot(up)
		if d < attack_reach and hit_cd <= 0.0 and _shaken <= 0.0:
			_attack_dir = dir.normalized()
			_set_state("windup")
			Sfx.play("parasite_windup", global_position, -4.0)
			return
		if d < attack_reach * 0.8:
			spd = 0.0
	else:
		spd = speed * 0.35
		_graze_t -= dt
		if _graze_t <= 0.0 or global_position.distance_to(_graze_target) < 0.4:
			_graze_t = randf_range(1.5, 3.5)
			var b := MossBall.frame_at(home_dir, randf() * 360.0)
			var a := randf() * home_radius * 0.8
			var gd := home_dir.rotated(b.x, a).rotated(home_dir, randf() * TAU)
			_graze_target = ball.surface_point(gd, 0.0)
		dir = _graze_target - global_position
		dir -= up * dir.dot(up)
	# Stay inside the home area.
	if _angle_from_home(global_position) > home_radius:
		var back := ball.surface_point(home_dir) - global_position
		dir = (back - up * back.dot(up))
	if dir.length() > 0.01:
		_face(dir.normalized(), dt * 5.0)
	var step := heading * spd * dt + _pushed * dt
	_pushed = _pushed.move_toward(Vector3.ZERO, dt * 6.0)
	# Parasites grip the moss: they never crawl off a ledge on their own.
	if step.length() > 0.0001 and not _ground_ahead(global_position + step * 4.0):
		_graze_target = global_position - heading * 1.0
		_graze_t = 1.0
		heading = -heading
		step = Vector3.ZERO
	global_position += step
	_snap_ground()


func _angle_from_home(p: Vector3) -> float:
	return ball.up_at(p).angle_to(home_dir)


func _face(dir: Vector3, t: float) -> void:
	var d := dir - up * dir.dot(up)
	if d.length() < 0.001:
		return
	heading = heading.slerp(d.normalized(), clampf(t, 0.0, 1.0)).normalized() if heading.dot(d.normalized()) > -0.99 else d.normalized()
	heading = (heading - up * heading.dot(up)).normalized()


func _ground_ahead(p: Vector3) -> bool:
	var u := ball.up_at(p)
	var q := PhysicsRayQueryParameters3D.create(p + u * 1.0, p - u * 0.9, 1 | 2)
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _snap_ground() -> void:
	up = ball.up_at(global_position)
	var from := global_position + up * 1.2
	var q := PhysicsRayQueryParameters3D.create(from, global_position - up * 2.0, 1 | 2)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		if state in ["graze", "chase", "recover", "knocked"]:
			# Walked off a plant: fall.
			vel = -up * 1.0
			_set_state("flung")
		return
	global_position = hit.position + up * _ground_offset
	standing_on = hit.collider


func _update_segments(dt: float) -> void:
	_clock += dt
	var head := global_position
	if _trail.is_empty() or _trail[0].distance_to(head) > spacing * 0.35:
		_trail.push_front(head)
		_trail_up.push_front(up)
		if _trail.size() > seg_count * 6 + 4:
			_trail.pop_back()
			_trail_up.pop_back()
	else:
		_trail[0] = head
		_trail_up[0] = up
	var rear_lift := 0.0
	if state == "windup":
		rear_lift = minf(1.0, state_t / windup_time)
	# Travelling body wave. The head lays down the path (the trail); every segment sits on that
	# path at its own distance behind the head, so turns bend the body progressively. On top of
	# that, a sideways wave whose phase advances with the distance the head has travelled: crests
	# start near the head and roll back towards the tail as the creature moves, like a crawling
	# centipede or a swimming worm. Standing still, a slow restrained ripple remains.
	var moved := 0.0 if _last_head == Vector3.ZERO else minf(head.distance_to(_last_head), speed * 3.0 * dt + 0.05)
	_last_head = head
	var body_len := spacing * maxf(2.0, seg_count - 1)
	var wavelength := body_len * 1.3
	_wave_phase = fmod(_wave_phase + moved / wavelength * TAU + dt * 1.1, TAU * 64.0)
	var pace := clampf(moved / maxf(dt * speed, 0.0001), 0.0, 1.2) if dt > 0.0 else 0.0
	_wave_amp = lerpf(_wave_amp, seg_radius * (0.1 + 0.34 * pace), 1.0 - exp(-dt * 6.0))
	var base: Array[Vector3] = []
	var ups: Array[Vector3] = []
	for i in seg_count:
		var dist := spacing * i
		base.append(_sample_trail(dist))
		ups.append(_trail_up[mini(_trail_up.size() - 1, int(dist / (spacing * 0.35)))])
	var limp: Array[Vector3] = []
	if state == "drifting":
		limp = _limp_chain()
	for i in seg_count:
		var p: Vector3 = base[i]
		var u: Vector3 = ups[i]
		if state == "drifting":
			p = limp[i]
			u = global_basis.y
		else:
			# Struck (Expansion 6): one or two quick residual twitches that die away at once.
			if state == "dying":
				var tw := exp(-state_t * 7.0) * seg_radius * 1.1
				var ax: Vector3 = heading if i == 0 else (base[i - 1] - base[i])
				ax -= u * ax.dot(u)
				if ax.length() > 0.0001:
					p += ax.normalized().cross(u) * tw * sin(state_t * 34.0 - float(i) * 1.2) * lerpf(0.4, 1.0, float(i) / maxf(1.0, seg_count - 1))
			if i == 0:
				p += u * rear_lift * seg_radius * 1.6
			elif i == 1:
				p += u * rear_lift * seg_radius * 0.8
			# Sideways, across the path at this segment (not across the head's heading).
			var along: Vector3 = heading if i == 0 else (base[i - 1] - base[i])
			along -= u * along.dot(u)
			if along.length() > 0.0001:
				var t_body := float(i) / maxf(1.0, seg_count - 1)
				var env := lerpf(0.3, 1.0, t_body) * (1.0 - rear_lift)
				p += along.normalized().cross(u) * _wave_amp * env * sin(_wave_phase - TAU * spacing * i / wavelength)
		var s := _segs[i]
		var ahead := head if i == 0 else _segs[i - 1].global_position
		var fwd := (ahead - p) if i > 0 else heading
		if state == "drifting" and i == 0:
			fwd = -global_basis.z
		fwd = fwd - u * fwd.dot(u)
		if fwd.length() < 0.001:
			fwd = heading
		var right := fwd.normalized().cross(u).normalized()
		var sc := s.scale
		s.global_transform = Transform3D(Basis(right, u, -fwd.normalized()).orthonormalized().scaled(sc), p)
	_push_body()
	if state == "windup" or (state == "attack" and kind == Kind.LARGE):
		var open := 0.9 if state == "windup" else 0.3
		for c in _segs[0].get_children():
			if c.name.begins_with("Mandible"):
				var side := signf(c.position.x)
				c.rotation.z = side * -(0.4 + open)


## The body tube follows the segment anchors: their positions (with the body's taper as radius)
## and ups, sent to the body shader.
func _push_body() -> void:
	var pts := PackedVector4Array()
	var ups := PackedVector4Array()
	pts.resize(MAX_SEGS)
	ups.resize(MAX_SEGS)
	for i in seg_count:
		var t := float(i) / maxf(1.0, seg_count - 1)
		var r := seg_radius * (1.0 - 0.5 * pow(t, 1.4)) * (1.08 if i == 0 else 1.0)
		var sp := _segs[i].global_position
		pts[i] = Vector4(sp.x, sp.y, sp.z, r)
		var su := _segs[i].global_basis.y.normalized()
		ups[i] = Vector4(su.x, su.y, su.z, 0.0)
	_body.global_position = _segs[0].global_position
	_body_mat.set_shader_parameter("pts", pts)
	_body_mat.set_shader_parameter("ups", ups)


## Defeated and adrift (Expansion 6): not a rigid stick. The body hangs in a gentle limp curve that
## sags as it relaxes, with a weak ripple running to the tail (the tail lagging behind) that dies
## away over the first seconds.
func _limp_chain() -> Array[Vector3]:
	var out: Array[Vector3] = []
	var p := global_position
	var dir := global_basis.z.normalized()
	var ax := global_basis.y.normalized()
	var ax2 := global_basis.x.normalized()
	var relax := exp(-_drift_t * 1.4)
	for i in seg_count:
		out.append(p)
		var tt := float(i) / maxf(1.0, seg_count - 1)
		var bend := 0.16 * (1.0 - relax * 0.6) + sin(_drift_t * 6.5 - float(i) * 1.1) * 0.42 * relax * (0.3 + tt)
		dir = dir.rotated(ax, bend).rotated(ax2, 0.07 * (1.0 - relax * 0.5)).normalized()
		p += dir * spacing
	return out


func _sample_trail(dist: float) -> Vector3:
	var acc := 0.0
	for i in range(_trail.size() - 1):
		var a := _trail[i]
		var b := _trail[i + 1]
		var l := a.distance_to(b)
		if acc + l >= dist:
			return a.lerp(b, (dist - acc) / maxf(l, 0.0001))
		acc += l
	return _trail[_trail.size() - 1] if _trail.size() > 0 else global_position


# --- Damage ------------------------------------------------------------------------------

## stages: damage stages; knock: direction of knockback (tangent), strength scale.
func hit(stages: int, from_pos: Vector3, knock := 1.0) -> bool:
	if hp <= 0 or hit_cd > 0.0 or state in ["dying", "drifting", "gone", "init"]:
		return false
	hp = maxi(0, hp - stages)
	hit_cd = 0.25
	_flash = 0.6
	_gray_target = 1.0 - float(hp) / max_hp
	_latched = 0.0
	Sfx.play("hit", global_position)
	if hp <= 0:
		_set_state("dying")
		_gray_target = 1.0
		Game.inst.parasite_killed(self)
		return true
	var away := global_position - from_pos
	away -= up * away.dot(up)
	away = away.normalized() if away.length() > 0.01 else heading * -1.0
	if kind == Kind.LARGE:
		# Partially dislodged: lifted off the moss where the current can carry it.
		vel = away * 5.5 * knock + up * 4.0
		_set_state("flung")
	else:
		vel = away * 5.0 * knock
		_set_state("knocked")
	return true


## Startled back from `from_pos` (the bloom's pulse when the axolotl re-forms there), unhurt: it
## scuttles a few metres off, then carries on.
func startle(from_pos: Vector3) -> void:
	if not state in ["graze", "chase", "windup", "attack", "recover"]:
		return
	var away := global_position - from_pos
	away -= up * away.dot(up)
	away = away.normalized() if away.length() > 0.01 else heading * -1.0
	vel = away * 7.0
	_latched = 0.0
	# Shaken: it may come back, but holds off attacking for a while (a unit test found one
	# returning to strike just as the re-formed axolotl's grace ran out).
	_shaken = 3.5
	_set_state("knocked")


## Thrown into open water by a rebounding plant (or a big impact).
func fling(v: Vector3) -> void:
	if hp <= 0 or state in ["dying", "drifting", "gone", "init"]:
		return
	vel = v
	_latched = 0.0
	_set_state("flung")


func _update_flung(dt: float) -> void:
	up = ball.up_at(global_position)
	vel -= up * 9.0 * dt
	vel += ball.current_at(global_position) * 2.2 * dt
	vel *= 1.0 - 0.6 * dt
	var from := global_position
	var to := from + vel * dt
	# Scramble back toward home while airborne (swim/scramble to latch on).
	var home := ball.surface_point(home_dir) - global_position
	vel += (home - up * home.dot(up)).normalized() * 1.2 * dt
	var q := PhysicsRayQueryParameters3D.create(from, to - up * _ground_offset, 1 | 2)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and state_t > 0.2 and vel.dot(up) <= 0.5:
		global_position = hit.position + up * _ground_offset
		standing_on = hit.collider
		# Re-latch: its home is now wherever it grabbed on.
		home_dir = ball.up_at(global_position)
		_set_state("recover")
		return
	global_position = to
	if (global_position - ball.global_position).length() < ball.radius:
		global_position = ball.surface_point(ball.up_at(global_position), _ground_offset)
		home_dir = ball.up_at(global_position)
		_set_state("recover")


func _detach() -> void:
	# Loses its grip; the aquarium current carries the grey body away.
	_set_state("drifting")
	top_level = true
	var u := up
	global_transform = Transform3D(Basis(heading.cross(u).normalized(), u, -heading), global_position)
	vel = u * 2.6 + Game.inst.tank_flow() * 0.6 + ball.current_at(global_position)
	_spin = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.35


func _update_drift(dt: float) -> void:
	_drift_t += dt
	var away := ball.up_at(global_position)
	var target_v := away * 1.6 + Game.inst.tank_flow()
	vel = vel.lerp(target_v, minf(1.0, dt * 0.3))
	global_position += vel * dt
	global_basis = (global_basis * Basis.from_euler(_spin * dt)).orthonormalized()
	_update_segments(dt)
	var cam := get_viewport().get_camera_3d()
	var far := cam == null or cam.global_position.distance_to(global_position) > 45.0
	if _drift_t > 14.0 or (far and _drift_t > 3.0):
		# Hand over to a cheap drifting speck (never popped out of existence).
		WaterFX.inst.add_debris(global_position, vel)
		state = "gone"
		visible = false
		set_physics_process(false)


func water_push(v: Vector3) -> void:
	if state in ["graze", "chase"]:
		_pushed += v
