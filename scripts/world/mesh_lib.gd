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


## Moss mound: the natural platform/ledge. Flat walkable top (never smaller than a cushion's
## top: radius minus the rounded rim) exactly at `height`; a rounded rim, then sides that lean
## outward going down and sweep into the ground in a concave curve (no 90-degree wall into the
## moss); an irregular outline from seeded noise. Only the lowest ~0.2 m of the sweep is
## walkable, so it is not a step that makes a jump easier. Returns [ArrayMesh, faces]; the
## collision is exactly the drawn triangles.
## `ground` (optional): Callable(x, z) -> local height of the real terrain under that point, so the
## base follows hills and the ball's curvature instead of a flat plane (the sweep then meets the
## ground everywhere; the top stays level).
static func mound(radius: float, height: float, sink: float, seed_v: int, radial := 28, ground := Callable()) -> Array:
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
		if ground.is_valid() and y < wall_top:
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
