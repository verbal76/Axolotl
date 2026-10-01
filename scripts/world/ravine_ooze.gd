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
	var lift := 0.0
	for cv in b.carves:
		var pts: Array = cv[0]
		var hw: float = cv[1]
		var depth: float = cv[2]
		var wall: float = cv[3]
		var w := hw + wall * 0.75
		var lift_k := lift
		lift += 0.004   # (overlapping ravines never z-fight)
		# Samples along the polyline, carried a little past each end (the carve rounds off there).
		var samples: Array[Vector3] = []
		var first: Vector3 = (pts[0] as Vector3).normalized()
		var second: Vector3 = (pts[1] as Vector3).normalized()
		samples.append(first.slerp(second, -w / maxf(0.001, first.angle_to(second) * b.radius)).normalized())
		for k in pts.size() - 1:
			var a: Vector3 = (pts[k] as Vector3).normalized()
			var c: Vector3 = (pts[k + 1] as Vector3).normalized()
			var n := maxi(1, int(ceil(a.angle_to(c) * b.radius / STEP_M)))
			for j in n:
				samples.append(a.slerp(c, float(j) / n).normalized())
		var last: Vector3 = (pts[pts.size() - 1] as Vector3).normalized()
		var prev: Vector3 = (pts[pts.size() - 2] as Vector3).normalized()
		samples.append(last)
		samples.append(prev.slerp(last, 1.0 + w / maxf(0.001, prev.angle_to(last) * b.radius)).normalized())
		var base := st_v.size()
		var along := 0.0
		for s in samples.size():
			var d := samples[s]
			var t := (samples[mini(s + 1, samples.size() - 1)] - samples[maxi(s - 1, 0)])
			t = (t - d * t.dot(d)).normalized()
			var side := d.cross(t).normalized()
			# The floor is the base sphere only where no hill rises under the ravine; elsewhere it
			# sits higher (hill height minus the carve), so the pool follows the floor along it.
			var floor_h := b.terrain_height(d)
			var r := b.radius + floor_h + LEVEL + lift_k
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
				if a > 0.6:
					spots.append(dd * (r + 0.02))
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
	return mi


# --- Bubbles (owner, 2026-10-01): little green bubbles rise out of the ooze now and then and pop a
# little above it. Only near Gill (the pool he can see), through WaterFX's pooled puffs.

const BUBBLE_EVERY_S := 0.03   # lots of them
const BUBBLE_NEAR_M := 16.0
const BUBBLE_RISE_S := 1.1
const BUBBLE_COLS: Array[Color] = [Color(1.0, 0.9, 0.3, 1.0), Color(0.78, 0.45, 1.0, 1.0)]   # yellow, purple
## They pop low, well inside the valley (never up past its rim).
const BUBBLE_TOP_M := 0.55

var ball: MossBall
var spots := PackedVector3Array()
var _rng := RandomNumberGenerator.new()
var _next := 0.0
var _pops: Array = []   # [time left, world position, colour]
var spawned := 0


func _process(dt: float) -> void:
	if ball == null or spots.is_empty() or WaterFX.inst == null or Game.inst == null or Game.inst.player == null:
		return
	for k in range(_pops.size() - 1, -1, -1):
		_pops[k][0] -= dt
		if _pops[k][0] <= 0.0:
			WaterFX.inst.sparkle(_pops[k][1], _pops[k][2], 5, 0.6, 0.05, 0.3)
			_pops.remove_at(k)
	var pl = Game.inst.player
	if pl.ball != ball:
		return
	_next -= dt
	if _next > 0.0:
		return
	_next = BUBBLE_EVERY_S * _rng.randf_range(0.6, 1.4)
	# A pool point near him where the camera looks.
	if spots.is_empty():
		return
	var cam: Camera3D = Game.inst.cam
	var here := to_local(pl.global_position)
	for tries in 16:
		var p: Vector3 = spots[_rng.randi() % spots.size()]
		if p.distance_to(here) > BUBBLE_NEAR_M:
			continue
		var from := to_global(p)
		if cam != null and not cam.is_position_in_frustum(from):
			continue
		var up := global_basis * p.normalized()
		var life := _rng.randf_range(0.6, BUBBLE_RISE_S)
		var speed := _rng.randf_range(0.6, 1.0) * BUBBLE_TOP_M / life
		var col: Color = BUBBLE_COLS[_rng.randi() % BUBBLE_COLS.size()]
		WaterFX.inst._spawn_puff(from, up * speed, life, _rng.randf_range(0.08, 0.15), col, 0.0)
		spawned += 1
		_pops.append([life * 0.95, from + up * speed * life * 0.95, col])
		break
