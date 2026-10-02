class_name LevelBuilder
extends RefCounted
## Placement helpers for authoring moss-ball content in (latitude, longitude) terms.

var ball: MossBall
var game: Node
var root: Node3D
var stem_mat: ShaderMaterial
var leaf_mat: ShaderMaterial
var shell_mat: ShaderMaterial
var strand_mat: ShaderMaterial
var bot_hints: Array = []     # authored waypoints for the automated playtest bot
## Ravines on this ball ({id, points (dirs), half (floor half-width + wall, m)}) and the ways
## across them ({a, b (rim points), gate (RestorationGate or null)}), for the bot's paths.
var ravines: Array = []
var crossings: Array = []
## Physics layer of climbing leaves on stem ladders: the axolotl stands on them, but the ground
## rays of creatures walking under them (parasites, food, motes) ignore them.
const CLIMB_LAYER := 8
## How far a climb leaf's base stands out from its stem's surface (its stalk bridges the gap).
const LEAF_CLEAR := 0.15


func _init(p_ball: MossBall, p_game: Node) -> void:
	ball = p_ball
	game = p_game
	root = Node3D.new()
	root.name = "Content"
	ball.add_child(root)


## Startup (2026-10-02): meshes that depend only on their own arguments (stems, ladder leaves) are
## built on worker threads while the layout goes on, and land on their MeshInstance3D nodes in
## finish_meshes() (Levels.build_ball, before the ball is used), in the order they were asked for:
## the same arrays and format SurfaceTool.commit() makes on this thread. Off (the default), each is
## built at once, as before.
var async_meshes := false
var _mesh_jobs: Array = []


## `mi`'s mesh from `build` (-> SurfaceTool ready to commit; must read nothing that the layout
## may change, as it can run later on a worker thread).
func mesh_later(mi: MeshInstance3D, build: Callable) -> void:
	if not async_meshes:
		mi.mesh = (build.call() as SurfaceTool).commit()
		return
	var out := []
	var id := WorkerThreadPool.add_task(func() -> void:
		var st: SurfaceTool = build.call()
		# (SurfaceTool.commit's flags: the custom channels' formats.)
		var flags := 0
		for c in 4:   # (the four custom channels)
			if st.get_custom_format(c) != SurfaceTool.CUSTOM_MAX:
				flags |= st.get_custom_format(c) << (Mesh.ARRAY_FORMAT_CUSTOM_BASE + c * Mesh.ARRAY_FORMAT_CUSTOM_BITS)
		out.append(st.commit_to_arrays())
		out.append(flags), true, "level mesh")
	_mesh_jobs.append([id, mi, out])


## Waits for the meshes mesh_later started and puts each on its node.
func finish_meshes() -> void:
	for j in _mesh_jobs:
		WorkerThreadPool.wait_for_task_completion(j[0])
		var out: Array = j[2]
		var am := ArrayMesh.new()
		if not (out[0][Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty():
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out[0], [], {}, out[1])
		(j[1] as MeshInstance3D).mesh = am
	_mesh_jobs.clear()


func d(lat: float, lon: float) -> Vector3:
	return MossBall.dir_ll(lat, lon)


func zone(id: String, lat: float, lon: float, radius_deg: float) -> void:
	ball.add_zone(id, d(lat, lon), radius_deg)


func pocket(lat: float, lon: float, radius_deg: float) -> void:
	ball.add_heal(d(lat, lon), radius_deg, 0.0)


# --- Terrain -----------------------------------------------------------------------------

## Rolling moss hill: a smooth bump in the ball's own surface (see MossBall.add_hill).
## Authored like the old buried spheres: a sphere of radius `rs` showing `h` above ground;
## the bump keeps that height and spreads wider so the slopes roll gently.
func hill(lat: float, lon: float, rs: float, h: float) -> void:
	var footprint := sqrt(maxf(rs * rs - (rs - h) * (rs - h), 0.01))
	ball.add_hill(d(lat, lon), footprint * 1.5 / ball.radius, h)


## Moss cushion (platform/ledge): a natural mound with a flat top. Returns the body; `top` height in meta.
func cushion(lat: float, lon: float, radius: float, height: float, xf_override: Variant = null) -> StaticBody3D:
	var xf: Transform3D = xf_override if xf_override != null else ball.xform_on_dir(d(lat, lon))
	var body := StaticBody3D.new()
	body.collision_layer = 1
	root.add_child(body)
	body.global_transform = xf
	# A natural mound (MeshLib.mound): flared into the ground, irregular outline, collision = mesh.
	var inv := xf.affine_inverse()
	var ground := func(x: float, z: float) -> float:
		return (inv * ball.surface_point(ball.up_at(xf * Vector3(x, 0.0, z)), 0.0)).y
	var res := MeshLib.mound(radius, height, 1.5, hash(xf.origin.snapped(Vector3.ONE * 0.01)), 28, ground)
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(res[1])
	cs.shape = shape
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = res[0]
	mi.material_override = ball.moss_material
	body.add_child(mi)
	body.set_meta("top", height)
	body.set_meta("radius", radius)
	body.set_meta("grounded", "cushion")
	# (A designed jump: its sides are never crawled over, however they meet the ground; see
	# Axolotl.CRAWL_MAX.)
	body.set_meta("jump_only", true)
	return body


# --- Terrain vocabulary (Expansion 4; docs/WORLD.md) ------------------------------------------
# Every piece is natural (irregular, sweeping into the ground), its collision is exactly its drawn
# triangles, and it records how the bot and the tests can use it.

## A solid body from a mesh built in the frame `xf` (vertices local to it).
func _terrain_body(xf: Transform3D, res: Array, kind: String, grounded := true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	root.add_child(body)
	body.global_transform = xf
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(res[1])
	cs.shape = shape
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = res[0]
	mi.material_override = ball.moss_material
	body.add_child(mi)
	if grounded:
		body.set_meta("grounded", kind)
	body.set_meta("terrain_kind", kind)
	return body


## A ridge along the great circle from (lat0, lon0) to (lat1, lon1): a crest `crest_w` wide at
## `height` above the ground, sides sweeping out to `width`, following the terrain, with walkable
## ramps at both ends (so the crest is an alternate, higher route). Returns the body; its crest line
## (world points) is in meta "crest".
func ridge(lat0: float, lon0: float, lat1: float, lon1: float, height: float, width: float, crest_w: float, seed_v := 1, ramp := 0.3) -> StaticBody3D:
	var a := d(lat0, lon0)
	var b := d(lat1, lon1)
	var mid := a.slerp(b, 0.5)
	var xf := ball.xform_on_dir(mid)
	var inv := xf.affine_inverse()
	var arc := a.angle_to(b) * ball.radius
	var n := maxi(12, int(arc / 0.7))
	var noise := FastNoiseLite.new()
	noise.seed = seed_v
	noise.frequency = 0.08
	var dirs: Array[Vector3] = []
	for i in n:
		dirs.append(a.slerp(b, float(i) / (n - 1)))
	var axis := a.cross(b).normalized()
	var sink := 1.6
	var prof := MeshLib.ridge_profile(width * 0.5, crest_w, sink)
	var hf := func(i: int) -> float:
		var t := float(i) / (n - 1)
		return height * smoothstep(0.0, ramp, t) * smoothstep(0.0, ramp, 1.0 - t) * (1.0 + 0.1 * noise.get_noise_1d(t * arc))
	var place := func(i: int, x: float, y: float) -> Vector3:
		# Sideways across the ridge is a rotation about the path's tangent (stays on the sphere).
		var dside: Vector3 = dirs[i].rotated((dirs[i].cross(axis)).normalized(), x / ball.radius)
		var gp := ball.surface_point(dside, 0.0)
		var up := ball.up_at(gp)
		var yy: float = y if y < 0.0 else y * float(hf.call(i))
		return inv * (gp + up * yy)
	var inside := func(i: int) -> Vector3:
		return inv * ball.surface_point(dirs[i], float(hf.call(i)) * 0.3 - 0.4)
	var body := _terrain_body(xf, MeshLib.sweep(n, prof, false, place, inside), "ridge")
	var crest := []
	for i in n:
		crest.append(ball.surface_point(dirs[i], float(hf.call(i)) + 0.05))
	body.set_meta("crest", crest)
	body.set_meta("top", height)
	return body


## A natural arch from (lat0, lon0) to (lat1, lon1): a rounded slab `width` wide and `thick`
## thick rising from the ground at both ends to `clearance` of open water beneath its middle. Its
## top is walkable (slopes under 52 degrees for spans over about 3 x its height) and Gill passes
## under it. Returns the body; its top line (world points) is in meta "top_line".
func arch(lat0: float, lon0: float, lat1: float, lon1: float, clearance: float, width: float, thick: float) -> StaticBody3D:
	var a := d(lat0, lon0)
	var b := d(lat1, lon1)
	var xf := ball.xform_on_dir(a.slerp(b, 0.5))
	var inv := xf.affine_inverse()
	var n := 28
	var centre: Array[Vector3] = []
	var ups: Array[Vector3] = []
	for i in n:
		var t := float(i) / (n - 1)
		var dd := a.slerp(b, t)
		var s := sin(t * PI)
		# Ends: the slab's top meets the ground; middle: `clearance` under its underside.
		var h := (clearance + thick * 0.5) * s - thick * 0.5 * (1.0 - s)
		centre.append(ball.surface_point(dd, h))
		ups.append(ball.up_at(ball.surface_point(dd, 0.0)))
	var frame := func(i: int) -> Array:
		var tn: Vector3 = (centre[mini(i + 1, n - 1)] - centre[maxi(i - 1, 0)]).normalized()
		var u: Vector3 = (ups[i] - tn * ups[i].dot(tn)).normalized()
		return [tn.cross(u).normalized(), u]
	var place := func(i: int, x: float, y: float) -> Vector3:
		var f: Array = frame.call(i)
		return inv * (centre[i] + (f[0] as Vector3) * x + (f[1] as Vector3) * y)
	var inside := func(i: int) -> Vector3:
		return inv * centre[i]
	var body := _terrain_body(xf, MeshLib.sweep(n, MeshLib.slab_profile(width, thick), true, place, inside), "arch")
	var line := []
	for i in n:
		line.append(centre[i] + (frame.call(i)[1] as Vector3) * (thick * 0.5 + 0.05))
	body.set_meta("top_line", line)
	return body


## A natural bridge between two raised points (world positions on formations, e.g. ridge crests or
## shelf tops), bowing up by `bow`. Its ends sink into the supports it joins.
func bridge(p0: Vector3, p1: Vector3, bow: float, width: float, thick: float) -> StaticBody3D:
	var midp := (p0 + p1) * 0.5
	var up0 := ball.up_at(midp)
	var xf := Transform3D(MossBall.frame_at(up0, 0.0), midp)
	var inv := xf.affine_inverse()
	var n := 20
	var centre: Array[Vector3] = []
	for i in n:
		var t := float(i) / (n - 1)
		centre.append(p0.lerp(p1, t) + up0 * (bow * sin(t * PI) - thick * 0.5))
	var place := func(i: int, x: float, y: float) -> Vector3:
		var tn: Vector3 = (centre[mini(i + 1, n - 1)] - centre[maxi(i - 1, 0)]).normalized()
		var u := (up0 - tn * up0.dot(tn)).normalized()
		return inv * (centre[i] + tn.cross(u).normalized() * x + u * y)
	var inside := func(i: int) -> Vector3:
		return inv * centre[i]
	var body := _terrain_body(xf, MeshLib.sweep(n, MeshLib.slab_profile(width, thick), true, place, inside), "bridge", false)
	body.set_meta("floats_by_design", "natural bridge spanning two formations")
	var line := []
	for i in n:
		line.append(centre[i] + up0 * (thick * 0.5 + 0.05))
	body.set_meta("top_line", line)
	return body


## An overhanging rock shelf: a stem sweeping out of the ground under a wide flat top at `height`
## (the overhang gives shelter beneath; the top is reached from somewhere higher or by a jump).
func shelf(lat: float, lon: float, height: float, r_top: float, r_stem: float) -> StaticBody3D:
	var xf := ball.xform_on_dir(d(lat, lon))
	var inv := xf.affine_inverse()
	var ground := func(x: float, z: float) -> float:
		return (inv * ball.surface_point(ball.up_at(xf * Vector3(x, 0.0, z)), 0.0)).y
	var body := _terrain_body(xf, MeshLib.shelf(r_top, r_stem, height, 1.6, hash(xf.origin.snapped(Vector3.ONE * 0.01)), ground), "shelf")
	body.set_meta("top", height)
	body.set_meta("radius", r_top)
	return body


## Terraces: stepped tiers at one spot, each a mound on the one below. tiers: [[radius, top]]
## with tops measured from the ground; keep each step a plain jump (top difference up to 1.3 m)
## and leave a ring of at least 1.2 m on each tier. Returns the tier bodies (lowest first).
func terrace(lat: float, lon: float, tiers: Array) -> Array:
	var out := []
	var base_xf := ball.xform_on_dir(d(lat, lon))
	var inv0 := base_xf.affine_inverse()
	# Each tier follows the ball's curve: the same height above the ground everywhere, so every
	# step up is the same plain jump right to the rim.
	var ground := func(x: float, z: float) -> float:
		return (inv0 * ball.surface_point(ball.up_at(base_xf * Vector3(x, 0.0, z)), 0.0)).y
	var below := 0.0
	for k in tiers.size():
		var r: float = tiers[k][0]
		var top: float = tiers[k][1]
		var xf := base_xf.translated_local(Vector3(0, below, 0))
		# Upper tiers carry a column down into the ground, hidden inside the tiers below.
		var res := MeshLib.mound(r, top - below, below + 1.5, hash(xf.origin.snapped(Vector3.ONE * 0.01)), 28, ground, true)
		var body := _terrain_body(xf, res, "terrace" if k == 0 else "terrace tier")
		body.set_meta("top", top)
		body.set_meta("radius", r)
		# (Where its top is: `top` is measured from the ground, not from the tier's own base.)
		body.set_meta("top_point", base_xf * Vector3(0, top, 0))
		# (A designed jump: its sides are never crawled over, however they meet the ground; see
		# Axolotl.CRAWL_MAX.)
		body.set_meta("jump_only", true)
		out.append(body)
		below = top
	return out


## A climbable spiral of leaves round a stem at `xf` (one plain jump per step): `count` leaves,
## the first `start` m up, then `rise` m and `turn_deg` degrees apart. Returns the leaf transforms.
func canopy_spiral(xf: Transform3D, count: int, start: float, rise: float, turn_deg: float, stem_h: float, stem_r: float,
		leaf_len := 3.0, leaf_w := 2.4) -> Array:
	stem_xf(xf, stem_h, stem_r, stem_r * 0.7)
	var leaves := []
	for i in count:
		var a := deg_to_rad(turn_deg * i)
		var h := start + i * rise
		var dir := Vector3(cos(a), 0.0, sin(a))
		var r := lerpf(stem_r, stem_r * 0.7, clampf(h / stem_h, 0.0, 1.0))
		var lx := Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.z) + PI), Vector3(dir.x * (r + LEAF_CLEAR), h, dir.z * (r + LEAF_CLEAR)))
		var world := xf * lx
		leaf_xf(world, leaf_len, leaf_w)
		leaves.append(world)
	return leaves


## A stem you can climb: leaves spiralling round it from `start` m up, `rise` m and `turn_deg`
## apart, each one plain jump from the last, up to the top. `levels` is [[height, length, width]]
## per leaf (lowest first; the axis follows the stem's bend). Each leaf grows from the stem on a
## curved stalk (Expansion 6: no leaf floats beside its stem). One body (CLIMB_LAYER) holds every
## leaf's collision, which follows the drawn leaf, and one merged mesh draws them all. Registers
## the climb (audit only: nothing on it is a completion target). Returns the leaf transforms.
func ladder_stem(stem_xf_: Transform3D, stem_h: float, r0: float, r1: float, bend: float, levels: Array, heading0: float, turn_deg: float, name_: String) -> Array:
	var body := StaticBody3D.new()
	body.collision_layer = CLIMB_LAYER
	body.collision_mask = 0
	root.add_child(body)
	body.global_transform = stem_xf_
	body.set_meta("floats_by_design", "leaves attached to a stem")
	var leaf_xfs := []
	var out := []
	var tops := []
	var leaves := []
	for i in levels.size():
		var y: float = levels[i][0]
		var len: float = levels[i][1]
		var w: float = levels[i][2]
		# (A level may give its own heading: a tapering trunk turns less where it is thick.)
		var a := deg_to_rad(float(levels[i][3]) if levels[i].size() > 3 else heading0 + turn_deg * i)
		var dir := Vector3(cos(a), 0.0, sin(a))
		# The bent stem's axis at this height (MeshLib.stem_mesh bends along local x).
		var t := (y + 0.5) / (stem_h + 0.5)
		var axis := Vector3(bend * t * t * (stem_h + 0.5), y, 0.0)
		var r := lerpf(r0, r1, clampf(y / stem_h, 0.0, 1.0))
		# The leaf's base stands just clear of the stem; its stalk reaches back into it.
		var local := Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.z) + PI), axis + dir * (r + LEAF_CLEAR))
		leaf_xfs.append([local, len, w])
		for shape in MeshLib.leaf_collision_shapes(len, w):
			var cs := CollisionShape3D.new()
			cs.shape = shape
			cs.transform = local
			body.add_child(cs)
		var world := stem_xf_ * local
		out.append(world)
		leaves.append([world, len, w])
		# The landing point: the broad middle of a ladder leaf, the broad inner part of a big one.
		tops.append(Levels.leaf_mid(world, minf(1.4, len * 0.5), 0.0).origin)
	# Each leaf's placement and size, for the footing and route audits: [world xform, length, width].
	body.set_meta("leaves", leaves)
	var mi := MeshInstance3D.new()
	mesh_later(mi, func() -> SurfaceTool:
		var st := MeshLib.leaf_surface()
		var nv := 0
		for lf in leaf_xfs:
			nv = MeshLib._leaf_into(st, lf[0], lf[1], lf[2], true, nv)
		st.generate_normals()
		return st)
	mi.material_override = leaf_mat
	mi.visibility_range_end = 140.0
	body.add_child(mi)
	# The climb starts on the ground just past the first leaf's tip.
	var first: Transform3D = out[0]
	var start := ball.surface_point(ball.up_at(Levels.leaf_mid(first, float(levels[0][1]) + 1.4, 0.0).origin))
	bot_hints.append({"route": name_, "audit": true, "start": start, "tops": tops, "zones": [], "goal": "top leaf"})
	return out


## Registers a climb for the bot and the reachability audit: from `start` (on the ground) hop
## along `tops` in order; `zones` are the restoration zones whose elevated motes and parasites it
## serves; `goal` names what it reaches.
func route(name_: String, start: Vector3, tops: Array, zones: Array, goal := "") -> void:
	bot_hints.append({"route": name_, "start": start, "tops": tops, "zones": zones, "goal": goal})


func stem_xf(xf: Transform3D, height: float, r0: float, r1: float, collide := true, bend := 0.0) -> Node3D:
	var node: Node3D
	if collide:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		# Collision follows the drawn stem: straight stems are one cylinder; bent ones a stack of
		# short cylinders along the bend (MeshLib.stem_mesh), so nothing solid sticks out of the
		# stem where it curves away.
		var segs := 1 if bend <= 0.0 else 5
		var total := height + 0.5
		for k in segs:
			var t0 := float(k) / segs
			var t1 := float(k + 1) / segs
			var tm := (t0 + t1) * 0.5
			var cs := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = lerpf(r0, r1, tm) if segs > 1 else (r0 + r1) * 0.5
			# (The drawn stem runs from 0.5 m below its base to its full height: so does this.)
			cyl.height = total * (t1 - t0) if segs > 1 else total
			cs.shape = cyl
			cs.position = Vector3(bend * tm * tm * total, total * tm, 0) if segs > 1 else Vector3(0, total * 0.5, 0)
			body.add_child(cs)
		node = body
	else:
		node = Node3D.new()
	root.add_child(node)
	node.global_transform = xf.translated_local(Vector3(0, -0.5, 0))
	node.set_meta("grounded", "stem")
	var mi := MeshInstance3D.new()
	mesh_later(mi, func() -> SurfaceTool: return MeshLib.stem_surface(r0, r1, height + 0.5, 9, bend))
	mi.material_override = stem_mat
	mi.visibility_range_end = 140.0
	node.add_child(mi)
	return node


func stem(lat: float, lon: float, height: float, r0: float, r1: float, collide := true) -> Node3D:
	return stem_xf(ball.xform_on_dir(d(lat, lon), 0.0, randf() * 360.0), height, r0, r1, collide)


## Static leaf platform: attached at xf.origin, extending along xf's -Z; with `petiole`, a curved
## stalk reaches back (+Z) into the stem it grows from.
func leaf_xf(xf: Transform3D, length: float, width: float, collide := true, petiole := true, stalk := 0.55) -> Node3D:
	var node: Node3D
	if collide:
		var body := StaticBody3D.new()
		body.collision_layer = 2
		# Collision is the drawn leaf (Expansion 6), not a box wider than it.
		for shape in MeshLib.leaf_collision_shapes(length, width):
			var cs := CollisionShape3D.new()
			cs.shape = shape
			body.add_child(cs)
		node = body
	else:
		node = Node3D.new()
	root.add_child(node)
	node.global_transform = xf
	node.set_meta("floats_by_design", "leaf platform attached to a stem")
	# Where it can be stood on (the elevated-route audit), or that it is decoration.
	if collide:
		node.set_meta("top_point", Levels.leaf_mid(xf, length * 0.5, 0.0).origin)
		node.set_meta("leaves", [[xf, length, width]])
	else:
		node.set_meta("decor_leaf", true)
	var mi := MeshInstance3D.new()
	mi.mesh = MeshLib.platform_leaf_mesh(length, width, petiole, stalk)
	mi.material_override = leaf_mat
	mi.visibility_range_end = 140.0
	node.add_child(mi)
	return node


func flex_xf(xf: Transform3D, length: float, width: float, bouncy: bool) -> Platforms.FlexLeaf:
	var f := Platforms.FlexLeaf.new()
	root.add_child(f)
	f.build(ball, xf, length, width, leaf_mat, bouncy)
	f.set_meta("floats_by_design", "flexible leaf attached to a stem")
	f.set_meta("top_point", Levels.leaf_mid(xf, length * 0.5, 0.0).origin)
	f.set_meta("leaves", [[xf, length, width]])
	ball.flex_leaves.append(f)
	return f


func sway_xf(xf: Transform3D, stem_len: float, leaf_len: float, leaf_w: float, amp: float, freq: float, phase: float) -> Platforms.SwayLeaf:
	var s := Platforms.SwayLeaf.new()
	root.add_child(s)
	s.build(ball, xf, stem_len, leaf_len, leaf_w, amp, freq, phase, stem_mat, leaf_mat)
	s.set_meta("floats_by_design", "current-swayed leaf on its own stem")
	s.set_meta("top_point", xf * Vector3(0, stem_len + 0.13, 0))
	return s


func crumble_xf(xf: Transform3D, size: Vector3, zone_id: String) -> Platforms.Crumble:
	var c := Platforms.Crumble.new()
	root.add_child(c)
	c.build(ball, xf, size, zone_id)
	c.set_meta("top_point", xf.origin)
	ball.crumbles.append(c)
	return c


## Local site frame helper: position relative to (lat, lon, heading) in units.
func at(lat: float, lon: float, heading: float, x: float, y: float, z: float, yaw_deg := 0.0) -> Transform3D:
	var xf := ball.site_xform(lat, lon, heading, Vector3(x, y, z))
	if yaw_deg != 0.0:
		xf.basis = xf.basis * Basis(Vector3.UP, deg_to_rad(yaw_deg))
	return xf


# --- World expansion vocabulary (docs/WORLD_EXPANSION.md) --------------------------------------

## Gives `node` its completion id explicitly, so ids never depend on authoring order.
func fixed(node: Object, id: String) -> Object:
	node.set_meta("fixed_id", id)
	return node


## Stamps every completion-bearing node authored so far with the id the catalog has always given
## it (positional, as Completion.build_from_world assigns them), so content added afterwards can
## never shift an id a save has earned. Call once the original content is authored.
func freeze_ids() -> void:
	var tag := Completion.ball_tag(ball.index)
	var taken := Completion._fixed_ids(ball.parasites + ball.motes + ball.upgrades + ball.blooms)
	var n := {}
	for par in ball.parasites:
		fixed(par, Completion._id_for(par, "%s.%s.parasite" % [tag, par.zone_id], n, taken))
	for m in ball.motes:
		fixed(m, Completion._id_for(m, "%s.%s.mote" % [tag, m.zone_id], n, taken))
	for u in ball.upgrades:
		fixed(u, Completion._id_for(u, "%s.cave" % tag, n, taken))
	for bl in ball.blooms:
		fixed(bl, Completion._id_for(bl, "%s.bloom" % tag, n, taken))


## Metres to degrees of arc on this ball.
func m2deg(m: float) -> float:
	return rad_to_deg(m / ball.radius)


## A ravine along the (lat, lon) points (Vector2): `width_m` across its floor, `depth_m` deep,
## walls `wall_m` wide. It must lie inside raised ground (a plateau) with its ends closed: its
## floor is the base sphere and falling onto it is a death (Game.ravine_fall).
func ravine(points_ll: Array, width_m: float, depth_m: float, wall_m: float, id: String) -> void:
	var dirs := []
	for q in points_ll:
		dirs.append(d(q.x, q.y))
	ball.add_ravine(dirs, width_m, depth_m, wall_m, id)
	ravines.append({"id": id, "points": dirs, "half": width_m * 0.5 + wall_m})


## A stone column standing straight up from the ground at `dir` to `height` (a stepping stone in a
## ravine): no skirt, a flat mossy top. Collision is its drawn faces.
func stone_column(dir: Vector3, radius: float, height: float) -> StaticBody3D:
	var xf := ball.xform_on_dir(dir)
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius * 1.12
	cm.height = height + 0.6
	cm.radial_segments = 14
	cm.rings = 6
	var body := StaticBody3D.new()
	body.collision_layer = 1
	root.add_child(body)
	body.global_transform = xf
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	var faces := cm.get_faces()
	# (Drawn from 0.6 m under the ground to `height`.)
	for i in faces.size():
		faces[i] += Vector3(0, cm.height * 0.5 - 0.6, 0)
	shape.set_faces(faces)
	cs.shape = shape
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.position = Vector3(0, cm.height * 0.5 - 0.6, 0)
	mi.material_override = ball.moss_material
	body.add_child(mi)
	body.set_meta("top", height)
	body.set_meta("radius", radius)
	body.set_meta("grounded", "stone column")
	body.set_meta("jump_only", true)
	body.set_meta("terrain_kind", "stone column")
	return body


## A stepping stone that rises out of the ground at `dir` to `height` when `zone` heals
## (RestorationGate "rise": buried until then; it never rises into him). Flat mossy top;
## collision is its drawn faces.
func rising_stone(zone_id: String, dir: Vector3, radius: float, height: float) -> RestorationGate:
	var open_xf := ball.xform_on_dir(dir)
	var closed_xf := open_xf.translated_local(Vector3(0, -height - 0.4, 0))
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius * 1.1
	cm.height = height + 0.6
	cm.radial_segments = 14
	cm.rings = 5
	var gt := RestorationGate.new()
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	var faces := cm.get_faces()
	for i in faces.size():
		faces[i] += Vector3(0, cm.height * 0.5 - 0.6, 0)
	shape.set_faces(faces)
	cs.shape = shape
	gt.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.position = Vector3(0, cm.height * 0.5 - 0.6, 0)
	mi.material_override = ball.moss_material
	gt.add_child(mi)
	gt.setup(ball, zone_id, "rise", closed_xf, open_xf, 2.5)
	gt.set_meta("top", height)
	gt.set_meta("top_point", open_xf * Vector3(0, height, 0))
	gt.set_meta("terrain_kind", "rising stone")
	gt.set_meta("jump_only", true)
	root.add_child(gt)
	return gt


## A fallen stem lying in a ravine that rises into a bridge from `p0` to `p1` (rim points) when
## `zone` heals (RestorationGate "rise"). Its top is walkable; the crossing is registered for the
## bot once it stands.
func fallen_stem_bridge(zone_id: String, p0: Vector3, p1: Vector3, r: float) -> RestorationGate:
	var mid := (p0 + p1) * 0.5
	var up := ball.up_at(mid)
	var along := (p1 - p0)
	var len := along.length() + 2.4
	var y := along.normalized()
	var x := y.cross(up).normalized()
	var z := x.cross(y).normalized()
	# The stem's own axis is local +Y (MeshLib.stem_mesh), centred on its middle.
	var open_xf := Transform3D(Basis(x, y, z), mid - up * (r - 0.12))
	var floor_mid := ball.surface_point(up, 0.0)
	var closed_xf := Transform3D(Basis(x, y, z).rotated(up, 0.35), floor_mid + up * r)
	var gt := RestorationGate.new()
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = r
	cyl.height = len
	cs.shape = cyl
	gt.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = MeshLib.stem_mesh(r * 1.02, r * 0.85, len, 11, 0.0)
	mi.position = Vector3(0, -len * 0.5, 0)
	mi.material_override = stem_mat
	gt.add_child(mi)
	gt.setup(ball, zone_id, "rise", closed_xf, open_xf, 3.0)
	gt.set_meta("floats_by_design", "a fallen stem raised into a bridge across a ravine")
	gt.set_meta("terrain_kind", "stem bridge")
	root.add_child(gt)
	crossings.append({"a": p0, "b": p1, "gate": gt})
	return gt


## A great kelp leaf that unfurls across a ravine from rim `p0` to rim `p1` when `zone` heals
## (RestorationGate "grow": a bud until then; solid once fully grown). Registered as a crossing.
func leaf_bridge(zone_id: String, p0: Vector3, p1: Vector3, width := 2.4) -> RestorationGate:
	var up := ball.up_at((p0 + p1) * 0.5)
	var along := p1 - p0
	along -= up * along.dot(up)
	var len := along.length() + 2.0
	var fwd := along.normalized()
	# The leaf runs along its local -Z from its base, a metre back from the near rim.
	var base := p0 - fwd * 1.0 + up * 0.08
	var xf := Transform3D(Basis(up.cross(-fwd).normalized(), up, -fwd), base)
	var gt := RestorationGate.new()
	for shape in MeshLib.leaf_collision_shapes(len, width):
		var cs := CollisionShape3D.new()
		cs.shape = shape
		gt.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = MeshLib.platform_leaf_mesh(len, width, false)
	mi.material_override = leaf_mat
	gt.add_child(mi)
	gt.setup(ball, zone_id, "grow", xf, xf, 3.0)
	gt.set_meta("floats_by_design", "a kelp leaf grown across a ravine")
	gt.set_meta("terrain_kind", "leaf bridge")
	root.add_child(gt)
	crossings.append({"a": p0, "b": p1, "gate": gt})
	return gt


## A curtain of hanging roots across a doorway at `xf` (its -Z faces out), `width` by `height`;
## it draws up out of the way when `zone` heals (RestorationGate "retract"). Solid while closed.
func root_curtain(zone_id: String, xf: Transform3D, width: float, height: float, seed_v: int, mat: Material = null) -> RestorationGate:
	var gt := RestorationGate.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(width, height, 0.8)
	cs.shape = bx
	cs.position = Vector3(0, height * 0.5, 0)
	gt.add_child(cs)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := int(width / 0.22)
	for i in n:
		var rx := -width * 0.5 + (i + rng.randf()) * width / n
		var rz := rng.randf_range(-0.3, 0.3)
		var rr := rng.randf_range(0.05, 0.11)
		var hang := height * rng.randf_range(0.8, 1.02)
		var m := MeshLib.stem_mesh(rr * 0.6, rr, hang, 5, rng.randf_range(-0.08, 0.08))
		st.append_from(m, 0, Transform3D(Basis(Vector3.RIGHT, PI), Vector3(rx, height + 0.2, rz)))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat if mat != null else stem_mat
	gt.add_child(mi)
	var open_xf := xf.translated_local(Vector3(0, height * 0.9, 0))
	gt.setup(ball, zone_id, "retract", xf, open_xf, 2.5)
	gt.set_meta("floats_by_design", "a root curtain hanging in a doorway")
	root.add_child(gt)
	return gt


## A bubble column rising `height` m from the ground at `dir`, `radius` m across: he is carried up
## it and hangs near the top (MossBall.lift_at). A ring of stones marks its vent.
## The soft pulsing glow under a flowing bubble column (unshaded, additive).
const VENT_GLOW := preload("res://shaders/vent_glow.gdshader")


func bubble_column(dir: Vector3, radius: float, height: float, speed := 5.0, zone_id := "") -> void:
	var base := ball.surface_point(dir, 0.0)
	var up := ball.up_at(base)
	# (With a zone: dormant until that zone heals, then it starts to flow, a new way up.)
	var gate: RestorationGate = null
	var holder: Node3D = root
	if zone_id != "":
		gate = RestorationGate.new()
		var at_base := Transform3D(MossBall.frame_at(up, 0.0), base)
		gate.setup(ball, zone_id, "column", at_base, at_base, 2.0)
		root.add_child(gate)
		holder = gate
	ball.columns.append([base, up, radius, height, speed, gate])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = QuadMesh.new()
	# (Enough bubbles, large enough, to read as a lift even in the dimmest world: Open Issue #2.)
	mm.instance_count = 120
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(base.snapped(Vector3.ONE * 0.1))
	for i in mm.instance_count:
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(rng.randf(), rng.randf(), rng.randf())))
	mm.custom_aabb = AABB(base - Vector3.ONE * (height + radius), Vector3.ONE * 2.0 * (height + radius))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var bm := ShaderMaterial.new()
	bm.shader = preload("res://shaders/bubble_column.gdshader")
	bm.set_shader_parameter("base_pos", base)
	bm.set_shader_parameter("up_dir", up)
	bm.set_shader_parameter("radius", radius * 0.8)
	bm.set_shader_parameter("height", height + 1.0)
	bm.set_shader_parameter("speed", speed * 0.6)
	mmi.material_override = bm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.top_level = true
	mmi.visibility_range_end = 90.0
	holder.add_child(mmi)
	# A soft glow round the vent while it flows (with the bubbles, so a dormant column shows none).
	var glow := MeshInstance3D.new()
	var gq := QuadMesh.new()
	gq.size = Vector2.ONE * radius * 3.2
	gq.orientation = PlaneMesh.FACE_Y
	glow.mesh = gq
	var gm := ShaderMaterial.new()
	gm.shader = VENT_GLOW
	glow.material_override = gm
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.visibility_range_end = 90.0
	# (Under the bubbles, not the gate's body: shown and hidden with them, and never mistaken for
	# part of a platform.)
	mmi.add_child(glow)
	glow.global_transform = Transform3D(MossBall.frame_at(up, 0.0), base + up * 0.08)
	# The vent: a low ring of pebbles (decoration; no collision to trip on).
	var ring := MeshInstance3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sm := SphereMesh.new()
	sm.radial_segments = 8
	sm.rings = 4
	for k in 9:
		var a := TAU * k / 9.0 + rng.randf() * 0.3
		var s := rng.randf_range(0.18, 0.3)
		st.append_from(sm, 0, Transform3D(Basis().scaled(Vector3(s, s * 0.6, s)), Vector3(cos(a), 0.05, sin(a)) * radius))
	ring.mesh = st.commit()
	ring.material_override = shell_mat
	root.add_child(ring)
	ring.global_transform = Transform3D(MossBall.frame_at(up, 0.0), base)
	bot_hints.append({"column": true, "base": base, "up": up, "radius": radius, "height": height, "gate": gate})
	_bubble_sound(holder, base + up * minf(height * 0.5, 3.0))


## A soft, local bubbling where water rises or rushes (quiet, heard only close by; it starts
## with a dormant column or stream when that begins to flow, as it lives under its gate).
func _bubble_sound(holder: Node3D, at: Vector3) -> void:
	if not ResourceLoader.exists("res://assets/audio/amb_bubbler.wav"):
		return
	var snd := AudioStreamPlayer3D.new()
	snd.bus = "Ambience"
	snd.stream = load("res://assets/audio/amb_bubbler.wav")
	snd.unit_size = 3.0
	snd.max_distance = 18.0
	snd.volume_db = -14.0
	# (Under a gate it starts when the water starts to flow: RestorationGate plays it.)
	snd.autoplay = not holder is RestorationGate
	holder.add_child(snd)
	snd.global_position = at


## A current stream from `from` to `to` (points on the ground; it runs a metre above the straight
## line between them): he is carried along it at `speed` m/s. With a zone, it starts to flow when
## that zone heals. Registered as a crossing for the bot when it spans a ravine.
func current_stream(from: Vector3, to: Vector3, radius := 1.2, speed := 7.0, zone_id := "") -> void:
	var up := ball.up_at((from + to) * 0.5)
	var dir := (to - from)
	dir -= up * dir.dot(up)
	var length := dir.length()
	dir = dir.normalized()
	var gate: RestorationGate = null
	var holder: Node3D = root
	if zone_id != "":
		gate = RestorationGate.new()
		var at_base := Transform3D(MossBall.frame_at(up, 0.0), from)
		gate.setup(ball, zone_id, "column", at_base, at_base, 2.0)
		root.add_child(gate)
		holder = gate
	ball.streams.append([from, dir, up, radius, length, speed, gate])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = QuadMesh.new()
	mm.instance_count = int(clampf(length * 9.0, 40.0, 160.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(from.snapped(Vector3.ONE * 0.1))
	for i in mm.instance_count:
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(rng.randf(), rng.randf(), rng.randf())))
	mm.custom_aabb = AABB(from - Vector3.ONE * (length + radius), Vector3.ONE * 2.0 * (length + radius))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var bm := ShaderMaterial.new()
	bm.shader = preload("res://shaders/bubble_column.gdshader")
	bm.set_shader_parameter("base_pos", from + up * 1.0)
	bm.set_shader_parameter("up_dir", dir)
	bm.set_shader_parameter("radius", radius * 0.8)
	bm.set_shader_parameter("height", length)
	bm.set_shader_parameter("speed", speed * 0.8)
	mmi.material_override = bm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.top_level = true
	mmi.visibility_range_end = 90.0
	holder.add_child(mmi)
	_bubble_sound(holder, (from + to) * 0.5 + up * 1.0)
	crossings.append({"a": from, "b": to, "gate": gate, "stream": true})


## A giant sea fan (landmark): a gorgonian of real branching tubes in a gently cupped, rippled
## fan (MeshLib.sea_fan_mesh; 00040-plants replaced the old flat crossing strips), `height` tall and
## `width` across, standing at `xf` (its broad face in the local XY plane). Collision is the drawn
## tubes.
func sea_fan(xf: Transform3D, height: float, width: float, color: Color, seed_v: int) -> StaticBody3D:
	var fan: Array = MeshLib.sea_fan_mesh(height, width, color, seed_v)
	var faces: PackedVector3Array = fan[1]
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	mat.roughness = 0.8
	mat.emission_enabled = true
	mat.emission = color * 0.25
	var body := StaticBody3D.new()
	body.collision_layer = 1
	root.add_child(body)
	body.global_transform = xf
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	cs.shape = shape
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = fan[0]
	mi.material_override = mat
	body.add_child(mi)
	body.set_meta("fan_stats", fan[2])
	body.set_meta("grounded", "sea fan")
	body.set_meta("terrain_kind", "sea fan")
	return body


# --- Actors ------------------------------------------------------------------------------

func parasite(kind: int, zone_id: String, lat: float, lon: float, home_deg := 9.0, h := 0.0) -> Parasite:
	var p := Parasite.new()
	p.setup(ball, kind, zone_id, d(lat, lon), home_deg, h)
	ball.add_child(p)
	ball.parasites.append(p)
	return p


func parasite_xf(kind: int, zone_id: String, xf: Transform3D, home_deg := 3.0) -> Parasite:
	var dir := ball.up_at(xf.origin)
	var h := ball.altitude(xf.origin)
	return parasite(kind, zone_id, rad_to_deg(asin(clampf(dir.y, -1, 1))), rad_to_deg(atan2(dir.x, dir.z)), home_deg, h)


func mote(zone_id: String, lat: float, lon: float, h := 0.0, wander := 2.2) -> Mote:
	var m := Mote.new()
	m.setup(ball, zone_id, d(lat, lon), h, wander)
	ball.add_child(m)
	ball.motes.append(m)
	return m


func mote_xf(zone_id: String, xf: Transform3D, wander := 1.2) -> Mote:
	var dir := ball.up_at(xf.origin)
	var h := ball.altitude(xf.origin)
	var m := Mote.new()
	m.setup(ball, zone_id, dir, h, wander)
	ball.add_child(m)
	ball.motes.append(m)
	return m


func bloom(lat: float, lon: float, h := 0.0) -> Bloom:
	var b := Bloom.new()
	b.setup(ball, d(lat, lon), h)
	ball.add_child(b)
	ball.blooms.append(b)
	ball.add_heal(d(lat, lon), 2.5, 0.0)
	return b


func bloom_xf(xf: Transform3D) -> Bloom:
	var dir := ball.up_at(xf.origin)
	var h := ball.altitude(xf.origin)
	var b := Bloom.new()
	b.setup(ball, dir, h)
	ball.add_child(b)
	ball.blooms.append(b)
	return b


## A Tier-2 shrine at `pos` (world space, on the ground or a leaf) granting `ability`, with its
## practice targets floating at `practice` (world space).
func shrine(ability: String, pos: Vector3, practice: Array) -> Tier2Shrine:
	var s := Tier2Shrine.new()
	s.setup(ball, ability, ball.up_at(pos), ball.altitude(pos))
	s.practice = practice
	ball.add_child(s)
	ball.shrines.append(s)
	return s


func food_region(lat: float, lon: float, radius_deg: float) -> void:
	ball.food_regions.append({"dir": d(lat, lon), "radius": radius_deg})


func hole(lat: float, lon: float, h := 0.0) -> void:
	ball.food_spots.append({"dir": d(lat, lon), "h": h, "occupied": false})


# --- Vegetation dressing -----------------------------------------------------------------

func strands(xf: Transform3D, width: float, depth: float, height: float, count: int, seed_v: int) -> void:
	# Dense hanging/standing moss strands (the hidden cave entrances squeeze through these).
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var mesh := MeshLib.tuft_mesh(1, 0.14, 1.0, 0.0, seed_v, 5, 0.15)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	for i in count:
		var local := Vector3(rng.randf_range(-width, width) * 0.5, 0, rng.randf_range(-depth, depth) * 0.5)
		var p := xf * local
		var up := ball.up_at(p)
		var b := MossBall.frame_at(up, rng.randf() * 360.0).scaled(Vector3(1.0, height * rng.randf_range(0.75, 1.15), 1.0))
		mm.set_instance_transform(i, Transform3D(b, ball.surface_point(up, -0.1)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = strand_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.top_level = true   # instance transforms are in world space
	root.add_child(mmi)


## Interior moss cave: a hollow mossy dome whose low entrance is hidden behind dense strands.
## Inside: a short optional climb to one permanent health upgrade.
func cave(lat: float, lon: float, heading: float, radius := 8.0, reward := "health") -> void:
	var xf := at(lat, lon, heading, 0, 0, 0)
	# Each cave is its own formation: size, mouth and lumps vary with a seed from its site, within
	# ranges that keep the interior climb, the mouth clearance and the ceiling height (MeshLib.cave_mound).
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(roundi(lat * 10.0), roundi(lon * 10.0)))
	var res := MeshLib.cave_mound({"radius": radius * rng.randf_range(0.98, 1.05), "height": rng.randf_range(7.0, 7.5),
			"thickness": 1.3, "door_w": rng.randf_range(2.5, 2.9), "door_h": rng.randf_range(2.3, 2.6), "wall_h": 1.9,
			# Base deep enough for the ball's curvature under the mound, plus a margin for slopes.
			"sink": 1.2 + radius * radius / (2.0 * ball.radius) + 0.4, "ball_radius": ball.radius, "seed": rng.randi()})
	var body := StaticBody3D.new()
	body.collision_layer = 1
	root.add_child(body)
	# Mesh door faces +Z; site forward is -Z, so turn the dome to face its heading.
	body.global_transform = Transform3D(xf.basis * Basis(Vector3.UP, PI), xf.origin)
	body.set_meta("grounded", "cave dome")
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(res[1])
	shape.backface_collision = true
	cs.shape = shape
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = res[0]
	mi.material_override = shell_mat
	body.add_child(mi)
	# Cave darkening centred inside the dome.
	var centre := xf.origin + xf.basis.y * 2.2
	ball.add_cave(Vector4(centre.x, centre.y, centre.z, radius * 1.05))
	# Hidden entrance: dense strands right in front of the door.
	strands(at(lat, lon, heading, 0, 0, -radius - 0.2), 4.2, 1.6, 2.4, 110, int(lat * 100 + lon))
	# Interior climb: three ledges, the last needing a water burst.
	# The original caves keep their layout; grottoes may mirror it, so interiors differ.
	var sx := -1.0 if reward == "pearl" and int(absf(lat * 10.0 + lon)) % 2 == 0 else 1.0
	var l1 := cushion(0, 0, 1.0, 1.2, at(lat, lon, heading, -3.0 * sx, 0, 2.5))
	var l2 := cushion(0, 0, 0.85, 2.6, at(lat, lon, heading, -1.0 * sx, 0, 4.2))
	var l3 := cushion(0, 0, 0.9, 3.9, at(lat, lon, heading, 3.2 * sx, 0, 1.0))
	var up_xf := at(lat, lon, heading, 3.2 * sx, 3.9, 1.0)
	# The interior climb for the elevated-route audit: in through the door, up the three ledges
	# (the last jump lands on the near side of the top ledge).
	bot_hints.append({"route": "cave climb", "audit": true, "burst": true, "start": ball.surface_point(ball.up_at(at(lat, lon, heading, -3.0 * sx, 0, 0.3).origin)),
			"tops": [at(lat, lon, heading, -3.0 * sx, 1.2, 2.5).origin, at(lat, lon, heading, -1.0 * sx, 2.6, 4.2).origin,
			at(lat, lon, heading, 2.64 * sx, 3.9, 1.42).origin], "zones": [], "goal": "cave reward"})
	var u := Platforms.Upgrade.new()
	u.kind = reward
	var dir := ball.up_at(up_xf.origin)
	u.setup(ball, dir, 3.9, up_xf.origin)
	ball.add_child(u)
	ball.upgrades.append(u)
	# Concentrated atmosphere: glowing spores and a soft teal light.
	var light := OmniLight3D.new()
	light.light_color = Color(0.35, 0.9, 0.75)
	light.omni_range = radius * 1.2
	light.light_energy = 0.9
	root.add_child(light)
	light.global_position = xf.origin + xf.basis.y * 3.0
	var spore_mat := StandardMaterial3D.new()
	spore_mat.albedo_color = Color(0.6, 1.0, 0.8)
	spore_mat.emission_enabled = true
	spore_mat.emission = Color(0.5, 1.0, 0.8)
	spore_mat.emission_energy_multiplier = 3.0
	rng.seed = int(lon * 10)
	var sm := SphereMesh.new()
	sm.radius = 0.04
	sm.height = 0.08
	sm.radial_segments = 6
	sm.rings = 3
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sm
	mm.instance_count = 60
	for i in 60:
		var a := rng.randf() * TAU
		var r := rng.randf_range(1.0, radius - 1.2)
		var p := xf * Vector3(cos(a) * r, rng.randf_range(0.2, radius * 0.7), sin(a) * r)
		mm.set_instance_transform(i, Transform3D(Basis(), p))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = spore_mat
	mmi.top_level = true
	root.add_child(mmi)
	bot_hints.append({"cave": true, "reward": u, "body": body, "shape": res[2], "centre": xf.origin, "entry": at(lat, lon, heading, 0, 0, -radius - 2.5).origin, "door": at(lat, lon, heading, 0, 0, -radius + 1.0).origin,
			"ledges": [l1, l2, l3], "upgrade": up_xf.origin, "radius": radius})
