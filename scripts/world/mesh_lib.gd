class_name MeshLib
## Procedural geometry used throughout the aquarium. Everything is generated at load time so
## the project ships with no third-party art. Vegetation meshes follow the convention
## UV.y = 0 at the base and 1 at the tip (used by vegetation.gdshader for bending).


## A tapered, slightly curved grass blade standing on +Y.
static func blade(st: SurfaceTool, xf: Transform3D, width: float, height: float, segs: int, curve: float, tint: Color) -> void:
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	for i in range(segs + 1):
		var t := float(i) / segs
		var w := width * (1.0 - t * 0.85)
		var z := curve * t * t * height
		var y := t * height
		var l := xf * Vector3(-w * 0.5, y, z)
		var r := xf * Vector3(w * 0.5, y, z)
		if i > 0:
			var n := (xf.basis * Vector3(0, -curve, 1)).normalized()
			for v in [[prev_l, t - 1.0 / segs], [prev_r, t - 1.0 / segs], [r, t], [prev_l, t - 1.0 / segs], [r, t], [l, t]]:
				st.set_normal(n)
				st.set_color(tint)
				st.set_uv(Vector2(0.5, v[1]))
				st.add_vertex(v[0])
		prev_l = l
		prev_r = r


static func tuft_mesh(blades: int, width: float, height: float, spread: float, seed_v: int, segs := 3, curve := 0.35) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in blades:
		var a := rng.randf() * TAU
		var p := Vector3(cos(a), 0, sin(a)) * rng.randf() * spread
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.25, 0.25))
		var tint := Color.WHITE.darkened(rng.randf() * 0.25)
		blade(st, Transform3D(b, p), width * rng.randf_range(0.7, 1.2), height * rng.randf_range(0.6, 1.2), segs, curve * rng.randf_range(0.5, 1.3), tint)
	return st.commit()


## Broad-leaf aquatic plant: a few wide, rounded leaves on short stalks.
static func broadleaf_mesh(leaves: int, size: float, seed_v: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in leaves:
		var a := TAU * i / leaves + rng.randf() * 0.5
		var b := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, -rng.randf_range(0.5, 1.1))
		_leaf_blade(st, Transform3D(b, Vector3.ZERO), size * rng.randf_range(0.35, 0.5), size * rng.randf_range(0.8, 1.2), Color.WHITE.darkened(rng.randf() * 0.2))
	return st.commit()


## Leaf outline along +Y (in the leaf's local plane XY), cupped slightly toward +Z.
static func _leaf_blade(st: SurfaceTool, xf: Transform3D, half_w: float, length: float, tint: Color) -> void:
	var segs := 6
	var pts_l: Array[Vector3] = []
	var pts_r: Array[Vector3] = []
	var mid: Array[Vector3] = []
	for i in range(segs + 1):
		var t := float(i) / segs
		var w := half_w * sin(PI * clampf(t * 0.95 + 0.05, 0.0, 1.0)) * (1.0 - t * 0.3)
		var y := t * length
		var cup := w * 0.25
		pts_l.append(xf * Vector3(-w, y, cup))
		pts_r.append(xf * Vector3(w, y, cup))
		mid.append(xf * Vector3(0, y, -0.02 * length))
	var n := (xf.basis * Vector3(0, 0, 1)).normalized()
	for i in range(segs):
		var t0 := float(i) / segs
		var t1 := float(i + 1) / segs
		for tri in [[mid[i], t0, pts_l[i], t0, pts_l[i + 1], t1], [mid[i], t0, pts_l[i + 1], t1, mid[i + 1], t1],
				[mid[i], t0, pts_r[i + 1], t1, pts_r[i], t0], [mid[i], t0, mid[i + 1], t1, pts_r[i + 1], t1]]:
			for k in 3:
				st.set_normal(n)
				st.set_color(tint)
				st.set_uv(Vector2(0.5, tri[k * 2 + 1]))
				st.add_vertex(tri[k * 2])


## A single large flat leaf used as a platform, lying in the XZ plane, pointing along -Z from
## the origin (the stem attachment). Mesh thickness is visual only.
static func platform_leaf_mesh(length: float, width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 10
	var rows: Array = []
	for i in range(segs + 1):
		var t := float(i) / segs
		var w := width * 0.5 * pow(sin(PI * clampf(t * 0.92 + 0.08, 0.0, 1.0)), 0.8)
		var droop := -0.35 * pow(t, 2.0)
		var z := -t * length
		rows.append([Vector3(-w, droop - w * 0.08, z), Vector3(0, droop + 0.06, z), Vector3(w, droop - w * 0.08, z), t])
	for i in range(segs):
		var a: Array = rows[i]
		var b: Array = rows[i + 1]
		for side in [0, 1]:
			var o := a[side * 2] as Vector3
			var m := a[1] as Vector3
			var o2 := b[side * 2] as Vector3
			var m2 := b[1] as Vector3
			var quad := [m, o, o2, m, o2, m2] if side == 0 else [m, o2, o, m, m2, o2]
			for v in quad:
				st.set_uv(Vector2(0.5 + (v as Vector3).x / width, float(i) / segs))
				st.add_vertex(v)
	st.generate_normals()
	return st.commit()


## Rounded moss cushion (squashed cylinder with soft top edge). Base extends below y=0 so it
## sits flush on a curved surface.
static func cushion_mesh(radius: float, height: float, sink: float = 1.2, radial := 24) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var profile: Array[Vector2] = [Vector2(radius * 1.05, -sink), Vector2(radius * 1.02, 0.0)]
	var r_edge := minf(radius * 0.35, height * 0.6)
	for i in range(1, 6):
		var a := PI * 0.5 * i / 5.0
		profile.append(Vector2(radius - r_edge + cos(a) * r_edge, height - r_edge + sin(a) * r_edge))
	profile.append(Vector2(0.0, height + 0.05))
	for s in radial:
		var a0 := TAU * s / radial
		var a1 := TAU * (s + 1) / radial
		for j in range(profile.size() - 1):
			var p0: Vector2 = profile[j]
			var p1: Vector2 = profile[j + 1]
			var v00 := Vector3(cos(a0) * p0.x, p0.y, sin(a0) * p0.x)
			var v01 := Vector3(cos(a1) * p0.x, p0.y, sin(a1) * p0.x)
			var v10 := Vector3(cos(a0) * p1.x, p1.y, sin(a0) * p1.x)
			var v11 := Vector3(cos(a1) * p1.x, p1.y, sin(a1) * p1.x)
			# Godot front faces wind clockwise seen from outside.
			for v in [v00, v11, v10, v00, v01, v11]:
				st.set_uv(Vector2(float(s) / radial, (v as Vector3).y / height))
				st.add_vertex(v)
	st.generate_normals()
	return st.commit()


## Collision hull points for a cushion (convex).
static func cushion_hull(radius: float, height: float, sink: float = 1.2) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var r_edge := minf(radius * 0.35, height * 0.6)
	for s in 16:
		var a := TAU * s / 16.0
		var d := Vector3(cos(a), 0, sin(a))
		pts.append(d * radius * 1.05 + Vector3(0, -sink, 0))
		pts.append(d * radius * 1.02)
		pts.append(d * (radius - r_edge * 0.3) + Vector3(0, height - r_edge * 0.3, 0))
		pts.append(d * (radius - r_edge) + Vector3(0, height, 0))
	return pts


## Vertical stem / trunk (tapered cylinder) along +Y.
static func stem_mesh(r0: float, r1: float, height: float, radial := 10, bend := 0.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 8
	for j in range(rings):
		var t0 := float(j) / rings
		var t1 := float(j + 1) / rings
		for s in radial:
			var a0 := TAU * s / radial
			var a1 := TAU * (s + 1) / radial
			var ra := lerpf(r0, r1, t0)
			var rb := lerpf(r1, r1, t1) if false else lerpf(r0, r1, t1)
			var oa := Vector3(bend * t0 * t0 * height, 0, 0)
			var ob := Vector3(bend * t1 * t1 * height, 0, 0)
			var v00 := oa + Vector3(cos(a0) * ra, t0 * height, sin(a0) * ra)
			var v01 := oa + Vector3(cos(a1) * ra, t0 * height, sin(a1) * ra)
			var v10 := ob + Vector3(cos(a0) * rb, t1 * height, sin(a0) * rb)
			var v11 := ob + Vector3(cos(a1) * rb, t1 * height, sin(a1) * rb)
			for v in [[v00, t0], [v11, t1], [v10, t1], [v00, t0], [v01, t0], [v11, t1]]:
				st.set_uv(Vector2(0.5, v[1]))
				st.add_vertex(v[0])
	st.generate_normals()
	return st.commit()


## Hollow dome shell with an entrance gap: the interior moss caves. Returns [mesh, faces].
## The dome sits on y=0 (the moss surface), opening toward +Z.
static func dome_shell(radius: float, thickness: float, height_scale: float, door_w: float, door_h: float) -> Array:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	var rings := 14
	var radial := 36
	var sink := 1.2
	for layer in [0, 1]:
		var r := radius if layer == 0 else radius - thickness
		for j in range(rings):
			for s in radial:
				var th0 := PI * 0.5 * j / rings
				var th1 := PI * 0.5 * (j + 1) / rings
				var a0 := TAU * s / radial
				var a1 := TAU * (s + 1) / radial
				var quad := [_dome_pt(r, th0, a0, height_scale, sink), _dome_pt(r, th1, a0, height_scale, sink),
						_dome_pt(r, th1, a1, height_scale, sink), _dome_pt(r, th0, a1, height_scale, sink)]
				var centre: Vector3 = (quad[0] + quad[2]) * 0.5
				# Entrance gap facing +Z.
				if centre.z > 0 and absf(centre.x) < door_w * 0.5 and centre.y < door_h:
					continue
				# Outer layer faces out, inner layer faces into the cave.
				var tris := [quad[0], quad[2], quad[1], quad[0], quad[3], quad[2]]
				if layer == 1:
					tris = [quad[0], quad[1], quad[2], quad[0], quad[2], quad[3]]
				for v in tris:
					st.set_uv(Vector2(float(s) / radial, (v as Vector3).y / (radius * height_scale)))
					st.add_vertex(v)
					faces.append(v)
	st.generate_normals()
	return [st.commit(), faces]


static func _dome_pt(r: float, th: float, a: float, hs: float, sink: float) -> Vector3:
	# th = 0 at the rim (ground), PI/2 at the top.
	var y := sin(th) * r * hs
	var rr := cos(th) * r
	if th <= 0.0001:
		y = -sink
	return Vector3(cos(a) * rr, y, sin(a) * rr)


## Tube along a curve for the vortex. UV.y runs 0..1 along the length, UV.x around.
static func tube_mesh(points: PackedVector3Array, ups: PackedVector3Array, radius: float, radial := 18) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := points.size()
	var rings: Array = []
	for i in n:
		var fwd := (points[mini(i + 1, n - 1)] - points[maxi(i - 1, 0)]).normalized()
		var up := (ups[i] - fwd * ups[i].dot(fwd)).normalized()
		var side := fwd.cross(up)
		var ring := []
		for s in radial + 1:
			var a := TAU * s / radial
			ring.append(points[i] + (up * cos(a) + side * sin(a)) * radius)
		rings.append(ring)
	for i in range(n - 1):
		for s in radial:
			var t0 := float(i) / (n - 1)
			var t1 := float(i + 1) / (n - 1)
			var u0 := float(s) / radial
			var u1 := float(s + 1) / radial
			for v in [[rings[i][s], u0, t0], [rings[i + 1][s], u0, t1], [rings[i + 1][s + 1], u1, t1],
					[rings[i][s], u0, t0], [rings[i + 1][s + 1], u1, t1], [rings[i][s + 1], u1, t0]]:
				st.set_uv(Vector2(v[1], v[2]))
				st.add_vertex(v[0])
	st.generate_normals()
	return st.commit()


## Funnel/whirlpool mouth: a cone opening upward (+Y), UV.y = 0 at the throat.
static func funnel_mesh(r_top: float, r_throat: float, depth: float, radial := 28) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 8
	for j in range(rings):
		for s in radial:
			var t0 := float(j) / rings
			var t1 := float(j + 1) / rings
			var ra := lerpf(r_throat, r_top, t0 * t0)
			var rb := lerpf(r_throat, r_top, t1 * t1)
			var a0 := TAU * s / radial
			var a1 := TAU * (s + 1) / radial
			var ya := -depth * (1.0 - t0)
			var yb := -depth * (1.0 - t1)
			for v in [[Vector3(cos(a0) * ra, ya, sin(a0) * ra), s, t0], [Vector3(cos(a0) * rb, yb, sin(a0) * rb), s, t1],
					[Vector3(cos(a1) * rb, yb, sin(a1) * rb), s + 1, t1], [Vector3(cos(a0) * ra, ya, sin(a0) * ra), s, t0],
					[Vector3(cos(a1) * rb, yb, sin(a1) * rb), s + 1, t1], [Vector3(cos(a1) * ra, ya, sin(a1) * ra), s + 1, t0]]:
				st.set_uv(Vector2(float(v[1]) / radial, v[2]))
				st.add_vertex(v[0])
	st.generate_normals()
	return st.commit()


static func mat(color: Color, rough := 0.85, emission := Color.BLACK, energy := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	return m


## Merge several primitive meshes (each with a local transform) into one ArrayMesh so a
## multi-part static shape costs one draw call.
static func merge(parts: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in parts:
		var m: Mesh = p[0]
		var xf: Transform3D = p[1]
		for s in m.get_surface_count():
			st.append_from(m, s, xf)
	return st.commit()


static func sphere(r: float, radial := 10, rings := 5) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = radial
	s.rings = rings
	return s


static func capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0)
	c.radial_segments = 8
	c.rings = 2
	return c
