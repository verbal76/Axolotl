class_name Levels
## Authored content for the three moss balls. Coordinates are (latitude, longitude) on each
## ball; structures that need exact metric layout use a local "site" frame.

const CENTERS := [Vector3(0, 0, 0), Vector3(130, 15, -35), Vector3(-50, 20, -120)]
const RADII := [24.0, 28.0, 30.0]

const PALETTES := [
	{"moss_healthy_a": Color(0.1, 0.34, 0.08), "moss_healthy_b": Color(0.36, 0.66, 0.2),
		"moss_dead_a": Color(0.34, 0.33, 0.3), "moss_dead_b": Color(0.54, 0.52, 0.46)},
	{"moss_healthy_a": Color(0.05, 0.3, 0.16), "moss_healthy_b": Color(0.26, 0.62, 0.36),
		"moss_dead_a": Color(0.33, 0.33, 0.31), "moss_dead_b": Color(0.52, 0.51, 0.47)},
	{"moss_healthy_a": Color(0.05, 0.24, 0.05), "moss_healthy_b": Color(0.3, 0.56, 0.12),
		"moss_dead_a": Color(0.32, 0.31, 0.27), "moss_dead_b": Color(0.5, 0.48, 0.42)},
]


static func build_ball(i: int, game: Node) -> MossBall:
	var b := MossBall.new()
	game.add_child(b)
	b.position = CENTERS[i]
	b.setup(i, RADII[i], PALETTES[i])
	var lb := LevelBuilder.new(b, game)
	match i:
		0: _materials(lb, Color(0.14, 0.36, 0.1), Color(0.42, 0.62, 0.22), Color(0.12, 0.4, 0.1), Color(0.45, 0.78, 0.25))
		1: _materials(lb, Color(0.1, 0.34, 0.16), Color(0.36, 0.6, 0.28), Color(0.08, 0.36, 0.18), Color(0.4, 0.75, 0.35))
		2: _materials(lb, Color(0.12, 0.3, 0.08), Color(0.4, 0.55, 0.18), Color(0.08, 0.34, 0.08), Color(0.42, 0.72, 0.18))
	match i:
		0: _ball1(lb)
		1: _ball2(lb)
		2: _ball3(lb)
	b.set_meta("builder", lb)
	return b


static func _materials(lb: LevelBuilder, stem_a: Color, stem_b: Color, leaf_a: Color, leaf_b: Color) -> void:
	var b := lb.ball
	lb.stem_mat = b.make_plant_material(stem_a, stem_b)
	lb.leaf_mat = b.make_plant_material(leaf_a, leaf_b, {"vein": 1.0})
	lb.shell_mat = b.make_moss_material({"fuzz": 0.0})
	lb.strand_mat = b.make_veg_material(b.palette["moss_healthy_a"], b.palette["moss_healthy_b"], {"sway": 0.08, "impulse_gain": 2.2, "cam_fade": 1.2})


static func _vortex_dir(from_i: int, to_i: int) -> Vector3:
	return (CENTERS[to_i] - CENTERS[from_i]).normalized()


static func _latlon(v: Vector3) -> Vector2:
	return Vector2(rad_to_deg(asin(clampf(v.y, -1, 1))), rad_to_deg(atan2(v.x, v.z)))


static func leaf_mid(xf: Transform3D, along: float, side: float) -> Transform3D:
	return Transform3D(xf.basis, xf * Vector3(side, 0.05, -along))


static func _near_any(dir: Vector3, list: Array) -> bool:
	for e in list:
		if dir.angle_to(e[0]) < deg_to_rad(e[1]):
			return true
	return false


## Tower of cushions with a crumbling brittle-moss bridge leading to a Mote on top.
static func _tower(lb: LevelBuilder, lat: float, lon: float, heading: float, zone: String) -> void:
	lb.cushion(0, 0, 1.2, 1.4, lb.at(lat, lon, heading, 0, 0, 0))
	lb.cushion(0, 0, 1.4, 2.8, lb.at(lat, lon, heading, 0, 0, -2.6))
	lb.crumble_xf(lb.at(lat, lon, heading, 0, 2.9, -5.1), Vector3(1.5, 0.4, 1.5), zone)
	lb.crumble_xf(lb.at(lat, lon, heading, 0, 3.4, -7.1), Vector3(1.5, 0.4, 1.5), zone)
	lb.cushion(0, 0, 1.4, 4.2, lb.at(lat, lon, heading, 0, 0, -10.0))
	lb.mote_xf(zone, lb.at(lat, lon, heading, 0, 4.2, -10.0), 0.7)
	lb.bot_hints.append({"tower": true, "lat": lat, "lon": lon, "heading": heading})


static func _holes(lb: LevelBuilder, n: int, seed_v: int, avoid: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var made := 0
	while made < n:
		var lat := rng.randf_range(-75, 75)
		var lon := rng.randf_range(-180, 180)
		if _near_any(MossBall.dir_ll(lat, lon), avoid):
			continue
		lb.hole(lat, lon)
		made += 1


# =========================================================================================
# MOSS BALL #1 — classic lush marimo (tutorial / baseline)
# =========================================================================================

static func _ball1(lb: LevelBuilder) -> void:
	var b := lb.ball
	b.food_weights = [0.6, 0.25, 0.15]
	b.food_target = 7
	b.start_dir = MossBall.dir_ll(89.5, 0)

	lb.zone("tut", 72, 0, 22)
	lb.zone("meadow", 28, 0, 30)
	lb.zone("east", 12, 95, 44)
	lb.zone("south", -60, 10, 42)
	lb.zone("west", 15, -90, 44)
	lb.zone("under", -30, 180, 52)

	# --- Tutorial: move -> jump -> water burst -> tail swipe -> restore -> bloom.
	lb.cushion(79, 0, 2.0, 1.3)                       # M1: needs a jump
	lb.cushion(57.5, 0, 2.4, 2.9)                     # M2: higher + a gap that needs jump + water burst
	lb.parasite(Parasite.Kind.SMALL, "tut", 59.0, 0, 2.4, 2.9)
	lb.bloom(55.6, 0, 2.9)

	# --- Meadow: rolling hills.
	lb.hill(36, -9, 9.0, 1.6)
	lb.hill(21, 11, 7.0, 1.3)
	lb.hill(31, 22, 8.0, 1.8)
	lb.mote("meadow", 35, -10, 1.6)
	lb.mote("meadow", 19, 14, 1.2)
	lb.parasite(Parasite.Kind.SMALL, "meadow", 27, -3, 8.0)
	lb.parasite(Parasite.Kind.SMALL, "meadow", 16, 6, 8.0)

	# --- East: brittle tower + vortex to Moss Ball #2.
	_tower(lb, 27, 76, 90, "east")
	lb.parasite(Parasite.Kind.MEDIUM, "east", -6, 90, 10.0)
	lb.parasite(Parasite.Kind.SMALL, "east", 12, 120, 9.0)
	lb.mote("east", -9, 112)
	lb.bloom(-1, 88)

	# --- South pole: a large parasite among hills.
	lb.hill(-52, 22, 10.0, 2.0)
	lb.hill(-72, -12, 8.0, 1.5)
	lb.parasite(Parasite.Kind.LARGE, "south", -62, 8, 12.0)
	lb.mote("south", -48, 34)
	lb.mote("south", -74, -24)

	# --- West: hidden interior moss cave.
	lb.cave(26, -104, 90)
	lb.parasite(Parasite.Kind.MEDIUM, "west", 8, -78, 10.0)
	lb.parasite(Parasite.Kind.SMALL, "west", -4, -96, 9.0)
	lb.mote("west", 3, -66)
	lb.mote("west", 14, -84)
	lb.bloom(-2, -74)

	# --- Underside.
	lb.hill(-28, 150, 9.0, 1.8)
	lb.parasite(Parasite.Kind.SMALL, "under", -24, 172, 10.0)
	lb.mote("under", -18, 160)
	lb.mote("under", -42, -162)
	lb.bloom(-34, 176)

	for r in [[28, 0, 30], [12, 95, 35], [15, -90, 35], [-38, 170, 40], [-58, 10, 35]]:
		lb.food_region(r[0], r[1], r[2])
	_holes(lb, 12, 101, [[MossBall.dir_ll(72, 0), 22], [MossBall.dir_ll(26, -104), 14]])

	# Vegetation: soft velvety marimo moss, short plants and broad leaves.
	var veg := b.make_veg_material(Color(0.12, 0.4, 0.1), Color(0.5, 0.8, 0.28), {"sway": 0.1})
	b.scatter(MeshLib.tuft_mesh(5, 0.07, 0.34, 0.12, 1, 3, 0.3), veg, 5200, 11, 0.8, 1.35)
	var veg2 := b.make_veg_material(Color(0.1, 0.36, 0.1), Color(0.35, 0.7, 0.22), {"sway": 0.14})
	b.scatter(MeshLib.broadleaf_mesh(4, 0.7, 2), veg2, 380, 12, 0.7, 1.25)
	b.scatter(MeshLib.tuft_mesh(3, 0.1, 1.7, 0.1, 3, 5, 0.25), veg2, 160, 13, 0.8, 1.3)


# =========================================================================================
# MOSS BALL #2 — current-swept overgrowth
# =========================================================================================

static func _ball2(lb: LevelBuilder) -> void:
	var b := lb.ball
	b.current_axis = Vector3.UP
	b.current_strength = 3.0
	b.food_weights = [0.45, 0.35, 0.2]
	b.food_target = 8
	# Re-create materials now that the current is known.
	for m in b.field_materials:
		m.set_shader_parameter("current_axis", b.current_axis)
		m.set_shader_parameter("current_strength", b.current_strength * 0.35)

	lb.zone("arrive", -5, -75, 32)
	lb.zone("mesa", 15, -20, 30)
	lb.zone("north", 62, 40, 40)
	lb.zone("east", 0, 60, 32)
	lb.zone("south", -55, 0, 42)
	lb.zone("far", -10, 160, 50)

	# Arrival meadow (exposed to the current).
	lb.parasite(Parasite.Kind.SMALL, "arrive", 2, -60, 9.0)
	lb.mote("arrive", -14, -82)
	lb.mote("arrive", 10, -90)
	lb.bloom(5, -67)

	# The mesa: only reachable by riding current-swayed living platforms.
	var S := [15.0, -20.0, 90.0]
	lb.cushion(0, 0, 4.5, 6.3, lb.at(S[0], S[1], S[2], 0, 0, 0))
	var sway_defs := [[11.0, 1.5, 0.35, 0.0], [8.6, 3.1, 0.3, 2.1], [6.3, 4.7, 0.4, 4.2]]
	for sd in sway_defs:
		lb.sway_xf(lb.at(S[0], S[1], S[2], 0, 0, sd[0]), sd[1], 2.3, 1.7, 0.2, sd[2], sd[3])
	lb.parasite_xf(Parasite.Kind.MEDIUM, "mesa", lb.at(S[0], S[1], S[2], 0.8, 6.3, -0.5), 3.5)
	lb.mote_xf("mesa", lb.at(S[0], S[1], S[2], -1.0, 6.3, 0.8), 0.55)
	lb.mote_xf("mesa", lb.at(S[0], S[1], S[2], 1.1, 6.3, -1.2), 0.55)
	lb.bloom_xf(lb.at(S[0], S[1], S[2], 0, 0, 14.0))
	lb.bot_hints.append({"mesa": true, "site": S, "sway": sway_defs})

	# Sheltered north cap + hidden cave.
	lb.cave(72, 110, 200)
	lb.parasite(Parasite.Kind.MEDIUM, "north", 60, 44, 10.0)
	lb.parasite(Parasite.Kind.SMALL, "north", 54, 14, 9.0)
	lb.mote("north", 66, 8)
	lb.mote("north", 50, 55)
	lb.bloom(55, 30)

	# East ridge: large parasite in strong current (knockback carries it downstream).
	lb.hill(2, 58, 8.0, 2.2)
	lb.parasite(Parasite.Kind.LARGE, "east", 2, 58, 11.0, 2.2)
	lb.parasite(Parasite.Kind.SMALL, "east", -9, 72, 9.0)
	lb.mote("east", 11, 70)
	lb.mote("east", -11, 48)

	# South: brittle tower.
	_tower(lb, -48, -34, 150, "south")
	lb.parasite(Parasite.Kind.MEDIUM, "south", -56, -4, 10.0)
	lb.parasite(Parasite.Kind.SMALL, "south", -62, 22, 9.0)
	lb.mote("south", -44, 12)
	lb.bloom(-42, 2)

	# Far side.
	lb.hill(-18, 168, 9.0, 1.8)
	lb.parasite(Parasite.Kind.LARGE, "far", -8, 158, 12.0)
	lb.parasite(Parasite.Kind.MEDIUM, "far", 6, 176, 10.0)
	lb.mote("far", -22, 148)
	lb.mote("far", 0, -168)
	lb.bloom(-4, 146)

	for r in [[-5, -75, 32], [62, 40, 35], [0, 60, 30], [-55, 0, 38], [-10, 160, 45]]:
		lb.food_region(r[0], r[1], r[2])
	_holes(lb, 12, 202, [[MossBall.dir_ll(15, -20), 12], [MossBall.dir_ll(72, 110), 14]])

	# Long flowing grasses bending with the current; broad leaves; tall stems.
	var avoid := [[MossBall.dir_ll(15, -20), 9.0], [_vortex_dir(1, 2), 5.0], [_vortex_dir(1, 0), 5.0]]
	var ok := func(dd: Vector3) -> bool: return not _near_any(dd, avoid)
	var grass := b.make_veg_material(Color(0.07, 0.36, 0.18), Color(0.45, 0.8, 0.32), {"sway": 0.3, "sway_speed": 1.8, "cam_fade": 2.0})
	b.scatter(MeshLib.tuft_mesh(4, 0.1, 3.0, 0.15, 4, 6, 0.2), grass, 2100, 21, 0.7, 1.4, ok)
	var short := b.make_veg_material(Color(0.06, 0.32, 0.16), Color(0.3, 0.66, 0.34), {"sway": 0.12})
	b.scatter(MeshLib.tuft_mesh(5, 0.07, 0.4, 0.12, 5, 3, 0.3), short, 3200, 22, 0.8, 1.3)
	b.scatter(MeshLib.broadleaf_mesh(4, 0.9, 7), short, 260, 23, 1.0, 1.6, ok)
	var rng := RandomNumberGenerator.new()
	rng.seed = 24
	for k in 34:
		var lat := rng.randf_range(-70, 70)
		var lon := rng.randf_range(-180, 180)
		var dd := MossBall.dir_ll(lat, lon)
		if _near_any(dd, avoid + [[MossBall.dir_ll(72, 110), 14.0]]):
			continue
		var h := rng.randf_range(5.0, 9.0)
		lb.stem_xf(b.xform_on_dir(dd, 0.0, rng.randf() * 360.0), h, 0.18, 0.1, false, rng.randf_range(0.02, 0.08))
		lb.leaf_xf(b.xform_on_dir(dd, h - 0.3, rng.randf() * 360.0), rng.randf_range(1.8, 2.8), rng.randf_range(1.2, 1.8), false)


# =========================================================================================
# MOSS BALL #3 — underwater jungle with a traversable canopy
# =========================================================================================

class Site:
	var lb: LevelBuilder
	var lat: float
	var lon: float
	var heading: float
	var R: float

	func _init(p_lb: LevelBuilder, p_lat: float, p_lon: float, p_heading: float) -> void:
		lb = p_lb
		lat = p_lat
		lon = p_lon
		heading = p_heading
		R = p_lb.ball.radius

	## True-distance coordinates at height y, measured from the site's radial axis.
	func p(x: float, y: float, z: float, yaw := 0.0) -> Transform3D:
		var k := R / (R + y)
		return lb.at(lat, lon, heading, x * k, y, z * k, yaw)

	static func yaw_out(dx: float, dz: float) -> float:
		return rad_to_deg(atan2(-dx, -dz))

	## A radial stem whose top (height h) sits at true coordinates (tx, tz).
	func stem_top(tx: float, tz: float, h: float, r0: float, r1: float) -> Node3D:
		var k := R / (R + h)
		return lb.stem_xf(p(tx * k, 0, tz * k), h, r0, r1)

	## Point on a stem (top at tx,tz,h_top) at height y, offset `off` along direction (dx,dz).
	func on_stem(tx: float, tz: float, h_top: float, y: float, dx: float, dz: float, off: float) -> Transform3D:
		var k := (R + y) / (R + h_top)
		return p(tx * k + dx * off, y, tz * k + dz * off, yaw_out(dx, dz))


static func _ball3(lb: LevelBuilder) -> void:
	var b := lb.ball
	b.food_weights = [0.25, 0.3, 0.45]
	b.food_target = 8

	lb.zone("arrive", 0, 65, 32)
	lb.zone("lower", 25, 20, 32)
	lb.zone("canopy", 28, -30, 30)
	lb.zone("drop", 6, -44, 22)
	lb.zone("roots", -40, 0, 42)
	lb.zone("far", -10, 160, 52)

	# --- Arrival clearing.
	lb.parasite(Parasite.Kind.SMALL, "arrive", 6, 50, 9.0)
	lb.mote("arrive", 10, 74)
	lb.mote("arrive", -10, 57)
	lb.bloom(5, 70)

	# --- Canopy structure (site C). x = east, z = south, true distances.
	var C := Site.new(lb, 28, -30, 0)
	C.stem_top(0, 0, 19.0, 1.1, 0.75)
	var spiral := []
	for i in 10:
		var a := deg_to_rad(i * 60.0)
		var h := 1.5 + i * 1.6
		var xf := C.p(cos(a) * 0.9, h, sin(a) * 0.9, Site.yaw_out(cos(a), sin(a)))
		lb.leaf_xf(xf, 3.0, 1.9)
		spiral.append(xf)
	# C1 (canopy bloom), C3 (mote) branch from the giant stem; C1b/C2 from stem S2.
	var c1 := C.p(cos(deg_to_rad(120)) * 0.9, 16.9, sin(deg_to_rad(120)) * 0.9, Site.yaw_out(cos(deg_to_rad(120)), sin(deg_to_rad(120))))
	lb.leaf_xf(c1, 4.5, 3.2)
	var c3 := C.p(cos(deg_to_rad(20)) * 0.9, 16.6, sin(deg_to_rad(20)) * 0.9, Site.yaw_out(cos(deg_to_rad(20)), sin(deg_to_rad(20))))
	lb.leaf_xf(c3, 5.0, 3.0)
	var T2 := Vector2(-6.8, 7.2)
	C.stem_top(T2.x, T2.y, 18.2, 0.9, 0.7)
	var c1b := C.on_stem(T2.x, T2.y, 18.2, 16.4, 0, -1, 0.8)
	lb.leaf_xf(c1b, 3.2, 2.6)
	var c2 := C.on_stem(T2.x, T2.y, 18.2, 17.3, 0, 1, 0.8)
	lb.leaf_xf(c2, 5.2, 3.4)
	# Lower canopy: flexible leaves that catch falls (F1 rebounds modestly).
	var T3 := Vector2(6.0, 1.4)
	C.stem_top(T3.x, T3.y, 8.2, 0.5, 0.35)
	var f1 := lb.flex_xf(C.on_stem(T3.x, T3.y, 8.2, 7.6, -1, 0, 0.45), 3.4, 2.6, true)
	var f2 := lb.flex_xf(C.on_stem(T3.x, T3.y, 8.2, 4.6, 0, 1, 0.4), 3.2, 2.4, false)
	# Hanging roots under the big canopy leaves (visual).
	var root_mat := lb.stem_mat
	for xf in [c1, c2, c3]:
		for k in 5:
			var off := Vector3(randf_range(-1.0, 1.0), 0, -randf_range(1.0, 4.0))
			var top: Vector3 = (xf as Transform3D) * off
			var up := b.up_at(top)
			var len := randf_range(2.5, 6.0)
			var node := Node3D.new()
			lb.root.add_child(node)
			node.global_transform = Transform3D(MossBall.frame_at(up, 0), top - up * len)
			var mi := MeshInstance3D.new()
			mi.mesh = MeshLib.stem_mesh(0.05, 0.03, len, 5)
			mi.material_override = root_mat
			node.add_child(mi)
	lb.parasite_xf(Parasite.Kind.MEDIUM, "canopy", leaf_mid(c2, 3.0, 0.5), 2.2)
	lb.parasite_xf(Parasite.Kind.SMALL, "canopy", leaf_mid(f1._pivot_xf, 2.0, 0.0), 1.2)
	lb.mote_xf("canopy", leaf_mid(c2, 1.8, -0.5), 0.5)
	lb.mote_xf("canopy", leaf_mid(c3, 3.6, 0.0), 0.5)
	lb.mote_xf("canopy", leaf_mid(spiral[4], 2.2, 0.0), 0.6)
	lb.bloom_xf(leaf_mid(c1, 2.6, 0.0))
	lb.bloom_xf(C.p(-2.6, 0, -3.2))

	# --- Drop clearing directly beneath C2's tip (extreme canopy drop).
	var tip := leaf_mid(c2, 6.2, 0.0)
	var tip_up := b.up_at(tip.origin)
	var ground := b.surface_point(tip_up)
	var drop_dir := tip_up
	lb.parasite_xf(Parasite.Kind.LARGE, "drop", Transform3D(Basis(), ground), 2.5)
	lb.parasite_xf(Parasite.Kind.SMALL, "drop", Transform3D(Basis(), b.surface_point(drop_dir.rotated(MossBall.frame_at(drop_dir, 0).x, deg_to_rad(3.5)))), 4.0)
	lb.mote_xf("drop", Transform3D(Basis(), b.surface_point(drop_dir.rotated(MossBall.frame_at(drop_dir, 0).z, deg_to_rad(6.0)))), 1.5)
	lb.bot_hints.append({"canopy": true, "spiral": spiral, "c1": c1, "c1b": c1b, "c2": c2, "c3": c3, "f1": f1, "f2": f2, "drop_dir": drop_dir})

	# --- Lower jungle.
	lb.parasite(Parasite.Kind.MEDIUM, "lower", 24, 26, 9.0)
	lb.parasite(Parasite.Kind.SMALL, "lower", 31, 10, 8.0)
	lb.mote("lower", 19, 31)
	lb.mote("lower", 33, 17)

	# --- Roots + hidden cave.
	lb.cave(-46, 8, 0)
	lb.parasite(Parasite.Kind.MEDIUM, "roots", -32, -12, 10.0)
	lb.parasite(Parasite.Kind.SMALL, "roots", -62, 42, 8.0)
	lb.mote("roots", -28, 6)
	lb.mote("roots", -56, -16)
	lb.bloom(-27, 22)

	# --- Far jungle.
	lb.parasite(Parasite.Kind.LARGE, "far", -10, 160, 12.0)
	lb.parasite(Parasite.Kind.MEDIUM, "far", 10, 176, 10.0)
	lb.mote("far", -25, 150)
	lb.mote("far", 4, -170)
	lb.bloom(-5, 148)

	for r in [[0, 65, 30], [25, 20, 30], [-40, 0, 38], [-10, 160, 45], [8, -60, 25]]:
		lb.food_region(r[0], r[1], r[2])
	_holes(lb, 16, 303, [[MossBall.dir_ll(28, -30), 8], [drop_dir, 6], [MossBall.dir_ll(-46, 8), 14]])

	# --- Dense jungle: towering stems with leaves, tall blades, ferns. Clearings kept open.
	var keep := [[MossBall.dir_ll(28, -30), 16.0], [drop_dir, 9.0], [_vortex_dir(2, 1), 9.0], [MossBall.dir_ll(-46, 8), 18.0],
			[MossBall.dir_ll(5, 70), 4.0], [MossBall.dir_ll(-27, 22), 4.0], [MossBall.dir_ll(-5, 148), 4.0]]
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var made := 0
	while made < 70:
		var lat := rng.randf_range(-78, 78)
		var lon := rng.randf_range(-180, 180)
		var dd := MossBall.dir_ll(lat, lon)
		if _near_any(dd, keep):
			continue
		made += 1
		var h := rng.randf_range(8.0, 20.0)
		lb.stem_xf(b.xform_on_dir(dd, 0.0, rng.randf() * 360.0), h, rng.randf_range(0.35, 0.9), rng.randf_range(0.2, 0.4), true, rng.randf_range(0.0, 0.04))
		# Big overhead leaves obscure the aquarium beyond.
		for k in rng.randi_range(2, 4):
			var y := h * rng.randf_range(0.5, 0.98)
			var xf := b.xform_on_dir(dd, y, rng.randf() * 360.0)
			lb.leaf_xf(xf.translated_local(Vector3(0, 0, -0.3)), rng.randf_range(3.0, 5.5), rng.randf_range(2.0, 3.4), y < 9.0)
	var ok := func(dd: Vector3) -> bool: return not _near_any(dd, keep.slice(0, 4))
	var tall := b.make_veg_material(Color(0.06, 0.3, 0.06), Color(0.4, 0.7, 0.16), {"sway": 0.16, "cam_fade": 2.4})
	b.scatter(MeshLib.tuft_mesh(3, 0.18, 4.2, 0.2, 5, 6, 0.25), tall, 1300, 31, 0.8, 1.4, ok)
	var fern := b.make_veg_material(Color(0.05, 0.28, 0.06), Color(0.3, 0.62, 0.14), {"sway": 0.1, "cam_fade": 1.6})
	b.scatter(MeshLib.broadleaf_mesh(7, 1.4, 6), fern, 520, 32, 1.0, 1.8, ok)
	var short := b.make_veg_material(Color(0.05, 0.26, 0.05), Color(0.3, 0.6, 0.14), {"sway": 0.1})
	b.scatter(MeshLib.tuft_mesh(5, 0.07, 0.4, 0.12, 8, 3, 0.3), short, 3200, 34, 0.8, 1.3)
