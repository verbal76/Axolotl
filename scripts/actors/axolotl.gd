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
const LIFT_ACCEL := 34.0          # how hard a bubble column pushes toward its lift speed
## The head: the axolotl's body collides as one sphere, but his head reaches HEAD_REACH ahead of it.
## After each move the head guard keeps this sphere out of walls and ceilings (see _guard_head).
const HEAD_REACH := 0.4
const HEAD_HEIGHT := 0.28
const HEAD_RADIUS := 0.17
## Distributed traction (Mote Open Issue #1; reworked after the phone playtest of dev-000033, where
## he face-planted into an ordinary mossy incline with a short steep foot and slid sideways along it).
## Before he treats steep ground ahead as a wall he reads its SHAPE: the ground along where he is going
## is sampled out to CRAWL_LOOK (about one and a half body lengths). A crawlable transition is a steep
## band (over 50 degrees, where the body alone would stop) whose top is at most CRAWL_MAX above his
## feet, with his front able to reach it (its foot within CRAWL_REACH) and PURCHASE beyond it: at least
## CRAWL_PURCHASE of walkable ground (under 45 degrees) he can plant on, with room for his body, still
## and solid (no leaf, crumble, moving body or ravine). Then, holding the stick into it, he crawls:
## front up onto the purchase, body over the edge, rear pushing, one bounded move along the band
## (CRAWL_UP up, CRAWL_FWD on), and walks on up whatever incline follows. Anything else steep is a
## barrier: a band taller than CRAWL_MAX (cushion and terrace walls, cliffs, ravine and cave walls,
## sheer faces), or one with nowhere to get purchase within reach (a long face, narrow ledges). There
## the head guard and the body's 52 degree wall behave exactly as before: he stops, and nothing holds
## him to the face. A crawl starts only from stable ground he stands on and needs purchase to end on,
## so repeated pushes never ratchet him up a face; CRAWL_MAX is well under a plain jump (1.85 m), so
## a crawl opens no route a jump from the same spot did not; and designed jumps (cushions, terrace
## tiers, stepping stones: LevelBuilder's "jump_only") are never crawled whatever their sides look like.
const CRAWL_MAX := 0.6
const CRAWL_REACH := 0.95
const CRAWL_LOOK := 1.6
const CRAWL_STEP := 0.1
const CRAWL_PURCHASE := 0.35
const CRAWL_STEEP_DOT := 0.643        # cos 50 degrees: steeper than this is a band to crawl (or a wall)
const WALK_DOT := 0.707               # cos 45 degrees: purchase, and the ground a crawl starts from
const CRAWL_UP := 2.6
const CRAWL_FWD := 1.6

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
var _fell_at := Vector3.ZERO      # where he last came down in a ravine
var _in_column := false            # being carried by a bubble column
var mantles := 0                   # crawls over steep transitions (tests and diagnostics)
var _mantle_t := -1.0              # time into a crawl, -1 when not crawling
var _crawl := {}                   # the transition being crawled (see crawl_probe)
var _crawl_r0 := 0.0               # his feet's distance from the ball's centre when it began
var _lip_armed := true             # re-armed only on walkable, stable ground
var _blocked := false              # his head or body met something steep last frame
var _block_n := Vector3.ZERO       # which way it pushed him (tangent to the ground)
var _turn_gap := 0.0               # the turn still to come (the model: the head leads it)
var _probe_cd := 0.0               # the ground ahead is not re-read every frame against a barrier
var _probe_at := Vector3.INF
var crawl_amount := 0.0            # 0..1, how far into the crawl's reach-and-pull (the model reads it)
var _guard_pushed := false

## Skill tree (docs/SKILL_TREE.md): each family's tier, applied by apply_skills. With no skills every
## value below is exactly the base constant, so a player without skills moves exactly as before.
var skill_tiers := {"lunge": 0, "quick": 0, "burst": 0, "magnet": 0, "glide": 0}
var _run_scale := 1.0              # Quick Gill: the GROUND run target only
var _lunge_time := LUNGE_TIME
var _lunge_steer := 0.0            # Lunge II: rad/s the stick turns a lunge
var catch_bonus := 0.0             # Lunge III: added to food and Mote catch radii (Game.lunge_contact)
var _lunge_aimed := false          # this lunge was aimed by Treasure Hunt (never steered)
var _burst_h := BURST_H
var _burst_up := BURST_UP
var _burst_up_only := BURST_UP_ONLY
var _carry_len := 0.0              # Water Burst II: how long the burst's push carries
var _carry_k := 1.0
var _burst_steer := 0.0            # Water Burst III: rad/s the stick bends the burst's path
var _carry_t := 0.0
var magnet_range := 0.0            # Mote Magnet (read by Mote)
var magnet_accel := 0.0
var magnet_leash := 0.0
var magnet_startle := 0.0
var _glide := {}                   # Glide tier values ({} = no glide)
## Glide: held Jump in the air near the top of a jump (docs/SKILL_TREE.md, "tiring wing").
var gliding := false
var glide_amount := 0.0            # 0..1 eased, for the model's posture
var glide_t := -1.0                # the tiring clock: since the glide first opened this air (-1 none)
var glides := 0                    # glides opened (tests and diagnostics)
var glide_sink := 0.0              # this frame's sink target (diagnostics)


## Applies the skill tree's tiers ({family: 0..3}) to his movement and actions.
func apply_skills(tiers: Dictionary) -> void:
	for f in skill_tiers:
		skill_tiers[f] = clampi(int(tiers.get(f, 0)), 0, 3)
	var T: Dictionary = SkillTree.TIERS
	var q: int = skill_tiers["quick"]
	var l: int = skill_tiers["lunge"]
	var b: int = skill_tiers["burst"]
	var m: int = skill_tiers["magnet"]
	var gl: int = skill_tiers["glide"]
	_run_scale = T["quick"]["run_scale"][q]
	_lunge_time = T["lunge"]["time"][l] if l > 0 else LUNGE_TIME
	_lunge_steer = T["lunge"]["steer"][l]
	catch_bonus = T["lunge"]["catch"][l]
	_burst_h = T["burst"]["h"][b] if b > 0 else BURST_H
	_burst_up = T["burst"]["up"][b] if b > 0 else BURST_UP
	_burst_up_only = T["burst"]["up_only"][b] if b > 0 else BURST_UP_ONLY
	_carry_len = T["burst"]["carry"][b]
	_carry_k = T["burst"]["carry_k"][b]
	_burst_steer = T["burst"]["steer"][b]
	magnet_range = T["magnet"]["range"][m]
	magnet_accel = T["magnet"]["accel"][m]
	magnet_leash = T["magnet"]["leash"][m]
	magnet_startle = T["magnet"]["startle"][m]
	_glide = {} if gl == 0 else {"s0": T["glide"]["s0"][gl], "tau": T["glide"]["tau"][gl], "v": T["glide"]["v"][gl]}
	if gl == 0:
		gliding = false

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
	_mantle_t = -1.0
	_lip_armed = true
	_blocked = false
	crawl_amount = 0.0
	gliding = false
	glide_t = -1.0
	_carry_t = 0.0
	# (No smear of his body from where he was.)
	model.reset_follow()


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
			if (pts[k + 1] - global_position).dot(up) < 0.12:
				continue   # a bump at his chin: the body steps it (and the model lifts the head onto it)
			if n.dot(up) < -0.3:
				# Ceiling: back away from it rather than into the floor.
				var back := -facing
				out = back * out.length() / maxf(0.35, -n.dot(up))
				n = back
			if out.length() > push.length():
				push = out
		if push == Vector3.ZERO:
			return
		_guard_pushed = true
		_block_n = push.normalized()
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
		model.conform = false
		model.crawl = 0.0
		model.turn_gap = 0.0
		gliding = false
		glide_amount = 0.0
		model.glide = 0.0
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
	var want_special := controls_enabled and Input.is_action_just_pressed("special")
	_acted = want_jump or want_swipe or want_lunge or want_special
	# (A Tier-2 ability is a short authored moment: nothing else starts while it runs.)
	var t2: Tier2Combat = Game.inst.t2 if Game.inst else null
	var t2_busy := t2 != null and t2.active != ""
	if t2_busy:
		want_jump = false
		want_swipe = false
		want_lunge = false

	var vup := velocity.dot(up)
	var vh := velocity - up * vup
	# (A current stream carries him along and holds him at its height; read here, applied below.)
	var stream := ball.stream_at(global_position) if ball != null and not ball.streams.is_empty() else Vector3.ZERO

	# Glide (skill tree): Jump held in the air, near the top of a jump or once falling. Releasing it,
	# landing, a column, a current, a lunge, a crawl, a hit or a Tier-2 move ends it. A tap of Jump in a
	# glide is the water burst (once per air, as always); holding on, he glides again after it.
	var hold := controls_enabled and not t2_busy and Input.is_action_pressed("jump")
	gliding = not _glide.is_empty() and hold and not grounded and vup <= SkillTree.GLIDE_ENTER and not _in_column \
			and stream == Vector3.ZERO and lunge_t < 0.0 and _mantle_t < 0.0 and hurt_lock <= 0.0
	if gliding and glide_t < 0.0:
		glide_t = 0.0
		glides += 1
	var g_e := exp(-maxf(glide_t, 0.0) / float(_glide.get("tau", 1.0)))
	var g_sink := SkillTree.GLIDE_S_END - (SkillTree.GLIDE_S_END - float(_glide.get("s0", 0.0))) * g_e
	var g_v := SkillTree.GLIDE_V_END + (float(_glide.get("v", 0.0)) - SkillTree.GLIDE_V_END) * g_e
	glide_sink = g_sink if gliding else 0.0

	# Facing follows intended direction (not during a lunge).
	if wish.length() > 0.08 and lunge_t < 0.0:
		var turn := 14.0 if grounded else (4.5 if gliding else 7.0)
		facing = _slerp_tangent(facing, wish.normalized(), minf(1.0, turn * dt))
	facing = (facing - up * facing.dot(up)).normalized()
	# (The turn still to come: his head leads it, AxolotlModel.turn_gap.)
	_turn_gap = facing.signed_angle_to(wish.normalized(), up) if wish.length() > 0.08 and lunge_t < 0.0 and swipe_t < 0.0 else 0.0

	# Horizontal movement.
	var control := 1.0
	if hurt_lock > 0.0:
		control = 0.35
	if land_lock > 0.0:
		control = 0.5
	# (Quick Gill scales the run on the ground only: in the air the target is the base run, so every
	# jump's reach is unchanged.)
	var target := wish * (RUN_SPEED * _run_scale if grounded else RUN_SPEED) * control
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
	# (Water Burst II: the burst's push carries on, the water's drag on it eased for a moment.)
	if _carry_t > 0.0:
		_carry_t = maxf(0.0, _carry_t - dt)
		if not grounded:
			accel *= _carry_k
	if lunge_t >= 0.0:
		lunge_t += dt / _lunge_time
		if _lunge_target_valid():
			var flat := _lunge_food.catch_point() - global_position
			flat -= up * flat.dot(up)
			if flat.length() > 0.2:
				facing = _slerp_tangent(facing, flat.normalized(), minf(1.0, 25.0 * dt))
		elif _lunge_steer > 0.0 and not _lunge_aimed and wish.length() > 0.2:
			# Lunge II: the stick steers a lunge that is not homing on anything.
			facing = _slerp_tangent(facing, wish.normalized(), minf(1.0, _lunge_steer * dt))
		vh = facing * LUNGE_SPEED * (1.0 - lunge_t * 0.5)
		if not lunge_hit:
			lunge_hit = Game.inst.lunge_contact(self)
		if lunge_t >= 1.0:
			lunge_t = -1.0
			_lunge_food = null
			if not lunge_hit:
				Game.inst.lunge_miss(self)
	elif gliding:
		# Gliding: the forward speed the (tiring) glide carries, along the stick.
		vh = vh.move_toward(wish * g_v, SkillTree.GLIDE_ACCEL * (_carry_k if _carry_t > 0.0 else 1.0) * dt)
	else:
		vh = vh.move_toward(target, accel * dt)
	# Water Burst III: during the carry the stick bends the burst's path (its speed unchanged).
	if _carry_t > 0.0 and _burst_steer > 0.0 and not grounded and wish.length() > 0.2 and lunge_t < 0.0:
		var sp := vh.length()
		if sp > 0.5:
			vh = _slerp_tangent(vh / sp, wish.normalized(), minf(1.0, _burst_steer * dt)) * sp

	# Gravity.
	if not grounded:
		if gliding:
			# The glide holds his descent to its sink: under it he falls as ever; over it (opening
			# the glide from a fall) the spread body brakes him.
			vup = maxf(vup - GRAVITY * dt, -g_sink) if vup > -g_sink else move_toward(vup, -g_sink, SkillTree.GLIDE_BRAKE * dt)
		else:
			vup = maxf(vup - GRAVITY * dt, -TERMINAL)
		air_time += dt
		# (The tiring clock runs on through bursts and releases until he lands.)
		if glide_t >= 0.0:
			glide_t += dt
	else:
		air_time = 0.0
		vup = minf(vup, 0.0) - 1.5
	# A bubble column carries him up (off the ground too) to hang bobbing near its top; he can
	# burst again from there.
	var lift := ball.lift_at(global_position) if ball != null and not ball.columns.is_empty() else 0.0
	# (A glide shaft is a column with a gentle down-draft: he sinks slowly, steering as he likes.)
	_in_column = lift != 0.0
	if _in_column:
		# (A column rests him: a glide after it starts fresh.)
		glide_t = -1.0
	if _in_column and lift > 0.0:
		vup = maxf(lift, 2.5) if grounded else move_toward(vup, lift, LIFT_ACCEL * dt)
		grounded = false
		burst_available = true
	elif _in_column and not grounded:
		vup = move_toward(vup, lift, LIFT_ACCEL * dt)
	# (Carried by a column or drifting down a shaft is no fall: a fall counts from where he leaves it.)
	if _in_column:
		apex_r = _r()
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
		lunge_cd = _lunge_time + 0.15
		_lunge_aimed = false
		lunged.emit()
		if wish.length() > 0.2:
			facing = wish.normalized()
		_lunge_food = Game.inst.lunge_target(self, facing)
		# Treasure Hunt: the same aim help toward the object he is after, unless food is nearer (then
		# the lunge goes for the food, as always).
		if Game.inst.treasure != null:
			var tc: Vector3 = Game.inst.treasure.aim(self, facing)
			if tc != Vector3.INF and _lunge_food != null and (_lunge_food as Node3D).global_position.distance_to(global_position) <= tc.distance_to(global_position):
				tc = Vector3.INF
			if tc != Vector3.INF:
				_lunge_food = null
				_lunge_aimed = true
				var flat := tc - global_position
				flat -= up * flat.dot(up)
				if flat.length() > 0.2:
					facing = flat.normalized()

	# Tier 2: the button starts the equipped ability (when ready and nothing else is running); while
	# it runs it steers him (docs/TIER2.md).
	if want_special and not t2_busy and swipe_t < 0.0 and lunge_t < 0.0 and t2 != null:
		t2_busy = t2.try_start(self)
	if t2_busy and t2.active != "":
		var drive: Array = t2.drive(self, dt, vh)
		vh = drive[0]
		if not is_nan(float(drive[1])):
			vup = drive[1]
	# (A current stream carries him along and holds him at its height.)
	if stream != Vector3.ZERO and not grounded:
		vup = move_toward(vup, 0.0, 30.0 * dt)
	# Traction: crawling over a steep transition he has purchase beyond (see CRAWL_MAX).
	if _mantle_t >= 0.0:
		_mantle_t += dt
		var cdir: Vector3 = _crawl["dir"]
		cdir = (cdir - up * cdir.dot(up)).normalized()
		var push_on := wish.length() > 0.05 and wish.normalized().dot(cdir) > 0.2
		var hr := _r() - _crawl_r0
		var past := (global_position - (_crawl["edge"] as Vector3)).dot(cdir)
		if not push_on or _mantle_t > float(_crawl["limit"]) or lunge_t >= 0.0 or t2_busy or _jumped_this_frame or hurt_lock > 0.0:
			# (Let go: nothing holds him, he settles or slides back as the ground has it.)
			_mantle_t = -1.0
		elif hr >= float(_crawl["rise"]) - 0.03 and past >= 0.12:
			# Over, his body on the purchase: on he walks.
			_mantle_t = -1.0
			vup = 0.0
			vh = cdir * maxf(vh.dot(cdir), CRAWL_FWD)
		else:
			# Front up and over the band, body following: up while below its top, then on over the
			# edge at the top's height until his body is on the purchase.
			var need := float(_crawl["rise"]) + 0.04 - hr
			vup = clampf(need / dt, 0.0, CRAWL_UP) if need > 0.0 else 0.0
			vh = cdir * CRAWL_FWD * (0.55 if need > 0.15 else 1.0)
			facing = _slerp_tangent(facing, cdir, minf(1.0, 12.0 * dt))
	elif grounded and _lip_armed and _blocked and not _jumped_this_frame and lunge_t < 0.0 and swipe_t < 0.0 and not t2_busy \
			and not _in_column and stream == Vector3.ZERO and hurt_lock <= 0.0 and wish.length() > 0.3 \
			and is_on_floor() and _floor_is_stable():
		# (Pressed against a barrier, the ground ahead is read again only every few frames or once he
		# has moved.)
		var c := {}
		_probe_cd -= dt
		if _probe_cd <= 0.0 or global_position.distance_to(_probe_at) > 0.08:
			c = _crawl_toward(wish.normalized())
			_probe_cd = 0.12
			_probe_at = global_position
		if not c.is_empty():
			_crawl = c
			_mantle_t = 0.0
			_crawl_r0 = _r()
			_lip_armed = false
			mantles += 1
			grounded = false
			vup = CRAWL_UP
			vh = (c["dir"] as Vector3) * CRAWL_FWD * 0.55
	crawl_amount = move_toward(crawl_amount, 1.0 if _mantle_t >= 0.0 else 0.0, dt * (8.0 if _mantle_t >= 0.0 else 4.0))
	# (Inside a bubble column its upflow shelters him from the ball's current.)
	var cur := ball.current_at(global_position) * (0.0 if _in_column else (0.45 if grounded else 1.0)) + ext_vel + stream
	velocity = vh + up * vup + cur
	var was_grounded := grounded
	var pre_vup := vup
	move_and_slide()
	# (While he crawls over a transition his head is over it: the probe found it clear.)
	_guard_pushed = false
	if _mantle_t < 0.0:
		_guard_head()
	_blocked = _guard_pushed or is_on_wall()
	if is_on_wall() and not _guard_pushed:
		_block_n = get_wall_normal()
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
		# Down on a ravine's floor: one frond, and he is put back at its edge (world expansion).
		if on_ravine_floor():
			_fell_at = global_position
			Game.inst.ravine_fall(self)
			return
		apex_r = r
		coyote_t = 0.0
		if _floor_is_stable():
			last_safe_pos = global_position
			last_safe_ball = ball
			# (Only walkable, stable ground re-arms a crawl: never mid-face, so no ratchet.)
			if _mantle_t < 0.0:
				_lip_armed = true
	else:
		if was_grounded and not _jumped_this_frame:
			coyote_t = COYOTE
		apex_r = maxf(apex_r, r)
		if gliding:
			# (A glide lands as gently as its descent: the fall counts as the height a free fall
			# would need to come down this fast, so a held glide lands soft and letting go falls on.)
			var vd := maxf(0.0, -velocity.dot(up))
			apex_r = minf(apex_r, r + vd * vd / (2.0 * GRAVITY))

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


## Down on a ravine's floor (not up on a bridge or a stepping stone above it).
func on_ravine_floor() -> bool:
	return ball.ravine_at(up) != "" and ball.altitude(global_position) < 1.0


func _floor_is_stable() -> bool:
	# (Never in a ravine or on its walls: he is put back where he stood before it, on the rim.)
	if ball.ravine_carve(up) > 0.15:
		return false
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var col := c.get_collider()
		# (A moving body is no safe footing, unless it has settled for good, like an opened
		# restoration gate.)
		if col and (col.has_meta("unsafe") or (col is AnimatableBody3D and not col.has_meta("settled"))):
			return false
	return true


func _floor_collider() -> Object:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_normal().dot(up) > 0.5:
			return c.get_collider()
	return null


## The crawlable transition he is pushing into, or {}: read along where he is heading (the stick's
## direction) and, when a face turned him aside, straight up it (as an animal turns into a slope to
## climb it), so a transition met at an angle is crawled too. See CRAWL_MAX.
func _crawl_toward(wdir: Vector3) -> Dictionary:
	var dirs: Array[Vector3] = [wdir]
	var n := _block_n - up * _block_n.dot(up)
	if n.length() > 0.2:
		var into := -n.normalized()
		# (Up the face, when that is within about 60 degrees of where he is heading.)
		if into.dot(wdir) > 0.5 and into.dot(wdir) < 0.985:
			dirs.append(into)
	for d in dirs:
		var c := crawl_probe(d)
		if c.get("crawl", false):
			return c
	return {}


## The shape of the ground ahead of his feet along `dir`, out to CRAWL_LOOK: {"crawl": true, "dir",
## "rise", "edge", "foot", "limit", ...} for a crawlable transition (see CRAWL_MAX), otherwise
## {"crawl": false, "why": ...} (no steep band, a barrier, no purchase, unsafe footing...).
func crawl_probe(dir: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var c0 := ball.global_position
	var feet := global_position
	var r_feet := (feet - c0).length()
	dir = (dir - up * dir.dot(up)).normalized()
	var ceil_h := CRAWL_MAX + 0.55
	var q := PhysicsRayQueryParameters3D.new()
	q.collision_mask = 1 | 2
	q.exclude = [get_rid()]
	q.hit_back_faces = false
	# Anything rising through the ceiling ahead is a wall: the profile stops short of it.
	q.from = feet + up * ceil_h
	q.to = q.from + dir * (CRAWL_LOOK + 0.1)
	var wall := space.intersect_ray(q)
	var look := CRAWL_LOOK if wall.is_empty() else ((wall["position"] as Vector3) - feet).dot(dir) - 0.05
	var hs: Array[float] = []
	var ns: Array[float] = []
	var nv: Array[Vector3] = []
	var cols: Array = []
	var pts: Array[Vector3] = []
	for k in range(1, int(look / CRAWL_STEP) + 1):
		var at := feet + dir * (k * CRAWL_STEP)
		q.from = at + up * ceil_h
		q.to = at - up * 0.6
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			break
		var hp: Vector3 = hit["position"]
		hs.append((hp - c0).length() - r_feet)
		ns.append((hit["normal"] as Vector3).dot(ball.up_at(hp)))
		nv.append(hit["normal"])
		cols.append(hit["collider"])
		pts.append(hp)
	# The steep band: the first sample steeper than CRAWL_STEEP_DOT (by the ground's own normal, so a
	# face met at an angle still reads as steep as it is, or by the rise between samples).
	var tan_steep := tan(acos(CRAWL_STEEP_DOT))
	var tan_walk := tan(acos(WALK_DOT))
	var i0 := -1
	var prev := 0.0
	for i in hs.size():
		if (hs[i] - prev) / CRAWL_STEP > tan_steep or (ns[i] < CRAWL_STEEP_DOT and hs[i] > 0.04):
			i0 = i
			break
		prev = hs[i]
	if i0 < 0:
		return {"crawl": false, "why": "no band"}
	var foot := i0 * CRAWL_STEP
	if foot > CRAWL_REACH:
		return {"crawl": false, "why": "out of reach"}
	# Up the band to the first walkable sample above it.
	var it := i0 + 1
	while it < hs.size() and (ns[it] < WALK_DOT or (hs[it] - hs[it - 1]) / CRAWL_STEP > tan_walk):
		it += 1
	var n_p := int(ceil(CRAWL_PURCHASE / CRAWL_STEP))
	if it + n_p >= hs.size():
		return {"crawl": false, "why": "no purchase in reach", "rise": hs[hs.size() - 1] if not hs.is_empty() else 0.0}
	var rise := hs[it]
	# (A designed jump, a cushion, terrace tier or stepping stone, is never crawled, whatever its
	# side looks like where he meets it: LevelBuilder marks them.)
	for i in range(i0, mini(it + n_p + 1, cols.size())):
		if cols[i] is Object and (cols[i] as Object).has_meta("jump_only"):
			return {"crawl": false, "why": "designed jump", "rise": rise}
	if rise > CRAWL_MAX:
		return {"crawl": false, "why": "too tall", "rise": rise}
	if rise < 0.08:
		return {"crawl": false, "why": "no band", "rise": rise}
	# Purchase: walkable, still, solid ground going on beyond it (not a ledge, a fin or a leaf).
	for i in range(it, it + n_p + 1):
		if ns[i] < WALK_DOT or (i > it and absf(hs[i] - hs[i - 1]) / CRAWL_STEP > tan_walk):
			return {"crawl": false, "why": "no purchase", "rise": rise}
		if not _purchase_ok(cols[i]):
			return {"crawl": false, "why": "unsafe", "rise": rise}
	if ball.ravine_carve(ball.up_at(pts[it])) > 0.15 or ball.ravine_carve(ball.up_at(pts[it + n_p])) > 0.15:
		return {"crawl": false, "why": "ravine", "rise": rise}
	# The band rises from the ground he stands on (not an edge floating above it), with headroom over
	# the way up and room for his body on the purchase.
	q.from = feet + up * 0.1
	q.to = q.from + dir * (foot + 0.4)
	if space.intersect_ray(q).is_empty():
		return {"crawl": false, "why": "floating", "rise": rise}
	q.from = feet + up * 0.35
	q.to = feet + up * (rise + 0.75)
	if not space.intersect_ray(q).is_empty():
		return {"crawl": false, "why": "overhead", "rise": rise}
	var sq := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = BODY_RADIUS - 0.03
	sq.shape = sph
	sq.collision_mask = 1 | 2
	sq.exclude = [get_rid()]
	var li := mini(it + 2, hs.size() - 1)
	sq.transform = Transform3D(Basis(), pts[li] + nv[li] * (BODY_RADIUS + 0.04))
	if not space.intersect_shape(sq, 1).is_empty():
		return {"crawl": false, "why": "no room", "rise": rise}
	var run := (it + 1) * CRAWL_STEP - foot
	return {"crawl": true, "dir": dir, "rise": rise, "edge": pts[it], "foot": foot, "run": run,
			"limit": rise / CRAWL_UP + (run + 1.0) / CRAWL_FWD + 0.3}


## What he may crawl onto: still, solid ground (not a leaf that bends or sways, a crumbling
## cap, or anything moving).
func _purchase_ok(col: Object) -> bool:
	if col == null or col.has_meta("unsafe") or col.has_method("absorb") or col is Platforms.Crumble:
		return false
	if col is AnimatableBody3D and not col.has_meta("settled"):
		return false
	return true


func _do_jump() -> float:
	_mantle_t = -1.0
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
		vh = wish.normalized() * _burst_h
		vup = _burst_up
		facing = wish.normalized()
	else:
		vh = facing * 1.5
		vup = _burst_up_only
	apex_r = _r()   # a burst "saves" the fall: distance is measured from here
	_carry_t = _carry_len
	model.burst_t = 0.0
	burst_used.emit()
	WaterFX.inst.impulse(global_position - facing * 0.4, 2.2, 0.6)
	WaterFX.inst.burst_fx(global_position + up * 0.2, -(vh.normalized() if vh.length() > 0.1 else up), up)
	Sfx.play("burst", global_position)
	return [vh, vup]


func _on_land(impact: float, r: float) -> void:
	burst_available = true
	glide_t = -1.0
	_carry_t = 0.0
	# (A ravine floor is its own penalty, one frond, handled by Game.ravine_fall.)
	if on_ravine_floor():
		return
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


func _update_model(dt: float) -> void:
	var vh := velocity - up * velocity.dot(up)
	model.speed = vh.length() / RUN_SPEED
	# (Pulling himself over a lip he is on the ground, as far as his body is concerned.)
	model.grounded = grounded or _mantle_t >= 0.0
	# (His body lies along the ground under it while he is on it.)
	model.conform = model.grounded
	model.crawl = crawl_amount
	model.turn_gap = _turn_gap if grounded else _turn_gap * 0.5
	model.vup = velocity.dot(up)
	glide_amount = move_toward(glide_amount, 1.0 if gliding else 0.0, dt * (5.0 if gliding else 4.0))
	model.glide = glide_amount
	model.swipe_t = swipe_t
	model.lunge_t = lunge_t
	model.brace = move_toward(model.brace, 1.0 if fall_danger else 0.0, 0.1)
	model.idle_ok = idle_allowed()
	if cam:
		model.camera_pos = cam.global_position


## Where to put him back after a ravine fall: his last safe footing, stepped a little further from
## the ravine (away from where he came down), on ground that is not itself in a ravine.
func ravine_return_point() -> Array:
	var b: MossBall = last_safe_ball if last_safe_ball else ball
	var safe := last_safe_pos
	var away := safe - _fell_at
	var u := b.up_at(safe)
	away -= u * away.dot(u)
	if away.length() > 0.01:
		# Out to untouched ground (clear of the ravine's cut), then a little more.
		for k in range(1, 12):
			var d := b.up_at(safe + away.normalized() * 0.4 * k)
			if b.ravine_carve(d) < 0.02 and b.ravine_at(d) == "":
				var d2 := b.up_at(safe + away.normalized() * (0.4 * k + 0.6))
				if b.ravine_carve(d2) < 0.02:
					d = d2
				return [b, b.surface_point(d, 0.3)]
	return [b, safe + u * 0.3]


## Whether the model may play an idle: he is standing still on the ground under the player's
## control with nothing else going on (no input, action, landing, hit, fall, current pull, cinematic).
## Idles are cosmetic (AxolotlModel); this only says when they may start and makes them stop.
func idle_allowed() -> bool:
	if state != "normal" or not controls_enabled or not grounded or _acted:
		return false
	if swipe_t >= 0.0 or lunge_t >= 0.0 or hurt_lock > 0.0 or land_lock > 0.0 or fall_danger or invuln_t > 0.0:
		return false
	if Game.inst != null and Game.inst.t2 != null and Game.inst.t2.active != "":
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
