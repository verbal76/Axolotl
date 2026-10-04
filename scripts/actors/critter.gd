class_name Critter
extends Node3D
## Base of Expansion 5's creatures (docs/ECOSYSTEM.md). A critter lives on one moss ball in one
## habitat. It never runs on its own: the Ecosystem node ticks it only while the axolotl is on its
## ball and near it (see ACTIVE_RANGE), so distant creatures cost nothing.
##
## Every critter has its own seeded random generator (never the global one gameplay and the test
## bot rely on), a species (discovered once per run when the axolotl sees it up close), and
## optionally a threat id: defeating a guardian or an eel is a completion entry and stays so.
##
## The shared "hittable" interface (hittable, closest_body_point, body_extent, hit) lets the tail
## swipe and hard landings reach any creature that can be struck, as they reach parasites.

## Range from the axolotl within which a critter is ticked.
const ACTIVE_RANGE := 38.0
## Physics layers for standing: terrain and platforms; leaf dwellers add the stem-ladder leaves.
const GROUND_MASK := 1 | 2
const LEAF_MASK := 1 | 2 | 8
## Terrain only: what nothing sees or strikes through.
const SOLID_MASK := 1

var ball: MossBall
var species := ""
var habitat := ""
var rng := RandomNumberGenerator.new()
var active := false
## Completion id earned by defeating it ("" for creatures whose defeat is not an entry).
var threat_id := ""
var hp := 0
var defeated := false
## Distance at which the axolotl discovers the species (and it must be in view: not hidden).
var seen_radius := 6.0


func setup(p_ball: MossBall, p_species: String, p_habitat: String, seed_v: int) -> void:
	ball = p_ball
	species = p_species
	habitat = p_habitat
	rng.seed = seed_v
	ball.critters.append(self)


## Called once by the Ecosystem on the first physics frame after the world is built: anything that
## needs the physics world (rays onto terrain, leaves, cave walls) happens here, not at placement.
func late_place() -> void:
	pass


## Called by the Ecosystem each physics frame while active.
func tick(_dt: float) -> void:
	pass


## Called when the critter becomes active or inactive (for example to stop a sound or reset).
func set_active(on: bool) -> void:
	active = on


## Moving points that bend vegetation: [[pos, radius, velocity, strength], ...].
func wake_points() -> Array:
	return []


func is_hidden() -> bool:
	return defeated or not visible


func discover_point() -> Vector3:
	return global_position


func hittable() -> bool:
	return false


func is_alive() -> bool:
	return not defeated


func closest_body_point(_p: Vector3) -> Vector3:
	return global_position


func body_extent() -> float:
	return 0.3


## Struck by the tail swipe (1 stage) or a hard landing (more). Returns true if it connected.
func hit(_stages: int, _from_pos: Vector3) -> bool:
	return false


## A saved run already defeated it: gone, silently.
func restore_defeated() -> void:
	defeated = true
	visible = false


func player() -> Axolotl:
	return Game.inst.player if Game.inst else null


## True when the axolotl is on this ball in normal play (can be noticed, chased or struck).
func player_here() -> bool:
	var p := player()
	return p != null and p.ball == ball and p.state == "normal"


## Terrain (never leaves or platforms) between a and b.
func line_blocked(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, SOLID_MASK)
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## The standable surface under `pos` (within +up_range / -down_range), or {} if none.
func ground_under(pos: Vector3, mask: int, up_range := 1.2, down_range := 2.0) -> Dictionary:
	var up := ball.up_at(pos)
	var q := PhysicsRayQueryParameters3D.create(pos + up * up_range, pos - up * down_range, mask)
	return get_world_3d().direct_space_state.intersect_ray(q)


## Hurts the axolotl (respecting his invulnerability after a hit).
func strike_player(from_pos: Vector3) -> void:
	var p := player()
	if p != null and p.state == "normal":
		p.take_damage(1, from_pos)


## A simple unshaded-ish material for creature parts.
static func mat(c: Color, emission := Color(0, 0, 0), rough := 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emission != Color(0, 0, 0):
		m.emission_enabled = true
		m.emission = emission
	return m


static func part(mesh: Mesh, material: Material, parent: Node3D, pos := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 60.0
	parent.add_child(mi)
	return mi


## One vertex-coloured mesh from many parts ([mesh, colour, transform]), so a creature costs one
## draw call instead of one per part.
static func merge(parts: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for pr in parts:
		var m: Mesh = pr[0]
		var c: Color = pr[1]
		var xf: Transform3D = pr[2]
		var arr := m.surface_get_arrays(0)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var nb := xf.basis.inverse().transposed()
		var order: Array = idx if idx.size() > 0 else range(v.size())
		for i in order:
			st.set_color(c)
			if nrm.size() > 0:
				st.set_normal((nb * nrm[i]).normalized())
			st.add_vertex(xf * v[i])
	return st.commit()


## The shared material for merged, vertex-coloured creature meshes.
static var _vc_mat: StandardMaterial3D
static var _vc_glow: StandardMaterial3D


static func vc_mat(glow := false) -> StandardMaterial3D:
	if glow:
		if _vc_glow == null:
			_vc_glow = StandardMaterial3D.new()
			_vc_glow.vertex_color_use_as_albedo = true
			_vc_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		return _vc_glow
	if _vc_mat == null:
		_vc_mat = StandardMaterial3D.new()
		_vc_mat.vertex_color_use_as_albedo = true
		_vc_mat.roughness = 0.6
	return _vc_mat


## A MeshInstance3D of a merged mesh.
static func merged_part(parts: Array, parent: Node3D, glow := false) -> MeshInstance3D:
	return part(merge(parts), vc_mat(glow), parent)


static func xf(pos: Vector3, scl := Vector3.ONE) -> Transform3D:
	return Transform3D(Basis().scaled(scl), pos)


static func sphere(r: float, segs := 10) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segs
	s.rings = maxi(4, segs / 2)
	return s
