class_name Levels
## Authored content for the moss balls. Coordinates are (latitude, longitude) on each ball;
## structures that need exact metric layout use a local "site" frame.
##
## The first three balls are the original chain (1 -> 2 -> 3). Expansion 4 adds branches, each
## reached by its own vortex from a ball already in the world (docs/WORLD.md): 4 Terrace Steps (off
## ball 1), 5 Reed Canyon (off 2), 6 Canopy Spire (off 3), 7 Hollow Grotto (off 4).

## (World expansion: the Expansion 4 arrangement spread 1.4x, so the balls can each double in
## radius as they are rebuilt and still keep 35 m or more of water between any two.)
const CENTERS := [Vector3(0, 0, 0), Vector3(182, 21, -49), Vector3(-70, 28, -168),
		Vector3(-14, 35, 154), Vector3(210, -28, 84), Vector3(-224, 42, -84), Vector3(-182, 0, 98)]
const RADII := [48.0, 56.0, 60.0, 36.0, 52.0, 16.0, 22.0]
const NAMES := ["Mossy Meadow", "Current Hollows", "Giant Stems", "Terrace Steps", "Reed Canyon", "Canopy Spire", "Hollow Grotto"]
## Vortex links [from, to]: the original chain first, then the branches. A link opens when its
## "from" ball is 70% restored and then works both ways.
const LINKS := [[0, 1], [1, 2], [0, 3], [1, 4], [2, 5], [3, 6]]

const PALETTES := [
	{"moss_healthy_a": Color(0.1, 0.34, 0.08), "moss_healthy_b": Color(0.36, 0.66, 0.2),
		"moss_dead_a": Color(0.34, 0.33, 0.3), "moss_dead_b": Color(0.54, 0.52, 0.46),
		"stone_a": Color(0.25, 0.2, 0.15), "stone_b": Color(0.47, 0.41, 0.32), "moss_tint": Color(0.44, 0.58, 0.14)},
	{"moss_healthy_a": Color(0.05, 0.3, 0.16), "moss_healthy_b": Color(0.26, 0.62, 0.36),
		"moss_dead_a": Color(0.33, 0.33, 0.31), "moss_dead_b": Color(0.52, 0.51, 0.47),
		"stone_a": Color(0.2, 0.21, 0.21), "stone_b": Color(0.42, 0.44, 0.43), "moss_tint": Color(0.12, 0.5, 0.42)},
	{"moss_healthy_a": Color(0.05, 0.24, 0.05), "moss_healthy_b": Color(0.3, 0.56, 0.12),
		"moss_dead_a": Color(0.32, 0.31, 0.27), "moss_dead_b": Color(0.5, 0.48, 0.42),
		"stone_a": Color(0.19, 0.14, 0.1), "stone_b": Color(0.38, 0.3, 0.22), "moss_tint": Color(0.5, 0.56, 0.1)},
	# 4 Terrace Steps: sunny yellow-green moss on ochre sandstone.
	{"moss_healthy_a": Color(0.2, 0.36, 0.07), "moss_healthy_b": Color(0.58, 0.74, 0.24),
		"moss_dead_a": Color(0.38, 0.35, 0.29), "moss_dead_b": Color(0.6, 0.55, 0.45),
		"stone_a": Color(0.4, 0.3, 0.18), "stone_b": Color(0.7, 0.58, 0.4), "moss_tint": Color(0.66, 0.66, 0.2)},
	# 5 Reed Canyon: deep teal moss on slate.
	{"moss_healthy_a": Color(0.03, 0.25, 0.2), "moss_healthy_b": Color(0.2, 0.58, 0.46),
		"moss_dead_a": Color(0.3, 0.32, 0.33), "moss_dead_b": Color(0.48, 0.51, 0.52),
		"stone_a": Color(0.15, 0.17, 0.21), "stone_b": Color(0.34, 0.38, 0.45), "moss_tint": Color(0.1, 0.45, 0.56)},
	# 6 Canopy Spire: emerald moss on red-brown rock.
	{"moss_healthy_a": Color(0.05, 0.3, 0.1), "moss_healthy_b": Color(0.3, 0.7, 0.28),
		"moss_dead_a": Color(0.35, 0.31, 0.29), "moss_dead_b": Color(0.55, 0.49, 0.45),
		"stone_a": Color(0.3, 0.13, 0.09), "stone_b": Color(0.56, 0.3, 0.21), "moss_tint": Color(0.56, 0.52, 0.1)},
	# 7 Hollow Grotto: cool blue-green moss on dark basalt.
	{"moss_healthy_a": Color(0.04, 0.2, 0.19), "moss_healthy_b": Color(0.24, 0.5, 0.52),
		"moss_dead_a": Color(0.29, 0.29, 0.31), "moss_dead_b": Color(0.46, 0.46, 0.5),
		"stone_a": Color(0.11, 0.1, 0.13), "stone_b": Color(0.3, 0.28, 0.35), "moss_tint": Color(0.3, 0.42, 0.62)},
]


static func build_ball(i: int, game: Node) -> MossBall:
	var b := MossBall.new()
	game.add_child(b)
	b.position = CENTERS[i]
	b.setup(i, RADII[i], PALETTES[i])
	var lb := LevelBuilder.new(b, game)
	b.display_name = NAMES[i]
	match i:
		0: _materials(lb, Color(0.14, 0.36, 0.1), Color(0.42, 0.62, 0.22), Color(0.12, 0.4, 0.1), Color(0.45, 0.78, 0.25))
		1: _materials(lb, Color(0.1, 0.34, 0.16), Color(0.36, 0.6, 0.28), Color(0.08, 0.36, 0.18), Color(0.4, 0.75, 0.35))
		2: _materials(lb, Color(0.12, 0.3, 0.08), Color(0.4, 0.55, 0.18), Color(0.08, 0.34, 0.08), Color(0.42, 0.72, 0.18))
		3: _materials(lb, Color(0.3, 0.34, 0.12), Color(0.6, 0.62, 0.28), Color(0.22, 0.42, 0.1), Color(0.6, 0.8, 0.28))
		4: _materials(lb, Color(0.08, 0.3, 0.26), Color(0.28, 0.56, 0.5), Color(0.05, 0.34, 0.28), Color(0.25, 0.66, 0.55))
		5: _materials(lb, Color(0.26, 0.2, 0.1), Color(0.5, 0.42, 0.22), Color(0.08, 0.36, 0.12), Color(0.36, 0.78, 0.3))
		6: _materials(lb, Color(0.12, 0.2, 0.22), Color(0.3, 0.44, 0.46), Color(0.06, 0.26, 0.26), Color(0.3, 0.58, 0.6))
	match i:
		0: _ball1(lb)
		1: _ball2(lb)
		2: _ball3(lb)
		3: WorldExpansion.terrace_steps(lb)
		4: WorldExpansion.reed_canyon(lb)
		5: WorldExpansion.canopy_spire(lb)
		6: WorldExpansion.hollow_grotto(lb)
	_accent_flora(lb, i)
	_sprouts(lb, i)
	b.finalize_terrain()
	# Selective shadows: the climbing leaves and the stems cast; formations and ground do not.
	# The detailed climbing leaves cast through a flat stand-in (a few triangles per leaf).
	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for n in lb.root.get_children():
		if n is Platforms.FlexLeaf or n is Platforms.SwayLeaf:
			MossBall.mark_caster(n)
		elif n is Platforms.Crumble or str(n.get_meta("grounded", "")) == "stem":
			MossBall.mark_caster(n)
			if n.has_meta("leaves"):
				_leaf_shadow(n, shadow_mat)
		elif n.has_meta("leaves"):
			_leaf_shadow(n, shadow_mat)
	b.set_meta("builder", lb)
	return b


## Each ball's accent colours (Expansion 6): tube corals and anemones that are grey and dead in the
## neglected tank and bloom into vivid colour as the moss round them is healed. [base, tip] pairs.
const ACCENTS := [
	[[Color(0.8, 0.25, 0.42), Color(1.0, 0.72, 0.8)], [Color(0.9, 0.62, 0.12), Color(1.0, 0.9, 0.45)]],
	[[Color(0.95, 0.4, 0.2), Color(1.0, 0.75, 0.5)], [Color(0.45, 0.25, 0.75), Color(0.8, 0.62, 1.0)]],
	[[Color(0.75, 0.2, 0.6), Color(1.0, 0.6, 0.9)], [Color(0.95, 0.55, 0.1), Color(1.0, 0.85, 0.35)]],
	[[Color(0.95, 0.72, 0.15), Color(1.0, 0.95, 0.6)], [Color(0.95, 0.38, 0.32), Color(1.0, 0.7, 0.6)]],
	[[Color(0.5, 0.28, 0.8), Color(0.85, 0.7, 1.0)], [Color(0.15, 0.7, 0.75), Color(0.6, 0.98, 0.95)]],
	[[Color(0.95, 0.5, 0.15), Color(1.0, 0.8, 0.45)], [Color(0.9, 0.3, 0.5), Color(1.0, 0.7, 0.8)]],
	[[Color(0.35, 0.35, 0.85), Color(0.7, 0.75, 1.0)], [Color(0.2, 0.75, 0.7), Color(0.7, 1.0, 0.9)]],
]


## Stem-plant tips per ball (Expansion 6, owner reference "a sprouted moss ball"): most ends red to
## orange, some deep red or pink, like Rotala crowning the moss.
const SPROUT_TIPS := [Color(0.95, 0.4, 0.14), Color(0.85, 0.18, 0.2), Color(1.0, 0.5, 0.25), Color(0.9, 0.3, 0.45),
		Color(0.95, 0.45, 0.12), Color(0.8, 0.2, 0.28), Color(1.0, 0.55, 0.3)]


## What sprouts as a ball heals (Expansion 6, owner reference photo of a sprouted moss ball): clusters
## of red-tipped stem plants and bright leafy fern clumps, thickest on the ball's top like a crown,
## and fine roots trailing from its underside. All are `sprout` plants: none on neglected moss; they
## grow in with the moss's health. Kept off routes, blooms and mouths like the rest.
static func _sprouts(lb: LevelBuilder, i: int) -> void:
	var b := lb.ball
	var keep := _veg_keep_clear(lb)
	var area := pow(float(RADII[i]) / 24.0, 2.0)
	# A steady, seedless pick per direction (the plants must not use gameplay's random sequence).
	var pick := func(d: Vector3) -> float: return fposmod(sin(d.x * 91.7 + d.y * 37.3 + d.z * 53.9) * 437.58, 1.0)
	var crown := func(d: Vector3) -> bool: return not keep.call(d) and (d.y > 0.25 or pick.call(d) < 0.35 * (d.y + 1.0))
	var stems := b.make_veg_material(Color(0.22, 0.46, 0.12), SPROUT_TIPS[i],
			Vegetation.family_params("medium", 1.0).merged({"sway": 0.2, "wake_gain": 0.8, "cam_fade": 1.4, "sprout": 1.0}, true))
	var nodes: Array = []
	nodes += b.scatter(MeshLib.stem_plant_mesh(5, 1.2, 700 + i, 7), stems, int(90 * area), 700 + i, 0.8, 1.6, crown, 45.0)
	# (Variegated: an earth star's pink margins and cream stripes, or a fire-and-ice white centre.)
	var fern_p := Vegetation.family_params("short", 0.6).merged({"sway": 0.18, "wake_gain": 0.7, "cam_fade": 1.2, "sprout": 1.0,
			"variegate": 1.0, "vari_style": float(i % 2), "vari_edge": Color(0.96, 0.58, 0.72), "vari_stripe": Color(0.95, 0.94, 0.84)}, true)
	var ferns := b.make_veg_material(Color(0.12, 0.42, 0.1), Color(0.55, 0.85, 0.25), fern_p)
	nodes += b.scatter(MeshLib.broadleaf_mesh(5, 1.0, 720 + i), ferns, int(45 * area), 720 + i, 0.8, 1.5, crown, 45.0)
	# The crown itself: tall stem plants and big fern clumps over the top of the ball, large enough
	# to shape its outline from across the tank (he walks through them like tall reeds).
	var top := func(d: Vector3) -> bool: return not keep.call(d) and d.y > 0.5 and pick.call(d * 1.7) < smoothstep(0.5, 0.9, d.y)
	var tall := b.make_veg_material(Color(0.2, 0.44, 0.1), SPROUT_TIPS[i],
			Vegetation.family_params("tall", 4.0).merged({"sway": 0.16, "sway_speed": 0.9, "wake_gain": 0.9, "cam_fade": 2.4, "sprout": 1.0}, true))
	nodes += b.scatter(MeshLib.stem_plant_mesh(8, 1.2, 760 + i, 8), tall, int(55 * area), 760 + i, 3.0, 5.5, top, 120.0)
	nodes += b.scatter(MeshLib.broadleaf_mesh(6, 1.0, 780 + i), ferns, int(18 * area), 780 + i, 2.0, 3.0, top, 120.0)
	var roots := b.make_veg_material(Color(0.22, 0.3, 0.12), Color(0.5, 0.45, 0.3),
			Vegetation.family_params("tall", 2.0).merged({"sway": 0.3, "sway_speed": 0.8, "wake_gain": 0.9, "cam_fade": 2.0, "sprout": 1.0}, true))
	var under := func(d: Vector3) -> bool: return not keep.call(d) and d.y < -0.65
	nodes += b.scatter(MeshLib.root_strands_mesh(5, 2.2, 740 + i), roots, int(45 * area), 740 + i, 1.8, 3.0, under, 110.0)
	b.sprout_nodes = nodes


## A shadow-only flat stand-in for a body's detailed climbing leaves (MeshLib.leaf_shadow_proxy).
static func _leaf_shadow(body: Node, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = MeshLib.leaf_shadow_proxy(body.get_meta("leaves"))
	mi.material_override = mat
	mi.top_level = true
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	mi.layers = MossBall.SHADOW_CASTER_LAYER
	body.add_child(mi)
	mi.global_transform = Transform3D.IDENTITY


static func _accent_flora(lb: LevelBuilder, i: int) -> void:
	var b := lb.ball
	var keep := _veg_keep_clear(lb)
	var ok := func(d: Vector3) -> bool: return not keep.call(d)
	var per := int(95.0 * pow(float(RADII[i]) / 24.0, 2.0))
	for k in 2:
		var col: Array = ACCENTS[i][k]
		var mat := b.make_veg_material(col[0], col[1], Vegetation.family_params("short", 0.45).merged({"sway": 0.12, "wake_gain": 0.7, "cam_fade": 1.0}, true))
		b.coral_nodes += b.scatter(MeshLib.coral_mesh(5 + k * 2, 0.75 + k * 0.15, 900 + i * 10 + k), mat, per, 900 + i * 10 + k, 0.9, 1.8, ok, 70.0)


## Ambient flap of platform and ladder leaves at the tip, in metres (dev-000024 playtest polish).
const LEAF_FLUTTER := 0.06


static func _materials(lb: LevelBuilder, stem_a: Color, stem_b: Color, leaf_a: Color, leaf_b: Color) -> void:
	var b := lb.ball
	lb.stem_mat = b.make_plant_material(stem_a, stem_b)
	# (Leaves flap a few centimetres at the tip, each on its own; the stems stay rigid.)
	lb.leaf_mat = b.make_plant_material(leaf_a, leaf_b, {"vein": 1.0, "variegate": 0.45, "vari_style": 1.0, "vari_stripe": Color(0.9, 0.95, 0.78),
			"flutter": LEAF_FLUTTER, "flutter_speed": 1.1, "leaf_data": true})
	lb.shell_mat = b.make_moss_material({"fuzz": 0.0})
	lb.strand_mat = b.make_veg_material(b.palette["moss_healthy_a"], b.palette["moss_healthy_b"], {"sway": 0.08, "impulse_gain": 2.2, "cam_fade": 1.2,
			"wake_gain": 1.0, "plant_height": 2.4})


static func _vortex_dir(from_i: int, to_i: int) -> Vector3:
	return (CENTERS[to_i] - CENTERS[from_i]).normalized()


static func _latlon(v: Vector3) -> Vector2:
	return Vector2(rad_to_deg(asin(clampf(v.y, -1, 1))), rad_to_deg(atan2(v.x, v.z)))


static func leaf_mid(xf: Transform3D, along: float, side: float) -> Transform3D:
	return Transform3D(xf.basis, xf * Vector3(side, 0.05, -along))


## Where new vegetation must not grow on this ball, so what matters stays readable: blooms, motes
## (a small clearing), burrow holes, cave mouths, the mounds (platforms), brittle moss and the
## vortex mouths; plus `extra` [[dir, degrees], ...]. Returns Callable(dir) -> true to keep clear.
static func _veg_keep_clear(lb: LevelBuilder, extra: Array = []) -> Callable:
	var b := lb.ball
	var deg := func(m: float) -> float: return rad_to_deg(m / b.radius)
	var list: Array = extra.duplicate()
	for bl in b.blooms:
		list.append([bl.dir, deg.call(1.6)])
	for m in b.motes:
		list.append([m.home_dir(), deg.call(1.8)])
	for h in b.food_spots:
		list.append([h["dir"], deg.call(0.9)])
	for c in b.crumbles:
		list.append([b.up_at(c._home.origin), deg.call(1.8)])
	for link in LINKS:
		if link[0] == b.index:
			list.append([_vortex_dir(b.index, link[1]), 6.0])
		elif link[1] == b.index:
			list.append([_vortex_dir(b.index, link[0]), 6.0])
	for h in lb.bot_hints:
		if h.has("cave"):
			list.append([b.up_at(h["door"]), deg.call(3.5)])
	for body in lb.root.get_children():
		if body is StaticBody3D and body.get_meta("grounded", "") == "cushion":
			list.append([b.up_at(body.global_position), deg.call(float(body.get_meta("radius")) * 1.9)])
	# (Ravines stay bare, so their edges read as the drop they are.)
	return func(d: Vector3) -> bool: return _near_any(d, list) or b.ravine_carve(d) > 0.1


## Dense stands with clearings: Callable(dir) -> true where a stand grows (smooth noise over the
## ball above `threshold`, about half the surface for threshold -0.15). Deterministic per seed.
static func _stands(seed_v: int, threshold: float) -> Callable:
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.frequency = 1.6
	return func(d: Vector3) -> bool: return n.get_noise_3dv(d) > threshold


## A jungle stem's leaves as a climb: levels from 0.9 m to its highest big leaf, at most 1 m apart,
## turning LADDER_TURN degrees each; the big leaves take the levels nearest their heights, small leaves the
## rest.
const LADDER_START := 0.9
const LADDER_RISE := 1.0
## (Each leaf a little more than a quarter turn round from the one below, so no leaf hangs over
## the one you jump from.)
const LADDER_TURN := 108.0
## A ladder leaf (Expansion 6, owner phone report): broad enough to land, turn and aim on (was 2.4 m
## long by 1.6 m wide, narrow enough to fall off while lining up the next jump).
const LADDER_LEAF_LEN := 2.6
const LADDER_LEAF_W := 2.2


static func _jungle_ladder(lb: LevelBuilder, sxf: Transform3D, h: float, r0: float, r1: float, bend: float, big: Array, k: int) -> void:
	# Every leaf, the top one too, grows from the stem below its tip (its stalk enters the stem).
	for bl in big:
		bl[0] = minf(bl[0], h - 0.5)
	big.sort_custom(func(a, b): return a[0] < b[0])
	var top: float = big[big.size() - 1][0]
	var n := ceili((top - LADDER_START) / LADDER_RISE - 0.001)
	var rise := (top - LADDER_START) / maxf(n, 1)
	var levels := []
	for i in n + 1:
		levels.append([LADDER_START + i * rise, LADDER_LEAF_LEN, LADDER_LEAF_W])
	for bl in big:
		var best := -1
		for i in levels.size():
			if levels[i][1] == LADDER_LEAF_LEN and (best < 0 or absf(levels[i][0] - bl[0]) < absf(levels[best][0] - bl[0])):
				best = i
		if best >= 0:
			levels[best] = [levels[best][0], bl[1], bl[2]]
	lb.ladder_stem(sxf, h, r0, r1, bend, levels, float(k * 137 % 360), LADDER_TURN, "jungle stem %d" % k)


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
	# The same climb for the elevated-route audit: two mounds, the brittle-moss bridge, the top.
	lb.bot_hints.append({"route": "tower", "audit": true, "start": lb.ball.surface_point(lb.ball.up_at(lb.at(lat, lon, heading, 0, 0, 2.6).origin)),
			"tops": [lb.at(lat, lon, heading, 0, 1.4, 0).origin, lb.at(lat, lon, heading, 0, 2.8, -2.6).origin, lb.at(lat, lon, heading, 0, 2.9, -5.1).origin,
			lb.at(lat, lon, heading, 0, 3.4, -7.1).origin, lb.at(lat, lon, heading, 0, 4.2, -10.0).origin], "zones": [zone], "goal": "tower top"})


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
# MOSS BALL #1 — Mossy Meadow (world expansion: radius 48, the template world)
# =========================================================================================
# The original content keeps its places on the ball (same latitude and longitude, so twice as
# far apart) and its completion ids; the tutorial keeps its size in metres at the north pole. The
# new content fills the larger ball (docs/WORLD_EXPANSION.md, "Mossy Meadow"):
#   the Glade Upland   a raised meadow over the north (the tutorial is on it), rimmed by a gentle
#                      escarpment down to the lowlands;
#   the Great Ravine   across the upland south of the tutorial: walk round either end (easy), hop
#                      the stepping stones (skilled), burst straight over (skilled), or cross on
#                      the fallen stem that rises into a bridge when the glade heals;
#   the Split Crack    a narrower cut in the western upland, crossed by a natural stone bridge;
#   the Heights        stepped terraces on the eastern upland;
#   Moss Meadow        the rolling lowland fields and the Meadow Stone;
#   East Tower lands   the brittle tower and the vortex to Current Hollows;
#   the Coral Garden   tube corals round a giant sea fan;
#   Southern Reed Hills, West Stone Ridge (a crest walk, a natural arch, the moss cave);
#   the Fern Grove     tall ferns and bubble columns up to high shelves;
#   Root Hollows       on the underside, walled by ridges, behind a root curtain that draws up
#                      when the southern hills heal (or climb in over the walls).

## The tutorial, in metres from the north pole along longitude 0 (the size it always had).
const TUT_M1_M := 4.61      # M1, the first mound: a plain jump (radius 2.0, top 1.3)
const TUT_M1_TOP := 1.3
const TUT_M2_M := 13.6      # M2: higher, across a gap that needs jump + water burst (radius 2.4)
const TUT_M2_TOP := 2.9
const TUT_PARASITE_M := 12.99
const TUT_BLOOM_M := 14.4
## Mossy Meadow's upland: a plateau over the north, flat above this latitude, its escarpment
## falling to the lowlands by UPLAND_FOOT_LAT.
const UPLAND_TOP_LAT := 54.0
const UPLAND_FOOT_LAT := 40.0
const UPLAND_H := 3.5
const GREAT_RAVINE_LAT := 62.0


## Latitude on Mossy Meadow `m` metres from the north pole (the tutorial's line, longitude 0),
## measured along the upland's surface where the tutorial lies.
static func tut_lat(m: float) -> float:
	return 90.0 - rad_to_deg(m / (RADII[0] + UPLAND_H))


## How far `dir` is from Mossy Meadow's north pole, in metres along the upland's surface.
static func tut_m(dir: Vector3) -> float:
	return dir.angle_to(Vector3.UP) * (RADII[0] + UPLAND_H)


## A direction on Mossy Meadow `m` metres from the north pole down longitude 0.
static func tut_dir(m: float) -> Vector3:
	return MossBall.dir_ll(tut_lat(m), 0.0)


static func _ball1(lb: LevelBuilder) -> void:
	var b := lb.ball
	b.food_weights = [0.6, 0.25, 0.15]
	b.food_target = 14
	b.start_dir = MossBall.dir_ll(89.5, 0)
	# Rolling hills first (their order is fixed: tests and views use them by index), broader and
	# higher at the new size.
	lb.hill(32, -9, 18.0, 2.4)
	lb.hill(21, 11, 14.0, 2.0)
	lb.hill(26, 22, 16.0, 2.7)
	lb.hill(-52, 22, 20.0, 3.0)
	lb.hill(-72, -12, 16.0, 2.2)
	lb.hill(-28, 150, 18.0, 2.7)
	# The Southern Reed Hills and the lowland folds.
	lb.hill(-44, 58, 14.0, 2.2)
	lb.hill(-64, 60, 12.0, 1.8)
	lb.hill(-58, -40, 14.0, 2.4)
	lb.hill(10, 160, 16.0, 2.2)
	lb.hill(-8, -160, 12.0, 1.6)
	# The Glade Upland.
	b.add_plateau(Vector3.UP, deg_to_rad(90.0 - UPLAND_FOOT_LAT), UPLAND_H, 90.0 - UPLAND_FOOT_LAT - (90.0 - UPLAND_TOP_LAT))
	# The Great Ravine: 47 m of it along the upland, closed at both ends.
	var gr := []
	for lon in range(-60, 61, 15):
		gr.append(Vector2(GREAT_RAVINE_LAT, lon))
	lb.ravine(gr, 3.6, UPLAND_H, 1.4, "b1.great_ravine")
	# The Split Crack in the western upland.
	lb.ravine([Vector2(72, -110), Vector2(64.5, -110), Vector2(57, -110)], 3.0, UPLAND_H, 1.3, "b1.split_crack")

	# Zones: the six that always were (their ids are the v3 catalog's), then the new ones.
	lb.zone("tut", 76, 0, 14)
	lb.zone("meadow", 28, 0, 22)
	lb.zone("east", 12, 95, 30)
	lb.zone("south", -60, 10, 30)
	lb.zone("west", 15, -90, 30)
	lb.zone("under", -30, 180, 34)
	lb.zone("rim", 62, 0, 26)
	lb.zone("crack", 64, -110, 16)
	lb.zone("heights", 62, 125, 22)
	lb.zone("coral", -22, 56, 16)
	lb.zone("fern", -36, -76, 16)
	lb.zone("roots", -62, -150, 14)

	# ---- The original content, in its original order (ids fixed as in catalog v3) -------------
	# Tutorial: move -> jump -> water burst -> tail swipe -> restore -> bloom.
	lb.cushion(tut_lat(TUT_M1_M), 0, 2.0, TUT_M1_TOP)          # M1: needs a jump
	lb.cushion(tut_lat(TUT_M2_M), 0, 2.4, TUT_M2_TOP)          # M2: higher + a gap that needs jump + water burst
	# (For the elevated-route audit: the tutorial's taught climb, onto M1 then jump + burst to M2.)
	lb.bot_hints.append({"route": "tutorial", "audit": true, "burst": true, "start": b.surface_point(tut_dir(TUT_M1_M - 3.2)),
			"tops": [b.surface_point(tut_dir(TUT_M1_M - 0.5), TUT_M1_TOP), b.surface_point(tut_dir(TUT_M1_M + 1.8), TUT_M1_TOP),
			b.surface_point(tut_dir(TUT_M2_M - 2.0), TUT_M2_TOP), b.surface_point(tut_dir(TUT_M2_M), TUT_M2_TOP)], "zones": ["tut"], "goal": "tutorial mound M2"})
	lb.fixed(lb.parasite(Parasite.Kind.SMALL, "tut", tut_lat(TUT_PARASITE_M), 0, 1.2, TUT_M2_TOP), "b1.tut.parasite.0")
	lb.fixed(lb.bloom(tut_lat(TUT_BLOOM_M), 0, TUT_M2_TOP), "b1.bloom.0")
	# Meadow.
	lb.fixed(lb.mote("meadow", 35, -10), "b1.meadow.mote.0")
	lb.fixed(lb.mote("meadow", 19, 14), "b1.meadow.mote.1")
	lb.fixed(lb.parasite(Parasite.Kind.SMALL, "meadow", 27, -3, 6.0), "b1.meadow.parasite.0")
	lb.fixed(lb.parasite(Parasite.Kind.SMALL, "meadow", 16, 6, 6.0), "b1.meadow.parasite.1")
	# East: the brittle tower + the vortex to Current Hollows.
	_tower(lb, 27, 76, 90, "east")
	lb.fixed(b.motes[b.motes.size() - 1], "b1.east.mote.0")
	lb.fixed(lb.parasite(Parasite.Kind.MEDIUM, "east", -6, 90, 7.0), "b1.east.parasite.0")
	lb.fixed(lb.parasite(Parasite.Kind.SMALL, "east", 12, 120, 6.0), "b1.east.parasite.1")
	lb.fixed(lb.mote("east", -9, 112), "b1.east.mote.1")
	lb.fixed(lb.bloom(-1, 88), "b1.bloom.1")
	# South: a large parasite among the reed hills.
	lb.fixed(lb.parasite(Parasite.Kind.LARGE, "south", -62, 8, 8.0), "b1.south.parasite.0")
	lb.fixed(lb.mote("south", -48, 34), "b1.south.mote.0")
	lb.fixed(lb.mote("south", -74, -24), "b1.south.mote.1")
	# West: the hidden moss cave.
	lb.cave(26, -104, 90)
	lb.fixed(b.upgrades[0], "b1.cave.0")
	lb.fixed(lb.parasite(Parasite.Kind.MEDIUM, "west", 8, -78, 7.0), "b1.west.parasite.0")
	lb.fixed(lb.parasite(Parasite.Kind.SMALL, "west", -4, -96, 6.0), "b1.west.parasite.1")
	lb.fixed(lb.mote("west", 3, -66), "b1.west.mote.0")
	lb.fixed(lb.mote("west", 14, -84), "b1.west.mote.1")
	lb.fixed(lb.bloom(-2, -74), "b1.bloom.2")
	# Underside.
	lb.fixed(lb.parasite(Parasite.Kind.SMALL, "under", -24, 172, 7.0), "b1.under.parasite.0")
	lb.fixed(lb.mote("under", -18, 160), "b1.under.mote.0")
	lb.fixed(lb.mote("under", -42, -162), "b1.under.mote.1")
	lb.fixed(lb.bloom(-34, 176), "b1.bloom.3")

	# ---- The Great Ravine and the upland rims ----------------------------------------------
	var rim_m := 1.8 + 1.4 + 0.7     # floor half-width + wall + a step onto solid ground
	var north_rim := func(lon: float) -> Vector3: return b.surface_point(MossBall.dir_ll(GREAT_RAVINE_LAT + lb.m2deg(rim_m), lon))
	var south_rim := func(lon: float) -> Vector3: return b.surface_point(MossBall.dir_ll(GREAT_RAVINE_LAT - lb.m2deg(rim_m), lon))
	# The fallen stem on the tutorial's line: it rises into a bridge when the glade heals.
	lb.fallen_stem_bridge("tut", north_rim.call(0.0), south_rim.call(0.0), 0.6)
	# Stepping stones (skilled): two stone columns up from the floor to rim height.
	var stone_lat := [GREAT_RAVINE_LAT + lb.m2deg(0.75), GREAT_RAVINE_LAT - lb.m2deg(0.75)]
	var stone_lon := [-24.0, -27.0]
	var stones := []
	for k in 2:
		lb.stone_column(MossBall.dir_ll(stone_lat[k], stone_lon[k]), 0.8, UPLAND_H + 0.1)
		stones.append(b.surface_point(MossBall.dir_ll(stone_lat[k], stone_lon[k]), UPLAND_H + 0.1))
	lb.crossings.append({"a": north_rim.call(-24.0), "b": south_rim.call(-27.0), "stones": stones, "gate": null})
	lb.route("stepping stones", north_rim.call(-24.0), stones, ["rim"], "the far stepping stone")
	lb.bot_hints[lb.bot_hints.size() - 1]["exit"] = [south_rim.call(-27.0)]
	lb.bot_hints.append({"route": "stones off", "audit": true, "branch": true, "start": stones[1], "tops": [south_rim.call(-27.0)], "zones": [], "goal": "the far rim"})
	lb.mote_xf("rim", Transform3D(MossBall.frame_at(b.up_at(stones[1]), 0.0), stones[1] + b.up_at(stones[1]) * 0.5), 0.3)
	lb.parasite(Parasite.Kind.SMALL, "rim", 57, -40, 4.0)
	lb.parasite(Parasite.Kind.SMALL, "rim", 57, 35, 4.0)
	lb.parasite(Parasite.Kind.MEDIUM, "rim", 68, 45, 4.0)
	lb.mote("rim", 56, -15)
	lb.mote("rim", 67, -50)
	lb.bloom(56.5, 5)

	# ---- The Split Crack and its stone bridge ------------------------------------------------
	var crack_side := lb.m2deg(1.5 + 1.3 + 0.8) / cos(deg_to_rad(64.5))
	var cb0 := b.surface_point(MossBall.dir_ll(64.5, -110 + crack_side))
	var cb1 := b.surface_point(MossBall.dir_ll(64.5, -110 - crack_side))
	var stone_bridge := lb.bridge(cb0, cb1, 0.5, 1.8, 0.8)
	var sbl: Array = stone_bridge.get_meta("top_line")
	lb.crossings.append({"a": cb0, "b": cb1, "gate": null})
	var sbm: Vector3 = sbl[sbl.size() / 2]
	lb.mote_xf("crack", Transform3D(MossBall.frame_at(b.up_at(sbm), 0.0), sbm + b.up_at(sbm) * 0.5), 0.4)
	lb.route("stone bridge", cb0, [sbl[4], sbl[8], sbm], ["crack"], "the stone bridge's middle")
	lb.bot_hints[lb.bot_hints.size() - 1]["exit"] = [sbl[14], cb1]
	lb.bot_hints.append({"route": "bridge off", "audit": true, "branch": true, "start": sbm, "tops": [sbl[14], cb1], "zones": [], "goal": "the far rim"})
	lb.parasite(Parasite.Kind.MEDIUM, "crack", 69, -95, 4.0)
	lb.parasite(Parasite.Kind.SMALL, "crack", 59, -126, 4.0)
	lb.mote("crack", 70, -128)

	# ---- The Heights: terraces on the eastern upland -----------------------------------------
	var tiers := lb.terrace(64, 125, [[4.2, 1.2], [2.8, 2.4], [1.6, 3.5]])
	var tier_top := func(k: int) -> Vector3:
		var base: Vector3 = (tiers[0] as Node3D).global_position
		return base + b.up_at(base) * float(tiers[k].get_meta("top"))
	var tstart := b.surface_point(MossBall.dir_ll(64 - lb.m2deg(6.0), 125))
	lb.route("heights terraces", tstart, [b.surface_point(MossBall.dir_ll(64 - lb.m2deg(3.3), 125), 1.2), b.surface_point(MossBall.dir_ll(64 - lb.m2deg(2.1), 125), 2.4), tier_top.call(2)], ["heights"], "terrace top")
	var tt: Vector3 = tier_top.call(2)
	lb.mote_xf("heights", Transform3D(MossBall.frame_at(b.up_at(tt), 0.0), tt + b.up_at(tt) * 0.5), 0.4)
	lb.parasite(Parasite.Kind.SMALL, "heights", 58, 100, 4.0)
	lb.parasite(Parasite.Kind.SMALL, "heights", 67, 152, 4.0)
	lb.parasite(Parasite.Kind.MEDIUM, "heights", 56, 145, 4.0)
	lb.mote("heights", 60, 168)
	lb.mote("heights", 70, 105)
	lb.bloom(66, 98)

	# ---- Moss Meadow lowland: more of it, and the Meadow Stone -------------------------------
	lb.parasite(Parasite.Kind.SMALL, "meadow", 24, -28, 5.0)
	lb.parasite(Parasite.Kind.SMALL, "meadow", 32, 30, 5.0)
	lb.mote("meadow", 22, -32)
	lb.mote("meadow", 35, 28)
	var ms_step := -14.0 + lb.m2deg(3.7) / cos(deg_to_rad(20.0))
	lb.cushion(20, ms_step, 1.2, 1.3)
	var ms := lb.shelf(20, -14, 2.6, 2.0, 1.1)
	var ms_top := ms.global_position + b.up_at(ms.global_position) * 2.6
	lb.route("meadow stone", b.surface_point(MossBall.dir_ll(20, ms_step + lb.m2deg(3.0) / cos(deg_to_rad(20.0)))),
			[b.surface_point(MossBall.dir_ll(20, ms_step), 1.3), ms_top], ["meadow"], "Meadow Stone")
	lb.mote_xf("meadow", Transform3D(MossBall.frame_at(b.up_at(ms_top), 0.0), ms_top + b.up_at(ms_top) * 0.5), 0.5)

	# ---- East Tower lands: more of them ------------------------------------------------------
	lb.parasite(Parasite.Kind.SMALL, "east", 18, 136, 5.0)
	lb.mote("east", 2, 140)

	# ---- The Coral Garden ----------------------------------------------------------------------
	lb.sea_fan(lb.at(-25, 60, 30, 0, -0.2, 0), 7.5, 9.0, Color(0.85, 0.35, 0.45), 4101)
	lb.parasite(Parasite.Kind.MEDIUM, "coral", -18, 46, 5.0)
	lb.parasite(Parasite.Kind.SMALL, "coral", -31, 68, 5.0)
	lb.mote("coral", -14, 64)
	lb.mote("coral", -30, 46)
	var cs_step := 52.5 - lb.m2deg(3.7) / cos(deg_to_rad(26.0))
	lb.cushion(-26, cs_step, 1.2, 1.3)
	var cs := lb.shelf(-26, 52.5, 2.6, 1.9, 1.0)
	var cs_top := cs.global_position + b.up_at(cs.global_position) * 2.6
	lb.route("coral shelf", b.surface_point(MossBall.dir_ll(-26, cs_step - lb.m2deg(3.0) / cos(deg_to_rad(26.0)))),
			[b.surface_point(MossBall.dir_ll(-26, cs_step), 1.3), cs_top], ["coral"], "coral shelf")
	lb.mote_xf("coral", Transform3D(MossBall.frame_at(b.up_at(cs_top), 0.0), cs_top + b.up_at(cs_top) * 0.5), 0.5)
	lb.bloom(-16, 52)

	# ---- Southern Reed Hills: more of them -----------------------------------------------------
	lb.parasite(Parasite.Kind.SMALL, "south", -50, -22, 5.0)
	lb.parasite(Parasite.Kind.MEDIUM, "south", -70, 45, 6.0)
	lb.mote("south", -42, 8)
	lb.mote("south", -60, 70)
	lb.bloom(-46, 18)

	# ---- West Stone Ridge, its arch, the cave's neighbourhood ------------------------------------
	var wr := lb.ridge(36, -136, 9, -130, 3.0, 7.0, 2.0, 11, 0.3)
	var wc: Array = wr.get_meta("crest")
	var wcm: Vector3 = wc[wc.size() / 2]
	lb.route("west ridge", wc[0], wc.slice(1, wc.size() / 2, 3) + [wcm], ["west"], "West Stone Ridge crest")
	lb.mote_xf("west", Transform3D(MossBall.frame_at(b.up_at(wcm), 0.0), wcm + b.up_at(wcm) * 0.5), 0.5)
	lb.arch(-5, -119, -5, -105, 2.2, 2.6, 0.9)
	lb.mote("west", -5, -112)
	lb.parasite(Parasite.Kind.SMALL, "west", 18, -122, 5.0)

	# ---- The Fern Grove and its bubble columns ---------------------------------------------------
	# [vent lat, lon, shelf lat, lon, shelf top]: each shelf 4 m from its column (clear of him
	# as he rises; he swims across from the top).
	for c in [[-33.0, -70.0, -33.0, -70.0 + lb.m2deg(4.0) / cos(deg_to_rad(33.0)), 5.0],
			[-42.0, -86.0, -42.0, -86.0 + lb.m2deg(4.0) / cos(deg_to_rad(42.0)), 4.2]]:
		var cdir := MossBall.dir_ll(c[0], c[1])
		lb.bubble_column(cdir, 0.9, float(c[4]) + 1.4)
		var sh := lb.shelf(c[2], c[3], c[4], 1.7, 0.9)
		var st_top := sh.global_position + b.up_at(sh.global_position) * float(c[4])
		lb.bot_hints.append({"route": "fern column", "lift": true, "start": b.surface_point(cdir),
				"tops": [b.surface_point(cdir, float(c[4]) + 1.0), st_top], "zones": ["fern"], "goal": "fern shelf"})
		lb.mote_xf("fern", Transform3D(MossBall.frame_at(b.up_at(st_top), 0.0), st_top + b.up_at(st_top) * 0.5), 0.4)
	lb.parasite(Parasite.Kind.SMALL, "fern", -40, -60, 5.0)
	lb.parasite(Parasite.Kind.SMALL, "fern", -28, -90, 5.0)
	lb.parasite(Parasite.Kind.MEDIUM, "fern", -48, -74, 5.0)
	lb.mote("fern", -46, -94)
	lb.bloom(-30, -80)

	# ---- Root Hollows: walled by ridges, a root curtain in the doorway ---------------------------
	var rc := MossBall.dir_ll(-62, -150)
	# A hexagon of walls 10 m out, in the site's own metres; each wall runs 4 m past its corners so
	# the corners are sealed and its ramps rise from outside (the skilled way in, over the top).
	var site := func(x: float, z: float) -> Vector3: return lb.at(-62, -150, 0, x, 0, z).origin
	var corner := func(k: int) -> Vector2:
		var a := deg_to_rad(60.0 * k + 30.0)
		return Vector2(cos(a), sin(a)) * 10.0
	var ll := func(pt: Vector3) -> Vector2: return _latlon(b.up_at(pt))
	# (Side 0, between corners 0 and 1, is the doorway.)
	for k in range(1, 6):
		var c0: Vector2 = corner.call(k)
		var c1: Vector2 = corner.call(k + 1)
		var dirv := (c1 - c0).normalized()
		var e0: Vector2 = ll.call(site.call(c0.x - dirv.x * 4.0, c0.y - dirv.y * 4.0))
		var e1: Vector2 = ll.call(site.call(c1.x + dirv.x * 4.0, c1.y + dirv.y * 4.0))
		var wall := lb.ridge(e0.x, e0.y, e1.x, e1.y, 3.0, 5.0, 1.6, 60 + k, 0.3)
		var wcr: Array = wall.get_meta("crest")
		lb.bot_hints.append({"route": "hollow wall %d" % k, "audit": true, "start": wcr[0],
				"tops": wcr.slice(2, wcr.size(), 3) + [wcr[wcr.size() - 1]], "zones": [], "goal": "Root Hollows wall"})
	var dm2: Vector2 = (corner.call(0) + corner.call(1)) * 0.5
	var dmid := b.up_at(site.call(dm2.x, dm2.y))
	var dxf := b.xform_on_dir(dmid)
	var face := (b.surface_point(rc) - dxf.origin)
	face = (face - dxf.basis.y * face.dot(dxf.basis.y)).normalized()
	dxf.basis = Basis(dxf.basis.y.cross(face).normalized(), dxf.basis.y, -face)
	var curtain := lb.root_curtain("south", dxf.translated_local(Vector3(0, -0.3, 0)), 10.5, 3.4, 5101)
	lb.bot_hints.append({"hollow": true, "door": dxf.origin, "inside": b.surface_point(rc), "zone": "roots", "gate": curtain})
	lb.parasite(Parasite.Kind.MEDIUM, "roots", -62, -150, 2.5)
	lb.parasite(Parasite.Kind.SMALL, "roots", -65, -140, 2.5)
	lb.mote("roots", -60, -158)
	lb.mote("roots", -66, -148)

	# ---- Optional discoveries (nothing needs them) ------------------------------------------------
	# A bloom tucked inside Root Hollows; a bubble pocket by the glade that carries him up just for
	# the view (the first bubble column he meets); Lookout Rock on the far upland, stepped tiers
	# to a view over the tank, where a snail lives.
	lb.bloom(-65, -156)
	lb.bubble_column(MossBall.dir_ll(74, 62), 1.0, 5.5, 4.5)
	var look := lb.terrace(67, -160, [[4.6, 1.2], [3.4, 2.4], [2.3, 3.6], [1.3, 4.8]])
	var lbase: Vector3 = (look[0] as Node3D).global_position
	var lup := b.up_at(lbase)
	var ltops := []
	for k in 4:
		var r_in: float = [3.9, 2.8, 1.8, 0.0][k]
		ltops.append(b.surface_point(b.up_at(lbase + MossBall.frame_at(lup, 0.0).z * r_in), float(look[k].get_meta("top"))) if k < 3 else lbase + lup * 4.8)
	lb.bot_hints.append({"route": "lookout rock", "audit": true, "start": b.surface_point(b.up_at(lbase + MossBall.frame_at(lup, 0.0).z * 6.4)),
			"tops": ltops, "zones": [], "goal": "Lookout Rock"})

	# ---- Food, holes, growth -----------------------------------------------------------------
	for r in [[28, 0, 24], [12, 95, 24], [15, -90, 24], [-38, 170, 26], [-58, 10, 24], [62, 60, 20], [62, -60, 20],
			[-22, 56, 14], [-36, -76, 14], [64, 150, 16]]:
		lb.food_region(r[0], r[1], r[2])
	_holes(lb, 26, 101, [[MossBall.dir_ll(78, 0), 12], [MossBall.dir_ll(26, -104), 16], [MossBall.dir_ll(GREAT_RAVINE_LAT, 0), 8],
			[MossBall.dir_ll(64, -110), 8], [rc, 13]])

	# Vegetation: soft velvety marimo moss, short plants and broad leaves.
	var veg := b.make_veg_material(Color(0.12, 0.4, 0.1), Color(0.5, 0.8, 0.28), Vegetation.family_params("short", 0.34))
	b.scatter(MeshLib.tuft_mesh(5, 0.07, 0.34, 0.12, 1, 3, 0.3), veg, 20000, 11, 0.8, 1.35)
	var leaves := b.make_veg_material(Color(0.1, 0.36, 0.1), Color(0.35, 0.7, 0.22), Vegetation.family_params("short", 0.5).merged({"sway": 0.22, "wake_gain": 0.6,
			# (Owner reference: variegated like an earth star, pink margins and cream stripes.)
			"variegate": 1.0, "vari_style": 0.0, "vari_edge": Color(0.96, 0.58, 0.72), "vari_stripe": Color(0.94, 0.92, 0.82)}, true))
	b.scatter(MeshLib.broadleaf_mesh(4, 0.7, 2), leaves, 1400, 12, 0.7, 1.25)
	var stalks := b.make_veg_material(Color(0.1, 0.36, 0.1), Color(0.35, 0.7, 0.22), Vegetation.family_params("medium", 1.7).merged({"sway": 0.14}, true))
	b.scatter(MeshLib.tuft_mesh(3, 0.1, 1.7, 0.1, 3, 5, 0.25), stalks, 600, 13, 0.8, 1.3)
	# Reactive vegetation: medium growth through the meadow, a tall reed bed in the southern hills
	# where the large parasite roams, tall ferns in the Fern Grove, medium growth in Root Hollows.
	# The tutorial, the ravine crossings, caves, blooms, motes, holes and platforms are kept clear.
	var clear := _veg_keep_clear(lb, [[MossBall.dir_ll(78, 0), 9.0], [MossBall.dir_ll(GREAT_RAVINE_LAT, 0), 6.0], [MossBall.dir_ll(74, 62), 3.0], [MossBall.dir_ll(67, -160), 8.0],
			[MossBall.dir_ll(GREAT_RAVINE_LAT, -25.5), 5.0], [MossBall.dir_ll(64.5, -110), 6.0], [MossBall.dir_ll(-25, 60), 5.0]])
	Vegetation.field(b, "medium", MossBall.dir_ll(28, 10), 14.0, 1500, 101, {"avoid": clear, "clumps": 12})
	Vegetation.field(b, "tall", MossBall.dir_ll(-58, 34), 12.0, 1600, 102, {"avoid": clear, "clumps": 9, "fill": 0.35, "edge": 0.7})
	Vegetation.corridor(b, "medium", MossBall.dir_ll(4, 60), MossBall.dir_ll(-40, 30), 6.0, 420, 103, {"avoid": clear})
	Vegetation.field(b, "tall", MossBall.dir_ll(-36, -76), 11.0, 1100, 104, {"avoid": clear, "clumps": 8, "fill": 0.45, "edge": 0.6})
	Vegetation.field(b, "medium", rc, 8.0, 380, 105, {"avoid": clear, "clumps": 5})
	Vegetation.field(b, "medium", MossBall.dir_ll(66, -60), 9.0, 420, 106, {"avoid": clear, "clumps": 6})
	# The Coral Garden: dense tube corals and anemones round the fan.
	var coral_c := MossBall.dir_ll(-22, 56)
	var in_garden := func(dd: Vector3) -> bool: return dd.angle_to(coral_c) < deg_to_rad(15.0) and not clear.call(dd)
	for k in 2:
		var col: Array = ACCENTS[0][k]
		var mat := b.make_veg_material(col[0], col[1], Vegetation.family_params("short", 0.45).merged({"sway": 0.12, "wake_gain": 0.7, "cam_fade": 1.0}, true))
		b.coral_nodes += b.scatter(MeshLib.coral_mesh(5 + k * 2, 0.75 + k * 0.15, 950 + k), mat, 240, 950 + k, 1.2, 2.6, in_garden, 70.0)


# =========================================================================================
# MOSS BALL #2 — current-swept overgrowth
# =========================================================================================

static func _ball2(lb: LevelBuilder) -> void:
	var b := lb.ball
	b.current_axis = Vector3.UP
	b.current_strength = 3.0
	lb.hill(2, 58, 16.0, 3.0)
	lb.hill(-18, 168, 18.0, 2.5)
	lb.hill(40, -150, 16.0, 2.4)
	lb.hill(-60, 80, 14.0, 2.2)
	b.food_weights = [0.45, 0.35, 0.2]
	b.food_target = 16
	# World expansion (radius 28 -> 56): the Current Shelf, an upland cut through by the Cut, a
	# ravine the current blows straight across.
	b.add_plateau(MossBall.dir_ll(-25, 110), lb.m2deg(26.0) * PI / 180.0, 3.5, 10.0)
	lb.ravine([Vector2(-13, 110), Vector2(-25, 110.5), Vector2(-37, 110)], 4.4, 3.5, 1.4, "b2.the_cut")
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
	var mesa_tops := []
	for sd in sway_defs:
		mesa_tops.append(lb.at(S[0], S[1], S[2], 0, sd[1] + 0.13, sd[0]).origin)
	mesa_tops.append(lb.at(S[0], S[1], S[2], 0, 6.3, 3.4).origin)
	mesa_tops.append(lb.at(S[0], S[1], S[2], 0, 6.3, 0.0).origin)
	# (Riding the swaying platforms in the current takes timing and the water burst.)
	lb.bot_hints.append({"route": "mesa", "audit": true, "burst": true, "start": b.surface_point(b.up_at(lb.at(S[0], S[1], S[2], 0, 0, 13.4).origin)),
			"tops": mesa_tops, "zones": ["mesa"], "goal": "mesa top"})

	# Sheltered north cap + hidden cave.
	lb.cave(72, 110, 200)
	lb.parasite(Parasite.Kind.MEDIUM, "north", 60, 44, 10.0)
	lb.parasite(Parasite.Kind.SMALL, "north", 54, 14, 9.0)
	lb.mote("north", 66, 8)
	lb.mote("north", 50, 55)
	lb.bloom(55, 30)

	# East ridge: large parasite in strong current (knockback carries it downstream).
	lb.parasite(Parasite.Kind.LARGE, "east", 2, 58, 11.0)
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
	lb.parasite(Parasite.Kind.LARGE, "far", -8, 158, 12.0)
	lb.parasite(Parasite.Kind.MEDIUM, "far", 6, 176, 10.0).make_spitter()
	lb.mote("far", -22, 148)
	lb.mote("far", 0, -168)
	lb.bloom(-4, 146)

	lb.freeze_ids()

	# ---- World expansion: Current Hollows at radius 56 ------------------------------------------
	lb.zone("cut", -25, 110, 22)
	lb.zone("hollows", 10, 28, 16)
	lb.zone("kelp", -42, -150, 18)
	lb.zone("still", 80, -40, 14)
	# The Cut: across it on the current bridge (a stream carrying him east over it), with a burst
	# jump downstream (the current helps; upstream it fights him), over the kelp leaf that grows
	# across once the east ridge heals, or on foot round either end.
	var cut_side := lb.m2deg(2.2 + 1.4 + 0.9) / cos(deg_to_rad(25.0))
	lb.current_stream(b.surface_point(MossBall.dir_ll(-25, 110.5 - cut_side)), b.surface_point(MossBall.dir_ll(-25, 110.5 + cut_side)), 1.3, 7.0)
	var kl := lb.m2deg(2.2 + 1.4 + 0.9) / cos(deg_to_rad(18.0))
	lb.leaf_bridge("east", b.surface_point(MossBall.dir_ll(-18, 110.2 - kl)), b.surface_point(MossBall.dir_ll(-18, 110.2 + kl)), 2.6)
	lb.parasite(Parasite.Kind.SMALL, "cut", -20, 100, 4.0)
	lb.parasite(Parasite.Kind.MEDIUM, "cut", -30, 121, 4.0)
	lb.parasite(Parasite.Kind.SMALL, "cut", -35, 99, 4.0)
	lb.mote("cut", -14, 102)
	lb.mote("cut", -36, 120)
	lb.mote("cut", -8, 118)
	lb.bloom(-26, 100)
	# Undercut Hollows: coral shelves overhanging the moss, Motes tucked in the shade beneath, and
	# a bubble column up to the highest shelf.
	var hshelves := [[6.0, 22.0, 2.8, 2.6], [12.0, 30.0, 3.4, 2.8], [4.0, 36.0, 2.8, 2.4]]
	for hi in hshelves.size():
		var hs: Array = hshelves[hi]
		lb.shelf(hs[0], hs[1], hs[2], hs[3], 1.0)
		if hi == 1:
			continue   # (the highest is reached by the column)
		# A mound beside each lower shelf: up onto it, a plain jump at a time.
		var sgn := -1.0 if hi == 0 else 1.0
		var step_lon: float = hs[1] + sgn * lb.m2deg(float(hs[3]) + 2.1) / cos(deg_to_rad(hs[0]))
		lb.cushion(hs[0], step_lon, 1.0, 1.4)
		var edge_lon: float = hs[1] + sgn * lb.m2deg(float(hs[3]) - 0.8) / cos(deg_to_rad(hs[0]))
		lb.bot_hints.append({"route": "hollows shelf %d" % hi,
				"start": b.surface_point(MossBall.dir_ll(hs[0], step_lon + sgn * lb.m2deg(3.0) / cos(deg_to_rad(hs[0])))),
				"tops": [b.surface_point(MossBall.dir_ll(hs[0], step_lon), 1.4), b.surface_point(MossBall.dir_ll(hs[0], edge_lon), hs[2]),
				b.surface_point(MossBall.dir_ll(hs[0], hs[1]), hs[2])], "zones": ["hollows"], "goal": "a coral shelf"})
	for hi in [0, 2]:
		var hs2: Array = hshelves[hi]
		lb.mote("hollows", hs2[0], hs2[1], hs2[2], 0.5)
	var hc := MossBall.dir_ll(12.0, 30.0 - lb.m2deg(4.6) / cos(deg_to_rad(12.0)))
	lb.bubble_column(hc, 0.9, 4.8)
	var htop := b.surface_point(MossBall.dir_ll(12.0, 30.0), 3.4)
	lb.bot_hints.append({"route": "hollows column", "lift": true, "start": b.surface_point(hc),
			"tops": [b.surface_point(hc, 4.4), htop], "zones": ["hollows"], "goal": "the high coral shelf"})
	lb.mote_xf("hollows", Transform3D(MossBall.frame_at(b.up_at(htop), 0.0), htop + b.up_at(htop) * 0.5), 0.4)
	lb.parasite(Parasite.Kind.SMALL, "hollows", 14, 18, 4.0)
	lb.parasite(Parasite.Kind.MEDIUM, "hollows", 0, 30, 4.0).make_spitter()
	lb.mote("hollows", 16, 40)
	lb.bloom(18, 26)
	# The mesa shortcut: once the arrival meadow heals, a column starts to flow beside the mesa, up
	# past its top (the swaying platforms stay the skilled way up).
	var mcol := lb.at(S[0], S[1], S[2], -6.8, 0, 0).origin
	lb.bubble_column(b.up_at(mcol), 1.0, 7.8, 5.0, "arrive")
	lb.bot_hints.append({"route": "mesa column", "audit": true, "lift": true, "start": b.surface_point(b.up_at(mcol)),
			"tops": [b.surface_point(b.up_at(mcol), 7.2), lb.at(S[0], S[1], S[2], -3.4, 6.3, 0).origin, lb.at(S[0], S[1], S[2], 0, 6.3, -0.2).origin], "zones": ["mesa"], "goal": "mesa top"})
	# Kelp Fields on the far southern side: tall swaying kelp stands, Motes hidden among them.
	lb.parasite(Parasite.Kind.SMALL, "kelp", -38, -142, 5.0)
	lb.parasite(Parasite.Kind.MEDIUM, "kelp", -48, -160, 5.0)
	lb.mote("kelp", -34, -158)
	lb.mote("kelp", -50, -140)
	lb.mote("kelp", -44, -170)
	lb.bloom(-40, -150)
	# The Still Pool: the sheltered cap where the current never reaches.
	lb.parasite(Parasite.Kind.SMALL, "still", 78, -20, 4.0)
	lb.mote("still", 84, -70)
	lb.mote("still", 76, -55)
	lb.bloom(82, -30)

	for r in [[-5, -75, 26], [62, 40, 26], [0, 60, 24], [-55, 0, 28], [-10, 160, 30], [-25, 110, 18], [10, 28, 14],
			[-42, -150, 16], [80, -40, 12]]:
		lb.food_region(r[0], r[1], r[2])
	_holes(lb, 28, 202, [[MossBall.dir_ll(15, -20), 12], [MossBall.dir_ll(72, 110), 14], [MossBall.dir_ll(-25, 110), 8], [MossBall.dir_ll(10, 28), 8]])

	# Long flowing grasses bending with the current; broad leaves; tall stems.
	var avoid := [[MossBall.dir_ll(15, -20), 9.0], [_vortex_dir(1, 2), 5.0], [_vortex_dir(1, 0), 5.0], [_vortex_dir(1, 4), 5.0],
			[MossBall.dir_ll(-25, 110.5), 6.0], [MossBall.dir_ll(-18, 110.2), 5.0], [MossBall.dir_ll(10, 28), 10.0]]
	var ok := func(dd: Vector3) -> bool: return not _near_any(dd, avoid) and b.ravine_carve(dd) < 0.1
	# The long grass grows in dense stands with open clearings between them (same number of
	# plants, so the stands are thicker), rather than an even carpet.
	var stands := _stands(20, -0.15)
	var ok_tall := func(dd: Vector3) -> bool: return ok.call(dd) and stands.call(dd)
	var grass := b.make_veg_material(Color(0.07, 0.36, 0.18), Color(0.45, 0.8, 0.32),
			Vegetation.family_params("tall", 3.0).merged({"sway": 0.3, "sway_speed": 1.8, "cam_fade": 2.0}, true))
	b.scatter(MeshLib.tuft_mesh(4, 0.1, 3.0, 0.15, 4, 6, 0.2), grass, 6000, 21, 0.7, 1.4, ok_tall)
	var short := b.make_veg_material(Color(0.06, 0.32, 0.16), Color(0.3, 0.66, 0.34), Vegetation.family_params("short", 0.4).merged({"sway": 0.2}, true))
	b.scatter(MeshLib.tuft_mesh(5, 0.07, 0.4, 0.12, 5, 3, 0.3), short, 9000, 22, 0.8, 1.3)
	# (Owner reference: "fire and ice" hosta leaves, a white centre with green margins.)
	var ice := b.make_veg_material(Color(0.06, 0.32, 0.16), Color(0.3, 0.66, 0.34), Vegetation.family_params("short", 0.4).merged({"sway": 0.2,
			"variegate": 1.0, "vari_style": 1.0, "vari_stripe": Color(0.94, 0.96, 0.9)}, true))
	b.scatter(MeshLib.broadleaf_mesh(4, 0.9, 7), ice, 700, 23, 1.0, 1.6, ok)
	var rng := RandomNumberGenerator.new()
	rng.seed = 24
	for k in 90:
		var lat := rng.randf_range(-70, 70)
		var lon := rng.randf_range(-180, 180)
		var dd := MossBall.dir_ll(lat, lon)
		if _near_any(dd, avoid + [[MossBall.dir_ll(72, 110), 14.0]]):
			continue
		var h := rng.randf_range(5.0, 9.0)
		lb.stem_xf(b.xform_on_dir(dd, 0.0, rng.randf() * 360.0), h, 0.18, 0.1, false, rng.randf_range(0.02, 0.08))
		# A drooping frond, not a flat leaf: out of reach, so it must not look like a platform.
		lb.leaf_xf(b.xform_on_dir(dd, h - 0.3, rng.randf() * 360.0).rotated_local(Vector3.RIGHT, deg_to_rad(-55.0)), rng.randf_range(1.8, 2.8),
				rng.randf_range(1.2, 1.8) * 0.45, false)
	# World expansion: the Kelp Fields' tall stands, and coral under the Undercut Hollows' shelves.
	var clear2 := _veg_keep_clear(lb, [[MossBall.dir_ll(-25, 110.5), 6.0], [MossBall.dir_ll(-18, 110.2), 5.0]])
	Vegetation.field(b, "tall", MossBall.dir_ll(-42, -150), 12.0, 1300, 201, {"avoid": clear2, "clumps": 9, "fill": 0.4, "edge": 0.6})
	Vegetation.field(b, "medium", MossBall.dir_ll(-25, 124), 9.0, 380, 202, {"avoid": clear2, "clumps": 5})
	var hol := MossBall.dir_ll(8, 30)
	var in_hollows := func(dd: Vector3) -> bool: return dd.angle_to(hol) < deg_to_rad(13.0) and not clear2.call(dd)
	for k in 2:
		var col: Array = ACCENTS[1][k]
		var cmat := b.make_veg_material(col[0], col[1], Vegetation.family_params("short", 0.45).merged({"sway": 0.12, "wake_gain": 0.7, "cam_fade": 1.0}, true))
		b.coral_nodes += b.scatter(MeshLib.coral_mesh(5 + k * 2, 0.75 + k * 0.15, 960 + k), cmat, 220, 960 + k, 1.1, 2.4, in_hollows, 70.0)


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


## Moss Ball #3's spiral canopy climb around the giant stem. Every step is a plain jump with room
## to spare (jump apex 1.85 m; the water burst is extra help, not a requirement), and the first
## leaf is low enough to get onto from the ground. Owner playtest: the old 1.5 m start and 1.6 m
## steps needed a precise jump + burst every time, and a child could not start the climb.
const SPIRAL_LEAVES := 16
const SPIRAL_START := 0.8
const SPIRAL_RISE := 1.0
## Expansion 6: a quarter turn per leaf (was 72 degrees), so the broad leaves stand clear of their
## neighbours. The phase keeps the leaves at 5.8 and 6.8 m out from under the lower canopy's
## flexible leaf F1 (it dips about 2 m when landed on), and keeps the last two jumps clear of the
## big canopy leaves above (C3 spans about -10..50 degrees, C1 87..153): the spiral ends at 325
## degrees, one hop from C3, and C1 is one hop on from C3.
const SPIRAL_TURN := 90.0
const SPIRAL_PHASE := 55.0
## Expansion 6 (owner phone report): broad leaves, room to land, turn and aim (was 1.9 m).
const SPIRAL_LEAF_W := 2.4


static func _ball3(lb: LevelBuilder) -> void:
	var b := lb.ball
	b.food_weights = [0.25, 0.3, 0.45]
	b.food_target = 16

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
	for i in SPIRAL_LEAVES:
		# Four leaves per turn: a leaf is 4 m above the one below it, so no leaf hangs low over
		# another (or under the lower canopy's flexible leaves); the last leaf ends beside C3.
		var a := deg_to_rad(SPIRAL_PHASE + i * SPIRAL_TURN)
		var h := SPIRAL_START + i * SPIRAL_RISE
		# Each leaf's base just clear of the tapering trunk, joined to it by its stalk.
		var rr := lerpf(1.1, 0.75, h / 19.0) + LevelBuilder.LEAF_CLEAR
		var xf := C.p(cos(a) * rr, h, sin(a) * rr, Site.yaw_out(cos(a), sin(a)))
		lb.leaf_xf(xf, 3.0, SPIRAL_LEAF_W)
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
	# Hanging roots under the big canopy leaves (visual). Each hangs from its top and swings a
	# little in the water on its own (the plant shader's ambient flutter).
	var root_mat := b.make_plant_material(lb.stem_mat.get_shader_parameter("healthy_a"), lb.stem_mat.get_shader_parameter("healthy_b"),
			{"flutter": 0.14, "flutter_speed": 0.7, "flutter_reach": 6.0})
	for xf in [c1, c2, c3]:
		for k in 5:
			var off := Vector3(randf_range(-1.0, 1.0), 0, -randf_range(1.0, 4.0))
			var top: Vector3 = (xf as Transform3D) * off
			var up := b.up_at(top)
			var len := randf_range(2.5, 6.0)
			var node := Node3D.new()
			lb.root.add_child(node)
			node.global_transform = Transform3D(MossBall.frame_at(-up, 0), top)
			var mi := MeshInstance3D.new()
			mi.mesh = MeshLib.stem_mesh(0.05, 0.03, len, 5)
			mi.material_override = root_mat
			node.add_child(mi)
	lb.parasite_xf(Parasite.Kind.MEDIUM, "canopy", leaf_mid(c2, 3.0, 0.5), 2.2)
	lb.parasite_xf(Parasite.Kind.SMALL, "canopy", leaf_mid(f1._pivot_xf, 2.0, 0.0), 1.2)
	lb.mote_xf("canopy", leaf_mid(c2, 1.8, -0.5), 0.5)
	lb.mote_xf("canopy", leaf_mid(c3, 3.6, 0.0), 0.5)
	# Beside the 7th spiral leaf, away from the lower canopy (Expansion 6's quarter-turn spiral).
	lb.mote_xf("canopy", leaf_mid(spiral[6], 2.2, 0.0), 0.6)
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
	# The same climb for the elevated-route audit: up the spiral, round the canopy leaves (the
	# bot's path), and the lower canopy's flexible leaves, reached by dropping from the spiral.
	var ctops := []
	for xf in spiral:
		ctops.append(leaf_mid(xf, 1.5, 0.0).origin)
	for lm in [[c3, 1.0], [c3, 3.2], [c3, 0.8], [c1, 0.8], [c1, 2.6], [c1, 3.8], [c1b, 1.6], [c2, 1.2], [c2, 3.8]]:
		ctops.append(leaf_mid(lm[0], lm[1], 0.0).origin)
	var cstart := b.surface_point(b.up_at(leaf_mid(spiral[0], 4.4, 0.0).origin))
	lb.bot_hints.append({"route": "canopy", "audit": true, "start": cstart, "tops": ctops, "zones": ["canopy"], "goal": "canopy"})
	var fl := [leaf_mid(f1._pivot_xf, 1.7, 0.0).origin, leaf_mid(f2._pivot_xf, 1.6, 0.0).origin]
	var near_leaf: Vector3 = ctops[0]
	for q in ctops.slice(0, spiral.size()):
		if (q as Vector3).distance_to(fl[0]) < near_leaf.distance_to(fl[0]) and b.altitude(q) > b.altitude(fl[0]):
			near_leaf = q
	lb.bot_hints.append({"route": "lower canopy", "audit": true, "branch": true, "start": near_leaf, "tops": fl, "zones": ["canopy"], "goal": "flexible leaves"})

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
	lb.parasite(Parasite.Kind.MEDIUM, "far", 10, 176, 10.0).make_spitter()
	lb.mote("far", -25, 150)
	lb.mote("far", 4, -170)
	lb.bloom(-5, 148)

	lb.freeze_ids()

	# ---- World expansion: Giant Stems at radius 60 ---------------------------------------------
	lb.zone("crown", 45, 112, 16)
	lb.zone("tangle", -66, -100, 16)
	# The Great Trunk: a 30 m giant laddered all the way up to the High Crown, broad leaves round
	# its top with a Mote and a bloom (the view across the whole aquarium).
	var gt_dir := MossBall.dir_ll(45, 112)
	var gxf := b.xform_on_dir(gt_dir, 0.0, 30.0)
	var crown_h := 30.0
	# (A trunk this thick takes a gentler spiral than a jungle stem: 60 degrees and 1.3 m a leaf,
	# so each is a plain jump from the last; the top three are the crown's broad leaves.)
	lb.stem_xf(gxf, crown_h, 1.8, 1.1, true, 0.0001)
	var glevels := []
	var gy := LADDER_START
	var gh := 20.0
	while gy < crown_h - 0.6:
		glevels.append([gy, LADDER_LEAF_LEN, LADDER_LEAF_W, gh])
		# (Turning just enough that neighbours are clear of each other: less where it is thick.)
		gh += lerpf(75.0, LADDER_TURN, gy / crown_h)
		gy += 1.0
	for k in 3:
		var lv: Array = glevels[glevels.size() - 1 - k]
		glevels[glevels.size() - 1 - k] = [lv[0], 3.8, 2.8, lv[3]]
	lb.ladder_stem(gxf, crown_h, 1.8, 1.1, 0.0001, glevels, 20.0, 0.0, "great trunk")
	var groute: Dictionary = lb.bot_hints[lb.bot_hints.size() - 1]
	groute.erase("audit")
	groute["zones"] = ["crown"]
	var gtops: Array = groute["tops"]
	var crown_top: Vector3 = gtops[gtops.size() - 1]
	lb.mote_xf("crown", Transform3D(MossBall.frame_at(b.up_at(crown_top), 0.0), crown_top + b.up_at(crown_top) * 0.6), 0.4)
	var crown_mid: Vector3 = gtops[gtops.size() - 3]
	lb.bloom_xf(Transform3D(MossBall.frame_at(b.up_at(crown_mid), 0.0), crown_mid))
	lb.parasite(Parasite.Kind.MEDIUM, "crown", 41, 104, 4.0)
	lb.parasite(Parasite.Kind.SMALL, "crown", 50, 124, 4.0)
	lb.mote("crown", 38, 118)
	# The canopy shortcut: once the lower jungle heals, a bubble column beside the giant spiral
	# lifts him to its eighth leaf, halfway up.
	var sp8: Transform3D = spiral[8]
	var sp8_mid := leaf_mid(sp8, 2.2, 0.0)
	# (Between the spiral's lines of leaves, at 100 degrees round the stem: clear of every leaf
	# below it, and away from where the climb starts.)
	var col_at := C.p(cos(deg_to_rad(100.0)) * 5.5, 0, sin(deg_to_rad(100.0)) * 5.5).origin
	var col_dir := b.up_at(col_at)
	lb.bubble_column(col_dir, 0.9, b.altitude(sp8_mid.origin) + 1.4, 5.5, "lower")
	lb.bot_hints.append({"route": "canopy column", "audit": true, "lift": true, "start": b.surface_point(col_dir),
			"tops": [b.surface_point(col_dir, b.altitude(sp8_mid.origin) + 1.0), sp8_mid.origin], "zones": [], "goal": "halfway up the giant spiral"})
	# The Root Tangle on the underside: old roots arching over one another into low tunnels, Motes
	# in the shade beneath and on top.
	var tangle := [[-60, -112, -70, -92], [-72, -114, -60, -90], [-58, -98, -74, -104], [-66, -120, -66, -82]]
	for ta in tangle:
		lb.arch(ta[0], ta[1], ta[2], ta[3], 1.7, 2.2, 0.9)
	lb.parasite(Parasite.Kind.SMALL, "tangle", -62, -96, 3.5)
	lb.parasite(Parasite.Kind.MEDIUM, "tangle", -70, -108, 3.5)
	lb.parasite(Parasite.Kind.SMALL, "tangle", -56, -110, 3.5)
	lb.mote("tangle", -66, -101)
	lb.mote("tangle", -60, -86)
	lb.mote("tangle", -74, -96)
	lb.bloom(-64, -120)
	# More of the lower and far jungle.
	lb.parasite(Parasite.Kind.SMALL, "lower", 38, 30, 5.0)
	lb.parasite(Parasite.Kind.SMALL, "far", 20, 140, 5.0)
	lb.mote("lower", 14, 44)
	lb.mote("far", -30, 176)
	lb.mote("far", 26, -150)

	for r in [[0, 65, 26], [25, 20, 26], [-40, 0, 30], [-10, 160, 32], [8, -60, 20], [45, 112, 14], [-66, -100, 14]]:
		lb.food_region(r[0], r[1], r[2])
	_holes(lb, 32, 303, [[MossBall.dir_ll(28, -30), 8], [drop_dir, 6], [MossBall.dir_ll(-46, 8), 14], [gt_dir, 6], [MossBall.dir_ll(-66, -100), 12]])

	# --- Dense jungle: towering stems with leaves, tall blades, ferns. Clearings kept open.
	var keep := [[MossBall.dir_ll(28, -30), 16.0], [drop_dir, 9.0], [_vortex_dir(2, 1), 9.0], [MossBall.dir_ll(-46, 8), 18.0], [_vortex_dir(2, 5), 9.0],
			[MossBall.dir_ll(5, 70), 4.0], [MossBall.dir_ll(-27, 22), 4.0], [MossBall.dir_ll(-5, 148), 4.0],
			[gt_dir, 12.0], [MossBall.dir_ll(-66, -100), 18.0], [col_dir, 5.0]]
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var made := 0
	var placed := []
	while made < 140:
		var lat := rng.randf_range(-78, 78)
		var lon := rng.randf_range(-180, 180)
		var dd := MossBall.dir_ll(lat, lon)
		# Stems stand apart, so each one's ladder of leaves is its own (none hangs over another's).
		if _near_any(dd, keep) or _near_any(dd, placed):
			continue
		placed.append([dd, rad_to_deg(9.0 / b.radius)])
		made += 1
		var h := rng.randf_range(8.0, 20.0)
		var sxf := b.xform_on_dir(dd, 0.0, rng.randf() * 360.0)
		var r0 := rng.randf_range(0.35, 0.9)
		var r1 := rng.randf_range(0.2, 0.4)
		var bend := rng.randf_range(0.0, 0.04)
		lb.stem_xf(sxf, h, r0, r1, true, bend)
		# Big overhead leaves obscure the aquarium beyond...
		var big := []
		for k in rng.randi_range(2, 4):
			var y := h * rng.randf_range(0.5, 0.98)
			rng.randf()
			big.append([y, rng.randf_range(3.0, 5.5), rng.randf_range(2.0, 3.4)])
		# ...and every stem is a ladder up to them (owner phone report: leaves that look like
		# platforms must be reachable): a leaf 0.9 m up to start, then one plain jump per leaf.
		_jungle_ladder(lb, sxf, h, r0, r1, bend, big, made)
	# Ferns and tall blades stay back from each ladder's first leaves, so they can be seen from the
	# ground.
	var ladder_feet := []
	for e in placed:
		ladder_feet.append([e[0], rad_to_deg(3.8 / b.radius)])
	var ok := func(dd: Vector3) -> bool: return not _near_any(dd, keep.slice(0, 5)) and not _near_any(dd, ladder_feet)
	var stands := _stands(30, -0.2)
	var ok_tall := func(dd: Vector3) -> bool: return ok.call(dd) and stands.call(dd)
	var tall := b.make_veg_material(Color(0.06, 0.3, 0.06), Color(0.4, 0.7, 0.16), Vegetation.family_params("tall", 4.2).merged({"cam_fade": 2.4}, true))
	b.scatter(MeshLib.tuft_mesh(3, 0.18, 4.2, 0.2, 5, 6, 0.25), tall, 4000, 31, 0.8, 1.4, ok_tall)
	var fern := b.make_veg_material(Color(0.05, 0.28, 0.06), Color(0.3, 0.62, 0.14), Vegetation.family_params("medium", 1.2).merged({"sway": 0.16, "cam_fade": 1.6, "wake_gain": 0.8,
			"variegate": 0.8, "vari_style": 0.0, "vari_edge": Color(0.9, 0.42, 0.55), "vari_stripe": Color(0.88, 0.93, 0.7)}, true))
	b.scatter(MeshLib.broadleaf_mesh(7, 1.4, 6), fern, 1500, 32, 1.0, 1.8, ok)
	var short := b.make_veg_material(Color(0.05, 0.26, 0.05), Color(0.3, 0.6, 0.14), Vegetation.family_params("short", 0.4))
	b.scatter(MeshLib.tuft_mesh(5, 0.07, 0.4, 0.12, 8, 3, 0.3), short, 9000, 34, 0.8, 1.3)
