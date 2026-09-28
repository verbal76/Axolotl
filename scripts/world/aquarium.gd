class_name Aquarium
extends Node3D
## The household aquarium and the kid's bedroom around it. Everything here responds
## continuously to total restoration (0..1): water clarity, gravel, ooze, algae, light.

const TANK_MIN := Vector3(-232, -110, -202)
const TANK_MAX := Vector3(232, 150, 152)
const FLOOR_Y := -825.0
const ROOM_LAYER := 2

const GRAVEL_TEX := preload("res://assets/textures/gravel.png")
const GRIME_TEX := preload("res://assets/textures/grime.png")
const ALGAE_TEX := preload("res://assets/textures/algae_mask.png")
const NOISE := preload("res://assets/textures/noise_rgb.png")

var env: Environment
var sun: DirectionalLight3D
var gravel_mat: ShaderMaterial
var pebble_mat: ShaderMaterial
var glass_mats: Array[ShaderMaterial] = []
var surface_mat: ShaderMaterial
var shaft_mats: Array[ShaderMaterial] = []
var plant_mat: ShaderMaterial
var ooze: Array = []          # [node, threshold]
var snail: Node3D
var legs: Node3D
var hand: Node3D
var clean := 0.0
var _snail_t := 0.0
var _legs_t := -1.0
var _hand_t := -1.0
var _room_light: OmniLight3D
## Daylight from the bedroom window, through the side glass: only reaches in once the glass is clean.
var window_light: DirectionalLight3D
## The aquarium light shared by every moss ball's materials (shaders/aquarium_light.gdshaderinc):
## clarity (0 murky .. 1 clear) and the direction toward the ceiling light. Materials made later
## pick these up when their ball registers them.
static var light_params := {"clarity": 0.0, "lamp_dir": Vector3(0.29, 0.95, -0.1)}
var _pushed_clarity := -1.0


func build(p_env: Environment) -> void:
	env = p_env
	_build_light()
	_build_gravel()
	_build_glass()
	_build_surface()
	_build_bubbler()
	_build_snail()
	_build_plants()
	_build_room()
	apply(0.0)


func _build_light() -> void:
	sun = DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-72), deg_to_rad(20), 0)
	sun.light_color = Color(0.95, 1.0, 0.92)
	sun.light_energy = 0.9
	# Selective shadows (Expansion 6): terrain, stems, leaves, the axolotl and creatures cast them
	# (grass, particles and effects do not), near the camera only, so big leaves and overhangs
	# shade what is under them.
	sun.shadow_enabled = true
	# A modest map for a phone (set here, not in the project settings, so an update carries it).
	RenderingServer.directional_shadow_atlas_set_size(2048, true)
	# The cheapest soft filter: no noisy sampling (there is no temporal smoothing on a phone).
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW)
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 42.0
	sun.directional_shadow_split_1 = 0.3
	sun.shadow_blur = 0.8
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.2
	sun.light_cull_mask = 0xFFFFF & ~(1 << (ROOM_LAYER - 1))
	add_child(sun)
	light_params["lamp_dir"] = Basis.from_euler(sun.rotation).z.normalized()
	window_light = DirectionalLight3D.new()
	# From the window side of the room (+x), a little from above.
	window_light.rotation = Vector3(deg_to_rad(-16), deg_to_rad(72), 0)
	window_light.light_color = Color(0.72, 0.84, 1.0)
	window_light.light_energy = 0.0
	window_light.shadow_enabled = false
	window_light.light_cull_mask = sun.light_cull_mask
	add_child(window_light)
	_room_light = OmniLight3D.new()
	_room_light.position = Vector3(0, 1250, 1500)
	_room_light.omni_range = 6000
	_room_light.omni_attenuation = 0.4
	_room_light.light_energy = 1.4
	_room_light.light_color = Color(1.0, 0.92, 0.8)
	_room_light.light_cull_mask = 1 << (ROOM_LAYER - 1)
	add_child(_room_light)
	var fill := OmniLight3D.new()
	fill.position = Vector3(1400, 400, 1000)
	fill.omni_range = 4000
	fill.light_energy = 1.0
	fill.light_color = Color(0.85, 0.92, 1.0)
	fill.light_cull_mask = 1 << (ROOM_LAYER - 1)
	add_child(fill)


func _build_gravel() -> void:
	gravel_mat = ShaderMaterial.new()
	gravel_mat.shader = preload("res://shaders/gravel.gdshader")
	gravel_mat.set_shader_parameter("gravel_tex", GRAVEL_TEX)
	gravel_mat.set_shader_parameter("grime_tex", GRIME_TEX)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(TANK_MAX.x - TANK_MIN.x, TANK_MAX.z - TANK_MIN.z)
	pm.subdivide_width = 8
	pm.subdivide_depth = 8
	mi.mesh = pm
	mi.material_override = gravel_mat
	mi.position = Vector3((TANK_MIN.x + TANK_MAX.x) * 0.5, TANK_MIN.y, (TANK_MIN.z + TANK_MAX.z) * 0.5)
	add_child(mi)
	# 3D pebbles for depth.
	pebble_mat = ShaderMaterial.new()
	pebble_mat.shader = preload("res://shaders/gravel.gdshader")
	pebble_mat.set_shader_parameter("gravel_tex", GRAVEL_TEX)
	pebble_mat.set_shader_parameter("grime_tex", GRIME_TEX)
	pebble_mat.set_shader_parameter("tile", 0.35)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 8
	sm.rings = 4
	mm.mesh = sm
	mm.instance_count = 1400
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in mm.instance_count:
		var p := Vector3(rng.randf_range(TANK_MIN.x + 5, TANK_MAX.x - 5), TANK_MIN.y, rng.randf_range(TANK_MIN.z + 5, TANK_MAX.z - 5))
		var s := rng.randf_range(2.5, 5.0)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s * rng.randf_range(0.8, 1.3), s * 0.55, s))
		mm.set_instance_transform(i, Transform3D(b, p))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = pebble_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	# Pockets of ooze among the gravel; each clears at its own restoration threshold.
	var ooze_mat := StandardMaterial3D.new()
	ooze_mat.albedo_color = Color(0.16, 0.2, 0.08)
	ooze_mat.roughness = 0.15
	ooze_mat.metallic_specular = 0.8
	for i in 34:
		var root := Node3D.new()
		root.position = Vector3(rng.randf_range(-190, 190), TANK_MIN.y, rng.randf_range(-170, 120))
		add_child(root)
		for k in rng.randi_range(2, 4):
			var b := MeshInstance3D.new()
			var s := SphereMesh.new()
			s.radius = rng.randf_range(3.0, 7.0)
			s.height = s.radius * 2.0
			s.radial_segments = 12
			s.rings = 6
			b.mesh = s
			b.material_override = ooze_mat
			b.position = Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6))
			b.scale = Vector3(1.0, 0.35, 1.0)
			root.add_child(b)
		ooze.append([root, rng.randf_range(0.03, 0.93)])


func _build_glass() -> void:
	var size := TANK_MAX - TANK_MIN
	var y0 := TANK_MIN.y - 15.0
	var y1 := TANK_MAX.y + 15.0
	var h := y1 - y0
	var cy := (y0 + y1) * 0.5
	var panes := [
		[Vector3(TANK_MIN.x, cy, (TANK_MIN.z + TANK_MAX.z) * 0.5), Vector3(0, PI / 2, 0), Vector2(size.z, h)],
		[Vector3(TANK_MAX.x, cy, (TANK_MIN.z + TANK_MAX.z) * 0.5), Vector3(0, -PI / 2, 0), Vector2(size.z, h)],
		[Vector3((TANK_MIN.x + TANK_MAX.x) * 0.5, cy, TANK_MIN.z), Vector3.ZERO, Vector2(size.x, h)],
		[Vector3((TANK_MIN.x + TANK_MAX.x) * 0.5, cy, TANK_MAX.z), Vector3(0, PI, 0), Vector2(size.x, h)],
	]
	var i := 0
	for p in panes:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = p[2]
		mi.mesh = q
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/glass.gdshader")
		m.set_shader_parameter("algae_tex", ALGAE_TEX)
		m.set_shader_parameter("grime_tex", GRIME_TEX)
		m.set_shader_parameter("scale", Vector2(1.0 + i * 0.13, 0.8 + i * 0.07))
		mi.material_override = m
		mi.position = p[0]
		mi.rotation = p[1]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		glass_mats.append(m)
		i += 1
	# Tank bottom and silicone frame (fog-disabled so they read from the room side too).
	var frame := MeshLib.mat(Color(0.08, 0.08, 0.09), 0.5)
	for x in [TANK_MIN.x, TANK_MAX.x]:
		for z in [TANK_MIN.z, TANK_MAX.z]:
			var c := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(4, h, 4)
			c.mesh = bm
			c.material_override = frame
			c.position = Vector3(x, cy, z)
			add_child(c)
	var rim := MeshInstance3D.new()
	var rb := BoxMesh.new()
	rb.size = Vector3(size.x + 8, 8, size.z + 8)
	rim.mesh = rb
	rim.material_override = frame
	rim.position = Vector3((TANK_MIN.x + TANK_MAX.x) * 0.5, y0 - 4, (TANK_MIN.z + TANK_MAX.z) * 0.5)
	add_child(rim)


func _build_surface() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(TANK_MAX.x - TANK_MIN.x, TANK_MAX.z - TANK_MIN.z)
	pm.flip_faces = true
	mi.mesh = pm
	surface_mat = ShaderMaterial.new()
	surface_mat.shader = preload("res://shaders/water_surface.gdshader")
	surface_mat.set_shader_parameter("noise_tex", NOISE)
	mi.material_override = surface_mat
	mi.position = Vector3((TANK_MIN.x + TANK_MAX.x) * 0.5, TANK_MAX.y, (TANK_MIN.z + TANK_MAX.z) * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# Light shafts from the ceiling light through the surface (Expansion 6): all along the light's
	# direction, a pair passing beside each moss ball (where the axolotl is) and a few in open water.
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var lamp: Vector3 = light_params["lamp_dir"]
	var through := []
	for c in Levels.CENTERS:
		for k in 2:
			var side := lamp.cross(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()).normalized()
			through.append((c as Vector3) + side * rng.randf_range(22.0, 44.0))
	for k in 5:
		through.append(Vector3(rng.randf_range(-190, 190), 0, rng.randf_range(-160, 110)))
	for p in through:
		var s := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = rng.randf_range(4, 8)
		cm.bottom_radius = rng.randf_range(12, 22)
		cm.height = 300
		cm.cap_top = false
		cm.cap_bottom = false
		cm.radial_segments = 12
		s.mesh = cm
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/light_shaft.gdshader")
		m.set_shader_parameter("noise_tex", NOISE)
		s.material_override = m
		# Its axis along the light, crossing the surface above `p`.
		var y_axis := lamp.normalized()
		var x_axis := y_axis.cross(Vector3.FORWARD).normalized()
		var z_axis := x_axis.cross(y_axis).normalized()
		var top: Vector3 = (p as Vector3) + y_axis * (TANK_MAX.y - (p as Vector3).y) / y_axis.y
		s.transform = Transform3D(Basis(x_axis, y_axis, z_axis), top - y_axis * 150.0)
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(s)
		shaft_mats.append(m)


func _build_bubbler() -> void:
	var base := Vector3(175, TANK_MIN.y, -165)
	var stone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 7
	cm.bottom_radius = 8
	cm.height = 9
	stone.mesh = cm
	stone.material_override = MeshLib.mat(Color(0.55, 0.45, 0.42), 0.95)
	stone.position = base + Vector3(0, 4.5, 0)
	add_child(stone)
	var tube := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 1.0
	tm.bottom_radius = 1.0
	tm.height = TANK_MAX.y - TANK_MIN.y + 20
	tube.mesh = tm
	var tmat := MeshLib.mat(Color(0.6, 0.75, 0.7), 0.2)
	tube.material_override = tmat
	tube.position = Vector3(base.x + 12, (TANK_MAX.y + TANK_MIN.y) * 0.5 + 10, TANK_MIN.z + 3)
	add_child(tube)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var q := QuadMesh.new()
	mm.mesh = q
	mm.instance_count = 110
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in mm.instance_count:
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(rng.randf(), rng.randf(), rng.randf())))
	mm.custom_aabb = AABB(base - Vector3(20, 0, 20), Vector3(40, TANK_MAX.y - TANK_MIN.y + 10, 40))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var bm := ShaderMaterial.new()
	bm.shader = preload("res://shaders/bubbles.gdshader")
	bm.set_shader_parameter("base_pos", base + Vector3(0, 9, 0))
	bm.set_shader_parameter("height", TANK_MAX.y - TANK_MIN.y - 9)
	mmi.material_override = bm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	var snd := AudioStreamPlayer3D.new()
	snd.bus = "Ambience"
	if ResourceLoader.exists("res://assets/audio/amb_bubbler.wav"):
		snd.stream = load("res://assets/audio/amb_bubbler.wav")
	snd.position = base + Vector3(0, 60, 0)
	snd.unit_size = 60.0
	snd.max_distance = 400.0
	snd.volume_db = -6.0
	snd.autoplay = true
	add_child(snd)


func _build_snail() -> void:
	snail = Node3D.new()
	add_child(snail)
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 2.4
	cap.height = 14
	body.mesh = cap
	body.rotation = Vector3(PI / 2, 0, 0)
	body.scale = Vector3(1.0, 1.0, 0.55)
	body.position = Vector3(0, 1.4, 0)
	body.material_override = MeshLib.mat(Color(0.75, 0.66, 0.5), 0.6)
	snail.add_child(body)
	var shell_mat := MeshLib.mat(Color(0.55, 0.32, 0.15), 0.4)
	for k in 4:
		var t := MeshInstance3D.new()
		var tm := TorusMesh.new()
		var r := 4.8 - k * 1.1
		tm.inner_radius = r * 0.45
		tm.outer_radius = r
		t.mesh = tm
		t.material_override = shell_mat if k % 2 == 0 else MeshLib.mat(Color(0.8, 0.6, 0.35), 0.4)
		t.rotation = Vector3(0, 0, PI / 2)
		t.position = Vector3(k * 0.5, 6.0 + k * 0.4, 1.5)
		snail.add_child(t)
	for side in [-1.0, 1.0]:
		var e := MeshInstance3D.new()
		var em := CylinderMesh.new()
		em.top_radius = 0.35
		em.bottom_radius = 0.5
		em.height = 4.0
		e.mesh = em
		e.material_override = MeshLib.mat(Color(0.7, 0.62, 0.48), 0.6)
		e.position = Vector3(side * 1.2, 3.2, -7.0)
		e.rotation = Vector3(-0.5, 0, side * 0.3)
		snail.add_child(e)


func _build_plants() -> void:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_lambert;
uniform float health = 0.0;
void vertex() {
	float t = UV.y;
	vec3 base = MODEL_MATRIX[3].xyz;
	VERTEX.x += sin(TIME * 0.8 + base.x * 0.05 + t * 2.0) * t * t * 6.0;
	VERTEX.z += cos(TIME * 0.6 + base.z * 0.05) * t * t * 4.0;
}
void fragment() {
	vec3 sick = vec3(0.35, 0.33, 0.25);
	vec3 ok = mix(vec3(0.12, 0.38, 0.12), vec3(0.4, 0.72, 0.25), UV.y);
	ALBEDO = mix(sick, ok, health) * COLOR.rgb;
	BACKLIGHT = ALBEDO * 0.3;
}
"""
	plant_mat = ShaderMaterial.new()
	plant_mat.shader = sh
	var blade_mesh := MeshLib.tuft_mesh(1, 4.0, 1.0, 0.0, 1, 6, 0.1)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = blade_mesh
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var clusters := [Vector3(-200, 0, -175), Vector3(-205, 0, 120), Vector3(200, 0, 115), Vector3(60, 0, -185), Vector3(-80, 0, 130)]
	var xfs := []
	for c in clusters:
		for i in 22:
			var p: Vector3 = c + Vector3(rng.randf_range(-22, 22), TANK_MIN.y, rng.randf_range(-16, 16))
			var hgt := rng.randf_range(80, 190)
			var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(rng.randf_range(1.5, 2.5), hgt, 1.0))
			xfs.append(Transform3D(b, p))
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = plant_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


# --- Bedroom -----------------------------------------------------------------------------

func _room_mat(c: Color, rough := 0.85, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.disable_fog = true
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


func _box(size: Vector3, pos: Vector3, mat: Material, parent: Node3D = null, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.layers = 1 << (ROOM_LAYER - 1)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else self).add_child(mi)
	return mi


func _build_room() -> void:
	var room := Node3D.new()
	room.name = "Bedroom"
	add_child(room)
	var wall := _room_mat(Color(0.62, 0.72, 0.82))
	var wall2 := _room_mat(Color(0.95, 0.85, 0.62))
	var floor_m := _room_mat(Color(0.55, 0.38, 0.24))
	var ceil_m := _room_mat(Color(0.93, 0.93, 0.9))
	var X0 := -1600.0
	var X1 := 1600.0
	var Z0 := -330.0
	var Z1 := 3100.0
	var Y1 := FLOOR_Y + 2300.0
	_box(Vector3(X1 - X0, 20, Z1 - Z0), Vector3(0, FLOOR_Y - 10, (Z0 + Z1) * 0.5), floor_m, room)
	_box(Vector3(X1 - X0, 20, Z1 - Z0), Vector3(0, Y1, (Z0 + Z1) * 0.5), ceil_m, room)
	_box(Vector3(X1 - X0, Y1 - FLOOR_Y, 20), Vector3(0, (FLOOR_Y + Y1) * 0.5, Z0), wall2, room)
	_box(Vector3(X1 - X0, Y1 - FLOOR_Y, 20), Vector3(0, (FLOOR_Y + Y1) * 0.5, Z1), wall, room)
	_box(Vector3(20, Y1 - FLOOR_Y, Z1 - Z0), Vector3(X0, (FLOOR_Y + Y1) * 0.5, (Z0 + Z1) * 0.5), wall, room)
	_box(Vector3(20, Y1 - FLOOR_Y, Z1 - Z0), Vector3(X1, (FLOOR_Y + Y1) * 0.5, (Z0 + Z1) * 0.5), wall, room)
	# Floorboards.
	for i in 12:
		_box(Vector3(X1 - X0, 2, 6), Vector3(0, FLOOR_Y + 1, Z0 + 280 * i), _room_mat(Color(0.42, 0.28, 0.17)), room)
	# Rug.
	_box(Vector3(1300, 6, 900), Vector3(-100, FLOOR_Y + 3, 1700), _room_mat(Color(0.35, 0.55, 0.75)), room)
	_box(Vector3(1100, 7, 700), Vector3(-100, FLOOR_Y + 4, 1700), _room_mat(Color(0.95, 0.8, 0.35)), room)
	# Tank stand / dresser with drawers.
	var wood := _room_mat(Color(0.8, 0.62, 0.42))
	_box(Vector3(620, 690, 420), Vector3(0, FLOOR_Y + 345, -25), wood, room)
	for i in 3:
		_box(Vector3(560, 190, 10), Vector3(0, FLOOR_Y + 120 + i * 215, 190), _room_mat(Color(0.86, 0.7, 0.5)), room)
		_box(Vector3(80, 18, 20), Vector3(0, FLOOR_Y + 120 + i * 215, 200), _room_mat(Color(0.3, 0.3, 0.32), 0.3), room)
	# Bed.
	_box(Vector3(1000, 300, 1900), Vector3(950, FLOOR_Y + 150, 2100), _room_mat(Color(0.6, 0.45, 0.32)), room)
	_box(Vector3(1020, 140, 1500), Vector3(950, FLOOR_Y + 360, 2300), _room_mat(Color(0.4, 0.75, 0.55)), room)
	_box(Vector3(1030, 80, 700), Vector3(950, FLOOR_Y + 380, 1900), _room_mat(Color(0.95, 0.55, 0.45)), room)
	_box(Vector3(700, 150, 330), Vector3(950, FLOOR_Y + 430, 2900), _room_mat(Color(0.98, 0.98, 0.95)), room)
	_box(Vector3(1000, 900, 60), Vector3(950, FLOOR_Y + 450, 3060), _room_mat(Color(0.55, 0.4, 0.3)), room)
	# Desk with lamp, books and a toy.
	_box(Vector3(900, 40, 550), Vector3(-1150, FLOOR_Y + 720, 1100), wood, room)
	for lx in [-1550, -760]:
		for lz in [860, 1340]:
			_box(Vector3(40, 720, 40), Vector3(lx, FLOOR_Y + 360, lz), wood, room)
	_box(Vector3(60, 400, 60), Vector3(-1350, FLOOR_Y + 940, 1000), _room_mat(Color(0.2, 0.2, 0.22), 0.3), room)
	_box(Vector3(260, 160, 260), Vector3(-1350, FLOOR_Y + 1150, 1000), _room_mat(Color(1.0, 0.9, 0.55), 0.5, 1.8), room)
	var cols := [Color(0.9, 0.3, 0.3), Color(0.3, 0.5, 0.9), Color(0.95, 0.8, 0.2), Color(0.4, 0.8, 0.45), Color(0.7, 0.4, 0.8)]
	for i in 5:
		_box(Vector3(40, 250 - i * 12, 190), Vector3(-1000 + i * 45, FLOOR_Y + 860 - i * 6, 1250), _room_mat(cols[i]), room)
	# Toy dinosaur (simple blocky shapes).
	var dino := _room_mat(Color(0.35, 0.75, 0.35))
	_box(Vector3(220, 110, 90), Vector3(-850, FLOOR_Y + 820, 1000), dino, room)
	_box(Vector3(90, 180, 70), Vector3(-730, FLOOR_Y + 900, 1000), dino, room)
	_box(Vector3(120, 60, 70), Vector3(-680, FLOOR_Y + 990, 1000), dino, room)
	_box(Vector3(160, 40, 40), Vector3(-990, FLOOR_Y + 820, 1000), dino, room, Vector3(0, 0, 0.3))
	# Bookshelf.
	_box(Vector3(80, 1600, 700), Vector3(X0 + 60, FLOOR_Y + 800, 2300), wood, room)
	for s in 5:
		_box(Vector3(300, 20, 700), Vector3(X0 + 150, FLOOR_Y + 150 + s * 330, 2300), wood, room)
		for b in 9:
			_box(Vector3(220, 230 - (b % 3) * 30, 50), Vector3(X0 + 150, FLOOR_Y + 280 + s * 330 - (b % 3) * 15, 2020 + b * 70), _room_mat(cols[(b + s) % 5]), room)
	# Window with daylight.
	_box(Vector3(30, 900, 1000), Vector3(X1 - 15, FLOOR_Y + 1300, 1000), _room_mat(Color(0.95, 0.95, 0.92)), room)
	_box(Vector3(20, 780, 880), Vector3(X1 - 30, FLOOR_Y + 1300, 1000), _room_mat(Color(0.75, 0.9, 1.0), 0.5, 2.2), room)
	_box(Vector3(24, 20, 880), Vector3(X1 - 36, FLOOR_Y + 1300, 1000), _room_mat(Color(0.95, 0.95, 0.92)), room)
	_box(Vector3(24, 780, 20), Vector3(X1 - 36, FLOOR_Y + 1300, 1000), _room_mat(Color(0.95, 0.95, 0.92)), room)
	# Curtains.
	_box(Vector3(40, 1100, 220), Vector3(X1 - 60, FLOOR_Y + 1250, 420), _room_mat(Color(0.9, 0.5, 0.55)), room)
	_box(Vector3(40, 1100, 220), Vector3(X1 - 60, FLOOR_Y + 1250, 1580), _room_mat(Color(0.9, 0.5, 0.55)), room)
	# Door.
	_box(Vector3(820, 2000, 30), Vector3(-500, FLOOR_Y + 1000, Z1 - 20), _room_mat(Color(0.92, 0.9, 0.85)), room)
	_box(Vector3(60, 60, 60), Vector3(-200, FLOOR_Y + 1000, Z1 - 50), _room_mat(Color(0.8, 0.7, 0.3), 0.3), room)
	# Poster behind the tank, a star-lamp and a ball on the floor.
	_box(Vector3(700, 900, 8), Vector3(-80, 350, Z0 + 15), _room_mat(Color(0.2, 0.3, 0.55)), room)
	_box(Vector3(500, 300, 10), Vector3(-80, 450, Z0 + 20), _room_mat(Color(0.95, 0.75, 0.3)), room)
	_box(Vector3(260, 260, 10), Vector3(-200, 150, Z0 + 20), _room_mat(Color(0.4, 0.85, 0.7)), room)
	var ball := MeshInstance3D.new()
	var bs := SphereMesh.new()
	bs.radius = 130
	bs.height = 260
	ball.mesh = bs
	ball.material_override = _room_mat(Color(0.95, 0.35, 0.3))
	ball.position = Vector3(300, FLOOR_Y + 130, 1500)
	ball.layers = 1 << (ROOM_LAYER - 1)
	room.add_child(ball)
	_build_legs(room)
	_build_hand(room)


func _build_legs(room: Node3D) -> void:
	# Incidental: legs passing across the room (never a face, never acknowledging anything).
	legs = Node3D.new()
	legs.visible = false
	room.add_child(legs)
	var jeans := _room_mat(Color(0.2, 0.3, 0.5))
	var sock := _room_mat(Color(0.95, 0.95, 0.95))
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(0, FLOOR_Y + 820, side * 90)
		hip.name = "Hip%d" % int(side)
		legs.add_child(hip)
		_box(Vector3(130, 820, 130), Vector3(0, -410, 0), jeans, hip)
		_box(Vector3(250, 90, 120), Vector3(40, -800, 0), sock, hip)


func _build_hand(room: Node3D) -> void:
	hand = Node3D.new()
	hand.visible = false
	room.add_child(hand)
	var skin := _room_mat(Color(0.93, 0.74, 0.62))
	_box(Vector3(190, 220, 60), Vector3.ZERO, skin, hand)
	for i in 4:
		_box(Vector3(38, 170, 45), Vector3(-72 + i * 48, 190, 0), skin, hand)
	_box(Vector3(40, 130, 45), Vector3(130, 20, 0), skin, hand, Vector3(0, 0, -0.6))


func play_legs() -> void:
	if _legs_t < 0.0:
		_legs_t = 0.0
		legs.visible = true


func play_hand() -> void:
	if _hand_t < 0.0:
		_hand_t = 0.0
		hand.visible = true


# --- Continuous restoration ---------------------------------------------------------------

func apply(g: float) -> void:
	clean = g
	var e := ease(g, 0.8)
	# Even clear water keeps some haze, so the far glass and the room recede (Expansion 6).
	env.fog_density = lerpf(0.017, 0.0055, e)
	env.fog_light_color = Color(0.2, 0.26, 0.17).lerp(Color(0.24, 0.45, 0.52), e)
	env.background_color = env.fog_light_color
	env.ambient_light_color = Color(0.45, 0.5, 0.38).lerp(Color(0.5, 0.7, 0.75), e)
	env.ambient_light_energy = lerpf(0.55, 0.8, e)
	sun.light_energy = lerpf(0.75, 1.2, e)
	sun.light_color = Color(0.85, 0.92, 0.75).lerp(Color(0.97, 1.0, 0.97), e)
	# Clear water and glass: light carries further in, shadows read more crisply, and the window's
	# daylight comes through the side glass.
	sun.shadow_opacity = lerpf(0.4, 0.78, e)
	window_light.light_energy = lerpf(0.0, 0.5, e * e)
	light_params["clarity"] = e
	if absf(e - _pushed_clarity) > 0.004 or (e >= 1.0 and _pushed_clarity < 1.0):
		_pushed_clarity = e
		var gm := Game.inst
		if gm != null:
			for b in gm.balls:
				b.set_field_param("clarity", e)
	gravel_mat.set_shader_parameter("clean", e)
	pebble_mat.set_shader_parameter("clean", e)
	for m in glass_mats:
		m.set_shader_parameter("clean", g)
		m.set_shader_parameter("water_density", env.fog_density)
		m.set_shader_parameter("water_color", env.fog_light_color)
	surface_mat.set_shader_parameter("clean", e)
	for m in shaft_mats:
		m.set_shader_parameter("strength", lerpf(0.018, 0.13, e))
	plant_mat.set_shader_parameter("health", clampf(0.25 + g * 0.9, 0.0, 1.0))
	for o in ooze:
		var s := 1.0 - smoothstep(o[1], o[1] + 0.07, g)
		(o[0] as Node3D).scale = Vector3.ONE * maxf(s, 0.001)
		(o[0] as Node3D).visible = s > 0.01
	WaterFX.inst.murk = 1.0 - e


func _process(dt: float) -> void:
	# Snail grazing slowly around the gravel.
	_snail_t += dt * 0.006
	var p := Vector3(cos(_snail_t) * 150.0, TANK_MIN.y, sin(_snail_t) * 105.0 - 20.0)
	var p2 := Vector3(cos(_snail_t + 0.01) * 150.0, TANK_MIN.y, sin(_snail_t + 0.01) * 105.0 - 20.0)
	snail.position = p
	snail.look_at(p2, Vector3.UP)
	if _legs_t >= 0.0:
		_legs_t += dt
		var k := _legs_t / 6.0
		legs.position = Vector3(lerpf(-1400, 1100, k), 0, 1900)
		var swing := sin(_legs_t * 5.0) * 0.35
		legs.get_node("Hip-1").rotation.z = swing
		legs.get_node("Hip1").rotation.z = -swing
		if k >= 1.0:
			_legs_t = -1.0
			legs.visible = false
	if _hand_t >= 0.0:
		_hand_t += dt
		var k := 0.0
		if _hand_t < 1.8:
			k = smoothstep(0.0, 1.8, _hand_t)
		elif _hand_t < 3.4:
			k = 1.0
		else:
			k = 1.0 - smoothstep(3.4, 5.0, _hand_t)
		hand.position = Vector3(60, -40 + k * 60, lerpf(1200, 205, k))
		if _hand_t > 5.0:
			_hand_t = -1.0
			hand.visible = false
