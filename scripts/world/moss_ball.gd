class_name MossBall
extends Node3D
## One giant aquarium moss ball: sphere-centred gravity source, restoration state, health
## field (shared by every moss/plant material on it), vegetation and gameplay content.

signal restoration_changed(ball: MossBall)
signal event_restored(ball: MossBall, pos: Vector3)
signal zone_completed(ball: MossBall, zone_id: String)

const MOSS_SHADER := preload("res://shaders/moss.gdshader")
const VEG_SHADER := preload("res://shaders/vegetation.gdshader")
const PLANT_SHADER := preload("res://shaders/plant.gdshader")
const NOISE := preload("res://assets/textures/noise_rgb.png")
const MAX_HEALS := 64

## The platform leaves' material (LeafMotion sets its landing give and current sway).
var leaf_mat: ShaderMaterial
var index := 0
var radius := 24.0
var display_name := ""
var palette := {}

# Health splats: Vector4(dir.x, dir.y, dir.z, current angular radius)
var heals: Array[Vector4] = []
var heal_targets: Array[float] = []
var heal_speed: Array[float] = []
var _heals_dirty := true
var field_materials: Array[ShaderMaterial] = []
## Vegetation materials only (they take the wake every frame).
var veg_materials: Array[ShaderMaterial] = []

# Restoration bookkeeping.
var zones := {}
var events_total := 0
var events_done := 0
var restoration := 0.0
var completed := false

# Content registries (filled by the level builder).
var motes: Array = []
var parasites: Array = []
## Repopulation (Repopulation; spec docs/research/2026-09-30-DEVICE_AUDIT.md §D): parasites that came back to cleared zones.
## Never in `parasites`, so the completion catalog, the run save and restoration never see them.
var returners: Array = []
var _hostiles: Array = []
var foods: Array = []
var food_spots: Array = []     # burrower holes: {dir, occupied}
var food_regions: Array = []   # {dir, radius_deg}
var food_weights := [0.6, 0.25, 0.15]
var food_target := 7
var blooms: Array = []
var crumbles: Array = []
## Restoration gates (RestorationGate): geography that changes when its zone heals.
var gates: Array = []
## Tier-2 shrines on this ball (Tier2Shrine; docs/TIER2.md).
var shrines: Array = []
## Bubble columns (world expansion traversal toy): [base (world), up, radius, height, speed,
## gate (RestorationGate of kind "column", or null: always flowing)].
## Inside one he is carried up to near its top, where he hangs until he swims off.
var columns: Array = []
var flex_leaves: Array = []
var upgrades: Array = []
## Expansion 5's creatures (Critter): ambient life and threats.
var critters: Array = []
var vortex_out: Node = null
## Every vortex that starts or ends on this ball.
var vortices: Array = []
var vortex_in: Node = null
var arrival_dir := Vector3.UP
var start_dir := Vector3.UP

# Aquarium current (Moss Ball #2). Flow circulates around current_axis in an equatorial band.
var current_axis := Vector3.UP
var current_strength := 0.0

var moss_material: ShaderMaterial
var static_body: StaticBody3D
var _veg_parent: Node3D
var _surface: MeshInstance3D

# Smooth rolling terrain: bell-shaped bumps in the moss surface. [dir, angular radius, height]
var hills: Array = []


func setup(p_index: int, p_radius: float, p_palette: Dictionary) -> void:
	index = p_index
	radius = p_radius
	palette = p_palette
	name = "MossBall%d" % (index + 1)
	static_body = StaticBody3D.new()
	static_body.collision_layer = 1
	static_body.collision_mask = 0
	add_child(static_body)
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = radius
	cs.shape = sph
	static_body.add_child(cs)

	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 128
	sm.rings = 64
	mi.mesh = sm
	moss_material = make_moss_material()
	mi.material_override = moss_material
	mi.name = "MossSurface"
	# (It receives shadows but casts none: a sphere shading itself adds little, and redrawing each
	# ball's surface into the shadow map was most of Expansion 6's frame-time cost.)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_surface = mi
	_veg_parent = Node3D.new()
	_veg_parent.name = "Vegetation"
	add_child(_veg_parent)
	_veg_parent.child_order_changed.connect(func() -> void: _veg_cull_dirty = true)


# --- Materials ---------------------------------------------------------------------------

func register_material(m: ShaderMaterial) -> ShaderMaterial:
	field_materials.append(m)
	# The aquarium light's caustics sample this (vegetation has no other texture).
	if m.get_shader_parameter("noise_tex") == null:
		m.set_shader_parameter("noise_tex", NOISE)
	for k in Aquarium.light_params:
		m.set_shader_parameter(k, Aquarium.light_params[k])
	m.set_shader_parameter("ball_center", global_position if is_inside_tree() else position)
	_ensure_health_map()
	m.set_shader_parameter("health_map", health_tex)
	if vitality_tex != null:
		m.set_shader_parameter("vitality_map", vitality_tex)
		m.set_shader_parameter("vitality_on", true)
	if not caves.is_empty():
		var arr := caves.duplicate()
		while arr.size() < 4:
			arr.append(Vector4(0, 0, 0, -1))
		m.set_shader_parameter("caves", arr)
	_heals_dirty = true
	return m


func make_moss_material(extra := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = MOSS_SHADER
	m.set_shader_parameter("noise_tex", NOISE)
	for k in ["healthy_a", "healthy_b", "dead_a", "dead_b"]:
		if palette.has("moss_" + k):
			m.set_shader_parameter(k, palette["moss_" + k])
	for k in ["stone_a", "stone_b", "moss_tint"]:
		if palette.has(k):
			m.set_shader_parameter(k, palette[k])
	for k in extra:
		m.set_shader_parameter(k, extra[k])
	return register_material(m)


func make_veg_material(healthy_a: Color, healthy_b: Color, extra := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = VEG_SHADER
	m.set_shader_parameter("healthy_a", healthy_a)
	m.set_shader_parameter("healthy_b", healthy_b)
	m.set_shader_parameter("current_axis", current_axis)
	m.set_shader_parameter("current_strength", current_strength * 0.35)
	for k in extra:
		m.set_shader_parameter(k, extra[k])
	veg_materials.append(m)
	return register_material(m)


func make_plant_material(healthy_a: Color, healthy_b: Color, extra := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PLANT_SHADER
	m.set_shader_parameter("noise_tex", NOISE)
	m.set_shader_parameter("healthy_a", healthy_a)
	m.set_shader_parameter("healthy_b", healthy_b)
	for k in extra:
		m.set_shader_parameter(k, extra[k])
	return register_material(m)


# --- Geometry helpers --------------------------------------------------------------------

static func dir_ll(lat: float, lon: float) -> Vector3:
	var la := deg_to_rad(lat)
	var lo := deg_to_rad(lon)
	return Vector3(cos(la) * sin(lo), sin(la), cos(la) * cos(lo))


## `h` is always measured above the actual ground (terrain included).
func surface_point(dir: Vector3, h := 0.0) -> Vector3:
	var d := dir.normalized()
	return global_position + d * (radius + terrain_height(d) + h)


# --- Terrain -------------------------------------------------------------------------------
#
# Ground height above the base sphere is the sum of authored features (hills, plateaus) minus the
# ravines carved into them, never below 0: the base sphere stays the floor of every ravine and the
# safety floor under everything (world expansion, docs/WORLD_EXPANSION.md). Features are bucketed
# by direction so a lookup only visits the few that reach it.

const CELL_DEG := 6.0
## Carved ravines: [points (directions), half width m, depth m, wall m, id].
var carves: Array = []
var _cells := {}
var _cells_dirty := true


## Registers a rolling hill (a cosine bell). Register every feature before placing anything.
func add_hill(dir: Vector3, angular_radius: float, height: float) -> void:
	hills.append([dir.normalized(), angular_radius, height])
	_cells_dirty = true


## A plateau: flat on top at `height`, falling away over its outer `edge_deg`.
func add_plateau(dir: Vector3, angular_radius: float, height: float, edge_deg := 3.0) -> void:
	hills.append([dir.normalized(), angular_radius, height, "plateau", deg_to_rad(edge_deg)])
	_cells_dirty = true


## A ravine cut along `points` (directions from the ball's centre): `width_m` across its floor,
## `depth_m` deep (never below the base sphere), walls `wall_m` wide.
func add_ravine(points: Array, width_m: float, depth_m: float, wall_m := 1.5, id := "") -> void:
	var pts := PackedVector3Array()
	for pt in points:
		pts.append((pt as Vector3).normalized())
	carves.append([pts, width_m * 0.5, depth_m, wall_m, id if id != "" else "ravine.%d" % carves.size()])
	_cells_dirty = true


static func _cell_key(dir: Vector3) -> int:
	var lat := rad_to_deg(asin(clampf(dir.y, -1.0, 1.0))) + 90.0
	var lon := rad_to_deg(atan2(dir.x, dir.z)) + 180.0
	var n_lon := int(ceil(360.0 / CELL_DEG))
	return mini(int(lat / CELL_DEG), int(180.0 / CELL_DEG) - 1) * n_lon + mini(int(lon / CELL_DEG), n_lon - 1)


func _build_cells() -> void:
	_cells.clear()
	var n_lat := int(180.0 / CELL_DEG)
	var n_lon := int(ceil(360.0 / CELL_DEG))
	var pad := deg_to_rad(CELL_DEG) * 1.5
	for i in n_lat:
		for j in n_lon:
			var d := dir_ll(-90.0 + (i + 0.5) * CELL_DEG, -180.0 + (j + 0.5) * CELL_DEG)
			var hs: Array[int] = []
			for k in hills.size():
				var hl: Array = hills[k]
				if (hl[0] as Vector3).angle_to(d) <= float(hl[1]) + pad:
					hs.append(k)
			var cs: Array[int] = []
			for k in carves.size():
				var cv: Array = carves[k]
				if _polyline_angle(d, cv[0]) <= (float(cv[1]) + float(cv[3])) / radius + pad:
					cs.append(k)
			if not hs.is_empty() or not cs.is_empty():
				_cells[i * n_lon + j] = [hs, cs]
	# Typed copies of the hills for terrain_height (startup: ~1 M calls; same values, same arithmetic).
	_hc.resize(hills.size())
	_hcos.resize(hills.size())
	_hang.resize(hills.size())
	_hh.resize(hills.size())
	_hedge.resize(hills.size())
	for k in hills.size():
		var hl: Array = hills[k]
		_hc[k] = hl[0]
		_hang[k] = float(hl[1])
		_hcos[k] = cos(float(hl[1]))
		_hh[k] = float(hl[2])
		_hedge[k] = float(hl[4]) if hl.size() > 3 and hl[3] == "plateau" else -1.0
	_cells_dirty = false


var _hc := PackedVector3Array()
var _hcos := PackedFloat64Array()
var _hang := PackedFloat64Array()
var _hh := PackedFloat64Array()
var _hedge := PackedFloat64Array()


## Smallest angle from `d` to a polyline of directions (great-circle segments).
static func _polyline_angle(d: Vector3, pts: PackedVector3Array) -> float:
	var best := INF
	if pts.size() == 1:
		return d.angle_to(pts[0])
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var n := a.cross(b)
		var ang := INF
		if n.length_squared() > 1e-12:
			n = n.normalized()
			var q := (d - n * d.dot(n))
			if q.length_squared() > 1e-12:
				q = q.normalized()
				if absf(a.angle_to(q) + q.angle_to(b) - a.angle_to(b)) < 1e-4:
					ang = d.angle_to(q)
		best = minf(best, minf(ang, minf(d.angle_to(a), d.angle_to(b))))
	return best


## Ground height above the base sphere at `dir` (features minus ravines, never below 0).
func terrain_height(dir: Vector3) -> float:
	if hills.is_empty() and carves.is_empty():
		return 0.0
	if _cells_dirty:
		_build_cells()
	var cell = _cells.get(_cell_key(dir))
	if cell == null:
		return 0.0
	var h := 0.0
	var hs: Array[int] = cell[0]
	for k in hs:
		var c: float = _hc[k].dot(dir)
		if c <= _hcos[k]:
			continue
		var ang: float = _hang[k]
		var a := acos(minf(c, 1.0))
		var edge: float = _hedge[k]
		if edge >= 0.0:
			h += _hh[k] * (1.0 - smoothstep(ang - edge, ang, a))
		else:
			h += _hh[k] * (0.5 + 0.5 * cos(PI * a / ang))
	var carve := 0.0
	for k in cell[1]:
		var cv: Array = carves[k]
		var dist := _polyline_angle(dir, cv[0]) * radius
		var hw: float = cv[1]
		var wall: float = cv[3]
		carve = maxf(carve, float(cv[2]) * (1.0 - smoothstep(hw, hw + wall, dist)))
	return maxf(0.0, h - carve)


## How deep the ravines cut at `dir` (0 on untouched ground; their full depth on a floor).
func ravine_carve(dir: Vector3) -> float:
	if carves.is_empty():
		return 0.0
	if _cells_dirty:
		_build_cells()
	var cell = _cells.get(_cell_key(dir.normalized()))
	if cell == null:
		return 0.0
	var carve := 0.0
	for k in cell[1]:
		var cv: Array = carves[k]
		var dist := _polyline_angle(dir.normalized(), cv[0]) * radius
		carve = maxf(carve, float(cv[2]) * (1.0 - smoothstep(float(cv[1]), float(cv[1]) + float(cv[3]), dist)))
	return carve


## The ravine whose floor `dir` is on (within its floor, deeper than half its depth), or "".
func ravine_at(dir: Vector3) -> String:
	if carves.is_empty():
		return ""
	if _cells_dirty:
		_build_cells()
	var cell = _cells.get(_cell_key(dir.normalized()))
	if cell == null:
		return ""
	for k in cell[1]:
		var cv: Array = carves[k]
		if _polyline_angle(dir.normalized(), cv[0]) * radius <= float(cv[1]) + float(cv[3]) * 0.35:
			return cv[4]
	return ""


func ground_radius(dir: Vector3) -> float:
	return radius + terrain_height(dir.normalized())


## Height of a world position above the ground directly below it (terrain included).
func altitude(world_pos: Vector3) -> float:
	var off := world_pos - global_position
	return off.length() - ground_radius(off)


func _ground_normal(d: Vector3) -> Vector3:
	var e1 := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
	var e2 := d.cross(e1)
	var eps := 0.004
	var a := (d + e1 * eps).normalized()
	var b := (d - e1 * eps).normalized()
	var c := (d + e2 * eps).normalized()
	var e := (d - e2 * eps).normalized()
	var n := (a * ground_radius(a) - b * ground_radius(b)).cross(c * ground_radius(c) - e * ground_radius(e)).normalized()
	return n if n.dot(d) > 0.0 else -n


# --- Terrain mesh and collision --------------------------------------------------------------
#
# The ground is built as a cube-sphere of tiles about TILE_M across with TILE_Q quads a side
# (under 1 m apart at any radius). Tiles with raised ground get concave collision that is the
# drawn surface; flat ground keeps the base sphere collider. Tiles are drawn merged into a few
# chunks per cube face; from afar the ball swaps to one light whole-ball mesh (FAR_LOD_M).

const TILE_M := 8.0
const TILE_Q := 10
const CHUNKS_PER_EDGE := 2
const FACES := [[Vector3.RIGHT, Vector3.BACK, Vector3.UP], [Vector3.LEFT, Vector3.FORWARD, Vector3.UP],
		[Vector3.UP, Vector3.RIGHT, Vector3.BACK], [Vector3.DOWN, Vector3.RIGHT, Vector3.FORWARD],
		[Vector3.BACK, Vector3.LEFT, Vector3.UP], [Vector3.FORWARD, Vector3.RIGHT, Vector3.UP]]
## Beyond this distance from the ball's surface the far mesh is drawn instead of the tiles.
const FAR_LOD_M := 70.0
var terrain_chunks: Array[MeshInstance3D] = []
## Per ground chunk: its centre direction and angular radius (for horizon culling).
var _chunk_dirs: Array[Vector3] = []
var _chunk_ang: Array[float] = []
var _terrain_shapes: Array[CollisionShape3D] = []
var terrain_tile_count := 0
var terrain_collision_tiles := 0


static func _cube_dir(face: Array, u: float, v: float) -> Vector3:
	# (Equal-angle warp, so tiles are about the same size across a face.)
	var a := tan(u * PI * 0.25)
	var b := tan(v * PI * 0.25)
	return ((face[0] as Vector3) + (face[1] as Vector3) * a + (face[2] as Vector3) * b).normalized()


## Rebuilds the visible ground and its collision once the level is laid out.
func finalize_terrain() -> void:
	if _cells_dirty:
		_build_cells()
	var tiles := maxi(2, int(ceil(radius * PI * 0.5 / TILE_M)))
	tiles = int(ceil(float(tiles) / CHUNKS_PER_EDGE)) * CHUNKS_PER_EDGE
	var per := tiles / CHUNKS_PER_EDGE
	for c in terrain_chunks:
		c.queue_free()
	terrain_chunks.clear()
	_chunk_dirs.clear()
	_chunk_ang.clear()
	for cs in _terrain_shapes:
		cs.queue_free()
	_terrain_shapes.clear()
	terrain_tile_count = 0
	terrain_collision_tiles = 0
	# Startup (2026-10-01, 2026-10-02): every tile's geometry (its height samples, vertices,
	# normals, indices and collision faces) and the far mesh's vertices are computed in parallel on
	# worker threads (pure reads of the hills, ravines and cells, all built above); the meshes,
	# nodes and collision shapes are then made here on the main thread, in the same order, from
	# those exact values, so the ground is bit-identical to building the tiles one by one
	# (_test_terrain_parallel_identical compares the two).
	var jobs: Array = []
	for f in FACES.size():
		for cx in CHUNKS_PER_EDGE:
			for cy in CHUNKS_PER_EDGE:
				var k := 0
				for tx in range(cx * per, (cx + 1) * per):
					for ty in range(cy * per, (cy + 1) * per):
						jobs.append(TileGeometry.new(f, tx, ty, k * (TILE_Q + 1) * (TILE_Q + 1)))
						k += 1
	var far := []
	if parallel_terrain:
		var task := WorkerThreadPool.add_group_task(func(ji: int) -> void:
			if ji == jobs.size():
				far.append(_far_vertices())
			else:
				_tile_geometry(jobs[ji], tiles), jobs.size() + 1, -1, true, "terrain tiles")
		WorkerThreadPool.wait_for_group_task_completion(task)
	else:
		for jb in jobs:
			_tile_geometry(jb, tiles)
		far.append(_far_vertices())
	var next := 0
	for f in FACES.size():
		for cx in CHUNKS_PER_EDGE:
			for cy in CHUNKS_PER_EDGE:
				var st_v := PackedVector3Array()
				var st_n := PackedVector3Array()
				var st_i := PackedInt32Array()
				for tx in range(cx * per, (cx + 1) * per):
					for ty in range(cy * per, (cy + 1) * per):
						_add_tile(jobs[next], st_v, st_n, st_i)
						next += 1
				var arr := []
				arr.resize(Mesh.ARRAY_MAX)
				arr[Mesh.ARRAY_VERTEX] = st_v
				arr[Mesh.ARRAY_NORMAL] = st_n
				arr[Mesh.ARRAY_INDEX] = st_i
				var am := ArrayMesh.new()
				am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
				var mi := MeshInstance3D.new()
				mi.name = "Ground_%d_%d_%d" % [f, cx, cy]
				mi.mesh = am
				mi.material_override = moss_material
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mi.visibility_range_end = radius + FAR_LOD_M
				mi.visibility_range_end_margin = 4.0
				add_child(mi)
				terrain_chunks.append(mi)
				var cd := _cube_dir(FACES[f], -1.0 + (2.0 * cx + 1.0) / CHUNKS_PER_EDGE, -1.0 + (2.0 * cy + 1.0) / CHUNKS_PER_EDGE)
				var corner := _cube_dir(FACES[f], -1.0 + 2.0 * cx / CHUNKS_PER_EDGE, -1.0 + 2.0 * cy / CHUNKS_PER_EDGE)
				_chunk_dirs.append(cd)
				_chunk_ang.append(cd.angle_to(corner) * 1.15)
	# The far mesh: the whole ball, light (hills and ravines at a coarse spacing).
	_surface.mesh = _far_mesh(far[0])
	_surface.visibility_range_begin = radius + FAR_LOD_M
	_surface.visibility_range_begin_margin = 4.0


## Tile geometry on worker threads (finalize_terrain); false builds every tile on the calling
## thread instead (the reference the parallel build is checked against).
var parallel_terrain := true


## One tile's geometry, computed by _tile_geometry (on a worker thread) and added to its chunk by
## _add_tile (on the main thread). `base`: the tile's first vertex index within its chunk.
class TileGeometry extends RefCounted:
	var f: int
	var tx: int
	var ty: int
	var base: int
	var verts: PackedVector3Array
	var norms: PackedVector3Array
	var idx: PackedInt32Array
	## The drawn triangles, for collision; empty when the tile has no raised ground.
	var faces: PackedVector3Array
	var max_h := -INF
	func _init(p_f: int, p_tx: int, p_ty: int, p_base: int) -> void:
		f = p_f
		tx = p_tx
		ty = p_ty
		base = p_base


## A tile's quads (safe on a worker thread: reads only the terrain and writes only `jb`).
func _tile_geometry(jb: TileGeometry, tiles: int) -> void:
	var face: Array = FACES[jb.f]
	var q := TILE_Q
	var n := q + 3   # one sample of border each side, for the normals
	var pos := PackedVector3Array()
	pos.resize(n * n)
	var raised := false
	for j in n:
		for i in n:
			var u := -1.0 + 2.0 * (jb.tx + float(i - 1) / q) / tiles
			var v := -1.0 + 2.0 * (jb.ty + float(j - 1) / q) / tiles
			var d := _cube_dir(face, u, v)
			var h := terrain_height(d)
			jb.max_h = maxf(jb.max_h, h)
			if h > 0.01 and i > 0 and j > 0 and i < n - 1 and j < n - 1:
				raised = true
			pos[j * n + i] = d * (radius + h)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	for j in range(1, n - 1):
		for i in range(1, n - 1):
			var p := pos[j * n + i]
			var nrm := (pos[j * n + i + 1] - pos[j * n + i - 1]).cross(pos[(j + 1) * n + i] - pos[(j - 1) * n + i]).normalized()
			if nrm.dot(p) < 0.0:
				nrm = -nrm
			verts.append(p)
			norms.append(nrm)
	var w := q + 1
	# Front faces are clockwise seen from outside: pick the order from the tile's own geometry.
	var p00 := pos[1 * n + 1]
	var flip := (pos[1 * n + 2] - p00).cross(pos[2 * n + 1] - p00).dot(p00) > 0.0
	var idx := PackedInt32Array()
	var faces := PackedVector3Array()
	var base := jb.base
	for j in q:
		for i in q:
			var a := j * w + i
			var b := a + 1
			var c := a + w
			var d := c + 1
			if flip:
				idx.append_array([base + a, base + c, base + b, base + b, base + c, base + d])
			else:
				idx.append_array([base + a, base + b, base + c, base + b, base + d, base + c])
			if raised:
				faces.append_array([verts[a], verts[b], verts[c], verts[b], verts[d], verts[c]])
	jb.verts = verts
	jb.norms = norms
	jb.idx = idx
	jb.faces = faces


## Adds a computed tile to its chunk's arrays, with collision when it has raised ground.
func _add_tile(jb: TileGeometry, verts: PackedVector3Array, norms: PackedVector3Array, idx: PackedInt32Array) -> void:
	terrain_max_h = maxf(terrain_max_h, jb.max_h)
	verts.append_array(jb.verts)
	norms.append_array(jb.norms)
	idx.append_array(jb.idx)
	terrain_tile_count += 1
	if not jb.faces.is_empty():
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(jb.faces)
		shape.backface_collision = true
		var cs := CollisionShape3D.new()
		cs.shape = shape
		static_body.add_child(cs)
		_terrain_shapes.append(cs)
		terrain_collision_tiles += 1


## Horizon culling: ground and vegetation chunks wholly below the camera's horizon (seen over the
## ball's bulge, allowing for the tallest ground and plants) are not drawn.
var terrain_max_h := 0.0
var chunks_hidden := 0


func update_visibility(cam_pos: Vector3) -> void:
	var to_cam := cam_pos - global_position
	var dist := to_cam.length()
	chunks_hidden = 0
	if dist < radius + 1.0:
		return
	var cam_dir := to_cam / dist
	# The camera sees over the bulge to this angle; tall things beyond it still show their tops.
	var horizon := acos(clampf(radius / dist, -1.0, 1.0)) + acos(clampf(radius / (radius + terrain_max_h + 8.0), -1.0, 1.0))
	for i in terrain_chunks.size():
		var vis := cam_dir.angle_to(_chunk_dirs[i]) < horizon + _chunk_ang[i]
		terrain_chunks[i].visible = vis
		if not vis:
			chunks_hidden += 1
	if _veg_cull_dirty:
		_collect_veg_cull()
	for i in _veg_cull.size():
		_veg_cull[i].visible = cam_dir.angle_to(_veg_cull_dir[i]) < horizon + _veg_cull_ang[i]


## The tagged vegetation chunks with their directions and spreads, gathered once and again only
## when the vegetation's children change (perf 2026-10-02: reading two metas off ~2500 nodes on
## every pass was a 3.5 ms spike four times a second).
var _veg_cull: Array[Node3D] = []
var _veg_cull_dir: Array[Vector3] = []
var _veg_cull_ang: Array[float] = []
var _veg_cull_dirty := true


func _collect_veg_cull() -> void:
	_veg_cull_dirty = false
	_veg_cull.clear()
	_veg_cull_dir.clear()
	_veg_cull_ang.clear()
	for c in _veg_parent.get_children():
		if c is Node3D and c.has_meta("chunk_dir"):
			_veg_cull.append(c)
			_veg_cull_dir.append(c.get_meta("chunk_dir"))
			_veg_cull_ang.append(float(c.get_meta("chunk_ang", 0.9)))


## The far mesh's vertices (safe on a worker thread).
func _far_vertices() -> PackedVector3Array:
	var seg := 96
	var rings := 48
	var verts := PackedVector3Array()
	for r in rings + 1:
		var th := PI * r / rings
		for sg in seg + 1:
			var ph := TAU * sg / seg
			var d := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
			verts.append(d * (radius + terrain_height(d)))
	return verts


func _far_mesh(verts: PackedVector3Array) -> ArrayMesh:
	var seg := 96
	var rings := 48
	var norms := PackedVector3Array()
	for r in rings + 1:
		var th := PI * r / rings
		for sg in seg + 1:
			var ph := TAU * sg / seg
			norms.append(Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph)))
	var idx := PackedInt32Array()
	for r in rings:
		for sg in seg:
			var i00 := r * (seg + 1) + sg
			var i01 := i00 + 1
			var i10 := i00 + seg + 1
			var i11 := i10 + 1
			idx.append_array([i00, i11, i01, i00, i10, i11])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am


func up_at(world_pos: Vector3) -> Vector3:
	return (world_pos - global_position).normalized()


## Orthonormal basis at a surface direction; -Z points toward `heading` (degrees clockwise from
## local north, i.e. toward +Y pole).
static func frame_at(dir: Vector3, heading_deg: float) -> Basis:
	var up := dir.normalized()
	var ref := Vector3.UP if absf(up.y) < 0.98 else Vector3.FORWARD
	var north := (ref - up * ref.dot(up)).normalized()
	var east := north.cross(up)
	var h := deg_to_rad(heading_deg)
	var fwd := north * cos(h) + east * sin(h)
	var right := fwd.cross(up)
	return Basis(right, up, -fwd)


## Curvature-aware placement. local = (x right, y height above surface, z back) relative to a
## site frame. Returns a transform whose Y axis is the local radial up.
func site_xform(lat: float, lon: float, heading: float, local := Vector3.ZERO) -> Transform3D:
	var d := dir_ll(lat, lon)
	var b := frame_at(d, heading)
	var flat := d * radius + b.x * local.x + b.z * local.z
	var nd := flat.normalized()
	var nb := frame_at(nd, 0.0)
	# Keep the site's heading: re-orthonormalise its forward onto the new tangent plane.
	var fwd := -b.z
	fwd = (fwd - nd * fwd.dot(nd)).normalized()
	nb = Basis(fwd.cross(nd), nd, -fwd)
	return Transform3D(nb, global_position + nd * (radius + terrain_height(nd) + local.y))


func xform_on_dir(dir: Vector3, h := 0.0, heading := 0.0) -> Transform3D:
	return Transform3D(frame_at(dir, heading), surface_point(dir, h))


# --- Health field ------------------------------------------------------------------------

## Settled restoration (world expansion): an equirectangular map the shaders sample; splats in
## `heals` are only the ones still growing in, painted into the map once they reach full size.
const HEALTH_MAP_W := 512
const HEALTH_MAP_H := 256
var health_img: Image
var health_tex: ImageTexture
var _health_dirty := false


func add_heal(dir: Vector3, radius_deg: float, grow_time := 1.2) -> void:
	var d := dir.normalized()
	var target := deg_to_rad(radius_deg)
	if _heal_record != null:
		_heal_record.append([d, target])
	if grow_time <= 0.0:
		_paint_heal(d, target)
		return
	if heals.size() >= MAX_HEALS:
		# (Out of uniform room: settle the oldest one into the map now.)
		_settle(0)
	heals.append(Vector4(d.x, d.y, d.z, 0.0))
	heal_targets.append(target)
	heal_speed.append(target / maxf(grow_time, 0.001))
	_heals_dirty = true


func _settle(i: int) -> void:
	var s := heals[i]
	_paint_heal(Vector3(s.x, s.y, s.z), heal_targets[i])
	heals.remove_at(i)
	heal_targets.remove_at(i)
	heal_speed.remove_at(i)
	_heals_dirty = true


func _ensure_health_map() -> void:
	if health_img == null:
		health_img = Image.create(HEALTH_MAP_W, HEALTH_MAP_H, false, Image.FORMAT_R8)
		health_img.fill(Color(0, 0, 0))
		health_tex = ImageTexture.create_from_image(health_img)
		for m in field_materials:
			m.set_shader_parameter("health_map", health_tex)


## Paints a splat into the map (the strongest splat wins, as in the shader's splat formula).
func _paint_heal(d: Vector3, ang: float) -> void:
	_ensure_health_map()
	_paint_into(health_img, d, ang)
	_health_dirty = true


static func _paint_into(img: Image, d: Vector3, ang: float) -> void:
	var lat := asin(clampf(d.y, -1.0, 1.0))
	var lon := atan2(d.x, d.z)
	var y0 := maxi(0, int(floor((0.5 - (lat + ang) / PI) * HEALTH_MAP_H)) - 1)
	var y1 := mini(HEALTH_MAP_H - 1, int(ceil((0.5 - (lat - ang) / PI) * HEALTH_MAP_H)) + 1)
	var cos_ang := cos(minf(ang, PI))
	for y in range(y0, y1 + 1):
		var la := (0.5 - (y + 0.5) / HEALTH_MAP_H) * PI
		# Columns this row can reach (all of them near a pole or for a huge splat).
		var span := PI
		if ang < PI * 0.5 and absf(la) + ang < PI * 0.5:
			span = asin(clampf(sin(ang) / maxf(cos(la), 1e-4), 0.0, 1.0)) + 0.02
		var x0 := int(floor(((lon - span) / TAU + 0.5) * HEALTH_MAP_W)) - 1
		var x1 := int(ceil(((lon + span) / TAU + 0.5) * HEALTH_MAP_W)) + 1
		if span >= PI:
			x0 = 0
			x1 = HEALTH_MAP_W - 1
		for xx in range(x0, x1 + 1):
			var x := posmod(xx, HEALTH_MAP_W)
			var lo := ((x + 0.5) / HEALTH_MAP_W - 0.5) * TAU
			var pd := Vector3(cos(la) * sin(lo), sin(la), cos(la) * cos(lo))
			var c := pd.dot(d)
			if c < cos_ang - 0.02 and ang < PI:
				continue
			var v := 1.0 - smoothstep(ang * 0.55, ang, acos(clampf(c, -1.0, 1.0)))
			if v > img.get_pixel(x, y).r:
				img.set_pixel(x, y, Color(v, 0, 0))


# --- Onboarding's staged restoration (presentation only; docs/ONBOARDING.md) -------------------
# The true health (health_img, heals, health_at, restoration) is never touched here: the kill
# applies exactly as always. Only the shaders are told to draw part of it as it looked before,
# behind a front that spreads outward (health_field.gdshaderinc, stage_*).

## While not null, every splat add_heal() is given is noted here ([dir, angle in radians]).
var _heal_record = null
## The staged reveal in progress (stage_outer > 0), for tests and diagnostics.
var stage_dir := Vector3.UP
var stage_reveal := 0.0
var stage_outer := 0.0
var _stage_base: ImageTexture
var _stage_base_img: Image


func record_heals_begin() -> void:
	_heal_record = []


func record_heals_end() -> Array:
	var r: Array = _heal_record if _heal_record != null else []
	_heal_record = null
	return r


## The moss as it is drawn right now (settled map plus the splats still growing), as an image.
func health_snapshot() -> Image:
	_ensure_health_map()
	var img := health_img.duplicate() as Image
	for i in heals.size():
		var s := heals[i]
		if s.w > 0.0:
			_paint_into(img, Vector3(s.x, s.y, s.z), s.w)
	return img


## Starts drawing the area within `outer` (radians) of `dir` as `base` (the snapshot from before
## the kill) beyond a front at angle 0; stage_set() moves the front out.
func stage_begin(dir: Vector3, outer: float, base: Image) -> void:
	stage_dir = dir.normalized()
	stage_outer = maxf(0.001, outer)
	stage_reveal = 0.0
	_stage_base_img = base
	_stage_base = ImageTexture.create_from_image(base)
	for m in field_materials:
		m.set_shader_parameter("health_base", _stage_base)
		m.set_shader_parameter("stage_dir", stage_dir)
		m.set_shader_parameter("stage_outer", stage_outer)
		m.set_shader_parameter("stage_reveal", 0.0)


func stage_set(reveal: float) -> void:
	stage_reveal = reveal
	set_field_param("stage_reveal", reveal)


## Ends the staging: everything is drawn as it truly is.
func stage_end() -> void:
	stage_outer = 0.0
	stage_reveal = 0.0
	set_field_param("stage_outer", 0.0)
	_stage_base = null
	_stage_base_img = null


func staging() -> bool:
	return stage_outer > 0.0


## What the shaders draw at `dir` (health_at with the staging applied): tests and renders.
func shown_health_at(dir: Vector3) -> float:
	var h := drawn_health_at(dir)
	if stage_outer <= 0.0 or _stage_base_img == null:
		return h
	var d := dir.normalized()
	var a := acos(clampf(d.dot(stage_dir), -1.0, 1.0))
	if a >= stage_outer:
		return h
	var img := _stage_base_img
	var u := atan2(d.x, d.z) / TAU + 0.5
	var v := 0.5 - asin(clampf(d.y, -1.0, 1.0)) / PI
	var b := img.get_pixel(clampi(int(u * HEALTH_MAP_W), 0, HEALTH_MAP_W - 1), clampi(int(v * HEALTH_MAP_H), 0, HEALTH_MAP_H - 1)).r
	var ahead := smoothstep(stage_reveal - 0.045, stage_reveal, a)
	if vitality_img == null:
		return lerpf(h, minf(h, b), ahead)
	# (As the shader: the staging is applied first, the vitality dims the result.)
	var raw := health_at(dir)
	return lerpf(raw, minf(raw, b), ahead) * lerpf(VIT_DIM, 1.0, vitality_at(dir))


# --- Hard Mode vitality (HardMode, ledger row 12) -----------------------------------------------
# Each zone's vitality V dims what is drawn: health x lerp(0.35, 1, V), through a small equirectangular
# map (same layout as the health map). The permanent health map, restoration and every earned id are
# never touched. Null in Normal: nothing is sampled or drawn differently.

const VIT_W := 64
const VIT_H := 32
const VIT_DIM := 0.35
var vitality_img: Image = null
var vitality_tex: ImageTexture = null


## Hard Mode: the vitality map to draw (R8, VIT_W x VIT_H). The first call turns it on in every material.
func set_vitality_image(img: Image) -> void:
	vitality_img = img
	if vitality_tex == null:
		vitality_tex = ImageTexture.create_from_image(img)
		for m in field_materials:
			m.set_shader_parameter("vitality_map", vitality_tex)
			m.set_shader_parameter("vitality_on", true)
	else:
		vitality_tex.update(img)


## Turns the vitality map off again (tests that drew it put the ball back as Normal draws it).
func clear_vitality() -> void:
	vitality_img = null
	vitality_tex = null
	for m in field_materials:
		m.set_shader_parameter("vitality_on", false)
		m.set_shader_parameter("vitality_map", null)


## The vitality drawn at `dir` (1 without Hard Mode), sampled as the shader samples it.
func vitality_at(dir: Vector3) -> float:
	if vitality_img == null:
		return 1.0
	var d := dir.normalized()
	var fx := (atan2(d.x, d.z) / TAU + 0.5) * VIT_W - 0.5
	var fy := (0.5 - asin(clampf(d.y, -1.0, 1.0)) / PI) * VIT_H - 0.5
	var x0 := int(floor(fx))
	var y0 := int(floor(fy))
	var tx := fx - x0
	var ty := fy - y0
	var px := func(x: int, y: int) -> float: return vitality_img.get_pixel(posmod(x, VIT_W), posmod(y, VIT_H)).r
	return lerpf(lerpf(px.call(x0, y0), px.call(x0 + 1, y0), tx), lerpf(px.call(x0, y0 + 1), px.call(x0 + 1, y0 + 1), tx), ty)


## The health drawn at `dir` with Hard Mode's vitality (health_at in Normal).
func drawn_health_at(dir: Vector3) -> float:
	var h := health_at(dir)
	return h if vitality_img == null else h * lerpf(VIT_DIM, 1.0, vitality_at(dir))


## CPU mirror of the shader's health function (gameplay such as crumbling moss, and tests).
func health_at(dir: Vector3) -> float:
	var h := 0.0
	if health_img != null:
		var d := dir.normalized()
		var u := atan2(d.x, d.z) / TAU + 0.5
		var v := 0.5 - asin(clampf(d.y, -1.0, 1.0)) / PI
		# Bilinear, as the shader samples it (wrapping round in longitude).
		var fx := u * HEALTH_MAP_W - 0.5
		var fy := clampf(v * HEALTH_MAP_H - 0.5, 0.0, HEALTH_MAP_H - 1.0)
		var x0 := int(floor(fx))
		var y0 := int(floor(fy))
		var tx := fx - x0
		var ty := fy - y0
		var y1 := mini(y0 + 1, HEALTH_MAP_H - 1)
		var a := lerpf(health_img.get_pixel(posmod(x0, HEALTH_MAP_W), y0).r, health_img.get_pixel(posmod(x0 + 1, HEALTH_MAP_W), y0).r, tx)
		var b := lerpf(health_img.get_pixel(posmod(x0, HEALTH_MAP_W), y1).r, health_img.get_pixel(posmod(x0 + 1, HEALTH_MAP_W), y1).r, tx)
		h = lerpf(a, b, ty)
	for s in heals:
		var ang := acos(clampf(dir.normalized().dot(Vector3(s.x, s.y, s.z)), -1.0, 1.0))
		h = maxf(h, 1.0 - smoothstep(s.w * 0.55, s.w, ang))
	return h


## Visual layer of the few things that cast the ceiling light's shadow (Aquarium.sun casts only
## from it, Expansion 6 "selective shadows"): the axolotl, parasites, creatures, climbing leaves
## and stems. Terrain, formations and vegetation only receive shadows: drawing them into the
## shadow map was most of the frame time the lighting added.
const SHADOW_CASTER_LAYER := 1 << 10


## Puts every visible mesh under `n` that may cast a shadow on the caster layer.
static func mark_caster(n: Node) -> void:
	if n is GeometryInstance3D and (n as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
		(n as VisualInstance3D).layers |= SHADOW_CASTER_LAYER
	for c in n.get_children():
		mark_caster(c)


## Plants that sprout only as the ball heals (Levels._sprouts): not drawn at all until it is a
## quarter restored (on neglected moss they would be zero-size and still cost their triangles).
var sprout_nodes: Array = []
## The reef corals (Levels._accent_flora), for diagnostics.
var coral_nodes: Array = []
var _sprouts_shown := true


func _update_sprouts() -> void:
	var want := restoration >= 0.25
	if not want:
		for h in heals:
			if h.w > 90.0:
				want = true
				break
	if want != _sprouts_shown:
		_sprouts_shown = want
		for n in sprout_nodes:
			(n as Node3D).visible = want


func _process(delta: float) -> void:
	_update_sprouts()
	var growing := false
	for i in range(heals.size() - 1, -1, -1):
		var s := heals[i]
		if s.w < heal_targets[i]:
			s.w = minf(heal_targets[i], s.w + heal_speed[i] * delta)
			heals[i] = s
			growing = true
		else:
			# Fully grown: into the map it goes.
			_settle(i)
	if _health_dirty and health_tex != null:
		health_tex.update(health_img)
		_health_dirty = false
	if growing or _heals_dirty:
		_push_heals()
		_heals_dirty = false


func _push_heals() -> void:
	var arr := PackedVector4Array()
	arr.resize(MAX_HEALS)
	for i in heals.size():
		arr[i] = heals[i]
	for m in field_materials:
		m.set_shader_parameter("heals", arr)
		m.set_shader_parameter("heal_count", heals.size())
		m.set_shader_parameter("ball_center", global_position)


## Cave interiors on this ball (darkened in every terrain, vegetation and plant material).
var caves := PackedVector4Array()


func add_cave(c: Vector4) -> void:
	if caves.size() >= 4:
		push_warning("more than 4 caves on %s: the extra one is not darkened" % name)
		return
	caves.append(c)
	var arr := caves.duplicate()
	while arr.size() < 4:
		arr.append(Vector4(0, 0, 0, -1))
	set_field_param("caves", arr)


func set_veg_param(param: String, value: Variant) -> void:
	for m in veg_materials:
		m.set_shader_parameter(param, value)


func set_field_param(param: String, value: Variant) -> void:
	for m in field_materials:
		m.set_shader_parameter(param, value)


# --- Restoration -------------------------------------------------------------------------

func add_zone(id: String, dir: Vector3, radius_deg: float) -> void:
	zones[id] = {"dir": dir.normalized(), "radius": radius_deg, "total": 0, "done": 0, "completed": false}


func register_event(zone_id: String) -> void:
	zones[zone_id]["total"] += 1
	events_total += 1


func complete_event(zone_id: String, pos: Vector3, splat_deg := 11.0) -> void:
	var z: Dictionary = zones[zone_id]
	z["done"] += 1
	events_done += 1
	add_heal(up_at(pos), splat_deg, 1.4)
	restoration = float(events_done) / maxf(1.0, float(events_total))
	event_restored.emit(self, pos)
	if z["done"] >= z["total"] and not z["completed"]:
		z["completed"] = true
		add_heal(z["dir"], z["radius"] * 1.12, 3.5)
		for c in crumbles:
			if c.zone_id == zone_id:
				c.restore()
		for gt in gates:
			if gt.zone_id == zone_id:
				gt.open(true)
		zone_completed.emit(self, zone_id)
	if events_done >= events_total and not completed:
		completed = true
		add_heal(Vector3.UP, 340.0, 8.0)
	restoration_changed.emit(self)


## Continuing a saved run: an event that was already restored. Same bookkeeping and healed moss
## as complete_event, but instant and silent (no signals, sounds or growth animation).
func restore_event(zone_id: String, pos: Vector3, splat_deg := 11.0) -> void:
	var z: Dictionary = zones[zone_id]
	z["done"] += 1
	events_done += 1
	add_heal(up_at(pos), splat_deg, 0.0)
	restoration = float(events_done) / maxf(1.0, float(events_total))
	if z["done"] >= z["total"] and not z["completed"]:
		z["completed"] = true
		add_heal(z["dir"], z["radius"] * 1.12, 0.0)
		for c in crumbles:
			if c.zone_id == zone_id:
				c.restored = true
				c.remove_meta("unsafe")
		for gt in gates:
			if gt.zone_id == zone_id:
				gt.open(false)
	if events_done >= events_total and not completed:
		completed = true
		add_heal(Vector3.UP, 340.0, 0.0)


## Every parasite on the ball that fights (authored ones and returners): for combat, neighbours and
## hits, never for completion or restoration (those use `parasites`).
func hostiles() -> Array:
	return parasites if returners.is_empty() else _hostiles


## Call after `returners` changes.
func returners_changed() -> void:
	_hostiles = parasites + returners


func zone_health(zone_id: String) -> float:
	var z: Dictionary = zones[zone_id]
	return float(z["done"]) / maxf(1.0, float(z["total"]))


# --- Bubble columns -----------------------------------------------------------------------

## Current streams (world expansion, Current Hollows): [base (world), dir (unit, tangent), up,
## radius, length, speed, gate or null]. A jet of moving water about a metre up that carries him
## along it, holding him at its height (a current bridge).
var streams: Array = []


## The stream velocity at `world_pos` (zero outside every stream): full speed along its middle,
## easing in over its first and out over its last 1.5 m.
func stream_at(world_pos: Vector3) -> Vector3:
	for st in streams:
		var off: Vector3 = world_pos - (st[0] as Vector3)
		var dir: Vector3 = st[1]
		var along := off.dot(dir)
		var length: float = st[4]
		if along < 0.0 or along > length:
			continue
		var axis_pt: Vector3 = (st[0] as Vector3) + dir * along + (st[2] as Vector3) * 1.0
		if world_pos.distance_to(axis_pt) > float(st[3]):
			continue
		var flow: float = 1.0 if st[6] == null else (st[6] as RestorationGate).flow
		var k := smoothstep(0.0, 1.5, along) * (1.0 - smoothstep(length - 1.5, length, along))
		return dir * float(st[5]) * flow * maxf(k, 0.25)
	return Vector3.ZERO


## Whether `world_pos` is inside a bubble column's reach (flowing or not yet).
func in_column(world_pos: Vector3) -> bool:
	for c in columns:
		var off: Vector3 = world_pos - (c[0] as Vector3)
		var along: float = off.dot(c[1])
		if along >= -0.5 and along <= float(c[3]) and (off - (c[1] as Vector3) * along).length() <= float(c[2]):
			return true
	return false


## The upward speed a bubble column carries him at `world_pos` (0 outside every column): full
## speed low down, easing to nothing over its top 1.5 m, so he rises to the top and hangs there.
func lift_at(world_pos: Vector3) -> float:
	for c in columns:
		var off: Vector3 = world_pos - (c[0] as Vector3)
		var along: float = off.dot(c[1])
		if along < -0.5 or along > float(c[3]):
			continue
		if (off - (c[1] as Vector3) * along).length() > float(c[2]):
			continue
		var flow: float = 1.0 if c.size() < 6 or c[5] == null else (c[5] as RestorationGate).flow
		if float(c[4]) < 0.0:
			return float(c[4]) * flow   # (a glide shaft sinks him evenly all the way down)
		return float(c[4]) * flow * (1.0 - smoothstep(float(c[3]) - 1.5, float(c[3]), along))
	return 0.0


# --- Current -----------------------------------------------------------------------------

## Aquarium current velocity at a world position (zero on balls without current). Sheltered
## areas (near the poles of current_axis, or low inside dense growth) get little flow.
func current_at(world_pos: Vector3) -> Vector3:
	if current_strength <= 0.0:
		return Vector3.ZERO
	var up := up_at(world_pos)
	var band := 1.0 - smoothstep(0.45, 0.8, absf(up.dot(current_axis)))
	var alt := altitude(world_pos)
	var exposure := clampf(0.55 + alt * 0.2, 0.3, 1.3)
	return current_axis.cross(up).normalized() * current_strength * band * exposure


# --- Vegetation --------------------------------------------------------------------------

const CHUNK_DIRS := [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1),
		Vector3(1, 1, 1), Vector3(1, 1, -1), Vector3(1, -1, 1), Vector3(1, -1, -1), Vector3(-1, 1, 1), Vector3(-1, 1, -1), Vector3(-1, -1, 1), Vector3(-1, -1, -1)]


## On (or just round) a vortex's tidal-pool landing pad on this ball: no plant or scattered piece
## grows there (owner, v96 phone test: a plant grew through a pad). The pads' directions come from
## the level layout, so this works before the vortices themselves are built.
func on_vortex_pad(d: Vector3) -> bool:
	var lim := (Vortex.POOL_R + 0.8) / radius
	for pair in Levels.LINKS:
		var other := -1
		if pair[0] == index:
			other = pair[1]
		elif pair[1] == index:
			other = pair[0]
		if other >= 0 and d.angle_to(Levels._vortex_dir(index, other)) < lim:
			return true
	return false


## Scatter instanced vegetation over the sphere. `accept` (optional) filters directions.
## Instances are chunked by direction so the far side of the ball is frustum culled.
func scatter(mesh: Mesh, mat: Material, count: int, seed_v: int, scale_min: float, scale_max: float,
		accept: Callable = Callable(), vis_end := 70.0, sink := 0.05) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	# World expansion: instances go into cells about 35 m across (a grid on each face of a cube
	# round the ball), each drawn from its own centre, so distance and horizon culling drop the
	# cells he cannot see instead of whole sides of a big ball.
	var k := clampi(int(ceil(sqrt(4.0 * PI * radius * radius / 6.0) / 35.0)), 1, 6)
	var buckets := {}
	var tries := 0
	var placed := 0
	while placed < count and tries < count * 6:
		tries += 1
		var d := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
		if accept.is_valid() and not accept.call(d):
			continue
		var key := _cube_cell(d, k)
		var b := frame_at(d, rng.randf() * 360.0)
		var s := rng.randf_range(scale_min, scale_max)
		# (Never on a vortex's landing pad. Skipped after its draws, so every other placement on the
		# ball stays exactly where it was.)
		if on_vortex_pad(d):
			continue
		b = b.scaled(Vector3(s, s, s))
		if not buckets.has(key):
			buckets[key] = []
		buckets[key].append(Transform3D(b, d * (radius + terrain_height(d) - sink)))
		placed += 1
	var out := []
	for key in buckets:
		var list: Array = buckets[key]
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = MultiMesh.new()
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = vis_end
		mmi.visibility_range_end_margin = 10.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		fill_chunk(mmi, mesh, list)
		var xfs: Array[Transform3D] = []
		xfs.assign(list)
		mmi.set_meta("veg_transforms", xfs)
		_veg_parent.add_child(mmi)
		out.append(mmi)
	return out


## The cube-face grid cell (k x k per face) a direction falls in.
static func _cube_cell(d: Vector3, k: int) -> int:
	var a := d.abs()
	var face: int
	var u: float
	var v: float
	if a.x >= a.y and a.x >= a.z:
		face = 0 if d.x > 0.0 else 1
		u = d.y / a.x
		v = d.z / a.x
	elif a.y >= a.z:
		face = 2 if d.y > 0.0 else 3
		u = d.x / a.y
		v = d.z / a.y
	else:
		face = 4 if d.z > 0.0 else 5
		u = d.x / a.z
		v = d.y / a.z
	var cu := clampi(int((u + 1.0) * 0.5 * k), 0, k - 1)
	var cv := clampi(int((v + 1.0) * 0.5 * k), 0, k - 1)
	return (face * k + cu) * k + cv


## Fills an instanced node with `list` (ball-local transforms), the node standing at the middle
## of its instances (so its visibility range is measured from where they are), and tags it for
## horizon culling.
func fill_chunk(mmi: MultiMeshInstance3D, mesh: Mesh, list: Array) -> void:
	var c := Vector3.ZERO
	for x in list:
		c += (x as Transform3D).origin
	c /= maxf(1.0, float(list.size()))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = list.size()
	for j in list.size():
		var x: Transform3D = list[j]
		mm.set_instance_transform(j, Transform3D(x.basis, x.origin - c))
	mmi.multimesh = mm
	mmi.position = c
	tag_chunk(mmi, list)


## Marks an instanced node with the direction and angular spread of its instances (ball-local
## transforms), for horizon culling.
static func tag_chunk(node: Node3D, xforms: Array) -> void:
	var c := Vector3.ZERO
	for x in xforms:
		c += (x as Transform3D).origin.normalized()
	if c.length_squared() < 1e-8:
		return
	c = c.normalized()
	var spread := 0.0
	for x in xforms:
		spread = maxf(spread, c.angle_to((x as Transform3D).origin))
	node.set_meta("chunk_dir", c)
	node.set_meta("chunk_ang", spread + 0.05)


## Adds an instanced vegetation node (Vegetation.field and friends) to this ball's vegetation,
## so it is density-scaled with the rest.
func add_vegetation(node: Node3D) -> void:
	_veg_parent.add_child(node)


# --- The view from the room (docs/AQUARIUM.md) -------------------------------------------------

## A thinned copy of this world's own vegetation (every `keep`-th plant of every chunk, a little
## larger to make up the density), with the same meshes and materials, so the plant cover and its
## health read from outside the tank, where the real chunks are beyond their visibility ranges.
## Built each time an outside view opens and freed when it closes.
var _far_veg: Node3D


func set_far_view(on: bool, keep := 5, grow := 1.7) -> void:
	if not on:
		# (Nothing of it stays behind in play: built on the way out, freed on the way back in.)
		if _far_veg != null:
			_far_veg.queue_free()
			_far_veg = null
		return
	if _far_veg != null:
		return
	# Every kept plant of the same mesh and material goes into one MultiMesh. Plants too small to
	# read from the room are left out, and the rest are thinned evenly to FAR_TRIS per world.
	# (A plant's variant meshes (Levels._variants) share one: from the room they cannot be told
	# apart, and one MultiMesh is one draw call.)
	var groups := {}
	var tris := {}
	var total := 0.0
	var first_variant := {}
	for c in _veg_parent.get_children():
		if not (c is MultiMeshInstance3D and c.has_meta("veg_transforms")):
			continue
		var src: MultiMeshInstance3D = c
		var mesh: Mesh = src.multimesh.mesh
		if mesh == null or mesh.get_aabb().get_longest_axis_size() < FAR_MIN_SIZE:
			continue
		if mesh.resource_name == "stem_plant":
			var vk := [mesh.resource_name, src.material_override]
			if not first_variant.has(vk):
				first_variant[vk] = mesh
			mesh = first_variant[vk]
		var key := [mesh, src.material_override]
		if not groups.has(key):
			groups[key] = []
			tris[key] = _mesh_tris(mesh)
		var list: Array = src.get_meta("veg_transforms")
		var into: Array = groups[key]
		var base := src.transform
		for j in range(0, list.size(), keep):
			var x: Transform3D = base * list[j]
			into.append(Transform3D(x.basis.scaled(Vector3.ONE * grow), x.origin))
		total += float(tris[key]) * ceilf(list.size() / float(keep))
	var stride := maxi(1, ceili(total / FAR_TRIS))
	for key in groups:
		var all: Array = groups[key]
		var thin := []
		for j in range(0, all.size(), stride):
			thin.append(all[j])
		groups[key] = thin
	_far_veg = Node3D.new()
	_far_veg.name = "FarVegetation"
	_veg_parent.get_parent().add_child(_far_veg)
	_far_veg.transform = _veg_parent.transform
	for key in groups:
		var picks: Array = groups[key]
		if picks.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = key[0]
		mm.instance_count = picks.size()
		for j in picks.size():
			mm.set_instance_transform(j, picks[j])
		var far := MultiMeshInstance3D.new()
		far.multimesh = mm
		far.material_override = key[1]
		far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_far_veg.add_child(far)


## The far view's triangle budget per world, and the smallest plant it keeps (its mesh's longest
## side, in metres): a whole tank of them costs about what one world's near view does.
const FAR_TRIS := 15000.0
const FAR_MIN_SIZE := 0.45


static func _mesh_tris(mesh: Mesh) -> int:
	var n := 0
	for i in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(i)
		var idx = a[Mesh.ARRAY_INDEX]
		n += (idx.size() if idx != null else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return n


func far_vegetation() -> Node3D:
	return _far_veg


## Fraction of scattered vegetation instances kept visible (thermal scaling).
func set_vegetation_density(f: float) -> void:
	for c in _veg_parent.get_children():
		if c is MultiMeshInstance3D:
			var mm: MultiMesh = c.multimesh
			mm.visible_instance_count = int(mm.instance_count * f) if f < 0.999 else -1
