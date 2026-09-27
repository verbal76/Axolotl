class_name AxolotlModel
extends Node3D
## Procedural axolotl, built and animated entirely in code.
## Local space: -Z forward, +Y up, origin on the ground under the body centre.
##
## The body is ONE smooth skinned mesh on an 11-bone spine (head end first), so it bends like
## a salamander: a travelling S-wave runs down the body when he moves, stronger toward the
## tail. Legs hang off spine bones (they ride the wave) and step in the diagonal salamander
## gait, timed to the body bends. The six feathery external gills (three per side, off the
## back of the head) are the diegetic health display.

const BODY_COLOR := Color(1.0, 0.64, 0.72)         # soft pink (head reads lightest)
const TOP_TINT := Color(0.97, 0.86, 0.9)           # multiplied in along the back
const FIN_COLOR := Color(1.0, 0.7, 0.78)
const FRECKLE_COLOR := Color(0.9, 0.42, 0.52)
const GILL_CORE := Color(0.98, 0.55, 0.55)
const GILL_EDGE := Color(1.0, 0.3, 0.52)
const GILL_FRINGE := Color(0.95, 0.1, 0.42)

## Spine bones (model-space z; bone 0 carries the head). BODY_Y is the spine height.
const BONE_Z := [-0.20, -0.10, 0.0, 0.10, 0.20, 0.31, 0.43, 0.55, 0.67, 0.79, 0.91]
const BODY_Y := 0.17
const FRONT_BONE := 1
const REAR_BONE := 4
## Gill order = health order: top pair, middle pair, low pair (L then R).
const GILL_SLOTS := [[-1.0, 0], [1.0, 0], [-1.0, 1], [1.0, 1], [-1.0, 2], [1.0, 2]]

var rig: Node3D
var skeleton: Skeleton3D
var head: Node3D
var eye_l: Node3D
var eye_r: Node3D
var mouth: Node3D
var gills: Array[Node3D] = []
var gill_mats: Array[ShaderMaterial] = []
var legs: Array[Node3D] = []        # shoulder pivots: FL, FR, BL, BR
var _elbows: Array[Node3D] = []
var swipe_fx: MeshInstance3D
var _swipe_mat: ShaderMaterial
var _mouth_dark: MeshInstance3D
var _tongue: MeshInstance3D

# Animation state (written by the controller each frame).
var speed := 0.0            # 0..1 of run speed (can exceed 1 when boosted)
var grounded := true
var vup := 0.0
var swipe_t := -1.0         # 0..1 progress, -1 inactive
var swipe_side := 1.0
var lunge_t := -1.0
var burst_t := -1.0
var hurt_t := -1.0
var brace := 0.0            # dangerous fall telegraph 0..1
var surf := 0.0             # vortex surfing 0..1
var surf_bank := 0.0
var happy_t := -1.0
var perk_t := -1.0
var shake_t := -1.0
var land_t := -1.0
var land_variant := 0
var land_strength := 1.0
var look_target := Vector3.ZERO
var has_look := false
var camera_pos := Vector3.ZERO
var dissolve := 0.0          # 0 visible .. 1 gone

# Health display (on the gills).
var health := 3
var max_health := 3
var _flash := 0.0
var _fall_flicker := 0.0
var _gill_grow: Array[float] = [1, 1, 1, 0, 0, 0]

var _t := 0.0
var _wave := 0.0            # body-wave phase (advances with movement)
var _blink := 2.0
var _bone_rot: Array[Vector3] = []
var _land_pose := {}


func _ready() -> void:
	_build()


# --- construction -------------------------------------------------------------------------

func _m(c: Color, rough := 0.5, rim := 0.35) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if rim > 0.0:
		m.rim_enabled = true
		m.rim = rim
		m.rim_tint = 0.5
	return m


## Axolotl skin: a faint pink self-glow (like light through translucent skin) so the colour
## survives the murky green water.
func _skin(m: StandardMaterial3D) -> StandardMaterial3D:
	m.emission_enabled = true
	m.emission = m.albedo_color
	m.emission_energy_multiplier = 0.16
	return m


func _mesh(mesh: Mesh, mat: Material, parent: Node3D, pos := Vector3.ZERO, scl := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _ball(r: float, seg := 16) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = seg / 2
	return s


func _build() -> void:
	var body_mat := _skin(_m(BODY_COLOR, 0.34, 0.3))
	body_mat.vertex_color_use_as_albedo = true
	var head_mat := _skin(_m(BODY_COLOR, 0.32, 0.3))
	var fin_mat := _skin(_m(FIN_COLOR, 0.4, 0.5))
	fin_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	fin_mat.vertex_color_use_as_albedo = true

	rig = Node3D.new()
	add_child(rig)
	skeleton = Skeleton3D.new()
	skeleton.name = "Spine"
	rig.add_child(skeleton)
	for i in BONE_Z.size():
		skeleton.add_bone("s%d" % i)
		if i > 0:
			skeleton.set_bone_parent(i, i - 1)
		var rest := Vector3(0, BODY_Y, BONE_Z[0]) if i == 0 else Vector3(0, 0, BONE_Z[i] - BONE_Z[i - 1])
		skeleton.set_bone_rest(i, Transform3D(Basis(), rest))
		_bone_rot.append(Vector3.ZERO)
	skeleton.reset_bone_poses()
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _body_mesh()
	body.set_surface_override_material(0, body_mat)
	body.set_surface_override_material(1, fin_mat)
	skeleton.add_child(body)
	body.skin = skeleton.create_skin_from_rest_transforms()
	body.skeleton = body.get_path_to(skeleton)

	_build_head(head_mat)
	_build_legs(body_mat)

	# Water arc shown during the tail swipe (270-degree sweep around the back and sides).
	swipe_fx = MeshInstance3D.new()
	swipe_fx.mesh = _arc_mesh(1.55, 0.35)
	_swipe_mat = ShaderMaterial.new()
	_swipe_mat.shader = preload("res://shaders/swipe_arc.gdshader")
	swipe_fx.material_override = _swipe_mat
	swipe_fx.position = Vector3(0, 0.22, 0.05)
	swipe_fx.visible = false
	swipe_fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(swipe_fx)
	set_health(health, max_health, false)


## Linear interpolation through (z, value) keys.
static func _profile(keys: Array, z: float) -> float:
	if z <= keys[0][0]:
		return keys[0][1]
	for i in range(1, keys.size()):
		if z <= keys[i][0]:
			var a: Array = keys[i - 1]
			var b: Array = keys[i]
			return lerpf(a[1], b[1], smoothstep(a[0], b[0], z))
	return keys[keys.size() - 1][1]


const W_KEYS := [[-0.27, 0.11], [-0.18, 0.16], [-0.05, 0.205], [0.10, 0.225], [0.25, 0.19], [0.38, 0.125], [0.55, 0.085], [0.75, 0.05], [0.95, 0.022], [1.03, 0.006]]
const H_KEYS := [[-0.27, 0.10], [-0.18, 0.135], [-0.05, 0.16], [0.10, 0.165], [0.25, 0.15], [0.38, 0.12], [0.55, 0.10], [0.75, 0.08], [0.95, 0.045], [1.03, 0.012]]
const TOP_FIN := [[0.02, 0.0], [0.25, 0.018], [0.5, 0.06], [0.72, 0.085], [0.95, 0.075], [1.1, 0.0]]
const LOW_FIN := [[0.4, 0.0], [0.6, 0.035], [0.85, 0.05], [1.1, 0.0]]


func _weights(z: float) -> Array:
	if z <= BONE_Z[0]:
		return [0, 0, 1.0]
	for i in range(BONE_Z.size() - 1):
		if z <= BONE_Z[i + 1]:
			var t: float = (z - BONE_Z[i]) / (BONE_Z[i + 1] - BONE_Z[i])
			return [i, i + 1, 1.0 - t]
	var last := BONE_Z.size() - 1
	return [last, last, 1.0]


func _tail_drop(z: float) -> float:
	return -0.03 * maxf(0.0, z - 0.35)


## One continuous tapered body (surface 0) plus the dorsal/ventral tail fin sheet (surface 1),
## both skinned to the spine.
func _body_mesh() -> ArrayMesh:
	var am := ArrayMesh.new()
	var nz := 46
	var na := 20
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var bones := PackedInt32Array()
	var wts := PackedFloat32Array()
	for j in nz:
		var z := lerpf(-0.27, 1.03, float(j) / (nz - 1))
		var w := _profile(W_KEYS, z)
		var h := _profile(H_KEYS, z)
		var bw := _weights(z)
		for a in na:
			var ang := TAU * a / na
			var y := cos(ang) * h
			if y < 0.0:
				y *= 0.8   # flatter belly
			verts.append(Vector3(sin(ang) * w, BODY_Y + y + _tail_drop(z), z))
			var top := clampf(cos(ang) * 0.5 + 0.5, 0.0, 1.0)
			cols.append(Color.WHITE.lerp(TOP_TINT, top * top))
			uvs.append(Vector2(float(a) / na, float(j) / (nz - 1)))
			bones.append_array([bw[0], bw[1], 0, 0])
			wts.append_array([bw[2], 1.0 - bw[2], 0.0, 0.0])
	var idx := PackedInt32Array()
	for j in nz - 1:
		for a in na:
			var a1 := (a + 1) % na
			var p00 := j * na + a
			var p01 := j * na + a1
			var p10 := (j + 1) * na + a
			var p11 := (j + 1) * na + a1
			# Clockwise seen from outside (Godot front faces).
			idx.append_array([p00, p01, p11, p00, p11, p10])
	# Tail-tip cap.
	var tip := verts.size()
	var tz := 1.03
	var tw := _weights(tz)
	verts.append(Vector3(0, BODY_Y + _tail_drop(tz), tz + 0.01))
	cols.append(Color.WHITE)
	uvs.append(Vector2(0.5, 1.0))
	bones.append_array([tw[0], tw[1], 0, 0])
	wts.append_array([tw[2], 1.0 - tw[2], 0.0, 0.0])
	var last := (nz - 1) * na
	for a in na:
		idx.append_array([last + a, last + (a + 1) % na, tip])
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrays(verts, _normals(verts, idx), cols, uvs, bones, wts, idx))

	# Fin sheet: a thin double-sided membrane along the top of the back/tail and under the tail.
	var fv := PackedVector3Array()
	var fc := PackedColorArray()
	var fu := PackedVector2Array()
	var fb := PackedInt32Array()
	var fw := PackedFloat32Array()
	var fi := PackedInt32Array()
	for fin in [[TOP_FIN, 1.0], [LOW_FIN, -1.0]]:
		var keys: Array = fin[0]
		var dirv: float = fin[1]
		var start := fv.size()
		var steps := 30
		for k in steps + 1:
			var z := lerpf(keys[0][0], keys[keys.size() - 1][0], float(k) / steps)
			var fh := _profile(keys, z)
			var zc := minf(z, 1.03)
			var base_y := _profile(H_KEYS, zc) * (1.0 if dirv > 0.0 else 0.8)
			var bw := _weights(zc)
			var y0 := BODY_Y + _tail_drop(zc) + dirv * (base_y - 0.01)
			for row in [0.0, 1.0]:
				fv.append(Vector3(0, y0 + dirv * fh * row, z))
				fc.append(Color.WHITE.lerp(Color(1.0, 0.88, 0.9), row))
				fu.append(Vector2(row, float(k) / steps))
				fb.append_array([bw[0], bw[1], 0, 0])
				fw.append_array([bw[2], 1.0 - bw[2], 0.0, 0.0])
		for k in steps:
			var b0 := start + k * 2
			fi.append_array([b0, b0 + 1, b0 + 3, b0, b0 + 3, b0 + 2])
	var fn := PackedVector3Array()
	for v in fv:
		fn.append(Vector3.RIGHT)
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrays(fv, fn, fc, fu, fb, fw, fi))
	return am


static func _arrays(v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray, uv: PackedVector2Array,
		b: PackedInt32Array, w: PackedFloat32Array, idx: PackedInt32Array) -> Array:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_COLOR] = c
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_BONES] = b
	arr[Mesh.ARRAY_WEIGHTS] = w
	arr[Mesh.ARRAY_INDEX] = idx
	return arr


## Smooth vertex normals from face normals (outward for Godot's clockwise front faces).
static func _normals(v: PackedVector3Array, idx: PackedInt32Array) -> PackedVector3Array:
	var n := PackedVector3Array()
	n.resize(v.size())
	for i in range(0, idx.size(), 3):
		var a := v[idx[i]]
		var fnrm := (v[idx[i + 2]] - a).cross(v[idx[i + 1]] - a)
		for k in 3:
			n[idx[i + k]] += fnrm
	for i in n.size():
		n[i] = n[i].normalized() if n[i].length() > 0.0 else Vector3.UP
	return n


func _build_head(head_mat: StandardMaterial3D) -> void:
	var att := BoneAttachment3D.new()
	att.bone_name = "s0"
	skeleton.add_child(att)
	head = Node3D.new()
	head.position = Vector3(0, 0.035, -0.08)
	att.add_child(head)
	# Big, wide, rounded head.
	_mesh(_ball(0.2, 32), head_mat, head, Vector3(0, 0, -0.1), Vector3(1.36, 0.96, 1.12))
	# Freckles over the crown.
	var fparts := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 14:
		var ax := rng.randf_range(-0.55, 0.55)
		var az := rng.randf_range(-0.2, 0.75)
		var d := Vector3(sin(ax) * 1.36, cos(ax) * cos(az) * 0.96, -sin(az) * 1.12).normalized()
		var p := Vector3(d.x * 0.2 * 1.36, d.y * 0.2 * 0.96, d.z * 0.2 * 1.12) * 0.995 + Vector3(0, 0, -0.1)
		var r := rng.randf_range(0.008, 0.014)
		fparts.append([MeshLib.sphere(r, 6, 3), Transform3D(Basis().scaled(Vector3(1, 0.35, 1)), p)])
	_mesh(MeshLib.merge(fparts), _m(FRECKLE_COLOR, 0.5, 0.0), head)
	# Soft cheeks.
	var blush := _m(Color(1.0, 0.64, 0.68), 0.6, 0.0)
	_mesh(_ball(0.05), blush, head, Vector3(0.19, -0.06, -0.21), Vector3(1.0, 0.55, 0.6))
	_mesh(_ball(0.05), blush, head, Vector3(-0.19, -0.06, -0.21), Vector3(1.0, 0.55, 0.6))
	# Nostrils.
	var dark := _m(Color(0.45, 0.2, 0.25), 0.6, 0.0)
	_mesh(_ball(0.009, 8), dark, head, Vector3(0.045, 0.02, -0.315))
	_mesh(_ball(0.009, 8), dark, head, Vector3(-0.045, 0.02, -0.315))
	# Big glossy eyes set wide on the front of the face.
	var sclera := _m(Color(0.03, 0.04, 0.08), 0.06, 0.0)
	sclera.metallic_specular = 1.0
	var iris := _m(Color(0.55, 0.3, 0.1), 0.15, 0.0)
	var pupil := _m(Color(0.01, 0.01, 0.02), 0.1, 0.0)
	var shine := _m(Color.WHITE, 0.2, 0.0)
	shine.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_l = Node3D.new()
	eye_r = Node3D.new()
	for e in [[eye_l, -1.0], [eye_r, 1.0]]:
		var n: Node3D = e[0]
		var sx: float = e[1]
		n.position = Vector3(sx * 0.14, 0.055, -0.235)
		n.rotation = Vector3(0.05, -sx * 0.42, 0)
		head.add_child(n)
		_mesh(_ball(0.06, 20), sclera, n)
		_mesh(_ball(0.047, 16), iris, n, Vector3(0, 0, -0.03), Vector3(1, 1, 0.45))
		_mesh(_ball(0.032, 16), pupil, n, Vector3(0, 0, -0.043), Vector3(1, 1, 0.4))
		_mesh(_ball(0.016, 8), shine, n, Vector3(0.018, 0.024, -0.052))
		_mesh(_ball(0.008, 8), shine, n, Vector3(-0.014, -0.016, -0.056))
	# Wide smile: dark mouth + tongue, with an upper lip over the top edge -> a crescent.
	mouth = Node3D.new()
	mouth.position = Vector3(0, -0.085, -0.27)
	head.add_child(mouth)
	_mouth_dark = _mesh(_ball(0.1, 20), _m(Color(0.42, 0.1, 0.16), 0.7, 0.0), mouth, Vector3.ZERO, Vector3(1.25, 0.4, 0.5))
	_tongue = _mesh(_ball(0.06, 16), _m(Color(1.0, 0.5, 0.56), 0.5, 0.0), mouth, Vector3(0, -0.018, -0.008), Vector3(1.3, 0.35, 0.65))
	_mesh(_ball(0.1, 20), head_mat, mouth, Vector3(0, 0.03, 0.004), Vector3(1.32, 0.34, 0.54))
	# Six feathery external gills, three per side off the back of the head.
	for i in GILL_SLOTS.size():
		var side: float = GILL_SLOTS[i][0]
		var k: int = GILL_SLOTS[i][1]
		var g := Node3D.new()
		g.position = Vector3(side * 0.225, 0.095 - k * 0.08, 0.02 + k * 0.035)
		head.add_child(g)
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://shaders/gill.gdshader")
		mat.set_shader_parameter("phase", float(i) * 1.7)
		gill_mats.append(mat)
		var len: float = [0.37, 0.4, 0.33][k]
		_mesh(_gill_mesh(len, 0.085 - k * 0.008), mat, g)
		gills.append(g)


## Base gill direction (Euler) for slot k on a side: top pair fans up, middle out, low down.
static func _gill_base(side: float, k: int) -> Vector3:
	var out: float = [0.62, 1.2, 1.8][k]            # angle away from vertical, outward
	var back: float = [0.35, 0.45, 0.55][k]           # sweep toward the tail
	return Vector3(back, 0.0, -side * out)


## A tapered stalk with a leaf-shaped blade and fine filaments fringing both edges, in the
## local XY plane pointing up +Y (the node rotation aims it).
static func _gill_mesh(length: float, width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 12
	var pts: Array = []
	for i in n + 1:
		var t := float(i) / n
		var w := width * pow(sin(PI * clampf(t * 0.95 + 0.05, 0.0, 1.0)), 0.7) * (1.0 - 0.25 * t)
		pts.append([Vector3(0, t * length, 0), w, t])
	# Blade (two halves so the centre stays warm and the edge hot pink).
	for i in n:
		var a: Array = pts[i]
		var b: Array = pts[i + 1]
		for s in [-1.0, 1.0]:
			var q := [a[0], a[0] + Vector3(s * a[1], 0, 0), b[0] + Vector3(s * b[1], 0, 0), b[0]]
			var c := [GILL_CORE, GILL_EDGE, GILL_EDGE, GILL_CORE]
			var u := [Vector2(0, a[2]), Vector2(1, a[2]), Vector2(1, b[2]), Vector2(0, b[2])]
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_color(c[idx])
				st.set_uv(u[idx])
				st.set_normal(Vector3(0, 0, -1))
				st.add_vertex(q[idx])
	# Filaments: fine strands angled toward the tip, dense along both edges.
	var strands := 26
	for i in strands:
		var t := 0.08 + 0.9 * float(i) / (strands - 1)
		var y := t * length
		var w := width * pow(sin(PI * clampf(t * 0.95 + 0.05, 0.0, 1.0)), 0.7) * (1.0 - 0.25 * t)
		var fl := (0.035 + 0.05 * sin(PI * t)) * (length / 0.37)
		for s in [-1.0, 1.0]:
			var root := Vector3(s * w * 0.85, y, 0)
			var dir := Vector3(s * 0.8, 0.6, 0).normalized()
			var tip := root + dir * fl
			var side := Vector3(-dir.y, dir.x, 0) * 0.004
			var q := [root - side, root + side, tip + side * 0.3, tip - side * 0.3]
			var c := [GILL_EDGE, GILL_EDGE, GILL_FRINGE, GILL_FRINGE]
			var u := [Vector2(0.8, t), Vector2(0.8, t), Vector2(1.0, t), Vector2(1.0, t)]
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_color(c[idx])
				st.set_uv(u[idx])
				st.set_normal(Vector3(0, 0, -1))
				st.add_vertex(q[idx])
	return st.commit()


func _build_legs(body_mat: StandardMaterial3D) -> void:
	var skin := _skin(_m(BODY_COLOR, 0.36, 0.3))
	for i in 4:
		var front := i < 2
		var side := -1.0 if i % 2 == 0 else 1.0
		var att := BoneAttachment3D.new()
		att.bone_name = "s%d" % (FRONT_BONE if front else REAR_BONE)
		skeleton.add_child(att)
		var shoulder := Node3D.new()
		shoulder.position = Vector3(side * 0.15, -0.035, 0.0)
		att.add_child(shoulder)
		# Chubby upper limb splays out sideways; the elbow drops a short forearm to the ground.
		var upper_len := 0.12
		_mesh(MeshLib.capsule(0.043, upper_len + 0.07), skin, shoulder, Vector3(side * upper_len * 0.5, -0.012, 0), Vector3.ONE, Vector3(0, 0, side * 1.35))
		var elbow := Node3D.new()
		elbow.position = Vector3(side * upper_len, -0.03, 0)
		shoulder.add_child(elbow)
		_mesh(MeshLib.capsule(0.037, 0.11), skin, elbow, Vector3(side * 0.018, -0.04, -0.008), Vector3.ONE, Vector3(0.12, 0, side * 0.35))
		var hand := Node3D.new()
		hand.position = Vector3(side * 0.035, -0.095, -0.02)
		elbow.add_child(hand)
		_mesh(_hand_mesh(side, front), skin, hand)
		legs.append(shoulder)
		_elbows.append(elbow)


## Chubby four-fingered hand: flat palm, splayed fingers with round tips.
static func _hand_mesh(side: float, front: bool) -> ArrayMesh:
	var parts := [[MeshLib.sphere(0.042, 10, 5), Transform3D(Basis().scaled(Vector3(1.25, 0.5, 1.1)), Vector3.ZERO)]]
	var count := 4
	for f in count:
		var a := (-0.85 + f * 0.55) * (1.0 if front else 0.9) + side * 0.25
		var dir := Vector3(sin(a), 0, -cos(a))
		var mid := dir * 0.05
		parts.append([MeshLib.capsule(0.0135, 0.055), Transform3D(Basis.from_euler(Vector3(PI / 2, -a, 0)), mid + Vector3(0, -0.004, 0))])
		parts.append([MeshLib.sphere(0.017, 8, 4), Transform3D(Basis(), dir * 0.078 + Vector3(0, -0.004, 0))])
	return MeshLib.merge(parts)


## Water arc: annulus sector covering the 270 degrees behind and beside the body (+Z side).
func _arc_mesh(r_out: float, r_in: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 28
	var span := PI * 1.5
	for i in n:
		var a0 := -span / 2 + span * i / n
		var a1 := -span / 2 + span * (i + 1) / n
		var p := [Vector3(sin(a0) * r_in, 0, cos(a0) * r_in), Vector3(sin(a0) * r_out, 0, cos(a0) * r_out),
				Vector3(sin(a1) * r_out, 0, cos(a1) * r_out), Vector3(sin(a1) * r_in, 0, cos(a1) * r_in)]
		var uv := [Vector2(float(i) / n, 0), Vector2(float(i) / n, 1), Vector2(float(i + 1) / n, 1), Vector2(float(i + 1) / n, 0)]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(uv[k])
			st.add_vertex(p[k])
	return st.commit()


# --- Health (gills) -------------------------------------------------------------------------

func set_health(h: int, mx: int, flash := true) -> void:
	health = h
	max_health = mx
	if flash:
		_flash = 0.6


func fall_flicker() -> void:
	_fall_flicker = 1.2


## Gill i: active (i < health) glows and stands proud; lost (i < max_health) goes pale and
## droops; dormant (not yet unlocked) is a small pale bud until a cave upgrade grows it.
func _update_gills(dt: float, back: float, flap: float, flare: float) -> void:
	_flash = maxf(0.0, _flash - dt)
	_fall_flicker = maxf(0.0, _fall_flicker - dt)
	for i in gills.size():
		var side: float = GILL_SLOTS[i][0]
		var k: int = GILL_SLOTS[i][1]
		var unlocked := i < max_health
		_gill_grow[i] = move_toward(_gill_grow[i], 1.0 if unlocked else 0.0, dt * 1.5)
		var grow := _gill_grow[i]
		var active := i < health
		var droop := 0.0 if active else (0.55 if unlocked else 0.2)
		var sway := sin(_t * 2.3 + i * 1.3) * (0.1 + flap) + sin(_t * 15.0 + i) * flap * 0.35
		var base := _gill_base(side, k)
		var rot := base + Vector3(back * 0.9 + droop * 0.6 + sway * 0.4, side * sway * 0.3, side * (droop * 0.5 - flare * 0.35 + back * 0.15))
		gills[i].rotation = gills[i].rotation.lerp(rot, minf(1.0, dt * 12.0))
		gills[i].scale = Vector3.ONE * lerpf(0.72, 1.0, grow) * (0.9 if (unlocked and not active) else 1.0)
		var m := gill_mats[i]
		if active:
			var e := 0.34 + sin(_t * 2.0 + i) * 0.07
			if health == 1:
				# Irregular heartbeat-like pulse on the final gill.
				var p := pow(maxf(0.0, sin(_t * 5.3) * sin(_t * 2.1 + 1.3)), 3.0)
				e = 0.15 + p * 1.2 + (0.2 if fmod(_t, 1.7) < 0.08 else 0.0)
			e += _flash * 1.6
			if _fall_flicker > 0.0 and i == health - 1:
				e *= 0.2 + 1.8 * float(int(_t * 24.0) % 2)
			m.set_shader_parameter("glow", e)
			m.set_shader_parameter("desat", 0.0)
			m.set_shader_parameter("flutter", 1.0 + flap)
		elif unlocked:
			m.set_shader_parameter("glow", 0.0)
			m.set_shader_parameter("desat", 0.85)
			m.set_shader_parameter("flutter", 0.4)
		else:
			m.set_shader_parameter("glow", 0.0)
			m.set_shader_parameter("desat", 0.7)
			m.set_shader_parameter("flutter", 0.3)


# --- Animation ------------------------------------------------------------------------------

func play_land(variant: int, strength: float) -> void:
	land_variant = variant
	land_strength = strength
	land_t = 0.0


func _process(dt: float) -> void:
	_t += dt
	# The body wave advances with movement (and idles slowly), so it matches the ground speed.
	var s := clampf(speed, 0.0, 1.4)
	if grounded:
		_wave += dt * (1.2 + s * 10.5)
	else:
		_wave += dt * 7.0
	_advance_timers(dt)
	_animate(dt)


func _advance_timers(dt: float) -> void:
	if burst_t >= 0.0:
		burst_t += dt / 0.45
		if burst_t > 1.0: burst_t = -1.0
	if hurt_t >= 0.0:
		hurt_t += dt / 0.4
		if hurt_t > 1.0:
			hurt_t = -1.0
			shake_t = 0.0
	if happy_t >= 0.0:
		happy_t += dt / 1.2
		if happy_t > 1.0: happy_t = -1.0
	if perk_t >= 0.0:
		perk_t += dt / 0.8
		if perk_t > 1.0: perk_t = -1.0
	if shake_t >= 0.0:
		shake_t += dt / 0.5
		if shake_t > 1.0: shake_t = -1.0
	if land_t >= 0.0:
		land_t += dt / 0.9
		if land_t > 1.0: land_t = -1.0
	_blink -= dt
	if _blink < -0.12:
		_blink = randf_range(1.8, 4.5)


func _animate(dt: float) -> void:
	var s := clampf(speed, 0.0, 1.4)
	var rig_pos := Vector3.ZERO
	var rig_rot := Vector3.ZERO
	var rig_scale := Vector3.ONE
	var head_rot := Vector3.ZERO
	var eye_scale := Vector3.ONE
	var eye_l_scale := Vector3.ONE
	var mouth_open := 0.35
	# Body wave: amplitude per bone grows toward the tail; the head end stays steady.
	var wave_amp := 0.05 + 0.2 * minf(s * 1.3, 1.0)
	var wave_len := 0.62          # phase lag between neighbouring bones
	var arch := 0.0               # + arches the back (head and tail up)
	var tail_base := 0.0
	var gill_back := s * 0.45
	var gill_flare := 0.0
	var gill_flap := 0.1
	var leg_mode := 0   # 0 walk, 1 swim-tuck (air), 2 spread (brace/surf)

	rig_pos.y = sin(_wave * 2.0) * 0.01 * s + sin(_t * 1.6) * 0.005

	if not grounded:
		leg_mode = 1
		rig_rot.x = clampf(vup * 0.035, -0.4, 0.3)
		arch = clampf(-vup * 0.02, -0.12, 0.12)
		wave_amp = 0.2
		gill_back = maxf(gill_back, 0.6)
	if burst_t >= 0.0:
		var k := sin(burst_t * PI)
		wave_amp = 0.18 + 0.3 * k
		_wave += dt * 14.0 * k
		rig_scale = Vector3(0.94, 0.94, 1.0 + 0.18 * k)
		gill_back = 1.1
		mouth_open = 0.7
	if swipe_t >= 0.0:
		var k := swipe_t
		rig_rot.y += sin(k * PI) * 0.45 * swipe_side
		tail_base = lerpf(-1.0, 1.0, smoothstep(0.0, 1.0, k)) * swipe_side
		wave_amp = 0.04
	if lunge_t >= 0.0:
		var k := sin(clampf(lunge_t, 0.0, 1.0) * PI)
		rig_pos.z -= 0.16 * k
		rig_scale = Vector3(0.93, 0.93, 1.0 + 0.25 * k)
		head_rot.x = -0.22 * k
		mouth_open = 0.35 + 1.5 * k
		gill_back = 1.1
		leg_mode = 1
		wave_amp *= 0.3
	if brace > 0.0:
		leg_mode = 2
		gill_back = 1.0 + brace * 0.3
		eye_scale = Vector3.ONE * (1.0 + 0.35 * brace)
		rig_scale = Vector3(1.06, 0.88, 0.98)
		rig_rot.x = 0.22 * brace
		wave_amp = 0.05
		mouth_open = 0.9
	if surf > 0.0:
		leg_mode = 2
		rig_rot.z = surf_bank
		gill_back = 1.3
		mouth_open = 1.2
		eye_scale = Vector3(1.0, 0.55, 1.0)   # happy squint
		wave_amp = 0.18
		tail_base = -surf_bank * 0.4
	if hurt_t >= 0.0:
		var k := sin(hurt_t * PI)
		rig_rot.x -= 0.3 * k
		rig_rot.z += 0.22 * k
		rig_scale *= Vector3(1.08, 0.85, 0.96).lerp(Vector3.ONE, 1.0 - k)
		eye_scale = Vector3(1.0, 0.15, 1.0)
		mouth_open = 0.1
		arch = -0.15 * k
	if shake_t >= 0.0:
		var k := 1.0 - shake_t
		head_rot.y += sin(shake_t * 38.0) * 0.4 * k
		gill_flap = 0.6 * k
	if happy_t >= 0.0:
		var k := sin(happy_t * PI)
		rig_pos.y += absf(sin(happy_t * PI * 3.0)) * 0.07 * k
		rig_rot.z += sin(happy_t * 25.0) * 0.1 * k
		gill_flap = maxf(gill_flap, 0.5 * k)
		mouth_open = 0.35 + 0.8 * k
		eye_scale = Vector3(1.0, lerpf(1.0, 0.5, k), 1.0)
		wave_amp = maxf(wave_amp, 0.12 * k)
	if perk_t >= 0.0:
		var k := sin(perk_t * PI)
		head_rot.x -= 0.22 * k
		gill_flare = 0.6 * k
		eye_scale = eye_scale * (1.0 + 0.15 * k)
	if land_t >= 0.0:
		_animate_landing(dt)
		var l := _land_pose
		rig_pos += l["pos"]
		rig_rot += l["rot"]
		rig_scale *= l["scale"]
		head_rot += l["head"]
		if l["wink"]:
			eye_l_scale = Vector3(1.0, 0.12, 1.0)
		mouth_open = maxf(mouth_open, l["mouth"])
		gill_flap = maxf(gill_flap, l["flap"])
		wave_amp *= 0.4

	if has_look and land_t < 0.0 and swipe_t < 0.0:
		var local := to_local(look_target)
		head_rot.y += clampf(atan2(-local.x, -local.z), -0.7, 0.7)
	if _blink < 0.0:
		eye_scale.y *= 0.1

	rig.position = rig.position.lerp(rig_pos, minf(1.0, dt * 18.0))
	rig.rotation = rig.rotation.lerp(rig_rot, minf(1.0, dt * 14.0))
	rig.scale = rig.scale.lerp(rig_scale * (1.0 - dissolve), minf(1.0, dt * 16.0))
	head.rotation = head.rotation.lerp(head_rot, minf(1.0, dt * 12.0))
	eye_l.scale = eye_l.scale.lerp(eye_scale * eye_l_scale, minf(1.0, dt * 20.0))
	eye_r.scale = eye_r.scale.lerp(eye_scale, minf(1.0, dt * 20.0))
	var mo := 0.35 + mouth_open * 0.55
	_mouth_dark.scale = _mouth_dark.scale.lerp(Vector3(1.25, 0.18 + mo * 0.5, 0.5), minf(1.0, dt * 14.0))
	_tongue.position.y = lerpf(_tongue.position.y, -0.01 - mo * 0.02, minf(1.0, dt * 14.0))

	# Spine: travelling S-wave (relative bend per bone), plus swipe whip and back arch.
	var n := BONE_Z.size()
	for i in n:
		var f := float(i) / (n - 1)
		var amp := wave_amp * lerpf(0.12, 1.25, pow(f, 1.1))
		var yaw := sin(_wave - i * wave_len) * amp
		if swipe_t >= 0.0 and i >= 3:
			# Whip: the rear half sweeps across with a little lag down the chain.
			var lag := clampf(swipe_t * 1.25 - (i - 3) * 0.04, 0.0, 1.0)
			yaw += lerpf(-1.0, 1.0, smoothstep(0.0, 1.0, lag)) * swipe_side * 0.32 * (1.0 if i >= 5 else 0.5)
		elif i >= 5:
			yaw += tail_base * 0.12
		var pitch := arch * (1.0 if i >= 5 else -0.4) * 0.5
		if brace > 0.0 and i >= 5:
			pitch -= 0.06 * brace
		var target := Vector3(pitch, yaw, 0.0)
		_bone_rot[i] = _bone_rot[i].lerp(target, minf(1.0, dt * 18.0))
		if i == 0:
			continue   # the head stays aligned with the controller's facing
		skeleton.set_bone_pose_rotation(i, Quaternion.from_euler(_bone_rot[i]))

	_update_gills(dt, clampf(gill_back, 0.0, 1.4), gill_flap, gill_flare)
	_animate_legs(dt, s, leg_mode)

	if swipe_t >= 0.0:
		swipe_fx.visible = true
		_swipe_mat.set_shader_parameter("progress", swipe_t)
		_swipe_mat.set_shader_parameter("side", swipe_side)
	else:
		swipe_fx.visible = false


## Salamander gait: diagonal pairs (FL+BR, FR+BL) swing together, each leg protracting while
## lifted, timed to the body wave so the step and the body bend read as one motion.
func _animate_legs(dt: float, s: float, mode: int) -> void:
	var stride := minf(s * 1.4, 1.0)
	for i in legs.size():
		var front := i < 2
		var side := -1.0 if i % 2 == 0 else 1.0
		var diag := (i == 0 or i == 3)
		var ph := _wave - (FRONT_BONE if front else REAR_BONE) * 0.62 + (0.0 if diag else PI)
		var yaw := 0.0
		var roll := 0.0
		var bend := 0.0
		match mode:
			0:
				var swing := sin(ph) * 0.62 * stride
				var lift := maxf(0.0, cos(ph)) * 0.55 * stride
				yaw = side * swing * (1.0 if front else 0.85)
				roll = side * lift * 0.8
				bend = side * lift * 0.9
				# Idle: tiny weight shifts so he never looks frozen.
				roll += side * sin(_t * 1.3 + i) * 0.03 * (1.0 - stride)
			1:
				# Tucked back along the body like a swimming axolotl, paddling a little.
				yaw = side * (0.95 if front else 0.75) + side * sin(_t * 9.0 + i) * 0.12
				roll = side * 0.35
				bend = side * 0.6
			2:
				yaw = side * (-0.35 if front else 0.35)
				roll = side * (0.55 + sin(_t * 8.0 + i) * 0.08)
				bend = -side * 0.2
		if land_t >= 0.0 and land_variant == 0 and i == 1:
			var fist: Vector3 = _land_pose["fist"]
			yaw += fist.y
			roll += fist.z
			bend += fist.x * 0.5
		legs[i].rotation = legs[i].rotation.lerp(Vector3(0, yaw, roll), minf(1.0, dt * 14.0))
		_elbows[i].rotation = _elbows[i].rotation.lerp(Vector3(0, 0, bend), minf(1.0, dt * 14.0))


func _animate_landing(_dt: float) -> void:
	var t := land_t
	var squash := (1.0 - smoothstep(0.0, 0.25, t)) * 0.35 * land_strength
	var pose := {"pos": Vector3(0, -0.06 * squash, 0), "rot": Vector3.ZERO, "scale": Vector3(1.0 + squash * 0.5, 1.0 - squash, 1.0 + squash * 0.3),
			"head": Vector3.ZERO, "wink": false, "mouth": 0.0, "flap": 0.0, "fist": Vector3.ZERO}
	match land_variant:
		0:  # Tiny fist planted into the moss, chin up.
			var k := smoothstep(0.05, 0.2, t) * (1.0 - smoothstep(0.7, 1.0, t))
			pose["fist"] = Vector3(0.9 * k, 0.4 * k, 0.9 * k)
			pose["rot"] = Vector3(-0.2 * k, 0.15 * k, -0.18 * k)
			pose["head"] = Vector3(-0.25 * k, 0, 0)
			pose["mouth"] = 0.8 * k
		1:  # Head/gill shake.
			var k := smoothstep(0.2, 0.3, t) * (1.0 - smoothstep(0.75, 0.95, t))
			pose["head"] = Vector3(0, sin(t * 60.0) * 0.5 * k, 0)
			pose["flap"] = 0.8 * k
		2:  # Slightly awkward tip-over, immediately played off with a bounce.
			var tip := smoothstep(0.05, 0.25, t) * (1.0 - smoothstep(0.3, 0.45, t))
			var bounce := sin(clampf((t - 0.45) / 0.3, 0.0, 1.0) * PI)
			pose["rot"] = Vector3(0.1 * tip, 0, 0.55 * tip)
			pose["pos"] += Vector3(0, bounce * 0.1, 0)
			pose["head"] = Vector3(-0.3 * bounce, 0, 0)
			pose["mouth"] = 0.9 * bounce
		3:  # Glance at the camera and wink.
			var k := smoothstep(0.2, 0.35, t) * (1.0 - smoothstep(0.8, 1.0, t))
			var local := to_local(camera_pos)
			var yaw := clampf(atan2(-local.x, -local.z), -1.2, 1.2)
			pose["rot"] = Vector3(0, yaw * 0.35 * k, 0)
			pose["head"] = Vector3(-0.15 * k, yaw * 0.6 * k, 0)
			pose["wink"] = t > 0.35 and t < 0.75
			pose["mouth"] = 0.7 * k
	_land_pose = pose
