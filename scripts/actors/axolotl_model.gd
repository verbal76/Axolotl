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
const SKIN_SHADER := preload("res://shaders/axolotl_skin.gdshader")
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
## Free swimming (Swim Mode, docs/AQUARIUM.md): 0 off; above 0 the swimming gait, 1 relaxed, 2 fast.
## The body and tail undulate side to side (bigger and quicker with effort), the limbs paddle when
## slow and tuck back when fast, the gills sweep back with speed. `swim_turn` (rad/s of heading
## change) curves the body into a turn; `swim_pitch` tips it up or down as he climbs or dives.
var swim := 0.0
var swim_turn := 0.0
var swim_pitch := 0.0
var surf_bank := 0.0
var happy_t := -1.0
var perk_t := -1.0
var shake_t := -1.0
var land_t := -1.0
var land_variant := 0
var land_strength := 1.0
var look_target := Vector3.ZERO
var has_look := false
## v107 game feel (owner, 2026-10-08): presentation only. Everything below poses this visual rig;
## his collision is the sphere on the axolotl body, never this, and nothing here is read by play.
var soft_land_t := -1.0
var soft_land_k := 0.0
var takeoff_t := -1.0
var gulp_t := -1.0
var gulp_k := 0.0
var teeter_t := -1.0
## 0..1: the shimmer weight while his existing post-hit invulnerability runs (Juice reads
## Axolotl.invuln_t and sets this; no timer of its own).
var invuln := 0.0
var _look_w := 0.0
var _grow_i := -1
var _grow_k := 1.0
var _skin_glow := 0.08
var camera_pos := Vector3.ZERO
var dissolve := 0.0          # 0 visible .. 1 gone

# Health display (on the gills).
var health := 3
var max_health := 3
var _flash := 0.0
var _fall_flicker := 0.0

var _t := 0.0
var _wave := 0.0            # body-wave phase (advances with movement)
var _blink := 2.0
var _bone_rot: Array[Vector3] = []
var _land_pose := {}
## Cosmetic randomness (blinks, idle choice and timing): its own generator, so animation never
## moves the global random sequence gameplay uses.
var _fx := RandomNumberGenerator.new()

# Tail whip (physical playtest of dev-000024: the drawn arc swept 270 degrees while the tail barely
# moved). The whip runs on its own clock from the swipe press: a short cock to one side, the strike
# (the hips lead, the bend travels down the tail, which stretches out), follow-through past the far
# side, then recovery. The tail tip passes straight behind him at the hit frame (0.09 s: the
# swipe's timing, reach and damage are unchanged), and the water arc's bright head rides the tip.
const WHIP_LEN := 0.55
const WHIP_HIT_S := 0.09          # Axolotl.SWIPE_TIME * 0.3: the frame the hit registers
var _whip_s := -1.0
var _whip_side := 1.0
var _prev_swipe_t := -1.0
var whip_tip_az := 0.0            # the tail tip's direction round his body (0 = straight behind)

# Idles (physical playtest of dev-000024): standing still, now and then he does one of five
# little things (the owner added the look-up). Purely the model: the gameplay body, its collision and the camera never move.
enum Idle { NONE = -1, LOOKAROUND, SCOOT, TILT, STRETCH, LOOKUP, DANCE }
const IDLE_LEN := [4.6, 3.8, 2.8, 3.4, 3.4, 2.8]
## The idles he picks himself (the dance is only for Treasure Hunt finds).
const IDLE_RANDOM := 5
## When the stretch's yawn sounds (seconds into it).
const YAWN_AT := 0.38
const IDLE_FIRST := Vector2(4.0, 8.0)     # first idle after he stops
const IDLE_GAP := Vector2(7.0, 16.0)      # between idles while he stays still
var idle_ok := false                      # set by the controller: nothing else going on
var idle_kind: int = Idle.NONE
var idle_s := 0.0
var idle_side := 1.0
var idle_count := 0
var _idle_wait := -1.0
var _still_s := 0.0
var _idle_last: int = Idle.NONE
var _idle_stride := 0.0
var yawns := 0                   # yawn sounds played (tests)
var _skin_mats: Array[ShaderMaterial] = []
var _cheek_mat: StandardMaterial3D
var _leg_idle: Array = []
var _leg_idle_w := 0.0
var _leg_swing := 1.0

# Follow-through (Mote Open Issue #1): the head leads, the body follows, the tail completes the
# motion. Each spine segment (bone i to bone i + 1) keeps its own direction in the world and swings
# after the segment ahead of it: quickly when he is moving, so the body lies along the path his head
# took (the lag of each segment is its length over his speed), and more slowly when he turns on the
# spot (a C-bend that then straightens). The head segment always points where the controller faces.
# Pitch follows the same way in the air and in the water; on the ground each segment lies along the
# ground under it (FOLLOW_RAYS rays), so the body drapes over crests and dips and climbs onto a slope
# front first. All of it is the model: the gameplay body, its collision and its controls are untouched.
## Per-segment follow rate (1/s): turning on the spot; moving, speed / FOLLOW_SEG. (Second pass,
## after the phone playtest of dev-000033: with a lag of exactly the path, 0.12 m, the body in
## ordinary turns bent no more than the gait's own S-wave and read as rigid from the gameplay camera.
## Now each segment trails its neighbour by about 0.035 s at a run, so the bend travels visibly
## from the head down to the tail, about a third of a second end to end, and the rear swings out
## through a turn before it settles.)
const FOLLOW_RATE_MIN := 8.0
const FOLLOW_SEG := 0.22
const FOLLOW_RATE_MAX_SPEED := 6.2
## Airborne, the body follows the head's rise and fall at this rate (1/s), not with its speed.
const FOLLOW_AIR_RATE := 9.0
## Largest bend between neighbouring segments (radians), sideways and up/down.
const FOLLOW_MAX_YAW := 0.5
const FOLLOW_MAX_PITCH := 0.5
## While he keeps turning (rad/s), each joint holds this much bend (s) into the curve, up to
## FOLLOW_CURVE_MAX (radians): at a turn of 1 rad/s, about 30 degrees head to tail.
const FOLLOW_CURVE := 0.055
const FOLLOW_CURVE_MAX := 0.11
## The head leads into a turn: it looks round ahead of the body by this much of the turn still to
## come (turn_gap, radians, set by the controller) and of the rate of turning (rad/s).
const HEAD_LEAD_GAP := 0.75
const HEAD_LEAD_RATE := 0.14
const HEAD_LEAD_MAX := 0.6
## How quickly the body settles onto the ground under it (1/s).
const CONFORM_RATE := 16.0
## Where the ground is felt, along the body (model z): ahead of the chin, under the chin, the
## shoulders, the middle, the hips and the tail tip.
const FOLLOW_RAYS := [-0.55, -0.3, -0.05, 0.25, 0.55, 0.9]
## On (the player, the swimmer): off, the spine is laid straight along the model as before.
var follow := true
## Lay the body on the ground under it (the player on the ground; set by the controller each frame).
var conform := false
var conform_mask := 1 | 2 | 8
## Nose up (+) or down while airborne (radians), led by the head (set by the controller).
var air_pitch := 0.0
## The turn still to come (radians, + to the left), set by the controller: the head leads it.
var turn_gap := 0.0
## 0..1 while he crawls over a steep transition (set by the controller): the front reaches up for the
## purchase, the front feet reach and grip, the rear pushes.
var crawl := 0.0
## 0..1: the glide posture (skill tree): body flat and a little arched, legs spread wide, gills
## fanned, a slow ripple, banking into turns. The body's follow-through is unchanged underneath it.
var glide := 0.0
var _prev_basis := Basis()
var _turn_rate := 0.0
var _seg_w: Array[Vector3] = []          # world direction of each segment, toward the tail
var _f_yaw: Array[float] = []            # this frame's follow yaw / pitch per segment (model space)
var _f_pitch: Array[float] = []
var _f_lift := 0.0                        # the head joint raised or lowered onto the ground under it
var _f_prev_pos := Vector3.INF
var _conform_w := 0.0
var _ray_q: PhysicsRayQueryParameters3D

# Brace against a current (ledger row 19). A ball's current pushing him along the ground (set by the
# controller: current_brace 0..1, how hard; current_push, the push in the world) shows as resistance:
# body low and leaning into the flow, legs splayed with the feet propped downstream and dug in, the
# feet re-planted one at a time (each lags upstream as he skids, lifts and is set down again
# downstream), the tail held off to the downstream side as a rudder with small corrections, chin
# tucked, mouth set, gills streaming. Each planted foot scrapes a small drag mark (WaterFX.drag_mark)
# that grows as the foot skids, up to BRACE_MARK_MAX, and fades. Purely the model and the ground
# marks: the gameplay body, its collision, movement and timing are untouched, and nothing here draws
# a random number (the steps run on their own clock).
var current_brace := 0.0
var current_push := Vector3.ZERO
## Seconds for all four feet to be re-planted in turn: light push .. full push.
const BRACE_CYCLE := Vector2(2.2, 1.1)
## The part of each foot's turn spent lifted (the re-planting step).
const BRACE_LIFT := 0.13
## The order the feet are re-planted: diagonal pairs, like the gait (FL, BR, FR, BL).
const BRACE_ORDER := [0, 3, 1, 2]
## A drag mark: from where the foot was planted along its skid, at most this long (m), this wide.
const BRACE_MARK_MAX := 0.32
const BRACE_MARK_MIN := 0.07
const BRACE_MARK_W := 0.11
var drag_marks := 0                 # marks scraped (tests)
var _brace_w := 0.0                 # the brace this frame, after the model's own gates
var _brace_plant := 0.0             # how much of it is the planted stance (eases off as he walks)
var _brace_clock := 0.0
var _brace_up := Vector2(0, -1)     # upstream, in the model's ground plane (x, z)
var _rudder := 0.0
var _hands: Array[Node3D] = []
var _foot_lifted: Array[bool] = [true, true, true, true]
var _foot_mark: Array[int] = [-1, -1, -1, -1]          # the WaterFX mark each planted foot is drawing
var _foot_at: Array[Vector3] = [Vector3.INF, Vector3.INF, Vector3.INF, Vector3.INF]
var _foot_n: Array[Vector3] = [Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP]
var _mark_q: PhysicsRayQueryParameters3D


func _ready() -> void:
	_fx.seed = 0x6711
	_build()
	# His colours as chosen in the pause menu (GillLook), kept up to date while it is open.
	apply_look(GillLook.current())
	Settings.gill_look_changed.connect(_on_look_changed)


func _on_look_changed() -> void:
	apply_look(GillLook.current())


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


## Axolotl skin (Expansion 6, shaders/axolotl_skin.gdshader): soft moist skin with a warmer back,
## a pale belly, a faint mottle and freckles, and a gentle self-glow so the colour survives the
## murky green water. `mode`: 0 the body, 1 a rigid part (head, limbs), 2 the fin membrane.
func _skin_mat(mode: int, freckles := 1.0, spot_scale := 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SKIN_SHADER
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("freckles", freckles)
	m.set_shader_parameter("spot_scale", spot_scale)
	_skin_mats.append(m)
	return m


## Recolours his skin, freckles and cheeks and lays on his pattern (GillLook.current); the gill
## fronds keep their colours.
func apply_look(t: Dictionary) -> void:
	var pat: Texture2D = t.get("pattern", null)
	for m in _skin_mats:
		m.set_shader_parameter("base_color", t["base"])
		m.set_shader_parameter("back_tint", t["back"])
		m.set_shader_parameter("belly_tint", t["belly"])
		m.set_shader_parameter("freckle_color", t["freckle"])
		m.set_shader_parameter("pattern_on", 1.0 if pat != null else 0.0)
		m.set_shader_parameter("pattern_tex", pat)
		m.set_shader_parameter("pattern_mode", int(t.get("pattern_mode", 0)))
		m.set_shader_parameter("pattern_scale", float(t.get("pattern_size", 3)))
		m.set_shader_parameter("pattern_alpha", float(t.get("pattern_alpha", 1.0)))
	if _cheek_mat:
		_cheek_mat.albedo_color = t["cheek"]


## The skin colours in use (tests).
func look_base() -> Color:
	return _skin_mats[0].get_shader_parameter("base_color") if not _skin_mats.is_empty() else Color.BLACK


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
	var body_mat := _skin_mat(0)
	var head_mat := _skin_mat(1, 1.0, 1.2)
	var fin_mat := _skin_mat(2, 0.0)

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

	# Water arc shown during the tail swipe: the real hit area, drawn to scale (the 270 degrees
	# behind and beside him, out to the swipe's reach from his body centre; Game.player_swipe).
	swipe_fx = MeshInstance3D.new()
	swipe_fx.mesh = _arc_mesh(Game.SWIPE_REACH, 0.45)
	_swipe_mat = ShaderMaterial.new()
	_swipe_mat.shader = preload("res://shaders/swipe_arc.gdshader")
	swipe_fx.material_override = _swipe_mat
	swipe_fx.position = Vector3(0, 0.25, 0.0)   # Axolotl.body_center()
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


func _build_head(head_mat: ShaderMaterial) -> void:
	var att := BoneAttachment3D.new()
	att.bone_name = "s0"
	skeleton.add_child(att)
	head = Node3D.new()
	head.position = Vector3(0, 0.035, -0.08)
	att.add_child(head)
	# Big, wide, rounded head.
	_mesh(_ball(0.2, 32), head_mat, head, Vector3(0, 0, -0.1), Vector3(1.36, 0.96, 1.12))
	# (Freckles over the crown are part of the skin now: axolotl_skin.gdshader.)
	# Soft cheeks.
	var blush := _m(Color(1.0, 0.64, 0.68), 0.6, 0.0)
	_cheek_mat = blush
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
	_mesh(_ball(0.1, 20), _skin_mat(1, 0.0), mouth, Vector3(0, 0.03, 0.004), Vector3(1.32, 0.34, 0.54))
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
## local XY plane pointing up +Y (the node rotation aims it). A second, slightly narrower blade
## crosses the first round the stalk (Expansion 6), so the gill stays feathery seen edge on (from
## the side it was a bare stick).
static func _gill_mesh(length: float, width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in [[Basis(), 1.0], [Basis(Vector3.UP, deg_to_rad(68.0)), 0.78]]:
		_gill_blade(st, blade[0], length, width * float(blade[1]))
	return st.commit()


static func _gill_blade(st: SurfaceTool, rot: Basis, length: float, width: float) -> void:
	var nrm := rot * Vector3(0, 0, -1)
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
				st.set_normal(nrm)
				st.add_vertex(rot * (q[idx] as Vector3))
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
				st.set_normal(nrm)
				st.add_vertex(rot * (q[idx] as Vector3))


func _build_legs(_body_mat: ShaderMaterial) -> void:
	var skin := _skin_mat(1, 0.5, 2.5)
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
		_hands.append(hand)
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
	var span := ARC_SPAN
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


# --- Tail whip ------------------------------------------------------------------------------

const ARC_SPAN := PI * 1.5            # the swipe's 270 degrees (only the cone ahead is safe)
const WHIP_HIP_SHARE := 0.4
## Each bone's share of the tail's bend (head end first; the front half stays out of it).
const WHIP_BONE_W := [0.0, 0.0, 0.0, 0.068, 0.108, 0.135, 0.135, 0.135, 0.122, 0.095, 0.068]


## The whip's sweep (radians round him, 0 = straight behind, + toward the swipe's far side) at
## `s` seconds from the press: cock to the near side, strike across, overshoot, settle, recover.
static func whip_curve(s: float) -> float:
	const COCK := -2.15
	const OVER := 2.7
	const HOLD := 2.0
	if s <= 0.0:
		return 0.0
	if s < 0.045:
		return COCK * sin(s / 0.045 * PI * 0.5)
	if s < 0.15:
		return lerpf(COCK, OVER, smoothstep(0.0, 1.0, (s - 0.045) / 0.105))
	if s < 0.25:
		return lerpf(OVER, HOLD, smoothstep(0.0, 1.0, (s - 0.15) / 0.1))
	return lerpf(HOLD, 0.0, smoothstep(0.0, 1.0, clampf((s - 0.25) / (WHIP_LEN - 0.25), 0.0, 1.0)))


func whip_active() -> bool:
	return _whip_s >= 0.0


# --- Idles ----------------------------------------------------------------------------------

func _update_idle(dt: float) -> void:
	# The Treasure Hunt dance plays through to its end whatever else is set (the controller holds
	# him still meanwhile), then ends cleanly.
	if idle_kind == Idle.DANCE:
		idle_s += dt
		if idle_s >= IDLE_LEN[Idle.DANCE] or dissolve > 0.0:
			idle_kind = Idle.NONE
			_still_s = 0.0
			_idle_wait = -1.0
			_idle_stride = 0.0
		return
	var busy := not idle_ok or dissolve > 0.0 or swipe_t >= 0.0 or _whip_s >= 0.0 or lunge_t >= 0.0 or burst_t >= 0.0 \
			or hurt_t >= 0.0 or land_t >= 0.0 or happy_t >= 0.0 or perk_t >= 0.0 or surf > 0.0 or brace > 0.0 or not grounded \
			or current_brace > 0.0
	if busy:
		# Anything else going on ends an idle at once (the pose blends out in a few frames) and
		# restarts the wait.
		idle_kind = Idle.NONE
		_still_s = 0.0
		_idle_wait = -1.0
		_idle_stride = 0.0
		return
	if idle_kind != Idle.NONE:
		var before := idle_s
		idle_s += dt
		if idle_kind == Idle.STRETCH and before < YAWN_AT and idle_s >= YAWN_AT:
			# A tiny, squeaky yawn.
			yawns += 1
			Sfx.play("gill_yawn", global_position if is_inside_tree() else null, -6.0, 0.06)
		if idle_s >= IDLE_LEN[idle_kind]:
			idle_kind = Idle.NONE
			_still_s = 0.0
			_idle_wait = _fx.randf_range(IDLE_GAP.x, IDLE_GAP.y)
			_idle_stride = 0.0
		else:
			_idle_stride = _idle_pose_at(idle_kind, idle_s, idle_side).get("stride", 0.0)
		return
	_still_s += dt
	if _idle_wait < 0.0:
		_idle_wait = _fx.randf_range(IDLE_FIRST.x, IDLE_FIRST.y)
	if _still_s >= _idle_wait:
		# Any idle but the one just played, so no two in a row and no fixed order.
		var pool: Array[int] = []
		for k in IDLE_RANDOM:
			if k != _idle_last:
				pool.append(k)
		start_idle(pool[_fx.randi() % pool.size()])


## A find in Treasure Hunt: up on his back legs for a happy butt-and-tail wiggle (docs/TREASURE_HUNT.md).
func start_dance() -> void:
	idle_kind = Idle.DANCE
	idle_s = 0.0
	idle_side = 1.0
	happy_t = -1.0


func dancing() -> bool:
	return idle_kind == Idle.DANCE


func start_idle(kind: int) -> void:
	idle_kind = kind
	idle_s = 0.0
	idle_side = -1.0 if _fx.randf() < 0.5 else 1.0
	_idle_last = kind
	idle_count += 1


static func _env(s: float, a: float, b: float, c: float, d: float) -> float:
	return smoothstep(a, b, s) * (1.0 - smoothstep(c, d, s))


## The pose an idle adds at `s` seconds (mirrored by `side`). Legs: per leg (FL, FR, BL, BR)
## (shoulder yaw, shoulder roll, elbow bend) for the left side, mirrored for the right.
static func _idle_pose_at(kind: int, s: float, side: float) -> Dictionary:
	var spine: Array = []
	spine.resize(BONE_Z.size())
	spine.fill(Vector2.ZERO)
	var p := {"pos": Vector3.ZERO, "rot": Vector3.ZERO, "scale": Vector3.ONE, "head": Vector3.ZERO, "eye": 1.0, "mouth": 0.0,
			"gback": 0.0, "gflap": 0.0, "gflare": 0.0, "wave": 1.0, "pivot": Vector3.ZERO, "spine": spine, "legs": [], "legw": 0.0,
			"stride": 0.0, "swing": 1.0}
	match kind:
		Idle.LOOKAROUND:
			# Up onto his back legs, a look one way and the other, and back down onto all fours.
			var up := _env(s, 0.15, 0.95, 3.75, 4.45)
			var th := 0.78 * up
			var look := 0.85 * _env(s, 1.15, 1.55, 1.95, 2.3) - 0.85 * _env(s, 2.35, 2.8, 3.2, 3.55)
			look *= side
			p["pivot"] = Vector3(0, 0.03, BONE_Z[REAR_BONE])
			p["rot"] = Vector3(th, look * 0.22, 0.0)
			# Head kept near level (he looks out, not at the ceiling), turning with each look.
			p["head"] = Vector3(-th * 0.62, look * 0.85, -look * 0.18)
			# The tail stays down on the ground behind him as a counterweight, its tip lifting.
			spine[REAR_BONE] = Vector2(-th, -look * 0.22)
			spine[6] = Vector2(-0.07 * up, 0.0)
			spine[7] = Vector2(-0.06 * up, 0.0)
			p["wave"] = lerpf(1.0, 0.3, up)
			# Front paws lifted and held in front of the chest; back legs splayed for balance.
			p["legs"] = [Vector3(-0.55, 0.95, 0.95), Vector3(-0.55, 0.95, 0.95), Vector3(0.45, 0.25, -0.1), Vector3(0.45, 0.25, -0.1)]
			p["legw"] = up
			p["gflare"] = 0.55 * absf(look)
			p["gflap"] = 0.25 * absf(look)
			p["eye"] = 1.0 + 0.12 * up
			var land := _env(s, 4.3, 4.42, 4.45, 4.6)
			p["scale"] = Vector3(1.0 + 0.05 * land, 1.0 - 0.08 * land, 1.0)
		Idle.SCOOT:
			# A curious little scoot to one side, one to the other, and back to where he started.
			var k1 := smoothstep(0.55, 0.95, s)
			var k2 := smoothstep(1.75, 2.25, s)
			var k3 := smoothstep(3.05, 3.5, s)
			p["pos"] = Vector3(side * (0.2 * k1 - 0.38 * k2 + 0.18 * k3), 0.0, 0.0)
			var m1 := _env(s, 0.5, 0.65, 0.85, 1.0)
			var m2 := _env(s, 1.7, 1.85, 2.15, 2.3)
			var m3 := _env(s, 3.0, 3.15, 3.4, 3.55)
			var moving := side * (m1 - m2 + m3)          # + toward `side`
			p["pos"].y = 0.025 * (m1 + m2 + m3)
			p["stride"] = 0.75 * (m1 + m2 + m3)
			p["swing"] = 0.35                            # feet patter sideways, not a walk
			p["rot"] = Vector3(0.0, 0.0, -moving * 0.1)
			var look := side * (0.55 * _env(s, 0.1, 0.45, 0.95, 1.3) - 0.6 * _env(s, 1.35, 1.65, 2.3, 2.6) + 0.3 * _env(s, 2.7, 2.95, 3.3, 3.6))
			p["head"] = Vector3(0.0, look, 0.0)
			# The body curves toward the scoot and the tail drags behind it.
			for i in range(1, BONE_Z.size()):
				spine[i] = Vector2(0.0, (-0.05 if i < 5 else 0.07) * moving)
			p["gflap"] = 0.3 * (m1 + m2 + m3)
			p["gflare"] = 0.35 * absf(look)
		Idle.DANCE:
			# Up onto the back legs, the hips and tail wiggling side to side (a goofy little victory
			# shimmy), front paws up and waving, a big happy squint, then back down onto all fours.
			var up := _env(s, 0.0, 0.3, 2.45, 2.75)
			var th := 0.92 * up
			var wig := sin(s * TAU * 3.3) * _env(s, 0.28, 0.42, 2.3, 2.5)
			p["pivot"] = Vector3(0, 0.03, BONE_Z[REAR_BONE])
			p["rot"] = Vector3(th, wig * 0.36, wig * 0.12)
			p["pos"] = Vector3(0.0, 0.02 * absf(wig) * up, 0.0)
			# The head stays level and faces front against the hips' swing.
			p["head"] = Vector3(-th * 0.6, -wig * 0.28, wig * 0.12)
			spine[REAR_BONE] = Vector2(-th, -wig * 0.3)
			for i in range(REAR_BONE + 1, BONE_Z.size()):
				var f := float(i - REAR_BONE) / float(BONE_Z.size() - 1 - REAR_BONE)
				spine[i] = Vector2(-0.05 * up, sin(s * TAU * 3.3 - f * 1.4) * 0.34 * up)
			p["wave"] = 0.2
			var paw := 0.25 * sin(s * TAU * 3.3)
			p["legs"] = [Vector3(-0.55, 0.95 + paw, 0.95), Vector3(-0.55, 0.95 - paw, 0.95), Vector3(0.45, 0.25, -0.1), Vector3(0.45, 0.25, -0.1)]
			p["legw"] = up
			p["eye"] = lerpf(1.0, 0.45, up)
			p["mouth"] = 0.95 * up
			p["gflap"] = 0.8 * up
			p["gflare"] = 0.6 * up
		Idle.TILT:
			# A curious head tilt one way, a blink, then the other way.
			var t1 := _env(s, 0.2, 0.6, 1.05, 1.35)
			var t2 := _env(s, 1.4, 1.75, 2.2, 2.55)
			var roll := side * (0.42 * t1 - 0.38 * t2)
			p["head"] = Vector3(-0.08 * (t1 + t2), side * (0.15 * t1 - 0.12 * t2), roll)
			p["rot"] = Vector3(0.0, 0.0, roll * 0.12)
			p["gflare"] = 0.6 * (t1 + t2)
			p["gflap"] = 0.2 * (t1 + t2)
			p["eye"] = (1.0 + 0.15 * (t1 + t2)) * (0.1 if absf(s - 1.37) < 0.07 else 1.0)
			p["mouth"] = 0.5 * (t1 + t2)
		Idle.STRETCH:
			# A long stretch with a yawn (front legs reaching forward, back legs back, tail straight),
			# then a quick shake from gills to tail.
			var st := _env(s, 0.1, 0.8, 1.5, 2.0)
			var yawn := _env(s, 0.4, 0.8, 1.25, 1.6)
			p["scale"] = Vector3(1.0 - 0.05 * st, 1.0 - 0.07 * st, 1.0 + 0.1 * st)
			p["pos"] = Vector3(0.0, -0.02 * st, 0.0)
			p["head"] = Vector3(0.3 * yawn, 0.0, 0.0)
			p["mouth"] = 1.9 * yawn
			p["eye"] = lerpf(1.0, 0.12, yawn)
			p["legs"] = [Vector3(-0.95, 0.2, 0.1), Vector3(-0.95, 0.2, 0.1), Vector3(1.0, 0.2, 0.05), Vector3(1.0, 0.2, 0.05)]
			p["legw"] = st
			p["gback"] = 0.9 * st
			p["wave"] = lerpf(1.0, 0.15, st)
			var sh := _env(s, 2.0, 2.1, 2.7, 3.0)
			p["head"] += Vector3(0.0, sin(s * 38.0) * 0.32 * sh, 0.0)
			p["rot"] = Vector3(0.0, 0.0, sin(s * 38.0 + 1.0) * 0.07 * sh)
			p["gflap"] = sh
			for i in range(3, BONE_Z.size()):
				spine[i] = Vector2(0.0, sin(s * 30.0 - i * 0.7) * 0.13 * sh)
		Idle.LOOKUP:
			# Watches something drift past overhead: chin up, eyes following it across.
			var up := _env(s, 0.2, 0.7, 2.7, 3.2)
			var follow := lerpf(-0.6, 0.7, smoothstep(0.6, 2.6, s)) * side
			p["head"] = Vector3(0.55 * up, follow * up, -follow * 0.2 * up)
			p["rot"] = Vector3(0.12 * up, follow * 0.15 * up, 0.0)
			p["pivot"] = Vector3(0, 0.03, BONE_Z[REAR_BONE])
			p["eye"] = 1.0 + 0.2 * up
			p["gflare"] = 0.45 * up
			p["mouth"] = 0.45 * up
	return p


# --- Health (gills) -------------------------------------------------------------------------

func set_health(h: int, mx: int, flash := true) -> void:
	health = h
	max_health = mx
	if flash:
		_flash = 0.6


## Onboarding's feeding lesson: fronds [from, to) come back slowly from grey to colour and light
## over `dur` seconds (presentation only; his health is already restored).
var _slow_from := 0
var _slow_to := 0
var _slow_k := 1.0
var _slow_dur := 1.0


func restore_fronds_slowly(from_h: int, to_h: int, dur: float) -> void:
	_slow_from = from_h
	_slow_to = to_h
	_slow_dur = maxf(0.05, dur)
	_slow_k = 0.0


## How far the slow frond restore has come (1 when none is running).
func frond_restore_progress() -> float:
	return _slow_k


func fall_flicker() -> void:
	_fall_flicker = 1.2


## v107 game feel. A soft landing's squash (k 0..1 from how hard he came down) springing back.
func soft_land(k: float) -> void:
	soft_land_k = clampf(k, 0.0, 1.0)
	soft_land_t = 0.0


## The push-off: a quick stretch up as he leaves the ground (never before: the jump is not delayed).
func takeoff() -> void:
	takeoff_t = 0.0


## A gulp: mouth wide then snapped shut, chin up, a swallow along the body; k is the prey's weight.
func gulp(k: float) -> void:
	gulp_k = clampf(k, 0.0, 1.0)
	gulp_t = 0.0


## The edge assist caught him at a rim: a small wobble over the drop, eyes wide.
func teeter() -> void:
	teeter_t = 0.0


## A frond just gained (a cave's health upgrade) grows in from small over about a second.
func grow_frond(i: int) -> void:
	_grow_i = i
	_grow_k = 0.0


## v107: while his existing post-hit invulnerability runs, his skin breathes a soft glow (a calm
## pulse, never a blink). Written only when it changes.
func _update_invuln_glow() -> void:
	var target := 0.08
	if invuln > 0.0:
		target += 0.22 * invuln * (0.55 + 0.45 * sin(_t * TAU * 2.2))
	if absf(target - _skin_glow) < 0.004:
		return
	_skin_glow = target
	for m in _skin_mats:
		m.set_shader_parameter("glow", target)


## Gill i: active (i < health) glows in colour; any other gill (lost, or not yet restored
## by a cave upgrade) is dull and faded with a slight droop. All six are always visible.
func _update_gills(dt: float, back: float, flap: float, flare: float) -> void:
	_update_invuln_glow()
	_flash = maxf(0.0, _flash - dt)
	_fall_flicker = maxf(0.0, _fall_flicker - dt)
	_slow_k = minf(1.0, _slow_k + dt / _slow_dur)
	for i in gills.size():
		var side: float = GILL_SLOTS[i][0]
		var k: int = GILL_SLOTS[i][1]
		var active := i < health
		var droop := 0.0 if active else 0.3
		var sway := sin(_t * 2.3 + i * 1.3) * (0.1 + flap) + sin(_t * 15.0 + i) * flap * 0.35
		var base := _gill_base(side, k)
		var rot := base + Vector3(back * 0.9 + droop * 0.6 + sway * 0.4, side * sway * 0.3, side * (droop * 0.5 - flare * 0.35 + back * 0.15))
		gills[i].rotation = gills[i].rotation.lerp(rot, minf(1.0, dt * 12.0))
		# All six gills are always there at full size; health shows only as glow vs dull. (v107: a
		# frond just gained grows in from small with a little spring.)
		if i == _grow_i and _grow_k < 1.0:
			var gk := 1.0 - exp(-_grow_k * 5.0) * cos(_grow_k * PI * 2.5)
			gills[i].scale = Vector3.ONE * lerpf(0.2, 1.0, clampf(gk, 0.0, 1.15))
		else:
			gills[i].scale = Vector3.ONE
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
			var slow := smoothstep(0.0, 1.0, _slow_k) if _slow_k < 1.0 and i >= _slow_from and i < _slow_to else 1.0
			# (A frond coming back brightens as it fills with colour, then settles.)
			var bloom := 0.0 if _slow_k >= 1.0 or i < _slow_from or i >= _slow_to else sin(slow * PI) * 1.4
			m.set_shader_parameter("glow", e * slow + bloom)
			m.set_shader_parameter("desat", 0.88 * (1.0 - slow))
			m.set_shader_parameter("flutter", lerpf(0.35, 1.0 + flap, slow))
		else:
			# Lost (or not yet grown by a cave upgrade): dull and faded.
			m.set_shader_parameter("glow", 0.0)
			m.set_shader_parameter("desat", 0.88)
			m.set_shader_parameter("flutter", 0.35)


# --- Animation ------------------------------------------------------------------------------

func play_land(variant: int, strength: float) -> void:
	land_variant = variant
	land_strength = strength
	land_t = 0.0


func _process(dt: float) -> void:
	_t += dt
	# The body wave advances with movement (and idles slowly), so it matches the ground speed.
	var s := clampf(speed, 0.0, 1.4)
	if swim > 0.0:
		_wave += dt * (2.2 + swim * 6.5)
	elif grounded:
		_wave += dt * (1.2 + maxf(s, _idle_stride) * 10.5)
	else:
		_wave += dt * lerpf(7.0, 2.4, glide)
	_advance_timers(dt)
	_update_idle(dt)
	_update_follow(dt)
	_animate(dt)


## Clears the follow-through: the body lies straight along the model at once. Placing him (a
## respawn, a checkpoint, a teleport) leaves no smear from where he was.
func reset_follow() -> void:
	_f_prev_pos = Vector3.INF
	_end_marks()


## The follow-through, once a frame (see FOLLOW_RATE_MIN): writes _f_yaw, _f_pitch (each segment's
## direction in model space, toward the tail) and _f_lift (the head joint onto the ground).
var _prof: Array = []
var _prof_tick := 0


func _update_follow(dt: float) -> void:
	var n := BONE_Z.size() - 1
	if _f_yaw.size() != n:
		_f_yaw.resize(n)
		_f_pitch.resize(n)
		_seg_w.resize(n)
		_f_prev_pos = Vector3.INF
	if not follow or not is_inside_tree():
		_f_yaw.fill(0.0)
		_f_pitch.fill(0.0)
		_f_lift = 0.0
		_f_prev_pos = Vector3.INF
		return
	var bas := global_transform.basis.orthonormalized()
	var pos := global_transform.origin
	if _f_prev_pos == Vector3.INF or pos.distance_to(_f_prev_pos) > 2.5 or dt <= 0.0:
		# (Placed, respawned or teleported: straight, where he is now.)
		for i in n:
			_seg_w[i] = bas.z
		_f_yaw.fill(0.0)
		_f_pitch.fill(0.0)
		_f_lift = 0.0
		_conform_w = 0.0
		_f_prev_pos = pos
		_prev_basis = bas
		_turn_rate = 0.0
		_prof = []
		return
	var spd := pos.distance_to(_f_prev_pos) / dt
	_f_prev_pos = pos
	var inv := bas.inverse()
	# Authored whole-body moves (the tail whip, whose water arc is drawn from the straight body, the
	# lunge, a landing, rising onto his back legs) straighten him quickly instead.
	var stiff := _whip_s >= 0.0 or lunge_t >= 0.0 or land_t >= 0.0 or idle_kind == Idle.DANCE or idle_kind == Idle.LOOKAROUND
	# (In the water the body is looser: the tail trails further through a turn or a dive.)
	var a := 1.0 - exp(-maxf(FOLLOW_RATE_MIN, minf(spd, FOLLOW_RATE_MAX_SPEED) / (FOLLOW_SEG * (1.3 if swim > 0.0 else 1.0))) * dt)
	# (Up and down, off the ground and out of the water, the body follows at a steady rate: it trails
	# the head's rise and fall however fast he flies.)
	var a_p := a if grounded or swim > 0.0 else 1.0 - exp(-FOLLOW_AIR_RATE * dt)
	var a_stiff := 1.0 - exp(-30.0 * dt)
	var ac := 1.0 - exp(-CONFORM_RATE * dt)
	# (The ground under him is re-probed every other frame while he moves and every sixth while he
	# stands; the body eases toward it at CONFORM_RATE either way, so this reads the same at half
	# the raycasts.)
	_prof_tick += 1
	if not conform:
		_prof = []
	elif _prof.is_empty() or _prof_tick % (2 if spd > 0.05 else 6) == 0:
		_prof = _ground_profile()
	var prof: Array = _prof
	_conform_w = move_toward(_conform_w, 0.0 if prof.is_empty() else 1.0, dt * 6.0)
	# The head leads: in the air its nose rises and dips with the jump, the body following.
	var lead := 0.0
	if not grounded and swim <= 0.0:
		lead = clampf(vup * 0.045, -0.55, 0.4)
	var lift := 0.0
	if not prof.is_empty():
		var hl: float = _profile_h(prof, BONE_Z[0])
		lift = clampf(0.0 if is_nan(hl) else hl, -0.25, 0.3 + 0.25 * crawl)
	# The head leads into a turn: round ahead of the body by part of the turn still to come and of
	# how fast he is turning (none while an authored whole-body move plays).
	var up_n := bas.y
	var f_now := -bas.z
	var f_prev := -_prev_basis.z
	_prev_basis = bas
	var w := f_prev.signed_angle_to(f_now, up_n) / dt if f_prev.length() > 0.5 else 0.0
	_turn_rate = lerpf(_turn_rate, clampf(w, -12.0, 12.0), 1.0 - exp(-20.0 * dt))
	var head_yaw := 0.0
	if not stiff and swim <= 0.0:
		head_yaw = clampf(turn_gap * HEAD_LEAD_GAP + _turn_rate * HEAD_LEAD_RATE, -HEAD_LEAD_MAX, HEAD_LEAD_MAX)
	elif swim > 0.0:
		head_yaw = clampf(swim_turn * 0.12, -0.35, 0.35)
	_f_lift = lerpf(_f_lift, lift * _conform_w, ac)
	var prev_yaw := 0.0
	var prev_pitch := 0.0
	for i in n:
		var dl := inv * _seg_w[i]
		var yaw := atan2(dl.x, dl.z)
		var pitch := asin(clampf(-dl.y, -1.0, 1.0))
		# On the ground: the slope of the ground under this segment (NAN where nothing is under it).
		var pg := NAN
		if not prof.is_empty():
			var h0: float = _profile_h(prof, BONE_Z[i])
			var h1: float = _profile_h(prof, BONE_Z[i + 1])
			if not is_nan(h0) and not is_nan(h1):
				pg = atan2(h0 - h1, BONE_Z[i + 1] - BONE_Z[i])
		if i == 0:
			yaw = lerpf(_f_yaw[0], head_yaw, 1.0 - exp(-18.0 * dt))
			# (Off the ground the head segment points where the head does; on it, it eases onto the
			# ground ahead.)
			var target := lead if is_nan(pg) else lerpf(lead, pg, _conform_w)
			pitch = lerpf(pitch, target, lerpf(1.0, ac, _conform_w))
		else:
			var rel := wrapf(yaw - prev_yaw, -PI, PI)
			# (Held in a curve while he keeps turning, more toward the tail, so even a broad turn
			# reads as the whole body bending along it; straight again when he runs straight.)
			var curve := 0.0 if stiff else clampf(-_turn_rate * FOLLOW_CURVE * lerpf(0.6, 1.4, float(i) / n) * (0.7 if swim > 0.0 else 1.0), -FOLLOW_CURVE_MAX, FOLLOW_CURVE_MAX)
			rel = curve + (rel - curve) * (1.0 - (a_stiff if stiff else a))
			yaw = prev_yaw + clampf(rel, -FOLLOW_MAX_YAW, FOLLOW_MAX_YAW)
			var lagged := pitch + (prev_pitch - pitch) * a_p
			if not is_nan(pg):
				pitch = lerpf(lagged, lerpf(pitch, pg, ac), _conform_w)
			else:
				# Hanging over an edge: it follows the segment ahead, drooping a little.
				pitch = lagged + (0.06 * _conform_w * a_p)
			if stiff and is_nan(pg):
				pitch = lerpf(pitch, prev_pitch, a_stiff)
			pitch = prev_pitch + clampf(pitch - prev_pitch, -FOLLOW_MAX_PITCH, FOLLOW_MAX_PITCH)
		pitch = clampf(pitch, -1.2, 1.2)
		_f_yaw[i] = yaw
		_f_pitch[i] = pitch
		_seg_w[i] = bas * Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
		prev_yaw = yaw
		prev_pitch = pitch


## The ground under his body, in model space: [[z, height], ...] by z, NAN where nothing is under
## that point (over an edge). Empty when nothing is found under him at all.
func _ground_profile() -> Array:
	var space := get_world_3d().direct_space_state
	if _ray_q == null:
		_ray_q = PhysicsRayQueryParameters3D.new()
		_ray_q.hit_from_inside = false
		_ray_q.hit_back_faces = false
	_ray_q.collision_mask = conform_mask
	var xf := Transform3D(global_transform.basis.orthonormalized(), global_transform.origin)
	var inv := xf.affine_inverse()
	var out := []
	var found := false
	var base := 0.0
	for z in FOLLOW_RAYS:
		# (Ahead from his own footing; behind, each from the ground found just before it, so the
		# rays start above ground rising behind him and reach ground falling away.)
		var from_h: float = (0.0 if z < 0.0 else base) + (0.6 if z >= 0.0 else 0.75 + 0.35 * crawl)
		_ray_q.from = xf * Vector3(0, from_h, z)
		_ray_q.to = xf * Vector3(0, from_h - 1.5, z)
		var hit := space.intersect_ray(_ray_q)
		var h := NAN
		if not hit.is_empty():
			var lp: Vector3 = inv * (hit["position"] as Vector3)
			h = lp.y
			found = true
		if z >= 0.0 and not is_nan(h):
			base = h
		out.append([z, h])
	if not found:
		return []
	out.sort_custom(func(p, q): return p[0] < q[0])
	return out


## Ground height at `z` along the body from a profile (linear between samples; NAN past a gap).
static func _profile_h(prof: Array, z: float) -> float:
	if z <= prof[0][0]:
		return prof[0][1]
	for i in range(1, prof.size()):
		var b: Array = prof[i]
		if z <= b[0]:
			var a: Array = prof[i - 1]
			if is_nan(a[1]) or is_nan(b[1]):
				return NAN
			return lerpf(a[1], b[1], (z - a[0]) / (b[0] - a[0]))
	return prof[prof.size() - 1][1]


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
	if soft_land_t >= 0.0:
		soft_land_t += dt / 0.34
		if soft_land_t > 1.0: soft_land_t = -1.0
	if takeoff_t >= 0.0:
		takeoff_t += dt / 0.26
		if takeoff_t > 1.0: takeoff_t = -1.0
	if gulp_t >= 0.0:
		gulp_t += dt / 0.34
		if gulp_t > 1.0: gulp_t = -1.0
	if teeter_t >= 0.0:
		teeter_t += dt / 0.6
		if teeter_t > 1.0: teeter_t = -1.0
	if _grow_k < 1.0:
		_grow_k = minf(1.0, _grow_k + dt / 1.1)
	_blink -= dt
	if _blink < -0.12:
		_blink = _fx.randf_range(1.8, 4.5)
	# The whip clock starts on a new swipe (swipe_t restarting) and runs on past it.
	if swipe_t >= 0.0 and (_prev_swipe_t < 0.0 or swipe_t < _prev_swipe_t):
		_whip_s = 0.0
		_whip_side = swipe_side
	_prev_swipe_t = swipe_t
	if _whip_s >= 0.0:
		_whip_s += dt
		if _whip_s > WHIP_LEN:
			_whip_s = -1.0


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
		# (With the follow-through the head leads the jump's rise and fall and the body follows it
		# (_update_follow); the whole body tips only a little.)
		rig_rot.x = clampf(vup * (0.012 if follow else 0.035), -0.4, 0.3)
		arch = clampf(-vup * 0.02, -0.12, 0.12)
		wave_amp = 0.2
		gill_back = maxf(gill_back, 0.6)
		if glide > 0.01 and swim <= 0.0:
			# Gliding: flat and spread like a leaf on the water, nose just below level, banking into
			# the turn he is making; a slow small ripple down the body and tail.
			var gw := glide
			if gw > 0.35:
				leg_mode = 4
			rig_rot.x = lerpf(rig_rot.x, 0.06, gw)
			rig_rot.z = clampf(-_turn_rate * 0.08, -0.4, 0.4) * gw
			arch = lerpf(arch, 0.08, gw)
			wave_amp = lerpf(wave_amp, 0.07, gw)
			gill_back = lerpf(gill_back, 0.1, gw)
			gill_flare = maxf(gill_flare, 0.8 * gw)
			rig_scale = Vector3(1.0 + 0.12 * gw, 1.0 - 0.12 * gw, 1.0)
	if swim > 0.0:
		var e := clampf(swim / 2.0, 0.0, 1.0)
		# Lateral undulation drives him: gentle when hovering, strong and quick when fast.
		wave_amp = 0.1 + 0.28 * e
		leg_mode = 1 if swim > 1.1 else 0
		gill_back = 0.25 + 0.75 * e
		gill_flap = 0.15 + 0.2 * (1.0 - e)
		# Into the turn (the body curves, the tail swings out), nose up or down with the climb.
		rig_rot.z = clampf(-swim_turn * 0.18, -0.35, 0.35)
		rig_rot.x = clampf(swim_pitch, -0.6, 0.6)
		# (The follow-through already swings the tail out round a turn: a lighter push here.)
		tail_base = clampf(-swim_turn * (0.25 if follow else 0.5), -0.8, 0.8)
		arch = clampf(-swim_pitch * 0.15, -0.12, 0.12)
	if crawl > 0.05 and swim <= 0.0:
		# Crawling over a transition: chin up toward the purchase, front feet reaching for it and
		# gripping, the rear pushing (the body's bend over the edge is the follow-through's).
		leg_mode = 3
		head_rot.x -= 0.22 * crawl
		gill_back = maxf(gill_back, 0.5 * crawl)
		wave_amp *= 1.0 - 0.6 * crawl
	_brace_w = brace_weight()
	_brace_plant = 0.0
	_rudder = 0.0
	if _brace_w > 0.0:
		# Braced against the current: leaning into it (toward upstream), body low and squat, chin
		# tucked, mouth set, eyes narrowed, gills streaming; the body stiffens (less wave).
		var bw := _brace_w
		var lp := global_transform.basis.orthonormalized().inverse() * current_push if is_inside_tree() else current_push
		var u := Vector2(-lp.x, -lp.z)
		if u.length() > 0.001:
			_brace_up = u.normalized()
		u = _brace_up
		_brace_plant = bw * (1.0 - smoothstep(0.3, 0.75, s))
		var pl := _brace_plant
		var lean := 0.3 * bw
		rig_rot.x += lean * u.y
		rig_rot.z -= lean * u.x
		# (Shoulders turned a little into the flow, head further: he faces up into it.)
		rig_rot.y -= 0.12 * bw * u.x
		head_rot.y -= 0.25 * bw * u.x
		rig_pos += Vector3(u.x, 0.0, u.y) * 0.05 * bw
		rig_pos.y -= 0.045 * pl
		rig_scale *= Vector3(1.0 + 0.08 * pl, 1.0 - 0.15 * pl, 1.0)
		head_rot.x += 0.16 * pl
		eye_scale.y *= 1.0 - 0.3 * pl
		mouth_open = lerpf(mouth_open, 0.08, pl)
		gill_back = maxf(gill_back, 0.35 + 0.6 * bw)
		gill_flap = maxf(gill_flap, 0.15 + 0.2 * bw)
		wave_amp *= 1.0 - 0.75 * pl
		# The tail as a rudder: held off to the downstream side, set against the flow, with small
		# steering corrections (on his own clock).
		_rudder = (-u.x * 0.75 + sin(_t * 2.3) * 0.18 + sin(_t * 5.1) * 0.06) * bw
	if burst_t >= 0.0:
		var k := sin(burst_t * PI)
		wave_amp = 0.18 + 0.3 * k
		_wave += dt * 14.0 * k
		rig_scale = Vector3(0.94, 0.94, 1.0 + 0.18 * k)
		gill_back = 1.1
		mouth_open = 0.7
	var whip := _whip_s >= 0.0
	if whip:
		# The hips lead the sweep and carry about 0.4 of it; the head turns back against the twist
		# so his eyes stay on what he is swiping.
		var hips := whip_curve(_whip_s + 0.012) * _whip_side * WHIP_HIP_SHARE
		rig_rot.y += hips
		head_rot.y -= hips * 0.6
		wave_amp = 0.02
		if _whip_s < 0.3:
			leg_mode = 2
		gill_back = maxf(gill_back, 0.8)
		mouth_open = maxf(mouth_open, 0.8 * (1.0 - smoothstep(0.2, 0.4, _whip_s)))
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

	# v107 game feel: short springs layered on whatever else he is doing (presentation only).
	if soft_land_t >= 0.0:
		# Squash, a little overshoot, settle: a damped spring over about a third of a second.
		var sp := exp(-soft_land_t * 3.2) * cos(soft_land_t * PI * 2.4) * soft_land_k
		rig_scale *= Vector3(1.0 + 0.1 * sp, 1.0 - 0.17 * sp, 1.0 + 0.04 * sp)
		rig_pos.y -= 0.03 * maxf(0.0, sp)
	if takeoff_t >= 0.0:
		var sp := exp(-takeoff_t * 3.0) * cos(takeoff_t * PI * 2.0)
		rig_scale *= Vector3(1.0 - 0.06 * sp, 1.0 + 0.13 * sp, 1.0 - 0.03 * sp)
		gill_back = maxf(gill_back, 0.6 * maxf(0.0, sp))
	if gulp_t >= 0.0:
		var k := sin(gulp_t * PI) * gulp_k
		mouth_open = 1.0 if gulp_t < 0.22 else lerpf(mouth_open, 0.05, smoothstep(0.22, 0.4, gulp_t))
		head_rot.x += 0.14 * k
		rig_scale *= Vector3(1.0 + 0.05 * k, 1.0 - 0.04 * k, 1.0 + 0.02 * k)
		gill_flap = maxf(gill_flap, 0.45 * k)
		eye_scale = eye_scale * Vector3(1.0, lerpf(1.0, 0.55, k), 1.0)
	if teeter_t >= 0.0:
		var sp := sin(teeter_t * PI * 3.0) * exp(-teeter_t * 2.6)
		rig_rot.x += 0.16 * sp
		eye_scale = eye_scale * (1.0 + 0.25 * exp(-teeter_t * 3.0))
		gill_flap = maxf(gill_flap, 0.3 * absf(sp))
		if teeter_t < 0.5:
			leg_mode = 2

	var ip := {}
	if idle_kind != Idle.NONE:
		ip = _idle_pose_at(idle_kind, idle_s, idle_side)
		rig_pos += ip["pos"]
		rig_rot += ip["rot"]
		rig_scale *= ip["scale"]
		head_rot += ip["head"]
		eye_scale.y *= ip["eye"]
		mouth_open = maxf(mouth_open, ip["mouth"])
		gill_back = maxf(gill_back, ip["gback"])
		gill_flap = maxf(gill_flap, ip["gflap"])
		gill_flare = maxf(gill_flare, ip["gflare"])
		wave_amp *= ip["wave"]
		# Rotations pivot where the pose says (the hips, to rise onto the back legs), so the feet
		# that stay down stay planted.
		var pv: Vector3 = ip["pivot"]
		rig_pos += pv - Basis.from_euler(ip["rot"]) * pv
	elif grounded and s < 0.3:
		# Breathing.
		rig_scale.y *= 1.0 + 0.012 * sin(_t * 1.7)
	# (Eased in and out, never snapped: v107's glances come and go calmly.)
	var look_ok := has_look and land_t < 0.0 and swipe_t < 0.0 and lunge_t < 0.0 and idle_kind == Idle.NONE
	_look_w = move_toward(_look_w, 1.0 if look_ok else 0.0, dt * 2.5)
	if _look_w > 0.0:
		var local := to_local(look_target)
		head_rot.y += clampf(atan2(-local.x, -local.z), -0.7, 0.7) * smoothstep(0.0, 1.0, _look_w)
	if _blink < 0.0:
		eye_scale.y *= 0.1

	rig.position = rig.position.lerp(rig_pos, minf(1.0, dt * 18.0))
	rig.rotation = rig.rotation.lerp(rig_rot, minf(1.0, dt * (60.0 if whip else 14.0)))
	rig.scale = rig.scale.lerp(rig_scale * (1.0 - dissolve), minf(1.0, dt * 16.0))
	head.rotation = head.rotation.lerp(head_rot, minf(1.0, dt * 12.0))
	eye_l.scale = eye_l.scale.lerp(eye_scale * eye_l_scale, minf(1.0, dt * 20.0))
	eye_r.scale = eye_r.scale.lerp(eye_scale, minf(1.0, dt * 20.0))
	var mo := 0.35 + mouth_open * 0.55
	_mouth_dark.scale = _mouth_dark.scale.lerp(Vector3(1.25, 0.18 + mo * 0.5, 0.5), minf(1.0, dt * 14.0))
	_tongue.position.y = lerpf(_tongue.position.y, -0.01 - mo * 0.02, minf(1.0, dt * 14.0))

	# Spine: travelling S-wave (relative bend per bone), plus swipe whip and back arch.
	var n := BONE_Z.size()
	var spine_ip: Array = ip.get("spine", [])
	# The tail tip's direction round him (for the whip's water arc): walked down the chain.
	var hx := sin(rig.rotation.y) * BONE_Z[0]
	var hz := cos(rig.rotation.y) * BONE_Z[0]
	var heading := rig.rotation.y
	# The follow-through (_update_follow) sets each segment's direction; the wave, the whip, the arch
	# and the idles bend it further, relative to it, as they always have.
	var has_f := _f_yaw.size() == n - 1
	var fb_prev := Basis()
	for i in n:
		var fb := Basis.from_euler(Vector3(_f_pitch[i], _f_yaw[i], 0.0)) if has_f and i < n - 1 else fb_prev
		var q_f := Quaternion(fb_prev.inverse() * fb) if i > 0 else Quaternion(fb)
		fb_prev = fb
		var f := float(i) / (n - 1)
		var amp := wave_amp * lerpf(0.12, 1.25, pow(f, 1.1))
		var yaw := sin(_wave - i * wave_len) * amp
		if whip and i >= 3:
			# Whip: the bend travels down the tail, each bone a little behind the one before.
			yaw += whip_curve(_whip_s - (i - 3) * 0.008) * _whip_side * WHIP_BONE_W[i]
		elif i >= 5:
			yaw += tail_base * 0.12 + _rudder * (0.07 + 0.03 * (i - 5))
		var pitch := arch * (1.0 if i >= 5 else -0.4) * 0.5
		if brace > 0.0 and i >= 5:
			pitch -= 0.06 * brace
		if not spine_ip.is_empty():
			pitch += (spine_ip[i] as Vector2).x
			yaw += (spine_ip[i] as Vector2).y
		var target := Vector3(pitch, yaw, 0.0)
		_bone_rot[i] = _bone_rot[i].lerp(target, minf(1.0, dt * (70.0 if whip else 18.0)))
		if i > 0:
			heading += _bone_rot[i].y
		var seg: float = (BONE_Z[i + 1] - BONE_Z[i]) if i < n - 1 else 0.12
		var fy: float = _f_yaw[mini(i, n - 2)] if has_f else 0.0
		hx += sin(heading + fy) * seg
		hz += cos(heading + fy) * seg
		if i == 0:
			# The head stays aligned with the controller's facing; it only tips with the ground
			# ahead (or the jump), and sits on the ground under it.
			skeleton.set_bone_pose_rotation(0, q_f)
			skeleton.set_bone_pose_position(0, Vector3(0, BODY_Y + _f_lift, BONE_Z[0]))
			continue
		skeleton.set_bone_pose_rotation(i, q_f * Quaternion.from_euler(_bone_rot[i]))
	whip_tip_az = atan2(hx, hz)
	_leg_idle = ip.get("legs", [])
	_leg_idle_w = ip.get("legw", 0.0)
	_leg_swing = ip.get("swing", 1.0)

	_update_gills(dt, clampf(gill_back, 0.0, 1.4), gill_flap, gill_flare)
	_animate_legs(dt, maxf(s, ip.get("stride", 0.0)), leg_mode)
	_brace_marks(dt)

	# The water arc: its bright head rides the tail tip, from the strike to the follow-through.
	var arc_a := smoothstep(0.02, 0.05, _whip_s) * (1.0 - smoothstep(0.2, 0.34, _whip_s)) if whip else 0.0
	swipe_fx.visible = arc_a > 0.0
	if swipe_fx.visible:
		_swipe_mat.set_shader_parameter("head", clampf((whip_tip_az + ARC_SPAN * 0.5) / ARC_SPAN, 0.0, 1.0))
		_swipe_mat.set_shader_parameter("dir", _whip_side)
		_swipe_mat.set_shader_parameter("strength", arc_a)


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
				var swing := sin(ph) * 0.62 * stride * _leg_swing
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
			4:
				# Glide: all four spread wide and flat, the front ones reaching a little forward, the
				# back ones a little back, fingers and toes fanned, with a slow flutter.
				# (Upper limbs level, forearms straightened out sideways instead of down to the ground.)
				var fl := sin(_t * 3.2 + i * 1.3) * 0.08
				yaw = side * (-0.35 if front else 0.55)
				roll = side * (0.12 + fl)
				bend = side * (1.3 if front else 1.15)
			3:
				# Crawl: front feet reach forward and up for the purchase and paw at it in turn; the
				# back feet plant and push, swept back.
				var paw := sin(_t * 11.0 + (0.0 if side < 0.0 else PI))
				if front:
					yaw = side * (-0.75 + 0.2 * paw)
					roll = side * (0.55 + 0.25 * maxf(0.0, paw))
					bend = side * 0.35
				else:
					yaw = side * (0.7 + 0.15 * paw)
					roll = side * 0.12
					bend = -side * 0.15
		if land_t >= 0.0 and land_variant == 0 and i == 1:
			var fist: Vector3 = _land_pose["fist"]
			yaw += fist.y
			roll += fist.z
			bend += fist.x * 0.5
		if _brace_plant > 0.0 and mode == 0:
			var bp := _brace_leg(i, side)
			yaw = lerpf(yaw, bp.x, _brace_plant)
			roll = lerpf(roll, bp.y, _brace_plant)
			bend = lerpf(bend, bp.z, _brace_plant)
		if _hands.size() == legs.size():
			# (Planted, the fingers press into the ground.)
			var dig := -0.35 * _brace_plant * (1.0 - _brace_lift(i))
			_hands[i].rotation.x = lerpf(_hands[i].rotation.x, dig, minf(1.0, dt * 14.0))
		if _leg_idle_w > 0.0 and not _leg_idle.is_empty():
			var li: Vector3 = _leg_idle[i]    # (shoulder yaw, shoulder roll, elbow bend), mirrored per side
			yaw = lerpf(yaw, side * li.x, _leg_idle_w)
			roll = lerpf(roll, side * li.y, _leg_idle_w)
			bend = lerpf(bend, side * li.z, _leg_idle_w)
		legs[i].rotation = legs[i].rotation.lerp(Vector3(0, yaw, roll), minf(1.0, dt * 14.0))
		_elbows[i].rotation = _elbows[i].rotation.lerp(Vector3(0, 0, bend), minf(1.0, dt * 14.0))


# --- Brace against a current (ledger row 19) ---------------------------------------------------

## The brace drawn this frame: the controller's current_brace while he stands on the ground with
## nothing else posing him; 0 swimming, in the air, crawling, or in another full-body moment.
func brace_weight() -> float:
	if current_brace <= 0.0 or not grounded or swim > 0.0 or crawl > 0.05 or brace > 0.0 or surf > 0.0 \
			or lunge_t >= 0.0 or dissolve > 0.0 or glide > 0.05:
		return 0.0
	return clampf(current_brace, 0.0, 1.0)


## Where foot `i` is in its re-planting turn: 0..1 round the cycle from the moment it lifts.
func _brace_phase(i: int) -> float:
	return fposmod(_brace_clock - BRACE_ORDER.find(i) * 0.25, 1.0)


## 0..1..0 while foot `i` is lifted for its re-planting step, 0 while it is planted.
func _brace_lift(i: int) -> float:
	var p := _brace_phase(i)
	return sin(p / BRACE_LIFT * PI) if p < BRACE_LIFT else 0.0


## The braced pose of leg `i` (shoulder yaw, shoulder roll, elbow bend, as _animate_legs uses them):
## splayed wide and propped toward downstream, the foot lagging upstream as he skids, then lifted
## and set down downstream again.
func _brace_leg(i: int, side: float) -> Vector3:
	var p := _brace_phase(i)
	# -1: lagged upstream (about to lift); +1: just set down downstream.
	var at := lerpf(-1.0, 1.0, p / BRACE_LIFT) if p < BRACE_LIFT else lerpf(1.0, -1.0, (p - BRACE_LIFT) / (1.0 - BRACE_LIFT))
	var d := -_brace_up
	var dir := Vector2(side, 0.0) + d * (0.8 + 0.4 * at)
	var out := side * dir.x
	var yaw := clampf(side * atan2(-dir.y, maxf(out, 0.05)), -1.0, 1.0)
	var lift := _brace_lift(i)
	var strain := sin(_t * 17.0 + i * 1.7) * 0.03
	# Elbows up and out, forearms angled outward to the planted feet (the low body keeps them on
	# the ground); the props on the downstream side reach wider.
	var roll := side * (0.36 + 0.12 * (out - 1.0) + 0.45 * lift + strain)
	var bend := side * (0.3 + 0.12 * (out - 1.0) + 0.45 * lift)
	return Vector3(yaw, roll, bend)


## The feet's drag marks: a planted foot starts a mark where it is set down and draws it out along
## its skid (up to BRACE_MARK_MAX); lifting it ends the mark. Only on the moss and gravel itself
## (the ball's ground, layer 1), never on a leaf, a stone or a platform.
func _brace_marks(dt: float) -> void:
	if _brace_plant < 0.3 or _hands.size() != 4 or not is_inside_tree() or WaterFX.inst == null:
		_end_marks()
		return
	var bw := _brace_w
	_brace_clock += dt / lerpf(BRACE_CYCLE.x, BRACE_CYCLE.y, bw)
	var fx := WaterFX.inst
	for i in 4:
		var lifted := _brace_phase(i) < BRACE_LIFT
		var foot := _hands[i].global_position
		if lifted:
			if not _foot_lifted[i] and _foot_mark[i] >= 0:
				# Lifting off: a little kicked-up silt where the scrape ends.
				fx.scuff(_foot_at[i].lerp(foot, 0.5), _foot_n[i], current_push * 0.4, bw)
			_foot_mark[i] = -1
			_foot_at[i] = Vector3.INF
		elif _foot_lifted[i] or _foot_at[i] == Vector3.INF:
			# Set down: dig in where the ground is.
			var hit := _ground_under(foot)
			if not hit.is_empty():
				_foot_at[i] = hit[0]
				_foot_n[i] = hit[1]
				var down := current_push - (hit[1] as Vector3) * current_push.dot(hit[1])
				var dir := down.normalized() if down.length() > 0.01 else global_transform.basis.z
				_foot_mark[i] = fx.drag_mark(hit[0], hit[1], dir, BRACE_MARK_MIN, BRACE_MARK_W, 0.55 + 0.45 * bw)
				drag_marks += 1
		elif _foot_mark[i] >= 0:
			# Skidding: the mark follows the foot (kept on the ground plane where it dug in).
			var n: Vector3 = _foot_n[i]
			var a: Vector3 = _foot_at[i]
			var b := foot - n * (foot - a).dot(n)
			if a.distance_to(b) > BRACE_MARK_MAX:
				_foot_mark[i] = -1
			elif not fx.drag_mark_stretch(_foot_mark[i], a, b, BRACE_MARK_MIN):
				_foot_mark[i] = -1
		_foot_lifted[i] = lifted


func _end_marks() -> void:
	for i in 4:
		_foot_mark[i] = -1
		_foot_at[i] = Vector3.INF
		_foot_lifted[i] = true


## The ball's ground (layer 1) under a foot: [point, normal], or [] (not on the moss or gravel).
func _ground_under(foot: Vector3) -> Array:
	if _mark_q == null:
		_mark_q = PhysicsRayQueryParameters3D.new()
		_mark_q.collision_mask = 1
		_mark_q.hit_back_faces = false
	var n := global_transform.basis.y.normalized()
	_mark_q.from = foot + n * 0.25
	_mark_q.to = foot - n * 0.3
	var hit := get_world_3d().direct_space_state.intersect_ray(_mark_q)
	if hit.is_empty() or (hit["normal"] as Vector3).dot(n) < 0.6:
		return []
	return [hit["position"], hit["normal"]]


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
