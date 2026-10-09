class_name Swimmer
extends CharacterBody3D
## Gill in Swim Mode (docs/AQUARIUM.md): free swimming anywhere in the aquarium's water, off the
## moss balls' gravity. A body of its own, separate from the gameplay axolotl, so nothing in Swim
## Mode can touch the run: blooms, shrines, Motes, food, damage, falls and the timer all look at
## Game.player, never at this. It collides with the moss balls, their terrain and leaves, the glass,
## the gravel and the water surface (sliding along them, never stuck), and swims with assisted,
## flight-style controls (owner, 2026-09-30):
## - the stick aims his nose: left and right turn him, and (like a flight stick) pulling down pitches
##   him up and pushing up pitches him down; the Settings "Invert swim up/down" reverses only that;
## - Swim (held) propels him along his nose; let go and he glides to a stop;
## - the camera rides behind his nose, dipping with his pitch.

## Swimming speed while Swim is held (units/s), and how quickly he gets up to it.
const SPEED := 10.0
const ACCEL := 2.2
const GLIDE := 1.4
## Turn and pitch rates at full stick (rad/s), how fast they respond, and the pitch limit.
const YAW_RATE := 1.9
const PITCH_RATE := 1.5
const RATE_EASE := 6.0
const PITCH_MAX := 1.2
## (Kept for the gait: the speed at which he swims "relaxed".)
const RELAXED := 5.0
const RADIUS := 0.32
## The glass, gravel and water surface (Aquarium.TANK_LAYER), plus terrain, platforms and leaves.
const MASK := 1 | 2 | 8

var model: AxolotlModel
var facing := Vector3.FORWARD
var pitch := 0.0
var stick := Vector2.ZERO
## Swim is held.
var swim_held := false
## Pitch input is reversed (Settings.swim_invert_y).
var invert_y := false
var heading := 0.0
var _yaw_v := 0.0
var _pitch_v := 0.0
var cam_yaw := 0.0
var cam_pitch := 0.15
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
	heading = atan2(-facing.x, -facing.z)
	cam_yaw = heading
	_prev_heading = heading
	_rng.seed = 0x5117


## Where his nose points.
func nose() -> Vector3:
	return Vector3(-sin(heading) * cos(pitch), sin(pitch), -cos(heading) * cos(pitch)).normalized()


## Where the camera looks: behind his nose, dipping with only part of his pitch (so a dive or a
## climb stays readable).
func cam_forward() -> Vector3:
	return Vector3(-sin(cam_yaw) * cos(cam_pitch), sin(cam_pitch), -cos(cam_yaw) * cos(cam_pitch)).normalized()


func _physics_process(dt: float) -> void:
	# Aim: the stick sets how fast his nose turns and pitches (eased, never a snap).
	var st := stick.limit_length(1.0)
	var pitch_in := -st.y * (-1.0 if invert_y else 1.0)
	_yaw_v = lerpf(_yaw_v, -st.x * YAW_RATE, clampf(RATE_EASE * dt, 0.0, 1.0))
	_pitch_v = lerpf(_pitch_v, pitch_in * PITCH_RATE, clampf(RATE_EASE * dt, 0.0, 1.0))
	heading = wrapf(heading + _yaw_v * dt, -PI, PI)
	pitch = clampf(pitch + _pitch_v * dt, -PITCH_MAX, PITCH_MAX)
	facing = Vector3(-sin(heading), 0, -cos(heading))
	# Propulsion along the nose while Swim is held; otherwise a glide.
	var n := nose()
	if swim_held:
		velocity = velocity.lerp(n * SPEED, clampf(ACCEL * dt, 0.0, 1.0))
	else:
		velocity = velocity.move_toward(Vector3.ZERO, GLIDE * maxf(1.0, velocity.length() * 0.35) * dt)
	# (Momentum turns with him a little, so a turn while coasting curves rather than skids.)
	if velocity.length() > 0.2:
		velocity = velocity.slerp(n * velocity.length(), clampf(dt * 1.5, 0.0, 1.0))
	move_and_slide()
	var sp := velocity.length()
	var turn_rate := wrapf(heading - _prev_heading, -PI, PI) / maxf(dt, 0.001)
	_prev_heading = heading
	global_basis = Basis(Vector3.UP, heading) * Basis(Vector3.RIGHT, pitch)
	# The swimming gait: effort from speed and from holding Swim (hovering still undulates gently).
	model.swim = clampf(0.3 + sp / RELAXED * 0.7, 0.3, 2.0) + (0.25 if swim_held else 0.0)
	model.swim_turn = lerpf(model.swim_turn, clampf(turn_rate, -3.0, 3.0), clampf(dt * 6.0, 0.0, 1.0))
	model.swim_pitch = 0.0
	model.speed = clampf(sp / RELAXED, 0.0, 1.0) * 0.4
	model.grounded = false
	model.idle_ok = false
	# The camera follows behind his nose (a little behind the turn, so the turn reads).
	cam_yaw += wrapf(heading - cam_yaw, -PI, PI) * clampf(dt * 3.0, 0.0, 1.0)
	cam_pitch = lerpf(cam_pitch, pitch * 0.55 + 0.08, clampf(dt * 3.0, 0.0, 1.0))
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
