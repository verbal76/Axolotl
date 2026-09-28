class_name Axolotl
extends CharacterBody3D
## The player. Sphere-centred gravity locomotion with camera-relative input, a push-off
## jump, a once-per-airborne directional water burst, tail swipe, feeding lunge, hard and
## extreme landings, and health shown by the six gills.

signal health_changed(health: int, max_health: int)
signal died
signal jumped
signal burst_used
signal landed(kind: String)
signal swiped
signal lunged

const RUN_SPEED := 6.2
const ACCEL := 40.0
const DECEL := 32.0
const AIR_ACCEL := 17.0
const GRAVITY := 20.0
const JUMP_V := 8.6
const TERMINAL := 24.0
const COYOTE := 0.12
const BUFFER := 0.15
const BURST_H := 8.8
const BURST_UP := 5.2
const BURST_UP_ONLY := 8.4
const LUNGE_SPEED := 11.0
const LUNGE_TIME := 0.28
const SWIPE_TIME := 0.3
const HARD_FALL := 3.4
const EXTREME_FALL := 13.0
const BODY_RADIUS := 0.3
## The head: the axolotl's body collides as one sphere, but his head reaches HEAD_REACH ahead of it.
## After each move the head guard keeps this sphere out of walls and ceilings (see _guard_head).
const HEAD_REACH := 0.4
const HEAD_HEIGHT := 0.28
const HEAD_RADIUS := 0.17

var ball: MossBall
var cam: Node3D                  # FollowCam
var up := Vector3.UP
var facing := Vector3.FORWARD
var controls_enabled := true
var state := "normal"            # normal | dead | cinematic

var max_health := 3
var health := 3

var grounded := false
var coyote_t := 0.0
var buffer_t := 0.0
var burst_available := true
var air_time := 0.0
var apex_r := 0.0
var swipe_t := -1.0
var _swipe_aim := Vector3.ZERO
var swipe_cd := 0.0
var lunge_t := -1.0
var lunge_cd := 0.0
var lunge_hit := false
var _lunge_food: Food = null      # what the lunge is homing in on, if anything
var invuln_t := 0.0
var hurt_lock := 0.0
var land_lock := 0.0
var last_safe_pos := Vector3.ZERO
var last_safe_ball: MossBall
var fall_danger := false
var move_input := Vector2.ZERO
var bot_input := Vector2.ZERO    # used by the automated test bot
var use_bot_input := false
var ext_vel := Vector3.ZERO      # external water pull (e.g. an open vortex's suction)
var _last_land_variant := -1
var _landing_speed := 0.0
var _jumped_this_frame := false
var _stream_t := 0.0
var _acted := false               # a jump, swipe or lunge was pressed this frame

var model: AxolotlModel
var blob_shadow: MeshInstance3D


func _ready() -> void:
	collision_layer = 4
	# Terrain, platforms and climbing leaves (LevelBuilder.CLIMB_LAYER).
	collision_mask = 1 | 2 | LevelBuilder.CLIMB_LAYER
	floor_max_angle = deg_to_rad(52)
	floor_snap_length = 0.35
	floor_constant_speed = true
	floor_block_on_wall = false
	safe_margin = 0.02
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = BODY_RADIUS
	cs.shape = sph
	cs.position = Vector3(0, BODY_RADIUS, 0)
	add_child(cs)
	model = AxolotlModel.new()
	add_child(model)
	MossBall.mark_caster.call_deferred(model)
	blob_shadow = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.1, 1.1)
	q.orientation = PlaneMesh.FACE_Y
	blob_shadow.mesh = q
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://shaders/blob_shadow.gdshader")
	blob_shadow.material_override = sm
	blob_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blob_shadow.top_level = true
	add_child(blob_shadow)


func place(p_ball: MossBall, pos: Vector3, face_dir := Vector3.ZERO) -> void:
	ball = p_ball
	up = ball.up_at(pos)
	global_position = pos
	if face_dir != Vector3.ZERO:
		facing = (face_dir - up * face_dir.dot(up)).normalized()
	else:
		facing = (facing - up * facing.dot(up)).normalized()
		if facing.length() < 0.1:
			facing = MossBall.frame_at(up, 0).z * -1.0
	velocity = Vector3.ZERO
	_apply_orientation(1.0)
	apex_r = _r()
	last_safe_pos = pos
	last_safe_ball = ball


func _r() -> float:
	return (global_position - ball.global_position).length()


func _lunge_target_valid() -> bool:
	return _lunge_food != null and is_instance_valid(_lunge_food) and _lunge_food.is_catchable()


var _head_q: PhysicsShapeQueryParameters3D


## Centre of the head's collision sphere.
func head_center() -> Vector3:
	return global_position + up * HEAD_HEIGHT + facing * HEAD_REACH


## Keeps the head out of walls and ceilings: its sphere is tested after each move and, where it
## overlaps solid terrain, he is moved back out along the contact (and stops moving into it).
## Walkable floors and slopes under the head are left to the body (a slope rising ahead is walked
## up, not pushed away from), so traversal is unchanged; only the visible head no longer enters walls.
func _guard_head() -> void:
	var space := get_world_3d().direct_space_state
	if _head_q == null:
		_head_q = PhysicsShapeQueryParameters3D.new()
		var sph := SphereShape3D.new()
		sph.radius = HEAD_RADIUS
		_head_q.shape = sph
		_head_q.collision_mask = collision_mask
		_head_q.exclude = [get_rid()]
	var q := _head_q
	for i in 3:
		q.transform = Transform3D(Basis(), head_center())
		var pts := space.collide_shape(q, 8)
		var push := Vector3.ZERO
		for k in range(0, pts.size(), 2):
			# Pairs: the deepest point of the head inside the terrain, and the terrain surface.
			var out: Vector3 = pts[k + 1] - pts[k]
			if out.length() < 0.001:
				continue
			var n := out.normalized()
			if n.dot(up) > cos(floor_max_angle):
				continue   # ground he can stand on: the body handles floors and slopes
			if n.dot(up) < -0.3:
				# Ceiling: back away from it rather than into the floor.
				var back := -facing
				out = back * out.length() / maxf(0.35, -n.dot(up))
				n = back
			if out.length() > push.length():
				push = out
		if push == Vector3.ZERO:
			return
		global_position += push
		var pn := push.normalized()
		var into := velocity.dot(pn)
		if into < 0.0:
			velocity -= pn * into


func head_position() -> Vector3:
	return global_position + up * 0.25 + facing * 0.55


func body_center() -> Vector3:
	return global_position + up * 0.25


# --- Main loop ---------------------------------------------------------------------------

func _physics_process(dt: float) -> void:
	if ball == null or state != "normal":
		model.idle_ok = false
		_update_shadow()
		return
	_jumped_this_frame = false
	up = ball.up_at(global_position)
	up_direction = up

	# Timers.
	coyote_t = maxf(0.0, coyote_t - dt)
	buffer_t = maxf(0.0, buffer_t - dt)
	swipe_cd = maxf(0.0, swipe_cd - dt)
	lunge_cd = maxf(0.0, lunge_cd - dt)
	invuln_t = maxf(0.0, invuln_t - dt)
	hurt_lock = maxf(0.0, hurt_lock - dt)
	land_lock = maxf(0.0, land_lock - dt)

	# Input.
	var stick := Vector2.ZERO
	if controls_enabled:
		stick = bot_input if use_bot_input else Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	move_input = stick
	var wish := _camera_relative(stick)
	var want_jump := controls_enabled and Input.is_action_just_pressed("jump")
	var want_swipe := controls_enabled and Input.is_action_just_pressed("swipe")
	var want_lunge := controls_enabled and Input.is_action_just_pressed("lunge")
	_acted = want_jump or want_swipe or want_lunge

	var vup := velocity.dot(up)
	var vh := velocity - up * vup

	# Facing follows intended direction (not during a lunge).
	if wish.length() > 0.08 and lunge_t < 0.0:
		var turn := 14.0 if grounded else 7.0
		facing = _slerp_tangent(facing, wish.normalized(), minf(1.0, turn * dt))
	facing = (facing - up * facing.dot(up)).normalized()

	# Horizontal movement.
	var control := 1.0
	if hurt_lock > 0.0:
		control = 0.35
	if land_lock > 0.0:
		control = 0.5
	var target := wish * RUN_SPEED * control
	# Turning to aim on the ground (Expansion 6, owner phone report): from a standstill he turns on
	# the spot until he faces (within about 25 degrees) where the stick points, then sets off; so
	# landing, turning and lining up the next jump on a leaf does not walk him off it. Running, a
	# sharp change of direction only eases off while he swings round; curving is unaffected.
	if grounded and wish.length() > 0.08 and lunge_t < 0.0:
		var align := facing.dot(wish.normalized())
		if vh.length() < 1.5:
			target *= smoothstep(0.55, 0.92, align)
		else:
			target *= lerpf(0.15, 1.0, smoothstep(-0.2, 0.75, align))
	var accel := (ACCEL if wish.length() > 0.05 else DECEL) if grounded else AIR_ACCEL
	if lunge_t >= 0.0:
		lunge_t += dt / LUNGE_TIME
		if _lunge_target_valid():
			var flat := _lunge_food.catch_point() - global_position
			flat -= up * flat.dot(up)
			if flat.length() > 0.2:
				facing = _slerp_tangent(facing, flat.normalized(), minf(1.0, 25.0 * dt))
		vh = facing * LUNGE_SPEED * (1.0 - lunge_t * 0.5)
		if not lunge_hit:
			lunge_hit = Game.inst.lunge_contact(self)
		if lunge_t >= 1.0:
			lunge_t = -1.0
			_lunge_food = null
			if not lunge_hit:
				Game.inst.lunge_miss(self)
	else:
		vh = vh.move_toward(target, accel * dt)

	# Gravity.
	if not grounded:
		vup = maxf(vup - GRAVITY * dt, -TERMINAL)
		air_time += dt
	else:
		air_time = 0.0
		vup = minf(vup, 0.0) - 1.5
	# The lunge rises or dips so the mouth meets food floating above or below it.
	if lunge_t >= 0.0 and not lunge_hit and _lunge_target_valid():
		var dh := (_lunge_food.catch_point() - head_position()).dot(up)
		if absf(dh) > 0.1:
			vup = clampf(dh / 0.12, -8.0, 10.0)

	# Jump / water burst / buffering.
	if want_jump:
		if grounded or coyote_t > 0.0:
			vup = _do_jump()
		elif burst_available:
			var b := _do_burst(wish)
			vh = b[0]
			vup = b[1]
		else:
			buffer_t = BUFFER
	elif buffer_t > 0.0 and grounded:
		buffer_t = 0.0
		vup = _do_jump()

	# Actions.
	if want_swipe and swipe_cd <= 0.0 and lunge_t < 0.0:
		swipe_t = 0.0
		swipe_cd = SWIPE_TIME + 0.08
		_swipe_aim = Game.inst.swipe_aim(self)
		if _swipe_aim != Vector3.ZERO:
			model.swipe_side = signf(facing.cross(_swipe_aim).dot(up))
		else:
			model.swipe_side = 1.0 if randf() < 0.5 else -1.0
		swiped.emit()
		WaterFX.inst.impulse(global_position + up * 0.3 - facing * 0.6, 1.3, 0.5)
	if swipe_t >= 0.0:
		# Aim assist: whip the body round during the wind-up, before the hit frame.
		if _swipe_aim != Vector3.ZERO and swipe_t < 0.3:
			_swipe_aim = (_swipe_aim - up * _swipe_aim.dot(up)).normalized()
			facing = _slerp_tangent(facing, _swipe_aim, minf(1.0, 30.0 * dt))
		var prev := swipe_t
		swipe_t += dt / SWIPE_TIME
		if prev < 0.3 and swipe_t >= 0.3:
			Game.inst.player_swipe(self)
		if swipe_t >= 1.0:
			swipe_t = -1.0
	if want_lunge and lunge_cd <= 0.0 and lunge_t < 0.0:
		lunge_t = 0.0
		lunge_hit = false
		lunge_cd = LUNGE_TIME + 0.15
		lunged.emit()
		if wish.length() > 0.2:
			facing = wish.normalized()
		_lunge_food = Game.inst.lunge_target(self, facing)

	var cur := ball.current_at(global_position) * (0.45 if grounded else 1.0) + ext_vel
	velocity = vh + up * vup + cur
	var was_grounded := grounded
	var pre_vup := vup
	move_and_slide()
	_guard_head()
	velocity -= cur
	grounded = is_on_floor()
	if _jumped_this_frame:
		grounded = false

	var r := _r()
	if grounded:
		var fc := _floor_collider()
		if fc and fc.has_method("stepped"):
			fc.stepped()
		if not was_grounded:
			_on_land(-pre_vup, r)
		apex_r = r
		coyote_t = 0.0
		if _floor_is_stable():
			last_safe_pos = global_position
			last_safe_ball = ball
	else:
		if was_grounded and not _jumped_this_frame:
			coyote_t = COYOTE
		apex_r = maxf(apex_r, r)

	# Dangerous-fall telegraph: body language only, no UI.
	var fall := apex_r - r
	fall_danger = not grounded and fall > EXTREME_FALL - 0.6 and velocity.dot(up) < -6.0
	if fall_danger:
		_stream_t -= dt
		if _stream_t <= 0.0:
			_stream_t = 0.05
			WaterFX.inst.stream(global_position + up * 0.3, up, 1.0)
	elif not grounded and velocity.dot(up) < -12.0:
		_stream_t -= dt
		if _stream_t <= 0.0:
			_stream_t = 0.12
			WaterFX.inst.stream(global_position + up * 0.3, up, 0.4)

	# Fast movement stirs the water.
	if grounded and vh.length() > RUN_SPEED * 0.8:
		WaterFX.inst.trail(global_position, 0.35)

	# Safety net: never fall inside a moss ball.
	if r < ball.radius - 1.5:
		place(last_safe_ball, last_safe_pos + ball.up_at(last_safe_pos) * 0.5)

	_apply_orientation(minf(1.0, dt * 20.0))
	_update_model(dt)
	_update_shadow()


func _floor_is_stable() -> bool:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var col := c.get_collider()
		if col and (col.has_meta("unsafe") or col is AnimatableBody3D):
			return false
	return true


func _floor_collider() -> Object:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_normal().dot(up) > 0.5:
			return c.get_collider()
	return null


func _do_jump() -> float:
	_jumped_this_frame = true
	coyote_t = 0.0
	buffer_t = 0.0
	grounded = false
	apex_r = _r()
	jumped.emit()
	WaterFX.inst.impulse(global_position, 1.0, 0.35)
	Sfx.play("jump", global_position)
	return JUMP_V


## Returns [horizontal velocity, vertical velocity].
func _do_burst(wish: Vector3) -> Array:
	burst_available = false
	var vh: Vector3
	var vup: float
	if wish.length() > 0.2:
		vh = wish.normalized() * BURST_H
		vup = BURST_UP
		facing = wish.normalized()
	else:
		vh = facing * 1.5
		vup = BURST_UP_ONLY
	apex_r = _r()   # a burst "saves" the fall: distance is measured from here
	model.burst_t = 0.0
	burst_used.emit()
	WaterFX.inst.impulse(global_position - facing * 0.4, 2.2, 0.6)
	WaterFX.inst.burst_fx(global_position + up * 0.2, -(vh.normalized() if vh.length() > 0.1 else up), up)
	Sfx.play("burst", global_position)
	return [vh, vup]


func _on_land(impact: float, r: float) -> void:
	burst_available = true
	var fall := apex_r - r
	var col := _floor_collider()
	if col and col.has_method("absorb"):
		# Flexible vegetation cushions the fall.
		col.absorb(self, impact, fall)
		model.land_t = -1.0
		landed.emit("leaf")
		Sfx.play("leaf_bend", global_position)
		return
	if fall >= EXTREME_FALL:
		_superhero_landing(true)
		landed.emit("extreme")
	elif fall >= HARD_FALL:
		_superhero_landing(false)
		landed.emit("hard")
	else:
		if impact > 5.0:
			WaterFX.inst.impulse(global_position, 0.6, 0.3)
		Sfx.play("land_soft", global_position, -8.0 + minf(impact, 8.0))
		landed.emit("soft")


func _superhero_landing(extreme: bool) -> void:
	var v := randi() % 4
	if v == _last_land_variant:
		v = (v + 1 + randi() % 3) % 4
	_last_land_variant = v
	model.play_land(v, 1.4 if extreme else 1.0)
	land_lock = 0.25
	var radius := 4.4 if extreme else 2.8
	var stages := 2 if extreme else 1
	if extreme:
		# Environmental fall damage may never remove the final segment.
		if health > 1:
			health -= 1
			model.set_health(health, max_health, true)
			health_changed.emit(health, max_health)
		model.fall_flicker()
		Settings.haptic("heavy")
		Sfx.play("land_extreme", global_position)
	else:
		Settings.haptic("land")
		Sfx.play("land_hard", global_position)
	WaterFX.inst.impulse(global_position, 3.0 if extreme else 2.0, 0.8)
	WaterFX.inst.landing_ring(global_position, up, radius)
	Game.inst.pressure_wave(self, global_position, radius, stages)
	if cam and cam.has_method("shake"):
		cam.shake(0.25 if extreme else 0.12)


# --- Damage / health ---------------------------------------------------------------------

## Where the last hit came from (diagnostics and tests).
var last_hit_from := Vector3.ZERO


func take_damage(amount: int, from_pos: Vector3) -> void:
	# (Never while his controls are taken away, e.g. the vortex-connection shot: the playthrough
	# found a parasite hitting him four times while he could not move.)
	if state != "normal" or invuln_t > 0.0 or not controls_enabled:
		return
	health = maxi(0, health - amount)
	last_hit_from = from_pos
	invuln_t = 1.3
	hurt_lock = 0.3
	model.hurt_t = 0.0
	model.set_health(health, max_health, true)
	health_changed.emit(health, max_health)
	var away := global_position - from_pos
	away -= up * away.dot(up)
	velocity = away.normalized() * 5.0 + up * 3.5
	grounded = false
	Settings.haptic("hurt")
	Sfx.play("hurt", global_position)
	if health <= 0:
		died.emit()


## Rebound from a springy leaf: a modest upward push (never a trampoline).
func leaf_rebound(v: float) -> void:
	velocity += up * v
	grounded = false
	_jumped_this_frame = true
	apex_r = _r()
	WaterFX.inst.impulse(global_position, 1.2, 0.4)


func heal(amount: int) -> void:
	if amount <= 0:
		return
	var before := health
	health = mini(max_health, health + amount)
	if health != before:
		model.set_health(health, max_health, true)
		health_changed.emit(health, max_health)


func restore_full() -> void:
	health = max_health
	model.set_health(health, max_health, true)
	health_changed.emit(health, max_health)


func add_max_health() -> void:
	max_health = mini(6, max_health + 1)
	health = max_health
	model.set_health(health, max_health, true)
	health_changed.emit(health, max_health)


# --- Helpers -----------------------------------------------------------------------------

func _camera_relative(stick: Vector2) -> Vector3:
	if stick.length() < 0.05 or cam == null:
		return Vector3.ZERO
	var cf: Vector3 = -cam.global_basis.z
	cf = cf - up * cf.dot(up)
	if cf.length() < 0.05:
		cf = cam.global_basis.y - up * cam.global_basis.y.dot(up)
	cf = cf.normalized()
	var cr := cf.cross(up)
	var v := cr * stick.x + cf * stick.y
	return v.limit_length(1.0)


func _slerp_tangent(a: Vector3, b: Vector3, t: float) -> Vector3:
	var ang := a.signed_angle_to(b, up)
	return a.rotated(up, ang * t)


func _apply_orientation(t: float) -> void:
	var right := facing.cross(up).normalized()
	var target := Basis(right, up, -facing).orthonormalized()
	global_basis = global_basis.orthonormalized().slerp(target, t) if t < 1.0 else target


func _update_model(_dt: float) -> void:
	var vh := velocity - up * velocity.dot(up)
	model.speed = vh.length() / RUN_SPEED
	model.grounded = grounded
	model.vup = velocity.dot(up)
	model.swipe_t = swipe_t
	model.lunge_t = lunge_t
	model.brace = move_toward(model.brace, 1.0 if fall_danger else 0.0, 0.1)
	model.idle_ok = idle_allowed()
	if cam:
		model.camera_pos = cam.global_position


## Whether the model may play an idle: he is standing still on the ground under the player's
## control with nothing else going on (no input, action, landing, hit, fall, current pull, cinematic).
## Idles are cosmetic (AxolotlModel); this only says when they may start and makes them stop.
func idle_allowed() -> bool:
	if state != "normal" or not controls_enabled or not grounded or _acted:
		return false
	if swipe_t >= 0.0 or lunge_t >= 0.0 or hurt_lock > 0.0 or land_lock > 0.0 or fall_danger or invuln_t > 0.0:
		return false
	if move_input.length() > 0.05 or ext_vel.length() > 0.05:
		return false
	var vh := velocity - up * velocity.dot(up)
	if vh.length() > 0.3:
		return false
	return Game.inst == null or Game.inst.cinematic == ""


func _update_shadow() -> void:
	if ball == null:
		return
	var space := get_world_3d().direct_space_state
	var from := global_position + up * 0.4
	var q := PhysicsRayQueryParameters3D.create(from, from - up * 30.0, collision_mask)
	var hit := space.intersect_ray(q)
	if hit.is_empty() or model.dissolve > 0.5:
		blob_shadow.visible = false
		return
	blob_shadow.visible = true
	var n: Vector3 = hit.normal
	var p: Vector3 = hit.position + n * 0.04
	var d := from.distance_to(hit.position)
	blob_shadow.global_transform = Transform3D(MossBall.frame_at(n, 0), p)
	blob_shadow.scale = Vector3.ONE * clampf(1.0 - d * 0.05, 0.4, 1.0)
	(blob_shadow.material_override as ShaderMaterial).set_shader_parameter("strength", clampf(0.55 - d * 0.03, 0.12, 0.55))
