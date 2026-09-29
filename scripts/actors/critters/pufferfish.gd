class_name Pufferfish
extends Critter
## A slow pufferfish drifting in open water above ridges and open ground (docs/ECOSYSTEM.md). It
## hangs at about the height of the axolotl's jumps and climbs, not at ground level. When he comes
## near it puffs up over INFLATE_TIME (grows, spikes out, yellows: the telegraph), bobs down toward
## him, and stays puffed a while after he leaves. Touching it puffed hurts. Each tail swipe that lands
## knocks it back and costs it one of HP (a bright flash and a pop say so); the last one deflates it
## and it drifts off, back in its patch RETURN_AFTER later when he is elsewhere, like the reed stalker.
## Beating it is not a completion entry (only discovering the species is).

const NOTICE_R := 3.4
const INFLATE_TIME := 0.6
const STAY_PUFFED := 3.0
const BODY_R := 0.28
const PUFFED_R := 0.9
const CONTACT_CD := 1.6
const SPIKES := 18
const HP := 3
## After a hit it cannot be hit again for this long (so one swipe never counts twice).
const HIT_CD := 0.35
## Back in its patch this long (play time) after it was beaten, when he is elsewhere.
const RETURN_AFTER := 120.0
## Puffed near him, it sinks toward this height above his body centre (it faces the intruder).
const FACE_UP := 0.7

var home_dir := Vector3.UP
var home_deg := 8.0
var hover := 2.0
var inflate := 0.0
var puffed := false
var calm_t := 0.0
var contact_cd := 0.0
var _vel := Vector3.ZERO
var _wander := Vector3.ZERO
var _wander_t := 0.0
var _ground_alt := 0.0
var _ground_t := 0.0
var _body: MeshInstance3D
var hit_cd := 0.0
var gone_at := 0.0
var _flash := 0.0


func place(p_ball: MossBall, p_home: Vector3, p_deg: float, p_hover: float, seed_v: int) -> void:
	setup(p_ball, "puffer", "open water", seed_v)
	seen_radius = 7.0
	p_ball.add_child(self)
	home_dir = p_home.normalized()
	home_deg = p_deg
	hover = p_hover
	_build()
	_ground_alt = ball.altitude(ball.surface_point(home_dir))
	global_position = ball.surface_point(home_dir, hover)
	hp = HP


func late_place() -> void:
	var g := ground_under(ball.surface_point(home_dir, 3.0), GROUND_MASK, 0.5, 8.0)
	if g:
		_ground_alt = ball.altitude(g["position"])
	global_position = ball.surface_point(home_dir, _ground_alt + hover)


func _build() -> void:
	# One mesh, two shapes (Expansion 6, owner reference photos): calm, a spotted porcupinefish with
	# fins and flat spines; puffed, a spiny ball (shaders/puffer_body.gdshader morphs between them).
	_mat = ShaderMaterial.new()
	_mat.shader = BODY_SHADER
	_body = Critter.part(_puffer_mesh(), _mat, self)
	_body.custom_aabb = AABB(Vector3.ONE * -1.4, Vector3.ONE * 2.8)


const BODY_SHADER := preload("res://shaders/puffer_body.gdshader")
const SPINES := 170
var _mat: ShaderMaterial
static var _mesh: ArrayMesh


## The calm fish: head toward -Z, `BODY_R` (0.28 m) round the middle. Each vertex also carries its
## puffed position and normal (CUSTOM0/1): body points out onto a sphere of PUFFED_R, fins and
## eyes moved with the body point they sit on, spines standing out along the sphere.
static func _puffer_mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	st.set_custom_format(1, SurfaceTool.CUSTOM_RGBA_FLOAT)
	var skin := Color(0.62, 0.55, 0.38, 1.0)
	var belly := Color(0.9, 0.86, 0.74, 1.0)
	var fin := Color(0.78, 0.7, 0.36, 0.0)
	var centre := Vector3(0, 0, -0.03)
	var rings := 16
	var sides := 16
	var calm := func(u: float, a: float) -> Vector3:
		# u: 0 at the snout, 1 where the tail stalk meets the tail fin.
		var z := lerpf(-0.4, 0.4, u)
		var r := BODY_R * 0.82 * pow(sin(PI * clampf(u * 0.86 + 0.07, 0.0, 1.0)), 0.62) * (1.0 - 0.45 * pow(u, 3.0))
		return Vector3(cos(a) * r * 0.95, sin(a) * r * 0.88, z)
	var puff := func(p: Vector3) -> Vector3:
		return centre + (p - centre).normalized() * PUFFED_R
	var nv := 0
	# Body (closed at the snout; the tail fin covers the stalk's end).
	for i in rings + 1:
		var u := float(i) / rings
		for k in sides:
			var a := TAU * k / sides
			var p: Vector3 = calm.call(u, a)
			var pp: Vector3 = puff.call(p)
			st.set_color(belly if sin(a) < -0.35 else skin)
			st.set_custom(0, Color(pp.x, pp.y, pp.z))
			var pn := (pp - centre).normalized()
			st.set_custom(1, Color(pn.x, pn.y, pn.z))
			st.add_vertex(p)
			nv += 1
	for i in rings:
		for k in sides:
			var a := i * sides + k
			var b := i * sides + (k + 1) % sides
			for q in [a, b, a + sides, b, b + sides, a + sides]:
				st.add_index(q)
	# Parts riding the body: each vertex moves by the same offset as its anchor body point.
	var ride := func(verts: Array, anchor: Vector3, col: Color) -> void:
		var shift: Vector3 = puff.call(anchor) - anchor
		var pn := (anchor + shift - centre).normalized()
		var start := nv
		for v in verts:
			st.set_color(col)
			st.set_custom(0, Color((v as Vector3).x + shift.x, (v as Vector3).y + shift.y, (v as Vector3).z + shift.z))
			st.set_custom(1, Color(pn.x, pn.y, pn.z))
			st.add_vertex(v)
			nv += 1
		for t in range(0, verts.size(), 3):
			st.add_index(start + t)
			st.add_index(start + t + 1)
			st.add_index(start + t + 2)
	var fan := func(root: Vector3, dir_a: Vector3, dir_b: Vector3, n: int) -> Array:
		var out := []
		for f in n:
			var d0 := dir_a.slerp(dir_b, float(f) / n)
			var d1 := dir_a.slerp(dir_b, float(f + 1) / n)
			out.append_array([root, root + d0, root + d1])
		return out
	# Tail fin, dorsal and anal fins, two pectoral fins.
	var tail: Vector3 = calm.call(1.0, 0.0) * Vector3(0, 0, 1)
	ride.call(fan.call(tail, Vector3(0, 0.16, 0.12), Vector3(0, -0.16, 0.12), 6), tail, fin)
	var dors: Vector3 = calm.call(0.72, PI * 0.5)
	ride.call(fan.call(dors, Vector3(0, 0.12, 0.02), Vector3(0, 0.02, 0.14), 4), dors, fin)
	var anal: Vector3 = calm.call(0.72, -PI * 0.5)
	ride.call(fan.call(anal, Vector3(0, -0.11, 0.02), Vector3(0, -0.02, 0.13), 4), anal, fin)
	for side in [-1.0, 1.0]:
		var pec: Vector3 = calm.call(0.36, 0.0 if side > 0.0 else PI)
		ride.call(fan.call(pec, Vector3(side * 0.12, 0.06, 0.02), Vector3(side * 0.1, -0.06, 0.08), 5), pec, fin)
		# A big dark eye with a bright catch-light, and pale lips at the snout.
		var eye: Vector3 = calm.call(0.2, 0.0 if side > 0.0 else PI) + Vector3(0, 0.05, 0)
		var ev := []
		for k in 8:
			var a0 := TAU * k / 8
			var a1 := TAU * (k + 1) / 8
			var o := Vector3(side * 0.012, 0, 0)
			ev.append_array([eye + o, eye + o + Vector3(0, cos(a0), sin(a0)) * 0.05, eye + o + Vector3(0, cos(a1), sin(a1)) * 0.05])
		ride.call(ev, eye, Color(0.04, 0.05, 0.08, 0.0))
		ride.call([eye + Vector3(side * 0.016, 0.02, -0.01), eye + Vector3(side * 0.016, 0.03, 0.005), eye + Vector3(side * 0.016, 0.012, 0.004)], eye, Color(0.9, 0.95, 1.0, 0.0))
	var snout: Vector3 = calm.call(0.0, 0.0) * Vector3(0, 0, 1) + Vector3(0, -0.03, -0.01)
	var lips := []
	for k in 8:
		var a0 := TAU * k / 8
		var a1 := TAU * (k + 1) / 8
		lips.append_array([snout, snout + Vector3(cos(a0) * 0.045, sin(a0) * 0.028, -0.01), snout + Vector3(cos(a1) * 0.045, sin(a1) * 0.028, -0.01)])
	ride.call(lips, snout, Color(0.9, 0.62, 0.58, 0.0))
	# Spines: flat along the body toward the tail when calm; standing out when puffed.
	for i in SPINES:
		var y := 1.0 - 2.0 * (i + 0.5) / SPINES
		var r := sqrt(1.0 - y * y)
		var ga := i * 2.399963
		var n := Vector3(cos(ga) * r, y, sin(ga) * r)
		var u := clampf(0.5 + n.z * 0.42, 0.08, 0.85)
		var a := atan2(n.y, n.x)
		var base_c: Vector3 = calm.call(u, a)
		var base_p := centre + n * PUFFED_R
		var back := Vector3(0, 0, 1)
		var side_c := back.cross(base_c.normalized()).normalized() * 0.012
		var side_p := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized() * 0.03
		var calm_tri := [base_c - side_c, base_c + side_c, base_c + back * 0.06 + (base_c - Vector3(0, 0, base_c.z)).normalized() * 0.01]
		var puff_tri := [base_p - side_p * 1.5, base_p + side_p * 1.5, base_p + n * 0.26]
		var start := nv
		for q in 3:
			var pv: Vector3 = puff_tri[q]
			st.set_color(Color(0.95, 0.9, 0.74, 0.0))
			st.set_custom(0, Color(pv.x, pv.y, pv.z))
			st.set_custom(1, Color(n.x, n.y, n.z))
			st.add_vertex(calm_tri[q])
			nv += 1
		st.add_index(start)
		st.add_index(start + 1)
		st.add_index(start + 2)
	st.generate_normals()
	_mesh = st.commit()
	return _mesh


func tick(dt: float) -> void:
	if defeated:
		var p0 := player()
		if Game.inst.clock.play_s - gone_at > RETURN_AFTER and (p0 == null or p0.ball != ball or p0.global_position.distance_to(ball.surface_point(home_dir)) > 20.0):
			_return()
		return
	contact_cd = maxf(0.0, contact_cd - dt)
	hit_cd = maxf(0.0, hit_cd - dt)
	_flash = maxf(0.0, _flash - dt * 4.0)
	var p := player()
	var near := player_here() and p.body_center().distance_to(global_position) < NOTICE_R
	if near:
		calm_t = 0.0
		if not puffed:
			puffed = true
			Sfx.play("puff_inflate", global_position)
	else:
		calm_t += dt
		if puffed and calm_t > STAY_PUFFED:
			puffed = false
	inflate = move_toward(inflate, 1.0 if puffed else 0.0, dt / (INFLATE_TIME if puffed else 1.5))
	# Drift: a slow wander leashed to home, the ball's current, the height it likes.
	_wander_t -= dt
	if _wander_t <= 0.0:
		_wander_t = rng.randf_range(2.0, 4.0)
		var up0 := ball.up_at(global_position)
		_wander = MossBall.frame_at(up0, rng.randf() * 360.0).z * rng.randf_range(0.2, 0.5)
	var up := ball.up_at(global_position)
	var off := rad_to_deg(up.angle_to(home_dir))
	var home_pull := Vector3.ZERO
	if off > home_deg:
		home_pull = (ball.surface_point(home_dir) - global_position).normalized() * 0.6
	_ground_t -= dt
	if _ground_t <= 0.0:
		_ground_t = 0.5
		var g := ground_under(global_position, GROUND_MASK, 0.5, hover + 6.0)
		_ground_alt = ball.altitude(g["position"]) if g else _ground_alt
	var want_alt := _ground_alt + hover
	# Puffed with him close: it sinks to face him (never below FACE_UP over his body centre), so a
	# swipe can reach it and its spines are a real threat.
	if puffed and near:
		want_alt = minf(want_alt, maxf(_ground_alt + 0.9, ball.altitude(p.body_center()) + FACE_UP))
	var alt_err := want_alt - ball.altitude(global_position)
	var target_v := _wander * (1.0 - inflate * 0.8) + home_pull + ball.current_at(global_position) * 0.35 + up * clampf(alt_err, -0.6, 0.6)
	_vel = _vel.lerp(target_v, clampf(dt * 1.5, 0.0, 1.0))
	global_position += _vel * dt
	# Puffed: it hurts to touch.
	if puffed and inflate > 0.6 and contact_cd <= 0.0 and player_here():
		if p.body_center().distance_to(global_position) < radius() + 0.25:
			contact_cd = CONTACT_CD
			strike_player(global_position)
	_pose(dt)


func radius() -> float:
	return lerpf(BODY_R, PUFFED_R, inflate)


func _pose(_dt: float) -> void:
	var up := ball.up_at(global_position)
	var fwd := _vel - up * _vel.dot(up)
	if fwd.length() < 0.05:
		fwd = -global_basis.z
	fwd = fwd.normalized()
	global_basis = Basis(fwd.cross(up).normalized(), up, -fwd).orthonormalized()
	_mat.set_shader_parameter("inflate", inflate)
	_body.scale = Vector3.ONE * (1.0 + _flash * 0.12)


func wake_points() -> Array:
	return []


func hittable() -> bool:
	return not defeated


## The point of its (puffed or calm) body nearest `pt`: a swipe reaches its surface, not its centre.
func closest_body_point(pt: Vector3) -> Vector3:
	var d := pt - global_position
	if d.length() < 0.001:
		return global_position
	return global_position + d.normalized() * minf(radius(), d.length())


## (closest_body_point already lies on its surface.)
func body_extent() -> float:
	return 0.08


## Struck: knocked back and puffed at once; each landed hit (at most one per HIT_CD) costs one of HP,
## and the last one beats it. Returns true when the hit landed.
func hit(stages: int, from_pos: Vector3) -> bool:
	if defeated or hit_cd > 0.0:
		return false
	hit_cd = HIT_CD
	# Knocked back along the ground (not up out of reach): about a body length, so he can follow up.
	var up := ball.up_at(global_position)
	var away := global_position - from_pos
	away -= up * away.dot(up)
	away = away.normalized() if away.length() > 0.01 else -global_basis.z
	_vel = away * 2.4
	puffed = true
	calm_t = 0.0
	hp -= maxi(1, stages)
	_flash = 1.0
	WaterFX.inst.sparkle(global_position, Color(1.0, 0.92, 0.55, 0.9), 10, 1.4, 0.06, 0.6)
	Sfx.play("puff_bounce", global_position)
	if hp <= 0:
		_beaten()
	return true


func _beaten() -> void:
	defeated = true
	gone_at = Game.inst.clock.play_s
	puffed = false
	inflate = 0.0
	visible = false
	WaterFX.inst.sparkle(global_position, Color(0.95, 1.0, 0.8, 0.9), 18, 1.8, 0.07, 1.0)
	Sfx.play("drain", global_position, -4.0)
	Game.inst.critter_defeated(self)


## Back in its patch after a while, when the axolotl is elsewhere.
func _return() -> void:
	defeated = false
	visible = true
	hp = HP
	hit_cd = 0.0
	puffed = false
	inflate = 0.0
	_vel = Vector3.ZERO
	global_position = ball.surface_point(home_dir, _ground_alt + hover)
