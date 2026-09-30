class_name ReedStalker
extends Critter
## A long, low hunter living in a patch of tall reeds (docs/ECOSYSTEM.md). Its body is reed-coloured
## and lower than the reeds, so the axolotl usually sees the reeds part before he sees it: its
## movement bends the vegetation where it really is (wake points on its head and body).
##
## It prowls its patch. When the axolotl is in the patch and close, it stalks him, keeping a few
## metres off; then it stops, rears and hisses while the reeds around it thrash (the telegraph,
## 0.9 s) and pounces along the line it locked at the start of the telegraph, so a sidestep avoids
## it. After a pounce it lies low for a moment (vulnerable). It gives up when he leaves the patch.
## Two swipes drive it off; it returns to its patch later when he is away (not a completion entry).

const NOTICE_R := 9.0
const KEEP_OFF := 3.6
const TELEGRAPH := 0.9
const POUNCE_TIME := 0.35
const POUNCE_DIST := 3.4
const RECOVER := 1.6
const COOLDOWN := 2.5
const CONTACT_R := 0.7
const RETURN_AFTER := 120.0
const SEGS := 6
const SPACING := 0.32

## The reed patch: centre direction and radius (degrees).
var patch_dir := Vector3.UP
var patch_deg := 10.0
var state := "prowl"
var state_t := 0.0
var cooldown := 0.0
## Play time when it was driven off (it returns RETURN_AFTER later; the clock runs while the ball
## is dormant, so it is back even if the axolotl went elsewhere).
var gone_at := 0.0
var heading := Vector3.FORWARD
var _target := Vector3.ZERO
var _lock := Vector3.ZERO
var _vel := Vector3.ZERO
var _hurt := false
var _trail: Array[Vector3] = []
var _mm: MultiMesh
var _head: Node3D
var _frill: MeshInstance3D
var _near_t := 0.0


func place(p_ball: MossBall, p_patch: Vector3, p_deg: float, seed_v: int) -> void:
	setup(p_ball, "stalker", "tall reeds", seed_v)
	org = OrganicMotion.new(rng.seed, OrganicMotion.STALKER)
	hp = 2
	seen_radius = 4.5
	p_ball.add_child(self)
	patch_dir = p_patch.normalized()
	patch_deg = p_deg
	global_position = ball.surface_point(patch_dir)
	heading = MossBall.frame_at(patch_dir, rng.randf() * 360.0).z
	_build()
	_pick_target()
	for i in SEGS:
		_trail.append(global_position)


func late_place() -> void:
	_snap(global_position)
	_trail.clear()
	for i in SEGS:
		_trail.append(global_position)
	_update_body(0.0)


func _build() -> void:
	# Body segments as one batch (striped reed colours), the head, and the frill it flares.
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = Critter.sphere(0.2, 8)
	_mm.instance_count = SEGS
	for i in SEGS:
		_mm.set_instance_color(i, Color(0.34, 0.4, 0.16) if i % 2 == 0 else Color(0.52, 0.46, 0.2))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _mm
	mmi.material_override = Critter.vc_mat()
	mmi.top_level = true
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = 60.0
	add_child(mmi)
	_head = Node3D.new()
	_head.top_level = true
	add_child(_head)
	var head := [[Critter.sphere(0.2, 10), Color(0.34, 0.4, 0.16), Critter.xf(Vector3.ZERO, Vector3(0.85, 0.6, 1.5))]]
	for side in [-1.0, 1.0]:
		head.append([Critter.sphere(0.04, 6), Color(0.95, 0.85, 0.3), Critter.xf(Vector3(side * 0.1, 0.07, -0.2))])
	Critter.part(Critter.merge(head), Critter.vc_mat(), _head)
	_frill = Critter.part(Critter.sphere(0.25, 10), Critter.mat(Color(0.75, 0.4, 0.14)), _head, Vector3(0, 0.06, 0.14), Vector3(1.4, 0.8, 0.2))


func _in_patch(pos: Vector3, margin := 0.0) -> bool:
	return rad_to_deg(ball.up_at(pos).angle_to(patch_dir)) <= patch_deg + margin


func _pick_target() -> void:
	var d := patch_dir.rotated(MossBall.frame_at(patch_dir, rng.randf() * 360.0).x, deg_to_rad(rng.randf() * patch_deg * 0.8))
	_target = ball.surface_point(d)


func _snap(pos: Vector3) -> void:
	var hit := ground_under(pos, GROUND_MASK, 0.8, 2.0)
	global_position = (hit["position"] as Vector3) if hit else ball.surface_point(ball.up_at(pos))


func tick(dt: float) -> void:
	if defeated:
		var p0 := player()
		if Game.inst.clock.play_s - gone_at > RETURN_AFTER and (p0 == null or p0.ball != ball or p0.global_position.distance_to(ball.surface_point(patch_dir)) > 20.0):
			_return()
		return
	state_t += dt
	cooldown = maxf(0.0, cooldown - dt)
	var p := player()
	var here := player_here()
	var up := ball.up_at(global_position)
	var to: Vector3 = (p.global_position - global_position) if p else Vector3.ZERO
	to -= up * to.dot(up)
	var dist := to.length()
	var hunting := here and _in_patch(p.global_position, 1.5) and dist < NOTICE_R \
			and not line_blocked(global_position + up * 0.3, p.body_center())
	# Expression (OrganicMotion): prowling slinks in curves with stop-and-go pauses; stalking keeps a
	# little of it; the telegraph, pounce and recovery have none.
	match state:
		"prowl":
			org.step(dt, 1.0, 1.0, 1.0)
		"stalk":
			org.step(dt, 0.3, 0.35, 0.5)
		"flee":
			org.step(dt, 0.0, 0.4, 0.0)
		_:
			org.step(dt, 0.0, 0.0, 0.0, true)
	match state:
		"prowl":
			_walk_to(_target, 1.0, dt, true)
			if global_position.distance_to(_target) < 0.6 or state_t > 8.0:
				_pick_target()
				state_t = 0.0
			if hunting:
				_go("stalk")
		"stalk":
			if not hunting:
				_go("prowl")
				_pick_target()
			else:
				# Keep a few metres off, circling slowly toward his side.
				var aim := p.global_position - to.normalized() * KEEP_OFF + to.normalized().cross(up) * 1.2
				if _in_patch(aim):
					_walk_to(aim, 2.0, dt)
				_face(to, dt)
				_near_t = _near_t + dt if dist < KEEP_OFF + 1.0 else 0.0
				if _near_t > 1.2 and cooldown <= 0.0:
					_go("telegraph")
					_lock = to.normalized()
					Sfx.play("stalker_hiss", global_position)
		"telegraph":
			_vel = Vector3.ZERO
			if state_t >= TELEGRAPH:
				_go("pounce")
				_hurt = false
				Sfx.play("stalker_pounce", global_position)
		"pounce":
			var step := _lock * (POUNCE_DIST / POUNCE_TIME) * dt
			if not line_blocked(global_position + up * 0.3, global_position + up * 0.3 + _lock * 0.5):
				_vel = step / dt
				_snap(global_position + step)
				heading = _lock
			if not _hurt and here and p.body_center().distance_to(global_position + up * 0.25) < CONTACT_R + 0.3:
				_hurt = true
				strike_player(global_position)
			if state_t >= POUNCE_TIME:
				_go("recover")
		"recover":
			_vel = Vector3.ZERO
			if state_t >= RECOVER:
				cooldown = COOLDOWN
				_near_t = 0.0
				_go("stalk" if hunting else "prowl")
		"flee":
			var away := -to.normalized() if dist > 0.01 else heading
			_walk_to(global_position + away * 2.0, 3.0, dt)
			if state_t > 2.0:
				_go("prowl")
				_pick_target()
	_update_body(dt)


func _go(s: String) -> void:
	state = s
	state_t = 0.0


## `glide`: it walks where its head points (prowling: turns are curves, never corners).
func _walk_to(target: Vector3, speed: float, dt: float, glide := false) -> void:
	var up := ball.up_at(global_position)
	var d := target - global_position
	d -= up * d.dot(up)
	if d.length() < 0.05:
		_vel = Vector3.ZERO
		return
	var dn := d.normalized()
	var along := dn
	var spd := speed
	if OrganicMotion.enabled and (org.w_path > 0.0005 or org.w_speed > 0.0005):
		# Expression bends the way it wants to go (straight in at the spot) and its pace.
		along = dn.rotated(up, org.yaw * smoothstep(0.3, 1.5, d.length()))
		spd *= org.speed
		if glide:
			heading = heading.slerp(along, clampf(dt * 4.0 * org.turn, 0.0, 1.0)).normalized()
			heading = (heading - up * heading.dot(up)).normalized()
			along = heading
	var step := along * minf(d.length(), spd * dt)
	# Stays in its patch and out of rock.
	var next := global_position + step
	if along != dn and step.length() > 0.0 and _walk_blocked(up, next, step):
		# (Blocked on its curve: the plain line, as without expression.)
		step = dn * minf(d.length(), spd * dt)
		next = global_position + step
	if step.length() <= 0.0 or _walk_blocked(up, next, step):
		_pick_target()
		_vel = Vector3.ZERO
		return
	_vel = step / dt
	heading = heading.slerp(dn if along == dn else along, clampf(dt * 4.0, 0.0, 1.0)).normalized()
	_snap(next)


## A step to `nx` would leave its patch or go into rock.
func _walk_blocked(up: Vector3, nx: Vector3, st: Vector3) -> bool:
	return not _in_patch(nx, 2.0) or line_blocked(global_position + up * 0.3, nx + up * 0.3 + st.normalized() * 0.3)


func _face(dir: Vector3, dt: float) -> void:
	if dir.length() > 0.01:
		heading = heading.slerp(dir.normalized(), clampf(dt * 5.0, 0.0, 1.0)).normalized()


func _update_body(_dt: float) -> void:
	var up := ball.up_at(global_position)
	heading = (heading - up * heading.dot(up)).normalized()
	if _trail.is_empty() or _trail[0].distance_to(global_position) > SPACING:
		_trail.push_front(global_position)
		while _trail.size() > SEGS + 1:
			_trail.pop_back()
	var rear := 0.0
	if state == "telegraph":
		rear = clampf(state_t / 0.3, 0.0, 1.0)
	for i in SEGS:
		var p: Vector3 = _trail[mini(i + 1, _trail.size() - 1)]
		var u := ball.up_at(p)
		var sc := lerpf(1.0, 0.45, float(i) / SEGS)
		var fwd := (_trail[mini(i, _trail.size() - 1)] - p)
		fwd = (fwd - u * fwd.dot(u)).normalized() if fwd.length() > 0.01 else heading
		_mm.set_instance_transform(i, Transform3D(Basis(fwd.cross(u).normalized(), u, -fwd).orthonormalized().scaled(Vector3(sc, sc * 0.7, sc * 1.4)),
				p + u * (0.16 + rear * 0.25 * maxf(0.0, 1.0 - i * 0.5))))
	var hp_ := global_position + up * (0.2 + rear * 0.6)
	var hb := Basis(heading.cross(up).normalized(), up, -heading).orthonormalized()
	if org != null and (org.look != 0.0 or org.lift != 0.0):
		# Expression, visual only: the head bobs and scans (its trail, which hit tests use, does not).
		hp_ += up * org.lift
		hb = Basis(up, org.look) * hb * Basis(Vector3.RIGHT, org.nod)
	_head.global_transform = Transform3D(hb, hp_)
	_frill.scale = Vector3(1.4, 0.8 + rear * 1.4, 0.2)


## Head and mid-body: the reeds part where it really is. The telegraph thrashes them.
func wake_points() -> Array:
	if defeated:
		return []
	var up := ball.up_at(global_position)
	var s := 0.35 + 0.6 * clampf(_vel.length() / 2.0, 0.0, 1.0)
	var jitter := Vector3.ZERO
	if state == "telegraph":
		s = 1.5
		jitter = heading.cross(up) * sin(state_t * 40.0) * 4.0
	var mid: Vector3 = _trail[mini(3, _trail.size() - 1)] if not _trail.is_empty() else global_position
	return [[global_position + up * 0.2, 0.8, _vel + jitter, s], [mid + up * 0.2, 0.7, _vel - jitter, s * 0.8]]


func is_hidden() -> bool:
	return defeated


func hittable() -> bool:
	return not defeated


func closest_body_point(pt: Vector3) -> Vector3:
	var best := global_position
	for q in _trail:
		if (q as Vector3).distance_to(pt) < best.distance_to(pt):
			best = q
	return best + ball.up_at(best) * 0.16


func body_extent() -> float:
	return 0.25


func hit(stages: int, _from_pos: Vector3) -> bool:
	if defeated:
		return false
	hp -= stages
	WaterFX.inst.sparkle(global_position + ball.up_at(global_position) * 0.3, Color(0.9, 0.85, 0.5, 0.9), 10, 1.4, 0.06, 0.6)
	if hp <= 0:
		defeated = true
		gone_at = Game.inst.clock.play_s
		visible = false
		Game.inst.critter_defeated(self)
		return true
	cooldown = COOLDOWN
	_go("flee")
	return true


## Back in its patch after a while, when the axolotl is elsewhere.
func _return() -> void:
	defeated = false
	visible = true
	hp = 2
	global_position = ball.surface_point(patch_dir)
	_snap(global_position)
	_trail.clear()
	for i in SEGS:
		_trail.append(global_position)
	_go("prowl")
	_pick_target()
