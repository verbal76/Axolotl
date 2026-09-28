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


## A creased blade (a shallow V with a midrib, so it is not a flat card), curved and tapered, with a
## little twist; for the medium and tall vegetation families.
static func reed(st: SurfaceTool, xf: Transform3D, width: float, height: float, segs: int, curve: float, twist: float, tint: Color) -> void:
	var prev: Array = []
	for i in range(segs + 1):
		var t := float(i) / segs
		var w := width * (1.0 - t * 0.8) * (0.85 + 0.3 * sin(t * PI))
		var z := curve * t * t * height
		var y := t * height
		var rot := Basis(Vector3.UP, twist * t)
		var crease := w * 0.35
		var row := [xf * (rot * Vector3(-w * 0.5, y, z)), xf * (rot * Vector3(0.0, y, z - crease)), xf * (rot * Vector3(w * 0.5, y, z))]
		if i > 0:
			var tp := t - 1.0 / segs
			for half in 2:
				var a0: Vector3 = prev[half]
				var a1: Vector3 = prev[half + 1]
				var b0: Vector3 = row[half]
				var b1: Vector3 = row[half + 1]
				var n := (b0 - a0).cross(a1 - a0).normalized()
				for v in [[a0, tp], [a1, tp], [b1, t], [a0, tp], [b1, t], [b0, t]]:
					st.set_normal(n)
					st.set_color(tint)
					st.set_uv(Vector2(0.5, v[1]))
					st.add_vertex(v[0])
		prev = row


## A clump of reeds (medium/tall vegetation): `blades` creased blades from a small base spread,
## leaning out a little, heights and curves varied.
static func reed_clump(blades: int, width: float, height: float, spread: float, seed_v: int, segs := 5, curve := 0.25) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in blades:
		var a := rng.randf() * TAU
		var p := Vector3(cos(a), 0, sin(a)) * sqrt(rng.randf()) * spread
		var bs := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.2, 0.3))
		var tint := Color.WHITE.darkened(rng.randf() * 0.3)
		reed(st, Transform3D(bs, p), width * rng.randf_range(0.7, 1.25), height * rng.randf_range(0.6, 1.15), segs,
				curve * rng.randf_range(0.4, 1.4), rng.randf_range(-0.8, 0.8), tint)
	return st.commit()


## Broad-leaf aquatic plant: a rosette of wide, rounded leaves (Expansion 6, owner: they read as
## sharp and blocky). Each leaf is an ovate blade that rises from the centre, arches over and droops
## under its own weight, its edges cupped a little, with smooth shading. UV.y runs base to tip, so
## the vegetation material sways the outer leaf most in the current.
static func broadleaf_mesh(leaves: int, size: float, seed_v: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base := 0
	for i in leaves:
		var a := TAU * i / leaves + rng.randf() * 0.5
		var rise := rng.randf_range(0.55, 1.05)
		var length := size * rng.randf_range(0.8, 1.2)
		var half_w := size * rng.randf_range(0.3, 0.42)
		base = _broad_leaf(st, Basis(Vector3.UP, a), rise, half_w, length, Color.WHITE.darkened(rng.randf() * 0.2), base)
	st.generate_normals()
	return st.commit()


## A cluster of stem plants (Expansion 6, owner reference "a sprouted moss ball": Rotala-like red
## stems crowning the healed moss). `stems` thin upright stems of up to `height`, leaning a little
## outward, each with pairs of narrow leaves turning a quarter turn up the stem, longer below and
## shorter toward the tip. UV.y runs base to tip (the material's colour runs green to red by it).
static func stem_plant_mesh(stems: int, height: float, seed_v: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base := 0
	for i in stems:
		var a := TAU * i / stems + rng.randf() * 0.8
		var lean := rng.randf_range(0.04, 0.3)
		var dirv := Vector3(sin(a) * sin(lean), cos(lean), cos(a) * sin(lean))
		var bow := Vector3(cos(a), 0, -sin(a)) * rng.randf_range(-0.08, 0.08)
		var root := Vector3(sin(a), 0, cos(a)) * height * rng.randf_range(0.0, 0.12)
		var len := height * rng.randf_range(0.6, 1.0)
		var tint := Color.WHITE.darkened(rng.randf() * 0.15)
		var at := func(t: float) -> Vector3: return root + dirv * len * t + bow * len * t * t
		# The stem: a thin three-sided tube.
		var r0 := height * 0.012
		var rings := 5
		var start := base
		var x := dirv.cross(Vector3.RIGHT if absf(dirv.x) < 0.9 else Vector3.FORWARD).normalized()
		var y := dirv.cross(x).normalized()
		for j in rings:
			var t := float(j) / (rings - 1)
			var c: Vector3 = at.call(t)
			for k in 3:
				var ang := TAU * k / 3.0
				st.set_color(tint)
				st.set_uv(Vector2(float(k) / 3.0, t))
				st.add_vertex(c + (x * cos(ang) + y * sin(ang)) * r0 * (1.0 - 0.6 * t))
				base += 1
		for j in rings - 1:
			for k in 3:
				var i0 := start + j * 3 + k
				var i1 := start + j * 3 + (k + 1) % 3
				for q in [i0, i1, i0 + 3, i1, i1 + 3, i0 + 3]:
					st.add_index(q)
		# Leaf pairs: narrow lance-shaped leaves, arching out and a little down.
		var pairs := 10
		for j in pairs:
			var t := 0.12 + 0.86 * float(j) / (pairs - 1)
			var c: Vector3 = at.call(t)
			var ll := height * lerpf(0.2, 0.11, t)
			var lw := ll * 0.3
			for side in [-1.0, 1.0]:
				var la := a + j * PI * 0.5 + (0.0 if side > 0.0 else PI) + rng.randf_range(-0.2, 0.2)
				var out := Vector3(sin(la), 0, cos(la))
				var tip: Vector3 = c + out * ll * 0.85 + dirv * ll * lerpf(0.45, 0.1, t) - Vector3.UP * ll * 0.1
				var mid: Vector3 = c + out * ll * 0.45 + dirv * ll * 0.35
				var wv := out.cross(dirv).normalized() * lw
				for v in [c, mid + wv, tip, mid - wv]:
					st.set_color(tint.lightened(0.05))
					st.set_uv(Vector2(0.5, t))
					st.add_vertex(v)
				for q in [base, base + 1, base + 2, base, base + 2, base + 3]:
					st.add_index(q)
				base += 4
	st.generate_normals()
	return st.commit()


## Fine roots and strands trailing from the underside of a healed moss ball (Expansion 6, the
## "sprouted moss ball" reference): `n` thin wavering ribbons of up to `length`, crossed in pairs so
## they read from any side. UV.y runs from the moss to the free end.
static func root_strands_mesh(n: int, length: float, seed_v: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base := 0
	for i in n:
		var a := rng.randf() * TAU
		var root := Vector3(sin(a), 0, cos(a)) * length * rng.randf_range(0.0, 0.15)
		var len := length * rng.randf_range(0.5, 1.0)
		var ph := rng.randf() * TAU
		var drift := Vector3(sin(a), 0, cos(a)) * rng.randf_range(0.05, 0.25)
		var w := length * 0.03
		var segs := 8
		var tint := Color.WHITE.darkened(rng.randf() * 0.25)
		for cross_k in 2:
			var wd := Vector3(cos(a + cross_k * PI * 0.5), 0, -sin(a + cross_k * PI * 0.5)) * w
			var start := base
			for j in segs + 1:
				var t := float(j) / segs
				var c := root + Vector3.UP * len * t + drift * len * t * t + Vector3(sin(t * 7.0 + ph), 0, cos(t * 5.0 + ph)) * len * 0.04 * t
				for sgn in [-1.0, 1.0]:
					st.set_color(tint)
					st.set_uv(Vector2(0.5 + sgn * 0.5, t))
					st.add_vertex(c + wd * sgn * (1.0 - 0.7 * t))
					base += 1
			for j in segs:
				var i0 := start + j * 2
				for q in [i0, i0 + 1, i0 + 2, i0 + 1, i0 + 3, i0 + 2]:
					st.add_index(q)
	st.generate_normals()
	return st.commit()


## Tube coral / anemone cluster (Expansion 6, the healed tank's colour): `tubes` soft tapering
## tubes rising from one spot, leaning outward, each ending in a flared rounded mouth. UV.y runs base
## to tip (the vegetation material colours and sways by it).
static func coral_mesh(tubes: int, height: float, seed_v: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base := 0
	var sides := 7
	for i in tubes:
		var a := TAU * i / tubes + rng.randf() * 0.6
		var lean := rng.randf_range(0.1, 0.45)
		var dirv := Vector3(sin(a) * sin(lean), cos(lean), cos(a) * sin(lean))
		var root := Vector3(sin(a), 0, cos(a)) * height * rng.randf_range(0.02, 0.1)
		var len := height * rng.randf_range(0.55, 1.0)
		var r0 := height * rng.randf_range(0.07, 0.1)
		var tint := Color.WHITE.darkened(rng.randf() * 0.18)
		var start := base
		# Rings: the tube, then a flared lip and a rounded rim turning back in.
		var profile := [[0.0, 1.0], [0.3, 0.8], [0.65, 0.72], [0.88, 0.85], [0.96, 1.35], [1.0, 1.2], [0.98, 0.7]]
		var x := dirv.cross(Vector3.UP if absf(dirv.y) < 0.95 else Vector3.RIGHT).normalized()
		var y := dirv.cross(x).normalized()
		for pr in profile:
			var t: float = pr[0]
			var c: Vector3 = root + dirv * len * t
			for k in sides:
				var ang := TAU * k / sides
				st.set_color(tint)
				st.set_uv(Vector2(float(k) / sides, t))
				st.add_vertex(c + (x * cos(ang) + y * sin(ang)) * r0 * float(pr[1]))
				base += 1
		for j in profile.size() - 1:
			for k in sides:
				var i0 := start + j * sides + k
				var i1 := start + j * sides + (k + 1) % sides
				for q in [i0, i1, i0 + sides, i1, i1 + sides, i0 + sides]:
					st.add_index(q)
	st.generate_normals()
	return st.commit()


## One rosette leaf pointing out along the basis' +Z: `rise` radians up from level at the base,
## curving down toward the tip. Indexed from `base`; returns the new vertex count.
static func _broad_leaf(st: SurfaceTool, rot: Basis, rise: float, half_w: float, length: float, tint: Color, base: int) -> int:
	var rows := 9
	var cols := [-1.0, -0.5, 0.0, 0.5, 1.0]
	var p := Vector3.ZERO
	var start := base
	for i in rows + 1:
		var t := float(i) / rows
		# The midrib: out and up at first, arching over and down toward the tip.
		var ang := rise - t * (rise + 0.55)
		var dirv := Vector3(0, sin(ang), cos(ang))
		if i > 0:
			p += dirv * (length / rows)
		var w := half_w * pow(sin(PI * clampf(t * 0.92 + 0.06, 0.0, 1.0)), 0.75) * (1.0 - 0.2 * t)
		var side := Vector3(1, 0, 0)
		var lift := Vector3(0, cos(ang), -sin(ang))
		for s in cols:
			var v: Vector3 = p + side * s * w + lift * (s * s) * w * 0.28
			st.set_color(tint)
			st.set_uv(Vector2(0.5 + s * 0.5, t))
			st.add_vertex(rot * v)
			base += 1
	for i in rows:
		for k in cols.size() - 1:
			var a := start + i * cols.size() + k
			var b := a + 1
			var c := a + cols.size()
			var d := c + 1
			for q in [a, c, b, b, c, d]:
				st.add_index(q)
	return base


## Platform leaf outline (Expansion 6, owner phone report): narrow where it joins its stalk, broad
## through the middle so there is room to land, settle, turn and aim, then a natural taper to a
## rounded point. t = 0 at the base, 1 at the tip; returns the half-width as a fraction of half the
## leaf's width. The drawn leaf and its collision both follow this.
static func leaf_profile(t: float) -> float:
	var tc := clampf(t, 0.0, 1.0)
	var neck := 0.22 + 0.78 * smoothstep(0.0, 0.2, tc)
	return neck * pow(sin(PI * tc), 0.42) * (1.0 - 0.12 * tc)


## Height of a platform leaf's upper surface above its base plane at (t along, s across in -1..1):
## a gentle crown along the midrib, edges curling a little down, the tip drooping slightly. Nearly
## level where the axolotl stands (the middle).
static func leaf_top_y(t: float, s: float, width: float) -> float:
	return 0.06 - 0.15 * pow(clampf(t, 0.0, 1.0), 2.4) - 0.08 * s * s * minf(width / 2.2, 1.4)


## Visual thickness of a platform leaf at s across (thickest at the midrib, a thin edge).
static func leaf_thickness(s: float) -> float:
	return 0.02 + 0.07 * (1.0 - s * s)


## A large leaf used as a platform, lying in the XZ plane, pointing along -Z from the origin (where
## it joins its stalk). It is a lens (upper and under surfaces meeting in a thin edge), not a flat
## card. With `petiole`, a curved stalk runs from the leaf's base back into the stem it grows from
## (+Z, rising slightly as it enters the stem), so the leaf is seen to grow out of it: nothing but
## the drawn leaf collides (MeshLib.leaf_collision_shapes); the stalk never snags.
static func platform_leaf_mesh(length: float, width: float, petiole := false) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_leaf_into(st, Transform3D.IDENTITY, length, width, petiole, 0)
	st.generate_normals()
	return st.commit()


## Appends a platform leaf (as platform_leaf_mesh) transformed by `xf` to `st` (indexed), whose
## vertices so far number `base`; returns the new count. Call generate_normals() once at the end.
static func _leaf_into(st: SurfaceTool, xf: Transform3D, length: float, width: float, petiole: bool, p_base: int) -> int:
	var rows := 10
	var cols := [-1.0, -0.55, 0.0, 0.55, 1.0]
	var base := p_base
	var top := []
	for i in rows + 1:
		var t := float(i) / rows
		var hw := width * 0.5 * leaf_profile(t)
		var row := []
		for s in cols:
			var v := Vector3(s * hw, leaf_top_y(t, s, width), -t * length)
			st.set_uv(Vector2(0.5 + s * hw / width, t))
			st.add_vertex(xf * v)
			row.append(base)
			base += 1
		top.append(row)
	# The under surface shares the edge vertices (the edge is thin, its shading rounded).
	var bot := []
	for i in rows + 1:
		var t := float(i) / rows
		var hw := width * 0.5 * leaf_profile(t)
		var row := []
		for j in cols.size():
			var s: float = cols[j]
			if j == 0 or j == cols.size() - 1:
				row.append(top[i][j])
				continue
			var v := Vector3(s * hw, leaf_top_y(t, s, width) - leaf_thickness(s), -t * length)
			st.set_uv(Vector2(0.5 + s * hw / width, t))
			st.add_vertex(xf * v)
			row.append(base)
			base += 1
		bot.append(row)
	for i in rows:
		for j in cols.size() - 1:
			var a: int = top[i][j]
			var b: int = top[i][j + 1]
			var c: int = top[i + 1][j]
			var d: int = top[i + 1][j + 1]
			for k in [a, c, b, b, c, d]:
				st.add_index(k)
			a = bot[i][j]
			b = bot[i][j + 1]
			c = bot[i + 1][j]
			d = bot[i + 1][j + 1]
			for k in [a, b, c, b, d, c]:
				st.add_index(k)
	if petiole:
		# The stalk: from inside the stem (0.55 m back, a little higher) arcing down and out into
		# the leaf's narrow base, thickest where it leaves the stem.
		var r_scale := clampf(width / 2.2, 0.8, 1.5)
		var p0 := Vector3(0, 0.3, 0.55)
		var p1 := Vector3(0, 0.28, 0.12)
		var p2 := Vector3(0, 0.1, -0.08)
		var p3 := Vector3(0, 0.02, -0.34)
		var rings := 6
		var sides := 6
		var ring_start := base
		for i in rings:
			var t := float(i) / (rings - 1)
			var u := 1.0 - t
			var c := p0 * u * u * u + p1 * 3.0 * u * u * t + p2 * 3.0 * u * t * t + p3 * t * t * t
			var tan := (p1 - p0) * 3.0 * u * u + (p2 - p1) * 6.0 * u * t + (p3 - p2) * 3.0 * t * t
			tan = tan.normalized()
			var side := Vector3.RIGHT
			var nrm := tan.cross(side).normalized()
			var r := lerpf(0.085, 0.045, t) * r_scale
			for k in sides:
				var a := TAU * k / sides
				var v := c + (side * cos(a) + nrm * sin(a)) * r
				st.set_uv(Vector2(float(k) / sides, 0.0))
				st.add_vertex(xf * v)
		for i in rings - 1:
			for k in sides:
				var a := ring_start + i * sides + k
				var b := ring_start + i * sides + (k + 1) % sides
				var c := a + sides
				var d := b + sides
				for q in [a, b, c, b, d, c]:
					st.add_index(q)
		base += rings * sides
	return base


## Collision for a platform leaf (as platform_leaf_mesh, same length and width): its upper surface
## exactly as drawn (sampled), and an under side just below the drawn one. Two convex pieces, so
## the narrow base does not grow invisible corners beside the stalk. Cached per size.
static var _leaf_shapes := {}


static func leaf_collision_shapes(length: float, width: float) -> Array:
	var key := "%.3f_%.3f" % [length, width]
	if _leaf_shapes.has(key):
		return _leaf_shapes[key]
	var out := []
	for piece in [[0.0, 0.22], [0.18, 1.0]]:
		var pts := PackedVector3Array()
		var n := 6 if piece[0] == 0.0 else 12
		for i in n + 1:
			var t: float = lerpf(piece[0], piece[1], float(i) / n)
			var hw := width * 0.5 * leaf_profile(t) * 0.97
			for s in [-1.0, -0.5, 0.0, 0.5, 1.0]:
				var y := leaf_top_y(t, s, width)
				pts.append(Vector3(s * hw, y, -t * length))
				pts.append(Vector3(s * hw, y - leaf_thickness(s) - 0.03, -t * length))
		var shape := ConvexPolygonShape3D.new()
		shape.points = pts
		out.append(shape)
	_leaf_shapes[key] = out
	return out


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


## Moss mound: the natural platform/ledge. Flat walkable top (never smaller than a cushion's
## top: radius minus the rounded rim) exactly at `height`; a rounded rim, then sides that lean
## outward going down and sweep into the ground in a concave curve (no 90-degree wall into the
## moss); an irregular outline from seeded noise. Only the lowest ~0.2 m of the sweep is
## walkable, so it is not a step that makes a jump easier. Returns [ArrayMesh, faces]; the
## collision is exactly the drawn triangles.
## `ground` (optional): Callable(x, z) -> local height of the real terrain under that point, so the
## base follows hills and the ball's curvature instead of a flat plane (the sweep then meets the
## ground everywhere; the top stays level).
## `follow_top`: the whole mound follows the terrain (its top parallel to the ground, the same
## height above it everywhere): terraces on small balls, where a flat top would stand far higher
## above the ground at its rim than at its middle.
static func mound(radius: float, height: float, sink: float, seed_v: int, radial := 28, ground := Callable(), follow_top := false) -> Array:
	var noise := FastNoiseLite.new()
	noise.seed = seed_v
	noise.frequency = 0.9
	var r_edge := minf(radius * 0.35, height * 0.6)
	# Side: leans out at WALL_DEG as it goes down, then a concave fillet (a circular arc of radius
	# rf) turns it into the ground. Slopes under 52 degrees are walkable: on this arc that is only
	# its lowest rf * (1 - cos 52) (about 0.2 m), so the flare is no step up.
	var wall_deg := deg_to_rad(75.0)
	var rf := clampf(height * 0.22, 0.25, 0.55)
	var arc_h := rf * (1.0 - cos(wall_deg))
	var wall_top := height - r_edge
	var wall_bot := arc_h
	var r_wall_bot := radius + (wall_top - wall_bot) / tan(wall_deg)
	var r_base := r_wall_bot + rf * sin(wall_deg)
	# Profile: [r, y, noise weight] from the buried base to the top centre.
	# The irregular outline scales each angle's whole side evenly (weight 1), so the designed
	# slopes hold at every angle; it fades out across the rim to the top.
	var prof: Array = [[r_base, -sink, 1.0]]
	var na := 6
	for i in na + 1:
		# Arc centre sits rf above the ground at r_base; from the ground (angle 0) up to the wall.
		var a := wall_deg * float(i) / na
		prof.append([r_base - rf * sin(a), rf * (1.0 - cos(a)), 1.0])
	var nw := 4
	for i in range(1, nw + 1):
		var v := float(i) / nw
		prof.append([lerpf(r_wall_bot, radius, v), lerpf(wall_bot, wall_top, v), 1.0])
	for i in range(1, 6):
		var a := PI * 0.5 * i / 5.0
		prof.append([radius - r_edge + cos(a) * r_edge, height - r_edge + sin(a) * r_edge, 1.0 - float(i) / 5.0])
	prof.append([0.0, height + 0.05, 0.0])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	var ring := func(j: int, s: int) -> Vector3:
		var pr: Array = prof[j]
		var a := TAU * s / radial
		var d := Vector3(cos(a), 0.0, sin(a))
		# Irregular outline: only ever outward, so the walkable top is never smaller.
		var n := absf(noise.get_noise_2d(cos(a) * 1.3, sin(a) * 1.3)) * 0.16
		var r: float = pr[0] * (1.0 + n * float(pr[2]))
		var y: float = pr[1]
		if ground.is_valid() and follow_top:
			y += float(ground.call(d.x * r, d.z * r))
		elif ground.is_valid() and y < wall_top:
			# Bend the base onto the terrain: fully at the ground, fading out up the wall.
			var gy: float = ground.call(d.x * r, d.z * r)
			y += gy * (1.0 - clampf(y / wall_top, 0.0, 1.0))
		return Vector3(d.x * r, y, d.z * r)
	for s in radial:
		for j in prof.size() - 1:
			var v00: Vector3 = ring.call(j, s)
			var v01: Vector3 = ring.call(j, s + 1)
			var v10: Vector3 = ring.call(j + 1, s)
			var v11: Vector3 = ring.call(j + 1, s + 1)
			# Godot front faces wind clockwise seen from outside.
			for v in [v00, v11, v10, v00, v01, v11]:
				st.set_uv(Vector2(float(s) / radial, (v as Vector3).y / height))
				st.add_vertex(v)
				faces.append(v)
	st.generate_normals()
	return [st.commit(), faces]


## Sweeps a cross-section along a path (ridges, arches, bridges). `place(i, x, y)` gives the
## position of profile point (x across, y up) at station i (it follows the terrain or the path);
## `inside(i)` a point inside the solid at station i, so every triangle is wound to face out.
## `profile` runs across the section; `closed` joins its last point back to its first (a tube).
## Returns [ArrayMesh, faces]: the collision is exactly the drawn triangles.
static func sweep(stations: int, profile: PackedVector2Array, closed: bool, place: Callable, inside: Callable) -> Array:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	var rows := []
	for i in stations:
		var row := []
		for pr in profile:
			row.append(place.call(i, pr.x, pr.y))
		rows.append(row)
	var np := profile.size()
	var segs := np if closed else np - 1
	for i in stations - 1:
		var ref: Vector3 = (inside.call(i) + inside.call(i + 1)) * 0.5
		for j in segs:
			var j1 := (j + 1) % np
			var quad := [rows[i][j], rows[i][j1], rows[i + 1][j1], rows[i + 1][j]]
			for tri in [[quad[0], quad[1], quad[2]], [quad[0], quad[2], quad[3]]]:
				var a: Vector3 = tri[0]
				var bb: Vector3 = tri[1]
				var c: Vector3 = tri[2]
				var n := (c - a).cross(bb - a)
				if n.length_squared() < 1e-12:
					continue
				# Front faces (Godot winds them clockwise) point away from the inside.
				if n.dot((a + bb + c) / 3.0 - ref) < 0.0:
					var tmp := bb
					bb = c
					c = tmp
				for v in [a, bb, c]:
					st.set_uv(Vector2(0.0, v.y))
					st.add_vertex(v)
					faces.append(v)
	st.generate_normals()
	return [st.commit(), faces]


## Cross-section of a ridge (x across, y up, at full height 1.0): a flat crest `crest` wide, a
## rounded rim, sides leaning out, a concave sweep into the ground, and buried skirts.
static func ridge_profile(half_width: float, crest: float, sink: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var side := func(sgn: float) -> Array:
		var out := []
		out.append(Vector2(sgn * half_width, -sink))
		# A concave sweep from the ground up into a steep side (gentle at the foot, near vertical
		# under the rim), then the rounded rim onto the flat crest.
		for k in 7:
			var a := float(k) / 6.0
			out.append(Vector2(sgn * (crest * 0.5 + 0.12 + (half_width - crest * 0.5 - 0.12) * pow(1.0 - a, 2.2)), a * 0.85))
		out.append(Vector2(sgn * (crest * 0.5 + 0.06), 0.96))
		out.append(Vector2(sgn * crest * 0.5, 1.0))
		return out
	var left: Array = side.call(-1.0)
	for v in left:
		pts.append(v)
	var right: Array = side.call(1.0)
	right.reverse()
	for v in right:
		pts.append(v)
	return pts


## Cross-section of an arch/bridge slab: a closed rounded rectangle `width` x `thick`, flat on top.
static func slab_profile(width: float, thick: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var r := minf(thick * 0.45, width * 0.3)
	var corners := [[Vector2(width * 0.5 - r, thick * 0.5 - r), 0.0], [Vector2(-width * 0.5 + r, thick * 0.5 - r), 90.0],
			[Vector2(-width * 0.5 + r, -thick * 0.5 + r), 180.0], [Vector2(width * 0.5 - r, -thick * 0.5 + r), 270.0]]
	for c in corners:
		for k in 4:
			var a := deg_to_rad(float(c[1]) + 90.0 * k / 3.0)
			pts.append((c[0] as Vector2) + Vector2(cos(a), sin(a)) * r)
	return pts


## Overhanging rock shelf ("mushroom" rock): a stem rising from a concave sweep into the ground,
## flaring out under a wide flat top (the overhang). Walkable top exactly at `height`.
static func shelf(r_top: float, r_stem: float, height: float, sink: float, seed_v: int, ground := Callable()) -> Array:
	var noise := FastNoiseLite.new()
	noise.seed = seed_v
	noise.frequency = 0.9
	var lip := minf(0.9, height * 0.3)
	var under := height - lip
	var prof: Array = [[r_stem + 0.5, -sink], [r_stem + 0.5, 0.0], [r_stem + 0.2, 0.2], [r_stem + 0.06, 0.5], [r_stem, 0.9],
			[r_stem, under * 0.55], [r_stem * 1.05, under * 0.75]]
	for k in range(1, 6):
		var a := float(k) / 5.0
		prof.append([lerpf(r_stem * 1.05, r_top, 1.0 - pow(1.0 - a, 2.0)), lerpf(under * 0.75, under, sin(a * PI * 0.5))])
	prof.append([r_top + 0.1, under + lip * 0.45])
	prof.append([r_top, under + lip * 0.85])
	prof.append([r_top - 0.25, height])
	prof.append([0.0, height + 0.04])
	var radial := 26
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	var pt := func(j: int, s: int) -> Vector3:
		var a := TAU * s / radial
		var d := Vector3(cos(a), 0.0, sin(a))
		var r: float = prof[j][0] * (1.0 + absf(noise.get_noise_2d(cos(a) * 1.3, sin(a) * 1.3)) * 0.14)
		var y: float = prof[j][1]
		if ground.is_valid() and y < 1.0:
			y += float(ground.call(d.x * r, d.z * r)) * (1.0 - clampf(y, 0.0, 1.0))
		return Vector3(d.x * r, y, d.z * r)
	for s in radial:
		for j in prof.size() - 1:
			var v00: Vector3 = pt.call(j, s)
			var v01: Vector3 = pt.call(j, s + 1)
			var v10: Vector3 = pt.call(j + 1, s)
			var v11: Vector3 = pt.call(j + 1, s + 1)
			var centre := Vector3(0.0, (v00.y + v10.y) * 0.5, 0.0)
			for tri in [[v00, v11, v10], [v00, v01, v11]]:
				var a: Vector3 = tri[0]
				var bb: Vector3 = tri[1]
				var c: Vector3 = tri[2]
				var n := (c - a).cross(bb - a)
				if n.length_squared() < 1e-12:
					continue
				# Outward from the rock's axis (the underside of the overhang faces down-out).
				var out := (a + bb + c) / 3.0 - centre
				if n.dot(out) < 0.0:
					var tmp := bb
					bb = c
					c = tmp
				for v in [a, bb, c]:
					st.set_uv(Vector2(0.0, v.y))
					st.add_vertex(v)
					faces.append(v)
	st.generate_normals()
	return [st.commit(), faces]


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


## Vertical stem / trunk along +Y (Expansion 6: grown, not a cylinder): tapering, with a root
## flare where it meets the ground (0.5 m up the mesh; the flare is mostly below it), soft growth
## nodes every ~1.7 m, and a slight irregular wobble. UV.x runs round it and UV.y along it in
## metres, so the plant material's grain runs up the stem (it banded across it before).
## Collision (LevelBuilder.stem_xf) stays within a few centimetres of it.
static func stem_mesh(r0: float, r1: float, height: float, radial := 10, bend := 0.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := maxi(8, int(height / 0.6))
	var sides := maxi(radial, 12)
	var seed_v := r0 * 37.1 + height * 3.3
	var ring_pts: Array = []
	for j in rings + 1:
		var t := float(j) / rings
		var y := t * height
		var row: Array = []
		for k in sides + 1:
			var a := TAU * k / sides
			var r := lerpf(r0, r1, t)
			r *= 1.0 + 0.3 * (1.0 - smoothstep(0.1, 0.75, y))
			var node := fposmod(y + seed_v, 1.7) / 1.7
			r *= 1.0 + 0.06 * pow(1.0 - absf(node * 2.0 - 1.0), 10.0)
			r *= 1.0 + 0.03 * sin(a * 3.0 + y * 0.8 + seed_v) + 0.02 * sin(a * 5.0 - y * 1.3)
			var o := Vector3(bend * t * t * height, 0, 0)
			row.append([o + Vector3(cos(a) * r, y, sin(a) * r), Vector2(float(k) / sides * 3.0, y * 0.08)])
		ring_pts.append(row)
	for j in rings:
		for k in sides:
			var v00: Array = ring_pts[j][k]
			var v01: Array = ring_pts[j][k + 1]
			var v10: Array = ring_pts[j + 1][k]
			var v11: Array = ring_pts[j + 1][k + 1]
			for v in [v00, v11, v10, v00, v01, v11]:
				st.set_uv(v[1])
				st.add_vertex(v[0])
	st.generate_normals()
	return st.commit()


## Hollow dome shell with an entrance gap: the interior moss caves. Returns [mesh, faces].
## The dome sits on y=0 (the moss surface), opening toward +Z.
## `sink` is how far the rim skirt reaches below the site's ground point: it must cover the moss
## ball curving away under a flat dome (radius^2 / 2R) plus any slope, or the rim floats.
## Natural moss cave: an irregular mound with a thick wall, a vaulted interior and an arched mouth
## facing +Z. Returns [ArrayMesh, collision faces, part starts]; the collision is exactly the drawn
## triangles.
##
## Construction (docs/TERRAIN.md): the outer and inner surfaces are grids of rows (heights) by
## columns (angles). In every row below the arch top, the columns run from one side of the mouth
## round the back to the other side, so both surfaces end exactly on the arch outline (no
## rectangular cut, no stair-steps); above the arch the rows close into full rings. Jamb strips
## join the outer and inner outlines, closing the wall. The inside rises in vertical walls before
## the vault, so no ceiling slopes down to the floor where the axolotl's head could meet it.
##
## p: radius (outer base), height (outer top), thickness (wall at the base), door_w, door_h (mouth
## width at the ground and height), wall_h (interior vertical wall), sink (how far the base goes
## under the local ground), ball_radius (to follow the moss ball's curvature), seed.
static func cave_mound(p: Dictionary) -> Array:
	var ro: float = p.get("radius", 8.0)
	var ho: float = p.get("height", 7.2)
	var th: float = p.get("thickness", 1.3)
	var dw: float = p.get("door_w", 2.6)
	var dh: float = p.get("door_h", 2.4)
	var wall_h: float = p.get("wall_h", 1.9)
	var sink: float = p.get("sink", 2.5)
	var rb: float = p.get("ball_radius", 24.0)
	var noise := FastNoiseLite.new()
	noise.seed = int(p.get("seed", 1))
	noise.frequency = 0.16
	noise.fractal_octaves = 3
	var ri := ro - th
	var hc := ho - th * 0.7
	var ground := func(r: float) -> float: return sqrt(maxf(rb * rb - r * r, 0.0)) - rb
	# Mouth half-width (m) at height y above the local ground: a rounded arch, slightly flared at
	# the base, with an irregular outline.
	var half_w := func(y: float) -> float:
		var k := clampf(y / dh, 0.0, 1.0)
		var w := dw * 0.5 * pow(1.0 - pow(k, 2.2), 0.5) * (1.0 + 0.08 * (1.0 - k))
		return maxf(w * (1.0 + 0.14 * noise.get_noise_1d(y * 9.0 + 40.0)), 0.0) if k < 1.0 else 0.0
	var outer_r := func(y: float) -> float:
		var yy := clampf(y, 0.0, ho)
		return ro * pow(maxf(1.0 - pow(yy / ho, 2.2), 0.0), 1.0 / 2.2)
	var inner_r := func(y: float) -> float:
		if y <= wall_h:
			return ri
		var k := clampf((y - wall_h) / (hc - wall_h), 0.0, 1.0)
		return ri * sqrt(maxf(1.0 - k * k, 0.0))
	var bottom := -sink
	var arch_top := dh * 1.05 + 0.15
	# Rows: three through the buried base, then fine rows (about 0.25 m) up through the mouth so
	# its rounded top is smooth, then the vault.
	var rows_base := 3
	var rows_low := 26
	var rows_high := 12
	var mouth_floor: float = ground.call(ro) - 0.1
	var cols := 56
	var a_door := PI * 0.5
	var surfaces := []
	var outline := []   # the mouth on the outer face: [height above the ground, half-width]
	for layer in [0, 1]:
		var grid := []
		var top := ho if layer == 0 else hc
		for j in rows_low + rows_high + 1:
			var y: float
			if j <= rows_base:
				y = lerpf(bottom, mouth_floor, float(j) / rows_base)
			elif j <= rows_low:
				# Closer rows toward the crown, so the arch closes in a round curve, not a point.
				var k := float(j - rows_base) / (rows_low - rows_base)
				y = lerpf(mouth_floor, arch_top, 1.0 - pow(1.0 - k, 1.7))
			else:
				var k := float(j - rows_low) / rows_high
				y = lerpf(arch_top, top, sin(k * PI * 0.5))
			var r: float = outer_r.call(y) if layer == 0 else inner_r.call(y)
			# The mouth is measured from the ground where the wall stands.
			var g_here: float = ground.call(r)
			var hw: float = half_w.call(y - g_here) if y - g_here < dh * 1.05 else 0.0
			if layer == 0 and y - g_here >= 0.0 and j > 0:
				outline.append([y - g_here, hw])
			var ring := []
			for i in cols + 1:
				var span := TAU - 2.0 * (hw / maxf(r, 0.5))
				var a := a_door + hw / maxf(r, 0.5) + span * float(i) / cols
				var dir := Vector3(cos(a), 0.0, sin(a))
				var rr := r
				var yy := y
				var n := noise.get_noise_3d(dir.x * ro, y, dir.z * ro)
				if layer == 0:
					# Lumpy outside; a brow over the mouth.
					rr *= 1.0 + 0.07 * n
					var da := wrapf(a - a_door, -PI, PI) * r
					var brow := exp(-pow(da / 2.2, 2.0)) * exp(-pow((y - g_here - dh - 0.5) / 0.8, 2.0))
					rr += 0.7 * brow
					# The base sweeps out into the ground in a concave flare (no wall straight into
					# the moss); walkable only in its lowest few centimetres.
					rr += 0.65 * pow(1.0 - clampf((y - g_here) / 1.6, 0.0, 1.0), 2.5)
					# Height lumps fade out toward the top so the crown never folds over itself.
					yy += 0.25 * n * sin(clampf(y / ho, 0.0, 1.0) * PI)
				else:
					# Inside only ever widens, so clearance is never below the design.
					rr += 0.25 * absf(n)
					if y > wall_h:
						var kv := clampf((y - wall_h) / (hc - wall_h), 0.0, 1.0)
						yy += 0.25 * absf(noise.get_noise_3d(dir.x * 7.0, y * 2.0, dir.z * 7.0)) * sin(kv * PI)
				if j == 0:
					yy = bottom
				ring.append(Vector3(dir.x * rr, yy, dir.z * rr))
			# Above the mouth the ring closes: its last vertex is exactly its first, so the
			# normals join smoothly (no seam up the dome).
			if hw <= 0.0:
				ring[cols] = ring[0]
			grid.append(ring)
		surfaces.append(grid)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	var tri := func(a: Vector3, b: Vector3, c: Vector3) -> void:
		for v in [a, b, c]:
			st.set_uv(Vector2(0.0, v.y))
			st.add_vertex(v)
			faces.append(v)
	var counts := []
	for layer in [0, 1]:
		var grid: Array = surfaces[layer]
		counts.append(faces.size() / 3)
		for j in grid.size() - 1:
			for i in cols:
				var v00: Vector3 = grid[j][i]
				var v01: Vector3 = grid[j][i + 1]
				var v10: Vector3 = grid[j + 1][i]
				var v11: Vector3 = grid[j + 1][i + 1]
				# Outer faces out, inner faces into the cave (Godot front faces wind clockwise).
				if layer == 0:
					tri.call(v00, v11, v10)
					tri.call(v00, v01, v11)
				else:
					tri.call(v00, v10, v11)
					tri.call(v00, v11, v01)
	# Jambs: close the wall along both sides of the mouth with a rounded (bullnose) strip.
	counts.append(faces.size() / 3)
	var segs := 4
	for side in [0, cols]:
		for j in rows_low:
			var o0: Vector3 = surfaces[0][j][side]
			var o1: Vector3 = surfaces[0][j + 1][side]
			var i0: Vector3 = surfaces[1][j][side]
			var i1: Vector3 = surfaces[1][j + 1][side]
			# Above the arch both outlines close onto the centre line: nothing to join there
			# (a strip would be a fin inside the wall).
			var closed := func(v: Vector3) -> bool: return absf(v.x) < 1e-3
			if closed.call(o0) and closed.call(o1) and closed.call(i0) and closed.call(i1):
				continue
			for s in segs:
				var t0 := float(s) / segs
				var t1 := float(s + 1) / segs
				var p00: Vector3 = _jamb_pt(o0, i0, t0)
				var p01: Vector3 = _jamb_pt(o0, i0, t1)
				var p10: Vector3 = _jamb_pt(o1, i1, t0)
				var p11: Vector3 = _jamb_pt(o1, i1, t1)
				if side == 0:
					tri.call(p00, p10, p11)
					tri.call(p00, p11, p01)
				else:
					tri.call(p00, p11, p10)
					tri.call(p00, p01, p11)
	st.generate_normals()
	# Triangle index where each part starts: outer, inner, jambs (for tests).
	return [st.commit(), faces, {"inner": counts[1], "jamb": counts[2], "total": faces.size() / 3, "outline": outline,
			"interior_radius": ri, "wall_h": wall_h, "door_w": dw, "door_h": dh}]


## A point across the jamb from the outer outline (t = 0) to the inner (t = 1), bulging into the
## mouth in the middle so the wall end is rounded, not a flat cut.
static func _jamb_pt(o: Vector3, i: Vector3, t: float) -> Vector3:
	var p := o.lerp(i, t)
	# Never past half-way to the centre line (the mouth narrows to nothing at its crown).
	var into_mouth := Vector3(-signf(p.x), 0.0, 0.0)
	return p + into_mouth * minf(0.14, absf(p.x) * 0.5) * sin(PI * t)


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
