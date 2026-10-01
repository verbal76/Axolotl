class_name RavineOoze
extends MeshInstance3D
## Owner, 2026-10-01: a pool of glowing, bubbling green ooze on every ravine floor, so a fall into a
## valley (one frond, put back on the rim: Game.ravine_fall) reads as landing in something bad.
## Purely visual: no collision, the floor and the fall rule are unchanged. One opaque mesh per ball:
## a ribbon along each ravine just above its floor (the base sphere), wide enough to meet the walls,
## its edges cut where the ravine's carve fades (vertex alpha; see ravine_ooze.gdshader).

const LEVEL := 0.3      # m above the floor: he lands on it, then sinks in (Game._cine_ravine)
const STEP_M := 0.8     # sample spacing along a ravine
const ACROSS := 6       # columns across

static var _mat: ShaderMaterial


static func build(b: MossBall) -> RavineOoze:
	var st_v := PackedVector3Array()
	var st_n := PackedVector3Array()
	var st_c := PackedColorArray()
	var st_uv := PackedVector2Array()
	var st_i := PackedInt32Array()
	var lift := 0.0
	for cv in b.carves:
		var pts: Array = cv[0]
		var hw: float = cv[1]
		var depth: float = cv[2]
		var wall: float = cv[3]
		var w := hw + wall * 0.75
		var r := b.radius + LEVEL + lift
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
			if s > 0:
				along += samples[s - 1].angle_to(d) * b.radius
			for i in ACROSS + 1:
				var u := float(i) / ACROSS
				var dd := d.rotated(t, (u * 2.0 - 1.0) * w / b.radius).normalized()
				var cut := clampf(b.ravine_carve(dd) / maxf(depth, 0.01), 0.0, 1.0)
				# (Only where the floor really is low enough for the ooze to show.)
				var a := smoothstep(0.55, 0.85, cut) if b.terrain_height(dd) < LEVEL + 0.6 else 0.0
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
	return mi
