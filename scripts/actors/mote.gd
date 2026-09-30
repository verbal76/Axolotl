class_name Mote
extends Node3D
## Regeneration Mote: a tiny living bioluminescent spore-organism tied to one damaged
## patch. Wanders just above the moss, is nudged by water, must be caught with the lunge,
## and when caught dives into the moss (its light following it down) to restore the patch.

var ball: MossBall
var zone_id := ""
var anchor := Vector3.ZERO       # ground point it belongs to
var anchor_up := Vector3.UP
var wander := 2.2
var h_hint := 0.0
var state := "init"              # init wander captured done
var vel := Vector3.ZERO
var intensity := 1.0
var _target := Vector3.ZERO
var _retarget := 0.0
var _t := 0.0
var _dive_from := Vector3.ZERO
var _dive_to := Vector3.ZERO
var _core: MeshInstance3D
var _halo: MeshInstance3D
var _body: Node3D
var _bell: MeshInstance3D
var _limbs: MeshInstance3D
var _swim := 0.0
var _dir := Vector3.UP
## Mote Magnet (skill tree): seconds it ignores the pull after a missed lunge startled it, whether it
## is being drawn now, and its line of sight to him (re-read a few times a second).
var startle_t := 0.0
var magnet_on := false
var _los := false
var _los_t := 0.0
## How many times any Mote has run the Magnet (tests: never with no Magnet).
static var magnet_calls := 0


func setup(p_ball: MossBall, p_zone: String, dir: Vector3, h := 0.0, p_wander := 2.2) -> void:
	ball = p_ball
	zone_id = p_zone
	_dir = dir.normalized()
	h_hint = h
	wander = p_wander
	ball.register_event(zone_id)


func _ready() -> void:
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = Color(0.75, 1.0, 0.82)
	core_mat.emission_enabled = true
	core_mat.emission = Color(0.5, 1.0, 0.7)
	core_mat.emission_energy_multiplier = 4.0
	_core = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.06
	s.height = 0.1
	s.radial_segments = 10
	s.rings = 5
	_core.mesh = s
	_core.material_override = core_mat
	add_child(_core)
	# Soft glow (not a marker ring): additive billboard that fades with distance.
	_halo = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	_halo.mesh = q
	var hm := ShaderMaterial.new()
	hm.shader = preload("res://shaders/glow_billboard.gdshader")
	_halo.material_override = hm
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_halo)
	# The organism (Expansion 6): a soft glowing bell over the nucleus, and tentacles hanging below
	# that sway and trail as it swims. Turned to its ball's up each frame (_body).
	_body = Node3D.new()
	add_child(_body)
	_core.reparent(_body, false)
	_core.scale = Vector3.ONE * 0.6
	_bell = MeshInstance3D.new()
	var bs := SphereMesh.new()
	bs.radius = 0.1
	bs.height = 0.16
	bs.radial_segments = 14
	bs.rings = 7
	bs.is_hemisphere = true
	_bell.mesh = bs
	_bell.position = Vector3(0, -0.02, 0)
	var bm := ShaderMaterial.new()
	bm.shader = BELL_SHADER
	_bell.material_override = bm
	_bell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(_bell)
	_limbs = MeshInstance3D.new()
	_limbs.mesh = _tentacles()
	var lm := ShaderMaterial.new()
	lm.shader = LIMB_SHADER
	_limbs.material_override = lm
	_limbs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(_limbs)
	for mi in [_core, _halo, _bell, _limbs]:
		mi.visibility_range_end = 70.0


const BELL_SHADER := preload("res://shaders/mote_bell.gdshader")
const LIMB_SHADER := preload("res://shaders/mote_limb.gdshader")
static var _tent_mesh: ArrayMesh


## Six tapering tentacles from under the bell's rim, hanging down (-Y); UV.y root to tip, COLOR.r
## each one's phase. Shared by every mote.
static func _tentacles() -> ArrayMesh:
	if _tent_mesh != null:
		return _tent_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 6
	var rings := 7
	var sides := 4
	var base := 0
	for k in n:
		var a := TAU * k / n + 0.3
		var root := Vector3(cos(a) * 0.07, -0.02, sin(a) * 0.07)
		var length := 0.2 + 0.08 * float(k % 3)
		var start := base
		for j in rings:
			var t := float(j) / (rings - 1)
			var c := root + Vector3(cos(a) * 0.03 * t, -length * t, sin(a) * 0.03 * t)
			var r := lerpf(0.011, 0.002, t)
			for q in sides:
				var b := TAU * q / sides
				st.set_color(Color(float(k) / n, 0, 0))
				st.set_uv(Vector2(float(q) / sides, t))
				st.add_vertex(c + Vector3(cos(b) * r, 0, sin(b) * r))
				base += 1
		for j in rings - 1:
			for q in sides:
				var i0 := start + j * sides + q
				var i1 := start + j * sides + (q + 1) % sides
				for v in [i0, i0 + sides, i1, i1, i0 + sides, i1 + sides]:
					st.add_index(v)
	st.generate_normals()
	_tent_mesh = st.commit()
	return _tent_mesh


func is_available() -> bool:
	return state == "wander"


## The ground direction this mote belongs to (its restoration spot).
func home_dir() -> Vector3:
	return _dir


## Continuing a saved run: this mote was already returned to the moss. Gone at once, no effects.
func restore_done() -> void:
	state = "done"
	intensity = 0.0
	visible = false


func light_intensity() -> float:
	return intensity


func _physics_process(dt: float) -> void:
	if state == "done" or Game.paused_for_aquarium():
		return
	if state == "init":
		var top := ball.surface_point(_dir, h_hint + 3.0)
		# (Climbing leaves count: a Mote may perch high on a ladder of them, like the High Crown.)
		var q := PhysicsRayQueryParameters3D.create(top, ball.global_position, 1 | 2 | LevelBuilder.CLIMB_LAYER)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		anchor = hit.position if not hit.is_empty() else ball.surface_point(_dir)
		anchor_up = ball.up_at(anchor)
		global_position = anchor + anchor_up * 0.6
		_target = global_position
		state = "wander"
		return
	_t += dt
	if Game.inst.player.ball != ball:
		return
	if state == "wander" and not Game.inst.near_player(global_position):
		return
	match state:
		"wander":
			_update_wander(dt)
		"captured":
			var k := minf(1.0, _t / 0.8)
			global_position = _dive_from.lerp(_dive_to, k * k)
			intensity = 1.0 + (1.0 - k) * 1.5
			scale = Vector3.ONE * (1.0 - k * 0.7)
			if k >= 1.0:
				state = "done"
				intensity = 0.0
				visible = false
				Game.inst.mote_restored(self)
	# Swims by pulsing its bell (quicker when it moves); upright to its ball, leaning a little into
	# its motion; its tentacles trail behind (mote_limb.gdshader).
	var spd := vel.length()
	_swim += dt * (3.0 + spd * 4.0)
	var up := ball.up_at(global_position)
	var lean := (vel - up * vel.dot(up)) * 0.25
	var bup := (up + lean.limit_length(0.5)).normalized()
	var bx := bup.cross(Vector3.FORWARD if absf(bup.z) < 0.9 else Vector3.RIGHT).normalized()
	_body.global_basis = Basis(bx, bup, bx.cross(bup)).orthonormalized()
	var squeeze := sin(_swim) * 0.12
	_bell.scale = Vector3(1.0 + squeeze, 1.0 - squeeze * 1.3, 1.0 + squeeze)
	_limbs.set_instance_shader_parameter("drag", (_body.global_basis.inverse() * vel).limit_length(2.5))
	var pulse := 0.85 + 0.15 * sin(_t * 3.1) + 0.05 * sin(_t * 11.0)
	_core.scale = Vector3.ONE * 0.6 * pulse
	if state == "wander":
		intensity = pulse
	_bell.set_instance_shader_parameter("glow", intensity)
	_limbs.set_instance_shader_parameter("glow", intensity)


func _update_wander(dt: float) -> void:
	var up := ball.up_at(global_position)
	_retarget -= dt
	if _retarget <= 0.0 or global_position.distance_to(_target) < 0.25:
		_retarget = randf_range(1.2, 3.0)
		var b := MossBall.frame_at(anchor_up, randf() * 360.0)
		var off := (b.x * (randf() * 2.0 - 1.0) + b.z * (randf() * 2.0 - 1.0)) * wander
		_target = anchor + off + anchor_up * randf_range(0.35, 0.95)
	var steer := (_target - global_position).limit_length(1.0) * 1.4
	vel += steer * dt
	# Tiny currents and axolotl-made water movement push it around.
	vel += WaterFX.inst.push_at(global_position) * 3.5 * dt
	vel += ball.current_at(global_position) * 0.08 * dt
	vel += Vector3(sin(_t * 1.7), sin(_t * 2.3 + 1.0), cos(_t * 1.3)) * 0.25 * dt
	# Mote Magnet: drawn gently toward him (never into his mouth: only a lunge captures).
	var leash := wander * 1.6
	var pl: Axolotl = Game.inst.player
	if pl.magnet_range > 0.0:
		_magnet(dt, pl)
		if magnet_on:
			leash += pl.magnet_leash
	# Leash to its patch; keep hovering above the moss.
	var from_anchor := global_position - anchor
	var lateral := from_anchor - anchor_up * from_anchor.dot(anchor_up)
	if lateral.length() > leash:
		vel -= lateral.normalized() * (lateral.length() - leash) * 3.0 * dt
	var height := from_anchor.dot(anchor_up)
	if height < 0.3:
		vel += anchor_up * (0.3 - height) * 6.0 * dt
	elif height > 1.4:
		vel -= anchor_up * (height - 1.4) * 3.0 * dt
	vel = vel.limit_length(3.5)
	vel *= 1.0 - 0.9 * dt
	global_position += vel * dt


## Mote Magnet: within range and in plain sight of him (nothing solid between), on his ball, not over
## a ravine and not while startled, it drifts toward his head. No randomness is drawn (the seeded
## playthroughs stay identical), and with no Magnet this is never called.
func _magnet(dt: float, pl: Axolotl) -> void:
	magnet_calls += 1
	magnet_on = false
	if startle_t > 0.0:
		startle_t -= dt
		return
	if pl.state != "normal" or pl.ball != ball:
		return
	var to := pl.head_position() - global_position
	var d := to.length()
	if d > pl.magnet_range or d < 0.45:
		return
	if ball.ravine_carve(ball.up_at(global_position)) > 0.15 or ball.ravine_carve(pl.up) > 0.15:
		return
	_los_t -= dt
	if _los_t <= 0.0:
		_los_t = 0.2
		var q := PhysicsRayQueryParameters3D.create(global_position, pl.body_center(), 1 | 2 | LevelBuilder.CLIMB_LAYER)
		_los = get_world_3d().direct_space_state.intersect_ray(q).is_empty()
	if not _los:
		return
	magnet_on = true
	# (Stronger the nearer he is inside the range, easing off right by his mouth.)
	var k := clampf(1.0 - d / pl.magnet_range, 0.0, 1.0) * 0.6 + 0.4
	vel += to / d * pl.magnet_accel * k * dt


## A missed lunge startles it out of the Magnet's pull for a moment.
func startle(seconds: float) -> void:
	startle_t = maxf(startle_t, seconds)
	magnet_on = false


## Water pressure from a near-miss lunge: pushed like a floating object in a pool.
func push(v: Vector3) -> void:
	if state == "wander":
		vel += v


func capture() -> void:
	if state != "wander":
		return
	state = "captured"
	_t = 0.0
	_dive_from = global_position
	var up := ball.up_at(global_position)
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position - up * 4.0, 1 | 2 | LevelBuilder.CLIMB_LAYER)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	_dive_to = (hit.position if not hit.is_empty() else anchor) - up * 0.25
