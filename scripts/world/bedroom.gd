class_name Bedroom
extends Node3D
## The bedroom round Gill's aquarium (docs/AQUARIUM.md): a lived-in late-1980s / early-1990s kid's
## room, slightly chaotic and warm, with the aquarium on its stand as the focal point. Built from
## simple shapes merged into a few meshes (one per material: most parts share one vertex-coloured
## material), so the whole room is a handful of draw calls. Everything is on Aquarium.ROOM_LAYER.
## Original, generic designs only (no brands, characters or logos).
##
## Units are millimetres (the tank is 580 wide). The room runs X -1600..1600, Z -330 (the wall
## behind the tank) .. 3100 (the door), floor FLOOR_Y, ceiling FLOOR_Y + 2300.

const X0 := -1600.0
const X1 := 1600.0
const Z0 := -330.0
const Z1 := 3100.0
const TEX := "res://assets/textures/room/"

var floor_y := -825.0
var y1 := 1475.0
var _mats := {}
var _sts := {}
var _layer := 2
var _r := RandomNumberGenerator.new()
## Where the room view looks from and at (Aquarium experiences).
var view_pos := Vector3(420, 360, 2150)
var view_look := Vector3(0, -60, 0)


func build(p_floor_y: float, layer: int, tank_min: Vector3, tank_max: Vector3) -> void:
	floor_y = p_floor_y
	y1 = floor_y + 2300.0
	_layer = layer
	_r.seed = 1990
	name = "Bedroom"
	_shell()
	_tank_corner(tank_min, tank_max)
	_desk()
	_bed()
	_tv_corner()
	_shelf()
	_floor_things()
	_walls_things(tank_min, tank_max)
	_commit()


# --- Materials and merging ------------------------------------------------------------------

func _mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.disable_fog = true
	m.roughness = 0.85
	match key:
		"vc":
			m.vertex_color_use_as_albedo = true
		"vc_gloss":
			m.vertex_color_use_as_albedo = true
			m.roughness = 0.35
		"vc_glow":
			# Lamps, screens and indicator lights: their own colour at full brightness.
			m.vertex_color_use_as_albedo = true
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		"crt":
			m.albedo_texture = load(TEX + "crt_screen.png")
			m.emission_enabled = true
			m.emission_texture = m.albedo_texture
			m.emission_energy_multiplier = 0.9
			m.roughness = 0.2
		"rug":
			m.albedo_texture = load(TEX + "rug.png")
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.5
		_:
			m.albedo_texture = load(TEX + key + ".png")
			m.vertex_color_use_as_albedo = true
			if key in ["wallpaper", "blanket", "cork"]:
				m.texture_repeat = true
	_mats[key] = m
	return m


func _st(key: String) -> SurfaceTool:
	if not _sts.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_sts[key] = st
	return _sts[key]


func _commit() -> void:
	for key in _sts:
		var st: SurfaceTool = _sts[key]
		var mi := MeshInstance3D.new()
		mi.name = "Room_" + key
		mi.mesh = st.commit()
		mi.material_override = _mat(key)
		mi.layers = 1 << (_layer - 1)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	_sts.clear()


## A quad a-b-c-d (counter-clockwise seen from its front) with UVs uv0..uv3.
func _quad(key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, uv := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]) -> void:
	var st := _st(key)
	var n := (b - a).cross(c - a).normalized()
	# (Godot's front faces wind clockwise: emit a, c, b and a, d, c.)
	for v in [[a, uv[0]], [c, uv[2]], [b, uv[1]], [a, uv[0]], [d, uv[3]], [c, uv[2]]]:
		st.set_normal(n)
		st.set_color(col)
		st.set_uv(v[1])
		st.add_vertex(v[0])


## A box of `size` whose transform is `xf` (centred), each face UV-mapped 0..1 (or by `tile`
## world units when tile > 0).
func box(key: String, size: Vector3, xf: Transform3D, col: Color, tile := 0.0) -> void:
	var h := size * 0.5
	var c := [Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z),
			Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]
	var faces := [[4, 5, 6, 7, Vector2(size.x, size.y)], [1, 0, 3, 2, Vector2(size.x, size.y)], [5, 1, 2, 6, Vector2(size.z, size.y)],
			[0, 4, 7, 3, Vector2(size.z, size.y)], [7, 6, 2, 3, Vector2(size.x, size.z)], [0, 1, 5, 4, Vector2(size.x, size.z)]]
	for f in faces:
		var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		if tile > 0.0:
			var s: Vector2 = f[4] / tile
			uvs = [Vector2(0, s.y), Vector2(s.x, s.y), Vector2(s.x, 0), Vector2(0, 0)]
		_quad(key, xf * c[f[0]], xf * c[f[1]], xf * c[f[2]], xf * c[f[3]], col, uvs)


func bx(key: String, size: Vector3, pos: Vector3, col: Color, rot := Vector3.ZERO) -> void:
	box(key, size, Transform3D(Basis.from_euler(rot), pos), col)


## A cylinder (axis local Y) of radius r0 at the bottom and r1 at the top.
func cyl(key: String, r0: float, r1: float, height: float, xf: Transform3D, col: Color, segs := 12, caps := true) -> void:
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var b0 := Vector3(cos(a0) * r0, -height * 0.5, sin(a0) * r0)
		var b1 := Vector3(cos(a1) * r0, -height * 0.5, sin(a1) * r0)
		var t0 := Vector3(cos(a0) * r1, height * 0.5, sin(a0) * r1)
		var t1 := Vector3(cos(a1) * r1, height * 0.5, sin(a1) * r1)
		_quad(key, xf * b1, xf * b0, xf * t0, xf * t1, col)
		if caps:
			var tc := Vector3(0, height * 0.5, 0)
			var bc := Vector3(0, -height * 0.5, 0)
			_quad(key, xf * tc, xf * t1, xf * t0, xf * tc, col)
			_quad(key, xf * bc, xf * b0, xf * b1, xf * bc, col)


## A draped cloth: a grid over `size` (x by z) at transform xf, heights from a crumple function.
func cloth(key: String, size: Vector2, xf: Transform3D, col: Color, lumps: float, drape_edges := 0.0, n := 14, uv_scale := 1.0) -> void:
	var pts := []
	for j in n + 1:
		for i in n + 1:
			var u := float(i) / n
			var v := float(j) / n
			var x := (u - 0.5) * size.x
			var z := (v - 0.5) * size.y
			var y := lumps * (sin(u * 7.3 + v * 2.1) * 0.5 + sin(u * 3.1 - v * 6.7) * 0.35 + _r.randf_range(-0.15, 0.15))
			# Hanging down over the sides.
			if drape_edges > 0.0:
				var edge := maxf(absf(u - 0.5), absf(v - 0.5)) * 2.0
				y -= smoothstep(0.82, 1.0, edge) * drape_edges
			pts.append([Vector3(x, y, z), Vector2(u * uv_scale, v * uv_scale)])
	for j in n:
		for i in n:
			var a: Array = pts[j * (n + 1) + i]
			var b: Array = pts[j * (n + 1) + i + 1]
			var c: Array = pts[(j + 1) * (n + 1) + i + 1]
			var d: Array = pts[(j + 1) * (n + 1) + i]
			# (Top side up: a, d, c, b is counter-clockwise seen from above.)
			_quad(key, xf * (a[0] as Vector3), xf * (d[0] as Vector3), xf * (c[0] as Vector3), xf * (b[0] as Vector3), col, [a[1], d[1], c[1], b[1]])


func _jit(c: Color, k := 0.06) -> Color:
	return Color(clampf(c.r * _r.randf_range(1.0 - k, 1.0 + k), 0, 1), clampf(c.g * _r.randf_range(1.0 - k, 1.0 + k), 0, 1), clampf(c.b * _r.randf_range(1.0 - k, 1.0 + k), 0, 1))


# --- The room -------------------------------------------------------------------------------

func _shell() -> void:
	var fy := floor_y
	# Floorboards (warm wood, board by board), ceiling, papered walls, skirting.
	var boards := int((Z1 - Z0) / 180.0)
	for i in boards:
		var z := Z0 + 90.0 + i * 180.0
		bx("vc", Vector3(X1 - X0, 20, 176), Vector3(0, fy - 10, z), _jit(Color(0.5, 0.33, 0.2), 0.08))
	bx("vc", Vector3(X1 - X0, 20, Z1 - Z0), Vector3(0, y1, (Z0 + Z1) * 0.5), Color(0.9, 0.89, 0.85))
	var wh := y1 - fy
	# (Warm, slightly faded paper: the pattern's cool blue-grey tinted toward cream.)
	var paper := Color(1.12, 0.98, 0.8)
	box("wallpaper", Vector3(X1 - X0, wh, 20), Transform3D(Basis(), Vector3(0, (fy + y1) * 0.5, Z0)), paper, 500.0)
	box("wallpaper", Vector3(X1 - X0, wh, 20), Transform3D(Basis(), Vector3(0, (fy + y1) * 0.5, Z1)), paper, 500.0)
	box("wallpaper", Vector3(20, wh, Z1 - Z0), Transform3D(Basis(), Vector3(X0, (fy + y1) * 0.5, (Z0 + Z1) * 0.5)), paper, 500.0)
	box("wallpaper", Vector3(20, wh, Z1 - Z0), Transform3D(Basis(), Vector3(X1, (fy + y1) * 0.5, (Z0 + Z1) * 0.5)), paper, 500.0)
	for w in [[Vector3(X1 - X0, 90, 16), Vector3(0, fy + 45, Z0 + 16)], [Vector3(X1 - X0, 90, 16), Vector3(0, fy + 45, Z1 - 16)],
			[Vector3(16, 90, Z1 - Z0), Vector3(X0 + 16, fy + 45, (Z0 + Z1) * 0.5)], [Vector3(16, 90, Z1 - Z0), Vector3(X1 - 16, fy + 45, (Z0 + Z1) * 0.5)]]:
		bx("vc", w[0], w[1], Color(0.93, 0.91, 0.86))
	# A ceiling light (a round glass shade).
	cyl("vc_glow", 220, 180, 60, Transform3D(Basis(), Vector3(0, y1 - 40, 1500)), Color(1.0, 0.95, 0.82), 16)
	# Window with sill and half-open blinds, curtains.
	bx("vc", Vector3(30, 900, 1000), Vector3(X1 - 15, fy + 1300, 1000), Color(0.95, 0.95, 0.92))
	bx("vc_glow", Vector3(20, 780, 880), Vector3(X1 - 30, fy + 1300, 1000), Color(0.62, 0.78, 0.95))
	bx("vc", Vector3(90, 30, 1040), Vector3(X1 - 50, fy + 840, 1000), Color(0.95, 0.95, 0.92))
	for k in 16:
		bx("vc", Vector3(14, 12, 870), Vector3(X1 - 60, fy + 1660 - k * 30, 1000), Color(0.93, 0.91, 0.86), Vector3(0, 0, 0.9))
	for cz in [420.0, 1580.0]:
		cloth("vc", Vector2(1100, 230), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(X1 - 70, fy + 1250, cz)), Color(0.82, 0.42, 0.45), 18.0, 0.0, 10)
	# Door with a handle, and a hook with a jacket.
	bx("vc", Vector3(820, 2000, 30), Vector3(-500, fy + 1000, Z1 - 20), Color(0.9, 0.87, 0.8))
	bx("vc_gloss", Vector3(60, 40, 60), Vector3(-160, fy + 1000, Z1 - 55), Color(0.78, 0.66, 0.3))
	cloth("vc", Vector2(260, 700), Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(-820, fy + 1500, Z1 - 60)), Color(0.2, 0.3, 0.55), 22.0, 0.0, 8)


## The aquarium's stand and hardware: the hood with its light strip, a hang-on filter, the air pump
## and its tubing, cords to a power strip, a fish-food tub and a net.
func _tank_corner(tmin: Vector3, tmax: Vector3) -> void:
	var fy := floor_y
	var sw := tmax.x - tmin.x + 360.0
	var sd := tmax.z - tmin.z + 60.0
	var sz := (tmin.z + tmax.z) * 0.5
	var top := tmin.y - 25.0
	var wood := Color(0.55, 0.36, 0.22)
	# A dresser as the stand: three wide drawers, knobs, a slightly scuffed top.
	bx("vc", Vector3(sw, top - fy, sd), Vector3(0, (fy + top) * 0.5, sz), wood)
	bx("vc", Vector3(sw + 20, 22, sd + 20), Vector3(0, top - 11, sz), wood.lightened(0.08))
	for i in 3:
		var dy := fy + 130.0 + i * 205.0
		bx("vc", Vector3(sw - 60, 180, 10), Vector3(0, dy, sz + sd * 0.5 + 5.0), wood.lightened(0.12))
		for kx in [-sw * 0.25, sw * 0.25]:
			cyl("vc_gloss", 18, 18, 24, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(kx, dy, sz + sd * 0.5 + 20.0)), Color(0.8, 0.7, 0.4), 10)
	# The glass's black plastic rim and the hood (a lid with a light strip under a raised hump).
	var gw := tmax.x - tmin.x
	var gd := tmax.z - tmin.z
	bx("vc_gloss", Vector3(gw + 16, 20, gd + 16), Vector3(0, tmin.y - 10, sz), Color(0.06, 0.06, 0.07))
	bx("vc_gloss", Vector3(gw + 16, 18, gd + 16), Vector3(0, tmax.y + 12, sz), Color(0.06, 0.06, 0.07))
	bx("vc_gloss", Vector3(gw + 10, 26, gd + 10), Vector3(0, tmax.y + 34, sz), Color(0.08, 0.08, 0.09))
	bx("vc_gloss", Vector3(gw - 60, 34, gd * 0.5), Vector3(0, tmax.y + 62, sz - gd * 0.1), Color(0.1, 0.1, 0.11))
	bx("vc_glow", Vector3(gw - 90, 6, 40), Vector3(0, tmax.y + 20, sz), Color(0.8, 0.92, 1.0))
	# Hang-on-back filter at the back right, its intake tube down into the water.
	var fx := tmax.x - 120.0
	bx("vc_gloss", Vector3(150, 190, 80), Vector3(fx, tmax.y - 20, tmin.z - 45), Color(0.12, 0.13, 0.14))
	bx("vc_gloss", Vector3(150, 16, 110), Vector3(fx, tmax.y + 82, tmin.z - 35), Color(0.16, 0.17, 0.18))
	cyl("vc_gloss", 9, 9, 210, Transform3D(Basis(), Vector3(fx - 40, tmax.y - 60, tmin.z + 18)), Color(0.12, 0.13, 0.14), 8)
	# Air pump on the stand, clear tubing up and over the rim, into the tank.
	var pump := Vector3(tmax.x + 105, top + 38, sz + 60)
	bx("vc_gloss", Vector3(130, 70, 90), pump, Color(0.22, 0.26, 0.3))
	bx("vc", Vector3(90, 8, 60), pump + Vector3(0, 38, 0), Color(0.3, 0.34, 0.38))
	var tube := [pump + Vector3(-40, 20, -30), Vector3(tmax.x + 30, top + 120, sz - 100), Vector3(tmax.x + 8, tmax.y + 30, tmin.z + 40), Vector3(tmax.x - 20, tmax.y - 20, tmin.z + 40)]
	for i in tube.size() - 1:
		_tube(tube[i], tube[i + 1], 5.0, Color(0.8, 0.9, 0.9))
	# Fish-food tub and a little net leaning on the tank.
	cyl("vc_gloss", 34, 34, 90, Transform3D(Basis(), Vector3(tmin.x - 100, top + 45, sz + 120)), Color(0.9, 0.55, 0.15), 14)
	cyl("vc", 36, 36, 18, Transform3D(Basis(), Vector3(tmin.x - 100, top + 99, sz + 120)), Color(0.95, 0.9, 0.3), 14)
	_tube(Vector3(tmin.x - 70, top + 5, sz + 180), Vector3(tmin.x - 20, tmax.y + 60, sz + 150), 6.0, Color(0.2, 0.35, 0.8))
	cyl("vc", 55, 55, 6, Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3(tmin.x - 15, tmax.y + 80, sz + 150)), Color(0.85, 0.9, 0.95), 12, false)
	# Cords down the back to a power strip on the floor.
	var strip := Vector3(tmax.x + 120, fy + 20, tmin.z - 20)
	bx("vc", Vector3(320, 40, 70), strip, Color(0.88, 0.86, 0.8))
	bx("vc_glow", Vector3(24, 10, 18), strip + Vector3(-130, 22, 0), Color(1.0, 0.3, 0.2))
	for p in [Vector3(fx, tmax.y - 100, tmin.z - 85), pump + Vector3(60, -20, 0), Vector3(0, tmax.y + 40, tmin.z - 30)]:
		_tube(p, Vector3((p as Vector3).x + 20, fy + 60, tmin.z - 50), 6.0, Color(0.1, 0.1, 0.1))
		_tube(Vector3((p as Vector3).x + 20, fy + 60, tmin.z - 50), strip + Vector3(_r.randf_range(-100, 100), 20, 0), 6.0, Color(0.1, 0.1, 0.1))


func _tube(a: Vector3, b: Vector3, r: float, col: Color) -> void:
	var d := b - a
	var up := d.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	var fwd := side.cross(up)
	cyl("vc_gloss", r, r, d.length(), Transform3D(Basis(side, up, fwd), (a + b) * 0.5), col, 6, false)


## The desk by the left wall: goose-neck lamp, homework, an open notebook, pencils, a cassette
## stack and a portable cassette radio, a chair with a hoodie over it.
func _desk() -> void:
	var fy := floor_y
	var dx := -1180.0
	var dz := 1100.0
	var top := fy + 740.0
	var wood := Color(0.62, 0.45, 0.3)
	bx("vc", Vector3(900, 36, 560), Vector3(dx, top, dz), wood)
	for lx in [dx - 410, dx + 410]:
		for lz in [dz - 240, dz + 240]:
			bx("vc", Vector3(40, 720, 40), Vector3(lx, fy + 360, lz), wood.darkened(0.1))
	bx("vc", Vector3(300, 160, 520), Vector3(dx + 250, top - 110, dz), wood.darkened(0.05))
	# Lamp: base, two-part arm, cone shade (glowing inside).
	cyl("vc_gloss", 70, 80, 30, Transform3D(Basis(), Vector3(dx - 300, top + 32, dz - 170)), Color(0.15, 0.3, 0.6), 14)
	_tube(Vector3(dx - 300, top + 40, dz - 170), Vector3(dx - 250, top + 330, dz - 140), 9.0, Color(0.15, 0.3, 0.6))
	_tube(Vector3(dx - 250, top + 330, dz - 140), Vector3(dx - 120, top + 380, dz - 60), 9.0, Color(0.15, 0.3, 0.6))
	cyl("vc_gloss", 110, 50, 140, Transform3D(Basis(Vector3.FORWARD, 2.2), Vector3(dx - 80, top + 340, dz - 40)), Color(0.15, 0.3, 0.6), 14, false)
	cyl("vc_glow", 30, 30, 30, Transform3D(Basis(), Vector3(dx - 70, top + 300, dz - 40)), Color(1.0, 0.9, 0.6), 10)
	# Homework and notes, an open notebook, pencils.
	box("homework", Vector3(215, 2, 280), Transform3D(Basis(Vector3.UP, 0.25), Vector3(dx + 40, top + 20, dz + 60)), Color.WHITE)
	box("note_paper", Vector3(215, 2, 270), Transform3D(Basis(Vector3.UP, -0.4), Vector3(dx + 260, top + 21, dz - 90)), Color.WHITE)
	bx("vc", Vector3(420, 12, 300), Vector3(dx - 60, top + 24, dz + 90), Color(0.95, 0.94, 0.9), Vector3(0, -0.1, 0))
	bx("vc", Vector3(10, 16, 300), Vector3(dx - 60, top + 30, dz + 90), Color(0.2, 0.3, 0.7), Vector3(0, -0.1, 0))
	for k in 4:
		_tube(Vector3(dx + 130 + k * 22, top + 22, dz + 190), Vector3(dx + 300 + k * 18, top + 22, dz + 120 + k * 10), 5.0, [Color(0.95, 0.8, 0.2), Color(0.9, 0.3, 0.3), Color(0.3, 0.6, 0.9), Color(0.95, 0.8, 0.2)][k])
	# Cassettes: a leaning stack, one out of its case.
	for k in 6:
		box("cassette_labels", Vector3(110, 17, 70), Transform3D(Basis(Vector3.UP, _r.randf_range(-0.25, 0.25)), Vector3(dx + 330, top + 28 + k * 18, dz + 180)), Color(0.9, 0.9, 0.9))
	bx("vc_gloss", Vector3(100, 12, 64), Vector3(dx + 180, top + 25, dz + 230), Color(0.12, 0.12, 0.13), Vector3(0, 0.6, 0))
	# A portable cassette radio: body, two speaker grilles, handle, tape door.
	var bb := Vector3(dx - 280, top + 110, dz + 170)
	bx("vc_gloss", Vector3(380, 190, 110), bb, Color(0.18, 0.18, 0.2))
	for sx in [-120.0, 120.0]:
		cyl("vc", 70, 70, 10, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), bb + Vector3(sx, -10, 58)), Color(0.35, 0.35, 0.38), 16)
		cyl("vc", 28, 28, 12, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), bb + Vector3(sx, -10, 62)), Color(0.12, 0.12, 0.13), 10)
	bx("vc_gloss", Vector3(110, 60, 8), bb + Vector3(0, 20, 58), Color(0.4, 0.42, 0.45))
	_tube(bb + Vector3(-150, 95, 0), bb + Vector3(150, 95, 0), 10.0, Color(0.6, 0.6, 0.62))
	# Chair pulled out, a hoodie over its back.
	var ch := Vector3(dx + 420, fy, dz + 380)
	bx("vc", Vector3(420, 30, 400), ch + Vector3(0, 460, 0), Color(0.3, 0.45, 0.65))
	for cx in [-190, 190]:
		for cz in [-170, 170]:
			bx("vc_gloss", Vector3(24, 460, 24), ch + Vector3(cx, 230, cz), Color(0.7, 0.7, 0.72))
	bx("vc", Vector3(420, 420, 30), ch + Vector3(0, 700, 190), Color(0.3, 0.45, 0.65))
	cloth("vc", Vector2(420, 360), Transform3D(Basis(Vector3.RIGHT, -1.2), ch + Vector3(0, 820, 150)), Color(0.75, 0.2, 0.25), 20.0, 0.0, 8)


## The bed along the right side: frame, headboard, mattress, a rumpled patterned comforter pushed
## half off, a pillow askew, a stuffed toy.
func _bed() -> void:
	var fy := floor_y
	var bxp := 1060.0
	var bz := 2250.0
	bx("vc", Vector3(1000, 300, 1900), Vector3(bxp, fy + 150, bz), Color(0.5, 0.33, 0.22))
	bx("vc", Vector3(1000, 900, 60), Vector3(bxp, fy + 450, bz + 950), Color(0.46, 0.3, 0.2))
	bx("vc", Vector3(950, 150, 1850), Vector3(bxp, fy + 375, bz), Color(0.92, 0.92, 0.95))
	cloth("blanket", Vector2(1080, 1500), Transform3D(Basis(Vector3.UP, 0.06), Vector3(bxp - 40, fy + 470, bz - 120)), Color.WHITE, 38.0, 170.0, 18, 3.0)
	cloth("vc", Vector2(600, 330), Transform3D(Basis(Vector3.UP, 0.18), Vector3(bxp + 60, fy + 500, bz + 700)), Color(0.96, 0.95, 0.9), 50.0, 30.0, 8)
	# A floppy stuffed toy (a green lizard-ish blob) on the pillow.
	var toy := Vector3(bxp - 180, fy + 560, bz + 650)
	cyl("vc", 60, 45, 140, Transform3D(Basis(Vector3.FORWARD, 1.3), toy), Color(0.45, 0.72, 0.4), 10)
	cyl("vc", 45, 30, 70, Transform3D(Basis(), toy + Vector3(-80, 30, 0)), Color(0.45, 0.72, 0.4), 10)
	# Bedside table: an alarm clock with red digits, a glass of water, a comic.
	var bt := Vector3(bxp - 640, fy, bz + 820)
	bx("vc", Vector3(360, 520, 360), bt + Vector3(0, 260, 0), Color(0.55, 0.38, 0.25))
	bx("vc_gloss", Vector3(170, 90, 80), bt + Vector3(-40, 565, 40), Color(0.12, 0.12, 0.13))
	var clock := Label3D.new()
	clock.text = "7:42"
	clock.font_size = 64
	clock.pixel_size = 0.9
	clock.modulate = Color(1.0, 0.18, 0.12)
	clock.outline_size = 0
	clock.shaded = false
	clock.double_sided = false
	clock.layers = 1 << (_layer - 1)
	clock.position = bt + Vector3(-40, 570, 82)
	clock.rotation = Vector3(0, -PI * 0.5 + 0.2, 0)
	add_child(clock)
	cyl("vc_gloss", 30, 34, 110, Transform3D(Basis(), bt + Vector3(100, 575, -60)), Color(0.8, 0.9, 1.0), 12)
	bx("vc", Vector3(170, 8, 250), bt + Vector3(40, 524, -40), Color(0.95, 0.3, 0.25), Vector3(0, 0.4, 0))


## The TV corner: a chunky CRT on a rolling cart with a generic game console, two wired controllers
## trailing onto the rug, cartridges scattered, cables.
func _tv_corner() -> void:
	var fy := floor_y
	var c := Vector3(-1180, fy, 2350)
	bx("vc", Vector3(600, 30, 500), c + Vector3(0, 560, 0), Color(0.2, 0.2, 0.22))
	bx("vc", Vector3(600, 30, 500), c + Vector3(0, 200, 0), Color(0.2, 0.2, 0.22))
	for kx in [-280, 280]:
		for kz in [-230, 230]:
			bx("vc_gloss", Vector3(24, 560, 24), c + Vector3(kx, 290, kz), Color(0.55, 0.55, 0.58))
	# The CRT: deep body, bezel, screen (facing +X, toward the bed), knobs.
	var tv := c + Vector3(0, 800, 0)
	bx("vc_gloss", Vector3(460, 420, 480), tv + Vector3(-40, 0, 0), Color(0.16, 0.16, 0.17))
	bx("vc_gloss", Vector3(60, 460, 520), tv + Vector3(220, 0, 0), Color(0.2, 0.2, 0.21))
	box("crt", Vector3(10, 330, 420), Transform3D(Basis(), tv + Vector3(255, 20, -20)), Color.WHITE)
	for k in 2:
		cyl("vc", 16, 16, 20, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), tv + Vector3(260, -170, 180 - k * 50)), Color(0.5, 0.5, 0.52), 8)
	# Rabbit-ear antenna.
	_tube(tv + Vector3(-40, 210, 0), tv + Vector3(-120, 520, -160), 4.0, Color(0.6, 0.6, 0.62))
	_tube(tv + Vector3(-40, 210, 0), tv + Vector3(20, 540, 150), 4.0, Color(0.6, 0.6, 0.62))
	# Console on the lower shelf: a grey box, a cartridge sticking out, power light.
	var con := c + Vector3(20, 260, 0)
	bx("vc_gloss", Vector3(260, 80, 300), con, Color(0.62, 0.62, 0.64))
	bx("vc", Vector3(120, 70, 30), con + Vector3(0, 70, -40), Color(0.25, 0.25, 0.27))
	bx("vc_glow", Vector3(14, 10, 14), con + Vector3(120, 20, 120), Color(1.0, 0.2, 0.2))
	# Controllers on the floor (flat bodies, a d-pad and two buttons), cords back to the console.
	for k in 2:
		var cp := c + Vector3(560 + k * 140, 18, -120 + k * 260)
		var rot := Basis(Vector3.UP, 0.4 + k * 1.3)
		box("vc_gloss", Vector3(160, 26, 70), Transform3D(rot, cp), Color(0.55, 0.55, 0.58))
		box("vc", Vector3(30, 8, 30), Transform3D(rot, cp + rot * Vector3(-45, 14, 0)), Color(0.1, 0.1, 0.1))
		for b in 2:
			cyl("vc", 9, 9, 8, Transform3D(rot, cp + rot * Vector3(35 + b * 26, 15, 8)), Color(0.8, 0.2, 0.2), 8)
		_tube(cp + rot * Vector3(0, 0, -35), con + Vector3(130, -30, -60 + k * 60), 4.0, Color(0.12, 0.12, 0.12))
	# Cartridges scattered and stacked.
	for k in 5:
		bx("vc", Vector3(110, 18, 120), c + Vector3(420 + _r.randf_range(-80, 200), 10 + (k % 2) * 18, 180 + _r.randf_range(-60, 60)), _jit(Color(0.35, 0.35, 0.38), 0.2), Vector3(0, _r.randf() * TAU, 0))


## A bookshelf by the left wall: books leaning, comics in a stack, keepsakes (a toy dinosaur, a
## trophy, a snow globe, a model rocket).
func _shelf() -> void:
	var fy := floor_y
	var sx := X0 + 170
	var sz := 3000.0 - 420.0
	var wood := Color(0.6, 0.43, 0.28)
	bx("vc", Vector3(320, 1700, 20), Vector3(sx, fy + 850, sz - 350), wood)
	bx("vc", Vector3(320, 1700, 20), Vector3(sx, fy + 850, sz + 350), wood)
	bx("vc", Vector3(20, 1700, 700), Vector3(sx - 150, fy + 850, sz), wood.darkened(0.1))
	var cols := [Color(0.8, 0.25, 0.25), Color(0.25, 0.45, 0.8), Color(0.95, 0.8, 0.25), Color(0.35, 0.7, 0.4), Color(0.6, 0.35, 0.7), Color(0.9, 0.55, 0.2)]
	for s in 5:
		var y := fy + 20 + s * 400
		bx("vc", Vector3(320, 22, 700), Vector3(sx, y, sz), wood)
		if s == 4:
			continue
		var z := sz - 320.0
		while z < sz + 250.0:
			var bw := _r.randf_range(35, 70)
			var bh := _r.randf_range(220, 330)
			var tilt := _r.randf_range(-0.15, 0.15) if _r.randf() < 0.3 else 0.0
			bx("vc", Vector3(230, bh, bw), Vector3(sx + 10, y + 11 + bh * 0.5, z + bw * 0.5), _jit(cols[_r.randi() % cols.size()], 0.15), Vector3(tilt, 0, 0))
			z += bw + 4.0
			if _r.randf() < 0.12:
				z += 120.0
	# Keepsakes on the top shelf.
	var ty := fy + 20 + 4 * 400 + 11
	cyl("vc_gloss", 50, 70, 180, Transform3D(Basis(), Vector3(sx, ty + 90, sz - 200)), Color(0.9, 0.75, 0.25), 12)
	cyl("vc_gloss", 25, 25, 90, Transform3D(Basis(), Vector3(sx, ty + 225, sz - 200)), Color(0.9, 0.75, 0.25), 10)
	cyl("vc_gloss", 90, 90, 40, Transform3D(Basis(), Vector3(sx, ty + 20, sz)), Color(0.35, 0.25, 0.2), 14)
	cyl("vc_gloss", 80, 80, 150, Transform3D(Basis(), Vector3(sx, ty + 115, sz)), Color(0.8, 0.9, 1.0), 14)
	_tube(Vector3(sx, ty, sz + 220), Vector3(sx, ty + 360, sz + 220), 34.0, Color(0.9, 0.9, 0.92))
	cyl("vc", 34, 0.1, 90, Transform3D(Basis(), Vector3(sx, ty + 405, sz + 220)), Color(0.85, 0.2, 0.2), 10)
	# The toy dinosaur on the middle shelf's end.
	var dn := Vector3(sx, fy + 20 + 2 * 400 + 11, sz + 280)
	bx("vc", Vector3(90, 90, 180), dn + Vector3(0, 60, 0), Color(0.35, 0.72, 0.35))
	bx("vc", Vector3(60, 110, 60), dn + Vector3(0, 150, -100), Color(0.35, 0.72, 0.35))
	bx("vc", Vector3(40, 40, 120), dn + Vector3(0, 40, 130), Color(0.35, 0.72, 0.35), Vector3(0.3, 0, 0))
	# Comics in a messy pile on the floor beside it.
	for k in 7:
		bx("vc", Vector3(170, 8, 260), Vector3(sx + 300, fy + 6 + k * 9, sz - 60), _jit(cols[k % cols.size()], 0.2), Vector3(0, _r.randf_range(-0.3, 0.3), 0))


## On the floor: the braided rug, clothes, sneakers, a backpack spilling a notebook, a ball.
func _floor_things() -> void:
	var fy := floor_y
	box("rug", Vector3(1500, 4, 1000), Transform3D(Basis(Vector3.UP, 0.05), Vector3(-40, fy + 3, 1650)), Color.WHITE)
	# Clothes: a t-shirt and jeans in heaps, socks.
	cloth("vc", Vector2(420, 360), Transform3D(Basis(Vector3.UP, 0.7), Vector3(420, fy + 12, 1250)), Color(0.95, 0.85, 0.3), 26.0, 0.0, 8)
	cloth("vc", Vector2(300, 620), Transform3D(Basis(Vector3.UP, -0.5), Vector3(620, fy + 14, 2000)), Color(0.22, 0.32, 0.55), 30.0, 0.0, 8)
	for k in 2:
		cyl("vc", 30, 30, 160, Transform3D(Basis(Vector3.FORWARD, PI * 0.5) * Basis(Vector3.RIGHT, k * 1.2), Vector3(200 + k * 120, fy + 30, 2500 + k * 40)), Color(0.95, 0.95, 0.95), 8)
	# Sneakers (sole, upper, a stripe), one on its side.
	for k in 2:
		var sp := Vector3(520 + k * 170, fy, 2750 - k * 60)
		var rot := Basis(Vector3.UP, 0.3 + k * 0.9) * (Basis(Vector3.FORWARD, 1.3) if k == 1 else Basis())
		box("vc", Vector3(110, 30, 290), Transform3D(rot, sp + rot * Vector3(0, 15, 0)), Color(0.95, 0.95, 0.95))
		box("vc", Vector3(100, 110, 250), Transform3D(rot, sp + rot * Vector3(0, 80, 10)), Color(0.9, 0.25, 0.3))
		box("vc", Vector3(104, 20, 200), Transform3D(rot, sp + rot * Vector3(0, 70, 20)), Color(0.95, 0.95, 0.95))
	# Backpack slumped against the desk, a notebook sliding out.
	var bp := Vector3(-760, fy, 1500)
	box("vc", Vector3(320, 420, 180), Transform3D(Basis(Vector3.FORWARD, -0.2), bp + Vector3(0, 200, 0)), Color(0.2, 0.55, 0.5))
	box("vc", Vector3(260, 180, 60), Transform3D(Basis(Vector3.FORWARD, -0.2), bp + Vector3(20, 130, 110)), Color(0.18, 0.5, 0.45))
	bx("vc", Vector3(210, 10, 280), bp + Vector3(220, 8, 120), Color(0.2, 0.3, 0.75), Vector3(0, 0.5, 0))
	# A ball that rolled under the dresser's corner.
	var ball := MeshInstance3D.new()
	var bs := SphereMesh.new()
	bs.radius = 110
	bs.height = 220
	ball.mesh = bs
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.95, 0.35, 0.3)
	bm.disable_fog = true
	ball.material_override = bm
	ball.position = Vector3(560, fy + 110, 700)
	ball.layers = 1 << (_layer - 1)
	add_child(ball)


## On the walls: the posters flanking the tank, a corkboard with notes and a fish doodle.
func _walls_things(tmin: Vector3, tmax: Vector3) -> void:
	box("poster_space", Vector3(560, 750, 6), Transform3D(Basis(Vector3.FORWARD, 0.02), Vector3(-760, 520, Z0 + 14)), Color.WHITE)
	box("poster_shapes", Vector3(520, 700, 6), Transform3D(Basis(Vector3.FORWARD, -0.03), Vector3(780, 560, Z0 + 14)), Color.WHITE)
	# Corkboard above the desk on the left wall, with notes pinned up.
	var cz := 1100.0
	box("cork", Vector3(12, 520, 760), Transform3D(Basis(), Vector3(X0 + 16, 480, cz)), Color.WHITE)
	box("note_paper", Vector3(4, 280, 220), Transform3D(Basis(Vector3.RIGHT, 0.08) * Basis(Vector3.UP, PI * 0.5), Vector3(X0 + 26, 500, cz - 180)), Color.WHITE)
	box("homework", Vector3(4, 250, 190), Transform3D(Basis(Vector3.RIGHT, -0.1) * Basis(Vector3.UP, PI * 0.5), Vector3(X0 + 26, 460, cz + 170)), Color.WHITE)
	bx("vc", Vector3(4, 120, 160), Vector3(X0 + 26, 650, cz + 20), Color(0.98, 0.9, 0.4), Vector3(0.12, 0, 0))
	for p in [Vector3(X0 + 30, 630, cz - 180), Vector3(X0 + 30, 580, cz + 170), Vector3(X0 + 30, 700, cz + 20)]:
		cyl("vc_gloss", 8, 8, 10, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), p), Color(0.9, 0.2, 0.2), 8)
