class_name CreatureMeshes
extends RefCounted
## Procedural creature meshes (owner, 2026-10-07: the edible shrimp and the reed stalker read as
## placeholder balls). Small helpers that loft a body along a curve of elliptical rings and add thin
## double-sided blades (fins, legs, antennae, fans), all into one vertex-coloured mesh per creature
## part, so a creature stays a draw call or two. Front is -Z, up is +Y (as the creatures orient).


# --- The edible shrimp (Food DRIFTER) -----------------------------------------------------------

## A little shrimp, about 0.26 m nose to tail fan: a smooth carapace and five arched tail segments
## (each a slight swell, banded darker at the joints), a pointed rostrum, two dark eyes on stalks,
## long swept-back antennae and a fanned tail. The legs are separate (they paddle: Food).
static func shrimp_body() -> ArrayMesh:
	var st := _Counted.new()
	var body := Color(1.0, 0.6, 0.4)
	var band := Color(0.78, 0.38, 0.24)
	var belly := Color(1.0, 0.82, 0.66)
	var rings := []
	# Carapace (front) then the arched abdomen, rising a little and curling down at the tail.
	var prof := [[-0.1, 0.0, 0.012, 0.01], [-0.085, 0.004, 0.026, 0.024], [-0.06, 0.008, 0.034, 0.032], [-0.03, 0.01, 0.036, 0.034],
			[-0.005, 0.01, 0.034, 0.032]]
	for p in prof:
		rings.append([Vector3(0, p[1], p[0]), p[2], p[3], body, belly])
	for sgi in 5:
		var z0 := 0.0 + sgi * 0.024
		var y0 := 0.01 - sgi * sgi * 0.0018
		var r0 := 0.032 - sgi * 0.004
		rings.append([Vector3(0, y0, z0 + 0.004), r0 * 0.92, r0 * 0.9, band, belly])
		rings.append([Vector3(0, y0 + 0.002, z0 + 0.014), r0, r0 * 0.98, body, belly])
	rings.append([Vector3(0, -0.012, 0.128), 0.01, 0.008, body, belly])
	st.loft(rings, 9)
	# Rostrum, eyes, antennae, tail fan.
	st.blade(Vector3(0, 0.012, -0.095), Vector3(0, 0.004, -0.05), Vector3.RIGHT, 0.012, 0.001, body, band)
	for sd in [-1.0, 1.0]:
		st.blade(Vector3(sd * 0.018, 0.016, -0.08), Vector3(sd * 0.012, 0.004, -0.01), Vector3.UP, 0.008, 0.008, band, band)
		var eye := Critter.sphere(0.008, 6)
		st.add_mesh(eye, Color(0.06, 0.04, 0.05), Transform3D(Basis(), Vector3(sd * 0.031, 0.02, -0.09)))
		st.blade(Vector3(sd * 0.01, 0.01, -0.1), Vector3(sd * 0.05, 0.03, -0.06), Vector3.UP, 0.004, 0.0015, band, body, 4, Vector3(sd * 0.03, -0.02, 0.2))
		st.blade(Vector3(sd * 0.008, 0.006, -0.098), Vector3(sd * 0.03, 0.01, -0.03), Vector3.UP, 0.003, 0.001, band, body, 3, Vector3(sd * 0.04, -0.015, 0.16))
	for k in 5:
		var a := deg_to_rad(-50.0 + k * 25.0)
		var d := Vector3(sin(a) * 0.045, -0.006, cos(a) * 0.045)
		st.blade(Vector3(0, -0.01, 0.125), d, Vector3(cos(a), 0, -sin(a)), 0.012, 0.02, body, Color(1.0, 0.86, 0.72))
	return st.commit()


## One shrimp swimmeret pair's leg: a thin curved blade (Food paddles them).
static func shrimp_leg() -> ArrayMesh:
	var st := _Counted.new()
	var c := Color(1.0, 0.66, 0.46)
	for sd in [-1.0, 1.0]:
		st.blade(Vector3(sd * 0.012, -0.02, 0), Vector3(sd * 0.014, -0.03, 0.006), Vector3(0, 0, 1), 0.006, 0.002, c, Color(1.0, 0.85, 0.7), 2, Vector3(0, 0, 0.01))
	return st.commit()


# --- The reed stalker -----------------------------------------------------------------------------

## A body segment of the reed stalker, authored at the size of the old 0.2 m sphere (the stalker
## scales its segments along the body): a flattened, armoured segment with a dorsal crest of reed
## spines, a darker stripe down the back, a pale belly and a short leg either side.
static func stalker_segment() -> ArrayMesh:
	var st := _Counted.new()
	var back := Color(0.9, 0.95, 0.85)   # (multiplied by the segment's own reed colour)
	var belly := Color(1.25, 1.2, 0.95)
	var stripe := Color(0.55, 0.6, 0.45)
	var rings := []
	# (Nearly a cylinder, overlapping its neighbours: one continuous ridged body, not beads. A
	# slight swell mid-segment and a darker joint band at the back edge give the segmentation.)
	for p in [[-0.26, 0.16, 0.12, back], [-0.12, 0.2, 0.16, back], [0.04, 0.2, 0.16, back], [0.16, 0.18, 0.14, stripe], [0.26, 0.15, 0.11, stripe]]:
		rings.append([Vector3(0, 0, p[0]), p[1], p[2], p[3], belly])
	st.loft(rings, 10)
	# The crest: three leaning reed spines along the back, dark at the base, pale at the tip.
	for k in 3:
		var z := -0.14 + k * 0.12
		st.blade(Vector3(0, 0.13, z), Vector3(0, 0.2, 0.09), Vector3(0, 0, 1), 0.08, 0.006, stripe * Color(0.6, 0.6, 0.6), back)
	# A short jointed leg each side, bent down to the moss.
	for sd in [-1.0, 1.0]:
		st.blade(Vector3(sd * 0.17, -0.04, -0.02), Vector3(sd * 0.1, -0.1, -0.03), Vector3(0, 0, 1), 0.05, 0.02, stripe, back, 2, Vector3(0, -0.03, 0.02))
	return st.commit()


## The head: a long wedge snout with a jaw line, raised brows over amber eyes with slit pupils, and
## feeler whiskers swept back. Coloured (not multiplied).
static func stalker_head() -> ArrayMesh:
	var st := _Counted.new()
	var top := Color(0.36, 0.42, 0.17)
	var belly := Color(0.62, 0.58, 0.3)
	var rings := []
	for p in [[-0.3, 0.02, 0.015, -0.01], [-0.25, 0.06, 0.04, -0.005], [-0.15, 0.1, 0.07, 0.0], [-0.04, 0.14, 0.1, 0.01], [0.06, 0.15, 0.11, 0.01], [0.14, 0.12, 0.09, 0.0]]:
		rings.append([Vector3(0, p[3], p[0]), p[1], p[2], top, belly])
	st.loft(rings, 10)
	var amber := Color(1.0, 0.78, 0.18)
	for sd in [-1.0, 1.0]:
		st.add_mesh(Critter.sphere(0.042, 8), amber, Transform3D(Basis().scaled(Vector3(0.7, 1.0, 1.0)), Vector3(sd * 0.1, 0.07, -0.1)))
		st.add_mesh(Critter.sphere(0.02, 6), Color(0.04, 0.03, 0.02), Transform3D(Basis().scaled(Vector3(0.4, 1.2, 0.6)), Vector3(sd * 0.128, 0.075, -0.11)))
		# Brow ridge over the eye.
		st.blade(Vector3(sd * 0.06, 0.1, -0.15), Vector3(sd * 0.07, 0.01, 0.1), Vector3(0, 1, 0.2).normalized(), 0.04, 0.015, top, top.darkened(0.3))
		# Feelers.
		st.blade(Vector3(sd * 0.03, 0.03, -0.27), Vector3(sd * 0.18, 0.08, 0.05), Vector3.UP, 0.012, 0.003, belly, top, 4, Vector3(sd * 0.05, 0.02, 0.25))
	# The jaw line: a dark seam along each side of the snout.
	for sd in [-1.0, 1.0]:
		st.blade(Vector3(sd * 0.055, -0.03, -0.25), Vector3(sd * 0.05, 0.0, 0.22), Vector3.UP, 0.012, 0.01, Color(0.16, 0.15, 0.08), Color(0.16, 0.15, 0.08))
	return st.commit()


## The display frill behind the head: a fan of seven ribbed rays with webbing between them, orange
## with dark veins and pale tips (the stalker flares it as it rears: its telegraph).
static func stalker_frill() -> ArrayMesh:
	var st := _Counted.new()
	var web := Color(0.86, 0.44, 0.14)
	var tip := Color(1.0, 0.82, 0.45)
	var vein := Color(0.4, 0.16, 0.06)
	for k in 7:
		var a := deg_to_rad(-75.0 + k * 25.0)
		var d := Vector3(sin(a) * 0.3, cos(a) * 0.26, 0.04)
		st.blade(Vector3(0, 0, 0), d, Vector3(cos(a), -sin(a), 0), 0.11, 0.07, web, tip, 2)
		st.blade(Vector3(0, 0, -0.005), d * 1.05, Vector3(cos(a), -sin(a), 0), 0.012, 0.004, vein, vein, 2)
	return st.commit()


## SurfaceTool with a running vertex count (for indices) and a few builders.
class _Counted:
	var st := SurfaceTool.new()
	var n := 0

	func _init() -> void:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	func v(p: Vector3, nrm: Vector3, c: Color) -> int:
		st.set_color(c)
		st.set_normal(nrm)
		st.add_vertex(p)
		n += 1
		return n - 1

	func tri(a: int, b: int, c: int) -> void:
		st.add_index(a)
		st.add_index(b)
		st.add_index(c)

	func loft(rings: Array, sides: int) -> void:
		var start := n
		for r in rings:
			var c: Vector3 = r[0]
			for k in sides:
				var a := TAU * k / sides
				var dir := Vector3(cos(a), sin(a), 0.0)
				var under := clampf(-dir.y, 0.0, 1.0)
				v(c + Vector3(dir.x * float(r[1]), dir.y * float(r[2]), 0.0),
						Vector3(dir.x / maxf(float(r[1]), 0.001), dir.y / maxf(float(r[2]), 0.001), 0.0).normalized(),
						(r[3] as Color).lerp(r[4], under))
		for i in rings.size() - 1:
			for k in sides:
				var a0 := start + i * sides + k
				var a1 := start + i * sides + (k + 1) % sides
				tri(a0, a0 + sides, a1)
				tri(a1, a0 + sides, a1 + sides)
		for e in [0, rings.size() - 1]:
			var r: Array = rings[e]
			var ci := v(r[0], Vector3(0, 0, -1.0 if e == 0 else 1.0), r[3])
			for k in sides:
				var a0: int = start + e * sides + k
				var a1: int = start + e * sides + (k + 1) % sides
				if e == 0:
					tri(ci, a0, a1)
				else:
					tri(ci, a1, a0)

	func blade(base: Vector3, dir: Vector3, side: Vector3, width: float, tip_w: float, col: Color, tip_col: Color, segs := 2, curl := Vector3.ZERO) -> void:
		var nrm := dir.cross(side).normalized()
		var start := n
		for i in segs + 1:
			var t := float(i) / segs
			var w := lerpf(width, tip_w, t) * 0.5
			var p := base + dir * t + curl * t * t
			for s in [-1.0, 1.0]:
				v(p + side * w * s, nrm, col.lerp(tip_col, t))
		for i in segs:
			var a := start + i * 2
			# (Both windings: a blade is seen from either side.)
			tri(a, a + 2, a + 1)
			tri(a + 1, a + 2, a + 3)
			tri(a, a + 1, a + 2)
			tri(a + 1, a + 3, a + 2)

	func add_mesh(m: Mesh, c: Color, xf: Transform3D) -> void:
		var arr := m.surface_get_arrays(0)
		var vv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var start := n
		var nb := xf.basis.inverse().transposed()
		for i in vv.size():
			v(xf * vv[i], (nb * nn[i]).normalized(), c)
		if idx.size() > 0:
			for i in range(0, idx.size(), 3):
				tri(start + idx[i], start + idx[i + 1], start + idx[i + 2])
		else:
			for i in range(0, vv.size(), 3):
				tri(start + i, start + i + 1, start + i + 2)

	func commit() -> ArrayMesh:
		return st.commit()
