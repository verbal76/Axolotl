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
var foods: Array = []
var food_spots: Array = []     # burrower holes: {dir, occupied}
var food_regions: Array = []   # {dir, radius_deg}
var food_weights := [0.6, 0.25, 0.15]
var food_target := 7
var blooms: Array = []
var crumbles: Array = []
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
	add_child(mi)
	_surface = mi
	_veg_parent = Node3D.new()
	_veg_parent.name = "Vegetation"
	add_child(_veg_parent)


# --- Materials ---------------------------------------------------------------------------

func register_material(m: ShaderMaterial) -> ShaderMaterial:
	field_materials.append(m)
	# The aquarium light's caustics sample this (vegetation has no other texture).
	if m.get_shader_parameter("noise_tex") == null:
		m.set_shader_parameter("noise_tex", NOISE)
	for k in Aquarium.light_params:
		m.set_shader_parameter(k, Aquarium.light_params[k])
	m.set_shader_parameter("ball_center", global_position if is_inside_tree() else position)
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

## Registers a rolling hill. Register every hill before placing anything on the ball.
func add_hill(dir: Vector3, angular_radius: float, height: float) -> void:
	hills.append([dir.normalized(), angular_radius, height])


## Ground height above the base sphere: a sum of cosine bells, flat at the crest and at the
## foot, so hills blend into each other and into the ball without creases.
func terrain_height(dir: Vector3) -> float:
	var h := 0.0
	for hl in hills:
		var c: float = (hl[0] as Vector3).dot(dir)
		var ang: float = hl[1]
		if c <= cos(ang):
			continue
		var x := acos(minf(c, 1.0)) / ang
		h += float(hl[2]) * (0.5 + 0.5 * cos(PI * x))
	return h


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


## Rebuilds the visible moss surface and adds hill collision once the level is laid out.
## The base sphere collider stays; each hill gets a matching collision patch on top.
func finalize_terrain() -> void:
	if hills.is_empty():
		return
	var seg := 176
	var rings := 88
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	for r in rings + 1:
		var th := PI * r / rings
		for sg in seg + 1:
			var ph := TAU * sg / seg
			var d := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
			var th_h := terrain_height(d)
			verts.append(d * (radius + th_h))
			norms.append(_ground_normal(d) if th_h > 0.0001 else d)
			uvs.append(Vector2(float(sg) / seg, float(r) / rings))
	var idx := PackedInt32Array()
	for r in rings:
		for sg in seg:
			var i00 := r * (seg + 1) + sg
			var i01 := i00 + 1
			var i10 := i00 + seg + 1
			var i11 := i10 + 1
			# Clockwise seen from outside (Godot front faces).
			idx.append_array([i00, i11, i01, i00, i10, i11])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_surface.mesh = am
	for hl in hills:
		_hill_collider(hl[0], hl[1])


## Polar grid over one hill's footprint following the full terrain (so overlaps agree).
func _hill_collider(center: Vector3, ang: float) -> void:
	var k_rings := 14
	var segs := 40
	var e1 := center.cross(Vector3.UP if absf(center.y) < 0.9 else Vector3.RIGHT).normalized()
	var e2 := center.cross(e1)
	var grid: Array = []
	for k in k_rings + 1:
		var r := ang * 1.03 * float(k) / k_rings
		var row := PackedVector3Array()
		for sg in segs:
			var ph := TAU * sg / segs
			var d := (center * cos(r) + (e1 * cos(ph) + e2 * sin(ph)) * sin(r)).normalized()
			row.append(d * ground_radius(d))
		grid.append(row)
	var faces := PackedVector3Array()
	for k in k_rings:
		var a: PackedVector3Array = grid[k]
		var b: PackedVector3Array = grid[k + 1]
		for sg in segs:
			var s1 := (sg + 1) % segs
			faces.append_array([a[sg], b[sg], b[s1], a[sg], b[s1], a[s1]])
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var cs := CollisionShape3D.new()
	cs.shape = shape
	static_body.add_child(cs)


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

func add_heal(dir: Vector3, radius_deg: float, grow_time := 1.2) -> void:
	if heals.size() >= MAX_HEALS:
		# Merge into the smallest splat to stay within the uniform budget.
		var smallest := 0
		for i in heals.size():
			if heal_targets[i] < heal_targets[smallest]:
				smallest = i
		heals.remove_at(smallest)
		heal_targets.remove_at(smallest)
		heal_speed.remove_at(smallest)
	var d := dir.normalized()
	var target := deg_to_rad(radius_deg)
	var start := 0.0 if grow_time > 0.0 else target
	heals.append(Vector4(d.x, d.y, d.z, start))
	heal_targets.append(target)
	heal_speed.append(target / maxf(grow_time, 0.001))
	_heals_dirty = true


## CPU mirror of the shader health function (used by gameplay such as crumbling moss).
func health_at(dir: Vector3) -> float:
	var h := 0.0
	for s in heals:
		var ang := acos(clampf(dir.dot(Vector3(s.x, s.y, s.z)), -1.0, 1.0))
		h = maxf(h, 1.0 - smoothstep(s.w * 0.55, s.w, ang))
	return h


func _process(delta: float) -> void:
	var growing := false
	for i in heals.size():
		var s := heals[i]
		if s.w < heal_targets[i]:
			s.w = minf(heal_targets[i], s.w + heal_speed[i] * delta)
			heals[i] = s
			growing = true
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
	if events_done >= events_total and not completed:
		completed = true
		add_heal(Vector3.UP, 340.0, 0.0)


func zone_health(zone_id: String) -> float:
	var z: Dictionary = zones[zone_id]
	return float(z["done"]) / maxf(1.0, float(z["total"]))


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


## Scatter instanced vegetation over the sphere. `accept` (optional) filters directions.
## Instances are chunked by direction so the far side of the ball is frustum culled.
func scatter(mesh: Mesh, mat: Material, count: int, seed_v: int, scale_min: float, scale_max: float,
		accept: Callable = Callable(), vis_end := 95.0, sink := 0.05) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var buckets := []
	for i in CHUNK_DIRS.size():
		buckets.append([])
	var tries := 0
	var placed := 0
	while placed < count and tries < count * 6:
		tries += 1
		var d := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
		if accept.is_valid() and not accept.call(d):
			continue
		var best := 0
		var best_dot := -2.0
		for i in CHUNK_DIRS.size():
			var dd: float = d.dot((CHUNK_DIRS[i] as Vector3).normalized())
			if dd > best_dot:
				best_dot = dd
				best = i
		var b := frame_at(d, rng.randf() * 360.0)
		var s := rng.randf_range(scale_min, scale_max)
		b = b.scaled(Vector3(s, s, s))
		buckets[best].append(Transform3D(b, d * (radius + terrain_height(d) - sink)))
		placed += 1
	var out := []
	for i in buckets.size():
		var list: Array = buckets[i]
		if list.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = list.size()
		for j in list.size():
			mm.set_instance_transform(j, list[j])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = vis_end
		mmi.visibility_range_end_margin = 10.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		_veg_parent.add_child(mmi)
		out.append(mmi)
	return out


## Adds an instanced vegetation node (Vegetation.field and friends) to this ball's vegetation,
## so it is density-scaled with the rest.
func add_vegetation(node: Node3D) -> void:
	_veg_parent.add_child(node)


## Fraction of scattered vegetation instances kept visible (thermal scaling).
func set_vegetation_density(f: float) -> void:
	for c in _veg_parent.get_children():
		if c is MultiMeshInstance3D:
			var mm: MultiMesh = c.multimesh
			mm.visible_instance_count = int(mm.instance_count * f) if f < 0.999 else -1
