class_name RavineOoze
extends MeshInstance3D
## Owner, 2026-10-01: a pool of bubbling, tie-dyed orange-and-purple ooze on every ravine floor, so a fall into a
## valley (one frond, put back on the rim: Game.ravine_fall) reads as landing in something bad.
## Purely visual: no collision, the floor and the fall rule are unchanged. One opaque mesh per ball:
## a ribbon along each ravine just above its floor (wherever that floor is), wide enough to meet the walls,
## its edges cut where the ravine's carve fades (vertex alpha; see ravine_ooze.gdshader).

const LEVEL := 0.3      # m above the floor: he lands on it, then sinks in (Game._cine_ravine)
const STEP_M := 0.45    # sample spacing along a ravine (fine: the edge is a smooth curve)
const ACROSS := 18      # columns across

static var _mat: ShaderMaterial


static func build(b: MossBall) -> RavineOoze:
	var st_v := PackedVector3Array()
	var st_n := PackedVector3Array()
	var st_c := PackedColorArray()
	var st_uv := PackedVector2Array()
	var st_i := PackedInt32Array()
	var spots := PackedVector3Array()   # where bubbles may rise: the pool shows and is above the ground
	var tops := PackedFloat32Array()    # how high one may rise there (m above the pool; under the rim)
	var lift := 0.0
	for cv in b.carves:
		var pts: Array = cv[0]
		var hw: float = cv[1]
		var depth: float = cv[2]
		var wall: float = cv[3]
		var w := hw + wall * 0.75
		var lift_k := lift
		lift += 0.004   # (overlapping ravines never z-fight)
		# Samples along the polyline, carried on past each end over the carve's rounded end wall. There
		# the pool keeps the floor's level at that end (`level_at`), so the end wall cuts it on the same
		# smooth curve as the side walls (owner, 2026-10-02: it ended square, climbing the slope).
		var samples: Array[Vector3] = []
		var level_at: Array[Vector3] = []
		var first: Vector3 = (pts[0] as Vector3).normalized()
		var second: Vector3 = (pts[1] as Vector3).normalized()
		var ext := w + wall
		var n_ext := maxi(2, int(ceil(ext / STEP_M)))
		for e in range(n_ext, 0, -1):
			samples.append(first.slerp(second, -ext * e / n_ext / maxf(0.001, first.angle_to(second) * b.radius)).normalized())
			level_at.append(first)
		for k in pts.size() - 1:
			var a: Vector3 = (pts[k] as Vector3).normalized()
			var c: Vector3 = (pts[k + 1] as Vector3).normalized()
			var n := maxi(1, int(ceil(a.angle_to(c) * b.radius / STEP_M)))
			for j in n:
				samples.append(a.slerp(c, float(j) / n).normalized())
				level_at.append(samples[samples.size() - 1])
		var last: Vector3 = (pts[pts.size() - 1] as Vector3).normalized()
		var prev: Vector3 = (pts[pts.size() - 2] as Vector3).normalized()
		samples.append(last)
		level_at.append(last)
		for e in range(1, n_ext + 1):
			samples.append(prev.slerp(last, 1.0 + ext * e / n_ext / maxf(0.001, prev.angle_to(last) * b.radius)).normalized())
			level_at.append(last)
		var base := st_v.size()
		var along := 0.0
		for s in samples.size():
			var d := samples[s]
			var t := (samples[mini(s + 1, samples.size() - 1)] - samples[maxi(s - 1, 0)])
			t = (t - d * t.dot(d)).normalized()
			var side := d.cross(t).normalized()
			# The floor is the base sphere only where no hill rises under the ravine; elsewhere it
			# sits higher (hill height minus the carve), so the pool follows the floor along it.
			var floor_h := b.terrain_height(level_at[s])
			var r := b.radius + floor_h + LEVEL + lift_k
			# The rim here: the lower of the two banks just outside the walls.
			var reach := (hw + wall + 0.5) / b.radius
			var rim_h := minf(b.terrain_height(d.rotated(t, reach)), b.terrain_height(d.rotated(t, -reach)))
			var top := clampf(rim_h - (floor_h + LEVEL) - 0.15, 0.0, BUBBLE_TOP_M)
			if s > 0:
				along += samples[s - 1].angle_to(d) * b.radius
			for i in ACROSS + 1:
				var u := float(i) / ACROSS
				var dd := d.rotated(t, (u * 2.0 - 1.0) * w / b.radius).normalized()
				var cut := clampf(b.ravine_carve(dd) / maxf(depth, 0.01), 0.0, 1.0)
				# The pool stops just short of where the wall rises through it, on a smooth curve from
				# the terrain's own (analytic) height, so its edge never follows the wall's triangles
				# (owner, 2026-10-01: "it's fluid, it should be smooth").
				var th := b.terrain_height(dd)
				var a := (1.0 - smoothstep(floor_h + LEVEL - 0.2, floor_h + LEVEL - 0.06, th)) * smoothstep(0.3, 0.5, cut)
				if a > 0.6 and top >= 0.15:
					spots.append(dd * (r + 0.02))
					tops.append(top)
				st_v.append(dd * r)
				st_n.append(dd)
				st_c.append(Color(1, 1, 1, a))
				st_uv.append(Vector2(along, u))
		for s in samples.size() - 1:
			for i in ACROSS:
				var p0 := base + s * (ACROSS + 1) + i
				var p1 := p0 + ACROSS + 1
				st_i.append_array([p0, p0 + 1, p1, p0 + 1, p1 + 1, p1])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = st_v
	arr[Mesh.ARRAY_NORMAL] = st_n
	arr[Mesh.ARRAY_COLOR] = st_c
	arr[Mesh.ARRAY_TEX_UV] = st_uv
	arr[Mesh.ARRAY_INDEX] = st_i
	var am := ArrayMesh.new()
	if not st_i.is_empty():
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = load("res://shaders/ravine_ooze.gdshader")
	var mi := RavineOoze.new()
	mi.name = "RavineOoze"
	mi.mesh = am
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = b.radius + MossBall.FAR_LOD_M
	mi.ball = b
	mi.spots = spots
	mi.tops = tops
	mi._make_pool()
	return mi


# --- Bubbles (owner, 2026-10-01) ------------------------------------------------------------------
# Yellow and purple bubbles swell out of the ooze near Gill, wobble up a little, swell and pop into a
# soft ring about half a metre up (never above the valley's rim). Their own fixed pool (one
# MultiMesh per ball, BUBBLE_POOL slots, reused; nothing allocated per frame): they never take
# particles from Gill, hits or any other effect, and a full pool simply skips a spawn.

const BUBBLE_POOL := 64
const BUBBLE_EVERY_S := 0.03     # the approved amount of bubbling (dev-000074)
const BUBBLE_NEAR_M := 16.0
const BUBBLE_TOP_M := 0.5        # pop height above the pool (less where the rim is lower)
const BUBBLE_POP_S := 0.28
const BUBBLE_COLS: Array[Color] = [Color(1.0, 0.9, 0.3, 1.0), Color(0.78, 0.45, 1.0, 1.0)]   # yellow, purple

var ball: MossBall
var spots := PackedVector3Array()
var tops := PackedFloat32Array()
var spawned := 0
var _rng := RandomNumberGenerator.new()
var _next := 0.0
var _mm: MultiMesh
var _mmi: MultiMeshInstance3D
# Slot state, fixed size (life < 0: free).
var _life := PackedFloat32Array()     # seconds into this bubble (rise, then pop)
var _rise := PackedFloat32Array()     # rise time
var _top := PackedFloat32Array()      # rise height (m)
var _size := PackedFloat32Array()
var _ph := PackedFloat32Array()       # wobble phase
var _base := PackedVector3Array()     # start (ball-local, on the pool)
var _up := PackedVector3Array()
var _side := PackedVector3Array()
var _col := PackedInt32Array()
const _HIDE := Vector3(0, -9999, 0)


func _make_pool() -> void:
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.use_custom_data = true
	_mm.mesh = q
	_mm.instance_count = BUBBLE_POOL
	_mm.custom_aabb = AABB(Vector3.ONE * -1000.0, Vector3.ONE * 2000.0)
	for arr in [_life, _rise, _top, _size, _ph]:
		arr.resize(BUBBLE_POOL)
	for arr in [_base, _up, _side]:
		arr.resize(BUBBLE_POOL)
	_col.resize(BUBBLE_POOL)
	for k in BUBBLE_POOL:
		_life[k] = -1.0
		_hide(k)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/ooze_bubble.gdshader")
	_mmi = MultiMeshInstance3D.new()
	_mmi.name = "OozeBubbles"
	_mmi.multimesh = _mm
	_mmi.material_override = m
	_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mmi)


func _hide(k: int) -> void:
	_mm.set_instance_transform(k, Transform3D(Basis().scaled(Vector3.ONE * 0.0001), _HIDE))
	_mm.set_instance_color(k, Color(0, 0, 0, 0))


## Bubbles alive now (for tests and diagnostics).
func alive() -> int:
	var n := 0
	for k in BUBBLE_POOL:
		if _life[k] >= 0.0:
			n += 1
	return n


## Where slot k is now (ball-local), its pool point and how high it may go; empty if free.
func bubble_state(k: int) -> Array:
	if _life[k] < 0.0:
		return []
	return [_pos(k), _base[k], _top[k]]


func _pos(k: int) -> Vector3:
	var x := clampf(_life[k] / _rise[k], 0.0, 1.0)
	var h := _top[k] * (1.0 - (1.0 - x) * (1.0 - x))       # rises, slowing near the top
	var wob := sin(_ph[k] + _life[k] * 5.5) * 0.045 * smoothstep(0.0, 0.3, x)
	return _base[k] + _up[k] * h + _side[k] * wob


func _process(dt: float) -> void:
	if _mm == null or spots.is_empty() or Game.inst == null or Game.inst.player == null:
		return
	var pl = Game.inst.player
	var here_ball: bool = pl.ball == ball
	var any := false
	for k in BUBBLE_POOL:
		if _life[k] < 0.0:
			continue
		_life[k] += dt
		var t := _life[k]
		if t >= _rise[k] + BUBBLE_POP_S or not here_ball:
			_life[k] = -1.0
			_hide(k)
			continue
		any = true
		var c: Color = BUBBLE_COLS[_col[k]]
		var p := to_global(_pos(k))
		if t < _rise[k]:
			var x := t / _rise[k]
			# Swells out of the ooze, then a little extra just before it pops.
			var sz := _size[k] * smoothstep(0.0, 0.3, x) * (1.0 + 0.3 * smoothstep(0.75, 1.0, x))
			c.a = smoothstep(0.0, 0.2, x)
			_mm.set_instance_transform(k, Transform3D(Basis().scaled(Vector3.ONE * maxf(sz, 0.0001)), p))
			_mm.set_instance_color(k, c)
			_mm.set_instance_custom_data(k, Color(0, 0, 0, 0))
		else:
			var y := (t - _rise[k]) / BUBBLE_POP_S
			c.a = (1.0 - y) * (1.0 - y) * 0.9
			_mm.set_instance_transform(k, Transform3D(Basis().scaled(Vector3.ONE * _size[k] * (1.3 + 1.6 * y)), p))
			_mm.set_instance_color(k, c)
			_mm.set_instance_custom_data(k, Color(1, y, 0, 0))
	_mmi.visible = any or here_ball
	if not here_ball:
		return
	_next -= dt
	if _next > 0.0:
		return
	_next = BUBBLE_EVERY_S * _rng.randf_range(0.5, 1.5)
	_spawn(pl)


func _spawn(pl) -> void:
	var slot := -1
	for k in BUBBLE_POOL:
		if _life[k] < 0.0:
			slot = k
			break
	if slot < 0:
		return   # (full: skip, never take one back early)
	var cam: Camera3D = Game.inst.cam
	var here := to_local(pl.global_position)
	for tries in 12:
		var i := _rng.randi() % spots.size()
		var sp: Vector3 = spots[i]
		if sp.distance_to(here) > BUBBLE_NEAR_M:
			continue
		if cam != null and not cam.is_position_in_frustum(to_global(sp)):
			continue
		var up := sp.normalized()
		_base[slot] = sp
		_up[slot] = up
		_side[slot] = up.cross(Vector3.UP if absf(up.y) < 0.9 else Vector3.RIGHT).normalized().rotated(up, _rng.randf() * TAU)
		_top[slot] = tops[i] * _rng.randf_range(0.75, 1.0)
		_rise[slot] = _rng.randf_range(0.7, 1.2)
		_size[slot] = _rng.randf_range(0.07, 0.13)   # (as drawn in dev-000074)
		_ph[slot] = _rng.randf() * TAU
		_col[slot] = _rng.randi() % BUBBLE_COLS.size()
		_life[slot] = 0.0
		spawned += 1
		return
