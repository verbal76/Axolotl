class_name Aquarium
extends Node3D
## The household aquarium and the kid's bedroom around it. Everything here responds
## continuously to total restoration (0..1): water clarity, gravel, ooze, algae, light.

## (World expansion: grown to hold the spread-out, doubled moss balls with about 30 m to the glass.)
const TANK_MIN := Vector3(-290, -110, -260)
const TANK_MAX := Vector3(290, 150, 220)
const FLOOR_Y := -825.0
const ROOM_LAYER := 2
## Collision layer 12: the tank's glass, gravel floor and water surface, which only the Swim Mode
## swimmer (and its camera) collides with (docs/AQUARIUM.md); gameplay never sees it.
const TANK_LAYER_BIT := 1 << 11

const GRIME_TEX := preload("res://assets/textures/grime.png")
const ALGAE_TEX := preload("res://assets/textures/algae_mask.png")
const NOISE := preload("res://assets/textures/noise_rgb.png")

var env: Environment
var sun: DirectionalLight3D
var gravel_mat: ShaderMaterial
## The bedroom round the tank, and the cool light the tank casts into it.
var bedroom: Bedroom
var tank_spill: OmniLight3D
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
## The aquarium experiences' outside views (the room, inspection, Live Tank): the camera is in the
## room, not the water, so the water's haze starts at the glass (depth fog) and the glass lets the
## tank be seen instead of compositing a water column that the camera is not in.
var outside := false
var tank_body: StaticBody3D
var floor_mesh: Mesh
var _fog_saved := {}
## The aquarium light shared by every moss ball's materials (shaders/aquarium_light.gdshaderinc):
## clarity (0 murky .. 1 clear) and the direction toward the ceiling light. Materials made later
## pick these up when their ball registers them.
static var light_params := {"clarity": 0.0, "lamp_dir": Vector3(0.29, 0.95, -0.1)}
var _pushed_clarity := -1.0


func build(p_env: Environment) -> void:
	env = p_env
	_build_light()
	_build_gravel()
	StartupTrace.mark("aquarium: gravel")
	_build_glass()
	_build_surface()
	_build_bubbler()
	_build_snail()
	_build_plants()
	_build_room()
	StartupTrace.mark("aquarium: bedroom and the rest")
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
	RenderingServer.directional_shadow_atlas_set_size(1024, true)
	# Hard-edged sampling: soft filters dither (there is no temporal smoothing on a phone to hide
	# it); the water's haze softens the look instead.
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
	# One shadow map over the near 30 m (QualityScaler shortens it, then turns it off, on a phone
	# that cannot hold its frame rate).
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 30.0
	# Only the selected casters (MossBall.SHADOW_CASTER_LAYER): Gill, parasites, creatures,
	# climbing leaves and stems.
	sun.shadow_caster_mask = MossBall.SHADOW_CASTER_LAYER
	sun.shadow_blur = 0.8
	sun.shadow_bias = 0.1
	sun.shadow_normal_bias = 2.0
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
	_room_light.light_color = Color(1.0, 0.86, 0.68)
	_room_light.light_cull_mask = 1 << (ROOM_LAYER - 1)
	add_child(_room_light)
	var fill := OmniLight3D.new()
	fill.position = Vector3(1400, 400, 1000)
	fill.omni_range = 4000
	fill.light_energy = 1.0
	fill.light_color = Color(0.85, 0.92, 1.0)
	fill.light_cull_mask = 1 << (ROOM_LAYER - 1)
	add_child(fill)


## The floor's height above TANK_MIN.y at (x, z) (docs/AQUARIUM.md): banked up toward the back glass as
## aquascapes are, gently rolling, heaped against the glass, gathered round the plant clumps and the
## bubbler, and dipping where the ooze lies. Everything on the floor stands on this.
static func floor_h(x: float, z: float) -> float:
	if _floor_noise == null:
		_floor_noise = FastNoiseLite.new()
		_floor_noise.seed = 4411
		_floor_noise.frequency = 0.012
		_floor_noise.fractal_octaves = 3
	var back := clampf((TANK_MAX.z - z) / (TANK_MAX.z - TANK_MIN.z), 0.0, 1.0)
	var h := 2.5 + back * back * 13.0
	h += _floor_noise.get_noise_2d(x, z) * 4.0 + _floor_noise.get_noise_2d(x * 4.1 + 300.0, z * 4.1) * 1.1
	# Heaped against the glass.
	var wall := minf(minf(x - TANK_MIN.x, TANK_MAX.x - x), minf(z - TANK_MIN.z, TANK_MAX.z - z))
	h += 3.5 * pow(clampf(1.0 - wall / 16.0, 0.0, 1.0), 2.0)
	for f in FLOOR_FEATURES:
		var d := Vector2(x - f[0], z - f[1]).length()
		var k := clampf(1.0 - d / f[2], 0.0, 1.0)
		h += f[3] * k * k * (3.0 - 2.0 * k)
	return maxf(h, 0.3)


## The floor's surface point at (x, z).
static func floor_point(x: float, z: float) -> Vector3:
	return Vector3(x, TANK_MIN.y + floor_h(x, z), z)


static var _floor_noise: FastNoiseLite
var _hgrid := PackedFloat32Array()
var _hn := Vector2i.ZERO


## The floor as built (bilinear between the grid's heights): what the pebbles sit on.
func _grid_point(x: float, z: float) -> Vector3:
	var fx := clampf((x - TANK_MIN.x) / FLOOR_STEP, 0.0, _hn.x - 1.001)
	var fz := clampf((z - TANK_MIN.z) / FLOOR_STEP, 0.0, _hn.y - 1.001)
	var i := int(fx)
	var j := int(fz)
	var u := fx - i
	var v := fz - j
	var n := _hn.x
	var h := lerpf(lerpf(_hgrid[j * n + i], _hgrid[j * n + i + 1], u), lerpf(_hgrid[(j + 1) * n + i], _hgrid[(j + 1) * n + i + 1], u), v)
	return Vector3(x, TANK_MIN.y + h, z)
## [x, z, radius, height]: gravel heaped round the plant clumps and the bubbler's stone.
const FLOOR_FEATURES := [[175.0, -165.0, 28.0, 4.5], [-200.0, -175.0, 34.0, 4.0], [-205.0, 120.0, 34.0, 4.0], [200.0, 115.0, 34.0, 3.5],
		[60.0, -185.0, 30.0, 3.5], [-80.0, 130.0, 30.0, 3.0]]
const FLOOR_STEP := 4.0
const PEBBLE_TILE := 48.0
## Near-camera 3D pebbles are drawn only this close (the textured floor carries them beyond).
const PEBBLE_RANGE := 100.0
const GRAVEL2_TEX := preload("res://assets/textures/gravel2_albedo.png")
const GRAVEL2_NRM := preload("res://assets/textures/gravel2_normal.png")
const STONE_COLS := [Color(0.4, 0.39, 0.37), Color(0.44, 0.41, 0.36), Color(0.47, 0.41, 0.32), Color(0.35, 0.28, 0.22),
		Color(0.24, 0.23, 0.22), Color(0.3, 0.3, 0.29), Color(0.56, 0.53, 0.48)]
const STONE_WEIGHTS := [0.22, 0.2, 0.16, 0.14, 0.12, 0.12, 0.04]
var pebble_tiles: Array[MultiMeshInstance3D] = []


func _build_gravel() -> void:
	gravel_mat = ShaderMaterial.new()
	gravel_mat.shader = preload("res://shaders/gravel.gdshader")
	gravel_mat.set_shader_parameter("gravel_tex", GRAVEL2_TEX)
	gravel_mat.set_shader_parameter("gravel_nrm", GRAVEL2_NRM)
	gravel_mat.set_shader_parameter("grime_tex", GRIME_TEX)
	pebble_mat = ShaderMaterial.new()
	pebble_mat.shader = gravel_mat.shader
	pebble_mat.set_shader_parameter("gravel_tex", GRAVEL2_TEX)
	pebble_mat.set_shader_parameter("gravel_nrm", GRAVEL2_NRM)
	pebble_mat.set_shader_parameter("grime_tex", GRIME_TEX)
	pebble_mat.set_shader_parameter("pebble", true)
	for m in [gravel_mat, pebble_mat]:
		m.set_shader_parameter("lamp_dir", light_params["lamp_dir"])
	# The floor: a height mesh (real piles, hollows and a bank toward the back).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# (Heights computed once on the grid; normals from the neighbours, and the pebbles placed on
	# the same grid, so startup evaluates the floor once per vertex.)
	var nx := int(ceil((TANK_MAX.x - TANK_MIN.x) / FLOOR_STEP)) + 1
	var nz := int(ceil((TANK_MAX.z - TANK_MIN.z) / FLOOR_STEP)) + 1
	_hgrid = PackedFloat32Array()
	_hgrid.resize(nx * nz)
	_hn = Vector2i(nx, nz)
	for j in nz:
		for i in nx:
			_hgrid[j * nx + i] = floor_h(minf(TANK_MIN.x + i * FLOOR_STEP, TANK_MAX.x), minf(TANK_MIN.z + j * FLOOR_STEP, TANK_MAX.z))
	for j in nz:
		for i in nx:
			var x := minf(TANK_MIN.x + i * FLOOR_STEP, TANK_MAX.x)
			var z := minf(TANK_MIN.z + j * FLOOR_STEP, TANK_MAX.z)
			var i0 := maxi(i - 1, 0)
			var i1 := mini(i + 1, nx - 1)
			var j0 := maxi(j - 1, 0)
			var j1 := mini(j + 1, nz - 1)
			var n := Vector3((_hgrid[j * nx + i0] - _hgrid[j * nx + i1]) / ((i1 - i0) * FLOOR_STEP), 1.0,
					(_hgrid[j0 * nx + i] - _hgrid[j1 * nx + i]) / ((j1 - j0) * FLOOR_STEP)).normalized()
			st.set_normal(n)
			st.set_color(Color.WHITE)
			st.add_vertex(Vector3(x, TANK_MIN.y + _hgrid[j * nx + i], z))
	for j in nz - 1:
		for i in nx - 1:
			var a := j * nx + i
			for q in [a, a + 1, a + nx, a + 1, a + nx + 1, a + nx]:
				st.add_index(q)
	var floor_mi := MeshInstance3D.new()
	floor_mi.name = "GravelFloor"
	floor_mesh = st.commit()
	floor_mi.mesh = floor_mesh
	floor_mi.material_override = gravel_mat
	add_child(floor_mi)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var small := _pebble_mesh(1, 11)
	var big := _pebble_mesh(2, 23)
	# Near-camera pebbles: tiles of instanced pebbles, drawn only within PEBBLE_RANGE (their
	# silhouettes and parallax are what close views need); denser where gravel gathers.
	var tx := int(ceil((TANK_MAX.x - TANK_MIN.x) / PEBBLE_TILE))
	var tz := int(ceil((TANK_MAX.z - TANK_MIN.z) / PEBBLE_TILE))
	for tj in tz:
		for ti in tx:
			var x0 := TANK_MIN.x + ti * PEBBLE_TILE
			var z0 := TANK_MIN.z + tj * PEBBLE_TILE
			for mesh_k in 2:
				var xfs := []
				var cols := []
				var count := 150 if mesh_k == 0 else 40
				for i in count:
					var x := minf(x0 + rng.randf() * PEBBLE_TILE, TANK_MAX.x - 1.5)
					var z := minf(z0 + rng.randf() * PEBBLE_TILE, TANK_MAX.z - 1.5)
					var r := (1.0 + pow(rng.randf(), 2.0) * 1.4) if mesh_k == 0 else (2.2 + pow(rng.randf(), 1.6) * 2.4)
					var sy := rng.randf_range(0.45, 0.75)
					var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3(rng.randf() - 0.5, 0, rng.randf() - 0.5).normalized(), rng.randf() * 0.35)
					basis = basis.scaled(Vector3(r * rng.randf_range(0.9, 1.3), r * sy, r))
					# Partly buried: its middle 10-40% of its height above the surface.
					var p := _grid_point(x, z) + Vector3.UP * r * sy * rng.randf_range(0.1, 0.4)
					xfs.append(Transform3D(basis, p))
					cols.append(_stone_col(rng))
				pebble_tiles.append(_pebble_mm(small if mesh_k == 0 else big, xfs, cols, Vector3(x0 + PEBBLE_TILE * 0.5, TANK_MIN.y, z0 + PEBBLE_TILE * 0.5), PEBBLE_RANGE))
	# Larger stones scattered over the whole floor (drawn from anywhere: they give the whole-tank
	# views their depth), gathering round the plants and the bubbler.
	var sx := []
	var sc := []
	for i in 260:
		var x: float
		var z: float
		if i < 90:
			var f: Array = FLOOR_FEATURES[i % FLOOR_FEATURES.size()]
			var a := rng.randf() * TAU
			var d: float = f[2] * sqrt(rng.randf()) * 0.9
			x = f[0] + cos(a) * d
			z = f[1] + sin(a) * d
		else:
			x = rng.randf_range(TANK_MIN.x + 4, TANK_MAX.x - 4)
			z = rng.randf_range(TANK_MIN.z + 4, TANK_MAX.z - 4)
		x = clampf(x, TANK_MIN.x + 5, TANK_MAX.x - 5)
		z = clampf(z, TANK_MIN.z + 5, TANK_MAX.z - 5)
		var r := 4.0 + pow(rng.randf(), 2.2) * 6.0
		var sy := rng.randf_range(0.5, 0.82)
		var basis := (Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.2, 0.2))).scaled(Vector3(r * rng.randf_range(0.9, 1.35), r * sy, r))
		sx.append(Transform3D(basis, _grid_point(x, z) + Vector3.UP * r * sy * rng.randf_range(0.05, 0.3)))
		sc.append(_stone_col(rng))
	var stones := _pebble_mm(big, sx, sc, Vector3.ZERO, 0.0)
	stones.name = "GravelStones"
	# Pockets of ooze among the gravel; each clears at its own restoration threshold.
	var ooze_mat := StandardMaterial3D.new()
	ooze_mat.albedo_color = Color(0.16, 0.2, 0.08)
	ooze_mat.roughness = 0.15
	ooze_mat.metallic_specular = 0.8
	for i in 34:
		var root := Node3D.new()
		var ox := rng.randf_range(-190, 190)
		var oz := rng.randf_range(-170, 120)
		root.position = floor_point(ox, oz) - Vector3.UP * 0.6
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


func _stone_col(rng: RandomNumberGenerator) -> Color:
	var r := rng.randf()
	var acc := 0.0
	for k in STONE_COLS.size():
		acc += STONE_WEIGHTS[k]
		if r <= acc:
			var c: Color = STONE_COLS[k]
			return c * rng.randf_range(0.85, 1.12)
	return STONE_COLS[0]


func _pebble_mm(mesh: Mesh, xfs: Array, cols: Array, centre: Vector3, range_end: float) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		mm.set_instance_custom_data(i, cols[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = pebble_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if range_end > 0.0:
		# (Its own position is the tile's centre, so the range is measured from there.)
		mmi.position = centre
		for i in xfs.size():
			var xf: Transform3D = xfs[i]
			mm.set_instance_transform(i, Transform3D(xf.basis, xf.origin - centre))
		mmi.visibility_range_end = range_end + PEBBLE_TILE * 0.7
	add_child(mmi)
	return mmi


## A pebble: a subdivided octahedron (`level` 1 or 2) pushed out to a sphere and made lumpy and
## irregular (never a clean ball), unit size. Vertex colour red: 1 on top, darker toward the bottom
## where it sinks into the gravel (contact shading).
func _pebble_mesh(level: int, seed_v: int) -> ArrayMesh:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var verts := [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
	var tris := [[0, 2, 4], [4, 2, 1], [1, 2, 5], [5, 2, 0], [4, 3, 0], [1, 3, 4], [5, 3, 1], [0, 3, 5]]
	for l in level:
		var nt := []
		var mid := {}
		var midpoint := func(a: int, b: int) -> int:
			var key := "%d_%d" % [mini(a, b), maxi(a, b)]
			if mid.has(key):
				return mid[key]
			verts.append(((verts[a] as Vector3) + (verts[b] as Vector3)).normalized())
			mid[key] = verts.size() - 1
			return verts.size() - 1
		for t in tris:
			var ab: int = midpoint.call(t[0], t[1])
			var bc: int = midpoint.call(t[1], t[2])
			var ca: int = midpoint.call(t[2], t[0])
			nt.append_array([[t[0], ab, ca], [ab, t[1], bc], [ca, bc, t[2]], [ab, bc, ca]])
		tris = nt
	var lumps := [Vector3(r.randf() - 0.5, r.randf() - 0.5, r.randf() - 0.5).normalized(), Vector3(r.randf() - 0.5, r.randf() - 0.5, r.randf() - 0.5).normalized()]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in verts:
		var d := (v as Vector3).normalized()
		var k := 1.0 + 0.12 * d.dot(lumps[0]) - 0.1 * absf(d.dot(lumps[1])) + r.randf_range(-0.05, 0.05)
		# A flatter base.
		var p := d * k
		if p.y < -0.3:
			p.y = lerpf(p.y, -0.35, 0.6)
		st.set_color(Color(clampf(0.35 + (p.y + 0.4) * 0.9, 0.35, 1.0), 0, 0))
		st.add_vertex(p)
	# (Godot's front faces wind clockwise seen from outside: the octahedron above is counter-
	# clockwise, so each triangle goes in reversed.)
	for t in tris:
		st.add_index(t[0])
		st.add_index(t[2])
		st.add_index(t[1])
	st.generate_normals()
	return st.commit()


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
	for i in Levels.CENTERS.size():
		for k in 2:
			var side := lamp.cross(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()).normalized()
			# (Clear of the ball itself: a shaft's cone is up to 22 m across where it passes.)
			through.append((Levels.CENTERS[i] as Vector3) + side * (float(Levels.RADII[i]) + rng.randf_range(10.0, 26.0)))
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
	var base := floor_point(175, -165)
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
			var px: float = c.x + rng.randf_range(-22, 22)
			var pz: float = c.z + rng.randf_range(-16, 16)
			var p: Vector3 = floor_point(px, pz) - Vector3.UP * 0.8
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


## The bedroom (Bedroom: a lived-in late-80s / early-90s kid's room round the tank), the cool light
## the tank throws on the things near it, and the incidental legs and hand.
func _build_room() -> void:
	bedroom = Bedroom.new()
	add_child(bedroom)
	bedroom.build(FLOOR_Y, ROOM_LAYER, TANK_MIN, TANK_MAX)
	tank_spill = OmniLight3D.new()
	tank_spill.name = "TankSpill"
	tank_spill.position = Vector3(0, 60, TANK_MAX.z + 140)
	tank_spill.omni_range = 1300.0
	tank_spill.omni_attenuation = 1.4
	tank_spill.light_color = Color(0.55, 0.8, 1.0)
	tank_spill.light_energy = 0.6
	tank_spill.light_cull_mask = 1 << (ROOM_LAYER - 1)
	add_child(tank_spill)
	_build_legs(bedroom)
	_build_hand(bedroom)


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


# --- The aquarium experiences (docs/AQUARIUM.md) -------------------------------------------

## The tank's own collision (the glass, the gravel and the water surface), on TANK_LAYER_BIT only,
## built the first time Swim Mode needs it (never in gameplay, so it costs gameplay nothing).
func ensure_tank_body() -> StaticBody3D:
	if tank_body != null:
		return tank_body
	tank_body = StaticBody3D.new()
	tank_body.name = "TankBody"
	tank_body.collision_layer = TANK_LAYER_BIT
	tank_body.collision_mask = 0
	add_child(tank_body)
	var size := TANK_MAX - TANK_MIN
	var c := (TANK_MIN + TANK_MAX) * 0.5
	var t := 20.0
	# Four panes of glass, and the water's surface as a lid (he swims under it, never out).
	for b in [[Vector3(TANK_MIN.x - t * 0.5, c.y, c.z), Vector3(t, size.y + 60, size.z + 2 * t)],
			[Vector3(TANK_MAX.x + t * 0.5, c.y, c.z), Vector3(t, size.y + 60, size.z + 2 * t)],
			[Vector3(c.x, c.y, TANK_MIN.z - t * 0.5), Vector3(size.x + 2 * t, size.y + 60, t)],
			[Vector3(c.x, c.y, TANK_MAX.z + t * 0.5), Vector3(size.x + 2 * t, size.y + 60, t)],
			[Vector3(c.x, TANK_MAX.y - 1.0 + t * 0.5, c.z), Vector3(size.x + 2 * t, t, size.z + 2 * t)]]:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = b[1]
		cs.shape = bs
		cs.position = b[0]
		tank_body.add_child(cs)
	# The gravel, as drawn (lifted a little: the pebbles and stones on it are not collided with).
	var fs := CollisionShape3D.new()
	fs.shape = floor_mesh.create_trimesh_shape()
	fs.position = Vector3.UP * 1.2
	tank_body.add_child(fs)
	return tank_body


## Switches between the view from the room (true) and the view from inside the water (false).
func set_outside_view(on: bool) -> void:
	if on == outside:
		return
	outside = on
	if on:
		_fog_saved = {"mode": env.fog_mode, "density": env.fog_density}
		env.fog_mode = Environment.FOG_MODE_DEPTH
		env.fog_depth_curve = 1.0
		outside_camera(Vector3(0, 0, TANK_MAX.z + 600.0))
	else:
		env.fog_mode = _fog_saved.get("mode", Environment.FOG_MODE_EXPONENTIAL)
		apply(clean)
	for m in glass_mats:
		m.set_shader_parameter("outside", on)


## Outside views: the water's haze begins at the glass nearest the camera and deepens across the
## tank (murkier water hazes sooner). Called every frame the outside camera moves.
func outside_camera(cam_pos: Vector3) -> void:
	if not outside:
		return
	var near := AABB(TANK_MIN, TANK_MAX - TANK_MIN)
	var q := cam_pos.clamp(near.position, near.end)
	var d := cam_pos.distance_to(q)
	var water := lerpf(0.017, 0.007, ease(clean, 0.8))
	env.fog_depth_begin = d
	env.fog_depth_end = d + 9.0 / water
	env.fog_density = 0.92


## From inside the water the room is seen only through the glass, which lets through less than 8%
## of it beyond ln(0.45 / 0.08) / density (docs/AQUARIUM.md): past that the bedroom is hidden
## (a measured ~8% of the frame in the worlds' views), and shown again nearer the glass, from
## outside the tank, and in the aquarium experiences' views from the room.
var _room_t := 0.0
func _cull_room(dt: float) -> void:
	_room_t -= dt
	if _room_t > 0.0 or bedroom == null:
		return
	_room_t = 0.2
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var p := cam.global_position
	var inside := p.x > TANK_MIN.x and p.x < TANK_MAX.x and p.z > TANK_MIN.z and p.z < TANK_MAX.z and p.y < TANK_MAX.y and p.y > TANK_MIN.y
	var show := true
	if inside and not outside:
		var d_glass := minf(minf(p.x - TANK_MIN.x, TANK_MAX.x - p.x), minf(minf(p.z - TANK_MIN.z, TANK_MAX.z - p.z), TANK_MAX.y - p.y))
		var water := lerpf(0.017, 0.007, ease(clean, 0.8))
		show = d_glass < 1.73 / water
	if bedroom.visible != show:
		bedroom.visible = show


# --- Continuous restoration ---------------------------------------------------------------

func apply(g: float) -> void:
	clean = g
	var e := ease(g, 0.8)
	# Even clear water keeps some haze, so the far glass and the room recede (Expansion 6).
	if not outside:
		env.fog_density = lerpf(0.017, 0.007, e)
	# Healed, the water turns a rich aqua-blue (Expansion 6, owner's art-direction references):
	# cool water and shade against warm light and the vivid life on the moss.
	env.fog_light_color = Color(0.2, 0.26, 0.17).lerp(Color(0.1, 0.4, 0.55), e)
	env.background_color = env.fog_light_color
	env.ambient_light_color = Color(0.45, 0.5, 0.38).lerp(Color(0.54, 0.66, 0.72), e)
	# Healed, the light has a direction (Expansion 6): the ceiling light carries the image and the
	# ambient stays low, so forms model and shade instead of glowing flat.
	env.ambient_light_energy = lerpf(0.55, 0.62, e)
	sun.light_energy = lerpf(0.75, 1.4, e)
	sun.light_color = Color(0.85, 0.92, 0.75).lerp(Color(1.0, 0.96, 0.86), e)
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
	gravel_mat.set_shader_parameter("clarity", e)
	pebble_mat.set_shader_parameter("clarity", e)
	for m in glass_mats:
		m.set_shader_parameter("clean", g)
		m.set_shader_parameter("water_density", lerpf(0.017, 0.007, e))
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
	_cull_room(dt)
	# Snail grazing slowly around the gravel.
	_snail_t += dt * 0.006
	var p := floor_point(cos(_snail_t) * 150.0, sin(_snail_t) * 105.0 - 20.0)
	var p2 := floor_point(cos(_snail_t + 0.01) * 150.0, sin(_snail_t + 0.01) * 105.0 - 20.0)
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
