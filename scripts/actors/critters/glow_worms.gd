class_name GlowWorms
extends Critter
## A colony of glow-worms on a grotto's ceiling (docs/ECOSYSTEM.md): tiny lights on silk threads
## hanging from the rock. As the axolotl comes near, the nearest ones dim and draw their threads up
## (the shader does it per worm, from his position), and brighten again behind him. Harmless: they
## make caves feel inhabited, and their glow marks the ceiling.

const MAX_WORMS := 48

## Cave centre on the floor and its radius.
var cave_centre := Vector3.ZERO
var cave_radius := 7.0
var count := 0
var _mat: ShaderMaterial


func place(p_ball: MossBall, p_centre: Vector3, p_radius: float, seed_v: int) -> void:
	setup(p_ball, "glowworm", "grotto ceilings", seed_v)
	seen_radius = p_radius
	p_ball.add_child(self)
	cave_centre = p_centre
	cave_radius = p_radius
	global_position = p_centre


func late_place() -> void:
	var p_centre := cave_centre
	var p_radius := cave_radius
	# Worms hang where rays from inside the cave meet its ceiling.
	var up := ball.up_at(p_centre)
	var from := p_centre + up * 2.0
	var space := get_world_3d().direct_space_state
	var xfs: Array[Transform3D] = []
	var tries := 0
	while xfs.size() < MAX_WORMS and tries < MAX_WORMS * 4:
		tries += 1
		var d := (up * rng.randf_range(0.6, 1.0) + MossBall.frame_at(up, rng.randf() * 360.0).z * rng.randf_range(0.0, 0.9)).normalized()
		var q := PhysicsRayQueryParameters3D.create(from, from + d * (p_radius + 4.0), SOLID_MASK)
		q.hit_from_inside = false
		var hit := space.intersect_ray(q)
		# (The cave is one two-sided surface; only hits well above the floor are ceiling.)
		if hit.is_empty() or ball.altitude(hit["position"]) - ball.altitude(p_centre) < 2.2:
			continue
		var at: Vector3 = hit["position"]
		var len := rng.randf_range(0.2, 0.7)
		var fr := MossBall.frame_at(up, rng.randf() * 360.0)
		xfs.append(Transform3D(fr.scaled(Vector3(1.0, len, 1.0)), at - up * 0.02))
	count = xfs.size()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _worm_mesh()
	mm.instance_count = count
	for i in count:
		mm.set_instance_transform(i, xfs[i])
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/glow_worm.gdshader")
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = 50.0
	mmi.top_level = true
	mmi.set_meta("worm_transforms", xfs)
	add_child(mmi)
	_mat.set_shader_parameter("player_pos", Vector3(1e6, 1e6, 1e6))


## A silk thread 1 m long hanging down (-Y, scaled per worm) with a bead of light at its end.
## Vertex colour red marks the bead (1) and the thread (0.25).
static func _worm_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 0.006
	for v in [Vector3(-w, 0, 0), Vector3(w, 0, 0), Vector3(-w, -1, 0), Vector3(w, 0, 0), Vector3(w, -1, 0), Vector3(-w, -1, 0)]:
		st.set_color(Color(0.25, 0, 0))
		st.add_vertex(v)
	var r := 0.025
	var tip := Vector3(0, -1, 0)
	var ring := [Vector3(r, 0, 0), Vector3(0, 0, r), Vector3(-r, 0, 0), Vector3(0, 0, -r)]
	for k in 4:
		var a2: Vector3 = ring[k]
		var b2: Vector3 = ring[(k + 1) % 4]
		for v in [tip + Vector3(0, r * 1.4, 0), tip + a2, tip + b2, tip + a2, tip + Vector3(0, -r * 1.2, 0), tip + b2]:
			st.set_color(Color(1, 0, 0))
			st.add_vertex(v)
	return st.commit()


func tick(_dt: float) -> void:
	if _mat == null:
		return
	var p := player()
	_mat.set_shader_parameter("player_pos", p.body_center() if player_here() else Vector3(1e6, 1e6, 1e6))


func set_active(on: bool) -> void:
	super.set_active(on)
	if not on and _mat:
		_mat.set_shader_parameter("player_pos", Vector3(1e6, 1e6, 1e6))


func discover_point() -> Vector3:
	return cave_centre + ball.up_at(cave_centre) * 2.0
