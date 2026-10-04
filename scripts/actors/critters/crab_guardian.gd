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
	# Expansion 6 (owner reference photo): a domed, speckled dark carapace with a red rim, red
	# jointed legs with sharp tips, and chunky two-fingered pincers. Merged meshes: the carapace
	# (its own shell material), each claw arm (they pivot) and the legs.
	_rig = Node3D.new()
	add_child(_rig)
	_shell_mat = Critter.vc_mat().duplicate()
	_shell_mat.roughness = 0.35
	_carapace_mat = ShaderMaterial.new()
	_carapace_mat.shader = CARAPACE
	var shell := MeshInstance3D.new()
	shell.mesh = _carapace_mesh()
	shell.material_override = _carapace_mat
	shell.position = Vector3(0, 0.3, 0)
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.visibility_range_end = 60.0
	_rig.add_child(shell)
	var red := Color(0.84, 0.2, 0.09)
	var orange := Color(0.95, 0.45, 0.16)
	var dark := Color(0.16, 0.05, 0.03)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nv := 0
	# Eyes on short stalks at the front of the shell.
	for side in [-1.0, 1.0]:
		nv = _tube(st, Vector3(side * 0.13, 0.46, -0.4), Vector3(side * 0.15, 0.58, -0.44), 0.03, 0.025, orange, orange, nv)
		nv = _blob(st, Vector3(side * 0.15, 0.61, -0.45), 0.05, Color(0.03, 0.03, 0.04), nv)
	# Four jointed walking legs a side: out and up to a knee, down to an ankle, a sharp tip.
	for side in [-1.0, 1.0]:
		for k in 4:
			var z := -0.16 + k * 0.17
			var hip := Vector3(side * 0.46, 0.28, z)
			var knee := Vector3(side * 0.8, 0.5, z + 0.05 * (k - 1.5))
			var ankle := Vector3(side * 1.02, 0.22, z + 0.1 * (k - 1.5))
			var tip := Vector3(side * 1.1, 0.0, z + 0.13 * (k - 1.5))
			nv = _tube(st, hip, knee, 0.055, 0.045, red, red, nv)
			nv = _tube(st, knee, ankle, 0.045, 0.035, red, orange, nv)
			nv = _tube(st, ankle, tip, 0.032, 0.004, orange, dark, nv)
	st.generate_normals()
	var leg_node := Node3D.new()
	_rig.add_child(leg_node)
	Critter.part(st.commit(), _shell_mat, leg_node)
	_legs.append(leg_node)
	# The pincers: arm, a chunky palm, a fixed finger below and a movable one above.
	for side in [-1.0, 1.0]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(side * 0.4, 0.32, -0.3)
		_rig.add_child(shoulder)
		var cs := SurfaceTool.new()
		cs.begin(Mesh.PRIMITIVE_TRIANGLES)
		var cn := 0
		cn = _tube(cs, Vector3.ZERO, Vector3(side * 0.16, 0.04, -0.22), 0.075, 0.065, red, red, cn)
		cn = _tube(cs, Vector3(side * 0.16, 0.04, -0.22), Vector3(side * 0.22, 0.05, -0.36), 0.065, 0.075, red, orange, cn)
		cn = _blob(cs, Vector3(side * 0.24, 0.05, -0.5), 1.0, red, cn, Vector3(0.15, 0.13, 0.2))
		cn = _tube(cs, Vector3(side * 0.24, -0.02, -0.64), Vector3(side * 0.22, -0.04, -0.8), 0.06, 0.035, orange, orange, cn)
		cn = _tube(cs, Vector3(side * 0.22, -0.04, -0.8), Vector3(side * 0.17, 0.0, -0.92), 0.035, 0.006, orange, dark, cn)
		cn = _tube(cs, Vector3(side * 0.27, 0.11, -0.63), Vector3(side * 0.25, 0.1, -0.79), 0.05, 0.03, red, orange, cn)
		cn = _tube(cs, Vector3(side * 0.25, 0.1, -0.79), Vector3(side * 0.19, 0.04, -0.9), 0.03, 0.005, orange, dark, cn)
		cs.generate_normals()
		Critter.part(cs.commit(), _shell_mat, shoulder)
		_claws.append(shoulder)


const CARAPACE := preload("res://shaders/crab_shell.gdshader")
var _carapace_mat: ShaderMaterial


## The carapace: a wide oval dome (y = 0 at the rim) with a slightly serrated front edge, closed
## underneath by a shallow belly plate.
static func _carapace_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 10
	var sides := 32
	var rim := func(a: float) -> Vector2:
		var x := sin(a) * 0.6
		var z := -cos(a) * 0.46
		# Broader at the front shoulders, a few small teeth along the front edge.
		var front := maxf(0.0, -cos(a))
		var k := 1.0 + 0.06 * front + 0.035 * front * absf(sin(a * 8.0))
		return Vector2(x * k, z * (1.0 - 0.06 * front))
	var verts := []
	for half in [1.0, -1.0]:
		var block := []
		for i in rings + 1:
			var v := float(i) / rings
			var row := []
			for k in sides:
				var a := TAU * k / sides
				var r: Vector2 = rim.call(a)
				var y := 0.26 * (1.0 - pow(v, 2.2)) if half > 0.0 else -0.1 * (1.0 - v * v)
				row.append(Vector3(r.x * v, y, r.y * v))
			block.append(row)
		verts.append(block)
	var n := 0
	for hb in 2:
		var block: Array = verts[hb]
		var start := n
		for i in rings + 1:
			for k in sides:
				st.add_vertex(block[i][k])
				n += 1
		for i in rings:
			for k in sides:
				var a := start + i * sides + k
				var b := start + i * sides + (k + 1) % sides
				var c := a + sides
				var d := b + sides
				var tri := [a, c, b, b, c, d] if hb == 0 else [a, b, c, b, d, c]
				for q in tri:
					st.add_index(q)
	st.generate_normals()
	return st.commit()


## A tapered tube from `a` to `b` (radius r0 to r1, colour c0 to c1), indexed from `base`.
static func _tube(st: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float, c0: Color, c1: Color, base: int) -> int:
	var d := (b - a).normalized()
	var x := d.cross(Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT).normalized()
	var y := x.cross(d)
	var sides := 7
	for j in 2:
		var p: Vector3 = a if j == 0 else b
		var r: float = r0 if j == 0 else r1
		for k in sides:
			var ang := TAU * k / sides
			st.set_color(c0 if j == 0 else c1)
			st.add_vertex(p + (x * cos(ang) + y * sin(ang)) * r)
	for k in sides:
		var i0 := base + k
		var i1 := base + (k + 1) % sides
		for q in [i0, i0 + sides, i1, i1, i0 + sides, i1 + sides]:
			st.add_index(q)
	# Rounded joint at the near end.
	return _blob(st, a, r0 * 1.05, c0, base + sides * 2)


## A small sphere (or `scl`-scaled ellipsoid of radius 1 * scl) at `c`, indexed from `base`.
static func _blob(st: SurfaceTool, c: Vector3, r: float, col: Color, base: int, scl := Vector3.ONE) -> int:
	var rings := 5
	var sides := 8
	for i in rings + 1:
		var phi := PI * i / rings
		for k in sides:
			var th := TAU * k / sides
			st.set_color(col)
			st.add_vertex(c + Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th)) * r * scl)
	for i in rings:
		for k in sides:
			var a := base + i * sides + k
			var b := base + i * sides + (k + 1) % sides
			for q in [a, b, a + sides, b, b + sides, a + sides]:
				st.add_index(q)
	return base + (rings + 1) * sides


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
	_carapace_mat.set_shader_parameter("flash", 1.0 if state == "stunned" else 0.0)


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
