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
## Simulated time for cosmetic motion (the ripple runs on continuously instead of restarting with
## each state).
var _clock := 0.0


var _probe_from := Vector3.ZERO
var _probe_dir := Vector3.FORWARD
var _probe_len := 10.0
var _cave_r := 8.0

## Where Gill can stand to fight it (cohesion audit P7): on the grotto floor, straight out in front
## of the crevice, a little beyond the reach of its strike, so it strikes at him, its head fully out
## lands inside his swipe, and he can walk there from the grotto's door. Set by late_place.
var stand := Vector3.ZERO
## How far round the grotto wall (degrees) from the place it was given late_place moved it (0: kept).
var placed_deg := 0.0
## The grotto it lives in: floor centre, door, and the tops of its climb's ledges (the strike guards
## the floor; it must never see him up on the climb).
var _floor_c := Vector3.INF
var _door := Vector3.INF
var _ledge_tops: Array[Vector3] = []
## Its cleft shows once he is in its grotto: a faint glowing lip and a bubble now and then
## (0 .. 1, eased in and out).
var _cue := 0.0
var _cue_bubble_t := 0.6
var _lip_mat: StandardMaterial3D
## The rock's own surface normal at the crevice (the cleft and its lip lie flat on it).
var _wall_n := Vector3.ZERO

## Wall positions tried, in steps of CANDIDATE_STEP degrees either side of the one it was given,
## until the crevice has a clear strike line and a spot to be fought from.
const CANDIDATE_STEP := 8.0
const CANDIDATES := 9
## Kept this far round from the grotto's door (degrees), so the strike never guards the way in.
const DOOR_CLEAR_DEG := 55.0
## Distances straight out from the crevice (along the floor) tried for the stand spot.
const STAND_DISTS := [2.95, 2.8, 3.1, 3.3]
## The cleft's lip at full cue (emission energy), in the eyes' colour family, dimmer.
const LIP_GLOW := 0.9
const LIP_COLOR := Color(0.62, 0.85, 0.32)
## Seconds between the cleft's bubbles while he is in its grotto and it hides.
const CUE_BUBBLE_S := 2.4
## He counts as in its grotto within this much of the cave's radius from its floor centre.
const GROTTO_IN := 0.95


## Lives in the wall found from `from` (inside the cave) along `dir` (see late_place). `grotto` is
## the cave's bot hint (centre, door, ledges) when known.
func place(p_ball: MossBall, from: Vector3, dir: Vector3, cave_radius: float, seed_v: int, grotto := {}) -> void:
	setup(p_ball, "eel", "grotto wall", seed_v)
	org = OrganicMotion.new(rng.seed, OrganicMotion.EEL)
	hp = 2
	seen_radius = 4.5
	p_ball.add_child(self)
	_probe_from = from
	_probe_dir = dir.normalized()
	_probe_len = cave_radius + 3.0
	_cave_r = cave_radius
	mouth = from + _probe_dir * (cave_radius - 1.5)
	normal = -_probe_dir
	global_position = mouth
	_dir = normal
	if not grotto.is_empty():
		_floor_c = p_ball.surface_point(p_ball.up_at(grotto["centre"]), 0.0)
		_door = grotto["door"]
		for l in grotto.get("ledges", []):
			var lp: Vector3 = (l as Node3D).global_position
			_ledge_tops.append(lp + p_ball.up_at(lp) * float((l as Node3D).get_meta("top", 0.0)))
	visible = false


func late_place() -> void:
	var space := get_world_3d().direct_space_state
	var up := ball.up_at(_probe_from)
	var first := {}
	var chosen := {}
	# The wall it was given first, then further round either way (never toward the door), until
	# the crevice strikes clear of the grotto's ledges and has a spot in front to be fought from.
	for k in CANDIDATES * 2 - 1:
		var step := (k + 1) / 2 * (1 if k % 2 == 1 else -1)
		var d := _probe_dir.rotated(up, deg_to_rad(step * CANDIDATE_STEP))
		if _door != Vector3.INF and k > 0:
			var to_door := _door - _probe_from
			to_door -= up * to_door.dot(up)
			if rad_to_deg(d.angle_to(to_door.normalized())) < DOOR_CLEAR_DEG:
				continue
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(_probe_from, _probe_from + d * _probe_len, SOLID_MASK))
		if hit.is_empty() or (hit["position"] as Vector3).distance_to(_probe_from) > _cave_r - 0.4:
			# (No wall, or out through the doorway: not a crevice.)
			if k == 0:
				first = {"mouth": _probe_from + d * (_cave_r - 1.5) if hit.is_empty() else hit["position"], "normal": -d, "step": 0}
			continue
		# The wall faces back into the cave (the surface is two-sided, so its reported normal may not).
		var wn: Vector3 = hit["normal"]
		var cand := {"mouth": hit["position"], "normal": -d, "step": step, "wall": wn if wn.dot(-d) >= 0.0 else -wn}
		if k == 0:
			first = cand
		if _floor_c == Vector3.INF:
			chosen = cand
			break
		var st := _stand_for(cand["mouth"], -d)
		if st != Vector3.INF and not _sees_ledges(cand["mouth"], -d):
			cand["stand"] = st
			chosen = cand
			break
	if chosen.is_empty():
		chosen = first
	mouth = chosen["mouth"]
	normal = chosen["normal"]
	_wall_n = chosen.get("wall", normal)
	placed_deg = float(chosen["step"]) * CANDIDATE_STEP
	stand = chosen.get("stand", ball.surface_point(ball.up_at(mouth + normal * (STRIKE_REACH + 0.45)), 0.0))
	global_position = mouth
	_dir = normal
	visible = true
	_build()
	_pose()


## The first distance straight out from a crevice at `m` (facing `n`) that is a fair place to fight
## it from (_spot_ok), or INF.
func _stand_for(m: Vector3, n: Vector3) -> Vector3:
	for dist in STAND_DISTS:
		var s := ball.surface_point(ball.up_at(m + n * float(dist)), 0.0)
		if _spot_ok(m, n, s):
			return s
	return Vector3.INF


## Gill standing at `s`: on the grotto's floor with room round him, walkable from the door, seen by
## a crevice at `m` (facing `n`) whose whole strike line is clear of rock and ledges and ends inside
## his swipe without touching him.
func _spot_ok(m: Vector3, n: Vector3, s: Vector3) -> bool:
	var up := ball.up_at(s)
	var c := s + up * 0.25
	if s.distance_to(_floor_c) > _cave_r - 2.0:
		return false
	var space := get_world_3d().direct_space_state
	var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(s + up * 2.2, s - up * 0.5, SOLID_MASK))
	if floor_hit.is_empty() or (floor_hit["position"] as Vector3).distance_to(s) > 0.15:
		return false
	var side := n.cross(up).normalized()
	for o in [side * 0.5, -side * 0.5, n * 0.5]:
		if line_blocked(s + up * 0.3, s + up * 0.3 + o):
			return false
	var lift := up * 0.35
	var mid := _floor_c + ball.up_at(_floor_c) * 0.35
	if line_blocked(_door + lift, s + lift) and (line_blocked(_door + lift, mid) or line_blocked(mid, s + lift)):
		return false
	var to := c - m
	if to.length() > NOTICE_R - 0.2 or to.normalized().dot(n) < 0.3 or line_blocked(m + n * 0.25, c):
		return false
	var aim := _aim_from(m, n, c)
	if line_blocked(m + aim * 0.2, m + aim * (STRIKE_REACH + 0.2)):
		return false
	var tip := m + aim * STRIKE_REACH
	var ab := tip - m
	var k := clampf((c - m).dot(ab) / ab.length_squared(), 0.0, 1.0)
	var gap := c.distance_to(m + ab * k)
	return gap > CONTACT_R + 0.08 and gap < Game.SWIPE_REACH + body_extent() - 0.3 and not line_blocked(c, tip)


## A crevice at `m` (facing `n`) would see him standing on one of its grotto's ledges.
func _sees_ledges(m: Vector3, n: Vector3) -> bool:
	for lt in _ledge_tops:
		var c := lt + ball.up_at(lt) * 0.25
		var to := c - m
		if to.length() <= NOTICE_R + 0.3 and to.normalized().dot(n) >= 0.2 and not line_blocked(m + n * 0.25, c):
			return true
	return false


func _build() -> void:
	# The crevice (a dark cleft, visible even when the eel hides), the body as one batch of
	# segments, the head, and the glowing eyes (their own material: they brighten as it notices him).
	var up := ball.up_at(mouth)
	var cleft := Node3D.new()
	add_child(cleft)
	# (Flat on the rock's own surface there: the vault may lean in over the crevice.)
	var wn := _wall_n if _wall_n.dot(normal) > 0.3 else normal
	var wx := wn.cross(up).normalized()
	cleft.global_transform = Transform3D(Basis(wx, wx.cross(wn).normalized(), wn), mouth - wn * 0.02)
	Critter.part(Critter.sphere(0.3, 10), Critter.mat(Color(0.02, 0.02, 0.02)), cleft, Vector3.ZERO, Vector3(0.9, 1.3, 0.12))
	# Its lip (cohesion audit P7): a thin ring round the cleft that glows faintly, in the eyes'
	# colour, once he is in its grotto, as if light seeped from the crevice. Dark otherwise.
	var lip := TorusMesh.new()
	lip.inner_radius = 0.25
	lip.outer_radius = 0.31
	lip.rings = 20
	lip.ring_segments = 6
	_lip_mat = Critter.mat(Color(0.05, 0.06, 0.03), LIP_COLOR)
	_lip_mat.emission_energy_multiplier = 0.0
	var lip_mi := Critter.part(lip, _lip_mat, cleft)
	lip_mi.transform = Transform3D(Basis.from_scale(Vector3(1.0, 1.42, 0.5)) * Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, 0.035))
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
	_clock += dt
	# Expression (OrganicMotion), cosmetic only: hidden or resting it sways its head in the cleft and
	# now and then peeks a little further out; noticing him and striking, none (its aim, reach and
	# timing never change).
	if state in ["hidden", "cooldown"]:
		org.step(dt, 1.0, 0.0, 1.0)
	else:
		org.step(dt, 0.0, 0.0, 0.0, true)
	var p := player()
	_update_cue(dt, p)
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


## Readability (cohesion audit P7): with him in its grotto, the cleft's lip glows faintly (a slow
## breath) and, while it hides, a couple of bubbles rise from it every few seconds, so "which wall
## is it in" has an answer before it strikes. Cosmetic: no random draws, no effect on its timing.
func _update_cue(dt: float, p: Axolotl) -> void:
	var inside := player_here() and _floor_c != Vector3.INF and p.global_position.distance_to(_floor_c) < _cave_r * GROTTO_IN
	_cue = move_toward(_cue, 1.0 if inside else 0.0, dt * (0.8 if inside else 1.5))
	if inside and state in ["hidden", "cooldown"]:
		_cue_bubble_t -= dt
		if _cue_bubble_t <= 0.0:
			_cue_bubble_t = CUE_BUBBLE_S + 0.5 * sin(_clock * 0.7 + float(rng.seed % 97))
			WaterFX.inst.bubbles(mouth + normal * 0.15, ball.up_at(mouth), 2)
	_lip_mat.emission_energy_multiplier = cleft_glow()


## How brightly the cleft's lip glows now (emission energy; 0 when he is away or it is beaten).
func cleft_glow() -> float:
	if defeated or _lip_mat == null:
		return 0.0
	return _cue * LIP_GLOW * (0.8 + 0.2 * sin(_clock * 1.6))


func set_active(on: bool) -> void:
	super.set_active(on)
	if not on:
		_cue = 0.0
		if _lip_mat != null:
			_lip_mat.emission_energy_multiplier = 0.0


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
	return _aim_from(mouth, normal, target)


func _aim_from(m: Vector3, n: Vector3, target: Vector3) -> Vector3:
	var d := (target - m).normalized()
	var ang := d.angle_to(n)
	if ang > deg_to_rad(50.0):
		var axis := n.cross(d).normalized()
		d = n.rotated(axis, deg_to_rad(50.0))
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
	if ext < 0.05 and org != null:
		head += normal * clampf(org.lift, 0.0, 0.05)
	# Head first, then back into the crevice (the body shader runs head to tail).
	var pts := PackedVector4Array()
	var ups := PackedVector4Array()
	pts.resize(Parasite.MAX_SEGS)
	ups.resize(Parasite.MAX_SEGS)
	for i in SEGS + 1:
		var k := 1.0 - float(i) / SEGS
		var p := tail.lerp(head, k)
		# A sideways ripple along the body while it is out.
		var rt := _clock if OrganicMotion.enabled else state_t
		p += _dir.cross(up).normalized() * sin(k * 9.0 - rt * 12.0) * 0.06 * clampf(ext, 0.0, 1.0) * (1.0 - k * 0.6)
		pts[i] = Vector4(p.x, p.y, p.z, 0.15 * lerpf(1.05, 0.85, float(i) / SEGS))
		ups[i] = Vector4(up.x, up.y, up.z, 0.0)
	_segs_mi.global_position = head
	_body_mat.set_shader_parameter("pts", pts)
	_body_mat.set_shader_parameter("ups", ups)
	_segs_mi.visible = ext > 0.05 and not defeated
	var look := _dir if ext > 0.05 else normal
	var hb := Basis(look.cross(up).normalized(), up, -look).orthonormalized()
	if org != null and (org.look != 0.0 or org.nod != 0.0):
		hb = Basis(up, org.look) * hb * Basis(Vector3.RIGHT, org.nod)
	_head.global_transform = Transform3D(hb, head)
	_head.visible = not defeated
	var glow := 0.25
	if state == "alert":
		glow = 1.0 + 0.8 * sin(state_t * 30.0)
	elif state in ["strike", "hold", "retract"]:
		glow = 1.6
	_eye_mat.emission_energy_multiplier = glow
	if defeated and _lip_mat != null:
		_lip_mat.emission_energy_multiplier = 0.0


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
	# (v107: its own hit sound: a startled burst of bubbles.)
	if Juice.enabled:
		Sfx.play("eel_bubbles", mouth + _dir * ext, -5.0, 0.06, 1.3)
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
