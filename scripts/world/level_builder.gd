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


func _init(p_ball: MossBall, p_game: Node) -> void:
	ball = p_ball
	game = p_game
	root = Node3D.new()
	root.name = "Content"
	ball.add_child(root)


func d(lat: float, lon: float) -> Vector3:
	return MossBall.dir_ll(lat, lon)


func zone(id: String, lat: float, lon: float, radius_deg: float) -> void:
	ball.add_zone(id, d(lat, lon), radius_deg)


func pocket(lat: float, lon: float, radius_deg: float) -> void:
	ball.add_heal(d(lat, lon), radius_deg, 0.0)


# --- Terrain -----------------------------------------------------------------------------

## Rolling moss hill: a partly buried sphere (gentle slopes, cheap sphere collision).
func hill(lat: float, lon: float, rs: float, h: float) -> StaticBody3D:
	var dir := d(lat, lon)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	root.add_child(body)
	body.global_position = ball.surface_point(dir, h - rs)
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = rs
	cs.shape = sh
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = rs
	sm.height = rs * 2.0
	sm.radial_segments = 32
	sm.rings = 16
	mi.mesh = sm
	mi.material_override = ball.moss_material
	body.add_child(mi)
	return body


## Moss cushion: rounded, steep-sided platform. Returns the body; `top` height in meta.
func cushion(lat: float, lon: float, radius: float, height: float, xf_override: Variant = null) -> StaticBody3D:
	var xf: Transform3D = xf_override if xf_override != null else ball.xform_on_dir(d(lat, lon))
	var body := StaticBody3D.new()
	body.collision_layer = 1
	root.add_child(body)
	body.global_transform = xf
	var cs := CollisionShape3D.new()
	var hull := ConvexPolygonShape3D.new()
	hull.points = MeshLib.cushion_hull(radius, height, 1.5)
	cs.shape = hull
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = MeshLib.cushion_mesh(radius, height, 1.5)
	mi.material_override = ball.moss_material
	body.add_child(mi)
	body.set_meta("top", height)
	return body


func stem_xf(xf: Transform3D, height: float, r0: float, r1: float, collide := true, bend := 0.0) -> Node3D:
	var node: Node3D
	if collide:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = (r0 + r1) * 0.5
		cyl.height = height
		cs.shape = cyl
		cs.position = Vector3(0, height * 0.5 - 0.5, 0)
		body.add_child(cs)
		node = body
	else:
		node = Node3D.new()
	root.add_child(node)
	node.global_transform = xf.translated_local(Vector3(0, -0.5, 0))
	var mi := MeshInstance3D.new()
	mi.mesh = MeshLib.stem_mesh(r0, r1, height + 0.5, 9, bend)
	mi.material_override = stem_mat
	mi.visibility_range_end = 140.0
	node.add_child(mi)
	return node


func stem(lat: float, lon: float, height: float, r0: float, r1: float, collide := true) -> Node3D:
	return stem_xf(ball.xform_on_dir(d(lat, lon), 0.0, randf() * 360.0), height, r0, r1, collide)


## Static leaf platform: attached at xf.origin, extending along xf's -Z.
func leaf_xf(xf: Transform3D, length: float, width: float, collide := true) -> Node3D:
	var node: Node3D
	if collide:
		var body := StaticBody3D.new()
		body.collision_layer = 2
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(width * 0.8, 0.25, length * 0.9)
		cs.shape = b
		cs.position = Vector3(0, -0.05, -length * 0.5)
		body.add_child(cs)
		node = body
	else:
		node = Node3D.new()
	root.add_child(node)
	node.global_transform = xf
	var mi := MeshInstance3D.new()
	mi.mesh = MeshLib.platform_leaf_mesh(length, width)
	mi.material_override = leaf_mat
	mi.visibility_range_end = 140.0
	node.add_child(mi)
	return node


func flex_xf(xf: Transform3D, length: float, width: float, bouncy: bool) -> Platforms.FlexLeaf:
	var f := Platforms.FlexLeaf.new()
	root.add_child(f)
	f.build(ball, xf, length, width, leaf_mat, bouncy)
	ball.flex_leaves.append(f)
	return f


func sway_xf(xf: Transform3D, stem_len: float, leaf_len: float, leaf_w: float, amp: float, freq: float, phase: float) -> Platforms.SwayLeaf:
	var s := Platforms.SwayLeaf.new()
	root.add_child(s)
	s.build(ball, xf, stem_len, leaf_len, leaf_w, amp, freq, phase, stem_mat, leaf_mat)
	return s


func crumble_xf(xf: Transform3D, size: Vector3, zone_id: String) -> Platforms.Crumble:
	var c := Platforms.Crumble.new()
	root.add_child(c)
	c.build(ball, xf, size, zone_id)
	ball.crumbles.append(c)
	return c


## Local site frame helper: position relative to (lat, lon, heading) in units.
func at(lat: float, lon: float, heading: float, x: float, y: float, z: float, yaw_deg := 0.0) -> Transform3D:
	var xf := ball.site_xform(lat, lon, heading, Vector3(x, y, z))
	if yaw_deg != 0.0:
		xf.basis = xf.basis * Basis(Vector3.UP, deg_to_rad(yaw_deg))
	return xf


# --- Actors ------------------------------------------------------------------------------

func parasite(kind: int, zone_id: String, lat: float, lon: float, home_deg := 9.0, h := 0.0) -> Parasite:
	var p := Parasite.new()
	p.setup(ball, kind, zone_id, d(lat, lon), home_deg, h)
	ball.add_child(p)
	ball.parasites.append(p)
	return p


func parasite_xf(kind: int, zone_id: String, xf: Transform3D, home_deg := 3.0) -> Parasite:
	var dir := ball.up_at(xf.origin)
	var h := (xf.origin - ball.global_position).length() - ball.radius
	return parasite(kind, zone_id, rad_to_deg(asin(clampf(dir.y, -1, 1))), rad_to_deg(atan2(dir.x, dir.z)), home_deg, h)


func mote(zone_id: String, lat: float, lon: float, h := 0.0, wander := 2.2) -> Mote:
	var m := Mote.new()
	m.setup(ball, zone_id, d(lat, lon), h, wander)
	ball.add_child(m)
	ball.motes.append(m)
	return m


func mote_xf(zone_id: String, xf: Transform3D, wander := 1.2) -> Mote:
	var dir := ball.up_at(xf.origin)
	var h := (xf.origin - ball.global_position).length() - ball.radius
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
	var h := (xf.origin - ball.global_position).length() - ball.radius
	var b := Bloom.new()
	b.setup(ball, dir, h)
	ball.add_child(b)
	ball.blooms.append(b)
	return b


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
		mm.set_instance_transform(i, Transform3D(b, ball.global_position + up * ball.radius - up * 0.1))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = strand_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.top_level = true   # instance transforms are in world space
	root.add_child(mmi)


## Interior moss cave: a hollow mossy dome whose low entrance is hidden behind dense strands.
## Inside: a short optional climb to one permanent health upgrade.
func cave(lat: float, lon: float, heading: float, radius := 8.0) -> void:
	var xf := at(lat, lon, heading, 0, 0, 0)
	var res := MeshLib.dome_shell(radius, 0.9, 0.9, 2.6, 1.8)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	root.add_child(body)
	# Mesh door faces +Z; site forward is -Z, so turn the dome to face its heading.
	body.global_transform = Transform3D(xf.basis * Basis(Vector3.UP, PI), xf.origin)
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
	ball.set_field_param("cave", Vector4(centre.x, centre.y, centre.z, radius * 1.05))
	for m in [ball.moss_material]:
		m.set_shader_parameter("cave", Vector4(centre.x, centre.y, centre.z, radius * 1.05))
	# Hidden entrance: dense strands right in front of the door.
	strands(at(lat, lon, heading, 0, 0, -radius - 0.2), 4.2, 1.6, 2.4, 110, int(lat * 100 + lon))
	# Interior climb: three ledges, the last needing a water burst.
	var l1 := cushion(0, 0, 1.0, 1.2, at(lat, lon, heading, -3.0, 0, 2.5))
	var l2 := cushion(0, 0, 0.85, 2.6, at(lat, lon, heading, -1.0, 0, 4.2))
	var l3 := cushion(0, 0, 0.9, 3.9, at(lat, lon, heading, 3.2, 0, 1.0))
	var up_xf := at(lat, lon, heading, 3.2, 3.9, 1.0)
	var u := Platforms.Upgrade.new()
	var dir := ball.up_at(up_xf.origin)
	u.setup(ball, dir, 3.9)
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
	var rng := RandomNumberGenerator.new()
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
	bot_hints.append({"cave": true, "entry": at(lat, lon, heading, 0, 0, -radius - 2.5).origin, "door": at(lat, lon, heading, 0, 0, -radius + 1.0).origin,
			"ledges": [l1, l2, l3], "upgrade": up_xf.origin})
