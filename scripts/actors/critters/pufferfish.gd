class_name Pufferfish
extends Critter
## A slow pufferfish drifting in open water above ridges and open ground (docs/ECOSYSTEM.md). It
## hangs at about the height of the axolotl's jumps and climbs, not at ground level. When he comes
## near it puffs up over INFLATE_TIME (grows, spikes out, yellows: the telegraph) and stays puffed a
## while after he leaves. Touching it puffed hurts; a swipe only bats it away (it cannot be beaten),
## so the thing to do is to go round it or wait for it to drift clear.

const NOTICE_R := 3.4
const INFLATE_TIME := 0.6
const STAY_PUFFED := 3.0
const BODY_R := 0.28
const PUFFED_R := 0.9
const CONTACT_CD := 1.6
const SPIKES := 18

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
var _spike_mi: MeshInstance3D
var _skin: StandardMaterial3D


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


func late_place() -> void:
	var g := ground_under(ball.surface_point(home_dir, 3.0), GROUND_MASK, 0.5, 8.0)
	if g:
		_ground_alt = ball.altitude(g["position"])
	global_position = ball.surface_point(home_dir, _ground_alt + hover)


func _build() -> void:
	# One mesh for the body (skin, spots, eyes, fins, tail) and one for all the spikes.
	_skin = Critter.vc_mat().duplicate()
	var skin := Color(0.82, 0.7, 0.36)
	var spot := Color(0.45, 0.32, 0.16)
	var parts := [[Critter.sphere(BODY_R, 14), skin, Transform3D()]]
	for i in 5:
		var a := rng.randf() * TAU
		var e := rng.randf_range(-0.6, 0.8)
		parts.append([Critter.sphere(0.05, 6), spot, Critter.xf(Vector3(cos(a) * cos(e), sin(e), sin(a) * cos(e)) * BODY_R * 0.95)])
	for side in [-1.0, 1.0]:
		parts.append([Critter.sphere(0.05, 6), Color(0.05, 0.05, 0.05), Critter.xf(Vector3(side * 0.16, 0.08, -0.2))])
		parts.append([Critter.sphere(0.07, 6), skin, Critter.xf(Vector3(side * 0.26, 0, 0.02), Vector3(0.3, 1.0, 1.2))])
	parts.append([Critter.sphere(0.09, 6), skin, Critter.xf(Vector3(0, 0, 0.3), Vector3(0.3, 1.1, 1.0))])
	_body = Critter.part(Critter.merge(parts), _skin, self)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.035
	cone.height = 0.16
	cone.radial_segments = 5
	cone.rings = 1
	var spikes := []
	for i in SPIKES:
		# Spread evenly over the sphere (golden spiral).
		var y := 1.0 - 2.0 * (i + 0.5) / SPIKES
		var r := sqrt(1.0 - y * y)
		var a := i * 2.399963
		var n := Vector3(cos(a) * r, y, sin(a) * r)
		spikes.append([cone, Color(0.95, 0.9, 0.7), Transform3D(Basis(Quaternion(Vector3.UP, n)), n * (BODY_R + 0.06))])
	_spike_mi = Critter.part(Critter.merge(spikes), _skin, self)


func tick(dt: float) -> void:
	contact_cd = maxf(0.0, contact_cd - dt)
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
	var alt_err := (_ground_alt + hover) - ball.altitude(global_position)
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
	var k := radius() / BODY_R
	_body.scale = Vector3.ONE * k
	# The spikes stand out as it puffs up (hidden while it is smooth).
	_spike_mi.scale = Vector3.ONE * k
	_spike_mi.visible = inflate > 0.25
	_skin.albedo_color = Color(1, 1, 1).lerp(Color(1.15, 1.1, 0.75), inflate)


func wake_points() -> Array:
	return []


func hittable() -> bool:
	return true


func closest_body_point(_p: Vector3) -> Vector3:
	return global_position


func body_extent() -> float:
	return radius()


## Batted away (it cannot be beaten), and puffed up at once.
func hit(_stages: int, from_pos: Vector3) -> bool:
	var away := (global_position - from_pos).normalized()
	_vel = away * 4.0
	puffed = true
	calm_t = 0.0
	Sfx.play("puff_bounce", global_position)
	return true


func is_alive() -> bool:
	return true
