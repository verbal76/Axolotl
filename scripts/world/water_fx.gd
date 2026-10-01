class_name WaterFX
extends Node3D
## Lightweight illusion of responsive water: bounded local impulses (fed to vegetation,
## moss and particulate shaders), a camera-wrapped cloud of suspended particles, pooled
## billboard puffs (bubbles, sparkles), and cheap drifting specks for distant dead parasites.

## Cosmetic randomness (Expansion 6): its own generator, never the gameplay random sequence
## that deterministic playthroughs and tests rely on.
static var _fx_rng := RandomNumberGenerator.new()

static var inst: WaterFX

const MAX_IMPULSES := 8
const PUFF_POOL := 220
const DEBRIS_POOL := 48
## Drag marks (ledger row 19): small scrapes his braced feet leave in the moss and gravel when a
## current pushes him along the ground. A fixed pool drawn as one multimesh (one draw call); each
## mark lives MARK_LIFE seconds, fading out over its last MARK_FADE, and the oldest is reused when
## the pool is full. No random numbers: each mark's variant comes from a counter.
const MARK_POOL := 32
const MARK_LIFE := 3.2
const MARK_FADE := 2.4
const MARK_LIFT := 0.012           # above the ground, against z-fighting

var _imp_pos: Array[Vector3] = []
var _imp_str: Array[float] = []
var _imp_life: Array[float] = []
var _imp_max: Array[float] = []

var specks_mat: ShaderMaterial
var _specks: MultiMeshInstance3D
var speck_count := 420
var murk := 1.0

var _puff_mm: MultiMesh
var _puffs: Array = []      # [pos, vel, life, max_life, size, color, drag, rise]
var _puff_next := 0

var _debris_mm: MultiMesh
var _debris: Array = []     # [pos, vel, age]
var _debris_next := 0

var _mark_mm: MultiMesh
var _mark_mi: MultiMeshInstance3D          # hidden while no mark is alive (no draw call)
var _mark_age := PackedFloat32Array()     # seconds since it was scraped; < 0 free
var _mark_str := PackedFloat32Array()
var _mark_gen := PackedInt32Array()       # bumped each time a slot is reused (stale handles fail)
var _mark_next := 0
var _mark_count := 0                      # marks scraped since start (also each one's variant)
var marks_live := 0

var mote_uniform := PackedVector4Array()
var mote_count := 0


func _init() -> void:
	inst = self


func _ready() -> void:
	for i in MAX_IMPULSES:
		_imp_pos.append(Vector3.ZERO)
		_imp_str.append(0.0)
		_imp_life.append(0.0)
		_imp_max.append(1.0)
	mote_uniform.resize(6)

	# Suspended particles.
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = q
	mm.instance_count = 900
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in mm.instance_count:
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(rng.randf(), rng.randf(), rng.randf())))
	mm.visible_instance_count = speck_count
	mm.custom_aabb = AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000))
	specks_mat = ShaderMaterial.new()
	specks_mat.shader = preload("res://shaders/specks.gdshader")
	_specks = MultiMeshInstance3D.new()
	_specks.multimesh = mm
	_specks.material_override = specks_mat
	_specks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_specks)

	# Puffs.
	_puff_mm = MultiMesh.new()
	_puff_mm.transform_format = MultiMesh.TRANSFORM_3D
	_puff_mm.use_colors = true
	_puff_mm.mesh = q
	_puff_mm.instance_count = PUFF_POOL
	_puff_mm.custom_aabb = AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000))
	for i in PUFF_POOL:
		_puffs.append([Vector3.ZERO, Vector3.ZERO, 0.0, 1.0, 0.1, Color(1, 1, 1, 0), 1.0, Vector3.ZERO])
		_puff_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.0001), Vector3(0, -9999, 0)))
		_puff_mm.set_instance_color(i, Color(0, 0, 0, 0))
	var pm := ShaderMaterial.new()
	pm.shader = preload("res://shaders/puff.gdshader")
	var pmi := MultiMeshInstance3D.new()
	pmi.multimesh = _puff_mm
	pmi.material_override = pm
	pmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pmi)

	# Debris specks (dead parasites far away).
	_debris_mm = MultiMesh.new()
	_debris_mm.transform_format = MultiMesh.TRANSFORM_3D
	_debris_mm.use_colors = true
	_debris_mm.mesh = q
	_debris_mm.instance_count = DEBRIS_POOL
	_debris_mm.custom_aabb = AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000))
	for i in DEBRIS_POOL:
		_debris.append(null)
		_debris_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.0001), Vector3(0, -9999, 0)))
		_debris_mm.set_instance_color(i, Color(0, 0, 0, 0))
	var dmi := MultiMeshInstance3D.new()
	dmi.multimesh = _debris_mm
	dmi.material_override = pm
	dmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dmi)

	# Drag marks.
	var plane := PlaneMesh.new()
	plane.size = Vector2(1, 1)
	# (A few rows along it, so a mark follows the moss's lumps.)
	plane.subdivide_depth = 3
	_mark_mm = MultiMesh.new()
	_mark_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mark_mm.use_colors = true
	_mark_mm.use_custom_data = true
	_mark_mm.mesh = plane
	_mark_mm.instance_count = MARK_POOL
	_mark_mm.custom_aabb = AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000))
	_mark_age.resize(MARK_POOL)
	_mark_str.resize(MARK_POOL)
	_mark_gen.resize(MARK_POOL)
	for i in MARK_POOL:
		_mark_age[i] = -1.0
		_hide_mark(i)
	var mm_mat := ShaderMaterial.new()
	mm_mat.shader = preload("res://shaders/drag_mark.gdshader")
	mm_mat.set_shader_parameter("noise_tex", MossBall.NOISE)
	_mark_mi = MultiMeshInstance3D.new()
	_mark_mi.multimesh = _mark_mm
	_mark_mi.material_override = mm_mat
	_mark_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mark_mi.visible = false
	add_child(_mark_mi)


func set_speck_density(n: int) -> void:
	speck_count = n
	_specks.multimesh.visible_instance_count = n


# --- Impulses ----------------------------------------------------------------------------

## A local water push at `pos`. strength ~0.5 (step) .. 3 (extreme landing).
func impulse(pos: Vector3, strength: float, life := 0.5) -> void:
	var slot := 0
	var weakest := INF
	for i in MAX_IMPULSES:
		var s := _current_strength(i)
		if s < weakest:
			weakest = s
			slot = i
	_imp_pos[slot] = pos
	_imp_str[slot] = strength
	_imp_life[slot] = life
	_imp_max[slot] = life
	var g := Game.inst
	if g:
		g.on_water_impulse(pos, strength)


func _current_strength(i: int) -> float:
	if _imp_life[i] <= 0.0:
		return 0.0
	return _imp_str[i] * (_imp_life[i] / _imp_max[i])


## Strength of water disturbance at a position (for motes/food reacting to impulses).
func push_at(pos: Vector3) -> Vector3:
	var push := Vector3.ZERO
	for i in MAX_IMPULSES:
		var s := _current_strength(i)
		if s <= 0.0:
			continue
		var d := pos - _imp_pos[i]
		var dist := d.length()
		if dist > 5.0:
			continue
		push += d / maxf(dist, 0.1) * s / (1.0 + dist * dist * 0.8)
	return push


func trail(pos: Vector3, strength: float) -> void:
	if _fx_rng.randf() < 0.25:
		impulse(pos, strength, 0.3)
	if _fx_rng.randf() < 0.3:
		_spawn_puff(pos + Vector3(_fx_rng.randf() - 0.5, _fx_rng.randf() - 0.5, _fx_rng.randf() - 0.5) * 0.3, Vector3.ZERO, 0.8, 0.05, Color(0.85, 0.95, 1.0, 0.5), 0.9, _up_of(pos) * 0.8)


func _up_of(pos: Vector3) -> Vector3:
	var g := Game.inst
	if g and g.player and g.player.ball:
		return g.player.ball.up_at(pos)
	return Vector3.UP


# --- Puff effects ------------------------------------------------------------------------

func _spawn_puff(pos: Vector3, vel: Vector3, life: float, size: float, col: Color, drag := 1.5, rise := Vector3.ZERO) -> void:
	var p: Array = _puffs[_puff_next]
	p[0] = pos
	p[1] = vel
	p[2] = life
	p[3] = life
	p[4] = size
	p[5] = col
	p[6] = drag
	p[7] = rise
	_puff_next = (_puff_next + 1) % PUFF_POOL


func burst_fx(pos: Vector3, back_dir: Vector3, up: Vector3) -> void:
	for i in 18:
		var spread := Vector3(_fx_rng.randf() - 0.5, _fx_rng.randf() - 0.5, _fx_rng.randf() - 0.5) * 1.4
		_spawn_puff(pos, (back_dir + spread).normalized() * _fx_rng.randf_range(3.0, 7.0), _fx_rng.randf_range(0.5, 0.9), _fx_rng.randf_range(0.04, 0.1), Color(0.85, 0.97, 1.0, 0.8), 3.5, up * 1.2)


func landing_ring(pos: Vector3, up: Vector3, radius: float) -> void:
	var b := MossBall.frame_at(up, 0)
	var n := 26 if radius > 3.5 else 18
	for i in n:
		var a := TAU * i / n
		var d := b.x * cos(a) + b.z * sin(a)
		_spawn_puff(pos + up * 0.15, d * radius * 2.2, 0.55, _fx_rng.randf_range(0.06, 0.12), Color(0.8, 0.95, 1.0, 0.7), 3.0, up * 0.6)
	for i in 8:
		_spawn_puff(pos + up * 0.1, (up + Vector3(_fx_rng.randf() - 0.5, _fx_rng.randf() - 0.5, _fx_rng.randf() - 0.5)).normalized() * 2.0, 0.7, 0.08, Color(0.55, 0.5, 0.4, 0.5), 2.0)


## Water Cannon: a tight jet of bright droplets from `from` to `to` over `time` seconds.
func jet(from: Vector3, to: Vector3, time: float) -> void:
	var v := (to - from) / time
	for i in 44:
		var k := float(i) / 44.0
		var o := Vector3(_fx_rng.randf() - 0.5, _fx_rng.randf() - 0.5, _fx_rng.randf() - 0.5) * 0.12
		_spawn_puff(from + o - v * k * 0.08, v * _fx_rng.randf_range(0.95, 1.05), time * _fx_rng.randf_range(0.95, 1.1), _fx_rng.randf_range(0.05, 0.1), Color(0.85, 0.98, 1.0, 0.9), 0.0)


## Water drawn in toward `pos` (the moment before a Tier-2 release).
func gather(pos: Vector3, radius: float) -> void:
	for i in 16:
		var d := Vector3(_fx_rng.randf() - 0.5, _fx_rng.randf() - 0.5, _fx_rng.randf() - 0.5).normalized()
		_spawn_puff(pos + d * radius, -d * radius / 0.22, 0.22, _fx_rng.randf_range(0.03, 0.06), Color(0.8, 0.95, 1.0, 0.7), 0.0)


## Bubble Blast: a shell of bubbles thrown outward over the upper hemisphere round `pos`.
func blast_shell(pos: Vector3, up: Vector3, radius: float) -> void:
	for i in 40:
		var d := Vector3(_fx_rng.randf() - 0.5, _fx_rng.randf() - 0.5, _fx_rng.randf() - 0.5).normalized()
		if d.dot(up) < -0.1:
			d -= up * d.dot(up) * 1.2
			d = d.normalized()
		_spawn_puff(pos, d * radius * _fx_rng.randf_range(2.0, 2.6), 0.5, _fx_rng.randf_range(0.06, 0.14), Color(0.85, 0.97, 1.0, 0.75), 3.0)


func stream(pos: Vector3, up: Vector3, strength: float) -> void:
	for i in int(2 + strength * 3):
		var o := Vector3(_fx_rng.randf() - 0.5, _fx_rng.randf() - 0.5, _fx_rng.randf() - 0.5) * 0.6
		_spawn_puff(pos + o, up * _fx_rng.randf_range(6.0, 10.0) * strength, 0.35, 0.035, Color(0.9, 1.0, 1.0, 0.6), 2.0)


func sparkle(pos: Vector3, col: Color, count := 14, speed := 1.5, size := 0.07, life := 1.0) -> void:
	for i in count:
		var d := Vector3(_fx_rng.randf() - 0.5, _fx_rng.randf() - 0.5, _fx_rng.randf() - 0.5).normalized()
		_spawn_puff(pos, d * speed * _fx_rng.randf_range(0.4, 1.0), life * _fx_rng.randf_range(0.6, 1.2), size * _fx_rng.randf_range(0.6, 1.3), col, 1.5)


## Particles travelling from `from` to `to` over `time` seconds (regeneration wisps).
func wisp(from: Vector3, to: Vector3, time: float, col: Color, count := 30) -> void:
	for i in count:
		var o := Vector3(_fx_rng.randf() - 0.5, _fx_rng.randf() - 0.5, _fx_rng.randf() - 0.5) * 0.8
		var v := (to - from) / time
		_spawn_puff(from + o, v * _fx_rng.randf_range(0.9, 1.05), time * _fx_rng.randf_range(0.9, 1.0), _fx_rng.randf_range(0.05, 0.11), col, 0.0)


func _process(dt: float) -> void:
	# Impulses decay and feed shaders.
	var arr := PackedVector4Array()
	arr.resize(MAX_IMPULSES)
	for i in MAX_IMPULSES:
		if _imp_life[i] > 0.0:
			_imp_life[i] = maxf(0.0, _imp_life[i] - dt)
		var s := _current_strength(i)
		arr[i] = Vector4(_imp_pos[i].x, _imp_pos[i].y, _imp_pos[i].z, s)
	var g := Game.inst
	var cam := get_viewport().get_camera_3d()
	if g and g.player and g.player.ball:
		var b: MossBall = g.player.ball
		b.set_field_param("impulses", arr)
		b.set_field_param("motes", mote_uniform)
		b.set_field_param("mote_count", mote_count)
		specks_mat.set_shader_parameter("flow", b.current_at(cam.global_position if cam else g.player.global_position) * 0.6)
	specks_mat.set_shader_parameter("impulses", arr)
	specks_mat.set_shader_parameter("motes", mote_uniform)
	specks_mat.set_shader_parameter("mote_count", mote_count)
	specks_mat.set_shader_parameter("murk", murk)
	if cam:
		specks_mat.set_shader_parameter("cam_pos", cam.global_position)

	# Puffs.
	for i in PUFF_POOL:
		var p: Array = _puffs[i]
		if p[2] <= 0.0:
			continue
		p[2] -= dt
		if p[2] <= 0.0:
			_puff_mm.set_instance_color(i, Color(0, 0, 0, 0))
			_puff_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.0001), Vector3(0, -9999, 0)))
			continue
		var v: Vector3 = p[1]
		v = v * maxf(0.0, 1.0 - p[6] * dt) + p[7] * dt
		p[1] = v
		p[0] += v * dt
		var k: float = p[2] / p[3]
		var c: Color = p[5]
		_puff_mm.set_instance_color(i, Color(c.r, c.g, c.b, c.a * minf(1.0, k * 2.0)))
		_puff_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * p[4] * (0.7 + 0.3 * k) * 2.0), p[0]))

	_update_marks(dt)

	# Debris specks.
	for i in DEBRIS_POOL:
		var d = _debris[i]
		if d == null:
			continue
		d[2] += dt
		var vel: Vector3 = d[1]
		vel = vel.lerp(Vector3(0, -0.15, 0) + (vel.normalized() * 0.6 if vel.length() > 0.01 else Vector3.ZERO), minf(1.0, dt * 0.05))
		d[1] = vel
		d[0] += vel * dt
		var a := clampf(1.0 - (d[2] - 40.0) / 80.0, 0.25, 1.0)
		_debris_mm.set_instance_color(i, Color(0.42, 0.42, 0.4, 0.8 * a))
		_debris_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.35), d[0]))


# --- Drag marks (ledger row 19) -----------------------------------------------------------------

## Scrape a drag mark at `pos` on ground facing `up`, running along `dir` for `length` m, `width` m
## across, at `strength` (0..1). Returns a handle for drag_mark_stretch.
func drag_mark(pos: Vector3, up: Vector3, dir: Vector3, length: float, width: float, strength: float) -> int:
	var i := _mark_next
	_mark_next = (_mark_next + 1) % MARK_POOL
	if _mark_age[i] < 0.0:
		marks_live += 1
	_mark_mi.visible = true
	_mark_age[i] = 0.0
	_mark_str[i] = clampf(strength, 0.0, 1.0)
	_mark_gen[i] += 1
	_mark_count += 1
	_mark_mm.set_instance_custom_data(i, Color(length, fmod(_mark_count * 0.618034, 1.0), width, _moss_lift(pos, up)))
	_mark_mm.set_instance_transform(i, _mark_xf(pos, up, dir, length, width))
	_mark_mm.set_instance_color(i, Color(1, 1, 1, 0.0))
	return i + _mark_gen[i] * MARK_POOL


## Draw a mark out from `a` (where the foot dug in) to `b` (where it is now), at least `min_len`
## long. False when the mark is gone (faded, or its slot reused).
func drag_mark_stretch(handle: int, a: Vector3, b: Vector3, min_len: float) -> bool:
	var i := handle % MARK_POOL
	if handle < 0 or _mark_age[i] < 0.0 or _mark_gen[i] != handle / MARK_POOL:
		return false
	var d := b - a
	var xf := _mark_mm.get_instance_transform(i)
	var up := xf.basis.y.normalized()
	d -= up * d.dot(up)
	var length := maxf(d.length(), min_len)
	var dir := d.normalized() if d.length() > 0.005 else xf.basis.z.normalized()
	var cd := _mark_mm.get_instance_custom_data(i)
	cd.r = length
	_mark_mm.set_instance_custom_data(i, cd)
	_mark_mm.set_instance_transform(i, _mark_xf(a, up, dir, length, cd.b))
	return true


## How visible mark slot `i` is now (0..1; 0 when free): in at once, then fading over its last MARK_FADE s.
func mark_alpha(i: int) -> float:
	var age := _mark_age[i]
	if age < 0.0:
		return 0.0
	return _mark_str[i] * minf(1.0, age / 0.08) * (1.0 - smoothstep(MARK_LIFE - MARK_FADE, MARK_LIFE, age))


## A puff or two of silt kicked up where a braced foot lifts, drifting with `drift`.
func scuff(pos: Vector3, up: Vector3, drift: Vector3, strength: float) -> void:
	var side := drift.cross(up)
	side = side.normalized() * 0.05 if side.length() > 0.001 else Vector3.ZERO
	for k in 2:
		_spawn_puff(pos + up * 0.04 + side * (k * 2 - 1), drift + up * 0.25, 0.7, 0.035 + 0.02 * strength, Color(0.55, 0.5, 0.38, 0.4 * strength), 1.8, up * 0.15)


## How far the moss material displaces its surface at `pos` (moss.gdshader's fuzz, scaled by the
## moss's health and how flat the ground is there, as it does), so a mark lies on the drawn moss.
func _moss_lift(pos: Vector3, up: Vector3) -> float:
	var g := Game.inst
	if g == null or g.player == null or g.player.ball == null:
		return 0.0
	var b: MossBall = g.player.ball
	if b.moss_material == null:
		return 0.0
	var fuzz: Variant = b.moss_material.get_shader_parameter("fuzz")
	var fz := 0.35 if fuzz == null else float(fuzz)
	var dir := (pos - b.global_position).normalized()
	var slope: Variant = b.moss_material.get_shader_parameter("moss_slope")
	var ms := 0.5 if slope == null else float(slope)
	var flat_ := smoothstep(ms - 0.25, ms + 0.15, up.dot(dir))
	return fz * lerpf(0.55, 1.0, b.health_at(dir)) * lerpf(0.35, 1.0, flat_)


func _mark_xf(pos: Vector3, up: Vector3, dir: Vector3, length: float, width: float) -> Transform3D:
	var z := (dir - up * dir.dot(up)).normalized()
	var x := up.cross(z).normalized()
	# (The plane's +Z runs along the skid: UV.y 0 where the foot dug in, 1 at its far end.)
	return Transform3D(Basis(x * width, up, z * length), pos + up * MARK_LIFT + z * length * 0.5)


func _hide_mark(i: int) -> void:
	_mark_mm.set_instance_color(i, Color(0, 0, 0, 0))
	_mark_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.0001), Vector3(0, -9999, 0)))


func _update_marks(dt: float) -> void:
	if marks_live <= 0:
		return
	for i in MARK_POOL:
		if _mark_age[i] < 0.0:
			continue
		_mark_age[i] += dt
		if _mark_age[i] >= MARK_LIFE:
			_mark_age[i] = -1.0
			marks_live -= 1
			_hide_mark(i)
			_mark_mi.visible = marks_live > 0
			continue
		_mark_mm.set_instance_color(i, Color(1, 1, 1, mark_alpha(i)))


## Hand a dead parasite body over to the cheap far-field representation.
func add_debris(pos: Vector3, vel: Vector3) -> void:
	_debris[_debris_next] = [pos, vel, 0.0]
	_debris_next = (_debris_next + 1) % DEBRIS_POOL
