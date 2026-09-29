class_name Swimmer
extends CharacterBody3D
## Gill in Swim Mode (docs/AQUARIUM.md): free swimming anywhere in the aquarium's water, off the
## moss balls' gravity. A body of its own, separate from the gameplay axolotl, so nothing in Swim
## Mode can touch the run: blooms, shrines, Motes, food, damage, falls and the timer all look at
## Game.player, never at this. It collides with the moss balls, their terrain and leaves, the glass,
## the gravel and the water surface (sliding along them, never stuck), and swims with assisted,
## watery controls:
## - the stick steers where the camera looks (look up and push forward to rise, down to dive);
## - Up / Down rise and sink straight; Faster is held for purposeful swimming;
## - he turns smoothly toward where he is told to go, keeps a little momentum and glides to a stop.

const RELAXED := 5.0
const FAST := 14.0
const ACCEL := 2.4
const GLIDE := 1.6
const TURN := 3.5
const RADIUS := 0.32
## The glass, gravel and water surface (Aquarium.TANK_LAYER), plus terrain, platforms and leaves.
const MASK := 1 | 2 | 8

var model: AxolotlModel
var facing := Vector3.FORWARD
var pitch := 0.0
var stick := Vector2.ZERO
var up_in := 0.0
var fast := false
var cam_yaw := 0.0
var cam_pitch := 0.15
var _cam_manual := 0.0
var _prev_heading := 0.0
var _perk_cd := 0.0
var _rng := RandomNumberGenerator.new()


func setup(pos: Vector3, face: Vector3, tank_layer: int) -> void:
	collision_layer = 0
	collision_mask = MASK | tank_layer
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	wall_min_slide_angle = 0.0
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = RADIUS
	cs.shape = sph
	add_child(cs)
	model = AxolotlModel.new()
	add_child(model)
	global_position = pos
	var f := Vector3(face.x, 0, face.z)
	facing = f.normalized() if f.length() > 0.05 else Vector3.FORWARD
	cam_yaw = atan2(-facing.x, -facing.z)
	_prev_heading = cam_yaw
	_rng.seed = 0x5117


## Where the camera looks (horizontal yaw and pitch): the stick steers relative to it.
func cam_forward() -> Vector3:
	return Vector3(-sin(cam_yaw) * cos(cam_pitch), sin(cam_pitch), -cos(cam_yaw) * cos(cam_pitch)).normalized()


func look(delta: Vector2) -> void:
	cam_yaw -= delta.x
	cam_pitch = clampf(cam_pitch + delta.y, -1.1, 1.1)
	if delta.length() > 0.0001:
		_cam_manual = 1.2


func _physics_process(dt: float) -> void:
	var fwd := cam_forward()
	var right := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
	var wish := right * stick.x + fwd * stick.y + Vector3.UP * up_in
	var mag := clampf(wish.length(), 0.0, 1.0)
	var target := Vector3.ZERO
	if mag > 0.05:
		target = wish.normalized() * mag * (FAST if fast else RELAXED)
		velocity = velocity.lerp(target, clampf(ACCEL * dt, 0.0, 1.0))
	else:
		# A glide, slowing naturally in the water.
		velocity = velocity.move_toward(Vector3.ZERO, GLIDE * maxf(1.0, velocity.length() * 0.35) * dt)
	move_and_slide()
	# Heading follows travel (smoothly; never a rigid snap), nose up or down with the climb.
	var sp := velocity.length()
	var flat := Vector3(velocity.x, 0, velocity.z)
	if flat.length() > 0.3:
		var want := flat.normalized()
		# (Turned about the vertical: a slerp between near-opposite directions has no stable axis.)
		var a := Tier2.signed_angle(facing, want, Vector3.UP)
		facing = facing.rotated(Vector3.UP, a * clampf(TURN * dt, 0.0, 1.0)).normalized()
	var want_pitch := atan2(velocity.y, maxf(flat.length(), 0.01)) if sp > 0.4 else 0.0
	pitch = lerpf(pitch, clampf(want_pitch, -1.0, 1.0), clampf(dt * 3.0, 0.0, 1.0))
	var heading := atan2(-facing.x, -facing.z)
	var turn_rate := wrapf(heading - _prev_heading, -PI, PI) / maxf(dt, 0.001)
	_prev_heading = heading
	global_basis = Basis(Vector3.UP, heading) * Basis(Vector3.RIGHT, pitch)
	# The swimming gait: effort from speed (hovering still undulates gently).
	model.swim = clampf(0.25 + sp / RELAXED * 0.75, 0.25, 2.0) if sp < RELAXED else clampf(1.0 + (sp - RELAXED) / (FAST - RELAXED), 1.0, 2.0)
	model.swim_turn = lerpf(model.swim_turn, clampf(turn_rate, -3.0, 3.0), clampf(dt * 6.0, 0.0, 1.0))
	model.swim_pitch = 0.0
	model.speed = clampf(sp / RELAXED, 0.0, 1.0) * 0.4
	model.grounded = false
	model.idle_ok = false
	# The camera drifts back behind his direction of travel when not being turned by hand.
	_cam_manual = maxf(0.0, _cam_manual - dt)
	if _cam_manual <= 0.0 and flat.length() > 1.0:
		var a := wrapf(heading - cam_yaw, -PI, PI)
		if absf(a) < 2.6:
			cam_yaw += a * clampf(dt * 0.9, 0.0, 1.0)
	_perk_cd = maxf(0.0, _perk_cd - dt)


## A fish came close: a short curious reaction (never takes control).
func notice_fish(at: Vector3) -> void:
	if _perk_cd > 0.0:
		return
	_perk_cd = 4.0 + _rng.randf() * 3.0
	# Gills perk up and he turns his head to look (the model's perk reaction).
	model.perk_t = 0.0
	model.look_target = at


func body_center() -> Vector3:
	return global_position
