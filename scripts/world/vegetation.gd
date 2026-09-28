class_name Vegetation
## Reusable aquatic vegetation: families and placement (docs/VEGETATION.md). Everything is
## instanced (MultiMesh, no per-plant nodes, scripts or collision) and moves in the vegetation
## shader: ambient sway, current, water impulses and the wake of movers (Wake).
##
## Families: "short" (ankle-high growth, a subtle local response), "medium" (reaches into the
## axolotl's body, parts and recovers around him), "tall" (dense reeds that can hide him; the moving
## plants show where he is). Placement: field (a patch with natural clumps and a soft edge),
## corridor (a band along a path), both with keep-out rules so paths, caves, blooms, holes and
## platforms stay readable. New moss balls use these rather than hand-scattered meshes.

const FAMILIES := {
	"short": {"blades": 5, "width": 0.07, "height": 0.38, "spread": 0.12, "segs": 3, "curve": 0.3, "reed": false,
			"sway": 0.1, "wake_gain": 0.45, "cam_fade": 1.2, "scale": [0.8, 1.35], "vis": 70.0},
	"medium": {"blades": 5, "width": 0.11, "height": 0.95, "spread": 0.18, "segs": 3, "curve": 0.28, "reed": true,
			"sway": 0.13, "wake_gain": 1.0, "cam_fade": 1.6, "scale": [0.75, 1.3], "vis": 55.0},
	"tall": {"blades": 5, "width": 0.15, "height": 2.2, "spread": 0.22, "segs": 4, "curve": 0.2, "reed": true,
			"sway": 0.16, "wake_gain": 1.25, "cam_fade": 2.2, "scale": [0.8, 1.3], "vis": 65.0},
}


## The shader parameters that make an existing vegetation material behave as a family (its
## response to the wake and its height, so movers passing over it do not bend it).
static func family_params(family: String, height := -1.0) -> Dictionary:
	var f: Dictionary = FAMILIES[family]
	return {"sway": f["sway"], "wake_gain": f["wake_gain"], "cam_fade": f["cam_fade"],
			"plant_height": f["height"] if height < 0.0 else height}


static func material(ball: MossBall, family: String, colors: Array = []) -> ShaderMaterial:
	var a: Color = colors[0] if colors.size() > 0 else ball.palette.get("moss_healthy_a", Color(0.1, 0.35, 0.1))
	var b: Color = colors[1] if colors.size() > 1 else ball.palette.get("moss_healthy_b", Color(0.45, 0.75, 0.25))
	return ball.make_veg_material(a, b, family_params(family))


## Two mesh variants per family (different clumps), so a patch never repeats one clump.
static func meshes(family: String, seed_v: int) -> Array:
	var f: Dictionary = FAMILIES[family]
	var out := []
	for v in 2:
		var n: int = f["blades"] + v
		if f["reed"]:
			out.append(MeshLib.reed_clump(n, f["width"], f["height"], f["spread"], seed_v * 31 + v, f["segs"], f["curve"]))
		else:
			out.append(MeshLib.tuft_mesh(n, f["width"], f["height"], f["spread"], seed_v * 31 + v, f["segs"], f["curve"]))
	return out


## A patch of `family` centred on `dir` (a direction from the ball's centre), `radius_deg` across,
## about `count` plants, grouped in natural clumps with a thinning edge. opts:
##   clumps (int, default 7), clump_deg (clump spread, default radius/3), fill (0..1, share placed
##   evenly rather than in clumps, default 0.25), edge (where thinning starts, 0..1, default 0.6),
##   avoid (Callable(dir) -> true to keep a spot clear), material, colors.
## Deterministic for a seed; uses its own random generator (never the global one).
static func field(ball: MossBall, family: String, dir: Vector3, radius_deg: float, count: int, seed_v: int, opts := {}) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var centre := dir.normalized()
	var clumps: Array[Vector3] = []
	for k in int(opts.get("clumps", 7)):
		clumps.append(_offset(centre, rng.randf() * radius_deg * 0.8, rng.randf() * 360.0))
	var clump_deg: float = opts.get("clump_deg", radius_deg / 3.0)
	var fill: float = opts.get("fill", 0.25)
	var edge: float = opts.get("edge", 0.6)
	var avoid: Callable = opts.get("avoid", Callable())
	var dirs: Array[Vector3] = []
	var tries := 0
	while dirs.size() < count and tries < count * 8:
		tries += 1
		var d: Vector3
		if rng.randf() < fill or clumps.is_empty():
			d = _offset(centre, sqrt(rng.randf()) * radius_deg, rng.randf() * 360.0)
		else:
			d = _offset(clumps[rng.randi() % clumps.size()], absf(rng.randfn()) * clump_deg, rng.randf() * 360.0)
		var r := rad_to_deg(d.angle_to(centre)) / radius_deg
		if r > 1.0 or rng.randf() < smoothstep(edge, 1.0, r):
			continue
		if avoid.is_valid() and avoid.call(d):
			continue
		dirs.append(d)
	return _plant(ball, family, dirs, rng, opts)


## A band of `family` along the great-circle path from `from_dir` to `to_dir`, `width_deg` wide.
static func corridor(ball: MossBall, family: String, from_dir: Vector3, to_dir: Vector3, width_deg: float, count: int, seed_v: int, opts := {}) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var a := from_dir.normalized()
	var b := to_dir.normalized()
	var avoid: Callable = opts.get("avoid", Callable())
	var dirs: Array[Vector3] = []
	var tries := 0
	while dirs.size() < count and tries < count * 8:
		tries += 1
		var t := rng.randf()
		var on := a.slerp(b, t)
		# Narrower at the ends, full width in the middle.
		var w := width_deg * (0.5 + 0.5 * sin(t * PI)) * 0.5
		var d := _offset(on, rng.randfn() * w * 0.6, rng.randf() * 360.0)
		if avoid.is_valid() and avoid.call(d):
			continue
		dirs.append(d)
	return _plant(ball, family, dirs, rng, opts)


static func _offset(d: Vector3, deg: float, heading: float) -> Vector3:
	var axis := MossBall.frame_at(d, heading).x
	return d.rotated(axis, deg_to_rad(deg)).normalized()


## Instances on the terrain (ball-local transforms, rooted slightly into the ground), split
## between the family's two mesh variants.
static func _plant(ball: MossBall, family: String, dirs: Array[Vector3], rng: RandomNumberGenerator, opts: Dictionary) -> Array:
	var f: Dictionary = FAMILIES[family]
	var mat: ShaderMaterial = opts.get("material", null)
	if mat == null:
		mat = material(ball, family, opts.get("colors", []))
	var variants := meshes(family, rng.randi() % 100000)
	var lists := [[], []]
	var sc: Array = f["scale"]
	for d in dirs:
		var s := rng.randf_range(sc[0], sc[1])
		var bs := MossBall.frame_at(d, rng.randf() * 360.0).scaled(Vector3(s, s * rng.randf_range(0.85, 1.15), s))
		lists[rng.randi() % 2].append(Transform3D(bs, d * (ball.radius + ball.terrain_height(d) - 0.05)))
	var out := []
	for v in 2:
		var list: Array = lists[v]
		if list.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = variants[v]
		mm.instance_count = list.size()
		for j in list.size():
			mm.set_instance_transform(j, list[j])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Veg_%s" % family
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = f["vis"]
		mmi.visibility_range_end_margin = 10.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		mmi.set_meta("veg_family", family)
		MossBall.tag_chunk(mmi, list)
		# The placements, readable without a renderer (tests; headless runs keep no instance data).
		var xfs: Array[Transform3D] = []
		xfs.assign(list)
		mmi.set_meta("veg_transforms", xfs)
		ball.add_vegetation(mmi)
		out.append(mmi)
	return out


# --- Ambient motion (CPU mirrors of the shaders, for the tests) -------------------------------

## The ambient part of a vegetation plant's bend (shaders/vegetation.gdshader: sway, swell and the
## blade's own flutter; not the current, impulses or wake) at time `t`, for a plant rooted at `base`
## (world) on a ball whose centre is `centre`, for the blade whose vertex tint is `tint_r`.
## `hlt` is the moss health there. Keep in step with the shader.
static func ambient_bend(base: Vector3, centre: Vector3, tint_r: float, t: float, sway: float, sway_speed: float, hlt := 1.0) -> Vector3:
	var up := (base - centre).normalized()
	var hsh := _fract(sin(base.dot(Vector3(12.9898, 78.233, 37.719))) * 43758.5453)
	var ph := hsh * TAU
	var pace := sway_speed * lerpf(0.8, 1.25, _fract(hsh * 7.31))
	var side := up.cross(Vector3(0.31 + hsh, 0.87, 0.42 - hsh).normalized()).normalized()
	var side2 := up.cross(side)
	var amp := lerpf(0.75, 1.25, _fract(hsh * 13.7))
	var gust := 0.8 + 0.2 * sin(base.dot(Vector3(0.21, 0.17, 0.23)) - t * 0.45 + hsh * 2.5)
	var h := lerpf(0.35, 1.0, hlt)
	var bend := (side * sin(t * pace + ph) + side2 * cos(t * pace * 0.73 + ph * 1.7) * 0.5) * sway * amp * h * gust
	var bph := _fract(tint_r * 41.3) * TAU + ph
	bend += (side * sin(t * pace * 1.7 + bph) + side2 * cos(t * pace * 1.35 + bph * 1.3)) * sway * 0.45 * h
	return bend


## A platform or ladder leaf's ambient flap at its tip (shaders/plant.gdshader, leaf_data) at time
## `t`: along the leaf's up, in metres. `leaf_ph` is its CUSTOM0.w (MeshLib.leaf_phase), `node_at`
## the origin of the mesh it is in. Keep in step with the shader.
static func leaf_flutter(leaf_ph: float, node_at: Vector3, t: float, flutter: float, speed: float) -> float:
	var node_ph := _fract(sin(node_at.dot(Vector3(12.9898, 78.233, 37.719))) * 43758.5453)
	var ph := _fract(leaf_ph + node_ph)
	var pace := speed * lerpf(0.75, 1.3, _fract(ph * 7.31))
	var amp := flutter * lerpf(0.6, 1.25, _fract(ph * 3.17))
	return (sin(t * pace + ph * TAU) * 0.75 + sin(t * pace * 2.37 + ph * 17.1) * 0.25) * amp


static func _fract(x: float) -> float:
	return x - floorf(x)
