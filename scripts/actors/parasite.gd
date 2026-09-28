class_name Parasite
extends Node3D
## Invasive aquatic microparasite. Crawls on moss (and plants), grazes inside its home
## area, attacks the axolotl with readable telegraphs, and shows its remaining health only
## through colour: damage drains stolen vitality from the head toward the rear.
##
## Combat (Expansion 6, docs/ECOSYSTEM.md "Parasites"): each size fights its own way. Small ones
## dart in and latch on; medium ones circle for a better angle before they commit; large ones coil
## and make a heavy, committed charge. Spitters (a medium variant) keep their distance and lob a
## slow glob. They notice him only in sight (never through rock), alert near neighbours, spread
## round him instead of queueing, and share an attack budget so a group is chaos, not a blender.
## Hurt ones may break off and flee inside their territory, and recover a little if left alone.
## Every decision's variety comes from the parasite's own seeded generator (deterministic).

const SHADER := preload("res://shaders/parasite.gdshader")
const BODY_SHADER := preload("res://shaders/parasite_body.gdshader")
const MAX_SEGS := 12
## The shared body tube (rings x sides), laid along the segments by BODY_SHADER.
static var _tube: ArrayMesh
const NOISE := preload("res://assets/textures/noise_rgb.png")

enum Kind { SMALL = 1, MEDIUM = 2, LARGE = 3 }

var kind: int = Kind.SMALL
var ball: MossBall
var zone_id := ""
var hp := 1
var max_hp := 1
var home_dir := Vector3.UP
var home_radius := deg_to_rad(9.0)
var spawn_dir := Vector3.UP
var spawn_h := 0.0

var state := "init"   # init graze chase windup attack recover knocked flung retreat dying drifting gone
var state_t := 0.0
## Simulated time for cosmetic motion (never wall-clock: segment positions feed hit tests).
var _clock := 0.0
var heading := Vector3.FORWARD
var up := Vector3.UP
var vel := Vector3.ZERO
var seg_count := 3
var seg_radius := 0.12
var spacing := 0.2
var speed := 2.4
var attack_reach := 1.4
var windup_time := 0.45
var lunge_dist := 1.2
var hit_cd := 0.0
## Seconds it holds off attacking after the bloom's pulse startled it (it can still be hit).
var _shaken := 0.0

# --- Combat behaviour (Expansion 6) ---
## Neighbours within this distance of one that spots the axolotl join in.
const ALERT_R := 8.0
## At most this many parasites (and globs in flight) committed to an attack on a ball at once...
const MAX_COMMITTED := 2
## ...and attacks start at least this many physics frames apart.
const COMMIT_GAP_FRAMES := 24
## Physics frame of the last attack commitment on each ball (by instance id).
static var _last_commit := {}
## "" or "spitter" (a medium that keeps its distance and spits globs).
var variant := ""
var _rng := RandomNumberGenerator.new()
## Brave ones never flee.
var _brave := false
## Within the chase: "approach" or "circle" (medium).
var _mode := "approach"
var _mode_t := 0.0
var _circle_len := 1.5
var _circled := false
var _circle_dir := 1.0
## Approach angle when joining a group (radians round him; 0 = straight in).
var _flank := 0.0
var _alerted_t := 0.0
var _wary_t := 0.0
var _perk_t := 0.0
var _los := false
var _los_check := 0.0
var _unseen_t := 0.0
var _want_retreat := false
var _regen_ok := false
var _quiet_t := 0.0
var _spit_cd := 0.0
var _glob: ParasiteGlob = null
var _hurt_done := false
var _stretch_v := 1.0
var standing_on: Node = null
var _attack_from := Vector3.ZERO
var _attack_dir := Vector3.ZERO
var _graze_target := Vector3.ZERO
var _graze_t := 0.0
var _latched := 0.0
var _gray := 0.0
var _gray_target := 0.0
var _flash := 0.0
var _windup_v := 0.0
var _trail: Array[Vector3] = []
var _trail_up: Array[Vector3] = []
## Segment anchors (not drawn: the body is one continuous tube, `_body`); the head's carries the
## eyes and mandibles, the others the legs.
var _segs: Array[MeshInstance3D] = []
var _mat: ShaderMaterial
var _body: MeshInstance3D
var _body_mat: ShaderMaterial
var _spin := Vector3.ZERO
var _drift_t := 0.0
var _ground_offset := 0.1
var _pushed := Vector3.ZERO
## Body wave (see _update_segments): phase advances with distance travelled, so the motion is the
## same at any frame rate; amplitude follows how fast the head is really moving.
var _wave_phase := 0.0
var _wave_amp := 0.0
var _last_head := Vector3.ZERO


func setup(p_ball: MossBall, p_kind: int, p_zone: String, dir: Vector3, home_deg := 9.0, h := 0.0) -> void:
	ball = p_ball
	kind = p_kind
	zone_id = p_zone
	hp = kind
	max_hp = kind
	spawn_dir = dir.normalized()
	spawn_h = h
	home_dir = spawn_dir
	home_radius = deg_to_rad(home_deg)
	match kind:
		Kind.SMALL:
			seg_count = 3; seg_radius = 0.13; speed = 2.6; attack_reach = 1.5; windup_time = 0.45; lunge_dist = 1.3
		Kind.MEDIUM:
			seg_count = 6; seg_radius = 0.17; speed = 2.0; attack_reach = 1.8; windup_time = 0.6; lunge_dist = 1.7
		Kind.LARGE:
			# The heavy charge: a long coil, a committed run, a long recovery.
			seg_count = 9; seg_radius = 0.24; speed = 1.6; attack_reach = 3.4; windup_time = 1.1; lunge_dist = 4.4
	spacing = seg_radius * 1.45
	_ground_offset = seg_radius * 0.85
	ball.register_event(zone_id)
	# Its own generator, from where it lives (never the gameplay random sequence).
	_rng.seed = hash([roundi(spawn_dir.x * 1000.0), roundi(spawn_dir.y * 1000.0), roundi(spawn_dir.z * 1000.0), kind, zone_id])
	_brave = kind == Kind.SMALL or _rng.randf() < 0.35
	_circle_dir = 1.0 if _rng.randf() < 0.5 else -1.0


## Makes this a spitter (a medium parasite that keeps its distance and spits globs).
func make_spitter() -> void:
	variant = "spitter"
	attack_reach = 1.6
	windup_time = 0.85


func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("noise_tex", NOISE)
	var palettes := [[Color(0.95, 0.2, 0.62), Color(1.0, 0.62, 0.12), Color(0.5, 1.0, 0.3)],
			[Color(0.7, 0.15, 0.95), Color(0.2, 0.9, 0.8), Color(1.0, 0.9, 0.2)],
			[Color(1.0, 0.35, 0.1), Color(0.95, 0.1, 0.45), Color(0.3, 0.9, 1.0)]]
	var p: Array = palettes[kind - 1]
	_body_mat = ShaderMaterial.new()
	_body_mat.shader = BODY_SHADER
	_body_mat.set_shader_parameter("noise_tex", NOISE)
	for m in [_mat, _body_mat]:
		m.set_shader_parameter("color_a", p[0])
		m.set_shader_parameter("color_b", p[1])
		m.set_shader_parameter("spot", p[2])
	_body_mat.set_shader_parameter("npts", seg_count)
	for i in seg_count:
		var mi := MeshInstance3D.new()
		mi.set_instance_shader_parameter("seg_t", (float(i) + 0.5) / seg_count)
		mi.top_level = true
		mi.scale = Vector3(1.0, 1.0, 1.35)
		add_child(mi)
		_segs.append(mi)
	_body = MeshInstance3D.new()
	_body.mesh = _body_tube()
	_body.material_override = _body_mat
	_body.top_level = true
	var ext := spacing * seg_count + seg_radius * 4.0 + 1.0
	_body.custom_aabb = AABB(Vector3(-ext, -ext, -ext), Vector3(ext, ext, ext) * 2.0)
	_body.visibility_range_end = 80.0
	add_child(_body)
	# Head details: beady eyes and mandibles.
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.05, 0.05, 0.05)
	eye_mat.roughness = 0.2
	for side in [-1.0, 1.0]:
		var e := MeshInstance3D.new()
		var es := SphereMesh.new()
		es.radius = seg_radius * 0.22
		es.height = seg_radius * 0.44
		es.radial_segments = 8
		es.rings = 4
		e.mesh = es
		e.material_override = eye_mat
		e.position = Vector3(side * seg_radius * 0.55, seg_radius * 0.45, -seg_radius * 0.6)
		_segs[0].add_child(e)
		var m := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = seg_radius * 0.18
		cm.height = seg_radius * 0.9
		cm.radial_segments = 6
		m.mesh = cm
		m.material_override = _mat
		m.set_instance_shader_parameter("seg_t", 0.02)
		m.position = Vector3(side * seg_radius * 0.35, -seg_radius * 0.2, -seg_radius * 1.1)
		m.rotation = Vector3(-PI / 2 + 0.3, 0, side * -0.4)
		m.name = "Mandible"
		_segs[0].add_child(m)
	# Tiny bristly legs on larger bodies, merged into one mesh per segment.
	if kind > Kind.SMALL:
		var leg := CylinderMesh.new()
		leg.top_radius = 0.0
		leg.bottom_radius = seg_radius * 0.12
		leg.height = seg_radius * 1.2
		leg.radial_segments = 4
		for i in range(1, seg_count - 1):
			var parts := []
			for side in [-1.0, 1.0]:
				parts.append([leg, Transform3D(Basis.from_euler(Vector3(0, 0, side * 1.1)), Vector3(side * seg_radius * 0.8, -seg_radius * 0.35, 0))])
			var l := MeshInstance3D.new()
			l.mesh = MeshLib.merge(parts)
			l.material_override = _mat
			l.set_instance_shader_parameter("seg_t", (float(i) + 0.5) / seg_count)
			l.visibility_range_end = 40.0
			_segs[i].add_child(l)
	for sgi in _segs:
		for c in sgi.get_children():
			if c is GeometryInstance3D:
				c.visibility_range_end = 40.0


## Colour state on the body and its appendages: grey front (0..1, head to rear), hit flash, and
## the wind-up glow.
func set_look(gray: float, flash_v: float, windup_v: float) -> void:
	for m in [_mat, _body_mat]:
		m.set_shader_parameter("gray_front", gray)
		m.set_shader_parameter("flash", flash_v)
		m.set_shader_parameter("windup", windup_v)


## The shared body tube: rings along UV.y (head 0 .. tail 1, plus the rounded caps the shader
## adds beyond both ends), sides round UV.x. Positions are placed entirely by the shader.
static func _body_tube() -> ArrayMesh:
	if _tube != null:
		return _tube
	var rings := 34
	var sides := 10
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var nrm := PackedVector3Array()
	for j in rings:
		for k in sides + 1:
			verts.append(Vector3(0, 0, float(j) * 0.01))
			uvs.append(Vector2(float(k) / sides, float(j) / (rings - 1)))
			nrm.append(Vector3.UP)
	var idx := PackedInt32Array()
	for j in rings - 1:
		for k in sides:
			var a := j * (sides + 1) + k
			var b := a + 1
			var c := a + sides + 1
			var d := c + 1
			idx.append_array([a, c, b, b, c, d])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	_tube = ArrayMesh.new()
	_tube.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return _tube


func is_alive() -> bool:
	return hp > 0


## Continuing a saved run: this parasite was already cleared. Gone at once, no effects.
func restore_cleared() -> void:
	hp = 0
	state = "gone"
	visible = false
	set_physics_process(false)


func head_pos() -> Vector3:
	return global_position


## Closest body point to `p` (for hit tests).
func closest_body_point(p: Vector3) -> Vector3:
	var best := global_position
	var bd := INF
	for s in _segs:
		var d := s.global_position.distance_squared_to(p)
		if d < bd:
			bd = d
			best = s.global_position
	return best


func body_extent() -> float:
	return seg_radius


# --- Update ------------------------------------------------------------------------------

func _physics_process(dt: float) -> void:
	if state == "gone":
		return
	var g := Game.inst
	if state == "init":
		_init_on_ground()
		return
	# Parasites on other moss balls sleep (they don't respawn and keep their state).
	if state != "drifting" and g.player.ball != ball:
		return
	state_t += dt
	hit_cd = maxf(0.0, hit_cd - dt)
	_shaken = maxf(0.0, _shaken - dt)
	_alerted_t = maxf(0.0, _alerted_t - dt)
	_wary_t = maxf(0.0, _wary_t - dt)
	_perk_t = maxf(0.0, _perk_t - dt)
	_spit_cd = maxf(0.0, _spit_cd - dt)
	_quiet_t += dt
	_flash = maxf(0.0, _flash - dt * 3.0)
	_gray = move_toward(_gray, _gray_target, dt * 1.6)
	var target_windup := 1.0 if state == "windup" else 0.0
	_windup_v = move_toward(_windup_v, target_windup, dt * 4.0)
	set_look(_gray, _flash, _windup_v * (0.6 + 0.4 * sin(state_t * 30.0)))

	match state:
		"graze", "chase":
			_update_crawl(dt, g.player)
		"windup":
			if variant == "spitter":
				# It keeps its aim on him while it swells (the glob goes where he is when it spits).
				var to: Vector3 = g.player.global_position - global_position
				_face(to, dt * 8.0)
			else:
				_face(_attack_dir, dt * 10.0)
			_snap_ground()
			if kind == Kind.LARGE and fmod(state_t, 0.25) < dt:
				# Scraping the moss as it coils.
				WaterFX.inst.impulse(global_position - heading * spacing, 0.8, 0.3)
			if state_t >= windup_time:
				_set_state("attack")
				_attack_from = global_position
				_hurt_done = false
				if variant == "spitter":
					_spit(g.player)
				elif kind == Kind.LARGE:
					Sfx.play("parasite_charge", global_position, -1.0)
				else:
					Sfx.play("parasite_snap", global_position, -2.0)
		"attack":
			if variant == "spitter":
				# The recoil of the spit.
				_snap_ground()
				if state_t >= 0.25:
					_set_state("recover")
			elif kind == Kind.LARGE:
				_update_charge(dt, g.player)
			else:
				var k := minf(1.0, state_t / 0.22)
				var p := _attack_from + _attack_dir * lunge_dist * sin(k * PI * 0.5)
				global_position = p
				_snap_ground()
				var pl: Axolotl = g.player
				if pl.state == "normal" and pl.body_center().distance_to(global_position + up * seg_radius) < 0.55 + seg_radius:
					var hp0 := pl.health
					pl.take_damage(1, global_position)
					# (It latches only onto a bite that landed: never onto him while he is untouchable.)
					if kind == Kind.SMALL and pl.health < hp0:
						_latched = 0.45
					_set_state("recover")
				elif k >= 1.0:
					_set_state("recover")
		"recover":
			if _latched > 0.0:
				_latched -= dt
				var pl: Axolotl = g.player
				global_position = pl.body_center() + pl.up * 0.15 - pl.facing * 0.1
				if _latched <= 0.0:
					_snap_ground()
			else:
				_snap_ground()
			var rec := 0.7
			if kind == Kind.LARGE:
				rec = 1.5
			elif variant == "spitter":
				rec = 0.8
			if state_t >= rec:
				_circled = false
				_end_disruption()
		"knocked":
			global_position += vel * dt
			vel = vel.move_toward(Vector3.ZERO, dt * 8.0)
			_snap_ground()
			if state_t > 0.4:
				_end_disruption()
		"retreat":
			_update_retreat(dt, g.player)
		"flung":
			_update_flung(dt)
		"dying":
			_snap_ground()
			if state_t > 0.55:
				_detach()
		"drifting":
			_update_drift(dt)
	_update_segments(dt)


func _init_on_ground() -> void:
	up = spawn_dir
	var top := ball.surface_point(spawn_dir, spawn_h + 3.0)
	var q := PhysicsRayQueryParameters3D.create(top, ball.global_position, 1 | 2)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		global_position = ball.surface_point(spawn_dir, _ground_offset)
	else:
		global_position = hit.position + up * _ground_offset
		standing_on = hit.collider
	heading = MossBall.frame_at(up, randf() * 360.0).z * -1.0
	for i in 12:
		_trail.push_back(global_position + heading * -spacing * i * 0.5)
		_trail_up.push_back(up)
	state = "graze"
	_graze_target = global_position
	# Laid out where it is at once (a parasite on another ball sleeps until the axolotl arrives).
	_update_segments(0.0)


func _set_state(s: String) -> void:
	state = s
	state_t = 0.0


func _update_crawl(dt: float, pl: Axolotl) -> void:
	var to_player := pl.global_position - global_position
	var d := to_player.length()
	var player_here := pl.ball == ball and pl.state == "normal"
	var in_home := _angle_from_home(pl.global_position) < home_radius * 1.7
	# Sight (never through rock): checked a few times a second, and only when he is near.
	_los_check -= dt
	if _los_check <= 0.0:
		_los_check = 0.2
		_los = player_here and d < 12.0 and _sees(pl)
	var aggro := 7.5 if kind == Kind.LARGE else 6.5
	if variant == "spitter":
		aggro = 9.0
	if _wary_t > 0.0:
		aggro *= 0.5
	var alerted := _alerted_t > 0.0
	var engaged := state == "chase"
	var noticed := player_here and in_home and absf(to_player.dot(up)) < 2.2 and (d < aggro or (alerted and d < 12.0))
	var keep := _los or (engaged and _unseen_t < (2.5 if alerted else 1.5))
	if noticed and keep:
		if not engaged:
			_set_state("chase")
			_mode = "approach"
			_mode_t = 0.0
			if not alerted:
				_alert_nearby(pl)
				# Joining a fight already under way: it takes its own side.
				var others := 0
				for q in ball.parasites:
					if q != self and q.is_alive() and q.state in ["chase", "windup", "attack"] and q.global_position.distance_to(pl.global_position) < 6.0:
						others += 1
				if others > 0:
					_flank = (1.0 if others % 2 == 1 else -1.0) * deg_to_rad(40.0 + _rng.randf() * 30.0)
	elif engaged:
		_set_state("graze")
	if state == "chase":
		_unseen_t = 0.0 if _los else _unseen_t + dt
	var dir: Vector3
	var spd := speed
	if state == "chase":
		_mode_t += dt
		var flat := to_player - up * to_player.dot(up)
		if variant == "spitter":
			var r: Array = _spitter_move(dt, pl, flat, d)
			if r.is_empty():
				return
			dir = r[0]
			spd = r[1]
		else:
			if d < attack_reach and hit_cd <= 0.0 and _shaken <= 0.0 and _mode != "circle":
				if _may_commit():
					_commit(flat.normalized())
					return
				# Waiting its turn: hold just out of reach, facing him, shuffling apart from the others.
				_face(flat.normalized(), dt * 6.0)
				_spread_apart(dt)
				_snap_ground()
				return
			dir = flat
			# Joining a group: come in from its own side rather than queueing behind the others.
			if _flank != 0.0 and d > attack_reach * 1.2:
				var from_him := -flat.normalized()
				var spot := pl.global_position + from_him.rotated(up, _flank) * attack_reach * 0.9
				dir = spot - global_position
				dir -= up * dir.dot(up)
			match kind:
				Kind.SMALL:
					# Darting: quick bursts and pauses, zig-zagging in.
					var ph := fmod(_clock * 1.7 + _rng.seed % 97 * 0.01, 1.0)
					spd = speed * (1.75 if ph < 0.55 else 0.3)
					dir = dir.rotated(up, sin(ph * TAU) * 0.45)
				Kind.MEDIUM:
					if _mode == "approach" and not _circled and d < 3.4 and d > attack_reach * 0.7:
						_mode = "circle"
						_mode_t = 0.0
						_circle_len = _rng.randf_range(1.0, 2.2)
					if _mode == "circle":
						# Round him at a wary distance, looking for his side or back.
						var from_him := -flat.normalized()
						var spot := pl.global_position + from_him.rotated(up, _circle_dir * 0.9) * 2.6
						dir = spot - global_position
						dir -= up * dir.dot(up)
						spd = speed * 1.1
						var behind := pl.facing.dot(from_him) < -0.1
						if _mode_t > _circle_len or (_mode_t > 0.6 and behind) or not _ground_ahead(global_position + heading * 0.6):
							_mode = "approach"
							_circled = true
			if d < attack_reach * 0.8 and _mode != "circle":
				spd = 0.0
			_spread_apart(dt)
	else:
		spd = speed * 0.35
		_graze_t -= dt
		if _graze_t <= 0.0 or global_position.distance_to(_graze_target) < 0.4:
			_graze_t = randf_range(1.5, 3.5)
			var b := MossBall.frame_at(home_dir, randf() * 360.0)
			var a := randf() * home_radius * 0.8
			var gd := home_dir.rotated(b.x, a).rotated(home_dir, randf() * TAU)
			_graze_target = ball.surface_point(gd, 0.0)
		dir = _graze_target - global_position
		dir -= up * dir.dot(up)
		dir = _avoid_blooms(dir)
		_try_recover()
	# Stay inside the home area.
	if _angle_from_home(global_position) > home_radius:
		var back := ball.surface_point(home_dir) - global_position
		dir = (back - up * back.dot(up))
	_move(dir, spd, dt)


## Walks along `dir` at `spd`, gripping the moss (never off a ledge on its own).
func _move(dir: Vector3, spd: float, dt: float) -> void:
	if dir.length() > 0.01:
		_face(dir.normalized(), dt * 5.0)
	var step := heading * spd * dt + _pushed * dt
	_pushed = _pushed.move_toward(Vector3.ZERO, dt * 6.0)
	# Parasites grip the moss: they never crawl off a ledge on their own.
	if step.length() > 0.0001 and not _ground_ahead(global_position + step * 4.0):
		_graze_target = global_position - heading * 1.0
		_graze_t = 1.0
		heading = -heading
		step = Vector3.ZERO
	global_position += step
	_snap_ground()


## A spitter's footwork: back off when he is close, close in when he is far, sidle in between;
## and spit when it has a clear, on-screen shot. Returns [dir, speed], or [] when it committed.
func _spitter_move(dt: float, pl: Axolotl, flat: Vector3, d: float) -> Array:
	var toward := flat.normalized() if flat.length() > 0.01 else heading
	if d < attack_reach and hit_cd <= 0.0 and _shaken <= 0.0 and _may_commit():
		# Cornered at close range: a plain bite.
		variant = ""
		_commit(toward)
		variant = "spitter"
		_spit_cd = maxf(_spit_cd, 1.0)
		return []
	if d > 2.6 and d < 9.0 and _los and _spit_cd <= 0.0 and _glob == null and _shaken <= 0.0 and _on_screen() and _may_commit():
		_last_commit[ball.get_instance_id()] = Engine.get_physics_frames()
		_attack_dir = toward
		_set_state("windup")
		Sfx.play("parasite_spit_windup", global_position, -3.0)
		return []
	var dir: Vector3
	var spd := speed
	if d < 3.4:
		dir = -toward
		spd = speed * 0.8
		if not _ground_ahead(global_position - toward * 0.8):
			dir = toward.cross(up) * _circle_dir
	elif d > 7.0:
		dir = toward
	else:
		dir = toward.cross(up) * _circle_dir + toward * 0.2
		spd = speed * 0.35
	_spread_apart(dt)
	# It keeps looking at him as it moves.
	_face(toward, dt * 3.0)
	return [dir, spd]


## Spits a glob at him (aimed where he is now: no homing).
func _spit(pl: Axolotl) -> void:
	_spit_cd = 2.6
	var from := global_position + up * (seg_radius * 2.5) + heading * seg_radius * 1.5
	var gl := ParasiteGlob.new()
	gl.launch(self, ball, from, pl.body_center())
	_glob = gl
	Sfx.play("parasite_spit", from, -2.0)


## The large parasite's charge: a committed run along the line it locked while coiling, carried
## by its weight (speeds up, then runs on). Stops at rock or a drop, and recovers slowly.
func _update_charge(dt: float, pl: Axolotl) -> void:
	var dur := 0.6
	var k := minf(1.0, state_t / dur)
	var target := _attack_from + _attack_dir * lunge_dist * (k * k * (3.0 - 2.0 * k))
	var step := target - global_position
	if step.length() > 0.0001:
		var q := PhysicsRayQueryParameters3D.create(global_position + up * 0.4, target + up * 0.4 + step.normalized() * 0.3, 1)
		var blocked := not get_world_3d().direct_space_state.intersect_ray(q).is_empty()
		if blocked or not _ground_ahead(target + step.normalized() * 0.4):
			_set_state("recover")
			return
	global_position = target
	_snap_ground()
	if not _hurt_done and pl.state == "normal":
		var c := pl.body_center()
		var reach := 0.6 + seg_radius
		if c.distance_to(global_position + up * seg_radius) < reach or c.distance_to(_segs[1].global_position) < reach:
			pl.take_damage(1, global_position)
			_hurt_done = true
	if k >= 1.0:
		_set_state("recover")


## Commits to its attack toward `dir` (starts the wind-up).
func _commit(dir: Vector3) -> void:
	_last_commit[ball.get_instance_id()] = Engine.get_physics_frames()
	_attack_dir = dir
	_set_state("windup")
	if kind == Kind.LARGE:
		Sfx.play("parasite_charge_windup", global_position, -1.0)
	else:
		Sfx.play("parasite_windup", global_position, -4.0)


## Whether the ball's attack budget has room: at most MAX_COMMITTED attackers (and globs in flight)
## at once, and attacks starting at least COMMIT_GAP_FRAMES apart.
func _may_commit() -> bool:
	var n := ParasiteGlob.incoming_on(ball)
	for q in ball.parasites:
		if q != self and q.is_alive() and q.state in ["windup", "attack"]:
			n += 1
	if n >= MAX_COMMITTED:
		return false
	var last: int = _last_commit.get(ball.get_instance_id(), -100000)
	return Engine.get_physics_frames() - last >= COMMIT_GAP_FRAMES


## Line of sight to him over the terrain (two rays, low and high, so a hummock between them does
## not blind it but rock does).
func _sees(pl: Axolotl) -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + up * 0.6, pl.body_center() + pl.up * 0.2, 1)
	if space.intersect_ray(q).is_empty():
		return true
	q = PhysicsRayQueryParameters3D.create(global_position + up * 1.3, pl.body_center() + pl.up * 0.9, 1)
	return space.intersect_ray(q).is_empty()


## On the player's screen and not far off (spitters never shoot from off-screen).
func _on_screen() -> bool:
	var cam := get_viewport().get_camera_3d()
	return cam != null and cam.global_position.distance_to(global_position) < 24.0 and cam.is_position_in_frustum(global_position + up * 0.3)


## It spotted him: grazing neighbours close by (whose territory he is in) join in, each from its
## own side. Only a parasite that saw him itself raises the alarm (no chain across the ball).
func _alert_nearby(pl: Axolotl) -> void:
	var k := 0
	for q in ball.parasites:
		if q == self or not q.is_alive() or q.state != "graze":
			continue
		if q.global_position.distance_to(global_position) > ALERT_R:
			continue
		if q._angle_from_home(pl.global_position) > q.home_radius * 1.7:
			continue
		k += 1
		q.alert(k)
	if k > 0:
		_perk_t = 0.35
		Sfx.play("parasite_alert", global_position, -3.0)


## Alerted by a neighbour: it joins the hunt from its own side (the k-th joiner alternates sides).
func alert(k: int) -> void:
	_alerted_t = 5.0
	_perk_t = 0.35
	_flank = (1.0 if k % 2 == 1 else -1.0) * deg_to_rad(40.0 + _rng.randf() * 30.0)
	_set_state("chase")
	_mode = "approach"
	_mode_t = 0.0
	_los_check = 0.0


## A push away from other engaged parasites close by (they spread round him, not stack).
func _separation() -> Vector3:
	var push := Vector3.ZERO
	for q in ball.parasites:
		if q == self or not q.is_alive() or not q.state in ["chase", "windup", "retreat"]:
			continue
		var off: Vector3 = global_position - q.global_position
		off -= up * off.dot(up)
		var dd: float = off.length()
		if dd < 1.2 and dd > 0.001:
			push += off / dd * (1.2 - dd)
	return push


## Shuffles sideways away from engaged neighbours that are too close (also while it holds still).
func _spread_apart(dt: float) -> void:
	var push := _separation()
	if push.length() < 0.001:
		return
	var step := push.normalized() * minf(push.length() * 2.5, 1.5) * dt
	if _ground_ahead(global_position + step * 6.0):
		global_position += step


## Grazing and fleeing parasites keep off the blooms (they never camp a re-forming point).
func _avoid_blooms(dir: Vector3) -> Vector3:
	for bl in ball.blooms:
		if not bl.is_placed():
			continue
		var off: Vector3 = global_position - bl.respawn_point()
		off -= up * off.dot(up)
		if off.length() < 2.2:
			dir = off.normalized() * maxf(dir.length(), 0.5) + dir * 0.2
	return dir


## After a knock or a recovery: a hurt one that would rather live flees; others carry on.
func _end_disruption() -> void:
	if _want_retreat and hp > 0:
		_want_retreat = false
		_set_state("retreat")
		Sfx.play("parasite_flee", global_position, -3.0)
	else:
		_set_state("graze")


## Fleeing: away from him, faster than it crawls, but never out of its own territory (it runs
## along its edge instead). Gives up after a few seconds or once clear, and stays wary a while.
func _update_retreat(dt: float, pl: Axolotl) -> void:
	var away := global_position - pl.global_position
	away -= up * away.dot(up)
	var dir := away.normalized() if away.length() > 0.01 else -heading
	var ang := _angle_from_home(global_position)
	if ang > home_radius * 0.75:
		var inward := ball.surface_point(home_dir) - global_position
		inward = (inward - up * inward.dot(up)).normalized()
		if dir.dot(inward) < 0.0:
			dir -= inward * dir.dot(inward)
			if dir.length() < 0.05:
				dir = inward.cross(up)
		if ang > home_radius * 0.92:
			dir += inward * 1.5
		dir = dir.normalized()
	dir = _avoid_blooms(dir)
	_move(dir, speed * 1.35, dt)
	if state != "retreat":
		return
	if state_t > 4.0 or away.length() > 7.5 or pl.ball != ball:
		_wary_t = 3.0
		_set_state("graze")


## Left alone long enough after fleeing hurt, it regains one stage of vitality (once per escape).
func _try_recover() -> void:
	if not _regen_ok or hp <= 0 or hp >= max_hp or _quiet_t < 10.0:
		return
	var pl: Axolotl = Game.inst.player
	if pl.ball == ball and pl.global_position.distance_to(global_position) < 6.0:
		return
	hp += 1
	_regen_ok = false
	_gray_target = 1.0 - float(hp) / max_hp
	WaterFX.inst.sparkle(global_position, Color(1.0, 0.5, 0.8, 0.8), 8, 0.8, 0.05, 0.8)


func _angle_from_home(p: Vector3) -> float:
	return ball.up_at(p).angle_to(home_dir)


func _face(dir: Vector3, t: float) -> void:
	var d := dir - up * dir.dot(up)
	if d.length() < 0.001:
		return
	heading = heading.slerp(d.normalized(), clampf(t, 0.0, 1.0)).normalized() if heading.dot(d.normalized()) > -0.99 else d.normalized()
	heading = (heading - up * heading.dot(up)).normalized()


func _ground_ahead(p: Vector3) -> bool:
	var u := ball.up_at(p)
	var q := PhysicsRayQueryParameters3D.create(p + u * 1.0, p - u * 0.9, 1 | 2)
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _snap_ground() -> void:
	up = ball.up_at(global_position)
	var from := global_position + up * 1.2
	var q := PhysicsRayQueryParameters3D.create(from, global_position - up * 2.0, 1 | 2)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		if state in ["graze", "chase", "recover", "knocked", "retreat"]:
			# Walked off a plant: fall.
			vel = -up * 1.0
			_set_state("flung")
		return
	global_position = hit.position + up * _ground_offset
	standing_on = hit.collider


func _update_segments(dt: float) -> void:
	_clock += dt
	var head := global_position
	if _trail.is_empty() or _trail[0].distance_to(head) > spacing * 0.35:
		_trail.push_front(head)
		_trail_up.push_front(up)
		if _trail.size() > seg_count * 6 + 4:
			_trail.pop_back()
			_trail_up.pop_back()
	else:
		_trail[0] = head
		_trail_up[0] = up
	var rear_lift := 0.0
	if state == "windup":
		rear_lift = minf(1.0, state_t / windup_time) * (1.35 if kind == Kind.LARGE else 1.0)
	elif _perk_t > 0.0:
		# Perks up (spotting him, or hearing the alarm).
		rear_lift = 0.45 * sin(_perk_t / 0.35 * PI)
	elif state == "recover" and kind == Kind.LARGE:
		# Spent after a charge: head low.
		rear_lift = -0.35 * (1.0 - minf(1.0, state_t / 1.5))
	# Body length: coiled while winding up, stretched in a lunge or charge, long and low in flight.
	var stretch := 1.0
	match state:
		"windup":
			stretch = 0.72 if kind == Kind.LARGE else 0.82
		"attack":
			stretch = 1.25 if kind == Kind.LARGE else 1.15
		"retreat":
			stretch = 1.1
	_stretch_v = lerpf(_stretch_v, stretch, 1.0 - exp(-dt * 10.0)) if dt > 0.0 else stretch
	# Travelling body wave. The head lays down the path (the trail); every segment sits on that
	# path at its own distance behind the head, so turns bend the body progressively. On top of
	# that, a sideways wave whose phase advances with the distance the head has travelled: crests
	# start near the head and roll back towards the tail as the creature moves, like a crawling
	# centipede or a swimming worm. Standing still, a slow restrained ripple remains.
	var moved := 0.0 if _last_head == Vector3.ZERO else minf(head.distance_to(_last_head), speed * 3.0 * dt + 0.05)
	_last_head = head
	var body_len := spacing * maxf(2.0, seg_count - 1)
	var wavelength := body_len * 1.3
	_wave_phase = fmod(_wave_phase + moved / wavelength * TAU + dt * 1.1, TAU * 64.0)
	var pace := clampf(moved / maxf(dt * speed, 0.0001), 0.0, 1.2) if dt > 0.0 else 0.0
	_wave_amp = lerpf(_wave_amp, seg_radius * (0.1 + 0.34 * pace), 1.0 - exp(-dt * 6.0))
	var base: Array[Vector3] = []
	var ups: Array[Vector3] = []
	for i in seg_count:
		var dist := spacing * i * _stretch_v
		base.append(_sample_trail(dist))
		ups.append(_trail_up[mini(_trail_up.size() - 1, int(dist / (spacing * 0.35)))])
	var limp: Array[Vector3] = []
	if state == "drifting":
		limp = _limp_chain()
	for i in seg_count:
		var p: Vector3 = base[i]
		var u: Vector3 = ups[i]
		if state == "drifting":
			p = limp[i]
			u = global_basis.y
		else:
			# Struck (Expansion 6): one or two quick residual twitches that die away at once.
			if state == "dying":
				var tw := exp(-state_t * 7.0) * seg_radius * 1.1
				var ax: Vector3 = heading if i == 0 else (base[i - 1] - base[i])
				ax -= u * ax.dot(u)
				if ax.length() > 0.0001:
					p += ax.normalized().cross(u) * tw * sin(state_t * 34.0 - float(i) * 1.2) * lerpf(0.4, 1.0, float(i) / maxf(1.0, seg_count - 1))
			if i == 0:
				p += u * rear_lift * seg_radius * 1.6
			elif i == 1:
				p += u * rear_lift * seg_radius * 0.8
			# Sideways, across the path at this segment (not across the head's heading).
			var along: Vector3 = heading if i == 0 else (base[i - 1] - base[i])
			along -= u * along.dot(u)
			if along.length() > 0.0001:
				var t_body := float(i) / maxf(1.0, seg_count - 1)
				var env := lerpf(0.3, 1.0, t_body) * (1.0 - clampf(rear_lift, 0.0, 1.0))
				p += along.normalized().cross(u) * _wave_amp * env * sin(_wave_phase - TAU * spacing * i / wavelength)
		var s := _segs[i]
		var ahead := head if i == 0 else _segs[i - 1].global_position
		var fwd := (ahead - p) if i > 0 else heading
		if state == "drifting" and i == 0:
			fwd = -global_basis.z
		fwd = fwd - u * fwd.dot(u)
		if fwd.length() < 0.001:
			fwd = heading
		var right := fwd.normalized().cross(u).normalized()
		var sc := s.scale
		s.global_transform = Transform3D(Basis(right, u, -fwd.normalized()).orthonormalized().scaled(sc), p)
	_push_body()
	if state == "windup" or (state == "attack" and kind == Kind.LARGE):
		var open := 0.9 if state == "windup" else 0.3
		for c in _segs[0].get_children():
			if c.name.begins_with("Mandible"):
				var side := signf(c.position.x)
				c.rotation.z = side * -(0.4 + open)


## The body tube follows the segment anchors: their positions (with the body's taper as radius)
## and ups, sent to the body shader.
func _push_body() -> void:
	var pts := PackedVector4Array()
	var ups := PackedVector4Array()
	pts.resize(MAX_SEGS)
	ups.resize(MAX_SEGS)
	for i in seg_count:
		var t := float(i) / maxf(1.0, seg_count - 1)
		var r := seg_radius * (1.0 - 0.5 * pow(t, 1.4)) * (1.08 if i == 0 else 1.0)
		var sp := _segs[i].global_position
		pts[i] = Vector4(sp.x, sp.y, sp.z, r)
		var su := _segs[i].global_basis.y.normalized()
		ups[i] = Vector4(su.x, su.y, su.z, 0.0)
	_body.global_position = _segs[0].global_position
	_body_mat.set_shader_parameter("pts", pts)
	_body_mat.set_shader_parameter("ups", ups)


## Defeated and adrift (Expansion 6): not a rigid stick. The body hangs in a gentle limp curve that
## sags as it relaxes, with a weak ripple running to the tail (the tail lagging behind) that dies
## away over the first seconds.
func _limp_chain() -> Array[Vector3]:
	var out: Array[Vector3] = []
	var p := global_position
	var dir := global_basis.z.normalized()
	var ax := global_basis.y.normalized()
	var ax2 := global_basis.x.normalized()
	var relax := exp(-_drift_t * 1.4)
	for i in seg_count:
		out.append(p)
		var tt := float(i) / maxf(1.0, seg_count - 1)
		var bend := 0.16 * (1.0 - relax * 0.6) + sin(_drift_t * 6.5 - float(i) * 1.1) * 0.42 * relax * (0.3 + tt)
		dir = dir.rotated(ax, bend).rotated(ax2, 0.07 * (1.0 - relax * 0.5)).normalized()
		p += dir * spacing
	return out


func _sample_trail(dist: float) -> Vector3:
	var acc := 0.0
	for i in range(_trail.size() - 1):
		var a := _trail[i]
		var b := _trail[i + 1]
		var l := a.distance_to(b)
		if acc + l >= dist:
			return a.lerp(b, (dist - acc) / maxf(l, 0.0001))
		acc += l
	return _trail[_trail.size() - 1] if _trail.size() > 0 else global_position


# --- Damage ------------------------------------------------------------------------------

## stages: damage stages; knock: direction of knockback (tangent), strength scale.
func hit(stages: int, from_pos: Vector3, knock := 1.0) -> bool:
	if hp <= 0 or hit_cd > 0.0 or state in ["dying", "drifting", "gone", "init"]:
		return false
	hp = maxi(0, hp - stages)
	hit_cd = 0.25
	_flash = 0.6
	_gray_target = 1.0 - float(hp) / max_hp
	_latched = 0.0
	_quiet_t = 0.0
	Sfx.play("hit", global_position)
	# Badly hurt, a timid one breaks off once the blow's knock is over (see _end_disruption).
	if hp > 0 and not _brave and kind != Kind.SMALL and float(hp) <= max_hp * 0.5:
		_want_retreat = true
		_regen_ok = true
	if hp <= 0:
		_set_state("dying")
		_gray_target = 1.0
		Game.inst.parasite_killed(self)
		return true
	var away := global_position - from_pos
	away -= up * away.dot(up)
	away = away.normalized() if away.length() > 0.01 else heading * -1.0
	if kind == Kind.LARGE:
		# Partially dislodged: lifted off the moss where the current can carry it.
		vel = away * 5.5 * knock + up * 4.0
		_set_state("flung")
	else:
		vel = away * 5.0 * knock
		_set_state("knocked")
	return true


## Startled back from `from_pos` (the bloom's pulse when the axolotl re-forms there), unhurt: it
## scuttles a few metres off, then carries on.
func startle(from_pos: Vector3) -> void:
	if not state in ["graze", "chase", "windup", "attack", "recover"]:
		return
	var away := global_position - from_pos
	away -= up * away.dot(up)
	away = away.normalized() if away.length() > 0.01 else heading * -1.0
	vel = away * 7.0
	_latched = 0.0
	# Shaken: it may come back, but holds off attacking for a while (a unit test found one
	# returning to strike just as the re-formed axolotl's grace ran out).
	_shaken = 3.5
	_set_state("knocked")


## Thrown into open water by a rebounding plant (or a big impact).
func fling(v: Vector3) -> void:
	if hp <= 0 or state in ["dying", "drifting", "gone", "init"]:
		return
	vel = v
	_latched = 0.0
	_set_state("flung")


func _update_flung(dt: float) -> void:
	up = ball.up_at(global_position)
	vel -= up * 9.0 * dt
	vel += ball.current_at(global_position) * 2.2 * dt
	vel *= 1.0 - 0.6 * dt
	var from := global_position
	var to := from + vel * dt
	# Scramble back toward home while airborne (swim/scramble to latch on).
	var home := ball.surface_point(home_dir) - global_position
	vel += (home - up * home.dot(up)).normalized() * 1.2 * dt
	var q := PhysicsRayQueryParameters3D.create(from, to - up * _ground_offset, 1 | 2)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and state_t > 0.2 and vel.dot(up) <= 0.5:
		global_position = hit.position + up * _ground_offset
		standing_on = hit.collider
		# Re-latch: its home is now wherever it grabbed on.
		home_dir = ball.up_at(global_position)
		_set_state("recover")
		return
	global_position = to
	if (global_position - ball.global_position).length() < ball.radius:
		global_position = ball.surface_point(ball.up_at(global_position), _ground_offset)
		home_dir = ball.up_at(global_position)
		_set_state("recover")


func _detach() -> void:
	# Loses its grip; the aquarium current carries the grey body away.
	_set_state("drifting")
	top_level = true
	var u := up
	global_transform = Transform3D(Basis(heading.cross(u).normalized(), u, -heading), global_position)
	vel = u * 2.6 + Game.inst.tank_flow() * 0.6 + ball.current_at(global_position)
	_spin = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.35


func _update_drift(dt: float) -> void:
	_drift_t += dt
	var away := ball.up_at(global_position)
	var target_v := away * 1.6 + Game.inst.tank_flow()
	vel = vel.lerp(target_v, minf(1.0, dt * 0.3))
	global_position += vel * dt
	global_basis = (global_basis * Basis.from_euler(_spin * dt)).orthonormalized()
	_update_segments(dt)
	var cam := get_viewport().get_camera_3d()
	var far := cam == null or cam.global_position.distance_to(global_position) > 45.0
	if _drift_t > 14.0 or (far and _drift_t > 3.0):
		# Hand over to a cheap drifting speck (never popped out of existence).
		WaterFX.inst.add_debris(global_position, vel)
		state = "gone"
		visible = false
		set_physics_process(false)


func water_push(v: Vector3) -> void:
	if state in ["graze", "chase", "retreat"]:
		_pushed += v
